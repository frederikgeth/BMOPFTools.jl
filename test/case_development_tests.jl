using Test, BMOPFTools, JSON3

_case_dev_base() = parse_bmopf(joinpath(@__DIR__, "data", "case_development", "feeder.json"))

@testset "Case development: selections and budgets" begin
    base = _case_dev_base(); saved = deepcopy(base)
    schema_findings = Finding[]
    schema_check(base, schema_findings)
    @test isempty(filter(f -> f.severity == ERROR, schema_findings))
    for (builder, recipe, family, field) in (
        (add_ibrs, IBRRecipe, "ibr", "s_max"),
        (add_generators, GeneratorRecipe, "generator", "p_max"))
        r = recipe(bus_ids=["near", "far"], phase_by_bus=Dict("far"=>"2"), capacity_budget=12000.0)
        net, mf = builder(base; recipe=r)
        @test sum(sum(d[field]) for d in values(net[family])) ≈ 12000.0
        far = only(d for d in values(net[family]) if d["bus"] == "far")
        @test far["terminal_map"] == ["2", "n"]
        @test length(far[field]) == 1
        d = manifest_to_dict(mf)
        @test d["recipe"]["parameters"]["capacity_budget"] == 12000.0
        @test JSON3.read(JSON3.write(d)).recipe.parameters.phase_by_bus.far == "2"
        @test all(haskey(f, "detail") && haskey(f, "section") for f in d["findings_after"])
        @test_throws ArgumentError builder(base; recipe=recipe(bus_ids=["missing"]))
        @test_throws ArgumentError builder(base; recipe=recipe(bus_ids=["far", "far"]))
        @test_throws ArgumentError builder(base; recipe=recipe(capacity_budget=-1.0))
        @test_throws ArgumentError builder(base; recipe=recipe(phase_by_bus=Dict("far"=>"n")))
        @test_throws ArgumentError builder(base; recipe=recipe(bus_ids=String[], capacity_budget=1.0))
        empty, _ = builder(base; recipe=recipe(capacity_budget=0.0))
        @test isempty(empty[family])
    end
    @test base == saved
    @test_throws ArgumentError add_ibrs(base; recipe=IBRRecipe(
        capacity_budget=100.0, s_fraction=Inf))
end

@testset "Case development: independent operating points" begin
    base, _ = add_ibrs(_case_dev_base(); recipe=IBRRecipe(capacity_budget=12000.0))
    base, _ = augment_case(base)
    original = deepcopy(base)
    scenario = CaseScenario(name="midday", demand_scale=0.4, reactive_scale=0.7, pv_scale=0.8)
    net, mf = materialize_scenario(base, scenario)
    @test net["load"]["far"]["p_nom"] ≈ 0.4 .* base["load"]["far"]["p_nom"]
    @test net["load"]["far"]["q_nom"] ≈ 0.7 .* base["load"]["far"]["q_nom"]
    @test net["ibr"]["pv_far"]["p_avail"] ≈ 0.8 * base["ibr"]["pv_far"]["p_avail"]
    for field in ("s_max", "q_min", "q_max", "p_min")
        @test net["ibr"]["pv_far"][field] == base["ibr"]["pv_far"][field]
    end
    @test net["ibr"]["pv_far"]["p_max"] ≈ 0.8 .* base["ibr"]["pv_far"]["p_max"]
    night, _ = materialize_scenario(base, CaseScenario(pv_scale=0.0))
    @test night["ibr"]["pv_far"]["p_avail"] == 0.0
    @test all(iszero, night["ibr"]["pv_far"]["p_max"])
    @test base == original
    @test first(materialize_scenario(base, scenario)) == net
    @test_throws ArgumentError materialize_scenario(base, CaseScenario(demand_scale=NaN))
    @test_throws ArgumentError materialize_scenario(base, CaseScenario(pv_scale=-1.0))
    @test_throws ArgumentError materialize_scenario(base, CaseScenario(pv_ids=["missing"]))
    @test_throws ArgumentError materialize_scenario(base, CaseScenario(name=""))
    ts = deepcopy(base)
    ts["time_series"] = Dict{String,Any}("demand"=>Dict("values"=>[0.5, 1.5]))
    ts["load"]["far"]["time_series"] = Dict("p_nom"=>"demand")
    @test_throws ArgumentError materialize_scenario(ts, CaseScenario())
    snap, _ = materialize_scenario(ts, CaseScenario(t_index=2, demand_scale=0.4))
    @test snap["load"]["far"]["p_nom"] ≈ 0.6 .* base["load"]["far"]["p_nom"]
    @test !is_timeseries(snap)

    mktempdir() do dir
        source = joinpath(@__DIR__, "data", "case_development", "feeder.json")
        log = write_case_log(net, joinpath(dir, "case.json"); manifests=[mf],
            assumptions=["Illustrative PV scale"], source_paths=[source], settings=Dict("seed"=>42))
        @test length(log["sources"][1]["sha256"]) == 64
        @test JSON3.read(read(joinpath(dir, "case.json"), String)).settings.seed == 42
        @test haskey(log["transformations"][1]["recipe"], "parameters")
        other = Dict{String,Any}(reverse(collect(net)))
        @test BMOPFTools._case_hash(other) == log["case_sha256"]
        @test BMOPFTools._case_hash(base) != log["case_sha256"]
        write_case_log(net, joinpath(dir, "case.md"); manifests=[mf])
        @test isfile(joinpath(dir, "case.md"))
        @test_throws ArgumentError write_case_log(net, joinpath(dir, "case.txt"))
    end
end

@testset "Case development: failures remain in sweeps" begin
    base = _case_dev_base()
    specs = [CaseScenario(name="bad_input", demand_scale=-1), CaseScenario(name="failed_solve")]
    rows = run_case_sweep(base, specs; solve=n -> error("test solver failure"))
    @test length(rows) == 2
    @test rows[1]["error_stage"] == "materialize"
    @test rows[2]["error_stage"] == "solve"
    @test rows[2]["verification"] === nothing
    @test_throws ArgumentError run_case_sweep(base, [CaseScenario(), CaseScenario()]; solve=identity)
    @test_throws InterruptException run_case_sweep(base, [CaseScenario()]; solve=n -> throw(InterruptException()))
    saved = deepcopy(base)
    unsolved = run_case_sweep(base, [CaseScenario()]; solve=n -> begin
        empty!(n)
        Dict{String,Any}("termination_status"=>"TIME_LIMIT", "primal_status"=>"NO_SOLUTION")
    end, keep_results=true)
    @test base == saved
    row = only(unsolved)
    @test row["status"] == "completed"
    @test row["termination_status"] == "TIME_LIMIT"
    @test row["verification"]["results"]["solution"]["verification_status"] == "indeterminate"
    @test row["result"]["primal_status"] == "NO_SOLUTION"
    @test JSON3.read(JSON3.write(row)).termination_status == "TIME_LIMIT"
end

@testset "Case development: availability boundaries and diagnostic scope" begin
    base, _ = add_ibrs(_case_dev_base(); recipe=IBRRecipe(capacity_budget=12000.0))
    inv = base["ibr"]["pv_far"]
    inv["s_max"] = [1000.0, 2000.0, 3000.0]
    inv["p_avail"] = 3000.0
    inv["p_max"] = [400.0, 2000.0, 3000.0]
    inv["p_min"] = [100.0, 100.0, 100.0]
    net, _ = materialize_scenario(base, CaseScenario())
    @test net["ibr"]["pv_far"]["p_max"] == [400.0, 1000.0, 1500.0]
    night, _ = materialize_scenario(base, CaseScenario(pv_scale=0.0))
    @test night["ibr"]["pv_far"]["p_min"] == [100.0, 100.0, 100.0]
    @test all(iszero, night["ibr"]["pv_far"]["p_max"])
    inv["s_max"] = [-1.0, 2.0, 3.0]
    @test_throws ArgumentError materialize_scenario(base, CaseScenario())
    inv["s_max"] = [1000.0, 2000.0, 3000.0]
    inv["topology"] = "UNKNOWN"
    @test_throws ArgumentError materialize_scenario(base, CaseScenario())

    # Spatially unbalanced loads can have exactly balanced aggregate totals.
    net = _case_dev_base()
    net["load"]["near"]["p_nom"] = [2000.0, 1000.0, 0.0]
    net["load"]["far"]["p_nom"] = [0.0, 1000.0, 2000.0]
    report = analyze(net)
    f = only(f for f in report.findings if f.code == "I.DIV.LOAD_PHASE_BALANCED")
    @test f.detail["single_phase_applicability"] == "unassessed"
    @test f.detail["knowledge_ids"] == ["PSK-000009"]
    net["load"]["far"]["p_nom"][1] += 1000.0
    @test !any(f -> f.code == "I.DIV.LOAD_PHASE_BALANCED", analyze(net).findings)
end
