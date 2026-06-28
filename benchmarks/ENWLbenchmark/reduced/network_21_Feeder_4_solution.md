# BMOPF Solution Profile: network_21_Feeder_4

**Generated:** 2026-06-23 13:46:39  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -70.9567  
**Solve time:** 0.035 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.4 kW |
| Total load | 17.358 kW |
| Total network losses (P) | 42.47 W |
| Total network losses (Q) | 8.63 W var |
| Loss fraction | 0.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.239 V (bus `318`) |

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
| ✅ | `105` | 240.0 V | 41 | 0.998 (`318`) | 1.0 (`sourcebus`) | 0.1 % (`318`) | 0.24 V (`318`) |

### Per-bus detail

**Zone `105`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `318` | 239.6 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.24 V |
| ✅ | `359` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.22 V |
| ✅ | `152` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.21 V |
| ✅ | `175` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.22 V |
| ✅ | `322` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.21 V |
| ✅ | `331` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.21 V |
| ✅ | `376` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.22 V |
| ✅ | `362` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `316` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.2 V |
| ✅ | `181` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.17 V |
| ✅ | `314` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.18 V |
| ✅ | `372` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `206` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.17 V |
| ✅ | `305` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `226` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `236` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `295` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.17 V |
| ✅ | `253` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `198` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `165` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `264` | 239.8 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `203` | 239.8 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `151` | 239.8 | 239.9 | 0.998 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `298` | 239.8 | 239.8 | 0.998 | 0.999 | 0.0 % | 0.09 V |
| ✅ | `119` | 239.8 | 239.9 | 0.998 | 0.999 | 0.0 % | 0.1 V |
| ✅ | `99` | 239.8 | 239.9 | 0.998 | 0.999 | 0.0 % | 0.1 V |
| ✅ | `178` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `276` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.16 V |
| ✅ | `73` | 239.8 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.11 V |
| ✅ | `155` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.14 V |
| ✅ | `164` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.14 V |
| ✅ | `154` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.14 V |
| ✅ | `68` | 239.8 | 239.9 | 0.998 | 0.999 | 0.0 % | 0.1 V |
| ✅ | `94` | 239.8 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `63` | 239.8 | 239.9 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `115` | 239.8 | 239.9 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `86` | 239.8 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `105` | 239.9 | 239.9 | 0.999 | 0.999 | 0.0 % | 0.05 V |
| ✅ | `55` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.07 V |
| ✅ | `47` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.07 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -34.716 kW | [-34.716 kW, 34.716 kW] |
| W | `grid` | `2` | pg | -34.716 kW | [-34.716 kW, 34.716 kW] |
| W | `grid` | `3` | pg | -34.716 kW | [-34.716 kW, 34.716 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-34.716 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-34.716 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-34.716 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.24 V at bus '318' — reflects the neutral shift under unbalanced loading.

