# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:18  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -201206.1064  
**Solve time:** 0.053 s  
**Findings:** 26 errors · 31 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 37.507 kW |
| Total load | 13.109 kW |
| Total network losses (P) | 24.398 kW |
| Total network losses (Q) | 7.055 kW var |
| Loss fraction | 186.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 18.328 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.097 (`896`) | 5.2 % (`313`) | 18.33 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 241.5 | 252.3 | 1.05 | 1.097 | 4.7 % | 18.33 V |
| ✅ | `949` | 241.9 | 251.8 | 1.052 | 1.095 | 4.3 % | 17.4 V |
| ✅ | `677` | 241.5 | 251.8 | 1.05 | 1.095 | 4.5 % | 17.75 V |
| ✅ | `660` | 241.5 | 251.8 | 1.05 | 1.095 | 4.5 % | 17.68 V |
| ✅ | `661` | 241.5 | 251.7 | 1.05 | 1.094 | 4.4 % | 17.54 V |
| ✅ | `654` | 241.5 | 251.6 | 1.05 | 1.094 | 4.4 % | 17.41 V |
| ✅ | `644` | 241.5 | 251.6 | 1.05 | 1.094 | 4.4 % | 17.39 V |
| ✅ | `895` | 241.9 | 251.5 | 1.052 | 1.094 | 4.2 % | 17.08 V |
| ✅ | `635` | 241.5 | 251.5 | 1.05 | 1.093 | 4.3 % | 17.3 V |
| ✅ | `904` | 241.9 | 251.4 | 1.052 | 1.093 | 4.1 % | 16.95 V |
| ✅ | `775` | 241.8 | 251.3 | 1.051 | 1.093 | 4.1 % | 16.98 V |
| ✅ | `849` | 241.9 | 251.3 | 1.052 | 1.093 | 4.1 % | 16.81 V |
| ✅ | `894` | 242.6 | 251.3 | 1.055 | 1.093 | 3.8 % | 15.77 V |
| ✅ | `808` | 241.8 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.94 V |
| ✅ | `693` | 241.8 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.58 V |
| ✅ | `673` | 241.8 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.57 V |
| ✅ | `627` | 241.5 | 250.9 | 1.05 | 1.091 | 4.1 % | 16.56 V |
| ✅ | `665` | 241.8 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.51 V |
| ✅ | `617` | 241.5 | 250.8 | 1.05 | 1.091 | 4.1 % | 16.51 V |
| ✅ | `618` | 241.5 | 250.8 | 1.05 | 1.091 | 4.1 % | 16.51 V |
| ✅ | `608` | 241.5 | 250.8 | 1.05 | 1.09 | 4.0 % | 16.48 V |
| ✅ | `779` | 241.8 | 250.8 | 1.051 | 1.09 | 3.9 % | 16.74 V |
| ✅ | `659` | 241.8 | 250.8 | 1.051 | 1.09 | 3.9 % | 16.45 V |
| ✅ | `607` | 241.5 | 250.8 | 1.05 | 1.09 | 4.0 % | 16.42 V |
| ✅ | `600` | 241.5 | 250.7 | 1.05 | 1.09 | 4.0 % | 16.31 V |
| ✅ | `717` | 241.7 | 250.7 | 1.051 | 1.09 | 3.9 % | 17.0 V |
| ✅ | `655` | 241.7 | 250.6 | 1.051 | 1.09 | 3.9 % | 16.75 V |
| ✅ | `609` | 241.7 | 250.6 | 1.051 | 1.09 | 3.9 % | 16.7 V |
| ✅ | `773` | 241.7 | 250.6 | 1.051 | 1.09 | 3.9 % | 16.59 V |
| ✅ | `568` | 241.7 | 250.6 | 1.051 | 1.09 | 3.9 % | 16.26 V |
| ✅ | `545` | 241.5 | 250.2 | 1.05 | 1.088 | 3.7 % | 15.7 V |
| ✅ | `313` | 237.9 | 249.8 | 1.034 | 1.086 | 5.2 % | 15.38 V |
| ✅ | `303` | 237.9 | 249.8 | 1.034 | 1.086 | 5.2 % | 15.3 V |
| ✅ | `290` | 237.9 | 249.7 | 1.034 | 1.086 | 5.1 % | 15.22 V |
| ✅ | `282` | 237.9 | 249.7 | 1.034 | 1.085 | 5.1 % | 15.18 V |
| ✅ | `272` | 237.9 | 249.6 | 1.034 | 1.085 | 5.1 % | 15.08 V |
| ✅ | `321` | 237.9 | 249.3 | 1.035 | 1.084 | 4.9 % | 14.75 V |
| ✅ | `264` | 238.0 | 249.2 | 1.035 | 1.084 | 4.9 % | 14.65 V |
| ✅ | `263` | 238.0 | 249.0 | 1.035 | 1.082 | 4.8 % | 14.33 V |
| ✅ | `254` | 238.0 | 248.9 | 1.035 | 1.082 | 4.7 % | 14.25 V |
| ✅ | `229` | 238.0 | 248.6 | 1.035 | 1.081 | 4.6 % | 13.86 V |
| ✅ | `216` | 238.0 | 248.5 | 1.035 | 1.08 | 4.6 % | 13.76 V |
| ✅ | `192` | 238.1 | 248.2 | 1.035 | 1.079 | 4.4 % | 13.37 V |
| ✅ | `175` | 238.1 | 248.1 | 1.035 | 1.079 | 4.4 % | 13.28 V |
| ✅ | `530` | 240.6 | 248.0 | 1.046 | 1.078 | 3.3 % | 12.94 V |
| ✅ | `166` | 238.2 | 247.6 | 1.035 | 1.076 | 4.1 % | 12.54 V |
| ✅ | `498` | 238.4 | 247.5 | 1.037 | 1.076 | 4.0 % | 8.21 V |
| ✅ | `491` | 238.4 | 247.5 | 1.037 | 1.076 | 3.9 % | 8.19 V |
| ✅ | `473` | 238.4 | 247.4 | 1.037 | 1.076 | 3.9 % | 8.16 V |
| ✅ | `472` | 238.4 | 247.3 | 1.037 | 1.075 | 3.9 % | 8.14 V |
| ✅ | `439` | 238.4 | 247.2 | 1.037 | 1.075 | 3.8 % | 8.11 V |
| ✅ | `151` | 238.2 | 247.2 | 1.036 | 1.075 | 3.9 % | 12.14 V |
| ✅ | `536` | 238.4 | 247.1 | 1.037 | 1.074 | 3.8 % | 8.1 V |
| ✅ | `145` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 12.04 V |
| ✅ | `427` | 238.4 | 247.0 | 1.037 | 1.074 | 3.7 % | 8.07 V |
| ✅ | `138` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 11.9 V |
| ✅ | `144` | 238.2 | 246.9 | 1.036 | 1.074 | 3.8 % | 11.84 V |
| ✅ | `428` | 241.0 | 246.9 | 1.048 | 1.073 | 2.5 % | 11.53 V |
| ✅ | `416` | 241.0 | 246.9 | 1.048 | 1.073 | 2.6 % | 11.51 V |
| ✅ | `131` | 238.2 | 246.9 | 1.036 | 1.073 | 3.8 % | 11.76 V |
| ✅ | `391` | 240.9 | 246.9 | 1.047 | 1.073 | 2.6 % | 11.49 V |
| ✅ | `392` | 240.8 | 246.9 | 1.047 | 1.073 | 2.6 % | 11.48 V |
| ✅ | `380` | 240.8 | 246.9 | 1.047 | 1.073 | 2.6 % | 11.48 V |
| ✅ | `366` | 240.7 | 246.9 | 1.047 | 1.073 | 2.7 % | 11.45 V |
| ✅ | `355` | 240.7 | 246.9 | 1.046 | 1.073 | 2.7 % | 11.44 V |
| ✅ | `441` | 240.4 | 246.8 | 1.045 | 1.073 | 2.8 % | 11.39 V |
| ✅ | `479` | 238.4 | 246.8 | 1.037 | 1.073 | 3.7 % | 8.04 V |
| ✅ | `348` | 240.7 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.51 V |
| ✅ | `327` | 240.3 | 246.8 | 1.045 | 1.073 | 2.8 % | 11.36 V |
| ✅ | `384` | 240.2 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.35 V |
| ✅ | `318` | 240.2 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.34 V |
| ✅ | `300` | 240.0 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.31 V |
| ✅ | `377` | 238.4 | 246.7 | 1.037 | 1.073 | 3.6 % | 8.02 V |
| ✅ | `376` | 238.4 | 246.7 | 1.037 | 1.073 | 3.6 % | 8.01 V |
| ✅ | `354` | 238.4 | 246.6 | 1.037 | 1.072 | 3.6 % | 8.0 V |
| ✅ | `521` | 238.4 | 246.2 | 1.037 | 1.071 | 3.4 % | 7.96 V |
| ✅ | `307` | 238.4 | 246.1 | 1.037 | 1.07 | 3.4 % | 7.96 V |
| ✅ | `116` | 238.3 | 246.1 | 1.036 | 1.07 | 3.4 % | 10.76 V |
| ✅ | `128` | 238.3 | 246.0 | 1.036 | 1.069 | 3.3 % | 10.57 V |
| ✅ | `104` | 238.3 | 245.8 | 1.036 | 1.069 | 3.2 % | 10.42 V |
| ✅ | `198` | 238.3 | 245.8 | 1.036 | 1.069 | 3.2 % | 10.37 V |
| ✅ | `256` | 238.4 | 245.7 | 1.037 | 1.068 | 3.2 % | 7.96 V |
| ✅ | `247` | 238.4 | 245.6 | 1.037 | 1.068 | 3.1 % | 7.97 V |
| ✅ | `108` | 238.3 | 245.6 | 1.036 | 1.068 | 3.2 % | 10.19 V |
| ✅ | `99` | 238.3 | 245.5 | 1.036 | 1.068 | 3.1 % | 10.13 V |
| ✅ | `226` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.03 V |
| ✅ | `220` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.06 V |
| ✅ | `219` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.23 V |
| ✅ | `208` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.27 V |
| ✅ | `201` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.76 V |
| ✅ | `188` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 8.83 V |
| ✅ | `179` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 9.32 V |
| ✅ | `162` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 9.41 V |
| ✅ | `187` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 9.63 V |
| ✅ | `147` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 9.72 V |
| ✅ | `90` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 9.98 V |
| ✅ | `82` | 238.4 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.99 V |
| ✅ | `62` | 236.2 | 240.7 | 1.027 | 1.046 | 2.0 % | 6.81 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.937 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.921 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.221 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.859 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.077 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.135 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.772 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=5.25 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.249 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=5.181 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.74 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.967 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=5.2 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.213 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.741 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.792 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.199 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=5.248 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.787 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.239 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.896 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.738 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.743 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.212 kW is within 1 % of its P bound.
- **ERROR** `E.SOL.IBR_VIOLATION` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': |S|=5.251 kW exceeds s_max=5.25 kW (apparent-power circle violated).
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.811 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 186.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 18.33 V at bus '896' — reflects the neutral shift under unbalanced loading.

