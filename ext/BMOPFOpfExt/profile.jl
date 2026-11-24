# ext/BMOPFOpfExt/profile.jl
#
# Optimization profile of the best-known solution — the "fingerprint" that
# describes solver-side counts and numerical activity:
# a dimension count proxy, binding inequalities, and a complementarity screen. Computed while the JuMP model is
# still live (inside _build_and_solve), since the model is discarded afterwards.
#
# Everything is best-effort and guarded: a solver that does not expose duals or
# barrier iterations, or an infeasible solve, yields `nothing` for the affected
# fields — it must never break solve_opf.

# Classify a MOI set as :eq, :ineq, or :other for DOF / active-set accounting.
_set_kind(::MOI.EqualTo) = :eq
_set_kind(::MOI.Zeros)   = :eq
_set_kind(::MOI.LessThan)    = :ineq
_set_kind(::MOI.GreaterThan) = :ineq
_set_kind(::MOI.Interval)    = :ineq
_set_kind(::Any) = :other

# Signed slack (≥ 0 means feasible interior; ≈ 0 means binding) for an inequality,
# given the constraint's primal function value and its set. `nothing` if not a
# one-sided bound we can score.
_slack(v, s::MOI.LessThan)    = s.upper - v
_slack(v, s::MOI.GreaterThan) = v - s.lower
_slack(v, s::MOI.Interval)    = min(v - s.lower, s.upper - v)
_slack(v, ::Any) = nothing

"""
    _optimization_profile(model; per_unit, tol_active, tol_primal) -> Dict

Return a machine-readable optimization fingerprint of `model` after `optimize!`.
See docs/TAGGING.md (BMOPFDraftData) for how these feed benchmark classification.
"""
function _optimization_profile(model::JuMP.Model;
                               per_unit::Bool=true,
                               tol_active::Float64=1e-6,
                               tol_primal::Float64=1e-6)
    prof = Dict{String,Any}(
        "units" => per_unit ? "per_unit" : "SI",
        "n_variables" => nothing, "n_eq_constraints" => nothing,
        "n_ineq_constraints" => nothing, "degrees_of_freedom" => nothing,
        "barrier_iterations" => nothing, "solve_time_s" => nothing,
        "has_duals" => false, "n_active" => nothing, "n_weakly_active" => nothing,
        "strict_complementarity" => nothing, "min_active_multiplier" => nothing,
        "max_shadow_price" => nothing, "median_shadow_price" => nothing,
        "dimension_method" => "variable_minus_equality_count",
        "n_unassessed_inequalities" => 0, "n_missing_active_duals" => 0,
        "tol_active" => tol_active, "tol_primal" => tol_primal,
    )

    # --- counts / DOF (always available) ---
    try
        nvar = JuMP.num_variables(model)
        neq = 0; nineq = 0
        for (F, S) in JuMP.list_of_constraint_types(model)
            k = _set_kind(_proto(S))
            n = JuMP.num_constraints(model, F, S)
            if k === :eq
                # Vector zero-component limits contain one scalar equality per
                # component, despite having one semantic constraint handle.
                neq += S <: MOI.Zeros ? sum(
                    MOI.dimension(MOI.get(model, MOI.ConstraintSet(), c))
                    for c in JuMP.all_constraints(model, F, S)) : n
            end
            k === :ineq && (nineq += n)
        end
        prof["n_variables"] = nvar
        prof["n_eq_constraints"] = neq
        prof["n_ineq_constraints"] = nineq
        prof["degrees_of_freedom"] = nvar - neq
    catch
    end

    # --- solver-reported iterations & time ---
    try
        prof["barrier_iterations"] = Int(MOI.get(model, MOI.BarrierIterations()))
    catch
    end
    try
        prof["solve_time_s"] = JuMP.solve_time(model)
    catch
    end

    # --- primal active set + dual-based strict complementarity ---
    # "Active" is judged from the PRIMAL slack (the constraint binds), not by
    # dual-thresholding — an interior-point solver returns tiny-but-nonzero duals
    # for inactive bounds too, which would grossly overcount. The dual is then used
    # to screen for weak activity: a binding constraint with a near-zero multiplier.
    # This numerical screen does not establish uniqueness or solver difficulty.
    hd = false
    try
        hd = JuMP.has_duals(model)
    catch
    end
    prof["has_duals"] = hd

    active_mults = Float64[]   # multipliers of primal-binding constraints
    n_active = 0
    n_weak = 0
    n_unassessed = 0
    n_missing_duals = 0
    try
        backend = JuMP.backend(model)
        for (F, S) in JuMP.list_of_constraint_types(model)
            _set_kind(_proto(S)) === :ineq || continue
            cons = JuMP.all_constraints(model, F, S)
            # One batched solver query per constraint type. Building each
            # constraint's JuMP function object just to read its set, and
            # querying values one row at a time, dominated this pass.
            batch = _batched_rows(backend, cons, hd)
            for (r, con) in enumerate(cons)
                sl = nothing; v = 0.0
                try
                    if batch === nothing
                        v = JuMP.value(con)
                        sl = _slack(v, JuMP.constraint_object(con).set)
                    else
                        v = batch.values[r]
                        sl = _slack(v, batch.sets[r])
                    end
                catch
                    n_unassessed += 1
                    continue
                end
                if sl === nothing || !isfinite(sl)
                    n_unassessed += 1
                    continue
                end
                # binding ⟺ slack within tol of the bound (relative to the
                # constraint's own magnitude, so it scales across units)
                binding = abs(sl) <= tol_primal * (1.0 + abs(v))
                binding || continue
                n_active += 1
                if hd
                    d = NaN
                    try
                        d = abs(batch === nothing || batch.duals === nothing ?
                                JuMP.dual(con) : batch.duals[r])
                    catch
                    end
                    !isfinite(d) ? (n_missing_duals += 1) :
                        (d > tol_active ? push!(active_mults, d) : (n_weak += 1))
                end
            end
        end
        prof["n_active"] = n_active
        prof["n_unassessed_inequalities"] = n_unassessed
        prof["n_missing_active_duals"] = n_missing_duals
        if hd
            prof["n_weakly_active"] = n_weak
            prof["strict_complementarity"] =
                n_unassessed == 0 && n_missing_duals == 0 ? (n_weak == 0) : nothing
            if !isempty(active_mults)
                prof["min_active_multiplier"] = minimum(active_mults)
                prof["max_shadow_price"] = maximum(active_mults)
                sorted = sort(active_mults)
                m = length(sorted)
                prof["median_shadow_price"] = isodd(m) ? sorted[(m + 1) ÷ 2] :
                    (sorted[m ÷ 2] + sorted[m ÷ 2 + 1]) / 2
            end
        end
    catch
    end

    prof
end

# Sets, primal values and (optionally) duals of one constraint type in batched
# solver queries, or `nothing` when the backend cannot answer them in bulk (the
# caller then falls back to per-row JuMP queries).
function _batched_rows(backend, cons, want_duals::Bool)
    isempty(cons) && return nothing
    try
        idx = JuMP.index.(cons)
        sets = MOI.get(backend, MOI.ConstraintSet(), idx)
        values = MOI.get(backend, MOI.ConstraintPrimal(), idx)
        duals = nothing
        if want_duals
            duals = try
                MOI.get(backend, MOI.ConstraintDual(), idx)
            catch
                nothing
            end
        end
        return (sets=sets, values=values, duals=duals)
    catch
        return nothing
    end
end

# A zero-argument prototype instance of a MOI set type, for kind classification.
# The scalar bound sets take a Float64 bound; Zeros/others take a dimension.
_proto(::Type{<:MOI.LessThan})    = MOI.LessThan(0.0)
_proto(::Type{<:MOI.GreaterThan}) = MOI.GreaterThan(0.0)
_proto(::Type{<:MOI.EqualTo})     = MOI.EqualTo(0.0)
_proto(::Type{<:MOI.Interval})    = MOI.Interval(0.0, 0.0)
_proto(::Type{<:MOI.Zeros})       = MOI.Zeros(1)
_proto(::Type{S}) where {S}       = nothing
_set_kind(::Nothing) = :other
