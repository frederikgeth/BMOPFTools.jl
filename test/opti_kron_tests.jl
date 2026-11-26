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
        @test !any(mid.keep[p] == false && m.pair_i[p] == m.pair_j[p] for p in eachindex(mid.keep))
    end

    if _OK_HAS_HIGHS
        @testset "Algorithm 1 (HiGHS)" begin
            for S in (OptiKronBox(U), OptiKronHull(U), OptiKronEllipsoid(U),
                      OptiKronWasserstein(U; p=2))
                for Ebar in (5e-4, 2e-3, 1e-2)
                    res = opti_kron_reduction(m, S, Ebar; optimizer=HiGHS.Optimizer)
                    @test res.status == :optimal
                    @test res.max_violation ≤ 1e-3 * Ebar
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

    # ── coverage added in the review pass ──────────────────────────────────
    @testset "tree helpers, sub-network extraction and no-load solve" begin
        cnt = downstream_bus_counts(net)
        @test cnt["s"] == 6 && cnt["b2"] == 4 && cnt["b4"] == 2 && cnt["b5"] == 1
        y, V = opti_kron_noload(net)
        @test all(abs(V[y.index[("b5", t)]]) ≈ 230 for t in ("1", "2", "3"))   # no load ⇒ no drop
        sub = extract_downstream_network(net, "b2")
        @test sort(collect(keys(sub["bus"]))) == ["b2", "b3", "b4", "b5"]
        @test only(values(sub["voltage_source"]))["bus"] == "b2"
        @test sub["meta"]["extracted_from"]["dropped_boundary_elements"] == 1  # the feeding line
        @test sort(collect(keys(sub["load"]))) == ["db3", "db4", "db5"]
        @test haskey(net["bus"], "s")                                         # input untouched
        @test_throws ArgumentError extract_downstream_network(net, "nope")
    end

    @testset "islands and meshes" begin
        isl = deepcopy(net)
        isl["bus"]["x1"] = Dict{String,Any}("terminal_names" => ["1", "2", "3"])
        isl["bus"]["x2"] = Dict{String,Any}("terminal_names" => ["1", "2", "3"])
        isl["line"]["lx"] = merge(deepcopy(isl["line"]["l1"]), Dict{String,Any}("bus_from" => "x1", "bus_to" => "x2"))
        mi = opti_kron_model(isl; H=2)
        @test mi.n_unreached == 2
        @test all(isfinite, mi.K)
        @test mi.K ≈ m.K                                   # the island changes nothing
        mesh = deepcopy(net)
        mesh["line"]["l6"] = merge(deepcopy(mesh["line"]["l1"]), Dict{String,Any}("bus_from" => "b3", "bus_to" => "b5"))
        mm = opti_kron_model(mesh; H=2)
        @test mm.n_mesh_edges == 1
        nr = length(mm.rows)
        @test mm.K[:, 1:nr] ≈ transpose(mm.K[:, 1:nr]) rtol = 1e-9   # reciprocal network
        r3 = mm.rowof[(mm.busof["b3"], "1")]; r5 = mm.rowof[(mm.busof["b5"], "1")]
        @test mm.K[r3, r5] > m.K[m.rowof[(m.busof["b3"], "1")], m.rowof[(m.busof["b5"], "1")]]  # parallel path couples b3, b5 more
    end

    @testset "transformers, slack across zones, required buses" begin
        tx = parse_bmopf(joinpath(@__DIR__, "data", "transformer_interoperability", "delta_wye.json"))
        lc = Dict{String,Any}()
        for a in 1:4, b in 1:4
            lc["R_series_$(a)_$(b)"] = a == b ? 4e-4 : 1e-5
            lc["X_series_$(a)_$(b)"] = a == b ? 2.5e-4 : 1e-5
        end
        tx["linecode"] = Dict{String,Any}("lv" => lc)
        tx["line"] = Dict{String,Any}()
        prev = "t"
        for k in 1:4
            b = "u$k"
            tx["bus"][b] = Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"],
                                            "perfectly_grounded_terminals" => ["n"])
            tx["line"]["lu$k"] = Dict{String,Any}("bus_from" => prev, "bus_to" => b, "linecode" => "lv",
                "length" => 50.0, "terminal_map_from" => ["a", "b", "c", "n"],
                "terminal_map_to" => ["a", "b", "c", "n"])
            tx["load"]["lu$k"] = Dict{String,Any}("bus" => b, "terminal_map" => ["a", "n"],
                "configuration" => "SINGLE_PHASE", "model" => "constant_power",
                "p_nom" => [400.0 * k], "q_nom" => [100.0])
            prev = b
        end
        tx = parse_bmopf(BMOPFTools.JSON3.write(tx); from_string=true)
        @test opti_kron_required_buses(tx) == ["f", "t"]
        mt = opti_kron_model(tx; H=3)
        @test maximum(mt.zone) == 2
        cross = [p for p in eachindex(mt.pair_i) if mt.zone[mt.pair_i[p]] != mt.zone[mt.pair_j[p]]]
        @test !isempty(cross) && all(mt.pair_i[p] == 1 for p in cross)      # only the slack crosses
        nocross = opti_kron_model(tx; H=3, slack_cross_zone=false)
        @test all(nocross.zone[nocross.pair_i[p]] == nocross.zone[nocross.pair_j[p]] for p in eachindex(nocross.pair_i))
        # eliminating a transformer terminal is refused by the builder
        sup = collect(1:length(mt.buses)); sup[mt.busof["t"]] = 1
        sup[mt.busof["u1"]] = 1
        @test_throws ArgumentError kron_reduce_buses(tx, mt, sup)
        if _OK_HAS_HIGHS
            Ut = opti_kron_load_injections(mt, tx, Dict(id => [0.5, 1.0, 1.5] for id in keys(tx["load"])))
            res = opti_kron_reduction(mt, OptiKronHull(Ut), 0.02; optimizer=HiGHS.Optimizer,
                                      keep=opti_kron_required_buses(tx))
            @test res.status == :optimal
            @test res.assignment[mt.busof["t"]] == mt.busof["t"]
            red = kron_reduce_buses(tx, mt, res)
            @test haskey(red["transformer"]["delta_wye"], "tx")                # kept unchanged
        end
    end

    @testset "load injections: delta split and sign" begin
        nd = deepcopy(net)
        nd["load"]["dd"] = Dict{String,Any}("bus" => "b3", "configuration" => "DELTA",
            "model" => "CONSTANT_POWER", "p_nom" => [600.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0],
            "terminal_map" => ["1", "2", "3"], "v_nom" => [400.0, 400.0, 400.0])
        md = opti_kron_model(nd; H=2)
        Ud = opti_kron_load_injections(md, nd, Dict("dd" => [1.0]); n=1)
        r1 = md.rowof[(md.busof["b3"], "1")]; r2 = md.rowof[(md.busof["b3"], "2")]
        @test Ud[r1, 1] ≈ -0.3 && Ud[r2, 1] ≈ -0.3                 # 0.6 kW split across 1–2
        @test count(!iszero, Ud) == 2
    end

    @testset "uncertainty-set options and membership" begin
        Es = OptiKronEllipsoid(U; covariance=:shrinkage)
        Ep = OptiKronEllipsoid(U)
        @test Es.Omega > 0 && Ep.Omega > 0
        @test istril(Ep.L)
        @test_throws ArgumentError OptiKronEllipsoid(U; covariance=:bogus)
        B = OptiKronBox(U)
        @test all(BMOPFTools._ok_contains(B, B.samples[:, s]) for s in 1:size(U, 2))
        @test !BMOPFTools._ok_contains(B, B.ubar .+ 2 .* B.delta .+ 1.0)
        # Wasserstein membership is exact (needs an optimizer): see the review regressions
        rng = Random.MersenneTwister(5)
        big = opti_kron_load_injections(m, net, Dict(id => [0.3 + rand(rng) for _ in 1:400]
                                                     for id in keys(net["load"])))
        Wb = OptiKronWasserstein(big; p=2, epsilon=0.01)
        @test_throws ArgumentError OptiKronWasserstein(U; p=3)
        if _OK_HAS_HIGHS
            r = opti_kron_reduction(m, Wb, 5e-3; optimizer=HiGHS.Optimizer)
            @test r.status == :optimal
            @test maximum(opti_kron_worst_errors(m, r.assignment, Wb)) ≤ 5e-3 * (1 + 1e-3)
            @test r.lower_bound ≤ length(r.super_nodes)
        end
    end

    if _OK_HAS_HIGHS
        @testset "initial-sample validation and screening soundness" begin
            S = OptiKronBox(U)
            bad = copy(U[:, 1:1]); bad[findfirst(c -> !(c in S.idx), 1:size(U, 1)), 1] = 1.0
            @test_throws ArgumentError opti_kron_reduction(m, S, 2e-3; optimizer=HiGHS.Optimizer, initial=bad)
            outside = zeros(size(U, 1), 1); outside[S.idx, 1] .= S.ubar .+ 3 .* S.delta .+ 1
            @test_throws ArgumentError opti_kron_reduction(m, S, 2e-3; optimizer=HiGHS.Optimizer, initial=outside)
            for Eb in (1e-3, 3e-3)
                scr = opti_kron_screen(m, S, Eb)
                res0 = opti_kron_reduction(m, S, Eb; optimizer=HiGHS.Optimizer, screen=false)
                used = [p for p in eachindex(m.pair_i) if res0.assignment[m.pair_j[p]] == m.pair_i[p]]
                @test all(scr.keep[p] for p in used)       # screening keeps what an optimum uses
            end
        end
    end

    @testset "voltage tightening: scalar limits, row types, slack excluded" begin
        mh = opti_kron_model(net; H=4)
        sup = collect(1:length(mh.buses))
        sup[mh.busof["b3"]] = mh.busof["b2"]; sup[mh.busof["b1"]] = 1
        ns = deepcopy(net)
        for b in keys(ns["bus"]); ns["bus"][b]["v_min"] = 200.0; end    # scalar limit
        ms_ = opti_kron_model(ns; H=4)
        red = kron_reduce_buses(ns, ms_, sup; Ebar=1e-3)
        @test red["bus"]["b2"]["v_min"] isa AbstractVector && length(red["bus"]["b2"]["v_min"]) == 3
        @test all(red["bus"]["b2"]["v_min"] .> 200.0)
        @test red["bus"]["s"]["v_min"] == 200.0                        # slack untouched
        @test all(red["bus"]["b5"]["v_min"] .> 200.0)                  # kept buses' own e_ii
        # limit arrays are indexed by every non-neutral terminal, grounded or not
        bus = Dict{String,Any}("terminal_names" => ["1", "2", "3", "n"],
                               "perfectly_grounded_terminals" => ["2", "n"])
        conv = Dict{String,Any}("terminal_conventions" => Dict("phase" => ["1", "2", "3"], "neutral" => ["n"]))
        @test BMOPFTools._kr_limit_phases(conv, bus) == ["1", "2", "3"]
        @test BMOPFTools._kr_row_limit_fields(conv, bus) == (("vpn_min", "vpn_max"), ("v_min", "v_max"))
        floating = Dict{String,Any}("terminal_names" => ["1", "n"])
        @test BMOPFTools._kr_row_limit_fields(conv, floating) == (("vpn_min", "vpn_max"),)
    end
end

# ── regression cases from the PR review (one per finding) ──────────────────
_okr_lc(n; r=4e-4, x=2.5e-4) = Dict{String,Any}(
    (f * "_$(a)_$(b)" => (a == b ? v : 0.0) for (f, v) in (("R_series", r), ("X_series", x))
     for a in 1:n for b in 1:n)...)
_okr_line(a, b, tm; len=100.0, lc="lc", tmto=tm) = Dict{String,Any}(
    "bus_from" => a, "bus_to" => b, "linecode" => lc, "length" => len,
    "terminal_map_from" => tm, "terminal_map_to" => tmto)
_okr_parse(d) = parse_bmopf(BMOPFTools.JSON3.write(d); from_string=true)

# s — b1 — b2 with a two-phase WYE load whose neutral is listed first.
function _okr_nonlast_neutral()
    tn = ["a", "b", "n"]
    bus = Dict(b => Dict{String,Any}("terminal_names" => tn) for b in ("s", "b1", "b2"))
    bus["s"]["perfectly_grounded_terminals"] = ["n"]
    _okr_parse(Dict("bus" => bus, "linecode" => Dict("lc" => _okr_lc(3)),
        "line" => Dict("l1" => _okr_line("s", "b1", tn), "l2" => _okr_line("b1", "b2", tn)),
        "load" => Dict("d2" => Dict("bus" => "b2", "configuration" => "WYE", "model" => "CONSTANT_POWER",
                       "terminal_map" => ["n", "a", "b"], "p_nom" => [100.0, 300.0], "q_nom" => [0.0, 0.0])),
        "voltage_source" => Dict("src" => Dict("bus" => "s", "terminal_map" => ["a", "b", "n"],
                       "v_magnitude" => [100.0, 100.0, 0.0], "v_angle" => [0.0, -2π / 3, 0.0])),
        "terminal_conventions" => Dict("phase" => ["a", "b"], "neutral" => ["n"])))
end

# Finite three-winding transformer w1/w2/w3 with a loaded line behind each secondary.
function _okr_nwinding()
    d = BMOPFTools.JSON3.read(read(joinpath(@__DIR__, "data", "ideal_nwinding.json"), String), Dict{String,Any})
    first(values(d["transformer"]["n_winding"]))["x_sc"]["2_3"] = 0.02
    for b in keys(d["bus"]); d["bus"][b]["perfectly_grounded_terminals"] = ["n"]; end
    d["voltage_source"] = Dict("src" => Dict("bus" => "w1", "terminal_map" => ["a", "n"],
                                "v_magnitude" => [460.0], "v_angle" => [0.0]))
    d["linecode"] = Dict("lc" => _okr_lc(1)); d["line"] = Dict{String,Any}(); d["load"] = Dict{String,Any}()
    for (w, x) in (("w2", "x2"), ("w3", "x3"))
        d["bus"][x] = Dict("terminal_names" => ["a", "n"], "perfectly_grounded_terminals" => ["n"])
        d["line"]["l$x"] = _okr_line(w, x, ["a"]; len=50.0)
        d["load"]["d$x"] = Dict("bus" => x, "terminal_map" => ["a", "n"], "configuration" => "WYE",
                                "model" => "CONSTANT_POWER", "p_nom" => [500.0], "q_nom" => [100.0])
    end
    d["terminal_conventions"] = Dict("phase" => ["a"], "neutral" => ["n"])
    _okr_parse(d)
end

# s — k (kept, neutral not earthed) — e (eliminated): phase over a line, neutral
# over a closed switch to e's perfectly grounded neutral.
function _okr_inherited_ground()
    bus = Dict("s" => Dict{String,Any}("terminal_names" => ["a", "n"], "perfectly_grounded_terminals" => ["n"]),
               "k" => Dict{String,Any}("terminal_names" => ["a", "n"]),
               "e" => Dict{String,Any}("terminal_names" => ["a", "n"], "perfectly_grounded_terminals" => ["n"]))
    _okr_parse(Dict("bus" => bus, "linecode" => Dict("lc" => _okr_lc(2), "lc1" => _okr_lc(1)),
        "line" => Dict("l1" => _okr_line("s", "k", ["a", "n"]; len=500.0),
                       "l2" => _okr_line("k", "e", ["a"]; lc="lc1")),
        "switch" => Dict("sw" => Dict{String,Any}("bus_from" => "k", "bus_to" => "e",
                         "terminal_map_from" => ["n"], "terminal_map_to" => ["n"])),
        "load" => Dict("dk" => Dict("bus" => "k", "configuration" => "WYE", "model" => "CONSTANT_POWER",
                       "terminal_map" => ["a", "n"], "p_nom" => [2000.0], "q_nom" => [500.0])),
        "voltage_source" => Dict("src" => Dict("bus" => "s", "terminal_map" => ["a", "n"],
                       "v_magnitude" => [100.0], "v_angle" => [0.0])),
        "terminal_conventions" => Dict("phase" => ["a"], "neutral" => ["n"])))
end

# Four-bus mesh: s–p, s–q, s–r (BFS tree) plus p–q, p–r. p is a BFS leaf with
# three physical neighbors.
function _okr_mesh()
    bus = Dict(b => Dict{String,Any}("terminal_names" => ["a"]) for b in ("s", "p", "q", "r"))
    edges = (("s", "p"), ("s", "q"), ("s", "r"), ("p", "q"), ("p", "r"))
    _okr_parse(Dict("bus" => bus, "linecode" => Dict("lc" => _okr_lc(1)),
        "line" => Dict("l$k" => _okr_line(a, b, ["a"]) for (k, (a, b)) in enumerate(edges)),
        "load" => Dict("d$b" => Dict("bus" => b, "configuration" => "WYE", "model" => "CONSTANT_POWER",
                       "terminal_map" => ["a"], "p_nom" => [500.0], "q_nom" => [0.0]) for b in ("p", "q", "r")),
        "voltage_source" => Dict("src" => Dict("bus" => "s", "terminal_map" => ["a"],
                       "v_magnitude" => [230.0], "v_angle" => [0.0])),
        "terminal_conventions" => Dict("phase" => ["a"], "neutral" => String[])))
end

@testset "Opti-KRON review regressions" begin
    net = _ok_test_feeder()
    m = opti_kron_model(net; H=4)
    U = _ok_test_samples(m, net)

    if _OK_HAS_HIGHS
        @testset "set membership of initial samples (hull, Wasserstein)" begin
            H = OptiKronHull(U)
            mid = zeros(size(U, 1), 1); mid[:, 1] .= 0.5 .* (U[:, 1] .+ U[:, 2])
            far = 3 .* U[:, 1:1]                                     # outside the hull
            @test BMOPFTools._ok_contains(H, mid[H.idx, 1]; optimizer=HiGHS.Optimizer)
            @test !BMOPFTools._ok_contains(H, far[H.idx, 1]; optimizer=HiGHS.Optimizer)
            @test_throws ArgumentError BMOPFTools._ok_contains(H, mid[H.idx, 1])   # needs an optimizer
            @test_throws ArgumentError opti_kron_reduction(m, H, 2e-3; optimizer=HiGHS.Optimizer,
                                                           initial=far, screen=false)
            ref = opti_kron_reduction(m, H, 2e-3; optimizer=HiGHS.Optimizer, screen=false)
            inh = opti_kron_reduction(m, H, 2e-3; optimizer=HiGHS.Optimizer, screen=false, initial=mid)
            @test length(inh.super_nodes) == length(ref.super_nodes)
            @test inh.lower_bound ≤ length(ref.super_nodes)
            for p in (1, 2, Inf)
                W = OptiKronWasserstein(U; p=p, epsilon=0.01)          # N = 12: cap = 1
                @test all(BMOPFTools._ok_contains(W, W.samples[:, s]; optimizer=HiGHS.Optimizer)
                          for s in 1:size(U, 2))
                @test !BMOPFTools._ok_contains(W, 3 .* W.samples[:, 1] .+ 10W.radius;
                                               optimizer=HiGHS.Optimizer)
            end
            @test_throws ArgumentError opti_kron_reduction(m, OptiKronWasserstein(U; p=2), 2e-3;
                optimizer=HiGHS.Optimizer, initial=far)
            # an optimizer that cannot decide membership skips default seeds
            # instead of failing, while an explicit check still throws
            W2 = OptiKronWasserstein(U; p=2)
            noqp = () -> error("this optimizer cannot solve the membership QP")
            @test BMOPFTools._ok_seed_member(W2, W2.samples[:, 1], HiGHS.Optimizer)
            @test !BMOPFTools._ok_seed_member(W2, W2.samples[:, 1], noqp)
            @test_throws ErrorException BMOPFTools._ok_contains(W2, W2.samples[:, 1]; optimizer=noqp)
        end
    end

    @testset "non-last neutral: samples and region lift" begin
        nn = _okr_nonlast_neutral()
        mn = opti_kron_model(nn; H=2)
        Un = opti_kron_load_injections(mn, nn, Dict("d2" => [1.0]); n=1)
        @test Un[mn.rowof[(mn.busof["b2"], "a")], 1] ≈ -0.1
        @test Un[mn.rowof[(mn.busof["b2"], "b")], 1] ≈ -0.3
        @test count(!iszero, Un) == 2
        if _OK_HAS_IPOPT
            ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
            sup = collect(1:length(mn.buses)); sup[mn.busof["b2"]] = mn.busof["b1"]
            red = kron_reduce_buses(nn, mn, sup)
            full = solve_pf(nn; optimizer=ipopt); pr = solve_pf(red; optimizer=ipopt)
            lr = lift_solution(nn, red, pr; model=mn, method=:region)
            vpn(r, t) = abs(complex(r["bus"]["b2"][t]["vr"], r["bus"]["b2"][t]["vi"]) -
                            complex(r["bus"]["b2"]["n"]["vr"], r["bus"]["b2"]["n"]["vi"]))
            for t in ("a", "b")
                @test vpn(lr, t) ≈ vpn(full, t) atol = 0.01      # only b1's relocation effect remains
            end
        end
    end

    @testset "n_winding transformers in the topology walk" begin
        nw = _okr_nwinding()
        @test opti_kron_required_buses(nw) == ["w1", "w2", "w3"]
        mw = opti_kron_model(nw; H=3)
        @test mw.n_unreached == 0
        @test sort(mw.buses) == ["w1", "w2", "w3", "x2", "x3"]
        sub = extract_downstream_network(nw, "w1")
        @test sort(collect(keys(sub["bus"]))) == ["w1", "w2", "w3", "x2", "x3"]
    end

    @testset "an inherited ideal ground survives elimination" begin
        ng = _okr_inherited_ground()
        mg = opti_kron_model(ng; H=2)
        sup = collect(1:length(mg.buses)); sup[mg.busof["e"]] = mg.busof["k"]
        red = kron_reduce_buses(ng, mg, sup)
        @test "n" in red["bus"]["k"]["perfectly_grounded_terminals"]
        @test "k:n" in red["_kron_reduction"]["grounded_terminals_added"]
        if _OK_HAS_IPOPT
            ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
            vk(r) = abs(complex(r["bus"]["k"]["a"]["vr"], r["bus"]["k"]["a"]["vi"]) -
                        complex(get(r["bus"]["k"], "n", Dict("vr" => 0.0))["vr"],
                                get(r["bus"]["k"], "n", Dict("vi" => 0.0))["vi"]))
            @test vk(solve_pf(red; optimizer=ipopt)) ≈ vk(solve_pf(ng; optimizer=ipopt)) rtol = 1e-6
        end
    end

    @testset "buses represented by the slack: fixed-voltage certificate" begin
        sup = collect(1:length(m.buses)); sup[m.busof["b1"]] = 1
        tight = deepcopy(net); tight["bus"]["b1"]["v_min"] = [226.0, 226.0, 226.0]
        @test_throws ArgumentError kron_reduce_buses(tight, opti_kron_model(tight; H=4), sup; Ebar=0.02)
        loose = deepcopy(net); loose["bus"]["b1"]["v_min"] = [220.0, 220.0, 220.0]
        @test kron_reduce_buses(loose, opti_kron_model(loose; H=4), sup; Ebar=0.02) isa Dict
        @test kron_reduce_buses(tight, opti_kron_model(tight; H=4), sup) isa Dict   # no Ebar: no certificate
    end

    @testset "time-varying passive data is refused, a snapshot reduces" begin
        sup = collect(1:length(m.buses)); sup[m.busof["b3"]] = m.busof["b2"]
        ts = deepcopy(net)
        ts["time_series"] = Dict{String,Any}("len" => Dict{String,Any}("values" => [1.0, 1.5]))
        ts["line"]["l3"]["time_series"] = Dict{String,Any}("length" => "len")      # l3 = b2–b3
        @test_throws ArgumentError kron_reduce_buses(ts, m, sup)
        snap = get_snapshot(ts, 2)
        red = kron_reduce_buses(snap, opti_kron_model(snap; H=4), sup)
        @test !haskey(red["line"], "l3")
        # profiles on untouched elements and on moved devices are fine
        ok = deepcopy(net)
        ok["time_series"] = Dict{String,Any}("shape" => Dict{String,Any}("values" => [0.5, 1.0]))
        ok["load"]["db3"]["time_series"] = Dict{String,Any}("p_nom" => "shape")
        ok["line"]["l1"]["time_series"] = Dict{String,Any}("length" => "shape")
        red2 = kron_reduce_buses(ok, m, sup)
        @test red2["load"]["db3"]["bus"] == "b2" && haskey(red2["load"]["db3"], "time_series")
        lim = deepcopy(net)
        lim["time_series"] = ok["time_series"]
        lim["bus"]["b2"]["v_min"] = [200.0, 200.0, 200.0]
        lim["bus"]["b2"]["time_series"] = Dict{String,Any}("v_min" => "shape")
        @test_throws ArgumentError kron_reduce_buses(lim, m, sup; Ebar=1e-3)   # would freeze a limit profile
        @test kron_reduce_buses(lim, m, sup) isa Dict
    end

    @testset "mesh fill-in through edges outside the BFS tree" begin
        nm = _okr_mesh()
        mm = opti_kron_model(nm; H=2)
        sup = collect(1:length(mm.buses)); sup[mm.busof["p"]] = 1
        @test isempty(BMOPFTools._ok_radial_violations(mm, sup))        # the tree rule misses it
        @test_throws ArgumentError kron_reduce_buses(nm, mm, sup)
        red = kron_reduce_buses(nm, mm, sup; allow_mesh=true)
        @test red["_kron_reduction"]["mesh_fill_in_buses"] == ["p"]
        @test haskey(red["line"], "kron_eq:q:r")                        # the new loop
        # a pass-through elimination on the radial feeder is still accepted
        sup2 = collect(1:length(m.buses)); sup2[m.busof["b1"]] = 1
        @test isempty(kron_reduce_buses(net, m, sup2)["_kron_reduction"]["mesh_fill_in_buses"])
    end
end

# The Opti-KRON tutorial quotes the example script's output line by line. Run
# the script and require every printed line to appear in the page, so the
# tutorial cannot drift from the code.
if _OK_HAS_HIGHS && _OK_HAS_IPOPT
    @testset "tutorial_opti_kron.md matches its example script" begin
        root = pkgdir(BMOPFTools)
        script = joinpath(root, "examples", "opti_kron", "tutorial_feeder.jl")
        page = joinpath(root, "docs", "src", "tutorial_opti_kron.md")
        norm_ws(s) = replace(strip(s), r"\s+" => " ")
        out = mktemp() do path, io
            redirect_stdout(io) do
                Base.include(Module(:OptiKronTutorial), script)
            end
            close(io); read(path, String)
        end
        doc = norm_ws(read(page, String))
        lines = filter(!isempty, norm_ws.(split(out, '\n')))
        @test length(lines) ≥ 12
        missing_from_page = [l for l in lines if !occursin(l, doc)]
        @test isempty(missing_from_page)        # on failure, lists only the drifted lines
    end
end
