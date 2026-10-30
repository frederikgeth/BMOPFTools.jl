using Test, BMOPFTools, JSON3

_has_hint(list, id) = any(h -> h["id"] == id, list)

_interpretation_fixture() = JSON3.read(read(joinpath(@__DIR__, "data", "profiler_evidence",
    "provenance_context.json"), String), Dict{String,Any})

function _interpretation_classify(net; voltage_levels=nothing)
    findings = Finding[]
    lc = BMOPFTools._classify_linecodes(net, findings)
    result = BMOPFTools._classify_impedance_transformation(net, findings, lc; voltage_levels)
    result, findings
end

@testset "profiler interpretations support review without implying repair" begin
    net = _interpretation_fixture(); original = deepcopy(net)
    findings = Finding[]
    result = provenance_analysis(net, findings)
    hint = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", findings))
    context = hint.detail["interpretation"]
    @test hint.severity == INFO
    @test context["observations"]["basis"] == "PN_MPN_patterns_not_matched"
    @test context["observations"]["by_linecode"]["three_wire"]["R_mutual_self_ratio"] ≈ 0.1
    @test _has_hint(context["possible_explanations"], "kron_reduction")
    @test _has_hint(context["alternatives"], "native_three_wire")
    @test _has_hint(context["alternatives"], "other_equivalent")
    @test _has_hint(context["implications"], "neutral_assumed_grounded")
    @test occursin("1 of 1 are used on LV lines", hint.message)
    @test occursin("phase-to-neutral patterns need 0.5", context["observations"]["by_linecode"]["three_wire"]["pattern_comparison"]["summary"])
    @test !context["observations"]["by_linecode"]["three_wire"]["pattern_comparison"]["criteria"][1]["met"]
    @test context["supporting_context"]["three_wire"]["lv_without_neutral_line_ids"] == ["feeder"]
    @test context["automation_guidance"]["disposition"] == "review"
    @test context["automation_guidance"]["additional_evidence_required_for_model_changes"]
    @test result["impedance_transform"]["evidence_by_linecode"]["three_wire"]["history_status"] == "unknown"
    @test !hint.detail["history_verified"]
    network_hint = only(filter(f -> f.code == "I.PROV.KRON_LIKELY", findings))
    @test network_hint.detail["interpretation"]["observations"]["n_with_neutral"] == 0
    @test net == original

    explanation = explain_finding(hint)
    @test explanation["code"] == hint.code
    @test explanation["interpretation"] == context
    @test explanation["instance"]["detail"] == hint.detail
    @test !haskey(explain_finding(hint.code), "instance") # code-only API unchanged
    decoded = JSON3.read(JSON3.write(explanation))
    @test decoded.interpretation.automation_guidance.disposition == "review"
    @test any(h -> h.id == "native_three_wire", decoded.interpretation.alternatives)
    @test decoded.instance.detail.history_verified === false
    report = analyze(net)
    decoded_report = JSON3.read(sprint(io -> BMOPFTools.render_json(report, io)))
    serialized = only(filter(f -> f.code == hint.code, decoded_report.findings))
    @test serialized.detail.interpretation.supporting_context.three_wire.lv_without_neutral_line_ids == ["feeder"]
    markdown = sprint(io -> BMOPFTools.render_markdown(report, io))
    @test occursin(hint.code, markdown)
    @test occursin("How to read this", markdown)
    @test occursin("Why it matters", markdown)
    @test occursin("phase-to-neutral patterns need 0.5", markdown)
    terminal = sprint(io -> BMOPFTools.render_terminal(report, io))
    @test count("Check: Inspect the original conductor model", terminal) == 1
    @test net == original
    explanation["interpretation"]["observations"]["linecodes"][1] = "changed"
    push!(explanation["instance"]["detail"]["interpretation"]["alternatives"], Dict("id" => "new", "text" => "changed"))
    @test context["observations"]["linecodes"] == ["three_wire"]
    @test !_has_hint(context["alternatives"], "new")
    # A native three-wire interpretation is legitimate: the same observations
    # must not be promoted into a verified origin or a model-changing action.
    plain = Finding(INFO, "I.PROV.KRON_LIKELY", :provenance, :network, nothing, "review")
    @test explain_finding(plain)["interpretation"] === nothing
    @test explain_finding(plain)["instance"]["detail"] === nothing
    supplied = Finding(INFO, plain.code, :provenance, :network, nothing, "review",
        Dict{String,Any}("interpretation" => Dict("sample" => Inf, "labels" => [:a])))
    @test explain_finding(supplied)["interpretation"]["sample"] === nothing
    @test explain_finding(supplied)["interpretation"]["labels"] == ["a"]
    @test_throws BMOPFTools.UnknownFindingCode explain_finding(
        Finding(INFO, "I.UNKNOWN.CODE", :provenance, :network, nothing, "unknown"))
end

@testset "Kron candidate context follows actual linecode use" begin
    net = _interpretation_fixture()
    for v in (999.0, 1000.0, 11000.0)
        net["voltage_source"]["grid"]["v_magnitude"] .= v
        r, fs = _interpretation_classify(net)
        f = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs))
        context = f.detail["interpretation"]["supporting_context"]["three_wire"]
        @test context["lv_without_neutral_line_ids"] == (v < 1000 ? ["feeder"] : [])
        @test context["other_or_unassessed_line_ids"] == (v < 1000 ? [] : ["feeder"])
        @test !f.detail["history_verified"]
        @test r["by_linecode"]["three_wire"] == "kron_reduced"
        @test occursin(v < 1000 ? "used on LV lines without a represented neutral" : "this is context only", f.message)
        implication_ids = BMOPFTools._interpretation_ids(f.detail["interpretation"]["implications"])
        @test v < 1000 ? "neutral_assumed_grounded" in implication_ids : implication_ids == ["mv_hv_or_unused_context"]
    end
    delete!(net, "voltage_source")
    r, fs = _interpretation_classify(net)
    @test isempty(r["evidence_by_linecode"]["three_wire"]["supporting_context"]["lv_without_neutral_line_ids"])
    @test any(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs)
    empty!(net["line"])
    r, fs = _interpretation_classify(net)
    @test isempty(r["evidence_by_linecode"]["three_wire"]["supporting_context"])
    template_hint = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs)) # weak template-only hint retained
    @test occursin("1 are not used by any line", template_hint.message)
    @test !occursin("LV lines without a represented neutral", template_hint.message)

    net = _interpretation_fixture()
    net["line"]["copy"] = deepcopy(net["line"]["feeder"])
    # A mixed-use template does not inherit LV context for every use.
    net["bus"]["mv"] = Dict("terminal_names" => ["a","b","c"])
    net["line"]["copy"]["bus_to"] = "mv"
    vl = Dict("bus_voltage_map" => Dict("s"=>230.0, "t"=>230.0, "mv"=>11000.0))
    r, _ = _interpretation_classify(net; voltage_levels=vl)
    c = r["evidence_by_linecode"]["three_wire"]["supporting_context"]
    @test c["line_ids"] == ["copy", "feeder"]
    @test c["lv_without_neutral_line_ids"] == ["feeder"]
    @test c["other_or_unassessed_line_ids"] == ["copy"]
    for invalid_map in (["a","a","c"], ["a","b","n"], ["a","b"], nothing)
        net["line"]["feeder"]["terminal_map_to"] = invalid_map
        r, _ = _interpretation_classify(net; voltage_levels=vl)
        @test isempty(r["evidence_by_linecode"]["three_wire"]["supporting_context"]["lv_without_neutral_line_ids"])
    end
    net = _interpretation_fixture()
    for bus in values(net["bus"]); push!(bus["terminal_names"], "n"); end
    net["switch"] = Dict("neutral" => Dict("bus_from"=>"s", "bus_to"=>"t",
        "terminal_map_from"=>["n"], "terminal_map_to"=>["n"]))
    r, _ = _interpretation_classify(net)
    @test isempty(r["evidence_by_linecode"]["three_wire"]["supporting_context"]["lv_without_neutral_line_ids"])
    net["switch"]["neutral"]["open_switch"] = true
    r, _ = _interpretation_classify(net)
    @test r["evidence_by_linecode"]["three_wire"]["supporting_context"]["lv_without_neutral_line_ids"] == ["feeder"]
    # Insertion order does not affect evidence, including bounded context lists.
    reversed = deepcopy(net)
    reversed["line"] = Dict(reverse(collect(reversed["line"])))
    @test first(_interpretation_classify(net)) == first(_interpretation_classify(reversed))
    for i in 1:12
        net["line"]["extra_$(lpad(i, 2, '0'))"] = deepcopy(net["line"]["feeder"])
    end
    r, _ = _interpretation_classify(net)
    c = r["evidence_by_linecode"]["three_wire"]["supporting_context"]
    @test c["n_lines"] == c["n_lv_without_neutral_lines"] == 13
    @test c["n_other_or_unassessed_lines"] == 0
    @test length(c["line_ids"]) == length(c["lv_without_neutral_line_ids"]) == c["witness_limit"] == 5
    @test c["witnesses_truncated"]
    reversed["line"] = Dict(reverse(collect(net["line"])))
    @test first(_interpretation_classify(net)) == first(_interpretation_classify(reversed))
end

@testset "balanced and decoupled signatures retain useful hypotheses" begin
    net = _interpretation_fixture(); lc = net["linecode"]["three_wire"]
    for i in 1:3, j in 1:3
        lc["R_series_$(i)_$(j)"] = i == j ? 2.0 : 1.0
        lc["X_series_$(i)_$(j)"] = i == j ? 3.0 : 0.3
    end
    _, fs = _interpretation_classify(net)
    seq = only(filter(f -> f.code == "I.PROV.SEQ_DERIVED", fs))
    @test _has_hint(seq.detail["interpretation"]["possible_explanations"], "sequence_parameterisation")
    @test _has_hint(seq.detail["interpretation"]["alternatives"], "symmetric_construction")
    @test seq.detail["sequence_applicability"] == "unassessed"
    @test seq.detail["interpretation"]["observations"]["by_linecode"]["three_wire"]["z1"] == Dict("r"=>1.0, "x"=>2.7)
    mpn = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_MPN", fs))
    @test _has_hint(mpn.detail["interpretation"]["suggested_checks"], "asymmetry")
    @test mpn.detail["interpretation"]["observations"]["also_exactly_balanced"] == ["three_wire"]
    lc["X_series_1_2"] = lc["X_series_2_1"] = 0.8
    _, fs = _interpretation_classify(net)
    pn = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_PN", fs))
    @test _has_hint(pn.detail["interpretation"]["possible_explanations"], "phase_to_neutral")
    for i in 1:3, j in 1:3
        i == j && continue
        lc["R_series_$(i)_$(j)"] = lc["X_series_$(i)_$(j)"] = 0.0
    end
    _, fs = _interpretation_classify(net)
    dec = only(filter(f -> f.code == "I.PROV.DECOUPLED_PHASES", fs))
    @test _has_hint(dec.detail["interpretation"]["suggested_checks"], "coordinate_basis")
    @test _has_hint(dec.detail["interpretation"]["implications"], "z0_equals_z1")
    @test dec.detail["interpretation"]["observations"]["signature"] == "negligible_series_coupling"
    @test !any(f -> f.code == "I.PROV.SEQ_DERIVED", fs)
    for key in keys(lc); lc[key] = 0.0; end
    r, fs = _interpretation_classify(net)
    @test r["by_linecode"]["three_wire"] == "unknown"
    @test !any(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs)
    for key in collect(keys(lc)); startswith(key, "X_series_") && delete!(lc, key); end
    r, fs = _interpretation_classify(net)
    @test r["evidence_by_linecode"]["three_wire"]["status"] == "indeterminate"
    @test !any(f -> startswith(f.code, "I.PROV.IMPEDANCE_TRANSFORM_"), fs)
    for n in (2, 4)
        net["linecode"]["three_wire"] = Dict{String,Any}(
            "$(kind)_series_$(i)_$(j)" => (i == j ? 2.0 : 0.1)
            for kind in ("R", "X") for i in 1:n for j in 1:n)
        r, fs = _interpretation_classify(net)
        @test isempty(r)
        @test !any(f -> startswith(f.code, "I.PROV.IMPEDANCE_TRANSFORM_"), fs)
    end
    # Nonfinite entries are not evidence for any transformation candidate.
    net = _interpretation_fixture()
    net["linecode"]["three_wire"]["X_series_1_1"] = NaN
    fs = Finding[]
    dimensions = Dict{String,Any}("by_linecode" => Dict("three_wire" => Dict("n_conductors" => 3)))
    r = BMOPFTools._classify_impedance_transformation(net, fs, dimensions)
    @test r["evidence_by_linecode"]["three_wire"]["status"] == "indeterminate"
    @test r["by_linecode"]["three_wire"] == "unknown"
    @test isempty(fs)
end

@testset "Kron candidate cross-references the sequence signature" begin
    net = _interpretation_fixture(); lc = net["linecode"]["three_wire"]
    for i in 1:3, j in 1:3
        lc["R_series_$(i)_$(j)"] = i == j ? 2.0 : 0.4  # balanced, but R mutual/self 0.2 ≠ ½
        lc["X_series_$(i)_$(j)"] = i == j ? 3.0 : 1.0
    end
    _, fs = _interpretation_classify(net)
    @test any(f -> f.code == "I.PROV.SEQ_DERIVED", fs)
    kr = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs))
    @test kr.detail["interpretation"]["observations"]["also_exactly_balanced"] == ["three_wire"]
    @test occursin("I.PROV.SEQ_DERIVED", kr.message)
end

@testset "converter source equivalents are not provenance hints" begin
    net = _interpretation_fixture(); lc = net["linecode"]["three_wire"]
    lc["source"] = "OpenDSS Vsource.source Thevenin impedance"
    r, fs = _interpretation_classify(net)
    @test !any(f -> startswith(f.code, "I.PROV.IMPEDANCE_TRANSFORM_"), fs)
    @test r["evidence_by_linecode"]["three_wire"]["finding_suppressed"] == "source_thevenin_equivalent"
    @test r["by_linecode"]["three_wire"] == "kron_reduced" # classification itself is unchanged
    for i in 1:3, j in 1:3
        lc["R_series_$(i)_$(j)"] = i == j ? 2.0 : 0.4
        lc["X_series_$(i)_$(j)"] = i == j ? 3.0 : 1.0
    end
    _, fs = _interpretation_classify(net)
    @test !any(f -> f.code == "I.PROV.SEQ_DERIVED", fs)
    report = analyze(net)
    @test occursin("1 source equivalent(s) not flagged", sprint(io -> BMOPFTools.render_terminal(report, io)))
    lc["source"] = "Manufacturer datasheet"
    _, fs = _interpretation_classify(net)
    @test any(f -> f.code == "I.PROV.SEQ_DERIVED", fs)
end

@testset "every interpretation is complete and catalogued" begin
    for (code, spec) in BMOPFTools._FINDING_INTERPRETATIONS
        @test explain_finding(code)["code"] == code
        record = BMOPFTools._finding_interpretation(code, Dict{String,Any}())
        for key in ("possible_explanations", "implications", "alternatives", "suggested_checks")
            @test !isempty(record[key])
            ids = BMOPFTools._interpretation_ids(record[key])
            @test allunique(ids)
            @test all(h -> !isempty(h["text"]), record[key])
        end
        @test record["automation_guidance"]["disposition"] == "review"
        record["possible_explanations"][1]["text"] = "mutated"
        @test spec.explanations[1]["text"] != "mutated" # records are copies
    end
    @test_throws ErrorException BMOPFTools._finding_interpretation("I.UNKNOWN.CODE", Dict{String,Any}())
end
