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
            @test !haskey(snap_free["transformer"]["delta_wye"][tid], "tap_min")
            @test !haskey(snap_free["transformer"]["delta_wye"][tid], "tap_max")
            @test net["transformer"]["delta_wye"][tid]["tap_min"] == 0.9
            @test tid in snap_free["_meta"]["projection"]["free_taps"]
        end

        # Regulator ratios must remain pinned in a subsequent power-flow solve.
        @testset "Projected regulator taps stay fixed in power flow" begin
            for kind in ("single_phase_autotransformer", "open_delta_regulator"),
                free_arms in ((true,true), (true,false), (false,true)), per_unit in (false,true)
                kind == "single_phase_autotransformer" && free_arms != (true,true) && continue
                bank = kind == "open_delta_regulator"
                phases = bank ? ["1","2","3"] : ["1"]
                terminals = vcat(phases,"n")
                xf = Dict{String,Any}("bus_from"=>"src", "bus_to"=>"reg",
                    "terminal_map_from"=>copy(terminals), "terminal_map_to"=>copy(terminals),
                    "regulator_type"=>"B", "s_rating"=>250000.,
                    "r_series_from"=>.35, "x_series_from"=>.15,
                    "r_series_to"=>.05, "x_series_to"=>.02)
                if bank
                    xf["connection"] = "ABBC"
                    xf["tap_ratio"] = [1.025,.99]
                    xf["tap_ratio_min"] = [free_arms[k] ? .97 : xf["tap_ratio"][k] for k in 1:2]
                    xf["tap_ratio_max"] = [free_arms[k] ? 1.06 : xf["tap_ratio"][k] for k in 1:2]
                else
                    xf["tap_ratio"] = 1.025
                    xf["tap_ratio_min"] = .97
                    xf["tap_ratio_max"] = 1.06
                end
                net = Dict{String,Any}(
                    "bus"=>Dict{String,Any}(b=>Dict{String,Any}("terminal_names"=>copy(terminals),
                        "perfectly_grounded_terminals"=>["n"]) for b in ("src","reg")),
                    "voltage_source"=>Dict{String,Any}("src"=>Dict{String,Any}("bus"=>"src",
                        "terminal_map"=>phases, "v_magnitude"=>fill(2400.,length(phases)),
                        "v_angle"=>[.13-2pi*(k-1)/3 for k in eachindex(phases)], "cost"=>fill(.2,length(phases)))),
                    "transformer"=>Dict{String,Any}(kind=>Dict{String,Any}("tx"=>xf)),
                    "load"=>Dict{String,Any}("ld"=>Dict{String,Any}("bus"=>"reg", "terminal_map"=>terminals,
                        "configuration"=>bank ? "WYE" : "SINGLE_PHASE",
                        "p_nom"=>bank ? [30000.,20000.,25000.] : [50000.],
                        "q_nom"=>bank ? [6000.,4000.,5000.] : [12000.])))
                before = deepcopy(net)
                result = solve_opf(net; optimizer=opt, per_unit)
                @test result["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                snapshot = project_solution(net,result)
                pinned = snapshot["transformer"][kind]["tx"]
                if bank
                    for k in 1:2
                        @test BMOPFTools._odr_ratio_coeff_bounds(pinned,k) === nothing
                        if !free_arms[k]
                            @test pinned["tap_ratio"][k] == xf["tap_ratio"][k]
                            @test pinned["tap_ratio_min"][k] == xf["tap_ratio_min"][k]
                            @test pinned["tap_ratio_max"][k] == xf["tap_ratio_max"][k]
                        end
                    end
                else
                    @test BMOPFTools._xfmr_ratio_coeff_bounds(kind,pinned) === nothing
                end
                @test net == before
                @test "tx" in snapshot["_meta"]["projection"]["free_taps"]
                pf = solve_pf(snapshot; optimizer=opt, per_unit)
                @test pf["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                for (bus, values) in result["bus"], (terminal, v) in values
                    @test pf["bus"][bus][terminal]["vr"] ≈ v["vr"] atol=1e-4
                    @test pf["bus"][bus][terminal]["vi"] ≈ v["vi"] atol=1e-4
                end
            end
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

            # Transformer snapshot: projection, BMOPF re-solve, and the OpenDSS
            # export oracle agree after the tap ratio is materialised.
            @testset "freed-tap snapshot (A≈B≈C)" begin
                net = from_dss(joinpath(_PROJ_DIR, "pf_dy_xfmr_tap.dss"))
                tid = first(keys(net["transformer"]["delta_wye"]))
                net["transformer"]["delta_wye"][tid]["tap_min"] = 0.9
                net["transformer"]["delta_wye"][tid]["tap_max"] = 1.1
                result = solve_opf(net; optimizer = opt)
                rep = run_projection_case("pf_dy_xfmr_tap", net, result;
                                          optimizer = opt, has_ods = true,
                                          atol = _PROJ_ATOL, rtol = _PROJ_RTOL)
                @test pf_ok(rep.ab)
                @test pf_ok(rep.ac)
            end
        else
            @test_skip "A≈C oracle requires OpenDSSDirect"
        end
    end
end
