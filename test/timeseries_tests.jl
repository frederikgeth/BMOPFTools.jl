# Time-series support — is_timeseries / get_snapshot semantics plus the
# t_index kwarg threaded through analyze / solve_opf / profile_solution.
# Included from runtests.jl (which defines `_HAS_JUMP_IPOPT` and loads
# JuMP/Ipopt when available) — the OPF section is gated on that flag.

const _TS_FIXTURE_PATH = joinpath(@__DIR__, "data", "LV", "lv1_14bus_timeseries.json")

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
        net = parse_bmopf(_TS_FIXTURE_PATH)
        # the fixture ships a delta_wye transformer; hang a series off it
        net["time_series"]["derate"] = Dict{String,Any}("values" => fill(0.8, 24))
        net["transformer"]["delta_wye"]["tx3170"]["time_series"] =
            Dict{String,Any}("s_rating" => "derate")

        snap = get_snapshot(net, 5)
        @test snap["transformer"]["delta_wye"]["tx3170"]["s_rating"] ≈ 0.8 * 100000
        @test !haskey(snap["transformer"]["delta_wye"]["tx3170"], "time_series")
        # original unmutated
        @test net["transformer"]["delta_wye"]["tx3170"]["s_rating"] == 100000
    end

    @testset "fixture — lv1_14bus_timeseries loads and analyzes" begin
        net = parse_bmopf(_TS_FIXTURE_PATH)
        @test is_timeseries(net)
        @test length(net["time_series"]["residential_daily"]["values"]) == 24
        @test length(net["time_series"]["solar_daily"]["values"]) == 24
        @test all(haskey(l, "time_series") for (_, l) in net["load"])
        @test all(haskey(i, "time_series") for (_, i) in net["ibr"])

        report = analyze(net)                       # defaults to t_index = 1
        @test isempty(errors(report))
        report24 = analyze(net; t_index = 24)       # kwarg threads through
        @test isempty(errors(report24))
        @test_throws BoundsError analyze(net; t_index = 25)

        # 03:00 (t=4): no sun, light load; 12:00 (t=13): full sun
        snap_night = get_snapshot(net, 4)
        snap_noon  = get_snapshot(net, 13)
        @test snap_night["ibr"]["pv_b3230"]["p_max"] ≈ [0.0]
        @test snap_night["load"]["ld3313_load_a"]["p_nom"] ≈ [2700.0]  # 0.27 × 10 kW
        @test snap_noon["ibr"]["pv_b3230"]["p_max"]  ≈ [15000.0]
        @test snap_noon["ibr"]["pv_b3230"]["p_avail"] ≈ 15000.0        # scalar path
        @test snap_noon["load"]["ld3313_load_a"]["p_nom"] ≈ [4000.0]   # 0.40 × 10 kW
    end

    @testset "fixture — OPF across snapshots (gated)" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path"
        else
            net = parse_bmopf(_TS_FIXTURE_PATH)
            net_ready, _ = augment_case(net; recipe = AugmentationRecipe())
            @test is_timeseries(net_ready)   # augmentation preserves ts refs
            opt = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

            grid_p(res) = sum(v["ps"] for v in values(first(values(res["voltage_source"])))) +
                          sum(sum(ph["pg"] for ph in values(g)) for g in values(get(res, "generator", Dict())); init = 0.0)
            pv_p(res)   = sum(sum(ph["pg"] for ph in values(res["ibr"][id])) for id in keys(res["ibr"]))

            res_noon = solve_opf(net_ready; optimizer = opt, per_unit = true, t_index = 13)
            res_eve  = solve_opf(net_ready; optimizer = opt, per_unit = true, t_index = 20)
            @test res_noon["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test res_eve["termination_status"]  in ("LOCALLY_SOLVED", "OPTIMAL")

            # different snapshots → different dispatch
            @test !isapprox(res_noon["objective"], res_eve["objective"]; rtol = 1e-3)
            @test pv_p(res_noon) ≈ 30_000.0 atol = 10.0      # both PVs at full output
            @test pv_p(res_eve)  ≈ 0.0      atol = 1.0       # no sun at 19:00
            @test grid_p(res_noon) < 0                       # midday reverse flow
            @test grid_p(res_eve)  > 0                       # evening import

            # t_index kwarg ≡ explicit get_snapshot round-trip
            res_manual = solve_opf(get_snapshot(net_ready, 13);
                                   optimizer = opt, per_unit = true)
            @test res_manual["objective"] ≈ res_noon["objective"] rtol = 1e-6

            # profile_solution accepts the ts net + t_index and stays clean
            sol_report = profile_solution(net_ready, res_noon; t_index = 13)
            @test isempty(errors(sol_report))
        end
    end
end
