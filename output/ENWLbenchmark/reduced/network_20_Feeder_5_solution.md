# BMOPF Solution Profile: network_20_Feeder_5

**Generated:** 2026-06-23 13:46:39  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -101.6061  
**Solve time:** 0.05 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.139 kW |
| Total load | 21.114 kW |
| Total network losses (P) | 25.16 W |
| Total network losses (Q) | 7.86 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.171 V (bus `44`) |

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
| ✅ | `41` | 240.0 V | 25 | 0.999 (`47`) | 1.0 (`sourcebus`) | 0.1 % (`48`) | 0.17 V (`44`) |

### Per-bus detail

**Zone `41`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `47` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.16 V |
| ✅ | `48` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `44` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.17 V |
| ✅ | `42` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `60` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
| ✅ | `63` | 240.0 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `45` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `51` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.09 V |
| ✅ | `54` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.09 V |
| ✅ | `57` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `56` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.09 V |
| ✅ | `53` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `59` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `50` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `62` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `41` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.07 V |
| ✅ | `64` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.06 V |
| ✅ | `58` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `49` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `52` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `61` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.06 V |
| ✅ | `43` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.06 V |
| ✅ | `55` | 240.0 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.02 V |
| ✅ | `46` | 240.0 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.02 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |
| W | `grid` | `2` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |
| W | `grid` | `3` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-42.228 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-42.228 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-42.228 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.17 V at bus '44' — reflects the neutral shift under unbalanced loading.

