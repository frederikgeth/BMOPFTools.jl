# io/powerio_findings.jl
#
# PowerIO conversion diagnostics → BMOPFTools `Finding`s.
#
# `from_dss` and `to_dss` each hand a network across the PowerIO boundary and
# get back a list of everything the conversion could not carry. Those arrive as
# powerio diagnostics; this is where they become the same `Finding` records
# every analysis and validation pass in this package produces, so a fidelity
# loss reads the same way as a data quality problem found in the dict.

# powerio's severity ladder (powerio-diag) onto this package's three levels.
# `note` and `remark` are the current vocabulary (`note` adds context, `remark`
# reports a successful operation); `debug`, `info`, and `fatal` are the
# pre-0.10 spellings, kept so a diagnostic built against either vocabulary maps
# the same way.
const _POWERIO_SEVERITY = Dict{String,Severity}(
    "note"    => INFO,
    "debug"   => INFO,
    "remark"  => INFO,
    "info"    => INFO,
    "warning" => WARNING,
    "error"   => ERROR,
    "fatal"   => ERROR,
)

# Severity for a diagnostic that carries none. PowerIO.jl reports a handle's
# retained findings as `CODE: message` lines alone, and only the conversion
# entry points carry the record behind the line, so a line-only diagnostic has
# no severity to read and is taken as a fidelity loss.
const _POWERIO_SEVERITY_DEFAULT = WARNING

# Severity name → value, for reading back the records written into `_meta`.
const _SEVERITY_BY_NAME = Dict(string(s) => s for s in (ERROR, WARNING, INFO))

# A powerio diagnostic code: `NAMESPACE.SCOPE.SPECIFIC`, uppercase, no colon.
# Used to decide whether a line's prefix really is a code before splitting it
# off, so an uncoded line keeps its whole text as the message.
const _POWERIO_CODE_RE = r"^[A-Z][A-Z0-9_]*(\.[A-Z][A-Z0-9_]*)+$"

# Code for a diagnostic that arrived without one of its own. Nothing powerio
# 0.9 emits takes this path.
const _POWERIO_UNCODED = "W.PROV.POWERIO_UNCODED"

# Collections a powerio element path can name. `transformer` is here even
# though it is not a component collection (it is subtype-keyed) because the
# writer's transformer diagnostics are the ones that carry a path at all.
const _POWERIO_ELEMENT_CLASSES = Set{String}((COMPONENT_COLLECTIONS...,
    "transformer", "linecode", "wire_data", "line_geometry", "time_series"))

"""
    _split_powerio_line(line) -> (code, message)

Split a powerio diagnostic line at the first `": "`. The code matches
`NAMESPACE.SCOPE.SPECIFIC` and carries no colon of its own, so the first
separator is the right one. A line whose prefix is not a code keeps its whole
text as the message and reports an empty code.
"""
function _split_powerio_line(line::AbstractString)::Tuple{String,String}
    r = findfirst(": ", line)
    r === nothing && return ("", String(line))
    code = String(line[1:prevind(line, first(r))])
    occursin(_POWERIO_CODE_RE, code) || return ("", String(line))
    return (code, String(line[nextind(line, last(r)):end]))
end

"""
    _powerio_element(path, fold_ids) -> (component_type, component_id)

Resolve a powerio diagnostic `target` to a component this package can address. The
writer spells its paths `"<class> <name>"` (`"transformer reg1"`); the reader
spells its own as JSON pointers, which name a field rather than a component and
so resolve to the network. `fold_ids` lower-cases the name for the `from_dss`
direction, where every identifier was case folded on ingest.
"""
function _powerio_element(path, fold_ids::Bool)::Tuple{Symbol,Union{String,Nothing}}
    path isa AbstractString || return (:network, nothing)
    parts = split(String(path), ' '; limit=2)
    length(parts) == 2 || return (:network, nothing)
    class, name = String(parts[1]), String(parts[2])
    (class in _POWERIO_ELEMENT_CLASSES && !isempty(name)) || return (:network, nothing)
    return (Symbol(class), fold_ids ? lowercase(name) : name)
end

# One diagnostic, normalised to the fields this package reads. Handles both
# shapes PowerIO.jl returns: a `Diagnostic`, whose `target` names the element
# it is about, and a bare line, which carries a code and a message and
# nothing else. `stage` is a pre-0.10 field kept for a caller that still
# builds diagnostic stand-ins with one; PowerIO.jl's own `Diagnostic` has no
# such field, so a real diagnostic always reads it as `nothing`.
function _powerio_fields(d)
    hasproperty(d, :code) || return (_split_powerio_line(String(d))...,
                                     nothing, nothing, nothing)
    # `hasproperty` only says the field exists — a `Diagnostic`'s `target` is
    # `Union{Nothing,String}` and declares the property on every instance, so
    # an absent value must be read past `hasproperty` and back off `nothing`.
    function prop(name)
        hasproperty(d, name) || return nothing
        v = getproperty(d, name)
        v === nothing ? nothing : String(v)
    end
    return (String(d.code), something(prop(:message), ""),
            prop(:severity), prop(:target), prop(:stage))
end

# Render one diagnostic as the `"CODE: message"` line this package's own
# `_meta["powerio_warnings"]` and the `to_dss`/`from_dss` two-element returns
# document and carry. Built from `code` and `message` directly rather than
# `string(d)`/`sprint(show, d)`: PowerIO.jl's `Base.show` for `Diagnostic`
# prepends the severity and appends the target, a different line.
_powerio_render_line(d) = hasproperty(d, :code) ? string(d.code, ": ", d.message) : String(d)

"""
    _powerio_diagnostic_records(diagnostics; fold_ids=false) -> Vector{Dict{String,Any}}

Fold a conversion's diagnostics into one JSON-serialisable record per
`(code, severity)` class, ordered by code. The powerio code is kept verbatim.

Grouping is not cosmetic: a large feeder produces one `EMIT.BMOPF.FIELD_DROPPED`
per dropped field per element, which reaches five figures on the bigger ENWL
networks. Ungrouped, that list is both the whole report and most of the written
document. Each record keeps its count, every element path in the class, and a
few example messages, so nothing needed to identify what was lost is dropped.
"""
function _powerio_diagnostic_records(diagnostics;
                                     fold_ids::Bool=false)::Vector{Dict{String,Any}}
    isempty(diagnostics) && return Dict{String,Any}[]

    order    = Tuple{String,String}[]
    grouped  = Dict{Tuple{String,String},Dict{String,Any}}()
    for d in diagnostics
        code, msg, sev, path, stage = _powerio_fields(d)
        isempty(code) && (code = _POWERIO_UNCODED)
        sev_str = sev === nothing ? "" : sev
        key = (code, sev_str)
        if !haskey(grouped, key)
            push!(order, key)
            grouped[key] = Dict{String,Any}(
                "code"     => code,
                "severity" => string(get(_POWERIO_SEVERITY, sev_str,
                                         _POWERIO_SEVERITY_DEFAULT)),
                "count"    => 0,
                "messages" => String[],
                "elements" => String[],
            )
        end
        g = grouped[key]
        g["count"] += 1
        length(g["messages"]) < 5 && msg ∉ g["messages"] && push!(g["messages"], msg)
        if path !== nothing
            path ∉ g["elements"] && push!(g["elements"], path)
            ct, cid = _powerio_element(path, fold_ids)
            if cid !== nothing
                g["component_type"] = string(ct)
                # An id only identifies the finding while the class holds one
                # element; past that the elements list is the identification.
                g["component_id"] = get(g, "component_id", cid) == cid ? cid : nothing
            end
        end
        stage === nothing || (g["stage"] = stage)
    end

    records = Dict{String,Any}[]
    for key in sort!(order)
        g = grouped[key]
        get(g, "component_id", missing) === nothing && delete!(g, "component_id")
        isempty(g["elements"]) && delete!(g, "elements")
        n, msgs = g["count"], g["messages"]
        g["message"] = n == 1 ? first(msgs) :
                       "$n occurrences, e.g. $(first(msgs))"
        n == 1 && delete!(g, "messages")
        push!(records, g)
    end
    return records
end

"""
    powerio_findings(net::Dict{String,Any}; section=:provenance) -> Vector{Finding}
    powerio_findings(records::AbstractVector; section=:provenance) -> Vector{Finding}

The PowerIO conversion diagnostics of a network as [`Finding`](@ref)s: one per
diagnostic class, carrying powerio's own code verbatim, its message, and its
severity mapped onto this package's three levels.

For a network, the records read come from `_meta["powerio_diagnostics"]`, which
[`from_dss`](@ref) writes at ingest and which survives a `write_bmopf` /
`parse_bmopf` round trip under `meta.provenance`. A network that never crossed
the PowerIO boundary yields nothing. [`analyze`](@ref) calls this, so the
findings are already in the [`SummaryReport`](@ref); call it directly to read
them off a network without running the analysis passes.

A powerio diagnostic that carries no severity of its own — the `CODE: message`
lines a handle retains, as opposed to the records the conversion entry points
return — is taken as a `WARNING`.
"""
function powerio_findings(net::Dict{String,Any};
                          section::Symbol=:provenance)::Vector{Finding}
    records = get(get(net, "_meta", Dict{String,Any}()), "powerio_diagnostics", nothing)
    records isa AbstractVector || return Finding[]
    return powerio_findings(records; section=section)
end

function powerio_findings(records::AbstractVector;
                          section::Symbol=:provenance)::Vector{Finding}
    findings = Finding[]
    for r in records
        r isa AbstractDict || continue
        sev = get(_SEVERITY_BY_NAME, String(get(r, "severity", "WARNING")),
                  _POWERIO_SEVERITY_DEFAULT)
        ctype = Symbol(get(r, "component_type", "network"))
        cid   = get(r, "component_id", nothing)
        detail = Dict{String,Any}(k => v for (k, v) in r
                                  if k ∉ ("code", "severity", "message",
                                          "component_type", "component_id"))
        push!(findings, Finding(sev, String(get(r, "code", _POWERIO_UNCODED)),
                                section, ctype,
                                cid isa AbstractString ? String(cid) : nothing,
                                String(get(r, "message", "")),
                                isempty(detail) ? nothing : detail))
    end
    return findings
end
