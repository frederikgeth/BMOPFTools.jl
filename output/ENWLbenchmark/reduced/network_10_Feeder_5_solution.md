# BMOPF Solution Profile: network_10_Feeder_5

**Generated:** 2026-06-23 13:46:11  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -56.1723  
**Solve time:** 0.03 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.247 kW |
| Total load | 13.188 kW |
| Total network losses (P) | 59.27 W |
| Total network losses (Q) | 19.9 W var |
| Loss fraction | 0.4% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.636 V (bus `276`) |

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
| ✅ | `146` | 240.0 V | 17 | 0.996 (`276`) | 1.0 (`sourcebus`) | 0.3 % (`276`) | 0.64 V (`276`) |

### Per-bus detail

**Zone `146`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `276` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.64 V |
| ✅ | `273` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.63 V |
| ✅ | `298` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.41 V |
| ✅ | `271` | 239.3 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.4 V |
| ✅ | `301` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.38 V |
| ✅ | `300` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.39 V |
| ✅ | `307` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.36 V |
| ✅ | `312` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.35 V |
| ✅ | `293` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.37 V |
| ✅ | `299` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.35 V |
| ✅ | `274` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.36 V |
| ✅ | `275` | 239.5 | 239.8 | 0.997 | 0.999 | 0.1 % | 0.28 V |
| ✅ | `272` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.34 V |
| ✅ | `266` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.37 V |
| ✅ | `261` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.37 V |
| ✅ | `146` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.28 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -26.376 kW | [-26.376 kW, 26.376 kW] |
| W | `grid` | `2` | pg | -26.376 kW | [-26.376 kW, 26.376 kW] |
| W | `grid` | `3` | pg | -26.376 kW | [-26.376 kW, 26.376 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-26.376 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-26.376 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-26.376 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.64 V at bus '276' — reflects the neutral shift under unbalanced loading.

