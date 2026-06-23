# BMOPF Solution Profile: network_9_Feeder_4

**Generated:** 2026-06-23 13:47:06  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -91.5908  
**Solve time:** 0.042 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.93 kW |
| Total load | 19.902 kW |
| Total network losses (P) | 28.2 W |
| Total network losses (Q) | 9.09 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.189 V (bus `124`) |

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
| ✅ | `117` | 240.0 V | 24 | 0.999 (`124`) | 1.0 (`sourcebus`) | 0.1 % (`124`) | 0.19 V (`124`) |

### Per-bus detail

**Zone `117`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `124` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `121` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `119` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `137` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `125` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `122` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `133` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.14 V |
| ✅ | `128` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `131` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `139` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.14 V |
| ✅ | `134` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `130` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `136` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `127` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `118` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `135` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `126` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `129` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `120` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `138` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `123` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.1 V |
| ✅ | `132` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.09 V |
| ✅ | `117` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |
| W | `grid` | `2` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |
| W | `grid` | `3` | pg | -39.804 kW | [-39.804 kW, 39.804 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-39.804 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-39.804 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-39.804 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.19 V at bus '124' — reflects the neutral shift under unbalanced loading.

