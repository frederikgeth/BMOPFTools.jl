# BMOPF Network Summary: DSuite_SPM_Urban

**Generated:** 2026-06-23 21:26:51  
**Findings:** 0 errors · 75 warnings · 153 info  
**Convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 1229 |  |
| line | 1233 |  |
| linecode | 64 |  |
| voltage_source | 1 |  |
| load | 356 | 299.0 kW, 0.0 var |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 6 | Dyn0×6 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.41 kV | 2 | 1 | 0 | 0 |
| LV_242V | 242.0 V | 1227 | 1232 | 356 | 0 |

**Transformer transitions:**

- `dist_transformer_11532030_9067026`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_11534398_9067036`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10432314_9067607`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_14078068_9067610`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20108487_9071358`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20098160_9044497`: MV_6.4kV → LV_242V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Meshed |
| Mean degree | 2.02 |
| Max degree | 7 |
| Degree-1 buses | 481 |
| Tree depth (max hops) | 88 |

> 🟡 **[W.CONN.MESHED]** Network contains 11 extra edge(s) forming cycles — not purely radial.
> 🟡 **[W.CONN.DANGLING]** 190 bus(es) are degree-1 with no attached load, generator, or shunt.

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 0.0 | 1000.0 | 0.437 | 356 |
| q_nom | 0.0 | 0.0 | 0.0 | 356 |

### line ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.00432 | 19.9 | 1.123 | 1233 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 1.0e-6 | 402.0 | 7.997 | 64 |

### transformer

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| s_rating | 500000.0 | 500000.0 | 0.0 | 6 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 354 of 356 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 356 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 356 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at '10584929' has balanced aggregate load across 3 phase(s) (max spread 1.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 4 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 299.0 kW |
| Total load Q | 0.0 var |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| dist_transformer_11532030_9067026 | 500.0 kVA | 59.8% |
| dist_transformer_11534398_9067036 | 500.0 kVA | 59.8% |
| dist_transformer_10432314_9067607 | 500.0 kVA | 59.8% |
| dist_transformer_14078068_9067610 | 500.0 kVA | 59.8% |
| dist_transformer_20108487_9071358 | 500.0 kVA | 59.8% |
| dist_transformer_20098160_9044497 | 500.0 kVA | 59.8% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.3 MW).
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'sourcebus' (MV, 6.41 kV) has an electrical reach of 1.0 m — shorter than typical for a MV feeder (200.0 m); electrically it is a stub/service drop rather than a feeder.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 1229 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 1229 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | mixed | 1 / 2 |
| LV_242V | mixed | 323 / 1227 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 324 |
| Neutral branches | 0 |
| Grounding points | 1 |
| Neutral sections | 324 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| exactly_balanced | 17 |
| decoupled | 47 |

**OpenDSS default fingerprints:** 5 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 6.41 kV | 2 | ≤3-wire | solid | 0 | solidly earthed |
| 242.0 V | 1227 | ≤3-wire | none | 0 | IT (isolated / high-impedance earthed) |

> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_0.05_cu' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_185_al_wavef' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'default' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_ohline_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_cable_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.SEQ_DERIVED]** 17 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: _line_sourcez, cable_230v_0.05_cu, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_300_al_wave, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, default, unknown_lv_cable_m, unknown_lv_ohline_m.
> 🔵 **[I.PROV.DECOUPLED_PHASES]** 47 linecode(s) have zero mutual coupling (diagonal impedance matrix) — positive-sequence-only data; the phases decouple into independent single-phase networks: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_25_al, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_cu, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_s, unknown_lv_ohline_s.
> 🔵 **[I.PROV.PARTIAL_PI_SHUNT]** 63 of 64 linecode(s) have no π-shunt admittance — mixed model: some lines are series-only, others include shunt capacitance/conductance: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🟡 **[W.PROV.IMPLICIT_GROUNDING]** No branch carries a neutral conductor, but 318 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_11532030_9067026' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067026', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067026' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_11534398_9067036' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067036', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067036' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10432314_9067607' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067607', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067607' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_14078068_9067610' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067610', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067610' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20108487_9071358' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9071358', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9071358' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20098160_9044497' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9044497', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9044497' if a local earth was intended.
> 🔵 **[I.PROV.DSS_DEFAULT_LENGTH]** 5 of 1233 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10429506' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10429584' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10429586' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10429590' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10433947' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10435588' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10435614' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10435941' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10435959' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10435976' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436491' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436627' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436629' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436633' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10436637' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10438258' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10445747' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10445749' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10449755' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11157824' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11474852' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11550906' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11564999' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11601713' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11629040' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11629042' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11629044' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11629046' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11630809' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11630813' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11630815' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4052405' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4067615' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5176717' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5193550' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5354881' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5402306' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5402319' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5403201' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5403202' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5419602' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5436380' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '5439592' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6340768' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6340769' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6343682' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6343687' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6343690' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6343692' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6345176' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6345392' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6345393' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6345397' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6346503' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6346504' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6346527' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6346528' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6347480' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6352790' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6352794' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6357475' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6362760' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6365150' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6365164' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6621251' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6721570' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6731662' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7017461' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7133196' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7133203' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7133214' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7133232' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325270' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325271' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325272' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325273' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325274' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325275' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325276' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325277' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325278' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325279' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325281' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325282' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325283' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325284' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325285' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325286' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325287' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325288' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325289' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325290' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325291' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325292' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325293' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325294' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325295' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325296' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325297' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325474' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325475' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325476' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325477' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325478' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7325479' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7412941' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7412944' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7413019' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7413030' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7413054' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7413064' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8850211' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8850520' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8855922' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8858366' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8871722' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '8871727' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.

## 8. Spec Conformance & Benchmark Readiness

| Spec conformance | Value |
|------------------|------:|
| Conformance issues | 0 |
| Voltage sources (spec requires 1) | 1 |

| Structural integrity | Value |
|----------------------|------:|
| Reference issues | 0 |
| Dimension issues | 0 |
| Galvanic islands | 2 |
| Islands without voltage reference | 0 |
| Line impedance spread | 4.16e10× |

| Benchmark readiness | Value |
|---------------------|------:|
| Objective well-posed | false |
| Only slack generation | false |
| Buses with \|V\| bounds | 0.0% |
| Buses with vpn / vpp / vpos bounds | 0 / 0 / 0 |
| Lines with thermal limits | 100.0% |
| Generators with no DOF (p\_min≈p\_max) | 0 |
| Generators with zero cost (dispatchable) | 0 |
| Same-cost generator pairs (≤1 hop) | 0 |
| Loads with zero p\_nom | 57 |

**Augmentation needed:**

- no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)
- no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF

> 🟡 **[W.INT.LOW_IMPEDANCE_LINE]** 53 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 10436627, 10436629, 10436633, 10436637, 10438258, 10445747, 10445749, 11629040, 11629042, 11629044, 11629046, 7133196, 7133203, 7133214, 7133232, 7325270, 7325271, 7325272, 7325273, 7325274, 7325275, 7325276, 7325277, 7325278, 7325279, 7325281, 7325282, 7325283, 7325284, 7325285, 7325286, 7325287, 7325288, 7325289, 7325290, 7325291, 7325293, 7325294, 7325295, 7325296, 7325297, 7325474, 7325475, 7325476, 7325477, 7325478, 7325479, 7412941, 7412944, 7413019, 7413030, 7413054, 7413064.

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
> 🔵 **[I.BENCH.LOAD_ZERO_PNOM]** 57 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_x1_16680546_1, sop_x1_16680546_2, sop_x1_16680546_3, sop_x2_17806531_1, sop_x2_17806531_2, sop_x2_17806531_3, sop_x3_16825063_1, sop_x3_16825063_2, sop_x3_16825063_3, sop_x4_17806525_1, sop_x4_17806525_2, sop_x4_17806525_3, sop_x5_17806528_1, sop_x5_17806528_2, sop_x5_17806528_3, statcom_14307491_1, statcom_14307491_2, statcom_14307491_3, statcom_15717555_1, statcom_15717555_2, statcom_15717555_3, statcom_15892354_1, statcom_15892354_2, statcom_15892354_3, statcom_16666765_1, statcom_16666765_2, statcom_16666765_3, statcom_16670799_1, statcom_16670799_2, statcom_16670799_3, statcom_16680428_1, statcom_16680428_2, statcom_16680428_3, statcom_16802187_1, statcom_16802187_2, statcom_16802187_3, statcom_16802215_1, statcom_16802215_2, statcom_16802215_3, statcom_16803228_1, statcom_16803228_2, statcom_16803228_3, statcom_16822347_1, statcom_16822347_2, statcom_16822347_3, statcom_16829606_1, statcom_16829606_2, statcom_16829606_3, statcom_16913952_1, statcom_16913952_2, statcom_16913952_3, statcom_16939712_1, statcom_16939712_2, statcom_16939712_3, str_9067026_1, str_9067026_2, str_9067026_3.

## 9. Data Quality Summary

**Total findings:** 228 (0 errors, 75 warnings, 153 info)

### 🟡 Warnings

- **[W.CONN.MESHED]** `network`  
  Network contains 11 extra edge(s) forming cycles — not purely radial.
- **[W.CONN.DANGLING]** `bus`  
  190 bus(es) are degree-1 with no attached load, generator, or shunt.
- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  354 of 356 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.3 MW).
- **[W.PROV.IMPLICIT_GROUNDING]** `network`  
  No branch carries a neutral conductor, but 318 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325292`  
  Line '7325292' has ||Z||_F = 5.36e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7133203`  
  Line '7133203' has ||Z||_F = 2.21e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325285`  
  Line '7325285' has ||Z||_F = 8.89e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10438258`  
  Line '10438258' has ||Z||_F = 2.95e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11550906`  
  Line '11550906' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325478`  
  Line '7325478' has ||Z||_F = 1.52e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `6365164`  
  Line '6365164' has ||Z||_F = 8.06e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325276`  
  Line '7325276' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325278`  
  Line '7325278' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `6346503`  
  Line '6346503' has ||Z||_F = 7.37e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325294`  
  Line '7325294' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10436633`  
  Line '10436633' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11629042`  
  Line '11629042' has ||Z||_F = 2.65e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10445749`  
  Line '10445749' has ||Z||_F = 5.29e-8 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10436629`  
  Line '10436629' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `8871722`  
  Line '8871722' has ||Z||_F = 7.36e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325279`  
  Line '7325279' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325281`  
  Line '7325281' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325291`  
  Line '7325291' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325293`  
  Line '7325293' has ||Z||_F = 5.14e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325273`  
  Line '7325273' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7133214`  
  Line '7133214' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11630815`  
  Line '11630815' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325287`  
  Line '7325287' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325283`  
  Line '7325283' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7413064`  
  Line '7413064' has ||Z||_F = 8.77e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325288`  
  Line '7325288' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10435614`  
  Line '10435614' has ||Z||_F = 6.46e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325296`  
  Line '7325296' has ||Z||_F = 7.86e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325284`  
  Line '7325284' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325274`  
  Line '7325274' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325275`  
  Line '7325275' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11630809`  
  Line '11630809' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11564999`  
  Line '11564999' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7413019`  
  Line '7413019' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11629044`  
  Line '11629044' has ||Z||_F = 2.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11629046`  
  Line '11629046' has ||Z||_F = 4.26e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325295`  
  Line '7325295' has ||Z||_F = 9.82e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11629040`  
  Line '11629040' has ||Z||_F = 3.38e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325282`  
  Line '7325282' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10436637`  
  Line '10436637' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325477`  
  Line '7325477' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7413054`  
  Line '7413054' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7412941`  
  Line '7412941' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325475`  
  Line '7325475' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325270`  
  Line '7325270' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7133196`  
  Line '7133196' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `6345176`  
  Line '6345176' has ||Z||_F = 7.84e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325479`  
  Line '7325479' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10436627`  
  Line '10436627' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325474`  
  Line '7325474' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325271`  
  Line '7325271' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7413030`  
  Line '7413030' has ||Z||_F = 2.96e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325286`  
  Line '7325286' has ||Z||_F = 7.99e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7133232`  
  Line '7133232' has ||Z||_F = 8.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325277`  
  Line '7325277' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7412944`  
  Line '7412944' has ||Z||_F = 1.64e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325272`  
  Line '7325272' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `6365150`  
  Line '6365150' has ||Z||_F = 7.16e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11474852`  
  Line '11474852' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10445747`  
  Line '10445747' has ||Z||_F = 5.29e-8 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325297`  
  Line '7325297' has ||Z||_F = 1.66e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `8858366`  
  Line '8858366' has ||Z||_F = 8.25e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325290`  
  Line '7325290' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11601713`  
  Line '11601713' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325476`  
  Line '7325476' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7325289`  
  Line '7325289' has ||Z||_F = 1.26e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11630813`  
  Line '11630813' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.RED.ZERO_LOADS]** `load`  
  57 load(s) have p_nom=0 and q_nom=0 — electrically inert.
- **[W.INT.LOW_IMPEDANCE_LINE]** `line`  
  53 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 10436627, 10436629, 10436633, 10436637, 10438258, 10445747, 10445749, 11629040, 11629042, 11629044, 11629046, 7133196, 7133203, 7133214, 7133232, 7325270, 7325271, 7325272, 7325273, 7325274, 7325275, 7325276, 7325277, 7325278, 7325279, 7325281, 7325282, 7325283, 7325284, 7325285, 7325286, 7325287, 7325288, 7325289, 7325290, 7325291, 7325293, 7325294, 7325295, 7325296, 7325297, 7325474, 7325475, 7325476, 7325477, 7325478, 7325479, 7412941, 7412944, 7413019, 7413030, 7413054, 7413064.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 356 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 356 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at '10584929' has balanced aggregate load across 3 phase(s) (max spread 1.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  4 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'c'.
- **[I.OPS.FEEDER_SHORT]** `network`  
  Galvanic zone anchored at bus 'sourcebus' (MV, 6.41 kV) has an electrical reach of 1.0 m — shorter than typical for a MV feeder (200.0 m); electrically it is a stub/service drop rather than a feeder.
- **[I.PROV.NEGATIVE_MUTUAL_R]** `cable_230v_0.05_cu`  
  Linecode 'cable_230v_0.05_cu' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
- **[I.PROV.NEGATIVE_MUTUAL_R]** `cable_230v_185_al_wavef`  
  Linecode 'cable_230v_185_al_wavef' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
- **[I.PROV.NEGATIVE_MUTUAL_R]** `default`  
  Linecode 'default' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
- **[I.PROV.NEGATIVE_MUTUAL_R]** `unknown_lv_ohline_m`  
  Linecode 'unknown_lv_ohline_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
- **[I.PROV.NEGATIVE_MUTUAL_R]** `unknown_lv_cable_m`  
  Linecode 'unknown_lv_cable_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
- **[I.PROV.SEQ_DERIVED]** `linecode`  
  17 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: _line_sourcez, cable_230v_0.05_cu, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_300_al_wave, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, default, unknown_lv_cable_m, unknown_lv_ohline_m.
- **[I.PROV.DECOUPLED_PHASES]** `linecode`  
  47 linecode(s) have zero mutual coupling (diagonal impedance matrix) — positive-sequence-only data; the phases decouple into independent single-phase networks: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_25_al, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_cu, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_s, unknown_lv_ohline_s.
- **[I.PROV.PARTIAL_PI_SHUNT]** `linecode`  
  63 of 64 linecode(s) have no π-shunt admittance — mixed model: some lines are series-only, others include shunt capacitance/conductance: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_11532030_9067026`  
  Transformer 'dist_transformer_11532030_9067026' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067026', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067026' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_11534398_9067036`  
  Transformer 'dist_transformer_11534398_9067036' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067036', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067036' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10432314_9067607`  
  Transformer 'dist_transformer_10432314_9067607' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067607', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067607' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_14078068_9067610`  
  Transformer 'dist_transformer_14078068_9067610' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067610', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067610' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20108487_9071358`  
  Transformer 'dist_transformer_20108487_9071358' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9071358', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9071358' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20098160_9044497`  
  Transformer 'dist_transformer_20098160_9044497' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9044497', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9044497' if a local earth was intended.
- **[I.PROV.DSS_DEFAULT_LENGTH]** `line`  
  5 of 1233 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
- **[I.PROV.LINE_SWITCH_LIKE]** `10429506`  
  Line '10429506' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10429584`  
  Line '10429584' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10429586`  
  Line '10429586' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10429590`  
  Line '10429590' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10433947`  
  Line '10433947' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10435588`  
  Line '10435588' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10435614`  
  Line '10435614' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10435941`  
  Line '10435941' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10435959`  
  Line '10435959' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10435976`  
  Line '10435976' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436268`  
  Line '10436268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436491`  
  Line '10436491' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436627`  
  Line '10436627' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436629`  
  Line '10436629' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436633`  
  Line '10436633' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10436637`  
  Line '10436637' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10438258`  
  Line '10438258' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10445747`  
  Line '10445747' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10445749`  
  Line '10445749' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10449755`  
  Line '10449755' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11157824`  
  Line '11157824' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11474852`  
  Line '11474852' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11550906`  
  Line '11550906' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11564999`  
  Line '11564999' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11601713`  
  Line '11601713' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11629040`  
  Line '11629040' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11629042`  
  Line '11629042' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11629044`  
  Line '11629044' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11629046`  
  Line '11629046' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11630809`  
  Line '11630809' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11630813`  
  Line '11630813' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11630815`  
  Line '11630815' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4052405`  
  Line '4052405' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4067615`  
  Line '4067615' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5176717`  
  Line '5176717' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5193550`  
  Line '5193550' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5354881`  
  Line '5354881' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5402306`  
  Line '5402306' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5402319`  
  Line '5402319' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5403201`  
  Line '5403201' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5403202`  
  Line '5403202' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5419602`  
  Line '5419602' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5436380`  
  Line '5436380' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `5439592`  
  Line '5439592' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6340768`  
  Line '6340768' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6340769`  
  Line '6340769' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6343682`  
  Line '6343682' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6343687`  
  Line '6343687' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6343690`  
  Line '6343690' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6343692`  
  Line '6343692' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6345176`  
  Line '6345176' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6345392`  
  Line '6345392' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6345393`  
  Line '6345393' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6345397`  
  Line '6345397' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6346503`  
  Line '6346503' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6346504`  
  Line '6346504' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6346527`  
  Line '6346527' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6346528`  
  Line '6346528' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6347480`  
  Line '6347480' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6352790`  
  Line '6352790' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6352794`  
  Line '6352794' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6357475`  
  Line '6357475' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6362760`  
  Line '6362760' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6365150`  
  Line '6365150' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6365164`  
  Line '6365164' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6621251`  
  Line '6621251' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6721570`  
  Line '6721570' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6731662`  
  Line '6731662' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7017461`  
  Line '7017461' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7133196`  
  Line '7133196' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7133203`  
  Line '7133203' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7133214`  
  Line '7133214' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7133232`  
  Line '7133232' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325270`  
  Line '7325270' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325271`  
  Line '7325271' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325272`  
  Line '7325272' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325273`  
  Line '7325273' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325274`  
  Line '7325274' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325275`  
  Line '7325275' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325276`  
  Line '7325276' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325277`  
  Line '7325277' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325278`  
  Line '7325278' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325279`  
  Line '7325279' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325281`  
  Line '7325281' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325282`  
  Line '7325282' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325283`  
  Line '7325283' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325284`  
  Line '7325284' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325285`  
  Line '7325285' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325286`  
  Line '7325286' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325287`  
  Line '7325287' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325288`  
  Line '7325288' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325289`  
  Line '7325289' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325290`  
  Line '7325290' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325291`  
  Line '7325291' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325292`  
  Line '7325292' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325293`  
  Line '7325293' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325294`  
  Line '7325294' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325295`  
  Line '7325295' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325296`  
  Line '7325296' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325297`  
  Line '7325297' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325474`  
  Line '7325474' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325475`  
  Line '7325475' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325476`  
  Line '7325476' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325477`  
  Line '7325477' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325478`  
  Line '7325478' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7325479`  
  Line '7325479' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7412941`  
  Line '7412941' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7412944`  
  Line '7412944' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7413019`  
  Line '7413019' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7413030`  
  Line '7413030' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7413054`  
  Line '7413054' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7413064`  
  Line '7413064' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8850211`  
  Line '8850211' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8850520`  
  Line '8850520' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8855922`  
  Line '8855922' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8858366`  
  Line '8858366' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8871722`  
  Line '8871722' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `8871727`  
  Line '8871727' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  1229 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `bus`  
  bus has field(s) not in the BMOPF schema: latitude, longitude.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `network`  
  meta has field(s) not in the BMOPF schema: reference, source.
- **[I.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines '7133203' and '5284643' at bus '17500511' have ||Z||_F ratio 69600.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[I.RED.MERGEABLE_LINES]** `line`  
  170 group(s) of series lines (460 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  33 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  8 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
- **[I.BENCH.LOAD_ZERO_PNOM]** `load`  
  57 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_x1_16680546_1, sop_x1_16680546_2, sop_x1_16680546_3, sop_x2_17806531_1, sop_x2_17806531_2, sop_x2_17806531_3, sop_x3_16825063_1, sop_x3_16825063_2, sop_x3_16825063_3, sop_x4_17806525_1, sop_x4_17806525_2, sop_x4_17806525_3, sop_x5_17806528_1, sop_x5_17806528_2, sop_x5_17806528_3, statcom_14307491_1, statcom_14307491_2, statcom_14307491_3, statcom_15717555_1, statcom_15717555_2, statcom_15717555_3, statcom_15892354_1, statcom_15892354_2, statcom_15892354_3, statcom_16666765_1, statcom_16666765_2, statcom_16666765_3, statcom_16670799_1, statcom_16670799_2, statcom_16670799_3, statcom_16680428_1, statcom_16680428_2, statcom_16680428_3, statcom_16802187_1, statcom_16802187_2, statcom_16802187_3, statcom_16802215_1, statcom_16802215_2, statcom_16802215_3, statcom_16803228_1, statcom_16803228_2, statcom_16803228_3, statcom_16822347_1, statcom_16822347_2, statcom_16822347_3, statcom_16829606_1, statcom_16829606_2, statcom_16829606_3, statcom_16913952_1, statcom_16913952_2, statcom_16913952_3, statcom_16939712_1, statcom_16939712_2, statcom_16939712_3, str_9067026_1, str_9067026_2, str_9067026_3.

