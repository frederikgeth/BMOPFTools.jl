# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -105704.3195  
**Solve time:** 0.04 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 46.81 kW |
| Total load | 40.596 kW |
| Total network losses (P) | 6.214 kW |
| Total network losses (Q) | 1.919 kW var |
| Loss fraction | 15.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 8.172 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.053 (`949`) | 3.1 % (`894`) | 8.17 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 235.3 | 242.3 | 1.023 | 1.053 | 3.1 % | 8.02 V |
| ✅ | `895` | 235.3 | 242.1 | 1.023 | 1.053 | 3.0 % | 7.86 V |
| ✅ | `904` | 235.3 | 242.0 | 1.023 | 1.052 | 2.9 % | 7.8 V |
| ✅ | `775` | 235.4 | 242.0 | 1.023 | 1.052 | 2.9 % | 7.62 V |
| ✅ | `849` | 235.3 | 241.9 | 1.023 | 1.052 | 2.9 % | 7.73 V |
| ✅ | `894` | 234.9 | 241.9 | 1.021 | 1.052 | 3.1 % | 8.17 V |
| ✅ | `896` | 235.5 | 241.9 | 1.024 | 1.052 | 2.8 % | 7.72 V |
| ✅ | `661` | 235.5 | 241.7 | 1.024 | 1.051 | 2.7 % | 7.46 V |
| ✅ | `808` | 235.4 | 241.7 | 1.023 | 1.051 | 2.7 % | 7.41 V |
| ✅ | `693` | 235.4 | 241.7 | 1.023 | 1.051 | 2.7 % | 7.39 V |
| ✅ | `673` | 235.4 | 241.7 | 1.023 | 1.051 | 2.7 % | 7.39 V |
| ✅ | `654` | 235.5 | 241.7 | 1.024 | 1.051 | 2.7 % | 7.41 V |
| ✅ | `665` | 235.4 | 241.7 | 1.023 | 1.051 | 2.7 % | 7.37 V |
| ✅ | `644` | 235.5 | 241.6 | 1.024 | 1.051 | 2.7 % | 7.37 V |
| ✅ | `779` | 235.4 | 241.6 | 1.024 | 1.051 | 2.7 % | 7.48 V |
| ✅ | `635` | 235.5 | 241.6 | 1.024 | 1.051 | 2.7 % | 7.34 V |
| ✅ | `659` | 235.4 | 241.6 | 1.023 | 1.051 | 2.7 % | 7.32 V |
| ✅ | `660` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.41 V |
| ✅ | `717` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.61 V |
| ✅ | `655` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.47 V |
| ✅ | `609` | 235.4 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.43 V |
| ✅ | `773` | 235.4 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.36 V |
| ✅ | `568` | 235.4 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.17 V |
| ✅ | `627` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.1 V |
| ✅ | `617` | 235.5 | 241.5 | 1.024 | 1.05 | 2.6 % | 7.08 V |
| ✅ | `618` | 235.5 | 241.4 | 1.024 | 1.05 | 2.6 % | 7.07 V |
| ✅ | `313` | 234.4 | 241.4 | 1.019 | 1.05 | 3.1 % | 7.0 V |
| ✅ | `608` | 235.5 | 241.4 | 1.024 | 1.05 | 2.6 % | 7.06 V |
| ✅ | `677` | 235.5 | 241.4 | 1.024 | 1.05 | 2.6 % | 7.36 V |
| ✅ | `607` | 235.5 | 241.4 | 1.024 | 1.05 | 2.6 % | 7.03 V |
| ✅ | `303` | 234.4 | 241.4 | 1.019 | 1.05 | 3.0 % | 6.96 V |
| ✅ | `600` | 235.5 | 241.4 | 1.024 | 1.049 | 2.6 % | 6.99 V |
| ✅ | `290` | 234.4 | 241.3 | 1.019 | 1.049 | 3.0 % | 6.91 V |
| ✅ | `282` | 234.4 | 241.3 | 1.019 | 1.049 | 3.0 % | 6.87 V |
| ✅ | `272` | 234.4 | 241.3 | 1.019 | 1.049 | 3.0 % | 6.82 V |
| ✅ | `545` | 235.5 | 241.2 | 1.024 | 1.049 | 2.5 % | 6.75 V |
| ✅ | `321` | 234.4 | 241.1 | 1.019 | 1.048 | 2.9 % | 6.63 V |
| ✅ | `264` | 234.4 | 241.0 | 1.019 | 1.048 | 2.9 % | 6.56 V |
| ✅ | `263` | 234.5 | 240.8 | 1.019 | 1.047 | 2.8 % | 6.33 V |
| ✅ | `254` | 234.5 | 240.8 | 1.019 | 1.047 | 2.7 % | 6.31 V |
| ✅ | `229` | 234.5 | 240.6 | 1.019 | 1.046 | 2.7 % | 6.09 V |
| ✅ | `216` | 234.5 | 240.5 | 1.02 | 1.046 | 2.6 % | 6.04 V |
| ✅ | `192` | 234.5 | 240.3 | 1.02 | 1.045 | 2.5 % | 5.8 V |
| ✅ | `175` | 234.5 | 240.3 | 1.02 | 1.045 | 2.5 % | 5.77 V |
| ✅ | `530` | 235.6 | 240.1 | 1.024 | 1.044 | 2.0 % | 5.35 V |
| ✅ | `166` | 234.6 | 240.0 | 1.02 | 1.044 | 2.4 % | 5.44 V |
| ✅ | `498` | 234.7 | 239.9 | 1.02 | 1.043 | 2.3 % | 3.79 V |
| ✅ | `491` | 234.7 | 239.9 | 1.02 | 1.043 | 2.3 % | 3.76 V |
| ✅ | `473` | 234.7 | 239.8 | 1.02 | 1.043 | 2.2 % | 3.73 V |
| ✅ | `472` | 234.7 | 239.8 | 1.02 | 1.042 | 2.2 % | 3.7 V |
| ✅ | `151` | 234.6 | 239.7 | 1.02 | 1.042 | 2.3 % | 5.17 V |
| ✅ | `439` | 234.7 | 239.7 | 1.02 | 1.042 | 2.2 % | 3.67 V |
| ✅ | `145` | 234.6 | 239.7 | 1.02 | 1.042 | 2.2 % | 5.12 V |
| ✅ | `536` | 234.7 | 239.7 | 1.02 | 1.042 | 2.2 % | 3.65 V |
| ✅ | `138` | 234.6 | 239.6 | 1.02 | 1.042 | 2.2 % | 5.04 V |
| ✅ | `427` | 234.7 | 239.6 | 1.02 | 1.042 | 2.1 % | 3.61 V |
| ✅ | `144` | 234.6 | 239.6 | 1.02 | 1.042 | 2.2 % | 4.98 V |
| ✅ | `131` | 234.6 | 239.5 | 1.02 | 1.042 | 2.2 % | 4.97 V |
| ✅ | `428` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.55 V |
| ✅ | `416` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.52 V |
| ✅ | `380` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.54 V |
| ✅ | `391` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.53 V |
| ✅ | `392` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.54 V |
| ✅ | `366` | 235.8 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.53 V |
| ✅ | `355` | 235.7 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.53 V |
| ✅ | `441` | 235.7 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.53 V |
| ✅ | `479` | 234.7 | 239.5 | 1.02 | 1.041 | 2.1 % | 3.56 V |
| ✅ | `327` | 235.7 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.52 V |
| ✅ | `348` | 235.7 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.51 V |
| ✅ | `384` | 235.7 | 239.5 | 1.025 | 1.041 | 1.6 % | 4.52 V |
| ✅ | `318` | 235.6 | 239.5 | 1.025 | 1.041 | 1.7 % | 4.52 V |
| ✅ | `300` | 235.6 | 239.5 | 1.024 | 1.041 | 1.7 % | 4.52 V |
| ✅ | `377` | 234.7 | 239.4 | 1.02 | 1.041 | 2.1 % | 3.53 V |
| ✅ | `376` | 234.7 | 239.4 | 1.02 | 1.041 | 2.0 % | 3.52 V |
| ✅ | `354` | 234.7 | 239.3 | 1.02 | 1.04 | 2.0 % | 3.49 V |
| ✅ | `128` | 234.6 | 239.1 | 1.02 | 1.04 | 1.9 % | 4.42 V |
| ✅ | `116` | 234.6 | 239.1 | 1.02 | 1.039 | 1.9 % | 4.44 V |
| ✅ | `521` | 234.7 | 239.1 | 1.02 | 1.039 | 1.9 % | 3.4 V |
| ✅ | `307` | 234.7 | 239.0 | 1.02 | 1.039 | 1.9 % | 3.37 V |
| ✅ | `198` | 234.6 | 238.9 | 1.02 | 1.039 | 1.9 % | 4.27 V |
| ✅ | `104` | 234.6 | 238.9 | 1.02 | 1.039 | 1.9 % | 4.28 V |
| ✅ | `108` | 234.6 | 238.8 | 1.02 | 1.038 | 1.8 % | 4.17 V |
| ✅ | `99` | 234.6 | 238.8 | 1.02 | 1.038 | 1.8 % | 4.13 V |
| ✅ | `256` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.29 V |
| ✅ | `247` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.28 V |
| ✅ | `226` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.23 V |
| ✅ | `220` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.22 V |
| ✅ | `219` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.24 V |
| ✅ | `208` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.25 V |
| ✅ | `201` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.43 V |
| ✅ | `188` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.46 V |
| ✅ | `179` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.72 V |
| ✅ | `162` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.75 V |
| ✅ | `187` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.93 V |
| ✅ | `147` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 3.92 V |
| ✅ | `90` | 234.7 | 238.7 | 1.02 | 1.038 | 1.8 % | 4.04 V |
| ✅ | `82` | 234.6 | 238.7 | 1.02 | 1.038 | 1.8 % | 4.05 V |
| ✅ | `62` | 233.4 | 236.0 | 1.015 | 1.026 | 1.1 % | 2.75 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.495 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=2.984 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.305 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.254 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.042 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=3.315 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=2.897 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=3.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=2.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=3.05 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=2.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.93 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=3.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=3.084 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=3.301 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=3.421 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=3.313 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=2.882 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=3.153 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.398 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=3.082 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.964 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.359 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.006 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=3.178 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=2.928 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.954 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.911 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=3.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=3.203 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.031 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=3.36 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=3.118 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=3.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.024 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.942 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.396 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.309 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.514 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=2.91 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.438 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=3.021 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 8.17 V at bus '894' — reflects the neutral shift under unbalanced loading.

