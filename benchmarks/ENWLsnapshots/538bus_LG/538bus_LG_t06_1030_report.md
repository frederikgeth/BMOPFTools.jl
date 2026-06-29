# BMOPF Network Summary: Unnamed Network

**Generated:** 2026-06-29 20:08:36  
**Findings:** 0 errors · 3 warnings · 7 info  
**Convention:** LV_230V: 4-wire; 1 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 538 |  |
| line | 537 |  |
| linecode | 9 |  |
| voltage_source | 1 |  |
| load | 302 | 65.778 kW, 21.6 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 0 |  |
| ibr | 302 | capacity: 1.586 MVA (PV×302) |
| control_profile | 1 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_230V | 230.0 V | 538 | 537 | 302 | 0 |

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 2.0 |
| Max degree | 41 |
| Degree-1 buses | 302 |
| Tree depth (max hops) | 73 |

## 4. Diversity & Variance

**Overall symmetry score:** LOW

### load

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 27.3 | 2450.0 | 1.574 | 304 |
| q_nom | 8.99 | 805.0 | 1.574 | 304 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.791 | 142.0 | 1.038 | 537 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000259 | 0.00228 | 0.713 | 9 |

> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 302 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 65.778 kW |
| Total load Q | 21.6 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.07 MW).
> 🟡 **[W.OPS.LINE_UNCONSTRAINED]** 537 of 537 lines have no thermal limit (i_max or s_max) — OPF thermal constraints will be missing.

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 538 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 538 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** LV_230V: 4-wire; 1 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_230V | 4-wire | 538 / 538 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 538 |
| Neutral branches | 537 |
| Grounding points | 1 |
| Neutral sections | 1 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 9 |

**OpenDSS default fingerprints:** none detected ✓

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 230.0 V | 538 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |

> 🔵 **[I.PROV.NO_PI_SHUNT]** All 9 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
> 🟡 **[W.PROV.I_MAX_ABSENT]** 537 line(s) have no `i_max` on their linecode (or no linecode at all) — their series current is left entirely unconstrained in the OPF, so no thermal limit is enforced on the branch.

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
| Line impedance spread | 481.0× |

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
- 537 of 537 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section)

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF; 537 of 537 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section).

## 9. Data Quality Summary

**Total findings:** 10 (0 errors, 3 warnings, 7 info)

### 🟡 Warnings

- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.07 MW).
- **[W.OPS.LINE_UNCONSTRAINED]** `line`  
  537 of 537 lines have no thermal limit (i_max or s_max) — OPF thermal constraints will be missing.
- **[W.PROV.I_MAX_ABSENT]** `line`  
  537 line(s) have no `i_max` on their linecode (or no linecode at all) — their series current is left entirely unconstrained in the OPF, so no thermal limit is enforced on the branch.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 302 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.PROV.NO_PI_SHUNT]** `linecode`  
  All 9 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  538 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `[source]`  
  Additional property not defined in schema at [voltage_source][source].
- **[I.RED.MERGEABLE_LINES]** `line`  
  18 group(s) of series lines (43 lines total) can be merged — intermediate buses have no other connections.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF; 537 of 537 lines lack thermal limits — add i_max/s_max (e.g. correlated with conductor cross-section).

