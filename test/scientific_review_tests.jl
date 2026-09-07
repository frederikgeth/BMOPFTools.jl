using Test, BMOPFTools, JSON3, JSONSchema, LinearAlgebra

@testset "Scientific review — independent result acceptance (PSK-000003)" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "claimed-feasible-invalid-solution")
    data = joinpath(@__DIR__, "data", "scientific_review")
    net = parse_bmopf(joinpath(fixture, "network.json"))
    read_result(path) = JSON3.read(read(path, String), Dict{String,Any})
    good = read_result(joinpath(fixture, "validated-result.json"))
    bad = read_result(joinpath(data, "inconsistent-phasor-result.json"))
    original = deepcopy(bad)
    for r in (bad, JSON3.read(JSON3.write(bad), Dict{String,Any}))
        c = check_claimed_solution_validity(net, r)
        @test c.status == :failed
        @test "E.SOL.PHASOR_INCONSISTENT" in [f["code"] for f in c.evidence["blocking_solution_findings"]]
        @test "E.SOL.VOLT_VIOLATION" in [f["code"] for f in c.evidence["blocking_solution_findings"]]
    end
    @test bad == original
    typed = Dict{String,Any}("termination_status"=>"OPTIMAL",
        "bus"=>Dict("study_bus"=>Dict(t=>Dict{String,Float64}(vals)
            for (t,vals) in bad["bus"]["study_bus"])))
    @test check_claimed_solution_validity(net, typed).evidence["solution_summary"]["n_volt_violations"] == 1
    @test check_claimed_solution_validity(net, good).status == :passed
    # Serialization noise is comfortably inside the existing 0.2% tolerance.
    rounded = deepcopy(good)
    rounded["bus"]["study_bus"]["a"]["vm"] *= 1.0001
    @test check_claimed_solution_validity(net, rounded).status == :passed
    # Existing component dictionaries are not enough if their checked values are missing.
    incomplete_net = deepcopy(net)
    incomplete_net["line"] = Dict("l"=>Dict("terminal_map_from"=>["a"], "i_max"=>[1.0]))
    incomplete = deepcopy(good); incomplete["line"] = Dict("l"=>Dict("a"=>Dict()))
    fs = Finding[]; incomplete_summary = solution_check(incomplete_net, incomplete, fs)
    @test "line.l.a.cm_fr" in incomplete_summary["missing_result_fields"]
    @test !incomplete_summary["feasible"]
    for r in (Dict{String,Any}("termination_status"=>"OPTIMAL"),
              Dict{String,Any}("termination_status"=>"TIME_LIMIT"))
        fs = Finding[]; s = solution_check(net, r, fs)
        @test s["verification_status"] == "indeterminate"
        @test !s["feasible"]
    end
    timed = deepcopy(good)
    timed["termination_status"] = "TIME_LIMIT"
    timed["primal_status"] = "FEASIBLE_POINT"
    timed["voltage_source"] = Dict("source"=>Dict{String,Any}())
    fs = Finding[]; s = solution_check(net, timed, fs)
    @test s["solver_claimed_feasible"]
    @test !any(f -> f.code == "E.SOL.INFEASIBLE", fs)
    @test haskey(s, "n_volt_violations")
    timed["bus"]["study_bus"]["a"] = Dict("vr"=>230.0,"vi"=>0.0,"vm"=>230.0)
    timed["voltage_source"]["source"]["a"] = Dict("ps"=>1000.0,"qs"=>0.0)
    fs = Finding[]; s = solution_check(net, timed, fs)
    @test any(f -> f.code == "W.SOL.POWER_BALANCE", fs)
    @test s["verification_status"] == "failed"
    wrong_source = deepcopy(good)
    wrong_source["bus"]["study_bus"]["a"] = Dict("vr"=>250.0,"vi"=>0.0,"vm"=>250.0)
    fs = Finding[]; solution_check(net, wrong_source, fs)
    @test any(f -> f.code == "E.SOL.REFERENCE_VIOLATION", fs)

    vnet = parse_bmopf(joinpath(data, "vuf-network.json"))
    vbad = read_result(joinpath(data, "vuf-result.json"))
    @test check_claimed_solution_validity(vnet, vbad).status == :failed
    # Independently synthesize Fortescue phasors at several positive-sequence scales.
    a = cis(2π/3)
    for scale in (0.9, 1.0, 1.1), ratio in (0.01, 0.02, 0.03)
        voltages = 230 * scale .* [1+ratio, a^2+a*ratio, a+a^2*ratio]
        r = Dict{String,Any}("termination_status"=>"OPTIMAL",
            "bus"=>Dict("b"=>Dict(t=>Dict("vr"=>real(v),"vi"=>imag(v),"vm"=>abs(v))
                for (t,v) in zip(["a","b","c"], voltages))))
        c = check_claimed_solution_validity(vnet, r)
        @test c.status == (ratio > 0.02 ? :failed : :passed)
        roundtrip = JSON3.read(JSON3.write(r), Dict{String,Any})
        @test check_claimed_solution_validity(vnet, roundtrip).status == c.status
        # Consistent role relabelling must leave the verdict unchanged.
        renamed_net = deepcopy(vnet); renamed = deepcopy(r)
        renamed_net["bus"]["b"]["terminal_names"] = ["x","y","z"]
        renamed["bus"]["b"] = Dict(t=>r["bus"]["b"][s] for (t,s) in zip(["x","y","z"],["a","b","c"]))
        @test check_claimed_solution_validity(renamed_net, renamed).status == c.status
    end
    zero = deepcopy(vbad)
    for vals in values(zero["bus"]["b"])
        vals["vr"] = vals["vi"] = vals["vm"] = 0.0
    end
    @test check_claimed_solution_validity(vnet, zero).status == :indeterminate
end

if Base.get_extension(BMOPFTools, :BMOPFOpfExt) !== nothing
    include("solution_candidate_tests.jl")
end

@testset "Scientific review — voltage augmentation domain" begin
    for (terms, angles, expected) in ((["a","b","n"], [0.0,π], 240.0),
                                     (["a","b","n"], [0.0,-2π/3], 120sqrt(3)))
        net = Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>terms,"va_nom"=>angles)))
        entries = BMOPFTools.TransformEntry[]
        BMOPFTools._apply_voltage_bounds!(net, entries, AugmentationRecipe(), Dict("b"=>120.0))
        @test only(net["bus"]["b"]["vpp_min"]) ≈ 0.9expected rtol=1e-10
        @test only(net["bus"]["b"]["vpp_max"]) ≈ 1.1expected rtol=1e-10
        @test !haskey(net["bus"]["b"], "vneg_max")
        @test !haskey(net["bus"]["b"], "vuf_max")
    end
    unknown = Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a","b","n"])))
    entries = BMOPFTools.TransformEntry[]
    BMOPFTools._apply_voltage_bounds!(unknown, entries, AugmentationRecipe(), Dict("b"=>120.0))
    @test !haskey(unknown["bus"]["b"], "vpp_max")
    @test any(e -> e.rule == "pair_voltage_reference_unknown", entries)
    # Reuse the OpenDSS center-tap fixture; the transformer topology supplies the reference.
    ct = from_dss(joinpath(@__DIR__, "data", "pf_comparison", "pf_center_tap_240.dss"))
    augmented, _ = augment_case(ct)
    for zone in BMOPFTools._classify_zones(ct)
        zone.topology == :split_phase || continue
        for bid in zone.buses
            b = augmented["bus"][bid]
            length(b["terminal_names"]) == 3 || continue
            haskey(b, "vpp_max") || continue
            @test !haskey(b, "vneg_max")
            @test only(b["vpp_max"]) > 240.0
        end
    end
end

@testset "Scientific review — series reduction refuses unsupported preservation" begin
    net = parse_bmopf(joinpath(@__DIR__, "data", "scientific_review", "pi-chain.json"))
    reduced = merge_series_lines(net; series_merge_policy=:exact)
    @test reduced["line"] == net["line"]
    @test any(e -> e["code"] == "PI_SHUNT_PRESENT", reduced["_simplification_log"])
    approximate = merge_series_lines(net)
    @test length(approximate["line"]) == 1
    @test only(values(approximate["line"]))["length"] == 2.0
    @test approximate["linecode"] == net["linecode"]
    risk = only(e for e in approximate["_simplification_log"] if e["code"] == "SERIES_MERGE_APPROXIMATE")
    @test risk["severity"] == "warning"
    @test risk["detail"]["shunts_redistributed"]
    @test !risk["detail"]["error_quantified"]
    @test Set(risk["detail"]["lines"]) == Set(["AB", "BC"])
    @test risk["detail"]["removed_bus"] == "B"
    @test JSON3.read(JSON3.write(risk), Dict{String,Any}) == risk
    @test length(net["line"]) == 2 # input remains unchanged
    @test merge_series_lines(net; series_merge_policy=:off)["line"] == net["line"]
    @test_throws ArgumentError merge_series_lines(net; series_merge_policy=:invalid)
    @test length(simplify_network(net; dangling_lines=false)["line"]) == 1
    @test length(simplify_network(net; dangling_lines=false, series_merge_policy=:exact)["line"]) == 2
    grounded = deepcopy(net); grounded["bus"]["B"]["perfectly_grounded_terminals"] = ["1"]
    @test length(merge_series_lines(grounded)["line"]) == 2
    # An independent nodal elimination shows why simply doubling length is wrong.
    Y = [1.1 -1.0 0.0; -1.0 2.2 -1.0; 0.0 -1.0 1.1]
    exact = Y[[1,3],[1,3]] - Y[[1,3],[2]] * (Y[[2],[2]] \ Y[[2],[1,3]])
    @test norm(exact - [0.7 -0.5; -0.5 0.7]) > 0.01
    for key in ("G_from_1_1", "G_to_1_1")
        net["linecode"]["lc"][key] = 0.0
    end
    @test length(merge_series_lines(net; series_merge_policy=:exact)["line"]) == 1
    @test !any(e -> e["code"] == "SERIES_MERGE_APPROXIMATE", merge_series_lines(net)["_simplification_log"])
    for bound in ("v_min", "vuf_max")
        bounded = deepcopy(net); bounded["bus"]["B"][bound] = bound == "v_min" ? [200.0] : 0.02
        @test length(merge_series_lines(bounded)["line"]) == 2
        dropped = merge_series_lines(bounded; allow_drop_bus_constraints=true)
        @test length(dropped["line"]) == 1
        evidence = only(e["detail"] for e in dropped["_simplification_log"] if e["code"] == "SERIES_MERGE_APPROXIMATE")
        @test evidence["dropped_bus_constraints"][bound] == bounded["bus"]["B"][bound]
        @test length(merge_series_lines(bounded; series_merge_policy=:exact, allow_drop_bus_constraints=true)["line"]) == 2
    end
    net["line"]["AB"]["s_max"] = [1000.0]
    @test length(merge_series_lines(net)["line"]) == 2
end

@testset "Scientific review — synthetic ampacity stays identifiable" begin
    @test !default_recipe().apply_thermal
    net = Dict{String,Any}("linecode"=>Dict("lc"=>Dict{String,Any}(
        "R_series_1_1"=>0.000396, "R_series_2_2"=>0.0008,
        "X_series_1_1"=>0.0001, "X_series_2_2"=>0.0001)))
    entries = BMOPFTools.TransformEntry[]
    BMOPFTools._apply_thermal!(net, entries, AugmentationRecipe(apply_thermal=true), Dict("lc"=>"distinct"))
    @test only(entries).confidence == :heuristic
    provenance = net["meta"]["provenance"]["thermal_estimates"]["lc"]
    @test provenance["equal_conductor_ratings_assumed"]
    @test !provenance["material_and_installation_verified"]
    mktempdir() do dir
        path = joinpath(dir, "case.json")
        net["bus"] = Dict{String,Any}()
        net["voltage_source"] = Dict{String,Any}()
        write_bmopf(net, path)
        schema = JSONSchema.Schema(JSON3.read(read(joinpath(@__DIR__, "..", "src", "validation", "schemas", "draft_bmopf_schema.json"), String)))
        @test JSONSchema.validate(schema, JSON3.read(read(path, String))) === nothing
        @test parse_bmopf(path)["meta"]["provenance"]["thermal_estimates"]["lc"] == provenance
    end
end
