# Trusting the Solver

When you have worked through the formulation traps of the previous pages and the
[benchmark-readiness flags](../methodology.md), the remaining trap is *numerical*, not
physical. This page is about the last question a validator asks: **how much should I trust
what Ipopt just told me?**

!!! note "How to read this page"
    Same split as the [main note](index.md): two audiences share this page.

    - **Building or curating a dataset?** Read the *Takeaway* boxes and the
      [trust checklist](@ref "7. A trust checklist") at the end. The short version: once your
      bounds are sane, your objective is off the
      [loss-maximization list](loss_maximization.md), and the benchmark flags are
      clear, solver statuses become useful **hypotheses** to verify: multi-start
      and a feasibility relaxation strengthen an infeasibility diagnosis, while
      primal residual checks establish whether a locally solved point is a valid
      operating point.
    - **Validating a formulation?** Read everything. The two headline rules are:
      *a local infeasibility status is not an infeasibility certificate*, and *a
      local optimum is not a global optimum*. Sections 2–6 explain what additional
      evidence can justify greater confidence without changing those facts.

!!! tip "The two claims, up front"
    After the physics traps are excluded:

    - **`INFEASIBLE` means this solver trajectory did not reach feasibility.**
      Ipopt entered restoration, minimised constraint violation locally, and
      could not drive it to zero. Repeated starts and a consistent slack-current
      pattern strengthen the diagnosis but do not prove the feasible set is empty.
    - **`LOCALLY_SOLVED` means a KKT point was found.** A high-voltage start and a
      non-decreasing generation-cost objective often favour the operational
      branch, but this does not establish global optimality. Only a valid global
      bound — for example from an exact relaxation or global solver — can do that.

## 1. What Ipopt's verdicts actually certify

!!! tip "Takeaway"
    Ipopt is a **local** interior-point solver. `LOCALLY_SOLVED` reports that its
    termination tests for approximate first-order (KKT) conditions passed — a
    stationary-point claim for a *nonconvex* program, not a global optimum.
    `LOCALLY_INFEASIBLE` ("Converged to a locally infeasible point") reports that
    Ipopt's **restoration phase** reached a local minimiser of constraint violation
    with violation still above tolerance. Independently inspect primal residuals
    before treating either status as evidence about the represented system.

Ipopt solves a sequence of barrier subproblems with a filter line search
([Wächter & Biegler, 2006](https://doi.org/10.1007/s10107-004-0559-y)). When a step
cannot make progress toward both feasibility and optimality, it switches to a
**feasibility restoration phase** that ignores the objective and minimises the constraint
violation. The two terminal messages map onto this machinery directly:

- **`LOCALLY_SOLVED`** — the KKT residual and the constraint violation are both below
  tolerance at a stationary point.
- **`LOCALLY_INFEASIBLE`** — restoration converged to a local minimiser of infeasibility
  whose residual is still positive: Ipopt got as close to feasible as it locally could,
  and that was not close enough.

!!! details "Derivation: why 'locally infeasible' is a one-sided signal on a nonconvex set"
    On a convex program, a point of minimal-but-positive constraint violation proves the
    feasible set is empty: the violation is a convex function and a local minimiser is
    global. On a **nonconvex** program that implication breaks. A locally infeasible
    point only certifies that *from this trajectory* Ipopt could not reach feasibility; a
    different start might. The honest reading is the one in the interior-point literature:
    converging to an infeasible stationary point leaves it "unclear whether the problem is
    truly infeasible or whether the algorithm was unable to find a feasible solution"
    ([Hinder & Ye, 2018](https://arxiv.org/abs/1801.03072)). Methods that *do* return a
    first-order **certificate** of local infeasibility exist, but they are specially
    constructed; stock Ipopt does not hand you one.

    The practical upshot is the whole reason this page exists: you cannot lift
    `INFEASIBLE` to a proof for free, but you can accumulate reproducible evidence
    by excluding alternative explanations — which is Sections 2 through 6.

## 2. Building evidence for physical infeasibility

!!! tip "Takeaway"
    Full operational bounds and a positive voltage floor can make the search
    region bounded and remove common collapse/zero-voltage pathologies
    ([§3](index.md) and [§4](index.md)). They do not make the problem convex or
    make restoration exhaustive. Treat agreement across starts, formulations,
    and residual diagnostics as evidence, not as a binary proof.

The main note's [§4](index.md) makes the physical case sharp: with constant-power loads,
the edge of the AC feasible region *is* the loadability boundary, and beyond the nose the
equations have **no real solution** — genuine infeasibility, not a modelling slip. So an
`INFEASIBLE` on a heavily loaded sub-network is frequently the model telling you the truth.

The hedge is nonconvexity: restoration is start-dependent. Two cheap cross-checks promote
the signal toward certainty:

- **Multi-start.** Re-solve from several materially different starts (flat,
  high-voltage, a linear-model warm start). If every start lands in restoration
  with a comparable residual, confidence in the diagnosis increases; one
  independently verified feasible point disproves infeasibility — see [Symptom
  5](diagnostics.md).
- **The slack-current measure.** [`solve_feasibility_opf`](../validation.md) adds an
  elastic slack current at every non-source terminal and minimises its norm. For
  a converged relaxed solve, a non-zero `total_slack_magnitude_A` localises where
  that local solution uses residual current. Unlike an IIS for a convex/linear
  problem, it does not certify that no zero-slack solution exists elsewhere.

## 3. Why a local solve often reaches the high-voltage branch

!!! tip "Takeaway"
    Some radial single-phase results establish useful uniqueness or attraction
    properties for the high-voltage power-flow solution under stated conditions.
    Those results motivate a high-voltage start and a loss/cost-minimising
    objective here. They do not establish uniqueness or global optimality for the
    meshed, multiphase, unbalanced OPFs this engine also targets.

This is the optimistic mirror of [§2](index.md) and [§5](index.md). On a radial network
the high-voltage solution is the last one to vanish as the system loads toward its limit,
and the standard computational routes return exactly it when one exists
([Dvijotham, Mallada & Simpson-Porco, 2017](https://arxiv.org/abs/1706.05290), a radial,
single-phase result). A loss-minimising objective can favour that branch
([§5](index.md)). For a four-wire unbalanced feeder this is a useful
initialisation heuristic and modelling analogy, not a probability statement or
a theorem that carries over ([Bernstein et al.,
2018](https://doi.org/10.1109/TPWRS.2018.2823277)). Globality remains an open
claim until a valid lower bound closes the optimality gap.

!!! details "Derivation: what an actual globality certificate would require"
    Attraction to a familiar branch is not a theorem about your specific
    instance. A genuine certificate comes from one of two places:

    - **An exact convex relaxation.** Solve the SOC/SDP relaxation, then confirm exactness
      ([Diagnostics Symptom 3](diagnostics.md)). An exact relaxation has a *single global*
      optimum; if your nonconvex objective value matches it, you have proof of globality.
      This is why the validation workflow pairs the two solves.
    - **A global optimization method** that brackets the global optimum between a feasible
      upper bound (any AC-feasible point) and a relaxation lower bound, and drives the gap
      to zero — surveyed in the note below.

    Absent either, treat `LOCALLY_SOLVED` as a high-confidence operating point — and use
    the [low-voltage-branch checks](diagnostics.md) to rule out the one failure mode that
    *does* fake a clean solve: convergence to the low-voltage branch under a poor start.

!!! warning "Why there is no cheap certificate: AC OPF is NP-hard"
    The absence of a free globality certificate is **fundamental, not a tooling gap**.
    AC OPF is a nonconvex, NP-hard optimization problem, and the hardness does not come
    from the objective or from network size alone: even deciding **AC *feasibility*** — is
    there *any* operating point at all — is **NP-hard even on radial / tree networks**
    ([Lehmann, Grastien & Van Hentenryck, 2016](https://doi.org/10.1109/TPWRS.2015.2407363))
    and **strongly NP-hard** in general
    ([Bienstock & Verma, 2019](https://doi.org/10.1016/j.orl.2019.08.009)). The tree result
    is the pointed one here: the distribution feeders this package targets are precisely
    where one might hope topology buys tractability, and it does not. So a polynomial-time
    local solver such as Ipopt *cannot*, in general, hand you a certificate of globality or
    of infeasibility — which is exactly why this page is framed as **calibrated trust**,
    and why a certificate, when you need one, costs a relaxation-exactness check or a
    global solve.

!!! note "If you do need a certificate: global OPF in practice"
    When the deliverable is a *proof* of the global optimum — certifying a benchmark
    reference value rather than trusting it — the tools live outside BMOPFTools (which
    ships only the local nonconvex engine) and form a small, well-characterised toolbox.
    All of them **bracket** the optimum between a feasible upper bound (any AC-feasible
    point, e.g. your Ipopt solution) and a relaxation lower bound, then close the gap:

    - **Moment / Lasserre SDP hierarchies.** Cast ACOPF as polynomial optimization and
      climb a hierarchy of SDP relaxations that converges to the global optimum; the
      second-order moment relaxation already closes many cases the first-order SDP leaves
      open ([Molzahn & Hiskens, 2014](https://arxiv.org/abs/1312.1992)). *Critical limit:*
      the semidefinite blocks grow steeply, so only sparsity / clique decomposition keeps
      it tractable, and even then it caps out at moderate network sizes.
    - **Optimization-based bound tightening (OBBT) and valid cuts.** Iteratively shrink
      variable bounds by solving auxiliary relaxations and add valid inequalities. Cheap
      and parallelizable — the workhorse that makes everything else practical — but it
      tightens the gap rather than closing it on its own.
    - **Spatial branch-and-bound.** Partition the nonconvex space and bound each piece with
      a convex relaxation, yielding a certified global optimum at exponential worst-case
      cost. [Alpine.jl](https://arxiv.org/abs/1707.02514)
      ([Nagarajan et al., 2019](https://doi.org/10.1007/s10898-018-00734-1)) is the open
      Julia implementation; general global solvers (BARON, SCIP, Gurobi) do the same.
    - **The QC relaxation** ([Coffrin, Hijazi & Van Hentenryck,
      2016](https://doi.org/10.1109/TPWRS.2015.2463111)) — a tractable strengthening
      sitting between SOC and SDP, the relaxation of choice *inside* bound-tightening and
      branch-and-bound.

    The state of the art combines all four: [Gopinath et al.
    (2020)](https://doi.org/10.1016/j.epsr.2020.106688) close the optimality gap on the
    standard ACOPF benchmark libraries (PGLib) by pairing SDP-based bound tightening with
    valid cuts. These methods *can* certify globality,
    but they are NP-hard in the worst case (above), do not yet scale to large feeders, and
    are **not** what this package ships. Reach for them — your own, or the ecosystem's via
    [`to_pmd`](../conversion.md) — only when a proof is the actual deliverable; for
    everything else, the [trust checklist](@ref "7. A trust checklist") is the right tool.

## 4. Residual trap A — degeneracy of the added models

!!! tip "Takeaway"
    Degeneracy is a **constraint-qualification failure**: the gradients of the active
    constraints stop being linearly independent. Its symptoms are slow convergence and
    **non-unique or blown-up duals** (shadow prices, sensitivities) — *not* a wrong primal
    point. A `LOCALLY_SOLVED` with a small primal residual is still a valid operating
    point even when its duals are garbage. Distrust the prices, not the dispatch.

Augmenting a case — adding generators, fixing a dispatch, pinning a regulator — is exactly
where degeneracy creeps in. The classic example is an **over-determined bus**: a generator
pinned to a single operating point (`p_min = p_max`) sitting at a bus whose voltage is also
fixed by a hard equality. At the solution, several active constraints have linearly
dependent gradients, and the Lagrange multipliers are no longer unique.

A second, entirely **avoidable** cause is a **redundant constraint** — an equation that
carries no information because the others already imply it. Unlike the over-determined bus,
which fails LICQ only on a measure-zero parameter set, a structural redundancy breaks it at
*every* feasible point, so it never solves cleanly.

!!! warning "Don't bolt a system-wide power balance onto nodal KCL"
    The nodal power-balance (KCL) equations are **linearly dependent by construction**:
    summing them over all terminals telescopes the internal flows and leaves the global
    conservation identity

    ```math
    \sum_i S_i \;=\; \sum_g S^g \;-\; \sum_d S^d \;-\; \text{losses}.
    ```

    So a "sanity" constraint $\sum_g S^g = \sum_d S^d + \text{losses}$ added *on top of*
    full per-terminal KCL is **already implied** — its gradient row is a linear combination
    of the KCL rows. LICQ then fails everywhere: duals become non-unique, and the
    interior-point iteration stalls or terminates with diverging iterates
    (`NORM_LIMIT`) on a problem that is otherwise perfectly well posed. This is the same redundancy that makes classical
    transmission OPF **drop the slack-bus balance** and let the reference absorb the
    mismatch ([cycle-flow formulations](https://arxiv.org/abs/1704.01881)); in this
    package the slack *source* plays that role, so the global balance is never needed.
    The same trap recurs in miniature whenever an equality duplicates information already
    present — pinning a reference bus's voltage magnitude on top of its rectangular
    fixes, or grounding a neutral the source already fixes to zero. **Fix:** delete the
    redundant equation; do not regularise around it.

!!! details "Derivation: LICQ, MFCQ, and what fails"
    The **linear independence constraint qualification (LICQ)** asks that the gradients of
    the active constraints be linearly independent at the solution; it guarantees a
    *unique, bounded* multiplier vector. The weaker **Mangasarian–Fromovitz CQ (MFCQ)**
    asks only positive-linear independence and guarantees the multiplier set is *bounded*
    but not unique. Interior-point convergence analysis leans on at least MFCQ: when even
    that fails, the dual iterates can diverge and the solve crawls
    ([on multiplier behaviour in infeasible IPMs](https://arxiv.org/abs/1707.07327)).

    For AC OPF, LICQ holds *generically* — it fails only on a measure-zero set of
    parameter values, a fact made precise with tools from differential topology by
    [Hauswirth, Bolognani, Hug & Dörfler (2018)](https://arxiv.org/abs/1806.06615), who
    show the LICQ is satisfied almost everywhere and unique multipliers therefore exist
    generically. The trouble is that **augmentation deliberately steers you onto that
    set**: identical generator costs, zero-cost generators, and pinned injections are
    exactly the structured coincidences that make active-constraint gradients dependent.
    This is why these are caught structurally *before* you solve, by the benchmark-
    readiness flags `W.BENCH.GEN_NO_DOF`, `W.BENCH.GEN_ZERO_COST`, and
    `W.BENCH.GEN_DEGENERATE_COST` ([Methodology § Benchmark readiness](../methodology.md));
    a zero-cost generator's non-coercive objective surfaces at runtime as diverging
    iterates (`NORM_LIMIT`) or an unbounded-objective termination — the runtime echo of
    `W.BENCH.GEN_ZERO_COST`.

The trust message: clear the `W.BENCH.GEN_*` flags, keep redundant equations out of your
formulation, and degeneracy mostly evaporates. Where it remains, read it as a warning about
*prices and sensitivities*, and confirm the primal dispatch is unaffected by re-solving from
a second start ([Symptom 5](diagnostics.md)).

## 5. Residual trap B — smoothness loss and the zero-voltage bifurcation

!!! tip "Takeaway"
    The bilinear power map $p = v_r c_r + v_i c_i$ is **smooth** — products of variables
    are $C^\infty$. The danger near zero voltage is twofold: (a) the map's **Jacobian rank
    drops** when the voltage factor vanishes, so the current it multiplies becomes
    *indeterminate* — a bifurcation of the solution set, and a constraint-qualification
    failure; and (b) **voltage-dependent load models are genuinely non-smooth** as voltage
    → 0. Keep voltages away from zero and both disappear.

!!! warning "Bilinear is not the same as non-smooth"
    It is tempting to call the bilinear power equations "non-smooth," but they are not — a
    product $xy$ is infinitely differentiable everywhere. Two *distinct* effects masquerade
    as non-smoothness:

    - **(a) Rank-loss / bifurcation.** In the constant-power constraint
      $p = v_r c_r + v_i c_i$, the partial derivatives with respect to the current are
      $(v_r, v_i)$. When the voltage factor $\to 0$, that gradient vanishes: the current is
      no longer pinned by the power equation, so *any* current satisfies it. The
      solution set bifurcates and LICQ ([§4](@ref "4. Residual trap A — degeneracy of the added models"))
      fails. The function is smooth; its Jacobian is rank-deficient.
    - **(b) Genuine non-smoothness.** ZIP and exponential load models *are* non-smooth at
      zero. The exponential form realises $P \propto (W / V_{\text{nom}}^2)^{\gamma/2}$
      with $W = v_r^2 + v_i^2$, and the constant-current term needs $s = \sqrt{W}$. For
      $\gamma < 2$ the derivative of $x^{\gamma/2}$ blows up as $x \to 0$; $\sqrt{x}$ has
      an infinite slope at the origin. These are real singularities, not rank artefacts.

!!! details "Derivation: the Hessian blow-up of a fractional power"
    For $f(x) = x^{\gamma/2}$ with $0 < \gamma < 2$, $f''(x) = \tfrac{\gamma}{2}
    \!\left(\tfrac{\gamma}{2}-1\right) x^{\gamma/2 - 2}$, whose magnitude $\to \infty$ as
    $x \to 0^+$ because the exponent $\gamma/2 - 2 < -1$. An interior-point method building
    the Lagrangian Hessian then sees unbounded curvature, takes vanishing steps, and churns
    in restoration — the symptom in [Trap 8](known_traps.md). The fix is to bound the
    argument away from zero: BMOPFTools floors $W$ at $(\texttt{\_W\_FLOOR\_FRAC} \cdot
    V_{\text{nom}})^2$ and $s$ correspondingly (see
    [`load.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/load.jl)),
    so the load model never reaches its singular point. The volt-var / volt-watt droop
    curves are smoothed the same way, with softplus corners rather than hard ReLU kinks
    ([Smooth droop encoding](../relu_softplus_encoding.md)).

## 6. Residual trap C — zero voltage in power–voltage formulations

!!! tip "Takeaway"
    Allowing $|V| = 0$ admits a **spurious all-zero solution** ($S = 0$ for *any* current)
    and excites the constant-power $1/V$ current singularity. Keep a **strictly positive
    voltage floor** — even in collapse studies, where you drop the *operational* lower
    bound but never lower it to literally zero.

In the bus-injection model $S_i = V_i \sum_j Y_{ij}^* V_j^*$, the all-zero voltage profile
$V = 0$ gives $S = 0$ trivially — a feasible point of the power-flow equations that is
physically meaningless. With the IVR formulation the same degeneracy appears through
[§5](@ref "5. Residual trap B — smoothness loss and the zero-voltage bifurcation")(a): at
$v_r = v_i = 0$ the bilinear power equation collapses to $0 = 0$ for any current, so an
ungrounded or islanded sub-network can drift its whole voltage to zero. Conversely, a
constant-power load demands $i = (S/V)^*$, so as $|V| \to 0$ the required current $\to
\infty$ — the feasible set is non-compact in the current variables and the constraints
become ill-conditioned ([Molzahn, Lesieutre & DeMarco,
2013](https://molzahn.github.io/pubs/molzahn_lesieutre_demarco-pfcondition.pdf)).

!!! warning "Reconciling with the collapse-study advice"
    [§4](index.md) of the main note tells you to *drop the voltage lower bound* to study
    loadability — and that is right, but it means dropping the **operational** bound
    (e.g. $0.9$ p.u.), not setting it to zero. The low-voltage branch you want to expose
    lives well above zero; the all-zero solution of this section is a different, spurious
    object. BMOPFTools' feasibility OPF keeps this distinction concretely: it retains the
    case's own (strictly positive) voltage bounds unchanged and relaxes only nodal current
    balance, so infeasibility surfaces as localised slack currents rather than as a
    collapsed voltage solution (see the
    [infeasibility diagnosis tutorial](../tutorial_infeasibility.md)).

## 7. A trust checklist

Work top to bottom; each step removes one alternative explanation for the solver's verdict.

!!! note "Before you trust the verdict"
    1. **Benchmark-readiness flags clear?** No `W.BENCH.GEN_*`, no degeneracy flags
       ([Methodology](../methodology.md)). Clears [§4](@ref "4. Residual trap A — degeneracy of the added models").
    2. **No redundant constraints?** No equation implied by the others — in particular no
       system-wide power balance on top of nodal KCL
       ([§4](@ref "4. Residual trap A — degeneracy of the added models")).
    3. **Bounds sane and collapse excluded?** Full operational box, a strictly positive
       voltage floor ([§6](@ref "6. Residual trap C — zero voltage in power–voltage formulations")),
       and you are not deliberately on the loadability boundary ([§4](index.md)).
    4. **Objective off the loss-max list?** Loss/cost-minimising, non-decreasing in
       generation ([loss-maximization list](loss_maximization.md)).
    5. **Load models away from their singular point?** Voltage floor in place so fractional
       ZIP exponents stay smooth ([§5](@ref "5. Residual trap B — smoothness loss and the zero-voltage bifurcation")).
    6. **Multi-start agrees?** Same verdict, comparable objective, no low-voltage cluster
       across several starts ([Symptom 4–5](diagnostics.md)).

!!! note "Then read the verdict this way"
    - **`INFEASIBLE`** after steps 1–6 ⇒ report a strengthened but still local
      infeasibility diagnosis; show the multi-start outcomes and localise the
      residual with `solve_feasibility_opf`.
    - **`LOCALLY_SOLVED`** after steps 1–6 ⇒ treat it as a candidate operating
      point after independently checking primal feasibility. Do not label it
      globally optimal unless a relaxation/global solve supplies a matching valid
      bound ([Symptom 3](diagnostics.md)).
    - **Slow / churning / suspicious duals** ⇒ you are in Section 4, 5, or a collapse
      regime; localise with [Symptom 5](diagnostics.md) before trusting *any* number.

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Decision matrix](decision_matrix.md) ·
[Objectives that imply loss maximization](loss_maximization.md) ·
[Diagnostics & validation](diagnostics.md) ·
[Known traps](known_traps.md) · [References](references.md)
