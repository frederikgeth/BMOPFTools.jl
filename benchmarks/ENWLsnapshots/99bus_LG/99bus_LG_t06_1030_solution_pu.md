# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:16  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -130908.3981  
**Solve time:** 0.04 s  
**Findings:** 0 errors · 48 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 22.208 kW |
| Total load | 12.685 kW |
| Total network losses (P) | 9.523 kW |
| Total network losses (Q) | 2.818 kW var |
| Loss fraction | 75.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 11.178 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.069 (`896`) | 3.9 % (`313`) | 11.18 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 237.3 | 246.0 | 1.032 | 1.069 | 3.7 % | 11.18 V |
| ✅ | `949` | 237.6 | 245.7 | 1.033 | 1.068 | 3.5 % | 10.66 V |
| ✅ | `660` | 237.4 | 245.5 | 1.032 | 1.067 | 3.5 % | 10.72 V |
| ✅ | `677` | 237.4 | 245.5 | 1.032 | 1.067 | 3.5 % | 10.76 V |
| ✅ | `661` | 237.4 | 245.5 | 1.032 | 1.067 | 3.5 % | 10.66 V |
| ✅ | `654` | 237.4 | 245.4 | 1.032 | 1.067 | 3.5 % | 10.57 V |
| ✅ | `895` | 237.7 | 245.4 | 1.033 | 1.067 | 3.4 % | 10.42 V |
| ✅ | `644` | 237.4 | 245.4 | 1.032 | 1.067 | 3.5 % | 10.55 V |
| ✅ | `635` | 237.4 | 245.3 | 1.032 | 1.067 | 3.5 % | 10.5 V |
| ✅ | `904` | 237.7 | 245.3 | 1.033 | 1.067 | 3.3 % | 10.35 V |
| ✅ | `775` | 237.6 | 245.3 | 1.033 | 1.066 | 3.3 % | 10.34 V |
| ✅ | `849` | 237.7 | 245.2 | 1.033 | 1.066 | 3.3 % | 10.26 V |
| ✅ | `894` | 238.0 | 245.2 | 1.035 | 1.066 | 3.2 % | 9.78 V |
| ✅ | `808` | 237.6 | 245.0 | 1.033 | 1.065 | 3.2 % | 10.23 V |
| ✅ | `693` | 237.6 | 245.0 | 1.033 | 1.065 | 3.2 % | 10.06 V |
| ✅ | `673` | 237.6 | 245.0 | 1.033 | 1.065 | 3.2 % | 10.06 V |
| ✅ | `665` | 237.6 | 244.9 | 1.033 | 1.065 | 3.2 % | 10.02 V |
| ✅ | `627` | 237.4 | 244.9 | 1.032 | 1.065 | 3.3 % | 10.03 V |
| ✅ | `617` | 237.4 | 244.9 | 1.032 | 1.065 | 3.3 % | 10.0 V |
| ✅ | `618` | 237.4 | 244.9 | 1.032 | 1.065 | 3.3 % | 10.0 V |
| ✅ | `779` | 237.6 | 244.9 | 1.033 | 1.065 | 3.2 % | 10.15 V |
| ✅ | `659` | 237.6 | 244.9 | 1.033 | 1.065 | 3.2 % | 9.98 V |
| ✅ | `608` | 237.4 | 244.9 | 1.032 | 1.065 | 3.3 % | 9.98 V |
| ✅ | `607` | 237.4 | 244.9 | 1.032 | 1.065 | 3.2 % | 9.94 V |
| ✅ | `600` | 237.4 | 244.8 | 1.032 | 1.064 | 3.2 % | 9.87 V |
| ✅ | `717` | 237.6 | 244.8 | 1.033 | 1.064 | 3.1 % | 10.27 V |
| ✅ | `655` | 237.6 | 244.8 | 1.033 | 1.064 | 3.1 % | 10.13 V |
| ✅ | `609` | 237.6 | 244.8 | 1.033 | 1.064 | 3.1 % | 10.1 V |
| ✅ | `773` | 237.6 | 244.8 | 1.033 | 1.064 | 3.1 % | 10.04 V |
| ✅ | `568` | 237.5 | 244.8 | 1.033 | 1.064 | 3.1 % | 9.85 V |
| ✅ | `545` | 237.4 | 244.4 | 1.032 | 1.063 | 3.1 % | 9.47 V |
| ✅ | `313` | 235.0 | 243.9 | 1.022 | 1.061 | 3.9 % | 9.2 V |
| ✅ | `303` | 235.0 | 243.9 | 1.022 | 1.06 | 3.9 % | 9.15 V |
| ✅ | `290` | 235.0 | 243.8 | 1.022 | 1.06 | 3.8 % | 9.1 V |
| ✅ | `282` | 235.0 | 243.8 | 1.022 | 1.06 | 3.8 % | 9.08 V |
| ✅ | `272` | 235.0 | 243.8 | 1.022 | 1.06 | 3.8 % | 9.01 V |
| ✅ | `321` | 235.0 | 243.6 | 1.022 | 1.059 | 3.7 % | 8.82 V |
| ✅ | `264` | 235.0 | 243.5 | 1.022 | 1.059 | 3.7 % | 8.75 V |
| ✅ | `263` | 235.0 | 243.4 | 1.022 | 1.058 | 3.6 % | 8.56 V |
| ✅ | `254` | 235.0 | 243.3 | 1.022 | 1.058 | 3.6 % | 8.5 V |
| ✅ | `229` | 235.1 | 243.1 | 1.022 | 1.057 | 3.5 % | 8.27 V |
| ✅ | `216` | 235.1 | 243.1 | 1.022 | 1.057 | 3.5 % | 8.2 V |
| ✅ | `530` | 236.7 | 242.9 | 1.029 | 1.056 | 2.7 % | 7.68 V |
| ✅ | `192` | 235.1 | 242.8 | 1.022 | 1.056 | 3.4 % | 7.94 V |
| ✅ | `175` | 235.1 | 242.8 | 1.022 | 1.056 | 3.3 % | 7.89 V |
| ✅ | `166` | 235.2 | 242.4 | 1.022 | 1.054 | 3.2 % | 7.44 V |
| ✅ | `151` | 235.2 | 242.2 | 1.022 | 1.053 | 3.0 % | 7.19 V |
| ✅ | `145` | 235.2 | 242.1 | 1.022 | 1.053 | 3.0 % | 7.13 V |
| ✅ | `428` | 237.0 | 242.0 | 1.03 | 1.052 | 2.2 % | 6.67 V |
| ✅ | `416` | 236.9 | 242.0 | 1.03 | 1.052 | 2.2 % | 6.65 V |
| ✅ | `391` | 236.9 | 242.0 | 1.03 | 1.052 | 2.3 % | 6.65 V |
| ✅ | `380` | 236.8 | 242.0 | 1.03 | 1.052 | 2.3 % | 6.65 V |
| ✅ | `392` | 236.8 | 242.0 | 1.03 | 1.052 | 2.3 % | 6.65 V |
| ✅ | `138` | 235.2 | 242.0 | 1.022 | 1.052 | 3.0 % | 7.04 V |
| ✅ | `366` | 236.8 | 242.0 | 1.029 | 1.052 | 2.3 % | 6.64 V |
| ✅ | `355` | 236.7 | 242.0 | 1.029 | 1.052 | 2.3 % | 6.64 V |
| ✅ | `441` | 236.6 | 242.0 | 1.029 | 1.052 | 2.4 % | 6.63 V |
| ✅ | `327` | 236.5 | 242.0 | 1.028 | 1.052 | 2.4 % | 6.62 V |
| ✅ | `348` | 236.7 | 242.0 | 1.029 | 1.052 | 2.3 % | 6.66 V |
| ✅ | `384` | 236.4 | 242.0 | 1.028 | 1.052 | 2.4 % | 6.61 V |
| ✅ | `318` | 236.4 | 242.0 | 1.028 | 1.052 | 2.4 % | 6.61 V |
| ✅ | `144` | 235.2 | 242.0 | 1.022 | 1.052 | 3.0 % | 7.0 V |
| ✅ | `300` | 236.3 | 242.0 | 1.027 | 1.052 | 2.5 % | 6.61 V |
| ✅ | `131` | 235.2 | 241.9 | 1.022 | 1.052 | 2.9 % | 6.95 V |
| ✅ | `498` | 235.3 | 241.7 | 1.023 | 1.051 | 2.8 % | 4.78 V |
| ✅ | `491` | 235.3 | 241.7 | 1.023 | 1.051 | 2.8 % | 4.77 V |
| ✅ | `473` | 235.3 | 241.6 | 1.023 | 1.05 | 2.7 % | 4.75 V |
| ✅ | `472` | 235.3 | 241.5 | 1.023 | 1.05 | 2.7 % | 4.73 V |
| ✅ | `439` | 235.3 | 241.5 | 1.023 | 1.05 | 2.7 % | 4.72 V |
| ✅ | `536` | 235.3 | 241.4 | 1.023 | 1.05 | 2.7 % | 4.7 V |
| ✅ | `116` | 235.2 | 241.4 | 1.023 | 1.05 | 2.7 % | 6.34 V |
| ✅ | `427` | 235.3 | 241.4 | 1.023 | 1.049 | 2.6 % | 4.69 V |
| ✅ | `128` | 235.2 | 241.4 | 1.023 | 1.049 | 2.7 % | 6.23 V |
| ✅ | `479` | 235.3 | 241.3 | 1.023 | 1.049 | 2.6 % | 4.66 V |
| ✅ | `198` | 235.2 | 241.2 | 1.023 | 1.049 | 2.6 % | 6.12 V |
| ✅ | `104` | 235.2 | 241.2 | 1.023 | 1.049 | 2.6 % | 6.13 V |
| ✅ | `377` | 235.3 | 241.2 | 1.023 | 1.049 | 2.6 % | 4.65 V |
| ✅ | `376` | 235.3 | 241.2 | 1.023 | 1.048 | 2.5 % | 4.65 V |
| ✅ | `108` | 235.3 | 241.1 | 1.023 | 1.048 | 2.5 % | 5.99 V |
| ✅ | `354` | 235.3 | 241.1 | 1.023 | 1.048 | 2.5 % | 4.64 V |
| ✅ | `99` | 235.3 | 241.1 | 1.023 | 1.048 | 2.5 % | 5.95 V |
| ✅ | `521` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.61 V |
| ✅ | `307` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.61 V |
| ✅ | `256` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.6 V |
| ✅ | `247` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.61 V |
| ✅ | `226` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.64 V |
| ✅ | `220` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.66 V |
| ✅ | `219` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.77 V |
| ✅ | `208` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 4.79 V |
| ✅ | `201` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.09 V |
| ✅ | `188` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.13 V |
| ✅ | `179` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.45 V |
| ✅ | `162` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.5 V |
| ✅ | `187` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.64 V |
| ✅ | `147` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.69 V |
| ✅ | `90` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.85 V |
| ✅ | `82` | 235.3 | 241.0 | 1.023 | 1.048 | 2.5 % | 5.86 V |
| ✅ | `62` | 233.9 | 237.6 | 1.017 | 1.033 | 1.6 % | 3.99 V |
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
  Line losses are 75.1 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 11.18 V at bus '896' — reflects the neutral shift under unbalanced loading.

