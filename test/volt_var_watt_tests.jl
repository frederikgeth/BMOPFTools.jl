# Volt-var / Volt-watt droop tests.
#
# Included from runtests.jl when JuMP and Ipopt are in the load path.
#
# Coverage:
#   - the ReLU-sum encoding (breakpoints_to_triples + smooth/exact evaluation),
#     reproducing the canonical two-triple Volt-watt example;
#   - the OPF builder: a Volt-watt cap that curtails P at high voltage and a
#     Volt-var equality that drives Q onto the curve, each verified to bind to
#     the smooth curve value at the solved voltage;
#   - SI / per-unit invariance of the droop;
#   - THREE_LEG fall-back (warn, box bounds);
#   - integrity validation of the droop sub-objects and config-driven defaults.

# Reach into the extension module for the (JuMP-independent) encoding helpers.
const _OPFEXT = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

@testset "Volt-var / Volt-watt" begin

    # ─────────────────────────────────────────────────────────────────────────
    # Encoding: ReLU-sum reproduces the canonical Volt-watt characteristic
    # (100 % below 253 V dropping to 20 % at 260 V).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "encoding — breakpoints_to_triples" begin
        base, tr = _OPFEXT.breakpoints_to_triples([253.0, 260.0], [1.0, 0.2])
        @test base ≈ 1.0
        @test length(tr) == 2
        # Two triples: (−0.8/7, 253) and (+0.8/7, 260), matching the write-up.
        @test tr[1][1] ≈ -0.8/7   rtol=1e-9
        @test tr[1][2] == 253.0
        @test tr[2][1] ≈  0.8/7   rtol=1e-9
        @test tr[2][2] == 260.0

        # Exact (kinked) evaluation: flat clamps + the linear ramp between.
        @test _OPFEXT.curve_value_exact(base, tr, 250.0) ≈ 1.0
        @test _OPFEXT.curve_value_exact(base, tr, 253.0) ≈ 1.0
        @test _OPFEXT.curve_value_exact(base, tr, 256.5) ≈ 0.6   rtol=1e-9
        @test _OPFEXT.curve_value_exact(base, tr, 260.0) ≈ 0.2   rtol=1e-9
        @test _OPFEXT.curve_value_exact(base, tr, 265.0) ≈ 0.2

        # Strictly-increasing requirement.
        @test_throws ArgumentError _OPFEXT.breakpoints_to_triples([260.0, 253.0], [1.0, 0.2])
    end

    @testset "encoding — smooth → exact as ε → 0" begin
        base, tr = _OPFEXT.breakpoints_to_triples([207.0, 220.0, 240.0, 258.0],
                                                  [0.44, 0.0, 0.0, -0.60])
        for u in (210.0, 230.0, 250.0, 258.0)
            @test _OPFEXT.curve_value_smooth(base, tr, u, 1e-4) ≈
                  _OPFEXT.curve_value_exact(base, tr, u)   atol=2e-3
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Volt-watt: at a stiff high terminal voltage the active-power cap curtails
    # the inverter well below p_max, binding exactly to the smooth curve.
    # ─────────────────────────────────────────────────────────────────────────
    _volt_watt_net(vsrc) = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0],"v_max":[280.0]},
            "b1": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0],"v_max":[280.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[$(vsrc)],"v_angle":[0.0],"cost":[1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[100.0],"q_nom":[0.0]}},
         "control_profile":{"vw":{"volt_watt":{
             "voltage_reference":"PN_PER_PHASE",
             "breakpoints":[253.0,260.0],"p_limits":[0.20,1.00],
             "p_unit":"VA_FRACTION","p_ref":"S_MAX"}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","n"],
             "topology":"SINGLE_PHASE","prime_mover":"PV",
             "s_max":[3000.0],"p_max":[3000.0],"p_min":[0.0],
             "q_min":[0.0],"q_max":[0.0],
             "control_profile":"vw","cost":[0.1]}}}
        """; from_string=true)

    @testset "volt_watt — curtailment binds to curve" begin
        net = _volt_watt_net(260.0)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        vm  = res["bus"]["b1"]["1"]["vm"]
        pg  = res["inverter"]["pv1"]["1"]["pg"]

        # Reconstruct the cap the builder applies at the solved voltage.
        base, tr = _OPFEXT.breakpoints_to_triples([253.0, 260.0], [1.0, 0.2])
        ε   = 2e-3 * (253.0 + 260.0) / 2
        cap = 3000.0 * _OPFEXT.curve_value_smooth(base, tr, vm, ε)

        @test pg ≈ cap        atol = 5.0        # P binds to the curtailment cap
        @test pg < 0.4 * 3000.0                  # substantially curtailed
        @test vm > 253.0                         # droop region is active
    end

    @testset "volt_watt — SI / per-unit invariance" begin
        net = _volt_watt_net(260.0)
        pg_si = solve_opf(net; per_unit=false)["inverter"]["pv1"]["1"]["pg"]
        pg_pu = solve_opf(net; per_unit=true)["inverter"]["pv1"]["1"]["pg"]
        @test pg_si ≈ pg_pu   rtol = 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Volt-var: a resistive line decouples Q from voltage, so the terminal sits
    # at the (stiff) source voltage and Q is driven onto the curve.
    # ─────────────────────────────────────────────────────────────────────────
    _volt_var_net(vsrc) = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0],"v_max":[280.0]},
            "b1": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0],"v_max":[280.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[$(vsrc)],"v_angle":[0.0],"cost":[1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.02}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[200.0],"q_nom":[0.0]}},
         "control_profile":{"vv":{"volt_var":{
             "voltage_reference":"PN_PER_PHASE",
             "breakpoints":[207.0,220.0,240.0,258.0],"q_limits":[-0.60,0.44],
             "q_unit":"VA_FRACTION","q_ref":"VAR_MAX"}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","n"],
             "topology":"SINGLE_PHASE","prime_mover":"PV",
             "s_max":[3000.0],"p_max":[0.0],"p_min":[0.0],
             "control_profile":"vv","cost":[0.1]}}}
        """; from_string=true)

    @testset "volt_var — Q follows the droop curve (absorb at high V)" begin
        # per_unit improves conditioning when active power is pinned to zero.
        net = _volt_var_net(258.0)
        res = solve_opf(net; per_unit=true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        vm = res["bus"]["b1"]["1"]["vm"]
        qg = res["inverter"]["pv1"]["1"]["qg"]

        base, tr = _OPFEXT.breakpoints_to_triples([207.0, 220.0, 240.0, 258.0],
                                                  [0.44, 0.0, 0.0, -0.60])
        ε  = 2e-3 * (207.0 + 220.0 + 240.0 + 258.0) / 4
        q_expected = 3000.0 * _OPFEXT.curve_value_smooth(base, tr, vm, ε)

        @test qg ≈ q_expected   atol = 5.0       # Q binds to the curve
        @test qg < -1000.0                       # absorbing near V4
    end

    @testset "volt_var — deadband gives ≈ 0 reactive power" begin
        net = _volt_var_net(230.0)               # between V2=220 and V3=240
        res = solve_opf(net; per_unit=true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test abs(res["inverter"]["pv1"]["1"]["qg"]) < 30.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # FOUR_LEG voltage_ref: PER_PHASE feeds each phase its own magnitude;
    # AVERAGE feeds every phase the mean of the phase magnitudes. An unbalanced
    # source puts the three phases at different voltages, so the two modes are
    # distinguishable: PER_PHASE gives three different Q values, AVERAGE gives
    # the same Q on all phases (equal s_max ⇒ equal droop base).
    # ─────────────────────────────────────────────────────────────────────────
    _volt_var_4leg_net(vref) = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0,200.0,200.0],"v_max":[280.0,280.0,280.0]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[200.0,200.0,200.0],"v_max":[280.0,280.0,280.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[243.0,250.0,257.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.02,"R_series_2_2":0.02,"R_series_3_3":0.02}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE","p_nom":[200.0,200.0,200.0],"q_nom":[0.0,0.0,0.0]}},
         "control_profile":{"vv":{"volt_var":{
             "voltage_reference":"PN_PER_PHASE",
             "breakpoints":[207.0,220.0,240.0,258.0],"q_limits":[-0.60,0.44],
             "q_unit":"VA_FRACTION","q_ref":"VAR_MAX"}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"PV","voltage_ref":"$(vref)",
             "s_max":[3000.0,3000.0,3000.0],"p_max":[0.0,0.0,0.0],"p_min":[0.0,0.0,0.0],
             "control_profile":"vv","cost":[0.1,0.1,0.1]}}}
        """; from_string=true)

    _vv_curve_si(u) = begin
        base, tr = _OPFEXT.breakpoints_to_triples([207.0, 220.0, 240.0, 258.0],
                                                  [0.44, 0.0, 0.0, -0.60])
        ε = 2e-3 * (207.0 + 220.0 + 240.0 + 258.0) / 4
        3000.0 * _OPFEXT.curve_value_smooth(base, tr, u, ε)
    end

    @testset "voltage_ref=PER_PHASE — each phase sees its own magnitude" begin
        res = solve_opf(_volt_var_4leg_net("PER_PHASE"); per_unit=true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        invr = res["inverter"]["pv1"]
        for ph in ("1", "2", "3")
            vm = res["bus"]["b1"][ph]["vm"]
            @test invr[ph]["qg"] ≈ _vv_curve_si(vm)   atol = 10.0
        end
        # Unbalanced voltages ⇒ the per-phase Q values genuinely differ.
        qs = [invr[ph]["qg"] for ph in ("1", "2", "3")]
        @test maximum(qs) - minimum(qs) > 100.0
    end

    @testset "voltage_ref=AVERAGE — all phases see the mean magnitude" begin
        res = solve_opf(_volt_var_4leg_net("AVERAGE"); per_unit=true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        invr = res["inverter"]["pv1"]
        u_avg = sum(res["bus"]["b1"][ph]["vm"] for ph in ("1", "2", "3")) / 3
        q_expected = _vv_curve_si(u_avg)
        for ph in ("1", "2", "3")
            @test invr[ph]["qg"] ≈ q_expected   atol = 10.0
        end
        # Equal droop base + shared reference ⇒ equal Q across phases.
        qs = [invr[ph]["qg"] for ph in ("1", "2", "3")]
        @test maximum(qs) - minimum(qs) < 10.0
    end

    @testset "voltage_ref=AVERAGE on SINGLE_PHASE — warns, no effect" begin
        net = _volt_var_net(258.0)
        net["inverter"]["pv1"]["voltage_ref"] = "AVERAGE"
        res = @test_logs (:warn,) match_mode=:any solve_opf(net; per_unit=true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # Behaviour identical to PER_PHASE: Q still binds to the curve.
        vm = res["bus"]["b1"]["1"]["vm"]
        @test res["inverter"]["pv1"]["1"]["qg"] ≈ _vv_curve_si(vm)   atol = 10.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # THREE_LEG: droop unsupported — warns and falls back to box bounds.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "THREE_LEG — droop ignored with warning" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3"],
                   "v_min":[390.0,390.0,390.0],"v_max":[460.0,460.0,460.0]},
            "b1": {"terminal_names":["1","2","3"],
                   "v_min":[390.0,390.0,390.0],"v_max":[460.0,460.0,460.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[400.0,400.0,400.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"R_series_2_2":0.01,"R_series_3_3":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3"],
             "configuration":"DELTA",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}},
         "control_profile":{"vv":{"volt_var":{
             "voltage_reference":"PN_PER_PHASE",
             "breakpoints":[207.0,220.0,240.0,258.0],"q_limits":[-0.60,0.44],
             "q_unit":"VA_FRACTION","q_ref":"VAR_MAX"}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","2","3"],
             "topology":"THREE_LEG","prime_mover":"PV",
             "s_max":[3000.0,3000.0,3000.0],
             "p_max":[2000.0,2000.0,2000.0],"p_min":[0.0,0.0,0.0],
             "q_min":[-1000.0,-1000.0,-1000.0],"q_max":[1000.0,1000.0,1000.0],
             "control_profile":"vv","cost":[0.1,0.1,0.1]}}}
        """; from_string=true)

        res = @test_logs (:warn,) match_mode=:any solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Validation: droop sub-object integrity checks.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "validation — integrity checks" begin
        conflict = parse_bmopf("""
        {"bus":{"b":{"terminal_names":["1","n"]}},
         "control_profile":{"cp":{"power_factor":{"pf":0.95},
             "volt_var":{"breakpoints":[207.0,220.0,240.0,258.0],
                         "q_limits":[-0.6,0.44],"q_unit":"VA_FRACTION","q_ref":"VAR_MAX"}}}}
        """; from_string=true)
        f = Finding[]
        BMOPFTools.integrity_check(conflict, f)
        @test any(x -> x.code == "E.INT.CONTROL_PROFILE_CONFLICT", f)

        badshape = parse_bmopf("""
        {"bus":{"b":{"terminal_names":["1","n"]}},
         "control_profile":{"cp":{
             "volt_var":{"breakpoints":[207.0,220.0,240.0],
                         "q_limits":[-0.6,0.44],"q_unit":"VA_FRACTION","q_ref":"VAR_MAX"}}}}
        """; from_string=true)
        f = Finding[]
        BMOPFTools.integrity_check(badshape, f)
        @test any(x -> x.code == "E.INT.VOLT_VAR_SHAPE", f)

        unsupported = parse_bmopf("""
        {"bus":{"b":{"terminal_names":["1","n"]}},
         "control_profile":{"cp":{
             "volt_var":{"breakpoints":[207.0,220.0,240.0,258.0],
                         "q_limits":[-0.6,0.44],"q_unit":"VA_FRACTION",
                         "q_ref":"VAR_AVAILABLE"}}}}
        """; from_string=true)
        f = Finding[]
        BMOPFTools.integrity_check(unsupported, f)
        @test any(x -> x.code == "E.INT.DROOP_UNSUPPORTED", f)

        bad_vref = parse_bmopf("""
        {"bus":{"b":{"terminal_names":["1","2","3","n"]}},
         "inverter":{"pv1":{"bus":"b","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"PV","voltage_ref":"MEDIAN",
             "s_max":[3000.0,3000.0,3000.0]}}}
        """; from_string=true)
        f = Finding[]
        BMOPFTools.integrity_check(bad_vref, f)
        @test any(x -> x.code == "E.INT.VOLTAGE_REF_INVALID", f)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Augmentation: config-driven regional defaults fill a blank sub-object.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "augmentation — Queensland defaults" begin
        cfg = deepcopy(BMOPFTools.load_config())
        cfg["augment"]["smart_inverter"]["enabled"] = true
        cfg["augment"]["smart_inverter"]["region"]  = "Aus_A"

        net = parse_bmopf("""
        {"bus":{"b":{"terminal_names":["1","n"]}},
         "control_profile":{"qld":{"volt_var":{},"volt_watt":{}}},
         "inverter":{"pv1":{"bus":"b","terminal_map":["1","n"],
             "topology":"SINGLE_PHASE","prime_mover":"PV","s_max":[3000.0],
             "control_profile":"qld"}}}
        """; from_string=true)

        net′, _ = augment_case(net; config=cfg, recipe=AugmentationRecipe(
            apply_v_bounds=false, apply_vpn_bounds=false, apply_vpp_bounds=false,
            apply_vneg_bounds=false, apply_thermal=false, apply_q_bounds=false,
            apply_slack_generator=false, apply_inverter=false))

        vv = net′["control_profile"]["qld"]["volt_var"]
        vw = net′["control_profile"]["qld"]["volt_watt"]
        @test vv["breakpoints"] == [207.0, 220.0, 240.0, 258.0]
        @test vv["q_limits"]    == [-0.60, 0.44]
        @test vw["breakpoints"] == [253.0, 260.0]
        @test vw["p_limits"]    == [0.20, 1.00]
    end

end  # @testset "Volt-var / Volt-watt"
