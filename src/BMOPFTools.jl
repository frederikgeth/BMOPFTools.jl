"""
    BMOPFTools

A Julia library for parsing, validating, analysing, and reporting on
BMOPF-format distribution network datasets.

The network data model is a plain `Dict{String,Any}` that mirrors the
BMOPF JSON schema exactly. No custom wrapper types are used for network
data, so data flows naturally to and from PowerModelsDistribution and
JSON without conversion.

# Public API

    net    = parse_bmopf(path)          # load from BMOPF JSON file
    net    = from_pmd(eng)              # convert PMD ENGINEERING dict
    report = analyze(net)               # run all analyses
    render(report, stdout)              # terminal output
    render(report, "report.md")         # markdown file

See also: `write_bmopf`, `to_pmd`.
"""
module BMOPFTools

using Dates
using LinearAlgebra
using Logging
using Statistics
using Graphs
using JSON3

# Stable URI for the BMOPF JSON schema. Will become a versioned path once the
# spec is frozen (e.g. /schema/v1/bmopf.json).
const _BMOPF_SCHEMA_URI =
    "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/schema/bmopf.json"

# Package version, read once at load time from the Project.toml.
const _BMOPFTOOLS_VERSION = string(pkgversion(BMOPFTools))

# Canonical list of transformer subtype keys under `net["transformer"][subtype]`.
# Generic loops that iterate every subtype should use this constant (visible to
# the OPF extension as `BMOPFTools.TRANSFORMER_SUBTYPES`) rather than repeating
# the tuple inline, so new subtypes flow through analysis/validation/IO for free.
# Sites that are genuinely subtype-specific (constraint dispatch, terminal arity,
# allowed-field lists, per-unit base selection, vector-group notation, Yprim
# builders) must still be edited by hand when a subtype is added.
const TRANSFORMER_SUBTYPES =
    ("single_phase", "center_tap", "wye_delta", "delta_wye",
     "single_phase_autotransformer", "open_delta_regulator")

# Transformer subtypes that do NOT galvanically isolate their two sides. The
# autotransformer ties from- and to-sides through a shared common winding/neutral
# and the open-delta regulator passes the shared phase straight through; both are
# tap-only, same-voltage-level devices, so their `bus_from`/`bus_to` stay in one
# galvanic zone. The remaining subtypes are true galvanic separations. Used by
# the galvanic-zone/island partitioning so regulators don't spuriously split a
# zone (and orphan it from its voltage reference).
const GALVANIC_CONTINUOUS_SUBTYPES =
    ("single_phase_autotransformer", "open_delta_regulator")

# ---------------------------------------------------------------------------
# Finding — the one struct in the library.
# Everything network-related stays as Dict{String,Any}; findings are outputs
# that need stable structure for rendering and programmatic use.
# ---------------------------------------------------------------------------

"""
    Severity

Severity level for a [`Finding`](@ref).

- `ERROR`   — will directly compromise OPF correctness or prevent execution
- `WARNING` — degrades result quality or indicates suspicious data
- `INFO`    — informational; worth knowing but not actionable
"""
@enum Severity ERROR WARNING INFO

"""
    Finding

A single diagnostic finding produced by any analysis or validation pass.

# Fields
- `severity`       — `ERROR`, `WARNING`, or `INFO`
- `code`           — stable dot-separated identifier, e.g. `"E.VOLT.LINE_CROSSING"`.
                     Use these for programmatic filtering; do not match on `message`.
- `section`        — which report section produced this, e.g. `:voltage_levels`
- `component_type` — `:bus`, `:line`, `:load`, `:transformer`, `:network`, etc.
- `component_id`   — the dict key of the affected component, or `nothing` for
                     network-level findings
- `message`        — human-readable description
- `detail`         — optional machine-readable metadata (actual vs expected
                     values, timestamps, etc.) for renderer and downstream use
"""
struct Finding
    severity::Severity
    code::String
    section::Symbol
    component_type::Symbol
    component_id::Union{String,Nothing}
    message::String
    detail::Union{Dict{String,Any},Nothing}
end

# Convenience constructors — detail is optional
Finding(sev, code, section, ctype, cid, msg) =
    Finding(sev, code, section, ctype, cid, msg, nothing)

"""
    SummaryReport

Assembled output of [`analyze`](@ref). Holds all section result dicts and
the complete finding log. Passed to [`render`](@ref) for output.

`results` maps section name → analysis output dict. Renderers walk this
structure; the keys are stable across versions.
"""
struct SummaryReport
    network_name::Union{String,Nothing}
    generated_at::DateTime
    results::Dict{Symbol,Dict{String,Any}}
    findings::Vector{Finding}
end

"""
    SolutionReport

Output of [`profile_solution`](@ref). Holds the network name, result metadata,
per-check summary dicts, and the complete finding log for the solution profile.
Pass to [`render_solution`](@ref) for Markdown output.
"""
struct SolutionReport
    network_name::Union{String,Nothing}
    generated_at::DateTime
    result_meta::Dict{String,Any}   # termination_status, objective, solve_time
    results::Dict{Symbol,Dict{String,Any}}
    findings::Vector{Finding}
end

errors(r::SolutionReport)   = errors(r.findings)
warnings(r::SolutionReport) = warnings(r.findings)
infos(r::SolutionReport)    = infos(r.findings)

# ---------------------------------------------------------------------------
# Accessors on Finding collections
# ---------------------------------------------------------------------------

"""
    errors(findings::Vector{Finding}) -> Vector{Finding}
    errors(report::SummaryReport) -> Vector{Finding}

The subset of findings with `ERROR` severity. See also [`warnings`](@ref),
[`infos`](@ref).
"""
errors(fs::Vector{Finding})   = filter(f -> f.severity == ERROR,   fs)

"""
    warnings(findings::Vector{Finding}) -> Vector{Finding}
    warnings(report::SummaryReport) -> Vector{Finding}

The subset of findings with `WARNING` severity. See also [`errors`](@ref),
[`infos`](@ref).
"""
warnings(fs::Vector{Finding}) = filter(f -> f.severity == WARNING, fs)

"""
    infos(findings::Vector{Finding}) -> Vector{Finding}
    infos(report::SummaryReport) -> Vector{Finding}

The subset of findings with `INFO` severity. See also [`errors`](@ref),
[`warnings`](@ref).
"""
infos(fs::Vector{Finding})    = filter(f -> f.severity == INFO,    fs)

errors(r::SummaryReport)   = errors(r.findings)
warnings(r::SummaryReport) = warnings(r.findings)
infos(r::SummaryReport)    = infos(r.findings)

@doc "Finding severity: will compromise OPF correctness or prevent execution." ERROR
@doc "Finding severity: degrades result quality or indicates suspicious data." WARNING
@doc "Finding severity: informational — worth knowing, not necessarily actionable." INFO

# ---------------------------------------------------------------------------
# Terminal-name conventions
# ---------------------------------------------------------------------------

"""
    _neutral_terminal(bus) -> Union{String,Nothing}

Identify the neutral terminal of a bus. Checks the explicit `neutral_terminal`
field first (spec-authoritative), then falls back to the documented naming
convention: a terminal named `"n"` or `"N"` (any case) is treated as neutral.
Returns `nothing` if no neutral can be identified.

The OpenDSS numeric convention ["1","2","3","4"] is resolved at import time by
`from_dss` (remapped to ["a","b","c","n"]) rather than here.
"""
function _neutral_terminal(bus::Dict{String,Any})::Union{String,Nothing}
    nt = get(bus, "neutral_terminal", nothing)
    nt isa String && return nt
    _neutral_terminal(get(bus, "terminal_names", String[]))
end

function _neutral_terminal(names::AbstractVector)::Union{String,Nothing}
    for nm in names
        lowercase(string(nm)) == "n" && return string(nm)
    end
    nothing
end

"""
    _neutral_pos(terminal_map) -> Union{Int,Nothing}

Return the 1-based position of the neutral terminal in `terminal_map`,
or `nothing` if none is identified.
"""
function _neutral_pos(terminal_map::AbstractVector)::Union{Int,Nothing}
    nt = _neutral_terminal(terminal_map)
    nt === nothing && return nothing
    findfirst(==(nt), string.(terminal_map))
end

"""
    _phase_positions(terminal_map) -> Vector{Int}

Return the 1-based positions of the non-neutral conductors in `terminal_map`.
"""
function _phase_positions(terminal_map::AbstractVector)::Vector{Int}
    np = _neutral_pos(terminal_map)
    [k for k in eachindex(terminal_map) if k != np]
end

"""
    _xfmr_winding_pairs(terminal_map) -> Vector{Tuple{Int,Union{Int,Nothing}}}

Winding terminal pairs `(p, q)` for one side of a single-phase transformer /
autotransformer, where each winding spans the terminal voltage `V_p − V_q`:

- **line-to-neutral** (a terminal named `"n"` is present): one phase→neutral
  winding per phase conductor, all sharing the neutral position `q`;
- **line-to-line** (no neutral, exactly two terminals): a single winding across
  the pair, `q` = the second terminal;
- otherwise (no neutral, ≠ 2 terminals): phase→ground windings (`q = nothing`,
  the implicit zero reference).

This lets the builders treat both `["1","n"]` (L-N) and `["1","2"]` (L-L) maps
uniformly — the return current always closes at `q`.
"""
function _xfmr_winding_pairs(terminal_map::AbstractVector)::Vector{Tuple{Int,Union{Int,Nothing}}}
    np = _neutral_pos(terminal_map)
    if np !== nothing
        return [(p, np) for p in _phase_positions(terminal_map)]
    elseif length(terminal_map) == 2
        return [(1, 2)]
    else
        return [(p, nothing) for p in _phase_positions(terminal_map)]
    end
end

"""
    _xfmr_turns_ratio(xfmr) -> Float64

Return N = v_ref_from / v_ref_to, defaulting to 1.0 if either field is missing
or v_ref_to is zero.
"""
function _xfmr_turns_ratio(xfmr::Dict{String,Any})::Float64
    vf = Float64(get(xfmr, "v_ref_from", 1.0))
    vt = Float64(get(xfmr, "v_ref_to",   1.0))
    iszero(vt) ? 1.0 : vf / vt
end

"""
    _autotransformer_neff(a, regulator_type) -> Float64

Effective from→to turns ratio `n_eff` for a step voltage regulator at fixed tap
ratio `a` (regulated/source, e.g. `a ∈ [0.9, 1.1]`). The OPF uses the wye-wye
convention `V_fr = n_eff·V_to` (so `V_to = V_fr/n_eff`). To realise a regulated
voltage `V_to = a·V_fr` for the standard ANSI **Type B** regulator we therefore
need `n_eff = 1/a`; **Type A** (series winding on the regulated side) is the
reciprocal connection, `n_eff = a`. See `_add_autotransformer!`.
"""
function _autotransformer_neff(a::Real, regulator_type::AbstractString)::Float64
    af = Float64(a)
    iszero(af) && return 1.0
    uppercase(strip(regulator_type)) == "A" ? af : 1.0 / af
end

"""
    _autotransformer_ratio(xfmr) -> Float64

Effective `n_eff` for an autotransformer/regulator object, reading `tap_ratio`
(default 1.0) and `regulator_type` (default "B"). For `open_delta_regulator`,
`tap_ratio` is a length-2 vector handled per regulator by the OPF; this scalar
helper is for the single-phase case.
"""
function _autotransformer_ratio(xfmr::Dict{String,Any})::Float64
    a  = Float64(get(xfmr, "tap_ratio", 1.0))
    rt = string(get(xfmr, "regulator_type", "B"))
    _autotransformer_neff(a, rt)
end

# ---------------------------------------------------------------------------
# Submodule includes — order matters; IO first, then analysis, then report
# ---------------------------------------------------------------------------

include("config.jl")

include("io/migrate.jl")
include("io/parse_bmopf.jl")
include("io/write_bmopf.jl")
include("io/from_pmd.jl")
include("io/to_pmd.jl")
include("io/from_dss.jl")
include("io/sideload_coordinates.jl")
include("io/to_ybus.jl")

include("analysis/inventory.jl")
include("analysis/voltage_levels.jl")
include("analysis/connectivity.jl")
include("analysis/diversity.jl")
include("analysis/operational.jl")
include("analysis/load_models.jl")
include("analysis/provenance.jl")
include("infeasibility/preflight.jl")

include("validation/schema.jl")
include("validation/completeness.jl")
include("validation/domain_rules.jl")
include("validation/redundancy.jl")
include("validation/integrity.jl")
include("validation/spec_conformance.jl")
include("validation/solution.jl")

include("network/simplify.jl")

include("report/formatting.jl")
include("report/render_terminal.jl")
include("report/render_markdown.jl")
include("report/render_ascii_tree.jl")
include("report/render_solution_markdown.jl")

include("infeasibility/infeasibility.jl")

include("augmentation.jl")

# ---------------------------------------------------------------------------
# Top-level entry points
# ---------------------------------------------------------------------------

"""
    analyze(net::Dict{String,Any}; t_index::Int=1) -> SummaryReport

Run all analysis and validation passes on a BMOPF network dict and return
a [`SummaryReport`](@ref).

For snapshot networks, `t_index` is ignored. For networks with a
`"time_series"` key, the snapshot at `t_index` is materialised first.
"""
function analyze(net::Dict{String,Any}; t_index::Int=1, config::Dict=_DEFAULT_CONFIG)
    working = is_timeseries(net) ? get_snapshot(net, t_index) : net
    findings = Finding[]
    results  = Dict{Symbol,Dict{String,Any}}()

    # Analysis passes — each appends to findings and returns a results dict
    results[:inventory]      = inventory_analysis(working, findings)
    results[:voltage_levels] = voltage_level_analysis(working, findings)
    results[:connectivity]   = connectivity_analysis(working, findings)
    results[:diversity]      = diversity_analysis(working, findings)
    results[:operational]    = operational_analysis(working, findings; config=config)
    results[:load_models]    = load_model_analysis(working, findings)
    results[:provenance]     = provenance_analysis(working, findings)
    results[:preflight]      = infeasibility_preflight(working, findings)

    # Validation passes
    results[:schema]         = schema_check(working, findings)
    results[:completeness]   = completeness_check(working, findings)
    results[:domain_rules]   = domain_rules_check(working, findings; thresholds=_domain_thresholds(config))
    results[:redundancy]     = redundancy_check(working, findings)
    results[:integrity]      = integrity_check(working, findings)
    results[:spec]           = spec_conformance_check(working, findings)
    results[:benchmark]      = benchmark_readiness_check(working, findings)

    SummaryReport(
        get(net, "name", nothing),
        now(),
        results,
        findings
    )
end

"""
    analyze(path::AbstractString; kwargs...) -> SummaryReport

Parse a BMOPF JSON file and run [`analyze`](@ref).
"""
analyze(path::AbstractString; kwargs...) = analyze(parse_bmopf(path); kwargs...)

"""
    render(report::SummaryReport, dest; kwargs...)

Render a [`SummaryReport`](@ref) to `dest`.

- `dest::IO`            — writes terminal-formatted text (ANSI colour if tty)
- `dest::AbstractString` — writes to file; format inferred from extension
  (`.md` → Markdown, anything else → plain text)

# Keyword arguments
- `color::Bool` — force-enable/disable ANSI colour for IO dest (default: auto)
- `verbose::Bool` — include INFO-level findings (default: `true`)
"""
function render(report::SummaryReport, dest::IO; color::Bool=get(dest, :color, false), verbose::Bool=true)
    render_terminal(report, dest; color=color, verbose=verbose)
end

function render(report::SummaryReport, path::AbstractString; verbose::Bool=true)
    if endswith(path, ".md")
        open(path, "w") do io
            render_markdown(report, io; verbose=verbose)
        end
    else
        open(path, "w") do io
            render_terminal(report, io; color=false, verbose=verbose)
        end
    end
end

"""
    profile_solution(net, result; t_index::Int=1) -> SolutionReport

Profile an OPF result dict against the BMOPF network that produced it.
Checks bound satisfaction (voltage, thermal, generator dispatch), constraint
residuals, power balance, and produces informational summaries (loss fraction,
neutral shift).

`net` may be a snapshot or time-series network dict; `t_index` selects the
snapshot when time-series data is present. `result` is the dict returned by
[`solve_opf`](@ref) or any compatible solver.

Returns a [`SolutionReport`](@ref) which can be rendered to Markdown with
[`render_solution`](@ref).
"""
function profile_solution(net::Dict{String,Any}, result::Dict{String,Any};
                           t_index::Int=1)
    working  = is_timeseries(net) ? get_snapshot(net, t_index) : net
    findings = Finding[]
    results  = Dict{Symbol,Dict{String,Any}}()
    results[:solution] = solution_check(working, result, findings)
    results[:voltage_zones] = voltage_zone_summary(working, result)
    meta = Dict{String,Any}(
        "termination_status" => get(result, "termination_status", "UNKNOWN"),
        "objective"          => get(result, "objective",          NaN),
        "solve_time"         => get(result, "solve_time",         NaN),
    )
    SolutionReport(get(net, "name", nothing), now(), meta, results, findings)
end

"""
    render_solution(report::SolutionReport, dest; verbose::Bool=true)

Render a [`SolutionReport`](@ref) to `dest`.

- `dest::IO`             — writes Markdown text
- `dest::AbstractString` — writes to file (`.md` extension recommended)
"""
function render_solution(report::SolutionReport, dest::IO; verbose::Bool=true)
    render_solution_markdown(report, dest; verbose=verbose)
end

function render_solution(report::SolutionReport, path::AbstractString; verbose::Bool=true)
    open(path, "w") do io
        render_solution_markdown(report, io; verbose=verbose)
    end
end

# ---------------------------------------------------------------------------
# OPF entry point — implementation lives in ext/BMOPFOpfExt (loaded when
# JuMP and Ipopt are both available in the calling environment).
# ---------------------------------------------------------------------------

"""
    solve_opf(net::Dict{String,Any}; optimizer=Ipopt.Optimizer, t_index::Int=1,
              per_unit::Bool=false, s_base::Float64=1e6,
              volt_var_watt_eps::Float64=2e-3) -> Dict{String,Any}

Solve the four-wire rectangular current-voltage (IVR-EN) optimal power flow
on a BMOPF network dict. Requires JuMP and Ipopt to be loaded in the calling
environment before calling this function.

When `per_unit=true` the model is built and solved in per-unit (V_base
propagated from the source bus through transformers; S_base = `s_base` VA,
default 1 MVA). All results are returned in SI units regardless.

## Smart-inverter Volt-var / Volt-watt

An inverter whose `control_profile` declares a `volt_var` and/or `volt_watt`
sub-object follows a voltage-dependent droop: Volt-watt caps active power,
`P_k ≤ p_base · f^VW(|U_k|)`, and Volt-var pins reactive power to the curve,
`Q_k = q_base · f^VV(|U_k|)`. Each piecewise-linear characteristic is encoded as
a sum of shifted/scaled smooth-ReLU (softplus) terms so the model stays
differentiable for Ipopt; `volt_var_watt_eps` is the relative corner-smoothing
(smaller → sharper kinks, larger → smoother). Breakpoint voltages are SI volts
(phase-to-neutral) regardless of `per_unit`. Supported for SINGLE_PHASE and
FOUR_LEG inverters; for THREE_LEG (delta) the droop is ignored (box bounds
retained) with a warning. Default characteristics for a region (e.g. AS/NZS
4777.2:2020 "Australia A" for Queensland) can be injected by `augment_case`
via the `[augment.smart_inverter]` config section.

Returns a results dict with keys:
- `"termination_status"` — JuMP termination status string
- `"objective"` — optimal objective value (total generation cost, W·\$/W)
- `"solve_time"` — wall-clock solve time (s)
- `"bus"` — per-bus voltage results: `"vr"`, `"vi"`, `"vm"`, `"va"` per terminal
- `"line"` — per-line from/to current results per conductor
- `"generator"` — per-generator P/Q dispatch results
- `"voltage_source"` — per-source current injection results
- `"initialisation"` — per-bus, per-terminal Ipopt start values:
  `"vr_init"`, `"vi_init"`, `"vm_init"`, `"va_init"` (SI, same units as `"bus"`).
  Always present. Pass to [`profile_solution`](@ref) to diagnose convergence issues.
"""
function solve_opf end
export solve_opf

"""
    solve_feasibility_opf(net::Dict{String,Any}; optimizer=nothing, t_index::Int=1)
        -> Dict{String,Any}

Feasibility-relaxed variant of [`solve_opf`](@ref). Adds elastic slack current
injections at every non-source bus terminal so that KCL can always be satisfied,
then minimises the L2² norm of those slacks.

Because the problem is always feasible, the solver always converges. Non-zero
slacks in the result indicate where the network cannot satisfy its physical
constraints. Use [`diagnose_infeasibility`](@ref) to interpret the result.

Requires JuMP and Ipopt (same as `solve_opf`).

Additional result keys beyond `solve_opf`:
- `"slack_injections"`        — per-bus, per-terminal `cs_r`, `cs_i`, `cs_mag` (A)
- `"total_slack_magnitude_A"` — L2 norm of all slack injections (A)
- `"is_feasibility_opf"`      — always `true`, used by `diagnose_infeasibility`
"""
function solve_feasibility_opf end
export solve_feasibility_opf

"""
    solve_pf(net::Dict{String,Any}; optimizer=Ipopt.Optimizer, t_index::Int=1,
             per_unit::Bool=false, s_base::Float64=1e6) -> Dict{String,Any}

Determined four-wire rectangular current-voltage (IVR-EN) power flow on a BMOPF
network dict. Same device models as [`solve_opf`](@ref) but with **no operational
bounds and no objective**: fixed source voltages, constant-power injections, and
exact KCL fully determine the nodal state.

Device current/thermal limits and voltage bounds are intentionally ignored — the
power flow reports whatever results from the physics; use `solve_opf` or a
post-solve validation pass when limits must hold.

Generators must be **fixed setpoints** (`p_min == p_max` and `q_min == q_max`); a
non-degenerate range is rejected, since a power flow has no objective to choose a
dispatch within the range. Inverters under a `control_profile` are voltage-
dependent and remain determined.

Requires JuMP and Ipopt (same as `solve_opf`). The result dict matches
`solve_opf`'s structure plus `"is_power_flow" => true`.
"""
function solve_pf end
export solve_pf

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

export Severity, ERROR, WARNING, INFO
export Finding, SummaryReport, SolutionReport
export errors, warnings, infos
export profile_solution, render_solution, solution_check, voltage_zone_summary
export parse_bmopf, write_bmopf, migrate
export from_pmd, to_pmd
export from_dss
export sideload_coordinates!
export analyze, render
export load_config                      # tunable thresholds (config/default.toml)
export is_timeseries, get_snapshot      # useful for interactive use

# Analysis and validation functions (used directly in tests)
export inventory_analysis
export voltage_level_analysis
export connectivity_analysis
export diversity_analysis
export operational_analysis
export load_model_analysis
export provenance_analysis
export infeasibility_preflight
export schema_check
export completeness_check
export domain_rules_check
export redundancy_check
export integrity_check
export spec_conformance_check
export benchmark_readiness_check
export render_markdown, render_terminal, render_ascii_tree
export augment_case, AugmentationRecipe, default_recipe
export fix_case, FixRecipe
export add_generators, GeneratorRecipe, default_generator_recipe
export add_inverters, InverterRecipe, default_inverter_recipe
export TransformationManifest, TransformEntry, manifest_to_dict, render_manifest
export diagnose_infeasibility
export merge_series_lines, remove_dangling_lines
export remove_open_switches, collapse_closed_switches
export simplify_network
export transformer_yprim, export_yprim, write_yprim

end # module BMOPFTools
