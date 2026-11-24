# Robust Opti-KRON prototype (src/network/opti_kron.jl, ext/BMOPFOpfExt/opti_kron.jl)

using Test, BMOPFTools, LinearAlgebra, Random

const _OK_HAS_HIGHS = try
    @eval using JuMP, HiGHS
    true
catch
    false
end
const _OK_HAS_IPOPT = try
    @eval using JuMP, Ipopt
    true
catch
    false
end

# Schur complement of the full passive Ybus onto the phase nodes of `kept`.
function _ok_schur(net, kept; terms=["1", "2", "3"])
    y = ybus_passive(net)
    K = vcat([[y.index[(b, t)] for t in terms] for b in kept]...)
    R = setdiff(1:size(y.Y, 1), K)
    Matrix{ComplexF64}(y.Y[K, K]) - Matrix{ComplexF64}(y.Y[K, R]) * (Matrix{ComplexF64}(y.Y[R, R]) \ Matrix{ComplexF64}(y.Y[R, K]))
end
function _ok_phase_block(net, kept; terms=["1", "2", "3"])
    y = ybus_passive(net)
    K = vcat([[y.index[(b, t)] for t in terms] for b in kept]...)
    Matrix{ComplexF64}(y.Y[K, K])
end

# 3-wire radial feeder: s — b1 — b2 — b3, b2 — b4, b4 — b5; uncoupled phases.
function _ok_test_feeder(; r=4e-4, x=2.5e-4, len=100.0)
    lc = Dict{String,Any}()
    for a in 1:3, b in 1:3
        lc["R_series_$(a)_$(b)"] = a == b ? r : 0.0
        lc["X_series_$(a)_$(b)"] = a == b ? x : 0.0
        for side in ("from", "to"), q in ("G", "B")
            lc["$(q)_$(side)_$(a)_$(b)"] = 0.0
        end
    end
    tn = ["1", "2", "3"]
    bus = Dict(b => Dict("terminal_names" => tn) for b in ["s", "b1", "b2", "b3", "b4", "b5"])
    edges = [("s", "b1"), ("b1", "b2"), ("b2", "b3"), ("b2", "b4"), ("b4", "b5")]
    line = Dict("l$k" => Dict("bus_from" => a, "bus_to" => b, "length" => len,
                              "linecode" => "lc", "terminal_map_from" => tn,
                              "terminal_map_to" => tn) for (k, (a, b)) in enumerate(edges))
    load = Dict("d$b" => Dict("bus" => b, "configuration" => "WYE", "model" => "CONSTANT_POWER",
                              "p_nom" => [3000.0, 2000.0, 1000.0], "q_nom" => [500.0, 300.0, 100.0],
                              "terminal_map" => tn, "v_nom" => [230.0, 230.0, 230.0])
                for b in ["b1", "b3", "b4", "b5"])
    net = Dict("bus" => bus, "line" => line, "linecode" => Dict("lc" => lc), "load" => load,
               "voltage_source" => Dict("src" => Dict("bus" => "s", "terminal_map" => tn,
                   "v_magnitude" => [230.0, 230.0, 230.0], "v_angle" => [0.0, -2π / 3, 2π / 3])),
               "terminal_conventions" => Dict("phase" => tn, "neutral" => String[]))
    parse_bmopf(BMOPFTools.JSON3.write(net); from_string=true)
end

function _ok_test_samples(m, net; N=12, seed=7)
    rng = Random.MersenneTwister(seed)
    ids = sort(collect(keys(net["load"])))
    mp = Dict(id => [0.3 + rand(rng) for _ in 1:N] for id in ids)
    opti_kron_load_injections(m, net, mp)
end

@testset "robust Opti-KRON prototype" begin
    net = _ok_test_feeder()
    m = opti_kron_model(net; H=2, sbase=1e3)

    @testset "model structure" begin
        @test m.buses[1] == "s"
        @test length(m.rows) == 18
        @test m.n_mesh_edges == 0
        @test all(m.zone .== 1)
        # every bus has its self pair; pairs are within H tree hops
        for j in 1:length(m.buses)
            @test any(p -> m.pair_i[p] == j, m.cand[j])
        end
        @test all(length(p) ≤ m.H + 1 for p in m.pair_path)
        # the source bus can only represent itself
        @test m.cand[1] == [findfirst(p -> m.pair_i[p] == 1 && m.pair_j[p] == 1, eachindex(m.pair_i))]
    end

    @testset "sensitivity reduces to LinDistFlow on uncoupled phases" begin
        r = 4e-4 * 100; x = 2.5e-4 * 100
        depth(b) = Dict("s" => 0, "b1" => 1, "b2" => 2, "b3" => 3, "b4" => 3, "b5" => 4)[b]
        shared(a, b) = begin
            # number of common edges on the source paths of a and b
            pa = Dict("b1" => ["s", "b1"], "b2" => ["s", "b1", "b2"], "b3" => ["s", "b1", "b2", "b3"],
                      "b4" => ["s", "b1", "b2", "b4"], "b5" => ["s", "b1", "b2", "b4", "b5"], "s" => ["s"])
            length(intersect(pa[a], pa[b])) - 1
        end
        nr = length(m.rows)
        for (ri, (i, t)) in enumerate(m.rows), (rk, (k, t2)) in enumerate(m.rows)
            exp_p = t == t2 ? shared(m.buses[i], m.buses[k]) * r * 1e3 / 230^2 : 0.0
            exp_q = t == t2 ? shared(m.buses[i], m.buses[k]) * x * 1e3 / 230^2 : 0.0
            @test isapprox(m.K[ri, rk], exp_p; atol=1e-12)
            @test isapprox(m.K[ri, rk+nr], exp_q; atol=1e-12)
        end
    end

    U = _ok_test_samples(m, net)

    @testset "load injections" begin
        nr = length(m.rows)
        @test size(U) == (2nr, 12)
        @test all(U[1:nr, :] .≤ 0)                      # loads are negative injections
        @test all(iszero, U[m.rowof[(1, "1")], :])      # nothing at the source
    end

    @testset "worst cases (Table I) are attained by their maximizers" begin
        rng = Random.MersenneTwister(3)
        sets = [OptiKronBox(U), OptiKronHull(U), OptiKronEllipsoid(U),
                OptiKronWasserstein(U; p=1), OptiKronWasserstein(U; p=2),
                OptiKronWasserstein(U; p=Inf)]
        for S in sets
            C = randn(rng, 5, length(S.idx))
            w = BMOPFTools._ok_wc(S, C)
            for r in 1:5
                ustar = BMOPFTools._ok_argmax(S, C[r, :])
                @test isapprox(dot(C[r, :], ustar), w[r]; rtol=1e-9, atol=1e-12)
            end
            # the worst case dominates every training sample
            @test all(w .≥ vec(maximum(C * S.samples, dims=2)) .- 1e-9)
        end
        # box worst case equals the vertex enumeration on a 3-coordinate slice
        B = OptiKronBox(U)
        c = zeros(length(B.idx)); c[1:3] .= [1.0, -2.0, 0.5]
        verts = [B.ubar .+ B.delta .* vcat([s1, s2, s3], zeros(length(B.idx) - 3))
                 for s1 in (-1, 1), s2 in (-1, 1), s3 in (-1, 1)]
        @test BMOPFTools._ok_wc(B, reshape(c, 1, :))[1] ≈ maximum(dot(c, v) for v in verts)
    end

    @testset "Wasserstein radius calibration" begin
        for p in (1, 2, Inf)
            Wh = OptiKronWasserstein(U; p=p)
            Wn = OptiKronWasserstein(U; p=p, radius=:nearest)
            @test 0 ≤ Wh.radius ≤ Wn.radius + 1e-12   # hull is closer than any vertex
            @test OptiKronWasserstein(U; p=p, radius=0.5).radius == 0.5
        end
        # a sample inside the hull of the others has zero distance
        Y = [0.0 1.0 0.0; 0.0 0.0 1.0]
        θ = BMOPFTools._ok_simplex_projection_ls(Y, [0.25, 0.25])
        @test norm(Y * θ .- [0.25, 0.25]) < 1e-8
        @test sum(θ) ≈ 1 && all(θ .≥ 0)
        θ = BMOPFTools._ok_simplex_projection_ls(Y, [1.0, 1.0])
        @test Y * θ ≈ [0.5, 0.5] atol = 1e-8
    end

    @testset "errors" begin
        ident = collect(1:length(m.buses))
        @test all(iszero, opti_kron_errors(m, ident, U))
        # everything merged into the source: error = −(v_j − 1)
        allsrc = ones(Int, length(m.buses))
        @test opti_kron_errors(m, allsrc, U) ≈ -(m.K * U)
    end

    @testset "screening" begin
        S = OptiKronBox(U)
        loose = opti_kron_screen(m, S, 1.0)
        @test all(loose.keep)
        @test loose.n_redundant > 0
        tight = opti_kron_screen(m, S, 1e-9)
        @test all(tight.keep[p] == (m.pair_i[p] == m.pair_j[p]) for p in eachindex(tight.keep))
        H = OptiKronHull(U)
        mid = opti_kron_screen(m, H, 2e-3)
        @test count(mid.keep) ≤ length(mid.keep)
        # screening never removes a pair that a certified assignment uses
    end

    if _OK_HAS_HIGHS
        @testset "Algorithm 1 (HiGHS)" begin
            for S in (OptiKronBox(U), OptiKronHull(U), OptiKronEllipsoid(U),
                      OptiKronWasserstein(U; p=2))
                for Ebar in (5e-4, 2e-3, 1e-2)
                    res = opti_kron_reduction(m, S, Ebar; optimizer=HiGHS.Optimizer)
                    @test res.status == :optimal
                    @test res.max_violation ≤ 1e-6 * Ebar
                    w = opti_kron_worst_errors(m, res.assignment, S)
                    @test maximum(w) ≤ Ebar * (1 + 1e-6)
                    @test res.assignment[1] == 1
                    # without screening the certified optimum is the same
                    res0 = opti_kron_reduction(m, S, Ebar; optimizer=HiGHS.Optimizer, screen=false)
                    @test length(res0.super_nodes) == length(res.super_nodes)
                end
            end
            # convex hull: constraint generation == direct model with all samples
            Hs = OptiKronHull(U)
            for Ebar in (1e-3, 4e-3)
                a1 = opti_kron_reduction(m, Hs, Ebar; optimizer=HiGHS.Optimizer)
                direct = opti_kron_reduction(m, Hs, Ebar; optimizer=HiGHS.Optimizer, initial=U)
                @test length(a1.super_nodes) == length(direct.super_nodes)
                @test length(direct.history) == 1
            end
            # a huge threshold collapses everything within H hops onto the source
            big = opti_kron_reduction(opti_kron_model(net; H=4), OptiKronBox(U), 1.0;
                                      optimizer=HiGHS.Optimizer)
            @test big.super_nodes == ["s"]
            # a tiny threshold keeps every loaded/voltage-distinct bus
            tiny = opti_kron_reduction(m, OptiKronBox(U), 1e-9; optimizer=HiGHS.Optimizer)
            @test tiny.reduction == 0.0
        end
    end

    @testset "fill-in detection and required buses" begin
        mh = opti_kron_model(net; H=4)
        id(b) = mh.busof[b]
        sup = collect(1:length(mh.buses))
        # b2 joins b1 (towards s), b3 and b4: keeping b3 and b4 while
        # eliminating b2 creates a triangle b1–b3–b4
        sup[id("b2")] = id("b1")
        @test BMOPFTools._ok_radial_violations(mh, sup) == [id("b2")]
        sup[id("b3")] = id("b1")                       # now only b4 side has a super-node
        @test isempty(BMOPFTools._ok_radial_violations(mh, sup))
        @test opti_kron_required_buses(net) == ["s"]
    end

    @testset "kron_reduce_buses" begin
        mh = opti_kron_model(net; H=4)
        id(b) = mh.busof[b]
        sup = collect(1:length(mh.buses))
        sup[id("b1")] = id("b2"); sup[id("b3")] = id("b2"); sup[id("b4")] = id("b5")
        red = kron_reduce_buses(net, mh, sup)
        log = red["_kron_reduction"]
        @test sort(collect(keys(red["bus"]))) == ["b2", "b5", "s"]
        @test log["n_eliminated"] == 3
        @test log["super_node_of"] == Dict("b1" => "b2", "b3" => "b2", "b4" => "b5")
        @test sort([l["bus"] for l in values(red["load"])]) == ["b2", "b2", "b5", "b5"]
        @test log["n_devices_moved"] == 3
        @test isempty(log["mesh_fill_in_buses"])
        # exactness: reduced passive network == Schur complement of the original
        @test _ok_phase_block(red, ["s", "b2", "b5"]) ≈ _ok_schur(net, ["s", "b2", "b5"]) rtol = 1e-12
        # serialization round trip keeps the equivalent network
        io = IOBuffer(); write_bmopf(red, io)
        back = parse_bmopf(String(take!(io)); from_string=true)
        @test _ok_phase_block(back, ["s", "b2", "b5"]) ≈ _ok_phase_block(red, ["s", "b2", "b5"]) rtol = 1e-12

        # boundary: identity assignment changes nothing electrical
        same = kron_reduce_buses(net, mh, collect(1:length(mh.buses)))
        @test sort(collect(keys(same["bus"]))) == sort(collect(keys(net["bus"])))
        @test isempty(same["_kron_reduction"]["equivalent_lines"])
        @test _ok_phase_block(same, ["s", "b2", "b5"]) ≈ _ok_phase_block(net, ["s", "b2", "b5"])
        # boundary: everything merged into the source
        alls = kron_reduce_buses(net, mh, ones(Int, length(mh.buses)))
        @test collect(keys(alls["bus"])) == ["s"]
        @test all(l["bus"] == "s" for l in values(alls["load"]))

        # certified voltage tightening: super-node band shrinks by Ē·U0
        netv = deepcopy(net)
        for b in keys(netv["bus"])
            netv["bus"][b]["v_min"] = fill(0.9 * 230, 3); netv["bus"][b]["v_max"] = fill(1.1 * 230, 3)
        end
        mv = opti_kron_model(netv; H=4)
        redv = kron_reduce_buses(netv, mv, sup; Ebar=1e-3)
        r2 = mv.rowof[(mv.busof["b2"], "1")]; r3 = mv.rowof[(mv.busof["b3"], "1")]
        @test redv["bus"]["b2"]["v_min"][1] ≈ (0.9 * 230 + 1e-3 * mv.u0[r3]) * mv.u0[r2] / mv.u0[r3]
        @test redv["bus"]["b2"]["v_max"][1] ≈ (1.1 * 230 - 1e-3 * mv.u0[r3]) * mv.u0[r2] / mv.u0[r3]
        @test redv["_kron_reduction"]["n_voltage_limits_tightened"] > 0
        @test redv["bus"]["s"]["v_min"] == netv["bus"]["s"]["v_min"]   # untouched

        # a device terminal earthed at its bus is earthed at the super-node too
        netg = deepcopy(net)
        netg["bus"]["b3"]["terminal_names"] = ["1", "2", "3", "n"]
        netg["bus"]["b3"]["perfectly_grounded_terminals"] = ["n"]
        netg["load"]["db3"]["terminal_map"] = ["1", "2", "3", "n"]
        mg = opti_kron_model(netg; H=4)
        redg = kron_reduce_buses(netg, mg, sup)
        @test "n" in redg["bus"]["b2"]["terminal_names"]
        @test "n" in redg["bus"]["b2"]["perfectly_grounded_terminals"]
        @test redg["_kron_reduction"]["grounded_terminals_added"] == ["b2:n"]
        netu = deepcopy(netg); netu["bus"]["b3"]["perfectly_grounded_terminals"] = String[]
        netu["shunt"] = Dict("g" => Dict("bus" => "b3", "terminal_map" => ["n"], "G_1_1" => 1.0, "B_1_1" => 0.0))
        @test_throws ArgumentError kron_reduce_buses(netu, opti_kron_model(netu; H=4), sup)

        # negative: refuse instead of guessing
        bad = copy(sup); bad[id("b2")] = id("b5")                     # b1 → b2, not a super-node
        @test_throws ArgumentError kron_reduce_buses(net, mh, bad)
        mesh = collect(1:length(mh.buses)); mesh[id("b2")] = id("b1")
        @test_throws ArgumentError kron_reduce_buses(net, mh, mesh)
        @test kron_reduce_buses(net, mh, mesh; allow_mesh=true)["_kron_reduction"]["mesh_fill_in_buses"] == ["b2"]
        srcgone = collect(1:length(mh.buses)); srcgone[1] = id("b1")
        @test_throws ArgumentError kron_reduce_buses(net, mh, srcgone)
        @test_throws ArgumentError kron_reduce_buses(net, mh, sup[1:end-1])
    end

    if _OK_HAS_HIGHS
        @testset "keep and preserve_radial" begin
            mh = opti_kron_model(net; H=4)
            S = OptiKronBox(U)
            res = opti_kron_reduction(mh, S, 1.0; optimizer=HiGHS.Optimizer, keep=["b4"])
            @test res.assignment[mh.busof["b4"]] == mh.busof["b4"]
            @test isempty(BMOPFTools._ok_radial_violations(mh, res.assignment))
            res2 = opti_kron_reduction(mh, S, 1.0; optimizer=HiGHS.Optimizer, keep=["b3", "b4"])
            @test isempty(BMOPFTools._ok_radial_violations(mh, res2.assignment))
            res3 = opti_kron_reduction(mh, S, 1.0; optimizer=HiGHS.Optimizer, keep=["b3", "b4"],
                                       preserve_radial=false)
            @test length(res3.super_nodes) ≤ length(res2.super_nodes)
            @test_throws ArgumentError opti_kron_reduction(mh, S, 1.0; optimizer=HiGHS.Optimizer,
                                                           keep=["nope"])
            # the radial result is buildable without allow_mesh
            @test kron_reduce_buses(net, mh, res2) isa Dict
        end
    end

    if _OK_HAS_IPOPT
        @testset "AC exactness and lift_solution" begin
            mh = opti_kron_model(net; H=4)
            id(b) = mh.busof[b]
            sup = collect(1:length(mh.buses))
            sup[id("b1")] = id("b2"); sup[id("b3")] = id("b2"); sup[id("b4")] = id("b5")
            red = kron_reduce_buses(net, mh, sup)
            moved = deepcopy(net)
            for l in values(moved["load"])
                l["bus"] = get(red["_kron_reduction"]["super_node_of"], l["bus"], l["bus"])
            end
            opt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-10)
            pf_o = solve_pf(net; optimizer=opt)
            pf_m = solve_pf(moved; optimizer=opt)
            pf_r = solve_pf(red; optimizer=opt)
            v(r, b, t) = complex(r["bus"][b][t]["vr"], r["bus"][b][t]["vi"])
            # the reduced case reproduces the relocated full network exactly
            for b in ("s", "b2", "b5"), t in ("1", "2", "3")
                @test abs(v(pf_r, b, t) - v(pf_m, b, t)) ≤ 1e-6 * 230
            end
            # region lift: exact for exact boundary voltages (relocated network)
            lr = lift_solution(net, red, pf_m)
            @test lr["_lift"]["method"] == "region" && lr["_lift"]["converged"]
            # linear lift: removes the first-order relocation error everywhere
            ll = lift_solution(net, red, pf_r; model=mh)
            @test ll["_lift"]["method"] == "linear"
            worst_naive = 0.0; worst_lift = 0.0
            for (jb, ib) in red["_kron_reduction"]["super_node_of"], t in ("1", "2", "3")
                truth = abs(v(pf_o, jb, t))
                worst_naive = max(worst_naive, abs(abs(v(pf_r, ib, t)) - truth))
                worst_lift = max(worst_lift, abs(ll["bus"][jb][t]["vpn_lifted"] - truth))
            end
            @test worst_lift < 0.1 * worst_naive          # second-order residual only
            for b in ("b2", "b5"), t in ("1", "2", "3")     # super-nodes corrected too
                @test abs(ll["bus"][b][t]["vpn_lifted"] - abs(v(pf_o, b, t))) <
                      abs(abs(v(pf_r, b, t)) - abs(v(pf_o, b, t))) + 1e-9
            end
            @test_throws ArgumentError lift_solution(net, red, pf_r; method=:linear)
            # identity reduction: nothing to lift, linear lift returns the solution
            same = kron_reduce_buses(net, mh, collect(1:length(mh.buses)))
            @test lift_solution(net, same, pf_o)["_lift"]["iterations"] == 0
            ls = lift_solution(net, same, pf_o; model=mh)
            @test ls["bus"]["b3"]["1"]["vpn_lifted"] ≈ abs(v(pf_o, "b3", "1")) rtol = 1e-9
        end
    end
end
