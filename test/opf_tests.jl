# OPF solver unit tests with analytically verifiable numerical results.
# Included from runtests.jl when JuMP and Ipopt are in the load path.
#
# Test design notes
# -----------------
# Each test uses a minimal self-consistent fixture where the expected solution
# can be derived analytically, and then asserts the solver matches to a tight
# numerical tolerance (atol ≤ 0.01 V on voltages, which is ~10 ppm at 1 kV).
#
# All fixtures use:
#   - v_min on load buses to exclude the low-voltage (non-physical) NLP solution
#   - diagonal or resistive-only linecodes to enable closed-form derivations
#   - grounded neutral where not under test

@testset "OPF — solve_opf extension" begin

    # ─────────────────────────────────────────────────────────────────────────
    # T1: Single-phase, purely resistive, no reactive power
    #
    # KVL + constant-power load gives:  V² - V_s·V + R·P = 0
    # High-voltage solution:  V = (V_s + √(V_s² - 4RP)) / 2
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T1: single-phase resistive — exact voltage" begin
        V_s = 1000.0;  R = 0.5;  P = 100_000.0
        V_exp = (V_s + sqrt(V_s^2 - 4*R*P)) / 2   # 500 + 200√5 ≈ 947.214 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_exp   atol=0.01
        @test abs(res["bus"]["bus1"]["1"]["vi"]) < 0.01  # imaginary ≈ 0
        @test res["objective"] ≈ 0.0   atol=1e-6         # no generator
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T2: Three-phase balanced with diagonal linecode
    #
    # Off-diagonal impedance is zero ⟹ each phase decouples to the same
    # single-phase problem as T1.  All phases must have the same |V| and
    # angles equal to the source angles (0°, −120°, +120°).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T2: 3-phase balanced, decoupled phases" begin
        V_s = 1000.0;  R = 0.5;  P = 100_000.0
        V_exp = (V_s + sqrt(V_s^2 - 4*R*P)) / 2   # ≈ 947.214 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0, 900.0, 900.0],"v_max":[999.0, 999.0, 999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[100000.0,100000.0,100000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        b = res["bus"]["bus1"]
        # Equal voltage magnitude on all three phases
        @test b["1"]["vm"] ≈ V_exp   atol=0.01
        @test b["2"]["vm"] ≈ V_exp   atol=0.01
        @test b["3"]["vm"] ≈ V_exp   atol=0.01
        # Phase angles match source (diagonal impedance → no inter-phase coupling)
        @test b["1"]["va"] ≈  0.0     atol=1e-4
        @test b["2"]["va"] ≈ -2.0944  atol=1e-3
        @test b["3"]["va"] ≈  2.0944  atol=1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T3: Forced generator dispatch — bus voltage rises as line current falls
    #
    # With generator fixed at Pg = P_gen, the source delivers P_net = P_load − P_gen.
    # The same quadratic gives:  V = (V_s + √(V_s² − 4R·P_net)) / 2
    # Objective = cost × P_gen (deterministic since Pg is fixed).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T3: forced generator dispatch — exact voltage and cost" begin
        V_s = 1000.0;  R = 0.5;  P_load = 100_000.0;  P_gen = 50_000.0
        P_net = P_load - P_gen
        V_exp = (V_s + sqrt(V_s^2 - 4*R*P_net)) / 2   # 500 + 150√10 ≈ 974.342 V
        cost  = 0.1

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[960.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1"],
             "configuration":"WYE",
             "p_min":[50000.0],"p_max":[50000.0],
             "q_min":[0.0],"q_max":[0.0],"cost":[0.1]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["bus1"]["1"]["vm"]          ≈ V_exp         atol=0.01
        @test res["generator"]["gen1"]["1"]["pg"]   ≈ P_gen         atol=1.0
        @test res["objective"]                      ≈ cost * P_gen  atol=0.1
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T4: Cost-optimal dispatch — negative unit cost drives output to p_max
    #
    # cost = −1 $/W → minimising the objective maximises Pg → each phase
    # should hit its p_max bound.  A near-zero-impedance line ensures the
    # voltage constraint does not interfere.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T4: cost-optimal dispatch — negative cost → p_max" begin
        P_max_ph = 50_000.0

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[990.0, 990.0, 990.0],"v_max":[1001.0, 1001.0, 1001.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":1.0e-4,"R_series_2_2":1.0e-4,"R_series_3_3":1.0e-4}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[150000.0,150000.0,150000.0],"q_nom":[0.0,0.0,0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_min":[0.0,0.0,0.0],"p_max":[50000.0,50000.0,50000.0],
             "q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],"cost":[-1.0,-1.0,-1.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        for ph in ("1","2","3")
            @test res["generator"]["gen1"][ph]["pg"] ≈ P_max_ph   atol=1.0
        end
        @test res["objective"] ≈ -3.0 * P_max_ph   atol=10.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T5: Power balance identity
    #
    # For any converged OPF:  P_source = P_load + P_line_loss
    # Verified using the KVL-derived source injection and line losses.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T5: power balance identity" begin
        V_s = 1000.0;  R = 0.5;  P_load = 100_000.0

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Source real power via the voltage-source slack current at sourcebus.
        # P_src = (vr_src - vr_n)·cr + (vi_src - vi_n)·ci
        # With grounded neutral: vr_n = vi_n = 0, vi_src = 0 (angle=0).
        # So P_src = vr_src · cr = V_s · cr.
        crg_src = res["voltage_source"]["vs"]["1"]["ps"] / V_s   # ps = V_s · cr
        P_src   = res["voltage_source"]["vs"]["1"]["ps"]

        # Line loss: P_loss = R · |I|² (no reactive component here)
        cr_fr  = res["line"]["l1"]["1"]["cr_fr"]
        ci_fr  = res["line"]["l1"]["1"]["ci_fr"]
        P_loss = R * (cr_fr^2 + ci_fr^2)

        @test P_src ≈ P_load + P_loss   atol=0.1   # within 0.1 W
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T6: Four-wire explicit neutral — floating neutral has non-zero voltage
    #
    # Unbalanced WYE loads drive a non-zero neutral current through the finite
    # neutral impedance (R_n = 0.2 Ω), displacing the neutral potential.
    # Approximate analysis gives |V_n| ≈ 8–10 V at bus1.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T6: four-wire floating neutral — non-zero neutral voltage" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","2","3","n"],
                         "v_min":[850.0, 850.0, 850.0],"v_max":[1050.0, 1050.0, 1050.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc4w":{
             "R_series_1_1":0.1,"R_series_2_2":0.1,
             "R_series_3_3":0.1,"R_series_4_4":0.2}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1","2","3","n"],
             "terminal_map_to":  ["1","2","3","n"],
             "linecode":"lc4w","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[50000.0,100000.0,80000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Neutral must float to a non-zero voltage (unbalanced currents through
        # a finite neutral resistance create a measurable voltage displacement).
        vm_n = res["bus"]["bus1"]["n"]["vm"]
        @test vm_n > 1.0   # analytical estimate: |V_n| ≈ R_n × |I_n| ≈ 8–10 V
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T7: Standalone shunt object — exact to-end voltage
    #
    # Single-phase Thevenin with shunt conductance G at the load bus:
    #   I_series = G · V_bus1,  KVL: V_s − V_bus1 = R · I_series
    #   → V_bus1 = V_s / (1 + R·G)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T7: standalone shunt — exact to-end voltage" begin
        V_s = 1000.0;  R = 0.01;  G = 1.0
        V_exp = V_s / (1 + R * G)   # 1000/1.01 ≈ 990.099 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "shunt":{"sh1":{"bus":"bus1","terminal_map":["1"],"G_1_1":1.0}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # V_bus1 = V_s / (1 + R·G): shunt draws I = G·V, creating a voltage drop
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_exp   atol=0.01
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T8: π-model line shunt — to-end voltage via linecode G_to field
    #
    # Same Thevenin formula with the to-end π-shunt conductance G_to in the
    # linecode (no load, no from-end shunt):
    #   → V_bus1 = V_s / (1 + R·G_to)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T8: π-model line shunt — exact to-end voltage" begin
        V_s = 1000.0;  R = 0.01;  G_to = 0.5
        V_exp = V_s / (1 + R * G_to)   # 1000/1.005 ≈ 995.025 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"G_to_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # V_bus1 = V_s / (1 + R·G_to): to-end π-shunt provides a return path
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_exp   atol=0.01
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T9: Total current limit includes from-end π-shunt contribution
    #
    # From-end conductance shunt G_fr draws I_sh = G_fr · V_s from the source
    # bus.  With no to-end load the series current is zero, so the total
    # from-end current = G_fr · V_s.  We verify:
    #   (a) The solver is feasible (i_max = 120 A > G_fr · V_s = 100 A)
    #   (b) The reported total from-end current cm_fr ≈ 100 A — i.e. it includes
    #       the π-shunt, even though the series component is ≈ 0 (no load)
    #   (c) That total equals G_fr · |V_fr| ≈ 100 A < i_max
    # The reported cr_fr/cm_fr are series + π-shunt, the same quantity the
    # thermal magnitude limit is enforced on.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T9: total current limit includes from-end π-shunt" begin
        V_s = 1000.0;  G_fr = 0.1   # shunt draws 100 A from source bus to ground
        I_sh_exp = G_fr * V_s        # = 100 A; series current ≈ 0 (no load)

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-4,"G_from_1_1":0.1,"i_max":[120.0]}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # Total from-end current = series (≈0) + from-end π-shunt (≈100 A)
        @test res["line"]["l1"]["1"]["cm_fr"] ≈ I_sh_exp   atol=1.0
        # The to-end carries no shunt and no series flow → ≈ 0 A
        @test res["line"]["l1"]["1"]["cm_to"] < 1.0
        # Cross-check against G_fr · |V_sourcebus|, within i_max = 120 A
        vr_src = res["bus"]["sourcebus"]["1"]["vr"]
        vi_src = res["bus"]["sourcebus"]["1"]["vi"]
        I_sh_computed = G_fr * sqrt(vr_src^2 + vi_src^2)
        @test I_sh_computed ≈ I_sh_exp   atol=1.0
        @test I_sh_computed < 120.0   # within the thermal limit
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T9b: shunt-carrying line WITH a phase-to-ground v_max array. This drives
    # the series-current box derivation through _terminal_vmax_to_ground, which
    # must read the per-phase v_max[k] entry (a scalar Float64(v_max) crashes on
    # the array). Regression for the per-phase v_min/v_max migration.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T9b: series-current box with per-phase v_max + line shunt" begin
        # The shunt-carrying line l2 has from-bus b1, which carries a per-phase
        # v_max array → _terminal_vmax_to_ground reads v_max[k] for b1's phase.
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "b1":       {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[1100.0]},
            "b2":       {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-4,"i_max":[120.0]},
                     "lcsh":{"R_series_1_1":1.0e-4,"G_from_1_1":0.1,"i_max":[120.0]}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"b1",
                       "terminal_map_from":["1"],"terminal_map_to":["1"],
                       "linecode":"lc","length":1.0},
                 "l2":{"bus_from":"b1","bus_to":"b2",
                       "terminal_map_from":["1"],"terminal_map_to":["1"],
                       "linecode":"lcsh","length":1.0}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["b1"]["1"]["vm"] ≤ 1100.0 + 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T10: Sequence voltage bounds — all three sequence components constrained
    #
    # Balanced 3-phase source at V_s=1000 V feeds a generator-only bus lb
    # through a diagonal resistive line (R=0.5 Ω/phase).
    # Generator cost = -1 (incentivises maximum output → drives V_lb above V_s).
    # Three simultaneous sequence bounds are tested:
    #   vpos_max  = 1050 V   → positive-sequence upper bound (binding)
    #   vneg_max  =    1 V   → negative-sequence near-zero (forces balance)
    #   vzero_max =    1 V   → zero-sequence near-zero (forces balance)
    #
    # Tight vneg_max and vzero_max force the solution to be balanced, so
    # V₁ = |V_phase| and the analytic result V_phase = vpos_max = 1050 V applies.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T10: sequence voltage bounds — positive/negative/zero sequence" begin
        V_s = 1000.0;  R = 0.5;  vpos_max = 1050.0

        net = parse_bmopf("""
        {"bus":{
            "sb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n",
                  "perfectly_grounded_terminals":["n"]},
            "lb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n",
                  "perfectly_grounded_terminals":["n"],
                  "v_min":[200.0, 200.0, 200.0],
                  "vpos_max":$(vpos_max),
                  "vneg_max":1.0,
                  "vzero_max":1.0}},
         "voltage_source":{"vs":{"bus":"sb","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_s),$(V_s),$(V_s)],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":$(R),"R_series_2_2":$(R),"R_series_3_3":$(R)}},
         "line":{"l1":{"bus_from":"sb","bus_to":"lb",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "generator":{"g":{"bus":"lb","configuration":"WYE",
             "terminal_map":["1","2","3","n"],
             "p_min":[0.0,0.0,0.0],"p_max":[200000.0,200000.0,200000.0],
             "q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],
             "cost":[-1.0,-1.0,-1.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        b = res["bus"]["lb"]
        s3 = sqrt(3.0) / 2.0

        # Terminal voltages (grounded neutral → phase-to-ground)
        vr1 = b["1"]["vr"]; vi1 = b["1"]["vi"]
        vr2 = b["2"]["vr"]; vi2 = b["2"]["vi"]
        vr3 = b["3"]["vr"]; vi3 = b["3"]["vi"]

        # Positive sequence: V₁ = (Va + α·Vb + α²·Vc) / 3
        V1r = (vr1 - 0.5*vr2 - s3*vi2 - 0.5*vr3 + s3*vi3) / 3
        V1i = (vi1 + s3*vr2 - 0.5*vi2 - s3*vr3 - 0.5*vi3) / 3
        V1  = sqrt(V1r^2 + V1i^2)

        # Negative sequence: V₂ = (Va + α²·Vb + α·Vc) / 3
        V2r = (vr1 - 0.5*vr2 + s3*vi2 - 0.5*vr3 - s3*vi3) / 3
        V2i = (vi1 - s3*vr2 - 0.5*vi2 + s3*vr3 - 0.5*vi3) / 3
        V2  = sqrt(V2r^2 + V2i^2)

        # Zero sequence: V₀ = (Va + Vb + Vc) / 3
        V0r = (vr1 + vr2 + vr3) / 3
        V0i = (vi1 + vi2 + vi3) / 3
        V0  = sqrt(V0r^2 + V0i^2)

        # vpos_max binding: generator drives V₁ to the positive-sequence bound
        @test V1 ≈ vpos_max   atol=5.0
        @test V1 <= vpos_max + 1.0
        # vneg_max=1, vzero_max=1 honored: sequence components within their bounds
        @test V2 < 2.0
        @test V0 < 2.0
        # Tight neg/zero bounds force balance: all phases at vpos_max magnitude
        @test b["1"]["vm"] ≈ vpos_max   atol=5.0
        @test b["2"]["vm"] ≈ vpos_max   atol=5.0
        @test b["3"]["vm"] ≈ vpos_max   atol=5.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Per-unit scaling tests
    #
    # T11: Base propagation — solve_opf(per_unit=true) returns SI results.
    #      The source bus voltage in the result must match the SI fixture value
    #      regardless of the internal PU representation.
    #
    # T12: SI == PU results — the same network solved with and without per_unit
    #      must produce numerically identical results (rtol=1e-4).
    #
    # T13: Net dict immutability — calling solve_opf with per_unit=true must
    #      not modify the original network dict.
    # ─────────────────────────────────────────────────────────────────────────

    # Shared fixture for T11–T13: T1 geometry with a profit-seeking DER at bus1
    # (negative cost) so the optimizer always dispatches at p_max, giving a
    # deterministic nonzero pg far from zero — avoids rtol failures on near-zero values.
    # The grid connection is covered by the voltage-source slack at sourcebus.
    # g1 injects 200 kW; load is 100 kW → net 100 kW exported to sourcebus.
    # V_bus1 rises above V_s (reverse current direction).
    # Analytical: V² − V_s·V − R·P_net = 0 → V = (V_s + √(V_s²+4·R·P_net))/2 ≈ 1047.7 V
    # cost = -0.05 $/W → objective = -0.05 × 200 000 = -10 000 $/s
    _pu_net() = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"]},
        "bus1":     {"terminal_names":["1","n"],
                     "perfectly_grounded_terminals":["n"],
                     "v_min":[900.0],"v_max":[1100.0]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.5}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
         "terminal_map_from":["1"],"terminal_map_to":["1"],
         "linecode":"lc","length":1.0}},
     "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE",
         "p_nom":[100000.0],"q_nom":[0.0]}},
     "generator":{"g1":{"bus":"bus1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE",
         "p_min":[0.0],"p_max":[200000.0],
         "q_min":[0.0],"q_max":[0.0],
         "cost":[-0.05]}}}
    """; from_string=true)

    @testset "T11: per_unit=true returns SI results" begin
        net = _pu_net()
        res = solve_opf(net; per_unit=true)

        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Source voltage is fixed at 1000 V; result must be in SI, not PU.
        @test res["bus"]["sourcebus"]["1"]["vm"] ≈ 1000.0   atol=0.1

        # Load bus voltage: g1 exports P_net = 200kW − 100kW = 100kW to sourcebus.
        # Reverse current → V_bus1 > V_s. Quadratic: V² − V_s·V − R·P_net = 0.
        V_s = 1000.0; R = 0.5; P_net = 100_000.0
        V_exp = (V_s + sqrt(V_s^2 + 4*R*P_net)) / 2   # ≈ 1047.7 V
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_exp   atol=0.5

        # Profit-seeking generator (cost=-0.05 $/W) binds at p_max=200 000 W.
        # objective = -0.05 × 200 000 = -10 000; pg in W, not PU.
        @test res["objective"] ≈ -10_000.0   rtol=1e-3
        @test res["generator"]["g1"]["1"]["pg"] ≈ 200_000.0   rtol=1e-3
    end

    @testset "T12: per_unit=true and per_unit=false agree" begin
        net    = _pu_net()
        r_si   = solve_opf(net)
        r_pu   = solve_opf(net; per_unit=true)

        @test r_si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test r_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Voltages at source and load bus must match to tight tolerance.
        for bus in ("sourcebus", "bus1")
            vm_si = r_si["bus"][bus]["1"]["vm"]
            vm_pu = r_pu["bus"][bus]["1"]["vm"]
            @test isapprox(vm_si, vm_pu; rtol=1e-4)

            va_si = r_si["bus"][bus]["1"]["va"]
            va_pu = r_pu["bus"][bus]["1"]["va"]
            @test isapprox(va_si, va_pu; atol=1e-6)
        end

        # Objective (in W·$/W = SI) must match; both should be ≈ -10 000.
        @test isapprox(r_si["objective"], r_pu["objective"]; rtol=1e-3)

        # Line current magnitude at from-end must match.
        cm_si = r_si["line"]["l1"]["1"]["cm_fr"]
        cm_pu = r_pu["line"]["l1"]["1"]["cm_fr"]
        @test isapprox(cm_si, cm_pu; rtol=1e-3)

        # Generator output (in W) must match; both should be ≈ 200 000 W.
        pg_si = r_si["generator"]["g1"]["1"]["pg"]
        pg_pu = r_pu["generator"]["g1"]["1"]["pg"]
        @test isapprox(pg_si, pg_pu; rtol=1e-3)
    end

    @testset "T13: per_unit=true does not mutate net" begin
        net = _pu_net()

        # Snapshot SI values before the solve.
        v_min_before  = net["bus"]["bus1"]["v_min"]
        vmag_before   = net["voltage_source"]["vs"]["v_magnitude"][1]
        pnom_before   = net["load"]["ld1"]["p_nom"][1]
        r_before      = net["linecode"]["lc"]["R_series_1_1"]

        solve_opf(net; per_unit=true)

        @test net["bus"]["bus1"]["v_min"]                      == v_min_before
        @test net["voltage_source"]["vs"]["v_magnitude"][1]    == vmag_before
        @test net["load"]["ld1"]["p_nom"][1]                   == pnom_before
        @test net["linecode"]["lc"]["R_series_1_1"]            == r_before
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T13b: per-unit ⇄ SI agreement for EVERY transformer subtype.
    #
    # The dedicated per_unit tests above use a transformer-free network, so the
    # transformer p.u. scaling went unexercised. Solving the same net with
    # per_unit=true and per_unit=false must agree on bus voltages and total
    # losses. The no-load (core-loss) shunt is the discriminating case: g/b_no_load
    # is an ADMITTANCE, so it scales ×z_base (reciprocal of the impedance rule) —
    # before the fix it was omitted from _pu_scale_transformers! and the core loss
    # silently vanished in p.u. mode. wye_delta / delta_wye / single_phase / center_tap
    # carry a no-load shunt to exercise that path on wye-from and delta-from windings.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T13b: per_unit ⇄ SI agreement across transformer subtypes" begin
        function _pu_si_agree(solver, net; label="")
            @testset "$label" begin
                r_si = solver(net; per_unit=false)
                r_pu = solver(net; per_unit=true, s_base=1e6)
                @test r_si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                @test r_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                for (bid, td) in r_si["bus"], (t, tv) in td
                    @test isapprox(r_pu["bus"][bid][t]["vm"], tv["vm"]; rtol=1e-3, atol=1e-2)
                end
                ls_si = get(r_si, "losses", Dict()); ls_pu = get(r_pu, "losses", Dict())
                @test isapprox(get(ls_pu, "p_loss", 0.0), get(ls_si, "p_loss", 0.0); rtol=2e-3, atol=1.0)
                @test isapprox(get(ls_pu, "q_loss", 0.0), get(ls_si, "q_loss", 0.0); rtol=2e-3, atol=1.0)
            end
        end

        # single_phase (1φ YY) with a no-load shunt
        _pu_si_agree(solve_feasibility_opf, parse_bmopf("""
        {"bus":{"hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"hv","terminal_map":["1","n"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase":{"t1":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "v_ref_from":2400.0,"v_ref_to":240.0,"s_rating":50000.0,
             "r_series_from":0.1,"x_series_from":0.2,"r_series_to":0.001,"x_series_to":0.002,
             "g_no_load":2e-5,"b_no_load":8e-5}}},
         "load":{"ld":{"bus":"lv","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
             "p_nom":[20000.0],"q_nom":[5000.0]}}}
        """; from_string=true); label="single_phase")

        # wye_delta (HV wye / LV delta) with a no-load shunt on the wye from-side.
        # The delta secondary common mode is anchored by a near-solid grounding
        # shunt at lv.1 (as in the OpenDSS PF-comparison fixture).
        _pu_si_agree(solve_feasibility_opf, parse_bmopf("""
        {"bus":{"hv":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","2","3"]}},
         "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
             "v_magnitude":[6350.0,6350.0,6350.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "shunt":{"grnd_lv":{"bus":"lv","terminal_map":["1"],"G_1_1":1000.0,"B_1_1":0.0}},
         "transformer":{"wye_delta":{"t1":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3"],
             "v_ref_from":11000.0,"v_ref_to":415.0,"s_rating":500000.0,
             "r_series_from":2.42,"r_series_to":0.0034,"x_series_from":4.84,"x_series_to":0.0069,
             "g_no_load":1e-4,"b_no_load":2e-4}}},
         "load":{"ld":{"bus":"lv","terminal_map":["1","2"],"configuration":"DELTA",
             "p_nom":[100000.0],"q_nom":[30000.0]}}}
        """; from_string=true); label="wye_delta")

        # delta_wye (HV delta / LV wye) with a no-load shunt on the delta from-side
        _pu_si_agree(solve_feasibility_opf, parse_bmopf("""
        {"bus":{"hv":{"terminal_names":["1","2","3"]},
                "lv":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
             "v_magnitude":[6350.0,6350.0,6350.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"delta_wye":{"t1":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3","n"],
             "v_ref_from":11000.0,"v_ref_to":415.0,"s_rating":500000.0,
             "r_series_from":2.42,"r_series_to":0.0034,"x_series_from":4.84,"x_series_to":0.0069,
             "g_no_load":1e-4,"b_no_load":2e-4}}},
         "load":{"ld1":{"bus":"lv","terminal_map":["1","n"],"configuration":"WYE","p_nom":[80000.0],"q_nom":[20000.0]},
                 "ld2":{"bus":"lv","terminal_map":["2","n"],"configuration":"WYE","p_nom":[80000.0],"q_nom":[20000.0]},
                 "ld3":{"bus":"lv","terminal_map":["3","n"],"configuration":"WYE","p_nom":[80000.0],"q_nom":[20000.0]}}}
        """; from_string=true); label="delta_wye")

        # center_tap (split-phase) with a no-load shunt
        _pu_si_agree(solve_feasibility_opf, parse_bmopf("""
        {"bus":{"mv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","2","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"src":{"bus":"mv","terminal_map":["1"],"v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
             "v_ref_from":2400.0,"v_ref_to":120.0,"s_rating":25000.0,
             "r_series_from":0.1,"x_series_from":0.4,"r_series_to":0.001,"x_series_to":0.004,
             "g_no_load":2e-5,"b_no_load":8e-5}}},
         "load":{"l1":{"bus":"lv","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]},
                 "l2":{"bus":"lv","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]}}}
        """; from_string=true); label="center_tap")

        # single_phase_autotransformer (step regulator) — lossy, no core shunt
        _pu_si_agree(solve_feasibility_opf, parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "reg":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase_autotransformer":{"r1":{"bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.05,"regulator_type":"B","s_rating":500000.0,
             "r_series_from":0.5,"x_series_from":0.0}}},
         "load":{"ld":{"bus":"reg","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
             "p_nom":[50000.0],"q_nom":[0.0]}}}
        """; from_string=true); label="single_phase_autotransformer")

        # open_delta_regulator — lossless ratio regulator, no core shunt
        _pu_si_agree(solve_pf, parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "reg":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[2400.0,2400.0,2400.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"open_delta_regulator":{"od":{"bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "connection":"ABBC","tap_ratio":[1.05,1.025],"regulator_type":"B","s_rating":500000.0}}}}
        """; from_string=true); label="open_delta_regulator")
    end

    @testset "T13c: perfectly-grounded delta-secondary phase warm-starts cleanly" begin
        # Regression for a crash in _set_yd_dy_start_values!: when a delta-secondary
        # phase is `perfectly_grounded`, that terminal becomes the warm-start anchor
        # but is fixed to 0 with no start value, so reading it via JuMP.start_value
        # returned `nothing` → complex(nothing, nothing) MethodError. The anchor read
        # now treats a grounded terminal as 0. (Distinct from the grounded-wye-neutral
        # case; mode-independent — exercised here in SI mode.)
        net = parse_bmopf("""
        {"bus":{"hv":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","2","3"],"perfectly_grounded_terminals":["1"]}},
         "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
             "v_magnitude":[6350.0,6350.0,6350.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"wye_delta":{"t1":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3"],
             "v_ref_from":11000.0,"v_ref_to":415.0,"s_rating":500000.0,
             "r_series_from":2.42,"r_series_to":0.0034,"x_series_from":4.84,"x_series_to":0.0069,
             "g_no_load":1e-4,"b_no_load":2e-4}}},
         "load":{"ld":{"bus":"lv","terminal_map":["1","2"],"configuration":"DELTA",
             "p_nom":[100000.0],"q_nom":[30000.0]}}}
        """; from_string=true)
        res = solve_feasibility_opf(net)                       # must not throw
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["lv"]["1"]["vm"] < 1e-6               # grounded delta phase pinned to 0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T14: Result dictionary structure contract
    #
    # Pins the shape of every section of the result dict so that refactoring
    # the extraction code cannot silently rename or drop fields.
    #
    # Fixture: single-phase, two buses, one line, one closed switch in series
    # with the line (sourcebus→switchbus→bus1), one load, one generator, one
    # voltage source.  All components appear in the result dict.
    #
    # sourcebus --[l1]--> switchbus --[sw1]--> bus1
    #                                           ├── ld1 (load)
    #                                           └── gen1 (generator)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T14: result dict structure contract" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "switchbus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "bus1":      {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"],
                          "v_min":[800.0],"v_max":[1050.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"switchbus",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "switch":{"sw1":{"bus_from":"switchbus","bus_to":"bus1",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "open_switch":false}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[50000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_min":[10000.0],"p_max":[10000.0],
             "q_min":[0.0],"q_max":[0.0],
             "cost":[0.01]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # ── top-level keys ────────────────────────────────────────────────────
        for k in ("termination_status","objective","solve_time",
                  "bus","line","switch","load","generator","transformer",
                  "voltage_source")
            @test haskey(res, k)
        end

        # ── bus: terminal-keyed, four fields per terminal ─────────────────────
        for (bus_id, expected_terminals) in (
                "sourcebus" => ["1","n"],
                "switchbus" => ["1","n"],
                "bus1"      => ["1","n"])
            @test haskey(res["bus"], bus_id)
            for t in expected_terminals
                @test haskey(res["bus"][bus_id], t)
                td = res["bus"][bus_id][t]
                for f in ("vr","vi","vm","va")
                    @test haskey(td, f)
                    @test td[f] isa Float64
                end
                @test td["vm"] >= 0.0
                @test td["vm"] ≈ sqrt(td["vr"]^2 + td["vi"]^2)   atol=1e-9
                @test td["va"] ≈ atan(td["vi"], td["vr"])          atol=1e-9
            end
        end

        # ── line: terminal-name keys (not positional integers) ────────────────
        @test haskey(res["line"], "l1")
        # conductor "1" from terminal_map_from=["1"]
        @test haskey(res["line"]["l1"], "1")
        @test !haskey(res["line"]["l1"], 1)   # must be String key, not Int
        ld = res["line"]["l1"]["1"]
        for f in ("cr_fr","ci_fr","cr_to","ci_to","cm_fr","cm_to")
            @test haskey(ld, f)
            @test ld[f] isa Float64
        end
        @test ld["cm_fr"] >= 0.0
        @test ld["cm_to"] >= 0.0
        @test ld["cm_fr"] ≈ sqrt(ld["cr_fr"]^2 + ld["ci_fr"]^2)  atol=1e-9
        @test ld["cm_to"] ≈ sqrt(ld["cr_to"]^2 + ld["ci_to"]^2)  atol=1e-9

        # ── switch: terminal-name keys, three fields ──────────────────────────
        @test haskey(res["switch"], "sw1")
        # terminal_map_from = ["1","n"] → keys "1" and "n"
        for t in ("1","n")
            @test haskey(res["switch"]["sw1"], t)
            sd = res["switch"]["sw1"][t]
            for f in ("cr","ci","cm")
                @test haskey(sd, f)
                @test sd[f] isa Float64
            end
            @test sd["cm"] >= 0.0
            @test sd["cm"] ≈ sqrt(sd["cr"]^2 + sd["ci"]^2)  atol=1e-9
        end

        # ── load: phase-terminal keys only (neutral absent) ───────────────────
        @test haskey(res["load"], "ld1")
        # terminal_map = ["1","n"], SINGLE_PHASE → phase terminal "1" only
        @test haskey(res["load"]["ld1"], "1")
        @test !haskey(res["load"]["ld1"], "n")  # neutral carries no current variable
        ldd = res["load"]["ld1"]["1"]
        for f in ("crd","cid","pd","qd")
            @test haskey(ldd, f)
            @test ldd[f] isa Float64
        end
        # constant-power constraints must hold: pd ≈ p_nom, qd ≈ q_nom
        @test ldd["pd"] ≈ 50_000.0   atol=1.0
        @test ldd["qd"] ≈      0.0   atol=1.0

        # ── generator: phase-terminal keys only (neutral absent) ─────────────
        @test haskey(res["generator"], "gen1")
        @test haskey(res["generator"]["gen1"], "1")
        @test !haskey(res["generator"]["gen1"], "n")
        gd = res["generator"]["gen1"]["1"]
        for f in ("crg","cig","pg","qg")
            @test haskey(gd, f)
            @test gd[f] isa Float64
        end
        @test gd["pg"] ≈ 10_000.0   atol=1.0   # fixed p_min == p_max

        # ── transformer: empty dict (no transformers in this fixture) ─────────
        @test res["transformer"] isa Dict
        @test isempty(res["transformer"])

        # ── voltage_source: phase-terminal keys, slack current + power ─────────
        @test haskey(res["voltage_source"], "vs")
        @test haskey(res["voltage_source"]["vs"], "1")   # phase terminal only
        @test !haskey(res["voltage_source"]["vs"], "n")  # neutral carries return current, no var
        sd = res["voltage_source"]["vs"]["1"]
        for f in ("cr","ci","cm","ps","qs")
            @test haskey(sd, f)
            @test sd[f] isa Float64
        end
        @test sd["cm"] >= 0.0
        @test sd["cm"] ≈ sqrt(sd["cr"]^2 + sd["ci"]^2)  atol=1e-9
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T15: Switch current limit
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T15: switch i_max enforced" begin
        # Same topology as T14 but with a tight i_max on the switch.
        # The load demands 50 W through a 1000 V source → ~0.05 A.
        # Setting i_max=[0.03] makes the limit binding and forces the solver
        # to shed load via the generator or go infeasible; here the generator
        # is unconstrained so we just verify the switch current is ≤ i_max.
        net = parse_bmopf("""
        {"bus":{
            "sourcebus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "switchbus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "bus1":      {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"switchbus",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "switch":{"sw1":{"bus_from":"switchbus","bus_to":"bus1",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "open_switch":false,"i_max":[0.03]}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[50000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "cost":[0.01]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        cm = res["switch"]["sw1"]["1"]["cm"]
        @test cm <= 0.03 + 1e-6
    end

    @testset "T15b: switch without i_max is unconstrained" begin
        # Identical to T15 but no i_max field — the solve must still complete
        # and the switch current is not clipped.
        net = parse_bmopf("""
        {"bus":{
            "sourcebus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "switchbus": {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]},
            "bus1":      {"terminal_names":["1","n"],
                          "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"switchbus",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "switch":{"sw1":{"bus_from":"switchbus","bus_to":"bus1",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "open_switch":false}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[50000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "cost":[0.01]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # current flows freely — no artificial clip
        @test res["switch"]["sw1"]["1"]["cm"] > 0.03
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Initialisation block
    # ─────────────────────────────────────────────────────────────────────────
    @testset "Initialisation block — structure and values" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"],
                   "v_min":[900.0, 900.0, 900.0],"v_max":[1100.0, 1100.0, 1100.0]}},
         "voltage_source":{"vs":{"bus":"src",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[10000.0,10000.0,10000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # "initialisation" key always present
        @test haskey(res, "initialisation")
        init = res["initialisation"]
        @test init isa Dict

        # Every bus and terminal in the solved result has a matching init entry
        for (bid, t_dict) in res["bus"]
            @test haskey(init, bid)
            for (t, _) in t_dict
                @test haskey(init[bid], t)
            end
        end

        # Each init entry has all four fields
        for (bid, t_dict) in init
            for (t, ivals) in t_dict
                @test haskey(ivals, "vr_init")
                @test haskey(ivals, "vi_init")
                @test haskey(ivals, "vm_init")
                @test haskey(ivals, "va_init")
                @test ivals["vm_init"] ≈ sqrt(ivals["vr_init"]^2 + ivals["vi_init"]^2)
            end
        end

        # Grounded neutral terminal init is exactly zero
        @test init["src"]["n"]["vm_init"] == 0.0
        @test init["b1"]["n"]["vm_init"]  == 0.0

        # Phase terminals initialised at the source v_magnitude (1000 V)
        @test init["src"]["1"]["vm_init"] ≈ 1000.0   atol=1e-6
        @test init["b1"]["1"]["vm_init"]  ≈ 1000.0   atol=1e-6

        # per_unit=true: init values are returned in SI (same V_base rescaling as "bus")
        res_pu = solve_opf(net; per_unit=true)
        @test haskey(res_pu, "initialisation")
        # SI values match within floating point
        @test res_pu["initialisation"]["src"]["1"]["vm_init"] ≈
              res["initialisation"]["src"]["1"]["vm_init"]   rtol=1e-4
    end

    @testset "Initialisation profiling — level mismatch flagged" begin
        # Build a two-voltage-level network (MV source → LV load via transformer).
        # _set_voltage_start_values! uses source vm (6350 V) for all buses, so
        # LV buses (~230 V solved) will have vm_init ≈ 6350 V → ratio >> 10×.
        net = parse_bmopf("""
        {"bus":{
            "hv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"],
                  "v_min":[5500.0, 5500.0, 5500.0],"v_max":[7000.0, 7000.0, 7000.0]},
            "lv":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"],
                  "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]}},
         "voltage_source":{"vs":{"bus":"hv",
             "terminal_map":["a","b","c"],
             "v_magnitude":[6350.0,6350.0,6350.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "transformer":{"single_phase":{"tx":{"bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["a","b","c"],
             "terminal_map_to":["a","b","c"],
             "s_rating":100000.0,
             "v_ref_from":11000.0,"v_ref_to":400.0,
             "r_series_from":0.01,"r_series_to":0.0001,
             "x_series_from":0.05,"x_series_to":0.0005}}},
         "load":{"ld":{"bus":"lv","terminal_map":["a","b","c","n"],
             "configuration":"WYE",
             "p_nom":[5000.0,5000.0,5000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res    = solve_opf(net)
        report = profile_solution(net, res)

        @test haskey(res, "initialisation")
        # LV bus solved voltage should be ~230 V, init was ~6350 V → level mismatch
        vm_lv_sol  = res["bus"]["lv"]["a"]["vm"]
        vm_lv_init = res["initialisation"]["lv"]["a"]["vm_init"]
        @test vm_lv_init / vm_lv_sol > 10.0

        @test any(f -> f.code == "W.SOL.INIT_LEVEL_MISMATCH", report.findings)
        # HV bus (same level as source) should NOT trigger the mismatch
        vm_hv_sol  = res["bus"]["hv"]["a"]["vm"]
        vm_hv_init = res["initialisation"]["hv"]["a"]["vm_init"]
        @test 0.1 < vm_hv_init / vm_hv_sol < 10.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T15: Voltage-dependent load models (ZIP / exponential)
    #
    # Single-phase resistive feeder (as T1).  With a voltage-dependent load the
    # KVL fixed point has closed forms:
    #   pure-Z (γ=2):  P=Pnom·(V/Vnom)²  ⟹  V = Vs / (1 + R·Pnom/Vnom²)
    #   pure-I (γ=1):  P=Pnom·(V/Vnom)   ⟹  V = Vs − R·Pnom/Vnom
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T15: voltage-dependent load models" begin
        V_s = 1000.0;  R = 0.5;  Pnom = 100_000.0;  Vnom = 1000.0
        k = R * Pnom / Vnom^2          # 0.05

        mkload(extra) = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[850.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]$extra}}}
        """; from_string=true)

        # ── pure constant-impedance via ZIP (αZ=βZ=1) ────────────────────────
        V_z = V_s / (1 + k)            # 952.381 V
        res = solve_opf(mkload(""","model":"zip","v_nom":[1000.0],
            "alpha_z":[1.0],"alpha_i":[0.0],"alpha_p":[0.0],
            "beta_z":[1.0],"beta_i":[0.0],"beta_p":[0.0]"""))
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_z   atol=0.01
        @test res["load"]["ld1"]["1"]["pd"] ≈ Pnom*(V_z/Vnom)^2   rtol=1e-4

        # ── pure constant-current via ZIP (αI=βI=1) ──────────────────────────
        V_i = V_s - R*Pnom/Vnom        # 950.0 V
        res = solve_opf(mkload(""","model":"zip","v_nom":[1000.0],
            "alpha_z":[0.0],"alpha_i":[1.0],"alpha_p":[0.0],
            "beta_z":[0.0],"beta_i":[1.0],"beta_p":[0.0]"""))
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_i   atol=0.01
        @test res["load"]["ld1"]["1"]["pd"] ≈ Pnom*(V_i/Vnom)   rtol=1e-4

        # ── exponential γ=2 must match pure-Z (integer-exponent routing) ─────
        res = solve_opf(mkload(""","model":"exponential","v_nom":[1000.0],
            "gamma_p":[2.0],"gamma_q":[2.0]"""))
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_z   atol=0.01

        # ── exponential γ=1 must match pure-I ────────────────────────────────
        res = solve_opf(mkload(""","model":"exponential","v_nom":[1000.0],
            "gamma_p":[1.0],"gamma_q":[1.0]"""))
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_i   atol=0.01

        # ── non-integer exponential (γ=1.5): self-consistent fixed point ─────
        res = solve_opf(mkload(""","model":"exponential","v_nom":[1000.0],
            "gamma_p":[1.5],"gamma_q":[1.5]"""))
        V = res["bus"]["bus1"]["1"]["vm"];  pd = res["load"]["ld1"]["1"]["pd"]
        @test pd ≈ Pnom*(V/Vnom)^1.5                     rtol=1e-4
        @test V  ≈ (V_s + sqrt(V_s^2 - 4*R*pd))/2        atol=0.01
        @test V_i < V < V_z   # between the γ=1 and γ=2 fixed points

        # ── ZIP with αP=βP=1 recovers constant power (T1 value) ──────────────
        V_cp = (V_s + sqrt(V_s^2 - 4*R*Pnom))/2          # ≈ 947.214 V
        res = solve_opf(mkload(""","model":"zip","v_nom":[1000.0],
            "alpha_z":[0.0],"alpha_i":[0.0],"alpha_p":[1.0],
            "beta_z":[0.0],"beta_i":[0.0],"beta_p":[1.0]"""))
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_cp   atol=0.01
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV1: Single-phase FOUR_LEG inverter — unconstrained Q (box bounds)
    #
    # A PV inverter sits at bus1 alongside a load. The inverter has p_max on
    # each phase so the augmentation pass fills in q_min/q_max at cos φ = 0.90.
    # The OPF minimises slack cost so it maximises the (cheaper) inverter
    # dispatch. All three phases are symmetric → each phase decouples.
    #
    # With p_max = 3000 W/phase, p_nom_load = 2000 W/phase and the inverter
    # cost < slack cost, the OPF should dispatch the inverter at p_avail and
    # let it offset the load.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-SP: split-phase center-tap init angles are anti-phase" begin
        # The two LV legs of a center-tap (split-phase) secondary must be warm-
        # started 180° apart, not the canonical −120°.
        net = parse_bmopf("""
        {"bus":{
            "mv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lv":{"terminal_names":["1","2","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"src":{"bus":"mv","terminal_map":["1"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
             "v_ref_from":2400.0,"v_ref_to":120.0,"s_rating":25000.0,
             "r_series_from":0.1,"x_series_from":0.4,
             "r_series_to":0.001,"x_series_to":0.004}}},
         "load":{
             "l1":{"bus":"lv","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
                   "p_nom":[2000.0],"q_nom":[0.0]},
             "l2":{"bus":"lv","terminal_map":["2","n"],"configuration":"SINGLE_PHASE",
                   "p_nom":[2000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        # Initialisation block is captured from the warm-start regardless of the
        # solve outcome.
        i1 = res["initialisation"]["lv"]["1"]["va_init"]
        i2 = res["initialisation"]["lv"]["2"]["va_init"]
        @test isapprox(abs(rem2pi(i2 - i1, RoundNearest)), π; atol=0.05)  # legs ~180° apart
    end

    @testset "T-INV1: FOUR_LEG inverter, box Q bounds via augmentation" begin
        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"R_series_2_2":0.01,"R_series_3_3":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"PV",
             "s_max":[3000.0,3000.0,3000.0],
             "p_max":[3000.0,3000.0,3000.0],"p_min":[0.0,0.0,0.0],
             "cost":[0.1,0.1,0.1]}}}
        """; from_string=true)

        net′, _ = augment_case(net; recipe=AugmentationRecipe(
            apply_v_bounds=false, apply_vpn_bounds=false,
            apply_vpp_bounds=false, apply_vneg_bounds=false,
            apply_thermal=false, apply_q_bounds=false,
            apply_slack_generator=false))

        # Augmentation should have added q_min/q_max to the inverter
        inv = net′["inverter"]["pv1"]
        @test haskey(inv, "q_max")
        @test inv["q_max"][1] ≈ 3000.0 * tan(acos(0.90))   rtol=1e-6

        res = solve_opf(net′)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test haskey(res, "inverter")
        @test haskey(res["inverter"], "pv1")
        # Inverter should dispatch close to p_max on each phase (cheaper than slack)
        for t in ("1","2","3")
            @test res["inverter"]["pv1"][t]["pg"] ≈ 3000.0   atol=1.0
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV2: Constant power-factor equality constraint
    #
    # A FOUR_LEG PV inverter with a power_factor control profile (pf = 0.9,
    # lagging). The OPF must satisfy Q_k = -tan(arccos(0.9)) * P_k exactly.
    # We verify the Q/P ratio at the solved dispatch point.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV2: constant power-factor equality enforced" begin
        pf_target = 0.9
        tan_phi   = tan(acos(pf_target))

        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"R_series_2_2":0.01,"R_series_3_3":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}},
         "control_profile":{"pf09":{"power_factor":{"pf":0.9}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"PV",
             "s_max":[3000.0,3000.0,3000.0],
             "p_max":[2700.0,2700.0,2700.0],"p_min":[0.0,0.0,0.0],
             "control_profile":"pf09","cost":[0.1,0.1,0.1]}}}
        """; from_string=true)

        # Augmentation must NOT add q_min/q_max (PF profile present)
        net′, _ = augment_case(net; recipe=AugmentationRecipe(
            apply_v_bounds=false, apply_vpn_bounds=false,
            apply_vpp_bounds=false, apply_vneg_bounds=false,
            apply_thermal=false, apply_q_bounds=false,
            apply_slack_generator=false))
        @test !haskey(net′["inverter"]["pv1"], "q_min")

        res = solve_opf(net′)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        for t in ("1","2","3")
            pg = res["inverter"]["pv1"][t]["pg"]
            qg = res["inverter"]["pv1"][t]["qg"]
            # PF equality: Q = -tan_phi * P  (pf > 0 → lagging → absorbing VAr)
            @test qg ≈ -tan_phi * pg   atol=0.1
        end

        # solution_check must not flag PF deviation
        f = Finding[]
        solution_check(net′, res, f)
        @test !any(f_ -> f_.code == "W.SOL.INV_PF_DEVIATION", f)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV3: s_max circle is binding
    #
    # Inverter with p_max = s_max * pf (exactly on the circle boundary).
    # With the constant-PF coupling the apparent power must equal s_max.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV3: s_max apparent-power circle respected" begin
        pf      = 0.9
        s_max_k = 3000.0
        p_max_k = s_max_k * pf   # 2700 W — on the circle

        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                    "v_min":[200.0],"v_max":[260.0]},
            "b1":  {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                    "v_min":[200.0],"v_max":[260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0],"cost":[1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.001}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]}},
         "control_profile":{"pf09":{"power_factor":{"pf":0.9}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","n"],
             "topology":"SINGLE_PHASE","prime_mover":"PV",
             "s_max":[3000.0],"p_max":[2700.0],"p_min":[0.0],
             "control_profile":"pf09","cost":[0.1]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg = res["inverter"]["pv1"]["1"]["pg"]
        qg = res["inverter"]["pv1"]["1"]["qg"]
        sm = sqrt(pg^2 + qg^2)
        @test sm <= s_max_k * 1.001   # within 0.1 % of nameplate
        @test pg <= p_max_k * 1.001
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV4: per-unit mode parity for inverters
    #
    # Regression guard for the inverter per-unit gap: _to_per_unit must scale
    # the inverter's p/q/s bounds by s_base and _from_per_unit must scale the
    # cri/cii/pg/qg results back to SI. The SI-mode and PU-mode solves of the
    # same network must agree on the reported inverter dispatch (pg/qg) and
    # currents (cri/cii). Without the scalers the PU-mode bounds are applied at
    # 1e6× the intended tightness and the results come out in a hybrid scale.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV4: per-unit mode matches SI mode for inverters" begin
        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0, 200.0, 200.0],"v_max":[260.0, 260.0, 260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"R_series_2_2":0.01,"R_series_3_3":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}},
         "control_profile":{"pf09":{"power_factor":{"pf":0.9}}},
         "inverter":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"PV",
             "s_max":[3000.0,3000.0,3000.0],
             "p_max":[2700.0,2700.0,2700.0],"p_min":[0.0,0.0,0.0],
             "control_profile":"pf09","cost":[0.1,0.1,0.1]}}}
        """; from_string=true)

        net′, _ = augment_case(net; recipe=AugmentationRecipe(
            apply_v_bounds=false, apply_vpn_bounds=false,
            apply_vpp_bounds=false, apply_vneg_bounds=false,
            apply_thermal=false, apply_q_bounds=false,
            apply_slack_generator=false))

        res_si = solve_opf(net′; per_unit=false)
        res_pu = solve_opf(net′; per_unit=true, s_base=1e6)
        @test res_si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        for t in ("1","2","3")
            si = res_si["inverter"]["pv1"][t]
            pu = res_pu["inverter"]["pv1"][t]
            @test pu["pg"]  ≈ si["pg"]   rtol=1e-4
            @test pu["qg"]  ≈ si["qg"]   atol=1.0
            @test pu["cri"] ≈ si["cri"]  rtol=1e-4 atol=1e-3
            @test pu["cii"] ≈ si["cii"]  rtol=1e-4 atol=1e-3
            # Sanity: PU-mode dispatch is in SI watts, near p_max (cheaper than slack)
            @test pu["pg"] ≈ 2700.0   atol=5.0
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-VBND: per-phase vpn arrays and per-pair vpp arrays on a 4-wire bus.
    # Regression-guards that the OPF constraint builder (and the per-unit scaler)
    # consume them as arrays rather than crashing on Float64(::Vector). Bounds
    # are hand-set to physically feasible values (phase-to-ground ≈1000 V,
    # line-to-line ≈1732 V) so the solve is well-posed.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-VBND: per-phase vpn/vpp array bounds solve" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[900.0, 900.0, 900.0],"v_max":[1100.0, 1100.0, 1100.0],
                   "vpn_min":[900.0,900.0,900.0],"vpn_max":[1100.0,1100.0,1100.0],
                   "vpp_min":[1500.0,1500.0,1500.0],"vpp_max":[2000.0,2000.0,2000.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-4,"R_series_2_2":1.0e-4,"R_series_3_3":1.0e-4}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-VBND2: per-phase ASYMMETRIC v_min/v_max bind differently per phase. A
    # tight upper bound on phase 1 only must cap phase-1 voltage while phases
    # 2/3 stay higher — proving the bound is indexed per phase, not shared.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-VBND2: per-phase asymmetric v_min/v_max" begin
        # A reactive-capable generator with negative cost pushes every phase
        # voltage up to ~1069.6 V when uncapped. Capping phase 1 only (at 1030)
        # must bind there while phases 2/3 stay at the higher uncapped level —
        # proving the bound is indexed per phase, not shared.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[900.0,900.0,900.0],"v_max":[1030.0, 1200.0, 1200.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5,
             "X_series_1_1":0.5,"X_series_2_2":0.5,"X_series_3_3":0.5}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":1.0}},
         "generator":{"g":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_min":[0.0,0.0,0.0],"p_max":[1.0e5,1.0e5,1.0e5],
             "q_min":[0.0,0.0,0.0],"q_max":[1.0e5,1.0e5,1.0e5],
             "cost":[-1.0,-1.0,-1.0]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        vm1 = res["bus"]["b1"]["1"]["vm"]
        vm2 = res["bus"]["b1"]["2"]["vm"]
        @test vm1 ≤ 1030.0 + 1e-2            # phase-1 cap is active
        @test vm2 > 1030.0 + 5.0             # phase-2 free to exceed phase-1 cap
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-VNMAX: the optional scalar vn_max caps the neutral-to-ground voltage.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-VNMAX: neutral-to-ground cap" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],
                   "v_min":[900.0,900.0,900.0],"v_max":[1100.0,1100.0,1100.0],
                   "vn_max":5.0}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-3,"R_series_2_2":1.0e-3,"R_series_3_3":1.0e-3,
             "R_series_4_4":1.0e-3}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","n"],"configuration":"WYE",
             "p_nom":[5000.0],"q_nom":[0.0]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        vmn = res["bus"]["b1"]["n"]["vm"]
        @test vmn ≤ 5.0 + 1e-3               # neutral cap enforced
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-VBND-ALIGN: per-phase bound index alignment when a phase is grounded.
    # Bus b1 has phase "1" perfectly grounded, so it is skipped when applying
    # phase bounds. The vpn_max array is [tight, loose, loose]; the tight entry
    # belongs to phase 1 (grounded, never applied). A buggy implementation that
    # collapses onto the filtered phase list would apply vpn_max[1] (tight) to
    # phase 2 — so phase 2's voltage would be wrongly capped. With correct
    # full-order indexing phase 2 sees vpn_max[2] (loose) and stays high.
    @testset "T-VBND-ALIGN: per-phase index alignment under grounded phase" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["1","n"],
                   "vpn_min":[1.0, 900.0, 900.0],
                   "vpn_max":[2.0, 1100.0, 1100.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-3,"R_series_2_2":1.0e-3,"R_series_3_3":1.0e-3}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["2","n"],"configuration":"WYE",
             "p_nom":[1000.0],"q_nom":[0.0]}}}
        """; from_string=true)
        # Phase 1 is grounded, so the phase-bound loop skips it. Phase 2's bound
        # is vpn_max[2]=1100 (≈ solved 1000 V is feasible). A buggy collapse onto
        # the filtered list would apply vpn_max[1]=2.0 to phase 2 — making the
        # problem infeasible (2 V cap vs ~1000 V solution). So a successful solve
        # with phase 2 ≈ 1000 V proves the indices are aligned.
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        vpn2 = let b = res["bus"]["b1"]
            sqrt((b["2"]["vr"] - b["n"]["vr"])^2 + (b["2"]["vi"] - b["n"]["vi"])^2)
        end
        @test vpn2 > 900.0    # governed by its own loose bound, not phase 1's 2 V
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-PCOST: non-uniform per-phase cost. A generator is forced (p_min=p_max)
    # to distinct per-phase outputs that exactly serve the per-phase load, so
    # the objective is the deterministic Σ cost_k · P_k:
    #   0.1·10000 + 0.2·20000 + 0.3·30000 = 14 000.
    # The old polynomial reading ([c2,c1,c0]) would have applied a single c1 to
    # every phase (0.2·60000 = 12 000), so this value distinguishes the two.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-PCOST: per-phase linear cost → objective" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],"v_min":[950.0, 950.0, 950.0],"v_max":[1050.0, 1050.0, 1050.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-4,"R_series_2_2":1.0e-4,"R_series_3_3":1.0e-4}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1","terminal_map_from":["1","2","3"],
             "terminal_map_to":["1","2","3"],"linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[10000.0,20000.0,30000.0],"q_nom":[0.0,0.0,0.0]}},
         "generator":{"g1":{"bus":"bus1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_min":[10000.0,20000.0,30000.0],"p_max":[10000.0,20000.0,30000.0],
             "q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],
             "cost":[0.1,0.2,0.3]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["objective"] ≈ 14_000.0   atol=1.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-AUGBND: end-to-end regression — augment_case must produce voltage bounds
    # that a plain 4-wire LV feeder can actually satisfy. Before the fix the
    # injected vpn (≈120-146 V) and vpp (≈207-253 V) bounds were physically
    # impossible for a 230 V (L-N) / 398 V (L-L) feeder → LOCALLY_INFEASIBLE.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-AUGBND: augment_case bounds solve on 4-wire LV feeder" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":3.96e-4,"R_series_2_2":3.96e-4,
                           "R_series_3_3":3.96e-4,"R_series_4_4":3.96e-4}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":100.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)
        net′, _ = augment_case(net)
        res = solve_opf(net′)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    # ═════════════════════════════════════════════════════════════════════════
    # Feasibility-OPF parity guards (refactor safety net).
    #
    # These three tests pin the invariants that the planned "shared engine +
    # per-problem build recipe" refactor is most likely to break — namely that
    # solve_feasibility_opf carries the *same hard bounds* as solve_opf, returns
    # the *same physical solution* when the network is feasible, and exposes a
    # *stable result-dict contract* for its slack outputs. They are written
    # against the current (pre-refactor) implementation and must pass as-is.
    # ═════════════════════════════════════════════════════════════════════════

    # ─────────────────────────────────────────────────────────────────────────
    # A: Feasibility OPF honours the OPF's hard voltage bounds.
    #
    # T3 geometry with a tight v_max on bus1 (960–999 V) and NO generator, so the
    # load forces V toward ~947 V; we instead clamp v_max to a value BELOW the
    # physical voltage. solve_opf would be infeasible. solve_feasibility_opf must
    # NOT violate the bound: the voltage sits at the bound and the resulting power
    # imbalance surfaces as a non-zero slack injection at that terminal. This is
    # the exact invariant — "identical hard constraints, KCL is the only
    # relaxation" — that moving the bound calls into a shared builder can break.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "A: feasibility honours hard voltage bounds (residual, no violation)" begin
        # Force the load-bus voltage into a tight band the load cannot physically
        # satisfy: at full load the physical voltage is ~947 V, but v_min=985 V
        # forbids that. solve_opf would be infeasible; solve_feasibility_opf must
        # keep V within [985,999] and surface the imbalance as a slack residual.
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[985.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_feasibility_opf(net)
        @test res["is_feasibility_opf"] == true
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Hard v_min/v_max must be respected (the only relaxation is nodal current).
        vm = res["bus"]["bus1"]["1"]["vm"]
        @test vm >= 985.0 - 1e-2
        @test vm <= 999.0 + 1e-2

        # The physical solution at full load (~947 V) is below v_min=985, so the
        # bound is binding and the imbalance must appear as a non-zero residual.
        @test res["total_slack_magnitude_A"] > 1.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # B: OPF and feasibility OPF agree on a feasible bounded network.
    #
    # On a network where solve_opf is feasible, the feasibility model's elastic
    # slack must be driven to ≈0 and its bus voltages must match solve_opf to a
    # tight tolerance — proving both build paths assemble the same device
    # constraints over the same feasible set. Uses the T2 balanced fixture.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "B: OPF vs feasibility consistency (slack≈0, voltages match)" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0,900.0,900.0],"v_max":[999.0,999.0,999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[100000.0,100000.0,100000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        r_opf  = solve_opf(net)
        r_feas = solve_feasibility_opf(net)
        @test r_opf["termination_status"]  in ("LOCALLY_SOLVED", "OPTIMAL")
        @test r_feas["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Feasible network → elastic slack collapses to ≈0.
        @test r_feas["total_slack_magnitude_A"] < 1e-3

        # Bus voltages from both formulations must coincide.
        for ph in ("1","2","3")
            @test r_feas["bus"]["bus1"][ph]["vm"] ≈ r_opf["bus"]["bus1"][ph]["vm"] atol=0.05
            @test r_feas["bus"]["bus1"][ph]["va"] ≈ r_opf["bus"]["bus1"][ph]["va"] atol=1e-4
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # C: Feasibility-OPF result-dict contract (mirror of T14 for slack outputs).
    #
    # Pins the shape of the feasibility-specific result sections so that moving
    # slack-result extraction into a build recipe cannot silently rename or drop
    # fields that diagnose_infeasibility consumes.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "C: feasibility result dict structure contract" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[985.0],"v_max":[999.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_feasibility_opf(net)

        # ── feasibility-specific top-level keys ───────────────────────────────
        @test res["is_feasibility_opf"] === true
        @test haskey(res, "slack_injections")
        @test haskey(res, "total_slack_magnitude_A")
        @test res["total_slack_magnitude_A"] isa Float64
        @test res["total_slack_magnitude_A"] >= 0.0

        # ── it remains a superset of the OPF dict contract ────────────────────
        for k in ("termination_status","objective","bus","line","load","voltage_source")
            @test haskey(res, k)
        end

        # ── slack_injections: bus → terminal → {cs_r, cs_i, cs_mag} ────────────
        si = res["slack_injections"]
        @test si isa Dict
        @test haskey(si, "bus1")            # non-source, ungrounded → has a slack node
        td = si["bus1"]["1"]
        for f in ("cs_r","cs_i","cs_mag")
            @test haskey(td, f)
            @test td[f] isa Float64
        end
        @test td["cs_mag"] >= 0.0
        @test td["cs_mag"] ≈ sqrt(td["cs_r"]^2 + td["cs_i"]^2) atol=1e-9

        # Grounded terminals carry no elastic slack.
        @test !(haskey(si, "bus1") && haskey(si["bus1"], "n"))

        # total_slack_magnitude_A equals the L2 norm over all reported nodes.
        total = sqrt(sum(v["cs_mag"]^2 for bd in values(si) for v in values(bd); init=0.0))
        @test res["total_slack_magnitude_A"] ≈ total atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────────
    # GND: ground currents — node-level injection + line π-shunt earth return.
    #
    # Single-phase line with a from-side shunt susceptance B. The line carries no
    # series shunt loss (G=0), so its device ground current is purely the shunt
    # current into earth: cg = (G + jB)·V_fr summed over phases ⇒ cg_i = B·vr_fr,
    # cg_r = −B·vi_fr. The grounded neutral terminals must appear in the node
    # "ground" section with finite currents.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "GND: ground currents — node injection + line shunt earth return" begin
        B = 1e-4
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[1100.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5,"B_from_1_1":$B}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[50000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Node-level ground section: grounded neutrals present, currents finite.
        @test haskey(res, "ground")
        @test haskey(res["ground"], "sourcebus") && haskey(res["ground"]["sourcebus"], "n")
        @test haskey(res["ground"], "bus1")      && haskey(res["ground"]["bus1"], "n")
        for bd in values(res["ground"]), v in values(bd)
            @test isfinite(v["cg_r"]) && isfinite(v["cg_i"]) && isfinite(v["cgm"])
            @test v["cgm"] ≈ sqrt(v["cg_r"]^2 + v["cg_i"]^2) atol=1e-9
        end

        # Line device ground current = from-side π-shunt current into earth.
        vr_fr = res["bus"]["sourcebus"]["1"]["vr"]
        vi_fr = res["bus"]["sourcebus"]["1"]["vi"]
        lg = res["line"]["l1"]["ground"]
        @test lg["cg_r"] ≈ -B * vi_fr atol=1e-9
        @test lg["cg_i"] ≈  B * vr_fr atol=1e-9
        @test lg["cgm"]  ≈ sqrt(lg["cg_r"]^2 + lg["cg_i"]^2) atol=1e-12
        @test lg["cgm"] > 0.0   # shunt present ⇒ nonzero earth current
    end

    # ─────────────────────────────────────────────────────────────────────────
    # LOSS: complex element losses via the terminal-power identity
    #   S_loss = 1ᵀ S_from + 1ᵀ S_to
    # and the network-wide P/Q balance built on them.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "LOSS: complex line loss (R+jX) and exact P/Q balance" begin
        R = 0.5; X = 0.3; P = 60_000.0; Q = 20_000.0
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                         "v_min":[800.0],"v_max":[1100.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":$R,"X_series_1_1":$X}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[$P],"q_nom":[$Q]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Series current (no shunt ⇒ total = series). Loss must equal Z·|I|².
        cr = res["line"]["l1"]["1"]["cr_fr"]; ci = res["line"]["l1"]["1"]["ci_fr"]
        I2 = cr^2 + ci^2
        ll = res["line"]["l1"]["loss"]
        @test ll["p_loss"] ≈ R * I2  rtol=1e-6
        @test ll["q_loss"] ≈ X * I2  rtol=1e-6
        @test ll["p_loss"] > 0.0 && ll["q_loss"] > 0.0     # inductive line absorbs Q
        @test res["losses"]["p_loss"] ≈ ll["p_loss"] rtol=1e-9
        @test res["losses"]["q_loss"] ≈ ll["q_loss"] rtol=1e-9

        # Network balance closes for BOTH P and Q (slack supplies load + loss).
        f = Finding[]
        prof = solution_check(net, res, f)
        @test prof["p_loss"] ≈ R * I2  rtol=1e-6
        @test prof["q_loss"] ≈ X * I2  rtol=1e-6
        @test prof["power_balance_err"]   < max(0.01*abs(prof["p_load"]), 1.0)
        @test prof["q_power_balance_err"] < max(0.01*abs(prof["q_load"]),
                                                0.01*abs(prof["q_gen"]), 1.0)
        @test !any(fd -> fd.code == "W.SOL.POWER_BALANCE", f)
    end

    # ═════════════════════════════════════════════════════════════════════════
    # Power flow — solve_pf
    #
    # A determined power flow: same physics as solve_opf, but no operational
    # bounds and no objective. Verified against the same analytic fixed points
    # and cross-checked against solve_opf / solve_feasibility_opf.
    # ═════════════════════════════════════════════════════════════════════════

    # ─────────────────────────────────────────────────────────────────────────
    # PF1: single-phase resistive — same closed-form voltage as T1.
    #   V² − V_s·V + R·P = 0  →  V = (V_s + √(V_s² − 4RP)) / 2
    # No voltage bounds present (PF imposes none), so the source-warm-start lands
    # on the high-voltage physical root.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF1: single-phase resistive — exact voltage" begin
        V_s = 1000.0;  R = 0.5;  P = 100_000.0
        V_exp = (V_s + sqrt(V_s^2 - 4*R*P)) / 2   # ≈ 947.214 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["is_power_flow"] == true
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["bus1"]["1"]["vm"] ≈ V_exp   atol=0.01
        @test abs(res["bus"]["bus1"]["1"]["vi"]) < 0.01
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF2: PF agrees with feasibility OPF (slack≈0) on a bound-free load network.
    # Both solve the same physics; the only difference is the elastic slack and
    # the objective, neither of which is active on a feasible determined network.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF2: solve_pf matches solve_feasibility_opf voltages" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus",
             "terminal_map":["1","2","3"],
             "v_magnitude":[1000.0,1000.0,1000.0],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[100000.0,100000.0,100000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        r_pf   = solve_pf(net)
        r_feas = solve_feasibility_opf(net)
        @test r_pf["termination_status"]   in ("LOCALLY_SOLVED", "OPTIMAL")
        @test r_feas["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test r_feas["total_slack_magnitude_A"] < 1e-3
        for ph in ("1","2","3")
            @test r_pf["bus"]["bus1"][ph]["vm"] ≈ r_feas["bus"]["bus1"][ph]["vm"] atol=0.05
            @test r_pf["bus"]["bus1"][ph]["va"] ≈ r_feas["bus"]["bus1"][ph]["va"] atol=1e-4
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF3: fixed-setpoint generator — PF matches solve_opf on the same dispatch.
    # T3 fixes the generator at p_min == p_max == 50 kW; with that dispatch the
    # PF and OPF must give the identical bus voltage (no bounds bind in T3's OPF).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF3: fixed-setpoint generator matches solve_opf" begin
        V_s = 1000.0;  R = 0.5;  P_load = 100_000.0;  P_gen = 50_000.0
        P_net = P_load - P_gen
        V_exp = (V_s + sqrt(V_s^2 - 4*R*P_net)) / 2   # ≈ 974.342 V

        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1"],
             "configuration":"WYE",
             "p_min":[50000.0],"p_max":[50000.0],
             "q_min":[0.0],"q_max":[0.0],"cost":[0.1]}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["bus1"]["1"]["vm"]        ≈ V_exp   atol=0.01
        @test res["generator"]["gen1"]["1"]["pg"] ≈ P_gen   atol=1.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF4: a generator with a non-degenerate range is rejected (no objective to
    # pick a dispatch — solve_pf requires fixed setpoints).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF4: non-degenerate generator range is rejected" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1"],
             "configuration":"WYE",
             "p_min":[0.0],"p_max":[50000.0],
             "q_min":[0.0],"q_max":[0.0],"cost":[0.1]}}}
        """; from_string=true)

        @test_throws ArgumentError solve_pf(net)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF5: operational limits are ignored — a binding line i_max that would clip
    # the OPF does not constrain the PF (and does not mutate the caller's net).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF5: device current limits are ignored by solve_pf" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5,"i_max":[1.0e-3]}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # Physical current (~108 A) far exceeds the absurd i_max=1e-3 A, proving
        # the thermal limit was not enforced.
        @test res["line"]["l1"]["1"]["cm_fr"] > 1.0
        # The caller's net must be untouched (limit stripping happens on a copy).
        @test net["linecode"]["lc"]["i_max"] == [1.0e-3]
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Single-phase autotransformer / step voltage regulator
    #
    # Lossless ideal regulator collapses to V_to = n_eff·V_fr_pn.
    # Type B (default): n_eff = a.  Type A: n_eff = 1/a.
    # No load → no current → V_to is exactly the boosted source voltage.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "REG: single-phase autotransformer Type B — boosted ratio" begin
        V_s = 2400.0;  a = 1.05
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase_autotransformer":{"r1":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.05,"regulator_type":"B","s_rating":500000.0}}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["reg"]["1"]["vm"] ≈ a * V_s   atol=0.01
        @test abs(res["bus"]["reg"]["1"]["vi"]) < 0.01
    end

    @testset "REG: single-phase autotransformer Type A — reciprocal ratio" begin
        V_s = 2400.0;  a = 1.05   # Type A: n_eff = 1/a → V_to = V_s / a
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase_autotransformer":{"r1":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.05,"regulator_type":"A","s_rating":500000.0}}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["bus"]["reg"]["1"]["vm"] ≈ V_s / a   atol=0.01
    end

    @testset "REG: autotransformer under load — positive loss, KCL closes" begin
        # A lossy regulator feeding a load. The shared-neutral KCL sign is correct
        # iff the series resistance dissipates POSITIVE power (negative loss is the
        # classic sign-error symptom). Feasibility OPF must close KCL (slack ≈ 0).
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[2200.0],"v_max":[2800.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase_autotransformer":{"r1":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.05,"regulator_type":"B","s_rating":500000.0,
             "r_series_from":0.5,"x_series_from":0.0}}},
         "load":{"ld":{"bus":"reg","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[50000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_feasibility_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["total_slack_magnitude_A"] < 1e-3        # KCL closes
        # Series current → from terminal; copper loss = R·|I_s|².
        cr = res["transformer"]["r1"]["fr"]["1"]["cr"]
        ci = res["transformer"]["r1"]["fr"]["1"]["ci"]
        @test 0.5 * (cr^2 + ci^2) > 0.0                    # positive loss
        # The terminal-power identity loss must equal R·|I_s|² (no shunt, no X).
        xloss = res["transformer"]["r1"]["loss"]
        @test xloss["p_loss"] ≈ 0.5 * (cr^2 + ci^2)  rtol=1e-6
        @test xloss["p_loss"] > 0.0                        # dissipative, not generating
        @test abs(xloss["q_loss"]) < 1e-3                  # X=0 ⇒ no reactive loss
    end

    # ─────────────────────────────────────────────────────────────────────────
    # NEUTRAL: secondary return must close through the transformer neutral, not
    # leak to earth. Discriminating case = an UNGROUNDED secondary neutral, which
    # the balanced/grounded tests above cannot exercise. Before the fix the YY
    # secondary and the autotransformer to-neutral were left dangling, producing
    # a slack current = Σ I_to (≈ the load current) at the floating neutral.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "NEUTRAL: YY secondary return closes through floating LV neutral" begin
        # Single-phase YY transformer, LV neutral NOT grounded. KCL can only close
        # if the secondary current returns through the transformer's LV neutral.
        net = parse_bmopf("""
        {"bus":{
            "hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":[]}},
         "voltage_source":{"vs":{"bus":"hv","terminal_map":["1","n"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase":{"t1":{
             "bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "v_ref_from":2400.0,"v_ref_to":240.0,"s_rating":50000.0,
             "r_series_from":0.1,"x_series_from":0.0}}},
         "load":{"ld":{"bus":"lv","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[20000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_feasibility_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["total_slack_magnitude_A"] < 1e-3        # return closes — no slack
        @test res["load"]["ld"]["1"]["pd"] ≈ 20000.0  rtol=1e-3
    end

    @testset "NEUTRAL: autotransformer shared-neutral bond ties floating to-neutral" begin
        # SVR with an UNGROUNDED secondary neutral. The galvanic neutral bond must
        # tie reg/n to the (grounded) src/n so the return current closes.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","n"],"perfectly_grounded_terminals":[]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","n"],
             "v_magnitude":[2400.0],"v_angle":[0.0]}},
         "transformer":{"single_phase_autotransformer":{"r1":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "tap_ratio":1.05,"regulator_type":"B","s_rating":500000.0,
             "r_series_from":0.5,"x_series_from":0.0}}},
         "load":{"ld":{"bus":"reg","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[50000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_feasibility_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["total_slack_magnitude_A"] < 1e-3        # return closes via the bond
        # Bond ties the two neutrals to the same potential (src/n grounded ⇒ 0).
        @test res["bus"]["reg"]["n"]["vm"] ≈ res["bus"]["src"]["n"]["vm"]  atol=1e-4
    end

    # ─────────────────────────────────────────────────────────────────────────
    # LINE-TO-LINE: single_phase and autotransformer connected phase-to-phase
    # (terminal_map = ["1","2"], no neutral). The winding spans V₁−V₂; a 2-phase
    # map is ONE winding, not two phase-to-ground units.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "LL: single_phase transformer with line-to-line primary" begin
        # 4160 V L-L primary → 240 V L-N secondary. One winding across HV 1-2.
        Vs = 2401.0  # phase-to-ground source magnitude (L-L ≈ 4158 V)
        net = parse_bmopf("""
        {"bus":{
            "hv":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[210.0],"v_max":[260.0]}},
         "voltage_source":{"vs":{"bus":"hv","terminal_map":["1","2","3"],
             "v_magnitude":[$Vs,$Vs,$Vs],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"single_phase":{"t1":{
             "bus_from":"hv","bus_to":"lv",
             "terminal_map_from":["1","2"],"terminal_map_to":["1","n"],
             "v_ref_from":4160.0,"v_ref_to":240.0,"s_rating":50000.0,
             "r_series_from":0.1,"x_series_from":0.0}}},
         "load":{"ld":{"bus":"lv","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[8000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # Exactly one reported series winding current (not two).
        @test sort(collect(keys(res["transformer"]["t1"]["fr"]))) == ["1"]
        # Secondary L-N voltage ≈ HV L-L voltage / ratio (4160/240).
        vll = sqrt((res["bus"]["hv"]["1"]["vr"] - res["bus"]["hv"]["2"]["vr"])^2 +
                   (res["bus"]["hv"]["1"]["vi"] - res["bus"]["hv"]["2"]["vi"])^2)
        @test res["bus"]["lv"]["1"]["vm"] ≈ vll * 240/4160  rtol=2e-3
        @test res["transformer"]["t1"]["loss"]["p_loss"] > 0.0   # R·|I|² dissipation
    end

    @testset "LL: single_phase autotransformer across two phases" begin
        # Type B regulator across phases 1-2 (no neutral): V_LL boosted by a.
        a = 1.05
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3"],"perfectly_grounded_terminals":[]},
            "reg":{"terminal_names":["1","2","3"],"perfectly_grounded_terminals":[]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[2400.0,2400.0,2400.0],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"single_phase_autotransformer":{"r1":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","2"],"terminal_map_to":["1","2"],
             "tap_ratio":$a,"regulator_type":"B","s_rating":500000.0}}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        Vll(b) = sqrt((res["bus"][b]["1"]["vr"] - res["bus"][b]["2"]["vr"])^2 +
                      (res["bus"][b]["1"]["vi"] - res["bus"][b]["2"]["vi"])^2)
        @test Vll("reg") ≈ a * Vll("src")  rtol=1e-3
    end

    @testset "REG: open-delta regulator ABBC — both line-to-line ratios" begin
        # Lossless open-delta, no load: each regulating winding boosts its
        # line-to-line voltage by its tap. With balanced source phases the
        # regulated phase-pair magnitudes equal a_j · |V_LL_source|.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]},
            "reg":{"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[2400.0,2400.0,2400.0],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "transformer":{"open_delta_regulator":{"od":{
             "bus_from":"src","bus_to":"reg",
             "terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],
             "connection":"ABBC","tap_ratio":[1.05,1.025],"regulator_type":"B",
             "s_rating":500000.0}}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        Vll(b, p, q) = begin
            vr = res["bus"][b][p]["vr"] - res["bus"][b][q]["vr"]
            vi = res["bus"][b][p]["vi"] - res["bus"][b][q]["vi"]
            sqrt(vr^2 + vi^2)
        end
        Vll_src_12 = Vll("src", "1", "2")
        Vll_src_23 = Vll("src", "2", "3")
        @test Vll("reg", "1", "2") ≈ 1.05  * Vll_src_12   rtol=1e-3
        @test Vll("reg", "2", "3") ≈ 1.025 * Vll_src_23   rtol=1e-3
    end

end  # @testset "OPF — solve_opf extension"
