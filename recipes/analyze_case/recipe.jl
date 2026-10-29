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

# The curated opt-out suppresses the whole spatial pass even with coordinates.
spatial_path = joinpath(root, "test", "data", "spatial_shared_infrastructure.json")
spatial_case = parse_bmopf(spatial_path)
suppressed = execute_analysis(spatial_case; spatial_enabled=false)
suppressed["request"]["parameters"]["spatial_enabled"] === false || error("opt-out not recorded")
skipped = suppressed["result"]["results"]["connectivity"]["spatial"]
skipped["reason"] == "disabled" && skipped["analysis_performed"] === false || error("spatial analysis was not skipped")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()

# Minimized static diagnostic evidence; this does not build or solve a model.
profile_path = joinpath(root, "test", "data", "profiler_evidence", "two_boundary_chain.json")
profile = execute_analysis(parse_bmopf(profile_path))["result"]["results"]
coverage = profile["operational"]["winding_limit_coverage"]
coverage["n_windings_without_caps"] == 4 || error("rating-only winding gap was missed")
zone = only(filter(z -> z["n_buses"] == 5, profile["operational"]["feeder_length"]))
zone["anchor_extent_m"] == 400.0 && zone["boundary_reach_m"] == 200.0 || error("boundary distance mismatch")
zone["threshold_status"] == "unassessed" || error("multi-boundary threshold policy was inferred")
profile["assessment"]["comprehensive_validation"] === false || error("coverage was promoted to validation")

# Exploratory provenance feedback survives the existing JSON analysis route.
context_path = joinpath(root, "test", "data", "profiler_evidence", "provenance_context.json")
context_response = execute_analysis(parse_bmopf(context_path))
hint = only(filter(f -> f["code"] == "I.PROV.IMPEDANCE_TRANSFORM_KR",
    context_response["result"]["findings"]))
interpretation = hint["detail"]["interpretation"]
interpretation["supporting_context"]["three_wire"]["n_lv_without_neutral_lines"] == 1 ||
    error("LV context was lost in analysis JSON")
haskey(interpretation["alternatives"], "native_three_wire") || error("native three-wire alternative was lost")
interpretation["automation_guidance"]["disposition"] == "review" || error("hint was promoted to an edit")
hint["detail"]["history_verified"] === false || error("hypothesis was promoted to verified history")
