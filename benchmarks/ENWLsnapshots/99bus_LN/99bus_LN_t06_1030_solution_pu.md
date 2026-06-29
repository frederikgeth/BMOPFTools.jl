# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:23  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -129996.4184  
**Solve time:** 0.048 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.12 kW |
| Total load | 12.685 kW |
| Total network losses (P) | 10.435 kW |
| Total network losses (Q) | 3.034 kW var |
| Loss fraction | 82.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 11.642 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.064 (`896`) | 3.7 % (`313`) | 11.64 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 236.5 | 244.7 | 1.028 | 1.064 | 3.6 % | 11.64 V |
| ✅ | `949` | 237.0 | 244.4 | 1.03 | 1.063 | 3.2 % | 10.98 V |
| ✅ | `660` | 236.5 | 244.3 | 1.028 | 1.062 | 3.4 % | 11.18 V |
| ✅ | `677` | 236.5 | 244.3 | 1.028 | 1.062 | 3.4 % | 11.23 V |
| ✅ | `661` | 236.5 | 244.3 | 1.028 | 1.062 | 3.4 % | 11.09 V |
| ✅ | `654` | 236.5 | 244.2 | 1.028 | 1.062 | 3.4 % | 10.99 V |
| ✅ | `895` | 237.0 | 244.2 | 1.03 | 1.062 | 3.1 % | 10.75 V |
| ✅ | `644` | 236.5 | 244.2 | 1.028 | 1.062 | 3.3 % | 10.98 V |
| ✅ | `635` | 236.5 | 244.1 | 1.028 | 1.061 | 3.3 % | 10.92 V |
| ✅ | `904` | 237.0 | 244.1 | 1.03 | 1.061 | 3.1 % | 10.69 V |
| ✅ | `775` | 237.0 | 244.1 | 1.031 | 1.061 | 3.0 % | 10.68 V |
| ✅ | `849` | 237.0 | 244.0 | 1.03 | 1.061 | 3.0 % | 10.6 V |
| ✅ | `894` | 237.0 | 244.0 | 1.03 | 1.061 | 3.0 % | 10.07 V |
| ✅ | `808` | 237.6 | 243.8 | 1.033 | 1.06 | 2.7 % | 10.6 V |
| ✅ | `693` | 237.1 | 243.8 | 1.031 | 1.06 | 2.9 % | 10.43 V |
| ✅ | `673` | 237.1 | 243.8 | 1.031 | 1.06 | 2.9 % | 10.42 V |
| ✅ | `627` | 236.5 | 243.7 | 1.028 | 1.06 | 3.1 % | 10.42 V |
| ✅ | `665` | 237.0 | 243.7 | 1.031 | 1.06 | 2.9 % | 10.39 V |
| ✅ | `617` | 236.5 | 243.7 | 1.028 | 1.06 | 3.1 % | 10.39 V |
| ✅ | `618` | 236.5 | 243.7 | 1.028 | 1.06 | 3.1 % | 10.39 V |
| ✅ | `608` | 236.5 | 243.7 | 1.028 | 1.06 | 3.1 % | 10.36 V |
| ✅ | `779` | 237.5 | 243.7 | 1.032 | 1.06 | 2.7 % | 10.55 V |
| ✅ | `659` | 237.0 | 243.7 | 1.031 | 1.059 | 2.9 % | 10.35 V |
| ✅ | `607` | 236.5 | 243.7 | 1.028 | 1.059 | 3.1 % | 10.33 V |
| ✅ | `600` | 236.5 | 243.6 | 1.028 | 1.059 | 3.1 % | 10.25 V |
| ✅ | `717` | 238.0 | 243.6 | 1.035 | 1.059 | 2.4 % | 10.68 V |
| ✅ | `655` | 237.7 | 243.6 | 1.033 | 1.059 | 2.6 % | 10.54 V |
| ✅ | `609` | 237.6 | 243.6 | 1.033 | 1.059 | 2.6 % | 10.5 V |
| ✅ | `773` | 237.5 | 243.6 | 1.032 | 1.059 | 2.7 % | 10.47 V |
| ✅ | `568` | 237.0 | 243.6 | 1.03 | 1.059 | 2.9 % | 10.23 V |
| ✅ | `545` | 236.5 | 243.2 | 1.028 | 1.058 | 2.9 % | 9.85 V |
| ✅ | `313` | 234.4 | 242.8 | 1.019 | 1.056 | 3.7 % | 9.25 V |
| ✅ | `303` | 234.4 | 242.8 | 1.019 | 1.056 | 3.6 % | 9.2 V |
| ✅ | `290` | 234.4 | 242.7 | 1.019 | 1.055 | 3.6 % | 9.14 V |
| ✅ | `282` | 234.4 | 242.7 | 1.019 | 1.055 | 3.6 % | 9.12 V |
| ✅ | `272` | 234.4 | 242.7 | 1.019 | 1.055 | 3.6 % | 9.05 V |
| ✅ | `321` | 234.4 | 242.5 | 1.019 | 1.054 | 3.5 % | 8.83 V |
| ✅ | `264` | 234.4 | 242.4 | 1.019 | 1.054 | 3.5 % | 8.76 V |
| ✅ | `263` | 234.4 | 242.3 | 1.019 | 1.053 | 3.4 % | 8.55 V |
| ✅ | `254` | 234.4 | 242.2 | 1.019 | 1.053 | 3.4 % | 8.49 V |
| ✅ | `498` | 234.7 | 242.2 | 1.021 | 1.053 | 3.2 % | 2.09 V |
| ✅ | `491` | 234.7 | 242.1 | 1.021 | 1.053 | 3.2 % | 2.1 V |
| ✅ | `473` | 234.7 | 242.1 | 1.021 | 1.053 | 3.2 % | 2.11 V |
| ✅ | `229` | 234.5 | 242.1 | 1.019 | 1.052 | 3.3 % | 8.23 V |
| ✅ | `472` | 234.7 | 242.0 | 1.021 | 1.052 | 3.2 % | 2.13 V |
| ✅ | `216` | 234.5 | 242.0 | 1.019 | 1.052 | 3.3 % | 8.16 V |
| ✅ | `439` | 234.7 | 242.0 | 1.021 | 1.052 | 3.1 % | 2.15 V |
| ✅ | `536` | 234.7 | 241.9 | 1.021 | 1.052 | 3.1 % | 2.17 V |
| ✅ | `427` | 234.7 | 241.8 | 1.021 | 1.051 | 3.1 % | 2.2 V |
| ✅ | `530` | 235.9 | 241.8 | 1.026 | 1.051 | 2.6 % | 8.0 V |
| ✅ | `192` | 234.5 | 241.8 | 1.02 | 1.051 | 3.2 % | 7.89 V |
| ✅ | `175` | 234.5 | 241.7 | 1.02 | 1.051 | 3.2 % | 7.83 V |
| ✅ | `479` | 234.7 | 241.7 | 1.021 | 1.051 | 3.0 % | 2.24 V |
| ✅ | `377` | 234.7 | 241.6 | 1.021 | 1.051 | 3.0 % | 2.28 V |
| ✅ | `376` | 234.7 | 241.6 | 1.021 | 1.05 | 3.0 % | 2.29 V |
| ✅ | `354` | 234.7 | 241.5 | 1.021 | 1.05 | 3.0 % | 2.33 V |
| ✅ | `166` | 234.6 | 241.4 | 1.02 | 1.05 | 3.0 % | 7.31 V |
| ✅ | `521` | 234.7 | 241.3 | 1.021 | 1.049 | 2.9 % | 2.46 V |
| ✅ | `307` | 234.7 | 241.2 | 1.021 | 1.049 | 2.8 % | 2.52 V |
| ✅ | `151` | 234.6 | 241.2 | 1.02 | 1.049 | 2.9 % | 7.07 V |
| ✅ | `145` | 234.6 | 241.1 | 1.02 | 1.048 | 2.8 % | 7.01 V |
| ✅ | `138` | 234.6 | 241.0 | 1.02 | 1.048 | 2.8 % | 6.92 V |
| ✅ | `428` | 236.3 | 241.0 | 1.027 | 1.048 | 2.1 % | 7.13 V |
| ✅ | `416` | 236.2 | 241.0 | 1.027 | 1.048 | 2.1 % | 7.1 V |
| ✅ | `391` | 236.1 | 241.0 | 1.027 | 1.048 | 2.1 % | 7.07 V |
| ✅ | `380` | 236.1 | 241.0 | 1.027 | 1.048 | 2.1 % | 7.06 V |
| ✅ | `392` | 236.1 | 241.0 | 1.027 | 1.048 | 2.1 % | 7.06 V |
| ✅ | `366` | 236.1 | 241.0 | 1.026 | 1.048 | 2.2 % | 7.03 V |
| ✅ | `355` | 236.0 | 241.0 | 1.026 | 1.048 | 2.2 % | 7.01 V |
| ✅ | `144` | 234.6 | 241.0 | 1.02 | 1.048 | 2.8 % | 6.87 V |
| ✅ | `441` | 235.9 | 241.0 | 1.026 | 1.048 | 2.2 % | 6.96 V |
| ✅ | `327` | 235.8 | 241.0 | 1.025 | 1.048 | 2.3 % | 6.91 V |
| ✅ | `348` | 236.0 | 241.0 | 1.026 | 1.048 | 2.2 % | 7.01 V |
| ✅ | `384` | 235.7 | 241.0 | 1.025 | 1.048 | 2.3 % | 6.89 V |
| ✅ | `318` | 235.7 | 241.0 | 1.025 | 1.048 | 2.3 % | 6.88 V |
| ✅ | `300` | 235.6 | 241.0 | 1.024 | 1.048 | 2.3 % | 6.84 V |
| ✅ | `131` | 234.6 | 241.0 | 1.02 | 1.048 | 2.8 % | 6.83 V |
| ✅ | `256` | 234.7 | 240.9 | 1.021 | 1.048 | 2.7 % | 2.72 V |
| ✅ | `247` | 234.7 | 240.9 | 1.021 | 1.047 | 2.7 % | 2.76 V |
| ✅ | `116` | 234.7 | 240.5 | 1.02 | 1.046 | 2.5 % | 6.15 V |
| ✅ | `226` | 234.7 | 240.5 | 1.021 | 1.045 | 2.5 % | 3.08 V |
| ✅ | `128` | 234.7 | 240.4 | 1.02 | 1.045 | 2.5 % | 6.02 V |
| ✅ | `220` | 234.7 | 240.4 | 1.021 | 1.045 | 2.5 % | 3.14 V |
| ✅ | `198` | 234.7 | 240.3 | 1.02 | 1.045 | 2.5 % | 5.93 V |
| ✅ | `104` | 234.7 | 240.3 | 1.02 | 1.045 | 2.4 % | 5.96 V |
| ✅ | `108` | 234.7 | 240.2 | 1.02 | 1.044 | 2.4 % | 5.81 V |
| ✅ | `99` | 234.7 | 240.1 | 1.02 | 1.044 | 2.4 % | 5.77 V |
| ✅ | `219` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 3.56 V |
| ✅ | `208` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 3.62 V |
| ✅ | `201` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 4.33 V |
| ✅ | `188` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 4.4 V |
| ✅ | `179` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 4.98 V |
| ✅ | `162` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 5.05 V |
| ✅ | `187` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 5.28 V |
| ✅ | `147` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 5.37 V |
| ✅ | `90` | 234.7 | 240.1 | 1.021 | 1.044 | 2.3 % | 5.67 V |
| ✅ | `82` | 234.7 | 240.1 | 1.02 | 1.044 | 2.3 % | 5.68 V |
| ✅ | `62` | 233.5 | 237.0 | 1.015 | 1.031 | 1.5 % | 3.95 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=3.021 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=3.438 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=3.451 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=3.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=3.031 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=3.405 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=3.371 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=3.274 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=3.006 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=3.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=3.05 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=3.368 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=3.392 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=3.042 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=2.912 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=2.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=3.514 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=2.93 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=3.309 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=3.011 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=2.951 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=2.911 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=3.178 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=3.313 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=2.91 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=2.954 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=3.398 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=2.966 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=3.111 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=2.928 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=3.315 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=3.226 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=3.254 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=3.45 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=2.939 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=3.251 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=2.984 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=3.44 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=3.385 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=3.153 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=3.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=3.082 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=3.118 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=3.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=3.421 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=3.351 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=2.942 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 82.3 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 11.64 V at bus '896' — reflects the neutral shift under unbalanced loading.

