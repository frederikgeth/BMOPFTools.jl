# BMOPF Solution Profile: network_22_Feeder_2

**Generated:** 2026-06-23 13:46:40  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -68.9141  
**Solve time:** 0.026 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.854 kW |
| Total load | 13.764 kW |
| Total network losses (P) | 89.97 W |
| Total network losses (Q) | 21.32 W var |
| Loss fraction | 0.7% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.079 V (bus `174`) |

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
| ✅ | `112` | 240.0 V | 28 | 0.994 (`174`) | 1.0 (`sourcebus`) | 0.5 % (`174`) | 1.08 V (`174`) |

### Per-bus detail

**Zone `112`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `174` | 238.7 | 239.8 | 0.994 | 0.999 | 0.5 % | 1.08 V |
| ✅ | `186` | 238.7 | 239.8 | 0.994 | 0.999 | 0.5 % | 1.08 V |
| ✅ | `168` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 0.98 V |
| ✅ | `250` | 239.0 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.72 V |
| ✅ | `251` | 239.0 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.73 V |
| ✅ | `248` | 239.1 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.71 V |
| ✅ | `210` | 239.1 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.67 V |
| ✅ | `239` | 239.1 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.63 V |
| ✅ | `194` | 239.1 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.67 V |
| ✅ | `142` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.66 V |
| ✅ | `190` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.63 V |
| ✅ | `216` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.61 V |
| ✅ | `217` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.63 V |
| ✅ | `112` | 239.1 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.67 V |
| ✅ | `183` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.66 V |
| ✅ | `178` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.63 V |
| ✅ | `144` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.42 V |
| ✅ | `150` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.43 V |
| ✅ | `138` | 239.2 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.44 V |
| ✅ | `91` | 239.2 | 239.8 | 0.996 | 0.999 | 0.3 % | 0.57 V |
| ✅ | `171` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.62 V |
| ✅ | `71` | 239.3 | 239.9 | 0.996 | 0.999 | 0.2 % | 0.52 V |
| ✅ | `64` | 239.3 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.5 V |
| ✅ | `185` | 239.4 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.62 V |
| ✅ | `189` | 239.5 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.58 V |
| ✅ | `179` | 239.5 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.57 V |
| ✅ | `54` | 239.6 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.37 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -27.528 kW | [-27.528 kW, 27.528 kW] |
| W | `grid` | `2` | pg | -27.528 kW | [-27.528 kW, 27.528 kW] |
| W | `grid` | `3` | pg | -27.528 kW | [-27.528 kW, 27.528 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-27.528 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-27.528 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-27.528 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.08 V at bus '174' — reflects the neutral shift under unbalanced loading.

