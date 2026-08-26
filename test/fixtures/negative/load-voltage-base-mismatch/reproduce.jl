using BMOPFTools
using JSON3

fixture = @__DIR__
network = parse_bmopf(joinpath(fixture, "wrong-base-network.json"))
contract = check_load_voltage_base_consistency(network; load_ids=["delta_zip"])

JSON3.pretty(stdout, contract_result_to_dict(contract))
println()
