# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -122390.3793  
**Solve time:** 0.071 s  
**Findings:** 0 errors · 13 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.472 kW |
| Total load | 6.004 kW |
| Total network losses (P) | 10.467 kW |
| Total network losses (Q) | 3.831 kW var |
| Loss fraction | 174.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.24 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.059 (`95`) | 3.2 % (`95`) | 6.24 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 236.2 | 243.6 | 1.027 | 1.059 | 3.2 % | 6.24 V |
| ✅ | `92` | 236.2 | 243.6 | 1.027 | 1.059 | 3.2 % | 6.22 V |
| ✅ | `107` | 236.2 | 243.6 | 1.027 | 1.059 | 3.2 % | 6.21 V |
| ✅ | `89` | 236.2 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.93 V |
| ✅ | `104` | 236.3 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.92 V |
| ✅ | `80` | 236.2 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.94 V |
| ✅ | `83` | 236.3 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.88 V |
| ✅ | `98` | 236.2 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.93 V |
| ✅ | `86` | 236.3 | 243.3 | 1.027 | 1.058 | 3.0 % | 5.91 V |
| ✅ | `101` | 236.3 | 243.2 | 1.027 | 1.058 | 3.0 % | 5.83 V |
| ✅ | `102` | 236.3 | 243.0 | 1.028 | 1.057 | 2.9 % | 2.8 V |
| ✅ | `105` | 236.3 | 243.0 | 1.028 | 1.056 | 2.9 % | 2.79 V |
| ✅ | `99` | 236.3 | 242.8 | 1.028 | 1.056 | 2.8 % | 2.61 V |
| ✅ | `84` | 236.3 | 242.8 | 1.028 | 1.056 | 2.8 % | 2.65 V |
| ✅ | `90` | 236.3 | 242.8 | 1.028 | 1.056 | 2.8 % | 2.59 V |
| ✅ | `87` | 236.3 | 242.6 | 1.028 | 1.055 | 2.7 % | 2.4 V |
| ✅ | `93` | 236.3 | 242.6 | 1.028 | 1.055 | 2.7 % | 2.49 V |
| ✅ | `96` | 236.3 | 242.6 | 1.028 | 1.055 | 2.7 % | 2.36 V |
| ✅ | `81` | 236.3 | 242.6 | 1.028 | 1.055 | 2.7 % | 2.33 V |
| ✅ | `106` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.93 V |
| ✅ | `97` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.93 V |
| ✅ | `88` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.92 V |
| ✅ | `91` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.92 V |
| ✅ | `100` | 238.9 | 240.5 | 1.038 | 1.046 | 0.7 % | 4.83 V |
| ✅ | `94` | 238.9 | 240.5 | 1.038 | 1.046 | 0.7 % | 4.82 V |
| ✅ | `103` | 238.9 | 240.3 | 1.038 | 1.045 | 0.6 % | 4.63 V |
| ✅ | `82` | 238.8 | 239.8 | 1.038 | 1.043 | 0.4 % | 4.22 V |
| ✅ | `85` | 238.8 | 239.7 | 1.038 | 1.042 | 0.4 % | 3.99 V |
| ✅ | `79` | 236.3 | 239.6 | 1.028 | 1.042 | 1.4 % | 2.01 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.643 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.935 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.005 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.827 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 174.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.24 V at bus '95' — reflects the neutral shift under unbalanced loading.

