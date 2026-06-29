# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -104243.8304  
**Solve time:** 0.048 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 12.941 kW |
| Total load | 5.553 kW |
| Total network losses (P) | 7.388 kW |
| Total network losses (Q) | 2.694 kW var |
| Loss fraction | 133.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.487 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.053 (`92`) | 2.9 % (`92`) | 5.49 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 235.5 | 242.2 | 1.024 | 1.053 | 2.9 % | 5.49 V |
| ✅ | `95` | 235.5 | 242.1 | 1.024 | 1.053 | 2.9 % | 5.45 V |
| ✅ | `83` | 235.5 | 242.0 | 1.024 | 1.052 | 2.8 % | 5.37 V |
| ✅ | `98` | 235.5 | 241.9 | 1.024 | 1.052 | 2.8 % | 5.25 V |
| ✅ | `104` | 235.5 | 241.8 | 1.024 | 1.051 | 2.7 % | 5.08 V |
| ✅ | `101` | 235.5 | 241.8 | 1.024 | 1.051 | 2.7 % | 5.11 V |
| ✅ | `89` | 235.5 | 241.7 | 1.024 | 1.051 | 2.7 % | 4.98 V |
| ✅ | `86` | 235.5 | 241.6 | 1.024 | 1.051 | 2.7 % | 5.01 V |
| ✅ | `107` | 235.5 | 241.6 | 1.024 | 1.051 | 2.7 % | 4.95 V |
| ✅ | `96` | 235.6 | 241.4 | 1.024 | 1.05 | 2.5 % | 2.37 V |
| ✅ | `80` | 235.5 | 241.4 | 1.024 | 1.05 | 2.5 % | 4.72 V |
| ✅ | `105` | 235.6 | 241.3 | 1.024 | 1.049 | 2.5 % | 2.29 V |
| ✅ | `90` | 235.6 | 241.3 | 1.024 | 1.049 | 2.5 % | 2.27 V |
| ✅ | `87` | 235.6 | 241.2 | 1.024 | 1.049 | 2.4 % | 2.14 V |
| ✅ | `84` | 235.6 | 241.1 | 1.024 | 1.048 | 2.4 % | 2.09 V |
| ✅ | `102` | 235.6 | 240.9 | 1.024 | 1.047 | 2.3 % | 1.83 V |
| ✅ | `99` | 235.6 | 240.9 | 1.024 | 1.047 | 2.3 % | 1.79 V |
| ✅ | `81` | 235.6 | 240.8 | 1.024 | 1.047 | 2.3 % | 1.76 V |
| ✅ | `93` | 235.6 | 240.7 | 1.024 | 1.047 | 2.2 % | 1.7 V |
| ✅ | `100` | 237.8 | 239.3 | 1.034 | 1.041 | 0.7 % | 4.34 V |
| ✅ | `97` | 237.8 | 239.3 | 1.034 | 1.04 | 0.7 % | 4.31 V |
| ✅ | `91` | 237.8 | 239.2 | 1.034 | 1.04 | 0.6 % | 4.22 V |
| ✅ | `88` | 237.8 | 239.0 | 1.034 | 1.039 | 0.5 % | 4.03 V |
| ✅ | `94` | 237.8 | 238.9 | 1.034 | 1.039 | 0.5 % | 3.99 V |
| ✅ | `82` | 237.8 | 238.9 | 1.034 | 1.039 | 0.5 % | 3.94 V |
| ✅ | `106` | 237.8 | 238.8 | 1.034 | 1.038 | 0.5 % | 3.88 V |
| ✅ | `85` | 237.8 | 238.8 | 1.034 | 1.038 | 0.4 % | 3.78 V |
| ✅ | `103` | 237.8 | 238.6 | 1.034 | 1.037 | 0.4 % | 3.63 V |
| ✅ | `79` | 235.6 | 238.6 | 1.024 | 1.037 | 1.3 % | 1.78 V |
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
  Line losses are 133.0 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.49 V at bus '92' — reflects the neutral shift under unbalanced loading.

