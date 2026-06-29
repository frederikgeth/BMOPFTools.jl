# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:23  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -5773.138  
**Solve time:** 0.054 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.583 kW |
| Total load | 13.48 kW |
| Total network losses (P) | 103.18 W |
| Total network losses (Q) | 28.55 W var |
| Loss fraction | 0.8% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.827 V (bus `82`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.995 (`82`) | 1.005 (`99`) | 0.8 % (`82`) | 1.83 V (`82`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `82` | 228.7 | 230.6 | 0.995 | 1.003 | 0.8 % | 1.83 V |
| ✅ | `99` | 229.7 | 231.2 | 0.999 | 1.005 | 0.6 % | 1.24 V |
| ✅ | `85` | 228.8 | 230.6 | 0.995 | 1.003 | 0.8 % | 1.74 V |
| ✅ | `87` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.22 V |
| ✅ | `90` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.21 V |
| ✅ | `105` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.2 V |
| ✅ | `81` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.16 V |
| ✅ | `102` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.15 V |
| ✅ | `96` | 229.7 | 231.1 | 0.999 | 1.005 | 0.6 % | 1.15 V |
| ✅ | `95` | 229.7 | 230.9 | 0.999 | 1.004 | 0.5 % | 1.16 V |
| ✅ | `107` | 229.7 | 230.8 | 0.999 | 1.003 | 0.5 % | 1.07 V |
| ✅ | `89` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.03 V |
| ✅ | `92` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.03 V |
| ✅ | `103` | 229.3 | 230.6 | 0.997 | 1.003 | 0.6 % | 1.24 V |
| ✅ | `83` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 1.0 V |
| ✅ | `104` | 229.7 | 230.7 | 0.999 | 1.003 | 0.4 % | 0.99 V |
| ✅ | `98` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.42 V |
| ✅ | `80` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.4 V |
| ✅ | `106` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.31 V |
| ✅ | `91` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.32 V |
| ✅ | `86` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.42 V |
| ✅ | `100` | 230.2 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.36 V |
| ✅ | `88` | 230.1 | 230.6 | 1.001 | 1.003 | 0.2 % | 0.38 V |
| ✅ | `97` | 230.1 | 230.6 | 1.0 | 1.003 | 0.2 % | 0.43 V |
| ✅ | `94` | 229.9 | 230.6 | 0.999 | 1.003 | 0.3 % | 0.66 V |
| ✅ | `79` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.8 V |
| ✅ | `101` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.74 V |
| ✅ | `84` | 229.7 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.97 V |
| ✅ | `93` | 229.7 | 230.3 | 0.999 | 1.001 | 0.2 % | 0.95 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=725.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=739.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=718.54 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=630.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=668.41 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=666.92 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=638.62 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=652.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=721.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=737.45 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=733.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=636.01 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=627.4 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=645.58 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=627.82 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=722.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=747.83 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=702.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=727.16 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=736.51 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=678.96 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=630.17 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=749.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=691.77 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=697.03 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=632.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=729.99 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=739.8 W is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.83 V at bus '82' — reflects the neutral shift under unbalanced loading.

