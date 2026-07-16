# Objective and feasibility

The component pages define the network's variables and constraints — the *feasible
set*. This page defines what is optimised over it: the **objective**, and the
**feasibility relaxation** used to diagnose networks that have no feasible point.
Unlike the component pages this is a *formulation* page, not a data object. Symbols are
defined in [Notation](notation.md).

## Objective

The default snapshot objective minimises total **active-power dispatch cost
rate**, summed over every dispatchable element (generators, the voltage source,
IBRs) and every phase:

```math
\min \; \sum_{e} \sum_{k} \textcolor{red}{c_{e,k}}\; P_{e,k}/1000,
```

where $\textcolor{red}{c_{e,k}}$ (currency/kWh, from each element's per-phase
`cost` array) is the energy price of phase $k$, and $P_{e,k}$ is that phase's
injected active power in watts — the same bilinear expression the element defines
($P_{e,k}=\Delta v^r\,c^r + \Delta v^i\,c^i$). The factor $1/1000$ converts W to
kW, so this snapshot objective is a cost **rate** in currency/h. For a
multi-period monetary objective, multiply every snapshot rate by its duration in
hours before summing.

### Sign convention

$P_{e,k}$ is the power **injected into the network** by the element, uniformly across
generators, IBRs, and the voltage source (each stamps $+I$ into KCL). Therefore:

- a **positive** cost minimises that element's injection;
- a **negative** cost maximises it.

The voltage source is *not* special: for the slack, positive injection means importing
from the grid, so a positive source cost is the grid import price (and export, a
negative injection, is credited at the same price). Maximising system exports is a
positive slack cost with free DERs.

The cost is **linear** in the dispatch and is added exactly — there is no
polynomial/quadratic term. A `cost` must be a per-phase vector; a scalar is rejected.

## Feasibility relaxation

A constant-power OPF can be **infeasible**: the load/generation specification may be
irreconcilable with the network physics. To diagnose such cases, a
feasibility-relaxed variant adds an **elastic slack current** and minimises it, instead
of cost.

### Elastic slack

At every ungrounded, non-source terminal a free slack current
$\textcolor{blue}{s_{i,p}}=s^r_{i,p}+\textcolor{brown}{j}\,s^i_{i,p}$ is added directly
into that terminal's KCL:

```math
\kappa^{\Re}_{i,p} + s^r_{i,p} = 0, \qquad \kappa^{\Im}_{i,p} + s^i_{i,p} = 0.
```

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
