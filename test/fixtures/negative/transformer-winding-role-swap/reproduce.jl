using BMOPFTools
using JSON3

fixture = @__DIR__
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))
result = check_transformer_winding_convention_preservation(
    source,
    target;
    source_subtype="wye_delta",
    source_id="tx",
    target_id="tx_equiv",
    bus_mapping=Dict("primary" => "primary", "secondary" => "secondary"),
)
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
