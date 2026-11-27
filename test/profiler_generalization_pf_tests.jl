# Independent check of the profiler's system-type verdicts against the power-flow
# engine: what `analyze` says about a case must match how the case solves.
# Needs JuMP + Ipopt (included only when both are available).

using Test
using BMOPFTools
using JuMP, Ipopt

@testset "Profiler generalization — power-flow cross-check" begin
    sys(name) = parse_bmopf(joinpath(@__DIR__, "data", "profiler_systems", name * ".json"))
    solve(net) = redirect_stdout(devnull) do
        redirect_stderr(devnull) do
            solve_pf(net)
        end
    end
    vmag(res, bus, t) = hypot(res["bus"][bus][t]["vr"], res["bus"][bus][t]["vi"])
    vpp(res, bus, s, t) = hypot(res["bus"][bus][s]["vr"] - res["bus"][bus][t]["vr"],
                                res["bus"][bus][s]["vi"] - res["bus"][bus][t]["vi"])
    report(net) = redirect_stderr(devnull) do
        analyze(net)
    end

    @testset "reported bus levels are the solved leg voltages" begin
        for name in ("na_mgn_split_phase", "eu_tn_four_wire", "au_men_four_wire")
            net = sys(name)
            levels = report(net).results[:voltage_levels]["bus_voltage_map"]
            res = solve(net)
            for (bus, b) in net["bus"], t in b["terminal_names"]
                t == "n" && continue
                @test vmag(res, bus, t) ≈ levels[bus] rtol = 0.03
            end
        end
    end

    @testset "high leg solves at √3 times the reported leg level" begin
        for (name, bus) in (("na_high_leg_open_delta", "svc"), ("jp_three_wire_v_connection", "shop"))
            net = sys(name)
            vl = report(net).results[:voltage_levels]
            @test vl["mixed_phase_to_neutral_buses"] == [bus]
            leg = vl["bus_voltage_map"][bus]
            res = solve(net)
            @test vmag(res, bus, "a") ≈ leg rtol = 0.02
            @test vmag(res, bus, "b") ≈ leg rtol = 0.02
            @test vmag(res, bus, "c") ≈ sqrt(3) * leg rtol = 0.02   # the high leg
            @test vpp(res, bus, "a", "b") ≈ 2 * leg rtol = 0.02     # anti-phase legs
            @test vpp(res, bus, "b", "c") ≈ 2 * leg rtol = 0.02     # delta is closed
        end
    end

    @testset "primaries on the same conductors do not make a high leg" begin
        net = sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_from"] = ["a", "n"]
        rep = report(net)
        @test isempty(rep.results[:voltage_levels]["mixed_phase_to_neutral_buses"])
        @test "E.VOLT.LEVEL_MISMATCH" in [f.code for f in rep.findings]
        res = solve(net)
        # In-phase secondaries add in line: 120 V + 240 V, not sqrt(3) x 120 V.
        @test vmag(res, "svc", "c") ≈ 360.0 rtol = 0.03
        @test !isapprox(vmag(res, "svc", "c"), sqrt(3) * 120.0; rtol = 0.2)
    end

    @testset "a line-to-line power primary beside a line-to-neutral lighting primary" begin
        net = sys("na_high_leg_open_delta")
        p = net["transformer"]["single_phase"]["power"]
        p["terminal_map_from"] = ["a", "b"]; p["v_nom_from"] = 7200.0 * sqrt(3)
        rep = report(net)
        @test isempty(rep.results[:voltage_levels]["high_leg_banks"])
        @test "E.VOLT.LEVEL_MISMATCH" in [f.code for f in rep.findings]
        res = solve(net)
        @test vmag(res, "svc", "a") ≈ 120.0 rtol = 0.03
        @test vmag(res, "svc", "c") ≈ 349.0 rtol = 0.03      # not sqrt(3) x 120 = 208
        # One winding of the power unit reversed: sqrt(7) x 120 V.
        net = sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["terminal_map_to"] = ["c", "b"]
        @test isempty(report(net).results[:voltage_levels]["high_leg_banks"])
        @test vmag(solve(net), "svc", "c") ≈ sqrt(7) * 120.0 rtol = 0.03
    end

    @testset "a bank fed from an upstream center tap is not a verified high leg" begin
        net = sys("na_high_leg_open_delta")
        net["bus"]["mid"] = Dict{String,Any}("terminal_names" => ["a","b","n"])
        net["shunt"]["gnd_mid"] = Dict{String,Any}("bus" => "mid", "terminal_map" => ["n"], "G_1_1" => 0.04, "B_1_1" => 0.0)
        up = deepcopy(net["transformer"]["center_tap"]["lighting"]); up["bus_to"] = "mid"
        net["transformer"]["center_tap"]["upstream"] = up
        for (st, id) in (("center_tap", "lighting"), ("single_phase", "power"))
            u = net["transformer"][st][id]; u["bus_from"] = "mid"; u["v_nom_from"] = 120.0
            for k in ("r_series_from", "x_series_from"); u[k] = u[k] * (120.0 / 7200.0)^2; end
        end
        b = only(report(net).results[:voltage_levels]["high_leg_banks"])
        @test b["status"] == "unverified"
        res = solve(net)
        # The primary legs are 180° apart, so the "third" conductor is far from
        # the sqrt(3) x 120 V a delta would give.
        @test !isapprox(vmag(res, "svc", "c"), sqrt(3) * 120.0; rtol = 0.2)
    end

    @testset "two primaries on one source conductor, under different labels" begin
        net = sys("na_high_leg_open_delta")
        delete!(net["line"], "main")
        mk(tf, tt) = Dict{String,Any}("bus_from" => "sub", "bus_to" => "pole", "linecode" => "one",
            "length" => 600.0, "terminal_map_from" => tf, "terminal_map_to" => tt)
        lc = net["linecode"]["primary"]
        net["linecode"]["one"] = Dict{String,Any}("R_series_1_1" => lc["R_series_1_1"],
            "X_series_1_1" => lc["X_series_1_1"], "i_max" => [300.0])
        net["line"]["to_a"] = mk(["a"], ["a"]); net["line"]["to_b"] = mk(["a"], ["b"]); net["line"]["to_n"] = mk(["n"], ["n"])
        @test isempty(report(net).results[:voltage_levels]["high_leg_banks"])
        @test vmag(solve(net), "svc", "c") ≈ 360.0 rtol = 0.03          # in phase: 120 V + 240 V
    end

    @testset "a weak source phase on the power unit does not close the delta" begin
        net = sys("na_high_leg_open_delta")
        net["voltage_source"]["grid"]["v_magnitude"][2] *= 0.4
        rep = report(net)
        @test only(rep.results[:voltage_levels]["high_leg_banks"])["status"] == "amplitude_mismatch"
        @test "W.VOLT.XFMR_RATIO" in [f.code for f in rep.findings]
        res = solve(net)
        @test vmag(res, "svc", "a") ≈ 120.0 rtol = 0.03
        # 120 V legs and a 96 V power winding: about 110 V, not sqrt(3) x 120 V.
        @test vmag(res, "svc", "c") ≈ 110.0 rtol = 0.05
    end

    @testset "a fixed tap on the power unit changes the high-leg voltage" begin
        net = sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["tap"] = 0.8
        b = only(report(net).results[:voltage_levels]["high_leg_banks"])
        @test b["status"] == "amplitude_mismatch"
        res = solve(net)
        @test vmag(res, "svc", "a") ≈ 120.0 rtol = 0.03
        # 120 V legs and a 300 V power winding at 120°: about 261 V.
        @test vmag(res, "svc", "c") ≈ 261.5 rtol = 0.03
        @test vpp(res, "svc", "b", "c") ≈ 2 * 120.0 * b["secondary_amplitude_ratio"] rtol = 0.03
    end

    @testset "a free tap range on the power unit is not read as tap = 1" begin
        net = sys("na_high_leg_open_delta")
        net["transformer"]["single_phase"]["power"]["tap_min"] = 0.8
        net["transformer"]["single_phase"]["power"]["tap_max"] = 0.85
        b = only(report(net).results[:voltage_levels]["high_leg_banks"])
        @test b["status"] == "amplitude_mismatch"
        res = solve(net)
        @test vmag(res, "svc", "a") ≈ 120.0 rtol = 0.03
        # Not sqrt(3) x 120 V = 208 V: the power winding is held within its bounds.
        @test vmag(res, "svc", "c") ≈ 253.0 rtol = 0.03
        lo, hi = b["secondary_amplitude_range"]
        @test 2 * 120.0 * lo * 0.97 <= vpp(res, "svc", "b", "c") <= 2 * 120.0 * hi * 1.03
        @test vpp(res, "svc", "b", "c") ≈ 2 * 120.0 * b["secondary_amplitude_ratio"] rtol = 0.03
    end

    @testset "zero available power does not switch an inverter off" begin
        # A delta island whose only earth is a separately earthed neutral; a
        # unity-power-factor inverter with two coils fixed at 500 W ties the
        # phases to it. `p_avail = 0` is not a solver bound.
        net = sys("it_delta_island_unreferenced")
        net["bus"]["it1"]["terminal_names"] = ["a", "b", "c", "n"]
        net["bus"]["it1"]["perfectly_grounded_terminals"] = ["n"]
        net["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}(
            "power_factor" => Dict{String,Any}("pf" => 1.0)))
        net["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "it1", "terminal_map" => ["a", "b", "n"],
            "topology" => "FOUR_LEG", "prime_mover" => "PV", "s_max" => [3000.0, 3000.0],
            "p_min" => [500.0, 500.0], "p_max" => [500.0, 500.0], "q_min" => [-500.0, -500.0],
            "q_max" => [500.0, 500.0], "control_profile" => "cp", "p_avail" => 0.0))
        @test isempty(errors(report(net)))
        res = solve(net)
        for t in ("a", "b")
            coil = res["ibr"]["pv"][t]
            @test coil["pg"] ≈ 500.0 rtol = 1e-4
            @test hypot(coil["cri"], coil["cii"]) ≈ 2.5 rtol = 0.05
        end
        # With P pinned at zero the same inverter carries nothing, and the
        # profiler reports the floating phases.
        off = deepcopy(net); off["ibr"]["pv"]["p_min"] = [0.0, 0.0]; off["ibr"]["pv"]["p_max"] = [0.0, 0.0]
        @test "E.INT.NO_VOLTAGE_REFERENCE" in [f.code for f in errors(report(off))]
        ro = solve(off)
        @test all(hypot(ro["ibr"]["pv"][t]["cri"], ro["ibr"]["pv"][t]["cii"]) < 1e-3 for t in ("a", "b"))
    end

    @testset "an unbalanced source magnitude breaks the V-connection's delta" begin
        net = sys("jp_three_wire_v_connection")
        net["voltage_source"]["grid"]["v_magnitude"][3] *= 0.4
        @test isempty(report(net).results[:voltage_levels]["high_leg_banks"])
        res = solve(net)
        @test vmag(res, "shop", "a") ≈ 100.0 rtol = 0.05
        # Nowhere near the sqrt(3) x 100 V of a closed delta.
        @test !isapprox(vmag(res, "shop", "c"), sqrt(3) * 100.0; rtol = 0.2)
    end

    @testset "a load written against earth is the island's reference" begin
        net = sys("it_delta_island_unreferenced")
        net["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a"],
            "configuration" => "SINGLE_PHASE", "model" => "constant_impedance",
            "p_nom" => [100.0], "q_nom" => [0.0], "v_nom" => [230.0])
        @test isempty(errors(report(net)))
        res = solve(net)
        # Pinned, and uniquely: with no other path to earth the load can carry
        # no current, so its phase sits at earth potential and the other two
        # at the line voltage, as on a system with one phase earthed.
        @test vmag(res, "it1", "a") < 1.0
        @test vmag(res, "it1", "b") ≈ 400.0 rtol = 0.02
        @test vmag(res, "it1", "c") ≈ 400.0 rtol = 0.02
        @test vpp(res, "it1", "a", "b") ≈ 400.0 rtol = 0.02
    end

    @testset "an island is referenced exactly when the profiler says so" begin
        # Referenced through cable capacitance: phase-to-earth voltages are the
        # balanced nominal.
        cap = sys("it_delta_island_capacitive")
        @test isempty(errors(report(cap)))
        rc = solve(cap)
        for t in ("a", "b", "c")
            @test vmag(rc, "it1", t) ≈ 400 / sqrt(3) rtol = 0.02
        end
        # Unreferenced: the phase-to-phase voltages are still defined, but the
        # phase-to-earth voltages are an arbitrary shift, the rank deficiency
        # E.INT.NO_VOLTAGE_REFERENCE reports.
        bare = sys("it_delta_island_unreferenced")
        @test "E.INT.NO_VOLTAGE_REFERENCE" in [f.code for f in errors(report(bare))]
        rb = solve(bare)
        @test vpp(rb, "it1", "a", "b") ≈ 400.0 rtol = 0.02
        @test vpp(rb, "it1", "b", "c") ≈ 400.0 rtol = 0.02
        shift_cap = hypot(sum(rc["bus"]["it1"][t]["vr"] for t in ("a", "b", "c")) / 3,
                          sum(rc["bus"]["it1"][t]["vi"] for t in ("a", "b", "c")) / 3)
        @test shift_cap < 1.0          # capacitance pins the neutral point near earth
        # One sparse diagonal entry anchors the island in the solve, and the
        # profiler agrees; explicit zeros beside it change neither.
        sparse = sys("it_delta_island_unreferenced")
        sparse["linecode"]["cable"]["B_from_1_1"] = 1e-7
        padded = deepcopy(sparse)
        padded["linecode"]["cable"]["B_from_2_2"] = 0.0; padded["linecode"]["cable"]["B_from_3_3"] = 0.0
        @test isempty(errors(report(sparse))) && isempty(errors(report(padded)))
        rs = solve(sparse); rp = solve(padded)
        for t in ("a", "b", "c")
            @test vmag(rs, "it1", t) ≈ vmag(rp, "it1", t) rtol = 1e-6
        end
    end
end
