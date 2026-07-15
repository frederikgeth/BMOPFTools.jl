"""
    write_bmopf(net::Dict{String,Any}, dest; meta=nothing, indent=2)

Serialise a BMOPF network dict to JSON.

- `dest::IO`             — writes to the IO stream
- `dest::AbstractString` — writes to a file at that path

A `meta` block is always written. Fields are assembled in this priority order
(highest wins): the `meta` keyword argument → `net["meta"]` → auto-generated
defaults (`\$schema`, `case_study_generator`, `created`). Caller-supplied values
are never overwritten by auto-generation.

The input `net` is never mutated. Tool-private state is not serialised verbatim:
the `"_meta"` key is persisted under `meta.provenance`, and non-spec bus fields
(`neutral_terminal`, plus the `longitude`/`latitude` attached by
`sideload_coordinates!`) are stripped so the output satisfies the schema's
`additionalProperties: false` on bus objects. Dropping the coordinates is lossy
by design: they are not recoverable on read.

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
                     indent::Union{Int,Nothing}=2)
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
    buses isa Dict && (out["bus"] = _strip_derived_bus_fields(buses))
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
                     indent::Union{Int,Nothing}=2)
    open(path, "w") do io
        write_bmopf(net, io; meta, indent)
    end
end

# ---------------------------------------------------------------------------
# Internal: drop tool-derived bus fields that are not part of the spec
# ---------------------------------------------------------------------------

"""
    _DERIVED_BUS_FIELDS

Bus fields the tool attaches in memory that must not be serialised: bus objects
declare `additionalProperties: false` in the BMOPF schema, so any of these that
survives a write makes the file schema-invalid and provokes spurious
`I.SCHEMA.UNKNOWN_FIELDS` findings when it is read back.

They are stripped for the same reason but recovered differently:

- `neutral_terminal` — *derived*. Recomputed from `terminal_names` on read (see
  `_neutral_terminal`), so dropping it loses nothing.
- `longitude`, `latitude` — *sideloaded*. Attached by [`sideload_coordinates!`](@ref)
  from an external Buscoords CSV, and **not** recoverable from anything else in
  the file. Dropping them is lossy by design: the BMOPF schema has nowhere to put
  bus coordinates, so they live in memory only and are re-attached from the CSV
  on each load.

See [`_strip_derived_bus_fields`](@ref), which is the only consumer.
"""
const _DERIVED_BUS_FIELDS = ("neutral_terminal", "longitude", "latitude")

"""
    _strip_derived_bus_fields(buses) -> Dict{String,Any}

Return a shallow copy of the bus collection with every field in
[`_DERIVED_BUS_FIELDS`](@ref) removed from each bus object, so the written JSON
satisfies the schema's `additionalProperties: false` on buses.

Does not mutate the input: the caller's in-memory network keeps its coordinates
and neutral terminals. Buses carrying none of these fields are passed through by
reference rather than copied.

Note this is lossy for sideloaded coordinates — see [`_DERIVED_BUS_FIELDS`](@ref)
for which fields are recoverable on read and which are not.
"""
function _strip_derived_bus_fields(buses::Dict)::Dict{String,Any}
    out = Dict{String,Any}()
    for (id, bus) in buses
        if bus isa Dict && any(haskey(bus, k) for k in _DERIVED_BUS_FIELDS)
            out[id] = Dict{String,Any}(k => v for (k, v) in bus
                                       if k ∉ _DERIVED_BUS_FIELDS)
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
