# sideload_coordinates_tests.jl
#
# Coverage for sideload_coordinates! — merges an OpenDSS-style Buscoords CSV
# (bus_id,x,y, no header) into a parsed network as GeoJSON Point geometry —
# and normalize_coordinates!, which upgrades legacy scalar longitude/latitude
# fields to the same GeoJSON "geo" representation. No solver required.

@testset "sideload_coordinates!" begin

    # write_csv(rows) → path to a temp CSV holding the given text lines.
    write_csv(lines) = (p = tempname() * ".csv";
                        open(io -> foreach(l -> println(io, l), lines), p, "w"); p)

    # geo helpers — coordinates are [lon, lat] (GeoJSON / RFC 7946 axis order).
    lon(bus) = bus["geo"]["coordinates"][1]
    lat(bus) = bus["geo"]["coordinates"][2]

    @testset "matches buses and stores a GeoJSON Point (x→lon, y→lat)" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "650, 100.0, 200.0",
            "632, 110.5, 205.5",
            "634, 120.0, 210.0",
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 3
        @test n_skipped == 0
        @test net["bus"]["650"]["geo"]["type"] == "Point"
        @test net["bus"]["650"]["geo"]["coordinates"] == [100.0, 200.0]
        @test lon(net["bus"]["650"]) == 100.0
        @test lat(net["bus"]["650"]) == 200.0
        @test lon(net["bus"]["632"]) == 110.5
    end

    @testset "rows for unknown buses are counted as skipped" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "650, 1.0, 2.0",
            "no_such_bus, 3.0, 4.0",   # not present in net → skipped
            "another_ghost, 5.0, 6.0", # skipped
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1
        @test n_skipped == 2
        @test haskey(net["bus"]["650"], "geo")   # 650 did get coords
    end

    @testset "blank, short and non-numeric rows are ignored (not skipped)" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "",                  # blank → continue
            "   ",               # whitespace-only → continue
            "650, 1.0",          # < 3 fields → continue
            "632, abc, 2.0",     # non-numeric x → continue
            "634, 3.0, xyz",     # non-numeric y → continue
            "671, 7.0, 8.0",     # the one good row
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1                       # only bus 671 matched
        @test n_skipped == 0                       # malformed rows are not "skipped"
        @test lon(net["bus"]["671"]) == 7.0
        @test !haskey(net["bus"]["650"], "geo")
    end

    @testset "missing file throws ArgumentError" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        @test_throws ArgumentError sideload_coordinates!(
            net, joinpath(tempdir(), "definitely_no_such_coords.csv"))
    end

    @testset "normalize_coordinates! upgrades legacy scalar lon/lat to geo" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        # Simulate a network produced by the pre-GeoJSON sideloader.
        net["bus"]["650"]["longitude"] = 100.0
        net["bus"]["650"]["latitude"]  = 200.0
        net["bus"]["632"]["longitude"] = 110.5
        net["bus"]["632"]["latitude"]  = 205.5

        n = BMOPFTools.normalize_coordinates!(net)
        @test n == 2
        @test net["bus"]["650"]["geo"] ==
              Dict{String,Any}("type" => "Point", "coordinates" => [100.0, 200.0])
        # legacy scalar fields are removed once folded in
        @test !haskey(net["bus"]["650"], "longitude")
        @test !haskey(net["bus"]["650"], "latitude")
    end

    @testset "normalize_coordinates! leaves an existing geo untouched" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["bus"]["650"]["geo"] =
            Dict{String,Any}("type" => "Point", "coordinates" => [1.0, 2.0])
        # a stray legacy field alongside geo is discarded, geo wins
        net["bus"]["650"]["longitude"] = 999.0
        net["bus"]["650"]["latitude"]  = 999.0

        n = BMOPFTools.normalize_coordinates!(net)
        @test n == 0                                   # geo already present → not upgraded
        @test net["bus"]["650"]["geo"]["coordinates"] == [1.0, 2.0]
        @test !haskey(net["bus"]["650"], "longitude")
        @test !haskey(net["bus"]["650"], "latitude")
    end

    @testset "geo geometry validates against the JSON Schema" begin
        # URI that _detect_spec_version maps to the bundled :draft schema, so
        # layer-1 JSONSchema validation actually runs.
        schema_uri = "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/schema/bmopf.json"
        with_schema(net) = (net["meta"] = get(net, "meta", Dict{String,Any}());
                            net["meta"]["\$schema"] = schema_uri; net)

        # Baseline: the bare fixture is schema-valid, so a geo failure below is
        # attributable to the geometry and nothing else.
        net0 = with_schema(parse_bmopf(IEEE13_FIXTURE; from_string=true))
        @test schema_check(net0, Finding[])["jsonschema_valid"] == true

        # Bus Point + line LineString + meta.crs → still valid.
        net = with_schema(parse_bmopf(IEEE13_FIXTURE; from_string=true))
        first_bus  = first(keys(net["bus"]))
        first_line = first(keys(net["line"]))
        net["bus"][first_bus]["geo"] =
            Dict{String,Any}("type" => "Point", "coordinates" => [151.207, -33.867])
        net["line"][first_line]["geo"] = Dict{String,Any}(
            "type" => "LineString",
            "coordinates" => [[151.207, -33.867], [151.209, -33.868], [151.210, -33.870]])
        net["meta"]["crs"] = "EPSG:4326"
        @test schema_check(net, Finding[])["jsonschema_valid"] == true

        # Malformed geo (wrong geometry type on a bus) → invalid.
        bad = with_schema(parse_bmopf(IEEE13_FIXTURE; from_string=true))
        bad["bus"][first(keys(bad["bus"]))]["geo"] =
            Dict{String,Any}("type" => "Polygon", "coordinates" => [[0.0, 0.0]])
        @test schema_check(bad, Finding[])["jsonschema_valid"] == false
    end

    @testset "network_to_geojson assembles a FeatureCollection" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv(["650, 100.0, 200.0", "632, 110.5, 205.5", "634, 120.0, 210.0"])
        sideload_coordinates!(net, path)

        fc = network_to_geojson(net)
        @test fc["type"] == "FeatureCollection"

        feats  = fc["features"]
        bykind(k) = filter(f -> f["properties"]["kind"] == k, feats)
        bus_feats  = bykind("bus")
        line_feats = bykind("line")

        # One Feature per placed bus (only 3 buses got coords).
        @test length(bus_feats) == 3
        b650 = only(filter(f -> f["properties"]["id"] == "650", bus_feats))
        @test b650["type"] == "Feature"
        @test b650["geometry"] == Dict{String,Any}("type" => "Point",
                                                    "coordinates" => [100.0, 200.0])

        # Lines whose endpoints are both placed get a derived straight LineString.
        derived = only(filter(f -> f["geometry"]["coordinates"] == [[100.0, 200.0], [110.5, 205.5]],
                              line_feats))
        @test derived["geometry"]["type"] == "LineString"
        @test derived["properties"]["bus_from"] == "650"
        @test derived["properties"]["bus_to"]   == "632"

        # No CRS foreign member for default WGS84.
        @test !haskey(fc, "crs")

        # include_lines=false → buses only.
        @test isempty(filter(f -> f["properties"]["kind"] == "line",
                             network_to_geojson(net; include_lines=false)["features"]))
    end

    @testset "network_to_geojson honours an explicit line geo and a projected CRS" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv(["650, 100.0, 200.0", "632, 110.5, 205.5"])
        sideload_coordinates!(net, path)

        # An explicit multi-vertex routing wins over the derived straight segment.
        line_id = first(keys(net["line"]))
        net["line"][line_id]["geo"] = Dict{String,Any}(
            "type" => "LineString",
            "coordinates" => [[1.0, 1.0], [2.0, 2.0], [3.0, 3.0]])

        net["meta"] = get(net, "meta", Dict{String,Any}())
        net["meta"]["crs"] = "EPSG:28356"    # projected (metres), non-WGS84

        fc = network_to_geojson(net)
        explicit = only(filter(f -> f["properties"]["id"] == line_id,
                               filter(f -> f["properties"]["kind"] == "line", fc["features"])))
        @test explicit["geometry"]["coordinates"] == [[1.0, 1.0], [2.0, 2.0], [3.0, 3.0]]
        # Non-WGS84 CRS is echoed as a top-level foreign member.
        @test fc["crs"] == "EPSG:28356"
    end
end
