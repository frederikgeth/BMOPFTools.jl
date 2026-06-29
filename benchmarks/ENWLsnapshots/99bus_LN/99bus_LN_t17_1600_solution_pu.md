# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -172787.6338  
**Solve time:** 0.056 s  
**Findings:** 5 errors · 44 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 43.122 kW |
| Total load | 23.59 kW |
| Total network losses (P) | 19.532 kW |
| Total network losses (Q) | 5.789 kW var |
| Loss fraction | 82.8% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 14.657 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.079 (`896`) | 4.6 % (`313`) | 14.66 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 238.3 | 248.2 | 1.036 | 1.079 | 4.3 % | 14.66 V |
| ✅ | `949` | 239.0 | 247.9 | 1.039 | 1.078 | 3.9 % | 13.89 V |
| ✅ | `895` | 239.0 | 247.7 | 1.039 | 1.077 | 3.8 % | 13.64 V |
| ✅ | `661` | 238.3 | 247.7 | 1.036 | 1.077 | 4.1 % | 13.98 V |
| ✅ | `660` | 238.3 | 247.7 | 1.036 | 1.077 | 4.1 % | 14.09 V |
| ✅ | `677` | 238.3 | 247.6 | 1.036 | 1.077 | 4.1 % | 14.16 V |
| ✅ | `654` | 238.3 | 247.6 | 1.036 | 1.076 | 4.0 % | 13.85 V |
| ✅ | `904` | 239.0 | 247.5 | 1.039 | 1.076 | 3.7 % | 13.54 V |
| ✅ | `644` | 238.3 | 247.5 | 1.036 | 1.076 | 4.0 % | 13.83 V |
| ✅ | `775` | 239.1 | 247.5 | 1.04 | 1.076 | 3.7 % | 13.5 V |
| ✅ | `635` | 238.3 | 247.5 | 1.036 | 1.076 | 4.0 % | 13.75 V |
| ✅ | `849` | 239.0 | 247.4 | 1.039 | 1.076 | 3.6 % | 13.43 V |
| ✅ | `894` | 239.0 | 247.4 | 1.039 | 1.076 | 3.6 % | 12.87 V |
| ✅ | `808` | 239.9 | 247.1 | 1.043 | 1.074 | 3.1 % | 13.49 V |
| ✅ | `693` | 239.2 | 247.1 | 1.04 | 1.074 | 3.4 % | 13.19 V |
| ✅ | `673` | 239.1 | 247.1 | 1.04 | 1.074 | 3.5 % | 13.18 V |
| ✅ | `665` | 239.1 | 247.0 | 1.039 | 1.074 | 3.5 % | 13.13 V |
| ✅ | `627` | 238.3 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.11 V |
| ✅ | `779` | 239.7 | 247.0 | 1.042 | 1.074 | 3.2 % | 13.39 V |
| ✅ | `659` | 239.1 | 247.0 | 1.039 | 1.074 | 3.4 % | 13.08 V |
| ✅ | `617` | 238.3 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.08 V |
| ✅ | `618` | 238.3 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.07 V |
| ✅ | `608` | 238.3 | 247.0 | 1.036 | 1.074 | 3.7 % | 13.05 V |
| ✅ | `607` | 238.3 | 246.9 | 1.036 | 1.074 | 3.7 % | 12.99 V |
| ✅ | `717` | 240.4 | 246.9 | 1.045 | 1.073 | 2.8 % | 13.57 V |
| ✅ | `655` | 240.0 | 246.9 | 1.043 | 1.073 | 3.0 % | 13.36 V |
| ✅ | `600` | 238.4 | 246.8 | 1.036 | 1.073 | 3.7 % | 12.9 V |
| ✅ | `609` | 239.8 | 246.8 | 1.043 | 1.073 | 3.0 % | 13.3 V |
| ✅ | `773` | 239.6 | 246.8 | 1.042 | 1.073 | 3.2 % | 13.17 V |
| ✅ | `568` | 239.0 | 246.8 | 1.039 | 1.073 | 3.4 % | 12.9 V |
| ✅ | `498` | 236.0 | 246.5 | 1.026 | 1.072 | 4.5 % | 3.09 V |
| ✅ | `491` | 236.0 | 246.4 | 1.026 | 1.071 | 4.5 % | 3.07 V |
| ✅ | `545` | 238.4 | 246.4 | 1.036 | 1.071 | 3.5 % | 12.38 V |
| ✅ | `473` | 236.0 | 246.3 | 1.026 | 1.071 | 4.5 % | 3.04 V |
| ✅ | `472` | 236.0 | 246.3 | 1.026 | 1.071 | 4.5 % | 3.02 V |
| ✅ | `439` | 236.0 | 246.2 | 1.026 | 1.07 | 4.4 % | 3.0 V |
| ✅ | `536` | 236.0 | 246.1 | 1.026 | 1.07 | 4.4 % | 2.98 V |
| ✅ | `313` | 235.6 | 246.1 | 1.024 | 1.07 | 4.6 % | 11.96 V |
| ✅ | `303` | 235.6 | 246.0 | 1.024 | 1.07 | 4.6 % | 11.87 V |
| ✅ | `427` | 236.0 | 246.0 | 1.026 | 1.07 | 4.3 % | 2.96 V |
| ✅ | `290` | 235.6 | 246.0 | 1.024 | 1.069 | 4.5 % | 11.79 V |
| ✅ | `282` | 235.6 | 246.0 | 1.024 | 1.069 | 4.5 % | 11.75 V |
| ✅ | `272` | 235.6 | 245.9 | 1.024 | 1.069 | 4.5 % | 11.66 V |
| ✅ | `479` | 236.0 | 245.9 | 1.026 | 1.069 | 4.3 % | 2.94 V |
| ✅ | `377` | 236.0 | 245.8 | 1.026 | 1.069 | 4.2 % | 2.94 V |
| ✅ | `376` | 236.0 | 245.7 | 1.026 | 1.068 | 4.2 % | 2.93 V |
| ✅ | `321` | 235.6 | 245.7 | 1.024 | 1.068 | 4.4 % | 11.34 V |
| ✅ | `354` | 236.0 | 245.6 | 1.026 | 1.068 | 4.2 % | 2.94 V |
| ✅ | `264` | 235.6 | 245.6 | 1.024 | 1.068 | 4.3 % | 11.24 V |
| ✅ | `263` | 235.6 | 245.3 | 1.025 | 1.067 | 4.2 % | 10.92 V |
| ✅ | `254` | 235.7 | 245.3 | 1.025 | 1.067 | 4.2 % | 10.85 V |
| ✅ | `521` | 236.0 | 245.3 | 1.026 | 1.066 | 4.0 % | 2.98 V |
| ✅ | `307` | 236.0 | 245.2 | 1.026 | 1.066 | 4.0 % | 3.01 V |
| ✅ | `229` | 235.7 | 245.0 | 1.025 | 1.065 | 4.1 % | 10.47 V |
| ✅ | `216` | 235.7 | 245.0 | 1.025 | 1.065 | 4.0 % | 10.39 V |
| ✅ | `256` | 236.0 | 244.8 | 1.026 | 1.064 | 3.8 % | 3.13 V |
| ✅ | `247` | 236.0 | 244.7 | 1.026 | 1.064 | 3.8 % | 3.18 V |
| ✅ | `192` | 235.7 | 244.7 | 1.025 | 1.064 | 3.9 % | 10.01 V |
| ✅ | `175` | 235.7 | 244.6 | 1.025 | 1.064 | 3.9 % | 9.93 V |
| ✅ | `530` | 237.5 | 244.6 | 1.033 | 1.064 | 3.1 % | 9.93 V |
| ✅ | `166` | 235.8 | 244.3 | 1.025 | 1.062 | 3.7 % | 9.23 V |
| ✅ | `226` | 236.0 | 244.1 | 1.026 | 1.061 | 3.5 % | 3.49 V |
| ✅ | `220` | 236.0 | 244.0 | 1.026 | 1.061 | 3.5 % | 3.55 V |
| ✅ | `151` | 235.8 | 243.9 | 1.025 | 1.06 | 3.5 % | 8.89 V |
| ✅ | `145` | 235.8 | 243.8 | 1.025 | 1.06 | 3.5 % | 8.8 V |
| ✅ | `138` | 235.8 | 243.7 | 1.025 | 1.06 | 3.4 % | 8.67 V |
| ✅ | `144` | 235.9 | 243.7 | 1.025 | 1.06 | 3.4 % | 8.61 V |
| ✅ | `428` | 238.0 | 243.7 | 1.035 | 1.059 | 2.5 % | 8.76 V |
| ✅ | `416` | 237.9 | 243.7 | 1.034 | 1.059 | 2.5 % | 8.72 V |
| ✅ | `391` | 237.8 | 243.7 | 1.034 | 1.059 | 2.5 % | 8.69 V |
| ✅ | `380` | 237.8 | 243.7 | 1.034 | 1.059 | 2.5 % | 8.69 V |
| ✅ | `392` | 237.8 | 243.7 | 1.034 | 1.059 | 2.5 % | 8.68 V |
| ✅ | `366` | 237.7 | 243.7 | 1.034 | 1.059 | 2.6 % | 8.64 V |
| ✅ | `131` | 235.9 | 243.7 | 1.025 | 1.059 | 3.4 % | 8.54 V |
| ✅ | `355` | 237.7 | 243.6 | 1.033 | 1.059 | 2.6 % | 8.62 V |
| ✅ | `441` | 237.5 | 243.6 | 1.033 | 1.059 | 2.7 % | 8.56 V |
| ✅ | `327` | 237.4 | 243.6 | 1.032 | 1.059 | 2.7 % | 8.5 V |
| ✅ | `348` | 237.7 | 243.6 | 1.033 | 1.059 | 2.6 % | 8.64 V |
| ✅ | `384` | 237.3 | 243.6 | 1.032 | 1.059 | 2.7 % | 8.47 V |
| ✅ | `318` | 237.3 | 243.6 | 1.032 | 1.059 | 2.7 % | 8.46 V |
| ✅ | `300` | 237.2 | 243.6 | 1.031 | 1.059 | 2.8 % | 8.41 V |
| ✅ | `219` | 236.0 | 243.4 | 1.026 | 1.058 | 3.2 % | 4.03 V |
| ✅ | `208` | 236.0 | 243.3 | 1.026 | 1.058 | 3.1 % | 4.11 V |
| ✅ | `116` | 236.0 | 243.0 | 1.026 | 1.057 | 3.1 % | 7.59 V |
| ✅ | `128` | 236.0 | 243.0 | 1.026 | 1.057 | 3.1 % | 7.44 V |
| ✅ | `198` | 236.0 | 242.8 | 1.026 | 1.056 | 3.0 % | 7.28 V |
| ✅ | `104` | 236.0 | 242.8 | 1.026 | 1.056 | 3.0 % | 7.33 V |
| ✅ | `108` | 236.0 | 242.6 | 1.026 | 1.055 | 2.9 % | 7.13 V |
| ✅ | `99` | 236.0 | 242.6 | 1.026 | 1.055 | 2.9 % | 7.08 V |
| ✅ | `201` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 5.05 V |
| ✅ | `188` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 5.16 V |
| ✅ | `179` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 5.96 V |
| ✅ | `162` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.07 V |
| ✅ | `187` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.44 V |
| ✅ | `147` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.51 V |
| ✅ | `90` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.93 V |
| ✅ | `82` | 236.0 | 242.5 | 1.026 | 1.054 | 2.8 % | 6.95 V |
| ✅ | `62` | 234.6 | 238.7 | 1.02 | 1.038 | 1.8 % | 4.84 V |
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
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
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
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
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
  IBR 'pv_21' phase 'c': pg=4.893 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
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
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.486 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 82.8 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 14.66 V at bus '896' — reflects the neutral shift under unbalanced loading.

