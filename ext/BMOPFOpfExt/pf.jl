# Power flow — determined four-wire IVR-EN nodal solve.
#
# A power flow is the same physics as solve_opf / solve_feasibility_opf with two
# deliberate omissions that make it a *determined* problem rather than an
# optimization:
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
# a non-degenerate range is rejected with a clear error. Volt-var controls fix Q
# as a function of voltage, but Volt-watt only caps P; a profile alone does not
# determine active dispatch under the zero objective.

"""
    BMOPFTools.solve_pf(net; optimizer=_default_optimizer(), t_index=1,
                        per_unit=true, s_base=1e6,
                        softplus=:user_defined,
                        build_spec=OpfBuildSpec()) -> Dict

Determined four-wire rectangular current-voltage (IVR-EN) power flow on a BMOPF
network dict.

Same device models as [`solve_opf`](@ref) with **no objective** and operational
bounds removed except transformer nameplate caps — the network's physics (fixed source voltages + constant-power
injections + exact KCL) fully determine the solution. Device current/thermal
limits and voltage bounds, apart from the nameplate exception below, are ignored; use `solve_opf` (or a
post-solve validation pass) when limits must be enforced.

**One exception**: when a transformer declares a nameplate `s_rating`, its
per-coil apparent-power cap is **always enforced**, in the power flow too — loading any coil beyond `s_rating / n_phase` can make the PF
return `LOCALLY_INFEASIBLE` rather than report an overloaded state. The status
alone is not a global infeasibility certificate. This is easy
to misread as a numerical failure (healthy voltages, no other limits). To
solve without the nameplate — e.g. to compare against a limit-free OpenDSS
solve — delete `s_rating` from the transformer dicts in the input net first.

Generators must be specified as **fixed setpoints** (`p_min == p_max` and
`q_min == q_max`); a non-degenerate P/Q range is rejected, since a power flow has
no objective to select a dispatch within the range.

IBR `s_max` ratings are retained as the per-phase base of `S_MAX`/`VAR_MAX`
controller curves, but their apparent-power constraints are omitted. Volt-var
still imposes its reactive-power equality, and Volt-watt still imposes its
active-power cap. A Volt-watt cap alone does not determine active dispatch;
provide fixed active-power setpoints for a determined case, or use `solve_opf`
with an explicit dispatch objective.

The result dict has the same structure as `solve_opf` (`bus`, `line`, `load`,
`generator`, `transformer`, `voltage_source`, …) plus `is_power_flow == true`.
Custom ownership follows the same `build_spec` contract, after the private
power-flow working copy has had operational limit fields removed.
For cases with Volt-var/Volt-watt profiles, `softplus=:user_defined` uses the
stable registered nonlinear operator. Pass `softplus=:builtin` explicitly for
current DiffOpt nonlinear wrappers; the built-in expression has a narrower
overflow-safe range. Pass `softplus=:swish` for a native `logistic`-based
encoding on backends that support that primitive; Swish is solver-specific and
does not preserve softplus's monotonicity or convexity.
"""
function BMOPFTools.solve_pf(net::Dict{String,Any};
                              optimizer=_default_optimizer(),
                              t_index::Int=1,
                              per_unit::Bool=true,
                              s_base::Float64=1e6,
                              scaling_policy::Union{
                                  BMOPFTools.AbstractOpfScalingPolicy,Nothing}=nothing,
                              softplus::Symbol=:user_defined,
                              build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                              verbose::Bool=false,
                              solver_options=(),
                              model_hook!::Union{Function,Nothing}=nothing,
                              solution_hook!::Union{Function,Nothing}=nothing)
    _build_and_solve(net; optimizer=optimizer, t_index=t_index,
                     per_unit=per_unit, s_base=s_base, scaling_policy,
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
    _validate_pf_ibrs(ctx.net)

    # Device constraints only — no _add_voltage_and_bus_bounds!.
    BMOPFTools.add_opf_device_constraints!(ctx)

    # The checks above read the case. A coefficient provider can still replace
    # a fixed bound with a different number or a live parameter while the model
    # is built, so determinacy is confirmed once more on the rows actually
    # stamped.
    _validate_pf_resolved_dispatch(ctx)

    # Feasibility objective: the equations fully determine the state.
    _run_opf_stage!(ctx, :objective,
        () -> @objective(ctx.model, Min, 0.0);
        required=(:device_physics,))
end

# Limit fields removed for a pure power flow. IBR s_max also parameterizes
# controller curves, so it is retained and its constraint is skipped by the
# IBR builder for the power-flow recipe.
const _PF_LIMIT_FIELDS = ("i_max", "i_max_from", "i_max_to", "s_max")

"""
    _strip_operational_limits!(net)

Delete current/thermal/apparent-power limit fields from components and
linecode in the (private working) network — including inline `line` limits
(which override the linecode's) and `dc_branch` `i_max`/`p_max` — so the power
flow omits those operational limits. IBR `s_max` is retained as a controller
normalization parameter; the IBR builder skips its apparent-power constraint.
Voltage bounds are never added by
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
    # switch, generator
    for coll in ("line", "switch", "generator")
        for (_, comp) in get(net, coll, Dict())
            comp isa Dict || continue
            for f in _PF_LIMIT_FIELDS
                delete!(comp, f)
            end
        end
    end

    # Keep IBR s_max: S_MAX/VAR_MAX droop laws use it as a rating base even
    # when the apparent-power constraint is disabled. Only strip current caps.
    for (_, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        for f in ("i_max", "i_max_from", "i_max_to")
            delete!(inv, f)
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
            # n_winding ratings live per winding, one level further down, and
            # are deliberately KEPT: a winding's `s_max` is that transformer's
            # nameplate (the counterpart of the always-enforced `s_rating`),
            # and its `i_max` is enforced with it.
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
# One side of a fixed setpoint: both bounds present, ONE ENTRY PER COIL, and
# equal. A missing, short, or one-sided bound leaves a coil's power free, which
# a power flow (no objective) cannot resolve — it would return wherever the
# start point happened to lead.
function _require_fixed_setpoint(owner, label, lo, hi, ncoils::Int)
    (length(lo) == ncoils && length(hi) == ncoils && ncoils > 0) || throw(ArgumentError(
        "$owner: solve_pf requires $(label)_min and $(label)_max with one " *
        "entry for each of its $ncoils coil(s) and $(label)_min == $(label)_max. " *
        "A power flow has no objective to choose a dispatch, so a missing, " *
        "short, or one-sided bound leaves the operating point undetermined. " *
        "Use solve_opf for range-bounded devices."))
    for k in eachindex(lo)
        # Relative comparison: the working values may be per-unit or SI.
        isapprox(lo[k], hi[k]; rtol=1e-9, atol=1e-12 * max(1.0, abs(lo[k]))) ||
            throw(ArgumentError(
                "$owner: $(label)_min[$k] ≠ $(label)_max[$k]. solve_pf requires " *
                "fixed setpoints ($(label)_min == $(label)_max); a power flow has " *
                "no objective to choose a dispatch within a range. Use solve_opf " *
                "for range-bounded devices."))
    end
    return nothing
end

function _validate_pf_generators(net::Dict{String,Any})
    nlabels = BMOPFTools._neutral_labels(net)
    for (gid, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        ncoils = length(first(_generator_positions(
            Vector{String}(get(gen, "terminal_map", String[])),
            get(gen, "configuration", "WYE"), nlabels)))
        for label in ("p", "q")
            _require_fixed_setpoint("Generator '$gid'", label,
                Float64.(get(gen, "$(label)_min", Float64[])),
                Float64.(get(gen, "$(label)_max", Float64[])), ncoils)
        end
    end
    return nothing
end

"""
    _dc_side_fixes_active_power(inv) -> Bool

Whether the DC side supplies the ONE equation that determines a single-coil
IBR's active power, so that no fixed AC setpoint is needed:

- a private DC link (`dc_link_coupled`) with a zero-width balance
  (`p_dc_min == p_dc_max`); a balance *range* determines nothing;
- a `dc_bus` converter in `"droop"` mode (its V–P law) or `"V"` mode (it
  balances the DC network at its voltage reference). A `"P"`-mode converter is
  a dispatched injection, so the DC side determines nothing for it.
"""
function _dc_side_fixes_active_power(inv)
    if haskey(inv, "dc_bus")
        return String(get(inv, "dc_control", "P")) in ("V", "droop")
    elseif get(inv, "dc_link_coupled", false) === true
        return Float64(get(inv, "p_dc_min", 0.0)) == Float64(get(inv, "p_dc_max", 0.0))
    end
    return false
end

"""
    _validate_pf_ibrs(net)

Require every IBR to be a determined device, **coil by coil**. The test is
which equations fix the dispatch, not which fields are present.

- **Active power** must be a fixed setpoint per coil (`p_min == p_max`). A
  Volt-watt curve only *caps* P, so it does not determine it. The exception is
  a **single-coil** unit whose DC side supplies the determining equation
  ([`_dc_side_fixes_active_power`](@ref)). A multi-coil DC-coupled unit is not
  exempt, because the DC side fixes only the *sum* of its coil powers.
- **One free voltage master per DC port.** Voltage masters sharing a port
  assert one voltage equation between them, which determines one active power.
  A second master without a fixed setpoint leaves the split between them free.
- **Reactive power** must be fixed per coil (`q_min == q_max`) or set by a
  control equality the builder actually stamps for this device
  ([`_ibr_reactive_law`](@ref)): a constant power factor, or a Volt-var curve
  on a topology that supports one. A declared but unapplied law — Volt-var on
  `THREE_LEG`, or a malformed curve — does not count.
"""
function _validate_pf_ibrs(net::Dict{String,Any})
    profiles = get(net, "control_profile", Dict())
    nlabels = BMOPFTools._neutral_labels(net)
    free_masters = Dict{Any,Vector{String}}()   # DC port => masters without fixed P
    dc_classes = _dc_node_classes(net)
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        owner = "IBR '$id'"
        ncoils = _ibr_coil_count(inv, nlabels)
        p_lo = Float64.(get(inv, "p_min", Float64[]))
        p_hi = Float64.(get(inv, "p_max", Float64[]))
        dc_sets_p = ncoils == 1 && _dc_side_fixes_active_power(inv)
        dc_sets_p || _require_fixed_setpoint(owner, "p", p_lo, p_hi, ncoils)
        if dc_sets_p && haskey(inv, "dc_bus") &&
                String(get(inv, "dc_control", "P")) == "V" &&
                !(length(p_lo) == length(p_hi) == 1 && p_lo[1] == p_hi[1])
            # The same electrical port: ideal ties and perfect grounds merge
            # terminals, so masters at opposite ends of a zero-ohm conductor
            # share one voltage equation.
            terminals = string.(get(inv, "dc_terminal_map", String[]))
            isempty(terminals) && continue
            port = first(_dc_port_key(dc_classes, String(inv["dc_bus"]), terminals))
            push!(get!(free_masters, port, String[]), String(id))
        end
        _ibr_reactive_law(inv, profiles) === nothing &&
            _require_fixed_setpoint(owner, "q",
                Float64.(get(inv, "q_min", Float64[])),
                Float64.(get(inv, "q_max", Float64[])), ncoils)
    end
    for (port, masters) in free_masters
        length(masters) <= 1 || throw(ArgumentError(
            "solve_pf: DC port $(port) has $(length(masters)) voltage-master " *
            "converters without a fixed active-power setpoint (" *
            join(sort!(masters), ", ") * "). Their shared voltage equation " *
            "determines one active power, so the split between them is free. " *
            "Fix p_min == p_max on all but one, or use solve_opf."))
    end
    return nothing
end

# Whether the stamped rows fix one power of one coil: a single equality, or a
# lower/upper pair whose two sides are the SAME function with the same bound
# (one live parameter used for both ends of a setpoint).
function _pf_rows_fix(ctx, prefix::Symbol, index)
    row(side) = get(ctx.objects, BMOPFTools.OpfModelKey(
        :constraint, Symbol(prefix, :_, side), index), nothing)
    row(:equality) === nothing || return true
    lower, upper = row(:lower), row(:upper)
    (lower === nothing || upper === nothing) && return false
    lo = JuMP.constraint_object(lower); hi = JuMP.constraint_object(upper)
    (lo.set isa MOI.GreaterThan && hi.set isa MOI.LessThan) || return false
    return lo.set.lower == hi.set.upper && JuMP.isequal_canonical(lo.func, hi.func)
end

"""
    _validate_pf_resolved_dispatch(ctx)

Confirm, on the constraint rows the builder stamped, that every generator and
IBR coil the case-level checks accepted as a fixed setpoint is still one. This
catches a coefficient provider that widens a bound (`p_min == p_max` in the
case, a range in the model): the case passes, the model has free dispatch.
"""
function _validate_pf_resolved_dispatch(ctx::OpfContext)
    isempty(ctx.build_spec.coefficient_providers) && return nothing
    net = ctx.net
    nlabels = BMOPFTools._neutral_labels(net)
    profiles = get(net, "control_profile", Dict())
    fail(owner, label, k) = throw(ArgumentError(
        "$owner coil $k: solve_pf requires a fixed $(label) setpoint, but the " *
        "resolved model bounds it by a range. A coefficient provider replaced " *
        "$(label)_min or $(label)_max; supply the same value or the same " *
        "parameter for both, or use solve_opf."))
    for (gid, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        ncoils = length(first(_generator_positions(
            Vector{String}(get(gen, "terminal_map", String[])),
            get(gen, "configuration", "WYE"), nlabels)))
        for k in 1:ncoils, label in (:p, :q)
            _pf_rows_fix(ctx, Symbol(:generator_, label), (string(gid), k)) ||
                fail("Generator '$gid'", label, k)
        end
    end
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        ncoils = _ibr_coil_count(inv, nlabels)
        dc_sets_p = ncoils == 1 && _dc_side_fixes_active_power(inv)
        q_law = _ibr_reactive_law(inv, profiles) !== nothing
        for k in 1:ncoils
            dc_sets_p || _pf_rows_fix(ctx, :ibr_p, (string(id), k)) || fail("IBR '$id'", :p, k)
            q_law || _pf_rows_fix(ctx, :ibr_q, (string(id), k)) || fail("IBR '$id'", :q, k)
        end
    end
    return nothing
end
