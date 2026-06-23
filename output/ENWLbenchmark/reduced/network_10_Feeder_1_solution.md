# BMOPF Solution Profile: network_10_Feeder_1

**Generated:** 2026-06-23 13:46:10  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -102.2528  
**Solve time:** 0.055 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.945 kW |
| Total load | 19.902 kW |
| Total network losses (P) | 42.63 W |
| Total network losses (Q) | 12.11 W var |
| Loss fraction | 0.2% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.383 V (bus `241`) |

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
| ✅ | `116` | 240.0 V | 25 | 0.998 (`241`) | 1.0 (`sourcebus`) | 0.2 % (`241`) | 0.38 V (`241`) |

### Per-bus detail

**Zone `116`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `241` | 239.6 | 240.1 | 0.998 | 1.0 | 0.2 % | 0.38 V |
| ✅ | `246` | 239.7 | 240.1 | 0.998 | 1.0 | 0.2 % | 0.37 V |
| ✅ | `124` | 239.8 | 240.1 | 0.998 | 1.0 | 0.1 % | 0.3 V |
| ✅ | `121` | 239.8 | 240.1 | 0.998 | 1.0 | 0.1 % | 0.3 V |
| ✅ | `125` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.18 V |
| ✅ | `119` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.17 V |
| ✅ | `130` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.18 V |
| ✅ | `127` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.18 V |
| ✅ | `242` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `244` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.07 V |
| ✅ | `247` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.07 V |
| ✅ | `122` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.16 V |
| ✅ | `123` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `132` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `120` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.14 V |
| ✅ | `129` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.15 V |
| ✅ | `126` | 239.9 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.15 V |
| ✅ | `116` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.16 V |
| ✅ | `128` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.16 V |
| ✅ | `243` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.05 V |
| ✅ | `235` | 240.0 | 240.1 | 0.999 | 1.0 | 0.0 % | 0.04 V |
| ✅ | `248` | 240.0 | 240.1 | 0.999 | 0.999 | 0.0 % | 0.02 V |
| ✅ | `245` | 240.0 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.03 V |
| ✅ | `46` | 240.1 | 240.1 | 1.0 | 1.0 | 0.0 % | 0.05 V |
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
  Maximum neutral terminal voltage: 0.38 V at bus '241' — reflects the neutral shift under unbalanced loading.

