# Shared physical bus-branch inventory. Parallel records retain distinct IDs.
const _PhysicalBranch = NamedTuple{(:kind, :id, :from, :to, :continuous),
    Tuple{String,String,String,String,Bool}}

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
        "conductor_reason" => "Switch-state conductor paths are not assessed in this increment.",
        "invalid_switch_ids" => inventory.invalid_switches,
        "skipped_branch_ids" => inventory.skipped_ids)
    result = Dict{String,Any}("switch_counts" => counts, "assessment" => assessment)
    if isempty(all_switches)
        result["status"] = "inapplicable"
        assessment["reason"] = "No switch records."
        return result
    elseif !isempty(inventory.invalid_switches)
        result["status"] = "indeterminate"
        assessment["reason"] = "Every switch needs a Boolean open_switch and two distinct declared bus endpoints."
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
    result
end
