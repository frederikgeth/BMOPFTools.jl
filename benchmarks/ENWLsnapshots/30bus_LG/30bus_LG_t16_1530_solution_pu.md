# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -117414.1505  
**Solve time:** 0.055 s  
**Findings:** 2 errors · 27 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 18.712 kW |
| Total load | 9.638 kW |
| Total network losses (P) | 9.074 kW |
| Total network losses (Q) | 3.34 kW var |
| Loss fraction | 94.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.821 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.063 (`95`) | 3.4 % (`95`) | 6.82 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 236.8 | 244.5 | 1.03 | 1.063 | 3.4 % | 6.82 V |
| ✅ | `107` | 236.8 | 244.3 | 1.03 | 1.062 | 3.3 % | 6.65 V |
| ✅ | `101` | 236.8 | 244.3 | 1.03 | 1.062 | 3.3 % | 6.67 V |
| ✅ | `104` | 236.8 | 244.2 | 1.03 | 1.062 | 3.2 % | 6.53 V |
| ✅ | `86` | 236.8 | 244.0 | 1.03 | 1.061 | 3.1 % | 6.34 V |
| ✅ | `98` | 236.8 | 244.0 | 1.03 | 1.061 | 3.1 % | 6.33 V |
| ✅ | `83` | 236.8 | 243.9 | 1.03 | 1.061 | 3.1 % | 6.25 V |
| ✅ | `89` | 236.8 | 243.9 | 1.03 | 1.061 | 3.1 % | 6.24 V |
| ✅ | `92` | 236.8 | 243.9 | 1.03 | 1.061 | 3.1 % | 6.22 V |
| ✅ | `80` | 236.8 | 243.5 | 1.03 | 1.059 | 2.9 % | 5.81 V |
| ✅ | `96` | 236.9 | 242.8 | 1.03 | 1.056 | 2.6 % | 3.28 V |
| ✅ | `87` | 236.9 | 242.7 | 1.03 | 1.055 | 2.5 % | 3.18 V |
| ✅ | `81` | 236.9 | 242.7 | 1.03 | 1.055 | 2.5 % | 3.15 V |
| ✅ | `102` | 236.9 | 242.5 | 1.03 | 1.054 | 2.5 % | 3.01 V |
| ✅ | `93` | 236.9 | 242.3 | 1.03 | 1.053 | 2.4 % | 2.99 V |
| ✅ | `99` | 236.9 | 242.2 | 1.03 | 1.053 | 2.3 % | 2.79 V |
| ✅ | `90` | 236.9 | 242.2 | 1.03 | 1.053 | 2.3 % | 2.79 V |
| ✅ | `105` | 236.9 | 242.2 | 1.03 | 1.053 | 2.3 % | 2.77 V |
| ✅ | `84` | 236.9 | 241.8 | 1.03 | 1.051 | 2.1 % | 2.59 V |
| ✅ | `88` | 238.6 | 241.2 | 1.038 | 1.049 | 1.1 % | 4.52 V |
| ✅ | `100` | 238.6 | 241.2 | 1.038 | 1.049 | 1.1 % | 4.5 V |
| ✅ | `97` | 238.6 | 241.0 | 1.038 | 1.048 | 1.0 % | 4.39 V |
| ✅ | `91` | 238.6 | 240.9 | 1.038 | 1.048 | 1.0 % | 4.33 V |
| ✅ | `94` | 238.6 | 240.9 | 1.038 | 1.047 | 1.0 % | 4.25 V |
| ✅ | `106` | 238.6 | 240.8 | 1.038 | 1.047 | 0.9 % | 4.22 V |
| ✅ | `82` | 238.6 | 240.4 | 1.038 | 1.045 | 0.8 % | 3.65 V |
| ✅ | `103` | 238.6 | 240.4 | 1.038 | 1.045 | 0.8 % | 3.5 V |
| ✅ | `85` | 238.6 | 240.4 | 1.038 | 1.045 | 0.8 % | 3.38 V |
| ✅ | `79` | 236.9 | 240.4 | 1.03 | 1.045 | 1.5 % | 2.6 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=5.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=5.086 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.213 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.236 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.969 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.731 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=5.191 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.617 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.502 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.03 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.461 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.111 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.42 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.236 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.601 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 94.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.82 V at bus '95' — reflects the neutral shift under unbalanced loading.

