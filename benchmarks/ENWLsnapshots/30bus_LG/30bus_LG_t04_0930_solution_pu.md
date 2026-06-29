# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -46277.5234  
**Solve time:** 0.04 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 10.525 kW |
| Total load | 9.126 kW |
| Total network losses (P) | 1.399 kW |
| Total network losses (Q) | 542.9 W var |
| Loss fraction | 15.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.024 V (bus `83`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.027 (`83`) | 1.6 % (`83`) | 3.02 V (`83`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `83` | 232.4 | 236.2 | 1.011 | 1.027 | 1.6 % | 3.02 V |
| ✅ | `107` | 232.4 | 236.2 | 1.011 | 1.027 | 1.6 % | 3.02 V |
| ✅ | `104` | 232.4 | 236.1 | 1.011 | 1.027 | 1.6 % | 2.94 V |
| ✅ | `89` | 232.4 | 236.1 | 1.011 | 1.027 | 1.6 % | 2.94 V |
| ✅ | `92` | 232.4 | 236.0 | 1.011 | 1.026 | 1.6 % | 2.85 V |
| ✅ | `95` | 232.4 | 236.0 | 1.011 | 1.026 | 1.6 % | 2.83 V |
| ✅ | `101` | 232.4 | 236.0 | 1.011 | 1.026 | 1.6 % | 2.82 V |
| ✅ | `80` | 232.4 | 235.6 | 1.011 | 1.024 | 1.4 % | 2.38 V |
| ✅ | `86` | 232.4 | 235.6 | 1.011 | 1.024 | 1.4 % | 2.38 V |
| ✅ | `98` | 232.4 | 235.5 | 1.011 | 1.024 | 1.3 % | 2.27 V |
| ✅ | `102` | 232.5 | 235.4 | 1.011 | 1.024 | 1.3 % | 2.24 V |
| ✅ | `99` | 232.5 | 235.4 | 1.011 | 1.023 | 1.3 % | 2.22 V |
| ✅ | `105` | 232.5 | 235.4 | 1.011 | 1.023 | 1.3 % | 2.22 V |
| ✅ | `90` | 232.5 | 235.4 | 1.011 | 1.023 | 1.3 % | 2.21 V |
| ✅ | `81` | 232.5 | 235.3 | 1.011 | 1.023 | 1.2 % | 2.13 V |
| ✅ | `87` | 232.5 | 235.2 | 1.011 | 1.023 | 1.2 % | 2.07 V |
| ✅ | `96` | 232.5 | 235.2 | 1.011 | 1.022 | 1.2 % | 2.05 V |
| ✅ | `93` | 232.5 | 234.8 | 1.011 | 1.021 | 1.0 % | 1.99 V |
| ✅ | `84` | 232.5 | 234.8 | 1.011 | 1.021 | 1.0 % | 1.9 V |
| ✅ | `97` | 233.7 | 234.5 | 1.016 | 1.02 | 0.4 % | 0.99 V |
| ✅ | `100` | 233.7 | 234.5 | 1.016 | 1.02 | 0.4 % | 0.95 V |
| ✅ | `88` | 233.7 | 234.5 | 1.016 | 1.02 | 0.4 % | 0.87 V |
| ✅ | `91` | 233.7 | 234.5 | 1.016 | 1.02 | 0.4 % | 0.84 V |
| ✅ | `106` | 233.7 | 234.5 | 1.016 | 1.02 | 0.4 % | 0.81 V |
| ✅ | `94` | 233.7 | 234.5 | 1.016 | 1.019 | 0.4 % | 0.68 V |
| ✅ | `103` | 233.6 | 234.5 | 1.016 | 1.019 | 0.4 % | 0.53 V |
| ✅ | `82` | 233.4 | 234.5 | 1.015 | 1.019 | 0.5 % | 0.44 V |
| ✅ | `85` | 233.0 | 234.5 | 1.013 | 1.019 | 0.6 % | 0.67 V |
| ✅ | `79` | 232.5 | 234.5 | 1.011 | 1.019 | 0.9 % | 1.35 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=2.162 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=1.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.15 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=2.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.998 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.044 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=1.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.991 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.132 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=1.865 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.841 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.058 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=2.128 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=1.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=1.84 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=2.115 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=1.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.119 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.855 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=2.107 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=2.17 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.159 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.199 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=1.96 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=2.117 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 3.02 V at bus '83' — reflects the neutral shift under unbalanced loading.

