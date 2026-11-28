# [Spatial analysis settings and result keys](@id spatial-reference)

Lookup tables for the spatial pass of [`analyze`](@ref) and
`connectivity_analysis`: configuration, thresholds, result keys, review-item
codes, the decision ledger and the export bundle. For what the evidence means,
see [Spatial diagnostics and cleanup review](spatial_diagnostics.md); for the
workflow, see the [spatial cleanup tutorial](@ref spatial-cleanup).

## [Configuration: `[spatial]`](@id spatial-config)

Set keys in a TOML file passed as `config=load_config("file.toml")`, or edit
`load_config()["spatial"]` before calling `analyze(net; config=config)`. Omitted
keys keep their defaults (from `config/default.toml`).

| Key | Default | Valid values | Controls |
|---|---|---|---|
| `enabled` | `true` | Boolean | The whole pass. `false` skips coordinate inventory, routes, proximity, candidates and review capture; no `W.GEO.*` Findings. |
| `proximity_enabled` | `true` | Boolean | Proximity inventory (`proximity`). |
| `proximity_radius_m` | `1.0` | finite, > 0 | Neighbor radius for `proximity` and `S.NEARBY_WITHOUT_DIRECT_BRANCH`. |
| `max_candidate_pairs` | `1000000` | integer ≥ 1 | Location-pair budget for the proximity search. |
| `witness_limit` | `20` | integer ≥ 1 | Examples kept per proximity and candidate check (and members per cluster). |
| `discrepancy_enabled` | `true` | Boolean | The `S.*` candidate checks (`discrepancy_candidates`). |
| `max_topology_pairs` | `100000` | integer ≥ 1 | Budget for nearby-pair expansion, series-path steps, branch-span pairs, route-segment processing and route-endpoint bus queries. |
| `max_series_hops` | `8` | integer 2–64 | Longest line-only series path (edges) compared with a direct line. |
| `route_endpoint_tolerance_m` | `5.0` | finite, > 0 | Route-endpoint candidate tolerance and alternative-bus search radius; also the absolute floor of the series-path detour rule. |
| `long_span_threshold_m` | `10000.0` | finite, > 0 | Absolute span above which a branch or route segment becomes a candidate. |
| `review_enabled` | `true` | Boolean | Capture of the `cleanup_review` queue. |
| `max_review_candidates` | `5000` | integer 1–100000 | Capture cap per check, then for the combined queue. |

Invalid values make the affected part `indeterminate` with reason
`invalid_configuration`; a disabled part is `inapplicable` with reason
`disabled`. A non-Boolean `enabled` or a non-object `[spatial]` section makes the
whole pass `indeterminate` / `invalid_configuration`.

Outside Julia, the pass is turned off with `execute_analysis(net;
spatial_enabled=false)`, `bin/bmopf analyze-case --input CASE.json --no-spatial`
or the MCP `bmopf_analyze` argument `"spatial_enabled": false`; the response
records the effective value. See
[JSON execution](execution_interface.md#Suppressing-geospatial-analysis).

## [Thresholds](@id spatial-thresholds)

Distances are great-circle lengths (sphere radius 6 371 008.8 m) in a geographic
frame and Euclidean lengths in a declared local Cartesian frame. "Comparison
length" is `line.meta.physical_length_m` when that key is present, otherwise the
declared `line.length` unless `meta.electrical_length_regularized = true` (then
unavailable). Only `route_endpoint_tolerance_m`, `long_span_threshold_m` and
`proximity_radius_m` are configurable.

| Comparison | Rule | Frames | Reported as |
|---|---|---|---|
| Line shorter than chord | comparison length + `max(5 m, 0.1 × chord)` < chord | geographic, Cartesian | `W.GEO.LINE_SHORTER_THAN_CHORD`; `length_context` `chord_check`; tag `shorter_than_chord` |
| Line shorter than chord (descriptive counter) | same rule on the **declared** length | geographic, Cartesian | `lines.n_shorter_than_chord_beyond_tolerance` |
| Line far longer than chord | comparison length > `max(5 × chord, chord + 100 m)` and no valid route whose recomputed length matches the comparison length | geographic, Cartesian | `W.GEO.LINE_LONGER_THAN_CHORD`; tag `far_longer_than_chord` |
| Length-context comparisons | \|a − b\| > `max(5 m, 0.1 × b)`: stored vs recomputed route length, comparison length vs recomputed route length, declared vs physical length | route checks WGS84 only | `length_context` statuses; tags `stored_route_length_mismatch`, `physical_route_length_mismatch`, `declared_physical_length_mismatch` |
| Declared vs stored route length (descriptive counter) | \|declared − route `length_m`\| > `max(5 m, 0.1 × declared)` | WGS84 | `routes.n_length_mismatches` |
| Route endpoint gap (descriptive counter) | gap > 5 m | WGS84 | `routes.n_endpoint_gaps_over_5m` |
| Route endpoint gap (Finding) | gap > `max(20 m, 0.1 × chord)` | declared geographic only | `W.GEO.ROUTE_ENDPOINT_GAP` |
| Route endpoint candidate | an endpoint farther than `route_endpoint_tolerance_m` from its bus, better of forward/reversed assignment; alternatives searched within the same radius | WGS84 | `S.ROUTE_ENDPOINT_DISAGREEMENT` |
| Direct alongside series path | series chord sum ≤ direct chord + `max(route_endpoint_tolerance_m, 0.1 × direct chord)` | geographic, Cartesian | `S.DIRECT_ALONGSIDE_SERIES_PATH` |
| Long span | all-port span of a line, switch or transformer, or one route segment, > `long_span_threshold_m` | span: both; segment: WGS84 | `S.LONG_BRANCH_SPAN`, `S.ROUTE_SEGMENT_DEFECT` |
| Proximity | separation ≤ `proximity_radius_m` | geographic, Cartesian | `proximity`; `S.NEARBY_WITHOUT_DIRECT_BRANCH` |
| Length scale | ≥ 10 lines with chord ≥ 10 m; median comparison-length/chord ratio within 5 % of a unit factor, and ≥ 60 % of lines within 20 % of it | geographic, Cartesian | `W.GEO.LENGTH_SCALE_SUSPECT`; `length_scale` |
| Coordinate outlier | position (0, 0) in a geographic frame; or, with ≥ 5 placed buses, distance from the median position > `max(100 km, 20 × p90 distance)` | geographic, Cartesian | `W.GEO.COORDINATE_OUTLIER`; `coordinate_outliers` |
| Route as frame evidence | both route ends within 10⁻⁵ degrees of the bus coordinates and all vertices valid | WGS84 routes | `coordinate_reference.status = "wgs84_route_evidence"` |
| Long-line rank | declared length ÷ the voltage tier's p99 declared length | any | `lines.relative_length_witnesses` (ranking only) |

The route endpoint gap is `min` over the two orientations of the larger of the two
endpoint distances. Unit factors for the length-scale rule are 0.001 (km stored
as m), 1000, 1/0.3048 (ft stored as m), 0.3048 (coordinates in ft declared as m),
1/304.8 (kft) and 1/1609.344 (mi). `W.GEO.*` Findings fire only with a declared
network frame; route evidence alone supports measurements but no Finding.
Placeholder lengths (exactly 1 on a line with inline impedance totals) are not
compared. The Finding definitions are in the
[GEO reference](findings.md#GEO-—-declared-coordinate-frames).

## [Coordinate declaration keys](@id spatial-declaration-keys)

Each key may appear on the network root or in `meta`; several declarations must
agree.

| Key | Scope | Accepted values |
|---|---|---|
| `crs`, `coordinate_reference_system`, `coordinate_system` | network | `"EPSG:4326"`, `"WGS84"`, `"CRS84"`; geographic datums by EPSG code or name: GDA94 (4283), GDA2020 (7844), JGD2000 (4612), JGD2011 (6668), NAD83 (4269), NAD83(2011) (6318), ETRS89 (4258), NZGD2000 (4167); `{"type": "cartesian", "name": ..., "units": ..., "axis_order": ["x", "y"]}`; any other code is recorded as `declared_other` (`"EPSG:28356"`, `28356` and `{"type": "projected", "epsg": 28356}` are one declaration) |
| `coordinate_units` | network, bus | Cartesian: `m`, `km`, `ft`, `ftUS` (1200/3937 m), `kft`, `mi` (and spelled-out aliases such as `metre`, `meters`); geographic: `degrees` |
| `coordinate_axis_order` | network, bus | `["longitude", "latitude"]` or `["x", "y"]`; a conflicting order is reported, never applied |
| `coordinate_provenance` | network default, bus | string; `schematic` and `displaced` exclude the bus from metric checks |
| `coordinate_accuracy_m` | network default, bus | finite, ≥ 0; descriptive only |

Bus position fields: `longitude`/`latitude` for a geographic frame, `x`/`y` for a
Cartesian frame. Route geometry: `line.meta.route_geometry` with
`basis = "WGS84_geodesic_polyline"`, `coordinates` (≥ 2 `[lon, lat]` vertices)
and optional `length_m`.

## [Spatial result: `results[:connectivity]["spatial"]`](@id spatial-result-keys)

Present when at least one bus has `longitude`, `latitude`, `x` or `y`, or when the
pass is disabled or misconfigured. Without coordinate fields the key is absent,
unless `extras.geojson` holds a GeoLayer.

| Situation | `status` / `reason` | Other keys |
|---|---|---|
| Disabled | `inapplicable` / `disabled` | `analysis_performed = false`, `caution` |
| Invalid `[spatial]` | `indeterminate` / `invalid_configuration` | `analysis_performed = false`, `caution` |
| No bus coordinates, unapplied GeoLayer | `indeterminate` / `unapplied_geolayer` | `analysis_performed = false`, `geolayer` (`path`, `n_features`, `space`, `crs`), `caution` |
| Analysis ran | (per section) | the sections below |

| Key | Contents |
|---|---|
| `coordinate_reference` | `status`, `declared_crs`, `caution`, `n_matching_wgs84_routes`, `n_metric_eligible_buses`, `distance_scope` (`declared_network_frame`, `matched_route_endpoints_only`, `unavailable`), `metric_distances_applicable`, `geodesic_distances_applicable`. |
| `coordinate_semantics` | Resolved `frame`, `datum`, `units`, `axis_order`, `unit_scale_to_m`, `distance_basis`, `issues`, `declarations`; provenance/accuracy coverage and bounded bus issue witnesses. |
| `coordinate_coverage` | `n_buses`, `n_with_any_coordinate`, `n_complete_lonlat`, `n_with_xy_fields`, `n_partial`, `n_invalid`, `n_outside_wgs84_range`. |
| `routes` | `n_lines`, `n_with_route`, `basis_counts`, `n_endpoint_comparisons`, `n_length_comparisons`, `n_endpoint_gaps_over_5m`, `n_length_mismatches` (`null` when nothing was compared), `endpoint_gap_witnesses` (≤ 10). |
| `lines` | `length_by_tier_m` (`n`, `p50`, `p95`, `p99`, `max`), `n_with_chord_comparison`, `n_shorter_than_chord_beyond_tolerance`, `longest_witnesses`, `relative_length_witnesses`, `shorter_than_chord_witnesses` (≤ 10 each). |
| `length_context` | `n_lines`, `comparison_status_counts` per comparison, `context_counts` per tag, `witnesses` (≤ 5 per tag), `tolerance`, `caution`. |
| `length_scale` | `status` (`passed`, `suspect`, `indeterminate`), `reason`, `median_length_to_chord`, `factor`, `reading`, `fraction_agreeing`, `n_lines`. |
| `coordinate_outliers` | `buses`, `reasons` per bus (`null_island` or `far_from_network` with `distance_from_median_m`), `n_assessed`, `rule`, `extent_p90_m`, `limit_m`. |
| `coincidence` | Exact-coordinate groups with context tags, counts per tag, bounded bus/terminal/component witnesses. |
| `transformers` | Maximum all-winding bus separation per transformer, quantiles, zero-extent counts, bounded assessed/indeterminate witnesses. |
| `proximity` | See [proximity keys](@ref spatial-proximity-keys). |
| `discrepancy_candidates` | `checks` (one entry per candidate check), `caution`, `unassessed`, the effective budgets and thresholds, `n_invalid_branch_declarations`. |
| `cleanup_review` | See [cleanup review keys](@ref spatial-review-keys). |

`coordinate_reference.status`:

| Status | Meaning |
|---|---|
| `declared_wgs84` | WGS84 or an accepted geographic datum (named in `coordinate_semantics.datum`). |
| `declared_cartesian` | A local Cartesian frame with units. |
| `wgs84_route_evidence` | No declaration; matching WGS84 routes support the frame for their endpoint buses only. |
| `declared_other` | A recognized but uninterpreted declaration (e.g. a projected EPSG code); metric checks inapplicable. |
| `ambiguous` | Invalid or conflicting declarations; metric comparisons and exact groups suppressed. |
| `unspecified` | No declaration and no route evidence; distances indeterminate. |

Status vocabulary used throughout: checks are `assessed`, `indeterminate` or
`inapplicable`; individual comparisons are `passed`, `failed`, `indeterminate` or
`inapplicable`.

Coincidence context tags: `transformer_ports`, `line_connected`, `open_switch`,
`closed_switch`, `unknown_switch_state`, `no_direct_branch`. Witness selection
keeps up to five groups per tag, 20 member buses and 20 internal components per
group.

### [Proximity keys](@id spatial-proximity-keys)

| Key | Meaning |
|---|---|
| `status`, `reason` | `assessed`; `inapplicable` (`disabled`, or `no_eligible_coordinates` under `declared_other`); `indeterminate` (invalid settings, no eligible coordinates, budget exhausted, index range exceeded). |
| `radius_m`, `max_candidate_pairs`, `witness_limit`, `metric_kind`, `linkage` | Effective settings; linkage is `single_linkage`. |
| `n_eligible_buses`, `n_unique_locations`, `n_indexed_locations`, `n_index_range_exclusions` | Coverage. |
| `n_near_bus_pairs` | Unordered bus pairs at different locations within the radius; `null` if incomplete. |
| `n_near_bus_pairs_observed` | Lower bound when incomplete. |
| `n_zero_distance_bus_pairs` | Pairs at one canonical metric location; `null` if incomplete. |
| `n_clusters`, `n_observed_components` | Final single-linkage clusters (`null` if incomplete); observed partial components (not a lower bound). |
| `counts_complete`, `candidate_pairs_checked` | Budget status. |
| `pair_witnesses`, `cluster_witnesses` | Representative pairs (voltage tiers, provenance, `reported_accuracy_sum_m`, multiplicity); clusters with `members`, `members_truncated`, `complete`. |

### [Candidate checks and `S.*` codes](@id spatial-candidate-codes)

Each entry of `discrepancy_candidates.checks` has `status`, `reason`, `scope`,
`counts_complete`, `n_candidates` (`null` when incomplete),
`n_candidates_observed` (lower bound), `witnesses` (≤ `witness_limit`) and
check-specific domain counts (`n_*`). `S.*` codes label review candidates; they
are not Finding codes.

| Check | Code | Evidence |
|---|---|---|
| `nearby_topology` | `S.NEARBY_WITHOUT_DIRECT_BRANCH` | Metric-eligible bus pair within the proximity radius (including co-location) with no direct line, switch or supported transformer between them; carries `component_relation` (`same_bus_component`, `separate_bus_components`, `unknown_switch_state`, `indeterminate_graph`), `voltage_tier_relation` (`same`, `different`, `unknown`) and `endpoint_like`. |
| `series_paths` | `S.DIRECT_ALONGSIDE_SERIES_PATH` | A direct line and a line-only path of 2 to `max_series_hops` edges with degree-two interior buses, meeting the detour rule above. |
| `branch_spans` | `S.LONG_BRANCH_SPAN` | Line, switch or all-winding transformer span above `long_span_threshold_m`. |
| `route_endpoints` | `S.ROUTE_ENDPOINT_DISAGREEMENT` | Valid WGS84 route whose endpoints disagree with eligible WGS84 bus positions; `orientation` (`forward`, `reversed`, `ambiguous`), per-side `gap_m`, unassigned `nearby_alternative_buses`. |
| `route_overlaps` | `S.SHARED_ROUTE_SEGMENT` | Two or more lines with exactly the same nonzero WGS84 vertex-to-vertex segment, either direction. |
| `source_intervals` | `S.REPEATED_SOURCE_INTERVAL` | An explicit nonempty string repeated in `meta.source_interval`, or separately in `meta.backbone_extension.source_interval`. |
| `route_defects` | `S.INVALID_ROUTE_GEOMETRY`, `S.ROUTE_SEGMENT_DEFECT` | Malformed route data; zero-length or repeated undirected WGS84 segments, or segments above `long_span_threshold_m`. |

Shared-segment and repeated-source groups also carry `declared_arrangement`
(`series_chain`, `parallel_bus_pair`, `branched_or_cyclic`, `disconnected`,
`indeterminate`), `terminal_map_relation` (`equal_declared_maps`,
`different_declared_maps`, `unassessed`) and a `voltage_context` computed over
all members, whose `relation` is `same`, `different`, `crossing_endpoint_tiers`
or `unknown`.
Unassessed: partial collinear overlap, crossings, self-intersections without a
repeated segment, arbitrary alternate paths, electrical equivalence.

### `R.LINE_LENGTH_CONTEXT`

One review item per line whose `length_context` carries any tag other than
`regularized_electrical_length`. Tags: `shorter_than_chord`,
`far_longer_than_chord`, `stored_route_length_mismatch`,
`physical_route_length_mismatch`, `declared_physical_length_mismatch`,
`invalid_route_geometry`, `invalid_route_length`, `invalid_length_declaration`,
`regularized_electrical_length`. The item evidence keeps all lengths, the
comparison basis, thresholds, `length_scales_impedance` and source references
(`raw_key`, `raw_layer`, `source_entity_id`).

## [Cleanup review: `cleanup_review`](@id spatial-review-keys)

| Key | Meaning |
|---|---|
| `schema_version` | `spatial-cleanup-review/v1`. |
| `ranking_policy` | `spatial-review-priority/v2`. |
| `status`, `reason` | `assessed` / `completed_within_declared_scope`; `indeterminate` / `incomplete_scan_or_capture` or `invalid_configuration`; `inapplicable` / `disabled`. |
| `queue_complete` | `false` if any scan or capture is incomplete, the queue was truncated, or a discrepancy scan was disabled. |
| `queue_truncated`, `n_items`, `n_captured_before_queue_limit`, `max_review_candidates` | Final-queue cap. |
| `coverage` | Per check (including `length_context`): `status`, `reason`, `n_observed`, `n_captured`, `scan_complete`, `capture_complete`, `scope`, `domain_counts`. |
| `items` | Ranked review items (below). |
| `locations` | Location groups (below). |
| `category_counts`, `disposition_counts`, `presentation_counts`, `review_status_counts` | Counts over captured items. |
| `case_fingerprint`, `analysis_fingerprint` | Decision bindings (see [fingerprints](@ref Sidecar-dispositions)). |
| `coordinate_context`, `analysis_settings` | Frame and metric coverage; the `[spatial]` settings used. |
| `scope`, `ranking_scope`, `grouping_policy`, `calibration`, `caution`, `count_scope` | Fixed descriptive text. |
| `decision_audit` | Present after [`apply_spatial_review`](@ref). |

Item fields:

| Field | Meaning |
|---|---|
| `item_id` | `review-` + SHA-256 of the candidate identity (code plus typed components; segment and line digest for shared segments; namespace and ID for source intervals; direct branch and ordered path, direction-independent, for series paths). |
| `code`, `check` | Review code and originating check (`length_context` for `R.LINE_LENGTH_CONTEXT`). |
| `priority`, `ranking_reason`, `evidence_class` | See the table below. |
| `assessment` | `category`, `observation`, `explanation`, `uncertainty`, `inspect`, `voltage_context`, `error_probability` (always `null`). |
| `bus_ids`, `components` | Referenced buses and typed components (`kind`, `id`). |
| `impact` | `n_identified_buses`, `n_identified_components`, `n_directly_attached_loads`, `subjects_complete`, `scope`. |
| `location_id`, `location` | Exact first sorted evidence point (`status = "located"`, `frame`, `coordinate`, `units`) or `unavailable` with `primary_asset`. |
| `geometry` | WGS84 `MultiPoint` or `null`. |
| `local_geometry` | Cartesian points in meters with `frame`, or `null`. |
| `geometry_basis` | `explicit_route_segment_vertices`, `disagreeing_route_endpoints` or `eligible_referenced_bus_locations`. |
| `geometry_coverage` | `n_identified_buses`, `n_buses_with_eligible_coordinates`, `n_evidence_points`, `all_identified_buses_located`, `subject_list_complete`. |
| `coordinate_evidence` | Per bus: provenance, accuracy, metric eligibility, issues. |
| `interpretation_evidence` | Direct/series items only: oriented terminal maps and same-bus terminal-set comparisons, intermediate attachments (loads, shunts, capacitors, sources, generators, IBRs) with terminal maps, `perfectly_grounded_terminals`, per-line lengths, and source declarations (`origin`, `evidence_status`, `claim`, `attachment_mode`, `method`, `source_ref`, `placeholder`, read under `meta` or one dictionary level below). |
| `evidence` | The underlying candidate record. |
| `evidence_fingerprint` | SHA-256 over the item's evidence-bearing fields. |
| `review` | `status`, `disposition` and, once replayed, `decision`. |

Location group fields: `location_id`, `location`, `item_ids`, `codes`, `priority`
(maximum), `max_item_directly_attached_loads`, `bus_ids`, `components`,
`n_identified_buses`, `n_identified_components`, `evidence_classes`,
`category_counts`, `disposition_counts`. Groups sort by priority, maximum
directly attached loads, component count, then `location_id`.

### [Priorities, evidence classes and categories](@id spatial-review-priorities)

Items sort by priority (3 first), then `n_directly_attached_loads`, then
`n_identified_components` (both descending), then `item_id`.

| `ranking_reason` | Codes | Priority | `evidence_class` | `category` |
|---|---|---|---|---|
| `invalid_geometry` | `S.INVALID_ROUTE_GEOMETRY` | 3 | `declaration_inconsistency` | `data_inconsistency` |
| `invalid_or_inconsistent_length` | `R.LINE_LENGTH_CONTEXT` with `invalid_length_declaration`, `invalid_route_length`, `shorter_than_chord` or `far_longer_than_chord` | 3 | `declaration_inconsistency` | `data_inconsistency` |
| `route_and_bus_coordinates_disagree` | `S.ROUTE_ENDPOINT_DISAGREEMENT` | 3 | `geometric_discrepancy` | `data_inconsistency` |
| `length_declarations_disagree` | other `R.LINE_LENGTH_CONTEXT`, not regularized | 2 | `declaration_inconsistency` | `data_inconsistency` |
| `direct_and_series_declarations` | `S.DIRECT_ALONGSIDE_SERIES_PATH` | 2 | `topology_candidate` | `review_candidate` |
| `nearby_separate_components_same_tier` | `S.NEARBY_WITHOUT_DIRECT_BRANCH` | 2 | `topology_candidate` | `review_candidate` |
| `line_endpoints_cross_voltage_tiers` | `S.SHARED_ROUTE_SEGMENT`, `S.REPEATED_SOURCE_INTERVAL` | 2 | `topology_candidate` | `review_candidate` |
| `repeated_source_identity_requires_review` | `S.REPEATED_SOURCE_INTERVAL` | 2 | `topology_candidate` | `review_candidate` |
| `degenerate_or_retraced_segments` | `S.ROUTE_SEGMENT_DEFECT` with zero or repeated segments | 2 | `geometric_discrepancy` | `review_candidate` |
| `voltage_context_unavailable` | `S.NEARBY_WITHOUT_DIRECT_BRANCH`, `S.SHARED_ROUTE_SEGMENT`, `S.REPEATED_SOURCE_INTERVAL` | 2 | `needs_information` | `needs_information` |
| `topology_evidence_incomplete` | `S.NEARBY_WITHOUT_DIRECT_BRANCH` | 2 | `needs_information` | `needs_information` |
| `regularized_length_requires_interpretation` | `R.LINE_LENGTH_CONTEXT` with a regularized length and no priority-3 tag | 1 | `representation_context` | `context_only` |
| `different_voltage_systems_share_location` | `S.NEARBY_WITHOUT_DIRECT_BRANCH` | 1 | `representation_context` | `context_only` |
| `proximity_without_connectivity_claim` | `S.NEARBY_WITHOUT_DIRECT_BRANCH` | 1 | `representation_context` | `context_only` |
| `different_voltage_systems_share_route` | `S.SHARED_ROUTE_SEGMENT`, `S.REPEATED_SOURCE_INTERVAL` | 1 | `representation_context` | `context_only` |
| `shared_representation_in_series_chain` | `S.SHARED_ROUTE_SEGMENT`, `S.REPEATED_SOURCE_INTERVAL` | 1 | `representation_context` | `context_only` |
| `distinct_terminal_maps` | `S.SHARED_ROUTE_SEGMENT`, `S.REPEATED_SOURCE_INTERVAL` | 1 | `representation_context` | `context_only` |
| `shared_route_without_conflicting_evidence` | `S.SHARED_ROUTE_SEGMENT` | 1 | `representation_context` | `context_only` |
| `absolute_span_review_threshold` | `S.LONG_BRANCH_SPAN`; `S.ROUTE_SEGMENT_DEFECT` with long segments only | 1 | `representation_context` | `context_only` |

For shared-segment and source-interval groups the rules apply in this order:
crossing endpoint tiers, different voltage systems, series chain, different
terminal maps, unknown voltage, then the code-specific default.

### Dispositions and presentation

| Disposition | Set by | Presentation bucket |
|---|---|---|
| `unreviewed` | default | `attention`, or `context` if the category is `context_only` |
| `confirmed_issue` | reviewer | `attention` |
| `needs_information` | reviewer | `attention` |
| `deferred` | reviewer | `attention` |
| `accepted_modeling` | reviewer | `reviewed` |
| `resolved` | reviewer | `reviewed` |

`review.status` after replay:

| Status | Meaning |
|---|---|
| `unreviewed` | No record for this item. |
| `recorded` | The latest record applies; `disposition` set from it. |
| `stale_decision` | The latest record's case, analysis or evidence fingerprint differs from the current one. |
| `conflicting_decisions` | Different records share the latest timestamp. |
| `invalid_record` | A malformed record targets this item. |
| `modified_evidence` | The item's evidence no longer matches its `evidence_fingerprint`. |

## [Sidecar dispositions](@id Sidecar-dispositions)

Decision records are created by [`spatial_review_decision`](@ref) and replayed by
[`apply_spatial_review`](@ref). Ledger file envelope:

```json
{"schema_version": "spatial-cleanup-review/v1", "decisions": [ ... ]}
```

Record fields (exactly these keys):

| Field | Requirement |
|---|---|
| `schema_version` | `spatial-cleanup-review/v1` |
| `item_id` | Nonempty; must match one captured item when created. |
| `case_fingerprint`, `analysis_fingerprint`, `evidence_fingerprint` | 64-character lowercase hex, copied from the review. |
| `disposition` | One of the dispositions above. |
| `reviewer`, `rationale` | Nonempty strings. |
| `recorded_at` | UTC `yyyy-mm-ddTHH:MM:SSZ`. |
| `evidence_refs` | List of nonempty strings (may be empty); stored as text, never fetched. |

Fingerprints (canonical SHA-256: sorted object keys, integral floats written as
integers):

| Fingerprint | Hashes |
|---|---|
| `case_fingerprint` | The whole network dictionary, except `_meta.parsed_at` and `meta.provenance.parsed_at`. Not the input file hash. |
| `analysis_fingerprint` | `spatial-cleanup-review/v1`, `spatial-review-priority/v2` and the whole `[spatial]` section. |
| `evidence_fingerprint` | The item's identity, code, check, evidence, location, geometry, coverage, impact, priority, ranking reason, evidence class, subjects, assessment, coordinate evidence and interpretation evidence. |

Replay rules: the latest `recorded_at` per item wins; identical duplicates are
harmless; records for absent items are kept as unmatched; each replay starts from
`unreviewed`, so an empty ledger resets all dispositions. `decision_audit` holds
`records`, `invalid_records` (with `issues`), `unmatched_records`,
`n_invalid_records`, `n_unmatched_records` and `policy`. A review with duplicate
item IDs must be regenerated before replay.

## [Export bundle](@id spatial-review-export)

[`export_spatial_review(review, outdir; item_limit=20)`](@ref export_spatial_review)
writes:

| File | Contents |
|---|---|
| `review.md` | [`render_spatial_review`](@ref) output: coverage banner, category and disposition counts, candidate index, attention items grouped by location, expandable context and reviewed inventories. |
| `review.json` | The complete captured queue (or the replayed copy). |
| `review.geojson` | [`spatial_review_geojson`](@ref) output. |
| `decisions-template.json` | Empty ledger envelope; an existing file is preserved. |

Other files are replaced. `item_limit` (nonnegative integer) caps each of the
attention, context and reviewed sections separately in Markdown; it does not
change the captured queue. `render(report, "report.md")` includes the same
section with a cap of 20.

`spatial_review_geojson` returns a `FeatureCollection` of WGS84 `MultiPoint`
features, one per located item, with `review_schema_version`, `queue_complete`,
`scope`, `coordinate_context` and `n_items_without_wgs84_geometry`. Feature
properties carry the item's code, location, priority, ranking reason, impact,
subjects, review state, geometry basis and coverage, fingerprints, assessment and
evidence. Cartesian and unlocated items are omitted and counted.

Command-line example:

```sh
julia --project=. examples/spatial_cleanup_review.jl CASE.json OUTDIR [DECISIONS.json]
```

The JSON execution interface's `analyze_case` returns the unreviewed queue in
the report; disposition replay and GeoJSON export are Julia-only.

## Synthetic fixtures

| File | Demonstrates |
|---|---|
| `test/data/spatial_discrepancies.json` | Direct line beside a series path, shared geometry, repeated source interval, route ending near another bus. |
| `test/data/spatial_split_lengths.json` | Parent `physical_length_m` inherited by split child sections. |
| `test/data/spatial_review_calibration.json` | Expected review categories and priorities. |
| `test/data/spatial_shared_infrastructure.json` | Shared MV/LV infrastructure classification. |
