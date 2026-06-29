# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:23  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -169402.882  
**Solve time:** 0.068 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 29.526 kW |
| Total load | 11.225 kW |
| Total network losses (P) | 18.301 kW |
| Total network losses (Q) | 5.398 kW var |
| Loss fraction | 163.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 14.519 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.081 (`896`) | 4.5 % (`896`) | 14.52 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 238.1 | 248.5 | 1.035 | 1.081 | 4.5 % | 14.52 V |
| ✅ | `949` | 238.8 | 248.0 | 1.038 | 1.078 | 4.0 % | 13.52 V |
| ✅ | `677` | 238.2 | 248.0 | 1.035 | 1.078 | 4.3 % | 14.0 V |
| ✅ | `660` | 238.2 | 248.0 | 1.035 | 1.078 | 4.3 % | 13.91 V |
| ✅ | `661` | 238.2 | 247.9 | 1.035 | 1.078 | 4.2 % | 13.76 V |
| ✅ | `654` | 238.2 | 247.8 | 1.035 | 1.077 | 4.2 % | 13.65 V |
| ✅ | `644` | 238.2 | 247.8 | 1.036 | 1.077 | 4.2 % | 13.63 V |
| ✅ | `895` | 238.9 | 247.8 | 1.039 | 1.077 | 3.9 % | 13.26 V |
| ✅ | `635` | 238.2 | 247.7 | 1.036 | 1.077 | 4.2 % | 13.55 V |
| ✅ | `904` | 238.9 | 247.6 | 1.038 | 1.077 | 3.8 % | 13.16 V |
| ✅ | `849` | 238.9 | 247.5 | 1.039 | 1.076 | 3.8 % | 13.04 V |
| ✅ | `894` | 238.9 | 247.5 | 1.039 | 1.076 | 3.8 % | 12.2 V |
| ✅ | `775` | 238.9 | 247.5 | 1.039 | 1.076 | 3.7 % | 13.14 V |
| ✅ | `808` | 239.7 | 247.2 | 1.042 | 1.075 | 3.2 % | 13.2 V |
| ✅ | `627` | 238.2 | 247.2 | 1.036 | 1.075 | 3.9 % | 12.88 V |
| ✅ | `693` | 239.0 | 247.2 | 1.039 | 1.075 | 3.6 % | 12.86 V |
| ✅ | `673` | 238.9 | 247.2 | 1.039 | 1.075 | 3.6 % | 12.85 V |
| ✅ | `665` | 238.9 | 247.1 | 1.039 | 1.074 | 3.6 % | 12.8 V |
| ✅ | `617` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 12.83 V |
| ✅ | `618` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 12.83 V |
| ✅ | `779` | 239.4 | 247.1 | 1.041 | 1.074 | 3.3 % | 12.99 V |
| ✅ | `608` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 12.8 V |
| ✅ | `659` | 238.9 | 247.1 | 1.039 | 1.074 | 3.6 % | 12.76 V |
| ✅ | `607` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 12.76 V |
| ✅ | `600` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 12.67 V |
| ✅ | `717` | 240.1 | 246.9 | 1.044 | 1.074 | 3.0 % | 13.23 V |
| ✅ | `655` | 239.7 | 246.9 | 1.042 | 1.074 | 3.1 % | 13.04 V |
| ✅ | `609` | 239.6 | 246.9 | 1.042 | 1.074 | 3.2 % | 12.99 V |
| ✅ | `773` | 239.4 | 246.9 | 1.041 | 1.074 | 3.3 % | 12.88 V |
| ✅ | `568` | 238.8 | 246.9 | 1.038 | 1.074 | 3.5 % | 12.61 V |
| ✅ | `545` | 238.2 | 246.5 | 1.036 | 1.072 | 3.6 % | 12.16 V |
| ✅ | `313` | 235.5 | 245.9 | 1.024 | 1.069 | 4.5 % | 11.54 V |
| ✅ | `498` | 236.0 | 245.9 | 1.026 | 1.069 | 4.3 % | 2.59 V |
| ✅ | `303` | 235.5 | 245.9 | 1.024 | 1.069 | 4.5 % | 11.47 V |
| ✅ | `290` | 235.6 | 245.8 | 1.024 | 1.069 | 4.5 % | 11.4 V |
| ✅ | `491` | 236.0 | 245.8 | 1.026 | 1.069 | 4.3 % | 2.59 V |
| ✅ | `282` | 235.6 | 245.8 | 1.024 | 1.069 | 4.4 % | 11.36 V |
| ✅ | `473` | 236.0 | 245.7 | 1.026 | 1.068 | 4.2 % | 2.58 V |
| ✅ | `272` | 235.6 | 245.7 | 1.024 | 1.068 | 4.4 % | 11.27 V |
| ✅ | `472` | 236.0 | 245.6 | 1.026 | 1.068 | 4.2 % | 2.58 V |
| ✅ | `439` | 236.0 | 245.6 | 1.026 | 1.068 | 4.2 % | 2.58 V |
| ✅ | `321` | 235.6 | 245.5 | 1.024 | 1.068 | 4.3 % | 10.99 V |
| ✅ | `536` | 236.0 | 245.5 | 1.026 | 1.067 | 4.1 % | 2.58 V |
| ✅ | `264` | 235.6 | 245.5 | 1.024 | 1.067 | 4.3 % | 10.89 V |
| ✅ | `427` | 236.0 | 245.4 | 1.026 | 1.067 | 4.1 % | 2.59 V |
| ✅ | `263` | 235.6 | 245.2 | 1.024 | 1.066 | 4.2 % | 10.61 V |
| ✅ | `479` | 236.0 | 245.2 | 1.026 | 1.066 | 4.0 % | 2.61 V |
| ✅ | `254` | 235.6 | 245.2 | 1.024 | 1.066 | 4.2 % | 10.54 V |
| ✅ | `377` | 236.0 | 245.2 | 1.026 | 1.066 | 4.0 % | 2.63 V |
| ✅ | `376` | 236.0 | 245.1 | 1.026 | 1.066 | 4.0 % | 2.63 V |
| ✅ | `354` | 236.0 | 245.0 | 1.026 | 1.065 | 3.9 % | 2.67 V |
| ✅ | `229` | 235.7 | 245.0 | 1.025 | 1.065 | 4.0 % | 10.19 V |
| ✅ | `216` | 235.7 | 244.9 | 1.025 | 1.065 | 4.0 % | 10.11 V |
| ✅ | `521` | 236.0 | 244.7 | 1.026 | 1.064 | 3.8 % | 2.79 V |
| ✅ | `530` | 237.4 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.81 V |
| ✅ | `192` | 235.7 | 244.6 | 1.025 | 1.064 | 3.9 % | 9.76 V |
| ✅ | `307` | 236.0 | 244.6 | 1.026 | 1.064 | 3.7 % | 2.84 V |
| ✅ | `175` | 235.7 | 244.6 | 1.025 | 1.063 | 3.9 % | 9.68 V |
| ✅ | `256` | 236.0 | 244.2 | 1.026 | 1.062 | 3.6 % | 3.04 V |
| ✅ | `166` | 235.8 | 244.2 | 1.025 | 1.062 | 3.7 % | 9.02 V |
| ✅ | `247` | 236.0 | 244.2 | 1.026 | 1.062 | 3.5 % | 3.1 V |
| ✅ | `151` | 235.8 | 243.9 | 1.025 | 1.06 | 3.5 % | 8.7 V |
| ✅ | `145` | 235.8 | 243.8 | 1.025 | 1.06 | 3.5 % | 8.62 V |
| ✅ | `138` | 235.8 | 243.7 | 1.025 | 1.06 | 3.4 % | 8.5 V |
| ✅ | `428` | 237.9 | 243.7 | 1.034 | 1.06 | 2.5 % | 8.71 V |
| ✅ | `416` | 237.9 | 243.7 | 1.034 | 1.06 | 2.5 % | 8.69 V |
| ✅ | `391` | 237.8 | 243.7 | 1.034 | 1.06 | 2.6 % | 8.64 V |
| ✅ | `392` | 237.8 | 243.7 | 1.034 | 1.06 | 2.6 % | 8.63 V |
| ✅ | `380` | 237.8 | 243.7 | 1.034 | 1.06 | 2.6 % | 8.63 V |
| ✅ | `366` | 237.7 | 243.7 | 1.033 | 1.06 | 2.6 % | 8.59 V |
| ✅ | `355` | 237.6 | 243.7 | 1.033 | 1.06 | 2.6 % | 8.57 V |
| ✅ | `144` | 235.8 | 243.7 | 1.025 | 1.06 | 3.4 % | 8.45 V |
| ✅ | `441` | 237.5 | 243.7 | 1.032 | 1.059 | 2.7 % | 8.51 V |
| ✅ | `348` | 237.7 | 243.7 | 1.033 | 1.059 | 2.6 % | 8.65 V |
| ✅ | `327` | 237.3 | 243.7 | 1.032 | 1.059 | 2.8 % | 8.44 V |
| ✅ | `384` | 237.3 | 243.7 | 1.032 | 1.059 | 2.8 % | 8.42 V |
| ✅ | `318` | 237.2 | 243.7 | 1.031 | 1.059 | 2.8 % | 8.4 V |
| ✅ | `300` | 237.1 | 243.7 | 1.031 | 1.059 | 2.8 % | 8.35 V |
| ✅ | `131` | 235.8 | 243.6 | 1.025 | 1.059 | 3.4 % | 8.38 V |
| ✅ | `226` | 236.0 | 243.6 | 1.026 | 1.059 | 3.3 % | 3.49 V |
| ✅ | `220` | 236.0 | 243.5 | 1.026 | 1.059 | 3.3 % | 3.55 V |
| ✅ | `116` | 235.9 | 243.1 | 1.026 | 1.057 | 3.1 % | 7.51 V |
| ✅ | `128` | 235.9 | 243.0 | 1.026 | 1.056 | 3.1 % | 7.32 V |
| ✅ | `219` | 236.0 | 242.9 | 1.026 | 1.056 | 3.0 % | 4.08 V |
| ✅ | `208` | 236.0 | 242.8 | 1.026 | 1.056 | 3.0 % | 4.15 V |
| ✅ | `198` | 235.9 | 242.8 | 1.026 | 1.056 | 3.0 % | 7.2 V |
| ✅ | `104` | 235.9 | 242.8 | 1.026 | 1.056 | 3.0 % | 7.25 V |
| ✅ | `108` | 235.9 | 242.7 | 1.026 | 1.055 | 2.9 % | 7.05 V |
| ✅ | `99` | 235.9 | 242.6 | 1.026 | 1.055 | 2.9 % | 7.01 V |
| ✅ | `201` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 5.08 V |
| ✅ | `188` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 5.18 V |
| ✅ | `179` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 5.94 V |
| ✅ | `162` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 6.05 V |
| ✅ | `187` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 6.35 V |
| ✅ | `147` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 6.46 V |
| ✅ | `90` | 236.0 | 242.5 | 1.026 | 1.055 | 2.8 % | 6.86 V |
| ✅ | `82` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.88 V |
| ✅ | `62` | 234.6 | 238.7 | 1.02 | 1.038 | 1.8 % | 4.8 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.888 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=3.793 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.924 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.975 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.814 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=3.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.146 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.175 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.429 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.318 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.393 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=4.127 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.411 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.24 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=3.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.109 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.054 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=3.819 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.32 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=3.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.553 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.267 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=3.965 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.477 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.016 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=3.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.863 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.142 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.437 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=3.816 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.458 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.48 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 163.0 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 14.52 V at bus '896' — reflects the neutral shift under unbalanced loading.

