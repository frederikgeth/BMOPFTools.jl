# BMOPF Solution Profile: network_4_Feeder_3

**Generated:** 2026-06-23 13:46:57  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -76.1266  
**Solve time:** 0.03 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.137 kW |
| Total load | 17.034 kW |
| Total network losses (P) | 103.06 W |
| Total network losses (Q) | 25.88 W var |
| Loss fraction | 0.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.71 V (bus `107`) |

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
| ✅ | `102` | 240.0 V | 39 | 0.993 (`212`) | 1.0 (`sourcebus`) | 0.5 % (`107`) | 0.71 V (`107`) |

### Per-bus detail

**Zone `102`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `212` | 238.6 | 239.6 | 0.993 | 0.998 | 0.4 % | 0.39 V |
| ✅ | `107` | 238.6 | 239.7 | 0.994 | 0.998 | 0.5 % | 0.71 V |
| ✅ | `242` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.35 V |
| ✅ | `239` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.33 V |
| ✅ | `200` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.33 V |
| ✅ | `225` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.33 V |
| ✅ | `234` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.33 V |
| ✅ | `196` | 238.6 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.33 V |
| ✅ | `194` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.28 V |
| ✅ | `185` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.31 V |
| ✅ | `180` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.32 V |
| ✅ | `178` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.35 V |
| ✅ | `175` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.32 V |
| ✅ | `183` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.31 V |
| ✅ | `171` | 238.7 | 239.6 | 0.994 | 0.998 | 0.4 % | 0.34 V |
| ✅ | `130` | 238.7 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.39 V |
| ✅ | `126` | 238.7 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.39 V |
| ✅ | `125` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.45 V |
| ✅ | `121` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.42 V |
| ✅ | `127` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.4 V |
| ✅ | `119` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.43 V |
| ✅ | `120` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.44 V |
| ✅ | `114` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.45 V |
| ✅ | `105` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.47 V |
| ✅ | `112` | 238.8 | 239.6 | 0.994 | 0.998 | 0.3 % | 0.39 V |
| ✅ | `93` | 238.8 | 239.9 | 0.994 | 0.999 | 0.4 % | 0.7 V |
| ✅ | `102` | 238.8 | 239.7 | 0.994 | 0.998 | 0.4 % | 0.5 V |
| ✅ | `99` | 238.9 | 239.8 | 0.995 | 0.998 | 0.4 % | 0.48 V |
| ✅ | `96` | 238.9 | 239.8 | 0.995 | 0.998 | 0.4 % | 0.49 V |
| ✅ | `87` | 239.0 | 239.8 | 0.995 | 0.999 | 0.3 % | 0.49 V |
| ✅ | `95` | 239.0 | 239.8 | 0.995 | 0.998 | 0.3 % | 0.48 V |
| ✅ | `84` | 239.0 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.49 V |
| ✅ | `89` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.58 V |
| ✅ | `82` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.44 V |
| ✅ | `73` | 239.4 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.33 V |
| ✅ | `90` | 239.4 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.2 V |
| ✅ | `67` | 239.5 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.3 V |
| ✅ | `52` | 239.6 | 240.0 | 0.998 | 0.999 | 0.2 % | 0.24 V |
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
  Maximum neutral terminal voltage: 0.71 V at bus '107' — reflects the neutral shift under unbalanced loading.

