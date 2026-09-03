using BMOPFTools
using JSON3
using SHA

root = normpath(joinpath(@__DIR__, "..", ".."))
case_path = joinpath(@__DIR__, "input.json")
input = Dict{String,Any}(
    "role" => "case",
    "path" => relpath(case_path, root),
    "sha256" => bytes2hex(sha256(read(case_path))),
)

net = parse_bmopf(case_path)
response = execute_case_parse(net; inputs=[input])
response["status"] == "completed" || error("parse operation did not complete")

migration_codes = Set(String(note["code"]) for note in response["result"]["migration_notes"])
"W.MIGRATE.LOAD_MODEL_CASE" in migration_codes || error(
    "parse recipe did not expose the expected load-model migration")

# This separate assertion is the misconception guard: the same document parses
# and migrates successfully but remains deliberately incomplete under the JSON
# Schema. The parse response itself does not run or embed this validation.
schema_findings = Finding[]
schema_check(net, schema_findings)
any(finding -> finding.code == "E.SCHEMA.REQUIRED", schema_findings) || error(
    "parse-only boundary fixture unexpectedly passed schema validation")

JSON3.pretty(stdout, response, JSON3.AlignmentContext(; indent=UInt16(2)))
println()
