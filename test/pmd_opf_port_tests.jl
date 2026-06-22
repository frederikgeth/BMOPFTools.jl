# OPF optimality tests ported from PowerModelsDistribution.jl.
#
# Provenance
# ----------
# These fixtures reproduce the small networks used by PMD's optimal-power-flow
# unit tests. The published objective targets are PMD's reference values; the
# pg/qg are the slack (voltage-source) injections, which BMOPF reports as
# voltage_source[...]["ps"|"qs"] (W/var, positive = supplying), so we sum over
# phases and compare in kW/kvar:
#
#   PMD test/opf_iv.jl, "test IVR opf_iv" (IVRUPowerModel — the formulation
#   closest to BMOPF's own current-voltage OPF engine):
#     · 2-bus diagonal      → Σ pg = 18.209 kW, Σ qg = 0.208 kvar
#     · 3-bus balanced      → Σ pg = 18.345 kW, Σ qg = 9.194 kvar
#     · 3-bus unbalanced    → Σ pg = 21.4812 kW, Σ qg = 9.27263 kvar
#
#   PMD test/opf.jl (AC formulations — objectives are formulation-independent):
#     · 4-bus phase drop    → Σ pg = 18.2632 kW, Σ qg = 9.02334 kvar (+ voltages)
#     · 5-bus phase drop    → Σ pg = 59.9363 kW, Σ qg = −33.5395 kvar (+ voltages)
#     · 3-bus delta+ZIP     → Σ pg = 42.0464 kW, Σ qg = 18.1928 kvar (+ voltages)
#
# No dependency on PMD or its parser: each network is rebuilt directly from the
# underlying OpenDSS source (PMD `test/data/opendss/case{2_diag,3_balanced,
# 3_unbalanced,4_phase_drop,5_phase_drop,3_unbalanced_delta_loads}.dss`) in
# BMOPF's native JSON schema.
#
# Modelling notes (DSS → BMOPF)
# -----------------------------
#   · Source `Circuit.3Bus_example  basekv=0.4 pu=0.9959 MVAsc1=MVAsc3=1e6`:
#     a "really stiff" (≈ ideal) wye source. Phase-to-ground magnitude
#     v_ph = 0.9959·400/√3 = 229.993 V at 0°/−120°/+120°. The 1e6-MVA short-
#     circuit level gives a Thévenin impedance ≈ 1.6e-7 Ω → modelled as an ideal
#     BMOPF voltage source (negligible internal drop).
#   · The DSS lines are 3-wire (Kron-reduced, `.1.2.3`); single-phase loads
#     return through the solidly-grounded system reference (`.x.0`). Modelled in
#     BMOPF with a perfectly-grounded "n" terminal at every bus (ideal return).
#   · linecode `rmatrix`/`xmatrix` are Ω per unit length, `length=1` → entered
#     directly as R_series/X_series. `cmatrix` is nF per unit length; at the DSS
#     basefreq=50 Hz the π-model half-shunt is B = ½·ω·C = 8.0e-6 S per phase
#     (diagonal; case3 only — case2 has cmatrix = 0).
#   · The constant-power loads (`model=1`) map to BMOPF's default PQ loads. The
#     case3 `daily` loadshape is a time series irrelevant to the single-snapshot
#     OPF and is omitted (PMD likewise dispatches the nominal kW/kvar here).

@testset "OPF optimality — ported from PowerModelsDistribution" begin

    # Source phase-to-ground magnitude: 0.9959 · 400/√3 V (basekv=0.4, pu=0.9959)
    V_PH = 229.99325323437935
    # Half π-shunt at 50 Hz for the case3 cmatrix = 50.9296 nF/unit linecodes
    B_HALF = 8.000002860513336e-6

    "Σ over phases of the voltage-source injection, returned in kW and kvar."
    function _source_kw_kvar(res, sid="source")
        vs = res["voltage_source"][sid]
        p = sum(vs[ph]["ps"] for ph in keys(vs))
        q = sum(vs[ph]["qs"] for ph in keys(vs))
        return p / 1000.0, q / 1000.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case2_diag — 2-bus, diagonal (decoupled) line, balanced 3×6 kW load.
    # PMD IVR target: Σ pg = 18.209 kW, Σ qg = 0.208 kvar.
    #
    # With a purely diagonal R=X=0.1 Ω line and unity-PF loads, qg arises solely
    # from the series reactance carrying the load current (X·|I|²), so this case
    # is a clean check that BMOPF's series-reactance reactive loss matches PMD.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "2-bus diagonal — Σpg=18.209 kW, Σqg=0.208 kvar" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "primary":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_PH),$(V_PH),$(V_PH)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{"556MCM":{
             "R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1,
             "X_series_1_1":0.1,"X_series_2_2":0.1,"X_series_3_3":0.1}},
         "line":{"OHLine":{"bus_from":"sourcebus","bus_to":"primary",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"556MCM","length":1.0}},
         "load":{
             "L1":{"bus":"primary","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[0.0]},
             "L2":{"bus":"primary","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[0.0]},
             "L3":{"bus":"primary","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 18.209  atol=1e-2
        @test qg ≈ 0.208   atol=1e-2
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case3_balanced — 3-bus, two coupled (full-matrix) lines, π-shunts,
    # balanced 3×(6 kW + 3 kvar) load.
    # PMD IVR target: Σ pg = 18.345 kW, Σ qg = 9.194 kvar.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "3-bus balanced — Σpg=18.345 kW, Σqg=9.194 kvar" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "primary":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]},
            "loadbus":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_PH),$(V_PH),$(V_PH)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{
             "556MCM":{
                 "R_series_1_1":0.1000,"R_series_1_2":0.0400,"R_series_1_3":0.0400,
                 "R_series_2_2":0.1000,"R_series_2_3":0.0400,"R_series_3_3":0.1000,
                 "X_series_1_1":0.0583,"X_series_1_2":0.0233,"X_series_1_3":0.0233,
                 "X_series_2_2":0.0583,"X_series_2_3":0.0233,"X_series_3_3":0.0583,
                 "B_from_1_1":$(B_HALF),"B_from_2_2":$(B_HALF),"B_from_3_3":$(B_HALF),
                 "B_to_1_1":$(B_HALF),"B_to_2_2":$(B_HALF),"B_to_3_3":$(B_HALF)},
             "4/0QUAD":{
                 "R_series_1_1":0.1167,"R_series_1_2":0.0467,"R_series_1_3":0.0467,
                 "R_series_2_2":0.1167,"R_series_2_3":0.0467,"R_series_3_3":0.1167,
                 "X_series_1_1":0.0667,"X_series_1_2":0.0267,"X_series_1_3":0.0267,
                 "X_series_2_2":0.0667,"X_series_2_3":0.0267,"X_series_3_3":0.0667,
                 "B_from_1_1":$(B_HALF),"B_from_2_2":$(B_HALF),"B_from_3_3":$(B_HALF),
                 "B_to_1_1":$(B_HALF),"B_to_2_2":$(B_HALF),"B_to_3_3":$(B_HALF)}},
         "line":{
             "OHLine":{"bus_from":"sourcebus","bus_to":"primary",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
                 "linecode":"556MCM","length":1.0},
             "Quad":{"bus_from":"primary","bus_to":"loadbus",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
                 "linecode":"4/0QUAD","length":1.0}},
         "load":{
             "L1":{"bus":"loadbus","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]},
             "L2":{"bus":"loadbus","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]},
             "L3":{"bus":"loadbus","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 18.345  atol=1e-2
        @test qg ≈ 9.194   atol=1e-2
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case3_unbalanced — identical to case3_balanced but L1 = 9 kW (others 6 kW),
    # so the load (and the resulting neutral/return current) is unbalanced.
    # PMD IVR target: Σ pg = 21.4812 kW, Σ qg = 9.27263 kvar.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "3-bus unbalanced — Σpg=21.4812 kW, Σqg=9.27263 kvar" begin
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "primary":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]},
            "loadbus":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_PH),$(V_PH),$(V_PH)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{
             "556MCM":{
                 "R_series_1_1":0.1000,"R_series_1_2":0.0400,"R_series_1_3":0.0400,
                 "R_series_2_2":0.1000,"R_series_2_3":0.0400,"R_series_3_3":0.1000,
                 "X_series_1_1":0.0583,"X_series_1_2":0.0233,"X_series_1_3":0.0233,
                 "X_series_2_2":0.0583,"X_series_2_3":0.0233,"X_series_3_3":0.0583,
                 "B_from_1_1":$(B_HALF),"B_from_2_2":$(B_HALF),"B_from_3_3":$(B_HALF),
                 "B_to_1_1":$(B_HALF),"B_to_2_2":$(B_HALF),"B_to_3_3":$(B_HALF)},
             "4/0QUAD":{
                 "R_series_1_1":0.1167,"R_series_1_2":0.0467,"R_series_1_3":0.0467,
                 "R_series_2_2":0.1167,"R_series_2_3":0.0467,"R_series_3_3":0.1167,
                 "X_series_1_1":0.0667,"X_series_1_2":0.0267,"X_series_1_3":0.0267,
                 "X_series_2_2":0.0667,"X_series_2_3":0.0267,"X_series_3_3":0.0667,
                 "B_from_1_1":$(B_HALF),"B_from_2_2":$(B_HALF),"B_from_3_3":$(B_HALF),
                 "B_to_1_1":$(B_HALF),"B_to_2_2":$(B_HALF),"B_to_3_3":$(B_HALF)}},
         "line":{
             "OHLine":{"bus_from":"sourcebus","bus_to":"primary",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
                 "linecode":"556MCM","length":1.0},
             "Quad":{"bus_from":"primary","bus_to":"loadbus",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
                 "linecode":"4/0QUAD","length":1.0}},
         "load":{
             "L1":{"bus":"loadbus","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[9000.0],"q_nom":[3000.0]},
             "L2":{"bus":"loadbus","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]},
             "L3":{"bus":"loadbus","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 21.4812  atol=1e-2
        @test qg ≈ 9.27263  atol=1e-2
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case4_phase_drop — true phase dropping: three independent single-phase
    # lines, each carrying one load on a different phase (loadbusN on phase N).
    # Ported from PMD test/opf.jl, "4-bus phase drop acp/acr opf" (both AC
    # formulations report the same objective and voltages).
    #
    # Source pu=1 ⇒ phase-to-ground magnitude V_PH1 = 400/√3 = 230.940 V; this is
    # also the per-unit voltage base used by the PMD voltage assertions.
    # Loads: 5 / 6 / 7 kW + 3 kvar (phase-to-neutral). cmatrix = 50 nF/unit
    # (default 60 Hz ⇒ π half-shunt B = 9.4248e-6 S).
    #
    # PMD targets: Σpg = 18.2632 kW, Σqg = 9.02334 kvar, and
    #   loadbus1 |V|/Vbase = 0.98995, ∠V =  0.27°
    #   loadbus2 |V|/Vbase = 0.98803, ∠V = −119.74°
    #   loadbus3 |V|/Vbase = 0.98611, ∠V =  120.25°
    # ─────────────────────────────────────────────────────────────────────────
    @testset "4-bus phase drop — Σpg=18.2632 kW, Σqg=9.02334 kvar" begin
        V1 = 230.94010767585033
        Bh = 9.424777960769377e-6
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "loadbus1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                        "v_min":[200.0],"v_max":[250.0]},
            "loadbus2":{"terminal_names":["2","n"],"perfectly_grounded_terminals":["n"],
                        "v_min":[200.0],"v_max":[250.0]},
            "loadbus3":{"terminal_names":["3","n"],"perfectly_grounded_terminals":["n"],
                        "v_min":[200.0],"v_max":[250.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(V1),$(V1),$(V1)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{"oh":{"R_series_1_1":0.1,"X_series_1_1":0.01,
                           "B_from_1_1":$(Bh),"B_to_1_1":$(Bh)}},
         "line":{
             "OHLine1":{"bus_from":"sourcebus","bus_to":"loadbus1",
                 "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"oh","length":1.0},
             "OHLine2":{"bus_from":"sourcebus","bus_to":"loadbus2",
                 "terminal_map_from":["2"],"terminal_map_to":["2"],"linecode":"oh","length":1.0},
             "OHLine3":{"bus_from":"sourcebus","bus_to":"loadbus3",
                 "terminal_map_from":["3"],"terminal_map_to":["3"],"linecode":"oh","length":1.0}},
         "load":{
             "L1":{"bus":"loadbus1","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[5000.0],"q_nom":[3000.0]},
             "L2":{"bus":"loadbus2","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0]},
             "L3":{"bus":"loadbus3","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[7000.0],"q_nom":[3000.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 18.2632  atol=1e-2
        @test qg ≈ 9.02334  atol=1e-2

        # Per-bus voltage magnitude (pu on V1) and angle (deg) against PMD.
        for (b, t, vpu, vadeg) in (("loadbus1","1",0.98995,0.27),
                                   ("loadbus2","2",0.98803,-119.74),
                                   ("loadbus3","3",0.98611,120.25))
            bt = res["bus"][b][t]
            @test bt["vm"] / V1 ≈ vpu  atol=1e-4
            @test rad2deg(bt["va"]) ≈ vadeg  atol=1e-2
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case5_phase_drop — a 3-phase trunk feeding mixed laterals: a 1-phase lateral
    # (phase 1), a 2-phase lateral (phases 2,3), and a 1-phase lateral (phase 3)
    # terminating in a shunt capacitor. Loads are capacitive (−10 kvar). Ported
    # from PMD test/opf.jl, "5-bus phase drop acp/acr opf".
    #
    # Source pu=1 ⇒ V_PH1 = 230.940 V (also the voltage base). All linecodes share
    # R=0.1, X=0.01, cmatrix=50 nF/unit (60 Hz ⇒ half-shunt B = 9.4248e-6 S).
    # Capacitor capac1: 4.5 kvar, kv = 0.4/√3 ⇒ B = 4.5e3/V1² = 0.084375 S (phase 3).
    #
    # PMD targets: Σpg = 59.9363 kW, Σqg = −33.5395 kvar, and at midbus
    #   |V|/Vbase = [0.97351, 0.96490, 0.95646], ∠V = [−1.26, −121.31, 118.17]°.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "5-bus phase drop — Σpg=59.9363 kW, Σqg=-33.5395 kvar" begin
        V1 = 230.94010767585033
        Bh = 9.424777960769377e-6
        Bc = 0.084375
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "midbus":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                      "v_min":[180.0,180.0,180.0],"v_max":[250.0,250.0,250.0]},
            "l1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[150.0],"v_max":[260.0]},
            "l2":{"terminal_names":["2","3","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[150.0,150.0],"v_max":[260.0,260.0]},
            "cap1":{"terminal_names":["3","n"],"perfectly_grounded_terminals":["n"],
                    "v_min":[150.0],"v_max":[260.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(V1),$(V1),$(V1)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{
             "lc1_3ph":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1,
                        "X_series_1_1":0.01,"X_series_2_2":0.01,"X_series_3_3":0.01,
                        "B_from_1_1":$(Bh),"B_from_2_2":$(Bh),"B_from_3_3":$(Bh),
                        "B_to_1_1":$(Bh),"B_to_2_2":$(Bh),"B_to_3_3":$(Bh)},
             "lc1_2ph":{"R_series_1_1":0.1,"R_series_2_2":0.1,
                        "X_series_1_1":0.01,"X_series_2_2":0.01,
                        "B_from_1_1":$(Bh),"B_from_2_2":$(Bh),
                        "B_to_1_1":$(Bh),"B_to_2_2":$(Bh)},
             "lc1_1ph":{"R_series_1_1":0.1,"X_series_1_1":0.01,
                        "B_from_1_1":$(Bh),"B_to_1_1":$(Bh)}},
         "line":{
             "line1":{"bus_from":"sourcebus","bus_to":"midbus",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],"linecode":"lc1_3ph","length":1.0},
             "line2":{"bus_from":"midbus","bus_to":"l1",
                 "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc1_1ph","length":1.0},
             "line3":{"bus_from":"midbus","bus_to":"l2",
                 "terminal_map_from":["2","3"],"terminal_map_to":["2","3"],"linecode":"lc1_2ph","length":1.0},
             "line4":{"bus_from":"midbus","bus_to":"cap1",
                 "terminal_map_from":["3"],"terminal_map_to":["3"],"linecode":"lc1_1ph","length":1.0}},
         "shunt":{"capac1":{"bus":"cap1","terminal_map":["3"],"G_1_1":0.0,"B_1_1":$(Bc)}},
         "load":{
             "load1":{"bus":"l1","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[14000.0],"q_nom":[-10000.0]},
             "load2":{"bus":"l2","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[18000.0],"q_nom":[-10000.0]},
             "load3":{"bus":"l2","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[22000.0],"q_nom":[-10000.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 59.9363   atol=1e-2
        @test qg ≈ -33.5395  atol=1e-2

        mb = res["bus"]["midbus"]
        for (t, vpu, vadeg) in (("1",0.97351,-1.26),("2",0.96490,-121.31),("3",0.95646,118.17))
            @test mb[t]["vm"] / V1 ≈ vpu  atol=1e-4
            @test rad2deg(mb[t]["va"]) ≈ vadeg  atol=1e-2
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # case3_unbalanced_delta_loads — the case3 trunk feeding six single-phase
    # loads at loadbus: three DELTA arms (1-2, 2-3, 3-1) and three WYE loads,
    # each pair spanning the three OpenDSS load models —
    #   model=1 → constant power   (BMOPF default PQ)
    #   model=2 → constant impedance (BMOPF exponential γ=2)
    #   model=5 → constant current  (BMOPF exponential γ=1)
    # Ported from PMD test/opf.jl, "3-bus unbalanced fotp/fotr opf with
    # voltage-dependent loads" (the exact AC objective these approximate).
    #
    # v_nom is the OpenDSS load `kv`: 400 V (line-to-line) for the DELTA arms,
    # 230.94 V (line-to-neutral) for the WYE loads.
    # Source pu=0.9959 ⇒ V_PH = 229.993 V.
    #
    # PMD targets: Σpg = 42.0464 kW, Σqg = 18.1928 kvar, and at loadbus
    #   |V|/Vbase = [0.94105, 0.95942, 0.95876], ∠V = [−0.9, −120.3, 120.2]°
    #   (Vbase = 0.4/√3 kV).
    #
    # Tolerance note: PMD pins this voltage-dependent case ONLY via its linearised
    # formulations (FOTP/FOTR/FBS), all at atol=1 kW/kvar — there is no exact AC
    # reference. BMOPF solves the case exactly; its objective lands inside PMD's
    # ±1 band, and the *voltages* match PMD's references to PMD's own fotp
    # tolerances (vm atol=1e-2 pu, va atol=5e-1°), which are the tight checks here.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "3-bus unbalanced delta+ZIP loads — Σpg=42.0464 kW, Σqg=18.1928 kvar" begin
        VLL = 400.0
        VLN = 229.99325323437935   # wye load v_nom (0.4/√3 kV)
        net = parse_bmopf("""
        {"bus":{
            "sourcebus":{"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"]},
            "primary":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[180.0,180.0,180.0],"v_max":[250.0,250.0,250.0]},
            "loadbus":  {"terminal_names":["1","2","3","n"],
                         "perfectly_grounded_terminals":["n"],
                         "v_min":[180.0,180.0,180.0],"v_max":[250.0,250.0,250.0]}},
         "voltage_source":{"source":{"bus":"sourcebus","terminal_map":["1","2","3"],
             "v_magnitude":[$(VLN),$(VLN),$(VLN)],
             "v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{
             "556MCM":{
                 "R_series_1_1":0.1000,"R_series_1_2":0.0400,"R_series_1_3":0.0400,
                 "R_series_2_2":0.1000,"R_series_2_3":0.0400,"R_series_3_3":0.1000,
                 "X_series_1_1":0.0583,"X_series_1_2":0.0233,"X_series_1_3":0.0233,
                 "X_series_2_2":0.0583,"X_series_2_3":0.0233,"X_series_3_3":0.0583},
             "4/0QUAD":{
                 "R_series_1_1":0.1167,"R_series_1_2":0.0467,"R_series_1_3":0.0467,
                 "R_series_2_2":0.1167,"R_series_2_3":0.0467,"R_series_3_3":0.1167,
                 "X_series_1_1":0.0667,"X_series_1_2":0.0267,"X_series_1_3":0.0267,
                 "X_series_2_2":0.0667,"X_series_2_3":0.0267,"X_series_3_3":0.0667}},
         "line":{
             "OHLine":{"bus_from":"sourcebus","bus_to":"primary",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],"linecode":"556MCM","length":1.0},
             "Quad":{"bus_from":"primary","bus_to":"loadbus",
                 "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],"linecode":"4/0QUAD","length":1.0}},
         "load":{
             "L1":{"bus":"loadbus","terminal_map":["1","2"],"configuration":"DELTA","p_nom":[9000.0],"q_nom":[3000.0]},
             "L2":{"bus":"loadbus","terminal_map":["2","3"],"configuration":"DELTA","p_nom":[6000.0],"q_nom":[3000.0],
                   "model":"exponential","v_nom":[$(VLL)],"gamma_p":[2.0],"gamma_q":[2.0]},
             "L3":{"bus":"loadbus","terminal_map":["3","1"],"configuration":"DELTA","p_nom":[6000.0],"q_nom":[3000.0],
                   "model":"exponential","v_nom":[$(VLL)],"gamma_p":[1.0],"gamma_q":[1.0]},
             "L4":{"bus":"loadbus","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[9000.0],"q_nom":[3000.0]},
             "L5":{"bus":"loadbus","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0],
                   "model":"exponential","v_nom":[$(VLN)],"gamma_p":[2.0],"gamma_q":[2.0]},
             "L6":{"bus":"loadbus","terminal_map":["3","n"],"configuration":"SINGLE_PHASE","p_nom":[6000.0],"q_nom":[3000.0],
                   "model":"exponential","v_nom":[$(VLN)],"gamma_p":[1.0],"gamma_q":[1.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg, qg = _source_kw_kvar(res)
        @test pg ≈ 42.0464  atol=1.0   # PMD pins this case only to ±1 (approx. formulations)
        @test qg ≈ 18.1928  atol=1.0

        VB = 400.0 / sqrt(3)
        lb = res["bus"]["loadbus"]
        for (t, vpu, vadeg) in (("1",0.94105,-0.9),("2",0.95942,-120.3),("3",0.95876,120.2))
            @test lb[t]["vm"] / VB ≈ vpu  atol=1e-2
            @test rad2deg(lb[t]["va"]) ≈ vadeg  atol=5e-1
        end
    end
end
