# PowerIO 0.11 integration

OpenDSS intake uses `PowerIO.parse` and a typed `PioModule{MulticonductorNetwork}`.
Conversion selects `bmopf-json@0.1.0` explicitly. This retains the numerical
consumer's declared profile while PowerIO 0.11 also offers a separately pinned
0.2.0 proposal. Extended transformers and controls move through the documented
`extras` relocation contract with diagnostics. Whole regulator and n-winding
tables are restored for the existing component-specific applicability checks.
Task Force ratification is independent of PowerIO publication.

The conversion audit obtains source-only metadata from PowerIO IR generation 2.
This is an explicit serialization operation at intake; ordinary typed inspection
does not decode a network JSON payload. Diagnostic codes and severities come
from the structured PowerIO records. Missing metadata and unclassified findings
retain the existing incomplete-audit status.

The numerical transformer adapter continues to state its own winding-side
admittance convention. A successful parse or conversion does not certify that
all equipment is supported by a selected solver; numerical validation and the
existing applicability checks remain necessary.

Aggregated `EMIT.BMOPF.FIELD_DROPPED` diagnostics identify their field and
source elements through `details`. The audit reads that structured list,
keeps the full records in `_meta.powerio_diagnostic_details`, and records
unattributed elements when an upstream list is truncated. Reader diagnostics
remain separate from writer field mappings; a complete field mapping does not
certify a clean source parse. Both records survive BMOPF JSON export.

## Explicit core-shunt locations

PowerIO's proposed `no_load_shunt` object keeps the exciting branch on its
physical winding and gives the admittance per coil. The 0.1.0 output profile
retains that object under `extras.transformer`. Intake restores it, creates
an equivalent ordinary bus shunt with the same coil incidence, and records
the source object and generated shunt ID in `_meta.explicit_transformer_core_shunts`.
This conversion does not move the branch across transformer leakage. It also
prevents the OpenDSS percentage normalization from adding a second core branch.

The package continues to reject unknown declared schema retrieval URLs. This
compatibility path supports explicitly converted PowerIO 0.11 data and does
not claim acceptance of every field in a BMOPF 0.2.0 proposal snapshot.

Materialized core shunts remain attached to their owning transformer in the
operating-point loss ledger. Transformer loss objectives and reports include
their active and reactive power; the network power balance counts them once.
Neutral terminals appear last in the generated shunt map, with the admittance
matrix permuted to preserve its physical connections.

## Supported behavior and remaining limits

| Operation or field | Package behavior | Evidence and limit |
|---|---|---|
| Typed DSS parse → explicit BMOPF 0.1 profile | Accepted with source and writer diagnostics | Intake is separate from schema validity and solver applicability. |
| Exact unit n-winding `tap_ratio`, no competing bounds/control | Normalized to the implicit nominal ratio | Original value and winding index survive in migration notes; normalization is idempotent. |
| Non-unit n-winding tap or tap bounds | Retained and rejected at solver build | No tap optimization or approximate near-unit normalization. |
| Per-winding `s_rating` | Retained as nameplate metadata | It is not automatically interpreted as the supported `s_max`/`i_max` constraint. |
| Aggregate field diagnostics | Attributed by field and component class | Lists cap at 100 elements per field; missing identities remain unknown. |
| PowerIO `remark` / `note` | Reported as `INFO` | Error and warning severities remain distinct. |
| Explicit transformer core shunts | Preserved at intake and included once in the loss ledger | DSS export still loses some return connections and matrix entries; see the field-level loss ledger. |
| Native three-winding PF fixtures | Compared against OpenDSS | Named fixtures validate the implemented nominal domain. |
| Native four-winding DYYN fixture | All six reactance pairs and all 12 energized nodes agree with OpenDSS | The voltage comparison uses 2 V / 0.3%; the maximum LV error is 0.094 V. |

`W.MIGRATE.NWINDING_NOMINAL_TAP` describes representation normalization only.
It does not extend the two-winding adjustable-tap contract linked to PSK-000005,
or the fixed winding-convention contract linked to PSK-000006. Scientific
contract domains and stable identities remain those declared in the existing
package metadata and book.

The fixture suite checks field-level expected losses in
`test/data/roundtrip_expected_losses.json` as well as whole-case expected
failures. Fixes must update the specific expected loss and promote its
assertion; a different lost field cannot replace it unnoticed. Power-flow
comparisons require every energized source node, with an explicit mapping
when identities differ. An original solve that cannot converge is reported as
a skip, not numerical agreement. No tolerance is relaxed for this upgrade.

The standalone fidelity sweep uses its documented tighter tolerances; its
results must not be substituted for the regression suite's 2 V / 2% round-trip
gate. The separate four-winding import comparison uses 2 V / 0.3%. Parsing,
DSS round-trip fidelity, and BMOPFTools solver acceptance have separate tests.

## Reproducing prerelease validation

The integration was developed against PowerIO.jl
`d08f4510648b7307427b3ba95cfa463ae62ee381` and native PowerIO
`a84d97d97343b4175e9a846aa358997ff53b0e5f` (C ABI 7, including core-shunt preservation and complete OpenDSS `Xscarray` winding pairs). A development checkout
can use `Pkg.develop` in both the root and test environments, with `POWERIO_CAPI`
pointing to that native build. Recipe subprocesses use the root environment.
The same source override is needed when testing the docs, DiffOpt, and downstream
project environments before registration. These local overrides are not
committed package dependencies. Normal CI must resolve the coordinated released
packages and their native artifacts before the compatibility bump is merged.

The minimized `test/data/powerio_duplicate_new/Master.dss` fixture checks the
newly visible `PARSE.DSS.SOURCE_MALFORMED` code, the final SI linecode values,
and an independent OpenDSS comparison. The 100/101-element tests exercise the
actual writer, not only synthetic diagnostic records. Full diagnostic records,
including any upstream source spans, survive BMOPF JSON serialization.

## Validation evidence at the 0.11 release

The coordinated prerelease revisions above were checked with Julia 1.12.5.
The full package suite, scientific-contract/JSON execution gates, generated
registry/export checks, docs build, DiffOpt tests, and downstream extension
tests pass locally. The full suite passes 9,087 checks and retains 30 expected failures and three
explicit skips: 30 lossy feature round trips, the non-convergent original
open-delta deck, and two pre-existing network-limit test scaffolds.

| Check | Result | Interpretation |
|---|---|---|
| 35 feature cases, semantic round trip | 5 clean; 30 with recorded differences | 263 exact path/kind differences are checked; the two four-winding reactance discrepancies are resolved. |
| Same cases, regression PF gate (2 V / 2%) | 34 match; 1 source solve skipped | Every energized reference node is covered, including explicitly mapped fixture returns. |
| Same cases, stricter standalone PF sweep | 26 match; 8 differ; 1 source solve skipped | No whole-case expected failure is promoted on this evidence. |
| 7 representative real feeders, standalone sweep | 1 matches; 6 do not establish agreement | Two regenerated decks do not converge; SWER has three unmatched source node identities. Other failures exceed the tighter tolerance. |

The standalone sweep is reproduced with
`julia --project=test --startup-file=no scripts/roundtrip_fidelity.jl --out /tmp/roundtrip-fidelity`
under the same dependency overrides. Its reports include missing node identities
as well as voltage errors. Imported SWER solver agreement and DSS re-export
coverage are different checks: the former passes while the latter still needs
an explicit reviewed node correspondence. None of these results expands a
scientific contract's declared domain.

## Follow-up issue regressions

The release table above records the 35-case baseline at PR #385. The current
corpus adds `pf_3wdg_unequal_kva.dss`: 36 cases, five structurally clean,
31 with recorded differences, and 264 exact path/kind differences. The new
case passes the coarse DSS round-trip voltage check but exposes a separate
import primitive-admittance discrepancy against OpenDSS.

- **#163:** the LV1 bus and transformer terminal maps and earth-routing evidence
  are retained through BMOPF JSON serialization.
- **#381:** unresolved geometry is rejected with
  `BUILD.DIST.ELECTRICAL_INCOMPLETE`, including after source IR serialization;
  explicit four-conductor linecodes import successfully. Faithful geometry
  import remains unsupported, as documented in the conversion guide.
- **#356 remains open:** the issue's requested own-kVA scalar value does not
  match OpenDSS's primitive admittance. Two unequal-rating resistance checks
  and one primitive-admittance check document the unresolved discrepancy.
  The equal-rating boundary and JSON preservation checks pass.
