# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:17  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -199571.8925  
**Solve time:** 0.075 s  
**Findings:** 0 errors · 33 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 36.45 kW |
| Total load | 12.38 kW |
| Total network losses (P) | 24.07 kW |
| Total network losses (Q) | 6.943 kW var |
| Loss fraction | 194.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 18.388 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.097 (`896`) | 5.2 % (`313`) | 18.39 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 241.3 | 252.3 | 1.049 | 1.097 | 4.8 % | 18.39 V |
| ✅ | `949` | 241.8 | 251.8 | 1.051 | 1.095 | 4.3 % | 17.45 V |
| ✅ | `677` | 241.4 | 251.7 | 1.049 | 1.095 | 4.5 % | 17.81 V |
| ✅ | `660` | 241.4 | 251.7 | 1.049 | 1.094 | 4.5 % | 17.74 V |
| ✅ | `661` | 241.3 | 251.6 | 1.049 | 1.094 | 4.5 % | 17.6 V |
| ✅ | `654` | 241.4 | 251.5 | 1.049 | 1.094 | 4.4 % | 17.47 V |
| ✅ | `644` | 241.4 | 251.5 | 1.049 | 1.094 | 4.4 % | 17.45 V |
| ✅ | `895` | 241.8 | 251.5 | 1.051 | 1.093 | 4.2 % | 17.13 V |
| ✅ | `635` | 241.4 | 251.4 | 1.049 | 1.093 | 4.4 % | 17.36 V |
| ✅ | `904` | 241.8 | 251.4 | 1.051 | 1.093 | 4.2 % | 17.0 V |
| ✅ | `849` | 241.8 | 251.2 | 1.051 | 1.092 | 4.1 % | 16.86 V |
| ✅ | `894` | 242.4 | 251.2 | 1.054 | 1.092 | 3.8 % | 15.77 V |
| ✅ | `775` | 241.6 | 251.2 | 1.051 | 1.092 | 4.2 % | 17.02 V |
| ✅ | `808` | 241.7 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.98 V |
| ✅ | `693` | 241.6 | 250.9 | 1.051 | 1.091 | 4.0 % | 16.64 V |
| ✅ | `673` | 241.6 | 250.8 | 1.051 | 1.091 | 4.0 % | 16.63 V |
| ✅ | `627` | 241.4 | 250.8 | 1.049 | 1.091 | 4.1 % | 16.64 V |
| ✅ | `665` | 241.6 | 250.8 | 1.051 | 1.09 | 4.0 % | 16.57 V |
| ✅ | `617` | 241.4 | 250.8 | 1.049 | 1.09 | 4.1 % | 16.59 V |
| ✅ | `618` | 241.4 | 250.8 | 1.049 | 1.09 | 4.1 % | 16.59 V |
| ✅ | `608` | 241.4 | 250.8 | 1.049 | 1.09 | 4.1 % | 16.55 V |
| ✅ | `779` | 241.6 | 250.8 | 1.051 | 1.09 | 4.0 % | 16.79 V |
| ✅ | `659` | 241.6 | 250.7 | 1.05 | 1.09 | 4.0 % | 16.51 V |
| ✅ | `607` | 241.4 | 250.7 | 1.049 | 1.09 | 4.1 % | 16.49 V |
| ✅ | `600` | 241.4 | 250.6 | 1.049 | 1.09 | 4.0 % | 16.39 V |
| ✅ | `717` | 241.6 | 250.6 | 1.05 | 1.09 | 3.9 % | 17.05 V |
| ✅ | `655` | 241.6 | 250.6 | 1.05 | 1.09 | 3.9 % | 16.81 V |
| ✅ | `609` | 241.6 | 250.6 | 1.05 | 1.09 | 3.9 % | 16.76 V |
| ✅ | `773` | 241.6 | 250.6 | 1.05 | 1.09 | 3.9 % | 16.66 V |
| ✅ | `568` | 241.6 | 250.6 | 1.05 | 1.089 | 3.9 % | 16.33 V |
| ✅ | `545` | 241.4 | 250.1 | 1.049 | 1.087 | 3.8 % | 15.78 V |
| ✅ | `313` | 237.8 | 249.8 | 1.034 | 1.086 | 5.2 % | 15.43 V |
| ✅ | `303` | 237.8 | 249.7 | 1.034 | 1.086 | 5.2 % | 15.36 V |
| ✅ | `290` | 237.8 | 249.6 | 1.034 | 1.085 | 5.1 % | 15.28 V |
| ✅ | `282` | 237.8 | 249.6 | 1.034 | 1.085 | 5.1 % | 15.24 V |
| ✅ | `272` | 237.9 | 249.5 | 1.034 | 1.085 | 5.1 % | 15.14 V |
| ✅ | `321` | 237.9 | 249.3 | 1.034 | 1.084 | 5.0 % | 14.82 V |
| ✅ | `264` | 237.9 | 249.2 | 1.034 | 1.083 | 4.9 % | 14.72 V |
| ✅ | `263` | 237.9 | 248.9 | 1.034 | 1.082 | 4.8 % | 14.4 V |
| ✅ | `254` | 237.9 | 248.9 | 1.034 | 1.082 | 4.8 % | 14.32 V |
| ✅ | `229` | 238.0 | 248.6 | 1.035 | 1.081 | 4.6 % | 13.94 V |
| ✅ | `216` | 238.0 | 248.5 | 1.035 | 1.08 | 4.6 % | 13.84 V |
| ✅ | `192` | 238.0 | 248.2 | 1.035 | 1.079 | 4.4 % | 13.45 V |
| ✅ | `175` | 238.0 | 248.1 | 1.035 | 1.079 | 4.4 % | 13.36 V |
| ✅ | `530` | 240.5 | 248.0 | 1.045 | 1.078 | 3.3 % | 13.04 V |
| ✅ | `166` | 238.1 | 247.6 | 1.035 | 1.076 | 4.1 % | 12.64 V |
| ✅ | `498` | 238.3 | 247.3 | 1.036 | 1.075 | 3.9 % | 8.09 V |
| ✅ | `491` | 238.3 | 247.2 | 1.036 | 1.075 | 3.9 % | 8.07 V |
| ✅ | `151` | 238.1 | 247.2 | 1.035 | 1.075 | 3.9 % | 12.22 V |
| ✅ | `473` | 238.3 | 247.1 | 1.036 | 1.075 | 3.8 % | 8.05 V |
| ✅ | `145` | 238.1 | 247.1 | 1.035 | 1.074 | 3.9 % | 12.12 V |
| ✅ | `472` | 238.3 | 247.1 | 1.036 | 1.074 | 3.8 % | 8.03 V |
| ✅ | `138` | 238.1 | 247.0 | 1.035 | 1.074 | 3.8 % | 11.99 V |
| ✅ | `439` | 238.3 | 247.0 | 1.036 | 1.074 | 3.7 % | 8.01 V |
| ✅ | `144` | 238.1 | 246.9 | 1.035 | 1.074 | 3.8 % | 11.92 V |
| ✅ | `536` | 238.3 | 246.9 | 1.036 | 1.074 | 3.7 % | 8.0 V |
| ✅ | `428` | 241.0 | 246.9 | 1.048 | 1.073 | 2.6 % | 11.66 V |
| ✅ | `416` | 240.9 | 246.9 | 1.047 | 1.073 | 2.6 % | 11.63 V |
| ✅ | `131` | 238.1 | 246.9 | 1.035 | 1.073 | 3.8 % | 11.85 V |
| ✅ | `391` | 240.8 | 246.8 | 1.047 | 1.073 | 2.6 % | 11.61 V |
| ✅ | `380` | 240.8 | 246.8 | 1.047 | 1.073 | 2.6 % | 11.6 V |
| ✅ | `392` | 240.8 | 246.8 | 1.047 | 1.073 | 2.6 % | 11.6 V |
| ✅ | `366` | 240.7 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.57 V |
| ✅ | `355` | 240.6 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.56 V |
| ✅ | `441` | 240.4 | 246.8 | 1.045 | 1.073 | 2.8 % | 11.5 V |
| ✅ | `348` | 240.5 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.61 V |
| ✅ | `327` | 240.2 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.47 V |
| ✅ | `384` | 240.1 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.46 V |
| ✅ | `427` | 238.3 | 246.8 | 1.036 | 1.073 | 3.7 % | 7.98 V |
| ✅ | `318` | 240.1 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.44 V |
| ✅ | `300` | 239.9 | 246.8 | 1.043 | 1.073 | 3.0 % | 11.42 V |
| ✅ | `479` | 238.3 | 246.6 | 1.036 | 1.072 | 3.6 % | 7.95 V |
| ✅ | `377` | 238.3 | 246.5 | 1.036 | 1.072 | 3.6 % | 7.94 V |
| ✅ | `376` | 238.3 | 246.5 | 1.036 | 1.072 | 3.5 % | 7.93 V |
| ✅ | `354` | 238.3 | 246.4 | 1.036 | 1.071 | 3.5 % | 7.92 V |
| ✅ | `116` | 238.2 | 246.1 | 1.036 | 1.07 | 3.4 % | 10.85 V |
| ✅ | `521` | 238.3 | 246.0 | 1.036 | 1.07 | 3.3 % | 7.9 V |
| ✅ | `128` | 238.3 | 245.9 | 1.036 | 1.069 | 3.3 % | 10.63 V |
| ✅ | `307` | 238.3 | 245.9 | 1.036 | 1.069 | 3.3 % | 7.91 V |
| ✅ | `104` | 238.2 | 245.8 | 1.036 | 1.069 | 3.3 % | 10.51 V |
| ✅ | `198` | 238.3 | 245.7 | 1.036 | 1.068 | 3.3 % | 10.47 V |
| ✅ | `108` | 238.3 | 245.6 | 1.036 | 1.068 | 3.2 % | 10.28 V |
| ✅ | `99` | 238.3 | 245.5 | 1.036 | 1.067 | 3.2 % | 10.22 V |
| ✅ | `256` | 238.3 | 245.5 | 1.036 | 1.067 | 3.1 % | 7.92 V |
| ✅ | `247` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 7.94 V |
| ✅ | `226` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.04 V |
| ✅ | `220` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.06 V |
| ✅ | `219` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.27 V |
| ✅ | `208` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.31 V |
| ✅ | `201` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.81 V |
| ✅ | `188` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.89 V |
| ✅ | `179` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.41 V |
| ✅ | `162` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.49 V |
| ✅ | `187` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.71 V |
| ✅ | `147` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.8 V |
| ✅ | `90` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 10.07 V |
| ✅ | `82` | 238.3 | 245.4 | 1.036 | 1.067 | 3.1 % | 10.07 V |
| ✅ | `62` | 236.1 | 240.7 | 1.027 | 1.046 | 2.0 % | 6.87 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=5.048 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.664 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.619 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=5.222 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.616 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.225 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.687 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.839 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.703 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.89 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=5.003 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.789 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=5.043 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.643 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.227 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=5.195 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=5.247 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.734 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.025 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=5.237 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.668 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.214 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 194.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 18.39 V at bus '896' — reflects the neutral shift under unbalanced loading.

