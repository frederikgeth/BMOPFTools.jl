using Test
using BMOPFTools
using JuMP
using Ipopt
using MockOpfExtension

@testset "installed downstream OPF extension" begin
    net = parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
        "b1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
              "v_min":[200.0],"v_max":[260.0]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
         "v_magnitude":[230.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.01}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}},
     "ibr":{"pv":{"bus":"b1","terminal_map":["1","n"],
         "topology":"SINGLE_PHASE","prime_mover":"PV",
         "s_max":[100.0],"p_min":[1500.0],"p_max":[1500.0],
         "q_min":[0.0],"q_max":[0.0],"cost":[0.0]}}}
    """; from_string=true)

    spec = OpfBuildSpec(component_builders=Dict(
        (:ibr, "pv") => MockOpfExtension.builder()))
    result = solve_opf(net; build_spec=spec)
    @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test result["mock_ibr"]["pv"]["p"] ≈ 1500.0 atol=1e-3

    # A real installed extension can declare, fingerprint, and report a bespoke
    # regularization without importing BMOPFOpfExt or private context fields.
    ctx = build_opf_model(net; build_spec=spec, add_objective=false)
    p_key = OpfModelKey(:expression, :mock_ibr_active_power, "pv")
    p = opf_object(ctx, p_key)
    tie_break = JuMP.@expression(opf_model(ctx), 1e-8 * p)
    tie_break_key = OpfModelKey(:objective, :mock_ibr_tie_break, "pv")
    register_opf_objective_term!(ctx, tie_break_key, tie_break)
    register_opf_regularization!(ctx, :mock_ibr_tie_break;
        method=:linear_tie_break, weight=1e-8, units=:per_unit,
        term_key=tie_break_key, targets=[p_key],
        purpose="Exercise the installed downstream provenance contract",
        owner=:MockOpfExtension)
    register_opf_differentiability_annotation!(ctx, :fixed_mock_regime;
        kind=:dynamic_branch,
        description="Fixture regime is fixed before its parameter sweep",
        owner=:MockOpfExtension, key=p_key, blocking=false)
    JuMP.@objective(opf_model(ctx), Min, generation_cost(ctx) + tie_break)
    enforce_kcl!(ctx)
    JuMP.optimize!(opf_model(ctx))
    provenance = opf_research_provenance(ctx)
    @test provenance["regularizations"][1]["owner"] == "MockOpfExtension"
    @test provenance["differentiability_annotations"][1]["owner"] ==
          "MockOpfExtension"
    @test length(provenance["hashes"]["model_structure_sha256"]) == 64
end
