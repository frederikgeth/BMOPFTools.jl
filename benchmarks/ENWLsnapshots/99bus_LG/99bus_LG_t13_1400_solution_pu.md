# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:18  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -200367.9946  
**Solve time:** 0.055 s  
**Findings:** 29 errors · 25 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 38.339 kW |
| Total load | 13.973 kW |
| Total network losses (P) | 24.366 kW |
| Total network losses (Q) | 7.024 kW var |
| Loss fraction | 174.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 18.612 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.097 (`896`) | 5.3 % (`313`) | 18.61 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 241.3 | 252.4 | 1.049 | 1.097 | 4.8 % | 18.61 V |
| ✅ | `949` | 241.8 | 251.9 | 1.051 | 1.095 | 4.4 % | 17.69 V |
| ✅ | `677` | 241.4 | 251.8 | 1.049 | 1.095 | 4.5 % | 18.03 V |
| ✅ | `660` | 241.4 | 251.8 | 1.049 | 1.095 | 4.5 % | 17.96 V |
| ✅ | `661` | 241.4 | 251.7 | 1.049 | 1.094 | 4.5 % | 17.83 V |
| ✅ | `654` | 241.4 | 251.6 | 1.049 | 1.094 | 4.5 % | 17.69 V |
| ✅ | `644` | 241.4 | 251.6 | 1.049 | 1.094 | 4.4 % | 17.67 V |
| ✅ | `895` | 241.8 | 251.6 | 1.051 | 1.094 | 4.2 % | 17.37 V |
| ✅ | `635` | 241.4 | 251.5 | 1.049 | 1.094 | 4.4 % | 17.58 V |
| ✅ | `904` | 241.8 | 251.4 | 1.051 | 1.093 | 4.2 % | 17.24 V |
| ✅ | `775` | 241.6 | 251.3 | 1.051 | 1.093 | 4.2 % | 17.26 V |
| ✅ | `849` | 241.8 | 251.3 | 1.051 | 1.093 | 4.1 % | 17.1 V |
| ✅ | `894` | 242.3 | 251.3 | 1.053 | 1.093 | 3.9 % | 16.08 V |
| ✅ | `808` | 241.7 | 251.0 | 1.051 | 1.091 | 4.0 % | 17.21 V |
| ✅ | `693` | 241.6 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.86 V |
| ✅ | `673` | 241.6 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.85 V |
| ✅ | `627` | 241.4 | 250.9 | 1.05 | 1.091 | 4.1 % | 16.85 V |
| ✅ | `665` | 241.6 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.79 V |
| ✅ | `617` | 241.4 | 250.9 | 1.05 | 1.091 | 4.1 % | 16.8 V |
| ✅ | `618` | 241.4 | 250.9 | 1.05 | 1.091 | 4.1 % | 16.79 V |
| ✅ | `779` | 241.6 | 250.8 | 1.051 | 1.091 | 4.0 % | 17.03 V |
| ✅ | `608` | 241.4 | 250.8 | 1.05 | 1.091 | 4.1 % | 16.76 V |
| ✅ | `659` | 241.6 | 250.8 | 1.051 | 1.091 | 4.0 % | 16.73 V |
| ✅ | `607` | 241.4 | 250.8 | 1.05 | 1.09 | 4.1 % | 16.7 V |
| ✅ | `600` | 241.4 | 250.7 | 1.05 | 1.09 | 4.0 % | 16.6 V |
| ✅ | `717` | 241.6 | 250.7 | 1.05 | 1.09 | 3.9 % | 17.21 V |
| ✅ | `655` | 241.6 | 250.7 | 1.05 | 1.09 | 3.9 % | 16.99 V |
| ✅ | `609` | 241.6 | 250.7 | 1.05 | 1.09 | 3.9 % | 16.94 V |
| ✅ | `773` | 241.6 | 250.7 | 1.05 | 1.09 | 3.9 % | 16.83 V |
| ✅ | `568` | 241.6 | 250.7 | 1.05 | 1.09 | 3.9 % | 16.54 V |
| ✅ | `545` | 241.4 | 250.2 | 1.05 | 1.088 | 3.8 % | 15.98 V |
| ✅ | `313` | 237.7 | 249.9 | 1.033 | 1.086 | 5.3 % | 15.68 V |
| ✅ | `303` | 237.7 | 249.8 | 1.034 | 1.086 | 5.3 % | 15.6 V |
| ✅ | `290` | 237.7 | 249.7 | 1.034 | 1.086 | 5.2 % | 15.52 V |
| ✅ | `282` | 237.7 | 249.7 | 1.034 | 1.086 | 5.2 % | 15.47 V |
| ✅ | `272` | 237.7 | 249.6 | 1.034 | 1.085 | 5.2 % | 15.38 V |
| ✅ | `321` | 237.8 | 249.4 | 1.034 | 1.084 | 5.1 % | 15.06 V |
| ✅ | `264` | 237.8 | 249.3 | 1.034 | 1.084 | 5.0 % | 14.95 V |
| ✅ | `263` | 237.8 | 249.0 | 1.034 | 1.083 | 4.9 % | 14.64 V |
| ✅ | `254` | 237.8 | 249.0 | 1.034 | 1.082 | 4.9 % | 14.55 V |
| ✅ | `229` | 237.8 | 248.7 | 1.034 | 1.081 | 4.7 % | 14.17 V |
| ✅ | `216` | 237.8 | 248.6 | 1.034 | 1.081 | 4.7 % | 14.07 V |
| ✅ | `192` | 237.9 | 248.3 | 1.034 | 1.079 | 4.5 % | 13.68 V |
| ✅ | `175` | 237.9 | 248.2 | 1.034 | 1.079 | 4.5 % | 13.59 V |
| ✅ | `530` | 240.3 | 248.1 | 1.045 | 1.079 | 3.4 % | 13.23 V |
| ✅ | `166` | 238.0 | 247.7 | 1.035 | 1.077 | 4.2 % | 12.87 V |
| ✅ | `498` | 238.2 | 247.4 | 1.036 | 1.076 | 4.0 % | 8.47 V |
| ✅ | `491` | 238.2 | 247.3 | 1.036 | 1.075 | 4.0 % | 8.45 V |
| ✅ | `151` | 238.0 | 247.3 | 1.035 | 1.075 | 4.0 % | 12.46 V |
| ✅ | `473` | 238.2 | 247.2 | 1.036 | 1.075 | 3.9 % | 8.42 V |
| ✅ | `145` | 238.0 | 247.2 | 1.035 | 1.075 | 4.0 % | 12.36 V |
| ✅ | `472` | 238.2 | 247.1 | 1.036 | 1.075 | 3.9 % | 8.4 V |
| ✅ | `138` | 238.0 | 247.1 | 1.035 | 1.074 | 3.9 % | 12.22 V |
| ✅ | `439` | 238.2 | 247.1 | 1.036 | 1.074 | 3.8 % | 8.38 V |
| ✅ | `144` | 238.0 | 247.0 | 1.035 | 1.074 | 3.9 % | 12.16 V |
| ✅ | `536` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 8.37 V |
| ✅ | `131` | 238.0 | 247.0 | 1.035 | 1.074 | 3.9 % | 12.08 V |
| ✅ | `428` | 240.8 | 247.0 | 1.047 | 1.074 | 2.7 % | 11.82 V |
| ✅ | `416` | 240.7 | 246.9 | 1.047 | 1.074 | 2.7 % | 11.79 V |
| ✅ | `391` | 240.6 | 246.9 | 1.046 | 1.074 | 2.7 % | 11.77 V |
| ✅ | `380` | 240.6 | 246.9 | 1.046 | 1.074 | 2.8 % | 11.77 V |
| ✅ | `392` | 240.6 | 246.9 | 1.046 | 1.074 | 2.8 % | 11.77 V |
| ✅ | `366` | 240.5 | 246.9 | 1.046 | 1.074 | 2.8 % | 11.74 V |
| ✅ | `355` | 240.4 | 246.9 | 1.045 | 1.074 | 2.8 % | 11.73 V |
| ✅ | `441` | 240.2 | 246.9 | 1.044 | 1.074 | 2.9 % | 11.69 V |
| ✅ | `348` | 240.4 | 246.9 | 1.045 | 1.073 | 2.8 % | 11.8 V |
| ✅ | `327` | 240.1 | 246.9 | 1.044 | 1.073 | 3.0 % | 11.66 V |
| ✅ | `384` | 240.0 | 246.9 | 1.043 | 1.073 | 3.0 % | 11.64 V |
| ✅ | `318` | 239.9 | 246.9 | 1.043 | 1.073 | 3.0 % | 11.63 V |
| ✅ | `427` | 238.2 | 246.9 | 1.036 | 1.073 | 3.8 % | 8.35 V |
| ✅ | `300` | 239.8 | 246.9 | 1.043 | 1.073 | 3.1 % | 11.61 V |
| ✅ | `479` | 238.2 | 246.7 | 1.036 | 1.073 | 3.7 % | 8.32 V |
| ✅ | `377` | 238.2 | 246.6 | 1.036 | 1.072 | 3.6 % | 8.31 V |
| ✅ | `376` | 238.2 | 246.6 | 1.036 | 1.072 | 3.6 % | 8.3 V |
| ✅ | `354` | 238.2 | 246.5 | 1.036 | 1.072 | 3.6 % | 8.29 V |
| ✅ | `116` | 238.1 | 246.2 | 1.035 | 1.071 | 3.5 % | 11.1 V |
| ✅ | `521` | 238.2 | 246.1 | 1.036 | 1.07 | 3.4 % | 8.26 V |
| ✅ | `128` | 238.1 | 246.1 | 1.035 | 1.07 | 3.5 % | 10.9 V |
| ✅ | `307` | 238.2 | 246.0 | 1.036 | 1.07 | 3.4 % | 8.26 V |
| ✅ | `104` | 238.1 | 245.9 | 1.035 | 1.069 | 3.4 % | 10.73 V |
| ✅ | `198` | 238.1 | 245.9 | 1.035 | 1.069 | 3.4 % | 10.7 V |
| ✅ | `108` | 238.1 | 245.7 | 1.035 | 1.068 | 3.3 % | 10.51 V |
| ✅ | `99` | 238.1 | 245.6 | 1.035 | 1.068 | 3.3 % | 10.44 V |
| ✅ | `256` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.27 V |
| ✅ | `247` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.28 V |
| ✅ | `226` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.36 V |
| ✅ | `220` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.38 V |
| ✅ | `219` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.57 V |
| ✅ | `208` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 8.61 V |
| ✅ | `201` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 9.09 V |
| ✅ | `188` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 9.15 V |
| ✅ | `179` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 9.64 V |
| ✅ | `162` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 9.73 V |
| ✅ | `187` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 9.94 V |
| ✅ | `147` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 10.03 V |
| ✅ | `90` | 238.2 | 245.6 | 1.036 | 1.068 | 3.2 % | 10.29 V |
| ✅ | `82` | 238.2 | 245.5 | 1.035 | 1.067 | 3.2 % | 10.29 V |
| ✅ | `62` | 236.0 | 240.7 | 1.026 | 1.047 | 2.0 % | 7.01 V |
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
  IBR 'pv_22' phase 'c': pg=4.833 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.81 kW is within 1 % of its P bound.
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
  IBR 'pv_18' phase 'b': pg=5.227 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.98 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.848 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.244 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.901 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.873 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.202 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.869 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.781 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.782 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.219 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.852 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.784 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.202 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.828 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=5.249 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.24 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=5.062 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.968 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.121 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 174.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 18.61 V at bus '896' — reflects the neutral shift under unbalanced loading.

