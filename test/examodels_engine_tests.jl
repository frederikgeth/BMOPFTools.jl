# ExaModels coverage for the JuMP-backed IVR-EN engine. ExaModels and its
# NLPModels-compatible solver are opt-in packages, not declared test deps.
# The two-bus fixture has a known high-voltage solution and exercises nonlinear
# constant-power load equations through the public and staged engine paths.

_examodels_fixture() = parse_bmopf("""
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

@testset "ExaModels optimizer support" begin
    optimizer = () -> ExaModels.Optimizer(NLPModelsIpopt.ipopt)
    expected_vm = (1000.0 + sqrt(1000.0^2 - 4 * 0.5 * 100000.0)) / 2

    @testset "JuMP optimizer factory" begin
        model = JuMP.Model(optimizer)
        @test occursin("ExaModels", JuMP.solver_name(model))
    end

    @testset "public OPF solve with default per-unit and verbosity" begin
        result = solve_opf(_examodels_fixture(); optimizer)
        @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test result["bus"]["bus1"]["1"]["vm"] ≈ expected_vm atol=1e-3
    end

    @testset "staged engine build and solve" begin
        ctx = build_opf_model(_examodels_fixture(); optimizer, per_unit=false)
        enforce_kcl!(ctx)
        model = opf_model(ctx)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) in
              (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
        result = extract_result(ctx)
        @test result["bus"]["bus1"]["1"]["vm"] ≈ expected_vm atol=1e-3
    end
end
