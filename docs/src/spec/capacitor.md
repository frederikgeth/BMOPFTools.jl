# Capacitors

A **capacitor** is a fixed, nameplate-rated shunt capacitor bank. Electrically it is a
constant susceptance derived from its rating, delivering voltage-dependent reactive
power.

The foundational model (data model, symbols, variables, constraints) is in the
[Capacitor page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/capacitor/).
This page records where BMOPFTools extends it and how BMOPFTools implements it.
Symbols are defined in [Notation](notation.md).

## BMOPFTools extensions to the specification

### Per-element ratings

The specification rates a balanced bank with one scalar `q_rated` for the whole bank
and a line-to-line `v_nom` (for `WYE` and `DELTA`). BMOPFTools instead rates each
element separately, which also admits unbalanced banks:

| Field | Type | Unit | Description |
|-------|------|:----:|-------------|
| `q_rated` | number[] | var | Rated reactive power per element: one per phase (`WYE`), one per phase pair (`DELTA`), one entry (`SINGLE_PHASE`) |
| `v_nom` | number | V | Rated element voltage: phase-to-neutral for `WYE`/`SINGLE_PHASE`, line-to-line for `DELTA` |

Element $k$ has susceptance
$\textcolor{red}{b_{\kappa,k}}=\textcolor{red}{Q^{\text{rated}}_{\kappa,k}}/(\textcolor{red}{V^{\text{nom}}_\kappa})^2$,
so the configuration constant $\beta_\kappa$ of the specification's
[Susceptance from nameplate data](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/capacitor/#Susceptance-from-nameplate-data)
is not needed. Each element is then placed with the specification's
reciprocal two-node stamp (see its
[Terminal-space assembly](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/capacitor/#Terminal-space-assembly)),
using its own $b_{\kappa,k}$; `DELTA` element $k$ spans terminals $(k, k+1)$
cyclically. A balanced specification bank maps to equal entries
$Q^{\text{rated}}_{\kappa,k}=Q^{\text{rated}}_\kappa/3$, with
$V^{\text{nom}}_{\text{LL}}/\sqrt3$ as `v_nom` for `WYE`; both give the same
susceptance matrix.

A `WYE` bank is stamped phase-to-neutral, so its terminal map needs a resolvable
neutral; without one the bank contributes nothing, and validation reports
`W.SPEC.CAP_WYE_NO_NEUTRAL`. A missing or non-positive `v_nom` is refused, and a
negative `q_rated` entry is reported as `E.SPEC.CAP_NEGATIVE_Q` (model a reactor as
a [shunt](shunt.md) instead).

## Implementation in BMOPFTools

### [Realization](@id Realisation)

A capacitor is treated as a **connection-aware shunt**. The nameplate and connection
are assembled into a terminal-space susceptance matrix ($\textcolor{red}{\mathbf{B}}$,
via `_cap_bmatrix`), and the current is injected with the **same** in-place machinery
as a standalone [shunt](shunt.md) (`_shunt_current!` with $G=$ `nothing`), subtracting
the affine expression $\textcolor{red}{\mathbf{B}}\textcolor{blue}{\mathbf{U}}$ from
the KCL accumulator. No decision variable or defining equality is created
([`capacitor.jl:_add_capacitor_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/capacitor.jl)).

### Source map

| Constraint | Code location |
|------------|---------------|
| Susceptance matrix from nameplate | `_cap_bmatrix` (`src/io/capacitor.jl`) |
| Current expression + KCL | `capacitor.jl:_add_capacitor_constraints!` (via `shunt.jl:_shunt_current!`) |
