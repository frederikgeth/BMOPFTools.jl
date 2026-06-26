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
            "v_ref" => kv * 1e3 / sqrt(3), "connection" => "WYE",
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

    # Exact star formula for n = 3: X1 = ½(X12+X13−X23) etc. (ref-1 base).
    zb1 = (115e3)^2 / 30e6
    X = B._nw_star_reactances_ref1(xf)
    @test X[1] ≈ 0.5 * (8 + 8 - 6) / 100 * zb1
    @test X[2] ≈ 0.5 * (8 + 6 - 8) / 100 * zb1
    @test X[3] ≈ 0.5 * (8 + 6 - 8) / 100 * zb1

    # n = 2 is under-determined: all leakage on winding 1.
    xf2 = _nw_xfmr([("b1", 115.0, 0.3), ("b2", 24.9, 0.4)], Dict("1_2" => 8.0))
    X2 = B._nw_star_reactances_ref1(xf2)
    @test X2[2] == 0.0
    @test X2[1] ≈ 8 / 100 * zb1

    @test B._nw_phase_terminals(["a", "b", "c", "n"]) == (["a", "b", "c"], "n")
end

@testset "n_winding — edge cases (n≥4, negative leg, dual-secondary)" begin
    # n = 4, star-INCONSISTENT pairwise data → least-squares residual > 0 and the
    # approximation warning fires.
    w4 = [("hv",115.0,0.3),("mv",24.9,0.4),("lv",4.16,0.4),("tv",2.4,0.4)]
    xf4 = _nw_xfmr(w4, Dict("1_2"=>8.0,"1_3"=>8.0,"1_4"=>8.0,
                            "2_3"=>6.0,"2_4"=>6.0,"3_4"=>4.0))
    @test B._nw_star_residual(xf4) > 1e-3
    net4 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t4" => xf4)))
    f4 = Finding[]; spec_conformance_check(net4, f4)
    @test any(x -> x.code == "W.SPEC.XFMR_NWINDING_APPROX", f4)

    # n = 4, star-CONSISTENT data (X = [5,3,3,1] ⇒ X_ij = X_i+X_j) → residual ≈ 0,
    # no approximation warning.
    cons = Dict("1_2"=>8.0,"1_3"=>8.0,"1_4"=>6.0,"2_3"=>6.0,"2_4"=>4.0,"3_4"=>4.0)
    xfc = _nw_xfmr(w4, cons)
    @test B._nw_star_residual(xfc) < 1e-9
    netc = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("tc" => xfc)))
    fc = Finding[]; spec_conformance_check(netc, fc)
    @test !any(x -> x.code == "W.SPEC.XFMR_NWINDING_APPROX", fc)
    # n = 3 is always exact.
    @test B._nw_star_residual(_nw_xfmr([("a",1.0,0.1),("b",1.0,0.1),("c",1.0,0.1)],
                                       Dict("1_2"=>5.0,"1_3"=>5.0,"2_3"=>3.0))) == 0.0

    # A negative star leg is physical for n ≥ 3: X23 ≫ X12,X13 ⇒ X1 < 0.
    xfneg = _nw_xfmr([("hv",115.0,0.3),("mv",24.9,0.4),("lv",4.16,0.4)],
                     Dict("1_2"=>3.0,"1_3"=>3.0,"2_3"=>10.0))
    @test B._nw_star_reactances_ref1(xfneg)[1] < 0          # ½(3+3−10) < 0
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
    bad2 = deepcopy(good); delete!(bad2["windings"][2], "v_ref")
    net2 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => bad2)))
    f2 = Finding[]; completeness_check(net2, f2)
    @test any(x -> x.code == "E.COMP.MISSING_REQUIRED", f2)

    # DELTA winding → not-implemented spec error (reserved scope).
    bad3 = deepcopy(good); bad3["windings"][3]["connection"] = "DELTA"
    net3 = Dict{String,Any}("transformer" => Dict{String,Any}(
        "n_winding" => Dict{String,Any}("t1" => bad3)))
    f3 = Finding[]; spec_conformance_check(net3, f3)
    @test any(x -> x.code == "E.SPEC.XFMR_NOT_IMPLEMENTED", f3)
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
    end

end
