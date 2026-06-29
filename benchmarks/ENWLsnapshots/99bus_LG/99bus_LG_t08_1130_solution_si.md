# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:16  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -170655.8733  
**Solve time:** 0.065 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 28.3 kW |
| Total load | 11.225 kW |
| Total network losses (P) | 17.075 kW |
| Total network losses (Q) | 4.951 kW var |
| Loss fraction | 152.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.62 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.086 (`896`) | 4.6 % (`313`) | 15.62 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.7 | 249.9 | 1.042 | 1.086 | 4.4 % | 15.62 V |
| ✅ | `949` | 240.1 | 249.4 | 1.044 | 1.084 | 4.0 % | 14.8 V |
| ✅ | `677` | 239.7 | 249.3 | 1.042 | 1.084 | 4.2 % | 15.08 V |
| ✅ | `660` | 239.7 | 249.3 | 1.042 | 1.084 | 4.2 % | 15.01 V |
| ✅ | `661` | 239.7 | 249.2 | 1.042 | 1.083 | 4.1 % | 14.88 V |
| ✅ | `654` | 239.7 | 249.1 | 1.042 | 1.083 | 4.1 % | 14.77 V |
| ✅ | `644` | 239.7 | 249.1 | 1.042 | 1.083 | 4.1 % | 14.75 V |
| ✅ | `895` | 240.1 | 249.1 | 1.044 | 1.083 | 3.9 % | 14.52 V |
| ✅ | `635` | 239.7 | 249.0 | 1.042 | 1.083 | 4.1 % | 14.67 V |
| ✅ | `904` | 240.1 | 249.0 | 1.044 | 1.082 | 3.8 % | 14.4 V |
| ✅ | `849` | 240.1 | 248.8 | 1.044 | 1.082 | 3.8 % | 14.27 V |
| ✅ | `894` | 240.5 | 248.8 | 1.046 | 1.082 | 3.6 % | 13.45 V |
| ✅ | `775` | 240.0 | 248.8 | 1.043 | 1.082 | 3.8 % | 14.35 V |
| ✅ | `808` | 240.0 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.34 V |
| ✅ | `693` | 240.0 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.03 V |
| ✅ | `673` | 240.0 | 248.5 | 1.044 | 1.08 | 3.7 % | 14.02 V |
| ✅ | `627` | 239.7 | 248.5 | 1.042 | 1.08 | 3.8 % | 14.01 V |
| ✅ | `665` | 240.0 | 248.4 | 1.044 | 1.08 | 3.7 % | 13.97 V |
| ✅ | `617` | 239.7 | 248.4 | 1.042 | 1.08 | 3.8 % | 13.95 V |
| ✅ | `618` | 239.7 | 248.4 | 1.042 | 1.08 | 3.8 % | 13.95 V |
| ✅ | `779` | 240.0 | 248.4 | 1.043 | 1.08 | 3.6 % | 14.15 V |
| ✅ | `659` | 240.0 | 248.4 | 1.043 | 1.08 | 3.6 % | 13.92 V |
| ✅ | `608` | 239.7 | 248.4 | 1.042 | 1.08 | 3.8 % | 13.93 V |
| ✅ | `607` | 239.7 | 248.4 | 1.042 | 1.08 | 3.8 % | 13.89 V |
| ✅ | `600` | 239.7 | 248.3 | 1.042 | 1.079 | 3.7 % | 13.79 V |
| ✅ | `717` | 240.0 | 248.3 | 1.043 | 1.079 | 3.6 % | 14.33 V |
| ✅ | `655` | 240.0 | 248.3 | 1.043 | 1.079 | 3.6 % | 14.15 V |
| ✅ | `609` | 240.0 | 248.2 | 1.043 | 1.079 | 3.6 % | 14.1 V |
| ✅ | `773` | 240.0 | 248.2 | 1.043 | 1.079 | 3.6 % | 14.01 V |
| ✅ | `568` | 240.0 | 248.2 | 1.043 | 1.079 | 3.6 % | 13.75 V |
| ✅ | `545` | 239.8 | 247.8 | 1.042 | 1.077 | 3.5 % | 13.26 V |
| ✅ | `313` | 236.6 | 247.2 | 1.029 | 1.075 | 4.6 % | 12.65 V |
| ✅ | `303` | 236.6 | 247.1 | 1.029 | 1.074 | 4.6 % | 12.59 V |
| ✅ | `290` | 236.6 | 247.0 | 1.029 | 1.074 | 4.5 % | 12.52 V |
| ✅ | `282` | 236.6 | 247.0 | 1.029 | 1.074 | 4.5 % | 12.48 V |
| ✅ | `272` | 236.6 | 246.9 | 1.029 | 1.074 | 4.5 % | 12.41 V |
| ✅ | `321` | 236.7 | 246.7 | 1.029 | 1.073 | 4.4 % | 12.16 V |
| ✅ | `264` | 236.7 | 246.7 | 1.029 | 1.072 | 4.3 % | 12.06 V |
| ✅ | `263` | 236.7 | 246.4 | 1.029 | 1.071 | 4.2 % | 11.8 V |
| ✅ | `254` | 236.7 | 246.4 | 1.029 | 1.071 | 4.2 % | 11.73 V |
| ✅ | `229` | 236.7 | 246.1 | 1.029 | 1.07 | 4.1 % | 11.42 V |
| ✅ | `216` | 236.7 | 246.1 | 1.029 | 1.07 | 4.1 % | 11.34 V |
| ✅ | `530` | 238.8 | 245.9 | 1.038 | 1.069 | 3.1 % | 10.87 V |
| ✅ | `192` | 236.8 | 245.8 | 1.029 | 1.069 | 3.9 % | 11.02 V |
| ✅ | `175` | 236.8 | 245.7 | 1.029 | 1.068 | 3.9 % | 10.95 V |
| ✅ | `166` | 236.8 | 245.3 | 1.03 | 1.067 | 3.7 % | 10.37 V |
| ✅ | `498` | 237.0 | 245.1 | 1.031 | 1.066 | 3.5 % | 6.84 V |
| ✅ | `491` | 237.0 | 245.1 | 1.031 | 1.065 | 3.5 % | 6.82 V |
| ✅ | `473` | 237.0 | 245.0 | 1.031 | 1.065 | 3.5 % | 6.8 V |
| ✅ | `151` | 236.8 | 245.0 | 1.03 | 1.065 | 3.5 % | 10.04 V |
| ✅ | `145` | 236.8 | 244.9 | 1.03 | 1.065 | 3.5 % | 9.97 V |
| ✅ | `472` | 237.0 | 244.9 | 1.031 | 1.065 | 3.4 % | 6.78 V |
| ✅ | `428` | 239.2 | 244.8 | 1.04 | 1.065 | 2.4 % | 9.6 V |
| ✅ | `416` | 239.2 | 244.8 | 1.04 | 1.065 | 2.5 % | 9.58 V |
| ✅ | `439` | 237.0 | 244.8 | 1.031 | 1.064 | 3.4 % | 6.76 V |
| ✅ | `391` | 239.1 | 244.8 | 1.039 | 1.064 | 2.5 % | 9.56 V |
| ✅ | `392` | 239.0 | 244.8 | 1.039 | 1.064 | 2.5 % | 9.56 V |
| ✅ | `380` | 239.0 | 244.8 | 1.039 | 1.064 | 2.5 % | 9.56 V |
| ✅ | `366` | 239.0 | 244.8 | 1.039 | 1.064 | 2.6 % | 9.54 V |
| ✅ | `138` | 236.9 | 244.8 | 1.03 | 1.064 | 3.5 % | 9.85 V |
| ✅ | `355` | 238.9 | 244.8 | 1.039 | 1.064 | 2.6 % | 9.53 V |
| ✅ | `441` | 238.7 | 244.8 | 1.038 | 1.064 | 2.6 % | 9.5 V |
| ✅ | `348` | 238.9 | 244.8 | 1.039 | 1.064 | 2.5 % | 9.6 V |
| ✅ | `327` | 238.6 | 244.8 | 1.037 | 1.064 | 2.7 % | 9.48 V |
| ✅ | `384` | 238.5 | 244.8 | 1.037 | 1.064 | 2.7 % | 9.47 V |
| ✅ | `318` | 238.5 | 244.8 | 1.037 | 1.064 | 2.7 % | 9.46 V |
| ✅ | `536` | 237.0 | 244.8 | 1.031 | 1.064 | 3.4 % | 6.74 V |
| ✅ | `144` | 236.9 | 244.8 | 1.03 | 1.064 | 3.4 % | 9.81 V |
| ✅ | `300` | 238.4 | 244.8 | 1.036 | 1.064 | 2.8 % | 9.44 V |
| ✅ | `131` | 236.9 | 244.7 | 1.03 | 1.064 | 3.4 % | 9.74 V |
| ✅ | `427` | 237.0 | 244.7 | 1.031 | 1.064 | 3.3 % | 6.72 V |
| ✅ | `479` | 237.0 | 244.5 | 1.031 | 1.063 | 3.3 % | 6.69 V |
| ✅ | `377` | 237.0 | 244.4 | 1.031 | 1.063 | 3.2 % | 6.68 V |
| ✅ | `376` | 237.0 | 244.4 | 1.031 | 1.063 | 3.2 % | 6.67 V |
| ✅ | `354` | 237.0 | 244.3 | 1.031 | 1.062 | 3.2 % | 6.66 V |
| ✅ | `116` | 236.9 | 244.1 | 1.03 | 1.061 | 3.1 % | 8.96 V |
| ✅ | `128` | 237.0 | 244.0 | 1.03 | 1.061 | 3.1 % | 8.81 V |
| ✅ | `521` | 237.0 | 244.0 | 1.031 | 1.061 | 3.0 % | 6.63 V |
| ✅ | `307` | 237.0 | 243.9 | 1.031 | 1.06 | 3.0 % | 6.63 V |
| ✅ | `198` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 8.65 V |
| ✅ | `104` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 8.67 V |
| ✅ | `108` | 237.0 | 243.7 | 1.03 | 1.059 | 2.9 % | 8.49 V |
| ✅ | `99` | 237.0 | 243.6 | 1.03 | 1.059 | 2.9 % | 8.44 V |
| ✅ | `256` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.62 V |
| ✅ | `247` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.63 V |
| ✅ | `226` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.69 V |
| ✅ | `220` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.71 V |
| ✅ | `219` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.86 V |
| ✅ | `208` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 6.89 V |
| ✅ | `201` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.29 V |
| ✅ | `188` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.35 V |
| ✅ | `179` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.76 V |
| ✅ | `162` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 7.83 V |
| ✅ | `187` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.02 V |
| ✅ | `147` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.09 V |
| ✅ | `90` | 237.0 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.31 V |
| ✅ | `82` | 237.0 | 243.5 | 1.03 | 1.059 | 2.8 % | 8.31 V |
| ✅ | `62` | 235.1 | 239.4 | 1.022 | 1.041 | 1.8 % | 5.67 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.888 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=3.793 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.924 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.975 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.814 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=3.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.146 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.175 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.429 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.318 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.393 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=4.127 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.411 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.24 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=3.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.109 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.054 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=3.819 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.32 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=3.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.58 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.267 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=3.965 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.477 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.016 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=3.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.482 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.863 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.142 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.437 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=3.816 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.458 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.48 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 152.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.62 V at bus '896' — reflects the neutral shift under unbalanced loading.

