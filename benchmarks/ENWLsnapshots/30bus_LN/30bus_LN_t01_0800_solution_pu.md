# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:23  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 15243.3973  
**Solve time:** 0.076 s  
**Findings:** 28 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 15.244 kW |
| Total load | 14.991 kW |
| Total network losses (P) | 252.86 W |
| Total network losses (Q) | 75.44 W var |
| Loss fraction | 1.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 2.506 V (bus `85`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.985 (`85`) | 1.0 (`sourcebus`) | 1.1 % (`85`) | 2.51 V (`85`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `85` | 226.5 | 229.0 | 0.985 | 0.996 | 1.1 % | 2.51 V |
| ✅ | `82` | 226.6 | 229.0 | 0.985 | 0.996 | 1.0 % | 2.36 V |
| ✅ | `86` | 226.9 | 229.0 | 0.986 | 0.996 | 0.9 % | 1.36 V |
| ✅ | `98` | 227.0 | 229.0 | 0.987 | 0.996 | 0.9 % | 1.22 V |
| ✅ | `80` | 227.1 | 229.0 | 0.987 | 0.996 | 0.9 % | 1.19 V |
| ✅ | `103` | 227.1 | 229.0 | 0.987 | 0.996 | 0.8 % | 1.9 V |
| ✅ | `101` | 227.5 | 229.0 | 0.989 | 0.996 | 0.6 % | 0.83 V |
| ✅ | `94` | 227.8 | 229.0 | 0.99 | 0.996 | 0.5 % | 1.21 V |
| ✅ | `93` | 227.8 | 228.3 | 0.99 | 0.993 | 0.2 % | 0.83 V |
| ✅ | `83` | 227.9 | 229.0 | 0.991 | 0.996 | 0.5 % | 0.69 V |
| ✅ | `104` | 228.0 | 229.0 | 0.991 | 0.996 | 0.5 % | 0.68 V |
| ✅ | `89` | 228.0 | 229.0 | 0.991 | 0.996 | 0.5 % | 0.68 V |
| ✅ | `107` | 228.0 | 229.0 | 0.991 | 0.996 | 0.5 % | 0.68 V |
| ✅ | `92` | 228.0 | 229.0 | 0.991 | 0.996 | 0.4 % | 0.68 V |
| ✅ | `95` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.69 V |
| ✅ | `97` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.9 V |
| ✅ | `88` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.89 V |
| ✅ | `100` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.88 V |
| ✅ | `91` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.87 V |
| ✅ | `106` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.86 V |
| ✅ | `79` | 228.1 | 229.0 | 0.992 | 0.996 | 0.4 % | 0.7 V |
| ✅ | `102` | 228.1 | 228.9 | 0.992 | 0.995 | 0.3 % | 0.59 V |
| ✅ | `87` | 228.1 | 228.9 | 0.992 | 0.995 | 0.3 % | 0.58 V |
| ✅ | `96` | 228.1 | 228.9 | 0.992 | 0.995 | 0.3 % | 0.58 V |
| ✅ | `99` | 228.1 | 228.9 | 0.992 | 0.995 | 0.3 % | 0.57 V |
| ✅ | `105` | 228.1 | 228.8 | 0.992 | 0.995 | 0.3 % | 0.56 V |
| ✅ | `90` | 228.1 | 228.8 | 0.992 | 0.995 | 0.3 % | 0.56 V |
| ✅ | `81` | 228.1 | 228.8 | 0.992 | 0.995 | 0.3 % | 0.56 V |
| ✅ | `84` | 228.1 | 228.3 | 0.992 | 0.993 | 0.1 % | 0.47 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 2.51 V at bus '85' — reflects the neutral shift under unbalanced loading.

