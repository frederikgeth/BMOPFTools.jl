# BMOPF Network Summary: DSuite_SPM_Suburban

**Generated:** 2026-06-23 21:26:51  
**Findings:** 0 errors · 66 warnings · 139 info  
**Convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 2282 |  |
| line | 2301 |  |
| linecode | 64 |  |
| voltage_source | 1 |  |
| load | 1114 | 1.042 MW, 0.0 var |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 10 | Dyn0×10 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.41 kV | 2 | 1 | 0 | 0 |
| LV_242V | 242.0 V | 2280 | 2300 | 1114 | 0 |

**Transformer transitions:**

- `dist_transformer_20190615_9064119`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10433351_9067554`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20012486_9049173`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10350026_9076215`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20240793_9024306`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10433349_9082814`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20012512_9082132`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_20096439_9125147`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10434231_9125129`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10432679_9016690`: MV_6.4kV → LV_242V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Meshed |
| Mean degree | 2.02 |
| Max degree | 11 |
| Degree-1 buses | 1030 |
| Tree depth (max hops) | 38 |

> 🟡 **[W.CONN.MESHED]** Network contains 30 extra edge(s) forming cycles — not purely radial.

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 0.0 | 1000.0 | 0.263 | 1114 |
| q_nom | 0.0 | 0.0 | 0.0 | 1114 |

### line ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.0216 | 23.2 | 1.082 | 2301 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 1.0e-6 | 402.0 | 7.997 | 64 |

### transformer

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| s_rating | 500000.0 | 500000.0 | 0.0 | 10 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 1112 of 1114 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 1114 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 1114 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 5 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 15 lines share linecode 'default' with similar length (±10%) — electrically near-identical.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 1.042 MW |
| Total load Q | 0.0 var |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| dist_transformer_20190615_9064119 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_10433351_9067554 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_20012486_9049173 | 500.0 kVA | 24.4% |
| dist_transformer_10350026_9076215 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_20240793_9024306 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_10433349_9082814 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_20012512_9082132 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_20096439_9125147 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_10434231_9125129 | 500.0 kVA | 208.4% ⚠ |
| dist_transformer_10432679_9016690 | 500.0 kVA | 208.4% ⚠ |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (1.04 MW).
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_20190615_9064119' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_10433351_9067554' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_10350026_9076215' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_20240793_9024306' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_10433349_9082814' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_20012512_9082132' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_20096439_9125147' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_10434231_9125129' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'dist_transformer_10432679_9016690' is at 208.4% utilisation at nominal load — little OPF headroom.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'sourcebus' (MV, 6.41 kV) has an electrical reach of 1.0 m — shorter than typical for a MV feeder (200.0 m); electrically it is a stub/service drop rather than a feeder.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 2282 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 2282 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | mixed | 1 / 2 |
| LV_242V | mixed | 1075 / 2280 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 1076 |
| Neutral branches | 0 |
| Grounding points | 1 |
| Neutral sections | 1076 |
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
| 242.0 V | 1983 | ≤3-wire | none | 0 | IT (isolated / high-impedance earthed) |
| 242.0 V | 297 | ≤3-wire | none | 0 | IT (isolated / high-impedance earthed) |

> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_0.05_cu' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_185_al_wavef' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'default' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_ohline_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_cable_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.SEQ_DERIVED]** 17 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: _line_sourcez, cable_230v_0.05_cu, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_300_al_wave, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, default, unknown_lv_cable_m, unknown_lv_ohline_m.
> 🔵 **[I.PROV.DECOUPLED_PHASES]** 47 linecode(s) have zero mutual coupling (diagonal impedance matrix) — positive-sequence-only data; the phases decouple into independent single-phase networks: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_25_al, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_cu, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_s, unknown_lv_ohline_s.
> 🔵 **[I.PROV.PARTIAL_PI_SHUNT]** 63 of 64 linecode(s) have no π-shunt admittance — mixed model: some lines are series-only, others include shunt capacitance/conductance: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🟡 **[W.PROV.IMPLICIT_GROUNDING]** No branch carries a neutral conductor, but 1066 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20190615_9064119' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9064119', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9064119' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10433351_9067554' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067554', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067554' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20012486_9049173' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9049173', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9049173' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10350026_9076215' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9076215', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9076215' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20240793_9024306' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9024306', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9024306' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10433349_9082814' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9082814', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9082814' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20012512_9082132' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9082132', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9082132' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_20096439_9125147' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9125147', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9125147' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10434231_9125129' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9125129', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9125129' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10432679_9016690' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9016690', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9016690' if a local earth was intended.
> 🔵 **[I.PROV.DSS_DEFAULT_LENGTH]** 5 of 2301 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10091256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10092530' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10094236' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10094304' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10094353' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10094545' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10094737' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10104749' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10108429' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10112504' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10118466' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10119479' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10145464' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10877462' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10877534' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10881070' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10883341' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10883375' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10883646' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10883672' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10886611' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10891515' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10891546' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10891644' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '10892379' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11470960' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11470969' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11519646' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11519647' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11520353' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11559268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11572984' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11581768' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11608030' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11608031' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11608032' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11614758' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11614760' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11614761' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11618073' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11620810' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11620811' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11620812' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11620813' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11620814' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '3552356' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '3555675' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4568733' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4671627' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4775561' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '6936427' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7194482' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7218887' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7218893' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7219136' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7219179' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7278989' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7278993' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7278995' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7278997' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7278999' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7279177' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7279433' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383762' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383778' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383785' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383789' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383798' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383830' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383833' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383835' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383845' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383849' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383869' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383890' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383893' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7383921' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9343579' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9353311' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9353329' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9567546' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9567928' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9568309' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9571247' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9571588' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9571625' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9572292' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9573349' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9573800' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9574819' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9584164' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9584594' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9585031' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9586142' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9586156' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9596591' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9596641' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9596747' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9596748' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9603618' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.

## 8. Spec Conformance & Benchmark Readiness

| Spec conformance | Value |
|------------------|------:|
| Conformance issues | 0 |
| Voltage sources (spec requires 1) | 1 |

| Structural integrity | Value |
|----------------------|------:|
| Reference issues | 0 |
| Dimension issues | 0 |
| Galvanic islands | 3 |
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
| Loads with zero p\_nom | 72 |

**Augmentation needed:**

- no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)
- no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF

> 🟡 **[W.INT.LOW_IMPEDANCE_LINE]** 32 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 10886611, 11620810, 11620811, 11620812, 11620813, 11620814, 7194482, 7218887, 7218893, 7219136, 7219179, 7278989, 7278993, 7278995, 7278997, 7278999, 7279177, 7279433, 7383762, 7383778, 7383785, 7383789, 7383798, 7383830, 7383833, 7383835, 7383845, 7383849, 7383869, 7383890, 7383893, 7383921.

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
> 🔵 **[I.BENCH.LOAD_ZERO_PNOM]** 72 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_a1_14534810_1, sop_a1_14534810_2, sop_a1_14534810_3, sop_a2_9336563_1, sop_a2_9336563_2, sop_a2_9336563_3, sop_a3_15870547_1, sop_a3_15870547_2, sop_a3_15870547_3, sop_b1_9376744_1, sop_b1_9376744_2, sop_b1_9376744_3, sop_b2_17641788_1, sop_b2_17641788_2, sop_b2_17641788_3, sop_b3_14854625_1, sop_b3_14854625_2, sop_b3_14854625_3, sop_x4_13407292_1, sop_x4_13407292_2, sop_x4_13407292_3, sop_x5_17892708_1, sop_x5_17892708_2, sop_x5_17892708_3, statcom_12753273_1, statcom_12753273_2, statcom_12753273_3, statcom_12812602_1, statcom_12812602_2, statcom_12812602_3, statcom_13379019_1, statcom_13379019_2, statcom_13379019_3, statcom_13580150_1, statcom_13580150_2, statcom_13580150_3, statcom_13605448_1, statcom_13605448_2, statcom_13605448_3, statcom_13687015_1, statcom_13687015_2, statcom_13687015_3, statcom_13781202_1, statcom_13781202_2, statcom_13781202_3, statcom_14554105_1, statcom_14554105_2, statcom_14554105_3, statcom_15210260_1, statcom_15210260_2, statcom_15210260_3, statcom_15299670_1, statcom_15299670_2, statcom_15299670_3, statcom_15468770_1, statcom_15468770_2, statcom_15468770_3, statcom_15596111_1, statcom_15596111_2, statcom_15596111_3, statcom_15688800_1, statcom_15688800_2, statcom_15688800_3, statcom_15695193_1, statcom_15695193_2, statcom_15695193_3, statcom_17383288_1, statcom_17383288_2, statcom_17383288_3, str_9076215_1, str_9076215_2, str_9076215_3.

## 9. Data Quality Summary

**Total findings:** 205 (0 errors, 66 warnings, 139 info)

### 🟡 Warnings

- **[W.CONN.MESHED]** `network`  
  Network contains 30 extra edge(s) forming cycles — not purely radial.
- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  1112 of 1114 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (1.04 MW).
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_20190615_9064119`  
  Transformer 'dist_transformer_20190615_9064119' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_10433351_9067554`  
  Transformer 'dist_transformer_10433351_9067554' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_10350026_9076215`  
  Transformer 'dist_transformer_10350026_9076215' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_20240793_9024306`  
  Transformer 'dist_transformer_20240793_9024306' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_10433349_9082814`  
  Transformer 'dist_transformer_10433349_9082814' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_20012512_9082132`  
  Transformer 'dist_transformer_20012512_9082132' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_20096439_9125147`  
  Transformer 'dist_transformer_20096439_9125147' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_10434231_9125129`  
  Transformer 'dist_transformer_10434231_9125129' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `dist_transformer_10432679_9016690`  
  Transformer 'dist_transformer_10432679_9016690' is at 208.4% utilisation at nominal load — little OPF headroom.
- **[W.PROV.IMPLICIT_GROUNDING]** `network`  
  No branch carries a neutral conductor, but 1066 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7278989`  
  Line '7278989' has ||Z||_F = 3.11e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10881070`  
  Line '10881070' has ||Z||_F = 8.8e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383833`  
  Line '7383833' has ||Z||_F = 1.08e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383785`  
  Line '7383785' has ||Z||_F = 1.33e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7278993`  
  Line '7278993' has ||Z||_F = 4.12e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11559268`  
  Line '11559268' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383869`  
  Line '7383869' has ||Z||_F = 5.84e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11608031`  
  Line '11608031' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7218893`  
  Line '7218893' has ||Z||_F = 5.44e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383921`  
  Line '7383921' has ||Z||_F = 7.08e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383798`  
  Line '7383798' has ||Z||_F = 7.34e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7278997`  
  Line '7278997' has ||Z||_F = 5.29e-8 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7219179`  
  Line '7219179' has ||Z||_F = 6.94e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10118466`  
  Line '10118466' has ||Z||_F = 8.93e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11618073`  
  Line '11618073' has ||Z||_F = 5.82e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383778`  
  Line '7383778' has ||Z||_F = 1.01e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10883341`  
  Line '10883341' has ||Z||_F = 5.01e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11608032`  
  Line '11608032' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383893`  
  Line '7383893' has ||Z||_F = 4.61e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `10886611`  
  Line '10886611' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7278995`  
  Line '7278995' has ||Z||_F = 1.02e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383762`  
  Line '7383762' has ||Z||_F = 6.91e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11620812`  
  Line '11620812' has ||Z||_F = 2.65e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11572984`  
  Line '11572984' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383835`  
  Line '7383835' has ||Z||_F = 4.76e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11614761`  
  Line '11614761' has ||Z||_F = 5.82e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7219136`  
  Line '7219136' has ||Z||_F = 8.87e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383845`  
  Line '7383845' has ||Z||_F = 6.89e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11470969`  
  Line '11470969' has ||Z||_F = 1.81e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11614758`  
  Line '11614758' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383849`  
  Line '7383849' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11519647`  
  Line '11519647' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7279177`  
  Line '7279177' has ||Z||_F = 9.36e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11620813`  
  Line '11620813' has ||Z||_F = 4.26e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11608030`  
  Line '11608030' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11614760`  
  Line '11614760' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7194482`  
  Line '7194482' has ||Z||_F = 6.74e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383830`  
  Line '7383830' has ||Z||_F = 4.46e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383789`  
  Line '7383789' has ||Z||_F = 1.39e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11620814`  
  Line '11620814' has ||Z||_F = 2.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7383890`  
  Line '7383890' has ||Z||_F = 1.05e-6 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11520353`  
  Line '11520353' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11470960`  
  Line '11470960' has ||Z||_F = 1.49e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7279433`  
  Line '7279433' has ||Z||_F = 7.92e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11620811`  
  Line '11620811' has ||Z||_F = 3.38e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7218887`  
  Line '7218887' has ||Z||_F = 9.34e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7278999`  
  Line '7278999' has ||Z||_F = 5.29e-8 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11581768`  
  Line '11581768' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11519646`  
  Line '11519646' has ||Z||_F = 4.62e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11620810`  
  Line '11620810' has ||Z||_F = 2.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines '7278999' and '3196081' at bus '17743105' have ||Z||_F ratio 286000.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[W.RED.ZERO_LOADS]** `load`  
  72 load(s) have p_nom=0 and q_nom=0 — electrically inert.
- **[W.INT.LOW_IMPEDANCE_LINE]** `line`  
  32 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 10886611, 11620810, 11620811, 11620812, 11620813, 11620814, 7194482, 7218887, 7218893, 7219136, 7219179, 7278989, 7278993, 7278995, 7278997, 7278999, 7279177, 7279433, 7383762, 7383778, 7383785, 7383789, 7383798, 7383830, 7383833, 7383835, 7383845, 7383849, 7383869, 7383890, 7383893, 7383921.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 1114 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 1114 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  5 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  15 lines share linecode 'default' with similar length (±10%) — electrically near-identical.
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
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20190615_9064119`  
  Transformer 'dist_transformer_20190615_9064119' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9064119', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9064119' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10433351_9067554`  
  Transformer 'dist_transformer_10433351_9067554' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9067554', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9067554' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20012486_9049173`  
  Transformer 'dist_transformer_20012486_9049173' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9049173', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9049173' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10350026_9076215`  
  Transformer 'dist_transformer_10350026_9076215' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9076215', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9076215' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20240793_9024306`  
  Transformer 'dist_transformer_20240793_9024306' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9024306', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9024306' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10433349_9082814`  
  Transformer 'dist_transformer_10433349_9082814' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9082814', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9082814' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20012512_9082132`  
  Transformer 'dist_transformer_20012512_9082132' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9082132', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9082132' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_20096439_9125147`  
  Transformer 'dist_transformer_20096439_9125147' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9125147', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9125147' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10434231_9125129`  
  Transformer 'dist_transformer_10434231_9125129' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9125129', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9125129' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10432679_9016690`  
  Transformer 'dist_transformer_10432679_9016690' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9016690', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9016690' if a local earth was intended.
- **[I.PROV.DSS_DEFAULT_LENGTH]** `line`  
  5 of 2301 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
- **[I.PROV.LINE_SWITCH_LIKE]** `10091256`  
  Line '10091256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10092530`  
  Line '10092530' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10094236`  
  Line '10094236' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10094304`  
  Line '10094304' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10094353`  
  Line '10094353' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10094545`  
  Line '10094545' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10094737`  
  Line '10094737' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10104749`  
  Line '10104749' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10108429`  
  Line '10108429' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10112504`  
  Line '10112504' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10118466`  
  Line '10118466' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10119479`  
  Line '10119479' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10145464`  
  Line '10145464' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10877462`  
  Line '10877462' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10877534`  
  Line '10877534' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10881070`  
  Line '10881070' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10883341`  
  Line '10883341' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10883375`  
  Line '10883375' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10883646`  
  Line '10883646' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10883672`  
  Line '10883672' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10886611`  
  Line '10886611' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10891515`  
  Line '10891515' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10891546`  
  Line '10891546' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10891644`  
  Line '10891644' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `10892379`  
  Line '10892379' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11470960`  
  Line '11470960' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11470969`  
  Line '11470969' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11519646`  
  Line '11519646' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11519647`  
  Line '11519647' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11520353`  
  Line '11520353' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11559268`  
  Line '11559268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11572984`  
  Line '11572984' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11581768`  
  Line '11581768' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11608030`  
  Line '11608030' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11608031`  
  Line '11608031' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11608032`  
  Line '11608032' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11614758`  
  Line '11614758' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11614760`  
  Line '11614760' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11614761`  
  Line '11614761' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11618073`  
  Line '11618073' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11620810`  
  Line '11620810' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11620811`  
  Line '11620811' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11620812`  
  Line '11620812' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11620813`  
  Line '11620813' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11620814`  
  Line '11620814' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `3552356`  
  Line '3552356' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `3555675`  
  Line '3555675' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4568733`  
  Line '4568733' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4671627`  
  Line '4671627' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4775561`  
  Line '4775561' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `6936427`  
  Line '6936427' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7194482`  
  Line '7194482' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7218887`  
  Line '7218887' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7218893`  
  Line '7218893' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7219136`  
  Line '7219136' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7219179`  
  Line '7219179' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7278989`  
  Line '7278989' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7278993`  
  Line '7278993' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7278995`  
  Line '7278995' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7278997`  
  Line '7278997' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7278999`  
  Line '7278999' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7279177`  
  Line '7279177' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7279433`  
  Line '7279433' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383762`  
  Line '7383762' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383778`  
  Line '7383778' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383785`  
  Line '7383785' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383789`  
  Line '7383789' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383798`  
  Line '7383798' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383830`  
  Line '7383830' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383833`  
  Line '7383833' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383835`  
  Line '7383835' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383845`  
  Line '7383845' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383849`  
  Line '7383849' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383869`  
  Line '7383869' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383890`  
  Line '7383890' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383893`  
  Line '7383893' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7383921`  
  Line '7383921' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9343579`  
  Line '9343579' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9353311`  
  Line '9353311' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9353329`  
  Line '9353329' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9567546`  
  Line '9567546' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9567928`  
  Line '9567928' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9568309`  
  Line '9568309' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9571247`  
  Line '9571247' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9571588`  
  Line '9571588' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9571625`  
  Line '9571625' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9572292`  
  Line '9572292' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9573349`  
  Line '9573349' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9573800`  
  Line '9573800' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9574819`  
  Line '9574819' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9584164`  
  Line '9584164' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9584594`  
  Line '9584594' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9585031`  
  Line '9585031' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9586142`  
  Line '9586142' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9586156`  
  Line '9586156' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9596591`  
  Line '9596591' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9596641`  
  Line '9596641' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9596747`  
  Line '9596747' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9596748`  
  Line '9596748' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9603618`  
  Line '9603618' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  2282 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `bus`  
  bus has field(s) not in the BMOPF schema: latitude, longitude.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `network`  
  meta has field(s) not in the BMOPF schema: reference, source.
- **[I.RED.MERGEABLE_LINES]** `line`  
  277 group(s) of series lines (637 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.PARALLEL_LINES]** `line`  
  1 bus pair(s) have more than one line — parallel lines are unusual in distribution networks and may indicate a data conversion artefact (2 lines across 1 pair(s)).
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  28 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  8 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
- **[I.BENCH.LOAD_ZERO_PNOM]** `load`  
  72 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_a1_14534810_1, sop_a1_14534810_2, sop_a1_14534810_3, sop_a2_9336563_1, sop_a2_9336563_2, sop_a2_9336563_3, sop_a3_15870547_1, sop_a3_15870547_2, sop_a3_15870547_3, sop_b1_9376744_1, sop_b1_9376744_2, sop_b1_9376744_3, sop_b2_17641788_1, sop_b2_17641788_2, sop_b2_17641788_3, sop_b3_14854625_1, sop_b3_14854625_2, sop_b3_14854625_3, sop_x4_13407292_1, sop_x4_13407292_2, sop_x4_13407292_3, sop_x5_17892708_1, sop_x5_17892708_2, sop_x5_17892708_3, statcom_12753273_1, statcom_12753273_2, statcom_12753273_3, statcom_12812602_1, statcom_12812602_2, statcom_12812602_3, statcom_13379019_1, statcom_13379019_2, statcom_13379019_3, statcom_13580150_1, statcom_13580150_2, statcom_13580150_3, statcom_13605448_1, statcom_13605448_2, statcom_13605448_3, statcom_13687015_1, statcom_13687015_2, statcom_13687015_3, statcom_13781202_1, statcom_13781202_2, statcom_13781202_3, statcom_14554105_1, statcom_14554105_2, statcom_14554105_3, statcom_15210260_1, statcom_15210260_2, statcom_15210260_3, statcom_15299670_1, statcom_15299670_2, statcom_15299670_3, statcom_15468770_1, statcom_15468770_2, statcom_15468770_3, statcom_15596111_1, statcom_15596111_2, statcom_15596111_3, statcom_15688800_1, statcom_15688800_2, statcom_15688800_3, statcom_15695193_1, statcom_15695193_2, statcom_15695193_3, statcom_17383288_1, statcom_17383288_2, statcom_17383288_3, str_9076215_1, str_9076215_2, str_9076215_3.

