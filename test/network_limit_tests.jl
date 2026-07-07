# Network-limit correctness tests for the OPF engine.
# Included from runtests.jl when JuMP and Ipopt are in the load path.
#
# Purpose — a THIRD validation axis, distinct from feasibility and optimality
# -------------------------------------------------------------------------
# The feasibility suite (powerflow_comparison_tests.jl) checks that the solved
# voltages/currents satisfy the *physics* (KCL/KVL, component models) by matching
# OpenDSS. The optimality suite (opf_tests.jl, pmd_opf_port_tests.jl) checks that
# the optimizer reaches the right dispatch given the bounds. Neither asks the
# prior question this file targets:
#
#   Does each modeled network LIMIT correctly encode the engineering limit it
#   claims to — given that the decision variables are RECTANGULAR (vr, vi, cr,
#   ci) and almost none of these limits are box bounds on a variable?
#
# OpenDSS cannot be the oracle here: it is a power-flow engine and has no OPF
# inequality limits, so every limit constraint is invisible to the feasibility
# harness. A wrong sign or factor in a limit would still produce "an optimum" —
# just the optimum of the wrong feasible set — so optimality cannot catch it
# either.
#
# Method — binding test + recompute-from-primal
# ---------------------------------------------
# Each test (1) builds a minimal case where the target limit is the SINGLE
# active constraint and drives the network onto it; (2) solves; (3) recomputes
# the limited quantity from the primal solution by an INDEPENDENT route (e.g.
# sqrt(vr²+vi²), atan2 angle differences, an explicit Fortescue matrix) — never
# by reading back the constraint's own expression — and asserts it equals the
# named threshold. Recomputing by a different route is what catches a factor-of,
# a flipped cross-product sign, or a wrong rotation constant.
#
# The taxonomy of nontrivial limits (see docs/src/validation.md, "Limit
# correctness"):
#   A. magnitude  → quadratic ball/annulus (voltage, current, apparent power)
#   B. angle      → bilinear cross/dot inequalities (no angle variable exists)
#   C. sequence   → Fortescue transform then magnitude (vpos/vneg/vzero)
#   D. power      → bounds on bilinear power expressions p = vr·ir + vi·ii

@testset "Network-limit correctness — binding + recompute-from-primal" begin

    # ─────────────────────────────────────────────────────────────────────────
    # L-B1: intra-bus voltage angle-difference limit (`va_diff_max`)
    #
    # Class B. The bound is encoded in rectangular variables as the bilinear
    # inequality  s ≤ tan(va_diff_max)·c , with
    #   s = vr_k·vi_j − vi_k·vr_j = |V_k||V_j|·sin(θ_j − θ_k)   (cross product)
    #   c = vr_k·vr_j + vi_k·vi_j = |V_k||V_j|·cos(θ_j − θ_k)   (dot product),
    # so s/c = tan(θ_j − θ_k): it bounds the SIGNED RAW angle θ_j − θ_k for each
    # ordered phase pair k<j, applied to every applicable pair on the bus.
    #
    # SUBTLETY surfaced by this scaffold (bus.jl:201-217): the bounded quantity
    # is the raw inter-phase angle (≈ ∓120° nominally), NOT a deviation from
    # nominal — so a meaningful bound must be supplied AROUND ±120°, and the sign
    # follows the (k<j) pair ordering. A correct binding test must therefore (a)
    # pick a single applicable pair, (b) drive θ_j − θ_k onto the named bound,
    # and (c) recompute it independently with atan2(vi,vr) per terminal. Pinning
    # down whether this raw-angle semantics is the intended engineering meaning
    # (vs. a deviation/sequence-angle bound) is itself a backlog item — see
    # docs/src/validation.md "Limit correctness".
    # ─────────────────────────────────────────────────────────────────────────
    # NOTE: the constraint now bounds the CENTERED difference θ_j−θ_k−Δ, where
    # Δ = va_nom[j]−va_nom[k] is the nominal offset (±120° for 3φ, 180° for
    # split-phase legs). A tight window around the nominal is only feasible
    # BECAUSE of the centering rotation — the old raw-around-zero bound would be
    # infeasible for any real multiphase solution (≈±120°). These tests recompute
    # the centered quantity independently via atan2 per terminal.
    @testset "L-B1: 3φ centered angle diff — recompute via atan2" begin
        V_s = 1000.0; R = 0.5
        win = 0.10                      # ±0.10 rad window around ±120° nominal
        net = parse_bmopf("""
        {"bus":{
            "sb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"]},
            "lb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"],
                  "v_min":[800.0,800.0,800.0],
                  "va_nom":[0.0,-2.0943951,2.0943951],
                  "va_diff_min":$(-win),"va_diff_max":$(win)}},
         "voltage_source":{"vs":{"bus":"sb","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_s),$(V_s),$(V_s)],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":$(R),"R_series_2_2":$(R),"R_series_3_3":$(R)}},
         "line":{"l1":{"bus_from":"sb","bus_to":"lb",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"lb","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[20000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        b = res["bus"]["lb"]
        θ(t) = atan(b[t]["vi"], b[t]["vr"])
        nom = Dict("1"=>0.0, "2"=>-2.0943951, "3"=>2.0943951)
        wrap(x) = (y = mod(x + π, 2π) - π; y == -π ? π : y)
        for (k, j) in (("1","2"), ("1","3"), ("2","3"))
            centered = wrap(θ(j) - θ(k) - (nom[j] - nom[k]))
            @test -win - 1e-3 <= centered <= win + 1e-3       # within the window
            raw = wrap(θ(j) - θ(k))
            @test abs(abs(raw) - 2.0943951) < win + 1e-2       # raw diff ≈ ±120°
        end
    end

    @testset "L-B1b: split-phase legs held ~180° apart" begin
        V_s = 230.0; R = 0.1
        win = 0.10
        # Source pins leg "2" anti-phase to leg "1"; the constrained LV bus must
        # keep the two legs ≈π apart, i.e. centered diff (raw − π) within window.
        net = parse_bmopf("""
        {"bus":{
            "sb":{"terminal_names":["1","n","2"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"]},
            "lb":{"terminal_names":["1","n","2"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"],
                  "v_min":[180.0,180.0],
                  "va_nom":[0.0,3.1415927],
                  "va_diff_min":$(-win),"va_diff_max":$(win)}},
         "voltage_source":{"vs":{"bus":"sb","terminal_map":["1","n","2"],
             "v_magnitude":[$(V_s),0.0,$(V_s)],
             "v_angle":[0.0,0.0,3.1415927]}},
         "linecode":{"lc":{"R_series_1_1":$(R),"R_series_2_2":$(R)}},
         "line":{"l1":{"bus_from":"sb","bus_to":"lb",
             "terminal_map_from":["1","2"],"terminal_map_to":["1","2"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"lb","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        b = res["bus"]["lb"]
        θ(t) = atan(b[t]["vi"], b[t]["vr"])
        wrap(x) = (y = mod(x + π, 2π) - π; y == -π ? π : y)
        raw = wrap(θ("2") - θ("1"))
        @test abs(abs(raw) - π) < win + 1e-2                  # legs ≈ 180° apart
        centered = wrap(raw - π)
        @test -win - 1e-3 <= centered <= win + 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-C2: negative-sequence voltage limit (`vneg_max`)
    #
    # Class C. |V₂|² ≤ vneg_max², where V₂ is the negative-sequence component —
    # a complex linear combination of the three phase phasors via the Fortescue
    # a-operator (α = e^{j120°}). A wrong rotation constant or 1/3 factor passes
    # feasibility silently. An unbalanced source pushes V₂ up against the bound.
    #
    # TODO(scaffold): set the source imbalance / vneg_max so V₂ is the binding
    # constraint at the optimum, then assert V2 ≈ vneg_max (atol).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-C2: negative-sequence bound — recompute via Fortescue" begin
        V_s = 1000.0; R = 0.5
        vneg_max = 30.0

        net = parse_bmopf("""
        {"bus":{
            "sb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"]},
            "lb":{"terminal_names":["1","2","3","n"],
                  "neutral_terminal":"n","perfectly_grounded_terminals":["n"],
                  "v_min":[800.0,800.0,800.0],
                  "vneg_max":$(vneg_max)}},
         "voltage_source":{"vs":{"bus":"sb","terminal_map":["1","2","3"],
             "v_magnitude":[$(V_s),$(V_s),$(V_s)],
             "v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{
             "R_series_1_1":$(R),"R_series_2_2":$(R),"R_series_3_3":$(R)}},
         "line":{"l1":{"bus_from":"sb","bus_to":"lb",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":1.0}},
         "load":{"ld":{"bus":"lb","terminal_map":["1","n"],
             "configuration":"SINGLE_PHASE","p_nom":[80000.0],"q_nom":[0.0]}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        b = res["bus"]["lb"]
        s3 = sqrt(3.0) / 2.0
        vr1 = b["1"]["vr"]; vi1 = b["1"]["vi"]
        vr2 = b["2"]["vr"]; vi2 = b["2"]["vi"]
        vr3 = b["3"]["vr"]; vi3 = b["3"]["vi"]
        # Independent Fortescue recompute: V₂ = (Va + α²·Vb + α·Vc) / 3.
        V2r = (vr1 - 0.5*vr2 + s3*vi2 - 0.5*vr3 - s3*vi3) / 3
        V2i = (vi1 - s3*vr2 - 0.5*vi2 + s3*vr3 - 0.5*vi3) / 3
        V2  = sqrt(V2r^2 + V2i^2)
        # Scaffold assertion: realised negative sequence respects its bound.
        @test V2 <= vneg_max + 1e-2
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-A8: IBR/generator apparent-power limit (`s_max`)
    #
    # Class A (with class-D power expressions). pg² + qg² ≤ s_max², where pg, qg
    # are themselves bilinear in (v, i). Recompute |S| from the reported pg/qg
    # (which are evaluated from the primal v·i product) and assert it hits s_max.
    #
    # TODO(scaffold): add an s_max-limited generator fixture and drive |S| to the
    # bound (e.g. negative active-power cost with a binding apparent-power cap).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-A8: apparent-power bound — recompute |S| = √(pg²+qg²)" begin
        @test_skip "scaffold: add s_max generator fixture, assert √(pg²+qg²) ≈ s_max"
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-A5: branch thermal current limit (`i_max` on the linecode)
    #
    # Class A. cr² + ci² ≤ i_max², on the TOTAL per-end terminal current (series
    # + π-shunt). Recompute cm from the reported cr/ci and assert it hits i_max.
    #
    # TODO(scaffold): add an i_max-limited line fixture and load it onto the
    # thermal bound, then assert cm_fr ≈ i_max.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-A5: thermal current bound — recompute cm" begin
        @test_skip "scaffold: add i_max line fixture, assert cm_fr ≈ i_max at the bound"
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-A5b: to-side thermal bound with a FROM-side-only π-shunt (#274)
    #
    # The to-side total current is −c_series (no to-shunt), whose magnitude
    # differs from the from-side total c_series + I_shunt_fr whenever a from-side
    # shunt exists. Here a capacitive from-side shunt shrinks the from-side
    # magnitude below the (inductive) load-driven series current, so the from-side
    # cone alone would let the to-end exceed i_max. A local generator can relieve
    # the line, so the correct model clamps the to-end at i_max; the buggy model
    # (from-cone only) reports cm_to > i_max.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-A5b: to-side i_max with from-side-only shunt (#274)" begin
        # A line whose linecode carries a from-side-only capacitive π-shunt feeds
        # an inductive constant-power load. The capacitive shunt shrinks the
        # from-end total current below the (inductive) series current, so the two
        # ends differ: |I_to| = |series| ≈ 22 A, |I_fr| = |series + I_shunt| ≈ 17 A.
        # Only the to-side cone can catch an over-limit to-end; the pre-#274 model
        # added it only when a *to*-side shunt was present, leaving the to-end
        # unbounded here.
        #
        # Checked in both per-unit and SI mode. (Issue #299: the default per-unit
        # path used to silently drop a shunt-bearing line's i_max backstop, so
        # this could only be observed in SI; #299 added a to-side variable box so
        # the limit now holds in both modes.)
        mknet(ilim) = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[150.0,150.0,150.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1,"R_series_4_4":0.1,
             "X_series_1_1":0.05,"X_series_2_2":0.05,"X_series_3_3":0.05,"X_series_4_4":0.05,
             "B_from_1_1":0.03,"B_from_2_2":0.03,"B_from_3_3":0.03}},
         "line":{"l":{"bus_from":"src","bus_to":"b","linecode":"lc","length":1.0,
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "i_max":[$(ilim),$(ilim),$(ilim),1000.0]}},
         "load":{"ld":{"bus":"b","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "model":"constant_power","p_nom":[3000.0,3000.0,3000.0],"q_nom":[4000.0,4000.0,4000.0]}}}
        """; from_string=true)

        for pu in (false, true)
            # Positive control: a slack limit (25 A > both ends) solves, and the
            # from-side shunt genuinely makes the to-end the larger of the two.
            ok = solve_opf(mknet(25.0); per_unit = pu)
            @test ok["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            cm_fr = ok["line"]["l"]["1"]["cm_fr"]
            cm_to = ok["line"]["l"]["1"]["cm_to"]
            @test cm_to > cm_fr + 1.0                 # ends differ; to-end is larger
            @test cm_to <= 25.0 * (1 + 5e-3)

            # Binding case: i_max = 19 A sits between |I_fr| (≈17) and |I_to| (≈22).
            # With the to-side backstop the fixed load cannot be met (infeasible);
            # without it (the bug) the solve succeeds with the to-end ≈22 A over cap.
            lim = solve_opf(mknet(19.0); per_unit = pu)
            @test lim["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-A9: neutral-conductor current limit (trailing per-conductor `i_max` entry)
    #
    # Class A on the IMPLICIT neutral current. A star device's neutral return
    # carries −Σ(phase currents); a 4th i_max entry caps it via
    # (Σ crg)² + (Σ cig)² ≤ i_max_neutral². We incentivise injection on phase a
    # only (so |Iₙ| ≈ |Iₐ|), drive it onto a small neutral cap, and recompute the
    # neutral magnitude from the primal phase currents.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-A9: neutral current bound — recompute |Iₙ| = |Σ Iₖ|" begin
        _net(comp) = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1,"R_series_4_4":0.1}},
         "line":{"l":{"bus_from":"src","bus_to":"b","terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],"linecode":"lc","length":1.0}},
         $(comp)}
        """; from_string=true)

        # (a) WYE generator
        gnet = _net("""
        "generator":{"g":{"bus":"b","terminal_map":["1","2","3","n"],"configuration":"WYE",
            "p_min":[0.0,0.0,0.0],"p_max":[20000.0,0.0,0.0],"q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],
            "cost":[-1.0,0.0,0.0],"i_max":[1000.0,1000.0,1000.0,10.0]}}""")
        res = solve_opf(gnet)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        g  = res["generator"]["g"]
        crn = g["1"]["crg"] + g["2"]["crg"] + g["3"]["crg"]
        cin = g["1"]["cig"] + g["2"]["cig"] + g["3"]["cig"]
        @test hypot(crn, cin) ≈ 10.0 atol = 1e-1          # neutral current binds the cap
        @test hypot(g["1"]["crg"], g["1"]["cig"]) ≈ 10.0 atol = 1e-1   # only phase a flows

        # (b) FOUR_LEG IBR — same neutral cap via the shared helper
        inet = _net("""
        "ibr":{"v":{"bus":"b","terminal_map":["1","2","3","n"],"topology":"FOUR_LEG",
            "prime_mover":"GENERIC","s_max":[20000.0,20000.0,20000.0],
            "p_min":[0.0,0.0,0.0],"p_max":[20000.0,0.0,0.0],"q_min":[0.0,0.0,0.0],"q_max":[0.0,0.0,0.0],
            "cost":[-1.0,0.0,0.0],"i_max":[1000.0,1000.0,1000.0,10.0]}}""")
        res2 = solve_opf(inet)
        @test res2["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        v   = res2["ibr"]["v"]
        crn2 = v["1"]["cri"] + v["2"]["cri"] + v["3"]["cri"]
        cin2 = v["1"]["cii"] + v["2"]["cii"] + v["3"]["cii"]
        @test hypot(crn2, cin2) ≈ 10.0 atol = 1e-1

        # (c) SINGLE_PHASE IBR: phase and return are ONE current, so a per-conductor
        # i_max = [phase, neutral] must bind at the tighter entry (one constraint,
        # not two). 1φ feeder, incentivise injection, cap the return at 8 A.
        spnet = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[200.0],"v_max":[260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1}},
         "line":{"l":{"bus_from":"src","bus_to":"b","terminal_map_from":["1","n"],
             "terminal_map_to":["1","n"],"linecode":"lc","length":1.0}},
         "ibr":{"v":{"bus":"b","terminal_map":["1","n"],"topology":"SINGLE_PHASE",
             "prime_mover":"GENERIC","s_max":[20000.0],"p_min":[0.0],"p_max":[20000.0],
             "q_min":[0.0],"q_max":[0.0],"cost":[-1.0],"i_max":[20.0,8.0]}}}
        """; from_string=true)
        res3 = solve_opf(spnet)
        @test res3["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        v3 = res3["ibr"]["v"]["1"]
        @test hypot(v3["cri"], v3["cii"]) ≈ 8.0 atol = 1e-1   # binds the tighter of [20, 8]
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-SMAX-LINE: branch apparent-power limit (`s_max` on the line)
    #
    # Class D. Ground-referenced per conductor: |S_k| = v_k·|I_tot,k| ≤ s_max_k.
    # A 1φ feeder with a generator incentivised to export; the phase-conductor
    # s_max is tight (5 kVA) and the neutral loose. Recompute |S| = vm·cm_fr at
    # the from-end and assert it hits the cap while i_max stays slack.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-SMAX-LINE: apparent-power bound — recompute |S| = vm·cm_fr" begin
        net = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[215.0],"v_max":[245.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05}},
         "line":{"l":{"bus_from":"src","bus_to":"b","terminal_map_from":["1","n"],
             "terminal_map_to":["1","n"],"linecode":"lc","length":1.0,
             "i_max":[1000.0,1000.0],"s_max":[5000.0,100000.0]}},
         "generator":{"g":{"bus":"b","terminal_map":["1","n"],"configuration":"WYE",
             "p_min":[0.0],"p_max":[50000.0],"q_min":[0.0],"q_max":[0.0],"cost":[-1.0]}}}
        """; from_string=true)
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        vm  = res["bus"]["src"]["1"]["vm"]
        cm  = res["line"]["l"]["1"]["cm_fr"]
        @test vm * cm ≈ 5000.0 rtol = 5e-3          # |S| binds the phase s_max
        @test cm < 1000.0                            # the loose i_max stays slack
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-SCALE: cone limits are enforced at a large per-unit base (#302)
    #
    # A magnitude/power SOC cone `a² + b² ≤ lim²` has value ~1e-6 at the default
    # s_base = 1e6 for a small feeder (per-unit currents ~1e-3), below Ipopt's
    # absolute constr_viol_tol (1e-4) — so a limit that should force infeasibility
    # was silently accepted. Normalizing the cone to `(a/lim)² + (b/lim)² ≤ 1`
    # makes it O(1) and enforceable. A fixed inductive load whose apparent power
    # exceeds a tight line s_max must be infeasible; a loose limit stays feasible.
    # (s_max routes through the shared `_apparent_power_limit!`, exercised by every
    # line/transformer/generator/IBR/n-winding s_max cone.)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-SCALE: s_max enforced at default per-unit base (#302)" begin
        mknet(slim) = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[200.0,200.0,200.0],"v_max":[250.0,250.0,250.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0943951,2.0943951]}},
         "linecode":{"lc":{"R_series_1_1":0.05,"R_series_2_2":0.05,"R_series_3_3":0.05,"R_series_4_4":0.05}},
         "line":{"l":{"bus_from":"src","bus_to":"b","linecode":"lc","length":10.0,
             "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
             "s_max":[$(slim),$(slim),$(slim),1000000.0]}},
         "load":{"ld":{"bus":"b","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "model":"constant_power","p_nom":[4000.0,4000.0,4000.0],"q_nom":[3000.0,3000.0,3000.0]}}}
        """; from_string=true)
        # |S| per phase ≈ 5 kVA. Tight 2 kVA cap → infeasible; loose 100 kVA → feasible.
        @test solve_opf(mknet(2000.0))["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL")
        @test solve_opf(mknet(100000.0))["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # L-SMAX-XFMR: transformer nameplate cap (`s_rating`)
    #
    # The nameplate is a required field and is always enforced as a per-winding
    # coil apparent-power cap. A 1φ transformer feeding an incentivised generator
    # export: with s_rating present the delivered power is capped near the
    # nameplate; strip s_rating from the dict to solve without the limit.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "L-SMAX-XFMR: s_rating caps transformer throughput" begin
        _base = """
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "b":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                     "v_min":[200.0],"v_max":[260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
         "transformer":{"single_phase":{"t":{"bus_from":"src","bus_to":"b",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "v_nom_from":230.0,"v_nom_to":230.0,"s_rating":8000.0,
             "r_series_from":0.01,"x_series_from":0.05}}},
         "generator":{"g":{"bus":"b","terminal_map":["1","n"],"configuration":"WYE",
             "p_min":[0.0],"p_max":[50000.0],"q_min":[0.0],"q_max":[0.0],"cost":[-1.0]}}}
        """
        net_cap = parse_bmopf(_base; from_string=true)
        net_free = parse_bmopf(_base; from_string=true)
        delete!(net_free["transformer"]["single_phase"]["t"], "s_rating")  # no power limit
        res_on  = solve_opf(net_cap)
        res_off = solve_opf(net_free)
        @test res_on["termination_status"]  in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res_off["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        pg_on  = res_on["generator"]["g"]["1"]["pg"]
        pg_off = res_off["generator"]["g"]["1"]["pg"]
        @test pg_on < pg_off                         # the nameplate cap bites
        # The cap binds the HV (primary) coil apparent power at s_rating. Power
        # flows secondary→primary here, so the secondary export pg = s_rating +
        # transformer copper losses — near, and slightly above, the 8 kVA cap.
        @test isapprox(pg_on, 8000.0; rtol = 0.02) && pg_on ≥ 8000.0

        # The result surfaces the coil apparent power and its cap, and it binds.
        tfr = res_on["transformer"]["t"]["fr"]["1"]
        @test haskey(tfr, "s") && haskey(tfr, "s_max")
        @test isapprox(tfr["s_max"], 8000.0; rtol = 1e-6)
        @test isapprox(tfr["s"], 8000.0; rtol = 5e-3)     # coil |S| at the nameplate
        # the post-solve profiler flags the (near-)active nameplate limit
        f = BMOPFTools.Finding[]; BMOPFTools.solution_check(net_cap, res_on, f)
        @test any(x -> x.code in ("W.SOL.THERMAL_ACTIVE", "E.SOL.THERMAL_VIOLATION") &&
                       x.component_type == :transformer, f)
    end

end
