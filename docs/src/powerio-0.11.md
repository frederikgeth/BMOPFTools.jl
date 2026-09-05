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
