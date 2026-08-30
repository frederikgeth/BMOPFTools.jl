# execution/interface.jl

const _EXECUTION_RESPONSE_SCHEMA_VERSION = "0.1.0"
const _EXECUTION_CONTRACT_IDS = ("parallel_member_limit_preservation",)

function _execution_package_identity()
    Dict{String,Any}(
        "name" => "BMOPFTools",
        "version" => _BMOPFTOOLS_VERSION,
    )
end

function _execution_inputs(inputs::AbstractVector)
    normalized = Dict{String,Any}[]
    for input in inputs
        input isa AbstractDict || throw(ArgumentError(
            "each execution input must be a dictionary"))
        role = get(input, "role", get(input, :role, nothing))
        path = get(input, "path", get(input, :path, nothing))
        sha256 = get(input, "sha256", get(input, :sha256, nothing))
        role isa AbstractString && !isempty(role) || throw(ArgumentError(
            "each execution input must have a nonempty role"))
        path isa AbstractString && !isempty(path) || throw(ArgumentError(
            "each execution input must have a nonempty path"))
        sha256 isa AbstractString && occursin(r"^[0-9a-f]{64}$", sha256) ||
            throw(ArgumentError("each execution input must have a lowercase SHA-256 digest"))
        push!(normalized, Dict{String,Any}(
            "role" => String(role),
            "path" => String(path),
            "sha256" => String(sha256),
        ))
    end
    normalized
end

function _execution_parameters(parameters::AbstractDict)
    Dict{String,Any}(string(key) => _jsonable(value) for (key, value) in parameters)
end

"""
    execute_contract(contract_id, source, target; parameters, inputs=[])

Run a contract through the stable, JSON-ready BMOPFTools execution interface.
The response preserves the scientific-contract status (`passed`, `failed`,
`inapplicable`, or `indeterminate`), package identity, explicit request
parameters, optional input hashes, and the complete structured contract result.

The initial interface supports `parallel_member_limit_preservation`. Its
`parameters` dictionary must contain `member_ids` and `aggregate_id`; optional
`atol` and `rtol` entries are passed to the underlying domain API. Unsupported
contracts raise `ArgumentError` instead of dynamically invoking arbitrary Julia
functions.
"""
function execute_contract(
        contract_id::AbstractString,
        source::Dict{String,Any},
        target::Dict{String,Any};
        parameters::AbstractDict,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    id = String(contract_id)
    id in _EXECUTION_CONTRACT_IDS || throw(ArgumentError(
        "unsupported executable contract '$id'; supported contracts: " *
        join(_EXECUTION_CONTRACT_IDS, ", ")))

    normalized_parameters = _execution_parameters(parameters)
    unknown_parameters = setdiff(
        Set(keys(normalized_parameters)),
        Set(["member_ids", "aggregate_id", "atol", "rtol"]),
    )
    isempty(unknown_parameters) || throw(ArgumentError(
        "unsupported parameters for parallel_member_limit_preservation: " *
        join(sort!(collect(unknown_parameters)), ", ")))
    member_ids = get(normalized_parameters, "member_ids", nothing)
    aggregate_id = get(normalized_parameters, "aggregate_id", nothing)
    member_ids isa AbstractVector && all(item -> item isa AbstractString, member_ids) ||
        throw(ArgumentError("parallel_member_limit_preservation requires string-array parameter 'member_ids'"))
    aggregate_id isa AbstractString && !isempty(aggregate_id) || throw(ArgumentError(
        "parallel_member_limit_preservation requires nonempty string parameter 'aggregate_id'"))

    atol = get(normalized_parameters, "atol", 1e-9)
    rtol = get(normalized_parameters, "rtol", 1e-8)
    atol isa Real && !(atol isa Bool) || throw(ArgumentError(
        "parameter 'atol' must be numeric"))
    rtol isa Real && !(rtol isa Bool) || throw(ArgumentError(
        "parameter 'rtol' must be numeric"))
    result = check_parallel_member_limit_preservation(
        source,
        target;
        member_ids=String.(member_ids),
        aggregate_id=String(aggregate_id),
        atol=atol,
        rtol=rtol,
    )
    result_payload = contract_result_to_dict(result)
    Dict{String,Any}(
        "schema_version" => _EXECUTION_RESPONSE_SCHEMA_VERSION,
        "operation" => "check_contract",
        "status" => string(result.status),
        "package" => _execution_package_identity(),
        "request" => Dict{String,Any}(
            "contract_id" => id,
            "parameters" => normalized_parameters,
        ),
        "inputs" => _execution_inputs(inputs),
        "result" => _jsonable(result_payload),
    )
end

"""
    execution_error_response(message; code="invalid_request",
                             contract_id=nothing, inputs=[])

Construct the same stable response envelope for a transport or request error.
This status is distinct from the four scientific-contract statuses and does not
represent scientific evidence.
"""
function execution_error_response(
        message::AbstractString;
        code::AbstractString="invalid_request",
        contract_id::Union{AbstractString,Nothing}=nothing,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    isempty(message) && throw(ArgumentError("execution error message must be nonempty"))
    isempty(code) && throw(ArgumentError("execution error code must be nonempty"))
    Dict{String,Any}(
        "schema_version" => _EXECUTION_RESPONSE_SCHEMA_VERSION,
        "operation" => "check_contract",
        "status" => "error",
        "package" => _execution_package_identity(),
        "request" => Dict{String,Any}(
            "contract_id" => contract_id === nothing ? nothing : String(contract_id),
            "parameters" => Dict{String,Any}(),
        ),
        "inputs" => _execution_inputs(inputs),
        "error" => Dict{String,Any}(
            "code" => String(code),
            "message" => String(message),
        ),
    )
end
