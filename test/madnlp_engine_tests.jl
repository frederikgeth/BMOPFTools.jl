# Focused MadNLP coverage for the JuMP-backed OPF engine.
#
# Broader domain and hardening tests also exercise MadNLP. These tests keep the
# basic solver integration visible in the engine suite and verify a complete
# solve through the public API.

# Single-phase constant-power load behind a 0.5 Ω series resistance. The 900 V
# lower bound selects the high-voltage root of the resulting quadratic.
_madnlp_fixture() = parse_bmopf("""
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

const _MADNLP_EXPECTED_VM = (1000.0 + sqrt(1000.0^2 - 4 * 0.5 * 100000.0)) / 2

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
        net = _madnlp_fixture()

        # `print_level` is a `MadNLP.LogLevels` enum (TRACE=1 .. ERROR=6);
        # there is no level 0. `verbose=true` keeps `set_silent` from
        # overwriting the option at `optimize!` time, so this actually
        # exercises the option plumbing rather than being silently discarded.
        result = solve_opf(net; optimizer=MadNLP.Optimizer,
                           per_unit=false,
                           verbose=true,
                           solver_options=("tol" => 1e-9,
                                           "print_level" => MadNLP.ERROR))
        @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test result["bus"]["bus1"]["1"]["vm"] ≈ _MADNLP_EXPECTED_VM atol=1e-3
    end

    @testset "provenance records the solver package actually used" begin
        # Regression guard: provenance used to report a fixed "Ipopt" key, so a
        # MadNLP solve was attributed an Ipopt version whenever Ipopt happened
        # to be loaded too (and recorded no version at all otherwise).
        net = _madnlp_fixture()

        ctx = build_opf_model(net; optimizer=MadNLP.Optimizer, per_unit=false)
        enforce_kcl!(ctx)
        JuMP.optimize!(opf_model(ctx))
        provenance = opf_research_provenance(ctx)
        @test provenance["software"]["solver_package"]["name"] == "MadNLP"
        @test provenance["software"]["solver_package"]["version"] ==
              string(Base.pkgversion(MadNLP))
        @test !haskey(provenance["software"], "Ipopt")
    end
end
