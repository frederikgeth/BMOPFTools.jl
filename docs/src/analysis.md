# Analysis & reports

For the physical rationale behind these checks, read
[How network diagnostics work](methodology.md).

[`analyze`](@ref) runs fifteen passes over a network dict and returns a
[`SummaryReport`](@ref) holding per-pass result dicts (`report.results`)
and the combined finding log (`report.findings`). For time-series networks
the snapshot at `t_index` is materialized first.

This page is the overview: what runs, what the report contains and how to read
a finding. The rest of the profiling material is organized by what you are
trying to do:

| You want to | Read |
|---|---|
| Learn the loop on a small case: run, read, decide, fix, recheck | [Profile your first messy case](tutorial_profile_messy_case.md) |
| See what the profiler says about your kind of network | [System types and regional practice](tutorial_system_types.md) |
| Understand a grounding or neutral finding | [Grounding and neutral findings explained](grounding_findings.md) |
| Change a threshold | [Tune profiler thresholds](howto_thresholds.md) |
| Accept a finding and keep a record | [Accept and track findings](howto_accept_findings.md) |
| Work through coordinates and line lengths | [Spatial cleanup tutorial](tutorial_spatial_cleanup.md) |
| Look up a result key | [Analysis result keys](analysis_results.md) |
| Look up a finding code | [Finding-code reference](findings.md) |

## The passes

| `results` key | function | computes |
|---|---|---|
| `:inventory` | [`inventory_analysis`](@ref) | component counts, totals (load P/Q, generation capacity), per-type breakdowns |
| `:voltage_levels` | [`voltage_level_analysis`](@ref) | BFS voltage propagation from sources through transformer ratios; level clustering; transformer transitions; level-crossing violations |
| `:connectivity` | [`connectivity_analysis`](@ref) | connected components, radial/meshed over phase-carrying branches (physical branch count, parallel-aware; neutral-only bond cycles counted separately), degree statistics, tree depth, dangling buses, galvanic-zone phase topology (split-phase / SWER tagging), voltage-tier and zone cycle-rank decomposition, parallel-line declarations, switch-state bus and mapped-conductor scenarios |
| `:diversity` | [`diversity_analysis`](@ref) | parameter spread per category (CV, duplicate tuples), phase imbalance, symmetry score |
| `:operational` | [`operational_analysis`](@ref) | total load/generation, transformer utilization at nominal load (downstream BFS), line thermal-limit coverage |
| `:load_models` | [`load_model_analysis`](@ref) | load model breakdown by type, voltage-dependent load count, exponential loads that are ZIP-equivalent (integer exponents), nonlinear loads on buses without a lower voltage bound |
| `:provenance` | [`provenance_analysis`](@ref) | impedance classification (balance tiers, passivity, sign structure), wires per level / Kron likelihood, neutral grounding structure, earthing-system tags, OpenDSS default fingerprints, regulator patterns, the **convention statement** |
| `:preflight` | [`infeasibility_preflight`](@ref) | generation adequacy, voltage-bound coverage, bound-pair conflicts (v/vpn/vpp/vpos, p, q), topological risk |
| `:schema` | [`schema_check`](@ref) | fields present but not in the data model (cataloged, not rejected) |
| `:completeness` | [`completeness_check`](@ref) | required fields per component type, incl. transformer subtypes; optional-field coverage |
| `:domain_rules` | [`domain_rules_check`](@ref) | numerical plausibility: bounds signs, power factors, costs, impedance diagonals, transformer step ratios, zero limits/lengths, angle units, load model coefficient validity |
| `:redundancy` | [`redundancy_check`](@ref) | zero loads/shunts, mergeable series lines (junction-aware), unused/duplicate linecodes |
| `:integrity` | [`integrity_check`](@ref) | referential integrity, dimension consistency, padded matrices, voltage reference per galvanic island, wye-without-neutral, low-impedance lines, generator cost symmetry |
| `:spec` | [`spec_conformance_check`](@ref) | TF-spec rules the JSON Schema cannot express: single source, configuration/arity, transformer map arities, terminal types, matrix storage |
| `:benchmark` | [`benchmark_readiness_check`](@ref) | objective well-posedness, slack-only detection, bound/limit coverage, **augmentation suggestions** |

Two further result blocks are produced inside these passes rather than by a
pass of their own:

- `results[:connectivity]["spatial"]` — the geospatial analysis, run by the
  connectivity pass when buses carry coordinate fields
  ([Spatial diagnostics](spatial_diagnostics.md));
- `results[:assessment]` — which tracked checks were assessed, skipped, not
  applicable or indeterminate ([Assessment coverage](analysis_results.md#Assessment-coverage)).

After the passes, `analyze` consolidates the finding log
(`results[:consolidation]`, [below](#Report-consolidation)).

Note on transformer utilization: the downstream-load estimate excludes the
transformer under analysis. If its from side remains reachable from its to
side, the figure is labeled `upper_bound` and does not raise
`W.OPS.XFMR_OVERLOADED`; parallel siblings and other alternate paths defeat
the radial attribution. Otherwise `estimate_status` is `radial_component`.


## The report

[`render`](@ref) writes nine sections (terminal with ANSI color, or
Markdown via a `.md` path / [`BMOPFTools.render_markdown`](@ref)):

1. **Component inventory**
2. **Voltage levels** — level table + transformer transitions
3. **Connectivity & topology**
4. **Diversity & variance**
5. **Loading & operational summary**
6. **Infeasibility pre-flight**
7. **Provenance & model conventions** — the convention statement, wires per
   level, neutral grounding, linecode classification, OpenDSS default
   fingerprints, **earthing system per galvanic zone**
8. **Spec conformance & benchmark readiness** — incl. structural integrity
   and augmentation suggestions
9. **Data quality summary** — every finding, grouped by severity

The header repeats the convention statement, e.g.

```
Convention   MV_6.4kV: 4-wire; LV_250V: 4-wire; 4 grounding point(s)
```

so a case's modeling assumptions are visible before any numbers.


## Findings

Each [`Finding`](@ref) carries severity, a stable code, the producing
section, component type/id, a human message and an optional machine-readable
`detail` dict. Severity semantics:

- `ERROR` — will compromise OPF correctness or prevent execution;
- `WARNING` — degrades result quality or indicates suspicious data;
- `INFO` — provenance/context worth knowing; not necessarily actionable.

Filter with [`errors`](@ref) / [`warnings`](@ref) / [`infos`](@ref), and
match on `f.code` — message text is not stable. The complete catalog with
triggers and rationale is in the [finding-code reference](findings.md).


## Report consolidation

Each pass emits one Finding per affected component, and two passes can describe
the same root cause from their own angle. On a feeder with a thousand sub-meter
line segments that is a thousand findings for one fact. `analyze` therefore
finishes with a consolidation step so that the report is proportional to the
number of distinct problems:

- **Roll-up.** An `I.` or `W.` code raised on more than
  `config["report"]["rollup_threshold"]` components (default 25) becomes one
  Finding with the same code and severity. Its `detail["components"]` lists the
  component ids and `detail["count"]` their number.
- **Subsumption.** A Finding is dropped when a stronger one states the same
  fact about the same component: `I.PROV.LINE_SWITCH_LIKE` on a line that also
  raises `W.DOM.LINE_LOW_IMPEDANCE`, and `W.OPS.LINE_UNCONSTRAINED` when
  `W.PROV.I_MAX_ABSENT` names the same lines.

`E.` Findings are never rolled up or dropped. Nothing is lost:
`results[:consolidation]` records every roll-up and subsumption, and
[`expand_findings`](@ref) returns one Finding per component again.

```julia
report = analyze(net)
length(report.findings)                    # consolidated
per_component = expand_findings(report)    # one Finding per affected component
filter(is_rolled_up, report.findings)      # the roll-ups

cfg = load_config(); cfg["report"]["rollup_threshold"] = 0   # disable roll-up
analyze(net; config=cfg)
```

The individual passes (`domain_rules_check`, `provenance_analysis`, …) are not
consolidated when you call them directly.

## Evidence qualified profiler results

Many INFO and WARNING Findings flag data that *might* mislead a study. They are
hints, not verdicts: each one tells you what the data most likely means, why that
would matter, what else could explain it and what to check. Read them as a
colleague's margin notes on a case you are building or modifying, whether you
work alone or with an AI assistant.

### Reading a hint

Hints that carry review guidance store it in `detail["interpretation"]`. The
markdown report shows it under each Finding ("How to read this"); the terminal
report adds the main alternative and the first check; JSON and
`explain_finding(finding)` return all of it:

- `observations`: what was measured, e.g. matrix statistics compared with
  the reference patterns (`pattern_comparison`).
- `possible_explanations`: the usual reading first.
- `implications`: what goes wrong in a study if that reading is true.
- `alternatives`: other plausible readings of the same data.
- `suggested_checks`: the cheapest useful check first.
- `supporting_context`: case facts that strengthen or weaken the hint, e.g.
  which lines actually use a linecode and at what voltage.
- `learn_more`: documentation pages (`page`, `section`, `url`) that explain the
  underlying physics or modeling choice.
- `automation_guidance`: always `review`, with additional evidence required
  before changing the model. An AI assistant should investigate, not edit.

Each guidance list is ordered and holds `{"id", "text"}` records: match the
stable `id` in code, show the `text` to people.

```julia
report = analyze(net)
hint = first(filter(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", report.findings))
guide = explain_finding(hint)["interpretation"]
[h["text"] for h in guide["implications"]]
guide["observations"]["by_linecode"]          # includes pattern_comparison
```

### Impedance provenance hints

Linecode matrices provide clues to construction choices. Their engineering
implications depend on which conductors and couplings the model retains:

| Pattern | Possible origin | Engineering implications |
|---|---|---|
| equal self, equal mutual (`I.PROV.SEQ_DERIVED`) | sequence values or a symmetry/transposition assumption | phase-pair asymmetry is absent from the inspected block; retained neutral coupling and other equipment can still create unbalance |
| negligible phase-block coupling (`I.PROV.DECOUPLED_PHASES`) | per-phase simplification | uniform self terms give approximately Z₀ = Z₁; unequal self terms can still couple sequence networks. Diagonal structure does not exclude prior reduction |
| three-wire, no PN pattern (`I.PROV.IMPEDANCE_TRANSFORM_KR`) | prior neutral elimination (weak hint) | a zero-neutral-voltage model cannot predict neutral rise when inappropriate; total dissipation can remain represented, while separate neutral attribution needs recovery data |
| uniform R, mutual ≈ ½ self (`…_PN`) | phase-to-neutral equivalent | exact under the single-grounded/no-earth-current assumptions; similar conductor resistances explain the pattern, while accuracy depends on earth-current assumptions |
| uniform R and X (`…_MPN`) | modified phase-to-neutral equivalent | review PN earth-current assumptions and the additional reactance-symmetrization approximation |

`observations.by_linecode` records `n_conductors`, `phase_block_only` and the
relative coupling to conductors outside the inspected block. An extra conductor
can coexist with a sequence-built phase block: OpenDSS can materialize a coupled
four-conductor matrix from sequence values, or a modeller can supply neutral
parameters separately. Shape alone does not select transposition over sequence
parameterization. A balanced phase block can still have an explicit neutral
that introduces phase-to-neutral unbalance.
An extra conductor with negligible coupling to the phases is flagged as a
possible placeholder or simplified neutral, with its coupling evidence retained.

The per-phase simplification hint also covers unequal diagonal terms, with
`phase_self_uniform` distinguishing the two cases. Unequal diagonal phase
impedances may couple the sequence networks. A Schur reduction subtracts its
correction from the original mutuals and can cancel them. Diagonal data therefore
retain an unresolved origin, with possible prior reduction listed as an
alternative; the hint does not declare Kron history impossible.

For the PN transformation, the exact reference domain has no conductor-to-earth shunts,
no device current injection into earth, and one grounding point per
continuous neutral section. Neutral current and voltage can be recovered using
source information in that domain. Multiple earth-return paths can invalidate
its assumptions; grounding impedance alone does not determine the error. The
R mutual/self ratio near one half is a fingerprint for similar phase/neutral
resistances, while the transformation itself also applies to unequal conductors.

The Kron hint is matrix-only, so its context distinguishes known LV use without
a represented neutral, known MV/HV-only use, unused templates, and unassessed or
mixed use. Missing nominal-voltage or terminal-map evidence does not establish
MV/HV use. Context counts retain `n_mv_hv_lines`, `n_lv_with_neutral_lines` and
`n_unassessed_lines`, with bounded line-ID examples; their sum is the legacy
`n_other_or_unassessed_lines`. Only positively identified MV/HV-only uses receive
`known_mv_hv_context`; unused templates receive `unused_linecode_context`.
Unassessed uses keep conditional neutral implications and an
`unassessed_use_context` disclosure. Exactly balanced candidates cross-reference
`I.PROV.SEQ_DERIVED`. `I.PROV.KRON_LIKELY` remains the network-level counterpart
for an LV level without a neutral carried by any branch.

Converter-generated source equivalents (linecodes whose `source` names a
Thevenin or source impedance, e.g. from `from_dss`) are classified but never
flagged; the report counts them. Scientific checks for
[reduction and positive-sequence applicability](scientific_contracts.md) keep
their own documented domains; these hints do not widen them. Compatibility
details are in [Provenance report compatibility](dev/versioning.md#Provenance-report-compatibility).
