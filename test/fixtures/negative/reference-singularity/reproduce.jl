using BMOPFTools
using JSON3

fixture = @__DIR__
load(name) = JSON3.read(read(joinpath(fixture, name), String), Dict{String,Any})
result = check_reference_singularity(
    load("source.json"), load("target.json");
    source_model_id="referenced-source", target_model_id="floating-target")
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
