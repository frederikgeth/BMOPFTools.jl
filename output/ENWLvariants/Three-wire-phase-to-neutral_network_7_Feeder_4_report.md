# BMOPF Network Summary: Three-wire-phase-to-neutral_network_7_Feeder_4

**Generated:** 2026-06-15 12:58:15  
**Findings:** 0 errors · 3 warnings · 6 info  
**Convention:** LV_240V: mixed; implicit (Kron-style) grounding

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 1545 |  |
| line | 1544 |  |
| linecode | 7 |  |
| voltage_source | 1 |  |
| load | 186 | 162.9 kW, 53.5 kvar |
| generator | 1 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_240V | 240.0 V | 1545 | 1544 | 186 | 1 |

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 2.0 |
| Max degree | 19 |
| Degree-1 buses | 411 |
| Tree depth (max hops) | 197 |

> 🟡 **[W.CONN.DANGLING]** 225 bus(es) are degree-1 with no attached load, generator, or shunt.

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 114.0 | 9740.0 | 1.615 | 186 |
| q_nom | 37.5 | 3200.0 | 1.615 | 186 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.01 | 18.6 | 1.224 | 1544 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000213 | 0.00231 | 0.79 | 7 |

> 🟡 **[W.DIV.LOAD_SYMMETRIC]** 135 of 186 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 162.9 kW |
| Total load Q | 53.5 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.16 MW).

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 1545 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 1545 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** LV_240V: mixed; implicit (Kron-style) grounding

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_240V | mixed | 187 / 1545 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 187 |
| Neutral branches | 0 |
| Grounding points | 187 |
| Neutral sections | 187 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 7 |

**OpenDSS default fingerprints:** 1 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 240.0 V | 1545 | ≤3-wire | solid | 186 | indeterminate (3-wire / Kron-style implicit grounding) |

> 🔵 **[I.PROV.DSS_DEFAULT_LENGTH]** 1 of 1544 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_PN]** 7 three-wire linecode(s) match the impedance signature of phase-to-neutral approximation — R block is circulant with mutual ≈ ½ self (neutral resistance folded into phase self-terms); X block retains the original geometric structure. Valid approximation for equal phase/neutral conductors; error grows with grounding impedance.: lc2, lc3, lc4, lc6, lc7, lc8, lc9.

## 8. Spec Conformance & Benchmark Readiness

| Spec conformance | Value |
|------------------|------:|
| Conformance issues | 0 |
| Voltage sources (spec requires 1) | 1 |

| Structural integrity | Value |
|----------------------|------:|
| Reference issues | 0 |
| Dimension issues | 0 |
| Galvanic islands | 1 |
| Islands without voltage reference | 0 |
| Line impedance spread | 4790.0× |

| Benchmark readiness | Value |
|---------------------|------:|
| Objective well-posed | true |
| Only slack generation | true |
| Buses with \|V\| bounds | 0.0% |
| Buses with vpn / vpp / vsym bounds | 0 / 0 / 0 |
| Lines with thermal limits | 100.0% |

**Augmentation needed:**

- only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)
- no phase-to-neutral or sequence voltage bounds (vpn_*/vsym_*) — sequence bounds also improve solver robustness for 4-wire OPF

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vsym_*) — sequence bounds also improve solver robustness for 4-wire OPF.

## 9. Data Quality Summary

**Total findings:** 9 (0 errors, 3 warnings, 6 info)

### 🟡 Warnings

- **[W.CONN.DANGLING]** `bus`  
  225 bus(es) are degree-1 with no attached load, generator, or shunt.
- **[W.DIV.LOAD_SYMMETRIC]** `load`  
  135 of 186 loads share identical (p_nom, q_nom) — possible copy-paste symmetry.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.16 MW).

### 🔵 Info

- **[I.PROV.DSS_DEFAULT_LENGTH]** `line`  
  1 of 1544 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
- **[I.PROV.IMPEDANCE_TRANSFORM_PN]** `linecode`  
  7 three-wire linecode(s) match the impedance signature of phase-to-neutral approximation — R block is circulant with mutual ≈ ½ self (neutral resistance folded into phase self-terms); X block retains the original geometric structure. Valid approximation for equal phase/neutral conductors; error grows with grounding impedance.: lc2, lc3, lc4, lc6, lc7, lc8, lc9.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  1545 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.RED.MERGEABLE_LINES]** `line`  
  221 group(s) of series lines (1070 lines total) can be merged — intermediate buses have no other connections.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vsym_*) — sequence bounds also improve solver robustness for 4-wire OPF.

