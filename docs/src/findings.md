# Finding-code reference

The complete catalogue of the 88 finding codes, grouped by family. Codes are
**stable identifiers** — filter on `f.code`, never on message text. Severity
prefix: `E.` error, `W.` warning, `I.` info (see
[Analysis & reports](analysis.md) for the severity semantics).

## COMP — completeness

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.COMP.MISSING_REQUIRED` | E | A component lacks a field the data model marks required (incl. the seven transformer required fields per subtype). The case cannot be instantiated as an OPF without it. |

## SCHEMA — unknown fields & metadata validation

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.SCHEMA.UNKNOWN_FIELDS` | I | Fields present that the data model does not define (underscore-prefixed extension keys are exempt). Catalogued rather than rejected: they are either converter passthrough or schema-evolution candidates — but a spec-conformant consumer will ignore them, so nothing essential should live there. |
| `W.SCHEMA.META_SCHEMA_URI` | W | `meta.$schema` is present but does not look like an `https://` URI. The field is intended to point to the versioned BMOPF JSON Schema document. |
| `W.SCHEMA.META_DATE_FORMAT` | W | `meta.created` or `meta.modified` is not a recognisable ISO 8601 datetime string (expected `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SSZ`). |
| `I.SCHEMA.META_LICENSE_URI` | I | `meta.license` is a long string that does not look like a URI. Short SPDX identifiers (e.g. `CC-BY-4.0`) are fine; longer values should be a `https://` URI pointing to the licence text. |
| `W.SCHEMA.META_ORCID_FORMAT` | W | An entry in `meta.authors` has an `orcid` field that does not match the standard ORCID format `XXXX-XXXX-XXXX-XXXX`. |
| `W.SCHEMA.META_SOURCE_URL` | W | A `url` field in `meta.sources` is present but does not look like an `https://` URI. |

## CONN — connectivity & topology

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.CONN.DISCONNECTED` | E | More than one connected component (over lines, closed switches and transformers). Buses without a path to a source have no defined operating point. |
| `W.CONN.MESHED` | W | Physical branch count exceeds the spanning-forest count — cycles exist. Counted over *branch elements*, so electrically parallel lines are correctly detected as meshes. Not an error (the spec supports meshes) but radial-only methods will fail. |
| `W.CONN.DANGLING` | W | Degree-1 buses with no load, generator or shunt attached — dead ends that contribute variables and constraints but no physics; often conversion artifacts (e.g. switch far-ends). |

## VOLT — voltage levels

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.VOLT.LEVEL_MISMATCH` | E | BFS voltage propagation reaches a bus with two inconsistent nominal voltages (beyond 5 %). The network's transformer ratios and topology contradict each other. |
| `E.VOLT.LINE_CROSSING` | E | A line (not a transformer) connects buses assigned to different voltage levels. Only transformers may cross levels; this is almost always a wiring error in the data. |
| `W.VOLT.UNASSIGNED` | W | Buses unreachable from any voltage source during propagation — likely islanded; their nominal voltage is unknown. |
| `W.VOLT.XFMR_RATIO` | W | A transformer's `v_ref` turns ratio disagrees (>10 %) with the voltage ratio of the levels it actually connects — ratio and placement are inconsistent. |

## DIV — diversity & symmetry

Symmetries in data create symmetric optima and degrade NLP convergence
[ref. 2](methodology.md#refs); these findings flag suspiciously templated parameterisation.

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.DIV.LOAD_SYMMETRIC` | W | More than half of the loads share identical `(p_nom, q_nom)` tuples — copy-paste parameterisation; dispatch among them is interchangeable. |
| `I.DIV.LOAD_CV_LOW` | I | Load `p_nom` coefficient of variation < 0.05 across ≥3 loads — essentially uniform loading. |
| `I.DIV.LOAD_IMBALANCE` | I | A multi-phase load with >20 % spread between its phase setpoints — noteworthy unbalance (often intended; this is context, not criticism). |
| `I.DIV.LINE_SYMMETRIC` | I | ≥80 % of the lines sharing a linecode have lengths within ±10 % of the median — electrically near-identical sections. |
| `I.DIV.BUS_UNIFORM_VMIN` | I | Every bus that has `v_min` has the *same* value — no spatial differentiation of the lower voltage envelope. |
| `I.DIV.BUS_UNIFORM_VMAX` | I | Same for `v_max`. |

## OPS — operational loading

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.OPS.IMPORT_DEPENDENT` | W | Local generation capacity below 5 % of total load — the case is a pure import feeder; with only a slack source the dispatch problem is loss minimisation at best. |
| `W.OPS.XFMR_OVERLOADED` | W | Estimated downstream apparent load exceeds 90 % of a transformer's rating at nominal setpoints — little OPF headroom, or a rating entered on the wrong base (see the regulator/autotransformer discussion in [methodology](methodology.md)). |
| `W.OPS.LINE_UNCONSTRAINED` | W | Lines without any thermal limit (`i_max`/`s_max` on the line or its linecode) — the OPF will have no flow constraints there. |

## PRE — infeasibility pre-flight

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.PRE.VBOUND_CONFLICT` | E | A bus voltage bound pair with lower > upper (checked elementwise for all four flavours: `v`, `vpn`, `vpp`, `vsym`). The feasible set is empty before the solver starts. |
| `E.PRE.PBOUND_CONFLICT` | E | Generator `p_min > p_max` — infeasible by construction. |
| `E.PRE.QBOUND_CONFLICT` | E | Generator `q_min > q_max` — same. |
| `I.PRE.NO_VOLT_BOUNDS` | I | Buses with no voltage bounds at all — voltages are unconstrained there (spec semantics for absent optional bounds). |
| `I.PRE.SINGLE_SOURCE` | I | Exactly one voltage source. The spec *requires* this in the current version; operationally it is still a single point of failure worth knowing about. |

## DOM — domain plausibility

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.DOM.VMIN_NEGATIVE` | E | Negative `v_min` — magnitudes are nonnegative by definition. |
| `E.DOM.VMAX_NONPOSITIVE` | E | `v_max ≤ 0` — forces zero voltage; almost certainly a unit/typo error. |
| `E.DOM.NEGATIVE_VALUE` | E | Negative value in an inherently nonnegative field (length, diagonal resistance). |
| `W.DOM.LOAD_PF_LOW` | W | Load power factor below 0.70 — plausible but unusual for aggregated demand; often a P/Q unit mix-up. |
| `W.DOM.GEN_COST_NEGATIVE` | W | Negative generation cost — the optimizer will dispatch it to its bound; verify it is intended (e.g. must-run subsidy). |
| `W.DOM.GEN_COST_HIGH` | W | Cost above 10 \$/kWh — beyond any realistic tariff; suspect units. |
| `W.DOM.LC_ZERO_R` | W | Near-zero or negative self-resistance on **any** linecode diagonal — a superconducting conductor, usually a placeholder. |
| `W.DOM.XFMR_RATIO_OOB` | W | Direction-agnostic transformer step ratio `max(r, 1/r)` above 1000:1. Calibrated so standard distribution step-downs (e.g. 11 kV/433 V ≈ 25:1) do **not** flag. |
| `W.DOM.ZERO_LIMIT` | W | An `i_max`/`s_max` entry exactly 0. Read literally this forces zero flow; in source tools 0 usually means "no limit" — classic semantic abuse. Drop the field instead. |
| `W.DOM.ZERO_LENGTH` | W | A zero-length line — degenerate impedance; the spec's lossless switch object is the right model for such sections ([ref. 2](methodology.md#refs)). |
| `W.DOM.ANGLE_UNITS` | W | A source `v_angle` entry with magnitude > 2π — angles are radians in the data model; this is almost certainly degrees. |
| `I.DOM.NEGATIVE_LOAD` | I | Loads with negative `p_nom` — embedded generation hiding as negative load; skews adequacy statistics and dodges the generator model. |

## RED — redundancy

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.RED.ZERO_LOADS` | W | Loads with `p_nom = q_nom = 0` — electrically inert objects that still create variables/constraints. |
| `I.RED.ZERO_SHUNTS` | I | Shunts whose every G/B matrix entry is zero — same. |
| `I.RED.MERGEABLE_LINES` | I | Chains of series lines whose interior buses have line-degree 2 and **no** other attachment (loads, generators, shunts, switches, transformers all counted as blockers). Merging removes superfluous buses that slow solvers ([ref. 2](methodology.md#refs)). |
| `I.RED.UNUSED_LINECODES` | I | Linecodes never referenced by a line — a cable library shipped with the case; harmless, but distinguishes library data from network data. |
| `I.RED.DUPLICATE_LINECODES` | I | Groups of linecodes with identical `R/X_series_1_1` fingerprints (codes lacking impedance data are excluded — absence is not evidence of duplication). |

## PROV — provenance & conventions

The largest family; full derivations in the
[methodology notes](methodology.md).

### Impedance matrix structure

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.PROV.NONRECIPROCAL` | E | An impedance/admittance block (linecode R/X/G/B or bus-shunt G/B) is not symmetric — reciprocity is violated; passive RLC networks cannot do that. Catches, e.g., delta-bank admittances built from the incidence matrix instead of `Y·(M∆)ᵀM∆`. |
| `E.PROV.NONPASSIVE` | E | The R block has a negative eigenvalue — the line would generate power. PSD of R is invariant under Kron reduction (Schur complements of accretive matrices stay accretive), so this is always an error. |
| `W.PROV.X_NONINDUCTIVE` | W | Non-positive series self-reactance — series compensation does not exist inside linecodes; almost always a sign flip or X/B confusion. |
| `W.PROV.X_NOT_PSD` | W | The X block has a negative eigenvalue — the implied inductance matrix is not realisable (energy argument; also Kron-invariant via sectorial Schur closure). |
| `I.PROV.NEGATIVE_MUTUAL_R` | I | Negative off-diagonal resistance. Carson's earth-return term makes mutual R positive for geometry-derived matrices; a negative entry signals processed/fitted provenance. |
| `E.PROV.NEGATIVE_G` | E | A conductance block (line shunt or bus shunt) that is not PSD / has negative diagonals — an active element. |
| `W.PROV.B_SIGN` | W | A susceptance block that is not PSD or has negative diagonals — not a physical capacitance matrix. |
| `I.PROV.B_OFFDIAG` | I | Positive mutual susceptance with PSD intact — deviates from the Maxwell sign pattern. Clean electrostatic pipelines (including grounded-screen elimination and bundling) preserve the pattern, so this marks fitted/averaged provenance rather than an error. |

### Parameterisation provenance

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.PROV.SEQ_DERIVED` | I | Exactly balanced impedance matrices (equal self, equal mutual): constructed from sequence parameters (`r1,x1,r0,x0`) or a transposition assumption — not from conductor geometry. The implied Z₁/Z₀ are recovered and reported. |
| `I.PROV.DECOUPLED_PHASES` | I | Diagonal impedance matrices — positive-sequence-only data; the phases decouple into independent single-phase networks (maximal redundancy/symmetry). |

### Grounding & reduction conventions

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.PROV.KRON_LIKELY` | I | A 3-wire **LV** level (LV is physically 4-wire); the neutral was probably Kron-eliminated under an every-bus-grounded assumption. 3-wire MV is physical and never flags. |
| `I.PROV.KRON_REDUCIBLE` | I | A 4-wire network whose every neutral is perfectly grounded — Kron reduction would be exact, so the explicit neutrals are numerically redundant. |

### Impedance transformation type (3-wire LV only)

When a 3-wire LV network is detected, the structure of each linecode's R and X
blocks is compared against three known impedance-transformation signatures from
Geth, Heidari & Koirala (ACM e-Energy 2022, doi:[10.1145/3538637.3538844](https://doi.org/10.1145/3538637.3538844)):

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.PROV.IMPEDANCE_TRANSFORM_KR` | I | **Kron-reduced**: R and/or X off-diagonals are non-uniform (distinct matrix structure) and/or R_mutual/R_self ≪ 0.5. The neutral row/column was eliminated from the original Carson 4-wire matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate otherwise. Zero-sequence behaviour is not captured. |
| `I.PROV.IMPEDANCE_TRANSFORM_PN` | I | **Phase-to-neutral approximation**: R block is circulant (all diagonals equal, all off-diagonals equal) with mutual ≈ ½ self; X block retains the original geometric structure (off-diagonals vary). Neutral resistance has been folded into phase self-terms. Valid approximation for equal phase/neutral conductor resistance; error grows with grounding impedance. |
| `I.PROV.IMPEDANCE_TRANSFORM_MPN` | I | **Modified phase-to-neutral approximation**: both R and X blocks are circulant with mutual ≈ ½ self. X is further symmetrised relative to the standard phase-to-neutral form, introducing additional modelling error, particularly for asymmetric cable geometries. |
| `W.PROV.IMPLICIT_GROUNDING` | W | Neutral terminals exist and are referenced by components, but **no branch carries a neutral conductor** — the dataset uses the implicit "n = local ground" convention. Made explicit so 4-wire consumers don't misread it. |
| `E.PROV.FLOATING_NEUTRAL` | E | A neutral section (continuity graph over lines/closed switches) with no path to ground **and** loads/generators using it — the zero-sequence path is undefined; 4-wire analysis is ill-posed. |
| `W.PROV.FLOATING_NEUTRAL` | W | Same, but unused — latent rather than active. |

### OpenDSS default fingerprints

Values matching documented OpenDSS defaults indicate the source `.dss`
files likely **omitted** the field (see [methodology](methodology.md) for
the table).

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.PROV.DSS_DEFAULT_Z` | W | Recovered Z₁/Z₀ match the default line constants (r1=0.058, x1=0.1206, r0=0.1784, x0=0.4047 Ω/kft) — a fictitious 60 Hz overhead line in your data. |
| `W.PROV.DSS_DEFAULT_SOURCE_Z` | W | Source Thévenin Z₁ matches MVAsc3=2000 with X1R1=4 — the fault level was never specified; arguably the most consequential default of all. |
| `I.PROV.DSS_DEFAULT_AMPS` | I | `i_max` exactly 400 A (the `normamps` default; 600 A is excluded as a common genuine rating). |
| `I.PROV.DSS_DEFAULT_XFMR` | I | Transformer per-unit impedance equal to `xhl = 7 %` / `%r = 0.2` per winding. |
| `I.PROV.DSS_DEFAULT_PF` | I | Loads at power factor exactly 0.88 — reactive demand defaulted. |
| `I.PROV.DSS_DEFAULT_KV` | I | Components sitting exactly at 115 kV or 12.47 kV — US defaults, glaring outside US test feeders. |
| `I.PROV.DSS_DEFAULT_LENGTH` | I | A *minority* of lines with length exactly 1.0 among varied lengths. (Universal 1.0 is detected as a deliberate length-normalised convention and reported in the convention statement instead.) |

### Control devices

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.PROV.REGULATOR_PATTERN` | W | A transformer that looks like a voltage-regulator/autotransformer encoding: either both windings on one bus (the explicit EPRI autotransformer form) or a near-1:1 wye unit with same-level endpoints / very low impedance / non-unity tap. The data model has no regulator object — a control device has been frozen into a fixed branch. |

## INT — structural integrity

Motivated by the benchmark-pitfall catalogue of ([ref. 2](methodology.md#refs)).

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.INT.UNKNOWN_BUS` | E | A component references a bus id that does not exist. |
| `E.INT.UNKNOWN_LINECODE` | E | A line references a linecode that does not exist (distinct from *unused* linecodes). |
| `E.INT.UNKNOWN_TERMINAL` | E | A terminal-map entry is not a terminal of the referenced bus — typos, or attempts to connect nodal elements directly to ground (forbidden by spec Table 10). |
| `W.INT.DIM_MISMATCH` | W | Terminal-map arity vs linecode matrix size, `i_max` length vs conductor count, setpoint length vs configuration, source `vm`/`va` vs map length. |
| `W.INT.PADDED_MATRIX` | W | All-zero row/column pairs in linecode impedances — padded conductors demonstrably wreck NLP performance (22 → 590 Ipopt iterations in ([ref. 2](methodology.md#refs)) Table 3); shrink the matrix and use terminal maps. |
| `E.INT.NO_VOLTAGE_REFERENCE` | E | A galvanic island (transformer windings are separations) with no source, perfect grounding, or grounding shunt — voltages there are defined only up to a shift (the IEEE-123 "bus 610" rank deficiency ([ref. 2](methodology.md#refs))). A shunt counts only if its admittance has nonzero row sums, so a pure delta capacitor bank correctly does not anchor an island. |
| `W.INT.WYE_WITHOUT_NEUTRAL` | W | A wye-configured load/generator at a bus with no identifiable neutral — implies an undeclared ground return; in 3-wire sections only delta connections are expected. |
| `W.INT.LOW_IMPEDANCE_LINE` | W | Lines whose total series impedance is below 10⁻³× the network median — they degrade conditioning; the spec's lossless switch object is the intended model ([ref. 2](methodology.md#refs)). |
| `I.INT.UNIFORM_GEN_COST` | I | Groups of generators with identical cost vectors — any dispatch split among them is optimal (degeneracy); diversify costs for benchmark use. |

## SPEC — TF-spec conformance

Rules the JSON Schema cannot express.

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.SPEC.N_SOURCES` | W | Voltage-source count ≠ 1 (spec Eq. 17 requires exactly one in this version). |
| `W.SPEC.BAD_CONFIG` | W | A configuration string outside `SINGLE_PHASE`/`WYE`/`DELTA`. |
| `W.SPEC.CONFIG_ARITY` | W | Terminal-map arity inconsistent with the configuration (SINGLE_PHASE = 2, WYE = 4, DELTA = 3). |
| `I.SPEC.GEN_CONFIG_FUTURE` | I | Generator configurations marked future-support in the spec (only WYE is current). |
| `W.SPEC.XFMR_TMAP_ARITY` | W | Transformer terminal-map lengths off the per-subtype spec values — also the deliberate tripwire for unconverted wye-wye units. |
| `W.SPEC.TERMINAL_TYPES` | W | The source file used non-string terminal identifiers; they were coerced at parse (aliases or verbatim — the finding says which). |
| `I.SPEC.MATRIX_TRIANGULAR` | I | Impedance matrices stored upper-triangular; the spec defines full row-first storage. Read fine; normalise before publishing. |

## BENCH — benchmark readiness

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.BENCH.AUGMENTATION` | I | The case is not yet a non-trivial OPF benchmark; the message lists the concrete augmentation steps: no costed generation (degenerate objective), slack-only generation (trivial dispatch), absent voltage bounds, absent vpn/vsym bounds (which also aid solver robustness ([ref. 3](methodology.md#refs))), missing thermal limits. |
