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
