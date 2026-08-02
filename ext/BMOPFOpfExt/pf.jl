# Power flow — determined four-wire IVR-EN nodal solve.
#
# A power flow is the same physics as solve_opf / solve_feasibility_opf with two
# deliberate omissions that make it a *determined* problem rather than an
# optimisation:
#
#   1. NO operational bounds (voltage limits, bus limits, device current/thermal
#      limits). The power flow solves the network as-is and reports whatever
#      currents and voltages result; rating violations are a separate validation
#      concern. This mirrors PowerModels `build_pf_iv` (variable_*(bounded=false)).
#      ONE deliberate exception: the transformer nameplate `s_rating` (a required
#      field with an always-enforced per-coil cap, see transformer_models.md) is
#      NOT stripped — a PF loading a coil beyond s_rating/n_ph returns
#      LOCALLY_INFEASIBLE (see issue #355). Remove `s_rating` from the input dict
#      for a limit-free reference solve.
#   2. NO objective (Min 0). The voltage source fixes the slack-bus voltages and
#      supplies the free swing current; constant-power loads/generators/IBRs
#      and exact KCL then fully determine the nodal state.
#
# Because generators in this model are P/Q *ranges* (p_min..p_max), they would
# leave the system underdetermined under no objective. A power flow therefore
# requires every generator to be a fixed setpoint (p_min==p_max, q_min==q_max);
# a non-degenerate range is rejected with a clear error. IBRs governed by a
# control_profile are voltage-dependent and remain determined, so they are fine.

"""
    BMOPFTools.solve_pf(net; optimizer=Ipopt.Optimizer, t_index=1,
                        per_unit=true, s_base=1e6,
                        softplus=:user_defined,
                        build_spec=OpfBuildSpec()) -> Dict

Determined four-wire rectangular current-voltage (IVR-EN) power flow on a BMOPF
network dict.

Same device models as [`solve_opf`](@ref) but with **no operational bounds and no
objective** — the network's physics (fixed source voltages + constant-power
injections + exact KCL) fully determine the solution. Device current/thermal
limits and voltage bounds are intentionally ignored; use `solve_opf` (or a
post-solve validation pass) when limits must be enforced.

**One exception**: a transformer's nameplate `s_rating` is a required field
whose per-coil apparent-power cap is **always enforced**, in the power flow
too — loading any coil beyond `s_rating / n_phase` makes the PF
`LOCALLY_INFEASIBLE` rather than reporting an overloaded state. This is easy
to misread as a numerical failure (healthy voltages, no other limits). To
solve without the nameplate — e.g. to compare against a limit-free OpenDSS
solve — delete `s_rating` from the transformer dicts in the input net first.

Generators must be specified as **fixed setpoints** (`p_min == p_max` and
`q_min == q_max`); a non-degenerate P/Q range is rejected, since a power flow has
no objective to select a dispatch within the range.

The result dict has the same structure as `solve_opf` (`bus`, `line`, `load`,
`generator`, `transformer`, `voltage_source`, …) plus `is_power_flow == true`.
Custom ownership follows the same `build_spec` contract, after the private
power-flow working copy has had operational limit fields removed.
For cases with Volt-var/Volt-watt profiles, `softplus=:user_defined` uses the
stable registered nonlinear operator. Pass `softplus=:builtin` explicitly for
current DiffOpt nonlinear wrappers; the built-in expression has a narrower
overflow-safe range.
"""
function BMOPFTools.solve_pf(net::Dict{String,Any};
                              optimizer=Ipopt.Optimizer,
                              t_index::Int=1,
                              per_unit::Bool=true,
                              s_base::Float64=1e6,
                              softplus::Symbol=:user_defined,
                              build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                              verbose::Bool=false,
                              solver_options=(),
                              model_hook!::Union{Function,Nothing}=nothing,
                              solution_hook!::Union{Function,Nothing}=nothing)
    _build_and_solve(net; optimizer=optimizer, t_index=t_index,
                     per_unit=per_unit, s_base=s_base,
                     problem=:power_flow,
                     softplus=softplus, build_spec=build_spec,
                     build! = build_pf!,
                     extract! = (ctx, result) -> (result["is_power_flow"] = true; nothing),
                     verbose, solver_options, model_hook!, solution_hook!)
end

"""
    build_pf!(ctx)

Build recipe for the determined power flow: strip operational limits, warm-start,
require fixed generator setpoints, add the device constraints, and set a trivial
(feasibility) objective. No voltage/bus/current bounds are added.
"""
function build_pf!(ctx::OpfContext)
    # ctx.net is the engine's private working copy (snapshot + per-unit already
    # applied), so removing limit fields here cannot affect the caller's dict.
    _strip_operational_limits!(ctx.net)

    BMOPFTools.set_opf_start_values!(ctx)

    _validate_pf_generators(ctx.net)

    # Device constraints only — no _add_voltage_and_bus_bounds!.
    BMOPFTools.add_opf_device_constraints!(ctx)

    # Feasibility objective: the equations fully determine the state.
    _run_opf_stage!(ctx, :objective,
        () -> @objective(ctx.model, Min, 0.0);
        required=(:device_physics,))
end

# Limit fields removed for a pure power flow. Each device helper guards on the
# field being present, so deleting them is sufficient to omit every operational
# current/thermal/apparent-power limit while leaving all KVL/KCL physics intact.
const _PF_LIMIT_FIELDS = ("i_max", "i_max_from", "i_max_to", "s_max")

"""
    _strip_operational_limits!(net)

Delete current/thermal/apparent-power limit fields from every component and
linecode in the (private working) network — including inline `line` limits
(which override the linecode's) and `dc_branch` `i_max`/`p_max` — so the power
flow imposes no operational limits. Voltage bounds are never added by
`build_pf!`, so they need no stripping. Transformer `s_rating` is deliberately
NOT stripped: it is a required field with a documented always-enforced
contract (see transformer_models.md); remove it from the input net to compare
against a limit-free reference.
"""
function _strip_operational_limits!(net::Dict{String,Any})
    # linecodes carry line thermal limits (i_max)
    for (_, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        for f in _PF_LIMIT_FIELDS
            delete!(lc, f)
        end
    end

    # flat component collections: line (inline limits override the linecode's),
    # switch, generator, ibr
    for coll in ("line", "switch", "generator", "ibr")
        for (_, comp) in get(net, coll, Dict())
            comp isa Dict || continue
            for f in _PF_LIMIT_FIELDS
                delete!(comp, f)
            end
        end
    end

    # DC branches carry their own limit fields (i_max, p_max). p_max is removed
    # only here — on generators/sources it is a dispatch setpoint, not a limit.
    for (_, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        for f in ("i_max", "p_max")
            delete!(br, f)
        end
    end

    # transformers are nested one level by subtype
    for (_, subdict) in get(net, "transformer", Dict())
        subdict isa Dict || continue
        for (_, xfmr) in subdict
            xfmr isa Dict || continue
            for f in _PF_LIMIT_FIELDS
                delete!(xfmr, f)
            end
        end
    end

    return nothing
end

"""
    _validate_pf_generators(net)

Throw an `ArgumentError` if any generator has a non-degenerate active or reactive
power range (`p_min != p_max` or `q_min != q_max`). A power flow has no objective
to select a point within a range, so generators must be fixed setpoints.
"""
function _validate_pf_generators(net::Dict{String,Any})
    for (gid, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        p_min = Float64.(get(gen, "p_min", Float64[]))
        p_max = Float64.(get(gen, "p_max", Float64[]))
        q_min = Float64.(get(gen, "q_min", Float64[]))
        q_max = Float64.(get(gen, "q_max", Float64[]))

        for (lo, hi, label) in ((p_min, p_max, "p"), (q_min, q_max, "q"))
            n = min(length(lo), length(hi))
            for k in 1:n
                if !isapprox(lo[k], hi[k]; atol=1e-9, rtol=1e-9)
                    throw(ArgumentError(
                        "Generator '$gid': $(label)_min[$k]=$(lo[k]) ≠ " *
                        "$(label)_max[$k]=$(hi[k]). solve_pf requires fixed " *
                        "generator setpoints ($(label)_min == $(label)_max); a " *
                        "power flow has no objective to choose a dispatch within " *
                        "a range. Use solve_opf for range-bounded generators."))
                end
            end
        end
    end
    return nothing
end
