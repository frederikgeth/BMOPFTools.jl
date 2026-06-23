# Diagnostics & Validation

How to *detect* the failure modes from
[Bounds, Branches, and Feasibility](index.md), rather than merely avoid them. This page
is aimed at the validation audience: you are checking your own linear, convex, or
nonconvex formulation against the benchmark and need to know what to measure and what a
discrepancy means.

The throughline: two well-known generic optimization tools become your two
domain-specific diagnostics. *Bound everything and see what binds* is the unboundedness
test of [§1](index.md); evaluating a
relaxed solution against the AC equations is the exactness test of
[§5](index.md).

!!! tip "BMOPFTools-native shortcuts"
    The JuMP recipes below apply to *your* model. Two of these diagnostics already exist
    inside this package, and you should reach for them first:

    - **AC-feasibility of a candidate point** (Symptom 3) is exactly what
      [`solve_feasibility_opf`](../validation.md) measures: it adds an elastic slack
      current at every non-source terminal and minimises its norm, so a returned
      `total_slack_magnitude_A` ≈ 0 certifies the point satisfies every KCL/KVL and
      component-model equation. This is the native, four-wire analogue of
      `primal_feasibility_report` against the AC model.
    - **Ill-posedness *before* you solve** — flat objectives, free injections, and
      cost degeneracy — is caught structurally by the benchmark-readiness flags
      (`W.BENCH.GEN_ZERO_COST`, `W.BENCH.GEN_DEGENERATE_COST`, `W.BENCH.GEN_NO_DOF`;
      see [Methodology § Benchmark readiness](../methodology.md)). A `DUAL_INFEASIBLE`
      from a zero-cost generator is the runtime echo of `W.BENCH.GEN_ZERO_COST`.

## Symptom 1 — `INFEASIBLE_OR_UNBOUNDED` / `DUAL_INFEASIBLE`

First, **disambiguate**. Unboundedness can only come from the objective, so drop it and
re-solve ([YALMIP](https://yalmip.github.io/infeasibleorunbounded);
[JuMP](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/debugging/)):

```julia
@objective(model, Min, 0)   # feasibility test
optimize!(model)
# feasible now  ⇒ original was UNBOUNDED
# infeasible now ⇒ original was (also) INFEASIBLE
```

Then **localize the unboundedness**. Add large finite bounds to every free or
one-sided variable, re-solve, and inspect which variables sit at the artificial bound —
those are your unbounded directions:

```julia
for v in all_variables(model)
    has_lower_bound(v) || set_lower_bound(v, -1e6)
    has_upper_bound(v) || set_upper_bound(v,  1e6)
end
optimize!(model)
for v in all_variables(model)
    if isapprox(value(v), 1e6; atol=1) || isapprox(value(v), -1e6; atol=1)
        @info "at artificial bound" v value(v)
    end
end
```

In a power-flow model the variables pinned at the artificial bound are almost always
voltage magnitudes (missing $\underline v$ / $\overline v$) or an unbounded generator —
i.e. exactly the missing operational limits from §1. Erwin Kalvelagen's variant — bind
the objective to a large-bounded auxiliary variable via an equality, then read its value
— is the same idea
([the canonical infeasible/unbounded writeup](http://yetanothermathprogrammingconsultant.blogspot.com/2018/08/the-best-way-to-debug-infeasible-models.html)).

## Symptom 2 — model is infeasible and you do not know why

Use an irreducible infeasible subsystem (IIS) if your solver supports it:

```julia
compute_conflict!(model)
if get_attribute(model, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
    iis, _ = copy_conflict(model)
    print(iis)
end
```

When no IIS is available, the **penalty relaxation** locates the binding constraints by
letting them be violated at a cost:

```julia
map = relax_with_penalty!(model)   # adds slacks + penalty to the objective
optimize!(model)
for (con, slack) in map
    value(slack) > 1e-6 && @info "violated" con value(slack)
end
```

!!! warning "Distinguish modeling infeasibility from physical infeasibility"
    `relax_with_penalty!` does **not** relax variable bounds or integrality. More
    important here: in a constant-power model an infeasibility may be *physical* — you
    are past the loadability / collapse boundary
    ([§4](index.md)), not
    mis-modeled. If the IIS centres on the power-balance and voltage-bound constraints
    of a heavily loaded sub-network, suspect collapse, and confirm with a continuation
    sweep rather than editing constraints.

## Symptom 3 — is my relaxation exact? (the central validation check)

Evaluate the relaxed solution against the **nonconvex AC** constraints and read off the
violation. JuMP's
[`primal_feasibility_report`](https://jump.dev/JuMP.jl/stable/manual/solutions/) does
this against any model:

```julia
# Solve the relaxation, then test its point against the AC model:
report = primal_feasibility_report(ac_model, Dict(v => value(v) for v in all_variables(relaxed_model)))
isempty(report) ? @info("AC-feasible: relaxation exact") :
                  @info("AC-infeasible: relaxation INEXACT", report)
```

In BMOPFTools the same check is available natively for a four-wire network: pin the
candidate dispatch into the case and call [`solve_feasibility_opf`](../validation.md),
which minimises an injected slack current. A near-zero slack certifies the point is a
valid AC power flow; a non-zero slack is the violation, localised to the terminals
where it concentrates:

```julia
res     = solve_feasibility_opf(net; optimizer = Ipopt.Optimizer)
slack_A = res["total_slack_magnitude_A"]
slack_A < 1e-3 ? @info("AC-feasible: candidate is a valid power flow") :
                 @info("AC-infeasible: relaxation/candidate INEXACT", slack_A)
```

For the branch-flow relaxation you can also read the gap directly per branch:

```math
\text{gap}_{ij} \;=\; \ell_{ij} \;-\; \frac{|S_{ij}|^2}{v_i}\,,
```

which is $\approx 0$ on every branch when exact and strictly positive where the cone is
slack. For the SDP / BIM relaxation, check the per-clique voltage matrix **rank** (or
the ratio of the two largest eigenvalues): a rank-1 matrix (eigenratio $\to \infty$,
second eigenvalue $\to 0$) means exact
([Lupien & Lesage-Landry, 2023](https://arxiv.org/abs/2311.07781)).

!!! tip "Where to expect inexactness"
    Empirically the relaxation goes inexact precisely when **upper voltage bounds bind**
    and their duals exceed a threshold — and exact solutions reliably show **binding
    upper bounds on active/reactive withdrawals** instead
    ([Gan et al., 2015](https://arxiv.org/abs/1311.7170);
    [Bobo et al., 2020](https://arxiv.org/abs/2001.00898)). If your validation
    diverges from the benchmark, check whether you are in a loss-rewarding objective
    ([list](loss_maximization.md)) or against an upper voltage bound first.

## Symptom 4 — I think I am on the wrong (low-voltage) branch

A nonconvex solver can converge to the low-voltage solution, especially under a
loss-rewarding objective or a poor start. Checks:

- **Voltage profile.** Operational solutions sit near $1$ p.u.; a solution with a
  cluster of buses well below $\underline v$-class values (e.g. $0.5$–$0.8$ p.u.) on a
  normally loaded feeder is the low-voltage branch.
- **Restart from a high-voltage start.** Flat start or warm-start from a linear-model
  solution; the high-voltage solution is the one fixed-point and relaxation methods
  converge to ([Dvijotham et al., 2017](https://arxiv.org/abs/1706.05290)). If the two
  starts give different solutions, you have multiplicity.
- **Cross-solver / cross-formulation.** Solve the relaxation too; if it is exact, its
  (unique, global) solution is the high-voltage one and is the reference your nonconvex
  solution should match
  ([§2](index.md)).

## Validation checklist against the benchmarks

1. Reproduce the benchmark's reported objective with **your** formulation and the
   **same** objective and bounds.
2. If you use a relaxation, run Symptom 3 and confirm exactness; only compare the value
   if exact.
3. If values differ, classify before debugging code: is the row in the
   [decision matrix](decision_matrix.md) a ✗ cell? Is the objective on the
   [loss-maximization list](loss_maximization.md)? Are upper voltage bounds binding?
   Expected divergence is not a bug.
4. For collapse/loadability instances, compare margins from a continuation sweep, not
   single-point objective values.

## See also — general optimization-debugging guides

Model debugging is an established craft, not specific to this library:

- [JuMP — Debugging tutorial](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/debugging/)
  and [Solutions / infeasibility certificates](https://jump.dev/JuMP.jl/stable/manual/solutions/).
- [Kalvelagen — "The best way to debug infeasible models"](http://yetanothermathprogrammingconsultant.blogspot.com/2018/08/the-best-way-to-debug-infeasible-models.html).
- [YALMIP — Infeasible or unbounded](https://yalmip.github.io/infeasibleorunbounded) and
  [Debugging unbounded models](https://yalmip.github.io/debuggingunbounded).
- [GAMS — Execution errors & performance](https://www.gams.com/latest/docs/UG_ExecErrPerformance.html)
  (the most complete cross-tool treatment).
- [Pyomo — Model debugging](https://pyomo.readthedocs.io/en/stable/model_debugging/index.html).
- [AIMMS — Debug infeasible or unbounded results](https://how-to.aimms.com/Articles/136/136-Infeasible-Unbounded.html).

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Decision matrix](decision_matrix.md) ·
[Objectives that imply loss maximization](loss_maximization.md) ·
[Known traps](known_traps.md) · [References](references.md)
