# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -26607.6066  
**Solve time:** 0.035 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 11.941 kW |
| Total load | 11.431 kW |
| Total network losses (P) | 510.02 W |
| Total network losses (Q) | 193.11 W var |
| Loss fraction | 4.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.892 V (bus `89`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.015 (`89`) | 1.0 % (`89`) | 1.89 V (`89`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `89` | 231.2 | 233.5 | 1.005 | 1.015 | 1.0 % | 1.89 V |
| ✅ | `83` | 231.2 | 233.5 | 1.005 | 1.015 | 1.0 % | 1.88 V |
| ✅ | `92` | 231.2 | 233.5 | 1.005 | 1.015 | 1.0 % | 1.88 V |
| ✅ | `107` | 231.2 | 233.5 | 1.005 | 1.015 | 1.0 % | 1.84 V |
| ✅ | `95` | 231.2 | 233.4 | 1.005 | 1.015 | 1.0 % | 1.8 V |
| ✅ | `96` | 231.2 | 233.4 | 1.005 | 1.015 | 1.0 % | 1.79 V |
| ✅ | `105` | 231.2 | 233.4 | 1.005 | 1.015 | 0.9 % | 1.77 V |
| ✅ | `87` | 231.2 | 233.4 | 1.005 | 1.015 | 0.9 % | 1.76 V |
| ✅ | `81` | 231.2 | 233.4 | 1.005 | 1.015 | 0.9 % | 1.74 V |
| ✅ | `104` | 231.2 | 233.3 | 1.005 | 1.014 | 0.9 % | 1.72 V |
| ✅ | `102` | 231.2 | 233.3 | 1.005 | 1.014 | 0.9 % | 1.68 V |
| ✅ | `99` | 231.2 | 233.2 | 1.005 | 1.014 | 0.9 % | 1.63 V |
| ✅ | `90` | 231.2 | 233.2 | 1.005 | 1.014 | 0.9 % | 1.61 V |
| ✅ | `101` | 231.2 | 233.1 | 1.005 | 1.013 | 0.8 % | 1.46 V |
| ✅ | `84` | 231.2 | 232.9 | 1.005 | 1.012 | 0.7 % | 1.46 V |
| ✅ | `93` | 231.2 | 232.7 | 1.005 | 1.012 | 0.7 % | 1.41 V |
| ✅ | `80` | 231.2 | 232.7 | 1.005 | 1.012 | 0.6 % | 1.04 V |
| ✅ | `86` | 231.2 | 232.7 | 1.005 | 1.012 | 0.6 % | 1.03 V |
| ✅ | `98` | 231.2 | 232.6 | 1.005 | 1.011 | 0.6 % | 0.98 V |
| ✅ | `106` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.3 V |
| ✅ | `88` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.27 V |
| ✅ | `91` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.27 V |
| ✅ | `97` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.2 V |
| ✅ | `100` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.16 V |
| ✅ | `94` | 232.2 | 232.4 | 1.01 | 1.01 | 0.1 % | 0.09 V |
| ✅ | `103` | 231.6 | 232.4 | 1.007 | 1.01 | 0.3 % | 0.49 V |
| ✅ | `79` | 231.2 | 232.3 | 1.005 | 1.01 | 0.5 % | 0.94 V |
| ✅ | `82` | 231.1 | 232.3 | 1.005 | 1.01 | 0.5 % | 1.0 V |
| ✅ | `85` | 231.0 | 232.3 | 1.004 | 1.01 | 0.6 % | 1.13 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=1.382 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=1.433 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.293 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=1.43 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.432 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=1.439 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=1.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.454 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.372 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=1.46 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.346 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=1.255 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=1.322 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=1.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=1.448 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=1.28 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=1.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=1.487 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.261 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.425 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=1.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=1.442 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.462 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=1.325 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.89 V at bus '89' — reflects the neutral shift under unbalanced loading.

