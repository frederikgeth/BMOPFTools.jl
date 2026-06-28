# BMOPF Solution Profile: network_23_Feeder_3

**Generated:** 2026-06-23 13:46:41  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -6.3657  
**Solve time:** 0.006 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 2.279 kW |
| Total load | 2.274 kW |
| Total network losses (P) | 4.84 W |
| Total network losses (Q) | 0.84 W var |
| Loss fraction | 0.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.283 V (bus `57`) |

### Bound status

| Category | Violated | Active (≤1 %) |
|----------|:--------:|:-------------:|
| Voltage  | 0 | 0 |
| Thermal  | 0 | 0 |
| Generator| 0 | 3 |

## 2. Voltage by Galvanic Zone

Per-unit magnitudes are relative to each zone's own voltage base; volts are not comparable across transformer boundaries.

| St | Zone | V base | Buses | Vm min (pu) | Vm max (pu) | Max imbalance | Max neutral shift |
|:--:|------|-------:|------:|------------:|------------:|--------------:|------------------:|
| ✅ | `36` | 240.0 V | 5 | 0.999 (`57`) | 1.0 (`57`) | 0.1 % (`57`) | 0.28 V (`57`) |

### Per-bus detail

**Zone `36`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `57` | 239.9 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.28 V |
| ✅ | `56` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.08 V |
| ✅ | `58` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `36` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -4.548 kW | [-4.548 kW, 4.548 kW] |
| W | `grid` | `2` | pg | -4.548 kW | [-4.548 kW, 4.548 kW] |
| W | `grid` | `3` | pg | -4.548 kW | [-4.548 kW, 4.548 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-4.548 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-4.548 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-4.548 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.28 V at bus '57' — reflects the neutral shift under unbalanced loading.

