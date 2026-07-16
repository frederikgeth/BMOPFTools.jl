# Objectives That Imply Loss Maximization

Several objectives that read as maximizing something *desirable* are, mechanically,
maximizing line losses or branch current. On a convex relaxation that breaks exactness;
on the nonconvex model it drags the solution toward the low-voltage branch. This page is
the catalogue, with safe reformulations.

## The one test

An objective **non-decreasing in every nodal generation — equivalently, in line losses**
is the *objective-side* condition for a relaxation to stay exact and for the nonconvex
problem to stay on the high-voltage branch ([Low, 2014](https://doi.org/10.1109/TCNS.2014.2323634);
[Gan et al., 2015](https://arxiv.org/abs/1311.7170);
[Yuan & Paolone, 2020](https://arxiv.org/abs/1906.06105)). It is not sufficient on its
own — the theorems additionally assume radiality, non-binding upper voltage bounds, and
no binding generator lower bounds (or permitted load over-satisfaction) — but it is the
condition the objective *itself* controls, so it is the one to screen for. For any
objective not on the safe list:

!!! tip "Self-diagnosis"
    At fixed loads and topology, **does the optimizer prefer larger branch current
    anywhere — or does its optimum sit where an upper voltage bound binds?** If either
    is yes, expect relaxation inexactness and drift toward the low-voltage solution.

## The catalogue

| Objective as written | Why it rewards loss / current | Safer reformulation |
|---|---|---|
| **Max PV/DER injection**, max renewable dispatch, naive hosting capacity | Surplus injection becomes reverse flow → $I^2 r$, and pushes voltages up until the **upper** bound binds — the regime where SOC/SDP exactness is known to fail | Maximize injection *net of losses*; or fix injection and solve feasibility; or penalize curtailment instead of rewarding injection — then verify exactness |
| **Max total load served / loadability / demand delivered** | Drives straight to the nose; the loadability limit *is* the collapse point | Parametrize load, minimize cost/loss at each level; for true loadability use the nonconvex model + continuation |
| **Max power/energy transfer, ATC, interface flow** | Directly maximizes branch current → $I^2 r$ | Bound transfer as a *constraint*; study maximum transfer only in the nonconvex model |
| **Max export to grid / feed-in / "self-sufficiency" via export** | Reverse-flow current maximization | Recast as **minimize net cost / minimize net import** |
| **Max storage throughput / arbitrage volume / EV energy delivered** | Rewards cycling current; the linear charge/discharge constraints add their own documented inexactness | Minimize cost *including losses*; bound throughput as a constraint |
| **Max reactive support / VAR injection** | Reactive current also dissipates $I^2 r$ | Minimize losses subject to voltage constraints; reward constraint satisfaction, not raw $Q$ |
| **Min cost with a negative cost coefficient** (subsidy, feed-in tariff as negative cost) | The *form* is the safe one, but a negative coefficient inverts monotonicity, so min-cost silently becomes max-generation → loss-max. The trap is in the **data**, not the objective | Audit the sign of every cost term; if negative prices are real, switch to the nonconvex model and do not trust the relaxation |
| **Max revenue / profit** (price × output) | Rewards more generation and flow | As above — minimize net cost instead |

!!! warning "The asymmetry to remember"
    *Minimize import* is loss-aligned and safe. *Maximize export* is not — even though
    both sound like "less reliance on the grid." Direction of the optimization, not the
    English description, is what determines the monotonicity.

!!! note "This is a tested behaviour, not just a caution"
    The negative-coefficient row is exercised directly in the OPF suite: test **T4**
    ([Validating the OPF](../validation.md)) gives a generator a *negative* cost
    coefficient and confirms the optimum drives each phase to `p_max` with
    `objective = −3·P_max/1000` (\$/h, with `P_max` in W) — i.e. min-cost has
    silently become max-generation. If your
    own formulation reproduces that number, it is reproducing the trap, not a bug.

## Two that look risky but are mostly fine

- **Maximize $\sum_i |V_i|$.** Counterintuitively this is usually loss-*reducing* and
  correctly selects the high-voltage branch. The residual risk is different: it can
  drive into binding **upper** voltage bounds, which is a separate exactness-failure
  mode — the non-binding-upper-voltage-bound hypothesis of the radial exactness theorem
  ([Gan et al., 2015](https://arxiv.org/abs/1311.7170)). Safe for branch selection; watch
  the ceiling for relaxation tightness.

- **Minimize generation / min slack power / min cost (non-negative coeffs).** The
  canonical safe family. Because slack power $=$ losses $+$ net load, minimizing it
  *is* loss minimization *when the other injections are fixed* — which is exactly why a
  feasibility problem is so often turned into min-slack to make it well posed and
  branch-correct ([§5](index.md)). With other dispatchable generators free, min-slack
  minimizes losses plus their output, which can drive local injection against upper
  voltage bounds; see the min-import caveat in the [decision matrix](decision_matrix.md).

## When loss-maximizing is the actual research question

Maximum loadability, voltage-stability margin, and worst-case transfer are legitimate
questions — they are *deliberately* boundary-seeking. The point is not to avoid them but
to model them correctly:

!!! note
    Solve these in the **nonconvex AC** model (optionally with a continuation /
    margin formulation) — for BMOPFTools that is [`solve_opf`](../opf.md) — not in a
    relaxation. *No* relaxation is a valid feasibility certificate in this regime,
    including any you reach via [`to_pmd`](../conversion.md): a relaxation will happily
    report an "optimal" loadability past the true collapse point. See
    [Known traps](known_traps.md) for runnable instances that exhibit this.

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Decision matrix](decision_matrix.md) · [Diagnostics & validation](diagnostics.md) ·
[Trusting the solver](solver_trust.md) · [References](references.md)
