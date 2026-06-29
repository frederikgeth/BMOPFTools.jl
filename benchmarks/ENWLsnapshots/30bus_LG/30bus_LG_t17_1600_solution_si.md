# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -107896.6799  
**Solve time:** 0.059 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.354 kW |
| Total load | 11.682 kW |
| Total network losses (P) | 7.672 kW |
| Total network losses (Q) | 2.813 kW var |
| Loss fraction | 65.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.81 V (bus `107`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.06 (`107`) | 3.4 % (`107`) | 6.81 V (`107`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `107` | 236.0 | 243.9 | 1.026 | 1.06 | 3.4 % | 6.81 V |
| ✅ | `92` | 236.0 | 243.8 | 1.026 | 1.06 | 3.4 % | 6.75 V |
| ✅ | `89` | 236.0 | 243.8 | 1.026 | 1.06 | 3.4 % | 6.71 V |
| ✅ | `104` | 236.0 | 243.7 | 1.026 | 1.059 | 3.3 % | 6.59 V |
| ✅ | `83` | 236.0 | 243.6 | 1.026 | 1.059 | 3.3 % | 6.51 V |
| ✅ | `95` | 236.0 | 243.6 | 1.026 | 1.059 | 3.3 % | 6.49 V |
| ✅ | `86` | 236.0 | 243.1 | 1.026 | 1.057 | 3.1 % | 6.08 V |
| ✅ | `80` | 236.0 | 243.1 | 1.026 | 1.057 | 3.1 % | 6.05 V |
| ✅ | `101` | 236.0 | 243.0 | 1.026 | 1.056 | 3.0 % | 5.92 V |
| ✅ | `98` | 236.0 | 242.9 | 1.026 | 1.056 | 3.0 % | 5.85 V |
| ✅ | `105` | 236.1 | 241.7 | 1.026 | 1.051 | 2.4 % | 2.74 V |
| ✅ | `84` | 236.1 | 241.6 | 1.026 | 1.05 | 2.4 % | 2.72 V |
| ✅ | `87` | 236.1 | 241.4 | 1.026 | 1.05 | 2.3 % | 2.49 V |
| ✅ | `81` | 236.1 | 241.4 | 1.026 | 1.05 | 2.3 % | 2.49 V |
| ✅ | `96` | 236.1 | 241.3 | 1.026 | 1.049 | 2.3 % | 2.42 V |
| ✅ | `102` | 236.1 | 241.3 | 1.026 | 1.049 | 2.3 % | 2.4 V |
| ✅ | `90` | 236.1 | 241.3 | 1.026 | 1.049 | 2.2 % | 2.4 V |
| ✅ | `99` | 236.1 | 241.2 | 1.026 | 1.049 | 2.2 % | 2.38 V |
| ✅ | `93` | 236.1 | 240.6 | 1.026 | 1.046 | 1.9 % | 2.24 V |
| ✅ | `100` | 237.9 | 240.1 | 1.034 | 1.044 | 1.0 % | 4.55 V |
| ✅ | `106` | 237.9 | 240.0 | 1.034 | 1.044 | 0.9 % | 4.49 V |
| ✅ | `97` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 4.44 V |
| ✅ | `91` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 4.17 V |
| ✅ | `88` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 4.08 V |
| ✅ | `94` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 3.95 V |
| ✅ | `103` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 3.7 V |
| ✅ | `85` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 3.43 V |
| ✅ | `82` | 237.9 | 240.0 | 1.034 | 1.043 | 0.9 % | 3.22 V |
| ✅ | `79` | 236.1 | 239.9 | 1.026 | 1.043 | 1.7 % | 2.78 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.328 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.658 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.339 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.22 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.976 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.0 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.713 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.166 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.198 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=4.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.768 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.202 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.707 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 65.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.81 V at bus '107' — reflects the neutral shift under unbalanced loading.

