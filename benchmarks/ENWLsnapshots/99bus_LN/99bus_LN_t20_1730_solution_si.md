# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:27  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -105145.998  
**Solve time:** 0.082 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 47.368 kW |
| Total load | 40.596 kW |
| Total network losses (P) | 6.772 kW |
| Total network losses (Q) | 2.017 kW var |
| Loss fraction | 16.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 8.876 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.05 (`949`) | 2.8 % (`313`) | 8.88 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 235.5 | 241.4 | 1.024 | 1.05 | 2.5 % | 8.84 V |
| ✅ | `895` | 235.5 | 241.2 | 1.024 | 1.049 | 2.5 % | 8.68 V |
| ✅ | `904` | 235.5 | 241.1 | 1.024 | 1.048 | 2.4 % | 8.63 V |
| ✅ | `775` | 235.6 | 241.1 | 1.025 | 1.048 | 2.4 % | 8.45 V |
| ✅ | `849` | 235.5 | 241.0 | 1.024 | 1.048 | 2.4 % | 8.55 V |
| ✅ | `894` | 235.1 | 241.0 | 1.022 | 1.048 | 2.6 % | 8.88 V |
| ✅ | `896` | 235.7 | 241.0 | 1.025 | 1.048 | 2.3 % | 8.72 V |
| ✅ | `661` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.41 V |
| ✅ | `808` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.28 V |
| ✅ | `693` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.25 V |
| ✅ | `654` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.35 V |
| ✅ | `673` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.26 V |
| ✅ | `665` | 235.7 | 240.8 | 1.025 | 1.047 | 2.2 % | 8.23 V |
| ✅ | `644` | 235.7 | 240.7 | 1.025 | 1.047 | 2.2 % | 8.32 V |
| ✅ | `779` | 235.7 | 240.7 | 1.025 | 1.047 | 2.2 % | 8.39 V |
| ✅ | `635` | 235.7 | 240.7 | 1.025 | 1.047 | 2.2 % | 8.29 V |
| ✅ | `659` | 235.7 | 240.7 | 1.025 | 1.047 | 2.2 % | 8.19 V |
| ✅ | `660` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.42 V |
| ✅ | `717` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.55 V |
| ✅ | `655` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.4 V |
| ✅ | `609` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.35 V |
| ✅ | `773` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.29 V |
| ✅ | `568` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 8.05 V |
| ✅ | `627` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 7.99 V |
| ✅ | `313` | 234.0 | 240.6 | 1.018 | 1.046 | 2.8 % | 7.38 V |
| ✅ | `617` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 7.97 V |
| ✅ | `618` | 235.7 | 240.6 | 1.025 | 1.046 | 2.1 % | 7.96 V |
| ✅ | `608` | 235.7 | 240.5 | 1.025 | 1.046 | 2.1 % | 7.95 V |
| ✅ | `303` | 234.0 | 240.5 | 1.018 | 1.046 | 2.8 % | 7.34 V |
| ✅ | `677` | 235.7 | 240.5 | 1.025 | 1.046 | 2.1 % | 8.42 V |
| ✅ | `607` | 235.7 | 240.5 | 1.025 | 1.046 | 2.1 % | 7.92 V |
| ✅ | `290` | 234.0 | 240.5 | 1.018 | 1.046 | 2.8 % | 7.28 V |
| ✅ | `600` | 235.7 | 240.5 | 1.025 | 1.046 | 2.1 % | 7.88 V |
| ✅ | `282` | 234.0 | 240.5 | 1.018 | 1.045 | 2.8 % | 7.25 V |
| ✅ | `272` | 234.1 | 240.4 | 1.018 | 1.045 | 2.8 % | 7.19 V |
| ✅ | `545` | 235.7 | 240.3 | 1.025 | 1.045 | 2.0 % | 7.62 V |
| ✅ | `321` | 234.1 | 240.3 | 1.018 | 1.045 | 2.7 % | 6.99 V |
| ✅ | `264` | 234.1 | 240.2 | 1.018 | 1.044 | 2.7 % | 6.92 V |
| ✅ | `498` | 234.3 | 240.1 | 1.019 | 1.044 | 2.5 % | 1.97 V |
| ✅ | `491` | 234.3 | 240.1 | 1.019 | 1.044 | 2.5 % | 1.96 V |
| ✅ | `473` | 234.3 | 240.0 | 1.019 | 1.044 | 2.5 % | 1.94 V |
| ✅ | `263` | 234.1 | 240.0 | 1.018 | 1.043 | 2.6 % | 6.69 V |
| ✅ | `254` | 234.1 | 240.0 | 1.018 | 1.043 | 2.6 % | 6.66 V |
| ✅ | `472` | 234.3 | 240.0 | 1.019 | 1.043 | 2.4 % | 1.92 V |
| ✅ | `439` | 234.3 | 239.9 | 1.019 | 1.043 | 2.4 % | 1.91 V |
| ✅ | `536` | 234.3 | 239.9 | 1.019 | 1.043 | 2.4 % | 1.9 V |
| ✅ | `427` | 234.3 | 239.8 | 1.019 | 1.043 | 2.4 % | 1.88 V |
| ✅ | `229` | 234.1 | 239.8 | 1.018 | 1.043 | 2.5 % | 6.43 V |
| ✅ | `216` | 234.1 | 239.7 | 1.018 | 1.042 | 2.4 % | 6.38 V |
| ✅ | `479` | 234.3 | 239.7 | 1.019 | 1.042 | 2.3 % | 1.87 V |
| ✅ | `377` | 234.3 | 239.6 | 1.019 | 1.042 | 2.3 % | 1.86 V |
| ✅ | `376` | 234.3 | 239.6 | 1.019 | 1.042 | 2.3 % | 1.86 V |
| ✅ | `192` | 234.1 | 239.5 | 1.018 | 1.041 | 2.3 % | 6.13 V |
| ✅ | `354` | 234.3 | 239.5 | 1.019 | 1.041 | 2.2 % | 1.86 V |
| ✅ | `175` | 234.1 | 239.5 | 1.018 | 1.041 | 2.3 % | 6.09 V |
| ✅ | `530` | 235.4 | 239.3 | 1.024 | 1.04 | 1.7 % | 6.11 V |
| ✅ | `166` | 234.2 | 239.3 | 1.018 | 1.04 | 2.2 % | 5.7 V |
| ✅ | `521` | 234.3 | 239.3 | 1.019 | 1.04 | 2.1 % | 1.87 V |
| ✅ | `307` | 234.3 | 239.2 | 1.019 | 1.04 | 2.1 % | 1.89 V |
| ✅ | `151` | 234.2 | 239.0 | 1.018 | 1.039 | 2.1 % | 5.46 V |
| ✅ | `145` | 234.2 | 239.0 | 1.018 | 1.039 | 2.1 % | 5.4 V |
| ✅ | `256` | 234.3 | 238.9 | 1.019 | 1.039 | 2.0 % | 1.97 V |
| ✅ | `138` | 234.2 | 238.9 | 1.018 | 1.039 | 2.0 % | 5.32 V |
| ✅ | `247` | 234.3 | 238.9 | 1.019 | 1.039 | 2.0 % | 1.99 V |
| ✅ | `144` | 234.2 | 238.8 | 1.018 | 1.038 | 2.0 % | 5.27 V |
| ✅ | `131` | 234.2 | 238.8 | 1.018 | 1.038 | 2.0 % | 5.24 V |
| ✅ | `428` | 235.7 | 238.8 | 1.025 | 1.038 | 1.3 % | 5.41 V |
| ✅ | `416` | 235.7 | 238.8 | 1.025 | 1.038 | 1.3 % | 5.37 V |
| ✅ | `380` | 235.6 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.37 V |
| ✅ | `391` | 235.6 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.36 V |
| ✅ | `392` | 235.6 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.36 V |
| ✅ | `366` | 235.5 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.33 V |
| ✅ | `355` | 235.5 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.32 V |
| ✅ | `441` | 235.4 | 238.7 | 1.023 | 1.038 | 1.5 % | 5.27 V |
| ✅ | `327` | 235.3 | 238.7 | 1.023 | 1.038 | 1.5 % | 5.23 V |
| ✅ | `348` | 235.4 | 238.7 | 1.024 | 1.038 | 1.4 % | 5.27 V |
| ✅ | `384` | 235.3 | 238.7 | 1.023 | 1.038 | 1.5 % | 5.21 V |
| ✅ | `318` | 235.2 | 238.7 | 1.023 | 1.038 | 1.5 % | 5.2 V |
| ✅ | `300` | 235.2 | 238.7 | 1.022 | 1.038 | 1.5 % | 5.18 V |
| ✅ | `226` | 234.3 | 238.5 | 1.019 | 1.037 | 1.8 % | 2.18 V |
| ✅ | `128` | 234.3 | 238.4 | 1.019 | 1.037 | 1.8 % | 4.6 V |
| ✅ | `220` | 234.3 | 238.4 | 1.019 | 1.037 | 1.8 % | 2.21 V |
| ✅ | `116` | 234.3 | 238.4 | 1.019 | 1.036 | 1.8 % | 4.67 V |
| ✅ | `198` | 234.3 | 238.3 | 1.019 | 1.036 | 1.7 % | 4.49 V |
| ✅ | `104` | 234.3 | 238.2 | 1.019 | 1.036 | 1.7 % | 4.52 V |
| ✅ | `108` | 234.3 | 238.2 | 1.019 | 1.035 | 1.7 % | 4.4 V |
| ✅ | `99` | 234.3 | 238.1 | 1.019 | 1.035 | 1.7 % | 4.37 V |
| ✅ | `219` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 2.52 V |
| ✅ | `208` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 2.56 V |
| ✅ | `201` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 3.15 V |
| ✅ | `188` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 3.21 V |
| ✅ | `179` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 3.71 V |
| ✅ | `162` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 3.77 V |
| ✅ | `187` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 4.04 V |
| ✅ | `147` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 4.04 V |
| ✅ | `90` | 234.3 | 238.1 | 1.019 | 1.035 | 1.6 % | 4.28 V |
| ✅ | `82` | 234.3 | 238.0 | 1.019 | 1.035 | 1.6 % | 4.29 V |
| ✅ | `62` | 233.2 | 235.6 | 1.014 | 1.024 | 1.0 % | 2.97 V |
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
  Maximum neutral terminal voltage: 8.88 V at bus '894' — reflects the neutral shift under unbalanced loading.

