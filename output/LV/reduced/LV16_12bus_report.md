# BMOPF Network Summary: LV16_12bus

**Generated:** 2026-06-23 21:34:01  
**Findings:** 0 errors · 1 warnings · 20 info  
**Convention:** MV_6.4kV: 4-wire; LV_250V: 4-wire; 3 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 4 |  |
| line | 2 |  |
| linecode | 22 |  |
| voltage_source | 1 |  |
| load | 1 | 10.0 kW, 5.4 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 2 |  |
| switch | 0 |  |
| transformer | 1 | Dyn0×1 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.35 kV | 1 | 0 | 0 | 0 |
| LV_250V | 250.0 V | 3 | 2 | 1 | 0 |

**Transformer transitions:**

- `tx215`: MV_6.4kV → LV_250V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 1.5 |
| Max degree | 2 |
| Degree-1 buses | 2 |
| Tree depth (max hops) | 3 |

## 4. Diversity & Variance

**Overall symmetry score:** LOW

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.855 | 79.7 | 1.384 | 2 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000146 | 0.00457 | 1.723 | 22 |

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 10.0 kW |
| Total load Q | 5.4 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| tx215 | 750.0 kVA | 1.5% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'c'.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 4 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 4 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: 4-wire; LV_250V: 4-wire; 3 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | 4-wire | 1 / 1 |
| LV_250V | 4-wire | 3 / 3 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 4 |
| Neutral branches | 2 |
| Grounding points | 3 |
| Neutral sections | 2 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 12 |
| near_balanced | 9 |
| not_applicable | 1 |

**OpenDSS default fingerprints:** 1 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 6.35 kV | 1 | 4-wire | solid | 0 | solidly earthed |
| 250.0 V | 3 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |

> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.DSS_DEFAULT_PF]** 1 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
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

**Total findings:** 21 (0 errors, 1 warnings, 20 info)

### 🟡 Warnings

- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).

### 🔵 Info

- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b467' has no load connected to phase terminal 'c'.
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
  1 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  9 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  4 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.RED.MERGEABLE_LINES]** `line`  
  1 group(s) of series lines (2 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  20 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  4 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

