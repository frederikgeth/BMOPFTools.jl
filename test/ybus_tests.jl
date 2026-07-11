# Tests for the system nodal admittance matrix (ybus_passive).
#
# Three layers:
#   1. per-primitive analytic checks (line Π, shunt, capacitor) — always run;
#   2. structural checks: symmetry, current conservation, node aliasing
#      (closed switches, negligible-Z lines) and earth-reference collapse;
#   3. OpenDSS `getYsparse` cross-check on load-free passive decks (gated on
#      OpenDSSDirect). Load-free so OpenDSS's system Y is purely passive-element
#      Yprims + the Vsource Yprim; compared over the non-source buses it must
#      equal `ybus_passive` to numerical zero.

@testset "ybus_passive" begin
    using LinearAlgebra, SparseArrays

    # OpenDSS AllNodeNames / YNodeOrder use ".1/.2/.3/.4"; from_dss uses a/b/c/n.
    _TN = Dict("a" => "1", "b" => "2", "c" => "3", "n" => "4",
               "1" => "1", "2" => "2", "3" => "3", "4" => "4")

    dense(r) = Matrix(r.Y)

    # ── layer 1 + 2: analytic / structural, no OpenDSS ─────────────────────────

    @testset "single line Π + earth reference" begin
        # 2-bus, phase+neutral line; b1.n perfectly grounded.
        # Series y = 1/(1+j1) = 0.5 - 0.5j per conductor.
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                         "perfectly_grounded_terminals" => ["n"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a", "n"]),
            ),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}(
                    "bus_from" => "b1", "bus_to" => "b2",
                    "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
                    "R_series_1_1" => 1.0, "X_series_1_1" => 1.0,
                    "R_series_2_2" => 1.0, "X_series_2_2" => 1.0),
            ),
        )
        r = ybus_passive(net)
        Y = dense(r)

        # b1.n is grounded → no row; the 3 live nodes are b1.a, b2.a, b2.n.
        @test Set(r.nodes) == Set([("b1", "a"), ("b2", "a"), ("b2", "n")])
        @test r.index[("b1", "n")] == 0            # earth reference
        @test size(Y) == (3, 3)

        y = 1.0 / (1.0 + 1.0im)
        ia = r.index[("b1", "a")]; ja = r.index[("b2", "a")]
        # phase conductor: full series pair
        @test Y[ia, ia] ≈ y;  @test Y[ja, ja] ≈ y
        @test Y[ia, ja] ≈ -y; @test Y[ja, ia] ≈ -y
        # neutral conductor with grounded far end → shunt-to-earth y on b2.n
        kn = r.index[("b2", "n")]
        @test Y[kn, kn] ≈ y
        # symmetric, reciprocal (NOT Hermitian)
        @test maximum(abs.(Y .- transpose(Y))) < 1e-12
    end

    @testset "shunt admittance block" begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                        "perfectly_grounded_terminals" => ["n"]),
            ),
            "shunt" => Dict{String,Any}(
                "s" => Dict{String,Any}("bus" => "b", "terminal_map" => ["a", "n"],
                                        "G_1_1" => 2.0, "B_1_1" => -3.0,
                                        "G_2_2" => 0.0, "B_2_2" => 0.0),
            ),
        )
        r = ybus_passive(net)
        ia = r.index[("b", "a")]
        @test dense(r)[ia, ia] ≈ 2.0 - 3.0im       # G + jB
    end

    @testset "capacitor susceptance block (WYE)" begin
        # WYE cap: each phase-to-neutral susceptance b = q/v². Neutral grounded.
        q = 50.0; v = 240.0; b = q / v^2
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                        "perfectly_grounded_terminals" => ["n"]),
            ),
            "capacitor" => Dict{String,Any}(
                "c" => Dict{String,Any}("bus" => "b", "terminal_map" => ["a", "n"],
                                        "configuration" => "WYE",
                                        "q_rated" => [q], "v_nom" => v),
            ),
        )
        r = ybus_passive(net)
        ia = r.index[("b", "a")]
        @test dense(r)[ia, ia] ≈ 0.0 + b * im       # pure jB, neutral grounded
    end

    @testset "closed switch aliases nodes; open switch does not" begin
        base(status) = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a"]),
                "b3" => Dict{String,Any}("terminal_names" => ["a"]),
            ),
            "line" => Dict{String,Any}(
                "l" => Dict{String,Any}("bus_from" => "b2", "bus_to" => "b3",
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                    "R_series_1_1" => 1.0, "X_series_1_1" => 0.0),
            ),
            "switch" => Dict{String,Any}(
                "sw" => Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                    "status" => status),
            ),
        )
        rc = ybus_passive(base("closed"))
        # closed: b1.a and b2.a fused → same index, one fewer node than open.
        @test rc.index[("b1", "a")] == rc.index[("b2", "a")]
        @test length(rc.nodes) == 2                 # {b1≡b2}, b3

        ro = ybus_passive(base("open"))
        @test ro.index[("b1", "a")] != ro.index[("b2", "a")]
        @test length(ro.nodes) == 3                 # b1 isolated, b2, b3
    end

    @testset "negligible-impedance line is aliased, not stamped" begin
        # ‖Z‖_F below z_line_min_ohm (1e-4) → treated as a unity coupling.
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a"]),
            ),
            "line" => Dict{String,Any}(
                "l" => Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                    "R_series_1_1" => 1e-9, "X_series_1_1" => 0.0),
            ),
        )
        r = ybus_passive(net)
        @test r.index[("b1", "a")] == r.index[("b2", "a")]   # fused
        @test length(r.nodes) == 1
        @test nnz(r.Y) == 0                          # nothing stamped (no huge 1/z)
    end

    @testset "current conservation: shunt-free floating network" begin
        # No shunt, no ground → every column of Y sums to ≈0 (KCL / row-sum).
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a", "b", "c"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a", "b", "c"]),
            ),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
                    "terminal_map_from" => ["a", "b", "c"],
                    "terminal_map_to" => ["a", "b", "c"],
                    "R_series_1_1" => 0.5, "X_series_1_1" => 0.3,
                    "R_series_2_2" => 0.5, "X_series_2_2" => 0.3,
                    "R_series_3_3" => 0.5, "X_series_3_3" => 0.3),
            ),
        )
        r = ybus_passive(net)
        Y = dense(r)
        @test maximum(abs.(vec(sum(Y, dims = 1)))) < 1e-10
        @test maximum(abs.(Y .- transpose(Y))) < 1e-12
    end

    # ── layer 3: OpenDSS getYsparse cross-check (gated) ────────────────────────

    @testset "OpenDSS getYsparse parity (passive decks)" begin
        if !_HAS_ODS
            @test_skip "Requires OpenDSSDirect"
        else
            # Compare ybus_passive against OpenDSS's system Y over the non-source
            # buses. Load-free decks ⇒ OpenDSS Y is passive-only there.
            function parity(deck::String, srcbus::String; atol)
                path = normpath(abspath(joinpath(@__DIR__, "data", "ybus", deck)))
                OpenDSSDirect.dss("Clear")
                OpenDSSDirect.dss("Redirect \"$path\"")
                OpenDSSDirect.dss("Solve")
                Yods = Matrix(OpenDSSDirect.YMatrix.getYsparse(false))
                order = lowercase.(OpenDSSDirect.Circuit.YNodeOrder())
                oidx = Dict(n => i for (i, n) in enumerate(order))
                net = from_dss(path)
                r = ybus_passive(net)
                Y = Matrix(r.Y)
                okey(nd) = "$(nd[1]).$(_TN[nd[2]])"
                maxd = 0.0; ncomp = 0
                for (i, ni) in enumerate(r.nodes), (j, nj) in enumerate(r.nodes)
                    (ni[1] == srcbus || nj[1] == srcbus) && continue
                    ki = get(oidx, okey(ni), 0); kj = get(oidx, okey(nj), 0)
                    (ki == 0 || kj == 0) && continue
                    ncomp += 1
                    maxd = max(maxd, abs(Y[i, j] - Yods[ki, kj]))
                end
                @test ncomp > 0
                @test maxd < atol
            end
            # line Π + capacitor: exact to machine precision
            parity("passive_line3ph.dss", "src"; atol = 1e-9)
            # Yd transformer + grounding shunt: residual from %r/%noloadloss import
            parity("passive_yd_xfmr.dss", "hv"; atol = 1e-4)
        end
    end
end
