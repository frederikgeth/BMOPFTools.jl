# Shunts

A **shunt** is a fixed admittance connected between a set of bus terminals (and,
implicitly, ground). It models capacitor banks, grounding impedances, and similar
passive elements.

The foundational model (data model, symbols, variables, constraints) is in the
[Shunt page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/shunt/).
This page records where BMOPFTools extends it and how BMOPFTools implements it.
Symbols are defined in [Notation](notation.md). BMOPFTools implements the
specification's shunt model without extensions.

## Implementation in BMOPFTools

### [Realization](@id Realisation)

- **No variables: in-place substitution.** Exactly as for the line
  $\Pi$-shunt, the code builds the affine expression
  $\textcolor{brown}{\mathbf{Y}_{h}}\textcolor{blue}{\mathbf{U}_i}$ as JuMP `AffExpr`
  terms ([`shunt.jl:_shunt_current!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/shunt.jl)) and subtracts them directly from
  the KCL accumulator ([`shunt.jl:_add_shunt_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/shunt.jl)); no
  shunt-current variable or defining equality is created.
- **Grounded terminals** have their voltage variables fixed to zero
  (`variables.jl:_add_voltage_variables!`), so admittance entries that multiply them
  contribute nothing and grounding admittances collapse naturally. A terminal with
  no declared voltage variable is skipped.
- **Transformer core shunts.** A shunt recorded as an explicit transformer core
  shunt is booked to its transformer in the per-device loss ledger; its KCL
  contribution is unchanged.
- Per row/column $k,j$: $\mathfrak{R}(\textcolor{blue}{I_{h,k}}) = \sum_j(\mathbf{G}_{kj} v^r_j - \mathbf{B}_{kj} v^i_j)$,
  $\mathfrak{I}(\textcolor{blue}{I_{h,k}}) = \sum_j(\mathbf{G}_{kj} v^i_j + \mathbf{B}_{kj} v^r_j)$.

### Source map

| Constraint | Code location |
|------------|---------------|
| Shunt current expression | `shunt.jl:_shunt_current!` |
| KCL contribution | `shunt.jl:_add_shunt_constraints!` |
