# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -193405.4307  
**Solve time:** 0.058 s  
**Findings:** 27 errors · 26 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 37.719 kW |
| Total load | 13.973 kW |
| Total network losses (P) | 23.746 kW |
| Total network losses (Q) | 7.063 kW var |
| Loss fraction | 169.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.285 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.087 (`896`) | 4.9 % (`498`) | 15.29 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.4 | 249.9 | 1.041 | 1.087 | 4.6 % | 15.29 V |
| ✅ | `949` | 240.2 | 249.7 | 1.044 | 1.086 | 4.1 % | 14.31 V |
| ✅ | `677` | 239.4 | 249.5 | 1.041 | 1.085 | 4.4 % | 14.8 V |
| ✅ | `660` | 239.4 | 249.5 | 1.041 | 1.085 | 4.4 % | 14.71 V |
| ✅ | `661` | 239.4 | 249.4 | 1.041 | 1.084 | 4.3 % | 14.58 V |
| ✅ | `895` | 240.2 | 249.4 | 1.044 | 1.084 | 4.0 % | 14.03 V |
| ✅ | `654` | 239.4 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.45 V |
| ✅ | `644` | 239.4 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.43 V |
| ✅ | `904` | 240.2 | 249.3 | 1.044 | 1.084 | 3.9 % | 13.93 V |
| ✅ | `635` | 239.4 | 249.2 | 1.041 | 1.084 | 4.3 % | 14.35 V |
| ✅ | `775` | 240.3 | 249.2 | 1.045 | 1.083 | 3.9 % | 13.97 V |
| ✅ | `849` | 240.2 | 249.1 | 1.044 | 1.083 | 3.9 % | 13.81 V |
| ✅ | `894` | 240.2 | 249.1 | 1.044 | 1.083 | 3.9 % | 12.77 V |
| ✅ | `808` | 241.1 | 248.8 | 1.048 | 1.082 | 3.3 % | 13.99 V |
| ✅ | `693` | 240.3 | 248.8 | 1.045 | 1.082 | 3.7 % | 13.65 V |
| ✅ | `673` | 240.3 | 248.8 | 1.045 | 1.082 | 3.7 % | 13.63 V |
| ✅ | `627` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.66 V |
| ✅ | `665` | 240.2 | 248.7 | 1.045 | 1.081 | 3.7 % | 13.58 V |
| ✅ | `617` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.62 V |
| ✅ | `618` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.62 V |
| ✅ | `779` | 240.9 | 248.7 | 1.047 | 1.081 | 3.4 % | 13.85 V |
| ✅ | `659` | 240.2 | 248.7 | 1.044 | 1.081 | 3.7 % | 13.53 V |
| ✅ | `608` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.59 V |
| ✅ | `607` | 239.5 | 248.6 | 1.041 | 1.081 | 4.0 % | 13.53 V |
| ✅ | `600` | 239.5 | 248.5 | 1.041 | 1.081 | 3.9 % | 13.43 V |
| ✅ | `717` | 241.6 | 248.5 | 1.051 | 1.08 | 3.0 % | 14.11 V |
| ✅ | `655` | 241.2 | 248.5 | 1.049 | 1.08 | 3.2 % | 13.85 V |
| ✅ | `609` | 241.0 | 248.5 | 1.048 | 1.08 | 3.2 % | 13.8 V |
| ✅ | `773` | 240.8 | 248.5 | 1.047 | 1.08 | 3.3 % | 13.71 V |
| ✅ | `568` | 240.1 | 248.5 | 1.044 | 1.08 | 3.6 % | 13.38 V |
| ✅ | `498` | 236.9 | 248.2 | 1.03 | 1.079 | 4.9 % | 3.47 V |
| ✅ | `491` | 236.9 | 248.1 | 1.03 | 1.079 | 4.9 % | 3.43 V |
| ✅ | `545` | 239.5 | 248.0 | 1.041 | 1.078 | 3.7 % | 12.88 V |
| ✅ | `473` | 236.9 | 248.0 | 1.03 | 1.078 | 4.8 % | 3.39 V |
| ✅ | `472` | 236.9 | 247.9 | 1.03 | 1.078 | 4.8 % | 3.36 V |
| ✅ | `439` | 236.9 | 247.9 | 1.03 | 1.078 | 4.7 % | 3.33 V |
| ✅ | `536` | 236.9 | 247.8 | 1.03 | 1.077 | 4.7 % | 3.3 V |
| ✅ | `427` | 236.9 | 247.7 | 1.03 | 1.077 | 4.7 % | 3.27 V |
| ✅ | `313` | 236.4 | 247.5 | 1.028 | 1.076 | 4.8 % | 12.55 V |
| ✅ | `479` | 236.9 | 247.5 | 1.03 | 1.076 | 4.6 % | 3.22 V |
| ✅ | `303` | 236.4 | 247.5 | 1.028 | 1.076 | 4.8 % | 12.47 V |
| ✅ | `377` | 236.9 | 247.4 | 1.03 | 1.076 | 4.6 % | 3.21 V |
| ✅ | `290` | 236.4 | 247.4 | 1.028 | 1.076 | 4.8 % | 12.39 V |
| ✅ | `282` | 236.4 | 247.4 | 1.028 | 1.076 | 4.8 % | 12.35 V |
| ✅ | `376` | 236.9 | 247.4 | 1.03 | 1.076 | 4.5 % | 3.2 V |
| ✅ | `272` | 236.4 | 247.3 | 1.028 | 1.075 | 4.7 % | 12.26 V |
| ✅ | `354` | 236.9 | 247.3 | 1.03 | 1.075 | 4.5 % | 3.19 V |
| ✅ | `321` | 236.5 | 247.1 | 1.028 | 1.074 | 4.6 % | 11.95 V |
| ✅ | `264` | 236.5 | 247.0 | 1.028 | 1.074 | 4.6 % | 11.84 V |
| ✅ | `521` | 236.9 | 246.9 | 1.03 | 1.074 | 4.3 % | 3.19 V |
| ✅ | `263` | 236.5 | 246.8 | 1.028 | 1.073 | 4.5 % | 11.54 V |
| ✅ | `307` | 236.9 | 246.8 | 1.03 | 1.073 | 4.3 % | 3.21 V |
| ✅ | `254` | 236.5 | 246.8 | 1.028 | 1.073 | 4.5 % | 11.45 V |
| ✅ | `229` | 236.5 | 246.5 | 1.028 | 1.072 | 4.3 % | 11.07 V |
| ✅ | `216` | 236.6 | 246.5 | 1.028 | 1.072 | 4.3 % | 10.98 V |
| ✅ | `256` | 236.9 | 246.4 | 1.03 | 1.071 | 4.1 % | 3.3 V |
| ✅ | `247` | 236.9 | 246.3 | 1.03 | 1.071 | 4.1 % | 3.34 V |
| ✅ | `192` | 236.6 | 246.2 | 1.029 | 1.07 | 4.2 % | 10.59 V |
| ✅ | `175` | 236.6 | 246.1 | 1.029 | 1.07 | 4.1 % | 10.5 V |
| ✅ | `530` | 238.6 | 246.1 | 1.037 | 1.07 | 3.3 % | 10.36 V |
| ✅ | `166` | 236.7 | 245.7 | 1.029 | 1.068 | 3.9 % | 9.77 V |
| ✅ | `226` | 236.9 | 245.7 | 1.03 | 1.068 | 3.8 % | 3.61 V |
| ✅ | `220` | 236.9 | 245.6 | 1.03 | 1.068 | 3.8 % | 3.67 V |
| ✅ | `151` | 236.7 | 245.3 | 1.029 | 1.067 | 3.8 % | 9.37 V |
| ✅ | `145` | 236.7 | 245.3 | 1.029 | 1.066 | 3.7 % | 9.28 V |
| ✅ | `138` | 236.7 | 245.2 | 1.029 | 1.066 | 3.7 % | 9.14 V |
| ✅ | `144` | 236.7 | 245.1 | 1.029 | 1.066 | 3.7 % | 9.08 V |
| ✅ | `428` | 239.2 | 245.1 | 1.04 | 1.066 | 2.6 % | 9.23 V |
| ✅ | `416` | 239.1 | 245.1 | 1.04 | 1.066 | 2.6 % | 9.19 V |
| ✅ | `391` | 239.0 | 245.1 | 1.039 | 1.066 | 2.6 % | 9.14 V |
| ✅ | `380` | 239.0 | 245.1 | 1.039 | 1.066 | 2.6 % | 9.13 V |
| ✅ | `392` | 239.0 | 245.1 | 1.039 | 1.066 | 2.6 % | 9.13 V |
| ✅ | `131` | 236.7 | 245.1 | 1.029 | 1.065 | 3.6 % | 9.0 V |
| ✅ | `366` | 238.9 | 245.1 | 1.039 | 1.065 | 2.7 % | 9.08 V |
| ✅ | `355` | 238.8 | 245.1 | 1.038 | 1.065 | 2.7 % | 9.06 V |
| ✅ | `441` | 238.6 | 245.0 | 1.038 | 1.065 | 2.8 % | 8.97 V |
| ✅ | `348` | 238.9 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.12 V |
| ✅ | `327` | 238.5 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.9 V |
| ✅ | `384` | 238.4 | 245.0 | 1.037 | 1.065 | 2.9 % | 8.87 V |
| ✅ | `318` | 238.4 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.85 V |
| ✅ | `300` | 238.2 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.79 V |
| ✅ | `219` | 236.9 | 244.9 | 1.03 | 1.065 | 3.5 % | 4.15 V |
| ✅ | `208` | 236.9 | 244.8 | 1.03 | 1.064 | 3.4 % | 4.24 V |
| ✅ | `116` | 236.8 | 244.5 | 1.03 | 1.063 | 3.3 % | 8.01 V |
| ✅ | `128` | 236.9 | 244.3 | 1.03 | 1.062 | 3.3 % | 7.79 V |
| ✅ | `198` | 236.8 | 244.1 | 1.03 | 1.061 | 3.2 % | 7.63 V |
| ✅ | `104` | 236.8 | 244.1 | 1.03 | 1.061 | 3.2 % | 7.68 V |
| ✅ | `108` | 236.9 | 244.0 | 1.03 | 1.061 | 3.1 % | 7.46 V |
| ✅ | `99` | 236.9 | 243.9 | 1.03 | 1.06 | 3.1 % | 7.4 V |
| ✅ | `201` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.23 V |
| ✅ | `188` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.34 V |
| ✅ | `179` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.17 V |
| ✅ | `162` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.3 V |
| ✅ | `187` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.64 V |
| ✅ | `147` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.77 V |
| ✅ | `90` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.23 V |
| ✅ | `82` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.25 V |
| ✅ | `62` | 235.3 | 239.6 | 1.023 | 1.042 | 1.9 % | 5.06 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.814 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.801 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.302 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.779 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.938 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': |S|=5.25 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.98 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': |S|=5.25 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.147 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.901 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.873 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.869 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.781 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.533 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.915 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.462 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.852 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.634 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.784 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.248 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.828 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.208 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': |S|=5.25 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.968 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.606 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 169.9 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.29 V at bus '896' — reflects the neutral shift under unbalanced loading.

