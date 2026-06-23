"""
    run_benchmark.jl

One driver to regenerate everything under output/ENWLbenchmark/. Run it
whenever the benchmark cases or the analysis/OPF code change.

Stages (run in this order when none is named):

  outputs    For each case in original/, re-derive the reduced variant and
             write JSON + analysis report + ASCII tree + reduction log into
             original/ and reduced/.
  opf        Solve each reduced case with Ipopt in both SI and per-unit, then
             write opf_results.json and opf_comparison.md.
  solutions  Solve each reduced case (SI) and write a profile_solution report
             (<stem>_solution.md) next to it.

Usage:
    julia --project=scripts scripts/run_benchmark.jl               # all stages
    julia --project=scripts scripts/run_benchmark.jl opf           # one stage
    julia --project=scripts scripts/run_benchmark.jl opf solutions # a subset

Note: `outputs` does not regenerate the enriched root cases themselves (their
OpenDSS sources are no longer available); it reads the JSONs already in
original/ and rebuilds the derived artifacts from them.
"""

using Pkg
Pkg.activate(@__DIR__)   # scripts/Project.toml — BMOPFTools + JuMP + Ipopt + JSON3

include(joinpath(@__DIR__, "pipeline_common.jl"))

using JuMP, Ipopt
using JSON3
using Printf

const SOLVED_STATUSES = ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")

function _optimizer(; max_iter=500, tol=1e-6)
    optimizer_with_attributes(Ipopt.Optimizer,
        "max_iter"    => max_iter,
        "print_level" => 0,
        "tol"         => tol,
    )
end

# ── Stage: outputs ────────────────────────────────────────────────────────────
# Rebuild reports/trees/reduced variants from the enriched cases in original/.

function stage_outputs()
    sources = discover_cases(ORIG_DIR)
    println("[outputs] $(length(sources)) ENWLbenchmark case(s).\n")
    mkpath(ORIG_DIR); mkpath(REDUCED_DIR)

    ok = 0; failed = 0
    for src in sources
        stem = splitext(basename(src))[1]
        print("  $stem … ")
        t0 = time()
        try
            net_orig = parse_bmopf(src)
            net_red  = simplify_network(net_orig)
            write_variant(net_orig, ORIG_DIR, stem)
            write_variant(net_red,  REDUCED_DIR, stem; net_orig=net_orig)

            b0 = length(get(net_orig, "bus",  Dict()))
            b1 = length(get(net_red,  "bus",  Dict()))
            l0 = length(get(net_orig, "line", Dict()))
            l1 = length(get(net_red,  "line", Dict()))
            dt = round(time() - t0; digits=1)
            println("✓  buses $(b0)→$(b1) (-$(b0-b1))  lines $(l0)→$(l1) (-$(l0-l1))  $(dt)s")
            ok += 1
        catch e
            println("✗")
            @error "Failed: $stem" exception=(e, catch_backtrace())
            failed += 1
        end
    end
    println("\n[outputs] $ok processed, $failed failed → $ORIG_DIR, $REDUCED_DIR\n")
end

# ── Stage: opf ────────────────────────────────────────────────────────────────
# Solve each reduced case in SI and per-unit; write results table + comparison.

const RESULT_JSON = joinpath(BENCH_DIR, "opf_results.json")
const REPORT_MD   = joinpath(BENCH_DIR, "opf_comparison.md")
const OPF_MAX_ITER = 500

struct Row
    name         ::String
    n_buses      ::Int
    n_gens       ::Int
    status_si    ::String
    objective_si ::Union{Float64,Nothing}
    time_si      ::Float64
    status_pu    ::String
    objective_pu ::Union{Float64,Nothing}
    time_pu      ::Float64
end

function _run_solve(net, per_unit)
    status = "ERROR"; obj = nothing; t0 = time()
    try
        res = solve_opf(net; optimizer=_optimizer(; max_iter=OPF_MAX_ITER), per_unit=per_unit)
        status = res["termination_status"]
        obj    = res["objective"]
    catch e
        status = "ERROR: $(sprint(showerror, e))"
    end
    return status, obj, round(time() - t0; digits=1)
end

_flush_results(rows) = open(RESULT_JSON, "w") do io
    JSON3.pretty(io, [
        Dict("name" => r.name, "n_buses" => r.n_buses, "n_gens" => r.n_gens,
             "status_si" => r.status_si, "objective_si" => r.objective_si, "time_si_s" => r.time_si,
             "status_pu" => r.status_pu, "objective_pu" => r.objective_pu, "time_pu_s" => r.time_pu)
        for r in rows
    ])
end

_fmt_obj(status, obj) =
    status in SOLVED_STATUSES ? (obj === nothing ? "—" : @sprintf("%.6g", obj)) :
                                "`$(split(status, ':')[1])`"

function _fmt_delta(obj_si, obj_pu)
    (obj_si === nothing || obj_pu === nothing) && return "—"
    abs(obj_si) < 1e-12 && return "—"
    @sprintf("%+.4f%%", (obj_pu - obj_si) / abs(obj_si) * 100)
end

function stage_opf()
    sources = discover_cases(REDUCED_DIR)
    n = length(sources)
    println("[opf] Solving $n reduced case(s) with Ipopt (max_iter=$OPF_MAX_ITER)...\n")

    rows = Row[]
    for (i, src) in enumerate(sources)
        stem = splitext(basename(src))[1]
        net  = parse_bmopf(src)
        n_buses = length(get(net, "bus",       Dict()))
        n_gens  = length(get(net, "generator", Dict()))
        @printf("[%3d/%d] %s  (%d buses, %d gens)\n", i, n, stem, n_buses, n_gens)

        print("         SI  … "); flush(stdout)
        status_si, obj_si, t_si = _run_solve(net, false)
        status_si in SOLVED_STATUSES ? @printf("✓ %+.6e  (%.1fs)\n", obj_si, t_si) :
                                       @printf("✗ %s  (%.1fs)\n", status_si, t_si)

        print("         PU  … "); flush(stdout)
        status_pu, obj_pu, t_pu = _run_solve(net, true)
        status_pu in SOLVED_STATUSES ? @printf("✓ %+.6e  (%.1fs)\n", obj_pu, t_pu) :
                                       @printf("✗ %s  (%.1fs)\n", status_pu, t_pu)
        println()

        push!(rows, Row(stem, n_buses, n_gens,
                        status_si, obj_si, t_si, status_pu, obj_pu, t_pu))
        _flush_results(rows)   # checkpoint after every case
    end

    n_si = count(r -> r.status_si in SOLVED_STATUSES, rows)
    n_pu = count(r -> r.status_pu in SOLVED_STATUSES, rows)
    open(REPORT_MD, "w") do io
        println(io, "# ENWL Benchmark OPF Results (reduced networks)\n")
        println(io, "Solver: **Ipopt** (local NLP, AC rectangular power flow)  ")
        println(io, "Networks: simplified via `simplify_network` (series merge, dangling removal)  ")
        println(io, "Formulation: 4-wire, phase-to-neutral voltage bounds, single-phase DERs  ")
        println(io, raw"Objective: minimise total generation cost ($/s)  ")
        println(io, "Max iterations: $OPF_MAX_ITER\n")
        println(io, raw"| Network | Buses | Gens | SI status | Obj SI ($/s) | SI time | PU status | Obj PU ($/s) | PU time | Δ (PU−SI)/SI |")
        println(io,   "|---------|------:|-----:|-----------|-------------:|--------:|-----------|-------------:|--------:|-------------|")
        for r in rows
            @printf(io, "| %s | %d | %d | %s | %s | %.1fs | %s | %s | %.1fs | %s |\n",
                    r.name, r.n_buses, r.n_gens,
                    r.status_si in SOLVED_STATUSES ? "✓" : "✗", _fmt_obj(r.status_si, r.objective_si), r.time_si,
                    r.status_pu in SOLVED_STATUSES ? "✓" : "✗", _fmt_obj(r.status_pu, r.objective_pu), r.time_pu,
                    _fmt_delta(r.objective_si, r.objective_pu))
        end
        println(io, "\n**Summary:** $(n_si)/$(length(rows)) solved in SI, " *
                    "$(n_pu)/$(length(rows)) solved in per-unit.")
    end
    println("[opf] $RESULT_JSON\n      $REPORT_MD\n")
end

# ── Stage: solutions ──────────────────────────────────────────────────────────
# Solve each reduced case (SI) and write a profile_solution report beside it.

function stage_solutions()
    sources = discover_cases(REDUCED_DIR)
    println("[solutions] Solving OPF for $(length(sources)) reduced case(s).\n")

    ok = 0; failed = 0; infeasible = 0
    for src in sources
        stem     = splitext(basename(src))[1]
        out_path = joinpath(REDUCED_DIR, stem * "_solution.md")
        print("  $stem … ")
        t0 = time()
        try
            net    = parse_bmopf(src)
            result = solve_opf(net; optimizer=_optimizer())
            status = get(result, "termination_status", "UNKNOWN")
            report = profile_solution(net, result)
            render_solution(report, out_path)

            dt    = round(time() - t0; digits=1)
            obj   = get(result, "objective", NaN)
            obj_s = isfinite(obj) ? "obj=$(round(obj; digits=2))" : "obj=?"
            println("✓  $status  $obj_s  $(length(errors(report)))E/$(length(warnings(report)))W  $(dt)s")
            status in SOLVED_STATUSES ? (ok += 1) : (infeasible += 1)
        catch e
            println("✗")
            @error "Failed: $stem" exception=(e, catch_backtrace())
            failed += 1
        end
    end
    println("\n[solutions] $ok solved, $infeasible infeasible/suboptimal, $failed errored → $REDUCED_DIR\n")
end

# ── Dispatch ──────────────────────────────────────────────────────────────────

const STAGES = (
    outputs   = stage_outputs,
    opf       = stage_opf,
    solutions = stage_solutions,
)

function main(args)
    requested = isempty(args) ? collect(keys(STAGES)) : Symbol.(args)
    for s in requested
        if !haskey(STAGES, s)
            valid = join(keys(STAGES), ", ")
            println(stderr, "Unknown stage: $s. Valid stages: $valid")
            exit(1)
        end
    end
    for s in requested
        STAGES[s]()
    end
    println("Done.")
end

main(ARGS)
