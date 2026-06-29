# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:26  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -184937.7931  
**Solve time:** 0.21 s  
**Findings:** 0 errors · 33 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 41.758 kW |
| Total load | 19.861 kW |
| Total network losses (P) | 21.897 kW |
| Total network losses (Q) | 6.535 kW var |
| Loss fraction | 110.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.026 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.084 (`896`) | 4.8 % (`313`) | 15.03 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.2 | 249.4 | 1.04 | 1.084 | 4.4 % | 15.03 V |
| ✅ | `949` | 239.9 | 249.1 | 1.043 | 1.083 | 4.0 % | 14.09 V |
| ✅ | `660` | 239.2 | 248.9 | 1.04 | 1.082 | 4.2 % | 14.46 V |
| ✅ | `677` | 239.2 | 248.8 | 1.04 | 1.082 | 4.2 % | 14.54 V |
| ✅ | `661` | 239.2 | 248.8 | 1.04 | 1.082 | 4.2 % | 14.33 V |
| ✅ | `895` | 239.9 | 248.8 | 1.043 | 1.082 | 3.9 % | 13.83 V |
| ✅ | `654` | 239.2 | 248.8 | 1.04 | 1.082 | 4.2 % | 14.21 V |
| ✅ | `644` | 239.2 | 248.7 | 1.04 | 1.081 | 4.1 % | 14.19 V |
| ✅ | `904` | 239.9 | 248.7 | 1.043 | 1.081 | 3.8 % | 13.74 V |
| ✅ | `635` | 239.2 | 248.7 | 1.04 | 1.081 | 4.1 % | 14.1 V |
| ✅ | `775` | 240.0 | 248.6 | 1.044 | 1.081 | 3.7 % | 13.75 V |
| ✅ | `849` | 240.0 | 248.6 | 1.043 | 1.081 | 3.7 % | 13.63 V |
| ✅ | `894` | 240.0 | 248.6 | 1.043 | 1.081 | 3.7 % | 12.75 V |
| ✅ | `808` | 240.8 | 248.2 | 1.047 | 1.079 | 3.2 % | 13.79 V |
| ✅ | `693` | 240.1 | 248.2 | 1.044 | 1.079 | 3.5 % | 13.47 V |
| ✅ | `673` | 240.0 | 248.2 | 1.044 | 1.079 | 3.5 % | 13.45 V |
| ✅ | `627` | 239.2 | 248.1 | 1.04 | 1.079 | 3.9 % | 13.45 V |
| ✅ | `665` | 240.0 | 248.1 | 1.043 | 1.079 | 3.5 % | 13.41 V |
| ✅ | `617` | 239.2 | 248.1 | 1.04 | 1.079 | 3.9 % | 13.4 V |
| ✅ | `779` | 240.6 | 248.1 | 1.046 | 1.079 | 3.3 % | 13.7 V |
| ✅ | `618` | 239.2 | 248.1 | 1.04 | 1.079 | 3.9 % | 13.4 V |
| ✅ | `659` | 240.0 | 248.1 | 1.043 | 1.079 | 3.5 % | 13.36 V |
| ✅ | `608` | 239.2 | 248.1 | 1.04 | 1.079 | 3.9 % | 13.37 V |
| ✅ | `607` | 239.2 | 248.0 | 1.04 | 1.078 | 3.8 % | 13.33 V |
| ✅ | `600` | 239.2 | 248.0 | 1.04 | 1.078 | 3.8 % | 13.23 V |
| ✅ | `717` | 241.3 | 247.9 | 1.049 | 1.078 | 2.9 % | 13.96 V |
| ✅ | `655` | 240.9 | 247.9 | 1.047 | 1.078 | 3.1 % | 13.71 V |
| ✅ | `609` | 240.8 | 247.9 | 1.047 | 1.078 | 3.1 % | 13.66 V |
| ✅ | `773` | 240.6 | 247.9 | 1.046 | 1.078 | 3.2 % | 13.57 V |
| ✅ | `568` | 239.9 | 247.9 | 1.043 | 1.078 | 3.5 % | 13.21 V |
| ✅ | `545` | 239.3 | 247.5 | 1.04 | 1.076 | 3.6 % | 12.72 V |
| ✅ | `313` | 236.2 | 247.2 | 1.027 | 1.075 | 4.8 % | 12.4 V |
| ✅ | `303` | 236.3 | 247.1 | 1.027 | 1.074 | 4.7 % | 12.32 V |
| ✅ | `498` | 236.8 | 247.1 | 1.029 | 1.074 | 4.5 % | 2.6 V |
| ✅ | `290` | 236.3 | 247.1 | 1.027 | 1.074 | 4.7 % | 12.24 V |
| ✅ | `491` | 236.8 | 247.0 | 1.029 | 1.074 | 4.5 % | 2.58 V |
| ✅ | `282` | 236.3 | 247.0 | 1.027 | 1.074 | 4.7 % | 12.2 V |
| ✅ | `272` | 236.3 | 247.0 | 1.027 | 1.074 | 4.7 % | 12.1 V |
| ✅ | `473` | 236.8 | 247.0 | 1.029 | 1.074 | 4.4 % | 2.56 V |
| ✅ | `472` | 236.8 | 246.9 | 1.029 | 1.073 | 4.4 % | 2.54 V |
| ✅ | `439` | 236.8 | 246.8 | 1.029 | 1.073 | 4.4 % | 2.53 V |
| ✅ | `321` | 236.3 | 246.7 | 1.027 | 1.073 | 4.5 % | 11.77 V |
| ✅ | `536` | 236.8 | 246.7 | 1.029 | 1.073 | 4.3 % | 2.52 V |
| ✅ | `264` | 236.3 | 246.7 | 1.027 | 1.072 | 4.5 % | 11.67 V |
| ✅ | `427` | 236.8 | 246.6 | 1.029 | 1.072 | 4.3 % | 2.52 V |
| ✅ | `479` | 236.8 | 246.5 | 1.029 | 1.072 | 4.2 % | 2.52 V |
| ✅ | `263` | 236.3 | 246.4 | 1.028 | 1.071 | 4.4 % | 11.35 V |
| ✅ | `254` | 236.3 | 246.4 | 1.028 | 1.071 | 4.4 % | 11.27 V |
| ✅ | `377` | 236.8 | 246.4 | 1.029 | 1.071 | 4.2 % | 2.53 V |
| ✅ | `376` | 236.8 | 246.3 | 1.029 | 1.071 | 4.2 % | 2.53 V |
| ✅ | `354` | 236.8 | 246.2 | 1.029 | 1.071 | 4.1 % | 2.55 V |
| ✅ | `229` | 236.4 | 246.1 | 1.028 | 1.07 | 4.2 % | 10.9 V |
| ✅ | `216` | 236.4 | 246.1 | 1.028 | 1.07 | 4.2 % | 10.8 V |
| ✅ | `521` | 236.8 | 245.9 | 1.029 | 1.069 | 4.0 % | 2.65 V |
| ✅ | `192` | 236.4 | 245.8 | 1.028 | 1.069 | 4.1 % | 10.41 V |
| ✅ | `307` | 236.8 | 245.8 | 1.029 | 1.069 | 3.9 % | 2.7 V |
| ✅ | `175` | 236.4 | 245.7 | 1.028 | 1.068 | 4.0 % | 10.33 V |
| ✅ | `530` | 238.4 | 245.6 | 1.036 | 1.068 | 3.2 % | 10.3 V |
| ✅ | `256` | 236.8 | 245.4 | 1.029 | 1.067 | 3.7 % | 2.91 V |
| ✅ | `247` | 236.8 | 245.3 | 1.029 | 1.066 | 3.7 % | 2.97 V |
| ✅ | `166` | 236.5 | 245.3 | 1.028 | 1.066 | 3.8 % | 9.58 V |
| ✅ | `151` | 236.5 | 244.9 | 1.028 | 1.065 | 3.6 % | 9.23 V |
| ✅ | `145` | 236.5 | 244.9 | 1.028 | 1.065 | 3.6 % | 9.14 V |
| ✅ | `138` | 236.5 | 244.7 | 1.028 | 1.064 | 3.6 % | 9.01 V |
| ✅ | `226` | 236.8 | 244.7 | 1.029 | 1.064 | 3.5 % | 3.37 V |
| ✅ | `144` | 236.6 | 244.7 | 1.028 | 1.064 | 3.5 % | 8.95 V |
| ✅ | `428` | 239.0 | 244.7 | 1.039 | 1.064 | 2.5 % | 9.24 V |
| ✅ | `131` | 236.6 | 244.6 | 1.029 | 1.064 | 3.5 % | 8.88 V |
| ✅ | `416` | 238.9 | 244.6 | 1.039 | 1.064 | 2.5 % | 9.2 V |
| ✅ | `391` | 238.8 | 244.6 | 1.038 | 1.064 | 2.5 % | 9.15 V |
| ✅ | `380` | 238.8 | 244.6 | 1.038 | 1.064 | 2.5 % | 9.15 V |
| ✅ | `392` | 238.8 | 244.6 | 1.038 | 1.064 | 2.5 % | 9.15 V |
| ✅ | `366` | 238.7 | 244.6 | 1.038 | 1.064 | 2.6 % | 9.09 V |
| ✅ | `355` | 238.6 | 244.6 | 1.038 | 1.064 | 2.6 % | 9.07 V |
| ✅ | `220` | 236.8 | 244.6 | 1.029 | 1.064 | 3.4 % | 3.45 V |
| ✅ | `441` | 238.4 | 244.6 | 1.037 | 1.064 | 2.7 % | 8.96 V |
| ✅ | `348` | 238.6 | 244.6 | 1.037 | 1.063 | 2.6 % | 9.1 V |
| ✅ | `327` | 238.3 | 244.6 | 1.036 | 1.063 | 2.7 % | 8.9 V |
| ✅ | `384` | 238.2 | 244.6 | 1.036 | 1.063 | 2.8 % | 8.87 V |
| ✅ | `318` | 238.2 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.84 V |
| ✅ | `300` | 238.0 | 244.6 | 1.035 | 1.063 | 2.8 % | 8.78 V |
| ✅ | `116` | 236.7 | 244.1 | 1.029 | 1.061 | 3.2 % | 7.92 V |
| ✅ | `219` | 236.8 | 243.9 | 1.029 | 1.061 | 3.1 % | 4.04 V |
| ✅ | `128` | 236.7 | 243.9 | 1.029 | 1.061 | 3.2 % | 7.69 V |
| ✅ | `208` | 236.8 | 243.8 | 1.029 | 1.06 | 3.1 % | 4.13 V |
| ✅ | `198` | 236.7 | 243.7 | 1.029 | 1.06 | 3.1 % | 7.57 V |
| ✅ | `104` | 236.7 | 243.7 | 1.029 | 1.06 | 3.1 % | 7.62 V |
| ✅ | `108` | 236.7 | 243.6 | 1.029 | 1.059 | 3.0 % | 7.41 V |
| ✅ | `99` | 236.7 | 243.5 | 1.029 | 1.059 | 3.0 % | 7.36 V |
| ✅ | `201` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 5.21 V |
| ✅ | `188` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 5.31 V |
| ✅ | `179` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 6.17 V |
| ✅ | `162` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 6.29 V |
| ✅ | `187` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 6.65 V |
| ✅ | `147` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 6.75 V |
| ✅ | `90` | 236.8 | 243.4 | 1.029 | 1.058 | 2.9 % | 7.2 V |
| ✅ | `82` | 236.7 | 243.4 | 1.029 | 1.058 | 2.9 % | 7.22 V |
| ✅ | `62` | 235.1 | 239.3 | 1.022 | 1.041 | 1.8 % | 5.05 V |
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
  IBR 'pv_44' phase 'a': pg=4.558 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.828 kW is within 1 % of its P bound.
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
  IBR 'pv_12' phase 'b': pg=5.149 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.562 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.417 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.62 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.617 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=5.108 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.42 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_19`  
  IBR 'pv_19' phase 'a': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.629 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 110.2 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.03 V at bus '896' — reflects the neutral shift under unbalanced loading.

