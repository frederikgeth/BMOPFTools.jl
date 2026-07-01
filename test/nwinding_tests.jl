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
    end

end
