"""
    connectivity_analysis(net, findings) -> Dict{String,Any}

Build an undirected graph of the network and compute:
- Number of connected components
- Radial vs meshed topology (cycle detection)
- Degree statistics
- Tree depth and longest path from voltage source
- Open-switch isolated sections
"""
function connectivity_analysis(net::Dict{String,Any},
                                findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    buses = get(net, "bus", Dict())
    n     = length(buses)
    if n == 0
        result["n_components"] = 0
        return result
    end

    # Assign stable integer indices to bus names
    bus_names = collect(keys(buses))
    bus_index = Dict(name => i for (i, name) in enumerate(bus_names))

    g = SimpleGraph(n)

    # SimpleGraph deduplicates parallel edges and drops self-loops, so count
    # branch elements separately — radiality must see every physical branch.
    n_branches = Ref(0)

    # Check for branch self-loops (bus_from == bus_to) before adding edges.
    function check_self_loop!(comp_type, id, bus_a, bus_b)
        (bus_a isa AbstractString && bus_b isa AbstractString) || return
        if bus_a == bus_b
            push!(findings, Finding(ERROR, "E.CONN.SELF_LOOP", :connectivity,
                Symbol(comp_type), id,
                "$comp_type '$id' connects bus '$bus_a' to itself — zero-length branch.",
                Dict{String,Any}("bus" => bus_a)))
        end
    end

    # Helper: add an edge if both endpoints are known buses
    function add_edge_safe!(bus_a, bus_b)
        (bus_a isa AbstractString && bus_b isa AbstractString) || return
        i = get(bus_index, bus_a, nothing)
        j = get(bus_index, bus_b, nothing)
        (i === nothing || j === nothing) && return
        n_branches[] += 1
        add_edge!(g, i, j)
    end

    # Lines
    for (id, l) in get(net, "line", Dict())
        bf = get(l, "bus_from", nothing); bt = get(l, "bus_to", nothing)
        check_self_loop!("line", id, bf, bt)
        add_edge_safe!(bf, bt)
    end

    # Closed switches only
    for (id, sw) in get(net, "switch", Dict())
        bf = get(sw, "bus_from", nothing); bt = get(sw, "bus_to", nothing)
        check_self_loop!("switch", id, bf, bt)
        get(sw, "open_switch", false) && continue
        add_edge_safe!(bf, bt)
    end

    # Transformers (each winding pair is an edge)
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            bf = get(t, "bus_from", nothing); bt = get(t, "bus_to", nothing)
            check_self_loop!("transformer ($subtype)", id, bf, bt)
            add_edge_safe!(bf, bt)
        end
    end

    # Voltage source buses (connected to their bus)
    vsrc_buses = String[]
    for (_, vs) in get(net, "voltage_source", Dict())
        b = get(vs, "bus", nothing)
        b isa AbstractString && push!(vsrc_buses, b)
    end

    # Connected components
    comps = connected_components(g)
    n_comps = length(comps)
    result["n_components"] = n_comps
    result["is_connected"]  = (n_comps == 1)

    if n_comps > 1
        # label each component's buses
        comp_bus_lists = Vector{Vector{String}}()
        for comp in comps
            push!(comp_bus_lists, [bus_names[i] for i in comp])
        end
        result["components"] = comp_bus_lists
        push!(findings, Finding(ERROR, "E.CONN.DISCONNECTED", :connectivity, :network, nothing,
            "Network has $n_comps disconnected components.",
            Dict{String,Any}("n_components" => n_comps)))
    end

    # Degree statistics
    degrees = degree(g)
    result["degree_min"]    = minimum(degrees)
    result["degree_max"]    = maximum(degrees)
    result["degree_mean"]   = mean(degrees)
    result["degree_median"] = median(degrees)

    degree_1_buses = [bus_names[i] for i in 1:n if degrees[i] == 1]
    degree_2_buses = [bus_names[i] for i in 1:n if degrees[i] == 2]
    result["degree_1_buses"] = degree_1_buses   # end-nodes / laterals
    result["degree_2_buses"] = degree_2_buses   # pass-through nodes
    result["n_degree_1"]     = length(degree_1_buses)
    result["n_degree_2"]     = length(degree_2_buses)

    # Radial vs meshed: a forest on n vertices has exactly n - n_components
    # edges. Use the physical branch count, not ne(g), so parallel branches
    # between the same bus pair are detected as cycles.
    n_edges         = n_branches[]
    n_vertices      = nv(g)
    tree_edge_count = n_vertices - n_comps
    is_radial       = (n_edges == tree_edge_count)
    result["is_radial"]       = is_radial
    result["n_extra_edges"]   = n_edges - tree_edge_count  # 0 for radial

    if !is_radial
        push!(findings, Finding(WARNING, "W.CONN.MESHED", :connectivity, :network, nothing,
            "Network contains $(n_edges - tree_edge_count) extra edge(s) forming cycles — not purely radial.",
            Dict{String,Any}("extra_edges" => n_edges - tree_edge_count)))
    end

    # Tree depth from each voltage source bus
    if !isempty(vsrc_buses)
        result["source_buses"] = vsrc_buses
        max_depth   = 0
        max_path    = String[]
        for src in vsrc_buses
            src_idx = get(bus_index, src, nothing)
            src_idx === nothing && continue
            dists = gdistances(g, src_idx)
            finite_dists = filter(d -> d < typemax(Int), dists)
            isempty(finite_dists) && continue
            d = maximum(finite_dists)
            if d > max_depth
                max_depth = d
                # trace back the farthest bus
                farthest_idx = findfirst(==(d), dists)
                if farthest_idx !== nothing
                    max_path = _trace_path(g, src_idx, farthest_idx, bus_names)
                end
            end
        end
        result["tree_depth_max"]   = max_depth
        result["longest_path_buses"] = max_path
    end

    # Open switch isolated sections: buses only reachable through open switches
    open_sw_buses = String[]
    for (_, sw) in get(net, "switch", Dict())
        !get(sw, "open_switch", false) && continue
        b_to = get(sw, "bus_to", nothing)
        b_to isa AbstractString && push!(open_sw_buses, b_to)
    end
    result["open_switch_isolated_buses"] = unique(open_sw_buses)

    # Dangling buses: degree 1 with no load, generator, or shunt attached
    load_buses = Set(string(get(l, "bus", "")) for (_, l) in get(net, "load",      Dict()))
    gen_buses  = Set(string(get(g, "bus", "")) for (_, g) in get(net, "generator", Dict()))
    shunt_buses = Set(string(get(s, "bus", "")) for (_, s) in get(net, "shunt",    Dict()))
    vsrc_set   = Set(vsrc_buses)
    dangling   = [b for b in degree_1_buses
                  if !(b in load_buses) && !(b in gen_buses) &&
                     !(b in shunt_buses) && !(b in vsrc_set)]
    result["dangling_buses"] = dangling
    if !isempty(dangling)
        push!(findings, Finding(WARNING, "W.CONN.DANGLING", :connectivity, :bus, nothing,
            "$(length(dangling)) bus(es) are degree-1 with no attached load, generator, or shunt.",
            Dict{String,Any}("buses" => dangling)))
    end

    # Galvanic-zone phase topology: tag split-phase (center-tap-fed) and SWER
    # (single-wire, transformer-isolated) zones.
    zone_class = _classify_zones(net)
    result["zones"] = [Dict{String,Any}(
            "label"    => z.label,
            "topology" => string(z.topology),
            "phases"   => sort(collect(z.phases)),
            "n_buses"  => length(z.buses)) for z in zone_class]
    result["n_split_phase_zones"] = count(z -> z.topology == :split_phase, zone_class)
    result["n_swer_zones"]        = count(z -> z.topology == :swer, zone_class)

    for z in zone_class
        if z.topology == :split_phase
            ct = something(findfirst(f -> f[1] == "center_tap", z.feed), nothing)
            ct_id = ct === nothing ? "?" : z.feed[ct][2]
            push!(findings, Finding(INFO, "I.PROV.SPLIT_PHASE_ZONE", :connectivity,
                :network, nothing,
                "Galvanic zone anchored at bus '$(z.label)' is split-phase " *
                "(fed by center_tap transformer '$(ct_id)'): legs $(sort(collect(z.phases))) " *
                "are anti-phase about the centre-tap neutral.",
                Dict{String,Any}("zone_anchor" => z.label, "center_tap" => ct_id,
                                 "phases" => sort(collect(z.phases)))))
        elseif z.topology == :swer
            push!(findings, Finding(INFO, "I.PROV.SWER_ZONE", :connectivity,
                :network, nothing,
                "Galvanic zone anchored at bus '$(z.label)' is single-wire and " *
                "transformer-isolated — a SWER (single-wire earth-return) section.",
                Dict{String,Any}("zone_anchor" => z.label,
                                 "phases" => sort(collect(z.phases)))))
        end
    end

    result
end

"""Simple BFS path reconstruction."""
function _trace_path(g::SimpleGraph, src::Int, dst::Int,
                     names::Vector{String})::Vector{String}
    prev = fill(-1, nv(g))
    visited = falses(nv(g))
    queue   = Int[src]
    visited[src] = true
    while !isempty(queue)
        v = popfirst!(queue)
        v == dst && break
        for w in neighbors(g, v)
            visited[w] && continue
            visited[w] = true
            prev[w] = v
            push!(queue, w)
        end
    end
    path = Int[]
    v = dst
    while v != -1
        push!(path, v)
        v = prev[v]
    end
    reverse!(path)
    [names[i] for i in path]
end

"""
    _galvanic_zones(net) -> Vector{Set{String}}

Partition buses into galvanic zones: connected subgraphs joined by lines,
closed switches, and the galvanically-continuous transformer subtypes
(`single_phase_autotransformer`, `open_delta_regulator`, listed in
`GALVANIC_CONTINUOUS_SUBTYPES`). Isolating transformer subtypes are NOT
included as edges. Returns a list of bus-name sets, one per zone.
"""
function _galvanic_zones(net::Dict{String,Any})::Vector{Set{String}}
    buses = collect(keys(get(net, "bus", Dict())))
    isempty(buses) && return Set{String}[]

    adj = Dict{String,Vector{String}}()
    for b in buses; adj[b] = String[]; end

    add_edge! = (a, b) -> begin
        push!(get!(adj, a, String[]), b)
        push!(get!(adj, b, String[]), a)
    end

    for (_, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString && f != t) && add_edge!(f, t)
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString && f != t) && add_edge!(f, t)
    end
    # Regulators (autotransformer / open-delta) keep both sides in one zone.
    xfmr = get(net, "transformer", Dict())
    for subtype in GALVANIC_CONTINUOUS_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            (f isa AbstractString && b isa AbstractString && f != b) && add_edge!(f, b)
        end
    end

    visited = Set{String}()
    zones   = Vector{Set{String}}()
    for b in buses
        b in visited && continue
        zone = Set{String}()
        queue = String[b]
        while !isempty(queue)
            cur = popfirst!(queue)
            cur in visited && continue
            push!(visited, cur)
            push!(zone, cur)
            for nb in get(adj, cur, String[])
                nb in visited || push!(queue, nb)
            end
        end
        push!(zones, zone)
    end
    zones
end

"""
    _classify_zones(net) -> Vector{NamedTuple}

Classify each galvanic zone (the components left after cutting transformer
windings) by phase topology.
Returns one entry per zone: `(buses, label, phases, topology, feed)` where
`topology` is one of:

- `:split_phase` — a `center_tap` transformer's `bus_to` lies in the zone
  (the modelled cause of split-phase service; NA 120-0-120, AU 230-0-230);
- `:swer` — the zone is single-wire (one distinct phase conductor across all its
  buses) **and** transformer-isolated (contains no voltage-source bus), the
  Single-Wire-Earth-Return signature;
- `:single_phase` / `:three_phase` / `:other` — by phase count otherwise.

`feed` lists `(subtype, transformer_id)` for transformers whose `bus_to` ∈ zone.
"""
function _classify_zones(net::Dict{String,Any})
    buses = get(net, "bus", Dict())

    vsrc_buses = Set(string(get(vs, "bus", ""))
                     for (_, vs) in get(net, "voltage_source", Dict()) if vs isa Dict)

    # Map each transformer's to-bus → [(subtype, id)]
    feed_by_bus = Dict{String,Vector{Tuple{String,String}}}()
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            bt = get(t, "bus_to", nothing)
            bt isa AbstractString || continue
            push!(get!(feed_by_bus, bt, Tuple{String,String}[]), (subtype, string(id)))
        end
    end

    out = NamedTuple[]
    for zone in _galvanic_zones(net)
        phases = Set{String}()
        for bid in zone
            b  = get(buses, bid, Dict())
            nt = _neutral_terminal(b)
            for t in get(b, "terminal_names", String[])
                string(t) != nt && push!(phases, string(t))
            end
        end

        feed = Tuple{String,String}[]
        for bid in zone
            append!(feed, get(feed_by_bus, bid, Tuple{String,String}[]))
        end

        has_source = any(bid -> bid in vsrc_buses, zone)
        is_ct_fed  = any(f -> f[1] == "center_tap", feed)

        topology =
            is_ct_fed                            ? :split_phase  :
            (length(phases) == 1 && !has_source) ? :swer         :
            length(phases) == 1                  ? :single_phase :
            length(phases) >= 3                  ? :three_phase  :
                                                   :other

        label = let src = intersect(zone, vsrc_buses)
            isempty(src) ? minimum(zone) : first(src)
        end

        push!(out, (buses = zone, label = label, phases = phases,
                    topology = topology, feed = feed))
    end
    out
end
