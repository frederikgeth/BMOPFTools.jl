using Test, BMOPFTools, JSON3

@testset "spatial decision evidence and public exports" begin
    net = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_discrepancies.json"), String), Dict{String,Any})
    review(n=net) = BMOPFTools._spatial_analysis(n, Dict{String,Any}())["cleanup_review"]
    series(r) = only(filter(i -> i["code"] == "S.DIRECT_ALONGSIDE_SERIES_PATH", r["items"]))
    original = deepcopy(net)
    r = review(); item = series(r); e = item["interpretation_evidence"]
    @test net == original
    @test all(c -> c["relation"] == "same_declared_terminal_sets", e["terminal_comparisons"])
    @test isempty(only(e["intermediate_buses"])["attachments"])
    @test only(e["intermediate_buses"])["perfectly_grounded_terminals"] === nothing
    @test isempty(e["direct"]["model_declarations"])
    @test e["direct"]["length_context"]["declared_length_m"] === nothing
    @test e["direct"]["length_context"]["chord_m"] > 0

    enriched = deepcopy(net)
    enriched["line"]["direct"]["meta"]["evidence_status"] = "inferred_not_observed"
    enriched["line"]["direct"]["meta"]["producer"] = Dict("claim" => "<placeholder> & unverified", "origin" => "inferred")
    # Historical nested declarations must not be mistaken for current provenance.
    enriched["line"]["direct"]["meta"]["history"] = Dict("prior_line" => Dict("origin" => "surveyed"))
    enriched["line"]["direct"]["length"] = 25.
    enriched["line"]["direct"]["terminal_map_from"] = ["1", "4"]
    enriched["bus"]["b"]["perfectly_grounded_terminals"] = ["4"]
    enriched["load"] = Dict("tap" => Dict("bus" => "b", "terminal_map" => ["1", "4"]))
    enriched["shunt"] = Dict("earth" => Dict("bus" => "b", "terminal_map" => ["4"], "G_1_1" => 0.1))
    er = review(enriched); ei = series(er); ee = ei["interpretation_evidence"]
    @test ei["item_id"] == item["item_id"]
    @test ei["assessment"] == item["assessment"]
    @test ei["evidence_fingerprint"] != item["evidence_fingerprint"]
    @test ee["terminal_comparisons"][1]["relation"] == "different_declared_terminal_sets"
    @test ee["direct"]["length_context"]["declared_length_m"] == 25.
    @test Set(a["kind"] for a in only(ee["intermediate_buses"])["attachments"]) == Set(["load", "shunt"])
    @test only(ee["intermediate_buses"])["perfectly_grounded_terminals"] == ["4"]
    @test length(ee["direct"]["model_declarations"]) == 3
    @test any(d -> d["path"] == ["meta", "producer", "origin"] && d["value"] == "inferred", ee["direct"]["model_declarations"])
    @test !any(d -> d["value"] == "surveyed", ee["direct"]["model_declarations"])
    @test JSON3.read(JSON3.write(ei))["interpretation_evidence"]["direct"]["line_id"] == "direct"
    asymmetric = deepcopy(enriched)
    asymmetric["line"]["ab"]["terminal_map_to"] = ["2"]
    asymmetric["line"]["bc"]["terminal_map_from"] = ["2"]
    asymmetric_evidence = series(review(asymmetric))["interpretation_evidence"]
    reversed = deepcopy(asymmetric)
    l = reversed["line"]["ab"]
    l["bus_from"], l["bus_to"] = l["bus_to"], l["bus_from"]
    l["terminal_map_from"], l["terminal_map_to"] = l["terminal_map_to"], l["terminal_map_from"]
    @test series(review(reversed))["interpretation_evidence"]["terminal_comparisons"] == asymmetric_evidence["terminal_comparisons"]
    @test first(series(review(reversed))["interpretation_evidence"]["series"])["terminal_map_to"] == ["2"]
    for invalid in (nothing, [], ["1", "1"], [1], "1")
        broken = deepcopy(net); broken["line"]["ab"]["terminal_map_from"] = invalid
        @test series(review(broken))["interpretation_evidence"]["terminal_comparisons"][1]["relation"] == "indeterminate"
    end
    record = spatial_review_decision(er, ei["item_id"]; disposition="needs_information", reviewer="synthetic",
        recorded_at="2026-10-24T01:00:00Z", rationale="Check the grounding shunt", evidence_refs=String[])
    tampered = deepcopy(er); series(tampered)["interpretation_evidence"]["direct"]["model_declarations"][1]["value"] = "changed"
    @test series(apply_spatial_review(tampered, [record]))["review"]["status"] != "recorded"
    md = sprint(io -> render_spatial_review(er, io))
    @test occursin("Direct / series decision evidence", md)
    @test occursin("different\\_declared\\_terminal\\_sets", md)
    @test occursin("shunt=1", md)
    @test occursin("&lt;placeholder&gt; &amp; unverified", md)
    @test !occursin("<placeholder>", md)
    @test occursin("Showing 0 of", sprint(io -> render_spatial_review(er, io; item_limit=0)))
    @test !occursin("Direct / series decision evidence", sprint(io -> render_spatial_review(er, io; item_limit=0)))
    for invalid in (-1, true, 1.5, "20")
        @test_throws ArgumentError render_spatial_review(er, IOBuffer(); item_limit=invalid)
    end
    @test_throws ArgumentError render_spatial_review(Dict("schema_version"=>"unknown"), IOBuffer())
    mktempdir() do dir
        out = joinpath(dir, "bundle")
        paths = export_spatial_review(er, out; item_limit=100)
        @test length(paths) == 4
        @test all(isfile, values(paths))
        @test all(isabspath, values(paths))
        @test JSON3.read(read(paths["review.json"], String))["n_items"] == er["n_items"]
        @test JSON3.read(read(paths["review.geojson"], String))["type"] == "FeatureCollection"
        @test JSON3.read(read(paths["decisions-template.json"], String))["decisions"] == []
        write(paths["decisions-template.json"], "preserve ledger")
        export_spatial_review(er, out; item_limit=0)
        @test read(paths["decisions-template.json"], String) == "preserve ledger"
        @test occursin("Showing 0 of", read(paths["review.md"], String))
        @test JSON3.read(read(paths["review.json"], String))["n_items"] == er["n_items"]
        @test_throws ArgumentError export_spatial_review(er, joinpath(dir, "invalid"); item_limit=-1)
        @test !ispath(joinpath(dir, "invalid"))
    end
    # Existing v1 payloads remain renderable without enrichment.
    legacy = deepcopy(r); delete!(series(legacy), "interpretation_evidence")
    @test !occursin("Direct / series decision evidence", sprint(io -> render_spatial_review(legacy, io)))
end
