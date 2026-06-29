# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -93413.5614  
**Solve time:** 0.046 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 11.589 kW |
| Total load | 5.776 kW |
| Total network losses (P) | 5.814 kW |
| Total network losses (Q) | 2.129 kW var |
| Loss fraction | 100.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.596 V (bus `104`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.048 (`104`) | 2.5 % (`104`) | 4.6 V (`104`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `104` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.6 V |
| ✅ | `101` | 235.3 | 240.9 | 1.023 | 1.047 | 2.4 % | 4.48 V |
| ✅ | `83` | 235.3 | 240.8 | 1.023 | 1.047 | 2.4 % | 4.42 V |
| ✅ | `98` | 235.3 | 240.7 | 1.023 | 1.047 | 2.4 % | 4.37 V |
| ✅ | `107` | 235.3 | 240.7 | 1.023 | 1.046 | 2.3 % | 4.26 V |
| ✅ | `80` | 235.3 | 240.7 | 1.023 | 1.046 | 2.3 % | 4.3 V |
| ✅ | `95` | 235.3 | 240.7 | 1.023 | 1.046 | 2.3 % | 4.22 V |
| ✅ | `89` | 235.3 | 240.6 | 1.023 | 1.046 | 2.3 % | 4.22 V |
| ✅ | `92` | 235.3 | 240.6 | 1.023 | 1.046 | 2.3 % | 4.19 V |
| ✅ | `102` | 235.3 | 240.4 | 1.023 | 1.045 | 2.2 % | 2.32 V |
| ✅ | `90` | 235.3 | 240.4 | 1.023 | 1.045 | 2.2 % | 2.32 V |
| ✅ | `96` | 235.3 | 240.3 | 1.023 | 1.045 | 2.2 % | 2.27 V |
| ✅ | `87` | 235.3 | 240.3 | 1.023 | 1.045 | 2.2 % | 2.26 V |
| ✅ | `86` | 235.3 | 240.3 | 1.023 | 1.045 | 2.2 % | 3.86 V |
| ✅ | `99` | 235.3 | 240.1 | 1.023 | 1.044 | 2.1 % | 2.05 V |
| ✅ | `105` | 235.3 | 240.0 | 1.023 | 1.044 | 2.0 % | 1.97 V |
| ✅ | `81` | 235.3 | 239.9 | 1.023 | 1.043 | 2.0 % | 1.82 V |
| ✅ | `84` | 235.3 | 239.8 | 1.023 | 1.043 | 2.0 % | 1.8 V |
| ✅ | `93` | 235.3 | 239.5 | 1.023 | 1.041 | 1.8 % | 1.49 V |
| ✅ | `106` | 237.1 | 238.7 | 1.031 | 1.038 | 0.7 % | 3.75 V |
| ✅ | `88` | 237.1 | 238.7 | 1.031 | 1.038 | 0.7 % | 3.7 V |
| ✅ | `100` | 237.1 | 238.6 | 1.031 | 1.038 | 0.7 % | 3.66 V |
| ✅ | `91` | 237.1 | 238.6 | 1.031 | 1.037 | 0.6 % | 3.58 V |
| ✅ | `94` | 237.1 | 238.6 | 1.031 | 1.037 | 0.6 % | 3.57 V |
| ✅ | `103` | 237.1 | 238.3 | 1.031 | 1.036 | 0.5 % | 3.34 V |
| ✅ | `97` | 237.1 | 238.3 | 1.031 | 1.036 | 0.5 % | 3.36 V |
| ✅ | `82` | 237.1 | 238.0 | 1.031 | 1.035 | 0.4 % | 3.01 V |
| ✅ | `85` | 237.1 | 237.9 | 1.031 | 1.035 | 0.4 % | 2.99 V |
| ✅ | `79` | 235.3 | 237.8 | 1.023 | 1.034 | 1.1 % | 1.35 V |
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
  Line losses are 100.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.6 V at bus '104' — reflects the neutral shift under unbalanced loading.

