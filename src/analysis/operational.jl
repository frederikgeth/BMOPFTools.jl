"""
    operational_analysis(net, findings) -> Dict{String,Any}

Compute operational loading statistics:
- Total load and generation
- Load by voltage level and configuration
- Transformer utilisation at nominal setpoints
- Line thermal headroom
- Generation/load ratio
"""
function operational_analysis(net::Dict{String,Any},
                               findings::Vector{Finding};
                               config::Dict=_DEFAULT_CONFIG)::Dict{String,Any}
    result = Dict{String,Any}()

    # --- Total load ---
    loads = get(net, "load", Dict())
    total_p_w   = 0.0
    total_q_var = 0.0
    for (_, l) in loads
        total_p_w   += sum(Float64.(get(l, "p_nom", Float64[])))
        total_q_var += sum(Float64.(get(l, "q_nom", Float64[])))
    end
    total_s_va = hypot(total_p_w, total_q_var)
    total_pf   = total_s_va > 0 ? total_p_w / total_s_va : 1.0
    result["total_load"] = Dict{String,Any}(
        "p_w"   => total_p_w,
        "q_var" => total_q_var,
        "s_va"  => total_s_va,
        "pf"    => total_pf,
        "pf_lag_lead" => total_q_var >= 0 ? "lagging" : "leading"
    )

    # --- Total generation capacity ---
    gens = get(net, "generator", Dict())
    total_p_cap = 0.0
    total_q_cap = 0.0
    for (_, g) in gens
        total_p_cap += sum(Float64.(get(g, "p_max", Float64[])))
        total_q_cap += sum(Float64.(get(g, "q_max", Float64[])))
    end
    result["total_generation_capacity"] = Dict{String,Any}(
        "p_max_w"   => total_p_cap,
        "q_max_var" => total_q_cap
    )
    result["generation_load_ratio"] =
        total_p_w > 0 ? round(100.0 * total_p_cap / total_p_w, digits=1) : nothing

    if total_p_cap < total_p_w * 0.05
        push!(findings, Finding(WARNING, "W.OPS.IMPORT_DEPENDENT", :operational, :network, nothing,
            "Network is heavily import-dependent: local generation capacity " *
            "($(round(total_p_cap/1e6, digits=2)) MW) is less than 5% of total load " *
            "($(round(total_p_w/1e6, digits=2)) MW).",
            nothing))
    end

    # --- Load by configuration ---
    cfg_p = Dict{String,Float64}()
    for (_, l) in loads
        cfg = string(get(l, "configuration", "UNKNOWN"))
        cfg_p[cfg] = get(cfg_p, cfg, 0.0) + sum(Float64.(get(l, "p_nom", Float64[])))
    end
    result["load_by_configuration"] = cfg_p

    # --- Transformer utilisation ---
    xfmr = get(net, "transformer", Dict())
    xfmr_util = Dict{String,Any}[]

    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            s_rating = Float64(get(t, "s_rating", 0.0))
            s_rating <= 0 && continue

            # Estimate loading: sum all loads downstream of this transformer
            t_bus = get(t, "bus_to", nothing)
            f_bus = get(t, "bus_from", nothing)
            (t_bus === nothing || f_bus === nothing) && continue
            s_load = _downstream_load(net, id, f_bus, t_bus)
            util_pct = round(100.0 * s_load / s_rating, digits=1)

            entry = Dict{String,Any}(
                "id"           => id,
                "subtype"      => subtype,
                "s_rating_va"  => s_rating,
                "s_load_va"    => s_load,
                "utilisation_pct" => util_pct
            )
            push!(xfmr_util, entry)

            if util_pct > 90.0
                push!(findings, Finding(WARNING, "W.OPS.XFMR_OVERLOADED", :operational,
                    :transformer, id,
                    "Transformer '$id' is at $(util_pct)% utilisation at nominal load — little OPF headroom.",
                    Dict{String,Any}("id" => id, "utilisation_pct" => util_pct)))
            end
        end
    end
    result["transformer_utilisation"] = xfmr_util

    # --- Line thermal coverage ---
    lines = get(net, "line", Dict())
    n_lines = length(lines)
    linecodes = get(net, "linecode", Dict())

    n_with_thermal = count(lines) do (_, l)
        lc_id = get(l, "linecode", nothing)
        lc = lc_id !== nothing ? get(linecodes, string(lc_id), Dict()) : Dict()
        haskey(l, "i_max") || haskey(l, "s_max") ||
        haskey(lc, "i_max") || haskey(lc, "s_max")
    end

    result["line_thermal_coverage"] = Dict{String,Any}(
        "n_lines"             => n_lines,
        "n_with_thermal_limit" => n_with_thermal,
        "n_unconstrained"     => n_lines - n_with_thermal,
        "pct_constrained"     => n_lines > 0 ?
            round(100.0 * n_with_thermal / n_lines, digits=1) : 0.0
    )
    if n_lines > 0 && n_with_thermal < n_lines
        push!(findings, Finding(WARNING, "W.OPS.LINE_UNCONSTRAINED", :operational, :line, nothing,
            "$(n_lines - n_with_thermal) of $n_lines lines have no thermal limit (i_max or s_max) — OPF thermal constraints will be missing.",
            Dict{String,Any}("n_unconstrained" => n_lines - n_with_thermal)))
    end

    # --- Unloaded phases per galvanic zone ---
    buses = get(net, "bus", Dict())
    zones = _galvanic_zones(net)
    unloaded_findings = Tuple{String,String,String}[]   # (zone_label, terminal, bus_list_hint)

    for zone in zones
        # Phase terminals present anywhere in this zone (exclude neutral)
        phase_present = Set{String}()
        for bid in zone
            b = get(buses, bid, Dict())
            nt = _neutral_terminal(b)
            for t in get(b, "terminal_names", String[])
                string(t) != nt && push!(phase_present, string(t))
            end
        end
        isempty(phase_present) && continue

        # Phase terminals actually connected to a load in this zone
        phase_loaded = Set{String}()
        for (_, l) in loads
            get(l, "bus", "") in zone || continue
            nt_bus = _neutral_terminal(get(buses, get(l, "bus", ""), Dict()))
            for t in get(l, "terminal_map", [])
                string(t) != nt_bus && push!(phase_loaded, string(t))
            end
        end

        # Identify a label for this zone (source bus if present, else smallest bus name)
        vsrc_buses = Set(string(get(vs, "bus", ""))
                         for (_, vs) in get(net, "voltage_source", Dict()))
        zone_label = let src = intersect(zone, vsrc_buses)
            isempty(src) ? minimum(zone) : first(src)
        end

        for t in sort(collect(setdiff(phase_present, phase_loaded)))
            push!(unloaded_findings, (zone_label, t, zone_label))
        end
    end

    if !isempty(unloaded_findings)
        for (zone_label, terminal, _) in unloaded_findings
            push!(findings, Finding(INFO, "I.OPS.UNLOADED_PHASE", :operational,
                :network, nothing,
                "Galvanic zone anchored at bus '$zone_label' has no load connected " *
                "to phase terminal '$terminal'.",
                Dict{String,Any}("zone_anchor" => zone_label, "terminal" => terminal)))
        end
    end
    result["unloaded_phase_findings"] = length(unloaded_findings)

    # --- Electrical-length plausibility per galvanic zone ---
    result["feeder_length"] = _feeder_length_check(net, zones, findings, config)

    result
end

"""
Flag galvanic zones whose electrical reach is implausible for their voltage
band. For each zone, the reach is the longest line/cable distance (Σ line
`length`, m) from the zone's source/anchor bus to its farthest bus — i.e. the
feeder reach. It is compared to the band's `reach_short_m` / `reach_long_m`
thresholds (`config["operational"]["feeder_length"]`); a threshold of 0 disables
that side. Emits `I.OPS.FEEDER_LONG` / `I.OPS.FEEDER_SHORT` and returns one
summary entry per zone with a reach value.
"""
function _feeder_length_check(net::Dict{String,Any},
                               zones::Vector{Set{String}},
                               findings::Vector{Finding},
                               config::Dict)::Vector{Dict{String,Any}}
    cfg = _feeder_length_cfg(config)
    v_nom = _assign_nominal_voltages(net)
    vsrc_buses = Set(string(get(vs, "bus", ""))
                     for (_, vs) in get(net, "voltage_source", Dict()) if vs isa Dict)

    summary = Dict{String,Any}[]
    for zone in zones
        length(zone) < 2 && continue   # a single bus has no reach

        anchor = let src = intersect(zone, vsrc_buses)
            isempty(src) ? minimum(zone) : first(src)
        end

        # Zone nominal voltage (per-conductor V): anchor first, else any bus.
        v = get(v_nom, anchor, nothing)
        if v === nothing
            for b in zone
                haskey(v_nom, b) && (v = v_nom[b]; break)
            end
        end
        v === nothing && continue

        reach_m = _zone_electrical_reach(net, zone, anchor)
        band    = _voltage_band(v)

        entry = Dict{String,Any}("zone_anchor" => anchor, "band" => band,
                                 "v_nom" => v, "reach_m" => reach_m)
        push!(summary, entry)

        band_cfg = get(cfg, band, nothing)
        band_cfg isa AbstractDict || continue
        short_m = Float64(get(band_cfg, "reach_short_m", 0.0))
        long_m  = Float64(get(band_cfg, "reach_long_m",  0.0))

        v_kv = round(v / 1000, digits=2)
        if long_m > 0 && reach_m > long_m
            push!(findings, Finding(INFO, "I.OPS.FEEDER_LONG", :operational, :network, nothing,
                "Galvanic zone anchored at bus '$anchor' ($band, $(v_kv) kV) has an " *
                "electrical reach of $(round(reach_m/1000, digits=2)) km — longer than the " *
                "typical maximum $band feeder reach ($(round(long_m/1000, digits=2)) km). " *
                "Check for excessive voltage drop or a length-unit (km vs m) error.",
                Dict{String,Any}("zone_anchor" => anchor, "band" => band,
                                 "v_nom" => v, "reach_m" => reach_m,
                                 "threshold_m" => long_m)))
        elseif short_m > 0 && reach_m < short_m
            push!(findings, Finding(INFO, "I.OPS.FEEDER_SHORT", :operational, :network, nothing,
                "Galvanic zone anchored at bus '$anchor' ($band, $(v_kv) kV) has an " *
                "electrical reach of $(round(reach_m, digits=1)) m — shorter than typical " *
                "for a $band feeder ($(round(short_m, digits=1)) m); electrically it is a " *
                "stub/service drop rather than a feeder.",
                Dict{String,Any}("zone_anchor" => anchor, "band" => band,
                                 "v_nom" => v, "reach_m" => reach_m,
                                 "threshold_m" => short_m)))
        end
    end
    summary
end

# Voltage band for a per-conductor (phase-to-neutral) nominal voltage, using the
# same boundaries as `_voltage_level_label`.
function _voltage_band(v_volts::Real)::String
    kv = v_volts / 1000.0
    kv >= 100 ? "EHV" : kv >= 35 ? "HV" : kv >= 1 ? "MV" : "LV"
end

"""
Longest line/cable distance (Σ line `length`, m) from `anchor` to any bus in
`zone`, over lines, closed switches, and galvanically-continuous transformers.
Switches and regulator transformers contribute zero length. Computed with a
Dijkstra shortest-path tree (so meshed zones use the electrically shorter path);
for radial feeders the path is unique. Lines missing a `length` count as 0.
"""
function _zone_electrical_reach(net::Dict{String,Any}, zone::Set{String},
                                 anchor::String)::Float64
    adj = Dict{String,Vector{Tuple{String,Float64}}}()
    add!(a, b, w) = begin
        (a in zone && b in zone) || return
        push!(get!(adj, a, Tuple{String,Float64}[]), (b, w))
        push!(get!(adj, b, Tuple{String,Float64}[]), (a, w))
    end

    for (_, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        add!(f, t, max(Float64(get(l, "length", 0.0)), 0.0))
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) && add!(f, t, 0.0)
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in GALVANIC_CONTINUOUS_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            (f isa AbstractString && b isa AbstractString) && add!(f, b, 0.0)
        end
    end

    # Dijkstra from anchor (small zones; a linear-scan frontier is fine).
    dist = Dict{String,Float64}(anchor => 0.0)
    done = Set{String}()
    while length(done) < length(dist)
        u = ""; best = Inf
        for (b, d) in dist
            (b in done || d >= best) && continue
            u = b; best = d
        end
        u == "" && break
        push!(done, u)
        for (nb, w) in get(adj, u, Tuple{String,Float64}[])
            nd = best + w
            (nd < get(dist, nb, Inf)) && (dist[nb] = nd)
        end
    end
    isempty(dist) ? 0.0 : maximum(values(dist))
end

"""
Sum apparent power of all loads electrically downstream of a transformer.

Method: build the bus adjacency from lines, closed switches, and all
transformers *except* the one under analysis, then BFS from `t_bus`.
Every bus reached without crossing the excluded transformer is downstream
(valid for radial networks; for meshed networks where a parallel path
exists back to `f_bus`, the result over-counts and the utilisation figure
should be treated as an upper bound).
"""
function _downstream_load(net::Dict{String,Any}, xfmr_id::String,
                           f_bus::String, t_bus::String)::Float64
    # Build adjacency excluding the transformer under analysis
    adj = Dict{String,Vector{String}}()
    add!(a, b) = (push!(get!(adj, a, String[]), b);
                  push!(get!(adj, b, String[]), a))

    for (_, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) && add!(f, t)
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) && add!(f, t)
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (oid, ot) in sub
            oid == xfmr_id && continue   # exclude the transformer under analysis
            f = get(ot, "bus_from", nothing); t = get(ot, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString) && add!(f, t)
        end
    end

    # BFS from t_bus
    downstream = Set{String}([t_bus])
    queue = String[t_bus]
    while !isempty(queue)
        b = popfirst!(queue)
        for nb in get(adj, b, String[])
            nb in downstream && continue
            push!(downstream, nb)
            push!(queue, nb)
        end
    end

    # Sum apparent power of loads at downstream buses
    s = 0.0
    for (_, l) in get(net, "load", Dict())
        get(l, "bus", "") in downstream || continue
        p = sum(Float64.(get(l, "p_nom", Float64[])))
        q = sum(Float64.(get(l, "q_nom", Float64[])))
        s += hypot(p, q)
    end
    s
end
