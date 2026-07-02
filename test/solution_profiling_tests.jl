# Tests for solution_check / profile_solution / render_solution.
#
# All tests build synthetic network + result dicts — no solver required.
# The helpers _net() and _result() return a minimal clean 3-phase 4-wire
# single-line feeder that produces zero findings beyond the INFO summaries.
# Individual testsets mutate copies to provoke specific findings.

# ── Minimal fixture helpers ───────────────────────────────────────────────────

function _base_net()
    Dict{String,Any}(
        "name" => "test_net",
        "bus" => Dict{String,Any}(
            "sourcebus" => Dict{String,Any}(
                "terminal_names" => ["a","b","c","n"],
                "perfectly_grounded_terminals" => ["n"],
            ),
            "b1" => Dict{String,Any}(
                "terminal_names" => ["a","b","c","n"],
                "v_min" => [200.0, 200.0, 200.0],
                "v_max" => [260.0, 260.0, 260.0],
            ),
        ),
        "voltage_source" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "bus" => "sourcebus",
                "terminal_map" => ["a","b","c","n"],
                "vm" => [230.0, 230.0, 230.0, 0.0],
                "va" => [0.0, -2.094, 2.094, 0.0],
            ),
        ),
        "linecode" => Dict{String,Any}(
            "lc1" => Dict{String,Any}(
                "R_series_1_1" => 0.1,
                "R_series_2_2" => 0.1,
                "R_series_3_3" => 0.1,
                "R_series_4_4" => 0.05,
                "i_max" => [200.0, 200.0, 200.0, 200.0],
            ),
        ),
        "line" => Dict{String,Any}(
            "l1" => Dict{String,Any}(
                "bus_from" => "sourcebus",
                "bus_to"   => "b1",
                "length"   => 100.0,
                "linecode" => "lc1",
                "terminal_map_from" => ["a","b","c","n"],
                "terminal_map_to"   => ["a","b","c","n"],
            ),
        ),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "b1",
                "terminal_map"  => ["a","b","c","n"],
                "configuration" => "WYE",
                "p_nom"         => [1000.0, 1000.0, 1000.0],
                "q_nom"         => [100.0,  100.0,  100.0],
            ),
        ),
        "generator" => Dict{String,Any}(
            "g1" => Dict{String,Any}(
                "bus"           => "sourcebus",
                "terminal_map"  => ["a","b","c","n"],
                "configuration" => "WYE",
                "p_min"         => [0.0, 0.0, 0.0],
                "p_max"         => [2000.0, 2000.0, 2000.0],
                "q_min"         => [-500.0, -500.0, -500.0],
                "q_max"         => [500.0,  500.0,  500.0],
            ),
        ),
    )
end

function _base_result(; vm=230.0)
    vr = vm
    Dict{String,Any}(
        "termination_status" => "LOCALLY_SOLVED",
        "objective" => 0.0,
        "solve_time" => 0.1,
        "bus" => Dict{String,Any}(
            "sourcebus" => Dict{String,Any}(
                "a" => Dict("vr"=>vr,  "vi"=>0.0,   "vm"=>vm,  "va"=>0.0),
                "b" => Dict("vr"=>-vr/2, "vi"=>-vr*sqrt(3)/2, "vm"=>vm, "va"=>-2.094),
                "c" => Dict("vr"=>-vr/2, "vi"=> vr*sqrt(3)/2, "vm"=>vm, "va"=> 2.094),
                "n" => Dict("vr"=>0.0, "vi"=>0.0, "vm"=>0.0, "va"=>0.0),
            ),
            "b1" => Dict{String,Any}(
                "a" => Dict("vr"=>vr,  "vi"=>0.0,   "vm"=>vm,  "va"=>0.0),
                "b" => Dict("vr"=>-vr/2, "vi"=>-vr*sqrt(3)/2, "vm"=>vm, "va"=>-2.094),
                "c" => Dict("vr"=>-vr/2, "vi"=> vr*sqrt(3)/2, "vm"=>vm, "va"=> 2.094),
                "n" => Dict("vr"=>0.0, "vi"=>0.0, "vm"=>0.0, "va"=>0.0),
            ),
        ),
        "line" => Dict{String,Any}(
            "l1" => Dict{String,Any}(
                "a" => Dict("cr_fr"=>5.0,"ci_fr"=>0.0,"cr_to"=>-5.0,"ci_to"=>0.0,"cm_fr"=>5.0,"cm_to"=>5.0),
                "b" => Dict("cr_fr"=>5.0,"ci_fr"=>0.0,"cr_to"=>-5.0,"ci_to"=>0.0,"cm_fr"=>5.0,"cm_to"=>5.0),
                "c" => Dict("cr_fr"=>5.0,"ci_fr"=>0.0,"cr_to"=>-5.0,"ci_to"=>0.0,"cm_fr"=>5.0,"cm_to"=>5.0),
                "n" => Dict("cr_fr"=>0.0,"ci_fr"=>0.0,"cr_to"=>0.0, "ci_to"=>0.0,"cm_fr"=>0.0,"cm_to"=>0.0),
            ),
        ),
        "switch"  => Dict{String,Any}(),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "a" => Dict("crd"=>4.35,"cid"=>0.0,"pd"=>1000.0,"qd"=>100.0),
                "b" => Dict("crd"=>4.35,"cid"=>0.0,"pd"=>1000.0,"qd"=>100.0),
                "c" => Dict("crd"=>4.35,"cid"=>0.0,"pd"=>1000.0,"qd"=>100.0),
            ),
        ),
        "generator" => Dict{String,Any}(
            "g1" => Dict{String,Any}(
                # pd=1000 W + R*len*cm² = 0.1*100*5² = 250 W line loss per phase.
                # qg = qd (100 var/phase) so the reactive balance closes (q_loss=0).
                "a" => Dict("crg"=>5.0,"cig"=>0.0,"pg"=>1250.0,"qg"=>100.0),
                "b" => Dict("crg"=>5.0,"cig"=>0.0,"pg"=>1250.0,"qg"=>100.0),
                "c" => Dict("crg"=>5.0,"cig"=>0.0,"pg"=>1250.0,"qg"=>100.0),
            ),
        ),
        "transformer" => Dict{String,Any}(),
        # Exact element losses (terminal-power identity). The checker reads these
        # directly; here the 3×250 W line copper loss with no reactive component.
        "losses" => Dict{String,Any}("p_loss" => 750.0, "q_loss" => 0.0),
    )
end

# ── Helper: extract finding codes ────────────────────────────────────────────

codes(findings) = Set(f.code for f in findings)

# ── T1: infeasible termination status ────────────────────────────────────────

@testset "SOL — infeasible status" begin
    net    = _base_net()
    result = _base_result()
    result["termination_status"] = "INFEASIBLE"

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test "E.SOL.INFEASIBLE" in codes(findings)
    @test !any(f.code == "E.SOL.VOLT_VIOLATION" for f in findings)
    @test out["feasible"] == false
    @test out["n_volt_violations"] == 0
end

# ── T2: NaN in claimed-feasible result ───────────────────────────────────────

@testset "SOL — NaN in result" begin
    net    = _base_net()
    result = _base_result()
    result["bus"]["b1"]["a"]["vm"] = NaN

    findings = Finding[]
    solution_check(net, result, findings)

    @test "E.SOL.NAN_IN_RESULT" in codes(findings)
end

# ── T3: voltage violation (vm below v_min) ────────────────────────────────────

@testset "SOL — voltage magnitude violation" begin
    net    = _base_net()
    result = _base_result(vm=180.0)   # 180 V < v_min=200

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test "E.SOL.VOLT_VIOLATION" in codes(findings)
    @test out["n_volt_violations"] > 0

    f = first(filter(f -> f.code == "E.SOL.VOLT_VIOLATION", findings))
    @test f.component_type == :bus
    @test f.detail["flavour"] == "vm"
    @test f.detail["vm"] ≈ 180.0
end

# ── T4: voltage near-active (within 1 % of v_max) ────────────────────────────

@testset "SOL — voltage near-active" begin
    net    = _base_net()
    # v_max = 260.0; put vm at 259.5 (within 1% of 260 = within 2.6 V)
    result = _base_result(vm=259.5)

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test !("E.SOL.VOLT_VIOLATION" in codes(findings))
    @test "W.SOL.VOLT_ACTIVE" in codes(findings)
    @test out["n_volt_active"] > 0
end

# ── T5: thermal violation ─────────────────────────────────────────────────────

@testset "SOL — thermal violation" begin
    net    = _base_net()
    result = _base_result()
    # i_max on lc1 is 200 A; set cm_fr to 250 A on phase a
    result["line"]["l1"]["a"]["cm_fr"] = 250.0

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test "E.SOL.THERMAL_VIOLATION" in codes(findings)
    @test out["n_thermal_violations"] > 0

    f = first(filter(f -> f.code == "E.SOL.THERMAL_VIOLATION", findings))
    @test f.component_id == "l1"
    @test f.detail["terminal"] == "a"
    @test f.detail["cm_fr"] ≈ 250.0
    @test f.detail["i_max"]  ≈ 200.0
end

# ── T6: thermal near-active ───────────────────────────────────────────────────

@testset "SOL — thermal near-active" begin
    net    = _base_net()
    result = _base_result()
    # i_max = 200; set cm_fr = 199.5 (within 1%)
    result["line"]["l1"]["a"]["cm_fr"] = 199.5

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test !("E.SOL.THERMAL_VIOLATION" in codes(findings))
    @test "W.SOL.THERMAL_ACTIVE" in codes(findings)
    @test out["n_thermal_active"] > 0
end

# ── T7: generator dispatch violation ─────────────────────────────────────────

@testset "SOL — generator violation" begin
    net    = _base_net()
    result = _base_result()
    # p_max = 2000; set pg to 2500 on phase a
    result["generator"]["g1"]["a"]["pg"] = 2500.0

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test "E.SOL.GEN_VIOLATION" in codes(findings)
    @test out["n_gen_violations"] > 0

    f = first(filter(f -> f.code == "E.SOL.GEN_VIOLATION", findings))
    @test f.component_id == "g1"
    @test f.detail["field"] == "pg"
    @test f.detail["value"] ≈ 2500.0
end

# ── T8: generator near-active ─────────────────────────────────────────────────

@testset "SOL — generator near-active" begin
    net    = _base_net()
    result = _base_result()
    # p_max = 2000; set pg = 1998 (within 1% = within 20 W)
    result["generator"]["g1"]["a"]["pg"] = 1998.0

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test !("E.SOL.GEN_VIOLATION" in codes(findings))
    @test "W.SOL.GEN_ACTIVE" in codes(findings)
    @test out["n_gen_active"] > 0
end

# ── T9: load residual ─────────────────────────────────────────────────────────

@testset "SOL — load residual" begin
    net    = _base_net()
    result = _base_result()
    # p_nom = 1000 W; set pd to 1500 W (residual = 500 W >> 1 W tolerance)
    result["load"]["ld1"]["a"]["pd"] = 1500.0

    findings = Finding[]
    solution_check(net, result, findings)

    @test "W.SOL.LOAD_RESIDUAL" in codes(findings)

    f = first(filter(f -> f.code == "W.SOL.LOAD_RESIDUAL", findings))
    @test f.component_id == "ld1"
    @test f.detail["terminal"] == "a"
    @test f.detail["p_err"] ≈ 500.0
end

# ── T10: clean solution — no errors or warnings ────────────────────────────────

@testset "SOL — clean solution" begin
    net    = _base_net()
    result = _base_result()

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test isempty(errors(findings))
    @test isempty(warnings(findings))
    @test out["n_volt_violations"]    == 0
    @test out["n_thermal_violations"] == 0
    @test out["n_gen_violations"]     == 0
    @test out["n_load_residuals"]     == 0
    # INFO summaries are always emitted for feasible solutions
    @test "I.SOL.BINDING_SUMMARY" in codes(findings)
end

# ── T11: profile_solution entry point ────────────────────────────────────────

@testset "SOL — profile_solution entry point" begin
    net    = _base_net()
    result = _base_result()

    report = profile_solution(net, result)

    @test report isa SolutionReport
    @test report.network_name == "test_net"
    @test report.result_meta["termination_status"] == "LOCALLY_SOLVED"
    @test haskey(report.results, :solution)
    @test report.results[:solution]["feasible"] == true
    @test isempty(errors(report))
end

# ── T12: render_solution produces valid Markdown ───────────────────────────────

@testset "SOL — render_solution markdown" begin
    net    = _base_net()
    result = _base_result()
    result["line"]["l1"]["a"]["cm_fr"] = 250.0   # inject a thermal violation for coverage

    report = profile_solution(net, result)
    io = IOBuffer()
    render_solution(report, io)
    md = String(take!(io))

    @test occursin("# BMOPF Solution Profile", md)
    @test occursin("## 1. Solution Summary", md)
    @test occursin("## 3. Thermal Limits", md)
    @test occursin("## 6. All Findings", md)
    @test occursin("LOCALLY_SOLVED", md)
    @test occursin("l1", md)
end

# ── T13: render_solution to file ─────────────────────────────────────────────

@testset "SOL — render_solution to file" begin
    net    = _base_net()
    result = _base_result()
    report = profile_solution(net, result)

    path = tempname() * ".md"
    render_solution(report, path)

    @test isfile(path)
    content = read(path, String)
    @test occursin("# BMOPF Solution Profile", content)
    rm(path)
end

# ── T14: voltage_zone_summary aggregates per galvanic zone ────────────────────

@testset "SOL — voltage zone summary" begin
    net    = _base_net()
    result = _base_result()   # all phases at 230 V, source base 230 V

    vz = BMOPFTools.voltage_zone_summary(net, result)
    @test vz["n_zones"] == 1   # sourcebus—b1 joined by line l1: one galvanic zone
    z = vz["zones"][1]

    @test z["n_buses"] == 2
    @test z["v_base"] ≈ 230.0
    @test z["vm_min_pu"] ≈ 1.0 atol=1e-6
    @test z["vm_max_pu"] ≈ 1.0 atol=1e-6
    @test z["status"] == "ok"
    @test z["max_neutral_shift_v"] == 0.0          # neutral excluded from the band
    @test z["max_imbalance_pct"] ≈ 0.0 atol=1e-6   # balanced
end

# ── T15: zone band reflects violation + imbalance + neutral shift ─────────────

@testset "SOL — voltage zone band flags" begin
    net    = _base_net()
    result = _base_result()
    # Drop b1 phase a below v_min (200 V) and shift its neutral.
    result["bus"]["b1"]["a"]["vm"] = 150.0
    result["bus"]["b1"]["n"]["vm"] = 5.0

    vz = BMOPFTools.voltage_zone_summary(net, result)
    z  = vz["zones"][1]
    @test z["status"] == "violation"
    @test z["vm_min_bus"] == "b1"
    @test z["vm_min_pu"] ≈ 150.0/230.0 atol=1e-6
    @test z["max_imbalance_bus"] == "b1"           # a=150 vs b,c=230
    @test z["max_imbalance_pct"] ≈ 100*(230.0-150.0)/230.0 atol=1e-6
    @test z["max_neutral_shift_v"] ≈ 5.0
    @test z["max_neutral_shift_bus"] == "b1"

    # Renderer surfaces the zone section.
    report = profile_solution(net, result)
    io = IOBuffer(); render_solution(report, io)
    md = String(take!(io))
    @test occursin("## 2. Voltage by Galvanic Zone", md)
    @test occursin("❌", md)
end

# ── T16: verbose per-bus drill-down table ─────────────────────────────────────

# ── T-BND: bound overshoot within solver tolerance is active, not a violation ─
# A solved interior-point optimum (especially via the per-unit round-trip) lands
# a few parts in 1e-6 outside an active bound. That must read as active, not as a
# violation. Guards the viol_tol relaxation in _bound_status.
@testset "SOL — tiny bound overshoot is active not violation" begin
    net    = _base_net()
    result = _base_result()
    # p_max = 2000; overshoot by 2e-6 relative (4 mW) — solver-tolerance scale
    result["generator"]["g1"]["a"]["pg"] = 2000.0 * (1 + 2e-6)

    findings = Finding[]
    out = solution_check(net, result, findings)

    @test !("E.SOL.GEN_VIOLATION" in codes(findings))
    @test "W.SOL.GEN_ACTIVE" in codes(findings)
    @test out["n_gen_violations"] == 0

    # …but a genuine overshoot (relative 1e-3) is still flagged.
    result2 = _base_result()
    result2["generator"]["g1"]["a"]["pg"] = 2000.0 * (1 + 1e-3)
    f2 = Finding[]
    solution_check(net, result2, f2)
    @test "E.SOL.GEN_VIOLATION" in codes(f2)
end

# ── T-VW: IBR active power validated against min(p_max, volt-watt cap) ─────────
# An IBR under a volt_watt profile is bounded by BOTH the available-power box
# `p_max` and the curtailment cap `p_base·f^VW(|U|)` — the validator checks the
# tighter of the two, mirroring the OPF. Exercises both binding cases.
@testset "SOL — IBR volt-watt cap and p_max (min of both)" begin
    function _net_vw(; p_max)
        net = _base_net()
        net["control_profile"] = Dict{String,Any}(
            "vw" => Dict{String,Any}(
                "volt_watt" => Dict{String,Any}(
                    "breakpoints" => [253.0, 260.0],
                    "p_limits"    => [0.2, 1.0],   # [p_low, p_high]
                    "p_ref"       => "S_MAX",
                    "p_unit"      => "VA_FRACTION",
                    "voltage_reference" => "PG_PER_PHASE",
                )))
        net["ibr"] = Dict{String,Any}(
            "pv1" => Dict{String,Any}(
                "bus" => "b1", "topology" => "SINGLE_PHASE",
                "terminal_map" => ["a","n"],
                "p_min" => [0.0], "p_max" => [p_max],
                "s_max" => [5000.0], "control_profile" => "vw"))
        net
    end
    # Drive the IBR-bus phase 'a' into the droop region (256.5 V → f^VW = 0.6),
    # so the S_MAX-referenced cap = 5000·0.6 = 3000 W.
    function _res_vw(pg)
        result = _base_result()
        result["bus"]["b1"]["a"] = Dict("vr"=>256.5,"vi"=>0.0,"vm"=>256.5,"va"=>0.0)
        result["ibr"] = Dict{String,Any}(
            "pv1" => Dict{String,Any}(
                "a" => Dict("cri"=>0.0,"cii"=>0.0,"pg"=>pg,"qg"=>0.0)))
        result
    end

    # ── Cap binds (p_max = 6000 W > cap 3000 W) ──
    f_ok = Finding[]; solution_check(_net_vw(; p_max=6000.0), _res_vw(2500.0), f_ok)
    @test !("E.SOL.IBR_VIOLATION" in codes(f_ok))           # 2500 < cap 3000 → clean
    f_cap = Finding[]; solution_check(_net_vw(; p_max=6000.0), _res_vw(3500.0), f_cap)
    @test "E.SOL.IBR_VIOLATION" in codes(f_cap)             # 3500 > cap 3000 → flagged

    # ── p_max binds (p_max = 2000 W < cap 3000 W) ──
    f_pm = Finding[]; solution_check(_net_vw(; p_max=2000.0), _res_vw(2500.0), f_pm)
    @test "E.SOL.IBR_VIOLATION" in codes(f_pm)              # 2500 > available 2000 → flagged

    # ── available power = 0 (night): any dispatch is a violation ──
    f_night = Finding[]; solution_check(_net_vw(; p_max=0.0), _res_vw(1000.0), f_night)
    @test "E.SOL.IBR_VIOLATION" in codes(f_night)
end

# ── T-BAL: power balance counts ALL injection sources ─────────────────────────
# p_gen must include IBRs and the voltage source, not just generators —
# otherwise the balance check spuriously fails whenever a DER dispatches or the
# slack imports/exports.
@testset "SOL — power balance includes IBR + voltage source" begin
    # Drop the generator; cover the load (3000 W) + line loss (750 W) with an
    # IBR (1875 W) and slack import (1875 W) → balance should close.
    net = _base_net()
    delete!(net, "generator")
    net["ibr"] = Dict{String,Any}(
        "pv1" => Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["a","b","c","n"],
            "topology" => "FOUR_LEG", "prime_mover" => "PV",
            "s_max" => [3000.0,3000.0,3000.0],
            "p_min" => [0.0,0.0,0.0], "p_max" => [3000.0,3000.0,3000.0]))

    result = _base_result()
    delete!(result, "generator")
    result["ibr"] = Dict{String,Any}(
        "pv1" => Dict{String,Any}(
            "a" => Dict("cri"=>0.0,"cii"=>0.0,"pg"=>625.0,"qg"=>0.0),
            "b" => Dict("cri"=>0.0,"cii"=>0.0,"pg"=>625.0,"qg"=>0.0),
            "c" => Dict("cri"=>0.0,"cii"=>0.0,"pg"=>625.0,"qg"=>0.0)))
    # Slack also supplies the 300 var reactive load (q_loss=0) so Q balances too.
    result["voltage_source"] = Dict{String,Any}(
        "src" => Dict{String,Any}(
            "a" => Dict("ps"=>625.0,"qs"=>100.0),
            "b" => Dict("ps"=>625.0,"qs"=>100.0),
            "c" => Dict("ps"=>625.0,"qs"=>100.0)))

    findings = Finding[]
    out = solution_check(net, result, findings)

    # p_gen = IBR 1875 + slack 1875 = 3750 W; load 3000 + loss 750 = 3750 W.
    @test out["p_gen"] ≈ 3750.0  atol=1e-6
    @test !("W.SOL.POWER_BALANCE" in codes(findings))
end

@testset "SOL — W.SOL.NEG_LOSS negative active branch loss" begin
    # Clean baseline: no per-element "loss" dicts → check is inert, no flag.
    net = _base_net()
    base = _base_result()
    f0 = Finding[]; out0 = solution_check(net, base, f0)
    @test !("W.SOL.NEG_LOSS" in codes(f0))
    @test out0["n_negative_losses"] == 0

    # A line reporting negative active loss beyond the throughput-relative band.
    neg = _base_result()
    neg["line"]["l1"]["loss"] =
        Dict{String,Any}("p_loss" => -500.0, "q_loss" => 0.0, "s_through" => 1.0e5)
    f1 = Finding[]; out1 = solution_check(net, neg, f1)
    @test "W.SOL.NEG_LOSS" in codes(f1)
    @test out1["n_negative_losses"] == 1
    @test out1["worst_negative_loss_w"] ≈ -500.0
    @test out1["worst_negative_loss_id"] == "l1"
    nf = first(x for x in f1 if x.code == "W.SOL.NEG_LOSS")
    @test nf.severity == WARNING
    @test nf.component_type == :line

    # Reactive loss is allowed to be negative (capacitive) — must NOT flag.
    cap = _base_result()
    cap["line"]["l1"]["loss"] =
        Dict{String,Any}("p_loss" => 250.0, "q_loss" => -800.0, "s_through" => 1.0e5)
    f2 = Finding[]; solution_check(net, cap, f2)
    @test !("W.SOL.NEG_LOSS" in codes(f2))

    # Sub-tolerance negative (numerical noise) — must NOT flag. Throughput 1e5 VA
    # ⇒ relative floor 1e-4·1e5 = 10 W; a −5 W residual is below it.
    noise = _base_result()
    noise["line"]["l1"]["loss"] =
        Dict{String,Any}("p_loss" => -5.0, "q_loss" => 0.0, "s_through" => 1.0e5)
    f3 = Finding[]; solution_check(net, noise, f3)
    @test !("W.SOL.NEG_LOSS" in codes(f3))

    # Transformer path: same rule, component_type :transformer.
    xf = _base_result()
    xf["transformer"]["t1"] = Dict{String,Any}(
        "loss" => Dict{String,Any}("p_loss" => -2000.0, "q_loss" => 0.0,
                                   "s_through" => 1.0e6))
    f4 = Finding[]; out4 = solution_check(net, xf, f4)
    @test "W.SOL.NEG_LOSS" in codes(f4)
    @test out4["worst_negative_loss_id"] == "t1"
    @test first(x for x in f4 if x.code == "W.SOL.NEG_LOSS").component_type == :transformer
end

@testset "SOL — voltage zone per-bus drill-down" begin
    net    = _base_net()
    result = _base_result()
    result["bus"]["b1"]["a"]["vm"] = 150.0   # b1 below v_min, worst deviation

    vz = BMOPFTools.voltage_zone_summary(net, result)
    rows = vz["zones"][1]["bus_rows"]
    @test length(rows) == 2                  # sourcebus + b1
    @test rows[1]["bus"] == "b1"             # sorted worst-deviation-first
    @test rows[1]["status"] == "violation"

    report = profile_solution(net, result)

    # verbose=true → drill-down present
    io = IOBuffer(); render_solution(report, io; verbose=true)
    md_v = String(take!(io))
    @test occursin("### Per-bus detail", md_v)
    @test occursin("Zone `b1`", md_v)       # single galvanic zone, labelled by first bus
    @test occursin("`sourcebus`", md_v)      # both buses appear as rows

    # verbose=false → band only, no drill-down
    io = IOBuffer(); render_solution(report, io; verbose=false)
    md_q = String(take!(io))
    @test occursin("## 2. Voltage by Galvanic Zone", md_q)
    @test !occursin("### Per-bus detail", md_q)
end

# ── Phase-to-neutral voltage bounds (vpn_min / vpn_max) ───────────────────────
@testset "SOL — phase-to-neutral voltage bound (vpn)" begin
    # |Vpn| = |V_phase − V_neutral| = 230 V on every phase of b1.
    net = _base_net()
    net["bus"]["b1"]["vpn_max"] = [220.0, 220.0, 220.0]   # 230 > 220 → violation
    f = Finding[]; solution_check(net, _base_result(), f)
    vf = first(x for x in f if x.code == "E.SOL.VOLT_VIOLATION")
    @test vf.detail["flavour"] == "vpn"

    # Within 1 % of the bound → active warning, not a violation.
    net2 = _base_net()
    net2["bus"]["b1"]["vpn_max"] = [232.0, 232.0, 232.0]
    f2 = Finding[]; solution_check(net2, _base_result(), f2)
    @test !("E.SOL.VOLT_VIOLATION" in codes(f2))
    @test any(x.code == "W.SOL.VOLT_ACTIVE" && x.detail["flavour"] == "vpn" for x in f2)
end

# ── Phase-to-phase voltage bounds (vpp_min / vpp_max) ─────────────────────────
@testset "SOL — phase-to-phase voltage bound (vpp)" begin
    # |Vpp| = √3·230 ≈ 398 V for the balanced fixture; 3 pairs (a-b, a-c, b-c).
    net = _base_net()
    net["bus"]["b1"]["vpp_max"] = [380.0, 380.0, 380.0]   # 398 > 380 → violation
    f = Finding[]; solution_check(net, _base_result(), f)
    vf = first(x for x in f if x.code == "E.SOL.VOLT_VIOLATION")
    @test vf.detail["flavour"] == "vpp"
    @test occursin("-", vf.detail["pair"])               # "a-b" style label

    net2 = _base_net()
    net2["bus"]["b1"]["vpp_max"] = [400.0, 400.0, 400.0]  # 398 within 1 %
    f2 = Finding[]; solution_check(net2, _base_result(), f2)
    @test any(x.code == "W.SOL.VOLT_ACTIVE" && x.detail["flavour"] == "vpp" for x in f2)
end

# ── Sequence voltage bounds (vpos / vneg / vzero) ─────────────────────────────
@testset "SOL — sequence voltage bounds" begin
    # Balanced positive sequence ≈ 230 V; vpos_min above it → undervoltage.
    # Sequence bounds are scalars (unlike the per-phase vpn/vpp arrays).
    net = _base_net()
    net["bus"]["b1"]["vpos_min"] = 240.0
    f = Finding[]; solution_check(net, _base_result(), f)
    @test any(x.code == "E.SOL.VOLT_VIOLATION" && x.detail["flavour"] == "vpos" for x in f)

    # vpos just below the magnitude → active.
    net_a = _base_net()
    net_a["bus"]["b1"]["vpos_max"] = 231.0
    fa = Finding[]; solution_check(net_a, _base_result(), fa)
    @test any(x.code == "W.SOL.VOLT_ACTIVE" && x.detail["flavour"] == "vpos" for x in fa)

    # Unbalance phase a → non-zero negative & zero sequence; tight caps → violation.
    net2 = _base_net()
    net2["bus"]["b1"]["vneg_max"]  = 5.0
    net2["bus"]["b1"]["vzero_max"] = 5.0
    res2 = _base_result()
    res2["bus"]["b1"]["a"]["vr"] = 180.0   # drag phase a down (vi stays 0)
    res2["bus"]["b1"]["a"]["vm"] = 180.0
    f2 = Finding[]; solution_check(net2, res2, f2)
    flavours = Set(x.detail["flavour"] for x in f2 if x.code == "E.SOL.VOLT_VIOLATION")
    @test "vneg" in flavours
    @test "vzero" in flavours
end

# ── Intra-bus angle-difference bounds (va_diff_min / va_diff_max) ─────────────
@testset "SOL — angle-difference bound (va_diff)" begin
    # Balanced fixture: raw inter-phase diffs are ≈ ±120° (±2.094 rad).
    # A tight window WITHOUT centering (no va_nom) is violated by the raw angle.
    net = _base_net()
    net["bus"]["b1"]["va_diff_min"] = -0.1
    net["bus"]["b1"]["va_diff_max"] =  0.1
    f = Finding[]; solution_check(net, _base_result(), f)
    vf = first(x for x in f if x.code == "E.SOL.ANGLE_VIOLATION")
    @test vf.detail["flavour"] == "va_diff"
    @test occursin("-", vf.detail["pair"])               # "a-b" style label

    # Centering on the ±120° nominal collapses the deviation to ≈ 0 → no
    # violation under the same tight window. This is the whole point.
    net2 = _base_net()
    net2["bus"]["b1"]["va_nom"]      = [0.0, -2.094, 2.094]
    net2["bus"]["b1"]["va_diff_min"] = -0.1
    net2["bus"]["b1"]["va_diff_max"] =  0.1
    f2 = Finding[]; solution_check(net2, _base_result(), f2)
    @test !any(x.code == "E.SOL.ANGLE_VIOLATION" for x in f2)
end

# ── Thermal limits: line-level i_max precedence + switch thermal ──────────────
@testset "SOL — line-level i_max precedence and switch thermal" begin
    # A line-level i_max overrides the linecode i_max (cm_fr=5 A > 3 A → violation).
    net = _base_net()
    net["line"]["l1"]["i_max"] = [3.0, 3.0, 3.0, 3.0]
    f = Finding[]; solution_check(net, _base_result(), f)
    tf = first(x for x in f if x.code == "E.SOL.THERMAL_VIOLATION")
    @test tf.detail["i_max"] == 3.0          # the line value, not the 200 A linecode

    # A switch with its own i_max: violation then near-active.
    net2 = _base_net()
    net2["switch"] = Dict{String,Any}("sw1" => Dict{String,Any}(
        "bus_from" => "sourcebus", "bus_to" => "b1",
        "terminal_map_from" => ["a","b","c","n"], "i_max" => [100.0,100.0,100.0,100.0]))
    res2 = _base_result()
    res2["switch"] = Dict{String,Any}("sw1" => Dict{String,Any}(
        "a" => Dict("cm"=>150.0), "b" => Dict("cm"=>150.0), "c" => Dict("cm"=>150.0)))
    f2 = Finding[]; solution_check(net2, res2, f2)
    @test any(x.code == "E.SOL.THERMAL_VIOLATION" && x.component_type == :switch for x in f2)

    res3 = _base_result()
    res3["switch"] = Dict{String,Any}("sw1" => Dict{String,Any}(
        "a" => Dict("cm"=>99.5), "b" => Dict("cm"=>99.5), "c" => Dict("cm"=>99.5)))
    f3 = Finding[]; solution_check(net2, res3, f3)
    @test any(x.code == "W.SOL.THERMAL_ACTIVE" && x.component_type == :switch for x in f3)
end

# ── IBR dispatch bounds, apparent-power circle, PF residual ──────────────
@testset "SOL — IBR limits and PF deviation" begin
    net = _base_net()
    net["control_profile"] = Dict{String,Any}(
        "cp1" => Dict{String,Any}("power_factor" => Dict{String,Any}("pf" => 0.95)))
    net["ibr"] = Dict{String,Any}(
        "inv1" => Dict{String,Any}(   # FOUR_LEG: P-violation + s_max + PF deviation
            "bus" => "b1", "terminal_map" => ["a","b","c","n"], "topology" => "FOUR_LEG",
            "p_min" => [0.0,0.0,0.0], "p_max" => [1000.0,1000.0,1000.0],
            "s_max" => [1200.0,1200.0,1200.0], "control_profile" => "cp1"),
        "inv2" => Dict{String,Any}(   # SINGLE_PHASE topology branch (clean)
            "bus" => "b1", "terminal_map" => ["a","n"], "topology" => "SINGLE_PHASE",
            "p_min" => [0.0], "p_max" => [500.0], "s_max" => [600.0]))
    result = _base_result()
    result["ibr"] = Dict{String,Any}(
        "inv1" => Dict{String,Any}(
            "a" => Dict("pg"=>2000.0, "qg"=>1500.0),   # pg>1000, |S|=2500>1200
            "b" => Dict("pg"=>2000.0, "qg"=>1500.0),
            "c" => Dict("pg"=>2000.0, "qg"=>1500.0)),
        "inv2" => Dict{String,Any}("a" => Dict("pg"=>300.0, "qg"=>0.0)))

    f = Finding[]; out = solution_check(net, result, f)
    @test out["n_inv_violations"] > 0
    @test "E.SOL.IBR_VIOLATION" in codes(f)                     # P bound + s_max circle
    @test "W.SOL.IBR_PF_DEVIATION" in codes(f)                  # constant-PF residual
    # both the P-bound and the apparent-power-circle messages are present
    msgs = join((x.message for x in f if x.code == "E.SOL.IBR_VIOLATION"), " ")
    @test occursin("violates", msgs)
    @test occursin("s_max", msgs)
end

# ── Voltage-dependent load model residuals + VD summary ───────────────────────
@testset "SOL — voltage-dependent load model residuals" begin
    # Four single-phase VD loads on b1; the solved bus voltage is exactly Vnom so
    # each model predicts its nominal power, but the result reports 1500 W ≠ model
    # → W.SOL.LOAD_MODEL_RESIDUAL for each, exercising every _load_model_power arm.
    net = _base_net()
    mkload(model, extra) = merge!(Dict{String,Any}(
        "bus" => "b1", "terminal_map" => ["a","n"], "configuration" => "SINGLE_PHASE",
        "p_nom" => [1000.0], "q_nom" => [100.0], "model" => model,
        "v_nom" => [230.0]), extra)
    net["load"] = Dict{String,Any}(
        "ldz"   => mkload("constant_impedance", Dict{String,Any}()),
        "ldi"   => mkload("constant_current",   Dict{String,Any}()),
        "ldzip" => mkload("zip", Dict{String,Any}(
            "alpha_z"=>[1.0],"alpha_i"=>[0.0],"alpha_p"=>[0.0],
            "beta_z"=>[1.0],"beta_i"=>[0.0],"beta_p"=>[0.0])),
        "ldexp" => mkload("exponential", Dict{String,Any}(
            "gamma_p"=>[2.0],"gamma_q"=>[2.0])))
    result = _base_result()
    result["load"] = Dict{String,Any}(
        lid => Dict{String,Any}("a" => Dict("pd"=>1500.0, "qd"=>250.0))
        for lid in ("ldz","ldi","ldzip","ldexp"))

    f = Finding[]; out = solution_check(net, result, f)
    @test out["n_load_model_residuals"] == 4
    @test "W.SOL.LOAD_MODEL_RESIDUAL" in codes(f)
    @test "I.SOL.LOAD_VD_SUMMARY" in codes(f)                   # aggregate VD summary
    @test out["vd_p_real_total"] ≈ 6000.0                       # 4 × 1500 W
    @test out["vd_p_nom_total"]  ≈ 4000.0                       # 4 × 1000 W
end

@testset "SOL — unknown load model is skipped, not a crash" begin
    # Regression: the skip guard mis-parsed as `a || (b && continue)`, so an
    # unrecognised model string reached `abs(pd - nothing)` → MethodError.
    net = _base_net()
    net["load"]["ld1"]["model"] = "constant_mystery"
    net["load"]["ld1"]["v_nom"] = [230.0, 230.0, 230.0]
    result = _base_result()
    f = Finding[]
    out = solution_check(net, result, f)                        # must not throw
    @test out["n_load_model_residuals"] == 0
    @test !("W.SOL.LOAD_MODEL_RESIDUAL" in codes(f))
end

# ── Reactive-power balance ────────────────────────────────────────────────────
@testset "SOL — reactive power balance error" begin
    net = _base_net()
    result = _base_result()
    # Inflate generator reactive output so Σqg ≫ qd + q_loss (active stays balanced).
    for ph in ("a","b","c")
        result["generator"]["g1"][ph]["qg"] = 2000.0
    end
    f = Finding[]; out = solution_check(net, result, f)
    @test out["q_power_balance_err"] > 1.0
    @test any(x.code == "W.SOL.POWER_BALANCE" &&
              get(x.detail, "flavour", "") == "reactive" for x in f)
end

# ── Initialisation quality: large error & non-zero neutral ────────────────────
@testset "SOL — initialisation quality findings" begin
    net = _base_net()
    result = _base_result()
    # b1.a solved at 230 V; init it at 300 V (30 % off, but < 10×) → large error.
    # b1.n initialised non-zero → neutral-nonzero info.
    result["initialisation"] = Dict{String,Any}(
        "b1" => Dict{String,Any}(
            "a" => Dict{String,Any}("vm_init" => 300.0),
            "n" => Dict{String,Any}("vm_init" => 5.0)))
    f = Finding[]; out = solution_check(net, result, f)
    @test out["n_init_large_errors"] == 1
    @test out["n_init_neutral_nonzero"] == 1
    @test "W.SOL.INIT_LARGE_ERROR" in codes(f)
    @test "I.SOL.INIT_NEUTRAL_NONZERO" in codes(f)
end

# ── voltage_zone_summary: declared-base median + active/violation per phase ────
@testset "SOL — zone summary declared base and per-phase status" begin
    net = _base_net()
    # Even number of declared voltages across the zone → median is their average.
    net["bus"]["sourcebus"]["v_declared"] = 230.0
    net["bus"]["b1"]["v_declared"]        = 240.0
    result = _base_result()
    # Drive the three phases of b1 to active-low, active-high, and violation-high.
    result["bus"]["b1"]["a"]["vm"] = 201.0   # within 1 % of v_min 200 → active
    result["bus"]["b1"]["b"]["vm"] = 259.0   # within 1 % of v_max 260 → active
    result["bus"]["b1"]["c"]["vm"] = 261.0   # above v_max 260       → violation

    vz = BMOPFTools.voltage_zone_summary(net, result)
    zone = vz["zones"][1]
    @test zone["v_base"] ≈ 235.0             # (230 + 240) / 2
    @test zone["status"] == "violation"      # the 261 V phase dominates
    b1row = first(r for r in zone["bus_rows"] if r["bus"] == "b1")
    @test b1row["status"] == "violation"
end
