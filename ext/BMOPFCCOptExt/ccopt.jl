"""Optional bridge from the staged BMOPF OPF to CCOpt/MPCCModels.

`droop_encoding=:complementarity` leaves each exact ReLU hinge half-stamped in
the JuMP model — `r ≥ 0`, `s ≥ 0`, `s = r − U + x̄` are constraints, `r · s = 0`
is not. This adapter supplies the missing half by handing the registered pairs
to `MPCCModels`, solving with CCOpt, and reading the result back through the
OPF extension's own extraction path so a CCOpt result dict is interchangeable
with a `solve_opf` one.
"""

mutable struct CCOptOpfModel
    ctx
    nlp
    mpcc
    pair_indices::Vector{Tuple{Int,Int}}
    pairs::Vector{BMOPFTools.OpfComplementarityPair}
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
    # `kcl_guard` stays armed. CCOpt never calls `JuMP.optimize!`, so the hook
    # costs this path nothing, and it keeps the model safe for anyone who picks
    # it up off `handle.ctx` and solves it themselves.
    ctx = BMOPFTools.build_opf_model(net;
        model=model, optimizer=nothing, t_index=t_index, per_unit=per_unit,
        s_base=s_base, scaling_policy=scaling_policy, add_objective=true,
        build_spec=build_spec, model_hook! = model_hook!,
        volt_var_watt_eps=volt_var_watt_eps,
        droop_encoding=:complementarity, verbose=verbose)
    BMOPFTools.enforce_kcl!(ctx)

    pairs = BMOPFTools.opf_complementarity_pairs(ctx)
    isempty(pairs) && throw(ArgumentError(
        "this network registered no complementarity pairs, so there is no " *
        "MPCC to solve: no IBR carries a Volt-var or Volt-watt control " *
        "profile, and no `model_hook!` registered a pair of its own. Solve it " *
        "with `solve_opf` instead — the encodings coincide when there is no " *
        "droop curve to encode."))

    nlp = NLPModelsJuMP.MathOptNLPModel(model)
    positions = _ccopt_variable_positions(model)
    pair_indices = Tuple{Int,Int}[]
    for pair in pairs
        left = positions[BMOPFTools.opf_object(ctx, pair.left)]
        right = positions[BMOPFTools.opf_object(ctx, pair.right)]
        push!(pair_indices, (left, right))
    end
    mpcc = MPCCModels.MPCCModel(nlp, [p[1] for p in pair_indices],
                                     [p[2] for p in pair_indices])
    return CCOptOpfModel(ctx, nlp, mpcc, pair_indices, pairs, positions,
                         nothing, nothing)
end

# CCOpt 0.1.0's penalty homotopy evaluates the MPCC's complementarity residual
# at the ℓ₁-relaxation's EXPANDED iterate (n + 3·n_cc entries) rather than at the
# MPCC's own, so it throws a DimensionError out of `comp_res_left!` before
# returning. Nothing in this adapter can supply a shorter vector, so the failure
# is reported for what it is instead of surfacing a bare dimension mismatch. The
# call is still attempted, so the method starts working again on its own once
# upstream is fixed.
const _PENALTY_UPSTREAM_HINT =
    "CCOpt's penalty homotopy failed inside the solver. In CCOpt 0.1.0 this " *
    "path evaluates the complementarity residual at the ℓ₁-relaxation's " *
    "expanded iterate, which raises a `DimensionError` for any model with at " *
    "least one pair; if that is the error below, it is an upstream defect and " *
    "not a property of this model. Use `method=:relaxation`."

function BMOPFTools.solve_ccopt!(handle::CCOptOpfModel;
                                 method::Symbol=:relaxation, kwargs...)
    CCOpt, _, _ = _ccopt_dependencies()
    method in (:relaxation, :penalty) || throw(ArgumentError(
        "CCOpt method must be :relaxation or :penalty, got :$method"))
    solver = method == :relaxation ?
        CCOpt.RelaxationSolver(handle.mpcc; kwargs...) :
        CCOpt.PenaltySolver(handle.mpcc; kwargs...)
    stats = try
        CCOpt.solve_homotopy!(solver)
    catch err
        method == :penalty && throw(ErrorException(
            "$_PENALTY_UPSTREAM_HINT\nUnderlying error: " *
            sprint(showerror, err)))
        rethrow()
    end
    handle.solver = solver
    handle.stats = stats
    return stats
end

function _ccopt_stats_value(stats, field, default)
    hasproperty(stats, field) ? getproperty(stats, field) : default
end

function _ccopt_wall_time(stats)
    direct = _ccopt_stats_value(stats, :wall_time, nothing)
    direct !== nothing && return Float64(direct)
    counters = _ccopt_stats_value(stats, :counters, nothing)
    counters === nothing && return NaN
    total = _ccopt_stats_value(counters, :total_time, NaN)
    return Float64(total)
end

"""
    _ccopt_complementarity_report(handle, x) -> Dict

Measure how far the returned point is from actually satisfying `r · s = 0`.

Three quantities, because they answer different questions:

- `residual` — `min(r, s)` per pair. One of the two must be zero at an exact
  solution, so this is the amount by which the hinge is *not* exact, in model
  voltage units.
- `curve_error_relative` — `|slope| · residual`, the fraction of that curve's
  own reference base by which the enforced droop value is displaced. This is the
  dimensionless quantity worth gating on: it is what a residual actually costs
  the model, and it is comparable across curves with different slopes and bases.
- `bound_violation` — `max(−r, −s, 0)`. A relaxation solver can return a point
  slightly outside the pair's own non-negativity bounds; a negative hinge value
  is not a small error, it is a meaningless one, and taking `|r · s|` hides it.
"""
function _ccopt_complementarity_report(handle::CCOptOpfModel, x)
    n = length(handle.pair_indices)
    report = Dict{String,Any}(
        "pair_count" => n,
        "max_product" => 0.0,
        "max_residual" => 0.0,
        "max_curve_error_relative" => 0.0,
        "max_curve_error" => 0.0,
        "max_bound_violation" => 0.0,
        "worst_pair" => nothing,
    )
    worst = -Inf
    for (k, (i, j)) in enumerate(handle.pair_indices)
        r = Float64(x[i]); s = Float64(x[j])
        pair = handle.pairs[k]
        slope = abs(Float64(get(pair.metadata, "slope", 1.0)))
        base = abs(Float64(get(pair.metadata, "base", 1.0)))
        residual = min(abs(r), abs(s))
        relative = slope * residual
        report["max_product"] = max(report["max_product"], abs(r * s))
        report["max_residual"] = max(report["max_residual"], residual)
        report["max_curve_error"] = max(report["max_curve_error"], base * relative)
        report["max_bound_violation"] =
            max(report["max_bound_violation"], max(-r, -s, 0.0))
        if relative > worst
            worst = relative
            report["worst_pair"] = pair.id
        end
    end
    report["max_curve_error_relative"] = worst == -Inf ? 0.0 : worst
    return report
end

"""Classify a CCOpt termination string into (status, feasible, warn)."""
function _ccopt_classify(raw::AbstractString)
    up = uppercase(String(raw))
    occursin("SUCCEEDED", up) && return ("LOCALLY_SOLVED", true, false)
    occursin("ACCEPTABLE", up) && return ("ALMOST_LOCALLY_SOLVED", true, true)
    up in ("FIRST_ORDER", "SMALL_STEP") &&
        return ("ALMOST_LOCALLY_SOLVED", true, true)
    return ("CCOPT_$up", false, false)
end

"""
    _ccopt_objective(handle, x, stats) -> Float64

The objective of the ORIGINAL problem at `x`, evaluated through the NLP the
MPCC wraps. `stats.objective` is whatever the homotopy's current subproblem
reported, which for a penalty method carries the penalty term; re-evaluating
removes any dependence on which method ran.
"""
function _ccopt_objective(handle::CCOptOpfModel, x, stats)
    try
        return Float64(NLPModelsJuMP.NLPModels.obj(handle.nlp, x))
    catch
        return Float64(_ccopt_stats_value(stats, :objective, NaN))
    end
end

function _ccopt_value_function(handle::CCOptOpfModel, x)
    positions = handle.variable_positions
    variable_value(v::JuMP.VariableRef) = Float64(x[positions[v]])
    function value(v)
        v isa Real && return Float64(v)
        v isa JuMP.VariableRef && return variable_value(v)
        # `JuMP.value(f, expr)` walks affine, quadratic and nonlinear
        # expressions alike, so result extractors that build any of them read
        # back correctly without a hand-rolled evaluator per expression type.
        # (It has no `VariableRef` method — that is the branch above.)
        return Float64(JuMP.value(variable_value, v))
    end
    return value
end

"""
    extract_ccopt_result(handle; stats, solution_hook!, curve_error_tol,
                         bound_tol) -> Dict

Extract a `solve_opf`-shaped result dict from a solved CCOpt model.

The point is accepted only if the solver terminated successfully AND the
complementarity pairs are satisfied to tolerance — a homotopy that stops early
returns a point on a *relaxed* droop curve, and reporting that as solved would
be the same class of wrong answer the encoding exists to remove. `curve_error_tol`
bounds `|slope| · min(r, s)` as a fraction of each curve's reference base
(default 1e-4, i.e. 0.01% of nameplate); `bound_tol` bounds how far a hinge
variable may sit below its own zero (both in model units).
"""
function BMOPFTools.extract_ccopt_result(handle::CCOptOpfModel;
                                         stats=handle.stats,
                                         solution_hook!::Union{Function,Nothing}=nothing,
                                         curve_error_tol::Float64=1e-4,
                                         bound_tol::Float64=1e-6)
    stats === nothing && throw(ArgumentError(
        "the CCOpt model has not been solved; call solve_ccopt! first"))
    x = _ccopt_stats_value(stats, :solution, nothing)
    x isa AbstractVector || throw(ArgumentError(
        "CCOpt statistics do not contain a primal solution"))
    length(x) == length(handle.variable_positions) || throw(ArgumentError(
        "CCOpt solution length does not match the NLP variable registry"))

    raw_status = string(_ccopt_stats_value(stats, :status, "UNKNOWN"))
    status, solved, acceptable = _ccopt_classify(raw_status)
    if !all(isfinite, x)
        status = "CCOPT_NONFINITE_SOLUTION"
        solved = false
        acceptable = false
    end

    cc = _ccopt_complementarity_report(handle, x)
    exact = cc["max_curve_error_relative"] <= curve_error_tol &&
            cc["max_bound_violation"] <= bound_tol
    if solved && !exact
        status = "CCOPT_COMPLEMENTARITY_NOT_SATISFIED"
        solved = false
        @warn "CCOpt terminated at $raw_status but the complementarity " *
              "pairs are not satisfied to tolerance: the returned point sits " *
              "on a RELAXED droop curve, so the reported setpoints do not " *
              "obey the control law. Tighten the homotopy, or raise the " *
              "tolerances if this displacement is acceptable." *
              "\n  worst pair                : $(cc["worst_pair"])" *
              "\n  max |slope|·min(r,s)      : $(cc["max_curve_error_relative"])" *
              " (tolerance $curve_error_tol)" *
              "\n  max hinge bound violation : $(cc["max_bound_violation"])" *
              " (tolerance $bound_tol)"
    elseif solved && acceptable
        # Mirrors the warning the native path emits on ALMOST_LOCALLY_SOLVED.
        @warn "CCOpt stopped at $raw_status: the returned point satisfies " *
              "only relaxed (acceptable) tolerances — treat residuals and " *
              "binding constraints with care."
    end

    wall_time = _ccopt_wall_time(stats)
    objective = _ccopt_objective(handle, x, stats)
    value_function = _ccopt_value_function(handle, x)
    ctx = handle.ctx
    opfext = _opf_extension()
    result = opfext._extract_results(ctx.model, ctx.net, ctx.bus_terminals,
                              ctx.grounded, ctx.vars, ctx.branch_inj;
                              bases=ctx.bases,
                              value_function=value_function,
                              status_override=status,
                              solve_time_override=wall_time,
                              objective_override=objective,
                              feasible_override=solved)
    # Same post-solve sequence as `extract_result`: registered extractors, then
    # the user hook, then the profile, then per-unit unwrapping. Skipping any of
    # them would make a CCOpt result quietly different from a `solve_opf` one.
    opfext._run_result_extractors!(ctx, result)
    solution_hook! === nothing || solution_hook!(ctx, result)

    # Only IBR droop hinges are converted; `opf_piecewise_linear_expression` and
    # the DC converter port curve still register softplus operators, so the
    # label has to report what the model actually contains.
    encoding = isempty(ctx.relu_ops) ? "exact_relu_hinge" :
               "exact_relu_hinge+softplus"
    iterations = _ccopt_stats_value(stats, :iter, nothing)
    result["ccopt"] = Dict{String,Any}(
        "encoding" => encoding,
        "method" => handle.solver === nothing ? nothing :
                    String(nameof(typeof(handle.solver))),
        "termination_status" => raw_status,
        "complementarity_satisfied" => exact,
        "curve_error_tol" => curve_error_tol,
        "bound_tol" => bound_tol,
        "max_complementarity_product" => cc["max_product"],
        "max_complementarity_residual" => cc["max_residual"],
        "max_curve_error_relative" => cc["max_curve_error_relative"],
        "max_curve_error" => cc["max_curve_error"],
        "max_hinge_bound_violation" => cc["max_bound_violation"],
        "worst_pair" => cc["worst_pair"],
        "pair_count" => cc["pair_count"],
    )
    # The real profiler, computed against the CCOpt point, so `n_active` and the
    # `is_opf` flag `profile_solution` derives from it stay meaningful.
    result["opt_profile"] = opfext._optimization_profile(
        ctx.model; per_unit=ctx.bases !== nothing,
        value_function=value_function, iterations=iterations,
        solve_time=wall_time)
    result["opt_profile"]["solver"] = "CCOpt"
    result["opt_profile"]["encoding"] = encoding
    result["opt_profile"]["pair_count"] = cc["pair_count"]

    ctx.bases === nothing ? result :
        opfext._from_per_unit(result, ctx.bases, ctx.net)
end
