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

Return the checked offline catalogue entry for one stable BMOPFTools Finding
code. The explanation records severity, namespace, catalogue section, canonical
meaning, documentation provenance, and any existing executable-contract/PSK
links. It does not infer a cause, recommend an automatic repair, or inspect a
case-specific Finding instance.

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
