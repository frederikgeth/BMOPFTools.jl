# CCOpt adapter tests. This file is included only when the optional CCOpt,
# MPCCModels, and NLPModelsJuMP packages are available.

const _CCOPT_EXT = Base.get_extension(BMOPFTools, :BMOPFCCOptExt)

# One single-phase Volt-watt IBR behind a resistive line: two hinges, so two
# complementarity pairs, and small enough that the smooth encoding's ε→0 limit
# can be computed exactly for comparison.
const _CCOPT_CASE = """
{
  "bus": {
    "src": {"terminal_names":["1","n"],
            "perfectly_grounded_terminals":["n"],
            "v_min":[200.0],"v_max":[300.0]},
    "b1":  {"terminal_names":["1","n"],
            "perfectly_grounded_terminals":["n"],
            "v_min":[200.0],"v_max":[300.0]}
  },
  "voltage_source": {
    "vs": {"bus":"src","terminal_map":["1"],
           "v_magnitude":[253.0],"v_angle":[0.0],"cost":[1.0]}
  },
  "linecode": {"lc": {"R_series_1_1":0.4}},
  "line": {"l1": {"bus_from":"src","bus_to":"b1",
                     "terminal_map_from":["1"],"terminal_map_to":["1"],
                     "linecode":"lc","length":1.0}},
  "load": {"ld": {"bus":"b1","terminal_map":["1","n"],
                     "configuration":"SINGLE_PHASE",
                     "p_nom":[100.0],"q_nom":[0.0]}},
  "control_profile": {
    "vw": {"volt_watt": {"voltage_reference":"PN_PER_PHASE",
                           "breakpoints":[253.0,260.0],
                           "p_limits":[1.00,0.20],
                           "p_unit":"VA_FRACTION","p_ref":"S_MAX"}}
  },
  "ibr": {"pv1": {"bus":"b1","terminal_map":["1","n"],
                     "topology":"SINGLE_PHASE","prime_mover":"PV",
                     "s_max":[3000.0],"p_max":[3000.0],"p_min":[0.0],
                     "q_min":[0.0],"q_max":[0.0],
                     "control_profile":"vw","cost":[-1.0]}}
}
"""

_ccopt_net() = parse_bmopf(_CCOPT_CASE; from_string=true)

# Same topology with the droop profile stripped: no hinges, hence no pairs.
function _ccopt_net_no_droop()
    net = _ccopt_net()
    delete!(net, "control_profile")
    delete!(net["ibr"]["pv1"], "control_profile")
    net
end

@testset "CCOpt complementarity adapter" begin
    @test _CCOPT_EXT !== nothing

    @testset "registration and pair structure" begin
        handle = build_ccopt_model(_ccopt_net())
        @test length(handle.pair_indices) == 2
        @test handle.mpcc.meta.ncc == 2
        pairs = opf_complementarity_pairs(handle.ctx)
        @test all(pair -> pair.left.family == :droop_hinge_value &&
                          pair.right.family == :droop_hinge_slack, pairs)
        # `base` and `slope` are what turn a complementarity residual into a
        # physical curve error, so the adapter depends on both being present.
        @test all(pair -> haskey(pair.metadata, "encoding") &&
                          haskey(pair.metadata, "slope") &&
                          haskey(pair.metadata, "base"), pairs)
    end

    @testset "solves, and agrees with the smooth ε→0 limit" begin
        handle = build_ccopt_model(_ccopt_net())
        solve_ccopt!(handle)
        result = extract_ccopt_result(handle)

        @test result["feasible"]
        @test result["ccopt"]["complementarity_satisfied"]
        @test result["ccopt"]["pair_count"] == 2
        @test result["ccopt"]["encoding"] == "exact_relu_hinge"
        # The exactness claim, measured rather than asserted: the enforced curve
        # is displaced by less than 0.01 % of its own reference base.
        @test result["ccopt"]["max_curve_error_relative"] < 1e-4

        # The smooth encoding converges as ε shrinks; the exact encoding must
        # land on that limit rather than on any particular ε's answer.
        converged = solve_opf(_ccopt_net(); volt_var_watt_eps=1e-5, verbose=false)
        coarse    = solve_opf(_ccopt_net(); volt_var_watt_eps=1e-1, verbose=false)
        pg_ccopt     = result["ibr"]["pv1"]["1"]["pg"]
        pg_converged = converged["ibr"]["pv1"]["1"]["pg"]
        pg_coarse    = coarse["ibr"]["pv1"]["1"]["pg"]
        @test isapprox(pg_ccopt, pg_converged; rtol=1e-3)
        @test isapprox(result["objective"], converged["objective"]; rtol=1e-3)
        # ...and the comparison is discriminating: a coarse ε is far away.
        @test abs(pg_coarse - pg_converged) > 100 * abs(pg_ccopt - pg_converged)

        # The profile is computed against the CCOpt point, not left as a stub,
        # so `profile_solution`'s `is_opf` flag stays meaningful.
        profile = result["opt_profile"]
        @test profile["solver"] == "CCOpt"
        @test profile["n_variables"] isa Integer && profile["n_variables"] > 0
        @test profile["n_active"] isa Integer && profile["n_active"] > 0
        @test profile["barrier_iterations"] isa Integer
    end

    @testset "an unenforced model refuses to solve" begin
        # `r · s = 0` is not in the JuMP model, so a plain solve relaxes every
        # hinge. On this case that relaxation is not conservative — it returns
        # the nameplate 3000 W where the exact hinge gives ~1183 W — so both the
        # optimize hook and the extract_result backstop must refuse.
        ctx = build_opf_model(_ccopt_net(); optimizer=Ipopt.Optimizer,
                              droop_encoding=:complementarity)
        enforce_kcl!(ctx)
        JuMP.set_silent(ctx.model)
        @test_throws ArgumentError JuMP.optimize!(ctx.model)
        @test_throws ArgumentError extract_result(ctx)

        # The guard is escapable, deliberately and explicitly.
        JuMP.set_optimize_hook(ctx.model, nothing)
        JuMP.optimize!(ctx.model)
        @test JuMP.termination_status(ctx.model) == JuMP.MOI.LOCALLY_SOLVED
    end

    @testset "a network with no droop curves is rejected" begin
        # Zero pairs is a valid network but not an MPCC; CCOpt 0.1.0 dies with a
        # MethodError deep in its solver constructor, so refuse it up front.
        @test_throws ArgumentError build_ccopt_model(_ccopt_net_no_droop())
    end

    @testset "complementarity residual gates feasibility" begin
        handle = build_ccopt_model(_ccopt_net())
        n = length(handle.variable_positions)
        # A point that satisfies the pairs (r = s = 0 on both hinges) is only
        # blocked by the solver's own status.
        exact = (status=:SOLVE_SUCCEEDED, solution=zeros(n),
                 objective=0.0, wall_time=0.0, iter=1)
        clean = extract_ccopt_result(handle; stats=exact)
        @test clean["feasible"]
        @test clean["termination_status"] == "LOCALLY_SOLVED"
        @test clean["ccopt"]["complementarity_satisfied"]

        # The same successful status over a point where r = s = 1 must NOT be
        # reported as solved: that point sits on a relaxed droop curve.
        violating = (status=:SOLVE_SUCCEEDED, solution=ones(n),
                     objective=0.0, wall_time=0.0, iter=1)
        gated = @test_logs (:warn,) match_mode=:any extract_ccopt_result(
            handle; stats=violating)
        @test !gated["feasible"]
        @test gated["termination_status"] == "CCOPT_COMPLEMENTARITY_NOT_SATISFIED"
        @test !gated["ccopt"]["complementarity_satisfied"]
        @test gated["ccopt"]["max_curve_error_relative"] > 1e-4
        @test gated["ccopt"]["worst_pair"] isa String

        # A hinge below its own zero is caught even though |r·s| stays small.
        negative = fill(0.0, n)
        negative[first(handle.pair_indices)[1]] = -1e-3
        below = (status=:SOLVE_SUCCEEDED, solution=negative,
                 objective=0.0, wall_time=0.0, iter=1)
        flagged = @test_logs (:warn,) match_mode=:any extract_ccopt_result(
            handle; stats=below, curve_error_tol=Inf)
        @test !flagged["feasible"]
        @test flagged["ccopt"]["max_hinge_bound_violation"] ≈ 1e-3

        # An acceptable-level termination is reported as such and warned about,
        # rather than laundered into LOCALLY_SOLVED.
        soft = (status=:SOLVED_TO_ACCEPTABLE_LEVEL, solution=zeros(n),
                objective=0.0, wall_time=0.0, iter=1)
        almost = @test_logs (:warn,) match_mode=:any extract_ccopt_result(
            handle; stats=soft)
        @test almost["termination_status"] == "ALMOST_LOCALLY_SOLVED"
        @test almost["feasible"]
    end

    @testset "registered result extractors run on the CCOpt path" begin
        seen = Ref(false)
        handle = build_ccopt_model(_ccopt_net();
            model_hook! = ctx -> register_opf_result_extractor!(
                ctx, :ccopt_probe, (c, res) -> (seen[] = true;
                                                res["probe"] = "ran")))
        n = length(handle.variable_positions)
        stats = (status=:SOLVE_SUCCEEDED, solution=zeros(n),
                 objective=0.0, wall_time=0.0, iter=1)
        result = extract_ccopt_result(handle; stats=stats)
        @test seen[]
        @test result["probe"] == "ran"
    end
end
