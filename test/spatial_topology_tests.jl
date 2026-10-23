using Test, BMOPFTools, JSON3

@testset "spatial topology review candidates" begin
    function local_net(points)
        Dict{String,Any}("meta" => Dict("crs" => Dict("type" => "cartesian", "name" => "site", "units" => "m")),
            "bus" => Dict(id => Dict{String,Any}("x" => xy[1], "y" => xy[2], "terminal_names" => ["1", "N"]) for (id, xy) in points),
            "line" => Dict{String,Any}(), "switch" => Dict{String,Any}())
    end
    edge(a, b) = Dict{String,Any}("bus_from" => a, "bus_to" => b,
        "terminal_map_from" => ["1"], "terminal_map_to" => ["1"])
    function candidates(net; kwargs...)
        cfg = load_config()
        for (k,v) in kwargs
            cfg["spatial"][string(k)] = v
        end
        BMOPFTools._spatial_analysis(net, Dict{String,Any}(); config=cfg)["discrepancy_candidates"]
    end
    n = local_net(Dict("a" => (0.,0.), "b" => (0.,0.), "c" => (.5,0.), "d" => (20.,0.)))
    original = deepcopy(n)
    r = candidates(n)
    @test n == original
    near = r["checks"]["nearby_topology"]
    @test near["n_candidates"] == 3
    @test all(w -> w["code"] == "S.NEARBY_WITHOUT_DIRECT_BRANCH", near["witnesses"])
    @test all(w -> w["component_relation"] == "separate_bus_components", near["witnesses"])
    @test all(w -> w["voltage_tier_relation"] == "unknown", near["witnesses"])
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).checks.nearby_topology.n_candidates == 3
    n["line"]["ac"] = edge("a", "c")
    @test candidates(n)["checks"]["nearby_topology"]["n_candidates"] == 2
    n["switch"]["bc"] = merge(edge("b","c"), Dict("open_switch" => true))
    near = candidates(n)["checks"]["nearby_topology"]
    @test near["n_candidates"] == 1
    @test only(near["witnesses"])["component_relation"] == "separate_bus_components"
    n["switch"]["bc"]["open_switch"] = false
    @test only(candidates(n)["checks"]["nearby_topology"]["witnesses"])["component_relation"] == "same_bus_component"
    delete!(n["switch"]["bc"], "open_switch")
    @test only(candidates(n)["checks"]["nearby_topology"]["witnesses"])["component_relation"] == "unknown_switch_state"
    n["line"]["bad"] = edge("a", "missing")
    @test candidates(n)["n_invalid_branch_declarations"] == 1
    partial = candidates(original; max_topology_pairs=1)["checks"]["nearby_topology"]
    @test !partial["counts_complete"]
    @test partial["n_candidates"] === nothing
    @test partial["n_candidates_observed"] == 1
    @test candidates(original; proximity_enabled=false)["checks"]["nearby_topology"]["status"] == "inapplicable"
    @test candidates(original; discrepancy_enabled=false)["checks"]["nearby_topology"]["reason"] == "disabled"
    for opt in ((max_topology_pairs=true,), (max_series_hops=1,), (max_series_hops=65,), (long_span_threshold_m=NaN,), (route_endpoint_tolerance_m=0.,))
        @test candidates(original; opt...)["checks"]["series_paths"]["reason"] == "invalid_configuration"
    end

    chain = local_net(Dict("a" => (0.,0.), "b" => (10.,0.), "c" => (20.,0.)))
    chain["line"] = Dict("ab" => edge("a","b"), "bc" => edge("b","c"), "ac" => edge("a","c"))
    series = candidates(chain)["checks"]["series_paths"]
    @test series["n_candidates"] == 1
    @test only(series["witnesses"])["direct_branch"]["component_id"] == "ac"
    @test only(series["witnesses"])["path_chord_sum_m"] == 20.
    chain["load"] = Dict("load" => Dict("bus" => "b"))
    @test only(candidates(chain)["checks"]["series_paths"]["witnesses"])["path_buses"][2]["attachments"]["load"] == 1
    chain["bus"]["b"]["y"] = 20.
    @test candidates(chain)["checks"]["series_paths"]["n_candidates"] == 0
    chain["bus"]["b"]["y"] = 0.
    chain["switch"]["tap"] = merge(edge("b","c"), Dict("open_switch" => true))
    @test candidates(chain)["checks"]["series_paths"]["n_candidates"] == 0
    empty!(chain["switch"])
    @test candidates(chain; max_topology_pairs=1)["checks"]["series_paths"]["n_candidates"] === nothing
    @test candidates(chain; long_span_threshold_m=20.)["checks"]["branch_spans"]["n_candidates"] == 0
    span = candidates(chain; long_span_threshold_m=19.)["checks"]["branch_spans"]
    @test span["n_candidates"] == 1
    @test only(span["witnesses"])["code"] == "S.LONG_BRANCH_SPAN"
    delete!(chain, "meta")
    @test candidates(chain)["checks"]["branch_spans"]["status"] == "indeterminate"

    # Topology considers every winding, but never claims galvanic continuity.
    tnet = deepcopy(original)
    tnet["transformer"] = Dict("n_winding" => Dict("t" => Dict("windings" => [Dict("bus"=>b) for b in ("a","b","c")])))
    @test candidates(tnet)["checks"]["nearby_topology"]["n_candidates"] == 0
    @test only(candidates(tnet; long_span_threshold_m=.4)["checks"]["branch_spans"]["witnesses"])["branch"]["kind"] == "transformer:n_winding"
    # Witness limits do not truncate observed classifications or totals.
    small = candidates(original; witness_limit=1)["checks"]["nearby_topology"]
    @test length(small["witnesses"]) == 1
    @test small["component_relation_counts_observed"] == Dict("separate_bus_components" => 3)
    @test small["voltage_tier_relation_counts_observed"] == Dict("unknown" => 3)
    @test small["n_endpoint_like_pairs_observed"] == 3
    unavailable = deepcopy(original)
    unavailable["line"]["ad"] = edge("a", "d")
    delete!(unavailable["bus"]["d"], "x")
    @test candidates(unavailable)["checks"]["branch_spans"]["status"] == "indeterminate"
    @test candidates(unavailable)["checks"]["series_paths"]["status"] == "indeterminate"
    @test candidates(unavailable)["checks"]["branch_spans"]["n_components_with_unavailable_distance"] == 1
    badconfig = load_config(); badconfig["spatial"] = false
    @test all(c -> c["reason"] == "invalid_configuration", values(BMOPFTools._spatial_analysis(original, Dict{String,Any}(); config=badconfig)["discrepancy_candidates"]["checks"]))
    tiers = Dict{String,Any}("levels" => Dict("MV" => Dict("buses"=>["a"]), "LV" => Dict("buses"=>["b","c"])))
    classified = BMOPFTools._spatial_analysis(original, tiers)["discrepancy_candidates"]["checks"]["nearby_topology"]
    @test classified["voltage_tier_relation_counts_observed"] == Dict("same"=>1, "different"=>2)
    # Numeric overflow never yields a partially measured all-port span.
    overflow = local_net(Dict("a" => (-1e308,0.), "b" => (1e308,0.)))
    overflow["line"]["ab"] = edge("a","b")
    @test candidates(overflow)["checks"]["branch_spans"]["status"] == "indeterminate"
    # Stable ordering, including when input dictionary insertion order changes.
    reordered = deepcopy(original)
    reordered["bus"] = Dict(reverse(collect(reordered["bus"])))
    @test candidates(reordered) == candidates(original)
    boundary = local_net(Dict("a"=>(0.,0.),"b"=>(10.,7.5),"c"=>(20.,0.)))
    boundary["line"] = Dict("ab"=>edge("a","b"),"bc"=>edge("b","c"),"ac"=>edge("a","c"))
    @test candidates(boundary)["checks"]["series_paths"]["n_candidates"] == 1
    boundary["bus"]["b"]["y"] = 7.500001
    @test candidates(boundary)["checks"]["series_paths"]["n_candidates"] == 0
    longchain = local_net(Dict("a"=>(0.,0.),"b"=>(10.,0.),"c"=>(20.,0.),"d"=>(30.,0.)))
    longchain["line"] = Dict("ab"=>edge("a","b"),"bc"=>edge("b","c"),"cd"=>edge("c","d"),"ad"=>edge("a","d"))
    @test candidates(longchain; max_series_hops=2)["checks"]["series_paths"]["n_candidates"] == 0
    @test candidates(longchain; max_series_hops=3)["checks"]["series_paths"]["n_candidates"] == 1

end
