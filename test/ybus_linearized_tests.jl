# Tests for the linearized nodal admittance matrix (ybus_linearized).
#
#   1. analytic folding checks — always run;
#   2. OpenDSS power-flow-residual cross-check (gated on OpenDSSDirect): at
#      OpenDSS's converged voltage v0, the fixed-point relation
#      `Y_lin·v0 = i_comp(v0)` must hold (net current ≈ 0 at every non-source
#      node) for BOTH fold modes — the strongest end-to-end validation of the
#      passive Y *and* the load folding against an independent power flow.

@testset "ybus_linearized" begin
    using LinearAlgebra, SparseArrays

    _TN = Dict("a" => "1", "b" => "2", "c" => "3", "n" => "4")

    # One WYE load, phase a to a grounded neutral, on a single bus.
    _wye_net(; model, extra=Dict{String,Any}()) = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "b" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                    "perfectly_grounded_terminals" => ["n"]),
        ),
        "load" => Dict{String,Any}(
            "ld" => merge(Dict{String,Any}(
                "bus" => "b", "terminal_map" => ["a", "n"],
                "configuration" => "WYE", "model" => model,
                "p_nom" => [15_000.0], "q_nom" => [5_000.0]), extra),
        ),
    )

    # ── layer 1: analytic ──────────────────────────────────────────────────────

    @testset "constant-impedance load folds to a shunt admittance" begin
        V = 240.0
        lin = ybus_linearized(_wye_net(model="constant_impedance",
                                       extra=Dict{String,Any}("v_nom" => [V])))
        ia = lin.index[("b", "a")]
        # y_z = (P − jQ)/V²  (phase-to-ground: stamped on the a-diagonal)
        @test Matrix(lin.Y)[ia, ia] ≈ (15_000.0 - 5_000.0im) / V^2
        # constant-Z has no compensation current
        @test all(iszero, lin.i_comp(zeros(ComplexF64, length(lin.nodes))))
    end

    @testset "constant-power load: no fold, current in i_comp" begin
        lin = ybus_linearized(_wye_net(model="constant_power"))
        ia = lin.index[("b", "a")]
        @test nnz(lin.Y) == 0                     # nothing folded into Y
        # i_comp at a test voltage = −conj(S)/conj(V)  (injection = −drawn)
        Vv = zeros(ComplexF64, length(lin.nodes))
        Vv[ia] = 230.0 + 10.0im
        S = 15_000.0 + 5_000.0im
        @test lin.i_comp(Vv)[ia] ≈ -conj(S) / conj(Vv[ia])
    end

    @testset "ZIP split: Z-part folds, I+P-part in i_comp" begin
        V = 240.0
        # αz=0.5 αi=0.2 αp=0.3 ; βz=0.4 βi=0.3 βp=0.3
        extra = Dict{String,Any}("v_nom" => [V],
            "alpha_z" => [0.5], "alpha_i" => [0.2], "alpha_p" => [0.3],
            "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3])
        lin = ybus_linearized(_wye_net(model="zip", extra=extra))
        ia = lin.index[("b", "a")]
        P = 15_000.0; Q = 5_000.0
        # y_z = (P·αz − j·Q·βz)/V²
        @test Matrix(lin.Y)[ia, ia] ≈ (P * 0.5 - im * Q * 0.4) / V^2
        # i_comp at V0: S_nz = (P·αi·u + P·αp) + j(Q·βi·u + Q·βp), u = |V|/Vnom
        Vv = zeros(ComplexF64, length(lin.nodes)); Vv[ia] = V + 0im
        u = 1.0
        Snz = (P*0.2*u + P*0.3) + im*(Q*0.3*u + Q*0.3)
        @test lin.i_comp(Vv)[ia] ≈ -conj(Snz) / conj(Vv[ia])
    end

    @testset "exponential (non-integer γ) lives entirely in i_comp" begin
        V = 240.0
        extra = Dict{String,Any}("v_nom" => [V], "gamma_p" => [1.4], "gamma_q" => [1.4])
        lin = ybus_linearized(_wye_net(model="exponential", extra=extra))
        ia = lin.index[("b", "a")]
        @test nnz(lin.Y) == 0                     # γ≠0,2 ⇒ no constant-Z part
        Vv = zeros(ComplexF64, length(lin.nodes)); Vv[ia] = 216.0 + 0im
        u = abs(Vv[ia]) / V
        S = 15_000.0 * u^1.4 + im * 5_000.0 * u^1.4
        @test lin.i_comp(Vv)[ia] ≈ -conj(S) / conj(Vv[ia])
    end

    @testset "fold=:all folds the whole load at v0; i_comp ≡ 0" begin
        V = 230.0 + 0im
        v0 = Dict((("b", "a")) => V)
        lin = ybus_linearized(_wye_net(model="constant_power"); fold=:all, v0=v0)
        ia = lin.index[("b", "a")]
        # equivalent admittance conj(S)/|V|² reproduces S at v0
        @test Matrix(lin.Y)[ia, ia] ≈ conj(15_000.0 + 5_000.0im) / abs(V)^2
        @test all(iszero, lin.i_comp(zeros(ComplexF64, length(lin.nodes))))
        @test lin.i0 !== nothing && all(iszero, lin.i0)
    end

    @testset "argument validation" begin
        @test_throws ArgumentError ybus_linearized(_wye_net(model="constant_power"); fold=:bogus)
        @test_throws ArgumentError ybus_linearized(_wye_net(model="constant_power"); fold=:all)
        lin = ybus_linearized(_wye_net(model="constant_power"))
        @test_throws DimensionMismatch lin.i_comp(ComplexF64[1.0, 2.0])  # wrong length
    end

    # ── layer 2: OpenDSS power-flow residual (gated) ───────────────────────────

    @testset "power-flow residual at OpenDSS solution" begin
        if !_HAS_ODS
            @test_skip "Requires OpenDSSDirect"
        else
            # Decks from_dss imports faithfully (WYE / DELTA / SINGLE_PHASE, ZIP
            # and constant-power). pf_zip_3ph (4-wire-line import quirk) and
            # pf_exp_1ph (exponential not imported by from_dss) are excluded — a
            # from_dss limitation, not a folding one.
            function residual(deck::String, srcbus::String; atol)
                path = normpath(abspath(joinpath(@__DIR__, "data", "pf_comparison", deck)))
                OpenDSSDirect.dss("Clear")
                OpenDSSDirect.dss("Redirect \"$path\"")
                OpenDSSDirect.dss("Solve")
                names = lowercase.(OpenDSSDirect.Circuit.AllNodeNames())
                volts = OpenDSSDirect.Circuit.AllBusVolts()
                odsv = Dict(n => v for (n, v) in zip(names, volts))
                net = from_dss(path)
                v0 = Dict{Tuple{String,String},ComplexF64}()
                for (bid, b) in net["bus"], t in b["terminal_names"]
                    k = "$(bid).$(get(_TN, t, t))"
                    haskey(odsv, k) && (v0[(bid, t)] = odsv[k])
                end
                for fold in (:constant_z, :all)
                    lin = ybus_linearized(net; fold=fold, v0=v0)
                    n = length(lin.nodes)
                    Vv = zeros(ComplexF64, n)
                    for (nd, i) in lin.index
                        i == 0 && continue
                        haskey(v0, nd) && (Vv[i] = v0[nd])
                    end
                    resid = lin.Y * Vv .- lin.i_comp(Vv)
                    maxr = 0.0
                    for (i, nd) in enumerate(lin.nodes)
                        nd[1] == srcbus && continue     # source injects; skip
                        maxr = max(maxr, abs(resid[i]))
                    end
                    @test maxr < atol
                end
            end
            residual("pf_zip_1ph.dss",   "src"; atol=1e-3)   # ZIP single-phase
            residual("pf_zip_delta.dss", "src"; atol=1e-3)   # ZIP delta
            residual("pf_delta_load.dss","src"; atol=1e-3)   # const-power delta
            residual("pf_1ph_line.dss",  "src"; atol=1e-3)   # const-power 1φ
            residual("pf_yd_xfmr.dss",   "hv";  atol=1e-2)   # delta loads + Yd xfmr
        end
    end
end
