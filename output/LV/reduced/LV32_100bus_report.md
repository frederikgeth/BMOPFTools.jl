# BMOPF Network Summary: LV32_100bus

**Generated:** 2026-06-23 21:34:02  
**Findings:** 0 errors · 2 warnings · 24 info  
**Convention:** MV_6.4kV: 4-wire; LV_250V: 4-wire; 24 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 39 |  |
| line | 37 |  |
| linecode | 22 |  |
| voltage_source | 1 |  |
| load | 22 | 220.0 kW, 118.7 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 23 |  |
| switch | 0 |  |
| transformer | 1 | Dyn0×1 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.35 kV | 1 | 0 | 0 | 0 |
| LV_250V | 250.0 V | 38 | 37 | 22 | 0 |

**Transformer transitions:**

- `tx3831`: MV_6.4kV → LV_250V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 1.95 |
| Max degree | 5 |
| Degree-1 buses | 23 |
| Tree depth (max hops) | 10 |

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 10000.0 | 10000.0 | 0.0 | 22 |
| q_nom | 5400.0 | 5400.0 | 0.0 | 22 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.281 | 407.0 | 1.817 | 37 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000146 | 0.00457 | 1.723 | 22 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 21 of 22 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
> 🔵 **[I.DIV.LOAD_CV_LOW]** Load p_nom has very low coefficient of variation (0.0) — all loads nearly identical.
> 🔵 **[I.DIV.LOAD_PF_DSS_DEFAULT]** Load power factor mean 0.88 is within 1% of the OpenDSS default PF=0.88 (CV=0.0) — reactive power may not have been explicitly set.
> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 22 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 22 loads share the 'SINGLE_PHASE' configuration — no connection diversity.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 220.0 kW |
| Total load Q | 118.7 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| tx3831 | 1.0 MVA | 25.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.22 MW).
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_LONG]** Galvanic zone anchored at bus 'b1071' (LV, 0.25 kV) has an electrical reach of 1.01 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 39 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 39 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: 4-wire; LV_250V: 4-wire; 24 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | 4-wire | 1 / 1 |
| LV_250V | 4-wire | 38 / 38 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 39 |
| Neutral branches | 37 |
| Grounding points | 24 |
| Neutral sections | 2 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 12 |
| near_balanced | 9 |
| not_applicable | 1 |

**OpenDSS default fingerprints:** 22 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 6.35 kV | 1 | 4-wire | solid | 0 | solidly earthed |
| 250.0 V | 38 | 4-wire | solid | 22 | TN-C-S / multi-earthed (PME/MEN-style) |

> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.DSS_DEFAULT_PF]** 22 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 9 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.

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
| Line impedance spread | 3310.0× |

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
| Loads with zero p\_nom | 0 |

**Augmentation needed:**

- no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)
- no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

## 9. Data Quality Summary

**Total findings:** 26 (0 errors, 2 warnings, 24 info)

### 🟡 Warnings

- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  21 of 22 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.22 MW).

### 🔵 Info

- **[I.DIV.LOAD_CV_LOW]** `load`  
  Load p_nom has very low coefficient of variation (0.0) — all loads nearly identical.
- **[I.DIV.LOAD_PF_DSS_DEFAULT]** `load`  
  Load power factor mean 0.88 is within 1% of the OpenDSS default PF=0.88 (CV=0.0) — reactive power may not have been explicitly set.
- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 22 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 22 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2234' has no load connected to phase terminal 'c'.
- **[I.OPS.FEEDER_LONG]** `network`  
  Galvanic zone anchored at bus 'b1071' (LV, 0.25 kV) has an electrical reach of 1.01 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
- **[I.PROV.B_OFFDIAG]** `abc4x95_lv_oh_4w_bundled`  
  Linecode 'abc4x95_lv_oh_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.B_OFFDIAG]** `abc4x95_lv_oh_4w_bundled`  
  Linecode 'abc4x95_lv_oh_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.B_OFFDIAG]** `uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled`  
  Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.B_OFFDIAG]** `uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled`  
  Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.B_OFFDIAG]** `uglv_240al_xlpe/nyl/pvc_ug_4w_bundled`  
  Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.B_OFFDIAG]** `uglv_240al_xlpe/nyl/pvc_ug_4w_bundled`  
  Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
- **[I.PROV.DSS_DEFAULT_PF]** `load`  
  22 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  9 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  39 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines 'l_2519' and 'l_3650' at bus 'b2329' have ||Z||_F ratio 1080.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[I.RED.MERGEABLE_LINES]** `line`  
  4 group(s) of series lines (8 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  19 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  4 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

