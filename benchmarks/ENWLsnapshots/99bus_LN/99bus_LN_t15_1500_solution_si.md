# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:25  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -191093.7637  
**Solve time:** 0.114 s  
**Findings:** 0 errors · 32 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 40.164 kW |
| Total load | 16.896 kW |
| Total network losses (P) | 23.268 kW |
| Total network losses (Q) | 6.925 kW var |
| Loss fraction | 137.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.18 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.086 (`896`) | 4.8 % (`498`) | 15.18 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.3 | 249.7 | 1.04 | 1.086 | 4.5 % | 15.18 V |
| ✅ | `949` | 240.1 | 249.4 | 1.044 | 1.085 | 4.1 % | 14.22 V |
| ✅ | `677` | 239.3 | 249.2 | 1.041 | 1.084 | 4.3 % | 14.69 V |
| ✅ | `660` | 239.3 | 249.2 | 1.041 | 1.084 | 4.3 % | 14.6 V |
| ✅ | `661` | 239.3 | 249.2 | 1.041 | 1.083 | 4.3 % | 14.47 V |
| ✅ | `895` | 240.1 | 249.2 | 1.044 | 1.083 | 4.0 % | 13.94 V |
| ✅ | `654` | 239.3 | 249.1 | 1.041 | 1.083 | 4.2 % | 14.34 V |
| ✅ | `644` | 239.3 | 249.1 | 1.041 | 1.083 | 4.2 % | 14.32 V |
| ✅ | `904` | 240.1 | 249.0 | 1.044 | 1.083 | 3.9 % | 13.84 V |
| ✅ | `635` | 239.3 | 249.0 | 1.041 | 1.083 | 4.2 % | 14.24 V |
| ✅ | `775` | 240.1 | 248.9 | 1.044 | 1.082 | 3.8 % | 13.86 V |
| ✅ | `849` | 240.1 | 248.9 | 1.044 | 1.082 | 3.8 % | 13.71 V |
| ✅ | `894` | 240.1 | 248.9 | 1.044 | 1.082 | 3.8 % | 12.74 V |
| ✅ | `808` | 240.9 | 248.5 | 1.047 | 1.081 | 3.3 % | 13.82 V |
| ✅ | `693` | 240.2 | 248.5 | 1.044 | 1.081 | 3.6 % | 13.53 V |
| ✅ | `673` | 240.2 | 248.5 | 1.044 | 1.081 | 3.6 % | 13.52 V |
| ✅ | `665` | 240.1 | 248.5 | 1.044 | 1.08 | 3.6 % | 13.48 V |
| ✅ | `627` | 239.4 | 248.5 | 1.041 | 1.08 | 4.0 % | 13.55 V |
| ✅ | `779` | 240.7 | 248.4 | 1.047 | 1.08 | 3.3 % | 13.74 V |
| ✅ | `617` | 239.4 | 248.4 | 1.041 | 1.08 | 3.9 % | 13.51 V |
| ✅ | `618` | 239.4 | 248.4 | 1.041 | 1.08 | 3.9 % | 13.51 V |
| ✅ | `659` | 240.1 | 248.4 | 1.044 | 1.08 | 3.6 % | 13.43 V |
| ✅ | `608` | 239.4 | 248.4 | 1.041 | 1.08 | 3.9 % | 13.48 V |
| ✅ | `607` | 239.4 | 248.4 | 1.041 | 1.08 | 3.9 % | 13.42 V |
| ✅ | `600` | 239.4 | 248.3 | 1.041 | 1.08 | 3.9 % | 13.33 V |
| ✅ | `717` | 241.5 | 248.3 | 1.05 | 1.079 | 2.9 % | 14.0 V |
| ✅ | `655` | 241.0 | 248.3 | 1.048 | 1.079 | 3.1 % | 13.75 V |
| ✅ | `609` | 240.9 | 248.3 | 1.047 | 1.079 | 3.2 % | 13.7 V |
| ✅ | `773` | 240.7 | 248.3 | 1.046 | 1.079 | 3.3 % | 13.61 V |
| ✅ | `568` | 240.0 | 248.2 | 1.044 | 1.079 | 3.6 % | 13.27 V |
| ✅ | `498` | 236.9 | 248.0 | 1.03 | 1.078 | 4.8 % | 3.41 V |
| ✅ | `491` | 236.9 | 247.9 | 1.03 | 1.078 | 4.8 % | 3.37 V |
| ✅ | `473` | 236.9 | 247.8 | 1.03 | 1.078 | 4.8 % | 3.34 V |
| ✅ | `545` | 239.4 | 247.8 | 1.041 | 1.077 | 3.7 % | 12.78 V |
| ✅ | `472` | 236.9 | 247.7 | 1.03 | 1.077 | 4.7 % | 3.3 V |
| ✅ | `439` | 236.9 | 247.7 | 1.03 | 1.077 | 4.7 % | 3.27 V |
| ✅ | `536` | 236.9 | 247.6 | 1.03 | 1.077 | 4.7 % | 3.24 V |
| ✅ | `427` | 236.9 | 247.5 | 1.03 | 1.076 | 4.6 % | 3.21 V |
| ✅ | `313` | 236.4 | 247.3 | 1.028 | 1.075 | 4.8 % | 12.46 V |
| ✅ | `479` | 236.9 | 247.3 | 1.03 | 1.075 | 4.5 % | 3.16 V |
| ✅ | `303` | 236.4 | 247.3 | 1.028 | 1.075 | 4.7 % | 12.38 V |
| ✅ | `377` | 236.9 | 247.2 | 1.03 | 1.075 | 4.5 % | 3.15 V |
| ✅ | `290` | 236.4 | 247.2 | 1.028 | 1.075 | 4.7 % | 12.3 V |
| ✅ | `282` | 236.4 | 247.2 | 1.028 | 1.075 | 4.7 % | 12.26 V |
| ✅ | `376` | 236.9 | 247.2 | 1.03 | 1.075 | 4.5 % | 3.13 V |
| ✅ | `272` | 236.4 | 247.1 | 1.028 | 1.075 | 4.7 % | 12.16 V |
| ✅ | `354` | 236.9 | 247.1 | 1.03 | 1.074 | 4.4 % | 3.13 V |
| ✅ | `321` | 236.4 | 246.9 | 1.028 | 1.074 | 4.6 % | 11.85 V |
| ✅ | `264` | 236.4 | 246.9 | 1.028 | 1.073 | 4.5 % | 11.74 V |
| ✅ | `521` | 236.9 | 246.7 | 1.03 | 1.073 | 4.3 % | 3.11 V |
| ✅ | `263` | 236.5 | 246.6 | 1.028 | 1.072 | 4.4 % | 11.44 V |
| ✅ | `307` | 236.9 | 246.6 | 1.03 | 1.072 | 4.2 % | 3.13 V |
| ✅ | `254` | 236.5 | 246.6 | 1.028 | 1.072 | 4.4 % | 11.35 V |
| ✅ | `229` | 236.5 | 246.3 | 1.028 | 1.071 | 4.3 % | 10.97 V |
| ✅ | `216` | 236.5 | 246.3 | 1.028 | 1.071 | 4.2 % | 10.87 V |
| ✅ | `256` | 236.9 | 246.2 | 1.03 | 1.071 | 4.1 % | 3.21 V |
| ✅ | `247` | 236.9 | 246.1 | 1.03 | 1.07 | 4.0 % | 3.26 V |
| ✅ | `192` | 236.5 | 246.0 | 1.028 | 1.069 | 4.1 % | 10.48 V |
| ✅ | `175` | 236.5 | 245.9 | 1.028 | 1.069 | 4.1 % | 10.39 V |
| ✅ | `530` | 238.5 | 245.9 | 1.037 | 1.069 | 3.2 % | 10.27 V |
| ✅ | `166` | 236.6 | 245.5 | 1.029 | 1.068 | 3.9 % | 9.66 V |
| ✅ | `226` | 236.9 | 245.5 | 1.03 | 1.067 | 3.8 % | 3.53 V |
| ✅ | `220` | 236.9 | 245.4 | 1.03 | 1.067 | 3.7 % | 3.59 V |
| ✅ | `151` | 236.6 | 245.1 | 1.029 | 1.066 | 3.7 % | 9.27 V |
| ✅ | `145` | 236.7 | 245.1 | 1.029 | 1.065 | 3.7 % | 9.17 V |
| ✅ | `138` | 236.7 | 245.0 | 1.029 | 1.065 | 3.6 % | 9.04 V |
| ✅ | `144` | 236.7 | 244.9 | 1.029 | 1.065 | 3.6 % | 8.98 V |
| ✅ | `428` | 239.1 | 244.9 | 1.04 | 1.065 | 2.5 % | 9.15 V |
| ✅ | `416` | 239.0 | 244.9 | 1.039 | 1.065 | 2.5 % | 9.1 V |
| ✅ | `391` | 238.9 | 244.9 | 1.039 | 1.065 | 2.6 % | 9.06 V |
| ✅ | `392` | 238.9 | 244.9 | 1.039 | 1.065 | 2.6 % | 9.05 V |
| ✅ | `380` | 238.9 | 244.9 | 1.039 | 1.065 | 2.6 % | 9.04 V |
| ✅ | `131` | 236.7 | 244.9 | 1.029 | 1.065 | 3.6 % | 8.9 V |
| ✅ | `366` | 238.8 | 244.9 | 1.038 | 1.065 | 2.6 % | 9.0 V |
| ✅ | `355` | 238.8 | 244.9 | 1.038 | 1.065 | 2.6 % | 8.97 V |
| ✅ | `441` | 238.6 | 244.8 | 1.037 | 1.065 | 2.7 % | 8.89 V |
| ✅ | `348` | 238.8 | 244.8 | 1.038 | 1.064 | 2.6 % | 9.03 V |
| ✅ | `327` | 238.4 | 244.8 | 1.037 | 1.064 | 2.8 % | 8.82 V |
| ✅ | `384` | 238.4 | 244.8 | 1.036 | 1.064 | 2.8 % | 8.79 V |
| ✅ | `318` | 238.3 | 244.8 | 1.036 | 1.064 | 2.8 % | 8.77 V |
| ✅ | `300` | 238.2 | 244.8 | 1.036 | 1.064 | 2.9 % | 8.71 V |
| ✅ | `219` | 236.9 | 244.7 | 1.03 | 1.064 | 3.4 % | 4.07 V |
| ✅ | `208` | 236.9 | 244.6 | 1.03 | 1.064 | 3.4 % | 4.15 V |
| ✅ | `116` | 236.8 | 244.2 | 1.029 | 1.062 | 3.2 % | 7.89 V |
| ✅ | `128` | 236.8 | 244.2 | 1.03 | 1.062 | 3.2 % | 7.7 V |
| ✅ | `198` | 236.8 | 243.9 | 1.03 | 1.061 | 3.1 % | 7.54 V |
| ✅ | `104` | 236.8 | 243.9 | 1.03 | 1.06 | 3.1 % | 7.59 V |
| ✅ | `108` | 236.8 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.37 V |
| ✅ | `99` | 236.8 | 243.7 | 1.03 | 1.06 | 3.0 % | 7.31 V |
| ✅ | `201` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 5.13 V |
| ✅ | `188` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 5.25 V |
| ✅ | `179` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 6.09 V |
| ✅ | `162` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 6.22 V |
| ✅ | `187` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 6.58 V |
| ✅ | `147` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 6.69 V |
| ✅ | `90` | 236.9 | 243.6 | 1.03 | 1.059 | 2.9 % | 7.14 V |
| ✅ | `82` | 236.8 | 243.6 | 1.03 | 1.059 | 2.9 % | 7.17 V |
| ✅ | `62` | 235.2 | 239.5 | 1.023 | 1.041 | 1.8 % | 5.0 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.682 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.429 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=5.207 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=5.048 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.839 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.794 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.27 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.89 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=5.175 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.687 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=5.141 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.619 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.65 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.059 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.646 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.615 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.621 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.81 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.734 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.248 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.331 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.703 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.947 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.573 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.618 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.665 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 137.7 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.18 V at bus '896' — reflects the neutral shift under unbalanced loading.

