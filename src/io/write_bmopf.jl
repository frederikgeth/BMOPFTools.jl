"""
    write_bmopf(net::Dict{String,Any}, dest; meta=nothing)

Serialise a BMOPF network dict to JSON.

- `dest::IO`             — writes to the IO stream
- `dest::AbstractString` — writes to a file at that path

A `meta` block is always written. Fields are assembled in this priority order
(highest wins): the `meta` keyword argument → `net["meta"]` → auto-generated
defaults (`\$schema`, `generator`, `created`). Caller-supplied values are never
overwritten by auto-generation.

# Keyword argument
- `meta`: a `Dict` of fields to include or override in the written `meta` block.
  All fields are optional; common ones are `title`, `description`, `license`,
  `authors`, `sources`, and `version`. See `docs/src/conventions.md` for the
  full field reference.

# Example
```julia
write_bmopf(net, "output.json";
    meta = Dict(
        "title"   => "LV network 1, Feeder 1",
        "license" => "https://creativecommons.org/licenses/by/4.0/",
        "authors" => [Dict("name" => "Frederik Geth", "orcid" => "0000-0001-9534-2265")],
        "sources" => [Dict("name" => "ENWL dataset", "format" => "OpenDSS",
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
    out["meta"] = out_meta
    if isnothing(indent)
        JSON3.write(io, out)
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
# Internal: assemble the meta block
# ---------------------------------------------------------------------------

"""
    _build_meta(base, override) -> Dict{String,Any}

Merge `base` (from `net["meta"]`) and `override` (from the `meta` kwarg),
then fill in auto-generated defaults for `\$schema`, `generator`, and `created`
if those keys are not already present. Never overwrites a value the caller set.
"""
function _build_meta(base::Dict,
                     override::Union{Dict,Nothing})::Dict{String,Any}
    m = Dict{String,Any}()
    for (k, v) in base;     m[k] = v; end
    if !isnothing(override)
        for (k, v) in override; m[k] = v; end
    end

    get!(m, "\$schema", _BMOPF_SCHEMA_URI)
    get!(m, "generator", Dict{String,Any}(
        "tool"    => "BMOPFTools.jl",
        "version" => _BMOPFTOOLS_VERSION,
    ))
    get!(m, "created", Dates.format(now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"))
    m
end
