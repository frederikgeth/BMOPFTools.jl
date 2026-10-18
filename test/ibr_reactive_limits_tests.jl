using Test, BMOPFTools, JuMP, Ipopt, JSON3

# Independent prescribed-voltage witnesses for #89. The minimized original is
# retained on disk; variants explicitly change topology, control and bounds.
function reactive_limit_net(; topology="SINGLE_PHASE", pf=0.8)
    net = JSON3.read(read(joinpath(@__DIR__, "data", "ibr_reactive_limits",
                                  "pf_capability.json"), String), Dict{String,Any})
    inv = net["ibr"]["pv"]
    inv["topology"] = topology
    phases = topology == "SINGLE_PHASE" ? ["a"] : ["a", "b", "c"]
    terminals = topology == "THREE_LEG" ? phases : vcat(phases, ["n"])
    net["bus"]["b"]["terminal_names"] = terminals
    net["bus"]["b"]["perfectly_grounded_terminals"] =
        topology == "THREE_LEG" ? String[] : ["n"]
    inv["terminal_map"] = terminals
    source = net["voltage_source"]["source"]
    source["terminal_map"] = phases
    source["v_magnitude"] = fill(230.0, length(phases))
    source["v_angle"] = length(phases) == 1 ? [0.0] : [0.0, -2pi/3, 2pi/3]
    for field in ("p_min", "p_max", "q_min", "q_max", "s_max")
        inv[field] = fill(only(inv[field]), length(phases))
    end
    if pf === nothing
        delete!(inv, "control_profile")
    else
        net["control_profile"]["pf"]["power_factor"]["pf"] = pf
    end
    return net
end

function solve_reactive_limit(net; per_unit=false, kwargs...)
    solve_opf(net; per_unit, solver_options=("tol"=>1e-10,
        "constr_viol_tol"=>1e-10, "bound_relax_factor"=>0.0),
        model_hook! = ctx -> begin
            count = length(net["ibr"]["pv"]["p_max"])
            @objective(ctx.model, Max,
                sum(opf_object(ctx, opf_ibr_power_key("pv", k)) for k in 1:count))
        end, kwargs...)
end

@testset "IBR reactive capability with control laws (#89)" begin
    @testset "PF intersects Q bounds across topologies and coordinates" begin
        for topology in ("SINGLE_PHASE", "FOUR_LEG", "THREE_LEG"),
            pf in (0.8, -0.8), pu in (false, true)
            net = reactive_limit_net(; topology, pf)
            original = deepcopy(net)
            result = solve_reactive_limit(net; per_unit=pu)
            @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test net == original
            phases = net["voltage_source"]["source"]["terminal_map"]
            voltages = 230.0 .* cis.(net["voltage_source"]["source"]["v_angle"])
            for (k, phase) in enumerate(phases)
                row = result["ibr"]["pv"][phase]
                # PF=0.8 gives |Q/P|=3/4, hence |Q|=300 caps P at 400 W.
                expected_s = 400.0 - sign(pf)*300.0im
                dv = topology == "THREE_LEG" ?
                    voltages[k] - voltages[mod1(k+1, 3)] : voltages[k]
                @test row["pg"] + im*row["qg"] ≈ expected_s atol=1e-3
                @test row["cri"] + im*row["cii"] ≈ conj(expected_s / dv) atol=1e-5
            end
            f = Finding[]
            summary = solution_check(net, result, f)
            @test summary["n_inv_violations"] == 0
            @test count(x -> x.code == "W.SOL.IBR_Q_ACTIVE", f) == length(phases)
            restored = JSON3.read(JSON3.write(result), Dict{String,Any})
            f2 = Finding[]
            @test solution_check(net, restored, f2)["n_inv_violations"] == 0
            @test [(x.code, x.detail) for x in f] == [(x.code, x.detail) for x in f2]
        end
    end

    @testset "optional, one-sided, unity-PF and zero-power boundaries" begin
        for pu in (false, true), (pf, fields, expected_p) in (
            (0.8, ("q_min",), 400.0), (-0.8, ("q_max",), 400.0),
            (0.8, (), 1200.0), (1.0, ("q_min", "q_max"), 1200.0),
            (-1.0, ("q_min", "q_max"), 1200.0))
            net = reactive_limit_net(; pf)
            for field in ("q_min", "q_max")
                field in fields || delete!(net["ibr"]["pv"], field)
            end
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test r["ibr"]["pv"]["a"]["pg"] ≈ expected_p atol=1e-3
            @test r["ibr"]["pv"]["a"]["qg"] ≈
                -sign(pf)*tan(acos(abs(pf)))*expected_p atol=1e-3
            ctx = build_opf_model(net; per_unit=pu)
            for (field, family) in (("q_min", :ibr_q_lower), ("q_max", :ibr_q_upper))
                @test (OpfModelKey(:constraint, family, ("pv", 1)) in
                       opf_object_keys(ctx)) == (field in fields)
            end
        end
        for pf in (0.8, -0.8), pu in (false, true)
            net = reactive_limit_net(; pf)
            net["ibr"]["pv"]["p_max"] = [0.0]
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test abs(r["ibr"]["pv"]["a"]["qg"]) < 1e-3
        end
    end

    @testset "supplied-result violations and near-active evidence" begin
        # Fixed analytic P/Q inputs exercise the verifier independently of a solve.
        for pf in (nothing, 0.8, -0.8), q in (-350.0, -300.0, 0.0, 300.0, 350.0)
            net = reactive_limit_net(; pf)
            result = Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED",
                "ibr"=>Dict("pv"=>Dict("a"=>Dict("pg"=>abs(q)/0.75, "qg"=>q))))
            before = deepcopy(result)
            f = Finding[]
            summary = solution_check(net, result, f)
            violations = filter(x -> x.code == "E.SOL.IBR_Q_VIOLATION", f)
            @test length(violations) == (abs(q) > 300 ? 1 : 0)
            @test count(x -> x.code == "W.SOL.IBR_Q_ACTIVE", f) == (abs(q) == 300 ? 1 : 0)
            @test summary["n_inv_violations"] == (abs(q) > 300 ? 1 : 0)
            @test result == before
            if !isempty(violations)
                detail = only(violations).detail
                @test detail["field"] == "qg"
                @test detail["value"] == q
                @test detail["lo"] == -300.0 && detail["hi"] == 300.0
                @test JSON3.read(JSON3.write(detail), Dict{String,Any}) == detail
            end
        end
    end

    @testset "control conflicts retain hard rows; no clipping" begin
        for pu in (false, true)
            net = reactive_limit_net()
            net["ibr"]["pv"]["p_min"] = [1200.0]
            ctx = build_opf_model(net; per_unit=pu)
            # Independent contradiction: P>=1200 and Q=-0.75P imply Q<=-900,
            # whereas the authored capability requires Q>=-300.
            @test -0.75 * only(net["ibr"]["pv"]["p_min"]) <
                only(net["ibr"]["pv"]["q_min"])
            for family in (:ibr_p_lower, :ibr_power_factor, :ibr_q_lower, :ibr_q_upper)
                @test OpfModelKey(:constraint, family, ("pv", 1)) in opf_object_keys(ctx)
            end
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")
        end
    end

    @testset "Volt-var equality intersects capability; box-only control retained" begin
        for topology in ("SINGLE_PHASE", "FOUR_LEG"), pu in (false, true)
            net = reactive_limit_net(; topology, pf=nothing)
            inv = net["ibr"]["pv"]
            inv["control_profile"] = "vv"
            inv["p_max"] .= 0.0
            # Low-voltage plateau: 0.1*s_max = 500 var. The source is 70 V
            # below the first knee, making softplus tails negligible here.
            net["control_profile"]["vv"] = Dict("volt_var"=>Dict(
                "breakpoints"=>[300.0, 310.0, 320.0, 330.0],
                "q_limits"=>[-0.1, 0.1],
                "q_unit"=>"VA_FRACTION", "q_ref"=>"VAR_MAX"))
            inv["q_max"] .= 600.0
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test all(abs(row["qg"] - 500.0) < 1e-3 for row in values(r["ibr"]["pv"]))
            inv["q_max"] .= 500.0
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            inv["q_max"] .= 400.0
            ctx = build_opf_model(net; per_unit=pu)
            for family in (:ibr_q_volt_var, :ibr_q_upper)
                @test OpfModelKey(:constraint, family, ("pv", 1)) in opf_object_keys(ctx)
            end
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")
            delete!(inv, "control_profile")
            r = solve_reactive_limit(net; per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        end
    end

    @testset "reactive coefficient providers remain live under PF" begin
        net = reactive_limit_net(; pf=-0.8)
        model = Model(Ipopt.Optimizer)
        qcap = @variable(model, set=Parameter(300.0))
        spec = OpfBuildSpec(coefficient_providers=Dict(
            OpfCoefficientKey(:limit, :ibr, "pv", :q_max, 1) =>
                OpfCoefficientProvider(:ReactiveLimitTest, (ctx, key, default) -> qcap)))
        ctx = build_opf_model(net; model, build_spec=spec, per_unit=false)
        @objective(model, Max, opf_object(ctx, opf_ibr_power_key("pv", 1)))
        enforce_kcl!(ctx)
        set_optimizer_attribute(model, "tol", 1e-10)
        set_optimizer_attribute(model, "bound_relax_factor", 0.0)
        for cap in (300.0, 150.0, 300.0)
            set_parameter_value(qcap, cap)
            resolve_opf!(ctx)
            result = extract_result(ctx)
            @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test result["ibr"]["pv"]["a"]["pg"] ≈ cap/0.75 atol=1e-3
            @test result["ibr"]["pv"]["a"]["qg"] ≈ cap atol=1e-3
        end
    end
end
