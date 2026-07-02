# Default numeric→name terminal aliases: 1≡a, 2≡b, 3≡c, 4≡neutral.
# Applied at ingest only when *every* numeric terminal token in the file is
# covered (the profiling guard) — a file with exotic terminals falls back to
# verbatim decimal strings so no information is invented.
const _DEFAULT_TERMINAL_ALIASES =
    Dict{Any,String}(1 => "1", 2 => "2", 3 => "3", 4 => "n")

"""
    parse_bmopf(path::AbstractString; terminal_aliases) -> Dict{String,Any}
    parse_bmopf(io::IO; terminal_aliases) -> Dict{String,Any}
    parse_bmopf(json::AbstractString; from_string=true, terminal_aliases) -> Dict{String,Any}

Parse a BMOPF JSON file (or IO stream, or raw JSON string) into a plain
`Dict{String,Any}` that mirrors the schema structure exactly.

The returned dict is mutable — analysis functions treat it as read-only
but callers may modify it freely.

Enums from PowerModelsDistribution (e.g. `WYE`, `DELTA`) are stored as
plain strings in BMOPF JSON and remain strings after parsing.  The
`to_pmd` conversion layer handles the string → Enum translation.

# Terminal normalization
The data model requires terminal identifiers to be strings. Non-string
entries (e.g. integer terminals `[1,2,3,4]`) are coerced at ingest:

- if every numeric token is covered by `terminal_aliases` (default
  `1→"1", 2→"2", 3→"3", 4→"n"`), the alias map is applied;
- otherwise — the profiling guard — every token becomes its verbatim
  decimal string and the neutral-identification heuristic decides
  semantics downstream.

Coercion is recorded under `_meta["terminal_coercions"]` and surfaced as
a `W.SPEC.TERMINAL_TYPES` conformance finding. Pass a custom
`terminal_aliases::Dict` to override the convention.

# Raises
- `ArgumentError` if the file cannot be found or is not valid JSON.
- Does **not** validate against the BMOPF JSON Schema here; call
  [`schema_check`](@ref) and [`spec_conformance_check`](@ref) for that.
"""
function parse_bmopf(path::AbstractString; from_string::Bool=false,
                     terminal_aliases::Dict=_DEFAULT_TERMINAL_ALIASES)::Dict{String,Any}
    if from_string
        _parse_bmopf_string(path; terminal_aliases)
    else
        isfile(path) || throw(ArgumentError("File not found: $path"))
        open(path, "r") do io
            _parse_bmopf_io(io; terminal_aliases)
        end
    end
end

function parse_bmopf(io::IO; terminal_aliases::Dict=_DEFAULT_TERMINAL_ALIASES)::Dict{String,Any}
    _parse_bmopf_io(io; terminal_aliases)
end

function _parse_bmopf_io(io::IO; terminal_aliases::Dict=_DEFAULT_TERMINAL_ALIASES)::Dict{String,Any}
    raw = JSON3.read(io, Dict{String,Any})
    _postprocess(raw, terminal_aliases)
end

function _parse_bmopf_string(s::AbstractString;
                             terminal_aliases::Dict=_DEFAULT_TERMINAL_ALIASES)::Dict{String,Any}
    raw = JSON3.read(s, Dict{String,Any})
    _postprocess(raw, terminal_aliases)
end

"""
Post-processing after JSON parse:
- Ensures all nested dicts are `Dict{String,Any}` (JSON3 may return
  typed dicts in some cases).
- Normalizes non-string terminal identifiers to canonical strings.
- Records provenance metadata if not already present.
"""
function _postprocess(raw::Dict{String,Any},
                      terminal_aliases::Dict=_DEFAULT_TERMINAL_ALIASES)::Dict{String,Any}
    d = _deep_convert(raw)
    d = migrate(d)
    n_coerced, mode = _normalize_terminals!(d, terminal_aliases)
    # Stamp parse time if no metadata present
    if !haskey(d, "_meta")
        d["_meta"] = Dict{String,Any}(
            "parsed_at" => string(now())
        )
    end
    if n_coerced > 0
        d["_meta"]["terminal_coercions"] = Dict{String,Any}(
            "n" => n_coerced, "mode" => mode)
    end
    # Restore tool provenance persisted by write_bmopf (meta.provenance) into
    # the in-memory _meta block, so fidelity-loss inventories and migration
    # notes survive a save/load round trip. In-memory _meta keys win.
    prov = get(get(d, "meta", Dict{String,Any}()), "provenance", nothing)
    if prov isa Dict
        for (k, v) in prov
            get!(d["_meta"], k, v)
        end
    end
    d
end

const _TERMINAL_ARRAY_KEYS = ("terminal_names", "perfectly_grounded_terminals",
                              "terminal_map", "terminal_map_from",
                              "terminal_map_to")

"""
Coerce non-string terminal identifiers (spec requires strings) to canonical
names. If every non-string token is covered by `aliases`, the alias map is
applied (default: 1→"1", 2→"2", 3→"3", 4→"n"); otherwise — the profiling
guard — every token becomes its verbatim decimal string and the standard
`_neutral_terminal` heuristic handles semantics downstream. Returns
(n_coerced, mode).
"""
function _normalize_terminals!(net::Dict{String,Any}, aliases::Dict)
    # collect all non-string tokens first (profiling pass)
    tokens = Set{Any}()
    each_terminal_array(net) do arr
        for t in arr
            t isa AbstractString || push!(tokens, t)
        end
    end
    isempty(tokens) && return (0, "none")
    use_aliases = all(t -> haskey(aliases, t), tokens)
    mode = use_aliases ? "aliases" : "verbatim-string"

    n = 0
    each_terminal_array(net) do arr
        for i in eachindex(arr)
            t = arr[i]
            t isa AbstractString && continue
            arr[i] = use_aliases ? aliases[t] : string(t)
            n += 1
        end
    end
    (n, mode)
end

# apply f to every terminal-bearing array in the network dict
function each_terminal_array(f, net::Dict{String,Any})
    visit(comp) = begin
        comp isa Dict || return
        for k in _TERMINAL_ARRAY_KEYS
            v = get(comp, k, nothing)
            v isa AbstractVector && f(v)
        end
    end
    for comp_type in ("bus", "line", "load", "generator", "voltage_source",
                      "shunt", "switch", "ibr")
        components = get(net, comp_type, nothing)
        components isa Dict || continue
        foreach(visit, values(components))
    end
    xfmr = get(net, "transformer", nothing)
    if xfmr isa Dict
        for subtype in TRANSFORMER_SUBTYPES
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            foreach(visit, values(sub))
        end
    end
    nothing
end

"""
Recursively convert any nested JSON3 objects/arrays into plain
`Dict{String,Any}` and `Vector{Any}` so that callers can use standard
Julia dict operations throughout.
"""
function _deep_convert(@nospecialize(x))
    if x isa Dict
        Dict{String,Any}(string(k) => _deep_convert(v) for (k, v) in x)
    elseif x isa AbstractVector
        Any[_deep_convert(v) for v in x]
    else
        x
    end
end

# ---------------------------------------------------------------------------
# Time-series helpers
# ---------------------------------------------------------------------------

"""
    is_timeseries(net::Dict{String,Any}) -> Bool

Return `true` if the network dict contains a root-level `"time_series"`
collection with at least one entry, *and* at least one component references
it via a `"time_series"` sub-dict.

This follows PMD's convention: a network with a `"time_series"` key but
no component references is treated as a snapshot network.
"""
function is_timeseries(net::Dict{String,Any})::Bool
    ts = get(net, "time_series", nothing)
    ts isa Dict && !isempty(ts) && _any_component_has_ts_ref(net)
end

function _any_component_has_ts_ref(net::Dict{String,Any})::Bool
    for key in ("bus", "line", "load", "generator", "voltage_source",
                "shunt", "switch", "ibr", "transformer")
        components = get(net, key, nothing)
        components isa Dict || continue
        for (_, comp) in components
            comp isa Dict || continue
            ts_ref = get(comp, "time_series", nothing)
            if ts_ref isa Dict && !isempty(ts_ref)
                return true
            end
        end
    end
    # also check nested transformer subtypes
    xfmr = get(net, "transformer", nothing)
    if xfmr isa Dict
        for subtype in TRANSFORMER_SUBTYPES
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            for (_, comp) in sub
                comp isa Dict || continue
                ts_ref = get(comp, "time_series", nothing)
                if ts_ref isa Dict && !isempty(ts_ref)
                    return true
                end
            end
        end
    end
    false
end

"""
    get_snapshot(net::Dict{String,Any}, t_index::Int) -> Dict{String,Any}

Materialise a snapshot of a time-series network at time step `t_index`
(1-based).

Returns a deep copy of `net` with all `"time_series"` parameter references
resolved to concrete scalar/vector values and all component-level
`"time_series"` sub-dicts removed. The root-level `"time_series"` key is
also removed from the result.

For a network without time series, returns a deep copy unchanged.

PMD convention: time series values are **scaling factors** applied
multiplicatively to the static parameter value:

    resolved_value = static_value * scale_factor[t_index]

# Raises
- `BoundsError` if `t_index` is out of range for any referenced series.
"""
function get_snapshot(net::Dict{String,Any}, t_index::Int)::Dict{String,Any}
    snap = deepcopy(net)
    !is_timeseries(snap) && return snap

    ts_root = snap["time_series"]

    for key in ("bus", "line", "load", "generator", "voltage_source",
                "shunt", "switch", "ibr")
        components = get(snap, key, nothing)
        components isa Dict || continue
        for (_, comp) in components
            comp isa Dict || continue
            _resolve_component_ts!(comp, ts_root, t_index)
        end
    end

    # transformer subtypes
    xfmr = get(snap, "transformer", nothing)
    if xfmr isa Dict
        for subtype in TRANSFORMER_SUBTYPES
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            for (_, comp) in sub
                comp isa Dict || continue
                _resolve_component_ts!(comp, ts_root, t_index)
            end
        end
    end

    delete!(snap, "time_series")
    snap
end

function _resolve_component_ts!(comp::Dict{String,Any},
                                ts_root::Dict{String,Any},
                                t_index::Int)
    ts_refs = get(comp, "time_series", nothing)
    ts_refs isa Dict || return

    for (param, ts_id) in ts_refs
        ts_id = string(ts_id)
        haskey(ts_root, ts_id) ||
            throw(KeyError("time_series id '$ts_id' referenced by component but not found at root level"))

        ts = ts_root[ts_id]
        values = ts["values"]
        t_index <= length(values) ||
            throw(BoundsError(values, t_index))

        scale = values[t_index]
        static_val = get(comp, param, nothing)

        if static_val isa AbstractVector
            comp[param] = static_val .* scale
        elseif static_val isa Number
            comp[param] = static_val * scale
        else
            # Storing the bare scale factor would silently corrupt units.
            throw(ArgumentError(
                "Time series reference for parameter '$param' (series '$ts_id') " *
                "has no static value on the component to scale. PMD convention " *
                "requires a concrete base value; refusing to materialise snapshot."))
        end
    end

    delete!(comp, "time_series")
    nothing
end
