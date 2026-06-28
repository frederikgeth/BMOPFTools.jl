# BMOPF Solution Profile: network_11_Feeder_1

**Generated:** 2026-06-23 13:46:11  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -137.2117  
**Solve time:** 0.066 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 25.225 kW |
| Total load | 25.14 kW |
| Total network losses (P) | 85.04 W |
| Total network losses (Q) | 41.07 W var |
| Loss fraction | 0.3% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.515 V (bus `141`) |

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
| ✅ | `117` | 240.0 V | 41 | 0.995 (`141`) | 1.0 (`sourcebus`) | 0.3 % (`141`) | 0.52 V (`141`) |

### Per-bus detail

**Zone `117`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `141` | 239.1 | 239.7 | 0.995 | 0.998 | 0.3 % | 0.52 V |
| ✅ | `142` | 239.2 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.39 V |
| ✅ | `214` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.29 V |
| ✅ | `202` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.28 V |
| ✅ | `139` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.32 V |
| ✅ | `138` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.31 V |
| ✅ | `140` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.31 V |
| ✅ | `135` | 239.3 | 239.7 | 0.997 | 0.998 | 0.2 % | 0.29 V |
| ✅ | `132` | 239.4 | 239.7 | 0.997 | 0.998 | 0.2 % | 0.28 V |
| ✅ | `205` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.21 V |
| ✅ | `208` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `211` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `199` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.21 V |
| ✅ | `200` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.16 V |
| ✅ | `203` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.17 V |
| ✅ | `212` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.17 V |
| ✅ | `209` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.18 V |
| ✅ | `206` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.18 V |
| ✅ | `198` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `210` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.18 V |
| ✅ | `204` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.17 V |
| ✅ | `213` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `201` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.2 V |
| ✅ | `207` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `176` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.18 V |
| ✅ | `97` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.16 V |
| ✅ | `126` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.14 V |
| ✅ | `123` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.13 V |
| ✅ | `124` | 239.5 | 239.6 | 0.997 | 0.998 | 0.0 % | 0.13 V |
| ✅ | `120` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.12 V |
| ✅ | `121` | 239.5 | 239.6 | 0.997 | 0.998 | 0.0 % | 0.08 V |
| ✅ | `127` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.09 V |
| ✅ | `117` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.11 V |
| ✅ | `128` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.1 V |
| ✅ | `122` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.1 V |
| ✅ | `125` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.14 V |
| ✅ | `76` | 239.5 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.11 V |
| ✅ | `73` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.11 V |
| ✅ | `85` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.11 V |
| ✅ | `88` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.12 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -50.28 kW | [-50.28 kW, 50.28 kW] |
| W | `grid` | `2` | pg | -50.28 kW | [-50.28 kW, 50.28 kW] |
| W | `grid` | `3` | pg | -50.28 kW | [-50.28 kW, 50.28 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-50.28 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-50.28 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-50.28 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.52 V at bus '141' — reflects the neutral shift under unbalanced loading.

