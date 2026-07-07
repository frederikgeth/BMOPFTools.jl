# Fixed capacitor-bank tests.
#
# Non-solver tests (nameplate→B, susceptance matrix, validation) always run.
# The OPF equivalence and OpenDSS-parity blocks live in
# powerflow_comparison_tests.jl (gated on JuMP/Ipopt/OpenDSSDirect).

const BC = BMOPFTools

@testset "capacitor — nameplate → susceptance & B-matrix" begin
    vpn = 14400.0
    # WYE: B per phase = q_rated / v_nom².
    wye = Dict{String,Any}("bus"=>"b", "terminal_map"=>["a","b","c","n"],
        "configuration"=>"WYE", "q_rated"=>[6.0e5, 6.0e5, 6.0e5], "v_nom"=>vpn)
    b = 6.0e5 / vpn^2
    @test BC._cap_susceptances(wye) ≈ [b, b, b]
    tm, B = BC._cap_bmatrix(wye)
    @test tm == ["a","b","c","n"]
    @test maximum(abs.(B .- transpose(B))) < 1e-12          # symmetric
    # phase a (idx 1) ↔ neutral (idx 4) stamp: B[1,1]=b, B[1,4]=-b, B[4,4]=Σb
    @test B[1,1] ≈ b && B[1,4] ≈ -b && B[4,1] ≈ -b
    @test B[4,4] ≈ 3b                                        # neutral sees all phases
    @test all(iszero, [B[1,2], B[1,3], B[2,3]])             # phases don't couple (wye)

    # SINGLE_PHASE: across the two terminals.
    sp = Dict{String,Any}("bus"=>"b", "terminal_map"=>["a","n"],
        "configuration"=>"SINGLE_PHASE", "q_rated"=>[6.0e5], "v_nom"=>vpn)
    _, Bsp = BC._cap_bmatrix(sp)
    @test Bsp ≈ [b -b; -b b]

    # DELTA: across each phase pair, line-to-line v_nom.
    vll = 24942.0
    bd  = 3.0e5 / vll^2
    dl = Dict{String,Any}("bus"=>"b", "terminal_map"=>["a","b","c"],
        "configuration"=>"DELTA", "q_rated"=>[3.0e5, 3.0e5, 3.0e5], "v_nom"=>vll)
    _, Bd = BC._cap_bmatrix(dl)
    @test maximum(abs.(Bd .- transpose(Bd))) < 1e-12
    @test Bd[1,1] ≈ 2bd                                      # phase a in pairs (a,b)&(c,a)
    @test Bd[1,2] ≈ -bd && Bd[2,3] ≈ -bd && Bd[1,3] ≈ -bd
end

@testset "capacitor — validation (completeness / spec)" begin
    good = Dict{String,Any}("bus"=>"b", "terminal_map"=>["a","b","c","n"],
        "configuration"=>"WYE", "q_rated"=>[6.0e5,6.0e5,6.0e5], "v_nom"=>14400.0)
    net  = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>good))
    f = Finding[]; completeness_check(net, f); spec_conformance_check(net, f)
    @test isempty([x for x in f if x.severity == ERROR])

    # missing v_nom → completeness error
    b1 = deepcopy(good); delete!(b1, "v_nom")
    n1 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b1))
    f1 = Finding[]; completeness_check(n1, f1)
    @test any(x -> x.code == "E.COMP.MISSING_REQUIRED", f1)

    # wrong q_rated length for WYE (3 phases ⇒ expect 3) → spec warning
    b2 = deepcopy(good); b2["q_rated"] = [6.0e5, 6.0e5]
    n2 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b2))
    f2 = Finding[]; spec_conformance_check(n2, f2)
    @test any(x -> x.code == "W.SPEC.CAP_QRATED_LENGTH", f2)

    # bad configuration → spec warning
    b3 = deepcopy(good); b3["configuration"] = "STAR"
    n3 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b3))
    f3 = Finding[]; spec_conformance_check(n3, f3)
    @test any(x -> x.code == "W.SPEC.BAD_CONFIG", f3)

    # non-positive v_nom → spec error
    b4 = deepcopy(good); b4["v_nom"] = 0.0
    n4 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b4))
    f4 = Finding[]; spec_conformance_check(n4, f4)
    @test any(x -> x.code == "E.SPEC.CAP_VRATED", f4)

    # negative q_rated → blocked (a reactor, not a capacitor)
    b5 = deepcopy(good); b5["q_rated"] = [6.0e5, -6.0e5, 6.0e5]
    n5 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b5))
    f5 = Finding[]; spec_conformance_check(n5, f5)
    @test any(x -> x.code == "E.SPEC.CAP_NEGATIVE_Q", f5)

    # WYE with arity 4 but no resolvable neutral → silently inert ⇒ warning
    b6 = deepcopy(good); b6["terminal_map"] = ["a","b","c","g"]   # 'g' is not a neutral
    n6 = Dict{String,Any}("capacitor"=>Dict{String,Any}("c1"=>b6))
    f6 = Finding[]; spec_conformance_check(n6, f6)
    @test any(x -> x.code == "W.SPEC.CAP_WYE_NO_NEUTRAL", f6)
    # a proper WYE (…,"n") does NOT warn
    f6b = Finding[]; spec_conformance_check(net, f6b)
    @test !any(x -> x.code == "W.SPEC.CAP_WYE_NO_NEUTRAL", f6b)

    # inventory counts it and totals q_rated
    rep = analyze(net)
    @test rep.results[:inventory]["capacitor"]["total"] == 1
    @test rep.results[:inventory]["capacitor"]["q_rated_total"] ≈ 1.8e6
end

if _HAS_JUMP_IPOPT
    @testset "capacitor — solved result sign & per-unit round-trip (#272/#273)" begin
        vpn = 230.0
        q0  = 1.0e3   # var per phase
        net = Dict{String,Any}("name" => "cap1",
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c","n"],
                "v_magnitude" => [vpn, vpn, vpn, 0.0],
                "v_angle" => [0.0, -2.0943951, 2.0943951, 0.0])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.01, "R_series_2_2" => 0.01, "R_series_3_3" => 0.01,
                "R_series_4_4" => 0.01)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a","b","c","n"],
                "terminal_map_to"   => ["a","b","c","n"],
                "linecode" => "lc", "length" => 100.0)),
            "load" => Dict{String,Any}("ld" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a","b","c","n"],
                "configuration" => "WYE", "model" => "constant_power",
                "p_nom" => [500.0,500.0,500.0], "q_nom" => [0.0,0.0,0.0])),
            "capacitor" => Dict{String,Any}("c1" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a","b","c","n"],
                "configuration" => "WYE",
                "q_rated" => [q0, q0, q0], "v_nom" => vpn)))

        res = solve_pf(net; optimizer = Ipopt.Optimizer, per_unit = true)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        # (#272) A capacitor DELIVERS reactive power: reported q > 0, and equals
        # +B·Σ|V|² recomputed from the solved SI voltages (the physical sign).
        Bph = q0 / vpn^2
        vsq = 0.0
        for ph in ("a","b","c")
            vr = res["bus"]["b1"][ph]["vr"]; vi = res["bus"]["b1"][ph]["vi"]
            vsq += vr^2 + vi^2
        end
        q_expected = Bph * vsq
        @test res["capacitor"]["c1"]["q"] > 0
        @test isapprox(res["capacitor"]["c1"]["q"], q_expected; rtol = 1e-3)

        # (#273) Currents are reported in SI amps (≈ B·|V| ≈ 4.3 A), not p.u.
        va  = abs(res["bus"]["b1"]["a"]["vr"] + im * res["bus"]["b1"]["a"]["vi"])
        cma = res["capacitor"]["c1"]["terminals"]["a"]["cm"]
        @test cma > 1.0
        @test isapprox(cma, Bph * va; rtol = 1e-3)

        # (#273) The per-unit path (default) must round-trip to the same SI q and
        # current as a native-SI solve — the capacitor block was missing from
        # _from_per_unit, so q was off by s_base and the current by i_base.
        res_si = solve_pf(net; optimizer = Ipopt.Optimizer, per_unit = false)
        @test isapprox(res["capacitor"]["c1"]["q"],
                       res_si["capacitor"]["c1"]["q"]; rtol = 1e-4)
        @test isapprox(cma, res_si["capacitor"]["c1"]["terminals"]["a"]["cm"]; rtol = 1e-4)

        # (#273) The line-loss `s_through` (VA) must also round-trip through the
        # per-unit path — it was omitted from the loss rescale, leaving it off
        # by s_base while p_loss/q_loss were correct.
        st_pu = res["line"]["l1"]["loss"]["s_through"]
        @test st_pu > 1.0   # SI VA, not p.u.
        @test isapprox(st_pu, res_si["line"]["l1"]["loss"]["s_through"]; rtol = 1e-4)
    end
end
