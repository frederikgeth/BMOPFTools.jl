> **Coordinate coverage:** 13 of 13 buses (100.0%) eligible for metric checks; **0 not eligible** for bus-distance checks.
>
> Frame: declared\_wgs84. Reported coordinate accuracy: 0 of 13 buses.
>
> Queue completeness covers applicable checks within search and capture limits. It does not cover excluded bus geometry or establish model correctness.

**Cleanup review:** assessed (completed_within_declared_scope); 6 captured items in 3 exact review locations. Queue complete within scope: true.

Reviewer dispositions are assertions with provenance, not validation or repairs. Resolved items remain visible. Unknown frames never become map coordinates.

- Coverage `route_defects`: inapplicable (no_routes); 0/0 observed candidates captured.
- Coverage `route_endpoints`: inapplicable (no_routes); 0/0 observed candidates captured.
- Coverage `route_overlaps`: inapplicable (no_routes); 0/0 observed candidates captured.
- Coverage `source_intervals`: inapplicable (no_explicit_source_intervals); 0/0 observed candidates captured.

- Disposition `confirmed_issue`: 1
- Disposition `unreviewed`: 5

Decision ledger: 0 invalid records; 0 unmatched records. Unmatched candidates are not assumed resolved.

Priority is an inspection order, not error probability. Impact counts refer only to identified subjects and directly attached loads.

| Automated evidence category | Captured observations |
| --- | ---: |
| context only | 2 |
| needs information | 0 |
| review candidate | 0 |
| data inconsistency | 4 |

These are observation counts, not error counts. Confirmed issues are recorded separately as reviewer dispositions. Context alone does not imply a required correction.

**Candidate index — 4 of 4 attention observations**

Links lead to the detailed entries below. The display limit applies to both the index and details; JSON retains all captured items. Row numbers are navigation aids, not stable identities.

| # | Priority | Category / code | Primary asset | Details |
| ---: | --- | --- | --- | --- |
| 1 | P3 | data inconsistency / R.LINE\_LENGTH\_CONTEXT | line:s10 | [View](#spatial-item-240ca9d6caaaa0ee48027adcae2daf5560c5c987cc81c9b891349bc0c36edd33) |
| 2 | P3 | data inconsistency / R.LINE\_LENGTH\_CONTEXT | line:s07 | [View](#spatial-item-7b9485d3be11600cabdfaeaf5143195ef8d72ffe885ac338c6f90623184bc0c9) |
| 3 | P3 | data inconsistency / R.LINE\_LENGTH\_CONTEXT | line:s11 | [View](#spatial-item-d910c8b0a5ab3d90fa3193a9e9dd0bd5ff1dc326637b474e86138c62d5e7f6c7) |
| 4 | P3 | data inconsistency / R.LINE\_LENGTH\_CONTEXT | line:s03 | [View](#spatial-item-08eea59a6010fd818f87afab81425180e7f98d6f0de438bd68a91a4bf34361e4) |

**Needs inspection or information**


**Review location: 0.0, 0.0 degrees in geographic:GDA2020**

<a id="spatial-item-240ca9d6caaaa0ee48027adcae2daf5560c5c987cc81c9b891349bc0c36edd33"></a>

- **data inconsistency · P3** — A length declaration is invalid, below its applicable endpoint bound, or several times above it.

  Subjects: line:s10, bus:p09, bus:p10.

  Evidence: declared length m: 52.0; physical length m: unavailable; chord m: 1.5817820441272965e7; stored route length m: unavailable; recomputed route length m: unavailable.

  Interpretation: The declared values conflict with supported length semantics or geometry.

  Uncertainty: The responsible field is unresolved; accuracy and provenance still matter.

  Inspect: Compare physical versus electrical length, units, coordinate accuracy and source records.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p09: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p10: provenance unspecified; reported accuracy unavailable m.

  Review: unreviewed (unreviewed). Directly attached loads: 2. Code: `R.LINE_LENGTH_CONTEXT`. ID: `review-134f12ac077aa332a09834a4308a50bbac1a8e7a2109f4cff086b651c8f9c831`.

<a id="spatial-item-d910c8b0a5ab3d90fa3193a9e9dd0bd5ff1dc326637b474e86138c62d5e7f6c7"></a>

- **data inconsistency · P3** — A length declaration is invalid, below its applicable endpoint bound, or several times above it.

  Subjects: line:s11, bus:p10, bus:p11.

  Evidence: declared length m: 52.0; physical length m: unavailable; chord m: 1.5817894538137954e7; stored route length m: unavailable; recomputed route length m: unavailable.

  Interpretation: The declared values conflict with supported length semantics or geometry.

  Uncertainty: The responsible field is unresolved; accuracy and provenance still matter.

  Inspect: Compare physical versus electrical length, units, coordinate accuracy and source records.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p10: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p11: provenance unspecified; reported accuracy unavailable m.

  Review: unreviewed (unreviewed). Directly attached loads: 2. Code: `R.LINE_LENGTH_CONTEXT`. ID: `review-b8518be2dc7964f53b90a69cdb717b1b9f5057cb9ebdcba8e6d28a5aec0557d1`.


**Review location: 153.02304080641179, -27.47 degrees in geographic:GDA2020**

<a id="spatial-item-7b9485d3be11600cabdfaeaf5143195ef8d72ffe885ac338c6f90623184bc0c9"></a>

- **data inconsistency · P3** — A length declaration is invalid, below its applicable endpoint bound, or several times above it.

  Subjects: line:s07, bus:p06, bus:p07.

  Evidence: declared length m: 520.0; physical length m: unavailable; chord m: 50.000036076446264; stored route length m: unavailable; recomputed route length m: unavailable.

  Interpretation: The declared values conflict with supported length semantics or geometry.

  Uncertainty: The responsible field is unresolved; accuracy and provenance still matter.

  Inspect: Compare physical versus electrical length, units, coordinate accuracy and source records.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p06: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p07: provenance unspecified; reported accuracy unavailable m.

  Review: confirmed\_issue (recorded). Directly attached loads: 2. Code: `R.LINE_LENGTH_CONTEXT`. ID: `review-2021221d763169f8c319463f1a8d088d43c1414aba84a708de316a8281cbe96c`.

  Reviewer: j.doe at 2026-11-26T03:00:00Z. Rationale: Length 520 m is a typing error; drawing sheet 14 gives 52 m..


**Review location: 153.02101360213726, -27.47 degrees in geographic:GDA2020**

<a id="spatial-item-08eea59a6010fd818f87afab81425180e7f98d6f0de438bd68a91a4bf34361e4"></a>

- **data inconsistency · P3** — A length declaration is invalid, below its applicable endpoint bound, or several times above it.

  Subjects: line:s03, bus:p02, bus:p03.

  Evidence: declared length m: 0.052; physical length m: unavailable; chord m: 50.00003607895657; stored route length m: unavailable; recomputed route length m: unavailable.

  Interpretation: The declared values conflict with supported length semantics or geometry.

  Uncertainty: The responsible field is unresolved; accuracy and provenance still matter.

  Inspect: Compare physical versus electrical length, units, coordinate accuracy and source records.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p02: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p03: provenance unspecified; reported accuracy unavailable m.

  Review: unreviewed (unreviewed). Directly attached loads: 2. Code: `R.LINE_LENGTH_CONTEXT`. ID: `review-fb15500cbee7d2914bcfc3e2282163023f79737efa2865aa8d984a6f40579859`.


Showing 4 of 4 attention observations; JSON retains all captured items.

<details>
<summary>Contextual observations — overlap alone is not an issue</summary>


**Review location: 0.0, 0.0 degrees in geographic:GDA2020**

<a id="spatial-item-77cbb27931e248358a5faab32085cb5b0014332c34916fb0a6637130bdf9621f"></a>

- **context only · P1** — A span exceeds the configured absolute review threshold.

  Subjects: line:s11, bus:p10, bus:p11.

  Interpretation: The threshold provides context; it is not an engineering limit.

  Uncertainty: A long span alone is not evidence of incorrect length or connectivity.

  Inspect: Compare geographic extent and source routing if unexpected for this case.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p10: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p11: provenance unspecified; reported accuracy unavailable m.

  Review: unreviewed (unreviewed). Directly attached loads: 2. Code: `S.LONG_BRANCH_SPAN`. ID: `review-2dcded4f8e42258d9d4ae5089259781f5541fff987b3225c92523cb87e2af490`.

<a id="spatial-item-ce0a1a59030c0a98679ce156cb59e5af10ad0879e1b4110e6101b121aeaabb1a"></a>

- **context only · P1** — A span exceeds the configured absolute review threshold.

  Subjects: line:s10, bus:p09, bus:p10.

  Interpretation: The threshold provides context; it is not an engineering limit.

  Uncertainty: A long span alone is not evidence of incorrect length or connectivity.

  Inspect: Compare geographic extent and source routing if unexpected for this case.

  Geometry basis: eligible\_referenced\_bus\_locations; 2/2 identified buses located; subject list complete: true.

  Coordinates for p09: provenance unspecified; reported accuracy unavailable m.

  Coordinates for p10: provenance unspecified; reported accuracy unavailable m.

  Review: unreviewed (unreviewed). Directly attached loads: 2. Code: `S.LONG_BRANCH_SPAN`. ID: `review-f12f8810d39ffaac3005822fa934c17c33a80950ced43ba5eb615e589dc309b9`.


Showing 2 of 2 context observations; JSON retains all captured items.

</details>

