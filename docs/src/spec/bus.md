# Buses

A **bus** is a set of electrical terminals sharing a location. It owns the network's
voltage variables and is where Kirchhoff's current law is enforced.

The foundational model (data model, symbols, variables, constraints) is in the
[Bus page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/bus/).
This page records where BMOPFTools extends it and how BMOPFTools implements it.
Symbols are defined in [Notation](notation.md).

## 4. Equality constraints

See [4. Equality constraints](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/bus/#4.-Equality-constraints)
in the specification.

### Perfect grounding

A perfectly grounded terminal is pinned to $0\text{ V}$; see
[Perfect grounding](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/bus/#Perfect-grounding).

### Kirchhoff's current law

The signed currents of all incident elements sum to zero at each terminal; see
[Kirchhoff's current law](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/bus/#Kirchhoff's-current-law)
for the equation and its sign convention.

## Engineering bounds

The phase-to-ground, neutral, phase-to-neutral, phase-to-phase, and
symmetrical-component magnitude bounds are defined in
[Engineering bounds](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/bus/#Engineering-bounds).
BMOPFTools adds the bounds listed below.

## BMOPFTools extensions to the specification

### Field names and additional fields

| Field | Type | Unit | Description |
|-------|------|:----:|-------------|
| `v_min`, `v_max` | number[] | V | Phase-to-ground magnitude bounds, one per phase terminal. BMOPFTools uses these names for the specification's `vpg_min`, `vpg_max`; a scalar value is rejected. |
| `vuf_max` | number | – | Voltage unbalance factor cap $\lvert U^{2}_i\rvert/\lvert U^{1}_i\rvert$ (three-phase buses, dimensionless) |
| `va_diff_min`, `va_diff_max` | number | rad | Intra-bus angle-difference window, applied to every phase pair |
| `va_nom` | number[] | rad | Nominal phase angles, one per phase terminal, that center the angle window |

### Voltage unbalance factor

`vneg_max` caps $|U^{2}_i|$ absolutely. `vuf_max` $=u$ instead bounds the ratio to
the positive sequence, which is itself a decision variable:

```math
\textcolor{blue}{U^{2}_i}(\textcolor{blue}{U^{2}_i})^{*} \ \le\ u^2\,
\textcolor{blue}{U^{1}_i}(\textcolor{blue}{U^{1}_i})^{*}, \qquad u \ge 0,
```

using the same sequence voltages as the specification's symmetrical-component
bounds. Because both sides scale as voltage squared, `vuf_max` needs no per-unit
conversion.

### Intra-bus angle difference

For each pair of applicable phase terminals $(p,q)$, with nominal offset
$\Delta=\textcolor{red}{\theta^{\text{nom}}_{i,q}}-\textcolor{red}{\theta^{\text{nom}}_{i,p}}$
taken from `va_nom` (offset $0$ when `va_nom` is absent) and
$\textcolor{blue}{z}=\textcolor{blue}{U_{i,p}}^{*}\textcolor{blue}{U_{i,q}}\,e^{-\textcolor{brown}{j}\Delta}=c+\textcolor{brown}{j}s$:

```math
\tan(\textcolor{red}{\theta^{\Delta,\min}_i})\, c \ \le\ s \ \le\ \tan(\textcolor{red}{\theta^{\Delta,\max}_i})\, c,
```

which bounds the angle between the two terminals, centered on its nominal offset.
Both `va_diff_min` and `va_diff_max` must be supplied (one-sided windows are
rejected), and both must lie strictly within $(-\pi/2, \pi/2)$. The rows are stamped
multiplied by $\cos$ of the bound to keep coefficients bounded; an equal-endpoint
window adds the half-plane guard $c\ge 0$ to exclude the antipodal solution.

## Implementation in BMOPFTools

### [Realization](@id Realisation)

- **Rectangular variables.** Each $\textcolor{blue}{U_{i,p}}$ is two real variables
  `vr[(i,p)]`, `vi[(i,p)]` (its real and imaginary parts), declared free in
  [`variables.jl:_add_voltage_variables!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/variables.jl). No box is set, matching the
  specification's absence of a Cartesian voltage bound.
- **Grounding** is `fix(vr,0); fix(vi,0)` in the same function. A free
  ground-injection current `cr_gnd`/`ci_gnd` (`_add_ground_variables!`) is added at
  each grounded terminal so current can flow into earth there.
- **Source fixing** is `fix(vr, |U|·cos θ); fix(vi, |U|·sin θ)` in
  [`source.jl:_add_source_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/source.jl).
- **KCL** is not stamped as a single vector equation. Instead each incident element
  adds its signed contribution into a per-terminal accumulator
  $(\kappa^{\Re}_{i,p},\kappa^{\Im}_{i,p})$ (`bus.jl:_init_kcl`, `_kcl_add!`), and the
  real and imaginary parts are set to zero separately,
  $\kappa^{\Re}_{i,p}=0,\ \kappa^{\Im}_{i,p}=0$ (`bus.jl:_add_kcl_constraints!`). The
  accumulator counts current flowing into the bus as positive, the negation of the
  specification's convention; the equation is the same. Grounded terminals keep
  their KCL equation, balanced by the ground-injection current.
- **Engineering bounds** are stamped as quadratics in the rectangular variables in
  `bus.jl:_add_voltage_bounds!` (phase-to-ground) and `_add_bus_limit_constraints!`
  (`vn_max`, phase-to-neutral, phase-to-phase, angle, symmetrical components,
  `vuf_max`). Upper-only magnitude caps (`vn_max`, `vneg_max`, `vzero_max`) use the
  normalized form $(a/U^{\max})^2+(b/U^{\max})^2\le 1$. The Fortescue transform is
  applied as an explicit real expansion of $\textcolor{brown}{\mathbf{F}}$ rather
  than a matrix multiply.

### Source map

| Constraint | Code location |
|------------|---------------|
| Voltage variables / grounding | `variables.jl:_add_voltage_variables!` |
| Ground-injection current | `variables.jl:_add_ground_variables!` |
| Source fixing | `source.jl:_add_source_constraints!` |
| KCL (accumulator + equality) | `bus.jl:_init_kcl`, `_kcl_add!`, `_add_kcl_constraints!` |
| Phase-to-ground bounds | `bus.jl:_add_voltage_bounds!` |
| `vn_max`, vpn, vpp, angle, sym, `vuf_max` | `bus.jl:_add_bus_limit_constraints!` (blocks a–e) |
| Angle-window validation and rows | `data_utils.jl:_angle_window`, `_angle_window_constraints!` |

### Reconciliation notes (data model)

!!! warning "Angle-difference fields absent from the schema"
    The intra-bus angle bound uses `va_diff_min`, `va_diff_max`, and the
    nominal-offset vector `va_nom`, but none of these fields are in the bundled
    schema's bus properties (which disallow additional properties). Data that uses
    them is enforced by the solver but does not validate against the schema.
