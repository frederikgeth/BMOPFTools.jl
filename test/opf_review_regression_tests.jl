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
