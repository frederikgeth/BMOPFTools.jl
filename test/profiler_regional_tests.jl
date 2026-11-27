# Regional system fixtures (test/data/profiler_systems) through analyze.

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler: regional systems" begin
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
end
