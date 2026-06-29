# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -49510.5167  
**Solve time:** 0.065 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.789 kW |
| Total load | 22.026 kW |
| Total network losses (P) | 1.763 kW |
| Total network losses (Q) | 668.84 W var |
| Loss fraction | 8.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.597 V (bus `104`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.028 (`104`) | 1.9 % (`104`) | 3.6 V (`104`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `104` | 232.1 | 236.5 | 1.009 | 1.028 | 1.9 % | 3.6 V |
| ✅ | `107` | 232.1 | 236.5 | 1.009 | 1.028 | 1.9 % | 3.6 V |
| ✅ | `99` | 232.2 | 236.4 | 1.009 | 1.028 | 1.8 % | 3.39 V |
| ✅ | `89` | 232.1 | 236.4 | 1.009 | 1.028 | 1.8 % | 3.44 V |
| ✅ | `87` | 232.2 | 236.3 | 1.009 | 1.028 | 1.8 % | 3.3 V |
| ✅ | `102` | 232.2 | 236.3 | 1.009 | 1.027 | 1.8 % | 3.28 V |
| ✅ | `95` | 232.1 | 236.3 | 1.009 | 1.027 | 1.8 % | 3.41 V |
| ✅ | `83` | 232.1 | 236.3 | 1.009 | 1.027 | 1.8 % | 3.39 V |
| ✅ | `92` | 232.1 | 236.2 | 1.009 | 1.027 | 1.8 % | 3.33 V |
| ✅ | `90` | 232.2 | 236.2 | 1.009 | 1.027 | 1.8 % | 3.22 V |
| ✅ | `81` | 232.2 | 236.0 | 1.009 | 1.026 | 1.7 % | 3.04 V |
| ✅ | `96` | 232.2 | 236.0 | 1.009 | 1.026 | 1.7 % | 3.02 V |
| ✅ | `105` | 232.2 | 236.0 | 1.009 | 1.026 | 1.6 % | 3.0 V |
| ✅ | `101` | 232.1 | 235.8 | 1.009 | 1.025 | 1.6 % | 2.84 V |
| ✅ | `84` | 232.2 | 235.5 | 1.009 | 1.024 | 1.4 % | 2.81 V |
| ✅ | `86` | 232.2 | 235.0 | 1.009 | 1.022 | 1.2 % | 2.05 V |
| ✅ | `98` | 232.2 | 234.9 | 1.009 | 1.021 | 1.2 % | 1.98 V |
| ✅ | `93` | 232.2 | 234.8 | 1.009 | 1.021 | 1.1 % | 2.54 V |
| ✅ | `80` | 232.2 | 234.7 | 1.009 | 1.021 | 1.1 % | 1.8 V |
| ✅ | `97` | 234.2 | 234.4 | 1.018 | 1.019 | 0.1 % | 0.59 V |
| ✅ | `91` | 234.2 | 234.4 | 1.018 | 1.019 | 0.1 % | 0.55 V |
| ✅ | `100` | 234.2 | 234.4 | 1.018 | 1.019 | 0.1 % | 0.48 V |
| ✅ | `106` | 234.1 | 234.4 | 1.018 | 1.019 | 0.1 % | 0.39 V |
| ✅ | `88` | 234.1 | 234.4 | 1.018 | 1.019 | 0.1 % | 0.36 V |
| ✅ | `94` | 233.6 | 234.4 | 1.016 | 1.019 | 0.3 % | 0.34 V |
| ✅ | `103` | 232.9 | 234.3 | 1.013 | 1.019 | 0.6 % | 0.94 V |
| ✅ | `79` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 1.77 V |
| ✅ | `82` | 232.3 | 234.3 | 1.01 | 1.019 | 0.9 % | 1.54 V |
| ✅ | `85` | 232.0 | 234.3 | 1.009 | 1.019 | 1.0 % | 1.9 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=2.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=2.796 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.672 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=2.499 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.61 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=2.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.49 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.809 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=2.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=2.718 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=2.766 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=2.561 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=2.59 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=2.753 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=2.39 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.426 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=2.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=2.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.722 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=2.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=2.391 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 3.6 V at bus '104' — reflects the neutral shift under unbalanced loading.

