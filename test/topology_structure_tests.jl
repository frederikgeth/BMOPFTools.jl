using Test, BMOPFTools, JSON3

@testset "topology structure" begin
    line(a, b; length=1.0, from=["1", "n"], to=["1", "n"]) =
        Dict{String,Any}("bus_from" => a, "bus_to" => b,
                         "terminal_map_from" => from, "terminal_map_to" => to,
                         "length" => length)
    net = Dict{String,Any}(
        "bus" => Dict(b => Dict{String,Any}() for b in ("a", "b", "c", "d", "e")),
        "line" => Dict("ab1" => line("a", "b"), "ab2" => line("b", "a"),
                       "bc" => line("b", "c"), "ca" => line("c", "a"),
                       "de" => line("d", "e")),
        "switch" => Dict("open" => Dict("bus_from" => "a", "bus_to" => "d",
                                           "open_switch" => true)),
        "transformer" => Dict("delta_wye" => Dict(
            "t1" => Dict("bus_from" => "c", "bus_to" => "d"),
            "t2" => Dict("bus_from" => "b", "bus_to" => "e"))))
    levels = Dict{String,Any}("levels" => Dict(
        "MV" => Dict("buses" => ["a", "b", "c"]),
        "LV" => Dict("buses" => ["d", "e"])))
    s = BMOPFTools._topology_structure(net, levels)
    whole = s["whole_network"]
    @test (whole["n_buses"], whole["n_physical_edges"], whole["cycle_rank"]) == (5, 7, 3)
    @test whole["cycle_rank"] == whole["simple_cycle_rank"] + whole["parallel_excess"]
    @test (whole["simple_cycle_rank"], whole["parallel_excess"],
           whole["transformer_mediated_cycle_rank"]) == (2, 1, 1)
    @test length(s["cycle_closing_branches"]) == whole["cycle_rank"]
    @test all(haskey(w, "component_id") for w in s["cycle_closing_branches"])
    mesh_findings = Finding[]
    connectivity_analysis(net, mesh_findings; voltage_levels=levels)
    mesh = only(filter(f -> f.code == "W.CONN.MESHED", mesh_findings))
    @test mesh.detail["simple_cycle_rank"] == 2
    @test mesh.detail["parallel_excess"] == 1
    @test mesh.detail["transformer_mediated_cycle_rank"] == 1
    @test mesh.detail["cycle_closing_branches"] == s["cycle_closing_branches"]
    tiers = Dict(t["level"] => t for t in s["voltage_tiers"])
    @test tiers["MV"]["cycle_rank"] == 2
    @test tiers["LV"]["cycle_rank"] == 0
    @test s["n_cross_tier_edges"] == 2
    @test length(s["galvanic_zones"]) == 2
    @test maximum(z["n_incident_isolating_transformers"] for z in s["galvanic_zones"]) == 2
    @test s["parallel_lines"]["classification_counts"]["same_declared_fields"] == 1
    net["line"]["ab2"]["meta"] = Dict("different_record" => true)
    @test BMOPFTools._topology_structure(net, levels)["parallel_lines"]["classification_counts"]["same_declared_fields"] == 1
    delete!(net["line"]["ab2"], "meta")
    reordered = deepcopy(net)
    reordered["line"] = Dict(reverse(collect(net["line"])))
    @test BMOPFTools._topology_structure(reordered, levels) == s
    closed = deepcopy(net)
    closed["switch"]["open"]["open_switch"] = false
    closed_structure = BMOPFTools._topology_structure(closed, levels)
    @test closed_structure["whole_network"]["cycle_rank"] == 4
    @test length(closed_structure["galvanic_zones"]) == 1

    # An incomplete map takes precedence over field comparison; the physical
    # cycle and all member IDs remain visible even on a malformed input.
    delete!(net["line"]["ab2"], "terminal_map_to")
    push!(net["line"], "bad" => line("a", "absent"))
    malformed = BMOPFTools._topology_structure(net, levels)
    @test malformed["n_skipped_branches"] == 1
    @test malformed["whole_network"]["cycle_rank"] == 3
    @test malformed["parallel_lines"]["classification_counts"]["incomplete_terminal_map"] == 1
    @test malformed["parallel_lines"]["witnesses"][1]["line_ids"] == ["ab1", "ab2"]
    net["line"]["ab2"]["terminal_map_to"] = ["2", "n"]
    mismatch = BMOPFTools._topology_structure(net, levels)
    @test mismatch["parallel_lines"]["classification_counts"]["terminal_map_disagreement"] == 1
    net["line"]["ab2"]["terminal_map_to"] = ["1", "n"]
    net["line"]["ab2"]["length"] = 2.0
    @test BMOPFTools._topology_structure(net, levels)["parallel_lines"]["classification_counts"]["different_declared_fields"] == 1

    sample_lines = Dict{String,Any}()
    for i in 1:7
        sample_lines["first$i"] = line("p$i", "p$(i+1)")
        sample_lines["second$i"] = i < 7 ?
            line("p$i", "p$(i+1)"; to=["2", "n"]) :
            line("p$i", "p$(i+1)"; length=2.0)
    end
    sample_net = Dict{String,Any}(
        "bus" => Dict("p$i" => Dict{String,Any}() for i in 1:8),
        "line" => sample_lines)
    sampled = BMOPFTools._topology_structure(sample_net, Dict{String,Any}())["parallel_lines"]
    @test sampled["classification_counts"]["terminal_map_disagreement"] == 6
    @test count(w -> w["classification"] == "terminal_map_disagreement", sampled["witnesses"]) == 5
    @test count(w -> w["classification"] == "different_declared_fields", sampled["witnesses"]) == 1

    # Empty and source-unassigned networks have explicit, serializable counts.
    empty = BMOPFTools._topology_structure(Dict{String,Any}(), Dict{String,Any}())
    @test empty["whole_network"]["cycle_rank"] == 0
    @test isempty(empty["galvanic_zones"])
    unassigned = BMOPFTools._topology_structure(net, Dict{String,Any}())
    @test only(unassigned["voltage_tiers"])["level"] == "unassigned"
    roundtrip = JSON3.read(JSON3.write(BMOPFTools._jsonable(s)))
    @test roundtrip.whole_network.cycle_rank == 3
    @test roundtrip.parallel_lines.witnesses[1].line_ids == ["ab1", "ab2"]
    @test length(roundtrip.cycle_closing_branches) == 3

    # A bus-level path can hide a missing phase path. Transformer winding ports
    # and sources bound the line/switch graph without assuming phase conversion.
    terminal_net = Dict{String,Any}(
        "bus" => Dict(b => Dict("terminal_names" => ["1", "2", "n"])
                      for b in ("src", "mid", "end")),
        "voltage_source" => Dict("source" => Dict("bus" => "src",
                                                "terminal_map" => ["1", "2", "n"])),
        "line" => Dict("a" => line("src", "mid"; from=["1", "n"], to=["1", "n"]),
                       "b" => line("mid", "end"; from=["2", "n"], to=["2", "n"])),
        "load" => Dict("load" => Dict("bus" => "end", "terminal_map" => ["2", "n"])))
    paths = BMOPFTools._topology_structure(terminal_net, Dict{String,Any}())["conductor_paths"]
    @test paths["status"] == "assessed"
    @test paths["n_load_terminals_without_boundary"] == 1
    @test only(paths["load_terminal_witnesses"])["terminal"] == "2"
    terminal_net["line"]["a"]["terminal_map_from"] = ["1", "2", "n"]
    terminal_net["line"]["a"]["terminal_map_to"] = ["1", "2", "n"]
    @test BMOPFTools._topology_structure(terminal_net, Dict{String,Any}())[
        "conductor_paths"]["n_load_terminals_without_boundary"] == 0
    terminal_net["switch"] = Dict("open" => Dict("bus_from" => "src", "bus_to" => "end",
        "terminal_map_from" => ["2"], "terminal_map_to" => ["2"], "open_switch" => true))
    @test BMOPFTools._topology_structure(terminal_net, Dict{String,Any}())[
        "conductor_paths"]["n_mapped_conductor_edges"] == 5
    terminal_net["switch"]["open"]["open_switch"] = false
    @test BMOPFTools._topology_structure(terminal_net, Dict{String,Any}())[
        "conductor_paths"]["n_mapped_conductor_edges"] == 6
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(paths))).n_load_terminals_without_boundary == 1
end
