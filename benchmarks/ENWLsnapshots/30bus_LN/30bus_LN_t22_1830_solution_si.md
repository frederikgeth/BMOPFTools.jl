# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -31522.76  
**Solve time:** 0.07 s  
**Findings:** 0 errors · 28 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 24.574 kW |
| Total load | 23.688 kW |
| Total network losses (P) | 885.11 W |
| Total network losses (Q) | 314.79 W var |
| Loss fraction | 3.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 3.199 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 0.999 (`85`) | 1.02 (`95`) | 1.6 % (`95`) | 3.2 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 230.7 | 234.5 | 1.003 | 1.02 | 1.6 % | 3.2 V |
| ✅ | `104` | 230.8 | 234.4 | 1.003 | 1.019 | 1.6 % | 3.04 V |
| ✅ | `89` | 230.8 | 234.3 | 1.003 | 1.019 | 1.5 % | 3.0 V |
| ✅ | `92` | 230.8 | 234.3 | 1.003 | 1.019 | 1.5 % | 3.0 V |
| ✅ | `83` | 230.8 | 234.3 | 1.003 | 1.019 | 1.5 % | 2.98 V |
| ✅ | `87` | 230.8 | 234.2 | 1.003 | 1.018 | 1.5 % | 2.73 V |
| ✅ | `107` | 230.8 | 234.2 | 1.003 | 1.018 | 1.5 % | 2.93 V |
| ✅ | `105` | 230.8 | 234.2 | 1.003 | 1.018 | 1.5 % | 2.71 V |
| ✅ | `96` | 230.8 | 234.2 | 1.003 | 1.018 | 1.5 % | 2.69 V |
| ✅ | `102` | 230.8 | 234.1 | 1.003 | 1.018 | 1.5 % | 2.64 V |
| ✅ | `90` | 230.8 | 234.0 | 1.003 | 1.018 | 1.4 % | 2.57 V |
| ✅ | `99` | 230.8 | 234.0 | 1.003 | 1.017 | 1.4 % | 2.54 V |
| ✅ | `81` | 230.8 | 234.0 | 1.003 | 1.017 | 1.4 % | 2.52 V |
| ✅ | `101` | 230.8 | 233.6 | 1.003 | 1.016 | 1.2 % | 2.25 V |
| ✅ | `84` | 230.8 | 233.2 | 1.003 | 1.014 | 1.0 % | 2.26 V |
| ✅ | `86` | 230.8 | 232.9 | 1.003 | 1.013 | 0.9 % | 1.54 V |
| ✅ | `88` | 232.4 | 232.8 | 1.01 | 1.012 | 0.2 % | 0.35 V |
| ✅ | `106` | 232.2 | 232.8 | 1.009 | 1.012 | 0.3 % | 0.43 V |
| ✅ | `100` | 232.2 | 232.8 | 1.009 | 1.012 | 0.3 % | 0.41 V |
| ✅ | `97` | 232.1 | 232.8 | 1.009 | 1.012 | 0.3 % | 0.44 V |
| ✅ | `91` | 232.1 | 232.8 | 1.009 | 1.012 | 0.3 % | 0.44 V |
| ✅ | `94` | 232.1 | 232.8 | 1.009 | 1.012 | 0.3 % | 0.38 V |
| ✅ | `98` | 230.8 | 232.7 | 1.003 | 1.012 | 0.9 % | 1.37 V |
| ✅ | `79` | 230.8 | 232.7 | 1.003 | 1.012 | 0.8 % | 1.69 V |
| ✅ | `93` | 230.8 | 232.7 | 1.003 | 1.012 | 0.8 % | 2.21 V |
| ✅ | `103` | 230.9 | 232.7 | 1.004 | 1.012 | 0.8 % | 1.5 V |
| ✅ | `82` | 230.0 | 232.7 | 1.0 | 1.012 | 1.2 % | 2.36 V |
| ✅ | `85` | 229.7 | 232.7 | 0.999 | 1.012 | 1.3 % | 2.72 V |
| ✅ | `80` | 230.8 | 232.6 | 1.003 | 1.011 | 0.8 % | 1.18 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=2.084 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.906 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=2.15 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.842 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.083 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=2.107 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.08 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.991 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=1.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=1.998 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=2.117 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=2.136 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=1.96 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=1.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=2.209 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.161 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.982 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.045 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=1.857 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=1.841 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=1.899 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 3.2 V at bus '95' — reflects the neutral shift under unbalanced loading.

