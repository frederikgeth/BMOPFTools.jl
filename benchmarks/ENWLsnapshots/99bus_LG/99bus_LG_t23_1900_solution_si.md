# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -13604.5801  
**Solve time:** 0.08 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 51.446 kW |
| Total load | 50.717 kW |
| Total network losses (P) | 728.41 W |
| Total network losses (Q) | 179.57 W var |
| Loss fraction | 1.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.627 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.992 (`894`) | 1.01 (`498`) | 1.6 % (`894`) | 4.63 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `498` | 229.9 | 232.2 | 1.0 | 1.01 | 1.0 % | 1.0 V |
| ✅ | `717` | 229.6 | 232.2 | 0.998 | 1.01 | 1.1 % | 4.03 V |
| ✅ | `491` | 229.9 | 232.2 | 1.0 | 1.01 | 1.0 % | 0.99 V |
| ✅ | `473` | 229.9 | 232.2 | 1.0 | 1.01 | 1.0 % | 0.98 V |
| ✅ | `472` | 229.9 | 232.2 | 1.0 | 1.009 | 1.0 % | 0.98 V |
| ✅ | `439` | 229.9 | 232.2 | 1.0 | 1.009 | 1.0 % | 0.97 V |
| ✅ | `536` | 229.9 | 232.1 | 1.0 | 1.009 | 1.0 % | 0.97 V |
| ✅ | `427` | 229.9 | 232.1 | 1.0 | 1.009 | 0.9 % | 0.96 V |
| ✅ | `655` | 229.6 | 232.1 | 0.998 | 1.009 | 1.1 % | 3.92 V |
| ✅ | `479` | 229.9 | 232.1 | 1.0 | 1.009 | 0.9 % | 0.96 V |
| ✅ | `609` | 229.6 | 232.1 | 0.998 | 1.009 | 1.1 % | 3.88 V |
| ✅ | `377` | 229.9 | 232.1 | 1.0 | 1.009 | 0.9 % | 0.95 V |
| ✅ | `376` | 229.9 | 232.0 | 1.0 | 1.009 | 0.9 % | 0.95 V |
| ✅ | `354` | 229.9 | 232.0 | 1.0 | 1.009 | 0.9 % | 0.95 V |
| ✅ | `779` | 229.6 | 232.0 | 0.998 | 1.009 | 1.0 % | 3.84 V |
| ✅ | `773` | 229.6 | 232.0 | 0.998 | 1.009 | 1.0 % | 3.79 V |
| ✅ | `521` | 229.9 | 231.9 | 1.0 | 1.008 | 0.9 % | 0.94 V |
| ✅ | `307` | 229.9 | 231.9 | 1.0 | 1.008 | 0.9 % | 0.94 V |
| ✅ | `894` | 228.1 | 231.8 | 0.992 | 1.008 | 1.6 % | 4.63 V |
| ✅ | `659` | 229.6 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.68 V |
| ✅ | `256` | 229.9 | 231.8 | 1.0 | 1.008 | 0.8 % | 0.95 V |
| ✅ | `665` | 229.6 | 231.8 | 0.998 | 1.008 | 0.9 % | 3.69 V |
| ✅ | `568` | 229.6 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.63 V |
| ✅ | `673` | 229.7 | 231.8 | 0.999 | 1.008 | 0.9 % | 3.68 V |
| ✅ | `849` | 229.5 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.83 V |
| ✅ | `775` | 229.8 | 231.8 | 0.999 | 1.008 | 0.9 % | 3.65 V |
| ✅ | `895` | 229.5 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.82 V |
| ✅ | `904` | 229.5 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.83 V |
| ✅ | `693` | 229.7 | 231.8 | 0.999 | 1.008 | 0.9 % | 3.67 V |
| ✅ | `949` | 229.5 | 231.8 | 0.998 | 1.008 | 1.0 % | 3.81 V |
| ✅ | `247` | 229.9 | 231.8 | 1.0 | 1.008 | 0.8 % | 0.96 V |
| ✅ | `808` | 229.7 | 231.7 | 0.998 | 1.008 | 0.9 % | 3.6 V |
| ✅ | `677` | 228.3 | 231.7 | 0.993 | 1.007 | 1.5 % | 4.43 V |
| ✅ | `660` | 228.5 | 231.7 | 0.994 | 1.007 | 1.4 % | 4.26 V |
| ✅ | `896` | 228.7 | 231.7 | 0.994 | 1.007 | 1.3 % | 4.2 V |
| ✅ | `644` | 228.9 | 231.7 | 0.995 | 1.007 | 1.2 % | 3.99 V |
| ✅ | `635` | 228.9 | 231.7 | 0.995 | 1.007 | 1.2 % | 3.94 V |
| ✅ | `661` | 228.9 | 231.7 | 0.995 | 1.007 | 1.2 % | 3.98 V |
| ✅ | `654` | 228.9 | 231.7 | 0.995 | 1.007 | 1.2 % | 3.93 V |
| ✅ | `607` | 229.3 | 231.7 | 0.997 | 1.007 | 1.1 % | 3.61 V |
| ✅ | `618` | 229.3 | 231.7 | 0.997 | 1.007 | 1.0 % | 3.61 V |
| ✅ | `600` | 229.3 | 231.7 | 0.997 | 1.007 | 1.0 % | 3.58 V |
| ✅ | `608` | 229.3 | 231.7 | 0.997 | 1.007 | 1.0 % | 3.6 V |
| ✅ | `627` | 229.3 | 231.7 | 0.997 | 1.007 | 1.1 % | 3.62 V |
| ✅ | `617` | 229.3 | 231.7 | 0.997 | 1.007 | 1.0 % | 3.6 V |
| ✅ | `545` | 229.4 | 231.7 | 0.998 | 1.007 | 1.0 % | 3.42 V |
| ✅ | `226` | 229.9 | 231.6 | 1.0 | 1.007 | 0.7 % | 1.0 V |
| ✅ | `220` | 229.9 | 231.6 | 1.0 | 1.007 | 0.7 % | 1.0 V |
| ✅ | `219` | 229.9 | 231.5 | 1.0 | 1.006 | 0.7 % | 1.08 V |
| ✅ | `530` | 229.7 | 231.4 | 0.999 | 1.006 | 0.8 % | 2.68 V |
| ✅ | `428` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.32 V |
| ✅ | `208` | 229.9 | 231.4 | 1.0 | 1.006 | 0.6 % | 1.09 V |
| ✅ | `380` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.3 V |
| ✅ | `392` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.3 V |
| ✅ | `391` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.27 V |
| ✅ | `366` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.27 V |
| ✅ | `355` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.26 V |
| ✅ | `416` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.25 V |
| ✅ | `441` | 229.8 | 231.4 | 0.999 | 1.006 | 0.7 % | 2.24 V |
| ✅ | `327` | 229.8 | 231.3 | 0.999 | 1.006 | 0.7 % | 2.21 V |
| ✅ | `384` | 229.8 | 231.3 | 0.999 | 1.006 | 0.7 % | 2.2 V |
| ✅ | `318` | 229.8 | 231.3 | 0.999 | 1.006 | 0.7 % | 2.19 V |
| ✅ | `300` | 229.8 | 231.3 | 0.999 | 1.006 | 0.7 % | 2.18 V |
| ✅ | `348` | 229.8 | 231.2 | 0.999 | 1.005 | 0.6 % | 2.1 V |
| ✅ | `201` | 229.9 | 231.2 | 1.0 | 1.005 | 0.5 % | 1.26 V |
| ✅ | `188` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.28 V |
| ✅ | `187` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.56 V |
| ✅ | `147` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.54 V |
| ✅ | `90` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.63 V |
| ✅ | `162` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.46 V |
| ✅ | `179` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.45 V |
| ✅ | `82` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.62 V |
| ✅ | `99` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.63 V |
| ✅ | `108` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.62 V |
| ✅ | `116` | 229.9 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.73 V |
| ✅ | `104` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.65 V |
| ✅ | `128` | 230.1 | 231.1 | 1.0 | 1.005 | 0.4 % | 1.59 V |
| ✅ | `198` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.62 V |
| ✅ | `144` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.76 V |
| ✅ | `131` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.73 V |
| ✅ | `138` | 230.0 | 231.1 | 1.0 | 1.005 | 0.5 % | 1.74 V |
| ✅ | `145` | 230.1 | 231.1 | 1.0 | 1.005 | 0.4 % | 1.74 V |
| ✅ | `151` | 230.1 | 231.1 | 1.0 | 1.005 | 0.4 % | 1.74 V |
| ✅ | `166` | 230.2 | 231.1 | 1.001 | 1.005 | 0.4 % | 1.73 V |
| ✅ | `192` | 230.2 | 231.1 | 1.001 | 1.005 | 0.4 % | 1.82 V |
| ✅ | `175` | 230.2 | 231.1 | 1.001 | 1.005 | 0.4 % | 1.8 V |
| ✅ | `216` | 230.2 | 231.1 | 1.001 | 1.005 | 0.4 % | 1.82 V |
| ✅ | `229` | 230.3 | 231.1 | 1.001 | 1.005 | 0.3 % | 1.82 V |
| ✅ | `263` | 230.3 | 231.0 | 1.001 | 1.005 | 0.3 % | 1.86 V |
| ✅ | `254` | 230.3 | 231.0 | 1.001 | 1.005 | 0.3 % | 1.84 V |
| ✅ | `264` | 230.4 | 231.0 | 1.002 | 1.005 | 0.3 % | 1.86 V |
| ✅ | `321` | 230.4 | 231.0 | 1.002 | 1.005 | 0.3 % | 1.86 V |
| ✅ | `272` | 230.5 | 231.0 | 1.002 | 1.004 | 0.2 % | 1.88 V |
| ✅ | `282` | 230.5 | 231.0 | 1.002 | 1.004 | 0.2 % | 1.89 V |
| ✅ | `290` | 230.5 | 231.0 | 1.002 | 1.004 | 0.2 % | 1.89 V |
| ✅ | `303` | 230.6 | 231.0 | 1.002 | 1.004 | 0.2 % | 1.89 V |
| ✅ | `313` | 230.6 | 231.0 | 1.002 | 1.004 | 0.2 % | 1.89 V |
| ✅ | `62` | 230.0 | 230.8 | 1.0 | 1.004 | 0.4 % | 1.13 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=1.231 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=1.353 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=1.346 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=1.286 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.297 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=1.462 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=1.473 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=1.471 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=1.225 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=1.454 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=1.256 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=1.31 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=1.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=1.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=1.428 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=1.448 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=1.428 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=1.285 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=1.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=1.362 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=1.403 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=1.311 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=1.26 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=1.251 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=1.325 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.407 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.269 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=1.293 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=1.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.341 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=1.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=1.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=1.449 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=1.432 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=1.486 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=1.426 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.445 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.289 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=1.383 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.494 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=1.278 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.63 V at bus '894' — reflects the neutral shift under unbalanced loading.

