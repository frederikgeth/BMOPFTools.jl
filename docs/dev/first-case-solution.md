# BMOPF Solution Profile: case_development_example

**Generated:** 2026-10-30 01:09:43  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 1.9568  
**Solve time:** 0.017 s  
**Findings:** 0 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Assessed checks | checks_passed |
| Unassessed dimensions | branch_and_device_equations, terminal_kcl, objective_optimality, independent_loss_reconstruction, complete_limit_coverage |
| Total generation | 7.827 kW |
| Total load | 7.8 kW |
| Total network losses (P) | 27.1 W |
| Total network losses (Q) | 4.84 W var |
| Loss fraction | 0.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.352 V (bus `far`) |

### Bound status

| Category | Violated | Active (≤1 %) |
|----------|:--------:|:-------------:|
| Voltage  | 0 | 0 |
| Thermal  | 0 | 0 |
| Generator| 0 | 0 |

## 2. Voltage by Galvanic Zone

Per-unit magnitudes are relative to each zone's own voltage base; volts are not comparable across transformer boundaries.

| St | Zone | V base | Buses | Vm min (pu) | Vm max (pu) | Max imbalance | Max neutral shift |
|:--:|------|-------:|------:|------------:|------------:|--------------:|------------------:|
| ✅ | `far` | 230.0 V | 4 | 0.995 (`far`) | 1.0 (`source`) | 0.2 % (`far`) | 0.35 V (`far`) |

### Per-bus detail

**Zone `far`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `far` | 228.8 | 229.2 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `joint` | 229.1 | 229.4 | 0.996 | 0.997 | 0.1 % | 0.25 V |
| ✅ | `near` | 229.4 | 229.6 | 0.997 | 0.998 | 0.1 % | 0.16 V |
| ✅ | `source` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## Optimization Profile

| Metric | Value |
|--------|-------|
| Variables | 76 |
| Equality constraints | 76 |
| Inequality constraints | 72 |
| Variables minus equalities (count proxy) | 0 |
| Active (binding) constraints | 0 |
| Any assessed inequality binds | false |
| Strict complementarity screen (solver scaling) | true |
| Weakly active inequalities | 0 |
| Barrier iterations | 2 |
| Solve time (s) | 0.01749706268310547 |

## 6. All Findings

- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A. IBR: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.35 V at bus 'far' — reflects the neutral shift under unbalanced loading.

