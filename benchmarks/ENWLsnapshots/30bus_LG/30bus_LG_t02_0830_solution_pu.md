# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:19  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -5773.4151  
**Solve time:** 0.034 s  
**Findings:** 28 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.583 kW |
| Total load | 13.48 kW |
| Total network losses (P) | 103.18 W |
| Total network losses (Q) | 28.55 W var |
| Loss fraction | 0.8% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.827 V (bus `82`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.995 (`82`) | 1.005 (`99`) | 0.8 % (`82`) | 1.83 V (`82`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `82` | 228.7 | 230.6 | 0.995 | 1.003 | 0.8 % | 1.83 V |
| ✅ | `99` | 229.7 | 231.2 | 0.999 | 1.005 | 0.6 % | 1.24 V |
| ✅ | `85` | 228.8 | 230.6 | 0.995 | 1.003 | 0.8 % | 1.74 V |
| ✅ | `87` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.22 V |
| ✅ | `90` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.21 V |
| ✅ | `105` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.2 V |
| ✅ | `81` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.16 V |
| ✅ | `102` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.15 V |
| ✅ | `96` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.15 V |
| ✅ | `95` | 229.7 | 230.9 | 0.999 | 1.004 | 0.5 % | 1.16 V |
| ✅ | `107` | 229.7 | 230.8 | 0.999 | 1.003 | 0.5 % | 1.07 V |
| ✅ | `89` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.03 V |
| ✅ | `92` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.03 V |
| ✅ | `103` | 229.3 | 230.6 | 0.997 | 1.003 | 0.6 % | 1.24 V |
| ✅ | `83` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.0 V |
| ✅ | `104` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 0.99 V |
| ✅ | `98` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.42 V |
| ✅ | `80` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.4 V |
| ✅ | `106` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.31 V |
| ✅ | `91` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.32 V |
| ✅ | `86` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.42 V |
| ✅ | `100` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.36 V |
| ✅ | `88` | 230.1 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.38 V |
| ✅ | `97` | 230.1 | 230.6 | 1.0 | 1.003 | 0.2 % | 0.43 V |
| ✅ | `94` | 229.9 | 230.6 | 0.999 | 1.003 | 0.3 % | 0.66 V |
| ✅ | `79` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.8 V |
| ✅ | `101` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.74 V |
| ✅ | `84` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.97 V |
| ✅ | `93` | 229.7 | 230.3 | 0.999 | 1.001 | 0.2 % | 0.95 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=725.73 W violates [0.0 W, 725.72 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=739.96 W violates [0.0 W, 739.95 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=718.55 W violates [0.0 W, 718.54 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=630.29 W violates [0.0 W, 630.28 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=668.42 W violates [0.0 W, 668.41 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=666.93 W violates [0.0 W, 666.92 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=638.63 W violates [0.0 W, 638.62 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=652.29 W violates [0.0 W, 652.28 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=721.29 W violates [0.0 W, 721.28 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=737.46 W violates [0.0 W, 737.45 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=733.4 W violates [0.0 W, 733.39 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=636.02 W violates [0.0 W, 636.01 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=627.41 W violates [0.0 W, 627.4 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=645.59 W violates [0.0 W, 645.58 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=627.83 W violates [0.0 W, 627.82 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=722.73 W violates [0.0 W, 722.72 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=747.84 W violates [0.0 W, 747.83 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=702.01 W violates [0.0 W, 702.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=727.17 W violates [0.0 W, 727.16 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=736.52 W violates [0.0 W, 736.51 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=678.97 W violates [0.0 W, 678.96 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=630.18 W violates [0.0 W, 630.17 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=749.96 W violates [0.0 W, 749.95 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=691.78 W violates [0.0 W, 691.77 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=697.04 W violates [0.0 W, 697.03 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=632.73 W violates [0.0 W, 632.72 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=730.0 W violates [0.0 W, 729.99 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=739.81 W violates [0.0 W, 739.8 W].
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.83 V at bus '82' — reflects the neutral shift under unbalanced loading.

