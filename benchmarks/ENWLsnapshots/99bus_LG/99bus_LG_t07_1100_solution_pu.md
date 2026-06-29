# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:16  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -152780.5394  
**Solve time:** 0.046 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 24.766 kW |
| Total load | 11.429 kW |
| Total network losses (P) | 13.337 kW |
| Total network losses (Q) | 3.883 kW var |
| Loss fraction | 116.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 13.415 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.078 (`896`) | 4.2 % (`313`) | 13.41 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 238.7 | 247.9 | 1.038 | 1.078 | 4.0 % | 13.41 V |
| ✅ | `949` | 239.0 | 247.6 | 1.039 | 1.076 | 3.7 % | 12.83 V |
| ✅ | `677` | 238.7 | 247.5 | 1.038 | 1.076 | 3.8 % | 13.01 V |
| ✅ | `660` | 238.7 | 247.4 | 1.038 | 1.076 | 3.8 % | 12.95 V |
| ✅ | `661` | 238.7 | 247.4 | 1.038 | 1.076 | 3.8 % | 12.85 V |
| ✅ | `654` | 238.7 | 247.3 | 1.038 | 1.075 | 3.7 % | 12.77 V |
| ✅ | `644` | 238.7 | 247.3 | 1.038 | 1.075 | 3.7 % | 12.74 V |
| ✅ | `895` | 239.0 | 247.3 | 1.039 | 1.075 | 3.6 % | 12.55 V |
| ✅ | `635` | 238.7 | 247.2 | 1.038 | 1.075 | 3.7 % | 12.68 V |
| ✅ | `904` | 239.0 | 247.2 | 1.039 | 1.075 | 3.5 % | 12.48 V |
| ✅ | `849` | 239.0 | 247.1 | 1.039 | 1.074 | 3.5 % | 12.36 V |
| ✅ | `894` | 239.7 | 247.1 | 1.042 | 1.074 | 3.2 % | 11.61 V |
| ✅ | `775` | 238.9 | 247.1 | 1.039 | 1.074 | 3.6 % | 12.46 V |
| ✅ | `808` | 238.9 | 246.8 | 1.039 | 1.073 | 3.4 % | 12.48 V |
| ✅ | `693` | 238.9 | 246.8 | 1.039 | 1.073 | 3.4 % | 12.19 V |
| ✅ | `673` | 238.9 | 246.8 | 1.039 | 1.073 | 3.4 % | 12.18 V |
| ✅ | `627` | 238.7 | 246.8 | 1.038 | 1.073 | 3.5 % | 12.13 V |
| ✅ | `665` | 238.9 | 246.7 | 1.039 | 1.073 | 3.4 % | 12.13 V |
| ✅ | `617` | 238.7 | 246.7 | 1.038 | 1.073 | 3.5 % | 12.1 V |
| ✅ | `618` | 238.7 | 246.7 | 1.038 | 1.073 | 3.5 % | 12.1 V |
| ✅ | `779` | 238.9 | 246.7 | 1.039 | 1.073 | 3.4 % | 12.34 V |
| ✅ | `608` | 238.7 | 246.7 | 1.038 | 1.073 | 3.5 % | 12.07 V |
| ✅ | `659` | 238.9 | 246.7 | 1.039 | 1.073 | 3.4 % | 12.09 V |
| ✅ | `607` | 238.7 | 246.7 | 1.038 | 1.072 | 3.5 % | 12.03 V |
| ✅ | `600` | 238.7 | 246.6 | 1.038 | 1.072 | 3.4 % | 11.95 V |
| ✅ | `717` | 238.9 | 246.6 | 1.039 | 1.072 | 3.3 % | 12.51 V |
| ✅ | `655` | 238.9 | 246.6 | 1.039 | 1.072 | 3.3 % | 12.31 V |
| ✅ | `609` | 238.9 | 246.6 | 1.039 | 1.072 | 3.3 % | 12.27 V |
| ✅ | `773` | 238.9 | 246.6 | 1.039 | 1.072 | 3.3 % | 12.21 V |
| ✅ | `568` | 238.8 | 246.5 | 1.038 | 1.072 | 3.3 % | 11.94 V |
| ✅ | `545` | 238.7 | 246.2 | 1.038 | 1.07 | 3.2 % | 11.5 V |
| ✅ | `313` | 236.1 | 245.8 | 1.026 | 1.069 | 4.2 % | 11.19 V |
| ✅ | `303` | 236.1 | 245.8 | 1.026 | 1.069 | 4.2 % | 11.13 V |
| ✅ | `290` | 236.1 | 245.7 | 1.026 | 1.068 | 4.2 % | 11.07 V |
| ✅ | `282` | 236.1 | 245.7 | 1.026 | 1.068 | 4.2 % | 11.05 V |
| ✅ | `272` | 236.1 | 245.6 | 1.026 | 1.068 | 4.2 % | 10.97 V |
| ✅ | `321` | 236.1 | 245.4 | 1.027 | 1.067 | 4.1 % | 10.72 V |
| ✅ | `264` | 236.1 | 245.4 | 1.027 | 1.067 | 4.0 % | 10.65 V |
| ✅ | `263` | 236.1 | 245.2 | 1.027 | 1.066 | 3.9 % | 10.42 V |
| ✅ | `254` | 236.1 | 245.1 | 1.027 | 1.066 | 3.9 % | 10.36 V |
| ✅ | `229` | 236.2 | 244.9 | 1.027 | 1.065 | 3.8 % | 10.08 V |
| ✅ | `216` | 236.2 | 244.8 | 1.027 | 1.064 | 3.8 % | 10.01 V |
| ✅ | `192` | 236.2 | 244.6 | 1.027 | 1.063 | 3.7 % | 9.72 V |
| ✅ | `175` | 236.2 | 244.5 | 1.027 | 1.063 | 3.6 % | 9.65 V |
| ✅ | `530` | 238.1 | 244.5 | 1.035 | 1.063 | 2.8 % | 9.42 V |
| ✅ | `166` | 236.3 | 244.1 | 1.027 | 1.061 | 3.4 % | 9.08 V |
| ✅ | `151` | 236.3 | 243.8 | 1.027 | 1.06 | 3.3 % | 8.8 V |
| ✅ | `145` | 236.3 | 243.7 | 1.027 | 1.06 | 3.2 % | 8.72 V |
| ✅ | `138` | 236.3 | 243.6 | 1.027 | 1.059 | 3.2 % | 8.62 V |
| ✅ | `144` | 236.3 | 243.6 | 1.027 | 1.059 | 3.2 % | 8.58 V |
| ✅ | `428` | 238.5 | 243.6 | 1.037 | 1.059 | 2.2 % | 8.33 V |
| ✅ | `416` | 238.4 | 243.6 | 1.037 | 1.059 | 2.2 % | 8.31 V |
| ✅ | `391` | 238.3 | 243.6 | 1.036 | 1.059 | 2.3 % | 8.3 V |
| ✅ | `380` | 238.3 | 243.5 | 1.036 | 1.059 | 2.3 % | 8.29 V |
| ✅ | `392` | 238.3 | 243.5 | 1.036 | 1.059 | 2.3 % | 8.29 V |
| ✅ | `366` | 238.2 | 243.5 | 1.036 | 1.059 | 2.3 % | 8.27 V |
| ✅ | `355` | 238.2 | 243.5 | 1.036 | 1.059 | 2.3 % | 8.26 V |
| ✅ | `131` | 236.3 | 243.5 | 1.027 | 1.059 | 3.2 % | 8.51 V |
| ✅ | `441` | 238.0 | 243.5 | 1.035 | 1.059 | 2.4 % | 8.23 V |
| ✅ | `348` | 238.1 | 243.5 | 1.035 | 1.059 | 2.3 % | 8.3 V |
| ✅ | `327` | 237.9 | 243.5 | 1.034 | 1.059 | 2.4 % | 8.21 V |
| ✅ | `384` | 237.8 | 243.5 | 1.034 | 1.059 | 2.5 % | 8.19 V |
| ✅ | `318` | 237.8 | 243.5 | 1.034 | 1.059 | 2.5 % | 8.19 V |
| ✅ | `300` | 237.7 | 243.5 | 1.033 | 1.059 | 2.5 % | 8.18 V |
| ✅ | `498` | 236.4 | 243.5 | 1.028 | 1.059 | 3.1 % | 5.53 V |
| ✅ | `491` | 236.4 | 243.4 | 1.028 | 1.058 | 3.0 % | 5.52 V |
| ✅ | `473` | 236.4 | 243.3 | 1.028 | 1.058 | 3.0 % | 5.5 V |
| ✅ | `472` | 236.4 | 243.3 | 1.028 | 1.058 | 3.0 % | 5.49 V |
| ✅ | `439` | 236.4 | 243.2 | 1.028 | 1.057 | 2.9 % | 5.47 V |
| ✅ | `536` | 236.4 | 243.2 | 1.028 | 1.057 | 2.9 % | 5.47 V |
| ✅ | `427` | 236.4 | 243.1 | 1.028 | 1.057 | 2.9 % | 5.45 V |
| ✅ | `116` | 236.4 | 242.9 | 1.028 | 1.056 | 2.9 % | 7.78 V |
| ✅ | `479` | 236.4 | 242.9 | 1.028 | 1.056 | 2.8 % | 5.43 V |
| ✅ | `377` | 236.4 | 242.9 | 1.028 | 1.056 | 2.8 % | 5.43 V |
| ✅ | `376` | 236.4 | 242.8 | 1.028 | 1.056 | 2.8 % | 5.42 V |
| ✅ | `128` | 236.4 | 242.8 | 1.028 | 1.056 | 2.8 % | 7.6 V |
| ✅ | `354` | 236.4 | 242.7 | 1.028 | 1.055 | 2.7 % | 5.42 V |
| ✅ | `104` | 236.4 | 242.7 | 1.028 | 1.055 | 2.7 % | 7.51 V |
| ✅ | `198` | 236.4 | 242.6 | 1.028 | 1.055 | 2.7 % | 7.47 V |
| ✅ | `108` | 236.4 | 242.5 | 1.028 | 1.054 | 2.7 % | 7.34 V |
| ✅ | `99` | 236.4 | 242.5 | 1.028 | 1.054 | 2.7 % | 7.3 V |
| ✅ | `521` | 236.4 | 242.5 | 1.028 | 1.054 | 2.6 % | 5.41 V |
| ✅ | `307` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.42 V |
| ✅ | `256` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.44 V |
| ✅ | `247` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.45 V |
| ✅ | `226` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.54 V |
| ✅ | `220` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.56 V |
| ✅ | `219` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.73 V |
| ✅ | `208` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 5.77 V |
| ✅ | `201` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.19 V |
| ✅ | `188` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.24 V |
| ✅ | `179` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.66 V |
| ✅ | `162` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.72 V |
| ✅ | `187` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.91 V |
| ✅ | `147` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 6.97 V |
| ✅ | `90` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 7.18 V |
| ✅ | `82` | 236.4 | 242.4 | 1.028 | 1.054 | 2.6 % | 7.19 V |
| ✅ | `62` | 234.7 | 238.6 | 1.02 | 1.037 | 1.7 % | 4.91 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.404 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.915 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.446 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=3.58 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=3.443 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=3.663 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=3.692 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.009 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=3.973 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=3.993 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.613 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=3.431 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=3.466 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=3.543 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=3.399 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.803 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=3.509 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.082 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=3.779 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.381 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.381 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=3.428 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=3.932 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=3.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=3.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=3.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=3.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=3.995 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=3.492 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=3.99 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=3.776 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.695 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.401 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=3.678 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.534 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=3.383 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 116.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 13.41 V at bus '896' — reflects the neutral shift under unbalanced loading.

