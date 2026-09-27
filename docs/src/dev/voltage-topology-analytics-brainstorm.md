# Voltage and topology analytics: working design

Status: topology, conductor-path, and conditional geographic increments
implemented on `codex/voltage-topology-analytics`. This note is the development
plan for case analysis, not a new electrical-validity contract. The branch adds
structured tier and zone cycle counts, parallel-line declaration classes,
cycle-closing branch witnesses, and mapped conductor paths. Three `W.GEO.*`
codes report explicit-WGS84 contradictions; the existing `W.CONN.MESHED`
Finding now carries the cycle decomposition and bounded branch witnesses.

## Why the current summary needs another layer

`voltage_level_analysis` reports source-propagated nominal bus levels and
transformer transitions. `connectivity_analysis` reports components, degree,
source distance, and one whole-network physical cycle rank (`n_extra_edges`).
`redundancy_check` separately lists parallel line groups. These views are useful,
but the whole-network cycle rank combines several different structures.

The pinned September 17 Springfield analyses illustrate the distinction:

| Metric | SFC peak | SPF west coverage inspection |
|---|---:|---:|
| Physical cycle rank, all branches | 303 | 499 |
| Excess parallel line edges | 145 | 203 |
| Cycle rank after collapsing parallel bus pairs | 158 | 296 |
| MV line-graph cycle rank | 12 | 11 |
| LV line-graph cycle rank after collapsing parallel pairs | 120 | 257 |
| Remaining cycles involving transformer connections | 26 | 28 |
| LV line components supplied through multiple transformers | 17 | 15 |

These are graph counts, not operating-switch-state claims. They use the
source-propagated voltage tiers in the existing reports, lines as their declared
bus-to-bus edges, and transformer winding connections. The SPF inspection model
contains provisional coverage extensions, so comparison with SFC must carry that
model boundary. Existing branch status is only represented by declared switches;
unrecorded normally-open points cannot be inferred from the graph.

The existing reports also reveal a separate intake problem worth triaging before
interpreting warning totals. SFC contains 6,932 and SPF 9,624 two-terminal
loads labeled `WYE`; BMOPFTools' load spec requires `SINGLE_PHASE` for a
two-terminal load. Every load in both files uses `model="CONSTANT_POWER"`,
where the BMOPF enum is lowercase `constant_power`. The repeated
`W.SPEC.CONFIG_ARITY` and `W.INT.DIM_MISMATCH` warnings largely follow the
two-terminal labeling. A future summary should group these by shared cause,
while retaining the individual records and avoiding an automatic rewrite of
the source data.

## Useful views, in priority order

1. **Explain every cycle rank.** For each voltage tier and galvanic zone, report
   bus count, line count, connected components, physical cycle rank, excess
   parallel edges, simple-graph cycle rank, and source/transformer anchors.
   Report transformer-mediated cycles separately. This makes `meshed` an
   inspectable decomposition instead of one flag.
2. **Classify parallel members.** Group same-bus-pair lines and compare terminal
   maps, linecodes/primitive matrices, lengths, current ratings, route geometry,
   and provenance. Separate plausible independent circuits from identical
   duplicates and inferred/raw overlays. Preserve every member ID and rating;
   do not aggregate them in the analysis.
3. **Locate structural witnesses.** Report short fundamental cycles and
   biconnected blocks with their member IDs, voltage tier, and evidence status.
   Identify bridges and articulation buses, including how many loads lie behind
   each bridge from a declared source. Cycles involving multiple transformers
   deserve their own witness list.
4. **Check conductor-level reachability.** Trace each phase and neutral terminal
   through mapped line/switch terminals and transformer windings. Compare the
   declared load terminal with its actual supply path; locate exactly where a
   conductor appears, disappears, or changes identity. This is more specific
   than a bus-level connected-component test.
5. **Reconcile nominal voltages.** Per source-connected zone, compare propagated
   phase-to-ground level with bus/load references, line endpoints, and each
   transformer winding's declared line-to-line or phase-to-neutral base. Record
   absent/conflicting evidence explicitly. Avoid treating a 6.35 kV phase
   voltage and an 11 kV line-to-line winding nameplate as a mismatch.
6. **Inspect geographic embedding.** Distinguish abstract graph planarity from
   spatial crossings. With trustworthy bus coordinates and route polylines,
   locate line intersections without an electrical node, coincident endpoints
   with different bus IDs, route endpoints far from their buses, overlapping
   segments, and suspicious line-length/route-length ratios. A crossing alone
   is a review candidate: grade separation and different circuits are possible.
   Do not use straight endpoint chords to claim a route crossing.
7. **Summarize by evidence and origin.** Partition the above by source-recorded,
   reviewed, inferred, and placeholder elements where the input actually
   declares that provenance. Report unknown separately. A small number of
   flagged raw elements can be more consequential than a large inferred
   extension; counts alone should not imply a quality verdict.

## Proposed implementation shape

- First add a deterministic, read-only topology result. The graph builder
  should retain physical member IDs/types while also deriving a simple graph;
  it must respect open switches and transformer winding boundaries. Results
  should be stable under dictionary insertion order.
- The first slice should emit aggregate counts and bounded witness lists.
  Full per-edge detail may live in a structured export, since a large case
  already produces multi-megabyte reports and tens of thousands of Findings.
- Add Findings only for a precise, evidenced inconsistency. A parallel pair,
  cycle, spatial crossing, or multi-fed zone is descriptive by itself.
  Findings need stable codes, machine-readable detail, and tests matched by
  code rather than message.
- Keep geographic embedding optional. On cases without coordinates or route
  polylines, return coverage and an indeterminate spatial assessment instead
  of silently using straight-line geometry.

## Development sequence

1. **Implemented:** deterministic branch inventory and cycle-rank identities
   for the whole graph, source-propagated voltage tiers, and galvanic zones;
   transformer-mediated rank; bounded parallel-line witnesses; Markdown and
   JSON output. Verify on synthetic boundary cases and the Springfield cases.
2. **Partly implemented:** deterministic cycle-closing branch witnesses with
   member IDs and a cap of ten. Bridge witnesses and transformer incidence per
   zone remain future work.
3. **Partly implemented:** mapped conductor paths over lines and closed
   switches, using voltage-source and transformer winding terminals as
   boundaries. The result locates load terminals in paths without a boundary;
   it makes no transformer-conversion inference and emits no Finding. Detailed
   voltage-nameplate reconciliation remains future work.
4. **Spatial first slice implemented:** conditional coordinate/route coverage,
   line lengths by voltage tier, and CRS-gated geodesic comparisons for lines,
   routes, and transformers. An OpenDSS x/y pair copied into longitude/latitude
   is not treated as WGS84 without declaration or matching route evidence.
   Explicit WGS84 declarations also enable warnings for out-of-range bus
   coordinates, lines shorter than endpoint chords, and route endpoint gaps.
   Route-only evidence remains measurement support, not a network CRS claim.
5. **Later:** abstract graph planarity with a nonplanar witness, followed
   separately by route crossings, near misses, duplicate geometry, and
   provenance coverage. Those checks need spatial indexing and explicit
   interpretation of non-junction crossings.
- Exercise radial, simple-cycle, parallel-pair, multi-transformer, open-switch,
  missing-coordinate, and crossing-without-junction fixtures. Include boundary
  and serialization tests before adding the result to `analyze` and its JSON
  execution surface.

## Suggested first increment

Implement the per-tier/per-zone graph decomposition and parallel-member
classification first. It needs no new source format or geometric tolerance,
explains the 303/499 Springfield counts immediately, and provides the stable
graph objects needed for later cycle witnesses and spatial checks. The first
review should inspect the 17 SFC and 15 SPF LV components with multiple
transformer feeds and the parallel groups where inferred links overlap
source-recorded lines.
