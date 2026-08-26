using BMOPFTools
using JSON3

fixture = @__DIR__
source = JSON3.read(read(joinpath(fixture, "source.json"), String), Dict{String,Any})
target = JSON3.read(read(joinpath(fixture, "target.json"), String), Dict{String,Any})
result = check_state_dependent_equivalent(
    source, target; source_model_id="source-state-dependent",
    target_model_id="target-frozen-base")
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
