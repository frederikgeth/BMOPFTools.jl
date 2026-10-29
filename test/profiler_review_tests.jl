using Test, BMOPFTools, JSON3

_review_profile_fixture() = JSON3.read(read(joinpath(@__DIR__, "data", "profiler_evidence", "two_boundary_chain.json"), String), Dict{String,Any})
_review_reach(net; config=load_config()) = BMOPFTools._feeder_length_check(net, BMOPFTools._galvanic_zones(net), Finding[], config)
_review_chain(rows) = only(filter(r -> r["n_buses"] == 5, rows))

@testset "profiler review source completeness" begin
    net = _review_profile_fixture()
    # A known source in the assessed zone does not resolve an invalid external
    # source. The external component reaches the port via a supported transformer.
    net["voltage_source"] = Dict{String,Any}(
        "known" => Dict("bus"=>"a", "terminal_map"=>["a"], "v_magnitude"=>[230.0]),
        "incomplete" => Dict("bus"=>"up", "terminal_map"=>["a"]))
    net["bus"]["via"] = Dict("terminal_names"=>["a","n"])
    tx(from, to) = Dict("windings"=>[Dict("bus"=>b, "terminal_map"=>["a","n"], "configuration"=>"WYE", "v_nom"=>230.0) for b in (from,to)])
    net["transformer"] = Dict("n_winding"=>Dict("port"=>tx("via","a"), "external"=>tx("up","via")))
    original = deepcopy(net)
    row = _review_chain(_review_reach(net))
    @test net == original
    @test row["status"] == "indeterminate"
    @test row["boundary_reach_m"] === nothing
    @test any(p -> p["kind"] == "transformer" && p["qualification"] == "unresolved", row["boundaries"])
    # With no additional source declaration this is an ordinary non-source stub.
    delete!(net["voltage_source"], "incomplete")
    @test _review_chain(_review_reach(net))["status"] == "assessed"

    # Permuting explicitly matched source coordinates must not alter the guard.
    net = _review_profile_fixture(); empty!(net["transformer"])
    for bus in values(net["bus"]); bus["terminal_names"] = ["a","b","c","n"]; end
    source = Dict{String,Any}("bus"=>"a", "terminal_map"=>["b","a","c"], "v_magnitude"=>[230.0,220.0,240.0])
    net["voltage_source"] = Dict("source"=>source)
    first = _review_chain(_review_reach(net))
    source["terminal_map"] = ["a","b","c"]; source["v_magnitude"] = [220.0,230.0,240.0]
    second = _review_chain(_review_reach(net))
    @test first["status"] == second["status"] == "indeterminate"
    source["v_magnitude"] = [230.0,232.0,235.0]
    @test _review_chain(_review_reach(net))["status"] == "assessed"
end

@testset "profiler review malformed evidence" begin
    net = _review_profile_fixture()
    net["switch"] = Dict("dangling"=>Dict("bus_from"=>"a", "bus_to"=>"missing", "open_switch"=>false))
    row = _review_chain(_review_reach(net))
    @test row["status"] == "indeterminate"
    @test "switch:dangling:invalid_endpoints" in row["invalid_branches"]
    net["switch"]["dangling"]["open_switch"] = true
    @test _review_chain(_review_reach(net))["status"] == "assessed"
    for threshold in (-1.0, Inf, "unknown")
        cfg = load_config(); cfg["operational"]["feeder_length"]["LV"]["multi_boundary"] = Dict("reach_long_m"=>threshold)
        row = _review_chain(_review_reach(_review_profile_fixture(); config=cfg))
        @test row["status"] == "assessed"
        @test row["threshold_status"] == "indeterminate"
        @test row["threshold_reason"] == "invalid_threshold_policy"
    end
    cfg = load_config(); cfg["operational"]["feeder_length"]["LV"]["multi_boundary"] = 42
    @test _review_chain(_review_reach(_review_profile_fixture(); config=cfg))["threshold_reason"] == "invalid_threshold_policy"

    net = _review_profile_fixture()
    ws = net["transformer"]["n_winding"]["left"]["windings"]
    ws[1]["i_max"] = -1.0
    coverage = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test coverage["transformers"][1]["coverage"] == "malformed"
    @test coverage["transformers"][1]["reason"] == "invalid_cap_declaration"
    ws[1] = nothing
    coverage = BMOPFTools._winding_limit_coverage(net, Finding[])
    @test coverage["transformers"][1]["coverage"] == "malformed"
    @test coverage["transformers"][1]["reason"] == "invalid_winding_map"
end

@testset "profiler review exact repetition and report noise" begin
    # Float64 conversion would make two different Int64 declarations identical.
    loads = Dict("l$i"=>Dict("p_nom"=>[2^53 + (i % 2)], "q_nom"=>[0]) for i in 1:4)
    net = Dict{String,Any}("load"=>loads); fs = Finding[]
    repeat = BMOPFTools._load_repeat_evidence(loads)
    @test repeat["n_distinct_pq_tuples"] == 2
    @test repeat["largest_group_count"] == 2
    @test BMOPFTools._load_diversity(net, fs)["n_distinct_pq_tuples"] == 2
    @test !any(f -> f.code == "W.DIV.LOAD_SYMMETRIC", fs)
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(repeat))).n_distinct_pq_tuples == 2

    net = _review_profile_fixture(); net["line"]["parallel"] = deepcopy(net["line"]["0"])
    report = analyze(net)
    for renderer in (BMOPFTools.render_terminal, BMOPFTools.render_markdown)
        io = IOBuffer(); renderer(report, io); output = String(take!(io))
        @test count("Parallel declaration evidence:", output) == 1
        @test occursin("Multiplicity", output)
        @test !occursin("| Bus pair | Line IDs | Declared-field class |", output)
    end
end

@testset "profiler weighted paths against all-pairs oracle" begin
    # Finite, hand-declared five-bus multigraphs cover zero-weight ties, unequal
    # parallel members, loops and an unreachable bus. Floyd-Warshall is independent
    # of the production heap/frontier traversal. No random generator or solver.
    cases = [
        [(1,2,2), (2,3,3), (3,4,4), (4,5,5)],
        [(1,2,9), (1,2,1), (2,3,2), (3,4,3), (4,5,4), (1,5,20)],
        [(1,2,0), (2,3,0), (3,1,0), (3,4,2), (4,5,1), (2,5,5)],
        [(1,2,3), (2,3,1), (3,4,2)],
    ]
    for edges in cases
        net = Dict{String,Any}("bus"=>Dict(string(i)=>Dict() for i in 1:5), "line"=>Dict(
            string(k)=>Dict("bus_from"=>string(a), "bus_to"=>string(b), "length"=>Float64(w))
            for (k,(a,b,w)) in enumerate(edges)))
        zone = Set(string.(1:5)); graph = BMOPFTools._reach_graph(net, [zone])
        D = fill(Inf,5,5)
        for i in 1:5; D[i,i] = 0.0; end
        for (a,b,w) in edges; D[a,b] = D[b,a] = min(D[a,b], w); end
        for k in 1:5, i in 1:5, j in 1:5; D[i,j] = min(D[i,j], D[i,k]+D[k,j]); end
        for starts in ([1], [1,5], [2,4])
            tree = BMOPFTools._reach_distances(graph.adj, zone, string.(starts))
            for b in 1:5
                @test get(tree.dist, string(b), Inf) == minimum(D[starts,b])
            end
            for b in keys(tree.dist)
                @test BMOPFTools._reach_path(tree,b)["n_path_edges"] < 5
            end
        end
    end
end

@testset "profiler review coordinate and component invariance" begin
    # A maximum deviation from the first diagonal can change under a permutation.
    # Full pairwise spread gives the same candidate in every ordered coordinate set.
    candidate = function (diagonals)
        lc = Dict{String,Any}("R_series_$(i)_$(j)" => (i == j ? diagonals[i] : 1.008) for i in 1:3 for j in 1:3)
        merge!(lc, Dict("X_series_$(i)_$(j)" => (i == j ? 3.0 : 0.3) for i in 1:3 for j in 1:3))
        net = Dict{String,Any}("linecode"=>Dict("matrix"=>lc)); fs = Finding[]
        r = BMOPFTools._classify_impedance_transformation(net, fs, BMOPFTools._classify_linecodes(net, fs))
        r["by_linecode"]["matrix"]
    end
    @test candidate([2.0,2.016,2.032]) == candidate([2.016,2.0,2.032]) == "unknown"
    @test candidate(fill(2.016,3)) == "modified_phase_to_neutral"

    net = _review_profile_fixture()
    net["bus"]["other"] = Dict("terminal_names"=>["a","n"])
    net["voltage_source"]["second"] = Dict("bus"=>"other", "terminal_map"=>["a"], "v_magnitude"=>[11000*sqrt(3.0)])
    bridge = deepcopy(net["transformer"]["n_winding"]["left"])
    bridge["windings"][2]["bus"] = "other"; bridge["windings"][2]["v_nom"] = 11000*sqrt(3.0)
    net["transformer"]["n_winding"]["bridge"] = bridge
    zones = BMOPFTools._galvanic_zones(net); original_zones = deepcopy(zones)
    forward = BMOPFTools._feeder_length_check(net, zones, Finding[], load_config())
    backward = BMOPFTools._feeder_length_check(net, reverse(zones), Finding[], load_config())
    @test forward == backward
    @test zones == original_zones
    @test _review_chain(forward)["boundary_reach_m"] == 200.0
    @test _review_chain(forward)["voltage_rtol"] == 0.05
    @test all(p -> p["energization"] == "unassessed" && p["supply_direction"] == "unassessed", _review_chain(forward)["boundaries"])
    net["voltage_source"]["second"]["v_magnitude"] = [15000.0]
    @test _review_chain(_review_reach(net))["status"] == "indeterminate"
end

@testset "profiler review coverage reasons and presentation groups" begin
    net = _review_profile_fixture()
    ws = net["transformer"]["n_winding"]["left"]["windings"]
    ws[1]["i_max"] = -1.0
    c = BMOPFTools._winding_limit_coverage(net, Finding[])
    ledger = BMOPFTools._assessment_coverage(Dict(:operational=>Dict("winding_limit_coverage"=>c)))
    limits = only(filter(c -> c["check"] == "winding_limits", ledger["checks"]))
    @test limits["reason_counts"]["invalid_cap_declaration"] == 1
    ws[1]["i_max"] = 1.0; net["transformer"]["n_winding"]["left"]["tap"] = 1.0
    @test BMOPFTools._winding_limit_coverage(net, Finding[])["transformers"][1]["status"] == "inapplicable"

    net = _review_profile_fixture()
    net["bus"]["radial"] = Dict{String,Any}("terminal_names"=>["a","n"])
    third = deepcopy(net["transformer"]["n_winding"]["left"]); third["windings"][2]["bus"] = "radial"
    net["transformer"]["n_winding"]["third"] = third
    net["load"]["radial"] = Dict("bus"=>"radial", "terminal_map"=>["a","n"], "configuration"=>"WYE", "p_nom"=>[50.0], "q_nom"=>[10.0])
    report = analyze(net)
    for renderer in (BMOPFTools.render_terminal, BMOPFTools.render_markdown)
        io = IOBuffer(); renderer(report,io); output = String(take!(io))
        @test occursin("Radial component estimates (1)",output)
        @test occursin("Upper-bound estimates (2)",output)
    end
    cfg = load_config(); cfg["operational"]["feeder_length"]["LV"]["multi_boundary"] = Dict("reach_long_m"=>0.0, "reach_short_m"=>0.0)
    row = _review_chain(_review_reach(_review_profile_fixture(); config=cfg))
    @test row["threshold_status"] == "skipped"
    @test row["threshold_reason"] == "thresholds_disabled"
end

@testset "profiler review nominal cycle guard" begin
    net = _review_profile_fixture()
    for b in ("u1","u2"); net["bus"][b] = Dict("terminal_names"=>["a","n"]); end
    tx(from,to) = Dict("windings"=>[Dict("bus"=>b,"terminal_map"=>["a","n"],"configuration"=>"WYE","v_nom"=>11000.0) for b in (from,to)])
    sub = net["transformer"]["n_winding"]
    sub["c1"] = tx("up","u1"); sub["c2"] = tx("u1","u2"); sub["c3"] = tx("u2","up")
    @test _review_chain(_review_reach(net))["boundary_reach_m"] == 200.0
    # Well within the 5% absolute-voltage screen but outside cycle roundoff.
    # Refusal concerns the nominal mapping, not physical mesh feasibility.
    sub["c3"]["windings"][2]["v_nom"] = 11001.0
    row = _review_chain(_review_reach(net))
    @test row["status"] == "indeterminate"
    @test row["boundary_reach_m"] === nothing
end

@testset "profiler review full matrix observation" begin
    lc = Dict{String,Any}("R_series_$(i)_$(j)" => (i == j ? 2.0 : 0.0) for i in 1:3 for j in 1:3)
    merge!(lc, Dict("X_series_$(i)_$(j)" => (i == j ? 1.0 : 0.0) for i in 1:3 for j in 1:3))
    lc["R_series_2_1"] = 1.0 # explicit lower triangle contradicts the zero upper triangle
    net = Dict{String,Any}("linecode"=>Dict("asymmetric"=>lc)); fs = Finding[]
    result = BMOPFTools._classify_linecodes(net,fs)
    @test any(f -> f.code == "E.PROV.NONRECIPROCAL",fs)
    @test !any(f -> f.code in ("I.PROV.DECOUPLED_PHASES","I.PROV.SEQ_DERIVED"),fs)
    @test result["by_linecode"]["asymmetric"]["verdict"] == "distinct"
end

@testset "profiler long path witness is bounded" begin
    n = 1000; zone = Set(string.(0:n))
    net = Dict{String,Any}("bus"=>Dict(b=>Dict() for b in zone), "line"=>Dict(
        string(i)=>Dict("bus_from"=>string(i-1),"bus_to"=>string(i),"length"=>1.0) for i in 1:n))
    graph = BMOPFTools._reach_graph(net,[zone])
    tree = BMOPFTools._reach_distances(graph.adj,zone,["0",string(n)])
    @test maximum(values(tree.dist)) == 500.0
    witness = BMOPFTools._reach_path(tree,"500")
    @test witness["n_path_edges"] == 500
    @test length(witness["branch_ids_from_farthest"]) == 20
    @test witness["path_truncated"]
    @test witness["boundary_bus"] in ("0","1000")
end
