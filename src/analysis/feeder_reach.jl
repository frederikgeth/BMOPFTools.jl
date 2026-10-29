# Bus-graph distances over declared lengths. Ports do not establish energization.
_voltage_band(v::Real) = v >= 100000 ? "EHV" : v >= 35000 ? "HV" : v >= 1000 ? "MV" : "LV"
const _REACH_VOLTAGE_RTOL = 0.05
const _REACH_CYCLE_RTOL = 1e-9
_reach_close(a, b) = abs(a - b) <= _REACH_VOLTAGE_RTOL * max(abs(a), abs(b))

function _reach_graph(net, zones)
    zi = Dict(b => i for (i, z) in enumerate(zones) for b in z)
    adj = Dict(b => Tuple{String,Float64,String}[] for b in keys(zi))
    issues = [String[] for _ in zones]; regularized = [String[] for _ in zones]
    impedance_basis = [Dict(k => 0 for k in ("length_scaled", "absolute_section", "unresolved")) for _ in zones]
    linecodes = get(net, "linecode", Dict())
    function edge(a, b, w, id)
        if !haskey(zi, a) || !haskey(zi, b)
            for x in (a, b)
                haskey(zi, x) && push!(issues[zi[x]], "$id:invalid_endpoints")
            end
            return
        end
        push!(adj[a], (b, w, id)); push!(adj[b], (a, w, id))
    end
    for (id, l) in get(net, "line", Dict())
        l isa AbstractDict || continue
        a = get(l, "bus_from", nothing); b = get(l, "bus_to", nothing)
        touched = unique([zi[x] for x in (a, b) if haskey(zi, x)])
        w = get(l, "length", nothing)
        if !_profile_nonnegative(w) || !haskey(zi, a) || !haskey(zi, b)
            for i in touched; push!(issues[i], "line:$id"); end
            continue
        end
        # Declaration source only; this does not validate the electrical matrix.
        inline = haskey(l, "R_series_1_1") || haskey(l, "X_series_1_1")
        lc = get(l, "linecode", nothing)
        basis = inline && !haskey(l, "linecode") ? "absolute_section" :
            !inline && lc isa AbstractString && linecodes isa AbstractDict &&
                get(linecodes, lc, nothing) isa AbstractDict ? "length_scaled" : "unresolved"
        for i in touched; impedance_basis[i][basis] += 1; end
        meta = get(l, "meta", Dict()); meta isa AbstractDict || (meta = Dict())
        flag = get(meta, "electrical_length_regularized", false)
        for i in touched
            flag === true && push!(regularized[i], string(id))
            flag isa Bool || push!(issues[i], "line:$id:invalid_regularization_flag")
        end
        edge(a, b, Float64(w), "line:$id")
    end
    for (id, sw) in get(net, "switch", Dict())
        sw isa AbstractDict || continue
        a = get(sw, "bus_from", nothing); b = get(sw, "bus_to", nothing)
        state = get(sw, "open_switch", false)
        if !(state isa Bool)
            for x in (a, b); haskey(zi, x) && push!(issues[zi[x]], "switch:$id:invalid_state"); end
        elseif !state
            edge(a, b, 0.0, "switch:$id")
        end
    end
    for subtype in GALVANIC_CONTINUOUS_SUBTYPES
        for (id, xf) in get(get(net, "transformer", Dict()), subtype, Dict())
            edge(get(xf, "bus_from", nothing), get(xf, "bus_to", nothing), 0.0, "transformer:$subtype:$id")
        end
    end
    for es in values(adj); sort!(es); end
    (zi=zi, adj=adj, issues=sort!.(unique!.(issues)), regularized=sort!.(regularized), impedance_basis=impedance_basis)
end

# A binary heap retains the physical edge inventory without a SimpleGraph collapse.
function _reach_push!(heap, item)
    push!(heap, item); i = length(heap)
    while i > 1
        p = i ÷ 2
        heap[p] <= item && break
        heap[i] = heap[p]; i = p
    end
    heap[i] = item
end
function _reach_pop!(heap)
    item = first(heap); last = pop!(heap)
    if !isempty(heap)
        i = 1
        while 2i <= length(heap)
            j = 2i
            j < length(heap) && heap[j+1] < heap[j] && (j += 1)
            last <= heap[j] && break
            heap[i] = heap[j]; i = j
        end
        heap[i] = last
    end
    item
end
function _reach_distances(adj, zone, starts)
    dist = Dict{String,Float64}(); parent = Dict{String,Tuple{String,String}}()
    heap = Tuple{Float64,String}[]
    for b in sort!(unique(starts))
        dist[b] = 0.0; _reach_push!(heap, (0.0, b))
    end
    while !isempty(heap)
        d, b = _reach_pop!(heap)
        d == dist[b] || continue
        for (next, w, id) in adj[b]
            next in zone || continue
            nd = d + w
            if isfinite(nd) && nd < get(dist, next, Inf)
                dist[next] = nd; parent[next] = (b, id)
                _reach_push!(heap, (nd, next))
            end
        end
    end
    (dist=dist, parent=parent)
end
function _reach_path(tree, bus; limit=20)
    edges = String[]; at = bus; n = 0
    while haskey(tree.parent, at)
        at, id = tree.parent[at]; n += 1
        length(edges) < limit && push!(edges, id)
    end
    Dict{String,Any}("boundary_bus" => at, "farthest_bus" => bus,
        "branch_ids_from_farthest" => edges, "n_path_edges" => n, "path_truncated" => n > limit)
end

# Only explicit, mapped two-port nominal relations qualify the initial screen.
# Other ports remain visible, without interpreting winding 1 as a supply side.
function _reach_boundaries(net, zones, zi)
    ports = [Dict{String,Any}[] for _ in zones]
    links = [Tuple{Int,Float64}[] for _ in zones]
    roots = [Float64[] for _ in zones]
    uncertain = falses(length(zones))
    roles = try
        _terminal_roles(net)
    catch err
        err isa ArgumentError || rethrow()
        nothing
    end
    roles_valid = roles !== nothing && isempty(intersect(roles.phase, roles.neutral)) &&
        isempty(intersect(union(roles.phase, roles.neutral), roles.earth))
    for (id, source) in sort!(collect(get(net, "voltage_source", Dict())), by=first)
        b = get(source, "bus", nothing); haskey(zi, b) || continue
        vals = get(source, "v_magnitude", nothing)
        good = roles_valid && _profile_port_map(net, source) && vals isa AbstractVector && !isempty(vals) &&
            length(vals) == length(source["terminal_map"]) && all(t -> t in roles.phase, source["terminal_map"]) &&
            all(v -> _profile_finite(v) && v > 0, vals) &&
            _reach_close(minimum(vals), maximum(vals))
        v = good ? maximum(Float64.(vals)) : nothing
        good && push!(roots[zi[b]], v)
        uncertain[zi[b]] |= !good
        push!(ports[zi[b]], Dict{String,Any}("kind" => "voltage_source", "id" => id,
            "bus" => b, "winding" => nothing, "subtype" => nothing, "v_nom" => v,
            "qualification" => good ? "qualified_source_boundary" : "unresolved",
            "reason" => good ? nothing : "invalid_source_reference"))
    end
    for (subtype, sub) in sort!(collect(get(net, "transformer", Dict())), by=first)
        subtype in GALVANIC_CONTINUOUS_SUBTYPES && continue
        sub isa AbstractDict || continue
        for (id, xf) in sort!(collect(sub), by=first)
            xf isa AbstractDict || continue
            raw = if subtype == "n_winding"
                get(xf, "windings", [])
            else
                [Dict{String,Any}("bus" => get(xf, "bus_$s", nothing),
                    "terminal_map" => get(xf, "terminal_map_$s", nothing),
                    "v_nom" => get(xf, "v_nom_$s", nothing)) for s in ("from", "to")]
            end
            raw isa AbstractVector || continue
            supported = roles_valid && length(raw) == 2 && subtype in ("n_winding", "single_phase", "wye_delta", "delta_wye") &&
                !any(haskey(xf, f) for f in ("tap_min", "tap_max", "control", "control_mode", "control_profile"))
            subtype == "n_winding" && any(haskey(xf, f) || any(w isa AbstractDict && haskey(w,f) for w in raw) for f in _PROFILE_NW_TAP_KEYS) && (supported = false)
            if supported && subtype in ("wye_delta", "delta_wye")
                wy = subtype == "wye_delta" ? 1 : 2; de = 3-wy
                wt = get(raw[wy], "terminal_map", []); dt = get(raw[de], "terminal_map", [])
                supported = wt isa AbstractVector && dt isa AbstractVector &&
                    count(t -> t in roles.neutral, wt) == 1 && length(dt) >= 2 &&
                    count(t -> t in roles.phase, wt) == length(dt) &&
                    all(t -> t in roles.phase, dt) && all(t -> t in union(roles.phase,roles.neutral), wt)
            end
            vnom = Float64[]; phase_counts = Int[]
            for w in raw
                if !_profile_port_map(net, w) || !_profile_finite(get(w, "v_nom", nothing)) || w["v_nom"] <= 0
                    supported = false; push!(vnom, NaN); continue
                end
                v = Float64(w["v_nom"])
                if subtype == "n_winding"
                    cfg = uppercase(string(get(w, "configuration", "WYE")))
                    tm = w["terminal_map"]; neutral = roles_valid ? roles.neutral : Set{String}()
                    phases = roles_valid ? count(t -> t in roles.phase, tm) : 0
                    push!(phase_counts, phases)
                    roles_valid && phases > 0 && all(t -> t in union(roles.phase, neutral), tm) || (supported = false)
                    if cfg == "DELTA" && phases == 3 && length(tm) == 3
                        v /= sqrt(3.0)
                    elseif cfg != "WYE" || count(t -> t in neutral, tm) != 1
                        supported = false
                    end
                elseif subtype == "single_phase"
                    tm = w["terminal_map"]
                    roles_valid && push!(phase_counts, count(t -> t in roles.phase, tm))
                    roles_valid && count(t -> t in roles.neutral, tm) == 1 &&
                        any(t -> t in roles.phase, tm) && all(t -> t in union(roles.phase,roles.neutral), tm) || (supported = false)
                end
                push!(vnom, v)
            end
            subtype in ("n_winding", "single_phase") && length(unique(phase_counts)) != 1 && (supported = false)
            tap = get(xf, "tap", 1.0)
            # Non-unity tap semantics vary by subtype; do not guess a voltage base.
            supported &= _profile_finite(tap) && tap == 1.0
            ids = [w isa AbstractDict ? get(zi, get(w, "bus", nothing), 0) : 0 for w in raw]
            supported &= length(ids) == 2 && all(>(0), ids) && ids[1] != ids[2]
            if supported
                ratio = vnom[2] / vnom[1]
                supported = isfinite(ratio) && ratio > 0 && isfinite(1/ratio)
            end
            if supported
                ratio = vnom[2] / vnom[1]
                push!(links[ids[1]], (ids[2], ratio)); push!(links[ids[2]], (ids[1], 1/ratio))
            end
            for (k, w) in enumerate(raw)
                ids[k] == 0 && continue
                !supported && (uncertain[ids[k]] = true)
                push!(ports[ids[k]], Dict{String,Any}("kind" => "transformer", "id" => id,
                    "subtype" => subtype, "winding" => k, "bus" => w["bus"],
                    "terminal_map" => get(w, "terminal_map", nothing),
                    "v_nom" => isfinite(vnom[k]) ? vnom[k] : nothing,
                    "other_zone" => supported ? ids[3-k] : nothing,
                    "other_v_nom" => supported ? vnom[3-k] : nothing,
                    "qualification" => supported ? "boundary_port" : "unresolved",
                    "reason" => supported ? "source_path_unassessed" : "unsupported_port_relation"))
            end
        end
    end
    for i in eachindex(zones)
        # Remove this zone before tracing source-side paths: a candidate must not
        # bootstrap its own supply through another port in the assessed zone.
        # Each source-side component has a relative nominal-voltage potential.
        # Compare every source reference through its min/max envelope, never a
        # first-arriving source value. Cycle ratios must agree within roundoff.
        assigned = Dict{Int,Tuple{Float64,Float64}}(); bad = Set{Int}(); seen = Set{Int}()
        for seed in eachindex(zones)
            (seed == i || seed in seen || (isempty(roots[seed]) && !uncertain[seed])) && continue
            weights = Dict(seed => 1.0); component = [seed]; conflict = false
            for j in component
                push!(seen, j)
                for (next, ratio) in links[j]
                    next == i && continue
                    w = weights[j] * ratio
                    if !isfinite(w) || w <= 0
                        conflict = true
                    elseif haskey(weights, next)
                        abs(weights[next]-w) <= _REACH_CYCLE_RTOL*max(weights[next],w) || (conflict = true)
                    else
                        weights[next] = w; push!(component, next)
                    end
                end
            end
            references = [v/weights[j] for j in component for v in roots[j]]
            conflict |= any(j -> uncertain[j], component)
            if isempty(references)
                # Unrooted does not mean known to contain no source: an invalid
                # source/unsupported relation can hide an additional boundary.
                conflict && union!(bad, component)
                continue
            end
            lo, hi = extrema(references)
            conflict |= !isfinite(lo) || lo <= 0 || !isfinite(hi) || !_reach_close(lo, hi)
            for j in component
                low, high = lo*weights[j], hi*weights[j]
                if !isfinite(low) || low <= 0 || !isfinite(high)
                    conflict = true
                end
                assigned[j] = (low, high)
                # Absolute port nominals are declarations too; compatible ratios
                # do not make an inconsistent absolute voltage base disappear.
                for p in ports[j]
                    if p["kind"] == "transformer" && get(p, "other_zone", nothing) !== nothing
                        (_reach_close(low, p["v_nom"]) && _reach_close(high, p["v_nom"])) || (conflict = true)
                    end
                end
            end
            conflict && union!(bad, component)
        end
        for p in ports[i]
            p["kind"] == "transformer" && p["qualification"] != "unresolved" || continue
            j = p["other_zone"]
            if j in bad
                p["qualification"] = "unresolved"; p["reason"] = "conflicting_or_incomplete_source_side"
            elseif haskey(assigned, j)
                if all(v -> _reach_close(v, p["other_v_nom"]), assigned[j])
                    p["qualification"] = "qualified_source_connected_boundary"
                    p["reason"] = nothing
                    p["source_side_voltage_range"] = collect(assigned[j])
                else
                    p["qualification"] = "unresolved"; p["reason"] = "source_side_voltage_mismatch"
                end
            else
                p["reason"] = "no_independent_voltage_source_path"
            end
        end
    end
    for ps in ports, p in ps
        j = get(p, "other_zone", nothing)
        j isa Int && (p["other_zone"] = minimum(zones[j]))
        p["energization"] = "unassessed"
        p["supply_direction"] = "unassessed"
        # Which side of this zone the port sits on, from the source search only:
        # a source beyond the port makes it a possible supply entry; none makes it
        # a downstream (load-side) port. Not an energization or flow claim.
        if p["kind"] == "transformer"
            p["port_role"] = p["qualification"] == "qualified_source_connected_boundary" ? "source_beyond_port" :
                get(p, "reason", nothing) == "no_independent_voltage_source_path" ? "no_source_beyond_port" : "unresolved"
        end
    end
    ports
end

"""Declared-length anchor extent and qualified nearest-boundary distance.
Legacy `reach_m` remains anchor extent; threshold comparisons name their metric.
"""
function _feeder_length_check(net::Dict{String,Any}, zones::Vector{Set{String}}, findings::Vector{Finding}, config::Dict)
    cfg = _feeder_length_cfg(config)
    zones = sort(zones; by=minimum) # stable component seeds without mutating the caller
    graph = _reach_graph(net, zones); ports = _reach_boundaries(net, zones, graph.zi)
    summary = Dict{String,Any}[]
    for i in sort!(collect(eachindex(zones)), by=i -> minimum(zones[i]))
        zone = zones[i]; ps = ports[i]
        sources = sort!([p["bus"] for p in ps if p["kind"] == "voltage_source"])
        anchor = isempty(sources) ? minimum(zone) : first(sources)
        qualified = filter(p -> startswith(p["qualification"], "qualified_"), ps)
        starts = sort!(unique([p["bus"] for p in qualified]))
        voltages = [p["v_nom"] for p in qualified]
        consistent = !isempty(voltages) && all(v -> _reach_close(v, minimum(voltages)), voltages)
        unresolved = any(p -> p["qualification"] == "unresolved", ps)
        lengths_valid = isempty(graph.issues[i])
        atree = _reach_distances(graph.adj, zone, [anchor])
        tree = _reach_distances(graph.adj, zone, starts)
        complete = length(tree.dist) == length(zone)
        status, reason = !lengths_valid ? ("indeterminate", "invalid_or_missing_length_or_switch") :
            unresolved ? ("indeterminate", "unresolved_boundary") : isempty(starts) ? ("indeterminate", "no_qualified_boundary") :
            !consistent ? ("indeterminate", "conflicting_boundary_voltages") : !complete ? ("indeterminate", "unreachable_buses_or_distance_overflow") :
            ("assessed", nothing)
        extent = lengths_valid && length(atree.dist) == length(zone) ? maximum(values(atree.dist)) : nothing
        reach = status == "assessed" ? maximum(values(tree.dist)) : nothing
        v = consistent ? minimum(voltages) : nothing
        band = v === nothing ? nothing : _voltage_band(v)
        entry = Dict{String,Any}("zone_anchor" => anchor, "n_buses" => length(zone),
            "n_loads" => count(l -> get(l, "bus", nothing) in zone, values(get(net, "load", Dict()))),
            "band" => band, "v_nom" => v, "reach_m" => extent, "anchor_extent_m" => extent,
            "metric_version" => "1", "metric" => "max_shortest_declared_length_to_qualified_boundary",
            "boundary_reach_m" => reach, "status" => status, "reason" => reason,
            "boundaries" => ps, "n_qualified_boundary_buses" => length(starts),
            "n_reachable_buses" => length(tree.dist), "n_unreachable_buses" => length(zone)-length(tree.dist),
            "invalid_branches" => graph.issues[i], "regularized_lines" => graph.regularized[i],
            "length_basis" => "declared_electrical_length_m", "supply_allocation" => "unassessed",
            "energization" => "unassessed", "voltage_rtol" => _REACH_VOLTAGE_RTOL,
            "cycle_ratio_rtol" => _REACH_CYCLE_RTOL,
            "threshold_status" => "unassessed", "threshold_reason" => reason)
        if reach !== nothing
            far = first(sort!([b for (b, d) in tree.dist if d == reach]))
            entry["path_witness"] = _reach_path(tree, far)
        end
        xfports = filter(p -> p["kind"] == "transformer", ps)
        entry["n_incident_transformers"] = length(unique((p["subtype"], p["id"]) for p in xfports))
        entry["n_incident_windings"] = length(xfports)
        # A bounded connecting path gives context without asserting safe paralleling.
        entry["n_ports_by_role"] = Dict(r => count(p -> p["port_role"] == r, xfports)
            for r in ("source_beyond_port", "no_source_beyond_port", "unresolved"))
        if entry["n_incident_transformers"] > 1
            firstbus = first(sort!([p["bus"] for p in xfports]))
            ptree = _reach_distances(graph.adj, zone, [firstbus])
            targets = sort!(unique([p["bus"] for p in xfports if p["bus"] != firstbus]))
            entry["port_path_witnesses"] = [_reach_path(ptree, b) for b in targets[1:min(end, 5)] if haskey(ptree.dist, b)]
        end
        push!(summary, entry)
        bandcfg = get(cfg, something(band, ""), Dict())
        policy = length(starts) <= 1 || !(bandcfg isa AbstractDict) ? bandcfg : get(bandcfg, "multi_boundary", Dict())
        status == "assessed" || continue
        if !isempty(graph.regularized[i])
            entry["threshold_reason"] = "regularized_electrical_lengths"
            continue
        elseif policy isa AbstractDict && isempty(policy)
            entry["threshold_reason"] = "no_metric_specific_thresholds"
            continue
        end
        short = policy isa AbstractDict ? get(policy, "reach_short_m", 0.0) : nothing
        long = policy isa AbstractDict ? get(policy, "reach_long_m", 0.0) : nothing
        if !_profile_nonnegative(short) || !_profile_nonnegative(long) || (short > 0 && long > 0 && short > long)
            entry["threshold_status"] = "indeterminate"
            entry["threshold_reason"] = "invalid_threshold_policy"
            continue
        elseif short == long == 0
            entry["threshold_status"] = "skipped"
            entry["threshold_reason"] = "thresholds_disabled"
            continue
        end
        entry["threshold_status"] = "assessed"; entry["threshold_reason"] = nothing
        kind = long > 0 && reach > long ? "long" : short > 0 && reach < short ? "short" : nothing
        if kind !== nothing && length(zone) > 1
            detail = Dict{String,Any}("zone_anchor" => anchor, "band" => band, "v_nom" => v,
                "reach_m" => extent, "boundary_reach_m" => reach, "metric" => entry["metric"],
                "threshold_m" => kind == "long" ? long : short,
                "n_qualified_boundary_buses" => length(starts), "supply_allocation" => "unassessed")
            code = kind == "long" ? "I.OPS.FEEDER_LONG" : "I.OPS.FEEDER_SHORT"
            observations = Dict{String,Any}("boundary_reach_m" => reach, "threshold_m" => detail["threshold_m"],
                "band" => band, "anchor_extent_m" => extent, "path_witness" => get(entry, "path_witness", nothing),
                "impedance_basis_counts" => copy(graph.impedance_basis[i]))
            detail["interpretation"] = _finding_interpretation(code, observations)
            hint = kind == "long" ?
                "Either a genuinely long feeder or metre values interpreted as kilometres upstream / a duplicated " *
                "km-to-m conversion." :
                "Either a stub, service drop or substation interconnect, or a unit slip / the OpenDSS default " *
                "`length=1` (e.g. kilometre values stored as metres)."
            counts = graph.impedance_basis[i]
            electrical = counts["absolute_section"] > 0 && counts["length_scaled"] == 0 && counts["unresolved"] == 0 ?
                "These lines use inline absolute section impedances: changing length changes this distance, not those matrices." :
                "Length errors scale per-length linecode impedances and can distort voltages and losses; " *
                "inline absolute matrices stay unchanged."
            push!(findings, Finding(INFO, code, :operational, :network, nothing,
                "Zone '$anchor': the farthest bus is $(round(reach; digits=1)) m (declared line length) from the " *
                "nearest supply boundary, $kind for the $band screen ($(detail["threshold_m"]) m). $hint $electrical " *
                "Spot-check a few lengths and linecode units.", detail))
        end
    end
    summary
end

# Kept as an internal compatibility wrapper; invalid/incomplete lengths return nothing.
function _zone_electrical_reach(net::Dict{String,Any}, zone::Set{String}, anchor::String)
    graph = _reach_graph(net, [zone])
    isempty(graph.issues[1]) || return nothing
    tree = _reach_distances(graph.adj, zone, [anchor])
    length(tree.dist) == length(zone) ? maximum(values(tree.dist)) : nothing
end
