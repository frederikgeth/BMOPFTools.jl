"""
    inventory_analysis(net, findings) -> Dict{String,Any}

Count components and compute summary statistics for each component type.
Returns a dict keyed by component type name; each value is a sub-dict with
at least a `"total"` count and type-specific breakdowns.
"""
function inventory_analysis(net::Dict{String,Any},
                             findings::Vector{Finding}; phase_order=Dict())::Dict{String,Any}
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

    # --- IBR ---
    ibrs = get(net, "ibr", Dict())
    by_topology   = Dict{String,Int}()
    by_prime_mover = Dict{String,Int}()
    total_s_max = 0.0
    for (_, inv) in ibrs
        inv isa Dict || continue
        topo = string(get(inv, "topology", "—"))
        by_topology[topo] = get(by_topology, topo, 0) + 1
        pm = string(get(inv, "prime_mover", "—"))
        by_prime_mover[pm] = get(by_prime_mover, pm, 0) + 1
        s = get(inv, "s_max", nothing)
        s isa AbstractVector && (total_s_max += sum(Float64(x) for x in s if x isa Number))
    end
    result["ibr"] = Dict{String,Any}(
        "total"           => length(ibrs),
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
    phase_relations = Dict{String,Any}()
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        n = length(sub)
        n == 0 && continue
        by_type[subtype] = n
        total_xfmr += n
        phase_relations[subtype]=Dict{String,Any}()
        for (id, xf) in sub
            xf isa Dict || continue
            evidence=_transformer_phase_summary(net,subtype,xf;phase_order)
            phase_relations[subtype][id]=evidence
            vg=evidence["display_label"]
            by_vg[vg] = get(by_vg, vg, 0) + 1
        end
    end
    result["transformer"] = Dict{String,Any}(
        "total"          => total_xfmr,
        "by_type"        => by_type,
        "by_vector_group" => by_vg,
        "phase_relations" => phase_relations
    )

    # --- DC network (converter stations / MVDC-LVDC) ---
    dc_buses = get(net, "dc_bus", Dict())
    if !isempty(dc_buses) || !isempty(get(net, "dc_branch", Dict()))
        # Converter stations: groups of IBRs sharing a dc_bus.
        conv_by_bus = Dict{String,Int}()
        for (_, inv) in get(net, "ibr", Dict())
            inv isa Dict && haskey(inv, "dc_bus") || continue
            b = string(inv["dc_bus"])
            conv_by_bus[b] = get(conv_by_bus, b, 0) + 1
        end
        n_stations = count(>=(2), values(conv_by_bus))   # ≥2 converters = a station
        result["dc_network"] = Dict{String,Any}(
            "dc_bus"            => length(dc_buses),
            "dc_branch"         => length(get(net, "dc_branch", Dict())),
            "dc_grounding"      => length(get(net, "dc_grounding", Dict())),
            "dc_load"           => length(get(net, "dc_load", Dict())),
            "dc_source"         => length(get(net, "dc_source", Dict())),
            "converters"        => sum(values(conv_by_bus); init=0),
            "converter_stations" => n_stations,
        )
    end

    result
end
