"""
    opf_encoding_comparison.jl

Compare the Ipopt smooth Volt-var/Volt-watt formulation with the CCOpt
complementarity formulation on one BMOPF snapshot.

The comparison is factorial, because encoding and solver are otherwise
confounded: CCOpt drives MadNLP, so a plain smooth-Ipopt-vs-CCOpt table cannot
say whether a difference came from dropping the smoothing or from changing the
optimiser. Three row families separate them:

    smooth / ipopt    the status quo
    smooth / madnlp   same encoding, different solver   -> solver effect
    ccopt             different encoding, same solver   -> encoding effect

Reported per row: solver status, objective, timing, and the maximum differences
in extracted IBR outputs and bus voltage magnitudes against the CCOpt row.
CCOpt rows additionally report how far the returned point is from satisfying
the complementarity pairs exactly, and the number of registered pairs.

Two caveats on reading the timing columns. `solve_time_s` is the solver's own
report, and the solvers do not measure the same span: CCOpt's wall time
includes MadNLP initialisation, while Ipopt's `JuMP.solve_time` excludes model
construction. `outer_time_s` brackets the whole call for every row and is the
column to compare. Use `--warmup` regardless, because the first invocation of
any path includes Julia compilation.

A note on `--softplus`. The default is `builtin`, not the package default
`user_defined`, because MadNLP's MOI layer mishandles JuMP user-defined
nonlinear operators: on the two-bus Volt-watt case it returns p_g = 800.8 W
where every other combination agrees on 1183.3 W, and reports LOCALLY_SOLVED
while doing it. Ipopt gives identical answers under both modes, so `builtin` is
the mode in which a cross-solver comparison is meaningful. Pass
`--softplus=user_defined` to see the discrepancy.

Usage:

    julia --project=<environment-with-ccopt> scripts/opf_encoding_comparison.jl \
        /path/to/case.bmopf.json

Options:

    --eps=1e-2,2e-3,1e-4,1e-5   Smooth epsilons (default shown above)
    --solvers=ipopt,madnlp      Solvers for the smooth rows
    --softplus=builtin          Smooth-ReLU mode: builtin or user_defined
    --method=relaxation         CCOpt method (relaxation; penalty is broken
                                upstream in CCOpt 0.1.0)
    --warmup                    Run one discarded solve of each formulation
    --verbose                   Keep solver output instead of suppressing it
    --out=/path/to/results.tsv  Also write the tab-separated report to a file

The active Julia environment must provide BMOPFTools, JuMP, Ipopt, CCOpt,
MPCCModels, and NLPModelsJuMP; MadNLP arrives with CCOpt. The benchmark data
itself is intentionally a positional argument because the ENWL snapshots live
in the sibling BMOPFDraftData repository.
"""

using Pkg

const _ROOT = normpath(joinpath(@__DIR__, ".."))
if isnothing(Base.identify_package("BMOPFTools"))
    Pkg.activate(_ROOT)
end

using BMOPFTools

const _OPTIONAL = ("JuMP", "Ipopt", "CCOpt", "MPCCModels", "NLPModelsJuMP", "MadNLP")
const _MISSING = filter(name -> isnothing(Base.identify_package(name)), _OPTIONAL)
isempty(_MISSING) || error(
    "This experiment needs packages not present in the active environment: " *
    join(_MISSING, ", ") *
    ". Activate an environment containing the CCOpt stack; see scripts/README.md.")

@eval using JuMP
@eval using Ipopt
@eval using CCOpt
@eval using MPCCModels
@eval using NLPModelsJuMP
@eval import MadNLP
using Printf

const _DEFAULT_EPS = [1e-2, 2e-3, 1e-4, 1e-5]
const _SOLVERS = (:ipopt, :madnlp)

struct Options
    path::String
    epsilons::Vector{Float64}
    solvers::Vector{Symbol}
    softplus::Symbol
    method::Symbol
    warmup::Bool
    verbose::Bool
    output::Union{String,Nothing}
end

function _usage(io=stdout)
    println(io, "Usage: julia --project=<env> scripts/opf_encoding_comparison.jl CASE [options]")
    println(io, "  --eps=1e-2,2e-3,1e-4,1e-5    smooth epsilon sweep")
    println(io, "  --solvers=ipopt,madnlp       solvers for the smooth rows")
    println(io, "  --softplus=builtin|user_defined  smooth-ReLU mode")
    println(io, "  --method=relaxation|penalty  CCOpt method")
    println(io, "  --warmup                     discard one solve per formulation")
    println(io, "  --verbose                    show solver output")
    println(io, "  --out=FILE                   also write the TSV report")
end

function _parse_args(args)
    isempty(args) && (_usage(stderr); error("a .bmopf.json case path is required"))
    path = nothing
    epsilons = copy(_DEFAULT_EPS)
    solvers = collect(_SOLVERS)
    softplus = :builtin
    method = :relaxation
    warmup = false
    verbose = false
    output = nothing

    for arg in args
        if arg == "--help" || arg == "-h"
            _usage()
            exit(0)
        elseif arg == "--warmup"
            warmup = true
        elseif arg == "--verbose"
            verbose = true
        elseif startswith(arg, "--eps=")
            raw = split(last(split(arg, "=", limit=2)), ",")
            epsilons = parse.(Float64, raw)
            isempty(epsilons) && error("--eps must contain at least one value")
            all(isfinite, epsilons) && all(>(0), epsilons) ||
                error("--eps values must be finite and positive")
        elseif startswith(arg, "--solvers=")
            raw = split(last(split(arg, "=", limit=2)), ",")
            solvers = Symbol.(strip.(raw))
            isempty(solvers) && error("--solvers must name at least one solver")
            all(s -> s in _SOLVERS, solvers) ||
                error("--solvers must be drawn from: " *
                      join(string.(_SOLVERS), ", "))
        elseif startswith(arg, "--softplus=")
            softplus = Symbol(last(split(arg, "=", limit=2)))
            softplus in (:builtin, :user_defined) ||
                error("--softplus must be builtin or user_defined")
        elseif startswith(arg, "--method=")
            method = Symbol(last(split(arg, "=", limit=2)))
            method in (:relaxation, :penalty) ||
                error("--method must be relaxation or penalty")
        elseif startswith(arg, "--out=")
            output = last(split(arg, "=", limit=2))
        elseif startswith(arg, "-")
            error("unknown option $arg (try --help)")
        elseif path === nothing
            path = arg
        else
            error("unexpected positional argument $arg")
        end
    end
    path === nothing && error("a .bmopf.json case path is required")
    isfile(path) || error("benchmark file does not exist: $path")
    Options(normpath(path), epsilons, solvers, softplus, method,
            warmup, verbose, output)
end

function _call_quiet(f, verbose)
    verbose ? f() : redirect_stdout(devnull) do
        f()
    end
end

# `bound_relax_factor = 0.0` on both interior-point solvers, matching the
# default `solve_ccopt!` applies: MadNLP otherwise relaxes every variable bound
# by 1e-8, which on an MPCC lets a hinge variable go negative and floors the
# achievable complementarity residual. Holding it at zero everywhere keeps the
# smooth rows on the same footing as the CCOpt row.
# Options are a TUPLE of pairs, not a vector: a vector unifies the element type,
# which turns Ipopt's integer `print_level` into a `Real` and gets it rejected.
_solver_spec(name::Symbol, verbose::Bool) =
    name === :ipopt ?
        (Ipopt.Optimizer, ("print_level" => (verbose ? 5 : 0),
                           "bound_relax_factor" => 0.0)) :
        (MadNLP.Optimizer, ("print_level" => (verbose ? MadNLP.INFO : MadNLP.ERROR),
                            "bound_relax_factor" => 0.0))

function _run_smooth(path, epsilon, solver, softplus; verbose=false)
    net = parse_bmopf(path)
    optimizer, options = _solver_spec(solver, verbose)
    t0 = time()
    result = _call_quiet(verbose) do
        solve_opf(net; optimizer=optimizer, solver_options=options,
                  softplus=softplus, volt_var_watt_eps=epsilon, verbose=verbose)
    end
    return result, time() - t0
end

function _ccopt_options(method, verbose)
    method == :relaxation || return nothing
    CCOpt.RelaxationOptions(
        print_level = verbose ? CCOpt.MadNLP.INFO : CCOpt.MadNLP.ERROR,
        file_print_level = CCOpt.MadNLP.ERROR,
    )
end

function _run_ccopt(path, method; verbose=false)
    net = parse_bmopf(path)
    handle = build_ccopt_model(net; verbose=verbose)
    t0 = time()
    options = _ccopt_options(method, verbose)
    _call_quiet(verbose) do
        options === nothing ?
            solve_ccopt!(handle; method=method) :
            solve_ccopt!(handle; method=method, solver_opts=options)
    end
    result = extract_ccopt_result(handle)
    return result, time() - t0
end

function _max_group_difference(a, b, group, field)
    maximum_difference = 0.0
    for id in intersect(collect(keys(a[group])), collect(keys(b[group])))
        for phase in intersect(collect(keys(a[group][id])), collect(keys(b[group][id])))
            left = a[group][id][phase]
            right = b[group][id][phase]
            haskey(left, field) && haskey(right, field) || continue
            maximum_difference = max(maximum_difference,
                                     abs(Float64(left[field]) - Float64(right[field])))
        end
    end
    maximum_difference
end

function _row(label, solver, softplus, epsilon, result;
              reference=nothing, outer_time=nothing)
    ccopt = get(result, "ccopt", Dict{String,Any}())
    profile = get(result, "opt_profile", Dict{String,Any}())
    comparison = reference === nothing ?
        (missing, missing, missing, missing, missing) :
        (result["objective"] - reference["objective"],
         _max_group_difference(result, reference, "ibr", "pg"),
         _max_group_difference(result, reference, "ibr", "qg"),
         _max_group_difference(result, reference, "ibr", "cri"),
         _max_group_difference(result, reference, "bus", "vm"))
    (
        label=label,
        solver=solver,
        softplus=softplus,
        epsilon=epsilon,
        status=result["termination_status"],
        feasible=result["feasible"],
        objective=result["objective"],
        iterations=get(profile, "barrier_iterations", nothing),
        solve_time=get(result, "solve_time", missing),
        outer_time=outer_time,
        max_complementarity=get(ccopt, "max_complementarity_product", missing),
        curve_error=get(ccopt, "max_curve_error_relative", missing),
        bound_violation=get(ccopt, "max_hinge_bound_violation", missing),
        complementarity_ok=get(ccopt, "complementarity_satisfied", missing),
        pair_count=get(ccopt, "pair_count", missing),
        objective_delta=comparison[1],
        max_pg_delta=comparison[2],
        max_qg_delta=comparison[3],
        max_cri_delta=comparison[4],
        max_vm_delta=comparison[5],
    )
end

const _HEADERS = [
    "formulation", "solver", "softplus", "epsilon", "status", "feasible",
    "objective", "iterations", "solve_time_s", "outer_time_s",
    "max_complementarity_product", "max_curve_error_relative",
    "max_hinge_bound_violation", "complementarity_satisfied", "pair_count",
    "objective_delta_vs_ccopt", "max_pg_delta", "max_qg_delta",
    "max_cri_delta", "max_vm_delta",
]

_g(v) = v === missing || v === nothing ? "" : @sprintf("%.6g", v)

function _field_strings(row)
    [
        row.label,
        string(row.solver),
        string(row.softplus),
        row.epsilon === nothing ? "" : @sprintf("%.6g", row.epsilon),
        row.status,
        string(row.feasible),
        @sprintf("%.12g", row.objective),
        row.iterations === nothing ? "" : string(row.iterations),
        _g(row.solve_time),
        _g(row.outer_time),
        _g(row.max_complementarity),
        _g(row.curve_error),
        _g(row.bound_violation),
        row.complementarity_ok === missing ? "" : string(row.complementarity_ok),
        row.pair_count === missing ? "" : string(row.pair_count),
        _g(row.objective_delta),
        _g(row.max_pg_delta),
        _g(row.max_qg_delta),
        _g(row.max_cri_delta),
        _g(row.max_vm_delta),
    ]
end

function _write_report(io, options, rows)
    println(io, "# BMOPFTools OPF encoding comparison")
    println(io, "# case=$(options.path)")
    println(io, "# ccopt_method=$(options.method)  softplus=$(options.softplus)")
    println(io, "# smooth rows compare against the CCOpt row")
    println(io, "# compare timings on outer_time_s; solve_time_s spans differ per solver")
    println(io, "# bound_relax_factor=0.0 on every solver")
    println(io, join(_HEADERS, '\t'))
    for row in rows
        println(io, join(_field_strings(row), '\t'))
    end
end

function main(args=ARGS)
    options = _parse_args(args)
    println("Comparing OPF encodings for $(options.path)")
    println("Smooth epsilons: $(join(options.epsilons, ", "))")
    println("Smooth solvers: $(join(string.(options.solvers), ", ")); " *
            "softplus: $(options.softplus); CCOpt method: $(options.method)")
    if options.softplus === :user_defined && :madnlp in options.solvers
        @warn "MadNLP's MOI layer mishandles JuMP user-defined nonlinear " *
              "operators; the smooth/madnlp rows below are not trustworthy " *
              "under --softplus=user_defined. Use --softplus=builtin for a " *
              "cross-solver comparison."
    end

    if options.warmup
        for solver in options.solvers
            _run_smooth(options.path, first(options.epsilons), solver,
                        options.softplus; verbose=options.verbose)
        end
        _run_ccopt(options.path, options.method; verbose=options.verbose)
        println("Warm-up complete; reported rows exclude the warm-up solves.")
    end

    smooth = [(solver, epsilon,
               _run_smooth(options.path, epsilon, solver, options.softplus;
                           verbose=options.verbose))
              for solver in options.solvers, epsilon in options.epsilons]
    ccopt, ccopt_outer_time = _run_ccopt(options.path, options.method;
                                         verbose=options.verbose)

    # `smooth` is a solver x epsilon matrix; flatten it so rows stay a Vector.
    rows = vec(Any[_row("smooth", solver, options.softplus, epsilon, result;
                        reference=ccopt, outer_time=elapsed)
                   for (solver, epsilon, (result, elapsed)) in smooth])
    push!(rows, _row("ccopt", :madnlp, "-", nothing, ccopt;
                     outer_time=ccopt_outer_time))

    _write_report(stdout, options, rows)
    if options.output !== nothing
        open(options.output, "w") do io
            _write_report(io, options, rows)
        end
        println("Wrote $(options.output)")
    end
end

main()
