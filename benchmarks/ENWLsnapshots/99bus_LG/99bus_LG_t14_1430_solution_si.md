# BMOPF Solution Profile: Unnamed Network

**Generated:** 2026-06-29 20:13:18  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -199127.676  
**Solve time:** 0.081 s  
**Findings:** 0 errors · 28 warnings · 3 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 38.969 kW |
| Total load | 14.852 kW |
| Total network losses (P) | 24.117 kW |
| Total network losses (Q) | 6.963 kW var |
| Loss fraction | 162.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 18.509 V (bus `896`) |

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
| ✅ | `104` | 230.0 V | 99 | 1.0 (`sourcebus`) | 1.097 (`896`) | 5.2 % (`313`) | 18.51 V (`896`) |

### Per-bus detail

**Zone `104`** (base 230.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `896` | 241.3 | 252.2 | 1.049 | 1.097 | 4.8 % | 18.51 V |
| ✅ | `949` | 241.7 | 251.7 | 1.051 | 1.095 | 4.4 % | 17.61 V |
| ✅ | `677` | 241.3 | 251.7 | 1.049 | 1.094 | 4.5 % | 17.93 V |
| ✅ | `660` | 241.3 | 251.7 | 1.049 | 1.094 | 4.5 % | 17.86 V |
| ✅ | `661` | 241.3 | 251.6 | 1.049 | 1.094 | 4.5 % | 17.73 V |
| ✅ | `654` | 241.3 | 251.5 | 1.049 | 1.093 | 4.4 % | 17.59 V |
| ✅ | `644` | 241.3 | 251.5 | 1.049 | 1.093 | 4.4 % | 17.57 V |
| ✅ | `895` | 241.7 | 251.5 | 1.051 | 1.093 | 4.3 % | 17.29 V |
| ✅ | `635` | 241.3 | 251.4 | 1.049 | 1.093 | 4.4 % | 17.48 V |
| ✅ | `904` | 241.7 | 251.3 | 1.051 | 1.093 | 4.2 % | 17.16 V |
| ✅ | `775` | 241.5 | 251.2 | 1.05 | 1.092 | 4.2 % | 17.16 V |
| ✅ | `849` | 241.7 | 251.2 | 1.051 | 1.092 | 4.1 % | 17.02 V |
| ✅ | `894` | 242.2 | 251.2 | 1.053 | 1.092 | 3.9 % | 16.05 V |
| ✅ | `808` | 241.5 | 250.8 | 1.05 | 1.091 | 4.0 % | 17.07 V |
| ✅ | `693` | 241.5 | 250.8 | 1.05 | 1.091 | 4.0 % | 16.77 V |
| ✅ | `673` | 241.5 | 250.8 | 1.05 | 1.091 | 4.0 % | 16.76 V |
| ✅ | `627` | 241.3 | 250.8 | 1.049 | 1.09 | 4.1 % | 16.74 V |
| ✅ | `665` | 241.5 | 250.8 | 1.05 | 1.09 | 4.0 % | 16.7 V |
| ✅ | `617` | 241.3 | 250.8 | 1.049 | 1.09 | 4.1 % | 16.69 V |
| ✅ | `618` | 241.3 | 250.7 | 1.049 | 1.09 | 4.1 % | 16.69 V |
| ✅ | `779` | 241.5 | 250.7 | 1.05 | 1.09 | 4.0 % | 16.95 V |
| ✅ | `608` | 241.3 | 250.7 | 1.049 | 1.09 | 4.1 % | 16.66 V |
| ✅ | `659` | 241.5 | 250.7 | 1.05 | 1.09 | 4.0 % | 16.64 V |
| ✅ | `607` | 241.3 | 250.7 | 1.049 | 1.09 | 4.1 % | 16.6 V |
| ✅ | `600` | 241.3 | 250.6 | 1.049 | 1.09 | 4.0 % | 16.5 V |
| ✅ | `717` | 241.5 | 250.6 | 1.05 | 1.089 | 3.9 % | 17.14 V |
| ✅ | `655` | 241.5 | 250.6 | 1.05 | 1.089 | 3.9 % | 16.91 V |
| ✅ | `609` | 241.5 | 250.6 | 1.05 | 1.089 | 3.9 % | 16.86 V |
| ✅ | `773` | 241.5 | 250.6 | 1.05 | 1.089 | 3.9 % | 16.73 V |
| ✅ | `568` | 241.5 | 250.5 | 1.05 | 1.089 | 3.9 % | 16.45 V |
| ✅ | `545` | 241.3 | 250.1 | 1.049 | 1.087 | 3.8 % | 15.88 V |
| ✅ | `313` | 237.7 | 249.7 | 1.033 | 1.086 | 5.2 % | 15.54 V |
| ✅ | `303` | 237.7 | 249.7 | 1.034 | 1.086 | 5.2 % | 15.45 V |
| ✅ | `290` | 237.7 | 249.6 | 1.034 | 1.085 | 5.2 % | 15.37 V |
| ✅ | `282` | 237.7 | 249.6 | 1.034 | 1.085 | 5.2 % | 15.34 V |
| ✅ | `272` | 237.7 | 249.5 | 1.034 | 1.085 | 5.1 % | 15.24 V |
| ✅ | `321` | 237.8 | 249.2 | 1.034 | 1.084 | 5.0 % | 14.92 V |
| ✅ | `264` | 237.8 | 249.2 | 1.034 | 1.083 | 5.0 % | 14.81 V |
| ✅ | `263` | 237.8 | 248.9 | 1.034 | 1.082 | 4.8 % | 14.5 V |
| ✅ | `254` | 237.8 | 248.8 | 1.034 | 1.082 | 4.8 % | 14.42 V |
| ✅ | `229` | 237.8 | 248.5 | 1.034 | 1.081 | 4.7 % | 14.03 V |
| ✅ | `216` | 237.8 | 248.4 | 1.034 | 1.08 | 4.6 % | 13.94 V |
| ✅ | `192` | 237.9 | 248.1 | 1.034 | 1.079 | 4.5 % | 13.55 V |
| ✅ | `175` | 237.9 | 248.1 | 1.034 | 1.079 | 4.4 % | 13.46 V |
| ✅ | `530` | 240.3 | 248.0 | 1.045 | 1.078 | 3.3 % | 13.13 V |
| ✅ | `166` | 238.0 | 247.6 | 1.035 | 1.076 | 4.2 % | 12.75 V |
| ✅ | `498` | 238.2 | 247.3 | 1.036 | 1.075 | 4.0 % | 8.35 V |
| ✅ | `491` | 238.2 | 247.3 | 1.036 | 1.075 | 3.9 % | 8.33 V |
| ✅ | `473` | 238.2 | 247.2 | 1.036 | 1.075 | 3.9 % | 8.31 V |
| ✅ | `151` | 238.0 | 247.1 | 1.035 | 1.075 | 4.0 % | 12.33 V |
| ✅ | `472` | 238.2 | 247.1 | 1.036 | 1.074 | 3.9 % | 8.29 V |
| ✅ | `145` | 238.0 | 247.1 | 1.035 | 1.074 | 3.9 % | 12.23 V |
| ✅ | `439` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 8.26 V |
| ✅ | `536` | 238.2 | 247.0 | 1.036 | 1.074 | 3.8 % | 8.25 V |
| ✅ | `138` | 238.0 | 246.9 | 1.035 | 1.074 | 3.9 % | 12.09 V |
| ✅ | `144` | 238.0 | 246.9 | 1.035 | 1.073 | 3.9 % | 12.03 V |
| ✅ | `427` | 238.2 | 246.8 | 1.036 | 1.073 | 3.8 % | 8.23 V |
| ✅ | `428` | 240.8 | 246.8 | 1.047 | 1.073 | 2.6 % | 11.72 V |
| ✅ | `416` | 240.8 | 246.8 | 1.047 | 1.073 | 2.6 % | 11.7 V |
| ✅ | `131` | 238.0 | 246.8 | 1.035 | 1.073 | 3.8 % | 11.95 V |
| ✅ | `391` | 240.6 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.68 V |
| ✅ | `380` | 240.6 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.68 V |
| ✅ | `392` | 240.6 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.68 V |
| ✅ | `366` | 240.5 | 246.8 | 1.046 | 1.073 | 2.7 % | 11.65 V |
| ✅ | `355` | 240.5 | 246.8 | 1.045 | 1.073 | 2.8 % | 11.63 V |
| ✅ | `441` | 240.2 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.59 V |
| ✅ | `327` | 240.1 | 246.8 | 1.044 | 1.073 | 2.9 % | 11.56 V |
| ✅ | `348` | 240.4 | 246.8 | 1.045 | 1.073 | 2.8 % | 11.68 V |
| ✅ | `384` | 240.0 | 246.8 | 1.043 | 1.073 | 3.0 % | 11.54 V |
| ✅ | `318` | 239.9 | 246.8 | 1.043 | 1.073 | 3.0 % | 11.53 V |
| ✅ | `300` | 239.8 | 246.8 | 1.043 | 1.073 | 3.0 % | 11.51 V |
| ✅ | `479` | 238.2 | 246.7 | 1.036 | 1.072 | 3.7 % | 8.19 V |
| ✅ | `377` | 238.2 | 246.6 | 1.036 | 1.072 | 3.6 % | 8.18 V |
| ✅ | `376` | 238.2 | 246.5 | 1.036 | 1.072 | 3.6 % | 8.17 V |
| ✅ | `354` | 238.2 | 246.4 | 1.036 | 1.071 | 3.6 % | 8.16 V |
| ✅ | `116` | 238.1 | 246.1 | 1.035 | 1.07 | 3.5 % | 10.99 V |
| ✅ | `521` | 238.2 | 246.1 | 1.036 | 1.07 | 3.4 % | 8.13 V |
| ✅ | `307` | 238.2 | 246.0 | 1.036 | 1.069 | 3.4 % | 8.13 V |
| ✅ | `128` | 238.1 | 245.9 | 1.035 | 1.069 | 3.4 % | 10.75 V |
| ✅ | `104` | 238.1 | 245.7 | 1.035 | 1.068 | 3.3 % | 10.62 V |
| ✅ | `198` | 238.1 | 245.7 | 1.035 | 1.068 | 3.3 % | 10.58 V |
| ✅ | `108` | 238.1 | 245.6 | 1.035 | 1.068 | 3.2 % | 10.39 V |
| ✅ | `256` | 238.2 | 245.5 | 1.036 | 1.068 | 3.2 % | 8.13 V |
| ✅ | `99` | 238.1 | 245.5 | 1.035 | 1.067 | 3.2 % | 10.33 V |
| ✅ | `247` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.15 V |
| ✅ | `226` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.22 V |
| ✅ | `220` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.25 V |
| ✅ | `219` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.43 V |
| ✅ | `208` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.47 V |
| ✅ | `201` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 8.95 V |
| ✅ | `188` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.03 V |
| ✅ | `179` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.53 V |
| ✅ | `162` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.61 V |
| ✅ | `187` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.84 V |
| ✅ | `147` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 9.92 V |
| ✅ | `90` | 238.2 | 245.4 | 1.036 | 1.067 | 3.1 % | 10.18 V |
| ✅ | `82` | 238.2 | 245.4 | 1.035 | 1.067 | 3.1 % | 10.18 V |
| ✅ | `62` | 236.0 | 240.7 | 1.026 | 1.046 | 2.0 % | 6.94 V |
| ✅ | `sourcebus` | 230.0 | 230.0 | 1.0 | 1.0 | 0.0 % | — |

## 6. All Findings

- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_31`  
  IBR 'pv_31' phase 'a': pg=4.967 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_37`  
  IBR 'pv_37' phase 'a': pg=4.859 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_22`  
  IBR 'pv_22' phase 'c': pg=4.743 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_4`  
  IBR 'pv_4' phase 'a': pg=4.831 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_46`  
  IBR 'pv_46' phase 'b': pg=4.926 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_48`  
  IBR 'pv_48' phase 'a': pg=4.694 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_39`  
  IBR 'pv_39' phase 'c': pg=5.019 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_25`  
  IBR 'pv_25' phase 'b': pg=4.74 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_18`  
  IBR 'pv_18' phase 'b': pg=5.176 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_34`  
  IBR 'pv_34' phase 'b': pg=4.741 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_38`  
  IBR 'pv_38' phase 'b': pg=4.895 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_5`  
  IBR 'pv_5' phase 'c': pg=4.806 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_13`  
  IBR 'pv_13' phase 'c': pg=4.769 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_42`  
  IBR 'pv_42' phase 'c': pg=5.217 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_27`  
  IBR 'pv_27' phase 'b': pg=4.811 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_35`  
  IBR 'pv_35' phase 'c': pg=4.921 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_41`  
  IBR 'pv_41' phase 'a': pg=4.827 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_21`  
  IBR 'pv_21' phase 'c': pg=4.792 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_36`  
  IBR 'pv_36' phase 'a': pg=4.772 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_23`  
  IBR 'pv_23' phase 'b': pg=5.227 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_16`  
  IBR 'pv_16' phase 'b': pg=5.077 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_9`  
  IBR 'pv_9' phase 'c': pg=5.248 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_45`  
  IBR 'pv_45' phase 'a': pg=4.738 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_10`  
  IBR 'pv_10' phase 'c': pg=4.955 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_8`  
  IBR 'pv_8' phase 'b': pg=4.787 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_40`  
  IBR 'pv_40' phase 'c': pg=5.181 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_47`  
  IBR 'pv_47' phase 'c': pg=5.248 kW is within 1 % of its P bound.
- **WARN** `W.SOL.IBR_ACTIVE` — ibr/`pv_17`  
  IBR 'pv_17' phase 'c': pg=5.218 kW is within 1 % of its P bound.
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 0 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 0A.
- INFO `I.SOL.LOSS_FRACTION`  
  Line losses are 162.4 % of total load — unusually high; verify impedance scaling and operating point.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 18.51 V at bus '896' — reflects the neutral shift under unbalanced loading.

