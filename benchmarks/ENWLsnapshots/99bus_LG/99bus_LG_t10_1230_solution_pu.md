# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:17  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -194994.5371  
**Solve time:** 0.048 s  
**Findings:** 11 errors · 40 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 34.521 kW |
| Total load | 11.642 kW |
| Total network losses (P) | 22.879 kW |
| Total network losses (Q) | 6.59 kW var |
| Loss fraction | 196.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 18.152 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.096 (`896`) | 5.2 % (`313`) | 18.15 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 240.8 | 252.1 | 1.047 | 1.096 | 4.9 % | 18.15 V |
| ✅ | `677` | 240.8 | 251.5 | 1.047 | 1.094 | 4.7 % | 17.58 V |
| ✅ | `660` | 240.8 | 251.5 | 1.047 | 1.094 | 4.6 % | 17.49 V |
| ✅ | `949` | 241.7 | 251.4 | 1.051 | 1.093 | 4.2 % | 17.05 V |
| ✅ | `661` | 240.8 | 251.4 | 1.047 | 1.093 | 4.6 % | 17.34 V |
| ✅ | `654` | 240.8 | 251.3 | 1.047 | 1.093 | 4.5 % | 17.21 V |
| ✅ | `644` | 240.9 | 251.3 | 1.047 | 1.093 | 4.5 % | 17.19 V |
| ✅ | `635` | 240.9 | 251.2 | 1.047 | 1.092 | 4.5 % | 17.1 V |
| ✅ | `895` | 241.7 | 251.2 | 1.051 | 1.092 | 4.1 % | 16.75 V |
| ✅ | `904` | 241.7 | 251.0 | 1.051 | 1.091 | 4.1 % | 16.63 V |
| ✅ | `775` | 241.5 | 251.0 | 1.05 | 1.091 | 4.1 % | 16.71 V |
| ✅ | `849` | 241.7 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.49 V |
| ✅ | `894` | 241.7 | 250.9 | 1.051 | 1.091 | 4.0 % | 15.37 V |
| ✅ | `808` | 241.5 | 250.6 | 1.05 | 1.09 | 4.0 % | 16.63 V |
| ✅ | `627` | 240.9 | 250.6 | 1.047 | 1.09 | 4.2 % | 16.37 V |
| ✅ | `693` | 241.5 | 250.6 | 1.05 | 1.089 | 4.0 % | 16.31 V |
| ✅ | `673` | 241.5 | 250.6 | 1.05 | 1.089 | 4.0 % | 16.29 V |
| ✅ | `617` | 240.9 | 250.6 | 1.047 | 1.089 | 4.2 % | 16.32 V |
| ✅ | `618` | 240.9 | 250.5 | 1.047 | 1.089 | 4.2 % | 16.32 V |
| ✅ | `665` | 241.5 | 250.5 | 1.05 | 1.089 | 3.9 % | 16.24 V |
| ✅ | `608` | 240.9 | 250.5 | 1.047 | 1.089 | 4.2 % | 16.29 V |
| ✅ | `779` | 241.5 | 250.5 | 1.05 | 1.089 | 3.9 % | 16.43 V |
| ✅ | `607` | 240.9 | 250.5 | 1.047 | 1.089 | 4.2 % | 16.23 V |
| ✅ | `659` | 241.4 | 250.5 | 1.05 | 1.089 | 3.9 % | 16.18 V |
| ✅ | `600` | 240.9 | 250.4 | 1.047 | 1.089 | 4.1 % | 16.12 V |
| ✅ | `717` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.61 V |
| ✅ | `655` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.4 V |
| ✅ | `609` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.36 V |
| ✅ | `773` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.29 V |
| ✅ | `568` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.01 V |
| ✅ | `545` | 240.9 | 249.9 | 1.047 | 1.086 | 3.9 % | 15.51 V |
| ✅ | `313` | 237.4 | 249.4 | 1.032 | 1.084 | 5.2 % | 15.2 V |
| ✅ | `303` | 237.4 | 249.3 | 1.032 | 1.084 | 5.2 % | 15.11 V |
| ✅ | `290` | 237.4 | 249.3 | 1.032 | 1.084 | 5.2 % | 15.04 V |
| ✅ | `282` | 237.4 | 249.3 | 1.032 | 1.084 | 5.2 % | 15.0 V |
| ✅ | `272` | 237.4 | 249.2 | 1.032 | 1.083 | 5.1 % | 14.91 V |
| ✅ | `321` | 237.4 | 248.9 | 1.032 | 1.082 | 5.0 % | 14.6 V |
| ✅ | `264` | 237.4 | 248.8 | 1.032 | 1.082 | 5.0 % | 14.5 V |
| ✅ | `263` | 237.5 | 248.6 | 1.032 | 1.081 | 4.8 % | 14.21 V |
| ✅ | `254` | 237.5 | 248.5 | 1.032 | 1.081 | 4.8 % | 14.12 V |
| ✅ | `229` | 237.5 | 248.2 | 1.033 | 1.079 | 4.7 % | 13.75 V |
| ✅ | `216` | 237.5 | 248.2 | 1.033 | 1.079 | 4.6 % | 13.66 V |
| ✅ | `192` | 237.5 | 247.9 | 1.033 | 1.078 | 4.5 % | 13.28 V |
| ✅ | `175` | 237.6 | 247.8 | 1.033 | 1.077 | 4.5 % | 13.2 V |
| ✅ | `530` | 239.9 | 247.8 | 1.043 | 1.077 | 3.4 % | 12.86 V |
| ✅ | `166` | 237.6 | 247.3 | 1.033 | 1.075 | 4.2 % | 12.51 V |
| ✅ | `498` | 237.9 | 246.9 | 1.034 | 1.074 | 3.9 % | 8.42 V |
| ✅ | `151` | 237.6 | 246.9 | 1.033 | 1.074 | 4.0 % | 12.12 V |
| ✅ | `491` | 237.9 | 246.9 | 1.034 | 1.073 | 3.9 % | 8.4 V |
| ✅ | `145` | 237.7 | 246.8 | 1.033 | 1.073 | 4.0 % | 12.03 V |
| ✅ | `473` | 237.9 | 246.8 | 1.034 | 1.073 | 3.9 % | 8.38 V |
| ✅ | `138` | 237.7 | 246.7 | 1.033 | 1.073 | 3.9 % | 11.9 V |
| ✅ | `472` | 237.9 | 246.7 | 1.034 | 1.073 | 3.8 % | 8.36 V |
| ✅ | `144` | 237.7 | 246.7 | 1.033 | 1.073 | 3.9 % | 11.85 V |
| ✅ | `428` | 240.4 | 246.7 | 1.045 | 1.072 | 2.7 % | 11.47 V |
| ✅ | `416` | 240.3 | 246.7 | 1.045 | 1.072 | 2.8 % | 11.45 V |
| ✅ | `391` | 240.2 | 246.6 | 1.044 | 1.072 | 2.8 % | 11.43 V |
| ✅ | `380` | 240.2 | 246.6 | 1.044 | 1.072 | 2.8 % | 11.43 V |
| ✅ | `392` | 240.2 | 246.6 | 1.044 | 1.072 | 2.8 % | 11.43 V |
| ✅ | `366` | 240.1 | 246.6 | 1.044 | 1.072 | 2.9 % | 11.41 V |
| ✅ | `439` | 237.9 | 246.6 | 1.034 | 1.072 | 3.8 % | 8.34 V |
| ✅ | `355` | 240.0 | 246.6 | 1.044 | 1.072 | 2.9 % | 11.4 V |
| ✅ | `131` | 237.7 | 246.6 | 1.033 | 1.072 | 3.9 % | 11.76 V |
| ✅ | `441` | 239.8 | 246.6 | 1.043 | 1.072 | 3.0 % | 11.36 V |
| ✅ | `348` | 240.0 | 246.6 | 1.044 | 1.072 | 2.9 % | 11.47 V |
| ✅ | `327` | 239.7 | 246.6 | 1.042 | 1.072 | 3.0 % | 11.33 V |
| ✅ | `536` | 237.9 | 246.6 | 1.034 | 1.072 | 3.8 % | 8.32 V |
| ✅ | `384` | 239.6 | 246.6 | 1.042 | 1.072 | 3.1 % | 11.32 V |
| ✅ | `318` | 239.5 | 246.6 | 1.041 | 1.072 | 3.1 % | 11.31 V |
| ✅ | `300` | 239.4 | 246.6 | 1.041 | 1.072 | 3.1 % | 11.29 V |
| ✅ | `427` | 237.9 | 246.5 | 1.034 | 1.072 | 3.7 % | 8.3 V |
| ✅ | `479` | 237.9 | 246.3 | 1.034 | 1.071 | 3.7 % | 8.27 V |
| ✅ | `377` | 237.9 | 246.2 | 1.034 | 1.071 | 3.6 % | 8.25 V |
| ✅ | `376` | 237.9 | 246.2 | 1.034 | 1.07 | 3.6 % | 8.24 V |
| ✅ | `354` | 237.9 | 246.1 | 1.034 | 1.07 | 3.6 % | 8.24 V |
| ✅ | `116` | 237.8 | 245.9 | 1.034 | 1.069 | 3.6 % | 10.85 V |
| ✅ | `128` | 237.8 | 245.8 | 1.034 | 1.069 | 3.5 % | 10.64 V |
| ✅ | `521` | 237.9 | 245.7 | 1.034 | 1.068 | 3.4 % | 8.2 V |
| ✅ | `307` | 237.9 | 245.6 | 1.034 | 1.068 | 3.4 % | 8.2 V |
| ✅ | `198` | 237.8 | 245.6 | 1.034 | 1.068 | 3.4 % | 10.45 V |
| ✅ | `104` | 237.8 | 245.6 | 1.034 | 1.068 | 3.4 % | 10.47 V |
| ✅ | `108` | 237.8 | 245.4 | 1.034 | 1.067 | 3.3 % | 10.26 V |
| ✅ | `99` | 237.8 | 245.3 | 1.034 | 1.067 | 3.3 % | 10.2 V |
| ✅ | `256` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.2 V |
| ✅ | `247` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.21 V |
| ✅ | `226` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.26 V |
| ✅ | `220` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.29 V |
| ✅ | `219` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.45 V |
| ✅ | `208` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.49 V |
| ✅ | `201` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.92 V |
| ✅ | `188` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 8.99 V |
| ✅ | `179` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 9.45 V |
| ✅ | `162` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 9.52 V |
| ✅ | `187` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 9.72 V |
| ✅ | `147` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 9.81 V |
| ✅ | `90` | 237.9 | 245.3 | 1.034 | 1.066 | 3.2 % | 10.05 V |
| ✅ | `82` | 237.8 | 245.2 | 1.034 | 1.066 | 3.2 % | 10.05 V |
| ✅ | `62` | 235.8 | 240.5 | 1.025 | 1.046 | 2.1 % | 6.84 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.677 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.721 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=5.118 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.824 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.617 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.862 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=5.009 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.585 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.441 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.167 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.828 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.934 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.086 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.562 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.42 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.528 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.461 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.111 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.19 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.57 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.785 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.969 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.502 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.447 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.159 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=5.015 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=5.03 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.731 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.417 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 196.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 18.15 V at bus '896' — reflects the neutral shift under unbalanced loading.

