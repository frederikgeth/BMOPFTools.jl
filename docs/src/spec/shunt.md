# Shunts

A **shunt** is a fixed admittance connected between a set of bus terminals (and,
implicitly, ground). It models capacitor banks, grounding impedances, and similar
passive elements. Parts 1–5 state the foundational model;
[part 6](#6.-Implementation-in-BMOPFTools) records how BMOPFTools realises it. Symbols
are defined in [Notation](notation.md).

## 1. Data model

A shunt is an entry of the top-level `shunt` object, keyed by its string ID $h$.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `bus` | string | – | ✔ | Host bus ID $i$ |
| `terminal_map` | string[] | – | ✔ | Conductor→terminal map $\textcolor{purple}{\mathbf{N}_{h}}$ |
| `G_k_j` | number | S | ✔ (`G_1_1`) | Conductance matrix entries |
| `B_k_j` | number | S | ✔ (`B_1_1`) | Susceptance matrix entries |

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `G_k_j`, `B_k_j` | $\textcolor{brown}{\mathbf{Y}_{h}} = \mathbf{G} + \textcolor{brown}{j}\mathbf{B}$ | admittance matrix (S), row-first entries |

The matrix is stored row-first: entry $(k,j)$ is field `G_k_j` / `B_k_j`. Ground is
never indexed (its voltage is zero); zero-filled rows/columns should be removed by
trimming the terminal map.

## 3. Variables

**None.** A shunt introduces no unknown — its current is determined entirely by the
bus voltage and its fixed admittance.

## 4. Equality constraints

The current drawn into the shunt at its terminals is linear in the bus voltage:

```math
\textcolor{blue}{\mathbf{I}_{h}} = \textcolor{brown}{\mathbf{Y}_{h}}\,\textcolor{blue}{\mathbf{U}_i}[\textcolor{purple}{\mathbf{N}_{h}}].
```

This current is the shunt's contribution to KCL at bus $i$ (leaving the bus toward
the admittance/ground). Examples: a single-entry $\textcolor{brown}{Y_{h,nn}}$ on
terminal $n$ grounds the neutral through an impedance; a delta pattern
$\textcolor{brown}{Y_{\text{cap}}}\,\textcolor{red}{\mathbf{M}^{\Delta}}$ on
$\{a,b,c\}$ models a delta capacitor bank.

## 5. Inequality constraints

**None.** With a fixed admittance the current follows the voltage; a current limit
would risk trivial infeasibility and is not imposed.

## 6. Implementation in BMOPFTools

### Realisation

- **No variables — in-place substitution.** Exactly as for the line
  $\Pi$-shunt, the code builds the affine expression
  $\textcolor{brown}{\mathbf{Y}_{h}}\textcolor{blue}{\mathbf{U}_i}$ as JuMP `AffExpr`
  terms ([`shunt.jl:_shunt_current!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/shunt.jl)) and subtracts them directly from
  the KCL accumulator ([`shunt.jl:_add_shunt_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/shunt.jl)) — no
  shunt-current variable or defining equality is created.
- **Grounded terminals** are absent from the voltage dictionary and contribute
  nothing (their voltage is zero), so grounding admittances collapse naturally.
- Per row/column $k,j$: $\mathfrak{R}(\textcolor{blue}{I_{h,k}}) = \sum_j(\mathbf{G}_{kj} v^r_j - \mathbf{B}_{kj} v^i_j)$,
  $\mathfrak{I}(\textcolor{blue}{I_{h,k}}) = \sum_j(\mathbf{G}_{kj} v^i_j + \mathbf{B}_{kj} v^r_j)$.

### Source map

| Constraint | Code location |
|------------|---------------|
| Shunt current expression | `shunt.jl:_shunt_current!` |
| KCL contribution | `shunt.jl:_add_shunt_constraints!` |
