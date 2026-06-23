# BMOPF Solution Profile: network_9_Feeder_6

**Generated:** 2026-06-23 13:47:07  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -115.7351  
**Solve time:** 0.087 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 20.896 kW |
| Total load | 20.868 kW |
| Total network losses (P) | 27.93 W |
| Total network losses (Q) | 10.02 W var |
| Loss fraction | 0.1% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.148 V (bus `165`) |

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
| ✅ | `156` | 240.0 V | 26 | 0.999 (`181`) | 1.0 (`sourcebus`) | 0.1 % (`181`) | 0.15 V (`165`) |

### Per-bus detail

**Zone `156`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `181` | 239.8 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.14 V |
| ✅ | `166` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `160` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `178` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.12 V |
| ✅ | `165` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `162` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.15 V |
| ✅ | `163` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `169` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `172` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `175` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `174` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `180` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `171` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `177` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.1 V |
| ✅ | `168` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `158` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `167` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.08 V |
| ✅ | `176` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.08 V |
| ✅ | `170` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.08 V |
| ✅ | `179` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `161` | 239.9 | 240.0 | 0.999 | 0.999 | 0.1 % | 0.08 V |
| ✅ | `164` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.06 V |
| ✅ | `173` | 239.9 | 240.0 | 0.999 | 0.999 | 0.0 % | 0.04 V |
| ✅ | `156` | 239.9 | 240.1 | 0.999 | 0.999 | 0.1 % | 0.09 V |
| ✅ | `46` | 240.1 | 240.2 | 1.0 | 1.0 | 0.0 % | 0.02 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |
| W | `grid` | `2` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |
| W | `grid` | `3` | pg | -41.736 kW | [-41.736 kW, 41.736 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-41.736 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-41.736 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-41.736 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.15 V at bus '165' — reflects the neutral shift under unbalanced loading.

