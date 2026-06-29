# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -83163.8069  
**Solve time:** 0.056 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.473 kW |
| Total load | 16.917 kW |
| Total network losses (P) | 4.556 kW |
| Total network losses (Q) | 1.765 kW var |
| Loss fraction | 26.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.436 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.047 (`95`) | 2.9 % (`95`) | 5.44 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 234.3 | 240.8 | 1.019 | 1.047 | 2.9 % | 5.44 V |
| ✅ | `107` | 234.3 | 240.8 | 1.019 | 1.047 | 2.8 % | 5.36 V |
| ✅ | `83` | 234.3 | 240.7 | 1.019 | 1.047 | 2.8 % | 5.32 V |
| ✅ | `89` | 234.3 | 240.6 | 1.019 | 1.046 | 2.7 % | 5.16 V |
| ✅ | `104` | 234.3 | 240.4 | 1.019 | 1.045 | 2.7 % | 5.0 V |
| ✅ | `92` | 234.3 | 240.4 | 1.019 | 1.045 | 2.6 % | 4.98 V |
| ✅ | `101` | 234.3 | 240.0 | 1.019 | 1.044 | 2.5 % | 4.62 V |
| ✅ | `90` | 234.3 | 240.0 | 1.019 | 1.043 | 2.4 % | 4.4 V |
| ✅ | `102` | 234.3 | 240.0 | 1.019 | 1.043 | 2.4 % | 4.38 V |
| ✅ | `99` | 234.3 | 240.0 | 1.019 | 1.043 | 2.4 % | 4.38 V |
| ✅ | `98` | 234.3 | 239.9 | 1.019 | 1.043 | 2.5 % | 4.51 V |
| ✅ | `105` | 234.3 | 239.9 | 1.019 | 1.043 | 2.4 % | 4.32 V |
| ✅ | `81` | 234.3 | 239.9 | 1.019 | 1.043 | 2.4 % | 4.32 V |
| ✅ | `96` | 234.3 | 239.8 | 1.019 | 1.042 | 2.4 % | 4.22 V |
| ✅ | `87` | 234.3 | 239.7 | 1.019 | 1.042 | 2.3 % | 4.14 V |
| ✅ | `86` | 234.3 | 239.6 | 1.019 | 1.042 | 2.3 % | 4.21 V |
| ✅ | `80` | 234.3 | 239.5 | 1.019 | 1.041 | 2.3 % | 4.12 V |
| ✅ | `84` | 234.3 | 239.2 | 1.019 | 1.04 | 2.1 % | 3.89 V |
| ✅ | `93` | 234.3 | 238.6 | 1.019 | 1.037 | 1.9 % | 3.62 V |
| ✅ | `100` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.54 V |
| ✅ | `106` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.42 V |
| ✅ | `94` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.2 V |
| ✅ | `91` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.25 V |
| ✅ | `88` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.2 V |
| ✅ | `97` | 236.8 | 237.7 | 1.029 | 1.034 | 0.4 % | 1.17 V |
| ✅ | `103` | 236.1 | 237.7 | 1.027 | 1.034 | 0.7 % | 0.86 V |
| ✅ | `82` | 235.6 | 237.7 | 1.024 | 1.033 | 0.9 % | 1.06 V |
| ✅ | `85` | 235.5 | 237.7 | 1.024 | 1.033 | 0.9 % | 1.15 V |
| ✅ | `79` | 234.3 | 237.7 | 1.019 | 1.033 | 1.5 % | 2.53 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=3.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=3.678 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.082 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=3.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=3.803 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.431 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.779 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=3.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=3.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=3.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=3.401 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=3.993 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.973 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.381 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=3.534 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.692 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.383 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=3.543 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.663 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 26.9 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.44 V at bus '95' — reflects the neutral shift under unbalanced loading.

