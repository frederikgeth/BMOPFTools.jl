using BMOPFTools
using JSON3

fixture = @__DIR__
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))
result = check_kron_boundary_recovery(
    source,
    target;
    source_line_id="l4",
    target_line_id="l3",
    bus_mapping=Dict("src" => "src", "load" => "load"),
    recovery_map=Dict(
        "eliminated_terminal" => "n",
        "voltage_constraint" => "V_n = 0 at both endpoints",
        "current_recovery" => "recover I_n from the retained phase voltages and source Z",
    ),
)
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
