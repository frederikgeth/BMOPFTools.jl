"""
    sideload_coordinates!(net, csv_path) -> (n_matched, n_skipped)

Read a OpenDSS-style bus coordinate CSV (`bus_id,x,y`, no header) and attach a
GeoJSON (RFC 7946) `Point` geometry to matching bus objects in `net` under the
`"geo"` key: `Dict("type" => "Point", "coordinates" => [x, y])`.

Returns the number of buses matched and the number of CSV rows skipped
because the bus ID was not present in `net` (open-switch stub buses and
synthetic slack buses are the usual cause).

The CSV x column is written as the first (longitude) coordinate and y as the
second (latitude) — the `[lon, lat]` axis order mandated by GeoJSON and used by
OpenDSS `Buscoords` (x) / `LatLongCoords` (Longitude→x). No coordinate-system
transformation is performed; values are stored as-is and interpreted in the
CRS declared by `net["meta"]["crs"]` (WGS84 when absent).
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
            bus["geo"] = Dict{String,Any}("type" => "Point", "coordinates" => [lon, lat])
            n_matched += 1
        else
            n_skipped += 1
        end
    end
    return n_matched, n_skipped
end

"""
    normalize_coordinates!(net) -> Int

Upgrade legacy scalar `"longitude"`/`"latitude"` bus fields (the pre-GeoJSON
representation) into a GeoJSON `"geo"` Point, in place.  A bus that already
carries a `"geo"` object is left untouched; the legacy scalar fields are
removed once folded in.  Returns the number of buses upgraded.

Call this after loading a network that may have been produced by an older
`sideload_coordinates!` so downstream code can rely on the `"geo"` field alone.
"""
function normalize_coordinates!(net::Dict{String,Any})
    buses = get(net, "bus", Dict())
    n_upgraded = 0
    for (_, bus) in buses
        bus isa Dict || continue
        haskey(bus, "geo") && (delete!(bus, "longitude"); delete!(bus, "latitude"); continue)
        (haskey(bus, "longitude") && haskey(bus, "latitude")) || continue
        lon = bus["longitude"]
        lat = bus["latitude"]
        bus["geo"] = Dict{String,Any}("type" => "Point", "coordinates" => [lon, lat])
        delete!(bus, "longitude")
        delete!(bus, "latitude")
        n_upgraded += 1
    end
    return n_upgraded
end

"""
    network_to_geojson(net; include_lines=true) -> Dict{String,Any}

Assemble a GeoJSON (RFC 7946) `FeatureCollection` from the `"geo"` geometry
attached to a network's buses and lines, ready to serialise (e.g. with
`JSON3.write`) and drop into any GIS/mapping tool.

Each bus carrying a `"geo"` Point becomes a `Feature` with
`properties.kind == "bus"`; each line becomes a `Feature` with
`properties.kind == "line"` (plus `bus_from`/`bus_to` when present).  When
`include_lines` is true and a line has no explicit `"geo"`, a straight
two-vertex `LineString` is synthesised from its endpoint buses' Point
coordinates — the same convention OpenDSS uses when drawing lines from bus
coordinates alone.  Buses and lines are emitted in sorted-id order so the
output is deterministic.

Geometry is copied by reference from the elements, so coordinates are in the
CRS declared by `net["meta"]["crs"]`.  When that CRS is present and is **not**
WGS84 (`EPSG:4326`), it is echoed as a top-level `"crs"` foreign member — a
deliberate departure from strict RFC 7946, which mandates WGS84; consumers that
ignore the member will misplace projected coordinates, so keep the network in
WGS84 for maximal interoperability.
"""
function network_to_geojson(net::Dict{String,Any}; include_lines::Bool=true)
    features  = Vector{Any}()
    buscoords = Dict{String,Vector}()   # bus id → Point coordinates, for line derivation

    buses = get(net, "bus", Dict())
    for id in sort(collect(keys(buses)))
        bus = buses[id]
        bus isa Dict || continue
        geo = get(bus, "geo", nothing)
        geo isa Dict || continue
        push!(features, Dict{String,Any}(
            "type"       => "Feature",
            "geometry"   => geo,
            "properties" => Dict{String,Any}("id" => id, "kind" => "bus")))
        get(geo, "type", nothing) == "Point" && (buscoords[id] = geo["coordinates"])
    end

    if include_lines
        lines = get(net, "line", Dict())
        for id in sort(collect(keys(lines)))
            line = lines[id]
            line isa Dict || continue
            bf  = get(line, "bus_from", nothing)
            bt  = get(line, "bus_to", nothing)
            geo = get(line, "geo", nothing)
            if !(geo isa Dict)
                # No explicit routing → derive a straight segment if both ends are placed.
                (haskey(buscoords, bf) && haskey(buscoords, bt)) || continue
                geo = Dict{String,Any}("type" => "LineString",
                                       "coordinates" => [buscoords[bf], buscoords[bt]])
            end
            props = Dict{String,Any}("id" => id, "kind" => "line")
            bf === nothing || (props["bus_from"] = bf)
            bt === nothing || (props["bus_to"]   = bt)
            push!(features, Dict{String,Any}(
                "type" => "Feature", "geometry" => geo, "properties" => props))
        end
    end

    fc  = Dict{String,Any}("type" => "FeatureCollection", "features" => features)
    crs = get(get(net, "meta", Dict()), "crs", nothing)
    if crs isa AbstractString && uppercase(crs) != "EPSG:4326"
        fc["crs"] = crs
    end
    return fc
end
