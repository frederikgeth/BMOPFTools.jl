# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:19  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -188673.953  
**Solve time:** 0.083 s  
**Findings:** 0 errors · 42 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 41.15 kW |
| Total load | 19.861 kW |
| Total network losses (P) | 21.289 kW |
| Total network losses (Q) | 6.161 kW var |
| Loss fraction | 107.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 17.13 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.091 (`896`) | 4.8 % (`313`) | 17.13 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 240.6 | 250.9 | 1.046 | 1.091 | 4.5 % | 17.13 V |
| ✅ | `949` | 241.0 | 250.5 | 1.048 | 1.089 | 4.1 % | 16.38 V |
| ✅ | `660` | 240.6 | 250.3 | 1.046 | 1.088 | 4.2 % | 16.55 V |
| ✅ | `677` | 240.6 | 250.3 | 1.046 | 1.088 | 4.2 % | 16.61 V |
| ✅ | `661` | 240.6 | 250.3 | 1.046 | 1.088 | 4.2 % | 16.45 V |
| ✅ | `895` | 241.0 | 250.2 | 1.048 | 1.088 | 4.0 % | 16.1 V |
| ✅ | `654` | 240.6 | 250.2 | 1.046 | 1.088 | 4.2 % | 16.33 V |
| ✅ | `644` | 240.6 | 250.2 | 1.046 | 1.088 | 4.2 % | 16.3 V |
| ✅ | `635` | 240.6 | 250.1 | 1.046 | 1.087 | 4.1 % | 16.22 V |
| ✅ | `904` | 241.0 | 250.1 | 1.048 | 1.087 | 4.0 % | 15.98 V |
| ✅ | `775` | 240.8 | 250.0 | 1.047 | 1.087 | 4.0 % | 15.98 V |
| ✅ | `849` | 241.0 | 250.0 | 1.048 | 1.087 | 3.9 % | 15.86 V |
| ✅ | `894` | 241.8 | 250.0 | 1.051 | 1.087 | 3.5 % | 14.98 V |
| ✅ | `808` | 240.9 | 249.6 | 1.047 | 1.085 | 3.8 % | 15.99 V |
| ✅ | `693` | 240.8 | 249.6 | 1.047 | 1.085 | 3.8 % | 15.64 V |
| ✅ | `673` | 240.8 | 249.6 | 1.047 | 1.085 | 3.8 % | 15.62 V |
| ✅ | `627` | 240.6 | 249.6 | 1.046 | 1.085 | 3.9 % | 15.54 V |
| ✅ | `665` | 240.8 | 249.6 | 1.047 | 1.085 | 3.8 % | 15.57 V |
| ✅ | `617` | 240.6 | 249.5 | 1.046 | 1.085 | 3.9 % | 15.5 V |
| ✅ | `779` | 240.8 | 249.5 | 1.047 | 1.085 | 3.8 % | 15.82 V |
| ✅ | `618` | 240.6 | 249.5 | 1.046 | 1.085 | 3.9 % | 15.5 V |
| ✅ | `659` | 240.8 | 249.5 | 1.047 | 1.085 | 3.8 % | 15.51 V |
| ✅ | `608` | 240.6 | 249.5 | 1.046 | 1.085 | 3.9 % | 15.47 V |
| ✅ | `607` | 240.6 | 249.5 | 1.046 | 1.085 | 3.8 % | 15.42 V |
| ✅ | `600` | 240.6 | 249.4 | 1.046 | 1.084 | 3.8 % | 15.32 V |
| ✅ | `717` | 240.8 | 249.4 | 1.047 | 1.084 | 3.7 % | 16.04 V |
| ✅ | `655` | 240.8 | 249.4 | 1.047 | 1.084 | 3.7 % | 15.81 V |
| ✅ | `609` | 240.8 | 249.4 | 1.047 | 1.084 | 3.7 % | 15.76 V |
| ✅ | `773` | 240.8 | 249.4 | 1.047 | 1.084 | 3.7 % | 15.69 V |
| ✅ | `568` | 240.8 | 249.3 | 1.047 | 1.084 | 3.7 % | 15.33 V |
| ✅ | `545` | 240.6 | 248.9 | 1.046 | 1.082 | 3.6 % | 14.76 V |
| ✅ | `313` | 237.7 | 248.6 | 1.033 | 1.081 | 4.8 % | 14.24 V |
| ✅ | `303` | 237.7 | 248.6 | 1.033 | 1.081 | 4.7 % | 14.17 V |
| ✅ | `290` | 237.7 | 248.5 | 1.033 | 1.08 | 4.7 % | 14.09 V |
| ✅ | `282` | 237.7 | 248.5 | 1.033 | 1.08 | 4.7 % | 14.04 V |
| ✅ | `272` | 237.7 | 248.4 | 1.033 | 1.08 | 4.7 % | 13.95 V |
| ✅ | `321` | 237.7 | 248.1 | 1.034 | 1.079 | 4.5 % | 13.64 V |
| ✅ | `264` | 237.7 | 248.1 | 1.034 | 1.079 | 4.5 % | 13.54 V |
| ✅ | `263` | 237.7 | 247.8 | 1.034 | 1.077 | 4.4 % | 13.24 V |
| ✅ | `254` | 237.8 | 247.8 | 1.034 | 1.077 | 4.3 % | 13.17 V |
| ✅ | `229` | 237.8 | 247.5 | 1.034 | 1.076 | 4.2 % | 12.82 V |
| ✅ | `216` | 237.8 | 247.4 | 1.034 | 1.076 | 4.2 % | 12.73 V |
| ✅ | `192` | 237.8 | 247.1 | 1.034 | 1.074 | 4.0 % | 12.36 V |
| ✅ | `175` | 237.8 | 247.0 | 1.034 | 1.074 | 4.0 % | 12.28 V |
| ✅ | `530` | 240.2 | 246.9 | 1.044 | 1.074 | 2.9 % | 12.15 V |
| ✅ | `166` | 237.9 | 246.5 | 1.034 | 1.072 | 3.7 % | 11.59 V |
| ✅ | `498` | 238.1 | 246.4 | 1.035 | 1.071 | 3.6 % | 6.99 V |
| ✅ | `491` | 238.1 | 246.3 | 1.035 | 1.071 | 3.6 % | 6.97 V |
| ✅ | `473` | 238.1 | 246.2 | 1.035 | 1.071 | 3.5 % | 6.95 V |
| ✅ | `472` | 238.1 | 246.2 | 1.035 | 1.07 | 3.5 % | 6.94 V |
| ✅ | `151` | 237.9 | 246.2 | 1.034 | 1.07 | 3.6 % | 11.23 V |
| ✅ | `145` | 237.9 | 246.1 | 1.034 | 1.07 | 3.5 % | 11.14 V |
| ✅ | `439` | 238.1 | 246.1 | 1.035 | 1.07 | 3.4 % | 6.92 V |
| ✅ | `536` | 238.1 | 246.0 | 1.035 | 1.07 | 3.4 % | 6.91 V |
| ✅ | `138` | 237.9 | 246.0 | 1.035 | 1.069 | 3.5 % | 11.01 V |
| ✅ | `144` | 237.9 | 245.9 | 1.035 | 1.069 | 3.5 % | 10.96 V |
| ✅ | `427` | 238.1 | 245.9 | 1.035 | 1.069 | 3.4 % | 6.9 V |
| ✅ | `428` | 240.5 | 245.9 | 1.046 | 1.069 | 2.3 % | 10.87 V |
| ✅ | `416` | 240.5 | 245.9 | 1.046 | 1.069 | 2.3 % | 10.84 V |
| ✅ | `391` | 240.5 | 245.9 | 1.046 | 1.069 | 2.3 % | 10.81 V |
| ✅ | `380` | 240.5 | 245.9 | 1.046 | 1.069 | 2.3 % | 10.81 V |
| ✅ | `392` | 240.5 | 245.9 | 1.046 | 1.069 | 2.3 % | 10.81 V |
| ✅ | `366` | 240.4 | 245.9 | 1.045 | 1.069 | 2.4 % | 10.78 V |
| ✅ | `131` | 237.9 | 245.9 | 1.035 | 1.069 | 3.4 % | 10.88 V |
| ✅ | `355` | 240.3 | 245.9 | 1.045 | 1.069 | 2.4 % | 10.76 V |
| ✅ | `441` | 240.1 | 245.9 | 1.044 | 1.069 | 2.5 % | 10.7 V |
| ✅ | `348` | 240.3 | 245.8 | 1.045 | 1.069 | 2.4 % | 10.81 V |
| ✅ | `327` | 240.0 | 245.8 | 1.043 | 1.069 | 2.6 % | 10.66 V |
| ✅ | `384` | 239.9 | 245.8 | 1.043 | 1.069 | 2.6 % | 10.64 V |
| ✅ | `318` | 239.8 | 245.8 | 1.043 | 1.069 | 2.6 % | 10.63 V |
| ✅ | `300` | 239.7 | 245.8 | 1.042 | 1.069 | 2.7 % | 10.6 V |
| ✅ | `479` | 238.1 | 245.7 | 1.035 | 1.068 | 3.3 % | 6.88 V |
| ✅ | `377` | 238.1 | 245.6 | 1.035 | 1.068 | 3.3 % | 6.87 V |
| ✅ | `376` | 238.1 | 245.6 | 1.035 | 1.068 | 3.2 % | 6.87 V |
| ✅ | `354` | 238.1 | 245.5 | 1.035 | 1.067 | 3.2 % | 6.86 V |
| ✅ | `116` | 238.0 | 245.2 | 1.035 | 1.066 | 3.1 % | 10.01 V |
| ✅ | `521` | 238.1 | 245.2 | 1.035 | 1.066 | 3.1 % | 6.86 V |
| ✅ | `128` | 238.1 | 245.1 | 1.035 | 1.065 | 3.0 % | 9.8 V |
| ✅ | `307` | 238.1 | 245.1 | 1.035 | 1.065 | 3.0 % | 6.87 V |
| ✅ | `198` | 238.1 | 244.9 | 1.035 | 1.065 | 3.0 % | 9.64 V |
| ✅ | `104` | 238.1 | 244.9 | 1.035 | 1.065 | 3.0 % | 9.66 V |
| ✅ | `108` | 238.1 | 244.7 | 1.035 | 1.064 | 2.9 % | 9.45 V |
| ✅ | `256` | 238.1 | 244.7 | 1.035 | 1.064 | 2.8 % | 6.91 V |
| ✅ | `99` | 238.1 | 244.6 | 1.035 | 1.064 | 2.9 % | 9.4 V |
| ✅ | `247` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 6.93 V |
| ✅ | `226` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 7.05 V |
| ✅ | `220` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 7.08 V |
| ✅ | `219` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 7.33 V |
| ✅ | `208` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 7.38 V |
| ✅ | `201` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 7.95 V |
| ✅ | `188` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.02 V |
| ✅ | `179` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.57 V |
| ✅ | `162` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.65 V |
| ✅ | `187` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.9 V |
| ✅ | `147` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.98 V |
| ✅ | `90` | 238.1 | 244.6 | 1.035 | 1.063 | 2.8 % | 9.25 V |
| ✅ | `82` | 238.1 | 244.5 | 1.035 | 1.063 | 2.8 % | 9.26 V |
| ✅ | `62` | 236.0 | 240.0 | 1.026 | 1.044 | 1.8 % | 6.33 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.415 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.677 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.227 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.969 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.731 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.374 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.68 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.498 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.502 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.03 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.785 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.461 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.447 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.59 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.828 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=5.009 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.938 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.585 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.528 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=5.138 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.562 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=5.191 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.617 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.862 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.111 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=5.249 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.42 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.629 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 107.2 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 17.13 V at bus '896' — reflects the neutral shift under unbalanced loading.

