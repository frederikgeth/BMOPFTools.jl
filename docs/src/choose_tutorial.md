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
| **Turn transformer test data into model fields** | [From test report to transformer model](tutorial_transformer_tests.md) | [Transformer models](transformer_models.md), [Transformer spec](spec/transformer.md) |
| **Understand four-wire physics** (why terminals, neutrals, matrices) | [Buses & terminals primer](terminals_primer.md) | [Impedance models & OPF decisions](tutorial_impedance_models.md), [Line geometry](tutorial_line_geometry.md) |
| **Get grounding, neutrals, and sequence coordinates right** | [Ground, neutral, and earth return](tutorial_grounding.md) | [Grounding spec](spec/grounding.md), [SWER case study](tutorial_swer.md) |
| **Get units, per-unit bases, and cost right** | [Units, bases, scaling, and economics](tutorial_units.md) | [Units and scaling](opf.md#Units-and-scaling), [Objective spec](spec/objective.md) |
| **Pick a defensible load model** (CVR, hosting, collapse) | [Choosing and identifying a load model](tutorial_load_models.md) | [Load spec](spec/load.md), [Impedance models & OPF decisions](tutorial_impedance_models.md) |
| **Build a benchmark** an optimiser can respect | [Case augmentation](augmentation.md) | [From nameplate data to a defensible model](tutorial_nameplate.md), [DER placement](tutorial_ders.md) |
| **Diagnose an infeasible case** | [Infeasibility diagnosis](tutorial_infeasibility.md) | [Bounds & feasibility](bounds/index.md), [Trusting the solver](bounds/solver_trust.md) |
| **Verify a solved OPF** you don't yet trust | [Trust but verify](tutorial_trust_but_verify.md) | [Trusting the solver](bounds/solver_trust.md), [Validating the OPF](validation.md) |
| **Model a specific device** (STATCOM, MVDC, regulator, PV droop) | [D-STATCOM study](tutorial_statcom.md) | [MVDC](tutorial_mvdc.md), [Tap optimisation](tutorial_tap.md), [VVWO](tutorial_vvwo.md) |
| **Extend or debug the solver** | [OPF engine: scope & status](dev/opf_engine.md) | [OPF model](opf.md), [Contributing](dev/contributing.md) |

## The judgment spine

Four of the tutorials, read in order, teach the reasoning a defensible study
needs — not just *how* to call the tools, but *when to trust the answer*:

1. **Assumptions** — [From nameplate data to a defensible model](tutorial_nameplate.md).
   Incomplete datasheets in; a model out. What can be *derived*, what needs an
   *assumption*, and what must stay *unknown* — and the difference between
   standards-derived, standards-inspired, and synthetic values.
2. **Solve** — [end-to-end tutorial](tutorial_end_to_end.md) and the
   [OPF model](opf.md). Turn the model into a solved dispatch.
3. **Verify** — [Trust but verify](tutorial_trust_but_verify.md). Take one solved
   OPF and independently recompute KCL, voltage bounds, thermal loading, losses,
   and the objective — learning what a solver's `LOCALLY_SOLVED` status does and
   does *not* guarantee.
4. **Consequences** — [Impedance models & OPF decisions](tutorial_impedance_models.md)
   and [Trusting the solver](bounds/solver_trust.md). How the modelling choices
   made in step 1 change the answer, and where the remaining traps live.

Read top to bottom you get the missing arc: **model assumptions → solve →
independent verification → fidelity consequences.**

!!! tip "Prerequisites"
    The solve/verify tutorials run a real OPF, so they need a Julia environment
    with `BMOPFTools`, `JuMP` and `Ipopt`. The data-model and conversion pages
    need only `BMOPFTools`. [Installation & first steps](installation.md)
    covers setting all of this up, starting from installing Julia itself.
