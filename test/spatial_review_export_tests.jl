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
    @test occursin("different declared terminal sets", md)
    @test occursin("shunt=1", md)
    @test !occursin("Any", md)
    @test !occursin("Source declaration `", md)
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

@testset "capacitor context, coverage banner and candidate navigation" begin
    net = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_capacitor_attachment.json"), String), Dict{String,Any})
    review(n=net) = BMOPFTools._spatial_analysis(n, Dict{String,Any}())["cleanup_review"]
    r = review(); item = only(r["items"])
    @test item["code"] == "S.DIRECT_ALONGSIDE_SERIES_PATH"
    middle = only(item["interpretation_evidence"]["intermediate_buses"])
    @test middle["bus_id"] == "j"
    @test only(middle["attachments"]) == Dict("kind"=>"capacitor", "component_id"=>"cap_at_junction", "terminal_map"=>["1","4"])
    @test item["evidence"]["path_buses"][2]["attachments"]["capacitor"] == 1
    @test only(JSON3.read(JSON3.write(item))["interpretation_evidence"]["intermediate_buses"])["attachments"][1]["kind"] == "capacitor"
    without = deepcopy(net); delete!(without, "capacitor")
    empty_item = only(review(without)["items"])
    @test isempty(only(empty_item["interpretation_evidence"]["intermediate_buses"])["attachments"])
    @test item["item_id"] == empty_item["item_id"]
    @test item["evidence_fingerprint"] != empty_item["evidence_fingerprint"]
    @test item["assessment"] == empty_item["assessment"]
    elsewhere = deepcopy(net); elsewhere["capacitor"]["cap_at_junction"]["bus"] = "a"
    @test isempty(only(only(review(elsewhere)["items"])["interpretation_evidence"]["intermediate_buses"])["attachments"])
    md = sprint(io -> render_spatial_review(r, io))
    @test occursin("capacitor=1", md)
    @test !occursin("no listed attachments", md)
    @test occursin("3 of 3 buses (100.0%)", md)
    @test occursin("**0 not eligible**", md)
    @test occursin("Reported coordinate accuracy: 0 of 3 buses", md)
    @test first(findfirst("Coordinate coverage", md)) < first(findfirst("Cleanup review", md))
    targets(s) = [m.captures[1] for m in eachmatch(r"\[View\]\(#([^\)]+)\)", s)]
    anchors(s) = [m.captures[1] for m in eachmatch(r"<a id=\"([^\"]+)\"></a>", s)]
    @test length(targets(md)) == 1
    @test targets(md) == anchors(md)
    @test occursin("Candidate index — 1 of 1 attention observations", md)
    hidden = sprint(io -> render_spatial_review(r, io; item_limit=0))
    @test isempty(targets(hidden)) && isempty(anchors(hidden))
    @test occursin("Candidate index — 0 of 1 attention observations", hidden)
    # Partial eligibility is independent of completeness of the applicable queue.
    partial = deepcopy(net); partial["bus"]["unlocated"] = Dict("terminal_names"=>["1"])
    partial["bus"]["a"]["coordinate_accuracy_m"] = 0.5
    pm = sprint(io -> render_spatial_review(review(partial), io))
    @test occursin("3 of 4 buses (75.0%)", pm)
    @test occursin("**1 not eligible**", pm)
    @test occursin("Reported coordinate accuracy: 1 of 4 buses", pm)
    legacy = deepcopy(r); delete!(legacy["coordinate_context"], "n_with_reported_accuracy")
    @test occursin("coverage unavailable in this report", sprint(io -> render_spatial_review(legacy, io)))
    unclassified = deepcopy(r); delete!(unclassified["items"][1], "assessment")
    @test occursin("classification unavailable / S.DIRECT", sprint(io -> render_spatial_review(unclassified, io)))
    unknown = deepcopy(net); delete!(unknown, "meta")
    @test occursin("**3 not eligible**", sprint(io -> render_spatial_review(review(unknown), io)))
    # An index must not imply that hidden items have detail targets in this file.
    many = deepcopy(net)
    for id in ("second", "third"); many["line"][id] = deepcopy(many["line"]["direct"]); end
    many_r = review(many)
    limited = sprint(io -> render_spatial_review(many_r, io; item_limit=2))
    @test occursin("Candidate index — 2 of 3 attention observations", limited)
    @test length(targets(limited)) == 2
    @test Set(targets(limited)) <= Set(anchors(limited))
    @test length(unique(anchors(limited))) == length(anchors(limited))
    context = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_shared_infrastructure.json"), String), Dict{String,Any})
    levels = Dict{String,Any}("levels"=>Dict("MV"=>Dict("buses"=>["mv_a","mv_b"]), "LV"=>Dict("buses"=>["lv_a","lv_b"])))
    cr = BMOPFTools._spatial_analysis(context, levels)["cleanup_review"]
    cm = sprint(io -> render_spatial_review(cr, io))
    @test occursin("Candidate index — 0 of 0 attention observations", cm)
    @test isempty(targets(cm))
    @test length(anchors(cm)) == cr["n_items"]
    # Fragments must not interpolate unsafe caller-supplied IDs into HTML.
    unsafe = deepcopy(r); unsafe["items"][1]["item_id"] = "\" onclick=\"alert(1)"
    um = sprint(io -> render_spatial_review(unsafe, io))
    @test all(a -> occursin(r"^spatial-item-[0-9a-f]{64}$", a), anchors(um))
    @test targets(um) == anchors(um)
    mktempdir() do dir
        paths = export_spatial_review(r, dir)
        @test Set(targets(read(paths["review.md"], String))) <= Set(anchors(read(paths["review.md"], String)))
        serialized = JSON3.read(read(paths["review.json"], String))
        @test only(serialized["items"])["evidence"]["path_buses"][2]["attachments"]["capacitor"] == 1
    end
end
