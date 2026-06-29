# BMOPF Network Summary: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Findings:** 0 errors · 3 warnings · 8 info  
**Convention:** LV_230V: 4-wire; 1 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 30 |  |
| line | 29 |  |
| linecode | 2 |  |
| voltage_source | 1 |  |
| load | 28 | 5.776 kW, 1.9 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 0 |  |
| ibr | 28 | capacity: 0.147 MVA (PV×28) |
| control_profile | 1 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_230V | 230.0 V | 30 | 29 | 28 | 0 |

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 1.93 |
| Max degree | 29 |
| Degree-1 buses | 29 |
| Tree depth (max hops) | 2 |

## 4. Diversity & Variance

**Overall symmetry score:** MODERATE

### load

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 25.8 | 741.0 | 1.064 | 28 |
| q_nom | 8.47 | 244.0 | 1.064 | 28 |

### line ⚠

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 180.0 | 525.0 | 0.334 | 29 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000259 | 0.00135 | 0.959 | 2 |

> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 28 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 28 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
> 🔵 **[I.DIV.LINE_SYMMETRIC]** 28 lines share linecode 'lc1' with similar length (±10%) — electrically near-identical.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 5.776 kW |
| Total load Q | 1.9 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).
> 🟡 **[W.OPS.LINE_UNCONSTRAINED]** 29 of 29 lines have no thermal limit (i_max or s_max) — OPF thermal constraints will be missing.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 30 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 30 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** LV_230V: 4-wire; 1 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_230V | 4-wire | 30 / 30 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 30 |
| Neutral branches | 29 |
| Grounding points | 1 |
| Neutral sections | 1 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 2 |

**OpenDSS default fingerprints:** none detected ✓

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 230.0 V | 30 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |

> 🔵 **[I.PROV.NO_PI_SHUNT]** All 2 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
> 🟡 **[W.PROV.I_MAX_ABSENT]** 29 line(s) have no `i_max` on their linecode (or no linecode at all) — their series current is left entirely unconstrained in the OPF, so no thermal limit is enforced on the branch.

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
| Line impedance spread | 1.88× |

| Benchmark readiness | Value |
|---------------------|------:|
| Objective well-posed | true |
| Only slack generation | true |
| Buses with \|V\| bounds | 0.0% |
| Buses with vpn / vpp / vpos bounds | 0 / 0 / 0 |
| Lines with thermal limits | 0.0% |
| Generators with no DOF (p\_min≈p\_max) | 0 |
| Generators with zero cost (dispatchable) | 0 |
| Same-cost generator pairs (≤1 hop) | 0 |
| Loads with zero p\_nom | 0 |

**Augmentation needed:**

- only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)
- no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF
- 29 of 29 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section)

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF; 29 of 29 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section).

## 9. Data Quality Summary

**Total findings:** 11 (0 errors, 3 warnings, 8 info)

### 🟡 Warnings

- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).
- **[W.OPS.LINE_UNCONSTRAINED]** `line`  
  29 of 29 lines have no thermal limit (i_max or s_max) — OPF thermal constraints will be missing.
- **[W.PROV.I_MAX_ABSENT]** `line`  
  29 line(s) have no `i_max` on their linecode (or no linecode at all) — their series current is left entirely unconstrained in the OPF, so no thermal limit is enforced on the branch.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 28 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 28 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.DIV.LINE_SYMMETRIC]** `line`  
  28 lines share linecode 'lc1' with similar length (±10%) — electrically near-identical.
- **[I.PROV.NO_PI_SHUNT]** `linecode`  
  All 2 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  30 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `[source]`  
  Additional property not defined in schema at [voltage_source][source].
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF; 29 of 29 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section).

