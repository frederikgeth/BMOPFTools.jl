using Test, JSON3
include(joinpath(@__DIR__, "..", "bench", "ipopt_barrier.jl"))

@testset "Ipopt barrier benchmark" begin
    B = IpoptBarrierBenchmark
    path = joinpath(@__DIR__, "data", "case_development", "feeder.json")
    original = JSON3.read(read(path, String), Dict{String,Any})
    before = deepcopy(original)
    # Deliberately insert IDs out of order, including an ineligible fifth load:
    # selection counts all IDs, rather than only eligible three-phase loads.
    net = deepcopy(original)
    load = first(values(net["load"]))
    net["load"] = Dict{String,Any}(lpad(string(i),2,'0')=>deepcopy(load) for i in 10:-1:1)
    net["load"]["05"]["p_nom"] = [100.0]
    net["load"]["05"]["q_nom"] = [20.0]
    augmented = B.instance(net; load_factor=0.5, der_every=5)
    @test collect(keys(augmented["generator"])) == ["der_10"]
    @test augmented["generator"]["der_10"]["p_max"] == 2load["p_nom"]
    @test augmented["load"]["10"]["p_nom"] == 0.5load["p_nom"]
    @test augmented["load"]["10"]["q_nom"] == 0.5load["q_nom"]
    @test B.digest(augmented) == B.digest(Dict(reverse(collect(augmented))))
    @test_throws ArgumentError B.instance(augmented; load_factor=1.0, der_every=5)
    @test isempty(B.instance(original; load_factor=0.0, der_every=0)["generator"])
    @test original == before
    @test_throws ArgumentError B.configuration(repeats=0)
    @test_throws ArgumentError B.configuration(s_base=NaN)
    @test_throws ArgumentError B.configuration(load_factors=[-1.0])
    @test_throws ArgumentError B.configuration(load_factors=Float64[])
    @test_throws ArgumentError B.configuration(der_every=-1)
    @test_throws ArgumentError B.configuration(max_wall_time=Inf)
    @test_throws ArgumentError B.main(["out", path, "--unknown", "1"])
    @test_throws ArgumentError B.main(["out", path, "--repeats"])
    @test_throws ArgumentError B.main(["out", path, "--repeats", "1", "--repeats", "2"])
    @test_throws ArgumentError B.main([path, path]) # never overwrite an input

    # Integration checks include real solver output and strict JSON round trips.
    cfg = B.configuration(repeats=2, load_factors=[1.0], der_every=1)
    io = IOBuffer()
    B.benchmark(io, [path], cfg)
    records = [JSON3.read(line, Dict{String,Any}) for line in split(chomp(String(take!(io))), '\n')]
    @test records[1]["kind"] == "environment"
    @test haskey(records[1]["packages"], "Ipopt_jll")
    @test length(records[1]["harness_sha256"]) == 64
    rows = filter(r -> r["kind"] == "run", records)
    @test length(rows) == 6
    @test count(r -> r["process_first_call"], rows) == 1
    @test [r["strategy"] for r in rows] == ["monotone", "adaptive", "adaptive", "monotone", "monotone", "adaptive"]
    @test all(r -> r["accepted"], rows)
    @test all(r -> r["error"] === nothing, rows)
    @test all(r -> length(r["case_sha256"]) == 64, rows)
    @test all(r -> r["verification"]["results"]["solution"]["verification_status"] == "checks_passed", rows)
    @test all(r -> !isempty(r["verification"]["results"]["solution"]["unassessed_dimensions"]), rows)
    @test records[end]["strategies"]["adaptive"]["accepted"] == 2
    @test records[end]["objectives_comparable"]
    @test records[end]["adaptive_over_monotone_solve_time"] isa Real
    @test original == before

    # A budget-limited run remains evidence, but cannot enter a speed comparison.
    case = B.instance(original; load_factor=1.0, der_every=1)
    failed = B.run_once(case, "adaptive", B.configuration(max_iter=0))
    @test !failed["accepted"]
    @test failed["error"] === nothing
    @test failed["termination_status"] == "ITERATION_LIMIT"
    failed["phase"] = "measured"
    mixed = [rows[3], rows[4], failed]
    summary = B.summarize(mixed)
    @test summary["adaptive_over_monotone_solve_time"] === nothing
    @test summary["strategies"]["adaptive"]["attempts"] == 2
    @test summary["strategies"]["adaptive"]["accepted"] == 1
    changed = deepcopy(rows)
    changed[3]["objective"] += 100.0
    @test !B.summarize(changed)["objectives_comparable"]
    @test B.summarize(changed)["adaptive_over_monotone_solve_time"] === nothing
    missing_time = deepcopy(rows)
    missing_time[3]["solve_time_s"] = nothing
    @test B.summarize(missing_time)["adaptive_over_monotone_solve_time"] === nothing
    @test B.summarize(Dict{String,Any}[])["adaptive_over_monotone_solve_time"] === nothing
    B.emit(io, failed)
    @test JSON3.read(String(take!(io)))["accepted"] == false
end
