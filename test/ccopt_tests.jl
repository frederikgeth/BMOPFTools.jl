# CCOpt adapter tests. This file is included only when the optional CCOpt,
# MPCCModels, and NLPModelsJuMP packages are available.

const _CCOPT_EXT = Base.get_extension(BMOPFTools, :BMOPFCCOptExt)

@testset "CCOpt complementarity adapter" begin
    @test _CCOPT_EXT !== nothing

    net = parse_bmopf("""
    {
      "bus": {
        "src": {"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[200.0],"v_max":[280.0]},
        "b1":  {"terminal_names":["1","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[200.0],"v_max":[280.0]}
      },
      "voltage_source": {
        "vs": {"bus":"src","terminal_map":["1"],
               "v_magnitude":[260.0],"v_angle":[0.0],"cost":[1.0]}
      },
      "linecode": {"lc": {"R_series_1_1":0.01}},
      "line": {"l1": {"bus_from":"src","bus_to":"b1",
                         "terminal_map_from":["1"],"terminal_map_to":["1"],
                         "linecode":"lc","length":1.0}},
      "load": {"ld": {"bus":"b1","terminal_map":["1","n"],
                         "configuration":"SINGLE_PHASE",
                         "p_nom":[100.0],"q_nom":[0.0]}},
      "control_profile": {
        "vw": {"volt_watt": {"voltage_reference":"PN_PER_PHASE",
                               "breakpoints":[253.0,260.0],
                               "p_limits":[0.20,1.00],
                               "p_unit":"VA_FRACTION","p_ref":"S_MAX"}}
      },
      "ibr": {"pv1": {"bus":"b1","terminal_map":["1","n"],
                         "topology":"SINGLE_PHASE","prime_mover":"PV",
                         "s_max":[3000.0],"p_max":[3000.0],"p_min":[0.0],
                         "q_min":[0.0],"q_max":[0.0],
                         "control_profile":"vw","cost":[0.1]}}
    }
    """; from_string=true)

    handle = build_ccopt_model(net)
    @test length(handle.pair_indices) == 2
    @test handle.mpcc.meta.ncc == 2
    @test all(pair -> pair.left.family == :droop_hinge_value &&
                    pair.right.family == :droop_hinge_slack,
              opf_complementarity_pairs(handle.ctx))
    @test all(pair -> haskey(pair.metadata, "encoding"),
              opf_complementarity_pairs(handle.ctx))

    fake_stats = (status=:ACCEPTABLE,
                  solution=ones(length(handle.variable_positions)),
                  objective=0.0, wall_time=0.0)
    result = extract_ccopt_result(handle; stats=fake_stats)
    @test result["feasible"]
    @test result["termination_status"] == "LOCALLY_SOLVED"
    @test result["ccopt"]["pair_count"] == 2
end
