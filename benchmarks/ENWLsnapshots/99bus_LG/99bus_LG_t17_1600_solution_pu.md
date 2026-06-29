# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:19  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -174376.3215  
**Solve time:** 0.049 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 41.863 kW |
| Total load | 23.59 kW |
| Total network losses (P) | 18.273 kW |
| Total network losses (Q) | 5.337 kW var |
| Loss fraction | 77.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.773 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.085 (`896`) | 4.7 % (`313`) | 15.77 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.9 | 249.6 | 1.043 | 1.085 | 4.2 % | 15.77 V |
| ✅ | `949` | 240.1 | 249.3 | 1.044 | 1.084 | 4.0 % | 15.24 V |
| ✅ | `895` | 240.1 | 249.1 | 1.044 | 1.083 | 3.9 % | 14.98 V |
| ✅ | `661` | 239.9 | 249.0 | 1.043 | 1.083 | 4.0 % | 15.13 V |
| ✅ | `660` | 239.9 | 249.0 | 1.043 | 1.083 | 4.0 % | 15.21 V |
| ✅ | `677` | 239.9 | 249.0 | 1.043 | 1.083 | 4.0 % | 15.25 V |
| ✅ | `654` | 239.9 | 248.9 | 1.043 | 1.082 | 3.9 % | 15.01 V |
| ✅ | `904` | 240.1 | 248.9 | 1.044 | 1.082 | 3.8 % | 14.86 V |
| ✅ | `644` | 239.9 | 248.9 | 1.043 | 1.082 | 3.9 % | 14.98 V |
| ✅ | `775` | 240.0 | 248.9 | 1.044 | 1.082 | 3.9 % | 14.82 V |
| ✅ | `635` | 239.9 | 248.9 | 1.043 | 1.082 | 3.9 % | 14.91 V |
| ✅ | `849` | 240.1 | 248.8 | 1.044 | 1.082 | 3.8 % | 14.74 V |
| ✅ | `894` | 240.6 | 248.8 | 1.046 | 1.082 | 3.6 % | 14.25 V |
| ✅ | `808` | 240.1 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.72 V |
| ✅ | `693` | 240.0 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.44 V |
| ✅ | `673` | 240.0 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.43 V |
| ✅ | `665` | 240.0 | 248.4 | 1.044 | 1.08 | 3.7 % | 14.38 V |
| ✅ | `779` | 240.0 | 248.4 | 1.044 | 1.08 | 3.6 % | 14.6 V |
| ✅ | `627` | 239.9 | 248.4 | 1.043 | 1.08 | 3.7 % | 14.3 V |
| ✅ | `659` | 240.0 | 248.4 | 1.044 | 1.08 | 3.6 % | 14.32 V |
| ✅ | `617` | 239.9 | 248.4 | 1.043 | 1.08 | 3.7 % | 14.27 V |
| ✅ | `618` | 239.9 | 248.4 | 1.043 | 1.08 | 3.7 % | 14.27 V |
| ✅ | `608` | 239.9 | 248.3 | 1.043 | 1.08 | 3.7 % | 14.24 V |
| ✅ | `607` | 239.9 | 248.3 | 1.043 | 1.08 | 3.6 % | 14.18 V |
| ✅ | `717` | 240.0 | 248.2 | 1.044 | 1.079 | 3.6 % | 14.74 V |
| ✅ | `655` | 240.0 | 248.2 | 1.044 | 1.079 | 3.6 % | 14.54 V |
| ✅ | `609` | 240.0 | 248.2 | 1.044 | 1.079 | 3.6 % | 14.49 V |
| ✅ | `773` | 240.0 | 248.2 | 1.044 | 1.079 | 3.6 % | 14.37 V |
| ✅ | `600` | 239.9 | 248.2 | 1.043 | 1.079 | 3.6 % | 14.09 V |
| ✅ | `568` | 240.0 | 248.2 | 1.043 | 1.079 | 3.6 % | 14.12 V |
| ✅ | `545` | 239.9 | 247.8 | 1.043 | 1.077 | 3.4 % | 13.56 V |
| ✅ | `313` | 236.7 | 247.5 | 1.029 | 1.076 | 4.7 % | 13.19 V |
| ✅ | `303` | 236.7 | 247.4 | 1.029 | 1.076 | 4.7 % | 13.1 V |
| ✅ | `290` | 236.7 | 247.3 | 1.029 | 1.075 | 4.6 % | 13.03 V |
| ✅ | `282` | 236.7 | 247.3 | 1.029 | 1.075 | 4.6 % | 13.0 V |
| ✅ | `272` | 236.7 | 247.2 | 1.029 | 1.075 | 4.6 % | 12.91 V |
| ✅ | `321` | 236.7 | 247.0 | 1.029 | 1.074 | 4.5 % | 12.63 V |
| ✅ | `264` | 236.7 | 246.9 | 1.029 | 1.073 | 4.4 % | 12.52 V |
| ✅ | `263` | 236.7 | 246.6 | 1.029 | 1.072 | 4.3 % | 12.22 V |
| ✅ | `254` | 236.7 | 246.6 | 1.029 | 1.072 | 4.3 % | 12.16 V |
| ✅ | `229` | 236.8 | 246.3 | 1.029 | 1.071 | 4.1 % | 11.81 V |
| ✅ | `216` | 236.8 | 246.2 | 1.029 | 1.071 | 4.1 % | 11.73 V |
| ✅ | `192` | 236.8 | 245.9 | 1.03 | 1.069 | 4.0 % | 11.38 V |
| ✅ | `175` | 236.8 | 245.9 | 1.03 | 1.069 | 3.9 % | 11.31 V |
| ✅ | `530` | 238.9 | 245.9 | 1.039 | 1.069 | 3.0 % | 11.08 V |
| ✅ | `498` | 237.1 | 245.8 | 1.031 | 1.069 | 3.8 % | 7.37 V |
| ✅ | `491` | 237.1 | 245.7 | 1.031 | 1.068 | 3.7 % | 7.34 V |
| ✅ | `473` | 237.1 | 245.6 | 1.031 | 1.068 | 3.7 % | 7.31 V |
| ✅ | `472` | 237.1 | 245.6 | 1.031 | 1.068 | 3.7 % | 7.29 V |
| ✅ | `439` | 237.1 | 245.5 | 1.031 | 1.067 | 3.6 % | 7.26 V |
| ✅ | `166` | 236.9 | 245.4 | 1.03 | 1.067 | 3.7 % | 10.7 V |
| ✅ | `536` | 237.1 | 245.4 | 1.031 | 1.067 | 3.6 % | 7.24 V |
| ✅ | `427` | 237.1 | 245.3 | 1.031 | 1.067 | 3.6 % | 7.2 V |
| ✅ | `479` | 237.1 | 245.1 | 1.031 | 1.066 | 3.5 % | 7.15 V |
| ✅ | `151` | 236.9 | 245.1 | 1.03 | 1.066 | 3.6 % | 10.35 V |
| ✅ | `377` | 237.1 | 245.0 | 1.031 | 1.065 | 3.5 % | 7.13 V |
| ✅ | `145` | 236.9 | 245.0 | 1.03 | 1.065 | 3.5 % | 10.26 V |
| ✅ | `376` | 237.1 | 245.0 | 1.031 | 1.065 | 3.4 % | 7.12 V |
| ✅ | `138` | 236.9 | 244.9 | 1.03 | 1.065 | 3.5 % | 10.14 V |
| ✅ | `354` | 237.1 | 244.9 | 1.031 | 1.065 | 3.4 % | 7.1 V |
| ✅ | `144` | 236.9 | 244.9 | 1.03 | 1.065 | 3.5 % | 10.09 V |
| ✅ | `428` | 239.3 | 244.9 | 1.04 | 1.065 | 2.4 % | 9.76 V |
| ✅ | `416` | 239.2 | 244.9 | 1.04 | 1.065 | 2.4 % | 9.74 V |
| ✅ | `391` | 239.2 | 244.9 | 1.04 | 1.065 | 2.5 % | 9.73 V |
| ✅ | `380` | 239.1 | 244.9 | 1.04 | 1.065 | 2.5 % | 9.73 V |
| ✅ | `392` | 239.1 | 244.9 | 1.04 | 1.065 | 2.5 % | 9.73 V |
| ✅ | `366` | 239.0 | 244.9 | 1.039 | 1.065 | 2.5 % | 9.71 V |
| ✅ | `355` | 239.0 | 244.8 | 1.039 | 1.065 | 2.5 % | 9.7 V |
| ✅ | `441` | 238.8 | 244.8 | 1.038 | 1.064 | 2.6 % | 9.68 V |
| ✅ | `131` | 236.9 | 244.8 | 1.03 | 1.064 | 3.4 % | 10.02 V |
| ✅ | `327` | 238.7 | 244.8 | 1.038 | 1.064 | 2.7 % | 9.65 V |
| ✅ | `348` | 238.9 | 244.8 | 1.039 | 1.064 | 2.6 % | 9.73 V |
| ✅ | `384` | 238.6 | 244.8 | 1.037 | 1.064 | 2.7 % | 9.64 V |
| ✅ | `318` | 238.6 | 244.8 | 1.037 | 1.064 | 2.7 % | 9.64 V |
| ✅ | `300` | 238.5 | 244.8 | 1.037 | 1.064 | 2.8 % | 9.63 V |
| ✅ | `521` | 237.1 | 244.6 | 1.031 | 1.063 | 3.2 % | 7.03 V |
| ✅ | `307` | 237.1 | 244.5 | 1.031 | 1.063 | 3.2 % | 7.02 V |
| ✅ | `116` | 237.0 | 244.1 | 1.03 | 1.062 | 3.1 % | 9.16 V |
| ✅ | `128` | 237.0 | 244.1 | 1.031 | 1.061 | 3.1 % | 9.06 V |
| ✅ | `256` | 237.1 | 244.1 | 1.031 | 1.061 | 3.0 % | 6.97 V |
| ✅ | `247` | 237.1 | 244.0 | 1.031 | 1.061 | 3.0 % | 6.97 V |
| ✅ | `198` | 237.0 | 243.9 | 1.031 | 1.06 | 3.0 % | 8.87 V |
| ✅ | `104` | 237.0 | 243.9 | 1.031 | 1.06 | 3.0 % | 8.89 V |
| ✅ | `108` | 237.0 | 243.7 | 1.031 | 1.06 | 2.9 % | 8.7 V |
| ✅ | `99` | 237.0 | 243.7 | 1.031 | 1.06 | 2.9 % | 8.65 V |
| ✅ | `226` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.99 V |
| ✅ | `220` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.0 V |
| ✅ | `219` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.1 V |
| ✅ | `208` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.13 V |
| ✅ | `201` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.49 V |
| ✅ | `188` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.55 V |
| ✅ | `179` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.97 V |
| ✅ | `162` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.04 V |
| ✅ | `187` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.26 V |
| ✅ | `147` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.31 V |
| ✅ | `90` | 237.1 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.52 V |
| ✅ | `82` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.52 V |
| ✅ | `62` | 235.2 | 239.4 | 1.023 | 1.041 | 1.8 % | 5.79 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.302 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.141 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.658 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.526 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.976 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.972 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.78 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.557 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.198 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=4.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.768 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.779 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.138 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.276 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.696 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.298 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.328 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.339 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.22 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.384 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.0 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.714 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.1 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.166 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.701 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.522 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.387 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.202 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.486 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 77.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.77 V at bus '896' — reflects the neutral shift under unbalanced loading.

