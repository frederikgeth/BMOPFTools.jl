# BMOPF Solution Profile: network_18_Feeder_6

**Generated:** 2026-06-23 13:46:35  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -121.5501  
**Solve time:** 0.043 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.052 kW |
| Total load | 20.868 kW |
| Total network losses (P) | 184.1 W |
| Total network losses (Q) | 62.97 W var |
| Loss fraction | 0.9% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.226 V (bus `503`) |

### Bound status

| Category | Violated | Active (≤1 %) |
|----------|:--------:|:-------------:|
| Voltage  | 0 | 0 |
| Thermal  | 0 | 0 |
| Generator| 0 | 3 |

## 2. Voltage by Galvanic Zone

Per-unit magnitudes are relative to each zone's own voltage base; volts are not comparable across transformer boundaries.

| St | Zone | V base | Buses | Vm min (pu) | Vm max (pu) | Max imbalance | Max neutral shift |
|:--:|------|-------:|------:|------------:|------------:|--------------:|------------------:|
| ✅ | `109` | 240.0 V | 45 | 0.992 (`382`) | 1.0 (`sourcebus`) | 0.6 % (`382`) | 1.23 V (`503`) |

### Per-bus detail

**Zone `109`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `382` | 238.3 | 239.6 | 0.992 | 0.998 | 0.6 % | 1.19 V |
| ✅ | `274` | 238.3 | 239.6 | 0.992 | 0.998 | 0.5 % | 1.13 V |
| ✅ | `503` | 238.4 | 239.7 | 0.992 | 0.998 | 0.5 % | 1.23 V |
| ✅ | `392` | 238.4 | 239.6 | 0.992 | 0.998 | 0.5 % | 1.06 V |
| ✅ | `272` | 238.4 | 239.6 | 0.992 | 0.998 | 0.5 % | 1.14 V |
| ✅ | `261` | 238.4 | 239.6 | 0.992 | 0.998 | 0.5 % | 1.1 V |
| ✅ | `260` | 238.4 | 239.6 | 0.992 | 0.998 | 0.5 % | 1.11 V |
| ✅ | `251` | 238.4 | 239.6 | 0.993 | 0.998 | 0.5 % | 1.09 V |
| ✅ | `442` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.17 V |
| ✅ | `434` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.17 V |
| ✅ | `509` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.16 V |
| ✅ | `433` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.15 V |
| ✅ | `425` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.15 V |
| ✅ | `417` | 238.5 | 239.7 | 0.993 | 0.998 | 0.5 % | 1.15 V |
| ✅ | `531` | 238.6 | 239.7 | 0.993 | 0.998 | 0.4 % | 1.03 V |
| ✅ | `477` | 238.6 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.01 V |
| ✅ | `469` | 238.6 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.01 V |
| ✅ | `256` | 238.7 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.02 V |
| ✅ | `201` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.96 V |
| ✅ | `461` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.16 V |
| ✅ | `528` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.15 V |
| ✅ | `453` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 1.14 V |
| ✅ | `190` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.96 V |
| ✅ | `160` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.89 V |
| ✅ | `215` | 238.9 | 239.8 | 0.995 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `122` | 239.0 | 239.8 | 0.995 | 0.999 | 0.4 % | 0.93 V |
| ✅ | `116` | 239.0 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.89 V |
| ✅ | `481` | 239.1 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.78 V |
| ✅ | `422` | 239.1 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.77 V |
| ✅ | `414` | 239.1 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.77 V |
| ✅ | `136` | 239.1 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.71 V |
| ✅ | `237` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.81 V |
| ✅ | `117` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.81 V |
| ✅ | `112` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.82 V |
| ✅ | `124` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.8 V |
| ✅ | `130` | 239.1 | 239.8 | 0.996 | 0.998 | 0.3 % | 0.71 V |
| ✅ | `390` | 239.1 | 239.6 | 0.996 | 0.998 | 0.2 % | 0.6 V |
| ✅ | `399` | 239.1 | 239.6 | 0.996 | 0.998 | 0.2 % | 0.6 V |
| ✅ | `473` | 239.1 | 239.6 | 0.996 | 0.998 | 0.2 % | 0.57 V |
| ✅ | `109` | 239.3 | 239.8 | 0.996 | 0.999 | 0.2 % | 0.58 V |
| ✅ | `81` | 239.6 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.36 V |
| ✅ | `379` | 239.6 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.29 V |
| ✅ | `389` | 239.6 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.29 V |
| ✅ | `491` | 239.6 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.28 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |
| W | `grid` | `2` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |
| W | `grid` | `3` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-41.736 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-41.736 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-41.736 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.23 V at bus '503' — reflects the neutral shift under unbalanced loading.

