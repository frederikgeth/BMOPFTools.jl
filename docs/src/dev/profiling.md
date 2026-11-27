# Profiling pipeline: structure and priorities

The profiling pipeline is the analysis side of BMOPFTools: [`analyze`](../analysis.md)
turns a network into a `SummaryReport` of [`Finding`](../findings.md)s, and
`profile_solution` ([result reference](../results.md)) turns a solved case into a `SolutionReport`.
This page sets the priorities for contributions to that pipeline — what makes a
good new finding, and what is currently out of scope.

## What runs, in order

[`analyze`](../analysis.md) calls the passes below in this order, each
appending to one finding log and returning one result dict. A new check
belongs in the pass that owns its subject; a new pass is rarely the right
answer.

| Order | `results` key | Source | Hosts |
|---|---|---|---|
| 1 | `:inventory` | `analysis/inventory.jl` | component counts, transformer phase labels |
| 2 | `:voltage_levels` | `analysis/voltage_levels.jl` | level propagation, ratio consistency; high-leg units come from `analysis/transformer_banks.jl` |
| 3 | `:connectivity` | `analysis/connectivity.jl` | graph, banks (`analysis/transformer_banks.jl`), DC links, zone classification, supply-phase consistency, switch scenarios, and the whole **spatial** pass (`analysis/spatial*.jl`) |
| 4 | `:diversity` | `analysis/diversity.jl` | load and line parameter spread |
| 5 | `:operational` | `analysis/operational.jl` | loading, limit coverage, feeder reach (`analysis/feeder_reach.jl`) |
| 6 | `:load_models` | `analysis/load_models.jl` | load-law inventory |
| 7 | `:provenance` | `analysis/provenance/*.jl` | linecodes, wires, grounding, earthing zones, tool-default fingerprints |
| 8 | `:preflight` | `infeasibility/preflight.jl` | adequacy, bound conflicts, coil headroom |
| 9–15 | `:schema` … `:benchmark` | `validation/*.jl` | schema, completeness, domain rules, redundancy, integrity (voltage-reference evidence in `validation/voltage_reference.jl`), spec conformance, benchmark readiness |
| — | `:assessment` | `report/assessment_coverage.jl` | which tracked checks were assessed |
| last | `:consolidation` | `report/finding_consolidation.jl` | roll-up and subsumption of the finding log |

Rules that follow from this structure:

- **A pass emits one Finding per affected component.** Do not aggregate inside
  a check to reduce noise; the consolidation step does that for every code, and
  `expand_findings` restores the per-component records.
- **One root cause, one Finding.** If a new check restates what another already
  says about the same component, add the pair to `_SUBSUMED_BY` rather than
  emitting both.
- **Thresholds come from the `config` argument.** Read them from the call's
  configuration with a packaged fallback; a module-level constant cannot be
  overridden per study.
- **Resolve the neutral through the case's terminal roles**
  (`_case_neutral_labels`), not through the name `n`.
- **Name the domain.** A check that applies only to some system types returns
  an explicit inapplicable or indeterminate result outside them; it does not
  guess. New system types get a fixture in `test/data/profiler_systems` and a
  row in [System types and regional practice](../tutorial_system_types.md).
- **Keep the report quiet on a clean case.** The regional fixtures must stay
  free of errors and warnings; `test/profiler_regional_tests.jl` enforces
  it.

- **Do not re-derive what the solver stamps.** A check that depends on how a
  device is modeled reads the same rules the builder does. For inverters that
  is `src/validation/ibr_rules.jl`; `test/ibr_rules_tests.jl` holds the
  profiler's conclusions against an independent LP. A single solve that
  returns zero current shows zero is feasible, not that it is forced.
- **Follow conductors, not labels or bus names.** `_conductor_groups`
  (`analysis/transformer_banks.jl`) is the one place a conductor is followed
  from bus to bus, and `_DisjointSets` (`analysis/disjoint_sets.jl`) the one
  union-find. A verdict must survive
  renaming a bus, reversing a switch and relabeling a terminal; the bank tests
  in `test/profiler_transformer_banks_tests.jl` apply those rewrites to every case.

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

## [Prioritize high-impact, high-likelihood findings](@id Prioritise-high-impact,-high-likelihood-findings)

New findings should be triaged on two axes:

- **Impact** — how much does this finding change a downstream user's decision? A
  finding that flags an unsolvable or physically wrong case is high-impact; a
  cosmetic note is low-impact.
- **Likelihood** — how often does the condition actually occur in real
  converted data?

Prioritize findings that are **high on both**. The
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
- [Finding-code reference](../findings.md) — the complete catalog.
- [Methodology notes](../methodology.md) — the physics and linear algebra behind
  the provenance checks.
