# Feasibility OPF — elastic slack-current formulation.
#
# Identical to solve_opf except:
#   1. A free slack current (cs_r, cs_i) is added at every ungrounded,
#      non-source bus terminal and injected directly into KCL.
#      This lets those KCL equations absorb residual current; it does not relax
#      the remaining hard constraints or guarantee NLP feasibility/convergence.
#   2. The objective minimises the L2² norm of all slack injections rather
#      than generation cost, with a documented transformer tie-break term.
#
# Interpretation: at a converged local solution, non-zero slacks indicate where
# that relaxed point uses residual current. This is a local diagnostic, not a
# proof that the original feasible set is empty. Pass the result to
# diagnose_infeasibility() for a ranked, classified breakdown.

"""
    BMOPFTools.solve_feasibility_opf(net; optimizer, t_index,
        softplus=:user_defined, build_spec=OpfBuildSpec()) -> Dict

Feasibility-relaxed four-wire IVR-EN OPF. Adds an elastic slack current
injection (the nodal current residual) at every non-source bus terminal and
uses ∑ |sₖ|² (L2² over all slack terminals) as its primary objective, plus the
documented transformer degeneracy tie-break.

The model retains [`solve_opf`](@ref)'s **non-KCL hard constraints** — voltage
bounds, bus/line angle limits, and device limits — while the nodal-current
variables enlarge the feasible set by relaxing **KCL**. They can absorb residual
current wherever they are present, but cannot reconcile mutually contradictory
hard constraints or guarantee convergence of the nonconvex NLP.

For a converged solve, non-zero residuals localise and quantify where that local
relaxed point pays to violate KCL. They do not certify that the original problem
has no zero-residual solution elsewhere. The raw `"objective"` is the squared
slack norm in the model's working coordinates (plus the documented transformer
tie-break); use the SI-valued `"slack_injections"` and
`"total_slack_magnitude_A"` fields for physical interpretation. Pass the result
to [`BMOPFTools.diagnose_infeasibility`](@ref) for a ranked breakdown.
`build_spec` follows the same ownership contract as `solve_opf`; custom terminal
injections participate in the KCL equation relaxed by the elastic current.
For cases with Volt-var/Volt-watt profiles, `softplus=:user_defined` uses the
stable registered nonlinear operator. Pass `softplus=:builtin` explicitly for
current DiffOpt nonlinear wrappers; the built-in expression has a narrower
overflow-safe range.
"""
function BMOPFTools.solve_feasibility_opf(net::Dict{String,Any};
                                           optimizer=Ipopt.Optimizer,
                                           t_index::Int=1,
                                           per_unit::Bool=true,
                                           s_base::Float64=1e6,
                                           scaling_policy::Union{
                                               BMOPFTools.AbstractOpfScalingPolicy,Nothing}=nothing,
                                           volt_var_watt_eps::Float64=2e-3,
                                           softplus::Symbol=:user_defined,
                                           build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                                           verbose::Bool=false,
                                           solver_options=(),
                                           model_hook!::Union{Function,Nothing}=nothing,
                                           solution_hook!::Union{Function,Nothing}=nothing)
    # cs_r/cs_i are created inside build! and read again in extract!; share them
    # across the two hooks via this closed-over scratch dict.
    slack = Dict{Symbol,Any}()
    _build_and_solve(net; optimizer=optimizer, t_index=t_index,
                     per_unit=per_unit, s_base=s_base, scaling_policy,
                     relu_eps=volt_var_watt_eps,
                     softplus=softplus, build_spec=build_spec,
                     problem=:feasibility_opf,
                     configure! = _configure_feasibility!,
                     build! = ctx -> build_feasibility!(ctx, slack),
                     extract! = (ctx, result) -> extract_feasibility!(ctx, result, slack),
                     verbose, solver_options, model_hook!, solution_hook!)
end

# Disable "acceptable level" early stopping so Ipopt must meet the regular
# tolerance (1e-8) before reporting normal convergence. Without this, problems with bilinear P/Q
# constraints and active thermal limits can exit prematurely, producing
# inaccurate voltages. Ipopt-specific: skipped (with a warning) for any other
# optimizer instead of erroring on an unsupported attribute.
function _configure_feasibility!(model)
    if occursin("Ipopt", JuMP.solver_name(model))
        JuMP.set_optimizer_attribute(model, "acceptable_tol", 1e-8)
    else
        @warn "solve_feasibility_opf: skipping the Ipopt-specific " *
              "`acceptable_tol` setting — solver is $(JuMP.solver_name(model)). " *
              "Consider disabling its own early-acceptance heuristics via " *
              "`solver_options` for accurate residuals."
    end
end

"""
    build_feasibility!(ctx, slack)

Build recipe for the elastic slack-current feasibility OPF. Stores the slack
variable dicts in `slack[:cs_r]` / `slack[:cs_i]` for `extract_feasibility!`.
"""
function build_feasibility!(ctx::OpfContext, slack::Dict{Symbol,Any})
    model = ctx.model; working = ctx.net; vars = ctx.vars
    bus_terminals = ctx.bus_terminals; grounded = ctx.grounded
    kcl_r = ctx.kcl_r; kcl_i = ctx.kcl_i

    # Use level-aware start values so that LV buses are initialised at ~250 V
    # rather than at the source voltage (~6350 V). When a case lacks useful
    # voltage bounds, this reduces attraction to a degenerate high-voltage local
    # minimum; it is an initialisation heuristic, not a convergence guarantee.
    _run_opf_stage!(ctx, :start_values, () -> begin
        _set_level_aware_start_values!(vars, working, bus_terminals, grounded)
        transport = _set_topology_aware_voltage_start_values!(
            vars, working, bus_terminals, grounded)
        _set_yd_dy_start_values!(
            vars, working, grounded; set_voltage_starts=false)
        state = BMOPFTools.extension_state!(ctx, :BMOPFToolsInitialization)
        state[:phasor_transport] = transport
    end; required=(:variables,))

    # Bound parity with solve_opf: the feasibility model carries the same
    # non-KCL hard constraints (voltage bounds, bus limits, line/bus angle limits,
    # and device limits). Its feasible set is larger only because the free nodal
    # residual (cs_r, cs_i) relaxes KCL below. Voltages still respect their hard
    # bounds; contradictory remaining hard constraints can still be infeasible.
    BMOPFTools.add_opf_operational_limits!(ctx)

    BMOPFTools.add_opf_device_constraints!(ctx)

    # ── Slack current injections ──────────────────────────────────────────────
    # One (cs_r, cs_i) pair per KCL node. Grounded terminals are excluded
    # (vr=vi=0 already fixed). Source-bus phase terminals carry the voltage
    # source's own slack current in KCL, so their elastic slack is naturally zero.

    cs_r = Dict{Tuple{String,String}, JuMP.VariableRef}()
    cs_i = Dict{Tuple{String,String}, JuMP.VariableRef}()

    for (bid, terminals) in bus_terminals
        for t in terminals
            key = (bid, t)
            key in grounded && continue
            haskey(kcl_r, key) || continue
            cs_r[key] = @variable(model, base_name = "cs_r_$(bid)_$(t)")
            cs_i[key] = @variable(model, base_name = "cs_i_$(bid)_$(t)")
            JuMP.add_to_expression!(kcl_r[key], cs_r[key])
            JuMP.add_to_expression!(kcl_i[key], cs_i[key])
        end
    end

    slack[:cs_r] = cs_r
    slack[:cs_i] = cs_i

    # ── Objective: minimise L2² of all slack injections ───────────────────────
    # A tiny linear term (−1e-6 × delta-side cr_xf) breaks the sign/circulation
    # degeneracy of Yd/Dy transformers: both current branches (and any uniform
    # delta loop current) give identical slack for passive transformers with
    # resistive loads.  The coefficient must stay ≪ 1 so the tie-break cannot
    # compete with the slack L2² term or reward circulating current — it merely
    # selects the physical branch when both are equally feasible.
    slack_obj = JuMP.QuadExpr()
    for key in keys(cs_r)
        JuMP.add_to_expression!(slack_obj, 1.0, cs_r[key], cs_r[key])
        JuMP.add_to_expression!(slack_obj, 1.0, cs_i[key], cs_i[key])
    end
    xfmr_dict = get(working, "transformer", Dict())
    cr_xf = vars[:cr_xf]
    for subtype in ("wye_delta", "delta_wye")
        wye_is_from = (subtype == "wye_delta")
        # The unobservable state is the delta circulation current — a uniform loop
        # current that adds equally to all delta arm currents without affecting
        # terminal voltages or wye-side KCL.  Penalise the delta-side phase currents
        # to break this degeneracy.  For Yd the delta is the to-side; for Dy it is
        # the from-side.
        side_del = wye_is_from ? "to" : "fr"
        for (tid, xfmr) in get(xfmr_dict, subtype, Dict())
            tm_del = Vector{String}(wye_is_from ?
                get(xfmr, "terminal_map_to",   String[]) :
                get(xfmr, "terminal_map_from", String[]))
            for k in 1:length(tm_del)
                JuMP.add_to_expression!(slack_obj, -1e-6, cr_xf[(tid, side_del, k)])
            end
        end
    end
    _run_opf_stage!(ctx, :objective,
        () -> @objective(model, Min, slack_obj);
        required=(:device_physics,))
end

"""
    extract_feasibility!(ctx, result, slack)

Post-solve hook: append the feasibility-specific result keys (`slack_injections`,
`total_slack_magnitude_A`, `is_feasibility_opf`) using the slack variables saved
by `build_feasibility!`. Runs before per-unit unwrapping, exactly as before.
"""
function extract_feasibility!(ctx::OpfContext, result::Dict{String,Any},
                              slack::Dict{Symbol,Any})
    model = ctx.model
    cs_r = slack[:cs_r]::Dict{Tuple{String,String}, JuMP.VariableRef}
    cs_i = slack[:cs_i]::Dict{Tuple{String,String}, JuMP.VariableRef}

    solved = JuMP.termination_status(model) in (JuMP.MOI.LOCALLY_SOLVED,
                                                 JuMP.MOI.OPTIMAL,
                                                 JuMP.MOI.ALMOST_LOCALLY_SOLVED) &&
             JuMP.result_count(model) >= 1 &&
             JuMP.primal_status(model) != JuMP.MOI.NO_SOLUTION
    val(v) = solved ? JuMP.value(v) : NaN

    # Slack injection results — keyed by bus then terminal
    slack_by_bus = Dict{String,Any}()
    for (bid, terminals) in ctx.bus_terminals
        t_slacks = Dict{String,Any}()
        for t in terminals
            key = (bid, t)
            haskey(cs_r, key) || continue
            csr = val(cs_r[key])
            csi = val(cs_i[key])
            t_slacks[t] = Dict{String,Any}(
                "cs_r"   => csr,
                "cs_i"   => csi,
                "cs_mag" => sqrt(csr^2 + csi^2),
            )
        end
        isempty(t_slacks) || (slack_by_bus[bid] = t_slacks)
    end

    total_sq = sum(
        v["cs_mag"]^2
        for td in values(slack_by_bus) for v in values(td);
        init = 0.0
    )

    result["slack_injections"]        = slack_by_bus
    result["total_slack_magnitude_A"] = sqrt(total_sq)
    result["is_feasibility_opf"]      = true
end
