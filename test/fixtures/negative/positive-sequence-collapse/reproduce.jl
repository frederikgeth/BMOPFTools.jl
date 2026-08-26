using BMOPFTools
using JSON3

fixture = @__DIR__
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "target.json"))
result = check_positive_sequence_collapse(
    source, target;
    source_line_id="l3", target_line_id="l1",
    declarations=Dict(
        "balanced_boundary_data" => false,
        "sequence_compatible_grounding" => true,
        "two_terminal_closure" => true,
        "phase_symmetric_decisions" => true,
        "positive_sequence_observations" => true,
    ),
)
JSON3.pretty(stdout, contract_result_to_dict(result),
             JSON3.AlignmentContext(; indent=UInt16(2)))
println()
