# BMOPF Solution Profile: network_25_Feeder_1

**Generated:** 2026-06-23 13:46:42  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -55.9709  
**Solve time:** 0.033 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.22 kW |
| Total load | 13.188 kW |
| Total network losses (P) | 32.36 W |
| Total network losses (Q) | 11.42 W var |
| Loss fraction | 0.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.465 V (bus `319`) |

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
| ✅ | `142` | 240.0 V | 24 | 0.998 (`319`) | 1.0 (`319`) | 0.2 % (`319`) | 0.46 V (`319`) |

### Per-bus detail

**Zone `142`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `319` | 239.7 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.46 V |
| ✅ | `335` | 239.7 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.39 V |
| ✅ | `251` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.37 V |
| ✅ | `390` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.34 V |
| ✅ | `252` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.33 V |
| ✅ | `247` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.33 V |
| ✅ | `468` | 239.8 | 240.2 | 0.998 | 1.0 | 0.1 % | 0.31 V |
| ✅ | `388` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.31 V |
| ✅ | `395` | 239.8 | 240.2 | 0.998 | 1.0 | 0.1 % | 0.31 V |
| ✅ | `377` | 239.8 | 240.2 | 0.998 | 1.0 | 0.1 % | 0.31 V |
| ✅ | `301` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.31 V |
| ✅ | `348` | 239.8 | 240.2 | 0.998 | 1.0 | 0.2 % | 0.3 V |
| ✅ | `281` | 239.8 | 240.2 | 0.999 | 1.0 | 0.2 % | 0.31 V |
| ✅ | `275` | 239.8 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.3 V |
| ✅ | `362` | 239.8 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.28 V |
| ✅ | `190` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.18 V |
| ✅ | `266` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.14 V |
| ✅ | `238` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.1 V |
| ✅ | `150` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `146` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `142` | 240.0 | 240.2 | 0.999 | 1.0 | 0.1 % | 0.08 V |
| ✅ | `80` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.08 V |
| ✅ | `19` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.02 V |
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
  Maximum neutral terminal voltage: 0.46 V at bus '319' — reflects the neutral shift under unbalanced loading.

