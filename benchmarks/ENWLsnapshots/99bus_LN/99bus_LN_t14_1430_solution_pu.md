# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -192506.9638  
**Solve time:** 0.065 s  
**Findings:** 25 errors · 27 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 38.519 kW |
| Total load | 14.852 kW |
| Total network losses (P) | 23.667 kW |
| Total network losses (Q) | 7.046 kW var |
| Loss fraction | 159.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.327 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.086 (`896`) | 4.9 % (`498`) | 15.33 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.4 | 249.9 | 1.041 | 1.086 | 4.6 % | 15.33 V |
| ✅ | `949` | 240.1 | 249.6 | 1.044 | 1.085 | 4.1 % | 14.37 V |
| ✅ | `677` | 239.4 | 249.4 | 1.041 | 1.084 | 4.4 % | 14.84 V |
| ✅ | `660` | 239.4 | 249.4 | 1.041 | 1.084 | 4.4 % | 14.75 V |
| ✅ | `661` | 239.4 | 249.4 | 1.041 | 1.084 | 4.3 % | 14.62 V |
| ✅ | `895` | 240.2 | 249.3 | 1.044 | 1.084 | 4.0 % | 14.09 V |
| ✅ | `654` | 239.4 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.49 V |
| ✅ | `644` | 239.4 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.47 V |
| ✅ | `904` | 240.2 | 249.2 | 1.044 | 1.083 | 3.9 % | 13.99 V |
| ✅ | `635` | 239.4 | 249.2 | 1.041 | 1.083 | 4.3 % | 14.39 V |
| ✅ | `775` | 240.2 | 249.1 | 1.044 | 1.083 | 3.9 % | 14.01 V |
| ✅ | `849` | 240.2 | 249.1 | 1.044 | 1.083 | 3.9 % | 13.87 V |
| ✅ | `894` | 240.2 | 249.1 | 1.044 | 1.083 | 3.9 % | 12.88 V |
| ✅ | `808` | 241.0 | 248.7 | 1.048 | 1.081 | 3.3 % | 14.03 V |
| ✅ | `693` | 240.3 | 248.7 | 1.045 | 1.081 | 3.7 % | 13.69 V |
| ✅ | `673` | 240.2 | 248.7 | 1.044 | 1.081 | 3.7 % | 13.68 V |
| ✅ | `627` | 239.4 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.7 V |
| ✅ | `665` | 240.2 | 248.7 | 1.044 | 1.081 | 3.7 % | 13.63 V |
| ✅ | `617` | 239.4 | 248.6 | 1.041 | 1.081 | 4.0 % | 13.66 V |
| ✅ | `618` | 239.4 | 248.6 | 1.041 | 1.081 | 4.0 % | 13.66 V |
| ✅ | `779` | 240.8 | 248.6 | 1.047 | 1.081 | 3.4 % | 13.9 V |
| ✅ | `608` | 239.4 | 248.6 | 1.041 | 1.081 | 4.0 % | 13.63 V |
| ✅ | `659` | 240.2 | 248.6 | 1.044 | 1.081 | 3.7 % | 13.58 V |
| ✅ | `607` | 239.4 | 248.6 | 1.041 | 1.081 | 4.0 % | 13.57 V |
| ✅ | `600` | 239.4 | 248.5 | 1.041 | 1.08 | 3.9 % | 13.47 V |
| ✅ | `717` | 241.6 | 248.5 | 1.05 | 1.08 | 3.0 % | 14.14 V |
| ✅ | `655` | 241.1 | 248.5 | 1.048 | 1.08 | 3.2 % | 13.89 V |
| ✅ | `609` | 241.0 | 248.4 | 1.048 | 1.08 | 3.2 % | 13.84 V |
| ✅ | `773` | 240.8 | 248.4 | 1.047 | 1.08 | 3.3 % | 13.75 V |
| ✅ | `568` | 240.1 | 248.4 | 1.044 | 1.08 | 3.6 % | 13.42 V |
| ✅ | `498` | 236.9 | 248.1 | 1.03 | 1.079 | 4.9 % | 3.45 V |
| ✅ | `491` | 236.9 | 248.1 | 1.03 | 1.079 | 4.9 % | 3.41 V |
| ✅ | `545` | 239.5 | 248.0 | 1.041 | 1.078 | 3.7 % | 12.92 V |
| ✅ | `473` | 236.9 | 248.0 | 1.03 | 1.078 | 4.8 % | 3.37 V |
| ✅ | `472` | 236.9 | 247.9 | 1.03 | 1.078 | 4.8 % | 3.34 V |
| ✅ | `439` | 236.9 | 247.8 | 1.03 | 1.077 | 4.7 % | 3.3 V |
| ✅ | `536` | 236.9 | 247.8 | 1.03 | 1.077 | 4.7 % | 3.28 V |
| ✅ | `427` | 236.9 | 247.6 | 1.03 | 1.077 | 4.7 % | 3.25 V |
| ✅ | `313` | 236.4 | 247.5 | 1.028 | 1.076 | 4.8 % | 12.56 V |
| ✅ | `479` | 236.9 | 247.5 | 1.03 | 1.076 | 4.6 % | 3.2 V |
| ✅ | `303` | 236.4 | 247.4 | 1.028 | 1.076 | 4.8 % | 12.48 V |
| ✅ | `377` | 236.9 | 247.4 | 1.03 | 1.075 | 4.5 % | 3.18 V |
| ✅ | `290` | 236.4 | 247.4 | 1.028 | 1.075 | 4.8 % | 12.4 V |
| ✅ | `376` | 236.9 | 247.3 | 1.03 | 1.075 | 4.5 % | 3.17 V |
| ✅ | `282` | 236.4 | 247.3 | 1.028 | 1.075 | 4.7 % | 12.37 V |
| ✅ | `272` | 236.4 | 247.3 | 1.028 | 1.075 | 4.7 % | 12.27 V |
| ✅ | `354` | 236.9 | 247.2 | 1.03 | 1.075 | 4.5 % | 3.17 V |
| ✅ | `321` | 236.4 | 247.1 | 1.028 | 1.074 | 4.6 % | 11.96 V |
| ✅ | `264` | 236.5 | 247.0 | 1.028 | 1.074 | 4.6 % | 11.85 V |
| ✅ | `521` | 236.9 | 246.9 | 1.03 | 1.073 | 4.3 % | 3.16 V |
| ✅ | `263` | 236.5 | 246.8 | 1.028 | 1.073 | 4.5 % | 11.55 V |
| ✅ | `307` | 236.9 | 246.7 | 1.03 | 1.073 | 4.3 % | 3.18 V |
| ✅ | `254` | 236.5 | 246.7 | 1.028 | 1.073 | 4.4 % | 11.46 V |
| ✅ | `229` | 236.5 | 246.5 | 1.028 | 1.072 | 4.3 % | 11.08 V |
| ✅ | `216` | 236.5 | 246.4 | 1.028 | 1.071 | 4.3 % | 10.98 V |
| ✅ | `256` | 236.9 | 246.3 | 1.03 | 1.071 | 4.1 % | 3.26 V |
| ✅ | `247` | 236.9 | 246.2 | 1.03 | 1.071 | 4.1 % | 3.3 V |
| ✅ | `192` | 236.6 | 246.1 | 1.029 | 1.07 | 4.2 % | 10.6 V |
| ✅ | `175` | 236.6 | 246.1 | 1.029 | 1.07 | 4.1 % | 10.5 V |
| ✅ | `530` | 238.5 | 246.0 | 1.037 | 1.07 | 3.3 % | 10.39 V |
| ✅ | `166` | 236.7 | 245.7 | 1.029 | 1.068 | 3.9 % | 9.77 V |
| ✅ | `226` | 236.9 | 245.6 | 1.03 | 1.068 | 3.8 % | 3.58 V |
| ✅ | `220` | 236.9 | 245.5 | 1.03 | 1.068 | 3.8 % | 3.64 V |
| ✅ | `151` | 236.7 | 245.3 | 1.029 | 1.066 | 3.7 % | 9.38 V |
| ✅ | `145` | 236.7 | 245.2 | 1.029 | 1.066 | 3.7 % | 9.28 V |
| ✅ | `138` | 236.7 | 245.1 | 1.029 | 1.066 | 3.7 % | 9.15 V |
| ✅ | `144` | 236.7 | 245.1 | 1.029 | 1.065 | 3.6 % | 9.09 V |
| ✅ | `428` | 239.2 | 245.0 | 1.04 | 1.065 | 2.5 % | 9.26 V |
| ✅ | `416` | 239.1 | 245.0 | 1.04 | 1.065 | 2.6 % | 9.22 V |
| ✅ | `391` | 239.0 | 245.0 | 1.039 | 1.065 | 2.6 % | 9.17 V |
| ✅ | `392` | 239.0 | 245.0 | 1.039 | 1.065 | 2.6 % | 9.17 V |
| ✅ | `380` | 239.0 | 245.0 | 1.039 | 1.065 | 2.6 % | 9.17 V |
| ✅ | `366` | 238.9 | 245.0 | 1.039 | 1.065 | 2.7 % | 9.11 V |
| ✅ | `131` | 236.7 | 245.0 | 1.029 | 1.065 | 3.6 % | 9.01 V |
| ✅ | `355` | 238.8 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.09 V |
| ✅ | `441` | 238.6 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.99 V |
| ✅ | `327` | 238.5 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.92 V |
| ✅ | `348` | 238.8 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.11 V |
| ✅ | `384` | 238.4 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.89 V |
| ✅ | `318` | 238.3 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.87 V |
| ✅ | `300` | 238.2 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.82 V |
| ✅ | `219` | 236.9 | 244.8 | 1.03 | 1.064 | 3.4 % | 4.13 V |
| ✅ | `208` | 236.9 | 244.7 | 1.03 | 1.064 | 3.4 % | 4.21 V |
| ✅ | `116` | 236.8 | 244.4 | 1.03 | 1.063 | 3.3 % | 8.01 V |
| ✅ | `128` | 236.8 | 244.3 | 1.03 | 1.062 | 3.2 % | 7.78 V |
| ✅ | `198` | 236.8 | 244.1 | 1.03 | 1.061 | 3.1 % | 7.64 V |
| ✅ | `104` | 236.8 | 244.0 | 1.03 | 1.061 | 3.1 % | 7.69 V |
| ✅ | `108` | 236.8 | 243.9 | 1.03 | 1.06 | 3.1 % | 7.46 V |
| ✅ | `99` | 236.8 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.41 V |
| ✅ | `201` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.21 V |
| ✅ | `188` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.33 V |
| ✅ | `179` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.19 V |
| ✅ | `162` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.31 V |
| ✅ | `187` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.67 V |
| ✅ | `147` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.78 V |
| ✅ | `90` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.24 V |
| ✅ | `82` | 236.9 | 243.7 | 1.03 | 1.06 | 3.0 % | 7.27 V |
| ✅ | `62` | 235.2 | 239.6 | 1.023 | 1.042 | 1.9 % | 5.07 V |
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
  IBR 'pv_37' phase 'a': pg=4.859 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.743 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.338 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.694 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=5.019 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.74 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.176 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.741 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.896 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.769 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.811 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.541 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.922 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.753 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.233 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.643 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.762 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': |S|=5.25 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.077 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.242 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.787 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.64 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 159.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.33 V at bus '896' — reflects the neutral shift under unbalanced loading.

