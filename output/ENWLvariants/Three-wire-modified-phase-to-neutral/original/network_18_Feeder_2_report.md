# BMOPF Network Summary: Three-wire-modified-phase-to-neutral / network_18 / Feeder_2

**Generated:** 2026-06-23 21:31:34  
**Findings:** 0 errors · 3 warnings · 54 info  
**Convention:** LV_240V: mixed; implicit (Kron-style) grounding

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 991 |  |
| line | 990 |  |
| linecode | 5 |  |
| voltage_source | 1 |  |
| load | 24 | 23.07 kW, 7.6 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 0 |  |
| inverter | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_240V | 240.0 V | 991 | 990 | 24 | 0 |

## 3. Connectivity & Topology

| Property | Value |
|----------|-------|
| Connected components | 1 |
| Fully connected | true |
| Topology | Radial |
| Mean degree | 2.0 |
| Max degree | 3 |
| Degree-1 buses | 35 |
| Tree depth (max hops) | 186 |

> 🟡 **[W.CONN.DANGLING]** 10 bus(es) are degree-1 with no attached load, generator, or shunt.

## 4. Diversity & Variance

**Overall symmetry score:** LOW

### load

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 114.0 | 3050.0 | 0.976 | 24 |
| q_nom | 37.5 | 1000.0 | 0.976 | 24 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 0.0312 | 17.0 | 2.046 | 990 |

### linecode

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| R_series_1_1 | 0.00113 | 0.00455 | 0.697 | 5 |

> 🔵 **[I.DIV.LOAD_UNIFORM_MODEL]** All 24 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
> 🔵 **[I.DIV.LOAD_UNIFORM_CONFIG]** All 24 loads share the 'SINGLE_PHASE' configuration — no connection diversity.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 23.07 kW |
| Total load Q | 7.6 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.02 MW).

## 6. Infeasibility Pre-flight

| Check | Result |
|-------|--------|
| Import dependent | true |
| Constraint conflicts | 0 |
| Buses without voltage bounds | 991 |
| Single point of failure | true |
| TPIA status | not_run |

> 🔵 **[I.PRE.NO_VOLT_BOUNDS]** 991 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
> 🔵 **[I.PRE.SINGLE_SOURCE]** Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.

## 7. Provenance & Model Conventions

**Inferred convention:** LV_240V: mixed; implicit (Kron-style) grounding

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_240V | mixed | 25 / 991 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 25 |
| Neutral branches | 0 |
| Grounding points | 1 |
| Neutral sections | 25 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| near_balanced | 4 |
| exactly_balanced | 1 |

**OpenDSS default fingerprints:** 1 hit(s) — see findings

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 240.0 V | 991 | ≤3-wire | solid | 0 | indeterminate (3-wire / Kron-style implicit grounding) |

> 🔵 **[I.PROV.SEQ_DERIVED]** 1 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: lc9.
> 🔵 **[I.PROV.NO_PI_SHUNT]** All 5 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
> 🟡 **[W.PROV.IMPLICIT_GROUNDING]** No branch carries a neutral conductor, but 24 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.
> 🔵 **[I.PROV.DSS_DEFAULT_LENGTH]** 1 of 990 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
> 🔵 **[I.PROV.IMPEDANCE_TRANSFORM_MPN]** 5 three-wire linecode(s) match the impedance signature of modified phase-to-neutral approximation — both R and X blocks are circulant with mutual ≈ ½ self. X is further symmetrised relative to the standard phase-to-neutral form, introducing additional modelling error particularly for asymmetric cable geometries.: lc2, lc4, lc5, lc6, lc9.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line198' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line2' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line204' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line210' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line217' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line224' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line240' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line247' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line248' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line3' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line309' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line327' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line332' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line336' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line345' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line354' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line364' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line374' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line385' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line4' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line619' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line649' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line662' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line670' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line675' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line683' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line688' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line7' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line701' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line709' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line71' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line715' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line728' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line736' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line737' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line741' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line748' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line753' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line764' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line773' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
> 🔵 **[I.PROV.LINE_SWITCH_LIKE]** Line 'line782' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.

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
| Line impedance spread | 1430.0× |

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

**Total findings:** 57 (0 errors, 3 warnings, 54 info)

### 🟡 Warnings

- **[W.CONN.DANGLING]** `bus`  
  10 bus(es) are degree-1 with no attached load, generator, or shunt.
- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.02 MW).
- **[W.PROV.IMPLICIT_GROUNDING]** `network`  
  No branch carries a neutral conductor, but 24 bus(es) have components referencing terminal 'n' without an explicit grounding — the model implicitly assumes every bus is grounded (Kron-style convention). Make this assumption explicit.

### 🔵 Info

- **[I.DIV.LOAD_UNIFORM_MODEL]** `load`  
  All 24 loads use the constant_power model — no load exercises voltage dependence (ZIP/exponential); the case does not test voltage-dependent load behaviour.
- **[I.DIV.LOAD_UNIFORM_CONFIG]** `load`  
  All 24 loads share the 'SINGLE_PHASE' configuration — no connection diversity.
- **[I.PROV.SEQ_DERIVED]** `linecode`  
  1 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: lc9.
- **[I.PROV.NO_PI_SHUNT]** `linecode`  
  All 5 linecode(s) have no π-shunt admittance (G_from/B_from/G_to/B_to absent or zero) — the line model reduces to a series impedance only. Shunt capacitance is typically negligible for short LV cables but may be significant for long MV/HV lines.
- **[I.PROV.DSS_DEFAULT_LENGTH]** `line`  
  1 of 990 line(s) have length exactly 1.0 among otherwise varied lengths — the OpenDSS default; these lengths were likely never set.
- **[I.PROV.IMPEDANCE_TRANSFORM_MPN]** `linecode`  
  5 three-wire linecode(s) match the impedance signature of modified phase-to-neutral approximation — both R and X blocks are circulant with mutual ≈ ½ self. X is further symmetrised relative to the standard phase-to-neutral form, introducing additional modelling error particularly for asymmetric cable geometries.: lc2, lc4, lc5, lc6, lc9.
- **[I.PROV.LINE_SWITCH_LIKE]** `line198`  
  Line 'line198' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line2`  
  Line 'line2' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line204`  
  Line 'line204' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line210`  
  Line 'line210' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line217`  
  Line 'line217' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line224`  
  Line 'line224' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line240`  
  Line 'line240' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line247`  
  Line 'line247' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line248`  
  Line 'line248' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line256`  
  Line 'line256' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line268`  
  Line 'line268' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line3`  
  Line 'line3' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line309`  
  Line 'line309' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line327`  
  Line 'line327' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line332`  
  Line 'line332' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line336`  
  Line 'line336' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line345`  
  Line 'line345' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line354`  
  Line 'line354' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line364`  
  Line 'line364' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line374`  
  Line 'line374' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line385`  
  Line 'line385' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line4`  
  Line 'line4' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line619`  
  Line 'line619' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line649`  
  Line 'line649' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line662`  
  Line 'line662' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line670`  
  Line 'line670' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line675`  
  Line 'line675' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line683`  
  Line 'line683' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line688`  
  Line 'line688' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line7`  
  Line 'line7' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line701`  
  Line 'line701' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line709`  
  Line 'line709' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line71`  
  Line 'line71' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line715`  
  Line 'line715' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line728`  
  Line 'line728' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line736`  
  Line 'line736' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line737`  
  Line 'line737' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line741`  
  Line 'line741' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line748`  
  Line 'line748' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line753`  
  Line 'line753' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line764`  
  Line 'line764' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line773`  
  Line 'line773' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PROV.LINE_SWITCH_LIKE]** `line782`  
  Line 'line782' has near-zero series impedance and may be modelled more accurately as a switch: effective impedance (Z·length) < 0.0001 Ω on all diagonals.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  991 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.RED.MERGEABLE_LINES]** `line`  
  49 group(s) of series lines (972 lines total) can be merged — intermediate buses have no other connections.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: no priced slack or generator — the generation-cost objective is degenerate; add a cost to the voltage source at the source bus (augment_case does this by default) or dispatchable DERs; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground); no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — sequence bounds also improve solver robustness for 4-wire OPF.

