# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -104333.5567  
**Solve time:** 0.069 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.575 kW |
| Total load | 15.163 kW |
| Total network losses (P) | 6.413 kW |
| Total network losses (Q) | 1.872 kW var |
| Loss fraction | 42.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 9.137 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.052 (`896`) | 2.9 % (`313`) | 9.14 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 235.7 | 242.0 | 1.025 | 1.052 | 2.7 % | 9.14 V |
| ✅ | `949` | 236.1 | 241.9 | 1.027 | 1.052 | 2.5 % | 8.8 V |
| ✅ | `895` | 236.1 | 241.7 | 1.027 | 1.051 | 2.4 % | 8.63 V |
| ✅ | `661` | 235.7 | 241.6 | 1.025 | 1.05 | 2.6 % | 8.72 V |
| ✅ | `904` | 236.1 | 241.6 | 1.027 | 1.05 | 2.4 % | 8.57 V |
| ✅ | `660` | 235.7 | 241.6 | 1.025 | 1.05 | 2.6 % | 8.78 V |
| ✅ | `677` | 235.7 | 241.6 | 1.025 | 1.05 | 2.5 % | 8.8 V |
| ✅ | `654` | 235.7 | 241.6 | 1.025 | 1.05 | 2.5 % | 8.65 V |
| ✅ | `775` | 236.2 | 241.6 | 1.027 | 1.05 | 2.3 % | 8.53 V |
| ✅ | `849` | 236.2 | 241.5 | 1.027 | 1.05 | 2.3 % | 8.5 V |
| ✅ | `894` | 236.2 | 241.5 | 1.027 | 1.05 | 2.3 % | 8.22 V |
| ✅ | `644` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 8.64 V |
| ✅ | `635` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 8.59 V |
| ✅ | `808` | 236.2 | 241.3 | 1.027 | 1.049 | 2.2 % | 8.48 V |
| ✅ | `693` | 236.2 | 241.3 | 1.027 | 1.049 | 2.2 % | 8.33 V |
| ✅ | `673` | 236.2 | 241.3 | 1.027 | 1.049 | 2.2 % | 8.32 V |
| ✅ | `665` | 236.2 | 241.3 | 1.027 | 1.049 | 2.2 % | 8.29 V |
| ✅ | `779` | 236.2 | 241.2 | 1.027 | 1.049 | 2.2 % | 8.42 V |
| ✅ | `659` | 236.2 | 241.2 | 1.027 | 1.049 | 2.2 % | 8.25 V |
| ✅ | `627` | 235.7 | 241.2 | 1.025 | 1.049 | 2.4 % | 8.22 V |
| ✅ | `617` | 235.7 | 241.2 | 1.025 | 1.049 | 2.4 % | 8.21 V |
| ✅ | `618` | 235.7 | 241.2 | 1.025 | 1.049 | 2.4 % | 8.21 V |
| ✅ | `608` | 235.7 | 241.2 | 1.025 | 1.049 | 2.4 % | 8.19 V |
| ✅ | `607` | 235.7 | 241.2 | 1.025 | 1.049 | 2.4 % | 8.16 V |
| ✅ | `717` | 236.2 | 241.1 | 1.027 | 1.048 | 2.2 % | 8.57 V |
| ✅ | `655` | 236.2 | 241.1 | 1.027 | 1.048 | 2.2 % | 8.41 V |
| ✅ | `609` | 236.2 | 241.1 | 1.027 | 1.048 | 2.2 % | 8.38 V |
| ✅ | `773` | 236.2 | 241.1 | 1.027 | 1.048 | 2.2 % | 8.31 V |
| ✅ | `568` | 236.1 | 241.1 | 1.027 | 1.048 | 2.2 % | 8.14 V |
| ✅ | `600` | 235.7 | 241.1 | 1.025 | 1.048 | 2.3 % | 8.11 V |
| ✅ | `545` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 7.8 V |
| ✅ | `313` | 233.9 | 240.5 | 1.017 | 1.046 | 2.9 % | 7.28 V |
| ✅ | `303` | 233.9 | 240.5 | 1.017 | 1.046 | 2.9 % | 7.24 V |
| ✅ | `290` | 233.9 | 240.5 | 1.017 | 1.046 | 2.9 % | 7.2 V |
| ✅ | `282` | 233.9 | 240.5 | 1.017 | 1.045 | 2.9 % | 7.17 V |
| ✅ | `272` | 233.9 | 240.4 | 1.017 | 1.045 | 2.8 % | 7.12 V |
| ✅ | `321` | 233.9 | 240.3 | 1.017 | 1.045 | 2.8 % | 6.96 V |
| ✅ | `264` | 233.9 | 240.2 | 1.017 | 1.045 | 2.7 % | 6.9 V |
| ✅ | `263` | 233.9 | 240.1 | 1.017 | 1.044 | 2.7 % | 6.73 V |
| ✅ | `254` | 233.9 | 240.1 | 1.017 | 1.044 | 2.7 % | 6.69 V |
| ✅ | `229` | 234.0 | 239.9 | 1.017 | 1.043 | 2.6 % | 6.48 V |
| ✅ | `216` | 234.0 | 239.9 | 1.017 | 1.043 | 2.6 % | 6.44 V |
| ✅ | `498` | 234.2 | 239.7 | 1.018 | 1.042 | 2.4 % | 2.05 V |
| ✅ | `491` | 234.2 | 239.7 | 1.018 | 1.042 | 2.4 % | 2.05 V |
| ✅ | `192` | 234.0 | 239.7 | 1.017 | 1.042 | 2.5 % | 6.23 V |
| ✅ | `530` | 235.2 | 239.7 | 1.023 | 1.042 | 2.0 % | 6.32 V |
| ✅ | `175` | 234.0 | 239.7 | 1.017 | 1.042 | 2.5 % | 6.19 V |
| ✅ | `473` | 234.2 | 239.7 | 1.018 | 1.042 | 2.4 % | 2.05 V |
| ✅ | `472` | 234.2 | 239.6 | 1.018 | 1.042 | 2.4 % | 2.05 V |
| ✅ | `439` | 234.2 | 239.6 | 1.018 | 1.042 | 2.3 % | 2.06 V |
| ✅ | `536` | 234.2 | 239.5 | 1.018 | 1.041 | 2.3 % | 2.06 V |
| ✅ | `427` | 234.2 | 239.4 | 1.018 | 1.041 | 2.3 % | 2.07 V |
| ✅ | `166` | 234.0 | 239.4 | 1.018 | 1.041 | 2.3 % | 5.79 V |
| ✅ | `479` | 234.2 | 239.3 | 1.018 | 1.041 | 2.3 % | 2.1 V |
| ✅ | `377` | 234.2 | 239.3 | 1.018 | 1.04 | 2.2 % | 2.11 V |
| ✅ | `376` | 234.2 | 239.3 | 1.018 | 1.04 | 2.2 % | 2.12 V |
| ✅ | `354` | 234.2 | 239.2 | 1.018 | 1.04 | 2.2 % | 2.13 V |
| ✅ | `151` | 234.0 | 239.2 | 1.018 | 1.04 | 2.2 % | 5.6 V |
| ✅ | `145` | 234.0 | 239.2 | 1.018 | 1.04 | 2.2 % | 5.55 V |
| ✅ | `138` | 234.0 | 239.1 | 1.018 | 1.04 | 2.2 % | 5.48 V |
| ✅ | `428` | 235.5 | 239.1 | 1.024 | 1.039 | 1.6 % | 5.61 V |
| ✅ | `416` | 235.4 | 239.1 | 1.024 | 1.039 | 1.6 % | 5.59 V |
| ✅ | `391` | 235.4 | 239.1 | 1.023 | 1.039 | 1.6 % | 5.57 V |
| ✅ | `392` | 235.4 | 239.1 | 1.023 | 1.039 | 1.6 % | 5.56 V |
| ✅ | `380` | 235.4 | 239.1 | 1.023 | 1.039 | 1.6 % | 5.56 V |
| ✅ | `366` | 235.3 | 239.1 | 1.023 | 1.039 | 1.6 % | 5.54 V |
| ✅ | `144` | 234.0 | 239.1 | 1.018 | 1.039 | 2.2 % | 5.44 V |
| ✅ | `355` | 235.3 | 239.1 | 1.023 | 1.039 | 1.6 % | 5.53 V |
| ✅ | `441` | 235.2 | 239.1 | 1.022 | 1.039 | 1.7 % | 5.48 V |
| ✅ | `327` | 235.1 | 239.1 | 1.022 | 1.039 | 1.7 % | 5.45 V |
| ✅ | `348` | 235.2 | 239.1 | 1.023 | 1.039 | 1.7 % | 5.51 V |
| ✅ | `384` | 235.0 | 239.0 | 1.022 | 1.039 | 1.7 % | 5.43 V |
| ✅ | `318` | 235.0 | 239.0 | 1.022 | 1.039 | 1.8 % | 5.42 V |
| ✅ | `300` | 234.9 | 239.0 | 1.022 | 1.039 | 1.8 % | 5.4 V |
| ✅ | `131` | 234.0 | 239.0 | 1.018 | 1.039 | 2.2 % | 5.41 V |
| ✅ | `521` | 234.2 | 239.0 | 1.018 | 1.039 | 2.1 % | 2.21 V |
| ✅ | `307` | 234.2 | 238.9 | 1.018 | 1.039 | 2.1 % | 2.24 V |
| ✅ | `256` | 234.2 | 238.7 | 1.018 | 1.038 | 2.0 % | 2.35 V |
| ✅ | `116` | 234.1 | 238.7 | 1.018 | 1.038 | 2.0 % | 4.89 V |
| ✅ | `247` | 234.2 | 238.6 | 1.018 | 1.038 | 1.9 % | 2.38 V |
| ✅ | `128` | 234.1 | 238.6 | 1.018 | 1.037 | 1.9 % | 4.78 V |
| ✅ | `198` | 234.1 | 238.5 | 1.018 | 1.037 | 1.9 % | 4.7 V |
| ✅ | `104` | 234.1 | 238.5 | 1.018 | 1.037 | 1.9 % | 4.73 V |
| ✅ | `108` | 234.1 | 238.4 | 1.018 | 1.036 | 1.9 % | 4.61 V |
| ✅ | `99` | 234.1 | 238.4 | 1.018 | 1.036 | 1.8 % | 4.59 V |
| ✅ | `226` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 2.59 V |
| ✅ | `220` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 2.62 V |
| ✅ | `219` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 2.91 V |
| ✅ | `208` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 2.95 V |
| ✅ | `201` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 3.48 V |
| ✅ | `188` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 3.54 V |
| ✅ | `179` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 3.99 V |
| ✅ | `162` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.04 V |
| ✅ | `187` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.25 V |
| ✅ | `147` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.28 V |
| ✅ | `90` | 234.2 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.5 V |
| ✅ | `82` | 234.1 | 238.3 | 1.018 | 1.036 | 1.8 % | 4.51 V |
| ✅ | `62` | 233.1 | 235.8 | 1.013 | 1.025 | 1.2 % | 3.12 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=2.391 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=2.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=2.786 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.825 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=2.672 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.835 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=2.424 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=2.451 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=2.531 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=2.718 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=2.561 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=2.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=2.753 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.473 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=2.39 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=2.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=2.49 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=2.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.436 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=2.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=2.766 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=2.61 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=2.59 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=2.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.821 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=2.403 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=2.763 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=2.426 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=2.796 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=2.78 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=2.407 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=2.67 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=2.555 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=2.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.689 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=2.469 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.809 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=2.499 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=2.722 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 42.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 9.14 V at bus '896' — reflects the neutral shift under unbalanced loading.

