# projection_tests.jl
#
# Tests for the OPF-solution → snapshot projection (`project_solution`,
# `dispatch_as_loads`) and the 3-way feasibility oracle
# (`run_projection_case`, in roundtrip_helpers.jl):
#
#   A = result["bus"]                       — the OPF-predicted state
#   B = solve_pf(project_solution(...))     — BMOPF's own determined re-solve
#   C = OpenDSS(to_dss(dispatch_as_loads))  — independent oracle
#
# A≈B is a pure-BMOPF correctness claim (projection reproduces the OPF); it runs
# whenever JuMP/Ipopt are present. A≈C / B≈C additionally exercise the PowerIO
# export and OpenDSS, and self-gate on `_HAS_ODS`.
#
# The controllable devices come from `add_ibrs` (DER placement): the raw
# pf_comparison decks import with NO generators/IBRs, so projection is exercised
# on augmented feeders — the real user flow (place DERs → solve → validate).
#
# `_HAS_ODS` / `_HAS_JUMP_IPOPT` are defined by the includer (runtests.jl).

include(joinpath(@__DIR__, "roundtrip_helpers.jl"))

const _PROJ_DIR = abspath(joinpath(@__DIR__, "data", "pf_comparison"))

# Transformer-free, export-PF-sound single-phase feeders (in roundtrip's
# RT_PF_SOUND). Augmented with a 1-φ IBR, their negative-load snapshot solves in
# OpenDSS and agrees with the OPF within the coarse PF tolerance.
const _PROJ_DER_CASES = ["pf_1ph_line", "pf_zip_1ph", "pf_exp_1ph"]

# Coarse oracle tolerance — the same atol=2 V / rtol=2 % the roundtrip PF gate
# uses. It absorbs the benign BMOPF↔OpenDSS floor (voltage-dependent load
# evaluation; OpenDSS clamping constant-power loads that PowerIO exports without
# `Vminpu/Vmaxpu`) while still catching a wrong sign / dropped injection.
const _PROJ_ATOL = 2.0
const _PROJ_RTOL = 0.02

@testset "OPF → snapshot projection" begin

    if !_HAS_JUMP_IPOPT
        @test_skip "projection tests require JuMP + Ipopt"
    else
        opt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

        # ── Unit: project_solution pins setpoints, does not mutate ────────────
        @testset "project_solution pins generation" begin
            net = from_dss(joinpath(_PROJ_DIR, "pf_1ph_line.dss"))
            net2, _ = add_ibrs(net)
            @test !isempty(get(net2, "ibr", Dict()))
            result = solve_opf(net2; optimizer = opt)

            net2_before = deepcopy(net2)
            snap = project_solution(net2, result)

            # Every pinned IBR now has p_min == p_max, q_min == q_max (the
            # solve_pf contract) at the solved dispatch.
            for (iid, inv) in snap["ibr"]
                @test inv["p_min"] == inv["p_max"]
                @test inv["q_min"] == inv["q_max"]
                r1 = result["ibr"][iid][first(keys(result["ibr"][iid]))]
                @test inv["p_min"][1] ≈ r1["pg"] atol=1e-6
                @test !haskey(inv, "control_profile")   # frozen, if it had one
            end
            @test snap["_meta"]["projection"]["ibrs"] == collect(keys(net2["ibr"]))

            # Caller's net is untouched (deep copy).
            @test net2 == net2_before
        end

        # ── Unit: infeasible result cannot be projected ───────────────────────
        @testset "project_solution rejects infeasible" begin
            net = from_dss(joinpath(_PROJ_DIR, "pf_1ph_line.dss"))
            bad = Dict{String,Any}("feasible" => false, "termination_status" => "INFEASIBLE")
            @test_throws ArgumentError project_solution(net, bad)
        end

        # ── Unit: free tap projected, fixed tap untouched ─────────────────────
        @testset "project_solution writes free tap" begin
            net = from_dss(joinpath(_PROJ_DIR, "pf_dy_xfmr_tap.dss"))
            tid = first(keys(net["transformer"]["delta_wye"]))
            fixed_tap = net["transformer"]["delta_wye"][tid]["tap"]

            # Fixed tap (no bounds) → not reported → net tap left as-is.
            r_fixed = solve_opf(net; optimizer = opt)
            snap_fixed = project_solution(net, r_fixed)
            @test snap_fixed["transformer"]["delta_wye"][tid]["tap"] == fixed_tap

            # Free the tap → OPF reports it → projection writes the solved value.
            net["transformer"]["delta_wye"][tid]["tap_min"] = 0.9
            net["transformer"]["delta_wye"][tid]["tap_max"] = 1.1
            r_free = solve_opf(net; optimizer = opt)
            solved_tap = get(r_free["transformer"][tid], "tap", nothing)
            @test solved_tap !== nothing
            snap_free = project_solution(net, r_free)
            @test snap_free["transformer"]["delta_wye"][tid]["tap"] ≈ solved_tap
            @test tid in snap_free["_meta"]["projection"]["free_taps"]
        end

        # ── Unit: dispatch_as_loads converts non-slack generation ─────────────
        @testset "dispatch_as_loads → negative loads" begin
            net = from_dss(joinpath(_PROJ_DIR, "pf_1ph_line.dss"))
            net2, _ = add_ibrs(net)
            result = solve_opf(net2; optimizer = opt)
            snap = project_solution(net2, result)
            iid = first(keys(snap["ibr"]))
            pinned_p = snap["ibr"][iid]["p_min"][1]

            loaded = dispatch_as_loads(snap)
            @test !haskey(loaded, "ibr") || isempty(loaded["ibr"])
            @test haskey(loaded["load"], "inj_$(iid)")
            inj = loaded["load"]["inj_$(iid)"]
            @test inj["model"] == "constant_power"
            @test inj["p_nom"][1] ≈ -pinned_p           # negative load = injection
            @test iid in loaded["_meta"]["dispatch_as_loads"]["converted"]
        end

        # ── A≈B: solve_pf on the projected net reproduces the OPF (tight) ─────
        @testset "A≈B self-consistency — $case" for case in _PROJ_DER_CASES
            net = from_dss(joinpath(_PROJ_DIR, "$case.dss"))
            net2, _ = add_ibrs(net)
            result = solve_opf(net2; optimizer = opt)
            rep = run_projection_case(case, net2, result;
                                      optimizer = opt, has_ods = false,
                                      atol = _PROJ_ATOL, rtol = _PROJ_RTOL)
            @test rep.projected_ok
            @test rep.n_pinned ≥ 1
            @test isempty(rep.errors)
            @test pf_ok(rep.ab)
            @test rep.ab.max_dV < 1e-2          # essentially exact
        end

        # ── A≈B≈C: independent OpenDSS oracle (gated) ─────────────────────────
        if _HAS_ODS
            @testset "A≈B≈C oracle — $case" for case in _PROJ_DER_CASES
                net = from_dss(joinpath(_PROJ_DIR, "$case.dss"))
                net2, _ = add_ibrs(net)
                result = solve_opf(net2; optimizer = opt)
                rep = run_projection_case(case, net2, result;
                                          optimizer = opt, has_ods = true,
                                          atol = _PROJ_ATOL, rtol = _PROJ_RTOL)
                @test isempty(rep.errors)
                @test pf_ok(rep.ab)
                @test pf_ok(rep.ac)             # OpenDSS agrees with the OPF
                @test pf_ok(rep.bc)
            end

            # Transformer snapshot: projection + A≈B work, but PowerIO exports
            # `kvs=(NaN,NaN)` for transformers, so the OpenDSS leg cannot solve.
            # A≈B is asserted; A≈C is a documented PowerIO blocker (@test_broken
            # flips to a pass once the kv export is fixed).
            @testset "freed-tap snapshot (A≈B ok, A≈C blocked by kvs=NaN)" begin
                net = from_dss(joinpath(_PROJ_DIR, "pf_dy_xfmr_tap.dss"))
                tid = first(keys(net["transformer"]["delta_wye"]))
                net["transformer"]["delta_wye"][tid]["tap_min"] = 0.9
                net["transformer"]["delta_wye"][tid]["tap_max"] = 1.1
                result = solve_opf(net; optimizer = opt)
                rep = run_projection_case("pf_dy_xfmr_tap", net, result;
                                          optimizer = opt, has_ods = true,
                                          atol = _PROJ_ATOL, rtol = _PROJ_RTOL)
                @test pf_ok(rep.ab)
                @test_broken pf_ok(rep.ac)
            end
        else
            @test_skip "A≈C oracle requires OpenDSSDirect"
        end
    end
end
