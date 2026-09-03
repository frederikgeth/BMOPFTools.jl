using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
case_path = joinpath(root, "examples", "lv1_14bus.json")
input = Dict{String,Any}(
    "role" => "case",
    "path" => relpath(case_path, root),
    "sha256" => bytes2hex(sha256(read(case_path))),
)

response = execute_analysis(parse_bmopf(case_path); inputs=[input])
response["status"] == "completed" || error("analysis operation did not complete")

observed = Set(String(finding["code"]) for finding in response["result"]["findings"])
expected = Set([
    "W.CONN.DANGLING",
    "I.PRE.NO_VOLT_BOUNDS",
    "W.CONV.TERMINAL_ROLES_INFERRED",
])
issubset(expected, observed) || error(
    "analysis recipe omitted expected Findings: $(sort!(collect(setdiff(expected, observed))))")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
