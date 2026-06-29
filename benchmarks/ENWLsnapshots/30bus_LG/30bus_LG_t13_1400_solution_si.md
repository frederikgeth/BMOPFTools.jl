# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -125346.49  
**Solve time:** 0.055 s  
**Findings:** 0 errors · 20 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.045 kW |
| Total load | 6.655 kW |
| Total network losses (P) | 10.39 kW |
| Total network losses (Q) | 3.814 kW var |
| Loss fraction | 156.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.399 V (bus `95`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.066 (`95`) | 3.5 % (`95`) | 7.4 V (`95`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `95` | 237.1 | 245.2 | 1.031 | 1.066 | 3.5 % | 7.4 V |
| ✅ | `92` | 237.1 | 245.2 | 1.031 | 1.066 | 3.5 % | 7.37 V |
| ✅ | `107` | 237.1 | 245.2 | 1.031 | 1.066 | 3.5 % | 7.37 V |
| ✅ | `104` | 237.1 | 245.2 | 1.031 | 1.066 | 3.5 % | 7.36 V |
| ✅ | `83` | 237.1 | 245.2 | 1.031 | 1.066 | 3.5 % | 7.36 V |
| ✅ | `89` | 237.1 | 245.1 | 1.031 | 1.066 | 3.5 % | 7.23 V |
| ✅ | `101` | 237.1 | 245.0 | 1.031 | 1.065 | 3.4 % | 7.23 V |
| ✅ | `80` | 237.1 | 244.9 | 1.031 | 1.065 | 3.4 % | 7.08 V |
| ✅ | `86` | 237.1 | 244.8 | 1.031 | 1.064 | 3.3 % | 7.01 V |
| ✅ | `98` | 237.1 | 244.6 | 1.031 | 1.063 | 3.2 % | 6.77 V |
| ✅ | `102` | 237.2 | 243.3 | 1.031 | 1.058 | 2.6 % | 3.21 V |
| ✅ | `96` | 237.2 | 243.3 | 1.031 | 1.058 | 2.6 % | 3.21 V |
| ✅ | `99` | 237.2 | 243.3 | 1.031 | 1.058 | 2.6 % | 3.2 V |
| ✅ | `87` | 237.2 | 243.3 | 1.031 | 1.058 | 2.6 % | 3.2 V |
| ✅ | `90` | 237.2 | 243.3 | 1.031 | 1.058 | 2.6 % | 3.2 V |
| ✅ | `81` | 237.2 | 243.0 | 1.031 | 1.056 | 2.5 % | 2.99 V |
| ✅ | `105` | 237.2 | 243.0 | 1.031 | 1.056 | 2.5 % | 2.98 V |
| ✅ | `84` | 237.2 | 242.7 | 1.031 | 1.055 | 2.4 % | 2.86 V |
| ✅ | `93` | 237.2 | 242.6 | 1.031 | 1.055 | 2.3 % | 2.86 V |
| ✅ | `100` | 239.1 | 241.5 | 1.039 | 1.05 | 1.1 % | 4.87 V |
| ✅ | `97` | 239.1 | 241.4 | 1.039 | 1.05 | 1.0 % | 4.79 V |
| ✅ | `94` | 239.1 | 241.4 | 1.039 | 1.05 | 1.0 % | 4.75 V |
| ✅ | `88` | 239.1 | 241.2 | 1.039 | 1.049 | 0.9 % | 4.63 V |
| ✅ | `106` | 239.1 | 241.2 | 1.039 | 1.049 | 0.9 % | 4.63 V |
| ✅ | `91` | 239.1 | 241.2 | 1.039 | 1.049 | 0.9 % | 4.59 V |
| ✅ | `103` | 239.1 | 241.1 | 1.039 | 1.048 | 0.9 % | 4.49 V |
| ✅ | `85` | 239.1 | 241.1 | 1.039 | 1.048 | 0.9 % | 4.33 V |
| ✅ | `82` | 239.1 | 241.1 | 1.039 | 1.048 | 0.9 % | 4.32 V |
| ✅ | `79` | 237.2 | 241.1 | 1.031 | 1.048 | 1.7 % | 3.13 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.243 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=5.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.852 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.997 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.218 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.833 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.784 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=5.218 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=4.828 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=5.247 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=5.218 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=4.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.202 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.121 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=4.781 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 156.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 7.4 V at bus '95' — reflects the neutral shift under unbalanced loading.

