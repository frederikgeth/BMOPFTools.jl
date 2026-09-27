# Shared physical bus-branch inventory. Parallel records retain distinct IDs.
const _PhysicalBranch = NamedTuple{(:kind, :id, :from, :to, :continuous),
    Tuple{String,String,String,String,Bool}}
const _ConductorNode = Tuple{String,String}
const _ConductorEdge = NamedTuple{(:kind, :id, :from, :to),
    Tuple{String,String,_ConductorNode,_ConductorNode}}

function _physical_branch_inventory(net::Dict{String,Any})
    buses = sort!(String[string(bus) for bus in keys(get(net, "bus", Dict()))])
    busset = Set(buses)
    fixed = _PhysicalBranch[]
    declared = _PhysicalBranch[]
    switches = NamedTuple{(:id, :from, :to, :open),Tuple{String,String,String,Bool}}[]
    invalid_switches = String[]
    skipped_ids = String[]
    skipped = 0
    function branch(kind, id, from, to, continuous)
        if !(from isa AbstractString && to isa AbstractString && from != to &&
             from in busset && to in busset)
            skipped += 1
            push!(skipped_ids, "$kind:$(string(id))")
            return nothing
        end
        (kind=kind, id=string(id), from=String(from), to=String(to),
         continuous=continuous)
    end
    for (id, line) in get(net, "line", Dict())
        edge = branch("line", id, get(line, "bus_from", nothing),
                      get(line, "bus_to", nothing), true)
        edge === nothing || (push!(fixed, edge); push!(declared, edge))
    end
    for (id, sw) in get(net, "switch", Dict())
        state = get(sw, "open_switch", nothing)
        from = get(sw, "bus_from", nothing); to = get(sw, "bus_to", nothing)
        # Keep the existing declared-structure fallback for malformed status
        # records, but do not assess a counterfactual from that fallback.
        edge = state === true ? nothing : branch("switch", id, from, to, true)
        edge === nothing || push!(declared, edge)
        valid_endpoints = from isa AbstractString && to isa AbstractString &&
            from != to && from in busset && to in busset
        if !(state isa Bool && valid_endpoints)
            push!(invalid_switches, string(id))
        else
            push!(switches, (id=string(id), from=String(from), to=String(to), open=state))
        end
    end
    transformers = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue
        sub = get(transformers, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            edge = branch("transformer:$subtype", id, get(t, "bus_from", nothing),
                          get(t, "bus_to", nothing), subtype in GALVANIC_CONTINUOUS_SUBTYPES)
            edge === nothing || (push!(fixed, edge); push!(declared, edge))
        end
    end
    for (id, t) in get(transformers, "n_winding", Dict())
        windings = _nw_windings(t)
        isempty(windings) && continue
        for j in 2:length(windings)
            edge = branch("transformer:n_winding", "$id:$j", windings[1].bus,
                          windings[j].bus, false)
            edge === nothing || (push!(fixed, edge); push!(declared, edge))
        end
    end
    sort!(switches, by=s -> s.id)
    sort!(invalid_switches)
    sort!(skipped_ids)
    (buses=buses, fixed=fixed, declared=declared, switches=switches,
     invalid_switches=invalid_switches, skipped=skipped, skipped_ids=skipped_ids)
end

# The declared conductor-path pass and switch counterfactuals use the same
# terminal-map validity rule. A switch record maps a group of terminal edges;
# the whole group changes state together.
function _mapped_conductor_inventory(net::Dict{String,Any})
    buses = get(net, "bus", Dict())
    nodes = _ConductorNode[]
    invalid_bus_ids = String[]
    for bus in sort!(collect(String.(keys(buses))))
        record = buses[bus]
        if !(record isa AbstractDict)
            push!(invalid_bus_ids, bus)
            continue
        end
        terms = get(record, "terminal_names", nothing)
        if !(terms isa AbstractVector && !isempty(terms))
            push!(invalid_bus_ids, bus)
            continue
        end
        for term in sort!(unique(string.(terms)))
            push!(nodes, (bus, term))
        end
    end
    index = Dict(node => i for (i, node) in enumerate(nodes))
    fixed = _ConductorEdge[]
    declared = _ConductorEdge[]
    switch_edges = Dict{String,Vector{_ConductorEdge}}()
    invalid_map_ids = String[]
    skipped_declared = 0
    function mapped_edges(kind, id, branch)
        a = get(branch, "bus_from", nothing); b = get(branch, "bus_to", nothing)
        from = get(branch, "terminal_map_from", nothing)
        to = get(branch, "terminal_map_to", nothing)
        if !(a isa AbstractString && b isa AbstractString &&
             from isa AbstractVector && to isa AbstractVector &&
             !isempty(from) && length(from) == length(to) &&
             all(i -> haskey(index, (String(a), string(from[i]))) &&
                      haskey(index, (String(b), string(to[i]))), eachindex(from)))
            push!(invalid_map_ids, "$kind:$(string(id))")
            return nothing
        end
        _ConductorEdge[(kind=kind, id=string(id),
                        from=(String(a), string(from[i])),
                        to=(String(b), string(to[i]))) for i in eachindex(from)]
    end
    for (id, line) in get(net, "line", Dict())
        if !(line isa AbstractDict)
            push!(invalid_map_ids, "line:$(string(id))")
            continue
        end
        edges = mapped_edges("line", id, line)
        if edges === nothing
            skipped_declared += 1
        else
            append!(fixed, edges); append!(declared, edges)
        end
    end
    for (id, sw) in get(net, "switch", Dict())
        if !(sw isa AbstractDict)
            push!(invalid_map_ids, "switch:$(string(id))")
            continue
        end
        open = get(sw, "open_switch", false) === true
        edges = mapped_edges("switch", id, sw)
        if edges === nothing
            open || (skipped_declared += 1)
        else
            switch_edges[string(id)] = edges
            open || append!(declared, edges)
        end
    end
    boundary_nodes = Set{_ConductorNode}()
    invalid_boundary_ids = String[]
    function mark_port(label, bus, terminals)
        valid = bus isa AbstractString && terminals isa AbstractVector &&
            !isempty(terminals) &&
            all(term -> haskey(index, (String(bus), string(term))), terminals)
        if !valid
            push!(invalid_boundary_ids, label)
        end
        (bus isa AbstractString && terminals isa AbstractVector) || return
        for term in terminals
            node = (String(bus), string(term))
            haskey(index, node) && push!(boundary_nodes, node)
        end
    end
    for (id, source) in get(net, "voltage_source", Dict())
        if !(source isa AbstractDict)
            push!(invalid_boundary_ids, "voltage_source:$(string(id))")
            continue
        end
        mark_port("voltage_source:$(string(id))", get(source, "bus", nothing),
                  get(source, "terminal_map", nothing))
    end
    transformers = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(transformers, subtype, nothing)
        sub isa AbstractDict || continue
        for (id, transformer) in sub
            if !(transformer isa AbstractDict)
                push!(invalid_boundary_ids, "transformer:$subtype:$(string(id))")
                continue
            end
            if subtype in WINDING_LIST_SUBTYPES
                windings = _nw_windings(transformer)
                isempty(windings) && push!(invalid_boundary_ids, "transformer:$subtype:$(string(id))")
                for (j, winding) in enumerate(windings)
                    mark_port("transformer:$subtype:$(string(id)):$j",
                              winding.bus, winding.terminal_map)
                end
            else
                mark_port("transformer:$subtype:$(string(id)):from",
                          get(transformer, "bus_from", nothing),
                          get(transformer, "terminal_map_from", nothing))
                mark_port("transformer:$subtype:$(string(id)):to",
                          get(transformer, "bus_to", nothing),
                          get(transformer, "terminal_map_to", nothing))
            end
        end
    end
    load_at = zeros(Int, length(nodes))
    invalid_load_ids = String[]
    for (id, load) in get(net, "load", Dict())
        if !(load isa AbstractDict)
            push!(invalid_load_ids, string(id))
            continue
        end
        bus = get(load, "bus", nothing)
        terms = get(load, "terminal_map", nothing)
        if !(bus isa AbstractString && terms isa AbstractVector &&
             !isempty(terms) && all(term -> haskey(index, (String(bus), string(term))), terms))
            push!(invalid_load_ids, string(id))
            continue
        end
        for term in terms
            load_at[index[(String(bus), string(term))]] += 1
        end
    end
    sort!(invalid_bus_ids); sort!(invalid_map_ids)
    sort!(invalid_load_ids); sort!(invalid_boundary_ids)
    (nodes=nodes, index=index, fixed=fixed, declared=declared,
     switch_edges=switch_edges, boundary_nodes=boundary_nodes, load_at=load_at,
     invalid_bus_ids=invalid_bus_ids, invalid_map_ids=invalid_map_ids,
     invalid_load_ids=invalid_load_ids,
     invalid_boundary_ids=invalid_boundary_ids,
     skipped_declared=skipped_declared)
end

function _scenario_graph_stats(buses, edges, source_at, load_at)
    index = Dict(bus => i for (i, bus) in enumerate(buses))
    graph = SimpleGraph(length(buses))
    for edge in edges
        add_edge!(graph, index[edge.from], index[edge.to])
    end
    components = connected_components(graph)
    component_of = zeros(Int, length(buses))
    sizes = Int[]; sources = Int[]; loads = Int[]
    for (cid, members) in enumerate(components)
        for i in members
            component_of[i] = cid
        end
        push!(sizes, length(members))
        push!(sources, sum(source_at[i] for i in members; init=0))
        push!(loads, sum(load_at[i] for i in members; init=0))
    end
    counts = _topology_counts(buses, edges)
    counts["n_components_with_source"] = count(>(0), sources)
    counts["n_components_with_multiple_sources"] = count(>(1), sources)
    counts["n_buses_without_source_path"] = sum((sizes[i] for i in eachindex(sizes) if sources[i] == 0); init=0)
    counts["n_loads_without_source_path"] = sum((loads[i] for i in eachindex(loads) if sources[i] == 0); init=0)
    (counts=counts, index=index, component_of=component_of, sizes=sizes,
     sources=sources, loads=loads)
end

# Iterative low-link DFS uses physical edge IDs as parent markers. A parallel
# edge is a back edge and prevents a false bridge.
function _scenario_bridges(buses, edges, index, source_at, load_at)
    adjacency = [Tuple{Int,Int}[] for _ in buses]
    for (eid, edge) in enumerate(edges)
        a = index[edge.from]; b = index[edge.to]
        push!(adjacency[a], (b, eid)); push!(adjacency[b], (a, eid))
    end
    n = length(buses)
    arrival = zeros(Int, n); low = zeros(Int, n)
    parent = zeros(Int, n); parent_edge = zeros(Int, n); cursor = ones(Int, n)
    subtree_buses = ones(Int, n)
    subtree_sources = copy(source_at); subtree_loads = copy(load_at)
    bridge_child = Dict{Int,Int}()
    tick = 0
    for root in 1:n
        arrival[root] == 0 || continue
        stack = [root]
        while !isempty(stack)
            v = stack[end]
            if arrival[v] == 0
                tick += 1; arrival[v] = tick; low[v] = tick
            end
            if cursor[v] <= length(adjacency[v])
                w, eid = adjacency[v][cursor[v]]
                cursor[v] += 1
                eid == parent_edge[v] && continue
                if arrival[w] == 0
                    parent[w] = v; parent_edge[w] = eid
                    push!(stack, w)
                else
                    low[v] = min(low[v], arrival[w])
                end
            else
                pop!(stack)
                p = parent[v]
                if p != 0
                    low[p] = min(low[p], low[v])
                    subtree_buses[p] += subtree_buses[v]
                    subtree_sources[p] += subtree_sources[v]
                    subtree_loads[p] += subtree_loads[v]
                    low[v] > arrival[p] && (bridge_child[parent_edge[v]] = v)
                end
            end
        end
    end
    (child=bridge_child, buses=subtree_buses, sources=subtree_sources,
     loads=subtree_loads)
end

function _conductor_view_counts(stats, mapped_edges)
    counts = stats.counts
    Dict{String,Any}(
        "n_bus_terminals" => counts["n_buses"],
        "n_mapped_conductor_edges" => length(mapped_edges),
        "n_path_components" => counts["n_components"],
        "n_boundary_components" => counts["n_components_with_source"],
        "n_bus_terminals_without_boundary" => counts["n_buses_without_source_path"],
        "n_load_terminals_without_boundary" => counts["n_loads_without_source_path"])
end

function _conductor_switch_scenarios(net::Dict{String,Any}, physical_inventory,
                                     bus_class_by_switch)
    inv = _mapped_conductor_inventory(net)
    evidence = Dict{String,Any}(
        "scope" => "mapped_line_and_switch_terminal_paths_with_source_and_transformer_ports_as_boundaries",
        "invalid_bus_ids" => inv.invalid_bus_ids,
        "invalid_branch_map_ids" => inv.invalid_map_ids,
        "invalid_load_ids" => inv.invalid_load_ids,
        "invalid_boundary_port_ids" => inv.invalid_boundary_ids)
    result = Dict{String,Any}("assessment" => evidence)
    if isempty(inv.nodes)
        result["status"] = "inapplicable"
        evidence["reason"] = "No bus terminal_names are declared."
        return result
    elseif !isempty(inv.invalid_bus_ids) || !isempty(inv.invalid_map_ids) ||
           !isempty(inv.invalid_load_ids) ||
           !isempty(inv.invalid_boundary_ids)
        result["status"] = "inapplicable"
        evidence["reason"] = "Complete bus terminal names, line/switch maps, load terminal maps, and boundary port maps are required."
        return result
    elseif isempty(inv.boundary_nodes)
        result["status"] = "indeterminate"
        evidence["reason"] = "No declared source or transformer boundary port is available."
        return result
    end
    boundary_at = [node in inv.boundary_nodes ? 1 : 0 for node in inv.nodes]
    envelope = copy(inv.fixed)
    for sw in physical_inventory.switches
        append!(envelope, inv.switch_edges[sw.id])
    end
    declared = _scenario_graph_stats(inv.nodes, inv.declared, boundary_at, inv.load_at)
    backbone = _scenario_graph_stats(inv.nodes, inv.fixed, boundary_at, inv.load_at)
    all_closed = _scenario_graph_stats(inv.nodes, envelope, boundary_at, inv.load_at)
    result["status"] = "assessed"
    evidence["reason"] = "Boundary paths are graph incidence only; transformer conversion and energization are unassessed."
    result["declared"] = _conductor_view_counts(declared, inv.declared)
    result["fixed_backbone"] = _conductor_view_counts(backbone, inv.fixed)
    result["all_closed_envelope"] = _conductor_view_counts(all_closed, envelope)

    bridges = _scenario_bridges(inv.nodes, inv.declared, declared.index,
                                 boundary_at, inv.load_at)
    switch_eids = Dict{String,Vector{Int}}()
    for (eid, edge) in enumerate(inv.declared)
        edge.kind == "switch" || continue
        push!(get!(switch_eids, edge.id, Int[]), eid)
    end
    classes = Dict(k => 0 for k in ("path_merge", "path_split", "no_path_change"))
    cross_layer = Dict{String,Int}()
    n_gain = 0; n_loss = 0; n_group_fallbacks = 0
    witnesses = Dict{String,Any}[]
    witnessed = Dict{String,Int}()
    for sw in physical_inventory.switches
        edges = inv.switch_edges[sw.id]
        gained = 0; lost = 0
        if sw.open
            affected = Set{Int}()
            for edge in edges
                push!(affected, declared.component_of[declared.index[edge.from]])
                push!(affected, declared.component_of[declared.index[edge.to]])
            end
            parent = Dict(cid => cid for cid in affected)
            function root(cid)
                while parent[cid] != cid
                    cid = parent[cid]
                end
                cid
            end
            merges = 0
            for edge in edges
                a = root(declared.component_of[declared.index[edge.from]])
                b = root(declared.component_of[declared.index[edge.to]])
                if a != b
                    parent[b] = a
                    merges += 1
                end
            end
            groups = Dict{Int,Vector{Int}}()
            for cid in affected
                push!(get!(groups, root(cid), Int[]), cid)
            end
            for members in values(groups)
                any(cid -> declared.sources[cid] > 0, members) || continue
                gained += sum((declared.loads[cid] for cid in members
                               if declared.sources[cid] == 0); init=0)
            end
            delta = -merges
            class = delta < 0 ? "path_merge" : "no_path_change"
        else
            eids = switch_eids[sw.id]
            component_ids = [declared.component_of[declared.index[inv.declared[eid].from]]
                             for eid in eids]
            if length(unique(component_ids)) == length(eids)
                delta = 0
                for (eid, cid) in zip(eids, component_ids)
                    haskey(bridges.child, eid) || continue
                    delta += 1
                    child = bridges.child[eid]
                    side_boundary = bridges.sources[child]
                    other_boundary = declared.sources[cid] - side_boundary
                    if side_boundary == 0 && other_boundary > 0
                        lost += bridges.loads[child]
                    elseif other_boundary == 0 && side_boundary > 0
                        lost += declared.loads[cid] - bridges.loads[child]
                    end
                end
            else
                # Multiple mapped pairs in one path component can form a
                # group cut even if no individual edge is a bridge.
                n_group_fallbacks += 1
                remaining = [edge for edge in inv.declared
                             if !(edge.kind == "switch" && edge.id == sw.id)]
                after = _scenario_graph_stats(inv.nodes, remaining,
                                               boundary_at, inv.load_at)
                delta = after.counts["n_components"] - declared.counts["n_components"]
                lost = after.counts["n_loads_without_source_path"] -
                       declared.counts["n_loads_without_source_path"]
            end
            class = delta > 0 ? "path_split" : "no_path_change"
        end
        classes[class] += 1
        pair = "$(bus_class_by_switch[sw.id])|$class"
        cross_layer[pair] = get(cross_layer, pair, 0) + 1
        gained > 0 && (n_gain += 1)
        lost > 0 && (n_loss += 1)
        if get(witnessed, class, 0) < 5
            push!(witnesses, Dict{String,Any}(
                "switch_id" => sw.id, "declared_state" => sw.open ? "open" : "closed",
                "bus_from" => sw.from, "bus_to" => sw.to,
                "classification" => class,
                "bus_graph_classification" => bus_class_by_switch[sw.id],
                "n_mapped_terminal_pairs" => length(edges),
                "delta_path_components" => delta,
                "n_load_terminals_gaining_boundary_path" => gained,
                "n_load_terminals_losing_boundary_path" => lost))
            witnessed[class] = get(witnessed, class, 0) + 1
        end
    end
    result["transition_counts"] = Dict{String,Any}(
        "classifications" => classes,
        "n_switches_gaining_load_boundary_path" => n_gain,
        "n_switches_losing_load_boundary_path" => n_loss)
    result["cross_layer_counts"] = cross_layer
    result["witnesses"] = witnesses
    result["witnesses_per_class_limit"] = 5
    result["assessment"]["n_group_cut_fallbacks"] = n_group_fallbacks
    result
end

function _switch_scenarios(net::Dict{String,Any}, inventory=_physical_branch_inventory(net))::Dict{String,Any}
    all_switches = get(net, "switch", Dict())
    counts = Dict{String,Any}(
        "n_records" => length(all_switches),
        "n_valid" => length(inventory.switches),
        "n_invalid" => length(inventory.invalid_switches),
        "n_assessed" => isempty(inventory.invalid_switches) ? length(inventory.switches) : 0,
        "n_declared_open" => count(s -> s.open, inventory.switches),
        "n_declared_closed" => count(s -> !s.open, inventory.switches))
    assessment = Dict{String,Any}(
        "scope" => "physical_bus_graph_with_declared_sources_and_loads",
        "conductor_status" => "inapplicable",
        "conductor_reason" => "",
        "invalid_switch_ids" => inventory.invalid_switches,
        "skipped_branch_ids" => inventory.skipped_ids)
    result = Dict{String,Any}("switch_counts" => counts, "assessment" => assessment)
    if isempty(all_switches)
        result["status"] = "inapplicable"
        assessment["reason"] = "No switch records."
        assessment["conductor_reason"] = "No switch records."
        result["conductor"] = Dict{String,Any}(
            "status" => "inapplicable", "reason" => "No switch records.")
        return result
    elseif !isempty(inventory.invalid_switches)
        result["status"] = "indeterminate"
        assessment["reason"] = "Every switch needs a Boolean open_switch and two distinct declared bus endpoints."
        assessment["conductor_status"] = "indeterminate"
        assessment["conductor_reason"] = "Switch state or bus endpoints are invalid."
        result["conductor"] = Dict{String,Any}(
            "status" => "indeterminate", "reason" => assessment["conductor_reason"])
        return result
    end
    buses = inventory.buses
    index = Dict(bus => i for (i, bus) in enumerate(buses))
    source_at = zeros(Int, length(buses)); load_at = zeros(Int, length(buses))
    for (_, source) in get(net, "voltage_source", Dict())
        bus = get(source, "bus", nothing)
        haskey(index, bus) && (source_at[index[bus]] += 1)
    end
    for (_, load) in get(net, "load", Dict())
        bus = get(load, "bus", nothing)
        haskey(index, bus) && (load_at[index[bus]] += 1)
    end
    envelope = copy(inventory.declared)
    for sw in inventory.switches
        sw.open && push!(envelope, (kind="switch", id=sw.id, from=sw.from,
                                   to=sw.to, continuous=true))
    end
    declared = _scenario_graph_stats(buses, inventory.declared, source_at, load_at)
    backbone = _scenario_graph_stats(buses, inventory.fixed, source_at, load_at)
    all_closed = _scenario_graph_stats(buses, envelope, source_at, load_at)
    result["status"] = "assessed"
    result["declared"] = declared.counts
    result["fixed_backbone"] = backbone.counts
    result["all_closed_envelope"] = all_closed.counts
    assessment["reason"] = "Bus graph only; a source path does not establish energization or switching feasibility."

    bridges = _scenario_bridges(buses, inventory.declared, index, source_at, load_at)
    closed_edge_id = Dict(edge.id => eid for (eid, edge) in enumerate(inventory.declared)
                          if edge.kind == "switch")
    pair_count = Dict{Tuple{String,String},Int}()
    for edge in inventory.declared
        pair = minmax(edge.from, edge.to)
        pair_count[pair] = get(pair_count, pair, 0) + 1
    end
    classes = Dict(k => 0 for k in ("component_join", "cycle_closure",
                                    "parallel_closure", "bridge", "alternate_path"))
    n_source_path_gain = 0; n_source_path_loss = 0; n_source_component_joins = 0
    witnesses = Dict{String,Any}[]
    witnessed = Dict{String,Int}()
    bus_class_by_switch = Dict{String,String}()
    for sw in inventory.switches
        a = index[sw.from]; b = index[sw.to]
        cid_a = declared.component_of[a]; cid_b = declared.component_of[b]
        gain_buses = 0; gain_loads = 0; lost_buses = 0; lost_loads = 0
        joins_sources = false
        if sw.open
            if cid_a != cid_b
                class = "component_join"
                delta_components = -1; delta_cycle_rank = 0
                sa = declared.sources[cid_a]; sb = declared.sources[cid_b]
                joins_sources = sa > 0 && sb > 0
                if sa > 0 && sb == 0
                    gain_buses = declared.sizes[cid_b]; gain_loads = declared.loads[cid_b]
                elseif sb > 0 && sa == 0
                    gain_buses = declared.sizes[cid_a]; gain_loads = declared.loads[cid_a]
                end
            else
                class = get(pair_count, minmax(sw.from, sw.to), 0) > 0 ?
                    "parallel_closure" : "cycle_closure"
                delta_components = 0; delta_cycle_rank = 1
            end
        else
            eid = closed_edge_id[sw.id]
            if haskey(bridges.child, eid)
                class = "bridge"
                delta_components = 1; delta_cycle_rank = 0
                child = bridges.child[eid]
                side_sources = bridges.sources[child]
                other_sources = declared.sources[cid_a] - side_sources
                if side_sources == 0 && other_sources > 0
                    lost_buses = bridges.buses[child]; lost_loads = bridges.loads[child]
                elseif other_sources == 0 && side_sources > 0
                    lost_buses = declared.sizes[cid_a] - bridges.buses[child]
                    lost_loads = declared.loads[cid_a] - bridges.loads[child]
                end
            else
                class = "alternate_path"
                delta_components = 0; delta_cycle_rank = -1
            end
        end
        classes[class] += 1
        bus_class_by_switch[sw.id] = class
        gain_buses > 0 && (n_source_path_gain += 1)
        lost_buses > 0 && (n_source_path_loss += 1)
        joins_sources && (n_source_component_joins += 1)
        if get(witnessed, class, 0) < 5
            push!(witnesses, Dict{String,Any}(
                "switch_id" => sw.id, "declared_state" => sw.open ? "open" : "closed",
                "bus_from" => sw.from, "bus_to" => sw.to, "classification" => class,
                "delta_components" => delta_components, "delta_cycle_rank" => delta_cycle_rank,
                "n_buses_gaining_source_path" => gain_buses,
                "n_loads_gaining_source_path" => gain_loads,
                "n_buses_losing_source_path" => lost_buses,
                "n_loads_losing_source_path" => lost_loads,
                "joins_source_components" => joins_sources))
            witnessed[class] = get(witnessed, class, 0) + 1
        end
    end
    result["transition_counts"] = Dict{String,Any}(
        "classifications" => classes,
        "n_switches_gaining_source_path" => n_source_path_gain,
        "n_switches_losing_source_path" => n_source_path_loss,
        "n_source_component_joins" => n_source_component_joins)
    result["witnesses"] = witnesses
    result["witnesses_per_class_limit"] = 5
    result["conductor"] = _conductor_switch_scenarios(net, inventory, bus_class_by_switch)
    assessment["conductor_status"] = result["conductor"]["status"]
    assessment["conductor_reason"] = result["conductor"]["assessment"]["reason"]
    result
end
