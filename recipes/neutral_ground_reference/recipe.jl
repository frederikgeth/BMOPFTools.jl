using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
fixture = joinpath(root, "test", "fixtures", "negative",
                   "neutral-ground-reference-conflation")
source_path = joinpath(fixture, "source.json")
target_path = joinpath(fixture, "transformed.json")

inputs = [
    Dict{String,Any}(
        "role" => "source",
        "path" => relpath(source_path, root),
        "sha256" => bytes2hex(sha256(read(source_path))),
    ),
    Dict{String,Any}(
        "role" => "target",
        "path" => relpath(target_path, root),
        "sha256" => bytes2hex(sha256(read(target_path))),
    ),
]

response = execute_contract(
    "neutral_ground_reference_preservation",
    parse_bmopf(source_path),
    parse_bmopf(target_path);
    parameters=Dict{String,Any}(
        "bus_mapping" => Dict("source" => "source", "load" => "load"),
    ),
    inputs=inputs,
)

@assert response["status"] == "failed"
expected_codes = Set([
    "E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH",
    "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH",
])
@assert Set(finding["code"] for finding in response["result"]["findings"]) ==
        expected_codes

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
