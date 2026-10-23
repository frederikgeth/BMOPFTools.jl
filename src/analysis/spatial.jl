# Descriptive geometry only. A field named longitude/latitude is not evidence
# of WGS84: sideload_coordinates! also copies arbitrary OpenDSS x/y verbatim.

function _spatial_point(x, y)
    (x isa Real && y isa Real && !(x isa Bool) && !(y isa Bool) &&
     isfinite(x) && isfinite(y)) || return nothing
    # Signed zero denotes the same position and must hash into the same group.
    point = (iszero(x) ? 0.0 : Float64(x), iszero(y) ? 0.0 : Float64(y))
    all(isfinite, point) ? point : nothing
end

function _spatial_length(value)
    value isa Real && !(value isa Bool) && isfinite(value) && value >= 0 || return nothing
    converted = Float64(value)
    isfinite(converted) ? converted : nothing
end

function _spatial_route_length(route)
    route === nothing && return (status="inapplicable", reason="no_route", length=nothing)
    get(route, "basis", nothing) == "WGS84_geodesic_polyline" ||
        return (status="inapplicable", reason="unsupported_route_basis", length=nothing)
    raw = get(route, "coordinates", nothing)
    raw isa AbstractVector && length(raw) >= 2 ||
        return (status="indeterminate", reason="invalid_route_coordinates", length=nothing)
    points = Tuple{Float64,Float64}[]
    for vertex in raw
        vertex isa AbstractVector && length(vertex) >= 2 ||
            return (status="indeterminate", reason="invalid_route_vertex", length=nothing)
        p = _spatial_point(vertex[1], vertex[2])
        _wgs84_point(p) || return (status="indeterminate", reason="invalid_route_vertex", length=nothing)
        push!(points, p)
    end
    distance = sum(_spatial_haversine(points[i-1], points[i]) for i in 2:length(points))
    (status="passed", reason="valid_wgs84_polyline", length=distance)
end

function _spatial_length_comparison(a, b; lower_bound=false, unavailable="indeterminate")
    if a === nothing || b === nothing
        return Dict{String,Any}("status" => unavailable, "tolerance_m" => nothing,
                               "difference_m" => nothing)
    end
    tolerance = max(5.0, 0.1 * b)
    failed = lower_bound ? a + tolerance < b : abs(a - b) > tolerance
    Dict{String,Any}("status" => failed ? "failed" : "passed",
        "tolerance_m" => tolerance, "difference_m" => a - b)
end

function _spatial_line_context(id, line, chord, metric_status)
    meta = get(line, "meta", nothing)
    meta = meta isa AbstractDict ? meta : Dict()
    declared = _spatial_length(get(line, "length", nothing))
    physical = _spatial_length(get(meta, "physical_length_m", nothing))
    regularized = get(meta, "electrical_length_regularized", false)
    # An invalid explicit physical length or regularization flag must not fall
    # back to a physical interpretation of the electrical declaration.
    basis = haskey(meta, "physical_length_m") ? "physical_length_m" :
        regularized === false ? "declared_length" : "unavailable"
    comparison = basis == "physical_length_m" ? physical :
        basis == "declared_length" ? declared : nothing
    route = _spatial_route(line)
    geometry = haskey(meta, "route_geometry") && route === nothing ?
        (status="indeterminate", reason="invalid_route_object", length=nothing) : _spatial_route_length(route)
    stored_route = route === nothing ? nothing : _spatial_length(get(route, "length_m", nothing))
    chord_check = _spatial_length_comparison(comparison, chord; lower_bound=true, unavailable=metric_status)
    chord_check["basis"] = basis
    route_check = _spatial_length_comparison(stored_route, geometry.length;
        unavailable=geometry.status == "inapplicable" ? "inapplicable" : "indeterminate")
    physical_route_check = _spatial_length_comparison(comparison, geometry.length;
        unavailable=geometry.status == "inapplicable" ? "inapplicable" : "indeterminate")
    declared_physical_check = _spatial_length_comparison(declared, physical;
        unavailable=haskey(meta, "physical_length_m") ? "indeterminate" : "inapplicable")
    tags = String[]
    for (tag, check) in (("shorter_than_chord", chord_check),
                         ("stored_route_length_mismatch", route_check),
                         ("physical_route_length_mismatch", physical_route_check),
                         ("declared_physical_length_mismatch", declared_physical_check))
        check["status"] == "failed" && push!(tags, tag)
    end
    regularized === true && push!(tags, "regularized_electrical_length")
    geometry.status == "indeterminate" && push!(tags, "invalid_route_geometry")
    route !== nothing && haskey(route, "length_m") && stored_route === nothing &&
        push!(tags, "invalid_route_length")
    (declared === nothing || (haskey(meta, "physical_length_m") && physical === nothing) ||
        !(regularized isa Bool)) && push!(tags, "invalid_length_declaration")
    Dict{String,Any}("line_id" => string(id),
        "bus_from" => get(line, "bus_from", nothing), "bus_to" => get(line, "bus_to", nothing),
        "declared_length_m" => declared, "physical_length_m" => physical,
        "comparison_length_m" => comparison, "comparison_basis" => basis,
        "electrical_length_regularized" => regularized isa Bool ? regularized : nothing,
        "length_scales_impedance" => haskey(line, "linecode") || haskey(line, "geometry"),
        "chord_m" => chord, "stored_route_length_m" => stored_route,
        "recomputed_route_length_m" => geometry.length,
        "route_geometry_status" => geometry.status, "route_geometry_reason" => geometry.reason,
        "chord_check" => chord_check, "route_length_check" => route_check,
        "physical_route_check" => physical_route_check, "declared_physical_check" => declared_physical_check,
        "contexts" => tags,
        "source_references" => Dict(k => meta[k] for k in ("raw_key", "raw_layer", "source_entity_id") if haskey(meta, k)))
end

function _spatial_length_summary(rows)
    status_counts = Dict{String,Any}()
    for key in ("chord_check", "route_length_check", "physical_route_check", "declared_physical_check")
        counts = Dict(status => 0 for status in ("passed", "failed", "indeterminate", "inapplicable"))
        for row in rows
            counts[row[key]["status"]] += 1
        end
        status_counts[key] = counts
    end
    counts = Dict{String,Int}()
    witnesses = Dict{String,Any}[]
    selected = Dict{String,Int}()
    for row in sort(rows, by=r -> r["line_id"])
        tags = row["contexts"]
        for tag in tags
            counts[tag] = get(counts, tag, 0) + 1
        end
        any(tag -> get(selected, tag, 0) < 5, tags) || continue
        push!(witnesses, row)
        for tag in tags
            selected[tag] = get(selected, tag, 0) + 1
        end
    end
    Dict{String,Any}("n_lines" => length(rows), "comparison_status_counts" => status_counts,
        "context_counts" => counts, "witnesses" => witnesses, "witnesses_per_context_limit" => 5,
        "tolerance" => "max(5 m, 10% of reference distance)",
        "caution" => "Physical length metadata takes precedence over declared electrical length. Regularized electrical length alone has no physical interpretation. Route agreement is internal consistency, not independent confirmation of surveyed geometry.")
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

# Read endpoint declarations without decoding electrical transformer parameters.
# Preserve winding order and missing entries so partial geometry is never passed
# off as the extent of the entire device.
function _spatial_transformer_buses(t, subtype)
    t isa AbstractDict || return Any[]
    if subtype in WINDING_LIST_SUBTYPES
        ws = get(t, "windings", nothing)
        ws isa AbstractVector || return Any[]
        return Any[w isa AbstractDict ? get(w, "bus", nothing) : nothing for w in ws]
    end
    Any[get(t, "bus_from", nothing), get(t, "bus_to", nothing)]
end

function _spatial_coincidence(net, coords, level_by_bus, crs_status; excluded=Set{String}())
    # Equality is descriptive even without a metric CRS. Never mix x/y and
    # longitude/latitude field families or silently snap almost-equal positions.
    groups = Dict{Tuple{String,Float64,Float64},Vector{String}}()
    for (id, p) in coords
        id in excluded && continue
        crs_status == "declared_wgs84" && !_wgs84_point(p) && continue
        push!(get!(groups, ("longitude_latitude", p...), String[]), id)
    end
    for (id, bus) in get(net, "bus", Dict())
        string(id) in excluded && continue
        bus isa AbstractDict || continue
        # A bus with lon/lat fields uses that family, including invalid pairs.
        any(k -> haskey(bus, k), ("longitude", "latitude")) && continue
        p = _spatial_point(get(bus, "x", nothing), get(bus, "y", nothing))
        p === nothing && continue
        push!(get!(groups, ("xy", p...), String[]), string(id))
    end
    eligible = sum(length, values(groups); init=0)
    filter!(kv -> length(last(kv)) > 1, groups)
    members = sort!([sort!(ids) for ids in values(groups)], by=first)
    group_of = Dict(id => i for (i, ids) in enumerate(members) for id in ids)
    point_of = Dict(first(sort(ids)) => key for (key, ids) in groups)
    contexts = [Set{String}() for _ in members]
    references = [Dict{String,Any}[] for _ in members]
    reference_counts = zeros(Int, length(members))
    function record!(kind, id, buses, ports; state=nothing)
        ids = unique(String[b for b in buses if b isa AbstractString])
        by_group = Dict{Int,Int}()
        for bus in ids
            i = get(group_of, bus, 0)
            i == 0 || (by_group[i] = get(by_group, i, 0) + 1)
        end
        for (i, count) in by_group
            count >= 2 || continue
            context = startswith(kind, "transformer:") ? "transformer_ports" :
                kind == "switch" ? (state === true ? "open_switch" :
                    state === false ? "closed_switch" : "unknown_switch_state") : "line_connected"
            push!(contexts[i], context)
            reference_counts[i] += 1
            # Input traversal is sorted, so the bounded selection is stable.
            length(references[i]) >= 20 && continue
            push!(references[i], Dict{String,Any}("kind" => kind,
                "component_id" => string(id), "ports" => ports, "open_switch" => state))
        end
    end
    for kind in ("line", "switch")
        for (id, component) in sort!(collect(get(net, kind, Dict())), by=first)
            component isa AbstractDict || continue
            buses = Any[get(component, "bus_from", nothing), get(component, "bus_to", nothing)]
            ports = [Dict("bus" => buses[i], "terminal_map" => get(component, "terminal_map_$side", nothing))
                     for (i, side) in enumerate(("from", "to"))]
            record!(kind, id, buses, ports; state=kind == "switch" ? get(component, "open_switch", nothing) : nothing)
        end
    end
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa AbstractDict || continue
        for (id, t) in sort!(collect(sub), by=first)
            t isa AbstractDict || continue
            buses = _spatial_transformer_buses(t, subtype)
            ports = if subtype in WINDING_LIST_SUBTYPES
                [Dict("winding" => i, "bus" => buses[i], "terminal_map" =>
                    w isa AbstractDict ? get(w, "terminal_map", nothing) : nothing)
                 for (i, w) in enumerate(get(t, "windings", Any[]) isa AbstractVector ? t["windings"] : Any[])]
            else
                [Dict("winding" => i, "bus" => buses[i], "terminal_map" => get(t, "terminal_map_$side", nothing))
                 for (i, side) in enumerate(("from", "to"))]
            end
            record!("transformer:$subtype", id, buses, ports)
        end
    end
    counts = Dict{String,Int}()
    for tags in contexts
        isempty(tags) && push!(tags, "no_direct_branch")
        for tag in tags
            counts[tag] = get(counts, tag, 0) + 1
        end
    end
    # Retain examples per context, so plentiful transformer ports cannot hide
    # groups with no direct branch. These tags explain declarations, not intent.
    witnesses = Dict{String,Any}[]
    selected = Dict{String,Int}()
    for (i, ids) in enumerate(members)
        tags = sort!(collect(contexts[i]))
        any(tag -> get(selected, tag, 0) < 5, tags) || continue
        for tag in tags
            selected[tag] = get(selected, tag, 0) + 1
        end
        family, x, y = point_of[first(ids)]
        bus_rows = [Dict{String,Any}("bus_id" => id,
            "voltage_tier" => get(level_by_bus, id, "unassigned"),
            "terminal_names" => get(net["bus"][id], "terminal_names", nothing))
            for id in Iterators.take(ids, 20)]
        push!(witnesses, Dict{String,Any}("anchor_bus" => first(ids),
            "coordinate_fields" => family, "coordinate" => [x, y],
            "n_buses" => length(ids), "buses" => bus_rows,
            "contexts" => tags, "n_internal_components" => reference_counts[i],
            "internal_components" => references[i],
            "members_truncated" => length(ids) > 20,
            "components_truncated" => reference_counts[i] > 20))
    end
    Dict{String,Any}("status" => eligible > 0 ? "assessed" : "indeterminate",
        "basis" => "exact_coordinate_equality_within_field_family",
        "n_eligible_buses" => eligible, "n_groups" => length(members),
        "n_buses_in_groups" => sum(length, members; init=0),
        "context_counts" => counts, "witnesses" => witnesses,
        "witnesses_per_context_limit" => 5, "members_per_witness_limit" => 20,
        "components_per_witness_limit" => 20,
        "caution" => "Coordinate equality does not establish electrical connectivity, duplicate assets, or a need to merge buses. Context tags describe direct branch declarations only.")
end

function _spatial_transformer_extent(net, coords, eligible; distance_kind="wgs84")
    rows = Dict{String,Any}[]
    incomplete = Dict{String,Any}[]
    n_total = 0
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa AbstractDict || continue
        for (id, t) in sort!(collect(sub), by=first)
            n_total += 1
            buses = _spatial_transformer_buses(t, subtype)
            if length(buses) < 2 || !all(b -> b isa AbstractString && b in eligible, buses)
                push!(incomplete, Dict{String,Any}("transformer_id" => string(id),
                    "subtype" => subtype, "status" => "indeterminate", "winding_buses" => buses))
                continue
            end
            distance = 0.0
            distance_valid = true
            farthest = [buses[1], buses[2]]
            for i in eachindex(buses), j in (i+1):length(buses)
                d = _coordinate_distance(coords[buses[i]], coords[buses[j]], distance_kind)
                if d === nothing
                    distance_valid = false
                    break
                end
                if d > distance
                    distance = d
                    farthest = [buses[i], buses[j]]
                end
            end
            if !distance_valid
                push!(incomplete, Dict{String,Any}("transformer_id" => string(id),
                    "subtype" => subtype, "status" => "indeterminate", "winding_buses" => buses,
                    "reason" => "distance_overflow"))
                continue
            end
            push!(rows, Dict{String,Any}("transformer_id" => string(id),
                "subtype" => subtype, "distance_m" => distance,
                "winding_buses" => buses, "farthest_bus_pair" => farthest))
        end
    end
    sort!(rows, by=r -> (-r["distance_m"], r["subtype"], r["transformer_id"]))
    Dict{String,Any}("n_transformers" => n_total, "n_assessed" => length(rows),
        "n_indeterminate" => length(incomplete),
        "n_zero_extent" => count(r -> r["distance_m"] == 0, rows),
        "separation_m" => _spatial_quantiles(Float64[r["distance_m"] for r in rows]),
        "farthest_witnesses" => collect(Iterators.take(rows, 10)),
        "indeterminate_witnesses" => collect(Iterators.take(incomplete, 10)),
        "caution" => "Extent is the maximum separation of all winding buses. Coincident ports can represent equipment at one location; zero extent alone is not an anomaly.")
end

"""
    _spatial_analysis(net, voltage_levels) -> Union{Nothing,Dict{String,Any}}

Return nothing unless buses contain coordinate fields. Distances in metres use
unambiguous WGS84 or explicit local Cartesian declarations, or endpoint-scoped
WGS84 route evidence. Unsupported/conflicting declarations suppress distances.
Ranked examples are descriptive. Findings require an explicit WGS84 declaration.
"""
function _spatial_analysis(net::Dict{String,Any}, voltage_levels::Dict{String,Any},
                           findings::Vector{Finding}=Finding[]; config::Dict=_DEFAULT_CONFIG)
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
    route_supported_buses = Set{String}()
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
           _spatial_route_matches(a, b, _spatial_route_ends(route)) &&
           _spatial_route_length(route).status == "passed"
            route_matched += 1
            push!(route_supported_buses, string(line["bus_from"]), string(line["bus_to"]))
        end
    end
    declared_crs = _spatial_crs_declaration(net)
    route_supports_wgs84 = route_matched > 0 &&
        all(==("WGS84_geodesic_polyline"), keys(route_basis))
    frame = _coordinate_frame(net)
    if frame.status == "unspecified" && route_supports_wgs84
        if frame.unit === nothing || first(frame.unit) == "degrees"
            frame = merge(frame, (status="wgs84_route_evidence", kind="wgs84", token="WGS84", unit=("degrees", 1.0),
                report=merge(frame.report, Dict("status" => "wgs84_route_evidence", "frame" => "WGS84", "units" => "degrees"))))
        else
            frame = merge(frame, (status="ambiguous", report=merge(frame.report,
                Dict("status" => "ambiguous", "issues" => ["coordinate_unit_domain_conflict"]))))
        end
    end
    crs_status = frame.status
    coordinates = _coordinate_inventory(net, frame, route_supported_buses)
    geodesic = crs_status in ("declared_wgs84", "wgs84_route_evidence")
    metric_coords = coordinates.points
    eligible = Set(keys(metric_coords))
    metric = geodesic || crs_status == "declared_cartesian"
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
        crs_status == "declared_cartesian" ?
        "Explicit local Cartesian x/y coordinates are converted to metres using declared units; no map projection is inferred." :
        crs_status == "ambiguous" ?
        "Conflicting or incomplete coordinate declarations prevent metric comparisons; inspect coordinate_semantics issues." :
        crs_status == "wgs84_route_evidence" ?
        "No network CRS is declared. Only bus endpoints matched to valid WGS84 route polylines support metre distances; the coordinate frame of other buses remains indeterminate." :
        crs_status == "declared_other" ?
        "The declared coordinate system is outside the supported WGS84 metric domain; bus geodesic comparisons are inapplicable. Exact coordinate equality remains descriptive." :
        "Coordinate system is not confirmed as WGS84. Longitude/latitude fields may contain arbitrary x/y; bus metre distances remain indeterminate."

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
    context_rows = Dict{String,Any}[]
    n_route_length_mismatch = 0
    n_route_endpoint_comparisons = 0; n_route_length_comparisons = 0
    for (id, line) in sort!(collect(lines), by=first)
        line isa AbstractDict || continue
        from = string(get(line, "bus_from", "")); to = string(get(line, "bus_to", ""))
        a = get(coords, from, nothing); b = get(coords, to, nothing)
        tier_a = get(level_by_bus, from, "unassigned")
        tier_b = get(level_by_bus, to, "unassigned")
        tier = tier_a == tier_b ? tier_a : "cross_tier"
        length_m = _spatial_length(get(line, "length", nothing))
        chord = from in eligible && to in eligible ?
            _coordinate_distance(metric_coords[from], metric_coords[to], frame.kind) : nothing
        metric_status = crs_status == "declared_other" ? "inapplicable" : "indeterminate"
        context = _spatial_line_context(id, line, chord, metric_status)
        push!(context_rows, context)
        if length_m !== nothing
            push!(get!(lengths_by_level, tier, Float64[]), length_m)
            push!(length_rows, (id=string(id), tier=tier, length=length_m))
        end
        if chord !== nothing
            if length_m !== nothing
                push!(chord_rows, (id=string(id), tier=tier, length=length_m,
                                   chord=chord, ratio=chord > 0 ? length_m / chord : nothing))
            end
            if crs_status == "declared_wgs84" && context["chord_check"]["status"] == "failed"
                push!(findings, Finding(WARNING, "W.GEO.LINE_SHORTER_THAN_CHORD",
                    :connectivity, :line, string(id),
                    "Line '$id' has a length below the geographic distance between its buses; inspect its physical/electrical length basis.",
                    Dict{String,Any}("bus_from" => from, "bus_to" => to,
                        "from_lonlat" => collect(a), "to_lonlat" => collect(b),
                        "length_m" => length_m, "chord_m" => chord,
                        "comparison_length_m" => context["comparison_length_m"],
                        "comparison_basis" => context["comparison_basis"],
                        "physical_length_m" => context["physical_length_m"],
                        "electrical_length_regularized" => context["electrical_length_regularized"],
                        "tolerance_m" => context["chord_check"]["tolerance_m"], "declared_crs" => declared_crs,
                        "length_scales_impedance" => context["length_scales_impedance"])))
            end
            route = _spatial_route(line)
            if geodesic && route !== nothing && get(route, "basis", nothing) == "WGS84_geodesic_polyline"
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
                route_length = _spatial_length(get(route, "length_m", nothing))
                if length_m !== nothing && route_length !== nothing
                    n_route_length_comparisons += 1
                    abs(length_m - route_length) > max(5.0, 0.1 * length_m) &&
                        (n_route_length_mismatch += 1)
                end
            end
        end
    end

    transformers = _spatial_transformer_extent(net, metric_coords, eligible; distance_kind=frame.kind)
    excluded = Set(id for (id, ev) in coordinates.evidence if crs_status == "ambiguous" ||
        any(r -> r in ("bus_crs_conflict", "bus_units_conflict", "bus_axis_order_conflict"), ev["issues"]))

    sort!(length_rows, by=r -> (-r.length, r.id))
    sort!(chord_rows, by=r -> (r.length - r.chord, r.id))
    short_chord_rows = filter(r -> r.length + max(5.0, 0.1 * r.chord) < r.chord,
                              chord_rows)
    sort!(route_gap_rows, by=r -> (-r.gap, r.id))
    length_stats = Dict(k => _spatial_quantiles(v) for (k, v) in lengths_by_level)
    relative_length_rows = [(id=r.id, tier=r.tier, length=r.length,
                             relative_to_p99=r.length / max(length_stats[r.tier]["p99"], eps()))
                            for r in length_rows]
    sort!(relative_length_rows, by=r -> (-r.relative_to_p99, r.id))
    Dict{String,Any}(
        "coordinate_reference" => Dict{String,Any}(
            "status" => crs_status, "declared_crs" => declared_crs,
            "caution" => caution, "n_matching_wgs84_routes" => route_matched,
            "n_metric_eligible_buses" => length(eligible),
            "distance_scope" => crs_status in ("declared_wgs84", "declared_cartesian") ? "declared_network_frame" :
                crs_status == "wgs84_route_evidence" ? "matched_route_endpoints_only" : "unavailable",
            "metric_distances_applicable" => metric,
            "geodesic_distances_applicable" => geodesic),
        "coordinate_semantics" => coordinates.report,
        "proximity" => _spatial_proximity(net, coordinates, frame, level_by_bus, config),
        "coordinate_coverage" => Dict{String,Any}(
            "n_buses" => length(buses), "n_with_any_coordinate" => n_any,
            "n_complete_lonlat" => n_complete, "n_with_xy_fields" => n_xy,
            "n_partial" => n_partial, "n_invalid" => n_invalid,
            "n_outside_wgs84_range" => n_outside),
        "coincidence" => _spatial_coincidence(net, coords, level_by_bus, crs_status; excluded=excluded),
        "length_context" => _spatial_length_summary(context_rows),
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
        "transformers" => transformers)
end
