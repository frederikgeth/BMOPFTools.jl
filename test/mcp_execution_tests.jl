using JSON3
using JSONSchema

@testset "MCP execution adapter" begin
    root = normpath(joinpath(@__DIR__, ".."))
    mcp = Module(:BMOPFMCPExecutionTest)
    Base.include(mcp, joinpath(root, "scripts", "bmopf_mcp.jl"))

    schema = JSONSchema.Schema(JSON3.read(
        read(joinpath(root, "schemas", "execution-response.schema.json"), String)))
    request(id, method, params=Dict{String,Any}()) = Dict{String,Any}(
        "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params)
    tool_call(id, name, arguments) = request(id, "tools/call", Dict{String,Any}(
        "name" => name, "arguments" => arguments))

    withenv("BMOPFTOOLS_MCP_ALLOWED_ROOTS" => root) do
        initialized = mcp.mcp_handle_request(request(
            1, "initialize", Dict("protocolVersion" => "2025-11-25")))
        @test initialized["result"]["protocolVersion"] == "2025-11-25"
        @test initialized["result"]["serverInfo"]["name"] == "bmopftools"
        @test initialized["result"]["capabilities"]["tools"]["listChanged"] === false

        tools = mcp.mcp_handle_request(request(2, "tools/list"))
        @test Set(tool["name"] for tool in tools["result"]["tools"]) == Set([
            "bmopf_parse",
            "bmopf_analyze",
            "bmopf_verify_solution",
            "bmopf_explain_finding",
            "bmopf_check_parallel_member_limits",
            "bmopf_check_neutral_ground_reference",
        ])
        @test all(tool -> tool["inputSchema"]["additionalProperties"] === false,
                  tools["result"]["tools"])

        resources = mcp.mcp_handle_request(request(3, "resources/list"))
        @test Set(resource["uri"] for resource in resources["result"]["resources"]) == Set([
            "bmopf://execution/manifest",
            "bmopf://execution/response-schema",
        ])
        manifest = mcp.mcp_handle_request(request(
            4, "resources/read", Dict("uri" => "bmopf://execution/manifest")))
        manifest_payload = JSON3.read(only(manifest["result"]["contents"])["text"])
        @test manifest_payload.schema_version == "0.5.0"
        @test manifest_payload.record_counts.recipe == 6

        parse_path = joinpath(root, "recipes", "parse_case", "input.json")
        parsed = mcp.mcp_handle_request(tool_call(
            5, "bmopf_parse", Dict("path" => parse_path)))
        parse_payload = parsed["result"]["structuredContent"]
        @test parse_payload["operation"] == "parse_case"
        @test parse_payload["status"] == "completed"
        @test parse_payload["result"]["component_counts"]["load"] == 1
        @test JSONSchema.validate(schema, JSON3.read(JSON3.write(parse_payload))) === nothing

        analysis_path = joinpath(root, "examples", "lv1_14bus.json")
        analyzed = mcp.mcp_handle_request(tool_call(
            6, "bmopf_analyze", Dict("path" => analysis_path)))
        analysis_payload = analyzed["result"]["structuredContent"]
        @test analysis_payload["operation"] == "analyze_case"
        @test analysis_payload["status"] == "completed"
        @test !isempty(analysis_payload["result"]["findings"])
        @test JSONSchema.validate(schema, JSON3.read(JSON3.write(analysis_payload))) === nothing

        solution_root = joinpath(root, "test", "fixtures", "negative",
                                 "claimed-feasible-invalid-solution")
        verified = mcp.mcp_handle_request(tool_call(
            7,
            "bmopf_verify_solution",
            Dict(
                "case_path" => joinpath(solution_root, "network.json"),
                "result_path" => joinpath(solution_root, "claimed-solved-result.json"),
            ),
        ))
        verification_payload = verified["result"]["structuredContent"]
        @test verification_payload["operation"] == "verify_solution"
        @test verification_payload["result"]["summary"]["errors"] == 1
        @test JSONSchema.validate(schema,
            JSON3.read(JSON3.write(verification_payload))) === nothing

        parallel_root = joinpath(root, "test", "fixtures", "negative",
                                 "parallel-rating-outer-relaxation")
        parallel = mcp.mcp_handle_request(tool_call(
            8,
            "bmopf_check_parallel_member_limits",
            Dict(
                "source_path" => joinpath(parallel_root, "source.json"),
                "target_path" => joinpath(parallel_root, "transformed.json"),
                "member_ids" => ["l1", "l2"],
                "aggregate_id" => "leq",
            ),
        ))
        parallel_payload = parallel["result"]["structuredContent"]
        @test parallel_payload["operation"] == "check_contract"
        @test parallel_payload["status"] == "failed"
        @test parallel_payload["request"]["contract_id"] ==
              "parallel_member_limit_preservation"
        @test JSONSchema.validate(schema, JSON3.read(JSON3.write(parallel_payload))) === nothing

        neutral_root = joinpath(root, "test", "fixtures", "negative",
                                "neutral-ground-reference-conflation")
        neutral = mcp.mcp_handle_request(tool_call(
            9,
            "bmopf_check_neutral_ground_reference",
            Dict(
                "source_path" => joinpath(neutral_root, "source.json"),
                "target_path" => joinpath(neutral_root, "transformed.json"),
                "bus_mapping" => Dict("source" => "source", "load" => "load"),
            ),
        ))
        neutral_payload = neutral["result"]["structuredContent"]
        @test neutral_payload["operation"] == "check_contract"
        @test neutral_payload["status"] == "failed"
        @test neutral_payload["request"]["contract_id"] ==
              "neutral_ground_reference_preservation"
        @test JSONSchema.validate(schema, JSON3.read(JSON3.write(neutral_payload))) === nothing

        explained = mcp.mcp_handle_request(tool_call(
            10, "bmopf_explain_finding", Dict("code" => "E.SOL.VOLT_VIOLATION")))
        explanation_payload = explained["result"]["structuredContent"]
        @test explanation_payload["operation"] == "explain_finding"
        @test explanation_payload["result"]["code"] == "E.SOL.VOLT_VIOLATION"
        @test JSONSchema.validate(schema,
            JSON3.read(JSON3.write(explanation_payload))) === nothing

        unknown = mcp.mcp_handle_request(tool_call(
            11, "bmopf_explain_finding", Dict("code" => "EMIT.BMOPF.FIELD_DROPPED")))
        @test unknown["result"]["isError"] === true
        unknown_payload = unknown["result"]["structuredContent"]
        @test unknown_payload["status"] == "error"
        @test unknown_payload["error"]["code"] == "unknown_finding_code"
        @test JSONSchema.validate(schema, JSON3.read(JSON3.write(unknown_payload))) === nothing

        outside_path, outside_io = mktemp()
        try
            write(outside_io, "{}")
            close(outside_io)
            outside = mcp.mcp_handle_request(tool_call(
                12, "bmopf_parse", Dict("path" => outside_path)))
            @test outside["result"]["isError"] === true
            @test outside["result"]["structuredContent"]["status"] == "error"
            @test occursin("outside BMOPFTOOLS_MCP_ALLOWED_ROOTS",
                outside["result"]["structuredContent"]["error"]["message"])
        finally
            isopen(outside_io) && close(outside_io)
            rm(outside_path; force=true)
        end

        unknown_tool = mcp.mcp_handle_request(tool_call(13, "bmopf_solve", Dict()))
        @test unknown_tool["error"]["code"] == -32602

        messages = [
            request(14, "initialize", Dict("protocolVersion" => "2025-11-25")),
            request(15, "tools/list"),
            tool_call(16, "bmopf_parse", Dict("path" => parse_path)),
        ]
        input = IOBuffer(join(JSON3.write.(messages), "\n") * "\n")
        output = IOBuffer()
        @test mcp.main(; input=input, output=output) == 0
        responses = JSON3.read.(filter(!isempty, split(String(take!(output)), '\n')))
        @test length(responses) == 3
        @test responses[3].result.structuredContent.operation == "parse_case"
    end

    @test isfile(joinpath(root, "bin", "bmopf-mcp"))
    @test (uperm(joinpath(root, "bin", "bmopf-mcp")) & 0o1) == 0o1
end
