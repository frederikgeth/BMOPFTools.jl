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
