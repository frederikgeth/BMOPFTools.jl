#!/usr/bin/env julia

using BMOPFTools
using JSON3
using SHA

const _CLI_USAGE = """
Usage:
  bmopf check-contract parallel_member_limit_preservation \\
    --source SOURCE.json --target TARGET.json \\
    --member-id LINE_ID --member-id LINE_ID --aggregate-id LINE_ID \\
    [--atol VALUE] [--rtol VALUE] [--pretty]

  bmopf check-contract neutral_ground_reference_preservation \\
    --source SOURCE.json --target TARGET.json \\
    --bus-map SOURCE_BUS=TARGET_BUS --bus-map SOURCE_BUS=TARGET_BUS \\
    [--atol VALUE] [--rtol VALUE] [--pretty]

  bmopf analyze-case --input CASE.json [--time-index INTEGER] [--pretty]

  bmopf verify-solution --case CASE.json --result RESULT.json \
    [--time-index INTEGER] [--pretty]

The command writes one execution-response JSON object to stdout. Diagnostics
and usage errors are written to stderr. Exit codes are 0 for a completed
operation, 2 for an invalid request, and 1 for an input or execution failure. A
completed contract may itself report passed, failed, inapplicable, or
indeterminate status. A completed analysis may contain ERROR Findings without
turning the operation status into an error.
"""
const _CLI_CONTRACT_IDS = (
    "neutral_ground_reference_preservation",
    "parallel_member_limit_preservation",
)

function _cli_bus_mapping(value::String)
    pair = split(value, "="; limit=2, keepempty=true)
    length(pair) == 2 && all(!isempty, pair) || throw(ArgumentError(
        "--bus-map must have the form SOURCE_BUS=TARGET_BUS"))
    String(pair[1]) => String(pair[2])
end

function _cli_parse_contract(args::Vector{String})
    length(args) >= 2 || throw(ArgumentError("missing contract ID"))
    contract_id = args[2]
    contract_id in _CLI_CONTRACT_IDS || throw(ArgumentError(
        "unsupported contract '$contract_id'; supported contracts: " *
        join(_CLI_CONTRACT_IDS, ", ")))
    source = nothing
    target = nothing
    member_ids = String[]
    aggregate_id = nothing
    bus_mapping = Dict{String,String}()
    atol = 1e-9
    rtol = 1e-8
    pretty = false
    index = 3
    while index <= length(args)
        flag = args[index]
        if flag == "--pretty"
            pretty = true
            index += 1
            continue
        end
        index < length(args) || throw(ArgumentError("missing value for $flag"))
        value = args[index + 1]
        if flag == "--source"
            source === nothing || throw(ArgumentError("--source may be supplied only once"))
            source = value
        elseif flag == "--target"
            target === nothing || throw(ArgumentError("--target may be supplied only once"))
            target = value
        elseif flag == "--member-id"
            push!(member_ids, value)
        elseif flag == "--aggregate-id"
            aggregate_id === nothing || throw(ArgumentError(
                "--aggregate-id may be supplied only once"))
            aggregate_id = value
        elseif flag == "--bus-map"
            source_id, target_id = _cli_bus_mapping(value)
            haskey(bus_mapping, source_id) && throw(ArgumentError(
                "--bus-map source '$source_id' may be supplied only once"))
            bus_mapping[source_id] = target_id
        elseif flag == "--atol"
            atol = tryparse(Float64, value)
            atol === nothing && throw(ArgumentError("--atol must be numeric"))
        elseif flag == "--rtol"
            rtol = tryparse(Float64, value)
            rtol === nothing && throw(ArgumentError("--rtol must be numeric"))
        else
            throw(ArgumentError("unknown option '$flag'"))
        end
        index += 2
    end
    source === nothing && throw(ArgumentError("--source is required"))
    target === nothing && throw(ArgumentError("--target is required"))
    if contract_id == "parallel_member_limit_preservation"
        isempty(member_ids) && throw(ArgumentError(
            "at least one --member-id is required"))
        aggregate_id === nothing && throw(ArgumentError("--aggregate-id is required"))
        isempty(bus_mapping) || throw(ArgumentError(
            "--bus-map is not valid for $contract_id"))
    else
        isempty(bus_mapping) && throw(ArgumentError(
            "at least one --bus-map is required"))
        isempty(member_ids) || throw(ArgumentError(
            "--member-id is not valid for $contract_id"))
        aggregate_id === nothing || throw(ArgumentError(
            "--aggregate-id is not valid for $contract_id"))
    end
    (
        operation="check_contract",
        contract_id=contract_id,
        source=String(source),
        target=String(target),
        member_ids=member_ids,
        aggregate_id=aggregate_id === nothing ? nothing : String(aggregate_id),
        bus_mapping=bus_mapping,
        atol=Float64(atol),
        rtol=Float64(rtol),
        pretty=pretty,
    )
end

function _cli_parse_analysis(args::Vector{String})
    input = nothing
    t_index = 1
    pretty = false
    index = 2
    while index <= length(args)
        flag = args[index]
        if flag == "--pretty"
            pretty = true
            index += 1
            continue
        end
        index < length(args) || throw(ArgumentError("missing value for $flag"))
        value = args[index + 1]
        if flag == "--input"
            input === nothing || throw(ArgumentError("--input may be supplied only once"))
            input = value
        elseif flag == "--time-index"
            parsed_index = tryparse(Int, value)
            parsed_index !== nothing && parsed_index >= 1 || throw(ArgumentError(
                "--time-index must be an integer of at least 1"))
            t_index = parsed_index
        else
            throw(ArgumentError("unknown option '$flag'"))
        end
        index += 2
    end
    input === nothing && throw(ArgumentError("--input is required"))
    (operation="analyze_case", input=String(input), t_index=t_index, pretty=pretty)
end

function _cli_parse_solution(args::Vector{String})
    case_path = nothing
    result_path = nothing
    t_index = 1
    pretty = false
    index = 2
    while index <= length(args)
        flag = args[index]
        if flag == "--pretty"
            pretty = true
            index += 1
            continue
        end
        index < length(args) || throw(ArgumentError("missing value for $flag"))
        value = args[index + 1]
        if flag == "--case"
            case_path === nothing || throw(ArgumentError("--case may be supplied only once"))
            case_path = value
        elseif flag == "--result"
            result_path === nothing || throw(ArgumentError("--result may be supplied only once"))
            result_path = value
        elseif flag == "--time-index"
            parsed_index = tryparse(Int, value)
            parsed_index !== nothing && parsed_index >= 1 || throw(ArgumentError(
                "--time-index must be an integer of at least 1"))
            t_index = parsed_index
        else
            throw(ArgumentError("unknown option '$flag'"))
        end
        index += 2
    end
    case_path === nothing && throw(ArgumentError("--case is required"))
    result_path === nothing && throw(ArgumentError("--result is required"))
    (
        operation="verify_solution",
        case_path=String(case_path),
        result_path=String(result_path),
        t_index=t_index,
        pretty=pretty,
    )
end

function _cli_parse(args::Vector{String})
    isempty(args) && throw(ArgumentError("missing operation"))
    args[1] == "check-contract" && return _cli_parse_contract(args)
    args[1] == "analyze-case" && return _cli_parse_analysis(args)
    args[1] == "verify-solution" && return _cli_parse_solution(args)
    throw(ArgumentError(
        "unsupported operation '$(args[1])'; expected check-contract, analyze-case, or verify-solution"))
end

function _cli_operation(args::Vector{String})
    !isempty(args) && args[1] == "analyze-case" && return "analyze_case"
    !isempty(args) && args[1] == "verify-solution" && return "verify_solution"
    "check_contract"
end

function _cli_parameters(parsed)
    parameters = Dict{String,Any}(
        "atol" => parsed.atol,
        "rtol" => parsed.rtol,
    )
    if parsed.contract_id == "parallel_member_limit_preservation"
        parameters["member_ids"] = parsed.member_ids
        parameters["aggregate_id"] = parsed.aggregate_id
    else
        parameters["bus_mapping"] = parsed.bus_mapping
    end
    parameters
end

function _cli_input(role::String, path::String)
    isfile(path) || throw(ArgumentError("$role input does not exist: $path"))
    Dict{String,Any}(
        "role" => role,
        "path" => path,
        "sha256" => bytes2hex(sha256(read(path))),
    )
end

function _cli_write(io::IO, payload::AbstractDict; pretty::Bool=false)
    if pretty
        JSON3.pretty(io, payload, JSON3.AlignmentContext(; indent=UInt16(2)))
    else
        JSON3.write(io, payload)
    end
    println(io)
end

function main(args::Vector{String}=ARGS; out::IO=stdout, err::IO=stderr)::Int
    parsed = try
        _cli_parse(args)
    catch exception
        message = sprint(showerror, exception)
        println(err, message)
        println(err, _CLI_USAGE)
        operation = _cli_operation(args)
        contract_id = operation == "check_contract" && length(args) >= 2 ? args[2] : nothing
        _cli_write(out, execution_error_response(
            message; code="invalid_request", operation=operation,
            contract_id=contract_id))
        return 2
    end

    inputs = try
        if parsed.operation == "check_contract"
            [_cli_input("source", parsed.source), _cli_input("target", parsed.target)]
        elseif parsed.operation == "analyze_case"
            [_cli_input("case", parsed.input)]
        else
            [_cli_input("case", parsed.case_path), _cli_input("result", parsed.result_path)]
        end
    catch exception
        message = sprint(showerror, exception)
        println(err, message)
        _cli_write(out, execution_error_response(
            message;
            code="input_error",
            operation=parsed.operation,
            contract_id=parsed.operation == "check_contract" ? parsed.contract_id : nothing,
        ); pretty=parsed.pretty)
        return 1
    end

    payload = try
        if parsed.operation == "check_contract"
            source = parse_bmopf(parsed.source)
            target = parse_bmopf(parsed.target)
            execute_contract(
                parsed.contract_id,
                source,
                target;
                parameters=_cli_parameters(parsed),
                inputs=inputs,
            )
        elseif parsed.operation == "analyze_case"
            execute_analysis(
                parse_bmopf(parsed.input);
                t_index=parsed.t_index,
                inputs=inputs,
            )
        else
            execute_solution_verification(
                parse_bmopf(parsed.case_path),
                read_result(parsed.result_path);
                t_index=parsed.t_index,
                inputs=inputs,
            )
        end
    catch exception
        message = sprint(showerror, exception)
        println(err, message)
        _cli_write(out, execution_error_response(
            message;
            code="execution_error",
            operation=parsed.operation,
            contract_id=parsed.operation == "check_contract" ? parsed.contract_id : nothing,
            inputs=inputs,
        ); pretty=parsed.pretty)
        return 1
    end

    _cli_write(out, payload; pretty=parsed.pretty)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
