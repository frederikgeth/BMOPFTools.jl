# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -123715.8617  
**Solve time:** 0.061 s  
**Findings:** 0 errors · 11 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.978 kW |
| Total load | 6.265 kW |
| Total network losses (P) | 10.713 kW |
| Total network losses (Q) | 3.928 kW var |
| Loss fraction | 171.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.189 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.06 (`92`) | 3.2 % (`92`) | 6.19 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 6.19 V |
| ✅ | `104` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 6.19 V |
| ✅ | `89` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 6.18 V |
| ✅ | `107` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 6.18 V |
| ✅ | `83` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 6.18 V |
| ✅ | `95` | 236.3 | 243.5 | 1.027 | 1.059 | 3.1 % | 6.02 V |
| ✅ | `98` | 236.3 | 243.4 | 1.027 | 1.058 | 3.1 % | 5.93 V |
| ✅ | `101` | 236.3 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.83 V |
| ✅ | `86` | 236.3 | 243.3 | 1.027 | 1.058 | 3.1 % | 5.86 V |
| ✅ | `80` | 236.3 | 243.1 | 1.027 | 1.057 | 3.0 % | 5.64 V |
| ✅ | `81` | 236.4 | 243.1 | 1.028 | 1.057 | 2.9 % | 2.79 V |
| ✅ | `99` | 236.4 | 243.1 | 1.028 | 1.057 | 2.9 % | 2.79 V |
| ✅ | `90` | 236.4 | 243.1 | 1.028 | 1.057 | 2.9 % | 2.78 V |
| ✅ | `96` | 236.4 | 243.0 | 1.028 | 1.056 | 2.9 % | 2.7 V |
| ✅ | `105` | 236.4 | 242.8 | 1.028 | 1.056 | 2.8 % | 2.49 V |
| ✅ | `102` | 236.4 | 242.8 | 1.028 | 1.055 | 2.8 % | 2.48 V |
| ✅ | `87` | 236.4 | 242.8 | 1.028 | 1.055 | 2.8 % | 2.48 V |
| ✅ | `93` | 236.4 | 242.7 | 1.028 | 1.055 | 2.8 % | 2.51 V |
| ✅ | `84` | 236.4 | 242.6 | 1.028 | 1.055 | 2.7 % | 2.32 V |
| ✅ | `106` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.94 V |
| ✅ | `88` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.94 V |
| ✅ | `100` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.93 V |
| ✅ | `91` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.93 V |
| ✅ | `97` | 238.9 | 240.6 | 1.039 | 1.046 | 0.7 % | 4.92 V |
| ✅ | `94` | 238.9 | 240.4 | 1.039 | 1.045 | 0.7 % | 4.76 V |
| ✅ | `103` | 238.9 | 240.3 | 1.039 | 1.045 | 0.6 % | 4.59 V |
| ✅ | `82` | 238.9 | 240.1 | 1.039 | 1.044 | 0.5 % | 4.39 V |
| ✅ | `85` | 238.9 | 240.0 | 1.039 | 1.044 | 0.5 % | 4.33 V |
| ✅ | `79` | 236.4 | 239.7 | 1.028 | 1.042 | 1.4 % | 1.99 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.066 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=5.157 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.792 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.787 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.077 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.743 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.74 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 171.0 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.19 V at bus '92' — reflects the neutral shift under unbalanced loading.

