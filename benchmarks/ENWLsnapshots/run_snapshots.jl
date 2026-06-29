"""
    run_snapshots.jl

Solve every ENWL snapshot case under benchmarks/ENWLsnapshots/ with the BMOPF
engine in both SI and per-unit modes, write the analysis reports + results JSON
next to each input, and build a single cross-case overview at the tree root.

For each input  <stem>.bmopf.json  in each feeder folder, writes alongside it:

    <stem>_report.md        findings analysis (network, solver-independent; once)
    <stem>_result_si.json   results JSON, SI mode
    <stem>_result_pu.json   results JSON, per-unit mode
    <stem>_solution_si.md   results analysis, SI mode
    <stem>_solution_pu.md   results analysis, per-unit mode

and at benchmarks/ENWLsnapshots/:

    opf_summary.json        per-case rows (checkpointed after every case)
    opf_summary.md          SI-vs-PU comparison table + aggregate metrics

Usage:
    julia --project=scripts benchmarks/ENWLsnapshots/run_snapshots.jl
    julia --project=scripts benchmarks/ENWLsnapshots/run_snapshots.jl 30bus_LG 99bus_LN

With no args every feeder folder is processed; otherwise only the named ones.
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..", "scripts")))

using BMOPFTools
using JuMP, Ipopt
using JSON3
using Printf
using Statistics

const SNAP_DIR = @__DIR__
const SUMMARY_JSON = joinpath(SNAP_DIR, "opf_summary.json")
const SUMMARY_MD   = joinpath(SNAP_DIR, "opf_summary.md")

const SOLVED_STATUSES = ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
const OPF_MAX_ITER = 500

# Export-maximising objective. The DERs carry no cost (left free); instead each
# input case carries a uniform positive linear `cost` on the slack's active-power
# *injection* (baked into the `voltage_source` of every *.bmopf.json so the cases
# solve standalone). Because that injection is import-positive (P_source > 0 =
# importing from grid), minimising Σ cost·P_source rewards exports, which — with
# loads fixed — pulls every PV to its maximum available / volt-watt-curtailed
# output. This makes the otherwise under-determined dispatch unique and
# mode-independent (SI ≡ PU). See objective.jl for the (uniform) cost convention.

_optimizer() = optimizer_with_attributes(Ipopt.Optimizer,
    "max_iter"    => OPF_MAX_ITER,
    "print_level" => 0,
    "tol"         => 1e-6,
)

# ── Case discovery ────────────────────────────────────────────────────────────

"""Sorted feeder sub-folders of benchmarks/ENWLsnapshots/ (optionally filtered)."""
function discover_folders(filter_names)
    folders = sort([
        d for d in readdir(SNAP_DIR; join=true)
        if isdir(d)
    ])
    isempty(filter_names) && return folders
    keep = Set(filter_names)
    sel = [d for d in folders if basename(d) in keep]
    missing = setdiff(keep, Set(basename.(folders)))
    isempty(missing) || @warn "Unknown folder(s) ignored" missing=collect(missing)
    return sel
end

"""Sorted input cases in a folder: the `*.bmopf.json` files, skipping artifacts."""
discover_inputs(dir) = sort([
    f for f in readdir(dir; join=true)
    if isfile(f) && endswith(f, ".bmopf.json")
])

# strip the trailing ".bmopf.json" to get the case stem
case_stem(path) = replace(basename(path), r"\.bmopf\.json$" => "")

# ── Solve helper ──────────────────────────────────────────────────────────────

function _run_solve(net, per_unit)
    status = "ERROR"; obj = nothing; t0 = time(); result = nothing
    try
        result = solve_opf(net; optimizer=_optimizer(), per_unit=per_unit)
        status = get(result, "termination_status", "UNKNOWN")
        obj    = get(result, "objective", nothing)
    catch e
        status = "ERROR: $(sprint(showerror, e))"
    end
    return result, status, obj, round(time() - t0; digits=1)
end

# ── Summary formatting ────────────────────────────────────────────────────────

_fmt_obj(status, obj) =
    status in SOLVED_STATUSES ? (obj === nothing ? "—" : @sprintf("%.6g", obj)) :
                                "`$(split(status, ':')[1])`"

function _fmt_delta(obj_si, obj_pu)
    (obj_si === nothing || obj_pu === nothing) && return "—"
    abs(obj_si) < 1e-12 && return "—"
    @sprintf("%+.4f%%", (obj_pu - obj_si) / abs(obj_si) * 100)
end

_flush_summary(rows) = open(SUMMARY_JSON, "w") do io
    JSON3.pretty(io, rows)
end

function write_summary_md(rows)
    n_si = count(r -> r["status_si"] in SOLVED_STATUSES, rows)
    n_pu = count(r -> r["status_pu"] in SOLVED_STATUSES, rows)
    t_si = sum(r -> r["time_si_s"], rows; init=0.0)
    t_pu = sum(r -> r["time_pu_s"], rows; init=0.0)
    times_si = [r["time_si_s"] for r in rows]
    times_pu = [r["time_pu_s"] for r in rows]
    n_feeders = length(unique(r["folder"] for r in rows))

    open(SUMMARY_MD, "w") do io
        println(io, "# ENWL Snapshots OPF Results (SI vs per-unit)\n")
        println(io, "Solver: **Ipopt** (local NLP, 4-wire IVR-EN rectangular OPF)  ")
        println(io, "Objective: **maximise system exports** — uniform positive cost " *
                    "on the slack active injection (baked into each case's voltage_source), " *
                    "DERs free; this pulls PV to its available / volt-watt-curtailed output " *
                    "and makes the dispatch unique (SI ≡ PU)  ")
        println(io, "Max iterations: $OPF_MAX_ITER  ")
        println(io, "Cases: $(length(rows)) (across $n_feeders feeders)\n")
        println(io, raw"| Folder | Case | Buses | Gens | SI | Obj SI ($/s) | SI time | PU | Obj PU ($/s) | PU time | Δ (PU−SI)/SI | E/W |")
        println(io,   "|--------|------|------:|-----:|----|-------------:|--------:|----|-------------:|--------:|-------------|-----|")
        for r in rows
            @printf(io, "| %s | %s | %d | %d | %s | %s | %.1fs | %s | %s | %.1fs | %s | %d/%d |\n",
                    r["folder"], r["name"], r["n_buses"], r["n_gens"],
                    r["status_si"] in SOLVED_STATUSES ? "✓" : "✗",
                    _fmt_obj(r["status_si"], r["objective_si"]), r["time_si_s"],
                    r["status_pu"] in SOLVED_STATUSES ? "✓" : "✗",
                    _fmt_obj(r["status_pu"], r["objective_pu"]), r["time_pu_s"],
                    _fmt_delta(r["objective_si"], r["objective_pu"]),
                    r["n_errors"], r["n_warnings"])
        end
        println(io)
        println(io, "## Aggregate metrics\n")
        println(io, "| Metric | SI | per-unit |")
        println(io, "|--------|---:|---------:|")
        @printf(io, "| Solved | %d/%d | %d/%d |\n", n_si, length(rows), n_pu, length(rows))
        @printf(io, "| Total solve time | %.1fs | %.1fs |\n", t_si, t_pu)
        @printf(io, "| Mean solve time | %.2fs | %.2fs |\n",
                mean(times_si), mean(times_pu))
        @printf(io, "| Median solve time | %.2fs | %.2fs |\n",
                median(times_si), median(times_pu))
        @printf(io, "| Max solve time | %.1fs | %.1fs |\n",
                maximum(times_si; init=0.0), maximum(times_pu; init=0.0))
    end
end

# ── Main ──────────────────────────────────────────────────────────────────────

function main(args)
    folders = discover_folders(args)
    inputs = [(folder=basename(d), path=p) for d in folders for p in discover_inputs(d)]
    n = length(inputs)
    println("[snapshots] $n case(s) across $(length(folders)) folder(s); solving SI + per-unit.\n")

    rows = Dict{String,Any}[]
    for (i, c) in enumerate(inputs)
        src  = c.path
        dir  = dirname(src)
        stem = case_stem(src)
        net  = parse_bmopf(src)   # export-reward slack cost is baked into the input
        n_buses = length(get(net, "bus",       Dict()))
        n_gens  = length(get(net, "generator", Dict()))
        @printf("[%3d/%d] %s/%s  (%d buses, %d gens)\n", i, n, c.folder, stem, n_buses, n_gens)

        # findings analysis — once per case (solver-independent)
        rpt = analyze(net)
        render(rpt, joinpath(dir, stem * "_report.md"))
        n_err = length(errors(rpt)); n_warn = length(warnings(rpt))

        # SI
        print("         SI  … "); flush(stdout)
        res_si, status_si, obj_si, t_si = _run_solve(net, false)
        if res_si !== nothing
            write_result(res_si, joinpath(dir, stem * "_result_si.json"))
            render_solution(profile_solution(net, res_si), joinpath(dir, stem * "_solution_si.md"))
        end
        status_si in SOLVED_STATUSES ? @printf("✓ %+.6e  (%.1fs)\n", obj_si, t_si) :
                                       @printf("✗ %s  (%.1fs)\n", split(status_si, '\n')[1], t_si)

        # per-unit
        print("         PU  … "); flush(stdout)
        res_pu, status_pu, obj_pu, t_pu = _run_solve(net, true)
        if res_pu !== nothing
            write_result(res_pu, joinpath(dir, stem * "_result_pu.json"))
            render_solution(profile_solution(net, res_pu), joinpath(dir, stem * "_solution_pu.md"))
        end
        status_pu in SOLVED_STATUSES ? @printf("✓ %+.6e  (%.1fs)\n", obj_pu, t_pu) :
                                       @printf("✗ %s  (%.1fs)\n", split(status_pu, '\n')[1], t_pu)
        println()

        push!(rows, Dict{String,Any}(
            "folder" => c.folder, "name" => stem,
            "n_buses" => n_buses, "n_gens" => n_gens,
            "status_si" => status_si, "objective_si" => obj_si, "time_si_s" => t_si,
            "status_pu" => status_pu, "objective_pu" => obj_pu, "time_pu_s" => t_pu,
            "n_errors" => n_err, "n_warnings" => n_warn,
        ))
        _flush_summary(rows)          # checkpoint after every case
    end

    write_summary_md(rows)
    n_si = count(r -> r["status_si"] in SOLVED_STATUSES, rows)
    n_pu = count(r -> r["status_pu"] in SOLVED_STATUSES, rows)
    println("[snapshots] $(n_si)/$n solved in SI, $(n_pu)/$n in per-unit.")
    println("            $SUMMARY_JSON\n            $SUMMARY_MD")
    println("Done.")
end

main(ARGS)
