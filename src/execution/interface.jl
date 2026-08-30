# execution/interface.jl

const _EXECUTION_RESPONSE_SCHEMA_VERSION = "0.3.0"

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

function _execution_validate_parameter_keys(
        contract_id::String,
        parameters::Dict{String,Any};
        required::Tuple,
        optional::Tuple=())
    allowed = Set(vcat(collect(required), collect(optional)))
    unknown = sort!(collect(setdiff(Set(keys(parameters)), allowed)))
    isempty(unknown) || throw(ArgumentError(
        "unsupported parameters for $contract_id: " * join(unknown, ", ")))
    missing = [key for key in required if !haskey(parameters, key)]
    isempty(missing) || throw(ArgumentError(
        "$contract_id requires parameter(s): " * join(missing, ", ")))
end

function _execution_tolerances(parameters::Dict{String,Any})
    atol = get(parameters, "atol", 1e-9)
    rtol = get(parameters, "rtol", 1e-8)
    atol isa Real && !(atol isa Bool) || throw(ArgumentError(
        "parameter 'atol' must be numeric"))
    rtol isa Real && !(rtol isa Bool) || throw(ArgumentError(
        "parameter 'rtol' must be numeric"))
    (atol=atol, rtol=rtol)
end

function _execute_parallel_member_limit(
        source::Dict{String,Any}, target::Dict{String,Any},
        parameters::Dict{String,Any})
    contract_id = "parallel_member_limit_preservation"
    _execution_validate_parameter_keys(
        contract_id, parameters;
        required=("member_ids", "aggregate_id"),
        optional=("atol", "rtol"),
    )
    member_ids = parameters["member_ids"]
    aggregate_id = parameters["aggregate_id"]
    member_ids isa AbstractVector && all(item -> item isa AbstractString, member_ids) ||
        throw(ArgumentError("$contract_id requires string-array parameter 'member_ids'"))
    aggregate_id isa AbstractString && !isempty(aggregate_id) || throw(ArgumentError(
        "$contract_id requires nonempty string parameter 'aggregate_id'"))
    tolerances = _execution_tolerances(parameters)
    check_parallel_member_limit_preservation(
        source,
        target;
        member_ids=String.(member_ids),
        aggregate_id=String(aggregate_id),
        atol=tolerances.atol,
        rtol=tolerances.rtol,
    )
end

function _execute_neutral_ground_reference(
        source::Dict{String,Any}, target::Dict{String,Any},
        parameters::Dict{String,Any})
    contract_id = "neutral_ground_reference_preservation"
    _execution_validate_parameter_keys(
        contract_id, parameters;
        required=("bus_mapping",),
        optional=("atol", "rtol"),
    )
    raw_mapping = parameters["bus_mapping"]
    raw_mapping isa AbstractDict || throw(ArgumentError(
        "$contract_id requires object parameter 'bus_mapping'"))
    mapping = Dict{String,String}()
    for (source_id, target_id) in raw_mapping
        source_id isa AbstractString && !isempty(source_id) || throw(ArgumentError(
            "$contract_id requires nonempty string bus_mapping keys"))
        target_id isa AbstractString && !isempty(target_id) || throw(ArgumentError(
            "$contract_id requires nonempty string bus_mapping values"))
        mapping[String(source_id)] = String(target_id)
    end
    tolerances = _execution_tolerances(parameters)
    check_neutral_ground_reference_preservation(
        source,
        target;
        bus_mapping=mapping,
        atol=tolerances.atol,
        rtol=tolerances.rtol,
    )
end

const _EXECUTION_CONTRACT_ADAPTERS = Dict{String,Function}(
    "neutral_ground_reference_preservation" => _execute_neutral_ground_reference,
    "parallel_member_limit_preservation" => _execute_parallel_member_limit,
)
const _EXECUTION_CONTRACT_IDS = Tuple(sort!(collect(keys(_EXECUTION_CONTRACT_ADAPTERS))))

"""
    execute_contract(contract_id, source, target; parameters, inputs=[])

Run a contract through the stable, JSON-ready BMOPFTools execution interface.
The response preserves the scientific-contract status (`passed`, `failed`,
`inapplicable`, or `indeterminate`), package identity, explicit request
parameters, optional input hashes, and the complete structured contract result.

The curated interface supports `parallel_member_limit_preservation`, with
`member_ids` and `aggregate_id`, and `neutral_ground_reference_preservation`,
with an explicit `bus_mapping`. Optional `atol` and `rtol` entries are passed to
the underlying domain API. Unsupported contracts raise `ArgumentError` instead
of dynamically invoking arbitrary Julia functions.
"""
function execute_contract(
        contract_id::AbstractString,
        source::Dict{String,Any},
        target::Dict{String,Any};
        parameters::AbstractDict,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    id = String(contract_id)
    adapter = get(_EXECUTION_CONTRACT_ADAPTERS, id, nothing)
    adapter === nothing && throw(ArgumentError(
        "unsupported executable contract '$id'; supported contracts: " *
        join(_EXECUTION_CONTRACT_IDS, ", ")))

    normalized_parameters = _execution_parameters(parameters)
    result = adapter(source, target, normalized_parameters)
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
    execute_analysis(net; t_index=1, inputs=[])

Run BMOPFTools' standard case analysis through the stable, JSON-ready execution
interface. A completed operation has status `completed` even when the report
contains ERROR or WARNING Findings: Finding severity describes the case, while
the envelope status describes whether the requested operation ran.

`t_index` selects a snapshot for time-series inputs and is ignored for snapshot
networks. Optional input records bind the response to caller-supplied file
hashes in the same way as [`execute_contract`](@ref).
"""
function execute_analysis(
        net::Dict{String,Any};
        t_index::Int=1,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    t_index >= 1 || throw(ArgumentError("t_index must be at least 1"))
    report = analyze(net; t_index=t_index)
    Dict{String,Any}(
        "schema_version" => _EXECUTION_RESPONSE_SCHEMA_VERSION,
        "operation" => "analyze_case",
        "status" => "completed",
        "package" => _execution_package_identity(),
        "request" => Dict{String,Any}(
            "contract_id" => nothing,
            "parameters" => Dict{String,Any}("t_index" => t_index),
        ),
        "inputs" => _execution_inputs(inputs),
        "result" => _report_to_json(report),
    )
end

"""
    execute_solution_verification(net, result; t_index=1, inputs=[])

Profile a solver result against its BMOPF case through the stable, JSON-ready
execution interface. The operation recomputes the package's solution checks and
returns the complete structured `SolutionReport`.

A response has status `completed` whenever profiling ran, even if the solver
reported an infeasible status or the report contains ERROR Findings. Solver
termination, Finding severity, and execution status are deliberately separate.
"""
function execute_solution_verification(
        net::Dict{String,Any},
        result::Dict{String,Any};
        t_index::Int=1,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    t_index >= 1 || throw(ArgumentError("t_index must be at least 1"))
    report = profile_solution(net, result; t_index=t_index)
    Dict{String,Any}(
        "schema_version" => _EXECUTION_RESPONSE_SCHEMA_VERSION,
        "operation" => "verify_solution",
        "status" => "completed",
        "package" => _execution_package_identity(),
        "request" => Dict{String,Any}(
            "contract_id" => nothing,
            "parameters" => Dict{String,Any}("t_index" => t_index),
        ),
        "inputs" => _execution_inputs(inputs),
        "result" => _solution_report_to_json(report),
    )
end

"""
    execution_error_response(message; code="invalid_request",
                             operation="check_contract",
                             contract_id=nothing, inputs=[])

Construct the same stable response envelope for a transport or request error.
This status is distinct from the four scientific-contract statuses and does not
represent scientific evidence.
"""
function execution_error_response(
        message::AbstractString;
        code::AbstractString="invalid_request",
        operation::AbstractString="check_contract",
        contract_id::Union{AbstractString,Nothing}=nothing,
        inputs::AbstractVector=Dict{String,Any}[])::Dict{String,Any}
    isempty(message) && throw(ArgumentError("execution error message must be nonempty"))
    isempty(code) && throw(ArgumentError("execution error code must be nonempty"))
    operation in ("check_contract", "analyze_case", "verify_solution") || throw(ArgumentError(
        "unsupported execution operation '$operation'"))
    operation != "check_contract" && contract_id !== nothing && throw(ArgumentError(
        "$operation errors cannot name a scientific contract"))
    Dict{String,Any}(
        "schema_version" => _EXECUTION_RESPONSE_SCHEMA_VERSION,
        "operation" => String(operation),
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
