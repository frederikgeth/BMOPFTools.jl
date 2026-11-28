# Known Traps

A gallery of small instances that *exhibit* each pathology from
[Bounds, Branches, and Feasibility](index.md). Each entry states what it demonstrates,
a minimal construction, the expected behavior per formulation, and what to look for. A
validator can use these as targeted tests: *"give me the input that should expose my
bug."*

## Trap 1 — Unbounded without bounds

**Shows:** [§1](index.md) — a
non-coercive objective over a non-compact set has no optimum.

**Construction:** any feeder, remove voltage magnitude bounds and generator limits, set
a *linear* objective (e.g. minimize a single weighted injection, or maximize
$\sum |V_i|$).

**Expected behavior:**

| Formulation | Outcome |
|---|---|
| Linear | unbounded (`DUAL_INFEASIBLE`) |
| SOC / SDP relaxation | unbounded |
| Nonconvex AC | unbounded or solver failure (`NORM_LIMIT`-class) |

**Look for:** after the bound-everything recipe ([Diagnostics §1](diagnostics.md)),
voltage magnitudes pinned at the artificial bound. *Adding $\underline v,\overline v$
alone makes it finite.*

*In BMOPFTools:* start from an augmented feeder and strip its voltage/generator bounds —
the inverse of the [case augmentation](../augmentation.md) step.

## Trap 2 — Branch multiplicity (high vs low voltage)

**Shows:** [§2](index.md) —
"square" is not "unique."

**Construction:** the two-bus system of §2 — source $E = 1.0\angle 0$, lossless
reactance $X$, constant-power load $P + jQ$ chosen so the radicand
$\tfrac{E^4}{4} - X^2P^2 - XE^2Q$ is positive. A light load gives widely separated
roots; as the load approaches the nose the radicand shrinks and the two roots
converge.

**Expected behavior:** for a light load, two real AC solutions $V_+ \approx 1$ p.u.
and $V_- \ll 1$ p.u.; an exact relaxation and a high-voltage-started nonconvex solve both
return $V_+$; a flat-but-low or adversarially started Newton solve can land on $V_-$.

**Look for:** different solutions from different starts ⇒ multiplicity. The low-voltage
cluster is the tell ([Diagnostics §4](diagnostics.md)).

*In BMOPFTools:* OPF test **T1** ([Validating the OPF](../validation.md)) solves the
high-voltage root `V = (V_s + √(V_s² − 4RP))/2` of the resistive analog of this
quadratic; a low-`R/X`
reactive variant loaded toward the nose exposes the second root.

## Trap 3 — Relaxation feasible *past* collapse

**Shows:** [§3](index.md)
and [§4](index.md) — a relaxation
enlarges the feasible set beyond the true AC boundary, so it can certify feasibility for
a loading the network cannot serve.

**Construction:** the two-bus, one-generator characterization of
[Kocuk, Dey & Sun (2016)](https://doi.org/10.1109/TPWRS.2015.2402640). Pick a
load just beyond the nose (radicand $< 0$).

**Expected behavior:**

| Formulation | Outcome |
|---|---|
| Nonconvex AC | infeasible (no real solution past the nose) |
| SOC / SDP relaxation | **may report feasible / "optimal"** — non-physical |

**Look for:** relaxation `OPTIMAL` while the AC solve is `LOCALLY_INFEASIBLE`; large
per-branch cone gap ([Diagnostics §3](diagnostics.md)). This is the headline reason a
feasible relaxation is only a one-sided certificate.

*In BMOPFTools:* check the AC side with [`solve_feasibility_opf`](@ref) — a
repeatable non-zero `total_slack_magnitude_A` is evidence consistent with the
analytically predicted collapse, not by itself a global infeasibility certificate.

## Trap 4 — Loss-maximizing objective breaks exactness

**Shows:** [§5](index.md) and the
[loss-maximization list](loss_maximization.md) — an objective that rewards current makes
the relaxed $\ell_{ij}$ slack.

**Construction:** a small radial feeder with DER; objective = **maximize PV injection**
(or maximize export), full bounds, SOC-BFM.

**Expected behavior:** the SOC solution reports inflated currents; the cone gap
$\ell_{ij} - |S_{ij}|^2/v_i$ is strictly positive on loaded branches;
`primal_feasibility_report` against the AC model is non-empty. Switching the objective to
*maximize injection net of losses* restores exactness.

**Look for:** positive cone gaps concentrated where upper voltage bounds bind
([Diagnostics §3](diagnostics.md)).

*In BMOPFTools:* adapt a radial DER feeder from the
[DER placement tutorial](../tutorial_ders.md).

## Trap 5 — Generator lower bounds break exactness

**Shows:** the standard escape-hatch conditions in
[§5](index.md) — exactness proofs often assume *no
generator lower bounds* or *load over-satisfaction*; reintroducing a lower bound can make
the relaxation inexact, exact, or feasible-while-AC-infeasible
([Kocuk, Dey & Sun, 2016](https://doi.org/10.1109/TPWRS.2015.2402640)).

**Construction:** the same two-bus, one-generator system with a binding
$\underline{P}^g > 0$; sweep the lower bound to move between the three outcomes.

**Expected behavior:** a single small instance reproduces all three approximation
outcomes as the lower bound varies — a compact regression test for any relaxation
implementation.

**Look for:** the outcome flipping as a single parameter sweeps; tabulate cone gap vs
$\underline{P}^g$.

*In BMOPFTools:* as Trap 3, sweeping the binding $\underline{P}^g > 0$.

Traps 1–5 are *formulation / physics* traps. Traps 6–9 are *numerical* traps — failure
modes of a correct model on a local solver, the subject of
[Trusting the solver](solver_trust.md).

## Trap 6 — Degenerate duals from an over-determined bus

**Shows:** [Trusting the solver §4](solver_trust.md) — a constraint-qualification (LICQ)
failure leaves the multipliers non-unique without corrupting the primal point.

**Construction:** any feeder; add a generator pinned to a single operating point
($\underline P^g = \overline P^g$) at a bus whose voltage is fixed by a hard equality
(a source-like / regulated bus). Equivalently, give two same-bus generators identical cost
coefficients, or a single generator a zero cost vector.

**Expected behavior:** `LOCALLY_SOLVED` with a sane primal dispatch but **non-unique or
blown-up duals**; convergence is slow; a zero-cost generator (non-coercive objective) can
even surface as diverging iterates (`NORM_LIMIT`). The *dispatch* is unaffected — re-solving
from a second start returns the same primal point with different multipliers.

**Look for:** large / start-dependent shadow prices; many iterations for a small problem;
a primal point that is stable across starts while duals are not.

*In BMOPFTools:* the benchmark-readiness flags `W.BENCH.GEN_NO_DOF`,
`W.BENCH.GEN_ZERO_COST`, and `W.BENCH.GEN_DEGENERATE_COST`
([Methodology](../methodology.md)) screen for these structures *before* you solve.
They are screening signals, not proofs: losses can still pin the dispatch, and
equal costs alone do not establish non-uniqueness. Reproduce by augmenting a feeder
with a zero-cost or pinned generator, reading the flag, and comparing duals across
starts.

## Trap 7 — Zero-voltage bifurcation / spurious all-zero solution

**Shows:** [Trusting the solver §5–§6](solver_trust.md) — at zero voltage the bilinear
power map's Jacobian rank drops and an all-zero voltage profile becomes feasible
($S = 0$ for *any* current).

**Construction:** an ungrounded or islanded sub-network; remove the strictly positive
voltage floor (allow $|V| \ge 0$). The constant-power equation $p = v_r c_r + v_i c_i$
then admits $v_r = v_i = 0$ with the current free.

**Expected behavior:** a sub-network collapses toward $\sim 0$ V with indeterminate
currents; Ipopt churns in restoration or returns a physically meaningless point.

**Look for:** a cluster of terminals at near-zero voltage with large or arbitrary currents;
restoration thrash that clears the moment a positive floor is restored.

*In BMOPFTools:* strip the positive voltage floor to reproduce. The feasibility OPF
keeps whatever voltage bounds the case declares and relaxes only nodal current
balance, so it excludes the low-voltage branch only when the case declares a positive
floor; with no `v_min` there is none (see the
[infeasibility diagnosis tutorial](../tutorial_infeasibility.md)).

## Trap 8 — Non-smooth ZIP exponent near zero voltage

**Shows:** [Trusting the solver §5](solver_trust.md) — a fractional-exponent load model is
genuinely non-smooth as voltage → 0, with an unbounded Hessian.

**Construction:** a load with an exponential model $P \propto (W/V_{\text{nom}}^2)^{\gamma/2}$,
$\gamma < 2$ (or a ZIP constant-current term $s = \sqrt{W}$), and $W = v_r^2 + v_i^2$
allowed to approach zero.

**Expected behavior:** exploding Lagrangian-Hessian entries, vanishing step sizes, and
Ipopt churning in its `Restoration` phase as the argument nears zero.

**Look for:** tiny steps and growing curvature reported in the Ipopt log on a feeder that
should be easy; the symptom disappears when $W$ is floored away from zero.

*In BMOPFTools:* a voltage-dependent load never evaluates a fractional power near
zero voltage. When a positive lower voltage bound is stamped on the coil, $W$ (and
$s$) get the lower bound $W \ge (v_{\min}/2)^2$; without one, the load is written in
the log-voltage variable $\ell = \log(|\Delta V|/V_{\text{nom}})$, which has no
zero-voltage point at all (see [Loads](../opf.md#Loads)). The trap therefore
reproduces only in your own formulation, written directly in $W$ without a floor.

## Trap 9 — Redundant constraint breaks LICQ everywhere

**Shows:** [Trusting the solver §4](solver_trust.md) — an equation already implied by the
others adds no information but makes the active-constraint gradients linearly dependent at
*every* feasible point, not just on a measure-zero set.

**Construction:** any feeder solving cleanly; add an explicit system-wide power-balance
constraint $\sum_g S^g = \sum_d S^d + \text{losses}$ on top of full per-terminal KCL.
Because summing the nodal balances already yields this identity, the added row is a linear
combination of the KCL rows.

**Expected behavior:** the problem is mathematically unchanged but the KKT system is
singular along the redundant direction; Ipopt stalls with non-unique multipliers or
terminates with diverging iterates (`NORM_LIMIT`), even though the primal dispatch (if it
converges) is fine.

**Look for:** a model that was well posed becomes ill-conditioned the moment a
"sanity-check" equality is added; removing that one constraint restores a clean solve.
Smaller instances: a voltage-magnitude pin on an already-fixed reference bus, or a second
ground on a neutral the source already fixes to zero.

*In BMOPFTools:* the slack *source* already closes the system, so a global power balance is
never required — adding one reproduces the trap; deleting it is the fix. Classical
transmission OPF drops the slack-bus balance for the same reason
([cycle-flow formulations](https://arxiv.org/abs/1704.01881)).

## Suggested test matrix

For a formulation under validation, the minimal coverage is one instance per trap:

| Trap | Property tested | Pass criterion |
|---|---|---|
| 1 | Well-posedness / bounds | unbounded without bounds, finite with them |
| 2 | Branch selection | high-voltage solution recovered from a sane start |
| 3 | One-sided certificate | AC-infeasible past nose; relaxation gap detected |
| 4 | Objective monotonicity | exact under loss-min; inexact (detected) under loss-max |
| 5 | Exactness escape hatches | three outcomes reproduced across a bound sweep |
| 6 | Constraint qualification | primal stable across starts; duals non-unique under pinning |
| 7 | Zero-voltage degeneracy | spurious all-zero / indeterminate-current point with no floor |
| 8 | Load-model smoothness | restoration churn without a $W$ floor; clean solve with one |
| 9 | No redundant constraints | adding a KCL-implied equality breaks the solve; removing it restores it |

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Decision matrix](decision_matrix.md) ·
[Objectives that imply loss maximization](loss_maximization.md) ·
[Diagnostics & validation](diagnostics.md) ·
[Trusting the solver](solver_trust.md) · [References](references.md)
