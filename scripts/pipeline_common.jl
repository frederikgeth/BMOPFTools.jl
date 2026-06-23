# pipeline_common.jl
#
# Shared helpers for the ENWLbenchmark regeneration pipeline. Included (not
# imported) by run_benchmark.jl; assumes BMOPFTools is already on the load path.

using BMOPFTools
using Dates

# Output layout: output/ENWLbenchmark/{original,reduced}/
const BENCH_DIR    = normpath(joinpath(@__DIR__, "..", "output", "ENWLbenchmark"))
const ORIG_DIR     = joinpath(BENCH_DIR, "original")
const REDUCED_DIR  = joinpath(BENCH_DIR, "reduced")

# ASCII-tree rendering options, shared across every report.
const TREE_OPTS = (
    max_buses    = 200,
    max_depth    = 10,
    fold_chains  = true,
    legend_limit = 50,
)

"""
    discover_cases(dir) -> Vector{String}

Sorted absolute paths of the BMOPF JSON cases in `dir`, skipping the
results/opf/report artifacts that live alongside them.
"""
function discover_cases(dir)
    sort([
        f for f in readdir(dir; join=true)
        if isfile(f) && endswith(f, ".json") &&
           !occursin("_results", basename(f)) &&
           !occursin("_opf", basename(f)) &&
           !occursin("_report", basename(f))
    ])
end

"""
    write_reduction_md(net_orig, net_red, path)

Render the `_simplification_log` of a reduced network as a Markdown table:
bus/line deltas, an operation histogram, and the full operation log.
"""
function write_reduction_md(net_orig, net_red, path)
    log = get(net_red, "_simplification_log", [])
    b0  = length(get(net_orig, "bus",  Dict()))
    b1  = length(get(net_red,  "bus",  Dict()))
    l0  = length(get(net_orig, "line", Dict()))
    l1  = length(get(net_red,  "line", Dict()))

    op_counts = Dict{String,Int}()
    for e in log
        op = get(e, "operation", "unknown")
        op_counts[op] = get(op_counts, op, 0) + 1
    end

    open(path, "w") do io
        name = get(net_red, "name", basename(path))
        println(io, "# Simplification log: $name\n")
        println(io, "**Generated:** $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))  ")
        println(io, "**Buses:** $b0 → $b1 (−$(b0 - b1))  ")
        println(io, "**Lines:** $l0 → $l1 (−$(l0 - l1))  ")
        println(io, "**Operations:** $(length(log))\n")
        println(io, "## Summary by operation\n")
        println(io, "| Operation | Count |")
        println(io, "|-----------|------:|")
        for op in sort(collect(keys(op_counts)))
            println(io, "| `$op` | $(op_counts[op]) |")
        end
        println(io)
        if !isempty(log)
            println(io, "## Operation log\n")
            println(io, "| # | Operation | Element | Message |")
            println(io, "|--:|-----------|---------|---------|")
            for (i, e) in enumerate(log)
                op    = get(e, "operation",    "")
                etype = get(e, "element_type", "")
                eid   = get(e, "element_id",   "")
                msg   = get(e, "message",      "")
                println(io, "| $i | `$op` | $etype `$eid` | $msg |")
            end
            println(io)
        end
    end
end

"""
    write_variant(net, dir, stem; net_orig=nothing)

Write one network variant (JSON + analysis report + ASCII tree) into `dir`.
When `net_orig` is supplied, `net` is treated as the reduced variant and a
`_reduction.md` log is written too.
"""
function write_variant(net, dir, stem; net_orig=nothing)
    mkpath(dir)
    write_bmopf(net, joinpath(dir, stem * ".json"))
    render(analyze(net), joinpath(dir, stem * "_report.md"))
    open(joinpath(dir, stem * "_tree.txt"), "w") do io
        render_ascii_tree(net, io; TREE_OPTS...)
    end
    net_orig !== nothing &&
        write_reduction_md(net_orig, net, joinpath(dir, stem * "_reduction.md"))
    return net
end
