# General n-winding transformer tests.
#
# Non-solver tests (accessors, star transform, validation, Yprim) always run.
# OPF / power-flow and OpenDSS-parity blocks are gated on _HAS_JUMP_IPOPT / _HAS_ODS
# (globals defined in runtests.jl).

const B = BMOPFTools

# Build an all-wye n_winding transformer dict from per-winding (bus, kv_LL, %r)
# and pairwise short-circuit reactances (%) on winding-1's base.
function _nw_xfmr(windings, xsc_pct; s_rating=30e6, kva=30000, g=0.0, b=0.0)
    kv1 = windings[1][2]
    zb1 = (kv1 * 1e3)^2 / s_rating            # per-phase Ω, winding-1 base
    ws = [Dict{String,Any}(
            "bus" => bus, "terminal_map" => ["a", "b", "c", "n"],
            "v_nom" => kv * 1e3 / sqrt(3), "configuration" => "WYE",
            "r_winding" => pr / 100 * (kv * 1e3)^2 / s_rating)
          for (bus, kv, pr) in windings]
    xsc = Dict{String,Any}(k => v / 100 * zb1 for (k, v) in xsc_pct)
    d = Dict{String,Any}("windings" => ws, "x_sc" => xsc, "s_rating" => s_rating)
    g != 0.0 && (d["g_no_load"] = g)
    b != 0.0 && (d["b_no_load"] = b)
    d
end

@testset "n_winding — accessors & star transform" begin
    xf = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4), ("b3", 4.16, 0.4)],
                  Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0))
    ws = B._nw_windings(xf)
    @test length(ws) == 3
    @test ws[1].bus == "b1" && ws[1].connection == "WYE"
    @test B._nw_turns_ratios(xf)[1] == 1.0
    @test B._nw_turns_ratios(xf)[2] ≈ (24.9/sqrt(3)) / (115.0/sqrt(3))

    # ZB matrix (n=3, ignore winding resistance here): ZB[i,i]=X_{1,i+1},
    # ZB[1,2]=½(X12+X13−X23) (referred to winding 1).
    zb1 = (115e3)^2 / 30e6
    xfX = _nw_xfmr([("b1",115.0,0.0),("b2",24.9,0.0),("b3",4.16,0.0)],
                   Dict("1_2"=>8.0,"1_3"=>8.0,"2_3"=>6.0))
    ZB = B._nw_zb_matrix(xfX)
    @test size(ZB) == (2, 2)
    @test imag(ZB[1,1]) ≈ 8 / 100 * zb1
    @test imag(ZB[2,2]) ≈ 8 / 100 * zb1
    @test imag(ZB[1,2]) ≈ 0.5 * (8 + 8 - 6) / 100 * zb1
    @test ZB[1,2] ≈ ZB[2,1]                                   # reciprocal

    # n = 2 → 1×1 ZB = Z_{1,2}.
    xf2 = _nw_xfmr([("b1", 115.0, 0.0), ("b2", 24.9, 0.0)], Dict("1_2" => 8.0))
    @test size(B._nw_zb_matrix(xf2)) == (1, 1)
    @test imag(B._nw_zb_matrix(xf2)[1,1]) ≈ 8 / 100 * zb1

    @test B._nw_phase_terminals(["a", "b", "c", "n"]) == (["a", "b", "c"], "n")
end

@testset "n_winding — edge cases (ZB exactness, negative entry, dual-secondary)" begin
    # The ZB matrix reconstructs EVERY pairwise short-circuit reactance exactly,
    # for any n (no approximation). Check n = 4 with non-star-consistent data.
    w4 = [("hv",115.0,0.0),("mv",24.9,0.0),("lv",4.16,0.0),("tv",2.4,0.0)]
    xsc4 = Dict("1_2"=>8.0,"1_3"=>8.0,"1_4"=>8.0,"2_3"=>6.0,"2_4"=>6.0,"3_4"=>4.0)
    xf4 = _nw_xfmr(w4, xsc4)
    zb1 = (115e3)^2 / 30e6
    ZB = B._nw_zb_matrix(xf4)
    @test size(ZB) == (3, 3)
    # Reconstruct pairwise from ZB and compare to the inputs (imag parts, ref-1).
    recon(p, q) = p == 1 ? imag(ZB[q-1,q-1]) :
                  q == 1 ? imag(ZB[p-1,p-1]) :
                  -(2*imag(ZB[p-1,q-1]) - imag(ZB[p-1,p-1]) - imag(ZB[q-1,q-1]))
    for (k, v) in xsc4
        i, j = parse.(Int, split(k, "_"))
        @test recon(i, j) ≈ v / 100 * zb1
    end

    # A negative ZB diagonal is physical for n ≥ 3: X23 ≫ X12,X13 ⇒ ZB[1,1] uses
    # Z_{1,2} which stays positive, but the equivalent star leg X1 < 0 shows up as
    # a negative off-diagonal coupling — the Yprim must still build and stay valid.
    xfneg = _nw_xfmr([("hv",115.0,0.0),("mv",24.9,0.0),("lv",4.16,0.0)],
                     Dict("1_2"=>3.0,"1_3"=>3.0,"2_3"=>10.0))
    @test imag(B._nw_zb_matrix(xfneg)[1,2]) < 0             # ½(3+3−10) < 0
    nodes, Y = B.nwinding_yprim(xfneg)                       # still a valid Yprim
    @test maximum(abs.(Y .- transpose(Y))) < 1e-9

    # Dual-secondary (two windings on the same bus): turns ratios independent of
    # the shared bus.
    xfds = _nw_xfmr([("b001",199.0,0.01),("b002",24.0,0.1),("b002",24.0,0.1)],
                    Dict("1_2"=>9.6,"1_3"=>9.6,"2_3"=>19.0))
    N = B._nw_turns_ratios(xfds)
    @test N[1] == 1.0
    @test N[2] ≈ N[3]
end

@testset "n_winding — validation (completeness / spec)" begin
    good = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4), ("b3", 4.16, 0.4)],
                    Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0))
    net = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => good)))

    f = Finding[]; completeness_check(net, f); spec_conformance_check(net, f)
    @test isempty([x for x in f if x.severity == ERROR])

    # Missing an x_sc pair → completeness error.
    bad1 = deepcopy(good); delete!(bad1["x_sc"], "2_3")
    net1 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => bad1)))
    f1 = Finding[]; completeness_check(net1, f1)
    @test any(x -> x.code == "E.COMP.MISSING_REQUIRED", f1)

    # Missing a required per-winding field → completeness error.
    bad2 = deepcopy(good); delete!(bad2["windings"][2], "v_nom")
    net2 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => bad2)))
    f2 = Finding[]; completeness_check(net2, f2)
    @test any(x -> x.code == "E.COMP.MISSING_REQUIRED", f2)

    # DELTA winding is now supported: no not-implemented (or any) spec error. The
    # delta coil is line-to-line (v_nom = kV_LL, three phase terminals, no neutral).
    d3 = deepcopy(good)
    d3["windings"][3]["configuration"]   = "DELTA"
    d3["windings"][3]["terminal_map"] = ["a", "b", "c"]
    d3["windings"][3]["v_nom"]        = 4.16e3            # line-to-line coil voltage
    net3 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => d3)))
    f3 = Finding[]; spec_conformance_check(net3, f3)
    @test !any(x -> x.code == "E.SPEC.XFMR_NOT_IMPLEMENTED", f3)
    @test isempty([x for x in f3 if x.severity == ERROR])

    # A DELTA winding with fewer than two phase conductors → arity warning.
    d4 = deepcopy(d3); d4["windings"][3]["terminal_map"] = ["a"]
    net4 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => d4)))
    f4 = Finding[]; spec_conformance_check(net4, f4)
    @test any(x -> x.code == "W.SPEC.XFMR_TMAP_ARITY", f4)
end

@testset "n_winding — visible to analysis/validation (#291)" begin
    _b() = Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                            "perfectly_grounded_terminals" => ["n"])
    xf = _nw_xfmr([("hv",115.0,0.3),("mv",24.9,0.4),("lv",4.16,0.4)],
                  Dict("1_2"=>8.0,"1_3"=>8.0,"2_3"=>6.0); s_rating=30e6)
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}("hv"=>_b(),"mv"=>_b(),"lv"=>_b()),
        "voltage_source" => Dict{String,Any}("s"=>Dict{String,Any}("bus"=>"hv",
            "terminal_map"=>["a","b","c"],"v_magnitude"=>[66395.0,66395.0,66395.0],
            "v_angle"=>[0.0,-2.0944,2.0944])),
        "load" => Dict{String,Any}(
            "lmv"=>Dict{String,Any}("bus"=>"mv","terminal_map"=>["a","b","c","n"],
                "configuration"=>"WYE","p_nom"=>[5e6,5e6,5e6],"q_nom"=>[1e6,1e6,1e6]),
            "llv"=>Dict{String,Any}("bus"=>"lv","terminal_map"=>["a","b","c","n"],
                "configuration"=>"WYE","p_nom"=>[2e6,2e6,2e6],"q_nom"=>[5e5,5e5,5e5])),
        "transformer" => Dict{String,Any}("n_winding"=>Dict{String,Any}("t1"=>xf)))

    # operational: the n_winding gets a utilisation entry that counts the load
    # on its downstream (winding 2 & 3) buses — previously skipped entirely.
    rep = analyze(net)
    util = rep.results[:operational]["transformer_utilisation"]
    e = findfirst(x -> x["id"] == "t1", util)
    @test e !== nothing
    @test util[e]["s_load_va"] > 20e6            # ≈ 21.5 MVA downstream

    # integrity: a clean n_winding produces no false floating/unused terminals,
    # and a dangling winding-bus reference IS caught.
    f = Finding[]; integrity_check(net, f)
    @test !any(x -> x.code in ("W.INT.FLOATING_LOAD_TERMINAL",
                               "W.INT.UNUSED_BUS_TERMINAL"), f)
    bad = deepcopy(net); bad["transformer"]["n_winding"]["t1"]["windings"][2]["bus"] = "ghost"
    fb = Finding[]; integrity_check(bad, fb)
    @test any(x -> x.code == "E.INT.UNKNOWN_BUS", fb)

    # fix: an islanded n_winding (no path to a source) is pruned by the
    # largest-component pass instead of being left dangling.
    isl = deepcopy(net)
    isl["bus"]["i1"] = _b(); isl["bus"]["i2"] = _b()
    isl["transformer"]["n_winding"]["t2"] =
        _nw_xfmr([("i1",4.16,0.3),("i2",0.4,0.4)], Dict("1_2"=>5.0); s_rating=1e6)
    isl2, _ = fix_case(isl; recipe=FixRecipe(apply_simplify_network=false,
        apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
        apply_source_bus_bounds=false))
    @test !haskey(isl2["bus"], "i1")                             # islanded bus dropped
    @test !haskey(isl2["transformer"]["n_winding"], "t2")        # dangling xfmr pruned
    @test haskey(isl2["transformer"]["n_winding"], "t1")         # sourced one kept
end

@testset "n_winding — reactance sign / realisability (physics)" begin
    _net(d) = Dict{String,Any}("transformer" =>
        Dict{String,Any}("n_winding" => Dict{String,Any}("t1" => d)))
    codes(net) = (f = Finding[]; B.domain_rules_check(net, f);
                  Set(x.code for x in f))

    # (1) Physically well-formed data → no sign/PSD finding.
    good = _nw_xfmr([("b1",115.0,0.3),("b2",24.9,0.4),("b3",4.16,0.4)],
                    Dict("1_2"=>8.0,"1_3"=>8.0,"2_3"=>6.0))
    c = codes(_net(good))
    @test !("W.DOM.XFMR_X_NONINDUCTIVE" in c)
    @test !("W.DOM.XFMR_X_NOT_PSD" in c)

    # (2) A NEGATIVE star/T branch that is still physical MUST pass. Here
    # X23 ≫ X12,X13 drives the ZB off-diagonal ½(3+3−10) < 0 (a negative
    # equivalent star leg), but imag(ZB)=[[3,−2],[−2,3]] has eigenvalues {1,5}
    # → PSD, so nothing is flagged. This is the whole point of the physics-based
    # discriminator: negative branch ≠ error.
    legit_neg = _nw_xfmr([("b1",115.0,0.0),("b2",24.9,0.0),("b3",4.16,0.0)],
                         Dict("1_2"=>3.0,"1_3"=>3.0,"2_3"=>10.0))
    @test imag(B._nw_zb_matrix(legit_neg)[1,2]) < 0        # negative star branch
    @test minimum(B._nw_xb_eigvals(legit_neg)) > 0         # yet PSD
    c2 = codes(_net(legit_neg))
    @test !("W.DOM.XFMR_X_NONINDUCTIVE" in c2)
    @test !("W.DOM.XFMR_X_NOT_PSD" in c2)

    # (3) All pairwise reactances positive but MUTUALLY INCONSISTENT: X23 = 10 ≫
    # X12 = X13 = 1 violates the realisability triangle X12·X13 ≥ ¼(X12+X13−X23)².
    # imag(ZB)=[[1,−4],[−4,1]] → eigenvalue −3 < 0 → not realisable → PSD flag.
    not_psd = _nw_xfmr([("b1",115.0,0.0),("b2",24.9,0.0),("b3",4.16,0.0)],
                       Dict("1_2"=>1.0,"1_3"=>1.0,"2_3"=>10.0))
    @test all(v -> v > 0, values(not_psd["x_sc"]))         # every pairwise > 0
    c3 = codes(_net(not_psd))
    @test "W.DOM.XFMR_X_NOT_PSD" in c3
    @test !("W.DOM.XFMR_X_NONINDUCTIVE" in c3)             # no negative pairwise

    # (4) A negative MEASURABLE pairwise short-circuit reactance → non-inductive.
    neg_pair = _nw_xfmr([("b1",115.0,0.0),("b2",24.9,0.0),("b3",4.16,0.0)],
                        Dict("1_2"=>-8.0,"1_3"=>8.0,"2_3"=>6.0))
    c4 = codes(_net(neg_pair))
    @test "W.DOM.XFMR_X_NONINDUCTIVE" in c4

    # (5) Two-bus subtype: an individual leg may be negative (valid star/T split)
    # as long as the TOTAL series reactance stays inductive — not flagged...
    split_ok = Dict{String,Any}("transformer" => Dict{String,Any}(
        "single_phase" => Dict{String,Any}("s1" => Dict{String,Any}(
            "x_series_from" => 1.0, "x_series_to" => -0.2))))
    @test !("W.DOM.XFMR_X_NONINDUCTIVE" in codes(split_ok))
    # ...but a negative TOTAL (the measurable short-circuit reactance) is flagged.
    split_bad = Dict{String,Any}("transformer" => Dict{String,Any}(
        "single_phase" => Dict{String,Any}("s1" => Dict{String,Any}(
            "x_series_from" => 0.1, "x_series_to" => -0.5))))
    @test "W.DOM.XFMR_X_NONINDUCTIVE" in codes(split_bad)
end

@testset "n_winding — Yprim symmetry & passivity" begin
    xf = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4), ("b3", 4.16, 0.4)],
                  Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0);
                  g = 1e-6, b = 5e-6)
    nodes, Y = B.nwinding_yprim(xf)
    @test length(nodes) == 12                      # 3 windings × (abc + n)
    @test maximum(abs.(Y .- transpose(Y))) < 1e-9  # reciprocal
    # Passive: quadratic form of the symmetric part is non-negative.
    V = randn(ComplexF64, length(nodes))
    @test real(V' * ((Y + Y') / 2) * V) > -1e-6
    # A uniform voltage offset draws no current (no shunt-to-ground branch).
    @test maximum(abs.(sum(Y, dims = 2))) < 1e-8

    # The magnetising shunt sits on WINDING 2 (b2), not winding 1 — OpenDSS
    # places the exciting branch on winding 2 (verified against its Yprim).
    # Difference against a shunt-free copy isolates the branch: it must land
    # entirely on the winding-2 (b2) coil, phase-to-neutral.
    xf0 = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4), ("b3", 4.16, 0.4)],
                   Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0))
    _, Y0 = B.nwinding_yprim(xf0)
    D = Y .- Y0
    b2 = [i for (i, nd) in enumerate(nodes) if nd[1] == "b2"]   # winding-2 nodes
    others = setdiff(1:length(nodes), b2)
    @test maximum(abs.(D[others, others])) < 1e-12             # nothing off winding 2
    y = 1e-6 + im*5e-6                                          # per-coil admittance
    b2ph = [i for i in b2 if nodes[i][2] in ("a","b","c")]
    b2n  = only(i for i in b2 if nodes[i][2] == "n")
    for i in b2ph
        @test isapprox(D[i, i], y;    atol=1e-12)              # phase diagonal
        @test isapprox(D[i, b2n], -y; atol=1e-12)              # phase→neutral
    end
    @test isapprox(D[b2n, b2n], 3y; atol=1e-12)                # neutral diagonal

    # Delta tertiary (YNynd): the delta coil is line-to-line (3 phase terminals,
    # no neutral, v_nom = kV_LL). Yprim must still build, be reciprocal & passive.
    xfd = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4), ("b3", 4.16, 0.4)],
                   Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0))
    xfd["windings"][3]["configuration"]   = "DELTA"
    xfd["windings"][3]["terminal_map"] = ["a", "b", "c"]
    xfd["windings"][3]["v_nom"]        = 4.16e3            # line-to-line
    nd, Yd = B.nwinding_yprim(xfd)
    @test length(nd) == 11                                # 4 + 4 + 3
    @test maximum(abs.(Yd .- transpose(Yd))) < 1e-9       # reciprocal
    Vd = randn(ComplexF64, length(nd))
    @test real(Vd' * ((Yd + Yd') / 2) * Vd) > -1e-6       # passive
    @test maximum(abs.(sum(Yd, dims = 2))) < 1e-8         # no shunt-to-ground
end

if _HAS_JUMP_IPOPT
    @testset "n_winding — OPF/PF self-consistency" begin
        xf = _nw_xfmr([("hv", 115.0, 0.3), ("mv", 24.9, 0.4), ("lv", 4.16, 0.4)],
                      Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0))
        g(b)  = Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                                 "neutral_terminal" => "n",
                                 "perfectly_grounded_terminals" => ["n"])
        vpn(kv) = kv * 1e3 / sqrt(3)
        net = Dict{String,Any}("name" => "nw3",
            "bus" => Dict{String,Any}("hv" => g("hv"), "mv" => g("mv"), "lv" => g("lv")),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
                "bus" => "hv", "terminal_map" => ["a","b","c","n"],
                "v_magnitude" => [vpn(115),vpn(115),vpn(115),0.0],
                "v_angle" => [0.0,-2.0943951,2.0943951,0.0])),
            "load" => Dict{String,Any}(
                "ldmv" => Dict{String,Any}("bus"=>"mv","terminal_map"=>["a","b","c","n"],
                    "configuration"=>"WYE","p_nom"=>[1e6,1e6,1e6],"q_nom"=>[2e5,2e5,2e5],
                    "model"=>"constant_power"),
                "ldlv" => Dict{String,Any}("bus"=>"lv","terminal_map"=>["a","b","c","n"],
                    "configuration"=>"WYE","p_nom"=>[5e5,5e5,5e5],"q_nom"=>[1e5,1e5,1e5],
                    "model"=>"constant_power")),
            "transformer" => Dict{String,Any}("n_winding" =>
                Dict{String,Any}("t1" => xf)))

        res = solve_pf(net; optimizer = Ipopt.Optimizer)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test haskey(res["transformer"], "t1")
        @test haskey(res["transformer"]["t1"], "w1")    # per-winding result keying
        # Secondary voltages sit near nominal (loaded, so slightly below).
        mva = abs(res["bus"]["mv"]["a"]["vr"] + im*res["bus"]["mv"]["a"]["vi"])
        lva = abs(res["bus"]["lv"]["a"]["vr"] + im*res["bus"]["lv"]["a"]["vi"])
        @test 0.9 * vpn(24.9) < mva < vpn(24.9)
        @test 0.9 * vpn(4.16) < lva < vpn(4.16)

        # Per-winding current limit `i_max`: the unconstrained winding-2 (MV)
        # coil current sets the scale; a loose cap (2×) is inert, a tight cap
        # (0.5×) cannot be met with the fixed load → the solve is infeasible.
        i2 = res["transformer"]["t1"]["w2"]["1"]["cm"]
        @test i2 > 0
        loose = deepcopy(net); loose["transformer"]["n_winding"]["t1"]["windings"][2]["i_max"] = 2 * i2
        rl = solve_pf(loose; optimizer = Ipopt.Optimizer)
        @test rl["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test isapprox(rl["transformer"]["t1"]["w2"]["1"]["cm"], i2; rtol = 1e-4)  # inert

        tight = deepcopy(net); tight["transformer"]["n_winding"]["t1"]["windings"][2]["i_max"] = 0.5 * i2
        rt = solve_pf(tight; optimizer = Ipopt.Optimizer)
        # Either Ipopt flags infeasibility, or it clamps at the limit — never
        # returns the unconstrained (over-limit) current as a clean solve.
        @test rt["termination_status"] ∉ ("LOCALLY_SOLVED", "OPTIMAL") ||
              rt["transformer"]["t1"]["w2"]["1"]["cm"] <= 0.5 * i2 * (1 + 1e-3)

        # Regression (issue #271): the no-load (magnetising) shunt branch
        # guarded on an undefined variable `nW` (the local is `n`), so any
        # n_winding transformer with nonzero g_no_load/b_no_load threw
        # UndefVarError at model build. No fixture exercised it. Build the
        # same transformer with a core-loss branch on winding 2 and confirm
        # it (a) solves and (b) adds real loss vs the lossless-core baseline.
        xf_core = _nw_xfmr([("hv", 115.0, 0.3), ("mv", 24.9, 0.4), ("lv", 4.16, 0.4)],
                           Dict("1_2" => 8.0, "1_3" => 8.0, "2_3" => 6.0);
                           g = 2e-4, b = 1e-3)   # SI siemens across the MV coil
        net_core = deepcopy(net)
        net_core["transformer"]["n_winding"]["t1"] = xf_core
        rc = solve_pf(net_core; optimizer = Ipopt.Optimizer)
        @test rc["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test haskey(rc["transformer"]["t1"], "w1")
        # Core conductance g>0 dissipates real power → transformer real loss
        # strictly exceeds the g=b=0 baseline (the device-loss identity sums
        # the magnetising-branch injection).
        p_base = res["transformer"]["t1"]["loss"]["p_loss"]
        p_core = rc["transformer"]["t1"]["loss"]["p_loss"]
        @test p_core > p_base + 1.0
    end

end
