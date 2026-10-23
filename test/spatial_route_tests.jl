using Test, BMOPFTools, JSON3

@testset "spatial route review candidates" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "data", "spatial_discrepancies.json"), String), Dict{String,Any})
    function result(n; kwargs...)
        cfg = load_config()
        for (k,v) in kwargs
            cfg["spatial"][string(k)] = v
        end
        BMOPFTools._spatial_analysis(n, Dict{String,Any}(); config=cfg)
    end
    checks(n; kwargs...) = result(n; kwargs...)["discrepancy_candidates"]["checks"]
    original = deepcopy(fixture)
    r = checks(fixture)
    @test fixture == original
    @test r["series_paths"]["n_candidates"] == 1
    @test r["route_overlaps"]["n_candidates"] == 1
    overlap = only(r["route_overlaps"]["witnesses"])
    @test overlap["code"] == "S.SHARED_ROUTE_SEGMENT"
    @test overlap["n_lines"] == 2
    @test !overlap["same_bus_pair"]
    @test overlap["terminal_map_relation"] == "unassessed"
    @test r["source_intervals"]["n_candidates"] == 1
    @test only(r["source_intervals"]["witnesses"])["code"] == "S.REPEATED_SOURCE_INTERVAL"
    @test r["route_endpoints"]["n_candidates"] == 1
    endpoint = only(r["route_endpoints"]["witnesses"])
    @test endpoint["code"] == "S.ROUTE_ENDPOINT_DISAGREEMENT"
    @test endpoint["line_id"] == "wrong_end"
    candidates = only(endpoint["endpoints"])["nearby_alternative_buses"]
    @test candidates["n_buses"] == 1
    @test only(candidates["buses"])["bus"]["bus_id"] == "c"
    @test only(candidates["buses"])["bus"]["terminal_names"] == ["1"]
    @test r["route_defects"]["n_candidates"] == 0
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).route_endpoints.n_candidates == 1
    rendered = sprint(io -> BMOPFTools._md_spatial(result(fixture), io))
    @test occursin("S.ROUTE_ENDPOINT_DISAGREEMENT", rendered)
    @test occursin("S.SHARED_ROUTE_SEGMENT", rendered)
    # Reversed endpoints, not an orientation-based false positive.
    reversed = deepcopy(fixture)
    reverse!(reversed["line"]["wrong_end"]["meta"]["route_geometry"]["coordinates"])
    @test only(checks(reversed)["route_endpoints"]["witnesses"])["orientation"] == "reversed"
    # Exactly the configured gap is accepted; the next smaller threshold flags it.
    gap = only(endpoint["endpoints"])["gap_m"]
    @test checks(fixture; route_endpoint_tolerance_m=gap)["route_endpoints"]["n_candidates"] == 0
    @test checks(fixture; route_endpoint_tolerance_m=prevfloat(gap))["route_endpoints"]["n_candidates"] == 1

    # Same endpoints with distinct maps remain separate circuit declarations.
    parallel = deepcopy(fixture)
    parallel["line"]["parallel"] = deepcopy(parallel["line"]["direct"])
    parallel["line"]["parallel"]["terminal_map_from"] = ["2"]
    parallel["line"]["parallel"]["terminal_map_to"] = ["2"]
    witnesses = checks(parallel)["route_overlaps"]["witnesses"]
    @test any(w -> w["same_bus_pair"] && w["terminal_map_relation"] == "different_declared_maps", witnesses)
    # Source IDs have explicit field namespaces; generic parent/raw IDs do not imply intervals.
    source = deepcopy(fixture)
    for line in values(source["line"])
        meta = get!(line, "meta", Dict{String,Any}())
        delete!(meta, "source_interval"); meta["raw_key"] = "shared-parent"
    end
    @test checks(source)["source_intervals"]["status"] == "inapplicable"
    source["line"]["ab"]["meta"]["source_interval"] = "id"
    source["line"]["bc"]["meta"]["backbone_extension"] = Dict("source_interval" => "id")
    @test checks(source)["source_intervals"]["n_candidates"] == 0
    source["line"]["direct"]["meta"]["backbone_extension"] = Dict("source_interval" => "id")
    @test checks(source)["source_intervals"]["n_candidates"] == 1

    defects = deepcopy(fixture)
    route = defects["line"]["ab"]["meta"]["route_geometry"]
    route["coordinates"] = [[153.,-27.],[153.,-27.],[153.0001,-27.],[153.,-27.]]
    dr = checks(defects; long_span_threshold_m=5.)["route_defects"]
    @test any(w -> get(w,"n_zero_segments",0) == 1 && get(w,"n_repeated_segments",0) == 1, dr["witnesses"])
    @test any(w -> get(w,"n_long_segments",0) > 0, dr["witnesses"])
    route["coordinates"] = [[153.,-27.],[NaN,-27.]]
    @test any(w -> w["code"] == "S.INVALID_ROUTE_GEOMETRY", checks(defects)["route_defects"]["witnesses"])
    route["coordinates"] = "invalid"
    @test checks(defects)["route_defects"]["n_invalid_routes"] == 1
    defects["line"]["ab"]["meta"]["route_geometry"] = true
    @test checks(defects)["route_defects"]["n_invalid_routes"] == 1
    route = Dict("basis" => "unknown", "coordinates" => [[1.,2.],[3.,4.]])
    for line in values(defects["line"])
        line["meta"] = Dict("route_geometry" => route)
    end
    @test checks(defects)["route_defects"]["status"] == "inapplicable"
    @test checks(defects)["route_overlaps"]["status"] == "inapplicable"
    # Route geometry is independently declared WGS84; an unknown bus frame
    # still prohibits assignments and bus-distance comparisons.
    unknown = deepcopy(fixture)
    delete!(unknown,"meta")
    for b in values(unknown["bus"])
        b["longitude"] += 5.
    end
    @test checks(unknown)["route_endpoints"]["status"] == "indeterminate"
    @test checks(unknown)["route_overlaps"]["n_candidates"] == 1
    partial = checks(fixture; max_topology_pairs=1)
    @test partial["route_overlaps"]["n_candidates"] === nothing
    @test partial["route_defects"]["n_candidates"] === nothing
    @test !partial["route_overlaps"]["counts_complete"]
    disabled = checks(fixture; discrepancy_enabled=false)
    @test all(c -> c["status"] == "inapplicable", values(disabled))
    reordered = deepcopy(fixture)
    reordered["line"] = Dict(reverse(collect(reordered["line"])))
    @test checks(reordered) == checks(fixture)
end
