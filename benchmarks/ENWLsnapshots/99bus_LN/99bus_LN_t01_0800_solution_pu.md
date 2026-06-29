# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 31375.7278  
**Solve time:** 0.064 s  
**Findings:** 48 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 31.376 kW |
| Total load | 30.625 kW |
| Total network losses (P) | 751.02 W |
| Total network losses (Q) | 211.07 W var |
| Loss fraction | 2.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 4.424 V (bus `677`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.972 (`677`) | 1.0 (`sourcebus`) | 2.3 % (`677`) | 4.42 V (`677`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `677` | 223.5 | 228.7 | 0.972 | 0.994 | 2.3 % | 4.42 V |
| ✅ | `896` | 223.7 | 228.7 | 0.972 | 0.994 | 2.2 % | 4.3 V |
| ✅ | `660` | 223.7 | 228.7 | 0.973 | 0.994 | 2.2 % | 4.27 V |
| ✅ | `661` | 223.9 | 228.7 | 0.974 | 0.994 | 2.1 % | 4.03 V |
| ✅ | `644` | 223.9 | 228.7 | 0.974 | 0.994 | 2.1 % | 4.02 V |
| ✅ | `654` | 224.0 | 228.7 | 0.974 | 0.994 | 2.1 % | 3.97 V |
| ✅ | `635` | 224.0 | 228.7 | 0.974 | 0.994 | 2.1 % | 3.97 V |
| ✅ | `627` | 224.3 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.62 V |
| ✅ | `618` | 224.3 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.61 V |
| ✅ | `617` | 224.4 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.6 V |
| ✅ | `608` | 224.4 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.6 V |
| ✅ | `607` | 224.4 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.6 V |
| ✅ | `600` | 224.4 | 228.7 | 0.976 | 0.994 | 1.9 % | 3.56 V |
| ✅ | `949` | 224.5 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.21 V |
| ✅ | `895` | 224.5 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.2 V |
| ✅ | `904` | 224.5 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.19 V |
| ✅ | `849` | 224.6 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.19 V |
| ✅ | `894` | 224.6 | 228.6 | 0.976 | 0.994 | 1.8 % | 2.91 V |
| ✅ | `775` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.24 V |
| ✅ | `808` | 224.6 | 228.3 | 0.976 | 0.993 | 1.6 % | 3.09 V |
| ✅ | `693` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.21 V |
| ✅ | `673` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.23 V |
| ✅ | `665` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.23 V |
| ✅ | `779` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.22 V |
| ✅ | `659` | 224.6 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.24 V |
| ✅ | `717` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.23 V |
| ✅ | `655` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.24 V |
| ✅ | `609` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.24 V |
| ✅ | `773` | 224.6 | 228.6 | 0.976 | 0.994 | 1.7 % | 3.25 V |
| ✅ | `568` | 224.6 | 228.6 | 0.976 | 0.994 | 1.8 % | 3.27 V |
| ✅ | `545` | 224.6 | 228.7 | 0.977 | 0.994 | 1.8 % | 3.34 V |
| ✅ | `530` | 225.3 | 228.8 | 0.979 | 0.995 | 1.5 % | 2.87 V |
| ✅ | `282` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.04 V |
| ✅ | `313` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.03 V |
| ✅ | `303` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.03 V |
| ✅ | `290` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.03 V |
| ✅ | `272` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.02 V |
| ✅ | `263` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.0 V |
| ✅ | `321` | 225.5 | 229.1 | 0.98 | 0.996 | 1.6 % | 3.0 V |
| ✅ | `264` | 225.5 | 229.1 | 0.98 | 0.996 | 1.5 % | 3.0 V |
| ✅ | `254` | 225.5 | 229.1 | 0.981 | 0.996 | 1.5 % | 2.97 V |
| ✅ | `229` | 225.6 | 229.1 | 0.981 | 0.996 | 1.5 % | 2.92 V |
| ✅ | `216` | 225.6 | 229.1 | 0.981 | 0.996 | 1.5 % | 2.92 V |
| ✅ | `192` | 225.6 | 229.1 | 0.981 | 0.996 | 1.5 % | 2.9 V |
| ✅ | `175` | 225.6 | 229.1 | 0.981 | 0.996 | 1.5 % | 2.87 V |
| ✅ | `416` | 225.7 | 228.7 | 0.981 | 0.994 | 1.3 % | 2.49 V |
| ✅ | `428` | 225.7 | 228.7 | 0.981 | 0.994 | 1.3 % | 2.5 V |
| ✅ | `391` | 225.7 | 228.7 | 0.981 | 0.995 | 1.3 % | 2.51 V |
| ✅ | `392` | 225.7 | 228.8 | 0.981 | 0.995 | 1.3 % | 2.52 V |
| ✅ | `380` | 225.7 | 228.8 | 0.981 | 0.995 | 1.3 % | 2.52 V |
| ✅ | `366` | 225.7 | 228.8 | 0.981 | 0.995 | 1.3 % | 2.52 V |
| ✅ | `355` | 225.7 | 228.8 | 0.981 | 0.995 | 1.3 % | 2.53 V |
| ✅ | `348` | 225.7 | 228.7 | 0.981 | 0.994 | 1.3 % | 2.5 V |
| ✅ | `441` | 225.7 | 228.8 | 0.981 | 0.995 | 1.4 % | 2.55 V |
| ✅ | `327` | 225.7 | 228.8 | 0.981 | 0.995 | 1.4 % | 2.55 V |
| ✅ | `384` | 225.7 | 228.8 | 0.981 | 0.995 | 1.4 % | 2.55 V |
| ✅ | `318` | 225.7 | 228.8 | 0.981 | 0.995 | 1.4 % | 2.56 V |
| ✅ | `300` | 225.7 | 228.8 | 0.981 | 0.995 | 1.4 % | 2.57 V |
| ✅ | `166` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.74 V |
| ✅ | `151` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.72 V |
| ✅ | `144` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.72 V |
| ✅ | `145` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.71 V |
| ✅ | `138` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.69 V |
| ✅ | `131` | 225.8 | 229.1 | 0.982 | 0.996 | 1.4 % | 2.68 V |
| ✅ | `116` | 225.9 | 229.0 | 0.982 | 0.996 | 1.4 % | 2.59 V |
| ✅ | `104` | 226.0 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.46 V |
| ✅ | `128` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.44 V |
| ✅ | `198` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.43 V |
| ✅ | `108` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.42 V |
| ✅ | `99` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.41 V |
| ✅ | `498` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `491` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `473` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `472` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `439` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `536` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `427` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.34 V |
| ✅ | `479` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `377` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `376` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `354` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `521` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `307` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `256` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `247` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.35 V |
| ✅ | `226` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.36 V |
| ✅ | `220` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.36 V |
| ✅ | `219` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.37 V |
| ✅ | `208` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.37 V |
| ✅ | `201` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.38 V |
| ✅ | `188` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.38 V |
| ✅ | `187` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.38 V |
| ✅ | `179` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.38 V |
| ✅ | `162` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.39 V |
| ✅ | `147` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.39 V |
| ✅ | `90` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.4 V |
| ✅ | `82` | 226.1 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.39 V |
| ✅ | `62` | 227.4 | 229.3 | 0.989 | 0.997 | 0.8 % | 1.62 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=0.01 W violates [0.0 W, 0.0 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=0.01 W violates [0.0 W, 0.0 W].
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 4.42 V at bus '677' — reflects the neutral shift under unbalanced loading.

