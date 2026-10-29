# report/finding_registry.jl

include("finding_registry_generated.jl")

struct UnknownFindingCode <: Exception
    code::String
end

Base.showerror(io::IO, error::UnknownFindingCode) = print(
    io,
    "unknown or undocumented Finding code '", error.code,
    "'; BMOPFTools-authored codes must be catalogued in docs/src/findings.md, " *
    "while external PowerIO conversion codes use PowerIO's catalogues",
)

"""
    explain_finding(code) -> Dict{String,Any}
    explain_finding(finding::Finding) -> Dict{String,Any}

Return the checked offline catalogue entry for one stable BMOPFTools Finding
code. The explanation records severity, namespace, catalogue section, canonical
meaning, documentation provenance, and any existing executable-contract and scientific-reference
links. It does not infer a cause, recommend an automatic repair, or inspect a
case-specific Finding instance.

With a `Finding`, also return its serialized `instance` and any recorded
`interpretation`: observations, possible explanations, supporting context,
alternatives, suggested checks and automation guidance. Missing interpretation
is `nothing`; this method does not invent context or infer a repair. Returned
instance data are detached from the original Finding. The code-only lookup
and its CLI/MCP response keep their existing shape.

Codes authored by external conversion pipelines (for example `EMIT.*` or
`READ.*`) are intentionally outside this registry and raise
`UnknownFindingCode` rather than receiving a guessed explanation.
"""
function explain_finding(code::AbstractString)::Dict{String,Any}
    normalized = String(code)
    isempty(normalized) && throw(ArgumentError("Finding code must be nonempty"))
    entry = get(_FINDING_EXPLANATIONS, normalized, nothing)
    entry === nothing && throw(UnknownFindingCode(normalized))
    Dict{String,Any}(
        "code" => normalized,
        "severity" => entry.severity,
        "namespace" => entry.namespace,
        "catalogue_section" => entry.catalogue_section,
        "section_title" => entry.section_title,
        "meaning" => entry.meaning,
        "contract_id" => entry.contract_id,
        "knowledge_ids" => copy(entry.knowledge_ids),
        "documentation" => Dict{String,Any}(
            "path" => _FINDING_REGISTRY_SOURCE_PATH,
            "sha256" => _FINDING_REGISTRY_SOURCE_SHA256,
        ),
        "registry" => Dict{String,Any}(
            "id" => _FINDING_REGISTRY_ID,
            "schema_version" => _FINDING_REGISTRY_SCHEMA_VERSION,
        ),
    )
end

function explain_finding(finding::Finding)::Dict{String,Any}
    result = explain_finding(finding.code)
    result["instance"] = deepcopy(_finding_to_json(finding))
    detail = something(finding.detail, Dict{String,Any}())
    result["interpretation"] = _jsonable(get(detail, "interpretation", nothing))
    result
end
