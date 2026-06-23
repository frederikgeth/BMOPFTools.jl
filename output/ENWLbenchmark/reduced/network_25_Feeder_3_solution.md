# BMOPF Solution Profile: network_25_Feeder_3

**Generated:** 2026-06-23 13:46:42  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -65.7786  
**Solve time:** 0.029 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 13.795 kW |
| Total load | 13.764 kW |
| Total network losses (P) | 30.83 W |
| Total network losses (Q) | 9.19 W var |
| Loss fraction | 0.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.35 V (bus `404`) |

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
| ✅ | `118` | 240.0 V | 28 | 0.998 (`404`) | 1.0 (`sourcebus`) | 0.2 % (`404`) | 0.35 V (`404`) |

### Per-bus detail

**Zone `118`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `404` | 239.6 | 240.0 | 0.998 | 0.999 | 0.2 % | 0.35 V |
| ✅ | `403` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.28 V |
| ✅ | `409` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.28 V |
| ✅ | `356` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `348` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `411` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.25 V |
| ✅ | `334` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `326` | 239.7 | 240.0 | 0.998 | 0.999 | 0.1 % | 0.24 V |
| ✅ | `243` | 239.8 | 240.1 | 0.998 | 1.0 | 0.1 % | 0.24 V |
| ✅ | `77` | 239.8 | 240.1 | 0.998 | 1.0 | 0.1 % | 0.19 V |
| ✅ | `436` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.17 V |
| ✅ | `503` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.16 V |
| ✅ | `499` | 239.8 | 240.1 | 0.999 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `443` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `501` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.13 V |
| ✅ | `417` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `410` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `475` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.14 V |
| ✅ | `297` | 239.8 | 240.1 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `267` | 239.8 | 240.1 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `124` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.14 V |
| ✅ | `118` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.14 V |
| ✅ | `130` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.14 V |
| ✅ | `277` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.13 V |
| ✅ | `85` | 239.8 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `81` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
| ✅ | `68` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.15 V |
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
  Maximum neutral terminal voltage: 0.35 V at bus '404' — reflects the neutral shift under unbalanced loading.

