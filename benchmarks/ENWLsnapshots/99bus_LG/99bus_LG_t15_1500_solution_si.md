# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:18  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -196048.324  
**Solve time:** 0.077 s  
**Findings:** 0 errors · 35 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 39.991 kW |
| Total load | 16.896 kW |
| Total network losses (P) | 23.095 kW |
| Total network losses (Q) | 6.689 kW var |
| Loss fraction | 136.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 17.843 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.095 (`896`) | 5.1 % (`313`) | 17.84 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 241.2 | 251.8 | 1.049 | 1.095 | 4.6 % | 17.84 V |
| ✅ | `949` | 241.6 | 251.3 | 1.05 | 1.093 | 4.2 % | 16.99 V |
| ✅ | `677` | 241.2 | 251.2 | 1.049 | 1.092 | 4.3 % | 17.26 V |
| ✅ | `660` | 241.2 | 251.2 | 1.049 | 1.092 | 4.3 % | 17.19 V |
| ✅ | `661` | 241.2 | 251.1 | 1.049 | 1.092 | 4.3 % | 17.08 V |
| ✅ | `895` | 241.6 | 251.1 | 1.05 | 1.092 | 4.1 % | 16.68 V |
| ✅ | `654` | 241.2 | 251.0 | 1.049 | 1.091 | 4.3 % | 16.94 V |
| ✅ | `644` | 241.2 | 251.0 | 1.049 | 1.091 | 4.3 % | 16.92 V |
| ✅ | `635` | 241.2 | 250.9 | 1.049 | 1.091 | 4.2 % | 16.83 V |
| ✅ | `904` | 241.6 | 250.9 | 1.05 | 1.091 | 4.1 % | 16.55 V |
| ✅ | `775` | 241.4 | 250.8 | 1.05 | 1.09 | 4.1 % | 16.54 V |
| ✅ | `849` | 241.6 | 250.8 | 1.05 | 1.09 | 4.0 % | 16.41 V |
| ✅ | `894` | 242.1 | 250.8 | 1.052 | 1.09 | 3.8 % | 15.46 V |
| ✅ | `808` | 241.5 | 250.4 | 1.05 | 1.089 | 3.9 % | 16.41 V |
| ✅ | `693` | 241.4 | 250.4 | 1.05 | 1.089 | 3.9 % | 16.15 V |
| ✅ | `673` | 241.4 | 250.4 | 1.05 | 1.089 | 3.9 % | 16.14 V |
| ✅ | `665` | 241.4 | 250.4 | 1.05 | 1.088 | 3.9 % | 16.08 V |
| ✅ | `627` | 241.2 | 250.3 | 1.049 | 1.088 | 4.0 % | 16.11 V |
| ✅ | `779` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.29 V |
| ✅ | `617` | 241.2 | 250.3 | 1.049 | 1.088 | 4.0 % | 16.06 V |
| ✅ | `659` | 241.4 | 250.3 | 1.05 | 1.088 | 3.9 % | 16.02 V |
| ✅ | `618` | 241.2 | 250.3 | 1.049 | 1.088 | 3.9 % | 16.06 V |
| ✅ | `608` | 241.2 | 250.3 | 1.049 | 1.088 | 3.9 % | 16.03 V |
| ✅ | `607` | 241.2 | 250.2 | 1.049 | 1.088 | 3.9 % | 15.98 V |
| ✅ | `600` | 241.2 | 250.1 | 1.049 | 1.088 | 3.9 % | 15.87 V |
| ✅ | `717` | 241.4 | 250.1 | 1.05 | 1.088 | 3.8 % | 16.48 V |
| ✅ | `655` | 241.4 | 250.1 | 1.05 | 1.088 | 3.8 % | 16.27 V |
| ✅ | `609` | 241.4 | 250.1 | 1.05 | 1.088 | 3.8 % | 16.22 V |
| ✅ | `773` | 241.4 | 250.1 | 1.05 | 1.088 | 3.8 % | 16.16 V |
| ✅ | `568` | 241.4 | 250.1 | 1.049 | 1.087 | 3.8 % | 15.83 V |
| ✅ | `545` | 241.2 | 249.6 | 1.049 | 1.085 | 3.7 % | 15.28 V |
| ✅ | `313` | 237.6 | 249.3 | 1.033 | 1.084 | 5.1 % | 14.94 V |
| ✅ | `303` | 237.7 | 249.2 | 1.033 | 1.084 | 5.0 % | 14.87 V |
| ✅ | `290` | 237.7 | 249.2 | 1.033 | 1.083 | 5.0 % | 14.79 V |
| ✅ | `282` | 237.7 | 249.1 | 1.033 | 1.083 | 5.0 % | 14.75 V |
| ✅ | `272` | 237.7 | 249.1 | 1.033 | 1.083 | 5.0 % | 14.65 V |
| ✅ | `321` | 237.7 | 248.8 | 1.033 | 1.082 | 4.8 % | 14.34 V |
| ✅ | `264` | 237.7 | 248.7 | 1.034 | 1.081 | 4.8 % | 14.24 V |
| ✅ | `263` | 237.7 | 248.5 | 1.034 | 1.08 | 4.7 % | 13.94 V |
| ✅ | `254` | 237.7 | 248.4 | 1.034 | 1.08 | 4.6 % | 13.86 V |
| ✅ | `229` | 237.8 | 248.1 | 1.034 | 1.079 | 4.5 % | 13.49 V |
| ✅ | `216` | 237.8 | 248.0 | 1.034 | 1.078 | 4.5 % | 13.39 V |
| ✅ | `192` | 237.8 | 247.7 | 1.034 | 1.077 | 4.3 % | 13.0 V |
| ✅ | `175` | 237.8 | 247.6 | 1.034 | 1.077 | 4.3 % | 12.92 V |
| ✅ | `530` | 240.2 | 247.6 | 1.044 | 1.076 | 3.2 % | 12.6 V |
| ✅ | `498` | 238.1 | 247.2 | 1.035 | 1.075 | 3.9 % | 8.15 V |
| ✅ | `166` | 237.9 | 247.2 | 1.034 | 1.075 | 4.0 % | 12.25 V |
| ✅ | `491` | 238.1 | 247.1 | 1.035 | 1.074 | 3.9 % | 8.13 V |
| ✅ | `473` | 238.1 | 247.0 | 1.035 | 1.074 | 3.9 % | 8.1 V |
| ✅ | `472` | 238.1 | 247.0 | 1.035 | 1.074 | 3.8 % | 8.07 V |
| ✅ | `439` | 238.1 | 246.9 | 1.035 | 1.073 | 3.8 % | 8.05 V |
| ✅ | `536` | 238.1 | 246.8 | 1.035 | 1.073 | 3.8 % | 8.03 V |
| ✅ | `151` | 237.9 | 246.8 | 1.034 | 1.073 | 3.8 % | 11.83 V |
| ✅ | `427` | 238.1 | 246.7 | 1.035 | 1.073 | 3.7 % | 8.0 V |
| ✅ | `145` | 237.9 | 246.7 | 1.034 | 1.073 | 3.8 % | 11.74 V |
| ✅ | `138` | 237.9 | 246.6 | 1.034 | 1.072 | 3.8 % | 11.6 V |
| ✅ | `479` | 238.1 | 246.5 | 1.035 | 1.072 | 3.6 % | 7.96 V |
| ✅ | `144` | 237.9 | 246.5 | 1.034 | 1.072 | 3.7 % | 11.54 V |
| ✅ | `428` | 240.7 | 246.5 | 1.047 | 1.072 | 2.5 % | 11.23 V |
| ✅ | `416` | 240.6 | 246.5 | 1.046 | 1.072 | 2.5 % | 11.2 V |
| ✅ | `391` | 240.5 | 246.5 | 1.046 | 1.072 | 2.6 % | 11.18 V |
| ✅ | `392` | 240.5 | 246.5 | 1.046 | 1.072 | 2.6 % | 11.18 V |
| ✅ | `380` | 240.5 | 246.5 | 1.046 | 1.072 | 2.6 % | 11.17 V |
| ✅ | `131` | 237.9 | 246.5 | 1.035 | 1.072 | 3.7 % | 11.47 V |
| ✅ | `366` | 240.4 | 246.5 | 1.045 | 1.072 | 2.6 % | 11.15 V |
| ✅ | `355` | 240.3 | 246.5 | 1.045 | 1.072 | 2.7 % | 11.14 V |
| ✅ | `377` | 238.1 | 246.4 | 1.035 | 1.071 | 3.6 % | 7.95 V |
| ✅ | `441` | 240.1 | 246.4 | 1.044 | 1.071 | 2.7 % | 11.1 V |
| ✅ | `348` | 240.3 | 246.4 | 1.045 | 1.071 | 2.6 % | 11.2 V |
| ✅ | `327` | 240.0 | 246.4 | 1.043 | 1.071 | 2.8 % | 11.06 V |
| ✅ | `384` | 239.9 | 246.4 | 1.043 | 1.071 | 2.8 % | 11.05 V |
| ✅ | `318` | 239.8 | 246.4 | 1.043 | 1.071 | 2.9 % | 11.04 V |
| ✅ | `300` | 239.7 | 246.4 | 1.042 | 1.071 | 2.9 % | 11.02 V |
| ✅ | `376` | 238.1 | 246.4 | 1.035 | 1.071 | 3.6 % | 7.94 V |
| ✅ | `354` | 238.1 | 246.3 | 1.035 | 1.071 | 3.5 % | 7.92 V |
| ✅ | `521` | 238.1 | 245.9 | 1.035 | 1.069 | 3.4 % | 7.87 V |
| ✅ | `307` | 238.1 | 245.8 | 1.035 | 1.069 | 3.3 % | 7.87 V |
| ✅ | `116` | 238.0 | 245.7 | 1.035 | 1.068 | 3.3 % | 10.49 V |
| ✅ | `128` | 238.1 | 245.6 | 1.035 | 1.068 | 3.3 % | 10.34 V |
| ✅ | `256` | 238.1 | 245.4 | 1.035 | 1.067 | 3.2 % | 7.85 V |
| ✅ | `104` | 238.1 | 245.4 | 1.035 | 1.067 | 3.2 % | 10.17 V |
| ✅ | `198` | 238.1 | 245.4 | 1.035 | 1.067 | 3.2 % | 10.14 V |
| ✅ | `247` | 238.1 | 245.3 | 1.035 | 1.067 | 3.1 % | 7.86 V |
| ✅ | `108` | 238.1 | 245.2 | 1.035 | 1.066 | 3.1 % | 9.96 V |
| ✅ | `99` | 238.1 | 245.2 | 1.035 | 1.066 | 3.1 % | 9.89 V |
| ✅ | `226` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 7.91 V |
| ✅ | `220` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 7.93 V |
| ✅ | `219` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 8.09 V |
| ✅ | `208` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 8.12 V |
| ✅ | `201` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 8.57 V |
| ✅ | `188` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 8.64 V |
| ✅ | `179` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 9.11 V |
| ✅ | `162` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 9.2 V |
| ✅ | `187` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 9.42 V |
| ✅ | `147` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 9.5 V |
| ✅ | `90` | 238.1 | 245.1 | 1.035 | 1.066 | 3.0 % | 9.74 V |
| ✅ | `82` | 238.1 | 245.1 | 1.035 | 1.065 | 3.0 % | 9.75 V |
| ✅ | `62` | 236.0 | 240.4 | 1.026 | 1.045 | 1.9 % | 6.64 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=5.003 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.228 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=5.048 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.231 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.839 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.616 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.89 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=5.195 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.249 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=5.243 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.687 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=5.124 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.619 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.734 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.228 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.204 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.799 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=5.248 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.241 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.703 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.573 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 136.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 17.84 V at bus '896' — reflects the neutral shift under unbalanced loading.

