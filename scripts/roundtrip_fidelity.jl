"""
    roundtrip_fidelity.jl

Map out where the BMOPF → OpenDSS export (`to_dss`) loses fidelity, by round-
tripping the test corpus DSS → BMOPF → DSS and diagnosing the differences with
three signal sources (PowerIO warnings, semantic BMOPF diff, OpenDSS power-flow
cross-check). See test/roundtrip_helpers.jl for the machinery.

Corpus tiers:
  Tier A — all 33 test/data/pf_comparison/*.dss (one feature per case).
  Tier B — a curated sample of real networks (LV / SWER / meshed / ENWL / dsuite).
  Tier C — the full ~854-file corpus (opt-in via --all).

Outputs (under output/roundtrip_fidelity/):
  case_matrix.md      per-case × per-signal table
  failure_map.md      grouped by (component_type, failure_mode)
  case_reports.json   full machine-readable CaseReport array
  diffs.csv           one row per semantic Diff
  pf.csv              one row per case PF result

The power-flow cross-check needs OpenDSSDirect, which is a *test-only* extra of
BMOPFTools. Running with `--project` (the main project) therefore skips the PF
gate. To exercise it, run from an environment that provides both BMOPFTools and
OpenDSSDirect, e.g.:
    julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.develop(path="."); \\
              Pkg.add("OpenDSSDirect"); include("scripts/roundtrip_fidelity.jl"); main()'
The committed regression testset (test/runtests.jl) always runs the PF gate,
since the package test target includes OpenDSSDirect.

Usage:
    julia --project scripts/roundtrip_fidelity.jl                 # Tier A + B
    julia --project scripts/roundtrip_fidelity.jl --tier-a-only
    julia --project scripts/roundtrip_fidelity.jl --all           # + full corpus
    julia --project scripts/roundtrip_fidelity.jl --cases pf_1ph_line,pf_yd_xfmr
    julia --project scripts/roundtrip_fidelity.jl --out /tmp/rt
"""

using Pkg
# Only fall back to the main project when the active environment does not already
# provide BMOPFTools (so a test/temp env carrying OpenDSSDirect is respected and
# the PF gate can fire).
if isnothing(Base.identify_package("BMOPFTools"))
    Pkg.activate(joinpath(@__DIR__, ".."))
end

using BMOPFTools
using JSON3
using Logging

const _HAS_ODS = !isnothing(Base.identify_package("OpenDSSDirect"))
if _HAS_ODS
    @eval using OpenDSSDirect
end

include(joinpath(@__DIR__, "..", "test", "roundtrip_helpers.jl"))

const DATA_DIR   = normpath(joinpath(@__DIR__, "..", "test", "data"))
const OUTPUT_DIR = normpath(joinpath(@__DIR__, "..", "output", "roundtrip_fidelity"))

# ── Corpus enumeration ──────────────────────────────────────────────────────

"All 33 systematic feature cases."
function tier_a_paths()
    dir = joinpath(DATA_DIR, "pf_comparison")
    [(joinpath(dir, f), :A) for f in sort(readdir(dir)) if endswith(f, ".dss")]
end

"Curated representative real networks (kept small for the default run)."
function tier_b_paths()
    rel = [
        joinpath("LV", "LV14_13bus", "Master.dss"),      # smallest LV
        joinpath("LV", "LV1_14bus", "Master.dss"),       # known-good fixture
        joinpath("LV", "LV15_137bus", "Master.dss"),     # mid
        joinpath("LV", "LV17_279bus", "Master.dss"),     # large
        joinpath("SWER", "Master.dss"),
        joinpath("MVLVmeshed", "Master.dss"),
        joinpath("ENWL", "network_1", "Feeder_1", "Master.dss"),
        joinpath("dsuite_networks_scaled_v1.1", "spd_r", "master_scaled.dss"),
        joinpath("dsuite_networks_scaled_v1.1", "spm_u", "master_scaled.dss"),
    ]
    [(joinpath(DATA_DIR, r), :B) for r in rel if isfile(joinpath(DATA_DIR, r))]
end

"Every Master.dss across the full corpus (Tier C, opt-in)."
function all_real_paths()
    out = Tuple{String,Symbol}[]
    for (root, _, files) in walkdir(DATA_DIR)
        occursin(joinpath("data", "pf_comparison"), root) && continue
        for f in files
            (f == "Master.dss" || f == "master_scaled.dss") &&
                push!(out, (joinpath(root, f), :C))
        end
    end
    sort!(out; by=first)
    out
end

# ── Report writers ──────────────────────────────────────────────────────────

_pfmark(pf::PFResult) = pf.skipped ? "–" : (pf_ok(pf) ? "✓" : "✗")
_dvstr(pf::PFResult)  = pf.skipped || isnan(pf.max_dV) ? "—" : string(round(pf.max_dV, digits=3))

function write_case_matrix(reports, path)
    open(path, "w") do io
        println(io, "# Round-trip fidelity — per-case × per-signal matrix\n")
        println(io, "| case | tier | parse_warn | export_warn | sem_diffs | pf | max_ΔV (V) | over_tol | errors |")
        println(io, "|------|------|-----------:|------------:|----------:|:--:|-----------:|---------:|-------:|")
        for r in reports
            println(io, "| $(r.case) | $(r.tier) | $(length(r.parse_warnings)) | ",
                    "$(length(r.export_warnings)) | $(length(r.semantic_diffs)) | ",
                    "$(_pfmark(r.pf)) | $(_dvstr(r.pf)) | $(length(r.pf.over_tol_nodes)) | ",
                    "$(length(r.errors)) |")
        end
    end
end

# Bucket every signal into (component_type, failure_mode) => Vector of (case, detail).
function _failure_buckets(reports)
    buckets = Dict{Tuple{Symbol,Symbol},Vector{Tuple{String,String}}}()
    push_b!(k, v) = push!(get!(buckets, k, Tuple{String,String}[]), v)
    for r in reports
        for d in r.semantic_diffs
            push_b!((d.component_type, classify_diff(d)), (r.case, d.path))
        end
        for w in unique(vcat(r.parse_warnings, r.export_warnings))
            push_b!(classify_warning(w), (r.case, first(w, min(length(w), 90))))
        end
        if !r.pf.skipped && !r.pf.solved
            push_b!((:network, :non_convergence), (r.case, r.pf.note))
        elseif !r.pf.skipped && r.pf.solved && !r.pf.matched
            push_b!((:network, :voltage_drift_over_tolerance),
                    (r.case, "max ΔV=$(round(r.pf.max_dV, digits=3)) V, $(length(r.pf.over_tol_nodes)) node(s)"))
        end
        for e in r.errors
            mode = occursin("to_dss", e) ? :export_error : :reparse_error
            push_b!((:network, mode), (r.case, first(e, min(length(e), 90))))
        end
    end
    buckets
end

function write_failure_map(reports, path)
    buckets = _failure_buckets(reports)
    open(path, "w") do io
        println(io, "# Round-trip fidelity — failure map\n")
        n_clean = count(r -> isempty(r.semantic_diffs) && isempty(r.errors) &&
                             pf_ok(r.pf), reports)
        println(io, "$(length(reports)) cases; $n_clean clean; ",
                "$(length(buckets)) (component × mode) failure groups.\n")
        for k in sort(collect(keys(buckets)); by=x -> (string(x[1]), string(x[2])))
            examples = buckets[k]
            cases = unique(first.(examples))
            println(io, "## $(k[1]) / $(k[2])  ($(length(cases)) case(s))")
            for (case, detail) in first(examples, min(length(examples), 3))
                println(io, "  - `$case` — $detail")
            end
            println(io)
        end
    end
end

_csv(x) = replace(string(x), "\"" => "'", "," => ";", "\n" => " ")

function write_diffs_csv(reports, path)
    open(path, "w") do io
        println(io, "case,component_type,subtype,id,field,kind,mode,v1,v2")
        for r in reports, d in r.semantic_diffs
            println(io, join(_csv.((r.case, d.component_type, d.subtype, d.id, d.field,
                                    d.kind, classify_diff(d), d.v1, d.v2)), ","))
        end
    end
end

function write_pf_csv(reports, path)
    open(path, "w") do io
        println(io, "case,tier,solved,matched,skipped,max_dV,n_nodes,over_tol,note")
        for r in reports
            p = r.pf
            println(io, join(_csv.((r.case, r.tier, p.solved, p.matched, p.skipped, p.max_dV,
                                    p.n_nodes_compared, length(p.over_tol_nodes), p.note)), ","))
        end
    end
end

function write_json(reports, path)
    payload = [(
        case = r.case, path = r.path, tier = r.tier,
        parse_warnings = r.parse_warnings, export_warnings = r.export_warnings,
        semantic_diffs = [(
            path = d.path, component_type = d.component_type, subtype = d.subtype,
            id = d.id, field = d.field, kind = d.kind, mode = classify_diff(d),
            v1 = string(d.v1), v2 = string(d.v2)) for d in r.semantic_diffs],
        pf = (solved = r.pf.solved, matched = r.pf.matched, skipped = r.pf.skipped,
              max_dV = isnan(r.pf.max_dV) ? nothing : r.pf.max_dV,
              n_nodes_compared = r.pf.n_nodes_compared,
              over_tol_nodes = [(node = n, dV = dv) for (n, dv) in r.pf.over_tol_nodes],
              note = r.pf.note),
        errors = r.errors,
    ) for r in reports]
    open(path, "w") do io
        JSON3.pretty(io, payload)
    end
end

function write_reports(reports, outdir)
    mkpath(outdir)
    write_case_matrix(reports, joinpath(outdir, "case_matrix.md"))
    write_failure_map(reports, joinpath(outdir, "failure_map.md"))
    write_diffs_csv(reports, joinpath(outdir, "diffs.csv"))
    write_pf_csv(reports, joinpath(outdir, "pf.csv"))
    write_json(reports, joinpath(outdir, "case_reports.json"))
end

# ── Entry point ─────────────────────────────────────────────────────────────

function _parse_args(args)
    opts = Dict{Symbol,Any}(:tier_a_only => false, :all => false,
                            :cases => String[], :out => OUTPUT_DIR)
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--tier-a-only"
            opts[:tier_a_only] = true
        elseif a == "--all"
            opts[:all] = true
        elseif a == "--cases"
            opts[:cases] = split(args[i += 1], ",")
        elseif a == "--out"
            opts[:out] = args[i += 1]
        else
            @warn "unknown argument" arg=a
        end
        i += 1
    end
    opts
end

function _select_paths(opts)
    paths = tier_a_paths()
    opts[:tier_a_only] || append!(paths, tier_b_paths())
    opts[:all] && append!(paths, all_real_paths())
    if !isempty(opts[:cases])
        want = Set(opts[:cases])
        paths = filter(p -> first(splitext(basename(first(p)))) in want, paths)
    end
    paths
end

function main(args=ARGS)
    opts = _parse_args(args)
    paths = _select_paths(opts)
    _HAS_ODS || @warn "OpenDSSDirect not available — power-flow cross-check skipped."
    @info "round-trip fidelity sweep" n_cases=length(paths) has_ods=_HAS_ODS out=opts[:out]

    workdir = joinpath(opts[:out], "tmp")
    mkpath(workdir)
    reports = run_corpus(paths; has_ods=_HAS_ODS, workdir=workdir)
    write_reports(reports, opts[:out])

    n_clean = count(r -> isempty(r.semantic_diffs) && isempty(r.errors) &&
                         pf_ok(r.pf), reports)
    @info "done" clean=n_clean total=length(reports) out=opts[:out]
    return reports
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
