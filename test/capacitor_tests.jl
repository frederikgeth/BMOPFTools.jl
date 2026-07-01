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
