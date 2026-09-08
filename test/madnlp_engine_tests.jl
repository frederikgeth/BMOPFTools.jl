# Focused MadNLP coverage for the JuMP-backed OPF engine.
#
# Broader domain and hardening tests also exercise MadNLP. These tests keep the
# basic solver integration visible in the engine suite and verify a complete
# solve through the public API.

@testset "MadNLP optimizer support" begin
    @testset "JuMP can construct a MadNLP model" begin
        model = JuMP.Model(MadNLP.Optimizer)
        JuMP.set_silent(model)
        @variable(model, x >= 0)
        @objective(model, Min, (x - 1)^2)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) == JuMP.MOI.LOCALLY_SOLVED
        @test JuMP.value(x) ≈ 1.0 atol=1e-8
    end

    @testset "engine solves a nonlinear IVR-EN case" begin
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

        result = solve_opf(net; optimizer=MadNLP.Optimizer,
                           per_unit=false,
                           solver_options=("tol" => 1e-9,
                                           "print_level" => 0))
        @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test result["bus"]["bus1"]["1"]["vm"] ≈
              (1000.0 + sqrt(1000.0^2 - 4 * 0.5 * 100000.0)) / 2 atol=1e-3
    end
end
