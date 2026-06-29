# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:23  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -151818.764  
**Solve time:** 0.044 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 25.728 kW |
| Total load | 11.429 kW |
| Total network losses (P) | 14.299 kW |
| Total network losses (Q) | 4.214 kW var |
| Loss fraction | 125.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 12.744 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.073 (`896`) | 4.1 % (`313`) | 12.74 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 237.7 | 246.7 | 1.033 | 1.073 | 3.9 % | 12.74 V |
| ✅ | `949` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 11.98 V |
| ✅ | `677` | 237.7 | 246.3 | 1.033 | 1.071 | 3.8 % | 12.35 V |
| ✅ | `660` | 237.7 | 246.3 | 1.033 | 1.071 | 3.7 % | 12.27 V |
| ✅ | `661` | 237.7 | 246.2 | 1.033 | 1.071 | 3.7 % | 12.15 V |
| ✅ | `654` | 237.7 | 246.2 | 1.033 | 1.07 | 3.7 % | 12.06 V |
| ✅ | `644` | 237.7 | 246.1 | 1.033 | 1.07 | 3.7 % | 12.04 V |
| ✅ | `895` | 238.3 | 246.1 | 1.036 | 1.07 | 3.4 % | 11.73 V |
| ✅ | `635` | 237.7 | 246.1 | 1.033 | 1.07 | 3.6 % | 11.97 V |
| ✅ | `904` | 238.3 | 246.0 | 1.036 | 1.07 | 3.3 % | 11.67 V |
| ✅ | `849` | 238.3 | 245.9 | 1.036 | 1.069 | 3.3 % | 11.56 V |
| ✅ | `894` | 238.3 | 245.9 | 1.036 | 1.069 | 3.3 % | 10.79 V |
| ✅ | `775` | 238.4 | 245.9 | 1.036 | 1.069 | 3.3 % | 11.66 V |
| ✅ | `808` | 239.1 | 245.6 | 1.04 | 1.068 | 2.8 % | 11.73 V |
| ✅ | `693` | 238.4 | 245.6 | 1.037 | 1.068 | 3.1 % | 11.43 V |
| ✅ | `673` | 238.4 | 245.6 | 1.037 | 1.068 | 3.1 % | 11.42 V |
| ✅ | `627` | 237.7 | 245.6 | 1.033 | 1.068 | 3.4 % | 11.42 V |
| ✅ | `665` | 238.4 | 245.6 | 1.036 | 1.068 | 3.1 % | 11.38 V |
| ✅ | `617` | 237.7 | 245.6 | 1.033 | 1.068 | 3.4 % | 11.38 V |
| ✅ | `618` | 237.7 | 245.6 | 1.033 | 1.068 | 3.4 % | 11.38 V |
| ✅ | `608` | 237.7 | 245.6 | 1.033 | 1.068 | 3.4 % | 11.36 V |
| ✅ | `779` | 238.9 | 245.5 | 1.039 | 1.068 | 2.9 % | 11.62 V |
| ✅ | `659` | 238.4 | 245.5 | 1.036 | 1.068 | 3.1 % | 11.34 V |
| ✅ | `607` | 237.7 | 245.5 | 1.034 | 1.067 | 3.4 % | 11.32 V |
| ✅ | `600` | 237.7 | 245.5 | 1.034 | 1.067 | 3.4 % | 11.24 V |
| ✅ | `717` | 239.5 | 245.4 | 1.041 | 1.067 | 2.6 % | 11.8 V |
| ✅ | `655` | 239.1 | 245.4 | 1.04 | 1.067 | 2.8 % | 11.59 V |
| ✅ | `609` | 239.0 | 245.4 | 1.039 | 1.067 | 2.8 % | 11.55 V |
| ✅ | `773` | 238.8 | 245.4 | 1.038 | 1.067 | 2.9 % | 11.51 V |
| ✅ | `568` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 11.21 V |
| ✅ | `545` | 237.7 | 245.0 | 1.034 | 1.065 | 3.2 % | 10.81 V |
| ✅ | `313` | 235.2 | 244.7 | 1.022 | 1.064 | 4.1 % | 10.48 V |
| ✅ | `303` | 235.2 | 244.7 | 1.022 | 1.064 | 4.1 % | 10.41 V |
| ✅ | `290` | 235.2 | 244.6 | 1.023 | 1.064 | 4.1 % | 10.35 V |
| ✅ | `282` | 235.2 | 244.6 | 1.023 | 1.064 | 4.1 % | 10.33 V |
| ✅ | `272` | 235.2 | 244.5 | 1.023 | 1.063 | 4.1 % | 10.24 V |
| ✅ | `321` | 235.2 | 244.3 | 1.023 | 1.062 | 4.0 % | 9.97 V |
| ✅ | `264` | 235.2 | 244.3 | 1.023 | 1.062 | 3.9 % | 9.89 V |
| ✅ | `263` | 235.2 | 244.1 | 1.023 | 1.061 | 3.9 % | 9.64 V |
| ✅ | `254` | 235.2 | 244.1 | 1.023 | 1.061 | 3.8 % | 9.58 V |
| ✅ | `498` | 235.6 | 244.0 | 1.024 | 1.061 | 3.7 % | 2.09 V |
| ✅ | `491` | 235.6 | 244.0 | 1.024 | 1.061 | 3.7 % | 2.09 V |
| ✅ | `473` | 235.6 | 243.9 | 1.024 | 1.061 | 3.6 % | 2.1 V |
| ✅ | `472` | 235.6 | 243.8 | 1.024 | 1.06 | 3.6 % | 2.11 V |
| ✅ | `229` | 235.3 | 243.8 | 1.023 | 1.06 | 3.7 % | 9.27 V |
| ✅ | `439` | 235.6 | 243.8 | 1.024 | 1.06 | 3.6 % | 2.12 V |
| ✅ | `216` | 235.3 | 243.8 | 1.023 | 1.06 | 3.7 % | 9.19 V |
| ✅ | `536` | 235.6 | 243.7 | 1.024 | 1.06 | 3.5 % | 2.13 V |
| ✅ | `427` | 235.6 | 243.6 | 1.024 | 1.059 | 3.5 % | 2.15 V |
| ✅ | `192` | 235.3 | 243.6 | 1.023 | 1.059 | 3.6 % | 8.88 V |
| ✅ | `479` | 235.6 | 243.5 | 1.024 | 1.059 | 3.4 % | 2.19 V |
| ✅ | `175` | 235.3 | 243.5 | 1.023 | 1.059 | 3.6 % | 8.8 V |
| ✅ | `377` | 235.6 | 243.4 | 1.024 | 1.058 | 3.4 % | 2.22 V |
| ✅ | `530` | 236.9 | 243.4 | 1.03 | 1.058 | 2.8 % | 8.78 V |
| ✅ | `376` | 235.6 | 243.4 | 1.024 | 1.058 | 3.4 % | 2.23 V |
| ✅ | `354` | 235.6 | 243.3 | 1.024 | 1.058 | 3.4 % | 2.27 V |
| ✅ | `166` | 235.4 | 243.1 | 1.023 | 1.057 | 3.3 % | 8.17 V |
| ✅ | `521` | 235.6 | 243.0 | 1.024 | 1.057 | 3.2 % | 2.42 V |
| ✅ | `307` | 235.6 | 242.9 | 1.024 | 1.056 | 3.2 % | 2.48 V |
| ✅ | `151` | 235.4 | 242.8 | 1.023 | 1.056 | 3.2 % | 7.9 V |
| ✅ | `145` | 235.4 | 242.7 | 1.023 | 1.055 | 3.2 % | 7.82 V |
| ✅ | `138` | 235.4 | 242.7 | 1.024 | 1.055 | 3.1 % | 7.71 V |
| ✅ | `144` | 235.4 | 242.6 | 1.024 | 1.055 | 3.1 % | 7.67 V |
| ✅ | `256` | 235.6 | 242.6 | 1.024 | 1.055 | 3.1 % | 2.7 V |
| ✅ | `428` | 237.4 | 242.6 | 1.032 | 1.055 | 2.2 % | 7.88 V |
| ✅ | `131` | 235.4 | 242.6 | 1.024 | 1.055 | 3.1 % | 7.6 V |
| ✅ | `416` | 237.3 | 242.6 | 1.032 | 1.055 | 2.3 % | 7.84 V |
| ✅ | `391` | 237.3 | 242.6 | 1.032 | 1.055 | 2.3 % | 7.8 V |
| ✅ | `380` | 237.2 | 242.6 | 1.031 | 1.055 | 2.3 % | 7.79 V |
| ✅ | `392` | 237.2 | 242.6 | 1.031 | 1.055 | 2.3 % | 7.79 V |
| ✅ | `366` | 237.2 | 242.6 | 1.031 | 1.055 | 2.3 % | 7.75 V |
| ✅ | `355` | 237.1 | 242.5 | 1.031 | 1.055 | 2.4 % | 7.73 V |
| ✅ | `441` | 237.0 | 242.5 | 1.03 | 1.055 | 2.4 % | 7.66 V |
| ✅ | `247` | 235.6 | 242.5 | 1.024 | 1.054 | 3.0 % | 2.76 V |
| ✅ | `348` | 237.1 | 242.5 | 1.031 | 1.054 | 2.4 % | 7.76 V |
| ✅ | `327` | 236.8 | 242.5 | 1.03 | 1.054 | 2.5 % | 7.61 V |
| ✅ | `384` | 236.8 | 242.5 | 1.029 | 1.054 | 2.5 % | 7.57 V |
| ✅ | `318` | 236.7 | 242.5 | 1.029 | 1.054 | 2.5 % | 7.56 V |
| ✅ | `300` | 236.6 | 242.5 | 1.029 | 1.054 | 2.6 % | 7.52 V |
| ✅ | `226` | 235.6 | 242.0 | 1.024 | 1.052 | 2.8 % | 3.14 V |
| ✅ | `116` | 235.5 | 242.0 | 1.024 | 1.052 | 2.8 % | 6.8 V |
| ✅ | `220` | 235.6 | 242.0 | 1.024 | 1.052 | 2.8 % | 3.2 V |
| ✅ | `128` | 235.5 | 241.9 | 1.024 | 1.052 | 2.8 % | 6.6 V |
| ✅ | `104` | 235.5 | 241.8 | 1.024 | 1.051 | 2.7 % | 6.56 V |
| ✅ | `198` | 235.5 | 241.7 | 1.024 | 1.051 | 2.7 % | 6.49 V |
| ✅ | `108` | 235.5 | 241.6 | 1.024 | 1.051 | 2.6 % | 6.38 V |
| ✅ | `99` | 235.5 | 241.6 | 1.024 | 1.05 | 2.6 % | 6.34 V |
| ✅ | `219` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 3.69 V |
| ✅ | `208` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 3.76 V |
| ✅ | `201` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 4.63 V |
| ✅ | `188` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 4.71 V |
| ✅ | `179` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 5.4 V |
| ✅ | `162` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 5.49 V |
| ✅ | `187` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 5.78 V |
| ✅ | `147` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 5.86 V |
| ✅ | `90` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 6.21 V |
| ✅ | `82` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 6.23 V |
| ✅ | `62` | 234.2 | 238.0 | 1.018 | 1.035 | 1.7 % | 4.35 V |
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
  Line losses are 125.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 12.74 V at bus '896' — reflects the neutral shift under unbalanced loading.

