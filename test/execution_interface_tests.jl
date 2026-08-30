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
    @test response["schema_version"] == "0.1.0"
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

    refusal = execute_contract(
        "parallel_member_limit_preservation", source, target;
        parameters=Dict("member_ids" => ["l1"], "aggregate_id" => "leq"))
    @test refusal["status"] == "inapplicable"
    @test JSONSchema.validate(schema, JSON3.read(JSON3.write(refusal))) === nothing

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

    malformed_out = IOBuffer()
    malformed_err = IOBuffer()
    malformed_code = cli_module.main(["check-contract"];
        out=malformed_out, err=malformed_err)
    @test malformed_code == 2
    @test JSON3.read(String(take!(malformed_out))).status == "error"
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
end
