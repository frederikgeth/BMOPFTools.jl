# Objective and feasibility

The component pages define the network's variables and constraints — the *feasible
set*. This page defines what is optimised over it: the **objective**, and the
**feasibility relaxation** used to diagnose networks that have no feasible point.
Unlike the component pages this is a *formulation* page, not a data object. Symbols are
defined in [Notation](notation.md).

## Objective

The default objective minimises total **active-power dispatch cost**, summed over every
dispatchable element (generators, the voltage source, IBRs) and every phase:

```math
\min \; \sum_{e} \sum_{k} \textcolor{red}{c_{e,k}}\; P_{e,k},
```

where $\textcolor{red}{c_{e,k}}$ (currency/W, from each element's per-phase `cost`
array) is the linear cost coefficient of phase $k$, and $P_{e,k}$ is that phase's
injected active power — the same bilinear expression the element defines
($P_{e,k}=\Delta v^r\,c^r + \Delta v^i\,c^i$).

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

Because the slack is unconstrained, KCL is **always satisfiable** — the relaxed problem
always has a solution.

### Objective

The cost objective is replaced by the squared magnitude ($\ell_2^2$) of all slack
injections:

```math
\min \; \sum_{i,p} \big( (s^r_{i,p})^2 + (s^i_{i,p})^2 \big).
```

### Interpretation

The relaxation carries the **same hard constraints** as the standard OPF — voltage
bounds, bus/line angle limits, and every device current limit — so its feasible set is
identical; the nodal current residual is the *only* relaxation, and it relaxes KCL.
Consequently:

- A **zero** slack solution certifies the network is physically feasible under its
  loading.
- **Non-zero** slack at a terminal localises and quantifies where KCL cannot balance —
  the origin and magnitude of the infeasibility.
- Voltages still respect their hard bounds (a constrained voltage sits at its bound and
  the imbalance surfaces as residual current), so infeasibility on *either* power
  balance or a voltage/angle bound is diagnosed by the residual pattern rather than a
  solver failure. A genuine solver-infeasible status is reserved for hard bounds that
  no nodal current can reconcile (e.g. a fixed source voltage contradicting a bound on
  the same terminal).

## Implementation in BMOPFTools

- **Objective** — `objective.jl:_add_objective!` accumulates the per-phase linear terms
  for generators, the voltage source, and IBRs into one `QuadExpr` and sets
  `@objective(model, Min, …)`.
- **Feasibility** — `solve_feasibility_opf` (`feasibility_opf.jl`) reuses the full OPF
  build (`_add_voltage_and_bus_bounds!`, `_add_device_constraints!`), then adds one
  `(cs_r, cs_i)` pair per KCL node into the accumulators and sets the $\ell_2^2$
  objective. Post-solve, `extract_feasibility!` reports `slack_injections` and
  `total_slack_magnitude_A` per terminal, consumed by `diagnose_infeasibility`.
- **Degeneracy tie-break** — for Yd/Dy transformers the delta circulation current is
  unobservable; a tiny ($-10^{-6}$) linear term on the delta-side current selects the
  physical branch without competing with the slack term.
- **Warm start** — the feasibility model has no voltage bounds pinning the degenerate
  $v=0$ / high-voltage minima, so level-aware start values seed LV buses near their
  nominal (≈250 V) rather than the source voltage.

### Source map

| Constraint | Code location |
|------------|---------------|
| Objective (min cost) | `objective.jl:_add_objective!` |
| Feasibility slacks + objective | `feasibility_opf.jl:build_feasibility!` |
| Residual extraction | `feasibility_opf.jl:extract_feasibility!` |
