"""
    to_pmd(net::Dict{String,Any}) -> Dict{String,Any}

Convert a BMOPF network dict to a PowerModelsDistribution ENGINEERING
model dictionary, suitable for passing directly to PMD's `solve_mc_*`
functions or `transform_data_model`.

The output includes the `"data_model" => ENGINEERING` marker that PMD expects.

# Key reverse mappings
- BMOPF `terminal_names` string arrays → PMD `terminals` int arrays
- BMOPF `terminal_map_*` string arrays → PMD `f_connections`/`t_connections` int arrays
- BMOPF voltage values in V → PMD in p.u. (requires settings voltage base)
- BMOPF power values in W/var → PMD scaled by `power_scale_factor`
- BMOPF `v_angle` in radians → PMD `va` in degrees
- BMOPF `open_switch` bool → PMD `state` (0=OPEN, 1=CLOSED)
- BMOPF pattern keys (R_series_1_1, G_1_1, ...) → PMD matrices

# Notes
- A minimal `settings` dict is always included in the output.
- If the BMOPF net contains `_pmd` sub-dicts (carried through from a PMD
  ENGINEERING source), those fields are merged back into the PMD component.
"""
function to_pmd(net::Dict{String,Any})::Dict{String,Any}
    eng = Dict{String,Any}()

    # PMD requires this marker
    eng["data_model"] = "ENGINEERING"   # caller should set to PMD Enum if using PMD directly

    # settings — use defaults if not derivable from BMOPF
    eng["settings"] = _infer_settings(net)
    vscale = eng["settings"]["voltage_scale_factor"]
    pscale = eng["settings"]["power_scale_factor"]

    get(net, "name", nothing) !== nothing && (eng["name"] = net["name"])

    # Build reverse terminal map: per bus, name → int
    terminal_int_map = _build_terminal_int_map(net)

    haskey(net, "bus") &&
        (eng["bus"] = Dict(id => _bus_to_pmd(b, vscale, id)
                           for (id, b) in net["bus"]))

    haskey(net, "line") &&
        (eng["line"] = Dict(id => _line_to_pmd(l, terminal_int_map)
                            for (id, l) in net["line"]))

    haskey(net, "linecode") &&
        (eng["linecode"] = Dict(id => _linecode_to_pmd(lc)
                                for (id, lc) in net["linecode"]))

    haskey(net, "voltage_source") &&
        (eng["voltage_source"] = Dict(id => _voltage_source_to_pmd(vs, terminal_int_map, vscale)
                                      for (id, vs) in net["voltage_source"]))

    haskey(net, "load") &&
        (eng["load"] = Dict(id => _load_to_pmd(l, terminal_int_map, pscale)
                            for (id, l) in net["load"]))

    haskey(net, "generator") &&
        (eng["generator"] = Dict(id => _generator_to_pmd(g, terminal_int_map, pscale)
                                 for (id, g) in net["generator"]))

    haskey(net, "shunt") &&
        (eng["shunt"] = Dict(id => _shunt_to_pmd(s, terminal_int_map)
                             for (id, s) in net["shunt"]))

    haskey(net, "switch") &&
        (eng["switch"] = Dict(id => _switch_to_pmd(sw, terminal_int_map)
                              for (id, sw) in net["switch"]))

    haskey(net, "transformer") &&
        (eng["transformer"] = _transformers_to_pmd(net["transformer"], terminal_int_map, vscale, pscale))

    haskey(net, "time_series") &&
        (eng["time_series"] = deepcopy(net["time_series"]))

    eng
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

function _infer_settings(net::Dict{String,Any})::Dict{String,Any}
    Dict{String,Any}(
        "voltage_scale_factor" => 1.0,   # BMOPF is in SI (V), PMD default kV → use 1.0
        "power_scale_factor"   => 1.0,   # BMOPF is in SI (W), adjust if needed
        "base_frequency"       => 50.0,
        "sbase_default"        => 1e6,
        "vbases_default"       => Dict{String,Any}()
    )
end

"""
Build a map: bus_id => Dict(terminal_name => terminal_int)
Standard: "1"=>1, "2"=>2, "3"=>3, "n"=>4
"""
function _build_terminal_int_map(net::Dict{String,Any})::Dict{String,Dict{String,Int}}
    result = Dict{String,Dict{String,Int}}()
    for (id, bus) in get(net, "bus", Dict())
        tnames = get(bus, "terminal_names", String[])
        result[id] = Dict(name => _terminal_name_to_int(name)
                          for name in tnames)
    end
    result
end

"""
Convert a BMOPF terminal name to a PMD integer terminal id.

The TF spec allows arbitrary terminal-name conventions (Table 11); the
common ones are supported here: OpenDSS numeric ("1","2","3","4"),
letter phases ("a","b","c","n", any case), and IEC 60445 ("L1","L2",
"L3","N"). Genuinely unknown names raise an informative error rather
than silently mis-mapping.
"""
const _TERMINAL_NAME_TO_INT = Dict{String,Int}(
    "1" => 1, "2" => 2, "3" => 3, "4" => 4, "n" => 4,
    "a" => 1, "b" => 2, "c" => 3,
    "l1" => 1, "l2" => 2, "l3" => 3)

function _terminal_name_to_int(name::String)::Int
    t = get(_TERMINAL_NAME_TO_INT, lowercase(name), nothing)
    t === nothing && throw(ArgumentError(
        "Unsupported terminal name '$name' — supported conventions: " *
        "\"1\"..\"4\", \"a\"/\"b\"/\"c\"/\"n\", \"L1\"/\"L2\"/\"L3\"/\"N\"."))
    t
end

function _terminal_map_to_connections(tmap::Vector, bus_id::String,
                                       terminal_int_map::Dict)::Vector{Int}
    bus_map = get(terminal_int_map, bus_id, Dict{String,Int}())
    [get(bus_map, string(t), _terminal_name_to_int(string(t))) for t in tmap]
end

"""
    _reduce_phase_bound(v, field, id) -> Float64

Reduce a per-phase voltage-bound array to the single scalar PMD requires.
Errors if the phase entries differ — PMD `vm_lb`/`vm_ub` cannot represent a
genuinely per-phase bound. Accepts a scalar for robustness.
"""
function _reduce_phase_bound(v, field::AbstractString, id)
    v isa AbstractVector || return Float64(v)
    isempty(v) && error("Bus '$id': `$field` is an empty array.")
    vals = Float64.(v)
    all(x -> isapprox(x, vals[1]; rtol=1e-9, atol=1e-9), vals) || error(
        "Bus '$id': `$field` = $vals has per-phase differences that PMD's scalar " *
        "vm_lb/vm_ub cannot represent. to_pmd supports only uniform per-phase bounds.")
    vals[1]
end

function _bus_to_pmd(b::Dict{String,Any}, vscale::Real, id)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), b)
    tnames = get(b, "terminal_names", String[])
    pmd["terminals"] = [_terminal_name_to_int(t) for t in tnames]

    grounded = get(b, "perfectly_grounded_terminals", String[])
    if !isempty(grounded)
        pmd["grounded"] = [_terminal_name_to_int(t) for t in grounded]
        pmd["rg"] = zeros(length(grounded))
        pmd["xg"] = zeros(length(grounded))
    end

    # voltage bounds: V → p.u. (approximate; exact requires per-bus vbase).
    # BMOPF v_min/v_max are per-phase arrays; PMD vm_lb/vm_ub are scalar per bus,
    # so reduce to a scalar only when every phase shares the same bound — a
    # genuinely per-phase bound cannot be represented and is an error.
    haskey(b, "v_min") && (pmd["vm_lb"] = _reduce_phase_bound(b["v_min"], "v_min", id) / vscale)
    haskey(b, "v_max") && (pmd["vm_ub"] = _reduce_phase_bound(b["v_max"], "v_max", id) / vscale)

    pmd["status"] = "ENABLED"
    pmd
end

function _line_to_pmd(l::Dict{String,Any},
                       terminal_int_map::Dict)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), l)
    pmd["f_bus"]  = l["bus_from"]
    pmd["t_bus"]  = l["bus_to"]
    pmd["length"] = get(l, "length", 1.0)
    haskey(l, "linecode") && (pmd["linecode"] = l["linecode"])

    pmd["f_connections"] = _terminal_map_to_connections(
        get(l, "terminal_map_from", String[]), l["bus_from"], terminal_int_map)
    pmd["t_connections"] = _terminal_map_to_connections(
        get(l, "terminal_map_to", String[]), l["bus_to"], terminal_int_map)

    pmd["status"] = "ENABLED"
    pmd
end

function _linecode_to_pmd(lc::Dict{String,Any})::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), lc)

    for (pmd_key, bmopf_prefix) in (("rs","R_series_"), ("xs","X_series_"),
                                     ("g_fr","G_from_"), ("g_to","G_to_"),
                                     ("b_fr","B_from_"), ("b_to","B_to_"))
        mat = _pattern_keys_to_matrix(lc, bmopf_prefix)
        mat !== nothing && (pmd[pmd_key] = mat)
    end

    haskey(lc, "i_max") && (pmd["cm_ub"] = lc["i_max"])
    haskey(lc, "s_max") && (pmd["sm_ub"] = lc["s_max"])
    pmd
end

function _voltage_source_to_pmd(vs::Dict{String,Any},
                                  terminal_int_map::Dict,
                                  vscale::Real)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), vs)
    pmd["bus"] = vs["bus"]
    pmd["connections"] = _terminal_map_to_connections(
        get(vs, "terminal_map", String[]), vs["bus"], terminal_int_map)

    haskey(vs, "v_magnitude") &&
        (pmd["vm"] = Float64.(vs["v_magnitude"]) ./ vscale)
    # radians → degrees
    haskey(vs, "v_angle") &&
        (pmd["va"] = Float64.(vs["v_angle"]) .* (180.0 / π))

    pmd["status"] = "ENABLED"
    pmd
end

function _load_to_pmd(l::Dict{String,Any},
                       terminal_int_map::Dict,
                       pscale::Real)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), l)
    pmd["bus"] = l["bus"]
    # PMD has no SINGLE_PHASE enum — 2-terminal loads are wye there
    cfg = get(l, "configuration", "WYE")
    pmd["configuration"] = cfg == "SINGLE_PHASE" ? "WYE" : cfg
    pmd["connections"]   = _terminal_map_to_connections(
        get(l, "terminal_map", String[]), l["bus"], terminal_int_map)

    haskey(l, "p_nom") && (pmd["pd_nom"] = Float64.(l["p_nom"]) ./ pscale)
    haskey(l, "q_nom") && (pmd["qd_nom"] = Float64.(l["q_nom"]) ./ pscale)

    haskey(l, "time_series") && (pmd["time_series"] = l["time_series"])
    pmd["status"] = "ENABLED"
    pmd
end

function _generator_to_pmd(g::Dict{String,Any},
                             terminal_int_map::Dict,
                             pscale::Real)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), g)
    pmd["bus"]           = g["bus"]
    pmd["configuration"] = get(g, "configuration", "WYE")
    pmd["connections"]   = _terminal_map_to_connections(
        get(g, "terminal_map", String[]), g["bus"], terminal_int_map)

    for (bmopf_k, pmd_k) in (("p_min","pg_lb"), ("p_max","pg_ub"),
                               ("q_min","qg_lb"), ("q_max","qg_ub"))
        haskey(g, bmopf_k) && (pmd[pmd_k] = Float64.(g[bmopf_k]) ./ pscale)
    end

    haskey(g, "time_series") && (pmd["time_series"] = g["time_series"])
    pmd["status"] = "ENABLED"
    pmd
end

function _shunt_to_pmd(s::Dict{String,Any},
                        terminal_int_map::Dict)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), s)
    pmd["bus"]         = s["bus"]
    pmd["connections"] = _terminal_map_to_connections(
        get(s, "terminal_map", String[]), s["bus"], terminal_int_map)

    gs = _pattern_keys_to_matrix(s, "G_")
    bs = _pattern_keys_to_matrix(s, "B_")
    gs !== nothing && (pmd["gs"] = gs)
    bs !== nothing && (pmd["bs"] = bs)

    pmd["status"] = "ENABLED"
    pmd
end

function _switch_to_pmd(sw::Dict{String,Any},
                         terminal_int_map::Dict)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), sw)
    pmd["f_bus"] = sw["bus_from"]
    pmd["t_bus"] = sw["bus_to"]
    pmd["state"] = get(sw, "open_switch", false) ? 0 : 1

    pmd["f_connections"] = _terminal_map_to_connections(
        get(sw, "terminal_map_from", String[]), sw["bus_from"], terminal_int_map)
    pmd["t_connections"] = _terminal_map_to_connections(
        get(sw, "terminal_map_to", String[]), sw["bus_to"], terminal_int_map)

    haskey(sw, "i_max") && (pmd["cm_ub"] = sw["i_max"])
    pmd["status"] = "ENABLED"
    pmd
end

function _transformers_to_pmd(xfmr_dict::Dict{String,Any},
                                terminal_int_map::Dict,
                                vscale::Real, pscale::Real)::Dict{String,Any}
    result = Dict{String,Any}()
    for (subtype, subtypes_dict) in xfmr_dict
        subtypes_dict isa Dict || continue
        for (id, xfmr) in subtypes_dict
            pmd_xfmr = _transformer_to_pmd(xfmr, subtype, terminal_int_map, vscale, pscale)
            result[id] = pmd_xfmr
        end
    end
    result
end

function _transformer_to_pmd(xfmr::Dict{String,Any}, subtype::String,
                               terminal_int_map::Dict,
                               vscale::Real, pscale::Real)::Dict{String,Any}
    pmd = _merge_pmd_extra(Dict{String,Any}(), xfmr)
    bus_from = get(xfmr, "bus_from", "")
    bus_to   = get(xfmr, "bus_to",   "")

    pmd["bus"] = [bus_from, bus_to]
    pmd["configuration"] = subtype in ("wye_delta",) ? ["WYE","DELTA"] :
                           subtype in ("delta_wye",) ? ["DELTA","WYE"] :
                           ["WYE","WYE"]

    f_conn = _terminal_map_to_connections(
        get(xfmr, "terminal_map_from", String[]), bus_from, terminal_int_map)
    t_conn = _terminal_map_to_connections(
        get(xfmr, "terminal_map_to", String[]), bus_to, terminal_int_map)
    pmd["connections"] = [f_conn, t_conn]

    if haskey(xfmr, "v_ref_from") && haskey(xfmr, "v_ref_to")
        pmd["vm_nom"] = [xfmr["v_ref_from"] / vscale, xfmr["v_ref_to"] / vscale]
    end
    haskey(xfmr, "s_rating") &&
        (pmd["sm_nom"] = [xfmr["s_rating"] / pscale, xfmr["s_rating"] / pscale])

    # BMOPF series impedances are Ω; PMD `rw`/`xsc` are per-unit on the
    # winding base. All multi-winding subtypes carry per-winding _from/_to
    # (has_r2/has_x2). A legacy single wye-side r_series/x_series (has_r1/
    # has_x1) on wye_delta/delta_wye is still inverted with an even split.
    has_r2 = haskey(xfmr, "r_series_from") && haskey(xfmr, "r_series_to")
    has_x2 = haskey(xfmr, "x_series_from") && haskey(xfmr, "x_series_to")
    has_r1 = haskey(xfmr, "r_series")
    has_x1 = haskey(xfmr, "x_series")
    if has_r1 || has_x1 || has_r2 || has_x2
        if haskey(xfmr, "v_ref_from") && haskey(xfmr, "v_ref_to") &&
           haskey(xfmr, "s_rating") && Float64(xfmr["s_rating"]) > 0
            s = Float64(xfmr["s_rating"])
            if subtype in ("wye_delta", "delta_wye") && (has_r1 || has_x1)
                v_ref_wye = subtype == "wye_delta" ? Float64(xfmr["v_ref_from"]) :
                                                     Float64(xfmr["v_ref_to"])
                z_base = v_ref_wye^2 / s
                # inverse of from_pmd lumping: split the total evenly
                has_r1 && (pmd["rw"] = fill(Float64(xfmr["r_series"]) / z_base / 2, 2))
                has_x1 && (pmd["xsc"] = [Float64(xfmr["x_series"]) / z_base])
            else
                z_base_from = Float64(xfmr["v_ref_from"])^2 / s
                z_base_to   = Float64(xfmr["v_ref_to"])^2   / s
                has_r2 && (pmd["rw"] = [Float64(xfmr["r_series_from"]) / z_base_from,
                                        Float64(xfmr["r_series_to"])   / z_base_to])
                # inverse of the even split in from_pmd: pair total = sum of halves
                has_x2 && (pmd["xsc"] = [Float64(xfmr["x_series_from"]) / z_base_from +
                                         Float64(xfmr["x_series_to"])   / z_base_to])
            end
        else
            @warn "Transformer: cannot convert r_series/x_series (Ω) to PMD p.u. — " *
                  "missing v_ref or s_rating. Winding impedance omitted."
        end
    end

    # No-load branch: BMOPF g_no_load/b_no_load (S) → PMD noloadloss/cmag
    # (both dimensionless, relative to s_rating). Inverse of from_pmd: g_no_load is
    # referred to the phase-to-ground stamping voltage V_LN = v_ref_from/√3 for a
    # 3-phase winding, or v_ref_from for single-phase (selected by phase count).
    has_g = haskey(xfmr, "g_no_load")
    has_b = haskey(xfmr, "b_no_load")
    if (has_g || has_b) &&
       haskey(xfmr, "v_ref_from") && haskey(xfmr, "s_rating") &&
       Float64(xfmr["s_rating"]) > 0
        vf    = Float64(xfmr["v_ref_from"])
        s     = Float64(xfmr["s_rating"])
        n_from_ph = count(!=("n"), Vector{String}(get(xfmr, "terminal_map_from", String[])))
        v_stamp = n_from_ph >= 3 ? vf / sqrt(3) : vf
        y_base = s / v_stamp^2
        G = has_g ? Float64(xfmr["g_no_load"]) : 0.0
        B = has_b ? Float64(xfmr["b_no_load"]) : 0.0
        pmd["noloadloss"] = G / y_base
        pmd["cmag"]       = sqrt(G^2 + B^2) / y_base
    elseif has_g || has_b
        @warn "Transformer: cannot convert g_no_load/b_no_load to PMD — " *
              "missing v_ref_from or s_rating. No-load branch omitted."
    end

    pmd["status"] = "ENABLED"
    pmd
end

# ---------------------------------------------------------------------------
# Shared utilities
# ---------------------------------------------------------------------------

"""
Reconstruct an n×n matrix from flat pattern keys, e.g. "R_series_1_1" → rs[1,1].
Returns `nothing` if no matching keys found.

For symmetric matrices stored in upper-triangular shorthand (only `i_j` with i≤j
present), the missing lower-triangle entry `i_j` is filled from `j_i` automatically.
Full storage always takes precedence: if both `i_j` and `j_i` are present, `i_j` is used.
"""
function _pattern_keys_to_matrix(d::Dict{String}, prefix::String)
    # find the size from existing keys; prefix ends with "_" so the
    # remaining suffix is "i_j" (e.g. "R_series_" + "1_2")
    n = 0
    for k in keys(d)
        if startswith(k, prefix)
            suffix = k[length(prefix)+1:end]
            m = match(r"^(\d+)_(\d+)$", suffix)
            m === nothing && continue
            i, j = parse(Int, m[1]), parse(Int, m[2])
            n = max(n, i, j)
        end
    end
    n == 0 && return nothing

    mat = zeros(n, n)
    for i in 1:n, j in 1:n
        key = "$(prefix)$(i)_$(j)"
        if haskey(d, key)
            mat[i,j] = Float64(d[key])
        elseif haskey(d, "$(prefix)$(j)_$(i)")
            # BMOPF stores symmetric matrices upper-triangular only
            mat[i,j] = Float64(d["$(prefix)$(j)_$(i)"])
        end
    end
    mat
end

"""
Merge any `_pmd` extra fields back into the PMD component dict.
"""
function _merge_pmd_extra(pmd::Dict{String,Any}, bmopf::Dict{String,Any})::Dict{String,Any}
    extra = get(bmopf, "_pmd", nothing)
    extra isa Dict || return pmd
    for (k, v) in extra
        pmd[k] = v
    end
    pmd
end
