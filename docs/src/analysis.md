# Analysis & reports

[`analyze`](@ref) runs fifteen passes over a network dict and returns a
[`SummaryReport`](@ref) holding per-pass result dicts (`report.results`)
and the combined finding log (`report.findings`). For time-series networks
the snapshot at `t_index` is materialised first.

## The passes

| `results` key | function | computes |
|---|---|---|
| `:inventory` | [`inventory_analysis`](@ref) | component counts, totals (load P/Q, generation capacity), per-type breakdowns |
| `:voltage_levels` | [`voltage_level_analysis`](@ref) | BFS voltage propagation from sources through transformer ratios; level clustering; transformer transitions; level-crossing violations |
| `:connectivity` | [`connectivity_analysis`](@ref) | connected components, radial/meshed (physical branch count, parallel-aware), degree statistics, tree depth, dangling buses, galvanic-zone phase topology (split-phase / SWER tagging) |
| `:diversity` | [`diversity_analysis`](@ref) | parameter spread per category (CV, duplicate tuples), phase imbalance, symmetry score |
| `:operational` | [`operational_analysis`](@ref) | total load/generation, transformer utilisation at nominal load (downstream BFS), line thermal-limit coverage |
| `:load_models` | [`load_model_analysis`](@ref) | load model breakdown by type, voltage-dependent load count, exponential loads that are ZIP-equivalent (integer exponents), nonlinear loads on buses without a lower voltage bound |
| `:provenance` | [`provenance_analysis`](@ref) | impedance classification (balance tiers, passivity, sign structure), wires per level / Kron likelihood, neutral grounding structure, earthing-system tags, OpenDSS default fingerprints, regulator patterns, the **convention statement** |
| `:preflight` | [`infeasibility_preflight`](@ref) | generation adequacy, voltage-bound coverage, bound-pair conflicts (v/vpn/vpp/vpos, p, q), topological risk |
| `:schema` | [`schema_check`](@ref) | fields present but not in the data model (catalogued, not rejected) |
| `:completeness` | [`completeness_check`](@ref) | required fields per component type, incl. transformer subtypes; optional-field coverage |
| `:domain_rules` | [`domain_rules_check`](@ref) | numerical plausibility: bounds signs, power factors, costs, impedance diagonals, transformer step ratios, zero limits/lengths, angle units, load model coefficient validity |
| `:redundancy` | [`redundancy_check`](@ref) | zero loads/shunts, mergeable series lines (junction-aware), unused/duplicate linecodes |
| `:integrity` | [`integrity_check`](@ref) | referential integrity, dimension consistency, padded matrices, voltage reference per galvanic island, wye-without-neutral, low-impedance lines, generator cost symmetry |
| `:spec` | [`spec_conformance_check`](@ref) | TF-spec rules the JSON Schema cannot express: single source, configuration/arity, transformer map arities, terminal types, matrix storage |
| `:benchmark` | [`benchmark_readiness_check`](@ref) | objective well-posedness, slack-only detection, bound/limit coverage, **augmentation suggestions** |

Note on transformer utilisation: the downstream-load estimate excludes only
the transformer under analysis; per-phase-banked units (parallel siblings on
the same bus pair) defeat the radial assumption and the figure becomes an
upper bound.

## The report

[`render`](@ref) writes nine sections (terminal with ANSI colour, or
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
match on `f.code` — message text is not stable. The complete catalogue with
triggers and rationale is in the [finding-code reference](findings.md).
