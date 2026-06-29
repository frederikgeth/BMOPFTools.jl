# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:15  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -104944.0496  
**Solve time:** 0.056 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 20.965 kW |
| Total load | 15.163 kW |
| Total network losses (P) | 5.802 kW |
| Total network losses (Q) | 1.785 kW var |
| Loss fraction | 38.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 7.869 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.057 (`896`) | 3.2 % (`313`) | 7.87 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 235.8 | 243.0 | 1.025 | 1.057 | 3.1 % | 7.87 V |
| ✅ | `949` | 235.9 | 242.9 | 1.026 | 1.056 | 3.1 % | 7.6 V |
| ✅ | `895` | 235.9 | 242.7 | 1.026 | 1.055 | 3.0 % | 7.44 V |
| ✅ | `904` | 235.9 | 242.7 | 1.026 | 1.055 | 2.9 % | 7.37 V |
| ✅ | `661` | 235.8 | 242.7 | 1.025 | 1.055 | 3.0 % | 7.49 V |
| ✅ | `660` | 235.8 | 242.6 | 1.025 | 1.055 | 3.0 % | 7.51 V |
| ✅ | `677` | 235.8 | 242.6 | 1.025 | 1.055 | 3.0 % | 7.51 V |
| ✅ | `654` | 235.8 | 242.6 | 1.025 | 1.055 | 3.0 % | 7.43 V |
| ✅ | `775` | 235.9 | 242.6 | 1.026 | 1.055 | 2.9 % | 7.31 V |
| ✅ | `849` | 235.9 | 242.6 | 1.026 | 1.055 | 2.9 % | 7.3 V |
| ✅ | `894` | 236.2 | 242.6 | 1.027 | 1.055 | 2.8 % | 7.09 V |
| ✅ | `644` | 235.8 | 242.6 | 1.025 | 1.055 | 2.9 % | 7.41 V |
| ✅ | `635` | 235.8 | 242.5 | 1.025 | 1.055 | 2.9 % | 7.37 V |
| ✅ | `808` | 235.9 | 242.4 | 1.026 | 1.054 | 2.8 % | 7.18 V |
| ✅ | `693` | 235.9 | 242.3 | 1.026 | 1.054 | 2.8 % | 7.09 V |
| ✅ | `673` | 235.9 | 242.3 | 1.026 | 1.054 | 2.8 % | 7.09 V |
| ✅ | `665` | 235.9 | 242.3 | 1.026 | 1.054 | 2.8 % | 7.06 V |
| ✅ | `779` | 235.9 | 242.3 | 1.026 | 1.053 | 2.8 % | 7.13 V |
| ✅ | `659` | 235.9 | 242.3 | 1.026 | 1.053 | 2.8 % | 7.02 V |
| ✅ | `627` | 235.8 | 242.3 | 1.025 | 1.053 | 2.8 % | 7.04 V |
| ✅ | `617` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 7.03 V |
| ✅ | `618` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 7.03 V |
| ✅ | `608` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 7.01 V |
| ✅ | `607` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 6.98 V |
| ✅ | `717` | 235.9 | 242.2 | 1.026 | 1.053 | 2.7 % | 7.22 V |
| ✅ | `655` | 235.9 | 242.2 | 1.026 | 1.053 | 2.7 % | 7.09 V |
| ✅ | `609` | 235.9 | 242.2 | 1.026 | 1.053 | 2.7 % | 7.08 V |
| ✅ | `773` | 235.9 | 242.2 | 1.026 | 1.053 | 2.7 % | 7.02 V |
| ✅ | `568` | 235.9 | 242.2 | 1.026 | 1.053 | 2.7 % | 6.92 V |
| ✅ | `600` | 235.8 | 242.2 | 1.025 | 1.053 | 2.8 % | 6.93 V |
| ✅ | `545` | 235.8 | 241.9 | 1.025 | 1.052 | 2.6 % | 6.64 V |
| ✅ | `313` | 234.2 | 241.5 | 1.018 | 1.05 | 3.2 % | 6.78 V |
| ✅ | `303` | 234.2 | 241.5 | 1.018 | 1.05 | 3.1 % | 6.74 V |
| ✅ | `290` | 234.3 | 241.4 | 1.018 | 1.05 | 3.1 % | 6.7 V |
| ✅ | `282` | 234.3 | 241.4 | 1.018 | 1.05 | 3.1 % | 6.67 V |
| ✅ | `272` | 234.3 | 241.4 | 1.019 | 1.049 | 3.1 % | 6.63 V |
| ✅ | `321` | 234.3 | 241.2 | 1.019 | 1.049 | 3.0 % | 6.48 V |
| ✅ | `264` | 234.3 | 241.2 | 1.019 | 1.049 | 3.0 % | 6.42 V |
| ✅ | `263` | 234.3 | 241.0 | 1.019 | 1.048 | 2.9 % | 6.26 V |
| ✅ | `254` | 234.3 | 241.0 | 1.019 | 1.048 | 2.9 % | 6.23 V |
| ✅ | `229` | 234.3 | 240.8 | 1.019 | 1.047 | 2.8 % | 6.04 V |
| ✅ | `216` | 234.3 | 240.8 | 1.019 | 1.047 | 2.8 % | 5.99 V |
| ✅ | `530` | 235.6 | 240.6 | 1.024 | 1.046 | 2.2 % | 5.33 V |
| ✅ | `192` | 234.3 | 240.6 | 1.019 | 1.046 | 2.7 % | 5.8 V |
| ✅ | `175` | 234.3 | 240.5 | 1.019 | 1.046 | 2.7 % | 5.76 V |
| ✅ | `166` | 234.4 | 240.2 | 1.019 | 1.045 | 2.6 % | 5.4 V |
| ✅ | `151` | 234.4 | 240.0 | 1.019 | 1.044 | 2.5 % | 5.2 V |
| ✅ | `145` | 234.4 | 240.0 | 1.019 | 1.043 | 2.4 % | 5.16 V |
| ✅ | `428` | 235.9 | 239.9 | 1.026 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `416` | 235.8 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `391` | 235.8 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `392` | 235.8 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `380` | 235.8 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `138` | 234.4 | 239.9 | 1.019 | 1.043 | 2.4 % | 5.09 V |
| ✅ | `366` | 235.7 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.53 V |
| ✅ | `355` | 235.7 | 239.9 | 1.025 | 1.043 | 1.8 % | 4.54 V |
| ✅ | `441` | 235.6 | 239.9 | 1.024 | 1.043 | 1.9 % | 4.54 V |
| ✅ | `327` | 235.5 | 239.9 | 1.024 | 1.043 | 1.9 % | 4.55 V |
| ✅ | `348` | 235.6 | 239.9 | 1.024 | 1.043 | 1.9 % | 4.56 V |
| ✅ | `384` | 235.4 | 239.9 | 1.024 | 1.043 | 1.9 % | 4.55 V |
| ✅ | `318` | 235.4 | 239.9 | 1.023 | 1.043 | 2.0 % | 4.55 V |
| ✅ | `144` | 234.4 | 239.9 | 1.019 | 1.043 | 2.4 % | 5.06 V |
| ✅ | `300` | 235.3 | 239.9 | 1.023 | 1.043 | 2.0 % | 4.56 V |
| ✅ | `131` | 234.4 | 239.9 | 1.019 | 1.043 | 2.4 % | 5.02 V |
| ✅ | `498` | 234.5 | 239.5 | 1.019 | 1.041 | 2.2 % | 3.93 V |
| ✅ | `491` | 234.5 | 239.5 | 1.019 | 1.041 | 2.2 % | 3.91 V |
| ✅ | `116` | 234.4 | 239.4 | 1.019 | 1.041 | 2.2 % | 4.56 V |
| ✅ | `473` | 234.5 | 239.4 | 1.019 | 1.041 | 2.1 % | 3.88 V |
| ✅ | `472` | 234.5 | 239.4 | 1.019 | 1.041 | 2.1 % | 3.86 V |
| ✅ | `128` | 234.4 | 239.4 | 1.019 | 1.041 | 2.1 % | 4.46 V |
| ✅ | `439` | 234.5 | 239.3 | 1.019 | 1.041 | 2.1 % | 3.84 V |
| ✅ | `536` | 234.5 | 239.3 | 1.019 | 1.04 | 2.1 % | 3.82 V |
| ✅ | `198` | 234.4 | 239.3 | 1.019 | 1.04 | 2.1 % | 4.37 V |
| ✅ | `104` | 234.4 | 239.3 | 1.019 | 1.04 | 2.1 % | 4.37 V |
| ✅ | `427` | 234.5 | 239.2 | 1.019 | 1.04 | 2.1 % | 3.8 V |
| ✅ | `108` | 234.4 | 239.2 | 1.019 | 1.04 | 2.1 % | 4.27 V |
| ✅ | `99` | 234.4 | 239.1 | 1.019 | 1.04 | 2.0 % | 4.24 V |
| ✅ | `479` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.76 V |
| ✅ | `377` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.74 V |
| ✅ | `376` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.73 V |
| ✅ | `354` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.71 V |
| ✅ | `521` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.64 V |
| ✅ | `307` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.63 V |
| ✅ | `256` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.58 V |
| ✅ | `247` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.57 V |
| ✅ | `226` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.53 V |
| ✅ | `220` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.53 V |
| ✅ | `219` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.54 V |
| ✅ | `208` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.55 V |
| ✅ | `201` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.68 V |
| ✅ | `188` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.71 V |
| ✅ | `179` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.91 V |
| ✅ | `162` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 3.93 V |
| ✅ | `187` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 4.04 V |
| ✅ | `147` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 4.06 V |
| ✅ | `90` | 234.5 | 239.1 | 1.019 | 1.04 | 2.0 % | 4.15 V |
| ✅ | `82` | 234.4 | 239.1 | 1.019 | 1.039 | 2.0 % | 4.16 V |
| ✅ | `62` | 233.2 | 236.2 | 1.014 | 1.027 | 1.3 % | 2.82 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=2.391 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=2.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=2.786 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=2.825 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=2.672 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=2.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=2.835 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=2.424 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=2.451 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=2.531 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=2.718 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=2.561 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=2.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=2.753 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.473 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=2.39 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=2.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=2.49 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=2.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.436 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=2.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=2.766 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=2.61 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=2.59 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=2.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.821 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=2.403 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=2.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=2.763 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=2.426 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=2.796 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=2.78 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=2.407 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=2.67 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=2.555 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=2.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=2.689 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=2.469 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=2.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=2.809 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=2.499 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=2.414 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=2.722 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 38.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 7.87 V at bus '896' — reflects the neutral shift under unbalanced loading.

