# Generic build/solve engine shared by every problem formulation.
#
# Each problem (OPF, feasibility OPF, and future power-flow / state-estimation
# variants) is expressed as a small *build recipe* — a function that declares
# which start values, bounds, device constraints, slacks, and objective to add.
# `_build_and_solve` owns the invariant pipeline around those recipes:
#
#   1. snapshot / per-unit the network
#   2. build the JuMP model + index structures + variables
#   3. initialise the KCL accumulators
#   4. run the problem's `build!(ctx)` recipe        ← the only part that varies
#   5. enforce KCL and optimize
#   6. extract the standard result dict
#   7. run the problem's optional `extract!(ctx, result)` hook for extra keys
#   8. unwrap per-unit
#
# This mirrors the PowerModels/InfrastructureModels pattern where a generic
# `solve_model(data, type, optimizer, build_method)` core is parameterised by a
# per-problem `build_*` function.

"""
    OpfContext

Bundle of everything a build recipe needs, threaded through the device-constraint
helpers in place of the previous 7 positional arguments. Field names match the
local variables the helpers already expect.

- `model`         — the JuMP model
- `net`           — the working network dict (snapshot + per-unit applied)
- `bus_terminals` — `Dict{String,Vector{String}}` bus → ordered terminals
- `grounded`      — `Set{Tuple{String,String}}` perfectly-grounded (bus, terminal)
- `vars`          — variable dict returned by `_build_vars`
- `kcl_r`/`kcl_i` — per-terminal KCL accumulator expressions
- `branch_inj`    — per two-port-device injection ledger (see `_new_branch_ledger`),
  populated as side effect of `_kcl_add!` so element complex losses can be
  computed exactly from terminal powers: `branch_inj[block][id]` is a vector of
  `(bus, terminal, cr_expr, ci_expr)`, each the current the element injects INTO
  that bus terminal (KCL "into bus" sign). The element's complex loss is then
  `S_loss = Σ V·conj(I_into_element) = −Σ V·conj(I_into_bus)`.
"""
struct OpfContext
    model
    net::Dict{String,Any}
    bus_terminals::Dict{String,Vector{String}}
    grounded::Set{Tuple{String,String}}
    vars::Dict
    kcl_r::Dict
    kcl_i::Dict
    branch_inj::Dict{String,Any}
    # Per-unit bases (`nothing` when the model is built in SI units), used by the
    # IBR Volt-var/Volt-watt droop to scale SI breakpoint voltages into model
    # units. `relu_eps` is the relative smoothing for the smooth-ReLU droop and
    # `relu_ops` caches the registered operators by (model-unit) ε.
    #
    # `bases` also lets a `model_hook!` author express physical-unit constraints:
    # by default `per_unit=true`, so `ctx.model`'s variables (voltages, currents,
    # powers) are per-unit and any watt/volt/amp literal in a hook must be divided
    # by the matching base. When present, `bases` is a NamedTuple carrying
    # `s_base` (VA), per-bus `v_base`/`i_base`/`z_base`/`y_base` Dicts, and the DC
    # `v_dc_base`/`i_dc_base`/`z_dc_base`; e.g. a watt cap becomes
    # `expr <= P_watts / ctx.bases.s_base`. In SI mode `bases === nothing` and the
    # literal is used as-is (divide by 1.0).
    bases
    relu_eps::Float64
    softplus::Symbol
    relu_ops::Dict{Float64,Any}
    # Stable downstream-extension substrate. `objects` maps public
    # `BMOPFTools.OpfModelKey`s to live JuMP objects; `extension_state` is
    # namespaced by an extension-owned key; `lifecycle` guards one-shot model
    # finalization and post-KCL mutation.
    objects::Dict{BMOPFTools.OpfModelKey,Any}
    extension_state::Dict{Any,Any}
    parameter_bindings::Dict{BMOPFTools.OpfModelKey,BMOPFTools.OpfParameterBinding}
    parameter_aliases::Dict{Symbol,BMOPFTools.OpfModelKey}
    coefficient_usage::Dict{BMOPFTools.OpfCoefficientKey,Int}
    regularizations::Dict{Symbol,BMOPFTools.OpfRegularization}
    differentiability_annotations::Dict{
        Symbol,BMOPFTools.OpfDifferentiabilityAnnotation}
    manifest::BMOPFTools.OpfBuildManifest
    build_spec::BMOPFTools.OpfBuildSpec
    result_extractors::Dict{Symbol,Function}
    lifecycle::Base.RefValue{Symbol}
end

BMOPFTools.opf_model(ctx::OpfContext) = ctx.model
BMOPFTools.opf_network(ctx::OpfContext) = ctx.net
BMOPFTools.opf_bases(ctx::OpfContext) = ctx.bases
BMOPFTools.opf_neutral_labels(ctx::OpfContext) = copy(BMOPFTools._neutral_labels(ctx.net))
BMOPFTools.opf_lifecycle(ctx::OpfContext) = ctx.lifecycle[]
function BMOPFTools.opf_build_manifest(ctx::OpfContext)
    manifest = ctx.manifest
    return BMOPFTools.OpfBuildManifest(
        manifest.problem, manifest.formulation, manifest.per_unit,
        manifest.s_base, copy(manifest.stages), copy(manifest.component_owners))
end
function BMOPFTools.opf_build_spec(ctx::OpfContext)
    spec = ctx.build_spec
    return BMOPFTools.OpfBuildSpec(
        family_builders=copy(spec.family_builders),
        component_builders=copy(spec.component_builders),
        coefficient_providers=copy(spec.coefficient_providers))
end
BMOPFTools.opf_stage_completed(ctx::OpfContext, stage::Symbol) =
    stage in ctx.manifest.stages

const _OPF_STAGE_ORDER = Dict{Symbol,Int}(
    :variables => 1,
    :start_values => 2,
    :operational_limits => 3,
    :device_physics => 4,
    :objective => 5,
    :kcl => 6,
)

function _run_opf_stage!(ctx::OpfContext, stage::Symbol, action::Function;
                         required::Tuple=())
    ctx.lifecycle[] == :building || throw(ArgumentError(
        "cannot run OPF construction stage '$stage' after KCL finalization"))
    stage in ctx.manifest.stages && throw(ArgumentError(
        "OPF construction stage '$stage' has already completed"))
    for dependency in required
        dependency in ctx.manifest.stages || throw(ArgumentError(
            "OPF construction stage '$stage' requires '$dependency' first"))
    end
    rank = get(_OPF_STAGE_ORDER, stage, nothing)
    rank === nothing && throw(ArgumentError("unknown OPF construction stage '$stage'"))
    completed_ranks = Int[get(_OPF_STAGE_ORDER, s, 0) for s in ctx.manifest.stages]
    maximum(completed_ranks; init=0) < rank || throw(ArgumentError(
        "OPF construction stage '$stage' is out of order; completed stages are " *
        "$(ctx.manifest.stages)"))
    action()
    push!(ctx.manifest.stages, stage)
    return ctx
end

function BMOPFTools.register_opf_object!(ctx::OpfContext,
                                         key::BMOPFTools.OpfModelKey,
                                         object; replace::Bool=false)
    haskey(ctx.parameter_bindings, key) && throw(ArgumentError(
        "cannot replace or re-register parameter-bound OPF model object $key; " *
        "update it through its OpfParameterBinding"))
    if haskey(ctx.objects, key) && !replace
        throw(ArgumentError("OPF model object key already registered: $key"))
    end
    ctx.objects[key] = object
    return object
end

function BMOPFTools.opf_object(ctx::OpfContext, key::BMOPFTools.OpfModelKey)
    haskey(ctx.objects, key) ||
        throw(KeyError("no OPF model object registered for $key"))
    return ctx.objects[key]
end

function BMOPFTools.opf_object_keys(ctx::OpfContext; kind=nothing)
    keys_all = collect(keys(ctx.objects))
    kind === nothing && return keys_all
    kind isa Symbol || throw(ArgumentError("kind must be a Symbol or nothing"))
    return filter(key -> key.kind == kind, keys_all)
end

function BMOPFTools.register_opf_objective_term!(
        ctx::OpfContext, key::BMOPFTools.OpfModelKey, term;
        replace::Bool=false)
    key.kind == :objective || throw(ArgumentError(
        "an OPF objective-term key must have kind=:objective; got $(key.kind)"))
    (term isa Real || term isa JuMP.AbstractJuMPScalar) || throw(ArgumentError(
        "an OPF objective term must be a real constant or scalar JuMP object"))
    if term isa JuMP.AbstractJuMPScalar
        try
            JuMP.check_belongs_to_model(term, ctx.model)
        catch
            throw(ArgumentError(
                "the OPF objective term belongs to a different JuMP model"))
        end
    end
    return BMOPFTools.register_opf_object!(ctx, key, term; replace)
end

function _solution_result_index(result)
    result isa Integer && result >= 1 || throw(ArgumentError(
        "result must be a positive integer"))
    return Int(result)
end

function _semantic_constraint(ctx::OpfContext,
                              key::BMOPFTools.OpfModelKey)
    key.kind == :constraint || throw(ArgumentError(
        "an OPF constraint query requires kind=:constraint; got $(key.kind)"))
    constraint = BMOPFTools.opf_object(ctx, key)
    constraint isa JuMP.ConstraintRef || throw(ArgumentError(
        "the object registered for $key is not a scalar or vector JuMP constraint"))
    return constraint
end

function BMOPFTools.opf_primal(ctx::OpfContext,
                               key::BMOPFTools.OpfModelKey; result=1)
    key.kind in (:variable, :parameter, :expression, :objective) ||
        throw(ArgumentError(
            "an OPF primal query requires a variable, parameter, expression, " *
            "or objective key; got $(key.kind)"))
    index = _solution_result_index(result)
    object = BMOPFTools.opf_object(ctx, key)
    object isa Real && return object
    object isa JuMP.AbstractJuMPScalar || throw(ArgumentError(
        "the object registered for $key is not a scalar JuMP object"))
    return JuMP.value(object; result=index)
end

function BMOPFTools.opf_constraint_value(
        ctx::OpfContext, key::BMOPFTools.OpfModelKey; result=1)
    index = _solution_result_index(result)
    return JuMP.value(_semantic_constraint(ctx, key); result=index)
end

function BMOPFTools.opf_constraint_slack(
        ctx::OpfContext, key::BMOPFTools.OpfModelKey; result=1)
    constraint = _semantic_constraint(ctx, key)
    value = JuMP.value(constraint; result=_solution_result_index(result))
    return _slack(value, JuMP.constraint_object(constraint).set)
end

function BMOPFTools.opf_dual(ctx::OpfContext,
                             key::BMOPFTools.OpfModelKey; result=1)
    return JuMP.dual(_semantic_constraint(ctx, key);
                     result=_solution_result_index(result))
end

function BMOPFTools.opf_objective_value(ctx::OpfContext; result=1)
    return JuMP.objective_value(ctx.model;
                                result=_solution_result_index(result))
end

_copy_regularization(record::BMOPFTools.OpfRegularization) =
    BMOPFTools.OpfRegularization(
        record.name, record.method, record.weight, record.units,
        record.term_key, copy(record.targets), record.purpose, record.owner,
        deepcopy(record.metadata))

function BMOPFTools.register_opf_regularization!(
        ctx::OpfContext, name::Symbol; method::Symbol, weight::Real,
        term_key::BMOPFTools.OpfModelKey, targets=BMOPFTools.OpfModelKey[],
        purpose::AbstractString, units::Symbol=:dimensionless,
        owner::Symbol=:downstream, metadata=Dict{String,Any}(),
        replace::Bool=false)
    isempty(string(name)) && throw(ArgumentError(
        "regularization name must be non-empty"))
    isempty(string(method)) && throw(ArgumentError(
        "regularization method must be non-empty"))
    haskey(ctx.regularizations, name) && !replace && throw(ArgumentError(
        "OPF regularization name already registered: '$name'"))
    weight_value = Float64(weight)
    isfinite(weight_value) && weight_value >= 0 || throw(ArgumentError(
        "regularization weight must be finite and non-negative"))
    isempty(strip(purpose)) && throw(ArgumentError(
        "regularization purpose must be non-empty"))
    term_key.kind == :objective || throw(ArgumentError(
        "regularization term_key must have kind=:objective"))
    haskey(ctx.objects, term_key) || throw(ArgumentError(
        "regularization objective term is not registered: $term_key"))
    target_keys = targets isa BMOPFTools.OpfModelKey ?
                  BMOPFTools.OpfModelKey[targets] :
                  BMOPFTools.OpfModelKey[targets...]
    length(unique(target_keys)) == length(target_keys) || throw(ArgumentError(
        "a regularization declaration cannot repeat a target"))
    for target in target_keys
        haskey(ctx.objects, target) || throw(ArgumentError(
            "regularization target is not registered: $target"))
    end
    metadata isa AbstractDict || throw(ArgumentError(
        "regularization metadata must be a dictionary"))
    metadata_copy = Dict{String,Any}(
        string(key) => deepcopy(value) for (key, value) in metadata)
    try
        _canonical_sha256(metadata_copy)
    catch err
        throw(ArgumentError(
            "regularization metadata is not deterministically hashable: " *
            sprint(showerror, err)))
    end
    record = BMOPFTools.OpfRegularization(
        name, method, weight_value, units, term_key, target_keys,
        String(purpose), owner, metadata_copy)
    ctx.regularizations[name] = record
    return _copy_regularization(record)
end

function BMOPFTools.opf_regularizations(ctx::OpfContext)
    return Dict(name => _copy_regularization(record)
        for (name, record) in ctx.regularizations)
end

const _DIFFERENTIABILITY_ANNOTATION_KINDS = Set((
    :nonsmooth_operator, :dynamic_branch,
    :unsupported_parameter_location))

_copy_differentiability_annotation(
        record::BMOPFTools.OpfDifferentiabilityAnnotation) =
    BMOPFTools.OpfDifferentiabilityAnnotation(
        record.name, record.kind, record.description, record.owner, record.key,
        record.blocking, deepcopy(record.metadata))

function BMOPFTools.register_opf_differentiability_annotation!(
        ctx::OpfContext, name::Symbol; kind::Symbol,
        description::AbstractString, owner::Symbol=:downstream, key=nothing,
        blocking::Bool=true, metadata=Dict{String,Any}(),
        replace::Bool=false)
    isempty(string(name)) && throw(ArgumentError(
        "differentiability annotation name must be non-empty"))
    kind in _DIFFERENTIABILITY_ANNOTATION_KINDS || throw(ArgumentError(
        "unsupported differentiability annotation kind '$kind'; expected " *
        ":nonsmooth_operator, :dynamic_branch, or " *
        ":unsupported_parameter_location"))
    isempty(strip(description)) && throw(ArgumentError(
        "differentiability annotation description must be non-empty"))
    (key === nothing || key isa BMOPFTools.OpfModelKey ||
     key isa BMOPFTools.OpfCoefficientKey) || throw(ArgumentError(
        "differentiability annotation key must be nothing, OpfModelKey, or " *
        "OpfCoefficientKey"))
    haskey(ctx.differentiability_annotations, name) && !replace &&
        throw(ArgumentError(
            "OPF differentiability annotation already registered: '$name'"))
    metadata isa AbstractDict || throw(ArgumentError(
        "differentiability annotation metadata must be a dictionary"))
    metadata_copy = Dict{String,Any}(
        string(metadata_key) => deepcopy(value)
        for (metadata_key, value) in metadata)
    try
        _canonical_sha256(metadata_copy)
    catch err
        throw(ArgumentError(
            "differentiability annotation metadata is not deterministically " *
            "hashable: " * sprint(showerror, err)))
    end
    record = BMOPFTools.OpfDifferentiabilityAnnotation(
        name, kind, String(description), owner, key, blocking, metadata_copy)
    ctx.differentiability_annotations[name] = record
    return _copy_differentiability_annotation(record)
end

function BMOPFTools.opf_differentiability_annotations(ctx::OpfContext)
    return Dict(name => _copy_differentiability_annotation(record)
        for (name, record) in ctx.differentiability_annotations)
end

function _canonical_write(io::IO, value)
    if value === nothing
        write(io, "n;")
    elseif value === missing
        write(io, "m;")
    elseif value isa Bool
        write(io, value ? "b1;" : "b0;")
    elseif value isa Integer
        text = string(value)
        write(io, "i", string(ncodeunits(text)), ":", text, ";")
    elseif value isa AbstractFloat
        text = value isa Union{Float16,Float32,Float64} ?
               string(typeof(value), ":", bitstring(value)) :
               string(typeof(value), ":", value)
        write(io, "f", string(ncodeunits(text)), ":", text, ";")
    elseif value isa Rational
        write(io, "r{")
        _canonical_write(io, numerator(value))
        _canonical_write(io, denominator(value))
        write(io, "};")
    elseif value isa Complex
        write(io, "c{")
        _canonical_write(io, real(value))
        _canonical_write(io, imag(value))
        write(io, "};")
    elseif value isa AbstractString
        write(io, "s", string(ncodeunits(value)), ":", value, ";")
    elseif value isa Symbol
        text = string(value)
        write(io, "y", string(ncodeunits(text)), ":", text, ";")
    elseif value isa BMOPFTools.OpfModelKey
        _canonical_write(io, (value.kind, value.family, value.index))
    elseif value isa NamedTuple
        _canonical_write(io, Dict(string(key) => getfield(value, key)
                                  for key in keys(value)))
    elseif value isa AbstractDict
        entries = Tuple{String,Vector{UInt8},Any}[]
        for (key, item) in value
            key_bytes = _canonical_bytes(key)
            push!(entries, (bytes2hex(key_bytes), key_bytes, item))
        end
        sort!(entries; by=first)
        write(io, "d", string(length(entries)), "{")
        for (_, key_bytes, item) in entries
            write(io, key_bytes)
            _canonical_write(io, item)
        end
        write(io, "};")
    elseif value isa AbstractArray
        write(io, "a", string(ndims(value)), "[")
        for dimension in size(value)
            _canonical_write(io, dimension)
        end
        write(io, "]")
        write(io, "{")
        for item in value
            _canonical_write(io, item)
        end
        write(io, "};")
    elseif value isa Tuple
        write(io, "t", string(length(value)), "{")
        for item in value
            _canonical_write(io, item)
        end
        write(io, "};")
    elseif value isa AbstractSet
        items = sort!([_canonical_bytes(item) for item in value]; by=bytes2hex)
        write(io, "e", string(length(items)), "{")
        foreach(item -> write(io, item), items)
        write(io, "};")
    else
        throw(ArgumentError(
            "unsupported canonical-hash value of type $(typeof(value))"))
    end
    return io
end

function _assert_canonical_acyclic(value, active=Base.IdSet{Any}())
    if value isa Union{AbstractDict,AbstractArray,AbstractSet}
        value in active && throw(ArgumentError(
            "canonical-hash values cannot contain reference cycles"))
        push!(active, value)
        if value isa AbstractDict
            for (key, item) in value
                _assert_canonical_acyclic(key, active)
                _assert_canonical_acyclic(item, active)
            end
        else
            for item in value
                _assert_canonical_acyclic(item, active)
            end
        end
        delete!(active, value)
    elseif value isa NamedTuple || value isa Tuple
        for item in value
            _assert_canonical_acyclic(item, active)
        end
    end
    return nothing
end

function _canonical_bytes(value)
    _assert_canonical_acyclic(value)
    io = IOBuffer()
    _canonical_write(io, value)
    return take!(io)
end

_canonical_sha256(value) = bytes2hex(SHA.sha256(_canonical_bytes(value)))

_stable_model_text(value) =
    sprint(show, value; context=:compact => true)

function _model_structure_record(ctx::OpfContext)
    variables = Dict{String,Any}[
        Dict(
            "name" => JuMP.name(variable),
            "index" => repr(JuMP.index(variable)),
            "binary" => JuMP.is_binary(variable),
            "integer" => JuMP.is_integer(variable),
            "parameter" => JuMP.is_parameter(variable),
        ) for variable in JuMP.all_variables(ctx.model)
    ]
    sort!(variables; by=record -> (record["name"], record["index"]))

    constraints = Dict{String,Any}[]
    constraint_types = sort!(collect(JuMP.list_of_constraint_types(ctx.model));
        by=types -> (string(first(types)), string(last(types))))
    for (F, S) in constraint_types
        # MOI stores a parameter's mutable value in a Parameter set. Its
        # existence is represented by variables[i]["parameter"], while its
        # current value belongs exclusively in _parameter_state_record.
        S <: JuMP.MOI.Parameter && continue
        for constraint in JuMP.all_constraints(ctx.model, F, S)
            object = JuMP.constraint_object(constraint)
            push!(constraints, Dict{String,Any}(
                "function_type" => string(F),
                "set_type" => string(S),
                "name" => JuMP.name(constraint),
                "function" => _stable_model_text(object.func),
                "set" => _stable_model_text(object.set),
            ))
        end
    end
    sort!(constraints; by=record -> (
        record["function_type"], record["set_type"], record["name"],
        record["function"], record["set"]))
    semantic_keys = [_model_key_record(key) for key in
        sort!(collect(keys(ctx.objects));
            by=key -> (string(key.kind), string(key.family), repr(key.index)))]
    return Dict{String,Any}(
        "schema" => "BMOPFTools.opf_model_structure/v1",
        "problem" => string(ctx.manifest.problem),
        "formulation" => string(ctx.manifest.formulation),
        "per_unit" => ctx.manifest.per_unit,
        "s_base" => ctx.manifest.s_base,
        "completed_stages" => string.(ctx.manifest.stages),
        "variables" => variables,
        "constraints" => constraints,
        "objective" => Dict{String,Any}(
            "sense" => string(JuMP.objective_sense(ctx.model)),
            "function_type" => string(JuMP.objective_function_type(ctx.model)),
            "function" => _stable_model_text(JuMP.objective_function(ctx.model)),
        ),
        "semantic_keys" => semantic_keys,
    )
end

function _parameter_state_record(ctx::OpfContext)
    records = Dict{String,Any}[]
    for variable in JuMP.all_variables(ctx.model)
        JuMP.is_parameter(variable) || continue
        push!(records, Dict{String,Any}(
            "name" => JuMP.name(variable),
            "index" => repr(JuMP.index(variable)),
            "value" => JuMP.parameter_value(variable),
        ))
    end
    sort!(records; by=record -> (record["name"], record["index"]))
    return records
end

function _regularization_record(record::BMOPFTools.OpfRegularization)
    return Dict{String,Any}(
        "name" => string(record.name),
        "method" => string(record.method),
        "weight" => record.weight,
        "units" => string(record.units),
        "term_key" => _model_key_record(record.term_key),
        "targets" => [_model_key_record(key) for key in record.targets],
        "purpose" => record.purpose,
        "owner" => string(record.owner),
        "metadata" => deepcopy(record.metadata),
    )
end

function _differentiability_annotation_record(
        record::BMOPFTools.OpfDifferentiabilityAnnotation)
    key = if record.key isa BMOPFTools.OpfModelKey
        Dict{String,Any}("type" => "model", "value" =>
            _model_key_record(record.key))
    elseif record.key isa BMOPFTools.OpfCoefficientKey
        Dict{String,Any}("type" => "coefficient", "value" =>
            _coefficient_key_record(record.key))
    else
        nothing
    end
    return Dict{String,Any}(
        "name" => string(record.name),
        "kind" => string(record.kind),
        "description" => record.description,
        "owner" => string(record.owner),
        "key" => key,
        "blocking" => record.blocking,
        "metadata" => deepcopy(record.metadata),
    )
end

function BMOPFTools.opf_research_hashes(ctx::OpfContext)
    regularizations = [_regularization_record(ctx.regularizations[name])
        for name in sort!(collect(keys(ctx.regularizations)))]
    annotations = [_differentiability_annotation_record(
            ctx.differentiability_annotations[name])
        for name in sort!(collect(keys(ctx.differentiability_annotations)))]
    return Dict{String,Any}(
        "schema" => "BMOPFTools.opf_research_hashes/v1",
        "algorithm" => "SHA-256",
        "canonicalization" => "BMOPFTools.canonical_value/v1",
        "prepared_working_network_sha256" => _canonical_sha256(ctx.net),
        "model_structure_sha256" =>
            _canonical_sha256(_model_structure_record(ctx)),
        "parameter_state_sha256" =>
            _canonical_sha256(_parameter_state_record(ctx)),
        "regularization_declarations_sha256" =>
            _canonical_sha256(regularizations),
        "differentiability_annotations_sha256" =>
            _canonical_sha256(annotations),
    )
end

_copy_parameter_binding(binding::BMOPFTools.OpfParameterBinding) =
    BMOPFTools.OpfParameterBinding(
        binding.key, binding.parameter, copy(binding.targets), copy(binding.links),
        binding.scope, copy(binding.aliases), binding.input_unit,
        binding.working_unit, binding.to_working_scale, binding.owner)

function _parameter_key(ctx::OpfContext, identifier)
    if identifier isa BMOPFTools.OpfModelKey
        return identifier
    elseif identifier isa Symbol || identifier isa AbstractString
        alias = Symbol(identifier)
        haskey(ctx.parameter_aliases, alias) ||
            throw(KeyError("no OPF parameter registered for alias '$alias'"))
        return ctx.parameter_aliases[alias]
    end
    throw(ArgumentError("an OPF parameter identifier must be an OpfModelKey, " *
                        "Symbol, or string alias"))
end

function BMOPFTools.bind_opf_parameter!(
        ctx::OpfContext, key::BMOPFTools.OpfModelKey, parameter, targets;
        scope=BMOPFTools.OpfParameterScope(:snapshot), aliases=Symbol[],
        input_unit::Symbol=:working, working_unit::Symbol=:working,
        to_working_scale::Real=1.0, owner::Symbol=:downstream,
        role::Symbol=:decision)
    ctx.lifecycle[] == :building || throw(ArgumentError(
        "OPF parameters may only be bound while the context is building"))
    key.kind == :parameter || throw(ArgumentError(
        "an OPF parameter key must have kind=:parameter; got $(key.kind)"))
    role == :structural && throw(ArgumentError(
        "structural OPF parameters require rebuilding the model; topology, " *
        "terminal maps, and dimensions cannot be parameter-bound"))
    role in (:decision, :coefficient) || throw(ArgumentError(
        "OPF parameter role must be :decision, :coefficient, or :structural"))
    haskey(ctx.parameter_bindings, key) && throw(ArgumentError(
        "OPF parameter key already bound: $key"))
    haskey(ctx.objects, key) && throw(ArgumentError(
        "OPF model object key already registered: $key"))

    JuMP.is_parameter(parameter) || throw(ArgumentError(
        "parameter must be a JuMP variable created with JuMP.Parameter"))
    JuMP.owner_model(parameter) === ctx.model || throw(ArgumentError(
        "parameter belongs to a different JuMP model"))
    target_keys = targets isa BMOPFTools.OpfModelKey ?
                  BMOPFTools.OpfModelKey[targets] :
                  BMOPFTools.OpfModelKey[targets...]
    isempty(target_keys) && throw(ArgumentError(
        "an OPF parameter binding requires at least one target"))
    length(unique(target_keys)) == length(target_keys) || throw(ArgumentError(
        "an OPF parameter binding cannot repeat a target"))
    scale = Float64(to_working_scale)
    isfinite(scale) && !iszero(scale) || throw(ArgumentError(
        "to_working_scale must be finite and non-zero"))
    parameter_scope = scope isa Symbol ? BMOPFTools.OpfParameterScope(scope) : scope
    parameter_scope isa BMOPFTools.OpfParameterScope || throw(ArgumentError(
        "scope must be an OpfParameterScope or scope-kind Symbol"))
    alias_symbols = Symbol[Symbol(alias) for alias in aliases]
    length(unique(alias_symbols)) == length(alias_symbols) || throw(ArgumentError(
        "an OPF parameter binding cannot repeat an alias"))
    for alias in alias_symbols
        haskey(ctx.parameter_aliases, alias) && throw(ArgumentError(
            "OPF parameter alias already registered: '$alias'"))
    end

    target_vars = Any[]
    for target_key in target_keys
        target_key.kind == :variable || throw(ArgumentError(
            "OPF parameter targets must have kind=:variable; got $target_key"))
        haskey(ctx.objects, target_key) || throw(ArgumentError(
            "unknown OPF parameter target: $target_key"))
        target = ctx.objects[target_key]
        target isa JuMP.AbstractVariableRef || throw(ArgumentError(
            "OPF parameter target is not a scalar JuMP variable: $target_key"))
        JuMP.is_parameter(target) && throw(ArgumentError(
            "an OPF parameter cannot target another JuMP parameter: $target_key"))
        JuMP.owner_model(target) === ctx.model || throw(ArgumentError(
            "OPF parameter target belongs to a different JuMP model: $target_key"))
        push!(target_vars, target)
    end

    link_keys = [BMOPFTools.OpfModelKey(
        :constraint, :parameter_link, (key, target_key))
        for target_key in target_keys]
    for link_key in link_keys
        haskey(ctx.objects, link_key) && throw(ArgumentError(
            "OPF parameter-link object key already registered: $link_key"))
    end

    # All validation happens before the first mutation, so malformed bindings
    # cannot leave aliases, registry entries, or partial link constraints behind.
    links = Any[]
    for (link_key, target) in zip(link_keys, target_vars)
        link = JuMP.@constraint(ctx.model, target == scale * parameter)
        push!(links, link)
        BMOPFTools.register_opf_object!(ctx, link_key, link)
    end
    binding = BMOPFTools.OpfParameterBinding(
        key, parameter, target_keys, links, parameter_scope, alias_symbols,
        input_unit, working_unit, scale, owner)
    ctx.parameter_bindings[key] = binding
    ctx.objects[key] = parameter
    for alias in alias_symbols
        ctx.parameter_aliases[alias] = key
    end
    return _copy_parameter_binding(binding)
end

function BMOPFTools.opf_parameter_binding(ctx::OpfContext, identifier)
    key = _parameter_key(ctx, identifier)
    haskey(ctx.parameter_bindings, key) ||
        throw(KeyError("no OPF parameter binding registered for $key"))
    return _copy_parameter_binding(ctx.parameter_bindings[key])
end

BMOPFTools.opf_parameter(ctx::OpfContext, identifier) =
    BMOPFTools.opf_parameter_binding(ctx, identifier).parameter

function BMOPFTools.opf_parameter_bindings(ctx::OpfContext)
    return Dict(key => _copy_parameter_binding(binding)
                for (key, binding) in ctx.parameter_bindings)
end

function BMOPFTools.opf_coefficient_provider(
        ctx::OpfContext, key::BMOPFTools.OpfCoefficientKey)
    return get(ctx.build_spec.coefficient_providers, key, nothing)
end

function BMOPFTools.opf_coefficient(
        ctx::OpfContext, key::BMOPFTools.OpfCoefficientKey, default)
    provider = BMOPFTools.opf_coefficient_provider(ctx, key)
    provider === nothing && return default
    ctx.coefficient_usage[key] = get(ctx.coefficient_usage, key, 0) + 1
    value = provider.provide(ctx, key, default)
    value === nothing && throw(ArgumentError(
        "OPF coefficient provider '$(provider.owner)' returned nothing for $key"))
    return value
end

_native_coefficient(ctx::OpfContext, category::Symbol, family::Symbol,
                    component, field::Symbol, index, default) =
    BMOPFTools.opf_coefficient(ctx,
        BMOPFTools.OpfCoefficientKey(
            category, family, string(component), field, index), default)

BMOPFTools.opf_coefficient_providers(ctx::OpfContext) =
    copy(ctx.build_spec.coefficient_providers)

BMOPFTools.opf_coefficient_usage(ctx::OpfContext) = copy(ctx.coefficient_usage)

struct _KKTDiagnosticOwner end

BMOPFTools.opf_kkt_diagnostic(ctx::OpfContext) =
    get(ctx.extension_state, _KKTDiagnosticOwner, nothing)

function BMOPFTools.opf_checked_kkt_factorization(
        ctx::OpfContext; pivot_tolerance::Real=1e-10)
    tolerance = Float64(pivot_tolerance)
    isfinite(tolerance) && 0.0 <= tolerance < 1.0 || throw(ArgumentError(
        "pivot_tolerance must be finite and in [0, 1)"))
    return function checked_kkt_factorization(matrix, diffopt_model)
        dimension = size(matrix, 1)
        size(matrix, 2) == dimension || throw(BMOPFTools.OpfDifferentiationError(
            "KKT Jacobian is not square: size $(size(matrix))"))
        factorization = LinearAlgebra.lu(matrix; check=false)
        successful = try
            LinearAlgebra.issuccess(factorization)
        catch
            hasproperty(factorization, :status) && factorization.status == 0
        end
        pivots = try
            abs.(LinearAlgebra.diag(factorization.U))
        catch
            Float64[]
        end
        pivot_ratio = if isempty(pivots) || any(x -> !isfinite(x), pivots)
            nothing
        else
            largest = maximum(pivots; init=0.0)
            iszero(largest) ? 0.0 : minimum(pivots; init=largest) / largest
        end
        rejected = !successful || pivot_ratio === nothing ||
                   pivot_ratio <= tolerance
        message = if !successful
            "KKT LU factorization is singular"
        elseif pivot_ratio === nothing
            "KKT LU factorization produced unavailable or non-finite pivots"
        elseif rejected
            "KKT LU pivot ratio $(pivot_ratio) is at or below the rejection tolerance $(tolerance)"
        else
            "KKT LU factorization passed the pivot-ratio guard"
        end
        diagnostic = BMOPFTools.OpfKKTDiagnostic(
            rejected ? :rejected : :accepted, dimension, pivot_ratio,
            tolerance, message)
        ctx.extension_state[_KKTDiagnosticOwner] = diagnostic
        rejected && throw(BMOPFTools.OpfDifferentiationError(
            "$message; refusing an unqualified implicit derivative"))
        return factorization
    end
end

_activity_bound_scale(set::JuMP.MOI.LessThan) = abs(set.upper)
_activity_bound_scale(set::JuMP.MOI.GreaterThan) = abs(set.lower)
_activity_bound_scale(set::JuMP.MOI.Interval) =
    max(abs(set.lower), abs(set.upper))

function _constraint_activity(model; active_tolerance, transition_tolerance,
                              dual_tolerance)
    active = String[]
    near = String[]
    weak = String[]
    violated = String[]
    inactive_slacks = Float64[]
    unsupported = 0
    has_duals = try
        JuMP.has_duals(model)
    catch err
        _rethrow_fatal(err)
        false
    end
    for (F, S) in JuMP.list_of_constraint_types(model)
        (S <: JuMP.MOI.LessThan || S <: JuMP.MOI.GreaterThan ||
         S <: JuMP.MOI.Interval) || continue
        for (ordinal, constraint) in enumerate(JuMP.all_constraints(model, F, S))
            value = try
                JuMP.value(constraint)
            catch err
                _rethrow_fatal(err)
                unsupported += 1
                continue
            end
            set = JuMP.constraint_object(constraint).set
            slack = _slack(value, set)
            slack === nothing && continue
            scale = 1.0 + abs(value) + _activity_bound_scale(set)
            normalized_slack = slack / scale
            name = JuMP.name(constraint)
            label = isempty(name) ?
                "$(F) in $(S) #$ordinal" : name
            if normalized_slack < -active_tolerance
                push!(violated, label)
            elseif abs(normalized_slack) <= active_tolerance
                push!(active, label)
                if has_duals
                    multiplier = try
                        abs(JuMP.dual(constraint))
                    catch err
                        _rethrow_fatal(err)
                        NaN
                    end
                    (!isfinite(multiplier) || multiplier <= dual_tolerance) &&
                        push!(weak, label)
                end
            else
                push!(inactive_slacks, normalized_slack)
                normalized_slack <= transition_tolerance && push!(near, label)
            end
        end
    end
    return sort!(active), sort!(near), sort!(weak), sort!(violated),
           isempty(inactive_slacks) ? nothing : minimum(inactive_slacks), unsupported
end

function BMOPFTools.opf_differentiability_report(
        ctx::OpfContext; active_tolerance::Real=1e-7,
        transition_tolerance::Real=1e-5, dual_tolerance::Real=1e-7)
    active_tol = Float64(active_tolerance)
    transition_tol = Float64(transition_tolerance)
    dual_tol = Float64(dual_tolerance)
    0.0 <= active_tol < transition_tol || throw(ArgumentError(
        "require 0 ≤ active_tolerance < transition_tolerance"))
    dual_tol >= 0.0 || throw(ArgumentError(
        "dual_tolerance must be non-negative"))
    status = JuMP.termination_status(ctx.model)
    successful = status in (
        JuMP.MOI.OPTIMAL, JuMP.MOI.LOCALLY_SOLVED,
        JuMP.MOI.ALMOST_OPTIMAL, JuMP.MOI.ALMOST_LOCALLY_SOLVED)
    discrete = sort!(String[
        JuMP.name(variable) for variable in JuMP.all_variables(ctx.model)
        if JuMP.is_binary(variable) || JuMP.is_integer(variable)
    ])
    inequality_count = 0
    for (F, S) in JuMP.list_of_constraint_types(ctx.model)
        if S <: JuMP.MOI.LessThan || S <: JuMP.MOI.GreaterThan ||
           S <: JuMP.MOI.Interval
            inequality_count += JuMP.num_constraints(ctx.model, F, S)
        end
    end
    coefficient_keys = sort!(collect(keys(ctx.build_spec.coefficient_providers));
        by=key -> (string(key.category), string(key.family), key.component,
                   string(key.field), repr(key.index)))
    unused = [key for key in coefficient_keys
              if get(ctx.coefficient_usage, key, 0) == 0]
    parameter_keys = sort!(collect(keys(ctx.parameter_bindings));
        by=key -> (string(key.family), repr(key.index)))
    active, near, weak, violated, minimum_inactive_slack, activity_failures = successful ?
        _constraint_activity(ctx.model; active_tolerance=active_tol,
            transition_tolerance=transition_tol, dual_tolerance=dual_tol) :
        (String[], String[], String[], String[], nothing, 0)
    kkt_diagnostic = BMOPFTools.opf_kkt_diagnostic(ctx)
    annotations = [_copy_differentiability_annotation(
            ctx.differentiability_annotations[name])
        for name in sort!(collect(keys(ctx.differentiability_annotations)))]
    nonsmooth = [record for record in annotations
                 if record.kind == :nonsmooth_operator]
    branches = [record for record in annotations
                if record.kind == :dynamic_branch]
    unsupported = [record for record in annotations
                   if record.kind == :unsupported_parameter_location]
    qualifications = String[
        "The IVR-EN OPF is nonconvex; sensitivities describe the selected local primal-dual solution, not a certified global optimizer.",
        "This report does not certify KKT nonsingularity, LICQ, strict complementarity, or second-order sufficiency.",
    ]
    inequality_count > 0 && push!(qualifications,
        "The model has $inequality_count scalar inequality constraints; derivatives are local to the solved active set and should be checked near transitions.")
    any(op -> op isa BuiltinSoftplus, values(ctx.relu_ops)) &&
        push!(qualifications,
            "Smooth droop explicitly uses the native log1p/exp softplus encoding; verify its numerical range for the chosen scaling.")
    activity_failures > 0 && push!(qualifications,
        "$activity_failures inequality constraint(s) could not be evaluated by the active-set scan.")
    any(key -> key.category == :physics &&
               get(ctx.coefficient_usage, key, 0) > 0, coefficient_keys) &&
        push!(qualifications,
            "Parameterized physics coefficients can change matrix rank, passivity, and conditioning; this report does not certify those properties after an update.")
    !isempty(discrete) && push!(qualifications,
        "Discrete variables are present and are not supported by smooth implicit differentiation.")
    !isempty(unused) && push!(qualifications,
        "$(length(unused)) registered coefficient provider(s) were not consumed; check semantic keys and device ownership.")
    !isempty(near) && push!(qualifications,
        "$(length(near)) inactive inequality constraint(s) are within the active-set transition tolerance; derivatives may be discontinuous under small perturbations.")
    !isempty(weak) && push!(qualifications,
        "$(length(weak)) active inequality constraint(s) have zero, unavailable, or small multipliers; strict complementarity is not supported by the observed solution.")
    !isempty(violated) && push!(qualifications,
        "$(length(violated)) inequality constraint(s) exceed the normalized primal-feasibility tolerance.")
    for (records, label) in ((nonsmooth, "nonsmooth operator"),
                             (branches, "parameter-dependent construction branch"),
                             (unsupported, "unsupported parameter location"))
        isempty(records) && continue
        blocking_count = count(record -> record.blocking, records)
        suffix = blocking_count == 0 ?
            "All are disclosed as nonblocking by their owners." :
            "$blocking_count are marked blocking."
        push!(qualifications,
            "$(length(records)) explicitly declared $label annotation(s). " *
            suffix)
    end
    kkt_diagnostic !== nothing && kkt_diagnostic.status == :rejected &&
        push!(qualifications, kkt_diagnostic.message)
    ctx.lifecycle[] == :kcl_finalized || push!(qualifications,
        "KCL construction is not finalized.")
    successful || push!(qualifications,
        "The model does not have a successful termination status; do not report an unqualified gradient.")
    ready = ctx.lifecycle[] == :kcl_finalized && successful &&
            isempty(discrete) && isempty(unused) && isempty(near) &&
            isempty(weak) && isempty(violated) && activity_failures == 0 &&
            !any(record -> record.blocking, annotations) &&
            (kkt_diagnostic === nothing || kkt_diagnostic.status == :accepted)
    return BMOPFTools.OpfDifferentiabilityReport(
        ready, ctx.lifecycle[], string(status), parameter_keys,
        coefficient_keys, unused, discrete,
        inequality_count, active, near, weak, violated,
        nonsmooth, branches, unsupported,
        minimum_inactive_slack, kkt_diagnostic, qualifications)
end

function _rethrow_fatal(err)
    err isa InterruptException && throw(err)
    err isa StackOverflowError && throw(err)
    err isa OutOfMemoryError && throw(err)
    return nothing
end

function _safe_provenance(f::Function)
    try
        return f()
    catch err
        _rethrow_fatal(err)
        return nothing
    end
end

function _constraint_residual_summary(model)
    JuMP.result_count(model) > 0 || return Dict{String,Any}(
        "evaluated_constraints" => 0,
        "unsupported_constraints" => 0,
        "max_primal_violation" => nothing,
        "max_normalized_primal_violation" => nothing,
        "max_complementarity_product" => nothing,
    )
    evaluated = 0
    unsupported = 0
    max_violation = 0.0
    max_normalized = 0.0
    complementarity = Float64[]
    has_duals = try
        JuMP.has_duals(model)
    catch err
        _rethrow_fatal(err)
        false
    end
    for (F, S) in JuMP.list_of_constraint_types(model)
        for constraint in JuMP.all_constraints(model, F, S)
            value = try
                JuMP.value(constraint)
            catch err
                _rethrow_fatal(err)
                unsupported += 1
                continue
            end
            set = JuMP.constraint_object(constraint).set
            violation = try
                Float64(JuMP.MOI.Utilities.distance_to_set(value, set))
            catch err
                _rethrow_fatal(err)
                unsupported += 1
                continue
            end
            evaluated += 1
            max_violation = max(max_violation, violation)
            value_scale = try
                LinearAlgebra.norm(value)
            catch err
                _rethrow_fatal(err)
                abs(value)
            end
            max_normalized = max(max_normalized, violation / (1.0 + value_scale))
            if has_duals && (set isa JuMP.MOI.LessThan ||
                             set isa JuMP.MOI.GreaterThan ||
                             set isa JuMP.MOI.Interval)
                slack = _slack(value, set)
                multiplier = try
                    abs(JuMP.dual(constraint))
                catch err
                    _rethrow_fatal(err)
                    nothing
                end
                if slack !== nothing && multiplier !== nothing &&
                   isfinite(slack) && isfinite(multiplier)
                    push!(complementarity, abs(slack * multiplier))
                end
            end
        end
    end
    return Dict{String,Any}(
        "evaluated_constraints" => evaluated,
        "unsupported_constraints" => unsupported,
        "max_primal_violation" => evaluated == 0 ? nothing : max_violation,
        "max_normalized_primal_violation" =>
            evaluated == 0 ? nothing : max_normalized,
        "max_complementarity_product" =>
            isempty(complementarity) ? nothing : maximum(complementarity),
    )
end

_model_key_record(key::BMOPFTools.OpfModelKey) = Dict{String,Any}(
    "kind" => string(key.kind), "family" => string(key.family),
    "index" => repr(key.index))

_coefficient_key_record(key::BMOPFTools.OpfCoefficientKey) = Dict{String,Any}(
    "category" => string(key.category), "family" => string(key.family),
    "component" => key.component, "field" => string(key.field),
    "index" => repr(key.index))

function BMOPFTools.opf_research_provenance(
        ctx::OpfContext; active_tolerance::Real=1e-7,
        transition_tolerance::Real=1e-5, dual_tolerance::Real=1e-7)
    model = ctx.model
    report = BMOPFTools.opf_differentiability_report(ctx;
        active_tolerance, transition_tolerance, dual_tolerance)
    manifest = ctx.manifest

    parameter_records = Dict{String,Any}[]
    for key in sort!(collect(keys(ctx.parameter_bindings));
                     by=key -> (string(key.family), repr(key.index)))
        binding = ctx.parameter_bindings[key]
        push!(parameter_records, Dict{String,Any}(
            "key" => _model_key_record(key),
            "scope" => Dict{String,Any}(
                "kind" => string(binding.scope.kind),
                "id" => binding.scope.id === nothing ? nothing :
                        repr(binding.scope.id)),
            "aliases" => string.(binding.aliases),
            "input_unit" => string(binding.input_unit),
            "working_unit" => string(binding.working_unit),
            "to_working_scale" => binding.to_working_scale,
            "owner" => string(binding.owner),
            "value" => _safe_provenance(
                () -> Float64(JuMP.parameter_value(binding.parameter))),
            "targets" => [_model_key_record(target) for target in binding.targets],
        ))
    end

    coefficient_records = Dict{String,Any}[]
    for key in sort!(collect(keys(ctx.build_spec.coefficient_providers));
                     by=key -> (string(key.category), string(key.family),
                         key.component, string(key.field), repr(key.index)))
        provider = ctx.build_spec.coefficient_providers[key]
        push!(coefficient_records, Dict{String,Any}(
            "key" => _coefficient_key_record(key),
            "owner" => string(provider.owner),
            "usage_count" => get(ctx.coefficient_usage, key, 0),
        ))
    end

    owner_records = Dict{String,Any}[
        Dict("component" => repr(component), "owner" => string(owner))
        for (component, owner) in sort!(collect(manifest.component_owners);
                                       by=entry -> repr(first(entry)))]
    initialized = count(variable ->
        _safe_provenance(() -> JuMP.start_value(variable)) !== nothing,
        JuMP.all_variables(model))
    objective = _safe_provenance(() -> Float64(JuMP.objective_value(model)))
    objective !== nothing && !isfinite(objective) && (objective = nothing)
    kkt = report.kkt_diagnostic
    regularization_records = [_regularization_record(ctx.regularizations[name])
        for name in sort!(collect(keys(ctx.regularizations)))]
    annotation_records = [_differentiability_annotation_record(
            ctx.differentiability_annotations[name])
        for name in sort!(collect(keys(ctx.differentiability_annotations)))]
    object_keys = sort!(collect(keys(ctx.objects));
        by=key -> (string(key.kind), string(key.family), repr(key.index)))
    reference_counts = Dict{String,Any}()
    reference_records = Dict{String,Any}[]
    objective_records = Dict{String,Any}[]
    for key in object_keys
        kind = string(key.kind)
        reference_counts[kind] = get(reference_counts, kind, 0) + 1
        push!(reference_records, Dict{String,Any}(
            "key" => _model_key_record(key),
            "object_type" => string(typeof(ctx.objects[key])),
        ))
        if key.kind == :objective
            value = _safe_provenance(() ->
                Float64(BMOPFTools.opf_primal(ctx, key)))
            value !== nothing && !isfinite(value) && (value = nothing)
            push!(objective_records, Dict{String,Any}(
                "key" => _model_key_record(key), "value" => value))
        end
    end

    return Dict{String,Any}(
        "schema" => "BMOPFTools.opf_research_provenance/v1",
        "hashes" => BMOPFTools.opf_research_hashes(ctx),
        "software" => Dict{String,Any}(
            "julia" => string(VERSION),
            "BMOPFTools" => string(Base.pkgversion(BMOPFTools)),
            "JuMP" => string(Base.pkgversion(JuMP)),
            "Ipopt" => string(Base.pkgversion(Ipopt)),
        ),
        "formulation" => Dict{String,Any}(
            "problem" => string(manifest.problem),
            "formulation" => string(manifest.formulation),
            "per_unit" => manifest.per_unit,
            "s_base" => manifest.s_base,
            "lifecycle" => string(ctx.lifecycle[]),
            "completed_stages" => string.(manifest.stages),
            "component_owners" => owner_records,
        ),
        "solver" => Dict{String,Any}(
            "name" => _safe_provenance(() -> JuMP.solver_name(model)),
            "version" => _safe_provenance(() ->
                JuMP.MOI.get(JuMP.backend(model), JuMP.MOI.SolverVersion())),
            "termination_status" => string(JuMP.termination_status(model)),
            "raw_status" => _safe_provenance(() -> JuMP.raw_status(model)),
            "primal_status" => string(JuMP.primal_status(model)),
            "dual_status" => string(JuMP.dual_status(model)),
            "result_count" => JuMP.result_count(model),
            "solve_time_s" => _safe_provenance(() -> JuMP.solve_time(model)),
            "barrier_iterations" => _safe_provenance(() -> Int(
                JuMP.MOI.get(model, JuMP.MOI.BarrierIterations()))),
            "objective_value" => objective,
        ),
        "model" => Dict{String,Any}(
            "variables" => JuMP.num_variables(model),
            "constraints" => sum(JuMP.num_constraints(model, F, S)
                for (F, S) in JuMP.list_of_constraint_types(model)),
            "initialized_variables" => initialized,
            "residuals" => _constraint_residual_summary(model),
        ),
        "semantic_references" => Dict{String,Any}(
            "counts_by_kind" => reference_counts,
            "objects" => reference_records,
            "objective_terms" => objective_records,
        ),
        "smoothing" => Dict{String,Any}(
            "volt_var_watt_relative_epsilon" => ctx.relu_eps,
            "softplus_mode" => string(ctx.softplus),
            "registered_softplus_operators" => length(ctx.relu_ops),
            "uses_builtin_softplus" =>
                any(op -> op isa BuiltinSoftplus, values(ctx.relu_ops)),
        ),
        "parameters" => parameter_records,
        "coefficient_providers" => coefficient_records,
        "regularizations" => regularization_records,
        "differentiability_annotations" => annotation_records,
        "differentiability" => Dict{String,Any}(
            "ready" => report.ready,
            "active_tolerance" => Float64(active_tolerance),
            "transition_tolerance" => Float64(transition_tolerance),
            "dual_tolerance" => Float64(dual_tolerance),
            "active_constraints" => copy(report.active_constraints),
            "near_active_constraints" => copy(report.near_active_constraints),
            "weakly_active_constraints" =>
                copy(report.weakly_active_constraints),
            "violated_constraints" => copy(report.violated_constraints),
            "nonsmooth_operators" =>
                string.(getfield.(report.nonsmooth_operators, :name)),
            "dynamic_branches" =>
                string.(getfield.(report.dynamic_branches, :name)),
            "unsupported_parameter_locations" => string.(getfield.(
                report.unsupported_parameter_locations, :name)),
            "minimum_inactive_slack" => report.minimum_inactive_slack,
            "qualifications" => copy(report.qualifications),
            "kkt" => kkt === nothing ? nothing : Dict{String,Any}(
                "status" => string(kkt.status),
                "dimension" => kkt.dimension,
                "pivot_ratio" => kkt.pivot_ratio,
                "tolerance" => kkt.tolerance,
                "message" => kkt.message,
            ),
        ),
    )
end

function BMOPFTools.extension_state!(ctx::OpfContext, owner,
                                     init::Function=() -> Dict{Symbol,Any}())
    return get!(init, ctx.extension_state, owner)
end

# Support Julia's `do` syntax: `extension_state!(ctx, owner) do ... end` passes
# the anonymous function as the first positional argument.
BMOPFTools.extension_state!(init::Function, ctx::OpfContext, owner) =
    BMOPFTools.extension_state!(ctx, owner, init)

function BMOPFTools.register_opf_result_extractor!(ctx::OpfContext,
                                                   owner::Symbol,
                                                   extract!::Function;
                                                   replace::Bool=false)
    if haskey(ctx.result_extractors, owner) && !replace
        throw(ArgumentError("OPF result extractor already registered by '$owner'"))
    end
    ctx.result_extractors[owner] = extract!
    return extract!
end

function _run_result_extractors!(ctx::OpfContext, result::Dict{String,Any})
    for owner in sort!(collect(keys(ctx.result_extractors)))
        ctx.result_extractors[owner](ctx, result)
    end
    return result
end

function BMOPFTools.add_terminal_injection!(ctx::OpfContext,
                                            bus::AbstractString,
                                            terminal::AbstractString,
                                            cr, ci)
    ctx.lifecycle[] == :building || throw(ArgumentError(
        "terminal injections may only be added while the OPF context is " *
        "building; current lifecycle is $(ctx.lifecycle[])"))
    bid = String(bus); tid = String(terminal)
    haskey(ctx.bus_terminals, bid) ||
        throw(ArgumentError("unknown OPF bus '$bid'"))
    tid in ctx.bus_terminals[bid] || throw(ArgumentError(
        "unknown terminal '$tid' on OPF bus '$bid'"))
    _kcl_add!(ctx.kcl_r, ctx.kcl_i, bid, tid, cr, ci)
    return ctx
end

function _register_native_variables!(ctx::OpfContext)
    for (family, collection) in ctx.vars
        if collection isa AbstractDict
            for (index, object) in collection
                key = BMOPFTools.OpfModelKey(:variable, Symbol(family), index)
                BMOPFTools.register_opf_object!(ctx, key, object)
            end
        else
            key = BMOPFTools.OpfModelKey(:variable, Symbol(family))
            BMOPFTools.register_opf_object!(ctx, key, collection)
        end
    end
    return ctx
end

# Fresh per-device injection ledger. Keyed block ("line"/"switch"/"transformer")
# → device id → Vector of (bus, terminal, cr_expr, ci_expr) injected into bus.
_new_branch_ledger() = Dict{String,Any}(
    "line" => Dict{String,Any}(),
    "switch" => Dict{String,Any}(),
    "transformer" => Dict{String,Any}())

# Record one terminal injection for a two-port device into the ledger. `entry`
# is the (block, id) pair identifying the device; nothing disables recording.
function _ledger_add!(branch_inj, entry, bus, terminal, cr_expr, ci_expr)
    branch_inj === nothing && return
    entry === nothing && return
    block, id = entry
    dev = get!(get!(branch_inj, block, Dict{String,Any}()), id, Vector{Any}())
    push!(dev, (bus, terminal, cr_expr, ci_expr))
    return
end

"""
    _add_device_constraints!(ctx)

Add the constraints shared by *every* problem formulation: the voltage source,
all branch/transformer/shunt couplings, and the load/generator/IBR power
equations, each contributing to the KCL accumulators. Voltage and bus-limit
bounds are NOT added here — a build recipe adds them explicitly so that an
unbounded formulation (e.g. power flow) can omit them.
"""
function _add_device_constraints!(ctx::OpfContext)
    _validate_build_spec(ctx)
    _assert_no_parallel_zero_impedance(ctx.net)
    for family in _DEVICE_FAMILY_ORDER
        _build_device_family!(ctx, family)
    end
    return ctx
end

const _DEVICE_FAMILY_ORDER = (
    :voltage_source, :line, :switch, :transformer, :shunt, :capacitor,
    :load, :generator, :dc_network, :ibr, :grounding,
)

const _FLAT_DEVICE_COLLECTION = Dict{Symbol,String}(
    :voltage_source => "voltage_source",
    :line => "line",
    :switch => "switch",
    :shunt => "shunt",
    :capacitor => "capacitor",
    :load => "load",
    :generator => "generator",
    :ibr => "ibr",
)

const _MIXED_DEVICE_FAMILIES =
    setdiff(Set(keys(_FLAT_DEVICE_COLLECTION)), Set((:line,)))

const _UNSUPPORTED_FAMILY_REPLACEMENTS = Set((
    :line, :transformer, :dc_network,
))

const _SUPPORTED_FAMILY_REPLACEMENTS =
    setdiff(Set(_DEVICE_FAMILY_ORDER), _UNSUPPORTED_FAMILY_REPLACEMENTS)

function _family_ids(ctx::OpfContext, family::Symbol)
    if haskey(_FLAT_DEVICE_COLLECTION, family)
        collection = get(ctx.net, _FLAT_DEVICE_COLLECTION[family], Dict())
        return sort!(String[string(id) for id in keys(collection)])
    elseif family == :transformer
        ids = String[]
        for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
            append!(ids, string.(keys(get(get(ctx.net, "transformer", Dict()),
                                         subtype, Dict()))))
        end
        return sort!(unique!(ids))
    elseif family == :dc_network
        ids = String[]
        for collection in ("dc_bus", "dc_branch", "dc_load", "dc_voltage_source")
            append!(ids, ["$collection/$(id)" for id in keys(get(ctx.net, collection, Dict()))])
        end
        return sort!(ids)
    elseif family == :grounding
        return sort!(["$bus/$terminal" for (bus, terminal) in ctx.grounded])
    end
    return String[]
end

function _validate_build_spec(ctx::OpfContext)
    spec = ctx.build_spec
    for family in keys(spec.family_builders)
        family in _UNSUPPORTED_FAMILY_REPLACEMENTS && throw(ArgumentError(
            "custom whole-family :$family ownership is not supported until " *
            "its native coupling and result-ledger seams are public; " *
            "replacement would otherwise produce incomplete physics or " *
            "silently incomplete flow/loss results"))
        family in _SUPPORTED_FAMILY_REPLACEMENTS || throw(ArgumentError(
            "unsupported OPF device-builder family '$family'; supported " *
            "families are $(sort!(collect(_SUPPORTED_FAMILY_REPLACEMENTS)))"))
    end
    for ((family, id), _) in spec.component_builders
        family == :line && throw(ArgumentError(
            "custom per-component :line ownership is not supported until its " *
            "native branch result-ledger seam is public; omit the line from " *
            "the network and re-stamp its physics through model_hook! instead"))
        family in _MIXED_DEVICE_FAMILIES || throw(ArgumentError(
            "per-component OPF builders are not supported for family '$family'"))
        ids = _family_ids(ctx, family)
        id in ids || throw(ArgumentError(
            "unknown component '$id' for OPF device family '$family'"))
    end
    if haskey(spec.family_builders, :ibr)
        coupled = sort!([id for (id, inv) in get(ctx.net, "ibr", Dict())
                         if inv isa Dict &&
                            (haskey(inv, "dc_bus") ||
                             get(inv, "dc_link_coupled", false) == true)])
        isempty(coupled) || throw(ArgumentError(
            "custom whole-family :ibr ownership is not supported when IBRs " *
            "have native DC coupling ($(join(coupled, ", "))); replacing the " *
            "IBR builder would otherwise remove converter/DC balance physics"))
    end
    for ((family, id), _) in spec.component_builders
        family == :ibr || continue
        inv = get(get(ctx.net, "ibr", Dict()), id, nothing)
        inv isa Dict || continue
        if haskey(inv, "dc_bus") || get(inv, "dc_link_coupled", false) == true
            throw(ArgumentError(
                "custom :ibr ownership for '$id' is not supported because the " *
                "IBR has native DC coupling; replacing it would otherwise " *
                "remove converter/DC balance physics"))
        end
    end
    return ctx
end

function _with_flat_device_subset(action::Function, ctx::OpfContext,
                                  family::Symbol, ids::Vector{String})
    collection_name = _FLAT_DEVICE_COLLECTION[family]
    original = get(ctx.net, collection_name, Dict())
    subset = Dict{String,Any}(id => original[id] for id in ids)
    ctx.net[collection_name] = subset
    try
        return action()
    finally
        ctx.net[collection_name] = original
    end
end

function _build_device_family!(ctx::OpfContext, family::Symbol)
    ids = _family_ids(ctx, family)
    spec = ctx.build_spec
    if haskey(spec.family_builders, family)
        builder = spec.family_builders[family]
        builder.build!(ctx, ids)
        ctx.manifest.component_owners[family] = builder.owner
        return ctx
    end

    assignments = Dict(id => spec.component_builders[(family, id)]
                       for id in ids
                       if haskey(spec.component_builders, (family, id)))
    native_ids = [id for id in ids if !haskey(assignments, id)]
    if isempty(assignments)
        _native_device_family!(ctx, family, ids)
        isempty(ids) || (ctx.manifest.component_owners[family] = :BMOPFTools)
        return ctx
    end

    isempty(native_ids) || _native_device_family!(ctx, family, native_ids)
    for id in native_ids
        ctx.manifest.component_owners[(family, id)] = :BMOPFTools
    end
    for id in sort!(collect(keys(assignments)))
        builder = assignments[id]
        builder.build!(ctx, String[id])
        ctx.manifest.component_owners[(family, id)] = builder.owner
    end
    return ctx
end

function _native_device_family!(ctx::OpfContext, family::Symbol,
                                ids::Vector{String})
    model = ctx.model; net = ctx.net; vars = ctx.vars
    kcl_r = ctx.kcl_r; kcl_i = ctx.kcl_i
    isempty(ids) && family != :grounding && return ctx
    coefficient = isempty(ctx.build_spec.coefficient_providers) ? nothing :
        ((args...) -> _native_coefficient(ctx, args...))
    parameterized_profiles = Set{String}(
        key.component for key in keys(ctx.build_spec.coefficient_providers)
        if key.category == :controller && key.family == :control_profile)
    action = if family == :voltage_source
        () -> _add_source_constraints!(model, net, vars, kcl_r, kcl_i)
    elseif family == :line
        () -> begin
            _add_line_constraints!(model, net, vars, kcl_r, kcl_i;
                                   grounded=ctx.grounded,
                                   branch_inj=ctx.branch_inj,
                                   coefficient=coefficient)
            _add_line_angle_constraints!(model, net, vars)
        end
    elseif family == :switch
        () -> _add_switch_constraints!(model, net, vars, kcl_r, kcl_i)
    elseif family == :transformer
        () -> begin
            _add_transformer_constraints!(model, net, vars, kcl_r, kcl_i;
                                          branch_inj=ctx.branch_inj)
            _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i;
                                       branch_inj=ctx.branch_inj)
        end
    elseif family == :shunt
        () -> _add_shunt_constraints!(net, vars, kcl_r, kcl_i)
    elseif family == :capacitor
        () -> _add_capacitor_constraints!(net, vars, kcl_r, kcl_i)
    elseif family == :load
        () -> _add_load_constraints!(model, net, vars, kcl_r, kcl_i;
                                     coefficient=coefficient)
    elseif family == :generator
        () -> _add_generator_constraints!(model, net, vars, kcl_r, kcl_i;
            coefficient=coefficient)
    elseif family == :dc_network
        () -> _add_dc_network_constraints!(model, net, vars)
    elseif family == :ibr
        () -> _add_ibr_constraints!(ctx, kcl_r, kcl_i;
                                    parameterized_profiles=parameterized_profiles,
                                    coefficient=coefficient)
    elseif family == :grounding
        () -> _add_ground_injections!(vars, kcl_r, kcl_i, ctx.grounded)
    else
        throw(ArgumentError("unsupported native OPF device family '$family'"))
    end
    if family in _MIXED_DEVICE_FAMILIES
        _with_flat_device_subset(action, ctx, family, ids)
    else
        action()
    end
    return ctx
end

"""
    _add_ground_injections!(vars, kcl_r, kcl_i, grounded)

Inject the free ground current `cr_gnd`/`ci_gnd` into the KCL accumulator at every
perfectly grounded terminal (current flowing from earth into the node). The
terminal voltage is fixed to 0; this current is what the solid ground sinks or
sources, giving KCL the degree of freedom to balance the branch currents arriving
at a grounded node — the physical earth-return path.
"""
function _add_ground_injections!(vars, kcl_r, kcl_i, grounded)
    cr_gnd = vars[:cr_gnd]; ci_gnd = vars[:ci_gnd]
    for (bid, t) in grounded
        _kcl_add!(kcl_r, kcl_i, bid, t, cr_gnd[(bid,t)], ci_gnd[(bid,t)])
    end
end

"""
    _add_voltage_and_bus_bounds!(ctx)

Add the hard operational voltage bounds and bus-limit constraints. Shared by
`solve_opf` and `solve_feasibility_opf` (both carry the same non-KCL hard
constraints); the power-flow recipe does not call this.
"""
function _add_voltage_and_bus_bounds!(ctx::OpfContext)
    _add_voltage_bounds!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
    _add_bus_limit_constraints!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
end

"""
    _build_and_solve(net; optimizer, t_index, per_unit, s_base, build!, extract!,
                     configure!, verbose, solver_options, model_hook!,
                     solution_hook!) -> Dict

Generic build/solve engine. `build!(ctx)` is the per-problem recipe run after
variables exist and before KCL is enforced. `extract!(ctx, result)` is an
optional post-solve hook to append problem-specific result keys. `configure!`
is an optional hook to set solver attributes on the freshly created model.

User-facing knobs threaded through from the public solve entry points:
- `verbose`        — when `false` (default) the solver output is silenced.
- `solver_options` — iterable of `name => value` pairs applied as raw solver
  attributes *after* the problem's own `configure!`, so user options win.
- `model_hook!`    — optional `hook!(ctx)` called after the standard `build!`
  recipe and **before** KCL is enforced, so a hook can add constraints,
  replace the objective, or stamp extra injections into `ctx.kcl_r`/`ctx.kcl_i`.
- `solution_hook!` — optional `hook!(ctx, result)` called after the solve and
  the problem's own `extract!`, but **before** per-unit unwrapping, so a hook
  can read `JuMP.value` of custom variables (the model is still live) and append
  its own result keys. Runs in the model's units (per-unit when `per_unit=true`);
  the hook must scale its outputs to SI via `ctx.bases` so they survive alongside
  the engine's SI result. See the public `solve_opf` docstring for the contract.
"""
function _build_and_solve(net::Dict{String,Any};
                          optimizer,
                          t_index::Int,
                          per_unit::Bool,
                          s_base::Float64,
                          problem::Symbol,
                          build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                          build!::Function,
                          extract!::Union{Function,Nothing}=nothing,
                          configure!::Union{Function,Nothing}=nothing,
                          relu_eps::Float64=2e-3,
                          softplus::Symbol=:user_defined,
                          verbose::Bool=false,
                          solver_options=(),
                          model_hook!::Union{Function,Nothing}=nothing,
                          solution_hook!::Union{Function,Nothing}=nothing)

    working, bases = _prepare_working_net(net, t_index, per_unit, s_base)

    model = JuMP.Model(optimizer)
    verbose || JuMP.set_silent(model)
    configure! === nothing || configure!(model)
    for (name, value) in solver_options
        JuMP.set_attribute(model, string(name), value)
    end

    ctx = _new_context(model, working, bases, relu_eps;
                       problem=problem, s_base=s_base, build_spec=build_spec,
                       softplus=softplus)

    build!(ctx)
    model_hook! === nothing || model_hook!(ctx)

    _enforce_kcl!(ctx)

    JuMP.optimize!(model)

    result = _extract_results(model, working, ctx.bus_terminals, ctx.grounded,
                              ctx.vars, ctx.branch_inj)
    extract! === nothing || extract!(ctx, result)
    _run_result_extractors!(ctx, result)

    # User post-solve extraction: read custom-variable values (model still live)
    # and append result keys. Runs in model units, before per-unit unwrapping —
    # the hook scales its own outputs to SI via `ctx.bases`.
    solution_hook! === nothing || solution_hook!(ctx, result)

    # Optimization fingerprint of the best-known solution — must be captured here,
    # while `model` is live (it is discarded when this function returns).
    result["opt_profile"] = _optimization_profile(model; per_unit=per_unit)

    bases !== nothing ? _from_per_unit(result, bases, net) : result
end

# ── Shared build sub-steps ─────────────────────────────────────────────────
# Factored out of `_build_and_solve` so the public staged API (`build_opf_model`,
# `enforce_kcl!`, `optimize!`, `extract_result`) and the fused engine run the
# EXACT same preparation, model, and KCL code — no second implementation to drift.

"""
    _prepare_working_net(net, t_index, per_unit, s_base) -> (working, bases)

Snapshot a time-series net at `t_index` (or deep-copy a static net), materialise
terminal roles, and per-unit-scale it when `per_unit=true`. `bases` is the
per-unit base NamedTuple, or `nothing` in SI mode.
"""
function _prepare_working_net(net::Dict{String,Any}, t_index::Int,
                              per_unit::Bool, s_base::Float64)
    working = BMOPFTools.is_timeseries(net) ?
              BMOPFTools.get_snapshot(net, t_index) : deepcopy(net)
    # Stamp per-bus neutral terminals from an explicit terminal_conventions block
    # so bus-level neutral resolution honours non-"n" labels even for nets built
    # programmatically (parse_bmopf already does this on load). Mutates the copy.
    BMOPFTools._materialize_terminal_roles!(working)

    bases = nothing
    per_unit && ((working, bases) = _to_per_unit(working, s_base))
    return working, bases
end

"""
    _new_context(model, working, bases, relu_eps; problem, s_base) -> OpfContext

Index the working net, declare all JuMP variables into `model`, initialise the
KCL accumulators and branch-injection ledger, and bundle them into an
`OpfContext`. Adds no constraints and sets no objective.
"""
function _new_context(model, working::Dict{String,Any}, bases, relu_eps::Float64;
                      problem::Symbol, s_base::Float64,
                      softplus::Symbol=:user_defined,
                      build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec())
    softplus in (:user_defined, :builtin) || throw(ArgumentError(
        "softplus must be :user_defined or :builtin, got :$softplus"))
    bus_terminals = _bus_terminals(working)
    grounded      = _grounded_terminals(working)

    vars = _build_vars(model, working, bus_terminals, grounded)
    _set_dc_start_values!(vars, working)

    kcl_r, kcl_i = _init_kcl(bus_terminals, grounded)
    branch_inj = _new_branch_ledger()

    manifest = BMOPFTools.OpfBuildManifest(
        problem, :ivr_en, bases !== nothing, s_base, Symbol[:variables],
        Dict{Any,Symbol}())
    owned_spec = BMOPFTools.OpfBuildSpec(
        family_builders=copy(build_spec.family_builders),
        component_builders=copy(build_spec.component_builders),
        coefficient_providers=copy(build_spec.coefficient_providers))
    ctx = OpfContext(model, working, bus_terminals, grounded, vars,
                     kcl_r, kcl_i, branch_inj, bases, relu_eps, softplus,
                     Dict{Float64,Any}(),
                     Dict{BMOPFTools.OpfModelKey,Any}(), Dict{Any,Any}(),
                     Dict{BMOPFTools.OpfModelKey,BMOPFTools.OpfParameterBinding}(),
                     Dict{Symbol,BMOPFTools.OpfModelKey}(),
                     Dict{BMOPFTools.OpfCoefficientKey,Int}(),
                     Dict{Symbol,BMOPFTools.OpfRegularization}(),
                     Dict{Symbol,BMOPFTools.OpfDifferentiabilityAnnotation}(),
                     manifest, owned_spec, Dict{Symbol,Function}(), Ref(:building))
    _register_native_variables!(ctx)
    return ctx
end

function BMOPFTools.set_opf_start_values!(ctx::OpfContext)
    return _run_opf_stage!(ctx, :start_values,
        () -> _set_voltage_start_values!(
            ctx.vars, ctx.net, ctx.bus_terminals, ctx.grounded);
        required=(:variables,))
end

function BMOPFTools.add_opf_operational_limits!(ctx::OpfContext)
    return _run_opf_stage!(ctx, :operational_limits,
        () -> _add_voltage_and_bus_bounds!(ctx);
        required=(:start_values,))
end

function BMOPFTools.add_opf_device_constraints!(ctx::OpfContext)
    return _run_opf_stage!(ctx, :device_physics,
        () -> _add_device_constraints!(ctx);
        required=(:start_values,))
end

function BMOPFTools.set_opf_objective!(ctx::OpfContext)
    return _run_opf_stage!(ctx, :objective,
        () -> @objective(ctx.model, Min, BMOPFTools.generation_cost(ctx));
        required=(:device_physics,))
end

"""
    _enforce_kcl!(ctx)

Enforce Kirchhoff's current law: pin every AC KCL accumulator to zero and add
the DC-network nodal balance. Call once, after all device constraints and any
`model_hook!` injections have contributed to `ctx.kcl_r`/`ctx.kcl_i`.
"""
function _enforce_kcl!(ctx::OpfContext)
    _run_opf_stage!(ctx, :kcl, () -> begin
        kcl_r_refs, kcl_i_refs =
            _add_kcl_constraints!(ctx.model, ctx.kcl_r, ctx.kcl_i)
        for (index, cref) in kcl_r_refs
            BMOPFTools.register_opf_object!(ctx,
                BMOPFTools.OpfModelKey(:constraint, :kcl_r, index), cref)
        end
        for (index, cref) in kcl_i_refs
            BMOPFTools.register_opf_object!(ctx,
                BMOPFTools.OpfModelKey(:constraint, :kcl_i, index), cref)
        end
        _add_dc_kcl_constraints!(ctx.model, ctx.vars)
    end; required=(:device_physics,))
    ctx.lifecycle[] = :kcl_finalized
    return ctx
end

# ── Public staged build/solve/extract API ──────────────────────────────────
# The fused `solve_opf` is the convenience path. These four functions expose the
# same pipeline as discrete, composable steps so a caller (typically an external
# package) can build SEVERAL OPF snapshots into ONE JuMP model, couple them with
# its own cross-snapshot constraints (e.g. battery state-of-charge dynamics
# linking period t to t+1), set a single combined objective, solve once, and
# extract each snapshot's result. Each `ctx` keeps its own variable, KCL, and
# ledger dicts, so multiple contexts coexist in one model without collision.

"""
    BMOPFTools.build_opf_model(net; optimizer=Ipopt.Optimizer, t_index=1,
        per_unit=true, s_base=1e6, model=nothing, add_objective=true,
        build_spec=OpfBuildSpec(), model_hook!=nothing,
        volt_var_watt_eps=2e-3, softplus=:user_defined, verbose=false) -> ctx

Build the IVR-EN OPF device model, bounds, and (optionally) the generation-cost
objective for one snapshot, **without enforcing KCL or optimising**. The first
step of the staged API; see the module notes above.

- `model` — build into this existing JuMP model instead of a fresh one. Pass the
  same model for every snapshot of a multi-period problem so they share one
  optimisation. When `nothing`, a new `JuMP.Model(optimizer)` is created (and
  silenced unless `verbose`).
- `add_objective` — when `false`, the per-snapshot generation cost is NOT set on
  the model; recover it with [`generation_cost`](@ref) and set one combined
  objective yourself. Setting `@objective` once per snapshot would overwrite, so
  multi-period callers pass `add_objective=false`.
- `build_spec` — assigns typed whole-family or per-component builders and
  coefficient providers. Unsupported ownership transfers are rejected before
  device physics is stamped; see [`OpfBuildSpec`](@ref).
- `softplus` — selects the smooth-ReLU encoding used by Volt-var/Volt-watt
  droop. The stable default is `:user_defined`. Pass `:builtin` explicitly for
  current DiffOpt nonlinear wrappers, which reject `MOI.UserDefinedFunction`;
  the built-in expression has a narrower overflow-safe range.
- `model_hook!` — called as `hook!(ctx)` after the standard build, exactly as in
  `solve_opf`, to add custom devices/constraints for this snapshot.

Returns the snapshot's context; use `opf_model`, `opf_object`, `opf_bases`, and
`add_terminal_injection!` to couple snapshots without relying on its layout. Pass it to
[`enforce_kcl!`](@ref) and [`extract_result`](@ref).
"""
function BMOPFTools.build_opf_model(net::Dict{String,Any};
                                    optimizer=Ipopt.Optimizer,
                                    t_index::Int=1,
                                    per_unit::Bool=true,
                                    s_base::Float64=1e6,
                                    model=nothing,
                                    add_objective::Bool=true,
                                    build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                                    model_hook!::Union{Function,Nothing}=nothing,
                                    volt_var_watt_eps::Float64=2e-3,
                                    softplus::Symbol=:user_defined,
                                    verbose::Bool=false)
    ctx = BMOPFTools.initialize_opf_model(net; optimizer, t_index, per_unit,
                                          s_base, model,
                                          build_spec, volt_var_watt_eps,
                                          softplus, verbose)
    build_opf!(ctx; add_objective=add_objective)
    model_hook! === nothing || model_hook!(ctx)
    return ctx
end

function BMOPFTools.initialize_opf_model(net::Dict{String,Any};
                                         optimizer=Ipopt.Optimizer,
                                         t_index::Int=1,
                                         per_unit::Bool=true,
                                         s_base::Float64=1e6,
                                         model=nothing,
                                         build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                                         volt_var_watt_eps::Float64=2e-3,
                                         softplus::Symbol=:user_defined,
                                         verbose::Bool=false)
    working, bases = _prepare_working_net(net, t_index, per_unit, s_base)
    if model === nothing
        model = JuMP.Model(optimizer)
        verbose || JuMP.set_silent(model)
    end
    return _new_context(model, working, bases, volt_var_watt_eps;
                        problem=:opf, s_base=s_base, build_spec=build_spec,
                        softplus=softplus)
end

"""
    BMOPFTools.enforce_kcl!(ctx) -> ctx

Enforce Kirchhoff's current law for one snapshot's accumulators (AC nodal balance
+ DC network). Call after every device constraint and `model_hook!` injection for
that snapshot has been added, and before optimising. In a multi-period build call
it once per snapshot `ctx`.
"""
BMOPFTools.enforce_kcl!(ctx::OpfContext) = _enforce_kcl!(ctx)

"""
    BMOPFTools.generation_cost(ctx) -> JuMP.QuadExpr

The snapshot's total active-power generation-cost expression (the quantity
`solve_opf` minimises), returned WITHOUT setting it on the model. Sum these
across snapshots — adding any custom terms (e.g. storage throughput cost) — and
call `JuMP.@objective(ctx.model, Min, total)` once for a multi-period solve.
"""
const _GENERATION_COST_KEY =
    BMOPFTools.OpfModelKey(:objective, :generation_cost)

function BMOPFTools.generation_cost(ctx::OpfContext)
    if haskey(ctx.objects, _GENERATION_COST_KEY)
        return ctx.objects[_GENERATION_COST_KEY]
    end
    term = _generation_cost_expr(ctx.model, ctx.net, ctx.vars)
    return BMOPFTools.register_opf_objective_term!(
        ctx, _GENERATION_COST_KEY, term)
end

"""
    BMOPFTools.extract_result(ctx; solution_hook!=nothing) -> Dict{String,Any}

Extract one snapshot's result dict from the solved model (call `JuMP.optimize!`
on `ctx.model` first). Mirrors `solve_opf`'s output for that snapshot: runs the
optional `solution_hook!(ctx, result)`, attaches `opt_profile`, and unwraps
per-unit back to SI. Safe to call once per snapshot `ctx` after a single solve.
"""
function BMOPFTools.extract_result(ctx::OpfContext;
                                   solution_hook!::Union{Function,Nothing}=nothing)
    result = _extract_results(ctx.model, ctx.net, ctx.bus_terminals,
                              ctx.grounded, ctx.vars, ctx.branch_inj)
    _run_result_extractors!(ctx, result)
    solution_hook! === nothing || solution_hook!(ctx, result)
    per_unit = ctx.bases !== nothing
    result["opt_profile"] = _optimization_profile(ctx.model; per_unit=per_unit)
    per_unit ? _from_per_unit(result, ctx.bases, ctx.net) : result
end
