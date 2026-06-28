# BMOPF Solution Profile: network_18_Feeder_8

**Generated:** 2026-06-23 13:46:35  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -110.3003  
**Solve time:** 0.037 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 20.026 kW |
| Total load | 19.902 kW |
| Total network losses (P) | 123.76 W |
| Total network losses (Q) | 29.54 W var |
| Loss fraction | 0.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.089 V (bus `229`) |

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
| ✅ | `110` | 240.0 V | 44 | 0.993 (`229`) | 1.0 (`sourcebus`) | 0.5 % (`229`) | 1.09 V (`229`) |

### Per-bus detail

**Zone `110`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `229` | 238.6 | 239.8 | 0.993 | 0.998 | 0.5 % | 1.09 V |
| ✅ | `209` | 238.6 | 239.8 | 0.993 | 0.998 | 0.5 % | 1.05 V |
| ✅ | `202` | 238.7 | 239.8 | 0.994 | 0.998 | 0.5 % | 0.98 V |
| ✅ | `320` | 239.0 | 239.6 | 0.995 | 0.998 | 0.3 % | 0.43 V |
| ✅ | `345` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.37 V |
| ✅ | `339` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.36 V |
| ✅ | `331` | 239.1 | 239.7 | 0.995 | 0.998 | 0.2 % | 0.44 V |
| ✅ | `347` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.34 V |
| ✅ | `330` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.36 V |
| ✅ | `317` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.36 V |
| ✅ | `333` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.35 V |
| ✅ | `340` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.38 V |
| ✅ | `302` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.38 V |
| ✅ | `291` | 239.1 | 239.6 | 0.995 | 0.998 | 0.2 % | 0.39 V |
| ✅ | `326` | 239.1 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `319` | 239.1 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `272` | 239.1 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.4 V |
| ✅ | `312` | 239.1 | 239.7 | 0.996 | 0.998 | 0.3 % | 0.47 V |
| ✅ | `305` | 239.1 | 239.7 | 0.996 | 0.998 | 0.3 % | 0.45 V |
| ✅ | `298` | 239.1 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.45 V |
| ✅ | `247` | 239.2 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.4 V |
| ✅ | `318` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.14 V |
| ✅ | `241` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.21 V |
| ✅ | `235` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.21 V |
| ✅ | `231` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.4 V |
| ✅ | `117` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.44 V |
| ✅ | `137` | 239.3 | 240.0 | 0.996 | 0.999 | 0.3 % | 0.63 V |
| ✅ | `110` | 239.3 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.41 V |
| ✅ | `243` | 239.3 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `249` | 239.3 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `255` | 239.3 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `129` | 239.4 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.55 V |
| ✅ | `120` | 239.4 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.54 V |
| ✅ | `79` | 239.4 | 240.1 | 0.997 | 1.0 | 0.3 % | 0.66 V |
| ✅ | `283` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.12 V |
| ✅ | `201` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.14 V |
| ✅ | `193` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.16 V |
| ✅ | `77` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.3 V |
| ✅ | `52` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `49` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `43` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `158` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.21 V |
| ✅ | `41` | 239.9 | 240.1 | 0.999 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |
| W | `grid` | `2` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |
| W | `grid` | `3` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-39.804 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-39.804 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-39.804 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.09 V at bus '229' — reflects the neutral shift under unbalanced loading.

