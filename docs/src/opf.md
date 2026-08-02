# Optimal power flow

Despite the name, the ambition of this Task Force extends well beyond the
classical OPF problem of minimising generation cost subject to network
constraints.  The unifying theme of the benchmark problems targeted here is
the need to **accurately represent distribution network physics** rather than
any particular objective function. Generation cost minimisation with explicit
operational bounds is a convenient starting point: its objective and feasibility
conditions are straightforward to compare across solvers. With fixed demand and
one uniform non-negative price on every real-power injection, minimizing total
injection is equivalent to minimizing real losses. That special case does
**not** imply uniqueness or global optimality in this
nonconvex formulation. The same network physics underpins a
much broader class of distribution-network-constrained optimisation problems
of practical relevance: maximum load delivery, conservation voltage reduction
(CVR), Dynamic Operating Envelopes (DOEs) for distributed energy resources,
and distribution system state estimation (DSSE).

What these problems share is not a common objective but a common requirement:
a faithful, conductor-level representation of an unbalanced network subject
to a selectable set of bounds.  Voltage bounds, current limits, and power
constraints are therefore **optional** in the data model, reflecting the fact
that different problem formulations will activate different subsets of the
feasible region.  The intent is a reusable foundation across all such problem
classes, not merely infrastructure for a single OPF problem definition.

---

BMOPFTools ships a **four-wire rectangular current–voltage** optimal
power flow engine as a Julia package extension.  It activates automatically when
both JuMP and Ipopt are loaded:

```julia
using BMOPFTools, JuMP, Ipopt

net    = parse_bmopf("mynetwork.json")
result = solve_opf(net)
```

A full mathematical derivation is available in `docs/math-model.tex`.

---

## Formulation principles

The engine is a **four-wire, rectangular current–voltage** formulation,
organised around a handful of deliberate, non-obvious choices worth stating
explicitly:

1. **Explicit current *and* voltage variables, as needed.** Both terminal
   voltages and branch currents are first-class variables — which is what lets
   the model represent parallel lines, meshed networks, and zero-impedance
   sections **exactly** (each parallel branch carries its own current, loops
   close through KCL, a jumper collapses to `V_fr = V_to`), with no small-ε
   impedance to break degeneracy.
2. **Series voltage drops obey Ohm's law in impedance form.** Every series
   element (line, transformer winding) is `ΔV = Z·I`, never admittance form.
   Only elements whose counter-terminal is **ground** (shunts, line π-halves)
   are written `I = Y·V`. This preserves the lossless limit — as `R → 0` the
   impedance form stays finite, whereas an admittance form blows up (`Y → ∞`).
3. **Derived quantities are expressions, not variables.** Powers, voltage
   differences, and averages are built as expressions of the real variables
   rather than fresh variables pinned down by equalities — avoiding trivial
   linear dependencies that only burden the solver. *Deliberate exception:* the
   two-winding transformer builders (YY, Yd/Dy, center_tap) and the DC resistive
   branch keep explicit per-winding current **variables** pinned by linear
   equalities, so that current limits (`i_max`) and the result writer have a
   first-class handle on each physical winding current — accepting one redundant
   linear degree of freedom per winding rather than threading an expression
   through the limit-and-reporting machinery.
4. **Idealized components are represented as such.** An ideal switch is
   `V_fr = V_to`, an ideal transformer is `V_fr = N·V_to`, a lossless shunt is
   pure susceptance — represented semantically, not approximated with a small ε
   (see [Zero impedance](dev/opf_engine.md#zero-impedance)).
5. **A variable number of terminals per bus.** Voltage variables and a KCL
   equation are declared at *every* terminal a bus actually has — there is no
   fixed slot count, and buses of different widths interconnect naturally in one
   model.
6. **Every phasing, mixed freely.** Single-phase, split-phase, three-wire (no
   neutral), and three-phase-plus-neutral are all first-class and coexist in a
   single case study, because state is keyed per `(bus, terminal)` with no
   global phase count. The engine's modeled scope is **up to three-phase +
   neutral** (four wire).
7. **Bounds are optional — use them if present, never synthesise one from
   another.** Voltage, current, and apparent-power limits are all optional in the
   data model, and different problem formulations activate different subsets of
   the feasible region. A constraint is stamped only from data that is actually
   present; the engine never derives a current bound from a power bound (or vice
   versa), because a case may carry one, both, or neither *by design*.
8. **No known non-smooth constraints — smoothen them.** Constraints are kept
   continuously differentiable so the interior-point solver sees a well-defined
   Jacobian everywhere. A magnitude `√(x²+y²)` is never written directly in a
   constraint (its gradient is unbounded at the origin, and a monitored voltage
   difference is not bounded away from zero); instead an *implicit square root* —
   an auxiliary `u ≥ 0` with `u² = x²+y²` — is used. Droop and saturation curves
   are encoded with a smooth ReLU/softplus rather than a hard `max`/`min` (see
   [Smooth droop encoding](relu_softplus_encoding.md)).
9. **Keep constraints low-degree (quadratic).** Where a naïve statement would be
   quartic, rational, or higher-order, an auxiliary variable and its defining
   constraint bring it back to degree two — the regime interior-point solvers
   handle most reliably. Apparent power is bounded through aux `p, q` with
   `p² + q² ≤ s²` (not a quartic in voltage × current); a free tap's reciprocal
   is an aux variable pinned by `n · n⁻¹ = 1` (not a rational term); the
   voltage-dependent load factors through `W = |ΔV|²` and `s = |ΔV|`.
10. **Well-posedness is enforced, not assumed.** Removable degeneracies are
    collapsed to their exact form (principle 4); irreducible ones are rejected
    with a clear error rather than allowed to poison the model with NaN/Inf. A
    zero nominal voltage (undefined `1/v_nom`), a zero winding turns-ratio, or two
    zero-impedance branches shorting the same terminals (an undetermined current
    split) are refused up front, not solved into nonsense.
11. **Prefer a hard variable bound; scale the constraint that is left.**
    Interior-point solvers enforce *variable bounds* far more tightly than general
    nonlinear constraints — Ipopt holds a bound to its `bound_relax_factor`
    (effectively exactly), but a constraint only to the absolute `constr_viol_tol`.
    So wherever a valid — if looser — box bound on a variable exists, it is stamped
    *in addition to* the exact constraint: it backstops the soft constraint and
    bounds the search region from the start. A current-magnitude limit `|I| ≤ i_max`
    is written both as a second-order cone and as a box on each rectangular current
    component. The magnitude and power cones that have no such backstop — apparent
    power, sequence voltage, neutral current — are instead written in **normalized**
    form `(a/lim)² + (b/lim)² ≤ 1` rather than `a² + b² ≤ lim²`, so the constraint
    value is order ≈ 1 regardless of the per-unit base and the solver's absolute
    tolerance stays meaningful. (Un-normalized, a current cone at a large `s_base`
    can sit near `1e-6` — below `constr_viol_tol` — so a limit that ought to force
    infeasibility is silently accepted.) This is the constraint-scaling companion to
    the variable scaling in [Units and scaling](#Units-and-scaling).
12. **The formulation is non-convex — determinism comes from the warm start.**
    Rectangular AC power flow is non-convex: the feasible set has multiple local
    optima (a voltage-collapsed root, phase-rotated roots), and the interior-point
    solver returns whichever is nearest its starting point. Every variable is
    therefore initialised from a physically-motivated, deterministic guess —
    canonical 120° phase angles, anti-phase split-phase legs, delta-loop voltage
    propagation, and `I = conj(S)/conj(V)` current seeding — to steer the solve to
    the *operational* root rather than a spurious one. The warm start is not a
    performance nicety; it is what makes the returned solution reproducible and
    physically meaningful (see [Warm-start initialisation](#Warm-start-initialisation)).
13. **One sign convention, and results are recomputed with it.** A single
    convention is fixed and applied to *every* element type — current into a bus is
    positive in KCL, apparent power is `S = V · conj(I)`. The result writer derives
    every reported quantity (per-element power, losses, terminal currents) from the
    *same* expressions the constraints are built from, never from an independent
    re-derivation that could drift out of sync with the model. This consistency is a
    correctness invariant, not a convenience: a quantity reported with the opposite
    sign to its own constraint is a silent error that a feasible solve will never
    catch.

These principles were inspired by the IVR-EN formulation in
[PowerModelsDistribution](positioning.md) and by Claeys et al.'s four-wire OPF
paper ([ref. 6](methodology.md#refs)), but the model here has been generalized
well beyond that starting point.

---

## Mathematical model

### Network representation

The network is a graph of **buses** $b \in \mathcal{B}$, each with a set of
**terminals** $\mathcal{T}_b$.  Terminals are named strings (e.g. `"a"`, `"b"`,
`"c"`, `"n"`).  The *neutral terminal* $n_b$ is identified by the explicit
`neutral_terminal` bus field, or by the naming convention: a terminal named `"n"`
or `"N"` (case-insensitive) is treated as neutral.

Terminals declared in `perfectly_grounded_terminals` are **perfectly grounded**:
their voltage is fixed to zero and they do not appear in the KCL system.
The set of grounded pairs is $\mathcal{G}_\text{nd}$.

**Phase terminals** $\mathcal{T}_b^\phi \subseteq \mathcal{T}_b$ are all
terminals that are not the neutral.

---

### Variables

All variables are real-valued. By default they are in SI units (V and A); see
[Units and scaling](#Units-and-scaling) for the optional per-unit solve.

| Variable | Index | Description |
|---|---|---|
| $v^r_{b,t},\; v^i_{b,t}$ | $(b,t)\in\mathcal{B}\times\mathcal{T}_b$ | Rectangular voltage at terminal |
| $c^r_{\ell,k},\; c^i_{\ell,k}$ | line $\ell$, conductor $k$ | Series current, from-side |
| $\tilde{c}^r_{\ell,k},\; \tilde{c}^i_{\ell,k}$ | line $\ell$, conductor $k$ | Series current, to-side |
| $c^{r,d}_{d,k},\; c^{i,d}_{d,k}$ | load $d$, phase $k$ | Load current |
| $c^{r,g}_{g,k},\; c^{i,g}_{g,k}$ | generator $g$, phase $k$ | Generator current |
| $c^{r,n}_{n,k},\; c^{i,n}_{n,k}$ | IBR $n$, phase $k$ | IBR current |
| $c^{r,s}_{v,k},\; c^{i,s}_{v,k}$ | voltage source $v$, phase $k$ | Source slack current |
| $c^{r,x}_{x,\sigma,k},\; c^{i,x}_{x,\sigma,k}$ | transformer $x$, side $\sigma$, conductor $k$ | Transformer winding current (two-bus subtypes) |
| $c^{r,w}_{x,j,k},\; c^{i,w}_{x,j,k}$ | `n_winding` transformer $x$, winding $j$, phase $k$ | n-winding winding current |

Load, generator, IBR, and source current variables cover **phase
conductors only**; neutral return current is implicit in KCL. IBRs add an
analogous current variable per phase — see [IBRs](#ibrs) below.

---

### Units and scaling

By default the OPF is built and solved directly in **SI** units (volts,
amperes, ohms) — the same units as the [data model](conventions.md#Units), so no
conversion is needed. Passing `per_unit=true` to `solve_opf` instead solves a
**normalized per-unit copy** of the network — a system base `s_base` (VA, default
`1e6`) with per-bus voltage bases propagated through transformer ratios — and
converts the results back to SI, so the choice is invisible to the caller.

Both modes exist because **variable scaling affects the conditioning of a
nonlinear interior-point solve**. Ipopt's initialization, barrier updates and
stopping tests are scale-sensitive, and it cannot infer good scaling in general,
so bringing variables to order ≈1 is standard practice for nonlinear programs
[ref. 18](methodology.md#refs). In SI, a four-wire LV problem spans many orders
of magnitude at once (volts, amperes, ohms, watts), which is the regime
interior-point methods handle least well.

Whether per-unit normalization actually improves convergence **here** is an
open, instance- and formulation-dependent question, not a settled fact: the
benefit of scaling a nonlinear program is known to be problem-dependent
[ref. 19](methodology.md#refs), and AC-OPF numerical performance is governed
strongly by the formulation as well [ref. 20](methodology.md#refs). The two
modes are provided precisely so this can be **benchmarked** rather than assumed —
the SI data model (a representation choice, [ref. 16](methodology.md#refs)) does
not commit the solver to computing in SI.

The [units, bases & economics tutorial](tutorial_units.md) works both modes on
one feeder — deriving the bases by hand and demonstrating the SI ≡ per-unit
equality live.

---

### Objective

Minimise total active-power generation cost **rate** (linear in active power;
bilinear in generator/IBR voltage-current variables):

$$\min \sum_{g \in \mathcal{G}} \sum_{k=1}^{|\mathcal{T}_g^\phi|}
  \frac{c^g_k}{1000} \cdot
  \bigl(\Delta v^r_k \, c^{r,g}_{g,k} + \Delta v^i_k \, c^{i,g}_{g,k}\bigr)$$

where $c^g_k$ (currency/kWh) is the **per-phase** energy price — the `cost`
field is a vector with one entry per phase term, indexed by $k$ — and
$\Delta v_k$ is the phase-to-neutral (WYE) or line-to-line (DELTA) voltage at
generator $g$'s $k$-th phase terminal (see [Generators](@ref generators-section)
below). Division by 1000 converts the active-power expression from W to kW, so
the snapshot objective has units currency/h. The same per-phase `cost` vector
prices the voltage source and IBRs. To obtain currency over a time interval,
multiply this rate by the interval duration in hours — the
[units, bases & economics tutorial](tutorial_units.md) reconstructs this
objective by hand from a solved result and prices a full day.

---

### [Current vs. apparent-power limits](@id Current-vs-apparent-power-limits)

Every element that carries a thermal/loading limit supports **both** a current
limit and an apparent-power limit, and both are enforced natively when present:

| Element | Current limit | Power limit | Preferred |
|---|---|---|---|
| Line / cable | `i_max` (per conductor) | `s_max` (per conductor) | **current** |
| Switch | `i_max` (per conductor) | `s_max` (per conductor) | **current** |
| Generator / IBR | `i_max` (per conductor circle) | `s_max` (per-phase circle) | power (nameplate) |
| 2-winding transformer (+ regulators) | `i_max_from`/`i_max_to` (per winding) | `s_rating` (nameplate — **required**, always enforced) | **power** (nameplate); regulators prefer current |
| n-winding transformer | per-winding `i_max` | per-winding `s_max` rating | power (per winding) |

Enforcing **both** on the same element is generally redundant — the tighter one
binds and the other is inert (flagged as
[`W.RED.DUAL_THERMAL_LIMIT`](findings.md)). Which to keep is physics, not taste:

- **Lines and cables** are limited by conductor heating, which the manufacturer
  specifies in amperes — current is the physical driver, so `i_max` is preferred.
- **Transformers** are specified by their **kVA nameplate**; the primary and
  secondary currents differ, so a single apparent-power rating is the natural
  limit. `s_rating` is a **required** transformer field (it also sets the
  winding-1 per-unit impedance base — see
  [transformer models](transformer_models.md)) and is **always enforced** as a
  per-winding coil apparent-power cap, alongside the per-winding
  `i_max_from`/`i_max_to` current cones when present. For `n ≥ 3` windings the cap
  is a per-winding `s_max` rating. One consequence to keep in mind: the primary
  coil carries **load + losses**, so at exactly-rated delivery the from-side cap
  binds slightly *below* the secondary nameplate throughput (by the loss margin).
  To solve a transformer with no loading limit, remove `s_rating` from the network
  dict before calling the OPF (a determined power flow / physics comparison).
- **Regulators** (autotransformer / open-delta) are a subtlety: their true limit
  is the **tap-changer (series-winding) current**, and the kVA is only defined at
  a reference voltage — so, unlike bulk transformers, regulators lean toward
  current. Both are still accepted and enforced.

Two problems make power limits treacherous, and are why current is preferred for
conductors:

1. **The neutral degeneracy.** An apparent-power limit needs a voltage reference.
   For a neutral conductor referenced to a grounded node, that reference voltage
   is ≈ 0, so `S = V∘I* ≈ 0` — the power cap is *vacuous* even while the neutral
   current overheats the conductor. A per-conductor `s_max` with a neutral entry
   is flagged [`W.DOM.POWER_LIMIT_NEUTRAL`](findings.md). A current limit has no
   such failure mode: the neutral is a current-carrying conductor with its own
   ampacity, and can carry *more* current than the phases under unbalance.
2. **The reference ambiguity.** `S = U∘I*`, but relative to *what* `U`? For
   lines/switches the engine uses **ground-referenced per-conductor** power
   ($S_k = v_k\,\overline{I_k}$, $v_k$ to ground) — the direct analogue of the
   per-conductor current limit. Phase-to-ground, phase-to-neutral, and
   phase-to-phase references coincide only when the neutral is grounded and
   undisplaced; they diverge otherwise. (Generator/IBR power circles use the
   device's connection reference — phase-to-neutral for WYE, line-to-line for
   DELTA — see [Generators](@ref generators-section).)

**Precedence.** For lines the rating source is, in order, the **line's own
override → its linecode → unconstrained**; the same precedence applies
independently to `i_max` and `s_max`. Augmentation can convert a power limit into
an equivalent current limit for lines/switches (`I = S/v_\text{ref}`, exact only
at the reference voltage) via the opt-in `apply_power_to_current` recipe flag;
transformers are never converted (their nameplate stays canonical).

---

### Constraints

#### Grounding

```math
v^r_{b,t} = 0, \quad v^i_{b,t} = 0 \qquad \forall\,(b,t) \in \mathcal{G}_\text{nd}
```

#### Voltage sources

Each source terminal $t_k$ is fixed to the specified rectangular value:

```math
v^r_{b,t_k} = V^s_{v,k} \cos\theta^s_{v,k}, \qquad
v^i_{b,t_k} = V^s_{v,k} \sin\theta^s_{v,k}
```

The voltage source is also the network's **current slack**: it injects a free
current $(c^{r,s}_{v,k},\, c^{i,s}_{v,k})$ into KCL at each phase terminal (with
the summed return at the neutral), so power balance at the source bus is met by
the source itself — no auxiliary generator is required. The slack current is
unbounded by default; optional per-phase bounds make it a bounded grid
connection, and an optional `cost` prices imported power (see
[Voltage source as current slack](@ref source-slack) below).

The source-bus **neutral** is additionally fixed to zero
($v^r_{b,n} = v^i_{b,n} = 0$) without being added to $\mathcal{G}_\text{nd}$,
so that KCL is still enforced there and the grid generator's neutral return
current can satisfy it.

#### Voltage magnitude bounds

`v_min`/`v_max` are **per-phase arrays** (phase-to-ground), one entry per phase
terminal in `terminal_names` order. The $k$-th entry bounds the $k$-th phase
terminal, applied at every ungrounded, non-source phase terminal:

```math
\bigl(v^{b}_{\text{min},k}\bigr)^2
\;\leq\;
\bigl(v^r_{b,t_k}\bigr)^2 + \bigl(v^i_{b,t_k}\bigr)^2
\;\leq\;
\bigl(v^{b}_{\text{max},k}\bigr)^2,
\qquad t_k \in \mathcal{T}_b^\phi
```

The phase index $k$ is kept aligned to the array even when a phase is
grounded/source-fixed (those terminals are skipped without shifting $k$). The
**neutral** terminal is not bounded phase-to-ground; instead it has its own
optional **maximum-only** cap `vn_max` (when present and ungrounded):
$\bigl(v^r_{b,n}\bigr)^2 + \bigl(v^i_{b,n}\bigr)^2 \leq \bigl(v^b_{n,\text{max}}\bigr)^2$.
Otherwise the neutral voltage is determined by KCL.

#### Lines

**KVL** (series voltage drop, conductor $k$ of line $\ell$ with total impedance
matrix $\mathbf{R}_\ell + j\mathbf{X}_\ell$ in Ω):

```math
v^r_{b^\text{fr}, t^\text{fr}_k} - v^r_{b^\text{to}, t^\text{to}_k}
= \sum_j \bigl(R_{\ell,kj}\,c^r_{\ell,j} - X_{\ell,kj}\,c^i_{\ell,j}\bigr)
```

```math
v^i_{b^\text{fr}, t^\text{fr}_k} - v^i_{b^\text{to}, t^\text{to}_k}
= \sum_j \bigl(R_{\ell,kj}\,c^i_{\ell,j} + X_{\ell,kj}\,c^r_{\ell,j}\bigr)
```

The impedance matrices capture full mutual coupling between conductors.

**Series current balance** (to-side series current equals the negative of the from-side):

```math
\tilde{c}^r_{\ell,k} = -c^r_{\ell,k}, \qquad \tilde{c}^i_{\ell,k} = -c^i_{\ell,k}
```

**π-model shunt currents** (from linecode ``G_fr``/``B_fr``/``G_to``/``B_to`` fields,
scaled by line length; linear in voltage variables, no new JuMP variables):

```math
I^{\text{sh},r}_{k}(b) = \sum_j \bigl(G_{kj}\,v^r_{b,t_j} - B_{kj}\,v^i_{b,t_j}\bigr),
\qquad
I^{\text{sh},i}_{k}(b) = \sum_j \bigl(G_{kj}\,v^i_{b,t_j} + B_{kj}\,v^r_{b,t_j}\bigr)
```

KCL contributions: $-(c^r_{\ell,k} + I^{\text{sh},r}_k(b^\text{fr}))$ at the from-bus,
$-(\tilde{c}^r_{\ell,k} + I^{\text{sh},r}_k(b^\text{to}))$ at the to-bus.

**Thermal current limit** on the **total** current (series + shunt) at each end:

```math
\bigl(c^r_{\ell,k} + I^{\text{sh},r}_k(b^\text{fr})\bigr)^2
+ \bigl(c^i_{\ell,k} + I^{\text{sh},i}_k(b^\text{fr})\bigr)^2
\leq \bigl(I^\text{max}_{\ell,k}\bigr)^2
```

```math
\bigl(\tilde{c}^r_{\ell,k} + I^{\text{sh},r}_k(b^\text{to})\bigr)^2
+ \bigl(\tilde{c}^i_{\ell,k} + I^{\text{sh},i}_k(b^\text{to})\bigr)^2
\leq \bigl(I^\text{max}_{\ell,k}\bigr)^2
```

!!! note "Current-limit box bounds"
    Wherever a magnitude limit $I^\text{max}$ applies directly to a current
    **variable** — switch, generator, and transformer winding currents — the
    implied box $-I^\text{max} \leq c^r,\,c^i \leq I^\text{max}$ is also placed
    on the variable (it follows from $|c| \leq I^\text{max}$ and is redundant
    with the cone, but bounds the variable from the start, helping the NLP
    solver).

    For **lines** the cone limits the *total* current $I^\text{tot} =
    c_{\ell,k} + I^\text{sh}_k$ (series + π-shunt), not the series variable
    itself, so the series box must absorb the shunt contribution:
    ```math
    |c^r_{\ell,k}|,\,|c^i_{\ell,k}| \;\le\; I^\text{tot,max}_{\ell,k}
      \;=\; I^\text{max}_{\ell,k} \;+\; \textstyle\sum_j |Y^\text{sh}_{kj}|\,V^\text{max}_{j},
    ```
    from $|c_{\ell,k}| = |I^\text{tot} - I^\text{sh}_k| \le I^\text{max} +
    \sum_j |Y^\text{sh}_{kj}|\,V^\text{max}_j$ (triangle inequality), where
    $|Y^\text{sh}_{kj}| = \sqrt{G_{kj}^2 + B_{kj}^2}$ is the from-side π-shunt
    admittance and $V^\text{max}_j$ is a **hard** to-ground voltage-magnitude
    bound on from-terminal $j$. This box is added only when such a $V^\text{max}$
    exists for every terminal feeding row $k$ — i.e. a phase-to-ground bound
    `v_max`, a phase-to-neutral bound `vpn_max` with a grounded neutral, or
    `vpn_max` together with a neutral-to-ground bound `vn_max`. With only a
    `vpn_max` on a floating neutral (no `vn_max`) the to-ground voltage is
    unbounded, so the series variable is **left free** rather than risk an
    unsound box. A transformer's winding with a no-load shunt is the
    one remaining cone-on-an-expression case; it is left cone-only for now (the
    same construction would apply).

**Apparent-power limit** (optional, from `s_max`) on the **total** current at each
end, referenced **to ground per conductor** — the direct power analogue of the
per-conductor current limit:

```math
\bigl(P_{\ell,k}\bigr)^2 + \bigl(Q_{\ell,k}\bigr)^2 \leq \bigl(S^\text{max}_{\ell,k}\bigr)^2,
\qquad
S_{\ell,k} = v_{b^\text{fr},t_k}\,\overline{I^\text{tot}_{\ell,k}}
```

with $P_{\ell,k} = v^r c^{r,\text{tot}} + v^i c^{i,\text{tot}}$ and
$Q_{\ell,k} = v^i c^{r,\text{tot}} - v^r c^{i,\text{tot}}$ (all at from-terminal
$t_k$; a matching cone is added at the to-end when a to-shunt is present).
`s_max` follows the same **element → linecode → unconstrained** precedence as
`i_max`. Both limits may be present and are both enforced, but doing so is
generally redundant — see [current vs. apparent-power limits](@ref
Current-vs-apparent-power-limits) for why current is preferred here and why the
**neutral entry of `s_max` is degenerate** ($v_n \approx 0 \Rightarrow S \approx 0$).

#### Switches

A switch is modelled as an **ideal, zero-impedance branch**: like a line, it
carries per-conductor series current variables $c^r_{sw,k}$, $c^i_{sw,k}$ that
enter KCL at both ends with opposite signs — $-(c^r_{sw,k},\,c^i_{sw,k})$ at the
from-terminal and $+(c^r_{sw,k},\,c^i_{sw,k})$ at the to-terminal — exactly as a
line's series current does. What differs from a line is the series relation: the
KVL voltage-drop equation is replaced by a state-dependent condition, and there
is no $\pi$-shunt.

A **closed** switch replaces KVL with a **zero voltage drop** (lossless short),
imposed per mapped conductor $k$ (neutral included if mapped):

```math
v^r_{b^\text{fr},t^\text{fr}_k} = v^r_{b^\text{to},t^\text{to}_k}, \qquad
v^i_{b^\text{fr},t^\text{fr}_k} = v^i_{b^\text{to},t^\text{to}_k}
```

The current $c_{sw,k}$ is left free and is determined by KCL — it is the
mechanism by which power flows through the closed switch. The two terminals are
held at equal voltage but are **not** merged into one bus (a separate
[`collapse_closed_switches`](@ref) network simplification does that node merge
explicitly, outside the OPF).

An **open** switch has its current variables fixed to zero
($c^r_{sw,k} = c^i_{sw,k} = 0$); the voltage-equality is dropped, so the two
buses are left electrically independent.

When a per-conductor thermal rating `i_max` is present, a **closed** switch is
limited by the same current cone (and box) used for lines, applied to the switch
current variable directly:

```math
\bigl(c^r_{sw,k}\bigr)^2 + \bigl(c^i_{sw,k}\bigr)^2 \leq \bigl(I^\text{max}_k\bigr)^2
```

(see the "Current-limit box bounds" note above). A closed switch with no
`i_max` is left thermally unconstrained; the data-quality provenance checks
flag this case. A switch may also carry an `s_max`, enforced as the same
ground-referenced per-conductor apparent-power cone used for lines (one cone
suffices — a switch has no shunt, so the from and to magnitudes are equal).

!!! note "Why a dedicated switch object"
    A closed switch could be eliminated by merging its two buses, but keeping
    it as its own object preserves the semantics of a controllable tie — which
    the connectivity, provenance, and thermal-protection passes reason about
    directly — and keeps the formulation structured so switch state could
    become a decision variable in a future extension (not currently
    implemented; `open_switch` is fixed input data here).

#### Standalone shunts

A `shunt` object represents an admittance matrix $\mathbf{Y}^{sh} = \mathbf{G}^{sh} + j\mathbf{B}^{sh}$ (S)
connected between a set of bus terminals and ground.  The current it draws is
linear in the voltage variables (no new JuMP variables):

```math
I^{\text{sh},r}_{k} = \sum_j \bigl(G^{sh}_{kj}\,v^r_{b,t_j} - B^{sh}_{kj}\,v^i_{b,t_j}\bigr),
\qquad
I^{\text{sh},i}_{k} = \sum_j \bigl(G^{sh}_{kj}\,v^i_{b,t_j} + B^{sh}_{kj}\,v^r_{b,t_j}\bigr)
```

KCL contribution: $-I^{\text{sh},r}_k$ (current leaves the bus to ground).
Grounded terminals are absent from the voltage variable dict and contribute zero.

#### Capacitor banks

A fixed `capacitor` is a constant susceptance $B = q_\text{rated}/v_\text{rated}^2$
(per phase for WYE, per pair for DELTA) delivering $Q = B\,V^2$. Its connection
is compiled to a terminal-space susceptance matrix $\mathbf{B}$ and injected with
**exactly the shunt contribution above** (with $\mathbf{G}=0$) — so it adds **no
JuMP variables** (linear in the voltages). A continuously-controllable capacitor
(making $B$ a bounded decision variable, $Q=B\,V^2$ bilinear) is a future
extension.

#### Loads

For every load sub-load $k$, define the **voltage drop** across the sub-load
(phase-to-neutral for WYE/SINGLE\_PHASE; line-to-line for DELTA):

```math
\Delta v^r_k = v^r_{b,t^\phi_k} - v^r_{b,n_b}, \qquad
\Delta v^i_k = v^i_{b,t^\phi_k} - v^i_{b,n_b}
```

The **realized power** is always bilinear in these voltage drops and the load
current variables (exact, no approximation):

```math
P_k = \Delta v^r_k \, c^{r,d}_{d,k} + \Delta v^i_k \, c^{i,d}_{d,k}, \qquad
Q_k = \Delta v^i_k \, c^{r,d}_{d,k} - \Delta v^r_k \, c^{i,d}_{d,k}
```

The load `model` field determines the right-hand-side value that $P_k$ and
$Q_k$ are pinned to.

##### Squared-voltage-drop variable

All voltage-dependent models introduce a scalar auxiliary variable per
sub-load:

```math
W_k = (\Delta v^r_k)^2 + (\Delta v^i_k)^2
```

$W_k$ is bounded: $(f \cdot V^{\text{nom}}_k)^2 \leq W_k \leq (c \cdot V^{\text{nom}}_k)^2$
with floor fraction $f = 0.5$ and ceiling fraction $c = 1.5$.  These
conditioning bounds are deliberately wider than any supply standard; the
bus voltage-magnitude bounds are the operative engineering constraints.

When a constant-current term is present, a further auxiliary variable
$s_k = \sqrt{W_k}$ is introduced with $s_k^2 = W_k$, $s_k \geq 0$.

##### Model types

| `model` | $P_k$ pinned to | $Q_k$ pinned to | Quadratic? |
|---|---|---|---|
| `constant_power` (default) | $P^{\text{nom}}_k$ | $Q^{\text{nom}}_k$ | yes |
| `constant_current` | $P^{\text{nom}}_k \cdot s_k / V^{\text{nom}}_k$ | $Q^{\text{nom}}_k \cdot s_k / V^{\text{nom}}_k$ | yes (with $s_k$) |
| `constant_impedance` | $P^{\text{nom}}_k \cdot W_k / (V^{\text{nom}}_k)^2$ | $Q^{\text{nom}}_k \cdot W_k / (V^{\text{nom}}_k)^2$ | yes |
| `zip` | $P^{\text{nom}}_k (\alpha^Z_k W_k/(V^{\text{nom}}_k)^2 + \alpha^I_k s_k/V^{\text{nom}}_k + \alpha^P_k)$ | analogous with $\beta$ | yes (with $s_k$ if $\alpha^I_k \neq 0$) |
| `exponential` | $P^{\text{nom}}_k (W_k/(V^{\text{nom}}_k)^2)^{\gamma^P_k/2}$ | analogous with $\gamma^Q_k$ | only if $\gamma \in \{0,1,2\}$ |

**Integer-exponent routing:** exponential loads with $\gamma \in \{0, 1, 2\}$
are automatically routed to the constant-power, constant-current, or
constant-impedance quadratic path respectively, keeping the formulation
quadratic.  The data-analysis pass ([`load_model_analysis`](@ref)) flags
these loads with `I.LOAD.EXP_ZIP_EQUIVALENT`.

**v\_nom** is required for all models except `constant_power`.  It is the
terminal voltage magnitude at which `p_nom`/`q_nom` are specified: phase-to-neutral (V) for WYE, line-to-line (V) for DELTA.  It may be a scalar
(shared across all sub-loads) or a per-sub-load array.

**DELTA** loads use line-to-line voltage drops: $\Delta v^r_k = v^r_{b,t_k} - v^r_{b,t_{k^+}}$,
$\Delta v^i_k = v^i_{b,t_k} - v^i_{b,t_{k^+}}$ (indices cyclic).

#### [Generators](@id generators-section)

Same bilinear form as WYE loads, with power bounds instead of equalities and
injected (positive) sign convention:

```math
P^{g,\text{min}}_{g,k}
\;\leq\; \Delta v^r_k \, c^{r,g}_{g,k} + \Delta v^i_k \, c^{i,g}_{g,k}
\;\leq\; P^{g,\text{max}}_{g,k}
```

```math
Q^{g,\text{min}}_{g,k}
\;\leq\; \Delta v^i_k \, c^{r,g}_{g,k} - \Delta v^r_k \, c^{i,g}_{g,k}
\;\leq\; Q^{g,\text{max}}_{g,k}
```

Two optional per-phase limits may also be supplied. An **apparent-power
rating** `s_max` $= S^{\max}_{g,k}$ [VA] stamps the power circle

```math
P_{g,k}^2 + Q_{g,k}^2 \;\leq\; \bigl(S^{\max}_{g,k}\bigr)^2 ,
```

and a **current-magnitude limit** `i_max` $= I^{\max}_{g,k}$ [A] stamps the
current circle directly on the terminal current variables

```math
\bigl(c^{r,g}_{g,k}\bigr)^2 + \bigl(c^{i,g}_{g,k}\bigr)^2 \;\leq\;
\bigl(I^{\max}_{g,k}\bigr)^2 .
```

Both are **optional and opt-in** — omit them and the model is unchanged. As for
IBRs, the current circle is the physically faithful thermal limit: since
$|S_{g,k}| = |\Delta v_k|\,|I_{g,k}|$, a current cap makes the deliverable power
roll off with voltage rather than staying flat at $S^{\max}$.

`i_max` is **per conductor**, not per phase: a star (`WYE`/`SINGLE_PHASE`)
generator may carry one extra trailing entry that caps the **neutral return
conductor**. The neutral current is implicit (the device injects on phases and
returns on the neutral, $I_n = -\sum_k I_{g,k}$), so the extra entry stamps a
second-order cone on the summed phase currents,

```math
\Bigl(\textstyle\sum_k c^{r,g}_{g,k}\Bigr)^2 +
\Bigl(\textstyle\sum_k c^{i,g}_{g,k}\Bigr)^2 \;\leq\;
\bigl(I^{\max}_{g,n}\bigr)^2 .
```

So a 3-phase wye `i_max` is length 4 (phases + neutral); a length-3 phases-only
vector is accepted but leaves the neutral unrated (`W.INT.IMAX_NO_NEUTRAL`), which
matters because the neutral can carry **more** current than the phases under
unbalance. A **single-phase** generator has a single current (phase and return
are the same), so its `i_max` is length 1 or 2 — the two entries describe one
conductor pair and collapse to a **single** circle at the tighter limit (never
constraining the variable twice); a length-1 vector is standardised to 2 by the
augmentation pass. `DELTA` has no neutral and takes exactly one entry per conductor.

#### IBRs

IBRs use the same bilinear current/power model as generators, with the
per-phase active and reactive powers

```math
P_{n,k} = \Delta v^r_k \, c^{r,n}_{n,k} + \Delta v^i_k \, c^{i,n}_{n,k},
\qquad
Q_{n,k} = \Delta v^i_k \, c^{r,n}_{n,k} - \Delta v^r_k \, c^{i,n}_{n,k}.
```

The voltage difference $\Delta v_k$ depends on the IBR **topology**:

- **`FOUR_LEG`** — phase-to-neutral, $\Delta v_k = v_{b,t_k} - v_{b,t_n}$, one
  current per phase conductor; the neutral is the last terminal in
  `terminal_map`.
- **`THREE_LEG`** — line-to-line (delta), $\Delta v_k = v_{b,t_k} - v_{b,t_{k^+}}$
  with cyclic index $k^+ = (k \bmod n) + 1$; no neutral current.
- **`SINGLE_PHASE`** — phase-to-reference, $\Delta v = v_{b,t_1} - v_{b,t_2}$,
  a single current.

Each phase $k$ is constrained by an active-power box and, when an apparent-power
rating $S^{\max}_{n,k}$ is given, an apparent-power circle:

```math
P^{\min}_{n,k} \;\leq\; P_{n,k} \;\leq\; P^{\max}_{n,k},
\qquad
P_{n,k}^2 + Q_{n,k}^2 \;\leq\; \bigl(S^{\max}_{n,k}\bigr)^2 .
```

Optionally, a per-phase **current-magnitude limit** `i_max` $= I^{\max}_{n,k}$
[A] may be supplied. When present it is stamped directly on the converter
current variables:

```math
\bigl(c^{r,n}_{n,k}\bigr)^2 + \bigl(c^{i,n}_{n,k}\bigr)^2 \;\leq\;
\bigl(I^{\max}_{n,k}\bigr)^2 .
```

This is the physically faithful limit for a voltage-source converter
(D-STATCOM, smart inverter): because $|S_{n,k}| = |\Delta v_k|\,|I_{n,k}|$, a
current cap makes the reactive capability roll off **≈ linearly** with voltage
($Q^{\max} \approx |\Delta v_k|\,I^{\max}$) rather than staying flat at
$S^{\max}$ — the constant-MVA idealization the apparent-power circle alone
implies. `i_max` is **optional and opt-in**: omit it and the model is unchanged;
supply it to model the low-voltage var rolloff of a real converter.

Like the generator, `i_max` is **per conductor**: a `FOUR_LEG` IBR carries a
trailing entry capping the **neutral conductor** ($\sum_k c^{r,n}_{n,k}$,
$\sum_k c^{i,n}_{n,k}$) — recommended, since a four-wire converter doing unbalance
compensation can drive a neutral current *larger* than any phase. A phases-only
length-3 vector warns (`W.INT.IMAX_NO_NEUTRAL`). A `SINGLE_PHASE` IBR has a single
current, so its `i_max` is length 1 or 2 and collapses to one circle at the tighter
limit. `THREE_LEG` (delta) has no neutral.

Reactive power is governed in one of two mutually exclusive ways:

- **Box bounds** (default): $Q^{\min}_{n,k} \leq Q_{n,k} \leq Q^{\max}_{n,k}$.
  These are normally filled by the augmentation pass before the OPF runs.
- **Constant power factor**: when the IBR references a `control_profile`
  with a signed `power_factor.pf`, $Q$ is coupled to $P$ by the exact equality

  ```math
  \operatorname{sign}(\mathrm{pf}) \, Q_{n,k}
  + \tan\!\bigl(\arccos|\mathrm{pf}|\bigr) \, P_{n,k} = 0,
  ```

  with $\mathrm{pf} > 0$ lagging (absorbing VAr) and $\mathrm{pf} < 0$ leading
  (injecting VAr).
- **Volt-var droop**: when the `control_profile` declares a `volt_var`
  sub-object, $Q$ is pinned to a piecewise-linear function of a **monitored
  voltage magnitude** $U_{n,k}$,
  $Q_{n,k} = Q^{\text{base}}_{n,k}\, f^{\mathrm{VV}}(U_{n,k})$ (an equality — the
  IBR follows the curve).

Active power follows either the box upper bound above or, when the
`control_profile` declares a `volt_watt` sub-object, a **Volt-watt** curtailment
cap $P_{n,k} \leq P^{\text{base}}_{n,k}\, f^{\mathrm{VW}}(U_{n,k})$.

The monitored voltage $U_{n,k}$ is **independent of the power voltage difference**
$\Delta v_k$ above: it is chosen per curve by the curve's `voltage_reference`
(`volt_var` and `volt_watt` may each pick their own), one of the six
`voltage_reference_type` values — a *quantity* crossed with an *aggregation*:

| `voltage_reference` | monitored quantity | aggregation |
|---|---|---|
| `PN_PER_PHASE` (default) | phase-to-neutral $\lvert v_{b,t_k}-v_{b,t_n}\rvert$ | per phase |
| `PG_PER_PHASE` | phase-to-ground $\lvert v_{b,t_k}\rvert$ | per phase |
| `PP_PER_PHASE` | phase-to-phase $\lvert v_{b,t_k}-v_{b,t_{k^+}}\rvert$ (cyclic $k^+$) | per phase |
| `PN_AVERAGED` / `PG_AVERAGED` / `PP_AVERAGED` | as above | every phase sees the mean of the per-phase magnitudes |

Phase-to-ground and phase-to-neutral differ only when the neutral is displaced
from ground. For a `SINGLE_PHASE` IBR the two phase-pair quantities (`PN`/`PP`)
coincide — the reference is `terminal_map[2]` — and aggregation is moot. The
legacy IBR-level `voltage_aggregation` field (`PER_PHASE`/`AVERAGE`), when present,
overrides the aggregation the enum implies, for backward compatibility.
`THREE_LEG` droop is unsupported (box bounds, with a warning).

##### STATCOMs (D-STATCOMs)

A **STATCOM** — a *D-STATCOM* in distribution-system terminology — is a
shunt-connected voltage-source converter with no active-power source. It is
modelled as an IBR with `prime_mover = "STATCOM"`: there is no separate object
category, because a STATCOM is physically the same VSC-shunt as any other
grid-tied inverter, exchanging reactive power bounded by the converter rating.
The augmentation pass clamps active power to zero
($P^{\min}_{n,k} = P^{\max}_{n,k} = 0$, converter losses neglected) and exposes
the full per-phase rating as symmetric reactive capability
($Q^{\max}_{n,k} = S^{\max}_{n,k}$, $Q^{\min}_{n,k} = -S^{\max}_{n,k}$), after
which the apparent-power circle, the optional current-magnitude limit `i_max`,
and any Volt-var `control_profile` apply unchanged. The
[`add_statcom!`](@ref) helper writes such an IBR directly. A battery-backed
D-STATCOM that can also dispatch active power is simply an IBR with a non-zero
`prime_mover` (e.g. `BATTERY`).

###### Shared DC link: active power circulation between phases

A four-wire converter's three phase legs share a single DC link, so the
*per-phase* active powers are not independent — they are coupled by the net
DC-side power balance. When an IBR sets `dc_link_coupled = true`, the engine adds
the aggregate constraint

```math
P^{dc}_{\min} \;\le\; \sum_{k} P_{n,k} \;\le\; P^{dc}_{\max},
```

over that IBR's phases, while each phase's $P_{n,k}$ is freed within its
apparent-power circle. With $P^{dc}_{\min} = P^{dc}_{\max} = 0$ — the default the
augmentation derives for a STATCOM — the converter exchanges **no net active
power** yet may *circulate* active power between phases: sourcing real power on a
heavily-loaded phase and sinking it on a lightly-loaded one. Because LV feeders
are resistive ($R \gg X$), this active redistribution is a far stronger lever on
per-phase voltage and unbalance than reactive support alone, which is the central
result of [the D-STATCOM unbalance study](@ref statcom-unbalance). The
constraint is the steady-state DC-link power balance of the four-wire converter
models in Heidari & Geth (2024) and Deakin, Heidari & Deng (2025); for a
non-STATCOM source (e.g. PV) the augmentation defaults the band to
$[0, P^{\text{avail}}]$, so the same coupling lets a curtailable inverter
redistribute its available power across phases.

##### Piecewise-linear droop encoding

Each characteristic $f$ through non-decreasing breakpoints
$(\bar x_i, \bar y_i)$, clamped flat outside the range, is written as a sum of
shifted/scaled rectified-linear (ReLU) terms,

```math
f(U) = \bar y_1 + \sum_i a_i \,\operatorname{ReLU}(U - \bar x_i),
```

where each interior segment contributes a
$\bigl(+a_i, \bar x_i\bigr) / \bigl(-a_i, \bar x_{i+1}\bigr)$ pair so the slope
telescopes. For a gradient-based solver the kinked
ReLU is replaced by the smooth softplus surrogate
$\operatorname{ReLU}^{\varepsilon}(x) = \varepsilon\,\log(1+e^{x/\varepsilon})$,
evaluated with the numerically stable `log1pexp`/`logistic` from
[StatsFuns.jl](https://github.com/JuliaStats/StatsFuns.jl) and registered as a
JuMP nonlinear operator (analytic derivatives) so Ipopt differentiates it
exactly. $\varepsilon \to 0$ recovers the exact ReLU; the relative smoothing is
the `volt_var_watt_eps` keyword of [`solve_opf`](@ref). The
[Smooth droop encoding](relu_softplus_encoding.md) tech note derives the
closed-form derivatives, the $\varepsilon\log 2$ error bound, and the numerically
stable `log1pexp`/`logistic` evaluation in full.

Breakpoint voltages are SI volts (phase-to-neutral) and are scaled into model
units at build time, so the droop is identical in SI and per-unit mode. Droop is
applied for `SINGLE_PHASE` and `FOUR_LEG` only; a `THREE_LEG` (delta) IBR
has too few degrees of freedom for a per-phase droop, so a profile on it is
ignored (box bounds retained) with a warning. Regional default characteristics
(e.g. AS/NZS 4777.2:2020 "Australia A" for Queensland) are injected by
[`augment_case`](@ref) from the `[augment.smart_ibr]` config section.

By default each phase responds to its own magnitude $U_{n,k}$. Setting the
IBR field **`voltage_aggregation`** to `"AVERAGE"` (default `"PER_PHASE"`) instead
feeds every phase the mean of the phase magnitudes,
$\bar U_n = \tfrac{1}{m}\sum_k U_{n,k}$, as the common reference for both the
Volt-var and Volt-watt curves — modelling IBRs that regulate on the average
terminal voltage rather than per phase. The setting only affects multi-phase
`FOUR_LEG` IBRs; on a `SINGLE_PHASE` IBR it is a no-op and emits a
warning. The [VVWO tutorial](tutorial_vvwo.md) works a Volt-var-Watt scenario
end to end, solving the droop control and the network simultaneously.

The IBR current variables enter KCL with the same sign convention as
generators (injection positive into the bus); for `FOUR_LEG` the negated phase
current is also added to the neutral terminal.

#### Transformers

Transformer constraints are **linear at a fixed tap**.  The turns ratio for the four
two-winding subtypes is $N = V^\text{ref}_\text{fr} / V^\text{ref}_\text{to}$
(SI volts), optionally scaled by a dimensionless multiplier `tap`
($N = N_0\cdot\texttt{tap}$).  The two regulator subtypes
(`single_phase_autotransformer`, `open_delta_regulator`) use an effective ratio
$n_\text{eff}$ derived from `tap_ratio` and `regulator_type` (see below).

##### Continuous tap optimisation

The tap can be a **free continuous decision variable** instead of a constant, so the
OPF chooses OLTC/regulator settings to reduce losses and hold voltages in band. It
follows the implicit free-variable pattern (bounds make it optimisable):

| subtype | tap field | free when |
|---|---|---|
| `single_phase`, `delta_wye`, `wye_delta` | `tap` (mult. on $N_0$) | `tap_min` < `tap_max` |
| `single_phase_autotransformer` | `tap_ratio` | `tap_ratio_min` < `tap_ratio_max` |
| `open_delta_regulator` | `tap_ratio` (per reg.) | `tap_ratio_min` < `tap_ratio_max` (element-wise) |

A free tap adds **one variable per tap** equal to the effective from→to ratio
coefficient ($N$ for `single_phase`, $n_\text{eff}$ otherwise). Using the ideal-core
coupling $N\,I_\text{series} = -I_\text{to}$, the voltage drop stays **quadratic** in
the tap (no cubic), so the existing Ipopt NLP solves it unchanged. For the YY family
the from-winding leakage of an OLTC scales with the winding turns ($\propto
\texttt{tap}^2$); referred to the to side it is **constant**
($R' = r_\text{to} + r_\text{fr}/N_0^2$, $X' = x_\text{to} + x_\text{fr}/N_0^2$) and
the drop is $v_\text{fr} - N v_\text{to} = -N\,(R'\,I_\text{to} \mp X'\,I_\text{to})$,
matching OpenDSS's turns-scaled `Yprim`; at `tap = 1` it is identical to the
fixed-tap stamping. (The `delta_wye`/`wye_delta` coupled delta-arm carries the same
exact ``\texttt{tap}^2`` referral — the short-circuit impedance referred to the
tapped side scales as ``\texttt{tap}^2``, the non-tapped side is held at nominal.) The
solved tap is reported in the [result dictionary](results.md) as `tap`/`tap_ratio`
with a `tap_binding` flag. See the
[tap-optimisation tutorial](@ref tap-optimisation).

Because every subtype is expressed as voltage/current **equalities** (the IVR
impedance form $v_\text{fr} - N v_\text{to} = Z\,I$) rather than a nodal
admittance $Y = Z^{-1}$, **zero winding resistance and zero leakage reactance are
admissible**: the constraints degrade to the ideal-transformer relation
$v_\text{fr} = N v_\text{to}$ (and, for `n_winding`, $V_1^r = V_{i+1}^r$ with
$\sum_k N_k I_k = 0$) with no inversion and no singularity. This holds for *all*
subtypes and is covered by the "ideal (zero-impedance) transformers" tests.
(The separate `transformer_yprim`/`nwinding_yprim` **admittance export** is the
one place that genuinely inverts $Z$ and so is singular at zero impedance — it
warns and skips there.)

---

**`single_phase` — Γ-equivalent model**

Series impedance $R_x = R_1 + N^2 R_2$, $X_x = X_1 + N^2 X_2$ is referred
to the HV (from) side, where $R_1, X_1$ (`r/x_series_from`, Ω on HV base)
are the HV winding values and $R_2, X_2$ (`r/x_series_to`, Ω on LV base)
are the LV winding values.  For each per-phase pair index $k$:

```math
v^r_{b^\text{fr},t^\text{fr}_k} - N\,v^r_{b^\text{to},t^\text{to}_k}
= R_x\,c^{r,x}_{x,\text{fr},k} - X_x\,c^{i,x}_{x,\text{fr},k}
```

```math
N\,c^{r,x}_{x,\text{fr},k} + c^{r,x}_{x,\text{to},k} = 0 \quad\text{(and imaginary)}
```

The no-load shunt $G_0 + jB_0$ (`g_no_load`, `b_no_load`, S) sits at the
HV terminals (phase-to-ground).  The total HV terminal current entering the
bus is series + shunt:

```math
I^\text{fr,term}_{x,k} =
  c^{r,x}_{x,\text{fr},k}
  + G_0\,v^r_{b^\text{fr},t^\text{fr}_k}
  - B_0\,v^i_{b^\text{fr},t^\text{fr}_k}
```

When all loss fields are absent or zero the model reduces to the ideal
$v^r_{b^\text{fr},t^\text{fr}_k} = N\,v^r_{b^\text{to},t^\text{to}_k}$.

---

**`center_tap` — coupled-coil 3-winding (primitive admittance)**

Terminal map: `terminal_map_from = [t_ph, t_n]` (HV phase, HV neutral),
`terminal_map_to = [t₁, tₙ, t₂]` (leg-1, center-tap neutral, leg-2).
$V^\text{ref}_\text{to}$ is the **per-leg** voltage (e.g. 120 V for a
120-0-120 V unit), so $N = V^\text{ref}_\text{fr}/V^\text{ref}_\text{to} = 60$
for a 7.2 kV / 120 V unit.

The split-phase unit is a genuine 3-winding transformer whose two LV
half-windings are tightly coupled on the shared core. Modelling each leg with an
*independent* secondary impedance drop omits that mutual coupling and spreads the
two legs apart under load. The OPF therefore imposes the OpenDSS-consistent 5×5
primitive admittance $Y_\text{CT}$ (the same one the Ybus exporter builds; see
[Transformer primitive admittance](spec/transformer-admittance.md)) as nodal current injections —
element current into each of the five terminals
$\mathbf I = Y_\text{CT}\,\mathbf V$ — and pins the per-winding current variables
(HV series, leg-1, centre, leg-2) to those injections for the `i_max` limits and
loss accounting. $Y_\text{CT}$ is reconstructed from the symmetric star leakage
arms $Z_1 = R_1+jX_1$ (HV) and $Z_2 = R_2+jX_2$ (each LV leg), with winding 3
dotted at the centre tap (leg-2 voltage span $V_{t_n} - V_{t_2}$). It matches
OpenDSS's transformer `Yprim` to machine precision.

The implied current relations are the ampere-turn

```math
N\,c^{r,x}_{x,s} + c^{r,x}_{x,\ell_1} - c^{r,x}_{x,\ell_2} = 0
\quad\text{(and imaginary)}
```

and the centre-tap KCL (variable index 2 on `to` side):

```math
c^{r,x}_{x,n} + c^{r,x}_{x,\ell_1} + c^{r,x}_{x,\ell_2} = 0
\quad\text{(and imaginary)}
```

The no-load shunt $G_0 + jB_0$ is folded into $Y_\text{CT}$ at the HV phase
terminal $t^\text{ph}$ (phase-to-ground). For an ideal core (zero series
impedance) $Y_\text{CT}$ is singular, so both legs are instead pinned directly to
$V_\text{hv}/N$ and the relations above route the currents.

!!! note "Leakage from OpenDSS XHL/XLT/XHT"
    For a 3-winding OpenDSS unit, the per-pair leakage values must be
    star-converted before storing in `x_series_from`/`x_series_to`:
    ```
    x_series_from = (XHL + XHT − XLT) / 2 × Vhv² / (100 · s_rating)
    x_series_to   = (XHL + XLT − XHT) / 2 × Vlv² / (100 · s_rating)
    ```
    Using the 2-winding shortcut (full `XHL` on the HV side, `x_series_to = 0`)
    drops the LV-side leakage and spreads the legs apart under load.
    PowerIO v0.7's BMOPF export carries the correct star split for
    [`from_dss`](@ref); BMOPFTools normalizes the no-load shunt convention.

---

**Wye–delta (Yd) / Delta–wye (Dy)** — effective turns ratio:

$$n_\text{eff} = \begin{cases} \sqrt{3}/N & \text{Yd} \\ N\sqrt{3} & \text{Dy} \end{cases}$$

**Loss model (per-winding T).** Matching the OpenDSS / PMD reference, each
winding carries its own series impedance — $R^\text{w}/X^\text{w}$
(`r/x_series_from`, wye winding) and $R^\text{d}/X^\text{d}$
(`r/x_series_to`, delta winding) — and a `g/b_no_load` core-loss shunt sits at
the from-side (HV) phase terminals. `g_no_load` is the **total** core-loss
conductance, split equally across the from-side phases and stamped
phase-to-ground; it is referred to the line-to-neutral stamping voltage
$V_\text{LN} = v_\text{ref,from}/\sqrt 3$, so that the total core loss
$g_\text{no\_load}\,V_\text{LN}^2 = \%\text{noloadloss}\cdot S_\text{rated}$
matches OpenDSS. The legacy single `r_series`/`x_series` is
read as $R^\text{w} = R_\text{series}$, $R^\text{d} = 0$, recovering the ideal
delta. The series drop enters the voltage equation behind the ideal transform:

Voltage (delta line-to-line = wye phase-to-neutral × $n_\text{eff}$, less the
winding series drop, indices cyclic):

```math
v^r_{\text{del},t_k} - v^r_{\text{del},t_{k^+}}
= n_\text{eff}\bigl(v^r_{\text{wye},t^\phi_k} - v^r_{\text{wye},n_\text{wye}}\bigr)
  - \bigl(R^\text{w} c^{r,x}_{x,\text{wye},k} - X^\text{w} c^{i,x}_{x,\text{wye},k}\bigr)
  - n_\text{eff}\bigl(R^\text{d} c^{r,x}_{x,\text{del},k} - X^\text{d} c^{i,x}_{x,\text{del},k}\bigr)
```

When all impedance fields are zero this collapses to the ideal transform.

Current (transpose of voltage transform, power-conservative):

```math
n_\text{eff} \, c^{r,x}_{x,\text{del},k}
= c^{r,x}_{x,\text{wye},k} - c^{r,x}_{x,\text{wye},k^-}
```

Star-point KCL at the wye neutral:

```math
c^{r,x}_{x,\text{wye},n} + \sum_{k} c^{r,x}_{x,\text{wye},k} = 0
```

---

**`single_phase_autotransformer` — step voltage regulator**

A fixed-tap regulator modelled as an autotransformer: the series and common
windings share a node, so from and to are galvanically tied (not isolated).
With fixed tap ratio $a$ (`tap_ratio`, regulated/source) the effective from→to
ratio is

```math
n_\text{eff} = \begin{cases} 1/a & \text{Type B (standard SVR, default)} \\ a & \text{Type A} \end{cases}
```

The voltage and current-coupling constraints are the `single_phase` YY form
with $N := n_\text{eff}$ and a series impedance $R_x = R_1 + n_\text{eff}^2 R_2$,
$X_x = X_1 + n_\text{eff}^2 X_2$:

```math
\bigl(v^r_{b^\text{fr},t^\text{ph}} - v^r_{b^\text{fr},t^\text{n}}\bigr)
- n_\text{eff}\bigl(v^r_{b^\text{to},t^\text{ph}} - v^r_{b^\text{to},t^\text{n}}\bigr)
= R_x\,c^{r,x}_{x,\text{fr}} - X_x\,c^{i,x}_{x,\text{fr}}
```

```math
n_\text{eff}\,c^{r,x}_{x,\text{fr}} + c^{r,x}_{x,\text{to}} = 0 \quad\text{(and imaginary)}
```

The galvanic tie shows up in the **shared-neutral KCL** — both the series and
the to-side return close at the common neutral (unlike the isolated YY, whose
from-neutral carries only the from-side return):

```math
I_n + c^{r,x}_{x,\text{fr}} + c^{r,x}_{x,\text{to}} = 0
\;\;\Longleftrightarrow\;\;
I_n + (1 - n_\text{eff})\,c^{r,x}_{x,\text{fr}} = 0
```

A sign error here would produce negative transformer losses. A lossless ideal
regulator ($R=X=G=B=0$) collapses to $v_\text{to} = n_\text{eff}\,v_\text{fr}$.

---

**`open_delta_regulator` — monolithic open-delta**

Two single-phase autotransformer windings connected **line-to-line** across the
phase pairs implied by `connection` (`ABBC`/`BCAC`/`CABA`); per-regulator taps
`tap_ratio = [a_1, a_2]` give $n_{\text{eff},j}$ as above. For each regulator
$j$ spanning from-phase pair $(p, q)$ and the matching to-phase pair:

```math
\bigl(v^r_{b^\text{fr},t_p} - v^r_{b^\text{fr},t_q}\bigr)
- n_{\text{eff},j}\bigl(v^r_{b^\text{to},t_p} - v^r_{b^\text{to},t_q}\bigr)
= R_{x,j}\,c^{r,x}_{x,\text{fr},j} - X_{x,j}\,c^{i,x}_{x,\text{fr},j}
```

```math
n_{\text{eff},j}\,c^{r,x}_{x,\text{fr},j} + c^{r,x}_{x,\text{to},j} = 0
```

KCL injects each regulator's line current at the two phases it spans
($+I$ at one, $-I$ at the other). The phase **common to both regulators** (B in
the ABBC arrangement) is a **galvanic straight-through** — a zero-impedance wire
with its own current variable, enforcing

```math
v_{b^\text{fr},t_\text{shared}} = v_{b^\text{to},t_\text{shared}}
```

This is the physically-correct "common neutral" model of Yan et al. (2018): the
shared phase passes through unchanged while the two regulated line-to-line
voltages are boosted by their taps. Without it the line-to-line voltages are
still correct but the per-phase reference floats (the unphysical
"unspecified neutral" model). See
[Transformer primitive admittance](spec/transformer-admittance.md) for the matching bus-admittance form.

---

**`n_winding` — general n-winding (ZB model, WYE and/or DELTA)**

The general n-winding transformer keeps the **explicit per-winding current
variables** $c^{r,w}_{x,j,k}, c^{i,w}_{x,j,k}$ (one per winding $j$ and phase
$k$) — it is the same rectangular IVR style as the other devices, **not** an
admittance model that eliminates currents. Keeping both current and voltage
variables (rather than substituting an admittance) is what lets the leakage be
parameterised down to **zero impedance** (a lossless / ideal transformer): the
leakage equation below stays well-posed at $ZB = 0$ (it collapses to the ideal
ratio $V^r_1 = V^r_{i+1}$) with no division by an impedance.

The leakage is the OpenDSS-style $ZB$ matrix referred to winding 1 (an
$(n{-}1)\times(n{-}1)$ impedance, exact for any $n$; see
[Conversion § n-winding](@ref n-winding)). With referred currents
$I^r_{j} = N_j\,c^{w}_{x,j,k}$ ($N_j = V^\text{ref}_j / V^\text{ref}_1$) and
referred coil voltages $V^r_j = U_{j,k}/N_j$, per phase/leg $k$:

```math
\sum_{j=1}^{n} N_j\,c^{r,w}_{x,j,k} = 0 \quad\text{(ideal core / ampere-turn; and imaginary)}
```

```math
V^r_1 - V^r_{i+1} = -\sum_{j=1}^{n-1} ZB_{i,j}\,I^r_{j+1},
\qquad i = 1,\dots,n-1 \quad\text{(complex; real/imag split)}
```

The per-leg leakage/ampere-turn structure is identical for `WYE` and `DELTA`
windings — only the coil↔terminal incidence differs. The coil voltage $U_{j,k}$
is **phase-to-neutral** for a `WYE` winding and **line-to-line** (phase $k$ minus
its delta partner $k^{\pm}$, selected by the winding's `delta_roll`) for a
`DELTA` winding, whose $V^\text{ref}$ is its line-to-line coil voltage — so the
$\sqrt{3}$ coil-base factor lives entirely in $N_j$, and $V^r_j$ stays consistent
(per-unit needs no $\sqrt3$ correction, since the bus base is line-to-neutral).
A `WYE` coil injects $-c^{w}_{x,j,k}$ at its phase and $+\sum_k c^{w}_{x,j,k}$ at
its neutral; a `DELTA` coil injects $-c^{w}_{x,j,k}$ at phase $k$ and
$+c^{w}_{x,j,k}$ at its delta partner. Referencing winding 1 folds out the core
node, so **no internal star-node variable is introduced**; the optional no-load
shunt sits across winding 1. The constraints are all linear. This path is
independent of the two-bus transformer code and is validated against OpenDSS's
own 3- and 4-winding solves, including delta (`Dyn`/`Dyyn`) configurations.

#### Kirchhoff's Current Law

KCL is enforced at every ungrounded terminal. Each component accumulates its
signed current contribution (positive = into bus) into per-terminal expressions
$\kappa^r_{b,t}$ and $\kappa^i_{b,t}$:

```math
\kappa^r_{b,t} = 0, \qquad \kappa^i_{b,t} = 0
\qquad \forall\,(b,t) \notin \mathcal{G}_\text{nd}
```

Sign conventions:

| Component | Terminal | KCL contribution |
|---|---|---|
| Line from-side | from terminal | $-c^r_\ell$ (leaves) |
| Line to-side | to terminal | $+c^r_\ell$ (enters, since $\tilde{c} = -c$) |
| Load WYE | phase terminal | $-c^{r,d}$ (consumed) |
| Load WYE | neutral terminal | $+c^{r,d}$ (return) |
| Load DELTA | positive terminal | $-c^{r,d}$ |
| Load DELTA | negative terminal | $+c^{r,d}$ |
| Generator WYE | phase terminal | $+c^{r,g}$ (injects) |
| Generator WYE | neutral terminal | $-c^{r,g}$ (return) |
| Voltage source | phase terminal | $+c^{r,s}$ (slack injects) |
| Voltage source | neutral terminal | $-c^{r,s}$ (return) |
| Transformer | each terminal | $-c^{r,x}$ (winding current leaves) |

---

## [Voltage source as current slack](@id source-slack)

The voltage source fixes its terminal voltages **and** closes KCL at the source
bus through its own slack current $(c^{r,s}_{v,k},\, c^{i,s}_{v,k})$ — there is no
separate slack generator and no `_auto_slack` injection. This mirrors the
OpenDSS/PMD `Vsource`, which is both a voltage reference and an (implicit)
unbounded power injection.

Because the terminal voltages are fixed, the per-phase power is **linear** in the
slack current:

```math
P^s_{v,k} = \Delta v^r_k \, c^{r,s}_{v,k} + \Delta v^i_k \, c^{i,s}_{v,k}, \qquad
Q^s_{v,k} = \Delta v^i_k \, c^{r,s}_{v,k} - \Delta v^r_k \, c^{i,s}_{v,k}
```

where $\Delta v$ is the phase-to-neutral voltage at the source bus. Optional
fields on the `voltage_source` object shape the slack:

- **`p_min`/`p_max`/`q_min`/`q_max`** — per-phase box bounds. Absent ⇒ unbounded
  (pure power-flow slack); present ⇒ a bounded grid connection.
- **`cost`** — a per-phase vector of linear active-power prices (one entry per
  phase term) added to the objective; exact since the source voltage is fixed.

The source-bus **neutral** is fixed to zero and carries the summed slack return
current, so neutral KCL is satisfied without a neutral voltage reference.

This makes the source play three roles with one object: unbounded power-flow
slack (no bounds, no cost), bounded grid connection (bounds), and priced
import/export (cost). The augmentation pass sets `cost` on the
source by default (see [Augmentation](augmentation.md)).

!!! note "Independent generators at the source bus"
    The voltage source is already the slack, so an *unbounded* generator
    co-located at the source bus creates a second free current injection at a
    fixed-voltage bus — a degenerate dispatch split. The pre-flight check flags
    this (`W.PRE.SOURCE_BUS_GENERATOR` for unbounded, `I.PRE.SOURCE_BUS_GENERATOR`
    for bounded); model such limits/cost on the voltage source instead.

---

## Warm-start initialisation

Both solvers seed Ipopt with phase-correct voltage start values (rectangular
`v_nom·∠angle`) so the NLP converges to the physical solution without a load-flow
pre-solve. Phase terminals use the canonical three-phase angles (0°, −120°, +120°)
taken from the voltage source. **Split-phase zones are special-cased**: a zone fed
by a `center_tap` transformer (see [`I.PROV.SPLIT_PHASE_ZONE`](findings.md)) has its
two legs initialised **anti-phase** — θ and θ+180° about the centre-tap neutral,
where θ is the feeding MV phase angle — rather than 120° apart. Without this, every
centre-tap secondary starts with a 60° leg error.

## Feasibility relaxation

`solve_feasibility_opf` adds an **elastic slack current**
$(c^{r,\varepsilon}_{b,t},\, c^{i,\varepsilon}_{b,t})$ at every ungrounded,
non-source terminal. These variables can absorb any KCL residual at those
terminals, but they do not relax contradictory source fixes, inconsistent hard
bounds, or other hard equalities:

```math
\kappa^r_{b,t} + c^{r,\varepsilon}_{b,t} = 0, \qquad
\kappa^i_{b,t} + c^{i,\varepsilon}_{b,t} = 0
```

The primary cost objective is replaced by the $\ell_2^2$ norm of all slack
injections:

```math
\min \sum_{(b,t)} \Bigl[\bigl(c^{r,\varepsilon}_{b,t}\bigr)^2
                       + \bigl(c^{i,\varepsilon}_{b,t}\bigr)^2\Bigr]
```

The implementation adds a tiny linear transformer-current tie-break to select a
numerical representative when Yd/Dy delta circulation is unobservable. Therefore
the raw solver `objective` is an implementation metric; interpret the SI-valued
slack fields instead.

All device models and non-KCL hard constraints — including voltage, sequence,
thermal, and angle limits — are built identically to `solve_opf`. The deliberate
changes are the elastic KCL currents and the slack-norm objective. Thus the
relaxed feasible set contains the original feasible set; it is not identical to
it, and contradictory remaining hard constraints can still make it empty.

A converged, independently residual-checked zero-slack point demonstrates
numerical feasibility. Non-zero slacks at $(b,t)$ show where that local relaxed
solution uses external current; they do not prove that no zero-slack solution
exists elsewhere.

```julia
fopf   = solve_feasibility_opf(net)
diag   = diagnose_infeasibility(fopf, net)

println(diag["is_feasible"])            # local classification from status/slack
println(diag["total_infeasibility_A"])  # L2 norm of all slacks (A)
```

## [Solver control and extending the formulation](@id extending-the-formulation)

All three entry points (`solve_opf`, `solve_pf`, `solve_feasibility_opf`)
accept:

- `verbose=true` — stream the solver log instead of silencing it.
- `solver_options` — an iterable of `name => value` pairs applied as raw
  solver attributes *after* the problem's own defaults (so yours win), e.g.
  `solver_options = ["max_iter" => 3000, "tol" => 1e-9]` for Ipopt.
- `optimizer` — any JuMP-compatible NLP optimizer, e.g.
  `optimizer = MadNLP.Optimizer` (Ipopt is only the default; the one
  Ipopt-specific setting in `solve_feasibility_opf` is skipped with a warning
  for other solvers).

Researchers who need to modify the formulation — add a constraint, swap the
objective, or stamp a new device — can pass a **`model_hook!`** without
forking the package. The hook is called as `hook!(ctx)` after the standard
model is built and *before* Kirchhoff's current law is enforced and the model
is solved. Use the public extension interface:

| API | contents |
|---|---|
| `opf_model(ctx)` | the JuMP model — `@constraint`/`@objective` work directly |
| `opf_network(ctx)` | the engine's working copy (snapshot + per-unit applied) |
| `opf_bases(ctx)` | SI↔working-coordinate bases, or `nothing` in SI mode |
| `opf_object(ctx, key)` | a native or extension-owned object under a semantic key |
| `add_terminal_injection!(ctx, …)` | supported KCL contribution seam |

Example — cap one generator's phase active power below its box bound:

```julia
using JuMP
result = solve_opf(net; model_hook! = ctx -> begin
    vr = opf_object(ctx, opf_bus_voltage_key("bus1", "1"))
    vi = opf_object(ctx, opf_bus_voltage_key("bus1", "1"; component=:imag))
    crg = opf_object(ctx, opf_generator_current_key("g1", 1))
    cig = opf_object(ctx,
        opf_generator_current_key("g1", 1; component=:imag))
    bases = opf_bases(ctx)
    scale = bases === nothing ? 1.0 : bases.s_base
    @constraint(opf_model(ctx), vr*crg + vi*cig <= 150e3 / scale)
end)
```

The model is solved in the model's working units: SI by default, per-unit
when `per_unit=true` — scale hand-written constants accordingly.

A `solution_hook!(ctx, result)` runs after the solve and before per-unit
unwrapping, with the model still live: read `JuMP.value` of the variables a
`model_hook!` created and append your own keys to `result` (scale to SI via
`opf_bases(ctx)`). A hook device that writes its net terminal power to
`result["custom_injection"] = Dict("p"=>…, "q"=>…)` (SI, generator sign) is
counted by `profile_solution`'s power-balance check, so a correct solve no
longer trips a spurious `W.SOL.POWER_BALANCE`.

### [Multi-period and storage: the staged API](@id staged-api)

`solve_opf` builds, solves, and extracts one snapshot in a single fused call —
it cannot express constraints that couple one time step to the next, such as a
battery's state of charge. For that, the same pipeline is exposed as four
composable steps that let you build **several snapshots into one JuMP model**,
add your own inter-temporal constraints, solve once, and extract each snapshot:

| function | role |
|---|---|
| `build_opf_model(net; model, add_objective, model_hook!, …)` | build one snapshot's devices/bounds into a (shared) model; no KCL, no solve |
| `generation_cost(ctx)` | that snapshot's cost-rate expression (\$/h), unset — duration-weight and sum across snapshots for one monetary objective |
| `enforce_kcl!(ctx)` | pin KCL for one snapshot (call once per snapshot before solving) |
| `extract_result(ctx; solution_hook!)` | extract one snapshot's SI result after the shared solve |

Pass the same `model` to every `build_opf_model` call and `add_objective=false`
so the snapshots share one optimisation and one objective. Each `ctx` keeps its
own variable/KCL dicts, so snapshots coexist without collision; couple them
through the variables a `model_hook!` publishes.

```julia
using JuMP, Ipopt
model = JuMP.Model(Ipopt.Optimizer)
ctxs  = [build_opf_model(nets[t]; model=model, add_objective=false,
                         model_hook! = battery_port!(t)) for t in 1:T]

# inter-temporal state of charge: SOC[t+1] = SOC[t] − P[t]·Δt, cyclic
duration_hours = fill(1.0, T)  # use the actual duration of every period
@variable(model, soc[1:T+1]); @constraint(model, soc[1] == soc[T+1])
for t in 1:T
    @constraint(model, soc[t+1] == soc[t] - Pexpr[t]*duration_hours[t])
    @constraint(model, 0 <= soc[t+1] <= E_max)
end

@objective(model, Min,
    sum(duration_hours[t] * generation_cost(ctxs[t]) for t in 1:T))
foreach(enforce_kcl!, ctxs)
JuMP.optimize!(model)
results = [extract_result(c) for c in ctxs]
```

`generation_cost(ctx)` is a **rate**, not an interval total. A bare sum of rates
preserves the same optimizer only when all periods have equal duration; it does
not report a monetary total. Duration weighting is required when periods differ
or when the objective value will be interpreted as currency.

Everything a snapshot exposes for coupling is the same context object a
`model_hook!` receives, so custom devices are declared exactly as in the
single-snapshot case. Downstream packages should prefer the stable accessors
[`opf_model`](@ref), [`opf_network`](@ref), [`opf_bases`](@ref),
[`opf_object`](@ref), and [`add_terminal_injection!`](@ref) over depending on the
raw context dictionaries. See [Parameterized and differentiable
extensions](differentiable_extensions.md) for the compatibility contract and
scientific limitations.

When an extension must intervene before native device physics is stamped, start
with [`initialize_opf_model`](@ref) and compose the public start-value, limit,
device, and objective stages explicitly. [`opf_build_manifest`](@ref) records
the exact stage order and native component ownership; the differentiable-
extensions guide documents this lower-level path.

### [Beyond OPF: other problem specifications](@id beyond-opf)

The staged API is problem-agnostic — it exposes the network physics, not just
the dispatch problem. Because `build_opf_model` adds operational limits only
where the net *declares* them (`v_min`/`v_max`/`i_max`), a net that omits them
yields a pure physics model with the bus voltages left free. Combined with
`add_objective=false` and a `model_hook!` that supplies its own objective, this
hosts estimation and fitting problems that are not dispatch optimisation at all.

For example, **weighted-least-squares state estimation** is: build the physics
of a bounds-free, load-free net (`source` + `line`s), add a free injection
current at each measured bus via a `model_hook!` (so KCL closes with the
voltages free to fit the data), and set the objective to the weighted sum of
squared measurement residuals `∑ wᵢ (zᵢ − hᵢ(state))²` for voltage-magnitude and
power-injection measurements. The solve returns the state that best explains the
measurements; with measurement redundancy it filters noise the raw readings
cannot. The same seam supports parameter estimation and other model-fitting
formulations — the device physics, per-unit handling, and multi-instance
coupling are reused unchanged.

---

## API reference

```@docs
solve_opf
solve_pf
solve_feasibility_opf
diagnose_infeasibility
build_opf_model
enforce_kcl!
generation_cost
extract_result
```
