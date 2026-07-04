# ext/BMOPFOpfExt/profile.jl
#
# Optimization profile of the best-known solution — the "fingerprint" that
# distinguishes a well-behaved OPF benchmark from a degenerate one:
# degrees of freedom, how many constraints bind at the optimum, and whether
# complementarity is strict (non-degenerate). Computed while the JuMP model is
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
    )

    # --- counts / DOF (always available) ---
    try
        nvar = JuMP.num_variables(model)
        neq = 0; nineq = 0
        for (F, S) in JuMP.list_of_constraint_types(model)
            k = _set_kind(_proto(S))
            n = JuMP.num_constraints(model, F, S)
            k === :eq   && (neq += n)
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
    # only to certify complementarity: a binding constraint with a ~0 multiplier is
    # weakly active (a degeneracy — the "easily solvable degeneracy" we want to flag).
    hd = false
    try
        hd = JuMP.has_duals(model)
    catch
    end
    prof["has_duals"] = hd

    active_mults = Float64[]   # multipliers of primal-binding constraints
    n_active = 0
    n_weak = 0
    try
        for (F, S) in JuMP.list_of_constraint_types(model)
            _set_kind(_proto(S)) === :ineq || continue
            for con in JuMP.all_constraints(model, F, S)
                sl = nothing; v = 0.0
                try
                    v = JuMP.value(con)
                    sl = _slack(v, JuMP.constraint_object(con).set)
                catch
                    continue
                end
                sl === nothing && continue
                # binding ⟺ slack within tol of the bound (relative to the
                # constraint's own magnitude, so it scales across units)
                binding = abs(sl) <= tol_primal * (1.0 + abs(v))
                binding || continue
                n_active += 1
                if hd
                    d = NaN
                    try; d = abs(JuMP.dual(con)); catch; end
                    isnan(d) ? nothing :
                        (d > tol_active ? push!(active_mults, d) : (n_weak += 1))
                end
            end
        end
        prof["n_active"] = n_active
        if hd
            prof["n_weakly_active"] = n_weak
            prof["strict_complementarity"] = (n_weak == 0)
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

# A zero-argument prototype instance of a MOI set type, for kind classification.
# The scalar bound sets take a Float64 bound; Zeros/others take a dimension.
_proto(::Type{<:MOI.LessThan})    = MOI.LessThan(0.0)
_proto(::Type{<:MOI.GreaterThan}) = MOI.GreaterThan(0.0)
_proto(::Type{<:MOI.EqualTo})     = MOI.EqualTo(0.0)
_proto(::Type{<:MOI.Interval})    = MOI.Interval(0.0, 0.0)
_proto(::Type{<:MOI.Zeros})       = MOI.Zeros(1)
_proto(::Type{S}) where {S}       = nothing
_set_kind(::Nothing) = :other
