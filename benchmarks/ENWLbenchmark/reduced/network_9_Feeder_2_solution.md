# BMOPF Solution Profile: network_9_Feeder_2

**Generated:** 2026-06-23 13:47:06  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -110.3514  
**Solve time:** 0.042 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 19.931 kW |
| Total load | 19.902 kW |
| Total network losses (P) | 28.72 W |
| Total network losses (Q) | 9.06 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.197 V (bus `96`) |

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
| ✅ | `100` | 240.0 V | 24 | 0.999 (`96`) | 1.0 (`sourcebus`) | 0.1 % (`96`) | 0.2 V (`96`) |

### Per-bus detail

**Zone `100`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `96` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.2 V |
| ✅ | `93` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.19 V |
| ✅ | `97` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `109` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `91` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.13 V |
| ✅ | `94` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `105` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.14 V |
| ✅ | `100` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `103` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `106` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `111` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `102` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `108` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `99` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.13 V |
| ✅ | `90` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.12 V |
| ✅ | `110` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `107` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `98` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `101` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `92` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
| ✅ | `95` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.1 V |
| ✅ | `104` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.08 V |
| ✅ | `89` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.11 V |
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
  Maximum neutral terminal voltage: 0.2 V at bus '96' — reflects the neutral shift under unbalanced loading.

