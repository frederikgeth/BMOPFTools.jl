# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -122160.5906  
**Solve time:** 0.055 s  
**Findings:** 0 errors · 26 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 18.056 kW |
| Total load | 8.241 kW |
| Total network losses (P) | 9.815 kW |
| Total network losses (Q) | 3.639 kW var |
| Loss fraction | 119.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.043 V (bus `83`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.064 (`83`) | 3.4 % (`83`) | 7.04 V (`83`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `83` | 237.0 | 244.8 | 1.03 | 1.064 | 3.4 % | 7.04 V |
| ✅ | `104` | 237.0 | 244.8 | 1.03 | 1.064 | 3.4 % | 7.04 V |
| ✅ | `89` | 237.0 | 244.6 | 1.03 | 1.064 | 3.3 % | 6.92 V |
| ✅ | `95` | 237.0 | 244.6 | 1.03 | 1.064 | 3.3 % | 6.9 V |
| ✅ | `92` | 237.0 | 244.4 | 1.03 | 1.062 | 3.2 % | 6.64 V |
| ✅ | `107` | 237.0 | 244.4 | 1.03 | 1.062 | 3.2 % | 6.64 V |
| ✅ | `80` | 237.0 | 244.3 | 1.03 | 1.062 | 3.2 % | 6.61 V |
| ✅ | `101` | 237.0 | 244.1 | 1.031 | 1.061 | 3.1 % | 6.4 V |
| ✅ | `98` | 237.0 | 244.1 | 1.031 | 1.061 | 3.1 % | 6.38 V |
| ✅ | `86` | 237.0 | 243.9 | 1.031 | 1.06 | 3.0 % | 6.19 V |
| ✅ | `99` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 3.86 V |
| ✅ | `102` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 3.85 V |
| ✅ | `96` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 3.84 V |
| ✅ | `90` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 3.84 V |
| ✅ | `105` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 3.84 V |
| ✅ | `84` | 237.1 | 243.0 | 1.031 | 1.056 | 2.6 % | 3.69 V |
| ✅ | `81` | 237.1 | 242.9 | 1.031 | 1.056 | 2.5 % | 3.58 V |
| ✅ | `87` | 237.1 | 242.8 | 1.031 | 1.056 | 2.5 % | 3.49 V |
| ✅ | `93` | 237.1 | 242.7 | 1.031 | 1.055 | 2.4 % | 3.57 V |
| ✅ | `106` | 239.1 | 241.4 | 1.039 | 1.05 | 1.0 % | 4.11 V |
| ✅ | `88` | 239.1 | 241.4 | 1.039 | 1.05 | 1.0 % | 4.1 V |
| ✅ | `94` | 239.1 | 241.3 | 1.039 | 1.049 | 1.0 % | 3.97 V |
| ✅ | `97` | 239.1 | 241.3 | 1.039 | 1.049 | 0.9 % | 3.97 V |
| ✅ | `91` | 239.1 | 241.0 | 1.039 | 1.048 | 0.8 % | 3.77 V |
| ✅ | `100` | 239.1 | 240.9 | 1.039 | 1.047 | 0.8 % | 3.72 V |
| ✅ | `82` | 239.1 | 240.8 | 1.039 | 1.047 | 0.7 % | 3.49 V |
| ✅ | `85` | 239.1 | 240.7 | 1.039 | 1.046 | 0.7 % | 3.34 V |
| ✅ | `103` | 239.1 | 240.7 | 1.039 | 1.046 | 0.7 % | 3.33 V |
| ✅ | `79` | 237.1 | 240.6 | 1.031 | 1.046 | 1.5 % | 2.79 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=5.025 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=5.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.224 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=5.249 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.195 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.248 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.687 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=5.163 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 119.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 7.04 V at bus '83' — reflects the neutral shift under unbalanced loading.

