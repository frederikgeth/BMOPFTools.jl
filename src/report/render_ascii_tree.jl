# report/render_ascii_tree.jl
#
# ASCII tree renderer for BMOPF networks.
#
# Algorithm: BFS from the source bus builds a spanning tree; DFS renders it
# with box-drawing characters. Two compression modes handle large networks:
#
#   fold_chains  – consecutive single-child un-annotated buses are collapsed
#                  into a "⋮ (N buses)" stub, keeping the tree width narrow.
#   max_depth    – subtrees beyond this depth are replaced with a one-line
#                  "[+N buses, M loads]" summary.
#
# Multi-voltage split (split_by_level=true, the default):
# When the network has ≥ 2 level-crossing transformer edges in the spanning
# tree (e.g. an MV feeder with multiple LV subnetworks), the output is divided
# into sections: a root section showing the MV backbone with section pointers,
# followed by one independently-rendered section per distribution transformer.
# Single-feeder networks (one HV→LV transformer only) are rendered as a single
# tree to avoid a trivially 1-bus root section.

"""
    render_ascii_tree(net, io; max_buses, max_depth, fold_chains, legend_limit,
                               split_by_level)

Write an ASCII tree of the network graph to `io`.

**Node labels** – the source bus is tagged `SRC`; loads appear as `L1,L2,…`
and generators as `G1,G2,…` (numbered per section, mapped in the legend printed
after each section). Transformer and switch edges are annotated.

**Large-network handling** – when a section's bus count exceeds `max_buses`:
- `fold_chains=true` (default) collapses unbranched corridors with no attached
  loads or generators into `⋮ (N buses)` stubs.
- Subtrees deeper than `max_depth` are replaced by a `[+N buses, M loads]` line.

**Multi-voltage split** – when `split_by_level=true` (default) and the spanning
tree crosses ≥ 2 voltage level boundaries, the file is split into a root section
(MV backbone) and one LV section per distribution transformer.
"""
function render_ascii_tree(net::Dict{String,Any}, io::IO;
                            max_buses::Int       = 200,
                            max_depth::Int       = 8,
                            fold_chains::Bool    = true,
                            legend_limit::Int    = 50,
                            split_by_level::Bool = true)

    buses     = get(net, "bus",             Dict())
    lines     = get(net, "line",            Dict())
    switches  = get(net, "switch",          Dict())
    loads     = get(net, "load",            Dict())
    gens      = get(net, "generator",       Dict())
    sources   = get(net, "voltage_source",  Dict())
    xfmr_dict = get(net, "transformer",     Dict())

    n_buses = length(buses)

    # ── 1. Adjacency list ────────────────────────────────────────────────────

    adj = Dict{String, Vector{NTuple{5,Any}}}()
    for bid in keys(buses); adj[bid] = NTuple{5,Any}[] end

    function add_edge!(a, b, etype, eid, is_open, label)
        (haskey(adj, a) && haskey(adj, b)) || return
        push!(adj[a], (b, etype, eid, is_open, label))
        push!(adj[b], (a, etype, eid, is_open, label))
    end

    for (lid, l) in lines
        add_edge!(get(l,"bus_from",""), get(l,"bus_to",""), :line, lid, false, "")
    end
    for (sid, sw) in switches
        is_open = get(sw, "open_switch", false)
        add_edge!(get(sw,"bus_from",""), get(sw,"bus_to",""), :switch, sid, is_open, "")
    end
    for subtype in TRANSFORMER_SUBTYPES
        for (tid, tx) in get(xfmr_dict, subtype, Dict())
            vg    = _derive_vector_group(subtype, tx)
            vf    = get(tx, "v_nom_from", nothing)
            vt    = get(tx, "v_nom_to",   nothing)
            ratio = (vf !== nothing && vt !== nothing) ?
                    " $(round(Float64(vf)/1000, digits=1))kV/$(round(Int, Float64(vt)))V" : ""
            add_edge!(get(tx,"bus_from",""), get(tx,"bus_to",""),
                      :transformer, tid, false, "$(tid): $vg$ratio")
        end
    end

    # ── 2. Bus annotations ────────────────────────────────────────────────────
    source_buses = Set{String}(get(s,"bus","") for (_, s) in sources)

    bus_loads = Dict{String,Vector{String}}()
    bus_gens  = Dict{String,Vector{String}}()
    bus_invs  = Dict{String,Vector{String}}()
    for (lid, l) in loads
        push!(get!(bus_loads, get(l,"bus",""), String[]), lid)
    end
    for (gid, g) in gens
        push!(get!(bus_gens, get(g,"bus",""), String[]), gid)
    end
    for (vid, v) in get(net, "ibr", Dict())
        push!(get!(bus_invs, get(v,"bus",""), String[]), vid)
    end

    function is_annotated(bid)
        bid in source_buses ||
        !isempty(get(bus_loads, bid, String[])) ||
        !isempty(get(bus_gens,  bid, String[])) ||
        !isempty(get(bus_invs,  bid, String[]))
    end

    # ── 3. Identify level-crossing transformers ───────────────────────────────
    level_xfmr_tids = Set{String}()
    if split_by_level
        for subtype in TRANSFORMER_SUBTYPES
            for (tid, tx) in get(xfmr_dict, subtype, Dict())
                vf = get(tx, "v_nom_from", nothing)
                vt = get(tx, "v_nom_to",   nothing)
                (vf === nothing || vt === nothing) && continue
                vf_f, vt_f = Float64(vf), Float64(vt)
                abs(vf_f - vt_f) / max(vf_f, vt_f, 1.0) > 0.05 &&
                    push!(level_xfmr_tids, tid)
            end
        end
    end

    # ── 4. BFS spanning tree ──────────────────────────────────────────────────
    root = isempty(source_buses) ? first(sort(collect(keys(buses)))) :
                                   first(sort(collect(source_buses)))

    parent      = Dict{String,Union{String,Nothing}}(root => nothing)
    parent_edge = Dict{String,Union{NTuple{5,Any},Nothing}}(root => nothing)
    bfs_order   = String[]
    children    = Dict{String,Vector{String}}()

    visited = Set{String}([root])
    queue   = [root]
    while !isempty(queue)
        cur = popfirst!(queue)
        push!(bfs_order, cur)
        children[cur] = String[]
        for e in sort(adj[cur], by = e -> e[1])
            nbr = e[1]
            nbr in visited && continue
            push!(visited, nbr)
            parent[nbr]      = cur
            parent_edge[nbr] = e
            push!(children[cur], nbr)
            push!(queue, nbr)
        end
    end

    unreachable = [b for b in keys(buses) if !haskey(parent, b)]

    # ── 5. Identify section roots ─────────────────────────────────────────────
    # A section root is a bus reached via a level-crossing transformer edge.
    # Only activate split mode when ≥ 2 such roots exist; otherwise a single
    # head-end transformer would produce a trivially 1-bus root section.

    sections_ordered = Tuple{String,String,String}[]   # (bus_to, tid, edge_label)
    section_root_set = Set{String}()

    for bid in bfs_order
        pe = parent_edge[bid]
        pe === nothing && continue
        pe[2] == :transformer || continue
        pe[3] in level_xfmr_tids || continue
        push!(sections_ordered, (bid, pe[3], pe[5]))
        push!(section_root_set, bid)
    end

    do_split = length(sections_ordered) >= 2
    if !do_split
        empty!(section_root_set)   # treat as single-section render
    end

    section_idx_map = Dict(sroot => i
                           for (i, (sroot, _, _)) in enumerate(sections_ordered))

    # ── 6. Subtree statistics ─────────────────────────────────────────────────
    subtree_buses = Dict{String,Int}()
    subtree_loads = Dict{String,Int}()
    for bid in reverse(bfs_order)
        subtree_buses[bid] = 1 + sum(get(subtree_buses, c, 1)
                                     for c in get(children, bid, String[]); init=0)
        subtree_loads[bid] = length(get(bus_loads, bid, String[])) +
                             sum(subtree_loads[c] for c in get(children, bid, String[]); init=0)
    end

    n_root_buses = n_buses -
                   sum(get(subtree_buses, s, 0) for (s,_,_) in sections_ordered; init=0)

    # ── 7. Chain detection ────────────────────────────────────────────────────
    # Chains never cross transformer or switch edges, so section boundaries are
    # automatically respected (section roots are reached via :transformer edges).

    chain_skip = Dict{String,Int}()

    if fold_chains
        for bid in bfs_order
            kids = get(children, bid, String[])
            length(kids) == 1 || continue
            is_annotated(bid) && continue
            pe = parent_edge[bid]
            pe !== nothing && pe[2] != :line && continue
            n_folded = 0
            cur = bid
            while true
                kk = get(children, cur, String[])
                length(kk) != 1 && break
                child = kk[1]
                is_annotated(child) && break
                ce = parent_edge[child]
                ce !== nothing && ce[2] != :line && break
                n_folded += 1
                cur = child
            end
            n_folded > 0 && (chain_skip[bid] = n_folded)
        end
    end

    # ── 8. Formatting helpers ─────────────────────────────────────────────────
    function fmt_bus(bid, load_num, gen_num)
        tags = String[]
        bid in source_buses && push!(tags, "SRC")
        ls = [load_num[l] for l in get(bus_loads, bid, String[]) if haskey(load_num, l)]
        gs = [gen_num[g]  for g in get(bus_gens,  bid, String[]) if haskey(gen_num, g)]
        !isempty(ls) && push!(tags, join(sort(ls), ","))
        !isempty(gs) && push!(tags, join(sort(gs), ","))
        isempty(tags) ? bid : "$bid ($(join(tags, " ")))"
    end

    function fmt_edge(e::NTuple{5,Any})
        etype, is_open, label = e[2], e[4], e[5]
        etype == :transformer && return "[$(label)]── "
        etype == :switch       && return is_open ? "[SW:open]── " : "[SW]── "
        return ""
    end

    # ── 9. DFS renderer ──────────────────────────────────────────────────────
    function dfs(bid, prefix, is_last, depth, compact_mode, skip_set, load_num, gen_num)
        bid in skip_set && return

        edge   = parent_edge[bid]
        bchar  = is_last ? "└── " : "├── "
        elabel = edge !== nothing ? fmt_edge(edge) : ""

        # Split mode: section roots become pointer stubs
        if bid in section_root_set
            sec_idx = section_idx_map[bid]
            nb = get(subtree_buses, bid, 1)
            nl = get(subtree_loads, bid, 0)
            _, stid, _ = sections_ordered[sec_idx]
            println(io, "$(prefix)$(bchar)$(elabel)→ Section $sec_idx: $stid  ($nb buses, $nl loads)")
            return
        end

        # Depth-based subtree collapse
        if compact_mode && depth > max_depth && get(subtree_buses, bid, 1) > 1
            nb = subtree_buses[bid]; nl = subtree_loads[bid]
            println(io, "$(prefix)$(bchar)$(elabel)$(fmt_bus(bid, load_num, gen_num)) [+$(nb-1) buses, $nl loads]")
            return
        end

        # Chain fold
        n_fold = get(chain_skip, bid, 0)
        if compact_mode && n_fold > 0
            println(io, "$(prefix)$(bchar)$(elabel)$(fmt_bus(bid, load_num, gen_num))")
            cur = bid
            for _ in 1:n_fold
                child = get(children, cur, String[])[1]
                push!(skip_set, child)
                cur = child
            end
            child_prefix = prefix * (is_last ? "    " : "│   ")
            println(io, "$(child_prefix)⋮  ($n_fold buses)")
            chain_kids = get(children, cur, String[])
            for (i, ck) in enumerate(chain_kids)
                dfs(ck, child_prefix, i == length(chain_kids), depth + 1,
                    compact_mode, skip_set, load_num, gen_num)
            end
            return
        end

        println(io, "$(prefix)$(bchar)$(elabel)$(fmt_bus(bid, load_num, gen_num))")
        kids = get(children, bid, String[])
        for (i, child) in enumerate(kids)
            dfs(child, prefix * (is_last ? "    " : "│   "), i == length(kids),
                depth + 1, compact_mode, skip_set, load_num, gen_num)
        end
    end

    # ── 10. Legend printer ────────────────────────────────────────────────────
    function print_legend(lids, gids, load_num, gen_num)
        if !isempty(lids)
            println(io, "\nLoads ($(length(lids)) total):")
            shown = min(length(lids), legend_limit)
            for lid in lids[1:shown]
                l    = get(loads, lid, Dict())
                p_w  = sum(Float64.(get(l, "p_nom", Float64[])); init=0.0)
                p_kw = round(p_w / 1000, digits=2)
                cfg  = get(l, "configuration", "WYE")
                tm   = get(l, "terminal_map", [])
                println(io, "  $(load_num[lid]) = $(rpad(lid, 16)) $(lpad(p_kw, 6)) kW  $cfg  terminals: $(join(string.(tm),","))")
            end
            shown < length(lids) &&
                println(io, "  … and $(length(lids) - shown) more (pass legend_limit= to show all)")
        end
        if !isempty(gids)
            println(io, "\nGenerators ($(length(gids)) total):")
            for gid in gids
                g     = get(gens, gid, Dict())
                p_max = sum(Float64.(get(g, "p_max", Float64[])); init=0.0)
                p_kw  = round(p_max / 1000, digits=2)
                tm_g  = get(g, "terminal_map", [])
                tm_str = isempty(tm_g) ? "" : "  terminals: $(join(string.(tm_g), ","))"
                println(io, "  $(gen_num[gid]) = $(rpad(gid, 16)) max $(lpad(p_kw, 6)) kW$tm_str")
            end
        end
    end

    # ── 11. Section bus membership ────────────────────────────────────────────
    function collect_subtree(bid)
        result = Set{String}()
        q = [bid]
        while !isempty(q)
            cur = popfirst!(q)
            push!(result, cur)
            append!(q, get(children, cur, String[]))
        end
        result
    end

    sec_bus_sets = Dict{String,Set{String}}()
    if do_split
        for (sroot, _, _) in sections_ordered
            sec_bus_sets[sroot] = collect_subtree(sroot)
        end
    end
    all_lv_buses = isempty(sec_bus_sets) ? Set{String}() : union(values(sec_bus_sets)...)

    # ── 12. Root section ──────────────────────────────────────────────────────
    root_load_ids = sort([lid for (lid, l) in loads
                          if !(get(l, "bus", "") in all_lv_buses)])
    root_gen_ids  = sort([gid for (gid, g) in gens
                          if !(get(g, "bus", "") in all_lv_buses)])
    root_load_num = Dict(lid => "L$i" for (i, lid) in enumerate(root_load_ids))
    root_gen_num  = Dict(gid => "G$i" for (i, gid) in enumerate(root_gen_ids))

    compact_root = (do_split ? n_root_buses : n_buses) > max_buses

    if do_split
        println(io, "# MV backbone  ($n_root_buses buses,  $(length(sections_ordered)) LV sections)")
    elseif n_buses > max_buses
        println(io, "# Network graph  ($n_buses buses, compressed)")
    else
        println(io, "# Network graph  ($n_buses buses)")
    end
    println(io)

    skip_root = Set{String}()
    println(io, fmt_bus(root, root_load_num, root_gen_num))
    root_kids = get(children, root, String[])
    for (i, child) in enumerate(root_kids)
        dfs(child, "", i == length(root_kids), 1, compact_root, skip_root,
            root_load_num, root_gen_num)
    end

    if !isempty(unreachable)
        println(io, "\n# Disconnected buses ($(length(unreachable)) — not reachable from source):")
        for bid in sort(unreachable)[1:min(10, length(unreachable))]
            println(io, "  $(fmt_bus(bid, root_load_num, root_gen_num))")
        end
        length(unreachable) > 10 && println(io, "  … and $(length(unreachable)-10) more")
    end

    print_legend(root_load_ids, root_gen_ids, root_load_num, root_gen_num)

    # ── 13. LV sections ───────────────────────────────────────────────────────
    do_split && for (sec_idx, (sroot, stid, slabel)) in enumerate(sections_ordered)
        println(io, "\n" * "─"^60)
        sec_set = sec_bus_sets[sroot]
        n_sec   = length(sec_set)

        println(io, "# Section $sec_idx: $stid  ($slabel,  $n_sec buses)")
        println(io)

        sec_load_ids = sort([lid for (lid, l) in loads
                             if get(l, "bus", "") in sec_set])
        sec_gen_ids  = sort([gid for (gid, g) in gens
                             if get(g, "bus", "") in sec_set])
        sec_load_num = Dict(lid => "L$i" for (i, lid) in enumerate(sec_load_ids))
        sec_gen_num  = Dict(gid => "G$i" for (i, gid) in enumerate(sec_gen_ids))

        compact_sec = n_sec > max_buses
        skip_sec    = Set{String}()

        println(io, fmt_bus(sroot, sec_load_num, sec_gen_num))
        sec_kids = get(children, sroot, String[])
        for (i, child) in enumerate(sec_kids)
            dfs(child, "", i == length(sec_kids), 1, compact_sec, skip_sec,
                sec_load_num, sec_gen_num)
        end

        print_legend(sec_load_ids, sec_gen_ids, sec_load_num, sec_gen_num)
    end

    _render_dc_network!(net, io)
end

# Append a compact DC-network overlay: each converter station (the IBRs sharing a
# dc_bus) and the DC branches/groundings tying the dc_buses together. The DC side
# is an overlay on the AC spanning tree, so it is listed separately rather than
# embedded in it. `⏚` marks a grounded DC terminal.
function _render_dc_network!(net::Dict{String,Any}, io::IO)
    dc_buses = get(net, "dc_bus", Dict())
    (dc_buses isa Dict && !isempty(dc_buses)) || return

    # converters grouped by dc_bus
    conv_by_bus = Dict{String,Vector{String}}()
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict && haskey(inv, "dc_bus") || continue
        push!(get!(conv_by_bus, string(inv["dc_bus"]), String[]), id)
    end
    # perfectly/resistively grounded terminals per dc_bus
    gnd = Dict{String,Vector{String}}()
    for (_, g) in get(net, "dc_grounding", Dict())
        g isa Dict || continue
        b = get(g, "dc_bus", nothing); t = get(g, "terminal", nothing)
        (b isa AbstractString && t isa AbstractString) || continue
        push!(get!(gnd, b, String[]), string(t))
    end
    for (b, dcbus) in dc_buses
        dcbus isa Dict || continue
        for t in string.(get(dcbus, "perfectly_grounded_terminals", String[]))
            push!(get!(gnd, b, String[]), t)
        end
    end

    n_branch = length(get(net, "dc_branch", Dict()))
    n_station = count(>=(2), length.(values(conv_by_bus)))
    println(io, "\n" * "─"^60)
    println(io, "# DC network (MVDC/LVDC): $(length(dc_buses)) dc bus(es), " *
                "$n_branch dc line(s), $n_station converter station(s)")
    println(io)

    grounded(b, t) = t in get(gnd, b, String[])
    for b in sort(collect(keys(dc_buses)))
        dcbus = dc_buses[b]
        dcbus isa Dict || continue
        terms = string.(get(dcbus, "terminal_names", String[]))
        tlabel = join(String[grounded(b, t) ? "$(t)⏚" : t for t in terms], ",")
        vmin = Float64.(get(dcbus, "v_dc_min", Float64[]))
        vmax = Float64.(get(dcbus, "v_dc_max", Float64[]))
        vtxt = (!isempty(vmin) && !isempty(vmax)) ?
               "  v_dc $(minimum(vmin))…$(maximum(vmax)) V" : ""
        println(io, "$b  [$tlabel]$vtxt")
        convs = sort(get(conv_by_bus, b, String[]))
        for (i, cid) in enumerate(convs)
            inv = net["ibr"][cid]
            acbus = get(inv, "bus", "?")
            port  = join(string.(get(inv, "dc_terminal_map", String[])), ",")
            lead  = i == length(convs) ? "└─" : "├─"
            println(io, "   $lead converter $cid ↔ AC $acbus  [$port]")
        end
    end

    dc_branches = get(net, "dc_branch", Dict())
    for id in sort(collect(keys(dc_branches)))
        br = dc_branches[id]
        br isa Dict || continue
        bf = get(br, "dc_bus_from", "?"); bt = get(br, "dc_bus_to", "?")
        r  = Float64.(get(br, "r", Float64[]))
        rtxt = isempty(r) ? "" : "r=$(join(r, "/"))Ω"
        tmf = join(string.(get(br, "terminal_map_from", String[])), ",")
        tmt = join(string.(get(br, "terminal_map_to", String[])), ",")
        println(io, "$(bf)[$tmf] ──$(rtxt)──> $(bt)[$tmt]   ($id)")
    end
    println(io, "\n⏚ = grounded DC terminal")
end
