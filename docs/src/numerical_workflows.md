# Scaling, initialization and diagnostics

Use this route when two nominally similar solves behave differently, or when
constructing a reproducible numerical experiment. The detailed equations and
supported scaling domains remain in the [OPF reference](opf.md#Units-and-scaling).
This page connects the controls to the evidence you should inspect.

## Choose coordinates deliberately

The input network and extracted results use SI units. Solver coordinates are a
separate choice. [`OpfScaling`](@ref) exposes SI, classic per-unit, and custom
consistent-base policies; an explicit `scaling_policy` takes precedence over
`per_unit` and `s_base`.

| Task | Where to go |
|:--|:--|
| Learn voltage/current/power bases and objective units | [Units, bases and economics](tutorial_units.md), which derives the classic bases by hand on a bundled feeder. |
| Choose a typed policy or experiment with zone-specific bases | [Custom and zone-local bases](#Custom-and-zone-local-bases) below, then [Units and scaling](opf.md#Units-and-scaling) for the qualified transformer/converter domains and rejected combinations. |
| Inspect the coordinates at an AC or DC location | [`opf_coordinate_bases`](@ref). Use the location's bases rather than assuming a universal power base. |
| Inspect model blocks, scaling and initialization evidence | [`opf_diagnostic_schema`](@ref). Check the returned capabilities before relying on semantic-block completeness. |
| Interpret objective weights or compare different norm encodings | [Objective weights](objectives.md#Weights-carry-units-—-and-that-is-deliberate), [norms](objectives.md#Which-norm?) and [pitfalls](objectives.md#objective-pitfalls). |

A scaling change is an experiment in numerical coordinates. Compare the
recovered physical quantities and residuals, as well as termination status and
solve time. The supported policy does not guarantee better conditioning or an
identical local solution from every starting point.

## Custom and zone-local bases

The `per_unit` and `s_base` keywords select the classic policy: one system
power base, with voltage bases seeded at the source and propagated through
isolating transformers. The typed [`OpfScaling`](@ref) boundary makes the same
choice explicit and lets you vary it reproducibly. The examples use the bundled
10 kV / 400 V feeder from the
[units tutorial](tutorial_units.md) and run when the documentation is built.

```@example scaling
using BMOPFTools, JuMP, Ipopt

net = parse_bmopf(joinpath(pkgdir(BMOPFTools), "test", "data",
                           "profiler_systems", "eu_tn_four_wire.json"))

ctx = build_opf_model(net; scaling_policy = OpfScaling(:classic; power_base = 1e6))
classic = opf_bases(ctx).v_base                    # propagated voltage base per bus
```

`OpfScaling(:si)` solves in SI, and `OpfScaling(:classic; power_base = …)` is
the keyword default spelled out. To change the voltage and power coordinates
together, supply a complete, compatible voltage-base map. Halving every
propagated voltage base while choosing a 200 kVA power base gives:

```@example scaling
custom_bases = Dict(bus => 0.5 * base for (bus, base) in classic)
policy = OpfScaling(
    name = :half_voltage_200kva,
    power_base = 200e3,
    voltage_bases = custom_bases,
)
ctx = build_opf_model(net; scaling_policy = policy)

opf_coordinate_bases(ctx, "mv").current == 200e3 / custom_bases["mv"]
```

This is intentionally a *consistent* family of coordinates. BMOPFTools checks
the line, switch, and transformer voltage-base relationships and derives the
current, impedance, and admittance bases from them. Arbitrary independent
bases would require coefficients in every voltage–current–power equation and
are not represented by this policy. When comparing two policies, first
establish that the physical solution and derivatives agree, and only then
compare solver trajectories; iteration counts alone are not evidence that the
mathematical problems match.

### Transformer-local power bases

A power base may also differ between galvanic zones. Pass per-bus
`power_bases` alongside the voltage bases — here 1 MVA on the MV side and the
transformer's 400 kVA rating on the LV side:

```@example scaling
zone_policy = OpfScaling(
    name = :transformer_local_power,
    voltage_bases = Dict(bus => base for (bus, base) in classic),
    power_bases = Dict(bus => (bus == "mv" ? 1e6 : 400e3) for bus in keys(classic)),
)
ctx = build_opf_model(net; scaling_policy = zone_policy)
evidence = opf_diagnostic_schema(ctx).transformer_scaling
(applied = evidence["applied_to_model"],
 identity = evidence["power_product_identity_passed"])
```

The rules that make such a policy admissible follow from the physics:

- Lines, closed switches, and galvanically continuous regulators share
  physical terminal currents, so with ``I_B = S_B / V_B`` their buses must keep
  **one** power base. A regulator's common bushing or straight-through phase
  also forces one voltage base: its tap is a winding coefficient, not a
  coordinate discontinuity.
- An isolating transformer is the natural boundary where the base may change.
  Its current-coupling, winding-power, KCL-injection, and rating equations then
  carry explicit side-base coefficients.

With a zone-local policy the engine derives local ``I``, ``Z``, and ``Y``
bases, stamps the side-base ratios into the transformer current balance and
leakage referral, scales device limits and costs on their owning zones, and
restores physical powers and losses with the side-local bases. A power-base
change is supported across every isolating subtype: `single_phase`,
`center_tap`, `wye_delta`, `delta_wye`, and `n_winding`. The two galvanically
continuous regulator families (`single_phase_autotransformer`,
`open_delta_regulator`) are excluded by design: a proposal with a voltage-base
or power-base jump across one is rejected before the model is built.

`opf_bases(ctx).s_base` is retained under a zone-local policy as a reference
value for compatibility and reporting; it is not a universal local power base.
Use `opf_coordinate_bases(ctx, bus).power` (or the `s_base_bus` table) when
writing a bus-local hook or interpreting a local residual.

How the coefficients enter, by subtype:

| Device | Where the base ratio appears |
|:--|:--|
| `wye_delta` / `delta_wye` | A reciprocal pair: delta terminal currents are converted into wye-current coordinates by ``S_\Delta / S_Y``, and delta-arm impedance acting on the wye current uses ``S_Y / S_\Delta``. The wye-coil nameplate and initialization use the wye-side base. |
| `center_tap` | The fixed 5×5 primitive is assembled on the primary power base. Secondary star impedances acquire ``S_\text{primary}/S_\text{secondary}``, the secondary shunt the reciprocal, and the three secondary current rows are transformed back to their local current base. The normalized primitive is generally nonsymmetric even though the physical primitive is reciprocal, as expected for an operator whose input and output coordinates use different power bases. |
| `n_winding` | Winding 1 defines the referred-current and ZB coordinates, so winding ``k`` enters ampere-turn balance and every ZB column as ``N_k (S_k / S_1) I_k``. The ZB matrix is divided once by the winding-1 impedance base; winding-local shunts, limits, and recovered results keep their owning winding's bases. |
| AC/DC converter | AC bus ``b`` uses its local ``S_\text{ac}(b)`` while the DC grid uses ``S_\text{dc}``, so the lossless converter equation carries ``S_\text{ac}(b)/S_\text{dc}``. In droop mode, `dc_p_ref` and the droop output keep the converter's AC power base; the voltage setpoint and deadband keep the DC voltage base. This covers the native lossless `P`, `V`, and `droop` formulations, not custom or lossy converter builders. |

`opf_coordinate_bases(ctx, bus)` and
`opf_coordinate_bases(ctx, bus; domain = :dc)` expose the voltage, current, and
power coordinates to hooks without relying on internal base tables, and
`opf_diagnostic_schema(ctx).acdc_scaling` records every stamped converter
coefficient and the qualified controller mode. Each of these domains is
covered by tests that compare SI and local-base solves on solved state,
losses, constraint sets, initialization, and physical Jacobians.

### Auditing a proposed base change

`opf_diagnostic_schema` can also audit a proposal *without* changing the
model. The snippet below is schematic: `"hv"` and `"delta"` stand for the buses
of a two-zone network of your own, and it does not run on the tutorial feeder.

```julia
proposal = opf_diagnostic_schema(
    ctx;
    voltage_bases = Dict("hv" => 6350.0, "delta" => 415 / sqrt(3)),
    power_bases = Dict("hv" => 10e6, "delta" => 1e6),
).transformer_scaling
proposal["proposal_admissible"]
proposal["power_product_identity_passed"]
proposal["requires_new_transformer_stamping"]
```

The report partitions buses into galvanically continuous zones and gives every
transformer interface's voltage-, current-, and power-coordinate ratios. It
checks the identity ``V_B I_B = S_B`` and records whether explicit current and
power conversion is required. For directly galvanic regulator interfaces it
also reports `galvanic_voltage_base_compatible`; a different voltage base makes
the proposal inadmissible even if the power base is unchanged. For a proposal
that differs from the context, `applied_to_model` stays `false`: this call
audits a design and never mutates an existing model.

### Power-base sensitivity

Keep the power base explicit when comparing solver settings. In
[issue #429](https://github.com/frederikgeth/BMOPFTools.jl/issues/429), the
default `s_base = 1e6` performed well on the measured French MV/LV feeders;
reducing it to `1e4` increased iterations from 35 to 97 on the reported 995-bus
example. These observations do not establish a universal best base. A base
derived from total load or the largest transformer rating has not been
validated by that comparison, and BMOPFTools keeps its 1 MVA default.

Per-zone power bases, written `OpfScaling(; voltage_bases, power_bases)`, are an
experimental coordinate policy with a qualified device domain. Seeding those
bases from transformer ratings is a separate experiment, not an automatic
recommendation. Compare physical results under the same initialization policy
as well as numerical effort, and do not infer a scaling defect only because a
chosen base differs from 1 MVA. The
[adaptive-barrier comparison](solvers.md#Trying-adaptive-barrier-updates-with-Ipopt)
holds the base fixed, so vary the power base in separate runs rather than
together with a solver-option change.

## Semantic blocks and local reference scales

After `enforce_kcl!(ctx)`, `opf_diagnostic_schema(ctx).semantic_blocks` lists
the engine's paired coordinates and residuals: rectangular real/imaginary
voltage and current pairs, active/reactive power pairs, and their paired KCL,
voltage-drop, device-power, transformer, switch, and source equations when
present. Each entry is a record (of the internal type `OpfSemanticBlock`, which
you read but do not construct) holding its ordered members, canonical component
labels, physical quantity and unit, model-to-canonical transform, and
residual-set contract.

The set contract is derived from the actual JuMP constraints. An equality to
the origin is `:zero_equality`; paired source-voltage or load-power equations
with nonzero right-hand sides are `:scalar_bounds`. The distinction matters:
treating every equality pair as a zero residual would make a physically false
covariance claim.

Selected declarations also carry a local physical reference scale and its
provenance. A load active/reactive residual pair, for example, uses the
per-phase nominal apparent-power magnitude when it is available. This is a
candidate nondimensionalization reference, not an instruction to mutate the
model and not the SI conversion factor. It lets an experiment compare
system-wide per-unit bases with device-local references without parsing JuMP
names or conflating units with numerical equilibration.

```@example scaling
enforce_kcl!(ctx)
blocks = opf_diagnostic_schema(ctx).semantic_blocks
load_blocks = filter(b -> b.quantity == :power &&
                          b.reference_physical_scale !== nothing, blocks)
(blocks = length(blocks), with_local_reference = length(load_blocks))
```

`opf_research_provenance(ctx)["semantic_references"]` serializes these
declarations, including reference-scale sources. Registration is metadata
only: it never changes variables, constraints, bounds, or coefficients.

## Inspect the start before tuning the solver

The [warm-start initialization](opf.md#Warm-start-initialisation) uses
network-wide source, grounding, conductor-map and winding relations to form a
zero-current phasor guess. Its transport diagnostics are available through
`opf_diagnostic_schema(ctx).initialization`. They describe the generated start,
not feasibility of the loaded network.

The initialization policy is invariant to the model coordinates: voltage
levels, phase-angle relationships, and zero neutrals are constructed in the
physical network semantics and then represented in the chosen units. A
different voltage base therefore changes `vr_init`/`vi_init` in model units but
not the physical initial state, which is what makes solver behavior comparable
across scaling policies.

For multi-voltage networks this is enforced by a network-wide sparse phasor
transport solve in per-bus nominal-voltage coordinates. Its rows use the actual
conductor maps and ideal winding equations, so a phase-B single-phase lateral
remains phase B after a label change, center-tap legs remain anti-phase, and
Yd/Dy or WYE/DELTA n-winding phase shifts compose through transformer chains.
Inspect the evidence rather than assuming it worked:

```@example scaling
initialization = opf_diagnostic_schema(ctx).initialization
(applied = initialization["applied"],
 residual = initialization["maximum_normalized_physics_residual"])
```

`initialization["maximum_normalized_residual_by_kind"]` breaks the residual down
by relation. The transport schema covers WYE, DELTA, center-tap, single-phase,
autotransformer, and open-delta relations. Zigzag would need an explicit
connection matrix in both the model and initialization layers and is not
supported.

Follow that section for the construction and its scope, then
[Trusting the solver](bounds/solver_trust.md) for solution branches and
start-dependence. The [solver guide](solvers.md#Settings-that-apply-to-all-three-solvers)
connects model coordinates, tolerances and independent validation. Changing
backends and changing a formulation are separate experiments.

## Keep a numerical experiment interpretable

For repeated coefficient changes, follow [Repeated solves](repeated_solves.md)
before reusing a model. For a reported operating point, capture
[`opf_research_provenance`](@ref) using the
[experiment-provenance guide](differentiable_extensions.md#Experiment-provenance).
It records scaling and model/parameter fingerprints as well as solver evidence;
full-model provenance collection can be expensive, so use study checkpoints.

Finish with [independent solution verification](tutorial_trust_but_verify.md).
For an additional re-solve comparison, use [solution projection](solution_projection.md).
These checks serve different purposes from model-coordinate diagnostics.
