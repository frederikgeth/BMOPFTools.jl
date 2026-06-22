# validation/schema.jl
#
# Two-layer schema validation:
#
#   Layer 1 — JSONSchema.jl structural validation against the bundled JSON
#             Schema for the spec version declared in meta.$schema. Catches
#             type errors, missing required fields, enum violations, and
#             additional properties not defined in the spec.
#
#   Layer 2 — hand-rolled unknown-field catalogue (fallback when the spec
#             version is unrecognised, and a cross-check for layer 1). Also
#             catalogues fields that are present but not in the schema for
#             dataset-assessment reporting.

using JSONSchema

# ---------------------------------------------------------------------------
# Schema registry — map spec version tag → loaded JSONSchema.Schema object.
# Schemas are loaded lazily on first use and cached here.
# ---------------------------------------------------------------------------

const _SCHEMA_FILES = Dict{Symbol,String}(
    :draft => joinpath(@__DIR__, "schemas", "draft_bmopf_schema.json"),
)

const _SCHEMA_CACHE = Dict{Symbol,JSONSchema.Schema}()

function _get_schema(version::Symbol)::Union{JSONSchema.Schema,Nothing}
    haskey(_SCHEMA_CACHE, version) && return _SCHEMA_CACHE[version]
    path = get(_SCHEMA_FILES, version, nothing)
    path === nothing && return nothing
    isfile(path) || return nothing
    raw = JSON3.read(read(path, String))
    schema = JSONSchema.Schema(raw)
    _SCHEMA_CACHE[version] = schema
    schema
end

# ---------------------------------------------------------------------------
# Strip internal keys before passing to JSONSchema.
# The schema uses additionalProperties:false so _meta, _pmd etc. would be
# spurious failures. Internal keys always start with "_".
# ---------------------------------------------------------------------------

function _strip_internal(@nospecialize(x))
    x isa Dict || return x
    out = Dict{String,Any}()
    for (k, v) in x
        startswith(string(k), "_") && continue
        out[string(k)] = _strip_internal(v)
    end
    out
end

# ---------------------------------------------------------------------------
# Convert a JSONSchema.jl SingleIssue into a Finding.
#
# JSONSchema.jl v1.5 returns a JSONSchema.SingleIssue with fields:
#   x      — the offending instance value
#   path   — Vector of path segments to the failing location
#   reason — keyword: "type", "required", "enum", "minimum", "additionalProperties", …
#   val    — the schema value that was violated (e.g. "number", ["x","y"], …)
#
# validate() returns the *first* issue found, not all issues. We emit one
# Finding per call and note in the message that further issues may exist.
# ---------------------------------------------------------------------------

function _single_issue_to_finding!(findings::Vector{Finding}, issue)
    reason = string(issue.reason)
    # JSONSchema.jl v1.5: issue.path is a pre-formatted String like "[bus][306][vpn_min]"
    path = isempty(issue.path) ? "(top-level)" : issue.path

    sev, code, msg = if reason == "required"
        ERROR, "E.SCHEMA.REQUIRED",
        "Missing required field at $path (expected: $(issue.val))."
    elseif reason == "type"
        ERROR, "E.SCHEMA.TYPE",
        "Type error at $path: got $(typeof(issue.x)), expected $(issue.val)."
    elseif reason == "enum"
        ERROR, "E.SCHEMA.ENUM",
        "Invalid value at $path: $(repr(issue.x)) not in allowed values $(issue.val)."
    elseif reason in ("minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum")
        ERROR, "E.SCHEMA.RANGE",
        "Value $(issue.x) at $path violates $reason constraint $(issue.val)."
    elseif reason == "additionalProperties"
        INFO, "I.SCHEMA.UNKNOWN_FIELDS",
        "Additional property not defined in schema at $path."
    else
        INFO, "I.SCHEMA.OTHER",
        "Schema violation ($reason) at $path."
    end

    # Extract component_type and component_id from the path string.
    # Format is "[comp_type][comp_id][field]", e.g. "[bus][306][vpn_min]".
    comp_type = :network
    comp_id   = nothing
    segments  = [m.match for m in eachmatch(r"\[([^\]]+)\]", path)]
    if length(segments) >= 2
        comp_type = Symbol(segments[1])
        comp_id   = segments[2]
    elseif length(segments) == 1
        comp_type = Symbol(segments[1])
    end

    push!(findings, Finding(sev, code, :schema, comp_type, comp_id, msg,
        Dict{String,Any}("reason" => reason, "path" => path,
                         "schema_value" => string(issue.val))))
end

# ---------------------------------------------------------------------------
# Known fields — fallback hand-rolled allowlist (layer 2).
# Used when spec version is unrecognised, and to catalogue additional fields
# present in the data regardless of JSONSchema result.
# ---------------------------------------------------------------------------

const _KNOWN_FIELDS = Dict{String,Set{String}}(
    "bus" => Set(["terminal_names", "neutral_terminal", "perfectly_grounded_terminals",
                  "v_min", "v_max", "vpn_min", "vpn_max",
                  "vpp_min", "vpp_max", "vpos_min", "vpos_max",
                  "vneg_max", "vzero_max",
                  "vn_max", "va_diff_min", "va_diff_max"]),
    "line" => Set(["length", "linecode", "bus_from", "bus_to",
                   "terminal_map_from", "terminal_map_to",
                   "va_diff_min", "va_diff_max"]),
    "voltage_source" => Set(["v_magnitude", "v_angle", "bus", "terminal_map",
                             "configuration", "p_min", "p_max", "q_min", "q_max",
                             "cost"]),
    "shunt" => Set(["bus", "terminal_map"]),
    "load" => Set(["p_nom", "q_nom", "bus", "configuration", "terminal_map",
                   "model", "v_nom",
                   "alpha_z", "alpha_i", "alpha_p",
                   "beta_z", "beta_i", "beta_p",
                   "gamma_p", "gamma_q"]),
    "generator" => Set(["p_min", "p_max", "q_min", "q_max", "cost",
                        "bus", "configuration", "terminal_map",
                        "i_max", "s_max"]),
    "linecode" => Set(["i_max", "s_max"]),
    "switch" => Set(["bus_from", "bus_to", "terminal_map_from",
                     "terminal_map_to", "open_switch", "i_max"]),
    "inverter" => Set(["bus", "terminal_map", "topology", "prime_mover",
                       "s_max", "p_avail", "p_min", "p_max", "q_min", "q_max",
                       "r_filter", "x_filter", "b_filter_shunt",
                       "grid_forming", "v_ref_internal", "cost",
                       "control_profile", "voltage_ref"]),
    # control_profile components are keyed by control-law name; list all nine
    # so future laws beyond the currently-wired three are not flagged as unknown
    "control_profile" => Set(["volt_var", "volt_watt", "watt_var", "watt_pf",
                              "power_factor", "power_sharing",
                              "sequence_current_limits", "droop", "gfm_voltage"])
)

const _KNOWN_TRANSFORMER_FIELDS = Dict{String,Set{String}}(
    "single_phase" => Set(["s_rating", "r_series_from", "x_series_from",
                           "r_series_to", "x_series_to", "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "v_ref_from", "v_ref_to",
                           "i_max_from", "i_max_to",
                           "g_no_load", "b_no_load"]),
    "center_tap"   => Set(["s_rating", "r_series_from", "x_series_from",
                           "r_series_to", "x_series_to", "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "v_ref_from", "v_ref_to",
                           "i_max_from", "i_max_to",
                           "g_no_load", "b_no_load"]),
    "wye_delta"    => Set(["s_rating",
                           "r_series_from", "x_series_from",
                           "r_series_to",   "x_series_to",
                           "r_series", "x_series",          # legacy shorthand
                           "g_no_load", "b_no_load",
                           "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "v_ref_from", "v_ref_to",
                           "i_max_from", "i_max_to"]),
    "delta_wye"    => Set(["s_rating",
                           "r_series_from", "x_series_from",
                           "r_series_to",   "x_series_to",
                           "r_series", "x_series",          # legacy shorthand
                           "g_no_load", "b_no_load",
                           "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "v_ref_from", "v_ref_to",
                           "i_max_from", "i_max_to"]),
    # Single-phase step voltage regulator / autotransformer. The ratio is the
    # fixed `tap_ratio` (not v_ref_from/v_ref_to); `regulator_type` picks ANSI A/B.
    "single_phase_autotransformer" =>
                      Set(["s_rating", "r_series_from", "x_series_from",
                           "r_series_to", "x_series_to", "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "tap_ratio", "regulator_type",
                           "i_max_from", "i_max_to",
                           "g_no_load", "b_no_load"]),
    # Monolithic open-delta regulator: two single-phase autotransformer windings
    # connected line-to-line across the phase pairs implied by `connection`.
    "open_delta_regulator" =>
                      Set(["s_rating", "r_series_from", "x_series_from",
                           "r_series_to", "x_series_to", "bus_from", "bus_to",
                           "terminal_map_from", "terminal_map_to",
                           "tap_ratio", "regulator_type", "connection",
                           "i_max_from", "i_max_to",
                           "g_no_load", "b_no_load"])
)

const _KNOWN_PATTERNS = Dict{String,Vector{Regex}}(
    "linecode" => [r"^R_series_\d+_\d+$", r"^X_series_\d+_\d+$",
                   r"^G_from_\d+_\d+$",   r"^G_to_\d+_\d+$",
                   r"^B_from_\d+_\d+$",   r"^B_to_\d+_\d+$"],
    "shunt"    => [r"^G_\d+_\d+$", r"^B_\d+_\d+$"]
)

const _TOLERATED_KEYS = Set(["_meta", "_pmd", "time_series"])

function _catalogue_unknown_fields(net::Dict{String,Any},
                                    findings::Vector{Finding})::Dict{String,Any}
    unknown_by_type = Dict{String,Dict{String,Int}}()

    for (comp_type, known) in _KNOWN_FIELDS
        components = get(net, comp_type, nothing)
        components isa Dict || continue
        patterns = get(_KNOWN_PATTERNS, comp_type, Regex[])
        unknown = Dict{String,Int}()
        for (_, comp) in components
            comp isa Dict || continue
            for k in keys(comp)
                k in known && continue
                (k in _TOLERATED_KEYS || startswith(k, "_")) && continue
                any(p -> match(p, k) !== nothing, patterns) && continue
                unknown[k] = get(unknown, k, 0) + 1
            end
        end
        isempty(unknown) || (unknown_by_type[comp_type] = unknown)
    end

    xfmr = get(net, "transformer", nothing)
    if xfmr isa Dict
        for (subtype, known) in _KNOWN_TRANSFORMER_FIELDS
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            unknown = Dict{String,Int}()
            for (_, comp) in sub
                comp isa Dict || continue
                for k in keys(comp)
                    k in known && continue
                    (k in _TOLERATED_KEYS || startswith(k, "_")) && continue
                    unknown[k] = get(unknown, k, 0) + 1
                end
            end
            isempty(unknown) ||
                (unknown_by_type["transformer/$subtype"] = unknown)
        end
    end

    known_top = Set(["name", "meta", "bus", "line", "linecode", "voltage_source",
                     "load", "generator", "shunt", "switch", "transformer",
                     "inverter", "control_profile",
                     "time_series", "_meta"])
    unknown_top = [k for k in keys(net) if !(k in known_top) && !startswith(k, "_")]
    isempty(unknown_top) ||
        (unknown_by_type["(top-level)"] = Dict(k => 1 for k in unknown_top))

    for (ctype, unknown) in unknown_by_type
        field_list = join(sort(collect(keys(unknown))), ", ")
        push!(findings, Finding(INFO, "I.SCHEMA.UNKNOWN_FIELDS", :schema,
            Symbol(replace(ctype, "/" => "_", "(" => "", ")" => "", "-" => "_")), nothing,
            "$ctype has field(s) not in the BMOPF schema: $field_list.",
            Dict{String,Any}("fields" => unknown)))
    end

    unknown_by_type
end

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

"""
    schema_check(net, findings) -> Dict{String,Any}

Two-layer schema validation:

**Layer 1** — JSONSchema.jl validation against the bundled JSON Schema for
the spec version declared in `meta.\$schema`. Catches type errors, missing
required fields, enum violations (`configuration` must be `"WYE"`, `"DELTA"`,
or `"SINGLE_PHASE"`), and `nonnegative_number` range constraints. Errors are
reported as `ERROR` findings; additional (unknown) properties as `INFO`.

**Layer 2** — hand-rolled unknown-field catalogue. Always runs; produces the
`unknown_fields_by_type` result dict used by the dataset-assessment report
section regardless of whether layer 1 ran.

Layer 1 is skipped (with an `INFO` finding) when the spec version in
`meta.\$schema` is not recognised — the hand-rolled catalogue still runs as
a fallback.
"""
function schema_check(net::Dict{String,Any},
                      findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    # ── Layer 1: JSONSchema structural validation ─────────────────────────────
    version = _detect_spec_version(net)
    schema  = _get_schema(version)

    if schema === nothing
        push!(findings, Finding(INFO, "I.SCHEMA.VERSION_UNKNOWN", :schema,
            :network, nothing,
            "Spec version '$version' has no bundled JSON Schema; " *
            "structural validation skipped. Unknown-field catalogue still runs.",
            nothing))
        result["jsonschema_ran"] = false
    else
        clean = _strip_internal(net)
        err   = JSONSchema.validate(schema, clean)
        if err === nothing
            result["jsonschema_valid"] = true
        else
            result["jsonschema_valid"] = false
            _single_issue_to_finding!(findings, err)
        end
        result["jsonschema_ran"]   = true
        result["spec_version"]     = string(version)
    end

    # ── Layer 2: unknown-field catalogue ─────────────────────────────────────
    unknown_by_type = _catalogue_unknown_fields(net, findings)
    result["unknown_fields_by_type"]          = unknown_by_type
    result["n_component_types_with_unknown"]  = length(unknown_by_type)

    # ── meta block validation ─────────────────────────────────────────────────
    meta = get(net, "meta", nothing)
    meta isa Dict && _check_meta(meta, findings)

    result
end

# ---------------------------------------------------------------------------
# meta block validation (unchanged)
# ---------------------------------------------------------------------------

const _META_KNOWN_FIELDS = Set([
    "\$schema", "version", "title", "description",
    "created", "modified", "license",
    "authors", "sources", "generator",
])
const _META_AUTHOR_FIELDS  = Set(["name", "email", "orcid"])
const _META_SOURCE_FIELDS  = Set(["name", "url", "format", "doi", "version"])
const _META_GEN_FIELDS     = Set(["tool", "version"])
const _ORCID_RE            = r"^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$"
const _ISO8601_RE          = r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?Z?)?$"
const _URI_RE              = r"^https?://"

function _check_meta(meta::Dict, findings::Vector{Finding})
    unknown = [k for k in keys(meta) if !(k in _META_KNOWN_FIELDS)]
    if !isempty(unknown)
        push!(findings, Finding(INFO, "I.SCHEMA.UNKNOWN_FIELDS", :schema,
            :network, nothing,
            "meta has field(s) not in the BMOPF schema: $(join(sort(unknown), ", ")).",
            Dict{String,Any}("fields" => Dict(k => 1 for k in unknown))))
    end

    s = get(meta, "\$schema", nothing)
    if s isa String && !occursin(_URI_RE, s)
        push!(findings, Finding(WARNING, "W.SCHEMA.META_SCHEMA_URI", :schema,
            :network, nothing,
            "meta.\$schema does not look like a URI: \"$s\"."))
    end

    for field in ("created", "modified")
        v = get(meta, field, nothing)
        if v isa String && !occursin(_ISO8601_RE, v)
            push!(findings, Finding(WARNING, "W.SCHEMA.META_DATE_FORMAT", :schema,
                :network, nothing,
                "meta.$field is not a recognised ISO 8601 datetime: \"$v\"."))
        end
    end

    lic = get(meta, "license", nothing)
    if lic isa String && !occursin(_URI_RE, lic) && length(lic) > 30
        push!(findings, Finding(INFO, "I.SCHEMA.META_LICENSE_URI", :schema,
            :network, nothing,
            "meta.license looks long for an SPDX identifier; consider using a URI."))
    end

    authors = get(meta, "authors", nothing)
    if authors isa Vector
        for (i, a) in enumerate(authors)
            a isa Dict || continue
            bad = [k for k in keys(a) if !(k in _META_AUTHOR_FIELDS)]
            isempty(bad) || push!(findings, Finding(INFO, "I.SCHEMA.UNKNOWN_FIELDS",
                :schema, :network, nothing,
                "meta.authors[$i] has unknown field(s): $(join(sort(bad), ", "))."))
            orcid = get(a, "orcid", nothing)
            if orcid isa String && !occursin(_ORCID_RE, orcid)
                push!(findings, Finding(WARNING, "W.SCHEMA.META_ORCID_FORMAT", :schema,
                    :network, nothing,
                    "meta.authors[$i].orcid does not match the ORCID format " *
                    "(XXXX-XXXX-XXXX-XXXX): \"$orcid\"."))
            end
        end
    end

    sources = get(meta, "sources", nothing)
    if sources isa Vector
        for (i, src) in enumerate(sources)
            src isa Dict || continue
            bad = [k for k in keys(src) if !(k in _META_SOURCE_FIELDS)]
            isempty(bad) || push!(findings, Finding(INFO, "I.SCHEMA.UNKNOWN_FIELDS",
                :schema, :network, nothing,
                "meta.sources[$i] has unknown field(s): $(join(sort(bad), ", "))."))
            url = get(src, "url", nothing)
            if url isa String && !occursin(_URI_RE, url)
                push!(findings, Finding(WARNING, "W.SCHEMA.META_SOURCE_URL", :schema,
                    :network, nothing,
                    "meta.sources[$i].url does not look like a URI: \"$url\"."))
            end
        end
    end

    gen = get(meta, "generator", nothing)
    if gen isa Dict
        bad = [k for k in keys(gen) if !(k in _META_GEN_FIELDS)]
        isempty(bad) || push!(findings, Finding(INFO, "I.SCHEMA.UNKNOWN_FIELDS",
            :schema, :network, nothing,
            "meta.generator has unknown field(s): $(join(sort(bad), ", "))."))
    end
end
