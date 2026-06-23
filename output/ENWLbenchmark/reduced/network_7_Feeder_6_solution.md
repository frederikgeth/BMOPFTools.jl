# BMOPF Solution Profile: network_7_Feeder_6

**Generated:** 2026-06-23 13:47:05  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -120.6772  
**Solve time:** 0.05 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.224 kW |
| Total load | 21.114 kW |
| Total network losses (P) | 110.19 W |
| Total network losses (Q) | 28.66 W var |
| Loss fraction | 0.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.084 V (bus `194`) |

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
| ✅ | `100` | 240.0 V | 28 | 0.994 (`194`) | 1.0 (`sourcebus`) | 0.4 % (`194`) | 1.08 V (`194`) |

### Per-bus detail

**Zone `100`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `194` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.08 V |
| ✅ | `197` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.06 V |
| ✅ | `190` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.06 V |
| ✅ | `196` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `193` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `192` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `198` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `195` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.05 V |
| ✅ | `191` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.04 V |
| ✅ | `186` | 238.8 | 239.8 | 0.994 | 0.999 | 0.4 % | 1.04 V |
| ✅ | `182` | 239.3 | 239.8 | 0.996 | 0.999 | 0.2 % | 0.54 V |
| ✅ | `113` | 239.6 | 239.8 | 0.997 | 0.999 | 0.1 % | 0.36 V |
| ✅ | `100` | 239.6 | 239.8 | 0.997 | 0.998 | 0.1 % | 0.32 V |
| ✅ | `107` | 239.6 | 239.8 | 0.997 | 0.999 | 0.1 % | 0.35 V |
| ✅ | `108` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.3 V |
| ✅ | `96` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.32 V |
| ✅ | `103` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.26 V |
| ✅ | `97` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.27 V |
| ✅ | `101` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.12 V |
| ✅ | `98` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.09 V |
| ✅ | `152` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.19 V |
| ✅ | `146` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.21 V |
| ✅ | `153` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.2 V |
| ✅ | `93` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.25 V |
| ✅ | `99` | 239.6 | 239.8 | 0.998 | 0.998 | 0.1 % | 0.26 V |
| ✅ | `102` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.32 V |
| ✅ | `78` | 239.6 | 239.8 | 0.998 | 0.999 | 0.1 % | 0.26 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |
| W | `grid` | `2` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |
| W | `grid` | `3` | pg | -42.228 kW | [-42.228 kW, 42.228 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-42.228 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-42.228 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-42.228 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 1.08 V at bus '194' — reflects the neutral shift under unbalanced loading.

