# SAPN structural case study: four preliminary public-data models

Date: 2026-09-27. This is static analysis of pinned BMOPF model files in
`../energex-network-model/artifacts/inspection-exports`. These are structural
trials, not as-operated SAPN networks or OPF benchmarks. No power flow or OPF
was solved. The reproducible runner and full Markdown/JSON reports are in
`output/scratch/sapn-case-analysis/` (local scratch output).

| Case and pinned input SHA-256 | Buses | Lines | Transformers | Loads | Cycles (simple + parallel) | Transformer-mediated cycles | Parallel line groups | Warnings |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Ascot Park v3, `27a82ee9b691c2c879628d6ae3e11dad19c794992b562b8e1193735469d61d98` | 5,135 | 5,254 | 252 | 252 | 372 (351 + 21) | 223 | 19 | 21 |
| Campbelltown coverage-preserved v2, `0c7324c7fd2a4833f122a3fdb2f9917d6f7e658cfa693bf1778a8ef657152664` | 27,455 | 28,019 | 223 | 223 | 788 (577 + 211) | 0 | 204 | 21 |
| Monarto Central all-crossings, `7dfccb23ae015d8a73ee06f1c20beca7b3d4298b1756d23bfcd2aa5d9599049e` | 261 | 247 | 56 | 56 | 43 (43 + 0) | 39 | 0 | 6 |
| Happy Valley coverage-first v2, `cb45fa67eca6a940b7d68853015ee5b0e557340528f35663b61ca2792fcaa138` | 20,547 | 20,544 | 468 | 0 | 466 (337 + 129) | 0 | 127 | 17 |

All four reports have zero `ERROR` Findings. Each model has two nominal voltage
tiers, one declared voltage source, and zero declared switches. Cycle counts
describe the supplied graph; they do not prove that these are energized loops.
Happy Valley also has an external `open-points.jsonl` ledger of 174 structural
cuts. Every entry says `observed_open_point=false` and
`selection_status=non_evidentiary_coverage_first_imputation`, so those cuts
do not establish an as-operated switch state. Likewise, a
parallel bus pair is not automatically a duplicate line: all 19 Ascot and 204
Campbelltown groups have differing declared fields, while Happy Valley has
126 differing-field groups and one same-field group. Inspect each group and
its source lineage before proposing an edit.

## Unexpected features and review leads

1. **Transformer topology differs sharply by case.** Ascot Park has 30
   galvanic zones, nine incident to more than one isolating transformer, and
   223 transformer-mediated cycles. Monarto Central has 18 zones, ten with
   multiple transformer incidence, and 39 transformer-mediated cycles. The
   Campbelltown and Happy Valley counts are zero transformer-mediated cycles
   despite larger line-graph cycle ranks. The preliminary transformer
   projection, LV attachment and zone partition deserve comparison with raw
   topology before interpreting this as installed meshing.
2. **The nominal transformer-load estimate is inapplicable on many loops.**
   With an alternate path around a transformer, 231/252 Ascot and 48/56
   Monarto loading estimates are upper bounds; all of those upper bounds
   exceed 90%. They are not overload evidence. Three cases have one synthetic
   balanced load per transformer, declared at 20% of nameplate with
   `not_customer_sites=true`; Happy Valley emits no loads. Accordingly,
   `W.DIV.LOAD_SYMMETRIC` in the first three and the 1,407
   `I.OPS.UNLOADED_PHASE` records in Happy Valley describe modeling scope.
3. **Coordinates are complete but the source models omit their CRS.** Every
   bus has `longitude` and `latitude`, with values plausible for South
   Australia. None of the four networks declares a CRS, and no line has a
   route polyline. BMOPFTools therefore reports `unspecified` CRS and leaves
   geodesic line/transformer checks inapplicable. Field names and plausible
   ranges alone do not establish WGS84; coordinates could be unspecified x/y.
   The follow-up below finds stronger WGS84 lineage in the acquisition code
   and raw geometries, but that evidence has not yet been recorded in the
   source BMOPF metadata. Do not reinterpret the original null comparisons as
   passes.
4. **The longest LV line records can be generated segments.** Campbelltown's
   `hh121e::sapn_lv_overhead_330349_656_1__men_2` is 250 m, 3.46 times its
   tier's 99th-percentile length. Its `neutral_build_parent` declares
   chainage 84.818–334.818 m. Happy Valley's
   `sapn:happy-valley:lv-line:2b685c951a7fc7137893__men_2` is also 250 m,
   2.60 times the tier's 99th percentile; the parent route is recorded as
   350.543 m and this segment as chainage 19.030–269.030 m. These are
   segmentation artefacts, not evidence of an anomalously long physical span.
   A useful next metric would compare the complete parent route with the raw
   geometry, while keeping generated segments out of ordinary span outlier
   rankings.
5. **A different long-line candidate remains.** Happy Valley's MV overhead
   `sapn:happy-valley:hv-line:6b06a5363908bd792868` is 1,190.921 m,
   2.74 times the MV 99th percentile. Ascot Park's longest MV underground
   record, `sm172e::sapn_hv_underground_1206_102_1`, is 393.882 m,
   1.90 times its MV 99th percentile. Without route geometry in the BMOPF
   inputs, these are review leads, not data-error Findings. Match their raw
   object IDs and geometry before deciding whether the recorded length is
   plausible.
6. **Parameters and provenance need work before OPF use.** Every case lacks
   line current limits (`W.OPS.LINE_UNCONSTRAINED` and
   `W.PROV.I_MAX_ABSENT`). The 15 Ascot, 14 Campbelltown and 13 Happy Valley
   `W.DOM.LINE_LOW_IMPEDANCE` records merit source-level review; some
   Campbelltown examples are named `sapn:attachment-retrofit:mv-lead:*`,
   while some Happy Valley examples are short neutral-route segments. The
   per-line `meta` field also carries raw layer, feeder, phase origin and
   parent segmentation, but is reported by `I.SCHEMA.UNKNOWN_FIELDS` because
   it is outside the current BMOPF component schema. Losing this lineage
   would make these diagnostics harder to interpret.

## Raw geometry cross-match follow-up

`output/scratch/sapn-case-analysis/cross_match.py` verifies the pinned model
hashes and the frozen raw-file receipt or manifest hashes, then joins model
lineage to source GeoJSON using layer, feeder, public object ID and G3E FID
where available. Object ID alone is unsafe: Campbelltown's combined historical
and current layers can reuse an ID for different feeders. The backfill
manifest says those historical features were once published; it does not
establish that they remain installed or energized. The evidence is in
`cross_match.json`. Happy Valley's manifest pins the current
`../energex-network-model/scripts/acquire_zone_context.py` producer, which
requests `outSR=4326`; selected route endpoints match model bus coordinates.
The older Ascot Park and Campbelltown manifests pin different producer hashes
which have not been independently rechecked, although their frozen GeoJSON
coordinates also match selected model endpoints. This supports a WGS84
interpretation of the inspected buses, subject to review before promoting a
CRS declaration in each source model.

| Source length attribute / GeoJSON polyline ground distance | Ascot Park | Campbelltown | Happy Valley |
|---|---:|---:|---:|
| Median over frozen raw HV overhead features longer than 1 m | 1.0008 | 1.2204 | 1.2231 |
| Median over frozen raw LV overhead features longer than 1 m | 1.0013 | 1.2204 | 1.2230 |

The ratio is consistent with Ascot Park's projected source layer in EPSG:7854
and Campbelltown/Happy Valley source layers in Web Mercator (EPSG:3857).
Thus a raw `Shape__Length` or `st_length(shape)` field is approximately 22%
larger than the local ground distance in the latter two datasets. Do not copy
that source attribute into BMOPF as metres without checking its CRS. The
Happy Valley 1,190.921 m MV candidate matches `hv-overhead:74189`: its raw
stored length is 1,459.972 m but its 13-vertex WGS84 polyline measures about
1,193.235 m by haversine summation. The model length is consistent with the
ground route and is a long section rather than a detected unit error. Ascot
Park's 393.882 m MV underground candidate matches raw object 1206: the
12-vertex route measures about 393.504 m, with a 290.927 m endpoint chord.

The parallel-group cross-match found all raw members for 19/19 Ascot Park,
200/204 Campbelltown and 127/127 Happy Valley groups. Distinct source object
IDs do not prove distinct physical circuits. One Happy Valley group has
**identical full raw geometry** for public objects `lv-overhead:18632` and
`lv-overhead:67161` (different G3E FIDs 10671084 and 10671086); the model
also gives both 67.358 m lines the same endpoints and declared electrical
fields. This is a high-priority duplicate-versus-parallel-circuit review
candidate, not an automatic deletion. Both raw features are exported in
`output/scratch/sapn-case-analysis/parallel_exact_geometry_witness.geojson`.
Other short groups can be partial raw
overlaps: Ascot Park's objects 1396/1423 and Campbelltown's 164967/271394
share a short endpoint segment while one raw feature continues much farther.

The explicit-neutral builder records
`coordinate_basis=endpoint_chord_fallback_no_route_geometry` when it has no
route polyline: it places inferred neutral buses along a straight endpoint
chord while preserving electrical chainage along the parent. Comparing those
generated positions to the frozen raw parent geometry gives:

| Case | Matched inferred nodes | More than 5 m from route | More than 10 m | Maximum gap |
|---|---:|---:|---:|---:|
| Ascot Park | 255/255 | 3 | 0 | 6.8 m |
| Campbelltown | 1,358/1,366 | 51 | 9 | 33.1 m |
| Happy Valley | 834/834 | 99 | 46 | 76.4 m |

Eight Campbelltown nodes could not be matched to the selected frozen raw
layers and are excluded from the gap counts. For example, Happy Valley
`men_route_ca70f6c45fe4b9af84b8` sits 76.4 m from raw overhead object
28226, and Campbelltown `men_route_1569dbe06e64e90bc4b5` sits 33.1 m from
raw overhead object 506600. These are **visual placement artefacts of inferred
nodes**, not evidence that installed neutral grounds are misplaced. The
builder's route-aware branch can avoid this chord fallback if source geometry
is carried into the model with verified orientation and chainage. The largest
witness from each case is exported as raw route, endpoint chord and inferred
node in `output/scratch/sapn-case-analysis/route_offset_witnesses.geojson`.

A separate `derived-wgs84` scratch run inserted `EPSG:4326` into in-memory
metadata only, leaving the source files untouched. Across the Ascot Park,
Campbelltown and Happy Valley models it compared all 53,817 line lengths with
endpoint chords and raised no `W.GEO.*` Findings. This tests the chord lower
bound under an analyst CRS assumption; it does not test route-to-bus snapping,
because the BMOPF files contain no routes. The derived transformer separation
distribution exposes a different review lead: seven Ascot Park inferred
transformers span more than 10 m, with a maximum of 47.6 m, while the other
two cases have nearly colocated winding buses. Ascot Park's transformer
metadata explicitly records `asset_origin=inferred_missing_public_transformer`
and a `lead_length_m` close to each span (47.5 m for the maximum). Review
whether the inferred lead should be represented separately from the
transformer before treating those spans as installed asset locations.

## Analyzer corrections prompted by these cases

The first run produced spurious transformer Findings. For delta–wye
transformers, the parsed leakage fields are on winding-local ohmic bases.
The former low-impedance check divided secondary leakage ohms by the primary
base, falsely reporting normal leakage as near zero and exposing the opt-in
impedance snap fix to the same mistake. The check and fix now use the
winding-local per-unit conversion. The orientation check now withholds
source-hop reversal warnings when an alternate transformer path joins the
terminals. The operational overload Finding now requires that removing the
transformer separate its downstream load region; otherwise the result is
marked `upper_bound`. Small regression fixtures cover each correction. The
table above uses the corrected run, not the misleading initial warning totals.

## Suggested next investigation

Record the verified CRS and route lineage in reviewed case metadata, then
carry source route geometry through neutral splitting so inferred node
positions follow the route. Review the exact-geometry Happy Valley pair and
the short partial overlaps against source asset records. Separately, compare
the multi-transformer LV zones with observed open-point evidence. Keep
inferred/placeholder elements distinct from raw records.
Only after these structural questions and thermal/demand inputs are resolved
should these trial models be evaluated as OPF benchmarks.
