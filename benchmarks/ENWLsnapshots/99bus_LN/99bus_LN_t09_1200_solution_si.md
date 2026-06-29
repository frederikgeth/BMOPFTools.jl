# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:24  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -181857.6122  
**Solve time:** 0.082 s  
**Findings:** 0 errors · 43 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 33.124 kW |
| Total load | 11.521 kW |
| Total network losses (P) | 21.603 kW |
| Total network losses (Q) | 6.37 kW var |
| Loss fraction | 187.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 15.566 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.085 (`896`) | 5.0 % (`313`) | 15.57 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 238.5 | 249.4 | 1.037 | 1.085 | 4.8 % | 15.57 V |
| ✅ | `949` | 239.3 | 249.1 | 1.04 | 1.083 | 4.3 % | 14.61 V |
| ✅ | `677` | 238.5 | 249.0 | 1.037 | 1.083 | 4.5 % | 15.07 V |
| ✅ | `660` | 238.5 | 249.0 | 1.037 | 1.082 | 4.5 % | 14.99 V |
| ✅ | `661` | 238.5 | 248.9 | 1.037 | 1.082 | 4.5 % | 14.84 V |
| ✅ | `895` | 239.3 | 248.8 | 1.04 | 1.082 | 4.2 % | 14.35 V |
| ✅ | `654` | 238.5 | 248.8 | 1.037 | 1.082 | 4.5 % | 14.72 V |
| ✅ | `644` | 238.5 | 248.8 | 1.037 | 1.082 | 4.5 % | 14.7 V |
| ✅ | `635` | 238.5 | 248.7 | 1.037 | 1.081 | 4.4 % | 14.61 V |
| ✅ | `904` | 239.3 | 248.7 | 1.04 | 1.081 | 4.1 % | 14.25 V |
| ✅ | `775` | 239.3 | 248.6 | 1.041 | 1.081 | 4.0 % | 14.25 V |
| ✅ | `849` | 239.3 | 248.6 | 1.04 | 1.081 | 4.0 % | 14.13 V |
| ✅ | `894` | 239.3 | 248.6 | 1.04 | 1.081 | 4.0 % | 13.27 V |
| ✅ | `808` | 240.1 | 248.2 | 1.044 | 1.079 | 3.5 % | 14.25 V |
| ✅ | `693` | 239.4 | 248.2 | 1.041 | 1.079 | 3.8 % | 13.94 V |
| ✅ | `673` | 239.3 | 248.2 | 1.041 | 1.079 | 3.8 % | 13.92 V |
| ✅ | `627` | 238.6 | 248.2 | 1.037 | 1.079 | 4.2 % | 13.93 V |
| ✅ | `665` | 239.3 | 248.2 | 1.041 | 1.079 | 3.8 % | 13.88 V |
| ✅ | `617` | 238.6 | 248.1 | 1.037 | 1.079 | 4.2 % | 13.88 V |
| ✅ | `618` | 238.6 | 248.1 | 1.037 | 1.079 | 4.2 % | 13.88 V |
| ✅ | `779` | 239.9 | 248.1 | 1.043 | 1.079 | 3.6 % | 14.1 V |
| ✅ | `659` | 239.3 | 248.1 | 1.04 | 1.079 | 3.8 % | 13.82 V |
| ✅ | `608` | 238.6 | 248.1 | 1.037 | 1.079 | 4.1 % | 13.85 V |
| ✅ | `607` | 238.6 | 248.1 | 1.037 | 1.079 | 4.1 % | 13.8 V |
| ✅ | `600` | 238.6 | 248.0 | 1.037 | 1.078 | 4.1 % | 13.71 V |
| ✅ | `717` | 240.7 | 248.0 | 1.047 | 1.078 | 3.2 % | 14.4 V |
| ✅ | `655` | 240.2 | 248.0 | 1.044 | 1.078 | 3.4 % | 14.14 V |
| ✅ | `609` | 240.1 | 247.9 | 1.044 | 1.078 | 3.4 % | 14.09 V |
| ✅ | `773` | 239.9 | 247.9 | 1.043 | 1.078 | 3.5 % | 14.01 V |
| ✅ | `568` | 239.2 | 247.9 | 1.04 | 1.078 | 3.8 % | 13.67 V |
| ✅ | `545` | 238.6 | 247.5 | 1.037 | 1.076 | 3.9 % | 13.17 V |
| ✅ | `313` | 235.7 | 247.2 | 1.025 | 1.075 | 5.0 % | 12.88 V |
| ✅ | `303` | 235.7 | 247.1 | 1.025 | 1.074 | 5.0 % | 12.8 V |
| ✅ | `290` | 235.7 | 247.1 | 1.025 | 1.074 | 4.9 % | 12.72 V |
| ✅ | `282` | 235.7 | 247.0 | 1.025 | 1.074 | 4.9 % | 12.68 V |
| ✅ | `498` | 236.2 | 247.0 | 1.027 | 1.074 | 4.7 % | 2.89 V |
| ✅ | `272` | 235.7 | 247.0 | 1.025 | 1.074 | 4.9 % | 12.59 V |
| ✅ | `491` | 236.2 | 246.9 | 1.027 | 1.074 | 4.7 % | 2.88 V |
| ✅ | `473` | 236.2 | 246.8 | 1.027 | 1.073 | 4.6 % | 2.88 V |
| ✅ | `472` | 236.2 | 246.8 | 1.027 | 1.073 | 4.6 % | 2.88 V |
| ✅ | `321` | 235.7 | 246.8 | 1.025 | 1.073 | 4.8 % | 12.27 V |
| ✅ | `264` | 235.8 | 246.7 | 1.025 | 1.073 | 4.8 % | 12.16 V |
| ✅ | `439` | 236.2 | 246.7 | 1.027 | 1.073 | 4.6 % | 2.89 V |
| ✅ | `536` | 236.2 | 246.6 | 1.027 | 1.072 | 4.5 % | 2.89 V |
| ✅ | `427` | 236.2 | 246.5 | 1.027 | 1.072 | 4.5 % | 2.91 V |
| ✅ | `263` | 235.8 | 246.5 | 1.025 | 1.072 | 4.7 % | 11.86 V |
| ✅ | `254` | 235.8 | 246.4 | 1.025 | 1.071 | 4.6 % | 11.77 V |
| ✅ | `479` | 236.2 | 246.3 | 1.027 | 1.071 | 4.4 % | 2.94 V |
| ✅ | `377` | 236.2 | 246.3 | 1.027 | 1.071 | 4.4 % | 2.97 V |
| ✅ | `376` | 236.2 | 246.2 | 1.027 | 1.07 | 4.4 % | 2.98 V |
| ✅ | `229` | 235.8 | 246.2 | 1.025 | 1.07 | 4.5 % | 11.38 V |
| ✅ | `354` | 236.2 | 246.1 | 1.027 | 1.07 | 4.3 % | 3.01 V |
| ✅ | `216` | 235.8 | 246.1 | 1.025 | 1.07 | 4.5 % | 11.29 V |
| ✅ | `192` | 235.9 | 245.8 | 1.026 | 1.069 | 4.3 % | 10.9 V |
| ✅ | `521` | 236.2 | 245.8 | 1.027 | 1.069 | 4.2 % | 3.13 V |
| ✅ | `175` | 235.9 | 245.7 | 1.026 | 1.068 | 4.3 % | 10.8 V |
| ✅ | `307` | 236.2 | 245.7 | 1.027 | 1.068 | 4.1 % | 3.2 V |
| ✅ | `530` | 237.7 | 245.6 | 1.034 | 1.068 | 3.4 % | 10.67 V |
| ✅ | `256` | 236.2 | 245.3 | 1.027 | 1.066 | 3.9 % | 3.42 V |
| ✅ | `166` | 236.0 | 245.3 | 1.026 | 1.066 | 4.0 % | 10.03 V |
| ✅ | `247` | 236.2 | 245.2 | 1.027 | 1.066 | 3.9 % | 3.48 V |
| ✅ | `151` | 236.0 | 244.9 | 1.026 | 1.065 | 3.9 % | 9.67 V |
| ✅ | `145` | 236.0 | 244.9 | 1.026 | 1.065 | 3.9 % | 9.58 V |
| ✅ | `138` | 236.0 | 244.8 | 1.026 | 1.064 | 3.8 % | 9.44 V |
| ✅ | `144` | 236.0 | 244.7 | 1.026 | 1.064 | 3.8 % | 9.38 V |
| ✅ | `131` | 236.0 | 244.7 | 1.026 | 1.064 | 3.8 % | 9.31 V |
| ✅ | `226` | 236.2 | 244.7 | 1.027 | 1.064 | 3.7 % | 3.88 V |
| ✅ | `428` | 238.2 | 244.6 | 1.036 | 1.064 | 2.8 % | 9.48 V |
| ✅ | `416` | 238.1 | 244.6 | 1.035 | 1.064 | 2.8 % | 9.44 V |
| ✅ | `391` | 238.1 | 244.6 | 1.035 | 1.064 | 2.8 % | 9.41 V |
| ✅ | `380` | 238.1 | 244.6 | 1.035 | 1.064 | 2.8 % | 9.41 V |
| ✅ | `392` | 238.0 | 244.6 | 1.035 | 1.064 | 2.9 % | 9.4 V |
| ✅ | `366` | 238.0 | 244.6 | 1.035 | 1.063 | 2.9 % | 9.36 V |
| ✅ | `355` | 237.9 | 244.6 | 1.034 | 1.063 | 2.9 % | 9.34 V |
| ✅ | `441` | 237.7 | 244.6 | 1.034 | 1.063 | 3.0 % | 9.26 V |
| ✅ | `348` | 237.9 | 244.6 | 1.034 | 1.063 | 2.9 % | 9.37 V |
| ✅ | `327` | 237.6 | 244.6 | 1.033 | 1.063 | 3.0 % | 9.21 V |
| ✅ | `384` | 237.6 | 244.6 | 1.033 | 1.063 | 3.0 % | 9.2 V |
| ✅ | `318` | 237.5 | 244.6 | 1.033 | 1.063 | 3.1 % | 9.16 V |
| ✅ | `220` | 236.2 | 244.6 | 1.027 | 1.063 | 3.6 % | 3.96 V |
| ✅ | `300` | 237.4 | 244.6 | 1.032 | 1.063 | 3.1 % | 9.12 V |
| ✅ | `116` | 236.1 | 244.0 | 1.027 | 1.061 | 3.4 % | 8.31 V |
| ✅ | `128` | 236.1 | 243.9 | 1.027 | 1.06 | 3.4 % | 8.09 V |
| ✅ | `219` | 236.2 | 243.9 | 1.027 | 1.06 | 3.3 % | 4.52 V |
| ✅ | `208` | 236.2 | 243.8 | 1.027 | 1.06 | 3.3 % | 4.61 V |
| ✅ | `104` | 236.1 | 243.7 | 1.027 | 1.06 | 3.3 % | 8.01 V |
| ✅ | `198` | 236.1 | 243.7 | 1.027 | 1.059 | 3.3 % | 7.93 V |
| ✅ | `108` | 236.1 | 243.5 | 1.027 | 1.059 | 3.2 % | 7.78 V |
| ✅ | `99` | 236.1 | 243.5 | 1.027 | 1.059 | 3.2 % | 7.73 V |
| ✅ | `201` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 5.64 V |
| ✅ | `188` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 5.74 V |
| ✅ | `179` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 6.56 V |
| ✅ | `162` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 6.68 V |
| ✅ | `187` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 7.02 V |
| ✅ | `147` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 7.13 V |
| ✅ | `90` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 7.57 V |
| ✅ | `82` | 236.2 | 243.4 | 1.027 | 1.058 | 3.1 % | 7.59 V |
| ✅ | `62` | 234.7 | 239.3 | 1.021 | 1.041 | 2.0 % | 5.3 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_43`  
  IBR 'pv_43' phase 'a': pg=4.276 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_3`  
  IBR 'pv_3' phase 'a': pg=4.163 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_11`  
  IBR 'pv_11' phase 'a': pg=4.658 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.486 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.791 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.425 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_14`  
  IBR 'pv_14' phase 'a': pg=4.427 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.701 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=4.141 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.715 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_2`  
  IBR 'pv_2' phase 'a': pg=4.283 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=4.166 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_30`  
  IBR 'pv_30' phase 'b': pg=4.14 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_6`  
  IBR 'pv_6' phase 'b': pg=4.625 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.312 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_44`  
  IBR 'pv_44' phase 'a': pg=4.268 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.834 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.815 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=4.245 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_26`  
  IBR 'pv_26' phase 'b': pg=4.186 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.143 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_33`  
  IBR 'pv_33' phase 'a': pg=4.629 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.707 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.169 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_32`  
  IBR 'pv_32' phase 'a': pg=4.038 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_12`  
  IBR 'pv_12' phase 'b': pg=4.976 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_7`  
  IBR 'pv_7' phase 'a': pg=4.581 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.435 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_28`  
  IBR 'pv_28' phase 'b': pg=4.891 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.339 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=4.521 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=4.866 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=4.22 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.331 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.198 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.887 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=4.298 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_15`  
  IBR 'pv_15' phase 'a': pg=4.328 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=4.557 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_24`  
  IBR 'pv_24' phase 'a': pg=4.713 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=4.505 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 187.5 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 15.57 V at bus '896' — reflects the neutral shift under unbalanced loading.

