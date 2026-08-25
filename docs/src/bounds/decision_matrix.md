# Decision Matrix

A lookup table for the question *"given my objective, my bounds, and my formulation —
is the problem well posed, which solution will I get, and can I trust it?"* Read the
prose reasoning behind every entry in
[Bounds, Branches, and Feasibility](index.md).

!!! note "How to use this"
    - **Dataset authors:** find your intended objective and confirm the instance lands
      in a green row before shipping.
    - **Validators:** this is the map of where your formulation *should* agree with the
      benchmark and where it is *expected* to diverge. Divergence inside a "✗ not
      physical" cell is not a bug in your code.

## Objective × bounds × formulation

Legend: ✓ = well behaved / exact / physical; ⚠ = conditional, verify;
✗ = ill posed / inexact / non-physical.

| Objective family | Bounded? (no op. limits) | Bounded? (full op. limits) | Branch favoured | Relaxation exactness (SOC/SDP) | Recommended model |
|---|:---:|:---:|---|:---:|---|
| **Min generation cost** (non-neg. coeffs) | ⚠ coercive only if strongly convex (e.g. strictly convex quadratic) | ✓ | High-voltage | ✓ under standard conditions | Relaxation, verify ex post |
| **Min losses / min slack power** | ✓ (coercive) | ✓ | High-voltage | ✓ | Relaxation |
| **Feasibility (constant objective)** | ✗ vacuous: every profile feasible, iterates drift (not "unbounded" — a constant objective can't be) | ✓ | Undetermined among feasible pts | ⚠ one-sided certificate only | Nonconvex or verified relaxation |
| **Min import from grid** | ✓ | ✓ | High-voltage | ⚠ with dispatchable DER (drives local injection up → upper `v` bounds) | Relaxation, watch upper bounds |
| **Max Σ voltage magnitude** | ⚠ unbounded above without `v̄` | ✓ | High-voltage | ⚠ fails when upper `v` bounds bind | Relaxation, watch upper bounds |
| **Max PV / DER injection** | ✗ | ⚠ bounded but boundary-seeking | Drives to upper `v` bound | ✗ typically inexact | Nonconvex; see [list](loss_maximization.md) |
| **Max load served / loadability** | ✗ | ⚠ drives to the nose | Toward low-voltage / nose | ✗ inexact near collapse | Nonconvex + continuation |
| **Max transfer / ATC / interface flow** | ✗ | ⚠ boundary-seeking | Maximizes current | ✗ | Nonconvex |
| **Max export / feed-in** | ✗ | ⚠ | Reverse-flow current max | ✗ | Nonconvex |
| **Max storage throughput / arbitrage volume** | ✗ | ⚠ | Cycling-current max | ✗ (plus SoC-constraint inexactness) | Nonconvex |
| **Max revenue / profit** | ✗ | ⚠ | More generation & flow | ✗ | Nonconvex |
| **Min cost with a negative coefficient** | ✗ | ⚠ | Inverted → toward low-voltage | ✗ data-induced | Audit signs; nonconvex if real |

!!! warning "The columns are not independent — and none of them is a certificate"
    "Bounded," "branch," and "exact" are three readings of one underlying property
    (see [§5](index.md)). A row that is ✗ on
    exactness is almost always boundary-seeking and low-voltage-leaning too. The green
    family at the top — objectives non-decreasing in generation/losses — is green in
    every column for the same reason.

    The "branch favoured" column records which branch an objective *pulls toward*,
    not which branch a local solver will return. Confirm the sheet a solve actually
    landed on with the [diagnostics](diagnostics.md); a green row is a reason to
    expect an operational answer, not evidence that you got one.

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
[Objectives that imply loss maximization](loss_maximization.md) ·
[Diagnostics & validation](diagnostics.md) ·
[Trusting the solver](solver_trust.md) · [References](references.md)
