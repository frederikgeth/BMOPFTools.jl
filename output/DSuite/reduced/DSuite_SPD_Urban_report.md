# BMOPF Network Summary: DSuite_SPD_Urban

**Generated:** 2026-06-23 21:26:48  
**Findings:** 0 errors · 29 warnings · 58 info  
**Convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 652 |  |
| line | 650 |  |
| linecode | 64 |  |
| voltage_source | 1 |  |
| load | 325 | 268.0 kW, 0.0 var |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 4 | Dyn0×4 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.41 kV | 2 | 1 | 0 | 0 |
| LV_242V | 242.0 V | 650 | 649 | 325 | 0 |

**Transformer transitions:**

- `dist_transformer_14660774_9052883`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_14787617_9117168`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10148955_9043330`: MV_6.4kV → LV_242V (delta_wye, Dyn0)
- `dist_transformer_10149015_9108352`: MV_6.4kV → LV_242V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Meshed |
| Mean degree | 2.01 |
| Max degree | 7 |
| Degree-1 buses | 274 |
| Tree depth (max hops) | 41 |

> 🟡 **[W.CONN.MESHED]** Network contains 3 extra edge(s) forming cycles — not purely radial.

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 0.0 | 1000.0 | 0.462 | 325 |
| q_nom | 0.0 | 0.0 | 0.0 | 325 |

### line ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.0432 | 29.7 | 1.415 | 650 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 1.0e-6 | 402.0 | 7.997 | 64 |

### transformer

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| s_rating | 500000.0 | 1.0e6 | 0.4 | 4 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 323 of 325 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 325 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 325 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 6 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 4 lines share linecode 'default' with similar length (±10%) — electrically near-identical.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 268.0 kW |
| Total load Q | 0.0 var |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| dist_transformer_14660774_9052883 | 500.0 kVA | 53.6% |
| dist_transformer_14787617_9117168 | 500.0 kVA | 53.6% |
| dist_transformer_10148955_9043330 | 1.0 MVA | 15.0% |
| dist_transformer_10149015_9108352 | 500.0 kVA | 53.6% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.27 MW).
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'sourcebus' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'sourcebus' (MV, 6.41 kV) has an electrical reach of 1.0 m — shorter than typical for a MV feeder (200.0 m); electrically it is a stub/service drop rather than a feeder.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 652 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 652 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: mixed; LV_242V: mixed; implicit (Kron-style) grounding

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | mixed | 1 / 2 |
| LV_242V | mixed | 290 / 650 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 291 |
| Neutral branches | 0 |
| Grounding points | 1 |
| Neutral sections | 291 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| exactly_balanced | 17 |
| decoupled | 47 |

**OpenDSS default fingerprints:** 1 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 6.41 kV | 2 | ≤3-wire | solid | 0 | solidly earthed |
| 242.0 V | 286 | ≤3-wire | none | 0 | IT (isolated / high-impedance earthed) |
| 242.0 V | 364 | ≤3-wire | none | 0 | IT (isolated / high-impedance earthed) |

> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_0.05_cu' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'cable_230v_185_al_wavef' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'default' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_ohline_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.NEGATIVE_MUTUAL_R]** Linecode 'unknown_lv_cable_m' has negative mutual resistance entries [(1, 2), (1, 3), (2, 3)] — unusual; Carson-derived matrices have positive mutuals.
> 🔵 **[I.PROV.SEQ_DERIVED]** 17 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: _line_sourcez, cable_230v_0.05_cu, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_300_al_wave, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, default, unknown_lv_cable_m, unknown_lv_ohline_m.
> 🔵 **[I.PROV.DECOUPLED_PHASES]** 47 linecode(s) have zero mutual coupling (diagonal impedance matrix) — positive-sequence-only data; the phases decouple into independent single-phase networks: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_25_al, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_cu, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_s, unknown_lv_ohline_s.
> 🔵 **[I.PROV.PARTIAL_PI_SHUNT]** 63 of 64 linecode(s) have no π-shunt admittance — mixed model: some lines are series-only, others include shunt capacitance/conductance: busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🟡 **[W.PROV.IMPLICIT_GROUNDING]** No branch carries a neutral conductor, but 287 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_14660774_9052883' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9052883', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9052883' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_14787617_9117168' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9117168', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9117168' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10148955_9043330' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9043330', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9043330' if a local earth was intended.
> 🔵 **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** Transformer 'dist_transformer_10149015_9108352' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9108352', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9108352' if a local earth was intended.
> 🔵 **[I.PROV.DSS_DEFAULT_LENGTH]** 1 of 650 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496741' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496742' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496743' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496744' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496745' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496746' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496905' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11496911' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11558306' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '11585405' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '3641098' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4606800' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '4607955' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7151147' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7210465' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7229858' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7257835' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7257837' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7257841' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7257846' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7257851' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7268155' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '7381641' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9892499' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9895154' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line '9897066' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.

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
| Line impedance spread | 2.08e10× |

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

> 🟡 **[W.INT.LOW_IMPEDANCE_LINE]** 16 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 11496741, 11496742, 11496743, 11496744, 11496745, 11496746, 7151147, 7210465, 7229858, 7257835, 7257837, 7257841, 7257846, 7257851, 7268155, 7381641.

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
> 🔵 **[I.BENCH.LOAD_ZERO_PNOM]** 57 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_a1_9355278_1, sop_a1_9355278_2, sop_a1_9355278_3, sop_a2_14912899_1, sop_a2_14912899_2, sop_a2_14912899_3, sop_b1_15032822_1, sop_b1_15032822_2, sop_b1_15032822_3, sop_b2_9348478_1, sop_b2_9348478_2, sop_b2_9348478_3, sop_x3_15558140_1, sop_x3_15558140_2, sop_x3_15558140_3, sop_x4_17910177_1, sop_x4_17910177_2, sop_x4_17910177_3, statcom_14137299_1, statcom_14137299_2, statcom_14137299_3, statcom_14978947_1, statcom_14978947_2, statcom_14978947_3, statcom_14991958_1, statcom_14991958_2, statcom_14991958_3, statcom_15092405_1, statcom_15092405_2, statcom_15092405_3, statcom_15136229_1, statcom_15136229_2, statcom_15136229_3, statcom_15136254_1, statcom_15136254_2, statcom_15136254_3, statcom_15208810_1, statcom_15208810_2, statcom_15208810_3, statcom_15384501_1, statcom_15384501_2, statcom_15384501_3, statcom_15461308_1, statcom_15461308_2, statcom_15461308_3, statcom_15461331_1, statcom_15461331_2, statcom_15461331_3, statcom_15766046_1, statcom_15766046_2, statcom_15766046_3, statcom_17522559_1, statcom_17522559_2, statcom_17522559_3, str_9043330_1, str_9043330_2, str_9043330_3.

## 9. Data Quality Summary

**Total findings:** 87 (0 errors, 29 warnings, 58 info)

### 🟡 Warnings

- **[W.CONN.MESHED]** `network`  
  Network contains 3 extra edge(s) forming cycles — not purely radial.
- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  323 of 325 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.27 MW).
- **[W.PROV.IMPLICIT_GROUNDING]** `network`  
  No branch carries a neutral conductor, but 287 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7381641`  
  Line '7381641' has ||Z||_F = 9.51e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496905`  
  Line '11496905' has ||Z||_F = 5.82e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7210465`  
  Line '7210465' has ||Z||_F = 7.82e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496741`  
  Line '11496741' has ||Z||_F = 2.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7257841`  
  Line '7257841' has ||Z||_F = 3.26e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `4606800`  
  Line '4606800' has ||Z||_F = 5.97e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7268155`  
  Line '7268155' has ||Z||_F = 8.82e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7257835`  
  Line '7257835' has ||Z||_F = 4.81e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496742`  
  Line '11496742' has ||Z||_F = 2.65e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496911`  
  Line '11496911' has ||Z||_F = 2.98e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7229858`  
  Line '7229858' has ||Z||_F = 7.45e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7257837`  
  Line '7257837' has ||Z||_F = 7.84e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7257846`  
  Line '7257846' has ||Z||_F = 7.03e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496744`  
  Line '11496744' has ||Z||_F = 2.65e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11585405`  
  Line '11585405' has ||Z||_F = 3.61e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496743`  
  Line '11496743' has ||Z||_F = 4.26e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `9895154`  
  Line '9895154' has ||Z||_F = 8.93e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496746`  
  Line '11496746' has ||Z||_F = 3.38e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7257851`  
  Line '7257851' has ||Z||_F = 1.06e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11558306`  
  Line '11558306' has ||Z||_F = 5.82e-5 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `7151147`  
  Line '7151147' has ||Z||_F = 8.21e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_LOW_IMPEDANCE]** `11496745`  
  Line '11496745' has ||Z||_F = 2.18e-7 Ω < threshold 0.0001 Ω — near-zero series impedance; consider replacing with a switch object to avoid ill-conditioned KVL constraints.
- **[W.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines '9892872' and '7257851' at bus '17701204' have ||Z||_F ratio 227000.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[W.RED.ZERO_LOADS]** `load`  
  57 load(s) have p_nom=0 and q_nom=0 — electrically inert.
- **[W.INT.LOW_IMPEDANCE_LINE]** `line`  
  16 line(s) have total series impedance below 10⁻³× the network median — they degrade NLP conditioning; model them as lossless switches: 11496741, 11496742, 11496743, 11496744, 11496745, 11496746, 7151147, 7210465, 7229858, 7257835, 7257837, 7257841, 7257846, 7257851, 7268155, 7381641.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 325 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 325 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  6 lines share linecode 'busbar' with similar length (±10%) — electrically near-identical.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  4 lines share linecode 'default' with similar length (±10%) — electrically near-identical.
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
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_14660774_9052883`  
  Transformer 'dist_transformer_14660774_9052883' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9052883', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9052883' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_14787617_9117168`  
  Transformer 'dist_transformer_14787617_9117168' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9117168', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9117168' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10148955_9043330`  
  Transformer 'dist_transformer_10148955_9043330' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9043330', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9043330' if a local earth was intended.
- **[I.PROV.WYE_NEUTRAL_UNGROUNDED]** `dist_transformer_10149015_9108352`  
  Transformer 'dist_transformer_10149015_9108352' (delta_wye) brings out a three-phase wye neutral on its secondary side at bus '9108352', but that bus has no local grounding (no perfect ground and no grounding impedance). The star point's zero-sequence potential is set only by what the neutral conductor reaches elsewhere — add a grounding shunt or perfect ground at '9108352' if a local earth was intended.
- **[I.PROV.DSS_DEFAULT_LENGTH]** `line`  
  1 of 650 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  64 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: _line_sourcez, busbar, cable_230v_0.0125_al, cable_230v_0.0125_cu, cable_230v_0.0225_cu, cable_230v_0.025_cu, cable_230v_0.03_al, cable_230v_0.04_al, cable_230v_0.04_cu, cable_230v_0.05_cu, cable_230v_0.06_al, cable_230v_0.06_cu, cable_230v_0.15_al, cable_230v_0.15_cu, cable_230v_0.1_al, cable_230v_0.1_cu, cable_230v_0.25_al, cable_230v_0.25_cu, cable_230v_0.2_al, cable_230v_0.2_cu, cable_230v_0.3_al, cable_230v_0.3_cu, cable_230v_0.5_al, cable_230v_0.5_cu, cable_230v_16_cu, cable_230v_185_al, cable_230v_185_al_wave, cable_230v_185_al_wavef, cable_230v_240_al_consac, cable_230v_25_al, cable_230v_25_al_acs, cable_230v_25_al_act, cable_230v_25_al_ascs, cable_230v_25_al_asct, cable_230v_25_cu, cable_230v_25_cu_cscs, cable_230v_25_cu_csct, cable_230v_300_al_consac, cable_230v_300_al_wave, cable_230v_300_cu, cable_230v_35_al_acs, cable_230v_35_al_act, cable_230v_35_al_ascs, cable_230v_35_al_asct, cable_230v_35_al_hybrid, cable_230v_35_cu_ccs, cable_230v_35_cu_cct, cable_230v_35_cu_cscs, cable_230v_35_cu_csct, cable_230v_4_cu, cable_230v_95_al, cable_230v_95_cu, connector, default, ohl_230v_0.0225_ocu, ohl_230v_0.05_oal, ohl_230v_25_oal, ohl_230v_35_abc, ohl_230v_50_abc, ohl_230v_50_oal, unknown_lv_cable_m, unknown_lv_cable_s, unknown_lv_ohline_m, unknown_lv_ohline_s.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496741`  
  Line '11496741' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496742`  
  Line '11496742' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496743`  
  Line '11496743' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496744`  
  Line '11496744' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496745`  
  Line '11496745' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496746`  
  Line '11496746' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496905`  
  Line '11496905' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11496911`  
  Line '11496911' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11558306`  
  Line '11558306' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `11585405`  
  Line '11585405' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `3641098`  
  Line '3641098' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4606800`  
  Line '4606800' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `4607955`  
  Line '4607955' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7151147`  
  Line '7151147' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7210465`  
  Line '7210465' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7229858`  
  Line '7229858' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7257835`  
  Line '7257835' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7257837`  
  Line '7257837' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7257841`  
  Line '7257841' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7257846`  
  Line '7257846' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7257851`  
  Line '7257851' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7268155`  
  Line '7268155' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `7381641`  
  Line '7381641' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9892499`  
  Line '9892499' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9895154`  
  Line '9895154' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `9897066`  
  Line '9897066' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  652 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `bus`  
  bus has field(s) not in the BMOPF schema: latitude, longitude.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `network`  
  meta has field(s) not in the BMOPF schema: reference, source.
- **[I.RED.MERGEABLE_LINES]** `line`  
  97 group(s) of series lines (236 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  23 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  8 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.
- **[I.BENCH.LOAD_ZERO_PNOM]** `load`  
  57 load(s) have p_nom = 0 on all phases — these loads impose no real power demand: sop_a1_9355278_1, sop_a1_9355278_2, sop_a1_9355278_3, sop_a2_14912899_1, sop_a2_14912899_2, sop_a2_14912899_3, sop_b1_15032822_1, sop_b1_15032822_2, sop_b1_15032822_3, sop_b2_9348478_1, sop_b2_9348478_2, sop_b2_9348478_3, sop_x3_15558140_1, sop_x3_15558140_2, sop_x3_15558140_3, sop_x4_17910177_1, sop_x4_17910177_2, sop_x4_17910177_3, statcom_14137299_1, statcom_14137299_2, statcom_14137299_3, statcom_14978947_1, statcom_14978947_2, statcom_14978947_3, statcom_14991958_1, statcom_14991958_2, statcom_14991958_3, statcom_15092405_1, statcom_15092405_2, statcom_15092405_3, statcom_15136229_1, statcom_15136229_2, statcom_15136229_3, statcom_15136254_1, statcom_15136254_2, statcom_15136254_3, statcom_15208810_1, statcom_15208810_2, statcom_15208810_3, statcom_15384501_1, statcom_15384501_2, statcom_15384501_3, statcom_15461308_1, statcom_15461308_2, statcom_15461308_3, statcom_15461331_1, statcom_15461331_2, statcom_15461331_3, statcom_15766046_1, statcom_15766046_2, statcom_15766046_3, statcom_17522559_1, statcom_17522559_2, statcom_17522559_3, str_9043330_1, str_9043330_2, str_9043330_3.

