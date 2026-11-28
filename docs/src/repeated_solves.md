# Repeated solves, parameters and coefficient providers

Scenario studies, time series and sensitivity experiments all solve related
problems, but they do not necessarily share one model. Choose the workflow
before trying to reuse solver state. These workflows need JuMP and a suitable
optimizer; DiffOpt is needed only when requesting derivatives through DiffOpt.

## Choose what is shared

| What changes or couples? | Workflow | Detailed guide |
|:--|:--|:--|
| Network data or independent operating scenarios | Materialize each case/snapshot and build its model. This is the simplest baseline. | [Case families](tutorial_case_development.md), [time series](tutorial_timeseries.md). |
| Supported coefficient values in an already parameterized model | Update the registered JuMP parameters and follow the cached-model reset/re-solve workflow. | [Updating parameters and resolving](@ref opf-parameter-resolves), [`resolve_opf!`](@ref). |
| Topology, dimensions, device ownership or voltage-domain certificates | Rebuild the model; a coefficient update does not reconstruct these choices. | [Staged construction](differentiable_extensions.md#Current-extension-substrate), [device replacement](differentiable_extensions.md#Replaceable-device-formulations). |
| Decisions coupled between time periods | Build multiple contexts into one model, add coupling constraints and solve jointly. | [Multi-period and storage construction](@ref staged-api), [coupled-snapshot example](tutorial_custom_formulations.md#5.-Rung-3-—-two-snapshots,-one-model:-an-energy-budget). |

Updating the source network dictionary alone does not update an already built
JuMP model. For a parameterized path, the coefficient-provider reference defines
which quantities remain symbolic. A parameter that currently equals zero is
still a parameter; see [substitution boundaries](formulation_substitutions.md).

## Reuse needs a fresh solution check

After changing parameters, re-solve with [`resolve_opf!`](@ref), not another
`optimize!`: a reused optimizer can evaluate the nonlinear functions at a stale point
and still report success. [Updating parameters and resolving](@ref opf-parameter-resolves)
gives the recipe and its limits.

For sensitivity studies, the [DiffOpt example](@ref diffopt-worked-example)
compares analytic, forward, reverse and finite-difference derivatives on one
selected local solution branch. For experiment logs, use
[research provenance](differentiable_extensions.md#Experiment-provenance) at
appropriate checkpoints. For changes in base policy or initialization, return
to [Scaling, initialization and diagnostics](numerical_workflows.md).

## Binding parameters to model objects

A JuMP parameter can drive a semantic model object, so a scenario, forecast, or
learned value updates the model without rebuilding it.

All model expressions are in working units. With the default
`per_unit=true`, downstream packages use `opf_bases(ctx)` when mapping SI
quantities into the model. The parameter registry records that mapping:

```julia
# cr: a custom device's real current variable, injected into KCL as in
# "Extension state and terminal injections" (Extending the OPF model)
theta_A = @variable(opf_model(ctx), theta_A in Parameter(10.0))
cr_key = OpfModelKey(:variable, :custom_current_r, ("load_bus", "1"))
register_opf_object!(ctx, cr_key, cr)

binding = bind_opf_parameter!(ctx,
    OpfModelKey(:parameter, :injected_current_A, ("load_bus", "1")),
    theta_A, cr_key;
    scope=OpfParameterScope(:scenario, scenario_id),
    aliases=[:current_forecast],
    input_unit=:A,
    working_unit=:pu_current,
    to_working_scale=inv(opf_bases(ctx).i_base["load_bus"]),
    owner=:PowerOptLab)
```

The generated link is
`cr == binding.to_working_scale * theta_A`. DiffOpt therefore applies the
SI-to-working-coordinate factor through its normal forward and reverse chain
rule. `opf_parameter_binding(ctx, :current_forecast)` and
`opf_parameter_bindings(ctx)` expose defensive metadata copies for provenance.
A single parameter may target several semantic variables by passing a vector of
`OpfModelKey`s.

Bindings must be installed before `enforce_kcl!`. They can target scalar
decision or coefficient variables already registered in the same JuMP model.
They intentionally cannot change topology, terminal maps, array dimensions, or
other structure-dependent data: request `role=:structural` to obtain an explicit
error, then rebuild the model for that case.

## [Updating parameters and resolving](@id opf-parameter-resolves)

Parameter providers preserve symbolic model algebra under supported updates;
that is separate from the optimizer's numerical evaluation cache. This matters
in scenario sweeps, learning loops, and finite-difference sensitivity checks.

!!! warning "A successful repeat solve can still contain stale evaluations"
    After a parameter update, a reused optimizer can evaluate the nonlinear
    functions at a stale point: exponential-load parameters changed through
    nonzero → zero → nonzero have produced a successful status from both Ipopt and
    MadNLP while the currents violated the updated load law.

For an already finalized **cached JuMP model**, reset the optimizer and check the
residuals:

```julia
JuMP.set_parameter_value(p, new_value)
resolve_opf!(ctx)  # or resolve_opf!(ctx1, ctx2, ...) for one shared model
residuals = JuMP.primal_feasibility_report(model; atol=1e-8)
isempty(residuals) || error("Updated model has constraint violations")
```

The reset preserves JuMP handles, algebra, and optimizer attributes, but reloads
the optimizer and costs setup time. It does not preserve solver-internal
factorizations. The previous feasible solution, captured right after each
`optimize_opf!`/`resolve_opf!` solve, becomes the primal/dual warm start unless
`warm_start=false` is passed; see [`resolve_opf!`](@ref). Choose
residual tolerances in the model's working units and check physical currents,
limits, and reference conditions independently as well. The scalar `atol` above
is an example, not a universal engineering tolerance.

`resolve_opf!` explicitly reloads and solves once, preserves optimize hooks,
and refuses unfinished contexts or contexts from different models. Parameter
updates made outside this workflow do not automatically reset the backend.

This workflow is for cached models; `direct_model` requires a separately managed
optimizer and model rebuild. It does not make structural edits safe in place:
changes to topology, dimensions, or the physical voltage-domain certificates still
require rebuilding.

## Coefficient providers for bespoke builders

`OpfBuildSpec` can also carry typed coefficient providers. This keeps scenario,
forecast, learned, or parameterized values outside the BMOPF data dictionary
and lets a custom builder state exactly which semantic coefficient it consumes:

```julia
p_key = OpfCoefficientKey(
    :setpoint, :ibr, "pv1", :active_power, 1)

provider = OpfCoefficientProvider(:PowerOptLab,
    (ctx, key, native_value) -> learned_p_parameter)

spec = OpfBuildSpec(
    component_builders=Dict((:ibr, "pv1") => pv_builder),
    coefficient_providers=Dict(p_key => provider))

# Inside pv_builder:
p = opf_coefficient(ctx, p_key, opf_network(ctx)["ibr"]["pv1"]["p_max"][1])
@constraint(opf_model(ctx), active_power_expression == p)
```

Providers cover scalar loads, availability, setpoints, costs, limits,
controller coefficients, and physics coefficients through the key's semantic
`category`. They may return a number, JuMP parameter, or scalar expression, but
must return it in model working units. `opf_coefficient` returns the supplied
native default when no provider exists. Provider provenance is inspectable via
`opf_coefficient_provider` and `opf_coefficient_providers`.

This protocol is consumed explicitly by custom builders; it does not silently
rewrite every native BMOPFTools equation. Native coefficient families should be
made provider-aware deliberately, with formulation-specific scaling and tests.
Structural data is excluded from `OpfCoefficientKey`.

The following native scalar paths consume providers:

| Category | Family | Fields | Index |
|:--|:--|:--|:--|
| `:load` | `:load` | `:p_nom`, `:q_nom` | sub-load/phase index |
| `:availability` | `:generator` | `:p_max` | phase/element index |
| `:limit` | `:generator` | `:p_min`, `:q_min`, `:q_max` | phase/element index |
| `:availability` | `:ibr` | `:p_max` | phase/element index |
| `:limit` | `:ibr` | `:p_min`, `:q_min`, `:q_max` | phase/element index |
| `:controller` | `:control_profile` | `:volt_var_breakpoints`, `:volt_var_q_limits` | curve-point index |
| `:controller` | `:control_profile` | `:volt_watt_breakpoints`, `:volt_watt_p_limits` | curve-point index |
| `:physics` | `:line` | `:R_series`, `:X_series` | matrix index `(row, column)` |

Known native gaps are deliberate capability boundaries, not implied support:

| Not provider-aware | Consequence |
|:--|:--|
| IBR `s_max`, `i_max`, and `p_avail` | Capability circles, current limits, and some Volt-var/Volt-watt normalization bases remain fixed at build time |
| Native IBR and generator costs | Parameterize an extension-owned objective term instead |
| DC droop coefficients | Rebuild or own the downstream control formulation |
| Transformer impedance/tap-model coefficients | Native transformer physics remains fixed except for exposed tap decision bindings |
| Shared linecode entries | Line providers address each post-length line matrix, not the common source linecode |

For example, native PV availability is identified by
`OpfCoefficientKey(:availability, :ibr, "pv1", :p_max, 1)`. When a Volt-watt
curve uses `P_MAX` as its reference, this same live coefficient also scales its
curtailment envelope. Values are
always working-coordinate values. An SI-watt parameter therefore needs division
by `opf_bases(ctx).s_base` when the model is per-unit. Providers registered for
other native locations remain visible but are not consumed; use
`opf_coefficient_usage(ctx)` or the capability report below to detect this.

Controller breakpoints are resolved in working voltage coordinates. Their
count, nominal smoothing width, and hinge structure are fixed when the model is
built. Symbolic ordering constraints preserve the nominal strict order; moving
knots through one another makes the model infeasible instead of silently
changing its meaning. Ordinates use the profile's declared fractional or
absolute working coordinate. A control profile shared by several IBRs is
resolved once per working voltage base, so one profile-scoped key denotes one
live coefficient and one set of ordering guards. A parameterized profile shared
across different per-unit voltage bases is rejected because one working-unit key
cannot represent both conversions unambiguously.

The default `softplus=:user_defined` uses the registered, numerically stable
operator. DiffOpt wrappers that reject user-defined nonlinear operators require
the explicit `softplus=:builtin` build keyword. That native `log1p(exp(⋅))`
expression is less overflow-resistant; explicit opt-in makes the numerical
encoding part of the study configuration and provenance. The separate
`softplus=:swish` mode emits the native `logistic` primitive as
`z * logistic(z / ε)` for solver backends such as Gurobi. It is not a
softplus-equivalent approximation: its slope can become negative near a hinge,
and it should only be selected when the backend's native logistic support is
known.

Line matrix keys address the **total line impedance after length application**,
not a shared linecode entry. Thus two lines that reference one linecode may be
parameterized independently. Defaults are ohms in an SI model and per-unit
impedance in a per-unit model. For an SI-valued parameter in a per-unit model,
divide by the impedance base of the line's from bus, for example
`r_ohm / opf_bases(ctx).z_base[line["bus_from"]]`. Providers replace scalar
entries only: topology, conductor count, terminal maps, and matrix dimensions
remain structural. Updates can nevertheless change rank, passivity, or
conditioning, which the readiness report flags but does not certify.

```@docs
resolve_opf!
```
