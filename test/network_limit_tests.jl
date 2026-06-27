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
    # L-A8: inverter/generator apparent-power limit (`s_max`)
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

end
