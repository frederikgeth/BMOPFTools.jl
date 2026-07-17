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
        @test res["objective"]                      ≈ cost * P_gen / 1000  atol=1e-4
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T4: Cost-optimal dispatch — negative unit cost drives output to p_max
    #
    # cost = −1 $/kWh → minimising the objective maximises Pg → each phase
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
        @test res["objective"] ≈ -3.0 * P_max_ph / 1000   atol=0.01
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T4b: Uniform cost convention — voltage source ≡ generator
    #
    # The `cost` field is `$/kWh of active energy INJECTED into the network`, with the
    # SAME sign convention for generators and the voltage source (both stamp +I
    # into KCL; both report power as +injection). So a POSITIVE cost minimises that
    # element's injection in both cases:
    #   • costly generator  → generates as little as possible (pg → p_min);
    #   • costly source     → imports as little as possible, i.e. exports (ps → −).
    # This locks the convention so source costs are never silently flipped vs
    # generator/IBR costs. (To maximise exports: positive slack cost = import price.)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T4b: uniform cost convention (source ≡ generator)" begin
        P_load = 100_000.0;  P_max = 150_000.0
        mknet(c_gen, c_src) = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[1100.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0],"cost":[$c_src]}},
         "linecode":{"lc":{"R_series_1_1":1.0e-4}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[$P_load],"q_nom":[0.0]}},
         "generator":{"gen1":{"bus":"bus1","terminal_map":["1"],
             "configuration":"WYE","p_min":[0.0],"p_max":[$P_max],
             "q_min":[0.0],"q_max":[0.0],"cost":[$c_gen]}}}
        """; from_string=true)

        # Case A: source free, generator costly → costly generator minimises its
        # injection (pg → 0); the source supplies the load (ps > 0).
        resA = solve_opf(mknet(1.0, 0.0))
        @test resA["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test resA["generator"]["gen1"]["1"]["pg"] ≈ 0.0   atol=1.0
        @test resA["voltage_source"]["vs"]["1"]["ps"] > P_load - 1.0   # source imports

        # Case B: generator free, source costly → costly source minimises its
        # injection, driving it NEGATIVE (export), while the generator maxes out.
        # Same positive-cost-→-less-injection rule as the generator in Case A.
        resB = solve_opf(mknet(0.0, 1.0))
        @test resB["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test resB["generator"]["gen1"]["1"]["pg"] ≈ P_max   atol=2.0
        @test resB["voltage_source"]["vs"]["1"]["ps"] < 0.0           # source exports
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
    # cost = -0.05 $/kWh → objective rate = -0.05 × 200 kW = -10 $/h
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

        # Profit-seeking generator (cost=-0.05 $/kWh) binds at p_max=200 000 W.
        # objective rate = -0.05 × 200 kW = -10 $/h; pg remains in W.
        @test res["objective"] ≈ -10.0   rtol=1e-3
        @test res["generator"]["g1"]["1"]["pg"] ≈ 200_000.0   rtol=1e-3
    end

    @testset "T11b: per-unit — linecode shared across voltage levels is split" begin
        # Regression: one z_base was taken per linecode (from the first
        # referencing line), so a linecode shared by MV and LV lines had the
        # other level's impedances scaled with the wrong base — silently.
        net = parse_bmopf("""
        {"bus":{
            "mvsrc":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "mvb":  {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lvb":  {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lvb2": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"mvsrc","terminal_map":["1"],
             "v_magnitude":[11000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.4,"R_series_2_2":0.4}},
         "line":{
             "lmv":{"bus_from":"mvsrc","bus_to":"mvb",
                 "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
                 "linecode":"lc","length":100.0},
             "llv":{"bus_from":"lvb","bus_to":"lvb2",
                 "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
                 "linecode":"lc","length":50.0}},
         "transformer":{"single_phase":{"tx":{"bus_from":"mvb","bus_to":"lvb",
             "terminal_map_from":["1"],"terminal_map_to":["1"],
             "s_rating":100000.0,"v_nom_from":11000.0,"v_nom_to":230.0,
             "r_series_from":1.0,"x_series_from":5.0}}},
         "load":{"ld":{"bus":"lvb2","terminal_map":["1","n"],"configuration":"WYE",
             "p_nom":[1000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        @test ext !== nothing
        net_pu, bases = ext._to_per_unit(net, 1e6)

        # The shared linecode must have been split into two.
        @test length(net_pu["linecode"]) == 2
        lc_mv_id = net_pu["line"]["lmv"]["linecode"]
        lc_lv_id = net_pu["line"]["llv"]["linecode"]
        @test lc_mv_id != lc_lv_id

        # Each copy is scaled with its own level's z_base.
        zb_mv = bases.z_base["mvsrc"]
        zb_lv = bases.z_base["lvb"]
        @test zb_mv != zb_lv
        @test net_pu["linecode"][lc_mv_id]["R_series_1_1"] ≈ 0.4 / zb_mv
        @test net_pu["linecode"][lc_lv_id]["R_series_1_1"] ≈ 0.4 / zb_lv

        # The user's dict is untouched.
        @test collect(keys(net["linecode"])) == ["lc"]
        @test net["line"]["llv"]["linecode"] == "lc"
    end

    @testset "T-HOOK: verbose, solver_options, model_hook!" begin
        net = _pu_net()

        # model_hook! can replace the objective — the standard cost objective
        # (−10 $/h, see T11) is overridden with a feasibility objective.
        res = solve_opf(net; model_hook! = ctx -> JuMP.@objective(ctx.model, Min, 0.0))
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test abs(res["objective"]) < 1e-6

        # model_hook! can add a constraint: cap the generator's export below
        # its unconstrained optimum (p_max = 200 kW binds at cost −0.05).
        # bus1's neutral is perfectly grounded, so P = vr·crg + vi·cig.
        res2 = solve_opf(net; model_hook! = ctx -> begin
            vr = ctx.vars[:vr];  vi = ctx.vars[:vi]
            crg = ctx.vars[:crg]; cig = ctx.vars[:cig]
            # model_hook! sees the model in its build units — per-unit by default
            # (per_unit=true). ctx.bases carries the conversion: divide a physical
            # watt cap by s_base to express it in the model's per-unit power, or 1.0
            # in SI mode where ctx.bases === nothing.
            sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
            JuMP.@constraint(ctx.model,
                vr[("bus1","1")]*crg[("g1",1)] +
                vi[("bus1","1")]*cig[("g1",1)] <= 150_000.0 / sb)
        end)
        @test res2["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res2["objective"] ≈ -0.05 * 150_000.0 / 1000   rtol=1e-3
        @test res2["generator"]["g1"]["1"]["pg"] ≈ 150_000.0   rtol=1e-3

        # solver_options are applied as raw solver attributes.
        res3 = solve_opf(net; solver_options=["max_iter" => 1])
        @test res3["termination_status"] == "ITERATION_LIMIT"

        # verbose=true streams the solver log (smoke: still solves).
        res4 = solve_opf(net; verbose=true)
        @test res4["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    @testset "T-SOLHOOK: solution_hook! extraction + custom_injection balance" begin
        # A custom device (battery) added ONLY via hooks — never in the JSON
        # spec. model_hook! stamps a single-phase P/Q injection into KCL with a
        # revenue price so it dispatches to its p_max bound; solution_hook! reads
        # its solved power (model still live) and registers it for power balance.
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[1100.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[100000.0],"q_nom":[0.0]}},
         "generator":{"g1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_min":[0.0],"p_max":[30000.0],
             "q_min":[0.0],"q_max":[0.0],"cost":[0.10]}},
         "battery":{"bat1":{"bus":"bus1","terminal_map":["1","n"],
             "p_min":0.0,"p_max":80000.0,"q_min":-40000.0,"q_max":40000.0,
             "discharge_price":-0.05}}}
        """; from_string=true)
        p_max_bat = 80000.0

        shared = Dict{Symbol,Any}()   # bridges the two hooks
        function bat_model_hook!(ctx)
            model = ctx.model
            vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
            sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
            base_obj = JuMP.objective_function(model)
            price = zero(JuMP.QuadExpr)
            for (bid, b) in get(ctx.net, "battery", Dict())
                bus = b["bus"]; tm = Vector{String}(b["terminal_map"])
                t_ph = tm[1]; t_n = length(tm) >= 2 ? tm[2] : nothing
                crb = JuMP.@variable(model, base_name = "crb_$bid")
                cib = JuMP.@variable(model, base_name = "cib_$bid")
                dvr = t_n === nothing ? vr[(bus,t_ph)] : JuMP.@expression(model, vr[(bus,t_ph)] - vr[(bus,t_n)])
                dvi = t_n === nothing ? vi[(bus,t_ph)] : JuMP.@expression(model, vi[(bus,t_ph)] - vi[(bus,t_n)])
                P = JuMP.@expression(model, dvr*crb + dvi*cib)
                Q = JuMP.@expression(model, dvi*crb - dvr*cib)
                JuMP.@constraint(model, P >= Float64(b["p_min"]) / sb)
                JuMP.@constraint(model, P <= Float64(b["p_max"]) / sb)
                JuMP.@constraint(model, Q >= Float64(b["q_min"]) / sb)
                JuMP.@constraint(model, Q <= Float64(b["q_max"]) / sb)
                JuMP.add_to_expression!(ctx.kcl_r[(bus,t_ph)], crb)
                JuMP.add_to_expression!(ctx.kcl_i[(bus,t_ph)], cib)
                t_n === nothing || JuMP.add_to_expression!(ctx.kcl_r[(bus,t_n)], -crb)
                t_n === nothing || JuMP.add_to_expression!(ctx.kcl_i[(bus,t_n)], -cib)
                price += Float64(b["discharge_price"]) * P
                shared[Symbol("P_", bid)] = P
                shared[Symbol("Q_", bid)] = Q
            end
            JuMP.@objective(model, Min, base_obj + price)
        end
        # solution_hook! that DOES register custom_injection.
        function bat_sol_hook!(ctx, result)
            sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
            p_tot = 0.0; q_tot = 0.0; bat_res = Dict{String,Any}()
            for (bid, _) in get(ctx.net, "battery", Dict())
                P_W  = JuMP.value(shared[Symbol("P_", bid)]) * sb
                Q_var = JuMP.value(shared[Symbol("Q_", bid)]) * sb
                bat_res[bid] = Dict{String,Any}("p"=>P_W, "q"=>Q_var)
                p_tot += P_W; q_tot += Q_var
            end
            result["battery"] = bat_res
            result["custom_injection"] = Dict{String,Any}("p"=>p_tot, "q"=>q_tot)
        end

        res = solve_opf(net; model_hook! = bat_model_hook!, solution_hook! = bat_sol_hook!)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # solution_hook! wrote the custom result block, in SI.
        @test haskey(res, "battery")
        @test haskey(res["battery"], "bat1")
        p_bat = res["battery"]["bat1"]["p"]
        @test p_bat ≈ p_max_bat   rtol=1e-3        # dispatched to bound (revenue)
        @test haskey(res, "custom_injection")
        @test res["custom_injection"]["p"] ≈ p_bat  rtol=1e-9

        # With custom_injection registered, profile_solution's balance closes:
        # no spurious W.SOL.POWER_BALANCE for the hook device.
        rep = profile_solution(net, res)
        @test !any(f.code == "W.SOL.POWER_BALANCE" for f in rep.findings)
        sol = rep.results[:solution]
        @test sol["p_custom_injection"] ≈ p_bat   rtol=1e-3

        # Negative control: a hook device NOT registered via custom_injection is
        # invisible to the balance and MUST trip W.SOL.POWER_BALANCE — proving the
        # registration is exactly what closes the balance.
        res2 = solve_opf(net; model_hook! = bat_model_hook!,
                              solution_hook! = (ctx, result) -> nothing)
        @test !haskey(res2, "custom_injection")
        rep2 = profile_solution(net, res2)
        @test any(f.code == "W.SOL.POWER_BALANCE" for f in rep2.findings)
    end

    @testset "T-STAGED: build_opf_model matches solve_opf (single snapshot)" begin
        # The staged API run as one snapshot must reproduce solve_opf exactly:
        # same construction/KCL/extract path, just unfused.
        net = _pu_net()
        fused = solve_opf(net)

        ctx = build_opf_model(net)
        enforce_kcl!(ctx)
        JuMP.optimize!(ctx.model)
        staged = extract_result(ctx)

        @test staged["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test staged["objective"] ≈ fused["objective"]  rtol=1e-8
        @test staged["bus"]["bus1"]["1"]["vm"] ≈ fused["bus"]["bus1"]["1"]["vm"]  rtol=1e-8
        @test staged["generator"]["g1"]["1"]["pg"] ≈ fused["generator"]["g1"]["1"]["pg"]  rtol=1e-8

        # add_objective=false leaves the model with no objective; generation_cost
        # returns the same expression solve_opf would have minimised.
        ctx2 = build_opf_model(net; add_objective=false)
        @test JuMP.objective_function(ctx2.model) == JuMP.AffExpr(0.0)  # unset ⇒ 0
        JuMP.@objective(ctx2.model, Min, generation_cost(ctx2))
        enforce_kcl!(ctx2)
        JuMP.optimize!(ctx2.model)
        staged2 = extract_result(ctx2)
        @test staged2["objective"] ≈ fused["objective"]  rtol=1e-8
    end

    @testset "T-MULTIPERIOD: SOC-coupled battery across two snapshots, one model" begin
        # Two snapshots co-optimised in ONE JuMP model with an inter-temporal
        # state-of-charge link — the formulation solve_opf cannot express. The
        # slack import price is high in period 1, low in period 2; a cyclic
        # battery must discharge into the expensive period and recharge in the
        # cheap one. Proves the staged public API supports storage/EV models.
        netj(src_cost) = """
        {"bus":{
            "sourcebus":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":     {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                         "v_min":[900.0],"v_max":[1100.0]}},
         "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0],"cost":[$src_cost]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
             "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[100000.0],"q_nom":[0.0]}}}
        """
        prices  = [0.20, 0.05]
        nets    = [parse_bmopf(netj(p); from_string=true) for p in prices]
        T       = length(nets)
        pmax_W  = 40_000.0
        emax_Wh = 100_000.0
        soc0_Wh = 40_000.0
        dt_h    = 1.0

        Pex = Dict{Int,Any}()
        port!(t) = ctx -> begin
            m = ctx.model
            vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
            sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
            crb = JuMP.@variable(m, base_name = "crb_t$t")
            cib = JuMP.@variable(m, base_name = "cib_t$t")
            P = JuMP.@expression(m, vr[("bus1","1")]*crb + vi[("bus1","1")]*cib)
            Q = JuMP.@expression(m, vi[("bus1","1")]*crb - vr[("bus1","1")]*cib)
            JuMP.@constraint(m, P <=  pmax_W / sb)
            JuMP.@constraint(m, P >= -pmax_W / sb)
            JuMP.@constraint(m, Q == 0.0)
            JuMP.add_to_expression!(ctx.kcl_r[("bus1","1")], crb)
            JuMP.add_to_expression!(ctx.kcl_i[("bus1","1")], cib)
            JuMP.add_to_expression!(ctx.kcl_r[("bus1","n")], -crb)
            JuMP.add_to_expression!(ctx.kcl_i[("bus1","n")], -cib)
            Pex[t] = P
        end

        model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(model)
        ctxs = [build_opf_model(nets[t]; model=model, add_objective=false,
                                model_hook! = port!(t)) for t in 1:T]
        sb = ctxs[1].bases.s_base
        Δpu(x) = x / sb

        JuMP.@variable(model, soc[1:T+1])
        JuMP.@constraint(model, soc[1] == Δpu(soc0_Wh))
        for t in 1:T
            JuMP.@constraint(model, soc[t+1] == soc[t] - Pex[t] * dt_h)
            JuMP.@constraint(model, 0.0 <= soc[t+1])
            JuMP.@constraint(model, soc[t+1] <= Δpu(emax_Wh))
        end
        JuMP.@constraint(model, soc[T+1] == Δpu(soc0_Wh))     # cyclic
        JuMP.@objective(model, Min,
            sum(dt_h * generation_cost(ctxs[t]) for t in 1:T))
        foreach(enforce_kcl!, ctxs)
        JuMP.optimize!(model)

        @test JuMP.termination_status(model) in (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)

        P1 = JuMP.value(Pex[1]) * sb
        P2 = JuMP.value(Pex[2]) * sb
        @test P1 ≈  pmax_W  rtol=1e-2      # discharge into the expensive period
        @test P2 ≈ -pmax_W  rtol=1e-2      # recharge in the cheap period

        soc_Wh = [JuMP.value(soc[k]) * sb for k in 1:T+1]
        @test soc_Wh[1] ≈ soc0_Wh  rtol=1e-6
        @test soc_Wh[T+1] ≈ soc0_Wh  rtol=1e-6         # cyclic closure
        for t in 1:T                                    # SOC dynamics conserved
            @test soc_Wh[t+1] ≈ soc_Wh[t] - (JuMP.value(Pex[t])*sb)*dt_h  rtol=1e-6
            @test -1.0 <= soc_Wh[t+1] <= emax_Wh + 1.0
        end

        # Per-snapshot extraction yields independent, in-band SI voltages.
        results = [extract_result(ctxs[t]) for t in 1:T]
        for t in 1:T
            @test 900.0 <= results[t]["bus"]["bus1"]["1"]["vm"] <= 1100.0
        end
    end

    @testset "T-STATE-EST: WLS state estimation via the staged API (different problem spec)" begin
        # The staged API is problem-agnostic: the same device physics underlies a
        # DIFFERENT problem specification — weighted-least-squares state estimation.
        # No operational bounds, no fixed loads, a measurement-residual objective.
        # This guards that build_opf_model(add_objective=false) + model_hook! can
        # host an estimator (bounds are added only where the net declares them,
        # so a bounds-free net yields a pure physics model with free voltages).

        # Ground truth from a determined power flow on a 3-bus resistive feeder.
        truejson = """
        {"bus":{
            "src": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus2":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{
            "l1":{"bus_from":"src","bus_to":"bus1","terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0},
            "l2":{"bus_from":"bus1","bus_to":"bus2","terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0}},
         "load":{
            "d1":{"bus":"bus1","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[20000.0],"q_nom":[0.0]},
            "d2":{"bus":"bus2","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[20000.0],"q_nom":[0.0]}}}
        """
        pf = solve_pf(parse_bmopf(truejson; from_string=true); per_unit=false)
        true_vm = Dict(b => hypot(pf["bus"][b]["1"]["vr"], pf["bus"][b]["1"]["vi"])
                       for b in ("bus1","bus2"))
        # Constant-power loads draw exactly nominal ⇒ injection = −20 kW, 0 var.
        true_pinj = Dict("bus1" => -20000.0, "bus2" => -20000.0)

        # Estimator net: physics only — source + lines, NO loads, NO limits.
        estjson = """
        {"bus":{
            "src": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "bus2":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.5}},
         "line":{
            "l1":{"bus_from":"src","bus_to":"bus1","terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0},
            "l2":{"bus_from":"bus1","bus_to":"bus2","terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0}}}
        """
        # meas :: Vector of (kind, bus, value, sigma), kind ∈ (:vm,:pinj,:qinj).
        function estimate(meas)
            est_net = parse_bmopf(estjson; from_string=true)
            buses = unique(b for (_, b, _, _) in meas)
            function wls!(ctx)
                m = ctx.model
                vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
                cr = Dict{String,Any}(); ci = Dict{String,Any}()
                for b in buses         # free injection so KCL closes; voltages stay free
                    cr[b] = JuMP.@variable(m, base_name="cinj_r_$b")
                    ci[b] = JuMP.@variable(m, base_name="cinj_i_$b")
                    JuMP.add_to_expression!(ctx.kcl_r[(b,"1")],  cr[b])
                    JuMP.add_to_expression!(ctx.kcl_i[(b,"1")],  ci[b])
                    JuMP.add_to_expression!(ctx.kcl_r[(b,"n")], -cr[b])
                    JuMP.add_to_expression!(ctx.kcl_i[(b,"n")], -ci[b])
                end
                obj = zero(JuMP.QuadExpr)
                for (kind, b, z, σ) in meas
                    w = 1.0 / σ^2; vrb = vr[(b,"1")]; vib = vi[(b,"1")]
                    if kind == :vm
                        r = JuMP.@expression(m, vrb^2 + vib^2 - z^2)
                        obj += (w / (2z)^2) * r^2
                    elseif kind == :pinj
                        obj += w * JuMP.@expression(m, vrb*cr[b] + vib*ci[b] - z)^2
                    elseif kind == :qinj
                        obj += w * JuMP.@expression(m, vib*cr[b] - vrb*ci[b] - z)^2
                    end
                end
                JuMP.@objective(m, Min, obj)
            end
            ctx = build_opf_model(est_net; per_unit=false, add_objective=false, model_hook! = wls!)
            enforce_kcl!(ctx)
            JuMP.optimize!(ctx.model)
            extract_result(ctx)
        end

        σv = 2.0; σp = 400.0
        mk(nz) = vcat([[(:vm, b, true_vm[b] + nz[b][1], σv),
                        (:pinj, b, true_pinj[b] + nz[b][2], σp),
                        (:qinj, b, 0.0 + nz[b][3], σp)] for b in ("bus1","bus2")]...)

        # (1) Noiseless measurements ⇒ estimate recovers the true state exactly.
        zero_nz = Dict(b => (0.0,0.0,0.0) for b in ("bus1","bus2"))
        res0 = estimate(mk(zero_nz))
        @test res0["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        for b in ("bus1","bus2")
            @test res0["bus"][b]["1"]["vm"] ≈ true_vm[b]  atol=1e-2
        end

        # (2) Fixed, deterministic perturbation ⇒ estimate stays within a few σ of
        # truth (graceful degradation; no reliance on an RNG in the suite).
        pert = Dict("bus1" => ( 1.5, -300.0, 0.0),
                    "bus2" => (-2.5,  350.0, 0.0))
        resN = estimate(mk(pert))
        @test resN["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        for b in ("bus1","bus2")
            @test abs(resN["bus"][b]["1"]["vm"] - true_vm[b]) <= 3σv
        end
    end

    @testset "T-WSTART: warm start honours a/b/c terminal naming" begin
        # Regression: canonical 120° start angles were keyed by the literal
        # names "1"/"2"/"3"; a bus using another convention (not covered by
        # the source's own terminal_map) started degenerately co-phasal.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":3.96e-4,"R_series_2_2":3.96e-4,
                           "R_series_3_3":3.96e-4,"R_series_4_4":3.96e-4}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["a","b","c","n"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["a","b","c","n"],"configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        init = res["initialisation"]["b1"]
        @test init["a"]["va_init"] ≈ 0.0      atol=1e-6
        @test init["b"]["va_init"] ≈ -2.0944  atol=1e-3
        @test init["c"]["va_init"] ≈  2.0944  atol=1e-3
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

        # Objective cost rate ($/h) must match; both should be ≈ -10.
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
            _strip_xfmr_ratings!(net)   # validates impedance/loss pu↔SI scaling, not the loading cap
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
             "v_nom_from":2400.0,"v_nom_to":240.0,"s_rating":50000.0,
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
             "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
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
             "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
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
             "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
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

    @testset "T13b2: center_tap internal neutral grounding (rneut/xneut) ≡ external shunt" begin
        # Supporting OpenDSS rneut/xneut on center_tap: the internal grounding branch
        # y_n = 1/(R_n+jX_n) from a winding neutral to earth must be identical to
        # grounding that terminal with an explicit external `shunt` of admittance y_n —
        # the "reify as an external shunt" equivalence a future data-cleanup would use.
        Rn, Xn = 2.0, 1.0
        yn = 1.0 / (Rn + Xn*im)
        Gn, Bn = real(yn), imag(yn)          # y_n = G_n + jB_n  (0.4 − 0.2j)

        # The centre-tap HV neutral is made to FLOAT: the source feeds `mv` through a
        # phase-only line (no neutral return), so the HV series current can only return
        # through the grounding branch. `r_neutral_from` then genuinely shifts the HV
        # neutral potential (a solidly-grounded neutral would sit at 0 V), exercising
        # the branch rather than leaving it redundant behind the transformer.
        top = """
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "mv":{"terminal_names":["1","n"]},
                "lv":{"terminal_names":["1","2","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[2400.0],"v_angle":[0.0]}},
         "line":{"ln":{"bus_from":"src","bus_to":"mv","terminal_map_from":["1"],"terminal_map_to":["1"],
             "linecode":"lc","length":100.0}},
         "linecode":{"lc":{"R_series_1_1":0.01,"X_series_1_1":0.02}},
         "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
             "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
             "r_series_from":0.1,"x_series_from":0.4,"r_series_to":0.001,"x_series_to":0.004__RNEUT__}}},
         "load":{"l1":{"bus":"lv","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[3000.0],"q_nom":[200.0]},
                 "l2":{"bus":"lv","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[1000.0],"q_nom":[100.0]}}__SHUNT__}
        """
        netA = parse_bmopf(replace(top,
            "__RNEUT__" => ",\"r_neutral_from\":$Rn,\"x_neutral_from\":$Xn",
            "__SHUNT__" => ""); from_string=true)
        netB = parse_bmopf(replace(top,
            "__RNEUT__" => "",
            "__SHUNT__" => ",\"shunt\":{\"gnd\":{\"bus\":\"mv\",\"terminal_map\":[\"n\"]," *
                           "\"G_1_1\":$Gn,\"B_1_1\":$Bn}}"); from_string=true)

        rA = solve_feasibility_opf(netA); rB = solve_feasibility_opf(netB)
        @test rA["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test rB["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # A (internal rneut) ≡ B (external shunt): identical bus voltages.
        for (bid, td) in rA["bus"], (t, tv) in td
            @test isapprox(rB["bus"][bid][t]["vm"], tv["vm"]; rtol=1e-6, atol=1e-6)
        end

        # The branch actually carries current: the floating HV neutral is displaced
        # from earth (a solidly-grounded neutral would sit at 0 V).
        @test rA["bus"]["mv"]["n"]["vm"] > 1.0
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
             "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
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
        # i_max = 0.03 A binds; the per-unit solve (this tiny current sits at
        # O(1e-8) p.u. against the 1 MVA base) satisfies it to ~3e-4 relative, so
        # allow a realistic per-unit convergence slack rather than a 1e-6 floor.
        @test cm <= 0.03 * (1 + 1e-3)
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
        #
        # This test is specifically about the SI-scale flat-start level mismatch:
        # solved per_unit=false so the flat start really does seed the LV bus at
        # the 6350 V source level (in per-unit mode, the default, the start is
        # ~1 p.u. everywhere and no mismatch arises — the profiler's detection is
        # then correctly silent, so there would be nothing to flag). We pin the SI
        # path here to keep the INIT_LEVEL_MISMATCH detection genuinely exercised.
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
             "v_nom_from":11000.0,"v_nom_to":400.0,
             "r_series_from":0.01,"r_series_to":0.0001,
             "x_series_from":0.05,"x_series_to":0.0005}}},
         "load":{"ld":{"bus":"lv","terminal_map":["a","b","c","n"],
             "configuration":"WYE",
             "p_nom":[5000.0,5000.0,5000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res    = solve_opf(net; per_unit=false)
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
    # T-INV1: Single-phase FOUR_LEG IBR — unconstrained Q (box bounds)
    #
    # A PV IBR sits at bus1 alongside a load. The IBR has p_max on
    # each phase so the augmentation pass fills in q_min/q_max at cos φ = 0.90.
    # The OPF minimises slack cost so it maximises the (cheaper) IBR
    # dispatch. All three phases are symmetric → each phase decouples.
    #
    # With p_max = 3000 W/phase, p_nom_load = 2000 W/phase and the IBR
    # cost < slack cost, the OPF should dispatch the IBR at p_avail and
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
             "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
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

    @testset "T-INV1: FOUR_LEG IBR, box Q bounds via augmentation" begin
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
         "ibr":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
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

        # Augmentation should have added q_min/q_max to the IBR
        inv = net′["ibr"]["pv1"]
        @test haskey(inv, "q_max")
        @test inv["q_max"][1] ≈ 3000.0 * tan(acos(0.90))   rtol=1e-6

        res = solve_opf(net′)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test haskey(res, "ibr")
        @test haskey(res["ibr"], "pv1")
        # IBR should dispatch close to p_max on each phase (cheaper than slack)
        for t in ("1","2","3")
            @test res["ibr"]["pv1"][t]["pg"] ≈ 3000.0   atol=1.0
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV2: Constant power-factor equality constraint
    #
    # A FOUR_LEG PV IBR with a power_factor control profile (pf = 0.9,
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
         "ibr":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
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
        @test !haskey(net′["ibr"]["pv1"], "q_min")

        res = solve_opf(net′)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        for t in ("1","2","3")
            pg = res["ibr"]["pv1"][t]["pg"]
            qg = res["ibr"]["pv1"][t]["qg"]
            # PF equality: Q = -tan_phi * P  (pf > 0 → lagging → absorbing VAr)
            @test qg ≈ -tan_phi * pg   atol=0.1
        end

        # solution_check must not flag PF deviation
        f = Finding[]
        solution_check(net′, res, f)
        @test !any(f_ -> f_.code == "W.SOL.IBR_PF_DEVIATION", f)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV3: s_max circle is binding
    #
    # IBR with p_max = s_max * pf (exactly on the circle boundary).
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
         "ibr":{"pv1":{"bus":"b1","terminal_map":["1","n"],
             "topology":"SINGLE_PHASE","prime_mover":"PV",
             "s_max":[3000.0],"p_max":[2700.0],"p_min":[0.0],
             "control_profile":"pf09","cost":[0.1]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg = res["ibr"]["pv1"]["1"]["pg"]
        qg = res["ibr"]["pv1"]["1"]["qg"]
        sm = sqrt(pg^2 + qg^2)
        @test sm <= s_max_k * 1.001   # within 0.1 % of nameplate
        @test pg <= p_max_k * 1.001
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV4: per-unit mode parity for IBRs
    #
    # Regression guard for the IBR per-unit gap: _to_per_unit must scale
    # the IBR's p/q/s bounds by s_base and _from_per_unit must scale the
    # cri/cii/pg/qg results back to SI. The SI-mode and PU-mode solves of the
    # same network must agree on the reported IBR dispatch (pg/qg) and
    # currents (cri/cii). Without the scalers the PU-mode bounds are applied at
    # 1e6× the intended tightness and the results come out in a hybrid scale.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV4: per-unit mode matches SI mode for IBRs" begin
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
         "ibr":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
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
            si = res_si["ibr"]["pv1"][t]
            pu = res_pu["ibr"]["pv1"][t]
            @test pu["pg"]  ≈ si["pg"]   rtol=1e-4
            @test pu["qg"]  ≈ si["qg"]   atol=1.0
            @test pu["cri"] ≈ si["cri"]  rtol=1e-4 atol=1e-3
            @test pu["cii"] ≈ si["cii"]  rtol=1e-4 atol=1e-3
            # Sanity: PU-mode dispatch is in SI watts, near p_max (cheaper than slack)
            @test pu["pg"] ≈ 2700.0   atol=5.0
        end
        # Cost coefficients on both the source and IBR must scale with s_base;
        # otherwise the PU solve has a different economic objective even if this
        # simple merit order happens to return the same dispatch.
        @test res_pu["objective"] ≈ res_si["objective"] rtol=1e-4
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV5: optional i_max current limit binds (STATCOM-like IBR)
    #
    # A pure-reactive IBR (p_min=p_max=0, generous s_max) supplies a lagging
    # reactive load across a lossy line, with an expensive slack so the optimum
    # wants to source the reactive demand locally. We first solve WITHOUT i_max
    # to measure the free current magnitude, then set i_max to 60 % of it and
    # re-solve. The current circle cri²+cii² ≤ i_max² must bind (|I| ≈ i_max),
    # the reactive output must drop, and the s_max circle must NOT be what limits.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV5: i_max current limit binds" begin
        mknet() = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[100.0,100.0,100.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,
             "X_series_1_1":0.05,"X_series_2_2":0.05,"X_series_3_3":0.05}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[4000.0,4000.0,4000.0]}},
         "ibr":{"st1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"GENERIC",
             "s_max":[8000.0,8000.0,8000.0],
             "p_min":[0.0,0.0,0.0],"p_max":[0.0,0.0,0.0],
             "q_min":[-8000.0,-8000.0,-8000.0],"q_max":[8000.0,8000.0,8000.0],
             "cost":[0.0,0.0,0.0]}}}
        """; from_string=true)

        imag(v) = sqrt(v["cri"]^2 + v["cii"]^2)

        # Free solve (no i_max) to measure the unconstrained current.
        res_free = solve_opf(mknet())
        @test res_free["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        I_free = imag(res_free["ibr"]["st1"]["1"])
        @test I_free > 1.0   # the IBR actually sources reactive power

        # Constrained solve: cap current at 60 % of the free magnitude.
        ilim   = 0.6 * I_free
        net_lim = mknet()
        net_lim["ibr"]["st1"]["i_max"] = [ilim, ilim, ilim]
        res_lim = solve_opf(net_lim)
        @test res_lim["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        for t in ("1","2","3")
            v = res_lim["ibr"]["st1"][t]
            I = imag(v)
            @test I ≈ ilim                       rtol=1e-3   # current circle binds
            @test I < imag(res_free["ibr"]["st1"][t]) * 0.95 # tighter than free
            @test abs(v["qg"]) < abs(res_free["ibr"]["st1"][t]["qg"])  # less Q delivered
            @test sqrt(v["pg"]^2 + v["qg"]^2) < 8000.0 * 0.9          # s_max not binding
        end

        # Opt-in guarantee: a generously large (non-binding) i_max reproduces the
        # free solve byte-for-byte in dispatch.
        net_big = mknet()
        net_big["ibr"]["st1"]["i_max"] = [1e6, 1e6, 1e6]
        res_big = solve_opf(net_big)
        for t in ("1","2","3")
            @test res_big["ibr"]["st1"][t]["qg"] ≈ res_free["ibr"]["st1"][t]["qg"]  atol=1.0
        end

        # Solution validator must NOT flag a current violation for the i_max solve.
        sfindings = Finding[]
        solution_check(net_lim, res_lim, sfindings)
        @test !any(f -> f.code == "E.SOL.IBR_VIOLATION", sfindings)

        # ...but a current that exceeds a tightened i_max IS flagged post-hoc.
        net_post = mknet()
        net_post["ibr"]["st1"]["i_max"] = [ilim, ilim, ilim]
        sf2 = Finding[]
        solution_check(net_post, res_free, sf2)   # res_free violates the tight i_max
        @test any(f -> f.code == "E.SOL.IBR_VIOLATION" &&
                       occursin("i_max", f.message), sf2)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-INV6: per-unit parity with i_max (guards the i_base scaling)
    #
    # Same network with a binding i_max solved in SI and PU modes must report
    # the same dispatch and currents. _pu_scale_ibrs! scales i_max by the per-bus
    # current base i_base = s_base / v_base; without it the PU current circle is
    # applied at the wrong tightness.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-INV6: per-unit parity with i_max" begin
        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[100.0,100.0,100.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,
             "X_series_1_1":0.05,"X_series_2_2":0.05,"X_series_3_3":0.05}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[4000.0,4000.0,4000.0]}},
         "ibr":{"st1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "topology":"FOUR_LEG","prime_mover":"GENERIC",
             "s_max":[8000.0,8000.0,8000.0],"i_max":[8.0,8.0,8.0],
             "p_min":[0.0,0.0,0.0],"p_max":[0.0,0.0,0.0],
             "q_min":[-8000.0,-8000.0,-8000.0],"q_max":[8000.0,8000.0,8000.0],
             "cost":[0.0,0.0,0.0]}}}
        """; from_string=true)

        res_si = solve_opf(net; per_unit=false)
        res_pu = solve_opf(net; per_unit=true, s_base=1e6)
        @test res_si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        for t in ("1","2","3")
            si = res_si["ibr"]["st1"][t]
            pu = res_pu["ibr"]["st1"][t]
            @test pu["cri"] ≈ si["cri"]  rtol=5e-3 atol=1e-2
            @test pu["cii"] ≈ si["cii"]  rtol=5e-3 atol=1e-2
            @test pu["qg"]  ≈ si["qg"]   rtol=5e-3 atol=5.0
            # The current circle binds at i_max = 8 A in both modes.
            @test sqrt(si["cri"]^2 + si["cii"]^2) ≈ 8.0  rtol=5e-3
            @test sqrt(pu["cri"]^2 + pu["cii"]^2) ≈ 8.0  rtol=5e-3
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-GEN-IMAX: optional generator i_max current limit binds.
    #
    # A cheap (profit-seeking) generator wants to inject as much active power as
    # its p_max allows across a lossy line to an expensive slack. We first solve
    # WITHOUT i_max to measure the free current, then cap i_max at 60 % of it and
    # re-solve. The current circle crg²+cig² ≤ i_max² must bind (|I| ≈ i_max) and
    # the injected power must drop. A generously large i_max reproduces the free
    # dispatch; the solution validator flags a post-hoc i_max breach.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-GEN-IMAX: generator i_max current limit binds" begin
        mknet() = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[100.0,100.0,100.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,
             "X_series_1_1":0.05,"X_series_2_2":0.05,"X_series_3_3":0.05}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[3000.0,3000.0,3000.0],"q_nom":[0.0,0.0,0.0]}},
         "generator":{"g1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_min":[0.0,0.0,0.0],"p_max":[5000.0,5000.0,5000.0],
             "q_min":[-5000.0,-5000.0,-5000.0],"q_max":[5000.0,5000.0,5000.0],
             "cost":[-0.05,-0.05,-0.05]}}}
        """; from_string=true)

        imag(v) = sqrt(v["crg"]^2 + v["cig"]^2)

        res_free = solve_opf(mknet())
        @test res_free["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        I_free = imag(res_free["generator"]["g1"]["1"])
        @test I_free > 1.0

        ilim    = 0.6 * I_free
        net_lim = mknet()
        net_lim["generator"]["g1"]["i_max"] = [ilim, ilim, ilim]
        res_lim = solve_opf(net_lim)
        @test res_lim["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        for t in ("1","2","3")
            v = res_lim["generator"]["g1"][t]
            @test imag(v) ≈ ilim                                  rtol=1e-3
            @test imag(v) < imag(res_free["generator"]["g1"][t]) * 0.95
            @test v["pg"] < res_free["generator"]["g1"][t]["pg"]
        end

        # Opt-in: a non-binding i_max reproduces the free dispatch.
        net_big = mknet()
        net_big["generator"]["g1"]["i_max"] = [1e6, 1e6, 1e6]
        res_big = solve_opf(net_big)
        for t in ("1","2","3")
            @test res_big["generator"]["g1"][t]["pg"] ≈
                  res_free["generator"]["g1"][t]["pg"]  atol=1.0
        end

        # Validator: no violation for the i_max solve; a breach IS flagged.
        sf1 = Finding[]
        solution_check(net_lim, res_lim, sf1)
        @test !any(f -> f.code == "E.SOL.GEN_VIOLATION", sf1)

        net_post = mknet()
        net_post["generator"]["g1"]["i_max"] = [ilim, ilim, ilim]
        sf2 = Finding[]
        solution_check(net_post, res_free, sf2)
        @test any(f -> f.code == "E.SOL.GEN_VIOLATION" &&
                       occursin("i_max", f.message), sf2)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T-GEN-IMAX-PU: per-unit parity for generator i_max (guards i_base scaling).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-GEN-IMAX-PU: per-unit parity with generator i_max" begin
        net = parse_bmopf("""
        {"bus":{
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],
             "v_angle":[0.0,-2.0944,2.0944],"cost":[100.0,100.0,100.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,
             "X_series_1_1":0.05,"X_series_2_2":0.05,"X_series_3_3":0.05}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_nom":[3000.0,3000.0,3000.0],"q_nom":[0.0,0.0,0.0]}},
         "generator":{"g1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "configuration":"WYE",
             "p_min":[0.0,0.0,0.0],"p_max":[5000.0,5000.0,5000.0],
             "q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],
             "i_max":[8.0,8.0,8.0],"cost":[-0.05,-0.05,-0.05]}}}
        """; from_string=true)

        res_si = solve_opf(net; per_unit=false)
        res_pu = solve_opf(net; per_unit=true, s_base=1e6)
        @test res_si["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        for t in ("1","2","3")
            si = res_si["generator"]["g1"][t]
            pu = res_pu["generator"]["g1"][t]
            @test pu["crg"] ≈ si["crg"]  rtol=5e-3 atol=1e-2
            @test pu["cig"] ≈ si["cig"]  rtol=5e-3 atol=1e-2
            @test pu["pg"]  ≈ si["pg"]   rtol=5e-3 atol=5.0
            @test sqrt(si["crg"]^2 + si["cig"]^2) ≈ 8.0  rtol=5e-3
            @test sqrt(pu["crg"]^2 + pu["cig"]^2) ≈ 8.0  rtol=5e-3
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
         "linecode":{"lc":{"R_series_1_1":1.0e-4,"R_series_2_2":1.0e-4,"R_series_3_3":1.0e-4,
             "R_series_4_4":1.0e-4}},
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
         "linecode":{"lc":{"R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5,"R_series_4_4":0.5,
             "X_series_1_1":0.5,"X_series_2_2":0.5,"X_series_3_3":0.5,"X_series_4_4":0.5}},
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
    # the objective is the deterministic cost rate Σ cost_k · P_k/1000:
    #   0.1·10 + 0.2·20 + 0.3·30 = 14 $/h.
    # The old polynomial reading ([c2,c1,c0]) would have applied a single c1 to
    # every phase (0.2·60 = 12 $/h), so this value distinguishes the two.
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
        @test res["objective"] ≈ 14.0   atol=1e-3
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

    # ─────────────────────────────────────────────────────────────────────────
    # T-NANOBJ: an infeasible solve must report objective = NaN, never the
    # stale candidate-point value the solver stopped at (regression — the
    # objective used to be read before the feasibility check).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T-NANOBJ: infeasible solve reports NaN objective" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                   "v_min":[240.0,240.0,240.0],"v_max":[250.0,250.0,250.0]}},
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
        # b1 must sit above 240 V while the source is fixed at 230 V and the
        # load only drops voltage — infeasible by construction.
        res = solve_opf(net)
        @test res["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")
        @test isnan(res["objective"])
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
    # PF5b: INLINE line limits are ignored too (issue #354). An inline i_max /
    # s_max on the line dict overrides the linecode's in the OPF (branch.jl),
    # so the PF must strip the line component itself, not just linecodes.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF5b: inline line i_max/s_max are ignored by solve_pf (#354)" begin
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
             "linecode":"lc","length":1.0,
             "i_max":[1.0e-3],"s_max":[1.0e-3]}},
         "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[100000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_pf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["line"]["l1"]["1"]["cm_fr"] > 1.0
        # The caller's net must be untouched.
        @test net["line"]["l1"]["i_max"] == [1.0e-3]
        @test net["line"]["l1"]["s_max"] == [1.0e-3]
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF5c: the strip contract, unit-tested — line and dc_branch limit fields
    # are removed; generator p_min/p_max are NOT (they are the PF's fixed
    # setpoint, not an operational limit).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF5c: _strip_operational_limits! covers line + dc_branch, keeps gen setpoints" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        net = Dict{String,Any}(
            "linecode"  => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.5, "i_max" => [10.0], "s_max" => [1.0e4])),
            "line"      => Dict{String,Any}("l1" => Dict{String,Any}(
                "linecode" => "lc", "i_max" => [10.0], "s_max" => [1.0e4])),
            "switch"    => Dict{String,Any}("sw" => Dict{String,Any}("i_max" => [10.0])),
            "generator" => Dict{String,Any}("g1" => Dict{String,Any}(
                "i_max" => [10.0], "s_max" => [1.0e4],
                "p_min" => [5.0e3], "p_max" => [5.0e3])),
            "dc_branch" => Dict{String,Any}("dcb" => Dict{String,Any}(
                "r" => 0.1, "i_max" => [10.0], "p_max" => 1.0e4)),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "t1" => Dict{String,Any}(
                    "i_max_from" => [10.0], "i_max_to" => [100.0],
                    "s_rating" => 5.0e4))))
        ext._strip_operational_limits!(net)

        for (comp, fields) in (net["linecode"]["lc"]        => ("i_max", "s_max"),
                               net["line"]["l1"]            => ("i_max", "s_max"),
                               net["switch"]["sw"]          => ("i_max",),
                               net["generator"]["g1"]       => ("i_max", "s_max"),
                               net["dc_branch"]["dcb"]      => ("i_max", "p_max"),
                               net["transformer"]["single_phase"]["t1"] =>
                                   ("i_max_from", "i_max_to"))
            for f in fields
                @test !haskey(comp, f)
            end
        end
        # Fixed generator setpoints survive; the transformer nameplate contract
        # (always enforced) survives.
        @test net["generator"]["g1"]["p_min"] == [5.0e3]
        @test net["generator"]["g1"]["p_max"] == [5.0e3]
        @test net["transformer"]["single_phase"]["t1"]["s_rating"] == 5.0e4
    end

    # ─────────────────────────────────────────────────────────────────────────
    # PF5d: the s_rating exception, pinned both ways (issue #355). The nameplate
    # coil cap IS enforced in a power flow — a load beyond s_rating is
    # LOCALLY_INFEASIBLE, not an overload report — and deleting s_rating from
    # the input net is the documented escape hatch.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "PF5d: transformer s_rating stays enforced in solve_pf (#355)" begin
        mknet() = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lv": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[1000.0],"v_angle":[0.0]}},
         "transformer":{"single_phase":{"t1":{
             "bus_from":"src","bus_to":"lv",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "v_nom_from":1000.0,"v_nom_to":1000.0,"s_rating":5000.0,
             "r_series_from":0.05,"x_series_from":0.1}}},
         "load":{"ld1":{"bus":"lv","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE",
             "p_nom":[10000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        # 10 kW load through a 5 kVA nameplate: the coil cap binds → infeasible.
        res = solve_pf(mknet())
        @test res["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")

        # The documented escape hatch: delete s_rating → the same PF solves and
        # reports the overloaded state.
        net = mknet()
        delete!(net["transformer"]["single_phase"]["t1"], "s_rating")
        res2 = solve_pf(net)
        @test res2["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test sum(ph["pd"] for ph in values(res2["load"]["ld1"])) ≈ 10000.0  rtol=1e-3
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
             "v_nom_from":2400.0,"v_nom_to":240.0,"s_rating":50000.0,
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
             "v_nom_from":4160.0,"v_nom_to":240.0,"s_rating":50000.0,
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

    # ─────────────────────────────────────────────────────────────────────────
    # CAP-EQ: the fix-recipe shunt→capacitor conversion is electrically lossless.
    # Solve the SAME feeder twice — once with the capacitive phase-to-ground
    # shunt, once after `apply_shunt_to_capacitor` re-represents it as a WYE
    # capacitor — and assert an identical operating point. This proves the
    # conversion preserves the physics in the actual OPF (the grounded neutral's
    # free ground current absorbs the capacitor's neutral-row current).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "CAP-EQ: shunt→capacitor conversion preserves the solution" begin
        netdict = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"],
                    "v_min" => [200.0,200.0,200.0])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c"],
                "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
                "X_series_1_1" => 0.3, "X_series_2_2" => 0.3, "X_series_3_3" => 0.3)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"],
                "linecode" => "lc", "length" => 1.0)),
            "shunt" => Dict{String,Any}("cap1" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a","b","c"],
                "B_1_1" => 5e-4, "B_2_2" => 5e-4, "B_3_3" => 5e-4)))

        res_shunt = solve_opf(deepcopy(netdict))
        @test res_shunt["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        net_cap, _ = fix_case(deepcopy(netdict); recipe = FixRecipe(
            apply_largest_component=false, apply_simplify_network=false,
            apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
            apply_source_bus_bounds=false, apply_shunt_to_capacitor=true))
        @test haskey(net_cap["capacitor"], "cap_cap1")
        @test !haskey(get(net_cap, "shunt", Dict()), "cap1")

        res_cap = solve_opf(net_cap)
        @test res_cap["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # Identical operating point at the bus carrying the converted element.
        for t in ("a","b","c")
            @test res_cap["bus"]["b1"][t]["vr"] ≈ res_shunt["bus"]["b1"][t]["vr"]  atol=1e-3
            @test res_cap["bus"]["b1"][t]["vi"] ≈ res_shunt["bus"]["b1"][t]["vi"]  atol=1e-3
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # CAP-EQ-CFG: the B-matrix fingerprinting recovers each capacitor config
    # (SINGLE_PHASE / WYE / DELTA) and the converted network solves to the same
    # operating point as the original capacitive shunt.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "CAP-EQ-CFG: fingerprinted conversion — all configs" begin
        base() = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"],
                    "v_min" => [200.0,200.0,200.0])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c"],
                "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
                "X_series_1_1" => 0.3, "X_series_2_2" => 0.3, "X_series_3_3" => 0.3)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"],
                "linecode" => "lc", "length" => 1.0)))

        # (config, shunt terminal_map, upper-triangular B keys)
        cases = [
            ("SINGLE_PHASE", ["a","b"],
             Dict{String,Any}("B_1_1"=>5e-4, "B_2_2"=>5e-4, "B_1_2"=>-5e-4)),
            ("DELTA", ["a","b","c"],
             Dict{String,Any}("B_1_1"=>1e-3, "B_2_2"=>1e-3, "B_3_3"=>1e-3,
                              "B_1_2"=>-5e-4, "B_2_3"=>-5e-4, "B_1_3"=>-5e-4)),
            ("WYE", ["a","b","c","n"],
             Dict{String,Any}("B_1_1"=>5e-4, "B_2_2"=>5e-4, "B_3_3"=>5e-4,
                              "B_4_4"=>1.5e-3, "B_1_4"=>-5e-4, "B_2_4"=>-5e-4,
                              "B_3_4"=>-5e-4)),
        ]

        for (cfg, tm, bkeys) in cases
            net = base()
            net["shunt"] = Dict{String,Any}("sh" => merge(
                Dict{String,Any}("bus" => "b1", "terminal_map" => tm), bkeys))

            res_shunt = solve_opf(deepcopy(net))
            @test res_shunt["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

            net_cap, _ = fix_case(deepcopy(net); recipe = FixRecipe(
                apply_largest_component=false, apply_simplify_network=false,
                apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
                apply_source_bus_bounds=false, apply_shunt_to_capacitor=true))
            @test haskey(get(net_cap, "capacitor", Dict()), "cap_sh")
            @test net_cap["capacitor"]["cap_sh"]["configuration"] == cfg
            @test !haskey(get(net_cap, "shunt", Dict()), "sh")

            res_cap = solve_opf(net_cap)
            @test res_cap["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            for t in ("a","b","c")
                @test res_cap["bus"]["b1"][t]["vr"] ≈ res_shunt["bus"]["b1"][t]["vr"]  atol=1e-3
                @test res_cap["bus"]["b1"][t]["vi"] ≈ res_shunt["bus"]["b1"][t]["vi"]  atol=1e-3
            end
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # STATCOM on an unbalanced four-wire LV feeder: reactive-only vs. active
    # power circulation (DC-link coupling). In LV networks R≫X, so reactive
    # support has weak voltage authority while active power redistribution
    # between phases (∑ₖ Pₖ = 0) directly balances the feeder.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "STATCOM DC-link active circulation vs reactive-only" begin
        # Resistive (R/X = 5) four-wire LV feeder; phase 1 heavily loaded.
        feeder(vmin) = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]$vmin}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.4,"X_series_1_1":0.08,
                           "R_series_2_2":0.4,"X_series_2_2":0.08,
                           "R_series_3_3":0.4,"X_series_3_3":0.08,
                           "R_series_4_4":0.4,"X_series_4_4":0.08}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[18000.0,3000.0,3000.0],"q_nom":[2000.0,500.0,500.0]}}}
        """; from_string=true)

        solved(r) = r["termination_status"] in
            ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
        function vuf(r, bus)
            b = r["bus"][bus]
            V = [b[t]["vr"] + im*b[t]["vi"] for t in ("1","2","3")]
            a = exp(im*2pi/3)
            V1 = (V[1] + a*V[2] + a^2*V[3]) / 3
            V2 = (V[1] + a^2*V[2] + a*V[3]) / 3
            abs(V2) / abs(V1) * 100
        end

        # Unconstrained voltages: both no-STATCOM and active-circulation solve;
        # active circulation strictly improves unbalance and losses.
        base = feeder("")
        r0   = solve_opf(deepcopy(base))
        @test solved(r0)

        nact = deepcopy(base)
        add_statcom!(nact, "b1"; s_max = 15000.0, dc_link_coupled = true)
        @test nact["ibr"]["statcom_b1"]["dc_link_coupled"] == true
        nact, _ = augment_case(nact)
        @test nact["ibr"]["statcom_b1"]["p_min"] ≈ [-15000.0, -15000.0, -15000.0]
        @test nact["ibr"]["statcom_b1"]["p_max"] ≈ [ 15000.0,  15000.0,  15000.0]
        @test nact["ibr"]["statcom_b1"]["p_dc_min"] == 0.0
        @test nact["ibr"]["statcom_b1"]["p_dc_max"] == 0.0
        ract = solve_opf(nact)
        @test solved(ract)

        # The DC-link balances the net active power to zero...
        ph = ract["ibr"]["statcom_b1"]
        sumP = sum(ph[t]["pg"] for t in ("1","2","3"))
        @test isapprox(sumP, 0.0; atol = 1.0)
        # ...and the converter sources active power on the heavy phase.
        @test ph["1"]["pg"] > 1000.0
        # Unbalance and losses both fall sharply.
        @test vuf(ract, "b1") < vuf(r0, "b1")
        @test vuf(ract, "b1") < 0.5
        @test ract["losses"]["p_loss"] < r0["losses"]["p_loss"]

        # With a per-phase voltage limit the heavy phase cannot be held up by
        # reactive support at any rating (R≫X), but active circulation can.
        bounded = feeder(""","v_min":[218.0,218.0,218.0],"v_max":[253.0,253.0,253.0]""")

        nreact = deepcopy(bounded)
        add_statcom!(nreact, "b1"; s_max = 30000.0)            # reactive-only
        nreact, _ = augment_case(nreact)
        @test nreact["ibr"]["statcom_b1"]["p_max"] == [0.0, 0.0, 0.0]
        @test !solved(solve_opf(nreact))                       # infeasible

        nactb = deepcopy(bounded)
        add_statcom!(nactb, "b1"; s_max = 30000.0, dc_link_coupled = true)
        nactb, _ = augment_case(nactb)
        @test solved(solve_opf(nactb))                         # feasible
    end

    # ─────────────────────────────────────────────────────────────────────────
    # TAP: Continuous free transformer tap (OLTC / regulator) optimisation.
    #
    # A free tap is a single decision variable equal to the effective from→to
    # ratio coefficient the winding constraints multiply (N for single_phase,
    # n_eff otherwise). These tests exercise the SAME constraint code as the
    # fixed-tap model — only the coefficient is promoted to a variable — so they
    # validate the math model directly. The crucial guarantee is "internal
    # exactness": re-solving with the tap FIXED to the optimiser's value t* must
    # reproduce the free-tap solution to solver tolerance.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TAP: continuous transformer tap optimisation" begin
        # 11 kV / 240 V, 50 kVA single-phase YY (matches the OpenDSS fixture).
        zbf = 11_000.0^2 / 50_000.0
        zbt =    240.0^2 / 50_000.0
        function net_1ph(; tapf::String="", vbounds::String="", pload=40_000.0)
            parse_bmopf("""
            {"bus":{
                "hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]$vbounds}},
             "voltage_source":{"src":{"bus":"hv","terminal_map":["1"],
                 "v_magnitude":[11000.0],"v_angle":[0.0],"cost":[1.0]}},
             "load":{"ld":{"bus":"lv","terminal_map":["1","n"],
                 "configuration":"SINGLE_PHASE","p_nom":[$pload],"q_nom":[10000.0]}},
             "transformer":{"single_phase":{"t1":{
                 "bus_from":"hv","bus_to":"lv",
                 "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
                 "v_nom_from":11000.0,"v_nom_to":240.0,"s_rating":50000.0,
                 "r_series_from":$(0.01*zbf),"x_series_from":$(0.04*zbf),
                 "r_series_to":$(0.01*zbt),"x_series_to":0.0$tapf}}}}
            """; from_string=true)
        end
        vlv(r) = sqrt(r["bus"]["lv"]["1"]["vr"]^2 + r["bus"]["lv"]["1"]["vi"]^2)

        # (a) Backward compatibility: absent tap ≡ fixed tap = 1.0 (no tap variable
        #     reported), and the solution is unchanged.
        r_none = solve_opf(net_1ph())
        r_one  = solve_opf(net_1ph(tapf=""","tap":1.0"""))
        @test r_none["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test !haskey(r_none["transformer"]["t1"], "tap")
        @test vlv(r_one) ≈ vlv(r_none) atol=1e-6

        # (b) Free tap is feasible, lands inside its bounds, and is reported.
        free = ""","tap":1.0,"tap_min":0.9,"tap_max":1.1"""
        vb   = ""","v_min":[238.0],"v_max":[250.0]"""
        rfree = solve_opf(net_1ph(tapf=free, vbounds=vb))
        @test rfree["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        tstar = rfree["transformer"]["t1"]["tap"]
        @test 0.9 - 1e-6 <= tstar <= 1.1 + 1e-6
        @test haskey(rfree["transformer"]["t1"], "tap_binding")
        @test 238.0 - 1e-3 <= vlv(rfree) <= 250.0 + 1e-3

        # (c) Internal exactness: fix the tap to t* → identical voltages & tap is
        #     no longer a variable. This is what ties the free model to the
        #     OpenDSS-validated fixed model.
        rfix = solve_opf(net_1ph(tapf=""","tap":$tstar""", vbounds=vb))
        @test !haskey(rfix["transformer"]["t1"], "tap")
        @test vlv(rfix) ≈ vlv(rfree) atol=1e-6

        # (d) Closed-form lossless regulator: with zero impedance the tap is the
        #     pure ratio, so V_to = V_from / (N0·t). A v_min/v_max window pins |V_to|
        #     and the optimiser must pick t = V_from / (N0 · V_to_target).
        function net_ideal(target)
            parse_bmopf("""
            {"bus":{
                "hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                      "v_min":[$(target-0.05)],"v_max":[$(target+0.05)]}},
             "voltage_source":{"src":{"bus":"hv","terminal_map":["1"],
                 "v_magnitude":[11000.0],"v_angle":[0.0],"cost":[1.0]}},
             "load":{"ld":{"bus":"lv","terminal_map":["1","n"],
                 "configuration":"SINGLE_PHASE","p_nom":[5000.0],"q_nom":[0.0]}},
             "transformer":{"single_phase":{"t1":{
                 "bus_from":"hv","bus_to":"lv",
                 "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
                 "v_nom_from":11000.0,"v_nom_to":240.0,"s_rating":50000.0,
                 "tap":1.0,"tap_min":0.85,"tap_max":1.15}}}}
            """; from_string=true)
        end
        r_id = solve_opf(net_ideal(245.0))
        @test r_id["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        # Lossless: V_to = V_from/(N0·t) with N0 = 11000/240 and V_from = 11000, so
        # t = V_from·v_nom_to/(v_nom_from·V_to) = 240/245 to hold |V_to| ≈ 245 V.
        @test r_id["transformer"]["t1"]["tap"] ≈ (240.0 / 245.0) rtol=2e-3
        @test r_id["bus"]["lv"]["1"]["vm"] ≈ 245.0 atol=0.06

        # (e) Per-unit and SI solves agree on the optimised tap and voltages. The
        #     reported tap is dimensionless (recovered from the effective coefficient
        #     via N0 of the SAME working net), so it is scale-invariant.
        nfree = net_1ph(tapf=free, vbounds=vb)
        rsi = solve_opf(nfree; per_unit=false)
        rpu = solve_opf(nfree; per_unit=true)
        @test rsi["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test rpu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test rsi["transformer"]["t1"]["tap"] ≈ rpu["transformer"]["t1"]["tap"] atol=1e-4
        @test vlv(rsi) ≈ vlv(rpu) atol=1e-3

        # (f) Lossless transformer (R=X=0): the free tap still solves — the voltage
        #     constraint collapses to the ideal V_fr = N·V_to with N a variable.
        nll = net_1ph(tapf=free, vbounds=vb)
        t = nll["transformer"]["single_phase"]["t1"]
        t["r_series_from"] = 0.0; t["x_series_from"] = 0.0; t["r_series_to"] = 0.0
        rll = solve_opf(nll)
        @test rll["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test 0.9 - 1e-6 <= rll["transformer"]["t1"]["tap"] <= 1.1 + 1e-6
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T15: Optimization profile — the solution "fingerprint" attached by the
    # BMOPFOpfExt profiler (ext/BMOPFOpfExt/profile.jl). A negative-cost generator
    # is driven to p_max on all three phases, so exactly those three dispatch
    # upper bounds are active at the optimum — a case that MUST bind.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T15: optimization profile — DOF, active set, complementarity" begin
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

        res = solve_opf(net)   # default per_unit=true
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test haskey(res, "opt_profile")
        p = res["opt_profile"]

        # counts / degrees of freedom
        @test p["n_variables"] isa Int && p["n_variables"] > 0
        @test p["n_eq_constraints"] isa Int && p["n_eq_constraints"] > 0
        @test p["n_ineq_constraints"] isa Int && p["n_ineq_constraints"] > 0
        @test p["degrees_of_freedom"] == p["n_variables"] - p["n_eq_constraints"]
        @test p["degrees_of_freedom"] > 0

        # solver-reported effort
        @test p["barrier_iterations"] isa Int && p["barrier_iterations"] > 0
        @test p["solve_time_s"] isa Real && p["solve_time_s"] >= 0
        @test p["units"] == "per_unit"

        # dual-based active set: the three generator p_max bounds must bind, each
        # with a strictly positive multiplier (non-degenerate).
        @test p["has_duals"] == true
        @test p["n_active"] isa Int && p["n_active"] >= 3
        @test p["n_weakly_active"] == 0
        @test p["strict_complementarity"] == true
        @test p["min_active_multiplier"] isa Real && p["min_active_multiplier"] > 0
        @test p["max_shadow_price"] >= p["min_active_multiplier"]

        # profile_solution surfaces it and derives the flags
        rep = profile_solution(net, res)
        o = rep.results[:optimization]
        @test o["available"] == true
        @test o["is_opf"] == true          # something binds → a genuine OPF
        @test o["degenerate"] == false     # strict complementarity holds

        # render_solution includes the section
        io = IOBuffer()
        render_solution(rep, io)
        @test occursin("Optimization Profile", String(take!(io)))
    end

    # ─────────────────────────────────────────────────────────────────────────
    # T16: Interior optimum — no operational constraint binds, so the case is
    # effectively a power-flow instance and `is_opf` must be false.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "T16: interior optimum — is_opf false" begin
        # Single-phase resistive, no generator, slack V=1000, high-V solution ≈947
        # sits strictly inside [900, 999] and there are no thermal limits → nothing
        # binds.
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
        p = res["opt_profile"]
        @test p["n_active"] == 0
        rep = profile_solution(net, res)
        @test rep.results[:optimization]["is_opf"] == false
    end

    # ─────────────────────────────────────────────────────────────────────────
    # solution_check coverage gaps (#290): power balance must account shunts and
    # capacitors; scalar (non-vector) thermal limits must be honoured; the NaN
    # scan must reach nested (transformer-winding) results; IBR violations must
    # count in the binding summary.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "solution_check coverage — balance/scalar/NaN/IBR (#290)" begin
        net = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b1":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3","n"],
             "v_magnitude":[230.0,230.0,230.0,0.0],"v_angle":[0.0,-2.0943951,2.0943951,0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,
             "R_series_4_4":0.05,"i_max":100.0}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","linecode":"lc","length":100.0,
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"]}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "model":"constant_power","p_nom":[2000.0,2000.0,2000.0],"q_nom":[800.0,800.0,800.0]}},
         "capacitor":{"c1":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "q_rated":[1000.0,1000.0,1000.0],"v_nom":230.0}},
         "shunt":{"sh":{"bus":"b1","terminal_map":["1"],"G_1_1":0.02,"B_1_1":0.0}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # (a) Balance accounts the capacitor's reactive injection and the phase
        # shunt's real draw — no spurious W.SOL.POWER_BALANCE.
        f = Finding[]
        out = solution_check(net, res, f)
        @test !any(x -> x.code == "W.SOL.POWER_BALANCE", f)
        @test out["q_capacitor"] > 0.0        # ≈ 3 × B·|V|²
        @test out["p_shunt"] > 100.0          # G·|V|² on the phase shunt (SI W)

        # (b) A SCALAR linecode i_max (not a vector) is honoured — a very tight
        # value fires a thermal finding that the vector-only check would miss.
        net_s = deepcopy(net); net_s["linecode"]["lc"]["i_max"] = 0.5
        fs = Finding[]
        solution_check(net_s, res, fs)
        @test any(x -> x.code in ("E.SOL.THERMAL_VIOLATION", "W.SOL.THERMAL_ACTIVE"), fs)

        # (c) A NaN buried in a transformer per-winding result is caught by the
        # recursive scan (a fixed bus[id][terminal].field descent missed it).
        res_nan = deepcopy(res)
        res_nan["transformer"] = Dict{String,Any}("t" => Dict{String,Any}(
            "fr" => Dict{String,Any}("1" => Dict{String,Any}("cm" => NaN))))
        fn = Finding[]
        on = solution_check(net, res_nan, fn)
        @test on["n_nan_fields"] >= 1
        @test any(x -> x.code == "E.SOL.NAN_IN_RESULT", fn)

        # (d) IBR capability violations count toward the binding-summary total.
        netv = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "b1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                      "v_min":[215.0],"v_max":[245.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","linecode":"lc","length":100.0,
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"]}},
         "ibr":{"pv":{"bus":"b1","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"PV",
             "s_max":[20000.0],"p_max":[20000.0],"p_min":[0.0],"q_min":[0.0],"q_max":[0.0],
             "cost":[-1.0]}}}
        """; from_string=true)
        rv = solve_opf(netv)
        @test rv["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        cm = hypot(rv["ibr"]["pv"]["1"]["cri"], rv["ibr"]["pv"]["1"]["cii"])
        netv2 = deepcopy(netv); netv2["ibr"]["pv"]["i_max"] = [0.5 * cm]  # tightened below solve
        fv = Finding[]
        solution_check(netv2, rv, fv)
        bs = only(x for x in fv if x.code == "I.SOL.BINDING_SUMMARY")
        @test bs.detail["n_inv_violations"] >= 1
        @test occursin("IBR:", bs.message)
    end

end  # @testset "OPF — solve_opf extension"
