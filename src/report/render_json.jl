# report/render_json.jl

"""
    render_json(report, io)

Write a machine-readable JSON serialization of a [`SummaryReport`](@ref) to `io`.

Unlike [`render_markdown`](@ref) (human-facing prose) this emits the structured
analysis verbatim: every section result dict under `results`, plus the complete
finding log as an array of records. The `results` keys are stable across
versions, so downstream consumers (e.g. dataset feature-tagging) can read the
numbers directly instead of parsing Markdown.

Shape:

```json
{
  "network_name": "...",
  "generated_at": "yyyy-mm-ddTHH:MM:SS",
  "summary": {"errors": N, "warnings": N, "info": N},
  "results": { "<section>": { ... } , ... },
  "findings": [
    {"severity": "INFO"|"WARNING"|"ERROR", "code": "...", "section": "...",
     "component_type": "...", "component_id": "..."|null, "message": "...",
     "detail": {...}|null},
    ...
  ]
}
```
"""
function render_json(report::SummaryReport, io::IO)
    # Strict, portable JSON: non-finite floats are sanitized to null in _jsonable
    # (below), so no JSON5 Infinity/NaN tokens are ever emitted — the output parses
    # in any language's standard JSON reader.
    JSON3.pretty(io, _report_to_json(report), JSON3.AlignmentContext(; indent=UInt16(2)))
end

function _report_to_json(report::SummaryReport)
    Dict{String,Any}(
        "network_name" => report.network_name,
        "generated_at" => Dates.format(report.generated_at, "yyyy-mm-ddTHH:MM:SS"),
        "summary" => Dict{String,Any}(
            "errors"   => length(errors(report)),
            "warnings" => length(warnings(report)),
            "info"     => length(infos(report)),
        ),
        "results"  => _jsonable(report.results),
        "findings" => [_finding_to_json(f) for f in report.findings],
    )
end

_finding_to_json(f::Finding) = Dict{String,Any}(
    "severity"       => string(f.severity),
    "code"           => f.code,
    "section"        => string(f.section),
    "component_type" => string(f.component_type),
    "component_id"   => f.component_id,
    "message"        => f.message,
    "detail"         => f.detail === nothing ? nothing : _jsonable(f.detail),
)

# Recursively coerce analysis values into JSON-native types. Result dicts hold
# arbitrary Julia values (Symbols, Chars, Sets, Tuples) that JSON3 would either
# reject or render inconsistently; normalise them here.
_jsonable(x::AbstractDict) = Dict{String,Any}(string(k) => _jsonable(v) for (k, v) in x)
_jsonable(x::Union{AbstractVector,AbstractSet,Tuple}) = [_jsonable(v) for v in x]
_jsonable(x::Symbol) = string(x)
_jsonable(x::AbstractChar) = string(x)
_jsonable(x::AbstractString) = String(x)
# Non-finite floats (Inf/NaN, e.g. an ungrounded star-point resistance) → null,
# so the emitted JSON stays strict and portable.
_jsonable(x::AbstractFloat) = isfinite(x) ? x : nothing
_jsonable(x::Union{Integer,Bool,Nothing}) = x
_jsonable(x) = string(x)
