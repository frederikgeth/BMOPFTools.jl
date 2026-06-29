# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -77339.2784  
**Solve time:** 0.067 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 47.898 kW |
| Total load | 44.43 kW |
| Total network losses (P) | 3.468 kW |
| Total network losses (Q) | 1.093 kW var |
| Loss fraction | 7.8% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.608 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.038 (`949`) | 2.7 % (`894`) | 6.61 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 233.2 | 238.9 | 1.014 | 1.038 | 2.5 % | 5.87 V |
| ✅ | `895` | 233.2 | 238.6 | 1.014 | 1.038 | 2.4 % | 5.73 V |
| ✅ | `904` | 233.2 | 238.6 | 1.014 | 1.037 | 2.3 % | 5.7 V |
| ✅ | `775` | 233.4 | 238.5 | 1.015 | 1.037 | 2.2 % | 5.41 V |
| ✅ | `894` | 232.3 | 238.5 | 1.01 | 1.037 | 2.7 % | 6.61 V |
| ✅ | `849` | 233.2 | 238.5 | 1.014 | 1.037 | 2.3 % | 5.64 V |
| ✅ | `808` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 5.27 V |
| ✅ | `693` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 5.27 V |
| ✅ | `673` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 5.27 V |
| ✅ | `665` | 233.4 | 238.3 | 1.015 | 1.036 | 2.1 % | 5.25 V |
| ✅ | `779` | 233.5 | 238.2 | 1.015 | 1.036 | 2.1 % | 5.38 V |
| ✅ | `659` | 233.5 | 238.2 | 1.015 | 1.036 | 2.1 % | 5.21 V |
| ✅ | `313` | 233.5 | 238.2 | 1.015 | 1.036 | 2.0 % | 4.7 V |
| ✅ | `896` | 233.7 | 238.2 | 1.016 | 1.036 | 2.0 % | 5.21 V |
| ✅ | `303` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 4.65 V |
| ✅ | `717` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.5 V |
| ✅ | `655` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.35 V |
| ✅ | `609` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.32 V |
| ✅ | `773` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.22 V |
| ✅ | `568` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 5.06 V |
| ✅ | `290` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 4.61 V |
| ✅ | `282` | 233.5 | 238.1 | 1.015 | 1.035 | 2.0 % | 4.58 V |
| ✅ | `661` | 233.6 | 238.1 | 1.016 | 1.035 | 1.9 % | 5.04 V |
| ✅ | `654` | 233.6 | 238.0 | 1.016 | 1.035 | 1.9 % | 5.01 V |
| ✅ | `272` | 233.5 | 238.0 | 1.015 | 1.035 | 2.0 % | 4.55 V |
| ✅ | `617` | 233.6 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.85 V |
| ✅ | `627` | 233.6 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.86 V |
| ✅ | `635` | 233.7 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.97 V |
| ✅ | `618` | 233.6 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.84 V |
| ✅ | `608` | 233.6 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.84 V |
| ✅ | `644` | 233.7 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.99 V |
| ✅ | `607` | 233.7 | 238.0 | 1.016 | 1.035 | 1.9 % | 4.81 V |
| ✅ | `600` | 233.7 | 237.9 | 1.016 | 1.035 | 1.9 % | 4.79 V |
| ✅ | `321` | 233.6 | 237.9 | 1.015 | 1.034 | 1.9 % | 4.4 V |
| ✅ | `660` | 233.7 | 237.9 | 1.016 | 1.034 | 1.8 % | 5.0 V |
| ✅ | `264` | 233.6 | 237.9 | 1.015 | 1.034 | 1.9 % | 4.35 V |
| ✅ | `545` | 233.7 | 237.8 | 1.016 | 1.034 | 1.8 % | 4.65 V |
| ✅ | `677` | 233.7 | 237.7 | 1.016 | 1.034 | 1.8 % | 4.96 V |
| ✅ | `263` | 233.6 | 237.7 | 1.016 | 1.033 | 1.8 % | 4.2 V |
| ✅ | `254` | 233.6 | 237.7 | 1.016 | 1.033 | 1.8 % | 4.17 V |
| ✅ | `229` | 233.6 | 237.5 | 1.016 | 1.033 | 1.7 % | 4.02 V |
| ✅ | `498` | 233.7 | 237.5 | 1.016 | 1.033 | 1.6 % | 2.86 V |
| ✅ | `216` | 233.6 | 237.5 | 1.016 | 1.033 | 1.7 % | 3.97 V |
| ✅ | `491` | 233.7 | 237.5 | 1.016 | 1.033 | 1.6 % | 2.84 V |
| ✅ | `473` | 233.7 | 237.4 | 1.016 | 1.032 | 1.6 % | 2.8 V |
| ✅ | `472` | 233.7 | 237.4 | 1.016 | 1.032 | 1.6 % | 2.77 V |
| ✅ | `439` | 233.7 | 237.3 | 1.016 | 1.032 | 1.6 % | 2.73 V |
| ✅ | `192` | 233.6 | 237.3 | 1.016 | 1.032 | 1.6 % | 3.78 V |
| ✅ | `536` | 233.7 | 237.3 | 1.016 | 1.032 | 1.5 % | 2.7 V |
| ✅ | `175` | 233.6 | 237.3 | 1.016 | 1.032 | 1.6 % | 3.77 V |
| ✅ | `427` | 233.7 | 237.2 | 1.016 | 1.031 | 1.5 % | 2.66 V |
| ✅ | `479` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.59 V |
| ✅ | `530` | 233.9 | 237.1 | 1.017 | 1.031 | 1.4 % | 3.55 V |
| ✅ | `377` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.56 V |
| ✅ | `166` | 233.6 | 237.1 | 1.016 | 1.031 | 1.5 % | 3.52 V |
| ✅ | `376` | 233.7 | 237.1 | 1.016 | 1.031 | 1.5 % | 2.54 V |
| ✅ | `354` | 233.7 | 237.0 | 1.016 | 1.031 | 1.4 % | 2.51 V |
| ✅ | `151` | 233.6 | 236.9 | 1.016 | 1.03 | 1.4 % | 3.33 V |
| ✅ | `145` | 233.6 | 236.8 | 1.016 | 1.03 | 1.4 % | 3.29 V |
| ✅ | `521` | 233.7 | 236.8 | 1.016 | 1.03 | 1.3 % | 2.39 V |
| ✅ | `138` | 233.7 | 236.8 | 1.016 | 1.03 | 1.4 % | 3.23 V |
| ✅ | `307` | 233.7 | 236.8 | 1.016 | 1.029 | 1.3 % | 2.35 V |
| ✅ | `131` | 233.7 | 236.7 | 1.016 | 1.029 | 1.3 % | 3.18 V |
| ✅ | `144` | 233.7 | 236.7 | 1.016 | 1.029 | 1.3 % | 3.18 V |
| ✅ | `428` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.94 V |
| ✅ | `380` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.93 V |
| ✅ | `392` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.93 V |
| ✅ | `416` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.91 V |
| ✅ | `391` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.92 V |
| ✅ | `366` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.91 V |
| ✅ | `355` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.91 V |
| ✅ | `441` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.91 V |
| ✅ | `327` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.9 V |
| ✅ | `348` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.88 V |
| ✅ | `384` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.89 V |
| ✅ | `318` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.89 V |
| ✅ | `300` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 2.89 V |
| ✅ | `256` | 233.7 | 236.6 | 1.016 | 1.029 | 1.2 % | 2.24 V |
| ✅ | `247` | 233.7 | 236.5 | 1.016 | 1.028 | 1.2 % | 2.22 V |
| ✅ | `128` | 233.7 | 236.5 | 1.016 | 1.028 | 1.2 % | 2.82 V |
| ✅ | `116` | 233.7 | 236.4 | 1.016 | 1.028 | 1.2 % | 2.77 V |
| ✅ | `198` | 233.7 | 236.3 | 1.016 | 1.027 | 1.1 % | 2.7 V |
| ✅ | `104` | 233.7 | 236.3 | 1.016 | 1.027 | 1.1 % | 2.69 V |
| ✅ | `108` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.62 V |
| ✅ | `99` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.59 V |
| ✅ | `226` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.09 V |
| ✅ | `220` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.08 V |
| ✅ | `219` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.01 V |
| ✅ | `208` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.0 V |
| ✅ | `201` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.07 V |
| ✅ | `188` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.08 V |
| ✅ | `179` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.28 V |
| ✅ | `162` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.29 V |
| ✅ | `187` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.45 V |
| ✅ | `147` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.42 V |
| ✅ | `90` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.52 V |
| ✅ | `82` | 233.7 | 236.2 | 1.016 | 1.027 | 1.1 % | 2.53 V |
| ✅ | `62` | 232.7 | 234.2 | 1.012 | 1.018 | 0.7 % | 1.71 V |
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
  Maximum neutral terminal voltage: 6.61 V at bus '894' — reflects the neutral shift under unbalanced loading.

