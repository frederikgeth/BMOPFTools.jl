# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -116413.707  
**Solve time:** 0.066 s  
**Findings:** 0 errors · 23 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.093 kW |
| Total load | 9.638 kW |
| Total network losses (P) | 9.455 kW |
| Total network losses (Q) | 3.447 kW var |
| Loss fraction | 98.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.253 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.058 (`95`) | 3.2 % (`95`) | 6.25 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 235.9 | 243.3 | 1.026 | 1.058 | 3.2 % | 6.25 V |
| ✅ | `107` | 235.9 | 243.2 | 1.026 | 1.057 | 3.2 % | 6.16 V |
| ✅ | `104` | 235.9 | 243.0 | 1.026 | 1.057 | 3.1 % | 6.03 V |
| ✅ | `101` | 235.9 | 243.0 | 1.026 | 1.057 | 3.1 % | 6.06 V |
| ✅ | `83` | 235.9 | 242.8 | 1.026 | 1.056 | 3.0 % | 5.74 V |
| ✅ | `89` | 235.9 | 242.8 | 1.026 | 1.055 | 3.0 % | 5.73 V |
| ✅ | `92` | 235.9 | 242.7 | 1.026 | 1.055 | 3.0 % | 5.71 V |
| ✅ | `86` | 235.9 | 242.7 | 1.026 | 1.055 | 3.0 % | 5.8 V |
| ✅ | `98` | 235.9 | 242.7 | 1.026 | 1.055 | 3.0 % | 5.77 V |
| ✅ | `96` | 236.0 | 242.6 | 1.026 | 1.055 | 2.9 % | 2.77 V |
| ✅ | `87` | 236.0 | 242.5 | 1.026 | 1.054 | 2.9 % | 2.68 V |
| ✅ | `81` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 2.64 V |
| ✅ | `102` | 236.0 | 242.3 | 1.026 | 1.054 | 2.8 % | 2.47 V |
| ✅ | `80` | 235.9 | 242.3 | 1.026 | 1.053 | 2.8 % | 5.34 V |
| ✅ | `93` | 236.0 | 242.1 | 1.026 | 1.053 | 2.7 % | 2.35 V |
| ✅ | `99` | 236.0 | 242.1 | 1.026 | 1.052 | 2.7 % | 2.19 V |
| ✅ | `90` | 236.0 | 242.1 | 1.026 | 1.052 | 2.6 % | 2.19 V |
| ✅ | `105` | 236.0 | 242.0 | 1.026 | 1.052 | 2.6 % | 2.16 V |
| ✅ | `84` | 236.0 | 241.6 | 1.026 | 1.051 | 2.5 % | 1.85 V |
| ✅ | `88` | 238.5 | 240.2 | 1.037 | 1.044 | 0.7 % | 4.89 V |
| ✅ | `100` | 238.5 | 240.2 | 1.037 | 1.044 | 0.7 % | 4.88 V |
| ✅ | `97` | 238.5 | 240.1 | 1.037 | 1.044 | 0.7 % | 4.78 V |
| ✅ | `91` | 238.5 | 240.0 | 1.037 | 1.043 | 0.7 % | 4.72 V |
| ✅ | `94` | 238.5 | 239.9 | 1.037 | 1.043 | 0.6 % | 4.64 V |
| ✅ | `106` | 238.5 | 239.8 | 1.037 | 1.043 | 0.6 % | 4.58 V |
| ✅ | `82` | 238.5 | 239.3 | 1.037 | 1.04 | 0.4 % | 4.03 V |
| ✅ | `103` | 238.5 | 239.3 | 1.037 | 1.04 | 0.4 % | 3.82 V |
| ✅ | `85` | 238.5 | 239.3 | 1.037 | 1.04 | 0.4 % | 3.71 V |
| ✅ | `79` | 236.0 | 239.2 | 1.026 | 1.04 | 1.4 % | 2.02 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=5.086 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.177 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.18 kW is within 1 % of its P bound.
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
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.42 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.207 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.601 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 98.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.25 V at bus '95' — reflects the neutral shift under unbalanced loading.

