using Test, BMOPFTools, JSON3

@testset "switch-state topology scenarios" begin
    edge(a, b) = Dict{String,Any}("bus_from" => a, "bus_to" => b)
    switch(a, b, open) = merge(edge(a, b), Dict{String,Any}("open_switch" => open))
    function case(buses; lines=Dict{String,Any}(), switches=Dict{String,Any}(),
                  transformers=Dict{String,Any}(), sources=String[], loads=String[])
        Dict{String,Any}(
            "bus" => Dict(b => Dict{String,Any}() for b in buses),
            "line" => lines, "switch" => switches, "transformer" => transformers,
            "voltage_source" => Dict("s$i" => Dict("bus" => b) for (i, b) in enumerate(sources)),
            "load" => Dict("l$i" => Dict("bus" => b) for (i, b) in enumerate(loads)))
    end
    function witness(result, id)
        only(filter(w -> w["switch_id"] == id, result["witnesses"]))
    end

    no_switch = case(["a", "b"]; lines=Dict("ab" => edge("a", "b")))
    none = BMOPFTools._switch_scenarios(no_switch)
    @test none["status"] == "inapplicable"
    @test none["switch_counts"]["n_records"] == 0
    @test connectivity_analysis(no_switch, Finding[])["switch_scenarios"] == none

    open_net = case(["a", "b", "c", "d", "e", "g"];
        lines=Dict("ab" => edge("a", "b"), "bc" => edge("b", "c"),
                   "de" => edge("d", "e")),
        switches=Dict("tie_sources" => switch("c", "d", true),
                      "tie_island" => switch("b", "g", true),
                      "cycle" => switch("a", "c", true),
                      "parallel" => switch("a", "b", true)),
        sources=["a", "d"], loads=["e", "g"])
    result = BMOPFTools._switch_scenarios(open_net)
    @test result["status"] == "assessed"
    @test result["switch_counts"]["n_assessed"] == 4
    @test result["declared"]["n_components"] == 3
    @test result["declared"]["n_buses_without_source_path"] == 1
    @test result["declared"]["n_loads_without_source_path"] == 1
    @test result["fixed_backbone"]["n_components"] == 3
    @test result["all_closed_envelope"]["n_components"] == 1
    @test result["all_closed_envelope"]["n_components_with_multiple_sources"] == 1
    @test result["all_closed_envelope"]["cycle_rank"] == 2
    @test result["all_closed_envelope"]["parallel_excess"] == 1
    @test result["transition_counts"]["classifications"] ==
        Dict("component_join" => 2, "cycle_closure" => 1,
             "parallel_closure" => 1, "bridge" => 0, "alternate_path" => 0)
    @test result["transition_counts"]["n_source_component_joins"] == 1
    @test result["transition_counts"]["n_switches_gaining_source_path"] == 1
    @test witness(result, "tie_sources")["joins_source_components"]
    @test witness(result, "tie_island")["n_buses_gaining_source_path"] == 1
    @test witness(result, "tie_island")["n_loads_gaining_source_path"] == 1
    @test witness(result, "cycle")["delta_cycle_rank"] == 1
    @test witness(result, "parallel")["classification"] == "parallel_closure"
    @test BMOPFTools._topology_structure(open_net, Dict{String,Any}())[
        "whole_network"]["n_physical_edges"] == result["declared"]["n_physical_edges"]
    declared_findings = Finding[]
    connectivity_analysis(open_net, declared_findings)
    @test count(f -> f.code == "E.CONN.DISCONNECTED", declared_findings) == 1
    @test all(f -> f.code != "W.CONN.MESHED", declared_findings)

    # Every single-switch graph transition obeys the reported physical cycle
    # and component deltas, including a parallel member.
    for id in keys(open_net["switch"])
        changed = deepcopy(open_net)
        changed["switch"][id]["open_switch"] = false
        after = BMOPFTools._switch_scenarios(changed)["declared"]
        w = witness(result, id)
        @test after["n_components"] - result["declared"]["n_components"] == w["delta_components"]
        @test after["cycle_rank"] - result["declared"]["cycle_rank"] == w["delta_cycle_rank"]
    end
    reordered = deepcopy(open_net)
    reordered["switch"] = Dict(reverse(collect(open_net["switch"])))
    reordered["line"] = Dict(reverse(collect(open_net["line"])))
    @test BMOPFTools._switch_scenarios(reordered) == result

    closed_net = case(["a", "b", "c", "d"];
        lines=Dict("ab" => edge("a", "b"), "cd" => edge("c", "d")),
        switches=Dict("bridge" => switch("b", "c", false),
                      "parallel" => switch("a", "b", false)),
        sources=["a"], loads=["c", "d"])
    closed = BMOPFTools._switch_scenarios(closed_net)
    @test closed["declared"]["n_components"] == 1
    @test closed["fixed_backbone"]["n_components"] == 2
    @test closed["declared"]["cycle_rank"] == 1
    @test closed["transition_counts"]["classifications"]["bridge"] == 1
    @test closed["transition_counts"]["classifications"]["alternate_path"] == 1
    @test witness(closed, "bridge")["n_buses_losing_source_path"] == 2
    @test witness(closed, "bridge")["n_loads_losing_source_path"] == 2
    @test witness(closed, "parallel")["delta_cycle_rank"] == -1
    for id in keys(closed_net["switch"])
        changed = deepcopy(closed_net)
        changed["switch"][id]["open_switch"] = true
        after = BMOPFTools._switch_scenarios(changed)["declared"]
        w = witness(closed, id)
        @test after["n_components"] - closed["declared"]["n_components"] == w["delta_components"]
        @test after["cycle_rank"] - closed["declared"]["cycle_rank"] == w["delta_cycle_rank"]
    end

    # A transformer creates an alternate bus path, without assessing winding
    # compatibility or source energization.
    xfmr_net = case(["a", "b", "c"];
        lines=Dict("ab" => edge("a", "b")),
        switches=Dict("bc" => switch("b", "c", false)),
        transformers=Dict("delta_wye" => Dict("ac" => edge("a", "c"))))
    @test witness(BMOPFTools._switch_scenarios(xfmr_net), "bc")["classification"] ==
        "alternate_path"

    malformed = deepcopy(open_net)
    delete!(malformed["switch"]["cycle"], "open_switch")
    uncertain = BMOPFTools._switch_scenarios(malformed)
    @test uncertain["status"] == "indeterminate"
    @test uncertain["assessment"]["invalid_switch_ids"] == ["cycle"]
    @test !haskey(uncertain, "declared")
    malformed["switch"]["cycle"]["open_switch"] = true
    malformed["switch"]["cycle"]["bus_to"] = "absent"
    @test BMOPFTools._switch_scenarios(malformed)["status"] == "indeterminate"
    malformed["switch"]["cycle"]["bus_to"] = "a"
    @test BMOPFTools._switch_scenarios(malformed)["status"] == "indeterminate"
    bad_line = deepcopy(closed_net)
    bad_line["line"]["absent"] = edge("a", "missing")
    @test BMOPFTools._switch_scenarios(bad_line)["assessment"]["skipped_branch_ids"] ==
        ["line:absent"]

    # Bus-graph results remain applicable when conductor maps are incomplete.
    partial = deepcopy(closed_net)
    partial["switch"]["bridge"]["terminal_map_from"] = ["1"]
    @test BMOPFTools._switch_scenarios(partial)["status"] == "assessed"
    @test closed["assessment"]["conductor_status"] == "inapplicable"
    roundtrip = JSON3.read(JSON3.write(BMOPFTools._jsonable(result)))
    @test roundtrip.transition_counts.classifications.component_join == 2
    @test roundtrip.witnesses[1].switch_id == "cycle"
    @test roundtrip.declared.n_buses_without_source_path == 1

    # Iterative bridge search handles a long switch chain without recursion or
    # a graph traversal for each switch.
    n = 1500
    chain = case(["b$i" for i in 1:n];
        switches=Dict("s$i" => switch("b$i", "b$(i+1)", false) for i in 1:n-1),
        sources=["b1"], loads=["b$n"])
    long_result = BMOPFTools._switch_scenarios(chain)
    @test long_result["transition_counts"]["classifications"]["bridge"] == n - 1
    @test long_result["declared"]["n_components"] == 1
    @test length(long_result["witnesses"]) == 5

    mapped(a, b, from, to) = merge(edge(a, b), Dict{String,Any}(
        "terminal_map_from" => from, "terminal_map_to" => to))
    mapped_switch(a, b, from, to, open) = merge(
        mapped(a, b, from, to), Dict{String,Any}("open_switch" => open))
    terminal_net = Dict{String,Any}(
        "bus" => Dict(b => Dict("terminal_names" => ["1", "2", "n"])
                      for b in ("a", "b", "c")),
        "line" => Dict("ab" => mapped("a", "b", ["1"], ["1"]),
                       "bc" => mapped("b", "c", ["1"], ["1"])),
        "switch" => Dict(
            "phase" => mapped_switch("a", "c", ["2"], ["2"], true),
            "neutral" => mapped_switch("a", "b", ["n"], ["n"], false),
            "parallel" => mapped_switch("a", "b", ["1"], ["1"], false),
            "loop" => mapped_switch("a", "c", ["1"], ["1"], true)),
        "voltage_source" => Dict("source" => Dict(
            "bus" => "a", "terminal_map" => ["1", "2", "n"])),
        "load" => Dict(
            "phase_load" => Dict("bus" => "c", "terminal_map" => ["2"]),
            "neutral_load" => Dict("bus" => "b", "terminal_map" => ["n"])))
    terminal_result = BMOPFTools._switch_scenarios(terminal_net)
    conductor = terminal_result["conductor"]
    @test conductor["status"] == "assessed"
    @test conductor["declared"]["n_load_terminals_without_boundary"] == 1
    @test conductor["all_closed_envelope"]["n_load_terminals_without_boundary"] == 0
    @test conductor["transition_counts"]["classifications"] ==
        Dict("path_merge" => 1, "path_split" => 1, "no_path_change" => 2)
    @test conductor["transition_counts"]["n_switches_gaining_load_boundary_path"] == 1
    @test conductor["transition_counts"]["n_switches_losing_load_boundary_path"] == 1
    @test conductor["cross_layer_counts"]["cycle_closure|path_merge"] == 1
    @test conductor["cross_layer_counts"]["alternate_path|path_split"] == 1
    conductor_witness(id) = only(filter(w -> w["switch_id"] == id,
                                        conductor["witnesses"]))
    @test conductor_witness("phase")["n_load_terminals_gaining_boundary_path"] == 1
    @test conductor_witness("phase")["bus_graph_classification"] == "cycle_closure"
    @test conductor_witness("neutral")["n_load_terminals_losing_boundary_path"] == 1
    @test conductor_witness("parallel")["delta_path_components"] == 0
    @test conductor_witness("loop")["delta_path_components"] == 0
    @test witness(terminal_result, "phase")["delta_components"] == 0
    @test BMOPFTools._topology_structure(terminal_net, Dict{String,Any}())[
        "conductor_paths"]["n_path_components"] == conductor["declared"]["n_path_components"]
    @test conductor["assessment"]["n_group_cut_fallbacks"] == 0
    reordered_terminal = deepcopy(terminal_net)
    reordered_terminal["switch"] = Dict(reverse(collect(terminal_net["switch"])))
    reordered_terminal["line"] = Dict(reverse(collect(terminal_net["line"])))
    @test BMOPFTools._switch_scenarios(reordered_terminal)["conductor"] == conductor
    roundtrip_conductor = JSON3.read(JSON3.write(BMOPFTools._jsonable(conductor)))
    @test roundtrip_conductor.witnesses[2].n_load_terminals_losing_boundary_path == 1

    incomplete = deepcopy(terminal_net)
    delete!(incomplete["switch"]["phase"], "terminal_map_to")
    incomplete_result = BMOPFTools._switch_scenarios(incomplete)
    @test incomplete_result["status"] == "assessed"
    @test incomplete_result["conductor"]["status"] == "inapplicable"
    @test incomplete_result["conductor"]["assessment"]["invalid_branch_map_ids"] ==
        ["switch:phase"]
    incomplete_bus = deepcopy(terminal_net)
    delete!(incomplete_bus["bus"]["c"], "terminal_names")
    @test BMOPFTools._switch_scenarios(incomplete_bus)["conductor"][
        "assessment"]["invalid_bus_ids"] == ["c"]
    no_boundary = deepcopy(terminal_net)
    empty!(no_boundary["voltage_source"])
    @test BMOPFTools._switch_scenarios(no_boundary)["conductor"]["status"] ==
        "indeterminate"

    # Two mapped pairs in distinct path components use the bridge fast path.
    two_phase = Dict{String,Any}(
        "bus" => Dict(b => Dict("terminal_names" => ["1", "2"]) for b in ("a", "b")),
        "switch" => Dict("sw" => mapped_switch("a", "b", ["1", "2"], ["1", "2"], false)),
        "voltage_source" => Dict("src" => Dict("bus" => "a", "terminal_map" => ["1", "2"])),
        "load" => Dict("ld" => Dict("bus" => "b", "terminal_map" => ["1", "2"])))
    two_phase_result = BMOPFTools._switch_scenarios(two_phase)["conductor"]
    @test two_phase_result["assessment"]["n_group_cut_fallbacks"] == 0
    @test only(two_phase_result["witnesses"])["delta_path_components"] == 2
    @test only(two_phase_result["witnesses"])["n_load_terminals_losing_boundary_path"] == 2

    terminal_chain_n = 800
    terminal_chain = Dict{String,Any}(
        "bus" => Dict("b$i" => Dict("terminal_names" => ["1"])
                      for i in 1:terminal_chain_n),
        "switch" => Dict("s$i" =>
            mapped_switch("b$i", "b$(i+1)", ["1"], ["1"], false)
            for i in 1:terminal_chain_n-1),
        "voltage_source" => Dict("src" => Dict("bus" => "b1",
                                              "terminal_map" => ["1"])),
        "load" => Dict("ld" => Dict("bus" => "b$terminal_chain_n",
                                   "terminal_map" => ["1"])))
    terminal_chain_result = BMOPFTools._switch_scenarios(terminal_chain)["conductor"]
    @test terminal_chain_result["transition_counts"]["classifications"]["path_split"] ==
        terminal_chain_n - 1
    @test terminal_chain_result["assessment"]["n_group_cut_fallbacks"] == 0
    @test length(terminal_chain_result["witnesses"]) == 5

    # Individually non-bridge mapped pairs can form a group cut. The exact
    # fallback removes the whole switch, preserving the source-path result.
    group_cut = Dict{String,Any}(
        "bus" => Dict(b => Dict("terminal_names" => ["1", "2"])
                      for b in ("a", "b", "c", "d")),
        "line" => Dict(
            "ac1" => mapped("a", "c", ["1"], ["1"]),
            "ca2" => mapped("c", "a", ["1"], ["2"]),
            "bd1" => mapped("b", "d", ["1"], ["1"]),
            "db2" => mapped("d", "b", ["1"], ["2"])),
        "switch" => Dict("cut" => mapped_switch("a", "b", ["1", "2"], ["1", "2"], false)),
        "voltage_source" => Dict("src" => Dict("bus" => "a", "terminal_map" => ["1"])),
        "load" => Dict("ld" => Dict("bus" => "b", "terminal_map" => ["2"])))
    cut_result = BMOPFTools._switch_scenarios(group_cut)["conductor"]
    @test cut_result["status"] == "assessed"
    @test cut_result["assessment"]["n_group_cut_fallbacks"] == 1
    @test only(cut_result["witnesses"])["delta_path_components"] == 1
    @test only(cut_result["witnesses"])["n_load_terminals_losing_boundary_path"] == 1

    # Transformer winding ports bound paths on each side independently.
    transformer_boundary = Dict{String,Any}(
        "bus" => Dict(b => Dict("terminal_names" => ["1"]) for b in ("a", "b")),
        "switch" => Dict("tie" => mapped_switch("a", "b", ["1"], ["1"], true)),
        "transformer" => Dict("delta_wye" => Dict("t" =>
            mapped("a", "b", ["1"], ["1"]))),
        "load" => Dict("ld" => Dict("bus" => "b", "terminal_map" => ["1"])))
    boundary_result = BMOPFTools._switch_scenarios(transformer_boundary)["conductor"]
    @test boundary_result["status"] == "assessed"
    @test boundary_result["declared"]["n_boundary_components"] == 2
    @test boundary_result["declared"]["n_load_terminals_without_boundary"] == 0
    @test only(boundary_result["witnesses"])["n_load_terminals_gaining_boundary_path"] == 0
end
