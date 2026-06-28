# BMOPF Solution Profile: network_4_Feeder_5

**Generated:** 2026-06-23 13:46:57  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -104.3354  
**Solve time:** 0.033 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.658 kW |
| Total load | 19.566 kW |
| Total network losses (P) | 92.4 W |
| Total network losses (Q) | 21.82 W var |
| Loss fraction | 0.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.69 V (bus `175`) |

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
| ✅ | `109` | 240.0 V | 44 | 0.995 (`404`) | 1.0 (`sourcebus`) | 0.3 % (`175`) | 0.69 V (`175`) |

### Per-bus detail

**Zone `109`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `404` | 238.9 | 239.5 | 0.995 | 0.997 | 0.3 % | 0.26 V |
| ✅ | `348` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.15 V |
| ✅ | `375` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `406` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.12 V |
| ✅ | `396` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.09 V |
| ✅ | `341` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `376` | 239.1 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.24 V |
| ✅ | `399` | 239.1 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `326` | 239.1 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `394` | 239.1 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.13 V |
| ✅ | `321` | 239.1 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `364` | 239.1 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.27 V |
| ✅ | `307` | 239.1 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.13 V |
| ✅ | `324` | 239.1 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.14 V |
| ✅ | `329` | 239.1 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.16 V |
| ✅ | `319` | 239.1 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.13 V |
| ✅ | `342` | 239.2 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.09 V |
| ✅ | `311` | 239.2 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.12 V |
| ✅ | `276` | 239.2 | 239.5 | 0.996 | 0.997 | 0.2 % | 0.11 V |
| ✅ | `175` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.69 V |
| ✅ | `271` | 239.2 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.09 V |
| ✅ | `216` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.08 V |
| ✅ | `202` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.06 V |
| ✅ | `278` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.04 V |
| ✅ | `125` | 239.3 | 239.8 | 0.996 | 0.998 | 0.2 % | 0.36 V |
| ✅ | `255` | 239.4 | 239.6 | 0.997 | 0.998 | 0.1 % | 0.05 V |
| ✅ | `189` | 239.4 | 239.6 | 0.997 | 0.998 | 0.1 % | 0.05 V |
| ✅ | `173` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.06 V |
| ✅ | `183` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.12 V |
| ✅ | `162` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.1 V |
| ✅ | `129` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.08 V |
| ✅ | `114` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.09 V |
| ✅ | `147` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.09 V |
| ✅ | `91` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.13 V |
| ✅ | `118` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `85` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `94` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `71` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `68` | 239.7 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `240` | 239.8 | 239.9 | 0.998 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `109` | 239.8 | 239.9 | 0.998 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `66` | 239.8 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.11 V |
| ✅ | `65` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.08 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -39.132 kW | [-39.132 kW, 39.132 kW] |
| W | `grid` | `2` | pg | -39.132 kW | [-39.132 kW, 39.132 kW] |
| W | `grid` | `3` | pg | -39.132 kW | [-39.132 kW, 39.132 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-39.132 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-39.132 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-39.132 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.69 V at bus '175' — reflects the neutral shift under unbalanced loading.

