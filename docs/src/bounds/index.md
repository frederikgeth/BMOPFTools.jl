# Bounds, Branches, and Feasibility

Why an optimal power flow (OPF) needs bounds, what the objective silently decides
for you, and where these choices quietly break down near voltage collapse.

!!! note "How to read this page"
    This page is written so two audiences can share it.

    - **Building or curating a dataset?** Read the *Takeaway* box in each section and
      the [decision matrix](decision_matrix.md). Skip the collapsible
      *Derivation* blocks. Check your objective against the
      [loss-maximization list](loss_maximization.md) before you ship.
    - **Validating your own formulation against the benchmarks?** Read everything,
      expand the *Derivation* blocks, and then work through
      [Diagnostics & validation](diagnostics.md), the
      [Known traps](known_traps.md) gallery, and — once you have cleared those — the
      [Trusting the solver](solver_trust.md) capstone on how far to trust an
      `INFEASIBLE` or `LOCALLY_SOLVED` verdict.

    Every collapsible block titled **Derivation** or **Proof sketch** is safe to
    skip on a first read; nothing later depends on having expanded it.

## Scope: this is a formulation-aware discussion

!!! info "What BMOPFTools ships, and what this page is about"
    BMOPFTools ships a single reference optimizer — the **nonconvex four-wire IVR-EN**
    engine ([`solve_opf`](../opf.md), [`solve_feasibility_opf`](../validation.md)). It
    does **not** ship convex relaxations or linear approximations. This page is
    deliberately *formulation-agnostic*: it is written for anyone validating a linear,
    convex, or nonconvex formulation against the benchmarks — including formulations you
    bring yourself or reach through [`to_pmd`](../conversion.md) into
    PowerModelsDistribution. Where it discusses relaxation exactness, the relaxation is
    *yours* or the ecosystem's, not one supplied by this library.

Everything below behaves differently across the three families of model that the
benchmarks are meant to be solved with across the broader PowerModels ecosystem
([Coffrin et al., 2018](https://doi.org/10.23919/PSCC.2018.8442948);
[Fobes et al., 2020](https://arxiv.org/abs/2004.10081)):

1. **Nonconvex AC** (polar, rectangular, current–voltage). Exact physics, multiple
   solutions, local optima — and NP-hard to solve or even to test for feasibility, on
   radial feeders as much as on meshed grids
   ([Lehmann, Grastien & Van Hentenryck, 2016](https://doi.org/10.1109/TPWRS.2015.2407363);
   [Trusting the solver](solver_trust.md)). This is the family BMOPFTools' own engine
   implements.
2. **Convex relaxations** (second-order-cone branch-flow / bus-injection models, SDP).
   A single global optimum, but it equals an AC solution only when the relaxation is
   *exact*. Reached here via export to PMD or your own solver, not shipped in-package.
3. **Linear approximations** (LinDistFlow, network/DC-style models). Always convex and
   well behaved, but blind to the phenomena that motivate this page.

Multiconductor, unbalanced networks sharpen every caveat here: the uniqueness and
exactness guarantees available for balanced single-phase networks are weaker or absent
in the multiphase setting
([Bernstein et al., 2018](https://doi.org/10.1109/TPWRS.2018.2823277)). When in doubt
on an unbalanced feeder, assume the optimistic single-phase result does **not** carry
over.

## 1. Without bounds, the problem is not well posed

!!! tip "Takeaway"
    A power-flow model with free injections has a **non-compact** feasible set. An
    optimizer terminates only if the objective is **coercive** over that set — grows
    without limit in every unbounded direction. Most natural objectives are not, so
    the problem is unbounded. This is not a solver bug; it is the model. As the JuMP
    debugging guide puts it, an unbounded model almost always means a modeling error,
    *because all physical systems have limits*
    ([JuMP docs](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/debugging/)).

In the bus-injection model the state is the complex voltage vector $V \in \mathbb{C}^n$
and the injections are

```math
S_i = V_i \sum_{j} Y_{ij}^{*}\, V_j^{*}, \qquad i = 1,\dots,n .
```

If the injections $S_i$ are free (no generator limits) and the voltages $V_i$ are free
(no magnitude limits), then *every* voltage profile is feasible — the injections simply
adjust to match. The feasible set is all of $\mathbb{C}^n$: closed, but unbounded.

!!! details "Derivation: why an unbounded feasible set defeats the optimizer"
    Let $\mathcal{F}$ be the feasible set and $f$ the objective (minimization). A
    minimizer is guaranteed to exist when $\mathcal{F}$ is closed and $f$ is
    **coercive** on $\mathcal{F}$, i.e. $f(x)\to+\infty$ whenever $\|x\|\to\infty$ with
    $x\in\mathcal{F}$ (a Weierstrass-type argument: sublevel sets are compact).

    There are two independent ways this fails for an unconstrained power-flow model:

    - **State unboundedness.** Even on the power-flow manifold, $|V_i|$ can grow
      without limit. Nothing in the equations bounds it.
    - **Objective unboundedness.** With several free injections, $\mathcal{F}$ admits
      *unbounded feasible directions* — rays (or, on the nonconvex manifold, feasible
      paths) along which you can move forever. A linear objective $c^\top S$ decreases
      without bound along any such direction $d$ with $c^\top d < 0$. (Strictly, the
      "recession cone" language is exact for the convex relaxation of $\mathcal{F}$; on
      the manifold itself read it as an asymptotic feasible direction.)

    The practical consequence: "the problem is unbounded" is really the conjunction
    *non-compact feasible set* **and** *non-coercive objective*. Fixing either one
    repairs well-posedness. A *strongly* convex generation cost (a strictly convex
    quadratic, say — strict convexity alone is not enough: $e^{-x}$ is strictly convex yet
    bounded below with no minimizer) can be coercive in the injection coordinates and
    bound that part of the problem — yet still leave voltage magnitude free. This is why a
    cost objective alone does not save you: you must still bound the voltages.

The takeaway for dataset authors: a benchmark instance with no voltage bounds and a
non-coercive (e.g. linear, or loss-rewarding) objective is *ill-posed by construction*,
and a solver returning `DUAL_INFEASIBLE` / `INFEASIBLE_OR_UNBOUNDED` is reporting that
faithfully.

## 2. A single reference pins the system — but not the branch

!!! tip "Takeaway"
    Adding one voltage reference (slack) with all other buses as PQ makes the system
    **square** (determined), so solutions are isolated. But *square is not unique*.
    Constant-power loads generically admit a **high-voltage** (operational) and a
    **low-voltage** solution; meshed networks can admit many. Uniqueness of the
    high-voltage solution is a theorem only under loading/`R/X` conditions. The
    objective is what **selects** the physical branch — it is not a tie-breaker, it is
    the mechanism.

Fixing $V_1 = V^{\text{ref}}$ removes the reference degree of freedom; fixing $S_i$ at
every other bus closes the system. Counting real equations and unknowns gives a square
polynomial system, which generically has finitely many isolated solutions — not one.

!!! details "Derivation: the two-bus quadratic and the high/low branch"
    Take a source $E\angle 0$ feeding a load bus through a lossless reactance $X$, with
    the load *consuming* $P + jQ$ (load-positive convention). Writing
    $\delta = \theta_{\text{source}} - \theta_{\text{load}}$, the power-balance relations
    at the load bus are

    ```math
    P = \frac{EV}{X}\sin\delta, \qquad
    Q = \frac{EV}{X}\cos\delta - \frac{V^2}{X},
    ```

    where $V = |V_2|$. Eliminating $\delta$
    (square and add) gives a quadratic in $u = V^2$:

    ```math
    u^2 + \left(2QX - E^2\right)u + X^2\left(P^2 + Q^2\right) = 0,
    ```

    with roots

    ```math
    V^2 = \frac{E^2}{2} - QX \;\pm\; \sqrt{\frac{E^4}{4} - X^2 P^2 - X E^2 Q }.
    ```

    The two signs are the **high-voltage** and **low-voltage** solutions. Real
    solutions exist only while the radicand is non-negative; it vanishes at the
    **saddle-node / nose point** (Sections 4 and 5 below). This is the smallest example
    of the multiplicity that the term "unique solution" hides.

Uniqueness of the operationally meaningful (high-voltage) solution holds under explicit
parametric conditions — loading bounded away from the nose, conditions on the `R/X`
structure — established by
[Bolognani & Zampieri (2016)](https://doi.org/10.1109/TPWRS.2015.2395452),
[Simpson-Porco (2018), Parts I–II](https://arxiv.org/abs/1701.02045), and, for
distribution feeders,
[Wang et al. (2018)](https://doi.org/10.1109/TSG.2016.2572060).

The second half is the deeper and more useful fact, and it is why the objective matters
so much: on a **radial** network the high-voltage solution is *the last one to vanish as
the system is loaded toward its limit*, and the standard computational routes —
[fixed-point iteration, convex relaxation, and energy-function minimization — all return
exactly that solution if and only if one exists](https://arxiv.org/abs/1706.05290)
([Dvijotham, Mallada & Simpson-Porco, 2017](https://arxiv.org/abs/1706.05290), a radial
result). A voltage-maximizing / loss-minimizing objective is the lever that pins you to
the physical branch. On meshed and on multiphase/unbalanced networks this is an
*extrapolation*, not a theorem — see the caveat in the scope section above
([Bernstein et al., 2018](https://doi.org/10.1109/TPWRS.2018.2823277)).

!!! warning "Definition matters"
    "Single voltage source" here means **one** bus that fixes both angle and magnitude,
    with *every other bus PQ*. A PV / voltage-regulating bus keeps the system **square**
    — it swaps the reactive-balance equation for a magnitude specification — so the
    determined-system count still holds. What it *does* break is (a) the PQ-network
    uniqueness theorems cited below, whose hypotheses assume constant-power buses, and
    (b) smoothness: once a `Q`-limit is hit, the bus switches PV↔PQ, introducing a
    complementarity condition (and, in an OPF, a non-smooth active set) that the clean
    two-branch picture does not cover.

## 3. Bounds turn power flow into OPF — even as a feasibility problem

!!! tip "Takeaway"
    Operational limits — voltage box, thermal/ampacity, generator capability — make the
    feasible set compact and the question *"does an operating point exist?"* well posed.
    That question **is** an OPF feasibility problem (OPF with a constant objective).
    But beware: feasibility checked through a **relaxation** is only a one-sided
    certificate.

Once you impose $\underline{v}\le|V_i|\le\overline{v}$, branch limits
$|S_{ij}|\le\overline{S}_{ij}$, and generator capability
$\underline{S}^g\le S^g\le\overline{S}^g$, the feasible set becomes a compact
semialgebraic set. Finding any point in it is the OPF feasibility problem — equivalently
a load-flow-feasibility or restoration problem. The bounds are precisely what restored
well-posedness in Section 1.

!!! details "Proof sketch: relaxations certify infeasibility, not feasibility"
    Write the AC feasible set $\mathcal{F}_{\text{AC}}$ and a convex relaxation
    $\mathcal{F}_{\text{rel}}$. By construction a relaxation enlarges the feasible set:

    ```math
    \mathcal{F}_{\text{AC}} \subseteq \mathcal{F}_{\text{rel}} .
    ```

    Therefore:

    - $\mathcal{F}_{\text{rel}} = \varnothing \;\Rightarrow\;
      \mathcal{F}_{\text{AC}} = \varnothing$ — relaxation infeasibility is a **valid
      certificate** of AC infeasibility.
    - $\mathcal{F}_{\text{rel}} \neq \varnothing \;\not\Rightarrow\;
      \mathcal{F}_{\text{AC}} \neq \varnothing$ — a feasible relaxation says nothing,
      on its own, about AC feasibility.

    [Kocuk, Dey & Sun (2016)](https://doi.org/10.1109/TPWRS.2015.2402640) show
    that even a two-bus, one-generator system can exhibit all three outcomes: the SDP
    relaxation can be exact, inexact, or **feasible while the OPF instance is
    infeasible**. This is the hinge into the next section.

## 4. The feasibility boundary is the collapse manifold

!!! tip "Takeaway"
    With constant-power (nonlinear) loads, the **edge of the AC feasible region is the
    voltage-collapse / loadability boundary**. To *study* collapse you must not impose a
    voltage lower bound that clips the low-voltage branch — but then you forfeit the
    compactness of Section 3 and reopen the branch-selection problem of Section 2.
    Relaxations enlarge the feasible set *past* the true boundary, so they cannot
    certify operability near collapse.

Voltage collapse is a saddle-node bifurcation: the high- and low-voltage solutions
coalesce and disappear at the nose, and the power-flow Jacobian is singular there
([Dobson & Lu, 1993](https://doi.org/10.1109/59.260912);
[Simpson-Porco, Dörfler & Bullo, 2016](https://doi.org/10.1038/ncomms10790)). In the
two-bus system, beyond the nose the AC equations have **no real solution** — genuine
infeasibility; in a network it is the coalescing high/low pair that vanishes along the
loading ray (other, more remote solution branches may persist, but not the operational
one). So with constant-power loads, feasibility silently encodes the stability limit.

!!! warning "Collapse is not exactly the nose, once loads are voltage-dependent"
    The saddle-node point coincides with the maximum-power (nose) point only for pure
    constant-power loads. With ZIP / voltage-dependent loads the saddle-node bifurcation
    can occur away from the nose, so the **static** power-flow feasibility boundary is
    only a *proxy* for the actual stability limit, and the proxy degrades as load models
    become more voltage-sensitive (see
    [Van Cutsem & Vournas, 1998](https://doi.org/10.1007/978-0-387-75536-6) for the
    canonical treatment). Continuation power flow traces the full P–V curve through the
    nose and is the right tool when the margin itself is the question.

!!! details "Derivation: what a voltage lower bound does to the branches"
    Return to the two-bus quadratic of Section 2. The high- and low-voltage roots are

    ```math
    V^2_{\pm} = \frac{E^2}{2} - QX \pm \sqrt{\;\underbrace{\tfrac{E^4}{4} - X^2 P^2 - X E^2 Q}_{\text{radicand }\rho}\;}.
    ```

    - $\rho > 0$: two solutions (operational $V_+$, collapsed $V_-$).
    - $\rho = 0$: the saddle-node — a single double root; the loadability limit.
    - $\rho < 0$: no real solution — infeasible AC, i.e. past collapse.

    Imposing $|V|\ge\underline{v}$ removes $V_-$ (and, near the nose, part of the
    feasible $V_+$ range too). That is exactly what you want for *operational* studies
    and exactly what you must *not* do for *collapse* studies. A relaxation, by
    contrast, replaces the equality defining the manifold with an inequality, so its
    feasible region can extend into the $\rho < 0$ region — reporting "feasible" for a
    loading the network cannot serve.

## 5. The objective decides everything

!!! tip "Takeaway"
    An objective **non-decreasing in every nodal generation — equivalently, in line
    losses** is the *objective-side* condition for a relaxation to be exact and for the
    nonconvex problem to stay on the high-voltage branch. It is necessary in practice but
    **not sufficient on its own**: the exactness theorems also need *network-side*
    conditions (radiality, non-binding upper voltage bounds, and either no binding
    generator lower bounds or permitted load over-satisfaction — see the proof sketch
    below and Section 3). Loss / cost /
    slack-power minimization supplies the objective-side condition; an objective that
    rewards higher losses or currents fails even that, dragging the exact model toward the
    low-voltage branch **and** breaking relaxation exactness, so the relaxed answer stops
    corresponding to any real operating point.

In the branch-flow relaxation the squared-current variable $\ell_{ij}$ satisfies the
relaxed inequality

```math
\ell_{ij} \;\ge\; \frac{|S_{ij}|^2}{v_i},
```

which equals the true physics only when it binds. A loss-minimizing objective *pushes
$\ell_{ij}$ down onto the binding face* — recovering an AC-feasible point. A
loss-maximizing objective *pulls $\ell_{ij}$ up off the face* — the cone goes slack and
the solution is no longer physical
([Gan, Li, Topcu & Low, 2015](https://arxiv.org/abs/1311.7170);
[Yuan & Paolone, 2020](https://arxiv.org/abs/1906.06105)).

!!! details "Proof sketch: monotonicity ⇒ exactness; and the standard escape hatches"
    The exactness arguments of
    [Low (2014), Part II](https://doi.org/10.1109/TCNS.2014.2323634) and
    [Gan et al. (2015)](https://arxiv.org/abs/1311.7170) run by contradiction: if the
    cone constraint were slack at the optimum, one could *decrease* $\ell_{ij}$, which
    decreases losses and (with an objective non-decreasing in generation/losses) cannot
    worsen the objective, contradicting optimality. The physical reading is that
    reducing a line's loss increases every upstream reverse flow.

    The recurring technical conditions in the exactness literature — no generator lower
    bounds, or allowing **load over-satisfaction**
    ([Sojoudi & Lavaei, 2012](https://doi.org/10.1109/PESGM.2012.6345272);
    [Gan et al., 2015](https://arxiv.org/abs/1311.7170)) — are exactly the assumptions
    that *simultaneously* guarantee boundedness (Section 1), keep you on the
    high-voltage branch (Section 2), and hold you away from collapse (Section 4). They
    are one set of conditions wearing three hats. When the relaxation is not exact, its
    optimum need not correspond to any AC-feasible point, so attaching a physical meaning
    to it is generally unjustified
    ([Kocuk, Dey & Sun, 2016](https://doi.org/10.1109/TPWRS.2015.2402640);
    [Molzahn & Hiskens, 2019](https://doi.org/10.1561/3100000012)).

A useful identity ties this back to feasibility: slack power $=$ losses $+$ net load, so
**with all other injections fixed, minimizing slack injection is loss minimization**
(when other generators are also free, min-slack minimizes losses *plus* their net output,
which is why min-import can push dispatchable DER against upper voltage bounds — see the
[decision matrix](decision_matrix.md)). This is why a bare feasibility problem is so often
quietly turned into a min-slack (loss-min) problem — it makes the problem well-posed *and*
branch-correct in one move.

The objectives that violate the monotonicity test, and the reformulations that fix them,
are catalogued in [Objectives that imply loss maximization](loss_maximization.md).

## 6. Practical recommendations by task

!!! note "Operational OPF (economic dispatch, Volt/VAR, hosting capacity done right)"
    Use a loss- or cost-minimizing objective (non-decreasing in generation), full
    operational bounds, and a relaxation if you want a global optimum — then **verify
    exactness** ([Diagnostics](diagnostics.md)). Linear models are fine for screening.

!!! note "Feasibility / restoration studies"
    Solve OPF with a constant objective, or min-slack, with full bounds. Remember the
    one-sided certificate: a feasible **relaxation** does not prove AC feasibility;
    confirm with a nonconvex solve or [`primal_feasibility_report`](diagnostics.md).

!!! note "Loadability / collapse studies"
    This is a **nonconvex / continuation** problem. Drop the voltage lower bound that
    clips the lower branch, expect multiplicity, and do **not** trust *any* relaxation
    as a feasibility oracle in this regime. Use BMOPFTools' nonconvex
    [`solve_opf`](../opf.md) (continuation around it) here, not a relaxation reached via
    [`to_pmd`](../conversion.md). Maximizing loadability in an SOC model and believing
    the number is the single most common error this page exists to prevent.

Once the traps above are excluded, the remaining question is how far to trust the solver's
own verdict — when an `INFEASIBLE` is physical and a `LOCALLY_SOLVED` is global. That is the
subject of the [Trusting the solver](solver_trust.md) capstone, together with the residual
*numerical* traps (degeneracy, non-smoothness, zero voltage) that survive after the physics
is right.

---

See also: [Decision matrix](decision_matrix.md) ·
[Objectives that imply loss maximization](loss_maximization.md) ·
[Diagnostics & validation](diagnostics.md) ·
[Known traps](known_traps.md) ·
[Trusting the solver](solver_trust.md) ·
[References](references.md)
