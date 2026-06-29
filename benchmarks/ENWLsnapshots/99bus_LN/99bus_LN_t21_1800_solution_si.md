# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:28  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -77236.6521  
**Solve time:** 0.184 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 48.001 kW |
| Total load | 44.43 kW |
| Total network losses (P) | 3.57 kW |
| Total network losses (Q) | 1.103 kW var |
| Loss fraction | 8.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.004 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.037 (`949`) | 2.6 % (`894`) | 7.0 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 233.3 | 238.6 | 1.014 | 1.037 | 2.3 % | 6.31 V |
| ✅ | `895` | 233.3 | 238.4 | 1.014 | 1.037 | 2.2 % | 6.17 V |
| ✅ | `904` | 233.3 | 238.3 | 1.014 | 1.036 | 2.2 % | 6.14 V |
| ✅ | `775` | 233.5 | 238.3 | 1.015 | 1.036 | 2.1 % | 5.85 V |
| ✅ | `894` | 232.3 | 238.3 | 1.01 | 1.036 | 2.6 % | 7.0 V |
| ✅ | `849` | 233.3 | 238.3 | 1.014 | 1.036 | 2.2 % | 6.08 V |
| ✅ | `808` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.73 V |
| ✅ | `693` | 233.5 | 238.0 | 1.015 | 1.035 | 2.0 % | 5.71 V |
| ✅ | `673` | 233.5 | 238.0 | 1.015 | 1.035 | 2.0 % | 5.71 V |
| ✅ | `665` | 233.5 | 238.0 | 1.015 | 1.035 | 2.0 % | 5.69 V |
| ✅ | `779` | 233.5 | 238.0 | 1.015 | 1.035 | 1.9 % | 5.84 V |
| ✅ | `659` | 233.5 | 238.0 | 1.015 | 1.035 | 1.9 % | 5.65 V |
| ✅ | `313` | 233.5 | 237.9 | 1.015 | 1.035 | 1.9 % | 4.85 V |
| ✅ | `896` | 233.7 | 237.9 | 1.016 | 1.035 | 1.8 % | 5.65 V |
| ✅ | `303` | 233.5 | 237.9 | 1.015 | 1.034 | 1.9 % | 4.81 V |
| ✅ | `717` | 233.6 | 237.9 | 1.016 | 1.034 | 1.9 % | 5.97 V |
| ✅ | `655` | 233.6 | 237.9 | 1.016 | 1.034 | 1.9 % | 5.82 V |
| ✅ | `609` | 233.6 | 237.9 | 1.016 | 1.034 | 1.9 % | 5.78 V |
| ✅ | `773` | 233.6 | 237.9 | 1.016 | 1.034 | 1.9 % | 5.69 V |
| ✅ | `568` | 233.6 | 237.9 | 1.016 | 1.034 | 1.9 % | 5.5 V |
| ✅ | `290` | 233.5 | 237.9 | 1.015 | 1.034 | 1.9 % | 4.77 V |
| ✅ | `282` | 233.5 | 237.8 | 1.015 | 1.034 | 1.9 % | 4.74 V |
| ✅ | `661` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.47 V |
| ✅ | `654` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.44 V |
| ✅ | `272` | 233.5 | 237.8 | 1.015 | 1.034 | 1.9 % | 4.7 V |
| ✅ | `617` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.27 V |
| ✅ | `627` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.27 V |
| ✅ | `618` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.26 V |
| ✅ | `608` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.25 V |
| ✅ | `635` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.41 V |
| ✅ | `644` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 5.42 V |
| ✅ | `607` | 233.7 | 237.7 | 1.016 | 1.034 | 1.8 % | 5.23 V |
| ✅ | `600` | 233.7 | 237.7 | 1.016 | 1.034 | 1.7 % | 5.21 V |
| ✅ | `321` | 233.5 | 237.7 | 1.015 | 1.033 | 1.8 % | 4.55 V |
| ✅ | `264` | 233.5 | 237.6 | 1.015 | 1.033 | 1.8 % | 4.5 V |
| ✅ | `660` | 233.7 | 237.6 | 1.016 | 1.033 | 1.7 % | 5.46 V |
| ✅ | `545` | 233.7 | 237.6 | 1.016 | 1.033 | 1.7 % | 5.06 V |
| ✅ | `498` | 233.7 | 237.6 | 1.016 | 1.033 | 1.7 % | 2.34 V |
| ✅ | `491` | 233.7 | 237.5 | 1.016 | 1.033 | 1.7 % | 2.32 V |
| ✅ | `473` | 233.7 | 237.5 | 1.016 | 1.033 | 1.7 % | 2.28 V |
| ✅ | `263` | 233.5 | 237.5 | 1.015 | 1.032 | 1.7 % | 4.35 V |
| ✅ | `677` | 233.7 | 237.5 | 1.016 | 1.032 | 1.6 % | 5.43 V |
| ✅ | `254` | 233.5 | 237.5 | 1.015 | 1.032 | 1.7 % | 4.32 V |
| ✅ | `472` | 233.7 | 237.4 | 1.016 | 1.032 | 1.6 % | 2.25 V |
| ✅ | `439` | 233.7 | 237.4 | 1.016 | 1.032 | 1.6 % | 2.21 V |
| ✅ | `536` | 233.7 | 237.3 | 1.016 | 1.032 | 1.6 % | 2.19 V |
| ✅ | `229` | 233.5 | 237.3 | 1.015 | 1.032 | 1.6 % | 4.16 V |
| ✅ | `427` | 233.7 | 237.3 | 1.016 | 1.032 | 1.6 % | 2.15 V |
| ✅ | `216` | 233.5 | 237.3 | 1.015 | 1.032 | 1.6 % | 4.12 V |
| ✅ | `479` | 233.7 | 237.2 | 1.016 | 1.031 | 1.5 % | 2.09 V |
| ✅ | `377` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.06 V |
| ✅ | `376` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.04 V |
| ✅ | `192` | 233.5 | 237.1 | 1.015 | 1.031 | 1.5 % | 3.93 V |
| ✅ | `175` | 233.5 | 237.1 | 1.015 | 1.031 | 1.5 % | 3.91 V |
| ✅ | `354` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.01 V |
| ✅ | `530` | 233.9 | 236.9 | 1.017 | 1.03 | 1.3 % | 3.9 V |
| ✅ | `166` | 233.6 | 236.9 | 1.016 | 1.03 | 1.4 % | 3.64 V |
| ✅ | `521` | 233.7 | 236.9 | 1.016 | 1.03 | 1.4 % | 1.91 V |
| ✅ | `307` | 233.7 | 236.8 | 1.016 | 1.03 | 1.4 % | 1.89 V |
| ✅ | `151` | 233.6 | 236.7 | 1.016 | 1.029 | 1.4 % | 3.46 V |
| ✅ | `145` | 233.6 | 236.7 | 1.016 | 1.029 | 1.3 % | 3.42 V |
| ✅ | `256` | 233.7 | 236.6 | 1.016 | 1.029 | 1.3 % | 1.8 V |
| ✅ | `138` | 233.6 | 236.6 | 1.016 | 1.029 | 1.3 % | 3.37 V |
| ✅ | `247` | 233.7 | 236.6 | 1.016 | 1.028 | 1.3 % | 1.79 V |
| ✅ | `131` | 233.6 | 236.5 | 1.016 | 1.028 | 1.3 % | 3.31 V |
| ✅ | `144` | 233.6 | 236.5 | 1.016 | 1.028 | 1.3 % | 3.32 V |
| ✅ | `428` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.3 V |
| ✅ | `380` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.28 V |
| ✅ | `392` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.28 V |
| ✅ | `416` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.26 V |
| ✅ | `391` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.26 V |
| ✅ | `366` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.26 V |
| ✅ | `355` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.25 V |
| ✅ | `441` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.23 V |
| ✅ | `327` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.21 V |
| ✅ | `348` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.2 V |
| ✅ | `384` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.19 V |
| ✅ | `318` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.19 V |
| ✅ | `300` | 234.1 | 236.5 | 1.018 | 1.028 | 1.0 % | 3.18 V |
| ✅ | `128` | 233.6 | 236.3 | 1.016 | 1.027 | 1.2 % | 2.92 V |
| ✅ | `226` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 1.72 V |
| ✅ | `220` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 1.72 V |
| ✅ | `116` | 233.6 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.9 V |
| ✅ | `198` | 233.6 | 236.1 | 1.016 | 1.027 | 1.1 % | 2.81 V |
| ✅ | `104` | 233.6 | 236.1 | 1.016 | 1.027 | 1.1 % | 2.81 V |
| ✅ | `108` | 233.6 | 236.1 | 1.016 | 1.026 | 1.1 % | 2.74 V |
| ✅ | `99` | 233.6 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.71 V |
| ✅ | `219` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 1.73 V |
| ✅ | `208` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 1.74 V |
| ✅ | `201` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 1.97 V |
| ✅ | `188` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.0 V |
| ✅ | `179` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.31 V |
| ✅ | `162` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.33 V |
| ✅ | `187` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.52 V |
| ✅ | `147` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.5 V |
| ✅ | `90` | 233.7 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.64 V |
| ✅ | `82` | 233.6 | 236.0 | 1.016 | 1.026 | 1.0 % | 2.65 V |
| ✅ | `62` | 232.7 | 234.1 | 1.012 | 1.018 | 0.6 % | 1.81 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=2.533 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=2.469 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=2.499 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.61 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=2.711 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.49 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.809 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=2.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=2.789 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=2.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=2.484 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=2.59 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=2.753 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=2.39 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.451 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=2.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=2.759 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=2.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=2.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.722 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=2.871 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=2.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=2.391 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=2.613 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.631 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=2.367 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=2.531 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=2.796 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.672 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=2.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=2.714 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=2.718 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=2.561 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=2.379 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=2.766 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=2.759 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=2.8 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.426 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=2.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=2.407 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 7.0 V at bus '894' — reflects the neutral shift under unbalanced loading.

