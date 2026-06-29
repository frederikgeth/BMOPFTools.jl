# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -66632.4636  
**Solve time:** 0.048 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.089 kW |
| Total load | 20.092 kW |
| Total network losses (P) | 2.996 kW |
| Total network losses (Q) | 1.105 kW var |
| Loss fraction | 14.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.093 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.038 (`92`) | 2.3 % (`92`) | 4.09 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 233.4 | 238.7 | 1.015 | 1.038 | 2.3 % | 4.09 V |
| ✅ | `89` | 233.4 | 238.6 | 1.015 | 1.037 | 2.2 % | 3.92 V |
| ✅ | `95` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 3.69 V |
| ✅ | `107` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 3.67 V |
| ✅ | `83` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 3.64 V |
| ✅ | `104` | 233.4 | 238.2 | 1.015 | 1.035 | 2.1 % | 3.51 V |
| ✅ | `101` | 233.4 | 238.1 | 1.015 | 1.035 | 2.0 % | 3.47 V |
| ✅ | `96` | 233.4 | 238.0 | 1.015 | 1.035 | 2.0 % | 2.64 V |
| ✅ | `102` | 233.4 | 237.7 | 1.015 | 1.033 | 1.8 % | 2.35 V |
| ✅ | `105` | 233.4 | 237.7 | 1.015 | 1.033 | 1.8 % | 2.35 V |
| ✅ | `87` | 233.4 | 237.5 | 1.015 | 1.033 | 1.8 % | 2.2 V |
| ✅ | `99` | 233.4 | 237.5 | 1.015 | 1.032 | 1.8 % | 2.18 V |
| ✅ | `90` | 233.4 | 237.5 | 1.015 | 1.032 | 1.7 % | 2.18 V |
| ✅ | `81` | 233.4 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.16 V |
| ✅ | `98` | 233.4 | 237.4 | 1.015 | 1.032 | 1.7 % | 2.8 V |
| ✅ | `80` | 233.4 | 237.3 | 1.015 | 1.032 | 1.7 % | 2.74 V |
| ✅ | `86` | 233.4 | 237.1 | 1.015 | 1.031 | 1.6 % | 2.46 V |
| ✅ | `84` | 233.4 | 236.7 | 1.015 | 1.029 | 1.4 % | 1.84 V |
| ✅ | `93` | 233.4 | 236.6 | 1.015 | 1.029 | 1.4 % | 1.89 V |
| ✅ | `97` | 235.2 | 236.2 | 1.023 | 1.027 | 0.4 % | 2.28 V |
| ✅ | `106` | 235.2 | 236.2 | 1.023 | 1.027 | 0.4 % | 2.24 V |
| ✅ | `88` | 235.2 | 236.1 | 1.023 | 1.026 | 0.4 % | 2.16 V |
| ✅ | `91` | 235.2 | 236.0 | 1.023 | 1.026 | 0.3 % | 2.05 V |
| ✅ | `94` | 235.2 | 235.9 | 1.023 | 1.026 | 0.3 % | 1.91 V |
| ✅ | `100` | 235.2 | 235.9 | 1.023 | 1.026 | 0.3 % | 1.9 V |
| ✅ | `103` | 234.8 | 235.9 | 1.021 | 1.026 | 0.5 % | 0.91 V |
| ✅ | `85` | 234.4 | 235.9 | 1.019 | 1.026 | 0.7 % | 0.45 V |
| ✅ | `82` | 234.2 | 235.9 | 1.018 | 1.026 | 0.8 % | 0.33 V |
| ✅ | `79` | 233.4 | 235.9 | 1.015 | 1.026 | 1.1 % | 1.23 V |
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
  Maximum neutral terminal voltage: 4.09 V at bus '92' — reflects the neutral shift under unbalanced loading.

