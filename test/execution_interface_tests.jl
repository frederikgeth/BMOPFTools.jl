using JSON3
using JSONSchema
using SHA

@testset "JSON execution interface" begin
    root = normpath(joinpath(@__DIR__, ".."))
    fixture = joinpath(root, "test", "fixtures", "negative",
                       "parallel-rating-outer-relaxation")
    source_path = joinpath(fixture, "source.json")
    target_path = joinpath(fixture, "transformed.json")
    source = parse_bmopf(source_path)
    target = parse_bmopf(target_path)
    inputs = [
        Dict("role" => "source", "path" => "source.json",
             "sha256" => bytes2hex(sha256(read(source_path)))),
        Dict("role" => "target", "path" => "transformed.json",
             "sha256" => bytes2hex(sha256(read(target_path)))),
    ]
    parameters = Dict{String,Any}(
        "member_ids" => ["l1", "l2"],
        "aggregate_id" => "leq",
    )

    response = execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=parameters, inputs=inputs)
    @test response["schema_version"] == "0.2.0"
    @test response["operation"] == "check_contract"
    @test response["status"] == "failed"
    @test response["request"]["parameters"]["member_ids"] == ["l1", "l2"]
    @test response["result"]["knowledge_ids"] == ["PSK-000001"]
    @test response["result"]["status"] == response["status"]
    @test any(finding -> finding["code"] ==
        "W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS",
        response["result"]["findings"])

    schema_path = joinpath(root, "schemas", "execution-response.schema.json")
    schema = JSONSchema.Schema(JSON3.read(read(schema_path, String)))
    @test JSONSchema.validate(schema, JSON3.read(JSON3.write(response))) === nothing

    analysis_path = joinpath(root, "examples", "lv1_14bus.json")
    analysis_input = Dict(
        "role" => "case",
        "path" => "examples/lv1_14bus.json",
        "sha256" => bytes2hex(sha256(read(analysis_path))),
    )
    analysis = execute_analysis(
        parse_bmopf(analysis_path); inputs=[analysis_input])
    @test analysis["operation"] == "analyze_case"
    @test analysis["status"] == "completed"
    @test analysis["request"]["contract_id"] === nothing
    @test analysis["request"]["parameters"] == Dict("t_index" => 1)
    @test analysis["result"]["summary"]["errors"] == 0
    @test Set(finding["code"] for finding in analysis["result"]["findings"]) >= Set([
        "W.CONN.DANGLING",
        "I.PRE.NO_VOLT_BOUNDS",
        "W.CONV.TERMINAL_ROLES_INFERRED",
    ])
    @test JSONSchema.validate(schema, JSON3.read(JSON3.write(analysis))) === nothing
    @test_throws ArgumentError execute_analysis(parse_bmopf(analysis_path); t_index=0)

    refusal = execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=Dict("member_ids" => ["l1"], "aggregate_id" => "leq"))
    @test refusal["status"] == "inapplicable"
    @test JSONSchema.validate(schema, JSON3.read(JSON3.write(refusal))) === nothing

    neutral_fixture = joinpath(root, "test", "fixtures", "negative",
                               "neutral-ground-reference-conflation")
    neutral_source_path = joinpath(neutral_fixture, "source.json")
    neutral_failed_path = joinpath(neutral_fixture, "transformed.json")
    neutral_passed_path = joinpath(neutral_fixture, "exact-target.json")
    neutral_source = parse_bmopf(neutral_source_path)
    neutral_failed_target = parse_bmopf(neutral_failed_path)
    neutral_passed_target = parse_bmopf(neutral_passed_path)
    neutral_parameters = Dict{String,Any}(
        "bus_mapping" => Dict("source" => "source", "load" => "load"),
    )

    neutral_failed = execute_contract(
        "neutral_ground_reference_preservation",
        neutral_source,
        neutral_failed_target;
        parameters=neutral_parameters,
    )
    @test neutral_failed["status"] == "failed"
    @test neutral_failed["result"]["knowledge_ids"] == ["PSK-000002"]
    @test Set(finding["code"] for finding in neutral_failed["result"]["findings"]) == Set([
        "E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH",
        "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH",
    ])
    @test JSONSchema.validate(schema,
        JSON3.read(JSON3.write(neutral_failed))) === nothing

    neutral_passed = execute_contract(
        "neutral_ground_reference_preservation",
        neutral_source,
        neutral_passed_target;
        parameters=neutral_parameters,
    )
    @test neutral_passed["status"] == "passed"
    @test isempty(neutral_passed["result"]["findings"])
    @test JSONSchema.validate(schema,
        JSON3.read(JSON3.write(neutral_passed))) === nothing

    neutral_indeterminate = execute_contract(
        "neutral_ground_reference_preservation",
        neutral_source,
        neutral_passed_target;
        parameters=Dict("bus_mapping" =>
            Dict("source" => "missing", "load" => "load")),
    )
    @test neutral_indeterminate["status"] == "indeterminate"
    @test only(neutral_indeterminate["result"]["findings"])["code"] ==
          "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE"
    @test JSONSchema.validate(schema,
        JSON3.read(JSON3.write(neutral_indeterminate))) === nothing

    error_response = execution_error_response(
        "missing mapping"; contract_id="parallel_member_limit_preservation")
    @test error_response["status"] == "error"
    @test !haskey(error_response, "result")
    @test JSONSchema.validate(schema,
        JSON3.read(JSON3.write(error_response))) === nothing

    @test_throws ArgumentError execute_contract(
        "unknown_contract", source, target; parameters=parameters)
    @test_throws ArgumentError execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=Dict("aggregate_id" => "leq"))
    @test_throws ArgumentError execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=merge(parameters, Dict("invented" => true)))
    @test_throws ArgumentError execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=merge(parameters, Dict("atol" => true)))
    @test_throws ArgumentError execute_contract(
        "neutral_ground_reference_preservation", neutral_source, neutral_passed_target;
        parameters=Dict("bus_mapping" => ["source=source"]))
    @test_throws ArgumentError execute_contract(
        "neutral_ground_reference_preservation", neutral_source, neutral_passed_target;
        parameters=merge(neutral_parameters, Dict("aggregate_id" => "line")))

    cli_module = Module(:BMOPFCLIExecutionTest)
    Base.include(cli_module, joinpath(root, "scripts", "bmopf_cli.jl"))
    out = IOBuffer()
    err = IOBuffer()
    exit_code = cli_module.main([
        "check-contract", "parallel_member_limit_preservation",
        "--source", source_path,
        "--target", target_path,
        "--member-id", "l1",
        "--member-id", "l2",
        "--aggregate-id", "leq",
    ]; out=out, err=err)
    @test exit_code == 0
    @test isempty(String(take!(err)))
    cli_response = JSON3.read(String(take!(out)))
    @test cli_response.status == "failed"
    @test cli_response.inputs[1].sha256 == bytes2hex(sha256(read(source_path)))
    @test JSONSchema.validate(schema, cli_response) === nothing

    analysis_cli_out = IOBuffer()
    analysis_cli_err = IOBuffer()
    analysis_cli_code = cli_module.main([
        "analyze-case", "--input", analysis_path,
    ]; out=analysis_cli_out, err=analysis_cli_err)
    @test analysis_cli_code == 0
    @test isempty(String(take!(analysis_cli_err)))
    analysis_cli_response = JSON3.read(String(take!(analysis_cli_out)))
    @test analysis_cli_response.operation == "analyze_case"
    @test analysis_cli_response.status == "completed"
    @test analysis_cli_response.inputs[1].role == "case"
    @test analysis_cli_response.inputs[1].sha256 == bytes2hex(sha256(read(analysis_path)))
    @test JSONSchema.validate(schema, analysis_cli_response) === nothing

    bad_analysis_out = IOBuffer()
    bad_analysis_err = IOBuffer()
    bad_analysis_code = cli_module.main([
        "analyze-case", "--input", analysis_path, "--time-index", "0",
    ]; out=bad_analysis_out, err=bad_analysis_err)
    @test bad_analysis_code == 2
    bad_analysis_response = JSON3.read(String(take!(bad_analysis_out)))
    @test bad_analysis_response.operation == "analyze_case"
    @test bad_analysis_response.status == "error"
    @test JSONSchema.validate(schema, bad_analysis_response) === nothing

    neutral_cli_out = IOBuffer()
    neutral_cli_err = IOBuffer()
    neutral_cli_code = cli_module.main([
        "check-contract", "neutral_ground_reference_preservation",
        "--source", neutral_source_path,
        "--target", neutral_passed_path,
        "--bus-map", "source=source",
        "--bus-map", "load=load",
    ]; out=neutral_cli_out, err=neutral_cli_err)
    @test neutral_cli_code == 0
    @test isempty(String(take!(neutral_cli_err)))
    neutral_cli_response = JSON3.read(String(take!(neutral_cli_out)))
    @test neutral_cli_response.status == "passed"
    @test neutral_cli_response.request.parameters.bus_mapping.source == "source"
    @test JSONSchema.validate(schema, neutral_cli_response) === nothing

    indeterminate_cli_out = IOBuffer()
    indeterminate_cli_err = IOBuffer()
    indeterminate_cli_code = cli_module.main([
        "check-contract", "neutral_ground_reference_preservation",
        "--source", neutral_source_path,
        "--target", neutral_passed_path,
        "--bus-map", "source=missing",
        "--bus-map", "load=load",
    ]; out=indeterminate_cli_out, err=indeterminate_cli_err)
    @test indeterminate_cli_code == 0
    @test isempty(String(take!(indeterminate_cli_err)))
    indeterminate_cli_response = JSON3.read(String(take!(indeterminate_cli_out)))
    @test indeterminate_cli_response.status == "indeterminate"
    @test JSONSchema.validate(schema, indeterminate_cli_response) === nothing

    malformed_out = IOBuffer()
    malformed_err = IOBuffer()
    malformed_code = cli_module.main(["check-contract"];
        out=malformed_out, err=malformed_err)
    @test malformed_code == 2
    malformed_response = JSON3.read(String(take!(malformed_out)))
    @test malformed_response.status == "error"
    @test JSONSchema.validate(schema, malformed_response) === nothing
    @test occursin("Usage:", String(take!(malformed_err)))

    unsupported_out = IOBuffer()
    unsupported_err = IOBuffer()
    unsupported_code = cli_module.main([
        "check-contract", "unknown_contract",
    ]; out=unsupported_out, err=unsupported_err)
    @test unsupported_code == 2
    unsupported_response = JSON3.read(String(take!(unsupported_out)))
    @test unsupported_response.status == "error"
    @test unsupported_response.error.code == "invalid_request"
    @test occursin("unsupported contract", String(take!(unsupported_err)))

    recipe = joinpath(root, "recipes", "parallel_member_limits", "recipe.jl")
    recipe_output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $recipe`, String)
    recipe_response = JSON3.read(recipe_output)
    @test recipe_response.status == "failed"
    @test JSONSchema.validate(schema, recipe_response) === nothing

    neutral_recipe = joinpath(root, "recipes", "neutral_ground_reference", "recipe.jl")
    neutral_recipe_output = read(
        `$(Base.julia_cmd()) --startup-file=no --project=$root $neutral_recipe`, String)
    neutral_recipe_response = JSON3.read(neutral_recipe_output)
    @test neutral_recipe_response.status == "failed"
    @test Set(String(finding.code) for finding in neutral_recipe_response.result.findings) == Set([
        "E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH",
        "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH",
    ])
    @test JSONSchema.validate(schema, neutral_recipe_response) === nothing

    analysis_recipe = joinpath(root, "recipes", "analyze_case", "recipe.jl")
    analysis_recipe_output = read(
        `$(Base.julia_cmd()) --startup-file=no --project=$root $analysis_recipe`, String)
    analysis_recipe_response = JSON3.read(analysis_recipe_output)
    @test analysis_recipe_response.status == "completed"
    @test analysis_recipe_response.result.summary.errors == 0
    @test JSONSchema.validate(schema, analysis_recipe_response) === nothing
end
