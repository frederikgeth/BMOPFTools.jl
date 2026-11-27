# Profiler generalization: system types beyond the three-phase four-wire wye
# feeder. Where a behavior is expressible in OpenDSS, the witness is a deck that
# OpenDSS solves (test/data/pf_comparison), so the profiler is checked against a
# case an independent engine accepts.
#
# Voltage reference, transformer banks, consolidation, DC links and the
# regional fixtures have their own profiler_*_tests.jl files.

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler generalization" begin
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
end
