using BMOPFTools
using JSON3

fixture = @__DIR__
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))
result = check_transformer_tap_domain_preservation(
    source, target; source_subtype="single_phase", source_id="tx")
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
