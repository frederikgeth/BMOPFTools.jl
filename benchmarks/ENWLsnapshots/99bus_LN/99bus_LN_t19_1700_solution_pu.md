# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -131764.6994  
**Solve time:** 0.044 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 45.231 kW |
| Total load | 34.488 kW |
| Total network losses (P) | 10.743 kW |
| Total network losses (Q) | 3.195 kW var |
| Loss fraction | 31.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 10.677 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.061 (`949`) | 3.4 % (`313`) | 10.68 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 237.6 | 243.9 | 1.033 | 1.061 | 2.8 % | 10.52 V |
| ✅ | `895` | 237.6 | 243.6 | 1.033 | 1.059 | 2.6 % | 10.29 V |
| ✅ | `896` | 237.1 | 243.6 | 1.031 | 1.059 | 2.9 % | 10.68 V |
| ✅ | `904` | 237.6 | 243.6 | 1.033 | 1.059 | 2.6 % | 10.23 V |
| ✅ | `775` | 237.7 | 243.5 | 1.033 | 1.059 | 2.5 % | 10.08 V |
| ✅ | `849` | 237.6 | 243.5 | 1.033 | 1.059 | 2.5 % | 10.13 V |
| ✅ | `894` | 237.6 | 243.5 | 1.033 | 1.059 | 2.5 % | 10.06 V |
| ✅ | `661` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 10.23 V |
| ✅ | `654` | 237.1 | 243.3 | 1.031 | 1.058 | 2.7 % | 10.15 V |
| ✅ | `644` | 237.1 | 243.2 | 1.031 | 1.058 | 2.7 % | 10.13 V |
| ✅ | `660` | 237.1 | 243.2 | 1.031 | 1.057 | 2.7 % | 10.29 V |
| ✅ | `635` | 237.1 | 243.2 | 1.031 | 1.057 | 2.7 % | 10.08 V |
| ✅ | `808` | 237.8 | 243.2 | 1.034 | 1.057 | 2.3 % | 10.07 V |
| ✅ | `693` | 237.7 | 243.2 | 1.034 | 1.057 | 2.4 % | 9.86 V |
| ✅ | `673` | 237.7 | 243.2 | 1.033 | 1.057 | 2.4 % | 9.86 V |
| ✅ | `677` | 237.1 | 243.1 | 1.031 | 1.057 | 2.6 % | 10.31 V |
| ✅ | `665` | 237.7 | 243.1 | 1.033 | 1.057 | 2.4 % | 9.82 V |
| ✅ | `779` | 237.8 | 243.1 | 1.034 | 1.057 | 2.3 % | 9.99 V |
| ✅ | `659` | 237.7 | 243.1 | 1.033 | 1.057 | 2.4 % | 9.77 V |
| ✅ | `627` | 237.1 | 243.0 | 1.031 | 1.056 | 2.6 % | 9.66 V |
| ✅ | `717` | 237.8 | 243.0 | 1.034 | 1.056 | 2.2 % | 10.18 V |
| ✅ | `617` | 237.1 | 243.0 | 1.031 | 1.056 | 2.5 % | 9.64 V |
| ✅ | `655` | 237.8 | 242.9 | 1.034 | 1.056 | 2.2 % | 9.98 V |
| ✅ | `609` | 237.8 | 242.9 | 1.034 | 1.056 | 2.2 % | 9.94 V |
| ✅ | `773` | 237.8 | 242.9 | 1.034 | 1.056 | 2.2 % | 9.86 V |
| ✅ | `618` | 237.1 | 242.9 | 1.031 | 1.056 | 2.5 % | 9.63 V |
| ✅ | `568` | 237.6 | 242.9 | 1.033 | 1.056 | 2.3 % | 9.62 V |
| ✅ | `608` | 237.1 | 242.9 | 1.031 | 1.056 | 2.5 % | 9.61 V |
| ✅ | `607` | 237.1 | 242.9 | 1.031 | 1.056 | 2.5 % | 9.58 V |
| ✅ | `600` | 237.1 | 242.8 | 1.031 | 1.056 | 2.5 % | 9.52 V |
| ✅ | `498` | 235.2 | 242.7 | 1.022 | 1.055 | 3.3 % | 2.36 V |
| ✅ | `313` | 234.8 | 242.7 | 1.021 | 1.055 | 3.4 % | 8.95 V |
| ✅ | `491` | 235.2 | 242.7 | 1.022 | 1.055 | 3.3 % | 2.33 V |
| ✅ | `303` | 234.8 | 242.6 | 1.021 | 1.055 | 3.4 % | 8.88 V |
| ✅ | `473` | 235.2 | 242.6 | 1.022 | 1.055 | 3.2 % | 2.3 V |
| ✅ | `290` | 234.8 | 242.6 | 1.021 | 1.055 | 3.4 % | 8.82 V |
| ✅ | `545` | 237.1 | 242.6 | 1.031 | 1.055 | 2.4 % | 9.17 V |
| ✅ | `472` | 235.2 | 242.6 | 1.022 | 1.055 | 3.2 % | 2.27 V |
| ✅ | `282` | 234.8 | 242.6 | 1.021 | 1.055 | 3.4 % | 8.78 V |
| ✅ | `272` | 234.8 | 242.5 | 1.021 | 1.054 | 3.3 % | 8.71 V |
| ✅ | `439` | 235.2 | 242.5 | 1.022 | 1.054 | 3.2 % | 2.24 V |
| ✅ | `536` | 235.2 | 242.4 | 1.022 | 1.054 | 3.2 % | 2.23 V |
| ✅ | `427` | 235.2 | 242.4 | 1.022 | 1.054 | 3.1 % | 2.2 V |
| ✅ | `321` | 234.8 | 242.3 | 1.021 | 1.053 | 3.2 % | 8.45 V |
| ✅ | `264` | 234.8 | 242.2 | 1.021 | 1.053 | 3.2 % | 8.37 V |
| ✅ | `479` | 235.2 | 242.2 | 1.022 | 1.053 | 3.1 % | 2.16 V |
| ✅ | `377` | 235.2 | 242.1 | 1.022 | 1.053 | 3.0 % | 2.15 V |
| ✅ | `376` | 235.2 | 242.1 | 1.022 | 1.053 | 3.0 % | 2.14 V |
| ✅ | `263` | 234.9 | 242.0 | 1.021 | 1.052 | 3.1 % | 8.13 V |
| ✅ | `354` | 235.2 | 242.0 | 1.022 | 1.052 | 3.0 % | 2.14 V |
| ✅ | `254` | 234.9 | 242.0 | 1.021 | 1.052 | 3.1 % | 8.07 V |
| ✅ | `229` | 234.9 | 241.8 | 1.021 | 1.051 | 3.0 % | 7.78 V |
| ✅ | `521` | 235.2 | 241.8 | 1.022 | 1.051 | 2.9 % | 2.13 V |
| ✅ | `216` | 234.9 | 241.7 | 1.021 | 1.051 | 3.0 % | 7.72 V |
| ✅ | `307` | 235.2 | 241.7 | 1.022 | 1.051 | 2.8 % | 2.14 V |
| ✅ | `192` | 234.9 | 241.5 | 1.021 | 1.05 | 2.9 % | 7.42 V |
| ✅ | `175` | 234.9 | 241.5 | 1.021 | 1.05 | 2.8 % | 7.37 V |
| ✅ | `256` | 235.2 | 241.3 | 1.022 | 1.049 | 2.7 % | 2.21 V |
| ✅ | `530` | 236.4 | 241.3 | 1.028 | 1.049 | 2.1 % | 7.36 V |
| ✅ | `247` | 235.2 | 241.3 | 1.022 | 1.049 | 2.7 % | 2.24 V |
| ✅ | `166` | 235.0 | 241.1 | 1.022 | 1.048 | 2.7 % | 6.82 V |
| ✅ | `151` | 235.0 | 240.8 | 1.022 | 1.047 | 2.5 % | 6.57 V |
| ✅ | `145` | 235.0 | 240.8 | 1.022 | 1.047 | 2.5 % | 6.5 V |
| ✅ | `226` | 235.2 | 240.8 | 1.022 | 1.047 | 2.5 % | 2.46 V |
| ✅ | `220` | 235.2 | 240.7 | 1.022 | 1.047 | 2.4 % | 2.5 V |
| ✅ | `138` | 235.0 | 240.7 | 1.022 | 1.047 | 2.5 % | 6.41 V |
| ✅ | `144` | 235.0 | 240.7 | 1.022 | 1.046 | 2.5 % | 6.35 V |
| ✅ | `131` | 235.0 | 240.6 | 1.022 | 1.046 | 2.4 % | 6.31 V |
| ✅ | `428` | 236.8 | 240.6 | 1.03 | 1.046 | 1.6 % | 6.56 V |
| ✅ | `416` | 236.8 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.52 V |
| ✅ | `391` | 236.7 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.49 V |
| ✅ | `392` | 236.7 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.49 V |
| ✅ | `380` | 236.7 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.48 V |
| ✅ | `366` | 236.6 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.45 V |
| ✅ | `355` | 236.6 | 240.6 | 1.029 | 1.046 | 1.7 % | 6.43 V |
| ✅ | `441` | 236.4 | 240.6 | 1.028 | 1.046 | 1.8 % | 6.37 V |
| ✅ | `327` | 236.3 | 240.6 | 1.027 | 1.046 | 1.9 % | 6.31 V |
| ✅ | `348` | 236.5 | 240.6 | 1.028 | 1.046 | 1.8 % | 6.38 V |
| ✅ | `384` | 236.2 | 240.6 | 1.027 | 1.046 | 1.9 % | 6.29 V |
| ✅ | `318` | 236.2 | 240.6 | 1.027 | 1.046 | 1.9 % | 6.28 V |
| ✅ | `300` | 236.1 | 240.6 | 1.027 | 1.046 | 1.9 % | 6.24 V |
| ✅ | `128` | 235.1 | 240.2 | 1.022 | 1.044 | 2.2 % | 5.5 V |
| ✅ | `219` | 235.2 | 240.2 | 1.022 | 1.044 | 2.2 % | 2.88 V |
| ✅ | `116` | 235.1 | 240.1 | 1.022 | 1.044 | 2.2 % | 5.59 V |
| ✅ | `208` | 235.2 | 240.1 | 1.022 | 1.044 | 2.1 % | 2.93 V |
| ✅ | `198` | 235.1 | 240.0 | 1.022 | 1.043 | 2.1 % | 5.39 V |
| ✅ | `104` | 235.1 | 240.0 | 1.022 | 1.043 | 2.1 % | 5.41 V |
| ✅ | `108` | 235.1 | 239.9 | 1.022 | 1.043 | 2.1 % | 5.26 V |
| ✅ | `99` | 235.1 | 239.8 | 1.022 | 1.043 | 2.0 % | 5.22 V |
| ✅ | `201` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 3.67 V |
| ✅ | `188` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 3.75 V |
| ✅ | `179` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 4.4 V |
| ✅ | `162` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 4.46 V |
| ✅ | `187` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 4.76 V |
| ✅ | `147` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 4.8 V |
| ✅ | `90` | 235.2 | 239.8 | 1.022 | 1.042 | 2.0 % | 5.11 V |
| ✅ | `82` | 235.1 | 239.7 | 1.022 | 1.042 | 2.0 % | 5.13 V |
| ✅ | `62` | 233.8 | 236.8 | 1.017 | 1.029 | 1.3 % | 3.56 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.348 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=3.404 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.431 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=3.903 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=3.945 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=3.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=3.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=3.993 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=3.509 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.973 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=3.58 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.06 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=3.838 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=3.534 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.692 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=3.902 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=3.543 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.663 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=3.492 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=3.695 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.513 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.466 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=3.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=3.678 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.082 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=3.803 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=3.443 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.779 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=3.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=3.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=3.582 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=3.401 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.379 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.364 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.381 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.008 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.383 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=3.381 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 31.2 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 10.68 V at bus '896' — reflects the neutral shift under unbalanced loading.

