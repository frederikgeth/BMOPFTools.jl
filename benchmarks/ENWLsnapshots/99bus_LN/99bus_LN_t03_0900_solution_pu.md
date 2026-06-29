# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -41587.4134  
**Solve time:** 0.041 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.734 kW |
| Total load | 22.76 kW |
| Total network losses (P) | 974.03 W |
| Total network losses (Q) | 309.08 W var |
| Loss fraction | 4.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 2.981 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.021 (`949`) | 1.2 % (`894`) | 2.98 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 232.0 | 234.7 | 1.009 | 1.021 | 1.2 % | 2.75 V |
| ✅ | `895` | 232.0 | 234.7 | 1.009 | 1.02 | 1.1 % | 2.69 V |
| ✅ | `904` | 232.0 | 234.6 | 1.009 | 1.02 | 1.1 % | 2.67 V |
| ✅ | `775` | 232.1 | 234.6 | 1.009 | 1.02 | 1.1 % | 2.57 V |
| ✅ | `894` | 231.7 | 234.6 | 1.007 | 1.02 | 1.2 % | 2.98 V |
| ✅ | `849` | 232.0 | 234.6 | 1.009 | 1.02 | 1.1 % | 2.64 V |
| ✅ | `808` | 232.1 | 234.5 | 1.009 | 1.019 | 1.0 % | 2.47 V |
| ✅ | `693` | 232.1 | 234.5 | 1.009 | 1.019 | 1.0 % | 2.48 V |
| ✅ | `673` | 232.1 | 234.5 | 1.009 | 1.019 | 1.0 % | 2.48 V |
| ✅ | `665` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.47 V |
| ✅ | `313` | 231.8 | 234.4 | 1.008 | 1.019 | 1.1 % | 2.48 V |
| ✅ | `779` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.51 V |
| ✅ | `659` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.45 V |
| ✅ | `303` | 231.8 | 234.4 | 1.008 | 1.019 | 1.1 % | 2.45 V |
| ✅ | `896` | 232.2 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.5 V |
| ✅ | `290` | 231.8 | 234.4 | 1.008 | 1.019 | 1.1 % | 2.43 V |
| ✅ | `717` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.59 V |
| ✅ | `655` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.51 V |
| ✅ | `282` | 231.8 | 234.4 | 1.008 | 1.019 | 1.1 % | 2.42 V |
| ✅ | `609` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.5 V |
| ✅ | `773` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.46 V |
| ✅ | `568` | 232.1 | 234.4 | 1.009 | 1.019 | 1.0 % | 2.38 V |
| ✅ | `661` | 232.2 | 234.4 | 1.009 | 1.019 | 0.9 % | 2.42 V |
| ✅ | `272` | 231.8 | 234.4 | 1.008 | 1.019 | 1.1 % | 2.4 V |
| ✅ | `654` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.4 V |
| ✅ | `635` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.38 V |
| ✅ | `644` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.38 V |
| ✅ | `617` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.31 V |
| ✅ | `627` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.31 V |
| ✅ | `618` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.3 V |
| ✅ | `608` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.3 V |
| ✅ | `607` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.29 V |
| ✅ | `600` | 232.2 | 234.3 | 1.009 | 1.019 | 0.9 % | 2.27 V |
| ✅ | `321` | 231.8 | 234.3 | 1.008 | 1.019 | 1.1 % | 2.31 V |
| ✅ | `264` | 231.8 | 234.2 | 1.008 | 1.018 | 1.1 % | 2.29 V |
| ✅ | `660` | 232.2 | 234.2 | 1.009 | 1.018 | 0.9 % | 2.38 V |
| ✅ | `545` | 232.2 | 234.2 | 1.009 | 1.018 | 0.9 % | 2.2 V |
| ✅ | `498` | 231.9 | 234.2 | 1.008 | 1.018 | 1.0 % | 1.78 V |
| ✅ | `491` | 231.9 | 234.2 | 1.008 | 1.018 | 1.0 % | 1.76 V |
| ✅ | `677` | 232.2 | 234.2 | 1.01 | 1.018 | 0.9 % | 2.36 V |
| ✅ | `263` | 231.8 | 234.2 | 1.008 | 1.018 | 1.0 % | 2.19 V |
| ✅ | `473` | 231.9 | 234.2 | 1.008 | 1.018 | 1.0 % | 1.74 V |
| ✅ | `254` | 231.8 | 234.1 | 1.008 | 1.018 | 1.0 % | 2.18 V |
| ✅ | `472` | 231.9 | 234.1 | 1.008 | 1.018 | 1.0 % | 1.72 V |
| ✅ | `439` | 231.9 | 234.1 | 1.008 | 1.018 | 1.0 % | 1.7 V |
| ✅ | `536` | 231.9 | 234.1 | 1.008 | 1.018 | 1.0 % | 1.68 V |
| ✅ | `229` | 231.8 | 234.1 | 1.008 | 1.018 | 1.0 % | 2.1 V |
| ✅ | `427` | 231.9 | 234.0 | 1.008 | 1.018 | 0.9 % | 1.66 V |
| ✅ | `216` | 231.8 | 234.0 | 1.008 | 1.018 | 1.0 % | 2.07 V |
| ✅ | `479` | 231.9 | 234.0 | 1.008 | 1.017 | 0.9 % | 1.61 V |
| ✅ | `377` | 231.9 | 234.0 | 1.008 | 1.017 | 0.9 % | 1.59 V |
| ✅ | `376` | 231.9 | 234.0 | 1.008 | 1.017 | 0.9 % | 1.59 V |
| ✅ | `192` | 231.8 | 233.9 | 1.008 | 1.017 | 0.9 % | 1.97 V |
| ✅ | `175` | 231.8 | 233.9 | 1.008 | 1.017 | 0.9 % | 1.96 V |
| ✅ | `354` | 231.9 | 233.9 | 1.008 | 1.017 | 0.9 % | 1.56 V |
| ✅ | `530` | 232.3 | 233.8 | 1.01 | 1.017 | 0.7 % | 1.67 V |
| ✅ | `166` | 231.8 | 233.8 | 1.008 | 1.017 | 0.9 % | 1.83 V |
| ✅ | `521` | 231.9 | 233.8 | 1.008 | 1.017 | 0.8 % | 1.48 V |
| ✅ | `307` | 231.9 | 233.8 | 1.008 | 1.016 | 0.8 % | 1.46 V |
| ✅ | `151` | 231.8 | 233.7 | 1.008 | 1.016 | 0.8 % | 1.72 V |
| ✅ | `145` | 231.8 | 233.7 | 1.008 | 1.016 | 0.8 % | 1.7 V |
| ✅ | `138` | 231.9 | 233.7 | 1.008 | 1.016 | 0.8 % | 1.67 V |
| ✅ | `256` | 231.9 | 233.7 | 1.008 | 1.016 | 0.8 % | 1.38 V |
| ✅ | `144` | 231.9 | 233.6 | 1.008 | 1.016 | 0.8 % | 1.65 V |
| ✅ | `131` | 231.9 | 233.6 | 1.008 | 1.016 | 0.8 % | 1.64 V |
| ✅ | `247` | 231.9 | 233.6 | 1.008 | 1.016 | 0.8 % | 1.37 V |
| ✅ | `428` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `380` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `392` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `416` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.35 V |
| ✅ | `391` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `366` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `355` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.36 V |
| ✅ | `441` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.37 V |
| ✅ | `327` | 232.3 | 233.6 | 1.01 | 1.016 | 0.6 % | 1.37 V |
| ✅ | `384` | 232.3 | 233.6 | 1.01 | 1.016 | 0.6 % | 1.37 V |
| ✅ | `348` | 232.3 | 233.6 | 1.01 | 1.016 | 0.5 % | 1.34 V |
| ✅ | `318` | 232.3 | 233.6 | 1.01 | 1.016 | 0.6 % | 1.37 V |
| ✅ | `300` | 232.3 | 233.6 | 1.01 | 1.016 | 0.6 % | 1.37 V |
| ✅ | `226` | 231.9 | 233.5 | 1.008 | 1.015 | 0.7 % | 1.28 V |
| ✅ | `128` | 231.9 | 233.5 | 1.008 | 1.015 | 0.7 % | 1.42 V |
| ✅ | `220` | 231.9 | 233.4 | 1.008 | 1.015 | 0.7 % | 1.26 V |
| ✅ | `116` | 231.9 | 233.4 | 1.008 | 1.015 | 0.7 % | 1.41 V |
| ✅ | `198` | 231.9 | 233.4 | 1.008 | 1.015 | 0.7 % | 1.37 V |
| ✅ | `104` | 231.9 | 233.4 | 1.008 | 1.015 | 0.7 % | 1.37 V |
| ✅ | `108` | 231.9 | 233.4 | 1.008 | 1.015 | 0.6 % | 1.33 V |
| ✅ | `99` | 231.9 | 233.3 | 1.008 | 1.015 | 0.6 % | 1.31 V |
| ✅ | `219` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.18 V |
| ✅ | `208` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.18 V |
| ✅ | `201` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.14 V |
| ✅ | `188` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.14 V |
| ✅ | `179` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.2 V |
| ✅ | `162` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.2 V |
| ✅ | `187` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.26 V |
| ✅ | `147` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.25 V |
| ✅ | `90` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.28 V |
| ✅ | `82` | 231.9 | 233.3 | 1.008 | 1.014 | 0.6 % | 1.28 V |
| ✅ | `62` | 231.4 | 232.3 | 1.006 | 1.01 | 0.4 % | 0.86 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=1.341 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=1.43 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=1.439 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=1.494 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=1.454 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=1.372 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=1.46 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=1.285 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=1.269 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=1.383 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=1.448 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=1.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=1.487 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=1.409 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=1.462 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=1.445 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=1.256 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=1.442 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=1.462 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=1.297 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=1.325 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=1.467 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=1.407 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=1.251 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=1.382 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=1.433 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=1.293 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=1.432 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=1.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=1.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=1.346 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=1.255 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=1.244 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=1.238 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=1.322 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=1.28 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=1.289 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=1.261 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=1.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=1.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=1.425 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=1.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=1.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=1.351 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 2.98 V at bus '894' — reflects the neutral shift under unbalanced loading.

