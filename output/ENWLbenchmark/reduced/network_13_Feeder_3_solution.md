# BMOPF Solution Profile: network_13_Feeder_3

**Generated:** 2026-06-23 13:46:17  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -3.2608  
**Solve time:** 0.01 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 2.277 kW |
| Total load | 2.274 kW |
| Total network losses (P) | 3.17 W |
| Total network losses (Q) | 0.68 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.186 V (bus `84`) |

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
| ✅ | `107` | 240.0 V | 6 | 0.999 (`84`) | 1.0 (`84`) | 0.1 % (`84`) | 0.19 V (`84`) |

### Per-bus detail

**Zone `107`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `84` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.19 V |
| ✅ | `81` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.08 V |
| ✅ | `107` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.06 V |
| ✅ | `36` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `59` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.05 V |
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
  Maximum neutral terminal voltage: 0.19 V at bus '84' — reflects the neutral shift under unbalanced loading.

