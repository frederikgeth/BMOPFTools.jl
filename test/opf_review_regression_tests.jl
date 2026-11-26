# Regression tests for the November 2026 OPF engine review.
#
# Included from runtests.jl when JuMP and Ipopt are in the load path.
#
# Each testset pins one defect found in that review. The fixtures are the
# smallest networks that expose it, and wherever possible the oracle is
# physics rather than a stored number: per-unit and SI solves must agree,
# power must balance, or a determined problem must reject an undetermined
# device.

@testset "OPF engine review regressions" begin
    D = Dict{String,Any}
    tight = ("tol" => 1e-10, "constr_viol_tol" => 1e-10)
    solved(r) = r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

    # ── Two-wire (phase + grounded neutral) building blocks ──────────────────
    bus2() = D("terminal_names" => ["p", "n"], "perfectly_grounded_terminals" => ["n"])
    src2(bus; v=240.0) = D("bus" => bus, "terminal_map" => ["p", "n"],
        "v_magnitude" => [v, 0.0], "v_angle" => [0.0, 0.0], "cost" => [0.25])
    load2(bus; p=250.0, q=65.0) = D("bus" => bus, "terminal_map" => ["p", "n"],
        "configuration" => "SINGLE_PHASE", "model" => "constant_power",
        "p_nom" => [p], "q_nom" => [q])
    line2(bf, bt; r=0.05, x=0.03) = D("bus_from" => bf, "bus_to" => bt,
        "terminal_map_from" => ["p", "n"], "terminal_map_to" => ["p", "n"],
        "R_series_1_1" => r, "X_series_1_1" => x,
        "R_series_2_2" => r, "X_series_2_2" => x,
        "R_series_1_2" => 0.0, "X_series_1_2" => 0.0)
    xfmr2(bf, bt, vf, vt) = D("bus_from" => bf, "bus_to" => bt,
        "terminal_map_from" => ["p", "n"], "terminal_map_to" => ["p", "n"],
        "v_nom_from" => vf, "v_nom_to" => vt,
        "r_series_from" => 0.1, "x_series_from" => 0.08,
        "r_series_to" => 0.025, "x_series_to" => 0.02)

    # ── 1. One voltage base per galvanic zone ────────────────────────────────
    # A regulator's two bus records are bonded by copper and its model uses
    # `tap_ratio` only. Propagating a base through its `v_nom_*` nameplate
    # applied the regulation twice in per-unit.
    @testset "per-unit: a regulator does not change the voltage base" begin
        regulator(extra) = merge(D("bus_from" => "f", "bus_to" => "t",
            "terminal_map_from" => ["p", "n"], "terminal_map_to" => ["p", "n"],
            "tap_ratio" => 1.05, "regulator_type" => "B",
            "r_series_from" => 0.1, "r_series_to" => 0.1), extra)
        for extra in (D("v_nom_from" => 240.0, "v_nom_to" => 252.0),
                      D("v_nom_from" => 240.0),          # one-sided nameplate
                      D())
            net = D("bus" => D("f" => bus2(), "t" => bus2()),
                "voltage_source" => D("s" => src2("f")),
                "transformer" => D("single_phase_autotransformer" =>
                    D("x" => regulator(extra))),
                "load" => D("l" => load2("t")))
            pu = solve_pf(deepcopy(net); per_unit=true, solver_options=tight)
            si = solve_pf(deepcopy(net); per_unit=false, solver_options=tight)
            @test solved(pu) && solved(si)
            @test pu["bus"]["t"]["p"]["vm"] ≈ si["bus"]["t"]["p"]["vm"] rtol=1e-6
            # Type B at tap 1.05 raises the regulated side by about 5 %.
            @test 245.0 < pu["bus"]["t"]["p"]["vm"] < 255.0
        end
    end

    # A line closing a loop between two transformers of unequal ratio used to
    # join buses holding different bases; the circulating current vanished.
    @testset "per-unit: unequal-ratio transformer mesh keeps its circulating current" begin
        net = D("bus" => D("f" => bus2(), "t1" => bus2(), "t2" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "transformer" => D("single_phase" => D(
                "a" => xfmr2("f", "t1", 240.0, 120.0),
                "b" => xfmr2("f", "t2", 240.0, 126.0))),
            "line" => D("m" => line2("t1", "t2")),
            "load" => D("l" => load2("t2")))
        pu = solve_pf(deepcopy(net); per_unit=true, solver_options=tight)
        si = solve_pf(deepcopy(net); per_unit=false, solver_options=tight)
        @test solved(pu) && solved(si)
        @test pu["line"]["m"]["p"]["cm_fr"] ≈ si["line"]["m"]["p"]["cm_fr"] rtol=1e-5
        @test pu["losses"]["p_loss"] ≈ si["losses"]["p_loss"] rtol=1e-5
        # 6 V of open-circuit mismatch across ~0.2 Ω of loop impedance: tens of amperes.
        @test si["line"]["m"]["p"]["cm_fr"] > 10.0
    end

    # ── 2. Angle windows bound phase conductors only ─────────────────────────
    @testset "line angle window skips the neutral conductor" begin
        function feeder(window)
            buses = D(b => D("terminal_names" => ["a", "b", "c", "n"])
                      for b in ("src", "b1", "b2"))
            fourwire(bf, bt) = merge(D("bus_from" => bf, "bus_to" => bt,
                "terminal_map_from" => ["a", "b", "c", "n"],
                "terminal_map_to" => ["a", "b", "c", "n"]),
                D("R_series_$(k)_$(k)" => 0.2 for k in 1:4))
            lines = D("l1" => fourwire("src", "b1"), "l2" => fourwire("b1", "b2"))
            if window !== nothing
                lines["l2"]["va_diff_min"] = -window
                lines["l2"]["va_diff_max"] = window
            end
            single(bus, ph) = D("bus" => bus, "terminal_map" => [ph, "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [3000.0], "q_nom" => [0.0])
            D("bus" => buses, "line" => lines,
              "voltage_source" => D("vs" => D("bus" => "src",
                  "terminal_map" => ["a", "b", "c"],
                  "v_magnitude" => fill(230.0, 3),
                  "v_angle" => [0.0, -2pi/3, 2pi/3])),
              "load" => D("la" => single("b1", "a"), "lb" => single("b2", "b")))
        end
        free = solve_opf(feeder(nothing); per_unit=false)
        # The premise: the phases barely move, the neutral phasor swings widely.
        swing = abs(rem2pi(free["bus"]["b1"]["n"]["va"] - free["bus"]["b2"]["n"]["va"], RoundNearest))
        @test swing > 0.3
        for pu in (true, false)
            ctx = build_opf_model(feeder(0.2); per_unit=pu)
            rows = [k.index for k in opf_object_keys(ctx; kind=:constraint)
                    if startswith(string(k.family), "line_angle_")]
            @test length(rows) == 6                       # 3 phases × (lower, upper)
            @test all(index -> index[2] in 1:3, rows)     # conductor 4 is the neutral
            windowed = solve_opf(feeder(0.2); per_unit=pu)
            @test solved(windowed)
            @test windowed["bus"]["b2"]["b"]["vm"] ≈ free["bus"]["b2"]["b"]["vm"] rtol=1e-5
        end
    end

    # ── 3. DELTA generator geometry ──────────────────────────────────────────
    @testset "DELTA generator: one coil per phase pair, phase terminals only" begin
        function gen_net(terminal_map, bounds)
            fourwire = merge(D("bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a", "b", "c", "n"],
                "terminal_map_to" => ["a", "b", "c", "n"]),
                D("R_series_$(k)_$(k)" => 0.2 for k in 1:4))
            D("bus" => D(b => D("terminal_names" => ["a", "b", "c", "n"])
                         for b in ("src", "b1")),
              "voltage_source" => D("vs" => D("bus" => "src",
                  "terminal_map" => ["a", "b", "c"],
                  "v_magnitude" => fill(230.0, 3),
                  "v_angle" => [0.0, -2pi/3, 2pi/3])),
              "line" => D("l1" => fourwire),
              "generator" => D("g" => D("bus" => "b1",
                  "terminal_map" => terminal_map, "configuration" => "DELTA",
                  "p_min" => bounds, "p_max" => bounds,
                  "q_min" => zero(bounds), "q_max" => zero(bounds))))
        end
        # Two terminals are ONE line-to-line coil, delivering its setpoint once.
        result = solve_opf(gen_net(["a", "b"], [1000.0]))
        @test solved(result)
        @test length(result["generator"]["g"]) == 1
        @test sum(coil["pg"] for coil in values(result["generator"]["g"])) ≈ 1000.0 atol=0.1
        exported = -sum(ph["ps"] for ph in values(result["voltage_source"]["vs"]))
        @test 900.0 < exported < 1000.0     # setpoint less line loss, not twice it
        # Bound vectors must cover every coil, and a neutral is not a delta endpoint.
        @test_throws ArgumentError solve_opf(gen_net(["a", "b"], [1000.0, 1000.0]))
        @test_throws ArgumentError solve_opf(gen_net(["a", "b", "c"], [1000.0]))
        @test_throws ArgumentError solve_opf(gen_net(["a", "b", "c", "n"], fill(1000.0, 4)))
        @test solved(solve_opf(gen_net(["a", "b", "c"], fill(1000.0, 3))))
    end

    # ── 4. DC conductors dissipate real power ────────────────────────────────
    mvdc_tie() = parse_bmopf("""
    {"bus":{
        "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[220.0],"v_max":[245.0]},
        "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[220.0],"v_max":[245.0]}},
     "voltage_source":{
        "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]},
        "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[10.0]}},
     "load":{"L2":{"bus":"f2","terminal_map":["a","n"],"configuration":"SINGLE_PHASE","p_nom":[5000.0],"q_nom":[0.0]}},
     "ibr":{
        "vsc1":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[8000.0],
                "dc_bus":"dcA","dc_terminal_map":["p","m"],"dc_control":"V","dc_v_set":850.0},
        "vsc2":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[8000.0],
                "dc_bus":"dcB","dc_terminal_map":["p","m"]}},
     "dc_bus":{
        "dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},"v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]},
        "dcB":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},"v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
     "dc_branch":{"line":{"dc_bus_from":"dcA","dc_bus_to":"dcB",
        "terminal_map_from":["p","m"],"terminal_map_to":["p","m"],"r":[5.0,0.0]}},
     "dc_grounding":{"gA":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
    """; from_string=true)

    @testset "losses include DC-branch I²R" begin
        for pu in (true, false)
            result = solve_opf(mvdc_tie(); per_unit=pu)
            @test solved(result)
            current = result["dc_branch"]["line"]["1"]["i_dc"]
            ohmic = 5.0 * current^2
            @test ohmic > 10.0
            @test result["dc_branch"]["line"]["loss"]["p_loss"] ≈ ohmic rtol=1e-4
            # No AC series elements here: the network loss IS the DC-branch loss,
            # and it closes the power balance (sources in, load out).
            @test result["losses"]["p_loss"] ≈ ohmic rtol=1e-4
            supplied = sum(ph["ps"] for src in values(result["voltage_source"])
                           for ph in values(src))
            @test supplied - 5000.0 ≈ result["losses"]["p_loss"] rtol=1e-3
        end
        ctx = build_opf_model(mvdc_tie(); per_unit=true)
        optimize_opf!(ctx)
        result = extract_result(ctx)
        s_base = opf_bases(ctx).s_base
        @test JuMP.value(BMOPFTools.opf_total_loss(ctx)) * s_base ≈
              result["losses"]["p_loss"] rtol=1e-6
        @test JuMP.value(BMOPFTools.opf_element_loss(ctx, "dc_branch", "line")) * s_base ≈
              result["losses"]["p_loss"] rtol=1e-6
        @test_throws ArgumentError BMOPFTools.opf_element_loss(ctx, "dc_branch", "nope")
    end

    # ── 5. DC droop acts on the pole-voltage magnitude ───────────────────────
    @testset "DC V–P droop is symmetric in pole polarity" begin
        function station(sign)
            role = sign > 0 ? "POSITIVE" : "NEGATIVE"
            lo, hi = sign > 0 ? (600.0, 1000.0) : (-1000.0, -600.0)
            parse_bmopf("""
            {"bus":{
                "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[210.0],"v_max":[250.0]},
                "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[210.0],"v_max":[250.0]}},
             "voltage_source":{
                "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]},
                "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]}},
             "ibr":{
                "vM":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[20000.0],
                      "dc_bus":"dcA","dc_terminal_map":["p","m"],"dc_control":"V","dc_v_set":$(sign * 820.0)},
                "vD":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[8000.0],
                      "dc_bus":"dcA","dc_terminal_map":["p","m"],"dc_control":"droop",
                      "dc_v_set":$(sign * 800.0),"dc_droop":0.01,"dc_p_ref":3000.0}},
             "dc_bus":{"dcA":{"terminal_names":["p","m"],"pole":{"p":"$role","m":"METALLIC_RETURN"},
                              "v_dc_min":[$lo,0.0],"v_dc_max":[$hi,0.0]}},
             "dc_grounding":{"g":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
            """; from_string=true)
        end
        # 20 V above the set magnitude at 0.01 V/W adds 2 kW to the 3 kW reference,
        # whichever pole the port sits on.
        for sign in (1.0, -1.0)
            result = solve_opf(station(sign))
            @test solved(result)
            @test result["dc_bus"]["dcA"]["p"]["v_dc"] ≈ sign * 820.0 atol=1e-2
            @test result["ibr"]["vD"]["a"]["pg"] ≈ 5000.0 atol=25.0
        end
    end

    # ── 6. Volt-watt P_AVAILABLE is per coil ─────────────────────────────────
    @testset "phase-to-phase SINGLE_PHASE IBR keeps its full available power" begin
        function pv_net(terminal_map)
            buses = D(b => D("terminal_names" => ["a", "b", "n"],
                             "perfectly_grounded_terminals" => ["n"])
                      for b in ("src", "e"))
            line = merge(D("bus_from" => "src", "bus_to" => "e",
                "terminal_map_from" => ["a", "b", "n"],
                "terminal_map_to" => ["a", "b", "n"]),
                D("R_series_$(k)_$(k)" => 0.01 for k in 1:3))
            D("bus" => buses, "line" => D("l" => line),
              "voltage_source" => D("s" => D("bus" => "src",
                  "terminal_map" => ["a", "b"], "v_magnitude" => [120.0, 120.0],
                  "v_angle" => [0.0, Float64(pi)], "cost" => [0.2, 0.2])),
              "ibr" => D("pv" => D("bus" => "e", "terminal_map" => terminal_map,
                  "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
                  "p_min" => [0.0], "p_max" => [6000.0], "p_avail" => 6000.0,
                  "q_min" => [0.0], "q_max" => [0.0], "s_max" => [8000.0],
                  "cost" => [-1.0], "control_profile" => "cp")),
              # Breakpoints far above the operating voltage: the cap sits at 100 %.
              "control_profile" => D("cp" => D("volt_watt" => D(
                  "voltage_reference" => "PG_PER_PHASE",
                  "breakpoints" => [200.0, 210.0], "p_limits" => [0.2, 1.0],
                  "p_unit" => "VA_FRACTION", "p_ref" => "P_AVAILABLE"))))
        end
        for terminal_map in (["a", "n"], ["a", "b"]), pu in (true, false)
            result = solve_opf(pv_net(terminal_map); per_unit=pu)
            @test solved(result)
            @test sum(coil["pg"] for coil in values(result["ibr"]["pv"])) ≈ 6000.0 rtol=2e-2
        end
    end

    # ── 7. A power flow must be determined ───────────────────────────────────
    @testset "solve_pf rejects undetermined devices" begin
        base() = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")),
            "load" => D("l" => load2("t")))
        ibr(fields) = merge(D("bus" => "t", "terminal_map" => ["p", "n"],
            "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
            "s_max" => [8000.0]), fields)
        with_ibr(fields) = (n = base(); n["ibr"] = D("pv" => ibr(fields)); n)
        fixed = D("p_min" => [100.0], "p_max" => [100.0],
                  "q_min" => [0.0], "q_max" => [0.0])
        @test solved(solve_pf(with_ibr(fixed)))
        # An active-power range, a missing reactive bound, a one-sided bound.
        @test_throws ArgumentError solve_pf(with_ibr(
            D("p_min" => [0.0], "p_max" => [5000.0], "q_min" => [0.0], "q_max" => [0.0])))
        @test_throws ArgumentError solve_pf(with_ibr(D("p_min" => [100.0], "p_max" => [100.0])))
        @test_throws ArgumentError solve_pf(with_ibr(D("p_max" => [100.0],
            "q_min" => [0.0], "q_max" => [0.0])))
        generator(fields) = (n = base(); n["generator"] = D("g" => merge(D("bus" => "t",
            "terminal_map" => ["p", "n"], "configuration" => "SINGLE_PHASE"), fields)); n)
        @test solved(solve_pf(generator(fixed)))
        @test_throws ArgumentError solve_pf(generator(D("p_min" => [100.0], "p_max" => [100.0])))
        @test_throws ArgumentError solve_pf(generator(D("p_min" => [100.0],
            "q_min" => [0.0], "q_max" => [0.0])))
    end

    # ── 8. Feasibility slack is priced in amperes ────────────────────────────
    @testset "feasibility slack location is independent of the unit system" begin
        bus4(; fields...) = merge(D("terminal_names" => ["a", "b", "c", "n"],
            "perfectly_grounded_terminals" => ["n"]),
            D(string(k) => v for (k, v) in fields))
        function line4(bf, bt; r, x)
            d = D("bus_from" => bf, "bus_to" => bt,
                  "terminal_map_from" => ["a", "b", "c", "n"],
                  "terminal_map_to" => ["a", "b", "c", "n"])
            for i in 1:4, j in i:4
                d["R_series_$(i)_$(j)"] = i == j ? r : r / 10
                d["X_series_$(i)_$(j)"] = i == j ? x : x / 5
            end
            d
        end
        v_mv = 11000 / sqrt(3)
        net = D("bus" => D("hv" => bus4(),
                "mv" => bus4(vpn_min=fill(0.97 * v_mv, 3)), "lv" => bus4(),
                "e" => bus4(vpn_max=fill(253.0, 3), vpn_min=fill(225.0, 3))),
            "voltage_source" => D("s" => D("bus" => "hv", "terminal_map" => ["a", "b", "c"],
                "v_magnitude" => fill(v_mv, 3), "v_angle" => [0.0, -2pi/3, 2pi/3])),
            "transformer" => D("delta_wye" => D("tx" => D("bus_from" => "mv", "bus_to" => "lv",
                "terminal_map_from" => ["a", "b", "c"],
                "terminal_map_to" => ["a", "b", "c", "n"],
                "v_nom_from" => v_mv, "v_nom_to" => 230.0,
                "r_series" => 0.02, "x_series" => 0.06))),
            "line" => D("l" => line4("lv", "e"; r=0.05, x=0.03),
                        "lm" => line4("hv", "mv"; r=40.0, x=40.0)),
            "load" => D("ld" => D("bus" => "e", "terminal_map" => ["a", "b", "c", "n"],
                "configuration" => "WYE", "model" => "constant_power",
                "p_nom" => [30000.0, 10000.0, 5000.0], "q_nom" => [5000.0, 2000.0, 1000.0])))
        pu = solve_feasibility_opf(deepcopy(net); per_unit=true)
        si = solve_feasibility_opf(deepcopy(net); per_unit=false)
        @test pu["total_slack_magnitude_A"] > 1.0          # genuinely infeasible
        @test pu["total_slack_magnitude_A"] ≈ si["total_slack_magnitude_A"] rtol=2e-2
        level(result, bus) = sum(t["cs_mag"] for t in values(get(result["slack_injections"], bus, D()));
                                 init=0.0)
        for bus in ("mv", "lv", "e")
            @test level(pu, bus) ≈ level(si, bus) rtol=5e-2 atol=0.05
        end
    end

    # ── 9. Smaller contracts ─────────────────────────────────────────────────
    @testset "capacitor requires v_nom" begin
        net = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")),
            "capacitor" => D("c" => D("bus" => "t", "terminal_map" => ["p", "n"],
                "configuration" => "SINGLE_PHASE", "q_rated" => [500.0])),
            "load" => D("l" => load2("t")))
        @test_throws ArgumentError solve_pf(deepcopy(net))
        net["capacitor"]["c"]["v_nom"] = 240.0
        pu = solve_pf(deepcopy(net); per_unit=true, solver_options=tight)
        si = solve_pf(deepcopy(net); per_unit=false, solver_options=tight)
        @test pu["voltage_source"]["s"]["p"]["qs"] ≈ si["voltage_source"]["s"]["p"]["qs"] rtol=1e-5
    end

    # ── 10. Unity minimum power factor is one equality ───────────────────────
    @testset "minimum power factor of exactly one stamps Q = 0 once" begin
        function policy_net(pf_min)
            path = joinpath(@__DIR__, "data", "ibr_minimum_pf", "curtailed.json")
            net = JSON3.read(read(path, String), Dict{String,Any})
            net["extras"]["bmopftools"]["minimum_power_factor"]["ibr"]["pv"]["pf_min"] = pf_min
            net
        end
        families(ctx) = Set(k.family for k in opf_object_keys(ctx; kind=:constraint)
                            if startswith(string(k.family), "ibr_minimum_pf"))
        # Below unity the limit is a wedge |Q| <= tan(phi)·P: two rows.
        @test families(build_opf_model(policy_net(0.8); per_unit=false)) ==
              Set([:ibr_minimum_pf_generation, :ibr_minimum_pf_lower, :ibr_minimum_pf_upper])
        # At unity the wedge closes to Q = 0: one equality, no opposing pair.
        for pu in (true, false)
            ctx = build_opf_model(policy_net(1.0); per_unit=pu)
            @test families(ctx) ==
                  Set([:ibr_minimum_pf_generation, :ibr_minimum_pf_equality])
            optimize_opf!(ctx)
            result = extract_result(ctx)
            @test solved(result)
            @test all(abs(coil["qg"]) < 1e-3 for coil in values(result["ibr"]["pv"]))
        end
    end

    # ── 11. A source that is not solidly grounded ────────────────────────────
    # The OPF earths the neutral of every voltage-source bus. The documented
    # way to model an impedance-grounded supply is to keep the source on a bus
    # of its own and place the grounding impedance on the next bus. The oracle
    # is the series circuit: source 230 V, two 0.1 Ω conductors, the 0.5 Ω
    # grounding resistor, and a 3 kW constant-power load, I·(230 − 0.7·I) = 3000.
    @testset "impedance-grounded supply: source on its own bus" begin
        fourwire(bf, bt) = merge(D("bus_from" => bf, "bus_to" => bt,
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to" => ["a", "b", "c", "n"]),
            D("R_series_$(k)_$(k)" => 0.1 for k in 1:4))
        link = merge(D("bus_from" => "s", "bus_to" => "h",
            "terminal_map_from" => ["a", "b", "c"], "terminal_map_to" => ["a", "b", "c"]),
            D("R_series_$(k)_$(k)" => 0.0 for k in 1:3))
        net = D("bus" => D("s" => D("terminal_names" => ["a", "b", "c"]),
                "h" => D("terminal_names" => ["a", "b", "c", "n"]),
                "e" => D("terminal_names" => ["a", "b", "c", "n"])),
            "voltage_source" => D("vs" => D("bus" => "s", "terminal_map" => ["a", "b", "c"],
                "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3])),
            "line" => D("link" => link, "feeder" => fourwire("h", "e")),
            "shunt" => D("zg" => D("bus" => "h", "terminal_map" => ["n"], "G_1_1" => 1 / 0.5)),
            "load" => D("la" => D("bus" => "e", "terminal_map" => ["a", "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [3000.0], "q_nom" => [0.0])))
        current = (230.0 - sqrt(230.0^2 - 4 * 0.7 * 3000.0)) / (2 * 0.7)
        for pu in (true, false)
            result = solve_pf(deepcopy(net); per_unit=pu, solver_options=tight)
            @test solved(result)
            @test result["line"]["feeder"]["n"]["cm_fr"] ≈ current rtol=1e-6
            @test result["bus"]["h"]["n"]["vm"] ≈ 0.5 * current rtol=1e-6
            @test result["bus"]["e"]["n"]["vm"] ≈ 0.6 * current rtol=1e-6
        end
    end

    # ── 12. Findings from the review of this change set ──────────────────────
    @testset "unity power factor never duplicates an existing Q = 0 row" begin
        function unity_net(; count=1, fields=D())
            path = joinpath(@__DIR__, "data", "ibr_minimum_pf", "curtailed.json")
            net = JSON3.read(read(path, String), Dict{String,Any})
            template = merge(net["ibr"]["pv"], fields)
            policy = net["extras"]["bmopftools"]["minimum_power_factor"]["ibr"]
            request = merge(policy["pv"], D("pf_min" => 1.0))
            empty!(net["ibr"]); empty!(policy)
            for k in 1:count
                net["ibr"]["pv$k"] = deepcopy(template)
                policy["pv$k"] = deepcopy(request)
            end
            net
        end
        rows(ctx, family) = count(k -> k.family == family,
                                  opf_object_keys(ctx; kind=:constraint))
        pinned = D("p_min" => [400.0], "p_max" => [400.0],
                   "q_min" => [0.0], "q_max" => [0.0])
        # A reactive box pinned at zero already says Q = 0: one row, not two.
        ctx = build_opf_model(unity_net(; fields=pinned); per_unit=false)
        @test rows(ctx, :ibr_q_equality) == 1
        @test rows(ctx, :ibr_minimum_pf_equality) == 0
        # A free reactive box leaves the policy row as the only Q = 0.
        ctx = build_opf_model(unity_net(); per_unit=false)
        @test rows(ctx, :ibr_minimum_pf_equality) == 1
        # Many fully pinned units: equalities must not outnumber the unknowns.
        for pu in (true, false)
            result = solve_opf(unity_net(; count=16, fields=pinned); per_unit=pu)
            @test solved(result)
            @test all(abs(only(values(unit))["qg"]) < 1e-3 for unit in values(result["ibr"]))
        end
    end

    @testset "shared DC-link balance is not restated when every coil is pinned" begin
        function statcom(p)
            buses = D(b => D("terminal_names" => ["a", "b", "c", "n"],
                             "perfectly_grounded_terminals" => ["n"]) for b in ("s", "e"))
            line = merge(D("bus_from" => "s", "bus_to" => "e",
                "terminal_map_from" => ["a", "b", "c", "n"],
                "terminal_map_to" => ["a", "b", "c", "n"]),
                D("R_series_$(k)_$(k)" => 0.05 for k in 1:4))
            D("bus" => buses, "line" => D("l" => line),
              "voltage_source" => D("vs" => D("bus" => "s", "terminal_map" => ["a", "b", "c"],
                  "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3],
                  "cost" => fill(0.2, 3))),
              "ibr" => D("sc" => D("bus" => "e", "terminal_map" => ["a", "b", "c", "n"],
                  "topology" => "FOUR_LEG", "prime_mover" => "STATCOM",
                  "dc_link_coupled" => true, "s_max" => fill(5000.0, 3),
                  "p_min" => p, "p_max" => p,
                  "q_min" => fill(0.0, 3), "q_max" => fill(0.0, 3))))
        end
        balance(ctx) = count(k -> startswith(string(k.family), "ibr_dc_power"),
                             opf_object_keys(ctx; kind=:constraint))
        # Pinned coil powers that already sum to the balance imply it.
        @test balance(build_opf_model(statcom([300.0, -100.0, -200.0]); per_unit=false)) == 0
        @test solved(solve_opf(statcom([300.0, -100.0, -200.0])))
        # Pinned powers that violate the balance keep the row: a real conflict.
        @test balance(build_opf_model(statcom([300.0, 0.0, 0.0]); per_unit=false)) == 1
    end

    @testset "solve_pf determinacy is checked coil by coil" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        function ibr_net(fields; profile=nothing)
            buses = D(b => D("terminal_names" => ["a", "b", "c", "n"],
                             "perfectly_grounded_terminals" => ["n"]) for b in ("s", "e"))
            line = merge(D("bus_from" => "s", "bus_to" => "e",
                "terminal_map_from" => ["a", "b", "c", "n"],
                "terminal_map_to" => ["a", "b", "c", "n"]),
                D("R_series_$(k)_$(k)" => 0.05 for k in 1:4))
            net = D("bus" => buses, "line" => D("l" => line),
              "voltage_source" => D("vs" => D("bus" => "s", "terminal_map" => ["a", "b", "c"],
                  "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3])),
              "ibr" => D("x" => merge(D("bus" => "e", "prime_mover" => "PV",
                  "s_max" => fill(8000.0, 3)), fields)))
            if profile !== nothing
                net["control_profile"] = D("cp" => profile)
                net["ibr"]["x"]["control_profile"] = "cp"
            end
            net
        end
        four(fields) = merge(D("terminal_map" => ["a", "b", "c", "n"], "topology" => "FOUR_LEG"), fields)
        three(fields) = merge(D("terminal_map" => ["a", "b", "c"], "topology" => "THREE_LEG"), fields)
        fixed3 = D("p_min" => fill(500.0, 3), "p_max" => fill(500.0, 3),
                   "q_min" => fill(0.0, 3), "q_max" => fill(0.0, 3))
        volt_var = D("volt_var" => D("voltage_reference" => "PN_PER_PHASE",
            "breakpoints" => [207.0, 220.0, 240.0, 253.0], "q_limits" => [-0.44, 0.44],
            "q_unit" => "VA_FRACTION", "q_ref" => "VAR_MAX"))
        ranged_q = D("p_min" => fill(500.0, 3), "p_max" => fill(500.0, 3),
                     "q_min" => fill(-4000.0, 3), "q_max" => fill(4000.0, 3))

        @test solved(solve_pf(ibr_net(four(fixed3))))
        # One-entry vectors on a three-coil device leave two coils free.
        short = D("p_min" => [500.0], "p_max" => [500.0], "q_min" => [0.0], "q_max" => [0.0])
        @test_throws ArgumentError solve_pf(ibr_net(four(short)))
        @test_throws ArgumentError solve_opf(ibr_net(four(short)))   # same rule in the OPF
        # Volt-var determines Q where the builder stamps it, and only there.
        @test solved(solve_pf(ibr_net(four(ranged_q); profile=volt_var)))
        @test_throws ArgumentError solve_pf(ibr_net(three(ranged_q); profile=volt_var))
        malformed = D("volt_var" => merge(volt_var["volt_var"], D("breakpoints" => [207.0, 253.0])))
        @test_throws ArgumentError solve_pf(ibr_net(four(ranged_q); profile=malformed))
        # A shared DC link fixes only the SUM of the coil powers.
        coupled = D("dc_link_coupled" => true, "prime_mover" => "STATCOM",
                    "p_min" => fill(-2000.0, 3), "p_max" => fill(2000.0, 3),
                    "q_min" => fill(0.0, 3), "q_max" => fill(0.0, 3))
        @test_throws ArgumentError solve_pf(ibr_net(four(coupled)))

        # The validator's notion of "a reactive law applies" is the builder's.
        for (device, profile) in ((four(ranged_q), volt_var), (three(ranged_q), volt_var),
                                  (four(ranged_q), malformed), (four(ranged_q), nothing),
                                  (four(ranged_q), D("power_factor" => D("pf" => 0.95))),
                                  (three(ranged_q), D("power_factor" => D("pf" => 0.95))))
            net = ibr_net(device; profile)
            ctx = Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
                build_opf_model(net; per_unit=false)
            end
            stamped = any(k -> k.family in (:ibr_q_volt_var, :ibr_power_factor),
                          opf_object_keys(ctx; kind=:constraint))
            law = ext._ibr_reactive_law(net["ibr"]["x"], get(net, "control_profile", D()))
            @test stamped == (law !== nothing)
        end
    end

    @testset "an open switch does not join voltage-base zones" begin
        function bypass(open)
            net = D("bus" => D("hv" => bus2(), "lv" => bus2()),
                "voltage_source" => D("s" => src2("hv"; v=230.0)),
                "transformer" => D("single_phase" => D("t" => xfmr2("hv", "lv", 230.0, 12.0))),
                "load" => D("l" => load2("lv"; p=20.0, q=5.0)))
            open === nothing || (net["switch"] = D("sw" => D("bus_from" => "hv", "bus_to" => "lv",
                "terminal_map_from" => ["p", "n"], "terminal_map_to" => ["p", "n"],
                "open_switch" => open)))
            net
        end
        base(net) = opf_bases(build_opf_model(net; per_unit=true)).v_base["lv"]
        @test base(bypass(nothing)) ≈ 12.0
        @test base(bypass(true)) ≈ 12.0      # open: still an isolated 12 V zone
        @test base(bypass(false)) ≈ 230.0    # closed: one copper zone with the source
        pu = solve_pf(bypass(true); per_unit=true, solver_options=tight)
        si = solve_pf(bypass(true); per_unit=false, solver_options=tight)
        @test solved(pu) && solved(si)
        @test pu["bus"]["lv"]["p"]["vm"] ≈ si["bus"]["lv"]["p"]["vm"] rtol=1e-6
    end

    @testset "branch-current and loss accessors stay separate" begin
        ctx = build_opf_model(mvdc_tie(); per_unit=true)
        # A DC branch has an ohmic loss but no AC conductor-current ledger.
        @test BMOPFTools.opf_element_loss(ctx, "dc_branch", "line") isa JuMP.AbstractJuMPScalar
        @test_throws ArgumentError BMOPFTools.opf_branch_currents(ctx, "dc_branch", "line")
        @test_throws ArgumentError BMOPFTools.opf_neutral_current(ctx, "dc_branch", "line")
        net = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")), "load" => D("l" => load2("t")))
        ac = build_opf_model(net; per_unit=false)
        currents = BMOPFTools.opf_branch_currents(ac, "line", "m")
        @test currents isa Vector && all(c -> c isa Tuple && length(c) == 3, currents)
        @test BMOPFTools.opf_neutral_current(ac, "line", "m") isa Tuple
    end

    # ── 13. Dependent rows are removed only when a static equality implies them ──
    # Each test is paired: the consistent case drops the dependent row and
    # solves; the conflicting or live case keeps the hard constraint.
    one_coil_net(fields; count=1, profile=nothing) = begin
        net = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")),
            "ibr" => D("u$k" => merge(D("bus" => "t", "terminal_map" => ["p", "n"],
                "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
                "s_max" => [8000.0]), fields) for k in 1:count))
        if profile !== nothing
            net["control_profile"] = D("cp" => profile)
            foreach(u -> u["control_profile"] = "cp", values(net["ibr"]))
        end
        net
    end
    family_rows(ctx, family) = count(k -> k.family == family,
                                     opf_object_keys(ctx; kind=:constraint))

    @testset "a live coefficient never makes the DC-link balance redundant" begin
        link = D("dc_link_coupled" => true, "prime_mover" => "STATCOM",
                 "p_min" => [0.0], "p_max" => [0.0],
                 "q_min" => [0.0], "q_max" => [0.0], "cost" => [-1.0])
        # Static: P pinned at zero already implies the zero balance.
        @test family_rows(build_opf_model(one_coil_net(link); per_unit=false),
                          :ibr_dc_power_equality) == 0
        # Live: the same defaults, but p_max is a parameter. The balance stays.
        for pu in (true, false)
            model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(model)
            available = JuMP.@variable(model, set = JuMP.Parameter(0.0))
            spec = OpfBuildSpec(coefficient_providers=Dict(
                OpfCoefficientKey(:availability, :ibr, "u1", :p_max, 1) =>
                    OpfCoefficientProvider(:ReviewTest, (ctx, key, default) -> available)))
            ctx = build_opf_model(one_coil_net(link); model, build_spec=spec, per_unit=pu)
            @test family_rows(ctx, :ibr_dc_power_equality) == 1
            scale = pu ? opf_bases(ctx).s_base : 1.0
            optimize_opf!(ctx)
            JuMP.set_parameter_value(available, 500.0 / scale)
            resolve_opf!(ctx)
            result = extract_result(ctx)
            @test solved(result)
            # The link carries no net active power, whatever the availability.
            @test abs(only(values(result["ibr"]["u1"]))["pg"]) < 1e-3
        end
    end

    @testset "constant power factor is not restated when the boxes imply it" begin
        unity = D("power_factor" => D("pf" => 1.0))
        lagging = D("power_factor" => D("pf" => 0.8))
        pinned(p, q) = D("p_min" => [p], "p_max" => [p], "q_min" => [q], "q_max" => [q])
        rows(net) = family_rows(build_opf_model(net; per_unit=false), :ibr_power_factor)
        # Q pinned at zero under a unity power factor: implied.
        @test rows(one_coil_net(pinned(400.0, 0.0); profile=unity)) == 0
        # P and Q pinned on the 0.8 lagging line (Q = −0.75 P): implied.
        @test rows(one_coil_net(pinned(400.0, -300.0); profile=lagging)) == 0
        # Pinned off the line, or not pinned at all: the law stays and binds.
        @test rows(one_coil_net(pinned(400.0, 300.0); profile=lagging)) == 1
        @test rows(one_coil_net(D("p_min" => [400.0], "p_max" => [400.0],
            "q_min" => [-4000.0], "q_max" => [4000.0]); profile=lagging)) == 1
        conflict = solve_opf(one_coil_net(pinned(400.0, 300.0); profile=lagging))
        @test !solved(conflict)
        # Many fully pinned units under an ordinary unity profile solve.
        for pu in (true, false)
            @test solved(solve_opf(one_coil_net(pinned(400.0, 0.0); count=12, profile=unity);
                                   per_unit=pu))
        end
    end

    dc_station(units; branch=nothing, bus_fields=D()) = begin
        net = D("bus" => D("f" => D("terminal_names" => ["a", "n"],
                    "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => D("s" => D("bus" => "f", "terminal_map" => ["a", "n"],
                "v_magnitude" => [230.0, 0.0], "v_angle" => [0.0, 0.0], "cost" => [1.0])),
            "ibr" => D(id => merge(D("bus" => "f", "terminal_map" => ["a", "n"],
                "topology" => "SINGLE_PHASE", "prime_mover" => "GENERIC",
                "s_max" => [8000.0], "q_min" => [0.0], "q_max" => [0.0],
                "dc_bus" => "dcA", "dc_terminal_map" => ["p", "m"]), fields)
                for (id, fields) in units),
            "dc_bus" => D("dcA" => merge(D("terminal_names" => ["p", "m"],
                "pole" => D("p" => "POSITIVE", "m" => "METALLIC_RETURN"),
                "v_dc_min" => [600.0, 0.0], "v_dc_max" => [1000.0, 0.0]), bus_fields)),
            "dc_grounding" => D("g" => D("dc_bus" => "dcA", "terminal" => "m", "r" => 0.0)))
        branch === nothing || (net["dc_branch"] = D("tie" => branch))
        net
    end
    master(v) = D("dc_control" => "V", "dc_v_set" => v)
    fixed_p(p) = D("p_min" => [p], "p_max" => [p])

    @testset "one voltage reference per DC port" begin
        # Twelve masters agreeing on 800 V: one row, and the build solves with
        # eleven of them dispatched and one balancing.
        units = [("m$k", k == 1 ? master(800.0) : merge(master(800.0), fixed_p(100.0)))
                 for k in 1:12]
        for pu in (true, false)
            ctx = build_opf_model(dc_station(units); per_unit=pu)
            @test family_rows(ctx, :dc_converter_voltage_control) == 1
            result = solve_opf(dc_station(units); per_unit=pu)
            @test solved(result)
            @test result["dc_bus"]["dcA"]["p"]["v_dc"] ≈ 800.0 atol=1e-2
        end
        # Masters that disagree are a data error, not a solver failure.
        @test_throws ArgumentError build_opf_model(
            dc_station([("m1", master(800.0)), ("m2", master(790.0))]))
    end

    @testset "an ideal DC conductor cannot join two different fixed voltages" begin
        # A DC terminal whose v_dc_min equals v_dc_max is a fixed potential.
        function two_bus(v_to)
            net = dc_station([("p1", fixed_p(500.0))];
                bus_fields=D("v_dc_min" => [800.0, 0.0], "v_dc_max" => [800.0, 0.0]))
            net["dc_bus"]["dcB"] = merge(deepcopy(net["dc_bus"]["dcA"]),
                D("v_dc_min" => [v_to, 0.0], "v_dc_max" => [v_to, 0.0]))
            net["dc_grounding"]["gB"] = D("dc_bus" => "dcB", "terminal" => "m", "r" => 0.0)
            net["dc_branch"] = D("tie" => D("dc_bus_from" => "dcA", "dc_bus_to" => "dcB",
                "terminal_map_from" => ["p", "m"], "terminal_map_to" => ["p", "m"],
                "r" => [0.0, 0.0]))
            net
        end
        for pu in (true, false)
            # Equal fixed potentials: the equality holds, so it is omitted.
            ctx = build_opf_model(two_bus(800.0); per_unit=pu)
            @test family_rows(ctx, :dc_branch_voltage_drop) == 0
            # 800 V against 700 V across zero ohms is a contradiction, not a
            # 1 A branch with 100 W of loss.
            @test_throws ArgumentError build_opf_model(two_bus(700.0); per_unit=pu)
        end
    end

    @testset "solve_pf: the DC side must supply the determining equation" begin
        ac(fields) = merge(D("q_min" => [0.0], "q_max" => [0.0]), fields)
        link(lo, hi) = one_coil_net(ac(D("dc_link_coupled" => true,
            "prime_mover" => "STATCOM", "p_dc_min" => lo, "p_dc_max" => hi,
            "p_min" => [-2000.0], "p_max" => [2000.0])))
        # A zero-width private balance determines the one active power.
        @test solved(solve_pf(link(0.0, 0.0)))
        # A balance RANGE determines nothing.
        @test_throws ArgumentError solve_pf(link(-500.0, 500.0))
        ranged = D("p_min" => [-4000.0], "p_max" => [4000.0])
        # One master balances the DC bus; a P-mode unit needs a setpoint.
        @test solved(solve_pf(dc_station([("m1", master(800.0)),
                                          ("p1", fixed_p(500.0))])))
        @test_throws ArgumentError solve_pf(dc_station([("m1", master(800.0)),
                                                        ("p1", ranged)]))
        # Two ranged P-mode units: DC KCL fixes their sum, the split is free.
        @test_throws ArgumentError solve_pf(dc_station([("m1", master(800.0)),
            ("p1", ranged), ("p2", ranged)]))
        # Two free masters on one port share one equation.
        @test_throws ArgumentError solve_pf(dc_station([("m1", master(800.0)),
                                                        ("m2", master(800.0))]))
        @test solved(solve_pf(dc_station([("m1", master(800.0)),
            ("m2", merge(master(800.0), fixed_p(300.0)))])))
    end

    # ── 14. The post-solve validator agrees with the engine ───────────────────
    # `solution_check` re-derives limits from the case, independently of the
    # model. For every semantic this change set touched, the engine's own
    # solution must pass it, and a solution that breaks the rule must not.
    @testset "solution_check mirrors the engine's semantics" begin
        codes(net, result) = (found = Finding[]; solution_check(net, result, found);
                              Set(f.code for f in found))

        # Line angle windows bound phase conductors only.
        buses = D(b => D("terminal_names" => ["a", "b", "c", "n"]) for b in ("src", "b1", "b2"))
        fourwire(bf, bt) = merge(D("bus_from" => bf, "bus_to" => bt,
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to" => ["a", "b", "c", "n"]),
            D("R_series_$(k)_$(k)" => 0.2 for k in 1:4))
        single(bus, ph) = D("bus" => bus, "terminal_map" => [ph, "n"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [3000.0], "q_nom" => [0.0])
        feeder = D("bus" => buses,
            "line" => D("l1" => fourwire("src", "b1"),
                        "l2" => merge(fourwire("b1", "b2"),
                                      D("va_diff_min" => -0.2, "va_diff_max" => 0.2))),
            "voltage_source" => D("vs" => D("bus" => "src", "terminal_map" => ["a", "b", "c"],
                "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3])),
            "load" => D("la" => single("b1", "a"), "lb" => single("b2", "b")))
        result = solve_opf(deepcopy(feeder); per_unit=false)
        @test solved(result)
        @test !("E.SOL.ANGLE_VIOLATION" in codes(feeder, result))
        # A phase conductor outside the window is still caught.
        tight = deepcopy(feeder)
        tight["line"]["l2"]["va_diff_min"] = 0.05; tight["line"]["l2"]["va_diff_max"] = 0.1
        @test "E.SOL.ANGLE_VIOLATION" in codes(tight, result)

        # The AC power balance is not thrown off by DC-branch loss.
        for pu in (true, false)
            net = mvdc_tie()
            result = solve_opf(net; per_unit=pu)
            @test result["losses"]["p_loss_dc"] ≈ result["dc_branch"]["line"]["loss"]["p_loss"] rtol=1e-9
            @test result["losses"]["p_loss_dc"] > 10.0
            @test !("W.SOL.POWER_BALANCE" in codes(net, result))
            # Without the reported share the validator recovers it per branch.
            stripped = deepcopy(result); delete!(stripped["losses"], "p_loss_dc")
            @test !("W.SOL.POWER_BALANCE" in codes(net, stripped))
            # A genuine imbalance is still reported.
            broken = deepcopy(result)
            broken["voltage_source"]["s1"]["a"]["ps"] += 500.0
            @test "W.SOL.POWER_BALANCE" in codes(net, broken)
        end

        # A two-terminal DELTA generator: one coil, tighter rating governs.
        line4 = merge(D("bus_from" => "src", "bus_to" => "b1",
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to" => ["a", "b", "c", "n"]),
            D("R_series_$(k)_$(k)" => 0.2 for k in 1:4))
        gen_case(i_max) = D("bus" => D(b => D("terminal_names" => ["a", "b", "c", "n"])
                                       for b in ("src", "b1")),
            "voltage_source" => D("vs" => D("bus" => "src", "terminal_map" => ["a", "b", "c"],
                "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3])),
            "line" => D("l1" => line4),
            "generator" => D("g" => D("bus" => "b1", "terminal_map" => ["a", "b"],
                "configuration" => "DELTA", "p_min" => [1000.0], "p_max" => [1000.0],
                "q_min" => [0.0], "q_max" => [0.0], "i_max" => i_max)))
        result = solve_opf(gen_case([5.0, 5.0]); per_unit=false)     # about 2.5 A
        @test solved(result)
        @test !("E.SOL.GEN_VIOLATION" in codes(gen_case([5.0, 5.0]), result))
        # The same solution against a tighter rating on EITHER conductor.
        @test "E.SOL.GEN_VIOLATION" in codes(gen_case([1.0, 5.0]), result)
        @test "E.SOL.GEN_VIOLATION" in codes(gen_case([5.0, 1.0]), result)

        # Volt-watt P_AVAILABLE is shared per coil for a phase-to-phase unit.
        pv = D("bus" => D(b => D("terminal_names" => ["a", "b", "n"],
                                 "perfectly_grounded_terminals" => ["n"]) for b in ("src", "e")),
            "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                "terminal_map_from" => ["a", "b", "n"], "terminal_map_to" => ["a", "b", "n"]),
                D("R_series_$(k)_$(k)" => 0.01 for k in 1:3))),
            "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a", "b"],
                "v_magnitude" => [120.0, 120.0], "v_angle" => [0.0, Float64(pi)],
                "cost" => [0.2, 0.2])),
            "ibr" => D("pv" => D("bus" => "e", "terminal_map" => ["a", "b"],
                "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
                "p_min" => [0.0], "p_max" => [6000.0], "p_avail" => 6000.0,
                "q_min" => [0.0], "q_max" => [0.0], "s_max" => [8000.0],
                "cost" => [-1.0], "control_profile" => "cp")),
            "control_profile" => D("cp" => D("volt_watt" => D(
                "voltage_reference" => "PG_PER_PHASE",
                "breakpoints" => [200.0, 210.0], "p_limits" => [0.2, 1.0],
                "p_unit" => "VA_FRACTION", "p_ref" => "P_AVAILABLE"))))
        result = solve_opf(deepcopy(pv); per_unit=false)
        @test solved(result)
        @test only(values(result["ibr"]["pv"]))["pg"] ≈ 6000.0 rtol=2e-2
        @test !any(startswith(code, "E.SOL") for code in codes(pv, result))
    end

    # ── 15. Third review: equivalence, resolved coefficients, coil indexing ──
    @testset "DC voltage masters are grouped by electrical equivalence" begin
        # Twelve buses whose poles are joined by zero-ohm ties and whose
        # returns are all grounded: one electrical port.
        function ring(units; r=0.0)
            net = D("bus" => D("f" => D("terminal_names" => ["a", "n"],
                        "perfectly_grounded_terminals" => ["n"])),
                "voltage_source" => D("s" => D("bus" => "f", "terminal_map" => ["a", "n"],
                    "v_magnitude" => [230.0, 0.0], "v_angle" => [0.0, 0.0], "cost" => [1.0])),
                "ibr" => D(), "dc_bus" => D(),
                "dc_grounding" => D(), "dc_branch" => D())
            for (k, fields) in enumerate(units)
                net["dc_bus"]["d$k"] = D("terminal_names" => ["p", "m"],
                    "pole" => D("p" => "POSITIVE", "m" => "METALLIC_RETURN"),
                    "v_dc_min" => [600.0, 0.0], "v_dc_max" => [1000.0, 0.0])
                net["dc_grounding"]["g$k"] = D("dc_bus" => "d$k", "terminal" => "m", "r" => 0.0)
                net["ibr"]["m$k"] = merge(D("bus" => "f", "terminal_map" => ["a", "n"],
                    "topology" => "SINGLE_PHASE", "prime_mover" => "GENERIC",
                    "s_max" => [8000.0], "q_min" => [0.0], "q_max" => [0.0],
                    "dc_bus" => "d$k", "dc_terminal_map" => ["p", "m"],
                    "dc_control" => "V", "dc_v_set" => 800.0), fields)
                k > 1 && (net["dc_branch"]["t$k"] = D("dc_bus_from" => "d$(k-1)",
                    "dc_bus_to" => "d$k", "terminal_map_from" => ["p"],
                    "terminal_map_to" => ["p"], "r" => [r]))
            end
            net
        end
        dispatched = [k == 1 ? D() : fixed_p(100.0) for k in 1:12]
        for pu in (true, false)
            ctx = build_opf_model(ring(dispatched); per_unit=pu)
            @test family_rows(ctx, :dc_converter_voltage_control) == 1
            @test solved(solve_opf(ring(dispatched); per_unit=pu))
            @test solved(solve_pf(ring(dispatched); per_unit=pu))
        end
        # Two free masters at opposite ends of an ideal tie share one equation.
        @test_throws ArgumentError solve_pf(ring([D(), D()]))
        # A resistive tie separates the ports: each master fixes its own bus.
        @test family_rows(build_opf_model(ring([D(), D()]; r=0.5); per_unit=false),
                          :dc_converter_voltage_control) == 2
        @test solved(solve_pf(ring([D(), D()]; r=0.5)))
        # Masters that disagree across an ideal tie are a data error.
        clash = ring([D(), D("dc_v_set" => 790.0)])
        @test_throws ArgumentError build_opf_model(clash)
    end

    @testset "solve_pf validates the resolved dispatch" begin
        fixed = D("p_min" => [0.0], "p_max" => [0.0], "q_min" => [0.0], "q_max" => [0.0])
        widen(value) = OpfBuildSpec(coefficient_providers=Dict(
            OpfCoefficientKey(:availability, :ibr, "u1", :p_max, 1) =>
                OpfCoefficientProvider(:ReviewTest, (ctx, key, default) -> value(default))))
        # The case says P is fixed at zero; a provider that widens it does not
        # leave a power flow.
        @test_throws ArgumentError solve_pf(one_coil_net(fixed);
            build_spec=widen(default -> default + 500.0), per_unit=false)
        # A provider that leaves the setpoint fixed is fine.
        @test solved(solve_pf(one_coil_net(fixed); build_spec=widen(identity)))
        @test solved(solve_pf(one_coil_net(fixed)))
    end

    @testset "flat Volt-var over a pinned reactive box is not restated" begin
        flat = D("volt_var" => D("voltage_reference" => "PG_PER_PHASE",
            "breakpoints" => [207.0, 220.0, 240.0, 253.0], "q_limits" => [0.0, 0.0],
            "q_unit" => "VA_FRACTION", "q_ref" => "VAR_MAX"))
        sloped = D("volt_var" => merge(flat["volt_var"], D("q_limits" => [-0.44, 0.44])))
        pinned = D("p_min" => [400.0], "p_max" => [400.0], "q_min" => [0.0], "q_max" => [0.0])
        rows(net) = family_rows(build_opf_model(net; per_unit=false), :ibr_q_volt_var)
        @test rows(one_coil_net(pinned; profile=flat)) == 0
        @test rows(one_coil_net(pinned; profile=sloped)) == 1      # a real law stays
        @test rows(one_coil_net(D("p_min" => [400.0], "p_max" => [400.0],
            "q_min" => [-100.0], "q_max" => [100.0]); profile=flat)) == 1
        for pu in (true, false)
            @test solved(solve_opf(one_coil_net(pinned; count=12, profile=flat); per_unit=pu))
        end
    end

    @testset "solution_check: derived DC share, coil indexing, terminal roles" begin
        report(net, result) = (found = Finding[]; out = solution_check(net, result, found);
                               (codes=Set(f.code for f in found), findings=found, out=out))
        unassessed(r) = any(f -> f.code == "W.SOL.LIMIT_UNASSESSED", r.findings)
        incomplete(r) = any(f -> haskey(f.detail, "missing_fields"), r.findings)

        # A result cannot repair its own balance by declaring a DC loss share.
        ac = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")), "load" => D("l" => load2("t")))
        result = solve_opf(deepcopy(ac); per_unit=false)
        @test !("W.SOL.POWER_BALANCE" in report(ac, result).codes)
        broken = deepcopy(result); broken["voltage_source"]["s"]["p"]["ps"] -= 500.0
        @test "W.SOL.POWER_BALANCE" in report(ac, broken).codes
        broken["losses"]["p_loss_dc"] = 500.0
        @test "W.SOL.POWER_BALANCE" in report(ac, broken).codes

        # Line-to-line devices have ONE power record; the result is complete.
        ll_bus() = D("terminal_names" => ["a", "b", "n"], "perfectly_grounded_terminals" => ["n"])
        function ll_net(device_family, device)
            D("bus" => D("src" => ll_bus(), "e" => ll_bus()),
              "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                  "terminal_map_from" => ["a", "b", "n"], "terminal_map_to" => ["a", "b", "n"]),
                  D("R_series_$(k)_$(k)" => 0.01 for k in 1:3))),
              "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a", "b"],
                  "v_magnitude" => [120.0, 120.0], "v_angle" => [0.0, Float64(pi)],
                  "cost" => [0.2, 0.2])),
              device_family => D("x" => device))
        end
        pq = D("p_min" => [1000.0], "p_max" => [1000.0], "q_min" => [0.0], "q_max" => [0.0])
        cases = (
            ("generator", merge(D("bus" => "e", "terminal_map" => ["a", "b"],
                                  "configuration" => "DELTA"), pq)),
            ("load", D("bus" => "e", "terminal_map" => ["a", "b"], "configuration" => "DELTA",
                       "p_nom" => [1000.0], "q_nom" => [0.0])),
            ("load", D("bus" => "e", "terminal_map" => ["a", "b"],
                       "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [0.0])),
            ("ibr", merge(D("bus" => "e", "terminal_map" => ["a", "b"],
                            "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
                            "s_max" => [8000.0]), pq)))
        for (family, device) in cases
            net = ll_net(family, device)
            result = solve_opf(deepcopy(net); per_unit=false)
            @test solved(result)
            checked = report(net, result)
            @test !incomplete(checked)
            @test !any(startswith(code, "E.") for code in checked.codes)
        end
        # Integrity accepts the one-entry bounds of a two-terminal DELTA generator.
        found = Finding[]; integrity_check(ll_net(cases[1]...), found)
        @test !any(f -> f.code == "W.INT.DIM_MISMATCH" && f.component_id == "x", found)

        # A declared neutral label that no naming guess would find.
        named = D("terminal_conventions" => D("phase" => ["a", "b", "c"],
                                             "neutral" => ["return"], "earth" => String[]),
            "bus" => D(b => D("terminal_names" => ["a", "b", "c", "return"],
                              "perfectly_grounded_terminals" => ["return"]) for b in ("src", "e")),
            "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                "terminal_map_from" => ["a", "b", "c", "return"],
                "terminal_map_to" => ["a", "b", "c", "return"]),
                D("R_series_$(k)_$(k)" => 0.01 for k in 1:4))),
            "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a", "b", "c"],
                "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2pi/3, 2pi/3],
                "cost" => fill(0.2, 3))),
            "ibr" => D("pv" => D("bus" => "e", "terminal_map" => ["a", "b", "c", "return"],
                "topology" => "FOUR_LEG", "prime_mover" => "PV",
                "p_min" => zeros(3), "p_max" => fill(6000.0, 3), "p_avail" => 6000.0,
                "q_min" => zeros(3), "q_max" => zeros(3), "s_max" => fill(8000.0, 3),
                "cost" => fill(-1.0, 3), "control_profile" => "cp")),
            "control_profile" => D("cp" => D("volt_watt" => D(
                "voltage_reference" => "PG_PER_PHASE",
                "breakpoints" => [300.0, 310.0], "p_limits" => [0.2, 1.0],
                "p_unit" => "VA_FRACTION", "p_ref" => "P_AVAILABLE"))))
        result = solve_opf(deepcopy(named); per_unit=false)
        @test solved(result)
        # Three coils share the 6 kW: 2 kW each, in the engine and the validator.
        @test all(coil -> isapprox(coil["pg"], 2000.0; rtol=2e-2), values(result["ibr"]["pv"]))
        @test !any(startswith(code, "E.SOL") for code in report(named, result).codes)

        # A protective-earth conductor is not angle-bounded, by either side.
        pe = D("terminal_conventions" => D("phase" => ["a"], "neutral" => ["n"], "earth" => ["pe"]),
            "bus" => D(b => D("terminal_names" => ["a", "n", "pe"],
                              "perfectly_grounded_terminals" => ["pe"]) for b in ("src", "e")),
            "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                "terminal_map_from" => ["a", "n", "pe"], "terminal_map_to" => ["a", "n", "pe"],
                "va_diff_min" => -0.2, "va_diff_max" => 0.2),
                D("R_series_$(k)_$(k)" => 0.05 for k in 1:3))),
            "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a"],
                "v_magnitude" => [230.0], "v_angle" => [0.0])),
            "load" => D("l" => D("bus" => "e", "terminal_map" => ["a", "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [2000.0], "q_nom" => [0.0])))
        ctx = build_opf_model(deepcopy(pe); per_unit=false)
        angle_rows = [k.index for k in opf_object_keys(ctx; kind=:constraint)
                      if startswith(string(k.family), "line_angle_")]
        @test Set(index[2] for index in angle_rows) == Set([1])    # the phase only
        result = solve_opf(deepcopy(pe); per_unit=false)
        @test solved(result)
        @test !unassessed(report(pe, result))
    end

    # ── 16. Fourth review ─────────────────────────────────────────────────────
    @testset "a declared phase label is a phase, whatever its name" begin
        # Two phases, one of them called "n". With roles declared, the naming
        # convention must not turn it into a neutral.
        # The source bus uses ordinary names; the oddly named phase lives on the
        # load bus, so only the angle predicate is under test here. (Source-bus
        # grounding has its own naming fallback, outside this test.)
        function two_phase(second; declared=true)
            net = D("bus" => D("src" => D("terminal_names" => ["a", "b"]),
                               "e" => D("terminal_names" => ["a", second])),
                "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                    "terminal_map_from" => ["a", "b"], "terminal_map_to" => ["a", second],
                    "va_diff_min" => 0.05, "va_diff_max" => 0.10),
                    D("R_series_$(k)_$(k)" => 0.05 for k in 1:2))),
                "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a", "b"],
                    "v_magnitude" => [230.0, 230.0], "v_angle" => [0.0, Float64(pi)])),
                "load" => D("l" => D("bus" => "e", "terminal_map" => ["a", second],
                    "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [0.0])))
            declared && (net["terminal_conventions"] = D(
                "phase" => unique(["a", "b", second]), "neutral" => String[], "earth" => String[]))
            net
        end
        angle_conductors(net) = Set(k.index[2] for k in opf_object_keys(
            build_opf_model(net; per_unit=false); kind=:constraint)
            if startswith(string(k.family), "line_angle_"))
        # The window cannot be met (the drop is resistive, so the angle shift is
        # ~0 rad against a required [0.05, 0.10]); what matters is that it is
        # ENFORCED on both phases under either name.
        @test angle_conductors(two_phase("b")) == Set([1, 2])
        @test angle_conductors(two_phase("n")) == Set([1, 2])
        @test !solved(solve_opf(two_phase("n"); per_unit=false))
        @test !solved(solve_opf(two_phase("b"); per_unit=false))
        # The validator applies the same rule to a supplied solution.
        relaxed = two_phase("n"); delete!(relaxed["line"]["l"], "va_diff_min")
        delete!(relaxed["line"]["l"], "va_diff_max")
        result = solve_opf(relaxed; per_unit=false)
        found = Finding[]; solution_check(two_phase("n"), result, found)
        @test count(f -> f.code == "E.SOL.ANGLE_VIOLATION", found) == 2
    end

    @testset "DC voltage references: cycles, consistency, free circulation" begin
        # A bipolar bus with masters on p−m, m−n and p−n: three references,
        # two of them independent.
        function bipolar(units)
            D("bus" => D("f" => D("terminal_names" => ["a", "n"],
                        "perfectly_grounded_terminals" => ["n"])),
              "voltage_source" => D("s" => D("bus" => "f", "terminal_map" => ["a", "n"],
                  "v_magnitude" => [230.0, 0.0], "v_angle" => [0.0, 0.0], "cost" => [1.0])),
              "ibr" => D(id => merge(D("bus" => "f", "terminal_map" => ["a", "n"],
                  "topology" => "SINGLE_PHASE", "prime_mover" => "GENERIC",
                  "s_max" => [8000.0], "q_min" => [0.0], "q_max" => [0.0],
                  "dc_bus" => "dc", "dc_control" => "V"), fields) for (id, fields) in units),
              "dc_bus" => D("dc" => D("terminal_names" => ["p", "m", "n"],
                  "pole" => D("p" => "POSITIVE", "m" => "METALLIC_RETURN", "n" => "NEGATIVE"),
                  "v_dc_min" => [600.0, 0.0, -1000.0], "v_dc_max" => [1000.0, 0.0, -600.0])),
              "dc_grounding" => D("g" => D("dc_bus" => "dc", "terminal" => "m", "r" => 0.0)))
        end
        port(a, b, v) = D("dc_terminal_map" => [a, b], "dc_v_set" => v)
        triangle(extra...) = [("pm", merge(port("p", "m", 800.0), extra[1])),
                              ("mn", merge(port("m", "n", 800.0), extra[2])),
                              ("pn", merge(port("p", "n", 1600.0), extra[3]))]
        free = (D(), D(), D())
        for pu in (true, false)
            ctx = build_opf_model(bipolar(triangle(free...)); per_unit=pu)
            @test family_rows(ctx, :dc_converter_voltage_control) == 2
        end
        # Inconsistent third side: a contradiction, reported at build time.
        bad = triangle(free...); bad[3] = ("pn", port("p", "n", 1500.0))
        @test_throws ArgumentError build_opf_model(bipolar(bad))
        # Three free masters around the triangle can circulate power.
        @test_throws ArgumentError solve_pf(bipolar(triangle(free...)))
        # Pinning one breaks the loop: the other two are determined.
        @test solved(solve_pf(bipolar(triangle(D(), D(), fixed_p(200.0)))))
    end

    @testset "solve_pf counts free DC dispatch in the built model" begin
        # Two masters on one port. In the case, one is pinned at zero.
        units = [("m1", master(800.0)), ("m2", merge(master(800.0), fixed_p(0.0)))]
        @test solved(solve_pf(dc_station(units)))
        widen = OpfBuildSpec(coefficient_providers=Dict(
            OpfCoefficientKey(:availability, :ibr, "m2", :p_max, 1) =>
                OpfCoefficientProvider(:ReviewTest, (ctx, key, default) -> default + 500.0)))
        # A provider that widens m2 leaves two free masters on one port.
        @test_throws ArgumentError solve_pf(dc_station(units); build_spec=widen, per_unit=false)
        # A standalone DC source must be a fixed injection.
        with_source(fields) = (net = dc_station([("m1", master(800.0))]);
            net["dc_source"] = D("pv" => merge(D("dc_bus" => "dcA",
                "terminal_map" => ["p", "m"]), fields)); net)
        @test solved(solve_pf(with_source(D("p" => 300.0))))
        @test solved(solve_pf(with_source(D("p_min" => 300.0, "p_max" => 300.0))))
        @test_throws ArgumentError solve_pf(with_source(D("p_min" => 0.0, "p_max" => 500.0)))
        @test_throws ArgumentError solve_pf(with_source(D("p_max" => 500.0)))
    end

    # A device owned by a custom builder stamps its own rows under its own
    # keys; the native-row check must leave it alone. (The mock builder is
    # loaded by opf_tests.jl in the full suite.)
    if isdefined(Main, :MockOpfExtension)
        @testset "solve_pf leaves custom-owned devices to their builder" begin
            net = one_coil_net(D("p_min" => [100.0], "p_max" => [100.0],
                                 "q_min" => [0.0], "q_max" => [0.0]))
            owned = Dict{Tuple{Symbol,String},Any}((:ibr, "u1") => Main.MockOpfExtension.builder())
            identity_provider = Dict(
                OpfCoefficientKey(:availability, :ibr, "u1", :p_max, 1) =>
                    OpfCoefficientProvider(:ReviewTest, (ctx, key, default) -> default))
            for providers in (Dict{OpfCoefficientKey,OpfCoefficientProvider}(), identity_provider)
                spec = OpfBuildSpec(component_builders=owned, coefficient_providers=providers)
                result = solve_pf(deepcopy(net); build_spec=spec, per_unit=false)
                @test solved(result)
            end
        end
    end

    @testset "solution_check reports missing DC evidence" begin
        net = mvdc_tie()
        net["dc_branch"]["line"]["i_max"] = [1.0, 1.0]       # far below the solved current
        result = solve_opf(mvdc_tie())
        report(candidate) = (found = Finding[]; solution_check(net, candidate, found); found)
        @test any(f -> f.code == "E.SOL.DC_THERMAL_VIOLATION", report(result))
        # Deleting the scalars the check reads must not turn a failure into a pass.
        hollow = deepcopy(result)
        delete!(hollow["dc_branch"]["line"]["1"], "i_dc")
        delete!(hollow["dc_bus"]["dcA"]["p"], "v_dc")
        found = report(hollow)
        incomplete = [f for f in found if f.code == "W.SOL.INCOMPLETE_RESULT"]
        @test length(incomplete) == 1
        @test "dc_branch.line.1.i_dc" in only(incomplete).detail["missing_fields"]
        @test "dc_bus.dcA.p.v_dc" in only(incomplete).detail["missing_fields"]
    end

    # ── 17. Fifth review ──────────────────────────────────────────────────────
    @testset "a loop of ideal DC conductors is rejected" begin
        # Three DC buses whose poles are joined by zero-ohm conductors.
        function poles(edges; r=0.0)
            net = dc_station([("m1", master(800.0))])
            for b in ("dcB", "dcC")
                net["dc_bus"][b] = deepcopy(net["dc_bus"]["dcA"])
                net["dc_grounding"]["g$b"] = D("dc_bus" => b, "terminal" => "m", "r" => 0.0)
            end
            net["dc_branch"] = D("t$k" => D("dc_bus_from" => a, "dc_bus_to" => b,
                "terminal_map_from" => ["p"], "terminal_map_to" => ["p"], "r" => [r])
                for (k, (a, b)) in enumerate(edges))
            net
        end
        tree = [("dcA", "dcB"), ("dcB", "dcC")]
        ring = vcat(tree, [("dcC", "dcA")])
        @test solved(solve_opf(poles(tree)))                       # a tree is fine
        @test_throws ArgumentError build_opf_model(poles(ring))     # a loop is not
        @test solved(solve_opf(poles(ring; r=0.1)))                 # resistive loop: fine
        # An ideal path between two terminals fixed at one potential closes the
        # same kind of loop through their references.
        pinned = poles(tree)
        for b in ("dcA", "dcC")
            pinned["dc_bus"][b]["v_dc_min"] = [800.0, 0.0]
            pinned["dc_bus"][b]["v_dc_max"] = [800.0, 0.0]
        end
        @test_throws ArgumentError build_opf_model(pinned)
    end

    @testset "fixed DC terminal voltages seed the reference graph" begin
        pin(net, v) = (net["dc_bus"]["dcA"]["v_dc_min"] = [v, 0.0];
                       net["dc_bus"]["dcA"]["v_dc_max"] = [v, 0.0]; net)
        masters = [("m$k", k == 1 ? master(800.0) : merge(master(800.0), fixed_p(100.0)))
                   for k in 1:12]
        for pu in (true, false)
            # The pole is already fixed at 800 V: every master row is implied.
            ctx = build_opf_model(pin(dc_station(masters), 800.0); per_unit=pu)
            @test family_rows(ctx, :dc_converter_voltage_control) == 0
            @test solved(solve_opf(pin(dc_station(masters), 800.0); per_unit=pu))
        end
        # A master that contradicts the fixed pole is reported at build time.
        @test_throws ArgumentError build_opf_model(pin(dc_station(masters), 790.0))
    end

    @testset "declared terminal roles govern source-bus grounding" begin
        # A two-phase source whose second phase is called "n".
        function source_case(second)
            D("terminal_conventions" => D("phase" => unique(["a", second]),
                                          "neutral" => String[], "earth" => String[]),
              "bus" => D(b => D("terminal_names" => ["a", second]) for b in ("src", "e")),
              "line" => D("l" => merge(D("bus_from" => "src", "bus_to" => "e",
                  "terminal_map_from" => ["a", second], "terminal_map_to" => ["a", second]),
                  D("R_series_$(k)_$(k)" => 0.05 for k in 1:2))),
              "voltage_source" => D("s" => D("bus" => "src", "terminal_map" => ["a", second],
                  "v_magnitude" => [230.0, 230.0], "v_angle" => [0.0, Float64(pi)])),
              "load" => D("l" => D("bus" => "e", "terminal_map" => ["a", second],
                  "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [0.0])))
        end
        reference = solve_opf(source_case("b"); per_unit=false)
        named = solve_opf(source_case("n"); per_unit=false)
        @test solved(reference) && solved(named)
        @test named["bus"]["src"]["n"]["vm"] ≈ 230.0 atol=1e-6      # a phase, not a ground
        @test named["bus"]["e"]["n"]["vm"] ≈ reference["bus"]["e"]["b"]["vm"] rtol=1e-8
        @test isempty(named["ground"])
        # Without a declaration the naming convention still applies.
        inferred = source_case("n"); delete!(inferred, "terminal_conventions")
        @test_throws ArgumentError build_opf_model(inferred)
    end

    @testset "solution_check: DC loss from resistance, typed evidence" begin
        report(net, candidate) = (found = Finding[]; out = solution_check(net, candidate, found);
                                  (found=found, out=out, codes=Set(f.code for f in found)))
        # An AC imbalance cannot be cancelled by a claimed drop across a
        # zero-ohm DC conductor.
        net = mvdc_tie(); net["dc_branch"]["line"]["r"] = [0.0, 0.0]
        result = solve_opf(deepcopy(net))
        @test solved(result)
        @test !("W.SOL.POWER_BALANCE" in report(net, result).codes)
        forged = deepcopy(result)
        forged["voltage_source"]["s1"]["a"]["ps"] -= 500.0
        @test "W.SOL.POWER_BALANCE" in report(net, forged).codes
        forged["dc_bus"]["dcB"]["p"]["v_dc"] = forged["dc_bus"]["dcA"]["p"]["v_dc"] - 50.0
        forged["dc_branch"]["line"]["1"]["i_dc"] = 10.0
        checked = report(net, forged)
        @test checked.out["verification_status"] == "failed"
        @test "W.SOL.DC_OHM_RESIDUAL" in checked.codes

        # Missing or malformed DC evidence: indeterminate, never an error and
        # never a failed balance on a guessed zero.
        lossy = mvdc_tie()
        good = solve_opf(deepcopy(lossy))
        @test report(lossy, good).out["verification_status"] == "checks_passed"
        for damage! in (r -> delete!(r["dc_branch"]["line"]["1"], "i_dc"),
                        r -> (r["dc_branch"]["line"]["1"]["i_dc"] = nothing),
                        r -> (r["dc_branch"]["line"]["1"] = nothing),
                        r -> (r["dc_bus"]["dcA"]["p"]["v_dc"] = nothing),
                        r -> (r["dc_bus"]["dcA"] = nothing))
            hollow = deepcopy(good); damage!(hollow)
            checked = report(lossy, hollow)
            @test checked.out["verification_status"] == "indeterminate"
            @test !("W.SOL.POWER_BALANCE" in checked.codes)
            @test checked.out["power_balance_assessed"] == false
        end
    end

    # ── 18. Finding codes for what the builders reject ───────────────────────
    # Each code is exercised positively, negatively and at a boundary, agrees
    # with the builder it mirrors, and survives the JSON report.
    @testset "finding codes for ideal topology and reference conflicts" begin
        integrity_codes(net) = (found = Finding[]; integrity_check(net, found); found)
        has(found, code) = any(f -> f.code == code, found)
        builds(net) = try build_opf_model(deepcopy(net); per_unit=false); true
                      catch err; err isa ArgumentError ? false : rethrow() end

        # DC ideal loops: tree (negative), loop (positive), resistive loop
        # (negative), path between two fixed terminals (boundary).
        function poles(edges; r=0.0)
            net = dc_station([("m1", master(800.0))])
            for b in ("dcB", "dcC")
                net["dc_bus"][b] = deepcopy(net["dc_bus"]["dcA"])
                net["dc_grounding"]["g$b"] = D("dc_bus" => b, "terminal" => "m", "r" => 0.0)
            end
            net["dc_branch"] = D("t$k" => D("dc_bus_from" => a, "dc_bus_to" => b,
                "terminal_map_from" => ["p"], "terminal_map_to" => ["p"], "r" => [r])
                for (k, (a, b)) in enumerate(edges))
            net
        end
        tree = [("dcA", "dcB"), ("dcB", "dcC")]; ring = vcat(tree, [("dcC", "dcA")])
        pinned = poles(tree)
        for b in ("dcA", "dcC")
            pinned["dc_bus"][b]["v_dc_min"] = [800.0, 0.0]
            pinned["dc_bus"][b]["v_dc_max"] = [800.0, 0.0]
        end
        for (net, expected) in ((poles(tree), false), (poles(ring), true),
                                (poles(ring; r=0.1), false), (pinned, true))
            found = integrity_codes(net)
            @test has(found, "E.INT.DC_IDEAL_LOOP") == expected
            @test builds(net) == !expected          # validation and builder agree
        end
        loop = only(f for f in integrity_codes(poles(ring)) if f.code == "E.INT.DC_IDEAL_LOOP")
        @test loop.component_id == "t3" && loop.detail["conductor"] == 1
        @test loop.detail["closes_through_fixed_terminals"] == false
        boundary = only(f for f in integrity_codes(pinned) if f.code == "E.INT.DC_IDEAL_LOOP")
        @test boundary.detail["closes_through_fixed_terminals"] == true

        # AC ideal loops: one closed switch (negative), two in parallel
        # (positive), one of them open (boundary), a zero-impedance line in
        # parallel with a closed switch (positive).
        function ac(switches; ideal_line=false)
            net = D("bus" => D("f" => bus2(), "t" => bus2()),
                "voltage_source" => D("s" => src2("f")),
                "line" => D("m" => line2("f", "t"; r=ideal_line ? 0.0 : 0.05,
                                         x=ideal_line ? 0.0 : 0.03)),
                "load" => D("l" => load2("t")),
                "switch" => D("s$k" => D("bus_from" => "f", "bus_to" => "t",
                    "terminal_map_from" => ["p"], "terminal_map_to" => ["p"],
                    "open_switch" => open) for (k, open) in enumerate(switches)))
            net
        end
        for (net, expected) in ((ac([false]), false), (ac([false, false]), true),
                                (ac([false, true]), false),
                                (ac([false]; ideal_line=true), true))
            @test has(integrity_codes(net), "E.INT.IDEAL_LOOP") == expected
            @test builds(net) == !expected
        end

        # DC reference conflicts: agreeing masters (negative), disagreeing
        # masters (positive), a master against a fixed pole (positive), an
        # inconsistent triangle (positive), a consistent one (boundary).
        pin(net, v) = (net["dc_bus"]["dcA"]["v_dc_min"] = [v, 0.0];
                       net["dc_bus"]["dcA"]["v_dc_max"] = [v, 0.0]; net)
        two(v) = dc_station([("m1", master(800.0)), ("m2", merge(master(v), fixed_p(0.0)))])
        for (net, expected) in ((two(800.0), false), (two(790.0), true),
                                (pin(dc_station([("m1", master(800.0))]), 800.0), false),
                                (pin(dc_station([("m1", master(800.0))]), 790.0), true))
            @test has(integrity_codes(net), "E.INT.DC_REFERENCE_CONFLICT") == expected
            @test builds(net) == !expected
        end
        clash = only(f for f in integrity_codes(two(790.0))
                     if f.code == "E.INT.DC_REFERENCE_CONFLICT")
        @test clash.component_id == "m2" && clash.detail["kind"] == "voltage_master"
        @test clash.detail["stated_V"] == 790.0 && clash.detail["implied_V"] == 800.0
    end

    @testset "finding codes for inapplicable bus limits and phase names" begin
        domain_codes(net) = (found = Finding[]; domain_rules_check(net, found); found)
        fields(found) = sort!(vcat([f.detail["fields"] for f in found
                                    if f.code == "W.DOM.BUS_LIMIT_NOT_APPLICABLE"]...))
        bus(terminals; limits...) = merge(D("terminal_names" => terminals),
                                          D(string(k) => v for (k, v) in limits))
        net(b) = D("bus" => D("b" => b))
        # Three phases with a neutral: every limit applies.
        @test isempty(fields(domain_codes(net(bus(["a", "b", "c", "n"];
            vneg_max=5.0, vuf_max=0.02, vpn_min=fill(207.0, 3))))))
        # Two phases: sequence limits do not apply; phase-to-neutral still does.
        @test fields(domain_codes(net(bus(["a", "b", "n"];
            vneg_max=5.0, vuf_max=0.02, vpn_min=fill(207.0, 2))))) == ["vneg_max", "vuf_max"]
        # Three phases, no neutral: phase-to-neutral does not apply; sequence does.
        @test fields(domain_codes(net(bus(["a", "b", "c"];
            vneg_max=5.0, vpn_max=fill(253.0, 3))))) == ["vpn_max"]
        # No such limits at all: nothing to report.
        @test isempty(fields(domain_codes(net(bus(["a", "n"]; v_min=[207.0])))))

        named(labels; neutral=String[]) = D("terminal_conventions" =>
                D("phase" => labels, "neutral" => neutral, "earth" => String[]),
            "bus" => D("b" => D("terminal_names" => vcat(labels, neutral))))
        lookalike(n) = [f for f in domain_codes(n) if f.code == "W.CONV.PHASE_NAMED_AS_NEUTRAL"]
        @test only(lookalike(named(["a", "n"]))).detail["labels"] == ["n"]
        @test isempty(lookalike(named(["a", "b"]; neutral=["n"])))      # n declared neutral
        @test isempty(lookalike(named(["a", "b"])))                     # ordinary names
        # Inferred roles never raise it: there is no declaration to contradict.
        @test isempty(lookalike(D("bus" => D("b" => D("terminal_names" => ["a", "n"])))))
    end

    @testset "new finding codes are registered and serialize" begin
        new_codes = ("E.INT.IDEAL_LOOP", "E.INT.DC_IDEAL_LOOP", "E.INT.DC_REFERENCE_CONFLICT",
                     "W.SOL.DC_OHM_RESIDUAL", "W.SOL.DC_LOSS_SHARE_MISMATCH",
                     "W.DOM.BUS_LIMIT_NOT_APPLICABLE", "W.CONV.PHASE_NAMED_AS_NEUTRAL")
        for code in new_codes
            entry = explain_finding(code)
            @test entry["code"] == code
            @test entry["severity"] == (startswith(code, "E.") ? "ERROR" : "WARNING")
        end
        # End to end through analyze and the JSON report.
        net = dc_station([("m1", master(800.0)), ("m2", merge(master(790.0), fixed_p(0.0)))])
        net["bus"]["f"]["vneg_max"] = 5.0
        report = analyze(net)
        codes = Set(f.code for f in report.findings)
        @test "E.INT.DC_REFERENCE_CONFLICT" in codes
        @test "W.DOM.BUS_LIMIT_NOT_APPLICABLE" in codes
        io = IOBuffer(); BMOPFTools.render_json(report, io)
        parsed = JSON3.read(String(take!(io)))
        serialized = Set(String(f.code) for f in parsed.findings)
        @test "E.INT.DC_REFERENCE_CONFLICT" in serialized
        @test "W.DOM.BUS_LIMIT_NOT_APPLICABLE" in serialized
        # The two validator codes carry structured evidence, not a reason string.
        forged_net = mvdc_tie(); forged_net["dc_branch"]["line"]["r"] = [0.0, 0.0]
        forged = solve_opf(deepcopy(forged_net))
        forged["dc_bus"]["dcB"]["p"]["v_dc"] = forged["dc_bus"]["dcA"]["p"]["v_dc"] - 50.0
        forged["dc_branch"]["line"]["1"]["i_dc"] = 10.0
        forged["losses"]["p_loss_dc"] = 500.0
        found = Finding[]; solution_check(forged_net, forged, found)
        ohm = only(f for f in found if f.code == "W.SOL.DC_OHM_RESIDUAL")
        @test ohm.detail["reported_drop_V"] ≈ 50.0 && ohm.detail["expected_drop_V"] == 0.0
        share = only(f for f in found if f.code == "W.SOL.DC_LOSS_SHARE_MISMATCH")
        @test share.detail["reported_p_loss_dc"] == 500.0 && share.detail["derived_p_loss_dc"] == 0.0
    end

    @testset "unsupported IBR records are rejected, not skipped" begin
        net = D("bus" => D("f" => bus2(), "t" => bus2()),
            "voltage_source" => D("s" => src2("f")),
            "line" => D("m" => line2("f", "t")),
            "ibr" => D("x" => D("bus" => "t", "terminal_map" => ["p", "n"],
                "topology" => "FIVE_LEG", "prime_mover" => "PV", "s_max" => [1000.0],
                "p_min" => [0.0], "p_max" => [100.0])))
        @test_throws ArgumentError solve_opf(net)
    end

    @testset "apparent-power auxiliaries start on their defining equalities" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        model = JuMP.Model()
        JuMP.@variable(model, vr, start = 0.9)
        JuMP.@variable(model, vi, start = -0.2)
        JuMP.@variable(model, cr, start = 0.5)
        JuMP.@variable(model, ci, start = 0.1)
        p, q = ext._apparent_power_limit!(model, vr, vi, cr, ci, 2.0)
        @test JuMP.start_value(p) ≈ 0.9 * 0.5 + (-0.2) * 0.1
        @test JuMP.start_value(q) ≈ (-0.2) * 0.5 - 0.9 * 0.1
    end
end
