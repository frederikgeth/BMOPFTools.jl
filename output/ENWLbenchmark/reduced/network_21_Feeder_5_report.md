# BMOPF Network Summary: network_21_Feeder_5

**Generated:** 2026-06-23 13:43:46  
**Findings:** 0 errors · 2 warnings · 7 info  
**Convention:** LV_240V: 4-wire; 1 grounding point(s)

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 61 |  |
| line | 60 |  |
| linecode | 4 |  |
| voltage_source | 1 |  |
| load | 27 | 23.97 kW, 7.9 kvar |
| generator | 8 | capacity: 171.82 kW |
| shunt | 1 |  |
| switch | 0 |  |
| transformer | 0 |  |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_240V | 240.0 V | 61 | 60 | 27 | 8 |

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 1.97 |
| Max degree | 3 |
| Degree-1 buses | 28 |
| Tree depth (max hops) | 14 |

## 4. Diversity & Variance

**Overall symmetry score:** LOW

### load

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 114.0 | 3050.0 | 1.022 | 27 |
| q_nom | 37.5 | 1000.0 | 1.022 | 27 |

### generator

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_max | 4000.0 | 47900.0 | 1.235 | 10 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 1.21 | 63.0 | 0.905 | 60 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.000259 | 0.00228 | 0.86 | 4 |

> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 27 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 27 loads share the 'SINGLE_PHASE' configuration — no connection diversity.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 23.97 kW |
| Total load Q | 7.9 kvar |
| Total gen capacity | 171.82 kW |
| Generation/load ratio | 716.8% |

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | false |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 61 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 61 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🟡 **[W.PRE.SOURCE_BUS_GENERATOR]** Generator 'grid' is at voltage-source bus 'sourcebus' and lacks p_max/q_max bounds. The voltage source is the network's current slack, so two unbounded current injections share one fixed-voltage bus — the dispatch split is degenerate (non-unique). Remove this generator and express its role as flow bounds/cost on the voltage source instead.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** LV_240V: 4-wire; 1 grounding point(s)

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_240V | 4-wire | 61 / 61 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 61 |
| Neutral branches | 60 |
| Grounding points | 1 |
| Neutral sections | 1 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| distinct | 4 |

**OpenDSS default fingerprints:** none detected ✓

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 240.0 V | 61 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |

> 🔵 **[I.PROV.NO_PI_SHUNT]** All 4 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.

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
| Line impedance spread | 52.2× |

| Benchmark readiness | Value |
|---------------------|------:|
| Objective well-posed | true |
| Only slack generation | false |
| Buses with \|V\| bounds | 0.0% |
| Buses with vpn / vpp / vpos bounds | 60 / 0 / 0 |
| Lines with thermal limits | 100.0% |
| Generators with no DOF (p\_min≈p\_max) | 0 |
| Generators with zero cost (dispatchable) | 0 |
| Same-cost generator pairs (≤1 hop) | 0 |
| Loads with zero p\_nom | 0 |

**Augmentation needed:**

- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground).

## 9. Data Quality Summary

**Total findings:** 9 (0 errors, 2 warnings, 7 info)

### 🟡 Warnings

- **[W.PRE.SOURCE_BUS_GENERATOR]** `grid`  
  Generator 'grid' is at voltage-source bus 'sourcebus' and lacks p_max/q_max bounds. The voltage source is the network's current slack, so two unbounded current injections share one fixed-voltage bus — the dispatch split is degenerate (non-unique). Remove this generator and express its role as flow bounds/cost on the voltage source instead.
- **[W.DOM.SHUNT_ON_GROUNDED]** `grounding`  
  Shunt 'grounding' is connected to terminal 'n' of bus 'sourcebus', which is perfectly grounded (V = 0) — the shunt draws G·V = 0 current and is inert. Drop the redundant shunt, or remove the perfect ground if impedance grounding was intended.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 27 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 27 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.PROV.NO_PI_SHUNT]** `linecode`  
  All 4 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  61 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.RED.MERGEABLE_LINES]** `line`  
  7 group(s) of series lines (14 lines total) can be merged — intermediate buses have no other connections.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground).

