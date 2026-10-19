"""
    write_bmopf(net::Dict{String,Any}, dest; meta=nothing, indent=2, include_coordinates=true)

Serialise a BMOPF network dict to JSON.

- `dest::IO`             — writes to the IO stream
- `dest::AbstractString` — writes to a file at that path

A `meta` block is always written. Fields are assembled in this priority order
(highest wins): the `meta` keyword argument → `net["meta"]` → auto-generated
defaults (`\$schema`, `case_study_generator`, `created`). Caller-supplied values
are never overwritten by auto-generation.

The input `net` is never mutated. Tool-private state is not serialised verbatim:
the `"_meta"` key is persisted under `meta.provenance`, and the derived bus
`neutral_terminal` is stripped (it is recomputed on read). Bus `longitude` and
`latitude` fields are preserved by default for viewers such as Tellegen.
These coordinate fields are a non-spec extension: pass
`include_coordinates=false` to omit them for strict BMOPF schema consumers.
Omitted coordinates are not recoverable from the written file.

Output is newline-terminated in both modes, so files round-trip through `diff`
and shell pipelines without a "\\ No newline at end of file" marker.

# Keyword arguments
- `meta`: a `Dict` of fields to include or override in the written `meta` block.
  All fields are optional; common ones are `title`, `description`, `license`,
  `authors`, `data_sources`, and `version`. See `docs/src/conventions.md` for the
  full field reference.
- `indent`: number of spaces for pretty-printing (default `2`). Pass
  `indent=nothing` for compact single-line output — one line of JSON plus the
  trailing newline.
- `include_coordinates`: preserve existing bus `longitude`/`latitude` fields
  (default `true`). Values are copied unchanged, including partial pairs;
  this does not validate a coordinate reference system, transform coordinates,
  or invent missing positions. Nonfinite numbers are rejected by the JSON writer.

# Example
```julia
write_bmopf(net, "output.json";
    meta = Dict(
        "title"   => "LV network 1, Feeder 1",
        "license" => "https://creativecommons.org/licenses/by/4.0/",
        "authors" => [Dict("name" => "Frederik Geth", "orcid" => "0000-0001-9534-2265")],
        "data_sources" => [Dict("name" => "ENWL dataset", "format" => "OpenDSS",
                           "url"  => "https://www.enwl.co.uk/…")]
    ))
```
"""
function write_bmopf(net::Dict{String,Any}, io::IO;
                     meta::Union{Dict,Nothing}=nothing,
                     indent::Union{Int,Nothing}=2,
                     include_coordinates::Bool=true)
    base     = get(net, "meta", Dict{String,Any}())
    out_meta = _build_meta(base, meta)

    # Persist tool provenance (_meta: fidelity-loss inventory, migration
    # notes, earth-terminal routing, …) under meta.provenance so it survives
    # the save/load round trip. Caller-set meta.provenance keys win; volatile
    # per-parse stamps are not persisted.
    priv = get(net, "_meta", Dict{String,Any}())
    if priv isa Dict && !isempty(priv)
        prov = Dict{String,Any}(k => v for (k, v) in priv
                                if k ∉ ("parsed_at",))
        existing = get(out_meta, "provenance", nothing)
        if existing isa Dict
            for (k, v) in existing; prov[k] = v; end
        end
        isempty(prov) || (out_meta["provenance"] = prov)
    end

    # Build output without mutating net; drop _meta (tool-private, not spec)
    out = Dict{String,Any}(k => v for (k, v) in net
                           if k != "meta" && k != "_meta")
    buses = get(net, "bus", nothing)
    buses isa Dict && (out["bus"] = _strip_derived_bus_fields(buses; include_coordinates))
    # Always export the terminal-role convention. If the case never declared one,
    # promote the inferred classification to an explicit block so the written
    # file is self-documenting and reloads without W.CONV.TERMINAL_ROLES_INFERRED.
    out["terminal_conventions"] = _terminal_conventions_dict(net)
    out["meta"] = out_meta
    if isnothing(indent)
        JSON3.write(io, out)
        write(io, '\n')
    else
        JSON3.pretty(io, out, JSON3.AlignmentContext(; indent=UInt16(indent)))
    end
end

function write_bmopf(net::Dict{String,Any}, path::AbstractString;
                     meta::Union{Dict,Nothing}=nothing,
                     indent::Union{Int,Nothing}=2,
                     include_coordinates::Bool=true)
    open(path, "w") do io
        write_bmopf(net, io; meta, indent, include_coordinates)
    end
end

# ---------------------------------------------------------------------------
# Internal: drop tool-derived bus fields that are not part of the spec
# ---------------------------------------------------------------------------

"""
    _DERIVED_BUS_FIELDS

Known non-spec bus fields excluded by core schema validation. Bus objects
declare `additionalProperties: false` in the BMOPF schema. The writer always
omits `neutral_terminal`, but preserves coordinates unless explicitly disabled.

Their persistence and recovery differ:

- `neutral_terminal` — *derived*. Recomputed from `terminal_names` on read (see
  `_neutral_terminal`), so dropping it loses nothing.
- `longitude`, `latitude` — *sideloaded*. Attached by [`sideload_coordinates!`](@ref)
  or supplied in input JSON. Preserved by default; omission is lossy because
  they cannot be recomputed from the electrical model.

See [`_strip_derived_bus_fields`](@ref), shared by writing and schema validation.
"""
const _DERIVED_BUS_FIELDS = ("neutral_terminal", "longitude", "latitude")

"""
    _strip_derived_bus_fields(buses; include_coordinates=false) -> Dict{String,Any}

Return a shallow copy of the bus collection without the derived neutral field.
With `include_coordinates=false` (the schema-validation default), also remove
bus longitude/latitude. The writer passes its explicit coordinate policy.

Does not mutate the input: the caller's in-memory network keeps its coordinates
and neutral terminals. Buses carrying none of these fields are passed through by
reference rather than copied.

Omitting coordinates is lossy — see [`_DERIVED_BUS_FIELDS`](@ref).
"""
function _strip_derived_bus_fields(buses::Dict; include_coordinates::Bool=false)::Dict{String,Any}
    fields = include_coordinates ? ("neutral_terminal",) : _DERIVED_BUS_FIELDS
    out = Dict{String,Any}()
    for (id, bus) in buses
        if bus isa Dict && any(haskey(bus, k) for k in fields)
            out[id] = Dict{String,Any}(k => v for (k, v) in bus
                                       if k ∉ fields)
        else
            out[id] = bus
        end
    end
    out
end

# ---------------------------------------------------------------------------
# Internal: assemble the meta block
# ---------------------------------------------------------------------------

"""
    _build_meta(base, override) -> Dict{String,Any}

Merge `base` (from `net["meta"]`) and `override` (from the `meta` kwarg),
then fill in auto-generated defaults for `\$schema`, `case_study_generator`, and `created`
if those keys are not already present. Never overwrites a value the caller set.

The auto-generated fields are:

- `\$schema` — URI of the BMOPF schema this file claims to conform to.
- `case_study_generator` — tool name and version stamp.
- `created` — wall-clock time of the write as an ISO-8601 UTC timestamp
  (`yyyy-mm-ddTHH:MM:SSZ`). Always UTC, never local time, so stamps from
  different machines are directly comparable. Note this makes `write_bmopf`
  non-deterministic: writing the same network twice yields files differing in
  this field. Pass `meta = Dict("created" => …)` to pin it, e.g. for byte-exact
  round-trip tests.
"""
function _build_meta(base::Dict,
                     override::Union{Dict,Nothing})::Dict{String,Any}
    m = Dict{String,Any}()
    for (k, v) in base;     m[k] = v; end
    if !isnothing(override)
        for (k, v) in override; m[k] = v; end
    end

    get!(m, "\$schema", _BMOPF_SCHEMA_URI)
    get!(m, "case_study_generator", Dict{String,Any}(
        "tool"    => "BMOPFTools.jl",
        "version" => _BMOPFTOOLS_VERSION,
    ))
    get!(m, "created", Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"))
    m
end
