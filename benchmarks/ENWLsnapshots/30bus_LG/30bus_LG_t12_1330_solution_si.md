# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:08:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -125662.7122  
**Solve time:** 0.063 s  
**Findings:** 0 errors · 23 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.681 kW |
| Total load | 6.265 kW |
| Total network losses (P) | 10.416 kW |
| Total network losses (Q) | 3.837 kW var |
| Loss fraction | 166.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.887 V (bus `92`) |

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
| ✅ | `100` | 230.0 V | 30 | 1.0 (`sourcebus`) | 1.066 (`92`) | 3.4 % (`92`) | 6.89 V (`92`) |

### Per-bus detail

**Zone `100`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `92` | 237.3 | 245.1 | 1.032 | 1.066 | 3.4 % | 6.89 V |
| ✅ | `104` | 237.3 | 245.1 | 1.032 | 1.066 | 3.4 % | 6.89 V |
| ✅ | `89` | 237.3 | 245.1 | 1.032 | 1.066 | 3.4 % | 6.88 V |
| ✅ | `107` | 237.3 | 245.1 | 1.032 | 1.066 | 3.4 % | 6.88 V |
| ✅ | `83` | 237.3 | 245.1 | 1.032 | 1.066 | 3.4 % | 6.88 V |
| ✅ | `95` | 237.3 | 244.8 | 1.032 | 1.065 | 3.3 % | 6.59 V |
| ✅ | `98` | 237.3 | 244.8 | 1.032 | 1.064 | 3.2 % | 6.6 V |
| ✅ | `101` | 237.3 | 244.6 | 1.032 | 1.064 | 3.2 % | 6.4 V |
| ✅ | `86` | 237.3 | 244.6 | 1.032 | 1.064 | 3.2 % | 6.42 V |
| ✅ | `80` | 237.4 | 244.4 | 1.032 | 1.063 | 3.1 % | 6.2 V |
| ✅ | `81` | 237.4 | 243.4 | 1.032 | 1.058 | 2.6 % | 3.12 V |
| ✅ | `99` | 237.4 | 243.4 | 1.032 | 1.058 | 2.6 % | 3.12 V |
| ✅ | `90` | 237.4 | 243.3 | 1.032 | 1.058 | 2.6 % | 3.12 V |
| ✅ | `96` | 237.4 | 243.2 | 1.032 | 1.058 | 2.5 % | 3.02 V |
| ✅ | `105` | 237.4 | 243.0 | 1.032 | 1.057 | 2.4 % | 2.86 V |
| ✅ | `102` | 237.4 | 243.0 | 1.032 | 1.057 | 2.4 % | 2.84 V |
| ✅ | `87` | 237.4 | 243.0 | 1.032 | 1.057 | 2.4 % | 2.85 V |
| ✅ | `93` | 237.4 | 243.0 | 1.032 | 1.057 | 2.4 % | 2.93 V |
| ✅ | `84` | 237.4 | 242.8 | 1.032 | 1.056 | 2.3 % | 2.74 V |
| ✅ | `88` | 239.1 | 241.8 | 1.04 | 1.051 | 1.1 % | 4.73 V |
| ✅ | `100` | 239.1 | 241.8 | 1.04 | 1.051 | 1.1 % | 4.72 V |
| ✅ | `91` | 239.1 | 241.8 | 1.04 | 1.051 | 1.1 % | 4.72 V |
| ✅ | `97` | 239.1 | 241.8 | 1.04 | 1.051 | 1.1 % | 4.72 V |
| ✅ | `106` | 239.1 | 241.7 | 1.04 | 1.051 | 1.1 % | 4.68 V |
| ✅ | `94` | 239.1 | 241.5 | 1.04 | 1.05 | 1.0 % | 4.51 V |
| ✅ | `103` | 239.1 | 241.4 | 1.04 | 1.05 | 1.0 % | 4.38 V |
| ✅ | `82` | 239.1 | 241.2 | 1.04 | 1.049 | 0.9 % | 4.18 V |
| ✅ | `85` | 239.1 | 241.1 | 1.04 | 1.048 | 0.9 % | 4.12 V |
| ✅ | `79` | 237.4 | 241.0 | 1.032 | 1.048 | 1.5 % | 2.64 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'a': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'b': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'c': pg=5.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'b': pg=5.066 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'c': pg=5.157 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.792 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'b': pg=4.787 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'c': pg=5.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'b': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'c': pg=5.077 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.743 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=5.173 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'b': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'b': pg=5.224 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'c': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'a': pg=4.74 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 166.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.89 V at bus '92' — reflects the neutral shift under unbalanced loading.

