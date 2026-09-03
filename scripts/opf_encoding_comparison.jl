"""
    opf_encoding_comparison.jl

Compare the Ipopt smooth Volt-var/Volt-watt formulation with the CCOpt
complementarity formulation on one BMOPF snapshot.

The script reports the objective, status, feasibility, solver-reported time,
and (for smooth-vs-CCOpt rows) the maximum differences in the extracted IBR
outputs and bus voltage magnitudes.  CCOpt rows also report how far the
returned point is from satisfying the complementarity pairs exactly, and the
number of registered pairs.

Two caveats on reading the timing columns.  `solve_time_s` is the solver's own
report, and the two solvers do not measure the same span: CCOpt's wall time
includes MadNLP initialisation, while Ipopt's `JuMP.solve_time` excludes model
construction.  `outer_time_s` brackets the whole call for both and is the
column to compare.  Use `--warmup` regardless, because the first invocation of
either path includes Julia compilation.

Usage:

    julia --project=<environment-with-ccopt> scripts/opf_encoding_comparison.jl \
        /path/to/case.bmopf.json

Options:

    --eps=1e-2,2e-3,1e-4,1e-5   Smooth epsilons (default shown above)
    --method=relaxation         CCOpt method (relaxation; penalty is broken
                                upstream in CCOpt 0.1.0)
    --warmup                    Run one discarded solve of each formulation
    --verbose                   Keep solver output instead of suppressing it
    --out=/path/to/results.tsv  Also write the tab-separated report to a file

The active Julia environment must provide BMOPFTools, JuMP, Ipopt, CCOpt,
MPCCModels, and NLPModelsJuMP.  The benchmark data itself is intentionally a
positional argument because the ENWL snapshots live in the sibling
BMOPFDraftData repository.
"""

using Pkg

const _ROOT = normpath(joinpath(@__DIR__, ".."))
if isnothing(Base.identify_package("BMOPFTools"))
    Pkg.activate(_ROOT)
end

using BMOPFTools

const _OPTIONAL = ("JuMP", "Ipopt", "CCOpt", "MPCCModels", "NLPModelsJuMP")
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
using Printf

const _DEFAULT_EPS = [1e-2, 2e-3, 1e-4, 1e-5]

struct Options
    path::String
    epsilons::Vector{Float64}
    method::Symbol
    warmup::Bool
    verbose::Bool
    output::Union{String,Nothing}
end

function _usage(io=stdout)
    println(io, "Usage: julia --project=<env> scripts/opf_encoding_comparison.jl CASE [options]")
    println(io, "  --eps=1e-2,2e-3,1e-4,1e-5  smooth epsilon sweep")
    println(io, "  --method=relaxation|penalty  CCOpt method")
    println(io, "  --warmup                     discard one solve per formulation")
    println(io, "  --verbose                    show solver output")
    println(io, "  --out=FILE                   also write the TSV report")
end

function _parse_args(args)
    isempty(args) && (_usage(stderr); error("a .bmopf.json case path is required"))
    path = nothing
    epsilons = copy(_DEFAULT_EPS)
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
    Options(normpath(path), epsilons, method, warmup, verbose, output)
end

function _call_quiet(f, verbose)
    verbose ? f() : redirect_stdout(devnull) do
        f()
    end
end

function _run_smooth(path, epsilon; verbose=false)
    net = parse_bmopf(path)
    t0 = time()
    result = _call_quiet(verbose) do
        solve_opf(net; volt_var_watt_eps=epsilon, verbose=verbose)
    end
    return result, time() - t0
end

function _ccopt_options(method)
    method == :relaxation || return nothing
    CCOpt.RelaxationOptions(
        print_level=CCOpt.MadNLP.ERROR,
        file_print_level=CCOpt.MadNLP.ERROR,
    )
end

function _run_ccopt(path, method; verbose=false)
    net = parse_bmopf(path)
    handle = build_ccopt_model(net; verbose=verbose)
    t0 = time()
    options = _ccopt_options(method)
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

function _row(label, epsilon, result; reference=nothing, outer_time=nothing)
    ccopt = get(result, "ccopt", Dict{String,Any}())
    comparison = reference === nothing ?
        (missing, missing, missing, missing, missing) :
        (result["objective"] - reference["objective"],
         _max_group_difference(result, reference, "ibr", "pg"),
         _max_group_difference(result, reference, "ibr", "qg"),
         _max_group_difference(result, reference, "ibr", "cri"),
         _max_group_difference(result, reference, "bus", "vm"))
    (
        label=label,
        epsilon=epsilon,
        status=result["termination_status"],
        feasible=result["feasible"],
        objective=result["objective"],
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
    "formulation", "epsilon", "status", "feasible", "objective",
    "solve_time_s", "outer_time_s", "max_complementarity_product",
    "max_curve_error_relative", "max_hinge_bound_violation",
    "complementarity_satisfied", "pair_count",
    "objective_delta_vs_ccopt", "max_pg_delta", "max_qg_delta",
    "max_cri_delta", "max_vm_delta",
]

function _field_strings(row)
    [
        row.label,
        row.epsilon === nothing ? "" : @sprintf("%.6g", row.epsilon),
        row.status,
        string(row.feasible),
        @sprintf("%.12g", row.objective),
        row.solve_time === missing ? "" : @sprintf("%.6g", row.solve_time),
        row.outer_time === nothing ? "" : @sprintf("%.6g", row.outer_time),
        row.max_complementarity === missing ? "" : @sprintf("%.6g", row.max_complementarity),
        row.curve_error === missing ? "" : @sprintf("%.6g", row.curve_error),
        row.bound_violation === missing ? "" : @sprintf("%.6g", row.bound_violation),
        row.complementarity_ok === missing ? "" : string(row.complementarity_ok),
        row.pair_count === missing ? "" : string(row.pair_count),
        row.objective_delta === missing ? "" : @sprintf("%.6g", row.objective_delta),
        row.max_pg_delta === missing ? "" : @sprintf("%.6g", row.max_pg_delta),
        row.max_qg_delta === missing ? "" : @sprintf("%.6g", row.max_qg_delta),
        row.max_cri_delta === missing ? "" : @sprintf("%.6g", row.max_cri_delta),
        row.max_vm_delta === missing ? "" : @sprintf("%.6g", row.max_vm_delta),
    ]
end

function _write_report(io, options, rows)
    println(io, "# BMOPFTools OPF encoding comparison")
    println(io, "# case=$(options.path)")
    println(io, "# ccopt_method=$(options.method)")
    println(io, "# smooth rows compare against the CCOpt row")
    println(io, "# compare timings on outer_time_s; solve_time_s spans differ per solver")
    println(io, join(_HEADERS, '\t'))
    for row in rows
        println(io, join(_field_strings(row), '\t'))
    end
end

function main(args=ARGS)
    options = _parse_args(args)
    println("Comparing OPF encodings for $(options.path)")
    println("Smooth epsilons: $(join(options.epsilons, ", ")); CCOpt method: $(options.method)")

    if options.warmup
        _run_smooth(options.path, first(options.epsilons); verbose=options.verbose)
        _run_ccopt(options.path, options.method; verbose=options.verbose)
        println("Warm-up complete; reported rows exclude the warm-up solves.")
    end

    smooth = [(epsilon, _run_smooth(options.path, epsilon; verbose=options.verbose))
              for epsilon in options.epsilons]
    ccopt, ccopt_outer_time = _run_ccopt(options.path, options.method;
                                         verbose=options.verbose)
    rows = Any[_row("smooth", epsilon, result;
                    reference=ccopt, outer_time=elapsed)
               for (epsilon, (result, elapsed)) in smooth]
    push!(rows, _row("ccopt", nothing, ccopt; outer_time=ccopt_outer_time))

    _write_report(stdout, options, rows)
    if options.output !== nothing
        open(options.output, "w") do io
            _write_report(io, options, rows)
        end
        println("Wrote $(options.output)")
    end
end

main()
