# Neutral-only branches keep buses connected but carry no phase conductor. They
# do not join galvanic (phase-conductor) zones, do not make a radial feeder
# meshed, and do not act as parallel supply paths around a transformer. The
# witness is a synthetic 4-wire wye feeder with a center-tap service
# transformer whose primary and secondary neutrals are bonded by a
# neutral-only line. It is built inline so the test owns every value.
using Test, BMOPFTools, JSON3

function _bus_graph_bond_witness(; neutral="4", conventions=true)
    p(t) = t == "4" ? neutral : t
    tm(ts...) = [p(t) for t in ts]
    net = Dict{String,Any}(
        "name" => "neutral bond bus-graph witness",
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => tm("1", "2", "3", "4"),
                                      "perfectly_grounded_terminals" => tm("4")),
            "pad" => Dict{String,Any}("terminal_names" => tm("1", "2", "3", "4")),
            "sec" => Dict{String,Any}("terminal_names" => tm("1", "2", "4"),
                                      "perfectly_grounded_terminals" => tm("4"))),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => tm("1", "2", "3"),
            "v_magnitude" => [7621.0, 7621.0, 7621.0],
            "v_angle" => [0.0, -2pi / 3, 2pi / 3])),
        "linecode" => Dict{String,Any}(
            "mv" => Dict{String,Any}(
                "R_series_1_1" => 2e-4, "R_series_2_2" => 2e-4, "R_series_3_3" => 2e-4,
                "R_series_4_4" => 4e-4, "X_series_1_1" => 4e-4, "X_series_2_2" => 4e-4,
                "X_series_3_3" => 4e-4, "X_series_4_4" => 4e-4),
            "bond" => Dict{String,Any}("R_series_1_1" => 1e-3, "X_series_1_1" => 1e-4)),
        "line" => Dict{String,Any}(
            "mv" => Dict{String,Any}("bus_from" => "src", "bus_to" => "pad",
                "terminal_map_from" => tm("1", "2", "3", "4"),
                "terminal_map_to" => tm("1", "2", "3", "4"),
                "linecode" => "mv", "length" => 500.0),
            "bond" => Dict{String,Any}("bus_from" => "pad", "bus_to" => "sec",
                "terminal_map_from" => tm("4"), "terminal_map_to" => tm("4"),
                "linecode" => "bond", "length" => 1.0)),
        "transformer" => Dict{String,Any}("center_tap" => Dict{String,Any}(
            "ct" => Dict{String,Any}("bus_from" => "pad", "bus_to" => "sec",
                "terminal_map_from" => tm("1", "4"), "terminal_map_to" => tm("1", "4", "2"),
                "v_nom_from" => 7621.0, "v_nom_to" => 120.0, "s_rating" => 25e3,
                "r_series_from" => 20.0, "r_series_to" => 0.01,
                "x_series_from" => 40.0, "x_series_to" => 0.01))),
        "load" => Dict{String,Any}("house" => Dict{String,Any}(
            "bus" => "sec", "terminal_map" => tm("1", "2"),
            "configuration" => "SINGLE_PHASE", "p_nom" => [3000.0], "q_nom" => [500.0])))
    conventions && (net["terminal_conventions"] = Dict{String,Any}(
        "phase" => ["1", "2", "3"], "neutral" => [neutral]))
    net
end

_zone_sets(net) = Set(Set(z) for z in BMOPFTools._galvanic_zones(net))

@testset "Neutral-only branches in bus-graph analyses" begin
    parse(net) = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)
    house_va = hypot(3000.0, 500.0)

    @testset "Neutral bond beside a center-tap transformer" begin
        net = parse(_bus_graph_bond_witness())
        @test _zone_sets(net) == Set([Set(["src", "pad"]), Set(["sec"])])
        report = analyze(net)
        conn = report.results[:connectivity]
        @test conn["is_radial"]
        @test conn["n_extra_edges"] == 0
        @test conn["n_neutral_only_branches"] == 1
        @test conn["neutral_only_cycle_rank"] == 1
        @test conn["is_connected"]
        @test !any(f -> f.code == "W.CONN.MESHED", report.findings)
        zones = Dict(z["label"] => z["topology"] for z in conn["zones"])
        @test zones == Dict("src" => "three_phase", "sec" => "split_phase")
        split = [f for f in report.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE"]
        @test only(split).detail["zone_anchor"] == "sec"
        # The physical bus graph still records the transformer-mediated cycle.
        whole = conn["structure"]["whole_network"]
        @test whole["cycle_rank"] == 1
        @test whole["transformer_mediated_cycle_rank"] == 1
        # The bond is not a parallel supply path around the transformer.
        @test BMOPFTools._downstream_load(net, "ct", ["pad"], ["sec"]) == (house_va, false)
        row = only(report.results[:operational]["transformer_utilisation"])
        @test row["estimate_status"] == "radial_component"
        @test row["s_load_va"] ≈ house_va
        @test BMOPFTools._downstream_buses(net, "ct", ["sec"]) == Set(["sec"])
    end

    @testset "Orientation checks are no longer skipped around a bond" begin
        net = _bus_graph_bond_witness()
        ct = net["transformer"]["center_tap"]["ct"]
        ct["bus_from"], ct["bus_to"] = "sec", "pad"
        ct["terminal_map_from"], ct["terminal_map_to"] = ["1", "4", "2"], ["1", "4"]
        ct["v_nom_from"], ct["v_nom_to"] = 120.0, 7621.0
        report = analyze(parse(net))
        @test any(f -> f.code == "W.DOM.XFMR_REVERSED" && f.component_id == "ct",
                  report.findings)
    end

    @testset "Phase-carrying parallel paths remain meshes" begin
        net = _bus_graph_bond_witness()
        for key in ("terminal_map_from", "terminal_map_to")
            net["line"]["bond"][key] = ["1", "4"]
        end
        net = parse(net)
        @test _zone_sets(net) == Set([Set(["src", "pad", "sec"])])
        report = analyze(net)
        meshed = only(f for f in report.findings if f.code == "W.CONN.MESHED")
        @test meshed.detail["extra_edges"] == 1
        @test meshed.detail["neutral_only_cycle_rank"] == 0
        @test last(BMOPFTools._downstream_load(net, "ct", ["pad"], ["sec"]))
        # A phase loop and a neutral bond: only the phase loop is a mesh.
        net = parse(_bus_graph_bond_witness())
        net["line"]["tie"] = Dict{String,Any}("bus_from" => "src", "bus_to" => "pad",
            "terminal_map_from" => ["1", "2", "3", "4"], "terminal_map_to" => ["1", "2", "3", "4"],
            "linecode" => "mv", "length" => 700.0)
        report = analyze(net)
        meshed = only(f for f in report.findings if f.code == "W.CONN.MESHED")
        @test meshed.detail["extra_edges"] == 1
        @test meshed.detail["neutral_only_cycle_rank"] == 1
        @test report.results[:connectivity]["n_extra_edges"] == 1
    end

    @testset "Role resolution boundaries" begin
        net = parse(_bus_graph_bond_witness(neutral="n", conventions=false))
        @test _zone_sets(net) == Set([Set(["src", "pad"]), Set(["sec"])])
        @test analyze(net).results[:connectivity]["is_radial"]
        # Without a neutral role the bond is not assumed to be a return path.
        net = _bus_graph_bond_witness()
        net["terminal_conventions"]["neutral"] = String[]
        net = parse(net)
        @test length(BMOPFTools._galvanic_zones(net)) == 1
        @test !analyze(net).results[:connectivity]["is_radial"]
        # A malformed declaration keeps the previous conservative treatment.
        net = parse(_bus_graph_bond_witness())
        net["terminal_conventions"] = Dict{String,Any}("neutral" => "4")
        @test length(BMOPFTools._galvanic_zones(net)) == 1
        @test !connectivity_analysis(net, BMOPFTools.Finding[])["is_radial"]
    end

    @testset "Neutral-only switch and grounding-electrode bus" begin
        net = _bus_graph_bond_witness()
        bond = pop!(net["line"], "bond")
        delete!(bond, "linecode"); delete!(bond, "length")
        bond["open_switch"] = false
        net["switch"] = Dict{String,Any}("bond" => bond)
        net["bus"]["electrode"] = Dict{String,Any}("terminal_names" => ["4"],
            "perfectly_grounded_terminals" => ["4"])
        net["line"]["ground"] = Dict{String,Any}("bus_from" => "sec", "bus_to" => "electrode",
            "terminal_map_from" => ["4"], "terminal_map_to" => ["4"],
            "linecode" => "bond", "length" => 3.0)
        net = parse(net)
        conn = connectivity_analysis(net, BMOPFTools.Finding[])
        @test conn["is_connected"]
        @test conn["is_radial"]
        @test conn["n_neutral_only_branches"] == 2
        @test conn["neutral_only_cycle_rank"] == 1
        @test Set(["electrode"]) in _zone_sets(net)
    end

    @testset "Serialization and rendering" begin
        net = parse(_bus_graph_bond_witness())
        path = joinpath(mktempdir(), "bond.json")
        write_bmopf(net, path)
        roundtrip = BMOPFTools.parse_bmopf(path)
        report = analyze(roundtrip)
        conn = JSON3.read(JSON3.write(BMOPFTools._jsonable(report.results[:connectivity])),
                          Dict{String,Any})
        @test conn["is_radial"] == true
        @test conn["neutral_only_cycle_rank"] == 1
        md = joinpath(mktempdir(), "report.md")
        render(report, md)
        @test occursin("| Neutral-only branches | 1 (closing 1 cycle(s)", read(md, String))
        net = parse(_bus_graph_bond_witness())
        net["line"]["tie"] = Dict{String,Any}("bus_from" => "src", "bus_to" => "pad",
            "terminal_map_from" => ["1", "2", "3", "4"], "terminal_map_to" => ["1", "2", "3", "4"],
            "linecode" => "mv", "length" => 700.0)
        meshed = only(f for f in analyze(net).findings if f.code == "W.CONN.MESHED")
        @test JSON3.read(JSON3.write(meshed.detail), Dict{String,Any})["neutral_only_cycle_rank"] == 1
    end
end
