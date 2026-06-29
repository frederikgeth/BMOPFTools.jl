# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:21  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 46725.9881  
**Solve time:** 0.054 s  
**Findings:** 48 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 46.726 kW |
| Total load | 44.972 kW |
| Total network losses (P) | 1.755 kW |
| Total network losses (Q) | 491.74 W var |
| Loss fraction | 3.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.111 V (bus `677`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.956 (`677`) | 1.0 (`sourcebus`) | 3.6 % (`677`) | 7.11 V (`677`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `677` | 219.9 | 228.2 | 0.956 | 0.992 | 3.6 % | 7.11 V |
| ✅ | `896` | 220.2 | 228.2 | 0.957 | 0.992 | 3.5 % | 6.91 V |
| ✅ | `660` | 220.2 | 228.2 | 0.957 | 0.992 | 3.5 % | 6.85 V |
| ✅ | `661` | 220.6 | 228.2 | 0.959 | 0.992 | 3.3 % | 6.43 V |
| ✅ | `644` | 220.6 | 228.2 | 0.959 | 0.992 | 3.3 % | 6.42 V |
| ✅ | `654` | 220.7 | 228.2 | 0.96 | 0.992 | 3.3 % | 6.34 V |
| ✅ | `635` | 220.7 | 228.2 | 0.96 | 0.992 | 3.3 % | 6.34 V |
| ✅ | `627` | 221.3 | 228.2 | 0.962 | 0.992 | 3.0 % | 5.73 V |
| ✅ | `618` | 221.3 | 228.2 | 0.962 | 0.992 | 3.0 % | 5.7 V |
| ✅ | `607` | 221.3 | 228.2 | 0.962 | 0.992 | 3.0 % | 5.7 V |
| ✅ | `617` | 221.4 | 228.2 | 0.962 | 0.992 | 3.0 % | 5.69 V |
| ✅ | `608` | 221.4 | 228.2 | 0.962 | 0.992 | 3.0 % | 5.69 V |
| ✅ | `600` | 221.4 | 228.2 | 0.963 | 0.992 | 2.9 % | 5.63 V |
| ✅ | `949` | 221.6 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.1 V |
| ✅ | `895` | 221.6 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.1 V |
| ✅ | `904` | 221.6 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.08 V |
| ✅ | `849` | 221.7 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.07 V |
| ✅ | `894` | 221.7 | 228.0 | 0.964 | 0.991 | 2.8 % | 4.66 V |
| ✅ | `775` | 221.7 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.14 V |
| ✅ | `808` | 221.7 | 227.6 | 0.964 | 0.99 | 2.6 % | 4.91 V |
| ✅ | `693` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.1 V |
| ✅ | `673` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.12 V |
| ✅ | `665` | 221.7 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.14 V |
| ✅ | `779` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.12 V |
| ✅ | `659` | 221.7 | 228.0 | 0.964 | 0.991 | 2.8 % | 5.15 V |
| ✅ | `717` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.13 V |
| ✅ | `655` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.15 V |
| ✅ | `609` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.15 V |
| ✅ | `773` | 221.7 | 228.0 | 0.964 | 0.991 | 2.7 % | 5.16 V |
| ✅ | `568` | 221.7 | 228.1 | 0.964 | 0.992 | 2.8 % | 5.18 V |
| ✅ | `545` | 221.7 | 228.2 | 0.964 | 0.992 | 2.8 % | 5.29 V |
| ✅ | `530` | 222.8 | 228.3 | 0.969 | 0.993 | 2.4 % | 4.52 V |
| ✅ | `282` | 223.2 | 228.7 | 0.971 | 0.994 | 2.4 % | 4.59 V |
| ✅ | `313` | 223.2 | 228.7 | 0.971 | 0.994 | 2.4 % | 4.59 V |
| ✅ | `303` | 223.2 | 228.7 | 0.971 | 0.994 | 2.4 % | 4.58 V |
| ✅ | `290` | 223.2 | 228.7 | 0.971 | 0.994 | 2.4 % | 4.58 V |
| ✅ | `272` | 223.3 | 228.7 | 0.971 | 0.994 | 2.4 % | 4.57 V |
| ✅ | `321` | 223.3 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.54 V |
| ✅ | `263` | 223.3 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.53 V |
| ✅ | `264` | 223.3 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.53 V |
| ✅ | `254` | 223.3 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.5 V |
| ✅ | `229` | 223.4 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.44 V |
| ✅ | `216` | 223.4 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.43 V |
| ✅ | `192` | 223.4 | 228.7 | 0.971 | 0.994 | 2.3 % | 4.41 V |
| ✅ | `416` | 223.4 | 228.2 | 0.971 | 0.992 | 2.1 % | 3.9 V |
| ✅ | `428` | 223.4 | 228.2 | 0.971 | 0.992 | 2.1 % | 3.92 V |
| ✅ | `391` | 223.4 | 228.2 | 0.971 | 0.992 | 2.1 % | 3.93 V |
| ✅ | `392` | 223.4 | 228.3 | 0.972 | 0.992 | 2.1 % | 3.94 V |
| ✅ | `380` | 223.4 | 228.3 | 0.972 | 0.992 | 2.1 % | 3.94 V |
| ✅ | `366` | 223.4 | 228.3 | 0.972 | 0.992 | 2.1 % | 3.95 V |
| ✅ | `355` | 223.4 | 228.3 | 0.972 | 0.992 | 2.1 % | 3.95 V |
| ✅ | `348` | 223.4 | 228.1 | 0.972 | 0.992 | 2.0 % | 3.89 V |
| ✅ | `441` | 223.4 | 228.3 | 0.972 | 0.993 | 2.1 % | 3.98 V |
| ✅ | `327` | 223.5 | 228.3 | 0.972 | 0.993 | 2.1 % | 3.99 V |
| ✅ | `384` | 223.5 | 228.3 | 0.972 | 0.993 | 2.1 % | 3.99 V |
| ✅ | `318` | 223.5 | 228.3 | 0.972 | 0.993 | 2.1 % | 4.0 V |
| ✅ | `300` | 223.5 | 228.4 | 0.972 | 0.993 | 2.1 % | 4.01 V |
| ✅ | `175` | 223.5 | 228.7 | 0.972 | 0.994 | 2.3 % | 4.36 V |
| ✅ | `166` | 223.6 | 228.7 | 0.972 | 0.994 | 2.2 % | 4.19 V |
| ✅ | `151` | 223.7 | 228.7 | 0.972 | 0.994 | 2.2 % | 4.16 V |
| ✅ | `144` | 223.7 | 228.7 | 0.973 | 0.994 | 2.2 % | 4.15 V |
| ✅ | `145` | 223.7 | 228.7 | 0.973 | 0.994 | 2.2 % | 4.14 V |
| ✅ | `138` | 223.7 | 228.7 | 0.973 | 0.994 | 2.2 % | 4.12 V |
| ✅ | `131` | 223.7 | 228.7 | 0.973 | 0.994 | 2.1 % | 4.09 V |
| ✅ | `116` | 223.9 | 228.6 | 0.973 | 0.994 | 2.1 % | 3.99 V |
| ✅ | `104` | 224.0 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.8 V |
| ✅ | `128` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.76 V |
| ✅ | `198` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.74 V |
| ✅ | `108` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.73 V |
| ✅ | `99` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.73 V |
| ✅ | `498` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `491` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `473` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `472` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `439` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `536` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `427` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.64 V |
| ✅ | `479` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `377` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `376` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `354` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `521` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `307` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `256` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.65 V |
| ✅ | `247` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.66 V |
| ✅ | `226` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.66 V |
| ✅ | `220` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.66 V |
| ✅ | `219` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.67 V |
| ✅ | `208` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.67 V |
| ✅ | `201` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.68 V |
| ✅ | `188` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.69 V |
| ✅ | `187` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.69 V |
| ✅ | `179` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.69 V |
| ✅ | `162` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.7 V |
| ✅ | `147` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.71 V |
| ✅ | `90` | 224.1 | 228.6 | 0.974 | 0.994 | 2.0 % | 3.71 V |
| ✅ | `82` | 224.1 | 228.6 | 0.975 | 0.994 | 2.0 % | 3.7 V |
| ✅ | `62` | 226.0 | 229.0 | 0.983 | 0.996 | 1.3 % | 2.5 V |
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
  Maximum neutral terminal voltage: 7.11 V at bus '677' — reflects the neutral shift under unbalanced loading.

