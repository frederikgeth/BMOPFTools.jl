# Analysis result keys

Reference for the structured results in `analyze(net).results`. For what the
passes are and how to read the report, start with
[Analysis & reports](analysis.md); for the meaning of a finding code, use the
[finding-code reference](findings.md). Keys documented here are stable across
versions.

## Connectivity

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
for every bus pair with more than one single-phase unit: `units` (the legs),
`parallel_units`, `unassessed_units` (maps that cannot be read), `n_branches`,
and `ambiguous`, true when a unit partly overlaps the legs, as `a–b` beside
`a–n` and `b–n` does. A center-tapped unit anchors its bank: a unit across one of
its legs is the parallel one. The grouping is resolved for the whole pair before
anything is counted and does not depend on component ids.

`results[:connectivity]["structure"]["whole_network"]["branch_scope"]` states
what one physical branch is in the cycle counts and witnesses; the mesh verdict
uses the same branches, so `n_extra_edges + neutral_only_cycle_rank` equals
`whole_network["cycle_rank"]`.

`results[:connectivity]["dc_links"]` lists groups of AC buses whose converters
share one DC island; the buses of a group are connected through it. In the
degree and path metrics each DC island is a vertex of its own, joined to every
AC bus it couples, so a hop over a DC island counts as two and the metrics do not depend on how
the AC buses are named. `longest_path_buses` lists AC buses only;
`longest_path_vertices` is the same walk with each DC island shown as
`dc_island:<label>`.
`dc_link_islands` gives the same groups with the `dc_island` label (its smallest
`dc_bus` id), so two islands that link the same AC buses stay distinct. Cycles
closed through a DC island are counted in
`structure.whole_network["dc_mediated_cycle_rank"]`, not as transformer-mediated,
and the closing-branch witness is the DC link, with an id of the form
`<dc_island>:<bus>|<bus>`.

### Zone topology

`results[:connectivity]["zones"]` classifies each galvanic zone as `three_phase`,
`single_phase`, `split_phase`, `swer` or `other`. A zone is `swer` only when a
line or closed switch carries its one phase conductor alone and no branch in the
zone carries a neutral: the earth return has to be witnessed by a branch. A
two-wire section, or a branchless service bus behind a single-phase transformer,
is `single_phase`. `n_swer_zones` and `n_split_phase_zones` count the tagged zones.

### Conditional geographic evidence

Spatial analysis runs automatically when bus coordinate fields are present.
It describes coordinate quality, shared infrastructure, geometry/topology
candidates and an evidence-bound cleanup queue. Coincidence alone is not an error.
See [Spatial diagnostics and cleanup review](spatial_diagnostics.md) for coordinate
semantics, suppression, candidate codes, illustrated examples and exports.


## Voltage levels

`results[:voltage_levels]["bus_voltage_map"]` holds one per-conductor
(phase-to-reference) nominal voltage per bus, propagated from the sources through
transformer ratios. Three cases need care when reading it:

- A phase-to-phase single-phase winding carries a line-to-line `v_nom`; the map
  holds the corresponding per-conductor value.
- An `n_winding` DELTA winding's `v_nom` is its line-to-line coil voltage; the map
  again holds the per-conductor value of the bus it lands on.
- On a high-leg (four-wire) delta bus no single value describes every conductor.
  The map holds the center-tapped leg voltage, the bus is listed in
  `mixed_phase_to_neutral_buses`, and the power units that create the high leg are
  listed in `high_leg_units`; `high_leg_banks` gives, per power unit, the
  lighting unit, the buses, the high-leg conductor and a `status`. The two
  units need not share a primary bus id, but grouping them across buses needs
  conductor-level evidence. Conductors are followed through closed switches,
  terminal by terminal. A winding's supply point is the set of buses at which
  every one of its primary terminals, the neutral included, is present; two
  units are one bank when those sets are equal (`supply_buses`), so a full
  primary disconnect between the units does not split the bank. A tie that
  carries some but not all of those conductors is a partial tie: the units
  stay separate branches, the pair is listed in
  `results[:connectivity]["undetermined_transformer_banks"]`, and a would-be
  high-leg bank has status `undetermined`. A tie on a conductor neither winding
  uses, or a neutral bond alone, is no evidence. None of this depends on bus
  names, switch direction or terminal labels. A bank is
  identified from the nominal phasors of the two primary windings. The phasor of
  a winding terminal is the magnitude and angle a voltage source declares for the conductor
  that terminal is on, followed through the terminal maps of lines and closed
  switches (a terminal called `b` that is fed from the source's `a` carries the
  angle of `a`, and a terminal called `n` that a line maps onto a source phase
  carries that phase; a conductor no source declares is at zero only when one
  of its terminals is a return terminal that is perfectly grounded or on a
  source bus, and has no established voltage otherwise; a shunt to earth is a
  path, not a voltage):
  the third conductor must come out at √3 times the leg level, with each
  secondary voltage taken as the traced primary phasor times the unit's
  effective turns ratio, nameplate ratio and `tap` together, as the solver
  builds it. A free tap (`tap_min < tap_max`) makes that ratio a range, reported
  as `secondary_amplitude_range`: the bank is `verified` only if every tap
  position closes the delta, `amplitude_mismatch` if none does, and `unverified`
  (with no Finding) if the positions disagree. Geometry and amplitude are separate conditions: the primaries'
  directions must close the delta at the bank's own line-to-line amplitude, and
  the power unit's secondary must be that amplitude within 10 %. In-phase
  primaries are never a bank, whatever the resulting magnitude. When the
  directions fit but the amplitude does not (a wrong rating, or a weak source
  phase), the status is `amplitude_mismatch`: not a high leg, and reported as
  `W.VOLT.XFMR_RATIO` with `secondary_amplitude_ratio`. A power winding whose
  two primary terminals trace to the same source conductor has no voltage
  across it: the same status, with a ratio of zero. Primaries on the
  same phase, a line-to-line beside a line-to-neutral primary, or one reversed
  winding do not close the delta and are ordinary level conflicts. Phase
  labels are never evidence of an angle: behind another transformer (two legs
  of an upstream center tap are 180° apart, whatever they are called) the
  status is `unverified`, the unit is kept out of level propagation, and it is
  not called a high leg. The high leg sits at √3 times the leg voltage to
  neutral. A power unit's own ratio is still checked, against twice the leg level.

### Transformer phase evidence

[Transformer phase reporting](transformer_phase.md) separates authored winding
connections and nameplate declarations from the derived ideal effective relation.
Inventory and voltage transitions retain string labels and add structured status,
phase correspondence, orientation and coil evidence. A `?` suffix never means
clock zero. Use `transformer_phase_relation` for a directed winding pair or pass
`phase_order` to the standalone inventory/voltage passes for custom labels.


## Pre-flight

### Qualified nominal transformer coil headroom

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


## Operational

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


`results[:operational]["import_dependent"]` is true when local active capacity is
below 5 % of load, and `["passive_feeder"]` when the case declares no generator and
no IBR at all. `W.OPS.IMPORT_DEPENDENT` is raised only for a case that declares
local resources with negligible capacity; a passive feeder imports by construction.

## Report-level blocks

### Assessment coverage

`results.assessment` lists which tracked checks were assessed, skipped, not
applicable or indeterminate, with reasons. It is separate from severity and is
not a validation score. Reports show a one-line summary plus the checks you can
act on; legacy passes without a coverage ledger appear only in JSON.


### Consolidation

`results[:consolidation]` records what the report consolidation changed:
`rolled_up` (code and count per roll-up), `subsumed` (dropped code, the code that
covers it, and the components), `rollup_threshold`, and the finding counts before
and after. See [Report consolidation](analysis.md#Report-consolidation).

### Repetition and parallel declarations

Parallel line records are grouped by bus pair and compared strictly, keeping
terminal order and endpoint orientation; matching records are inspection
candidates, not proven duplicate assets. Load repetition counts identical P/Q
declarations: group sizes 4, 3 and 1 give 8 loads, 3 distinct tuples, 5 excess
repetitions and 2 repeated groups with 7 members. Values are grouped before
conversion to Float64, so rounding cannot create false matches. Reports keep
radial nameplate estimates separate from ambiguous upper bounds, which never
trigger overload warnings.
