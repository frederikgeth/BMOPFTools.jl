# Switches

A **switch** is an ideal, lossless branch connecting two buses conductor-for-conductor.
When *closed* it short-circuits its terminals; when *open* it carries no current.

The foundational model (data model, symbols, variables, constraints) is in the
[Switch page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/switch/).
This page records where BMOPFTools extends it and how BMOPFTools implements it.
Symbols are defined in [Notation](notation.md).

## BMOPFTools extensions to the specification

### Apparent-power limit

The OPF also enforces an optional per-conductor `s_max` (VA) on a closed switch:
the ground-referenced apparent-power cone
$\textcolor{blue}{\mathbf{S}_{w ij}}\circ(\textcolor{blue}{\mathbf{S}_{w ij}})^{*} \le \textcolor{red}{\mathbf{S}^{\max}_{w ij}}\circ\textcolor{red}{\mathbf{S}^{\max}_{w ij}}$
with $\textcolor{blue}{\mathbf{S}_{w ij}}$ the product of the from-end terminal
voltages and the conjugate switch currents, conductor by conductor.
A switch has no shunt, so one cone at the from end suffices. `s_max` is not in the
bundled schema's switch properties, so data that uses it does not validate against
the schema.

## Implementation in BMOPFTools

### [Realization](@id Realisation)

- **Rectangular variables.** The switch current is `cr_sw`/`ci_sw`
  ([`variables.jl:_add_switch_variables!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/variables.jl)). For an **open** switch these are
  fixed to zero at declaration (`fix`), so no voltage coupling is stamped.
- **Closed-switch coupling** is stamped as the two real parts
  `vr[from]==vr[to]`, `vi[from]==vi[to]` per conductor
  ([`branch.jl:_add_switch_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/branch.jl)).
- **KCL contribution** is added as `-cr_sw` at `bus_from` and `+cr_sw` at `bus_to`
  (same function), realizing $\textcolor{blue}{\mathbf{I}_{w ji}}=-\textcolor{blue}{\mathbf{I}_{w ij}}$
  without a separate variable.
- **Limits.** The thermal quadratic, the Cartesian box (`_limit_current_box!`), and
  the optional `s_max` cone are stamped from the from-side current in the same
  function, and only for closed switches (an open switch's current is already
  fixed to zero).
- **Terminal maps** must have equal, nonzero length; otherwise the switch is
  refused with an `ArgumentError`.

### Source map

| Constraint | Code location |
|------------|---------------|
| Switch current variables (open → fixed 0) | `variables.jl:_add_switch_variables!` |
| Closed coupling, KCL, current and power limits | `branch.jl:_add_switch_constraints!` |
