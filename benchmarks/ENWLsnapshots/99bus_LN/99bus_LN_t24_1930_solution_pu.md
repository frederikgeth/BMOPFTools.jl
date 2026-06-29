# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:30  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 17115.3722  
**Solve time:** 0.046 s  
**Findings:** 48 errors · 0 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 49.905 kW |
| Total load | 49.121 kW |
| Total network losses (P) | 784.09 W |
| Total network losses (Q) | 188.17 W var |
| Loss fraction | 1.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 5.622 V (bus `677`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.973 (`677`) | 1.0 (`sourcebus`) | 2.6 % (`677`) | 5.62 V (`677`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `677` | 223.8 | 229.9 | 0.973 | 1.0 | 2.6 % | 5.62 V |
| ✅ | `660` | 224.1 | 229.9 | 0.974 | 0.999 | 2.5 % | 5.37 V |
| ✅ | `896` | 224.1 | 229.9 | 0.975 | 0.999 | 2.5 % | 5.32 V |
| ✅ | `644` | 224.5 | 229.9 | 0.976 | 0.999 | 2.3 % | 4.98 V |
| ✅ | `661` | 224.5 | 229.9 | 0.976 | 0.999 | 2.3 % | 4.96 V |
| ✅ | `635` | 224.6 | 229.9 | 0.976 | 0.999 | 2.3 % | 4.9 V |
| ✅ | `654` | 224.6 | 229.9 | 0.976 | 0.999 | 2.3 % | 4.89 V |
| ✅ | `627` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.4 V |
| ✅ | `607` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.39 V |
| ✅ | `618` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.38 V |
| ✅ | `608` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.37 V |
| ✅ | `617` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.37 V |
| ✅ | `600` | 225.1 | 229.9 | 0.979 | 0.999 | 2.1 % | 4.34 V |
| ✅ | `545` | 225.4 | 229.9 | 0.98 | 0.999 | 2.0 % | 4.08 V |
| ✅ | `568` | 225.4 | 229.9 | 0.98 | 0.999 | 1.9 % | 4.05 V |
| ✅ | `773` | 225.4 | 229.9 | 0.98 | 1.0 | 2.0 % | 4.11 V |
| ✅ | `609` | 225.4 | 229.9 | 0.98 | 1.0 | 2.0 % | 4.13 V |
| ✅ | `655` | 225.4 | 229.9 | 0.98 | 1.0 | 2.0 % | 4.14 V |
| ✅ | `717` | 225.4 | 230.0 | 0.98 | 1.0 | 2.0 % | 4.17 V |
| ✅ | `659` | 225.4 | 229.8 | 0.98 | 0.999 | 1.9 % | 4.03 V |
| ✅ | `779` | 225.4 | 229.9 | 0.98 | 1.0 | 1.9 % | 4.08 V |
| ✅ | `808` | 225.4 | 229.6 | 0.98 | 0.998 | 1.8 % | 3.85 V |
| ✅ | `665` | 225.4 | 229.8 | 0.98 | 0.999 | 1.9 % | 4.01 V |
| ✅ | `693` | 225.4 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.99 V |
| ✅ | `673` | 225.4 | 229.8 | 0.98 | 0.999 | 1.9 % | 4.0 V |
| ✅ | `849` | 225.5 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.96 V |
| ✅ | `894` | 225.5 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.93 V |
| ✅ | `775` | 225.5 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.96 V |
| ✅ | `904` | 225.5 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.95 V |
| ✅ | `895` | 225.5 | 229.8 | 0.98 | 0.999 | 1.9 % | 3.95 V |
| ✅ | `949` | 225.6 | 229.8 | 0.981 | 0.999 | 1.9 % | 3.91 V |
| ✅ | `530` | 226.0 | 229.8 | 0.983 | 0.999 | 1.7 % | 3.44 V |
| ✅ | `416` | 226.4 | 229.7 | 0.984 | 0.999 | 1.4 % | 3.0 V |
| ✅ | `348` | 226.4 | 229.7 | 0.984 | 0.998 | 1.4 % | 2.95 V |
| ✅ | `391` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.02 V |
| ✅ | `428` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.04 V |
| ✅ | `366` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.03 V |
| ✅ | `384` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.01 V |
| ✅ | `355` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.03 V |
| ✅ | `392` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.04 V |
| ✅ | `327` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.02 V |
| ✅ | `318` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.01 V |
| ✅ | `380` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.04 V |
| ✅ | `300` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.01 V |
| ✅ | `441` | 226.4 | 229.8 | 0.984 | 0.999 | 1.5 % | 3.03 V |
| ✅ | `263` | 226.5 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.99 V |
| ✅ | `192` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.96 V |
| ✅ | `254` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.96 V |
| ✅ | `216` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.94 V |
| ✅ | `175` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.93 V |
| ✅ | `229` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.94 V |
| ✅ | `264` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.94 V |
| ✅ | `144` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.88 V |
| ✅ | `321` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.93 V |
| ✅ | `282` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.93 V |
| ✅ | `272` | 226.6 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.92 V |
| ✅ | `151` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.85 V |
| ✅ | `290` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.91 V |
| ✅ | `145` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.84 V |
| ✅ | `138` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.84 V |
| ✅ | `303` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.9 V |
| ✅ | `131` | 226.7 | 229.8 | 0.985 | 0.999 | 1.4 % | 2.83 V |
| ✅ | `116` | 226.7 | 229.8 | 0.986 | 0.999 | 1.4 % | 2.81 V |
| ✅ | `313` | 226.7 | 229.8 | 0.986 | 0.999 | 1.4 % | 2.9 V |
| ✅ | `166` | 226.7 | 229.8 | 0.986 | 0.999 | 1.4 % | 2.81 V |
| ✅ | `104` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.67 V |
| ✅ | `187` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.59 V |
| ✅ | `147` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.6 V |
| ✅ | `90` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.63 V |
| ✅ | `162` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.58 V |
| ✅ | `179` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.57 V |
| ✅ | `188` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.55 V |
| ✅ | `201` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.54 V |
| ✅ | `208` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.5 V |
| ✅ | `219` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.5 V |
| ✅ | `220` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.48 V |
| ✅ | `226` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.48 V |
| ✅ | `247` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.46 V |
| ✅ | `256` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.46 V |
| ✅ | `307` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.45 V |
| ✅ | `521` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.44 V |
| ✅ | `354` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.43 V |
| ✅ | `376` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.43 V |
| ✅ | `377` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.43 V |
| ✅ | `479` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.43 V |
| ✅ | `427` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.42 V |
| ✅ | `536` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.42 V |
| ✅ | `439` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.42 V |
| ✅ | `472` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.42 V |
| ✅ | `473` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.41 V |
| ✅ | `491` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.41 V |
| ✅ | `498` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.41 V |
| ✅ | `99` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.63 V |
| ✅ | `108` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.63 V |
| ✅ | `82` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.62 V |
| ✅ | `198` | 226.8 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.62 V |
| ✅ | `128` | 226.9 | 229.8 | 0.986 | 0.999 | 1.3 % | 2.61 V |
| ✅ | `62` | 227.9 | 229.9 | 0.991 | 1.0 | 0.9 % | 1.79 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=728.14 W violates [0.0 W, 728.13 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=635.53 W violates [0.0 W, 635.52 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=627.83 W violates [0.0 W, 627.82 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=630.84 W violates [0.0 W, 630.83 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=720.24 W violates [0.0 W, 720.23 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=676.08 W violates [0.0 W, 676.07 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=730.0 W violates [0.0 W, 729.99 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=739.8 W violates [0.0 W, 739.79 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=718.95 W violates [0.0 W, 718.94 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=637.3 W violates [0.0 W, 637.29 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=749.43 W violates [0.0 W, 749.42 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=647.81 W violates [0.0 W, 647.8 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=678.97 W violates [0.0 W, 678.96 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=697.63 W violates [0.0 W, 697.62 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=682.11 W violates [0.0 W, 682.1 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=668.42 W violates [0.0 W, 668.41 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=707.69 W violates [0.0 W, 707.68 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=730.89 W violates [0.0 W, 730.88 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=617.97 W violates [0.0 W, 617.96 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=739.81 W violates [0.0 W, 739.8 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=737.11 W violates [0.0 W, 737.1 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=621.04 W violates [0.0 W, 621.03 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=628.29 W violates [0.0 W, 628.28 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=639.74 W violates [0.0 W, 639.73 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=708.53 W violates [0.0 W, 708.52 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=623.74 W violates [0.0 W, 623.73 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=720.36 W violates [0.0 W, 720.35 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=686.85 W violates [0.0 W, 686.84 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=624.39 W violates [0.0 W, 624.38 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=722.12 W violates [0.0 W, 722.11 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=653.92 W violates [0.0 W, 653.91 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=644.5 W violates [0.0 W, 644.49 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=733.4 W violates [0.0 W, 733.39 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=648.45 W violates [0.0 W, 648.44 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=728.6 W violates [0.0 W, 728.59 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=753.52 W violates [0.0 W, 753.51 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=710.4 W violates [0.0 W, 710.39 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=742.9 W violates [0.0 W, 742.89 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=710.68 W violates [0.0 W, 710.67 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=681.47 W violates [0.0 W, 681.46 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=661.2 W violates [0.0 W, 661.19 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=624.02 W violates [0.0 W, 624.01 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=741.59 W violates [0.0 W, 741.58 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=624.14 W violates [0.0 W, 624.13 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=709.47 W violates [0.0 W, 709.46 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=649.96 W violates [0.0 W, 649.95 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=633.32 W violates [0.0 W, 633.31 W].
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=660.74 W violates [0.0 W, 660.73 W].
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.62 V at bus '677' — reflects the neutral shift under unbalanced loading.

