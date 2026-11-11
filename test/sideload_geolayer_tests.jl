# sideload_geolayer! applies the GeoJSON layer that PowerIO stores in
# extras.geojson to bus longitude/latitude and line route geometry. The
# witness is a synthetic three-bus feeder with made-up coordinates near
# (10 E, 50 N); it is built inline so the test owns every value.
using Test, BMOPFTools, JSON3

function _geolayer_witness(; geo=Dict{String,Any}("space" => "geographic",
                                                  "crs" => "EPSG:4326", "kind" => "source"))
    bus(id, x, y) = Dict{String,Any}("type" => "Feature",
        "properties" => Dict{String,Any}("id" => id, "kind" => "bus"),
        "geometry" => Dict{String,Any}("type" => "Point", "coordinates" => [x, y]))
    route(id, a, b, pts) = Dict{String,Any}("type" => "Feature",
        "properties" => Dict{String,Any}("id" => id, "kind" => "line",
                                         "bus_from" => a, "bus_to" => b),
        "geometry" => Dict{String,Any}("type" => "LineString", "coordinates" => pts))
    layer = Dict{String,Any}("type" => "FeatureCollection", "features" => Any[
        bus("a", 10.0, 50.0), bus("b", 10.001, 50.0), bus("c", 10.001, 50.001),
        route("ab", "a", "b", [[10.0, 50.0], [10.0005, 50.0], [10.001, 50.0]]),
        route("bc", "b", "c", [[10.001, 50.0], [10.001, 50.001]])])
    geo === nothing || (layer["powerio_geo"] = geo)
    term = Dict{String,Any}("terminal_names" => ["1", "4"])
    # Declared lengths match the geodesic routes (about 71.5 m and 111.2 m).
    line(a, b, len) = Dict{String,Any}("bus_from" => a, "bus_to" => b,
        "terminal_map_from" => ["1", "4"], "terminal_map_to" => ["1", "4"],
        "linecode" => "lc", "length" => len)
    Dict{String,Any}(
        "name" => "geolayer witness",
        "terminal_conventions" => Dict{String,Any}("phase" => ["1"], "neutral" => ["4"]),
        "bus" => Dict{String,Any}("a" => merge(copy(term),
                Dict{String,Any}("perfectly_grounded_terminals" => ["4"])),
            "b" => copy(term), "c" => copy(term)),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}("bus" => "a",
            "terminal_map" => ["1"], "v_magnitude" => [230.0], "v_angle" => [0.0])),
        "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
            "R_series_1_1" => 1e-3, "R_series_2_2" => 1e-3,
            "X_series_1_1" => 1e-3, "X_series_2_2" => 1e-3)),
        "line" => Dict{String,Any}("ab" => line("a", "b", 71.5), "bc" => line("b", "c", 111.2)),
        "load" => Dict{String,Any}("l" => Dict{String,Any}("bus" => "c",
            "terminal_map" => ["1", "4"], "configuration" => "SINGLE_PHASE",
            "p_nom" => [1000.0], "q_nom" => [100.0])),
        "extras" => Dict{String,Any}("geojson" => layer))
end

_features(net) = net["extras"]["geojson"]["features"]
_untouched(net) = all(b -> !haskey(b, "longitude") && !haskey(b, "latitude"), values(net["bus"])) &&
    all(l -> !haskey(get(l, "meta", Dict()), "route_geometry"), values(net["line"])) &&
    !haskey(get(net, "meta", Dict()), "crs")

@testset "sideload_geolayer!" begin
    parse(net) = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)

    @testset "Geographic WGS84 layer" begin
        net = parse(_geolayer_witness())
        @test parse(_geolayer_witness())["extras"]["geojson"]["powerio_geo"]["space"] == "geographic"
        @test BMOPFTools.connectivity_analysis(net, BMOPFTools.Finding[])["spatial"]["reason"] ==
              "unapplied_geolayer"
        report = sideload_geolayer!(net)
        @test report["status"] == "applied" && report["reason"] === nothing
        @test report["crs"] == "EPSG:4326" && report["crs_declaration"] == "added"
        @test report["buses"]["n_applied"] == 3 && report["lines"]["n_applied"] == 2
        @test (net["bus"]["b"]["longitude"], net["bus"]["b"]["latitude"]) == (10.001, 50.0)
        route = net["line"]["ab"]["meta"]["route_geometry"]
        @test route["basis"] == "WGS84_geodesic_polyline"
        @test route["coordinates"] == [[10.0, 50.0], [10.0005, 50.0], [10.001, 50.0]]
        @test route["length_m"] ≈ BMOPFTools._spatial_haversine((10.0, 50.0), (10.001, 50.0)) rtol=1e-9
        @test net["meta"]["crs"] == "EPSG:4326"
        @test net["meta"]["coordinate_provenance"] == "source"
        @test haskey(net["extras"], "geojson")
        spatial = analyze(net).results[:connectivity]["spatial"]
        @test spatial["coordinate_reference"]["status"] == "declared_wgs84"
        @test spatial["coordinate_semantics"]["n_metric_eligible_buses"] == 3
        @test spatial["routes"]["n_with_route"] == 2
        @test spatial["routes"]["n_length_mismatches"] == 0
    end

    @testset "Layers that are not applied" begin
        cases = (
            (Dict{String,Any}("space" => "projected", "crs" => "EPSG:32617"), "inapplicable", "non_geographic_space"),
            (Dict{String,Any}("space" => "diagram"), "inapplicable", "non_geographic_space"),
            (Dict{String,Any}("space" => "unknown"), "inapplicable", "non_geographic_space"),
            (Dict{String,Any}("space" => "geographic", "crs" => "EPSG:4269"), "inapplicable", "unsupported_crs"),
            (nothing, "indeterminate", "missing_powerio_geo"),
            (Dict{String,Any}("crs" => "EPSG:4326"), "indeterminate", "invalid_powerio_geo"),
            (Dict{String,Any}("space" => "geographic", "crs" => 4326), "indeterminate", "invalid_powerio_geo"),
            (Dict{String,Any}("space" => "geographic", "kind" => 1), "indeterminate", "invalid_powerio_geo"))
        for (geo, status, reason) in cases
            net = parse(_geolayer_witness(geo=geo))
            report = sideload_geolayer!(net)
            @test (report["status"], report["reason"]) == (status, reason)
            @test _untouched(net)
        end
        net = parse(_geolayer_witness())
        get!(net, "meta", Dict{String,Any}())["crs"] = "EPSG:3857"
        @test sideload_geolayer!(net)["reason"] == "conflicting_crs_declaration"
        @test !any(b -> haskey(b, "longitude"), values(net["bus"]))
        net = parse(_geolayer_witness())
        net["extras"]["geojson"]["crs"] = "EPSG:3857"
        @test sideload_geolayer!(net)["reason"] == "conflicting_crs_declaration"
        net = parse(_geolayer_witness()); delete!(net, "extras")
        @test sideload_geolayer!(net)["reason"] == "no_geolayer"
        @test !haskey(BMOPFTools.connectivity_analysis(net, BMOPFTools.Finding[]), "spatial")
        net = parse(_geolayer_witness()); net["extras"]["geojson"]["features"] = "none"
        @test sideload_geolayer!(net)["reason"] == "invalid_feature_collection"
    end

    @testset "Feature matching boundaries" begin
        # An absent geographic CRS means EPSG:4326 (PowerIO's declaration).
        net = parse(_geolayer_witness(geo=Dict{String,Any}("space" => "geographic")))
        report = sideload_geolayer!(net)
        @test report["crs"] == "EPSG:4326" && report["buses"]["n_applied"] == 3
        @test !haskey(net["meta"], "coordinate_provenance")
        # An existing equivalent CRS declaration is kept.
        net = parse(_geolayer_witness()); get!(net, "meta", Dict{String,Any}())["crs"] = "WGS84"
        @test sideload_geolayer!(net)["crs_declaration"] == "existing"
        @test net["meta"]["crs"] == "WGS84"
        net = parse(_geolayer_witness())
        f = _features(net)
        f[1]["properties"]["id"] = "missing"                       # unmatched bus
        f[2]["geometry"]["coordinates"] = [10.0, 95.0]              # latitude out of range
        push!(f, deepcopy(f[3]))                                    # duplicate bus id "c"
        f[4]["properties"]["bus_from"], f[4]["properties"]["bus_to"] = "b", "a"   # reversed: accepted
        f[5]["properties"]["bus_to"] = "a"                          # wrong endpoints
        push!(f, Dict{String,Any}("type" => "Feature", "properties" => Dict("id" => "x", "kind" => "switch"),
                                  "geometry" => Dict("type" => "Point", "coordinates" => [10.0, 50.0])))
        report = sideload_geolayer!(net)
        @test report["buses"]["n_features"] == 4
        @test report["buses"]["n_unmatched"] == 1 && report["buses"]["n_invalid"] == 1
        @test report["buses"]["n_duplicate_ids"] == 1 && report["buses"]["n_applied"] == 0
        @test report["lines"]["n_applied"] == 1 && report["lines"]["n_endpoint_mismatch"] == 1
        @test report["n_ignored_features"] == 1
        @test report["witnesses"]["bus_unmatched_ids"] == ["missing"]
        @test report["witnesses"]["line_endpoint_mismatch_ids"] == ["bc"]
        @test !any(b -> haskey(b, "longitude"), values(net["bus"]))
        @test haskey(net["line"]["ab"]["meta"], "route_geometry")
        @test !haskey(get(net["line"]["bc"], "meta", Dict()), "route_geometry")
        # A one-vertex route and a non-numeric vertex are invalid.
        net = parse(_geolayer_witness())
        _features(net)[4]["geometry"]["coordinates"] = [[10.0, 50.0]]
        _features(net)[5]["geometry"]["coordinates"] = [[10.001, 50.0], ["x", 50.001]]
        @test sideload_geolayer!(net)["lines"]["n_invalid"] == 2
        # Existing positions and routes are kept unless overwrite=true.
        net = parse(_geolayer_witness())
        net["bus"]["a"]["longitude"] = 11.0; net["bus"]["a"]["latitude"] = 51.0
        net["line"]["ab"]["meta"] = Dict{String,Any}("route_geometry" => Dict{String,Any}("basis" => "other"))
        report = sideload_geolayer!(net)
        @test report["buses"]["n_kept_existing"] == 1 && report["lines"]["n_kept_existing"] == 1
        @test net["bus"]["a"]["longitude"] == 11.0
        report = sideload_geolayer!(net; overwrite=true)
        @test report["buses"]["n_applied"] == 3 && net["bus"]["a"]["longitude"] == 10.0
        @test net["line"]["ab"]["meta"]["route_geometry"]["basis"] == "WGS84_geodesic_polyline"
        # A layer that matches nothing declares nothing.
        net = parse(_geolayer_witness())
        for feature in _features(net)
            feature["properties"]["id"] = "z" * feature["properties"]["id"]
        end
        report = sideload_geolayer!(net)
        @test (report["status"], report["reason"]) == ("indeterminate", "no_features_applied")
        @test report["crs_declaration"] === nothing
        @test report["buses"]["n_unmatched"] == 3 && report["lines"]["n_unmatched"] == 2
        @test _untouched(net)
        # A legacy GeoJSON named-CRS member naming WGS84 is not a conflict.
        for name in ("urn:ogc:def:crs:OGC:1.3:CRS84", "urn:ogc:def:crs:EPSG::4326", "EPSG:4326")
            net = parse(_geolayer_witness())
            net["extras"]["geojson"]["crs"] = Dict{String,Any}("type" => "name",
                "properties" => Dict{String,Any}("name" => name))
            @test sideload_geolayer!(net)["status"] == "applied"
        end
        net = parse(_geolayer_witness())
        net["extras"]["geojson"]["crs"] = Dict{String,Any}("type" => "name",
            "properties" => Dict{String,Any}("name" => "urn:ogc:def:crs:EPSG::3857"))
        @test sideload_geolayer!(net)["reason"] == "conflicting_crs_declaration"
    end

    @testset "GeoLayer written by PowerIO" begin
        # Regenerate with scripts/regenerate_powerio_geolayer.jl.
        net = BMOPFTools.parse_bmopf(joinpath(@__DIR__, "data", "powerio_geolayer_bmopf.json"))
        @test !any(b -> haskey(b, "longitude"), values(net["bus"]))
        report = sideload_geolayer!(net)
        @test report["status"] == "applied"
        @test report["coordinate_provenance"] == "source"
        @test report["buses"]["n_applied"] == 3 && report["lines"]["n_applied"] == 2
        @test report["n_ignored_features"] == 0
        @test (net["bus"]["a"]["longitude"], net["bus"]["a"]["latitude"]) == (10.0, 50.0)
        @test net["line"]["bc"]["meta"]["route_geometry"]["coordinates"] ==
              [[10.001, 50.0], [10.001, 50.001]]
    end

    @testset "Serialization" begin
        net = parse(_geolayer_witness())
        report = sideload_geolayer!(net)
        @test JSON3.read(JSON3.write(report), Dict{String,Any}) == report
        path = joinpath(mktempdir(), "geo.json")
        write_bmopf(net, path)
        roundtrip = BMOPFTools.parse_bmopf(path)
        @test roundtrip["bus"]["c"]["latitude"] == 50.001
        @test roundtrip["line"]["bc"]["meta"]["route_geometry"]["coordinates"] ==
              [[10.001, 50.0], [10.001, 50.001]]
        @test roundtrip["meta"]["crs"] == "EPSG:4326"
        again = sideload_geolayer!(roundtrip)
        @test again["buses"]["n_kept_existing"] == 3 && again["lines"]["n_kept_existing"] == 2
        @test again["crs_declaration"] == "existing"
    end
end
