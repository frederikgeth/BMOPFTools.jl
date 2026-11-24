# Run from the repository root with the optional test/diffopt environment.
using BMOPFTools, JuMP, Ipopt, DiffOpt

function diffopt_resistance_sensitivity()
    source_voltage, resistance, demand = 1000.0, 0.5, 100_000.0  # V, ohm, W
    net = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[900.0],"v_max":[999.0]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[$source_voltage],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":$resistance}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}},
     "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE","p_nom":[$demand],"q_nom":[0.0]}}}
    """; from_string=true)

    model = DiffOpt.nonlinear_diff_model(Ipopt.Optimizer)
    set_silent(model)
    r = @variable(model, line_resistance_ohm in Parameter(resistance))
    key = OpfCoefficientKey(:physics, :line, "l1", :R_series, (1, 1))
    provider = OpfCoefficientProvider(:SensitivityExample, (ctx, key, default) -> r)
    ctx = build_opf_model(net; model, per_unit=false, add_objective=false,
        build_spec=OpfBuildSpec(coefficient_providers=Dict(key => provider)))
    @objective(model, Min, 0.0)  # local power-flow sensitivity, no dispatch objective
    enforce_kcl!(ctx)
    vr = opf_object(ctx, opf_bus_voltage_key("bus1", "1"))
    vi = opf_object(ctx, opf_bus_voltage_key("bus1", "1"; component=:imag))

    function solve_voltage!(resistance_value)
        set_parameter_value(r, resistance_value)
        optimize!(model)
        @assert termination_status(model) in (MOI.LOCALLY_SOLVED, MOI.OPTIMAL)
        voltage = value(vr)
        # Independent circuit residual at the CURRENT parameter, including re-solves.
        @assert abs(value(vi)) < 1e-7
        @assert abs(voltage * (source_voltage - voltage) /
                    resistance_value - demand) < 1e-3  # W
        return voltage
    end

    voltage = solve_voltage!(resistance)
    @assert opf_differentiability_report(ctx).ready  # screening, not a rank proof
    DiffOpt.set_forward_parameter(model, r, 1.0)
    DiffOpt.forward_differentiate!(model)
    forward = DiffOpt.get_forward_variable(model, vr)  # V/ohm
    DiffOpt.empty_input_sensitivities!(model)
    DiffOpt.set_reverse_variable(model, vr, 1.0)
    DiffOpt.reverse_differentiate!(model)
    reverse = DiffOpt.get_reverse_parameter(model, r)  # same scalar derivative
    DiffOpt.empty_input_sensitivities!(model)

    h = 1e-5  # ohm; both perturbed solves stay on the same high-voltage branch
    plus = solve_voltage!(resistance + h)
    minus = solve_voltage!(resistance - h)
    finite_difference = (plus - minus) / (2h)
    solve_voltage!(resistance)  # restore the nominal operating point
    analytic_voltage = (source_voltage + sqrt(source_voltage^2 - 4resistance*demand)) / 2
    analytic = -demand / (2analytic_voltage - source_voltage)
    return (; voltage, analytic_voltage, forward, reverse, finite_difference, analytic)
end

if abspath(PROGRAM_FILE) == @__FILE__
    println(diffopt_resistance_sensitivity())
end
