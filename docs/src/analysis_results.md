# Analysis result keys

Reference for the structured results in `analyze(net).results`. For what the
passes are and how to read the report, start with
[Analysis & reports](analysis.md); for the meaning of a finding code, use the
[finding-code reference](findings.md). This page documents selected keys, not
every key a pass emits; keys not documented here may change in any release.
See [Versioning](dev/versioning.md) for the package's compatibility policy.

Keys are written `results[:pass]["key"]`, where `results = analyze(net).results`;
a nested key continues the chain, as in
`results[:connectivity]["structure"]["whole_network"]`. Each section opens with
a table of the pass's top-level keys. "Conditional" marks a key that is present
only when the stated condition holds.

## Inventory

`results[:inventory]` counts components and totals declared quantities.

| Key | Type | Meaning |
|---|---|---|
| `bus` | Dict | `total` and `by_n_phases` (phase terminals per bus, neutral excluded) |
| `line` | Dict | `total` and `with_linecode` |
| `load` | Dict | `total`, `total_p_w`, `total_q_var` (sums of `p_nom`/`q_nom`) and `by_configuration` |
| `generator` | Dict | `total` and `total_p_cap_w` (sum of `p_max`) |
| `ibr` | Dict | `total`, `by_topology`, `by_prime_mover` and `total_s_max_va` |
| `capacitor` | Dict | `total` and `q_rated_total` |
| `transformer` | Dict | `total`, `by_type` (per subtype), `by_vector_group` and `phase_relations` (per subtype and id; see [Transformer phase evidence](#Transformer-phase-evidence)) |
| `linecode`, `voltage_source`, `shunt`, `switch`, `control_profile` | Dict | `total` |
| `dc_network` | Dict | Conditional on DC buses or branches: counts of `dc_bus`, `dc_branch`, `dc_grounding`, `dc_load`, `dc_source`, `converters` and `converter_stations` (DC buses shared by two or more converters) |

## Voltage levels

`results[:voltage_levels]` propagates nominal voltages from the sources through
transformer ratios and clusters buses into levels.

| Key | Type | Meaning |
|---|---|---|
| `bus_voltage_map` | Dict | Bus id → per-conductor (phase-to-reference) nominal voltage in V |
| `levels` | Dict | Level label (e.g. `LV_231V`) → `nominal_v`, `nominal_kv`, and the `buses`, `lines`, `loads` and `generators` at that level with their counts |
| `n_levels` | Int | Number of levels |
| `voltage_basis`, `voltage_basis_note` | String | Always `phase_to_reference`; the note states that balanced line-to-line values are √3 times these |
| `unassigned_buses` | Vector | Buses no voltage source reaches |
| `neutral_only_buses` | Vector | Buses that carry only a neutral or earth conductor |
| `transformer_transitions` | Vector | One record per transformer (per winding pair for `n_winding`): `id`, `subtype`, `vector_group`, `phase_relation`, `bus_from`, `bus_to`, `v_from`, `v_to`, `level_from`, `level_to` |
| `high_leg_banks` | Vector | One record per power unit paired with a center-tapped lighting unit ([below](#High-leg-delta-banks)) |
| `high_leg_units` | Vector | Power-unit ids from `high_leg_banks` of every status except `undetermined` |
| `mixed_phase_to_neutral_buses` | Vector | Secondary buses of `verified` high-leg banks |

The map holds one per-conductor value per bus. Three cases need care:

- A phase-to-phase single-phase winding carries a line-to-line `v_nom`; the map
  holds the corresponding per-conductor value.
- An `n_winding` DELTA winding's `v_nom` is its line-to-line coil voltage; the map
  again holds the per-conductor value of the bus it lands on.
- On a high-leg (four-wire) delta bus no single value describes every conductor.
  The map holds the center-tapped leg voltage and the bus is listed in
  `mixed_phase_to_neutral_buses`.

### High-leg delta banks

Each entry of `results[:voltage_levels]["high_leg_banks"]`:

| Field | Meaning |
|---|---|
| `power_unit` | Id of the `single_phase` unit that creates the high leg |
| `lighting_unit` | Id of the `center_tap` unit whose legs it joins |
| `bus_from`, `bus_to` | Primary and secondary bus of the power unit |
| `high_leg` | Secondary conductor of the power unit that is not on a lighting leg |
| `status` | Verdict, below |
| `secondary_amplitude_ratio` | Power-unit secondary voltage over the bank's line-to-line voltage (twice the leg voltage); `0` when the power winding has no voltage across it; `nothing` when the phasors are not established or the bank is undetermined |
| `secondary_amplitude_range` | `[low, high]` of that ratio over all tap positions when a unit has a free tap (`tap_min < tap_max`); `nothing` otherwise |

| `status` | Meaning |
|---|---|
| `verified` | The primaries close the delta and the power unit's secondary is the bank's line-to-line amplitude within 10 % at every tap position. The high leg sits at √3 times the leg voltage to neutral. |
| `amplitude_mismatch` | The primaries' directions close the delta, but the amplitude is off by more than 10 % at every tap position (a wrong rating, or a weak source phase), or the power winding's two primary terminals trace to one source conductor (ratio 0). Not a high leg; reported as `W.VOLT.XFMR_RATIO`. |
| `unverified` | The primary phasors are not established (no source declares the angle of a winding's conductors, as behind another transformer), or free tap positions disagree. Not a high leg; the unit is kept out of level propagation; no Finding. |
| `undetermined` | The power unit's primary is tied to the lighting unit's on some but not all conductors. Not a high leg; kept out of level propagation; the pair is listed in `results[:connectivity]["undetermined_transformer_banks"]`. |

Entries of `results[:connectivity]["undetermined_transformer_banks"]` carry
`bus_to`, `units`, `primary_buses` and a `reason`:

| `reason` | Meaning |
|---|---|
| `partial_primary_tie` | A tie carries some but not all of the conductors a winding's primary uses; the units stay separate branches |
| `no_common_supply_point` | Each unit shares a supply bus with the next, but no single bus holds them all |

Two units are one bank when their supply points share a bus: a winding's supply
point is the set of buses, reached by following conductors terminal by terminal
through closed switches, at which every primary terminal, the neutral included,
is present (`supply_buses` in `transformer_bank_groups`). A full primary
disconnect between the units does not split the bank; a tie on a conductor
neither winding uses, or a neutral bond alone, is no evidence. Verification
traces each primary terminal's conductor through the terminal maps of lines and
closed switches to the magnitude and angle a voltage source declares for it,
then takes each secondary voltage as that phasor times the unit's effective
turns ratio, nameplate ratio and `tap`, as the solver builds it. A conductor no
source declares is at zero only when one of its terminals is a perfectly
grounded return terminal or sits on a source bus; a shunt to earth is a path,
not a voltage. Phase labels are never evidence of an angle, and nothing depends
on bus names or switch direction. In-phase primaries, primaries on the same
phase, a line-to-line beside a line-to-neutral primary, or one reversed winding
do not form a bank and are reported as ordinary level conflicts. A power unit's
own ratio is still checked against twice the leg level.

### Transformer phase evidence

[Transformer phase reporting](transformer_phase.md) separates authored winding
connections and nameplate declarations from the derived ideal effective relation.
Inventory and voltage transitions retain string labels and add structured status,
phase correspondence, orientation and coil evidence. A `?` suffix never means
clock zero. Use `transformer_phase_relation` for a directed winding pair or pass
`phase_order` to the standalone inventory/voltage passes for custom labels.

## Connectivity

`results[:connectivity]` describes the bus graph and the galvanic zones.

| Key | Type | Meaning |
|---|---|---|
| `n_components`, `is_connected` | Int, Bool | Connected components of the closed-branch bus graph |
| `components` | Vector | Conditional on more than one component: the bus list of each (`E.CONN.DISCONNECTED`) |
| `is_radial` | Bool | No cycle among phase-carrying branches (physical branch count, so parallel branches count) |
| `n_extra_edges` | Int | Phase-carrying branches beyond a spanning forest (0 when radial) |
| `n_neutral_only_branches`, `neutral_only_cycle_rank` | Int | Neutral-only branches, and the cycles they alone close |
| `degree_min`, `degree_max`, `degree_mean`, `degree_median` | Number | Bus degree statistics |
| `degree_1_buses`, `degree_2_buses`, `n_degree_1`, `n_degree_2` | Vector, Int | End buses and pass-through buses |
| `dangling_buses` | Vector | Degree-1 buses with no load, generator, shunt, capacitor, IBR, source or transformer-bank leg (`W.CONN.DANGLING`) |
| `open_switch_isolated_buses` | Vector | Open-switch endpoints with no closed path to a source |
| `source_buses` | Vector | Conditional on a voltage source: buses that hold one |
| `tree_depth_max`, `longest_path_buses`, `longest_path_vertices` | Int, Vector | Conditional on a voltage source: hop depth from the sources, and the longest walk ([DC links](#Transformer-banks-and-DC-links)) |
| `zones`, `n_split_phase_zones`, `n_swer_zones` | Vector, Int | Galvanic-zone phase topology ([Zone topology](#Zone-topology)) |
| `supply_phase_consistency` | Dict | `n` and `ids` (zone anchors) of zones flagged `W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY` or `W.PROV.PHASE_ARRANGEMENT_MISMATCH` |
| `transformer_banks`, `transformer_bank_groups`, `undetermined_transformer_banks` | Vector | Single-phase transformer banks ([below](#Transformer-banks-and-DC-links)) |
| `dc_links`, `dc_link_islands` | Vector | AC buses coupled through one DC island |
| `structure` | Dict | Cycle-rank decomposition and parallel-line evidence ([Topology structure](#Topology-structure)) |
| `switch_scenarios` | Dict | Declared, fixed-backbone and all-closed switch views ([below](#Switch-state-bus-graph-scenarios)) |
| `spatial` | Dict | Conditional on bus coordinates: the geospatial analysis ([Geographic evidence](#Geographic-evidence)) |

### Topology structure

`results[:connectivity]["structure"]` groups graph counts. Every graph count
includes declared buses, including isolated buses. Closed switches, lines,
and transformer winding branches are physical edges; open switches are absent.
Invalid or self-loop branches are excluded and counted in
`n_skipped_branches`. A zone is a connected component formed by lines, closed
switches, and galvanically continuous transformers; isolating transformers
connect zones.

| Key | Contents |
|---|---|
| `whole_network` | Bus/component/edge counts; physical and simple cycle ranks, parallel excess, transformer- and DC-mediated cycle ranks, and `branch_scope` |
| `voltage_tiers` | One count record per source-propagated voltage label, including `unassigned` where needed |
| `galvanic_zones` | One record per zone with its minimum-bus `anchor`, voltage labels, cycle counts, and number of incident isolating transformers |
| `parallel_lines` | Parallel-line evidence ([Redundancy](#Redundancy)), restricted to declared buses |
| `cycle_closing_branches` | Up to ten deterministic spanning-forest closing branches, with member IDs and endpoints; these are graph witnesses, not defect assignments |
| `conductor_paths` | Terminal-level components through mapped lines and closed switches, with voltage-tier counts and bounded load-terminal witnesses. Transformer winding terminals and voltage-source terminals act as boundary ports; transformer conversion is not inferred |
| `n_cross_tier_edges`, `n_skipped_branches` | Edges omitted from within-tier graphs, and invalid/self-loop branches omitted from graph counts |

For each graph, `cycle_rank = n_physical_edges - n_buses + n_components` and
`cycle_rank = simple_cycle_rank + parallel_excess`. The simple graph retains
one edge per bus pair. `transformer_mediated_cycle_rank` is the whole-network
cycle rank without DC links, less the sum of within-zone cycle ranks;
`dc_mediated_cycle_rank` counts the cycles that DC links add. A tier contains
only edges whose endpoints have the same source-propagated voltage-level label;
`n_cross_tier_edges` counts the excluded branches. Unassigned buses form an
explicit `unassigned` tier.

`whole_network["branch_scope"]` states what one physical branch is in the cycle
counts and witnesses; the mesh verdict uses the same branches, so
`n_extra_edges + neutral_only_cycle_rank` equals `whole_network["cycle_rank"]`.
Cycles and parallel lines are descriptive evidence, not automatic data-quality
Findings.

### Switch-state bus graph scenarios

`results[:connectivity]["switch_scenarios"]` compares the supplied
switch-state snapshot with a fixed backbone (all switch edges removed) and an
all-closed envelope (all valid switch edges included). Every view retains all
declared buses, including isolated buses, and counts each physical parallel
branch separately. The three views report bus, component, physical and simple
edge, physical and simple cycle-rank, parallel-excess, source-containing
component, and bus/load-without-source-path counts. The all-closed envelope is
a graph bound; it may combine mutually exclusive switch positions.

`transition_counts["classifications"]` counts all individually assessed switches:
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
appear in `switch_scenarios["assessment"]["invalid_switch_ids"]`.
Counterfactual counts are omitted in that case. Incomplete terminal maps do not
prevent a bus-graph assessment. `switch_scenarios["assessment"]["skipped_branch_ids"]`
lists invalid or self-loop declared branches excluded from graph counts;
`switch_scenarios["switch_counts"]["n_assessed"]` is zero when switch state
comparison is indeterminate.

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
bridge precomputation when pairs occupy different path components and an exact
group-removal calculation otherwise; `switch_scenarios["conductor"]["assessment"]["n_group_cut_fallbacks"]`
reports how many switches needed that calculation.

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
The `W.CONN.MESHED` and `E.CONN.DISCONNECTED` Findings describe only the
declared snapshot; switch scenarios introduce no Findings.

### Transformer banks and DC links

`results[:connectivity]["transformer_banks"]` lists single-phase units that join
the same two buses on different conductors (three line-to-neutral units, an
open-wye/open-delta pair, a center-tapped lighting unit with a power unit). Each
entry gives `bus_from`, `bus_to` and the sorted `units`. A bank is one branch of
the bus graph for radiality, and supplies the union of its legs' phases. A unit
whose secondary phase conductors another unit already spans (the same pair, or
the two legs of a center-tapped winding) is a parallel transformer: it is not
a leg and closes a cycle.

`results[:connectivity]["transformer_bank_groups"]` gives the full resolution
for every secondary bus with more than one single-phase unit: `supply_buses`
(the shared supply point, [defined above](#High-leg-delta-banks)), `bus_from`
(its first bus), `bus_to`, `units` (the legs), `parallel_units`,
`unassessed_units` (maps that cannot be read), `n_branches`, and `ambiguous`,
true when a unit partly overlaps the legs, as `a–b` beside `a–n` and `b–n`
does. A center-tapped unit anchors its bank: a unit across one of its legs is
the parallel one. The grouping is resolved for the whole pair before anything
is counted and does not depend on component ids. Unit pairs whose grouping
cannot be decided are listed in `undetermined_transformer_banks`
([reasons](#High-leg-delta-banks)).

`results[:connectivity]["dc_links"]` lists groups of AC buses whose converters
share one DC island; the buses of a group are connected through it. In the
degree and path metrics each DC island is a vertex of its own, joined to every
AC bus it couples, so a hop over a DC island counts as two and the metrics do
not depend on how the AC buses are named. `longest_path_buses` lists AC buses
only; `longest_path_vertices` is the same walk with each DC island shown as
`dc_island:<label>`. `dc_link_islands` gives the same groups with the
`dc_island` label (its smallest `dc_bus` id), so two islands that link the same
AC buses stay distinct. Cycles closed through a DC island are counted in
`results[:connectivity]["structure"]["whole_network"]["dc_mediated_cycle_rank"]`,
not as transformer-mediated, and the closing-branch witness is the DC link, with
an id of the form `<dc_island>:<bus>|<bus>`.

### Zone topology

Each entry of `results[:connectivity]["zones"]` has `label` (the zone's source
bus, or else its minimum bus id), `topology`, `phases` and `n_buses`.
`topology` is `three_phase`, `single_phase`, `split_phase`, `swer` or `other`.
A zone is `swer` only when a line or closed switch carries its one phase
conductor alone and no branch in the zone carries a neutral: the earth return
has to be witnessed by a branch. A two-wire section, or a branchless service bus
behind a single-phase transformer, is `single_phase`. `n_swer_zones` and
`n_split_phase_zones` count the tagged zones.

### Geographic evidence

`results[:connectivity]["spatial"]` is present when buses carry coordinate
fields. It describes coordinate quality, shared infrastructure,
geometry/topology candidates and an evidence-bound cleanup queue; coincidence
alone is not an error. Its keys and settings are in
[Spatial analysis settings & result keys](spatial_reference.md); the reasoning
is in [Spatial diagnostics](spatial_diagnostics.md).

## Diversity

`results[:diversity]` measures parameter spread per category. Uniform values
across many components suggest synthetic or allocated data.

| Key | Type | Meaning |
|---|---|---|
| `load` | Dict | P, Q and power-factor statistics, phase imbalance, configurations, models, and load repetition (below) |
| `generator` | Dict | Generator spread |
| `line` | Dict | Length statistics |
| `linecode` | Dict | Series-resistance statistics and the share with mutual coupling |
| `transformer` | Dict | Distinct ratings and turns ratios |
| `bus` | Dict | Voltage-bound coverage |
| `symmetry_score` | String | `LOW` when no category is flagged, `MODERATE` when at most half the analyzed categories are, `HIGH` otherwise |
| `n_flagged_categories` | Int | Categories whose `symmetry_flag` is true |

Each category Dict carries `analysed` (whether it had data to assess) and, when
assessed, `symmetry_flag`.

Load repetition counts identical ordered `(p_nom, q_nom)` declarations in
`results[:diversity]["load"]`: `n_total_loads`, `n_distinct_pq_tuples`,
`n_excess_repetitions`, `n_repeated_groups`, `n_members_of_repeated_groups`,
`largest_group_count`, and up to five `witnesses`. Group sizes 4, 3 and 1 give
8 loads, 3 distinct tuples, 5 excess repetitions and 2 repeated groups with 7
members. Values are grouped before conversion to Float64, so rounding cannot
create false matches. Loads with missing or misaligned P/Q are counted in
`n_excluded_loads`. Repetition does not establish duplicate customers.

## Operational

`results[:operational]` summarizes declared load, generation and limit coverage
at nominal setpoints.

| Key | Type | Meaning |
|---|---|---|
| `total_load` | Dict | `p_w`, `q_var`, `s_va`, `pf` and `pf_lag_lead` |
| `total_generation_capacity` | Dict | `p_max_w` (generators plus IBRs), `generator_p_w`, `ibr_p_w`, `q_max_var` |
| `generation_load_ratio` | Float or `nothing` | Local active capacity as a percentage of load; `nothing` without load |
| `import_dependent` | Bool | Local active capacity below 5 % of load |
| `passive_feeder` | Bool | The case declares no generator and no IBR |
| `load_by_configuration` | Dict | Load P per `configuration` |
| `transformer_utilisation` | Vector | Nominal downstream demand against nameplate ([below](#Transformer-utilization)) |
| `winding_limit_coverage` | Dict | Per-winding caps of `n_winding` transformers ([below](#Transformer-winding-caps)) |
| `line_thermal_coverage` | Dict | `n_lines`, `n_with_thermal_limit`, `n_unconstrained`, `pct_constrained` |
| `unloaded_phase_findings` | Int | Number of `I.OPS.UNLOADED_PHASE` Findings |
| `feeder_length` | Vector | One record per galvanic zone ([below](#Feeder-length-and-supply-boundaries)) |

`W.OPS.IMPORT_DEPENDENT` is raised only for a case that declares local
resources with negligible capacity; a passive feeder imports by construction.

### Transformer utilization

Each `transformer_utilisation` entry has `id`, `subtype`, `s_rating_va`,
`s_load_va`, `utilisation_pct`, `estimate_status`, and the fixed labels
`comparison_basis = "nominal_demand_to_nameplate"` and
`modeled_limit_compliance = "unassessed"`. The downstream-load estimate excludes
the transformer under analysis. If its from side remains reachable from its to
side, `estimate_status` is `upper_bound` and the entry does not raise
`W.OPS.XFMR_OVERLOADED`; parallel siblings and other alternate paths defeat the
radial attribution. Otherwise `estimate_status` is `radial_component`. This is
an aggregate nameplate screen; the per-coil estimate is the
[coil headroom](#Qualified-nominal-transformer-coil-headroom) in pre-flight.

### Transformer winding caps

For two-winding subtypes the OPF turns `s_rating` into a per-coil cap. An
`n_winding` transformer is different: only per-winding `i_max` (coil current)
and `s_max` (coil apparent power, shared equally among phase legs) limit it.
`results[:operational]["winding_limit_coverage"]` lists each winding's caps
with field paths, and `W.OPS.XFMR_UNCONSTRAINED` flags windings with no finite
supported cap. A cap can be absent or explicitly `Inf`; observations count both
states, so an intentional unbounded declaration stays visible. Zero is a real
restriction. Direct neutral-current caps are not assessed, and this is declared
data, not a built or solved model. Other subtypes are reported as not
applicable.

### Feeder length and supply boundaries

`results[:operational]["feeder_length"]` reports, per galvanic zone, how far (by
declared line length) the farthest bus is from the nearest *supply boundary*: a
voltage source, or a transformer port with a source beyond it. For a chain of
four 100 m lines fed from both ends this is 200 m (`boundary_reach_m`), while
`reach_m` / `anchor_extent_m` measures 400 m from one end.
`I.OPS.FEEDER_LONG` and `I.OPS.FEEDER_SHORT` compare it with per-band
thresholds. Review genuine feeder size, unit conversions and the OpenDSS default
`length=1`: copying 1 km as 1 m makes a line 1000 times too short; interpreting
1000 m as 1000 km upstream makes it 1000 times too long.

`observations.impedance_basis_counts` separates per-length `length_scaled`
linecodes, inline `absolute_section` matrices and `unresolved` declarations.
As in the model, inline matrices win when a line also names a linecode;
`inline_overrides_linecode` counts those lines.
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

## Load models

`results[:load_models]` classifies load models.

| Key | Type | Meaning |
|---|---|---|
| `by_model` | Dict | Load count per model (`constant_power`, `constant_current`, `constant_impedance`, `zip`, `exponential`) |
| `n_voltage_dependent` | Int | Loads whose demand depends on voltage |
| `zip_equivalent` | Vector | Exponential loads with integer exponents in {0, 1, 2}, representable losslessly as ZIP (`I.LOAD.EXP_ZIP_EQUIVALENT`) |
| `nonlinear_no_vmin` | Vector | Voltage-dependent loads on buses without a lower voltage bound (`W.LOAD.NL_NO_VMIN`) |

## Provenance

`results[:provenance]` records where the data most likely came from and which
modeling conventions it encodes. The physics is in
[How network diagnostics work](methodology.md).

| Key | Type | Meaning |
|---|---|---|
| `convention` | String | The convention statement repeated in the report header: wires per level, grounding, length normalization, line-model mix |
| `linecodes` | Dict | `by_linecode` (per-linecode matrix classification, including the balance tier) and `verdict_counts` |
| `impedance_transform` | Dict | Phase-to-neutral, modified phase-to-neutral and Kron classification per linecode: `by_linecode`, `by_type`, `evidence_by_linecode` |
| `inline_line_matrices` | Dict | Invariant checks on lines that carry their own matrices: `checked`, `n_checked` |
| `line_models` | Dict | Line model per element (series, symmetric π, asymmetric π, Γ): `counts`, `by_element`, and the `asymmetric_pi`, `gamma` and `shunt_conductance` lists |
| `geometry_crosscheck` | Dict | Linecodes compared with their compiled conductor geometry: `checked`, `mismatched`, `n_checked` |
| `wires_by_level` | Dict | Level label → wire count (`wires`) and `nominal_v`, among others |
| `grounding` | Dict | Neutral grounding structure: `convention`, `n_grounding_points`, `n_floating`, `floating_components`, `all_perfectly_grounded`, `n_buses_with_neutral`, `n_neutral_branches`, `n_neutral_components` |
| `earthing_zones` | Vector | One record per galvanic zone: earthing `tag`, `status`, star-point earthing, downstream neutral earths and `protective_system_status` |
| `opendss_defaults` | Dict | `n_default_hits`, `default_z_linecodes`, `length_normalized` |
| `capacitor_like_shunts`, `reactor_like_shunts` | Dict | `n`, `ids` of shunts that look like capacitor or reactor banks |
| `switch_like_lines` | Dict | `n`, `ids` of lines below the switch-like impedance thresholds |
| `line_voltage_level_bridges` | Dict | `n`, `ids` of lines whose endpoints sit at different voltage levels |
| `redundant_voltage_bounds`, `inconsistent_bounds`, `inapplicable_voltage_bounds`, `overlapping_voltage_bounds` | Dict | `n`, `ids` of buses with voltage-bound declarations of that kind |
| `voltage_source_sequence` | Dict | `n`, `ids` and `arrangements`: voltage sources whose angle arrangement is not a positive-sequence rotation |
| `i_max_incomplete` | Dict | Lines, switches and transformers with partial or absent current ratings |
| `powerio_conversion` | Dict | What the OpenDSS import could not carry: `n_classes`, `n_diagnostics`, `by_code`, `source` |

### Impedance hint evidence

The impedance provenance hints (`I.PROV.SEQ_DERIVED`,
`I.PROV.DECOUPLED_PHASES`, `I.PROV.IMPEDANCE_TRANSFORM_*`) keep their evidence
in `detail["interpretation"]`; how to read each pattern is in
[Impedance provenance hints](methodology.md#Impedance-provenance-hints).

- `observations["by_linecode"][id]` records `n_conductors`, `phase_block_only`
  (a conductor lies outside the inspected phase block) and
  `additional_conductor_coupling_ratio` (the relative coupling to it). The
  decoupled-phases hint adds `phase_self_uniform`, which separates uniform from
  unequal diagonal terms; the sequence hint adds the implied `z1` and `z0`.
- `observations["pattern_comparison"]` compares matrix statistics with the
  reference patterns.
- The Kron hint's `supporting_context` counts the uses of each linecode:
  `n_mv_hv_lines`, `n_lv_with_neutral_lines` and `n_unassessed_lines` sum to
  `n_other_or_unassessed_lines`, each with bounded line-ID examples. Its
  `implications` carry the id `known_mv_hv_context` when every referenced use
  is a positively identified MV/HV line, `unused_linecode_context` when no line
  uses the linecode, and `unassessed_use_context` when some uses have
  incomplete or mixed voltage or map evidence.

Converter-generated source equivalents (linecodes whose `source` names a
Thevenin or source impedance, e.g. from `from_dss`) are classified but never
flagged; the report counts them. Compatibility details are in
[Provenance report compatibility](dev/versioning.md#Provenance-report-compatibility).

## Pre-flight

`results[:preflight]` screens for infeasibility before a solve.

| Key | Type | Meaning |
|---|---|---|
| `generation_adequacy` | Dict | `total_load_w`, `total_gen_cap_w`, `total_ibr_cap_w`, `adequacy_ratio`, `import_dependent` |
| `voltage_bound_tightness` | Dict | Bound coverage: `n_buses`, `n_with_lower_bound`, `n_with_upper_bound`, `n_with_bounds_by_kind`, `n_without_bounds`, `buses_without_bounds` |
| `constraint_conflicts` | Dict | `n_conflicts` and `conflicts`: lower bounds above upper bounds (v/vpn/vpp/vpos, p, q) |
| `source_setpoints` | Dict | `n_source_oob` and `violations`: source magnitudes outside their bus bounds |
| `source_bus_generators` | Dict | Generators on a source bus, counted as bounded and unbounded, with `generators` |
| `topological_risk` | Dict | `n_voltage_sources`, `single_point_of_failure` (at most one source) and switch counts |
| `transformer_coil_headroom` | Dict | Nominal per-coil headroom of a single-phase bank ([below](#Qualified-nominal-transformer-coil-headroom)) |
| `tpia_status` | String | Always `not_run`; reserved |

### Qualified nominal transformer coil headroom

`results[:preflight]["transformer_coil_headroom"]` exposes a
**nominal-demand estimate**, separate from the supplied-result
`profile_solution(net, result).results[:transformer_loading]` report.
The same block is carried by `execute_analysis`, JSON analysis reports and the
`analyze_case` recipe. Markdown includes the coil table and unassessed
reasons; terminal reports show the stable preflight Findings.

The supported domain is one `single_phase` transformer bank in a connected radial
network with exactly one upstream voltage source, explicit ordered branch maps,
and phase-neutral `SINGLE_PHASE` or `WYE` loads. A case may use its documented
`n`/`N` neutral naming convention or declared terminal roles; the report records
which was used. Endpoint labels are never matched as a substitute for an absent
map. Lines may be oriented either way and may explicitly permute phase labels.
Fixed open switches are omitted from the supply graph; isolated buses make this
whole-network screen inapplicable. Reverse-fed transformers, multiple
banks or supplies, meshes (including parallel paths), phase-to-phase/delta loads,
ZIP/exponential models, local generation, IBRs, separate shunts/capacitors,
DC devices, control profiles and authored tap bounds/decisions are unassessed.
The screen does not allocate the unsupported cases by phase count or bank
totals.

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

For example, a 100 kVA three-coil bank has a 33.3 kVA cap per coil. With 40 kW
on coil 1 alone, nominal bank utilization is 40 %, but coil 1 is at 120 % with
headroom −6.667 kVA.
`W.PRE.XFMR_COIL_HEADROOM` flags negative nominal headroom;
`I.PRE.XFMR_COIL_UNASSESSED` explains unsupported or incomplete cases.
`W.OPS.XFMR_OVERLOADED` is the separate aggregate nominal-load warning above
90 %.

Positive headroom **does not prove feasibility** and negative headroom **does
not prove infeasibility**. The result records both limitations, its assumptions
and `solver_run = false`. It neither retries a solve nor edits the network.
This is a nominal-demand screen. Assessing a solved network also requires
checking its equations, operating limits and recovered quantities.

## Schema

`results[:schema]` validates the document against the bundled JSON Schema and
catalogs fields outside the data model.

| Key | Type | Meaning |
|---|---|---|
| `jsonschema_ran` | Bool | A JSON Schema exists for the case's spec version and was applied |
| `jsonschema_valid` | Bool | Conditional on `jsonschema_ran`: the document passed |
| `spec_version` | String | Conditional on `jsonschema_ran`: the version validated against |
| `unknown_fields_by_type` | Dict | Component type → fields not in the data model (cataloged, not rejected) |
| `n_component_types_with_unknown` | Int | Number of entries in `unknown_fields_by_type` |

## Completeness

`results[:completeness]` has one Dict per component type present in the case
(`bus`, `line`, `linecode`, `load`, `shunt`, `voltage_source`, `transformer`,
…), with `n_components` and `n_with_missing` (components missing a required
field, `E.COMP.MISSING_REQUIRED`). Every type except `transformer` also has
`optional_coverage`: optional field → number of components that declare it.
Transformer requirements are checked per subtype.

## Domain rules

`results[:domain_rules]` checks numerical plausibility; the Findings carry the
detail.

| Key | Type | Meaning |
|---|---|---|
| `n_checks_run` | Int | Individual plausibility checks evaluated |
| `max_adjacent_impedance_ratio` | Float | Largest series-impedance ratio between lines sharing a bus (buses with a source, transformer or switch excluded) |
| `terminal_conventions` | Dict | Resolution of the case's terminal-role labels: `status`, `role_source`, `resolved_roles`, `declarations`, `invalid_declarations`, `unclassified_labels`, `unused_labels`, `usage`, `unassessed_paths` |

## Redundancy

`results[:redundancy]` lists components that can be removed or merged.

| Key | Type | Meaning |
|---|---|---|
| `zero_loads`, `zero_shunts`, `unused_linecodes` | Dict | `n`, `ids` |
| `sparse_phase_loads` | Dict | `n` and `loads`: WYE loads with zero phases, load id → dead phase indices |
| `mergeable_loads` | Dict | `n_groups`, `groups`: loads on one bus with the same configuration and terminal map (time-series loads excluded) |
| `mergeable_lines` | Dict | `n_groups`, `groups`: series lines that can be merged (junction-aware) |
| `parallel_lines` | Dict | Parallel line records per bus pair (below) |
| `duplicate_linecodes` | Dict | `n_duplicate_groups`, `groups` |
| `dual_thermal_limits` | Dict | `n`: components that declare both `i_max` and `s_max` (`W.RED.DUAL_THERMAL_LIMIT`) |
| `dc_redundancies` | Int | DC-network redundancies such as self-loop DC branches |

Parallel line records are grouped by bus pair and compared after endpoint
normalization: a reversed record has its from/to fields swapped and its angle
bounds negated, then terminal maps are compared in order, with no inferred
permutation, followed by every other declared field except `meta`. Classes are
`incomplete_terminal_map`, `terminal_map_disagreement`,
`unsupported_orientation`, `same_declared_fields` and
`different_declared_fields`; `classification_counts`,
`member_counts_by_class`, `excess_counts_by_class`, `n_parallel_excess` and
`n_identical_group_excess` count them, and `witnesses` keeps up to five per
class. Matching records are inspection candidates, not proven duplicate assets
(`asset_identity = "unassessed"`). The same evidence appears in
`results[:connectivity]["structure"]["parallel_lines"]`.

## Integrity

`results[:integrity]` checks referential and structural integrity.

| Key | Type | Meaning |
|---|---|---|
| `n_reference_issues` | Int | References to undeclared buses or terminals |
| `n_dimension_issues` | Int | Arity and matrix-dimension mismatches |
| `n_galvanic_islands`, `n_without_reference` | Int | Galvanic islands, and those without a voltage reference (`E.INT.NO_VOLTAGE_REFERENCE`) |
| `n_unreferenced_conductor_groups` | Int | Conductor groups in a referenced island that the reference does not reach |
| `n_floating_load_terminals` | Int | Loads, generators and IBRs with a phase terminal no branch wires (`W.INT.FLOATING_LOAD_TERMINAL`) |
| `n_unused_bus_terminals` | Int | Buses that declare a terminal no component references (`W.INT.UNUSED_BUS_TERMINAL`) |
| `impedance_spread`, `n_low_impedance_lines` | Float, Int | Conditional on at least three lines with a series impedance: max/min impedance ratio, and lines below 10⁻³ of the median (`W.INT.LOW_IMPEDANCE_LINE`) |

## Spec conformance

`results[:spec]` checks Task Force specification rules that the JSON Schema
cannot express.

| Key | Type | Meaning |
|---|---|---|
| `n_voltage_sources` | Int | Declared voltage sources (the specification expects one) |
| `n_ibr_issues` | Int | IBR prime-mover, topology and terminal-map arity issues |
| `n_triangular_linecodes` | Int | Linecodes stored upper-triangular instead of full row-first |
| `n_conformance_issues` | Int | Total conformance issues |
| `n_phase_to_neutral` | Int | `E.TMAP.PHASE_TO_NEUTRAL` Findings |
| `n_cross_phase_lines` | Int | Lines and switches whose from and to maps differ |
| `n_permuted_terminal_maps` | Int | Branch ends whose map is not in the bus's terminal order |

## Benchmark readiness

`results[:benchmark]` assesses whether the case is a well-posed OPF benchmark
([rationale](methodology.md#Benchmark-readiness)).

| Key | Type | Meaning |
|---|---|---|
| `objective_wellposed` | Bool | A generator or voltage source carries a cost |
| `only_slack_generation` | Bool | The only priced element is the slack and no dispatchable DER exists |
| `n_generators`, `n_ibrs`, `n_with_cost` | Int | Generators, IBRs and costed generators |
| `pct_v_bounds` | Float | Buses with `v_min`/`v_max`, in % |
| `pct_voltage_magnitude_bounds` | Float | Buses with any voltage-magnitude bound, in % |
| `n_vpn_bounds`, `n_vpp_bounds`, `n_vpos_bounds` | Int | Buses with phase-to-neutral, phase-to-phase and positive-sequence bounds |
| `pct_thermal_limits` | Float | Lines with a thermal limit, in % |
| `n_gen_no_dof`, `n_gen_zero_cost`, `n_same_cost_gen_pairs`, `n_loads_zero_pnom` | Int | Counts behind `W.BENCH.GEN_NO_DOF`, `W.BENCH.GEN_ZERO_COST`, `W.BENCH.GEN_DEGENERATE_COST` and `I.BENCH.LOAD_ZERO_PNOM` |
| `suggestions` | Vector | Augmentation suggestions as text (`I.BENCH.AUGMENTATION`) |

## Report-level blocks

### Assessment coverage

`results[:assessment]` records which tracked checks could be assessed.

| Key | Type | Meaning |
|---|---|---|
| `checks` | Vector | One record per tracked check |
| `check_status_counts` | Dict | Checks per status |
| `scope` | String | `explicit_producer_status_with_legacy_coverage_unknown` |
| `comprehensive_validation` | Bool | Always `false`: coverage is not a validation score |

Each check record has `check`, `entity_unit`, `n_entities`, `status`,
`status_counts`, `reason_counts` and `reason`. A status is one of `assessed`,
`skipped`, `inapplicable`, `indeterminate` or `unknown`; it is separate from
severity. Reports show a one-line summary plus the checks you can act on.
Passes without a complete coverage ledger appear only in JSON, as
`<pass>_remaining_coverage` checks with status `unknown`.

### Consolidation

`results[:consolidation]` records what report consolidation changed
([how consolidation works](analysis.md#Report-consolidation)).

| Key | Type | Meaning |
|---|---|---|
| `rolled_up` | Vector | One entry per roll-up: `code`, `n` |
| `subsumed` | Vector | One entry per dropped code: `code`, the covering code `by`, `n`, and `components` for per-component subsumption |
| `rollup_threshold` | Int | The threshold in effect |
| `n_findings_before`, `n_findings_after` | Int | Finding counts before and after consolidation |
