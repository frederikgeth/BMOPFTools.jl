# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:31  
**Status:** `LOCALLY_SOLVED`  
**Objective:** 46549.0416  
**Solve time:** 1.179 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 46.549 kW |
| Total load | 44.972 kW |
| Total network losses (P) | 1.578 kW |
| Total network losses (Q) | 414.0 W var |
| Loss fraction | 3.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 6.233 V (bus `677`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.96 (`677`) | 1.0 (`sourcebus`) | 3.3 % (`677`) | 6.23 V (`677`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `677` | 220.7 | 228.4 | 0.96 | 0.993 | 3.3 % | 6.23 V |
| ✅ | `896` | 220.9 | 228.3 | 0.961 | 0.993 | 3.2 % | 6.04 V |
| ✅ | `660` | 221.0 | 228.3 | 0.961 | 0.993 | 3.2 % | 5.98 V |
| ✅ | `661` | 221.4 | 228.3 | 0.962 | 0.993 | 3.0 % | 5.58 V |
| ✅ | `644` | 221.4 | 228.3 | 0.962 | 0.993 | 3.0 % | 5.58 V |
| ✅ | `654` | 221.5 | 228.3 | 0.963 | 0.993 | 3.0 % | 5.5 V |
| ✅ | `635` | 221.5 | 228.3 | 0.963 | 0.993 | 3.0 % | 5.49 V |
| ✅ | `627` | 222.0 | 228.3 | 0.965 | 0.993 | 2.7 % | 4.92 V |
| ✅ | `618` | 222.1 | 228.3 | 0.965 | 0.993 | 2.7 % | 4.9 V |
| ✅ | `607` | 222.1 | 228.3 | 0.965 | 0.993 | 2.7 % | 4.89 V |
| ✅ | `617` | 222.1 | 228.3 | 0.966 | 0.993 | 2.7 % | 4.88 V |
| ✅ | `608` | 222.1 | 228.3 | 0.966 | 0.993 | 2.7 % | 4.88 V |
| ✅ | `600` | 222.1 | 228.3 | 0.966 | 0.993 | 2.7 % | 4.83 V |
| ✅ | `949` | 222.3 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.1 V |
| ✅ | `895` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.1 V |
| ✅ | `904` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.08 V |
| ✅ | `849` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.08 V |
| ✅ | `894` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 3.04 V |
| ✅ | `775` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.29 V |
| ✅ | `808` | 222.4 | 227.7 | 0.967 | 0.99 | 2.3 % | 4.22 V |
| ✅ | `693` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.26 V |
| ✅ | `673` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.27 V |
| ✅ | `665` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.27 V |
| ✅ | `779` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.29 V |
| ✅ | `659` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.29 V |
| ✅ | `717` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.34 V |
| ✅ | `655` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.34 V |
| ✅ | `609` | 222.4 | 228.1 | 0.967 | 0.992 | 2.5 % | 4.34 V |
| ✅ | `773` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.35 V |
| ✅ | `568` | 222.4 | 228.2 | 0.967 | 0.992 | 2.5 % | 4.35 V |
| ✅ | `545` | 222.4 | 228.3 | 0.967 | 0.993 | 2.6 % | 4.51 V |
| ✅ | `530` | 223.4 | 228.4 | 0.971 | 0.993 | 2.2 % | 3.84 V |
| ✅ | `282` | 223.7 | 228.8 | 0.972 | 0.995 | 2.2 % | 4.02 V |
| ✅ | `313` | 223.7 | 228.8 | 0.972 | 0.995 | 2.2 % | 4.02 V |
| ✅ | `303` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 4.01 V |
| ✅ | `290` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 4.01 V |
| ✅ | `272` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 4.0 V |
| ✅ | `321` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 3.97 V |
| ✅ | `263` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 3.97 V |
| ✅ | `264` | 223.7 | 228.8 | 0.973 | 0.995 | 2.2 % | 3.97 V |
| ✅ | `254` | 223.8 | 228.8 | 0.973 | 0.995 | 2.2 % | 3.93 V |
| ✅ | `229` | 223.8 | 228.8 | 0.973 | 0.995 | 2.1 % | 3.87 V |
| ✅ | `216` | 223.8 | 228.8 | 0.973 | 0.995 | 2.1 % | 3.86 V |
| ✅ | `192` | 223.8 | 228.8 | 0.973 | 0.995 | 2.1 % | 3.84 V |
| ✅ | `175` | 223.9 | 228.7 | 0.973 | 0.995 | 2.1 % | 3.8 V |
| ✅ | `416` | 223.9 | 228.3 | 0.974 | 0.992 | 1.9 % | 3.37 V |
| ✅ | `428` | 223.9 | 228.3 | 0.974 | 0.993 | 1.9 % | 3.38 V |
| ✅ | `391` | 223.9 | 228.3 | 0.974 | 0.993 | 1.9 % | 3.38 V |
| ✅ | `392` | 223.9 | 228.3 | 0.974 | 0.993 | 1.9 % | 3.39 V |
| ✅ | `380` | 223.9 | 228.3 | 0.974 | 0.993 | 1.9 % | 3.39 V |
| ✅ | `366` | 223.9 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.39 V |
| ✅ | `355` | 223.9 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.39 V |
| ✅ | `348` | 223.9 | 228.2 | 0.974 | 0.992 | 1.9 % | 3.39 V |
| ✅ | `441` | 224.0 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.41 V |
| ✅ | `327` | 224.0 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.41 V |
| ✅ | `384` | 224.0 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.41 V |
| ✅ | `318` | 224.0 | 228.4 | 0.974 | 0.993 | 1.9 % | 3.41 V |
| ✅ | `300` | 224.0 | 228.5 | 0.974 | 0.993 | 2.0 % | 3.42 V |
| ✅ | `166` | 224.1 | 228.7 | 0.974 | 0.995 | 2.0 % | 3.63 V |
| ✅ | `151` | 224.1 | 228.7 | 0.974 | 0.995 | 2.0 % | 3.6 V |
| ✅ | `144` | 224.1 | 228.7 | 0.974 | 0.995 | 2.0 % | 3.59 V |
| ✅ | `145` | 224.1 | 228.7 | 0.974 | 0.994 | 2.0 % | 3.58 V |
| ✅ | `138` | 224.1 | 228.7 | 0.974 | 0.994 | 2.0 % | 3.56 V |
| ✅ | `131` | 224.2 | 228.7 | 0.975 | 0.994 | 2.0 % | 3.53 V |
| ✅ | `116` | 224.3 | 228.7 | 0.975 | 0.994 | 1.9 % | 3.42 V |
| ✅ | `104` | 224.5 | 228.7 | 0.976 | 0.994 | 1.9 % | 3.24 V |
| ✅ | `128` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.2 V |
| ✅ | `198` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.18 V |
| ✅ | `108` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.17 V |
| ✅ | `99` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.17 V |
| ✅ | `498` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.92 V |
| ✅ | `491` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.92 V |
| ✅ | `473` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.92 V |
| ✅ | `472` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.92 V |
| ✅ | `439` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.93 V |
| ✅ | `536` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.93 V |
| ✅ | `427` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.93 V |
| ✅ | `479` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.94 V |
| ✅ | `377` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.94 V |
| ✅ | `376` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.94 V |
| ✅ | `354` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.94 V |
| ✅ | `521` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.95 V |
| ✅ | `307` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.96 V |
| ✅ | `256` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.97 V |
| ✅ | `247` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.97 V |
| ✅ | `226` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 2.99 V |
| ✅ | `220` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.0 V |
| ✅ | `219` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.02 V |
| ✅ | `208` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.02 V |
| ✅ | `201` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.06 V |
| ✅ | `188` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.06 V |
| ✅ | `187` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.07 V |
| ✅ | `179` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.08 V |
| ✅ | `162` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.1 V |
| ✅ | `147` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.12 V |
| ✅ | `90` | 224.5 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.14 V |
| ✅ | `82` | 224.6 | 228.7 | 0.976 | 0.994 | 1.8 % | 3.14 V |
| ✅ | `62` | 226.3 | 229.1 | 0.984 | 0.996 | 1.2 % | 2.13 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=-0.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=0.0 W is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 6.23 V at bus '677' — reflects the neutral shift under unbalanced loading.

