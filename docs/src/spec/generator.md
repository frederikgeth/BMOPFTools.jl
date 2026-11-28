# Generators

A **generator** injects a *dispatchable* power at a bus: active and reactive power
lie within bounds rather than being fixed (a fixed injection is modeled as a negative
load). It shares the load's bilinear power form.

The foundational model (data model, symbols, variables, constraints) is in the
[Generator page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/generator/).
This page records where BMOPFTools extends it and how BMOPFTools implements it.
Symbols are defined in [Notation](notation.md).

## BMOPFTools extensions to the specification

### Cost field name

BMOPFTools reads the per-phase linear generation cost (currency/kWh) from the field
`cost`, the specification's `energy_cost_rate`. Phase $k$ contributes
$\textcolor{red}{c_{g,k}}\,P_{g,k}/1000$ per hour, with $P_{g,k}$ in W. The same
`cost` convention applies to the voltage source and to IBRs.

### `SINGLE_PHASE` and `DELTA` configurations

The specification supports only `WYE` generators. BMOPFTools also accepts:

- **`SINGLE_PHASE`**, handled like `WYE`: the sub-generator voltage is
  phase-to-neutral when the terminal map has a neutral, phase-to-ground otherwise.
- **`DELTA`**, with one coil per phase pair (three for a closed delta, one for a
  two-terminal line-to-line unit). The sub-generator voltage
  $\Delta\textcolor{blue}{U_{g,k}}$ is line-to-line; the coil current enters at the
  first terminal of the pair and returns at the second. The power box, apparent-power
  circle, and current circle of the specification apply per coil.

For a two-terminal unit (a single-phase `WYE`/`SINGLE_PHASE` unit, or a one-coil
`DELTA` unit), the phase and return conductors carry the same current, so the
`i_max` entries collapse to one circle at the tighter limit. Any other configuration
is refused with an `ArgumentError`.

## Implementation in BMOPFTools

### [Realization](@id Realisation)

- **Rectangular bilinear power.** The code stamps
  $P = \Delta v^r\,\text{crg} + \Delta v^i\,\text{cig}$,
  $Q = \Delta v^i\,\text{crg} - \Delta v^r\,\text{cig}$ and applies the P/Q box bounds
  directly ([`generator.jl:_add_generator_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/generator.jl)).
- **Apparent-power circle via auxiliaries.** To keep the constraint quadratic, real
  variables `pg`,`qg` are pinned to the bilinear $P,Q$ and bounded by
  $\text{pg}^2+\text{qg}^2\le\textcolor{red}{S^{\max}}^2$.
- **Current circle + box.** `crg^2+cig^2 ≤ i_max^2` plus `_limit_current_box!`.
- **Neutral-conductor limit.** With a trailing `i_max` entry (≥2 phases and a
  neutral in the terminal map, so `i_max` has one entry more than the phases), the return
  current $-\sum_k\textcolor{blue}{I_{g,k}}$ is bounded via `_neutral_current_limit!`.
  For a single-phase device (phase and return are the same current) the entries
  collapse to one circle at the tighter limit.
- **KCL**: `+crg` at the phase terminal, `-crg` at the neutral (`_kcl_add!`); for
  `DELTA`, `+crg`/`-crg` at the coil's two terminals.

### Source map

| Constraint | Code location |
|------------|---------------|
| Currents, KCL, P/Q box, s/i limits | `generator.jl:_add_generator_constraints!` |
| Neutral-return current limit | `data_utils.jl:_neutral_current_limit!` |
| Objective (per-phase `cost`) | `objective.jl:_generation_cost_expr` |
