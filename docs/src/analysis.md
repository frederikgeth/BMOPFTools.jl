# Analysis & reports

For the physical rationale behind these checks, read
[How network diagnostics work](methodology.md).

[`analyze`](@ref) runs fifteen passes over a network dict and returns a
[`SummaryReport`](@ref) holding per-pass result dicts (`report.results`)
and the combined finding log (`report.findings`). For time-series networks
the snapshot at `t_index` is materialised first.

## The passes

| `results` key | function | computes |
|---|---|---|
| `:inventory` | [`inventory_analysis`](@ref) | component counts, totals (load P/Q, generation capacity), per-type breakdowns |
| `:voltage_levels` | [`voltage_level_analysis`](@ref) | BFS voltage propagation from sources through transformer ratios; level clustering; transformer transitions; level-crossing violations |
| `:connectivity` | [`connectivity_analysis`](@ref) | connected components, radial/meshed (physical branch count, parallel-aware), degree statistics, tree depth, dangling buses, galvanic-zone phase topology (split-phase / SWER tagging), voltage-tier and zone cycle-rank decomposition, parallel-line declarations, switch-state bus and mapped-conductor scenarios |
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

Note on transformer utilisation: the downstream-load estimate excludes the
transformer under analysis. If its from side remains reachable from its to
side, the figure is labeled `upper_bound` and does not raise
`W.OPS.XFMR_OVERLOADED`; parallel siblings and other alternate paths defeat
the radial attribution. Otherwise `estimate_status` is `radial_component`.

### Topology structure

`report.results[:connectivity]["structure"]` has `whole_network`,
`voltage_tiers`, `galvanic_zones`, and `parallel_lines`. Every graph count
includes declared buses, including isolated buses. Closed switches, lines,
and transformer winding branches are physical edges; open switches are absent.
Invalid or self-loop branches are excluded and counted in
`n_skipped_branches`. A zone is a connected component formed by lines, closed
switches, and galvanically continuous transformers; isolating transformers
connect zones.

For each graph, `cycle_rank = n_physical_edges - n_buses + n_components` and
`cycle_rank = simple_cycle_rank + parallel_excess`. The simple graph retains
one edge per bus pair. `transformer_mediated_cycle_rank` is the whole-network
cycle rank less the sum of within-zone cycle ranks. A tier contains only edges
whose endpoints have the same source-propagated voltage-level label;
`n_cross_tier_edges` counts the excluded branches. Unassigned buses form an
explicit `unassigned` tier.

Parallel-line groups compare endpoint-normalized terminal maps first, then
the remaining declared line model fields (`meta` is excluded). Classes are
`incomplete_terminal_map`, `terminal_map_disagreement`,
`same_declared_fields`, and `different_declared_fields`. The JSON result has
all tier and zone counts and up to five deterministic witnesses per class. Matching
fields do not establish duplicate physical assets; cycles and parallel lines
are descriptive evidence, not automatic data-quality Findings.

The structure result uses these stable groups:

| Key | Contents |
|---|---|
| `whole_network` | Bus/component/edge counts; physical and simple cycle ranks, parallel excess, and transformer-mediated cycle rank. |
| `voltage_tiers` | One count record per source-propagated voltage label, including `unassigned` where needed. |
| `galvanic_zones` | One record per zone with its minimum-bus `anchor`, voltage labels, cycle counts, and number of incident isolating transformers. |
| `parallel_lines` | Group count, classification counts, and up to five sorted bus-pair/member-ID witnesses per class. |
| `cycle_closing_branches` | Up to ten deterministic spanning-forest closing branches, with member IDs and endpoints; these are graph witnesses, not defect assignments. |
| `conductor_paths` | Terminal-level components through mapped lines and closed switches, with voltage-tier counts and bounded load-terminal witnesses. Transformer winding terminals and voltage-source terminals act as boundary ports; transformer conversion is not inferred. |
| `n_cross_tier_edges`, `n_skipped_branches` | Edges omitted from within-tier graphs and invalid/self-loop branches omitted from graph counts. |

### Switch-state bus graph scenarios

`report.results[:connectivity]["switch_scenarios"]` compares the supplied
switch-state snapshot with a fixed backbone (all switch edges removed) and an
all-closed envelope (all valid switch edges included). Every view retains all
declared buses, including isolated buses, and counts each physical parallel
branch separately. The three views report bus, component, physical and simple
edge, physical and simple cycle-rank, parallel-excess, source-containing
component, and bus/load-without-source-path counts. The all-closed envelope is
a graph bound; it may combine mutually exclusive switch positions.

`transition_counts.classifications` counts all individually assessed switches:
`component_join` for an open switch between declared components,
`cycle_closure` or `parallel_closure` for an open switch within one
component, `bridge` for a closed switch whose opening splits a component,
and `alternate_path` for a closed switch whose opening leaves the component
connected. Each transition's component and physical cycle-rank deltas are
reported in `witnesses`, with at most five witnesses per class, sorted by
switch ID. Counts cover every assessed switch. For ties to a component
without a source path and bridges that remove such a path, witnesses include
affected bus and load counts. The result also counts ties between
source-containing components.

The result is `inapplicable` when there are no switches. It is
`indeterminate` if any switch lacks a Boolean `open_switch`, has a missing
endpoint, references an undeclared bus, or is a self-loop; the invalid IDs
appear in `assessment.invalid_switch_ids`. Counterfactual counts are omitted
in that case. Incomplete terminal maps do not prevent a bus-graph assessment.
`assessment.skipped_branch_ids` lists invalid or self-loop declared branches
excluded from graph counts; `switch_counts.n_assessed` is zero when switch
state comparison is indeterminate.

`switch_scenarios["conductor"]` separately compares mapped terminal paths
for the declared, fixed-backbone, and all-closed views. Its counts include
mapped conductor edges, path components, components containing a declared
voltage-source or transformer winding port, and bus/load terminals without a
path to such a boundary. Each switch transition reports its change in path
components and the number of load terminals gaining or losing a boundary path.
This can expose a missing phase or neutral path even when the bus graph stays
connected. The `path_merge`, `path_split`, and `no_path_change` class
counts cover every assessed switch; JSON carries up to five sorted witnesses
per class. A multi-conductor switch changes all mapped terminal pairs
together. `cross_layer_counts` counts combinations such as
`cycle_closure|path_merge`, which show when the bus and mapped-conductor
graphs respond differently to the same switch. The implementation uses
bridge precomputation when pairs occupy
different path components and an exact group-removal calculation otherwise.
`assessment.n_group_cut_fallbacks` reports how many switches needed that
calculation.

The conductor layer is `inapplicable` if bus terminal names or any required
line/switch, load, or boundary-port map is incomplete; its assessment lists
the affected record IDs. It is `indeterminate` if no source or transformer
boundary port exists. These statuses do not discard an applicable bus-graph
result. Transformer ports mark path boundaries on each winding side; the
analysis does not infer electrical continuity or phase conversion through
the transformer.

Source-path counts use only declared voltage-source and load bus incidence.
A graph path does not prove energization, switch operability, protection
compatibility, phase or voltage compatibility, capacity, or synchronization.
The existing `W.CONN.MESHED` and `E.CONN.DISCONNECTED` Findings still
describe only the declared snapshot; switch scenarios introduce no Findings.

### Conditional geographic evidence

Spatial analysis runs automatically when bus coordinate fields are present.
It describes coordinate quality, shared infrastructure, geometry/topology
candidates and an evidence-bound cleanup queue. Coincidence alone is not an error.
See [Spatial diagnostics and cleanup review](spatial_diagnostics.md) for coordinate
semantics, suppression, candidate codes, illustrated examples and exports.

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

## Transformer phase evidence

[Transformer phase reporting](transformer_phase.md) separates authored winding
connections and nameplate declarations from the derived ideal effective relation.
Inventory and voltage transitions retain string labels and add structured status,
phase correspondence, orientation and coil evidence. A `?` suffix never means
clock zero. Use `transformer_phase_relation` for a directed winding pair or pass
`phase_order` to the standalone inventory/voltage passes for custom labels.

## Qualified nominal transformer coil headroom

`analyze(net).results[:preflight]["transformer_coil_headroom"]` exposes a
**nominal-demand estimate**, separate from the supplied-result
`profile_solution(net, result).results[:transformer_loading]` report.
The same block is carried by `execute_analysis`, JSON analysis reports and the
existing `analyze_case` recipe. Markdown includes the coil table and unassessed
reasons; terminal reports show the stable preflight Findings.

The initial domain is one `single_phase` transformer bank in a connected radial
network with exactly one upstream voltage source, explicit ordered branch maps,
and phase-neutral `SINGLE_PHASE` or `WYE` loads. A case may use its documented
`n`/`N` neutral naming convention or declared terminal roles; the report records
which was used. Endpoint labels are never matched as a substitute for an absent
map. Lines may be oriented either way and may explicitly permute phase labels.
Fixed open switches are omitted from the supply graph; isolated buses make this
initial whole-network screen inapplicable. Reverse-fed transformers, multiple
banks or supplies, meshes (including parallel paths), phase-to-phase/delta loads,
ZIP/exponential models, local generation, IBRs, separate shunts/capacitors,
DC devices, control profiles and authored tap bounds/decisions are unassessed.
This deliberately bounded first domain does not allocate the unsupported cases
by phase count or bank totals.

For each mapped downstream coil, sum signed `p_nom` and `q_nom` and calculate
`S_nom = hypot(sum(P_nom), sum(Q_nom))`. P must be nonnegative; signed Q permits
nominal reactive cancellation. Constant-power, constant-current and
constant-impedance loads are evaluated at their own nominal voltages; the latter
two require finite positive `v_nom`. This assumes nominal voltage everywhere,
without calculating voltage drops, neutral displacement or mutual coupling.
Line/transformer losses, charging and magnetizing demand are omitted. Upstream
loads are outside the transformer sum. Local sources and compensation are
excluded rather than credited against demand. Source, voltage and current
limits are unassessed. A fixed positive tap does not change this ideal nominal
power accounting; tap bounds or control declarations receive no estimate.

Only this native `single_phase` phase-neutral bank uses
`s_rating / mapped_coil_count` as the from-side nameplate cap. Missing, zero,
negative or nonfinite ratings give an indeterminate result, never a zero cap.
The estimator does not infer other subtypes' caps or touch solver constraints.
Each estimated row records from/to terminals, source terminal, nominal P/Q/S,
cap, utilization, headroom and individual load contributions with ordered
source paths. The bank summary sums coil apparent magnitudes. Missing or
ambiguous data yield no partial numeric allocation and a stable reason.

For the 100 kVA, three-coil / 40 kW single-coil witness, nominal bank utilization
is 40%, but coil 1 is 120% with headroom −6.667 kVA.
`W.PRE.XFMR_COIL_HEADROOM` flags negative nominal headroom;
`I.PRE.XFMR_COIL_UNASSESSED` explains unsupported or incomplete cases.
`W.OPS.XFMR_OVERLOADED` remains the existing aggregate nominal-load warning
above 90%; its threshold and meaning are unchanged.

Positive headroom **does not prove feasibility** and negative headroom **does
not prove infeasibility**. The result records both limitations, its assumptions
and `solver_run = false`. It neither retries a solve nor edits the network.
This is a nominal-demand screen. Assessing a solved network also requires
checking its equations, operating limits and recovered quantities.

### Geometry and topology review candidates

See the [spatial candidate catalogue](spatial_diagnostics.md#Geometry-and-topology-review-candidates).
Candidate codes are advisory categories, distinct from registered Findings.

### Cleanup review workflow

See the [cleanup review workflow](spatial_diagnostics.md#Cleanup-review-workflow)
for evidence categories, review decisions, coverage and Markdown/JSON/GeoJSON exports.

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
| negligible phase-block coupling (`I.PROV.DECOUPLED_PHASES`) | per-phase simplification | approximately Z₀ = Z₁ for that block; inspect the intended return path and additional conductors |
| three-wire, no PN pattern (`I.PROV.IMPEDANCE_TRANSFORM_KR`) | prior neutral elimination (weak hint) | a zero-neutral-voltage model cannot predict neutral rise when inappropriate; total dissipation can remain represented, while separate neutral attribution needs recovery data |
| uniform R, mutual ≈ ½ self (`…_PN`) | phase-to-neutral equivalent | exact under the single-grounded/no-earth-current assumptions; conductor equality explains the pattern rather than establish accuracy |
| uniform R and X (`…_MPN`) | modified phase-to-neutral equivalent | review PN earth-current assumptions and the additional reactance-symmetrisation approximation |

`observations.by_linecode` records `n_conductors`, `phase_block_only` and the
relative coupling to conductors outside the inspected block for balance and
decoupling hints. A four-wire matrix can have a balanced phase block while its
neutral remains explicit and introduces phase-to-neutral unbalance. The
implications list reflects retained conductors; a phase-block signature alone
does not make neutral quantities unavailable.

For the PN transformation, the exact reference domain has no conductor-to-earth shunts,
no device current injection into earth, and one grounding point per
continuous neutral section. Neutral current and voltage can be recovered using
source information in that domain. Multiple earth-return paths can invalidate
its assumptions; grounding impedance alone does not determine the error. The
R mutual/self ratio near one half is a fingerprint for similar phase/neutral
resistances, while the transformation itself also applies to unequal conductors.

The Kron hint is matrix-only, so its message says how the linecode is used: on
LV lines without a represented neutral (a stronger hint), only elsewhere
(three-wire is normal at MV/HV), or not at all. When a matrix also has the
equal-self/equal-mutual signature, the message points to `I.PROV.SEQ_DERIVED`:
sequence-built data cannot show whether a neutral was ever there.
`I.PROV.KRON_LIKELY` is the network-level counterpart: an LV level with no
neutral conductor on any branch.

Converter-generated source equivalents (linecodes whose `source` names a
Thevenin or source impedance, e.g. from `from_dss`) are classified but never
flagged; the report counts them. Scientific checks for
[reduction and positive-sequence applicability](scientific_contracts.md) keep
their own documented domains; these hints do not widen them. Compatibility
details are in [Provenance report compatibility](dev/versioning.md#Provenance-report-compatibility).

### Transformer winding caps

For two-winding subtypes the OPF turns `s_rating` into a per-coil cap. An
`n_winding` transformer is different: only per-winding `i_max` (coil current)
and `s_max` (coil apparent power, shared equally among phase legs) limit it.
`operational.winding_limit_coverage` lists each winding's caps with field paths,
and `W.OPS.XFMR_UNCONSTRAINED` flags windings with no finite supported cap.
A cap can be absent or explicitly `Inf`; observations count both states, so an
intentional unbounded declaration stays visible. Zero is a real restriction.
Direct neutral-current caps are not assessed, and this is declared data, not a
built or solved model. Other subtypes are reported as not applicable.

### Feeder length and supply boundaries

`operational.feeder_length` reports, per galvanic zone, how far (by declared
line length) the farthest bus is from the nearest *supply boundary*: a voltage
source, or a transformer port with a source beyond it. For a chain of four
100 m lines fed from both ends this is 200 m (`boundary_reach_m`), while the
legacy `reach_m` / `anchor_extent_m` measures 400 m from one end.
`I.OPS.FEEDER_LONG` and `I.OPS.FEEDER_SHORT` compare it with per-band
thresholds. Review genuine feeder size, unit conversions and the OpenDSS default
`length=1`: copying 1 km as 1 m makes a line 1000 times too short; interpreting
1000 m as 1000 km upstream makes it 1000 times too long.

`observations.impedance_basis_counts` separates per-length `length_scaled`
linecodes, inline `absolute_section` matrices and `unresolved` declarations.
Length errors scale linecode impedances, while inline matrices are absolute
section totals and stay unchanged when length changes. The guide uses that
context; for an all-inline zone it explains the distance error separately from
electrical parameters. Per-km versus per-m impedance units deserve their own
check even when declared lengths are correct.

Each transformer port records a `port_role`: `source_beyond_port` (a possible
supply into the zone), `no_source_beyond_port` (load side) or `unresolved`. Two
or more ports with a source beyond them mean parallel supply, which the report
lists for review. Supported boundaries are voltage sources and untapped two-port
`n_winding`, `single_phase`, `wye_delta` and `delta_wye` transformers whose
voltage bases agree (source magnitudes within 5%, cycle ratios within 10⁻⁹).
Anything else leaves the distance unassessed with a stated reason rather than a
guess. The metric is graph distance; it does not compute voltage drop, flow or
energization. Missing or invalid lengths leave it indeterminate; regularized
electrical lengths suppress the threshold comparison.

Zones with several supply boundaries need their own threshold policy, since a
short distance to one of many ports does not make the zone a service drop:

```toml
[operational.feeder_length.LV.multi_boundary]
reach_short_m = 0.0
reach_long_m = 1500.0
```

### Assessment coverage

`results.assessment` lists which tracked checks were assessed, skipped, not
applicable or indeterminate, with reasons. It is separate from severity and is
not a validation score. Reports show a one-line summary plus the checks you can
act on; legacy passes without a coverage ledger appear only in JSON.

### Repetition and parallel declarations

Parallel line records are grouped by bus pair and compared strictly, keeping
terminal order and endpoint orientation; matching records are inspection
candidates, not proven duplicate assets. Load repetition counts identical P/Q
declarations: group sizes 4, 3 and 1 give 8 loads, 3 distinct tuples, 5 excess
repetitions and 2 repeated groups with 7 members. Values are grouped before
conversion to Float64, so rounding cannot create false matches. Reports keep
radial nameplate estimates separate from ambiguous upper bounds, which never
trigger overload warnings.
