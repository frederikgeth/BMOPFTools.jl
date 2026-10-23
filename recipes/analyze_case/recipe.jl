using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
case_path = joinpath(root, "recipes", "analyze_case", "input.json")
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

# Exercise the nominal coil screen through the same curated analysis operation.
# The fixture is a network plus a supplied result; only the network is used here.
coil_path = joinpath(root, "test", "data", "transformer_loading", "overloaded_coil.json")
coil_case = JSON3.read(read(coil_path, String), Dict{String,Any})["net"]
coil_response = execute_analysis(coil_case)
coil_screen = coil_response["result"]["results"]["preflight"]["transformer_coil_headroom"]
coil_screen["evidence"] == "nominal_demand_estimate" || error("wrong coil evidence kind")
coil_estimate = only(coil_screen["transformers"])
coil_estimate["status"] == "estimated" || error("mapped nominal coil case was unassessed")
coil_estimate["coils"][1]["headroom_VA"] < 0 || error("overloaded nominal coil was missed")
coil_screen["proves_infeasibility"] == false || error("screen was promoted to a certificate")
any(f -> f["code"] == "W.PRE.XFMR_COIL_HEADROOM", coil_response["result"]["findings"]) ||
    error("missing nominal headroom warning")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
