"""
    generate_output.jl

Pipeline 1: convert all DSS-sourced test cases to BMOPF JSON and generate
analysis reports, ASCII trees, simplified variants, and reduction logs.

Datasets covered (all under test/data/):
  LV/                          — CSIRO DAP individual LV feeders
  MV/                          — CSIRO DAP MV network (no sub-Master.dss)
  Master.dss (root)            — combined MV+LV system
  ENWL/                        — four-wire ENWL feeders
  ENWLvariants/                — three-wire impedance-transform variants
  dsuite_networks_scaled_v1.1/ — six UK LV D-Suite networks

Output per case:
  output/<dataset>/original/<stem>.json
  output/<dataset>/original/<stem>_report.md
  output/<dataset>/original/<stem>_tree.txt
  output/<dataset>/reduced/<stem>.json
  output/<dataset>/reduced/<stem>_report.md
  output/<dataset>/reduced/<stem>_tree.txt
  output/<dataset>/reduced/<stem>_reduction.md

Nothing is written to the root of output/<dataset>/.

Usage:
    julia --project scripts/generate_output.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using BMOPFTools
using Logging
using Dates

const DATA_DIR   = joinpath(@__DIR__, "..", "test", "data")
const OUTPUT_DIR = joinpath(@__DIR__, "..", "output")

const TREE_OPTS = (
    max_buses    = 200,
    max_depth    = 10,
    fold_chains  = true,
    legend_limit = 50,
)

# ── Reduction log renderer ────────────────────────────────────────────────────

function write_reduction_md(net_orig, net_red, path)
    log = get(net_red, "_simplification_log", [])
    b0  = length(get(net_orig, "bus",  Dict()))
    b1  = length(get(net_red,  "bus",  Dict()))
    l0  = length(get(net_orig, "line", Dict()))
    l1  = length(get(net_red,  "line", Dict()))

    # Count by operation
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
                op      = get(e, "operation",    "")
                etype   = get(e, "element_type", "")
                eid     = get(e, "element_id",   "")
                msg     = get(e, "message",      "")
                println(io, "| $i | `$op` | $etype `$eid` | $msg |")
            end
            println(io)
        end
    end
end

# ── Write all outputs for one variant (original or reduced) ──────────────────

function write_variant(net, dir, stem; net_orig=nothing)
    mkpath(dir)
    write_bmopf(net, joinpath(dir, stem * ".json"))
    report = analyze(net)
    render(report, joinpath(dir, stem * "_report.md"))
    open(joinpath(dir, stem * "_tree.txt"), "w") do io
        render_ascii_tree(net, io; TREE_OPTS...)
    end
    if net_orig !== nothing
        write_reduction_md(net_orig, net, joinpath(dir, stem * "_reduction.md"))
    end
    report
end

# ── Case discovery ────────────────────────────────────────────────────────────
# Each entry: (output_dataset, stem, master_path, network_name, meta)
# meta is a Dict written into net["meta"], or nothing.

cases = Tuple{String,String,String,String,Union{Dict,Nothing}}[]

# Helper to add a case
function add_case!(dataset, stem, master, name; meta=nothing)
    push!(cases, (dataset, stem, master, name, meta))
end

# ── LV: test/data/LV/<name>/Master.dss ───────────────────────────────────────
lv_dir = joinpath(DATA_DIR, "LV")
if isdir(lv_dir)
    for entry in sort(readdir(lv_dir))
        master = joinpath(lv_dir, entry, "Master.dss")
        isfile(master) || continue
        add_case!("LV", entry, master, entry)
    end
end

# ── Combined MV+LV: test/data/Master.dss ────────────────────────────────────
combined_master = joinpath(DATA_DIR, "Master.dss")
if isfile(combined_master)
    add_case!("combined", "MV_LV_combined", combined_master, "MV_LV_combined")
end

# ── ENWL 4-wire: test/data/ENWL/<network>/<feeder>/Master.dss ───────────────
enwl_dir = joinpath(DATA_DIR, "ENWL")
if isdir(enwl_dir)
    for (root, dirs, files) in walkdir(enwl_dir)
        "Master.dss" in files || continue
        rel   = relpath(root, enwl_dir)
        parts = splitpath(rel)
        stem  = join(parts, "_")
        name  = join(parts, " / ")
        add_case!("ENWL", stem, joinpath(root, "Master.dss"), name)
    end
end

# ── ENWLvariants: test/data/ENWLvariants/<variant>/<network>/<feeder>/Master.dss
# Output goes to output/ENWLvariants/<variant>/original/ and reduced/
enwlv_dir = joinpath(DATA_DIR, "ENWLvariants")
if isdir(enwlv_dir)
    for (root, dirs, files) in walkdir(enwlv_dir)
        "Master.dss" in files || continue
        rel   = relpath(root, enwlv_dir)
        parts = splitpath(rel)          # [variant, network, feeder]
        variant  = parts[1]
        stem     = join(parts[2:end], "_")
        name     = join(parts, " / ")
        dataset  = joinpath("ENWLvariants", variant)
        add_case!(dataset, stem, joinpath(root, "Master.dss"), name)
    end
end

# ── D-Suite: test/data/dsuite_networks_scaled_v1.1/<key>/master_scaled.dss ──
const DSUITE_NAMES = Dict(
    "spd_r" => "DSuite_SPD_Rural",
    "spd_s" => "DSuite_SPD_Suburban",
    "spd_u" => "DSuite_SPD_Urban",
    "spm_r" => "DSuite_SPM_Rural",
    "spm_s" => "DSuite_SPM_Suburban",
    "spm_u" => "DSuite_SPM_Urban",
)
dsuite_dir = joinpath(DATA_DIR, "dsuite_networks_scaled_v1.1")
if isdir(dsuite_dir)
    for key in sort(collect(keys(DSUITE_NAMES)))
        master = joinpath(dsuite_dir, key, "master_scaled.dss")
        isfile(master) || continue
        name = DSUITE_NAMES[key]
        meta = Dict{String,Any}(
            "source"    => "D-Suite Alpha v1.1",
            "reference" => "M. Deakin, DOI: 10.25405/data.ncl.27175317",
            "license"   => "CC-BY-4.0",
        )
        add_case!("DSuite", name, master, name; meta=meta)
    end
end

# Coordinate CSVs for D-Suite networks (bus_id, longitude, latitude — no header).
# PMD does not parse OpenDSS Buscoords, so we sideload them after conversion.
const DSUITE_COORD_CSV = Dict(
    key => joinpath(dsuite_dir, key, "opendss_xy_$(key)_scaled.csv")
    for key in keys(DSUITE_NAMES)
)

sort!(cases; by = c -> (c[1], c[2]))

println("Found $(length(cases)) case(s) across " *
        "$(length(unique(c[1] for c in cases))) dataset(s).\n")

# ── Process ───────────────────────────────────────────────────────────────────

let ok = 0, failed = 0
    for (dataset, stem, master, name, meta) in cases
        dataset_dir = joinpath(OUTPUT_DIR, dataset)
        orig_dir    = joinpath(dataset_dir, "original")
        red_dir     = joinpath(dataset_dir, "reduced")

        print("  $dataset / $stem … ")
        t0 = time()
        try
            net_orig = with_logger(NullLogger()) do
                from_dss(master)
            end
            net_orig["name"] = name
            meta !== nothing && (net_orig["meta"] = meta)

            # Sideload bus coordinates for D-Suite cases (the parser ignores Buscoords).
            # Coordinates from the original network propagate automatically to the
            # reduced network because simplify_network preserves bus dicts.
            coord_note = ""
            if dataset == "DSuite"
                dsuite_key = findfirst(v -> v == stem, DSUITE_NAMES)
                if dsuite_key !== nothing
                    csv = DSUITE_COORD_CSV[dsuite_key]
                    if isfile(csv)
                        n_matched, n_skipped = sideload_coordinates!(net_orig, csv)
                        coord_note = "  coords=$(n_matched)+$(n_skipped)skipped"
                    end
                end
            end

            net_red = simplify_network(net_orig)

            write_variant(net_orig, orig_dir, stem)
            write_variant(net_red,  red_dir,  stem; net_orig=net_orig)

            b0 = length(get(net_orig, "bus",  Dict()))
            b1 = length(get(net_red,  "bus",  Dict()))
            l0 = length(get(net_orig, "line", Dict()))
            l1 = length(get(net_red,  "line", Dict()))
            dt = round(time() - t0; digits=1)
            println("✓  buses $(b0)→$(b1) (-$(b0-b1))" *
                    "  lines $(l0)→$(l1) (-$(l0-l1))$(coord_note)  $(dt)s")
            ok += 1
        catch e
            println("✗")
            @error "Failed: $dataset/$stem" exception=(e, catch_backtrace())
            failed += 1
        end
    end

    println("\nDone: $ok processed, $failed failed.")
    println("Output written to $OUTPUT_DIR/<dataset>/{original,reduced}/")
end
