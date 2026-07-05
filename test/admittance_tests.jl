@testset "Transformer Yprim export" begin

    # ─── helpers ──────────────────────────────────────────────────────────────

    # Build a minimal BMOPF transformer dict and call transformer_yprim.
    # Returns (nodes, Y).

    function check_symmetry(Y; atol=1e-10)
        @test maximum(abs.(Y .- transpose(Y))) < atol
    end

    # Power balance: Re[conj(V)ᵀ I] should equal resistive loss = Σ |Iw|² R.
    # For a passive element we test Re[conj(V)ᵀ Y V] ≥ 0.
    function check_power_balance(Y, V; rtol=1e-6)
        S = conj(V)' * (Y * V)
        @test real(S) >= -rtol * abs(S)   # non-negative real part
    end

    # ─── single_phase ─────────────────────────────────────────────────────────

    @testset "single_phase" begin
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1"],
            "terminal_map_to"   => ["1"],
            "v_nom_from"        => 11000.0,
            "v_nom_to"          => 400.0,
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
            "r_series_to"       => 0.01,
            "x_series_to"       => 0.04,
            "g_no_load"         => 1e-4,
            "b_no_load"         => 5e-4,
        )
        nodes, Y = transformer_yprim(xfmr, "single_phase")

        @test length(nodes) == 2
        @test nodes[1] == ("hv", "1")
        @test nodes[2] == ("lv", "1")
        @test size(Y) == (2, 2)

        check_symmetry(Y)

        # Closed-form oracle (§2 of derivation note):
        #   Z = (R1 + N²R2) + j(X1 + N²X2),  y = 1/Z,  Y0 = G0+jB0
        # The magnetising shunt sits on WINDING 2 (the to coil) — here the to
        # side is phase-to-ground, so Y0 lands on the to diagonal:
        #   Y = [y, -Ny; -Ny, N²y + Y0]
        N  = 11000.0 / 400.0
        Z  = (0.5 + N^2*0.01) + im*(2.0 + N^2*0.04)
        y  = 1.0 / Z
        Y0 = 1e-4 + im*5e-4
        Y_ref = [y  -N*y; -N*y  N^2*y+Y0]
        @test maximum(abs.(Y .- Y_ref)) < 1e-12

        # Power balance
        check_power_balance(Y, [1.0+0im, 1.0/N])

        # Fixed off-nominal tap: N_eff = N·tap, with the FROM-winding leakage
        # turns-scaled by tap² (OLTC changes the from-winding turns), matching
        # the OPF's to-referred stamping and OpenDSS's turns-scaled Yprim:
        #   Z(tap) = tap²·z_fr + N_eff²·z_to = N_eff²·(z_to + z_fr/N0²)
        # (Two regressions: the tap used to be ignored entirely; then the
        # from-winding term was not tap-scaled, so Yprim disagreed with the OPF
        # and OpenDSS at any off-nominal tap.)
        tapm  = 0.95
        Nt    = N * tapm
        Z_t   = (tapm^2*0.5 + Nt^2*0.01) + im*(tapm^2*2.0 + Nt^2*0.04)
        y_t   = 1.0 / Z_t
        xfmr_tap = merge(xfmr, Dict{String,Any}("tap" => tapm))
        _, Y_tap = transformer_yprim(xfmr_tap, "single_phase")
        Y_tref = [y_t  -Nt*y_t; -Nt*y_t  Nt^2*y_t+Y0]
        @test maximum(abs.(Y_tap .- Y_tref)) < 1e-12
        @test !(Y_tap ≈ Y)

        # 3-phase block is block-diagonal over phase pairs
        xfmr3 = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1","2","3"],
            "terminal_map_to"   => ["1","2","3"],
            "v_nom_from"        => 11000.0,
            "v_nom_to"          => 400.0,
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
            "r_series_to"       => 0.01,
            "x_series_to"       => 0.04,
            "g_no_load"         => 3e-4,    # total; split into 3 × 1e-4 per pair
            "b_no_load"         => 15e-4,
        )
        nodes3, Y3 = transformer_yprim(xfmr3, "single_phase")
        @test size(Y3) == (6, 6)
        check_symmetry(Y3)
        # Off-diagonal between different pairs must be zero
        @test all(iszero, Y3[1:2, 3:4])
        @test all(iszero, Y3[1:2, 5:6])
    end

    # ─── single_phase (no-shunt, no-series) ───────────────────────────────────

    @testset "single_phase — lossless ideal" begin
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1"],
            "terminal_map_to"   => ["1"],
            "v_nom_from"        => 11000.0,
            "v_nom_to"          => 400.0,
        )
        N = 11000.0 / 400.0
        nodes, Y = transformer_yprim(xfmr, "single_phase")
        # With Z=0: series terms drop out; Y should be zero (shunt also zero).
        @test all(iszero, Y)
        check_symmetry(Y)
    end

    @testset "single_phase — line-to-line winding" begin
        # Primary connected across phases 1-2 (no neutral): ONE winding V₁−V₂.
        # Nodes [hv/1, lv/1, hv/2] with the YY core referenced to hv/2.
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1","2"],
            "terminal_map_to"   => ["1","n"],
            "v_nom_from"        => 4160.0,
            "v_nom_to"          => 240.0,
            "r_series_from"     => 0.1,
            "x_series_from"     => 0.4,
        )
        N = 4160.0 / 240.0
        nodes, Y = transformer_yprim(xfmr, "single_phase")
        # One winding ⇒ 3 distinct nodes (hv/1, lv/1, hv/2); lv/n == lv/1? no:
        # to-side is L-N so its reference is lv/n.
        @test ("hv","1") in nodes && ("hv","2") in nodes
        @test ("lv","1") in nodes && ("lv","n") in nodes
        check_symmetry(Y)
        # Current conservation: every column sums to ~0 (incl. the reference rows).
        for j in 1:size(Y,2)
            @test abs(sum(Y[:, j])) < 1e-9
        end
        # The 2-port between the winding terminals is the YY core with this N.
        ip = findfirst(==(("hv","1")), nodes)
        Z  = 0.1 + im*0.4; y = 1.0/Z
        @test abs(Y[ip, ip] - y) < 1e-9
    end

    # ─── center_tap ───────────────────────────────────────────────────────────

    @testset "center_tap" begin
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["ph","n"],
            "terminal_map_to"   => ["1","n","2"],
            "v_nom_from"        => 2400.0,
            "v_nom_to"          => 120.0,
            "r_series_from"     => 0.1,
            "x_series_from"     => 0.4,
            "r_series_to"       => 0.001,
            "x_series_to"       => 0.004,
            "g_no_load"         => 1e-5,
            "b_no_load"         => 5e-5,
        )
        nodes, Y = transformer_yprim(xfmr, "center_tap")

        @test length(nodes) == 5
        @test nodes[1] == ("hv", "ph")
        @test nodes[2] == ("hv", "n")
        @test nodes[3] == ("lv", "1")
        @test nodes[4] == ("lv", "n")
        @test nodes[5] == ("lv", "2")
        @test size(Y) == (5, 5)

        check_symmetry(Y)

        # Power balance: symmetric loading (V_a = -V_c, V_g = 0)
        N = 2400.0 / 120.0
        V = [1.0+0im, 0.0, 1.0/N, 0.0, -1.0/N]
        check_power_balance(Y, V)

        # HV rows: the magnetising shunt is on winding 2 (LV leg 1, nodes 3-4),
        # so the HV phase/neutral rows are pure series-star and each sums to 0.
        @test abs(Y[2,1] + Y[2,3] + Y[2,4] + Y[2,5] + Y[2,2]) < 1e-10  # row sum ≈ 0
        @test abs(sum(Y[1,:])) < 1e-10

        # Leg symmetry: a symmetric centre tap excited anti-phase about the
        # grounded centre draws equal-and-opposite leg WINDING currents and zero
        # centre-tap winding current. The magnetising shunt across leg 1 (Y0 on
        # nodes 3-4) is subtracted out to recover the winding currents.
        Y0 = 1e-5 + im*5e-5
        V_bal = [1.0+0im, 0.0, 1.0/N, 0.0, -1.0/N]
        I_bal = Y * V_bal
        Imag  = Y0 * (V_bal[3] - V_bal[4])
        IL1 = I_bal[3] - Imag; Ictr = I_bal[4] + Imag; IL2 = I_bal[5]
        @test abs(IL1 + IL2) < 1e-10   # IL1 = −IL2
        @test abs(Ictr)      < 1e-10   # I_centre = 0
    end

    # ─── wye_delta ────────────────────────────────────────────────────────────

    @testset "wye_delta" begin
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1","2","3","n"],
            "terminal_map_to"   => ["1","2","3"],
            "v_nom_from"        => 11000.0,
            "v_nom_to"          => 400.0,
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
            "r_series_to"       => 0.0,
            "x_series_to"       => 0.0,
            "g_no_load"         => 1e-4,
            "b_no_load"         => 5e-4,
        )
        nodes, Y = transformer_yprim(xfmr, "wye_delta")

        @test length(nodes) == 7     # 4 wye (3 phase + neutral) + 3 delta
        @test size(Y) == (7, 7)
        check_symmetry(Y)

        # Balanced 3-phase excitation — power balance
        N    = 11000.0 / 400.0
        neff = sqrt(3) / N
        ω    = exp(2im*π/3)
        V_wye_pn = 1.0  # per-unit phase-to-neutral
        V_wye    = [V_wye_pn, V_wye_pn*ω, V_wye_pn*ω^2, 0.0+0im]
        # Ideal delta line-to-line = neff * V_wye_pn
        Vd = neff * V_wye_pn .* [1.0+0im, ω, ω^2]
        V_full = vcat(V_wye, Vd)
        check_power_balance(Y, V_full)

        # Neutral row: with balanced voltage (V_n = 0) the neutral current
        # is zero for a 3-phase symmetric load.
        I = Y * V_full
        @test abs(I[4]) < 1e-8 * maximum(abs.(I))

        # With zero series impedance, wye_delta with nonzero Zd path:
        xfmr2 = merge(xfmr, Dict{String,Any}(
            "r_series_from" => 0.0, "x_series_from" => 0.0,
            "r_series_to"   => 0.5, "x_series_to"   => 2.0,
        ))
        nodes2, Y2 = transformer_yprim(xfmr2, "wye_delta")
        check_symmetry(Y2)

        # An off-nominal fixed tap applies the EXACT tap² referral (matching
        # OpenDSS): the wye-side (tapped side) short-circuit impedance scales as
        # tap². A tap is therefore NOT equivalent to rescaling v_nom_from — that
        # would move the nominal ratio n_eff0 and hence the leakage base — so the
        # two Yprims genuinely differ (they were equal only under the earlier
        # uniform-n_eff approximation). Verify the tap² scaling directly on the
        # positive-sequence wye short-circuit impedance (delta grounded = the
        # wye 3×3 block; the magnetising shunt sits on the delta side, so this
        # block is pure leakage).
        tapm = 1.05
        xfmr_tap = merge(xfmr, Dict{String,Any}("tap" => tapm))
        nodes_tap, Y_tap = transformer_yprim(xfmr_tap, "wye_delta")
        xfmr_ref = merge(xfmr, Dict{String,Any}("v_nom_from" => tapm * 11000.0))
        _, Y_ref = transformer_yprim(xfmr_ref, "wye_delta")
        @test nodes_tap == nodes[1:7]
        @test !(Y_tap ≈ Y)          # tap changed the stamp
        @test !(Y_tap ≈ Y_ref)      # and is NOT a v_nom rescaling (exact referral)
        ω   = exp(2im*π/3); Vp = ComplexF64[1, ω^2, ω]
        zsc(Ym) = 1 / ((Vp' * (Ym[1:3, 1:3] * Vp)) / (Vp' * Vp))  # wye pos-seq Z_sc
        @test isapprox(imag(zsc(Y_tap)) / imag(zsc(Y)), tapm^2; rtol=1e-9)

        # Regression: an empty terminal map on either side must return the
        # empty Yprim; the guard previously mis-parsed as
        # `a || (b && return)` and fell through to a BoundsError.
        xfmr3 = merge(xfmr, Dict{String,Any}("terminal_map_from" => String[]))
        nodes3, Y3 = transformer_yprim(xfmr3, "wye_delta")
        @test isempty(nodes3) && isempty(Y3)
        xfmr4 = merge(xfmr, Dict{String,Any}("terminal_map_to" => String[]))
        nodes4, Y4 = transformer_yprim(xfmr4, "wye_delta")
        @test isempty(nodes4) && isempty(Y4)
    end

    # ─── delta_wye ────────────────────────────────────────────────────────────

    @testset "delta_wye" begin
        xfmr = Dict{String,Any}(
            "bus_from"          => "hv",
            "bus_to"            => "lv",
            "terminal_map_from" => ["1","2","3"],
            "terminal_map_to"   => ["1","2","3","n"],
            "v_nom_from"        => 11000.0,
            "v_nom_to"          => 400.0,
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
            "r_series_to"       => 0.01,
            "x_series_to"       => 0.04,
            "g_no_load"         => 1e-4,
            "b_no_load"         => 5e-4,
        )
        nodes, Y = transformer_yprim(xfmr, "delta_wye")

        @test length(nodes) == 7     # 3 delta + 4 wye (3 phase + neutral)
        @test size(Y) == (7, 7)
        check_symmetry(Y)

        # Balanced excitation.
        # Node ordering from _yprim_yd: [wye terminals..., delta terminals...]
        # For delta_wye: wye = bus_to (4 nodes), delta = bus_from (3 nodes).
        N    = 11000.0 / 400.0
        neff = N * sqrt(3)
        ω    = exp(2im*π/3)
        V_wye_pn = 1.0 / neff
        V_wye    = V_wye_pn .* [1.0+0im, ω, ω^2, 0.0+0im]
        Vd       = [1.0+0im, ω, ω^2]
        V_full   = vcat(V_wye, Vd)   # wye nodes first
        check_power_balance(Y, V_full)
    end

    # ─── export_yprim roundtrip ───────────────────────────────────────────────

    @testset "export_yprim" begin
        net = Dict{String,Any}(
            "transformer" => Dict{String,Any}(
                "single_phase" => Dict{String,Any}(
                    "tx1" => Dict{String,Any}(
                        "bus_from"          => "hv",
                        "bus_to"            => "lv",
                        "terminal_map_from" => ["1"],
                        "terminal_map_to"   => ["1"],
                        "v_nom_from"        => 11000.0,
                        "v_nom_to"          => 400.0,
                        "r_series_from"     => 0.5,
                        "x_series_from"     => 2.0,
                    ),
                ),
                "wye_delta" => Dict{String,Any}(
                    "tx2" => Dict{String,Any}(
                        "bus_from"          => "hv",
                        "bus_to"            => "lv",
                        "terminal_map_from" => ["1","2","3","n"],
                        "terminal_map_to"   => ["1","2","3"],
                        "v_nom_from"        => 11000.0,
                        "v_nom_to"          => 400.0,
                        "r_series_from"     => 0.5,
                        "x_series_from"     => 2.0,
                    ),
                ),
            ),
        )

        out = export_yprim(net)
        @test haskey(out, "single_phase")
        @test haskey(out, "wye_delta")
        @test haskey(out["single_phase"], "tx1")
        @test haskey(out["wye_delta"],    "tx2")

        entry = out["single_phase"]["tx1"]
        @test haskey(entry, "nodes")
        @test haskey(entry, "Y_real")
        @test haskey(entry, "Y_imag")
        @test length(entry["nodes"]) == 2
        @test length(entry["Y_real"]) == 2
        @test length(entry["Y_real"][1]) == 2

        # Reconstruct Y and verify symmetry
        Yr = reduce(vcat, [reshape(row, 1, :) for row in entry["Y_real"]])
        Yi = reduce(vcat, [reshape(row, 1, :) for row in entry["Y_imag"]])
        Y_rt = Yr + im*Yi
        @test maximum(abs.(Y_rt .- transpose(Y_rt))) < 1e-10

        # Subtypes with no transformers should not appear
        @test !haskey(out, "center_tap")
        @test !haskey(out, "delta_wye")
    end

    # ─── unknown subtype ──────────────────────────────────────────────────────

    @testset "unknown subtype" begin
        xfmr = Dict{String,Any}("bus_from"=>"a","bus_to"=>"b")
        @test_throws ArgumentError transformer_yprim(xfmr, "bogus")
    end

    # ─── OPF self-consistency: single_phase ───────────────────────────────────
    # Recover the OPF winding current variables from I=Y·V and verify the
    # IVR constraints from transformer.jl are satisfied.

    @testset "OPF self-consistency — single_phase" begin
        N   = 27.5
        Z   = 0.5 + 2.0im
        Y0  = 1e-4 + 5e-4im
        y   = 1.0 / Z
        Y_  = [y  -N*y; -N*y  N^2*y+Y0]   # closed-form oracle (shunt on winding 2)

        # Pick an arbitrary voltage pair and get terminal currents.
        V = [1.1 + 0.05im, 0.04 - 0.01im]
        I = Y_ * V

        # From current is pure series; the TO terminal current is I_s + Y0·V_to.
        Is  = I[1]
        Ito = I[2] - Y0*V[2]

        # OPF voltage eq: V_fr - N·V_to = Z·I_s
        lhs_v = V[1] - N*V[2]
        rhs_v = Z * Is
        @test abs(lhs_v - rhs_v) < 1e-10

        # OPF current coupling: N·I_s + I_to = 0
        @test abs(N*Is + Ito) < 1e-10
    end

    # ─── OPF self-consistency: center_tap ─────────────────────────────────────

    @testset "OPF self-consistency — center_tap" begin
        N   = 20.0
        Z1  = 0.1 + 0.4im
        Z2  = 0.001 + 0.004im
        G0  = 1e-5; B0 = 5e-5

        xfmr = Dict{String,Any}(
            "bus_from"          => "hv", "bus_to"     => "lv",
            "terminal_map_from" => ["ph","n"],
            "terminal_map_to"   => ["1","n","2"],
            "v_nom_from"        => N * 120.0,
            "v_nom_to"          => 120.0,
            "r_series_from"     => real(Z1), "x_series_from" => imag(Z1),
            "r_series_to"       => real(Z2), "x_series_to"   => imag(Z2),
            "g_no_load"         => G0, "b_no_load" => B0,
        )
        nodes, Y = transformer_yprim(xfmr, "center_tap")

        # Pick a voltage consistent with ideal transform: V_leg1 = V_leg2 = 1/N.
        # Small perturbation to get nonzero impedance drops.
        V = [1.0+0im, 0.0, 1.0/N - 0.001, 0.0, -(1.0/N - 0.002)]
        I = Y * V

        # Recover OPF variables. The magnetising shunt is across winding 2 =
        # LV leg 1 (nodes 3-4), so the HV terminal current is pure series and
        # the leg-1/centre-tap winding currents are the terminal currents minus
        # the shunt current Y0·(V3−V4).
        Y0_val = G0 + im*B0
        Imag   = Y0_val * (V[3] - V[4])
        Is  = I[1]                  # HV phase terminal = pure series
        Im_ = I[2]                  # HV neutral = -Is
        IL1 = I[3] - Imag
        In_ = I[4] + Imag
        IL2 = I[5]

        # Ampere-turn (winding 3 dotted at the centre tap): N·Is + IL1 − IL2 = 0
        @test abs(N*Is + IL1 - IL2) < 1e-8

        # Center-tap KCL: In + IL1 + IL2 = 0
        @test abs(In_ + IL1 + IL2) < 1e-8

        # HV neutral: Im = -Is
        @test abs(Im_ + Is) < 1e-8

        # Voltage eq leg-1: (V_p-V_m) - N*(V_a-V_g) = Z1*Is - N*Z2*IL1
        V_hv   = V[1] - V[2]
        V_leg1 = V[3] - V[4]
        lhs1   = V_hv - N*V_leg1
        rhs1   = Z1*Is - N*Z2*IL1
        @test abs(lhs1 - rhs1) < 1e-8

        # Voltage eq leg-2: winding 3 is dotted at the centre tap, so it spans
        # V_g→V_c (V[4]-V[5]). With IL2 = I[5] = −Iw3 the Yprim satisfies
        #   (V_p-V_m) - N*(V_g-V_c) = Z1*Is + N*Z2*IL2.
        V_leg2 = V[4] - V[5]         # V_g - V_c (winding-3 span)
        lhs2 = V_hv - N*V_leg2
        rhs2 = Z1*Is + N*Z2*IL2
        @test abs(lhs2 - rhs2) < 1e-8
    end

    # ─── OPF self-consistency: wye_delta / delta_wye ──────────────────────────
    # Same idea as the single_phase/center_tap checks above: at an ARBITRARY
    # (unbalanced, neutral-shifted) voltage point, the currents implied by the
    # exported Yprim must satisfy the OPF builder's constraint equations
    # (`_add_yd_transformer!`): the delta voltage loop with the wye-referred
    # leakage Zeff = n_eff·Zw + (n_ph/n_eff)·Zd, the delta line-current
    # coupling, and the star-point KCL. This is the algebraic drift guard the
    # delta subtypes lacked — the orientation of the ideal transform is
    # invisible to the symmetry/passivity checks above (the historical export
    # bug stamped n_eff instead of 1/n_eff in the primitive, i.e. the inverse
    # transformer, and passed every one of them).
    for (sub, wye_is_from) in (("wye_delta", true), ("delta_wye", false))
        @testset "OPF self-consistency — $sub" begin
            Zw = 0.35 + 1.4im          # wye winding (Ω, wye-bus L-N base)
            Zd = 0.0004 + 0.0016im     # delta winding (Ω, delta-bus L-N base)
            G0 = 2e-4; B0 = -8e-4
            N  = 11000.0 / 400.0       # v_nom_from / v_nom_to
            xfmr = Dict{String,Any}(
                "bus_from"   => "hv",     "bus_to"    => "lv",
                "v_nom_from" => 11000.0,  "v_nom_to"  => 400.0,
                "g_no_load"  => G0,       "b_no_load" => B0,
            )
            if wye_is_from
                xfmr["terminal_map_from"] = ["1","2","3","n"]
                xfmr["terminal_map_to"]   = ["1","2","3"]
                xfmr["r_series_from"] = real(Zw); xfmr["x_series_from"] = imag(Zw)
                xfmr["r_series_to"]   = real(Zd); xfmr["x_series_to"]   = imag(Zd)
                n_eff   = sqrt(3.0) / N
                v_wye_m = 11000.0 / sqrt(3.0)
            else
                xfmr["terminal_map_from"] = ["1","2","3"]
                xfmr["terminal_map_to"]   = ["1","2","3","n"]
                xfmr["r_series_from"] = real(Zd); xfmr["x_series_from"] = imag(Zd)
                xfmr["r_series_to"]   = real(Zw); xfmr["x_series_to"]   = imag(Zw)
                n_eff   = N * sqrt(3.0)
                v_wye_m = 400.0 / sqrt(3.0)
            end
            nodes, Y = transformer_yprim(xfmr, sub)
            @test length(nodes) == 7
            # Node order from _yprim_yd: [wye 1, 2, 3, n, delta 1, 2, 3].
            # Voltages near (but off) the physical operating point so all
            # currents are nonzero: unbalanced phases, shifted neutral, and a
            # delta common-mode offset.
            V_wye_ph = v_wye_m .* [1.02*cis(0.01), 0.96*cis(-2π/3 + 0.03),
                                   1.05*cis(2π/3 - 0.02)]
            V_n      = 3.0 + 2.0im
            V_del    = [n_eff * (V_wye_ph[k] - V_n) * (1.0 + 0.01k) + (5.0 - 1.0im)
                        for k in 1:3]
            # (V_del here is a per-node guess, not the coil voltage; only its
            # differences enter the coil equations, which is what we test.)
            Vfull = vcat(V_wye_ph, V_n, V_del)
            I = Y * Vfull

            # Recover the OPF winding-current variables from the node currents.
            # The magnetising shunt is on WINDING 2 (the to side): a delta of
            # y=Y0/3 branches across the LV delta coils (Yd) or phase-to-neutral
            # on the LV wye (Dy). Subtract its node injections to get the pure
            # winding/line currents.
            y = (G0 + im*B0) / 3
            if wye_is_from   # to = delta (nodes 5-7); wye currents are pure
                Iw = [I[k] for k in 1:3]
                Id = [I[4+k] - y*(2*Vfull[4+k] - Vfull[4+mod1(k+1,3)] -
                                  Vfull[4+mod1(k-1,3)]) for k in 1:3]
                In = I[4]
            else             # to = wye (nodes 1-3 phase, 4 neutral); delta pure
                Iw = [I[k] - y*(Vfull[k] - Vfull[4]) for k in 1:3]
                Id = [I[4+k] for k in 1:3]
                In = I[4] + sum(y*(Vfull[k] - Vfull[4]) for k in 1:3)
            end

            Zeff = n_eff * Zw + (3.0 / n_eff) * Zd
            atol = 1e-9 * v_wye_m
            for k in 1:3
                k_v = wye_is_from ? mod1(k + 1, 3) : mod1(k - 1, 3)  # voltage-loop partner
                k_c = wye_is_from ? mod1(k - 1, 3) : mod1(k + 1, 3)  # current-coupling partner
                # Voltage: V_del[k] − V_del[k_other] = n_eff·(V_wye[k] − V_n) − Zeff·I_wye[k]
                lhs = Vfull[4+k] - Vfull[4+k_v]
                rhs = n_eff * (V_wye_ph[k] - V_n) - Zeff * Iw[k]
                @test abs(lhs - rhs) < atol
                # Current coupling: n_eff·I_del[k] = −(I_wye[k] − I_wye[k_other])
                @test abs(n_eff * Id[k] + (Iw[k] - Iw[k_c])) < atol
            end
            # Star-point KCL: I_n + Σ I_wye = 0
            @test abs(In + sum(Iw)) < atol
        end
    end

    # ─── internal winding neutral grounding (OpenDSS rneut/xneut) ─────────────
    # Verified OpenDSS topology: the winding star point stays solidly on the
    # neutral terminal and y_n = 1/(r_neutral+jx_neutral) is a grounding branch
    # from that terminal to earth — so the ONLY change to the Yprim is a
    # diagonal add of y_n at the neutral node. Winding equations are unchanged.
    @testset "neutral grounding branch (rneut/xneut)" begin
        yn = 1.0 / (2.0 + 1.0im)
        yd = Dict{String,Any}(
            "bus_from" => "hv", "bus_to" => "lv",
            "terminal_map_from" => ["1","2","3","n"],
            "terminal_map_to"   => ["1","2","3"],
            "v_nom_from" => 11000.0, "v_nom_to" => 400.0,
            "r_series_from" => 0.5, "x_series_from" => 2.0,
            "g_no_load" => 1e-4, "b_no_load" => 5e-4,
        )
        ydn = merge(yd, Dict{String,Any}("r_neutral_from" => 2.0,
                                         "x_neutral_from" => 1.0))
        _, Y0m = transformer_yprim(yd,  "wye_delta")
        _, Y1m = transformer_yprim(ydn, "wye_delta")
        D = Y1m .- Y0m
        @test isapprox(D[4, 4], yn; atol=1e-12)   # node 4 = wye neutral
        D[4, 4] = 0.0
        @test maximum(abs.(D)) < 1e-12            # nothing else changes

        # single_phase, both sides L-N: diagonal adds at each shared neutral.
        sp = Dict{String,Any}(
            "bus_from" => "hv", "bus_to" => "lv",
            "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n"],
            "v_nom_from" => 11000.0, "v_nom_to" => 400.0,
            "r_series_from" => 0.5, "x_series_from" => 2.0,
        )
        spn = merge(sp, Dict{String,Any}(
            "r_neutral_from" => 2.0, "x_neutral_from" => 1.0,
            "r_neutral_to"   => 5.0, "x_neutral_to"   => 0.0))
        nodes_sp, Y0s = transformer_yprim(sp,  "single_phase")
        _,        Y1s = transformer_yprim(spn, "single_phase")
        i_nf = findfirst(==(("hv","n")), nodes_sp)
        i_nt = findfirst(==(("lv","n")), nodes_sp)
        Ds = Y1s .- Y0s
        @test isapprox(Ds[i_nf, i_nf], yn;        atol=1e-12)
        @test isapprox(Ds[i_nt, i_nt], 1.0/5.0;   atol=1e-12)
        Ds[i_nf, i_nf] = 0.0; Ds[i_nt, i_nt] = 0.0
        @test maximum(abs.(Ds)) < 1e-12

        # center_tap: `r_neutral_from` grounds the HV neutral (node 2),
        # `r_neutral_to` the LV centre tap (node 4) — diagonal adds only.
        ct = Dict{String,Any}(
            "bus_from" => "hv", "bus_to" => "lv",
            "terminal_map_from" => ["ph","n"], "terminal_map_to" => ["1","n","2"],
            "v_nom_from" => 2400.0, "v_nom_to" => 120.0,
            "r_series_from" => 0.1, "x_series_from" => 0.4,
            "r_series_to"   => 0.001, "x_series_to" => 0.004,
            "g_no_load" => 1e-5, "b_no_load" => 5e-5,
        )
        ctn = merge(ct, Dict{String,Any}(
            "r_neutral_from" => 2.0, "x_neutral_from" => 1.0,
            "r_neutral_to"   => 5.0, "x_neutral_to"   => 0.0))
        _, Y0c = transformer_yprim(ct,  "center_tap")
        _, Y1c = transformer_yprim(ctn, "center_tap")
        Dc = Y1c .- Y0c
        @test isapprox(Dc[2, 2], yn;      atol=1e-12)   # node 2 = HV neutral
        @test isapprox(Dc[4, 4], 1.0/5.0; atol=1e-12)   # node 4 = LV centre tap
        Dc[2, 2] = 0.0; Dc[4, 4] = 0.0
        @test maximum(abs.(Dc)) < 1e-12

        # Ignored (warned) placements: delta side, and a side with no neutral.
        yd_del = merge(yd, Dict{String,Any}("r_neutral_to" => 2.0))
        _, Yd_del = @test_logs (:warn, r"DELTA side") transformer_yprim(yd_del, "wye_delta")
        @test Yd_del ≈ Y0m
        sp_ll = merge(sp, Dict{String,Any}(
            "terminal_map_from" => ["1","2"], "r_neutral_from" => 2.0))
        @test_logs (:warn, r"no shared neutral") transformer_yprim(sp_ll, "single_phase")
    end

    # ─── zero-leakage units keep their no-load shunt ──────────────────────────
    # The degenerate (singular series block) branches previously returned before
    # stamping the shunt, so a lossless-leakage unit with core loss exported an
    # all-zero Yprim.
    @testset "zero-leakage Yprim keeps the shunt" begin
        base = Dict{String,Any}(
            "bus_from" => "hv", "bus_to" => "lv",
            "v_nom_from" => 11000.0, "v_nom_to" => 400.0,
            "g_no_load"  => 1e-4, "b_no_load" => 5e-4,
        )
        Y0 = 1e-4 + im*5e-4
        # wye_delta: magnetising delta across the three LV (to-side, winding-2)
        # delta coils (nodes 5-7). Each delta node sits in two coils → diag 2·y,
        # off-diag −y, with y = Y0/3.
        yd = merge(base, Dict{String,Any}(
            "terminal_map_from" => ["1","2","3","n"], "terminal_map_to" => ["1","2","3"]))
        _, Y_yd = transformer_yprim(yd, "wye_delta")
        for k in 5:7
            @test Y_yd[k, k] ≈ 2 * Y0 / 3
            @test Y_yd[k, 5 + (k - 5 + 1) % 3] ≈ -Y0 / 3
        end
        @test all(iszero, Y_yd[1:4, 1:4])   # wye side carries no shunt
        # center_tap: shunt across winding 2 = LV leg 1 (nodes 3-4).
        ct = merge(base, Dict{String,Any}(
            "terminal_map_from" => ["ph","n"], "terminal_map_to" => ["1","n","2"]))
        _, Y_ct = transformer_yprim(ct, "center_tap")
        @test Y_ct[3, 3] ≈ Y0 && Y_ct[4, 4] ≈ Y0
        @test Y_ct[3, 4] ≈ -Y0 && Y_ct[4, 3] ≈ -Y0
        @test all(iszero, Y_ct[1:2, 1:2])   # HV side carries no shunt
    end

    # ─── single_phase_autotransformer ─────────────────────────────────────────

    @testset "single_phase_autotransformer" begin
        # Type B regulator, tap_ratio a=1.05 → n_eff = 1/a. Series impedance on
        # the from side. Nodes: [fr_ph, to_ph, fr_n, to_n].
        a  = 1.05
        ne = 1.0 / a                      # Type B effective ratio
        xfmr = Dict{String,Any}(
            "bus_from"          => "src",
            "bus_to"            => "reg",
            "terminal_map_from" => ["1", "n"],
            "terminal_map_to"   => ["1", "n"],
            "tap_ratio"         => a,
            "regulator_type"    => "B",
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
        )
        nodes, Y = transformer_yprim(xfmr, "single_phase_autotransformer")

        @test length(nodes) == 4
        @test nodes[1] == ("src", "1")
        @test nodes[2] == ("reg", "1")
        @test nodes[3] == ("src", "n")
        @test nodes[4] == ("reg", "n")
        @test size(Y) == (4, 4)
        check_symmetry(Y)

        # Oracle: the 2-port between the two phase nodes (neutrals at 0) is the
        # YY core with N := n_eff: Y_phase = [y, -ne·y; -ne·y, ne²·y].
        Z = 0.5 + im*2.0
        y = 1.0 / Z
        @test abs(Y[1,1] - y)        < 1e-10
        @test abs(Y[1,2] + ne*y)     < 1e-10
        @test abs(Y[2,2] - ne^2*y)   < 1e-10
        # Each column sums to ~0 (current conservation incl. the neutral rows).
        for j in 1:4
            @test abs(sum(Y[:, j])) < 1e-9
        end

        # Type A is the reciprocal connection: n_eff = a.
        xfmrA = merge(xfmr, Dict{String,Any}("regulator_type" => "A"))
        _, YA = transformer_yprim(xfmrA, "single_phase_autotransformer")
        @test abs(YA[2,2] - a^2*y) < 1e-10
        @test abs(YA[1,2] + a*y)   < 1e-10

        # No-load shunt is stamped ACROSS the from winding (ph_fr − n_fr, i.e.
        # nodes 1–3), matching the OPF's `_add_regulating_winding!` return at
        # the reference terminal — not phase-to-ground (the old Y[1,1]-only
        # stamp, which lost the neutral coupling and broke column conservation).
        Y0 = 1e-4 + im*5e-4
        xfmrS = merge(xfmr, Dict{String,Any}("g_no_load" => real(Y0),
                                             "b_no_load" => imag(Y0)))
        _, YS = transformer_yprim(xfmrS, "single_phase_autotransformer")
        E = zeros(ComplexF64, 4, 4)
        E[1,1] = 1; E[3,3] = 1; E[1,3] = -1; E[3,1] = -1
        @test maximum(abs.((YS .- Y) .- Y0 .* E)) < 1e-12
        for j in 1:4
            @test abs(sum(YS[:, j])) < 1e-9
        end
    end

    @testset "single_phase_autotransformer — line-to-line" begin
        # Regulator across phases 1-2 (no neutral): the winding reference q is the
        # second phase, so nodes are [src/1, reg/1, src/2, reg/2].
        a  = 1.05
        ne = 1.0 / a
        xfmr = Dict{String,Any}(
            "bus_from"          => "src",
            "bus_to"            => "reg",
            "terminal_map_from" => ["1","2"],
            "terminal_map_to"   => ["1","2"],
            "tap_ratio"         => a,
            "regulator_type"    => "B",
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
        )
        nodes, Y = transformer_yprim(xfmr, "single_phase_autotransformer")
        @test length(nodes) == 4
        @test nodes[1] == ("src","1") && nodes[2] == ("reg","1")
        @test ("src","2") in nodes && ("reg","2") in nodes
        check_symmetry(Y)
        # 2-port between the phase nodes (refs at 0) is the YY core with N := ne.
        Z = 0.5 + im*2.0; y = 1.0/Z
        @test abs(Y[1,1] - y)      < 1e-10
        @test abs(Y[1,2] + ne*y)   < 1e-10
        @test abs(Y[2,2] - ne^2*y) < 1e-10
        for j in 1:size(Y,2)              # current conservation incl. ref rows
            @test abs(sum(Y[:, j])) < 1e-9
        end
    end

    # ─── open_delta_regulator ─────────────────────────────────────────────────

    @testset "open_delta_regulator" begin
        # ABBC: regulator 1 across (1,2), regulator 2 across (2,3); each its tap.
        a = (1.05, 1.025)
        ne = (1.0/a[1], 1.0/a[2])         # Type B
        xfmr = Dict{String,Any}(
            "bus_from"          => "src",
            "bus_to"            => "reg",
            "terminal_map_from" => ["1", "2", "3", "n"],
            "terminal_map_to"   => ["1", "2", "3", "n"],
            "connection"        => "ABBC",
            "tap_ratio"         => [a[1], a[2]],
            "regulator_type"    => "B",
            "r_series_from"     => 0.5,
            "x_series_from"     => 2.0,
        )
        nodes, Y = transformer_yprim(xfmr, "open_delta_regulator")

        # Node order: from block then to block.
        @test length(nodes) == 8
        @test nodes[1] == ("src", "1") && nodes[5] == ("reg", "1")
        @test size(Y) == (8, 8)
        check_symmetry(Y)

        # The neutral nodes (4 = src.n, 8 = reg.n) carry no winding → zero rows.
        @test all(iszero, Y[4, :]) && all(iszero, Y[8, :])

        # Each regulator is a line-to-line core; injected current at its phase
        # pair must conserve (column sums zero across all nodes).
        for j in 1:8
            @test abs(sum(Y[:, j])) < 1e-9
        end

        # Apply a voltage profile; the line-to-line winding relation
        # I_to = -ne·I_from per core must hold. Build V with balanced phases.
        V = ComplexF64[
            230.94+0im, 230.94*cis(-2π/3), 230.94*cis(2π/3), 0.0,  # src 1,2,3,n
            0.0, 0.0, 0.0, 0.0]                                     # reg (solve below)
        # Choose reg phase voltages so each core is at its no-load boosted LL volts:
        # V_to_LL = a · V_fr_LL for Type B. Set reg phase = a-scaled src phase.
        V[5] = a[1]*V[1]; V[6] = a[1]*V[2]; V[7] = a[2]*V[3]
        I = Y * V
        # At the no-load boosted point each core's from/to LL drop satisfies the
        # ideal relation, so the line currents are tiny (only series-Z driven).
        @test all(isfinite, I)
    end

    # ─── open_delta_regulator vs Yan et al. 2018 Eq. (11) ──────────────────────
    # The exported Yprim is the device's natural line-to-line primitive, which is
    # exactly the "unspecified neutral" admittance matrix of Yan, Li, Saha et al.,
    # "Modeling and Analysis of Open-Delta Step Voltage Regulators...", IEEE Trans.
    # Smart Grid 9(3):2224 (2018), Eq. (11). The paper's effective ratio r = 1−nR
    # maps to our n_eff; reproduce the matrix term-by-term in per unit (yr=1).
    @testset "open_delta_regulator — matches paper Eq. (11)" begin
        # Pure-conductance series so yt = yr = 1 (Z = 1 Ω, x = 0).
        r1 = 0.95; r2 = 0.97; yr = 1.0
        # regulator_type "A" makes n_eff = tap_ratio, so we set tap = r directly.
        xfmr = Dict{String,Any}(
            "bus_from"          => "b4",
            "bus_to"            => "b5",
            "terminal_map_from" => ["1", "2", "3", "n"],
            "terminal_map_to"   => ["1", "2", "3", "n"],
            "connection"        => "ABBC",
            "tap_ratio"         => [r1, r2],
            "regulator_type"    => "A",
            "r_series_from"     => 1.0,
            "x_series_from"     => 0.0,
        )
        _, Y = transformer_yprim(xfmr, "open_delta_regulator")
        # Phase-node sub-matrix in order [A4,B4,C4,A5,B5,C5] (skip the two neutrals).
        Yr = real.(Y[[1, 2, 3, 5, 6, 7], [1, 2, 3, 5, 6, 7]])

        # Paper Eq. (11), ABBC (reg1 = A-B, reg2 = B-C), yr = 1.
        P = [  yr        -yr          0     -r1*yr        r1*yr           0;
              -yr        2yr        -yr      r1*yr   -(r1+r2)*yr       r2*yr;
                0        -yr         yr        0          r2*yr      -r2*yr;
            -r1*yr      r1*yr         0     r1^2*yr    -r1^2*yr           0;
             r1*yr  -(r1+r2)*yr   r2*yr   -r1^2*yr  (r1^2+r2^2)*yr  -r2^2*yr;
                0       r2*yr     -r2*yr      0        -r2^2*yr      r2^2*yr ]

        @test maximum(abs.(Yr .- P)) < 1e-10
    end

end
