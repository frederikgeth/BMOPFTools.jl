using BMOPFTools
using JSON3

fixture = @__DIR__
network = parse_bmopf(joinpath(fixture, "network.json"))
result = JSON3.read(
    read(joinpath(fixture, "claimed-solved-result.json"), String),
    Dict{String,Any},
)
contract = check_claimed_solution_validity(network, result)

JSON3.pretty(stdout, contract_result_to_dict(contract))
println()
