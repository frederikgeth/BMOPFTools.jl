# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -66666.6126  
**Solve time:** 0.039 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.055 kW |
| Total load | 20.092 kW |
| Total network losses (P) | 2.962 kW |
| Total network losses (Q) | 1.134 kW var |
| Loss fraction | 14.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.389 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.04 (`92`) | 2.4 % (`92`) | 4.39 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 233.5 | 239.1 | 1.015 | 1.04 | 2.4 % | 4.39 V |
| ✅ | `89` | 233.5 | 238.9 | 1.015 | 1.039 | 2.4 % | 4.22 V |
| ✅ | `95` | 233.5 | 238.7 | 1.015 | 1.038 | 2.3 % | 4.0 V |
| ✅ | `107` | 233.5 | 238.7 | 1.015 | 1.038 | 2.3 % | 3.98 V |
| ✅ | `83` | 233.5 | 238.7 | 1.015 | 1.038 | 2.2 % | 3.94 V |
| ✅ | `104` | 233.5 | 238.5 | 1.015 | 1.037 | 2.2 % | 3.82 V |
| ✅ | `101` | 233.5 | 238.5 | 1.015 | 1.037 | 2.2 % | 3.75 V |
| ✅ | `96` | 233.5 | 237.9 | 1.015 | 1.034 | 1.9 % | 3.28 V |
| ✅ | `98` | 233.5 | 237.8 | 1.015 | 1.034 | 1.9 % | 3.03 V |
| ✅ | `80` | 233.5 | 237.7 | 1.015 | 1.033 | 1.8 % | 2.97 V |
| ✅ | `102` | 233.5 | 237.6 | 1.015 | 1.033 | 1.8 % | 3.02 V |
| ✅ | `105` | 233.5 | 237.6 | 1.015 | 1.033 | 1.8 % | 3.02 V |
| ✅ | `87` | 233.5 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.88 V |
| ✅ | `86` | 233.5 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.69 V |
| ✅ | `99` | 233.5 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.86 V |
| ✅ | `90` | 233.5 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.87 V |
| ✅ | `81` | 233.5 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.85 V |
| ✅ | `84` | 233.5 | 236.7 | 1.015 | 1.029 | 1.4 % | 2.55 V |
| ✅ | `93` | 233.5 | 236.5 | 1.015 | 1.028 | 1.3 % | 2.6 V |
| ✅ | `97` | 235.2 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.61 V |
| ✅ | `106` | 235.2 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.58 V |
| ✅ | `88` | 235.2 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.5 V |
| ✅ | `91` | 235.2 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.4 V |
| ✅ | `94` | 235.2 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.25 V |
| ✅ | `100` | 235.1 | 236.3 | 1.022 | 1.027 | 0.5 % | 1.27 V |
| ✅ | `103` | 234.9 | 236.3 | 1.021 | 1.027 | 0.6 % | 0.42 V |
| ✅ | `85` | 234.5 | 236.3 | 1.019 | 1.027 | 0.8 % | 0.48 V |
| ✅ | `82` | 234.3 | 236.3 | 1.019 | 1.027 | 0.9 % | 0.64 V |
| ✅ | `79` | 233.5 | 236.3 | 1.015 | 1.027 | 1.2 % | 1.67 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=3.178 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=2.928 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.954 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=3.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.911 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=3.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.254 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.042 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=3.315 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.031 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=3.118 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=3.05 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=3.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=2.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.942 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.309 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.514 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=2.91 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=3.421 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.313 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.438 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=3.153 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.398 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.39 V at bus '92' — reflects the neutral shift under unbalanced loading.

