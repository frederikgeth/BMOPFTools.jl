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
    end
end
