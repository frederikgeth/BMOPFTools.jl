# BMOPF Solution Profile: network_5_Feeder_6

**Generated:** 2026-06-23 13:46:59  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -86.7931  
**Solve time:** 0.026 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.141 kW |
| Total load | 17.034 kW |
| Total network losses (P) | 106.89 W |
| Total network losses (Q) | 23.57 W var |
| Loss fraction | 0.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.702 V (bus `194`) |

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
| ✅ | `103` | 240.0 V | 36 | 0.994 (`189`) | 1.0 (`sourcebus`) | 0.6 % (`189`) | 0.7 V (`194`) |

### Per-bus detail

**Zone `103`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `189` | 238.7 | 240.1 | 0.994 | 1.0 | 0.6 % | 0.61 V |
| ✅ | `194` | 238.8 | 240.1 | 0.994 | 1.0 | 0.6 % | 0.7 V |
| ✅ | `114` | 238.8 | 240.1 | 0.994 | 1.0 | 0.5 % | 0.67 V |
| ✅ | `108` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.62 V |
| ✅ | `233` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `220` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `235` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `227` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `343` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.48 V |
| ✅ | `234` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `247` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `188` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.53 V |
| ✅ | `263` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.54 V |
| ✅ | `287` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `213` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.54 V |
| ✅ | `347` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.54 V |
| ✅ | `307` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `318` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `171` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.53 V |
| ✅ | `333` | 238.9 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.54 V |
| ✅ | `164` | 239.0 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.52 V |
| ✅ | `321` | 239.0 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.56 V |
| ✅ | `141` | 239.0 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.51 V |
| ✅ | `156` | 239.0 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.58 V |
| ✅ | `292` | 239.0 | 240.1 | 0.995 | 1.0 | 0.4 % | 0.48 V |
| ✅ | `134` | 239.0 | 240.1 | 0.995 | 1.0 | 0.5 % | 0.49 V |
| ✅ | `128` | 239.1 | 240.1 | 0.995 | 1.0 | 0.4 % | 0.46 V |
| ✅ | `116` | 239.1 | 240.1 | 0.995 | 1.0 | 0.4 % | 0.48 V |
| ✅ | `103` | 239.1 | 240.1 | 0.996 | 1.0 | 0.4 % | 0.47 V |
| ✅ | `93` | 239.2 | 240.1 | 0.996 | 1.0 | 0.4 % | 0.44 V |
| ✅ | `216` | 239.2 | 240.1 | 0.996 | 1.0 | 0.4 % | 0.46 V |
| ✅ | `87` | 239.3 | 240.1 | 0.997 | 1.0 | 0.3 % | 0.35 V |
| ✅ | `80` | 239.3 | 240.1 | 0.997 | 1.0 | 0.3 % | 0.38 V |
| ✅ | `58` | 239.7 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.25 V |
| ✅ | `59` | 239.7 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.29 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -34.068 kW | [-34.068 kW, 34.068 kW] |
| W | `grid` | `2` | pg | -34.068 kW | [-34.068 kW, 34.068 kW] |
| W | `grid` | `3` | pg | -34.068 kW | [-34.068 kW, 34.068 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-34.068 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-34.068 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-34.068 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.7 V at bus '194' — reflects the neutral shift under unbalanced loading.

