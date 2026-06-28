# Profiling pipeline: priorities

The profiling pipeline is the analysis side of BMOPFTools: [`analyze`](../analysis.md)
turns a network into a `SummaryReport` of [`Finding`](../findings.md)s, and
[`profile_solution`](../results.md) turns a solved case into a `SolutionReport`.
This page sets the priorities for contributions to that pipeline — what makes a
good new finding, and what is currently out of scope.

## Semantics and data quality come first

The value of this pipeline is **faithful semantics and high data quality**, not
the raw number of checks. Ingestion is a *semantic projection* onto the canonical
model (see the [conversion philosophy](../conversion.md)), and the analysis layer
exists to make a case's meaning, assumptions, and data-quality issues explicit —
the modeling-convention statement, the provenance checks, the benchmark-readiness
assessment.

So the bar for a contribution is: does it improve how faithfully the pipeline
*understands* a case, or how clearly it *surfaces* a real problem? A check that
adds noise, or that fires on a distinction without a difference, is a regression
even if it is technically correct.

## Prioritise high-impact, high-likelihood findings

New findings should be triaged on two axes:

- **Impact** — how much does this finding change a downstream user's decision? A
  finding that flags an unsolvable or physically wrong case is high-impact; a
  cosmetic note is low-impact.
- **Likelihood** — how often does the condition actually occur in real
  converted data?

Prioritise findings that are **high on both**. The
[Task Force feedback document](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/docs/taskforce_feedback.md)
is ordered roughly by impact for exactly this reason; new findings should aim for
the top of that ordering, not the long tail. Every new code still needs a row in
the [finding-code reference](../findings.md) with its trigger and rationale, and
must respect the stable-code contract in the [style guide](style_guide.md).

## Currently out of scope (but open to it)

Some modeling capabilities are **not in scope right now**. This is a deliberate
boundary, not a rejection — proposals are welcome, but they should go through the
Task Force and the migration path (see [Versioning](versioning.md)) rather than
being bolted on:

- **Explicit earth wires.** Modeling the earth/ground return as an explicit
  conductor is not currently supported.
- **n-wire polyphase.** Buses and lines beyond the up-to-four-wire model
  (arbitrary n-wire polyphase) are out of scope.
- **Harmonics.** The model is fundamental-frequency; harmonic representation and
  harmonic-related findings are out of scope.

!!! note "n-wire is not n-winding"
    Be precise: the out-of-scope item is n-*wire* polyphase **buses and lines**.
    n-*winding* **transformers** are a different thing and *are* supported (see
    the `nwinding` handling in `src/io/` and the OPF extension). Do not conflate
    the two when scoping a contribution.

If you have a concrete need for any of these out-of-scope capabilities, open a
discussion — the boundary can move, but it moves through the spec, with a
migration for existing cases.

## See also

- [Analysis & reports](../analysis.md) — what each pass computes.
- [Finding-code reference](../findings.md) — the complete catalogue.
- [Methodology notes](../methodology.md) — the physics and linear algebra behind
  the provenance checks.
