# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -80165.7542  
**Solve time:** 0.061 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 10.517 kW |
| Total load | 6.288 kW |
| Total network losses (P) | 4.229 kW |
| Total network losses (Q) | 1.533 kW var |
| Loss fraction | 67.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.458 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.043 (`95`) | 2.4 % (`95`) | 4.46 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 234.5 | 239.9 | 1.02 | 1.043 | 2.4 % | 4.46 V |
| ✅ | `89` | 234.5 | 239.8 | 1.02 | 1.043 | 2.3 % | 4.37 V |
| ✅ | `107` | 234.5 | 239.8 | 1.02 | 1.043 | 2.3 % | 4.32 V |
| ✅ | `83` | 234.5 | 239.8 | 1.02 | 1.042 | 2.3 % | 4.3 V |
| ✅ | `92` | 234.5 | 239.6 | 1.02 | 1.042 | 2.2 % | 4.15 V |
| ✅ | `104` | 234.5 | 239.4 | 1.02 | 1.041 | 2.1 % | 3.94 V |
| ✅ | `101` | 234.5 | 239.4 | 1.02 | 1.041 | 2.1 % | 3.95 V |
| ✅ | `80` | 234.5 | 239.4 | 1.02 | 1.041 | 2.1 % | 3.92 V |
| ✅ | `98` | 234.5 | 239.3 | 1.02 | 1.041 | 2.1 % | 3.86 V |
| ✅ | `102` | 234.6 | 239.2 | 1.02 | 1.04 | 2.0 % | 1.92 V |
| ✅ | `99` | 234.6 | 239.1 | 1.02 | 1.04 | 2.0 % | 1.9 V |
| ✅ | `90` | 234.6 | 239.1 | 1.02 | 1.04 | 2.0 % | 1.87 V |
| ✅ | `81` | 234.6 | 239.0 | 1.02 | 1.039 | 2.0 % | 1.81 V |
| ✅ | `86` | 234.5 | 239.0 | 1.02 | 1.039 | 2.0 % | 3.57 V |
| ✅ | `96` | 234.6 | 239.0 | 1.02 | 1.039 | 1.9 % | 1.74 V |
| ✅ | `84` | 234.6 | 238.9 | 1.02 | 1.039 | 1.9 % | 1.73 V |
| ✅ | `87` | 234.6 | 238.9 | 1.02 | 1.039 | 1.9 % | 1.64 V |
| ✅ | `105` | 234.6 | 238.7 | 1.02 | 1.038 | 1.8 % | 1.49 V |
| ✅ | `93` | 234.6 | 238.4 | 1.02 | 1.036 | 1.7 % | 1.32 V |
| ✅ | `88` | 236.3 | 237.4 | 1.027 | 1.032 | 0.5 % | 3.17 V |
| ✅ | `97` | 236.3 | 237.4 | 1.027 | 1.032 | 0.5 % | 3.12 V |
| ✅ | `106` | 236.3 | 237.3 | 1.027 | 1.032 | 0.4 % | 3.08 V |
| ✅ | `91` | 236.3 | 237.2 | 1.027 | 1.031 | 0.4 % | 3.0 V |
| ✅ | `103` | 236.3 | 237.1 | 1.027 | 1.031 | 0.3 % | 2.85 V |
| ✅ | `100` | 236.3 | 237.1 | 1.027 | 1.031 | 0.3 % | 2.83 V |
| ✅ | `94` | 236.3 | 237.1 | 1.027 | 1.031 | 0.3 % | 2.82 V |
| ✅ | `85` | 236.3 | 237.1 | 1.027 | 1.031 | 0.3 % | 2.6 V |
| ✅ | `82` | 236.3 | 237.1 | 1.027 | 1.031 | 0.3 % | 2.22 V |
| ✅ | `79` | 234.6 | 237.0 | 1.02 | 1.031 | 1.1 % | 1.48 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=2.966 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=3.111 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.928 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=3.451 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.315 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=3.226 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.371 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=3.274 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=3.44 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=3.251 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=3.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=3.385 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=3.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=3.042 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.118 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=3.421 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=3.011 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=3.178 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.313 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 67.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.46 V at bus '95' — reflects the neutral shift under unbalanced loading.

