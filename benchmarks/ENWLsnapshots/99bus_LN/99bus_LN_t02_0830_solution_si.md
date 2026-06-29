# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:22  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -4837.907  
**Solve time:** 0.063 s  
**Findings:** 0 errors · 48 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 28.102 kW |
| Total load | 27.908 kW |
| Total network losses (P) | 193.36 W |
| Total network losses (Q) | 47.25 W var |
| Loss fraction | 0.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 2.381 V (bus `894`) |

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
| ✅ | `104` | 230.0 V | 99 | 0.995 (`894`) | 1.005 (`498`) | 0.8 % (`894`) | 2.38 V (`894`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `894` | 228.8 | 230.6 | 0.995 | 1.003 | 0.8 % | 2.38 V |
| ✅ | `677` | 228.8 | 230.6 | 0.995 | 1.003 | 0.8 % | 2.24 V |
| ✅ | `498` | 229.8 | 231.1 | 0.999 | 1.005 | 0.6 % | 0.56 V |
| ✅ | `491` | 229.8 | 231.1 | 0.999 | 1.005 | 0.6 % | 0.56 V |
| ✅ | `473` | 229.8 | 231.1 | 0.999 | 1.005 | 0.6 % | 0.56 V |
| ✅ | `472` | 229.8 | 231.0 | 0.999 | 1.005 | 0.6 % | 0.55 V |
| ✅ | `439` | 229.8 | 231.0 | 0.999 | 1.004 | 0.6 % | 0.55 V |
| ✅ | `660` | 229.0 | 230.6 | 0.996 | 1.003 | 0.7 % | 2.14 V |
| ✅ | `536` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.54 V |
| ✅ | `427` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.54 V |
| ✅ | `479` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.53 V |
| ✅ | `377` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.52 V |
| ✅ | `376` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.52 V |
| ✅ | `354` | 229.8 | 231.0 | 0.999 | 1.004 | 0.5 % | 0.52 V |
| ✅ | `896` | 229.1 | 230.6 | 0.996 | 1.003 | 0.7 % | 2.11 V |
| ✅ | `521` | 229.8 | 230.9 | 0.999 | 1.004 | 0.5 % | 0.51 V |
| ✅ | `307` | 229.8 | 230.9 | 0.999 | 1.004 | 0.5 % | 0.5 V |
| ✅ | `644` | 229.1 | 230.6 | 0.996 | 1.003 | 0.6 % | 2.0 V |
| ✅ | `717` | 229.5 | 230.8 | 0.998 | 1.004 | 0.6 % | 1.97 V |
| ✅ | `661` | 229.2 | 230.6 | 0.996 | 1.003 | 0.6 % | 1.99 V |
| ✅ | `256` | 229.8 | 230.8 | 0.999 | 1.004 | 0.5 % | 0.5 V |
| ✅ | `247` | 229.8 | 230.8 | 0.999 | 1.004 | 0.5 % | 0.5 V |
| ✅ | `635` | 229.2 | 230.6 | 0.996 | 1.003 | 0.6 % | 1.97 V |
| ✅ | `654` | 229.2 | 230.6 | 0.996 | 1.003 | 0.6 % | 1.97 V |
| ✅ | `655` | 229.5 | 230.8 | 0.998 | 1.003 | 0.5 % | 1.91 V |
| ✅ | `609` | 229.5 | 230.8 | 0.998 | 1.003 | 0.5 % | 1.89 V |
| ✅ | `226` | 229.8 | 230.8 | 0.999 | 1.003 | 0.4 % | 0.5 V |
| ✅ | `220` | 229.8 | 230.7 | 0.999 | 1.003 | 0.4 % | 0.51 V |
| ✅ | `773` | 229.5 | 230.7 | 0.998 | 1.003 | 0.5 % | 1.86 V |
| ✅ | `779` | 229.5 | 230.7 | 0.998 | 1.003 | 0.5 % | 1.88 V |
| ✅ | `568` | 229.5 | 230.7 | 0.998 | 1.003 | 0.5 % | 1.78 V |
| ✅ | `659` | 229.5 | 230.7 | 0.998 | 1.003 | 0.5 % | 1.8 V |
| ✅ | `219` | 229.8 | 230.7 | 0.999 | 1.003 | 0.4 % | 0.53 V |
| ✅ | `665` | 229.6 | 230.7 | 0.998 | 1.003 | 0.5 % | 1.81 V |
| ✅ | `849` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.89 V |
| ✅ | `895` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.89 V |
| ✅ | `904` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.89 V |
| ✅ | `673` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.8 V |
| ✅ | `949` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.88 V |
| ✅ | `208` | 229.8 | 230.6 | 0.999 | 1.003 | 0.4 % | 0.54 V |
| ✅ | `775` | 229.6 | 230.6 | 0.998 | 1.003 | 0.4 % | 1.78 V |
| ✅ | `607` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.79 V |
| ✅ | `618` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.79 V |
| ✅ | `693` | 229.6 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.79 V |
| ✅ | `627` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.79 V |
| ✅ | `608` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.78 V |
| ✅ | `617` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.78 V |
| ✅ | `600` | 229.4 | 230.6 | 0.997 | 1.003 | 0.5 % | 1.77 V |
| ✅ | `545` | 229.5 | 230.6 | 0.998 | 1.003 | 0.5 % | 1.69 V |
| ✅ | `808` | 229.6 | 230.6 | 0.998 | 1.002 | 0.4 % | 1.7 V |
| ✅ | `530` | 229.6 | 230.5 | 0.998 | 1.002 | 0.4 % | 1.31 V |
| ✅ | `428` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.11 V |
| ✅ | `392` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.11 V |
| ✅ | `380` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.11 V |
| ✅ | `201` | 229.8 | 230.5 | 0.999 | 1.002 | 0.3 % | 0.61 V |
| ✅ | `366` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.09 V |
| ✅ | `188` | 229.8 | 230.5 | 0.999 | 1.002 | 0.3 % | 0.62 V |
| ✅ | `391` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.09 V |
| ✅ | `355` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.09 V |
| ✅ | `441` | 229.7 | 230.5 | 0.999 | 1.002 | 0.4 % | 1.08 V |
| ✅ | `416` | 229.7 | 230.5 | 0.999 | 1.002 | 0.3 % | 1.08 V |
| ✅ | `327` | 229.7 | 230.5 | 0.999 | 1.002 | 0.3 % | 1.07 V |
| ✅ | `384` | 229.7 | 230.5 | 0.999 | 1.002 | 0.3 % | 1.06 V |
| ✅ | `318` | 229.7 | 230.5 | 0.999 | 1.002 | 0.3 % | 1.06 V |
| ✅ | `300` | 229.7 | 230.5 | 0.999 | 1.002 | 0.3 % | 1.06 V |
| ✅ | `348` | 229.7 | 230.4 | 0.999 | 1.002 | 0.3 % | 1.02 V |
| ✅ | `187` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.76 V |
| ✅ | `147` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.75 V |
| ✅ | `90` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.79 V |
| ✅ | `162` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.7 V |
| ✅ | `179` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.7 V |
| ✅ | `82` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.79 V |
| ✅ | `99` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.79 V |
| ✅ | `108` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.79 V |
| ✅ | `116` | 229.7 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.85 V |
| ✅ | `104` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.8 V |
| ✅ | `128` | 229.8 | 230.4 | 0.999 | 1.002 | 0.2 % | 0.77 V |
| ✅ | `198` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.78 V |
| ✅ | `144` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.86 V |
| ✅ | `131` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.85 V |
| ✅ | `138` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.85 V |
| ✅ | `145` | 229.8 | 230.4 | 0.999 | 1.002 | 0.3 % | 0.85 V |
| ✅ | `151` | 229.8 | 230.4 | 0.999 | 1.002 | 0.2 % | 0.85 V |
| ✅ | `166` | 229.9 | 230.4 | 0.999 | 1.002 | 0.2 % | 0.84 V |
| ✅ | `192` | 229.8 | 230.4 | 0.999 | 1.002 | 0.2 % | 0.89 V |
| ✅ | `175` | 229.9 | 230.4 | 0.999 | 1.002 | 0.2 % | 0.88 V |
| ✅ | `216` | 229.9 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.88 V |
| ✅ | `229` | 229.9 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.88 V |
| ✅ | `263` | 229.9 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.9 V |
| ✅ | `254` | 229.9 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.89 V |
| ✅ | `264` | 230.0 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.9 V |
| ✅ | `321` | 230.0 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.9 V |
| ✅ | `272` | 230.0 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.91 V |
| ✅ | `282` | 230.0 | 230.4 | 1.0 | 1.002 | 0.2 % | 0.91 V |
| ✅ | `290` | 230.0 | 230.4 | 1.0 | 1.002 | 0.1 % | 0.91 V |
| ✅ | `303` | 230.0 | 230.4 | 1.0 | 1.002 | 0.1 % | 0.91 V |
| ✅ | `313` | 230.0 | 230.4 | 1.0 | 1.002 | 0.1 % | 0.91 V |
| ✅ | `62` | 229.9 | 230.3 | 0.999 | 1.001 | 0.2 % | 0.55 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=653.91 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=710.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=630.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=666.92 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=624.01 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=652.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=721.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=737.45 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=624.13 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=628.28 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=633.31 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=627.82 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=747.83 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=702.0 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=681.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=727.16 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=624.38 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=676.07 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=753.51 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=691.77 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=697.03 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=709.46 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=729.99 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=739.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=630.83 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=737.1 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=649.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=710.67 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=725.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=739.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=718.54 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=668.41 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=638.62 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=739.79 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=733.39 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=636.01 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=645.58 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=728.59 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=627.4 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=722.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=697.62 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=736.51 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=647.8 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=678.96 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=630.17 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=749.95 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=632.72 W is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=722.11 W is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 2.38 V at bus '894' — reflects the neutral shift under unbalanced loading.

