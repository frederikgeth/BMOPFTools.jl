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

@testset "contextual exact coincidence and transformer extent" begin
    net = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_context.json"), String), Dict{String,Any})
    original = deepcopy(net)
    levels = Dict{String,Any}("levels" => Dict(
        "MV" => Dict("buses" => ["hv", "tertiary"]), "LV" => Dict("buses" => ["lv"])))
    fs = Finding[]
    spatial = BMOPFTools._spatial_analysis(net, levels, fs)
    c = spatial["coincidence"]
    @test c["n_groups"] == 3
    @test c["n_buses_in_groups"] == 6
    @test c["context_counts"] == Dict("transformer_ports" => 1, "open_switch" => 1, "no_direct_branch" => 1)
    onsite = only(filter(w -> w["anchor_bus"] == "hv", c["witnesses"]))
    @test onsite["n_internal_components"] == 2
    @test [b["voltage_tier"] for b in onsite["buses"]] == ["MV", "LV"]
    @test onsite["buses"][2]["terminal_names"] == ["1", "2", "3", "4"]
    @test onsite["internal_components"][1]["ports"][2]["terminal_map"] == ["1", "2", "3", "4"]
    @test isempty(fs) # Coincidence itself never warns, including unlinked buses.
    @test net == original
    xf = spatial["transformers"]
    @test xf["n_assessed"] == 2
    @test xf["n_zero_extent"] == 1
    @test xf["separation_m"]["max"] > 90
    @test first(xf["farthest_witnesses"])["winding_buses"] == ["hv", "lv", "tertiary"]

    # Greatest separation need not include winding 1.
    net["bus"]["lv"]["longitude"] = 152.999
    spread = BMOPFTools._spatial_analysis(net, levels)["transformers"]
    @test first(spread["farthest_witnesses"])["farthest_bus_pair"] == ["lv", "tertiary"]
    delete!(net["bus"]["tertiary"], "latitude")
    partial = BMOPFTools._spatial_analysis(net, levels)["transformers"]
    @test partial["n_assessed"] == 1
    @test partial["n_indeterminate"] == 1
    @test only(partial["indeterminate_witnesses"])["status"] == "indeterminate"

    # Almost equal coordinates are deliberately not snapped.
    net = deepcopy(original)
    net["bus"]["unlinked_b"]["longitude"] = nextfloat(net["bus"]["unlinked_a"]["longitude"])
    @test BMOPFTools._spatial_analysis(net, levels)["coincidence"]["n_groups"] == 2
    net = deepcopy(original)
    delete!(net, "meta")
    unknown = BMOPFTools._spatial_analysis(net, levels)
    @test unknown["coincidence"]["n_groups"] == 3
    @test unknown["transformers"]["n_assessed"] == 0
    @test unknown["transformers"]["n_indeterminate"] == 2
    net["switch"]["tie"]["open_switch"] = false
    @test BMOPFTools._spatial_analysis(net, levels)["coincidence"]["context_counts"]["closed_switch"] == 1
    delete!(net["switch"]["tie"], "open_switch")
    @test BMOPFTools._spatial_analysis(net, levels)["coincidence"]["context_counts"]["unknown_switch_state"] == 1

    # x/y equality is available without a metric interpretation, and stays in
    # a separate field family even if the numeric tuples equal lon/lat tuples.
    xy = Dict{String,Any}("bus" => Dict(
        "a" => Dict("x" => 1.0, "y" => 2.0), "b" => Dict("x" => 1.0, "y" => 2.0),
        "c" => Dict("longitude" => 1.0, "latitude" => 2.0),
        "invalid" => Dict("longitude" => true, "latitude" => 2.0)))
    xy_c = BMOPFTools._spatial_analysis(xy, levels)["coincidence"]
    @test xy_c["n_groups"] == 1
    @test xy_c["n_eligible_buses"] == 3
    @test only(xy_c["witnesses"])["coordinate_fields"] == "xy"

    # Bound member output and retain exact totals, independently of input order.
    many = Dict{String,Any}("bus" => Dict(string(i) => Dict("longitude" => 1.0, "latitude" => 2.0) for i in 1:30))
    many_c = BMOPFTools._spatial_analysis(many, levels)["coincidence"]
    @test many_c["n_buses_in_groups"] == 30
    @test length(only(many_c["witnesses"])["buses"]) == 20
    @test only(many_c["witnesses"])["members_truncated"]
    many["bus"] = Dict(reverse(collect(many["bus"])))
    @test BMOPFTools._spatial_analysis(many, levels)["coincidence"] == many_c
    rt = JSON3.read(JSON3.write(BMOPFTools._jsonable(spatial)))
    @test rt.coincidence.context_counts.open_switch == 1
    @test rt.transformers.n_zero_extent == 1
    io = IOBuffer()
    BMOPFTools._md_spatial(spatial, io)
    md = String(take!(io))
    @test occursin("Exact coordinate coincidence: 3 groups", md)
    @test occursin("open_switch", md)
    @test occursin("2/2 assessed", md)
end
