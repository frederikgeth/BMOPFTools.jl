# [Extending the OPF model](@id Parameterized-and-differentiable-extensions)

Use the extension API to build a custom study into your own JuMP model, replace
supported device formulations, read their results through stable semantic keys,
and record what you built. None of this needs DiffOpt.

| Your task | Start with |
|:--|:--|
| Build into a caller-owned JuMP model | [Staged construction](#Current-extension-substrate). |
| Replace supported device physics and extract custom results | [Replaceable device formulations](#Replaceable-device-formulations) and [semantic solution access](#Semantic-solution-access). |
| Add a custom device's current to KCL | [Extension state and terminal injections](#Extension-state-and-terminal-injections). |
| Couple periods or scenarios in one optimization | [Multi-period construction](@ref staged-api). |
| Bind parameters, supply coefficients, or re-solve after an update | [Repeated solves, parameters and coefficient providers](repeated_solves.md). |
| Record model ownership, scaling and parameter fingerprints | [Experiment provenance](#Experiment-provenance). |
| Compute a local solution sensitivity | [Sensitivities with DiffOpt](@ref diffopt-sensitivities). |

Start with [First case](first_case.md) and basic JuMP model construction.
[Custom formulations](tutorial_custom_formulations.md) introduces the extension
ladder; [Advanced routes](advanced.md) connects it to encodings and numerics.

## Who owns which part?

BMOPFTools supplies the staged reference IVR-EN formulation, units, device
physics, KCL, parameter hooks and stable semantic object references. Downstream
code chooses its own objectives, devices, parameters and outputs, and decides how
to validate them. For which variables and equations can be substituted, see
[exact substitutions and formulation boundaries](formulation_substitutions.md).

## [Staged construction](@id Current-extension-substrate)

The staged API retains the live JuMP model:

```@example differentiable_extensions
using BMOPFTools, JuMP, Ipopt

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
`enforce_kcl!`. The convenience form is:

```julia
ctx = build_opf_model(net; model=my_model, add_objective=false)
# add a downstream objective, constraints, devices, or parameter links
optimize_opf!(ctx)        # finalizes KCL and solves; records the warm start for resolve_opf!
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
For extension-owned variables, expressions, constraints, and objectives, use
`OpfModelKey` directly; the named constructors are a convenience for native
objects and do not limit what an extension can register.

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
Because the DC-coupling accumulator is not a public extension seam,
BMOPFTools rejects custom ownership of an IBR with `dc_bus` or
`dc_link_coupled=true` instead of constructing a partially disconnected model.

Whole-family replacement, `OpfBuildSpec(family_builders=Dict(:ibr => builder))`, is
available for `:voltage_source`, `:switch`, `:shunt`, `:capacitor`, `:load`,
`:generator`, `:ibr`, and `:grounding`. Per-component native/custom partitioning
(`component_builders`) is supported for those flat collections except
`:grounding`. A family-level and a component-level assignment for the same family
is rejected.

`:line` and `:transformer` replacement is rejected, because the native branch
injection and result ledger is not a public extension seam; accepting it could
silently omit element flows and losses from `extract_result`. `:dc_network`
replacement is rejected because downstream builders cannot contribute to the
DC-KCL accumulator through a public API. For a bespoke line model, follow the [model-hook omit-and-re-stamp
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

## Semantic solution access

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

## Extension state and terminal injections

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

## Regularization declarations and fingerprints

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
  downstream parameters that were not bound through BMOPFTools;
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

## Experiment provenance

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

- Julia, BMOPFTools, JuMP, and solver-reported versions. `software`
  records the version of whichever solver package is actually in use
  under `solver_package` (`name` plus `version`, e.g. `Ipopt`,
  `MadNLP`, or `Gurobi`), not a fixed solver key;
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
  DiffOpt-compatible built-in softplus or native-logistic Swish encoding was
  used;
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
