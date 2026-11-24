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

@testset "physical and electrical length evidence" begin
    bus(x) = Dict{String,Any}("longitude" => x, "latitude" => -27.0)
    a, b = [153.0, -27.0], [153.001, -27.0]
    chord = BMOPFTools._spatial_haversine(a, b)
    net = Dict{String,Any}("meta" => Dict("crs" => "WGS84"),
        "bus" => Dict("a" => bus(a[1]), "b" => bus(b[1])),
        "line" => Dict("section" => Dict{String,Any}(
            "bus_from" => "a", "bus_to" => "b", "length" => 1.0,
            "linecode" => "cable", "meta" => Dict{String,Any}(
                "electrical_length_regularized" => true, "physical_length_m" => chord,
                "raw_key" => "synthetic:section",
                "route_geometry" => Dict{String,Any}("basis" => "WGS84_geodesic_polyline",
                    "coordinates" => [a, b], "length_m" => chord)))))
    levels = Dict{String,Any}()
    function report(net)
        fs = Finding[]
        r = BMOPFTools._spatial_analysis(net, levels, fs)
        r, fs
    end
    r, fs = report(net)
    ctx = r["length_context"]
    row = only(ctx["witnesses"])
    @test isempty(fs)
    @test row["comparison_basis"] == "physical_length_m"
    @test row["comparison_length_m"] ≈ chord
    @test row["declared_length_m"] == 1.0
    @test row["route_length_check"]["status"] == "passed"
    @test row["physical_route_check"]["status"] == "passed"
    @test row["declared_physical_check"]["status"] == "failed"
    @test row["source_references"]["raw_key"] == "synthetic:section"
    @test ctx["comparison_status_counts"]["chord_check"]["passed"] == 1
    @test row["length_scales_impedance"]
    @test ctx["context_counts"]["regularized_electrical_length"] == 1

    # A valid physical length is checked even when declared electrical length
    # is long enough, and invalid explicit metadata never silently falls back.
    short = deepcopy(net)
    short["line"]["section"]["length"] = 200.0
    short["line"]["section"]["meta"]["physical_length_m"] = 1.0
    r, fs = report(short)
    finding = only(filter(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", fs))
    @test finding.detail["comparison_basis"] == "physical_length_m"
    @test finding.detail["comparison_length_m"] == 1.0
    @test finding.detail["length_m"] == 200.0
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(finding.detail))).physical_length_m == 1.0
    for invalid in (true, -1.0, Inf, "100 metres")
        bad = deepcopy(net)
        bad["line"]["section"]["meta"]["physical_length_m"] = invalid
        r, fs = report(bad)
        @test isempty(fs)
        @test r["length_context"]["comparison_status_counts"]["chord_check"]["indeterminate"] == 1
        @test r["length_context"]["context_counts"]["invalid_length_declaration"] == 1
        @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).length_context.witnesses[1].physical_length_m === nothing
    end
    missing = deepcopy(net)
    delete!(missing["line"]["section"]["meta"], "physical_length_m")
    r, fs = report(missing)
    @test isempty(fs)
    @test only(r["length_context"]["witnesses"])["comparison_basis"] == "unavailable"
    @test r["length_context"]["comparison_status_counts"]["chord_check"]["indeterminate"] == 1

    # Strict lower-bound and symmetric-comparison boundaries.
    tolerance = max(5.0, 0.1 * chord)
    boundary = deepcopy(net)
    boundary["line"]["section"]["meta"]["physical_length_m"] = chord - tolerance
    @test isempty(last(report(boundary)))
    boundary["line"]["section"]["meta"]["physical_length_m"] -= 1e-6
    @test any(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", last(report(boundary)))
    @test BMOPFTools._spatial_length_comparison(105.0, 100.0)["status"] == "passed"
    @test BMOPFTools._spatial_length_comparison(110.0, 100.0)["status"] == "passed"
    @test BMOPFTools._spatial_length_comparison(nextfloat(110.0), 100.0)["status"] == "failed"

    reversed = deepcopy(net)
    reverse!(reversed["line"]["section"]["meta"]["route_geometry"]["coordinates"])
    @test first(report(reversed))["length_context"] == first(report(net))["length_context"]
    route_bad = deepcopy(net)
    route_bad["line"]["section"]["meta"]["route_geometry"]["coordinates"] = [a, [NaN, -27.0], b]
    r, fs = report(route_bad)
    @test r["length_context"]["context_counts"]["invalid_route_geometry"] == 1
    @test only(r["length_context"]["witnesses"])["route_length_check"]["status"] == "indeterminate"
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).length_context.witnesses[1].recomputed_route_length_m === nothing
    malformed = deepcopy(net)
    malformed["line"]["section"]["meta"]["route_geometry"] = "not a route object"
    @test first(report(malformed))["length_context"]["context_counts"]["invalid_route_geometry"] == 1
    for invalid in (true, -10.0, Inf)
        bad = deepcopy(net)
        bad["line"]["section"]["meta"]["route_geometry"]["length_m"] = invalid
        r, _ = report(bad)
        @test r["routes"]["n_length_comparisons"] == 0
        @test only(r["length_context"]["witnesses"])["route_length_check"]["status"] == "indeterminate"
        @test r["length_context"]["context_counts"]["invalid_route_length"] == 1
    end
    mismatch = deepcopy(net)
    mismatch["line"]["section"]["meta"]["route_geometry"]["length_m"] = 200.0
    @test first(report(mismatch))["length_context"]["context_counts"]["stored_route_length_mismatch"] == 1

    # Route evidence has endpoint scope, including transformer extent. It does
    # not establish the frame of a distant, unrelated coordinate pair.
    scoped = deepcopy(net)
    delete!(scoped, "meta")
    scoped["bus"]["c"] = bus(154.0)
    scoped["bus"]["d"] = bus(154.001)
    scoped["line"]["unrelated"] = Dict{String,Any}("bus_from" => "c", "bus_to" => "d", "length" => 1.0)
    scoped["transformer"] = Dict("delta_wye" => Dict("unrelated" => Dict("bus_from" => "c", "bus_to" => "d")))
    r, fs = report(scoped)
    @test isempty(fs)
    @test r["coordinate_reference"]["n_metric_eligible_buses"] == 2
    @test r["coordinate_reference"]["distance_scope"] == "matched_route_endpoints_only"
    @test r["lines"]["n_with_chord_comparison"] == 1
    @test r["transformers"]["n_indeterminate"] == 1
    @test r["length_context"]["comparison_status_counts"]["chord_check"]["indeterminate"] == 1
    scoped["meta"] = Dict("crs" => "EPSG:28356")
    r, _ = report(scoped)
    @test r["length_context"]["comparison_status_counts"]["chord_check"]["inapplicable"] == 2
    # A separately labeled WGS84 route can still be internally measured.
    @test r["length_context"]["comparison_status_counts"]["route_length_check"]["passed"] == 1

    # An invalid interior vertex must not establish route-derived bus evidence.
    delete!(route_bad, "meta")
    @test first(report(route_bad))["coordinate_reference"]["n_metric_eligible_buses"] == 0
    @test first(report(route_bad))["coordinate_reference"]["status"] == "unspecified"
    @test BMOPFTools._spatial_point(-0.0, 0.0) === BMOPFTools._spatial_point(0.0, -0.0)
    io = IOBuffer()
    BMOPFTools._md_spatial(first(report(net)), io)
    @test occursin("comparison basis `physical_length_m`", String(take!(io)))

    # Minimized synthetic witness for parent metadata retained after splitting:
    # report the discrepancy, but do not label the section lengths as defective
    # or infer a source-to-target transformation from their shared raw key.
    split = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_split_lengths.json"), String), Dict{String,Any})
    split_before = deepcopy(split)
    split_report, split_findings = report(split)
    @test split_report["length_context"]["context_counts"]["declared_physical_length_mismatch"] == 2
    @test length(split_report["length_context"]["witnesses"]) == 2
    @test isempty(split_findings)
    @test split == split_before
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
    linked = deepcopy(original)
    linked["line"] = Dict("coincident_line" => Dict("bus_from" => "unlinked_b", "bus_to" => "unlinked_a",
        "length" => 1.0, "terminal_map_from" => ["2"], "terminal_map_to" => ["1"]))
    linked_c = BMOPFTools._spatial_analysis(linked, levels)["coincidence"]
    @test linked_c["context_counts"]["line_connected"] == 1
    link = only(filter(w -> w["anchor_bus"] == "unlinked_a", linked_c["witnesses"]))
    @test only(link["internal_components"])["ports"][1]["terminal_map"] == ["2"]
    @test only(link["internal_components"])["ports"][1]["bus"] == "unlinked_b"
    malformed = deepcopy(original)
    malformed["transformer"]["n_winding"]["three_ports"]["windings"] = [Dict("bus" => "hv"), nothing, Dict("bus" => "lv")]
    @test BMOPFTools._spatial_analysis(malformed, levels)["transformers"]["n_indeterminate"] == 1
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
    groups = Dict{String,Any}("bus" => Dict("$(i)_$(j)" => Dict("x" => i, "y" => 0) for i in 1:30 for j in 1:2))
    groups_c = BMOPFTools._spatial_analysis(groups, levels)["coincidence"]
    @test groups_c["n_groups"] == 30
    @test length(groups_c["witnesses"]) == 5
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

include("coordinate_semantics_tests.jl")
include("spatial_proximity_tests.jl")

include("spatial_topology_tests.jl")
include("spatial_route_tests.jl")
include("spatial_review_tests.jl")
include("spatial_review_export_tests.jl")

include("spatial_shared_infrastructure_tests.jl")

@testset "spatial analysis enabled by default with whole-pass suppression" begin
    net = Dict{String,Any}("meta"=>Dict("crs"=>"WGS84"),
        "bus"=>Dict("a"=>Dict{String,Any}("longitude"=>153., "latitude"=>-27.),
                    "b"=>Dict{String,Any}("longitude"=>153.001, "latitude"=>-27.)),
        "line"=>Dict("short"=>Dict("bus_from"=>"a", "bus_to"=>"b", "length"=>1.)))
    cfg = load_config()
    @test cfg["spatial"]["enabled"] === true
    default_findings = Finding[]
    enabled = connectivity_analysis(net, default_findings)
    @test haskey(enabled["spatial"], "cleanup_review")
    @test any(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", default_findings)
    legacy = deepcopy(cfg); delete!(legacy["spatial"], "enabled")
    @test connectivity_analysis(net, Finding[]; config=legacy)["spatial"]["cleanup_review"]["items"] == enabled["spatial"]["cleanup_review"]["items"]
    older = deepcopy(cfg); delete!(older, "spatial")
    @test connectivity_analysis(net, Finding[]; config=older)["spatial"]["cleanup_review"]["items"] == enabled["spatial"]["cleanup_review"]["items"]
    cfg["spatial"]["enabled"] = false
    @test connectivity_analysis(Dict{String,Any}(), Finding[]; config=cfg)["spatial"]["reason"] == "disabled"
    original = deepcopy(net); config_before = deepcopy(cfg)
    fs = Finding[]
    disabled = connectivity_analysis(net, fs; config=cfg)
    @test net == original && cfg == config_before
    @test disabled["spatial"]["status"] == "inapplicable"
    @test disabled["spatial"]["reason"] == "disabled"
    @test disabled["spatial"]["analysis_performed"] === false
    @test !haskey(disabled["spatial"], "cleanup_review")
    @test !any(f -> startswith(f.code, "W.GEO."), fs)
    @test sort([f.code for f in fs]) == sort([f.code for f in default_findings if !startswith(f.code,"W.GEO.")])
    @test Dict(k=>v for (k,v) in disabled if k != "spatial") == Dict(k=>v for (k,v) in enabled if k != "spatial")
    @test JSON3.read(JSON3.write(disabled)).spatial.reason == "disabled"
    @test load_config()["spatial"]["enabled"] === true
    # Off means no traversal, even when subordinate settings or geometry cannot be read.
    cfg["spatial"]["max_topology_pairs"] = "invalid but unused"
    uninspectable = Dict{String,Any}("bus"=>true, "line"=>true)
    @test BMOPFTools._spatial_analysis(uninspectable, Dict{String,Any}(); config=cfg)["reason"] == "disabled"
    empty = Dict{String,Any}("bus"=>Dict("a"=>Dict()))
    @test BMOPFTools._spatial_analysis(empty, Dict{String,Any}()) === nothing
    @test BMOPFTools._spatial_analysis(empty, Dict{String,Any}(); config=cfg)["reason"] == "disabled"
    partial = Dict{String,Any}("bus"=>Dict("a"=>Dict("longitude"=>153.)))
    @test BMOPFTools._spatial_analysis(partial, Dict{String,Any}())["coordinate_coverage"]["n_partial"] == 1
    for value in ("false", 0, 1, nothing)
        invalid = load_config(); invalid["spatial"]["enabled"] = value
        result = BMOPFTools._spatial_analysis(net, Dict{String,Any}(); config=invalid)
        @test result["status"] == "indeterminate"
        @test result["reason"] == "invalid_configuration"
        @test result["analysis_performed"] === false
        @test occursin("invalid_configuration", sprint(io -> BMOPFTools._md_spatial(result, io)))
    end
    invalid = load_config(); invalid["spatial"] = false
    @test BMOPFTools._spatial_analysis(net, Dict{String,Any}(); config=invalid)["reason"] == "invalid_configuration"
    mktempdir() do dir
        config_path = joinpath(dir, "analysis-config.toml")
        write(config_path, "[spatial]\nenabled = false\n")
        override = load_config(config_path)
        sample = parse_bmopf(joinpath(@__DIR__, "..", "recipes", "analyze_case", "input.json"))
        sample["meta"] = Dict("crs"=>"WGS84")
        for (i,bus) in enumerate(values(sample["bus"]))
            bus["longitude"] = 153. + i*.001; bus["latitude"] = -27.
        end
        report = analyze(sample; config=override)
        @test report.results[:connectivity]["spatial"]["reason"] == "disabled"
        @test haskey(report.results, :voltage_levels) && haskey(report.results, :integrity)
        @test !any(f -> startswith(f.code,"W.GEO."), report.findings)
        for ext in ("md", "json")
            render(report, joinpath(dir,"report.$ext"))
        end
        md = read(joinpath(dir,"report.md"), String)
        @test occursin("disabled", md) && occursin("no geographic checks were run", md)
        @test !occursin("Cleanup review:", md)
        @test JSON3.read(read(joinpath(dir,"report.json"),String)).results.connectivity.spatial.analysis_performed === false
        @test_throws ArgumentError write_spatial_cleanup_bundle(sample, joinpath(dir,"bundle"); config=override)
        @test !isdir(joinpath(dir,"bundle"))
    end
end
