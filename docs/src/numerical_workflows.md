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
| Learn voltage/current/power bases and objective units | [Units, bases and economics](tutorial_units.md). Its feeder examples require the external dataset stated on that page. |
| Choose a typed policy or experiment with zone-specific bases | [Units and scaling](opf.md#Units-and-scaling), including the qualified transformer/converter domains and rejected combinations. |
| Inspect the coordinates at an AC or DC location | [`opf_coordinate_bases`](@ref). Use the location's bases rather than assuming a universal power base. |
| Inspect model blocks, scaling and initialization evidence | [`opf_diagnostic_schema`](@ref). Check the returned capabilities before relying on semantic-block completeness. |
| Interpret objective weights or compare different norm encodings | [Objective weights](objectives.md#Weights-carry-units-—-and-that-is-deliberate), [norms](objectives.md#Which-norm?) and [pitfalls](objectives.md#objective-pitfalls). |

A scaling change is an experiment in numerical coordinates. Compare the
recovered physical quantities and residuals, as well as termination status and
solve time. The supported policy does not guarantee better conditioning or an
identical local solution from every starting point.

## Inspect the start before tuning the solver

The [warm-start initialization](opf.md#Warm-start-initialisation) uses
network-wide source, grounding, conductor-map and winding relations to form a
zero-current phasor guess. Its transport diagnostics are available through
`opf_diagnostic_schema(ctx).initialization`. They describe the generated start,
not feasibility of the loaded network.

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
