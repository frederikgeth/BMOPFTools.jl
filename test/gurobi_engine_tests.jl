# Gurobi coverage for the quadratic-compatible subset of the IVR-EN engine.
#
# Gurobi is commercial and licence-gated, so it is not a declared test
# dependency: this file runs only when Gurobi.jl has been added to the test
# environment *and* a usable licence is present. The fixture intentionally uses
# constant-power physics: voltage-dependent exponential laws and smooth control
# curves remain NLP-only features.

# Probe for a usable licence. `Gurobi.Optimizer` acquires an environment
# eagerly, so *every* construction of a Gurobi model — including the trivial
# solver-name check below — must sit behind this guard. Without a licence,
# `JuMP.Model(Gurobi.Optimizer)` throws (e.g. `Gurobi Error 10009`) rather than
# returning an unusable model.
function _gurobi_license_available()
    try
        model = JuMP.Model(Gurobi.Optimizer)
        JuMP.set_silent(model)
        @variable(model, x >= 0)
        @objective(model, Min, x)
        JuMP.optimize!(model)
        return JuMP.termination_status(model) == JuMP.MOI.OPTIMAL
    catch
        return false
    end
end

@testset "Gurobi optimizer support" begin
    if !_gurobi_license_available()
        @test_skip "Gurobi license is unavailable"
    else
        @testset "JuMP can construct a Gurobi model" begin
            model = JuMP.Model(Gurobi.Optimizer)
            JuMP.set_silent(model)
            @test occursin("Gurobi", JuMP.solver_name(model))
        end

        @testset "engine solves a quadratic IVR-EN case" begin
            # The high-voltage root is selected by the explicit 900 V lower
            # bound. All engine constraints in this fixture are affine or
            # quadratic, which is the supported Gurobi path.
            net = parse_bmopf("""
            {"bus":{
                "sourcebus":{"terminal_names":["1","n"],
                             "perfectly_grounded_terminals":["n"]},
                "bus1":{"terminal_names":["1","n"],
                        "perfectly_grounded_terminals":["n"],
                        "v_min":[900.0],"v_max":[999.0]}},
             "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
                 "v_magnitude":[1000.0],"v_angle":[0.0]}},
             "linecode":{"lc":{"R_series_1_1":0.5}},
             "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
                 "terminal_map_from":["1"],"terminal_map_to":["1"],
                 "linecode":"lc","length":1.0}},
             "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
                 "configuration":"SINGLE_PHASE","p_nom":[100000.0],
                 "q_nom":[0.0]}}}
            """; from_string=true)

            result = solve_opf(net; optimizer=Gurobi.Optimizer,
                               per_unit=false,
                               solver_options=("NonConvex" => 2,
                                               "OutputFlag" => 0))
            @test result["termination_status"] == "OPTIMAL"
            @test result["bus"]["bus1"]["1"]["vm"] ≈
                  (1000.0 + sqrt(1000.0^2 - 4 * 0.5 * 100000.0)) / 2 atol=1e-3
            @test result["bus"]["bus1"]["1"]["vm"] >= 900.0
        end

        @testset "smooth control curves require softplus=:swish" begin
            # Gurobi's nonlinear interface accepts a fixed opcode set. Of the
            # three smooth-ReLU encodings, only `:swish` lands inside it:
            #   :user_defined -> MOI.UserDefinedFunction  (unsupported attribute)
            #   :builtin      -> `:log1p`                 (not a Gurobi opcode)
            #   :swish        -> `:logistic`              (GRB_OPCODE_LOGISTIC)
            # This is why the solver guide tells Gurobi users with Volt-var /
            # Volt-watt profiles to select `softplus=:swish` explicitly.
            opfext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

            build(op) = begin
                model = JuMP.Model(Gurobi.Optimizer)
                JuMP.set_silent(model)
                x = JuMP.@variable(model, lower_bound = 0.0, upper_bound = 10.0)
                JuMP.@constraint(model, x >= 2.0)
                JuMP.@objective(model, Min, op(model, x))
                model
            end

            @test_throws JuMP.MOI.UnsupportedAttribute JuMP.optimize!(build(
                (m, x) -> opfext.relu_operator(m, 0.05; name = :relu_ud)(x)))
            @test_throws JuMP.MOI.UnsupportedNonlinearOperator JuMP.optimize!(
                build((_, x) -> opfext.BuiltinSoftplus(0.05)(x)))

            swish_model = build((_, x) -> opfext.BuiltinSwish(0.05)(x))
            JuMP.optimize!(swish_model)
            @test JuMP.termination_status(swish_model) == JuMP.MOI.OPTIMAL
            # x is pinned at its lower bound 2.0, where the swish hinge is
            # within a hair of the exact ReLU (z/ε = 40).
            @test JuMP.objective_value(swish_model) ≈ 2.0 atol=1e-6
        end
    end
end
