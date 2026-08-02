# Choose your tutorial

The documentation is organised by *topic* — data model, case preparation, OPF,
bounds. That is the right shape for reference, but not always for a newcomer who
knows their **goal** and wants a starting point. This page routes by goal.

If you are brand new, read the [end-to-end tutorial](tutorial_end_to_end.md)
first — it is the one-sitting overview every path below assumes.

## Route by goal

| I want to… | Start here | Then |
|---|---|---|
| **Convert** OpenDSS / nameplate data into a BMOPF case | [From nameplate data to a defensible model](tutorial_nameplate.md) | [Conversion guide](conversion.md), [Case augmentation](augmentation.md) |
| **Triage a messy import** (warnings, provenance, repairs) | [Findings triage](tutorial_triage.md) | [Finding-code reference](findings.md), [Analysis & reports](analysis.md) |
| **Turn transformer test data into model fields** | [From test report to transformer model](tutorial_transformer_tests.md) | [Transformer models](transformer_models.md), [Transformer spec](spec/transformer.md) |
| **Understand four-wire physics** (why terminals, neutrals, matrices) | [Buses & terminals primer](terminals_primer.md) | [Impedance models & OPF decisions](tutorial_impedance_models.md), [Line geometry](tutorial_line_geometry.md) |
| **Get grounding, neutrals, and sequence coordinates right** | [Ground, neutral, and earth return](tutorial_grounding.md) | [Grounding spec](spec/grounding.md), [SWER case study](tutorial_swer.md) |
| **Get units, per-unit bases, and cost right** | [Units, bases, scaling, and economics](tutorial_units.md) | [Units and scaling](opf.md#Units-and-scaling), [Objective spec](spec/objective.md) |
| **Pick a defensible load model** (CVR, hosting, collapse) | [Choosing and identifying a load model](tutorial_load_models.md) | [Load spec](spec/load.md), [Impedance models & OPF decisions](tutorial_impedance_models.md) |
| **Build a benchmark** an optimiser can respect | [Case augmentation](augmentation.md) | [From nameplate data to a defensible model](tutorial_nameplate.md), [DER placement](tutorial_ders.md) |
| **Diagnose an infeasible case** | [Infeasibility diagnosis](tutorial_infeasibility.md) | [Bounds & feasibility](bounds/index.md), [Trusting the solver](bounds/solver_trust.md) |
| **Verify a solved OPF** you don't yet trust | [Trust but verify](tutorial_trust_but_verify.md) | [Trusting the solver](bounds/solver_trust.md), [Validating the OPF](validation.md) |
| **Model a specific device** (STATCOM, MVDC, regulator, PV droop) | [D-STATCOM study](tutorial_statcom.md) | [MVDC](tutorial_mvdc.md), [Tap optimisation](tutorial_tap.md), [VVWO](tutorial_vvwo.md) |
| **Change the formulation** (custom objectives, constraints, multi-period) | [Custom formulations](tutorial_custom_formulations.md) | [OPF model](opf.md), [Units, bases & economics](tutorial_units.md) |
| **Build a differentiable or bilevel research extension** | [Parameterized and differentiable extensions](differentiable_extensions.md) | [Custom formulations](tutorial_custom_formulations.md), [OPF engine](dev/opf_engine.md) |
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
3. **Solve** — [end-to-end tutorial](tutorial_end_to_end.md) and the
   [OPF model](opf.md). Turn the model into a solved dispatch.
4. **Verify** — [Trust but verify](tutorial_trust_but_verify.md). Take one solved
   OPF and independently recompute KCL, voltage bounds, thermal loading, losses,
   and the objective — learning what a solver's `LOCALLY_SOLVED` status does and
   does *not* guarantee.
5. **Consequences** — [Impedance models & OPF decisions](tutorial_impedance_models.md)
   and [Trusting the solver](bounds/solver_trust.md). How the modelling choices
   made in step 2 change the answer, and where the remaining traps live.
6. **Formulation** — [Custom formulations](tutorial_custom_formulations.md).
   When least-cost dispatch is not your question: hooks, replaced objectives,
   and multi-period coupling — with the discipline each rung demands.

Read top to bottom you get the missing arc: **triage → model assumptions →
solve → independent verification → fidelity consequences → your own
formulation.**

### The modelling-choices track

Step 2's "assumptions" fan out into deep dives, one per modelling choice —
each demonstrating live how that choice *writes the answer*:

- [Units, bases, scaling, and economics](tutorial_units.md) — the three unit
  systems every result rests on.
- [Impedance models & OPF decisions](tutorial_impedance_models.md) — network
  fidelity, symmetry, and what balanced models hide.
- [Choosing and identifying a load model](tutorial_load_models.md) — when
  constant-P/I/Z, ZIP, or exponential behaviour is defensible.
- [From test report to transformer model](tutorial_transformer_tests.md) —
  test data into validated fields, with the conventions made explicit.
- [Ground, neutral, and earth return](tutorial_grounding.md) — grounding
  assumptions, Kron reduction, and sequence coordinates.

!!! tip "Prerequisites"
    The solve/verify tutorials run a real OPF, so they need a Julia environment
    with `BMOPFTools`, `JuMP` and `Ipopt`. The data-model and conversion pages
    need only `BMOPFTools`. [Installation & first steps](installation.md)
    covers setting all of this up, starting from installing Julia itself.
