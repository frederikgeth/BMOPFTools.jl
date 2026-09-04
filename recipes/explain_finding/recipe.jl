using BMOPFTools
using JSON3

response = execute_finding_explanation("E.SOL.VOLT_VIOLATION")
response["status"] == "completed" || error("Finding explanation did not complete")
response["result"]["code"] == "E.SOL.VOLT_VIOLATION" || error(
    "Finding explanation returned a different code")
response["result"]["severity"] == "ERROR" || error(
    "Finding explanation returned an unexpected severity")
response["result"]["contract_id"] === nothing || error(
    "ordinary solution Finding unexpectedly claimed a scientific contract")
isempty(response["result"]["knowledge_ids"]) || error(
    "ordinary solution Finding unexpectedly claimed a PSK identity")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
