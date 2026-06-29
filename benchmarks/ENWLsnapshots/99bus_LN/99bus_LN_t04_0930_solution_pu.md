# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -74640.6491  
**Solve time:** 0.045 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.638 kW |
| Total load | 18.634 kW |
| Total network losses (P) | 3.004 kW |
| Total network losses (Q) | 925.22 W var |
| Loss fraction | 16.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.437 V (bus `949`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.038 (`949`) | 2.1 % (`313`) | 5.44 V (`949`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 234.1 | 238.8 | 1.018 | 1.038 | 2.1 % | 5.44 V |
| ✅ | `895` | 234.1 | 238.7 | 1.018 | 1.038 | 2.0 % | 5.31 V |
| ✅ | `904` | 234.1 | 238.6 | 1.018 | 1.038 | 2.0 % | 5.27 V |
| ✅ | `896` | 234.1 | 238.6 | 1.018 | 1.037 | 2.0 % | 5.3 V |
| ✅ | `849` | 234.1 | 238.6 | 1.018 | 1.037 | 2.0 % | 5.21 V |
| ✅ | `894` | 234.0 | 238.6 | 1.017 | 1.037 | 2.0 % | 5.3 V |
| ✅ | `775` | 234.1 | 238.6 | 1.018 | 1.037 | 1.9 % | 5.16 V |
| ✅ | `661` | 234.1 | 238.4 | 1.018 | 1.037 | 1.9 % | 5.1 V |
| ✅ | `654` | 234.1 | 238.4 | 1.018 | 1.037 | 1.9 % | 5.06 V |
| ✅ | `808` | 234.1 | 238.4 | 1.018 | 1.036 | 1.9 % | 5.09 V |
| ✅ | `644` | 234.1 | 238.4 | 1.018 | 1.036 | 1.9 % | 5.04 V |
| ✅ | `693` | 234.1 | 238.4 | 1.018 | 1.036 | 1.9 % | 5.01 V |
| ✅ | `673` | 234.1 | 238.4 | 1.018 | 1.036 | 1.9 % | 5.01 V |
| ✅ | `635` | 234.1 | 238.4 | 1.018 | 1.036 | 1.8 % | 5.02 V |
| ✅ | `660` | 234.1 | 238.4 | 1.018 | 1.036 | 1.8 % | 5.09 V |
| ✅ | `665` | 234.1 | 238.4 | 1.018 | 1.036 | 1.8 % | 4.99 V |
| ✅ | `779` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 5.08 V |
| ✅ | `659` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.96 V |
| ✅ | `677` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 5.08 V |
| ✅ | `627` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.86 V |
| ✅ | `655` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 5.05 V |
| ✅ | `717` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 5.14 V |
| ✅ | `609` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 5.03 V |
| ✅ | `617` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.84 V |
| ✅ | `773` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.98 V |
| ✅ | `618` | 234.1 | 238.2 | 1.018 | 1.036 | 1.8 % | 4.84 V |
| ✅ | `568` | 234.1 | 238.2 | 1.018 | 1.036 | 1.8 % | 4.87 V |
| ✅ | `608` | 234.1 | 238.2 | 1.018 | 1.036 | 1.8 % | 4.83 V |
| ✅ | `607` | 234.1 | 238.2 | 1.018 | 1.036 | 1.8 % | 4.8 V |
| ✅ | `600` | 234.1 | 238.2 | 1.018 | 1.036 | 1.8 % | 4.77 V |
| ✅ | `545` | 234.1 | 238.0 | 1.018 | 1.035 | 1.7 % | 4.6 V |
| ✅ | `313` | 233.1 | 237.9 | 1.013 | 1.034 | 2.1 % | 4.62 V |
| ✅ | `303` | 233.1 | 237.9 | 1.014 | 1.034 | 2.1 % | 4.59 V |
| ✅ | `290` | 233.1 | 237.8 | 1.014 | 1.034 | 2.1 % | 4.56 V |
| ✅ | `282` | 233.1 | 237.8 | 1.014 | 1.034 | 2.0 % | 4.54 V |
| ✅ | `272` | 233.1 | 237.8 | 1.014 | 1.034 | 2.0 % | 4.5 V |
| ✅ | `321` | 233.1 | 237.7 | 1.014 | 1.033 | 2.0 % | 4.39 V |
| ✅ | `264` | 233.1 | 237.6 | 1.014 | 1.033 | 2.0 % | 4.34 V |
| ✅ | `263` | 233.1 | 237.5 | 1.014 | 1.033 | 1.9 % | 4.22 V |
| ✅ | `254` | 233.1 | 237.5 | 1.014 | 1.033 | 1.9 % | 4.2 V |
| ✅ | `229` | 233.1 | 237.4 | 1.014 | 1.032 | 1.8 % | 4.06 V |
| ✅ | `216` | 233.2 | 237.4 | 1.014 | 1.032 | 1.8 % | 4.02 V |
| ✅ | `192` | 233.2 | 237.2 | 1.014 | 1.031 | 1.8 % | 3.88 V |
| ✅ | `530` | 234.1 | 237.2 | 1.018 | 1.031 | 1.3 % | 3.62 V |
| ✅ | `175` | 233.2 | 237.2 | 1.014 | 1.031 | 1.8 % | 3.85 V |
| ✅ | `498` | 233.3 | 237.1 | 1.014 | 1.031 | 1.7 % | 2.49 V |
| ✅ | `491` | 233.3 | 237.1 | 1.014 | 1.031 | 1.6 % | 2.47 V |
| ✅ | `473` | 233.3 | 237.0 | 1.014 | 1.031 | 1.6 % | 2.45 V |
| ✅ | `166` | 233.2 | 237.0 | 1.014 | 1.031 | 1.7 % | 3.62 V |
| ✅ | `472` | 233.3 | 237.0 | 1.014 | 1.03 | 1.6 % | 2.43 V |
| ✅ | `439` | 233.3 | 237.0 | 1.014 | 1.03 | 1.6 % | 2.4 V |
| ✅ | `536` | 233.3 | 236.9 | 1.014 | 1.03 | 1.6 % | 2.39 V |
| ✅ | `427` | 233.3 | 236.9 | 1.014 | 1.03 | 1.6 % | 2.36 V |
| ✅ | `151` | 233.2 | 236.8 | 1.014 | 1.03 | 1.6 % | 3.44 V |
| ✅ | `145` | 233.2 | 236.8 | 1.014 | 1.03 | 1.6 % | 3.41 V |
| ✅ | `479` | 233.3 | 236.8 | 1.014 | 1.03 | 1.5 % | 2.32 V |
| ✅ | `138` | 233.2 | 236.8 | 1.014 | 1.029 | 1.5 % | 3.36 V |
| ✅ | `377` | 233.3 | 236.7 | 1.014 | 1.029 | 1.5 % | 2.3 V |
| ✅ | `428` | 234.3 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.07 V |
| ✅ | `416` | 234.2 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.06 V |
| ✅ | `391` | 234.2 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.06 V |
| ✅ | `392` | 234.2 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.06 V |
| ✅ | `380` | 234.2 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.06 V |
| ✅ | `366` | 234.2 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.05 V |
| ✅ | `355` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.05 V |
| ✅ | `376` | 233.3 | 236.7 | 1.014 | 1.029 | 1.5 % | 2.29 V |
| ✅ | `144` | 233.2 | 236.7 | 1.014 | 1.029 | 1.5 % | 3.32 V |
| ✅ | `441` | 234.1 | 236.7 | 1.018 | 1.029 | 1.2 % | 3.05 V |
| ✅ | `327` | 234.0 | 236.7 | 1.017 | 1.029 | 1.2 % | 3.04 V |
| ✅ | `348` | 234.1 | 236.7 | 1.018 | 1.029 | 1.1 % | 3.06 V |
| ✅ | `384` | 234.0 | 236.7 | 1.017 | 1.029 | 1.2 % | 3.04 V |
| ✅ | `318` | 234.0 | 236.7 | 1.017 | 1.029 | 1.2 % | 3.04 V |
| ✅ | `131` | 233.2 | 236.7 | 1.014 | 1.029 | 1.5 % | 3.31 V |
| ✅ | `300` | 233.9 | 236.7 | 1.017 | 1.029 | 1.2 % | 3.04 V |
| ✅ | `354` | 233.3 | 236.7 | 1.014 | 1.029 | 1.5 % | 2.27 V |
| ✅ | `521` | 233.3 | 236.5 | 1.014 | 1.028 | 1.4 % | 2.21 V |
| ✅ | `307` | 233.3 | 236.5 | 1.014 | 1.028 | 1.4 % | 2.19 V |
| ✅ | `116` | 233.2 | 236.4 | 1.014 | 1.028 | 1.4 % | 2.96 V |
| ✅ | `128` | 233.3 | 236.4 | 1.014 | 1.028 | 1.4 % | 2.9 V |
| ✅ | `198` | 233.2 | 236.3 | 1.014 | 1.027 | 1.3 % | 2.83 V |
| ✅ | `104` | 233.2 | 236.3 | 1.014 | 1.027 | 1.3 % | 2.84 V |
| ✅ | `256` | 233.3 | 236.3 | 1.014 | 1.027 | 1.3 % | 2.13 V |
| ✅ | `108` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.76 V |
| ✅ | `247` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.13 V |
| ✅ | `99` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.74 V |
| ✅ | `226` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.09 V |
| ✅ | `220` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.08 V |
| ✅ | `219` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.1 V |
| ✅ | `208` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.1 V |
| ✅ | `201` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.24 V |
| ✅ | `188` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.26 V |
| ✅ | `179` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.45 V |
| ✅ | `162` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.47 V |
| ✅ | `187` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.58 V |
| ✅ | `147` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.59 V |
| ✅ | `90` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.68 V |
| ✅ | `82` | 233.3 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.69 V |
| ✅ | `62` | 232.4 | 234.2 | 1.01 | 1.018 | 0.8 % | 1.83 V |
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
  Maximum neutral terminal voltage: 5.44 V at bus '949' — reflects the neutral shift under unbalanced loading.

