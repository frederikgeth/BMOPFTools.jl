# BMOPF Solution Profile: network_4_Feeder_2

**Generated:** 2026-06-23 13:46:57  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -96.3277  
**Solve time:** 0.029 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.852 kW |
| Total load | 16.746 kW |
| Total network losses (P) | 106.0 W |
| Total network losses (Q) | 25.92 W var |
| Loss fraction | 0.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.471 V (bus `170`) |

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
| ✅ | `149` | 240.0 V | 35 | 0.993 (`386`) | 1.0 (`sourcebus`) | 0.2 % (`170`) | 0.47 V (`170`) |

### Per-bus detail

**Zone `149`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `386` | 238.6 | 238.8 | 0.993 | 0.994 | 0.1 % | 0.25 V |
| ✅ | `328` | 238.6 | 239.1 | 0.994 | 0.995 | 0.2 % | 0.41 V |
| ✅ | `390` | 238.6 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.2 V |
| ✅ | `384` | 238.6 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.21 V |
| ✅ | `381` | 238.6 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.21 V |
| ✅ | `372` | 238.6 | 238.9 | 0.994 | 0.994 | 0.1 % | 0.22 V |
| ✅ | `374` | 238.7 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.2 V |
| ✅ | `379` | 238.7 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.2 V |
| ✅ | `331` | 238.7 | 239.0 | 0.994 | 0.995 | 0.2 % | 0.34 V |
| ✅ | `370` | 238.7 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.2 V |
| ✅ | `376` | 238.7 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.14 V |
| ✅ | `366` | 238.7 | 238.9 | 0.994 | 0.994 | 0.1 % | 0.2 V |
| ✅ | `365` | 238.7 | 238.8 | 0.994 | 0.994 | 0.1 % | 0.17 V |
| ✅ | `358` | 238.7 | 238.9 | 0.994 | 0.995 | 0.1 % | 0.2 V |
| ✅ | `357` | 238.7 | 238.9 | 0.994 | 0.995 | 0.1 % | 0.22 V |
| ✅ | `350` | 238.7 | 238.9 | 0.994 | 0.995 | 0.1 % | 0.22 V |
| ✅ | `343` | 238.7 | 239.0 | 0.994 | 0.995 | 0.1 % | 0.27 V |
| ✅ | `348` | 238.7 | 238.9 | 0.994 | 0.995 | 0.1 % | 0.21 V |
| ✅ | `340` | 238.7 | 239.0 | 0.994 | 0.995 | 0.1 % | 0.23 V |
| ✅ | `336` | 238.7 | 239.0 | 0.994 | 0.995 | 0.1 % | 0.25 V |
| ✅ | `327` | 238.8 | 239.0 | 0.994 | 0.995 | 0.1 % | 0.28 V |
| ✅ | `325` | 238.8 | 239.1 | 0.994 | 0.995 | 0.1 % | 0.28 V |
| ✅ | `270` | 239.0 | 239.1 | 0.995 | 0.995 | 0.0 % | 0.09 V |
| ✅ | `252` | 239.0 | 239.2 | 0.995 | 0.996 | 0.1 % | 0.23 V |
| ✅ | `263` | 239.0 | 239.2 | 0.995 | 0.996 | 0.1 % | 0.23 V |
| ✅ | `170` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.47 V |
| ✅ | `200` | 239.1 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.26 V |
| ✅ | `158` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.28 V |
| ✅ | `157` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.33 V |
| ✅ | `208` | 239.4 | 239.6 | 0.997 | 0.998 | 0.1 % | 0.27 V |
| ✅ | `154` | 239.4 | 239.6 | 0.997 | 0.998 | 0.1 % | 0.25 V |
| ✅ | `162` | 239.4 | 239.6 | 0.997 | 0.998 | 0.1 % | 0.23 V |
| ✅ | `151` | 239.4 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.24 V |
| ✅ | `149` | 239.5 | 239.7 | 0.997 | 0.998 | 0.1 % | 0.23 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -33.492 kW | [-33.492 kW, 33.492 kW] |
| W | `grid` | `2` | pg | -33.492 kW | [-33.492 kW, 33.492 kW] |
| W | `grid` | `3` | pg | -33.492 kW | [-33.492 kW, 33.492 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-33.492 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-33.492 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-33.492 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.47 V at bus '170' — reflects the neutral shift under unbalanced loading.

