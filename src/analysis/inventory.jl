"""
    _yd_clock(tm_del, tm_wye) -> Int

Derive IEC clock number from delta and wye terminal orderings.

From the BMOPF constraint N·V_Δ[1] = V_Y[ph₁] − V_Y[ph₂], setting the first
delta terminal as the 0° reference and solving for the angle of wye terminal '1':
  ψ_wye1 = −(δ[p_HV] + δ[p1] + arg(1 − e^{jΔ}))
where δ[t] ∈ {0°,−120°,+120°} for terminals {1,2,3} and clock = (−ψ_wye1/30) mod 12.
"""
function _yd_clock(tm_del::Vector{String}, tm_wye::Vector{String})::Int
    ph_wye = filter(t -> t != "n", tm_wye)
    (length(tm_del) < 1 || length(ph_wye) < 2) && return 0

    p_HV = tm_del[1]
    p1   = ph_wye[1]
    p2   = ph_wye[2]

    phase_angle = Dict{String,Int}("1" => 0, "2" => -120, "3" => 120)
    all(haskey(phase_angle, t) for t in (p_HV, p1, p2)) || return 0

    d_HV = phase_angle[p_HV]
    d1   = phase_angle[p1]
    d2   = phase_angle[p2]

    # arg(1 − e^{jΔ}): −30° when Δ≡+120°, +30° when Δ≡+240° (≡−120°)
    arg_t = mod(d2 - d1, 360) == 120 ? -30 : 30
    psi_a = -(d_HV + d1 + arg_t)
    return mod(round(Int, -psi_a / 30.0), 12)
end

"""
    _derive_vector_group(subtype, xfmr) -> String

Derive IEC 60076-style vector group from BMOPF transformer data.

- D/Y = delta/wye (uppercase = HV primary; lowercase = LV secondary)
- "n" suffix when neutral terminal is accessible on that winding
- Clock number derived from terminal ordering using `_yd_clock`
"""
function _derive_vector_group(subtype::String, xfmr::Dict{String,Any})::String
    tmfr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tmto = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    n_fr = "n" in tmfr
    n_to = "n" in tmto

    if subtype == "delta_wye"
        lv    = n_to ? "yn" : "y"
        clock = _yd_clock(tmfr, tmto)
        return "D$(lv)$(clock)"

    elseif subtype == "wye_delta"
        hv    = n_fr ? "YN" : "Y"
        # For Yd: secondary (delta) angle = −(wye angle from formula) → negate clock
        clock = mod(-_yd_clock(tmto, tmfr), 12)
        return "$(hv)d$(clock)"

    elseif subtype == "single_phase"
        ph_fr = count(t -> t != "n", tmfr)
        ph_to = count(t -> t != "n", tmto)
        if ph_fr >= 3 && ph_to >= 3
            hv = n_fr ? "YN" : "Y"
            lv = n_to ? "yn" : "y"
            return "$(hv)$(lv)0"
        else
            return "Ii0"
        end

    elseif subtype == "center_tap"
        return "Ii0"

    elseif subtype == "single_phase_autotransformer"
        # Single-phase autotransformer / step voltage regulator (in-phase).
        return "Ia0"

    elseif subtype == "open_delta_regulator"
        conn = uppercase(strip(string(get(xfmr, "connection", ""))))
        return isempty(conn) ? "OD" : "OD-$(conn)"

    elseif subtype == "n_winding"
        # Per-winding connection letters: winding 1 upper-case (reference), the
        # rest lower-case, with `n` appended when the winding carries a neutral.
        # (Full IEC 61378-1 clock notation is out of scope.)
        ws = _nw_windings(xfmr)
        isempty(ws) && return "—"
        letter(j, w) = begin
            base = w.connection == "DELTA" ? "d" : "y"
            base = j == 1 ? uppercase(base) : base
            _, neu = _nw_phase_terminals(w.terminal_map)
            neu === nothing ? base : base * "n"
        end
        return join(letter(j, w) for (j, w) in enumerate(ws))

    else
        return "—"
    end
end

"""
    inventory_analysis(net, findings) -> Dict{String,Any}

Count components and compute summary statistics for each component type.
Returns a dict keyed by component type name; each value is a sub-dict with
at least a `"total"` count and type-specific breakdowns.
"""
function inventory_analysis(net::Dict{String,Any},
                             findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    # --- Simple component types ---
    for comp_type in ("linecode", "voltage_source", "shunt", "switch",
                      "control_profile")
        components = get(net, comp_type, Dict())
        result[comp_type] = Dict{String,Any}("total" => length(components))
    end

    # --- Capacitors (count + total installed reactive at rated voltage) ---
    caps = get(net, "capacitor", Dict())
    q_installed = 0.0
    for (_, c) in caps
        c isa Dict || continue
        q = get(c, "q_rated", nothing)
        q isa AbstractVector && (q_installed += sum(Float64, q))
    end
    result["capacitor"] = Dict{String,Any}(
        "total" => length(caps), "q_rated_total" => q_installed)

    # --- Inverter ---
    inverters = get(net, "inverter", Dict())
    by_topology   = Dict{String,Int}()
    by_prime_mover = Dict{String,Int}()
    total_s_max = 0.0
    for (_, inv) in inverters
        inv isa Dict || continue
        topo = string(get(inv, "topology", "—"))
        by_topology[topo] = get(by_topology, topo, 0) + 1
        pm = string(get(inv, "prime_mover", "—"))
        by_prime_mover[pm] = get(by_prime_mover, pm, 0) + 1
        s = get(inv, "s_max", nothing)
        s isa AbstractVector && (total_s_max += sum(Float64(x) for x in s if x isa Number))
    end
    result["inverter"] = Dict{String,Any}(
        "total"           => length(inverters),
        "by_topology"     => by_topology,
        "by_prime_mover"  => by_prime_mover,
        "total_s_max_va"  => total_s_max
    )

    # --- Bus ---
    buses = get(net, "bus", Dict())
    by_phases = Dict{Int,Int}()
    for (_, b) in buses
        names = String.(get(b, "terminal_names", String[]))
        nn = _neutral_terminal(b)
        n_phases = count(t -> t != nn, names)
        by_phases[n_phases] = get(by_phases, n_phases, 0) + 1
    end
    result["bus"] = Dict{String,Any}(
        "total"      => length(buses),
        "by_n_phases" => by_phases
    )

    # --- Line ---
    lines = get(net, "line", Dict())
    with_lc = count(l -> haskey(l, "linecode"), values(lines))
    result["line"] = Dict{String,Any}(
        "total"        => length(lines),
        "with_linecode" => with_lc
    )

    # --- Load ---
    loads = get(net, "load", Dict())
    total_p   = 0.0
    total_q   = 0.0
    cfg_counts = Dict{String,Int}()
    for (_, l) in loads
        total_p += sum(Float64.(get(l, "p_nom", Float64[])))
        total_q += sum(Float64.(get(l, "q_nom", Float64[])))
        cfg = string(get(l, "configuration", "UNKNOWN"))
        cfg_counts[cfg] = get(cfg_counts, cfg, 0) + 1
    end
    result["load"] = Dict{String,Any}(
        "total"            => length(loads),
        "total_p_w"        => total_p,
        "total_q_var"      => total_q,
        "by_configuration" => cfg_counts
    )

    # --- Generator ---
    gens = get(net, "generator", Dict())
    total_p_cap = 0.0
    for (_, g) in gens
        total_p_cap += sum(Float64.(get(g, "p_max", Float64[])))
    end
    result["generator"] = Dict{String,Any}(
        "total"         => length(gens),
        "total_p_cap_w" => total_p_cap
    )

    # --- Transformer ---
    xfmr          = get(net, "transformer", Dict())
    by_type       = Dict{String,Int}()
    by_vg         = Dict{String,Int}()
    total_xfmr    = 0
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        n = length(sub)
        n == 0 && continue
        by_type[subtype] = n
        total_xfmr += n
        for (_, xf) in sub
            vg = _derive_vector_group(subtype, xf)
            by_vg[vg] = get(by_vg, vg, 0) + 1
        end
    end
    result["transformer"] = Dict{String,Any}(
        "total"          => total_xfmr,
        "by_type"        => by_type,
        "by_vector_group" => by_vg
    )

    result
end
