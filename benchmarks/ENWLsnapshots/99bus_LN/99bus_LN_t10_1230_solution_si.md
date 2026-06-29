# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -190656.0409  
**Solve time:** 0.098 s  
**Findings:** 0 errors · 39 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 34.792 kW |
| Total load | 11.642 kW |
| Total network losses (P) | 23.15 kW |
| Total network losses (Q) | 6.856 kW var |
| Loss fraction | 198.8% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.378 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.087 (`896`) | 4.9 % (`313`) | 15.38 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.1 | 249.9 | 1.04 | 1.087 | 4.7 % | 15.38 V |
| ✅ | `949` | 239.9 | 249.5 | 1.043 | 1.085 | 4.2 % | 14.3 V |
| ✅ | `677` | 239.1 | 249.5 | 1.04 | 1.085 | 4.5 % | 14.89 V |
| ✅ | `660` | 239.1 | 249.5 | 1.04 | 1.085 | 4.5 % | 14.8 V |
| ✅ | `661` | 239.1 | 249.4 | 1.04 | 1.084 | 4.5 % | 14.67 V |
| ✅ | `654` | 239.1 | 249.3 | 1.04 | 1.084 | 4.4 % | 14.54 V |
| ✅ | `644` | 239.1 | 249.3 | 1.04 | 1.084 | 4.4 % | 14.52 V |
| ✅ | `895` | 239.9 | 249.3 | 1.043 | 1.084 | 4.1 % | 14.03 V |
| ✅ | `635` | 239.1 | 249.2 | 1.04 | 1.084 | 4.4 % | 14.44 V |
| ✅ | `904` | 239.9 | 249.1 | 1.043 | 1.083 | 4.0 % | 13.93 V |
| ✅ | `775` | 239.9 | 249.1 | 1.043 | 1.083 | 4.0 % | 14.0 V |
| ✅ | `849` | 239.9 | 249.0 | 1.043 | 1.083 | 4.0 % | 13.81 V |
| ✅ | `894` | 239.9 | 249.0 | 1.043 | 1.083 | 4.0 % | 12.69 V |
| ✅ | `808` | 240.8 | 248.7 | 1.047 | 1.081 | 3.4 % | 14.03 V |
| ✅ | `627` | 239.1 | 248.7 | 1.04 | 1.081 | 4.1 % | 13.75 V |
| ✅ | `693` | 240.0 | 248.7 | 1.044 | 1.081 | 3.8 % | 13.68 V |
| ✅ | `673` | 240.0 | 248.7 | 1.043 | 1.081 | 3.8 % | 13.67 V |
| ✅ | `617` | 239.1 | 248.6 | 1.04 | 1.081 | 4.1 % | 13.7 V |
| ✅ | `618` | 239.1 | 248.6 | 1.04 | 1.081 | 4.1 % | 13.7 V |
| ✅ | `665` | 239.9 | 248.6 | 1.043 | 1.081 | 3.8 % | 13.62 V |
| ✅ | `608` | 239.1 | 248.6 | 1.04 | 1.081 | 4.1 % | 13.67 V |
| ✅ | `779` | 240.5 | 248.6 | 1.046 | 1.081 | 3.5 % | 13.86 V |
| ✅ | `659` | 239.9 | 248.6 | 1.043 | 1.081 | 3.8 % | 13.57 V |
| ✅ | `607` | 239.2 | 248.6 | 1.04 | 1.081 | 4.1 % | 13.62 V |
| ✅ | `600` | 239.2 | 248.5 | 1.04 | 1.08 | 4.1 % | 13.52 V |
| ✅ | `717` | 241.3 | 248.4 | 1.049 | 1.08 | 3.1 % | 14.13 V |
| ✅ | `655` | 240.8 | 248.4 | 1.047 | 1.08 | 3.3 % | 13.88 V |
| ✅ | `609` | 240.7 | 248.4 | 1.046 | 1.08 | 3.4 % | 13.83 V |
| ✅ | `773` | 240.5 | 248.4 | 1.046 | 1.08 | 3.5 % | 13.76 V |
| ✅ | `568` | 239.8 | 248.4 | 1.043 | 1.08 | 3.7 % | 13.42 V |
| ✅ | `545` | 239.2 | 248.0 | 1.04 | 1.078 | 3.8 % | 12.96 V |
| ✅ | `498` | 236.7 | 247.8 | 1.029 | 1.077 | 4.8 % | 3.25 V |
| ✅ | `491` | 236.7 | 247.7 | 1.029 | 1.077 | 4.8 % | 3.23 V |
| ✅ | `473` | 236.7 | 247.7 | 1.029 | 1.077 | 4.8 % | 3.2 V |
| ✅ | `472` | 236.7 | 247.6 | 1.029 | 1.076 | 4.7 % | 3.18 V |
| ✅ | `439` | 236.7 | 247.5 | 1.029 | 1.076 | 4.7 % | 3.16 V |
| ✅ | `536` | 236.7 | 247.5 | 1.029 | 1.076 | 4.7 % | 3.15 V |
| ✅ | `313` | 236.2 | 247.5 | 1.027 | 1.076 | 4.9 % | 12.68 V |
| ✅ | `303` | 236.2 | 247.4 | 1.027 | 1.076 | 4.9 % | 12.6 V |
| ✅ | `290` | 236.2 | 247.4 | 1.027 | 1.075 | 4.9 % | 12.52 V |
| ✅ | `427` | 236.7 | 247.4 | 1.029 | 1.075 | 4.6 % | 3.14 V |
| ✅ | `282` | 236.2 | 247.3 | 1.027 | 1.075 | 4.8 % | 12.49 V |
| ✅ | `272` | 236.2 | 247.3 | 1.027 | 1.075 | 4.8 % | 12.39 V |
| ✅ | `479` | 236.7 | 247.2 | 1.029 | 1.075 | 4.6 % | 3.11 V |
| ✅ | `377` | 236.7 | 247.1 | 1.029 | 1.074 | 4.5 % | 3.12 V |
| ✅ | `376` | 236.7 | 247.1 | 1.029 | 1.074 | 4.5 % | 3.11 V |
| ✅ | `321` | 236.2 | 247.1 | 1.027 | 1.074 | 4.7 % | 12.08 V |
| ✅ | `264` | 236.3 | 247.0 | 1.027 | 1.074 | 4.7 % | 11.97 V |
| ✅ | `354` | 236.7 | 247.0 | 1.029 | 1.074 | 4.5 % | 3.12 V |
| ✅ | `263` | 236.3 | 246.8 | 1.027 | 1.073 | 4.6 % | 11.67 V |
| ✅ | `254` | 236.3 | 246.7 | 1.027 | 1.073 | 4.5 % | 11.58 V |
| ✅ | `521` | 236.7 | 246.6 | 1.029 | 1.072 | 4.3 % | 3.17 V |
| ✅ | `307` | 236.7 | 246.5 | 1.029 | 1.072 | 4.3 % | 3.21 V |
| ✅ | `229` | 236.3 | 246.5 | 1.027 | 1.072 | 4.4 % | 11.2 V |
| ✅ | `216` | 236.3 | 246.4 | 1.028 | 1.071 | 4.4 % | 11.1 V |
| ✅ | `192` | 236.4 | 246.1 | 1.028 | 1.07 | 4.3 % | 10.72 V |
| ✅ | `256` | 236.7 | 246.1 | 1.029 | 1.07 | 4.1 % | 3.35 V |
| ✅ | `175` | 236.4 | 246.1 | 1.028 | 1.07 | 4.2 % | 10.63 V |
| ✅ | `530` | 238.3 | 246.1 | 1.036 | 1.07 | 3.4 % | 10.47 V |
| ✅ | `247` | 236.7 | 246.0 | 1.029 | 1.07 | 4.0 % | 3.4 V |
| ✅ | `166` | 236.5 | 245.7 | 1.028 | 1.068 | 4.0 % | 9.89 V |
| ✅ | `226` | 236.7 | 245.4 | 1.029 | 1.067 | 3.8 % | 3.72 V |
| ✅ | `220` | 236.7 | 245.3 | 1.029 | 1.067 | 3.8 % | 3.79 V |
| ✅ | `151` | 236.5 | 245.3 | 1.028 | 1.067 | 3.8 % | 9.51 V |
| ✅ | `145` | 236.5 | 245.2 | 1.028 | 1.066 | 3.8 % | 9.42 V |
| ✅ | `138` | 236.5 | 245.1 | 1.028 | 1.066 | 3.8 % | 9.28 V |
| ✅ | `144` | 236.5 | 245.1 | 1.028 | 1.066 | 3.7 % | 9.23 V |
| ✅ | `428` | 238.9 | 245.0 | 1.039 | 1.065 | 2.7 % | 9.34 V |
| ✅ | `416` | 238.8 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.3 V |
| ✅ | `391` | 238.7 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.26 V |
| ✅ | `380` | 238.7 | 245.0 | 1.038 | 1.065 | 2.7 % | 9.26 V |
| ✅ | `392` | 238.7 | 245.0 | 1.038 | 1.065 | 2.8 % | 9.25 V |
| ✅ | `131` | 236.5 | 245.0 | 1.028 | 1.065 | 3.7 % | 9.14 V |
| ✅ | `366` | 238.6 | 245.0 | 1.037 | 1.065 | 2.8 % | 9.2 V |
| ✅ | `355` | 238.6 | 245.0 | 1.037 | 1.065 | 2.8 % | 9.18 V |
| ✅ | `441` | 238.4 | 245.0 | 1.036 | 1.065 | 2.9 % | 9.09 V |
| ✅ | `348` | 238.6 | 245.0 | 1.037 | 1.065 | 2.8 % | 9.25 V |
| ✅ | `327` | 238.2 | 245.0 | 1.036 | 1.065 | 2.9 % | 9.03 V |
| ✅ | `384` | 238.2 | 245.0 | 1.035 | 1.065 | 3.0 % | 9.01 V |
| ✅ | `318` | 238.1 | 245.0 | 1.035 | 1.065 | 3.0 % | 8.98 V |
| ✅ | `300` | 238.0 | 245.0 | 1.035 | 1.065 | 3.0 % | 8.93 V |
| ✅ | `219` | 236.7 | 244.6 | 1.029 | 1.064 | 3.5 % | 4.32 V |
| ✅ | `208` | 236.7 | 244.5 | 1.029 | 1.063 | 3.4 % | 4.4 V |
| ✅ | `116` | 236.6 | 244.4 | 1.029 | 1.063 | 3.4 % | 8.16 V |
| ✅ | `128` | 236.6 | 244.3 | 1.029 | 1.062 | 3.3 % | 7.94 V |
| ✅ | `198` | 236.6 | 244.1 | 1.029 | 1.061 | 3.2 % | 7.78 V |
| ✅ | `104` | 236.6 | 244.1 | 1.029 | 1.061 | 3.2 % | 7.83 V |
| ✅ | `108` | 236.6 | 243.9 | 1.029 | 1.061 | 3.2 % | 7.61 V |
| ✅ | `99` | 236.6 | 243.9 | 1.029 | 1.06 | 3.1 % | 7.55 V |
| ✅ | `201` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 5.4 V |
| ✅ | `188` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 5.51 V |
| ✅ | `179` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 6.36 V |
| ✅ | `162` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 6.47 V |
| ✅ | `187` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 6.8 V |
| ✅ | `147` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 6.93 V |
| ✅ | `90` | 236.7 | 243.8 | 1.029 | 1.06 | 3.1 % | 7.38 V |
| ✅ | `82` | 236.7 | 243.7 | 1.029 | 1.06 | 3.1 % | 7.41 V |
| ✅ | `62` | 235.1 | 239.6 | 1.022 | 1.042 | 2.0 % | 5.17 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.677 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.483 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.721 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.824 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.307 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.862 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=5.009 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.585 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.465 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.441 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.167 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.022 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.152 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.418 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.934 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=5.086 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.562 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.42 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.601 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.456 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.822 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.461 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.346 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.236 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.562 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.75 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.028 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.479 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.213 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.969 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.502 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.447 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=5.015 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=5.03 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.613 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.444 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_29`  
  IBR 'pv_29' phase 'a': pg=4.417 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 198.8 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.38 V at bus '896' — reflects the neutral shift under unbalanced loading.

