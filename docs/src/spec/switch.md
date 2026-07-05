# Switches

A **switch** is an ideal, lossless branch connecting two buses conductor-for-conductor.
When *closed* it short-circuits its terminals; when *open* it carries no current. Parts
1–5 state the foundational model; [part 6](#6.-Implementation-in-BMOPFTools) records how
BMOPFTools realises it. Symbols are defined in [Notation](notation.md).

## 1. Data model

A switch is an entry of the top-level `switch` object, keyed by its string ID $w$.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `bus_from`, `bus_to` | string | – | ✔ | Endpoint bus IDs $i$, $j$ |
| `terminal_map_from` | string[] | – | ✔ | Conductor→terminal map at `bus_from` |
| `terminal_map_to` | string[] | – | ✔ | Conductor→terminal map at `bus_to` |
| `open_switch` | bool | – | ✔ | `true` = open (no current), `false` = closed |
| `i_max` | number[] | A | | Per-conductor current-magnitude limit |

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `open_switch` | state $\in\{\text{open},\text{closed}\}$ | selects which equality applies |
| `i_max` | $\textcolor{red}{\mathbf{I}^{\max}_{w ij}}$ | per conductor |

## 3. Variables

A switch has $n_w$ conductors and one complex current per conductor, flowing from $i$
toward $j$:

```math
\textcolor{blue}{\mathbf{I}_{w ij}} \in \mathbb{C}^{n_w}.
```

The reverse current $\textcolor{blue}{\mathbf{I}_{w ji}}$ is its negative.

## 4. Equality constraints

### Closed switch — zero voltage drop

A closed switch equates the two ends conductor-by-conductor:

```math
\textcolor{blue}{\mathbf{U}_i}[\textcolor{purple}{\mathbf{N}_{w i}}]
= \textcolor{blue}{\mathbf{U}_j}[\textcolor{purple}{\mathbf{N}_{w j}}].
```

### Open switch — zero current

An open switch carries no current and imposes no voltage coupling (the two buses are
electrically disconnected at these conductors):

```math
\textcolor{blue}{\mathbf{I}_{w ij}} = \mathbf{0}.
```

### Current conservation and KCL

In both states the current is conserved, and enters each bus's KCL with opposite sign:

```math
\textcolor{blue}{\mathbf{I}_{w ji}} = -\,\textcolor{blue}{\mathbf{I}_{w ij}}.
```

## 5. Inequality constraints

### Cartesian variable bounds

When a current limit is present, a **box** is placed on the switch-current variable
components, $|\mathfrak{R}(\textcolor{blue}{I_{w ij,k}})|,\,|\mathfrak{I}(\textcolor{blue}{I_{w ij,k}})|\le\textcolor{red}{I^{\max}_{w ij,k}}$,
to bound the search. It is implied by the engineering limit below.

### Engineering bounds

**Thermal current limit** (a switch has no shunt, so both ends carry equal magnitude
— one constraint suffices):

```math
\textcolor{blue}{\mathbf{I}_{w ij}}\circ(\textcolor{blue}{\mathbf{I}_{w ij}})^{*}
\ \le\ \textcolor{red}{\mathbf{I}^{\max}_{w ij}}\!\circ\textcolor{red}{\mathbf{I}^{\max}_{w ij}}.
```

## 6. Implementation in BMOPFTools

### Realisation

- **Rectangular variables.** The switch current is `cr_sw`/`ci_sw`
  ([`variables.jl:_add_switch_variables!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/variables.jl)). For an **open** switch these are
  fixed to zero at declaration (`fix`), so no voltage coupling is stamped.
- **Closed-switch coupling** is stamped as the two real parts
  `vr[from]==vr[to]`, `vi[from]==vi[to]` per conductor
  ([`branch.jl:_add_switch_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/branch.jl)).
- **KCL contribution** is added as `-cr_sw` at `bus_from` and `+cr_sw` at `bus_to`
  (same function) — realising $\textcolor{blue}{\mathbf{I}_{w ji}}=-\textcolor{blue}{\mathbf{I}_{w ij}}$
  without a separate variable.
- **Limits.** The thermal quadratic and the cartesian box (`_limit_current_box!`) are
  stamped from the from-side current in the same function.

### Source map

| Constraint | Code location |
|------------|---------------|
| Switch current variables (open → fixed 0) | `variables.jl:_add_switch_variables!` |
| Closed coupling, KCL, current limit | `branch.jl:_add_switch_constraints!` |
