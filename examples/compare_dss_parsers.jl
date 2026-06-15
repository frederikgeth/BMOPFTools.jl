# =============================================================================
# Parser comparison: powerio (PR #82) vs PowerModelsDistribution
#
# Runs both parsers on every ENWL test case and reports:
#   - component count agreement
#   - bus name agreement
#   - conversion warnings from powerio (candidate feedback items)
#   - any findings that differ between the two parsing paths
#
# Prerequisites:
#   - powerio CLI built from eigenergy/powerio branch worktree-powerio-dist
#     (set BMOPFTOOLS_POWERIO_PATH or put `powerio` on PATH)
#   - PowerModelsDistribution in the active project
#     (julia --project=. after `Pkg.add("PowerModelsDistribution")`)
#
# Run:
#   BMOPFTOOLS_POWERIO_PATH=~/src/powerio/target/release/powerio \
#     julia --project=. examples/compare_dss_parsers.jl
# =============================================================================

using BMOPFTools
using PowerModelsDistribution
using Logging

const POWERIO = let p = get(ENV, "BMOPFTOOLS_POWERIO_PATH", Sys.which("powerio"))
    isnothing(p) && error(
        "powerio not found. Set BMOPFTOOLS_POWERIO_PATH to the binary path.")
    p
end

const DATA_DIR = normpath(joinpath(@__DIR__, "..", "test", "data", "ENWL"))
isdir(DATA_DIR) || error("ENWL data not found at $DATA_DIR")

println("powerio:  ", powerio_version(; powerio=POWERIO))
println("data dir: $(relpath(DATA_DIR))\n")

# ---------------------------------------------------------------------------
# Collect Master.dss files
# ---------------------------------------------------------------------------
cases = Tuple{String,String}[]          # (case_name, master_path)
for (root, dirs, files) in walkdir(DATA_DIR)
    "Master.dss" in files || continue
    rel  = relpath(root, DATA_DIR)
    push!(cases, (replace(rel, Base.Filesystem.path_separator => "/"), joinpath(root, "Master.dss")))
end
sort!(cases)
println("Found $(length(cases)) ENWL cases.\n")
println(rpad("Case", 30), rpad("buses", 8), rpad("lines", 8), rpad("loads", 8),
        rpad("count_ok", 10), "bus_names_ok")
println("─"^80)

results = []
for (name, master) in cases
    row = (; name, ok=true, issues=String[], warnings=String[])
    try
        net_dss, net_pmd = with_logger(NullLogger()) do
            net_dss = from_dss(master; powerio=POWERIO, name=name)
            eng     = parse_file(master; kron_reduce=false)
            net_pmd = from_pmd(eng)
            (net_dss, net_pmd)
        end

        # Collect powerio fidelity warnings (potential feedback items)
        warns = get(get(net_dss, "_meta", Dict()), "powerio_warnings", String[])

        # Component count comparison
        count_ok = true
        for key in ("bus", "line", "load", "linecode", "voltage_source")
            n_dss = length(get(net_dss, key, Dict()))
            n_pmd = length(get(net_pmd, key, Dict()))
            if n_dss != n_pmd
                push!(row.issues, "$(key): powerio=$(n_dss) pmd=$(n_pmd)")
                count_ok = false
            end
        end

        # Bus name comparison
        buses_dss = Set(lowercase.(keys(get(net_dss, "bus", Dict()))))
        buses_pmd = Set(lowercase.(keys(get(net_pmd, "bus", Dict()))))
        bus_ok = buses_dss == buses_pmd
        if !bus_ok
            only_dss = setdiff(buses_dss, buses_pmd)
            only_pmd = setdiff(buses_pmd, buses_dss)
            !isempty(only_dss) && push!(row.issues, "only in powerio: $(join(sort(collect(only_dss))[1:min(3,end)], ", "))")
            !isempty(only_pmd) && push!(row.issues, "only in pmd: $(join(sort(collect(only_pmd))[1:min(3,end)], ", "))")
        end

        n_bus = length(get(net_dss, "bus",  Dict()))
        n_lin = length(get(net_dss, "line", Dict()))
        n_ld  = length(get(net_dss, "load", Dict()))
        row = (; name, ok=count_ok && bus_ok, issues=row.issues, warnings=warns)

        mark = count_ok && bus_ok ? "✓" : "✗"
        println(rpad(name, 30), rpad(n_bus, 8), rpad(n_lin, 8), rpad(n_ld, 8),
                rpad(count_ok ? "✓" : "✗", 10), bus_ok ? "✓" : "✗")
    catch e
        row = (; name, ok=false, issues=["EXCEPTION: $(sprint(showerror, e)[1:120])"], warnings=String[])
        println(rpad(name, 30), "  ERROR: $(row.issues[1])")
    end
    push!(results, row)
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
println("\n", "─"^80)
n_ok   = count(r -> r.ok, results)
n_fail = length(results) - n_ok
println("Passed: $n_ok / $(length(results))")

if n_fail > 0
    println("\n### Cases with disagreements ###")
    for r in results
        r.ok && continue
        println("\n$(r.name):")
        for iss in r.issues
            println("  ⚠ $iss")
        end
    end
end

# ---------------------------------------------------------------------------
# Unique powerio conversion warnings (feedback for the PR)
# ---------------------------------------------------------------------------
all_warns = String[]
for r in results
    append!(all_warns, r.warnings)
end
unique_warns = unique(replace.(all_warns, r"(linecode|line|load) [^:]+:" => s"\1 <X>:"))
sort!(unique_warns)

println("\n### Unique powerio fidelity warnings ($(length(unique_warns)) categories) ###")
println("These represent information not representable in BMOPF JSON schema.")
println("Review as candidate feedback items for eigenergy/powerio PR #82.\n")
for w in unique_warns[1:min(40, end)]
    println("  ", w)
end
length(unique_warns) > 40 && println("  … and $(length(unique_warns)-40) more")
