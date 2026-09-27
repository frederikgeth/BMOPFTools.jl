# Descriptive geometry only. A field named longitude/latitude is not evidence
# of WGS84: sideload_coordinates! also copies arbitrary OpenDSS x/y verbatim.

function _spatial_point(x, y)
    (x isa Real && y isa Real && !(x isa Bool) && !(y isa Bool) &&
     isfinite(x) && isfinite(y)) || return nothing
    point = (Float64(x), Float64(y))
    all(isfinite, point) ? point : nothing
end

_wgs84_point(p) = p !== nothing && -180 <= p[1] <= 180 && -90 <= p[2] <= 90

function _spatial_haversine(a, b)
    lon1, lat1 = deg2rad(a[1]), deg2rad(a[2])
    lon2, lat2 = deg2rad(b[1]), deg2rad(b[2])
    h = sin((lat2 - lat1) / 2)^2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1) / 2)^2
    2 * 6_371_008.8 * asin(sqrt(clamp(h, 0.0, 1.0)))
end

function _spatial_quantiles(values::Vector{Float64})::Dict{String,Any}
    isempty(values) && return Dict{String,Any}("n" => 0)
    sorted = sort(values)
    at(p) = sorted[clamp(round(Int, 1 + (length(sorted) - 1) * p), 1, length(sorted))]
    Dict{String,Any}("n" => length(sorted), "p50" => at(0.5),
                     "p95" => at(0.95), "p99" => at(0.99), "max" => last(sorted))
end

function _spatial_crs_declaration(net)
    meta = get(net, "meta", nothing)
    for source in (net, meta)
        source isa AbstractDict || continue
        for key in ("coordinate_reference_system", "crs", "coordinate_system")
            value = get(source, key, nothing)
            value === nothing && continue
            if value isa AbstractDict
                value = get(value, "epsg", get(value, "code", get(value, "name", nothing)))
            end
            value === nothing || return string(value)
        end
    end
    nothing
end

function _spatial_is_wgs84(crs::AbstractString)
    token = lowercase(replace(strip(crs), r"[\s_\-]" => ""))
    token in ("epsg:4326", "4326", "wgs84", "ogc:crs84", "crs84")
end

function _spatial_route(line)
    meta = get(line, "meta", nothing)
    meta isa AbstractDict || return nothing
    route = get(meta, "route_geometry", nothing)
    route isa AbstractDict ? route : nothing
end

function _spatial_route_ends(route)
    points = get(route, "coordinates", nothing)
    points isa AbstractVector && length(points) >= 2 || return nothing
    first_pt = first(points); last_pt = last(points)
    first_pt isa AbstractVector && length(first_pt) >= 2 || return nothing
    last_pt isa AbstractVector && length(last_pt) >= 2 || return nothing
    a = _spatial_point(first_pt[1], first_pt[2])
    b = _spatial_point(last_pt[1], last_pt[2])
    a === nothing || b === nothing ? nothing : (a, b)
end

function _spatial_route_matches(a, b, ends)
    ends === nothing && return false
    p, q = ends
    near(x, y) = max(abs(x[1] - y[1]), abs(x[2] - y[2])) <= 1e-5
    (near(a, p) && near(b, q)) || (near(a, q) && near(b, p))
end

"""
    _spatial_analysis(net, voltage_levels) -> Union{Nothing,Dict{String,Any}}

Return nothing unless buses contain coordinate fields. Distances in metres are
computed only with an explicit WGS84 declaration or matching WGS84 route
evidence, and only for endpoints inside the geographic coordinate range.
Ranked examples are descriptive. Findings require an explicit WGS84 declaration.
"""
function _spatial_analysis(net::Dict{String,Any}, voltage_levels::Dict{String,Any},
                           findings::Vector{Finding}=Finding[])
    buses = get(net, "bus", Dict())
    any(bus -> bus isa AbstractDict && any(k -> haskey(bus, k),
        ("longitude", "latitude", "x", "y")), values(buses)) || return nothing

    coords = Dict{String,Tuple{Float64,Float64}}()
    n_any = 0; n_complete = 0; n_xy = 0; n_partial = 0; n_invalid = 0; n_outside = 0
    for (id, bus) in buses
        bus isa AbstractDict || continue
        has_lonlat = haskey(bus, "longitude") || haskey(bus, "latitude")
        has_xy = haskey(bus, "x") || haskey(bus, "y")
        (has_lonlat || has_xy) || continue
        n_any += 1
        has_xy && (n_xy += 1)
        if haskey(bus, "longitude") && haskey(bus, "latitude")
            point = _spatial_point(bus["longitude"], bus["latitude"])
            if point === nothing
                n_invalid += 1
            else
                coords[string(id)] = point
                n_complete += 1
                _wgs84_point(point) || (n_outside += 1)
            end
        elseif has_lonlat || has_xy && !(haskey(bus, "x") && haskey(bus, "y"))
            n_partial += 1
        end
    end

    lines = get(net, "line", Dict())
    route_basis = Dict{String,Int}()
    route_matched = 0
    n_routes = 0
    for line in values(lines)
        line isa AbstractDict || continue
        route = _spatial_route(line)
        route === nothing && continue
        n_routes += 1
        basis = string(get(route, "basis", "unspecified"))
        route_basis[basis] = get(route_basis, basis, 0) + 1
        basis == "WGS84_geodesic_polyline" || continue
        a = get(coords, string(get(line, "bus_from", "")), nothing)
        b = get(coords, string(get(line, "bus_to", "")), nothing)
        if a !== nothing && b !== nothing && _wgs84_point(a) && _wgs84_point(b) &&
           _spatial_route_matches(a, b, _spatial_route_ends(route))
            route_matched += 1
        end
    end
    declared_crs = _spatial_crs_declaration(net)
    route_supports_wgs84 = route_matched > 0 &&
        all(==("WGS84_geodesic_polyline"), keys(route_basis))
    crs_status = declared_crs === nothing ?
        (route_supports_wgs84 ? "wgs84_route_evidence" : "unspecified") :
        (_spatial_is_wgs84(declared_crs) ? "declared_wgs84" : "declared_other")
    geodesic = crs_status in ("declared_wgs84", "wgs84_route_evidence")
    if crs_status == "declared_wgs84"
        for id in sort!(collect(keys(coords)))
            point = coords[id]
            _wgs84_point(point) && continue
            push!(findings, Finding(WARNING, "W.GEO.WGS84_RANGE", :connectivity,
                :bus, id, "Bus '$id' has coordinates outside the declared WGS84 longitude/latitude range.",
                Dict{String,Any}("longitude" => point[1], "latitude" => point[2],
                                 "declared_crs" => declared_crs)))
        end
    end
    caution = crs_status == "declared_wgs84" ?
        "Network metadata declares WGS84; metre distances use valid longitude/latitude pairs only." :
        crs_status == "wgs84_route_evidence" ?
        "No network CRS is declared. Matching WGS84 route polylines support a geographic interpretation; verify that other bus coordinates share that frame. Fields named longitude/latitude may otherwise be arbitrary x/y." :
        "Coordinate system is not confirmed as WGS84. Longitude/latitude fields may contain arbitrary x/y; geodesic distances and spatial mismatch checks are inapplicable."

    level_by_bus = Dict{String,String}()
    for (label, level) in get(voltage_levels, "levels", Dict())
        for bus in get(level, "buses", String[])
            level_by_bus[string(bus)] = string(label)
        end
    end
    lengths_by_level = Dict{String,Vector{Float64}}()
    length_rows = NamedTuple[]
    chord_rows = NamedTuple[]
    route_gap_rows = NamedTuple[]
    n_route_length_mismatch = 0
    n_route_endpoint_comparisons = 0; n_route_length_comparisons = 0
    for (id, line) in lines
        line isa AbstractDict || continue
        from = string(get(line, "bus_from", "")); to = string(get(line, "bus_to", ""))
        a = get(coords, from, nothing); b = get(coords, to, nothing)
        tier_a = get(level_by_bus, from, "unassigned")
        tier_b = get(level_by_bus, to, "unassigned")
        tier = tier_a == tier_b ? tier_a : "cross_tier"
        raw_length = get(line, "length", nothing)
        length_m = raw_length isa Real && !(raw_length isa Bool) && isfinite(raw_length) && raw_length >= 0 ?
            Float64(raw_length) : nothing
        if length_m !== nothing
            push!(get!(lengths_by_level, tier, Float64[]), length_m)
            push!(length_rows, (id=string(id), tier=tier, length=length_m))
        end
        if geodesic && a !== nothing && b !== nothing && _wgs84_point(a) && _wgs84_point(b)
            chord = _spatial_haversine(a, b)
            if length_m !== nothing
                push!(chord_rows, (id=string(id), tier=tier, length=length_m,
                                   chord=chord, ratio=chord > 0 ? length_m / chord : nothing))
                tolerance = max(5.0, 0.1 * chord)
                if crs_status == "declared_wgs84" && length_m + tolerance < chord
                    push!(findings, Finding(WARNING, "W.GEO.LINE_SHORTER_THAN_CHORD",
                        :connectivity, :line, string(id),
                        "Line '$id' is shorter than the geographic distance between its buses.",
                        Dict{String,Any}("bus_from" => from, "bus_to" => to,
                            "from_lonlat" => collect(a), "to_lonlat" => collect(b),
                            "length_m" => length_m, "chord_m" => chord,
                            "tolerance_m" => tolerance, "declared_crs" => declared_crs,
                            "length_scales_impedance" => haskey(line, "linecode") || haskey(line, "geometry"))))
                end
            end
            route = _spatial_route(line)
            if route !== nothing && get(route, "basis", nothing) == "WGS84_geodesic_polyline"
                ends = _spatial_route_ends(route)
                if ends !== nothing && _wgs84_point(ends[1]) && _wgs84_point(ends[2])
                    p, q = ends
                    n_route_endpoint_comparisons += 1
                    gap = min(max(_spatial_haversine(a, p), _spatial_haversine(b, q)),
                              max(_spatial_haversine(a, q), _spatial_haversine(b, p)))
                    gap > 5 && push!(route_gap_rows, (id=string(id), gap=gap))
                    threshold = max(20.0, 0.1 * chord)
                    if crs_status == "declared_wgs84" && gap > threshold
                        push!(findings, Finding(WARNING, "W.GEO.ROUTE_ENDPOINT_GAP",
                            :connectivity, :line, string(id),
                            "Line '$id' route endpoints are far from its connected buses.",
                            Dict{String,Any}("bus_from" => from, "bus_to" => to,
                                "from_lonlat" => collect(a), "to_lonlat" => collect(b),
                                "route_first_lonlat" => collect(p),
                                "route_last_lonlat" => collect(q), "gap_m" => gap,
                                "threshold_m" => threshold, "declared_crs" => declared_crs,
                                "route_basis" => "WGS84_geodesic_polyline")))
                    end
                end
                route_length = get(route, "length_m", nothing)
                if length_m !== nothing && route_length isa Real && isfinite(route_length)
                    n_route_length_comparisons += 1
                    abs(length_m - route_length) > max(5.0, 0.1 * length_m) &&
                        (n_route_length_mismatch += 1)
                end
            end
        end
    end

    transformer_rows = NamedTuple[]
    if geodesic
        transformers = get(net, "transformer", Dict())
        for subtype in TRANSFORMER_SUBTYPES
            subtype in WINDING_LIST_SUBTYPES && continue
            sub = get(transformers, subtype, nothing)
            sub isa AbstractDict || continue
            for (id, transformer) in sub
                a = get(coords, string(get(transformer, "bus_from", "")), nothing)
                b = get(coords, string(get(transformer, "bus_to", "")), nothing)
                if a !== nothing && b !== nothing && _wgs84_point(a) && _wgs84_point(b)
                    push!(transformer_rows, (id=string(id), subtype=subtype,
                                             distance=_spatial_haversine(a, b)))
                end
            end
        end
    end

    sort!(length_rows, by=r -> (-r.length, r.id))
    sort!(chord_rows, by=r -> (r.length - r.chord, r.id))
    short_chord_rows = filter(r -> r.length + max(5.0, 0.1 * r.chord) < r.chord,
                              chord_rows)
    sort!(route_gap_rows, by=r -> (-r.gap, r.id))
    sort!(transformer_rows, by=r -> (-r.distance, r.id))
    length_stats = Dict(k => _spatial_quantiles(v) for (k, v) in lengths_by_level)
    relative_length_rows = [(id=r.id, tier=r.tier, length=r.length,
                             relative_to_p99=r.length / max(length_stats[r.tier]["p99"], eps()))
                            for r in length_rows]
    sort!(relative_length_rows, by=r -> (-r.relative_to_p99, r.id))
    Dict{String,Any}(
        "coordinate_reference" => Dict{String,Any}(
            "status" => crs_status, "declared_crs" => declared_crs,
            "caution" => caution, "n_matching_wgs84_routes" => route_matched,
            "geodesic_distances_applicable" => geodesic),
        "coordinate_coverage" => Dict{String,Any}(
            "n_buses" => length(buses), "n_with_any_coordinate" => n_any,
            "n_complete_lonlat" => n_complete, "n_with_xy_fields" => n_xy,
            "n_partial" => n_partial, "n_invalid" => n_invalid,
            "n_outside_wgs84_range" => n_outside),
        "routes" => Dict{String,Any}(
            "n_lines" => length(lines), "n_with_route" => n_routes,
            "basis_counts" => route_basis,
            "n_endpoint_comparisons" => n_route_endpoint_comparisons,
            "n_length_comparisons" => n_route_length_comparisons,
            "n_endpoint_gaps_over_5m" => n_route_endpoint_comparisons > 0 ?
                length(route_gap_rows) : nothing,
            "n_length_mismatches" => n_route_length_comparisons > 0 ?
                n_route_length_mismatch : nothing,
            "endpoint_gap_witnesses" => [Dict("line_id" => r.id, "gap_m" => r.gap)
                                         for r in Iterators.take(route_gap_rows, 10)]),
        "lines" => Dict{String,Any}(
            "length_by_tier_m" => length_stats,
            "n_with_chord_comparison" => length(chord_rows),
            "n_shorter_than_chord_beyond_tolerance" => !isempty(chord_rows) ?
                length(short_chord_rows) : nothing,
            "longest_witnesses" => [Dict("line_id" => r.id, "tier" => r.tier,
                                         "length_m" => r.length) for r in Iterators.take(length_rows, 10)],
            "relative_length_witnesses" => [Dict("line_id" => r.id, "tier" => r.tier,
                "length_m" => r.length, "relative_to_tier_p99" => r.relative_to_p99)
                for r in Iterators.take(relative_length_rows, 10)],
            "shorter_than_chord_witnesses" => [Dict("line_id" => r.id, "tier" => r.tier,
                "length_m" => r.length, "chord_m" => r.chord, "length_to_chord" => r.ratio)
                for r in Iterators.take(short_chord_rows, 10)]),
        "transformers" => Dict{String,Any}(
            "separation_m" => _spatial_quantiles(Float64[r.distance for r in transformer_rows]),
            "farthest_witnesses" => [Dict("transformer_id" => r.id,
                                          "subtype" => r.subtype,
                                          "distance_m" => r.distance)
                                     for r in Iterators.take(transformer_rows, 10)]))
end
