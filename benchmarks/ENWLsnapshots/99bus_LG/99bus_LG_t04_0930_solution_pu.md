# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:15  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -74772.862  
**Solve time:** 0.043 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.506 kW |
| Total load | 18.634 kW |
| Total network losses (P) | 2.872 kW |
| Total network losses (Q) | 925.05 W var |
| Loss fraction | 15.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.717 V (bus `949`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.04 (`949`) | 2.3 % (`949`) | 4.72 V (`949`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 234.0 | 239.3 | 1.017 | 1.04 | 2.3 % | 4.72 V |
| ✅ | `895` | 234.0 | 239.1 | 1.017 | 1.04 | 2.2 % | 4.59 V |
| ✅ | `904` | 234.0 | 239.1 | 1.017 | 1.039 | 2.2 % | 4.54 V |
| ✅ | `896` | 234.0 | 239.1 | 1.018 | 1.039 | 2.2 % | 4.59 V |
| ✅ | `849` | 234.0 | 239.0 | 1.017 | 1.039 | 2.2 % | 4.48 V |
| ✅ | `894` | 233.9 | 239.0 | 1.017 | 1.039 | 2.2 % | 4.62 V |
| ✅ | `775` | 234.0 | 239.0 | 1.017 | 1.039 | 2.2 % | 4.43 V |
| ✅ | `661` | 234.0 | 238.9 | 1.018 | 1.039 | 2.1 % | 4.41 V |
| ✅ | `654` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.38 V |
| ✅ | `808` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.27 V |
| ✅ | `693` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.27 V |
| ✅ | `673` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.27 V |
| ✅ | `644` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.35 V |
| ✅ | `635` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.34 V |
| ✅ | `660` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.37 V |
| ✅ | `665` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.25 V |
| ✅ | `779` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.27 V |
| ✅ | `659` | 234.0 | 238.8 | 1.018 | 1.038 | 2.1 % | 4.22 V |
| ✅ | `677` | 234.0 | 238.8 | 1.018 | 1.038 | 2.0 % | 4.34 V |
| ✅ | `627` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.2 V |
| ✅ | `655` | 234.1 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.21 V |
| ✅ | `717` | 234.1 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.27 V |
| ✅ | `609` | 234.1 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.21 V |
| ✅ | `773` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.18 V |
| ✅ | `617` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.19 V |
| ✅ | `568` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.14 V |
| ✅ | `618` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.18 V |
| ✅ | `608` | 234.0 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.18 V |
| ✅ | `607` | 234.0 | 238.6 | 1.018 | 1.038 | 2.0 % | 4.15 V |
| ✅ | `600` | 234.0 | 238.6 | 1.018 | 1.037 | 2.0 % | 4.12 V |
| ✅ | `545` | 234.0 | 238.4 | 1.018 | 1.037 | 1.9 % | 3.95 V |
| ✅ | `313` | 233.2 | 238.2 | 1.014 | 1.036 | 2.2 % | 4.51 V |
| ✅ | `303` | 233.2 | 238.2 | 1.014 | 1.036 | 2.2 % | 4.49 V |
| ✅ | `290` | 233.2 | 238.2 | 1.014 | 1.036 | 2.2 % | 4.46 V |
| ✅ | `282` | 233.2 | 238.2 | 1.014 | 1.036 | 2.2 % | 4.44 V |
| ✅ | `272` | 233.2 | 238.1 | 1.014 | 1.035 | 2.1 % | 4.4 V |
| ✅ | `321` | 233.2 | 238.0 | 1.014 | 1.035 | 2.1 % | 4.29 V |
| ✅ | `264` | 233.2 | 238.0 | 1.014 | 1.035 | 2.1 % | 4.25 V |
| ✅ | `263` | 233.2 | 237.9 | 1.014 | 1.034 | 2.0 % | 4.13 V |
| ✅ | `254` | 233.2 | 237.9 | 1.014 | 1.034 | 2.0 % | 4.11 V |
| ✅ | `229` | 233.2 | 237.7 | 1.014 | 1.034 | 2.0 % | 3.97 V |
| ✅ | `216` | 233.2 | 237.7 | 1.014 | 1.033 | 1.9 % | 3.94 V |
| ✅ | `530` | 234.1 | 237.6 | 1.018 | 1.033 | 1.5 % | 3.15 V |
| ✅ | `192` | 233.3 | 237.6 | 1.014 | 1.033 | 1.9 % | 3.8 V |
| ✅ | `175` | 233.3 | 237.5 | 1.014 | 1.033 | 1.9 % | 3.77 V |
| ✅ | `166` | 233.3 | 237.3 | 1.014 | 1.032 | 1.8 % | 3.56 V |
| ✅ | `151` | 233.3 | 237.2 | 1.014 | 1.031 | 1.7 % | 3.38 V |
| ✅ | `145` | 233.3 | 237.1 | 1.014 | 1.031 | 1.7 % | 3.34 V |
| ✅ | `428` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.59 V |
| ✅ | `416` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.6 V |
| ✅ | `138` | 233.3 | 237.1 | 1.014 | 1.031 | 1.6 % | 3.29 V |
| ✅ | `391` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.61 V |
| ✅ | `392` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.61 V |
| ✅ | `380` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.61 V |
| ✅ | `366` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.62 V |
| ✅ | `355` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.63 V |
| ✅ | `441` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.65 V |
| ✅ | `327` | 234.1 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.67 V |
| ✅ | `348` | 234.2 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.65 V |
| ✅ | `384` | 234.1 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.68 V |
| ✅ | `318` | 234.1 | 237.1 | 1.018 | 1.031 | 1.3 % | 2.69 V |
| ✅ | `300` | 234.0 | 237.0 | 1.017 | 1.031 | 1.3 % | 2.7 V |
| ✅ | `144` | 233.3 | 237.0 | 1.014 | 1.031 | 1.6 % | 3.26 V |
| ✅ | `498` | 233.4 | 237.0 | 1.015 | 1.031 | 1.6 % | 3.37 V |
| ✅ | `131` | 233.3 | 237.0 | 1.014 | 1.031 | 1.6 % | 3.24 V |
| ✅ | `491` | 233.4 | 237.0 | 1.015 | 1.03 | 1.6 % | 3.34 V |
| ✅ | `473` | 233.4 | 237.0 | 1.015 | 1.03 | 1.6 % | 3.31 V |
| ✅ | `472` | 233.4 | 236.9 | 1.015 | 1.03 | 1.5 % | 3.29 V |
| ✅ | `439` | 233.4 | 236.9 | 1.015 | 1.03 | 1.5 % | 3.26 V |
| ✅ | `536` | 233.4 | 236.9 | 1.015 | 1.03 | 1.5 % | 3.24 V |
| ✅ | `427` | 233.4 | 236.8 | 1.015 | 1.03 | 1.5 % | 3.21 V |
| ✅ | `479` | 233.4 | 236.7 | 1.015 | 1.029 | 1.5 % | 3.15 V |
| ✅ | `116` | 233.3 | 236.7 | 1.014 | 1.029 | 1.5 % | 2.92 V |
| ✅ | `128` | 233.3 | 236.7 | 1.014 | 1.029 | 1.5 % | 2.87 V |
| ✅ | `377` | 233.4 | 236.7 | 1.015 | 1.029 | 1.4 % | 3.13 V |
| ✅ | `376` | 233.4 | 236.7 | 1.015 | 1.029 | 1.4 % | 3.12 V |
| ✅ | `354` | 233.4 | 236.6 | 1.015 | 1.029 | 1.4 % | 3.09 V |
| ✅ | `104` | 233.3 | 236.6 | 1.014 | 1.029 | 1.4 % | 2.79 V |
| ✅ | `198` | 233.3 | 236.6 | 1.014 | 1.029 | 1.4 % | 2.78 V |
| ✅ | `108` | 233.3 | 236.5 | 1.014 | 1.028 | 1.4 % | 2.71 V |
| ✅ | `99` | 233.3 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.69 V |
| ✅ | `521` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.99 V |
| ✅ | `307` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.96 V |
| ✅ | `256` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.86 V |
| ✅ | `247` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.84 V |
| ✅ | `226` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.72 V |
| ✅ | `220` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.7 V |
| ✅ | `219` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.6 V |
| ✅ | `208` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.59 V |
| ✅ | `201` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.53 V |
| ✅ | `188` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.53 V |
| ✅ | `179` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.57 V |
| ✅ | `162` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.57 V |
| ✅ | `187` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.62 V |
| ✅ | `147` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.62 V |
| ✅ | `90` | 233.4 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.63 V |
| ✅ | `82` | 233.3 | 236.5 | 1.015 | 1.028 | 1.4 % | 2.64 V |
| ✅ | `62` | 232.4 | 234.4 | 1.011 | 1.019 | 0.9 % | 1.76 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=2.136 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=1.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=2.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.044 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=1.857 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.991 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.132 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=1.865 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=1.842 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=1.89 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=1.906 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=2.115 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=1.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.084 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.119 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=2.045 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=2.17 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.159 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=1.982 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=1.96 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=2.117 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=2.161 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=1.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=1.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.162 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=1.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.15 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.998 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=1.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=2.209 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.841 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.058 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=1.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=1.899 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=2.128 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=1.84 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=2.08 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.855 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=1.876 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=2.107 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.199 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=2.083 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.72 V at bus '949' — reflects the neutral shift under unbalanced loading.

