# Optimal power flow

Despite the name, the ambition of this Task Force extends well beyond the
classical OPF problem of minimizing generation cost subject to network
constraints.  The unifying theme of the benchmark problems targeted here is
the need to **accurately represent distribution network physics** rather than
any particular objective function. Generation cost minimization with explicit
operational bounds is a convenient starting point: its objective and feasibility
conditions are straightforward to compare across solvers. With fixed demand and
one uniform non-negative price on every real-power injection, minimizing total
injection is equivalent to minimizing real losses. That special case does
**not** imply uniqueness or global optimality in this
nonconvex formulation. The same network physics underpins a
much broader class of distribution-network-constrained optimization problems
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
JuMP is loaded; Ipopt is the default optimizer when available:

```julia
using BMOPFTools, JuMP, Ipopt

net    = parse_bmopf("mynetwork.json")
result = solve_opf(net)
```

Dictionary input to `solve_opf`, `solve_pf`, `initialize_opf_model`, and
`build_opf_model` is copied, snapshotted when needed, and normalized before
per-unit conversion or model construction. The same ingest operations as
`parse_bmopf` migrate legacy fields, honor terminal roles, assign combined
Yd/Dy leakage to the wye winding, and materialize explicit `no_load_shunt`
records. Reusing parsed input does not duplicate shunts or losses. The caller's
network remains unchanged.

For each of resistance and reactance, supply either a combined Yd/Dy field or
split winding fields. Competing declarations raise `ArgumentError`, as do
competing explicit and legacy excitation fields. Normalization is not schema
validation or proof of electrical feasibility; use the validation APIs and
independent solution checks for those purposes.

A full mathematical derivation is available in `docs/math-model.tex`.

---

## Formulation principles

The engine is a **four-wire, rectangular current–voltage** formulation,
organized around a handful of deliberate, non-obvious choices worth stating
explicitly:

1. **Explicit current *and* voltage variables, as needed.** Both terminal
   voltages and branch currents are first-class variables — which is what lets
   the model represent parallel lines, meshed networks, and zero-impedance
   sections **exactly** (each parallel branch carries its own current, loops
   close through KCL, a jumper collapses to `V_fr = V_to`), with no small-ε
   impedance to break degeneracy.
2. **Prefer impedance form for series voltage drops.** Lines use `ΔV = Z·I`,
   so exact zero series impedance needs no inverse. Transformer builders also
   retain explicit equations at their supported ideal limits. One deliberate
   exception is a fixed-tap center-tap transformer with nonzero leakage arms:
   its coupled primitive-admittance stamp preserves winding coupling; free taps
   or zero arms use its quadratic T-model branch. Shunts and line π-halves
   naturally use `I = Y·V`. A lossless line (`R = 0`, nonzero `X`) has finite
   impedance and admittance; losslessness alone does not make admittance singular.
3. **Prefer expressions for derived quantities; lift deliberately.** Powers,
   voltage differences, and averages normally remain expressions. An auxiliary
   variable and its defining equality add model size, but do not by themselves
   imply linear dependence. *Deliberate exception:* the
   two-port transformer builders (YY, Yd/Dy, center_tap) and the DC resistive
   branch keep explicit per-winding current **variables** pinned by linear
   equalities, so that current limits (`i_max`) and the result writer have a
   first-class handle on each physical winding current. Apparent-power and
   magnitude lifts are further deliberate exceptions, discussed below.
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
7. **Bounds are optional — use them if present, never synthesize one from
   another.** Voltage, current, and apparent-power limits are all optional in the
   data model, and different problem formulations activate different subsets of
   the feasible region. A constraint is stamped only from data that is actually
   present; the engine never derives a current bound from a power bound (or vice
   versa), because a case may carry one, both, or neither *by design*.
8. **Respect evaluation domains and distinguish smoothing from lifting.** The
   exact magnitude `√(x²+y²)` has no unique gradient at the origin. An *implicit
   square root*, `u ≥ 0` with `u² = x²+y²`, has polynomial rows, but its defining
   row has zero gradient when all three variables are zero. Lifting alone does
   not cure that degeneracy; voltage-dependent loads need the domain treatment
   below. Droop and saturation curves
   are encoded with a smooth ReLU/softplus rather than a hard `max`/`min` (see
   [Smooth droop encoding](relu_softplus_encoding.md)).
9. **Use low-degree lifts where they help the formulation.** An auxiliary
   variable and its defining equation can replace quartic or rational
   expressions with quadratic rows. This changes sparsity and model size; it
   does not guarantee a faster or better-conditioned NLP. Apparent power is
   bounded through aux `p, q` with
   `p² + q² ≤ s²` (not a quartic in voltage × current); a free tap's reciprocal
   is an aux variable pinned by `n · n⁻¹ = 1` (not a rational term); the
   voltage-dependent load uses W/s lifts when positive voltage is certified,
   with a logarithmic-domain fallback otherwise.
10. **Reject known unsupported domains and structural degeneracies.** Exact
    special cases are retained (principle 4), and the implemented applicability
    checks reject known invalid inputs. They are not a complete well-posedness
    or rank test. A zero nominal voltage (undefined `1/v_nom`), a zero winding turns-ratio, or structural
    ideal-conductor cycles (including parallel edges and self-loops) are rejected.
    The cycle check follows coefficient resolution and native builder ownership;
    it is not a general Jacobian-rank certificate.
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
12. **The formulation is non-convex — use a deterministic, auditable start.**
    AC power-flow equations can have multiple roots, and AC OPF can have multiple
    stationary points and locally optimal solutions. A local interior-point method
    follows a start-dependent trajectory; it is not a nearest-solution algorithm.
    Every variable is therefore initialized from a physically motivated,
    deterministic guess — canonical 120° phase angles, anti-phase split-phase
    legs, delta-loop voltage propagation, and `I = conj(S)/conj(V)` current
    seeding. This improves reproducibility and avoids obvious phase-mapping and
    voltage-level mistakes. It does **not** certify which basin was selected, that
    the point is locally or globally optimal, or that it lies on the operational
    voltage sheet. Those are separate validation questions (see
    [Warm-start initialization](#Warm-start-initialisation) and
    [Trusting the solver](bounds/solver_trust.md)).
13. **One sign convention, and results are recomputed with it.** A single
    convention is fixed and applied to *every* element type — current into a bus is
    positive in KCL, apparent power is `S = V · conj(I)`. The result writer derives
    every reported quantity (per-element power, losses, terminal currents) from the
    *same* expressions the constraints are built from, never from an independent
    re-derivation that could drift out of sync with the model. This consistency is a
    correctness invariant, not a convenience: a quantity reported with the opposite
    sign to its own constraint is a silent error that a feasible solve will never
    catch.

For the implementation choices, supported inputs, and return shapes of the
shared building blocks, see the [formulation helper guide](@ref opf-formulation-helpers).

These principles were inspired by the IVR-EN formulation in
[PowerModelsDistribution](positioning.md) and by Claeys et al.'s four-wire OPF
paper ([ref. 6](methodology.md#refs)), but the model here has been generalized
well beyond that starting point.

---

## Mathematical model

### Network representation

The network is a graph of **buses** $b \in \mathcal{B}$, each with a set of
**terminals** $\mathcal{T}_b$.  Terminals are named strings (e.g. `"a"`, `"b"`,
`"c"`, `"n"`).  The *neutral terminal* $n_b$ is identified, in order of
precedence, by the case-level [`terminal_conventions`](conventions.md)
labels, by the explicit `neutral_terminal` bus field, or by the naming
convention: a terminal named `"n"`/`"N"` (case-insensitive), or the reserved
import label `"n_ref"`, is treated as neutral.

**Phase terminals** $\mathcal{T}_b^\phi \subseteq \mathcal{T}_b$ are all
terminals that are not the neutral.

#### [Earth, grounded terminals, and return paths](@id opf-earth-reference)

Every voltage in the model is measured against one common reference, **earth**
(remote ground, 0 V). Three rules decide how a conductor relates to it, and
they are worth reading once because they determine where return current flows.

**1. A perfectly grounded terminal is tied to earth by an ideal conductor.**
The set of grounded pairs $\mathcal{G}_\text{nd}$ contains

- every terminal a bus lists in `perfectly_grounded_terminals`, and
- the **neutral terminal of every voltage-source bus** (see
  [Voltage sources](#Voltage-sources)).

A grounded terminal keeps its voltage variables, fixed to zero, and keeps its
KCL equation. What makes it a *ground* rather than a dead end is a free
**earth-injection current** $(c^{r,\text{gnd}}_{b,t},\, c^{i,\text{gnd}}_{b,t})$:
whatever the connected branches push into the node flows on into earth. That
current is reported per terminal under `result["ground"]`.

**2. A terminal that is not grounded floats.** Its voltage is a free variable
determined by KCL. A neutral conductor grounded only at the substation therefore
shows a neutral-to-earth voltage along the feeder, as it does in the field.

**3. A wye-connected device without a neutral in its `terminal_map` is
referenced to earth.** This applies alike to WYE loads and generators and to
the wye windings of `single_phase`, `wye_delta`, and `delta_wye` transformers.
Its coil voltage is the phase-to-earth voltage and its return current leaves
through an *implicit ideal earth connection* that appears in no KCL equation.
In power-engineering terms, a three-terminal wye map describes a **solidly
grounded star** (Yg), not a floating star.

!!! warning "A three-terminal wye map is Yg, with the zero-sequence path that implies"
    A solidly grounded star point carries zero-sequence current. A `wye_delta`
    unit whose wye map is `["a","b","c"]` therefore behaves as a grounding
    transformer on that side. To model an **ungrounded** star, give the bus an
    ungrounded neutral terminal and include it in the terminal map: the star
    point then floats and the phase currents must sum to zero through it. To
    model an **impedance-grounded** star, do the same and connect the neutral to
    earth through a `shunt` (or the transformer's `r/x_neutral_*` fields).

---

### Variables

All variables are real-valued. By default the model is built in **per-unit**
working coordinates and results are converted back to SI (V, A, W); see
[Units and scaling](#Units-and-scaling) for the bases and the SI alternative.

| Variable | Index | Description |
|---|---|---|
| $v^r_{b,t},\; v^i_{b,t}$ | $(b,t)\in\mathcal{B}\times\mathcal{T}_b$ | Rectangular voltage at terminal |
| $c^{r,\text{gnd}}_{b,t},\; c^{i,\text{gnd}}_{b,t}$ | $(b,t)\in\mathcal{G}_\text{nd}$ | Earth-injection current at a grounded terminal |
| $c^r_{\ell,k},\; c^i_{\ell,k}$ | line $\ell$, conductor $k$ | Series current, from-side |
| $c^r_{sw,k},\; c^i_{sw,k}$ | switch $sw$, conductor $k$ | Switch current (fixed to zero when open) |
| $c^{r,d}_{d,k},\; c^{i,d}_{d,k}$ | load $d$, phase $k$ | Load current |
| $c^{r,g}_{g,k},\; c^{i,g}_{g,k}$ | generator $g$, phase $k$ | Generator current |
| $c^{r,n}_{n,k},\; c^{i,n}_{n,k}$ | IBR $n$, phase $k$ | IBR current |
| $c^{r,s}_{v,k},\; c^{i,s}_{v,k}$ | voltage source $v$, phase $k$ | Source slack current |
| $c^{r,x}_{x,\sigma,k},\; c^{i,x}_{x,\sigma,k}$ | transformer $x$, side $\sigma$, conductor $k$ | Transformer winding current (two-bus subtypes) |
| $c^{r,w}_{x,j,k},\; c^{i,w}_{x,j,k}$ | `n_winding` transformer $x$, winding $j$, phase $k$ | n-winding winding current |
| $N_x$ or $n_{\text{eff},x}$ | transformer $x$ with a free tap | Effective ratio (see [Continuous tap optimization](@ref Continuous-tap-optimisation)) |

The to-side line series current $\tilde{c}_{\ell,k} = -c_{\ell,k}$ is an
*expression*, not a variable: a line has one independent series current per
conductor. Cases with a DC side add DC node voltages and DC branch, converter,
load, and source currents (see the [MVDC tutorial](tutorial_mvdc.md)).

Load, generator, IBR, and source current variables cover **phase
conductors only**; neutral return current is implicit in KCL. IBRs add an
analogous current variable per phase — see [IBRs](#ibrs) below.

---

### Units and scaling

The data model is always in **SI** units, but by default the OPF is built and
solved in a **normalized per-unit copy** (`per_unit=true`). It uses a system
base `s_base` (VA, default `1e6`) with per-bus voltage bases, then converts
results back to SI. Pass `per_unit=false` to build the numerical model directly
in volts, amperes, ohms, and watts.

**How voltage bases are assigned.** A voltage base is a coordinate scale for a
*conductor*, so every bus joined by copper must share one:

1. Buses joined by lines, switches, or galvanically continuous transformers
   (`single_phase_autotransformer`, `open_delta_regulator`) are grouped into
   **galvanic zones**. A regulator belongs here because its two bus records are
   bonded through a shared bushing, and its model uses the dimensionless
   `tap_ratio`, never a nameplate voltage pair.
2. The zone containing the first voltage source takes that source's largest
   phase voltage magnitude as its base.
3. The base changes only across an **isolating** transformer, by its nominal
   ratio: $V_\text{base,to} = V_\text{base,fr}\cdot
   V^\text{nom}_\text{to}/V^\text{nom}_\text{fr}$. Zones the source cannot
   reach inherit the source base.

Each transformer's nominal voltages are then divided by the base of *its own*
side, so its per-unit ratio is one exactly when the two zone bases stand in the
nameplate ratio. That is not always possible. When two transformers of unequal
ratio feed the same low-voltage zone (a mesh closed across, say, an 11/0.240 kV
and an 11/0.252 kV unit), the zone keeps the base it received first and the
second transformer simply carries a per-unit ratio different from one. The
circulating current that the ratio mismatch drives around the loop is retained,
and the per-unit and SI models describe the same physics.

The derived bases follow from $V_\text{base}$ and $S_\text{base}$:
$I_\text{base} = S_\text{base}/V_\text{base}$,
$Z_\text{base} = V_\text{base}^2/S_\text{base}$,
$Y_\text{base} = S_\text{base}/V_\text{base}^2$.

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

For reproducible scaling experiments, prefer a typed policy over the legacy
keywords:

```julia
classic = OpfScaling(:classic; power_base = 1e6)
si = OpfScaling(:si)
custom = OpfScaling(
    name = :voltage_half_power_200kva,
    power_base = 2e5,
    voltage_bases = Dict(bus => 0.5 * base for (bus, base) in reference_bases),
)

ctx = build_opf_model(net; scaling_policy = custom)
schema = opf_diagnostic_schema(ctx)
schema.scaling["kind"]  # => "consistent_per_unit"
```

For an experimental power base that changes across an isolated transformer,
use `OpfScaling(voltage_bases=..., power_bases=...)`. Every bus must be
declared and the power base must be constant within each galvanically continuous
zone. Cross-zone `single_phase`, `center_tap`, `wye_delta`, `delta_wye`, and
`n_winding` units are qualified. Native lossless AC/DC converters using `P`,
`V`, or `droop` control are also qualified with an independent DC power base.
The engine still rejects the remaining transformer families until their
connection-specific stamping has passed physical-state, derivative, set,
objective, and loss covariance; custom or lossy converter builders require
their own covariance contracts.
Galvanically continuous `single_phase_autotransformer` and
`open_delta_regulator` devices are also qualified, but only with one voltage
base and one power base across both sides. Their tap is dimensionless and does
not turn a shared copper bushing or straight-through phase into a scaling
boundary.

An explicit `scaling_policy` is authoritative over `per_unit` and `s_base`.
The custom `OpfScaling` form requires every AC bus to be declared and validates
that lines/switches preserve the voltage base and transformer bases preserve
the turns ratio. It derives `I_base=S_base/V_base`,
`Z_base=V_base^2/S_base`, and `Y_base=S_base/V_base^2`. Independently choosing
all four bases is not currently supported because the IVR equations assume
these identities; the constructor rejects incompatible declarations instead
of silently changing the physical model. The effective policy is serialized
by `opf_research_provenance`.

---

### Objective

Minimize total active-power generation cost **rate** (linear in active power;
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
| 2-winding transformer (+ regulators) | `i_max_from`/`i_max_to` (per winding) | `s_rating` (nameplate; enforced whenever supplied, in power flow too) | **power** (nameplate); regulators prefer current |
| n-winding transformer | per-winding `i_max` | per-winding `s_max` rating | power (per winding) |

Declaring **both** on the same element triggers the audit finding
[`W.RED.DUAL_THERMAL_LIMIT`](findings.md). The pair is not *mathematically*
redundant — see the warning below — but it is usually redundant in *engineering*
terms, because a device has one thermal limit and two declared rows normally mean
one was derived from the other. Which representation is the source of truth is
physics, not taste:

- **Lines and cables** are limited by conductor heating, which the manufacturer
  specifies in amperes — current is the physical driver, so `i_max` is preferred.
- **Transformers** are specified by their **kVA nameplate**; the primary and
  secondary currents differ, so a single apparent-power rating is the natural
  limit. A supplied `s_rating` (it also sets the winding-1 per-unit impedance
  base — see [transformer models](transformer_models.md)) is **always
  enforced**, in `solve_pf` too, as an apparent-power cap on the coils of **one**
  winding, alongside the `i_max_from`/`i_max_to` current cones when present.
  Which winding, and what share of the nameplate each coil receives, depends on
  the subtype — see the per-subtype table in
  [Nameplate rating as a loading cap](@ref transformer-nameplate-cap). For `n ≥ 3` windings the cap is a per-winding `s_max`
  rating. One consequence to keep in mind: a from-side coil carries **load +
  losses**, so at exactly-rated delivery a from-side cap binds slightly *below*
  the secondary nameplate throughput (by the loss margin). An absent `s_rating`
  leaves a two-winding unit **uncapped**; remove the field to solve a
  transformer with no loading limit (a physics comparison against a limit-free
  reference).
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

!!! warning "Current and apparent-power limits are not interchangeable"
    Since `|S| = |V||I|`, a conversion
    `I_max = S_max / V_ref` is exact only at the declared reference voltage.
    Away from that voltage it changes the feasible set and can change the active
    set, local minima, and solver basin. Nor is one of two simultaneously
    declared limits necessarily inactive over the whole voltage range: if
    `S_max / I_max` lies between `V_min` and `V_max`, the binding
    representation can switch with voltage. One row is provably dominated only
    after using the relevant voltage bounds and voltage reference to establish
    that ordering throughout the feasible range.

    This distinction matters in computational comparisons. A current-limited
    OPF and an apparent-power-limited OPF are different optimization problems
    unless the equivalence conditions are demonstrated; different
    local-optimum behavior is then a modeling result, not automatically a
    formulation bug.

    None of this makes keeping both rows the safe default. Two rows impose a
    voltage-dependent envelope that matches no real rating, so the resolution is
    an engineering one — decide which row is the device's source of truth and
    drop the derived one — rather than a license to declare both and let the
    solver sort it out.

---

### Constraints

#### Grounding

A grounded terminal is held at earth potential, and its earth-injection current
is left free (see [Earth, grounded terminals, and return
paths](@ref opf-earth-reference)):

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

**The source-bus neutral is solidly grounded.** Which terminal is the neutral
follows the bus's explicit `neutral_terminal` field, then the case's declared
`terminal_conventions`, and only for cases that declare no roles the naming
convention (`n`, `N`); a conductor declared as a phase is never grounded
because of its name. The neutral terminal of every
bus that hosts a voltage source is fixed to zero
($v^r_{b,n} = v^i_{b,n} = 0$) and added to $\mathcal{G}_\text{nd}$, whether or
not the source's own `terminal_map` lists it. Source magnitudes `v_magnitude`
are therefore phase-to-earth and phase-to-neutral at once. The neutral receives
the summed slack return current $-\sum_k c^{s}_{v,k}$ and, being grounded, a
free earth-injection current, so an earth-return circuit (current leaving on a
phase and coming back through earth) closes at the source.

!!! note "Modeling a source that is not solidly grounded"
    This rule means an impedance-grounded or ungrounded supply cannot be written
    on the source bus itself. Keep the grounding off that bus instead:

    1. give the **source bus phase terminals only** (no neutral), so there is
       no source-bus neutral for the engine to earth;
    2. join it to the first network bus with a **three-wire link** (a line with
       exact zero impedance is admissible);
    3. connect that bus's neutral to earth through a `shunt` holding the
       grounding admittance, or leave it unconnected for an ungrounded supply.

    The source then fixes the phase-to-earth voltages, and all neutral current
    returns through the grounding impedance. A 230 V source with a 0.5 Ω
    grounding resistor feeding a 3 kW phase-to-neutral load over 0.1 Ω
    conductors reproduces the series-circuit answer
    $I\,(230 - 0.7\,I) = 3000$, i.e. 13.61 A and 6.8 V neutral-to-earth at the
    grounding point (a regression test pins it). A transformer whose wye
    neutral is grounded through `r/x_neutral_*` serves the same purpose.

    The passive admittance export ([`ybus_passive`](@ref)) deliberately does
    **not** apply this rule: it grounds only the terminals declared in
    `perfectly_grounded_terminals`, because a voltage source is a boundary
    injection there rather than part of the passive network. Declare the source
    neutral in `perfectly_grounded_terminals` when the two views must agree.

#### [Magnitude-limit input domain](@id opf-magnitude-domain)

Declared magnitude limits must be nonnegative real values. Negative values and
NaN are rejected, including on inactive native devices. An omitted upper cap or
in-memory Julia `+Inf` means unconstrained; use omission in JSON. Lower magnitude
bounds must be finite. Zero remains an exact cap, including per-winding current
and apparent-power limits. Vector entries must be real; omit the whole field
rather than inserting `nothing`. Positive magnitudes and nominal voltages whose
squares or reciprocal squares cannot be represented in Float64 require rescaling.

!!! note "Zero, absent, and unrated are different inputs"
    Zero is an exact cap; it does not mean disabled or unrated. In particular,
    zero n-winding current and apparent-power caps are now enforced. A supplied
    transformer `s_rating` must be finite and strictly positive because it may
    also define impedance bases; omit it for an unrated supported recipe.

Malformed native transformer maps, unknown subtypes, and unsupported neutral
connections raise errors instead of leaving the device partially unstamped.
Native n-winding transformers require matching positive phase counts and support
`a`/`b`/`c` phase labels and `n` neutral (case insensitive); DELTA has no neutral.

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

#### [Other bus voltage limits](@id opf-bus-limits)

A phase-to-earth magnitude is only one way to state a voltage requirement. On a
four-wire feeder the customer sees the phase-to-**neutral** voltage, a
three-phase motor sees the phase-to-**phase** voltage and its unbalance, and a
protection engineer may care about the angle between phases. Each of these is
an optional bus field, stamped only when present. Write
$u_{b,k} = v_{b,t_k} - v_{b,n_b}$ for the phase-to-neutral phasor of phase $k$
(or $v_{b,t_k}$ itself when the neutral is perfectly grounded).

| Field | Shape | Constraint |
|---|---|---|
| `vpn_min`, `vpn_max` | per phase | $(V^{pn}_{\min,k})^2 \le \lvert u_{b,k}\rvert^2 \le (V^{pn}_{\max,k})^2$ |
| `vpp_min`, `vpp_max` | per unordered phase pair $(j<k)$ | $(V^{pp}_{\min,jk})^2 \le \lvert v_{b,t_j} - v_{b,t_k}\rvert^2 \le (V^{pp}_{\max,jk})^2$ |
| `va_diff_min`, `va_diff_max` (with optional `va_nom`) | scalars (rad); `va_nom` per phase | $\theta^{\min} \le \theta_{b,k} - \theta_{b,j} - \Delta_{jk} \le \theta^{\max}$ for every phase pair, $\Delta_{jk} = \theta^\text{nom}_k - \theta^\text{nom}_j$ |
| `vpos_min`, `vpos_max` | scalar | bounds on the positive-sequence magnitude $\lvert V_1\rvert$ |
| `vneg_max`, `vzero_max` | scalar | caps on $\lvert V_2\rvert$ and $\lvert V_0\rvert$ |
| `vuf_max` | scalar, dimensionless | $\lvert V_2\rvert^2 \le u^2\,\lvert V_1\rvert^2$ |

Arrays are indexed by the bus's **full** phase list in `terminal_names` order;
a grounded or source-fixed phase is skipped without shifting the index of the
entries after it.

*Angle windows.* The angle condition is written without trigonometric functions
of variables. With $z = \overline{v_{b,t_j}}\,v_{b,t_k}$ rotated by
$e^{-j\Delta_{jk}}$ into $c + js$, the window
$\theta^{\min} \le \arg(c+js) \le \theta^{\max}$ becomes two bilinear rows,
$\sin\theta^{\min}\,c \le \cos\theta^{\min}\,s$ and
$\cos\theta^{\max}\,s \le \sin\theta^{\max}\,c$. Both endpoints are required and
must lie strictly inside $(-\pi/2, \pi/2)$. `va_nom` centers the window on the
nominal displacement (for example $\mp 120°$); without it the window bounds the
raw angle difference.

*Sequence components.* $V_0, V_1, V_2$ are the Fortescue transform of the three
phasors $u_{b,k}$, with $\alpha = e^{j2\pi/3}$:
$V_1 = \tfrac13(u_a + \alpha u_b + \alpha^2 u_c)$,
$V_2 = \tfrac13(u_a + \alpha^2 u_b + \alpha u_c)$,
$V_0 = \tfrac13(u_a + u_b + u_c)$. Because the transform is linear in the
rectangular voltages, every sequence bound is a quadratic row. `vneg_max` caps
$\lvert V_2\rvert$ in volts, which matches a standard's unbalance limit only if
$\lvert V_1\rvert$ sits at nominal; `vuf_max` is the true ratio
$\lvert V_2\rvert/\lvert V_1\rvert \le u$ and needs no voltage base.

!!! warning "Limits that do not apply are skipped without a message"
    A limit is stamped only where its definition makes sense:

    - `vpn_min`/`vpn_max` need a neutral terminal on the bus. Without one they
      are skipped; use `v_min`/`v_max` there.
    - `vn_max` is skipped when the neutral is perfectly grounded (it is zero).
    - Sequence and unbalance limits (`vpos_*`, `vneg_max`, `vzero_max`,
      `vuf_max`) need **exactly three** phase terminals. On a single- or
      two-phase bus they are skipped.
    - A per-conductor limit vector (`i_max`, `s_max`, `i_max_from`, `i_max_to`)
      **shorter** than the conductor count caps only the leading conductors;
      the trailing ones, typically the neutral, stay unrated.

    Run the [validation](validation.md) pass before a study that relies on a
    limit: it reports limits that cannot bind.

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

**π-model shunt currents** (from the linecode matrix fields `G_from_i_j`,
`B_from_i_j`, `G_to_i_j`, `B_to_i_j`, scaled by line length; or the same fields
given inline on the line, used as-is; linear in voltage variables, no new JuMP
variables):

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
    $|Y^\text{sh}_{kj}| = \sqrt{G_{kj}^2 + B_{kj}^2}$ is the π-shunt
    admittance and $V^\text{max}_j$ is a **hard** to-ground voltage-magnitude
    bound on terminal $j$. The same series current appears at both ends, so the
    bound is formed at the from end and at the to end and the tighter one is
    kept. Each box is added only when such a $V^\text{max}$
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
$t_k$). A matching cone is **always** added at the to end: equal current
magnitudes do not imply equal powers, because the two end voltages differ, and
under reverse flow the to end is the binding one.
`s_max` follows the same **element → linecode → unconstrained** precedence as
`i_max`. Both limits may be present and are both enforced; the binding one can
change with voltage, so the pair is not mathematically redundant, but declaring
both is usually an engineering duplication — see [current vs. apparent-power
limits](@ref Current-vs-apparent-power-limits) for why current is the source of
truth here and why the **neutral entry of `s_max` is degenerate**
($v_n \approx 0 \Rightarrow S \approx 0$).

**Angle-difference limit** (optional `va_diff_min`/`va_diff_max`, radians).
A line may bound the angle by which its from-end voltage leads its to-end
voltage, $\theta^{\min}_\ell \le \theta_\text{fr} - \theta_\text{to} \le
\theta^{\max}_\ell$, on each **phase conductor** $k$. With
$c + js = v_{b^\text{fr},t_k}\,\overline{v_{b^\text{to},t_k}}$ the window is the
same pair of bilinear rows as the [bus angle window](@ref opf-bus-limits); both
endpoints are required and must lie strictly inside $(-\pi/2,\pi/2)$.

The **neutral conductor is exempt**. An angle window is a statement about the
power-carrying phasors. A neutral voltage is a small residual set by the return
current, and on a healthy unbalanced feeder the neutral phasors at the two ends
of one section routinely differ by tens of degrees while the phase angles move
by a fraction of a degree. Bounding it would reject ordinary operating points.
Which conductor is a neutral is taken from the case's declared
`terminal_conventions` when present: a conductor declared as a phase is
angle-bounded whatever it is called, and the naming convention (`n`, `N`) is
used only for cases that declare no roles.
A **protective-earth conductor** declared in `terminal_conventions` is exempt
for the same kind of reason: it sits at or near zero volts, where an angle is
not defined. The post-solve validator applies the same rule, so a solution the
engine accepts is not reported as violating, or as unassessable, on a
conductor the engine never bounded.

#### Switches

A switch is modeled as an **ideal, zero-impedance branch**: like a line, it
carries per-conductor series current variables $c^r_{sw,k}$, $c^i_{sw,k}$ that
enter KCL at both ends with opposite signs — $-(c^r_{sw,k},\,c^i_{sw,k})$ at the
from-terminal and $+(c^r_{sw,k},\,c^i_{sw,k})$ at the to-terminal — exactly as a
line's series current does. What differs from a line is the series relation: the
KVL voltage-drop equation is replaced by a state-dependent condition, and there
is no $\pi$-shunt.

A **closed** switch replaces KVL with a **zero voltage drop** (lossless short),
imposed per mapped conductor $k$:

```math
v^r_{b^\text{fr},t^\text{fr}_k} = v^r_{b^\text{to},t^\text{to}_k}, \qquad
v^i_{b^\text{fr},t^\text{fr}_k} = v^i_{b^\text{to},t^\text{to}_k}
```

The current $c_{sw,k}$ is left free and is determined by KCL — it is the
mechanism by which power flows through the closed switch. The two terminals are
held at equal voltage but are **not** merged into one bus (a separate
[`collapse_closed_switches`](@ref) network simplification does that node merge
explicitly, outside the OPF).

!!! warning "KCL must be able to determine the current"
    Because no impedance sets a switch current, the closed switch poles (and
    any other ideal conductors) must form a **tree**. Two closed switches in
    parallel can pass any circulating current, and so can one pole between two
    terminals that can each supply any current: two perfect grounds, or a
    source terminal and a ground. The common case is a **four-wire switch
    between two buses whose neutrals are both perfectly grounded**. Its neutral
    pole joins two points at earth potential, with the earth as a second ideal
    path between them, and nothing decides how the return current divides.
    The engine rejects such a case (`E.INT.IDEAL_LOOP`) rather than report an
    arbitrary current. The neutral pole is redundant there, so map only the
    phase poles (a three-pole switch), or let [`fix_case`](@ref) remove it; the
    rest of the solution is unchanged. The same rule applies to line conductors
    whose impedance is exactly zero, and to **ideal transformers** (zero
    leakage): one is fine, but two in parallel, or one bridged by a closed
    switch, can share the load in any proportion and are rejected. Give
    paralleled transformers their leakage impedance. An ideal
    grounded-wye/delta transformer directly on a voltage source is rejected for
    the same reason (its zero-sequence current is undetermined); a feeder
    impedance or the transformer's leakage resolves it.

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
A grounded terminal has zero voltage and so contributes nothing to the sum.

#### Capacitor banks

A fixed `capacitor` is a constant susceptance $B = q_\text{rated}/v_\text{nom}^2$
(per phase for WYE, per pair for DELTA) delivering $Q = B\,V^2$. The nominal
voltage `v_nom` is **required**: it is the voltage the reactive rating refers
to, and no default could mean the same capacitor in SI and in per-unit. Its connection
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

A WYE load whose `terminal_map` lists no neutral is referenced to earth:
$\Delta v_k = v_{b,t^\phi_k}$ and its return current closes through the implicit
earth connection described in
[Earth, grounded terminals, and return paths](@ref opf-earth-reference).

The **realized power** is always bilinear in these voltage drops and the load
current variables (exact, no approximation):

```math
P_k = \Delta v^r_k \, c^{r,d}_{d,k} + \Delta v^i_k \, c^{i,d}_{d,k}, \qquad
Q_k = \Delta v^i_k \, c^{r,d}_{d,k} - \Delta v^r_k \, c^{i,d}_{d,k}
```

The load `model` field determines the right-hand-side value that $P_k$ and
$Q_k$ are pinned to.

##### [Squared-voltage-drop variable](@id squared-voltage-drop-variable)

Mixed ZIP, constant-current, and general exponential models introduce a scalar
auxiliary variable per sub-load:

```math
W_k = (\Delta v^r_k)^2 + (\Delta v^i_k)^2
```

These remaining laws are supported on **strictly positive coil voltages**.
When a fixed reference or an enforced bus bound certifies `|ΔV| ≥ L > 0`,
the engine retains W/s lifts with the weaker domain guards `W ≥ (L/2)²`
and, when needed, `s ≥ L/2`. Those guards are implied by the physical bound;
there is no artificial upper voltage limit. Starts use fixed or initialized
terminal voltages, independently of nominal engineering bands.

!!! warning "A voltage start is not a physical domain certificate"
    Only an applicable, actually stamped bound justifies the W/s guards.
    Phase-to-ground bounds do not certify phase-to-floating-neutral voltage,
    and a power-flow recipe may omit operational bounds. A positive start alone
    cannot justify adding a positive physical lower limit. The former implicit
    `0.5–1.5 × v_nom` band could exclude valid operating points; it is removed.

    Rebuild if you change the source references or loosen the physical bounds
    used for a certificate. Editing those JuMP objects does not update the
    derived W/s guards automatically; leaving them in place can restrict the
    modified problem. The guards protect fractional-power evaluation, so solver
    bound relaxation also matters near the boundary.

Without such a certificate, the engine uses `ell = log(|ΔV|/V_nom)` and
`|ΔV/V_start|² = exp(2(ell - ell_start))`, where `V_start > 0` is the fixed
initialized coil magnitude (nominal voltage is the fallback at a zero start) and
`ell_start = log(V_start) - log(V_nom)`. This makes the two sides of the defining equation order
one at the start, including small positive voltages. ZIP factors become sums of `exp(2ell)`, `exp(ell)`
and constants; exponential factors become `exp(gamma*ell)`. This represents the
positive domain without an arbitrary epsilon and avoids negative-base fractional
powers during solver trials. The new variable and definition keys are
`load_log_voltage_magnitude` and `load_log_voltage_definition`; W/s keys are absent
on this path. `ell` and its defining residual are dimensionless. The definition
is scaled by `1/V_start²`; account for this normalization when interpreting its dual.

Fixed equal terminal voltages are rejected for these remaining laws. Pure-Z
loads support zero voltage as described below. The logarithmic formulation does
not prescribe a continuation at zero, nor guarantee good conditioning near it.
Extreme trial values can still cause exponential overflow/underflow. Check actual
coil voltages and physical residuals at the requested tolerances; disable solver
bound relaxation when evaluating fractional powers near a W-domain boundary.

**Structural substitutions:** constant-P-equivalent ZIP/exponential models have
no W/s auxiliaries and no implicit voltage band. A `constant_impedance` load,
pure-Z ZIP, or exponential load with both exponents 2 stamps the current law
`I = conj(S_nom) ΔV / V_nom²` directly. This is affine for fixed coefficients and
valid at zero voltage. It keeps the public current handles and result shape but
removes W and replaces the power rows with `load_impedance_current_real/imag`
constraints, whose semantic units are current. Nominal-power providers remain
symbolic, including across parameter updates through zero. Mixed ZIP Z terms
are not separately substituted yet.

!!! warning "Changing a parameter does not certify a fresh solution"
    Repeat-solve tests with both Ipopt and MadNLP found successful statuses with
    stale currents after nominal powers changed through zero. See the
    [parameter-update workflow](@ref opf-parameter-resolves) for the tested
    optimizer-cache reset, its setup cost, and required residual checks.

##### Model types

The quadratic classifications below refer to the certified W/s path. The
logarithmic path uses nonlinear exponentials even for ZIP/current models.

| `model` | $P_k$ pinned to | $Q_k$ pinned to | Quadratic W/s path? |
|---|---|---|---|
| `constant_power` (default) | $P^{\text{nom}}_k$ | $Q^{\text{nom}}_k$ | yes |
| `constant_current` | $P^{\text{nom}}_k \cdot s_k / V^{\text{nom}}_k$ | $Q^{\text{nom}}_k \cdot s_k / V^{\text{nom}}_k$ | yes (with $s_k$) |
| `constant_impedance` | $P^{\text{nom}}_k \cdot \lvert\Delta v_k\rvert^2 / (V^{\text{nom}}_k)^2$ | $Q^{\text{nom}}_k \cdot \lvert\Delta v_k\rvert^2 / (V^{\text{nom}}_k)^2$ | not needed: stamped as the affine current law above, with no $W_k$ |
| `zip` | $P^{\text{nom}}_k (\alpha^Z_k W_k/(V^{\text{nom}}_k)^2 + \alpha^I_k s_k/V^{\text{nom}}_k + \alpha^P_k)$ | analogous with $\beta$ | yes (with $s_k$ if $\alpha^I_k \neq 0$) |
| `exponential` | $P^{\text{nom}}_k (W_k/(V^{\text{nom}}_k)^2)^{\gamma^P_k/2}$ | analogous with $\gamma^Q_k$ | only if $\gamma \in \{0,1,2\}$ |

**Integer-exponent routing:** exponential loads with $\gamma \in \{0, 1, 2\}$
are automatically routed to the constant-power, constant-current, or
constant-impedance paths respectively. Current equivalents remain quadratic
when a positive voltage bound is certified.  The data-analysis pass ([`load_model_analysis`](@ref)) flags
these loads with `I.LOAD.EXP_ZIP_EQUIVALENT`.

**v\_nom** must be finite and strictly positive for all models except `constant_power`.  It is the
terminal voltage magnitude at which `p_nom`/`q_nom` are specified: phase-to-neutral (V) for WYE, line-to-line (V) for DELTA.  It may be a scalar
(shared across all sub-loads) or a per-sub-load array.

**DELTA** loads use line-to-line voltage drops: $\Delta v^r_k = v^r_{b,t_k} - v^r_{b,t_{k^+}}$,
$\Delta v^i_k = v^i_{b,t_k} - v^i_{b,t_{k^+}}$. A three-terminal map gives three
coils with cyclic $k^+$; a two-terminal map gives **one** coil across that pair.
A DELTA map holds phase terminals only: a neutral is not a coil endpoint and is
rejected.

**ZIP defaults.** A coefficient family (`alpha_*` or `beta_*`) that is entirely
absent means constant power $(0,0,1)$; if any member is given, the missing ones
are zero.

#### [Generators](@id generators-section)

Generators use coil voltage with power bounds and an injected (positive) sign
convention. WYE coils reference the listed neutral, or earth if the map lists
none (see [return paths](@ref opf-earth-reference)). DELTA coils span phase
pairs: three terminals give three coils, each referenced to the next terminal
cyclically, and two terminals give **one** line-to-line coil. A DELTA map holds
two or three distinct phase terminals; a neutral is rejected. A two-terminal `SINGLE_PHASE`
generator is one coil between the two listed terminals, including phase-to-phase
connections. It has one P/Q/cost entry and one current pair, reported under the
first terminal name. Both terminal current ratings apply to that same current,
so the tighter rating is used. Constraints, generation cost, and result extraction
use the same coil-voltage reference:


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

Every supplied `p_min`, `p_max`, `q_min`, or `q_max` vector must have exactly
**one entry per coil**; a shorter vector is rejected, because the uncovered
coils would otherwise be free, unbounded injections. Equal static bounds are
stamped as one equality row.

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
constraining the variable twice); a length-1 vector is standardized to 2 by the
augmentation pass.

A `DELTA` generator has no neutral, and its `i_max` entries cap the **coil**
currents, as for a `THREE_LEG` IBR below. A three-terminal delta has three
coils and takes three entries; entry $k$ caps the current of the coil between
`terminal_map[k]` and the next terminal, and the conductor current (the
difference of two coil currents) can exceed it. A **two-terminal** delta is one
coil whose current flows through both of its conductors, so its one or two
entries collapse to a single circle at the tighter limit, whichever terminal
that limit is listed against.

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
  current per phase conductor. The neutral is the terminal of `terminal_map`
  that carries the neutral role (by label, not by position); a map with no
  neutral is referenced to earth, like any other wye device.
- **`THREE_LEG`** — line-to-line (delta), $\Delta v_k = v_{b,t_k} - v_{b,t_{k^+}}$
  with cyclic index $k^+ = (k \bmod n) + 1$; no neutral current.
- **`SINGLE_PHASE`** — phase-to-reference, $\Delta v = v_{b,t_1} - v_{b,t_2}$,
  a single current.

Any other topology string, or a `SINGLE_PHASE` unit with fewer than two
terminals, is rejected with an `ArgumentError`. (Skipping such a record would
leave its current outside KCL, silently removing the device from the network.)

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
supply it to model the low-voltage var rolloff of a real converter. Unlike a
generator's, an IBR's current limit is stamped as the cone only, without the
companion box bound of formulation principle 11.

For a `FOUR_LEG` IBR, `i_max` is **per conductor**, with a
trailing entry capping the **neutral conductor** ($\sum_k c^{r,n}_{n,k}$,
$\sum_k c^{i,n}_{n,k}$) — recommended, since a four-wire converter doing unbalance
compensation can drive a neutral current *larger* than any phase. A phases-only
length-3 vector warns (`W.INT.IMAX_NO_NEUTRAL`). A `SINGLE_PHASE` IBR has a single
current, so its `i_max` is length 1 or 2 and collapses to one circle at the tighter
limit.

For **`THREE_LEG`**, `i_max[k]` instead caps the **cyclic pair current**
`J[k]` between `terminal_map[k]` and the next terminal (wrapping last to first).
Its `p_min`, `p_max`, `q_min`, `q_max`, and `s_max` entries also apply to each
pair, not to the three-pair aggregate. There is no neutral. With positive
injection powers `S[k] = P[k] + im*Q[k]`,
`J[k] = conj(S[k] / (V[k] - V[next]))`; the external conductor injection is
`I[k] = J[k] - J[previous]`. Thus a conductor current can exceed a pair cap
without violating this model. The earlier blanket description of IBR `i_max`
as per-conductor was incorrect for THREE_LEG; the runtime meaning is unchanged.

The `result["ibr"][id][terminal_map[k]]` fields `cri`/`cii` are the real/imaginary
parts of **J[k]**, not I[k]; `pg`/`qg` are the same pair's injection powers.
The first terminal identifies the oriented pair only in conjunction with the
authored cyclic `terminal_map`. Result JSON retains this representation. These
fields are returned in A, W and var after either SI or per-unit solves. Reconstruct
I from adjacent pair records before comparing with source/branch conductor
currents. No conductor-current rating is inferred from `i_max`.

Independent regressions in `test/three_leg_physics_tests.jl` use balanced and
unbalanced prescribed phasors, source-current KCL, complex power balance,
unequal pair limits, zero/missing limits, source-angle/cyclic covariance,
SI/classic/consistent/zone scaling with changed bases, and JSON round trips.
Their domain is the lossless fundamental-frequency cyclic-pair model with
nonzero pair voltages; they do not establish advanced inverter filter, DC-link,
switching, controller or feasible-region equivalence with other packages.

Declared `q_min` and `q_max` are hard reactive-power bounds in every control mode.
Within those bounds, reactive power is governed as follows:

- **Dispatchable Q** (default): Q can vary within its declared bounds and other
  capability constraints. Augmentation can populate missing bounds.
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

The PF/Volt-var equality and all declared P/Q/S/current limits apply together.
An incompatible control request can make the model infeasible; the engine does
not clip the controller or discard a bound. Existing PF-versus-droop precedence
and the unsupported THREE_LEG droop fallback remain unchanged.

!!! warning "Reactive capability compatibility change (#89)"
    Previously, the engine omitted Q-box constraints under PF or supported
    Volt-var control. It now enforces both, so dispatch and feasibility can change
    for cases containing those fields. If a Q restriction is not intended, remove
    that field explicitly before building the model. Review bounds introduced by
    augmentation as well as authored bounds: both constrain the resulting case.
    PF augmentation still avoids synthesizing missing Q boxes and preserves
    explicit ones. A local solver failure alone does not certify global infeasibility.

`solution_check` checks supplied Q values against the case's declared Q bounds
using `E.SOL.IBR_Q_VIOLATION` and `W.SOL.IBR_Q_ACTIVE`. These use the existing
power-bound tolerance with a 1 var absolute floor; they do not authenticate the
supplied result or substitute live coefficient-provider values for case data.
The existing P-only near-active Finding retains its meaning. The aggregate
`n_inv_violations` and `n_inv_active` counts now include Q-bound Findings.

Active power always respects the box upper bound above. When the
`control_profile` declares a `volt_watt` sub-object, a **Volt-watt** curtailment
cap $P_{n,k} \leq P^{\text{base}}_{n,k}\, f^{\mathrm{VW}}(U_{n,k})$ is added
*on top*, so the effective limit is the tighter of the two. The base
$P^{\text{base}}_{n,k}$ is selected by `p_ref`: the per-coil rating (`S_MAX`),
the per-coil `p_max` (`P_MAX`), or the unit's scalar available power `p_avail`
shared equally over its **coils** (`P_AVAILABLE`). A two-terminal
`SINGLE_PHASE` unit is one coil and keeps the whole of `p_avail`, whether its
terminals are phase–neutral or phase–phase.

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

!!! warning "Control requests the engine cannot honor fall back, with a warning"
    A control profile is applied only in the forms the native builder supports.
    Otherwise the device keeps its P/Q box and a warning is logged:

    - `volt_var` needs four breakpoints, two `q_limits`,
      `q_unit = "VA_FRACTION"`, and `q_ref = "VAR_MAX"`;
    - `volt_watt` needs two breakpoints, two `p_limits`,
      `p_unit = "VA_FRACTION"`, and `p_ref` in `S_MAX`/`P_MAX`/`P_AVAILABLE`;
    - a profile with both `power_factor` and a droop curve uses the power
      factor and drops **both** curves;
    - an unknown `voltage_reference` is read as `PN_PER_PHASE`; a `PN` reference
      on a unit without a neutral, or a `PP` reference with fewer than two
      phases, is read as phase-to-earth.

    Check the log, or the `modeled_volt_watt` result block, when a study
    depends on the controller being active.

##### STATCOMs (D-STATCOMs)

A **STATCOM** — a *D-STATCOM* in distribution-system terminology — is a
shunt-connected voltage-source converter with no active-power source. It is
modeled as an IBR with `prime_mover = "STATCOM"`: there is no separate object
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

over that IBR's phases. The per-phase boxes $P^{\min}_{n,k} \le P_{n,k} \le
P^{\max}_{n,k}$ still apply, so circulation needs per-phase boxes wide enough to
allow it; the augmentation pass widens them to the apparent-power rating
for a coupled STATCOM. When $P^{dc}_{\min} = P^{dc}_{\max}$ the pair collapses
to a single **equality** row (constraint family `ibr_dc_power_equality`);
otherwise two rows `ibr_dc_power_lower`/`ibr_dc_power_upper` are stamped. An
absent band defaults to $[0, 0]$ in the engine. With
$P^{dc}_{\min} = P^{dc}_{\max} = 0$ — the default the
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
stable `log1pexp`/`logistic` evaluation in full. The `softplus` keyword selects
the implementation: `:user_defined` (default, the registered operator above),
`:builtin` (the same function written with JuMP's built-in nonlinear
primitives, for differentiation wrappers that cannot see a registered
operator), or `:swish`. For a backend with native
logistic support, `softplus=:swish` selects the alternative
$z\,\sigma(z/\varepsilon)$ encoding; it is solver-specific and does not retain
softplus's monotonicity or convexity.

Breakpoint voltages are SI volts of the **monitored quantity** the curve's
`voltage_reference` selects (phase-to-neutral, phase-to-earth, or
phase-to-phase) and are scaled into model units at build time, so the droop is
identical in SI and per-unit mode. The smoothing width is
$\varepsilon = \texttt{volt\_var\_watt\_eps} \times$ the mean breakpoint
voltage (see [Smooth droop encoding](relu_softplus_encoding.md)). Droop is
applied for `SINGLE_PHASE` and `FOUR_LEG` only; a `THREE_LEG` (delta) IBR
has too few degrees of freedom for a per-phase droop, so a profile on it is
ignored (box bounds retained) with a warning. Regional default characteristics
(e.g. AS/NZS 4777.2:2020 "Australia A" for Queensland) are injected by
[`augment_case`](@ref) from the `[augment.smart_ibr]` config section.

By default each phase responds to its own magnitude $U_{n,k}$. Setting the
IBR field **`voltage_aggregation`** to `"AVERAGE"` (default `"PER_PHASE"`) instead
feeds every phase the mean of the phase magnitudes,
$\bar U_n = \tfrac{1}{m}\sum_k U_{n,k}$, as the common reference for both the
Volt-var and Volt-watt curves — modeling IBRs that regulate on the average
terminal voltage rather than per phase. The setting only affects multi-phase
`FOUR_LEG` IBRs; on a `SINGLE_PHASE` IBR it is a no-op and emits a
warning. The [VVWO tutorial](tutorial_vvwo.md) works a Volt-var-Watt scenario
end to end, solving the droop control and the network simultaneously.

The IBR current variables enter KCL with the same sign convention as
generators (injection positive into the bus); for `FOUR_LEG` the negated phase
current is also added to the neutral terminal.

#### Transformers

A transformer is modeled as an **ideal ratio** between coil voltages, a
**series leakage impedance** carried by the winding currents, and a **no-load
(core) admittance** across one winding. All of its rows are voltage and current
equalities that are **linear at a fixed tap**; a free tap makes them bilinear.

Three conventions carry over from the rest of this page and are worth holding
on to before reading the equations:

- every transformer current is the current flowing **from the bus into the
  transformer**, so each terminal contributes $-c^x$ to KCL;
- a wye winding whose terminal map has no neutral is a **solidly grounded
  star** (see [return paths](@ref opf-earth-reference));
- an isolating transformer is the only element across which the per-unit
  voltage base changes, while regulators and autotransformers keep one base on
  both sides (see [Units and scaling](#Units-and-scaling)).

The equations for every subtype — `single_phase`, `center_tap`, `wye_delta`,
`delta_wye`, the two regulator subtypes, and `n_winding` — together with
continuous tap optimization, are on their own page:
[Transformer equations in the OPF](opf_transformers.md). The supported subtypes,
field meanings, nameplate cap, and approximations are in
[Transformer models](transformer_models.md).

#### Kirchhoff's Current Law

KCL is enforced at **every** terminal. Each component accumulates its signed
current contribution (positive = into bus) into per-terminal expressions
$\kappa^r_{b,t}$ and $\kappa^i_{b,t}$:

```math
\kappa^r_{b,t} = 0, \qquad \kappa^i_{b,t} = 0
\qquad \forall\,(b,t)
```

At a grounded terminal $\kappa$ includes the free earth-injection current
$c^\text{gnd}_{b,t}$, so the row is always satisfiable and simply *defines* the
current flowing to earth there. At every other terminal KCL is a genuine
restriction.

Sign conventions:

| Component | Terminal | KCL contribution |
|---|---|---|
| Line from-side | from terminal | $-c^r_\ell$ (leaves) |
| Line to-side | to terminal | $+c^r_\ell$ (enters, since $\tilde{c} = -c$) |
| Load WYE | phase terminal | $-c^{r,d}$ (consumed) |
| Load WYE | neutral terminal | $+c^{r,d}$ (return; absent if the map has no neutral) |
| Load DELTA | positive terminal | $-c^{r,d}$ |
| Load DELTA | negative terminal | $+c^{r,d}$ |
| Generator WYE | phase terminal | $+c^{r,g}$ (injects) |
| Generator WYE | neutral terminal | $-c^{r,g}$ (return) |
| Generator DELTA | positive / negative terminal | $+c^{r,g}$ / $-c^{r,g}$ |
| IBR | phase (or pair-positive) / return terminal | $+c^{r,n}$ / $-c^{r,n}$ |
| Switch | from / to terminal | $-c^r_{sw}$ / $+c^r_{sw}$ |
| Shunt, capacitor, line π-half | each terminal | $-I^{\text{sh},r}$ (leaves to earth) |
| Grounded terminal | the terminal itself | $+c^{r,\text{gnd}}$ (free) |
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

The source-bus **neutral** is fixed to zero, treated as perfectly grounded, and
receives the summed slack return current (see
[Voltage sources](#Voltage-sources) for what that implies for grounding).

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

## [Warm-start initialization](@id Warm-start-initialisation)

Both solvers seed the NLP with a voltage-level- and topology-aware phasor start
without requiring a load-flow pre-solve. The engine assembles one sparse complex
least-squares system from source phasors, grounds, galvanic conductor maps, and
the same ideal zero-current winding equations used by the OPF. It solves that
system in coordinates normalized by each bus's nominal voltage. Consequently a
change among SI, classic per-unit, and a consistent custom policy changes the
numeric `vr`/`vi` coordinates but preserves the complete physical phasor start.

This is deliberately network-wide rather than a bus-by-bus angle rule. A
single-phase lateral inherits the phasor of the *actual mapped parent phase*,
even if the secondary labels it `1`. A center-tap transformer produces equal
magnitude, anti-series legs (θ and θ+180°). Yd/Dy and general WYE/DELTA
`n_winding` units propagate their connection phase shift, including
`delta_roll`, through arbitrary transformer chains. Single-phase and open-delta
regulators contribute their winding and shared-bushing relations. A weak
canonical three-phase prior only chooses coordinates left free by source and
topology equations, such as a floating delta common mode; it does not impose a
balanced-bus claim.

Device currents are seeded so that the bilinear power rows start close to
satisfied rather than at zero current. Constant-power load currents use their
nominal power; generator currents use the midpoint of each finite P/Q box;
Yd/Dy winding currents use the rated magnitude `s_rating / (3·|V|)` in phase
with the transported wye voltage. The auxiliary P/Q variables of every
apparent-power limit are started on their defining equalities, evaluated at
the voltage and current starts. Line and switch currents are not seeded.

IBR currents are seeded from their target complex power and the transported
phase-to-reference voltage using `I = conj(S / V)`. The rectangular components
are `(P*vr + Q*vi)/abs2(V)` and `(P*vi - Q*vr)/abs2(V)` in either SI or per-unit
coordinates. Thus the seed preserves the target's reactive-power sign; it is
still only an initial guess, subject to the limitations below.

!!! important "A warm start selects a trajectory, not a solution certificate"
    The transport solve constructs a deterministic **zero-current voltage
    phasor guess** (the device-current seeds above are added afterwards).
    It is not a loaded power-flow solution, and Ipopt is not guaranteed to return
    the feasible or stationary point nearest to it. Repeating the solve from the
    same start can establish computational reproducibility under a fixed software
    environment; it cannot establish uniqueness of the power-flow root,
    uniqueness of the OPF minimizer, local optimality, or global optimality.
    Multiple materially different starts are useful basin probes, but failure to
    discover another basin is not proof that none exists. Multiple local AC-OPF
    solutions from different initializations are documented by
    [Bukhsh et al. (2013)](https://doi.org/10.1109/TPWRS.2013.2274577).

!!! info "Concept: high voltage and the upper sheet"
    **High voltage** is a descriptive statement about voltage magnitudes relative
    to nominal values. The **upper sheet** is a local power-flow branch
    classification under a *declared continuation path*: it is normally the
    branch connected to the ordinary high-voltage solution before the relevant
    saddle-node (nose) point. Evidence can include a nonsingular power-flow
    Jacobian and the expected local voltage response as demand increases. The
    classification depends on which loads and controls are continued; voltage
    magnitude alone is not a certificate.

    Neither label proves OPF local optimality, OPF globality, transient
    stability, or small-signal stability. Radial and multiphase uniqueness
    results justify useful high-voltage initialization heuristics only under
    their stated assumptions
    ([Dvijotham, Mallada & Simpson-Porco,
    2017](https://arxiv.org/abs/1706.05290);
    [Bernstein et al.,
    2018](https://doi.org/10.1109/TPWRS.2018.2823277)).
    For voltage-sheet and collapse terminology, see Van Cutsem & Vournas in the
    [bounds bibliography](bounds/references.md).

If the transport solve fails or returns a non-finite value, the level-aware
nominal starts are kept; the schema below then reports `applied = false`.

Use `opf_diagnostic_schema(ctx).initialization` to inspect the equation counts and maximum
normalized transport residual by relation family. That evidence describes the
generated zero-current phasor transport only. It is not an initial-feasibility,
loaded-voltage, or convergence certificate. In particular, **zigzag is not yet
a BMOPF transformer connection**: representing it correctly requires an
explicit winding/terminal connection matrix, not inference from names. Such a
component must be added to the schema and OPF equations before its phase shift
can be claimed by initialization.

Transformer-local power bases are a separate equation-scaling problem. Use
`opf_diagnostic_schema(ctx; voltage_bases, power_bases).transformer_scaling` to
audit a proposed scheme. The report requires a common power base inside each
galvanically continuous zone and a common voltage base across each directly
shared regulator conductor. It exposes the exact side-current and side-power
conversion ratios at isolating transformer interfaces and explicitly reports
an inadmissible shared-conductor voltage conversion. A proposal never mutates
the model. When the context was built with qualified zone-local scaling,
the report records `applied_to_model=true`; otherwise it explicitly reports
when new transformer stamping is required.

AC/DC coordinate crossings have a separate public audit,
`opf_diagnostic_schema(ctx).acdc_scaling`. If converter `c` is attached to AC bus
`b`, with local AC power base `S_ac(b)` and DC power base `S_dc`, the native
lossless balance is stamped as

```math
U_{dc,pu} I_{dc,pu} = \frac{S_{ac}(b)}{S_{dc}} P_{ac,pu}.
```

`dc_p_ref` and the output of a droop curve remain in the converter's AC-power
coordinate, while its voltage argument, setpoint, and deadband use the DC
voltage coordinate. The audit exposes both bases and the stamped conversion
factor for every converter; it does not claim that either base choice improves
solver behavior.

## Feasibility relaxation

`solve_feasibility_opf` answers a diagnostic question: *if the network cannot
meet its limits, where would current have to be injected to make it balance,
and how much?* It adds an **elastic slack current**
$(c^{r,\varepsilon}_{b,t},\, c^{i,\varepsilon}_{b,t})$ to KCL at every
terminal that is not perfectly grounded. These variables can absorb any KCL
residual, but they do not relax contradictory source fixes, inconsistent hard
bounds, or other hard equalities:

```math
\kappa^r_{b,t} + c^{r,\varepsilon}_{b,t} = 0, \qquad
\kappa^i_{b,t} + c^{i,\varepsilon}_{b,t} = 0
```

Source-bus phase terminals receive a slack too; the source's own free current
already balances KCL there, so the penalty drives that slack to zero.

The cost objective is replaced by the sum of squared slack currents **in
amperes**:

```math
\min \sum_{(b,t)} w_b\Bigl[\bigl(c^{r,\varepsilon}_{b,t}\bigr)^2
                       + \bigl(c^{i,\varepsilon}_{b,t}\bigr)^2\Bigr],
\qquad
w_b = \begin{cases} 1 & \text{SI model}\\
\bigl(I_{\text{base},b}/I_\text{ref}\bigr)^2 & \text{per-unit model}\end{cases}
```

with $I_\text{ref}$ the largest bus current base. The weight matters on a
multi-voltage network. One per-unit of slack is worth $I_{\text{base},b}$
amperes, which is large on a low-voltage bus and small on a medium-voltage
one; an unweighted per-unit sum would therefore price an ampere differently at
each voltage level and move the slack to a different location than the SI
model does. With the weight, both unit systems minimize the same physical
quantity and localize the infeasibility alike.

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

The DC network's nodal balance is not elastic: a DC-side infeasibility is not
localized by this relaxation.

## Power-flow inverter controls

A power flow has no objective, so the equations alone must determine the
operating point. `solve_pf` therefore requires every dispatchable AC device to
be **determined**, coil by coil, and rejects a case that is not:

| Device | Active power | Reactive power |
|---|---|---|
| Generator | `p_min == p_max` | `q_min == q_max` |
| IBR | `p_min == p_max` | `q_min == q_max`, **or** a control equality the engine actually stamps for that device: constant power factor, or Volt-var |

Both bounds must be present, with **one entry per coil** (one for
`SINGLE_PHASE`, one per phase for `FOUR_LEG`, one per phase pair for
`THREE_LEG`). A missing, short, or one-sided bound is rejected just like a
range, because the solver would otherwise return whatever point its starting
guess led to and report success.

Two refinements follow from asking what is *stamped* rather than what is
*declared*:

- **A control law counts only where it is applied.** `THREE_LEG` carries no
  droop, a malformed Volt-var curve falls back to the reactive box, and a
  constant power factor takes precedence over a droop in the same profile. A
  `THREE_LEG` unit with a Volt-var profile and a reactive range is therefore
  undetermined, and is rejected.
- **A DC side determines one number, and only if it supplies an equation.**
  For a **single-coil** unit the active-power requirement is waived when the DC
  side fixes that power:
  - a private DC link (`dc_link_coupled`) with a zero-width balance
    (`p_dc_min == p_dc_max`); a balance *range* determines nothing;
  - a `dc_bus` converter in `"droop"` mode (its V–P law) or `"V"` mode (it
    balances the DC network at its voltage reference).

  A `"P"`-mode converter is a dispatched injection and needs a fixed setpoint
  like any other device: with two ranged `"P"`-mode units on one DC bus, DC KCL
  fixes their sum and leaves the split free. A standalone `dc_source` must
  likewise be a fixed injection (`p`, or `p_min == p_max`).

  Voltage masters need one more condition. A master without a fixed setpoint
  contributes one unknown current between its two DC nodes, and DC KCL gives
  one equation per node, so those currents are determined exactly when the
  free masters' ports form a **forest** over the DC nodes — no loops. Two free
  masters on one port, at the two ends of an ideal tie, or around a triangle of
  ports (p−m, m−n and p−n on a bipolar bus) can circulate power among
  themselves and are rejected. Nodes are electrical: terminals joined by
  zero-resistance conductors, or perfectly grounded, are one node. A multi-coil unit always needs each
  coil's active power fixed, because the DC side fixes only their sum.

These checks are made on the case first, and then once more on the rows the
builder stamped. The second pass matters when a coefficient provider is in
use: a bound that is fixed in the case can be replaced by a wider number or a
live parameter while the model is built, and a power flow must be determined in
the model that is solved, not only in the data it was read from. A setpoint
supplied as one parameter for both ends of the bound still counts as fixed.

The engine avoids stamping the same equation twice when static data already
implies it; see [Dependent equality rows](@ref opf-dependent-rows). Loops of
ideal conductors and contradictory DC voltage references are not reduced but
rejected, and static validation reports them first as `E.INT.IDEAL_LOOP`,
`E.INT.DC_IDEAL_LOOP` and `E.INT.DC_REFERENCE_CONFLICT`.

Volt-var specifies a reactive-power equality. Volt-watt specifies only an
active-power **upper bound**, which is why a Volt-watt profile does not
determine the dispatch and a fixed active setpoint is still required. A fixed
setpoint above the Volt-watt cap is incompatible with the controller; power
flow does not disable that cap.

`solve_pf` drops operational limits (voltage bounds, line, switch, generator,
and IBR current limits, line and DC-branch power limits). Three kinds of limit
are **kept**:

- transformer nameplates: `s_rating` on the two-winding subtypes, and the
  per-winding `s_max` and `i_max` of an `n_winding` transformer;
- voltage-source P/Q bounds;
- declared IBR `q_min`/`q_max`.

An inverter's `s_max` is retained as the normalization base for `S_MAX`
Volt-watt and `VAR_MAX` Volt-var curves, while its apparent-power constraint is
omitted. A power flow that returns an infeasible status on an otherwise healthy
network is often a nameplate being exceeded; remove the rating to compare
against a limit-free reference.

For how tightly a determined solve satisfies its equations, see
[Zero-degree-of-freedom solves](@ref solver-square-termination).

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
| `opf_diagnostic_schema(ctx)` | versioned scaling, initialization, interface, and semantic-block evidence |
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
    scale = opf_coordinate_bases(ctx, "bus1").power
    @constraint(opf_model(ctx), vr*crg + vi*cig <= 150e3 / scale)
end)
```

The model is solved in the model's working units: per-unit by default, SI
when `per_unit=false` — scale hand-written constants accordingly (the example
above divides by the bus power base).

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
battery's state of charge. For that, the same pipeline is exposed as
composable steps that let you build **several snapshots into one JuMP model**,
add your own inter-temporal constraints, solve once, and extract each snapshot:

| function | role |
|---|---|
| `build_opf_model(net; model, add_objective, model_hook!, …)` | build one snapshot's devices/bounds into a (shared) model; no KCL, no solve |
| `generation_cost(ctx)` | that snapshot's cost-rate expression (\$/h), unset — duration-weight and sum across snapshots for one monetary objective |
| `enforce_kcl!(ctx)` | pin KCL for one snapshot (call once per snapshot before solving) |
| `optimize_opf!(ctxs...; kwargs...)` | validate supplied contexts, finalize missing KCL, and solve their shared model once |
| `extract_result(ctx; solution_hook!)` | extract one snapshot's SI result after the shared solve |

Pass the same `model` to every `build_opf_model` call and `add_objective=false`
so the snapshots share one optimization and one objective. Each `ctx` keeps its
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
optimize_opf!(ctxs...)
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
hosts estimation and fitting problems that are not dispatch optimization at all.

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
optimize_opf!
generation_cost
extract_result
```


## Minimum power factor for generation

The native JuMP OPF builder accepts a versioned **BMOPFTools policy** under the
existing schema's free-form `extras` escape hatch. This is a package extension,
not an official Task Force field or a change to the bundled schema:

```julia
net["extras"] = Dict("bmopftools" => Dict("minimum_power_factor" => Dict(
    "schema" => "bmopftools.minimum_power_factor/v1",
    "ibr" => Dict("pv" => Dict(
        "pf_min" => 0.8, "direction" => "generation", "scope" => "per_coil")))))
result = solve_opf(net)
report = profile_solution(net, result)
```

When a case already has extras, insert this policy into its existing dictionaries
to retain other metadata. Normal JSON parsing/serialization preserves the policy.
Other engines/consumers must explicitly implement this package policy; do not
assume they enforce it merely because they accept the case JSON. The existing
`domain_rules.pf_min` setting remains only a load-validation warning threshold.

Each request needs exactly `pf_min`, `direction="generation"` and
`scope="per_coil"`; PF must be finite and satisfy `0 < pf_min <= 1`. The request
must reference an existing IBR with explicit nonnegative `p_min` for every coil;
any declared `p_max` must also be finite, nonnegative and cover every coil.
Consumption, bidirectional operation, aggregate PF and DC-coupled converters
are outside this initial domain and rejected. There is no implicit conversion
to an absolute-P envelope. Unknown policy versions/fields, unresolved profiles,
ambiguous terminal maps and unsupported topologies are rejected too.

For `m = pf_min` the native model enforces per coil:

```math
P \ge 0, \qquad m Q \le \sqrt{1-m^2}\,P, \qquad -m Q \le \sqrt{1-m^2}\,P.
```

These bounded-coefficient rows are equivalent to `-k*P <= Q <= k*P` with
`k = tan(acos(m))`, but avoid forming a huge tangent near m=0. They use **actual
dispatched P**, including after curtailment or live availability updates. At
P=0 they force Q=0; PF itself remains undefined at zero apparent power.
At m=1 they force Q=0 while retaining the explicit generation constraint.
P and Q are positive injections. Both reactive directions are permitted;
a one-sided `q_min`/`q_max` can restrict the direction further.

For SINGLE_PHASE the requirement applies to its two-terminal coil; for FOUR_LEG
it applies to each phase-neutral coil; for THREE_LEG it applies to each cyclic
delta pair, not to conductor power or an aggregate ratio. An unbalanced device
can satisfy aggregate PF while violating one of these per-coil requirements.
The equations are affine in P/Q, but those powers contain V–I products in IVR,
so the complete model remains nonlinear.

P/Q boxes, apparent-power circles and conductor-current limits stay enforced.
Compatible signed constant PF may be combined with the envelope when
`abs(pf) >= pf_min`; a lower constant PF is rejected explicitly. The usual sign
convention is retained: positive constant PF absorbs Q for P>0; negative injects
Q. Constant PF plus droop is rejected when this minimum-PF policy is enabled;
without the policy the existing PF-over-droop warning/precedence is retained.

SINGLE_PHASE and FOUR_LEG may combine minimum PF with supported Volt-var and/or
Volt-watt curves: `VA_FRACTION`, Volt-var `VAR_MAX`, and Volt-watt `S_MAX`, `P_MAX`
or scalar `P_AVAILABLE`, with finite ordered breakpoints, valid limits and
complete normalization bases. Optional control options that the native resolver
would otherwise ignore (including Volt-var low-P thresholds) are rejected in
this combined policy. THREE_LEG droop remains unsupported and is rejected here.
A control equality is never clipped to fit the envelope. Conflicting Q bounds
or droop targets can make the intersection infeasible.

Constraint keys use families `ibr_minimum_pf_generation`,
`ibr_minimum_pf_lower`, and `ibr_minimum_pf_upper`, indexed by `(ibr_id, coil)`.
A limit of exactly one is the boundary case: the wedge
$\lvert Q\rvert \le \tan\varphi\, P$ closes to the half-line $Q = 0$, $P \ge 0$.
The two wedge rows would then read $Q \le 0$ and $-Q \le 0$, a pair with no
interior and no unique multipliers, so the engine stamps the single equality
`ibr_minimum_pf_equality` in their place (`ibr_minimum_pf_generation` is kept).
That equality is omitted when another row already states $Q = 0$ for the coil —
a reactive box pinned at zero (`ibr_q_equality`) or a unity constant power
factor (`ibr_power_factor`) — since a second identical equality would leave the
coil with more equalities than unknowns.
The policy itself is fixed at model construction, not a live coefficient knob;
rebuild to change it. Existing live P/Q/capability coefficients remain live.

`profile_solution` and the existing `execute_solution_verification` operation
report `results["solution"]["minimum_power_factor"]`, containing policy provenance,
configuration errors and per-coil `passed`/`failed`/`indeterminate` evidence.
The independent check uses supplied P/Q, not solver termination as an oracle:
`max(-P, m*abs(Q)-sqrt(1-m^2)*P)` must be at most
`max(1e-6, 1e-6*max(abs(P),abs(Q)))` VA. Missing/nonfinite dispatch or no candidate
is unassessed. At exactly P=0, the checker uses `abs(Q)` directly so tiny PF
coefficients cannot hide reactive-only dispatch. Diagnostic infeasible candidates
can still expose violations.
This checks the case-authored policy, not live coefficient overrides or solver
stamping/provenance; passing it is not a complete feasibility certificate. The curated `verify_solution` recipe exercises the JSON path.

Compatibility change: malformed, zero or out-of-range constant PF is now
rejected with `E.INT.CONSTANT_PF_INVALID`, rather than silently dropping PF or
throwing later inside trigonometry. Remove the `power_factor` sub-object to
request freely dispatchable Q. The accepted numeric range in the bundled
Task Force schema is unchanged; this is stricter executable applicability.

Constant-PF equations use bounded coefficients `pf*Q + sqrt((1-|pf|)*(1+|pf|))*P = 0`,
including very small positive PF magnitudes where `tan(acos(|pf|))` loses the
requested ratio. This avoids an unbounded model coefficient; it does not promise
relative solver accuracy for dispatch below the solver's absolute tolerances.
The supplied-result constant-PF diagnostic records its scaled residual definition
and threshold explicitly, retaining the existing Q-equivalent relative tolerance.
Values that underflow to zero in Float64 are rejected.
