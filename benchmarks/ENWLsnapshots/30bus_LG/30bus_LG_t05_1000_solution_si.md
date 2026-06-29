# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -64467.7013  
**Solve time:** 0.046 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 10.054 kW |
| Total load | 7.372 kW |
| Total network losses (P) | 2.682 kW |
| Total network losses (Q) | 1.043 kW var |
| Loss fraction | 36.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.318 V (bus `104`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.038 (`104`) | 2.3 % (`104`) | 4.32 V (`104`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `104` | 233.5 | 238.8 | 1.015 | 1.038 | 2.3 % | 4.32 V |
| ✅ | `107` | 233.5 | 238.8 | 1.015 | 1.038 | 2.3 % | 4.29 V |
| ✅ | `89` | 233.5 | 238.8 | 1.015 | 1.038 | 2.3 % | 4.27 V |
| ✅ | `92` | 233.5 | 238.8 | 1.015 | 1.038 | 2.3 % | 4.27 V |
| ✅ | `95` | 233.5 | 238.7 | 1.015 | 1.038 | 2.3 % | 4.21 V |
| ✅ | `101` | 233.5 | 238.6 | 1.015 | 1.037 | 2.2 % | 4.09 V |
| ✅ | `83` | 233.5 | 238.6 | 1.015 | 1.037 | 2.2 % | 4.04 V |
| ✅ | `98` | 233.5 | 238.4 | 1.015 | 1.036 | 2.1 % | 3.83 V |
| ✅ | `86` | 233.5 | 238.3 | 1.015 | 1.036 | 2.1 % | 3.83 V |
| ✅ | `80` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 3.62 V |
| ✅ | `96` | 233.5 | 237.2 | 1.015 | 1.031 | 1.6 % | 2.78 V |
| ✅ | `81` | 233.5 | 237.2 | 1.015 | 1.031 | 1.6 % | 2.75 V |
| ✅ | `102` | 233.5 | 237.2 | 1.015 | 1.031 | 1.6 % | 2.73 V |
| ✅ | `90` | 233.5 | 237.1 | 1.015 | 1.031 | 1.6 % | 2.71 V |
| ✅ | `99` | 233.5 | 237.0 | 1.015 | 1.03 | 1.5 % | 2.63 V |
| ✅ | `84` | 233.5 | 237.0 | 1.015 | 1.03 | 1.5 % | 2.7 V |
| ✅ | `105` | 233.5 | 237.0 | 1.015 | 1.03 | 1.5 % | 2.61 V |
| ✅ | `87` | 233.5 | 236.9 | 1.015 | 1.03 | 1.5 % | 2.57 V |
| ✅ | `93` | 233.5 | 236.8 | 1.015 | 1.029 | 1.4 % | 2.62 V |
| ✅ | `91` | 234.9 | 236.5 | 1.022 | 1.028 | 0.7 % | 1.58 V |
| ✅ | `100` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.52 V |
| ✅ | `94` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.47 V |
| ✅ | `106` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.46 V |
| ✅ | `88` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.45 V |
| ✅ | `97` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.45 V |
| ✅ | `103` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.3 V |
| ✅ | `85` | 234.9 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.07 V |
| ✅ | `82` | 234.8 | 236.5 | 1.021 | 1.028 | 0.7 % | 1.08 V |
| ✅ | `79` | 233.5 | 236.5 | 1.015 | 1.028 | 1.3 % | 1.99 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=2.821 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=2.403 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=2.786 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.825 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=2.763 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.835 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=2.424 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=2.796 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=2.67 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=2.78 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=2.561 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=2.555 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=2.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=2.753 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.473 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.689 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.809 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=2.499 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=2.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.436 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=2.766 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=2.61 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 36.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.32 V at bus '104' — reflects the neutral shift under unbalanced loading.

