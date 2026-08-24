# [Choosing an objective](@id objectives)

`solve_opf` minimises generation cost. That is one choice among many, and for a
lot of distribution questions it is the wrong one: least-cost dispatch has no
opinion about losses, and no opinion at all about unbalance.

This page is the catalogue of the objective terms BMOPFTools ships, what each
one *does to the answer*, and — as importantly — when not to use it.

## The shape of a composed objective

Build the model without its default objective, assemble terms, set them, then
enforce KCL and solve:

```julia
using JuMP, Ipopt

ctx = build_opf_model(net; add_objective = false)

terms = [
    opf_loss_term(ctx;              weight = 1.0),          # per W
    opf_sequence_term(ctx, ["b1"];  weight = 50.0,          # per V²
                      component = :negative, norm = :squared),
]
set_opf_objective!(ctx, terms)

enforce_kcl!(ctx)          # REQUIRED — see the warning below
JuMP.optimize!(opf_model(ctx))
result = extract_result(ctx)
```

!!! danger "`enforce_kcl!` is not optional"
    `build_opf_model` defers KCL so a `model_hook!` can still contribute to the
    nodal accumulators. Until [`enforce_kcl!`](@ref) runs, **the network is
    electrically disconnected**: bus voltages are free variables and your
    objective is minimised without physics. An unbalance objective in particular
    reaches exactly zero with every compensator idle, which reads as a great
    result.

    This used to fail silently — `LOCALLY_SOLVED`, plausible numbers, no
    warning. It is now an error: `JuMP.optimize!` refuses a model holding any
    unstamped context, and [`extract_result`](@ref) refuses an unstamped
    context. Pass `kcl_guard=false` to `build_opf_model` if you deliberately
    want the optimise-time check off.

## The catalogue

| Term | Physical unit | Smooth? | Convex? | What it does |
|---|---|---|---|---|
| [`opf_generation_cost_term`](@ref) | currency/hour | exact | quadratic | The `solve_opf` default. Cheapest dispatch. |
| [`opf_loss_term`](@ref) | W | exact | bilinear, non-convex | Least-loss dispatch. |
| [`opf_sequence_term`](@ref) `norm=:squared` | V² | exact | quadratic | Reduces unbalance everywhere a little. |
| [`opf_sequence_term`](@ref) `norm=:magnitude` | V | to ε | group-lasso | Drives a few buses to balanced. |
| [`opf_sequence_term`](@ref) `norm=:max` | V² | exact | convex quadratic epigraph | Protects the worst bus. **Minimisation only.** |
| [`opf_current_term`](@ref) `quantity=:neutral` | A² or A | exact / to ε | per `norm` | Reduces neutral conductor current. |
| [`opf_current_term`](@ref) `quantity=:sequence` | A² or A | exact / to ε | per `norm` | Reduces zero-/negative-sequence current. |
| [`opf_control_effort_term`](@ref) | A² or A | exact / to ε | per `norm` | Penalises moving devices off a reference. `:magnitude` gives device-level sparsity. |
| [`opf_vuf_term`](@ref) | %² | exact | ratio, non-convex | **Squared** VUF penalty. Needs `vpos_min`. Not a drop-in for VUF — see Pitfalls. |

Anything not on this list you can build yourself from
[`opf_sequence_voltage`](@ref), [`opf_element_loss`](@ref),
[`opf_neutral_current`](@ref), [`opf_sequence_current`](@ref),
[`opf_reduce_norm`](@ref) and [`smooth_norm`](@ref), wrapped in an
[`OpfObjectiveTerm`](@ref).

### Voltage unbalance or current unbalance?

They are different objectives and they do not have the same optimum.

Voltage unbalance is what a *standard* limits. EN 50160:2010 §3.5 caps the
voltage unbalance factor at 2%, and IEC 61000-2-2:2002+A1:2017+A2:2018 gives the
compatibility level; both define it as the **ratio** `|V₂|/|V₁|`.

Declare that with the bus field **`vuf_max`** (dimensionless: `0.02` = 2%),
which is enforced exactly as `|V₂|² ≤ u²|V₁|²`. `vneg_max` bounds `|V₂|`
**absolutely** and is only equivalent to a ratio limit if `|V₁|` is treated as
fixed at nominal — a reasonable approximation, but an approximation.

A standard's limit is also a *temporal* compliance criterion (EN 50160 assesses
10-minute means across a week). A snapshot OPF constrains one instant; satisfying
`vuf_max` is necessary for compliance, not sufficient to demonstrate it.

Current unbalance is what *heats things*. `opf_current_term` with
`quantity=:neutral` targets the neutral conductor current directly, which is the
quantity behind neutral heating (`|Iₙ|²R`) and 4-wire losses. Note that
**zero-sequence VOLTAGE is neither neutral displacement nor neutral heating**:
on a floating-neutral bus the transform's input is already phase-to-neutral, so
`V₀` has the common displacement subtracted out. Neutral displacement is `Vₙ`
itself (bound it with `vn_max`); neutral heating is a current quantity. On a 4-wire element with no
parallel earth path `I_n = −3·I₀`, so a neutral penalty and a zero-sequence
current penalty are the same objective up to a factor of three — but the neutral
form is in amps of real conductor current, which is easier to reason about
against a conductor rating.

A rough rule: if you are answering to a limit, penalise voltage; if you are
answering to a thermal or loss question, penalise current.

## Weights carry units — and that is deliberate

A weight is declared **per physical unit**: per W for losses, per V² for a
squared voltage penalty, per V for a magnitude one. Term expressions are
converted to physical units before weighting.

The consequence worth relying on: **the same specification gives the same
answer in `per_unit = true` and `per_unit = false`**, and keeps doing so under a
future nondimensionalisation. This mirrors what the engine already does for
generation cost, where the per-unit working net pre-scales every cost
coefficient by `s_base` so the factors cancel.

!!! warning "That invariance is over unit modes, not over target sets"
    Reductions **sum** over their targets, so a term's magnitude grows with how
    many buses or devices you list. A weight tuned against three buses does not
    mean the same thing against thirty. Re-tune when the target set changes, or
    compare only across studies with the same one. ([#373](https://github.com/frederikgeth/BMOPFTools.jl/issues/373)
    tracks adding a `:mean` aggregation, which would make weights portable
    across target-set sizes.)

What is *not* handled, and cannot be: **commensurability**. Summing
currency/hour with V² is only meaningful once your weight states the exchange
rate you intend. No check can infer that.

!!! warning "Switching `norm` changes what your weight means"
    `:squared` and `:max` are in the **square** of the quantity's unit;
    `:magnitude` is in the unit itself. A weight of 50 means "50 per V²" in one
    and "50 per V" in the other — a factor of ~230 apart on an LV feeder. The
    objective value looks perfectly reasonable either way. Re-tune when you
    switch, and read the recorded `units` on the term to check yourself.

Every term is registered as a regularization declaration carrying its weight,
units and purpose, so what you combined is recoverable afterwards from
[`opf_regularizations`](@ref) and fingerprinted by
[`opf_research_hashes`](@ref). A weighted objective whose weights are not
recorded is not a reproducible experiment.

## Which norm?

Every penalty on a complex quantity has to reduce a phasor to a scalar. The
three reductions give **different answers**, and choosing between them is a
modelling decision:

- **`:squared`** — L2. Spreads the penalty. Improves every target a little.
  Cheapest and most reliable. Start here.
- **`:magnitude`** — the group-lasso norm, `Σ‖(re, im)‖₂`. Drives *individual*
  targets to (near) zero rather than shrinking all of them. Use it when you want
  "fix these few completely" rather than "improve everything slightly".
- **`:max`** — L∞. Minimises the worst target. A fairness objective. Exact
  through an epigraph over **squared** magnitudes, because `max` is monotone
  under squaring, so no square root is needed. The epigraph variable enters
  linearly but each constraint is a convex quadratic. It is exact **only while
  being minimised with a non-negative weight** — the constraints bound it from
  below only, so maximising it is unbounded. `set_opf_objective!` refuses that
  combination rather than handing the solver an unbounded problem.

!!! danger "Never reduce a phasor componentwise"
    `|re| + |im|` is **not rotation-invariant**: the answer would depend on your
    phase reference. That is a bug, not a modelling choice. `:magnitude` sums
    per-element 2-norms precisely to avoid it. If you build a custom term, use
    [`smooth_norm`](@ref) rather than summing absolute values of real and
    imaginary parts.

## Losses are not cost, and cost is not losses

With heterogeneous generation prices these two objectives actively disagree.
Least-loss dispatch will happily source from an expensive nearby unit rather
than transport cheap distant power; least-cost dispatch will push power across
the network to reach a cheap generator and pay for it in `I²R`. Combining them
is a deliberate act with a weight that states your exchange rate — not a
formality.

## What needs a square root, and what does not

A recurring mistake is reaching for a magnitude when a squared quantity would
do. Squared quantities are exact, smooth, cheaper, and better conditioned.

| Quantity | Needs `smooth_norm`? | Why |
|---|---|---|
| Network loss `Σ V·conj(I)` | **No** | Bilinear in (V, I) — an exact smooth quadratic. |
| `\|V₂\|²`, `\|I₀\|²` | **No** | The Fortescue transform is linear, so the square is a plain quadratic. |
| Current/apparent-power **limits** | **No** | Naturally squared: `ir² + ii² ≤ i_max²`. |
| Worst-case (L∞) of a magnitude | **No** | `max` is monotone under squaring. |
| `Σ\|V₂\|` (group-lasso) | **Yes** | A genuine 2-norm sum. |
| VUF = `\|V₂\|/\|V₁\|` | **Yes** | A ratio of magnitudes. |
| Conduction loss `a·\|I\|` | **Yes** | Linear in current, and an idle leg sits at exactly zero. |

## [Sizing ε — two regimes with opposite guidance](@id Sizing-ε)

[`smooth_norm`](@ref) approximates `‖·‖₂` by `√(x² + y² + ε²) − ε`, which
underestimates the exact norm by at most `ε` and is C^∞ everywhere including the
origin (where the exact norm's AD gradient is `0/0` and Ipopt rejects the model
outright).

`ε = eps_rel × scale`, where `scale` is the quantity's characteristic physical
magnitude. One `eps_rel` therefore means the same *relative* smoothing for a
voltage penalty and a current penalty, in either unit mode.

**The safe range for `eps_rel` depends on how the norm is used, and guidance
that is right in one regime is wrong in the other.**

**Regime 1 — the norm is being minimised** (every `:magnitude` term here). The
solver's endgame happens *inside* the smoothed region, so ε controls
conditioning directly. Measured over 40 configurations
(`bench/sequence_objective_norms.jl`):

| formulation | converged | median iters | max iters |
|---|---:|---:|---:|
| `:squared` (reference) | 40/40 | 21 | 28 |
| `:magnitude`, ε_rel = 1e-3 | 40/40 | 19 | 59 |
| `:magnitude`, ε_rel = 1e-6 | 39/40 | 71 | 1184 |
| `:magnitude`, ε_rel = 1e-9 | **27/40** | 116 | 3000 |

**Keep ε large** — the `1e-3` default. (Scope: one case family, Ipopt at its
default tolerance. Enough to pick between the alternatives tried; re-run
`bench/sequence_objective_norms.jl`, which prints its own environment, before
relying on it elsewhere.) The accuracy price is irrelevant: even
ε_rel = 1e-2 resolves `|V₂|` to ~1e-7 V against an EN 50160 VUF limit of ~4.6 V
on a 230 V base.

**Regime 2 — the norm is a coefficient** in a term whose optimum is *away* from
zero, such as a conduction loss `a·|I|`. The solver never enters the smoothed
region, ε is invisible to conditioning, and it can be as small as your accuracy
target wants. Upstream measurements in that regime report iteration counts
identical from ε_rel = 1e-2 down to 1e-18.

!!! warning "Do not carry an ε policy across that boundary"
    Anchoring ε just under the solver tolerance is correct in regime 2 and
    fails a third of the time in regime 1.

!!! warning "ε shifts the trade-off in a weighted objective"
    For a *pure* norm objective ε does not move the minimiser — `√(x²+ε²) − ε`
    is still minimised at `x = 0` — it only flattens the gradient near zero, so
    the solver stops a little earlier and looser. In a **weighted** objective
    like `cost + λ·unbalance` that flattened gradient competes against the other
    term, so ε *does* move the answer. Treat it as part of the model there, and
    report it alongside λ.

## Why not an exact cone?

The textbook exact form of a minimised magnitude is the epigraph
`min t s.t. x² + y² ≤ t²`. It is not used here, and the reason is measured
rather than argued: on the same 40 configurations it reported
`LOCALLY_INFEASIBLE` on **3/40**, all high-compensator-authority cases, while
the smoothed norm at a sensible ε never failed. This project ranks convergence
reliability above wall clock.

That is a result for one case family on one solver at its default tolerance —
enough to choose between the alternatives tried, not a general claim. The
benchmark records its own Julia/Ipopt/platform versions and tolerance.

The exception is `:max`, where the epigraph is **linear** rather than conic —
there it is exact, cheap and reliable, and it is what `:max` uses.

## [Pitfalls](@id objective-pitfalls)

Every entry here is a mistake that was actually made while building these terms,
kept so it is not made again. The first four change your *answer* without
changing anything that looks wrong.

### Do not put a smoothed norm inside a ratio

The `ε` that makes a vanishing norm well-conditioned is the same `ε` that
destroys a ratio built on that norm. `smooth_norm` subtracts `ε` from its
result, so a ratio of two smoothed norms is

```
(|V₂| − ε) / (|V₁| − ε)     rather than     |V₂| / |V₁|
```

With `ε` sized for conditioning (`1e-3` of a 260 V scale, so `ε = 0.26 V`) and a
true `|V₂|` of 0.6 V, that mis-states VUF by **more than 40%**. The objective
value looks entirely plausible.

This is why [`opf_vuf_term`](@ref) is the *squared* ratio, which needs no `ε` at
all. Whenever a magnitude appears in a denominator, or anywhere its small
absolute value matters rather than just its ordering, use squared quantities.

### Squared VUF is not a drop-in replacement for VUF

`x ↦ x²` is monotone, so minimising `VUF²` and minimising `VUF` agree **for one
bus as the sole objective**. Neither generalisation preserves that, and both are
implemented:

- **Summed over buses**, `Σ VUFᵢ²` and `Σ VUFᵢ` rank differently. VUFs of
  `(0, 2)` give sum `2`, sum-of-squares `4`; `(1.1, 1.1)` give `2.2` and `2.42`.
  Unsquared prefers the first, squared the second — squaring is an implicit
  preference for evenness. If you mean the worst bus, use `norm=:max`, which
  *is* order-equivalent to worst-bus VUF.
- **Combined with another term**, squaring changes the scalarisation, so the
  trade-off point against cost or losses moves.

Report the unsquared number with [`opf_report_vuf`](@ref) rather than reading
the objective value.

### `vneg_max` is not a VUF limit

`vneg_max` bounds `|V₂|` absolutely; a standard's unbalance limit is the ratio
`|V₂|/|V₁|`. They coincide only if `|V₁|` is fixed at nominal. Use `vuf_max` for
the exact ratio bound.

### A dimensionless bound is enforced to different precision in the two unit modes

`vuf_max` is a ratio, so it is deliberately **not** rescaled by
`_pu_scale_buses!` — the same number means the same limit in per-unit and in SI.
The *semantics* are unit-mode independent. The *numerical enforcement* is not.

The constraint residual `|V₂|² − u²|V₁|²` is dimensionful (volts²) while `u` is
not, so its absolute magnitude differs between modes by `v_base²` — about
`5×10⁴` on a 230 V feeder. Ipopt's `constr_viol_tol` is an **absolute**
tolerance, so at the default setting the same bound is satisfied to roughly
`2×10⁻³` relative in per-unit and `1×10⁻⁷` relative in SI.

This is solver tolerance, not a scaling defect: tightening `constr_viol_tol`
drives the per-unit overshoot monotonically to zero (measured `2.2×10⁻³` at the
default, `2.0×10⁻⁵` at `1e-10`, `2.2×10⁻⁷` at `1e-12`). If you need a
dimensionless bound honoured to tight relative precision in per-unit, tighten
`constr_viol_tol` rather than padding the bound.

### A feasibility solve cannot tell you whether a bound works

Checking a constraint by minimising a constant (`@objective(m, Min, 0.0)`) looks
like the neutral way to ask "is this bound respected?". It is not, for two
reasons.

A feasibility problem has **no unique solution**: the interior-point method stops
wherever the barrier happens to land, so the answer is not determinate, two unit
modes will not agree on it, and a bound that is nowhere near active still
"passes" a `≤ limit` check. And an unreachable bound tends to surface as
`ITERATION_LIMIT` rather than `LOCALLY_INFEASIBLE` — the solver grinds instead of
proving infeasibility, so you cannot distinguish "too tight" from "too slow".

Exercise a bound under a **real objective** that pushes against it. Then the
constrained optimum is determinate, the bound is genuinely active, and both unit
modes converge to the same point.

### An epigraph term is only exact when minimised

`norm=:max` builds `t` with `re² + im² ≤ t`, which bounds `t` from **below**
only. It equals the maximum while being pushed down, and is **unbounded** if
maximised or given a negative weight. `set_opf_objective!` rejects those, but the
underlying asymmetry is worth knowing before writing a custom epigraph term.

### Do not carry an ε policy between regimes

Anchoring `ε` just under the solver tolerance is correct when the norm is a
coefficient, and fails **13 times out of 40** when the norm is what you are
minimising. See [Sizing ε](@ref) above. One `eps_rel` is not a global constant.

### Do not size ε from a unit-conversion factor

`ε = eps_rel × scale` needs `scale` to be the quantity's **characteristic
magnitude** (≈230 V for an LV phase voltage), not the working→physical
conversion factor. They differ: in per-unit the conversion factor *is* about
230, but in SI it is `1.0`. Using the conversion factor gives `ε = 0.23 V` in
one mode and `1e-3 V` in the other — different smoothing, different answers,
from one specification. [`opf_physical_scale`](@ref) is the conversion factor
and is deliberately *not* what sizes `ε`.

### An exact reformulation is not automatically the reliable one

The textbook epigraph for a minimised magnitude is exact and looks obviously
correct. Measured, it fails 3/40 where the smoothed form fails none. Reach for
measurement before intuition on solver behaviour; `bench/sequence_objective_norms.jl`
is there to be re-run.

### Do not reduce a phasor componentwise

`|re| + |im|` is not rotation-invariant — the answer depends on your phase
reference. Always a bug. Use [`smooth_norm`](@ref).

### Expect ~1e-4, not ~1e-8, when comparing unit modes

The engine's physics agrees between `per_unit=true` and `per_unit=false` to
~1e-8 on voltages. But losses, `|V₂|` and VUF are all **small differences of
large numbers** — a 61 W loss out of 7.5 kW of terminal power, a 0.6 V `V₂` out
of 230 V phase voltages — so that agreement is amplified by two to three orders
in any of them. This is inherent to the quantity, not a defect. Writing a `1e-8`
tolerance against one of these asserts something arithmetic cannot deliver.

### `smooth_norm` is not exactly zero at zero, and its bound is not exact in Float64

Two floating-point consequences worth knowing before you assert on them:

- At an exactly-zero argument the result can be a tiny **negative** number
  (~`-1e-19 × scale`), because `sqrt(ε²)` need not round-trip to `ε`. Do not
  assert strict non-negativity.
- The `≤ ε` accuracy bound is exact in real arithmetic but holds only to
  rounding in `Float64`: the achievable resolution is the ulp of the *result*,
  not of `ε`. At `(1e6, 1e6)` with `ε = 1e-6` one ulp is ~2.3e-10, five orders
  above `ε`.

### Two objectives that sound alike and are not

- **Cost and losses.** With heterogeneous prices these actively disagree — see
  above, and the [tutorial](@ref tutorial-objectives) where least-loss dispatch
  costs 28% more and least-cost dispatch loses 3.6× more.
- **Voltage unbalance and current unbalance.** Minimising neutral current can
  make `|V₂|` *worse than doing nothing about unbalance at all*. If someone says
  "we minimise unbalance", ask which one.

### A weight is unit-mode invariant, not target-set invariant

Reductions sum over targets, so adding buses to a penalty scales it up. "Tuned
once" means across `per_unit` modes, not across different target lists. See
[#373](https://github.com/frederikgeth/BMOPFTools.jl/issues/373).

### `:magnitude` only differs from `:squared` when targets compete

Group-lasso sparsity needs **independently controllable** targets. On a radial
path with one compensator the targets are coupled — one degree of freedom — and
both norms find the same point. Prefer `:squared` there: exact, cheaper, no `ε`.

## Reproducibility

```julia
opf_regularizations(ctx)     # every term: weight, units, purpose
opf_differentiability_annotations(ctx)   # every smoothing and its ε
opf_research_hashes(ctx)     # fingerprints over both
```

Any `smooth_norm` you stamp records itself, so an approximation in your model is
never silent.
