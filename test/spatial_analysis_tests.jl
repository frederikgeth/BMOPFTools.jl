using Test, BMOPFTools, JSON3

@testset "conditional spatial analysis" begin
    bus(lon, lat) = Dict{String,Any}("longitude" => lon, "latitude" => lat)
    net = Dict{String,Any}(
        "bus" => Dict("a" => bus(153.0, -27.0), "b" => bus(153.001, -27.0)),
        "line" => Dict("short" => Dict{String,Any}(
            "bus_from" => "a", "bus_to" => "b", "length" => 20.0)),
        "transformer" => Dict("delta_wye" => Dict("t" => Dict{String,Any}(
            "bus_from" => "a", "bus_to" => "b"))))
    levels = Dict{String,Any}("levels" => Dict("LV" => Dict("buses" => ["a", "b"])))

    no_coords = deepcopy(net)
    for b in values(no_coords["bus"])
        delete!(b, "longitude"); delete!(b, "latitude")
    end
    @test BMOPFTools._spatial_analysis(no_coords, levels) === nothing
    @test !haskey(connectivity_analysis(no_coords, Finding[]; voltage_levels=levels), "spatial")

    # Plausible decimal-degree values alone are insufficient: OpenDSS x/y is
    # copied verbatim into these field names by sideload_coordinates!.
    unknown = BMOPFTools._spatial_analysis(net, levels)
    @test unknown["coordinate_reference"]["status"] == "unspecified"
    @test !unknown["coordinate_reference"]["geodesic_distances_applicable"]
    @test occursin("x/y", unknown["coordinate_reference"]["caution"])
    @test unknown["lines"]["n_with_chord_comparison"] == 0
    @test unknown["lines"]["n_shorter_than_chord_beyond_tolerance"] === nothing
    @test unknown["routes"]["n_endpoint_gaps_over_5m"] === nothing
    @test unknown["transformers"]["separation_m"]["n"] == 0
    @test unknown["lines"]["length_by_tier_m"]["LV"]["n"] == 1
    @test only(unknown["lines"]["relative_length_witnesses"])["relative_to_tier_p99"] == 1

    explicit = deepcopy(net)
    explicit["meta"] = Dict("crs" => "EPSG:4326")
    measured = BMOPFTools._spatial_analysis(explicit, levels)
    @test measured["coordinate_reference"]["status"] == "declared_wgs84"
    @test measured["lines"]["n_with_chord_comparison"] == 1
    @test measured["lines"]["n_shorter_than_chord_beyond_tolerance"] == 1
    @test measured["transformers"]["separation_m"]["max"] > 90
    @test measured["routes"]["n_endpoint_gaps_over_5m"] === nothing
    @test only(measured["lines"]["shorter_than_chord_witnesses"])["line_id"] == "short"
    @test connectivity_analysis(explicit, Finding[]; voltage_levels=levels)["spatial"]["coordinate_reference"]["status"] == "declared_wgs84"
    geo_findings = Finding[]
    connectivity_analysis(explicit, geo_findings; voltage_levels=levels)
    short_finding = only(filter(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", geo_findings))
    @test short_finding.component_id == "short"
    @test short_finding.detail["chord_m"] > short_finding.detail["length_m"]
    @test isempty(filter(f -> startswith(f.code, "W.GEO."),
                          let fs = Finding[]; connectivity_analysis(net, fs; voltage_levels=levels); fs end))
    boundary = deepcopy(explicit)
    boundary["line"]["short"]["length"] =
        measured["lines"]["shorter_than_chord_witnesses"][1]["chord_m"] -
        max(5.0, 0.1 * measured["lines"]["shorter_than_chord_witnesses"][1]["chord_m"])
    fs_boundary = Finding[]
    connectivity_analysis(boundary, fs_boundary; voltage_levels=levels)
    @test !any(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", fs_boundary)

    route_case = deepcopy(net)
    route_case["line"]["short"]["meta"] = Dict("route_geometry" => Dict(
        "basis" => "WGS84_geodesic_polyline",
        "coordinates" => [[153.0, -27.0], [153.001, -27.0]],
        "length_m" => 20.0))
    route = BMOPFTools._spatial_analysis(route_case, levels)
    @test route["coordinate_reference"]["status"] == "wgs84_route_evidence"
    @test route["coordinate_reference"]["n_matching_wgs84_routes"] == 1
    @test route["lines"]["n_with_chord_comparison"] == 1
    mixed = deepcopy(route_case)
    mixed["line"]["other"] = Dict{String,Any}(
        "bus_from" => "a", "bus_to" => "b", "length" => 20.0,
        "meta" => Dict("route_geometry" => Dict(
            "basis" => "unspecified", "coordinates" => [[153.0, -27.0], [153.001, -27.0]])))
    @test BMOPFTools._spatial_analysis(mixed, levels)["coordinate_reference"]["status"] == "unspecified"

    # A route declaration without matched endpoints does not establish a
    # network-wide coordinate frame; an explicit non-WGS CRS overrides it.
    route_case["line"]["short"]["meta"]["route_geometry"]["coordinates"] =
        [[153.01, -27.0], [153.011, -27.0]]
    @test BMOPFTools._spatial_analysis(route_case, levels)["coordinate_reference"]["status"] == "unspecified"
    unverified_route_findings = Finding[]
    BMOPFTools._spatial_analysis(route_case, levels, unverified_route_findings)
    @test !any(f -> startswith(f.code, "W.GEO."), unverified_route_findings)
    route_case["meta"] = Dict("coordinate_system" => "EPSG:28356")
    @test BMOPFTools._spatial_analysis(route_case, levels)["lines"]["n_with_chord_comparison"] == 0
    route_case["meta"]["coordinate_system"] = "WGS84"
    gaps = BMOPFTools._spatial_analysis(route_case, levels)
    @test gaps["routes"]["n_endpoint_gaps_over_5m"] == 1
    @test gaps["routes"]["n_endpoint_comparisons"] == 1
    @test gaps["routes"]["n_length_comparisons"] == 1
    route_findings = Finding[]
    connectivity_analysis(route_case, route_findings; voltage_levels=levels)
    @test only(filter(f -> f.code == "W.GEO.ROUTE_ENDPOINT_GAP", route_findings)).detail["gap_m"] > 20
    near_route = deepcopy(route_case)
    near_route["line"]["short"]["meta"]["route_geometry"]["coordinates"] =
        [[153.0, -27.0 + 19.9 / 111_195], [153.001, -27.0 + 19.9 / 111_195]]
    near_route_findings = Finding[]
    BMOPFTools._spatial_analysis(near_route, levels, near_route_findings)
    @test !any(f -> f.code == "W.GEO.ROUTE_ENDPOINT_GAP", near_route_findings)

    # Partial, projected-looking, and non-finite values are counted but never
    # fed to a geodesic distance formula.
    bad = deepcopy(explicit)
    bad["bus"]["a"]["longitude"] = 500_000.0
    delete!(bad["bus"]["b"], "latitude")
    rejected = BMOPFTools._spatial_analysis(bad, levels)
    @test rejected["coordinate_coverage"]["n_outside_wgs84_range"] == 1
    @test rejected["coordinate_coverage"]["n_partial"] == 1
    @test rejected["lines"]["n_with_chord_comparison"] == 0
    range_findings = Finding[]
    connectivity_analysis(bad, range_findings; voltage_levels=levels)
    @test only(filter(f -> f.code == "W.GEO.WGS84_RANGE", range_findings)).component_id == "a"
    range_boundary = Dict{String,Any}("bus" => Dict("edge" => bus(180.0, 90.0)),
        "meta" => Dict("crs" => "WGS84"))
    boundary_findings = Finding[]
    BMOPFTools._spatial_analysis(range_boundary, Dict{String,Any}(), boundary_findings)
    @test !any(f -> f.code == "W.GEO.WGS84_RANGE", boundary_findings)
    range_boundary["bus"]["edge"]["longitude"] = 180.001
    BMOPFTools._spatial_analysis(range_boundary, Dict{String,Any}(), boundary_findings)
    @test only(filter(f -> f.code == "W.GEO.WGS84_RANGE", boundary_findings)).component_id == "edge"
    bad["bus"]["a"]["longitude"] = Inf
    @test BMOPFTools._spatial_analysis(bad, levels)["coordinate_coverage"]["n_invalid"] == 1
    bad["bus"]["a"]["longitude"] = true
    @test BMOPFTools._spatial_analysis(bad, levels)["coordinate_coverage"]["n_invalid"] == 1

    xy = Dict{String,Any}("bus" => Dict("a" => Dict("x" => 100.0, "y" => 20.0)))
    xy_result = BMOPFTools._spatial_analysis(xy, Dict{String,Any}())
    @test xy_result["coordinate_coverage"]["n_with_xy_fields"] == 1
    @test xy_result["coordinate_reference"]["status"] == "unspecified"

    roundtrip = JSON3.read(JSON3.write(BMOPFTools._jsonable(measured)))
    @test roundtrip.lines.n_shorter_than_chord_beyond_tolerance == 1
    @test roundtrip.coordinate_reference.status == "declared_wgs84"
    finding_roundtrip = JSON3.read(JSON3.write(BMOPFTools._jsonable(short_finding.detail)))
    @test finding_roundtrip.chord_m > finding_roundtrip.length_m
end
