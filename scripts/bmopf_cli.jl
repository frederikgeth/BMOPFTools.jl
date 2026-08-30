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

The command writes one execution-response JSON object to stdout. Diagnostics
and usage errors are written to stderr. Exit codes are 0 for a completed
scientific-contract evaluation, 2 for an invalid request, and 1 for an input or
execution failure. A completed contract may itself report passed, failed,
inapplicable, or indeterminate status.
"""
const _CLI_CONTRACT_IDS = ("parallel_member_limit_preservation",)

function _cli_parse(args::Vector{String})
    length(args) >= 2 || throw(ArgumentError("missing operation or contract ID"))
    args[1] == "check-contract" || throw(ArgumentError(
        "unsupported operation '$(args[1])'; expected check-contract"))
    contract_id = args[2]
    contract_id in _CLI_CONTRACT_IDS || throw(ArgumentError(
        "unsupported contract '$contract_id'; supported contracts: " *
        join(_CLI_CONTRACT_IDS, ", ")))
    source = nothing
    target = nothing
    member_ids = String[]
    aggregate_id = nothing
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
    length(member_ids) >= 2 || throw(ArgumentError(
        "at least two --member-id values are required"))
    aggregate_id === nothing && throw(ArgumentError("--aggregate-id is required"))
    (
        contract_id=contract_id,
        source=String(source),
        target=String(target),
        member_ids=member_ids,
        aggregate_id=String(aggregate_id),
        atol=Float64(atol),
        rtol=Float64(rtol),
        pretty=pretty,
    )
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
        contract_id = length(args) >= 2 ? args[2] : nothing
        _cli_write(out, execution_error_response(
            message; code="invalid_request", contract_id=contract_id))
        return 2
    end

    inputs = try
        [_cli_input("source", parsed.source), _cli_input("target", parsed.target)]
    catch exception
        message = sprint(showerror, exception)
        println(err, message)
        _cli_write(out, execution_error_response(
            message;
            code="input_error",
            contract_id=parsed.contract_id,
        ); pretty=parsed.pretty)
        return 1
    end

    payload = try
        source = parse_bmopf(parsed.source)
        target = parse_bmopf(parsed.target)
        execute_contract(
            parsed.contract_id,
            source,
            target;
            parameters=Dict{String,Any}(
                "member_ids" => parsed.member_ids,
                "aggregate_id" => parsed.aggregate_id,
                "atol" => parsed.atol,
                "rtol" => parsed.rtol,
            ),
            inputs=inputs,
        )
    catch exception
        message = sprint(showerror, exception)
        println(err, message)
        _cli_write(out, execution_error_response(
            message;
            code="execution_error",
            contract_id=parsed.contract_id,
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
