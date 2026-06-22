"""
    from_pmd(eng::Dict{String,Any}) -> Dict{String,Any}

Convert a PowerModelsDistribution ENGINEERING model dictionary into a
BMOPF-format dictionary.

The conversion follows the field mapping documented in `docs/design/schema_mapping.md`.
Key transformations:

- Terminal integers → string names using a generated `terminal_names` array.
  PMD uses `[1,2,3,4]` where 4 is neutral; BMOPF uses string names.
  Generated names: `"1"`, `"2"`, `"3"`, `"n"` for standard 3-phase+neutral buses.
- PMD `f_connections`/`t_connections` int arrays → BMOPF `terminal_map_from/to` string arrays.
- PMD per-unit voltage bounds → SI (V) using `settings.voltage_scale_factor` and
  `vbases_default`.
- PMD power values scaled by `settings.power_scale_factor` → SI (W, var).
- PMD `va` in degrees → BMOPF `v_angle` in radians.
- PMD Enum values (WYE, DELTA, etc.) → strings.
- PMD `time_series` structure is preserved as-is (same convention).
- PMD transformer n-winding model → BMOPF transformer subtypes where determinable.

# Notes
- `generator` in PMD covers both `generator` and `voltage_source` components.
  PMD `voltage_source` objects are mapped to BMOPF `voltage_source` directly.
- Cost data from the MATHEMATICAL model is not available in the ENGINEERING
  model. Generator `cost` fields will be absent in the output unless present
  as custom fields in `eng`.
- Unknown/additional PMD fields are carried through under a `"_pmd"` sub-dict
  per component, preserving them without polluting the BMOPF namespace.
"""
function from_pmd(eng::Dict{String,Any};
                  add_slack_generator::Bool=true,
                  slack_cost::Float64=1.0,
                  meta::Union{Dict,Nothing}=nothing)::Dict{String,Any}
    net = Dict{String,Any}()

    settings = get(eng, "settings", Dict{String,Any}())
    vscale   = get(settings, "voltage_scale_factor", 1.0)
    pscale   = get(settings, "power_scale_factor",   1.0)
    vbases   = get(settings, "vbases_default", Dict{String,Any}())

    get(eng, "name", nothing) !== nothing && (net["name"] = eng["name"])

    # Bus terminal-name cache, computed once for all component conversions
    bus_terminals = _bus_terminal_names(eng)

    # buses
    if haskey(eng, "bus")
        net["bus"] = Dict{String,Any}()
        for (id, pmd_bus) in eng["bus"]
            net["bus"][id] = _bus_from_pmd(pmd_bus, id, vscale, vbases)
        end
    end

    # lines — self-loop grounding elements (earth terminal 5) become shunts
    if haskey(eng, "line")
        net["line"] = Dict{String,Any}()
        for (id, pmd_line) in eng["line"]
            f_bus  = get(pmd_line, "f_bus", nothing)
            t_bus  = get(pmd_line, "t_bus", nothing)
            t_conn = get(pmd_line, "t_connections", Int[])
            f_conn = get(pmd_line, "f_connections", Int[])

            if f_bus == t_bus && 5 in t_conn
                # Neutral-to-earth reactor: self-loop with PMD earth terminal → shunt
                s = _grounding_line_to_shunt(pmd_line)
                if s !== nothing
                    get!(net, "shunt", Dict{String,Any}())[id] = s
                end
                continue
            end
            if any(>(4), f_conn) || any(>(4), t_conn)
                @warn "from_pmd: line '$id' has terminals outside [1,4] — skipping"
                continue
            end
            net["line"][id] = _line_from_pmd(pmd_line, bus_terminals)
        end
    end

    # linecodes
    if haskey(eng, "linecode")
        net["linecode"] = Dict{String,Any}()
        for (id, pmd_lc) in eng["linecode"]
            net["linecode"][id] = _linecode_from_pmd(pmd_lc)
        end
    end

    # voltage sources
    if haskey(eng, "voltage_source")
        net["voltage_source"] = Dict{String,Any}()
        for (id, pmd_vs) in eng["voltage_source"]
            net["voltage_source"][id] = _voltage_source_from_pmd(pmd_vs, bus_terminals, vscale)
        end
    end

    # loads
    if haskey(eng, "load")
        net["load"] = Dict{String,Any}()
        for (id, pmd_load) in eng["load"]
            net["load"][id] = _load_from_pmd(pmd_load, bus_terminals, pscale)
        end
    end

    # generators
    if haskey(eng, "generator")
        net["generator"] = Dict{String,Any}()
        for (id, pmd_gen) in eng["generator"]
            net["generator"][id] = _generator_from_pmd(pmd_gen, bus_terminals, pscale)
        end
    end

    # Price the import slack. The OpenDSS circuit object is both a voltage
    # reference and an implicit unbounded power injection; the BMOPF
    # voltage_source captures both (it is the OPF current slack, see
    # ext/BMOPFOpfExt/source.jl). Attaching a per-phase cost gives the OPF
    # objective (generation cost) a well-posed meaning without a phantom generator.
    if add_slack_generator && haskey(net, "voltage_source")
        for (_, vs) in net["voltage_source"]
            vs isa Dict || continue
            haskey(vs, "cost") && continue
            phases = [t for t in get(vs, "terminal_map", String[]) if t != "n"]
            isempty(phases) && continue
            vs["cost"] = fill(slack_cost, length(phases))
        end
    end

    # shunts
    if haskey(eng, "shunt")
        net["shunt"] = Dict{String,Any}()
        for (id, pmd_shunt) in eng["shunt"]
            net["shunt"][id] = _shunt_from_pmd(pmd_shunt, bus_terminals)
        end
    end

    # switches
    if haskey(eng, "switch")
        net["switch"] = Dict{String,Any}()
        for (id, pmd_sw) in eng["switch"]
            net["switch"][id] = _switch_from_pmd(pmd_sw, bus_terminals)
        end
    end

    # transformers
    if haskey(eng, "transformer")
        net["transformer"] = _transformers_from_pmd(eng["transformer"], bus_terminals, vscale, pscale)
    end

    # time series — carry through as-is (same convention as PMD)
    if haskey(eng, "time_series")
        net["time_series"] = deepcopy(eng["time_series"])
    end

    net["meta"] = _build_meta(
        get(net, "meta", Dict{String,Any}()),
        meta,
    )
    # Keep _meta for internal traceability (not written by write_bmopf)
    net["_meta"] = Dict{String,Any}("source" => "pmd")

    net
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

"""
Build a cache of bus_id => terminal_names for connection mapping.
PMD terminals are integers; BMOPF uses strings.
Standard mapping: 1=>"1", 2=>"2", 3=>"3", 4=>"n" (neutral).
"""
function _bus_terminal_names(eng::Dict{String,Any})::Dict{String,Vector{String}}
    result = Dict{String,Vector{String}}()
    buses = get(eng, "bus", Dict())
    for (id, bus) in buses
        # Terminal 5 = OpenDSS earth reference (.0); not a BMOPF bus terminal
        terminals = filter(t -> 1 <= t <= 4, get(bus, "terminals", Int[]))
        result[id] = [_terminal_int_to_name(t) for t in terminals]
    end
    result
end

"""
Convert a PMD integer terminal id to a BMOPF terminal name.

NOTE: This library currently supports only the standard PMD convention
1,2,3 = phases, 4 = neutral ("n"). Nonstandard terminal numbering will
raise an error rather than silently mis-map.
"""
function _terminal_int_to_name(t::Int)::String
    1 <= t <= 4 || throw(ArgumentError(
        "Unsupported PMD terminal id $t — only 1,2,3 (phases) and 4 (neutral) are supported."))
    t == 4 ? "n" : string(t)
end

function _bus_from_pmd(pmd_bus::Dict{String,Any}, id::String,
                        vscale::Real, vbases::Dict)::Dict{String,Any}
    b = Dict{String,Any}()
    terminals = get(pmd_bus, "terminals", Int[])
    # Filter earth terminal before name conversion
    terminals = filter(t -> 1 <= t <= 4, terminals)
    b["terminal_names"] = [_terminal_int_to_name(t) for t in terminals]

    # grounded terminals — filter earth reference (terminal 5) from BMOPF view
    grounded_raw = get(pmd_bus, "grounded", Int[])
    if !isempty(grounded_raw)
        rg = get(pmd_bus, "rg", zeros(length(grounded_raw)))
        xg = get(pmd_bus, "xg", zeros(length(grounded_raw)))
        perfect = [_terminal_int_to_name(grounded_raw[i])
                   for i in eachindex(grounded_raw)
                   if 1 <= grounded_raw[i] <= 4 && rg[i] == 0.0 && xg[i] == 0.0]
        !isempty(perfect) && (b["perfectly_grounded_terminals"] = perfect)
    end

    # voltage base for this bus (V)
    vbase_kv = get(vbases, id, nothing)
    vbase_v  = vbase_kv !== nothing ? Float64(vbase_kv) * vscale : nothing

    # PMD's vbase is the transformer-rated voltage. Store it as v_declared so
    # augment_case can use it as the percentage-bound reference, falling back
    # to v_nom from voltage-level analysis only when this is absent.
    if vbase_v !== nothing
        b["v_declared"] = vbase_v
    end

    # voltage bounds: PMD vm_lb/vm_ub are in p.u. → scale to V. BMOPF v_min/v_max
    # are per-phase arrays (phase-to-ground), so map onto the phase terminals
    # (neutral excluded). PMD values may be scalar or per-terminal vectors.
    if vbase_v !== nothing
        tnames   = b["terminal_names"]
        nt       = _neutral_terminal(b)
        phase_ix = [k for k in eachindex(tnames) if tnames[k] != nt]
        _pmd_v_to_phase(v) =
            [Float64(v isa AbstractVector ? v[k] : v) * vbase_v for k in phase_ix]
        if haskey(pmd_bus, "vm_lb") && !isempty(phase_ix)
            b["v_min"] = _pmd_v_to_phase(pmd_bus["vm_lb"])
        end
        if haskey(pmd_bus, "vm_ub") && !isempty(phase_ix)
            b["v_max"] = _pmd_v_to_phase(pmd_bus["vm_ub"])
        end
    end

    _carry_extra(b, pmd_bus,
        ("terminals", "grounded", "rg", "xg", "vm_lb", "vm_ub", "status", "source_id"))
    b
end

function _line_from_pmd(pmd_line::Dict{String,Any},
                         bus_terminals::Dict{String,Vector{String}})::Dict{String,Any}
    l = Dict{String,Any}()
    l["bus_from"] = pmd_line["f_bus"]
    l["bus_to"]   = pmd_line["t_bus"]
    l["length"]   = Float64(get(pmd_line, "length", 1.0))

    if haskey(pmd_line, "linecode")
        l["linecode"] = pmd_line["linecode"]
    end

    f_conn = get(pmd_line, "f_connections", Int[])
    t_conn = get(pmd_line, "t_connections", Int[])
    l["terminal_map_from"] = [_terminal_int_to_name(c) for c in f_conn]
    l["terminal_map_to"]   = [_terminal_int_to_name(c) for c in t_conn]

    _carry_extra(l, pmd_line,
        ("f_bus", "t_bus", "length", "linecode", "f_connections", "t_connections",
         "status", "source_id"))
    l
end

# Convert a PMD neutral-to-earth self-loop line (reactor.X with bus2=busname.0)
# into a BMOPF shunt. PMD assigns earth terminal as id 5 (OpenDSS `.0`).
function _grounding_line_to_shunt(pmd_line::Dict{String,Any})
    f_conn = filter(t -> 1 <= t <= 4, get(pmd_line, "f_connections", Int[]))
    isempty(f_conn) && return nothing

    rs = get(pmd_line, "rs", nothing)
    isnothing(rs) && return nothing

    xs     = get(pmd_line, "xs", nothing)
    R      = Float64(rs[1,1])
    X      = isnothing(xs) ? 0.0 : Float64(xs[1,1])
    denom  = R^2 + X^2

    s = Dict{String,Any}(
        "bus"          => pmd_line["f_bus"],
        "terminal_map" => _terminal_int_to_name.(f_conn),
        "G_1_1"        => denom > 0 ? R / denom : 0.0,
        "B_1_1"        => denom > 0 ? -X / denom : 0.0,
    )
    _carry_extra(s, pmd_line,
        ("f_bus", "t_bus", "f_connections", "t_connections",
         "rs", "xs", "length", "status", "source_id"))
    s
end

function _linecode_from_pmd(pmd_lc::Dict{String,Any})::Dict{String,Any}
    lc = Dict{String,Any}()

    # rs, xs are matrices in PMD — flatten to R_series{ij}, X_series{ij}
    for (pmd_key, bmopf_prefix) in (("rs", "R_series_"), ("xs", "X_series_"),
                                     ("g_fr", "G_from_"), ("g_to", "G_to_"),
                                     ("b_fr", "B_from_"), ("b_to", "B_to_"))
        mat = get(pmd_lc, pmd_key, nothing)
        mat === nothing && continue
        _matrix_to_pattern_keys!(lc, mat, bmopf_prefix)
    end

    for (pmd_key, bmopf_key) in (("cm_ub", "i_max"), ("sm_ub", "s_max"))
        haskey(pmd_lc, pmd_key) && (lc[bmopf_key] = pmd_lc[pmd_key])
    end

    _carry_extra(lc, pmd_lc,
        ("rs", "xs", "g_fr", "g_to", "b_fr", "b_to", "cm_ub", "sm_ub", "source_id"))
    lc
end

function _voltage_source_from_pmd(pmd_vs::Dict{String,Any},
                                   bus_terminals::Dict{String,Vector{String}},
                                   vscale::Real)::Dict{String,Any}
    vs = Dict{String,Any}()
    vs["bus"] = pmd_vs["bus"]

    conn = get(pmd_vs, "connections", Int[])
    # A source whose neutral is bonded to earth (DSS `bus.0`) carries the
    # earth terminal 5 in its connections. vm/va align with connections,
    # so filter all three with the same mask.
    keep = [i for (i, c) in enumerate(conn) if 1 <= c <= 4]
    vs["terminal_map"] = [_terminal_int_to_name(conn[i]) for i in keep]

    # vm in PMD is p.u. relative to voltage_scale_factor — store in V
    if haskey(pmd_vs, "vm")
        vm = Float64.(pmd_vs["vm"])
        length(vm) == length(conn) && (vm = vm[keep])
        vs["v_magnitude"] = vm .* vscale
    end
    # va in PMD is degrees — BMOPF uses radians
    if haskey(pmd_vs, "va")
        va = Float64.(pmd_vs["va"])
        length(va) == length(conn) && (va = va[keep])
        vs["v_angle"] = va .* (π / 180.0)
    end

    _carry_extra(vs, pmd_vs, ("bus", "connections", "vm", "va", "status", "source_id"))
    vs
end

function _load_from_pmd(pmd_load::Dict{String,Any},
                         bus_terminals::Dict{String,Vector{String}},
                         pscale::Real)::Dict{String,Any}
    l = Dict{String,Any}()
    l["bus"] = pmd_load["bus"]

    conn = get(pmd_load, "connections", Int[])
    l["terminal_map"]  = [_terminal_int_to_name(c) for c in conn]

    # TF spec: reclassify 2-terminal loads by terminal type.
    # PMD labels all 2-terminal loads WYE regardless of connection.
    # If both terminals are phase conductors (neither is neutral=4), the
    # load is connected phase-to-phase → DELTA.
    # If one terminal is the neutral (4), it is phase-to-neutral → SINGLE_PHASE.
    cfg = string(pmd_load["configuration"])
    l["configuration"] = if length(conn) == 2 && !any(c == 4 for c in conn)
        "DELTA"
    elseif length(conn) == 2
        "SINGLE_PHASE"
    else
        cfg
    end

    if haskey(pmd_load, "pd_nom")
        l["p_nom"] = Float64.(pmd_load["pd_nom"]) .* pscale
    end
    if haskey(pmd_load, "qd_nom")
        l["q_nom"] = Float64.(pmd_load["qd_nom"]) .* pscale
    end

    # carry time_series refs unchanged
    haskey(pmd_load, "time_series") && (l["time_series"] = pmd_load["time_series"])

    _carry_extra(l, pmd_load,
        ("bus", "configuration", "connections", "pd_nom", "qd_nom",
         "time_series", "status", "source_id"))
    l
end

function _generator_from_pmd(pmd_gen::Dict{String,Any},
                               bus_terminals::Dict{String,Vector{String}},
                               pscale::Real)::Dict{String,Any}
    g = Dict{String,Any}()
    g["bus"]           = pmd_gen["bus"]
    g["configuration"] = string(pmd_gen["configuration"])

    conn = get(pmd_gen, "connections", Int[])
    g["terminal_map"] = [_terminal_int_to_name(c) for c in conn]

    for (pmd_k, bmopf_k) in (("pg_lb","p_min"), ("pg_ub","p_max"),
                               ("qg_lb","q_min"), ("qg_ub","q_max"))
        if haskey(pmd_gen, pmd_k)
            g[bmopf_k] = Float64.(pmd_gen[pmd_k]) .* pscale
        end
    end

    haskey(pmd_gen, "time_series") && (g["time_series"] = pmd_gen["time_series"])

    _carry_extra(g, pmd_gen,
        ("bus", "configuration", "connections", "pg_lb", "pg_ub",
         "qg_lb", "qg_ub", "time_series", "status", "source_id"))
    g
end

function _shunt_from_pmd(pmd_shunt::Dict{String,Any},
                          bus_terminals::Dict{String,Vector{String}})::Dict{String,Any}
    s = Dict{String,Any}()
    s["bus"] = pmd_shunt["bus"]

    conn = get(pmd_shunt, "connections", Int[])
    s["terminal_map"] = [_terminal_int_to_name(c) for c in conn]

    # gs, bs are matrices — flatten to G{ij}, B{ij}
    gs = get(pmd_shunt, "gs", nothing)
    bs = get(pmd_shunt, "bs", nothing)
    gs !== nothing && _matrix_to_pattern_keys!(s, gs, "G_")
    bs !== nothing && _matrix_to_pattern_keys!(s, bs, "B_")

    _carry_extra(s, pmd_shunt, ("bus", "connections", "gs", "bs", "status", "source_id"))
    s
end

function _switch_from_pmd(pmd_sw::Dict{String,Any},
                           bus_terminals::Dict{String,Vector{String}})::Dict{String,Any}
    sw = Dict{String,Any}()
    sw["bus_from"] = pmd_sw["f_bus"]
    sw["bus_to"]   = pmd_sw["t_bus"]

    # PMD state: OPEN=0/false, CLOSED=1/true → BMOPF open_switch is inverted
    state = get(pmd_sw, "state", 1)  # default closed
    sw["open_switch"] = (state == 0 || state == false || string(state) == "OPEN")

    f_conn = get(pmd_sw, "f_connections", Int[])
    t_conn = get(pmd_sw, "t_connections", Int[])
    sw["terminal_map_from"] = [_terminal_int_to_name(c) for c in f_conn]
    sw["terminal_map_to"]   = [_terminal_int_to_name(c) for c in t_conn]

    haskey(pmd_sw, "cm_ub") && (sw["i_max"] = pmd_sw["cm_ub"])

    _carry_extra(sw, pmd_sw,
        ("f_bus", "t_bus", "state", "f_connections", "t_connections",
         "cm_ub", "status", "source_id"))
    sw
end

function _transformers_from_pmd(pmd_xfmr_dict::Dict{String,Any},
                                  bus_terminals::Dict{String,Vector{String}},
                                  vscale::Real, pscale::Real)::Dict{String,Any}
    result = Dict{String,Any}()

    for (id, pmd_xfmr) in pmd_xfmr_dict
        pmd_xfmr isa Dict || continue
        subtype, bmopf_xfmr = _classify_transformer(id, pmd_xfmr, bus_terminals, vscale, pscale)
        if !haskey(result, subtype)
            result[subtype] = Dict{String,Any}()
        end
        result[subtype][id] = bmopf_xfmr
    end

    result
end

function _classify_transformer(id::String, pmd_xfmr::Dict{String,Any},
                                 bus_terminals::Dict{String,Vector{String}},
                                 vscale::Real, pscale::Real)
    buses   = get(pmd_xfmr, "bus",           String[])
    configs = get(pmd_xfmr, "configuration", Any[])
    nw      = get(pmd_xfmr, "nwinding",      length(buses))

    config_strs = [string(c) for c in configs]

    subtype = if nw == 3 && length(config_strs) >= 1 && config_strs[1] in ("WYE","SINGLE_PHASE")
        "center_tap"
    elseif nw == 2 && config_strs == ["WYE", "DELTA"]
        "wye_delta"
    elseif nw == 2 && config_strs == ["DELTA", "WYE"]
        "delta_wye"
    elseif nw == 2 && config_strs == ["WYE", "WYE"]
        "single_phase"
    else
        @warn "Transformer '$id': configuration $(config_strs) with $nw winding(s) " *
              "does not match a known BMOPF subtype; falling back to 'single_phase'. " *
              "Verify this is correct."
        "single_phase"
    end

    xfmr = Dict{String,Any}()
    xfmr["bus_from"] = length(buses) >= 1 ? buses[1] : ""
    xfmr["bus_to"]   = length(buses) >= 2 ? buses[2] : ""

    conns = get(pmd_xfmr, "connections", Vector{Any}[])
    if length(conns) >= 1
        xfmr["terminal_map_from"] = _winding_terminal_names(
            conns[1], xfmr["bus_from"], bus_terminals, id)
    end
    if length(conns) >= 2
        xfmr["terminal_map_to"] = _winding_terminal_names(
            conns[2], xfmr["bus_to"], bus_terminals, id)
    end

    # PMD cycles the wye-secondary connections by one position for delta_wye
    # (e.g. [1,2,3,4] → [2,3,1,4]).  Normalise to natural phase order so that
    # terminal_map_to[k] corresponds to physical phase k.
    if subtype == "delta_wye" && haskey(xfmr, "terminal_map_to")
        tm = xfmr["terminal_map_to"]
        phase_terms   = sort(filter(t -> t != "n", tm))
        neutral_terms = filter(t -> t == "n", tm)
        xfmr["terminal_map_to"] = vcat(phase_terms, neutral_terms)
    end

    vm_nom = get(pmd_xfmr, "vm_nom", nothing)
    if vm_nom !== nothing && length(vm_nom) >= 2
        xfmr["v_ref_from"] = Float64(vm_nom[1]) * vscale
        xfmr["v_ref_to"]   = Float64(vm_nom[2]) * vscale
    end

    sm_nom = get(pmd_xfmr, "sm_nom", nothing)
    if sm_nom !== nothing && !isempty(sm_nom)
        # PMD sm_nom is in power-scale units; BMOPF s_rating is VA
        xfmr["s_rating"] = Float64(sm_nom[1]) * pscale
    end

    # Series impedances: PMD `rw` (per winding) and `xsc` (per winding pair)
    # are per-unit on the winding base. BMOPF wants Ω.
    #
    # All multi-winding subtypes use per-winding `_from`/`_to` fields. The
    # OPF models a per-winding T behind the ideal transform (matches the
    # OpenDSS / PMD `eng2math` loss network). Resistance maps per winding;
    # for a 2-winding unit PMD's star conversion places the entire pair
    # leakage `xsc[1]` on winding 1 (from side), zero on winding 2.
    rw  = get(pmd_xfmr, "rw",  nothing)
    xsc = get(pmd_xfmr, "xsc", nothing)
    if rw !== nothing || xsc !== nothing
        if haskey(xfmr, "v_ref_from") && haskey(xfmr, "v_ref_to") && haskey(xfmr, "s_rating") &&
           xfmr["s_rating"] > 0
            z_base_from = xfmr["v_ref_from"]^2 / xfmr["s_rating"]
            z_base_to   = xfmr["v_ref_to"]^2   / xfmr["s_rating"]
            if subtype == "center_tap" && xsc !== nothing && length(xsc) >= 3
                # 3-winding star (Steinmetz) network. PMD `xsc` order is
                # [xhl, xht, xlt]; from = winding 1 (HV), to = winding 2 (one
                # leg). Symmetric center-tap: x_series_to applies per leg.
                xhl, xht, xlt = Float64(xsc[1]), Float64(xsc[2]), Float64(xsc[3])
                xfmr["x_series_from"] = (xhl + xht - xlt) / 2 * z_base_from
                xfmr["x_series_to"]   = (xhl + xlt - xht) / 2 * z_base_to
                if rw !== nothing && length(rw) >= 2
                    xfmr["r_series_from"] = Float64(rw[1]) * z_base_from
                    xfmr["r_series_to"]   = Float64(rw[2]) * z_base_to
                end
            else
                if rw !== nothing && length(rw) >= 2
                    from_is_delta_r = length(config_strs) >= 1 && config_strs[1] == "DELTA"
                    to_is_delta_r   = length(config_strs) >= 2 && config_strs[2] == "DELTA"
                    xfmr["r_series_from"] = Float64(rw[1]) * z_base_from * (from_is_delta_r ? sqrt(3) : 1.0)
                    xfmr["r_series_to"]   = Float64(rw[2]) * z_base_to   * (to_is_delta_r   ? sqrt(3) : 1.0)
                end
                # xsc[1] is the total from↔to leakage reactance (p.u.). Split
                # equally between windings to match OpenDSS's symmetric T-model.
                # (PMD's star-conversion places it all on winding 1, but the
                # BMOPF T-model needs per-winding values in each winding's own Ω.)
                #
                # √3 scaling for delta windings: the BMOPF voltage constraint uses
                # the winding terminal current variable (line current), but the
                # series-arm voltage drop is Z_arm × I_arm. For a delta connection
                # the balanced relationship is |I_terminal| = √3 × |I_arm|, so the
                # arm impedance used in the constraint must be divided by √3 to keep
                # Z_arm × I_arm correct — equivalently the stored x_series value
                # (which multiplies the terminal current) must be x_arm / √3.
                # Combining: x_series_delta = (xsc/2 × z_base_delta) × √3 / √3 ... the net
                # factor for the BMOPF convention turns out to be +√3 (see derivation
                # in docs/src/methodology.md §transformer T-model).
                if xsc !== nothing && !isempty(xsc)
                    # from-side (winding 1) scaling
                    from_is_delta = length(config_strs) >= 1 && config_strs[1] == "DELTA"
                    to_is_delta   = length(config_strs) >= 2 && config_strs[2] == "DELTA"
                    x_half_from = Float64(xsc[1]) / 2 * z_base_from * (from_is_delta ? sqrt(3) : 1.0)
                    x_half_to   = Float64(xsc[1]) / 2 * z_base_to   * (to_is_delta   ? sqrt(3) : 1.0)
                    xfmr["x_series_from"] = x_half_from
                    xfmr["x_series_to"]   = x_half_to
                end
            end
        else
            @warn "Transformer '$id': cannot convert winding impedance rw/xsc (p.u.) to Ω — " *
                  "missing v_ref or s_rating. Impedance omitted (treated as lossless); " *
                  "raw p.u. values preserved under '_pmd'."
            # keep raw p.u. values recoverable
            extra = get!(xfmr, "_pmd", Dict{String,Any}())
            rw  !== nothing && (extra["rw_pu"]  = rw)
            xsc !== nothing && (extra["xsc_pu"] = xsc)
        end
    end

    # No-load branch: PMD `noloadloss` (P_noload/S_rated) and `cmag`
    # (|I_mag|/I_rated) → BMOPF g_no_load/b_no_load (S) referred to from side.
    # OpenDSS places the no-load branch on winding 1 (from side).
    #
    # The OPF model stamps this shunt phase-to-GROUND at the from bus, which sits
    # at the line-to-neutral voltage V_LN = v_ref_from/√3 for a 3-phase winding
    # (v_ref_from is the line-to-line value). The conductance must therefore be
    # referred to V_LN so that the total core loss g_no_load·V_LN² = noloadloss·S
    # matches OpenDSS. Single-phase windings stamp at v_ref_from directly (V_LN²
    # would over-count); the from-side phase count selects the right base.
    #   G = P_noload / V_LN²  = noloadloss · s_rating / V_LN²
    #   |Y| = cmag · s_rating / V_LN²
    #   B = sqrt(|Y|² − G²)  (capacitive convention: B > 0 draws lagging I)
    noloadloss = Float64(get(pmd_xfmr, "noloadloss", 0.0))
    cmag       = Float64(get(pmd_xfmr, "cmag",       0.0))
    if (noloadloss > 0.0 || cmag > 0.0) &&
       haskey(xfmr, "v_ref_from") && haskey(xfmr, "s_rating") && xfmr["s_rating"] > 0
        vf  = Float64(xfmr["v_ref_from"])
        s   = Float64(xfmr["s_rating"])
        n_from_ph = count(!=("n"), Vector{String}(get(xfmr, "terminal_map_from", String[])))
        v_stamp = n_from_ph >= 3 ? vf / sqrt(3) : vf   # phase-to-ground stamping voltage
        y_base = s / v_stamp^2
        G = noloadloss * y_base
        Y_mag = cmag * y_base
        B = Y_mag^2 > G^2 ? sqrt(Y_mag^2 - G^2) : 0.0
        G > 0.0 && (xfmr["g_no_load"] = G)
        B > 0.0 && (xfmr["b_no_load"] = B)
    elseif (noloadloss > 0.0 || cmag > 0.0)
        @warn "Transformer '$id': cannot convert noloadloss/cmag to S — " *
              "missing v_ref_from or s_rating. No-load branch omitted."
    end

    _carry_extra(xfmr, pmd_xfmr,
        ("bus", "configuration", "connections", "vm_nom", "sm_nom",
         "rw", "xsc", "noloadloss", "cmag", "nwinding", "status", "source_id"))

    subtype, xfmr
end

"""
Convert a transformer winding's PMD connections to BMOPF terminal names.

PMD terminal 5 (OpenDSS `.0`) on a winding means the star point is bonded
directly to earth. The TF spec requires the wye map to carry the neutral
(length 4 for delta_wye/wye_delta), so the earth bond is re-routed to the
bus's neutral terminal when one exists. NOTE: combined with that bus's
grounding shunt this earths the star point through the grounding impedance
rather than solidly — flagged with a warning so the modeling change is
visible.
"""
function _winding_terminal_names(conns, bus_id::AbstractString,
                                  bus_terminals::Dict{String,Vector{String}},
                                  id::String)::Vector{String}
    names = String[]
    bus_names = get(bus_terminals, bus_id, String[])
    for c in conns
        if 1 <= c <= 4
            push!(names, _terminal_int_to_name(c))
        elseif c == 5
            if "n" in bus_names && !("n" in names)
                @warn "Transformer '$id': star point earthed directly in source " *
                      "data (terminal 5); re-routed to bus '$bus_id' neutral to " *
                      "satisfy the spec terminal map — earthing now goes through " *
                      "that bus's grounding impedance." maxlog=1
                push!(names, "n")
            else
                @warn "Transformer '$id': dropping earth terminal on winding at " *
                      "bus '$bus_id' (no neutral terminal available)." maxlog=1
            end
        end
    end
    names
end

# ---------------------------------------------------------------------------
# Utility — matrix flattening and extra-field passthrough
# ---------------------------------------------------------------------------

"""
Flatten an n×n matrix into pattern-key fields, e.g.:
    rs[1,1] → "R_series_1_1"
    rs[1,2] → "R_series_1_2"
"""
function _matrix_to_pattern_keys!(d::Dict{String,Any}, mat, prefix::String)
    m = _to_matrix(mat)
    m === nothing && return
    n = size(m, 1)
    for i in 1:n, j in 1:n
        d["$(prefix)$(i)_$(j)"] = Float64(m[i,j])
    end
end

function _to_matrix(x)
    x isa AbstractMatrix && return x
    if x isa AbstractVector
        isempty(x) && return nothing
        if x[1] isa AbstractVector
            # PMD JSON convention: outer vector = rows. Build row-wise explicitly
            # so asymmetric matrices (e.g. g_fr) keep correct orientation.
            n_rows = length(x)
            n_cols = length(x[1])
            all(length(row) == n_cols for row in x) || return nothing
            m = zeros(n_rows, n_cols)
            for i in 1:n_rows, j in 1:n_cols
                m[i, j] = Float64(x[i][j])
            end
            return m
        end
    end
    nothing
end

"""
Carry unrecognised PMD fields through under `"_pmd"` sub-dict,
preserving them without polluting the BMOPF namespace.
"""
function _carry_extra(bmopf::Dict{String,Any}, pmd::Dict{String,Any},
                       known_keys)
    extra = Dict{String,Any}()
    known_set = Set(string.(known_keys))
    for (k, v) in pmd
        string(k) in known_set && continue
        startswith(string(k), "_") && continue
        extra[string(k)] = v
    end
    isempty(extra) || (bmopf["_pmd"] = extra)
    nothing
end
