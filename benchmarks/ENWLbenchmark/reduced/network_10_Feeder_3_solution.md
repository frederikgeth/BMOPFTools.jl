# BMOPF Solution Profile: network_10_Feeder_3

**Generated:** 2026-06-23 13:46:10  
**Status:** `LOCALLY_SOLVED`  
**Objective:** -96.9621  
**Solve time:** 0.053 s  
**Findings:** 0 errors · 3 warnings · 2 info  

---

## 1. Solution Summary

| Field | Value |
|-------|-------|
| Status | `LOCALLY_SOLVED` |
| Total generation | 16.718 kW |
| Total load | 16.632 kW |
| Total network losses (P) | 86.25 W |
| Total network losses (Q) | 44.47 W var |
| Loss fraction | 0.5% |
| Active power balance error | 0.0 W |
| Reactive power balance error | 0.0 W var |
| Max neutral shift | 0.489 V (bus `343`) |

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
| ✅ | `285` | 240.0 V | 38 | 0.994 (`343`) | 1.0 (`sourcebus`) | 0.3 % (`343`) | 0.49 V (`343`) |

### Per-bus detail

**Zone `285`** (base 240.0 V):

| St | Bus | Vm min (V) | Vm max (V) | Vm min (pu) | Vm max (pu) | Imbalance | Neutral |
|:--:|-----|-----------:|-----------:|------------:|------------:|----------:|--------:|
| ✅ | `343` | 238.8 | 239.5 | 0.994 | 0.997 | 0.3 % | 0.49 V |
| ✅ | `349` | 238.8 | 239.4 | 0.994 | 0.997 | 0.3 % | 0.42 V |
| ✅ | `401` | 238.8 | 239.4 | 0.994 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `391` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `396` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.33 V |
| ✅ | `392` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.33 V |
| ✅ | `397` | 238.9 | 239.3 | 0.995 | 0.996 | 0.2 % | 0.28 V |
| ✅ | `395` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.32 V |
| ✅ | `389` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `387` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `390` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `393` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `360` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `365` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `363` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `342` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.38 V |
| ✅ | `359` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `354` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `368` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `358` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `364` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `353` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `347` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `357` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.36 V |
| ✅ | `340` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `346` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `348` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.35 V |
| ✅ | `336` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `341` | 238.9 | 239.4 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `333` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `335` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `338` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.4 V |
| ✅ | `337` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `334` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.38 V |
| ✅ | `331` | 238.9 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.37 V |
| ✅ | `292` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `285` | 239.0 | 239.5 | 0.995 | 0.997 | 0.2 % | 0.34 V |
| ✅ | `sourcebus` | 240.2 | 240.2 | 1.0 | 1.0 | 0.0 % | — |

## 4. Generator Dispatch

| Sev | Generator | Terminal | Field | Value | Bound |
|-----|-----------|----------|-------|-------|-------|
| W | `grid` | `1` | pg | -33.264 kW | [-33.264 kW, 33.264 kW] |
| W | `grid` | `2` | pg | -33.264 kW | [-33.264 kW, 33.264 kW] |
| W | `grid` | `3` | pg | -33.264 kW | [-33.264 kW, 33.264 kW] |

## 6. All Findings

- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '1': pg=-33.264 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '2': pg=-33.264 kW is within 1 % of its bound (active).
- **WARN** `W.SOL.GEN_ACTIVE` — generator/`grid`  
  Generator 'grid' phase '3': pg=-33.264 kW is within 1 % of its bound (active).
- INFO `I.SOL.BINDING_SUMMARY`  
  Solution bound summary: 0 violation(s), 3 active constraint(s). Voltage: 0V / 0A. Thermal: 0V / 0A. Generator: 0V / 3A.
- INFO `I.SOL.NEUTRAL_SHIFT`  
  Maximum neutral terminal voltage: 0.49 V at bus '343' — reflects the neutral shift under unbalanced loading.

