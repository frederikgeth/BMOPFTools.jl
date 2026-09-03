"""Optional bridge from the staged BMOPF OPF to CCOpt/MPCCModels."""

mutable struct CCOptOpfModel
    ctx
    nlp
    mpcc
    pair_indices::Vector{Tuple{Int,Int}}
    variable_positions::Dict{Any,Int}
    solver
    stats
end

function _ccopt_dependencies()
    return CCOpt, MPCCModels, NLPModelsJuMP
end

"""Return the variable order used by NLPModelsJuMP for a JuMP model."""
function _ccopt_variable_positions(model)
    vars = JuMP.all_variables(model)
    return Dict(v => i for (i, v) in enumerate(vars))
end

function BMOPFTools.build_ccopt_model(net::Dict{String,Any};
                                      t_index::Int=1,
                                      per_unit::Bool=true,
                                      s_base::Float64=1e6,
                                      scaling_policy=nothing,
                                      volt_var_watt_eps::Float64=2e-3,
                                      build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                                      model_hook!::Union{Function,Nothing}=nothing,
                                      verbose::Bool=false)
    _, MPCCModels, NLPModelsJuMP = _ccopt_dependencies()
    model = JuMP.Model()
    ctx = BMOPFTools.build_opf_model(net;
        model=model, optimizer=nothing, t_index=t_index, per_unit=per_unit,
        s_base=s_base, scaling_policy=scaling_policy, add_objective=true,
        build_spec=build_spec, model_hook! = model_hook!,
        volt_var_watt_eps=volt_var_watt_eps,
        droop_encoding=:complementarity, kcl_guard=false, verbose=verbose)
    BMOPFTools.enforce_kcl!(ctx)

    nlp = NLPModelsJuMP.MathOptNLPModel(model)
    positions = _ccopt_variable_positions(model)
    pairs = BMOPFTools.opf_complementarity_pairs(ctx)
    pair_indices = Tuple{Int,Int}[]
    for pair in pairs
        left = positions[BMOPFTools.opf_object(ctx, pair.left)]
        right = positions[BMOPFTools.opf_object(ctx, pair.right)]
        push!(pair_indices, (left, right))
    end
    ind_left = [p[1] for p in pair_indices]
    ind_right = [p[2] for p in pair_indices]
    mpcc = MPCCModels.MPCCModel(nlp, ind_left, ind_right)
    return CCOptOpfModel(ctx, nlp, mpcc, pair_indices, positions, nothing, nothing)
end

function BMOPFTools.solve_ccopt!(handle::CCOptOpfModel;
                                 method::Symbol=:relaxation, kwargs...)
    CCOpt, _, _ = _ccopt_dependencies()
    method in (:relaxation, :penalty) || throw(ArgumentError(
        "CCOpt method must be :relaxation or :penalty, got :$method"))
    solver = method == :relaxation ?
        CCOpt.RelaxationSolver(handle.mpcc; kwargs...) :
        CCOpt.PenaltySolver(handle.mpcc; kwargs...)
    stats = CCOpt.solve_homotopy!(solver)
    handle.solver = solver
    handle.stats = stats
    return stats
end

function _ccopt_stats_value(stats, field, default)
    hasproperty(stats, field) ? getproperty(stats, field) : default
end

function _ccopt_has_solution(stats, x)
    x isa AbstractVector || return false
    all(isfinite, x) || return false
    raw = uppercase(string(_ccopt_stats_value(stats, :status, "")))
    return occursin("SUCCEEDED", raw) || occursin("ACCEPTABLE", raw) ||
           raw in ("FIRST_ORDER", "SMALL_STEP")
end

function _ccopt_wall_time(stats)
    direct = _ccopt_stats_value(stats, :wall_time, nothing)
    direct !== nothing && return Float64(direct)
    counters = _ccopt_stats_value(stats, :counters, nothing)
    counters === nothing && return NaN
    total = _ccopt_stats_value(counters, :total_time, NaN)
    return Float64(total)
end

function _ccopt_value_function(handle::CCOptOpfModel, x)
    positions = handle.variable_positions
    function value(v)
        v isa Real && return Float64(v)
        v isa JuMP.VariableRef && return Float64(x[positions[v]])
        if v isa JuMP.AffExpr
            total = Float64(JuMP.constant(v))
            for (coefficient, variable) in JuMP.linear_terms(v)
                total += Float64(coefficient) * x[positions[variable]]
            end
            return total
        end
        throw(ArgumentError(
            "CCOpt result extraction encountered unsupported JuMP expression " *
            "type $(typeof(v)); register an explicit result extractor instead"))
    end
    return value
end

function BMOPFTools.extract_ccopt_result(handle::CCOptOpfModel;
                                         stats=handle.stats,
                                         solution_hook!::Union{Function,Nothing}=nothing)
    stats === nothing && throw(ArgumentError(
        "the CCOpt model has not been solved; call solve_ccopt! first"))
    x = _ccopt_stats_value(stats, :solution, nothing)
    x isa AbstractVector || throw(ArgumentError(
        "CCOpt statistics do not contain a primal solution"))
    length(x) == length(handle.variable_positions) || throw(ArgumentError(
        "CCOpt solution length does not match the NLP variable registry"))
    solved = _ccopt_has_solution(stats, x)
    raw_status = string(_ccopt_stats_value(stats, :status, "UNKNOWN"))
    objective = _ccopt_stats_value(stats, :objective, NaN)
    wall_time = _ccopt_wall_time(stats)
    value_function = _ccopt_value_function(handle, x)
    opfext = _opf_extension()
    result = opfext._extract_results(handle.ctx.model, handle.ctx.net,
                              handle.ctx.bus_terminals, handle.ctx.grounded,
                              handle.ctx.vars, handle.ctx.branch_inj;
                              bases=handle.ctx.bases,
                              value_function=value_function,
                              status_override=solved ? "LOCALLY_SOLVED" :
                                  "CCOPT_$(uppercase(raw_status))",
                              solve_time_override=wall_time,
                              objective_override=objective,
                              feasible_override=solved)
    products = isempty(handle.pair_indices) ? Float64[] :
        [abs(x[i] * x[j]) for (i, j) in handle.pair_indices]
    result["ccopt"] = Dict{String,Any}(
        "encoding" => "exact_relu_hinge",
        "method" => handle.solver === nothing ? nothing :
                    String(nameof(typeof(handle.solver))),
        "termination_status" => raw_status,
        "pair_count" => length(handle.pair_indices),
        "max_complementarity_product" => isempty(products) ? 0.0 : maximum(products),
    )
    result["opt_profile"] = Dict{String,Any}(
        "solver" => "CCOpt",
        "encoding" => "exact_relu_hinge",
        "pair_count" => length(handle.pair_indices),
        "solve_time_s" => wall_time,
    )
    solution_hook! === nothing || solution_hook!(handle.ctx, result)
    handle.ctx.bases === nothing ? result :
        opfext._from_per_unit(result, handle.ctx.bases, handle.ctx.net)
end
