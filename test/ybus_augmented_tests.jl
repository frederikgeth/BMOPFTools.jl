# Tests for the augmented (bordered, MNA-style) nodal admittance matrix
# (ybus_augmented).
#
# All analytic, no OpenDSS: the augmented matrix is validated against the
# aliased ybus_passive solve (switch invariant), against hand solutions
# (ideal transformer), and against the leakage→0 limit of the ordinary
# admittance stamp (the constraint row IS the exact ideal limit).

@testset "ybus_augmented" begin
    using LinearAlgebra, SparseArrays

    denseK(r) = Matrix(r.K)

    # Bordered solve: pad the nodal injection with zero constraint RHS.
    solveK(r, inj) = denseK(r) \ vcat(inj, zeros(ComplexF64, length(r.couplings)))

    # ── switch invariant: :constrain ≡ :alias, current is exact ──────────────

    @testset "closed switch: constrain ≡ alias, w = branch current" begin
        y = 0.5 - 0.25im   # shunt at b2.a (S)
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a"]),
            ),
            "switch" => Dict{String,Any}(
                "s1" => Dict{String,Any}(
                    "bus_from" => "b1", "bus_to" => "b2", "open_switch" => false,
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"]),
            ),
            "shunt" => Dict{String,Any}(
                "sh1" => Dict{String,Any}(
                    "bus" => "b2", "terminal_map" => ["a"],
                    "G_1_1" => real(y), "B_1_1" => imag(y)),
            ),
        )

        # Aliased (default): one fused node.
        ra = ybus_augmented(net)                      # switches=:alias
        @test length(ra.nodes) == 1
        @test isempty(ra.couplings)
        Iinj = 1.0 + 0.0im
        Va = solveK(ra, [Iinj])[1]
        @test Va ≈ Iinj / y

        # Constrained: two nodes + one coupling row; voltages identical.
        rc = ybus_augmented(net; switches=:constrain)
        @test length(rc.nodes) == 2
        @test length(rc.couplings) == 1
        K = denseK(rc)
        @test maximum(abs.(K .- transpose(K))) < 1e-15
        c = rc.couplings[1]
        @test c.kind == :switch && c.id == "s1" && c.conductor == 1

        x = solveK(rc, [Iinj, 0.0im])                 # inject at b1.a
        i1 = rc.index[("b1", "a")]; i2 = rc.index[("b2", "a")]
        @test x[i1] ≈ Va atol=1e-12
        @test x[i2] ≈ Va atol=1e-12
        # All injected current flows through the switch: the coupling draws
        # scale·w·coeff from each node; at b1.a (coeff +1) that must equal Iinj.
        w = x[end]
        k1 = findfirst(==(i1), c.nodes)
        @test c.scale * w * c.coeffs[k1] ≈ Iinj atol=1e-12
    end

    @testset "open switch stays open in both switch modes" begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a"]),
            ),
            "switch" => Dict{String,Any}(
                "s1" => Dict{String,Any}(
                    "bus_from" => "b1", "bus_to" => "b2", "open_switch" => true,
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"]),
            ),
        )
        r = ybus_augmented(net; switches=:constrain)
        @test length(r.nodes) == 2
        @test isempty(r.couplings)
        ra = ybus_augmented(net)                      # switches=:alias
        @test length(ra.nodes) == 2                   # not fused
        @test isempty(ra.couplings)
    end

    @testset "network opening in a loop: alias ≡ constrain ≡ switch removed" begin
        # b1 —l12— b2 —s23 (closed)— b3, and the open switch s13 from b3 back to
        # b1 (a network opening). Two conductors, inline Z, shunts at b1 and b3
        # so Y is nonsingular.
        line = Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
            "terminal_map_from" => ["a", "b"], "terminal_map_to" => ["a", "b"],
            "R_series_1_1" => 0.2, "R_series_1_2" => 0.05,
            "R_series_2_1" => 0.05, "R_series_2_2" => 0.2,
            "X_series_1_1" => 0.4, "X_series_1_2" => 0.1,
            "X_series_2_1" => 0.1, "X_series_2_2" => 0.4)
        sw(bfr, bto, open) = Dict{String,Any}("bus_from" => bfr, "bus_to" => bto,
            "terminal_map_from" => ["a", "b"], "terminal_map_to" => ["a", "b"],
            "open_switch" => open)
        sh(bus, g) = Dict{String,Any}("bus" => bus, "terminal_map" => ["a", "b"],
            "G_1_1" => g, "G_2_2" => g, "B_1_1" => 0.0, "B_2_2" => 0.0)
        mknet(s13_open) = Dict{String,Any}(
            "bus" => Dict{String,Any}(b => Dict{String,Any}("terminal_names" => ["a", "b"])
                                      for b in ("b1", "b2", "b3")),
            "line" => Dict{String,Any}("l12" => deepcopy(line)),
            "switch" => Dict{String,Any}("s23" => sw("b2", "b3", false),
                                         "s13" => sw("b3", "b1", s13_open)),
            "shunt" => Dict{String,Any}("sh1" => sh("b1", 0.1), "sh3" => sh("b3", 0.5)),
        )
        terms = [(b, t) for b in ("b1", "b2", "b3") for t in ("a", "b")]
        inj(r) = (v = zeros(ComplexF64, length(r.nodes));
                  v[r.index[("b1", "a")]] = 1.0; v[r.index[("b1", "b")]] = 0.5im; v)
        volts(r, x) = [x[r.index[n]] for n in terms]

        net = mknet(true)
        ra = ybus_augmented(net)                          # :alias
        rc = ybus_augmented(net; switches=:constrain)
        ref = ybus_passive(remove_open_switches(net))     # s13 deleted outright
        @test length(ra.nodes) == 4 && isempty(ra.couplings)
        @test length(rc.nodes) == 6
        @test [(c.id, c.conductor) for c in rc.couplings] == [("s23", 1), ("s23", 2)]

        Va = volts(ra, solveK(ra, inj(ra)))
        Vc = volts(rc, solveK(rc, inj(rc)))
        Vr = volts(ref, Matrix(ref.Y) \ inj(ref))
        @test maximum(abs.(Va .- Vr)) < 1e-12
        @test maximum(abs.(Vc .- Vr)) < 1e-12
        @test abs(Va[1] - Va[3]) > 0.01      # the line carries current: b1 ≠ b2

        # Closing s13 shorts the line, so the answer with s13 open is not the
        # all-closed one.
        rclosed = ybus_augmented(mknet(false))
        @test length(rclosed.nodes) == 2
        Vclosed = volts(rclosed, solveK(rclosed, inj(rclosed)))
        @test abs(Vclosed[1] - Vclosed[3]) < 1e-12
    end

    # ── dedupe: switch in parallel with an aliased negligible-Z line ─────────

    @testset "redundant switch constraint is deduped" begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["a"]),
                "b2" => Dict{String,Any}("terminal_names" => ["a"]),
            ),
            "switch" => Dict{String,Any}(
                "s1" => Dict{String,Any}(
                    "bus_from" => "b1", "bus_to" => "b2", "open_switch" => false,
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"]),
            ),
            # ‖Z‖ far below z_line_min_ohm → node-aliased unconditionally.
            "line" => Dict{String,Any}(
                "l0" => Dict{String,Any}(
                    "bus_from" => "b1", "bus_to" => "b2",
                    "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                    "R_series_1_1" => 1e-6, "X_series_1_1" => 0.0),
            ),
            "shunt" => Dict{String,Any}(
                "sh1" => Dict{String,Any}(
                    "bus" => "b2", "terminal_map" => ["a"],
                    "G_1_1" => 1.0, "B_1_1" => 0.0),
            ),
        )
        r = ybus_augmented(net; switches=:constrain)
        # The line fused b1.a/b2.a already: the switch row cancels to nothing.
        @test length(r.nodes) == 1
        @test isempty(r.couplings)
        @test abs(solveK(r, [1.0 + 0im])[1] - 1.0) < 1e-12
    end

    # ── ideal single_phase transformer: hand solution + leakage→0 limit ──────

    function _sp_xfmr_net(; x_to::Float64=0.0)
        # LV shunt fixed at 0.05 S (the `y` the hand solutions below use).
        Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "hv" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                         "perfectly_grounded_terminals" => ["n"]),
                "lv" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                         "perfectly_grounded_terminals" => ["n"]),
            ),
            "transformer" => Dict{String,Any}(
                "single_phase" => Dict{String,Any}(
                    "t1" => Dict{String,Any}(
                        "bus_from" => "hv", "bus_to" => "lv",
                        "terminal_map_from" => ["a", "n"],
                        "terminal_map_to"   => ["a", "n"],
                        "v_nom_from" => 11000.0, "v_nom_to" => 400.0,
                        "r_series_from" => 0.0, "x_series_from" => 0.0,
                        "r_series_to"   => 0.0, "x_series_to"   => x_to),
                ),
            ),
            "shunt" => Dict{String,Any}(
                "sh1" => Dict{String,Any}(
                    "bus" => "lv", "terminal_map" => ["a"],
                    "G_1_1" => 0.05, "B_1_1" => 0.0),
            ),
        )
    end

    @testset "ideal single_phase: constraint solution is exact" begin
        y = 0.05
        N = 11000.0 / 400.0
        net = _sp_xfmr_net()
        r = ybus_augmented(net)
        @test length(r.couplings) == 1
        c = r.couplings[1]
        @test c.kind == :ideal_xfmr && c.id == "single_phase/t1"
        K = denseK(r)
        @test maximum(abs.(K .- transpose(K))) < 1e-12

        Iinj = 2.0 + 0.0im
        inj = zeros(ComplexF64, length(r.nodes)); inj[r.index[("hv", "a")]] = Iinj
        x = solveK(r, inj)
        V_hv = x[r.index[("hv", "a")]]; V_lv = x[r.index[("lv", "a")]]
        # Ideal transformer, LV shunt y: V_lv = N·I/y, V_hv = N·V_lv = N²·I/y,
        # and the coil constraint V_hv = N·V_lv holds identically.
        @test V_lv ≈ N * Iinj / y  rtol=1e-12
        @test V_hv ≈ N * V_lv     rtol=1e-12
        # Winding currents: LV coil current = N × HV coil current.
        w = x[end]
        i_hv = c.scale * w * c.coeffs[findfirst(==(r.index[("hv", "a")]), c.nodes)]
        i_lv = c.scale * w * c.coeffs[findfirst(==(r.index[("lv", "a")]), c.nodes)]
        @test i_hv ≈ Iinj      atol=1e-12
        @test i_lv ≈ -N * Iinj rtol=1e-12
    end

    @testset "ideal single_phase = leakage→0 limit of ybus_passive" begin
        Iinj = 2.0 + 0.0im
        # Ideal (constraint) reference solution. With a current injection the
        # LV voltage is leakage-INdependent (the coil current is forced), so
        # the limit shows up at the HV node: V_hv(x_to) = V_hv(0) + Z_ref·I.
        r0 = ybus_augmented(_sp_xfmr_net())
        inj0 = zeros(ComplexF64, length(r0.nodes)); inj0[r0.index[("hv", "a")]] = Iinj
        x0 = solveK(r0, inj0)
        Vhv0 = x0[r0.index[("hv", "a")]]
        Vlv0 = x0[r0.index[("lv", "a")]]

        errs = Float64[]
        for x_to in (1e-1, 1e-3, 1e-5)     # Ω, all above xfmr_z_min_ohm = 1e-6
            rp = ybus_passive(_sp_xfmr_net(; x_to))
            inj = zeros(ComplexF64, length(rp.nodes)); inj[rp.index[("hv", "a")]] = Iinj
            x = Matrix(rp.Y) \ inj
            push!(errs, abs(x[rp.index[("hv", "a")]] - Vhv0))
            # LV voltage matches the ideal solution at every leakage (up to the
            # conditioning noise of the near-singular stamp).
            @test x[rp.index[("lv", "a")]] ≈ Vlv0 atol=1e-5
        end
        @test issorted(errs; rev=true)          # monotone approach to the limit
        @test errs[end] < 1e-6 * abs(Vhv0)      # and it converges to the constraint
    end

    # ── ideal delta_wye: leakage→0 limit, per-phase couplings ─────────────────

    function _dy_xfmr_net(; x_to::Float64=0.0)
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "hv" => Dict{String,Any}("terminal_names" => ["a", "b", "c"]),
                "lv" => Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"],
                                         "perfectly_grounded_terminals" => ["n"]),
            ),
            "transformer" => Dict{String,Any}(
                "delta_wye" => Dict{String,Any}(
                    "t1" => Dict{String,Any}(
                        "bus_from" => "hv", "bus_to" => "lv",
                        "terminal_map_from" => ["a", "b", "c"],
                        "terminal_map_to"   => ["a", "b", "c", "n"],
                        "v_nom_from" => 11000.0, "v_nom_to" => 400.0,
                        "r_series_from" => 0.0, "x_series_from" => 0.0,
                        "r_series_to"   => 0.0, "x_series_to"   => x_to),
                ),
            ),
            # Wye shunt loads on the LV phases; small HV shunts pin the delta
            # side's common mode (otherwise it is a genuine floating reference).
            "shunt" => Dict{String,Any}(
                "lv_load" => Dict{String,Any}(
                    "bus" => "lv", "terminal_map" => ["a", "b", "c"],
                    "G_1_1" => 0.05, "G_2_2" => 0.04, "G_3_3" => 0.06),
                "hv_ref" => Dict{String,Any}(
                    "bus" => "hv", "terminal_map" => ["a", "b", "c"],
                    "G_1_1" => 1e-3, "G_2_2" => 1e-3, "G_3_3" => 1e-3),
            ),
        )
        net
    end

    @testset "ideal delta_wye = leakage→0 limit of ybus_passive" begin
        # Unbalanced complex injection on the HV phases.
        α = cis(-2π/3)
        inj_of(index) = begin
            inj = Dict(("hv","a") => 1.0 + 0im, ("hv","b") => 0.8α, ("hv","c") => 1.1α^2)
            v = zeros(ComplexF64, maximum(values(index)))
            for (nd, i) in inj; v[index[nd]] = i; end
            v
        end

        r0 = ybus_augmented(_dy_xfmr_net())
        @test length(r0.couplings) == 3
        @test all(c -> c.kind == :ideal_xfmr, r0.couplings)
        K = denseK(r0)
        @test maximum(abs.(K .- transpose(K))) < 1e-12
        x0 = solveK(r0, inj_of(r0.index))
        V0 = [x0[r0.index[("lv", t)]] for t in ("a", "b", "c")]

        errs = Float64[]
        for x_to in (1e-1, 1e-3, 1e-5)
            rp = ybus_passive(_dy_xfmr_net(; x_to))
            x = Matrix(rp.Y) \ inj_of(rp.index)
            V = [x[rp.index[("lv", t)]] for t in ("a", "b", "c")]
            push!(errs, maximum(abs.(V .- V0)))
        end
        @test issorted(errs; rev=true)
        @test errs[end] < 1e-6 * maximum(abs.(V0))
    end

    # ── unity-ratio zero-leakage transformers stay aliased ───────────────────

    @testset "unity-ratio ideal transformer stays node-aliased" begin
        net = _sp_xfmr_net()
        x1 = net["transformer"]["single_phase"]["t1"]
        x1["v_nom_from"] = 400.0     # ratio 1:1 → exact node identity
        r = ybus_augmented(net)
        @test isempty(r.couplings)
        @test r.index[("hv", "a")] == r.index[("lv", "a")]
    end

    # ── validation ────────────────────────────────────────────────────────────

    @testset "argument validation" begin
        net = _sp_xfmr_net()
        @test_throws ArgumentError ybus_augmented(net; switches=:bogus)
        @test_throws ArgumentError ybus_augmented(net; ideal_xfmrs=:bogus)

        # Degenerate coil ratio (tap = 0 ⇒ ratio 0) must error, not stamp.
        net["transformer"]["single_phase"]["t1"]["tap"] = 0.0
        @test_throws ArgumentError ybus_augmented(net)
    end
end
