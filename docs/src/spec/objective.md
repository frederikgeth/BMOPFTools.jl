# Objective and feasibility

The component pages define the network's variables and constraints, that is, the
*feasible set*. This page covers what is optimized over it: the dispatch-cost
objective and the feasibility relaxation used to diagnose networks that have no
feasible point. Symbols are defined in [Notation](notation.md).

The foundational model is in the [Objective page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/objective/). This page records where BMOPFTools extends it and how BMOPFTools implements it.

## BMOPFTools extensions to the specification

BMOPFTools uses the specification's linear dispatch-cost objective and its
[sign convention](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/objective/#Sign-convention)
(a positive price minimizes the element's injection; the voltage source is not a
special case). It differs in these points:

- **Field name.** The per-phase price array is read from each element's `cost`
  field (currency/kWh), not `energy_cost_rate`.
- **IBRs are priced too.** The sum runs over generators, the voltage source, and
  IBRs.
- **Snapshot cost rate.** The objective omits the snapshot duration
  $\Delta_T$ and is a cost *rate* in currency/h:

  ```math
  \min \; \sum_{e} \sum_{k} \textcolor{red}{c_{e,k}}\; P_{e,k}/1000,
  ```

  where $P_{e,k}$ is the active power, in watts, injected by phase $k$ of element
  $e$. For a multi-period monetary objective, multiply every snapshot rate by its
  duration in hours before summing.
- **Per-phase vectors only.** A scalar (polynomial-style) `cost` is rejected; there is
  no quadratic term.

## Feasibility relaxation

A constant-power OPF can be **infeasible**: the load/generation specification may be
irreconcilable with the network physics. To diagnose such cases, a
feasibility-relaxed variant adds an **elastic slack current** and minimizes it, instead
of cost.

### Elastic slack

At every ungrounded terminal that has a KCL row, a free slack current
$\textcolor{blue}{s_{i,p}}=s^r_{i,p}+\textcolor{brown}{j}\,s^i_{i,p}$ is added directly
into that terminal's KCL:

```math
\kappa^{\Re}_{i,p} + s^r_{i,p} = 0, \qquad \kappa^{\Im}_{i,p} + s^i_{i,p} = 0,
```

where $\kappa^{\Re}_{i,p}$ and $\kappa^{\Im}_{i,p}$ are the real and imaginary parts
of the unrelaxed KCL current sum at terminal $(i,p)$. Source-bus phase terminals are
included; there the source's own free current already balances KCL, so the penalty
drives their slack to zero.

Where a slack pair is present, it can absorb any residual in that terminal's KCL.
This does **not** guarantee that the complete relaxed NLP is feasible or that a
local solver will converge: fixed source voltages, hard bounds, device equalities,
or terminals without slacks can still conflict.

### Objective

The cost objective is replaced by the squared magnitude ($\ell_2^2$) of all slack
injections:

```math
\min \; \sum_{i,p} \big( (s^r_{i,p})^2 + (s^i_{i,p})^2 \big).
```

### Interpretation

The relaxation retains the standard OPF's hard constraints — voltage bounds,
bus/line angle limits, and every device current limit — while enlarging the
feasible set only through the nodal-current slacks. Consequently, for a
successfully converged solve:

- An independently residual-checked **zero-slack** point demonstrates numerical
  feasibility under the represented loading and constraints.
- **Non-zero** slack at a locally optimal relaxed point identifies where that
  solve paid to violate KCL and by how much current. It is diagnostic evidence,
  not a proof that the original nonconvex problem has no zero-slack solution.
- Voltages still respect their hard bounds. When those hard constraints remain
  mutually consistent, an unreachable operating bound commonly surfaces as
  residual current. Contradictory hard constraints can instead leave even the
  relaxed problem infeasible (for example, a fixed source voltage contradicting
  a bound on the same terminal).

## Implementation in BMOPFTools

- **Objective** — `objective.jl:_add_objective!` accumulates the per-phase linear terms
  for generators, the voltage source, and IBRs into one `QuadExpr` and sets
  `@objective(model, Min, …)`.
- **Feasibility** — `solve_feasibility_opf` (`feasibility_opf.jl`) reuses the full OPF
  build (`_add_voltage_and_bus_bounds!`, `_add_device_constraints!`), then adds one
  `(cs_r, cs_i)` pair per KCL node into the accumulators and sets the $\ell_2^2$
  objective. Post-solve, `extract_feasibility!` reports per-terminal
  `slack_injections` and the scalar L2 norm `total_slack_magnitude_A`, consumed by
  `diagnose_infeasibility`.
- **Degeneracy tie-break** — for Yd/Dy transformers the delta circulation current is
  unobservable; a tiny ($-10^{-6}$) linear term on the delta-side current selects one
  numerical representative. Consequently the raw solver objective is an
  implementation metric, not exactly the physical squared-slack norm; use the
  reported SI slack fields for interpretation.
- **Warm start** — when a case lacks useful voltage bounds, level-aware start
  values seed LV buses near their nominal (≈250 V) rather than the source voltage.

### Source map

| Constraint | Code location |
|------------|---------------|
| Objective (min cost) | `objective.jl:_add_objective!` |
| Feasibility slacks + objective | `feasibility_opf.jl:build_feasibility!` |
| Residual extraction | `feasibility_opf.jl:extract_feasibility!` |
