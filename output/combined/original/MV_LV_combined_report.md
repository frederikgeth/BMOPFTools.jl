# BMOPF Network Summary: MV_LV_combined

**Generated:** 2026-06-23 21:34:05  
**Findings:** 0 errors · 14 warnings · 118 info  
**Convention:** MV_6.4kV: mixed; LV_250V: 4-wire; 1289 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 3409 |  |
| line | 3096 |  |
| linecode | 23 |  |
| voltage_source | 1 |  |
| load | 1255 | 12.55 MW, 6.77 Mvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 1288 |  |
| switch | 279 |  |
| transformer | 33 | Dyn0×33 |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 2

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| MV_6.4kV | 6.35 kV | 328 | 243 | 0 | 0 |
| LV_250V | 250.0 V | 3081 | 2853 | 1255 | 0 |

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
| Max degree | 9 |
| Degree-1 buses | 1865 |
| Tree depth (max hops) | 139 |

> 🟡 **[W.CONN.DANGLING]** 608 bus(es) are degree-1 with no attached load, generator, or shunt.

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 10000.0 | 10000.0 | 0.0 | 1255 |
| q_nom | 5400.0 | 5400.0 | 0.0 | 1255 |

### line ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.0669 | 744.0 | 1.435 | 3096 |

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
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b100' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1' has balanced aggregate load across 3 phase(s) (max spread 1.96%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1011' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1210' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1014' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1006' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1349' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b107' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1133' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LOAD_PHASE_BALANCED]** Galvanic zone anchored at 'b1248' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 135 lines share linecode 'ughv_400al_triplex_ug_3w_bundled' with similar length (±10%) — electrically near-identical.

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
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1025' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1025' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1349' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1151' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1151' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b105' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b105' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b131' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b131' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1372' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1372' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1133' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1248' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'a'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'b'.
> 🔵 **[I.OPS.UNLOADED_PHASE]** Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'c'.
> 🔵 **[I.OPS.FEEDER_LONG]** Galvanic zone anchored at bus 'b100' (LV, 0.25 kV) has an electrical reach of 1.02 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
> 🔵 **[I.OPS.FEEDER_LONG]** Galvanic zone anchored at bus 'b1003' (LV, 0.25 kV) has an electrical reach of 1.09 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'b1163' (LV, 0.25 kV) has an electrical reach of 1.1 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'b1133' (LV, 0.25 kV) has an electrical reach of 7.0 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
> 🔵 **[I.OPS.FEEDER_SHORT]** Galvanic zone anchored at bus 'b1007' (LV, 0.25 kV) has an electrical reach of 0.8 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 3409 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 3409 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** MV_6.4kV: mixed; LV_250V: 4-wire; 1289 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| MV_6.4kV | mixed | 1 / 328 |
| LV_250V | 4-wire | 3081 / 3081 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 3082 |
| Neutral branches | 3048 |
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
| 6.35 kV | 328 | ≤3-wire | solid | 0 | solidly earthed |
| 250.0 V | 315 | 4-wire | solid | 151 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 205 | 4-wire | solid | 94 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 258 | 4-wire | solid | 123 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 223 | 4-wire | solid | 94 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 216 | 4-wire | solid | 110 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 232 | 4-wire | solid | 112 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 90 | 4-wire | solid | 41 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 55 | 4-wire | solid | 12 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 13 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 250.0 V | 279 | 4-wire | solid | 141 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 12 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 29 | 4-wire | solid | 5 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 80 | 4-wire | solid | 21 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 248 | 4-wire | solid | 121 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 245 | 4-wire | solid | 121 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 137 | 4-wire | solid | 46 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 23 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 43 | 4-wire | solid | 7 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 100 | 4-wire | solid | 22 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 58 | 4-wire | solid | 11 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 13 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 26 | 4-wire | solid | 4 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 14 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 36 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 13 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 250.0 V | 15 | 4-wire | solid | 3 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 14 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 12 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 20 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 14 | 4-wire | solid | 2 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 17 | 4-wire | solid | 1 | TN-C-S / multi-earthed (PME/MEN-style) |
| 250.0 V | 1 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |
| 240.0 V | 25 | 4-wire | solid | 3 | TN-C-S / multi-earthed (PME/MEN-style) |

> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'abc4x95_lv_oh_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_from_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.B_OFFDIAG]** Linecode 'uglv_240al_xlpe/nyl/pvc_ug_4w_bundled' B_to_block has positive mutual susceptance — deviates from the Maxwell sign pattern; typical of screen-eliminated/bundled cable reductions, otherwise a sign-convention suspect.
> 🔵 **[I.PROV.DSS_DEFAULT_PF]** 1255 load(s) have power factor exactly 0.88 — the OpenDSS default; reactive demand was likely never specified.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_KR]** 10 three-wire linecode(s) match the impedance signature of Kron reduction — neutral row/column eliminated from the original four-wire Carson impedance matrix via Schur complement. Exact when every neutral is perfectly grounded; approximate with finite grounding. Zero-sequence behaviour is not captured by the three-wire representation.: generic/hv, moon_hv_oh_3wire, pluto_lv_oh_3wire, ughv_240al_triplex_ug_3w_bundled, ughv_240cu_hdpe/nyl/pvc_ug_3w_bundled, ughv_240cu_xlpe/nyl/pvc_ug_3w_bundled, ughv_400al_triplex_ug_3w_bundled, ughv_400al_xlpe/nyl/pvc_ug_3w_bundled, ughv_95al_xlpe/nyl/pvc_ug_3w_bundled, uglv_240al_xlpe/nyl/pvc_ug_3w_bundled.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1042' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1168' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1177' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1330' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1382' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1734' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1882' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1923' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_1998' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2082' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2160' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2218' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2395' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2519' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2537' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2594' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2652' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2673' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2681' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2790' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_2960' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3052' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3088' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3090' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3174' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3207' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3253' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3265' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3566' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3590' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3603' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3924' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_3977' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4087' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4115' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4116' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4172' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4283' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4326' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4328' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_436' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4467' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4507' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4686' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4687' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_4690' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_512' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_525' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_592' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_720' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_819' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'l_866' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.

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
| Line impedance spread | 25400.0× |

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

**Total findings:** 132 (0 errors, 14 warnings, 118 info)

### 🟡 Warnings

- **[W.CONN.DANGLING]** `bus`  
  608 bus(es) are degree-1 with no attached load, generator, or shunt.
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
  Galvanic zone anchored at 'b100' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1' has balanced aggregate load across 3 phase(s) (max spread 1.96%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1011' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1210' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1014' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1006' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1349' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b107' has balanced aggregate load across 3 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1133' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LOAD_PHASE_BALANCED]** `load`  
  Galvanic zone anchored at 'b1248' has balanced aggregate load across 2 phase(s) (max spread 0.0%) — the network is effectively balanced and a single-phase equivalent would suffice.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  135 lines share linecode 'ughv_400al_triplex_ug_3w_bundled' with similar length (±10%) — electrically near-identical.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1726' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1025' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1025' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1012' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1349' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1151' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1151' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b105' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b105' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b131' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b131' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1372' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1372' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1163' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1255' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1133' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1248' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b1007' has no load connected to phase terminal 'c'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'a'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'b'.
- **[I.OPS.UNLOADED_PHASE]** `network`  
  Galvanic zone anchored at bus 'b2885' has no load connected to phase terminal 'c'.
- **[I.OPS.FEEDER_LONG]** `network`  
  Galvanic zone anchored at bus 'b100' (LV, 0.25 kV) has an electrical reach of 1.02 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
- **[I.OPS.FEEDER_LONG]** `network`  
  Galvanic zone anchored at bus 'b1003' (LV, 0.25 kV) has an electrical reach of 1.09 km — longer than the typical maximum LV feeder reach (1.0 km). Check for excessive voltage drop or a length-unit (km vs m) error.
- **[I.OPS.FEEDER_SHORT]** `network`  
  Galvanic zone anchored at bus 'b1163' (LV, 0.25 kV) has an electrical reach of 1.1 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
- **[I.OPS.FEEDER_SHORT]** `network`  
  Galvanic zone anchored at bus 'b1133' (LV, 0.25 kV) has an electrical reach of 7.0 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
- **[I.OPS.FEEDER_SHORT]** `network`  
  Galvanic zone anchored at bus 'b1007' (LV, 0.25 kV) has an electrical reach of 0.8 m — shorter than typical for a LV feeder (30.0 m); electrically it is a stub/service drop rather than a feeder.
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
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1042`  
  Line 'l_1042' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1168`  
  Line 'l_1168' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1177`  
  Line 'l_1177' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1330`  
  Line 'l_1330' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1382`  
  Line 'l_1382' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1734`  
  Line 'l_1734' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1882`  
  Line 'l_1882' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1923`  
  Line 'l_1923' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_1998`  
  Line 'l_1998' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2082`  
  Line 'l_2082' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2160`  
  Line 'l_2160' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2218`  
  Line 'l_2218' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2395`  
  Line 'l_2395' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2519`  
  Line 'l_2519' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2537`  
  Line 'l_2537' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2594`  
  Line 'l_2594' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2652`  
  Line 'l_2652' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2673`  
  Line 'l_2673' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2681`  
  Line 'l_2681' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2790`  
  Line 'l_2790' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_2960`  
  Line 'l_2960' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3052`  
  Line 'l_3052' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3088`  
  Line 'l_3088' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3090`  
  Line 'l_3090' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3174`  
  Line 'l_3174' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3207`  
  Line 'l_3207' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3253`  
  Line 'l_3253' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3256`  
  Line 'l_3256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3265`  
  Line 'l_3265' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3566`  
  Line 'l_3566' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3590`  
  Line 'l_3590' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3603`  
  Line 'l_3603' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3924`  
  Line 'l_3924' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_3977`  
  Line 'l_3977' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4087`  
  Line 'l_4087' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4115`  
  Line 'l_4115' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4116`  
  Line 'l_4116' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4172`  
  Line 'l_4172' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4283`  
  Line 'l_4283' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4326`  
  Line 'l_4326' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4328`  
  Line 'l_4328' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_436`  
  Line 'l_436' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4467`  
  Line 'l_4467' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4507`  
  Line 'l_4507' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4686`  
  Line 'l_4686' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4687`  
  Line 'l_4687' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_4690`  
  Line 'l_4690' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_512`  
  Line 'l_512' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_525`  
  Line 'l_525' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_592`  
  Line 'l_592' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_720`  
  Line 'l_720' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_819`  
  Line 'l_819' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `l_866`  
  Line 'l_866' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  3409 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.DOM.LINE_IMPEDANCE_SPREAD]** `line`  
  Adjacent lines 'l_3238' and 'l_3095' at bus 'b706' have ||Z||_F ratio 1130.0× — large impedance contrasts between neighbouring lines cause ill-conditioned KKT Jacobians; consider per-unit scaling or network reformulation.
- **[I.RED.MERGEABLE_LINES]** `line`  
  130 group(s) of series lines (341 lines total) can be merged — intermediate buses have no other connections.
- **[I.RED.UNUSED_LINECODES]** `linecode`  
  2 linecode(s) defined but not referenced by any line.
- **[I.RED.DUPLICATE_LINECODES]** `linecode`  
  4 group(s) of linecodes share identical R_series_1_1/X_series_1_1.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

