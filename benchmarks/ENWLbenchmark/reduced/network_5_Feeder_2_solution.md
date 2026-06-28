# BMOPF Solution Profile: network_5_Feeder_2

**Generated:** 2026-06-23 13:46:57  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -80.7477  
**Solve time:** 0.033 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 17.439 kW |
| Total load | 17.358 kW |
| Total network losses (P) | 80.61 W |
| Total network losses (Q) | 11.19 W var |
| Loss fraction | 0.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.545 V (bus `157`) |

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
| ✅ | `102` | 240.0 V | 39 | 0.995 (`157`) | 1.0 (`sourcebus`) | 0.4 % (`157`) | 0.55 V (`157`) |

### Per-bus detail

**Zone `102`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `157` | 238.9 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.55 V |
| ✅ | `179` | 238.9 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.46 V |
| ✅ | `193` | 238.9 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.48 V |
| ✅ | `190` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.47 V |
| ✅ | `188` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.48 V |
| ✅ | `185` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.47 V |
| ✅ | `181` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.46 V |
| ✅ | `184` | 239.0 | 239.8 | 0.995 | 0.999 | 0.4 % | 0.45 V |
| ✅ | `176` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.45 V |
| ✅ | `154` | 239.0 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.43 V |
| ✅ | `153` | 239.1 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.36 V |
| ✅ | `150` | 239.1 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.42 V |
| ✅ | `149` | 239.1 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.42 V |
| ✅ | `146` | 239.1 | 239.9 | 0.995 | 0.999 | 0.3 % | 0.42 V |
| ✅ | `145` | 239.1 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.43 V |
| ✅ | `140` | 239.1 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.41 V |
| ✅ | `142` | 239.1 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.41 V |
| ✅ | `136` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.4 V |
| ✅ | `138` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.4 V |
| ✅ | `128` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.39 V |
| ✅ | `107` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.41 V |
| ✅ | `102` | 239.2 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.47 V |
| ✅ | `103` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.39 V |
| ✅ | `120` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.37 V |
| ✅ | `108` | 239.3 | 239.9 | 0.996 | 0.999 | 0.3 % | 0.36 V |
| ✅ | `99` | 239.4 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.34 V |
| ✅ | `95` | 239.4 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.32 V |
| ✅ | `57` | 239.5 | 240.0 | 0.997 | 0.999 | 0.2 % | 0.34 V |
| ✅ | `63` | 239.6 | 239.9 | 0.997 | 0.999 | 0.1 % | 0.22 V |
| ✅ | `68` | 239.6 | 239.8 | 0.997 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `73` | 239.6 | 239.8 | 0.997 | 0.999 | 0.1 % | 0.14 V |
| ✅ | `74` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.11 V |
| ✅ | `56` | 239.6 | 240.0 | 0.998 | 0.999 | 0.2 % | 0.28 V |
| ✅ | `52` | 239.6 | 240.0 | 0.998 | 0.999 | 0.2 % | 0.27 V |
| ✅ | `49` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.18 V |
| ✅ | `45` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `38` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.06 V |
| ✅ | `32` | 240.1 | 240.1 | 1.0 | 1.0 | 0.0 % | 0.02 V |
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
  Maximum neutral terminal voltage: 0.55 V at bus '157' — reflects the neutral shift under unbalanced loading.

