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

`results[:connectivity]["spatial"]` appears only when at least one bus has
`longitude`, `latitude`, `x`, or `y`. It reports coordinate and route coverage,
line-length distributions by voltage tier, and bounded long-line witnesses.
The long-line ranking compares each section with its own tier's 99th-percentile
declared length; a high rank is an inspection cue, not an error threshold.
Metre-based line chord, route endpoint, and transformer separation measurements
are computed only when network metadata declares WGS84 (`crs`,
`coordinate_system`, or `coordinate_reference_system`) or a matching
`WGS84_geodesic_polyline` route provides coordinate-frame evidence. The latter
is explicitly labeled as route evidence, not a network-wide CRS declaration.
Out-of-range and incomplete coordinate pairs are counted but excluded from
geodesic calculations.

The coordinate loader copies OpenDSS `x,y` into fields named
`longitude,latitude` without transforming or verifying them. Plausible numeric
values therefore do not establish a geographic CRS. When the frame remains
unspecified or is declared as another CRS, spatial distances are marked
inapplicable; line-length statistics remain available. The result makes no
automatic asset-error claim when the CRS is unspecified. With a network-level
WGS84 declaration, out-of-range bus coordinates and sufficiently large line
chord or route-endpoint contradictions raise `W.GEO.*` Findings. A line's
equivalent electrical length can differ from its physical route, so these
warnings call for source-data review rather than automatic repair.
Route `length_m` and declared line `length` may come from the same upstream
geometry calculation, so their agreement is an internal-consistency check,
not independent confirmation of the physical route.

The spatial result groups fields as follows:

| Key | Contents |
|---|---|
| `coordinate_reference` | `status`, declared CRS if any, caution text, matching WGS84 route count, and whether geodesic distances apply. Status is `declared_wgs84`, `wgs84_route_evidence`, `declared_other`, or `unspecified`. |
| `coordinate_coverage` | Counts of complete longitude/latitude pairs, x/y fields, partial and invalid pairs, and pairs outside WGS84 numeric ranges. |
| `routes` | Route and basis coverage, numbers of endpoint and length comparisons, mismatch counts, and bounded endpoint-gap witnesses. |
| `lines` | Length quantiles by voltage tier, chord comparison count, shorter-than-chord count, and bounded absolute and tier-relative length witnesses. |
| `transformers` | Bus separation quantiles and bounded farthest-pair witnesses. |

Endpoint gaps are counted with a 5 m descriptive threshold; the route-endpoint
Finding threshold is `max(20 m, 10% of endpoint chord)`. Route/declaration length
differences use `max(5 m, 10% of declared length)`; the line/chord lower-bound
check uses `max(5 m, 10% of chord)`. A mismatch count is JSON `null` when no
eligible comparison was made, rather than zero. Geographic Findings require
an explicit WGS84 declaration; matching route evidence alone supports
measurements but does not assert the CRS of every bus.

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
