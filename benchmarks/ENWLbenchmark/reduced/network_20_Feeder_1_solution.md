# BMOPF Solution Profile: network_20_Feeder_1

**Generated:** 2026-06-23 13:46:39  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -133.9374  
**Solve time:** 0.109 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 23.398 kW |
| Total load | 23.364 kW |
| Total network losses (P) | 34.27 W |
| Total network losses (Q) | 12.68 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.212 V (bus `58`) |

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
| ✅ | `52` | 240.0 V | 27 | 0.999 (`58`) | 1.0 (`sourcebus`) | 0.1 % (`58`) | 0.21 V (`58`) |

### Per-bus detail

**Zone `52`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `58` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.21 V |
| ✅ | `55` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.21 V |
| ✅ | `59` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `53` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `71` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
| ✅ | `76` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `74` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
| ✅ | `56` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `77` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `65` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `62` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `67` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.12 V |
| ✅ | `68` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `73` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.1 V |
| ✅ | `64` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.1 V |
| ✅ | `61` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.1 V |
| ✅ | `70` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.1 V |
| ✅ | `52` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.09 V |
| ✅ | `75` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `72` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `54` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `63` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `69` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `60` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `57` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `66` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.02 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -46.728 kW | [-46.728 kW, 46.728 kW] |
| W | `grid` | `2` | pg | -46.728 kW | [-46.728 kW, 46.728 kW] |
| W | `grid` | `3` | pg | -46.728 kW | [-46.728 kW, 46.728 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-46.728 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-46.728 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-46.728 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.21 V at bus '58' — reflects the neutral shift under unbalanced loading.

