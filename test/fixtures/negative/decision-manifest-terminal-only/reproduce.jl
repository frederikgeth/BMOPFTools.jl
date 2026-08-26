using BMOPFTools
using JSON3

manifest = JSON3.read(
    read(joinpath(@__DIR__, "transformed.json"), String),
    Dict{String,Any},
)
result = check_decision_preservation_manifest(manifest)
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
