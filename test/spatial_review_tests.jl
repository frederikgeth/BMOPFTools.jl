using Test, BMOPFTools, JSON3

@testset "spatial cleanup review workflow" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_discrepancies.json"), String), Dict{String,Any})
    calibration = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_review_calibration.json"), String), Dict{String,Any})
    for (id, length) in calibration["line_lengths_m"]; fixture["line"][id]["length"] = length; end
    function spatial(n; kwargs...)
        cfg = load_config()
        for (k,v) in kwargs; cfg["spatial"][string(k)] = v; end
        BMOPFTools._spatial_analysis(n, Dict{String,Any}(); config=cfg)
    end
    review(n; kwargs...) = spatial(n; kwargs...)["cleanup_review"]
    original = deepcopy(fixture)
    r = review(fixture)
    @test fixture == original
    @test r["queue_complete"]
    @test r["status"] == "assessed"
    @test r["n_items"] > 0
    @test length(unique(i["item_id"] for i in r["items"])) == r["n_items"]
    for expected in calibration["expectations"]
        item = only(filter(i -> i["code"] == expected["code"], r["items"]))
        @test item["priority"] == expected["priority"]
        @test item["ranking_reason"] == expected["ranking_reason"]
    end
    @test all(i -> i["review"]["disposition"] == "unreviewed", r["items"])
    @test issorted([-i["priority"] for i in r["items"]])
    reordered = deepcopy(fixture); reordered["line"] = Dict(reverse(collect(reordered["line"])))
    @test review(reordered) == r
    @test length(r["locations"]) < length(r["items"])
    @test sum(length(g["item_ids"]) for g in r["locations"]) == r["n_items"]
    @test !haskey(first(values(spatial(fixture)["discrepancy_candidates"]["checks"])), "_review_candidates")
    bounded = review(fixture; max_review_candidates=1)
    @test bounded["n_items"] == 1
    @test !bounded["queue_complete"]
    @test bounded["queue_truncated"]
    @test review(fixture; review_enabled=false)["reason"] == "disabled"
    for opt in ((max_review_candidates=0,), (max_review_candidates=true,), (max_review_candidates=100001,), (review_enabled="yes",))
        @test review(fixture; opt...)["reason"] == "invalid_configuration"
    end
    @test !review(fixture; discrepancy_enabled=false)["queue_complete"]
    # Capture is independent of old, short witness lists.
    parallel = deepcopy(fixture)
    for i in 1:30
        parallel["line"]["copy_$i"] = deepcopy(parallel["line"]["wrong_end"])
    end
    many = spatial(parallel; witness_limit=1)
    @test length(many["discrepancy_candidates"]["checks"]["route_endpoints"]["witnesses"]) == 1
    @test many["cleanup_review"]["coverage"]["route_endpoints"]["n_captured"] == 31
    @test many["cleanup_review"]["coverage"]["route_endpoints"]["capture_complete"]
    @test !review(parallel; max_review_candidates=2)["coverage"]["route_endpoints"]["capture_complete"]
    # Existing physical/electrical mismatches also enter the workflow.
    split = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_split_lengths.json"), String), Dict{String,Any})
    @test count(i -> i["code"] == "R.LINE_LENGTH_CONTEXT", review(split)["items"]) == 2
    # WGS84 point exports include IDs and dispositions; Cartesian is never mapped as degrees.
    geo = spatial_review_geojson(r)
    @test geo["type"] == "FeatureCollection"
    @test length(geo["features"]) == r["n_items"]
    @test all(f -> f["geometry"]["type"] == "MultiPoint", geo["features"])
    @test JSON3.read(JSON3.write(geo)).features[1].id == geo["features"][1]["id"]
    cart = Dict{String,Any}("meta" => Dict("crs"=>Dict("type"=>"cartesian", "units"=>"ft")),
        "bus" => Dict("a"=>Dict("x"=>0.,"y"=>0.), "b"=>Dict("x"=>1.,"y"=>0.)))
    local_review = review(cart)
    @test only(local_review["items"])["local_geometry"]["points"][2][1] ≈ .3048
    @test isempty(spatial_review_geojson(local_review)["features"])
    @test spatial_review_geojson(local_review)["n_items_without_wgs84_geometry"] == 1
    unknown = deepcopy(cart); delete!(unknown,"meta")
    @test !review(unknown)["queue_complete"]
    @test isempty(spatial_review_geojson(review(unknown))["features"])

    # Explicit sidecar provenance, immutable review/model, and deterministic replay.
    item = first(r["items"])
    function decision(r=r; kwargs...)
        opts = Dict(:disposition=>"accepted_modeling", :reviewer=>"synthetic-reviewer", :recorded_at=>"2026-10-24T01:00:00Z", :rationale=>"Synthetic expected representation", :evidence_refs=>["synthetic://review-case"])
        merge!(opts, Dict(kwargs))
        spatial_review_decision(r, item["item_id"]; opts...)
    end
    d = decision()
    reviewed = apply_spatial_review(r, [d])
    current = only(filter(i -> i["item_id"] == item["item_id"], reviewed["items"]))
    @test current["review"]["status"] == "recorded"
    @test current["review"]["disposition"] == "accepted_modeling"
    @test r == review(fixture)
    @test fixture == original
    @test length(reviewed["items"]) == length(r["items"])
    @test apply_spatial_review(reviewed, Any[])["disposition_counts"]["unreviewed"] == r["n_items"]
    for opts in ((reviewer="",), (rationale="",), (recorded_at="2026-02-30T01:00:00Z",), (recorded_at="2026-10-24",), (disposition="delete_asset",))
        @test_throws ArgumentError decision(; opts...)
    end
    later = decision(disposition="resolved", recorded_at="2026-10-25T01:00:00Z")
    final = apply_spatial_review(r, [later,d,d])
    @test final["disposition_counts"]["resolved"] == 1
    @test length(spatial_review_geojson(final)["features"]) == length(geo["features"])
    @test apply_spatial_review(r, [d,later])["items"] == final["items"]
    conflict = decision(disposition="confirmed_issue")
    disputed = apply_spatial_review(r, [d,conflict])
    @test disputed["review_status_counts"]["conflicting_decisions"] == 1
    @test disputed["disposition_counts"]["accepted_modeling"] == 0
    malformed = deepcopy(d); malformed["rationale"] = ""
    invalid = apply_spatial_review(r, [d,malformed])
    @test invalid["decision_audit"]["n_invalid_records"] == 1
    @test invalid["review_status_counts"]["invalid_record"] == 1
    modified = deepcopy(r); modified["items"][1]["evidence"]["edited"] = true
    @test_throws ArgumentError decision(modified)
    @test apply_spatial_review(modified, [d])["review_status_counts"]["modified_evidence"] == 1
    changed = deepcopy(fixture); changed["name"] = "new snapshot"
    stale = apply_spatial_review(review(changed), [d])
    @test stale["review_status_counts"]["stale_decision"] == 1
    @test stale["disposition_counts"]["accepted_modeling"] == 0
    reconfigured = apply_spatial_review(review(fixture; long_span_threshold_m=9999.), [d])
    @test reconfigured["review_status_counts"]["stale_decision"] == 1
    orphan = deepcopy(d); orphan["item_id"] = "review-missing"
    @test apply_spatial_review(r, [orphan])["decision_audit"]["n_unmatched_records"] == 1
    roundtrip = JSON3.read(JSON3.write(r), Dict{String,Any})
    @test apply_spatial_review(roundtrip, JSON3.read(JSON3.write([d]), Vector{Dict{String,Any}}))["disposition_counts"]["accepted_modeling"] == 1
    text = sprint(io -> BMOPFTools._md_spatial_cleanup_review(stale, io))
    @test occursin("stale_decision", text)
    @test occursin("Queue complete", text)
    # Member-list truncation is explicit, without unstable group identities.
    narrow = review(parallel; witness_limit=1)
    wide = review(parallel; witness_limit=40)
    key(i) = (i["code"], get(i["evidence"], "source_interval", ""), get(i["evidence"], "segment_lonlat", []))
    for i in filter(i -> i["code"] in ("S.SHARED_ROUTE_SEGMENT", "S.REPEATED_SOURCE_INTERVAL"), narrow["items"])
        matches = filter(j -> key(j) == key(i), wide["items"])
        @test any(j -> j["item_id"] == i["item_id"], matches)
        @test !i["impact"]["subjects_complete"]
        @test !i["geometry_coverage"]["subject_list_complete"]
    end
    @test BMOPFTools._spatial_review_hash(Dict("x"=>1.0, "y"=>-0.0)) == BMOPFTools._spatial_review_hash(Dict("y"=>0, "x"=>1))
    @test BMOPFTools._spatial_review_hash(Dict("x"=>NaN)) != BMOPFTools._spatial_review_hash(Dict("x"=>nothing))
    # Same positions at the longitude seam group using metric-location semantics.
    seam = Dict{String,Any}("meta"=>Dict("crs"=>"WGS84"), "bus"=>Dict(
        "a"=>Dict("longitude"=>180., "latitude"=>0.), "b"=>Dict("longitude"=>-180., "latitude"=>0.)))
    seam_item = only(review(seam)["items"])
    @test seam_item["geometry"]["coordinates"] == [[-180.,0.]]
    @test seam_item["geometry_coverage"]["all_identified_buses_located"]
    @test seam_item["location"]["coordinate"] == [-180.,0.]
    # Different maps are evidence of representation differences, not duplication.
    mapped = deepcopy(fixture)
    mapped["line"]["parallel"] = deepcopy(mapped["line"]["direct"])
    mapped["line"]["parallel"]["terminal_map_from"] = ["2"]
    mapped["line"]["parallel"]["terminal_map_to"] = ["2"]
    @test any(i -> i["ranking_reason"] == "distinct_terminal_maps" && i["priority"] == 1, review(mapped)["items"])
    # The existing JSON adapter carries the queue and the example exports usable files.
    sample = parse_bmopf(joinpath(@__DIR__, "..", "recipes", "analyze_case", "input.json"))
    sample["meta"] = Dict("crs"=>"WGS84")
    for bus in values(sample["bus"]); bus["longitude"] = 153.; bus["latitude"] = -27.; end
    response = execute_analysis(sample)
    @test haskey(response["result"]["results"]["connectivity"]["spatial"], "cleanup_review")
    include(joinpath(@__DIR__, "..", "examples", "spatial_cleanup_review.jl"))
    mktempdir() do dir
        bundle = write_spatial_cleanup_bundle(sample, dir)
        @test all(f -> isfile(joinpath(dir,f)), ("review.json","review.geojson","review.md","decisions-template.json"))
        disk = JSON3.read(read(joinpath(dir,"review.json"),String), Dict{String,Any})
        @test disk["case_fingerprint"] == bundle["case_fingerprint"]
        first_item = first(bundle["items"])
        note = spatial_review_decision(bundle, first_item["item_id"]; disposition="deferred", reviewer="synthetic-reviewer",
            recorded_at="2026-10-24T01:00:00Z", rationale="Synthetic example only")
        @test apply_spatial_review(disk,[note])["disposition_counts"]["deferred"] == 1
        write(joinpath(dir,"decisions-template.json"), "preserve existing ledger")
        write_spatial_cleanup_bundle(sample,dir; decisions=[note])
        @test read(joinpath(dir,"decisions-template.json"),String) == "preserve existing ledger"
    end

    # Fresh ingestion timestamps never invalidate a decision on unchanged input.
    parsed1 = parse_bmopf(joinpath(@__DIR__, "data", "spatial_discrepancies.json"))
    parsed2 = parse_bmopf(joinpath(@__DIR__, "data", "spatial_discrepancies.json"))
    parsed1["_meta"]["parsed_at"] = "2026-10-24T01:00:00"
    parsed2["_meta"]["parsed_at"] = "2026-10-25T01:00:00"
    r1, r2 = review(parsed1), review(parsed2)
    @test r1["case_fingerprint"] == r2["case_fingerprint"]
    note = spatial_review_decision(r1, first(r1["items"])["item_id"]; disposition="deferred", reviewer="synthetic-reviewer",
        recorded_at="2026-10-24T01:00:00Z", rationale="Same source across reloads")
    @test apply_spatial_review(r2,[note])["disposition_counts"]["deferred"] == 1
    @test parsed1["_meta"]["parsed_at"] == "2026-10-24T01:00:00"
    parsed2["_meta"]["source_revision"] = "new evidence"
    @test review(parsed2)["case_fingerprint"] != r1["case_fingerprint"]
    persisted = deepcopy(parsed1)
    persisted["meta"]["provenance"] = Dict("parsed_at"=>"later")
    @test review(persisted)["case_fingerprint"] == r1["case_fingerprint"]

    # Default JSON3 object views are supported as well as mutable dictionaries.
    object_review = JSON3.read(JSON3.write(r))
    object_decisions = JSON3.read(JSON3.write([d]))
    @test apply_spatial_review(object_review, object_decisions)["disposition_counts"]["accepted_modeling"] == 1
    @test spatial_review_decision(object_review, item["item_id"]; disposition="deferred", reviewer="synthetic-reviewer",
        recorded_at="2026-10-24T01:00:00Z", rationale="Object-view replay")["case_fingerprint"] == r["case_fingerprint"]
    for group in r["locations"]
        members = filter(i -> i["location_id"] == group["location_id"], r["items"])
        @test group["n_identified_buses"] == length(Set(b for i in members for b in i["bus_ids"]))
        @test group["n_identified_components"] == length(Set((c["kind"],c["id"]) for i in members for c in i["components"]))
        @test group["max_item_directly_attached_loads"] == maximum(i["impact"]["n_directly_attached_loads"] for i in members)
    end
    @test all(f -> haskey(f["properties"], "components") && haskey(f["properties"], "bus_ids"), spatial_review_geojson(r)["features"])

    @test r["coordinate_context"]["n_buses"] == length(fixture["bus"])
    @test r["coordinate_context"]["n_metric_eligible_buses"] == length(fixture["bus"])
    @test r["analysis_settings"]["max_review_candidates"] == 5000
    @test haskey(r["coverage"]["branch_spans"]["domain_counts"], "n_components_with_unavailable_distance")
    @test spatial_review_geojson(r)["coordinate_context"] == r["coordinate_context"]

end
