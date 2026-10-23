using Test, BMOPFTools, JSON3

@testset "indexed spatial proximity" begin
    function cartesian(points)
        Dict{String,Any}("meta" => Dict("coordinate_reference_system" =>
            Dict("type" => "cartesian", "name" => "test_grid", "units" => "m")),
            "bus" => Dict(string(i) => Dict{String,Any}("x" => p[1], "y" => p[2]) for (i, p) in enumerate(points)))
    end
    function proximity(net; kwargs...)
        cfg = load_config()
        for (k, v) in kwargs
            cfg["spatial"][string(k)] = v
        end
        BMOPFTools._spatial_analysis(net, Dict{String,Any}(); config=cfg)["proximity"]
    end
    net = cartesian([(0., 0.), (0., 0.), (.75, 0.), (1.5, 0.)])
    original = deepcopy(net)
    r = proximity(net)
    @test net == original
    @test r["status"] == "assessed"
    @test r["counts_complete"]
    @test r["n_near_bus_pairs"] == 3
    @test r["n_zero_distance_bus_pairs"] == 1
    @test r["n_clusters"] == 1
    @test r["n_unique_locations"] == 3
    @test only(r["cluster_witnesses"])["n_buses"] == 4
    @test r["linkage"] == "single_linkage" # endpoints are 1.5 m apart
    @test all(w -> w["distance_m"] <= 1.0, r["pair_witnesses"])
    @test proximity(net; proximity_radius_m=.74)["n_near_bus_pairs"] == 0
    @test proximity(cartesian([(0., 0.), (1., 0.)]))["n_near_bus_pairs"] == 1
    @test proximity(cartesian([(0., 0.), (nextfloat(1.), 0.)]))["n_near_bus_pairs"] == 0
    net["bus"] = Dict(reverse(collect(net["bus"])))
    @test proximity(net) == r
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).n_near_bus_pairs == 3

    for bus in values(net["bus"])
        bus["meta"] = Dict("coordinate_accuracy_m" => 0.5, "coordinate_provenance" => "interpolated")
    end
    @test all(w -> w["accuracy_context"] == "within_reported_accuracy", proximity(net)["pair_witnesses"])
    for bus in values(net["bus"])
        bus["meta"]["coordinate_accuracy_m"] = 0.01
    end
    @test all(w -> w["accuracy_context"] == "beyond_reported_accuracy", proximity(net)["pair_witnesses"])
    @test all(w -> w["accuracy_context"] == "accuracy_unreported", r["pair_witnesses"])
    @test proximity(net)["n_near_bus_pairs"] == 3 # accuracy never expands radius
    net["bus"]["3"]["meta"]["coordinate_provenance"] = "displaced"
    @test proximity(net)["n_near_bus_pairs"] == 0

    # Many identical records collapse to one indexed location. Weighted bus
    # counts are exact without materializing quadratically many pairs.
    duplicates = cartesian(vcat(fill((0., 0.), 2000), [(.5, 0.)]))
    dup = proximity(duplicates)
    @test dup["n_near_bus_pairs"] == 2000
    @test dup["n_zero_distance_bus_pairs"] == 1_999_000
    @test dup["candidate_pairs_checked"] == 1
    @test only(dup["cluster_witnesses"])["members_truncated"]
    sparse = proximity(cartesian([(10.0i, 0.) for i in 1:1000]))
    @test sparse["candidate_pairs_checked"] == 0
    @test sparse["n_near_bus_pairs"] == 0

    dense = cartesian([(0.1i, 0.) for i in 1:8])
    partial = proximity(dense; max_candidate_pairs=2, witness_limit=1)
    @test partial["status"] == "indeterminate"
    @test partial["reason"] == "candidate_budget_exhausted"
    @test partial["candidate_pairs_checked"] == 2
    @test partial["n_near_bus_pairs"] === nothing
    @test partial["n_clusters"] === nothing
    @test partial["n_near_bus_pairs_observed"] == 2
    @test length(partial["pair_witnesses"]) == 1
    @test length(partial["cluster_witnesses"]) == 1
    @test !only(partial["cluster_witnesses"])["complete"]
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(partial))).n_near_bus_pairs === nothing
    disabled = proximity(dense; proximity_enabled=false)
    @test disabled["status"] == "inapplicable"
    @test disabled["reason"] == "disabled"
    for options in ((proximity_radius_m=0.,), (proximity_radius_m=-1.,),
                    (proximity_radius_m=NaN,), (proximity_radius_m=true,),
                    (max_candidate_pairs=0,), (max_candidate_pairs=true,),
                    (witness_limit=1.5,), (proximity_enabled="yes",))
        @test proximity(dense; options...)["reason"] == "invalid_configuration"
    end
    @test proximity(dense; proximity_radius_m=1e-30)["reason"] == "index_numeric_range"

    function geographic(points)
        Dict{String,Any}("crs" => "WGS84", "bus" =>
            Dict(string(i) => Dict("longitude" => p[1], "latitude" => p[2]) for (i, p) in enumerate(points)))
    end
    seam = geographic([(179.999997, 0.), (-179.999997, 0.)])
    @test proximity(seam)["n_near_bus_pairs"] == 1
    pole = geographic([(0., 90.), (170., 90.), (0., 89.999995)])
    @test proximity(pole)["n_zero_distance_bus_pairs"] == 1
    @test proximity(pole)["n_near_bus_pairs"] == 2
    @test proximity(geographic([(180., 0.), (-180., 0.)]))["n_zero_distance_bus_pairs"] == 1
    for i in 1:30
        a = (153. + i * 1e-5, -27. + i * 1e-5)
        b = (a[1] + 1e-5, a[2] - 1e-5)
        boundary_radius = BMOPFTools._spatial_haversine(a, b)
        @test proximity(geographic([a, b]); proximity_radius_m=boundary_radius)["n_near_bus_pairs"] == 1
        @test proximity(geographic([a, b]); proximity_radius_m=prevfloat(boundary_radius))["n_near_bus_pairs"] == 0
    end
    delete!(seam, "crs")
    @test proximity(seam)["status"] == "indeterminate"
    seam["crs"] = "EPSG:28356"
    @test proximity(seam)["status"] == "inapplicable"

    # Deterministic finite clouds checked against a brute-force distance oracle;
    # these exercise bucket boundaries and different latitudes without timing assertions.
    for latitude in (0., -27., 89.9), radius in (0.2, 1., 5.)
        points = [(153. + mod(i * 17, 97) * 1e-6, latitude + mod(i * 31, 89) * 1e-6) for i in 1:50]
        expected = sum(0 < BMOPFTools._spatial_haversine(points[i], points[j]) <= radius
                       for i in 1:50 for j in 1:i-1)
        @test proximity(geographic(points); proximity_radius_m=radius)["n_near_bus_pairs"] == expected
    end
    for radius in (.2, 1., 5.)
        points = [(mod(i * 17, 97) / 10, mod(i * 31, 89) / 10) for i in 1:70]
        expected = sum(0 < hypot(points[i][1]-points[j][1], points[i][2]-points[j][2]) <= radius
                       for i in 1:70 for j in 1:i-1)
        @test proximity(cartesian(points); proximity_radius_m=radius)["n_near_bus_pairs"] == expected
    end

    # Configuration reaches the public analysis path and survives user TOML merging.
    mktemp() do path, io
        write(io, "[spatial]\nproximity_radius_m = 0.25\nproximity_enabled = false\n")
        close(io)
        cfg = load_config(path)
        sample = parse_bmopf(joinpath(@__DIR__, "..", "recipes", "analyze_case", "input.json"))
        sample["meta"] = Dict("crs" => "WGS84")
        for (i, bus) in enumerate(values(sample["bus"]))
            bus["longitude"] = 153. + i * 1e-6
            bus["latitude"] = -27.
        end
        report = analyze(sample; config=cfg)
        p = report.results[:connectivity]["spatial"]["proximity"]
        @test p["reason"] == "disabled"
        @test p["radius_m"] == .25
        @test cfg["spatial"]["max_candidate_pairs"] == 1_000_000
        out = IOBuffer()
        BMOPFTools.render_json(report, out)
        @test JSON3.read(String(take!(out))).results.connectivity.spatial.proximity.reason == "disabled"
    end
end
