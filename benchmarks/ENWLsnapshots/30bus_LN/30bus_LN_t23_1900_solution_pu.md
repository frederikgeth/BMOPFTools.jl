# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -12790.8532  
**Solve time:** 0.049 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 24.992 kW |
| Total load | 24.59 kW |
| Total network losses (P) | 402.0 W |
| Total network losses (Q) | 115.28 W var |
| Loss fraction | 1.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.581 V (bus `82`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.99 (`82`) | 1.01 (`102`) | 1.6 % (`82`) | 3.58 V (`82`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `102` | 229.5 | 232.4 | 0.998 | 1.01 | 1.2 % | 2.4 V |
| ✅ | `99` | 229.5 | 232.3 | 0.998 | 1.01 | 1.2 % | 2.38 V |
| ✅ | `82` | 227.7 | 231.3 | 0.99 | 1.006 | 1.6 % | 3.58 V |
| ✅ | `90` | 229.5 | 232.3 | 0.998 | 1.01 | 1.2 % | 2.38 V |
| ✅ | `105` | 229.5 | 232.3 | 0.998 | 1.01 | 1.2 % | 2.38 V |
| ✅ | `85` | 227.7 | 231.3 | 0.99 | 1.006 | 1.6 % | 3.52 V |
| ✅ | `96` | 229.5 | 232.3 | 0.998 | 1.01 | 1.2 % | 2.31 V |
| ✅ | `87` | 229.5 | 232.2 | 0.998 | 1.01 | 1.2 % | 2.31 V |
| ✅ | `81` | 229.5 | 232.2 | 0.998 | 1.009 | 1.1 % | 2.26 V |
| ✅ | `95` | 229.5 | 231.9 | 0.998 | 1.008 | 1.0 % | 2.34 V |
| ✅ | `89` | 229.5 | 231.7 | 0.998 | 1.008 | 1.0 % | 2.19 V |
| ✅ | `92` | 229.5 | 231.6 | 0.998 | 1.007 | 0.9 % | 2.09 V |
| ✅ | `107` | 229.5 | 231.6 | 0.998 | 1.007 | 0.9 % | 2.07 V |
| ✅ | `104` | 229.5 | 231.5 | 0.998 | 1.007 | 0.9 % | 2.02 V |
| ✅ | `83` | 229.5 | 231.5 | 0.998 | 1.007 | 0.9 % | 1.99 V |
| ✅ | `97` | 230.6 | 231.4 | 1.003 | 1.006 | 0.3 % | 0.55 V |
| ✅ | `106` | 230.6 | 231.4 | 1.003 | 1.006 | 0.3 % | 0.56 V |
| ✅ | `100` | 230.5 | 231.4 | 1.002 | 1.006 | 0.4 % | 0.64 V |
| ✅ | `98` | 229.6 | 231.4 | 0.998 | 1.006 | 0.8 % | 0.83 V |
| ✅ | `80` | 229.6 | 231.4 | 0.998 | 1.006 | 0.8 % | 0.87 V |
| ✅ | `88` | 230.4 | 231.4 | 1.002 | 1.006 | 0.4 % | 0.72 V |
| ✅ | `91` | 230.4 | 231.4 | 1.002 | 1.006 | 0.4 % | 0.79 V |
| ✅ | `86` | 229.6 | 231.4 | 0.998 | 1.006 | 0.8 % | 0.9 V |
| ✅ | `94` | 229.9 | 231.4 | 1.0 | 1.006 | 0.6 % | 1.29 V |
| ✅ | `79` | 229.5 | 231.3 | 0.998 | 1.006 | 0.8 % | 1.59 V |
| ✅ | `103` | 229.0 | 231.3 | 0.996 | 1.006 | 1.0 % | 2.2 V |
| ✅ | `101` | 229.5 | 231.3 | 0.998 | 1.006 | 0.8 % | 1.56 V |
| ✅ | `84` | 229.5 | 231.3 | 0.998 | 1.005 | 0.7 % | 1.91 V |
| ✅ | `93` | 229.5 | 230.9 | 0.998 | 1.004 | 0.6 % | 1.91 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=1.251 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=1.325 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.407 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=1.346 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.269 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=1.293 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.297 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=1.462 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.341 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=1.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=1.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=1.432 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=1.454 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=1.256 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.445 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.289 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=1.383 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=1.448 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.494 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=1.285 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=1.246 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 3.58 V at bus '82' — reflects the neutral shift under unbalanced loading.

