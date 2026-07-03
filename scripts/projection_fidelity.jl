"""
    projection_fidelity.jl

Sweep the OPF-solution → OpenDSS-snapshot projection across a corpus and report,
per case, whether the solved OPF is reproduced by (B) BMOPF's own determined
re-solve and (C) an independent OpenDSS power flow:

    A = result["bus"]                       — the OPF prediction
    B = solve_pf(project_solution(net, r))  — BMOPF self-oracle
    C = OpenDSS(to_dss(dispatch_as_loads))  — independent oracle, via PowerIO

A≈B≈C ⇒ the OPF solution is feasible AND the PowerIO export is faithful. The pair
that disagrees localizes the fault (A≈B✗C ⇒ export bug; A✗B ⇒ projection/model).
The failure map that falls out is the feedback artifact for the PowerIO developers.

Corpus (projection only has teeth where a net carries controllable devices; the
raw pf_comparison decks import with none, so we AUGMENT):
  · DER   — transformer-free feeders + `add_ibrs` (the OpenDSS oracle can solve).
  · TAP   — transformer fixtures with the tap freed (`tap_min`/`tap_max`); A≈B
            holds, but C is currently blocked by PowerIO's `kvs=(NaN,NaN)` export.
  · REAL  — a real feeder + `add_ibrs` (has a transformer → C blocked, A≈B works).

The OpenDSS leg needs OpenDSSDirect (a test-only extra). Run from an environment
that provides BMOPFTools + JuMP + Ipopt + OpenDSSDirect, e.g.:
    julia -e 'using Pkg; Pkg.activate("test"); Pkg.develop(path="."); \\
              include("scripts/projection_fidelity.jl"); main()'

Outputs (under output/projection_fidelity/):
  projection_matrix.md    per-case × {pinned, A≈B, A≈C, B≈C, ΔV, warns, errors}
  projection_failure_map.md   grouped by failure mode + attributed PowerIO warnings
  projection_reports.json     machine-readable ProjectionReport array

Usage:
    julia scripts/projection_fidelity.jl              # DER + TAP + REAL
    julia scripts/projection_fidelity.jl --der-only
"""

using Pkg
if isnothing(Base.identify_package("BMOPFTools"))
    Pkg.activate(joinpath(@__DIR__, ".."))
end

using BMOPFTools
using JSON3

const _HAS_ODS = !isnothing(Base.identify_package("OpenDSSDirect"))
_HAS_ODS && @eval using OpenDSSDirect
const _HAS_JUMP_IPOPT = !isnothing(Base.identify_package("JuMP")) &&
                        !isnothing(Base.identify_package("Ipopt"))
_HAS_JUMP_IPOPT && @eval using JuMP, Ipopt

include(joinpath(@__DIR__, "..", "test", "roundtrip_helpers.jl"))

const DATA_DIR   = normpath(joinpath(@__DIR__, "..", "test", "data"))
const OUTPUT_DIR = normpath(joinpath(@__DIR__, "..", "output", "projection_fidelity"))
const PF_DIR     = joinpath(DATA_DIR, "pf_comparison")

const _ATOL = 2.0
const _RTOL = 0.02

# ── Corpus construction ─────────────────────────────────────────────────────
# Each entry is (label, kind, build) where build() -> net carrying controllable
# devices (or `nothing` to skip). Kept lazy so a build failure degrades to one
# error row rather than aborting the sweep.

# Transformer-free pf_comparison cases with loads — augmentable, OpenDSS-solvable.
const _DER_STEMS = ["pf_1ph_line", "pf_zip_1ph", "pf_exp_1ph", "pf_3ph_line",
                    "pf_delta_load", "pf_zip_3ph", "pf_zip_delta",
                    "pf_cap_wye", "pf_cap_delta",
                    "pf_1ph_freeneutral", "pf_1ph_impedanceneutral",
                    "pf_1ph_perfectneutral"]

# Transformer fixtures whose tap we free (subtype => stem).
const _TAP_CASES = [("delta_wye", "pf_dy_xfmr_tap"), ("delta_wye", "pf_dy_xfmr"),
                    ("wye_delta", "pf_yd_xfmr")]

function _augment_der(stem)
    net = from_dss(joinpath(PF_DIR, "$stem.dss"))
    net2, _ = add_ibrs(net)
    isempty(get(net2, "ibr", Dict())) ? nothing : net2
end

function _free_tap(subtype, stem)
    net = from_dss(joinpath(PF_DIR, "$stem.dss"))
    sub = get(get(net, "transformer", Dict()), subtype, nothing)
    sub isa Dict && !isempty(sub) || return nothing
    for (_, x) in sub
        base = get(x, "tap", 1.0)
        x["tap_min"] = 0.9 * base; x["tap_max"] = 1.1 * base
    end
    net
end

function build_corpus(; der_only::Bool=false)
    corpus = Tuple{String,Symbol,Function}[]
    for s in _DER_STEMS
        push!(corpus, (s, :DER, () -> _augment_der(s)))
    end
    if !der_only
        for (st, s) in _TAP_CASES
            push!(corpus, (s * "[free-tap]", :TAP, () -> _free_tap(st, s)))
        end
        real = joinpath(DATA_DIR, "LV", "LV1_14bus", "Master.dss")
        isfile(real) && push!(corpus, ("LV1_14bus", :REAL,
            () -> (n = from_dss(real); n2 = add_ibrs(n)[1];
                   isempty(get(n2, "ibr", Dict())) ? nothing : n2)))
    end
    corpus
end

# ── Per-case run ────────────────────────────────────────────────────────────

struct ProjCase
    label::String
    kind::Symbol
    report::Union{ProjectionReport,Nothing}
    error::String
end

function run_case(label, kind, build, opt; has_ods)
    net = try
        build()
    catch e
        return ProjCase(label, kind, nothing, "build: $(sprint(showerror, e))")
    end
    net === nothing && return ProjCase(label, kind, nothing, "no controllable device placed")
    result = try
        solve_opf(net; optimizer=opt)
    catch e
        return ProjCase(label, kind, nothing, "solve_opf: $(sprint(showerror, e))")
    end
    if get(result, "feasible", true) === false
        return ProjCase(label, kind, nothing, "OPF infeasible ($(result["termination_status"]))")
    end
    rep = try
        run_projection_case(replace(label, r"[^\w]" => "_"), net, result;
                            optimizer=opt, has_ods=has_ods, atol=_ATOL, rtol=_RTOL)
    catch e
        return ProjCase(label, kind, nothing, "run_projection_case: $(sprint(showerror, e))")
    end
    ProjCase(label, kind, rep, "")
end

# ── Report writers ──────────────────────────────────────────────────────────

_mark(pf::PFResult) = pf.skipped ? "–" : (pf_ok(pf) ? "✓" : "✗")
_dv(pf::PFResult)   = (pf.skipped || isnan(pf.max_dV)) ? "—" : string(round(pf.max_dV, digits=3))

function write_matrix(cases, path)
    open(path, "w") do io
        println(io, "# Projection fidelity — per-case matrix\n")
        println(io, "A = OPF prediction · B = solve_pf(projected) · C = OpenDSS(export). ",
                    "`✓`=within atol=$(_ATOL) V / rtol=$(_RTOL); `–`=not run; `✗`=mismatch/non-convergence.\n")
        println(io, "| case | kind | gen/ibr | taps | A≈B | A≈C | B≈C | max ΔV A≈C (V) | export_warn | errors |")
        println(io, "|------|------|-------:|-----:|:---:|:---:|:---:|--------------:|------------:|-------:|")
        for c in cases
            if c.report === nothing
                println(io, "| $(c.label) | $(c.kind) | — | — | — | — | — | — | — | $(c.error) |")
            else
                r = c.report
                ntap = length(get(r.projection_meta, "free_taps", []))
                println(io, "| $(c.label) | $(c.kind) | $(r.n_pinned) | $ntap | $(_mark(r.ab)) | ",
                        "$(_mark(r.ac)) | $(_mark(r.bc)) | $(_dv(r.ac)) | ",
                        "$(length(r.export_warnings)) | $(length(r.errors)) |")
            end
        end
    end
end

function write_failure_map(cases, path)
    buckets = Dict{Tuple{Symbol,Symbol},Vector{Tuple{String,String}}}()
    push_b!(k, v) = push!(get!(buckets, k, Tuple{String,String}[]), v)
    for c in cases
        if c.report === nothing
            push_b!((:harness, :case_setup), (c.label, c.error)); continue
        end
        r = c.report
        !pf_ok(r.ab) && push_b!((:projection, :self_consistency_off),
                                (c.label, "A≈B max ΔV=$(_dv(r.ab)) V — projection/OPF disagreement"))
        if !r.ac.skipped && !r.ac.solved
            push_b!((:powerio_export, :opendss_nonconvergence), (c.label, r.ac.note))
        elseif !r.ac.skipped && r.ac.solved && !r.ac.matched
            push_b!((:powerio_export, :oracle_voltage_drift),
                    (c.label, "A≈C max ΔV=$(round(r.ac.max_dV, digits=3)) V, $(length(r.ac.over_tol_nodes)) node(s)"))
        end
        for w in unique(r.export_warnings)
            push_b!(classify_warning(w), (c.label, first(w, min(length(w), 100))))
        end
        for e in r.errors
            push_b!((:harness, :stage_error), (c.label, first(e, min(length(e), 100))))
        end
    end
    open(path, "w") do io
        println(io, "# Projection fidelity — failure map\n")
        n_full = count(c -> c.report !== nothing && pf_ok(c.report.ab) &&
                            pf_ok(c.report.ac) && isempty(c.report.errors), cases)
        println(io, "$(length(cases)) cases; $n_full fully consistent (A≈B≈C); ",
                    "$(length(buckets)) failure groups.\n")
        println(io, "> A≈B✗C ⇒ **PowerIO export bug** · A✗B ⇒ projection/model · ",
                    "harness ⇒ case setup / solver.\n")
        for k in sort(collect(keys(buckets)); by=x -> (string(x[1]), string(x[2])))
            ex = buckets[k]
            cs = unique(first.(ex))
            println(io, "## $(k[1]) / $(k[2])  ($(length(cs)) case(s))")
            for (lab, detail) in first(ex, min(length(ex), 5))
                println(io, "  - `$lab` — $detail")
            end
            println(io)
        end
    end
end

function _report_dict(c::ProjCase)
    d = Dict{String,Any}("label" => c.label, "kind" => string(c.kind), "error" => c.error)
    if c.report !== nothing
        r = c.report
        pf(p) = Dict("solved"=>p.solved, "matched"=>p.matched, "skipped"=>p.skipped,
                     "max_dV"=>p.max_dV, "n_nodes"=>p.n_nodes_compared,
                     "over_tol"=>length(p.over_tol_nodes), "note"=>p.note)
        d["n_pinned"] = r.n_pinned
        d["ab"] = pf(r.ab); d["ac"] = pf(r.ac); d["bc"] = pf(r.bc)
        d["export_warnings"] = r.export_warnings
        d["projection_meta"] = r.projection_meta
        d["errors"] = r.errors
    end
    d
end

# ── Main ─────────────────────────────────────────────────────────────────────

function main(args=ARGS)
    if !_HAS_JUMP_IPOPT
        @error "projection_fidelity needs JuMP + Ipopt"; return
    end
    der_only = "--der-only" in args
    opt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    workdir = mktempdir()
    corpus = build_corpus(; der_only=der_only)

    @info "projection_fidelity" cases=length(corpus) has_ods=_HAS_ODS der_only=der_only
    cases = ProjCase[]
    for (label, kind, build) in corpus
        c = run_case(label, kind, build, opt; has_ods=_HAS_ODS)
        push!(cases, c)
        if c.report === nothing
            @info "  $label [$kind]: SKIP/ERROR — $(c.error)"
        else
            r = c.report
            @info "  $label [$kind]" pinned=r.n_pinned AB=_mark(r.ab) AC=_mark(r.ac) BC=_mark(r.bc) warns=length(r.export_warnings)
        end
    end

    mkpath(OUTPUT_DIR)
    write_matrix(cases, joinpath(OUTPUT_DIR, "projection_matrix.md"))
    write_failure_map(cases, joinpath(OUTPUT_DIR, "projection_failure_map.md"))
    open(joinpath(OUTPUT_DIR, "projection_reports.json"), "w") do io
        JSON3.pretty(io, [_report_dict(c) for c in cases]; allow_inf=true)
    end
    @info "wrote reports" dir=OUTPUT_DIR
    cases
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
