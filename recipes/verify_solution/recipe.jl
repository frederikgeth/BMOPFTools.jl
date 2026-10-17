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

# Minimum-PF policy is checked against supplied dispatched P/Q, with no solve.
minpf_case = JSON3.read(read(joinpath(root,"test","data","ibr_minimum_pf","curtailed.json"),String),Dict{String,Any})
minpf_result = Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED",
    "ibr"=>Dict("pv"=>Dict("a"=>Dict("pg"=>400.0,"qg"=>900.0))))
minpf_response = execute_solution_verification(minpf_case,minpf_result)
any(f->f["code"]=="E.SOL.IBR_MINIMUM_PF",minpf_response["result"]["findings"]) ||
    error("minimum-PF verification omitted the curtailed-dispatch violation")
only(minpf_response["result"]["results"]["solution"]["minimum_power_factor"]["coils"])["status"]=="failed" ||
    error("minimum-PF evidence did not record failed compliance")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
