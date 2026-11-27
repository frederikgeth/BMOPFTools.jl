"""
    connectivity_analysis(net, findings) -> Dict{String,Any}

Build an undirected graph of the network and compute:
- Number of connected components
- Radial vs meshed topology (cycle detection over phase-carrying branches;
  cycles closed only by neutral-only branches, such as a neutral bond beside a
  service transformer, are counted separately as `neutral_only_cycle_rank`)
- Degree statistics
- Tree depth and longest path from voltage source
- Open-switch isolated sections
"""
function connectivity_analysis(net::Dict{String,Any},
                                findings::Vector{Finding}; voltage_levels=nothing,
                                config::Dict=_DEFAULT_CONFIG)::Dict{String,Any}
    result = Dict{String,Any}()

    buses = get(net, "bus", Dict())
    n     = length(buses)
    if n == 0
        inventory = _physical_branch_inventory(net)
        result["n_components"] = 0
        result["structure"] = _topology_structure(net, Dict{String,Any}(), inventory)
        result["switch_scenarios"] = _switch_scenarios(net, inventory)
        spatial = _spatial_analysis(net, Dict{String,Any}(), findings; config=config)
        spatial === nothing || (result["spatial"] = spatial)
        return result
    end

    # Assign stable integer indices to bus names
    bus_names = collect(keys(buses))
    bus_index = Dict(name => i for (i, name) in enumerate(bus_names))

    g = SimpleGraph(n)

    # SimpleGraph deduplicates parallel edges and drops self-loops, so count
    # branch elements separately — radiality must see every physical branch.
    n_branches = Ref(0)
    # Neutral-only lines/switches keep buses connected but carry no phase
    # conductor. Radiality is assessed on the phase-carrying graph.
    roles = _index_roles(net)
    g_phase = SimpleGraph(n)
    n_phase_branches = Ref(0)
    n_neutral_only = Ref(0)

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

    # Helper: add an edge if both endpoints are known buses. Self-loops are
    # excluded from the branch count: SimpleGraph silently drops them, so
    # counting them would flag a radial network as meshed. They are already
    # reported separately as E.CONN.SELF_LOOP.
    function add_edge_safe!(bus_a, bus_b; neutral_only::Bool=false)
        (bus_a isa AbstractString && bus_b isa AbstractString) || return
        i = get(bus_index, bus_a, nothing)
        j = get(bus_index, bus_b, nothing)
        (i === nothing || j === nothing || i == j) && return
        n_branches[] += 1
        add_edge!(g, i, j)
        if neutral_only
            n_neutral_only[] += 1
        else
            n_phase_branches[] += 1
            add_edge!(g_phase, i, j)
        end
    end

    # Lines
    for (id, l) in get(net, "line", Dict())
        bf = get(l, "bus_from", nothing); bt = get(l, "bus_to", nothing)
        check_self_loop!("line", id, bf, bt)
        add_edge_safe!(bf, bt; neutral_only=_neutral_only_branch(l, roles))
    end

    # Closed switches only
    for (id, sw) in get(net, "switch", Dict())
        bf = get(sw, "bus_from", nothing); bt = get(sw, "bus_to", nothing)
        check_self_loop!("switch", id, bf, bt)
        get(sw, "open_switch", false) && continue
        add_edge_safe!(bf, bt; neutral_only=_neutral_only_branch(sw, roles))
    end

    # Transformers (each winding pair is an edge). Single-phase units that join
    # the same two buses on DIFFERENT secondary conductors are one bank (three
    # L-N units, an open-wye/open-delta pair, a high-leg lighting + power pair):
    # the bank is a single branch of the bus graph, not a cycle. The grouping is
    # shared with the physical branch inventory, so this verdict and the cycle
    # evidence in `structure` count the same branches.
    xfmr = get(net, "transformer", Dict())
    banks = _transformer_bank_groups(net)
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for id in sort!(collect(keys(sub)))
            t = sub[id]
            t isa AbstractDict || continue
            bf = get(t, "bus_from", nothing); bt = get(t, "bus_to", nothing)
            check_self_loop!("transformer ($subtype)", id, bf, bt)
            (subtype, string(id)) in banks.merged && continue   # a further leg of a bank
            add_edge_safe!(bf, bt)
        end
    end
    result["transformer_banks"] = [g for g in banks.groups if length(g["units"]) > 1]
    result["undetermined_transformer_banks"] = banks.undetermined
    result["transformer_bank_groups"] = banks.groups

    # n-winding transformers: connect winding 1's bus to every other winding's.
    for (id, t) in get(xfmr, "n_winding", Dict())
        ws = _nw_windings(t)
        isempty(ws) && continue
        b1 = ws[1].bus
        for j in 2:length(ws)
            bj = ws[j].bus
            check_self_loop!("transformer (n_winding)", id, b1, bj)
            add_edge_safe!(b1, bj)
        end
    end

    # DC links: AC buses whose converters (IBRs with a `dc_bus`) sit on one DC
    # island are joined through it. An AC section fed only over DC is part of
    # the network, not a disconnected component, and a DC link between two
    # buses of one AC network closes a loop like any other branch.
    # Each DC island is its own vertex, joined to every AC bus it couples: a
    # star, not a chain through the AC buses in name order. Degree and path
    # metrics then do not depend on bus ids, and the cycle count is the same
    # (k links and one more vertex, against k - 1 links in a chain).
    dc_links = _dc_links(net)
    for link in dc_links
        add_vertex!(g); add_vertex!(g_phase)
        island_vertex = nv(g)
        push!(bus_names, "dc_island:$(link.island)")
        for b in link.buses
            i = get(bus_index, b, nothing)
            i === nothing && continue
            n_branches[] += 1; n_phase_branches[] += 1
            add_edge!(g, i, island_vertex); add_edge!(g_phase, i, island_vertex)
        end
    end
    result["dc_links"] = [link.buses for link in dc_links]
    result["dc_link_islands"] = [Dict{String,Any}("dc_island" => link.island, "buses" => link.buses)
                                 for link in dc_links]

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
            push!(comp_bus_lists, [bus_names[i] for i in comp if i <= n])
        end
        result["components"] = comp_bus_lists
        push!(findings, Finding(ERROR, "E.CONN.DISCONNECTED", :connectivity, :network, nothing,
            "Network has $n_comps disconnected components.",
            Dict{String,Any}("n_components" => n_comps)))
    end

    # Degree statistics
    degrees = degree(g)[1:n]            # AC buses; DC-island vertices are not buses
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
    # between the same bus pair are detected as cycles. Radiality concerns the
    # phase-carrying branches; neutral-only branches close cycles only through
    # transformers or parallel phase paths, which is counted separately.
    n_vertices      = nv(g)
    n_edges         = n_phase_branches[]
    tree_edge_count = n_vertices - length(connected_components(g_phase))
    is_radial       = (n_edges == tree_edge_count)
    neutral_cycles  = (n_branches[] - (n_vertices - n_comps)) - (n_edges - tree_edge_count)
    result["is_radial"]       = is_radial
    result["n_extra_edges"]   = n_edges - tree_edge_count  # 0 for radial
    result["n_neutral_only_branches"] = n_neutral_only[]
    result["neutral_only_cycle_rank"] = neutral_cycles

    # Tree depth from each voltage source bus
    if !isempty(vsrc_buses)
        result["source_buses"] = vsrc_buses
        max_depth   = 0
        max_path    = String[]
        max_path_buses = String[]
        for src in vsrc_buses
            src_idx = get(bus_index, src, nothing)
            src_idx === nothing && continue
            dists = gdistances(g, src_idx)
            # Depth is measured to AC buses. A hop over a DC island counts as
            # two (bus, island, bus), whatever the buses are called.
            finite_dists = filter(d -> d < typemax(Int), dists[1:n])
            isempty(finite_dists) && continue
            d = maximum(finite_dists)
            if d > max_depth
                max_depth = d
                # trace back the farthest bus
                farthest_idx = findfirst(i -> dists[i] == d, 1:n)
                if farthest_idx !== nothing
                    walk = _trace_path_vertices(g, src_idx, farthest_idx)
                    max_path = [bus_names[v] for v in walk]
                    # AC buses are the vertices 1:n; a bus whose id happens to
                    # look like a DC-island label is still a bus.
                    max_path_buses = [bus_names[v] for v in walk if v <= n]
                end
            end
        end
        result["tree_depth_max"]   = max_depth
        # `longest_path_buses` lists AC buses only, as its consumers (DER and
        # IBR placement among them) expect; the full walk, DC-island vertices
        # included, is `longest_path_vertices`.
        result["longest_path_buses"] = max_path_buses
        result["longest_path_vertices"] = max_path
    end

    # Open switch isolated sections: an open switch's endpoint is only genuinely
    # isolated if it has NO closed path to a voltage source. The previous version
    # listed every open switch's bus_to unconditionally, so a bus still fed by a
    # closed line elsewhere was falsely reported as isolated. Filter by the true
    # source-connectivity from the closed-edge components.
    powered = Set{String}()
    let vsrc_set0 = Set(vsrc_buses)
        for comp in comps
            names = [bus_names[i] for i in comp if i <= n]
            any(n -> n in vsrc_set0, names) && union!(powered, names)
        end
    end
    open_sw_buses = String[]
    for (_, sw) in get(net, "switch", Dict())
        !get(sw, "open_switch", false) && continue
        for b in (get(sw, "bus_from", nothing), get(sw, "bus_to", nothing))
            b isa AbstractString && !(b in powered) && push!(open_sw_buses, b)
        end
    end
    result["open_switch_isolated_buses"] = unique(open_sw_buses)

    # Dangling buses: degree 1 with no bus-attached element. `ibr` is a
    # first-class category (a PV/STATCOM on a lateral) — omitting it made such a
    # bus a false dangling report, which the placement passes then skipped.
    load_buses = Set(string(get(l, "bus", "")) for (_, l) in get(net, "load",      Dict()))
    gen_buses  = Set(string(get(g, "bus", "")) for (_, g) in get(net, "generator", Dict()))
    shunt_buses = Set(string(get(s, "bus", "")) for (_, s) in get(net, "shunt",    Dict()))
    cap_buses  = Set(string(get(c, "bus", "")) for (_, c) in get(net, "capacitor", Dict()))
    ibr_buses  = Set(string(get(v, "bus", "")) for (_, v) in get(net, "ibr",       Dict()))
    vsrc_set   = Set(vsrc_buses)
    # A further leg of a transformer bank is not a separate edge of the bus
    # graph, but its buses are not spare: the unit is connected there.
    bank_leg_buses = Set{String}()
    for (subtype, id) in banks.merged
        t = get(get(xfmr, subtype, Dict()), id, nothing)
        t isa AbstractDict || continue
        for b in (get(t, "bus_from", nothing), get(t, "bus_to", nothing))
            b isa AbstractString && push!(bank_leg_buses, String(b))
        end
    end
    dangling   = [b for b in degree_1_buses
                  if !(b in bank_leg_buses) &&
                     !(b in load_buses) && !(b in gen_buses) &&
                     !(b in shunt_buses) && !(b in cap_buses) &&
                     !(b in ibr_buses)  && !(b in vsrc_set)]
    result["dangling_buses"] = dangling
    if !isempty(dangling)
        push!(findings, Finding(WARNING, "W.CONN.DANGLING", :connectivity, :bus, nothing,
            "$(length(dangling)) bus(es) are degree-1 with no attached load, generator, " *
            "shunt, capacitor, ibr, or source.",
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

    # High-leg banks, resolved once for the network and indexed by secondary bus.
    high_leg_by_bus = Dict{String,Vector{Any}}()
    any(z -> z.topology == :split_phase, zone_class) &&
        for bank in _high_leg_banks(net)
            push!(get!(high_leg_by_bus, bank.bus_to, Any[]), bank)
        end
    for z in zone_class
        if z.topology == :split_phase
            ct = something(findfirst(f -> f[1] == "center_tap", z.feed), nothing)
            ct_id = ct === nothing ? "?" : z.feed[ct][2]
            # The anti-phase legs are the center-tapped winding's two outer
            # terminals. Any further phase conductor in the zone comes from a
            # banked power unit: the high leg of a four-wire delta.
            ct_rec = ct === nothing ? nothing :
                get(get(get(net, "transformer", Dict()), "center_tap", Dict()), ct_id, nothing)
            tm_to = ct_rec isa AbstractDict ? get(ct_rec, "terminal_map_to", nothing) : nothing
            legs = tm_to isa AbstractVector && length(tm_to) == 3 ?
                sort!([string(tm_to[1]), string(tm_to[3])]) : sort(collect(z.phases))
            # The high leg comes from the identified bank: the conductors a
            # high-leg power unit (the same units the voltage-level pass
            # reports) lands beyond the two legs. Another phase conductor in
            # the zone is listed separately, without a claim about its voltage.
            high_set = Set{String}()
            for bid in z.buses, bank in get(high_leg_by_bus, bid, ())
                bank.status == "verified" && union!(high_set, bank.high)
            end
            high = sort!(collect(high_set))
            other = sort!(collect(setdiff(z.phases, legs, high)))
            push!(findings, Finding(INFO, "I.PROV.SPLIT_PHASE_ZONE", :connectivity,
                :network, nothing,
                "Galvanic zone anchored at bus '$(z.label)' is split-phase " *
                "(fed by center_tap transformer '$(ct_id)'): legs $(legs) " *
                "are anti-phase about the center-tap neutral." *
                (isempty(high) ? "" : " Phase conductor(s) $(high) are supplied by a " *
                    "banked power unit — a high-leg (four-wire) delta, whose " *
                    "phase-to-neutral voltage differs from the legs'."),
                Dict{String,Any}("zone_anchor" => z.label, "center_tap" => ct_id,
                                 "phases" => sort(collect(z.phases)),
                                 "legs" => legs, "high_leg" => high,
                                 "other_phases" => other)))
        elseif z.topology == :swer
            push!(findings, Finding(INFO, "I.PROV.SWER_ZONE", :connectivity,
                :network, nothing,
                "Galvanic zone anchored at bus '$(z.label)' is single-wire and " *
                "transformer-isolated — a SWER (single-wire earth-return) section.",
                Dict{String,Any}("zone_anchor" => z.label,
                                 "phases" => sort(collect(z.phases)))))
        end
    end

    result["supply_phase_consistency"] = _check_supply_phase_consistency(net, findings, zone_class)
    levels = voltage_levels === nothing ? voltage_level_analysis(net, Finding[]) : voltage_levels
    inventory = _physical_branch_inventory(net)
    result["structure"] = _topology_structure(net, levels, inventory)
    result["switch_scenarios"] = _switch_scenarios(net, inventory)
    structure = result["structure"]
    if !is_radial
        whole = structure["whole_network"]
        push!(findings, Finding(WARNING, "W.CONN.MESHED", :connectivity, :network, nothing,
            "Network contains $(n_edges - tree_edge_count) extra edge(s) forming cycles — not purely radial.",
            Dict{String,Any}(
                "extra_edges" => n_edges - tree_edge_count,
                "neutral_only_cycle_rank" => neutral_cycles,
                "simple_cycle_rank" => whole["simple_cycle_rank"],
                "parallel_excess" => whole["parallel_excess"],
                "transformer_mediated_cycle_rank" => whole["transformer_mediated_cycle_rank"],
                "dc_mediated_cycle_rank" => whole["dc_mediated_cycle_rank"],
                "cycle_closing_branches" => structure["cycle_closing_branches"])))
    end
    spatial = _spatial_analysis(net, levels, findings; config=config)
    spatial === nothing || (result["spatial"] = spatial)

    result
end

# Physical cycle rank is E - V + C. Replacing each bus pair with one edge
# separates the rank into simple-graph cycles and excess parallel branches.
function _topology_counts(nodes::Vector, edges)::Dict{String,Any}
    indices = Dict(b => i for (i, b) in enumerate(nodes))
    graph = SimpleGraph(length(nodes))
    physical = 0
    for edge in edges
        a = get(indices, edge.from, 0); b = get(indices, edge.to, 0)
        (a == 0 || b == 0 || a == b) && continue
        physical += 1
        add_edge!(graph, a, b)
    end
    components = length(connected_components(graph))
    simple = ne(graph)
    Dict{String,Any}(
        "n_buses" => length(nodes), "n_components" => components,
        "n_physical_edges" => physical, "n_simple_edges" => simple,
        "cycle_rank" => physical - length(nodes) + components,
        "simple_cycle_rank" => simple - length(nodes) + components,
        "parallel_excess" => physical - simple)
end

# Line/switch conductor paths are independent of bus-level graph paths. This
# deliberately treats every transformer winding as a boundary port: winding
# coupling and phase conversion cannot be inferred from matching terminal names.
function _conductor_paths(net::Dict{String,Any}, voltage_levels::Dict{String,Any})::Dict{String,Any}
    inventory = _mapped_conductor_inventory(net)
    nodes = inventory.nodes
    isempty(nodes) && return Dict{String,Any}("status" => "inapplicable",
        "reason" => "No bus terminal_names are declared.", "n_bus_terminals" => 0)
    index = inventory.index
    graph = SimpleGraph(length(nodes))
    for edge in inventory.declared
        add_edge!(graph, index[edge.from], index[edge.to])
    end
    components = connected_components(graph)
    component_of = zeros(Int, length(nodes))
    for (ci, component) in enumerate(components), node in component
        component_of[node] = ci
    end
    boundary = Set(component_of[index[node]] for node in inventory.boundary_nodes)
    level_by_bus = Dict{String,String}()
    for (label, level) in get(voltage_levels, "levels", Dict())
        for bus in get(level, "buses", String[])
            level_by_bus[string(bus)] = string(label)
        end
    end
    per_tier = Dict{String,Set{Int}}()
    for (i, (bus, _)) in enumerate(nodes)
        push!(get!(per_tier, get(level_by_bus, bus, "unassigned"), Set{Int}()),
              component_of[i])
    end
    load_candidates = Dict{String,Any}[]
    n_load_terminals_without_boundary = 0
    for (id, load) in sort!(collect(get(net, "load", Dict())); by=x -> string(first(x)))
        load isa AbstractDict || continue
        bus = string(get(load, "bus", ""))
        terms = get(load, "terminal_map", nothing)
        terms isa AbstractVector || continue
        for term in terms
            i = get(index, (bus, string(term)), 0)
            i == 0 && continue
            component_of[i] in boundary && continue
            n_load_terminals_without_boundary += 1
            length(load_candidates) < 10 && push!(load_candidates, Dict{String,Any}(
                "load_id" => string(id), "bus" => bus, "terminal" => string(term),
                "path_component" => component_of[i]))
        end
    end
    Dict{String,Any}(
        "status" => isempty(boundary) ? "indeterminate" : "assessed",
        "scope" => "mapped_line_and_closed_switch_conductors_with_transformer_ports_as_boundaries",
        "n_bus_terminals" => length(nodes),
        "n_mapped_conductor_edges" => length(inventory.declared),
        "n_skipped_branches" => inventory.skipped_declared,
        "n_path_components" => length(components),
        "n_boundary_components" => length(boundary),
        "path_components_by_voltage_tier" => Dict(k => length(v) for (k, v) in per_tier),
        "n_load_terminals_without_boundary" => isempty(boundary) ? nothing :
            n_load_terminals_without_boundary,
        "load_terminal_witnesses" => isempty(boundary) ? Dict{String,Any}[] : load_candidates)
end

function _topology_structure(net::Dict{String,Any}, voltage_levels::Dict{String,Any},
                             inventory=_physical_branch_inventory(net))::Dict{String,Any}
    buses = inventory.buses
    busset = Set(buses)
    edges = inventory.declared
    skipped = inventory.skipped

    level_by_bus = Dict{String,String}()
    for (label, level) in get(voltage_levels, "levels", Dict())
        for bus in get(level, "buses", String[])
            bus in busset && (level_by_bus[bus] = string(label))
        end
    end
    level_nodes = Dict{String,Vector{String}}()
    for bus in buses
        push!(get!(level_nodes, get(level_by_bus, bus, "unassigned"), String[]), bus)
    end
    level_edges = Dict(label => typeof(edges)() for label in keys(level_nodes))
    cross_level = 0
    for edge in edges
        a = get(level_by_bus, edge.from, "unassigned")
        b = get(level_by_bus, edge.to, "unassigned")
        if a == b
            push!(level_edges[a], edge)
        else
            cross_level += 1
        end
    end
    tiers = [merge(Dict{String,Any}("level" => label),
                   _topology_counts(level_nodes[label], level_edges[label]))
             for label in sort!(collect(keys(level_nodes)))]

    zone_sets = sort!(_galvanic_zones(net), by=minimum)
    zone_by_bus = Dict(bus => i for (i, zone) in enumerate(zone_sets) for bus in zone)
    zone_edges = [typeof(edges)() for _ in zone_sets]
    incident = [Set{String}() for _ in zone_sets]
    for edge in edges
        a = zone_by_bus[edge.from]; b = zone_by_bus[edge.to]
        # A DC link is not a galvanic branch of a zone, wherever its ends are.
        edge.kind == "dc_link" && continue
        if a == b
            push!(zone_edges[a], edge)
        else
            # A continuous branch between zones can only be a neutral-only
            # line or switch. It is skipped on purpose: a neutral bond is not
            # a zone interface.
            edge.continuous && continue
            transformer_id = edge.kind == "transformer:n_winding" ? first(rsplit(edge.id, ":"; limit=2)) : edge.id
            push!(incident[a], "$(edge.kind):$transformer_id")
            push!(incident[b], "$(edge.kind):$transformer_id")
        end
    end
    zones = Dict{String,Any}[]
    for (i, zone) in enumerate(zone_sets)
        labels = sort!(unique(get(level_by_bus, b, "unassigned") for b in zone))
        push!(zones, merge(Dict{String,Any}(
            "anchor" => minimum(zone), "voltage_levels" => labels,
            "n_incident_isolating_transformers" => length(incident[i])),
            _topology_counts(sort!(collect(zone)), zone_edges[i])))
    end
    whole = _topology_counts(buses, edges)
    # Attribute each cycle to what closes it. Galvanic-zone ranks count lines
    # and switches inside a zone; what remains without DC links is closed
    # through transformers; what DC links add is closed through a DC island.
    ac_only = _topology_counts(buses, [e for e in edges if e.kind != "dc_link"])
    # What one "physical branch" is in these counts and in the cycle witnesses.
    whole["branch_scope"] = "lines; closed switches; two-bus transformers, with a bank of " *
        "single-phase units counted once; n_winding winding pairs; DC links between " *
        "converters on one DC island. Neutral-only lines and switches are included here " *
        "and reported separately as neutral_only_cycle_rank by the mesh verdict."
    whole["n_merged_bank_legs"] = inventory.n_merged_bank_legs
    whole["n_dc_links"] = inventory.n_dc_links
    zone_rank = sum(z["cycle_rank"] for z in zones; init=0)
    whole["transformer_mediated_cycle_rank"] = ac_only["cycle_rank"] - zone_rank
    whole["dc_mediated_cycle_rank"] = whole["cycle_rank"] - ac_only["cycle_rank"]

    # A deterministic spanning forest localizes each excess physical branch.
    # A closing branch is only a graph witness; its record is not necessarily
    # defective and may be an intentional parallel circuit or tie.
    forest = _DisjointSets(buses)
    closing = Dict{String,Any}[]
    # AC branches build the forest first, so a cycle that exists only through a
    # DC link names that link (and its DC island) as the closing branch.
    for edge in sort(edges, by=e -> (e.kind == "dc_link", e.kind, e.id, e.from, e.to))
        _ds_union!(forest, edge.to, edge.from) && continue
        length(closing) < 10 && push!(closing, Dict{String,Any}(
            "kind" => edge.kind, "component_id" => edge.id,
            "bus_from" => edge.from, "bus_to" => edge.to))
    end

    parallel = _parallel_line_evidence(net; level_by_bus=level_by_bus, busset=busset)
    delete!(parallel, "groups") # full groups remain only in the legacy redundancy result
    Dict{String,Any}(
        "whole_network" => whole, "voltage_tiers" => tiers, "galvanic_zones" => zones,
        "cycle_closing_branches" => closing,
        "conductor_paths" => _conductor_paths(net, voltage_levels),
        "n_cross_tier_edges" => cross_level, "n_skipped_branches" => skipped,
        "parallel_lines" => parallel)
end

"""
    _check_supply_phase_consistency(net, findings, zone_class) -> Dict

Flag galvanic zones whose buses contradict their supply. Phase count and
separation are fixed inside a galvanic zone — only a transformer (Scott-T,
center-tap, delta-wye) can change them — so a bus cannot carry more phases than
its feed provides, and a balanced 3-phase bus cannot sit downstream of a source
that is not a 120° rotation.

- `W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY` — a bus declares more phase conductors than
  the zone's galvanic feed (voltage source or feeding-transformer secondary)
  supplies. Catches a 3φ bus fed by a single-phase (1) or split-phase 180° (2-leg)
  supply.
- `W.PROV.PHASE_ARRANGEMENT_MISMATCH` — the zone has a 3-phase bus and enough
  conductors, but its voltage source's angle arrangement is zero/quadrature/
  anti-phase/incoherent rather than a 120° rotation, so it cannot establish a
  rotating 3-phase field.

Phase conductors are counted with the case's resolved terminal roles
(`terminal_conventions`, or the naming convention when none is declared):
neutral- and earth-role labels are not phases.
"""
function _check_supply_phase_consistency(net::Dict{String,Any},
                                         findings::Vector{Finding},
                                         zone_class)::Dict{String,Any}
    buses = get(net, "bus", Dict())
    vsrcs = get(net, "voltage_source", Dict())
    xfmr  = get(net, "transformer", Dict())

    is_return = _return_label_predicate(net)
    _nphase(tm) = let v = Vector{String}(string.(tm)), nt = _neutral_terminal(v)
        count(t -> !is_return(t, nt), v)
    end
    function _bus_nphase(bid)
        b = get(buses, bid, nothing)
        b isa Dict ? _nphase(get(b, "terminal_names", String[])) : 0
    end
    _phases(tm) = let v = Vector{String}(string.(tm)), nt = _neutral_terminal(v)
        Set(t for t in v if !is_return(t, nt))
    end
    # Phase conductors one feeding transformer lands in this zone.
    function _xfmr_to_phases(subtype, id, zone_buses)
        out = Set{String}()
        sub = get(xfmr, subtype, nothing); sub isa Dict || return out
        t = get(sub, id, nothing); t isa Dict || return out
        if subtype in WINDING_LIST_SUBTYPES
            # n_winding has no terminal_map_to; the windings that supply THIS
            # zone are the ones whose bus falls inside it.
            for w in _nw_windings(t)
                w.bus in zone_buses && union!(out, _phases(w.terminal_map))
            end
            return out
        end
        union!(out, _phases(get(t, "terminal_map_to", String[])))
    end

    affected = String[]
    bank_membership = _transformer_bank_groups(net).membership
    for z in zone_class
        # ── supplied phase count, and the source angle arrangement if source-fed ──
        supplied = 0
        src_arr  = :unknown
        src_id   = nothing
        for (sid, vs) in vsrcs
            vs isa Dict || continue
            string(get(vs, "bus", "")) in z.buses || continue
            tm = Vector{String}(string.(get(vs, "terminal_map", String[])))
            nt = _neutral_terminal(tm)
            va = Float64.(get(vs, "v_angle", Float64[]))
            angs = Float64[]
            for (k, t) in enumerate(tm)
                is_return(t, nt) && continue
                k <= length(va) && push!(angs, va[k])
            end
            np = _nphase(tm)
            if np > supplied
                supplied = np; src_id = sid
                src_arr  = length(angs) >= 2 ? _phase_separation_class(angs) :
                           np == 1            ? :single_phase : :unknown
            end
        end
        # A bank of single-phase units supplies the UNION of its legs: three
        # L-N units, or two open-delta units on (a,b) and (b,c), establish all
        # three phase conductors although each unit lands only one or two.
        # The union is taken per bank, that is over units sharing one
        # (supply point, bus_to) pair, primary buses joined by closed switches
        # being one supply point; unrelated single-phase units elsewhere in
        # the zone do not add up to a three-phase supply.
        fed_by_pair = Dict{Any,Set{String}}()
        for (subtype, id) in z.feed
            rec = get(get(xfmr, subtype, Dict()), id, nothing)
            pair = get(bank_membership, (String(subtype), string(id)), (subtype, id))
            union!(get!(fed_by_pair, pair, Set{String}()), _xfmr_to_phases(subtype, id, z.buses))
        end
        for fed in values(fed_by_pair)
            supplied = max(supplied, length(fed))
        end
        supplied == 0 && continue   # no identifiable supply — cannot judge

        offenders = sort([bid for bid in z.buses if _bus_nphase(bid) > supplied])
        if !isempty(offenders)
            push!(affected, z.label)
            push!(findings, Finding(WARNING, "W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY",
                :connectivity, :network, nothing,
                "Galvanic zone anchored at '$(z.label)' is supplied with $supplied " *
                "phase(s) but contains bus(es) declaring more ($(join(offenders, ", "))). " *
                "Phase count cannot increase without a transformer (Scott-T, " *
                "center-tap, delta-wye).",
                Dict{String,Any}("zone_anchor" => z.label, "supplied_phases" => supplied,
                                 "offending_buses" => offenders)))
            continue
        end

        if src_id !== nothing && any(bid -> _bus_nphase(bid) >= 3, z.buses) &&
                src_arr in (:zero, :quadrature, :anti_phase, :incoherent)
            push!(affected, z.label)
            push!(findings, Finding(WARNING, "W.PROV.PHASE_ARRANGEMENT_MISMATCH",
                :connectivity, :network, nothing,
                "Galvanic zone anchored at '$(z.label)' contains a 3-phase bus but its " *
                "voltage source '$(src_id)' has a $(src_arr) angle arrangement (not a " *
                "120° positive/negative rotation) — it cannot establish a rotating " *
                "3-phase field; a true 3-phase supply or a phase-converting " *
                "transformer (e.g. Scott-T) is required.",
                Dict{String,Any}("zone_anchor" => z.label, "source" => src_id,
                                 "arrangement" => string(src_arr))))
        end
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

"""Simple BFS path reconstruction."""
_trace_path(g::SimpleGraph, src::Int, dst::Int, names::Vector{String})::Vector{String} =
    [names[v] for v in _trace_path_vertices(g, src, dst)]

function _trace_path_vertices(g::SimpleGraph, src::Int, dst::Int)::Vector{Int}
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
end

"""
    _galvanic_zones(net) -> Vector{Set{String}}

Partition buses into galvanic zones: connected subgraphs joined by lines,
closed switches, and the galvanically-continuous transformer subtypes
(`single_phase_autotransformer`, `open_delta_regulator`, listed in
`GALVANIC_CONTINUOUS_SUBTYPES`). Isolating transformer subtypes are NOT
included as edges. Returns a list of bus-name sets, one per zone.

By default, zones describe phase-conductor continuity. Lines and closed switches
that map only neutral- or earth-role terminals at both ends (see
`_neutral_only_branch`), such as a primary-to-secondary neutral bond across a
service transformer, carry no phase conductor and do not join zones.

Pass `include_neutral_only=true` for conductor continuity instead: every line and
closed switch joins its buses. Per-unit scaling needs this form, because a
branch current is scaled by one endpoint's current base while KCL at the other
endpoint uses that bus's base, so both ends must share one power base.
"""
function _galvanic_zones(net::Dict{String,Any};
                         include_neutral_only::Bool=false)::Vector{Set{String}}
    buses = collect(keys(get(net, "bus", Dict())))
    isempty(buses) && return Set{String}[]

    busset = Set(buses)
    adj = Dict{String,Vector{String}}()
    for b in buses; adj[b] = String[]; end

    # Only connect declared buses. A component referencing an undeclared bus
    # (e.g. a case-inconsistent or dangling endpoint) must not inject a phantom
    # node into a zone — that dangling reference is reported separately by
    # integrity_check; here we keep zones over real buses only.
    add_edge! = (a, b) -> begin
        (a in busset && b in busset) || return
        push!(adj[a], b)
        push!(adj[b], a)
    end

    roles = include_neutral_only ? nothing : _index_roles(net)
    for (_, l) in get(net, "line", Dict())
        _neutral_only_branch(l, roles) && continue
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString && f != t) && add_edge!(f, t)
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        _neutral_only_branch(sw, roles) && continue
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

# AC buses coupled through each DC island: sorted groups of two or more AC bus
# ids whose converters share a DC island (dc_buses joined by dc_branches).
_dc_link_ac_groups(net)::Vector{Vector{String}} = [link.buses for link in _dc_links(net)]

# One record per DC island that couples two or more AC buses: `island` is the
# island's label (its smallest dc_bus id), `buses` the sorted AC buses. Two
# islands that link the same AC buses are two records.
function _dc_links(net)
    none = NamedTuple{(:island, :buses),Tuple{String,Vector{String}}}[]
    dc_buses = get(net, "dc_bus", Dict())
    dc_buses isa AbstractDict && !isempty(dc_buses) || return none
    islands = _DisjointSets(String[string(b) for b in keys(dc_buses)])
    parent = islands.parent
    find(x) = _ds_find!(islands, x)
    dc_branches = get(net, "dc_branch", Dict())
    dc_branches isa AbstractDict || (dc_branches = Dict())
    for (_, br) in dc_branches
        br isa AbstractDict || continue
        a = get(br, "dc_bus_from", nothing); c = get(br, "dc_bus_to", nothing)
        a isa AbstractString && c isa AbstractString &&
            haskey(parent, a) && haskey(parent, c) || continue
        _ds_union!(islands, a, c)
    end
    ac_buses = get(net, "bus", Dict())
    groups = Dict{String,Set{String}}()
    ibrs = get(net, "ibr", Dict())
    ibrs isa AbstractDict || (ibrs = Dict())
    for (_, inv) in ibrs
        inv isa AbstractDict || continue
        d = get(inv, "dc_bus", nothing); b = get(inv, "bus", nothing)
        d isa AbstractString && b isa AbstractString &&
            haskey(parent, d) && haskey(ac_buses, b) || continue
        push!(get!(groups, find(d), Set{String}()), b)
    end
    label = Dict{String,String}()
    for d in keys(parent)
        r = find(d)
        label[r] = min(get(label, r, d), d)
    end
    append!(none, [(island=label[r], buses=sort!(collect(g)))
                   for (r, g) in groups if length(g) >= 2])
    sort!(none, by = l -> (l.buses, l.island))
end

"""
    _transformer_bank_groups(net) -> (merged, groups)

Resolve, per ordered `(bus_from, bus_to)` pair, which single-phase units form
one bank. Primary buses joined by closed switches are one supply point (a
primary disconnect does not split a bank); `bus_from` in a group is that
supply point's canonical bus. The whole pair is resolved before anything is counted, and the result
does not depend on component ids:

- center-tapped units come first (the lighting transformer anchors its bank),
  then units are ordered by their secondary phase-conductor set (smaller first);
- a unit is a **leg** when its set neither contains nor is contained in the set
  of a leg already taken; otherwise it is **parallel** to the bank;
- a unit whose maps cannot be read is **unassessed** and stays its own branch.

Among units with identical sets one is a leg and the rest are parallel, so the
count is the same whichever id sorts first. `groups` reports `units` (the legs),
`parallel_units`, `unassessed_units`, and `ambiguous`, which is true when a unit
partly overlaps the legs (for example `a–b` beside `a–n` and `b–n`): the
grouping is then one reading of the data, recorded rather than hidden.
`merged` holds the `(subtype, id)` of every leg beyond the first of its bank:
the branches a bus graph must not count separately.
"""
function _transformer_bank_groups(net)
    Unit = Tuple{String,String}
    merged = Set{Unit}()
    groups = Dict{String,Any}[]
    undetermined = Dict{String,Any}[]
    membership = Dict{Unit,Tuple{Vector{String},String}}()
    undetermined_pairs = Set{Tuple{Unit,Unit}}()
    result() = (merged=merged, groups=groups, undetermined=undetermined,
                membership=membership, undetermined_pairs=undetermined_pairs)
    xfmr = get(net, "transformer", Dict())
    xfmr isa AbstractDict || return result()
    roles = _index_roles(net)
    neutrals = roles === nothing ? nothing : roles.neutral
    by_secondary = Dict{String,Vector{Any}}()
    supply = _supply_point(net)
    for subtype in _BANKABLE_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa AbstractDict || continue
        for (id, t) in sub
            t isa AbstractDict || continue
            bf = get(t, "bus_from", nothing); bt = get(t, "bus_to", nothing)
            bf isa AbstractString && bt isa AbstractString && bf != bt || continue
            tf = get(t, "terminal_map_from", nothing)
            reach = supply.reach(String(bf), tf)
            String(bt) in reach && continue
            push!(get!(by_secondary, String(bt), Any[]),
                  (subtype=subtype, id=string(id), sig=_bank_unit_signature(t, neutrals),
                   bus=String(bf), terminals=tf, reach=reach))
        end
    end
    note_undetermined!(bt, a, b, reason) = begin
        x, y = sort!([a, b], by = u -> (u.subtype, u.id))
        push!(undetermined_pairs, ((x.subtype, x.id), (y.subtype, y.id)))
        push!(undetermined, Dict{String,Any}("bus_to" => bt, "units" => sort!([a.id, b.id]),
            "primary_buses" => sort!(unique!([a.bus, b.bus])), "reason" => reason))
    end
    for bt in sort!(collect(keys(by_secondary)))
        all_units = sort!(by_secondary[bt], by = u -> (u.subtype, u.id))
        # Units that share a supply point: some bus at which both windings are
        # wholly present. Components of that relation are candidate banks.
        # Each set's root is its lowest index (the larger root goes under the
        # smaller), so banks come out in the order of their first unit.
        component = _DisjointSets(1:length(all_units))
        root(i) = _ds_find!(component, i)
        for i in 1:length(all_units), j in i+1:length(all_units)
            isempty(intersect(all_units[i].reach, all_units[j].reach)) && continue
            ri, rj = root(i), root(j)
            ri == rj || _ds_union!(component, max(ri, rj), min(ri, rj))
        end
        banks = Vector{Any}[]
        for r in unique(root.(1:length(all_units)))
            members = [all_units[i] for i in 1:length(all_units) if root(i) == r]
            common = sort!(collect(intersect((u.reach for u in members)...)))
            if isempty(common)
                # A chain: each unit shares a bus with the next, but no bus
                # holds them all. Not one supply point; left as separate units.
                for i in 1:length(members), j in i+1:length(members)
                    note_undetermined!(bt, members[i], members[j], "no_common_supply_point")
                end
                for u in members; push!(banks, Any[[u], u.reach]); end
            else
                push!(banks, Any[members, common])
            end
        end
        for (units, common) in banks, u in units
            membership[(u.subtype, u.id)] = (common, bt)
        end
        # Units in different banks whose primaries are joined on some but not
        # all of a winding's conductors: not grouped, and not known to be separate.
        for x in 1:length(banks), y in x+1:length(banks), a in banks[x][1], b in banks[y][1]
            (supply.partial(a.bus, a.terminals, b.bus) || supply.partial(b.bus, b.terminals, a.bus)) || continue
            ((a.subtype, a.id), (b.subtype, b.id)) in undetermined_pairs && continue
            ((b.subtype, b.id), (a.subtype, a.id)) in undetermined_pairs && continue
            note_undetermined!(bt, a, b, "partial_primary_tie")
        end
        for (units, common) in banks
            length(units) > 1 || continue
            # A center-tapped unit is identified as a bank's lighting transformer
            # by its subtype, so it anchors the bank: a unit across one of its legs
            # is the parallel one, not the other way around.
            assessed = sort!([u for u in units if u.sig !== nothing],
                             by = u -> (u.subtype != "center_tap", length(u.sig),
                                        sort!(collect(u.sig)), u.subtype, u.id))
            legs = eltype(assessed)[]; parallel = eltype(assessed)[]; ambiguous = false
            for u in assessed
                clash = [l for l in legs if issubset(u.sig, l.sig) || issubset(l.sig, u.sig)]
                if isempty(clash)
                    push!(legs, u)
                else
                    push!(parallel, u)
                    any(l -> l.sig != u.sig, clash) && (ambiguous = true)
                end
            end
            for l in legs[2:end]
                push!(merged, (l.subtype, l.id))
            end
            push!(groups, Dict{String,Any}("bus_from" => first(common), "supply_buses" => common, "bus_to" => bt,
                "units" => sort!([l.id for l in legs]),
                "parallel_units" => sort!([u.id for u in parallel]),
                "unassessed_units" => sort!([u.id for u in units if u.sig === nothing]),
                "ambiguous" => ambiguous,
                "n_branches" => (isempty(legs) ? 0 : 1) + length(parallel) +
                                count(u -> u.sig === nothing, units)))
        end
    end
    sort!(groups, by = g -> (g["supply_buses"], g["bus_to"]))
    result()
end

# Conductors as a union-find over (bus, terminal) nodes: two nodes are one
# conductor when a branch of one of the given `kinds` maps them onto each
# other (position k of `terminal_map_from` onto position k of
# `terminal_map_to`). Open switches join nothing. This is the one place the
# profiler follows a conductor from bus to bus; labels are never compared.
# Returns `(find, parent)`: `find(node)` is the group's representative, and
# `parent` holds every node a branch touched.
function _conductor_groups(net; kinds=("line", "switch"))
    conductors = _DisjointSets{Tuple{String,String}}()
    find(x) = _ds_find!(conductors, x)
    for kind in kinds
        table = get(net, kind, nothing)
        table isa AbstractDict || continue
        for (_, c) in table
            c isa AbstractDict || continue
            kind == "switch" && get(c, "open_switch", false) === true && continue
            a = get(c, "bus_from", nothing); b = get(c, "bus_to", nothing)
            tf = get(c, "terminal_map_from", nothing); tt = get(c, "terminal_map_to", nothing)
            a isa AbstractString && b isa AbstractString && tf isa AbstractVector && tt isa AbstractVector ||
                continue
            for k in 1:min(length(tf), length(tt))
                tf[k] isa AbstractString && tt[k] isa AbstractString || continue
                _ds_union!(conductors, (String(a), String(tf[k])), (String(b), String(tt[k])))
            end
        end
    end
    (find, conductors.parent)
end

# Conductor-level evidence of where a transformer's primary winding is
# supplied from, for deciding whether units on different primary buses are one
# bank.
#
# Conductors are followed through closed switches only, terminal by terminal,
# by the switch's own terminal maps (a label may change across a switch; the
# conductor does not). A winding's **supply point** is the set of buses at
# which EVERY one of its primary terminals, the neutral included, is present
# on the same conductors. Two units share a supply point when those sets have
# a bus in common: a bus at which both windings are wholly present. Units on
# one bus always do, whatever else their conductors reach, and a full primary
# disconnect between two units leaves the bank what it was.
#
# Anything less is not grouped. A tie that carries some but not all of a
# winding's conductors (one phase of two, the phases without the neutral) is a
# **partial** tie: the units stay separate branches and the pair is reported as
# undetermined. A tie on conductors neither winding uses, or a neutral bond
# alone, is no evidence at all.
#
# The result does not depend on bus names, switch direction or terminal
# labels: it is built from conductor groups, never from a representative bus.
function _supply_point(net)
    Node = Tuple{String,String}
    find, parent = _conductor_groups(net; kinds=("switch",))
    buses_of = Dict{Node,Set{String}}()            # conductor group => buses it is present at
    for n in collect(keys(parent)); push!(get!(buses_of, find(n), Set{String}()), n[1]); end
    roles = _index_roles(net)
    is_return(x) = _is_return_label(roles, x)
    readable(terminals) = terminals isa AbstractVector && !isempty(terminals) &&
        all(x -> x isa AbstractString, terminals)
    present(bus, t) = haskey(parent, (bus, t)) ? buses_of[find((bus, t))] : Set{String}((bus,))
    # Sorted list of the buses every primary terminal of the winding reaches.
    function reach(bus::AbstractString, terminals)
        bus = String(bus)
        (isempty(parent) || !readable(terminals)) && return [bus]
        sort!(collect(intersect((present(bus, String(t)) for t in terminals)...)))
    end
    # True when a PHASE conductor of the winding at `bus` is present at
    # `other`. Asked about two units that share no supply point: one crossing
    # phase conductor then makes the pair a partial tie.
    function partial(bus::AbstractString, terminals, other::AbstractString)
        bus = String(bus); other = String(other)
        (isempty(parent) || !readable(terminals) || bus == other) && return false
        any(t -> !is_return(t) && other in present(bus, String(t)), terminals)
    end
    (reach=reach, partial=partial)
end

# Single-phase unit subtypes that are banked in practice.
const _BANKABLE_SUBTYPES = ("single_phase", "center_tap")

# Secondary PHASE conductors of one unit (its neutral is shared by every leg of
# a bank and says nothing about which leg the unit is). Two units between the
# same bus pair are legs of one bank when neither's phase set contains the
# other's. A unit across conductors another unit already spans — the same
# pair, or the two legs of a center-tapped winding — is paralleled there,
# whatever its primary connection, and closes a loop.
function _bank_unit_signature(t, neutral_labels=nothing)
    f = get(t, "terminal_map_from", nothing); to = get(t, "terminal_map_to", nothing)
    f isa AbstractVector && to isa AbstractVector || return nothing
    all(x -> x isa AbstractString, to) || return nothing
    sig = Set{String}(string(x) for x in to if !_is_neutral_label(neutral_labels, string(x)))
    isempty(sig) ? nothing : sig
end

"""
    _classify_zones(net) -> Vector{NamedTuple}

Classify each galvanic zone (the components left after cutting transformer
windings) by phase topology.
Returns one entry per zone: `(buses, label, phases, topology, feed)` where
`topology` is one of:

- `:split_phase` — a `center_tap` transformer's `bus_to` lies in the zone
  (the modeled cause of split-phase service; NA 120-0-120, AU 230-0-230);
- `:swer` — the zone has one distinct phase conductor across all its buses, is
  transformer-isolated (contains no voltage-source bus), **and** a branch in it
  witnesses the earth return: at least one line or closed switch carries that
  phase alone, and none carries a neutral conductor. This is the
  Single-Wire-Earth-Return signature;
- `:single_phase` — one phase conductor otherwise. That includes a two-wire
  (phase + metallic neutral) section and a branchless service bus behind a
  single-phase transformer, where no branch establishes an earth return;
- `:three_phase` / `:other` — by phase count otherwise.

A perfectly grounded reference terminal (the `n_ref` an importer adds next to a
transported neutral) is not counted as a phase.

`feed` lists `(subtype, transformer_id)` for transformers whose `bus_to` ∈ zone.
"""
function _classify_zones(net::Dict{String,Any})
    buses = get(net, "bus", Dict())

    vsrc_buses = Set(string(get(vs, "bus", ""))
                     for (_, vs) in get(net, "voltage_source", Dict()) if vs isa Dict)

    # Map each transformer's to-bus → [(subtype, id)]
    feed_by_bus = Dict{String,Vector{Tuple{String,String}}}()
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            bt = get(t, "bus_to", nothing)
            bt isa AbstractString || continue
            push!(get!(feed_by_bus, bt, Tuple{String,String}[]), (subtype, string(id)))
        end
    end
    # n-winding: every non-reference winding's bus is fed by the transformer.
    # A dual-secondary unit lands two windings on one bus — record the feeding
    # transformer once per bus, not once per winding.
    for (id, t) in get(get(net, "transformer", Dict()), "n_winding", Dict())
        ws = _nw_windings(t)
        fed = Set{String}()
        for j in 2:length(ws)
            bj = ws[j].bus
            (isempty(bj) || bj in fed) && continue
            push!(fed, bj)
            push!(get!(feed_by_bus, bj, Tuple{String,String}[]), ("n_winding", string(id)))
        end
    end

    # Branch evidence for the return path, gathered once per zone: a branch
    # that carries a neutral is a metallic return; a branch that carries one
    # phase alone leaves the earth as the only return.
    zones = _galvanic_zones(net)
    zone_of = Dict{String,Int}()
    for (k, zone) in enumerate(zones), bid in zone
        zone_of[bid] = k
    end
    n_single_wire = zeros(Int, length(zones)); n_with_neutral = zeros(Int, length(zones))
    for kind in ("line", "switch"), (_, c) in get(net, kind, Dict())
        c isa AbstractDict || continue
        kind == "switch" && get(c, "open_switch", false) === true && continue
        f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
        f isa AbstractString && t isa AbstractString || continue
        k = get(zone_of, f, 0)
        k != 0 && k == get(zone_of, t, 0) || continue
        tf = get(c, "terminal_map_from", nothing)
        tf isa AbstractVector && !isempty(tf) || continue
        nf = _neutral_terminal(get(buses, f, Dict{String,Any}()))
        if any(x -> string(x) == nf || _is_convention_neutral(string(x)), tf)
            n_with_neutral[k] += 1
        elseif length(tf) == 1
            n_single_wire[k] += 1
        end
    end

    out = NamedTuple[]
    for (zone_index, zone) in enumerate(zones)
        phases = Set{String}()
        for bid in zone
            b  = get(buses, bid, Dict{String,Any}())
            nt = _neutral_terminal(b)
            pg = Set(string.(get(b, "perfectly_grounded_terminals", String[])))
            for t in get(b, "terminal_names", String[])
                st = string(t)
                st == nt && continue
                st in pg && _is_convention_neutral(st) && continue
                push!(phases, st)
            end
        end

        earth_return = n_single_wire[zone_index] > 0 && n_with_neutral[zone_index] == 0

        feed = Tuple{String,String}[]
        for bid in zone
            append!(feed, get(feed_by_bus, bid, Tuple{String,String}[]))
        end

        has_source = any(bid -> bid in vsrc_buses, zone)
        is_ct_fed  = any(f -> f[1] == "center_tap", feed)

        topology =
            is_ct_fed                            ? :split_phase  :
            (length(phases) == 1 && !has_source && earth_return) ? :swer :
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

# Endpoint-normalized declaration comparison, shared by topology and redundancy.
# Ordered conductor coordinates are compared strictly; no inferred permutation.
function _parallel_line_evidence(net; level_by_bus=Dict(), busset=nothing)
    groups = Dict{Tuple{String,String},Vector{Tuple{String,Any,Bool}}}()
    for (id, line) in get(net, "line", Dict())
        line isa AbstractDict || continue
        a = get(line, "bus_from", nothing); b = get(line, "bus_to", nothing)
        a isa AbstractString && b isa AbstractString && a != b || continue
        busset !== nothing && !(a in busset && b in busset) && continue
        pair = minmax(String(a), String(b))
        push!(get!(groups, pair, Tuple{String,Any,Bool}[]), (string(id), line, a == pair[1]))
    end
    names = ("incomplete_terminal_map", "terminal_map_disagreement", "unsupported_orientation",
             "same_declared_fields", "different_declared_fields")
    counts = Dict(k => 0 for k in names); members_by_class = copy(counts); excess_by_class = copy(counts)
    multiplicities = Dict{String,Int}(); full = Dict{String,Any}[]; witnesses = Dict{String,Any}[]
    for pair in sort!(collect(keys(groups)))
        members = sort!(groups[pair], by=first); n = length(members)
        n > 1 || continue
        maps = Any[]; fields = Any[]; supported = true
        for (_, line, forward) in members
            fm = get(line, forward ? "terminal_map_from" : "terminal_map_to", nothing)
            tm = get(line, forward ? "terminal_map_to" : "terminal_map_from", nothing)
            push!(maps, (fm, tm))
            normalized = Dict{String,Any}()
            for (k, v) in line
                k in ("bus_from", "bus_to", "terminal_map_from", "terminal_map_to", "meta") && continue
                key = k; value = v
                if !forward
                    m = match(r"^([GB])_(from|to)_(.+)$", k)
                    if m !== nothing
                        key = "$(m[1])_$(m[2] == "from" ? "to" : "from")_$(m[3])"
                    elseif k in ("va_diff_min", "va_diff_max")
                        key = k == "va_diff_min" ? "va_diff_max" : "va_diff_min"
                        if v isa Real || (v isa AbstractVector && all(x -> x isa Real, v))
                            value = -v
                        else
                            supported = false
                        end
                    end
                end
                normalized[key] = value
            end
            push!(fields, normalized)
        end
        validmap(m) = m isa AbstractVector && !isempty(m) && all(t -> t isa AbstractString, m) && length(unique(m)) == length(m)
        class = any(m -> !validmap(m[1]) || !validmap(m[2]) || length(m[1]) != length(m[2]), maps) ? "incomplete_terminal_map" :
            !all(m -> isequal(m, maps[1]), maps) ? "terminal_map_disagreement" :
            !supported ? "unsupported_orientation" :
            all(f -> isequal(f, fields[1]), fields) ? "same_declared_fields" : "different_declared_fields"
        counts[class] += 1; members_by_class[class] += n; excess_by_class[class] += n-1
        multiplicities[string(n)] = get(multiplicities, string(n), 0)+1
        ids = [m[1] for m in members]
        push!(full, Dict{String,Any}("bus_from" => pair[1], "bus_to" => pair[2], "line_ids" => ids,
            "classification" => class, "n_members" => n, "n_excess" => n-1))
        if count(w -> w["classification"] == class, witnesses) < 5
            push!(witnesses, Dict{String,Any}("bus_pair" => collect(pair), "line_ids" => ids[1:min(end, 5)],
                "classification" => class, "n_members" => n, "n_excess" => n-1,
                "members_truncated" => n > 5, "voltage_level" => get(level_by_bus, pair[1], "unassigned")))
        end
    end
    Dict{String,Any}("n_groups" => length(full), "groups" => full, "classification_counts" => counts,
        "member_counts_by_class" => members_by_class, "excess_counts_by_class" => excess_by_class,
        "multiplicity_counts" => multiplicities, "n_parallel_excess" => sum(values(excess_by_class)),
        "n_identical_group_excess" => excess_by_class["same_declared_fields"],
        "witnesses" => witnesses, "witnesses_per_class_limit" => 5, "member_witness_limit" => 5,
        "witnesses_truncated" => length(witnesses) < length(full),
        "comparison_basis" => "ordered_maps_and_all_declared_fields_except_meta_with_endpoint_shunts_and_signed_angle_bounds_normalized",
        "asset_identity" => "unassessed")
end
