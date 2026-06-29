# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -193942.5863  
**Solve time:** 0.082 s  
**Findings:** 0 errors · 29 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 36.92 kW |
| Total load | 13.109 kW |
| Total network losses (P) | 23.811 kW |
| Total network losses (Q) | 7.091 kW var |
| Loss fraction | 181.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.185 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.087 (`896`) | 4.9 % (`498`) | 15.19 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 239.5 | 249.9 | 1.041 | 1.087 | 4.6 % | 15.19 V |
| ✅ | `949` | 240.3 | 249.7 | 1.045 | 1.086 | 4.1 % | 14.21 V |
| ✅ | `677` | 239.5 | 249.5 | 1.041 | 1.085 | 4.4 % | 14.7 V |
| ✅ | `660` | 239.5 | 249.5 | 1.041 | 1.085 | 4.3 % | 14.61 V |
| ✅ | `661` | 239.5 | 249.4 | 1.041 | 1.085 | 4.3 % | 14.48 V |
| ✅ | `895` | 240.3 | 249.4 | 1.045 | 1.084 | 4.0 % | 13.93 V |
| ✅ | `654` | 239.5 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.35 V |
| ✅ | `644` | 239.5 | 249.3 | 1.041 | 1.084 | 4.3 % | 14.33 V |
| ✅ | `904` | 240.3 | 249.3 | 1.045 | 1.084 | 3.9 % | 13.83 V |
| ✅ | `635` | 239.5 | 249.3 | 1.041 | 1.084 | 4.2 % | 14.24 V |
| ✅ | `775` | 240.3 | 249.2 | 1.045 | 1.083 | 3.8 % | 13.86 V |
| ✅ | `849` | 240.3 | 249.1 | 1.045 | 1.083 | 3.9 % | 13.7 V |
| ✅ | `894` | 240.3 | 249.1 | 1.045 | 1.083 | 3.9 % | 12.67 V |
| ✅ | `808` | 241.2 | 248.8 | 1.049 | 1.082 | 3.3 % | 13.88 V |
| ✅ | `693` | 240.4 | 248.8 | 1.045 | 1.082 | 3.6 % | 13.54 V |
| ✅ | `673` | 240.4 | 248.8 | 1.045 | 1.082 | 3.7 % | 13.53 V |
| ✅ | `627` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.56 V |
| ✅ | `665` | 240.3 | 248.7 | 1.045 | 1.081 | 3.7 % | 13.48 V |
| ✅ | `617` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.52 V |
| ✅ | `618` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.51 V |
| ✅ | `779` | 241.0 | 248.7 | 1.048 | 1.081 | 3.4 % | 13.75 V |
| ✅ | `608` | 239.5 | 248.7 | 1.041 | 1.081 | 4.0 % | 13.48 V |
| ✅ | `659` | 240.3 | 248.7 | 1.045 | 1.081 | 3.6 % | 13.43 V |
| ✅ | `607` | 239.5 | 248.6 | 1.041 | 1.081 | 3.9 % | 13.43 V |
| ✅ | `600` | 239.5 | 248.5 | 1.042 | 1.081 | 3.9 % | 13.33 V |
| ✅ | `717` | 241.7 | 248.5 | 1.051 | 1.081 | 3.0 % | 14.0 V |
| ✅ | `655` | 241.2 | 248.5 | 1.049 | 1.081 | 3.2 % | 13.75 V |
| ✅ | `609` | 241.1 | 248.5 | 1.048 | 1.08 | 3.2 % | 13.7 V |
| ✅ | `773` | 240.9 | 248.5 | 1.047 | 1.08 | 3.3 % | 13.61 V |
| ✅ | `568` | 240.2 | 248.5 | 1.044 | 1.08 | 3.6 % | 13.27 V |
| ✅ | `498` | 237.0 | 248.3 | 1.03 | 1.079 | 4.9 % | 3.58 V |
| ✅ | `491` | 237.0 | 248.2 | 1.03 | 1.079 | 4.9 % | 3.54 V |
| ✅ | `473` | 237.0 | 248.1 | 1.03 | 1.079 | 4.8 % | 3.5 V |
| ✅ | `545` | 239.6 | 248.0 | 1.042 | 1.078 | 3.7 % | 12.78 V |
| ✅ | `472` | 237.0 | 248.0 | 1.03 | 1.078 | 4.8 % | 3.45 V |
| ✅ | `439` | 237.0 | 248.0 | 1.03 | 1.078 | 4.8 % | 3.42 V |
| ✅ | `536` | 237.0 | 247.9 | 1.03 | 1.078 | 4.7 % | 3.39 V |
| ✅ | `427` | 237.0 | 247.8 | 1.03 | 1.077 | 4.7 % | 3.35 V |
| ✅ | `479` | 237.0 | 247.6 | 1.03 | 1.077 | 4.6 % | 3.29 V |
| ✅ | `377` | 237.0 | 247.5 | 1.03 | 1.076 | 4.6 % | 3.27 V |
| ✅ | `313` | 236.5 | 247.5 | 1.028 | 1.076 | 4.8 % | 12.45 V |
| ✅ | `376` | 237.0 | 247.5 | 1.03 | 1.076 | 4.6 % | 3.25 V |
| ✅ | `303` | 236.5 | 247.4 | 1.028 | 1.076 | 4.8 % | 12.37 V |
| ✅ | `290` | 236.5 | 247.4 | 1.028 | 1.076 | 4.7 % | 12.29 V |
| ✅ | `282` | 236.5 | 247.4 | 1.028 | 1.076 | 4.7 % | 12.26 V |
| ✅ | `354` | 237.0 | 247.4 | 1.03 | 1.075 | 4.5 % | 3.24 V |
| ✅ | `272` | 236.5 | 247.3 | 1.028 | 1.075 | 4.7 % | 12.16 V |
| ✅ | `321` | 236.5 | 247.1 | 1.028 | 1.074 | 4.6 % | 11.85 V |
| ✅ | `264` | 236.5 | 247.0 | 1.028 | 1.074 | 4.6 % | 11.74 V |
| ✅ | `521` | 237.0 | 247.0 | 1.03 | 1.074 | 4.4 % | 3.21 V |
| ✅ | `307` | 237.0 | 246.9 | 1.03 | 1.073 | 4.3 % | 3.22 V |
| ✅ | `263` | 236.6 | 246.8 | 1.029 | 1.073 | 4.5 % | 11.44 V |
| ✅ | `254` | 236.6 | 246.8 | 1.029 | 1.073 | 4.4 % | 11.35 V |
| ✅ | `229` | 236.6 | 246.5 | 1.029 | 1.072 | 4.3 % | 10.97 V |
| ✅ | `256` | 237.0 | 246.5 | 1.03 | 1.072 | 4.1 % | 3.27 V |
| ✅ | `216` | 236.6 | 246.4 | 1.029 | 1.071 | 4.3 % | 10.88 V |
| ✅ | `247` | 237.0 | 246.4 | 1.03 | 1.071 | 4.1 % | 3.31 V |
| ✅ | `192` | 236.7 | 246.2 | 1.029 | 1.07 | 4.1 % | 10.49 V |
| ✅ | `175` | 236.7 | 246.1 | 1.029 | 1.07 | 4.1 % | 10.39 V |
| ✅ | `530` | 238.7 | 246.1 | 1.038 | 1.07 | 3.2 % | 10.25 V |
| ✅ | `226` | 237.0 | 245.8 | 1.03 | 1.069 | 3.8 % | 3.54 V |
| ✅ | `166` | 236.7 | 245.7 | 1.029 | 1.068 | 3.9 % | 9.66 V |
| ✅ | `220` | 237.0 | 245.7 | 1.03 | 1.068 | 3.8 % | 3.6 V |
| ✅ | `151` | 236.8 | 245.3 | 1.029 | 1.067 | 3.7 % | 9.27 V |
| ✅ | `145` | 236.8 | 245.2 | 1.029 | 1.066 | 3.7 % | 9.17 V |
| ✅ | `138` | 236.8 | 245.1 | 1.029 | 1.066 | 3.6 % | 9.03 V |
| ✅ | `144` | 236.8 | 245.1 | 1.029 | 1.066 | 3.6 % | 8.98 V |
| ✅ | `428` | 239.3 | 245.1 | 1.04 | 1.066 | 2.5 % | 9.11 V |
| ✅ | `416` | 239.2 | 245.1 | 1.04 | 1.065 | 2.5 % | 9.08 V |
| ✅ | `391` | 239.1 | 245.1 | 1.04 | 1.065 | 2.6 % | 9.03 V |
| ✅ | `392` | 239.1 | 245.1 | 1.04 | 1.065 | 2.6 % | 9.03 V |
| ✅ | `380` | 239.1 | 245.1 | 1.039 | 1.065 | 2.6 % | 9.02 V |
| ✅ | `366` | 239.0 | 245.0 | 1.039 | 1.065 | 2.6 % | 8.97 V |
| ✅ | `131` | 236.8 | 245.0 | 1.03 | 1.065 | 3.6 % | 8.89 V |
| ✅ | `355` | 238.9 | 245.0 | 1.039 | 1.065 | 2.7 % | 8.95 V |
| ✅ | `441` | 238.7 | 245.0 | 1.038 | 1.065 | 2.7 % | 8.86 V |
| ✅ | `348` | 238.9 | 245.0 | 1.039 | 1.065 | 2.6 % | 9.01 V |
| ✅ | `327` | 238.6 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.79 V |
| ✅ | `384` | 238.5 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.77 V |
| ✅ | `318` | 238.5 | 245.0 | 1.037 | 1.065 | 2.8 % | 8.74 V |
| ✅ | `300` | 238.3 | 245.0 | 1.036 | 1.065 | 2.9 % | 8.68 V |
| ✅ | `219` | 237.0 | 245.0 | 1.03 | 1.065 | 3.5 % | 4.06 V |
| ✅ | `208` | 237.0 | 244.9 | 1.03 | 1.065 | 3.4 % | 4.14 V |
| ✅ | `116` | 236.9 | 244.4 | 1.03 | 1.063 | 3.3 % | 7.88 V |
| ✅ | `128` | 236.9 | 244.3 | 1.03 | 1.062 | 3.2 % | 7.67 V |
| ✅ | `198` | 236.9 | 244.1 | 1.03 | 1.061 | 3.1 % | 7.51 V |
| ✅ | `104` | 236.9 | 244.1 | 1.03 | 1.061 | 3.1 % | 7.57 V |
| ✅ | `108` | 236.9 | 243.9 | 1.03 | 1.061 | 3.0 % | 7.34 V |
| ✅ | `99` | 236.9 | 243.9 | 1.03 | 1.06 | 3.0 % | 7.29 V |
| ✅ | `201` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.12 V |
| ✅ | `188` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 5.22 V |
| ✅ | `179` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.06 V |
| ✅ | `162` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.19 V |
| ✅ | `187` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.53 V |
| ✅ | `147` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 6.66 V |
| ✅ | `90` | 237.0 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.11 V |
| ✅ | `82` | 236.9 | 243.8 | 1.03 | 1.06 | 3.0 % | 7.14 V |
| ✅ | `62` | 235.3 | 239.6 | 1.023 | 1.042 | 1.9 % | 4.98 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.921 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.308 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=5.199 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.859 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.077 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=5.135 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.153 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.772 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=5.132 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.74 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.516 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=3.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.433 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=5.228 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_1`  
  IBR 'pv_1' phase 'a': pg=4.619 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.741 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.792 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.246 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.214 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.787 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=5.25 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.738 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.743 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_20`  
  IBR 'pv_20' phase 'a': pg=4.612 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 181.6 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.19 V at bus '896' — reflects the neutral shift under unbalanced loading.

