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
end
