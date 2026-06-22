# Finding-code reference

The complete catalogue of finding codes, grouped by family. Codes are
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
| `E.SCHEMA.REQUIRED` | E | JSON Schema validation: a required field is missing at the reported path. |
| `E.SCHEMA.TYPE` | E | JSON Schema validation: a field has the wrong JSON type (e.g. string where a number is expected) at the reported path. |
| `E.SCHEMA.ENUM` | E | JSON Schema validation: a value is not among the allowed enumerated values. |
| `E.SCHEMA.RANGE` | E | JSON Schema validation: a numeric value violates a minimum/maximum (or exclusive-bound) range constraint. |
| `I.SCHEMA.OTHER` | I | JSON Schema validation: a schema violation not covered by the specific codes above (catch-all, carrying the raw reason and path). |
| `I.SCHEMA.VERSION_UNKNOWN` | I | The declared spec version has no bundled JSON Schema document, so structural schema validation was skipped for this case. |
| `W.SCHEMA.META_SCHEMA_URI` | W | `meta.$schema` is present but does not look like an `https://` URI. The field is intended to point to the versioned BMOPF JSON Schema document. |
| `W.SCHEMA.META_DATE_FORMAT` | W | `meta.created` or `meta.modified` is not a recognisable ISO 8601 datetime string (expected `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SSZ`). |
| `I.SCHEMA.META_LICENSE_URI` | I | `meta.license` is a long string that does not look like a URI. Short SPDX identifiers (e.g. `CC-BY-4.0`) are fine; longer values should be a `https://` URI pointing to the licence text. |
| `W.SCHEMA.META_ORCID_FORMAT` | W | An entry in `meta.authors` has an `orcid` field that does not match the standard ORCID format `XXXX-XXXX-XXXX-XXXX`. |
| `W.SCHEMA.META_SOURCE_URL` | W | A `url` field in `meta.sources` is present but does not look like an `https://` URI. |

## CONN — connectivity & topology

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.CONN.DISCONNECTED` | E | More than one connected component (over lines, closed switches and transformers). Buses without a path to a source have no defined operating point. |
| `E.CONN.SELF_LOOP` | E | A line, switch, or transformer has identical `bus_from` and `bus_to` — a zero-length branch that creates a degenerate KVL constraint and is almost always a wiring error. |
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
| `I.DIV.LOAD_PF_DSS_DEFAULT` | I | Load power factor mean is within 1 % of 0.88 with CV < 0.05 — strongly suggests reactive power was never explicitly set and the OpenDSS default PF was inherited throughout. Compare with `I.PROV.DSS_DEFAULT_PF`, which detects the exact 0.88 value per load; this finding detects the statistical signature across all loads. |
| `I.DIV.LOAD_IMBALANCE` | I | A multi-phase load with >20 % spread between its phase setpoints — noteworthy unbalance (often intended; this is context, not criticism). |
| `I.DIV.LOAD_PHASE_BALANCED` | I | Aggregate load across all phase terminals in a galvanic zone is balanced within 2 % (max − min spread relative to max). The network is effectively balanced and a single-phase equivalent model would suffice; the unbalanced OPF formulation adds no value here. |
| `I.DIV.LOAD_UNIFORM_MODEL` | I | Across ≥3 loads, every load uses the *same* load model. When that model is `constant_power` (the default), no load exercises voltage dependence (ZIP/exponential) — the case does not test voltage-dependent load behaviour. Observational coverage signal, not a defect. |
| `I.DIV.LOAD_UNIFORM_CONFIG` | I | Across ≥3 loads, every load shares the *same* `configuration` (e.g. all WYE) — no connection diversity. Observational; uniform connection is common and often legitimate. |
| `I.DIV.LINE_SYMMETRIC` | I | ≥80 % of the lines sharing a linecode have lengths within ±10 % of the median — electrically near-identical sections. |
| `I.DIV.BUS_UNIFORM_VMIN` | I | Every bus that has `v_min` has the *same* value — no spatial differentiation of the lower voltage envelope. |
| `I.DIV.BUS_UNIFORM_VMAX` | I | Same for `v_max`. |

## OPS — operational loading

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.OPS.IMPORT_DEPENDENT` | W | Local generation capacity below 5 % of total load — the case is a pure import feeder; with only a slack source the dispatch problem is loss minimisation at best. |
| `W.OPS.XFMR_OVERLOADED` | W | Estimated downstream apparent load exceeds 90 % of a transformer's rating at nominal setpoints — little OPF headroom, or a rating entered on the wrong base (see the regulator/autotransformer discussion in [methodology](methodology.md)). |
| `W.OPS.LINE_UNCONSTRAINED` | W | Lines without any thermal limit (`i_max`/`s_max` on the line or its linecode) — the OPF will have no flow constraints there. |
| `I.OPS.UNLOADED_PHASE` | I | A phase terminal is present on buses in a galvanic zone (connected via lines and closed switches; transformers are boundaries) but no load connects to it anywhere in that zone. Reported per zone and per terminal. Common in partial-phase feeders; worth reviewing before interpreting unbalance results. |

## PRE — infeasibility pre-flight

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.PRE.VBOUND_CONFLICT` | E | A bus voltage bound pair with lower > upper (checked elementwise for all four flavours: `v`, `vpn`, `vpp`, `vpos`). The feasible set is empty before the solver starts. |
| `E.PRE.PBOUND_CONFLICT` | E | Generator `p_min > p_max` — infeasible by construction. |
| `E.PRE.QBOUND_CONFLICT` | E | Generator `q_min > q_max` — same. |
| `I.PRE.NO_VOLT_BOUNDS` | I | Buses with no voltage bounds at all — voltages are unconstrained there (spec semantics for absent optional bounds). |
| `I.PRE.SINGLE_SOURCE` | I | Exactly one voltage source. The spec *requires* this in the current version; operationally it is still a single point of failure worth knowing about. |
| `W.PRE.SOURCE_VOLTAGE_OOB` | W | A voltage source setpoint (`v_magnitude`) falls outside the bus's declared `v_min`/`v_max`. The source pins that voltage as a hard equality in the OPF, so the bound is trivially violated before the solver starts — a guaranteed infeasibility. Common cause: `v_magnitude` set in kV while bounds are in V, or an augmented bound tighter than the actual supply voltage. |
| `W.PRE.SOURCE_BUS_GENERATOR` | W | A generator without `p_max`/`q_max` sits at a voltage-source bus. The voltage source is itself the network's current slack, so two unbounded current injections share one fixed-voltage bus — the dispatch split is degenerate (non-unique). Remove the generator and express its role as flow bounds/cost on the voltage source instead. |
| `I.PRE.SOURCE_BUS_GENERATOR` | I | A *bounded* generator sits at a voltage-source bus. Well-posed (the generator is bounded, the source takes the remainder), but if its bounds/cost are meant to limit or price grid import, set them on the voltage source (`p_min`/`p_max`/`q_min`/`q_max`/`cost`) instead. |

## DOM — domain plausibility

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.DOM.VMIN_NEGATIVE` | E | A negative per-phase entry in `v_min` — magnitudes are nonnegative by definition. (`v_min` is a per-phase array, phase-to-ground.) |
| `E.DOM.VMAX_NONPOSITIVE` | E | A per-phase `v_max` entry ≤ 0 — forces zero voltage; almost certainly a unit/typo error. |
| `E.DOM.VNMAX_NEGATIVE` | E | Negative `vn_max` (the optional, maximum-only neutral-to-ground cap). |
| `E.DOM.NEGATIVE_VALUE` | E | Negative value in an inherently nonnegative field (length, diagonal resistance). |
| `W.DOM.LOAD_PF_LOW` | W | Load power factor below 0.70 — plausible but unusual for aggregated demand; often a P/Q unit mix-up. |
| `W.DOM.GEN_COST_NEGATIVE` | W | Negative generation cost — the optimizer will dispatch it to its bound; verify it is intended (e.g. must-run subsidy). |
| `W.DOM.GEN_COST_HIGH` | W | Cost above 10 \$/kWh — beyond any realistic tariff; suspect units. |
| `W.DOM.COST_PHASE_NONUNIFORM` | W | A dispatchable element (`generator` or `voltage_source`) has a per-phase `cost` vector whose entries differ across phases. Costs are normally a single \$/W price applied symmetrically; a non-uniform vector is more often a data-entry slip than an intended per-phase price signal. Scalar costs are uniform by definition and never flag. |
| `W.DOM.LC_ZERO_R` | W | Near-zero or negative self-resistance on **any** linecode diagonal — a superconducting conductor, usually a placeholder. |
| `E.DOM.XFMR_VREF_INVALID` | E | A transformer has `v_ref_from ≤ 0` or `v_ref_to ≤ 0`. The turns ratio N = v\_ref\_from / v\_ref\_to is undefined or infinite; the OPF cannot be built. Usually caused by a missing field defaulting to zero or a unit error (kV entered as 0.0). |
| `W.DOM.XFMR_RATIO_OOB` | W | Direction-agnostic transformer step ratio `max(r, 1/r)` above 1000:1. Calibrated so standard distribution step-downs (e.g. 11 kV/433 V ≈ 25:1) do **not** flag. |
| `W.DOM.ZERO_LIMIT` | W | An `i_max`/`s_max` entry exactly 0. Read literally this forces zero flow; in source tools 0 usually means "no limit" — classic semantic abuse. Drop the field instead. |
| `W.DOM.ZERO_LENGTH` | W | A zero-length line — degenerate impedance; the spec's lossless switch object is the right model for such sections ([ref. 2](methodology.md#refs)). |
| `W.DOM.ANGLE_UNITS` | W | A source `v_angle` entry with magnitude > 2π — angles are radians in the data model; this is almost certainly degrees. |
| `W.DOM.SOURCE_V_NEAR_BOUND` | W | A voltage source's fixed `v_magnitude` sits within `source_v_margin_frac` (default 5 %) of the `v_max − v_min` band from either bound, on its own bus or a same-voltage-base neighbour (reachable via lines/switches; transformers are not crossed). The source pins that voltage as a hard equality, so little headroom remains and the OPF risks infeasibility. The stricter sibling `W.PRE.SOURCE_VOLTAGE_OOB` fires when the setpoint is already *outside* the bounds; this one warns before it crosses. |
| `W.DOM.SHUNT_ON_GROUNDED` | W | A `shunt` connects to a terminal whose voltage is pinned to 0 V — either declared in the bus's `perfectly_grounded_terminals` or the neutral of a voltage-source bus (pinned to system ground). The shunt then draws `I = G·V = 0` current and is completely inert. Usually a redundant element, or a sign that impedance grounding was intended where a hard V=0 ground was actually declared. |
| `I.DOM.NEGATIVE_LOAD` | I | Loads with negative `p_nom` — embedded generation hiding as negative load; skews adequacy statistics and dodges the generator model. |
| `W.DOM.LINE_LOW_IMPEDANCE` | W | A line whose absolute series impedance ‖Z‖_F = ‖(R+jX)‖_F × length is below 10⁻⁴ Ω. Near-zero impedance makes the KVL constraint nearly rank-deficient; model the section as a switch instead. |
| `W.DOM.LINE_IMPEDANCE_SPREAD` | W | The worst adjacent-line ‖Z‖_F ratio (two lines sharing an interior bus, excluding voltage-source, transformer, and switch buses) exceeds 10⁵. At this contrast the NLP Jacobian loses roughly 5 decimal digits of precision; consider per-unit scaling or network reformulation. |
| `I.DOM.LINE_IMPEDANCE_SPREAD` | I | Same as above but ratio is between 10³ and 10⁵ — common at MV/LV boundaries and usually benign, but worth reviewing if solvers struggle to converge. The result dict key `max_adjacent_impedance_ratio` always carries the worst observed value. |
| `E.DOM.INV_P_BOUNDS` | E | Inverter `p_min > p_max` — the active-power box is empty; infeasible by construction. |
| `E.DOM.INV_Q_BOUNDS` | E | Inverter `q_min > q_max` — the reactive-power box is empty. |
| `E.DOM.INV_SMAX_NONPOSITIVE` | E | Inverter `s_max` has a non-positive entry — the apparent-power circle is empty, so no operating point exists. |
| `W.DOM.INV_BOUND_EXCEEDS_SMAX` | W | An inverter P or Q box-bound magnitude exceeds `s_max` — that box bound can never bind because the apparent-power circle dominates; usually a units or sizing mistake. |
| `W.DOM.INV_PV_ABSORBS` | W | A `prime_mover=PV` inverter has `p_min < 0`, i.e. it is allowed to absorb real power — physically implausible for PV; usually a sign error. |

## LOAD — load model validation & analysis

Emitted by [`domain_rules_check`](@ref) (coefficient plausibility, `DOM` pass)
and [`load_model_analysis`](@ref) (`load_models` pass).

### Validation (domain rules)

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.LOAD.VNOM_MISSING` | E | A voltage-dependent load (`model` ≠ `constant_power`) has no `v_nom` field. The reference voltage is required to evaluate any voltage-dependent power expression; the OPF cannot be constructed without it. |
| `E.LOAD.VNOM_ARITY` | E | `v_nom` is an array whose length is neither 1 nor the number of sub-loads. Each entry must broadcast to exactly one sub-load. |
| `E.LOAD.VNOM_NONPOSITIVE` | E | One or more `v_nom` entries are ≤ 0. Voltages are strictly positive; a non-positive value is unphysical and would produce division by zero in the OPF. |
| `E.LOAD.ZIP_ARITY` | E | A ZIP coefficient array (`alpha_z/i/p` or `beta_z/i/p`) has length that is neither 1 nor the number of sub-loads. |
| `E.LOAD.EXP_ARITY` | E | `gamma_p` or `gamma_q` has length that is neither 1 nor the number of sub-loads. |
| `W.LOAD.ZIP_SUM` | W | For a ZIP load, the active ($\alpha^Z + \alpha^I + \alpha^P$) or reactive ($\beta^Z + \beta^I + \beta^P$) coefficients do not sum to 1. At nominal voltage the load will not consume its nominal power; usually a data entry error. |
| `W.LOAD.GAMMA_NEGATIVE` | W | An exponential exponent $\gamma < 0$ — power increases as voltage falls. Physically possible for some device classes but extremely unusual in distribution-network demand models; almost always a sign error. |
| `W.LOAD.MODEL_MIXED` | W | A `zip` load carries `gamma_p`/`gamma_q` fields, or an `exponential` load carries ZIP coefficient fields. The extra fields are ignored; this finding flags the likely copy-paste error. |
| `W.LOAD.VNOM_MISMATCH` | W | A load's `v_nom` differs from the BFS-inferred bus nominal voltage by more than 25 %. For WYE loads `v_nom` is compared against the inferred phase-to-neutral voltage; for DELTA loads against phase-to-neutral × √3 (line-to-line). A large deviation means the power setpoint and voltage sensitivity are referenced to the wrong operating point — a common OpenDSS conversion error where the load `kV` field is left at a default or is set to the wrong voltage level. |
| `I.LOAD.GAMMA_RANGE` | I | An exponential exponent $\gamma \notin (0, 2)$ — outside the range typical of distribution loads (motors ≈ 0.08, constant-impedance = 2). Still valid; flagged as context. |
| `I.LOAD.MODEL_FIELDS_IGNORED` | I | A `constant_power`, `constant_current`, or `constant_impedance` load carries ZIP or exponential coefficient fields. These fields are redundant for named degenerate models and will be ignored by the OPF. |

### Analysis (load model pass)

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.LOAD.EXP_ZIP_EQUIVALENT` | I | One or more `exponential` loads have all exponents in $\{0, 1, 2\}$. These can be represented losslessly as `zip` (or the named `constant_power`/`constant_current`/`constant_impedance` models), keeping the OPF quadratic. The `loads` detail key lists the affected load IDs. |
| `W.LOAD.NL_NO_VMIN` | W | One or more voltage-dependent loads sit on buses without any lower voltage magnitude bound (`v_min`, `vpn_min`, or `vpp_min`). The OPF squared-voltage variable $W$ will rely on the default floor bound ($0.5\,V^{\text{nom}}$) rather than an engineering limit. For loads with $\gamma < 2$ or $\alpha^I/\alpha^Z \neq 0$ the power expression grows unboundedly as voltage falls; an explicit lower bound is strongly recommended. |

## RED — redundancy

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.RED.ZERO_LOADS` | W | Loads with `p_nom = q_nom = 0` — electrically inert objects that still create variables/constraints. |
| `I.RED.LOAD_SPARSE_PHASES` | I | WYE loads where at least one phase has `p≈0` and `q≈0` while another is active. Each dead phase still generates a current variable and two bilinear constraints in the OPF; splitting into per-phase `SINGLE_PHASE` loads eliminates them. SINGLE_PHASE and DELTA loads are excluded (no clean per-phase equivalent). |
| `I.RED.LOAD_MERGEABLE` | I | Groups of loads on the same bus sharing the same `configuration` and `terminal_map` (WYE/SINGLE_PHASE keys are phase-order-insensitive; DELTA keys are normalised to the smallest cyclic rotation). Each group can be collapsed into one load with summed `p_nom`/`q_nom`. Loads with `time_series` references are excluded (merging profiles is non-trivial). |
| `I.RED.ZERO_SHUNTS` | I | Shunts whose every G/B matrix entry is zero — same. |
| `I.RED.MERGEABLE_LINES` | I | Chains of series lines whose interior buses have line-degree 2 and **no** other attachment (loads, generators, shunts, switches, transformers all counted as blockers). Merging removes superfluous buses that slow solvers ([ref. 2](methodology.md#refs)). |
| `I.RED.PARALLEL_LINES` | I | Two or more lines sharing the same bus pair (direction-agnostic). Parallel lines are unusual in distribution networks and more commonly indicate a data conversion artefact than a genuine double-circuit feeder. |
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
| `I.PROV.LINE_SWITCH_LIKE` | I | A line has near-zero series impedance and may be better represented by the spec's lossless `switch` object. |

### Bound & limit completeness

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.PROV.INCONSISTENT_BOUNDS` | E | A bus has a voltage-bound pair with min > max — the feasible set is empty (the provenance-pass counterpart of the pre-flight `E.PRE.VBOUND_CONFLICT`). |
| `I.PROV.OVERLAPPING_VOLTAGE_BOUNDS` | I | A bus has several voltage-bound *types* active at once (e.g. both `v` and `vpn`) — overlapping envelopes; confirm they are meant to co-apply. |
| `W.PROV.REDUNDANT_VOLTAGE_BOUNDS` | W | A bus declares both phase-to-ground (`v_min`/`v_max`) and phase-to-neutral (`vpn_*`) bounds that encode the same limit — redundant duplication. |
| `W.PROV.INAPPLICABLE_VOLTAGE_BOUNDS` | W | A bus carries voltage bounds that cannot be enforced for its terminal structure and will be ignored by the OPF (e.g. a phase-to-neutral bound on a bus with no neutral). |
| `W.PROV.I_MAX_INCOMPLETE` | W | One or more lines have fewer `i_max` entries than conductors — the thermal limit is only partially specified; the unspecified conductors are left unconstrained. |
| `W.PROV.I_MAX_INCOMPLETE_SWITCH` | W | Same as above for switches. |
| `W.PROV.I_MAX_INCOMPLETE_XFMR` | W | Same for transformers (`i_max_from`/`i_max_to` shorter than the winding conductor count). |
| `W.PROV.I_MAX_ABSENT` | W | One or more lines have **no** `i_max` on their linecode (or no linecode) — the series current is left entirely unconstrained in the OPF, so no thermal limit is enforced on the branch at all (distinct from `I_MAX_INCOMPLETE`, which is a partial limit). |
| `W.PROV.I_MAX_ABSENT_SWITCH` | W | Same for **closed** switches with no `i_max`. Open switches are excluded — their current is fixed to zero regardless. |

### Zone phase topology

Emitted by the `:connectivity` pass after classifying each galvanic zone. Informational tags, not defects.

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.PROV.SPLIT_PHASE_ZONE` | I | A galvanic zone is fed by a `center_tap` transformer — a split-phase section (NA 120-0-120, AU 230-0-230 downstream of SWER). The two legs are anti-phase about the centre-tap neutral; the OPF warm-start initialises them 180° apart accordingly. |
| `I.PROV.SWER_ZONE` | I | A galvanic zone is single-wire (one phase conductor across all its buses) and transformer-isolated — a Single-Wire-Earth-Return section. Distinguished from a single-phase lateral, which shares its three-phase feeder's zone. |

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
| `I.PROV.WYE_NEUTRAL_UNGROUNDED` | I | A three-phase wye winding brings out its star-point neutral at a bus that has no local grounding (no perfect ground and no grounding impedance). The wye star point is the natural earthing point; its zero-sequence potential is then set only by what the neutral conductor reaches elsewhere. Single-phase transformers (phase-to-neutral / phase-to-phase) are exempt. |

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
| `I.PROV.NO_PI_SHUNT` | I | All linecodes have π-shunt admittance keys present but every entry is zero — the shunt capacitance/conductance of every cable was not populated. Line charging is absent from the model; this is common for short LV cables but is worth confirming for longer MV feeders. |
| `I.PROV.PARTIAL_PI_SHUNT` | I | Some linecodes have non-zero π-shunt admittance and others do not — mixed shunt population. May be intentional (e.g. short spurs vs long trunk cables) but is worth reviewing for consistency. |
| `W.PROV.REGULATOR_PATTERN` | W | A transformer that looks like a voltage-regulator/autotransformer encoding: either both windings on one bus (the explicit EPRI autotransformer form) or a near-1:1 wye unit with same-level endpoints / very low impedance / non-unity tap. The data model has no regulator object — a control device has been frozen into a fixed branch. |

## INT — structural integrity

Motivated by the benchmark-pitfall catalogue of ([ref. 2](methodology.md#refs)).

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.INT.UNKNOWN_BUS` | E | A component references a bus id that does not exist. |
| `E.INT.UNKNOWN_LINECODE` | E | A line references a linecode that does not exist (distinct from *unused* linecodes). |
| `E.INT.UNKNOWN_TERMINAL` | E | A terminal-map entry is not a terminal of the referenced bus — typos, or attempts to connect nodal elements directly to ground (forbidden by spec Table 10). |
| `E.INT.UNKNOWN_CONTROL_PROFILE` | E | An inverter references a `control_profile` id that does not exist in the network's `control_profile` table. |
| `W.INT.DIM_MISMATCH` | W | Terminal-map arity vs linecode matrix size, `i_max` length vs conductor count, setpoint length vs configuration, source `vm`/`va` vs map length. |
| `W.INT.PADDED_MATRIX` | W | All-zero row/column pairs in linecode impedances — padded conductors demonstrably wreck NLP performance (22 → 590 Ipopt iterations in ([ref. 2](methodology.md#refs)) Table 3); shrink the matrix and use terminal maps. |
| `E.INT.NO_VOLTAGE_REFERENCE` | E | A galvanic island (transformer windings are separations) with no source, perfect grounding, or grounding shunt — voltages there are defined only up to a shift (the IEEE-123 "bus 610" rank deficiency ([ref. 2](methodology.md#refs))). A shunt counts only if its admittance has nonzero row sums, so a pure delta capacitor bank correctly does not anchor an island. |
| `W.INT.WYE_WITHOUT_NEUTRAL` | W | A wye-configured load/generator at a bus with no identifiable neutral — implies an undeclared ground return; in 3-wire sections only delta connections are expected. |
| `W.INT.FLOATING_LOAD_TERMINAL` | W | A load or generator references a phase terminal that no branch (line, switch, or transformer winding) uses on the same bus. The voltage at that terminal is decoupled from the rest of the network — KCL is trivially satisfied there and the power balance constraint is degenerate. Common cause: a 3-phase load connected to a 2-wire section, or a terminal number typo. Terminals at voltage-source buses and neutral terminals are excluded (sources pin voltages; neutrals are often grounded implicitly). |
| `W.INT.UNUSED_BUS_TERMINAL` | W | A bus declares a terminal in `terminal_names` that is not referenced by any component at that bus (no branch end, load, generator, shunt, or voltage source uses it). The terminal adds a free voltage variable with no KCL constraint — pure numeric overhead. Almost always a conversion artifact or a missing connection. Voltage-source buses are excluded (the source pins every declared terminal regardless). |
| `W.INT.LOW_IMPEDANCE_LINE` | W | Lines whose total series impedance is below 10⁻³× the network median — they degrade conditioning; the spec's lossless switch object is the intended model ([ref. 2](methodology.md#refs)). |
| `I.INT.UNIFORM_GEN_COST` | I | Groups of generators with identical cost vectors — any dispatch split among them is optimal (degeneracy); diversify costs for benchmark use. |

## TMAP — terminal-map conventions

Checks on how component `terminal_map`s reference bus terminals.

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.TMAP.PHASE_TO_NEUTRAL` | E | A component's `terminal_map` contains no phase terminal (e.g. `["n"]`) — it connects only to neutral, leaving no phase to inject into or draw from. |
| `I.TMAP.CROSS_PHASE_LINE` | I | A line or switch has different from/to terminal maps — the conductors are cross-connected between phases across the branch. Valid (e.g. an intentional phase swap) but flagged as context. |
| `I.TMAP.PERMUTED_ORDER` | I | A component's `terminal_map` is a permutation of the bus's nodal terminal order — non-canonical ordering; verify the swap is deliberate rather than a data-entry slip. |

## SPEC — TF-spec conformance

Rules the JSON Schema cannot express.

| Code | Sev | Trigger & rationale |
|---|---|---|
| `W.SPEC.N_SOURCES` | W | Voltage-source count ≠ 1 (spec Eq. 17 requires exactly one in this version). |
| `W.SPEC.BAD_CONFIG` | W | A configuration string outside `SINGLE_PHASE`/`WYE`/`DELTA`. |
| `W.SPEC.CONFIG_ARITY` | W | Terminal-map arity inconsistent with the configuration (SINGLE_PHASE = 2, WYE = 4, DELTA = 3). |
| `E.SPEC.DUPLICATE_TERMINAL` | E | A component's `terminal_map` (or `terminal_map_from`/`terminal_map_to` for lines/switches) contains the same terminal label more than once — a degenerate connection that collapses two distinct conductors onto one. |
| `I.SPEC.LOAD_PHASE_TO_PHASE` | I | A `SINGLE_PHASE` load/generator whose two terminals are both phase conductors (neither is the bus neutral) — a phase-to-phase (delta-connected) single-phase element. Valid per spec; flagged as context because the modelling is distinct from the more common phase-to-neutral case. |
| `E.SPEC.WYE_MISSING_NEUTRAL` | E | A `WYE` load/generator whose last terminal is not the neutral of its bus — the return path is not the neutral conductor, which violates the spec's WYE connection semantics. |
| `E.SPEC.WYE_DUPLICATE_PHASE` | E | A `WYE` load/generator has duplicate phase terminals in the non-neutral slots. |
| `E.SPEC.DELTA_HAS_NEUTRAL` | E | A `DELTA` load/generator includes the bus neutral in its terminal map — delta elements must be phase-to-phase only. |
| `E.SPEC.DELTA_DUPLICATE_PHASE` | E | A `DELTA` load/generator has duplicate phase terminals. |
| `W.SPEC.XFMR_TMAP_ARITY` | W | Transformer terminal-map lengths off the per-subtype spec values — also the deliberate tripwire for unconverted wye-wye units. |
| `W.SPEC.INV_TOPOLOGY` | W | An inverter `topology` outside the spec-allowed set (`FOUR_LEG`/`THREE_LEG`/`SINGLE_PHASE`). |
| `W.SPEC.INV_TMAP_ARITY` | W | An inverter's `terminal_map` length does not match the arity its `topology` requires. |
| `W.SPEC.INV_PRIME_MOVER` | W | An inverter `prime_mover` is outside the spec-allowed set. |
| `W.SPEC.TERMINAL_TYPES` | W | The source file used non-string terminal identifiers; they were coerced at parse (aliases or verbatim — the finding says which). |
| `I.SPEC.MATRIX_TRIANGULAR` | I | Impedance matrices stored upper-triangular; the spec defines full row-first storage. Read fine; normalise before publishing. |

## SOL — solution profiling

Produced by [`profile_solution`](@ref) when checking an OPF result dict against
its network. See [`SolutionReport`](@ref) and [`render_solution`](@ref).

| Code | Sev | Trigger & rationale |
|---|---|---|
| `E.SOL.INFEASIBLE` | E | Solver termination status is not `LOCALLY_SOLVED`, `OPTIMAL`, or `ALMOST_LOCALLY_SOLVED`. All subsequent bound and residual checks are skipped. |
| `E.SOL.NAN_IN_RESULT` | E | One or more numeric fields in the result dict contain `NaN` or `Inf`. Indicates a solver failure or extraction bug even when the termination status appears feasible. |
| `E.SOL.VOLT_VIOLATION` | E | A bus terminal voltage magnitude (vm, vpn, vpp, or sequence component) lies outside its declared bound. |
| `W.SOL.VOLT_ACTIVE` | W | A voltage magnitude is within 1 % of its bound — the constraint is near-active (binding at the tolerance level). |
| `E.SOL.THERMAL_VIOLATION` | E | A line or switch current magnitude exceeds the component's or linecode's `i_max` limit. |
| `W.SOL.THERMAL_ACTIVE` | W | Current magnitude is within 1 % of `i_max` — the thermal limit is near-active. |
| `E.SOL.GEN_VIOLATION` | E | A generator's active or reactive dispatch (`pg`/`qg` per terminal) falls outside its declared `p_min`/`p_max`/`q_min`/`q_max` bounds. |
| `W.SOL.GEN_ACTIVE` | W | Generator dispatch is within 1 % of a bound — the bound is near-active. |
| `E.SOL.INV_VIOLATION` | E | An inverter's solved `pg`/`qg` (per phase) falls outside its declared `p_min`/`p_max`/`q_min`/`q_max` bounds. |
| `W.SOL.INV_ACTIVE` | W | An inverter dispatch is within 1 % of a P bound — the bound is near-active. |
| `W.SOL.INV_PF_DEVIATION` | W | A constant-power-factor inverter's solved operating point deviates from its commanded PF beyond tolerance — the PF-coupling constraint residual is non-trivial. |
| `W.SOL.LOAD_RESIDUAL` | W | For a `constant_power` load, solved `pd`/`qd` differs from `p_nom`/`q_nom` by more than 1 W / 1 var — the bilinear constant-power constraint has a non-trivial residual; the solver may not have converged tightly. Not emitted for voltage-dependent models (where `pd ≠ p_nom` is expected). |
| `W.SOL.LOAD_MODEL_RESIDUAL` | W | For a voltage-dependent load, the realised `pd`/`qd` is inconsistent with what the load model predicts at the solved terminal voltage by more than 1 W / 1 var. Indicates the load model constraint was not satisfied — a solver convergence or result extraction issue. |
| `I.SOL.LOAD_VD_SUMMARY` | I | Aggregate realised vs nominal P/Q across all voltage-dependent sub-loads. Quantifies the total demand shift due to voltage sensitivity at the solved operating point. |
| `W.SOL.POWER_BALANCE` | W | Network-wide active power balance error (Σpg − Σpd − Σp_loss) exceeds 1 % of total load — a significant mismatch that may indicate a lossy model, a missing component, or a result extraction issue. |
| `I.SOL.BINDING_SUMMARY` | I | Summary count of violated and near-active bounds across all categories (voltage, thermal, generator). Always emitted for feasible solutions. |
| `I.SOL.LOSS_FRACTION` | I | Line losses exceed 20 % of total generation — unusually high; may indicate a high-impedance feeder, a model issue, or an extreme operating point. |
| `W.SOL.NEG_LOSS` | W | A line or transformer dissipates **negative active power** (`p_loss < 0`) beyond numerical noise — non-physical for a passive branch, which cannot generate active power. Tolerance is throughput-relative (`p_loss < −max(1 W, 1e-4·\|S_through\|)`). Signals a non-converged / ill-conditioned solution, a sign error, or a negative-resistance input. Reactive loss is excluded, as line charging / capacitive shunts make `q_loss` legitimately negative. |
| `I.SOL.NEUTRAL_SHIFT` | I | Maximum neutral terminal voltage magnitude across all buses, with the bus identifier. Non-zero neutral shift indicates load unbalance or grounding impedance. |
| `W.SOL.INIT_LEVEL_MISMATCH` | W | One or more terminals have `vm_init / vm_solved` outside [0.1, 10] — the initialisation used the wrong voltage level (e.g. source voltage applied to an LV bus via flat warm-start). Solver may still converge but local-minimum risk is elevated. Only emitted when `result["initialisation"]` is present. |
| `W.SOL.INIT_LARGE_ERROR` | W | One or more phase terminals have an initialisation error exceeding 20 % of the solved voltage magnitude — the start point was a poor approximation of the solution. |
| `I.SOL.INIT_NEUTRAL_NONZERO` | I | One or more neutral terminals were initialised with non-zero voltage. Neutral start values should be zero; non-zero values indicate an initialisation inconsistency. |

## BENCH — benchmark readiness

| Code | Sev | Trigger & rationale |
|---|---|---|
| `I.BENCH.AUGMENTATION` | I | The case is not yet a non-trivial OPF benchmark; the message lists the concrete augmentation steps: no costed generation (degenerate objective), slack-only generation (trivial dispatch), absent voltage bounds, absent vpn/vpos bounds (which also aid solver robustness ([ref. 3](methodology.md#refs))), missing thermal limits. |
| `W.BENCH.GEN_NO_DOF` | W | One or more generators have `p_min ≈ p_max` on every phase — fixed output, not dispatchable. These generators consume variables and constraints but cannot move in the optimal solution, and may mask the true binding constraints. |
| `W.BENCH.GEN_ZERO_COST` | W | One or more dispatchable generators (`p_max > p_min` on at least one phase) have a cost vector of all zeros — the objective is flat in their dispatch direction, making the optimal solution primal non-unique. Assign a non-zero cost to each dispatchable unit. |
| `W.BENCH.GEN_DEGENERATE_COST` | W | Two or more dispatchable generators on the same bus or one line/switch hop apart share an identical cost coefficient. The solver can redistribute power between them freely without changing the objective, producing primal non-uniqueness and benchmarks that are sensitive to solver tolerances. |
| `I.BENCH.LOAD_ZERO_PNOM` | I | One or more loads have `p_nom = 0` on all phases — they impose no real power demand and are electrically inert. These loads may indicate missing data or placeholder entries that should be populated before benchmark use. |
