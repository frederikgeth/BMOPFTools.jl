"""
Repository-local comparison for issue #429. Run with --help for usage.
No solver defaults, runtime APIs, or scientific contracts are changed here.
"""
module IpoptBarrierBenchmark

using BMOPFTools, Ipopt, JuMP, JSON3, SHA, LinearAlgebra, Pkg, Dates

const ROOT = normpath(joinpath(@__DIR__, ".."))
const STRATEGIES = ("monotone", "adaptive")
const HELP = """
Usage: julia --project=test --startup-file=no bench/ipopt_barrier.jl OUT.jsonl CASE.json [...] [options]
  --repeats N          warmed runs per strategy (default 3)
  --load-factors CSV   nonnegative P/Q multipliers (default 0.5,1.0)
  --der-every N        add DER at every Nth load in sorted ID order; 0 disables (default 5)
  --s-base X          common per-unit power base (default 1e6)
  --max-iter N        identical iteration budget (default 3000)
  --max-wall-time X   Ipopt convergence-check time limit in seconds (default 60)
Output must not already exist. See bench/ipopt_barrier.md for scope and interpretation.
"""

function configuration(; repeats=3, load_factors=[0.5, 1.0], der_every=5,
                       s_base=1e6, max_iter=3000, max_wall_time=60.0)
    repeats isa Integer && repeats >= 1 || throw(ArgumentError("repeats must be positive"))
    der_every isa Integer && der_every >= 0 || throw(ArgumentError("der_every must be nonnegative"))
    max_iter isa Integer && max_iter >= 0 || throw(ArgumentError("max_iter must be nonnegative"))
    !isempty(load_factors) && all(x -> isfinite(x) && x >= 0, load_factors) ||
        throw(ArgumentError("load_factors must be finite and nonnegative"))
    isfinite(s_base) && s_base > 0 || throw(ArgumentError("s_base must be finite and positive"))
    isfinite(max_wall_time) && max_wall_time > 0 || throw(ArgumentError("max_wall_time must be finite and positive"))
    return (; repeats, load_factors, der_every, s_base, max_iter, max_wall_time)
end

"Copy and augment; generator capacity is based on the original, unscaled load."
function instance(net; load_factor, der_every)
    is_timeseries(net) && throw(ArgumentError("provide a static snapshot, not time-series data"))
    x = deepcopy(net)
    gens = get!(x, "generator", Dict{String,Any}())
    for (k, id) in enumerate(sort!(collect(keys(get(x, "load", Dict())))))
        d = x["load"][id]
        p = Float64.(d["p_nom"])
        q = Float64.(d["q_nom"])
        all(isfinite, p) && all(isfinite, q) || throw(ArgumentError("non-finite load $id"))
        if der_every > 0 && k % der_every == 0 && length(p) == 3 && sum(p) > 0 &&
           get(d, "configuration", "") in ("WYE", "DELTA")
            all(>=(0), p) || throw(ArgumentError("DER load $id has a negative phase demand"))
            gid = "der_$id"
            haskey(gens, gid) && throw(ArgumentError("generator ID collision: $gid"))
            gens[gid] = Dict{String,Any}("bus"=>d["bus"],
                "terminal_map"=>copy(d["terminal_map"]), "configuration"=>d["configuration"],
                "p_min"=>zeros(3), "p_max"=>2p, "q_min"=>-p, "q_max"=>p,
                "cost"=>fill(0.10, 3))
        end
        d["p_nom"] = load_factor .* p
        d["q_nom"] = load_factor .* q
    end
    for s in values(get(x, "voltage_source", Dict()))
        s["cost"] = fill(0.25, length(s["terminal_map"]))
    end
    return x
end

# Canonical dictionary ordering for a content hash, independent of insertion order.
canonical(x::AbstractDict) = "{" * join((JSON3.write(string(k)) * ":" * canonical(x[k])
    for k in sort!(collect(keys(x)); by=string)), ",") * "}"
canonical(x::AbstractVector) = "[" * join(canonical.(x), ",") * "]"
canonical(x) = JSON3.write(x)
digest(x) = bytes2hex(sha256(canonical(x)))

function solver_options(strategy, cfg)
    strategy in STRATEGIES || throw(ArgumentError("unknown barrier strategy"))
    Pair{String,Any}["mu_strategy"=>strategy, "print_level"=>0, "tol"=>1e-8,
        "max_iter"=>cfg.max_iter, "max_wall_time"=>cfg.max_wall_time,
        "linear_solver"=>"mumps"]
end

function environment(cfg)
    git(args...) = try
        strip(read(`git -C $ROOT $args`, String))
    catch
        nothing
    end
    Dict{String,Any}("kind"=>"environment", "schema_version"=>1,
        "created_at_utc"=>string(now(UTC)), "julia_version"=>string(VERSION),
        "machine"=>Sys.MACHINE, "kernel"=>string(Sys.KERNEL),
        "cpu"=>[c.model for c in Sys.cpu_info()], "julia_threads"=>Threads.nthreads(),
        "blas_threads"=>BLAS.get_num_threads(), "blas_config"=>string(BLAS.get_config()),
        "thread_environment"=>Dict(k=>get(ENV, k, nothing) for k in
            ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS")),
        "packages"=>Dict(d.name=>Dict("version"=>string(d.version), "tree_hash"=>string(d.tree_hash))
            for d in values(Pkg.dependencies()) if d.version !== nothing),
        "repository_revision"=>git("rev-parse", "HEAD"),
        "repository_status"=>git("status", "--porcelain"),
        "package_source"=>pathof(BMOPFTools), "active_project"=>Base.active_project(),
        "harness_sha256"=>bytes2hex(sha256(read(@__FILE__))),
        "configuration"=>Dict(string(k)=>v for (k,v) in pairs(cfg)),
        "start_policy"=>"fresh solve_opf topology-aware initialization for every call; no warm-start transfer",
        "per_unit"=>true, "verification"=>"profile_solution assessed checks only; see unassessed_dimensions",
        "solver_options"=>Dict(s=>Dict(solver_options(s, cfg)) for s in STRATEGIES))
end

function run_once(net, strategy, cfg)
    row = Dict{String,Any}("strategy"=>strategy, "accepted"=>false,
        "termination_status"=>nothing, "primal_status"=>nothing, "objective"=>nothing,
        "barrier_iterations"=>nothing, "solve_time_s"=>nothing,
        "solve_call_s"=>nothing, "verification_s"=>nothing, "verification"=>nothing,
        "error"=>nothing)
    start = time_ns()
    try
        call_start = time_ns()
        result = solve_opf(deepcopy(net); optimizer=Ipopt.Optimizer, per_unit=true,
            s_base=cfg.s_base, solver_options=solver_options(strategy, cfg))
        row["solve_call_s"] = (time_ns() - call_start) / 1e9
        for key in ("termination_status", "primal_status", "objective")
            row[key] = get(result, key, nothing)
        end
        for key in ("barrier_iterations", "solve_time_s")
            row[key] = get(get(result, "opt_profile", Dict()), key, nothing)
        end
        verification_start = time_ns()
        report = profile_solution(net, result)
        # Use the package serializer, including stable Finding codes and evidence.
        row["verification"] = BMOPFTools._solution_report_to_json(report)
        row["verification_s"] = (time_ns() - verification_start) / 1e9
        row["accepted"] = row["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL") &&
            row["primal_status"] == "FEASIBLE_POINT" &&
            row["objective"] isa Real && isfinite(row["objective"]) &&
            get(report.results[:solution], "verification_status", "indeterminate") == "checks_passed"
    catch err
        err isa InterruptException && rethrow()
        row["error"] = sprint(showerror, err)
    end
    row["total_time_s"] = (time_ns() - start) / 1e9
    return row
end

function spread(values)
    xs = sort!([Float64(x) for x in values if x isa Real && isfinite(x)])
    isempty(xs) && return nothing
    n = length(xs)
    Dict("n"=>n, "min"=>first(xs), "median"=>(xs[(n+1)÷2] + xs[(n+2)÷2])/2,
         "max"=>last(xs))
end

function summarize(rows)
    arms = Dict{String,Any}()
    for strategy in STRATEGIES
        rs = filter(r -> r["phase"] == "measured" && r["strategy"] == strategy, rows)
        ok = filter(r -> r["accepted"], rs)
        arms[strategy] = Dict("attempts"=>length(rs), "accepted"=>length(ok),
            "termination_statuses"=>[r["termination_status"] for r in rs],
            "all_attempt_total_time_s"=>spread([r["total_time_s"] for r in rs]),
            "accepted_metrics"=>Dict(k=>spread([r[k] for r in ok]) for k in
                ("objective", "barrier_iterations", "solve_time_s", "solve_call_s",
                 "verification_s", "total_time_s")))
    end
    measured = filter(r -> r["phase"] == "measured", rows)
    # Do not turn unsuccessful runs or materially different objectives into speedups.
    eligible = !isempty(measured) && all(r -> r["accepted"], measured) &&
        all(s -> arms[s]["attempts"] > 0, STRATEGIES)
    objectives = eligible ? [r["objective"] for r in measured] : Float64[]
    comparable = eligible && isapprox(minimum(objectives), maximum(objectives); atol=1e-4, rtol=1e-5)
    ratio = nothing
    if comparable
        a = arms["adaptive"]["accepted_metrics"]["solve_time_s"]
        m = arms["monotone"]["accepted_metrics"]["solve_time_s"]
        if a !== nothing && m !== nothing && m["median"] > 0 &&
           a["n"] == arms["adaptive"]["attempts"] && m["n"] == arms["monotone"]["attempts"]
            ratio = a["median"] / m["median"]
        end
    end
    Dict("kind"=>"summary", "strategies"=>arms, "objectives_comparable"=>comparable,
        "objective_comparison"=>Dict("atol"=>1e-4, "rtol"=>1e-5),
        "adaptive_over_monotone_solve_time"=>ratio)
end

function emit(io, record)
    JSON3.write(io, BMOPFTools._jsonable(record))
    write(io, '\n')
    flush(io)
end

function benchmark(io, paths, cfg)
    realpath(dirname(dirname(pathof(BMOPFTools)))) == realpath(ROOT) ||
        throw(ArgumentError("develop this BMOPFTools checkout into the active environment first"))
    emit(io, environment(cfg))
    first_call = true
    for path in paths
        raw = read(path)
        original = JSON3.read(raw, Dict{String,Any})
        for factor in cfg.load_factors
            net = instance(original; load_factor=factor, der_every=cfg.der_every)
            meta = Dict("input_path"=>abspath(path), "input_sha256"=>bytes2hex(sha256(raw)),
                "case_sha256"=>digest(net), "load_factor"=>factor,
                "buses"=>length(net["bus"]), "generators"=>length(net["generator"]))
            emit(io, merge(meta, Dict("kind"=>"case")))
            rows = Dict{String,Any}[]
            # Both strategies warm up once; only the first call in this process is cold.
            for rep in 0:cfg.repeats
                order = iseven(rep) ? STRATEGIES : reverse(STRATEGIES)
                for strategy in order
                    row = merge(meta, run_once(net, strategy, cfg), Dict("kind"=>"run",
                        "phase"=>rep == 0 ? "warmup" : "measured", "repeat"=>rep,
                        "process_first_call"=>first_call))
                    first_call = false
                    emit(io, row)
                    push!(rows, row)
                end
            end
            emit(io, merge(meta, summarize(rows)))
        end
    end
end

function main(args=ARGS)
    "--help" in args && (print(HELP); return)
    positional = String[]
    options = Dict{Symbol,Any}()
    parsers = Dict("--repeats"=>(:repeats, x->parse(Int,x)),
        "--load-factors"=>(:load_factors, x->parse.(Float64,split(x,','))),
        "--der-every"=>(:der_every, x->parse(Int,x)),
        "--s-base"=>(:s_base, x->parse(Float64,x)),
        "--max-iter"=>(:max_iter, x->parse(Int,x)),
        "--max-wall-time"=>(:max_wall_time, x->parse(Float64,x)))
    i = 1
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            haskey(parsers, arg) || throw(ArgumentError("unknown option $arg"))
            i < length(args) || throw(ArgumentError("missing value for $arg"))
            key, parse_value = parsers[arg]
            haskey(options,key) && throw(ArgumentError("duplicate option $arg"))
            options[key] = parse_value(args[i+1])
            i += 2
        else
            push!(positional,arg)
            i += 1
        end
    end
    length(positional) >= 2 || throw(ArgumentError(HELP))
    cfg = configuration(; options...)
    output, paths = first(positional), positional[2:end]
    ispath(output) && throw(ArgumentError("output already exists: $output"))
    all(isfile, paths) || throw(ArgumentError("an input file is missing"))
    # External option files can silently override the controlled comparison.
    isfile("ipopt.opt") && throw(ArgumentError("run from a directory without ipopt.opt"))
    BLAS.set_num_threads(1)
    open(output, "w") do io
        benchmark(io, paths, cfg)
    end
    println("Wrote ", abspath(output))
end

end # module

abspath(PROGRAM_FILE) == (@__FILE__) && IpoptBarrierBenchmark.main()
