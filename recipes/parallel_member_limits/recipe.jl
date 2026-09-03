using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
fixture = joinpath(root, "test", "fixtures", "negative",
                   "parallel-rating-outer-relaxation")
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
    "parallel_member_limit_preservation",
    parse_bmopf(source_path),
    parse_bmopf(target_path);
    parameters=Dict{String,Any}(
        "member_ids" => ["l1", "l2"],
        "aggregate_id" => "leq",
    ),
    inputs=inputs,
)

@assert response["status"] == "failed"
@assert any(finding -> finding["code"] ==
    "W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS", response["result"]["findings"])

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
