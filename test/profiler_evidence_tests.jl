using Test, BMOPFTools, JSON3

_profiler_fixture() = JSON3.read(read(joinpath(@__DIR__, "data", "profiler_evidence", "two_boundary_chain.json"), String), Dict{String,Any})
_profiler_reach(net; config=load_config()) = BMOPFTools._feeder_length_check(net, BMOPFTools._galvanic_zones(net), Finding[], config)
_profiler_lv(rows) = only(filter(r -> r["n_buses"] == 5, rows))

@testset "profiler winding declaration coverage" begin
    net = _profiler_fixture(); original = deepcopy(net); fs = Finding[]
    c = BMOPFTools._winding_limit_coverage(net, fs)
    @test net == original
    @test c["transformer_counts"]["absent"] == 2
    @test c["n_windings_without_caps"] == 4
    @test only(fs).code == "W.OPS.XFMR_UNCONSTRAINED"
    @test c["direct_neutral_current"] == "unsupported"
    ws = net["transformer"]["n_winding"]["left"]["windings"]
    ws[1]["i_max"] = 0.0
    c = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test c["transformer_counts"]["partial"] == 1
    @test c["windings"][1]["limits"]["i_max"]["supported"]
    @test c["windings"][1]["limits"]["s_max"]["state"] == "absent"
    @test c["windings"][1]["limits"]["i_max"]["field_path"] == ["transformer", "n_winding", "left", "windings", 1, "i_max"]
    ws[2]["s_max"] = 1000.0
    @test BMOPFTools._winding_limit_coverage(net, Finding[])["transformer_counts"]["present"] == 1
    for value in (-1.0, NaN, "10", [10.0], true, 1e300, 1e-300)
        ws[1]["i_max"] = value
        c = BMOPFTools._winding_limit_coverage(net, Finding[])
        @test c["transformer_counts"]["malformed"] == 1
        @test !c["windings"][1]["limits"]["i_max"]["supported"]
    end
    ws[1]["i_max"] = Inf; delete!(ws[2], "s_max")
    c = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test c["windings"][1]["limits"]["i_max"]["state"] == "unbounded"
    @test !c["windings"][1]["limits"]["i_max"]["supported"]
    @test c["n_windings_without_caps"] == 4
    ws[1]["i_max"] = 2.0; ws[1]["terminal_map"] = ["custom", "n"]
    net["bus"]["up"]["terminal_names"] = ["custom", "n"]
    @test BMOPFTools._winding_limit_coverage(net, Finding[])["transformer_counts"]["unsupported"] >= 1
    ws[1] = nothing
    c = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test c["windings"][2]["winding"] == 2 # malformed entries never renumber ports
    net = _profiler_fixture()
    net["transformer"]["single_phase"] = Dict("legacy" => Dict("s_rating" => 1000.0))
    c = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test c["transformer_counts"]["unsupported"] == 1
    decoded = JSON3.read(JSON3.write(BMOPFTools._jsonable(c)))
    @test decoded.n_windings_without_caps == 4
    @test decoded.transformers[3].status == "inapplicable"
    many = _profiler_fixture(); devices = many["transformer"]["n_winding"]
    for i in 1:10; devices["extra$i"] = deepcopy(devices["left"]); end
    fs = Finding[]; c = BMOPFTools._winding_limit_coverage(many, fs)
    @test only(fs).detail["witnesses_truncated"]
    @test length(only(fs).detail["witnesses"]) == 5
    @test c["n_windings_without_caps"] == 24
end

@testset "profiler nearest-boundary distances" begin
    net = _profiler_fixture(); original = deepcopy(net)
    lv = _profiler_lv(_profiler_reach(net))
    @test net == original
    @test lv["anchor_extent_m"] == lv["reach_m"] == 400.0
    @test lv["boundary_reach_m"] == 200.0 # independent four-edge chain oracle
    @test lv["n_qualified_boundary_buses"] == 2
    @test lv["n_incident_transformers"] == 2
    @test lv["n_incident_windings"] == 2
    @test lv["threshold_status"] == "unassessed"
    @test lv["threshold_reason"] == "no_metric_specific_thresholds"
    @test lv["path_witness"]["farthest_bus"] == "c"
    @test lv["path_witness"]["n_path_edges"] == 2
    @test length(lv["port_path_witnesses"]) == 1
    cfg = load_config()
    cfg["operational"]["feeder_length"]["LV"]["multi_boundary"] = Dict("reach_short_m" => 250.0)
    fs = Finding[]
    BMOPFTools._feeder_length_check(net, BMOPFTools._galvanic_zones(net), fs, cfg)
    f = only(filter(f -> f.code == "I.OPS.FEEDER_SHORT", fs))
    @test f.detail["boundary_reach_m"] == 200.0
    @test f.detail["reach_m"] == 400.0 # legacy field has not been reinterpreted
    @test startswith(f.detail["metric"], "max_shortest")
    reordered = deepcopy(net)
    for key in ("bus", "line")
        reordered[key] = Dict(reverse(collect(reordered[key])))
    end
    reordered["transformer"]["n_winding"] = Dict(reverse(collect(reordered["transformer"]["n_winding"])))
    @test _profiler_reach(net) == _profiler_reach(reordered)
    # Relabeling changes the display anchor to the middle, but not supply distance.
    renamed = deepcopy(net); mapping = Dict(b => b == "c" ? "0_middle" : "z_$b" for b in keys(net["bus"]))
    renamed["bus"] = Dict(mapping[b] => v for (b,v) in renamed["bus"])
    for l in values(renamed["line"]), side in ("from", "to"); l["bus_$side"] = mapping[l["bus_$side"]]; end
    for xf in values(renamed["transformer"]["n_winding"]), w in xf["windings"]; w["bus"] = mapping[w["bus"]]; end
    renamed["voltage_source"]["source"]["bus"] = mapping["up"]
    renamed["load"]["demand"]["bus"] = mapping["c"]
    relabeled = _profiler_lv(_profiler_reach(renamed))
    @test relabeled["boundary_reach_m"] == lv["boundary_reach_m"]
    @test relabeled["anchor_extent_m"] == 200.0
    @test relabeled["status"] == lv["status"]
    fs = Finding[]; BMOPFTools._feeder_length_check(renamed, BMOPFTools._galvanic_zones(renamed), fs, cfg)
    @test count(f -> f.code == "I.OPS.FEEDER_SHORT", fs) == 1
    for value in (nothing, -1.0, NaN, Inf)
        bad = deepcopy(net)
        value === nothing ? delete!(bad["line"]["0"], "length") : (bad["line"]["0"]["length"] = value)
        row = _profiler_lv(_profiler_reach(bad))
        @test row["status"] == "indeterminate"
        @test row["boundary_reach_m"] === nothing
        @test "line:0" in row["invalid_branches"]
    end
    regularized = deepcopy(net); regularized["line"]["0"]["meta"] = Dict("electrical_length_regularized" => true, "physical_length_m" => 10000.0)
    row = _profiler_lv(_profiler_reach(regularized; config=cfg))
    @test row["boundary_reach_m"] == 200.0
    @test row["threshold_reason"] == "regularized_electrical_lengths"
    unknown = deepcopy(net); delete!(unknown, "voltage_source")
    @test _profiler_lv(_profiler_reach(unknown))["reason"] == "no_qualified_boundary"
    conflict = deepcopy(net); conflict["voltage_source"]["other"] = Dict("bus" => "up", "terminal_map" => ["a"], "v_magnitude" => [2000.0])
    @test _profiler_lv(_profiler_reach(conflict))["status"] == "indeterminate"
    reversed_windings = deepcopy(net)
    for xf in values(reversed_windings["transformer"]["n_winding"]); reverse!(xf["windings"]); end
    @test _profiler_lv(_profiler_reach(reversed_windings))["boundary_reach_m"] == 200.0
    # The n-winding DELTA nominal is a coil line-to-line voltage, not the bus phase base.
    delta = deepcopy(net)
    for b in values(delta["bus"]); b["terminal_names"] = ["a","b","c","n"]; end
    source = delta["voltage_source"]["source"]
    source["terminal_map"] = ["a","b","c"]; source["v_magnitude"] = fill(11000.0,3)
    for xf in values(delta["transformer"]["n_winding"])
        xf["windings"][1]["configuration"] = "DELTA"
        xf["windings"][1]["terminal_map"] = ["a","b","c"]
        xf["windings"][1]["v_nom"] = 11000*sqrt(3.0)
        xf["windings"][2]["terminal_map"] = ["a","b","c","n"]
    end
    @test _profiler_lv(_profiler_reach(delta))["v_nom"] == 230.0
    @test _profiler_lv(_profiler_reach(delta))["boundary_reach_m"] == 200.0
    # A consistent terminal relabeling with explicit roles preserves graph evidence.
    terminal = deepcopy(net); terminal["terminal_conventions"] = Dict("phase"=>["phase"], "neutral"=>["return"], "earth"=>String[])
    rename_tm(tm) = [t == "a" ? "phase" : "return" for t in tm]
    for b in values(terminal["bus"]); b["terminal_names"] = rename_tm(b["terminal_names"]); end
    terminal["voltage_source"]["source"]["terminal_map"] = ["phase"]
    for xf in values(terminal["transformer"]["n_winding"]), w in xf["windings"]; w["terminal_map"] = rename_tm(w["terminal_map"]); end
    for l in values(terminal["line"]), key in ("terminal_map_from", "terminal_map_to"); l[key] = rename_tm(l[key]); end
    @test _profiler_lv(_profiler_reach(terminal))["boundary_reach_m"] == 200.0
    multiport = deepcopy(net)
    push!(multiport["transformer"]["n_winding"]["left"]["windings"], deepcopy(multiport["transformer"]["n_winding"]["left"]["windings"][2]))
    row = _profiler_lv(_profiler_reach(multiport))
    @test row["status"] == "indeterminate"
    @test row["n_incident_transformers"] == 2
    @test row["n_incident_windings"] == 3
    parallel = deepcopy(net); parallel["line"]["extra"] = deepcopy(parallel["line"]["0"])
    @test _profiler_lv(_profiler_reach(parallel))["boundary_reach_m"] == 200.0
    switched = deepcopy(net); sw = pop!(switched["line"], "2"); delete!(sw, "length"); sw["open_switch"] = true
    switched["switch"] = Dict("tie" => sw)
    rows = _profiler_reach(switched)
    @test length(rows) == 3
    @test sort([r["boundary_reach_m"] for r in rows if r["n_buses"] > 1]) == [100.0, 200.0]
    sw["open_switch"] = false
    @test _profiler_lv(_profiler_reach(switched))["boundary_reach_m"] == 100.0
    sw["open_switch"] = "unknown"
    row = only(filter(r -> r["n_buses"] == 5, BMOPFTools._feeder_length_check(switched, [Set(["up"]), Set(["a","b","c","d","e"])], Finding[], cfg)))
    @test row["status"] == "indeterminate"
    decoded = JSON3.read(JSON3.write(BMOPFTools._jsonable(lv)))
    @test decoded.boundary_reach_m == 200.0
end

@testset "profiler hypotheses remain separate from matrix history" begin
    matrix = Dict{String,Any}("R_series_$(i)_$(j)" => (i == j ? i+2.0 : 0.1*(i+j)) for i in 1:3 for j in 1:3)
    merge!(matrix, Dict("X_series_$(i)_$(j)" => (i == j ? i+1.0 : 0.1) for i in 1:3 for j in 1:3))
    net = Dict{String,Any}("linecode" => Dict("ASSUMED_KRON" => matrix))
    function classify(net)
        fs = Finding[]; lc = BMOPFTools._classify_linecodes(net, fs)
        result = BMOPFTools._classify_impedance_transformation(net, fs, lc)
        result, fs
    end
    r, fs = classify(net)
    @test r["classification_version"] == "2"
    @test r["by_linecode"]["ASSUMED_KRON"] == "kron_reduced"
    hint = only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs))
    @test hint.severity == INFO
    @test !hint.detail["history_verified"]
    @test haskey(hint.detail["interpretation"]["alternatives"], "native_three_wire")
    @test r["evidence_by_linecode"]["ASSUMED_KRON"]["history_status"] == "unknown"
    matrix["derivation"] = Dict("method" => "kron")
    r, _ = classify(net)
    @test r["evidence_by_linecode"]["ASSUMED_KRON"]["history_status"] == "declared_unverified"
    @test r["by_linecode"]["ASSUMED_KRON"] == "kron_reduced"
    for i in 1:3, j in 1:3
        matrix["R_series_$(i)_$(j)"] = i == j ? 2.0 : 1.0
        matrix["X_series_$(i)_$(j)"] = i == j ? 3.0 : 0.3
    end
    r, fs = classify(net)
    @test r["by_linecode"]["ASSUMED_KRON"] == "modified_phase_to_neutral"
    @test only(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_MPN", fs)).detail["history_verified"] === false
    @test only(filter(f -> f.code == "I.PROV.SEQ_DERIVED", fs)).detail["sequence_applicability"] == "unassessed"
    matrix["X_series_1_2"] = 0.8
    r, fs = classify(net)
    @test r["by_linecode"]["ASSUMED_KRON"] == "phase_to_neutral"
    for k in collect(keys(matrix)); startswith(k, "X_series_") && delete!(matrix, k); end
    r, fs = classify(net)
    @test r["by_linecode"]["ASSUMED_KRON"] == "unknown"
    @test r["evidence_by_linecode"]["ASSUMED_KRON"]["status"] == "indeterminate"
    @test !any(f -> f.code in ("I.PROV.IMPEDANCE_TRANSFORM_PN", "I.PROV.IMPEDANCE_TRANSFORM_MPN", "I.PROV.SEQ_DERIVED", "I.PROV.DECOUPLED_PHASES"), fs)
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).by_linecode.ASSUMED_KRON == "unknown"
end

@testset "profiler parallel and repetition counts" begin
    net = _profiler_fixture()
    for k in ("copy1", "copy2"); net["line"][k] = deepcopy(net["line"]["0"]); end
    # Separate genuine circuits are still legitimate review context.
    net["line"]["different"] = deepcopy(net["line"]["1"]); net["line"]["different"]["length"] = 50.0
    p = BMOPFTools._parallel_line_evidence(net)
    @test p["classification_counts"]["same_declared_fields"] == 1
    @test p["classification_counts"]["different_declared_fields"] == 1
    @test p["n_parallel_excess"] == 3
    @test p["n_identical_group_excess"] == 2
    @test p["multiplicity_counts"] == Dict("2"=>1, "3"=>1)
    fs = Finding[]; BMOPFTools._check_parallel_lines(net, fs)
    @test only(fs).detail["classification_counts"] == p["classification_counts"]
    @test !haskey(only(fs).detail, "groups")
    # Reversed endpoint shunts and signed angle limits normalize together.
    first = net["line"]["0"]; first["B_from_1_1"] = 1.0; first["B_to_1_1"] = 2.0
    first["va_diff_min"] = -0.1; first["va_diff_max"] = 0.2
    reverse = deepcopy(first); reverse["bus_from"], reverse["bus_to"] = reverse["bus_to"], reverse["bus_from"]
    reverse["B_from_1_1"], reverse["B_to_1_1"] = reverse["B_to_1_1"], reverse["B_from_1_1"]
    reverse["va_diff_min"], reverse["va_diff_max"] = -reverse["va_diff_max"], -reverse["va_diff_min"]
    pair = Dict{String,Any}("line" => Dict("forward"=>first, "reverse"=>reverse))
    @test BMOPFTools._parallel_line_evidence(pair)["classification_counts"]["same_declared_fields"] == 1
    reverse["terminal_map_from"] = ["b", "n"]
    @test BMOPFTools._parallel_line_evidence(pair)["classification_counts"]["terminal_map_disagreement"] == 1
    loads = Dict{String,Any}()
    for (group, n) in enumerate((4,3,1)), j in 1:n
        loads["$group-$j"] = Dict("p_nom"=>[Float64(group)], "q_nom"=>[0.0])
    end
    r = BMOPFTools._load_repeat_evidence(loads)
    @test (r["n_total_loads"], r["n_distinct_pq_tuples"], r["n_excess_repetitions"], r["largest_group_count"],
        r["n_repeated_groups"], r["n_members_of_repeated_groups"]) == (8,3,5,4,2,7)
    @test BMOPFTools._load_repeat_evidence(Dict(Base.reverse(collect(loads)))) == r
    loads["invalid"] = Dict("p_nom"=>[1.0], "q_nom"=>[])
    @test BMOPFTools._load_repeat_evidence(loads)["n_excluded_loads"] == 1
    fs = Finding[]; BMOPFTools._load_diversity(Dict{String,Any}("load"=>loads), fs)
    @test only(filter(f -> f.code == "W.DIV.LOAD_SYMMETRIC", fs)).detail["n_duplicates"] == 5
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).n_members_of_repeated_groups == 7
    for i in 1:10; loads["copy$i"] = Dict("p_nom"=>[1.0], "q_nom"=>[0.0]); end
    r = BMOPFTools._load_repeat_evidence(loads)
    @test r["witnesses"][1]["members_truncated"]
    @test length(r["witnesses"][1]["load_ids"]) == 5
end

@testset "profiler coverage and ordinary reports" begin
    net = _profiler_fixture(); report = analyze(net)
    coverage = report.results[:assessment]
    @test coverage["comprehensive_validation"] === false
    @test only(filter(c -> c["check"] == "nominal_coil_headroom", coverage["checks"]))["status_counts"]["inapplicable"] == 2
    @test only(filter(c -> c["check"] == "spatial_analysis", coverage["checks"]))["status"] == "inapplicable"
    unknown = deepcopy(net); unknown["meta"] = Dict("\$schema"=>"https://example.org/unknown")
    schema = schema_check(unknown, Finding[])
    c = BMOPFTools._assessment_coverage(Dict(:schema=>schema))
    @test only(filter(x -> x["check"] == "structural_schema", c["checks"]))["status"] == "skipped"
    for renderer in (BMOPFTools.render_terminal, BMOPFTools.render_markdown)
        io = IOBuffer(); renderer(report, io); text = String(take!(io))
        @test occursin("Assessment coverage", text)
        @test occursin("Winding limit coverage", text)
        @test occursin("nearest-boundary maximum 200.0 m", text)
        @test occursin("2 distinct transformers", text)
    end
    io=IOBuffer(); BMOPFTools.render_json(report, io); decoded=JSON3.read(String(take!(io)))
    @test decoded.results.assessment.comprehensive_validation === false
    @test decoded.results.operational.winding_limit_coverage.n_windings_without_caps == 4
    response = execute_analysis(net)
    @test response["status"] == "completed"
    @test response["result"]["results"]["assessment"]["comprehensive_validation"] === false
end
