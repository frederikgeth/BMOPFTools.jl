# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -93604.5273  
**Solve time:** 0.056 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 11.398 kW |
| Total load | 5.776 kW |
| Total network losses (P) | 5.623 kW |
| Total network losses (Q) | 2.113 kW var |
| Loss fraction | 97.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.723 V (bus `104`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.051 (`104`) | 2.6 % (`104`) | 4.72 V (`104`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `104` | 235.8 | 241.8 | 1.025 | 1.051 | 2.6 % | 4.72 V |
| ✅ | `101` | 235.8 | 241.7 | 1.025 | 1.051 | 2.6 % | 4.6 V |
| ✅ | `83` | 235.8 | 241.7 | 1.025 | 1.051 | 2.5 % | 4.55 V |
| ✅ | `98` | 235.8 | 241.6 | 1.025 | 1.05 | 2.5 % | 4.47 V |
| ✅ | `107` | 235.8 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.4 V |
| ✅ | `80` | 235.8 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.41 V |
| ✅ | `95` | 235.8 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.36 V |
| ✅ | `89` | 235.8 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.36 V |
| ✅ | `92` | 235.8 | 241.5 | 1.025 | 1.05 | 2.4 % | 4.33 V |
| ✅ | `86` | 235.8 | 241.1 | 1.025 | 1.048 | 2.3 % | 3.98 V |
| ✅ | `102` | 235.9 | 240.6 | 1.026 | 1.046 | 2.0 % | 2.93 V |
| ✅ | `90` | 235.9 | 240.6 | 1.026 | 1.046 | 2.0 % | 2.93 V |
| ✅ | `96` | 235.9 | 240.5 | 1.026 | 1.046 | 2.0 % | 2.89 V |
| ✅ | `87` | 235.9 | 240.5 | 1.026 | 1.046 | 2.0 % | 2.88 V |
| ✅ | `99` | 235.9 | 240.3 | 1.026 | 1.045 | 1.9 % | 2.69 V |
| ✅ | `105` | 235.9 | 240.2 | 1.026 | 1.044 | 1.9 % | 2.62 V |
| ✅ | `81` | 235.9 | 240.1 | 1.026 | 1.044 | 1.8 % | 2.49 V |
| ✅ | `84` | 235.9 | 240.0 | 1.026 | 1.044 | 1.8 % | 2.49 V |
| ✅ | `93` | 235.9 | 239.7 | 1.026 | 1.042 | 1.7 % | 2.24 V |
| ✅ | `106` | 237.3 | 239.3 | 1.032 | 1.04 | 0.9 % | 3.06 V |
| ✅ | `88` | 237.3 | 239.2 | 1.032 | 1.04 | 0.9 % | 3.01 V |
| ✅ | `100` | 237.3 | 239.2 | 1.032 | 1.04 | 0.8 % | 2.97 V |
| ✅ | `94` | 237.3 | 239.1 | 1.032 | 1.04 | 0.8 % | 2.87 V |
| ✅ | `91` | 237.3 | 239.1 | 1.032 | 1.04 | 0.8 % | 2.89 V |
| ✅ | `103` | 237.3 | 238.9 | 1.032 | 1.038 | 0.7 % | 2.62 V |
| ✅ | `97` | 237.3 | 238.8 | 1.032 | 1.038 | 0.7 % | 2.66 V |
| ✅ | `82` | 237.3 | 238.7 | 1.032 | 1.038 | 0.6 % | 2.27 V |
| ✅ | `85` | 237.3 | 238.7 | 1.032 | 1.038 | 0.6 % | 2.26 V |
| ✅ | `79` | 235.9 | 238.6 | 1.026 | 1.038 | 1.2 % | 1.49 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=3.428 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=3.932 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=3.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=3.915 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.446 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=3.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=3.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=3.99 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=3.995 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=3.692 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=3.776 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.009 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=3.973 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.613 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.401 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=3.678 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=3.399 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.803 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.534 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.85 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 97.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.72 V at bus '104' — reflects the neutral shift under unbalanced loading.

