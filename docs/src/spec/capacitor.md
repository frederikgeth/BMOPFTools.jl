# Capacitors

A **capacitor** is a fixed, nameplate-rated shunt capacitor bank. Electrically it is a
constant susceptance derived from its rating, delivering voltage-dependent reactive
power. Parts 1–5 state the foundational model;
[part 6](#6.-Implementation-in-BMOPFTools) records how BMOPFTools realises it. Symbols
are defined in [Notation](notation.md).

## 1. Data model

A capacitor is an entry of the top-level `capacitor` object, keyed by its string ID.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `bus` | string | – | ✔ | Host bus ID $i$ |
| `terminal_map` | string[] | – | ✔ | Conductor→terminal map |
| `configuration` | string | – | ✔ | `WYE`, `SINGLE_PHASE`, or `DELTA` |
| `q_rated` | number[] | var | ✔ | Rated reactive power per phase (WYE) or per phase-pair (DELTA) |
| `v_nom` | number | V | ✔ | Rated voltage (phase-to-neutral for WYE, line-to-line for DELTA) |

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `q_rated` | $\textcolor{red}{\mathbf{Q}^{\text{rated}}}$ | per phase / phase-pair |
| `v_nom` | $\textcolor{red}{V^{\text{nom}}}$ | rated voltage |

The bank's susceptance follows from the nameplate: $\textcolor{red}{B}=\textcolor{red}{Q^{\text{rated}}}/(\textcolor{red}{V^{\text{nom}}})^2$,
assembled (per configuration) into a terminal-space admittance
$\textcolor{brown}{\mathbf{Y}}=\textcolor{brown}{j}\,\textcolor{red}{\mathbf{B}}$.

## 3. Variables

**None.** Like a shunt, a capacitor introduces no unknown — its current follows from
the bus voltage and its fixed susceptance.

## 4. Equality constraints

The current drawn into the capacitor is linear in the bus voltage, and is the bank's
contribution to KCL at bus $i$:

```math
\textcolor{blue}{\mathbf{I}} = \textcolor{brown}{j}\,\textcolor{red}{\mathbf{B}}\,\textcolor{blue}{\mathbf{U}_i}[\textcolor{purple}{\mathbf{N}}].
```

The delivered reactive power is therefore voltage-dependent,
$\textcolor{red}{\mathbf{B}}\,|\textcolor{blue}{\mathbf{U}}|^2$ — it rises and falls
with the square of the terminal voltage, the defining behaviour of a fixed capacitor
(as opposed to a fixed-power source).

## 5. Inequality constraints

**None.** With a fixed susceptance the current follows the voltage; no rating bound is
imposed.

## 6. Implementation in BMOPFTools

### Realisation

A capacitor is treated as a **connection-aware shunt**. The nameplate and connection
are assembled into a terminal-space susceptance matrix ($\textcolor{red}{\mathbf{B}}$,
via `_cap_bmatrix`), and the current is injected with the **same** in-place machinery
as a standalone [shunt](shunt.md) — `_shunt_current!` with $G=$ nothing — subtracting
the affine expression $\textcolor{red}{\mathbf{B}}\textcolor{blue}{\mathbf{U}}$ from
the KCL accumulator. No decision variable or defining equality is created
([`capacitor.jl:_add_capacitor_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/capacitor.jl)).

### Source map

| Constraint | Code location |
|------------|---------------|
| Susceptance matrix from nameplate | `_cap_bmatrix` (`src/io/capacitor.jl`) |
| Current expression + KCL | `capacitor.jl:_add_capacitor_constraints!` (via `shunt.jl:_shunt_current!`) |
