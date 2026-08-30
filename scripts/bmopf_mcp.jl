#!/usr/bin/env julia

using BMOPFTools
using JSON3
using SHA

const MCP_PROTOCOL_VERSION = "2025-11-25"
const MCP_SUPPORTED_PROTOCOL_VERSIONS = Set([MCP_PROTOCOL_VERSION, "2025-06-18"])
const MCP_SERVER_NAME = "bmopftools"
const MCP_SERVER_VERSION = string(Base.pkgversion(BMOPFTools))
const MCP_ROOT = normpath(joinpath(@__DIR__, ".."))
const MCP_MANIFEST_URI = "bmopf://execution/manifest"
const MCP_RESPONSE_SCHEMA_URI = "bmopf://execution/response-schema"

function mcp_response(request_id, result::AbstractDict)
    Dict{String,Any}("jsonrpc" => "2.0", "id" => request_id, "result" => result)
end

function mcp_error_response(request_id, code::Int, message::AbstractString)
    Dict{String,Any}(
        "jsonrpc" => "2.0",
        "id" => request_id,
        "error" => Dict{String,Any}("code" => code, "message" => String(message)),
    )
end

function mcp_tool_definitions()
    path_property = Dict{String,Any}(
        "type" => "string",
        "minLength" => 1,
        "description" => "Existing local JSON file inside an allowed root.",
    )
    tolerance_properties = Dict{String,Any}(
        "atol" => Dict("type" => "number", "minimum" => 0),
        "rtol" => Dict("type" => "number", "minimum" => 0),
    )
    [
        Dict{String,Any}(
            "name" => "bmopf_parse",
            "description" => "Parse, migrate, normalize, and inventory one BMOPF JSON document. Completion is not validation.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["path"],
                "properties" => Dict("path" => path_property),
            ),
        ),
        Dict{String,Any}(
            "name" => "bmopf_analyze",
            "description" => "Run the complete BMOPFTools validation and analysis battery for one case.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["path"],
                "properties" => Dict(
                    "path" => path_property,
                    "time_index" => Dict("type" => "integer", "minimum" => 1),
                ),
            ),
        ),
        Dict{String,Any}(
            "name" => "bmopf_verify_solution",
            "description" => "Profile a supplied result independently without invoking a solver.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["case_path", "result_path"],
                "properties" => Dict(
                    "case_path" => path_property,
                    "result_path" => path_property,
                    "time_index" => Dict("type" => "integer", "minimum" => 1),
                ),
            ),
        ),
        Dict{String,Any}(
            "name" => "bmopf_explain_finding",
            "description" => "Look up one stable BMOPFTools Finding code offline; this does not diagnose a case or prescribe a repair.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["code"],
                "properties" => Dict(
                    "code" => Dict("type" => "string", "minLength" => 1),
                ),
            ),
        ),
        Dict{String,Any}(
            "name" => "bmopf_check_parallel_member_limits",
            "description" => "Run the reviewed scalar parallel-member-limit preservation contract with explicit member and aggregate IDs.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["source_path", "target_path", "member_ids", "aggregate_id"],
                "properties" => merge(Dict{String,Any}(
                    "source_path" => path_property,
                    "target_path" => path_property,
                    "member_ids" => Dict(
                        "type" => "array", "minItems" => 1, "uniqueItems" => true,
                        "items" => Dict("type" => "string", "minLength" => 1),
                    ),
                    "aggregate_id" => Dict("type" => "string", "minLength" => 1),
                ), tolerance_properties),
            ),
        ),
        Dict{String,Any}(
            "name" => "bmopf_check_neutral_ground_reference",
            "description" => "Run the reviewed neutral, ground, and reference preservation contract with an explicit bus mapping.",
            "inputSchema" => Dict{String,Any}(
                "type" => "object", "additionalProperties" => false,
                "required" => ["source_path", "target_path", "bus_mapping"],
                "properties" => merge(Dict{String,Any}(
                    "source_path" => path_property,
                    "target_path" => path_property,
                    "bus_mapping" => Dict(
                        "type" => "object", "minProperties" => 1,
                        "additionalProperties" => Dict("type" => "string", "minLength" => 1),
                    ),
                ), tolerance_properties),
            ),
        ),
    ]
end

const MCP_TOOL_OPERATIONS = Dict{String,String}(
    "bmopf_parse" => "parse_case",
    "bmopf_analyze" => "analyze_case",
    "bmopf_verify_solution" => "verify_solution",
    "bmopf_explain_finding" => "explain_finding",
    "bmopf_check_parallel_member_limits" => "check_contract",
    "bmopf_check_neutral_ground_reference" => "check_contract",
)

function _mcp_resource(uri::String, name::String, description::String)
    Dict{String,Any}(
        "uri" => uri,
        "name" => name,
        "description" => description,
        "mimeType" => "application/json",
    )
end

function mcp_resources()
    [
        _mcp_resource(
            MCP_MANIFEST_URI,
            "BMOPFTools executable-knowledge manifest",
            "Package identity, record counts, and source hashes for the executable surface.",
        ),
        _mcp_resource(
            MCP_RESPONSE_SCHEMA_URI,
            "BMOPFTools execution-response schema",
            "JSON Schema for every structured MCP tool result.",
        ),
    ]
end

function _mcp_allowed_roots()
    raw = get(ENV, "BMOPFTOOLS_MCP_ALLOWED_ROOTS", "")
    candidates = if isempty(raw)
        [MCP_ROOT]
    else
        split(raw, Sys.iswindows() ? ';' : ':'; keepempty=false)
    end
    roots = String[]
    for candidate in candidates
        path = abspath(candidate)
        isdir(path) || throw(ArgumentError("MCP allowed root is not a directory: $candidate"))
        push!(roots, realpath(path))
    end
    isempty(roots) && throw(ArgumentError("BMOPFTOOLS_MCP_ALLOWED_ROOTS names no directories"))
    unique(roots)
end

function _mcp_path_is_within(path::String, root::String)
    relative = try
        relpath(path, root)
    catch
        return false
    end
    relative != ".." && !startswith(relative, "..$(Base.Filesystem.path_separator)")
end

function _mcp_existing_file(value, label::String)
    value isa AbstractString && !isempty(value) || throw(ArgumentError(
        "$label must be a nonempty local path"))
    candidate = abspath(String(value))
    isfile(candidate) || throw(ArgumentError("$label does not exist: $value"))
    path = realpath(candidate)
    any(root -> _mcp_path_is_within(path, root), _mcp_allowed_roots()) ||
        throw(ArgumentError(
            "$label is outside BMOPFTOOLS_MCP_ALLOWED_ROOTS: $value"))
    path
end

function _mcp_input(role::String, path::String)
    Dict{String,Any}(
        "role" => role,
        "path" => path,
        "sha256" => bytes2hex(sha256(read(path))),
    )
end

function _mcp_require_keys(arguments::AbstractDict, required::Tuple, optional::Tuple=())
    allowed = Set(vcat(collect(required), collect(optional)))
    unknown = sort!(String.(collect(setdiff(Set(string.(keys(arguments))), allowed))))
    isempty(unknown) || throw(ArgumentError("unsupported tool argument(s): " * join(unknown, ", ")))
    missing = [key for key in required if !haskey(arguments, key)]
    isempty(missing) || throw(ArgumentError("missing tool argument(s): " * join(missing, ", ")))
end

function _mcp_string(arguments::AbstractDict, key::String)
    value = get(arguments, key, nothing)
    value isa AbstractString && !isempty(value) || throw(ArgumentError(
        "$key must be a nonempty string"))
    String(value)
end

function _mcp_time_index(arguments::AbstractDict)
    value = get(arguments, "time_index", 1)
    value isa Integer && !(value isa Bool) && value >= 1 || throw(ArgumentError(
        "time_index must be an integer of at least 1"))
    Int(value)
end

function _mcp_tolerance(arguments::AbstractDict, key::String, default::Float64)
    value = get(arguments, key, default)
    value isa Real && !(value isa Bool) && value >= 0 || throw(ArgumentError(
        "$key must be a nonnegative number"))
    Float64(value)
end

function _mcp_string_vector(arguments::AbstractDict, key::String)
    value = get(arguments, key, nothing)
    value isa AbstractVector && !isempty(value) &&
        all(item -> item isa AbstractString && !isempty(item), value) ||
        throw(ArgumentError("$key must be a nonempty string array"))
    values = String.(value)
    length(unique(values)) == length(values) || throw(ArgumentError(
        "$key entries must be unique"))
    values
end

function _mcp_string_mapping(arguments::AbstractDict, key::String)
    value = get(arguments, key, nothing)
    value isa AbstractDict && !isempty(value) || throw(ArgumentError(
        "$key must be a nonempty object"))
    result = Dict{String,String}()
    for (source, target) in value
        source isa AbstractString && !isempty(source) || throw(ArgumentError(
            "$key keys must be nonempty strings"))
        target isa AbstractString && !isempty(target) || throw(ArgumentError(
            "$key values must be nonempty strings"))
        result[String(source)] = String(target)
    end
    result
end

function mcp_execute_tool(name::String, arguments::AbstractDict)
    if name == "bmopf_parse"
        _mcp_require_keys(arguments, ("path",))
        path = _mcp_existing_file(_mcp_string(arguments, "path"), "case path")
        return execute_case_parse(parse_bmopf(path); inputs=[_mcp_input("case", path)])
    elseif name == "bmopf_analyze"
        _mcp_require_keys(arguments, ("path",), ("time_index",))
        path = _mcp_existing_file(_mcp_string(arguments, "path"), "case path")
        return execute_analysis(
            parse_bmopf(path);
            t_index=_mcp_time_index(arguments),
            inputs=[_mcp_input("case", path)],
        )
    elseif name == "bmopf_verify_solution"
        _mcp_require_keys(arguments, ("case_path", "result_path"), ("time_index",))
        case_path = _mcp_existing_file(_mcp_string(arguments, "case_path"), "case path")
        result_path = _mcp_existing_file(_mcp_string(arguments, "result_path"), "result path")
        return execute_solution_verification(
            parse_bmopf(case_path),
            read_result(result_path);
            t_index=_mcp_time_index(arguments),
            inputs=[_mcp_input("case", case_path), _mcp_input("result", result_path)],
        )
    elseif name == "bmopf_explain_finding"
        _mcp_require_keys(arguments, ("code",))
        return execute_finding_explanation(_mcp_string(arguments, "code"))
    elseif name == "bmopf_check_parallel_member_limits"
        _mcp_require_keys(
            arguments,
            ("source_path", "target_path", "member_ids", "aggregate_id"),
            ("atol", "rtol"),
        )
        source_path = _mcp_existing_file(_mcp_string(arguments, "source_path"), "source path")
        target_path = _mcp_existing_file(_mcp_string(arguments, "target_path"), "target path")
        return execute_contract(
            "parallel_member_limit_preservation",
            parse_bmopf(source_path),
            parse_bmopf(target_path);
            parameters=Dict{String,Any}(
                "member_ids" => _mcp_string_vector(arguments, "member_ids"),
                "aggregate_id" => _mcp_string(arguments, "aggregate_id"),
                "atol" => _mcp_tolerance(arguments, "atol", 1e-9),
                "rtol" => _mcp_tolerance(arguments, "rtol", 1e-8),
            ),
            inputs=[_mcp_input("source", source_path), _mcp_input("target", target_path)],
        )
    elseif name == "bmopf_check_neutral_ground_reference"
        _mcp_require_keys(
            arguments,
            ("source_path", "target_path", "bus_mapping"),
            ("atol", "rtol"),
        )
        source_path = _mcp_existing_file(_mcp_string(arguments, "source_path"), "source path")
        target_path = _mcp_existing_file(_mcp_string(arguments, "target_path"), "target path")
        return execute_contract(
            "neutral_ground_reference_preservation",
            parse_bmopf(source_path),
            parse_bmopf(target_path);
            parameters=Dict{String,Any}(
                "bus_mapping" => _mcp_string_mapping(arguments, "bus_mapping"),
                "atol" => _mcp_tolerance(arguments, "atol", 1e-9),
                "rtol" => _mcp_tolerance(arguments, "rtol", 1e-8),
            ),
            inputs=[_mcp_input("source", source_path), _mcp_input("target", target_path)],
        )
    end
    throw(ArgumentError("unknown tool: $name"))
end

function _mcp_tool_result(payload::AbstractDict; is_error::Bool=false)
    result = Dict{String,Any}(
        "content" => [Dict{String,Any}(
            "type" => "text",
            "text" => JSON3.write(payload),
        )],
        "structuredContent" => payload,
    )
    is_error && (result["isError"] = true)
    result
end

function _mcp_read_resource(uri)
    if uri == MCP_MANIFEST_URI
        return mcp_resources()[1], read(joinpath(MCP_ROOT, "generated", "executable-knowledge-manifest.json"), String)
    elseif uri == MCP_RESPONSE_SCHEMA_URI
        return mcp_resources()[2], read(joinpath(MCP_ROOT, "schemas", "execution-response.schema.json"), String)
    end
    nothing
end

function mcp_handle_request(request::AbstractDict)
    method = get(request, "method", nothing)
    request_id = get(request, "id", nothing)
    params = get(request, "params", Dict{String,Any}())
    params isa AbstractDict || return mcp_error_response(request_id, -32602, "params must be an object")

    if method == "initialize"
        requested = get(params, "protocolVersion", nothing)
        protocol = requested in MCP_SUPPORTED_PROTOCOL_VERSIONS ? requested : MCP_PROTOCOL_VERSION
        return mcp_response(request_id, Dict{String,Any}(
            "protocolVersion" => protocol,
            "capabilities" => Dict{String,Any}(
                "tools" => Dict("listChanged" => false),
                "resources" => Dict("subscribe" => false, "listChanged" => false),
            ),
            "serverInfo" => Dict("name" => MCP_SERVER_NAME, "version" => MCP_SERVER_VERSION),
            "instructions" => (
                "Use BMOPFTools tools for case-specific execution. Parse completion is not validation; " *
                "Finding severity, solver termination, execution status, and scientific-contract status are distinct. " *
                "Use multi-graph-book for scientific retrieval and evidence interpretation."
            ),
        ))
    elseif method in ("notifications/initialized", "notifications/cancelled")
        return nothing
    elseif method == "ping"
        return mcp_response(request_id, Dict{String,Any}())
    elseif method == "tools/list"
        return mcp_response(request_id, Dict{String,Any}("tools" => mcp_tool_definitions()))
    elseif method == "resources/list"
        return mcp_response(request_id, Dict{String,Any}("resources" => mcp_resources()))
    elseif method == "resources/read"
        resource = _mcp_read_resource(get(params, "uri", nothing))
        resource === nothing && return mcp_error_response(request_id, -32002, "unknown resource URI")
        definition, contents = resource
        return mcp_response(request_id, Dict{String,Any}(
            "contents" => [merge(definition, Dict{String,Any}("text" => contents))],
        ))
    elseif method == "tools/call"
        name = get(params, "name", nothing)
        name isa AbstractString || return mcp_error_response(request_id, -32602, "tool name must be a string")
        haskey(MCP_TOOL_OPERATIONS, String(name)) ||
            return mcp_error_response(request_id, -32602, "unknown tool: $name")
        arguments = get(params, "arguments", Dict{String,Any}())
        arguments isa AbstractDict || return mcp_error_response(request_id, -32602, "tool arguments must be an object")
        try
            payload = mcp_execute_tool(String(name), arguments)
            return mcp_response(request_id, _mcp_tool_result(payload))
        catch exception
            message = sprint(showerror, exception)
            operation = MCP_TOOL_OPERATIONS[String(name)]
            contract_id = if name == "bmopf_check_parallel_member_limits"
                "parallel_member_limit_preservation"
            elseif name == "bmopf_check_neutral_ground_reference"
                "neutral_ground_reference_preservation"
            else
                nothing
            end
            code = exception isa BMOPFTools.UnknownFindingCode ?
                "unknown_finding_code" : "mcp_tool_error"
            payload = execution_error_response(
                message;
                code=code,
                operation=operation,
                contract_id=contract_id,
            )
            return mcp_response(request_id, _mcp_tool_result(payload; is_error=true))
        end
    end
    mcp_error_response(request_id, -32601, "method not found: $method")
end

function main(; input::IO=stdin, output::IO=stdout)::Int
    for line in eachline(input)
        isempty(strip(line)) && continue
        result = try
            request = JSON3.read(line, Dict{String,Any})
            mcp_handle_request(request)
        catch exception
            mcp_error_response(nothing, -32700, sprint(showerror, exception))
        end
        result === nothing && continue
        JSON3.write(output, result)
        println(output)
        flush(output)
    end
    0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
