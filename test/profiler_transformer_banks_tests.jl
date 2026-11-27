# Single-phase transformer banks and high-leg identification
# (src/analysis/transformer_banks.jl).

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler: transformer banks" begin
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

    @testset "banks across primary buses need conductor-level evidence" begin
        # The open-delta bank with its two units on different primary buses,
        # joined (or not) by a switch. `feeds = 1`: pole2 hangs off pole through
        # the switch alone. `feeds = 2`: pole2 has its own line from the
        # substation, so the two primaries are separately fed.
        bank(net) = voltage_level_analysis(net, Finding[])["high_leg_banks"]
        build(tie; feeds=1, open=false) = begin
            out = _pg_sys("na_high_leg_open_delta")
            out["bus"]["pole2"] = deepcopy(out["bus"]["pole"])
            out["transformer"]["single_phase"]["power"]["bus_from"] = "pole2"
            feeds == 2 && (out["line"]["main2"] = merge(deepcopy(out["line"]["main"]), Dict{String,Any}("bus_to" => "pole2")))
            tie === nothing || (out["switch"] = Dict{String,Any}("tie" => Dict{String,Any}(
                "bus_from" => "pole", "bus_to" => "pole2", "terminal_map_from" => copy(tie),
                "terminal_map_to" => copy(tie), "open_switch" => open, "i_max" => fill(100.0, length(tie)))))
            out
        end
        # What a case reports: (bank membership, undetermined pairs, phase cycles, high-leg statuses).
        verdict(net) = begin
            c = _pg_analyze(net).results[:connectivity]
            (banks = sort!([g["units"] for g in c["transformer_banks"]]),
             undetermined = sort!([g["units"] for g in c["undetermined_transformer_banks"]]),
             cycles = c["n_extra_edges"],
             high_leg = sort!([(b["power_unit"], b["status"]) for b in bank(net)]))
        end
        one = [["lighting", "power"]]; none = Vector{String}[]
        full = ["a", "b", "c", "n"]
        cases = [
            # A full primary disconnect leaves the bank what it was.
            ("full disconnect",              build(full),             (banks=one,  undetermined=none, cycles=0, high_leg=[("power", "verified")])),
            ("full tie, two feeds",          build(full; feeds=2),    (banks=one,  undetermined=none, cycles=1, high_leg=[("power", "verified")])),
            # Partial ties: some conductor of a winding crosses, not all of them.
            ("phases a and b, no neutral",   build(["a", "b"]; feeds=2), (banks=none, undetermined=one, cycles=2, high_leg=[("power", "undetermined")])),
            ("phase a only",                 build(["a"]; feeds=2),      (banks=none, undetermined=one, cycles=2, high_leg=[("power", "undetermined")])),
            # The tie carries the WHOLE lighting winding (a and n): that winding is
            # present at pole2 as well, where the power unit is. One supply point.
            ("whole lighting winding",       build(["a", "n"]; feeds=2), (banks=one,  undetermined=none, cycles=1, high_leg=[("power", "verified")])),
            # ...but not the whole power winding (b and n) alone the other way
            # round: that one is then present at pole, where the lighting unit is.
            ("whole power winding",          build(["b", "n"]; feeds=2), (banks=one,  undetermined=none, cycles=1, high_leg=[("power", "verified")])),
            # No evidence: a conductor neither winding uses, a neutral bond, an open switch, no switch.
            ("unused phase c",               build(["c"]; feeds=2),   (banks=none, undetermined=none, cycles=2, high_leg=Tuple{String,String}[])),
            ("neutral bond",                 build(["n"]; feeds=2),   (banks=none, undetermined=none, cycles=1, high_leg=Tuple{String,String}[])),
            ("open disconnect",              build(full; feeds=2, open=true), (banks=none, undetermined=none, cycles=1, high_leg=Tuple{String,String}[])),
            ("no switch",                    build(nothing; feeds=2), (banks=none, undetermined=none, cycles=1, high_leg=Tuple{String,String}[])),
        ]
        for (name, net, expected) in cases
            @testset "$name" begin
                @test verdict(net) == expected
            end
        end
        # A full disconnect is the fixture again: same levels, nothing reported.
        rep = _pg_analyze(build(full)); base = _pg_analyze(_pg_sys("na_high_leg_open_delta"))
        @test isempty(errors(rep)) && isempty(warnings(rep))
        @test rep.results[:voltage_levels]["bus_voltage_map"]["svc"] ≈ base.results[:voltage_levels]["bus_voltage_map"]["svc"]
        @test isempty(rep.results[:connectivity]["dangling_buses"])
        g = only(rep.results[:connectivity]["transformer_banks"])
        @test g["supply_buses"] == ["pole", "pole2"]
        # Crossed phases at the disconnect: still one bank by connection, but
        # the phasor trace follows the conductors and does not certify it.
        crossed = build(full); crossed["switch"]["tie"]["terminal_map_to"] = ["b", "a", "c", "n"]
        @test !any(b -> b["status"] == "verified", bank(crossed))
        # A neutral bond across the bank itself (primary to secondary) changes nothing.
        bonded = _pg_sys("na_high_leg_open_delta")
        bonded["switch"] = Dict{String,Any}("bond" => Dict{String,Any}("bus_from" => "pole", "bus_to" => "svc",
            "terminal_map_from" => ["n"], "terminal_map_to" => ["n"], "open_switch" => false, "i_max" => [100.0]))
        @test verdict(bonded) == (banks=one, undetermined=none, cycles=0, high_leg=[("power", "verified")])

        # Units on ONE primary bus are one supply point whatever else their
        # conductors reach: a single-phase lateral switched off the pole, on the
        # lighting unit's conductors or on the power unit's, splits nothing.
        lateral(tm) = begin
            out = _pg_sys("na_high_leg_open_delta")
            out["bus"]["lat"] = Dict{String,Any}("terminal_names" => copy(tm))
            out["switch"] = Dict{String,Any}("tap" => Dict{String,Any}("bus_from" => "pole", "bus_to" => "lat",
                "terminal_map_from" => copy(tm), "terminal_map_to" => copy(tm), "open_switch" => false,
                "i_max" => fill(100.0, length(tm))))
            out["load"]["lat_load"] = Dict{String,Any}("bus" => "lat", "terminal_map" => copy(tm),
                "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [200.0], "v_nom" => [7200.0])
            out
        end
        same_bus = (banks=one, undetermined=none, cycles=0, high_leg=[("power", "verified")])
        push!(cases, ("lateral on the lighting conductors", lateral(["a", "n"]), same_bus))
        push!(cases, ("lateral on the power conductors", lateral(["b", "n"]), same_bus))
        push!(cases, ("lateral on the unused phase", lateral(["c", "n"]), same_bus))
        for name in ("lateral on the lighting conductors", "lateral on the power conductors", "lateral on the unused phase")
            net = only(c[2] for c in cases if c[1] == name)
            @testset "$name" begin
                @test verdict(net) == same_bus
                @test isempty(errors(_pg_analyze(net)))
            end
        end
        # Three units, each sharing a bus with the next but no bus holding all:
        # not one supply point. Nothing is merged and every pair is reported.
        chain = build(["a", "n"]; feeds=2)
        chain["bus"]["pole3"] = deepcopy(chain["bus"]["pole"])
        chain["line"]["main3"] = merge(deepcopy(chain["line"]["main"]), Dict{String,Any}("bus_to" => "pole3"))
        chain["switch"]["tie2"] = Dict{String,Any}("bus_from" => "pole2", "bus_to" => "pole3",
            "terminal_map_from" => ["b", "n"], "terminal_map_to" => ["b", "n"], "open_switch" => false, "i_max" => [100.0, 100.0])
        third = deepcopy(chain["transformer"]["single_phase"]["power"])
        third["bus_from"] = "pole3"; third["terminal_map_from"] = ["c", "n"]; third["terminal_map_to"] = ["c", "a"]
        chain["transformer"]["single_phase"]["third"] = third
        cc = _pg_analyze(chain).results[:connectivity]
        @test isempty(cc["transformer_banks"])
        @test length(cc["undetermined_transformer_banks"]) == 3
        @test all(g -> g["reason"] == "no_common_supply_point", cc["undetermined_transformer_banks"])
        # Component ids play no part: exchanging the two units' ids changes
        # nothing but the names in the answer.
        swapped_ids = build(full)
        swapped_ids["transformer"]["single_phase"]["aaa"] = pop!(swapped_ids["transformer"]["single_phase"], "power")
        swapped_ids["transformer"]["center_tap"]["zzz"] = pop!(swapped_ids["transformer"]["center_tap"], "lighting")
        vs = verdict(swapped_ids)
        @test vs.banks == [["aaa", "zzz"]] && vs.cycles == 0 && vs.high_leg == [("aaa", "verified")]

        # Invariance. None of the verdicts may depend on how the case is written:
        # the name of a bus, the direction of a switch, the label of a terminal.
        rename_bus(net, old, new) = begin
            out = deepcopy(net)
            out["bus"][new] = pop!(out["bus"], old)
            for kind in ("line", "switch"), c in values(get(out, kind, Dict()))
                for k in ("bus_from", "bus_to"); c[k] == old && (c[k] = new); end
            end
            for sub in values(out["transformer"]), t in values(sub)
                for k in ("bus_from", "bus_to"); t[k] == old && (t[k] = new); end
            end
            for kind in ("shunt", "load", "voltage_source"), c in values(get(out, kind, Dict()))
                c["bus"] == old && (c["bus"] = new)
            end
            out
        end
        reverse_switches(net) = begin
            out = deepcopy(net)
            for sw in values(get(out, "switch", Dict()))
                sw["bus_from"], sw["bus_to"] = sw["bus_to"], sw["bus_from"]
                sw["terminal_map_from"], sw["terminal_map_to"] = sw["terminal_map_to"], sw["terminal_map_from"]
            end
            out
        end
        # Rename one terminal of one bus everywhere it is referenced, and
        # declare the new label's role so that it still means what it meant.
        relabel(net, bus, old, new) = begin
            out = deepcopy(net)
            swap(v) = [x == old ? new : x for x in v]
            b = out["bus"][bus]; b["terminal_names"] = swap(b["terminal_names"])
            haskey(b, "perfectly_grounded_terminals") && (b["perfectly_grounded_terminals"] = swap(b["perfectly_grounded_terminals"]))
            for kind in ("line", "switch"), c in values(get(out, kind, Dict()))
                c["bus_from"] == bus && (c["terminal_map_from"] = swap(c["terminal_map_from"]))
                c["bus_to"] == bus && (c["terminal_map_to"] = swap(c["terminal_map_to"]))
            end
            for sub in values(out["transformer"]), t in values(sub)
                t["bus_from"] == bus && (t["terminal_map_from"] = swap(t["terminal_map_from"]))
                t["bus_to"] == bus && (t["terminal_map_to"] = swap(t["terminal_map_to"]))
            end
            for kind in ("shunt", "load", "voltage_source"), c in values(get(out, kind, Dict()))
                c["bus"] == bus && (c["terminal_map"] = swap(c["terminal_map"]))
            end
            role = old in out["terminal_conventions"]["neutral"] ? "neutral" : "phase"
            push!(out["terminal_conventions"][role], new)
            out
        end
        variants = [
            ("pole2 sorts first",  net -> rename_bus(net, "pole2", "a_pole2")),
            ("pole sorts last",    net -> rename_bus(net, "pole", "z_pole")),
            ("both renamed",       net -> rename_bus(rename_bus(net, "pole", "m2"), "pole2", "m1")),
            ("switch reversed",    reverse_switches),
            ("phase b relabeled",  net -> relabel(net, "pole2", "b", "x")),
            ("phase a relabeled",  net -> relabel(net, "pole2", "a", "y")),
            ("neutral relabeled",  net -> relabel(net, "pole2", "n", "m")),
            ("reversed, renamed, relabeled",
                net -> relabel(rename_bus(reverse_switches(net), "pole2", "a_pole2"), "a_pole2", "b", "x")),
        ]
        for (name, net, expected) in cases, (variant, transform) in variants
            haskey(net, "switch") || variant != "switch reversed" || continue
            # The lateral cases have no second pole to rename or relabel.
            haskey(net["bus"], "pole2") || variant in ("pole sorts last", "switch reversed") || continue
            @testset "$name — $variant" begin
                @test verdict(transform(net)) == expected
            end
        end
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
        # The fixed tap is part of the ratio, as in the solver: tap = 0.8 on the
        # power unit raises its secondary to 300 V in a 240 V bank.
        tapped = _pg_sys("na_high_leg_open_delta")
        tapped["transformer"]["single_phase"]["power"]["tap"] = 0.8
        b = only(bank(tapped))
        @test b["status"] == "amplitude_mismatch"
        @test b["secondary_amplitude_ratio"] ≈ 1.25 rtol = 1e-6
        @test "W.VOLT.XFMR_RATIO" in _pg_codes(_pg_analyze(tapped).findings)
        # The same tap on both units changes no ratio between them...
        both = deepcopy(tapped); both["transformer"]["center_tap"]["lighting"]["tap"] = 0.8
        @test only(bank(both))["status"] == "verified"
        # ...a small tap stays within tolerance, and a nonsensical one is unverified.
        small = _pg_sys("na_high_leg_open_delta")
        small["transformer"]["single_phase"]["power"]["tap"] = 1.025
        @test only(bank(small))["status"] == "verified"
        bad = _pg_sys("na_high_leg_open_delta")
        bad["transformer"]["single_phase"]["power"]["tap"] = 0.0
        @test only(bank(bad))["status"] == "unverified"
        # A power winding fed from one source conductor on both ends has no
        # voltage across it. That is an established result, not a missing one.
        same = _pg_sys("jp_three_wire_v_connection")
        same["line"]["main2"]["terminal_map_from"] = ["a", "b", "b"]       # p2.c is the source's b
        b = only(bank(same))
        @test b["status"] == "amplitude_mismatch" && b["secondary_amplitude_ratio"] == 0.0
        rep = _pg_analyze(same)
        r = only(f for f in rep.findings if f.code == "W.VOLT.XFMR_RATIO")
        @test r.component_id == "pole_shop_power" && r.detail["secondary_amplitude_ratio"] == 0.0
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        # The intact fixture is unaffected, and a zero-voltage LIGHTING primary
        # (no leg voltage to compare with) stays unverified.
        @test only(bank(_pg_sys("jp_three_wire_v_connection")))["status"] == "verified"
        dead = _pg_sys("jp_three_wire_v_connection")
        dead["line"]["main2"]["terminal_map_from"] = ["a", "a", "c"]
        @test only(bank(dead))["status"] == "unverified"
        # A terminal's label does not make it a return conductor. With phase c
        # and the neutral swapped at the pole, `pole.n` carries the source's c
        # and both primaries are line-to-line: no high leg.
        swapped = _pg_sys("na_high_leg_open_delta")
        swapped["line"]["main"]["terminal_map_to"] = ["a", "b", "n", "c"]
        @test !any(b -> b["status"] == "verified", bank(swapped))
        @test isempty(_pg_analyze(swapped).results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        # A neutral under another label still counts: the conductor reaches the
        # grounded neutral of the source bus.
        renamed = _pg_sys("na_high_leg_open_delta")
        renamed["bus"]["pole"]["terminal_names"] = ["a", "b", "c", "x"]
        renamed["line"]["main"]["terminal_map_to"] = ["a", "b", "c", "x"]
        for (st, id, tm) in (("center_tap", "lighting", ["a", "x"]), ("single_phase", "power", ["b", "x"]))
            renamed["transformer"][st][id]["terminal_map_from"] = tm
        end
        @test only(bank(renamed))["status"] == "verified"
        # A neutral that reaches no earth has no established voltage, whatever
        # it is called: without the upstream neutral conductor and the pole
        # electrode the bank is not certified. Either one restores it.
        cut(; electrode=false) = begin
            out = _pg_sys("na_high_leg_open_delta")
            out["line"]["main"]["terminal_map_from"] = ["a", "b", "c"]
            out["line"]["main"]["terminal_map_to"] = ["a", "b", "c"]
            electrode || delete!(out["shunt"], "gnd_pole")
            out
        end
        @test only(bank(cut()))["status"] == "unverified"
        @test isempty(_pg_analyze(cut()).results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        wired = _pg_sys("na_high_leg_open_delta"); delete!(wired["shunt"], "gnd_pole")
        @test only(bank(wired))["status"] == "verified"
        # A shunt to earth is a path, not a voltage. An electrode alone carries
        # the primary return current, and a shunt that also couples the neutral
        # to a phase drives it away from zero: neither establishes the phasor.
        @test only(bank(cut(electrode=true)))["status"] == "unverified"
        divider = cut()
        divider["shunt"]["tie"] = Dict{String,Any}("bus" => "pole", "terminal_map" => ["a", "n"],
            "G_1_1" => 1e-3, "G_1_2" => -1e-3, "G_2_1" => -1e-3, "G_2_2" => 2e-3,
            "B_1_1" => 0.0, "B_1_2" => 0.0, "B_2_1" => 0.0, "B_2_2" => 0.0)
        @test only(bank(divider))["status"] == "unverified"
        # A perfect ground at the pole does hold it.
        solid = cut(); solid["bus"]["pole"]["perfectly_grounded_terminals"] = ["n"]
        @test only(bank(solid))["status"] == "verified"
        # ...but not when nothing pins it and its terminals are not all returns.
        loose = deepcopy(renamed); delete!(loose["bus"]["sub"], "perfectly_grounded_terminals")
        loose["voltage_source"]["far"] = merge(deepcopy(loose["voltage_source"]["grid"]), Dict{String,Any}("bus" => "pole"))
        delete!(loose["voltage_source"], "grid")
        @test only(bank(loose))["status"] == "unverified"
        # A free tap (tap_min < tap_max) is a range, and `tap` only its start,
        # clamped into the bounds. Every position misses: a mismatch, although
        # the absent `tap` would read as 1.0.
        free(lo, hi; unit=("single_phase", "power"), tap=nothing) = begin
            out = _pg_sys("na_high_leg_open_delta"); t = out["transformer"][unit[1]][unit[2]]
            t["tap_min"] = lo; t["tap_max"] = hi; tap === nothing || (t["tap"] = tap)
            out
        end
        b = only(bank(free(0.8, 0.85)))
        @test b["status"] == "amplitude_mismatch"
        @test b["secondary_amplitude_range"] ≈ [1 / 0.85, 1 / 0.8] rtol = 1e-6
        @test b["secondary_amplitude_ratio"] ≈ 1 / 0.85 rtol = 1e-6          # the clamped start
        @test "W.VOLT.XFMR_RATIO" in _pg_codes(_pg_analyze(free(0.8, 0.85)).findings)
        # Every position closes the delta: verified, with the range reported.
        b = only(bank(free(0.95, 1.05)))
        @test b["status"] == "verified"
        @test b["secondary_amplitude_range"] ≈ [1 / 1.05, 1 / 0.95] rtol = 1e-6
        # Some positions close it and some do not: not certified, not reported.
        wide = free(0.8, 1.1)
        @test only(bank(wide))["status"] == "unverified"
        rep = _pg_analyze(wide)
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        @test !("W.VOLT.XFMR_RATIO" in _pg_codes(rep.findings))
        # Boundary: a range just inside the 10 % band, and one end just out of
        # it; a free tap on the lighting unit moves the range the other way.
        @test only(bank(free(0.92, 1.08)))["status"] == "verified"
        @test only(bank(free(0.89, 1.08)))["status"] == "unverified"
        @test only(bank(free(0.8, 0.85; unit=("center_tap", "lighting"))))["status"] == "amplitude_mismatch"
        # Equal bounds free nothing: the solver keeps `tap`, and so does the check.
        @test only(bank(free(0.8, 0.8)))["status"] == "verified"
        @test only(bank(free(0.8, 0.8; tap=0.8)))["status"] == "amplitude_mismatch"
        # Fixed taps report no range; malformed bounds are unverified.
        @test only(bank(_pg_sys("na_high_leg_open_delta")))["secondary_amplitude_range"] === nothing
        @test only(bank(free("low", 1.1)))["status"] == "unverified"
        @test only(bank(free(0.0, 1.1)))["status"] == "unverified"
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
end
