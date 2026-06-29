# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -113415.3842  
**Solve time:** 0.069 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 14.484 kW |
| Total load | 5.565 kW |
| Total network losses (P) | 8.919 kW |
| Total network losses (Q) | 3.218 kW var |
| Loss fraction | 160.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.58 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.056 (`92`) | 3.2 % (`92`) | 6.58 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 235.6 | 243.0 | 1.025 | 1.056 | 3.2 % | 6.58 V |
| ✅ | `104` | 235.6 | 243.0 | 1.025 | 1.056 | 3.2 % | 6.54 V |
| ✅ | `83` | 235.6 | 242.8 | 1.025 | 1.056 | 3.1 % | 6.41 V |
| ✅ | `89` | 235.6 | 242.8 | 1.025 | 1.056 | 3.1 % | 6.37 V |
| ✅ | `86` | 235.6 | 242.7 | 1.025 | 1.055 | 3.1 % | 6.36 V |
| ✅ | `101` | 235.6 | 242.7 | 1.025 | 1.055 | 3.1 % | 6.3 V |
| ✅ | `107` | 235.6 | 242.6 | 1.025 | 1.055 | 3.0 % | 6.17 V |
| ✅ | `95` | 235.6 | 242.6 | 1.025 | 1.055 | 3.0 % | 6.12 V |
| ✅ | `81` | 235.7 | 242.4 | 1.025 | 1.054 | 2.9 % | 2.54 V |
| ✅ | `87` | 235.7 | 242.4 | 1.025 | 1.054 | 2.9 % | 2.54 V |
| ✅ | `99` | 235.7 | 242.4 | 1.025 | 1.054 | 2.9 % | 2.52 V |
| ✅ | `96` | 235.7 | 242.3 | 1.025 | 1.054 | 2.9 % | 2.47 V |
| ✅ | `105` | 235.7 | 242.2 | 1.025 | 1.053 | 2.8 % | 2.33 V |
| ✅ | `98` | 235.7 | 242.1 | 1.025 | 1.053 | 2.8 % | 5.7 V |
| ✅ | `80` | 235.7 | 242.0 | 1.025 | 1.052 | 2.8 % | 5.63 V |
| ✅ | `93` | 235.7 | 242.0 | 1.025 | 1.052 | 2.7 % | 2.27 V |
| ✅ | `90` | 235.7 | 241.9 | 1.025 | 1.052 | 2.7 % | 2.07 V |
| ✅ | `84` | 235.7 | 241.9 | 1.025 | 1.052 | 2.7 % | 2.12 V |
| ✅ | `102` | 235.7 | 241.8 | 1.025 | 1.052 | 2.7 % | 2.02 V |
| ✅ | `88` | 238.4 | 239.7 | 1.037 | 1.042 | 0.5 % | 4.65 V |
| ✅ | `106` | 238.4 | 239.7 | 1.037 | 1.042 | 0.5 % | 4.64 V |
| ✅ | `97` | 238.4 | 239.5 | 1.037 | 1.041 | 0.4 % | 4.46 V |
| ✅ | `100` | 238.4 | 239.4 | 1.037 | 1.041 | 0.4 % | 4.41 V |
| ✅ | `85` | 238.4 | 239.3 | 1.037 | 1.04 | 0.4 % | 4.25 V |
| ✅ | `91` | 238.4 | 239.2 | 1.037 | 1.04 | 0.3 % | 4.26 V |
| ✅ | `94` | 238.4 | 239.1 | 1.037 | 1.04 | 0.3 % | 4.16 V |
| ✅ | `103` | 238.4 | 239.1 | 1.037 | 1.04 | 0.3 % | 3.95 V |
| ✅ | `82` | 238.4 | 239.1 | 1.037 | 1.04 | 0.3 % | 3.81 V |
| ✅ | `79` | 235.7 | 239.1 | 1.025 | 1.039 | 1.5 % | 2.39 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.976 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=4.163 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.658 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.425 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.768 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.198 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.22 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.283 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=4.166 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.625 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.328 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.713 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.815 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.143 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 160.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.58 V at bus '92' — reflects the neutral shift under unbalanced loading.

