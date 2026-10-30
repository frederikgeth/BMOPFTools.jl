# Choose your tutorial

The sidebar follows the workflow from understanding network data to preparing,
solving, and verifying a case. Advanced explanations, automation, and reference
material provide separate routes. This page helps you choose by goal; the
[homepage learning map](index.md#Find-your-route) shows how the sections connect.
[Choose an advanced route](advanced.md) for equation encodings, model extensions
and numerical experiments.

If you are new, follow [Installation & first steps](installation.md), then
[First case: inspect, solve and verify](first_case.md). The first case uses a
bundled synthetic feeder and needs no external data. You can stop after inspection
if you do not need a solver yet.

The [utility-data end-to-end tutorial](tutorial_end_to_end.md) is a later,
optional route. Its external dataset and license requirements are stated at the
start of that page; its dataset examples are not executed by the docs build.

## Route by goal

| I want to… | Start here | Then |
|---|---|---|
| **Explore a network visually** in the browser | [Visualizing a case with Tellegen](visualization.md) | [Analysis & reports](analysis.md), [Buses & terminals primer](terminals_primer.md) |
| **Convert OpenDSS** into a BMOPF case | [Conversion guide](conversion.md) | [Analysis & reports](analysis.md), [Utility-data end-to-end tutorial](tutorial_end_to_end.md) |
| **Derive model inputs from nameplate data** | [From nameplate data to a defensible model](tutorial_nameplate.md) | [Case augmentation](augmentation.md), [Data model conventions](conventions.md) |
| **Triage a messy import** (warnings, provenance, repairs) | [Findings triage](tutorial_triage.md) | [Finding-code reference](findings.md), [Analysis & reports](analysis.md) |
| **Turn transformer test data into model fields** | [From test report to transformer model](tutorial_transformer_tests.md) | [Transformer models](transformer_models.md), [Transformer spec](spec/transformer.md) |
| **Understand four-wire physics** (why terminals, neutrals, matrices) | [Buses & terminals primer](terminals_primer.md) | [Impedance models & OPF decisions](tutorial_impedance_models.md), [Line geometry](tutorial_line_geometry.md) |
| **Get grounding, neutrals, and sequence coordinates right** | [Ground, neutral, and earth return](tutorial_grounding.md) | [Grounding spec](spec/grounding.md), [SWER case study](tutorial_swer.md) |
| **Get units, per-unit bases, and cost right** | [Units, bases, scaling, and economics](tutorial_units.md) | [Units and scaling](opf.md#Units-and-scaling), [Objective spec](spec/objective.md) |
| **Pick a defensible load model** (CVR, hosting, collapse) | [Choosing and identifying a load model](tutorial_load_models.md) | [Load spec](spec/load.md), [Impedance models & OPF decisions](tutorial_impedance_models.md) |
| **Build a benchmark** an optimizer can respect | [Case augmentation](augmentation.md) | [From nameplate data to a defensible model](tutorial_nameplate.md), [DER placement](tutorial_ders.md) |
| **Diagnose an infeasible case** | [Infeasibility diagnosis](tutorial_infeasibility.md) | [Bounds & feasibility](bounds/index.md), [Trusting the solver](bounds/solver_trust.md) |
| **Verify a solved OPF** you don't yet trust | [Trust but verify](tutorial_trust_but_verify.md) | [Solution projection](solution_projection.md), [Engine validation evidence](validation.md) |
| **Model a specific device** (STATCOM, MVDC, regulator, PV droop) | [D-STATCOM study](tutorial_statcom.md) | [MVDC](tutorial_mvdc.md), [Tap optimization](tutorial_tap.md), [VVWO](tutorial_vvwo.md) |
| **Change the formulation** (custom objectives, constraints, multi-period) | [Custom formulations](tutorial_custom_formulations.md) | [OPF model](opf.md), [Units, bases & economics](tutorial_units.md) |
| **Assemble a network matrix or understand ideal-device boundaries** | [Nodal admittance builders](spec/nodal-admittance.md) | [Exact substitutions](formulation_substitutions.md), [Engine validation evidence](validation.md) |
| **Choose numerical coordinates or inspect initialization** | [Scaling, initialization and diagnostics](numerical_workflows.md) | [Solver guide](solvers.md), [Trusting the solver](bounds/solver_trust.md) |
| **Update coefficients and re-solve safely** | [Repeated solves](repeated_solves.md) | [Case families](tutorial_case_development.md), [Model extensions](differentiable_extensions.md) |
| **Build a differentiable or bilevel research extension** | [Model extensions and sensitivities](differentiable_extensions.md) | [Custom formulations](tutorial_custom_formulations.md), [OPF engine](dev/opf_engine.md) |
| **Extend or debug the solver** | [OPF engine: scope & status](dev/opf_engine.md) | [OPF model](opf.md), [Contributing](dev/contributing.md) |

## The judgment spine

Six of the tutorials, read in order, teach the reasoning a defensible study
needs — not just *how* to call the tools, but *when to trust the answer*:

1. **Triage** — [Findings triage](tutorial_triage.md). A raw import arrives
   with dozens of findings; learn to separate *defects* (fix), *judgment
   calls* (decide and document), and *disclosures* (keep — they are the
   case's provenance record).
2. **Assumptions** — [From nameplate data to a defensible model](tutorial_nameplate.md).
   Incomplete datasheets in; a model out. What can be *derived*, what needs an
   *assumption*, and what must stay *unknown* — and the difference between
   standards-derived, standards-inspired, and synthetic values.
3. **Solve** — [First case](first_case.md) and [Developing OPF case families](tutorial_case_development.md).
   Solve a supplied operating case, then compare explicit study scenarios.
4. **Verify** — [Trust but verify](tutorial_trust_but_verify.md). Take one solved
   OPF and independently recompute KCL, voltage bounds, thermal loading, losses,
   and the objective — learning what a solver's `LOCALLY_SOLVED` status does and
   does *not* guarantee.
5. **Consequences** — [Impedance models & OPF decisions](tutorial_impedance_models.md)
   and [Trusting the solver](bounds/solver_trust.md). How the modeling choices
   made in step 2 change the answer, and where the remaining traps live.
6. **Formulation** — [Custom formulations](tutorial_custom_formulations.md).
   When least-cost dispatch is not your question: hooks, replaced objectives,
   and multi-period coupling — with the discipline each rung demands.

Read top to bottom you get the missing arc: **triage → model assumptions →
solve → independent verification → fidelity consequences → your own
formulation.**

### [The modeling-choices track](@id The-modelling-choices-track)

Step 2's "assumptions" fan out into deep dives, one per modeling choice —
each demonstrating live how that choice *writes the answer*:

- [Units, bases, scaling, and economics](tutorial_units.md) — the three unit
  systems every result rests on.
- [Impedance models & OPF decisions](tutorial_impedance_models.md) — network
  fidelity, symmetry, and what balanced models hide.
- [Choosing and identifying a load model](tutorial_load_models.md) — when
  constant-P/I/Z, ZIP, or exponential behavior is defensible.
- [From test report to transformer model](tutorial_transformer_tests.md) —
  test data into validated fields, with the conventions made explicit.
- [Ground, neutral, and earth return](tutorial_grounding.md) — grounding
  assumptions, Kron reduction, and sequence coordinates.

## Prerequisites and example coverage

| Route | Software and data |
|---|---|
| [First case](first_case.md), inspection steps | BMOPFTools and the bundled feeder; no solver or external dataset. |
| [First case](first_case.md), solve and verify steps | BMOPFTools, JuMP and Ipopt; the same bundled feeder. |
| [Nodal admittance builders](spec/nodal-admittance.md) | BMOPFTools and Julia standard libraries; synthetic examples run in the docs build. |
| [DiffOpt worked example](differentiable_extensions.md#diffopt-worked-example) | Repository checkout and the optional `test/diffopt` environment (DiffOpt, JuMP, Ipopt); executed by the optional integration test job. |
| [Case families](tutorial_case_development.md) | BMOPFTools, JuMP and Ipopt; the bundled feeder and example script. |
| Utility-data tutorials, including [end-to-end](tutorial_end_to_end.md), [DER placement](tutorial_ders.md) and [PV controls](tutorial_vvwo.md) | Follow each page's external-dataset notice and software prerequisites. Reading a page does not require acquiring its data. |

The first-case Julia blocks execute during the docs build. Utility-data examples
marked **External dataset** are displayed as code and are not executed by that
build. Other pages state their own prerequisites; a data-modeling tutorial may
also run a solve to demonstrate the consequences of a modeling choice.

For the advanced [smooth-droop encoding note](relu_softplus_encoding.md), start
with the [PV control study](tutorial_vvwo.md) for the practical context, or read
[Power-flow inverter controls](opf.md#Power-flow-inverter-controls) for the
solver interface. Running the external-data study is not required to read the note.
