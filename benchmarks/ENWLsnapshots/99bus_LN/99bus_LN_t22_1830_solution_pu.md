# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:29  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -45206.325  
**Solve time:** 0.043 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 50.908 kW |
| Total load | 49.404 kW |
| Total network losses (P) | 1.505 kW |
| Total network losses (Q) | 449.23 W var |
| Loss fraction | 3.0% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.347 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.023 (`498`) | 1.3 % (`498`) | 4.35 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `498` | 232.2 | 235.2 | 1.01 | 1.023 | 1.3 % | 1.67 V |
| ✅ | `491` | 232.2 | 235.2 | 1.01 | 1.022 | 1.3 % | 1.63 V |
| ✅ | `473` | 232.2 | 235.1 | 1.01 | 1.022 | 1.3 % | 1.6 V |
| ✅ | `472` | 232.2 | 235.1 | 1.01 | 1.022 | 1.2 % | 1.57 V |
| ✅ | `439` | 232.2 | 235.1 | 1.01 | 1.022 | 1.2 % | 1.53 V |
| ✅ | `536` | 232.2 | 235.0 | 1.01 | 1.022 | 1.2 % | 1.51 V |
| ✅ | `427` | 232.2 | 235.0 | 1.01 | 1.022 | 1.2 % | 1.46 V |
| ✅ | `479` | 232.2 | 234.9 | 1.01 | 1.021 | 1.2 % | 1.38 V |
| ✅ | `377` | 232.2 | 234.9 | 1.01 | 1.021 | 1.1 % | 1.35 V |
| ✅ | `376` | 232.2 | 234.9 | 1.01 | 1.021 | 1.1 % | 1.33 V |
| ✅ | `354` | 232.2 | 234.8 | 1.01 | 1.021 | 1.1 % | 1.29 V |
| ✅ | `521` | 232.2 | 234.7 | 1.01 | 1.02 | 1.1 % | 1.15 V |
| ✅ | `307` | 232.2 | 234.6 | 1.01 | 1.02 | 1.0 % | 1.1 V |
| ✅ | `256` | 232.2 | 234.5 | 1.01 | 1.019 | 1.0 % | 0.95 V |
| ✅ | `247` | 232.2 | 234.4 | 1.01 | 1.019 | 1.0 % | 0.91 V |
| ✅ | `226` | 232.2 | 234.2 | 1.01 | 1.018 | 0.8 % | 0.7 V |
| ✅ | `220` | 232.2 | 234.2 | 1.01 | 1.018 | 0.8 % | 0.67 V |
| ✅ | `949` | 231.9 | 234.2 | 1.008 | 1.018 | 1.0 % | 3.71 V |
| ✅ | `313` | 232.1 | 234.2 | 1.009 | 1.018 | 0.9 % | 2.48 V |
| ✅ | `303` | 232.1 | 234.1 | 1.009 | 1.018 | 0.9 % | 2.46 V |
| ✅ | `290` | 232.1 | 234.1 | 1.009 | 1.018 | 0.9 % | 2.43 V |
| ✅ | `282` | 232.1 | 234.1 | 1.009 | 1.018 | 0.8 % | 2.4 V |
| ✅ | `272` | 232.1 | 234.0 | 1.009 | 1.018 | 0.8 % | 2.38 V |
| ✅ | `895` | 231.9 | 234.0 | 1.008 | 1.017 | 0.9 % | 3.66 V |
| ✅ | `717` | 232.2 | 234.0 | 1.01 | 1.017 | 0.8 % | 3.77 V |
| ✅ | `904` | 231.9 | 234.0 | 1.008 | 1.017 | 0.9 % | 3.65 V |
| ✅ | `321` | 232.1 | 234.0 | 1.009 | 1.017 | 0.8 % | 2.28 V |
| ✅ | `775` | 232.1 | 233.9 | 1.009 | 1.017 | 0.8 % | 3.45 V |
| ✅ | `894` | 231.1 | 233.9 | 1.005 | 1.017 | 1.2 % | 4.35 V |
| ✅ | `849` | 231.9 | 233.9 | 1.008 | 1.017 | 0.9 % | 3.63 V |
| ✅ | `264` | 232.1 | 233.9 | 1.009 | 1.017 | 0.8 % | 2.25 V |
| ✅ | `219` | 232.2 | 233.9 | 1.01 | 1.017 | 0.7 % | 0.49 V |
| ✅ | `208` | 232.2 | 233.9 | 1.01 | 1.017 | 0.7 % | 0.48 V |
| ✅ | `655` | 232.2 | 233.8 | 1.01 | 1.017 | 0.7 % | 3.6 V |
| ✅ | `254` | 232.1 | 233.8 | 1.009 | 1.016 | 0.7 % | 2.13 V |
| ✅ | `263` | 232.1 | 233.8 | 1.009 | 1.016 | 0.7 % | 2.13 V |
| ✅ | `673` | 232.1 | 233.8 | 1.009 | 1.016 | 0.7 % | 3.4 V |
| ✅ | `693` | 232.1 | 233.8 | 1.009 | 1.016 | 0.7 % | 3.39 V |
| ✅ | `609` | 232.2 | 233.8 | 1.01 | 1.016 | 0.7 % | 3.57 V |
| ✅ | `808` | 232.1 | 233.8 | 1.009 | 1.016 | 0.7 % | 3.3 V |
| ✅ | `665` | 232.1 | 233.7 | 1.009 | 1.016 | 0.7 % | 3.4 V |
| ✅ | `779` | 232.1 | 233.7 | 1.009 | 1.016 | 0.7 % | 3.54 V |
| ✅ | `659` | 232.1 | 233.7 | 1.009 | 1.016 | 0.7 % | 3.37 V |
| ✅ | `229` | 232.2 | 233.7 | 1.009 | 1.016 | 0.7 % | 2.04 V |
| ✅ | `773` | 232.2 | 233.7 | 1.01 | 1.016 | 0.6 % | 3.51 V |
| ✅ | `216` | 232.2 | 233.7 | 1.009 | 1.016 | 0.7 % | 2.01 V |
| ✅ | `568` | 232.2 | 233.6 | 1.01 | 1.016 | 0.6 % | 3.29 V |
| ✅ | `175` | 232.2 | 233.5 | 1.009 | 1.015 | 0.6 % | 1.88 V |
| ✅ | `192` | 232.2 | 233.5 | 1.009 | 1.015 | 0.6 % | 1.89 V |
| ✅ | `166` | 232.2 | 233.5 | 1.01 | 1.015 | 0.6 % | 1.75 V |
| ✅ | `617` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.12 V |
| ✅ | `627` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.13 V |
| ✅ | `545` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 2.99 V |
| ✅ | `608` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.12 V |
| ✅ | `618` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.12 V |
| ✅ | `201` | 232.2 | 233.4 | 1.01 | 1.015 | 0.5 % | 0.55 V |
| ✅ | `600` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.09 V |
| ✅ | `607` | 232.3 | 233.4 | 1.01 | 1.015 | 0.5 % | 3.11 V |
| ✅ | `188` | 232.2 | 233.4 | 1.01 | 1.015 | 0.5 % | 0.58 V |
| ✅ | `151` | 232.2 | 233.3 | 1.01 | 1.014 | 0.5 % | 1.62 V |
| ✅ | `145` | 232.2 | 233.3 | 1.01 | 1.014 | 0.5 % | 1.6 V |
| ✅ | `654` | 232.3 | 233.3 | 1.01 | 1.014 | 0.4 % | 3.31 V |
| ✅ | `661` | 232.3 | 233.3 | 1.01 | 1.014 | 0.4 % | 3.34 V |
| ✅ | `138` | 232.2 | 233.2 | 1.01 | 1.014 | 0.5 % | 1.57 V |
| ✅ | `635` | 232.3 | 233.2 | 1.01 | 1.014 | 0.4 % | 3.29 V |
| ✅ | `677` | 232.4 | 233.2 | 1.01 | 1.014 | 0.4 % | 3.49 V |
| ✅ | `131` | 232.2 | 233.2 | 1.01 | 1.014 | 0.4 % | 1.54 V |
| ✅ | `660` | 232.3 | 233.2 | 1.01 | 1.014 | 0.4 % | 3.44 V |
| ✅ | `530` | 232.5 | 233.2 | 1.011 | 1.014 | 0.3 % | 2.18 V |
| ✅ | `644` | 232.3 | 233.2 | 1.01 | 1.014 | 0.4 % | 3.32 V |
| ✅ | `896` | 232.3 | 233.2 | 1.01 | 1.014 | 0.4 % | 3.47 V |
| ✅ | `144` | 232.2 | 233.2 | 1.01 | 1.014 | 0.4 % | 1.53 V |
| ✅ | `128` | 232.2 | 233.1 | 1.01 | 1.013 | 0.4 % | 1.33 V |
| ✅ | `428` | 232.7 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.84 V |
| ✅ | `380` | 232.6 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.82 V |
| ✅ | `392` | 232.6 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.81 V |
| ✅ | `391` | 232.6 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.79 V |
| ✅ | `416` | 232.6 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.78 V |
| ✅ | `366` | 232.6 | 233.1 | 1.012 | 1.013 | 0.2 % | 1.78 V |
| ✅ | `355` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.77 V |
| ✅ | `441` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.75 V |
| ✅ | `327` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.71 V |
| ✅ | `384` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.68 V |
| ✅ | `318` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.69 V |
| ✅ | `348` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.66 V |
| ✅ | `300` | 232.6 | 233.1 | 1.011 | 1.013 | 0.2 % | 1.67 V |
| ✅ | `198` | 232.2 | 233.0 | 1.01 | 1.013 | 0.3 % | 1.29 V |
| ✅ | `179` | 232.2 | 233.0 | 1.01 | 1.013 | 0.3 % | 0.88 V |
| ✅ | `162` | 232.2 | 233.0 | 1.01 | 1.013 | 0.3 % | 0.89 V |
| ✅ | `104` | 232.2 | 233.0 | 1.01 | 1.013 | 0.3 % | 1.27 V |
| ✅ | `116` | 232.2 | 233.0 | 1.01 | 1.013 | 0.3 % | 1.31 V |
| ✅ | `108` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.23 V |
| ✅ | `99` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.21 V |
| ✅ | `187` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.09 V |
| ✅ | `147` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.04 V |
| ✅ | `90` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.17 V |
| ✅ | `82` | 232.2 | 232.9 | 1.01 | 1.013 | 0.3 % | 1.18 V |
| ✅ | `62` | 231.6 | 232.0 | 1.007 | 1.009 | 0.2 % | 0.82 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=2.112 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=1.937 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=2.15 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.083 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=1.829 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.08 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.991 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=1.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=2.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=2.108 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=2.112 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=2.136 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=1.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=2.209 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=1.89 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=2.014 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=1.821 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=1.901 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=1.841 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.85 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=1.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=1.899 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=1.863 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.077 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=2.197 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=2.0 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.084 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.906 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.842 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=2.107 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=2.075 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=2.117 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=2.135 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=1.998 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=1.96 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=1.812 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.161 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=2.178 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.982 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.045 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=1.857 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=1.876 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.35 V at bus '894' — reflects the neutral shift under unbalanced loading.

