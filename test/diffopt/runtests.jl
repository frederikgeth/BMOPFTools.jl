using Test
using BMOPFTools
using JuMP
using Ipopt
using DiffOpt

@testset "DiffOpt compatibility — staged IVR-EN model" begin
    # A source feeds an otherwise empty grounded single-phase bus through a
    # resistive line. A custom current injection I=theta is linked to a JuMP
    # parameter. Analytically V_bus = V_source + R*theta, so dV/dtheta = R.
    net = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.5}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}}}
    """; from_string=true)

    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    ctx = build_opf_model(net; model=model, per_unit=false,
                          add_objective=false)

    theta = JuMP.@variable(model, theta_I in JuMP.Parameter(10.0))
    cr = JuMP.@variable(model, base_name="custom_cr")
    ci = JuMP.@variable(model, base_name="custom_ci")
    cr_key = OpfModelKey(:variable, :custom_current_r, ("bus1", "1"))
    register_opf_object!(ctx, cr_key, cr)
    bind_opf_parameter!(ctx,
        OpfModelKey(:parameter, :terminal_current, ("bus1", "1")),
        theta, cr_key; aliases=[:theta_I], input_unit=:A, working_unit=:A)
    JuMP.@constraint(model, ci == 0.0)
    add_terminal_injection!(ctx, "bus1", "1", cr, ci)
    JuMP.@objective(model, Min, 0.0)
    enforce_kcl!(ctx)
    JuMP.optimize!(model)

    @test JuMP.termination_status(model) in
        (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
    vr = opf_object(ctx, OpfModelKey(:variable, :vr, ("bus1", "1")))
    @test JuMP.value(vr) ≈ 1005.0 atol=1e-7

    JuMP.MOI.set(model, DiffOpt.NonLinearKKTJacobianFactorization(),
        opf_checked_kkt_factorization(ctx))
    DiffOpt.set_forward_parameter(model, theta, 1.0)
    DiffOpt.forward_differentiate!(model)
    forward = DiffOpt.get_forward_variable(model, vr)
    @test forward ≈ 0.5 atol=1e-7
    @test opf_kkt_diagnostic(ctx).status == :accepted
    @test opf_kkt_diagnostic(ctx).pivot_ratio > 1e-10
    DiffOpt.empty_input_sensitivities!(model)

    # A central finite difference checks the full parameter-update/solve path,
    # rather than merely comparing DiffOpt with a restatement of its KKT system.
    theta0 = JuMP.parameter_value(theta)
    h = 1e-3
    JuMP.set_parameter_value(theta, theta0 + h)
    JuMP.optimize!(model)
    v_plus = JuMP.value(vr)
    JuMP.set_parameter_value(theta, theta0 - h)
    JuMP.optimize!(model)
    v_minus = JuMP.value(vr)
    central = (v_plus - v_minus) / (2h)
    @test central ≈ 0.5 atol=1e-7
    @test forward ≈ central atol=1e-7

    # With scalar seeds, forward and reverse differentiation must satisfy the
    # adjoint identity: <v̄, J θ̇> = <J' v̄, θ̇>.
    JuMP.set_parameter_value(theta, theta0)
    JuMP.optimize!(model)
    DiffOpt.empty_input_sensitivities!(model)
    DiffOpt.set_reverse_variable(model, vr, 1.0)
    DiffOpt.reverse_differentiate!(model)
    reverse = DiffOpt.get_reverse_parameter(model, theta)
    @test reverse ≈ 0.5 atol=1e-7
    @test 1.0 * forward ≈ reverse * 1.0 atol=1e-7
    DiffOpt.empty_input_sensitivities!(model)

    # Re-optimizing after a parameter update must preserve model structure and
    # agree with the analytic finite change. This is also a model-growth guard.
    nvar = JuMP.num_variables(model)
    ncon = sum(JuMP.num_constraints(model, F, S)
               for (F, S) in JuMP.list_of_constraint_types(model))
    JuMP.set_parameter_value(theta, -4.0)
    JuMP.optimize!(model)
    @test JuMP.value(vr) ≈ 998.0 atol=1e-7
    @test JuMP.num_variables(model) == nvar
    @test sum(JuMP.num_constraints(model, F, S)
              for (F, S) in JuMP.list_of_constraint_types(model)) == ncon
end

@testset "DiffOpt compatibility — SI/per-unit parameter chain rule" begin
    net = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.5}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}}}
    """; from_string=true)

    function physical_voltage_sensitivity(per_unit)
        model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
        JuMP.set_silent(model)
        ctx = build_opf_model(net; model, per_unit, s_base=1e6,
                              add_objective=false)
        theta = JuMP.@variable(model, theta_amp in JuMP.Parameter(10.0))
        cr = JuMP.@variable(model, base_name="parameterized_current")
        ci = JuMP.@variable(model, base_name="zero_current_imaginary")
        crkey = OpfModelKey(:variable, :custom_current_r, ("bus1", "1"))
        register_opf_object!(ctx, crkey, cr)
        current_scale = per_unit ? inv(opf_bases(ctx).i_base["bus1"]) : 1.0
        bind_opf_parameter!(ctx,
            OpfModelKey(:parameter, :current_A, ("bus1", "1")), theta, crkey;
            input_unit=:A, working_unit=per_unit ? :pu_current : :A,
            to_working_scale=current_scale)
        JuMP.@constraint(model, ci == 0.0)
        add_terminal_injection!(ctx, "bus1", "1", cr, ci)
        JuMP.@objective(model, Min, 0.0)
        enforce_kcl!(ctx)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) in
              (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
        vr = opf_object(ctx, OpfModelKey(:variable, :vr, ("bus1", "1")))
        DiffOpt.set_forward_parameter(model, theta, 1.0)
        DiffOpt.forward_differentiate!(model)
        working_derivative = DiffOpt.get_forward_variable(model, vr)
        voltage_scale = per_unit ? opf_bases(ctx).v_base["bus1"] : 1.0
        return voltage_scale * working_derivative,
               opf_parameter_binding(ctx,
                   OpfModelKey(:parameter, :current_A, ("bus1", "1")))
    end

    d_si, si_binding = physical_voltage_sensitivity(false)
    d_pu, pu_binding = physical_voltage_sensitivity(true)
    @test d_si ≈ 0.5 atol=1e-7
    @test d_pu ≈ 0.5 atol=1e-7
    @test d_pu ≈ d_si atol=1e-7
    @test si_binding.to_working_scale == 1.0
    @test pu_binding.to_working_scale != 1.0
end

@testset "DiffOpt compatibility — native load coefficient provider" begin
    # This exercises a parameter inside an unchanged native device equation,
    # rather than linking a parameter to an existing decision variable. For a
    # resistive feeder V² - Vs*V + R*P = 0, hence dV/dP = -R/(2V-Vs).
    vs = 1000.0
    resistance = 0.5
    p0 = 100_000.0
    net = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[900.0],"v_max":[999.0]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[$vs],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":$resistance}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}},
     "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE","p_nom":[$p0],"q_nom":[0.0]}}}
    """; from_string=true)

    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    demand = JuMP.@variable(model, demand_W in JuMP.Parameter(p0))
    pkey = OpfCoefficientKey(:load, :load, "ld1", :p_nom, 1)
    provider = OpfCoefficientProvider(:DiffOptTests,
        (ctx, key, default) -> demand)
    spec = OpfBuildSpec(coefficient_providers=Dict(pkey => provider))
    ctx = build_opf_model(net; model, per_unit=false, build_spec=spec,
                          add_objective=false)
    JuMP.@objective(model, Min, 0.0)
    enforce_kcl!(ctx)
    JuMP.optimize!(model)
    @test JuMP.termination_status(model) in
          (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)

    vr = opf_object(ctx, OpfModelKey(:variable, :vr, ("bus1", "1")))
    expected_v = (vs + sqrt(vs^2 - 4resistance*p0)) / 2
    expected_dv = -resistance / (2expected_v - vs)
    @test JuMP.value(vr) ≈ expected_v atol=1e-7

    DiffOpt.set_forward_parameter(model, demand, 1.0)
    DiffOpt.forward_differentiate!(model)
    forward = DiffOpt.get_forward_variable(model, vr)
    @test forward ≈ expected_dv atol=1e-9
    DiffOpt.empty_input_sensitivities!(model)

    h = 1.0
    JuMP.set_parameter_value(demand, p0 + h)
    JuMP.optimize!(model)
    plus = JuMP.value(vr)
    JuMP.set_parameter_value(demand, p0 - h)
    JuMP.optimize!(model)
    minus = JuMP.value(vr)
    @test forward ≈ (plus - minus) / (2h) atol=1e-9

    JuMP.set_parameter_value(demand, p0)
    JuMP.optimize!(model)
    DiffOpt.set_reverse_variable(model, vr, 1.0)
    DiffOpt.reverse_differentiate!(model)
    @test DiffOpt.get_reverse_parameter(model, demand) ≈ expected_dv atol=1e-9

    # The provider owns the SI→working expression in per-unit mode. DiffOpt
    # differentiates through demand_W / s_base, and output conversion restores
    # the identical physical V/W sensitivity.
    pu_model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(pu_model)
    pu_demand = JuMP.@variable(pu_model,
        pu_demand_W in JuMP.Parameter(p0))
    pu_provider = OpfCoefficientProvider(:DiffOptTests,
        (ctx, key, default) -> pu_demand / opf_bases(ctx).s_base)
    pu_ctx = build_opf_model(net; model=pu_model, per_unit=true, s_base=1e6,
        build_spec=OpfBuildSpec(coefficient_providers=Dict(
            pkey => pu_provider)), add_objective=false)
    JuMP.@objective(pu_model, Min, 0.0)
    enforce_kcl!(pu_ctx)
    JuMP.optimize!(pu_model)
    pu_vr = opf_object(pu_ctx,
        OpfModelKey(:variable, :vr, ("bus1", "1")))
    DiffOpt.set_forward_parameter(pu_model, pu_demand, 1.0)
    DiffOpt.forward_differentiate!(pu_model)
    pu_physical_derivative = opf_bases(pu_ctx).v_base["bus1"] *
        DiffOpt.get_forward_variable(pu_model, pu_vr)
    @test pu_physical_derivative ≈ expected_dv atol=1e-9
end

@testset "DiffOpt compatibility — active native availability limit" begin
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0],"cost":[0.0]}},
     "generator":{"pv":{"bus":"b","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE","p_min":[0.0],"p_max":[200.0],
         "q_min":[0.0],"q_max":[0.0],"cost":[-1.0]}}}
    """; from_string=true)

    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    availability = JuMP.@variable(model,
        pv_availability_W in JuMP.Parameter(120.0))
    key = OpfCoefficientKey(:availability, :generator, "pv", :p_max, 1)
    spec = OpfBuildSpec(coefficient_providers=Dict(
        key => OpfCoefficientProvider(:DiffOptTests,
            (ctx, coefficient_key, default) -> availability)))
    ctx = build_opf_model(net; model, per_unit=false, build_spec=spec)
    enforce_kcl!(ctx)
    JuMP.optimize!(model)
    @test JuMP.termination_status(model) in
          (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)

    crg = opf_object(ctx, OpfModelKey(:variable, :crg, ("pv", 1)))
    @test JuMP.value(crg) ≈ 0.12 atol=1e-8
    report = opf_differentiability_report(ctx)
    @test !report.ready
    @test report.coefficient_keys == [key]
    @test isempty(report.unused_coefficient_keys)
    @test report.inequality_constraints > 0
    @test !isempty(report.near_active_constraints) ||
          !isempty(report.weakly_active_constraints)
    @test opf_coefficient_usage(ctx)[key] == 1
    @test any(q -> occursin("active set", q), report.qualifications)
    @test any(q -> occursin("transition tolerance", q) ||
                   occursin("strict complementarity", q),
              report.qualifications)
    DiffOpt.set_forward_parameter(model, availability, 1.0)
    DiffOpt.forward_differentiate!(model)
    forward = DiffOpt.get_forward_variable(model, crg)
    @test forward ≈ 1e-3 atol=1e-8

    # Stay within the same active set: the negative generation cost keeps the
    # availability inequality strictly selected throughout this perturbation.
    h = 1e-2
    JuMP.set_parameter_value(availability, 120.0 + h)
    JuMP.optimize!(model)
    plus = JuMP.value(crg)
    JuMP.set_parameter_value(availability, 120.0 - h)
    JuMP.optimize!(model)
    minus = JuMP.value(crg)
    @test forward ≈ (plus - minus) / (2h) atol=1e-8
end

@testset "DiffOpt diagnostics — active-set transition" begin
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}}}
    """; from_string=true)
    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    ctx = build_opf_model(net; model, per_unit=false, add_objective=false)
    theta = JuMP.@variable(model,
        transition_parameter in JuMP.Parameter(-1e-3))
    x = JuMP.@variable(model, transition_decision)
    JuMP.@constraint(model, transition_bound, x <= 0.0)
    JuMP.@objective(model, Min, (x - theta)^2)
    enforce_kcl!(ctx)

    JuMP.optimize!(model)
    interior = opf_differentiability_report(ctx;
        active_tolerance=1e-8, transition_tolerance=1e-5)
    @test interior.ready
    @test isempty(interior.active_constraints)
    @test isempty(interior.near_active_constraints)

    JuMP.set_parameter_value(theta, -1e-6)
    JuMP.optimize!(model)
    near = opf_differentiability_report(ctx;
        active_tolerance=1e-8, transition_tolerance=1e-4)
    @test !near.ready
    @test "transition_bound" in near.near_active_constraints

    JuMP.set_parameter_value(theta, 0.0)
    JuMP.optimize!(model)
    kink = opf_differentiability_report(ctx;
        active_tolerance=5e-5, transition_tolerance=1e-4,
        dual_tolerance=1e-4)
    @test !kink.ready
    @test "transition_bound" in kink.active_constraints
    @test "transition_bound" in kink.weakly_active_constraints

    # On either side the local derivative exists but differs: one in the
    # interior and zero on the binding branch. The transition itself is exactly
    # the point the readiness report refuses to qualify.
    JuMP.set_parameter_value(theta, 1e-3)
    JuMP.optimize!(model)
    binding = opf_differentiability_report(ctx;
        active_tolerance=1e-5, transition_tolerance=1e-4)
    @test binding.ready
    @test "transition_bound" in binding.active_constraints
    @test isempty(binding.weakly_active_constraints)

    # A disclosed, externally audited build-time branch may remain
    # nonblocking. A hard operator on the differentiated path must fail closed.
    register_opf_differentiability_annotation!(ctx, :fixed_study_regime;
        kind=:dynamic_branch,
        description="Regime fixed before the parameter sweep",
        owner=:DiffOptTests, blocking=false)
    disclosed = opf_differentiability_report(ctx;
        active_tolerance=1e-5, transition_tolerance=1e-4)
    @test disclosed.ready
    @test only(disclosed.dynamic_branches).name == :fixed_study_regime
    register_opf_differentiability_annotation!(ctx, :hard_clamp;
        kind=:nonsmooth_operator,
        description="Test-only hard clamp on the derivative path",
        owner=:DiffOptTests)
    blocked = opf_differentiability_report(ctx;
        active_tolerance=1e-5, transition_tolerance=1e-4)
    @test !blocked.ready
    @test only(blocked.nonsmooth_operators).blocking
    @test any(q -> occursin("nonsmooth operator", q),
              blocked.qualifications)
end

@testset "DiffOpt diagnostics — singular KKT rejection" begin
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}}}
    """; from_string=true)
    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    ctx = build_opf_model(net; model, per_unit=false, add_objective=false)
    theta = JuMP.@variable(model,
        unused_parameter in JuMP.Parameter(1.0))
    JuMP.@variable(model, unidentifiable_free_direction)
    JuMP.@objective(model, Min, 0.0)
    enforce_kcl!(ctx)
    JuMP.optimize!(model)
    @test JuMP.termination_status(model) in
          (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)

    JuMP.MOI.set(model, DiffOpt.NonLinearKKTJacobianFactorization(),
        opf_checked_kkt_factorization(ctx))
    DiffOpt.set_forward_parameter(model, theta, 1.0)
    @test_throws OpfDifferentiationError DiffOpt.forward_differentiate!(model)
    diagnostic = opf_kkt_diagnostic(ctx)
    @test diagnostic.status == :rejected
    @test diagnostic.dimension > 0
    @test diagnostic.pivot_ratio === 0.0
    report = opf_differentiability_report(ctx)
    @test !report.ready
    @test report.kkt_diagnostic == diagnostic
    @test any(q -> occursin("KKT", q), report.qualifications)
    provenance = opf_research_provenance(ctx)
    @test provenance["differentiability"]["ready"] == false
    @test provenance["differentiability"]["kkt"]["status"] == "rejected"
    @test provenance["differentiability"]["kkt"]["pivot_ratio"] == 0.0
end

@testset "DiffOpt compatibility — native IBR availability" begin
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0],"cost":[0.0]}},
     "ibr":{"pv":{"bus":"b","terminal_map":["1","n"],
         "topology":"SINGLE_PHASE","prime_mover":"PV",
         "s_max":[500.0],"p_min":[0.0],"p_max":[200.0],
         "q_min":[0.0],"q_max":[0.0],"cost":[-1.0]}}}
    """; from_string=true)
    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    availability = JuMP.@variable(model,
        ibr_availability_W in JuMP.Parameter(150.0))
    key = OpfCoefficientKey(:availability, :ibr, "pv", :p_max, 1)
    ctx = build_opf_model(net; model, per_unit=false,
        build_spec=OpfBuildSpec(coefficient_providers=Dict(
            key => OpfCoefficientProvider(:DiffOptTests,
                (ctx, coefficient_key, default) -> availability))))
    enforce_kcl!(ctx)
    JuMP.optimize!(model)
    @test JuMP.termination_status(model) in
          (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
    cri = opf_object(ctx, OpfModelKey(:variable, :cri, ("pv", 1)))
    @test JuMP.value(cri) ≈ 0.15 atol=1e-7
    DiffOpt.set_forward_parameter(model, availability, 1.0)
    DiffOpt.forward_differentiate!(model)
    @test DiffOpt.get_forward_variable(model, cri) ≈ 1e-3 atol=1e-8
    @test opf_coefficient_usage(ctx)[key] == 1
end

@testset "DiffOpt compatibility — line resistance coefficient" begin
    # A constant-power load behind a resistive line satisfies
    # V^2 - Vs*V + R*P = 0 on the high-voltage branch. This exercises a
    # parameter multiplying a native current decision in the KVL equations.
    vs = 1000.0
    resistance = 0.5
    demand = 100_000.0
    net = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[900.0],"v_max":[999.0]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[$vs],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":$resistance}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}},
     "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE","p_nom":[$demand],"q_nom":[0.0]}}}
    """; from_string=true)
    key = OpfCoefficientKey(
        :physics, :line, "l1", :R_series, (1, 1))

    function resistance_model(per_unit)
        model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
        JuMP.set_silent(model)
        r_parameter = JuMP.@variable(model,
            line_resistance_ohm in JuMP.Parameter(resistance))
        provider = OpfCoefficientProvider(:DiffOptTests,
            (ctx, coefficient_key, default) -> per_unit ?
                r_parameter / opf_bases(ctx).z_base["sourcebus"] : r_parameter)
        ctx = build_opf_model(net; model, per_unit, s_base=1e6,
            build_spec=OpfBuildSpec(coefficient_providers=Dict(
                key => provider)), add_objective=false)
        JuMP.@objective(model, Min, 0.0)
        enforce_kcl!(ctx)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) in
              (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
        vr = opf_object(ctx,
            OpfModelKey(:variable, :vr, ("bus1", "1")))
        return model, ctx, r_parameter, vr
    end

    expected_v = (vs + sqrt(vs^2 - 4resistance*demand)) / 2
    expected_dv = -demand / (2expected_v - vs)
    si_model, si_ctx, si_r, si_vr = resistance_model(false)
    @test JuMP.value(si_vr) ≈ expected_v atol=1e-7
    DiffOpt.set_forward_parameter(si_model, si_r, 1.0)
    DiffOpt.forward_differentiate!(si_model)
    forward = DiffOpt.get_forward_variable(si_model, si_vr)
    @test forward ≈ expected_dv atol=1e-7
    DiffOpt.empty_input_sensitivities!(si_model)

    h = 1e-5
    nvar = JuMP.num_variables(si_model)
    ncon = sum(JuMP.num_constraints(si_model, F, S)
               for (F, S) in JuMP.list_of_constraint_types(si_model))
    JuMP.set_parameter_value(si_r, resistance + h)
    JuMP.optimize!(si_model)
    plus = JuMP.value(si_vr)
    JuMP.set_parameter_value(si_r, resistance - h)
    JuMP.optimize!(si_model)
    minus = JuMP.value(si_vr)
    @test forward ≈ (plus - minus) / (2h) atol=1e-5
    @test JuMP.num_variables(si_model) == nvar
    @test sum(JuMP.num_constraints(si_model, F, S)
              for (F, S) in JuMP.list_of_constraint_types(si_model)) == ncon
    @test opf_coefficient_usage(si_ctx)[key] == 1
    report = opf_differentiability_report(si_ctx)
    @test report.ready
    @test any(q -> occursin("matrix rank", q), report.qualifications)

    JuMP.set_parameter_value(si_r, resistance)
    JuMP.optimize!(si_model)
    DiffOpt.set_reverse_variable(si_model, si_vr, 1.0)
    DiffOpt.reverse_differentiate!(si_model)
    @test DiffOpt.get_reverse_parameter(si_model, si_r) ≈ expected_dv atol=1e-7

    pu_model, pu_ctx, pu_r, pu_vr = resistance_model(true)
    DiffOpt.set_forward_parameter(pu_model, pu_r, 1.0)
    DiffOpt.forward_differentiate!(pu_model)
    pu_physical_derivative = opf_bases(pu_ctx).v_base["bus1"] *
        DiffOpt.get_forward_variable(pu_model, pu_vr)
    @test pu_physical_derivative ≈ expected_dv atol=5e-7
end

@testset "DiffOpt compatibility — parameterized Volt-watt curve" begin
    voltage = 256.5
    rating = 3000.0
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
         "v_magnitude":[$voltage],"v_angle":[0.0],"cost":[0.0]}},
     "control_profile":{"vw":{"volt_watt":{
         "voltage_reference":"PN_PER_PHASE",
         "breakpoints":[253.0,260.0],"p_limits":[0.2,1.0],
         "p_unit":"VA_FRACTION","p_ref":"S_MAX"}}},
     "ibr":{"pv":{"bus":"b","terminal_map":["1","n"],
         "topology":"SINGLE_PHASE","prime_mover":"PV",
         "s_max":[$rating],"p_min":[0.0],"p_max":[$rating],
         "q_min":[0.0],"q_max":[0.0],"control_profile":"vw",
         "cost":[-1.0]}}}
    """; from_string=true)

    # Swapping to a wrapper that rejects MOI.UserDefinedFunction must not
    # silently change the smooth surrogate. The native encoding is opt-in.
    default_model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    default_error = try
        build_opf_model(net; model=default_model, per_unit=false)
        nothing
    catch caught
        caught
    end
    @test default_error isa ArgumentError
    @test occursin("softplus=:builtin", sprint(showerror, default_error))
    @test occursin("DiffOpt", sprint(showerror, default_error))

    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    p_low = JuMP.@variable(model, p_low_fraction in JuMP.Parameter(0.2))
    first_knot = JuMP.@variable(model,
        first_volt_watt_knot_V in JuMP.Parameter(253.0))
    ordinate_key = OpfCoefficientKey(
        :controller, :control_profile, "vw", :volt_watt_p_limits, 1)
    knot_key = OpfCoefficientKey(
        :controller, :control_profile, "vw", :volt_watt_breakpoints, 1)
    providers = Dict(
        ordinate_key => OpfCoefficientProvider(:DiffOptTests,
            (ctx, key, default) -> p_low),
        knot_key => OpfCoefficientProvider(:DiffOptTests,
            (ctx, key, default) -> first_knot),
    )
    ctx = build_opf_model(net; model, per_unit=false,
        softplus=:builtin,
        build_spec=OpfBuildSpec(coefficient_providers=providers))
    enforce_kcl!(ctx)
    JuMP.optimize!(model)
    @test JuMP.termination_status(model) in
          (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
    cri = opf_object(ctx, OpfModelKey(:variable, :cri, ("pv", 1)))

    # At the midpoint, d f/d p_low is the normalized difference of the two
    # fixed-width softplus hinges. Voltage is stiff, so dI/dp_low = S/U * df.
    epsilon = 2e-3 * (253.0 + 260.0) / 2
    softplus(z) = epsilon * log1p(exp(z / epsilon))
    df = (softplus(voltage - 253.0) - softplus(voltage - 260.0)) / 7.0
    expected = rating / voltage * df
    DiffOpt.set_forward_parameter(model, p_low, 1.0)
    DiffOpt.forward_differentiate!(model)
    forward = DiffOpt.get_forward_variable(model, cri)
    @test forward ≈ expected atol=1e-7

    h = 1e-4
    JuMP.set_parameter_value(p_low, 0.2 + h)
    JuMP.optimize!(model)
    plus = JuMP.value(cri)
    JuMP.set_parameter_value(p_low, 0.2 - h)
    JuMP.optimize!(model)
    minus = JuMP.value(cri)
    @test forward ≈ (plus - minus) / (2h) atol=1e-6
    @test opf_coefficient_usage(ctx)[ordinate_key] == 1
    @test opf_coefficient_usage(ctx)[knot_key] == 1

    # Knot count and smoothing stay fixed. Moving the first knot past the
    # second violates the generated ordering guard and produces a failed solve,
    # which the readiness report refuses to qualify for differentiation.
    nvar = JuMP.num_variables(model)
    ncon = sum(JuMP.num_constraints(model, F, S)
               for (F, S) in JuMP.list_of_constraint_types(model))
    JuMP.set_parameter_value(p_low, 0.2)
    JuMP.set_parameter_value(first_knot, 261.0)
    JuMP.optimize!(model)
    @test !(JuMP.termination_status(model) in
            (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL))
    @test !opf_differentiability_report(ctx).ready
    @test JuMP.num_variables(model) == nvar
    @test sum(JuMP.num_constraints(model, F, S)
              for (F, S) in JuMP.list_of_constraint_types(model)) == ncon
end
