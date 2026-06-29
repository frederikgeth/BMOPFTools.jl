# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -120764.8389  
**Solve time:** 0.059 s  
**Findings:** 15 errors · 16 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 18.434 kW |
| Total load | 8.241 kW |
| Total network losses (P) | 10.193 kW |
| Total network losses (Q) | 3.714 kW var |
| Loss fraction | 123.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.451 V (bus `89`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.058 (`89`) | 3.2 % (`89`) | 6.45 V (`89`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `89` | 236.1 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.45 V |
| ✅ | `95` | 236.1 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.44 V |
| ✅ | `83` | 236.1 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.44 V |
| ✅ | `104` | 236.1 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.44 V |
| ✅ | `92` | 236.1 | 243.1 | 1.026 | 1.057 | 3.0 % | 6.18 V |
| ✅ | `107` | 236.1 | 243.1 | 1.026 | 1.057 | 3.0 % | 6.17 V |
| ✅ | `99` | 236.2 | 243.0 | 1.027 | 1.056 | 3.0 % | 3.05 V |
| ✅ | `102` | 236.2 | 243.0 | 1.027 | 1.056 | 3.0 % | 3.05 V |
| ✅ | `96` | 236.2 | 243.0 | 1.027 | 1.056 | 3.0 % | 3.03 V |
| ✅ | `90` | 236.2 | 243.0 | 1.027 | 1.056 | 3.0 % | 3.03 V |
| ✅ | `105` | 236.2 | 243.0 | 1.027 | 1.056 | 3.0 % | 3.03 V |
| ✅ | `80` | 236.1 | 242.9 | 1.026 | 1.056 | 3.0 % | 6.09 V |
| ✅ | `101` | 236.1 | 242.8 | 1.026 | 1.056 | 2.9 % | 5.94 V |
| ✅ | `98` | 236.1 | 242.8 | 1.026 | 1.056 | 2.9 % | 5.94 V |
| ✅ | `84` | 236.2 | 242.7 | 1.027 | 1.055 | 2.8 % | 2.83 V |
| ✅ | `81` | 236.2 | 242.7 | 1.027 | 1.055 | 2.8 % | 2.75 V |
| ✅ | `86` | 236.1 | 242.6 | 1.026 | 1.055 | 2.8 % | 5.75 V |
| ✅ | `87` | 236.2 | 242.6 | 1.027 | 1.055 | 2.8 % | 2.64 V |
| ✅ | `93` | 236.2 | 242.5 | 1.027 | 1.054 | 2.7 % | 2.67 V |
| ✅ | `106` | 238.9 | 240.4 | 1.039 | 1.045 | 0.7 % | 4.64 V |
| ✅ | `88` | 238.9 | 240.4 | 1.039 | 1.045 | 0.7 % | 4.63 V |
| ✅ | `97` | 238.9 | 240.3 | 1.039 | 1.045 | 0.6 % | 4.53 V |
| ✅ | `94` | 238.9 | 240.3 | 1.039 | 1.045 | 0.6 % | 4.5 V |
| ✅ | `91` | 238.9 | 240.0 | 1.038 | 1.044 | 0.5 % | 4.28 V |
| ✅ | `100` | 238.8 | 239.9 | 1.038 | 1.043 | 0.5 % | 4.23 V |
| ✅ | `82` | 238.8 | 239.8 | 1.038 | 1.042 | 0.4 % | 4.01 V |
| ✅ | `85` | 238.8 | 239.6 | 1.038 | 1.042 | 0.3 % | 3.86 V |
| ✅ | `103` | 238.8 | 239.5 | 1.038 | 1.041 | 0.3 % | 3.82 V |
| ✅ | `79` | 236.2 | 239.4 | 1.027 | 1.041 | 1.4 % | 2.17 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=5.003 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.682 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.827 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=5.219 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.195 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.212 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.687 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 123.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.45 V at bus '89' — reflects the neutral shift under unbalanced loading.

