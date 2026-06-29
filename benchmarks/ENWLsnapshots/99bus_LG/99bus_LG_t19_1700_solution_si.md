# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -132552.0156  
**Solve time:** 0.068 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 44.443 kW |
| Total load | 34.488 kW |
| Total network losses (P) | 9.956 kW |
| Total network losses (Q) | 2.989 kW var |
| Loss fraction | 28.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 10.629 V (bus `949`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.065 (`949`) | 3.6 % (`313`) | 10.63 V (`949`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 237.3 | 245.0 | 1.032 | 1.065 | 3.4 % | 10.63 V |
| ✅ | `895` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 10.36 V |
| ✅ | `896` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 10.52 V |
| ✅ | `904` | 237.3 | 244.6 | 1.032 | 1.064 | 3.2 % | 10.3 V |
| ✅ | `849` | 237.3 | 244.5 | 1.032 | 1.063 | 3.1 % | 10.2 V |
| ✅ | `894` | 237.3 | 244.5 | 1.032 | 1.063 | 3.2 % | 10.25 V |
| ✅ | `775` | 237.3 | 244.5 | 1.032 | 1.063 | 3.1 % | 10.14 V |
| ✅ | `661` | 237.3 | 244.4 | 1.032 | 1.063 | 3.1 % | 10.11 V |
| ✅ | `654` | 237.3 | 244.3 | 1.032 | 1.062 | 3.0 % | 10.04 V |
| ✅ | `644` | 237.3 | 244.3 | 1.032 | 1.062 | 3.0 % | 10.01 V |
| ✅ | `660` | 237.3 | 244.3 | 1.032 | 1.062 | 3.0 % | 10.12 V |
| ✅ | `635` | 237.3 | 244.3 | 1.032 | 1.062 | 3.0 % | 9.97 V |
| ✅ | `808` | 237.4 | 244.2 | 1.032 | 1.062 | 3.0 % | 10.07 V |
| ✅ | `693` | 237.3 | 244.2 | 1.032 | 1.062 | 3.0 % | 9.88 V |
| ✅ | `673` | 237.3 | 244.2 | 1.032 | 1.062 | 3.0 % | 9.87 V |
| ✅ | `677` | 237.3 | 244.2 | 1.032 | 1.062 | 3.0 % | 10.11 V |
| ✅ | `665` | 237.3 | 244.2 | 1.032 | 1.062 | 3.0 % | 9.83 V |
| ✅ | `779` | 237.4 | 244.1 | 1.032 | 1.061 | 2.9 % | 9.98 V |
| ✅ | `659` | 237.3 | 244.1 | 1.032 | 1.061 | 2.9 % | 9.78 V |
| ✅ | `627` | 237.3 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.59 V |
| ✅ | `717` | 237.4 | 244.0 | 1.032 | 1.061 | 2.9 % | 10.15 V |
| ✅ | `655` | 237.4 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.95 V |
| ✅ | `609` | 237.4 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.92 V |
| ✅ | `617` | 237.3 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.57 V |
| ✅ | `773` | 237.4 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.83 V |
| ✅ | `568` | 237.3 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.61 V |
| ✅ | `618` | 237.3 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.56 V |
| ✅ | `608` | 237.3 | 244.0 | 1.032 | 1.061 | 2.9 % | 9.55 V |
| ✅ | `607` | 237.3 | 243.9 | 1.032 | 1.061 | 2.9 % | 9.51 V |
| ✅ | `600` | 237.3 | 243.9 | 1.032 | 1.06 | 2.8 % | 9.45 V |
| ✅ | `313` | 235.4 | 243.7 | 1.024 | 1.06 | 3.6 % | 9.09 V |
| ✅ | `303` | 235.4 | 243.7 | 1.024 | 1.059 | 3.6 % | 9.02 V |
| ✅ | `290` | 235.4 | 243.6 | 1.024 | 1.059 | 3.6 % | 8.96 V |
| ✅ | `545` | 237.3 | 243.6 | 1.032 | 1.059 | 2.7 % | 9.12 V |
| ✅ | `282` | 235.4 | 243.6 | 1.024 | 1.059 | 3.5 % | 8.92 V |
| ✅ | `272` | 235.4 | 243.5 | 1.024 | 1.059 | 3.5 % | 8.86 V |
| ✅ | `321` | 235.5 | 243.3 | 1.024 | 1.058 | 3.4 % | 8.61 V |
| ✅ | `264` | 235.5 | 243.2 | 1.024 | 1.058 | 3.4 % | 8.54 V |
| ✅ | `263` | 235.5 | 243.0 | 1.024 | 1.057 | 3.3 % | 8.31 V |
| ✅ | `254` | 235.5 | 243.0 | 1.024 | 1.056 | 3.3 % | 8.26 V |
| ✅ | `229` | 235.5 | 242.7 | 1.024 | 1.055 | 3.1 % | 7.99 V |
| ✅ | `216` | 235.5 | 242.7 | 1.024 | 1.055 | 3.1 % | 7.93 V |
| ✅ | `192` | 235.5 | 242.4 | 1.024 | 1.054 | 3.0 % | 7.64 V |
| ✅ | `498` | 235.8 | 242.4 | 1.025 | 1.054 | 2.9 % | 4.8 V |
| ✅ | `175` | 235.5 | 242.4 | 1.024 | 1.054 | 3.0 % | 7.6 V |
| ✅ | `491` | 235.8 | 242.3 | 1.025 | 1.054 | 2.9 % | 4.77 V |
| ✅ | `473` | 235.8 | 242.3 | 1.025 | 1.053 | 2.8 % | 4.74 V |
| ✅ | `530` | 237.2 | 242.2 | 1.032 | 1.053 | 2.2 % | 7.3 V |
| ✅ | `472` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 4.71 V |
| ✅ | `439` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 4.67 V |
| ✅ | `536` | 235.8 | 242.1 | 1.025 | 1.053 | 2.8 % | 4.65 V |
| ✅ | `427` | 235.8 | 242.0 | 1.025 | 1.052 | 2.7 % | 4.61 V |
| ✅ | `166` | 235.6 | 242.0 | 1.024 | 1.052 | 2.8 % | 7.11 V |
| ✅ | `479` | 235.8 | 241.9 | 1.025 | 1.052 | 2.7 % | 4.55 V |
| ✅ | `377` | 235.8 | 241.8 | 1.025 | 1.051 | 2.6 % | 4.52 V |
| ✅ | `376` | 235.8 | 241.8 | 1.025 | 1.051 | 2.6 % | 4.51 V |
| ✅ | `151` | 235.6 | 241.7 | 1.024 | 1.051 | 2.7 % | 6.85 V |
| ✅ | `354` | 235.8 | 241.7 | 1.025 | 1.051 | 2.6 % | 4.48 V |
| ✅ | `145` | 235.6 | 241.7 | 1.024 | 1.051 | 2.6 % | 6.79 V |
| ✅ | `138` | 235.6 | 241.6 | 1.024 | 1.05 | 2.6 % | 6.7 V |
| ✅ | `144` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 6.64 V |
| ✅ | `131` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 6.61 V |
| ✅ | `428` | 237.5 | 241.5 | 1.033 | 1.05 | 1.7 % | 6.33 V |
| ✅ | `416` | 237.5 | 241.5 | 1.033 | 1.05 | 1.7 % | 6.31 V |
| ✅ | `391` | 237.5 | 241.5 | 1.032 | 1.05 | 1.8 % | 6.3 V |
| ✅ | `392` | 237.4 | 241.5 | 1.032 | 1.05 | 1.8 % | 6.3 V |
| ✅ | `380` | 237.4 | 241.5 | 1.032 | 1.05 | 1.8 % | 6.3 V |
| ✅ | `366` | 237.4 | 241.5 | 1.032 | 1.05 | 1.8 % | 6.29 V |
| ✅ | `355` | 237.3 | 241.5 | 1.032 | 1.05 | 1.8 % | 6.28 V |
| ✅ | `441` | 237.2 | 241.5 | 1.031 | 1.05 | 1.9 % | 6.26 V |
| ✅ | `327` | 237.1 | 241.5 | 1.031 | 1.05 | 1.9 % | 6.24 V |
| ✅ | `348` | 237.2 | 241.5 | 1.031 | 1.05 | 1.9 % | 6.26 V |
| ✅ | `384` | 237.0 | 241.5 | 1.03 | 1.05 | 1.9 % | 6.23 V |
| ✅ | `318` | 237.0 | 241.5 | 1.03 | 1.05 | 2.0 % | 6.23 V |
| ✅ | `300` | 236.9 | 241.4 | 1.03 | 1.05 | 2.0 % | 6.23 V |
| ✅ | `521` | 235.8 | 241.4 | 1.025 | 1.05 | 2.5 % | 4.39 V |
| ✅ | `307` | 235.8 | 241.3 | 1.025 | 1.049 | 2.4 % | 4.37 V |
| ✅ | `256` | 235.8 | 241.0 | 1.025 | 1.048 | 2.3 % | 4.3 V |
| ✅ | `128` | 235.7 | 241.0 | 1.025 | 1.048 | 2.3 % | 5.91 V |
| ✅ | `116` | 235.7 | 240.9 | 1.025 | 1.048 | 2.3 % | 5.94 V |
| ✅ | `247` | 235.8 | 240.9 | 1.025 | 1.048 | 2.2 % | 4.3 V |
| ✅ | `198` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 5.76 V |
| ✅ | `104` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 5.76 V |
| ✅ | `108` | 235.7 | 240.7 | 1.025 | 1.046 | 2.2 % | 5.63 V |
| ✅ | `99` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.58 V |
| ✅ | `226` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.27 V |
| ✅ | `220` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.27 V |
| ✅ | `219` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.33 V |
| ✅ | `208` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.35 V |
| ✅ | `201` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.64 V |
| ✅ | `188` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 4.68 V |
| ✅ | `179` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.05 V |
| ✅ | `162` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.09 V |
| ✅ | `187` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.29 V |
| ✅ | `147` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.3 V |
| ✅ | `90` | 235.8 | 240.6 | 1.025 | 1.046 | 2.1 % | 5.47 V |
| ✅ | `82` | 235.7 | 240.5 | 1.025 | 1.046 | 2.1 % | 5.48 V |
| ✅ | `62` | 234.2 | 237.3 | 1.018 | 1.032 | 1.3 % | 3.73 V |
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
  Line losses are 28.9 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 10.63 V at bus '949' — reflects the neutral shift under unbalanced loading.

