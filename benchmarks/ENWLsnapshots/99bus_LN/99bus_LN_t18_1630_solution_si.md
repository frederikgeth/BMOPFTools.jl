# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -153433.7554  
**Solve time:** 0.072 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 44.569 kW |
| Total load | 29.351 kW |
| Total network losses (P) | 15.219 kW |
| Total network losses (Q) | 4.538 kW var |
| Loss fraction | 51.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 13.255 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.071 (`949`) | 4.2 % (`313`) | 13.25 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `949` | 238.4 | 246.4 | 1.036 | 1.071 | 3.5 % | 12.93 V |
| ✅ | `896` | 237.7 | 246.3 | 1.034 | 1.071 | 3.7 % | 13.25 V |
| ✅ | `895` | 238.4 | 246.2 | 1.036 | 1.07 | 3.4 % | 12.7 V |
| ✅ | `904` | 238.4 | 246.0 | 1.036 | 1.07 | 3.3 % | 12.61 V |
| ✅ | `775` | 238.4 | 246.0 | 1.037 | 1.069 | 3.3 % | 12.47 V |
| ✅ | `849` | 238.4 | 245.9 | 1.036 | 1.069 | 3.3 % | 12.51 V |
| ✅ | `894` | 238.4 | 245.9 | 1.036 | 1.069 | 3.3 % | 12.34 V |
| ✅ | `661` | 237.8 | 245.8 | 1.034 | 1.069 | 3.5 % | 12.7 V |
| ✅ | `660` | 237.8 | 245.8 | 1.034 | 1.069 | 3.5 % | 12.8 V |
| ✅ | `654` | 237.8 | 245.8 | 1.034 | 1.069 | 3.5 % | 12.6 V |
| ✅ | `644` | 237.8 | 245.7 | 1.034 | 1.068 | 3.5 % | 12.58 V |
| ✅ | `677` | 237.8 | 245.7 | 1.034 | 1.068 | 3.5 % | 12.85 V |
| ✅ | `635` | 237.8 | 245.7 | 1.034 | 1.068 | 3.4 % | 12.52 V |
| ✅ | `808` | 238.9 | 245.6 | 1.039 | 1.068 | 2.9 % | 12.34 V |
| ✅ | `693` | 238.5 | 245.6 | 1.037 | 1.068 | 3.1 % | 12.2 V |
| ✅ | `673` | 238.4 | 245.6 | 1.037 | 1.068 | 3.1 % | 12.2 V |
| ✅ | `665` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 12.16 V |
| ✅ | `779` | 239.0 | 245.5 | 1.039 | 1.067 | 2.8 % | 12.41 V |
| ✅ | `659` | 238.4 | 245.5 | 1.037 | 1.067 | 3.1 % | 12.11 V |
| ✅ | `627` | 237.8 | 245.4 | 1.034 | 1.067 | 3.3 % | 12.01 V |
| ✅ | `617` | 237.8 | 245.4 | 1.034 | 1.067 | 3.3 % | 11.97 V |
| ✅ | `618` | 237.8 | 245.4 | 1.034 | 1.067 | 3.3 % | 11.97 V |
| ✅ | `608` | 237.8 | 245.3 | 1.034 | 1.067 | 3.3 % | 11.95 V |
| ✅ | `717` | 239.0 | 245.3 | 1.039 | 1.067 | 2.8 % | 12.56 V |
| ✅ | `655` | 239.0 | 245.3 | 1.039 | 1.067 | 2.8 % | 12.34 V |
| ✅ | `609` | 239.0 | 245.3 | 1.039 | 1.067 | 2.8 % | 12.3 V |
| ✅ | `773` | 239.0 | 245.3 | 1.039 | 1.067 | 2.8 % | 12.28 V |
| ✅ | `568` | 238.4 | 245.3 | 1.036 | 1.067 | 3.0 % | 11.94 V |
| ✅ | `607` | 237.8 | 245.3 | 1.034 | 1.067 | 3.3 % | 11.91 V |
| ✅ | `600` | 237.8 | 245.2 | 1.034 | 1.066 | 3.2 % | 11.83 V |
| ✅ | `545` | 237.8 | 244.9 | 1.034 | 1.065 | 3.1 % | 11.41 V |
| ✅ | `313` | 235.2 | 244.8 | 1.023 | 1.065 | 4.2 % | 10.92 V |
| ✅ | `303` | 235.2 | 244.8 | 1.023 | 1.064 | 4.2 % | 10.86 V |
| ✅ | `290` | 235.2 | 244.7 | 1.023 | 1.064 | 4.1 % | 10.79 V |
| ✅ | `282` | 235.3 | 244.7 | 1.023 | 1.064 | 4.1 % | 10.75 V |
| ✅ | `272` | 235.3 | 244.7 | 1.023 | 1.064 | 4.1 % | 10.67 V |
| ✅ | `321` | 235.3 | 244.5 | 1.023 | 1.063 | 4.0 % | 10.39 V |
| ✅ | `264` | 235.3 | 244.4 | 1.023 | 1.063 | 4.0 % | 10.29 V |
| ✅ | `498` | 235.7 | 244.2 | 1.025 | 1.062 | 3.7 % | 1.96 V |
| ✅ | `491` | 235.7 | 244.2 | 1.025 | 1.062 | 3.7 % | 1.95 V |
| ✅ | `263` | 235.3 | 244.2 | 1.023 | 1.062 | 3.8 % | 10.01 V |
| ✅ | `473` | 235.7 | 244.1 | 1.025 | 1.061 | 3.7 % | 1.96 V |
| ✅ | `254` | 235.3 | 244.1 | 1.023 | 1.061 | 3.8 % | 9.94 V |
| ✅ | `472` | 235.7 | 244.0 | 1.025 | 1.061 | 3.6 % | 1.96 V |
| ✅ | `439` | 235.7 | 244.0 | 1.025 | 1.061 | 3.6 % | 1.97 V |
| ✅ | `536` | 235.7 | 243.9 | 1.025 | 1.061 | 3.6 % | 1.98 V |
| ✅ | `229` | 235.4 | 243.9 | 1.023 | 1.06 | 3.7 % | 9.6 V |
| ✅ | `427` | 235.7 | 243.8 | 1.025 | 1.06 | 3.5 % | 2.01 V |
| ✅ | `216` | 235.4 | 243.8 | 1.023 | 1.06 | 3.7 % | 9.53 V |
| ✅ | `479` | 235.7 | 243.7 | 1.025 | 1.059 | 3.5 % | 2.05 V |
| ✅ | `377` | 235.7 | 243.6 | 1.025 | 1.059 | 3.4 % | 2.08 V |
| ✅ | `376` | 235.7 | 243.6 | 1.025 | 1.059 | 3.4 % | 2.1 V |
| ✅ | `192` | 235.4 | 243.5 | 1.023 | 1.059 | 3.5 % | 9.18 V |
| ✅ | `175` | 235.4 | 243.5 | 1.023 | 1.059 | 3.5 % | 9.11 V |
| ✅ | `354` | 235.7 | 243.5 | 1.025 | 1.059 | 3.4 % | 2.14 V |
| ✅ | `530` | 237.0 | 243.3 | 1.031 | 1.058 | 2.7 % | 9.24 V |
| ✅ | `521` | 235.7 | 243.2 | 1.025 | 1.057 | 3.3 % | 2.29 V |
| ✅ | `166` | 235.5 | 243.1 | 1.024 | 1.057 | 3.3 % | 8.49 V |
| ✅ | `307` | 235.7 | 243.1 | 1.025 | 1.057 | 3.2 % | 2.36 V |
| ✅ | `151` | 235.5 | 242.8 | 1.024 | 1.056 | 3.2 % | 8.18 V |
| ✅ | `256` | 235.7 | 242.7 | 1.025 | 1.055 | 3.1 % | 2.6 V |
| ✅ | `145` | 235.5 | 242.7 | 1.024 | 1.055 | 3.1 % | 8.1 V |
| ✅ | `247` | 235.7 | 242.6 | 1.025 | 1.055 | 3.0 % | 2.67 V |
| ✅ | `138` | 235.5 | 242.6 | 1.024 | 1.055 | 3.1 % | 7.99 V |
| ✅ | `144` | 235.5 | 242.6 | 1.024 | 1.055 | 3.1 % | 7.93 V |
| ✅ | `131` | 235.5 | 242.5 | 1.024 | 1.055 | 3.1 % | 7.87 V |
| ✅ | `428` | 237.5 | 242.5 | 1.033 | 1.054 | 2.2 % | 8.25 V |
| ✅ | `416` | 237.4 | 242.5 | 1.032 | 1.054 | 2.2 % | 8.19 V |
| ✅ | `380` | 237.4 | 242.5 | 1.032 | 1.054 | 2.2 % | 8.17 V |
| ✅ | `391` | 237.4 | 242.5 | 1.032 | 1.054 | 2.2 % | 8.16 V |
| ✅ | `392` | 237.4 | 242.5 | 1.032 | 1.054 | 2.2 % | 8.16 V |
| ✅ | `366` | 237.3 | 242.5 | 1.032 | 1.054 | 2.3 % | 8.12 V |
| ✅ | `355` | 237.2 | 242.5 | 1.031 | 1.054 | 2.3 % | 8.1 V |
| ✅ | `441` | 237.1 | 242.5 | 1.031 | 1.054 | 2.3 % | 8.03 V |
| ✅ | `327` | 237.0 | 242.5 | 1.03 | 1.054 | 2.4 % | 7.96 V |
| ✅ | `348` | 237.2 | 242.5 | 1.031 | 1.054 | 2.3 % | 8.09 V |
| ✅ | `384` | 236.9 | 242.5 | 1.03 | 1.054 | 2.4 % | 7.94 V |
| ✅ | `318` | 236.9 | 242.5 | 1.03 | 1.054 | 2.4 % | 7.92 V |
| ✅ | `300` | 236.7 | 242.4 | 1.029 | 1.054 | 2.5 % | 7.87 V |
| ✅ | `226` | 235.7 | 242.1 | 1.025 | 1.053 | 2.8 % | 3.08 V |
| ✅ | `220` | 235.7 | 242.1 | 1.025 | 1.052 | 2.8 % | 3.15 V |
| ✅ | `116` | 235.6 | 242.0 | 1.024 | 1.052 | 2.8 % | 7.03 V |
| ✅ | `128` | 235.6 | 241.9 | 1.024 | 1.052 | 2.7 % | 6.84 V |
| ✅ | `198` | 235.6 | 241.7 | 1.024 | 1.051 | 2.7 % | 6.75 V |
| ✅ | `104` | 235.6 | 241.7 | 1.024 | 1.051 | 2.7 % | 6.8 V |
| ✅ | `108` | 235.6 | 241.6 | 1.024 | 1.05 | 2.6 % | 6.62 V |
| ✅ | `99` | 235.6 | 241.5 | 1.024 | 1.05 | 2.6 % | 6.58 V |
| ✅ | `219` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 3.7 V |
| ✅ | `208` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 3.78 V |
| ✅ | `201` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.74 V |
| ✅ | `188` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 4.83 V |
| ✅ | `179` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 5.58 V |
| ✅ | `162` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 5.67 V |
| ✅ | `187` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 6.01 V |
| ✅ | `147` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 6.07 V |
| ✅ | `90` | 235.7 | 241.5 | 1.025 | 1.05 | 2.5 % | 6.45 V |
| ✅ | `82` | 235.6 | 241.4 | 1.025 | 1.05 | 2.5 % | 6.47 V |
| ✅ | `62` | 234.3 | 238.0 | 1.019 | 1.035 | 1.6 % | 4.51 V |
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
  Line losses are 51.9 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 13.25 V at bus '896' — reflects the neutral shift under unbalanced loading.

