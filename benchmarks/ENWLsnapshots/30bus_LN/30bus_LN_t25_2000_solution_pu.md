# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 22080.2782  
**Solve time:** 0.078 s  
**Findings:** 28 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 22.081 kW |
| Total load | 21.55 kW |
| Total network losses (P) | 530.57 W |
| Total network losses (Q) | 157.33 W var |
| Loss fraction | 2.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.612 V (bus `85`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.978 (`85`) | 1.0 (`sourcebus`) | 1.6 % (`85`) | 3.61 V (`85`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `85` | 224.9 | 228.5 | 0.978 | 0.994 | 1.6 % | 3.61 V |
| ✅ | `82` | 225.0 | 228.5 | 0.978 | 0.994 | 1.5 % | 3.56 V |
| ✅ | `86` | 225.6 | 228.6 | 0.981 | 0.994 | 1.3 % | 1.87 V |
| ✅ | `80` | 225.7 | 228.6 | 0.981 | 0.994 | 1.2 % | 1.73 V |
| ✅ | `98` | 225.8 | 228.6 | 0.982 | 0.994 | 1.2 % | 1.64 V |
| ✅ | `103` | 226.0 | 228.5 | 0.983 | 0.994 | 1.1 % | 2.49 V |
| ✅ | `101` | 226.4 | 228.6 | 0.985 | 0.994 | 0.9 % | 1.17 V |
| ✅ | `94` | 226.8 | 228.5 | 0.986 | 0.994 | 0.8 % | 1.71 V |
| ✅ | `93` | 226.8 | 227.5 | 0.986 | 0.989 | 0.3 % | 1.24 V |
| ✅ | `83` | 227.0 | 228.6 | 0.987 | 0.994 | 0.7 % | 0.94 V |
| ✅ | `104` | 227.1 | 228.6 | 0.987 | 0.994 | 0.6 % | 0.94 V |
| ✅ | `89` | 227.1 | 228.5 | 0.987 | 0.994 | 0.6 % | 0.94 V |
| ✅ | `107` | 227.1 | 228.5 | 0.987 | 0.994 | 0.6 % | 0.94 V |
| ✅ | `92` | 227.1 | 228.5 | 0.987 | 0.994 | 0.6 % | 0.94 V |
| ✅ | `100` | 227.2 | 228.5 | 0.988 | 0.994 | 0.6 % | 1.25 V |
| ✅ | `91` | 227.2 | 228.5 | 0.988 | 0.994 | 0.6 % | 1.25 V |
| ✅ | `95` | 227.2 | 228.5 | 0.988 | 0.994 | 0.6 % | 0.94 V |
| ✅ | `88` | 227.2 | 228.5 | 0.988 | 0.994 | 0.6 % | 1.23 V |
| ✅ | `97` | 227.3 | 228.5 | 0.988 | 0.994 | 0.6 % | 1.22 V |
| ✅ | `106` | 227.3 | 228.5 | 0.988 | 0.994 | 0.5 % | 1.19 V |
| ✅ | `79` | 227.3 | 228.5 | 0.988 | 0.994 | 0.5 % | 0.96 V |
| ✅ | `102` | 227.3 | 228.4 | 0.988 | 0.993 | 0.5 % | 0.82 V |
| ✅ | `99` | 227.3 | 228.3 | 0.988 | 0.993 | 0.5 % | 0.81 V |
| ✅ | `96` | 227.3 | 228.3 | 0.988 | 0.993 | 0.4 % | 0.79 V |
| ✅ | `81` | 227.3 | 228.3 | 0.988 | 0.993 | 0.4 % | 0.78 V |
| ✅ | `90` | 227.3 | 228.3 | 0.988 | 0.993 | 0.4 % | 0.78 V |
| ✅ | `87` | 227.3 | 228.3 | 0.988 | 0.993 | 0.4 % | 0.77 V |
| ✅ | `105` | 227.3 | 228.2 | 0.988 | 0.992 | 0.4 % | 0.75 V |
| ✅ | `84` | 227.3 | 227.5 | 0.988 | 0.989 | 0.1 % | 0.77 V |
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
  Maximum neutral terminal voltage: 3.61 V at bus '85' — reflects the neutral shift under unbalanced loading.

