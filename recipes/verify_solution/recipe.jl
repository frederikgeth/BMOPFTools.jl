using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
fixture = joinpath(root, "test", "fixtures", "negative",
                   "claimed-feasible-invalid-solution")
case_path = joinpath(fixture, "network.json")
result_path = joinpath(fixture, "claimed-solved-result.json")
inputs = [
    Dict{String,Any}(
        "role" => "case",
        "path" => relpath(case_path, root),
        "sha256" => bytes2hex(sha256(read(case_path))),
    ),
    Dict{String,Any}(
        "role" => "result",
        "path" => relpath(result_path, root),
        "sha256" => bytes2hex(sha256(read(result_path))),
    ),
]

response = execute_solution_verification(
    parse_bmopf(case_path), read_result(result_path); inputs=inputs)
response["status"] == "completed" || error("solution verification did not complete")
response["result"]["result_meta"]["termination_status"] == "LOCALLY_SOLVED" ||
    error("fixture no longer carries its claimed-feasible solver status")

observed = Set(String(finding["code"]) for finding in response["result"]["findings"])
"E.SOL.VOLT_VIOLATION" in observed || error(
    "solution verification omitted E.SOL.VOLT_VIOLATION")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
