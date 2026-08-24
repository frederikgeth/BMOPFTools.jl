"""
    BMOPFTools

A Julia library for parsing, validating, analysing, and reporting on
BMOPF-format distribution network datasets.

The network data model is a plain `Dict{String,Any}` that mirrors the
BMOPF JSON schema exactly. No custom wrapper types are used for network
data, so data flows naturally to and from JSON without conversion.

# Public API

    net    = parse_bmopf(path)          # load from BMOPF JSON file
    net    = from_dss("Master.dss")     # parse OpenDSS (via PowerIO.jl)
    report = analyze(net)               # run all analyses
    render(report, stdout)              # terminal output
    render(report, "report.md")         # markdown file
    to_dss(net, "out/Master.dss")       # write OpenDSS (via PowerIO.jl)

See also: `write_bmopf`, `to_pmd`, `to_dss`.
"""
module BMOPFTools

using Dates
using LinearAlgebra
using SparseArrays
using Logging
using Statistics
using Graphs
using JSON3
using StatsFuns: log1pexp
import PowerIO

# The published schema's own `$id`, stamped into `meta.$schema` on write. The
# path this used to stamp (`/schema/bmopf.json`) no longer exists upstream, so
# the URI resolved to nothing. `_SPEC_VERSIONS` still accepts it on read.
const _BMOPF_SCHEMA_URI =
    "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/" *
    "draft_schema_and_networks/draft_bmopf_schema.json"

# Package version, read once at load time from the Project.toml.
const _BMOPFTOOLS_VERSION = string(pkgversion(BMOPFTools))

"""
    COMPONENT_COLLECTIONS

Canonical tuple of top-level component collections — the keys of `net` that hold
a string-keyed dict of named component instances placed in the network
(`net["load"]["ld1"]`, `net["dc_bus"]["d1"]`, …).

This is the single source of truth for any function that must iterate every
component type. Generic loops should use it (as
`BMOPFTools.COMPONENT_COLLECTIONS`; it is module-internal, like
`TRANSFORMER_SUBTYPES`) rather than repeating the tuple inline, so a new
component type flows through IO, validation and analysis for free. Current
consumers: `each_terminal_array`, `_any_component_has_ts_ref` and `get_snapshot`
— which each used to keep their own inline list, and had already drifted apart.

**Adding a component type:** add its schema key here. Nothing else needs to
change. `test/registry_tests.jl` fails CI if a schema key is neither registered
here nor listed as a known non-component, and also if this tuple names a type the
schema no longer defines.

Deliberately *not* component collections:

| key | why |
|:--|:--|
| `transformer` | subtype-dispatched via `TRANSFORMER_SUBTYPES`; `net["transformer"]` is keyed by subtype, not by instance |
| `linecode`, `wire_data`, `line_geometry` | shared catalogs referenced *by* components; they define no terminals of their own |
| `time_series` | data store keyed by series id |
| `name`, `meta`, `extras`, `terminal_conventions` | scalars and document metadata |

See also `TS_COMPONENT_COLLECTIONS` for the time-series-capable subset.
"""
const COMPONENT_COLLECTIONS = (
    "bus", "line", "load", "generator", "voltage_source",
    "shunt", "switch", "ibr", "capacitor", "control_profile",
    "dc_bus", "dc_branch", "dc_grounding", "dc_load", "dc_source",
)

"""
    TS_COMPONENT_COLLECTIONS

Subset of `COMPONENT_COLLECTIONS` whose instances may carry a
`"time_series"` sub-dict that `get_snapshot` can actually materialise. Consumed
by `_any_component_has_ts_ref` (which decides whether a network counts as a
time-series network) and by `get_snapshot` (which resolves the references).

Currently this is every component collection except `control_profile`.

!!! note "Why control_profile is excluded"
    A control profile's scalable quantities (`volt_var.breakpoints`, `q_limits`,
    …) are nested *inside* control-law sub-objects, but `_resolve_component_ts!`
    only scales top-level numeric or vector params on a component. A
    `time_series` reference on a control profile therefore has no top-level value
    to scale, and resolving it would throw rather than materialise a snapshot.

    Including `control_profile` here is the natural fix once the resolver grows
    nested-path support (e.g. a `"volt_var.breakpoints"` key); until then it is
    held out deliberately, and a control-profile time-series reference is ignored
    exactly as it was before the registry existed.

`transformer` is absent for a different reason: it is not in
`COMPONENT_COLLECTIONS` at all. Its time-series references *are* resolved,
by a dedicated subtype-aware pass in `get_snapshot` and `_any_component_has_ts_ref`.
"""
const TS_COMPONENT_COLLECTIONS =
    Tuple(c for c in COMPONENT_COLLECTIONS if c != "control_profile")

# Canonical list of transformer subtype keys under `net["transformer"][subtype]`.
# Generic loops that iterate every subtype should use this constant (visible to
# the OPF extension as `BMOPFTools.TRANSFORMER_SUBTYPES`) rather than repeating
# the tuple inline, so new subtypes flow through analysis/validation/IO for free.
# Sites that are genuinely subtype-specific (constraint dispatch, terminal arity,
# allowed-field lists, per-unit base selection, vector-group notation, Yprim
# builders) must still be edited by hand when a subtype is added.
const TRANSFORMER_SUBTYPES =
    ("single_phase", "center_tap", "wye_delta", "delta_wye",
     "single_phase_autotransformer", "open_delta_regulator", "n_winding")

# Subtypes whose data is a winding-indexed list (`windings = [{bus, …}, …]`)
# rather than the two-bus `bus_from`/`bus_to` shape. These are handled by a
# fully independent code path (see `src/io/nwinding.jl` and
# `ext/BMOPFOpfExt/nwinding.jl`); generic loops over `TRANSFORMER_SUBTYPES` that
# assume the two-bus shape must branch on membership here and route to the
# n-winding helpers (or skip).
const WINDING_LIST_SUBTYPES = ("n_winding",)

# Transformer subtypes that do NOT galvanically isolate their two sides. The
# autotransformer ties from- and to-sides through a shared common winding/neutral
# and the open-delta regulator passes the shared phase straight through; both are
# tap-only, same-voltage-level devices, so their `bus_from`/`bus_to` stay in one
# galvanic zone. The remaining subtypes are true galvanic separations. Used by
# the galvanic-zone/island partitioning so regulators don't spuriously split a
# zone (and orphan it from its voltage reference).
const GALVANIC_CONTINUOUS_SUBTYPES =
    ("single_phase_autotransformer", "open_delta_regulator")

"""
    _xfmr_from_to_buses(subtype, t) -> (from::Vector{String}, to::Vector{String})

The "from" and "to" bus references of a transformer, unifying the two-bus and
winding-list (`n_winding`) shapes so generic downstream / connectivity loops can
handle both. Two-bus subtypes → `([bus_from], [bus_to])`; `n_winding` →
winding 1's bus as the from side and every other winding's bus as the to side.
Absent references drop out (empty vectors).
"""
function _xfmr_from_to_buses(subtype, t)::Tuple{Vector{String},Vector{String}}
    if subtype in WINDING_LIST_SUBTYPES
        ws = _nw_windings(t)
        isempty(ws) && return (String[], String[])
        return (isempty(ws[1].bus) ? String[] : String[ws[1].bus],
                String[w.bus for w in ws[2:end] if !isempty(w.bus)])
    end
    f  = get(t, "bus_from", nothing)
    tt = get(t, "bus_to",   nothing)
    (f  isa AbstractString ? String[f]  : String[],
     tt isa AbstractString ? String[tt] : String[])
end

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
    TerminalRoles

Resolved case-wide classification of terminal-name labels into `phase`,
`neutral` and `earth` roles (see [`_terminal_roles`](@ref)). `inferred` is
`true` when the roles were derived from the naming convention because the case
carried no explicit `terminal_conventions` block, and `false` when they were
read from that block.
"""
struct TerminalRoles
    phase::Set{String}
    neutral::Set{String}
    earth::Set{String}
    inferred::Bool
end

# Terminal-name label treated as neutral by the fallback naming convention
# (case-insensitive `"n"`/`"N"`). This is the single definition of the guess we
# make when a case declares no `terminal_conventions`.
_is_convention_neutral(name) = lowercase(string(name)) == "n"

"""
    _terminal_roles(net) -> TerminalRoles

Resolve the case-wide terminal-role classification for an AC network.

If `net["terminal_conventions"]` is present it is authoritative: the `phase`,
`neutral` and `earth` label lists are taken verbatim (matched exactly, including
case). Otherwise the roles are **inferred** from every bus's `terminal_names`
using the naming convention (`"n"`/`"N"` → neutral, everything else → phase, no
earth) and the returned value is flagged `inferred=true` — which
`W.CONV.TERMINAL_ROLES_INFERRED` reports during validation.

`dc_bus` terminals are out of scope (DC carries its own pole roles) and are not
scanned.
"""
function _terminal_roles(net::Dict{String,Any})::TerminalRoles
    tc = get(net, "terminal_conventions", nothing)
    if tc isa Dict
        strs(k) = Set{String}(string(x) for x in get(tc, k, String[]))
        return TerminalRoles(strs("phase"), strs("neutral"), strs("earth"), false)
    end
    phase = Set{String}()
    neutral = Set{String}()
    for (_, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        for t in get(bus, "terminal_names", String[])
            s = string(t)
            push!(_is_convention_neutral(s) ? neutral : phase, s)
        end
    end
    TerminalRoles(phase, neutral, Set{String}(), true)
end

"""
    _neutral_labels(net) -> Set{String}

The set of terminal-name labels that denote a neutral conductor for this case,
from the resolved [`TerminalRoles`](@ref). Pass this to the terminal-map helpers
(`_neutral_terminal`, `_neutral_pos`, `_phase_positions`, …) so they resolve the
neutral by the case's declared label(s) rather than the hard-wired `"n"` guess.
"""
_neutral_labels(net::Dict{String,Any})::Set{String} = _terminal_roles(net).neutral

"""
    _terminal_conventions_dict(net) -> Dict{String,Any}

Build an exportable `terminal_conventions` block for `net`. If the case already
declares one it is returned verbatim (sorted for a stable serialisation);
otherwise the roles are inferred from the naming convention and promoted to an
explicit block (`phase`/`neutral` populated from the bus terminal names, `earth`
empty). Used by `from_dss` to record the convention it knows at ingest and by
`write_bmopf` to guarantee the field is always exported.
"""
function _terminal_conventions_dict(net::Dict{String,Any})::Dict{String,Any}
    roles = _terminal_roles(net)
    Dict{String,Any}(
        "phase"   => sort!(collect(roles.phase)),
        "neutral" => sort!(collect(roles.neutral)),
        "earth"   => sort!(collect(roles.earth)),
    )
end

"""
    _materialize_terminal_roles!(net) -> net

Stamp each AC bus with a derived `neutral_terminal` field resolved from the
case's [`TerminalRoles`](@ref), so the per-bus `_neutral_terminal(bus)` accessor
returns the right terminal even when the case declares a non-`"n"` neutral label
via `terminal_conventions`. This is an in-memory convenience only — the field is
stripped on write (see `write_bmopf`) since it is re-derivable from the exported
`terminal_conventions`.

A bus that resolves to no neutral is left untouched; a bus that resolves to more
than one neutral terminal keeps only the first (the redundancy is reported as
`W.CONV.MULTIPLE_NEUTRALS` during validation). Buses that already carry an
explicit `neutral_terminal` are left as-is.
"""
function _materialize_terminal_roles!(net::Dict{String,Any})
    roles = _terminal_roles(net)
    # Only stamp when the case declares its convention: with no declaration the
    # neutral label is the `"n"` naming convention, which `_neutral_terminal`
    # already resolves per-bus, so stamping would only pollute bus dicts.
    roles.inferred && return net
    isempty(roles.neutral) && return net
    for (_, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        haskey(bus, "neutral_terminal") && continue
        names = get(bus, "terminal_names", nothing)
        names isa AbstractVector || continue
        nt = _neutral_terminal(names, roles.neutral)
        nt === nothing || (bus["neutral_terminal"] = nt)
    end
    net
end

"""
    _neutral_terminal(bus) -> Union{String,Nothing}
    _neutral_terminal(names[, neutral_labels]) -> Union{String,Nothing}

Identify the neutral terminal of a bus (or of a terminal-name/`terminal_map`
vector). For a bus, the explicit `neutral_terminal` field is checked first
(materialised from `terminal_conventions` at ingest). Otherwise, when a
`neutral_labels` set is supplied (typically `_neutral_labels(net)`), a terminal
whose label is in that set is the neutral; when it is omitted, the fallback
naming convention applies — a terminal named `"n"`/`"N"` (any case) is neutral.
Returns `nothing` if no neutral can be identified.

The OpenDSS numeric convention `["1","2","3","4"]` is resolved at import time by
`from_dss` (remapped to `["a","b","c","n"]`) rather than here.
"""
function _neutral_terminal(bus::Dict{String,Any})::Union{String,Nothing}
    nt = get(bus, "neutral_terminal", nothing)
    nt isa String && return nt
    _neutral_terminal(get(bus, "terminal_names", String[]))
end

function _neutral_terminal(names::AbstractVector)::Union{String,Nothing}
    for nm in names
        _is_convention_neutral(nm) && return string(nm)
    end
    nothing
end

function _neutral_terminal(names::AbstractVector, neutral_labels)::Union{String,Nothing}
    for nm in names
        string(nm) in neutral_labels && return string(nm)
    end
    nothing
end

"""
    _neutral_pos(terminal_map[, neutral_labels]) -> Union{Int,Nothing}

Return the 1-based position of the neutral terminal in `terminal_map`,
or `nothing` if none is identified. See [`_neutral_terminal`](@ref) for how
`neutral_labels` selects the resolution strategy.
"""
function _neutral_pos(terminal_map::AbstractVector)::Union{Int,Nothing}
    nt = _neutral_terminal(terminal_map)
    nt === nothing && return nothing
    findfirst(==(nt), string.(terminal_map))
end

function _neutral_pos(terminal_map::AbstractVector, neutral_labels)::Union{Int,Nothing}
    nt = _neutral_terminal(terminal_map, neutral_labels)
    nt === nothing && return nothing
    findfirst(==(nt), string.(terminal_map))
end

"""
    _phase_positions(terminal_map[, neutral_labels]) -> Vector{Int}

Return the 1-based positions of the non-neutral conductors in `terminal_map`.
"""
function _phase_positions(terminal_map::AbstractVector)::Vector{Int}
    np = _neutral_pos(terminal_map)
    [k for k in eachindex(terminal_map) if k != np]
end

function _phase_positions(terminal_map::AbstractVector, neutral_labels)::Vector{Int}
    np = _neutral_pos(terminal_map, neutral_labels)
    [k for k in eachindex(terminal_map) if k != np]
end

"""
    _infer_ibr_topology(terminal_map) -> String

Infer an IBR/STATCOM topology from its terminal map by NEUTRAL PRESENCE and
phase count (not terminal count alone), matching the `_IBR_ARITY` contract:

  * a neutral terminal present → `SINGLE_PHASE` (2 terminals) or `FOUR_LEG` (≥3);
  * no neutral                 → `THREE_LEG` (≥3 terminals, a delta / 3-wire
    connection) or `SINGLE_PHASE` (a phase-to-phase pair).

Counting terminals alone mislabels a 3-wire delta `[a,b,c]` as `FOUR_LEG`.
"""
function _infer_ibr_topology(terminal_map::AbstractVector)::String
    _infer_ibr_topology(terminal_map, _neutral_terminal(terminal_map))
end

function _infer_ibr_topology(terminal_map::AbstractVector, neutral_labels)::String
    _infer_ibr_topology(terminal_map, _neutral_terminal(terminal_map, neutral_labels))
end

function _infer_ibr_topology(terminal_map::AbstractVector,
                             neutral::Union{String,Nothing})::String
    n = length(terminal_map)
    if neutral !== nothing
        return n <= 2 ? "SINGLE_PHASE" : "FOUR_LEG"
    end
    n >= 3 ? "THREE_LEG" : "SINGLE_PHASE"
end

"""
    _ibr_phase_count(topology, terminal_map) -> (n_phase::Int, has_neutral::Bool)

Number of phase currents and whether a neutral conductor is present for an IBR,
given its `topology` and terminal map. Single source of truth mirrored by the
OPF stamp (`ext/BMOPFOpfExt/ibr.jl`) and integrity's per-conductor `i_max`
check: `THREE_LEG` carries one current per terminal with no neutral;
`SINGLE_PHASE` one phase current (with a return when ≥2 terminals); `FOUR_LEG`
one per non-neutral phase plus a neutral.
"""
function _ibr_phase_count(topology, terminal_map::AbstractVector)::Tuple{Int,Bool}
    n = length(terminal_map)
    topology == "THREE_LEG"    && return (n, false)
    topology == "SINGLE_PHASE" && return (1, n >= 2)
    return (max(n - 1, 0), true)   # FOUR_LEG (and unknown → default)
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
    _xfmr_winding_pairs(terminal_map, _neutral_pos(terminal_map))
end

function _xfmr_winding_pairs(terminal_map::AbstractVector,
                             neutral_labels)::Vector{Tuple{Int,Union{Int,Nothing}}}
    _xfmr_winding_pairs(terminal_map, _neutral_pos(terminal_map, neutral_labels))
end

function _xfmr_winding_pairs(terminal_map::AbstractVector,
                             np::Union{Int,Nothing})::Vector{Tuple{Int,Union{Int,Nothing}}}
    phases = [k for k in eachindex(terminal_map) if k != np]
    if np !== nothing
        return [(p, np) for p in phases]
    elseif length(terminal_map) == 2
        return [(1, 2)]
    else
        return [(p, nothing) for p in phases]
    end
end

"""
    _xfmr_turns_ratio(xfmr) -> Float64

Return N = v_nom_from / v_nom_to, defaulting to 1.0 if either field is missing
or v_nom_to is zero.
"""
function _xfmr_turns_ratio(xfmr::Dict{String,Any})::Float64
    vf = Float64(get(xfmr, "v_nom_from", 1.0))
    vt = Float64(get(xfmr, "v_nom_to",   1.0))
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

# ── Continuous tap (free-variable) support ─────────────────────────────────────
# A transformer's tap is OPTIMISABLE when bounds are present and strictly ordered
# (mirrors the implicit generator/IBR free-variable pattern). Ordinary transformers
# (single_phase, wye_delta, delta_wye) use a dimensionless multiplier `tap` on the
# nominal from-side ratio N0 = v_nom_from/v_nom_to; the regulator subtypes use their
# native `tap_ratio`. The OPF declares ONE variable per free tap equal to the
# EFFECTIVE from→to ratio coefficient the winding constraints multiply (N for the
# single_phase form, n_eff otherwise), so the constraints stay degree-2.

"Fixed dimensionless tap multiplier for an ordinary transformer (`tap`, default 1.0)."
_xfmr_tap_mult(xfmr::Dict{String,Any})::Float64 = Float64(get(xfmr, "tap", 1.0))

"""
    _xfmr_ratio_coeff_fn(subtype, N0) -> Function

Effective from→to ratio coefficient as a function of the dimensionless tap `t`
(multiplier on the nominal ratio `N0 = v_nom_from/v_nom_to`).
"""
function _xfmr_ratio_coeff_fn(subtype::AbstractString, N0::Float64)
    subtype == "delta_wye" && return t -> sqrt(3.0) * N0 * t   # Dy: n_eff = N·√3
    subtype == "wye_delta" && return t -> sqrt(3.0) / (N0 * t) # Yd: n_eff = √3/N
    return t -> N0 * t                                          # single_phase: N
end

"""
    _xfmr_ratio_coeff_bounds(subtype, xfmr) -> Union{Nothing,NTuple{3,Float64}}

If `xfmr`'s tap is a free variable, return `(lo, hi, start)` bounds on the EFFECTIVE
from→to ratio coefficient used by the OPF (N for `single_phase`, n_eff for
`delta_wye`/`wye_delta`/`single_phase_autotransformer`), else `nothing`. The maps are
monotone, so the coefficient bounds are the sorted images of the tap bounds. For
`open_delta_regulator` use `_odr_ratio_coeff_bounds` (per regulator).
"""
function _xfmr_ratio_coeff_bounds(subtype::AbstractString, xfmr::Dict{String,Any})
    if subtype in ("single_phase", "center_tap", "wye_delta", "delta_wye")
        (haskey(xfmr, "tap_min") && haskey(xfmr, "tap_max")) || return nothing
        tlo = Float64(xfmr["tap_min"]); thi = Float64(xfmr["tap_max"])
        tlo < thi || return nothing
        tstart = clamp(_xfmr_tap_mult(xfmr), tlo, thi)
        coeff  = _xfmr_ratio_coeff_fn(subtype, _xfmr_turns_ratio(xfmr))
        c1 = coeff(tlo); c2 = coeff(thi)
        return (min(c1, c2), max(c1, c2), coeff(tstart))
    elseif subtype == "single_phase_autotransformer"
        (haskey(xfmr, "tap_ratio_min") && haskey(xfmr, "tap_ratio_max")) || return nothing
        alo = Float64(xfmr["tap_ratio_min"]); ahi = Float64(xfmr["tap_ratio_max"])
        alo < ahi || return nothing
        rt = string(get(xfmr, "regulator_type", "B"))
        astart = clamp(Float64(get(xfmr, "tap_ratio", 1.0)), alo, ahi)
        c1 = _autotransformer_neff(alo, rt); c2 = _autotransformer_neff(ahi, rt)
        return (min(c1, c2), max(c1, c2), _autotransformer_neff(astart, rt))
    end
    return nothing
end

"""
    _odr_ratio_coeff_bounds(xfmr, k) -> Union{Nothing,NTuple{3,Float64}}

Per-regulator (`k` = 1 or 2) effective `n_eff` bounds `(lo, hi, start)` for an
open-delta regulator, or `nothing` when that regulator's tap is fixed.
"""
function _odr_ratio_coeff_bounds(xfmr::Dict{String,Any}, k::Int)
    mn = get(xfmr, "tap_ratio_min", nothing); mx = get(xfmr, "tap_ratio_max", nothing)
    (mn isa AbstractVector && mx isa AbstractVector &&
     length(mn) >= k && length(mx) >= k) || return nothing
    alo = Float64(mn[k]); ahi = Float64(mx[k]); alo < ahi || return nothing
    taps = get(xfmr, "tap_ratio", Float64[])
    a0 = (taps isa AbstractVector && length(taps) >= k) ? Float64(taps[k]) : 1.0
    rt = string(get(xfmr, "regulator_type", "B"))
    astart = clamp(a0, alo, ahi)
    c1 = _autotransformer_neff(alo, rt); c2 = _autotransformer_neff(ahi, rt)
    return (min(c1, c2), max(c1, c2), _autotransformer_neff(astart, rt))
end

"""
    _xfmr_tap_from_coeff(subtype, xfmr, coeff) -> Float64

Invert the solved effective ratio coefficient back to the user-facing dimensionless
tap (`tap` for ordinary transformers, `tap_ratio` for regulators) for reporting.
Scale-invariant: in per-unit `coeff = N0_pu·t`, so the recovered `t` is dimensionless.
"""
function _xfmr_tap_from_coeff(subtype::AbstractString, xfmr::Dict{String,Any}, coeff::Float64)
    if subtype in ("single_phase", "center_tap")
        N0 = _xfmr_turns_ratio(xfmr); return iszero(N0) ? coeff : coeff / N0
    elseif subtype == "delta_wye"
        N0 = _xfmr_turns_ratio(xfmr); return iszero(N0) ? coeff : coeff / (sqrt(3.0) * N0)
    elseif subtype == "wye_delta"
        N0 = _xfmr_turns_ratio(xfmr)
        return iszero(N0) || iszero(coeff) ? coeff : sqrt(3.0) / (N0 * coeff)
    elseif subtype in ("single_phase_autotransformer", "open_delta_regulator")
        rt = string(get(xfmr, "regulator_type", "B"))
        return uppercase(strip(rt)) == "A" ? coeff : (iszero(coeff) ? coeff : 1.0 / coeff)
    end
    return coeff
end

"""
    _line_has_inline_z(line) -> Bool

Whether a line carries its own ABSOLUTE impedance matrices (`R_series_i_j`
[Ω], `X_series_i_j` [Ω], optional `G_*`/`B_*` [S]) instead of a `linecode`
reference. Units are unambiguous by location: linecode matrices are per
metre and scale with `length`; inline line matrices are section totals and
are **never** scaled by length (`length`, if present, is descriptive only).
A line must have exactly one impedance source (`E.INT.LINE_IMPEDANCE_SOURCE`).
"""
_line_has_inline_z(line::Dict{String,Any})::Bool =
    haskey(line, "R_series_1_1") || haskey(line, "X_series_1_1")

# ---------------------------------------------------------------------------
# Submodule includes — order matters; IO first, then analysis, then report
# ---------------------------------------------------------------------------

include("config.jl")

include("io/migrate.jl")
include("io/parse_bmopf.jl")
include("io/write_bmopf.jl")
include("io/result_io.jl")
include("io/to_pmd.jl")
include("io/powerio_findings.jl")
include("io/from_dss.jl")
include("io/to_dss.jl")
include("io/project_solution.jl")
include("io/sideload_coordinates.jl")
include("io/nwinding.jl")
include("io/capacitor.jl")
include("io/to_ybus.jl")
include("io/ybus.jl")
include("io/ybus_linearized.jl")
include("io/ybus_augmented.jl")

include("lineconstants/wire.jl")
include("lineconstants/earth.jl")
include("lineconstants/series.jl")
include("lineconstants/shunt.jl")
include("lineconstants/kron.jl")
include("lineconstants/overhead.jl")
include("lineconstants/compile.jl")

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
include("validation/wire_geometry.jl")
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
include("report/render_json.jl")

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
  (`.json` → structured JSON via [`render_json`](@ref), `.md` → Markdown,
  anything else → plain text)

# Keyword arguments
- `color::Bool` — force-enable/disable ANSI colour for IO dest (default: auto)
- `verbose::Bool` — include INFO-level findings (default: `true`)
"""
function render(report::SummaryReport, dest::IO; color::Bool=get(dest, :color, false), verbose::Bool=true)
    render_terminal(report, dest; color=color, verbose=verbose)
end

function render(report::SummaryReport, path::AbstractString; verbose::Bool=true)
    if endswith(path, ".json")
        open(path, "w") do io
            render_json(report, io)
        end
    elseif endswith(path, ".md")
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
    results[:optimization] = _optimization_summary(result)
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

function _piecewise_linear_hinges(breakpoints::AbstractVector{<:Real},
                                   values::AbstractVector{<:Real})
    n = length(breakpoints)
    n == length(values) || throw(ArgumentError(
        "breakpoints and values must have equal length"))
    n >= 2 || throw(ArgumentError("need at least 2 breakpoints, got $n"))

    xs = Float64.(breakpoints)
    ys = Float64.(values)
    all(isfinite, xs) || throw(ArgumentError("breakpoints must be finite"))
    all(isfinite, ys) || throw(ArgumentError("values must be finite"))
    all(i -> xs[i + 1] > xs[i], 1:(n - 1)) || throw(ArgumentError(
        "breakpoints must be strictly increasing"))

    hinges = Tuple{Float64,Float64}[]
    for i in 1:(n - 1)
        slope = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
        iszero(slope) && continue
        push!(hinges, (slope, xs[i]))
        push!(hinges, (-slope, xs[i + 1]))
    end
    return (baseline=ys[1], hinges=hinges)
end

"""
    piecewise_linear_value(input, breakpoints, values; epsilon=nothing)

Evaluate the continuous piecewise-linear function through corresponding
`breakpoints` and `values`, clamped flat outside the breakpoint interval.
Breakpoints must be finite and strictly increasing and both vectors must have
the same length of at least two.

With the default `epsilon=nothing`, evaluation is exact and retains the PWL
kinks. Passing a finite `epsilon > 0` replaces every hinge with the smooth
softplus `epsilon * log1pexp(z / epsilon)`, matching
[`opf_piecewise_linear_expression`](@ref). `input`, `breakpoints`, and `epsilon`
must use the same units; `values` determine the output units.

This numeric method is suitable as an exact control-law oracle outside an
optimisation model and as a reference for quantifying smoothing error.
"""
function piecewise_linear_value(input::Real,
                                breakpoints::AbstractVector{<:Real},
                                values::AbstractVector{<:Real};
                                epsilon::Union{Nothing,Real}=nothing)
    u = Float64(input)
    isfinite(u) || throw(ArgumentError("input must be finite"))
    curve = _piecewise_linear_hinges(breakpoints, values)
    if isnothing(epsilon)
        return curve.baseline + sum(
            slope * max(0.0, u - knot) for (slope, knot) in curve.hinges;
            init=0.0)
    end

    eps = Float64(epsilon)
    isfinite(eps) && eps > 0 || throw(ArgumentError(
        "epsilon must be finite and positive, got $epsilon"))
    return curve.baseline + sum(
        slope * eps * log1pexp((u - knot) / eps)
        for (slope, knot) in curve.hinges; init=0.0)
end
export piecewise_linear_value

"""
    opf_piecewise_linear_expression(ctx, input, breakpoints, values;
                                    epsilon) -> expression

Build a smooth JuMP expression for the continuous PWL function through
`breakpoints` and `values`, clamped flat outside the breakpoint interval. The
method is implemented by the OPF extension and requires JuMP and Ipopt to be
loaded.

`input` may be a JuMP variable or scalar expression. All curve data are fixed,
finite real numbers; `breakpoints` must be strictly increasing. The finite,
positive `epsilon` is the absolute softplus width in the same working units as
`input` and `breakpoints`. `values` determine the expression's output units.

Operator registration is cached by `epsilon` in `ctx`, so any number of curves
in one staged OPF context can share the same analytic softplus operator. The
expression follows the context's `softplus` build mode: the numerically stable
registered operator by default, or the native JuMP expression selected with
`softplus=:builtin` for DiffOpt compatibility. Curve construction does not add
constraints or modify the staged OPF lifecycle.

Use [`opf_bases`](@ref) to convert physical breakpoints and values to model
working units before calling this function. Use [`piecewise_linear_value`](@ref)
for exact numeric evaluation or for the corresponding smooth numeric oracle.
"""
function opf_piecewise_linear_expression end
export opf_piecewise_linear_expression

"""
    solve_opf(net::Dict{String,Any}; optimizer=Ipopt.Optimizer, t_index::Int=1,
              per_unit::Bool=true, s_base::Float64=1e6, scaling_policy=nothing,
              volt_var_watt_eps::Float64=2e-3,
              softplus::Symbol=:user_defined, build_spec=OpfBuildSpec(),
              verbose::Bool=false, solver_options=(),
              model_hook!=nothing, solution_hook!=nothing) -> Dict{String,Any}

Solve the four-wire rectangular current-voltage (IVR-EN) optimal power flow
on a BMOPF network dict. Requires JuMP and Ipopt to be loaded in the calling
environment before calling this function.

When `per_unit=true` (the default) the model is built and solved in per-unit
(V_base propagated from the source bus through transformers; S_base = `s_base`
VA, default 1 MVA; a DC network is scaled against its fixed-voltage anchor).
All results are returned in SI units regardless. Per-unit conditioning is
particularly important for DC networks, whose converter ports couple voltage
and current bilinearly; pass `per_unit=false` only to reproduce a raw-SI solve.

For controlled nondimensionalisation experiments, pass [`OpfScaling`](@ref).
An explicit `scaling_policy` is authoritative over the legacy `per_unit` and
`s_base` keywords. `OpfScaling(:classic)` selects the legacy convention,
`OpfScaling(:si)` selects raw SI coordinates, and the custom form accepts
explicit per-bus voltage bases plus system-wide or zone-local power bases while
enforcing the dimensional identities assumed by the IVR equations. The
effective coordinate system is recorded by [`opf_diagnostic_schema`](@ref) and
`opf_research_provenance(ctx)`.

## Solver control and formulation extension

- `verbose=true` streams the solver log (by default the model is silenced).
- `solver_options` is an iterable of `name => value` pairs applied as raw
  solver attributes, e.g. `solver_options = ["max_iter" => 3000, "tol" => 1e-9]`
  for Ipopt. Applied after the problem's own defaults, so user options win.
- `build_spec` assigns typed native/custom device ownership and coefficient
  providers. See [`OpfBuildSpec`](@ref) and the differentiable-extensions guide.
- `softplus=:user_defined` uses the stable registered nonlinear operator.
  Pass `softplus=:builtin` explicitly for wrappers such as DiffOpt that reject
  `MOI.UserDefinedFunction`; the native expression has a narrower safe range.
- `model_hook!` is the formulation extension point: a function `hook!(ctx)`
  called after the standard model is built and **before** KCL is enforced and
  the model is solved. Use [`opf_model`](@ref), [`opf_network`](@ref),
  [`opf_bases`](@ref), semantic key constructors plus [`opf_object`](@ref), and
  [`add_terminal_injection!`](@ref). The concrete context fields are internal.

  **Units.** With `per_unit=true` (the default) the model — and therefore every
  native model variable is in per-unit, so any physical-unit literal in a hook
  must be scaled by the matching base. `opf_bases(ctx)` returns the raw
  per-unit metadata as a NamedTuple with `s_base` (a compatibility/reference
  value), per-bus `v_base`/`i_base`/`z_base`/`y_base` Dicts and the DC
  `v_dc_base`/`i_dc_base`/`z_dc_base`, or `nothing` in SI mode
  (`per_unit=false`). Under a zone-local or otherwise nonuniform policy,
  use `opf_coordinate_bases(ctx, bus).power` for a hook literal at a
  particular bus; this returns `1.0` in SI mode. A watt cap at `bus1`, for
  instance, becomes
  `expr <= P_watts / opf_coordinate_bases(ctx, "bus1").power`.

  Example — cap one generator's phase-a active power at 5 kW:

  ```julia
  result = solve_opf(net; model_hook! = ctx -> begin
      model = opf_model(ctx)
      vr = opf_object(ctx, opf_bus_voltage_key("bus1", "a"))
      vi = opf_object(ctx,
          opf_bus_voltage_key("bus1", "a"; component=:imag))
      crg = opf_object(ctx, opf_generator_current_key("g1", 1))
      cig = opf_object(ctx,
          opf_generator_current_key("g1", 1; component=:imag))
      sb = opf_coordinate_bases(ctx, "bus1").power
      JuMP.@constraint(model, vr*crg + vi*cig <= 5_000.0 / sb)
  end)
  ```

- `solution_hook!` is the companion post-solve extraction point: a function
  `hook!(ctx, result)` called after the solve and the engine's own result
  extraction, but **before** per-unit unwrapping. The model is still live, so a
  hook can read `JuMP.value` of the custom variables it declared in a
  `model_hook!` (capture them in a shared closure) and append its own keys to
  the `result` dict. Because it runs in the model's units (per-unit by default),
  the hook must scale its outputs to SI via the matching
  `opf_coordinate_bases(ctx, bus).power` (or another local coordinate base) so
  they sit alongside the engine's SI results; the standard per-unit keys are
  unwrapped automatically but custom keys are not.

  A hook device that wants to be counted in `profile_solution`'s network
  power-balance check writes its **net terminal power** (SI, generator sign:
  positive = into the network) to `result["custom_injection"] =
  Dict("p"=>…, "q"=>…)`. Without this, a correct solve with a custom device
  trips a spurious `W.SOL.POWER_BALANCE` because the balance can't see the
  device's injection.

  Example — extract a battery's dispatch (declared in `model_hook!` and captured
  in `bat`) and register it for power balance:

  ```julia
  bat = Dict{Symbol,Any}()   # shared between the two hooks
  result = solve_opf(net;
      model_hook! = ctx -> begin
          # … declare crb/cib, add P/Q constraints, stamp KCL … then:
          bat[:P] = P_expr; bat[:Q] = Q_expr        # JuMP expressions
      end,
      solution_hook! = (ctx, result) -> begin
          sb = opf_coordinate_bases(ctx, "bus1").power
          p_W  = JuMP.value(bat[:P]) * sb           # per-unit → SI watts
          q_var = JuMP.value(bat[:Q]) * sb
          result["battery"] = Dict("bat1" => Dict("p"=>p_W, "q"=>q_var))
          result["custom_injection"] = Dict("p"=>p_W, "q"=>q_var)
      end)
  ```

## Smart-IBR Volt-var / Volt-watt

An IBR whose `control_profile` declares a `volt_var` and/or `volt_watt`
sub-object follows a voltage-dependent droop: Volt-watt caps active power,
`P_k ≤ p_base · f^VW(|U_k|)`, and Volt-var pins reactive power to the curve,
`Q_k = q_base · f^VV(|U_k|)`. Each piecewise-linear characteristic is encoded as
a sum of shifted/scaled smooth-ReLU (softplus) terms so the model stays
differentiable for Ipopt; `volt_var_watt_eps` is the relative corner-smoothing
(smaller → sharper kinks, larger → smoother). Breakpoint voltages are SI volts
(phase-to-neutral) regardless of `per_unit`. Supported for SINGLE_PHASE and
FOUR_LEG IBRs; for THREE_LEG (delta) the droop is ignored (box bounds
retained) with a warning. Default characteristics for a region (e.g. AS/NZS
4777.2:2020 "Australia A" for Queensland) can be injected by `augment_case`
via the `[augment.smart_ibr]` config section.

Returns a results dict with keys:
- `"termination_status"` — JuMP termination status string
- `"objective"` — optimal default-objective cost rate (currency/hour); custom
  `model_hook!` objectives retain whatever units the caller defines
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
    solve_feasibility_opf(net::Dict{String,Any}; optimizer=nothing, t_index::Int=1,
                          softplus::Symbol=:user_defined,
                          build_spec=OpfBuildSpec())
        -> Dict{String,Any}

Feasibility-relaxed variant of [`solve_opf`](@ref). Adds elastic slack current
injections at every non-source bus terminal so that KCL can always be satisfied,
then minimises the L2² norm of those slacks.

The added variables can absorb KCL residuals at the terminals where they are
present, but they do not relax contradictory hard bounds or guarantee convergence
of the nonconvex NLP. For a converged solve, non-zero slacks identify where that
relaxed solution paid to violate KCL; they are diagnostic evidence rather than a
global infeasibility certificate. Use [`diagnose_infeasibility`](@ref) to
interpret the result.

Requires JuMP and Ipopt (same as `solve_opf`).
For cases with Volt-var/Volt-watt profiles, pass `softplus=:builtin` explicitly
when using a DiffOpt nonlinear wrapper; its current backend rejects the stable
default's user-defined nonlinear operator.

Additional result keys beyond `solve_opf`:
- `"objective"`                  — squared-slack metric in solver working
  coordinates (plus the transformer tie-break); use the SI slack fields below
  for physical interpretation
- `"slack_injections"`        — per-bus, per-terminal `cs_r`, `cs_i`, `cs_mag` (A)
- `"total_slack_magnitude_A"` — L2 norm of all slack injections (A)
- `"is_feasibility_opf"`      — always `true`, used by `diagnose_infeasibility`
"""
function solve_feasibility_opf end
export solve_feasibility_opf

"""
    solve_pf(net::Dict{String,Any}; optimizer=Ipopt.Optimizer, t_index::Int=1,
             per_unit::Bool=true, s_base::Float64=1e6, scaling_policy=nothing,
             softplus::Symbol=:user_defined,
             build_spec=OpfBuildSpec()) -> Dict{String,Any}

Determined four-wire rectangular current-voltage (IVR-EN) power flow on a BMOPF
network dict. Same device models as [`solve_opf`](@ref) but with **no operational
bounds and no objective**: fixed source voltages, constant-power injections, and
exact KCL fully determine the nodal state.

Device current/thermal limits and voltage bounds are intentionally ignored — the
power flow reports whatever results from the physics; use `solve_opf` or a
post-solve validation pass when limits must hold.

Generators must be **fixed setpoints** (`p_min == p_max` and `q_min == q_max`); a
non-degenerate range is rejected, since a power flow has no objective to choose a
dispatch within the range. IBRs under a `control_profile` are voltage-
dependent and remain determined.

Requires JuMP and Ipopt (same as `solve_opf`). The result dict matches
`solve_opf`'s structure plus `"is_power_flow" => true`.
For cases with Volt-var/Volt-watt profiles, pass `softplus=:builtin` explicitly
when using a DiffOpt nonlinear wrapper; its current backend rejects the stable
default's user-defined nonlinear operator.
"""
function solve_pf end
export solve_pf

"""
    OpfModelKey(kind, family, index=nothing)

Stable semantic identifier for an object in a staged OPF model. `kind` is
typically `:variable`, `:expression`, or `:constraint`; `family` identifies the
physical/model quantity (for example `:vr`, `:tap`, or a downstream package's
own symbol); and `index` identifies the component/terminal/phase.

Keys are intentionally independent of JuMP and extensible by downstream
packages. Use [`register_opf_object!`](@ref) and [`opf_object`](@ref) rather than
depending on the internal layout of `ctx.vars`.
"""
struct OpfModelKey
    kind::Symbol
    family::Symbol
    index
end

OpfModelKey(kind::Symbol, family::Symbol) = OpfModelKey(kind, family, nothing)

Base.:(==)(a::OpfModelKey, b::OpfModelKey) =
    a.kind == b.kind && a.family == b.family && a.index == b.index
Base.isequal(a::OpfModelKey, b::OpfModelKey) =
    isequal(a.kind, b.kind) && isequal(a.family, b.family) &&
    isequal(a.index, b.index)
Base.hash(key::OpfModelKey, h::UInt) =
    hash(key.index, hash(key.family, hash(key.kind, h)))

"""
    OpfSemanticBlock(id, kind, members, components, quantity, physical_unit;
                     set_contract=:none, model_to_canonical=I,
                     reference_physical_scale=nothing,
                     reference_scale_source=nothing, owner=:BMOPFTools,
                     metadata=Dict())

Authoritative declaration that registered OPF objects form one semantic
coordinate or residual block. `members` are ordered model coordinates;
`components` name the corresponding canonical outputs (for example
`[:real, :imag]` or `[:active, :reactive]`). `model_to_canonical` maps the
ordered model components into that canonical component basis before physical
unit scaling is applied.

`reference_physical_scale` is an optional positive device or operating scale
for nondimensionalisation experiments. It is not the model-to-SI coordinate
conversion and its provenance must be stated in `reference_scale_source`.
The declaration is metadata only: registering a block never changes the model.
"""
struct OpfSemanticBlock
    id::String
    kind::Symbol
    members::Vector{OpfModelKey}
    components::Vector{Symbol}
    quantity::Symbol
    physical_unit::Symbol
    set_contract::Symbol
    model_to_canonical::Matrix{Float64}
    reference_physical_scale::Union{Nothing,Float64}
    reference_scale_source::Union{Nothing,String}
    owner::Symbol
    metadata::Dict{String,Any}
end

function OpfSemanticBlock(
    id::AbstractString,
    kind::Symbol,
    members,
    components,
    quantity::Symbol,
    physical_unit::Symbol;
    set_contract::Symbol = :none,
    model_to_canonical = nothing,
    reference_physical_scale::Union{Nothing,Real} = nothing,
    reference_scale_source::Union{Nothing,AbstractString} = nothing,
    owner::Symbol = :BMOPFTools,
    metadata = Dict{String,Any}(),
)
    normalized_id = String(id)
    isempty(strip(normalized_id)) &&
        throw(ArgumentError("semantic-block id must not be empty"))
    kind in (:variable, :constraint) || throw(ArgumentError(
        "semantic-block kind must be :variable or :constraint",
    ))
    normalized_members = OpfModelKey[member for member in members]
    normalized_components = Symbol.(collect(components))
    dimension = length(normalized_members)
    dimension > 0 ||
        throw(ArgumentError("semantic block must contain at least one member"))
    length(normalized_components) == dimension || throw(DimensionMismatch(
        "semantic-block member and component lengths differ",
    ))
    length(unique(normalized_members)) == dimension ||
        throw(ArgumentError("semantic-block members must be unique"))
    length(unique(normalized_components)) == dimension ||
        throw(ArgumentError("semantic-block components must be unique"))
    all(member -> member.kind == kind, normalized_members) ||
        throw(ArgumentError("every semantic-block member must match block kind"))
    set_contract in (:none, :zero_equality, :scalar_bounds, :euclidean_ball) ||
        throw(ArgumentError(
            "unsupported semantic-block set contract; use :none, " *
            ":zero_equality, :scalar_bounds, or :euclidean_ball"))
    kind == :variable && set_contract != :none && throw(ArgumentError(
        "variable semantic blocks must use set_contract=:none",
    ))
    transform = isnothing(model_to_canonical) ?
        Matrix{Float64}(I, dimension, dimension) :
        Matrix{Float64}(model_to_canonical)
    size(transform) == (dimension, dimension) || throw(DimensionMismatch(
        "semantic-block canonical transform must be $dimension-by-$dimension",
    ))
    all(isfinite, transform) || throw(ArgumentError(
        "semantic-block canonical transform must be finite",
    ))
    inverse = try
        inv(transform)
    catch exception
        throw(ArgumentError(
            "semantic-block canonical transform must be nonsingular: " *
            sprint(showerror, exception),
        ))
    end
    all(isfinite, inverse) || throw(ArgumentError(
        "semantic-block canonical transform has a non-finite inverse",
    ))
    scale = isnothing(reference_physical_scale) ? nothing :
        Float64(reference_physical_scale)
    !isnothing(scale) && (!isfinite(scale) || scale <= 0) &&
        throw(ArgumentError(
            "reference_physical_scale must be finite and positive",
        ))
    source = isnothing(reference_scale_source) ? nothing :
        String(reference_scale_source)
    !isnothing(scale) && (isnothing(source) || isempty(strip(source))) &&
        throw(ArgumentError(
            "a reference physical scale requires nonempty provenance",
        ))
    return OpfSemanticBlock(
        normalized_id,
        kind,
        normalized_members,
        normalized_components,
        quantity,
        physical_unit,
        set_contract,
        transform,
        scale,
        source,
        owner,
        Dict{String,Any}(string(key) => value for (key, value) in metadata),
    )
end

function _opf_rectangular_family(component::Symbol, real_family::Symbol,
                                 imaginary_family::Symbol)
    component == :real && return real_family
    component == :imag && return imaginary_family
    throw(ArgumentError("component must be :real or :imag"))
end

function _opf_positive_position(position::Integer, label::AbstractString)
    position isa Bool && throw(ArgumentError(
        "$label must be a positive integer, not Bool"))
    position >= 1 || throw(ArgumentError("$label must be a positive integer"))
    return Int(position)
end

"""Return the native real/imaginary bus-terminal voltage key."""
function opf_bus_voltage_key(bus::AbstractString, terminal::AbstractString;
                             component::Symbol=:real)
    family = _opf_rectangular_family(component, :vr, :vi)
    return OpfModelKey(:variable, family, (String(bus), String(terminal)))
end

"""Return the native real/imaginary perfect-ground current key."""
function opf_ground_current_key(bus::AbstractString, terminal::AbstractString;
                                component::Symbol=:real)
    family = _opf_rectangular_family(component, :cr_gnd, :ci_gnd)
    return OpfModelKey(:variable, family, (String(bus), String(terminal)))
end

"""Return the native line-current key for a conductor and branch side."""
function opf_line_current_key(line::AbstractString, conductor::Integer;
                              side::Symbol=:from, component::Symbol=:real)
    side in (:from, :to) || throw(ArgumentError("side must be :from or :to"))
    families = side == :from ? (:cr_fr, :ci_fr) : (:cr_to, :ci_to)
    family = _opf_rectangular_family(component, families...)
    index = (String(line), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native switch-current key for a conductor."""
function opf_switch_current_key(switch_id::AbstractString, conductor::Integer;
                                component::Symbol=:real)
    family = _opf_rectangular_family(component, :cr_sw, :ci_sw)
    index = (String(switch_id), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native load-current key for a phase/conductor position."""
function opf_load_current_key(load::AbstractString, conductor::Integer;
                              component::Symbol=:real)
    family = _opf_rectangular_family(component, :crd, :cid)
    index = (String(load), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native generator-current key for a phase/conductor position."""
function opf_generator_current_key(generator::AbstractString,
                                   conductor::Integer;
                                   component::Symbol=:real)
    family = _opf_rectangular_family(component, :crg, :cig)
    index = (String(generator), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native voltage-source current key for a conductor position."""
function opf_voltage_source_current_key(source::AbstractString,
                                        conductor::Integer;
                                        component::Symbol=:real)
    family = _opf_rectangular_family(component, :cr_src, :ci_src)
    index = (String(source), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native two-winding transformer-current key."""
function opf_transformer_current_key(transformer::AbstractString, side::Symbol,
                                     conductor::Integer;
                                     component::Symbol=:real)
    side in (:from, :to) || throw(ArgumentError("side must be :from or :to"))
    family = _opf_rectangular_family(component, :cr_xf, :ci_xf)
    side_index = side == :from ? "fr" : "to"
    index = (String(transformer), side_index,
             _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native scalar transformer-tap key."""
opf_transformer_tap_key(transformer::AbstractString) =
    OpfModelKey(:variable, :tap, String(transformer))

"""Return the native per-regulator transformer-tap key."""
function opf_transformer_tap_key(transformer::AbstractString,
                                 regulator::Integer)
    index = (String(transformer),
             _opf_positive_position(regulator, "regulator"))
    return OpfModelKey(:variable, :tap, index)
end

"""Return the native n-winding transformer-current key."""
function opf_nwinding_current_key(transformer::AbstractString,
                                  winding::Integer, conductor::Integer;
                                  component::Symbol=:real)
    family = _opf_rectangular_family(component, :cr_nw, :ci_nw)
    index = (String(transformer),
             _opf_positive_position(winding, "winding"),
             _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native inverter/IBR current key for a phase position."""
function opf_ibr_current_key(ibr::AbstractString, conductor::Integer;
                             component::Symbol=:real)
    family = _opf_rectangular_family(component, :cri, :cii)
    index = (String(ibr), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, family, index)
end

"""Return the native active/reactive power auxiliary key for one IBR phase."""
function opf_ibr_power_key(ibr::AbstractString, phase::Integer;
                           component::Symbol=:active)
    family = component == :active ? :p_ibr :
             component == :reactive ? :q_ibr :
             throw(ArgumentError("component must be :active or :reactive"))
    return OpfModelKey(:variable, family,
                       (String(ibr), _opf_positive_position(phase, "phase")))
end

"""Return the native monitored-voltage-magnitude auxiliary key for one IBR phase.

`reference` may be `:pg`, `:pn`, or `:pp` for the per-phase monitored
magnitude, or the corresponding `:_averaged` form for the actual shared
controller input when phase magnitudes are averaged. The averaged key refers
to a registered expression rather than a per-phase voltage variable.
"""
function opf_ibr_voltage_magnitude_key(
    ibr::AbstractString,
    phase::Integer;
    reference::Symbol,
    controller::Symbol,
)
    reference in (:pg, :pn, :pp, :pg_averaged, :pn_averaged, :pp_averaged,
                  :single_pg, :single_diff) ||
        throw(ArgumentError("unsupported voltage-magnitude reference '$reference'"))
    kind = reference in (:pg_averaged, :pn_averaged, :pp_averaged) ?
           :expression : :variable
    return OpfModelKey(kind, :u_ibr,
                       (String(ibr), _opf_positive_position(phase, "phase"),
                        String(reference), String(controller)))
end

"""Return the native signed DC bus-terminal voltage key."""
opf_dc_voltage_key(bus::AbstractString, terminal::AbstractString) =
    OpfModelKey(:variable, :v_dc, (String(bus), String(terminal)))

"""Return the native perfect-ground DC-current key."""
opf_dc_ground_current_key(bus::AbstractString, terminal::AbstractString) =
    OpfModelKey(:variable, :idc_gnd, (String(bus), String(terminal)))

"""Return the native DC branch-current key for a conductor."""
function opf_dc_branch_current_key(branch::AbstractString, conductor::Integer)
    index = (String(branch), _opf_positive_position(conductor, "conductor"))
    return OpfModelKey(:variable, :idc_br, index)
end

"""Return the native AC/DC converter DC-port current key."""
opf_converter_dc_current_key(ibr::AbstractString) =
    OpfModelKey(:variable, :idc_conv, String(ibr))

"""Return the native constant-power DC-load current key."""
opf_dc_load_current_key(load::AbstractString) =
    OpfModelKey(:variable, :idc_load, String(load))

"""Return the native DC-source current key."""
opf_dc_source_current_key(source::AbstractString) =
    OpfModelKey(:variable, :idc_src, String(source))

"""Return the native dispatched DC-source power key."""
opf_dc_source_power_key(source::AbstractString) =
    OpfModelKey(:variable, :pdc_src, String(source))

"""
    OpfParameterScope(kind, id=nothing)

Research-facing scope attached to an [`OpfParameterBinding`](@ref). `kind` is
one of `:global`, `:snapshot`, or `:scenario`. `id` is deliberately untyped so
an extension can use its own stable time/scenario identifier without BMOPFTools
prescribing a multi-period data model.
"""
struct OpfParameterScope
    kind::Symbol
    id
    function OpfParameterScope(kind::Symbol, id=nothing)
        kind in (:global, :snapshot, :scenario) || throw(ArgumentError(
            "OPF parameter scope must be :global, :snapshot, or :scenario"))
        kind == :global && id !== nothing && throw(ArgumentError(
            "a global OPF parameter scope cannot have an id"))
        return new(kind, id)
    end
end

"""
    OpfParameterBinding

Immutable metadata for a caller-owned JuMP parameter linked to one or more
semantic OPF decision variables. The link convention is
`target = to_working_scale * parameter`; consequently a reverse derivative
with respect to the input parameter includes this scale by the ordinary chain
rule. `input_unit` and `working_unit` are descriptive symbols, not an implicit
unit-conversion system.

The vectors contain live JuMP constraint references and are defensively copied
by [`opf_parameter_binding`](@ref) and [`opf_parameter_bindings`](@ref).
"""
struct OpfParameterBinding
    key::OpfModelKey
    parameter
    targets::Vector{OpfModelKey}
    links::Vector{Any}
    scope::OpfParameterScope
    aliases::Vector{Symbol}
    input_unit::Symbol
    working_unit::Symbol
    to_working_scale::Float64
    owner::Symbol
end

"""
    OpfRegularization

Explicit downstream declaration that a registered semantic objective term is a
regularization. `weight` and `units` describe its reported coefficient;
`term_key` identifies the objective contribution, `targets` identify the
regularized model quantities, and `purpose` records why the mathematical
problem was changed. BMOPFTools records this declaration but does not infer it
from arbitrary JuMP expressions or verify that the term is included in the
current model objective.
"""
struct OpfRegularization
    name::Symbol
    method::Symbol
    weight::Float64
    units::Symbol
    term_key::OpfModelKey
    targets::Vector{OpfModelKey}
    purpose::String
    owner::Symbol
    metadata::Dict{String,Any}
end

"""
    AbstractOpfScalingPolicy

Typed description of the coordinate system used to build an OPF model. Scaling
policies change coordinates only; they must not change the physical problem.
"""
abstract type AbstractOpfScalingPolicy end

"""
    SIUnitsScaling()

Build the model in its input SI units. This is the typed equivalent of the
legacy keyword `per_unit=false`.
"""
struct SIUnitsScaling <: AbstractOpfScalingPolicy end

"""
    ClassicPerUnitScaling(s_base=1e6)

The historical BMOPFTools per-unit convention: one system power base, voltage
bases propagated from the source through the network, and dimensionally
consistent current, impedance, and admittance bases derived from them.
"""
struct ClassicPerUnitScaling <: AbstractOpfScalingPolicy
    s_base::Float64
    function ClassicPerUnitScaling(s_base::Real=1e6)
        value = Float64(s_base)
        isfinite(value) && value > 0 || throw(ArgumentError(
            "s_base must be finite and positive, got $s_base"))
        return new(value)
    end
end

"""
    ConsistentPerUnitScaling(; s_base, voltage_bases,
                               dc_voltage_base=nothing, name=:custom)

An explicit, physically consistent nondimensionalisation policy. A positive
voltage base must be supplied for every AC bus. Connected lines and switches
must share a voltage base and transformer-side bases must respect the declared
turns ratio; BMOPFTools validates these invariants before building a model.

Current, impedance, and admittance bases remain derived as `S/V`, `V^2/S`, and
`S/V^2`. This policy deliberately does not accept an independently chosen
current base: the present IVR equations assume those identities. A future
coordinate-transformation layer may relax that restriction by stamping the
required coefficients explicitly.
"""
struct ConsistentPerUnitScaling <: AbstractOpfScalingPolicy
    name::Symbol
    s_base::Float64
    voltage_bases::Dict{String,Float64}
    dc_voltage_base::Union{Nothing,Float64}
    function ConsistentPerUnitScaling(;
            s_base::Real,
            voltage_bases,
            dc_voltage_base::Union{Nothing,Real}=nothing,
            name::Symbol=:custom)
        sb = Float64(s_base)
        isfinite(sb) && sb > 0 || throw(ArgumentError(
            "s_base must be finite and positive, got $s_base"))
        isempty(String(name)) && throw(ArgumentError("scaling policy name cannot be empty"))
        vb = Dict{String,Float64}()
        for (bus, value) in voltage_bases
            base = Float64(value)
            isfinite(base) && base > 0 || throw(ArgumentError(
                "voltage base for bus $(repr(bus)) must be finite and positive, got $value"))
            vb[String(bus)] = base
        end
        dcb = dc_voltage_base === nothing ? nothing : Float64(dc_voltage_base)
        dcb === nothing || (isfinite(dcb) && dcb > 0) || throw(ArgumentError(
            "dc_voltage_base must be finite and positive, got $dc_voltage_base"))
        return new(name, sb, vb, dcb)
    end
end

"""
    ZonePerUnitScaling(; voltage_bases, power_bases,
                         dc_voltage_base=nothing, dc_power_base=nothing,
                         name=:zone_local)

Experimental coordinate policy with a voltage and power base for every AC bus.
Power bases must be constant inside each galvanically continuous zone; they may
change only across an isolating transformer. The corresponding current,
impedance, and admittance bases are derived locally as `S/V`, `V^2/S`, and
`S/V^2`.

Voltage bases must likewise be identical across directly shared conductors,
including `single_phase_autotransformer` common bushings and
`open_delta_regulator` straight-through phases. A dimensionless tap changes a
winding relation; it is not a coordinate boundary. Both regulator families are
qualified under this one-voltage-base, one-power-base invariant.

This policy changes coordinates, never the physical model. BMOPFTools validates
the complete network before constructing the working copy and rejects device
families whose cross-zone stamping has not yet been qualified. In particular,
the qualified implementation supports isolated `single_phase`, `center_tap`,
`wye_delta`, `delta_wye`, and `n_winding` transformers. Native lossless AC/DC
converters using `P`, `V`, or `droop` control are qualified with independent
AC-bus and DC power bases. Other isolating transformer subtypes and custom or
lossy converter builders remain unavailable until their covariance tests are
in place.
"""
struct ZonePerUnitScaling <: AbstractOpfScalingPolicy
    name::Symbol
    voltage_bases::Dict{String,Float64}
    power_bases::Dict{String,Float64}
    dc_voltage_base::Union{Nothing,Float64}
    dc_power_base::Union{Nothing,Float64}
    function ZonePerUnitScaling(;
            voltage_bases,
            power_bases,
            dc_voltage_base::Union{Nothing,Real}=nothing,
            dc_power_base::Union{Nothing,Real}=nothing,
            name::Symbol=:zone_local)
        isempty(String(name)) && throw(ArgumentError(
            "scaling policy name cannot be empty"))
        normalize_bases(values, label) = begin
            result = Dict{String,Float64}()
            for (bus, raw) in values
                value = Float64(raw)
                isfinite(value) && value > 0 || throw(ArgumentError(
                    "$label for bus $(repr(bus)) must be finite and positive, got $raw"))
                result[String(bus)] = value
            end
            result
        end
        vb = normalize_bases(voltage_bases, "voltage base")
        sb = normalize_bases(power_bases, "power base")
        dcv = dc_voltage_base === nothing ? nothing : Float64(dc_voltage_base)
        dcs = dc_power_base === nothing ? nothing : Float64(dc_power_base)
        dcv === nothing || (isfinite(dcv) && dcv > 0) || throw(ArgumentError(
            "dc_voltage_base must be finite and positive, got $dc_voltage_base"))
        dcs === nothing || (isfinite(dcs) && dcs > 0) || throw(ArgumentError(
            "dc_power_base must be finite and positive, got $dc_power_base"))
        return new(name, vb, sb, dcv, dcs)
    end
end

"""
    OpfScaling(mode=:custom; kwargs...)

Construct the coordinate-scaling specification accepted by the staged OPF
builders. This is the public scaling entry point; concrete implementation
policy types are deliberately private so their representation can evolve.

Supported forms are:

  * `OpfScaling(:si)` for raw SI coordinates;
  * `OpfScaling(:classic; power_base=1e6)` for the historical system-base
    per-unit convention; and
  * `OpfScaling(; voltage_bases, power_base=...)` or
    `OpfScaling(; voltage_bases, power_bases=...)` for explicit voltage bases
    with respectively a system-wide or galvanic-zone power base.

Current, impedance, and admittance bases are always derived from voltage and
power bases. Supplying both `power_base` and `power_bases` is rejected.
"""
function OpfScaling(
    mode::Symbol = :custom;
    name::Union{Nothing,Symbol} = nothing,
    power_base::Union{Nothing,Real} = nothing,
    voltage_bases = nothing,
    power_bases = nothing,
    dc_voltage_base::Union{Nothing,Real} = nothing,
    dc_power_base::Union{Nothing,Real} = nothing,
)
    mode in (:si, :classic, :custom) || throw(ArgumentError(
        "OPF scaling mode must be :si, :classic, or :custom, got :$mode",
    ))
    if mode == :si
        name === nothing || throw(ArgumentError(
            "OpfScaling(:si) does not accept a policy name",
        ))
        any(value -> !isnothing(value), (
            power_base, voltage_bases, power_bases,
            dc_voltage_base, dc_power_base,
        )) && throw(ArgumentError("OpfScaling(:si) does not accept base data"))
        return SIUnitsScaling()
    elseif mode == :classic
        name === nothing || throw(ArgumentError(
            "OpfScaling(:classic) does not accept a policy name",
        ))
        voltage_bases === nothing || throw(ArgumentError(
            "OpfScaling(:classic) propagates voltage bases from the network",
        ))
        power_bases === nothing || throw(ArgumentError(
            "OpfScaling(:classic) accepts one power_base, not power_bases",
        ))
        dc_voltage_base === nothing && dc_power_base === nothing ||
            throw(ArgumentError(
                "OpfScaling(:classic) derives AC and DC bases from power_base",
            ))
        return ClassicPerUnitScaling(something(power_base, 1.0e6))
    end

    voltage_bases === nothing && throw(ArgumentError(
        "custom OPF scaling requires voltage_bases",
    ))
    power_base === nothing || power_bases === nothing || throw(ArgumentError(
        "supply either power_base or power_bases, not both",
    ))
    if power_bases === nothing
        power_base === nothing && throw(ArgumentError(
            "custom OPF scaling requires power_base or power_bases",
        ))
        dc_power_base === nothing || throw(ArgumentError(
            "dc_power_base is only meaningful with per-zone power_bases",
        ))
        return ConsistentPerUnitScaling(
            name=something(name, :custom),
            s_base=power_base,
            voltage_bases=voltage_bases,
            dc_voltage_base=dc_voltage_base,
        )
    end
    return ZonePerUnitScaling(
        name=something(name, :zone_local),
        voltage_bases=voltage_bases,
        power_bases=power_bases,
        dc_voltage_base=dc_voltage_base,
        dc_power_base=dc_power_base,
    )
end

"""Return a serialisable, defensive description of an OPF scaling policy."""
function opf_scaling_policy_data(policy::AbstractOpfScalingPolicy)
    if policy isa SIUnitsScaling
        return Dict{String,Any}(
            "kind" => "si_units",
            "dimensionless" => false,
        )
    elseif policy isa ClassicPerUnitScaling
        return Dict{String,Any}(
            "kind" => "classic_per_unit",
            "dimensionless" => true,
            "s_base" => policy.s_base,
            "voltage_base_source" => "network_propagation",
            "derived_base_identities" => ["I=S/V", "Z=V^2/S", "Y=S/V^2"],
        )
    end
    if policy isa ConsistentPerUnitScaling
        custom = policy
        return Dict{String,Any}(
            "kind" => "consistent_per_unit",
            "name" => string(custom.name),
            "dimensionless" => true,
            "s_base" => custom.s_base,
            "voltage_bases" => Dict(custom.voltage_bases),
            "dc_voltage_base" => custom.dc_voltage_base,
            "derived_base_identities" => ["I=S/V", "Z=V^2/S", "Y=S/V^2"],
        )
    end
    zone = policy::ZonePerUnitScaling
    return Dict{String,Any}(
        "kind" => "zone_per_unit",
        "name" => string(zone.name),
        "dimensionless" => true,
        "voltage_bases" => Dict(zone.voltage_bases),
        "power_bases" => Dict(zone.power_bases),
        "dc_voltage_base" => zone.dc_voltage_base,
        "dc_power_base" => zone.dc_power_base,
        "derived_base_identities" => ["I(bus)=S(bus)/V(bus)",
                                      "Z(bus)=V(bus)^2/S(bus)",
                                      "Y(bus)=S(bus)/V(bus)^2"],
        "qualification" =>
            "experimental_single_phase_center_tap_yd_dy_and_n_winding_transformer_slice",
    )
end

"""
    OpfDiagnosticSchema

Immutable, versioned description of the numerical coordinate system and
semantic structure of one staged OPF model. The contained dictionaries and
semantic-block records are defensive copies. BMOPFTools reports what it built;
diagnostic interpretation remains the responsibility of downstream tools.
"""
struct OpfDiagnosticSchema
    schema_version::VersionNumber
    scaling::Dict{String,Any}
    coordinate_bases::Dict{String,Any}
    semantic_blocks::Vector{OpfSemanticBlock}
    initialization::Dict{String,Any}
    transformer_scaling::Dict{String,Any}
    acdc_scaling::Dict{String,Any}
    capabilities::Dict{String,Any}
end

"""
    OpfBuildManifest

Provenance for a staged OPF construction. `problem` identifies the recipe,
`formulation` the network formulation, `per_unit` and `s_base` record the
working-unit choice, `stages` records completed construction stages in order,
and `component_owners` records which package owns each stamped device family.

[`opf_build_manifest`](@ref) returns a defensive snapshot: mutating the returned
vector or dictionary does not alter the context's internal construction record.
"""
struct OpfBuildManifest
    problem::Symbol
    formulation::Symbol
    per_unit::Bool
    s_base::Float64
    stages::Vector{Symbol}
    component_owners::Dict{Any,Symbol}
end

"""
    OpfDeviceBuilder(owner, build!)

A downstream device-formulation callback and its provenance owner. `owner` is a
stable package/research-code symbol. BMOPFTools calls `build!(ctx, ids)`, where
`ids` is the deterministically ordered vector of component identifiers assigned
to this builder. The callback must use public context, registry, and KCL helpers.
"""
struct OpfDeviceBuilder
    owner::Symbol
    build!::Function
end

"""
    OpfCoefficientKey(category, family, component, field, index=nothing)

Stable identifier for a non-structural coefficient consumed while a device
builder stamps equations. `category` is normally `:load`, `:availability`,
`:setpoint`, `:cost`, `:limit`, `:controller`, or `:physics`; downstream
packages may introduce additional semantic categories. Values returned for a
key are in the model's working units.
"""
struct OpfCoefficientKey
    category::Symbol
    family::Symbol
    component::String
    field::Symbol
    index
    function OpfCoefficientKey(category::Symbol, family::Symbol,
                               component::AbstractString, field::Symbol,
                               index=nothing)
        category == :structural && throw(ArgumentError(
            "structural data cannot be an OPF coefficient; rebuild the model"))
        return new(category, family, String(component), field, index)
    end
end

"""
    OpfCoefficientProvider(owner, provide)

Typed coefficient callback with package provenance. A custom device builder
calls [`opf_coefficient`](@ref) with a semantic key and native/default value;
when registered, `provide(ctx, key, default)` returns the number, JuMP
parameter, or scalar expression to stamp instead. Providers must return values
in model working units.
"""
struct OpfCoefficientProvider
    owner::Symbol
    provide::Function
end

"""
    OpfDifferentiabilityAnnotation

Explicit audit declaration for a differentiability hazard that cannot be
reliably inferred from a completed JuMP graph. `kind` is one of
`:nonsmooth_operator`, `:dynamic_branch`, or
`:unsupported_parameter_location`; `key` optionally identifies the affected
semantic object or coefficient. A blocking annotation makes
[`opf_differentiability_report`](@ref) return `ready=false`. Nonblocking
annotations remain visible as qualifications and in research provenance.
"""
struct OpfDifferentiabilityAnnotation
    name::Symbol
    kind::Symbol
    description::String
    owner::Symbol
    key::Union{Nothing,OpfModelKey,OpfCoefficientKey}
    blocking::Bool
    metadata::Dict{String,Any}
end

"""
    OpfKKTDiagnostic

Result recorded by [`opf_checked_kkt_factorization`](@ref). `pivot_ratio` is a
global-scale-invariant LU pivot proxy, not a condition-number certificate. A
`:rejected` status means differentiation was stopped before a regularized or
zero sensitivity could be mistaken for a valid implicit derivative.
"""
struct OpfKKTDiagnostic
    status::Symbol
    dimension::Int
    pivot_ratio::Union{Nothing,Float64}
    tolerance::Float64
    message::String
end

"""Error thrown when the checked KKT factorization rejects a derivative."""
struct OpfDifferentiationError <: Exception
    message::String
end

Base.showerror(io::IO, error::OpfDifferentiationError) =
    print(io, error.message)

"""
    OpfDifferentiabilityReport

Conservative diagnostic snapshot for a staged OPF model. `ready` requires
finalized construction, a successful solve, no discrete variables or unused
providers, and no detected near-active, weakly-active, violated, or rejected-KKT
conditions or blocking differentiability annotations. The three annotation
vectors disclose extension-declared nonsmooth operators, parameter-dependent
construction branches, and unsupported parameter locations. Active-set fields
use caller-configurable numerical tolerances. This remains a diagnostic rather
than a proof of LICQ, second-order sufficiency, or global solution-branch
stability.
"""
struct OpfDifferentiabilityReport
    ready::Bool
    lifecycle::Symbol
    termination_status::String
    parameter_keys::Vector{OpfModelKey}
    coefficient_keys::Vector{OpfCoefficientKey}
    unused_coefficient_keys::Vector{OpfCoefficientKey}
    discrete_variables::Vector{String}
    inequality_constraints::Int
    active_constraints::Vector{String}
    near_active_constraints::Vector{String}
    weakly_active_constraints::Vector{String}
    violated_constraints::Vector{String}
    nonsmooth_operators::Vector{OpfDifferentiabilityAnnotation}
    dynamic_branches::Vector{OpfDifferentiabilityAnnotation}
    unsupported_parameter_locations::Vector{OpfDifferentiabilityAnnotation}
    minimum_inactive_slack::Union{Nothing,Float64}
    kkt_diagnostic::Union{Nothing,OpfKKTDiagnostic}
    qualifications::Vector{String}
end

"""
    OpfBuildSpec(; family_builders, component_builders, coefficient_providers)

Typed ownership specification for staged device construction. A
`family_builders` entry replaces the native formulation for the complete family.
A `component_builders[(family, id)]` entry replaces one component while leaving
unassigned components native. Mixed per-component ownership is currently
supported for flat device collections such as `:ibr`; unsupported combinations
are rejected before the device-physics stage mutates the model. In particular,
`:line`, `:transformer`, and `:dc_network` family replacement is rejected until
their branch-result or DC-KCL ledgers have public extension seams;
per-component `:line` replacement is rejected for the same reason.
"""
struct OpfBuildSpec
    family_builders::Dict{Symbol,OpfDeviceBuilder}
    component_builders::Dict{Tuple{Symbol,String},OpfDeviceBuilder}
    coefficient_providers::Dict{OpfCoefficientKey,OpfCoefficientProvider}
    function OpfBuildSpec(
            family_builders::Dict{Symbol,OpfDeviceBuilder},
            component_builders::Dict{Tuple{Symbol,String},OpfDeviceBuilder},
            coefficient_providers::Dict{OpfCoefficientKey,OpfCoefficientProvider})
        overlap = intersect(Set(keys(family_builders)),
                            Set(family for (family, _) in keys(component_builders)))
        isempty(overlap) || throw(ArgumentError(
            "a device family cannot have both a family builder and component " *
            "builders: $(sort!(collect(overlap)))"))
        return new(family_builders, component_builders, coefficient_providers)
    end
end

function OpfBuildSpec(; family_builders=Dict(), component_builders=Dict(),
                      coefficient_providers=Dict())
    families = Dict{Symbol,OpfDeviceBuilder}(family_builders)
    components = Dict{Tuple{Symbol,String},OpfDeviceBuilder}(
        (Symbol(family), String(id)) => builder
        for ((family, id), builder) in component_builders)
    providers = Dict{OpfCoefficientKey,OpfCoefficientProvider}(
        coefficient_providers)
    return OpfBuildSpec(families, components, providers)
end

"""
    opf_model(ctx)
    opf_network(ctx)
    opf_bases(ctx)
    opf_coordinate_bases(ctx, location; domain=:ac)
    opf_diagnostic_schema(ctx; voltage_bases, power_bases)
    opf_lifecycle(ctx)

Stable accessors for a context returned by [`build_opf_model`](@ref). They
provide the live JuMP model, prepared working network, raw per-unit metadata,
public coordinate bases, versioned diagnostic evidence, and construction
lifecycle state. Prefer the latter two interfaces for cross-package tooling.
"""
function opf_model end

"""Return the prepared working network owned by a staged OPF context."""
function opf_network end

"""Return per-unit base metadata, or `nothing` for an SI staged model.

For zone-local policies, `s_base` is a compatibility/reference value rather
than a universal local power base. Use [`opf_coordinate_bases`](@ref) for
bus-local hook literals and residual interpretation.
"""
function opf_bases end

"""
    opf_coordinate_bases(ctx, location; domain=:ac)

Return the physical coordinate bases at one AC or DC bus. AC records contain
`voltage`, `current`, `power`, `impedance`, and `admittance`; DC records contain
`voltage`, `current`, `power`, and `impedance`. SI-coordinate models return
unity bases.
"""
function opf_coordinate_bases end

"""
Return the working-coordinate bases for one AC bus as a named tuple with
`voltage`, `current`, `power`, `impedance`, and `admittance` fields. SI contexts
return unity bases. This is the stable scaling seam for model hooks.
"""
function opf_ac_coordinate_bases end

"""
Return the working-coordinate bases for one DC bus as a named tuple with
`voltage`, `current`, `power`, and `impedance` fields. SI contexts return unity
bases. The DC network currently uses one common voltage and power coordinate.
"""
function opf_dc_coordinate_bases end

"""Return the typed coordinate-scaling policy owned by a staged OPF context."""
function opf_scaling_policy end

"""Return defensive, serializable evidence about the generated OPF start."""
function opf_initialization_data end

"""
Return a serializable, non-mutating transformer scaling contract.

Optional physical `voltage_bases` and `power_bases` are keyed by bus and
describe a proposed coordinate system. The report validates that power bases
are constant inside galvanically continuous zones, that directly shared
regulator conductors retain one voltage base, and exposes the exact
voltage/current/power conversion ratios required at every transformer winding
interface. It does not apply the proposed scaling to the model.
"""
function opf_transformer_scaling_contract_data end

"""Return non-mutating evidence for every native AC/DC converter base crossing."""
function opf_acdc_scaling_contract_data end

"""
    opf_diagnostic_schema(ctx; voltage_bases=nothing, power_bases=nothing)

Return a defensive, versioned description of a staged model's scaling,
semantic blocks, initialization provenance, and qualified coordinate
interfaces. Optional proposed AC bases affect only the transformer-interface
audit; this function never modifies the model. Native semantic blocks are
materialised lazily after KCL finalisation; inspect `capabilities` for
`semantic_blocks_available` and `semantic_blocks_registered` before relying on
their completeness. Bind the returned schema once when several fields are
needed; each call rebuilds its defensive evidence dictionaries.
"""
function opf_diagnostic_schema end

"""Return the declared neutral terminal labels for one staged OPF context."""
function opf_neutral_labels end

"""Return the staged OPF construction lifecycle (`:building` or `:kcl_finalized`)."""
function opf_lifecycle end

"""Return the construction provenance for a staged OPF context."""
function opf_build_manifest end

"""Return a defensive copy of the typed build specification owned by a context."""
function opf_build_spec end

"""Return whether construction stage `stage` has completed for this context."""
function opf_stage_completed end

"""
    initialize_opf_model(net; kwargs...) -> ctx

Prepare one OPF snapshot, create its native variables, and return a context
without adding start values, operational limits, device equations, an objective,
or KCL. This is the low-level entry point for composing the public construction
stages. [`build_opf_model`](@ref) remains the standard all-stage recipe.
"""
function initialize_opf_model end

"""Apply the standard IVR-EN voltage start-value stage."""
function set_opf_start_values! end

"""Add the standard OPF voltage and bus operational-limit stage."""
function add_opf_operational_limits! end

"""Add build-spec-selected native/custom device physics and terminal currents."""
function add_opf_device_constraints! end

"""Set the standard generation-cost objective on a staged OPF model."""
function set_opf_objective! end

"""
    register_opf_result_extractor!(ctx, owner, extract!; replace=false)

Register a deterministic post-solve callback `extract!(ctx, result)`. It runs
before a caller-supplied `solution_hook!` and before native per-unit results are
unwrapped. The callback must place physical-unit downstream outputs in `result`.
Duplicate owners are rejected unless `replace=true`.
"""
function register_opf_result_extractor! end

"""
    register_opf_object!(ctx, key::OpfModelKey, object; replace=false)
    opf_object(ctx, key::OpfModelKey)
    opf_object_keys(ctx; kind=nothing)

Register and retrieve stable semantic references to JuMP variables,
expressions, constraints, or downstream objects. Duplicate keys are rejected
unless `replace=true`. Native JuMP variables are registered automatically using
their existing variable-family symbol and raw index.
"""
function register_opf_object! end

"""
    register_opf_constraint!(ctx, family, index, constraint; replace=false)

Convenience wrapper for model hooks and device extensions. Registers a JuMP
constraint under `OpfModelKey(:constraint, family, index)` while preserving the
same collision and model-ownership checks as `register_opf_object!`.
"""
function register_opf_constraint! end

"""
    register_opf_semantic_block!(ctx, block; replace=false)

Register a non-mutating semantic coordinate/residual block whose members are
already present in the public OPF object registry. A model object may belong to
at most one registered block of its kind. Duplicate ids and overlapping members
are rejected unless replacing the same block id explicitly. Register custom
blocks after `enforce_kcl!` when possible: post-KCL registration materializes
native blocks and reports conflicts at the registration call. If an overlapping
custom block is registered before KCL, native materialization can fail later
when a schema or provenance report is requested; the context must then be
rebuilt because there is no unregister operation.
"""
function register_opf_semantic_block! end

"""
    opf_semantic_blocks(ctx; kind=nothing)

Return defensive copies of registered semantic blocks in deterministic id
order. `kind` may be `:variable`, `:constraint`, or `nothing`.
"""
function opf_semantic_blocks end

"""Retrieve a JuMP/downstream object registered under an [`OpfModelKey`](@ref)."""
function opf_object end

"""List registered [`OpfModelKey`](@ref)s, optionally filtered by `kind`."""
function opf_object_keys end

"""
    register_opf_objective_term!(ctx, key::OpfModelKey, term; replace=false)

Register a scalar objective contribution under a stable semantic key. `key`
must have `kind == :objective`; `term` may be a real constant or a scalar JuMP
variable/expression belonging to the context model. Registration identifies a
contribution but does not change the model's objective.
"""
function register_opf_objective_term! end

"""
    opf_primal(ctx, key::OpfModelKey; result=1)

Return the solved value of a registered variable, parameter, expression, or
objective term. Constraint keys are deliberately rejected; use
[`opf_constraint_value`](@ref) for the function value of a constraint.
"""
function opf_primal end

"""
    opf_constraint_value(ctx, key::OpfModelKey; result=1)

Return the solved function value on the left-hand side of a registered
constraint. This is not a residual: interpret it together with the constraint's
JuMP set, or use [`opf_constraint_slack`](@ref) for scalar inequalities.
"""
function opf_constraint_value end

"""
    opf_constraint_slack(ctx, key::OpfModelKey; result=1)

Return signed slack for a registered scalar `LessThan`, `GreaterThan`, or
`Interval` constraint. Positive values are feasible, zero is active, and
negative values indicate violation. Returns `nothing` for equality and
non-scalar/conic sets.
"""
function opf_constraint_slack end

"""
    opf_dual(ctx, key::OpfModelKey; result=1)

Return the solver dual of a registered constraint, preserving JuMP/MOI's sign
convention and scalar or vector shape. No economic sign reinterpretation or
unit conversion is applied.
"""
function opf_dual end

"""Return the solved value of the model's current objective."""
function opf_objective_value end

"""
    OpfObjectiveTerm(name, expr; weight=1.0, units=:dimensionless, purpose="")

One named, weighted contribution to a composed OPF objective.

`expr` must be in the PHYSICAL unit named by `units` — watts, volts, V², or
currency/hour — not in the model's working (per-unit) coordinates. That is what
makes a composed objective mean the same thing in `per_unit=true` and
`per_unit=false`: the term constructors ([`opf_loss_term`](@ref),
[`opf_sequence_term`](@ref), [`opf_generation_cost_term`](@ref)) convert for you
via [`opf_physical_scale`](@ref), and a hand-built term should do the same.

`weight` is then in objective-units per physical-unit, so a weight tuned once
stays correct across unit modes and under a future nondimensionalisation.

`units` is recorded rather than checked: it reaches the regularization
declaration and [`opf_research_hashes`](@ref), so what was combined — and in
what units — is auditable after the fact.

`valid_sense` records whether the term's expression means what it says under
either optimisation direction (`:any`) or only when pushed DOWN (`:min`). An
epigraph reduction such as `norm=:max` is `:min`: its variable is bounded from
below by the targets and from above by nothing, so it equals the maximum only
while it is being minimised with a non-negative weight. Maximising it, or giving
it a negative weight, is unbounded rather than wrong-by-a-little.
[`set_opf_objective!`](@ref) rejects those combinations instead of handing the
solver an unbounded problem.
"""
struct OpfObjectiveTerm
    name::Symbol
    expr
    weight::Float64
    units::Symbol
    purpose::String
    valid_sense::Symbol
end

function OpfObjectiveTerm(name::Symbol, expr; weight::Real=1.0,
                          units::Symbol=:dimensionless,
                          purpose::AbstractString="",
                          valid_sense::Symbol=:any)
    isfinite(Float64(weight)) || throw(ArgumentError(
        "objective term '$name': weight must be finite, got $weight"))
    valid_sense in (:any, :min) || throw(ArgumentError(
        "objective term '$name': valid_sense must be :any or :min, got " *
        "$valid_sense"))
    return OpfObjectiveTerm(name, expr, Float64(weight), units, String(purpose),
                            valid_sense)
end
export OpfObjectiveTerm

"""
    opf_physical_scale(ctx, unit; bus=nothing) -> Float64

Physical value of one working unit of `unit` — the factor converting an
expression in the model's working coordinates into SI. Returns `1.0` throughout
when the model was built in SI, so a term written against it needs no branch.

`unit` is `:W`, `:var`, `:VA`, `:V`, `:V2`, `:A`, `:A2`, or `:dimensionless`.
Voltage and current bases are PER BUS, so `bus` is required for those and
omitting it throws — a system-wide voltage scale would be wrong on any network
with more than one voltage level.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_physical_scale end
export opf_physical_scale

"""
    opf_reduce_norm(ctx, pairs; norm=:squared, scale=1.0, eps_rel=1e-3, name="")

Reduce complex quantities `pairs` (a vector of `(re, im)` expression pairs) to
one scalar, by `:squared` (L2), `:magnitude` (group-lasso, via
[`smooth_norm`](@ref)) or `:max` (L∞ through a convex-quadratic epigraph, minimisation only).

The choice changes the answer, not just the arithmetic: `:squared` improves
every target a little, `:magnitude` drives a few to zero, `:max` protects the
worst one. `:squared` and `:max` return the SQUARE of the input unit;
`:magnitude` returns the input unit.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_reduce_norm end
export opf_reduce_norm

"""
    opf_loss_term(ctx; blocks, weight=1.0, name=:losses)
    opf_sequence_term(ctx, buses; component=:negative, norm=:squared, weight=1.0)
    opf_generation_cost_term(ctx; weight=1.0)

Ready-made [`OpfObjectiveTerm`](@ref)s, in physical units (W, V²/V,
currency/hour respectively), for [`set_opf_objective!`](@ref).

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_loss_term end
export opf_loss_term

@doc (@doc opf_loss_term)
function opf_sequence_term end
export opf_sequence_term

@doc (@doc opf_loss_term)
function opf_generation_cost_term end
export opf_generation_cost_term

"""
    opf_branch_currents(ctx, block, id; side=:from) -> Vector{(terminal, re, im)}
    opf_neutral_current(ctx, block, id; side=:from) -> (re, im)
    opf_sequence_current(ctx, block, id; side=:from, component=:zero) -> (re, im)

Conductor currents at one end of a two-port element, in the model's working
units. The sign is the current flowing INTO the element (out of the bus) — the
conductor current, not the ledger's "into bus" convention.

`opf_neutral_current` is the current in the neutral terminal: the quantity that
physically heats a neutral conductor, and usually what a 4-wire unbalance study
wants to reduce. For a 4-wire element with no parallel earth path it equals
`−3·I₀`, so it and a zero-sequence penalty are the same objective up to a
factor of three — but this one is in amps of real conductor current. It throws
on a three-wire element rather than returning a zero that would silently make
the penalty vanish.

`opf_sequence_current` uses the same Fortescue convention as
[`opf_sequence_voltage`](@ref) and requires exactly three phase terminals.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_branch_currents end
export opf_branch_currents

@doc (@doc opf_branch_currents)
function opf_neutral_current end
export opf_neutral_current

@doc (@doc opf_branch_currents)
function opf_sequence_current end
export opf_sequence_current

"""
    opf_current_term(ctx, elements; quantity=:neutral, component=:zero,
                     norm=:squared, weight=1.0)

An [`OpfObjectiveTerm`](@ref) penalising branch currents over `elements`, each
`(block, id)` or `(block, id, side)`. `quantity` is `:neutral` or `:sequence`.

Converted to amps before reduction, so elements at different voltage levels are
weighted on one physical footing and the weight is unit-mode independent.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_current_term end
export opf_current_term

"""
    opf_report_sequence_voltage(ctx, bus; component=:negative) -> Float64
    opf_report_vuf(ctx, bus; percent=true) -> Float64
    opf_report_current(ctx, block, id; side=:from, quantity=:neutral) -> Float64

Post-solve reporting for the objective building blocks: solved magnitudes in
PHYSICAL units (volts, percent, amps) in either unit mode. Call after
`JuMP.optimize!`.

`opf_report_vuf` is the counterpart to [`opf_vuf_term`](@ref), which minimises
the SQUARED ratio — this returns the unsquared, directly comparable percentage.
Reading a squared-VUF objective value as if it were a VUF is the mistake these
helpers exist to prevent.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_report_sequence_voltage end
export opf_report_sequence_voltage

@doc (@doc opf_report_sequence_voltage)
function opf_report_vuf end
export opf_report_vuf

@doc (@doc opf_report_sequence_voltage)
function opf_report_current end
export opf_report_current

"""
    opf_control_effort_term(ctx, devices; reference=nothing, norm=:magnitude,
                            weight=1.0)

An [`OpfObjectiveTerm`](@ref) penalising how far dispatchable devices move from
a reference operating point, as injected-current deviation in amps. `devices` is
a collection of `(block, id)` with `block` `"ibr"` or `"generator"`.

Current rather than P/Q deliberately: injected current is LINEAR in the decision
variables, so the penalty is a norm of affine expressions.

With the default `norm=:magnitude` each device contributes ONE grouped norm over
all its phases, making the penalty a group-lasso over devices: it drives whole
devices to their reference rather than nudging every device slightly. That is
the difference between "re-dispatch these two units" and "re-dispatch all forty
by 3% each", which `:squared` cannot express.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_control_effort_term end
export opf_control_effort_term

"""
    opf_vuf_term(ctx, buses; weight=1.0, percent=true)

An [`OpfObjectiveTerm`](@ref) penalising the SQUARED voltage unbalance factor,
`Σ (|V2|/|V1|)^2`, in percent-squared by default (EN 50160 §3.5 and
IEC 61000-2-2 state their limit as 2%, i.e. 4.0 here).

Squared deliberately. VUF looks like the one objective that must contain a
square root, and building it from [`smooth_norm`](@ref) is actively wrong: the
shift subtracts `eps` from numerator and denominator alike, and an `eps` sized
to condition a norm heading to zero is comparable to the numerator itself — a
true `|V2|` of 0.6 V against `eps = 0.26 V` mis-states the ratio by over 40%.
The squared ratio needs no `eps`, is exact and smooth, and is strictly monotone
in VUF so it orders solutions identically. Take `sqrt` post-solve.

The voltage base cancels in the ratio, so the term is identical in per-unit and
SI by construction.

!!! warning "Requires `vpos_min` on every listed bus"
    A ratio is well posed only while its denominator is bounded away from zero,
    and `|V1|` is decision-dependent. Every listed bus must declare `vpos_min`,
    which `bus.jl` enforces as an actual constraint; this throws otherwise
    rather than handing the solver a term it can drive to `0/0`.

    Prefer [`opf_sequence_term`](@ref) unless you specifically need the ratio:
    with `|V1|` near nominal the two order solutions almost identically, and the
    plain magnitude is exact, convex, cheaper, and has no denominator to guard.

Implemented in the `BMOPFOpfExt` extension.
"""
function opf_vuf_term end
export opf_vuf_term

"""
    opf_element_loss(ctx, block, id) -> JuMP expression
    opf_total_loss(ctx; blocks=("line","transformer","switch")) -> JuMP expression

Active-power loss of one two-port element, or of the whole network, as a JuMP
expression in the model's WORKING units (per-unit when `per_unit=true`).

Built from the same per-device terminal-injection ledger the post-solve result
uses, so these expressions and `result["losses"]["p_loss"]` are the same
quantity: an objective built on one cannot silently disagree with the other.

`S_loss = Σ V · conj(I_into_element)` is BILINEAR in voltage and current, hence
an exact smooth quadratic. A loss objective needs no smoothing and no magnitude
— [`smooth_norm`](@ref) has no business here. (Semiconductor CONDUCTION loss is
a different quantity: it is linear in `|I|` and does need the norm, but that is
a device model rather than a network loss.)

!!! note "Losses are not generation cost"
    Minimising loss is not minimising [`generation_cost`](@ref). With
    heterogeneous generation prices the two disagree: least-loss dispatch will
    source from an expensive nearby unit rather than transport cheap distant
    power. Combine them deliberately with explicit weights.

Implemented in the `BMOPFOpfExt` extension (requires JuMP and Ipopt loaded).
"""
function opf_element_loss end
export opf_element_loss

@doc (@doc opf_element_loss)
function opf_total_loss end
export opf_total_loss

"""
    opf_sequence_voltage(ctx, bus; component=:negative) -> (re, im)

Symmetrical-component voltage at `bus` as a pair of affine JuMP expressions in
the model's working units. `component` is `:zero`, `:positive`, or `:negative`.

These are the same expressions the bus sequence BOUNDS are built from
(`vneg_max`, `vzero_max`, `vpos_min`/`vpos_max`), so a penalty and a limit on
the same quantity cannot drift apart.

The reference is phase-to-neutral where the bus neutral floats and
phase-to-ground otherwise; using phase-to-ground on a floating-neutral bus would
fold the neutral displacement into the zero-sequence component. Requires a
three-phase bus and throws otherwise, rather than reporting the unbalance of an
imagined one.

The Fortescue transform is linear in the rectangular voltage variables, so both
returned expressions are affine. `re^2 + im^2` is therefore an exact smooth
quadratic needing no smoothing; only a MAGNITUDE penalty needs
[`smooth_norm`](@ref).

Implemented in the `BMOPFOpfExt` extension (requires JuMP and Ipopt loaded).
"""
function opf_sequence_voltage end
export opf_sequence_voltage

"""
    smooth_norm(ctx, x, y; scale, eps_rel=1e-3, annotate=true, name="")

Smooth 2-norm `sqrt(x^2 + y^2 + eps^2) - eps` of a complex quantity `(x, y)`, as
a JuMP expression on `ctx`'s model, with `eps = eps_rel * scale`.

The building block for any objective or constraint that needs the MAGNITUDE of a
phasor where the exact norm's gradient would be singular. It is C-infinity
everywhere including the origin (the exact norm's AD gradient there is 0/0, which
Ipopt rejects outright), and it underestimates the exact norm by at most `eps` —
a closed-form one-sided error budget rather than a tuning knob.

`scale` is the quantity's characteristic magnitude in the model's WORKING units
(a conductor rating for a current, a nominal voltage for a voltage), so the
relative smoothing is the same for every device in a heterogeneous fleet and the
same in SI and per-unit. See `ctx.bases` for the conversion.

`eps_rel`'s safe range depends on how the norm is used, and guidance correct in
one regime is wrong in the other:

  * The norm is being **minimised** (it is the objective, or a penalty term). The
    solve's endgame happens inside the smoothed region, so `eps` controls
    conditioning: keep it large, around the `1e-3` default. Shrinking it to
    solver-tolerance scale is measurably unreliable.
  * The norm is a **coefficient** in a term whose optimum is away from zero (a
    current-linear conduction loss, say). The solver never enters the smoothed
    region, `eps` costs nothing, and it can be as small as the accuracy target
    wants.

Implemented in the `BMOPFOpfExt` extension (requires JuMP and Ipopt loaded).
See also [`register_opf_differentiability_annotation!`](@ref), which this
records by default so the approximation is never silent.
"""
function smooth_norm end
export smooth_norm

"""
    register_opf_regularization!(ctx, name; method, weight, term_key,
        targets=[], purpose, units=:dimensionless, owner=:downstream,
        metadata=Dict(), replace=false)

Declare a downstream regularization without modifying the JuMP model. The
objective `term_key` and every target must already be registered semantic
objects. Duplicate names are rejected unless `replace=true`.
"""
function register_opf_regularization! end

"""Return defensive copies of all explicit regularization declarations."""
function opf_regularizations end

"""
    register_opf_differentiability_annotation!(ctx, name; kind, description,
        owner=:downstream, key=nothing, blocking=true, metadata=Dict(),
        replace=false)

Declare a differentiability hazard without changing the JuMP model. Use this
for extension-defined nonsmooth operators, Julia control flow that depends on a
parameter value, or formulation-specific locations that cannot safely accept a
parameter. Duplicate names are rejected unless `replace=true`.
"""
function register_opf_differentiability_annotation! end

"""Return defensive copies of all explicit differentiability annotations."""
function opf_differentiability_annotations end

"""
    opf_research_hashes(ctx) -> Dict{String,Any}

Return versioned SHA-256 fingerprints for the prepared working network, JuMP
model structure, current parameter state, regularization declarations, and
differentiability annotations.
These are construction/reproduction fingerprints, not certificates of
algebraic equivalence between independently formulated models.
"""
function opf_research_hashes end

"""
    bind_opf_parameter!(ctx, key, parameter, targets; kwargs...)

Bind a caller-created JuMP `Parameter` to one or more registered native or
downstream decision variables. `key` must have `kind == :parameter`; every
target must be a registered `OpfModelKey(:variable, ...)` in the same model.
The generated equality is `target = to_working_scale * parameter`.

Bindings may only be added before KCL finalization. `role=:structural` is
rejected because topology, terminal maps, and dimensions require rebuilding
the model. Supported roles are `:decision` and `:coefficient`.
"""
function bind_opf_parameter! end

"""Return the live JuMP parameter identified by its canonical key or alias."""
function opf_parameter end

"""Return a defensive metadata copy for one canonical parameter key or alias."""
function opf_parameter_binding end

"""Return defensive metadata copies for all registered parameter bindings."""
function opf_parameter_bindings end

"""
    opf_coefficient(ctx, key::OpfCoefficientKey, default)

Resolve a coefficient for a custom device builder. Returns `default` when no
provider is registered; otherwise calls the typed provider with
`(ctx, key, default)`. The returned scalar is in model working units.
"""
function opf_coefficient end

"""Return the registered coefficient provider, or `nothing` when absent."""
function opf_coefficient_provider end

"""Return a defensive copy of the coefficient-provider registry."""
function opf_coefficient_providers end

"""Return provider-consumption counts keyed by [`OpfCoefficientKey`](@ref)."""
function opf_coefficient_usage end

"""
    opf_differentiability_report(ctx; active_tolerance=1e-7,
        transition_tolerance=1e-5, dual_tolerance=1e-7)
        -> OpfDifferentiabilityReport

Return a conservative readiness and qualification report for downstream
implicit differentiation. Scalar inequalities are classified as active,
near-active, weakly active, or violated using normalized primal slack and dual
magnitude. Explicit extension annotations classify graph-invisible nonsmooth
operators, dynamic branches, and unsupported parameter locations. This function
computes diagnostics only; JVP/VJP operations remain the responsibility of
DiffOpt or another downstream package.
"""
function opf_differentiability_report end

"""
    opf_checked_kkt_factorization(ctx; pivot_tolerance=1e-10)

Return a factorization callback suitable for DiffOpt's nonlinear KKT
factorization attribute. It records an [`OpfKKTDiagnostic`](@ref) on `ctx` and
throws [`OpfDifferentiationError`](@ref) when LU fails or its pivot-ratio proxy
is at or below `pivot_tolerance`. This API has no DiffOpt dependency; the
downstream package remains responsible for installing and invoking the callback.
"""
function opf_checked_kkt_factorization end

"""Return the most recent checked KKT diagnostic, or `nothing`."""
function opf_kkt_diagnostic end

"""
    opf_research_provenance(ctx; kwargs...) -> Dict{String,Any}

Return a defensive, JSON-compatible experiment snapshot for a staged OPF
context. The record includes software and solver versions, formulation and
construction choices, statuses, objective and residual summaries, parameter
and coefficient maps, initialization/smoothing metadata, active-set diagnostics,
regularizations, differentiability annotations, reproducibility hashes, and the
latest checked-KKT result. Active-set tolerance keywords are forwarded to
[`opf_differentiability_report`](@ref).
"""
function opf_research_provenance end

"""
    extension_state!(ctx, owner[, init])

Return the state namespace owned by `owner`, creating it from the zero-argument
function `init` when absent (`Dict{Symbol,Any}` by default). `owner` should
normally be the downstream package module or a package-specific singleton type;
namespaces prevent independent extensions from colliding in one OPF context.
"""
function extension_state! end

"""
    add_terminal_injection!(ctx, bus, terminal, cr, ci) -> ctx

Add a real/imaginary current expression injected **into** a bus terminal to the
staged model's KCL accumulator. This is the supported low-level seam for custom
devices. It must be called before [`enforce_kcl!`](@ref); unknown buses or
terminals and post-finalization mutation are rejected.

Currents use the model's working units (per-unit by default). A WYE device must
also add the negative return current at its neutral terminal.
"""
function add_terminal_injection! end

export OpfModelKey, OpfParameterScope, OpfParameterBinding, OpfRegularization
export OpfDifferentiabilityAnnotation
export opf_bus_voltage_key, opf_ground_current_key, opf_line_current_key
export opf_switch_current_key, opf_load_current_key
export opf_generator_current_key, opf_voltage_source_current_key
export opf_transformer_current_key, opf_transformer_tap_key
export opf_nwinding_current_key, opf_ibr_current_key
export opf_ibr_power_key
export opf_ibr_voltage_magnitude_key
export opf_dc_voltage_key, opf_dc_ground_current_key
export opf_dc_branch_current_key, opf_converter_dc_current_key
export opf_dc_load_current_key, opf_dc_source_current_key
export opf_dc_source_power_key
export OpfDifferentiabilityReport, OpfKKTDiagnostic, OpfDifferentiationError
export OpfScaling, OpfDiagnosticSchema
export OpfBuildManifest, OpfDeviceBuilder, OpfBuildSpec
export OpfCoefficientKey, OpfCoefficientProvider
export opf_model, opf_network, opf_bases, opf_coordinate_bases
export opf_diagnostic_schema
export opf_lifecycle
export opf_neutral_labels
export opf_build_manifest, opf_build_spec, opf_stage_completed
export initialize_opf_model, set_opf_start_values!
export add_opf_operational_limits!, add_opf_device_constraints!
export set_opf_objective!
export register_opf_object!, opf_object, opf_object_keys
export register_opf_objective_term!, opf_primal, opf_constraint_value
export opf_constraint_slack, opf_dual, opf_objective_value
export register_opf_regularization!, opf_regularizations, opf_research_hashes
export register_opf_differentiability_annotation!
export opf_differentiability_annotations
export bind_opf_parameter!, opf_parameter, opf_parameter_binding
export opf_parameter_bindings
export opf_coefficient, opf_coefficient_provider, opf_coefficient_providers
export opf_coefficient_usage, opf_differentiability_report
export opf_checked_kkt_factorization, opf_kkt_diagnostic
export opf_research_provenance
export extension_state!, add_terminal_injection!, register_opf_result_extractor!

"""
    build_opf_model(net; kwargs...) -> ctx
    enforce_kcl!(ctx) -> ctx
    generation_cost(ctx) -> JuMP.QuadExpr
    extract_result(ctx; solution_hook!=nothing) -> Dict{String,Any}

Staged build/solve/extract API — the composable form of [`solve_opf`](@ref).
Implemented in the `BMOPFOpfExt` extension (requires JuMP and Ipopt loaded).

`solve_opf` fuses model construction, KCL, the solve, and result extraction into
one call. These four functions expose the same pipeline as discrete steps so a
caller can build **several OPF snapshots into one JuMP model**, couple them with
its own cross-snapshot constraints (e.g. battery state-of-charge dynamics linking
period `t` to `t+1`), set a single combined objective, `JuMP.optimize!` once, and
extract each snapshot's result. This is the supported path for multi-period /
storage formulations that the single-snapshot `solve_opf` cannot express.

Typical multi-period skeleton:

```julia
using JuMP, Ipopt
model = JuMP.Model(Ipopt.Optimizer)
duration_hours = fill(1.0, T)  # replace with each period's actual duration
ctxs  = [build_opf_model(net; t_index=t, model=model, add_objective=false,
                         model_hook! = storage_ports!) for t in 1:T]
# couple snapshots: SOC[t+1] = SOC[t] + Δt·(charge − discharge) …
link_soc!(model, ctxs)
JuMP.@objective(model, Min,
    sum(duration_hours[t] * generation_cost(ctxs[t]) for t in 1:T) + storage_cost)
foreach(enforce_kcl!, ctxs)
JuMP.optimize!(model)
results = [extract_result(c) for c in ctxs]
```

!!! warning "`enforce_kcl!` is not optional"
    `build_opf_model` deliberately does not stamp KCL, so that a `model_hook!`
    can still contribute to the nodal accumulators. Until `enforce_kcl!` runs,
    the network is electrically disconnected and bus voltages are free
    variables, so any objective over them is minimised without physics — the
    solve can return a successful-looking status and a physically meaningless
    answer. `solve_opf` handles this for you; a staged caller must not omit the
    `foreach(enforce_kcl!, ctxs)` line above.

    This is guarded by default. `JuMP.optimize!` raises on a model holding any
    context whose KCL stage never ran, and `extract_result` raises on such a
    context. Two limits are worth knowing: the optimize-time check is a JuMP
    optimize hook, so a hook installed *after* `build_opf_model` supersedes it
    (the `extract_result` check still applies), and a `JuMP.copy_model` of a
    guarded model is refused outright because the copy carries the hook but not
    the guard's state. Pass `kcl_guard=false` to `build_opf_model` /
    `initialize_opf_model` to opt out of the optimize-time check.

The full per-argument contract for each function is documented on its own entry
below.
"""
function build_opf_model end
export build_opf_model

"""
    enforce_kcl!(ctx) -> ctx

Enforce Kirchhoff's current law for one snapshot's accumulators (AC nodal balance
+ DC network), after every device constraint and `model_hook!` injection for that
snapshot has contributed. Second step of the staged API (see
[`build_opf_model`](@ref)); call once per snapshot `ctx` before `JuMP.optimize!`.
Implemented in the `BMOPFOpfExt` extension.
"""
function enforce_kcl! end
export enforce_kcl!

"""
    generation_cost(ctx) -> JuMP.QuadExpr

The snapshot's total active-power generation-cost-rate expression (currency/hour) — the
quantity [`solve_opf`](@ref) minimises — returned WITHOUT setting it on the
model. For a multi-period monetary objective, multiply each expression by that
period's duration in hours before summing it with any custom cost terms; a bare
sum is only valid when all periods have the same duration and only the optimizer,
not the reported currency total, matters. Pairs with
`build_opf_model(...; add_objective=false)`.
Implemented in the `BMOPFOpfExt` extension.
"""
function generation_cost end
export generation_cost

"""
    extract_result(ctx; solution_hook!=nothing) -> Dict{String,Any}

Extract one snapshot's SI result dict from the solved model (call
`JuMP.optimize!(opf_model(ctx))` first). Mirrors [`solve_opf`](@ref)'s output for that
snapshot: runs the optional `solution_hook!(ctx, result)`, attaches `opt_profile`,
and unwraps per-unit back to SI. Final step of the staged API (see
[`build_opf_model`](@ref)). Implemented in the `BMOPFOpfExt` extension.
"""
function extract_result end
export extract_result

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

export Severity, ERROR, WARNING, INFO
export Finding, SummaryReport, SolutionReport
export errors, warnings, infos
export profile_solution, render_solution, solution_check
export parse_bmopf, write_bmopf
export write_result, read_result
export to_pmd
export from_dss, to_dss, powerio_source_behavior_contract
export powerio_findings
export project_solution, dispatch_as_loads
export sideload_coordinates!
export analyze, render
export load_config                      # tunable thresholds (config/default.toml)
export is_timeseries, get_snapshot      # useful for interactive use

# NOT exported (call qualified; stable in behaviour, not committed by name):
#   migrate               — runs automatically inside parse_bmopf
#   render_markdown/render_terminal — backends of the `render` verb
#   voltage_zone_summary  — internal aggregation behind profile_solution

# Per-pass analysis and validation entry points. These are deliberate public
# API (documented in analysis.md and toured by the walkthrough example):
# each pass is callable standalone for targeted checks, and its finding codes
# are covered by the stability contract in dev/versioning.md.
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
export render_ascii_tree
export augment_case, AugmentationRecipe, default_recipe
export fix_case, FixRecipe
export add_generators, GeneratorRecipe, default_generator_recipe
export add_ibrs, IBRRecipe, default_ibr_recipe
export add_statcom!
export TransformationManifest, TransformEntry, manifest_to_dict, render_manifest
export diagnose_infeasibility
export merge_series_lines, remove_dangling_lines
export remove_open_switches, collapse_closed_switches
export simplify_network
export transformer_yprim, export_yprim, write_yprim
export ybus_passive, YbusResult, line_yprim
export ybus_linearized, LinearizedYbus
export ybus_augmented, AugYbusResult, IdealCoupling
export overhead_line_constants, compile_linecode, compile_linecodes!

# ---------------------------------------------------------------------------
# Error hints
# ---------------------------------------------------------------------------

function __init__()
    # The OPF entry points are stubs whose methods live in the BMOPFOpfExt
    # package extension; without it a call raises a bare MethodError. Point
    # the user at the missing extension instead.
    Base.Experimental.register_error_hint(MethodError) do io, exc, _argtypes, _kwargs
        if exc.f in (solve_opf, solve_pf, solve_feasibility_opf)
            print(io, "\n\n`$(nameof(exc.f))` is provided by the BMOPFOpfExt " *
                      "package extension, which activates when JuMP and Ipopt " *
                      "are loaded. Run `import Pkg; Pkg.add([\"JuMP\", \"Ipopt\"])` " *
                      "once, then `using JuMP, Ipopt` before calling it.")
        end
    end
end

end # module BMOPFTools
