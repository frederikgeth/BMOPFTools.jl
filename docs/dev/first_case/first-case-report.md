# BMOPF Network Summary: case_development_example

**Generated:** 2026-10-25 11:19:03  
**Findings:** 0 errors · 2 warnings · 12 info  
**Convention:** LV_230V: 4-wire; 1 grounding point(s); series-only line model

---

## 1. Component Inventory

| Component | Count | Notes |
|-----------|------:|-------|
| bus | 4 |  |
| line | 3 |  |
| linecode | 1 |  |
| voltage_source | 1 |  |
| load | 2 | 7.8 kW, 1.6 kvar |
| generator | 0 | capacity: 0.0 W |
| shunt | 0 |  |
| switch | 0 |  |
| transformer | 0 |  |
| ibr | 0 | capacity: 0.0 MVA |
| control_profile | 0 |  |

## 2. Voltage Levels

**Voltage levels identified:** 1

| Level | Nominal | Buses | Lines | Loads | Generators |
|-------|---------|------:|------:|------:|-----------:|
| LV_230V | 230.0 V | 4 | 3 | 2 | 0 |

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

### Physical branch structure

| Scope | Buses | Components | Branches | Simple cycles | Parallel excess | Total cycle rank |
|---|---:|---:|---:|---:|---:|---:|
| Whole network | 4 | 1 | 3 | 0 | 0 | 0 |
| Tier LV_230V | 4 | 1 | 3 | 0 | 0 | 0 |

Transformer-mediated cycle rank: 0; cross-tier branches: 0; skipped invalid branches: 0.

Galvanic zones: 1; zones with simple cycles: 0; zones incident to multiple isolating transformers: 0.

Parallel line groups: 0. Classification counts: different_declared_fields=0, incomplete_terminal_map=0, same_declared_fields=0, terminal_map_disagreement=0.

### Mapped conductor paths

16 declared bus terminals; 12 mapped line/closed-switch conductor edges; 4 terminal-path components; 0 incomplete branch maps. Transformer winding ports bound these paths; winding conversion is unassessed.

Load terminals in paths without a source or transformer port: 2.

- `far` at far:n (path 4)
- `near` at near:n (path 4)

### Switch-state bus graph

inapplicable: No switch records.

### Switch-state mapped conductor paths

inapplicable: No switch records.

## 4. Diversity & Variance

**Overall symmetry score:** LOW

### load

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| p_nom | 900.0 | 1800.0 | 0.315 | 6 |
| q_nom | 180.0 | 360.0 | 0.315 | 6 |

### line

| Parameter | Min | Max | CV | n |
|-----------|-----|-----|----|---|
| length | 60.0 | 80.0 | 0.173 | 3 |

> 🔵 **[I.DIV.LOAD_IMBALANCE]** Load 'near' has phase imbalance of 69.2%.
> 🔵 **[I.DIV.LOAD_IMBALANCE]** Load 'far' has phase imbalance of 69.2%.

## 5. Loading & Operational Summary

| | Value |
|--|-------|
| Total load P | 7.8 kW |
| Total load Q | 1.6 kvar |
| Total gen capacity | 0.0 W |
| Generation/load ratio | 0.0% |

> 🟡 **[W.OPS.IMPORT_DEPENDENT]** Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).

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

**Inferred convention:** LV_230V: 4-wire; 1 grounding point(s); series-only line model

| Voltage level | Wires | Buses with neutral |
|---------------|-------|-------------------:|
| LV_230V | 4-wire | 4 / 4 |

| Neutral grounding | Value |
|-------------------|------:|
| Buses with neutral | 4 |
| Neutral branches | 3 |
| Grounding points | 1 |
| Neutral sections | 1 |
| Floating sections | 0 |

**Linecode impedance classification:**

| Verdict | Count |
|---------|------:|
| exactly_balanced | 1 |

**Line model topology:**

| Topology | Count |
|----------|------:|
| pure series | 1 |

**OpenDSS default fingerprints:** none detected ✓

**Earthing system per galvanic zone:**

| Zone | Buses | Wires | Star point | Downstream earths | Likely system |
|------|------:|-------|------------|------------------:|---------------|
| 230.0 V | 4 | 4-wire | solid | 0 | TN-S or TT (source-earthed only — protective-earth side not representable in the data model) |

> 🔵 **[I.PROV.SEQ_DERIVED]** 1 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: cable.
> 🔵 **[I.PROV.LINE_MODEL_UNIFORM]** All 1 line-model definition(s) use a single, consistent model: pure series impedance. Shunt charging is neglected network-wide — expected for LV / short-cable networks, but worth confirming for feeders with long MV/HV overhead or underground-cable sections.

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
| Line impedance spread | 1.33× |

| Benchmark readiness | Value |
|---------------------|------:|
| Objective well-posed | true |
| Only slack generation | true |
| Buses with \|V\| bounds | 0.0% |
| Buses with vpn / vpp / vpos bounds | 3 / 0 / 0 |
| Lines with thermal limits | 100.0% |
| Generators with no DOF (p\_min≈p\_max) | 0 |
| Generators with zero cost (dispatchable) | 0 |
| Same-cost generator pairs (≤1 hop) | 0 |
| Loads with zero p\_nom | 0 |

**Augmentation needed:**

- only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds
- no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground)

> 🔵 **[I.SPEC.MATRIX_TRIANGULAR]** 1 linecode(s) store impedance matrices upper-triangular; spec §4.1.1 defines full row-first storage: cable.

> 🔵 **[I.BENCH.AUGMENTATION]** Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground).

## 9. Data Quality Summary

**Total findings:** 14 (0 errors, 2 warnings, 12 info)

### 🟡 Warnings

- **[W.OPS.IMPORT_DEPENDENT]** `network`  
  Network is heavily import-dependent: local generation capacity (0.0 MW) is less than 5% of total load (0.01 MW).
- **[W.CONV.TERMINAL_ROLES_INFERRED]** `network`  
  No terminal_conventions block: legacy bus-name inference is used where terminal names can be assessed.

### 🔵 Info

- **[I.DIV.LOAD_IMBALANCE]** `near`  
  Load 'near' has phase imbalance of 69.2%.
- **[I.DIV.LOAD_IMBALANCE]** `far`  
  Load 'far' has phase imbalance of 69.2%.
- **[I.PROV.SEQ_DERIVED]** `linecode`  
  1 linecode(s) have exactly balanced impedance matrices (equal self, equal mutual entries) — likely constructed from sequence parameters (r1,x1,r0,x0) or a transposition assumption, not from conductor geometry: cable.
- **[I.PROV.LINE_MODEL_UNIFORM]** `linecode`  
  All 1 line-model definition(s) use a single, consistent model: pure series impedance. Shunt charging is neglected network-wide — expected for LV / short-cable networks, but worth confirming for feeders with long MV/HV overhead or underground-cable sections.
- **[I.PRE.NO_VOLT_BOUNDS]** `bus`  
  4 bus(es) have no voltage bounds — voltage will be unconstrained at these buses.
- **[I.PRE.SINGLE_SOURCE]** `network`  
  Network has a single voltage source — single point of failure. Infeasibility of the source makes the entire network infeasible.
- **[I.SCHEMA.VERSION_UNKNOWN]** `network`  
  Spec version 'unknown' has no bundled JSON Schema; structural validation skipped. Unknown-field catalogue still runs.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `bus`  
  bus has field(s) not in the BMOPF schema: v_declared.
- **[I.SCHEMA.UNKNOWN_FIELDS]** `network`  
  meta has field(s) not in the BMOPF schema: source.
- **[I.RED.MERGEABLE_LINES]** `line`  
  1 group(s) of series lines (2 lines total) can be merged — intermediate buses have no other connections.
- **[I.SPEC.MATRIX_TRIANGULAR]** `linecode`  
  1 linecode(s) store impedance matrices upper-triangular; spec §4.1.1 defines full row-first storage: cable.
- **[I.BENCH.AUGMENTATION]** `network`  
  Case needs augmentation to be a non-trivial OPF benchmark: only slack generation — dispatch is trivial (loss minimisation); add dispatchable DERs with diverse costs and p/q bounds; no voltage magnitude bounds on any bus — voltage is unconstrained; add v_min/v_max (phase-to-ground).

