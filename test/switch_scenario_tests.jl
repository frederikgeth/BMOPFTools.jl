using Test, BMOPFTools, JSON3

@testset "switch-state bus graph scenarios" begin
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
end
