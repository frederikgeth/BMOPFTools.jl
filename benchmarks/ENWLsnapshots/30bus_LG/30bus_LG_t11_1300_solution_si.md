# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -124106.0661  
**Solve time:** 0.06 s  
**Findings:** 0 errors · 25 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.15 kW |
| Total load | 6.004 kW |
| Total network losses (P) | 10.146 kW |
| Total network losses (Q) | 3.737 kW var |
| Loss fraction | 169.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.874 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.065 (`92`) | 3.4 % (`92`) | 6.87 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 237.3 | 245.0 | 1.032 | 1.065 | 3.4 % | 6.87 V |
| ✅ | `107` | 237.3 | 245.0 | 1.032 | 1.065 | 3.4 % | 6.86 V |
| ✅ | `95` | 237.3 | 244.9 | 1.032 | 1.065 | 3.3 % | 6.78 V |
| ✅ | `80` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 6.57 V |
| ✅ | `98` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 6.55 V |
| ✅ | `86` | 237.3 | 244.6 | 1.032 | 1.064 | 3.2 % | 6.53 V |
| ✅ | `89` | 237.3 | 244.6 | 1.032 | 1.064 | 3.2 % | 6.46 V |
| ✅ | `104` | 237.3 | 244.6 | 1.032 | 1.063 | 3.2 % | 6.45 V |
| ✅ | `83` | 237.3 | 244.6 | 1.032 | 1.063 | 3.2 % | 6.41 V |
| ✅ | `101` | 237.3 | 244.5 | 1.032 | 1.063 | 3.1 % | 6.36 V |
| ✅ | `102` | 237.4 | 243.3 | 1.032 | 1.058 | 2.6 % | 3.19 V |
| ✅ | `105` | 237.4 | 243.3 | 1.032 | 1.058 | 2.6 % | 3.18 V |
| ✅ | `84` | 237.4 | 243.1 | 1.032 | 1.057 | 2.5 % | 3.08 V |
| ✅ | `99` | 237.4 | 243.1 | 1.032 | 1.057 | 2.5 % | 3.01 V |
| ✅ | `90` | 237.4 | 243.0 | 1.032 | 1.057 | 2.5 % | 2.99 V |
| ✅ | `93` | 237.4 | 242.9 | 1.032 | 1.056 | 2.4 % | 2.98 V |
| ✅ | `87` | 237.4 | 242.9 | 1.032 | 1.056 | 2.4 % | 2.84 V |
| ✅ | `96` | 237.4 | 242.8 | 1.032 | 1.056 | 2.4 % | 2.81 V |
| ✅ | `81` | 237.4 | 242.8 | 1.032 | 1.056 | 2.4 % | 2.79 V |
| ✅ | `106` | 239.1 | 241.7 | 1.039 | 1.051 | 1.1 % | 4.67 V |
| ✅ | `97` | 239.1 | 241.7 | 1.039 | 1.051 | 1.1 % | 4.67 V |
| ✅ | `88` | 239.1 | 241.7 | 1.039 | 1.051 | 1.1 % | 4.66 V |
| ✅ | `91` | 239.1 | 241.7 | 1.039 | 1.051 | 1.1 % | 4.66 V |
| ✅ | `94` | 239.1 | 241.6 | 1.039 | 1.05 | 1.1 % | 4.56 V |
| ✅ | `100` | 239.1 | 241.5 | 1.039 | 1.05 | 1.1 % | 4.53 V |
| ✅ | `103` | 239.1 | 241.4 | 1.039 | 1.05 | 1.0 % | 4.37 V |
| ✅ | `82` | 239.1 | 240.9 | 1.039 | 1.048 | 0.8 % | 3.95 V |
| ✅ | `85` | 239.1 | 240.9 | 1.039 | 1.048 | 0.8 % | 3.75 V |
| ✅ | `79` | 237.4 | 240.9 | 1.032 | 1.047 | 1.5 % | 2.62 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=5.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=4.643 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.242 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=5.158 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.222 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'a': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=5.218 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'a': pg=5.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'a': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=4.935 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.243 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=5.219 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.025 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.226 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=5.242 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 169.0 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.87 V at bus '92' — reflects the neutral shift under unbalanced loading.

