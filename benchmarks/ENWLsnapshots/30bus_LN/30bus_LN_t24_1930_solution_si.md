# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 5298.1289  
**Solve time:** 0.055 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 24.344 kW |
| Total load | 24.05 kW |
| Total network losses (P) | 293.82 W |
| Total network losses (Q) | 62.55 W var |
| Loss fraction | 1.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.696 V (bus `85`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.983 (`85`) | 1.001 (`102`) | 1.6 % (`85`) | 3.7 V (`85`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `85` | 226.1 | 229.9 | 0.983 | 0.999 | 1.6 % | 3.7 V |
| ✅ | `82` | 226.4 | 229.9 | 0.985 | 0.999 | 1.5 % | 3.37 V |
| ✅ | `103` | 227.4 | 229.9 | 0.989 | 1.0 | 1.1 % | 2.35 V |
| ✅ | `86` | 227.4 | 229.9 | 0.989 | 1.0 | 1.1 % | 1.31 V |
| ✅ | `80` | 227.6 | 229.9 | 0.99 | 1.0 | 1.0 % | 1.2 V |
| ✅ | `98` | 227.8 | 229.9 | 0.99 | 1.0 | 0.9 % | 1.06 V |
| ✅ | `94` | 228.4 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.34 V |
| ✅ | `104` | 228.5 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.27 V |
| ✅ | `92` | 228.5 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.28 V |
| ✅ | `107` | 228.5 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.27 V |
| ✅ | `95` | 228.5 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.31 V |
| ✅ | `89` | 228.5 | 229.9 | 0.993 | 1.0 | 0.6 % | 1.23 V |
| ✅ | `83` | 228.5 | 229.9 | 0.994 | 1.0 | 0.6 % | 1.17 V |
| ✅ | `93` | 228.5 | 228.9 | 0.994 | 0.995 | 0.2 % | 1.39 V |
| ✅ | `84` | 228.5 | 229.3 | 0.994 | 0.997 | 0.3 % | 1.2 V |
| ✅ | `79` | 228.5 | 229.9 | 0.994 | 1.0 | 0.6 % | 1.18 V |
| ✅ | `105` | 228.5 | 230.2 | 0.994 | 1.001 | 0.7 % | 1.48 V |
| ✅ | `81` | 228.5 | 230.2 | 0.994 | 1.001 | 0.7 % | 1.49 V |
| ✅ | `90` | 228.5 | 230.2 | 0.994 | 1.001 | 0.7 % | 1.51 V |
| ✅ | `99` | 228.5 | 230.2 | 0.994 | 1.001 | 0.7 % | 1.5 V |
| ✅ | `87` | 228.5 | 230.3 | 0.994 | 1.001 | 0.8 % | 1.54 V |
| ✅ | `96` | 228.5 | 230.3 | 0.994 | 1.001 | 0.8 % | 1.56 V |
| ✅ | `102` | 228.5 | 230.3 | 0.994 | 1.001 | 0.8 % | 1.59 V |
| ✅ | `101` | 228.5 | 229.9 | 0.994 | 1.0 | 0.6 % | 0.88 V |
| ✅ | `97` | 228.8 | 229.9 | 0.995 | 1.0 | 0.5 % | 0.97 V |
| ✅ | `91` | 228.8 | 229.9 | 0.995 | 1.0 | 0.5 % | 0.96 V |
| ✅ | `100` | 228.8 | 229.9 | 0.995 | 1.0 | 0.5 % | 0.94 V |
| ✅ | `88` | 228.8 | 229.9 | 0.995 | 1.0 | 0.5 % | 0.93 V |
| ✅ | `106` | 228.9 | 229.9 | 0.995 | 1.0 | 0.4 % | 0.84 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=624.38 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=722.11 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=653.91 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=627.82 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=644.49 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=630.83 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=733.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=676.07 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=729.99 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=739.79 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=728.59 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=753.51 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=710.67 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=710.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=647.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=681.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=678.96 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=697.62 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=668.41 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=624.01 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=624.13 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=709.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=649.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=739.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=737.1 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=633.31 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=628.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=639.73 W is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 3.7 V at bus '85' — reflects the neutral shift under unbalanced loading.

