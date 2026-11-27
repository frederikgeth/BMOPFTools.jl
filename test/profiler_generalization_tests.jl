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
        # Boundary: a line-to-neutral unit beside a center tap is not a high leg,
        # and both passes say so: no high leg in the split-phase finding either,
        # and the unit's 240 V against the 120 V level is an ordinary mismatch.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["c", "n"]
        @test isempty(BMOPFTools._high_leg_power_units(net))
        rep = _pg_analyze(net)
        split = only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
        @test isempty(split.detail["high_leg"]) && split.detail["other_phases"] == ["c"]
        @test !occursin("high-leg", split.message)
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(rep.findings) ||
              "W.VOLT.XFMR_RATIO" in _pg_codes(rep.findings)

        # Secondary maps alone do not make a delta: with both primaries on the
        # same conductors the secondaries are in phase and add in line. Not a
        # high leg, and the unit's level conflicts like any other.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_from"] = ["a", "n"]
        @test isempty(BMOPFTools._high_leg_power_units(net))
        rep = _pg_analyze(net)
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(rep.findings)
        split = only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
        @test isempty(split.detail["high_leg"]) && split.detail["other_phases"] == ["c"]
        # The Japanese bank has phase-to-phase primaries on different pairs.
        jpn = _pg_sys("jp_three_wire_v_connection")
        @test BMOPFTools._high_leg_power_units(jpn) == Set([("single_phase", "pole_shop_power")])
        jpn["transformer"]["single_phase"]["pole_shop_power"]["terminal_map_from"] = ["b", "a"]
        @test isempty(BMOPFTools._high_leg_power_units(jpn))    # the same pair as the lighting unit

        # The power unit's own ratio is still checked, against the bank's
        # line-to-line voltage (twice the leg level).
        ratio(v) = begin
            n = _pg_sys("na_high_leg_open_delta")
            n["transformer"]["single_phase"]["power"]["v_nom_to"] = v
            [f for f in _pg_analyze(n).findings if f.code == "W.VOLT.XFMR_RATIO"]
        end
        @test isempty(ratio(240.0))
        @test isempty(ratio(250.0))                       # within the 10 % tolerance
        bad = only(ratio(480.0))
        @test bad.component_id == "power" && bad.detail["basis"] == "high_leg_line_to_line"
        @test bad.detail["bank_line_to_line_v"] ≈ 240.0
        @test length(ratio(208.0)) == 1                   # a wye-system unit in a delta bank
        # Japanese V-connection with a phase-to-phase primary: 200 V closes the delta.
        jp(v) = begin
            n = _pg_sys("jp_three_wire_v_connection")
            n["transformer"]["single_phase"]["pole_shop_power"]["v_nom_to"] = v
            [f.component_id for f in _pg_analyze(n).findings if f.code == "W.VOLT.XFMR_RATIO"]
        end
        @test isempty(jp(200.0)) && jp(400.0) == ["pole_shop_power"]
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

        # The reference is what the admittance builder stamps, nothing else.
        refd(net) = (f = Finding[]; integrity_check(net, f); !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f)))
        # Earth leakage in the stamped primitive: rows of Y sum to the shunt.
        leak(net) = (Y = line_yprim(net["line"]["run"], net["linecode"])[2];
                     maximum(abs, sum(Y, dims=2)) > 1e-12)
        bare() = _pg_sys("it_delta_island_unreferenced")
        @test !leak(bare()) && !refd(bare())
        cap = _pg_sys("it_delta_island_capacitive")
        @test leak(cap) && refd(cap)

        # Purely phase-to-phase admittance (zero row sums) is not a path to earth.
        net = bare()
        for i in 1:3, j in 1:3
            net["linecode"]["cable"]["B_from_$(i)_$(j)"] = i == j ? 2e-7 : -1e-7
        end
        @test !refd(net)
        # A line that uses a linecode takes its shunt from the linecode: a
        # B entry placed on the line record itself is never stamped.
        net = bare()
        for i in 1:3; net["line"]["run"]["B_to_$(i)_$(i)"] = 1e-6; end
        @test !leak(net) && !refd(net)
        # Inline totals on the line are the single source when present.
        net = bare()
        line = net["line"]["run"]; lc = net["linecode"]["cable"]; delete!(line, "linecode")
        for i in 1:3, j in 1:3
            line["R_series_$(i)_$(j)"] = lc["R_series_$(i)_$(j)"] * 80
            line["X_series_$(i)_$(j)"] = lc["X_series_$(i)_$(j)"] * 80
        end
        @test !refd(net)
        for i in 1:3; line["B_from_$(i)_$(i)"] = 4e-6; end
        @test leak(net) && refd(net)
        # Linecode values scale with length: a zero-length line stamps no shunt.
        net = _pg_sys("it_delta_island_capacitive"); net["line"]["run"]["length"] = 0.0
        @test !refd(net)
        # Only the mapped conductor block is stamped: capacitance on a fourth
        # linecode conductor that this three-wire line does not use is not there.
        net = bare()
        lc = net["linecode"]["cable"]
        for i in 1:4
            lc["R_series_$(i)_4"] = lc["R_series_4_$(i)"] = i == 4 ? 3e-4 : 5e-5
            lc["X_series_$(i)_4"] = lc["X_series_4_$(i)"] = i == 4 ? 3e-4 : 1e-4
        end
        for i in 1:4, j in 1:4; lc["B_from_$(i)_$(j)"] = (i == 4 && j == 4) ? 1e-7 : 0.0; end
        @test !leak(net) && !refd(net)
        # Sparse declarations: an omitted entry is zero. One diagonal entry is
        # a path to earth, and explicit zeros beside it change nothing.
        net = bare(); net["linecode"]["cable"]["B_from_1_1"] = 1e-7
        @test leak(net) && refd(net)
        padded = bare(); lc = padded["linecode"]["cable"]
        lc["B_from_1_1"] = 1e-7; lc["B_from_2_2"] = 0.0; lc["B_from_3_3"] = 0.0
        @test refd(padded)
        @test line_yprim(net["line"]["run"], net["linecode"])[2] ==
              line_yprim(padded["line"]["run"], padded["linecode"])[2]
        # G and B declared with different extents are padded, not rejected.
        net = bare(); lc = net["linecode"]["cable"]
        lc["G_to_2_2"] = 1e-9; lc["B_to_1_1"] = 0.0
        @test leak(net) && refd(net)
        # A sparse entry beyond the mapped conductors is still outside the block.
        net = bare(); net["linecode"]["cable"]["B_from_4_4"] = 1e-7
        @test !refd(net)
        # Malformed shunt data is not a reference and does not abort the helper.
        net = _pg_sys("it_delta_island_capacitive")
        net["linecode"]["cable"]["B_from_1_1"] = "high"
        @test !BMOPFTools._line_stamps_earth_shunt(net["line"]["run"], net["linecode"])
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
        # The passes changed here tolerate it. (analyze as a whole does not yet:
        # the inventory pass iterates transformer groups without a guard.)
        @test provenance_analysis(net, Finding[]) isa Dict
        @test BMOPFTools._dc_link_ac_groups(net) == Vector{String}[]
        @test BMOPFTools._transformer_neutral_earthing(net) isa Dict

        # A center-tap record that is a Dict of another value type.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"] =
            Dict{String,Any}(net["transformer"]["single_phase"]["power"])
        net["transformer"]["single_phase"] = Dict{String,Any}("power" =>
            Dict{String,Union{String,Vector,Real}}(
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

    @testset "mesh verdict and its evidence come from one graph" begin
        consistent(net) = begin
            f = Finding[]
            r = connectivity_analysis(net, f)
            whole = r["structure"]["whole_network"]
            mesh = [x for x in f if x.code == "W.CONN.MESHED"]
            # phase-carrying excess + neutral-only cycles = physical cycle rank
            @test r["n_extra_edges"] + r["neutral_only_cycle_rank"] == whole["cycle_rank"]
            @test r["is_radial"] == isempty(mesh)
            @test occursin("bank", whole["branch_scope"]) && occursin("DC links", whole["branch_scope"])
            (r, whole, mesh)
        end
        # A DC link across two buses of a radial feeder: one loop, with a witness.
        net = _pg_sys("eu_tn_four_wire")
        net["dc_bus"] = Dict{String,Any}("d1" => Dict{String,Any}("terminal_names" => ["p","n"]),
                                         "d2" => Dict{String,Any}("terminal_names" => ["p","n"]))
        net["dc_branch"] = Dict{String,Any}("cable" => Dict{String,Any}("dc_bus_from" => "d1", "dc_bus_to" => "d2"))
        net["ibr"] = Dict{String,Any}("c1" => Dict{String,Any}("bus" => "lv1", "dc_bus" => "d1"),
                                      "c2" => Dict{String,Any}("bus" => "lv2", "dc_bus" => "d2"))
        r, whole, mesh = consistent(net)
        m = only(mesh)
        @test m.detail["extra_edges"] == 1 && whole["cycle_rank"] == 1 && whole["n_dc_links"] == 1
        @test m.detail["simple_cycle_rank"] + m.detail["parallel_excess"] == 1
        @test length(m.detail["cycle_closing_branches"]) == 1
        @test all(z -> z["n_incident_isolating_transformers"] <= 1, r["structure"]["galvanic_zones"])
        @test m.detail["dc_mediated_cycle_rank"] == 1 && m.detail["transformer_mediated_cycle_rank"] == 0
        @test startswith(only(m.detail["cycle_closing_branches"])["component_id"], "d1:")
        # Two independent DC islands linking the same AC buses: two DC cycles,
        # none attributed to transformers, and witnesses that name their island.
        net["dc_bus"]["e1"] = Dict{String,Any}("terminal_names" => ["p","n"])
        net["dc_bus"]["e2"] = Dict{String,Any}("terminal_names" => ["p","n"])
        net["dc_branch"]["cable2"] = Dict{String,Any}("dc_bus_from" => "e1", "dc_bus_to" => "e2")
        net["ibr"]["c3"] = Dict{String,Any}("bus" => "lv1", "dc_bus" => "e1")
        net["ibr"]["c4"] = Dict{String,Any}("bus" => "lv2", "dc_bus" => "e2")
        delete!(net["transformer"], "delta_wye"); delete!(net["bus"], "mv")
        net["voltage_source"]["grid"]["bus"] = "lv0"
        r, whole, mesh = consistent(net)
        m = only(mesh)
        @test whole["dc_mediated_cycle_rank"] == 2 && whole["transformer_mediated_cycle_rank"] == 0
        @test sort([w["component_id"] for w in m.detail["cycle_closing_branches"]]) ==
              ["d1:lv1|lv2", "e1:lv1|lv2"]
        @test [d["dc_island"] for d in r["dc_link_islands"]] == ["d1", "e1"]
        @test all(z -> z["cycle_rank"] == 0, r["structure"]["galvanic_zones"])
        # The bundled banks: radial verdict and zero cycle rank together.
        for name in ("na_high_leg_open_delta", "jp_three_wire_v_connection")
            r, whole, mesh = consistent(_pg_sys(name))
            @test r["is_radial"] && whole["cycle_rank"] == 0 && whole["n_merged_bank_legs"] == 1
        end
        for name in ("eu_tn_four_wire", "na_mgn_split_phase", "au_men_four_wire")
            consistent(_pg_sys(name))
        end
        consistent(_pg_dss("pf_open_delta_reg.dss"))
    end

    @testset "bank grouping does not depend on component ids" begin
        build(ids) = begin
            net = _pg_sys("eu_tn_four_wire")
            delete!(net["transformer"], "delta_wye")
            net["bus"]["mv"]["terminal_names"] = ["a","b","c","n"]
            net["bus"]["mv"]["perfectly_grounded_terminals"] = ["n"]
            unit(tm) = Dict{String,Any}("bus_from" => "mv", "bus_to" => "lv0",
                "terminal_map_from" => ["a","n"], "terminal_map_to" => tm,
                "v_nom_from" => 5773.5, "v_nom_to" => 230.0, "s_rating" => 1e5)
            net["transformer"]["single_phase"] = Dict{String,Any}(
                ids[1] => unit(["a","n"]), ids[2] => unit(["b","n"]), ids[3] => unit(["a","b"]))
            f = Finding[]
            r = connectivity_analysis(net, f)
            (r, only(r["transformer_bank_groups"]))
        end
        ra, ga = build(("u1", "u2", "u3"))          # a–b sorts last
        rb, gb = build(("u2", "u3", "u1"))          # a–b sorts first
        @test ra["n_extra_edges"] == rb["n_extra_edges"] == 1
        @test ga["n_branches"] == gb["n_branches"] == 2
        # The legs are the two line-to-neutral units; a–b spans both and is parallel.
        @test ga["units"] == ["u1", "u2"] && ga["parallel_units"] == ["u3"]
        @test gb["units"] == ["u2", "u3"] && gb["parallel_units"] == ["u1"]
        @test ga["ambiguous"] && gb["ambiguous"]
        @test ra["structure"]["whole_network"]["cycle_rank"] ==
              rb["structure"]["whole_network"]["cycle_rank"]
        # Identical secondaries: one leg, one parallel, not ambiguous, whichever id is first.
        for ids in (("p", "q"), ("q", "p"))
            net = _pg_dss("pf_open_delta_reg.dss")
            sp = net["transformer"]["single_phase"]
            sp["reg2"]["terminal_map_to"] = copy(sp["reg1"]["terminal_map_to"])
            sp[ids[1]] = pop!(sp, "reg1"); sp[ids[2]] = pop!(sp, "reg2")
            g = only(connectivity_analysis(net, Finding[])["transformer_bank_groups"])
            @test length(g["units"]) == 1 && length(g["parallel_units"]) == 1 && !g["ambiguous"]
            @test g["n_branches"] == 2
        end
        # A center-tapped unit anchors its bank: a unit paralleled across one
        # of its legs is the parallel one, and the power unit stays a leg.
        net = _pg_sys("na_high_leg_open_delta")
        extra = deepcopy(net["transformer"]["single_phase"]["power"])
        extra["terminal_map_from"] = ["a", "n"]; extra["terminal_map_to"] = ["a", "n"]
        extra["v_nom_to"] = 120.0
        net["transformer"]["single_phase"]["aaa_extra"] = extra     # sorts before the others
        r = connectivity_analysis(net, Finding[])
        g = only(r["transformer_bank_groups"])
        @test g["units"] == ["lighting", "power"] && g["parallel_units"] == ["aaa_extra"]
        @test g["ambiguous"] && r["n_extra_edges"] == 1
        @test only(r["transformer_banks"])["units"] == ["lighting", "power"]
        # An unreadable unit stays its own branch and is named.
        net = _pg_dss("pf_open_delta_reg.dss")
        net["transformer"]["single_phase"]["reg2"]["terminal_map_to"] = "bc"
        g = only(BMOPFTools._transformer_bank_groups(net).groups)
        @test g["unassessed_units"] == ["reg2"] && g["n_branches"] == 2
    end

    @testset "a reference must reach every conductor group" begin
        # Oracle: the passive Ybus. A group floats when a common shift of its
        # nodes lies in the nullspace of the island's admittance matrix.
        floats(net, nodes) = begin
            r = ybus_passive(net)
            x = zeros(ComplexF64, length(r.nodes))
            for n in nodes; x[r.index[n]] = 1.0; end
            maximum(abs, r.Y * x) <= 1e-9 * maximum(abs, r.Y)
        end
        groups(net) = (f = Finding[]; integrity_check(net, f);
            [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE" && x.detail["scope"] == "conductor_group"])
        phases = [(b, t) for b in ("it0", "it1") for t in ("a", "b", "c")]

        # A separately carried fourth conductor with the line's only earth shunt:
        # the island has a tie to earth, the delta phases do not.
        net = _pg_sys("it_delta_island_unreferenced")
        for b in ("it0", "it1"); net["bus"][b]["terminal_names"] = ["a","b","c","n"]; end
        net["line"]["run"]["terminal_map_from"] = ["a","b","c","n"]
        net["line"]["run"]["terminal_map_to"] = ["a","b","c","n"]
        lc = net["linecode"]["cable"]
        for i in 1:4
            lc["R_series_$(i)_4"] = lc["R_series_4_$(i)"] = i == 4 ? 3e-4 : 5e-5
            lc["X_series_$(i)_4"] = lc["X_series_4_$(i)"] = i == 4 ? 3e-4 : 1e-4
        end
        lc["i_max"] = fill(200.0, 4); lc["B_from_4_4"] = 1e-7
        @test floats(net, phases)
        g = only(groups(net))
        @test Set((t["bus"], t["terminal"]) for t in g.detail["terminals"]) == Set(phases)
        @test g.severity == ERROR && g.detail["buses"] == ["it0", "it1"]
        @test integrity_check(net, Finding[])["n_without_reference"] == 0     # the island has one
        @test integrity_check(net, Finding[])["n_unreferenced_conductor_groups"] == 1

        # Anything that ties the phases to the earthed conductor removes it, and
        # the Ybus agrees each time.
        cap = deepcopy(net); cap["linecode"]["cable"]["B_from_1_1"] = 1e-7       # capacitance on a phase
        @test !floats(cap, phases) && isempty(groups(cap))
        mutual = deepcopy(net); mutual["linecode"]["cable"]["B_from_1_4"] = -2e-8 # phase-to-neutral capacitance
        mutual["linecode"]["cable"]["B_from_4_1"] = -2e-8
        mutual["linecode"]["cable"]["B_from_1_1"] = 2e-8                          # rows a sums to zero: no earth
        @test !floats(mutual, phases) && isempty(groups(mutual))
        wye = deepcopy(net)                                                       # a phase-to-neutral load
        wye["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [100.0], "q_nom" => [0.0])
        @test isempty(groups(wye))
        # The same earth admittance as a standalone shunt that merely LISTS the
        # phases in its map: only the matrix couplings tie terminals.
        sh = deepcopy(net); delete!(sh["linecode"]["cable"], "B_from_4_4")
        sh["shunt"] = Dict{String,Any}("earth" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "G_1_1" => 0.0, "B_1_1" => 0.0, "G_4_4" => 1e-3))
        @test floats(sh, phases)
        @test Set((t["bus"], t["terminal"]) for t in only(groups(sh)).detail["terminals"]) == Set(phases)
        # A nonzero entry between a phase and the earthed terminal does tie them...
        tied = deepcopy(sh); tied["shunt"]["earth"]["G_1_4"] = -1e-4; tied["shunt"]["earth"]["G_4_1"] = -1e-4
        tied["shunt"]["earth"]["G_1_1"] = 1e-4
        @test !floats(tied, phases) && isempty(groups(tied))
        # ...and so does a row of its own to earth.
        own = deepcopy(sh); own["shunt"]["earth"]["G_2_2"] = 1e-5
        @test !floats(own, phases) && isempty(groups(own))
        # A load written against earth (one terminal, no neutral) references its
        # phase, and through the delta the other two: the solver uses the
        # phase-to-reference voltage for it.
        for cfg in ("SINGLE_PHASE", "WYE")
            ld = deepcopy(net)
            tm = cfg == "WYE" ? ["a","b","c"] : ["a"]
            ld["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "configuration" => cfg, "model" => "constant_impedance",
                "p_nom" => fill(100.0, length(tm)), "q_nom" => fill(0.0, length(tm)),
                "v_nom" => fill(230.0, length(tm)))
            @test isempty(groups(ld))
        end
        # Oracle for loads: the linearized Ybus, with constant-impedance loads
        # folded in. A common shift of the phases is in its nullspace iff they float.
        floats_lin(net, nodes) = begin
            lin = ybus_linearized(net)
            x = zeros(ComplexF64, length(lin.nodes))
            for n in nodes; x[lin.index[n]] = 1.0; end
            maximum(abs, lin.Y * x) <= 1e-9 * maximum(abs, lin.Y)
        end
        zload(net, p, q) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a"],
                "configuration" => "SINGLE_PHASE", "model" => "constant_impedance",
                "p_nom" => [p], "q_nom" => [q], "v_nom" => [230.0])
            out
        end
        @test !floats_lin(zload(net, 100.0, 0.0), phases) && isempty(groups(zload(net, 100.0, 0.0)))
        # A zero-power load draws no current at any voltage: it pins nothing.
        zero_load = zload(net, 0.0, 0.0)
        @test floats_lin(zero_load, phases)
        @test length(groups(zero_load)) == 1
        @test isempty(groups(zload(net, 0.0, 50.0)))            # reactive demand alone is a term
        # A WYE load against earth references only the phases that draw power.
        partial = deepcopy(net)
        partial["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b","c"],
            "configuration" => "WYE", "model" => "constant_impedance",
            "p_nom" => [0.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0], "v_nom" => fill(230.0, 3))
        @test length(groups(partial)) == 1
        partial["load"]["aux"]["p_nom"] = [0.0, 80.0, 0.0]
        @test isempty(groups(partial))
        # The same holds per coil for a load that names the neutral: a
        # zero-power phase-to-neutral load ties nothing to the earthed neutral.
        pn(pv, qv) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","n"],
                "configuration" => "SINGLE_PHASE", "model" => "constant_impedance",
                "p_nom" => [pv], "q_nom" => [qv], "v_nom" => [230.0])
            out
        end
        @test floats_lin(pn(0.0, 0.0), phases) && length(groups(pn(0.0, 0.0))) == 1
        @test !floats_lin(pn(100.0, 0.0), phases) && isempty(groups(pn(100.0, 0.0)))
        # WYE to the neutral: one active coil is enough, since the delta load
        # and the transformer winding tie the phases to each other.
        wyen(pv) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b","c","n"],
                "configuration" => "WYE", "model" => "constant_impedance",
                "p_nom" => pv, "q_nom" => [0.0, 0.0, 0.0], "v_nom" => fill(230.0, 3))
            out
        end
        @test floats_lin(wyen([0.0, 0.0, 0.0]), phases) && length(groups(wyen([0.0, 0.0, 0.0]))) == 1
        @test !floats_lin(wyen([0.0, 0.0, 60.0]), phases) && isempty(groups(wyen([0.0, 0.0, 60.0])))
        # A DELTA coil ties its own pair only where it draws power. With the
        # fixture's delta load switched off and the winding removed from the
        # picture, a coil on a-b leaves c in a group of its own.
        coils = BMOPFTools._conductor_reference(Dict{String,Any}(
            "bus" => Dict{String,Any}("x" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                "perfectly_grounded_terminals" => ["n"])),
            "load" => Dict{String,Any}(
                "d" => Dict{String,Any}("bus" => "x", "terminal_map" => ["a","b","c"], "configuration" => "DELTA",
                    "p_nom" => [100.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0]),
                "y" => Dict{String,Any}("bus" => "x", "terminal_map" => ["c","n"], "configuration" => "SINGLE_PHASE",
                    "p_nom" => [50.0], "q_nom" => [0.0])))).groups
        @test coils == [[("x", "a"), ("x", "b")]]            # c is referenced through its own load; a-b float
        # Generators follow the same per-coil rule. A coil whose bounds force
        # both P and Q to zero carries no current at any voltage: it neither
        # ties its phase to the earthed neutral nor references anything.
        gen(tm; pmin=0.0, pmax=0.0, qmin=0.0, qmax=0.0, bounds=true) = begin
            out = deepcopy(net)
            g = Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "configuration" => "SINGLE_PHASE", "cost" => [0.1])
            bounds && merge!(g, Dict{String,Any}("p_min" => [pmin], "p_max" => [pmax],
                                                 "q_min" => [qmin], "q_max" => [qmax]))
            out["generator"] = Dict{String,Any}("g" => g)
            out
        end
        @test length(groups(gen(["a", "n"]))) == 1                    # fixed at zero: floats
        @test length(groups(gen(["a"]))) == 1                         # against earth, fixed at zero
        @test isempty(groups(gen(["a", "n"]; pmax=1000.0)))           # can produce: a tie
        @test isempty(groups(gen(["a", "n"]; qmin=-200.0)))           # reactive range alone is a term
        @test isempty(groups(gen(["a", "n"]; pmin=500.0, pmax=500.0)))# fixed nonzero output
        # Against earth, a generator references its phase only when its output
        # is given: with a dispatch range a voltage shift is absorbed by P and Q.
        @test length(groups(gen(["a"]; pmax=1000.0))) == 1             # a range pins nothing
        @test isempty(groups(gen(["a"]; pmin=500.0, pmax=500.0)))      # P and Q fixed, P nonzero
        @test length(groups(gen(["a"]; pmin=500.0, pmax=500.0, qmin=-10.0, qmax=10.0))) == 1   # Q free
        @test length(groups(gen(["a"]; bounds=false))) == 1            # no bounds: free
        @test isempty(groups(gen(["a", "n"]; bounds=false)))          # no bounds: not forced to zero
        # A zero rating leaves a coil no room even when its P/Q bounds allow dispatch.
        for (key, value) in (("s_max", [0.0]), ("i_max", [0.0, 0.0]), ("i_max", [0.0]), ("s_max", 0.0))
            g = gen(["a", "n"]; pmax=1000.0); g["generator"]["g"][key] = value
            @test length(groups(g)) == 1
        end
        g = gen(["a", "n"]; pmax=1000.0); g["generator"]["g"]["s_max"] = [2000.0]
        @test isempty(groups(g))

        # IBRs follow the same rule, coil by coil and by topology. An offline
        # phase-to-neutral inverter (P and Q pinned at zero) carries no current.
        ibr(tm, topo; extra...) = begin
            out = deepcopy(net)
            out["ibr"] = Dict{String,Any}("pv" => merge(Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "topology" => topo, "prime_mover" => "PV", "s_max" => [3000.0]),
                Dict{String,Any}(string(k) => v for (k, v) in extra)))
            out
        end
        @test isempty(groups(ibr(["a", "n"], "SINGLE_PHASE")))                     # online: a tie
        offline = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[0.0], q_max=[0.0])
        @test length(groups(offline)) == 1 && floats_lin(offline, phases)
        @test length(groups(ibr(["a", "n"], "SINGLE_PHASE"; s_max=[0.0]))) == 1    # zero apparent power
        @test length(groups(ibr(["a", "n"], "SINGLE_PHASE"; i_max=[50.0, 0.0]))) == 1   # one current, tightest entry
        @test isempty(groups(ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[-500.0], q_max=[500.0])))
        # FOUR_LEG: one coil per phase to the neutral; one live phase suffices here.
        four_off = ibr(["a","b","c","n"], "FOUR_LEG"; s_max=fill(1000.0, 3),
            p_min=fill(0.0, 3), p_max=fill(0.0, 3), q_min=fill(0.0, 3), q_max=fill(0.0, 3))
        @test length(groups(four_off)) == 1
        four_one = deepcopy(four_off); four_one["ibr"]["pv"]["q_max"] = [0.0, 0.0, 300.0]
        @test isempty(groups(four_one))
        four_rated = ibr(["a","b","c","n"], "FOUR_LEG"; s_max=[0.0, 0.0, 0.0])
        @test length(groups(four_rated)) == 1
        # THREE_LEG is line-to-line: never a tie to the neutral, online or not.
        @test length(groups(ibr(["a","b","c"], "THREE_LEG"))) == 1
        # A fixed-zero generator stamps nothing into the Ybus either.
        @test floats_lin(gen(["a", "n"]), phases)

        # The ISLAND test reads the same evidence. On the bare delta fixture, with
        # no other tie anywhere, the load is the island's reference...
        only_load = zload(_pg_sys("it_delta_island_unreferenced"), 100.0, 0.0)
        @test !floats_lin(only_load, phases)
        f = Finding[]; r = integrity_check(only_load, f)
        @test !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f))
        @test r["n_without_reference"] == 0 && r["n_unreferenced_conductor_groups"] == 0
        # ...and a zero-power load leaves it without one, in both tests' terms.
        no_load = zload(_pg_sys("it_delta_island_unreferenced"), 0.0, 0.0)
        @test floats_lin(no_load, phases)
        f = Finding[]; r = integrity_check(no_load, f)
        refs = [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE"]
        @test length(refs) == 1 && only(refs).detail["scope"] == "island" && r["n_without_reference"] == 1
        # A phase-to-phase load is no reference.
        pp = deepcopy(net)
        pp["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [100.0], "q_nom" => [0.0])
        @test length(groups(pp)) == 1
        # A capacitor ties what its susceptance matrix stamps. A WYE bank to the
        # earthed fourth conductor references the phases through it...
        capn = deepcopy(net)
        capn["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "configuration" => "WYE",
            "q_rated" => fill(1000.0, 3), "v_nom" => 230.0))
        @test !floats(capn, phases) && isempty(groups(capn))
        # ...a DELTA bank ties phases to each other only...
        capd = deepcopy(net)
        capd["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c"], "configuration" => "DELTA",
            "q_rated" => fill(1000.0, 3), "v_nom" => 400.0))
        @test floats(capd, phases) && length(groups(capd)) == 1
        # ...and a WYE bank whose map holds no resolvable neutral stamps nothing,
        # so merely listing the terminals connects nothing.
        capx = deepcopy(net)
        for b in ("it0", "it1"); capx["bus"][b]["terminal_names"] = ["a","b","c","m"]; end
        capx["line"]["run"]["terminal_map_from"] = ["a","b","c","m"]
        capx["line"]["run"]["terminal_map_to"] = ["a","b","c","m"]
        capx["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","m"], "configuration" => "WYE",
            "q_rated" => fill(1000.0, 3), "v_nom" => 230.0))
        @test all(iszero, BMOPFTools._cap_bmatrix(capx["capacitor"]["bank"])[2])
        phases_x = [(b, t) for b in ("it0", "it1") for t in ("a", "b", "c")]
        @test floats(capx, phases_x) && length(groups(capx)) == 1
        # An IBR ties its terminals as the solver stamps them: THREE_LEG is
        # line-to-line (no reference), FOUR_LEG reaches the earthed neutral.
        three = deepcopy(net)
        three["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c"], "topology" => "THREE_LEG", "prime_mover" => "PV", "s_max" => [3000.0]))
        @test length(groups(three)) == 1
        four = deepcopy(net)
        four["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "topology" => "FOUR_LEG", "prime_mover" => "PV", "s_max" => fill(1000.0, 3)))
        @test isempty(groups(four))
        # The whole-island finding is not repeated per group.
        bare = _pg_sys("it_delta_island_unreferenced")
        f = Finding[]; integrity_check(bare, f)
        refs = [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE"]
        @test length(refs) == 1 && only(refs).detail["scope"] == "island"
        # Declared but untouched terminals are not a group.
        spare = _pg_sys("it_delta_island_capacitive")
        spare["bus"]["it1"]["terminal_names"] = ["a","b","c","spare"]
        @test isempty(groups(spare))
        # Every well-formed regional fixture has every conductor group referenced.
        for name in ("na_mgn_split_phase", "na_high_leg_open_delta", "eu_tn_four_wire",
                     "it_delta_island_capacitive", "jp_three_wire_v_connection", "au_men_four_wire")
            @test isempty(BMOPFTools._unreferenced_conductor_groups(_pg_sys(name)))
        end
        # Malformed tables and records do not abort it.
        bad = _pg_sys("eu_tn_four_wire")
        bad["shunt"] = nothing; bad["switch"] = Dict{String,Any}("s" => 3)
        bad["line"]["f1"]["terminal_map_to"] = "abcn"; bad["load"]["h1"]["terminal_map"] = [1, 2]
        @test BMOPFTools._unreferenced_conductor_groups(bad) isa Vector
    end

    @testset "high-leg identification follows the primary winding phasors" begin
        bank(net) = voltage_level_analysis(net, Finding[])["high_leg_banks"]
        base = _pg_sys("na_high_leg_open_delta")
        b = only(bank(base))
        @test b["status"] == "verified" && b["high_leg"] == ["c"] && b["lighting_unit"] == "lighting"
        # Power primary moved to a–b (with its line-to-line nominal): different
        # terminal set, but the phasors do not close a delta.
        net = _pg_sys("na_high_leg_open_delta")
        p = net["transformer"]["single_phase"]["power"]
        p["terminal_map_from"] = ["a", "b"]; p["v_nom_from"] = 7200.0 * sqrt(3)
        @test isempty(bank(net))
        rep = _pg_analyze(net)
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(rep.findings)
        @test isempty(only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE").detail["high_leg"])
        # Reversing BOTH windings of the power unit is the same transformer.
        net = _pg_sys("na_high_leg_open_delta")
        p = net["transformer"]["single_phase"]["power"]
        p["terminal_map_from"] = ["n", "b"]; p["terminal_map_to"] = ["c", "b"]
        @test only(bank(net))["status"] == "verified"
        # Reversing only one of them flips its polarity, and the delta no
        # longer closes: the third conductor sits at sqrt(7) times the leg
        # level (the power-flow cross-check confirms 317 V), not sqrt(3).
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["c", "b"]
        @test isempty(bank(net))
        # Neither does a power primary on the lighting unit's own phase.
        net = _pg_sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_from"] = ["n", "a"]
        @test isempty(bank(net))
        # The source's angles decide, not the labels: with phases b and c
        # exchanged at the source the bank is still a delta.
        net = _pg_sys("na_high_leg_open_delta")
        net["voltage_source"]["grid"]["v_angle"] = [0.0, 2π/3, -2π/3]
        @test only(bank(net))["status"] == "verified"
        # ...and a source that puts b in phase with a makes it none.
        net["voltage_source"]["grid"]["v_angle"] = [0.0, 0.0, 2π/3]
        @test isempty(bank(net))
        # Phase labels are never evidence of an angle. Fed from an upstream
        # center tap, the two primary legs called "a" and "b" are 180° apart:
        # nothing in the primary's zone establishes their phasors, so the bank
        # is unverified, kept out of propagation, and not called a high leg.
        net = _pg_sys("na_high_leg_open_delta")
        net["bus"]["mid"] = Dict{String,Any}("terminal_names" => ["a","b","n"])
        net["shunt"]["gnd_mid"] = Dict{String,Any}("bus" => "mid", "terminal_map" => ["n"], "G_1_1" => 0.04, "B_1_1" => 0.0)
        up = deepcopy(net["transformer"]["center_tap"]["lighting"]); up["bus_to"] = "mid"
        net["transformer"]["center_tap"]["upstream"] = up
        for (st, id) in (("center_tap", "lighting"), ("single_phase", "power"))
            u = net["transformer"][st][id]; u["bus_from"] = "mid"; u["v_nom_from"] = 120.0
            for k in ("r_series_from", "x_series_from"); u[k] = u[k] * (120.0 / 7200.0)^2; end
        end
        b = only(bank(net))
        @test b["status"] == "unverified" && b["high_leg"] == ["c"]
        rep = _pg_analyze(net)
        @test !("E.VOLT.LEVEL_MISMATCH" in _pg_codes(rep.findings))
        split = only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE" && f.detail["zone_anchor"] == "svc")
        @test isempty(split.detail["high_leg"]) && split.detail["other_phases"] == ["c"]
        # Labels are not followed across a mapped conductor either. With the
        # source balanced, feed BOTH pole.a and pole.b from sub.a: the two
        # primaries are then in phase, whatever their terminals are called.
        net = _pg_sys("na_high_leg_open_delta")
        delete!(net["line"], "main")
        mk(tf, tt, code) = Dict{String,Any}("bus_from" => "sub", "bus_to" => "pole", "linecode" => code,
            "length" => 600.0, "terminal_map_from" => tf, "terminal_map_to" => tt)
        lc = net["linecode"]["primary"]
        net["linecode"]["one"] = Dict{String,Any}("R_series_1_1" => lc["R_series_1_1"],
            "X_series_1_1" => lc["X_series_1_1"], "i_max" => [300.0])
        net["line"]["to_a"] = mk(["a"], ["a"], "one")
        net["line"]["to_b"] = mk(["a"], ["b"], "one")        # pole.b is on the conductor of sub.a
        net["line"]["to_n"] = mk(["n"], ["n"], "one")
        @test isempty(bank(net))                               # in phase: no delta, not "verified"
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(_pg_analyze(net).findings)
        # The same wiring from sub.b to pole.b is the real bank again.
        net["line"]["to_b"] = mk(["b"], ["b"], "one")
        @test only(bank(net))["status"] == "verified"
        # A crossed feed that still delivers a different phase is a delta too:
        # what counts is the conductor's angle, not its name at the pole.
        net["line"]["to_b"] = mk(["c"], ["b"], "one")
        @test only(bank(net))["status"] == "verified"
        # Magnitudes are part of the phasor. With the source's c phase at 40 %,
        # the Japanese V-connection's power primary (b-c) no longer points where
        # a balanced set would put it, and the delta does not close.
        jpn = _pg_sys("jp_three_wire_v_connection")
        @test only(bank(jpn))["status"] == "verified"
        jpn["voltage_source"]["grid"]["v_magnitude"][3] *= 0.4
        @test isempty(bank(jpn))
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(_pg_analyze(jpn).findings)
        # Amplitudes count as well as directions. In the North American bank the
        # two primaries are line-to-neutral, so reducing the power unit's source
        # phase to 40 % leaves every direction intact and shrinks its secondary
        # to 40 % of the line-to-line voltage: the delta does not close.
        weak = _pg_sys("na_high_leg_open_delta")
        weak["voltage_source"]["grid"]["v_magnitude"][2] *= 0.4
        b = only(bank(weak))
        @test b["status"] == "amplitude_mismatch"
        @test b["secondary_amplitude_ratio"] ≈ 0.4 rtol = 1e-6
        rep = _pg_analyze(weak)
        r = only(f for f in rep.findings if f.code == "W.VOLT.XFMR_RATIO")
        @test r.component_id == "power" && r.detail["status"] == "amplitude_mismatch"
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        split = only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
        @test isempty(split.detail["high_leg"]) && split.detail["other_phases"] == ["c"]
        # The same reading for a wrong rating: 480 V in a 120/240 V bank.
        rated = _pg_sys("na_high_leg_open_delta")
        rated["transformer"]["single_phase"]["power"]["v_nom_to"] = 480.0
        b = only(bank(rated))
        @test b["status"] == "amplitude_mismatch"
        @test b["secondary_amplitude_ratio"] ≈ 2.0 rtol = 1e-6
        # Geometry and amplitude are tested independently. Both primaries on
        # a-n are in phase; choosing the power winding's secondary so that the
        # third conductor happens to land at sqrt(3) x 120 V does not make a
        # delta (its line-to-line voltages would be 240, 87.85 and 327.85 V).
        coincidence = _pg_sys("na_high_leg_open_delta")
        pw = coincidence["transformer"]["single_phase"]["power"]
        pw["terminal_map_from"] = ["a", "n"]; pw["v_nom_to"] = 87.85
        @test isempty(bank(coincidence))
        rep = _pg_analyze(coincidence)
        @test "E.VOLT.LEVEL_MISMATCH" in _pg_codes(rep.findings)
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        @test isempty(only(f for f in rep.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE").detail["high_leg"])
        # Boundary: within 10 % in the resulting high-leg voltage is still verified.
        near = _pg_sys("na_high_leg_open_delta")
        near["voltage_source"]["grid"]["v_magnitude"][2] *= 0.95
        @test only(bank(near))["status"] == "verified"
        # A missing or non-positive rating cannot be checked: unverified.
        norating = _pg_sys("na_high_leg_open_delta")
        delete!(norating["transformer"]["single_phase"]["power"], "v_nom_to")
        @test only(bank(norating))["status"] == "unverified"
        # A uniform change of magnitude changes no direction: still a delta.
        jpn = _pg_sys("jp_three_wire_v_connection")
        jpn["voltage_source"]["grid"]["v_magnitude"] .*= 0.9
        @test only(bank(jpn))["status"] == "verified"
        # A source that declares a conductor at two magnitudes establishes nothing.
        net = _pg_sys("na_high_leg_open_delta")
        net["voltage_source"]["second"] = Dict{String,Any}("bus" => "pole", "terminal_map" => ["a","b","c"],
            "v_magnitude" => [3600.0, 7200.0, 7200.0], "v_angle" => [0.0, -2π/3, 2π/3])
        @test only(bank(net))["status"] == "unverified"
        # Two sources that declare one conductor at different angles establish nothing.
        net = _pg_sys("na_high_leg_open_delta")
        net["voltage_source"]["second"] = Dict{String,Any}("bus" => "pole", "terminal_map" => ["a","b","c"],
            "v_magnitude" => fill(7200.0, 3), "v_angle" => [0.5, -2π/3, 2π/3])
        @test only(bank(net))["status"] == "unverified"
        # No source at all: unverified as well.
        net = _pg_sys("na_high_leg_open_delta"); delete!(net, "voltage_source")
        @test only(bank(net))["status"] == "unverified"
    end

    @testset "high-leg banks are resolved once per network" begin
        many(k) = begin
            net = _pg_sys("na_high_leg_open_delta")
            for i in 1:k
                net["bus"]["svc$i"] = deepcopy(net["bus"]["svc"])
                for (st, id) in (("center_tap", "lighting"), ("single_phase", "power"))
                    u = deepcopy(net["transformer"][st][id]); u["bus_to"] = "svc$i"
                    net["transformer"][st]["$id$i"] = u
                end
            end
            net
        end
        cost(net) = (connectivity_analysis(net, Finding[]); @allocated connectivity_analysis(net, Finding[]))
        small = many(50); large = many(200)
        @test length(voltage_level_analysis(large, Finding[])["high_leg_banks"]) == 201
        # Four times the banks: allocation grows about linearly, not quadratically.
        @test cost(large) < 8 * cost(small)
    end

    @testset "DC-linked path metrics do not depend on bus names" begin
        build(names) = begin
            net = _pg_sys("eu_tn_four_wire")
            # three AC end buses hanging off lv2, each with a converter on ONE DC bus
            net["dc_bus"] = Dict{String,Any}("d" => Dict{String,Any}("terminal_names" => ["p","n"]))
            net["ibr"] = Dict{String,Any}()
            for (k, name) in enumerate(names)
                net["bus"][name] = Dict{String,Any}("terminal_names" => ["a","b","c","n"])
                net["ibr"]["c$k"] = Dict{String,Any}("bus" => name, "dc_bus" => "d")
            end
            net["line"]["tie"] = Dict{String,Any}("bus_from" => "lv2", "bus_to" => names[1],
                "linecode" => "cable", "length" => 20.0,
                "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"])
            connectivity_analysis(net, Finding[])
        end
        ra = build(("x1", "x2", "x3")); rb = build(("x3", "x1", "x2")); rc = build(("x2", "x3", "x1"))
        @test ra["tree_depth_max"] == rb["tree_depth_max"] == rc["tree_depth_max"]
        @test ra["degree_max"] == rb["degree_max"] == rc["degree_max"]
        @test ra["n_degree_1"] == rb["n_degree_1"] == rc["n_degree_1"] == 3   # mv and the two far converter buses
        @test ra["is_radial"] && rb["is_radial"] && rc["is_radial"] && ra["is_connected"]
        @test ra["n_extra_edges"] + ra["neutral_only_cycle_rank"] ==
              ra["structure"]["whole_network"]["cycle_rank"] == 0
        # mv - lv0 - lv1 - lv2 - first - island - other: the island hop counts two.
        @test ra["tree_depth_max"] == 6
        # The bus path lists AC buses only (placement strategies slice it);
        # the walk with the island vertex is separate.
        @test !any(startswith("dc_island:"), ra["longest_path_buses"])
        @test any(startswith("dc_island:"), ra["longest_path_vertices"])
        @test length(ra["longest_path_vertices"]) == length(ra["longest_path_buses"]) + 1
        @test !any(startswith("dc_island:"), ra["degree_1_buses"])
        # A real AC bus whose id looks like a DC-island label is still a bus:
        # vertices are told apart by identity, not by name.
        named = _pg_sys("eu_tn_four_wire")
        named["bus"]["dc_island:lv1"] = pop!(named["bus"], "lv1")
        for l in values(named["line"]), k in ("bus_from", "bus_to")
            l[k] == "lv1" && (l[k] = "dc_island:lv1")
        end
        for l in values(named["load"]); l["bus"] == "lv1" && (l["bus"] = "dc_island:lv1"); end
        plain = connectivity_analysis(_pg_sys("eu_tn_four_wire"), Finding[])
        odd = connectivity_analysis(named, Finding[])
        @test odd["longest_path_buses"] == replace(plain["longest_path_buses"], "lv1" => "dc_island:lv1")
        @test odd["longest_path_buses"] == odd["longest_path_vertices"]
        @test "dc_island:lv1" in odd["longest_path_buses"]
        # src -> DC island -> recv -> leaf: the near-source half of the bus path
        # still reaches recv, as it does over a direct AC branch.
        chain = Dict{String,Any}(
            "bus" => Dict{String,Any}(b => Dict{String,Any}("terminal_names" => ["a","n"]) for b in ("src", "recv", "leaf")),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}("bus" => "src", "terminal_map" => ["a"],
                "v_magnitude" => [230.0], "v_angle" => [0.0])),
            "line" => Dict{String,Any}("l" => Dict{String,Any}("bus_from" => "recv", "bus_to" => "leaf",
                "terminal_map_from" => ["a","n"], "terminal_map_to" => ["a","n"])),
            "dc_bus" => Dict{String,Any}("link" => Dict{String,Any}("terminal_names" => ["p","n"])),
            "ibr" => Dict{String,Any}("c1" => Dict{String,Any}("bus" => "src", "dc_bus" => "link"),
                                      "c2" => Dict{String,Any}("bus" => "recv", "dc_bus" => "link")))
        conn = connectivity_analysis(chain, Finding[])
        @test conn["longest_path_buses"] == ["src", "recv", "leaf"]
        @test conn["longest_path_vertices"] == ["src", "dc_island:link", "recv", "leaf"]
        path = conn["longest_path_buses"]
        @test "recv" in path[1:max(1, cld(length(path), 2))]

        # End to end: near-source placement puts the same units behind a DC link
        # as behind a direct AC branch. src - (link) - hub - mid - leaf - tail:
        # the near-source half of the bus path is src, hub, mid, and mid is the
        # first load bus without a converter of its own.
        placed(link) = begin
            bus(grounded=true) = Dict{String,Any}("terminal_names" => ["1","2","3","n"],
                "perfectly_grounded_terminals" => ["n"])
            ln(f, t) = Dict{String,Any}("bus_from" => f, "bus_to" => t, "linecode" => "lc", "length" => 50.0,
                "terminal_map_from" => ["1","2","3","n"], "terminal_map_to" => ["1","2","3","n"])
            ld(b) = Dict{String,Any}("bus" => b, "terminal_map" => ["1","2","3","n"], "configuration" => "WYE",
                "p_nom" => fill(1000.0, 3), "q_nom" => fill(0.0, 3))
            net = Dict{String,Any}(
                "bus" => Dict{String,Any}(b => bus() for b in ("src", "hub", "mid", "leaf", "tail")),
                "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}("bus" => "src",
                    "terminal_map" => ["1","2","3"], "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2.0944, 2.0944])),
                "linecode" => Dict{String,Any}("lc" => Dict{String,Any}("R_series_1_1" => 0.000396)),
                "line" => Dict{String,Any}("l2" => ln("hub", "mid"), "l3" => ln("mid", "leaf"), "l4" => ln("leaf", "tail")),
                "load" => Dict{String,Any}("ld_mid" => ld("mid"), "ld_tail" => ld("tail")))
            if link == :dc
                net["dc_bus"] = Dict{String,Any}("link" => Dict{String,Any}("terminal_names" => ["p","n"]))
                net["ibr"] = Dict{String,Any}(k => Dict{String,Any}("bus" => b, "dc_bus" => "link",
                    "terminal_map" => ["1","2","3"], "topology" => "THREE_LEG", "prime_mover" => "CONVERTER",
                    "s_max" => [1e4]) for (k, b) in (("c1", "src"), ("c2", "hub")))
            else
                net["line"]["l1"] = ln("src", "hub")
            end
            @test connectivity_analysis(net, Finding[])["longest_path_buses"] == ["src", "hub", "mid", "leaf", "tail"]
            gens, _ = redirect_stderr(devnull) do
                add_generators(net; recipe=GeneratorRecipe(strategy=:topology_targeted,
                    topology_mode=:near_source, voltage_levels=nothing))
            end
            ibrs, _ = redirect_stderr(devnull) do
                add_ibrs(net; recipe=IBRRecipe(strategy=:topology_targeted,
                    topology_mode=:near_source, voltage_levels=nothing))
            end
            (sort!(collect(keys(get(gens, "generator", Dict())))),
             sort!([k for k in keys(get(ibrs, "ibr", Dict())) if !(k in ("c1", "c2"))]))
        end
        ac_gens, ac_ibrs = placed(:ac); dc_gens, dc_ibrs = placed(:dc)
        @test ac_gens == ["der_mid"] && dc_gens == ac_gens
        @test ac_ibrs == ["pv_mid"] && dc_ibrs == ac_ibrs
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
