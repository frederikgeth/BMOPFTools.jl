# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:19  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -154405.0366  
**Solve time:** 0.046 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 43.599 kW |
| Total load | 29.351 kW |
| Total network losses (P) | 14.248 kW |
| Total network losses (Q) | 4.166 kW var |
| Loss fraction | 48.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 14.178 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.076 (`949`) | 4.2 % (`313`) | 14.18 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 238.2 | 247.5 | 1.036 | 1.076 | 4.0 % | 14.16 V |
| ✅ | `896` | 238.2 | 247.4 | 1.036 | 1.076 | 4.0 % | 14.18 V |
| ✅ | `895` | 238.3 | 247.3 | 1.036 | 1.075 | 3.9 % | 13.9 V |
| ✅ | `904` | 238.3 | 247.1 | 1.036 | 1.075 | 3.9 % | 13.8 V |
| ✅ | `775` | 238.3 | 247.1 | 1.036 | 1.074 | 3.8 % | 13.65 V |
| ✅ | `849` | 238.3 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.68 V |
| ✅ | `894` | 238.3 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.63 V |
| ✅ | `661` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 13.65 V |
| ✅ | `660` | 238.3 | 246.9 | 1.036 | 1.074 | 3.8 % | 13.7 V |
| ✅ | `654` | 238.2 | 246.9 | 1.036 | 1.073 | 3.8 % | 13.56 V |
| ✅ | `677` | 238.3 | 246.9 | 1.036 | 1.073 | 3.7 % | 13.73 V |
| ✅ | `644` | 238.3 | 246.9 | 1.036 | 1.073 | 3.7 % | 13.53 V |
| ✅ | `635` | 238.3 | 246.8 | 1.036 | 1.073 | 3.7 % | 13.48 V |
| ✅ | `808` | 238.3 | 246.7 | 1.036 | 1.073 | 3.7 % | 13.51 V |
| ✅ | `693` | 238.3 | 246.7 | 1.036 | 1.073 | 3.7 % | 13.32 V |
| ✅ | `673` | 238.3 | 246.7 | 1.036 | 1.073 | 3.7 % | 13.32 V |
| ✅ | `665` | 238.3 | 246.6 | 1.036 | 1.072 | 3.6 % | 13.27 V |
| ✅ | `779` | 238.3 | 246.6 | 1.036 | 1.072 | 3.6 % | 13.5 V |
| ✅ | `659` | 238.3 | 246.6 | 1.036 | 1.072 | 3.6 % | 13.21 V |
| ✅ | `627` | 238.3 | 246.5 | 1.036 | 1.072 | 3.6 % | 13.0 V |
| ✅ | `617` | 238.3 | 246.5 | 1.036 | 1.072 | 3.6 % | 12.97 V |
| ✅ | `618` | 238.3 | 246.5 | 1.036 | 1.072 | 3.6 % | 12.97 V |
| ✅ | `717` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 13.64 V |
| ✅ | `655` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 13.42 V |
| ✅ | `608` | 238.3 | 246.4 | 1.036 | 1.071 | 3.6 % | 12.95 V |
| ✅ | `609` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 13.38 V |
| ✅ | `773` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 13.33 V |
| ✅ | `568` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 13.0 V |
| ✅ | `607` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 12.9 V |
| ✅ | `600` | 238.3 | 246.3 | 1.036 | 1.071 | 3.5 % | 12.82 V |
| ✅ | `545` | 238.3 | 246.0 | 1.036 | 1.069 | 3.4 % | 12.4 V |
| ✅ | `313` | 236.2 | 245.9 | 1.027 | 1.069 | 4.2 % | 11.8 V |
| ✅ | `303` | 236.2 | 245.9 | 1.027 | 1.069 | 4.2 % | 11.75 V |
| ✅ | `290` | 236.2 | 245.8 | 1.027 | 1.069 | 4.2 % | 11.68 V |
| ✅ | `282` | 236.2 | 245.8 | 1.027 | 1.069 | 4.2 % | 11.64 V |
| ✅ | `272` | 236.2 | 245.7 | 1.027 | 1.068 | 4.1 % | 11.57 V |
| ✅ | `321` | 236.2 | 245.5 | 1.027 | 1.067 | 4.0 % | 11.31 V |
| ✅ | `264` | 236.3 | 245.4 | 1.027 | 1.067 | 4.0 % | 11.22 V |
| ✅ | `263` | 236.3 | 245.2 | 1.027 | 1.066 | 3.9 % | 10.96 V |
| ✅ | `254` | 236.3 | 245.2 | 1.027 | 1.066 | 3.9 % | 10.89 V |
| ✅ | `229` | 236.3 | 244.9 | 1.027 | 1.065 | 3.7 % | 10.58 V |
| ✅ | `216` | 236.3 | 244.8 | 1.027 | 1.064 | 3.7 % | 10.5 V |
| ✅ | `192` | 236.3 | 244.5 | 1.028 | 1.063 | 3.6 % | 10.17 V |
| ✅ | `175` | 236.3 | 244.5 | 1.028 | 1.063 | 3.5 % | 10.12 V |
| ✅ | `530` | 238.3 | 244.4 | 1.036 | 1.062 | 2.6 % | 10.11 V |
| ✅ | `166` | 236.4 | 244.1 | 1.028 | 1.061 | 3.3 % | 9.57 V |
| ✅ | `151` | 236.4 | 243.7 | 1.028 | 1.06 | 3.2 % | 9.24 V |
| ✅ | `498` | 236.6 | 243.7 | 1.029 | 1.059 | 3.1 % | 5.48 V |
| ✅ | `145` | 236.4 | 243.7 | 1.028 | 1.059 | 3.2 % | 9.16 V |
| ✅ | `491` | 236.6 | 243.6 | 1.029 | 1.059 | 3.1 % | 5.47 V |
| ✅ | `138` | 236.4 | 243.6 | 1.028 | 1.059 | 3.1 % | 9.05 V |
| ✅ | `473` | 236.6 | 243.6 | 1.029 | 1.059 | 3.0 % | 5.46 V |
| ✅ | `144` | 236.4 | 243.5 | 1.028 | 1.059 | 3.1 % | 8.99 V |
| ✅ | `131` | 236.4 | 243.5 | 1.028 | 1.059 | 3.1 % | 8.94 V |
| ✅ | `472` | 236.6 | 243.5 | 1.029 | 1.059 | 3.0 % | 5.45 V |
| ✅ | `428` | 238.4 | 243.5 | 1.037 | 1.059 | 2.2 % | 8.93 V |
| ✅ | `416` | 238.4 | 243.5 | 1.037 | 1.059 | 2.2 % | 8.9 V |
| ✅ | `380` | 238.4 | 243.5 | 1.037 | 1.058 | 2.2 % | 8.89 V |
| ✅ | `391` | 238.4 | 243.5 | 1.037 | 1.058 | 2.2 % | 8.89 V |
| ✅ | `392` | 238.4 | 243.5 | 1.037 | 1.058 | 2.2 % | 8.89 V |
| ✅ | `366` | 238.4 | 243.4 | 1.037 | 1.058 | 2.2 % | 8.86 V |
| ✅ | `355` | 238.4 | 243.4 | 1.036 | 1.058 | 2.2 % | 8.85 V |
| ✅ | `441` | 238.2 | 243.4 | 1.036 | 1.058 | 2.3 % | 8.81 V |
| ✅ | `327` | 238.1 | 243.4 | 1.035 | 1.058 | 2.3 % | 8.78 V |
| ✅ | `348` | 238.3 | 243.4 | 1.036 | 1.058 | 2.2 % | 8.86 V |
| ✅ | `384` | 238.0 | 243.4 | 1.035 | 1.058 | 2.3 % | 8.76 V |
| ✅ | `318` | 238.0 | 243.4 | 1.035 | 1.058 | 2.4 % | 8.76 V |
| ✅ | `439` | 236.6 | 243.4 | 1.029 | 1.058 | 3.0 % | 5.44 V |
| ✅ | `300` | 237.9 | 243.4 | 1.034 | 1.058 | 2.4 % | 8.73 V |
| ✅ | `536` | 236.6 | 243.3 | 1.029 | 1.058 | 2.9 % | 5.43 V |
| ✅ | `427` | 236.6 | 243.3 | 1.029 | 1.058 | 2.9 % | 5.42 V |
| ✅ | `479` | 236.6 | 243.1 | 1.029 | 1.057 | 2.8 % | 5.41 V |
| ✅ | `377` | 236.6 | 243.0 | 1.029 | 1.057 | 2.8 % | 5.4 V |
| ✅ | `376` | 236.6 | 243.0 | 1.029 | 1.056 | 2.8 % | 5.4 V |
| ✅ | `354` | 236.6 | 242.9 | 1.029 | 1.056 | 2.7 % | 5.4 V |
| ✅ | `116` | 236.5 | 242.9 | 1.028 | 1.056 | 2.8 % | 8.17 V |
| ✅ | `128` | 236.5 | 242.8 | 1.028 | 1.055 | 2.7 % | 8.01 V |
| ✅ | `521` | 236.6 | 242.6 | 1.029 | 1.055 | 2.6 % | 5.41 V |
| ✅ | `198` | 236.5 | 242.6 | 1.028 | 1.055 | 2.6 % | 7.9 V |
| ✅ | `104` | 236.5 | 242.6 | 1.028 | 1.055 | 2.6 % | 7.92 V |
| ✅ | `307` | 236.6 | 242.5 | 1.029 | 1.054 | 2.6 % | 5.42 V |
| ✅ | `108` | 236.5 | 242.5 | 1.028 | 1.054 | 2.6 % | 7.74 V |
| ✅ | `99` | 236.6 | 242.4 | 1.028 | 1.054 | 2.6 % | 7.7 V |
| ✅ | `256` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.46 V |
| ✅ | `247` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.48 V |
| ✅ | `226` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.61 V |
| ✅ | `220` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.63 V |
| ✅ | `219` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.86 V |
| ✅ | `208` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 5.91 V |
| ✅ | `201` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 6.43 V |
| ✅ | `188` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 6.49 V |
| ✅ | `179` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 6.98 V |
| ✅ | `162` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 7.05 V |
| ✅ | `187` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 7.29 V |
| ✅ | `147` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 7.34 V |
| ✅ | `90` | 236.6 | 242.4 | 1.029 | 1.054 | 2.5 % | 7.58 V |
| ✅ | `82` | 236.6 | 242.3 | 1.029 | 1.054 | 2.5 % | 7.58 V |
| ✅ | `62` | 234.8 | 238.5 | 1.021 | 1.037 | 1.6 % | 5.19 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.378 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=3.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.863 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.58 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.83 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.142 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.019 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=3.775 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.307 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=3.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.267 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=3.795 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=3.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=3.965 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=3.917 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=3.756 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.175 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.389 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=3.941 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.975 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=3.888 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.016 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.819 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.063 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.458 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=3.793 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.109 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=3.846 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.146 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.849 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.32 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=3.816 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.555 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.437 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.127 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.302 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.318 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.379 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.24 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.497 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.48 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.429 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 48.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 14.18 V at bus '896' — reflects the neutral shift under unbalanced loading.

