# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:30  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 17115.8584  
**Solve time:** 0.113 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 49.905 kW |
| Total load | 49.121 kW |
| Total network losses (P) | 784.1 W |
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
| ✅ | `116` | 226.7 | 229.8 | 0.986 | 0.999 | 1.4 % | 2.82 V |
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

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=728.13 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=635.52 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=627.82 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=630.83 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=720.23 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=676.07 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=729.99 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=739.79 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=718.94 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=637.29 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=749.42 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=647.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=678.96 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=697.62 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=682.1 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=668.41 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=707.68 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=730.88 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=617.96 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=739.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=737.1 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=621.03 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=628.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=639.73 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=708.52 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=623.73 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=720.35 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=686.84 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=624.38 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=722.11 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=653.91 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=644.49 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=733.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=648.44 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=728.59 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=753.51 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=710.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=742.89 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=710.67 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=681.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=661.19 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=624.01 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=741.58 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=624.13 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=709.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=649.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=633.31 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=660.73 W is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 5.62 V at bus '677' — reflects the neutral shift under unbalanced loading.

