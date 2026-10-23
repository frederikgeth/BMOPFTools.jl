# Exact shared segments and explicit source identities are evidence of shared
# representation, never proof that two electrical circuits are duplicates.
function _spatial_line_group(net, ids, limit)
    lines = get(net, "line", Dict())
    pairs = Set{Any}(); maps = Any[]; rows = Dict{String,Any}[]
    for id in ids
        line = lines[id]
        a, b = get(line, "bus_from", nothing), get(line, "bus_to", nothing)
        valid = a isa AbstractString && b isa AbstractString
        pair = valid ? _spatial_pair(a, b) : nothing
        push!(pairs, pair)
        from_map, to_map = get(line, "terminal_map_from", nothing), get(line, "terminal_map_to", nothing)
        map_valid = valid && all(m -> m isa AbstractVector && !isempty(m) && all(t -> t isa AbstractString, m), (from_map, to_map))
        push!(maps, map_valid ? (a == first(pair) ? (from_map, to_map) : (to_map, from_map)) : nothing)
        length(rows) >= limit && continue
        meta = get(line, "meta", Dict()); meta = meta isa AbstractDict ? meta : Dict()
        push!(rows, Dict{String,Any}("line_id" => id, "bus_from" => a, "bus_to" => b,
            "terminal_map_from" => from_map, "terminal_map_to" => to_map,
            "linecode" => get(line, "linecode", nothing), "feeder_id" => get(meta, "feeder_id", nothing)))
    end
    same_pair = !(nothing in pairs) && length(pairs) == 1
    map_relation = !same_pair || any(isnothing, maps) ? "unassessed" :
        all(m -> isequal(m, first(maps)), maps) ? "equal_declared_maps" : "different_declared_maps"
    Dict{String,Any}("n_lines" => length(ids), "lines" => rows, "lines_truncated" => length(ids) > limit,
        "same_bus_pair" => same_pair, "terminal_map_relation" => map_relation)
end

# Index only the already eligible bus coordinates; a route never grants an
# unrelated bus a coordinate frame. Counts are unavailable when a query is cut.
function _spatial_route_bus_index(coordinates, frame, radius)
    points = coordinates.points
    magnitude = isempty(points) ? 0.0 : maximum(maximum(abs, _proximity_index_point(p, frame.kind)) for p in values(points))
    width = radius + 16 * eps(magnitude)
    buckets = Dict{NTuple{3,Int},Vector{String}}()
    excluded = 0
    for id in sort!(collect(keys(points)))
        p = _proximity_index_point(points[id], frame.kind)
        if !isfinite(width) || !all(x -> isfinite(x) && abs(x) < 2.0^50, p ./ radius)
            excluded += 1
            continue
        end
        push!(get!(buckets, floor.(Int, p ./ width), String[]), id)
    end
    (buckets=buckets, width=width, excluded=excluded)
end

function _spatial_route_queries(point, excluded_bus, index, coordinates, topology, radius, checked, budget, limit)
    p = _proximity_index_point(point, "wgs84")
    if !isfinite(index.width) || !all(x -> isfinite(x) && abs(x) < 2.0^50, p ./ radius)
        return Dict{String,Any}("status" => "indeterminate", "reason" => "index_numeric_range", "n_buses" => nothing, "buses" => [])
    end
    cell = floor.(Int, p ./ index.width)
    rows = Dict{String,Any}[]; count = 0; complete = index.excluded == 0
    for dx in -1:1, dy in -1:1, dz in -1:1
        for id in get(index.buckets, (cell[1]+dx, cell[2]+dy, cell[3]+dz), String[])
            id == excluded_bus && continue
            if checked[] >= budget
                return Dict{String,Any}("status" => "indeterminate", "reason" => "query_budget_exhausted",
                    "n_buses" => nothing, "n_buses_observed" => count, "buses" => rows)
            end
            checked[] += 1
            distance = _coordinate_distance(point, coordinates.points[id], "wgs84")
            (distance !== nothing && distance <= radius) || continue
            count += 1
            length(rows) >= limit && continue
            push!(rows, Dict{String,Any}("distance_m" => distance, "bus" => topology.bus_context(id),
                "coordinate_evidence" => coordinates.evidence[id]))
        end
    end
    Dict{String,Any}("status" => complete ? "assessed" : "indeterminate",
        "reason" => complete ? "completed" : "index_numeric_range", "n_buses" => complete ? count : nothing,
        "n_buses_observed" => count, "buses" => rows, "buses_truncated" => count > limit)
end

function _spatial_route_candidates!(checks, net, topology, coordinates, frame, budget, tolerance, span, limit)
    endpoints = checks["route_endpoints"]; overlaps = checks["route_overlaps"]
    defects = checks["route_defects"]; sources = checks["source_intervals"]
    segments = Dict{Any,Set{String}}(); intervals = Dict{Tuple{String,String},Vector{String}}()
    bus_index = frame.kind == "wgs84" ? _spatial_route_bus_index(coordinates, frame, tolerance) : nothing
    queried = Ref(0); compared = 0; missing = 0; unsupported = 0; invalid = 0
    route_count = 0; valid_routes = 0; segment_count = 0; truncated = false; source_invalid = 0
    for (id_raw, line) in sort!(collect(get(net, "line", Dict())), by=first)
        line isa AbstractDict || continue
        id = string(id_raw)
        meta = get(line, "meta", Dict()); meta = meta isa AbstractDict ? meta : Dict()
        extension = get(meta, "backbone_extension", Dict()); extension = extension isa AbstractDict ? extension : Dict()
        for (namespace, object) in (("meta.source_interval", meta), ("meta.backbone_extension.source_interval", extension))
            haskey(object, "source_interval") || continue
            source = object["source_interval"]
            if source isa AbstractString && !isempty(strip(source))
                push!(get!(intervals, (namespace, source), String[]), id)
            else
                source_invalid += 1
            end
        end
        haskey(meta, "route_geometry") || continue
        route_count += 1
        route = _spatial_route(line)
        geometry = route === nothing ? (status="indeterminate", reason="invalid_route_object") : _spatial_route_length(route)
        if geometry.status == "inapplicable"
            unsupported += 1
            continue
        elseif geometry.status != "passed"
            invalid += 1
            _spatial_candidate!(defects, "S.INVALID_ROUTE_GEOMETRY", Dict{String,Any}("line_id" => id,
                "reason" => geometry.reason), limit)
            continue
        end
        valid_routes += 1
        points = [_proximity_location(_spatial_point(v[1], v[2]), "wgs84") for v in route["coordinates"]]
        # Bound segment processing independently of bus queries and path walks.
        if length(points)-1 > budget-segment_count
            truncated = true
        else
            segment_count += length(points)-1
            seen = Set{Any}(); zero = Int[]; repeated = Int[]; jumps = Dict{String,Any}[]
            nzero = 0; nrepeated = 0; njumps = 0
            for i in 2:length(points)
                p, q = points[i-1], points[i]
                if p == q
                    nzero += 1
                    length(zero) < limit && push!(zero, i-1)
                    continue
                end
                key = _spatial_pair(p, q)
                if key in seen
                    nrepeated += 1
                    length(repeated) < limit && push!(repeated, i-1)
                end
                push!(seen, key)
                push!(get!(segments, key, Set{String}()), id)
                d = _spatial_haversine(p, q)
                if d > span
                    njumps += 1
                    length(jumps) < limit && push!(jumps, Dict("segment_index" => i-1, "distance_m" => d))
                end
            end
            if nzero + nrepeated + njumps > 0
                _spatial_candidate!(defects, "S.ROUTE_SEGMENT_DEFECT", Dict{String,Any}(
                    "line_id" => id, "n_zero_segments" => nzero, "zero_segment_indices" => zero,
                    "n_repeated_segments" => nrepeated, "repeated_segment_indices" => repeated,
                    "n_long_segments" => njumps, "long_segments" => jumps, "long_segment_threshold_m" => span), limit)
            end
        end
        a, b = get(line, "bus_from", nothing), get(line, "bus_to", nothing)
        if bus_index === nothing || !all(x -> haskey(coordinates.points, x), (a, b))
            missing += 1
            continue
        end
        compared += 1
        p, q = first(points), last(points)
        ca, cb = coordinates.points[a], coordinates.points[b]
        forward = (_spatial_haversine(ca, p), _spatial_haversine(cb, q))
        reverse = (_spatial_haversine(ca, q), _spatial_haversine(cb, p))
        reversed = maximum(reverse) < maximum(forward)
        distances = reversed ? reverse : forward
        maximum(distances) > tolerance || continue
        ends = reversed ? (q, p) : (p, q)
        rows = Dict{String,Any}[]
        for (i, bus) in enumerate((a, b))
            distances[i] > tolerance || continue
            query = _spatial_route_queries(ends[i], bus, bus_index, coordinates, topology,
                tolerance, queried, budget, limit)
            query["status"] == "assessed" || _spatial_incomplete!(endpoints, query["reason"])
            push!(rows, Dict{String,Any}("side" => i == 1 ? "from" : "to",
                "connected_bus" => topology.bus_context(bus), "gap_m" => distances[i],
                "route_endpoint_lonlat" => collect(ends[i]), "nearby_alternative_buses" => query))
        end
        _spatial_candidate!(endpoints, "S.ROUTE_ENDPOINT_DISAGREEMENT", Dict{String,Any}(
            "line_id" => id, "orientation" => maximum(reverse) == maximum(forward) ? "ambiguous" : reversed ? "reversed" : "forward",
            "tolerance_m" => tolerance, "endpoints" => rows), limit)
    end
    for ((namespace, source), ids) in sort!(collect(intervals), by=first)
        length(ids) > 1 || continue
        _spatial_candidate!(sources, "S.REPEATED_SOURCE_INTERVAL", merge(_spatial_line_group(net, ids, limit),
            Dict{String,Any}("namespace" => namespace, "source_interval" => source)), limit)
    end
    sources["n_invalid_interval_declarations"] = source_invalid
    sources["n_declared_intervals"] = length(intervals)
    for (segment, ids) in sort!(collect(segments), by=first)
        length(ids) > 1 || continue
        _spatial_candidate!(overlaps, "S.SHARED_ROUTE_SEGMENT", merge(_spatial_line_group(net, sort!(collect(ids)), limit),
            Dict{String,Any}("segment_lonlat" => [collect(p) for p in segment],
                "segment_length_m" => _spatial_haversine(segment...))), limit)
    end
    for check in (endpoints, overlaps, defects)
        check["n_routes"] = route_count
        check["n_valid_wgs84_routes"] = valid_routes
        check["n_unsupported_routes"] = unsupported
        check["n_invalid_routes"] = invalid
    end
    endpoints["n_endpoint_comparisons"] = compared
    endpoints["n_routes_with_unavailable_bus_coordinates"] = missing
    endpoints["bus_distance_queries_checked"] = queried[]
    overlaps["n_segments_checked"] = segment_count
    if truncated
        _spatial_incomplete!(overlaps, "segment_budget_exhausted")
        _spatial_incomplete!(defects, "segment_budget_exhausted")
    end
    if route_count == 0
        for check in (endpoints, overlaps, defects)
            _spatial_incomplete!(check, "no_routes"; status="inapplicable")
        end
    else
        compared == 0 && _spatial_incomplete!(endpoints, "no_comparable_route_endpoints")
        valid_routes == 0 && _spatial_incomplete!(overlaps, "no_supported_valid_routes";
            status=invalid == 0 ? "inapplicable" : "indeterminate")
        valid_routes == 0 && invalid == 0 && _spatial_incomplete!(defects, "unsupported_route_basis"; status="inapplicable")
    end
    isempty(intervals) && _spatial_incomplete!(sources, source_invalid == 0 ? "no_explicit_source_intervals" : "invalid_source_intervals";
        status=source_invalid == 0 ? "inapplicable" : "indeterminate")
    # Adding later observed candidates must never restore a partial total.
    for check in values(checks)
        check["counts_complete"] || (check["n_candidates"] = nothing)
    end
end
