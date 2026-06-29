# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:17  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -184702.4046  
**Solve time:** 0.075 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 32.268 kW |
| Total load | 11.521 kW |
| Total network losses (P) | 20.748 kW |
| Total network losses (Q) | 5.968 kW var |
| Loss fraction | 180.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 17.521 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.092 (`896`) | 5.2 % (`313`) | 17.52 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 240.2 | 251.2 | 1.044 | 1.092 | 4.8 % | 17.52 V |
| ✅ | `949` | 240.8 | 250.7 | 1.047 | 1.09 | 4.3 % | 16.71 V |
| ✅ | `677` | 240.2 | 250.7 | 1.044 | 1.09 | 4.6 % | 17.01 V |
| ✅ | `660` | 240.2 | 250.6 | 1.044 | 1.09 | 4.5 % | 16.93 V |
| ✅ | `661` | 240.2 | 250.6 | 1.044 | 1.089 | 4.5 % | 16.8 V |
| ✅ | `895` | 240.8 | 250.5 | 1.047 | 1.089 | 4.2 % | 16.45 V |
| ✅ | `654` | 240.2 | 250.5 | 1.044 | 1.089 | 4.5 % | 16.69 V |
| ✅ | `644` | 240.2 | 250.4 | 1.044 | 1.089 | 4.5 % | 16.66 V |
| ✅ | `635` | 240.2 | 250.4 | 1.044 | 1.089 | 4.4 % | 16.57 V |
| ✅ | `904` | 240.8 | 250.3 | 1.047 | 1.088 | 4.1 % | 16.31 V |
| ✅ | `775` | 240.7 | 250.2 | 1.046 | 1.088 | 4.2 % | 16.31 V |
| ✅ | `849` | 240.8 | 250.2 | 1.047 | 1.088 | 4.1 % | 16.18 V |
| ✅ | `894` | 241.0 | 250.2 | 1.048 | 1.088 | 4.0 % | 15.33 V |
| ✅ | `808` | 240.7 | 249.9 | 1.046 | 1.086 | 4.0 % | 16.22 V |
| ✅ | `693` | 240.7 | 249.8 | 1.046 | 1.086 | 4.0 % | 15.93 V |
| ✅ | `673` | 240.7 | 249.8 | 1.046 | 1.086 | 4.0 % | 15.91 V |
| ✅ | `665` | 240.7 | 249.8 | 1.046 | 1.086 | 4.0 % | 15.86 V |
| ✅ | `627` | 240.2 | 249.8 | 1.044 | 1.086 | 4.2 % | 15.87 V |
| ✅ | `779` | 240.7 | 249.8 | 1.046 | 1.086 | 4.0 % | 16.05 V |
| ✅ | `617` | 240.2 | 249.8 | 1.044 | 1.086 | 4.1 % | 15.82 V |
| ✅ | `618` | 240.2 | 249.7 | 1.044 | 1.086 | 4.1 % | 15.82 V |
| ✅ | `659` | 240.6 | 249.7 | 1.046 | 1.086 | 4.0 % | 15.8 V |
| ✅ | `608` | 240.2 | 249.7 | 1.044 | 1.086 | 4.1 % | 15.79 V |
| ✅ | `607` | 240.2 | 249.7 | 1.045 | 1.086 | 4.1 % | 15.75 V |
| ✅ | `600` | 240.2 | 249.6 | 1.045 | 1.085 | 4.1 % | 15.65 V |
| ✅ | `717` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 16.27 V |
| ✅ | `655` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 16.03 V |
| ✅ | `609` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 15.99 V |
| ✅ | `773` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 15.91 V |
| ✅ | `568` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 15.62 V |
| ✅ | `545` | 240.3 | 249.1 | 1.045 | 1.083 | 3.9 % | 15.07 V |
| ✅ | `313` | 236.9 | 248.9 | 1.03 | 1.082 | 5.2 % | 14.83 V |
| ✅ | `303` | 236.9 | 248.8 | 1.03 | 1.082 | 5.2 % | 14.76 V |
| ✅ | `290` | 236.9 | 248.8 | 1.03 | 1.082 | 5.2 % | 14.69 V |
| ✅ | `282` | 236.9 | 248.7 | 1.03 | 1.081 | 5.2 % | 14.65 V |
| ✅ | `272` | 236.9 | 248.7 | 1.03 | 1.081 | 5.1 % | 14.56 V |
| ✅ | `321` | 236.9 | 248.4 | 1.03 | 1.08 | 5.0 % | 14.27 V |
| ✅ | `264` | 236.9 | 248.3 | 1.03 | 1.08 | 5.0 % | 14.16 V |
| ✅ | `263` | 236.9 | 248.1 | 1.03 | 1.079 | 4.8 % | 13.87 V |
| ✅ | `254` | 236.9 | 248.0 | 1.03 | 1.078 | 4.8 % | 13.79 V |
| ✅ | `229` | 237.0 | 247.7 | 1.03 | 1.077 | 4.7 % | 13.43 V |
| ✅ | `216` | 237.0 | 247.6 | 1.03 | 1.077 | 4.6 % | 13.33 V |
| ✅ | `192` | 237.0 | 247.3 | 1.031 | 1.075 | 4.5 % | 12.95 V |
| ✅ | `175` | 237.0 | 247.3 | 1.031 | 1.075 | 4.5 % | 12.87 V |
| ✅ | `530` | 239.2 | 247.1 | 1.04 | 1.074 | 3.4 % | 12.49 V |
| ✅ | `166` | 237.1 | 246.7 | 1.031 | 1.073 | 4.2 % | 12.14 V |
| ✅ | `151` | 237.1 | 246.4 | 1.031 | 1.071 | 4.0 % | 11.78 V |
| ✅ | `145` | 237.1 | 246.3 | 1.031 | 1.071 | 4.0 % | 11.69 V |
| ✅ | `138` | 237.1 | 246.2 | 1.031 | 1.07 | 3.9 % | 11.56 V |
| ✅ | `144` | 237.1 | 246.1 | 1.031 | 1.07 | 3.9 % | 11.5 V |
| ✅ | `498` | 237.3 | 246.1 | 1.032 | 1.07 | 3.8 % | 7.99 V |
| ✅ | `131` | 237.1 | 246.1 | 1.031 | 1.07 | 3.9 % | 11.43 V |
| ✅ | `428` | 239.6 | 246.0 | 1.042 | 1.07 | 2.8 % | 11.13 V |
| ✅ | `416` | 239.6 | 246.0 | 1.042 | 1.07 | 2.8 % | 11.11 V |
| ✅ | `491` | 237.3 | 246.0 | 1.032 | 1.07 | 3.8 % | 7.98 V |
| ✅ | `391` | 239.5 | 246.0 | 1.041 | 1.07 | 2.8 % | 11.09 V |
| ✅ | `380` | 239.5 | 246.0 | 1.041 | 1.07 | 2.9 % | 11.09 V |
| ✅ | `392` | 239.5 | 246.0 | 1.041 | 1.07 | 2.9 % | 11.09 V |
| ✅ | `366` | 239.4 | 246.0 | 1.041 | 1.07 | 2.9 % | 11.07 V |
| ✅ | `355` | 239.3 | 246.0 | 1.041 | 1.07 | 2.9 % | 11.06 V |
| ✅ | `441` | 239.1 | 246.0 | 1.04 | 1.07 | 3.0 % | 11.03 V |
| ✅ | `348` | 239.3 | 246.0 | 1.04 | 1.07 | 2.9 % | 11.11 V |
| ✅ | `327` | 239.0 | 246.0 | 1.039 | 1.07 | 3.0 % | 11.0 V |
| ✅ | `384` | 238.9 | 246.0 | 1.039 | 1.07 | 3.1 % | 11.0 V |
| ✅ | `318` | 238.9 | 246.0 | 1.039 | 1.069 | 3.1 % | 10.98 V |
| ✅ | `300` | 238.8 | 246.0 | 1.038 | 1.069 | 3.1 % | 10.97 V |
| ✅ | `473` | 237.3 | 246.0 | 1.032 | 1.069 | 3.7 % | 7.96 V |
| ✅ | `472` | 237.3 | 245.9 | 1.032 | 1.069 | 3.7 % | 7.94 V |
| ✅ | `439` | 237.3 | 245.8 | 1.032 | 1.069 | 3.7 % | 7.93 V |
| ✅ | `536` | 237.3 | 245.7 | 1.032 | 1.068 | 3.7 % | 7.92 V |
| ✅ | `427` | 237.3 | 245.6 | 1.032 | 1.068 | 3.6 % | 7.9 V |
| ✅ | `479` | 237.3 | 245.5 | 1.032 | 1.067 | 3.5 % | 7.88 V |
| ✅ | `377` | 237.3 | 245.4 | 1.032 | 1.067 | 3.5 % | 7.87 V |
| ✅ | `116` | 237.2 | 245.4 | 1.031 | 1.067 | 3.5 % | 10.5 V |
| ✅ | `376` | 237.3 | 245.3 | 1.032 | 1.067 | 3.5 % | 7.87 V |
| ✅ | `354` | 237.3 | 245.2 | 1.032 | 1.066 | 3.4 % | 7.86 V |
| ✅ | `128` | 237.3 | 245.2 | 1.032 | 1.066 | 3.5 % | 10.3 V |
| ✅ | `104` | 237.3 | 245.0 | 1.032 | 1.065 | 3.4 % | 10.16 V |
| ✅ | `198` | 237.3 | 245.0 | 1.032 | 1.065 | 3.4 % | 10.11 V |
| ✅ | `521` | 237.3 | 244.9 | 1.032 | 1.065 | 3.3 % | 7.84 V |
| ✅ | `108` | 237.3 | 244.8 | 1.032 | 1.065 | 3.3 % | 9.94 V |
| ✅ | `307` | 237.3 | 244.8 | 1.032 | 1.064 | 3.2 % | 7.84 V |
| ✅ | `99` | 237.3 | 244.8 | 1.032 | 1.064 | 3.3 % | 9.89 V |
| ✅ | `256` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 7.86 V |
| ✅ | `247` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 7.87 V |
| ✅ | `226` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 7.95 V |
| ✅ | `220` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 7.97 V |
| ✅ | `219` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 8.15 V |
| ✅ | `208` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 8.19 V |
| ✅ | `201` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 8.64 V |
| ✅ | `188` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 8.7 V |
| ✅ | `179` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.14 V |
| ✅ | `162` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.23 V |
| ✅ | `187` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.44 V |
| ✅ | `147` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.51 V |
| ✅ | `90` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.74 V |
| ✅ | `82` | 237.3 | 244.7 | 1.032 | 1.064 | 3.2 % | 9.75 V |
| ✅ | `62` | 235.4 | 240.2 | 1.023 | 1.044 | 2.1 % | 6.64 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.276 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=5.0 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.163 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.658 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.486 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.425 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.768 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.701 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.141 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.283 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=4.166 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.625 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.384 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.815 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.202 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.976 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.893 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.339 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.22 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.526 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.198 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.298 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.328 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.557 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.713 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.909 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.844 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.505 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.909 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 180.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 17.52 V at bus '896' — reflects the neutral shift under unbalanced loading.

