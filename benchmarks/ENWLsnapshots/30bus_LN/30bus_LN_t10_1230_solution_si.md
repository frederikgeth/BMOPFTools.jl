# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -119625.3668  
**Solve time:** 0.086 s  
**Findings:** 0 errors · 22 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 15.86 kW |
| Total load | 5.868 kW |
| Total network losses (P) | 9.992 kW |
| Total network losses (Q) | 3.619 kW var |
| Loss fraction | 170.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.707 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.058 (`95`) | 3.2 % (`95`) | 6.71 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 235.9 | 243.4 | 1.026 | 1.058 | 3.2 % | 6.71 V |
| ✅ | `89` | 235.9 | 243.4 | 1.026 | 1.058 | 3.2 % | 6.69 V |
| ✅ | `107` | 235.9 | 243.4 | 1.026 | 1.058 | 3.2 % | 6.68 V |
| ✅ | `101` | 235.9 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.59 V |
| ✅ | `104` | 235.9 | 243.2 | 1.026 | 1.057 | 3.2 % | 6.53 V |
| ✅ | `92` | 235.9 | 243.2 | 1.026 | 1.057 | 3.1 % | 6.47 V |
| ✅ | `80` | 235.9 | 243.1 | 1.026 | 1.057 | 3.1 % | 6.42 V |
| ✅ | `99` | 236.0 | 243.0 | 1.026 | 1.056 | 3.0 % | 2.9 V |
| ✅ | `87` | 236.0 | 243.0 | 1.026 | 1.056 | 3.0 % | 2.9 V |
| ✅ | `81` | 236.0 | 243.0 | 1.026 | 1.056 | 3.0 % | 2.9 V |
| ✅ | `105` | 236.0 | 243.0 | 1.026 | 1.056 | 3.0 % | 2.89 V |
| ✅ | `83` | 235.9 | 242.9 | 1.026 | 1.056 | 3.0 % | 6.24 V |
| ✅ | `102` | 236.0 | 242.8 | 1.026 | 1.056 | 3.0 % | 2.74 V |
| ✅ | `84` | 236.0 | 242.7 | 1.026 | 1.055 | 2.9 % | 2.64 V |
| ✅ | `86` | 236.0 | 242.6 | 1.026 | 1.055 | 2.9 % | 5.95 V |
| ✅ | `98` | 236.0 | 242.6 | 1.026 | 1.055 | 2.9 % | 5.95 V |
| ✅ | `96` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 2.43 V |
| ✅ | `93` | 236.0 | 242.4 | 1.026 | 1.054 | 2.8 % | 2.47 V |
| ✅ | `90` | 236.0 | 242.4 | 1.026 | 1.054 | 2.8 % | 2.33 V |
| ✅ | `100` | 238.8 | 240.2 | 1.038 | 1.044 | 0.6 % | 4.75 V |
| ✅ | `94` | 238.8 | 240.2 | 1.038 | 1.044 | 0.6 % | 4.72 V |
| ✅ | `88` | 238.8 | 240.0 | 1.038 | 1.044 | 0.5 % | 4.56 V |
| ✅ | `106` | 238.8 | 239.9 | 1.038 | 1.043 | 0.4 % | 4.44 V |
| ✅ | `97` | 238.8 | 239.7 | 1.038 | 1.042 | 0.4 % | 4.32 V |
| ✅ | `91` | 238.8 | 239.7 | 1.038 | 1.042 | 0.4 % | 4.29 V |
| ✅ | `82` | 238.8 | 239.7 | 1.038 | 1.042 | 0.4 % | 4.22 V |
| ✅ | `103` | 238.8 | 239.6 | 1.038 | 1.042 | 0.3 % | 4.18 V |
| ✅ | `85` | 238.8 | 239.4 | 1.038 | 1.041 | 0.3 % | 3.81 V |
| ✅ | `79` | 236.0 | 239.4 | 1.026 | 1.041 | 1.5 % | 2.4 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.461 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=5.176 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.111 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.57 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.617 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.969 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.502 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.441 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=5.177 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=5.005 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.731 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.934 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.086 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.42 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 170.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.71 V at bus '95' — reflects the neutral shift under unbalanced loading.

