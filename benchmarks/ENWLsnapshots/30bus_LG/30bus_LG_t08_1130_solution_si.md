# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -104551.1724  
**Solve time:** 0.06 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 12.634 kW |
| Total load | 5.553 kW |
| Total network losses (P) | 7.081 kW |
| Total network losses (Q) | 2.622 kW var |
| Loss fraction | 127.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.802 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.057 (`92`) | 3.0 % (`92`) | 5.8 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 236.3 | 243.1 | 1.027 | 1.057 | 3.0 % | 5.8 V |
| ✅ | `95` | 236.3 | 243.1 | 1.027 | 1.057 | 3.0 % | 5.76 V |
| ✅ | `83` | 236.3 | 243.0 | 1.027 | 1.057 | 2.9 % | 5.69 V |
| ✅ | `98` | 236.3 | 242.9 | 1.027 | 1.056 | 2.9 % | 5.55 V |
| ✅ | `104` | 236.3 | 242.8 | 1.027 | 1.055 | 2.8 % | 5.41 V |
| ✅ | `101` | 236.3 | 242.8 | 1.027 | 1.055 | 2.8 % | 5.42 V |
| ✅ | `89` | 236.3 | 242.7 | 1.027 | 1.055 | 2.8 % | 5.3 V |
| ✅ | `86` | 236.3 | 242.6 | 1.027 | 1.055 | 2.8 % | 5.31 V |
| ✅ | `107` | 236.3 | 242.6 | 1.027 | 1.055 | 2.8 % | 5.28 V |
| ✅ | `80` | 236.3 | 242.4 | 1.027 | 1.054 | 2.6 % | 5.04 V |
| ✅ | `96` | 236.4 | 241.6 | 1.028 | 1.05 | 2.3 % | 2.91 V |
| ✅ | `105` | 236.4 | 241.5 | 1.028 | 1.05 | 2.2 % | 2.85 V |
| ✅ | `90` | 236.4 | 241.5 | 1.028 | 1.05 | 2.2 % | 2.83 V |
| ✅ | `87` | 236.4 | 241.4 | 1.028 | 1.049 | 2.2 % | 2.72 V |
| ✅ | `84` | 236.4 | 241.3 | 1.028 | 1.049 | 2.1 % | 2.7 V |
| ✅ | `102` | 236.4 | 241.1 | 1.028 | 1.048 | 2.0 % | 2.47 V |
| ✅ | `99` | 236.4 | 241.0 | 1.028 | 1.048 | 2.0 % | 2.44 V |
| ✅ | `81` | 236.4 | 241.0 | 1.028 | 1.048 | 2.0 % | 2.41 V |
| ✅ | `93` | 236.4 | 240.9 | 1.028 | 1.047 | 2.0 % | 2.4 V |
| ✅ | `100` | 237.9 | 240.1 | 1.034 | 1.044 | 1.0 % | 3.82 V |
| ✅ | `97` | 237.9 | 240.1 | 1.034 | 1.044 | 0.9 % | 3.79 V |
| ✅ | `91` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 3.71 V |
| ✅ | `88` | 237.9 | 239.8 | 1.034 | 1.042 | 0.8 % | 3.53 V |
| ✅ | `94` | 237.9 | 239.7 | 1.034 | 1.042 | 0.8 % | 3.49 V |
| ✅ | `82` | 237.9 | 239.7 | 1.034 | 1.042 | 0.8 % | 3.4 V |
| ✅ | `106` | 237.9 | 239.6 | 1.034 | 1.042 | 0.7 % | 3.39 V |
| ✅ | `85` | 237.9 | 239.6 | 1.034 | 1.042 | 0.7 % | 3.25 V |
| ✅ | `103` | 237.9 | 239.6 | 1.034 | 1.042 | 0.7 % | 3.13 V |
| ✅ | `79` | 236.4 | 239.5 | 1.028 | 1.041 | 1.4 % | 2.12 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.267 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=3.924 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.814 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=3.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=3.965 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=3.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.477 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.318 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.393 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=4.127 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.411 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.142 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.437 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=3.816 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.054 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.458 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.32 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.834 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 127.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.8 V at bus '92' — reflects the neutral shift under unbalanced loading.

