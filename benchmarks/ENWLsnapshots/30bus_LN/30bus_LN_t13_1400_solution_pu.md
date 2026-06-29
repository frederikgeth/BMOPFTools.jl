# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -123265.8187  
**Solve time:** 0.059 s  
**Findings:** 19 errors · 13 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.314 kW |
| Total load | 6.655 kW |
| Total network losses (P) | 10.659 kW |
| Total network losses (Q) | 3.886 kW var |
| Loss fraction | 160.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.495 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.06 (`95`) | 3.3 % (`95`) | 6.5 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 236.1 | 243.7 | 1.027 | 1.06 | 3.3 % | 6.5 V |
| ✅ | `89` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 6.47 V |
| ✅ | `92` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 6.47 V |
| ✅ | `107` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 6.47 V |
| ✅ | `104` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 6.46 V |
| ✅ | `83` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 6.46 V |
| ✅ | `101` | 236.1 | 243.5 | 1.027 | 1.059 | 3.2 % | 6.34 V |
| ✅ | `80` | 236.1 | 243.4 | 1.027 | 1.058 | 3.1 % | 6.21 V |
| ✅ | `86` | 236.1 | 243.3 | 1.027 | 1.058 | 3.1 % | 6.15 V |
| ✅ | `98` | 236.1 | 243.2 | 1.027 | 1.057 | 3.1 % | 6.02 V |
| ✅ | `102` | 236.2 | 243.1 | 1.027 | 1.057 | 3.0 % | 2.64 V |
| ✅ | `96` | 236.2 | 243.1 | 1.027 | 1.057 | 3.0 % | 2.64 V |
| ✅ | `99` | 236.2 | 243.1 | 1.027 | 1.057 | 3.0 % | 2.64 V |
| ✅ | `87` | 236.2 | 243.1 | 1.027 | 1.057 | 3.0 % | 2.63 V |
| ✅ | `90` | 236.2 | 243.1 | 1.027 | 1.057 | 3.0 % | 2.63 V |
| ✅ | `81` | 236.2 | 242.8 | 1.027 | 1.056 | 2.9 % | 2.37 V |
| ✅ | `105` | 236.2 | 242.8 | 1.027 | 1.056 | 2.9 % | 2.36 V |
| ✅ | `84` | 236.2 | 242.5 | 1.027 | 1.054 | 2.7 % | 2.13 V |
| ✅ | `93` | 236.2 | 242.4 | 1.027 | 1.054 | 2.7 % | 2.07 V |
| ✅ | `100` | 238.9 | 240.5 | 1.039 | 1.045 | 0.7 % | 5.02 V |
| ✅ | `97` | 238.9 | 240.4 | 1.039 | 1.045 | 0.6 % | 4.98 V |
| ✅ | `94` | 238.9 | 240.3 | 1.039 | 1.045 | 0.6 % | 4.9 V |
| ✅ | `88` | 238.9 | 240.2 | 1.039 | 1.044 | 0.6 % | 4.79 V |
| ✅ | `106` | 238.9 | 240.2 | 1.039 | 1.044 | 0.5 % | 4.78 V |
| ✅ | `91` | 238.9 | 240.1 | 1.039 | 1.044 | 0.5 % | 4.74 V |
| ✅ | `103` | 238.9 | 240.1 | 1.039 | 1.044 | 0.5 % | 4.64 V |
| ✅ | `82` | 238.9 | 239.9 | 1.039 | 1.043 | 0.4 % | 4.5 V |
| ✅ | `85` | 238.9 | 239.9 | 1.039 | 1.043 | 0.4 % | 4.48 V |
| ✅ | `79` | 236.2 | 239.7 | 1.027 | 1.042 | 1.5 % | 2.26 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.852 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.996 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.833 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.784 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.828 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=5.198 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.848 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=5.174 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.197 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.121 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.781 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 160.2 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.5 V at bus '95' — reflects the neutral shift under unbalanced loading.

