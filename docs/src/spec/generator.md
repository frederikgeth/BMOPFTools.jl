# Generators

A **generator** injects a *dispatchable* power at a bus — active and reactive power
lie within bounds rather than being fixed (a fixed injection is modelled as a negative
load). It shares the load's bilinear power form and connection configurations. Parts
1–5 state the foundational model; [part 6](#6.-Implementation-in-BMOPFTools) records
how BMOPFTools realises it. Symbols are defined in [Notation](notation.md).

## 1. Data model

A generator is an entry of the top-level `generator` object, keyed by its string ID $g$.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `bus` | string | – | ✔ | Host bus ID $i$ |
| `terminal_map` | string[] | – | ✔ | Conductor→terminal map $\textcolor{purple}{\mathbf{N}_{g}}$ |
| `configuration` | string | – | ✔ | `WYE`, `SINGLE_PHASE`, or `DELTA` |
| `p_min`, `p_max` | number[] | W | | Per-phase active-power bounds |
| `q_min`, `q_max` | number[] | var | | Per-phase reactive-power bounds |
| `s_max` | number[] | VA | | Per-phase apparent-power rating |
| `i_max` | number[] | A | | Per-conductor current-magnitude limit (incl. optional neutral entry) |
| `cost` | number[] | \$/kWh | | Per-phase linear generation cost |

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `p_min`, `p_max` | $\textcolor{red}{P^{\min}_{g}},\ \textcolor{red}{P^{\max}_{g}}$ | per phase |
| `q_min`, `q_max` | $\textcolor{red}{Q^{\min}_{g}},\ \textcolor{red}{Q^{\max}_{g}}$ | per phase |
| `s_max` | $\textcolor{red}{\mathbf{S}^{\max}_{g}}$ | per phase |
| `i_max` | $\textcolor{red}{\mathbf{I}^{\max}_{g}}$ | per conductor (last entry may bound the neutral return) |
| `cost` | $\textcolor{red}{\mathbf{c}_{g}}$ | per phase |

## 3. Variables

Each phase conductor $k$ injects a complex current $\textcolor{blue}{I_{g,k}}$ (the
current sent *to* the bus, opposite sign to a load), stacked into
$\textcolor{blue}{\mathbf{I}_{g}}$. The neutral return is implicit in KCL.

## 4. Equality constraints

With $\Delta\textcolor{blue}{U_{g,k}}$ the sub-generator voltage (phase-to-neutral for
`WYE`/`SINGLE_PHASE`, line-to-line for `DELTA`), the injected complex power is

```math
\textcolor{blue}{S_{g,k}} = \Delta\textcolor{blue}{U_{g,k}}\,(\textcolor{blue}{I_{g,k}})^{*}
= P_{g,k} + \textcolor{brown}{j}\,Q_{g,k}.
```

Current conservation over the generator's terminals gives its KCL contribution
(injection positive at the phase terminal, return at the neutral).

## 5. Inequality constraints

### Cartesian variable bounds

When `i_max` is present, a **box** on the current components
$|\mathfrak{R}(\textcolor{blue}{I_{g,k}})|,\,|\mathfrak{I}(\textcolor{blue}{I_{g,k}})|\le\textcolor{red}{I^{\max}_{g,k}}$
bounds the search; implied by the current circle below.

### Engineering bounds

**Active/reactive power box** (the dispatch range):

```math
\textcolor{red}{P^{\min}_{g,k}} \le P_{g,k} \le \textcolor{red}{P^{\max}_{g,k}},
\qquad
\textcolor{red}{Q^{\min}_{g,k}} \le Q_{g,k} \le \textcolor{red}{Q^{\max}_{g,k}}.
```

**Apparent-power circle** (optional):

```math
P_{g,k}^2 + Q_{g,k}^2 \le (\textcolor{red}{S^{\max}_{g,k}})^2.
```

**Current-magnitude circle** (optional), per conductor:

```math
\textcolor{blue}{I_{g,k}}(\textcolor{blue}{I_{g,k}})^{*} \le (\textcolor{red}{I^{\max}_{g,k}})^2.
```

For a star-connected generator whose `i_max` carries a trailing neutral entry, the
neutral return current $-\mathbf{1}^{\text{T}}\textcolor{blue}{\mathbf{I}_{g}}[\mathcal{P}]$
is additionally bounded by that entry.

## 6. Implementation in BMOPFTools

### Realisation

- **Rectangular bilinear power.** The code stamps
  $P = \Delta v^r\,\text{crg} + \Delta v^i\,\text{cig}$,
  $Q = \Delta v^i\,\text{crg} - \Delta v^r\,\text{cig}$ and applies the P/Q box bounds
  directly ([`generator.jl:_add_generator_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/generator.jl)).
- **Apparent-power circle via auxiliaries.** To keep the constraint quadratic, real
  variables `pg`,`qg` are pinned to the bilinear $P,Q$ and bounded by
  $\text{pg}^2+\text{qg}^2\le\textcolor{red}{S^{\max}}^2$.
- **Current circle + box.** `crg^2+cig^2 ≤ i_max^2` plus `_limit_current_box!`.
- **Neutral-conductor limit.** With a trailing `i_max` entry (≥2 phases), the return
  current $-\sum_k\textcolor{blue}{I_{g,k}}$ is bounded via `_neutral_current_limit!`.
  For a single-phase device (phase and return are the same current) the entries
  collapse to one circle at the tighter limit.
- **KCL**: `+crg` at the phase terminal, `-crg` at the neutral (`_kcl_add!`).

### Source map

| Constraint | Code location |
|------------|---------------|
| Currents, KCL, P/Q box, s/i limits | `generator.jl:_add_generator_constraints!` |
| Neutral-return current limit | `_neutral_current_limit!` |
| Objective (per-phase `cost`) | `objective.jl` |

!!! note "Reconciliation note — per-phase `cost`, `s_max`, `i_max`"
    The generator `cost` is a **per-phase array** (\$/kWh), and `s_max`/`i_max` are the
    apparent-power and current ratings above. In the Task Force PDF these appear in its
    schema-update addendum, including the neutral-return `i_max` entry; the code
    implements all of them. Fold into the primary generator data model when the PDF is
    superseded.
