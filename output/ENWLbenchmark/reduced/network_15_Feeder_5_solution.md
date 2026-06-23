# BMOPF Solution Profile: network_15_Feeder_5

**Generated:** 2026-06-23 13:46:20  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -106.2138  
**Solve time:** 0.052 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 21.236 kW |
| Total load | 21.114 kW |
| Total network losses (P) | 122.06 W |
| Total network losses (Q) | 36.77 W var |
| Loss fraction | 0.6% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 1.174 V (bus `510`) |

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
| ✅ | `1064` | 240.0 V | 44 | 0.993 (`510`) | 1.0 (`sourcebus`) | 0.6 % (`510`) | 1.17 V (`510`) |

### Per-bus detail

**Zone `1064`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `510` | 238.6 | 239.9 | 0.993 | 0.999 | 0.6 % | 1.17 V |
| ✅ | `496` | 238.6 | 239.9 | 0.994 | 0.999 | 0.5 % | 1.15 V |
| ✅ | `490` | 238.7 | 239.9 | 0.994 | 0.999 | 0.5 % | 1.08 V |
| ✅ | `461` | 238.8 | 239.9 | 0.994 | 0.999 | 0.5 % | 0.95 V |
| ✅ | `457` | 238.9 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.93 V |
| ✅ | `432` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.81 V |
| ✅ | `427` | 239.0 | 239.9 | 0.995 | 0.999 | 0.4 % | 0.79 V |
| ✅ | `1301` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.31 V |
| ✅ | `1295` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.31 V |
| ✅ | `1223` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.43 V |
| ✅ | `1202` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.29 V |
| ✅ | `1218` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.32 V |
| ✅ | `1186` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.29 V |
| ✅ | `1123` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.31 V |
| ✅ | `1134` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.3 V |
| ✅ | `1067` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.31 V |
| ✅ | `888` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.29 V |
| ✅ | `1104` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.28 V |
| ✅ | `1170` | 239.2 | 239.4 | 0.996 | 0.997 | 0.1 % | 0.36 V |
| ✅ | `815` | 239.2 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.28 V |
| ✅ | `1106` | 239.3 | 239.5 | 0.996 | 0.997 | 0.1 % | 0.26 V |
| ✅ | `776` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.25 V |
| ✅ | `1064` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.18 V |
| ✅ | `1080` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.15 V |
| ✅ | `1079` | 239.3 | 239.6 | 0.996 | 0.997 | 0.1 % | 0.12 V |
| ✅ | `987` | 239.3 | 239.6 | 0.996 | 0.998 | 0.1 % | 0.29 V |
| ✅ | `797` | 239.3 | 239.6 | 0.996 | 0.998 | 0.1 % | 0.28 V |
| ✅ | `629` | 239.3 | 239.6 | 0.996 | 0.998 | 0.1 % | 0.27 V |
| ✅ | `921` | 239.3 | 239.7 | 0.996 | 0.998 | 0.2 % | 0.29 V |
| ✅ | `903` | 239.3 | 239.7 | 0.996 | 0.998 | 0.1 % | 0.29 V |
| ✅ | `535` | 239.3 | 239.7 | 0.996 | 0.998 | 0.1 % | 0.28 V |
| ✅ | `856` | 239.4 | 239.8 | 0.997 | 0.998 | 0.2 % | 0.34 V |
| ✅ | `774` | 239.4 | 239.8 | 0.997 | 0.998 | 0.2 % | 0.32 V |
| ✅ | `523` | 239.4 | 239.8 | 0.997 | 0.998 | 0.2 % | 0.31 V |
| ✅ | `509` | 239.4 | 239.8 | 0.997 | 0.998 | 0.2 % | 0.31 V |
| ✅ | `471` | 239.4 | 239.8 | 0.997 | 0.998 | 0.2 % | 0.31 V |
| ✅ | `260` | 239.4 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.35 V |
| ✅ | `244` | 239.5 | 239.9 | 0.997 | 0.999 | 0.2 % | 0.35 V |
| ✅ | `213` | 239.6 | 240.1 | 0.998 | 1.0 | 0.2 % | 0.35 V |
| ✅ | `192` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.13 V |
| ✅ | `74` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
| ✅ | `75` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
| ✅ | `70` | 239.9 | 240.1 | 0.999 | 1.0 | 0.1 % | 0.11 V |
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
  Maximum neutral terminal voltage: 1.17 V at bus '510' — reflects the neutral shift under unbalanced loading.

