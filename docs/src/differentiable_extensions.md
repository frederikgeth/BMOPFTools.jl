# Parameterized and differentiable extensions

BMOPFTools exposes the reference IVR-EN network formulation through a staged
JuMP model-construction API. Downstream packages can build the formulation into
a caller-supplied JuMP model, retain stable references to native variables and
constraints, register their own model objects and state, and add custom terminal
injections before KCL is finalized. This is the foundation for compatibility
with implicit-differentiation tools such as
[DiffOpt.jl](https://jump.dev/DiffOpt.jl/).

The intended architecture is deliberately split:

- **BMOPFTools** owns network physics, units, native device models, KCL, and the
  stable extension protocol;
- **downstream research packages** own parameter selection, bespoke devices and
  objectives, automatic-differentiation rules, bilevel semantics, outer solvers,
  caching, and discrete relaxations.

BMOPFTools does not present itself as a differentiable OPF solver. It provides
the parameterized construction substrate, selected native coefficient paths,
replaceable device builders, and conservative readiness diagnostics; the
downstream differentiation package remains responsible for computing and
validating sensitivities. Current native coverage, known limitations, and the
research provenance contract are documented below.

```@example differentiable_extensions
using BMOPFTools

voltage_key = opf_bus_voltage_key("bus_1", "a")
@assert voltage_key == OpfModelKey(:variable, :vr, ("bus_1", "a"))
spec = OpfBuildSpec()
@assert isempty(spec.component_builders)
```

## Mathematical scope

Consider the smooth parameterized nonlinear program

```math
\begin{aligned}
z^\star(\theta) \in \arg\min_z\quad & f(z,\theta) \\
\text{subject to}\quad & c(z,\theta)=0, \\
                         & g(z,\theta)\leq0.
\end{aligned}
```

Writing its local primal-dual optimality system as
``F(w^\star,\theta)=0``, implicit differentiation formally gives

```math
\frac{\partial w^\star}{\partial\theta}
=-
\left(\frac{\partial F}{\partial w}\right)^{-1}
\frac{\partial F}{\partial\theta},
```

when the relevant Jacobian is nonsingular. This is a **local sensitivity of the
selected primal-dual solution**. For the nonconvex IVR-EN formulation it is not a
derivative of a guaranteed global optimizer. Multiple local solutions,
degeneracy, finite solver tolerances, and initialization can change the selected
solution branch.

Classical perturbation analysis relates smooth solution sensitivity to
constraint qualifications, second-order sufficient conditions, and
complementarity/nondegeneracy assumptions [1]. DiffOpt implements forward and
reverse differentiation of optimization models through MathOptInterface model
transformations [2].

## Current extension substrate

The staged API retains the live JuMP model:

```@example differentiable_extensions
using JuMP, Ipopt

net = parse_bmopf("""
{"bus":{"b":{"terminal_names":["1","n"],
                   "perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"grid":{"bus":"b","terminal_map":["1"],
     "v_magnitude":[230.0],"v_angle":[0.0]}},
 "load":{"demand":{"bus":"b","terminal_map":["1","n"],
     "configuration":"SINGLE_PHASE","p_nom":[1000.0],"q_nom":[0.0]}}}
"""; from_string=true)

load_key = OpfCoefficientKey(:load, :load, "demand", :p_nom, 1)
provider = OpfCoefficientProvider(:DocsExample,
    (ctx, key, default) -> 1.1 * default)
spec = OpfBuildSpec(coefficient_providers=Dict(load_key => provider))

model = JuMP.Model(Ipopt.Optimizer)
ctx = initialize_opf_model(net; model, per_unit=false, build_spec=spec)
set_opf_start_values!(ctx)
add_opf_operational_limits!(ctx)
add_opf_device_constraints!(ctx)
set_opf_objective!(ctx)
enforce_kcl!(ctx)

report = opf_differentiability_report(ctx)
@assert opf_coefficient_usage(ctx)[load_key] == 1
@assert opf_lifecycle(ctx) == :kcl_finalized
@assert !report.ready  # the example deliberately has not been optimized
nothing
```

For extensions that need to intervene between native construction stages, use
the same composable sequence and insert their objects and injections before
`enforce_kcl!`. The convenience form remains:

```julia
ctx = build_opf_model(net; model=my_model, add_objective=false)
# add a downstream objective, constraints, devices, or parameter links
enforce_kcl!(ctx)
JuMP.optimize!(opf_model(ctx))
result = extract_result(ctx)
```

Stages are one-shot and order checked. In particular, operational limits cannot
be stamped after device physics, and KCL cannot be finalized before device
physics. `build_opf_model` runs this standard recipe and remains the preferred
entry point when an extension only needs the post-build hook.

Every context carries construction provenance:

```julia
manifest = opf_build_manifest(ctx)
manifest.problem             # :opf
manifest.formulation         # :ivr_en
manifest.stages              # ordered completed stages
manifest.component_owners    # native device-family ownership
opf_stage_completed(ctx, :device_physics)
```

The manifest is intentionally inspect-only for downstream code; builder
ownership is populated through the typed build specification below.

### Native semantic key constructors

Extension code should use named constructors for native variables instead of
reproducing abbreviated family names and tuple layouts:

```julia
vr = opf_object(ctx, opf_bus_voltage_key("bus_1", "a"))
vi = opf_object(ctx,
    opf_bus_voltage_key("bus_1", "a"; component=:imag))
cr = opf_object(ctx, opf_ibr_current_key("pv_1", 1))
tap = opf_object(ctx, opf_transformer_tap_key("regulator_1"))
```

Rectangular AC quantities use `component=:real` by default and accept
`:imag`. Branch-side arguments use `:from` or `:to`; conductor, winding, and
regulator positions are positive one-based integers. The constructors cover
all native registry families:

| Physical quantity | Constructor |
|:--|:--|
| Bus voltage | `opf_bus_voltage_key` |
| Perfect-ground AC current | `opf_ground_current_key` |
| Line current, including from/to aliases | `opf_line_current_key` |
| Switch current | `opf_switch_current_key` |
| Load current | `opf_load_current_key` |
| Generator current | `opf_generator_current_key` |
| Voltage-source current | `opf_voltage_source_current_key` |
| Two-winding transformer current | `opf_transformer_current_key` |
| Scalar or open-delta regulator tap | `opf_transformer_tap_key` |
| N-winding transformer current | `opf_nwinding_current_key` |
| Inverter/IBR current | `opf_ibr_current_key` |
| DC bus voltage and perfect-ground current | `opf_dc_voltage_key`, `opf_dc_ground_current_key` |
| DC branch current | `opf_dc_branch_current_key` |
| Converter DC-port current | `opf_converter_dc_current_key` |
| DC load current | `opf_dc_load_current_key` |
| DC source current and dispatched power | `opf_dc_source_current_key`, `opf_dc_source_power_key` |

These functions construct keys only; they do not require JuMP or a live context.
`OpfModelKey` remains public for extension-owned variables, expressions,
constraints, objectives, and future native families. Consequently this
convenience layer does not close the semantic namespace or constrain bespoke
research formulations.

## Replaceable device formulations

An `OpfBuildSpec` assigns a downstream callback to a complete device family or
to selected components. Unassigned components retain their native BMOPFTools
formulation:

```julia
builder = OpfDeviceBuilder(:PowerOptLab, build_priority_controlled_ibrs!)
spec = OpfBuildSpec(component_builders=Dict(
    (:ibr, "pv_17") => builder,
    (:ibr, "pv_42") => builder,
))
ctx = build_opf_model(net; model=my_model, build_spec=spec)
```

BMOPFTools calls `build_priority_controlled_ibrs!(ctx, ids)` with sorted IDs.
The callback replaces, rather than supplements, native physics for those IDs.
It should reuse native semantic variables when it wants the standard result
schema, register custom expressions and constraints with `OpfModelKey`, add
terminal currents with `add_terminal_injection!`, and register any extra
post-solve output through `register_opf_result_extractor!`.

Replacement transfers responsibility for every native equation associated with
the selected component: terminal injections, limits, control laws, auxiliary
variables, result semantics, and coupled physics. In particular, native IBR
ownership includes apparent-power/current limits and converter/DC balance.
Because the DC-coupling accumulator is not yet a public extension seam,
BMOPFTools rejects custom ownership of an IBR with `dc_bus` or
`dc_link_coupled=true` instead of constructing a partially disconnected model.

Whole-family replacement is available for `:voltage_source`, `:switch`,
`:shunt`, `:capacitor`, `:load`, `:generator`, `:ibr`, and `:grounding`.
Per-component native/custom partitioning is currently supported for those flat
collections except `:grounding`. A family-level and a component-level
assignment for the same family is rejected.

`:line` and `:transformer` replacement is rejected until the native branch
injection/result ledger has a public extension seam; accepting it now could
silently omit element flows and losses from `extract_result`. `:dc_network`
replacement is likewise rejected until downstream builders can contribute to
the DC-KCL accumulator through a public API. These are fail-closed capability
boundaries, not promises that a custom callback can fill private ledgers.
For a bespoke line model today, follow the [model-hook omit-and-re-stamp
guidance](dev/opf_engine.md#Authoring-a-model_hook!) instead.

```julia
function build_priority_controlled_ibrs!(ctx, ids)
    model = opf_model(ctx)
    net = opf_network(ctx)
    for id in ids
        inv = net["ibr"][id]
        # Retrieve :vr/:vi and :cri/:cii through opf_object, then stamp the
        # downstream control law and its phase/return current contributions.
    end
end
```

Builder ownership is recorded in `opf_build_manifest(ctx).component_owners`.
For mixed families the keys are `(family, id)` tuples; for wholly native or
wholly replaced families the key is the family symbol. Build specifications and
manifests are defensively copied when exposed, so an extension cannot silently
change ownership after construction begins.

Result extractors run deterministically by owner symbol after native extraction,
before a caller's `solution_hook!`, and before per-unit unwrapping. As with the
existing solution-hook contract, downstream result values must be written in SI
units. The repository's `test/fixtures/MockOpfExtension/` package is the
executable minimal-package example.

Use the public context accessors rather than importing the implementation module:

```julia
m      = opf_model(ctx)
net_w  = opf_network(ctx)  # snapshot + optional per-unit working copy
bases  = opf_bases(ctx)
stage  = opf_lifecycle(ctx)
```

Native variables are registered under stable keys. For example, the current
rectangular-voltage family is addressed as:

```julia
vr = opf_object(ctx,
    OpfModelKey(:variable, :vr, ("load_bus", "1")))
```

Downstream packages can register their own variables, expressions, and
constraints without sharing internal dictionaries:

```julia
pkey = OpfModelKey(:expression, :battery_active_power, "bat1")
register_opf_object!(ctx, pkey, P_bat)
```

### Semantic solution access

The same keys provide a stable post-solve interface. This lets an extension
define losses, reports, and derivative seeds without depending on JuMP names or
the private layout of `OpfContext`:

```julia
JuMP.optimize!(opf_model(ctx))

P_bat_value = opf_primal(ctx, pkey)
kcl_key = OpfModelKey(:constraint, :kcl_r, ("load_bus", "1"))
kcl_function_value = opf_constraint_value(ctx, kcl_key)
kcl_dual = opf_dual(ctx, kcl_key)
total_objective = opf_objective_value(ctx)
```

`opf_constraint_slack` returns signed slack for scalar inequalities: positive is
feasible, zero is active, and negative is violated. It returns `nothing` for
equalities and non-scalar sets. `opf_dual` deliberately preserves JuMP/MOI's
dual sign and shape; BMOPFTools does not reinterpret it as an economic price.
All functions accept `result=...` for solvers that provide multiple results.

Objective contributions can be registered without changing the model objective:

```julia
cost_key = OpfModelKey(:objective, :battery_degradation, "bat1")
register_opf_objective_term!(ctx, cost_key, degradation_cost)

JuMP.@objective(opf_model(ctx), Min,
    generation_cost(ctx) + opf_object(ctx, cost_key))
```

The native generation-cost expression is registered lazily as
`OpfModelKey(:objective, :generation_cost)` when it is built. Native variables,
KCL constraints, parameter-link constraints, and the generation-cost term have
semantic keys. A downstream builder must register each additional expression or
constraint it expects to query; BMOPFTools does not infer semantics from JuMP
names. The provenance snapshot inventories every registered reference and
records solved objective-term values.

### Regularization declarations and fingerprints

Regularization can isolate a local lower-level solution or improve numerical
conditioning, but it changes the optimization problem. BMOPFTools therefore
does not infer regularization from an objective expression. A downstream package
must register the objective contribution and declare it explicitly:

```julia
tie_break_key = OpfModelKey(:objective, :battery_tie_break)
register_opf_objective_term!(ctx, tie_break_key, ε * sum(abs2, battery_power))

register_opf_regularization!(ctx, :battery_tie_break;
    method=:tikhonov,
    weight=ε,
    units=:currency_per_watt2,
    term_key=tie_break_key,
    targets=battery_power_keys,
    purpose="Select a locally isolated lower-level dispatch",
    owner=:PowerOptLab,
    metadata=Dict("protocol" => "study-v1"))
```

Registration records a claim; it neither adds the term to the JuMP objective nor
proves that the declared coefficient matches the expression. This separation is
intentional because an extension owns the mathematical meaning. Duplicate names,
unknown semantic targets, negative/non-finite weights, and metadata that cannot
be deterministically encoded are rejected. `opf_regularizations(ctx)` returns
defensive metadata copies.

`opf_research_hashes(ctx)` returns SHA-256 fingerprints for five independently
changing layers:

- `prepared_working_network_sha256`: the snapshot actually presented to the
  engine after time selection and optional per-unit transformation;
- `model_structure_sha256`: variables, constraints, objective, construction
  manifest, and semantic keys, excluding solver results and parameter values;
- `parameter_state_sha256`: all current JuMP parameter values, including raw
  downstream parameters that were not bound through BMOPFTools; and
- `regularization_declarations_sha256`: the explicit declarations above; and
- `differentiability_annotations_sha256`: extension-declared nonsmooth,
  dynamically branched, and unsupported parameter locations.

Dictionary ordering does not affect the canonical value encoding. The model
fingerprint is a deterministic *construction fingerprint*, not a canonical
algebraic normal form: equivalent formulations, reordered nonlinear expression
trees, or different JuMP versions may hash differently. Conversely, matching
hashes establish matching encoded records, not physical validity, global
optimality, or model equivalence. Software versions are therefore retained next
to the hashes. SHA-256 follows the NIST Secure Hash Standard
([FIPS 180-4](https://doi.org/10.6028/NIST.FIPS.180-4)); it is used here for
reproducible identity, not as a security boundary.

Package-local state is namespaced:

```julia
state = extension_state!(ctx, PowerOptLab)
state[:battery_variables] = battery_variables
```

Custom devices contribute injected current through the supported KCL seam:

```julia
# Current is positive INTO the terminal. A WYE return has the opposite sign.
add_terminal_injection!(ctx, "load_bus", "1",  crb,  cib)
add_terminal_injection!(ctx, "load_bus", "n", -crb, -cib)
```

All expressions are in the model's working units. With the default
`per_unit=true`, downstream packages use `opf_bases(ctx)` when mapping SI
quantities into the model. The parameter registry records that mapping:

```julia
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

### Coefficient providers for bespoke builders

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
p = opf_coefficient(ctx, p_key, inverter["p_max"][1])
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

The following native scalar paths currently consume providers:

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

| Not yet provider-aware | Consequence |
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
encoding part of the study configuration and provenance.

Line matrix keys address the **total line impedance after length application**,
not a shared linecode entry. Thus two lines that reference one linecode may be
parameterized independently. Defaults are ohms in an SI model and per-unit
impedance in a per-unit model. For an SI-valued parameter in a per-unit model,
divide by the impedance base of the line's from bus, for example
`r_ohm / opf_bases(ctx).z_base[line["bus_from"]]`. Providers replace scalar
entries only: topology, conductor count, terminal maps, and matrix dimensions
remain structural. Updates can nevertheless change rank, passivity, or
conditioning, which the readiness report flags but does not certify.

### Differentiability readiness and qualifications

After optimization, call:

```julia
report = opf_differentiability_report(ctx)
report.ready || error(join(report.qualifications, "\n"))
```

The report checks construction lifecycle, termination status, discrete
variables, and unconsumed providers. It records parameter/coefficient keys and
classifies scalar inequalities from normalized primal slack and dual magnitude:
`active_constraints`, `near_active_constraints`,
`weakly_active_constraints`, and `violated_constraints`. Near-active and weakly
active constraints make `ready=false`; tolerances are explicit keywords so a
study can align them with its solver tolerances and report them. This catches
common active-set and strict-complementarity hazards, but is not a proof of LICQ,
second-order sufficiency, or solution-branch uniqueness.

Reports and research hashes inspect the complete JuMP model. When several
snapshot contexts share one model, model/constraint counts, residuals, active
sets, and readiness are therefore model-wide; semantic inventories and build
manifests remain context-owned. A report from one snapshot can consequently
reflect a constraint added by another snapshot. Treat this as a joint-model
qualification, not a per-snapshot certificate.

### Explicit differentiability annotations

A completed JuMP graph cannot, in general, reveal that an extension selected
its equations using Julia control flow, embedded a bespoke hard operator, or
accepted a parameter at a formulation-specific location whose structure may
change. Extension packages should declare these cases explicitly:

```julia
register_opf_differentiability_annotation!(ctx, :volt_watt_hard_priority;
    kind=:nonsmooth_operator,
    description="The lower-level priority rule contains a hard max",
    owner=:PowerOptLab,
    key=OpfModelKey(:expression, :pv_priority, "pv_1"))

register_opf_differentiability_annotation!(ctx, :fixed_scenario_regime;
    kind=:dynamic_branch,
    description="A regime was selected before construction and held fixed",
    owner=:PowerOptLab,
    blocking=false,
    metadata=Dict("study_protocol" => "fixed-regime-v1"))
```

The supported kinds are `:nonsmooth_operator`, `:dynamic_branch`, and
`:unsupported_parameter_location`. An optional `OpfModelKey` or
`OpfCoefficientKey` locates the issue. Annotations block readiness by default;
`blocking=false` is an explicit owner assertion that the disclosed choice is
fixed or otherwise outside the differentiated path. It remains in
`report.qualifications`, `opf_differentiability_annotations(ctx)`, provenance,
and the annotation hash. This mechanism is an auditable declaration, not static
analysis of extension code and not a proof that undeclared operations are
smooth.

### Refusing singular KKT derivatives

DiffOpt's nonlinear backend may apply inertia correction to a singular KKT
Jacobian. That can be useful numerically, but the resulting regularized
sensitivity answers a modified linear system. For a fail-closed research
workflow, install BMOPFTools' optional checked factorization before calling
DiffOpt:

```julia
JuMP.MOI.set(model, DiffOpt.NonLinearKKTJacobianFactorization(),
    opf_checked_kkt_factorization(ctx; pivot_tolerance=1e-10))

DiffOpt.set_forward_parameter(model, theta, 1.0)
DiffOpt.forward_differentiate!(model)  # throws OpfDifferentiationError if rejected

diagnostic = opf_kkt_diagnostic(ctx)
@assert diagnostic.status == :accepted
```

The callback uses sparse LU and records the matrix dimension, rejection
tolerance, and minimum-to-maximum absolute pivot ratio. The ratio is a cheap,
global-scale-invariant warning proxy, not an exact condition number. It deliberately
throws rather than returning zeros or silently regularizing a rejected system.
Installing the callback remains explicit because BMOPFTools does not depend on
DiffOpt or own downstream JVP/VJP execution. After an attempt, the diagnostic is
also incorporated into `opf_differentiability_report(ctx)`.

### Experiment provenance

`opf_research_provenance(ctx)` produces a fresh, JSON-compatible dictionary for
an experiment log:

```julia
provenance = opf_research_provenance(ctx;
    active_tolerance=1e-7,
    transition_tolerance=1e-5,
    dual_tolerance=1e-7)
open("run-provenance.json", "w") do io
    JSON3.write(io, provenance)
end
```

The versioned `BMOPFTools.opf_research_provenance/v1` record includes:

- Julia, BMOPFTools, JuMP, Ipopt, and solver-reported versions;
- formulation, problem recipe, SI/per-unit bases, completed stages, and device
  formulation owners;
- termination, raw/primal/dual statuses, objective, iterations, and solve time;
- variable/constraint counts, start-value coverage, maximum primal violation,
  normalized primal violation, and scalar complementarity product;
- the semantic variable/expression/constraint/objective reference inventory and
  solved objective-term values;
- deterministic working-data, model-structure, parameter-state,
  regularization-declaration, and differentiability-annotation SHA-256
  fingerprints;
- smoothing configuration and whether the explicitly selected
  DiffOpt-compatible built-in softplus encoding was used;
- parameter scopes, units, scales, current values, semantic targets and owners;
- coefficient-provider semantic keys, owners, and consumption counts;
- explicit downstream regularization and differentiability declarations; and
- the complete active-set classification and latest checked-KKT diagnostic.

The record is defensive: mutating it cannot modify the live context. Residuals
are best-effort over constraint sets supported by MathOptInterface's distance
metric. The absolute residual and complementarity product mix the model's
working units, so cross-case comparisons should use the normalized residual and
retain the per-unit/basis metadata. Downstream packages should still append the
DiffOpt version, outer objective and loss, random seeds, original-file hashes,
and hashes for data not represented in the prepared BMOPF network. BMOPFTools
cannot infer those choices.

Structure hashing and provenance serialize the full model and can be expensive
on large feeders. Capture them at auditable study checkpoints (normally once
after construction and once for a reported solution), not inside a parameter-
sweep hot loop.

## Scientific limitations

### Active-set changes

Inequality-constrained solution maps are generally piecewise smooth. DiffOpt's
nonlinear sensitivity is local and does not account for active-set changes [3].
Voltage limits, inverter capability curves, volt-watt activation, thermal
limits, battery bounds, and tap bounds are therefore scientifically important
transition points. Derivatives should be checked against directional or
one-sided perturbations near such points.

Interior-point solvers generally return a point slightly inside a mathematically
binding inequality. Consequently, the active and transition tolerances should
be no tighter than the study's observed primal/barrier residuals. The report
stores `minimum_inactive_slack` to make that calibration auditable.

### Nonuniqueness and regularization

When the lower problem has multiple solutions, ``argmin`` is set-valued. A
solver and its initialization select one solution; this is not automatically an
optimistic or pessimistic bilevel convention. A downstream package may add a
small regularization to isolate a solution, but must report that regularization
because it changes the mathematical problem.

### Discrete decisions

Switch states, exact tap steps, and binary battery modes have no ordinary
derivative. Enumeration, continuous relaxations, smoothing, surrogate gradients,
or mixed discrete/continuous outer methods belong in downstream research code
and must be stated explicitly.

### Solution versus value derivatives

Researchers should distinguish sensitivity of the optimizer
``\partial z^\star/\partial\theta``, sensitivity of the optimal value, and the
gradient of a downstream loss. The extension API exposes primitive model objects
so a research package can define the relevant mathematical quantity rather than
receiving an ambiguous generic “gradient.” Forward Jacobian-vector products and
reverse vector-Jacobian products are generally preferable to materializing a
dense Jacobian [4].

## Research directions

Differentiable optimization is used for optimization layers and
decision-focused learning [5, 6], bilevel and hyperparameter optimization [4,
7], differentiable model-predictive control [8], inverse problems and parameter
estimation, and learning constrained policies while retaining explicit physical
models.

Power-system applications include dynamic locational marginal emissions via
implicit differentiation [9], learning state-dependent robustness margins for
OPF [10], and distribution-system flexibility sensitivities [11]. More recent
work explores differentiating power-flow solutions with respect to admittance
and topology parameters [12]; that item is a preprint and is cited as emerging
work rather than established evidence.

The interface is intended to enable research in these directions without
claiming support for global sensitivities, exact discrete differentiation,
parameter-dependent topology without rebuilding, generalized derivatives, or
GPU-batched differentiable simulation.

## Reproducibility checklist

A publication using this capability should report, at minimum:

- BMOPFTools, JuMP, DiffOpt, and solver versions;
- the network snapshot and formulation choices;
- parameter and output definitions with SI/internal scaling;
- initialization, warm-start, regularization, and smoothing choices;
- termination status and primal/dual/complementarity residuals;
- the local active-set convention and tolerance;
- how nonconvex solution-branch consistency was assessed;
- finite-difference or analytic derivative checks away from transitions;
- the treatment of discrete controls and failed/singular derivative evaluations.

## References

1. J. F. Bonnans and A. Shapiro, “Optimization Problems with Perturbations: A
   Guided Tour,” *SIAM Review* 40(2), 228–264, 1998.
   [doi:10.1137/S0036144596302644](https://doi.org/10.1137/S0036144596302644)
2. M. Besançon, J. Dias Garcia, B. Legat, and A. Sharma, “Flexible
   Differentiable Optimization via Model Transformations,” *INFORMS Journal on
   Computing* 36(2), 456–478, 2024.
   [doi:10.1287/ijoc.2022.0283](https://doi.org/10.1287/ijoc.2022.0283)
3. [DiffOpt.jl nonlinear differentiation reference](https://jump.dev/DiffOpt.jl/stable/reference/).
4. M. Blondel et al., “Efficient and Modular Implicit Differentiation,”
   *NeurIPS*, 2022. [paper](https://papers.neurips.cc/paper_files/paper/2022/hash/228b9279ecf9bbafe582406850c57115-Abstract-Conference.html)
5. B. Amos and J. Z. Kolter, “OptNet: Differentiable Optimization as a Layer in
   Neural Networks,” *ICML*, 2017. [paper](https://proceedings.mlr.press/v70/amos17a.html)
6. A. Agrawal et al., “Differentiable Convex Optimization Layers,” *NeurIPS*,
   2019. [paper](https://papers.neurips.cc/paper_files/paper/2019/hash/9ce3c52fc54362e22053399d3181c638-Abstract.html)
7. S. Gould et al., “On Differentiating Parameterized Argmin and Argmax Problems
   with Application to Bi-level Optimization,” 2016.
   [preprint](https://arxiv.org/abs/1607.05447)
8. B. Amos et al., “Differentiable MPC for End-to-end Planning and Control,”
   *NeurIPS*, 2018. [paper](https://papers.neurips.cc/paper_files/paper/2018/hash/ba6d843eb4251a4526ce65d1807a9309-Abstract.html)
9. L. F. Valenzuela et al., “Dynamic Locational Marginal Emissions via Implicit
   Differentiation,” *IEEE Transactions on Power Systems*.
   [doi:10.1109/TPWRS.2023.3247345](https://doi.org/10.1109/TPWRS.2023.3247345)
10. R. Mieth and H. V. Poor, “Prescribed Robustness in Optimal Power Flow,”
    *Electric Power Systems Research* 235, 110704, 2024.
    [doi:10.1016/j.epsr.2024.110704](https://doi.org/10.1016/j.epsr.2024.110704)
11. “Sensitivity Analysis of Power Flow Solution in Distribution Network Using
    Differentiable Convex Programming,” *NAPS*, 2025.
    [doi:10.1109/NAPS66256.2025.11272437](https://doi.org/10.1109/NAPS66256.2025.11272437)
12. S. Talkington et al., “Differentiating Through Power Flow Solutions for
    Admittance and Topology Control,” 2025.
    [preprint](https://arxiv.org/abs/2510.17071)
