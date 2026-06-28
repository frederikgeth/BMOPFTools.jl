# BMOPF Solution Profile: network_20_Feeder_4

**Generated:** 2026-06-23 13:46:39  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -134.9131  
**Solve time:** 0.029 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 24.624 kW |
| Total load | 24.594 kW |
| Total network losses (P) | 29.73 W |
| Total network losses (Q) | 13.29 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.131 V (bus `47`) |

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
| ✅ | `41` | 240.0 V | 31 | 0.999 (`60`) | 1.0 (`sourcebus`) | 0.1 % (`60`) | 0.13 V (`47`) |

### Per-bus detail

**Zone `41`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `60` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.07 V |
| ✅ | `48` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.07 V |
| ✅ | `42` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.06 V |
| ✅ | `47` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `44` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `63` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.05 V |
| ✅ | `65` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.09 V |
| ✅ | `45` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `66` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `51` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `69` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `54` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `57` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `56` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.07 V |
| ✅ | `62` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.06 V |
| ✅ | `50` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `68` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `53` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `59` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `41` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `64` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `49` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `61` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `43` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `52` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `67` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `70` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `58` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `46` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.03 V |
| ✅ | `55` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.02 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -49.188 kW | [-49.188 kW, 49.188 kW] |
| W | `grid` | `2` | pg | -49.188 kW | [-49.188 kW, 49.188 kW] |
| W | `grid` | `3` | pg | -49.188 kW | [-49.188 kW, 49.188 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-49.188 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-49.188 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-49.188 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.13 V at bus '47' — reflects the neutral shift under unbalanced loading.

