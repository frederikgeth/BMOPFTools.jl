using BMOPFTools
using JSON3

fixture = @__DIR__
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))
result = check_neutral_ground_reference_preservation(
    source, target;
    bus_mapping=Dict("source" => "source", "load" => "load"),
)

JSON3.pretty(stdout, contract_result_to_dict(result))
println()
