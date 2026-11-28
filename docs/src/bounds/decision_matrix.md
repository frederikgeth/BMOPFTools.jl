# Objective risk: decision matrix and loss-maximizing objectives

A lookup for the question *"given my objective, my bounds, and my formulation — is the
problem well posed, which solution will I get, and can I trust it?"*, followed by the
objectives that quietly maximize losses and how to reformulate them. The reasoning
behind every entry is in [Bounds, Branches, and Feasibility](index.md).

!!! note "How to use this"
    - **Dataset authors:** find your intended objective and confirm the instance lands
      in a row that is ✓ under full operational limits before shipping.
    - **Validators:** this is the map of where your formulation *should* agree with the
      benchmark and where it is *expected* to diverge. Divergence inside a "✗ not
      physical" cell is not a bug in your code.

## Objective × bounds × formulation

Legend: ✓ = well behaved / exact / physical; ⚠ = conditional, verify;
✗ = ill posed / inexact / non-physical.

| Objective family | Bounded? (no op. limits) | Bounded? (full op. limits) | Branch favored | Relaxation exactness (SOC/SDP) | Recommended model |
|---|:---:|:---:|---|:---:|---|
| **Min generation cost** (non-neg. coeffs) | ⚠ coercive only if strongly convex (e.g. strictly convex quadratic) | ✓ | High-voltage | ✓ under standard conditions | Relaxation, verify ex post |
| **Min losses / min slack power** | ⚠ bounded below but not attained: at fixed power, losses → 0 as all voltages rise; needs `v̄` | ✓ | High-voltage | ✓ | Relaxation |
| **Feasibility (constant objective)** | ✗ vacuous: every profile feasible, iterates drift (not "unbounded" — a constant objective can't be) | ✓ | Undetermined among feasible pts | ⚠ one-sided certificate only | Nonconvex or verified relaxation |
| **Min import from grid** | ⚠ as min losses: import → load as voltages rise; needs `v̄` | ✓ | High-voltage | ⚠ with dispatchable DER (drives local injection up → upper `v` bounds) | Relaxation, watch upper bounds |
| **Max Σ voltage magnitude** | ⚠ unbounded above without `v̄` | ✓ | High-voltage | ⚠ fails when upper `v` bounds bind | Relaxation, watch upper bounds |
| **Max PV / DER injection** | ✗ | ⚠ bounded but boundary-seeking | Drives to upper `v` bound | ✗ typically inexact | Nonconvex; see the [catalog](#loss-max-catalog) |
| **Max load served / loadability** | ✗ | ⚠ drives to the nose | Toward low-voltage / nose | ✗ inexact near collapse | Nonconvex + continuation |
| **Max transfer / ATC / interface flow** | ✗ | ⚠ boundary-seeking | Maximizes current | ✗ | Nonconvex |
| **Max export / feed-in** | ✗ | ⚠ | Reverse-flow current max | ✗ | Nonconvex |
| **Max storage throughput / arbitrage volume** | ✗ | ⚠ | Cycling-current max | ✗ (plus SoC-constraint inexactness) | Nonconvex |
| **Max reactive support / VAR injection** | ✗ | ⚠ boundary-seeking | Maximizes reactive current | ✗ | Nonconvex; reward constraint satisfaction instead |
| **Max revenue / profit** | ✗ | ⚠ | More generation & flow | ✗ | Nonconvex |
| **Min cost with a negative coefficient** | ✗ | ⚠ | Inverted → toward low-voltage | ✗ data-induced | Audit signs; nonconvex if real |

!!! warning "The columns are not independent — and none of them is a certificate"
    "Bounded," "branch," and "exact" are three readings of one underlying property
    (see [§5](index.md)). A row that is ✗ on
    exactness is almost always boundary-seeking and low-voltage-leaning too. The
    family at the top — objectives non-decreasing in generation/losses — is ✓ in
    every column once voltage bounds are present, for the same reason.

    The "branch favored" column records which branch an objective *pulls toward*,
    not which branch a local solver will return. Confirm the sheet a solve actually
    landed on with the [diagnostics](diagnostics.md); a ✓ row is a reason to
    expect an operational answer, not evidence that you got one.

## [Objectives that imply loss maximization](@id loss-maximization)

Several objectives that read as maximizing something *desirable* are, mechanically,
maximizing line losses or branch current. On a convex relaxation that breaks exactness;
on the nonconvex model it drags the solution toward the low-voltage branch. This
section is the catalog, with safe reformulations.

### The one test

An objective **non-decreasing in every nodal generation — equivalently, in line losses**
is an important *objective-side* hypothesis in relaxation-exactness and
high-voltage-selection results ([Low, 2014](https://doi.org/10.1109/TCNS.2014.2323634);
[Gan et al., 2015](https://arxiv.org/abs/1311.7170);
[Yuan & Paolone, 2020](https://arxiv.org/abs/1906.06105)). It is not sufficient on its
own — the theorems additionally assume radiality, non-binding upper voltage bounds, and
no binding generator lower bounds (or permitted load over-satisfaction) — but it is the
condition the objective *itself* controls, so it is the one to screen for. For any
objective not on the safe list:

!!! tip "Self-diagnosis"
    At fixed loads and topology, **does the optimizer prefer larger branch current
    anywhere — or does its optimum sit where an upper voltage bound binds?** If either
    is yes, audit relaxation exactness and voltage-sheet selection explicitly.

### [The catalog](@id loss-max-catalog)

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

### Borderline and safe cases

- **Maximize $\sum_i |V_i|$.** Counterintuitively this is usually loss-*reducing* and
  often favors a high-voltage branch under the cited radial assumptions. It can
  drive into binding **upper** voltage bounds, which is a separate exactness-failure
  mode — the non-binding-upper-voltage-bound hypothesis of the radial exactness theorem
  ([Gan et al., 2015](https://arxiv.org/abs/1311.7170)). Outside those assumptions,
  verify the selected sheet and relaxation tightness rather than assuming either.

- **Minimize generation / min slack power / min cost (non-negative coeffs).** The
  canonical safe family. Because slack power $=$ losses $+$ net load, minimizing it
  *is* loss minimization *when the other injections are fixed* — which is exactly why a
  feasibility problem is so often turned into min-slack to make it well posed and
  branch-favorable ([§5](index.md)). With other dispatchable generators free, min-slack
  minimizes losses plus their output, which can drive local injection against upper
  voltage bounds; see the min-import row of the [decision matrix](#Objective-bounds-formulation) above.



## Formulation cross-cut

The table's exactness column assumes a single-phase, radial-or-mild-mesh setting. Adjust
as follows:

- **Linear approximations** (LinDistFlow, network/DC): always bounded and convex given
  bounds; never "inexact" in the relaxation sense, but they cannot represent collapse or
  branch multiplicity at all. Use for screening, not for any question on this page.
- **Convex relaxations** (SOC-BFM/BIM, SDP): the exactness column applies. On
  **meshed** networks the radial guarantees weaken; on **multiphase / unbalanced**
  networks treat all ✓ as ⚠ and verify
  ([Bernstein et al., 2018](https://doi.org/10.1109/TPWRS.2018.2823277)).
- **Nonconvex AC**: no exactness question, but every ✗/⚠ row can still converge to a
  low-voltage or locally optimal solution depending on the start point. Use a
  high-voltage (flat or warm) start and check the [diagnostics](diagnostics.md).

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Diagnosing a formulation](diagnostics.md) ·
[Trusting the solver](solver_trust.md) · [References](references.md)
