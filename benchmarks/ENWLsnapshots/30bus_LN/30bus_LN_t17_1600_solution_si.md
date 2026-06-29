# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -107506.7712  
**Solve time:** 0.07 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.744 kW |
| Total load | 11.682 kW |
| Total network losses (P) | 8.062 kW |
| Total network losses (Q) | 2.912 kW var |
| Loss fraction | 69.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.363 V (bus `107`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.056 (`107`) | 3.3 % (`107`) | 6.36 V (`107`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `107` | 235.2 | 242.8 | 1.023 | 1.056 | 3.3 % | 6.36 V |
| ✅ | `92` | 235.2 | 242.7 | 1.023 | 1.055 | 3.3 % | 6.3 V |
| ✅ | `89` | 235.2 | 242.7 | 1.023 | 1.055 | 3.3 % | 6.26 V |
| ✅ | `104` | 235.2 | 242.6 | 1.023 | 1.055 | 3.2 % | 6.14 V |
| ✅ | `83` | 235.2 | 242.5 | 1.023 | 1.054 | 3.2 % | 6.06 V |
| ✅ | `95` | 235.2 | 242.5 | 1.023 | 1.054 | 3.2 % | 6.04 V |
| ✅ | `86` | 235.2 | 242.0 | 1.023 | 1.052 | 3.0 % | 5.68 V |
| ✅ | `80` | 235.2 | 242.0 | 1.023 | 1.052 | 2.9 % | 5.64 V |
| ✅ | `101` | 235.2 | 241.9 | 1.023 | 1.052 | 2.9 % | 5.48 V |
| ✅ | `98` | 235.2 | 241.8 | 1.023 | 1.051 | 2.9 % | 5.44 V |
| ✅ | `105` | 235.3 | 241.7 | 1.023 | 1.051 | 2.8 % | 1.92 V |
| ✅ | `84` | 235.3 | 241.5 | 1.023 | 1.05 | 2.7 % | 1.84 V |
| ✅ | `87` | 235.3 | 241.4 | 1.023 | 1.049 | 2.7 % | 1.58 V |
| ✅ | `81` | 235.3 | 241.4 | 1.023 | 1.049 | 2.6 % | 1.58 V |
| ✅ | `96` | 235.3 | 241.3 | 1.023 | 1.049 | 2.6 % | 1.48 V |
| ✅ | `102` | 235.3 | 241.3 | 1.023 | 1.049 | 2.6 % | 1.46 V |
| ✅ | `90` | 235.3 | 241.2 | 1.023 | 1.049 | 2.6 % | 1.45 V |
| ✅ | `99` | 235.3 | 241.2 | 1.023 | 1.049 | 2.6 % | 1.42 V |
| ✅ | `93` | 235.3 | 240.6 | 1.023 | 1.046 | 2.3 % | 1.02 V |
| ✅ | `100` | 237.9 | 239.3 | 1.034 | 1.04 | 0.6 % | 5.07 V |
| ✅ | `106` | 237.9 | 239.2 | 1.034 | 1.04 | 0.6 % | 5.01 V |
| ✅ | `97` | 237.9 | 239.1 | 1.034 | 1.04 | 0.5 % | 4.95 V |
| ✅ | `91` | 237.9 | 238.9 | 1.034 | 1.039 | 0.4 % | 4.65 V |
| ✅ | `88` | 237.9 | 238.9 | 1.034 | 1.039 | 0.4 % | 4.54 V |
| ✅ | `94` | 237.9 | 238.9 | 1.034 | 1.039 | 0.4 % | 4.42 V |
| ✅ | `103` | 237.9 | 238.9 | 1.034 | 1.039 | 0.4 % | 4.22 V |
| ✅ | `85` | 237.9 | 238.9 | 1.034 | 1.039 | 0.4 % | 3.96 V |
| ✅ | `82` | 237.8 | 238.9 | 1.034 | 1.039 | 0.5 % | 3.73 V |
| ✅ | `79` | 235.3 | 238.9 | 1.023 | 1.039 | 1.6 % | 2.34 V |
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
  Line losses are 69.0 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.36 V at bus '107' — reflects the neutral shift under unbalanced loading.

