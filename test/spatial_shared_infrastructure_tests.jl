using Test, BMOPFTools, JSON3

@testset "shared infrastructure context and reporting" begin
    net = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_shared_infrastructure.json"), String), Dict{String,Any})
    # Explicit synthetic output of the existing voltage pass; geometry never assigns voltage.
    tiers = Dict{String,Any}("levels"=>Dict("MV"=>Dict("buses"=>["mv_a","mv_b"]), "LV"=>Dict("buses"=>["lv_a","lv_b"])))
    function spatial(n=net, levels=tiers; kwargs...)
        cfg = load_config()
        for (k,v) in kwargs; cfg["spatial"][string(k)] = v; end
        findings = Finding[]
        result = BMOPFTools._spatial_analysis(n, levels, findings; config=cfg)
        result, findings
    end
    review(n=net, levels=tiers; kwargs...) = first(spatial(n, levels; kwargs...))["cleanup_review"]
    items(r, code) = filter(i -> i["code"] == code, r["items"])
    category(i) = i["assessment"]["category"]
    original = deepcopy(net)
    r = review()
    @test net == original
    @test isempty(last(spatial()))
    @test r["queue_complete"]
    @test r["n_items"] == 3
    @test r["category_counts"]["context_only"] == 3
    @test r["presentation_counts"]["attention"] == 0
    @test all(i -> i["priority"] == 1, r["items"])
    @test all(i -> i["review"]["disposition"] == "unreviewed", r["items"])
    @test all(i -> i["assessment"]["error_probability"] === nothing, r["items"])
    shared = only(items(r, "S.SHARED_ROUTE_SEGMENT"))
    @test shared["ranking_reason"] == "different_voltage_systems_share_route"
    @test shared["evidence"]["voltage_context"]["tiers"] == ["LV","MV"]
    @test shared["evidence"]["voltage_context"]["relation"] == "different"
    @test [l["voltage_tier_from"] for l in shared["evidence"]["lines"]] == ["LV","MV"]
    @test all(i -> i["ranking_reason"] == "different_voltage_systems_share_location", items(r, "S.NEARBY_WITHOUT_DIRECT_BRANCH"))

    # Classification uses all line members, independent of witness truncation.
    narrow = only(items(review(; witness_limit=1), "S.SHARED_ROUTE_SEGMENT"))
    @test narrow["evidence"]["lines_truncated"]
    @test narrow["evidence"]["voltage_context"] == shared["evidence"]["voltage_context"]
    @test narrow["assessment"] == shared["assessment"]
    @test narrow["item_id"] == shared["item_id"]
    @test !narrow["geometry_coverage"]["subject_list_complete"]
    reordered = deepcopy(net); reordered["line"] = Dict(reverse(collect(net["line"])))
    @test review(reordered) == r

    # Same-voltage geometric overlap also needs no duplicate-circuit inference.
    same = Dict{String,Any}("levels"=>Dict("LV"=>Dict("buses"=>sort!(collect(keys(net["bus"]))))))
    sr = review(net, same)
    @test category(only(items(sr, "S.SHARED_ROUTE_SEGMENT"))) == "context_only"
    @test all(i -> category(i) == "review_candidate", items(sr, "S.NEARBY_WITHOUT_DIRECT_BRANCH"))
    parallel = deepcopy(net)
    parallel["line"]["lv"] = deepcopy(parallel["line"]["mv"])
    parallel["bus"] = Dict(k=>v for (k,v) in parallel["bus"] if startswith(k,"mv"))
    pr = review(parallel)
    @test pr["presentation_counts"]["attention"] == 0
    @test only(items(pr, "S.SHARED_ROUTE_SEGMENT"))["evidence"]["same_bus_pair"]
    @test only(items(pr, "S.SHARED_ROUTE_SEGMENT"))["evidence"]["terminal_map_relation"] == "equal_declared_maps"
    parallel["line"]["lv"]["terminal_map_to"] = ["1"]
    @test only(items(review(parallel), "S.SHARED_ROUTE_SEGMENT"))["ranking_reason"] == "distinct_terminal_maps"

    # Unknown tiers are missing evidence, never inferred as MV/LV from geometry.
    unknown = review(net, Dict{String,Any}())
    @test unknown["category_counts"]["needs_information"] == 3
    @test unknown["category_counts"]["context_only"] == 0
    partial = deepcopy(tiers); partial["levels"]["LV"]["buses"] = ["lv_a"]
    @test only(items(review(net, partial; witness_limit=1), "S.SHARED_ROUTE_SEGMENT"))["evidence"]["voltage_context"]["relation"] == "unknown"
    crossed = deepcopy(tiers)
    crossed["levels"]["MV"]["buses"] = ["mv_a","mv_b","lv_b"]
    crossed["levels"]["LV"]["buses"] = ["lv_a"]
    ci = only(items(review(net, crossed; witness_limit=1), "S.SHARED_ROUTE_SEGMENT"))
    @test ci["ranking_reason"] == "line_endpoints_cross_voltage_tiers"
    @test category(ci) == "review_candidate"
    @test ci["evidence"]["voltage_context"]["n_lines_crossing_tiers"] == 1

    # Independent contradictions survive a contextual shared-route classification.
    wrong = deepcopy(net); wrong["bus"]["lv_b"]["longitude"] += .001
    wr = review(wrong)
    @test category(only(items(wr, "S.SHARED_ROUTE_SEGMENT"))) == "context_only"
    endpoint = only(items(wr, "S.ROUTE_ENDPOINT_DISAGREEMENT"))
    @test category(endpoint) == "data_inconsistency"
    @test endpoint["priority"] == 3
    @test wr["presentation_counts"]["attention"] > 0
    @test wr["disposition_counts"]["confirmed_issue"] == 0
    gap = only(endpoint["evidence"]["endpoints"])["gap_m"]
    @test isempty(items(review(wrong; route_endpoint_tolerance_m=gap), "S.ROUTE_ENDPOINT_DISAGREEMENT"))
    @test length(items(review(wrong; route_endpoint_tolerance_m=prevfloat(gap)), "S.ROUTE_ENDPOINT_DISAGREEMENT")) == 1
    bad = deepcopy(net); bad["line"]["lv"]["meta"]["route_geometry"]["coordinates"] = "invalid"
    @test category(only(items(review(bad), "S.INVALID_ROUTE_GEOMETRY"))) == "data_inconsistency"
    sourced = deepcopy(parallel)
    for l in values(sourced["line"])
        l["meta"]["source_interval"] = "same-source"
        l["terminal_map_to"] = ["1","2","3"]
    end
    @test category(only(items(review(sourced), "S.REPEATED_SOURCE_INTERVAL"))) == "review_candidate"

    # An intentional open switch and coincident transformer ports explain direct boundaries.
    switched = deepcopy(net)
    switched["switch"] = Dict("boundary"=>Dict("bus_from"=>"mv_a", "bus_to"=>"lv_a", "open_switch"=>true))
    @test length(items(review(switched), "S.NEARBY_WITHOUT_DIRECT_BRANCH")) == 1
    transformer = deepcopy(net)
    transformer["transformer"] = Dict("delta_wye"=>Dict("t"=>Dict("bus_from"=>"mv_a", "bus_to"=>"lv_a")))
    @test length(items(review(transformer), "S.NEARBY_WITHOUT_DIRECT_BRANCH")) == 1
    @test isempty(last(spatial(transformer)))

    # JSON/GeoJSON carry classification; decisions cannot silently bless changed policy/evidence.
    roundtrip = JSON3.read(JSON3.write(r))
    @test BMOPFTools._jsonable(spatial_review_geojson(roundtrip)["features"][1]["properties"]["assessment"]) == r["items"][1]["assessment"]
    note = spatial_review_decision(r, shared["item_id"]; disposition="confirmed_issue", reviewer="synthetic",
        recorded_at="2026-10-24T01:00:00Z", rationale="Synthetic review override; not a field finding")
    confirmed = apply_spatial_review(roundtrip, [note])
    @test confirmed["presentation_counts"]["attention"] == 1
    @test confirmed["category_counts"]["context_only"] == 3
    @test confirmed["disposition_counts"]["confirmed_issue"] == 1
    tampered = deepcopy(r); first(tampered["items"])["assessment"]["category"] = "data_inconsistency"
    @test apply_spatial_review(tampered, Any[])["review_status_counts"]["modified_evidence"] == 1
    old_policy = deepcopy(note)
    old_policy["analysis_fingerprint"] = BMOPFTools._spatial_review_hash(["spatial-cleanup-review/v1", load_config()["spatial"]])
    @test apply_spatial_review(r, [old_policy])["review_status_counts"]["stale_decision"] == 1
    @test apply_spatial_review(confirmed, Any[])["presentation_counts"]["attention"] == 0

    # Human-readable location evidence; contexts are retained in an expandable inventory.
    md = sprint(io -> BMOPFTools._md_spatial_cleanup_review(r, io))
    @test occursin("Contextual observations", md)
    @test occursin("Showing 0 of 0 attention observations", md)
    @test occursin("Review location:", md)
    @test occursin("MV", md) && occursin("LV", md)
    @test occursin("Interpretation:", md) && occursin("Uncertainty:", md) && occursin("Inspect:", md)
    @test occursin("not error counts", md)
    @test occursin("confirmed", sprint(io -> BMOPFTools._md_spatial_cleanup_review(confirmed, io)))
    hostile = deepcopy(r); first(hostile["items"])["bus_ids"] = ["<script>bad</script>[link](x)"]
    @test !occursin("<script>", sprint(io -> BMOPFTools._md_spatial_cleanup_review(hostile, io)))
    empty_review = review(; review_enabled=false)
    @test occursin("disabled", sprint(io -> BMOPFTools._md_spatial_cleanup_review(empty_review, io)))
    @test !review(; max_review_candidates=1)["queue_complete"]
    @test sum(values(r["category_counts"])) == r["n_items"]
    @test sum(sum(values(g["category_counts"])) for g in r["locations"]) == r["n_items"]
    # Existing v1 payloads remain readable without inventing new category totals.
    legacy = deepcopy(r)
    for item in legacy["items"]
        delete!(item, "assessment"); delete!(item, "coordinate_evidence")
        item["evidence_fingerprint"] = BMOPFTools._spatial_review_item_fingerprint(item)
    end
    delete!(legacy, "category_counts")
    legacy_md = sprint(io -> BMOPFTools._md_spatial_cleanup_review(legacy, io))
    @test occursin("Classification unavailable for legacy", legacy_md)
    @test !occursin("| context only | 0 |", legacy_md)
    @test occursin("Showing 3 of 3 attention observations", legacy_md)
    @test apply_spatial_review(legacy, Any[])["presentation_counts"]["attention"] == 3
    confirmed_md = sprint(io -> BMOPFTools._md_spatial_cleanup_review(confirmed, io))
    @test occursin("Reviewer: synthetic", confirmed_md)
    @test occursin("Rationale:", confirmed_md)
    @test occursin("\n\n  Interpretation:", md)
    @test occursin("reported accuracy", md)
    # The public renderer and JSON adapter carry the new assessment end to end.
    sample = parse_bmopf(joinpath(@__DIR__, "..", "recipes", "analyze_case", "input.json"))
    sample["meta"] = Dict("crs"=>"WGS84")
    for bus in values(sample["bus"]); bus["longitude"] = 153.; bus["latitude"] = -27.; end
    response = execute_analysis(sample)
    public_review = response["result"]["results"]["connectivity"]["spatial"]["cleanup_review"]
    @test all(i -> haskey(i, "assessment"), public_review["items"])
    mktempdir() do dir
        file = joinpath(dir, "report.md")
        render(analyze(sample), file)
        @test occursin("Automated evidence category", read(file, String))
        @test occursin("Contextual observations", read(file, String))
    end

end
