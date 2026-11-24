# Package-local review candidates, not electrical-equivalence or repair claims.
_spatial_pair(a, b) = isless(b, a) ? (b, a) : (a, b)
_spatial_candidate_check(scope) = Dict{String,Any}(
    "status" => "assessed", "reason" => "completed", "scope" => scope,
    "counts_complete" => true, "n_candidates" => 0, "n_candidates_observed" => 0,
    "witnesses" => Dict{String,Any}[])
function _spatial_candidate!(check, code, evidence, limit)
    check["n_candidates_observed"] += 1
    check["counts_complete"] && (check["n_candidates"] = check["n_candidates_observed"])
    if length(check["witnesses"]) < limit || _spatial_review_room(check)
        row = merge(Dict{String,Any}("code" => code), evidence)
        length(check["witnesses"]) < limit && push!(check["witnesses"], row)
        _spatial_review_room(check) && push!(check["_review_candidates"], row)
    end
end
function _spatial_incomplete!(check, reason; status="indeterminate")
    merge!(check, Dict("status" => status, "reason" => reason,
        "counts_complete" => false, "n_candidates" => nothing))
end

function _spatial_topology(net, levels, limit)
    buses = get(net, "bus", Dict())
    ids = sort!(string.(collect(keys(buses))))
    index = Dict(id => i for (i, id) in enumerate(ids))
    certain = collect(eachindex(ids)); possible = copy(certain)
    function root(p, i)
        while p[i] != i
            p[i] = p[p[i]]
            i = p[i]
        end
        i
    end
    function join!(p, a, b)
        i, j = root(p, index[a]), root(p, index[b])
        p[max(i, j)] = min(i, j)
    end
    components = Dict{String,Any}[]
    incidence = Dict(id => Int[] for id in ids)
    line_adj = Dict(id => Tuple{String,Int}[] for id in ids)
    invalid = 0
    function record!(kind, id, object, ports)
        object isa AbstractDict || (invalid += 1; return)
        bs = unique([get(p, "bus", nothing) for p in ports])
        if length(bs) < 2 || !all(b -> b isa AbstractString && haskey(index, b), bs)
            invalid += 1
            return
        end
        state = kind == "switch" ? get(object, "open_switch", nothing) : nothing
        ref = Dict{String,Any}("kind" => kind, "component_id" => string(id), "ports" => ports,
            "open_switch" => state isa Bool ? state : nothing,
            "linecode" => get(object, "linecode", nothing))
        push!(components, ref); k = length(components)
        for b in bs
            push!(incidence[b], k)
        end
        for b in bs[2:end]
            (kind != "switch" || state === false) && join!(certain, bs[1], b)
            (kind != "switch" || state !== true) && join!(possible, bs[1], b)
        end
        if kind == "line"
            a, b = bs
            push!(line_adj[a], (b, k)); push!(line_adj[b], (a, k))
        end
    end
    for kind in ("line", "switch")
        for (id, obj) in sort!(collect(get(net, kind, Dict())), by=first)
            ports = obj isa AbstractDict ? [Dict{String,Any}("bus" => get(obj, "bus_$s", nothing),
                "terminal_map" => get(obj, "terminal_map_$s", nothing)) for s in ("from", "to")] : []
            record!(kind, id, obj, ports)
        end
    end
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa AbstractDict || continue
        for (id, obj) in sort!(collect(sub), by=first)
            bs = _spatial_transformer_buses(obj, subtype)
            ports = if obj isa AbstractDict && subtype in WINDING_LIST_SUBTYPES
                [Dict{String,Any}("bus" => bs[i], "winding" => i,
                    "terminal_map" => w isa AbstractDict ? get(w, "terminal_map", nothing) : nothing)
                 for (i, w) in enumerate(get(obj, "windings", []) isa AbstractVector ? obj["windings"] : [])]
            elseif obj isa AbstractDict
                [Dict{String,Any}("bus" => bs[i], "terminal_map" => get(obj, "terminal_map_$s", nothing))
                 for (i, s) in enumerate(("from", "to"))]
            else
                []
            end
            record!("transformer:$subtype", id, obj, ports)
        end
    end
    certain_id = Dict(b => ids[root(certain, index[b])] for b in ids)
    possible_id = Dict(b => ids[root(possible, index[b])] for b in ids)
    attachments = Dict(id => Dict{String,Int}() for id in ids)
    for kind in ("load", "shunt", "capacitor", "voltage_source", "generator", "solar", "storage")
        for obj in values(get(net, kind, Dict()))
            obj isa AbstractDict || continue
            b = get(obj, "bus", nothing)
            haskey(attachments, b) || continue
            attachments[b][kind] = get(attachments[b], kind, 0) + 1
        end
    end
    function bus_context(b)
        incident = incidence[b]
        Dict{String,Any}("bus_id" => b, "voltage_tier" => get(levels, b, "unassigned"),
            "terminal_names" => buses[b] isa AbstractDict ? get(buses[b], "terminal_names", nothing) : nothing,
            "certain_component" => certain_id[b], "possible_component" => possible_id[b],
            "n_incident_branches" => length(incident), "attachments" => attachments[b],
            "incident_branches" => [components[i] for i in Iterators.take(incident, limit)],
            "incident_branches_truncated" => length(incident) > limit)
    end
    (components=components, incidence=incidence, incidence_sets=Dict(b => Set(v) for (b,v) in incidence), line_adj=line_adj,
     certain=certain_id, possible=possible_id, invalid=invalid, bus_context=bus_context, levels=levels)
end

function _spatial_nearby_callback(check, topology, coordinates, levels, budget, limit)
    checked = Ref(0); exhausted = Ref(false)
    check["component_relation_counts_observed"] = Dict{String,Int}()
    check["voltage_tier_relation_counts_observed"] = Dict{String,Int}()
    check["n_endpoint_like_pairs_observed"] = 0
    function observe(as, bs, distance)
        exhausted[] && return
        for (i, a) in enumerate(as), (j, b) in enumerate(bs)
            as === bs && j <= i && continue
            if checked[] >= budget
                exhausted[] = true
                return
            end
            checked[] += 1
            # Direct declarations explain co-location (including open switches).
            isdisjoint(topology.incidence_sets[a], topology.incidence_sets[b]) || continue
            connection = topology.certain[a] == topology.certain[b] ? "same_bus_component" :
                topology.possible[a] == topology.possible[b] ? "unknown_switch_state" :
                topology.invalid > 0 ? "indeterminate_graph" : "separate_bus_components"
            ta, tb = get(levels, a, "unassigned"), get(levels, b, "unassigned")
            tiers = "unassigned" in (ta, tb) ? "unknown" : ta == tb ? "same" : "different"
            endpoint_like = min(length(topology.incidence[a]), length(topology.incidence[b])) <= 1
            check["n_endpoint_like_pairs_observed"] += endpoint_like
            for (key, label) in (("component_relation_counts_observed", connection), ("voltage_tier_relation_counts_observed", tiers))
                counts = check[key]
                counts[label] = get(counts, label, 0) + 1
            end
            if length(check["witnesses"]) >= limit && !_spatial_review_room(check)
                check["n_candidates_observed"] += 1
                check["counts_complete"] && (check["n_candidates"] = check["n_candidates_observed"])
                continue
            end
            evidence = Dict{String,Any}("buses" => [topology.bus_context(a), topology.bus_context(b)],
                "distance_m" => distance, "component_relation" => connection,
                "voltage_tier_relation" => tiers,
                "endpoint_like" => endpoint_like,
                "coordinate_evidence" => [coordinates.evidence[a], coordinates.evidence[b]])
            _spatial_candidate!(check, "S.NEARBY_WITHOUT_DIRECT_BRANCH", evidence, limit)
        end
    end
    (observe=observe, checked=checked, exhausted=exhausted)
end

function _spatial_series_candidates!(check, topology, coordinates, frame, budget, hops, tolerance, limit)
    checked = 0; eligible = 0; missing = 0
    check["n_eligible_direct_lines"] = 0
    check["n_lines_with_unavailable_distance"] = 0
    for (direct_index, direct) in enumerate(topology.components)
        direct["kind"] == "line" || continue
        a, b = [p["bus"] for p in direct["ports"]]
        if !all(id -> haskey(coordinates.points, id), (a, b))
            missing += 1
            check["n_lines_with_unavailable_distance"] = missing
            continue
        end
        chord = _coordinate_distance(coordinates.points[a], coordinates.points[b], frame.kind)
        if chord === nothing
            missing += 1
            check["n_lines_with_unavailable_distance"] = missing
            continue
        end
        chord == 0 && continue
        eligible += 1
        check["n_eligible_direct_lines"] = eligible
        for (next, edge) in topology.line_adj[a]
            edge == direct_index && continue
            path = [a, next]; edges = [edge]
            current = next
            while true
                if checked >= budget
                    check["path_steps_checked"] = checked
                    _spatial_incomplete!(check, "path_budget_exhausted")
                    return
                end
                checked += 1
                current == b && break
                length(edges) >= hops && break
                length(topology.incidence[current]) == 2 || break
                choices = filter(x -> x[2] != last(edges), topology.line_adj[current])
                length(choices) == 1 || break
                following, next_edge = only(choices)
                (next_edge == direct_index || following in path) && break
                push!(edges, next_edge); push!(path, following)
                current = following
            end
            (current == b && length(edges) >= 2) || continue
            all(id -> haskey(coordinates.points, id), path) || continue
            distances = [_coordinate_distance(coordinates.points[path[i-1]], coordinates.points[path[i]], frame.kind)
                         for i in 2:length(path)]
            any(isnothing, distances) && continue
            path_length = sum(distances)
            isfinite(path_length) && path_length <= chord + max(tolerance, 0.1 * chord) || continue
            _spatial_candidate!(check, "S.DIRECT_ALONGSIDE_SERIES_PATH", Dict{String,Any}(
                "direct_branch" => direct, "series_branches" => topology.components[edges],
                "path_buses" => [topology.bus_context(id) for id in path],
                "endpoint_distance_m" => chord, "path_chord_sum_m" => path_length,
                "detour_ratio" => path_length / chord,
                "geometry_basis" => "bus_endpoint_chords_only"), limit)
        end
    end
    check["path_steps_checked"] = checked
    eligible == 0 && missing > 0 && _spatial_incomplete!(check, "no_comparable_line_endpoints")
end

function _spatial_branch_spans!(check, topology, coordinates, frame, threshold, budget, limit)
    checked = 0; missing = 0; assessed = 0
    check["n_assessed_components"] = 0
    check["n_components_with_unavailable_distance"] = 0
    for component in topology.components
        bs = unique([p["bus"] for p in component["ports"]])
        if !all(b -> haskey(coordinates.points, b), bs)
            missing += 1
            check["n_components_with_unavailable_distance"] = missing
            continue
        end
        longest = 0.0; pair = nothing; unavailable = false
        for i in eachindex(bs), j in 1:i-1
            if checked >= budget
                check["distance_pairs_checked"] = checked
                _spatial_incomplete!(check, "span_budget_exhausted")
                return
            end
            checked += 1
            d = _coordinate_distance(coordinates.points[bs[i]], coordinates.points[bs[j]], frame.kind)
            d === nothing && (unavailable = true; continue)
            if d > longest
                longest = d; pair = [bs[j], bs[i]]
            end
        end
        if unavailable
            missing += 1
            continue
        end
        assessed += 1
        check["n_assessed_components"] = assessed
        longest > threshold || continue
        _spatial_candidate!(check, "S.LONG_BRANCH_SPAN", Dict{String,Any}(
            "branch" => component, "farthest_buses" => pair, "span_m" => longest,
            "threshold_m" => threshold), limit)
    end
    check["distance_pairs_checked"] = checked
    check["n_components_with_unavailable_distance"] = missing
    assessed == 0 && missing > 0 && _spatial_incomplete!(check, "no_comparable_branch_coordinates")
end

function _spatial_discrepancies(net, coordinates, frame, levels, config)
    options = get(config, "spatial", Dict())
    options_valid = options isa AbstractDict
    options = options_valid ? options : Dict()
    enabled = get(options, "discrepancy_enabled", true)
    budget = get(options, "max_topology_pairs", 100_000)
    limit = get(options, "witness_limit", 20)
    hops = get(options, "max_series_hops", 8)
    tolerance = _spatial_length(get(options, "route_endpoint_tolerance_m", 5.0))
    span = _spatial_length(get(options, "long_span_threshold_m", 10_000.0))
    validint(x) = x isa Integer && !(x isa Bool) && 1 <= x <= typemax(Int)
    valid = options_valid && enabled isa Bool && validint(budget) && validint(limit) && validint(hops) &&
        2 <= hops <= 64 && tolerance !== nothing && tolerance > 0 && span !== nothing && span > 0
    checks = Dict{String,Any}(
        "nearby_topology" => _spatial_candidate_check("Metric-eligible bus pairs within the proximity radius, including zero distance, without any direct branch declaration."),
        "series_paths" => _spatial_candidate_check("Line-only paths of 2 to max_series_hops edges with degree-two interiors and endpoint-chord detour at most max(configured route endpoint tolerance, 10 percent)."),
        "branch_spans" => _spatial_candidate_check("All-port metric spans of lines, switches and supported transformer types above the configured absolute threshold."),
        "route_endpoints" => _spatial_candidate_check("Valid WGS84 route endpoints compared with metric-eligible WGS84 buses, orientation independent; nearby alternatives are unassigned candidates."),
        "route_overlaps" => _spatial_candidate_check("Exactly equal nonzero WGS84 vertex-to-vertex segments, allowing reversal; partial collinear overlap and crossings are unassessed."),
        "source_intervals" => _spatial_candidate_check("Exact repeated string IDs in meta.source_interval or meta.backbone_extension.source_interval, grouped separately by namespace."),
        "route_defects" => _spatial_candidate_check("Malformed route geometry, zero or retraced WGS84 segments, and segment lengths above the configured span threshold."))
    report = Dict{String,Any}("checks" => checks,
        "caution" => "Candidates describe geometry and declared bus-level topology, not conductor continuity, duplicate circuits, intended connections or safe repairs. Open switches and transformer isolation may be intentional.",
        "unassessed" => ["electrical_equivalence", "automatic_repair", "tolerant_partial_route_overlap", "arbitrary_route_crossings"])
    review_options = _spatial_review_options(config)
    for check in values(checks)
        check["_review_candidates"] = Dict{String,Any}[]
        check["_review_limit"] = review_options.valid && review_options.enabled ? review_options.limit : 0
    end
    if !valid || !enabled
        for check in values(checks)
            _spatial_incomplete!(check, valid ? "disabled" : "invalid_configuration";
                status=valid ? "inapplicable" : "indeterminate")
        end
        return (proximity=_spatial_proximity(net, coordinates, frame, levels, config), report=report)
    end
    topology = _spatial_topology(net, levels, limit)
    report["n_invalid_branch_declarations"] = topology.invalid
    report["max_topology_pairs"] = budget
    report["max_series_hops"] = hops
    report["route_endpoint_tolerance_m"] = tolerance
    report["long_span_threshold_m"] = span
    callback = _spatial_nearby_callback(checks["nearby_topology"], topology, coordinates, levels, budget, limit)
    proximity = _spatial_proximity(net, coordinates, frame, levels, config; observe=callback.observe)
    nearby = checks["nearby_topology"]
    nearby["bus_pairs_checked"] = callback.checked[]
    nearby["radius_m"] = proximity["radius_m"]
    if callback.exhausted[] || !proximity["counts_complete"]
        _spatial_incomplete!(nearby, callback.exhausted[] ? "bus_pair_budget_exhausted" : proximity["reason"];
            status=proximity["status"] == "inapplicable" ? "inapplicable" : "indeterminate")
    end
    if isempty(coordinates.points)
        for key in ("series_paths", "branch_spans")
            _spatial_incomplete!(checks[key], "no_eligible_coordinates";
                status=frame.status == "declared_other" ? "inapplicable" : "indeterminate")
        end
    else
        _spatial_series_candidates!(checks["series_paths"], topology, coordinates, frame, budget, hops, tolerance, limit)
        _spatial_branch_spans!(checks["branch_spans"], topology, coordinates, frame, span, budget, limit)
    end
    _spatial_route_candidates!(checks, net, topology, coordinates, frame, budget, tolerance, span, limit)
    (proximity=proximity, report=report)
end
