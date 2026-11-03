"""
    sideload_coordinates!(net, csv_path) -> (n_matched, n_skipped)

Read a OpenDSS-style bus coordinate CSV (`bus_id,x,y`, no header) and add
`"longitude"` and `"latitude"` fields to matching bus objects in `net`.

Returns the number of buses matched and the number of CSV rows skipped
because the bus ID was not present in `net` (open-switch stub buses and
synthetic slack buses are the usual cause).

The CSV x column is treated as longitude and y as latitude — the convention
used by OpenDSS `Buscoords` files.  No coordinate-system transformation is
performed; values are stored as-is. The field names do not prove WGS84: an
input may contain projected or arbitrary x/y. Spatial analysis reports an
unspecified coordinate reference unless case metadata or matching route
geometry supplies WGS84 evidence.

[`write_bmopf`](@ref) preserves these fields by default. Pass
`include_coordinates=false` when writing for strict BMOPF schema consumers.
"""
function sideload_coordinates!(net::Dict{String,Any}, csv_path::AbstractString)
    isfile(csv_path) || throw(ArgumentError("Coordinate CSV not found: $csv_path"))
    buses = get(net, "bus", Dict())
    n_matched = 0
    n_skipped = 0
    for line in eachline(csv_path)
        line = strip(line)
        isempty(line) && continue
        parts = split(line, ',')
        length(parts) >= 3 || continue
        id  = strip(parts[1])
        lon = tryparse(Float64, strip(parts[2]))
        lat = tryparse(Float64, strip(parts[3]))
        (lon === nothing || lat === nothing) && continue
        bus = get(buses, id, nothing)
        if bus isa Dict
            bus["longitude"] = lon
            bus["latitude"]  = lat
            n_matched += 1
        else
            n_skipped += 1
        end
    end
    return n_matched, n_skipped
end

"""
    sideload_geolayer!(net; overwrite=false) -> Dict{String,Any}

Apply the PowerIO GeoLayer stored in `net["extras"]["geojson"]` to the fields
that spatial analysis reads. PowerIO writes BMOPF geometry there as a GeoJSON
FeatureCollection whose `powerio_geo` member declares the coordinate space,
for example `{"space": "geographic", "crs": "EPSG:4326"}`, with `Point`
features `{"kind": "bus", "id": ...}` and `LineString` features
`{"kind": "line", "id": ..., "bus_from": ..., "bus_to": ...}`.

Only a geographic WGS84 layer is applied (`crs` absent, `EPSG:4326`, `WGS84`,
`OGC:CRS84` or an equivalent alias). Then:

- a bus `Point` sets `bus["longitude"]` and `bus["latitude"]`;
- a line `LineString` sets `line["meta"]["route_geometry"]` with
  `basis = "WGS84_geodesic_polyline"`, its vertices, and `length_m`, the
  geodesic length recomputed from those vertices;
- `meta.crs` is set to the layer CRS when the network declares none, and
  `meta.coordinate_provenance` to `powerio_geo.kind` (`source`, `synthetic`,
  `manual` or `derived`) when the network declares none.

Nothing is applied, and the report explains why, when `powerio_geo` is
missing or malformed, when the space is `projected`, `diagram` or `unknown`,
when the CRS is not WGS84, or when the network already declares a different
CRS. Coordinates are not transformed, and diagram or projected coordinates are
never relabeled as longitude/latitude.

Features are matched by exact `id`. Unmatched ids, nonfinite or out-of-range
coordinates, routes with fewer than two vertices, routes whose `bus_from` and
`bus_to` do not name the line's endpoints (in either orientation), and ids that
appear more than once are counted and skipped. Existing bus coordinates and
route geometry are kept unless `overwrite=true`. `extras.geojson` itself is
left in place.

The returned report has `status` (`"applied"`, `"inapplicable"` or
`"indeterminate"`), `reason`, the declared `space`, `crs` and
`coordinate_provenance`, `crs_declaration` (`"added"`, `"existing"` or
`nothing`), per-kind counts under `buses` and `lines` (`n_features`,
`n_applied`, `n_unmatched`, `n_invalid`, `n_duplicate_ids`, `n_kept_existing`,
plus `n_endpoint_mismatch` for lines), `n_ignored_features`, and bounded
`witnesses` (at most 20 ids per issue).

[`analyze`](@ref) reports a coordinate-free case that carries an unapplied
GeoLayer with spatial status `indeterminate` and reason `unapplied_geolayer`.
"""
function sideload_geolayer!(net::Dict{String,Any}; overwrite::Bool=false)::Dict{String,Any}
    limit = 20
    counts() = Dict{String,Any}("n_features" => 0, "n_applied" => 0, "n_unmatched" => 0,
        "n_invalid" => 0, "n_duplicate_ids" => 0, "n_kept_existing" => 0)
    report = Dict{String,Any}("status" => "indeterminate", "reason" => nothing,
        "space" => nothing, "crs" => nothing, "coordinate_provenance" => nothing,
        "crs_declaration" => nothing, "buses" => counts(),
        "lines" => merge(counts(), Dict{String,Any}("n_endpoint_mismatch" => 0)),
        "n_ignored_features" => 0, "witnesses" => Dict{String,Any}(), "witness_limit" => limit)
    stop(status, reason) = (report["status"] = status; report["reason"] = reason; report)

    extras = get(net, "extras", nothing)
    layer = extras isa AbstractDict ? get(extras, "geojson", nothing) : nothing
    layer === nothing && return stop("inapplicable", "no_geolayer")
    (layer isa AbstractDict && get(layer, "type", nothing) == "FeatureCollection" &&
        get(layer, "features", nothing) isa AbstractVector) ||
        return stop("indeterminate", "invalid_feature_collection")
    geo = get(layer, "powerio_geo", nothing)
    geo === nothing && return stop("indeterminate", "missing_powerio_geo")
    space = geo isa AbstractDict ? get(geo, "space", nothing) : nothing
    space isa AbstractString || return stop("indeterminate", "invalid_powerio_geo")
    report["space"] = space
    kind = get(geo, "kind", nothing)
    kind === nothing || kind isa AbstractString || return stop("indeterminate", "invalid_powerio_geo")
    report["coordinate_provenance"] = kind
    space == "geographic" || return stop("inapplicable", "non_geographic_space")
    # PowerIO: an absent geographic CRS means EPSG:4326.
    crs = get(geo, "crs", "EPSG:4326")
    crs isa AbstractString && !isempty(strip(crs)) || return stop("indeterminate", "invalid_powerio_geo")
    report["crs"] = crs
    _spatial_is_wgs84(crs) || return stop("inapplicable", "unsupported_crs")
    member = get(layer, "crs", nothing)
    member === nothing || _coordinate_crs(member) == "WGS84" ||
        return stop("indeterminate", "conflicting_crs_declaration")
    declared = [_coordinate_crs(last(row)) for row in _coordinate_declarations(net, _SPATIAL_CRS_KEYS)]
    all(==("WGS84"), declared) || return stop("indeterminate", "conflicting_crs_declaration")

    witness!(key, id) = (rows = get!(report["witnesses"], key, String[]);
                         length(rows) < limit && push!(rows, string(id)))
    finite_pair(v) = v isa AbstractVector && length(v) == 2 &&
        all(x -> x isa Real && !(x isa Bool) && isfinite(x), v)
    vertex(v) = finite_pair(v) ? _spatial_point(v[1], v[2]) : nothing

    # Group features by element kind and id; an id given twice is ambiguous.
    grouped = Dict{Tuple{String,String},Vector{Any}}()
    for feature in layer["features"]
        props = feature isa AbstractDict ? get(feature, "properties", nothing) : nothing
        geometry = feature isa AbstractDict ? get(feature, "geometry", nothing) : nothing
        fkind = props isa AbstractDict ? get(props, "kind", nothing) : nothing
        fid = props isa AbstractDict ? get(props, "id", nothing) : nothing
        gtype = geometry isa AbstractDict ? get(geometry, "type", nothing) : nothing
        if !(fid isa AbstractString && (fkind, gtype) in (("bus", "Point"), ("line", "LineString")))
            report["n_ignored_features"] += 1
            continue
        end
        push!(get!(grouped, (fkind, fid), Any[]), feature)
    end

    buses = get(net, "bus", Dict()); lines = get(net, "line", Dict())
    for ((fkind, fid), features) in sort!(collect(grouped), by=first)
        stats = report[fkind == "bus" ? "buses" : "lines"]
        stats["n_features"] += length(features)
        if length(features) > 1
            stats["n_duplicate_ids"] += 1; witness!("$(fkind)_duplicate_ids", fid)
            continue
        end
        feature = only(features)
        target = get(fkind == "bus" ? buses : lines, fid, nothing)
        if !(target isa AbstractDict)
            stats["n_unmatched"] += 1; witness!("$(fkind)_unmatched_ids", fid)
            continue
        end
        coordinates = get(feature["geometry"], "coordinates", nothing)
        if fkind == "bus"
            point = vertex(coordinates)
            if !_wgs84_point(point)
                stats["n_invalid"] += 1; witness!("bus_invalid_ids", fid)
            elseif !overwrite && (haskey(target, "longitude") || haskey(target, "latitude"))
                stats["n_kept_existing"] += 1
            else
                target["longitude"], target["latitude"] = point
                stats["n_applied"] += 1
            end
            continue
        end
        points = coordinates isa AbstractVector ? [vertex(v) for v in coordinates] : nothing
        if points === nothing || length(points) < 2 || !all(_wgs84_point, points)
            stats["n_invalid"] += 1; witness!("line_invalid_ids", fid)
            continue
        end
        props = feature["properties"]
        ends = (get(props, "bus_from", nothing), get(props, "bus_to", nothing))
        line_ends = (get(target, "bus_from", nothing), get(target, "bus_to", nothing))
        if any(!isnothing, ends) && !(ends == line_ends || reverse(ends) == line_ends)
            stats["n_endpoint_mismatch"] += 1; witness!("line_endpoint_mismatch_ids", fid)
            continue
        end
        meta = get!(target, "meta", Dict{String,Any}())
        if !(meta isa AbstractDict)
            stats["n_invalid"] += 1; witness!("line_invalid_ids", fid)
        elseif !overwrite && haskey(meta, "route_geometry")
            stats["n_kept_existing"] += 1
        else
            meta["route_geometry"] = Dict{String,Any}("basis" => "WGS84_geodesic_polyline",
                "coordinates" => [collect(p) for p in points],
                "length_m" => sum(_spatial_haversine(points[i-1], points[i]) for i in 2:length(points)))
            stats["n_applied"] += 1
        end
    end

    isempty(declared) || (report["crs_declaration"] = "existing")
    if report["buses"]["n_applied"] + report["lines"]["n_applied"] > 0
        meta = get!(net, "meta", Dict{String,Any}())
        if isempty(declared)
            meta["crs"] = crs
            report["crs_declaration"] = "added"
        end
        kind === nothing || isempty(_coordinate_declarations(net, ("coordinate_provenance",))) &&
            (meta["coordinate_provenance"] = kind)
    end
    report["status"] = "applied"
    report
end
