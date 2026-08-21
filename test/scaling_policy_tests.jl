@testset "Typed OPF scaling policies" begin
    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    @test ext !== nothing
    public_names = Set(names(BMOPFTools))
    @test all(name in public_names for name in (
        :OpfScaling, :OpfDiagnosticSchema,
        :opf_coordinate_bases, :opf_diagnostic_schema,
    ))
    @test all(name ∉ public_names for name in (
        :AbstractOpfScalingPolicy,
        :SIUnitsScaling,
        :ClassicPerUnitScaling,
        :ConsistentPerUnitScaling,
        :ZonePerUnitScaling,
        :opf_scaling_policy,
        :opf_initialization_data,
        :opf_transformer_scaling_contract_data,
        :opf_acdc_scaling_contract_data,
        :opf_semantic_blocks,
        :register_opf_semantic_block!,
        :register_opf_constraint!,
    ))

    @test BMOPFTools.opf_scaling_policy_data(OpfScaling(:si))["kind"] ==
        "si_units"
    @test BMOPFTools.opf_scaling_policy_data(OpfScaling(:classic))["s_base"] ==
        1e6
    @test_throws ArgumentError OpfScaling(:classic; power_base=0.0)
    @test_throws ArgumentError OpfScaling(:si; name=:ignored)
    @test_throws ArgumentError OpfScaling(:classic; name=:ignored)
    @test_throws ArgumentError OpfScaling(
        power_base=1e6, voltage_bases=Dict("source" => -1.0))

    net = parse_bmopf("""
    {"bus":{
        "source":{"terminal_names":["1","n"],
                  "perfectly_grounded_terminals":["n"]},
        "loadbus":{"terminal_names":["1","n"],
                   "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"source":{"bus":"source","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.5,"R_series_2_2":0.5}},
     "line":{"line":{"bus_from":"source","bus_to":"loadbus",
         "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
         "linecode":"lc","length":1.0}},
     "load":{"load":{"bus":"loadbus","terminal_map":["1","n"],
         "configuration":"WYE","p_nom":[100000.0],"q_nom":[20000.0]}}}
    """; from_string=true)

    legacy_bases = ext._compute_bases(net, 1e6)
    classic_bases = ext._compute_bases(net, OpfScaling(:classic; power_base=1e6))
    @test legacy_bases.s_base== classic_bases.s_base
    @test legacy_bases.v_base == classic_bases.v_base
    @test BMOPFTools.opf_scaling_policy_data(
        classic_bases.scaling_policy,
    )["kind"] == "classic_per_unit"

    custom = OpfScaling(
        name=:half_voltage_200kva,
        power_base=2e5,
        voltage_bases=Dict("source" => 500.0, "loadbus" => 500.0))
    custom_bases = ext._compute_bases(net, custom)
    @test custom_bases.v_base["source"] == 500.0
    @test custom_bases.i_base["source"] == 400.0
    @test custom_bases.z_base["source"] == 1.25
    @test custom_bases.y_base["source"] == 0.8
    @test custom_bases.scaling_policy === custom

    missing = OpfScaling(
        power_base=1e6, voltage_bases=Dict("source" => 1000.0))
    @test_throws ArgumentError ext._compute_bases(net, missing)
    mismatched = OpfScaling(
        power_base=1e6,
        voltage_bases=Dict("source" => 1000.0, "loadbus" => 500.0))
    @test_throws ArgumentError ext._compute_bases(net, mismatched)

    custom_net, bases = ext._to_per_unit(net, custom)
    @test custom_net["voltage_source"]["source"]["v_magnitude"][1] == 2.0
    @test bases.scaling_policy === custom

    ctx = build_opf_model(net; scaling_policy=custom, add_objective=false)
    @test BMOPFTools.opf_scaling_policy(ctx) === custom
    @test opf_build_manifest(ctx).per_unit
    @test opf_build_manifest(ctx).s_base== 2e5
    policy_record = opf_research_provenance(ctx)["formulation"]["scaling_policy"]
    @test policy_record["kind"] == "consistent_per_unit"
    @test policy_record["name"] == "half_voltage_200kva"

    current_contract = BMOPFTools.opf_transformer_scaling_contract_data(ctx)
    @test current_contract["available"]
    @test current_contract["proposal_admissible"]
    @test !current_contract["coordinate_change_from_current_model"]
    @test isempty(current_contract["interfaces"])
    inconsistent_zone = BMOPFTools.opf_transformer_scaling_contract_data(
        ctx;
        power_bases=Dict("source" => 1.0e6, "loadbus" => 1.0e5),
    )
    @test inconsistent_zone["available"]
    @test !inconsistent_zone["proposal_admissible"]
    @test !isempty(inconsistent_zone["inconsistent_galvanic_zones"])

    si_ctx = initialize_opf_model(net; scaling_policy=OpfScaling(:si))
    @test opf_bases(si_ctx) === nothing
    @test BMOPFTools.opf_scaling_policy_data(
        BMOPFTools.opf_scaling_policy(si_ctx),
    )["kind"] == "si_units"

    classic_result = solve_pf(net; scaling_policy=OpfScaling(:classic; power_base=1e6))
    custom_result = solve_pf(net; scaling_policy=custom)
    @test classic_result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test custom_result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    for bus in ("source", "loadbus"), terminal in ("1", "n")
        @test custom_result["bus"][bus][terminal]["vr"] ≈
              classic_result["bus"][bus][terminal]["vr"] rtol=2e-7 atol=2e-7
        @test custom_result["bus"][bus][terminal]["vi"] ≈
              classic_result["bus"][bus][terminal]["vi"] rtol=2e-7 atol=2e-7
    end
end

@testset "Zone-local per-unit scaling across an isolated transformer" begin
    net = parse_bmopf(raw"""
    {"bus":{
        "hv":{"terminal_names":["a","n"],
              "perfectly_grounded_terminals":["n"]},
        "lv":{"terminal_names":["x","n"],
              "perfectly_grounded_terminals":["n"]},
        "loadbus":{"terminal_names":["x","n"],
                   "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"source":{"bus":"hv","terminal_map":["a"],
         "v_magnitude":[2400.0],"v_angle":[0.17],"cost":[0.2]}},
     "transformer":{"single_phase":{"tx":{"bus_from":"hv","bus_to":"lv",
         "terminal_map_from":["a","n"],"terminal_map_to":["x","n"],
         "v_nom_from":2400.0,"v_nom_to":240.0,"s_rating":50000.0,
         "r_series_from":1.0,"x_series_from":2.0,
         "r_series_to":0.01,"x_series_to":0.02}}},
     "linecode":{"lc":{"R_series_1_1":0.02,"X_series_1_1":0.01,
                            "R_series_2_2":0.02,"X_series_2_2":0.01}},
     "line":{"line":{"bus_from":"lv","bus_to":"loadbus",
         "terminal_map_from":["x","n"],"terminal_map_to":["x","n"],
         "linecode":"lc","length":1.0}},
     "load":{"load":{"bus":"loadbus","terminal_map":["x","n"],
         "configuration":"WYE","p_nom":[10000.0],"q_nom":[3000.0]}}}
    """; from_string=true)
    original = deepcopy(net)

    zone = OpfScaling(
        name=:transformer_local_power,
        voltage_bases=Dict("hv" => 2400.0, "lv" => 240.0, "loadbus" => 240.0),
        power_bases=Dict("hv" => 1.0e6, "lv" => 25.0e3, "loadbus" => 25.0e3),
    )
    @test BMOPFTools.opf_scaling_policy_data(zone)["kind"] == "zone_per_unit"
    @test_throws ArgumentError build_opf_model(
        net; scaling_policy=OpfScaling(:si), s_base=2.0e6)
    @test_throws ArgumentError build_opf_model(
        net; scaling_policy=OpfScaling(:classic; power_base=2.0e6),
        per_unit=false)
    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    working, bases = ext._to_per_unit(net, zone)
    @test bases.s_base== 1.0e6
    @test bases.s_base_bus == zone.power_bases
    @test bases.i_base["hv"] ≈ 1.0e6 / 2400.0
    @test bases.i_base["lv"] ≈ 25.0e3 / 240.0
    @test working["transformer"]["single_phase"]["tx"][
        "_current_coupling_from_factor"] ≈ 40.0
    @test working["load"]["load"]["p_nom"][1] ≈ 0.4
    @test net == original

    context = build_opf_model(net; scaling_policy=zone, add_objective=false)
    pre_kcl_schema = opf_diagnostic_schema(context)
    @test pre_kcl_schema.capabilities["lifecycle"] == "building"
    @test !pre_kcl_schema.capabilities["semantic_blocks_available"]
    @test !pre_kcl_schema.capabilities["semantic_blocks_registered"]
    @test isempty(pre_kcl_schema.semantic_blocks)
    enforce_kcl!(context)
    post_kcl_schema = opf_diagnostic_schema(context)
    @test post_kcl_schema.capabilities["semantic_blocks_available"]
    @test post_kcl_schema.capabilities["semantic_blocks_registered"]
    @test !isempty(post_kcl_schema.semantic_blocks)
    contract = BMOPFTools.opf_transformer_scaling_contract_data(context)
    @test contract["proposal_admissible"]
    @test contract["applied_to_model"]
    @test !contract["coordinate_change_from_current_model"]
    @test !contract["requires_new_transformer_stamping"]
    @test contract["local_power_base_change_present"]

    si = solve_pf(net; scaling_policy=OpfScaling(:si))
    classic = solve_pf(net; scaling_policy=OpfScaling(:classic; power_base=1.0e6))
    local_result = solve_pf(net; scaling_policy=zone)
    for result in (si, classic, local_result)
        @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end
    for bus in ("hv", "lv", "loadbus"), terminal in
            (bus == "hv" ? ("a", "n") : ("x", "n"))
        @test local_result["bus"][bus][terminal]["vr"] ≈
              si["bus"][bus][terminal]["vr"] rtol=2e-7 atol=2e-6
        @test local_result["bus"][bus][terminal]["vi"] ≈
              si["bus"][bus][terminal]["vi"] rtol=2e-7 atol=2e-6
        @test classic["bus"][bus][terminal]["vr"] ≈
              si["bus"][bus][terminal]["vr"] rtol=2e-7 atol=2e-6
    end
    @test first(values(local_result["load"]["load"]))["pd"] ≈
          first(values(si["load"]["load"]))["pd"] rtol=2e-7
    @test local_result["voltage_source"]["source"]["a"]["ps"] ≈
          si["voltage_source"]["source"]["a"]["ps"] rtol=2e-7
    @test local_result["losses"]["p_loss"] ≈
          si["losses"]["p_loss"] rtol=2e-6 atol=1e-5

    si_opf = solve_opf(net; scaling_policy=OpfScaling(:si))
    local_opf = solve_opf(net; scaling_policy=zone)
    @test local_opf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test local_opf["objective"] ≈ si_opf["objective"] rtol=2e-7 atol=1e-8
    @test local_opf["voltage_source"]["source"]["a"]["ps"] ≈
          si_opf["voltage_source"]["source"]["a"]["ps"] rtol=2e-7

    bad_zone = OpfScaling(
        voltage_bases=zone.voltage_bases,
        power_bases=Dict("hv" => 1.0e6, "lv" => 25.0e3, "loadbus" => 20.0e3),
    )
    @test_throws ArgumentError ext._compute_bases(net, bad_zone)

end

@testset "Zone-local Yd/Dy connection-matrix covariance" begin
    function yd_dy_fixture(subtype)
        if subtype == "wye_delta"
            return parse_bmopf(raw"""
            {"bus":{"hv":{"terminal_names":["1","2","3","n"],
                           "perfectly_grounded_terminals":["n"]},
                    "lv":{"terminal_names":["1","2","3"],
                           "perfectly_grounded_terminals":["1"]}},
             "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
                 "v_magnitude":[6350.0,6350.0,6350.0],
                 "v_angle":[0.0,-2.0943951023931953,2.0943951023931953]}},
             "transformer":{"wye_delta":{"tx":{"bus_from":"hv","bus_to":"lv",
                 "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3"],
                 "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
                 "r_series_from":2.42,"x_series_from":4.84,
                 "r_series_to":0.0034,"x_series_to":0.0069,
                 "g_no_load":1e-4,"b_no_load":2e-4}}},
             "load":{"ld":{"bus":"lv","terminal_map":["1","2"],
                 "configuration":"DELTA","p_nom":[100000.0],"q_nom":[30000.0]}}}
            """; from_string=true)
        end
        return parse_bmopf(raw"""
        {"bus":{"hv":{"terminal_names":["1","2","3"]},
                "lv":{"terminal_names":["1","2","3"]}},
         "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
             "v_magnitude":[6350.0,6350.0,6350.0],
             "v_angle":[0.0,-2.0943951023931953,2.0943951023931953]}},
         "transformer":{"delta_wye":{"tx":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
             "r_series_from":2.42,"x_series_from":4.84,
             "r_series_to":0.0034,"x_series_to":0.0069,
             "g_no_load":1e-4,"b_no_load":2e-4}}},
         "load":{"ld1":{"bus":"lv","terminal_map":["1"],"configuration":"WYE",
                          "p_nom":[80000.0],"q_nom":[20000.0]},
                 "ld2":{"bus":"lv","terminal_map":["2"],"configuration":"WYE",
                          "p_nom":[80000.0],"q_nom":[20000.0]},
                 "ld3":{"bus":"lv","terminal_map":["3"],"configuration":"WYE",
                          "p_nom":[80000.0],"q_nom":[20000.0]}}}
        """; from_string=true)
    end

    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    for subtype in ("wye_delta", "delta_wye")
        @testset "$subtype" begin
            net = yd_dy_fixture(subtype)
            classic_context = build_opf_model(
                net; scaling_policy=OpfScaling(:classic; power_base=1.0e6),
                add_objective=false,
            )
            voltage_bases = Dict(opf_bases(classic_context).v_base)
            zone_policy = OpfScaling(
                name=Symbol(:local_, subtype),
                voltage_bases=voltage_bases,
                power_bases=Dict("hv" => 2.0e6, "lv" => 50.0e3),
            )
            working, bases = ext._to_per_unit(net, zone_policy)
            transformer = working["transformer"][subtype]["tx"]
            expected_delta_to_wye = subtype == "wye_delta" ? 0.025 : 40.0
            @test transformer["_delta_to_wye_power_factor"] ≈
                  expected_delta_to_wye
            @test transformer["_wye_to_delta_power_factor"] ≈
                  inv(expected_delta_to_wye)
            @test transformer["_delta_to_wye_power_factor"] *
                  transformer["_wye_to_delta_power_factor"] ≈ 1.0
            wye_bus = subtype == "wye_delta" ? "hv" : "lv"
            @test transformer[subtype == "wye_delta" ?
                              "_s_rating_from_pu" : "_s_rating_to_pu"] ≈
                  500000.0 / bases.s_base_bus[wye_bus]

            context = build_opf_model(net; scaling_policy=zone_policy, add_objective=false)
            contract = BMOPFTools.opf_transformer_scaling_contract_data(context)
            @test contract["proposal_admissible"]
            @test contract["applied_to_model"]
            @test !contract["requires_new_transformer_stamping"]

            # Use exact PF equations rather than the elastic feasibility model:
            # a relaxation current must not be able to hide a conversion error.
            si = solve_pf(net; scaling_policy=OpfScaling(:si))
            scaled = solve_pf(net; scaling_policy=zone_policy)
            @test si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test scaled["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            for (bus, terminal_data) in si["bus"],
                    (terminal, voltage) in terminal_data
                @test scaled["bus"][bus][terminal]["vr"] ≈ voltage["vr"] rtol=2e-5 atol=2e-4
                @test scaled["bus"][bus][terminal]["vi"] ≈ voltage["vi"] rtol=2e-5 atol=2e-4
            end
            @test scaled["voltage_source"]["src"]["1"]["ps"] ≈
                  si["voltage_source"]["src"]["1"]["ps"] rtol=2e-5 atol=1e-3
            @test scaled["losses"]["p_loss"] ≈ si["losses"]["p_loss"] rtol=2e-4 atol=1e-2
            @test scaled["losses"]["q_loss"] ≈ si["losses"]["q_loss"] rtol=2e-4 atol=1e-2
            @test scaled["transformer"]["tx"]["ground"]["cg_r"] ≈
                  si["transformer"]["tx"]["ground"]["cg_r"] rtol=2e-5 atol=1e-6
            @test scaled["transformer"]["tx"]["ground"]["cg_i"] ≈
                  si["transformer"]["tx"]["ground"]["cg_i"] rtol=2e-5 atol=1e-6
        end
    end

    # Galvanically coupled regulator/autotransformer families remain guarded;
    # they need shared-conductor coordinate proofs rather than isolated-port
    # current conversion.
    guarded = yd_dy_fixture("wye_delta")
    transformer = pop!(guarded["transformer"]["wye_delta"], "tx")
    guarded["transformer"] = Dict(
        "single_phase_autotransformer" => Dict("tx" => transformer),
    )
    guarded_policy = OpfScaling(
        voltage_bases=Dict("hv" => 6350.0, "lv" => 240.0),
        power_bases=Dict("hv" => 2.0e6, "lv" => 50.0e3),
    )
    @test_throws ArgumentError ext._compute_bases(guarded, guarded_policy)
end

@testset "Zone-local galvanic regulator covariance" begin
    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

    function single_regulator_fixture(; free_tap=false)
        network = parse_bmopf(raw"""
        {"bus":{
            "src":{"terminal_names":["1","n"],
                   "perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","n"],
                   "perfectly_grounded_terminals":[]}},
         "voltage_source":{"src":{"bus":"src","terminal_map":["1","n"],
             "v_magnitude":[2400.0],"v_angle":[0.13],"cost":[0.2]}},
         "transformer":{"single_phase_autotransformer":{"regulator":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.025,"regulator_type":"B","s_rating":250000.0,
             "r_series_from":0.45,"x_series_from":0.20,
             "r_series_to":0.08,"x_series_to":0.04,
             "g_no_load":1.0e-6,"b_no_load":3.0e-6,
             "i_max_from":[150.0],"i_max_to":[150.0]}}},
         "load":{"load":{"bus":"reg","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[50000.0],
             "q_nom":[12000.0]}}}
        """; from_string=true)
        if free_tap
            regulator = network["transformer"][
                "single_phase_autotransformer"]["regulator"]
            regulator["tap_ratio_min"] = 0.98
            regulator["tap_ratio_max"] = 1.06
        end
        return network
    end

    function open_delta_regulator_fixture(; free_tap=false)
        network = parse_bmopf(raw"""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"src":{"bus":"src",
             "terminal_map":["1","2","3"],
             "v_magnitude":[2400.0,2400.0,2400.0],
             "v_angle":[0.13,-1.9643951023931953,2.2243951023931953],
             "cost":[0.2]}},
         "transformer":{"open_delta_regulator":{"bank":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],
             "connection":"ABBC","tap_ratio":[1.025,0.99],
             "regulator_type":"B","s_rating":250000.0,
             "r_series_from":0.35,"x_series_from":0.15,
             "r_series_to":0.05,"x_series_to":0.02,
             "g_no_load":8.0e-7,"b_no_load":2.0e-6,
             "i_max_from":[150.0,150.0,150.0],
             "i_max_to":[150.0,150.0]}}},
         "load":{"load":{"bus":"reg",
             "terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[30000.0,20000.0,25000.0],
             "q_nom":[6000.0,4000.0,5000.0]}}}
        """; from_string=true)
        if free_tap
            regulator = network["transformer"]["open_delta_regulator"]["bank"]
            regulator["tap_ratio_min"] = [0.98, 0.97]
            regulator["tap_ratio_max"] = [1.06, 1.04]
        end
        return network
    end

    zone_policy = OpfScaling(
        name=:galvanic_regulator_zone,
        voltage_bases=Dict("src" => 2400.0, "reg" => 2400.0),
        power_bases=Dict("src" => 500.0e3, "reg" => 500.0e3),
    )

    function compare_physical_results(si, scaled, transformer_id)
        @test scaled["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        for (bus, terminals) in si["bus"], (terminal, voltage) in terminals
            @test scaled["bus"][bus][terminal]["vr"] ≈ voltage["vr"] rtol=2e-5 atol=2e-4
            @test scaled["bus"][bus][terminal]["vi"] ≈ voltage["vi"] rtol=2e-5 atol=2e-4
        end
        for side in ("fr", "to"), (index, current) in
                si["transformer"][transformer_id][side]
            @test scaled["transformer"][transformer_id][side][index]["cr"] ≈
                  current["cr"] rtol=3e-5 atol=2e-5
            @test scaled["transformer"][transformer_id][side][index]["ci"] ≈
                  current["ci"] rtol=3e-5 atol=2e-5
        end
        @test scaled["losses"]["p_loss"] ≈ si["losses"]["p_loss"] rtol=3e-5 atol=2e-3
        @test scaled["losses"]["q_loss"] ≈ si["losses"]["q_loss"] rtol=3e-5 atol=2e-3
    end

    for (label, fixture, subtype, transformer_id) in (
            ("single-phase", single_regulator_fixture,
             "single_phase_autotransformer", "regulator"),
            ("open-delta", open_delta_regulator_fixture,
             "open_delta_regulator", "bank"),
        )
        @testset "$label fixed and free taps" begin
            network = fixture()
            working, bases = ext._to_per_unit(network, zone_policy)
            transformer = working["transformer"][subtype][transformer_id]
            @test transformer["_s_base_from"] == transformer["_s_base_to"] == 500.0e3
            @test transformer["_current_coupling_from_factor"] == 1.0
            @test bases.v_base["src"] == bases.v_base["reg"]
            @test bases.i_base["src"] == bases.i_base["reg"]

            local_context = build_opf_model(
                network; scaling_policy=zone_policy, add_objective=false,
            )
            contract = BMOPFTools.opf_transformer_scaling_contract_data(local_context)
            @test contract["proposal_admissible"]
            @test contract["galvanic_voltage_compatibility_passed"]
            @test isempty(contract["inconsistent_galvanic_voltage_interfaces"])
            @test length(contract["interfaces"]) == 1
            interface = only(contract["interfaces"])
            @test interface["galvanically_continuous"]
            @test interface["same_galvanic_zone"]
            @test interface["galvanic_voltage_base_compatible"]
            @test !interface["requires_shared_conductor_voltage_conversion"]
            @test !interface["requires_explicit_current_conversion"]
            @test !interface["requires_explicit_power_conversion"]

            si = solve_pf(network; scaling_policy=OpfScaling(:si))
            scaled = solve_pf(network; scaling_policy=zone_policy)
            @test si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            compare_physical_results(si, scaled, transformer_id)

            free_network = fixture(; free_tap=true)
            si_free = build_opf_model(
                free_network; scaling_policy=OpfScaling(:si), add_objective=false,
            )
            local_free = build_opf_model(
                free_network; scaling_policy=zone_policy, add_objective=false,
            )
            si_init = BMOPFTools.opf_initialization_data(si_free)
            local_init = BMOPFTools.opf_initialization_data(local_free)
            @test si_init["maximum_normalized_physics_residual"] < 1e-10
            @test local_init["maximum_normalized_physics_residual"] < 1e-10
            @test isempty(si_init["unsupported_transformer_subtypes"])
            @test isempty(local_init["unsupported_transformer_subtypes"])
            @test count(variable -> startswith(JuMP.name(variable), "tap_"),
                        JuMP.all_variables(opf_model(local_free))) ==
                  (subtype == "open_delta_regulator" ? 2 : 1)
        end
    end

    # A tap is dimensionless, but a shared copper conductor is not a coordinate
    # boundary.  The proposal audit and applied policy must both reject either
    # voltage or power coordinates that jump across the regulator.
    si_context = build_opf_model(
        single_regulator_fixture();
        scaling_policy=OpfScaling(:si), add_objective=false,
    )
    bad_voltage = BMOPFTools.opf_transformer_scaling_contract_data(
        si_context;
        voltage_bases=Dict("src" => 2400.0, "reg" => 1200.0),
        power_bases=Dict("src" => 500.0e3, "reg" => 500.0e3),
    )
    @test !bad_voltage["proposal_admissible"]
    @test !bad_voltage["galvanic_voltage_compatibility_passed"]
    @test bad_voltage["requires_new_transformer_stamping"]
    @test bad_voltage["inconsistent_galvanic_voltage_interfaces"] ==
          ["single_phase_autotransformer/regulator:src->reg"]
    @test only(bad_voltage["interfaces"])[
        "requires_shared_conductor_voltage_conversion"]
    @test_throws ArgumentError ext._compute_bases(
        single_regulator_fixture(),
        OpfScaling(
            voltage_bases=Dict("src" => 2400.0, "reg" => 1200.0),
            power_bases=Dict("src" => 500.0e3, "reg" => 500.0e3),
        ),
    )
    @test_throws ArgumentError ext._compute_bases(
        single_regulator_fixture(),
        OpfScaling(
            voltage_bases=Dict("src" => 2400.0, "reg" => 2400.0),
            power_bases=Dict("src" => 500.0e3, "reg" => 50.0e3),
        ),
    )
end

@testset "Zone-local AC/DC converter covariance" begin
    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    function converter_fixture(; droop=false)
        network = parse_bmopf(raw"""
        {"bus":{
            "f1":{"terminal_names":["a","n"],
                  "perfectly_grounded_terminals":["n"]},
            "f2":{"terminal_names":["a","n"],
                  "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{
            "s1":{"bus":"f1","terminal_map":["a"],
                  "v_magnitude":[230.0],"v_angle":[0.0],"cost":[0.1]},
            "s2":{"bus":"f2","terminal_map":["a"],
                  "v_magnitude":[230.0],"v_angle":[0.0],"cost":[0.3]}},
         "load":{"load":{"bus":"f2","terminal_map":["a","n"],
            "configuration":"SINGLE_PHASE","p_nom":[5000.0],"q_nom":[0.0]}},
         "ibr":{
            "vsc1":{"bus":"f1","terminal_map":["a","n"],
                "topology":"SINGLE_PHASE","prime_mover":"GENERIC",
                "s_max":[8000.0],"dc_bus":"dcA",
                "dc_terminal_map":["p","m"],"dc_control":"V",
                "dc_v_set":850.0},
            "vsc2":{"bus":"f2","terminal_map":["a","n"],
                "topology":"SINGLE_PHASE","prime_mover":"GENERIC",
                "s_max":[8000.0],"dc_bus":"dcB",
                "dc_terminal_map":["p","m"]}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],"v_dc_nom":[850.0,0.0],
                "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]},
            "dcB":{"terminal_names":["p","m"],"v_dc_nom":[850.0,0.0],
                "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
         "dc_branch":{"tie":{"dc_bus_from":"dcA","dc_bus_to":"dcB",
            "terminal_map_from":["p","m"],"terminal_map_to":["p","m"],
            "r":[0.5,0.0],"i_max":[20.0,20.0],"p_max":12000.0}},
         "dc_grounding":{"ground":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
        """; from_string=true)
        if droop
            vsc = network["ibr"]["vsc2"]
            vsc["dc_control"] = "droop"
            vsc["dc_v_set"] = 840.0
            vsc["dc_p_ref"] = 3000.0
            vsc["dc_deadband"] = 2.0
            vsc["dc_droop"] = 0.01
        end
        return network
    end

    policy = OpfScaling(
        name=:acdc_local_power,
        voltage_bases=Dict("f1" => 230.0, "f2" => 230.0),
        power_bases=Dict("f1" => 1.0e6, "f2" => 100.0e3),
        dc_voltage_base=850.0,
        dc_power_base=20.0e3,
    )
    network = converter_fixture()
    working, bases = ext._to_per_unit(network, policy)
    @test bases.s_dc_base == 20.0e3
    @test working["ibr"]["vsc1"]["_ac_to_dc_power_factor"] == 50.0
    @test working["ibr"]["vsc2"]["_ac_to_dc_power_factor"] == 5.0
    @test working["dc_branch"]["tie"]["r"][1] ≈ 0.5 / (850.0^2 / 20.0e3)

    context = build_opf_model(network; scaling_policy=policy, add_objective=false)
    ac1 = opf_coordinate_bases(context, "f1")
    ac2 = opf_coordinate_bases(context, "f2")
    dc = opf_coordinate_bases(context, "dcA"; domain=:dc)
    @test ac1.power == 1.0e6
    @test ac2.power == 100.0e3
    @test dc.power == 20.0e3
    @test ac1.voltage * ac1.current == ac1.power
    @test dc.voltage * dc.current == dc.power
    @test_throws ArgumentError opf_coordinate_bases(context, "missing")
    @test_throws ArgumentError opf_coordinate_bases(
        context, "missing"; domain=:dc,
    )
    contract = BMOPFTools.opf_acdc_scaling_contract_data(context)
    @test contract["available"]
    @test contract["applied_to_model"]
    @test contract["converter_count"] == 2
    @test contract["distinct_power_coordinates_present"]
    @test contract["coefficient_contract_passed"]
    @test contract["control_modes_qualified"]
    @test [record["expected_ac_to_dc_power_factor"]
           for record in contract["converters"]] == [50.0, 5.0]

    # The differently based model must recover the same loaded converter tie,
    # including the newly public DC-port voltage/current/power record.
    si = solve_opf(network; scaling_policy=OpfScaling(:si))
    scaled = solve_opf(network; scaling_policy=policy)
    @test si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test scaled["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test scaled["objective"] ≈ si["objective"] rtol=2e-5 atol=1e-5
    for bus in ("f1", "f2"), terminal in ("a", "n")
        @test scaled["bus"][bus][terminal]["vr"] ≈
              si["bus"][bus][terminal]["vr"] rtol=2e-5 atol=2e-5
        @test scaled["bus"][bus][terminal]["vi"] ≈
              si["bus"][bus][terminal]["vi"] rtol=2e-5 atol=2e-5
    end
    for converter in ("vsc1", "vsc2")
        @test scaled["ibr"][converter]["a"]["pg"] ≈
              si["ibr"][converter]["a"]["pg"] rtol=3e-5 atol=2e-3
        for field in ("v_dc", "i_dc", "p_dc")
            @test scaled["ibr"][converter]["dc_port"][field] ≈
                  si["ibr"][converter]["dc_port"][field] rtol=3e-5 atol=2e-3
        end
    end
    for bus in ("dcA", "dcB"), terminal in ("p", "m")
        @test scaled["dc_bus"][bus][terminal]["v_dc"] ≈
              si["dc_bus"][bus][terminal]["v_dc"] rtol=3e-5 atol=2e-3
    end
    for conductor in ("1", "2")
        @test scaled["dc_branch"]["tie"][conductor]["i_dc"] ≈
              si["dc_branch"]["tie"][conductor]["i_dc"] rtol=3e-5 atol=2e-4
    end

    # Droop power lives in the AC coordinate of its converter, while its
    # voltage argument lives in the common DC coordinate.
    droop_working, _ = ext._to_per_unit(converter_fixture(; droop=true), policy)
    droop = droop_working["ibr"]["vsc2"]
    @test droop["dc_p_ref"] ≈ 3000.0 / 100.0e3
    @test droop["dc_droop"] ≈ 0.01 * 100.0e3 / 850.0
    @test droop["dc_v_set"] ≈ 840.0 / 850.0
    @test droop["dc_deadband"] ≈ 2.0 / 850.0

    si_context = build_opf_model(
        network; scaling_policy=OpfScaling(:si), add_objective=false,
    )
    @test opf_coordinate_bases(si_context, "f1").power == 1.0
    @test opf_coordinate_bases(si_context, "dcA"; domain=:dc).power == 1.0
    @test BMOPFTools.opf_acdc_scaling_contract_data(si_context)[
        "coefficient_contract_passed"]
end

@testset "Zone-local center-tap three-port covariance" begin
    function center_tap_fixture(; explicit_t_model=false)
        network = parse_bmopf(raw"""
        {"bus":{"mv":{"terminal_names":["1","n"],
                       "perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","n","2"],
                       "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"src":{"bus":"mv","terminal_map":["1"],
             "v_magnitude":[2400.0],"v_angle":[0.11],"cost":[0.2]}},
         "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
             "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
             "i_max_from":[100.0,100.0],"i_max_to":[1000.0,1000.0,1000.0],
             "r_series_from":0.1,"x_series_from":0.4,
             "r_series_to":0.001,"x_series_to":0.004,
             "g_no_load":2e-5,"b_no_load":8e-5}}},
         "load":{"l1":{"bus":"lv","terminal_map":["1","n"],
                         "configuration":"SINGLE_PHASE",
                         "p_nom":[3000.0],"q_nom":[500.0]},
                 "l2":{"bus":"lv","terminal_map":["2","n"],
                         "configuration":"SINGLE_PHASE",
                         "p_nom":[1000.0],"q_nom":[100.0]}}}
        """; from_string=true)
        if explicit_t_model
            network["transformer"]["center_tap"]["ct"]["r_series_from"] = 0.0
            network["transformer"]["center_tap"]["ct"]["x_series_from"] = 0.0
        end
        return network
    end

    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    zone_policy = OpfScaling(
        name=:center_tap_local_power,
        voltage_bases=Dict("mv" => 2400.0, "lv" => 120.0),
        power_bases=Dict("mv" => 1.0e6, "lv" => 25.0e3),
    )
    for (label, explicit_t_model) in
            (("fixed primitive", false), ("explicit T model", true))
        @testset "$label" begin
            net = center_tap_fixture(; explicit_t_model)
            working, bases = ext._to_per_unit(net, zone_policy)
            transformer = working["transformer"]["center_tap"]["ct"]
            @test transformer["_current_coupling_from_factor"] ≈ 40.0
            @test transformer["_s_rating_from_pu"] ≈ 0.025
            @test transformer["_s_rating_to_pu"] ≈ 1.0
            @test bases.i_base["mv"] ≈ 1.0e6 / 2400.0
            @test bases.i_base["lv"] ≈ 25.0e3 / 120.0
            @test transformer["i_max_from"][1] ≈ 0.24
            @test transformer["i_max_to"][1] ≈ 4.8

            context = build_opf_model(
                net; scaling_policy=zone_policy, add_objective=false,
            )
            constraint_families = Set(
                key.family for key in opf_object_keys(context; kind=:constraint)
            )
            if explicit_t_model
                @test :transformer_current_coupling_real in constraint_families
                @test :transformer_current_pin_real ∉ constraint_families
            else
                @test :transformer_current_pin_real in constraint_families
                @test :transformer_current_coupling_real ∉ constraint_families
            end
            contract = BMOPFTools.opf_transformer_scaling_contract_data(context)
            @test contract["proposal_admissible"]
            @test contract["applied_to_model"]
            @test !contract["requires_new_transformer_stamping"]

            si = solve_pf(net; scaling_policy=OpfScaling(:si))
            scaled = solve_pf(net; scaling_policy=zone_policy)
            @test si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test scaled["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            for (bus, terminal_data) in si["bus"],
                    (terminal, voltage) in terminal_data
                @test scaled["bus"][bus][terminal]["vr"] ≈ voltage["vr"] rtol=2e-6 atol=2e-5
                @test scaled["bus"][bus][terminal]["vi"] ≈ voltage["vi"] rtol=2e-6 atol=2e-5
            end
            @test scaled["voltage_source"]["src"]["1"]["ps"] ≈
                  si["voltage_source"]["src"]["1"]["ps"] rtol=2e-6 atol=1e-4
            @test scaled["losses"]["p_loss"] ≈ si["losses"]["p_loss"] rtol=2e-5 atol=1e-4
            @test scaled["losses"]["q_loss"] ≈ si["losses"]["q_loss"] rtol=2e-5 atol=1e-4
            for side in ("fr", "to"), (position, current) in
                    si["transformer"]["ct"][side]
                @test scaled["transformer"]["ct"][side][position]["cr"] ≈
                      current["cr"] rtol=2e-6 atol=1e-5
                @test scaled["transformer"]["ct"][side][position]["ci"] ≈
                      current["ci"] rtol=2e-6 atol=1e-5
            end
            @test scaled["transformer"]["ct"]["fr"]["1"]["s_max"] ≈ 25000.0

            si_opf = solve_opf(net; scaling_policy=OpfScaling(:si))
            local_opf = solve_opf(net; scaling_policy=zone_policy)
            @test local_opf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test local_opf["objective"] ≈ si_opf["objective"] rtol=2e-6 atol=1e-7
        end
    end
end

@testset "Zone-local n-winding multi-port covariance" begin
    net = parse_bmopf(raw"""
    {"bus":{
        "hv":{"terminal_names":["a","b","c","n"],
              "perfectly_grounded_terminals":["n"]},
        "mv":{"terminal_names":["a","b","c","n"],
              "perfectly_grounded_terminals":["n"]},
        "lv":{"terminal_names":["a","b","c","n"],
              "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"src":{"bus":"hv",
         "terminal_map":["a","b","c"],
         "v_magnitude":[2400.0,2400.0,2400.0],
         "v_angle":[0.17,-1.9243951023931953,2.2643951023931953],
         "cost":[0.2,0.2,0.2]}},
     "transformer":{"n_winding":{"nw":{"s_rating":500000.0,
         "g_no_load":1e-5,"b_no_load":4e-5,
         "windings":[
           {"bus":"hv","terminal_map":["a","b","c","n"],
            "v_nom":2400.0,"configuration":"WYE","r_winding":0.08,
            "i_max":500.0,"s_max":500000.0},
           {"bus":"mv","terminal_map":["a","b","c","n"],
            "v_nom":480.0,"configuration":"WYE","r_winding":0.003,
            "i_max":800.0,"s_max":200000.0},
           {"bus":"lv","terminal_map":["a","b","c","n"],
            "v_nom":120.0,"configuration":"WYE","r_winding":0.0002,
            "i_max":1000.0,"s_max":50000.0}],
         "x_sc":{"1_2":0.40,"1_3":0.55,"2_3":0.30}}}},
     "load":{
       "mvload":{"bus":"mv","terminal_map":["a","b","c","n"],
         "configuration":"WYE","p_nom":[10000.0,9000.0,11000.0],
         "q_nom":[2000.0,1800.0,2200.0]},
       "lvload":{"bus":"lv","terminal_map":["a","b","c","n"],
         "configuration":"WYE","p_nom":[2000.0,1500.0,2500.0],
         "q_nom":[400.0,300.0,500.0]}}}
    """; from_string=true)

    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    zone_policy = OpfScaling(
        name=:n_winding_local_power,
        voltage_bases=Dict("hv" => 2400.0, "mv" => 480.0, "lv" => 120.0),
        power_bases=Dict("hv" => 1.0e6, "mv" => 100.0e3, "lv" => 20.0e3),
    )
    working, bases = ext._to_per_unit(net, zone_policy)
    transformer = working["transformer"]["n_winding"]["nw"]
    @test transformer["_ampere_turn_power_factors"] ≈ [1.0, 0.1, 0.02]
    @test transformer["s_rating"] ≈ 0.5
    @test transformer["windings"][1]["i_max"] ≈ 1.2
    @test transformer["windings"][2]["i_max"] ≈ 3.84
    @test transformer["windings"][3]["i_max"] ≈ 6.0
    @test transformer["windings"][1]["s_max"] ≈ 0.5
    @test transformer["windings"][2]["s_max"] ≈ 2.0
    @test transformer["windings"][3]["s_max"] ≈ 2.5
    @test bases.i_base["hv"] ≈ 1.0e6 / 2400.0
    @test bases.i_base["mv"] ≈ 100.0e3 / 480.0
    @test bases.i_base["lv"] ≈ 20.0e3 / 120.0

    context = build_opf_model(
        net; scaling_policy=zone_policy, add_objective=false,
    )
    contract = BMOPFTools.opf_transformer_scaling_contract_data(context)
    @test contract["proposal_admissible"]
    @test contract["applied_to_model"]
    @test !contract["requires_new_transformer_stamping"]
    @test length(contract["interfaces"]) == 2
    @test all(interface -> interface["subtype"] == "n_winding",
              contract["interfaces"])
    @test sort([interface["power_coordinate_ratio_to_from"]
                for interface in contract["interfaces"]]) ≈ [0.02, 0.1]

    si = solve_pf(net; scaling_policy=OpfScaling(:si))
    scaled = solve_pf(net; scaling_policy=zone_policy)
    @test si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test scaled["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    for (bus, terminal_data) in si["bus"],
            (terminal, voltage) in terminal_data
        @test scaled["bus"][bus][terminal]["vr"] ≈ voltage["vr"] rtol=3e-6 atol=3e-5
        @test scaled["bus"][bus][terminal]["vi"] ≈ voltage["vi"] rtol=3e-6 atol=3e-5
    end
    for winding in ("w1", "w2", "w3"),
            (position, current) in si["transformer"]["nw"][winding]
        @test scaled["transformer"]["nw"][winding][position]["cr"] ≈
              current["cr"] rtol=3e-6 atol=3e-5
        @test scaled["transformer"]["nw"][winding][position]["ci"] ≈
              current["ci"] rtol=3e-6 atol=3e-5
    end
    @test sum(phase["ps"] for phase in values(
              scaled["voltage_source"]["src"])) ≈
          sum(phase["ps"] for phase in values(
              si["voltage_source"]["src"])) rtol=3e-6 atol=1e-3
    @test scaled["losses"]["p_loss"] ≈ si["losses"]["p_loss"] rtol=3e-5 atol=1e-3
    @test scaled["losses"]["q_loss"] ≈ si["losses"]["q_loss"] rtol=3e-5 atol=1e-3
    @test scaled["transformer"]["nw"]["w2"]["1"]["s_max"] ≈ 200000.0 / 3
    @test scaled["transformer"]["nw"]["w3"]["1"]["s_max"] ≈ 50000.0 / 3

    si_opf = solve_opf(net; scaling_policy=OpfScaling(:si))
    local_opf = solve_opf(net; scaling_policy=zone_policy)
    @test si_opf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test local_opf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test local_opf["objective"] ≈ si_opf["objective"] rtol=3e-6 atol=1e-7
end

@testset "Voltage warm-start scaling invariance across voltage levels" begin
    net = parse_bmopf(raw"""
    {"bus":{
        "hv":{"terminal_names":["1","2","3","n"],
              "perfectly_grounded_terminals":["n"]},
        "lv":{"terminal_names":["1","2","3"],
              "perfectly_grounded_terminals":["1"]}},
     "voltage_source":{"source":{"bus":"hv",
         "terminal_map":["1","2","3"],
         "v_magnitude":[6350.0,6350.0,6350.0],
         "v_angle":[0.0,-2.0943951023931953,2.0943951023931953]}},
     "transformer":{"wye_delta":{"t1":{
         "bus_from":"hv","bus_to":"lv",
         "terminal_map_from":["1","2","3","n"],
         "terminal_map_to":["1","2","3"],
         "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
         "r_series_from":2.42,"x_series_from":4.84,
         "r_series_to":0.003445,"x_series_to":0.00689}}}}
    """; from_string=true)

    classic = OpfScaling(:classic; power_base=1.0e6)
    classic_probe = build_opf_model(
        net; scaling_policy=classic, add_objective=false,
    )
    classic_bases = opf_bases(classic_probe)
    custom = OpfScaling(
        name=:scaled_voltage_coordinates,
        power_base=2.5e5,
        voltage_bases=Dict(
            "hv" => 0.65classic_bases.v_base["hv"],
            "lv" => 0.65classic_bases.v_base["lv"],
        ),
    )
    contexts = [
        build_opf_model(
            net; scaling_policy=OpfScaling(:si), add_objective=false,
        ),
        classic_probe,
        build_opf_model(net; scaling_policy=custom, add_objective=false),
    ]

    function start_coordinate(context, bus, terminal)
        vr = opf_object(
            context, OpfModelKey(:variable, :vr, (bus, terminal)),
        )
        vi = opf_object(
            context, OpfModelKey(:variable, :vi, (bus, terminal)),
        )
        real = JuMP.is_fixed(vr) ? JuMP.fix_value(vr) : JuMP.start_value(vr)
        imag = JuMP.is_fixed(vi) ? JuMP.fix_value(vi) : JuMP.start_value(vi)
        return complex(real, imag)
    end

    physical_starts = Dict{String,Vector{ComplexF64}}[]
    model_starts = Dict{String,Vector{ComplexF64}}[]
    for context in contexts
        bases = opf_bases(context)
        by_bus = Dict{String,Vector{ComplexF64}}()
        for bus in ("hv", "lv")
            voltage_base = isnothing(bases) ? 1.0 : bases.v_base[bus]
            terminals = bus == "hv" ? ("1", "2", "3", "n") :
                ("1", "2", "3")
            model_values = ComplexF64[
                start_coordinate(context, bus, terminal)
                for terminal in terminals
            ]
            physical = voltage_base .* model_values
            by_bus[bus] = physical
            if bus == "hv"
                @test all(isapprox(abs(value), 6350.0; atol=1e-10)
                          for value in physical[1:3])
                angles = angle.(model_values[1:3])
                @test isapprox(
                    rem2pi(angles[2] - angles[1], RoundNearest),
                    -2pi / 3;
                    atol=1e-5,
                )
                @test isapprox(
                    rem2pi(angles[3] - angles[1], RoundNearest),
                    2pi / 3;
                    atol=1e-5,
                )
                @test physical[4] == 0.0 + 0.0im
            end
        end
        push!(physical_starts, by_bus)
        push!(model_starts, Dict(
            bus => ComplexF64[
                start_coordinate(context, bus, terminal)
                for terminal in (bus == "hv" ? ("1", "2", "3", "n") :
                    ("1", "2", "3"))
            ] for bus in ("hv", "lv")
        ))
    end
    for candidate in physical_starts[2:end], bus in ("hv", "lv")
        @test candidate[bus] ≈ first(physical_starts)[bus] atol=1e-10
    end
    # Coordinate magnitudes do change with V_base even though the represented
    # physical start and all phase relations above are invariant.
    @test abs(model_starts[1]["hv"][1]) ≈ 6350.0 atol=1e-10
    @test abs(model_starts[2]["hv"][1]) ≈ 1.0 atol=1e-12
    @test abs(model_starts[3]["hv"][1]) ≈ inv(0.65) atol=1e-12
end

@testset "Compositional transformer phasor warm starts" begin
    start_complex(context, bus, terminal) = begin
        real_variable = opf_object(
            context, OpfModelKey(:variable, :vr, (bus, terminal)),
        )
        imaginary_variable = opf_object(
            context, OpfModelKey(:variable, :vi, (bus, terminal)),
        )
        real_value = JuMP.is_fixed(real_variable) ?
            JuMP.fix_value(real_variable) : JuMP.start_value(real_variable)
        imaginary_value = JuMP.is_fixed(imaginary_variable) ?
            JuMP.fix_value(imaginary_variable) : JuMP.start_value(imaginary_variable)
        complex(real_value, imaginary_value)
    end
    start_physical(context, bus, terminal) = begin
        value = start_complex(context, bus, terminal)
        bases = opf_bases(context)
        bases === nothing ? value : bases.v_base[bus] * value
    end

    @testset "single-phase lateral inherits its actual parent phase" begin
        net = parse_bmopf(raw"""
        {"bus":{
            "mv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]},
            "lv":{"terminal_names":["x","n"],
                  "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"source":{"bus":"mv",
             "terminal_map":["a","b","c"],
             "v_magnitude":[6350.0,6350.0,6350.0],
             "v_angle":[0.29670597283903605,-1.7976891295541593,2.3911010752322315]}},
         "transformer":{"single_phase":{"tb":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["b","n"],"terminal_map_to":["x","n"],
             "v_nom_from":6350.0,"v_nom_to":230.0,"s_rating":25000.0,
             "r_series_from":0.0,"x_series_from":0.0,
             "r_series_to":0.0,"x_series_to":0.0}}}}
        """; from_string=true)
        context = build_opf_model(
            net; scaling_policy=OpfScaling(:si), add_objective=false,
        )
        source_b = start_complex(context, "mv", "b")
        lv_x = start_complex(context, "lv", "x")
        @test abs(lv_x) ≈ 230.0 atol=1e-7
        @test abs(rem2pi(angle(lv_x) - angle(source_b), RoundNearest)) < 1e-9
        transport = extension_state!(context, :BMOPFToolsInitialization)
        @test transport[:phasor_transport].applied
        @test transport[:phasor_transport].maximum_normalized_physics_residual < 1e-10
        evidence = BMOPFTools.opf_initialization_data(context)
        @test evidence["available"]
        @test evidence["applied"]
        @test evidence["equation_count_by_kind"]["single_phase_transformer"] == 1
        @test evidence["transformer_component_count_by_subtype"]["single_phase"] == 1
        @test isempty(evidence["unsupported_transformer_subtypes"])
    end

    @testset "center tap inherits parent phase and reverses leg polarity" begin
        net = parse_bmopf(raw"""
        {"bus":{
            "mv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]},
            "lv":{"terminal_names":["l1","n","l2"],
                  "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"source":{"bus":"mv",
             "terminal_map":["a","b","c"],
             "v_magnitude":[2400.0,2400.0,2400.0],
             "v_angle":[0.29670597283903605,-1.7976891295541593,2.3911010752322315]}},
         "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["c","n"],"terminal_map_to":["l1","n","l2"],
             "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
             "r_series_from":0.0,"x_series_from":0.0,
             "r_series_to":0.0,"x_series_to":0.0}}}}
        """; from_string=true)
        context = build_opf_model(
            net; scaling_policy=OpfScaling(:si), add_objective=false,
        )
        parent = start_complex(context, "mv", "c")
        leg_one = start_complex(context, "lv", "l1")
        leg_two = start_complex(context, "lv", "l2")
        @test abs(leg_one) ≈ 120.0 atol=1e-7
        @test abs(leg_two) ≈ 120.0 atol=1e-7
        @test abs(rem2pi(angle(leg_one) - angle(parent), RoundNearest)) < 1e-9
        @test isapprox(
            abs(rem2pi(angle(leg_two) - angle(leg_one), RoundNearest)), π;
            atol=1e-9,
        )
    end

    @testset "chained Yd/Dy vector-group equations" begin
        net = parse_bmopf(raw"""
        {"bus":{
            "hv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]},
            "delta":{"terminal_names":["a","b","c"]},
            "lv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"source":{"bus":"hv",
             "terminal_map":["a","b","c"],
             "v_magnitude":[6350.0,6350.0,6350.0],
             "v_angle":[0.29670597283903605,-1.7976891295541593,2.3911010752322315]}},
         "transformer":{
           "wye_delta":{"yd":{"bus_from":"hv","bus_to":"delta",
             "terminal_map_from":["a","b","c","n"],
             "terminal_map_to":["a","b","c"],
             "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
             "r_series_from":0.0,"x_series_from":0.0,
             "r_series_to":0.0,"x_series_to":0.0}},
           "delta_wye":{"dy":{"bus_from":"delta","bus_to":"lv",
             "terminal_map_from":["a","b","c"],
             "terminal_map_to":["a","b","c","n"],
             "v_nom_from":415.0,"v_nom_to":230.0,"s_rating":100000.0,
             "r_series_from":0.0,"x_series_from":0.0,
             "r_series_to":0.0,"x_series_to":0.0}}}}
        """; from_string=true)
        context = build_opf_model(
            net; scaling_policy=OpfScaling(:si), add_objective=false,
        )
        hv = [start_complex(context, "hv", phase) for phase in ("a", "b", "c")]
        delta = [start_complex(context, "delta", phase) for phase in ("a", "b", "c")]
        lv = [start_complex(context, "lv", phase) for phase in ("a", "b", "c")]
        effective_yd = sqrt(3.0) / (11000.0 / 415.0)
        effective_dy = (415.0 / 230.0) * sqrt(3.0)
        for k in 1:3
            next = mod1(k + 1, 3)
            previous = mod1(k - 1, 3)
            @test delta[k] - delta[next] ≈ effective_yd * hv[k] atol=1e-5
            @test delta[k] - delta[previous] ≈ effective_dy * lv[k] atol=1e-5
        end
        transport = extension_state!(context, :BMOPFToolsInitialization)
        @test transport[:phasor_transport].maximum_normalized_physics_residual < 1e-10

        # A coordinate change must preserve the complete physical phasor start,
        # including the two transformer phase shifts and the floating delta gauge
        # selected by the deterministic prior.
        pu_context = build_opf_model(
            net; scaling_policy=OpfScaling(:classic; power_base=1.0e6),
            add_objective=false,
        )
        for bus in ("hv", "delta", "lv"), phase in ("a", "b", "c")
            @test start_physical(pu_context, bus, phase) ≈
                  start_physical(context, bus, phase) atol=1e-5
        end
        pu_evidence = BMOPFTools.opf_initialization_data(pu_context)
        @test pu_evidence["maximum_normalized_physics_residual"] < 1e-10
        @test pu_evidence["equation_count_by_kind"]["wye_delta"] == 3
        @test pu_evidence["equation_count_by_kind"]["delta_wye"] == 3

        local_power_contract = BMOPFTools.opf_transformer_scaling_contract_data(
            context;
            voltage_bases=Dict(
                "hv" => 6350.0,
                "delta" => 415.0 / sqrt(3.0),
                "lv" => 230.0 / sqrt(3.0),
            ),
            power_bases=Dict(
                "hv" => 10.0e6,
                "delta" => 1.0e6,
                "lv" => 100.0e3,
            ),
        )
        @test local_power_contract["available"]
        @test local_power_contract["proposal_admissible"]
        @test local_power_contract["local_power_base_change_present"]
        @test local_power_contract["requires_new_transformer_stamping"]
        @test local_power_contract["power_product_identity_passed"]
        @test length(local_power_contract["interfaces"]) == 2
        @test all(interface ->
            interface["power_product_identity_relative_error"] <= 1.0e-12,
            local_power_contract["interfaces"],
        )
        @test all(interface ->
            interface["requires_explicit_current_conversion"] &&
            interface["requires_explicit_power_conversion"],
            local_power_contract["interfaces"],
        )
    end

    @testset "n-winding delta_roll coil equations" begin
        net = parse_bmopf(raw"""
        {"bus":{
            "w1":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]},
            "w2":{"terminal_names":["a","b","c"]},
            "w3":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"source":{"bus":"w1",
             "terminal_map":["a","b","c"],
             "v_magnitude":[6350.0,6350.0,6350.0],
             "v_angle":[0.29670597283903605,-1.7976891295541593,2.3911010752322315]}},
         "transformer":{"n_winding":{"nw":{"s_rating":500000.0,
             "windings":[
               {"bus":"w1","terminal_map":["a","b","c","n"],
                "v_nom":6350.0,"configuration":"WYE","r_winding":0.0},
               {"bus":"w2","terminal_map":["a","b","c"],
                "v_nom":415.0,"configuration":"DELTA","delta_roll":-1,"r_winding":0.0},
               {"bus":"w3","terminal_map":["a","b","c","n"],
                "v_nom":230.0,"configuration":"WYE","r_winding":0.0}],
             "x_sc":{"1_2":0.0,"1_3":0.0,"2_3":0.0}}}}}
        """; from_string=true)
        context = build_opf_model(
            net; scaling_policy=OpfScaling(:si), add_objective=false,
        )
        w1 = [start_complex(context, "w1", phase) for phase in ("a", "b", "c")]
        w2 = [start_complex(context, "w2", phase) for phase in ("a", "b", "c")]
        w3 = [start_complex(context, "w3", phase) for phase in ("a", "b", "c")]
        n2 = 415.0 / 6350.0
        n3 = 230.0 / 6350.0
        for k in 1:3
            previous = mod1(k - 1, 3)
            @test w2[k] - w2[previous] ≈ n2 * w1[k] atol=1e-5
            @test w3[k] ≈ n3 * w1[k] atol=1e-5
        end

        # The same WYE/DELTA/WYE vector group must represent the identical
        # physical initialization when every winding uses a different power
        # base. Power bases affect current coordinates, never voltage phasors.
        local_context = build_opf_model(
            net;
            scaling_policy=OpfScaling(
                name=:n_winding_vector_group_local_power,
                voltage_bases=Dict(
                    "w1" => 6350.0, "w2" => 415.0, "w3" => 230.0,
                ),
                power_bases=Dict(
                    "w1" => 1.0e6, "w2" => 100.0e3, "w3" => 20.0e3,
                ),
            ),
            add_objective=false,
        )
        for bus in ("w1", "w2", "w3"), phase in ("a", "b", "c")
            @test start_physical(local_context, bus, phase) ≈
                  start_physical(context, bus, phase) atol=1e-5
        end
        evidence = BMOPFTools.opf_initialization_data(local_context)
        @test evidence["maximum_normalized_physics_residual"] < 1e-10
        @test evidence["equation_count_by_kind"]["n_winding_transformer"] == 6
    end
end
