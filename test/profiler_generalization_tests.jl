# Profiler generalization: system types beyond the three-phase four-wire wye
# feeder. Where a behavior is expressible in OpenDSS, the witness is a deck that
# OpenDSS solves (test/data/pf_comparison), so the profiler is checked against a
# case an independent engine accepts.

using Test
using BMOPFTools

const _PG_PF = joinpath(@__DIR__, "data", "pf_comparison")
_pg_codes(findings) = [f.code for f in findings]
_pg_dss(name) = redirect_stderr(devnull) do
    from_dss(joinpath(_PG_PF, name))
end
_pg_analyze(net) = redirect_stderr(devnull) do
    analyze(net)
end

@testset "Profiler generalization" begin

    @testset "transformer neutral impedance is a voltage reference" begin
        # Dyn transformer whose LV star point is earthed only through its own
        # rneut/xneut. OpenDSS solves this deck; the island is referenced.
        net = _pg_dss("pf_dy_xfmr_rneut.dss")
        xf = net["transformer"]["delta_wye"]["t1"]
        @test xf["r_neutral_to"] > 0
        @test isempty(get(net["bus"]["lv"], "perfectly_grounded_terminals", String[]))
        earth = BMOPFTools._transformer_neutral_earthing(net)
        @test haskey(earth, ("lv", "n"))
        @test earth[("lv", "n")] ≈ hypot(xf["r_neutral_to"], xf["x_neutral_to"])
        report = _pg_analyze(net)
        @test !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(report.findings))
        @test !("E.PROV.FLOATING_NEUTRAL" in _pg_codes(report.findings))
        @test report.results[:integrity]["n_without_reference"] == 0

        # Negative: remove the neutral impedance and the same island floats.
        bare = deepcopy(net)
        delete!(bare["transformer"]["delta_wye"]["t1"], "r_neutral_to")
        delete!(bare["transformer"]["delta_wye"]["t1"], "x_neutral_to")
        @test isempty(BMOPFTools._transformer_neutral_earthing(bare))
        @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(_pg_analyze(bare).findings)

        # Boundary: an impedance on a side without a neutral terminal is not a
        # branch (the network builders ignore it there).
        delta_side = deepcopy(bare)
        delta_side["transformer"]["delta_wye"]["t1"]["r_neutral_from"] = 5.0
        @test isempty(BMOPFTools._transformer_neutral_earthing(delta_side))
        @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(_pg_analyze(delta_side).findings)

        # Boundary: zero and non-finite impedances are not finite references.
        for bad in (0.0, Inf, NaN)
            z = deepcopy(bare)
            z["transformer"]["delta_wye"]["t1"]["r_neutral_to"] = bad
            @test isempty(BMOPFTools._transformer_neutral_earthing(z))
        end
    end

    @testset "single-phase banks are one branch and supply the union" begin
        # Two single-phase units on (a,b) and (b,c): an open-delta bank.
        net = _pg_dss("pf_open_delta_reg.dss")
        report = _pg_analyze(net)
        codes = _pg_codes(report.findings)
        conn = report.results[:connectivity]
        @test !("W.CONN.MESHED" in codes)
        @test !("W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY" in codes)
        @test conn["is_radial"]
        @test length(conn["transformer_banks"]) == 1
        @test conn["transformer_banks"][1]["units"] == ["reg1", "reg2"]

        # Negative: two units on the SAME conductors are parallel: a real loop.
        par = deepcopy(net)
        sp = par["transformer"]["single_phase"]
        sp["reg2"]["terminal_map_from"] = copy(sp["reg1"]["terminal_map_from"])
        sp["reg2"]["terminal_map_to"] = copy(sp["reg1"]["terminal_map_to"])
        rp = _pg_analyze(par)
        @test "W.CONN.MESHED" in _pg_codes(rp.findings)
        @test isempty(rp.results[:connectivity]["transformer_banks"])
        # ...and one leg alone cannot supply a three-phase bus.
        @test "W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY" in _pg_codes(rp.findings)
        # Units fed from different primary conductors but landing on the SAME
        # secondary conductors are paralleled there: still a loop, not a bank.
        tied = deepcopy(net)
        st = tied["transformer"]["single_phase"]
        st["reg2"]["terminal_map_to"] = copy(st["reg1"]["terminal_map_to"])
        rt = _pg_analyze(tied)
        @test "W.CONN.MESHED" in _pg_codes(rt.findings)
        @test isempty(rt.results[:connectivity]["transformer_banks"])

        # Three line-to-neutral units form a wye bank.
        bank = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "lv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
                "bus" => "mv", "terminal_map" => ["a","b","c"],
                "v_magnitude" => fill(7200.0, 3), "v_angle" => [0.0, -2π/3, 2π/3])),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "t$p" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "lv",
                    "terminal_map_from" => [p, "n"], "terminal_map_to" => [p, "n"],
                    "v_nom_from" => 7200.0, "v_nom_to" => 120.0) for p in ("a","b","c"))))
        f = Finding[]
        r = connectivity_analysis(bank, f)
        @test r["is_radial"]
        @test r["transformer_banks"][1]["units"] == ["ta", "tb", "tc"]
        @test !("W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY" in _pg_codes(f))
        # Boundary: with one unit removed, phase c is no longer supplied.
        delete!(bank["transformer"]["single_phase"], "tc")
        f = Finding[]
        connectivity_analysis(bank, f)
        @test "W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY" in _pg_codes(f)
    end

    @testset "SWER needs a branch that witnesses the earth return" begin
        # A two-wire single-phase bus behind an autotransformer is not SWER.
        report = _pg_analyze(_pg_dss("pf_autotransformer.dss"))
        conn = report.results[:connectivity]
        @test conn["n_swer_zones"] == 0
        @test !("I.PROV.SWER_ZONE" in _pg_codes(report.findings))
        # The imported grounded reference terminal is not a phase conductor.
        @test all(z -> z["topology"] == "single_phase", conn["zones"])

        base(line_map) = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"]),
                "s0" => Dict{String,Any}("terminal_names" => ["a","n"]),
                "s1" => Dict{String,Any}("terminal_names" => ["a","n"])),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
                "bus" => "mv", "terminal_map" => ["a","b","c"],
                "v_magnitude" => fill(6350.0, 3), "v_angle" => [0.0, -2π/3, 2π/3])),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "iso" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "s0",
                    "terminal_map_from" => ["a","b"], "terminal_map_to" => ["a","n"],
                    "v_nom_from" => 11000.0, "v_nom_to" => 12700.0))),
            "line" => Dict{String,Any}("span" => Dict{String,Any}(
                "bus_from" => "s0", "bus_to" => "s1",
                "terminal_map_from" => line_map, "terminal_map_to" => line_map)))
        topo(net) = only(z.topology for z in BMOPFTools._classify_zones(net) if "s0" in z.buses)
        @test topo(base(["a"])) == :swer                 # single conductor: earth return
        @test topo(base(["a", "n"])) == :single_phase    # metallic return
        mixed = base(["a"])
        mixed["bus"]["s2"] = Dict{String,Any}("terminal_names" => ["a","n"])
        mixed["line"]["two_wire"] = Dict{String,Any}("bus_from" => "s1", "bus_to" => "s2",
            "terminal_map_from" => ["a","n"], "terminal_map_to" => ["a","n"])
        @test topo(mixed) == :single_phase               # a neutral is transported
        nobranch = base(["a"]); delete!(nobranch, "line"); delete!(nobranch["bus"], "s1")
        @test topo(nobranch) == :single_phase            # nothing witnesses the return
        open_sw = base(["a"]); open_sw["switch"] = open_sw["line"]; delete!(open_sw, "line")
        open_sw["switch"]["span"]["open_switch"] = true
        @test topo(open_sw) == :single_phase             # an open switch carries nothing
    end

    @testset "n_winding delta windings propagate a per-conductor nominal" begin
        # 3-winding Dyn/yn deck: OpenDSS load kV fixes the expected bus levels.
        net = _pg_dss("pf_3wdg_dyn.dss")
        report = _pg_analyze(net)
        vmap = report.results[:voltage_levels]["bus_voltage_map"]
        for load in values(net["load"])
            @test vmap[load["bus"]] ≈ load["v_nom"][1] rtol = 1e-6
        end
        # All-wye three-winding deck is unchanged by the basis correction.
        net_y = _pg_dss("pf_3wdg_nwinding.dss")
        vmap_y = _pg_analyze(net_y).results[:voltage_levels]["bus_voltage_map"]
        for load in values(net_y["load"])
            @test vmap_y[load["bus"]] ≈ load["v_nom"][1] rtol = 1e-6
        end
    end

    # ── Report noise: narrowed triggers ─────────────────────────────────────

    _pg_feeder(; n_lines::Int=3, len::Float64=50.0) = begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}("b0" => Dict{String,Any}(
                "terminal_names" => ["a","b","c","n"], "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "b0", "terminal_map" => ["a","b","c"],
                "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2π/3, 2π/3])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                ("$(q)_series_$(k)_$(k)" => (q == "R" ? 3e-4 : 1e-4) for q in ("R","X"), k in 1:4)...,
                "i_max" => fill(200.0, 4))),
            "line" => Dict{String,Any}(), "load" => Dict{String,Any}())
        for k in 1:n_lines
            net["bus"]["b$k"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"])
            net["line"]["l$(lpad(k, 4, '0'))"] = Dict{String,Any}(
                "bus_from" => "b$(k-1)", "bus_to" => "b$k", "linecode" => "lc", "length" => len,
                "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"])
        end
        for (k, ph) in enumerate(("a","b","c"))
            net["load"]["ld$ph"] = Dict{String,Any}("bus" => "b$n_lines",
                "terminal_map" => [ph, "n"], "configuration" => "SINGLE_PHASE",
                "p_nom" => [1000.0 * k], "q_nom" => [100.0 * k], "v_nom" => [230.0])
        end
        net
    end

    @testset "unused-terminal check ignores pinned and capacitor-used terminals" begin
        net = _pg_feeder()
        net["bus"]["b1"]["terminal_names"] = ["a","b","c","n","n_ref"]
        net["bus"]["b1"]["perfectly_grounded_terminals"] = ["n_ref"]
        f = Finding[]
        r = integrity_check(net, f)
        @test r["n_unused_bus_terminals"] == 0          # n_ref is pinned, not free
        # Negative: the same extra terminal without the grounding IS free.
        delete!(net["bus"]["b1"], "perfectly_grounded_terminals")
        f = Finding[]
        integrity_check(net, f)
        @test any(x -> x.code == "W.INT.UNUSED_BUS_TERMINAL" && x.component_id == "b1" &&
                       x.detail["terminals"] == ["n_ref"], f)
        # A floating-star capacitor bank uses its star-point terminal.
        net["capacitor"] = Dict{String,Any}("cap" => Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["a","b","c","n_ref"]))
        f = Finding[]
        integrity_check(net, f)
        @test !any(x -> x.code == "W.INT.UNUSED_BUS_TERMINAL" && x.component_id == "b1", f)
    end

    @testset "unloaded-phase note needs a zone that carries load" begin
        # The source-side zone of the SWER deck has no load at all.
        net = _pg_dss("../SWER/Master.dss")
        f = Finding[]
        operational_analysis(net, f)
        anchors = [x.detail["zone_anchor"] for x in f if x.code == "I.OPS.UNLOADED_PHASE"]
        @test !any(a -> startswith(a, "_pio_vsource") || a == "mv", anchors)
        # A loaded zone with one phase left out is still reported.
        feeder = _pg_feeder(); delete!(feeder["load"], "ldc")
        f = Finding[]
        operational_analysis(feeder, f)
        @test [x.detail["terminal"] for x in f if x.code == "I.OPS.UNLOADED_PHASE"] == ["c"]
    end

    @testset "droop breakpoints beyond the band are not a defect" begin
        droop(bps) = begin
            net = _pg_feeder()
            net["bus"]["b3"]["v_min"] = fill(216.0, 3); net["bus"]["b3"]["v_max"] = fill(253.0, 3)
            net["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}(
                "volt_var" => Dict{String,Any}("breakpoints" => bps)))
            net["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "b3",
                "terminal_map" => ["a","n"], "control_profile" => "cp"))
            f = Finding[]; n = Ref(0)
            BMOPFTools._check_droop_breakpoint_band(net, f, n)
            [x for x in f if x.code == "W.DOM.DROOP_BREAKPOINT_OUTSIDE_BAND"]
        end
        @test isempty(droop([207.0, 220.0, 240.0, 258.0]))   # AS/NZS 4777.2 Australia A
        @test isempty(droop([220.0, 240.0]))                  # all inside
        @test isempty(droop([200.0, 260.0]))                  # one sloped segment spans the band
        @test isempty(droop([216.0, 253.0]))                  # ...also exactly on the bounds
        hit = droop([255.0, 260.0, 265.0])                    # entirely above the band
        @test length(hit) == 1 && hit[1].detail["side"] == "above"
        low = droop([200.0, 210.0])                           # entirely below
        @test length(low) == 1 && low[1].detail["side"] == "below"
        @test length(droop([253.0, 260.0])) == 1              # touching the upper bound only
    end

    @testset "provenance thresholds follow the call configuration" begin
        net = _pg_feeder(; len=0.1)                # Z·length = 3e-5 Ω < 1e-4 Ω default
        f = Finding[]
        provenance_analysis(net, f)
        @test count(x -> x.code == "I.PROV.LINE_SWITCH_LIKE", f) == 3
        cfg = load_config()
        cfg["provenance"]["switch_like"]["z_total"] = 1e-6
        f = Finding[]
        provenance_analysis(net, f; config=cfg)
        @test !any(x -> x.code == "I.PROV.LINE_SWITCH_LIKE", f)
        # ...and through analyze, which is what the configuration file documents.
        tight = _pg_analyze(net)
        loose = redirect_stderr(devnull) do; analyze(net; config=cfg); end
        @test "I.PROV.LINE_SWITCH_LIKE" in _pg_codes(expand_findings(tight)) ||
              "W.DOM.LINE_LOW_IMPEDANCE" in _pg_codes(expand_findings(tight))
        @test !("I.PROV.LINE_SWITCH_LIKE" in _pg_codes(loose.findings))

        # The OpenDSS default power factor fingerprint is configurable too.
        pfnet = _pg_feeder()
        for l in values(pfnet["load"]); l["q_nom"] = [l["p_nom"][1] * tan(acos(0.95))]; end
        f = Finding[]; provenance_analysis(pfnet, f)
        @test !any(x -> x.code == "I.PROV.DSS_DEFAULT_PF", f)
        cfg2 = load_config(); cfg2["provenance"]["dss_defaults"]["pf"] = 0.95
        f = Finding[]; provenance_analysis(pfnet, f; config=cfg2)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_PF", f)
        # A partial user section falls back to packaged values key by key.
        cfg3 = load_config(); cfg3["provenance"]["dss_defaults"] = Dict{String,Any}("pf" => 0.95)
        f = Finding[]; provenance_analysis(pfnet, f; config=cfg3)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_PF", f)
    end

    # ── Report noise: consolidation ─────────────────────────────────────────

    @testset "consolidation: roll-up is thresholded, lossless and never hides errors" begin
        mk(sev, code, id; ctype=:line) = Finding(sev, code, :domain_rules, ctype, id,
            "msg $id", Dict{String,Any}("k" => id))
        cfg(n) = Dict{String,Any}("report" => Dict{String,Any}("rollup_threshold" => n))
        raw = Finding[mk(WARNING, "W.X.MANY", "l$(lpad(k, 2, '0'))") for k in 30:-1:1]
        push!(raw, mk(INFO, "I.X.FEW", "a"), mk(INFO, "I.X.FEW", "b"))
        append!(raw, [mk(ERROR, "E.X.MANY", "e$k") for k in 1:30])
        push!(raw, Finding(WARNING, "W.X.NET", :domain_rules, :network, nothing, "net"))

        out, summary = BMOPFTools._consolidate_findings(raw; config=cfg(25))
        rolled = filter(is_rolled_up, out)
        @test length(rolled) == 1
        r = only(rolled)
        @test r.code == "W.X.MANY" && r.severity == WARNING && r.component_id === nothing
        @test r.detail["count"] == 30
        @test r.detail["components"] == ["l$(lpad(k, 2, '0'))" for k in 1:30]
        @test count(f -> f.code == "E.X.MANY", out) == 30        # errors stay per component
        @test count(f -> f.code == "I.X.FEW", out) == 2          # below threshold
        @test summary["rolled_up"] == [Dict{String,Any}("code" => "W.X.MANY", "n" => 30)]
        @test summary["n_findings_before"] == 63 && summary["n_findings_after"] == 34

        # Lossless: expansion restores every per-component record.
        expanded = expand_findings(out)
        @test length(expanded) == length(raw)
        key(f) = (f.code, string(f.component_id), f.message, f.detail)
        @test Set(key.(expanded)) == Set(key.(raw))
        @test !any(is_rolled_up, expanded)

        # Boundary: exactly the threshold is not rolled up; one more is.
        at = Finding[mk(INFO, "I.X.AT", "c$k") for k in 1:25]
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(25))[1])
        push!(at, mk(INFO, "I.X.AT", "c26"))
        @test any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(25))[1])
        # Disabled, and malformed thresholds fall back to the default.
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(0))[1])
        @test BMOPFTools._rollup_threshold(cfg(-1)) == 25
        @test BMOPFTools._rollup_threshold(cfg(true)) == 25
        @test BMOPFTools._rollup_threshold(Dict{String,Any}()) == 25
        # A component that raises one code twice cannot be keyed: left as is.
        dup = vcat(at, [mk(INFO, "I.X.AT", "c1")])
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(dup; config=cfg(25))[1])
    end

    @testset "consolidation: a stronger finding subsumes the weaker one" begin
        sw(id) = Finding(INFO, "I.PROV.LINE_SWITCH_LIKE", :provenance, :line, id, "s")
        lo(id) = Finding(WARNING, "W.DOM.LINE_LOW_IMPEDANCE", :domain_rules, :line, id, "l")
        out, summary = BMOPFTools._consolidate_findings(Finding[sw("a"), sw("b"), lo("b")])
        @test [(f.code, f.component_id) for f in out] ==
              [("I.PROV.LINE_SWITCH_LIKE", "a"), ("W.DOM.LINE_LOW_IMPEDANCE", "b")]
        @test summary["subsumed"][1]["components"] == ["b"]

        ops(n) = Finding(WARNING, "W.OPS.LINE_UNCONSTRAINED", :operational, :line, nothing,
            "o", Dict{String,Any}("n_unconstrained" => n))
        prov(ids) = Finding(WARNING, "W.PROV.I_MAX_ABSENT", :provenance, :line, nothing,
            "p", Dict{String,Any}("lines" => ids))
        same, _ = BMOPFTools._consolidate_findings(Finding[ops(2), prov(["x","y"])])
        @test [f.code for f in same] == ["W.PROV.I_MAX_ABSENT"]
        # Different counts are different facts: both stay.
        differ, _ = BMOPFTools._consolidate_findings(Finding[ops(3), prov(["x","y"])])
        @test length(differ) == 2
        alone, _ = BMOPFTools._consolidate_findings(Finding[ops(3)])
        @test length(alone) == 1
    end

    @testset "analyze reports a segmented feeder in proportion to its problems" begin
        # 40 sub-meter segments: one root cause, formerly 80 findings.
        net = _pg_feeder(; n_lines=40, len=0.1)
        report = _pg_analyze(net)
        low = [f for f in report.findings if f.code == "W.DOM.LINE_LOW_IMPEDANCE"]
        @test length(low) == 1 && is_rolled_up(low[1]) && low[1].detail["count"] == 40
        @test !any(f -> f.code == "I.PROV.LINE_SWITCH_LIKE", report.findings)
        @test report.results[:consolidation]["n_findings_after"] == length(report.findings)
        @test length(expand_findings(report)) > length(report.findings)
        # Rendering a roll-up works in every format.
        for ext in (".md", ".json", ".txt")
            path = tempname() * ext
            render(report, path)
            @test filesize(path) > 0
        end
        # Opting out restores the per-line findings.
        cfg = load_config(); cfg["report"]["rollup_threshold"] = 0
        flat = redirect_stderr(devnull) do; analyze(net; config=cfg); end
        @test count(f -> f.code == "W.DOM.LINE_LOW_IMPEDANCE", flat.findings) == 40
    end

    # ── Regional system types through analyze ───────────────────────────────

    _pg_sys(name) = parse_bmopf(joinpath(@__DIR__, "data", "profiler_systems", name * ".json"))
    _pg_zone(report, bus) = only(z for z in report.results[:connectivity]["zones"] if z["label"] == bus)

    @testset "regional fixtures are current with their generator" begin
        dir = joinpath(@__DIR__, "data", "profiler_systems")
        names = sort!([f for f in readdir(dir) if endswith(f, ".json")])
        @test names == ["au_men_four_wire.json", "eu_tn_four_wire.json",
            "it_delta_island_capacitive.json", "it_delta_island_unreferenced.json",
            "jp_three_wire_v_connection.json", "na_high_leg_open_delta.json",
            "na_mgn_split_phase.json"]
        for f in names
            net = parse_bmopf(joinpath(dir, f))
            @test haskey(net, "terminal_conventions")
            @test net["meta"]["license"] == "CC-BY-4.0"
        end
    end

    @testset "well-formed regional systems raise no error and no warning" begin
        for name in ("na_mgn_split_phase", "na_high_leg_open_delta", "eu_tn_four_wire",
                     "it_delta_island_capacitive", "jp_three_wire_v_connection",
                     "au_men_four_wire")
            report = _pg_analyze(_pg_sys(name))
            @testset "$name" begin
                @test isempty(errors(report))
                @test isempty(warnings(report))
                @test report.results[:connectivity]["is_radial"]
                @test report.results[:integrity]["n_without_reference"] == 0
            end
        end
    end

    @testset "North American MGN primary with a split-phase service" begin
        report = _pg_analyze(_pg_sys("na_mgn_split_phase"))
        conn = report.results[:connectivity]
        @test conn["n_split_phase_zones"] == 1 && conn["n_swer_zones"] == 0
        @test _pg_zone(report, "svc")["topology"] == "split_phase"
        # The single-phase lateral shares the three-phase feeder's zone.
        @test _pg_zone(report, "sub")["topology"] == "three_phase"
        vmap = report.results[:voltage_levels]["bus_voltage_map"]
        @test vmap["svc"] ≈ 120.0 && vmap["lat"] ≈ 7200.0
        split = only(f for f in report.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
        @test split.detail["legs"] == ["a", "b"] && isempty(split.detail["high_leg"])
        g = report.results[:provenance]["grounding"]
        @test g["n_floating"] == 0 && g["n_grounding_points"] >= 4
    end

    @testset "high-leg delta: one bank, mixed phase-to-neutral voltages" begin
        for (name, leg_v) in (("na_high_leg_open_delta", 120.0), ("jp_three_wire_v_connection", 100.0))
            net = _pg_sys(name)
            report = _pg_analyze(net)
            codes = _pg_codes(report.findings)
            @test !("E.VOLT.LEVEL_MISMATCH" in codes)
            @test !("W.VOLT.XFMR_RATIO" in codes)
            @test !("W.CONN.MESHED" in codes)
            @test !("W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY" in codes)
            vl = report.results[:voltage_levels]
            svc = only(vl["mixed_phase_to_neutral_buses"])
            @test vl["bus_voltage_map"][svc] ≈ leg_v
            @test length(vl["high_leg_units"]) == 1
            split = only(f for f in report.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE" &&
                                                       f.detail["zone_anchor"] == svc)
            @test split.detail["legs"] == ["a", "b"] && split.detail["high_leg"] == ["c"]
            @test length(report.results[:connectivity]["transformer_banks"]) == 1
        end
        # Negative: without the lighting unit the power unit is an ordinary
        # phase-to-phase transformer and propagates its own level.
        net = _pg_sys("na_high_leg_open_delta")
        delete!(net["transformer"], "center_tap")
        @test isempty(BMOPFTools._high_leg_power_units(net))
        vl = voltage_level_analysis(net, Finding[])
        @test isempty(vl["mixed_phase_to_neutral_buses"])
        @test vl["bus_voltage_map"]["svc"] ≈ 240.0 / sqrt(3)
        # Boundary: a line-to-neutral unit beside a center tap is not a high leg.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["c", "n"]
        @test isempty(BMOPFTools._high_leg_power_units(net))
    end

    @testset "unearthed delta island: referenced only through modeled capacitance" begin
        bare = _pg_analyze(_pg_sys("it_delta_island_unreferenced"))
        ref = only(f for f in bare.findings if f.code == "E.INT.NO_VOLTAGE_REFERENCE")
        @test sort(ref.detail["buses"]) == ["it0", "it1"]
        @test [f.code for f in errors(bare)] == ["E.INT.NO_VOLTAGE_REFERENCE"]
        cap = _pg_analyze(_pg_sys("it_delta_island_capacitive"))
        @test isempty(errors(cap))
        # A delta-fed level is three-wire by construction: no Kron suspicion.
        @test !("I.PROV.KRON_LIKELY" in _pg_codes(bare.findings))
        @test bare.results[:provenance]["wires_by_level"]["LV_231V"]["delta_fed"]

        # Boundary: purely phase-to-phase line admittance (zero row sums) is not
        # a path to earth; inline matrices on the line count like a linecode's.
        net = _pg_sys("it_delta_island_unreferenced")
        lc = net["linecode"]["cable"]
        for i in 1:3, j in 1:3
            lc["B_from_$(i)_$(j)"] = i == j ? 2e-7 : -1e-7
        end
        f = Finding[]; integrity_check(net, f)
        @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f)
        net = _pg_sys("it_delta_island_unreferenced")
        for i in 1:3; net["line"]["run"]["B_to_$(i)_$(i)"] = 1e-6; end
        f = Finding[]; integrity_check(net, f)
        @test !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f))
    end

    @testset "Kron suspicion needs branches at the level" begin
        # Two service buses that merely share a nominal voltage carry no wires.
        report = _pg_analyze(_pg_sys("jp_three_wire_v_connection"))
        @test !("I.PROV.KRON_LIKELY" in _pg_codes(report.findings))
        # A three-wire LV feeder behind a wye secondary is still a candidate.
        net = _pg_sys("eu_tn_four_wire")
        for l in values(net["line"])
            l["terminal_map_from"] = ["a","b","c"]; l["terminal_map_to"] = ["a","b","c"]
        end
        net["linecode"]["cable"] = Dict{String,Any}(k => v for (k, v) in net["linecode"]["cable"]
            if !occursin("4", k)); net["linecode"]["cable"]["i_max"] = fill(250.0, 3)
        f = Finding[]; provenance_analysis(net, f)
        @test "I.PROV.KRON_LIKELY" in _pg_codes(f)
    end

    @testset "declared neutral roles are honored on a hand-built case" begin
        # Neutral labeled "4", declared by terminal_conventions, never parsed
        # (so no bus carries a stamped neutral_terminal).
        relabel(x) = x isa AbstractString ? (x == "n" ? "4" : x) :
                     x isa AbstractVector ? Any[relabel(v) for v in x] :
                     x isa AbstractDict ? Dict{String,Any}(k => (k in ("name",) ? v : relabel(v)) for (k, v) in x) : x
        net = relabel(_pg_sys("au_men_four_wire"))
        net["terminal_conventions"] = Dict{String,Any}("phase" => ["a","b","c"], "neutral" => ["4"], "earth" => String[])
        foreach(b -> delete!(b, "neutral_terminal"), values(net["bus"]))
        report = _pg_analyze(net)
        g = report.results[:provenance]["grounding"]
        @test g["n_buses_with_neutral"] == 3
        @test g["n_grounding_points"] == 3 && g["n_floating"] == 0
        @test isempty(errors(report))
        # Negative: drop the earths and the "4" neutral is recognized as floating.
        delete!(net, "shunt")
        @test "E.PROV.FLOATING_NEUTRAL" in _pg_codes(_pg_analyze(net).findings)
        # The neutral power-limit check follows the declared role too.
        net["line"]["f1"]["s_max"] = [1e5, 1e5, 1e5, 1e5]
        f = Finding[]; n = Ref(0)
        BMOPFTools._check_power_limit_neutral(net, f, n)
        @test only(f).detail["neutral_index"] == 4
    end

    @testset "AC sections joined over a DC link are one network" begin
        net = _pg_sys("eu_tn_four_wire")
        net["bus"]["isl"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"],
            "perfectly_grounded_terminals" => ["n"])
        net["load"]["isl_load"] = Dict{String,Any}("bus" => "isl", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [0.0])
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test "E.CONN.DISCONNECTED" in _pg_codes(f) && isempty(r["dc_links"])
        net["dc_bus"] = Dict{String,Any}("d1" => Dict{String,Any}("terminal_names" => ["p","n"]),
                                         "d2" => Dict{String,Any}("terminal_names" => ["p","n"]))
        net["dc_branch"] = Dict{String,Any}("cable" => Dict{String,Any}("dc_bus_from" => "d1",
            "dc_bus_to" => "d2", "terminal_map_from" => ["p","n"], "terminal_map_to" => ["p","n"], "r" => 0.1))
        conv(bus, dc) = Dict{String,Any}("bus" => bus, "dc_bus" => dc, "terminal_map" => ["a","b","c"],
            "topology" => "THREE_LEG", "prime_mover" => "CONVERTER", "s_max" => [1e4])
        net["ibr"] = Dict{String,Any}("c1" => conv("lv2", "d1"), "c2" => conv("isl", "d2"))
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test !("E.CONN.DISCONNECTED" in _pg_codes(f))
        @test r["dc_links"] == [["isl", "lv2"]] && r["is_radial"]
        # Boundary: converters on separate DC islands do not join anything.
        delete!(net, "dc_branch")
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test "E.CONN.DISCONNECTED" in _pg_codes(f) && isempty(r["dc_links"])
        # A DC link between two buses of one AC network closes a loop.
        net["dc_branch"] = Dict{String,Any}("cable" => Dict{String,Any}("dc_bus_from" => "d1",
            "dc_bus_to" => "d2", "terminal_map_from" => ["p","n"], "terminal_map_to" => ["p","n"], "r" => 0.1))
        net["ibr"]["c2"]["bus"] = "lv1"; delete!(net["bus"], "isl"); delete!(net["load"], "isl_load")
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test !r["is_radial"] && "W.CONN.MESHED" in _pg_codes(f)
    end

    # ── Review regressions ──────────────────────────────────────────────────

    @testset "a unit across the center-tap legs is parallel, not a bank leg" begin
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["a", "b"]   # across the legs
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test !r["is_radial"] && "W.CONN.MESHED" in _pg_codes(f)
        @test isempty(r["transformer_banks"])
        @test isempty(BMOPFTools._high_leg_power_units(net))
        @test isempty(voltage_level_analysis(net, Finding[])["mixed_phase_to_neutral_buses"])
        # A leg-to-neutral unit beside the center tap is also within its span.
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["a", "n"]
        f = Finding[]
        @test !connectivity_analysis(net, f)["is_radial"]
        # Declared neutral labels are used for the leg comparison.
        @test BMOPFTools._bank_unit_signature(Dict("terminal_map_from" => ["a","4"],
            "terminal_map_to" => ["a","4"]), Set(["4"])) == Set(["a"])
        @test BMOPFTools._bank_unit_signature(Dict("terminal_map_from" => ["a"],
            "terminal_map_to" => ["n"])) === nothing
    end

    @testset "neutral impedance counts only where a builder stamps it" begin
        island(subtype) = Dict{String,Any}(
            "bus" => Dict{String,Any}("p" => Dict{String,Any}("terminal_names" => ["a","n"]),
                                      "s" => Dict{String,Any}("terminal_names" => ["a","n"])),
            "transformer" => Dict{String,Any}(subtype => Dict{String,Any}("t" => Dict{String,Any}(
                "bus_from" => "p", "bus_to" => "s", "terminal_map_from" => ["a","n"],
                "terminal_map_to" => ["a","n"], "v_nom_from" => 240.0, "v_nom_to" => 240.0,
                "s_rating" => 1e4, "r_neutral_from" => 5.0))))
        @test haskey(BMOPFTools._transformer_neutral_earthing(island("single_phase")), ("p", "n"))
        for subtype in ("single_phase_autotransformer", "open_delta_regulator")
            net = island(subtype)
            @test isempty(BMOPFTools._transformer_neutral_earthing(net))
            f = Finding[]; integrity_check(net, f)
            @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f)
        end
    end

    @testset "malformed input does not abort the profiler" begin
        net = _pg_sys("eu_tn_four_wire")
        net["transformer"]["wye_delta"] = nothing
        net["dc_bus"] = Dict{String,Any}("d" => Dict{String,Any}("terminal_names" => ["p","n"]))
        net["dc_branch"] = nothing; net["ibr"] = nothing
        @test _pg_analyze(net) isa SummaryReport

        # A center-tap record that is a Dict of another value type.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"] =
            Dict{String,Any}(net["transformer"]["single_phase"]["power"])
        net["transformer"]["single_phase"] = Dict{String,Any}("power" =>
            Dict{String,Union{String,Vector{String},Float64}}(
                k => v for (k, v) in net["transformer"]["single_phase"]["power"]))
        @test BMOPFTools._high_leg_power_units(net) == Set([("single_phase", "power")])

        # Malformed threshold values fall back to the packaged ones.
        cfg = load_config()
        cfg["provenance"]["dss_defaults"]["pf"] = "0.9"
        cfg["provenance"]["dss_defaults"]["normamps"] = NaN
        cfg["provenance"]["switch_like"]["z_total"] = "tiny"
        f = Finding[]
        @test provenance_analysis(_pg_sys("eu_tn_four_wire"), f; config=cfg) isa Dict
        cfg["provenance"]["dss_defaults"]["pf"] = 1.7
        @test provenance_analysis(_pg_sys("eu_tn_four_wire"), Finding[]; config=cfg) isa Dict
    end

    @testset "delta-fed means every feeder of the level" begin
        # A delta island and a wye-fed three-wire feeder at the same nominal voltage.
        net = _pg_sys("it_delta_island_capacitive")
        eu = _pg_sys("eu_tn_four_wire")
        net["bus"]["w0"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"],
            "perfectly_grounded_terminals" => ["n"])
        net["bus"]["w1"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"])
        dy = deepcopy(eu["transformer"]["delta_wye"]["sub"])
        dy["bus_from"] = "mv"; dy["bus_to"] = "w0"
        net["transformer"]["delta_wye"] = Dict{String,Any}("dy" => dy)
        net["line"]["w"] = Dict{String,Any}("bus_from" => "w0", "bus_to" => "w1", "linecode" => "cable",
            "length" => 60.0, "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"])
        f = Finding[]
        r = provenance_analysis(net, f)
        @test !r["wires_by_level"]["LV_231V"]["delta_fed"]
        @test "I.PROV.KRON_LIKELY" in _pg_codes(f)
    end

    @testset "supplied phases are united per bank, not per zone" begin
        # Two unrelated single-phase units on phases a and b feed two buses of
        # one LV zone; a three-phase bus behind them is not supplied.
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"], "perfectly_grounded_terminals" => ["n"]),
                "l1" => Dict{String,Any}("terminal_names" => ["a","b","c","n"]),
                "l2" => Dict{String,Any}("terminal_names" => ["a","b","c","n"]),
                "l3" => Dict{String,Any}("terminal_names" => ["a","b","c","n"])),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}("bus" => "mv",
                "terminal_map" => ["a","b","c"], "v_magnitude" => fill(7200.0, 3), "v_angle" => [0.0, -2π/3, 2π/3])),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "t$p" => Dict{String,Any}("bus_from" => "mv", "bus_to" => b,
                    "terminal_map_from" => [p, "n"], "terminal_map_to" => [p, "n"],
                    "v_nom_from" => 7200.0, "v_nom_to" => 120.0)
                for (p, b) in (("a", "l1"), ("b", "l2"), ("c", "l3")))),
            "line" => Dict{String,Any}(
                "x" => Dict{String,Any}("bus_from" => "l1", "bus_to" => "l2",
                    "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"]),
                "y" => Dict{String,Any}("bus_from" => "l2", "bus_to" => "l3",
                    "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"])))
        f = Finding[]
        connectivity_analysis(net, f)
        hit = only(x for x in f if x.code == "W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY")
        @test hit.detail["supplied_phases"] == 1
    end

    @testset "a long DC chain is one link" begin
        net = _pg_sys("eu_tn_four_wire")
        n = 20_000
        net["dc_bus"] = Dict{String,Any}("d$k" => Dict{String,Any}("terminal_names" => ["p","n"]) for k in 1:n)
        net["dc_branch"] = Dict{String,Any}("c$k" => Dict{String,Any}("dc_bus_from" => "d$k",
            "dc_bus_to" => "d$(k+1)") for k in 1:n-1)
        net["ibr"] = Dict{String,Any}(
            "c1" => Dict{String,Any}("bus" => "lv1", "dc_bus" => "d1"),
            "c2" => Dict{String,Any}("bus" => "lv2", "dc_bus" => "d$n"))
        @test BMOPFTools._dc_link_ac_groups(net) == [["lv1", "lv2"]]
    end

    # ── Noise budget on decks an independent engine solves ──────────────────
    #
    # Every deck in test/data/pf_comparison (and the SWER feeder) is solved by
    # OpenDSS in the power-flow comparison tests: these are valid networks. The
    # profiler may comment on them, but an ERROR on one is a false flag, and
    # the warning count is a budget: raise it only with a reason.
    @testset "noise budget on OpenDSS-validated decks" begin
        own(f) = first(f.code, 2) in ("E.", "W.", "I.")
        decks = sort!([f for f in readdir(_PG_PF) if endswith(f, ".dss")])
        @test length(decks) >= 30
        # The one known exception: the deck leaves a PV terminal on OpenDSS
        # node 0, which the import does not materialize at that bus.
        known_errors = Dict("pf_pv_1ph.dss" => ["E.INT.UNKNOWN_TERMINAL"])
        total_warnings = 0; worst = 0
        cases = vcat([(d, () -> _pg_dss(d)) for d in decks],
                     [("SWER", () -> _pg_dss("../SWER/Master.dss"))])
        for (name, load) in cases
            report = _pg_analyze(load())
            errs = sort!([f.code for f in errors(report) if own(f)])
            @test errs == get(known_errors, name, String[])
            n = count(own, warnings(report))
            total_warnings += n; worst = max(worst, n)
        end
        @test worst <= 7                       # measured: 7 (pf_zip_delta.dss)
        @test total_warnings <= 95             # measured: 87 over 38 cases
    end
end
