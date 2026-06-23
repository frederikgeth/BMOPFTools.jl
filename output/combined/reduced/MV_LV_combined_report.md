# BMOPF Network Summary: MV_LV_combined

**Generated:** 2026-06-23 21:34:06  
**Findings:** 0 errors · 13 warnings · 61 info  
**Convention:** MV_6.4kV: mixed; LV_250V: 4-wire; 1289 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 2169 |  |
| line | 2135 |  |
| linecode | 23 |  |
| voltage_source | 1 |  |
| load | 1255 | 12.55 MW, 6.77 Mvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 1288 |  |
| switch | 0 |  |
| transformer | 33 | Dyn0×33 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.35 kV | 147 | 146 | 0 | 0 |
| LV_250V | 250.0 V | 2022 | 1989 | 1255 | 0 |

**Transformer transitions:**

- `tx3913`: MV_6.4kV → LV_240V (delta_wye, Dyn0)
- `tx848`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1777`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx269`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3703`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1108`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1632`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2620`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2615`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx215`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2458`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2177`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1941`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3394`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1257`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1840`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2187`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3170`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx4271`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx4279`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2677`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3831`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2059`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1621`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2831`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx475`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx377`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx1902`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx381`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx4258`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3676`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx3270`: MV_6.4kV → LV_250V (delta_wye, Dyn0)
- `tx2382`: MV_6.4kV → LV_250V (delta_wye, Dyn0)

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 2.0 |
| Max degree | 8 |
| Degree-1 buses | 1259 |
| Tree depth (max hops) | 77 |

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 10000.0 | 10000.0 | 0.0 | 1255 |
| q_nom | 5400.0 | 5400.0 | 0.0 | 1255 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.2 | 744.0 | 1.548 | 2135 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000146 | 0.00457 | 1.747 | 23 |

### transformer

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| s_rating | 100000.0 | 1.0e6 | 0.436 | 33 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 1254 of 1255 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
> 🔵 **[I.DIV.LOAD_CV_LOW]** Load p_nom has very low coefficient of variation (0.0) — all loads nearly identical.
> 🔵 **[I.DIV.LOAD_PF_DSS_DEFAULT]** Load power factor mean 0.88 is within 1% of the OpenDSS default PF=0.88 (CV=0.0) — reactive power may not have been explicitly set.
> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 1255 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 1255 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1015' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1011' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1' has balanced aggregate load across 3 phase(s) (max spread 1.96%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1279' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1014' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b101' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b107' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b179' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1304' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1579' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 12.55 MW |
| Total load Q | 6.77 Mvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

**Transformer utilisation:**

| ID | Rating | Loading (est.) |
|----|--------|---------------:|
| tx3913 | 200.0 kVA | 17.0% |
| tx848 | 315.0 kVA | 18.0% |
| tx1777 | 500.0 kVA | 2.3% |
| tx269 | 500.0 kVA | 320.5% ⚠ |
| tx3703 | 500.0 kVA | 27.3% |
| tx1108 | 500.0 kVA | 343.2% ⚠ |
| tx1632 | 500.0 kVA | 47.7% |
| tx2620 | 500.0 kVA | 279.5% ⚠ |
| tx2615 | 315.0 kVA | 147.9% ⚠ |
| tx215 | 750.0 kVA | 1.5% |
| tx2458 | 1.0 MVA | 2.3% |
| tx2177 | 1.0 MVA | 3.4% |
| tx1941 | 500.0 kVA | 250.0% ⚠ |
| tx3394 | 315.0 kVA | 165.9% ⚠ |
| tx1257 | 1.0 MVA | 0.0% |
| tx1840 | 500.0 kVA | 9.1% |
| tx2187 | 500.0 kVA | 213.6% ⚠ |
| tx3170 | 100.0 kVA | 22.7% |
| tx4271 | 500.0 kVA | 15.9% |
| tx4279 | 500.0 kVA | 254.5% ⚠ |
| tx2677 | 500.0 kVA | 213.6% ⚠ |
| tx3831 | 1.0 MVA | 25.0% |
| tx2059 | 750.0 kVA | 183.3% ⚠ |
| tx1621 | 500.0 kVA | 2.3% |
| tx2831 | 500.0 kVA | 2.3% |
| tx475 | 1.0 MVA | 0.0% |
| tx377 | 500.0 kVA | 2.3% |
| tx1902 | 500.0 kVA | 2.3% |
| tx381 | 1.0 MVA | 0.0% |
| tx4258 | 315.0 kVA | 3.6% |
| tx3676 | 1.0 MVA | 2.3% |
| tx3270 | 750.0 kVA | 16.7% |
| tx2382 | 500.0 kVA | 275.0% ⚠ |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (12.55 MW).
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx269' is at 320.5% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx1108' is at 343.2% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2620' is at 279.5% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2615' is at 147.9% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx1941' is at 250.0% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx3394' is at 165.9% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2187' is at 213.6% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx4279' is at 254.5% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2677' is at 213.6% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2059' is at 183.3% utilisation at nominal load — little OPF headroom.
> 🟡 **[W.OPS.XFMR_OVERLOADED]** Transformer 'tx2382' is at 275.0% utilisation at nominal load — little OPF headroom.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1952' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1952' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b179' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1304' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2337' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2337' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1420' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1420' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1595' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1595' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1090' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1090' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1579' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_LONG]** Galvanic zone anchored at bus 'b1071' (LV, 0.25 kV) has an electrical reach of 1.01 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'b179' (LV, 0.25 kV) has an electrical reach of 7.4 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 2169 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 2169 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: mixed; LV_250V: 4-wire; 1289 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | mixed | 1 / 147 |
| LV_250V | 4-wire | 2022 / 2022 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 2023 |
| Neutral branches | 1989 |
| Grounding points | 1289 |
| Neutral sections | 34 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 13 |
| near_balanced | 9 |
| not_applicable | 1 |

**OpenDSS default fingerprints:** 1255 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 6.35 kV | 147 | ≤3-wire | solid | 0 | solidly earthed |
| 250.0 V | 233 | 4-wire | solid | 151 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 146 | 4-wire | solid | 94 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 169 | 4-wire | solid | 110 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 66 | 4-wire | solid | 41 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 175 | 4-wire | solid | 112 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 27 | 4-wire | solid | 12 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 213 | 4-wire | solid | 141 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 3 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 13 | 4-wire | solid | 5 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 47 | 4-wire | solid | 21 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 188 | 4-wire | solid | 123 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 141 | 4-wire | solid | 94 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 181 | 4-wire | solid | 121 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 190 | 4-wire | solid | 121 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 24 | 4-wire | solid | 7 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 24 | 4-wire | solid | 11 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 75 | 4-wire | solid | 46 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 38 | 4-wire | solid | 22 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 3 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 1 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 250.0 V | 3 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 5 | 4-wire | solid | 3 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 6 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 4 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 12 | 4-wire | solid | 4 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 4 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 2 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 6 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 5 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 3 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 1 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 250.0 V | 1 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 240.0 V | 13 | 4-wire | solid | 3 | TN-C-S / multi-earthed (PME/MEN-style) |

> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.DSS_DEFAULT_PF]** 1255 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 10 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: generic/hv, moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.

## 8. Spec Conformance & Benchmark Readiness

| Spec conformance | Value |
|------------------|------:|
| Conformance issues | 0 |
| Voltage sources (spec requires 1) | 1 |

| Structural integrity | Value |
|----------------------|------:|
| Reference issues | 0 |
| Dimension issues | 0 |
| Galvanic islands | 34 |
| Islands without voltage reference | 0 |
| Line impedance spread | 8500.0× |

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

**Total findings:** 74 (0 errors, 13 warnings, 61 info)

### 🟡 Warnings

- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  1254 of 1255 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (12.55 MW).
- **[W.OPS.XFMR_OVERLOADED]** `tx269`  
  Transformer 'tx269' is at 320.5% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx1108`  
  Transformer 'tx1108' is at 343.2% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2620`  
  Transformer 'tx2620' is at 279.5% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2615`  
  Transformer 'tx2615' is at 147.9% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx1941`  
  Transformer 'tx1941' is at 250.0% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx3394`  
  Transformer 'tx3394' is at 165.9% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2187`  
  Transformer 'tx2187' is at 213.6% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx4279`  
  Transformer 'tx4279' is at 254.5% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2677`  
  Transformer 'tx2677' is at 213.6% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2059`  
  Transformer 'tx2059' is at 183.3% utilisation at nominal load — little OPF headroom.
- **[W.OPS.XFMR_OVERLOADED]** `tx2382`  
  Transformer 'tx2382' is at 275.0% utilisation at nominal load — little OPF headroom.

### 🔵 Info

- **[I.DIV.LOAD_CV_LOW]** `load`  
  Load p_nom has very low coefficient of variation (0.0) — all loads nearly identical.
- **[I.DIV.LOAD_PF_DSS_DEFAULT]** `load`  
  Load power factor mean 0.88 is within 1% of the OpenDSS default PF=0.88 (CV=0.0) — reactive power may not have been explicitly set.
- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 1255 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 1255 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1015' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1011' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1' has balanced aggregate load across 3 phase(s) (max spread 1.96%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1279' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1014' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b101' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b107' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b179' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1304' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1579' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1952' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1952' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b179' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1304' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b395' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2337' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2337' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1420' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1420' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1595' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1595' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1090' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1090' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1579' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'c'.
- **[I.OPS.FEEDER_LONG]** `network`  
  Galvanic zone anchored at bus 'b1071' (LV, 0.25 kV) has an electrical reach of 1.01 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
- **[I.OPS.FEEDER_SHORT]** `network`  
  Galvanic zone anchored at bus 'b179' (LV, 0.25 kV) has an electrical reach of 7.4 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
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
  1255 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
- **[I.PROV.IMPEDANCE_TRANSFORM_KR]** `linecode`  
  10 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: generic/hv, moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  2169 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines 'l_2043' and 'l_3564' at bus 'b1461' have ||Z||_F ratio 1510.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[I.RED.MERGEABLE_LINES]** `line`  
  145 group(s) of series lines (349 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  3 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  4 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

