# Time-series support — is_timeseries / get_snapshot semantics plus the
# t_index kwarg threaded through analyze / solve_opf / profile_solution.
# Included from runtests.jl (which defines `_HAS_JUMP_IPOPT` and loads
# JuMP/Ipopt when available) — the OPF section is gated on that flag.

# Minimal self-contained 3-phase net: source → line → WYE load.
_ts_mini_net() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
           "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
    "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
           "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
     "linecode":"lc","length":2.0}},
 "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[1000.0,2000.0,3000.0],"q_nom":[100.0,200.0,300.0]}}}
"""; from_string=true)

@testset "Time-series support" begin

    @testset "is_timeseries edge cases" begin
        # plain snapshot network
        net = _ts_mini_net()
        @test !is_timeseries(net)

        # root time_series present but NO component references it → snapshot
        net_root_only = deepcopy(net)
        net_root_only["time_series"] = Dict{String,Any}(
            "s1" => Dict{String,Any}("values" => [0.5, 1.0]))
        @test !is_timeseries(net_root_only)

        # component reference present but no root collection → snapshot
        net_ref_only = deepcopy(net)
        net_ref_only["load"]["ld"]["time_series"] = Dict{String,Any}("p_nom" => "s1")
        @test !is_timeseries(net_ref_only)

        # component reference + EMPTY root collection → snapshot
        net_empty_root = deepcopy(net_ref_only)
        net_empty_root["time_series"] = Dict{String,Any}()
        @test !is_timeseries(net_empty_root)

        # both present → time-series network
        net_ts = deepcopy(net_ref_only)
        net_ts["time_series"] = Dict{String,Any}(
            "s1" => Dict{String,Any}("values" => [0.5, 1.0]))
        @test is_timeseries(net_ts)
    end

    @testset "get_snapshot — multiplicative resolution" begin
        net = _ts_mini_net()
        net["time_series"] = Dict{String,Any}(
            "shape"  => Dict{String,Any}("values" => [0.5, 1.0, 1.5]),
            "double" => Dict{String,Any}("values" => [2.0, 2.0, 2.0]))
        # vector parameter (per-phase load) and scalar parameter (line length)
        net["load"]["ld"]["time_series"] =
            Dict{String,Any}("p_nom" => "shape", "q_nom" => "shape")
        net["line"]["l1"]["time_series"] = Dict{String,Any}("length" => "double")

        snap = get_snapshot(net, 1)
        # vector: static .* scale
        @test snap["load"]["ld"]["p_nom"] ≈ [500.0, 1000.0, 1500.0]
        @test snap["load"]["ld"]["q_nom"] ≈ [50.0, 100.0, 150.0]
        # scalar: static * scale
        @test snap["line"]["l1"]["length"] ≈ 4.0

        # ts bookkeeping stripped from the snapshot
        @test !haskey(snap, "time_series")
        @test !haskey(snap["load"]["ld"], "time_series")
        @test !haskey(snap["line"]["l1"], "time_series")
        @test !is_timeseries(snap)

        # original network unmutated
        @test net["load"]["ld"]["p_nom"] == [1000.0, 2000.0, 3000.0]
        @test net["line"]["l1"]["length"] == 2.0
        @test haskey(net, "time_series")
        @test haskey(net["load"]["ld"], "time_series")

        # a later step resolves independently of the first
        snap3 = get_snapshot(net, 3)
        @test snap3["load"]["ld"]["p_nom"] ≈ [1500.0, 3000.0, 4500.0]
    end

    @testset "get_snapshot — non-ts net is a plain deep copy" begin
        net  = _ts_mini_net()
        snap = get_snapshot(net, 7)   # t_index irrelevant for snapshot nets
        @test snap == net             # structurally identical …
        @test snap !== net            # … but an independent copy
        snap["load"]["ld"]["p_nom"][1] = -1.0
        @test net["load"]["ld"]["p_nom"][1] == 1000.0
    end

    @testset "get_snapshot — out-of-range and invalid t_index" begin
        net = _ts_mini_net()
        net["time_series"] = Dict{String,Any}(
            "shape" => Dict{String,Any}("values" => [0.5, 1.0, 1.5]))
        net["load"]["ld"]["time_series"] = Dict{String,Any}("p_nom" => "shape")

        @test_throws BoundsError get_snapshot(net, 4)     # past the end
        @test_throws BoundsError get_snapshot(net, 0)     # 1-based indexing
        @test_throws BoundsError get_snapshot(net, -3)
        @test get_snapshot(net, 3)["load"]["ld"]["p_nom"] ≈ [1500.0, 3000.0, 4500.0]
    end

    @testset "get_snapshot — dangling series reference" begin
        net = _ts_mini_net()
        net["time_series"] = Dict{String,Any}(
            "shape" => Dict{String,Any}("values" => [1.0]))
        net["load"]["ld"]["time_series"] = Dict{String,Any}("p_nom" => "no_such_series")
        err = try get_snapshot(net, 1); nothing catch e; e end
        @test err isa ArgumentError
        @test occursin("no_such_series", err.msg)   # names the missing series
        @test occursin("'ld'", err.msg)             # names the offending component
        @test occursin("p_nom", err.msg)            # names the parameter
    end

    @testset "get_snapshot — transformer subtype refs" begin
        net = _ts_mini_net()
        net["time_series"] = Dict{String,Any}()
        net["transformer"] = Dict{String,Any}("delta_wye" =>
            Dict{String,Any}("synthetic_tx" => Dict{String,Any}("s_rating" => 100000.0)))
        # Snapshot resolution only needs a synthetic transformer rating and series.
        net["time_series"]["derate"] = Dict{String,Any}("values" => fill(0.8, 24))
        net["transformer"]["delta_wye"]["synthetic_tx"]["time_series"] =
            Dict{String,Any}("s_rating" => "derate")

        snap = get_snapshot(net, 5)
        @test snap["transformer"]["delta_wye"]["synthetic_tx"]["s_rating"] ≈ 0.8 * 100000
        @test !haskey(snap["transformer"]["delta_wye"]["synthetic_tx"], "time_series")
        # original unmutated
        @test net["transformer"]["delta_wye"]["synthetic_tx"]["s_rating"] == 100000
    end

end
