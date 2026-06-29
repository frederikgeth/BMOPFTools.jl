# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -113849.5533  
**Solve time:** 0.039 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 14.05 kW |
| Total load | 5.565 kW |
| Total network losses (P) | 8.486 kW |
| Total network losses (Q) | 3.129 kW var |
| Loss fraction | 152.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.033 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.062 (`92`) | 3.3 % (`92`) | 7.03 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 236.5 | 244.2 | 1.028 | 1.062 | 3.3 % | 7.03 V |
| ✅ | `104` | 236.5 | 244.1 | 1.028 | 1.061 | 3.3 % | 6.99 V |
| ✅ | `83` | 236.5 | 244.0 | 1.028 | 1.061 | 3.3 % | 6.87 V |
| ✅ | `89` | 236.5 | 244.0 | 1.028 | 1.061 | 3.3 % | 6.82 V |
| ✅ | `86` | 236.5 | 243.9 | 1.028 | 1.06 | 3.2 % | 6.79 V |
| ✅ | `101` | 236.5 | 243.9 | 1.028 | 1.06 | 3.2 % | 6.75 V |
| ✅ | `107` | 236.5 | 243.8 | 1.028 | 1.06 | 3.2 % | 6.63 V |
| ✅ | `95` | 236.5 | 243.7 | 1.028 | 1.06 | 3.2 % | 6.59 V |
| ✅ | `98` | 236.5 | 243.3 | 1.028 | 1.058 | 3.0 % | 6.14 V |
| ✅ | `80` | 236.5 | 243.2 | 1.028 | 1.057 | 2.9 % | 6.08 V |
| ✅ | `81` | 236.6 | 242.5 | 1.029 | 1.054 | 2.6 % | 3.54 V |
| ✅ | `87` | 236.6 | 242.5 | 1.029 | 1.054 | 2.6 % | 3.54 V |
| ✅ | `99` | 236.6 | 242.5 | 1.029 | 1.054 | 2.6 % | 3.51 V |
| ✅ | `96` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 3.48 V |
| ✅ | `105` | 236.6 | 242.3 | 1.029 | 1.053 | 2.5 % | 3.37 V |
| ✅ | `93` | 236.6 | 242.1 | 1.029 | 1.053 | 2.4 % | 3.35 V |
| ✅ | `90` | 236.6 | 242.0 | 1.029 | 1.052 | 2.4 % | 3.17 V |
| ✅ | `84` | 236.6 | 242.0 | 1.029 | 1.052 | 2.4 % | 3.23 V |
| ✅ | `102` | 236.6 | 241.9 | 1.029 | 1.052 | 2.3 % | 3.13 V |
| ✅ | `88` | 238.5 | 240.6 | 1.037 | 1.046 | 0.9 % | 4.06 V |
| ✅ | `106` | 238.5 | 240.5 | 1.037 | 1.046 | 0.9 % | 4.06 V |
| ✅ | `97` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.91 V |
| ✅ | `100` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.87 V |
| ✅ | `91` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.75 V |
| ✅ | `85` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.67 V |
| ✅ | `94` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.66 V |
| ✅ | `103` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.45 V |
| ✅ | `82` | 238.5 | 240.3 | 1.037 | 1.045 | 0.8 % | 3.32 V |
| ✅ | `79` | 236.6 | 240.2 | 1.029 | 1.044 | 1.6 % | 2.97 V |
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
  IBR 'pv_23' phase 'b': pg=4.522 kW is within 1 % of its P bound.
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
  IBR 'pv_24' phase 'a': pg=4.714 kW is within 1 % of its P bound.
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
  Line losses are 152.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 7.03 V at bus '92' — reflects the neutral shift under unbalanced loading.

