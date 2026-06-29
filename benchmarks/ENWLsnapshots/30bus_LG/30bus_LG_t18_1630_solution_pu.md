# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -96513.5353  
**Solve time:** 0.037 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 20.303 kW |
| Total load | 14.225 kW |
| Total network losses (P) | 6.079 kW |
| Total network losses (Q) | 2.284 kW var |
| Loss fraction | 42.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.848 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.054 (`92`) | 3.1 % (`92`) | 5.85 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 235.3 | 242.4 | 1.023 | 1.054 | 3.1 % | 5.85 V |
| ✅ | `89` | 235.3 | 242.4 | 1.023 | 1.054 | 3.1 % | 5.83 V |
| ✅ | `95` | 235.4 | 242.3 | 1.023 | 1.054 | 3.0 % | 5.77 V |
| ✅ | `104` | 235.4 | 242.3 | 1.023 | 1.053 | 3.0 % | 5.7 V |
| ✅ | `83` | 235.4 | 241.9 | 1.023 | 1.052 | 2.9 % | 5.35 V |
| ✅ | `101` | 235.4 | 241.9 | 1.023 | 1.052 | 2.8 % | 5.32 V |
| ✅ | `107` | 235.4 | 241.9 | 1.023 | 1.052 | 2.8 % | 5.29 V |
| ✅ | `80` | 235.4 | 241.2 | 1.023 | 1.049 | 2.5 % | 4.64 V |
| ✅ | `86` | 235.4 | 241.2 | 1.023 | 1.049 | 2.5 % | 4.6 V |
| ✅ | `98` | 235.4 | 241.1 | 1.023 | 1.048 | 2.5 % | 4.55 V |
| ✅ | `99` | 235.4 | 241.0 | 1.024 | 1.048 | 2.4 % | 3.67 V |
| ✅ | `102` | 235.4 | 241.0 | 1.024 | 1.048 | 2.4 % | 3.66 V |
| ✅ | `87` | 235.4 | 241.0 | 1.024 | 1.048 | 2.4 % | 3.65 V |
| ✅ | `90` | 235.4 | 240.8 | 1.024 | 1.047 | 2.4 % | 3.49 V |
| ✅ | `81` | 235.4 | 240.7 | 1.024 | 1.047 | 2.3 % | 3.39 V |
| ✅ | `105` | 235.4 | 240.6 | 1.024 | 1.046 | 2.3 % | 3.3 V |
| ✅ | `96` | 235.4 | 240.5 | 1.024 | 1.046 | 2.2 % | 3.22 V |
| ✅ | `93` | 235.4 | 240.0 | 1.024 | 1.043 | 2.0 % | 3.1 V |
| ✅ | `84` | 235.4 | 240.0 | 1.024 | 1.043 | 2.0 % | 2.96 V |
| ✅ | `88` | 237.5 | 239.2 | 1.032 | 1.04 | 0.8 % | 3.02 V |
| ✅ | `91` | 237.5 | 239.0 | 1.032 | 1.039 | 0.7 % | 2.83 V |
| ✅ | `106` | 237.5 | 238.9 | 1.032 | 1.039 | 0.6 % | 2.73 V |
| ✅ | `97` | 237.5 | 238.9 | 1.032 | 1.039 | 0.6 % | 2.53 V |
| ✅ | `100` | 237.5 | 238.9 | 1.032 | 1.039 | 0.6 % | 2.48 V |
| ✅ | `103` | 237.5 | 238.9 | 1.032 | 1.039 | 0.6 % | 2.23 V |
| ✅ | `94` | 237.4 | 238.9 | 1.032 | 1.039 | 0.6 % | 2.23 V |
| ✅ | `82` | 237.4 | 238.9 | 1.032 | 1.039 | 0.6 % | 1.53 V |
| ✅ | `85` | 237.4 | 238.9 | 1.032 | 1.039 | 0.6 % | 1.51 V |
| ✅ | `79` | 235.4 | 238.8 | 1.024 | 1.038 | 1.5 % | 2.22 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.458 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=3.793 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.109 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=3.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.58 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.142 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.32 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.437 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=3.816 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=3.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.127 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.267 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=3.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.965 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.318 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.24 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.48 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=3.975 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 42.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.85 V at bus '92' — reflects the neutral shift under unbalanced loading.

