# OPF engine: scope & status

BMOPFTools ships **one reference optimizer**: a nonconvex **four-wire rectangular
current–voltage** optimal power flow engine (see its
[formulation principles](../opf.md#Formulation-principles)), in a package
extension that activates when JuMP and Ipopt are loaded. It is not a general OPF framework, and
it is deliberately the *smaller* half of the project. As the
[positioning page](../positioning.md) puts it, the product is the model and the
tooling around it, not the solver; the [bounds & feasibility](../bounds/index.md)
series is written to be formulation-agnostic precisely because the benchmarks are
meant to be solved by many engines, not just this one.

This page sets the bar for contributions to the engine and the modeling
conventions a new constraint or element should follow.

## The correctness bar

The engine exists to **validate cases and profile solutions**, so its first
obligation is correctness, not features. The mathematical models and methods are
established, not exploratory:

- The formulation is fully derived in `docs/math-model.tex`.
- Feasibility / correctness is checked, not assumed: see
  [`solve_feasibility_opf`](../validation.md) and the relaxed power-flow
  cross-check against OpenDSSDirect in the test suite.
- The [bounds & feasibility](../bounds/index.md) series documents *why* a given
  bound/objective combination is well-posed (or not), and
  [Validating the OPF](../validation.md) is the practical checklist.

The expectation for a new formulation, constraint, or element is therefore:

1. **It is mathematically established** — cite the model (the math-model
   document, the spec, or the literature), don't invent physics in the solver.
2. **It is validated against a known-good reference** — a power-flow comparison
   against OpenDSSDirect, an analytic case, or an existing benchmark with a
   known solution. A constraint that only "looks right" is not enough; the
   feasibility/correctness of the model is the thing being benchmarked.

!!! warning "Not a model zoo"
    It is **not in scope** to accumulate every state-of-the-art formulation here
    so they can be compared through BMOPFTools. That is not what this engine is
    for. The Task Force's role is to navigate towards a *workable, broad spec* —
    a common, faithful representation that can serve as the **basis for your own
    bespoke extensions and formulations**, which you build in your own code or
    framework. If a piece of that work later becomes accepted practice, it can be
    folded back in here (via the spec and the [migration path](versioning.md)).
    Until then, the engine stays small and correct rather than broad.

## Modeling preferences

New constraints should stay consistent with how the engine is built. A few
preferences in particular:

- **Current limits over power limits.** Branch and thermal ratings are already
  current-based (`i_max`). For **device injections**, limits are still mostly
  power-based (`p_max` / `q_max` / `s_max`), with the IBR current limit `i_max`
  an optional add-on — so this is a *preferred direction*, not a description of
  the whole engine. A current bound stays linear or quadratic in the rectangular
  IVR variables and avoids bilinear power expressions, so **new injection
  constraints should prefer a current form where practical**. (This mirrors the
  Tier-3 note in the [style guide](style_guide.md).)
- **Impedance over admittance, for series elements.** Series elements (lines,
  transformer windings) should retain **impedance** equations at their ideal
  limits, avoiding inversion of singular series impedance. The fixed-tap
  center-tap builder deliberately uses a coupled primitive-admittance stamp
  with nonzero leakage arms; its free-tap/zero-arm branch uses the T-model. Distinguish **lossless** (`R = 0`) from **zero impedance** (`Z = 0`):
  for scalar `X ≠ 0`, `1/(jX) = -j/X` is finite and purely imaginary. The
  singularity is at `Z = 0`, or a singular matrix `Z`, rather than at zero
  resistance alone. Shunts and the transformer no-load branch remain naturally
  represented by `G + jB`.
- **Put valid bounds on current variables where possible/reasonable.** The
  current variables are first-class in an IVR formulation, and giving them sound
  bounds tightens the feasible region and helps the solver. Where a defensible
  current bound exists (a conductor ampacity, a converter limit), prefer to state
  it on the current variable directly.
- **Bounds are largely optional — do not infer one from another.** Many, if not
  all, of the bounds in the data model are optional, and different formulations
  activate different subsets (see [Optimal power flow](../opf.md)). So you
  **cannot** assume that the presence of, say, a power bound lets you derive a
  current bound: the case may carry one, both, or neither, by design. Stamp a
  constraint only from data that is actually present; never synthesise a missing
  bound from an unrelated one.

### [Zero impedance: represent it as is, don't approximate it](@id zero-impedance)

Represent a physically ideal branch by its exact zero impedance. The native
engine retains branch currents and stamps voltage-equality or ideal-transformer
rows; **it does not automatically merge buses**. Network transformations such as
`fix_case` and `simplify_network` are separate operations with their own
preservation requirements.

Avoid inventing a small impedance solely to imitate an ideal connection. However,
there is no universal `κ ∝ 1/|Z|` law for the IVR KKT system, nor a guarantee that
`Z = 0` is well-conditioned. Scaling, topology, independent references, and
constraint rank matter. Ideal cycles can leave circulating currents undetermined
and voltage rows dependent; the native guard detects structural ideal-conductor
cycles, parallel edges, and self-loops after coefficient resolution. Symbolic
parameters are not classified from their current value, and general dependent
transformer-ratio relations are not covered. A physically small nonzero impedance should
remain in the model unless an explicit, justified transformation changes it.

## Runtime limits

- **Line angle convention:** `va_diff_*` bounds `θ_from − θ_to`. Both bounds
  must be supplied, finite, ordered, and strictly inside `(-π/2, π/2)`.
  One-sided windows are rejected rather than completed with an implicit bound.
  The encoding does not define an angle at zero voltage. Unsupported windows
  raise `ArgumentError`.
- **Bus angle convention:** bounds apply to `θ_j − θ_k − (va_nom[j] − va_nom[k])`
  in declared phase order. The same endpoint domain applies as for lines.
  Omitted `va_nom` means zero offsets; if supplied, it must have exactly one
  finite angle per phase. Source-fixed and grounded phase pairs are skipped.
- **Angle conditioning:** sine/cosine rows keep coefficients bounded near the
  supported endpoints. Exact angle targets use an `*_angle_equality` semantic
  row and an `*_angle_domain` half-plane guard, replacing opposing lower/upper
  inequalities. Interval rows retain their lower/upper keys. Their multipliers
  are for the cosine-scaled rows: multiply by the endpoint cosine to compare
  against a tangent-row multiplier at the same solution.
- **Line apparent power:** `s_max` applies at both ends, even without π-shunts.
  Equal current magnitudes alone do not imply equal apparent powers.
- **Open switches:** currents remain fixed at zero; vacuous thermal constraints
  and power auxiliaries are omitted.
- **Zero-radius limits:** use exact component equalities instead of a squared
  norm inequality with a vanishing gradient. A semantic constraint handle may
  return a vector value/dual in this case; inspect its MOI shape.
- **Ideal voltage references:** conflicting references at the same terminal,
  including a nonzero source on a perfectly grounded terminal, raise
  `ArgumentError`. Identical colocated sources can still have an undetermined
  current allocation unless other constraints or costs resolve it.
- **Voltage-dependent loads:** the artificial `0.5–1.5 × v_nom` band is removed.
  Pure-P equivalents and pure-Z laws keep their direct formulations. Remaining
  laws use W/s lifts when fixed references or enforced bounds certify positive
  coil voltage, and a dimensionless logarithmic magnitude otherwise. See the
  [runtime load formulation](../opf.md#squared-voltage-drop-variable) for supported
  domains, semantic keys, and numerical limitations.
- **Native applicability:** missing series impedance, inconsistent matrix sizes,
  nonfinite impedance, incomplete/nonfinite source references, unsupported
  source/load/generator configurations or load models, incomplete load powers,
  and n-winding tap requests raise errors. Exact zero impedance must be explicit.
  A source may omit a trailing reference already fixed to zero by grounding;
  a two-terminal DELTA load has one coil. Checks apply to native-owned device
  physics; custom builders own their domain. Magnitude domains, malformed
  transformer maps/subtypes, and unsupported neutral connections are also
  checked; see [magnitude-limit inputs](@ref opf-magnitude-domain).

- **Solver results:** a locally solved status does not certify every engineering
  limit or a global optimum. Independent residual and limit checks remain
  necessary, and their coverage is finite.

## [Formulation helpers: purpose, domain, and trade-offs](@id opf-formulation-helpers)

These are implementation contracts for this engine, with executable witnesses
linked to `PSK-000013`; they do not extend that scientific contract's scope.
Start with the physical equation and its supported domain, then choose a helper.
An exact reformulation, a redundant bound, a domain guard, and a smoothing
approximation serve different purposes:

| Role | What must be preserved or declared | Example |
|---|---|---|
| Exact reformulation | Same physical feasible set on the stated domain; recover auxiliary quantities and account for row scaling in duals | Normalized positive-radius cap, P/Q lift, sine/cosine angle rows |
| Redundant bound | Follows from constraints actually enforced for this variable | Rectangular current box implied by a current-magnitude cap |
| Domain guard | Justified by an enforced physical condition; must be revisited when that condition changes | W/s lower guards from a positive coil-voltage certificate |
| Smoothing approximation | Changes the represented function; declare its scale, approximation error, and effect on the study | `smooth_norm`, smooth droop hinges |
| Initialization | Selects a starting point; does not constrain the physical feasible set | `_magnitude_start` |

The underscore-prefixed helpers below are **private implementation details**, not
a supported downstream API. They live principally in
`ext/BMOPFOpfExt/data_utils.jl` and `load.jl`. Engine contributors should reuse
and test them; downstream authors should use the public staged/coefficient APIs
and own the algebra of custom builders. Public objective helpers are documented
in [Choosing an objective](../objectives.md), and
[`opf_piecewise_linear_expression`](@ref) in
[Smooth droop encoding](../relu_softplus_encoding.md).

### Exact limits and their return shapes

`_magnitude_limit` and `_check_square_scale` centralize static numeric domains.
Limits and expression components must already share the model's working units;
these helpers do not convert SI data or choose a physical base. Missing/+Inf
upper caps are omitted, zero is exact, and negative/NaN caps fail. Positive
scales must have representable squares and reciprocal squares. That check
prevents silent underflow/overflow in the chosen algebra; passing it is not a
conditioning guarantee. Nameplates and lower bounds have stricter domains; see
[the runtime input rules](@ref opf-magnitude-domain).

`_soc_norm!(model, a, b, limit)` stamps
`(a/limit)^2 + (b/limit)^2 ≤ 1` for a positive cap. Normalization makes an absolute
row tolerance relative to the cap, avoiding tiny unscaled squared residuals.
Despite the helper's name, this is a scalar quadratic inequality when the
components are affine; it does not select a conic solver. It returns a constraint
handle, or `nothing` for an absent cap or a zero cap whose components are all
structurally zero.

At a zero cap, `_zero_components!` uses exact component equalities. The squared
inequality would have a zero gradient at every feasible point. A single
nontrivial component produces a scalar equality; several produce a vector
equality, so callers must accept a **vector-valued dual**. Identically zero
polynomial components can be omitted; a JuMP parameter currently equal to zero
is still symbolic. Do not infer structural simplifications from today's
parameter values.

`_limit_current_box!` adds the implied component bounds only when the cap applies
to the supplied current variables themselves. If `I_total = I_series + Y_sh V`,
then `|I_total| ≤ Imax` does **not** imply `|I_series| ≤ Imax`: the shunt current
can oppose the series current. `_terminal_vmax_to_ground` and
`_line_shunt_row_bound` support a conservative shunt allowance when genuine
voltage bounds exist. They do not supply missing physical limits. The zero-cap
box is skipped because the component equalities already enforce it.

`_neutral_current_limit!` applies the cap to the sum of phase currents of a
supported star-connected device. It represents that device's neutral return,
not every current that may share a network neutral or earth path.

`_apparent_power_limit!` introduces P/Q variables and bilinear defining rows,
then applies the normalized cap to those variables. For affine V/I inputs this
avoids a quartic voltage-current inequality, at the cost of two variables and
two definitions. It returns `(p, q)` or `nothing` when skipped; optional callbacks
and a ledger preserve semantic constraint identity and reporting. The caller
must supply the intended voltage reference: terminal-to-ground for a conductor
cap, coil voltage for a winding cap. Even `Smax = 0` does not imply `I = 0` at
zero voltage. A power cap cannot replace neutral ampacity.

!!! note "Exact reformulation does not preserve raw multipliers"
    For a positive-radius squared cap, if `lambda_scaled` multiplies the
    normalized row, the multiplier on `a² + b² − limit²` is
    `lambda_scaled / limit²`, in the same working coordinates. Physical-unit
    conversion is a separate step. At zero radius the representation and dual
    shape change; there is no scalar multiplier conversion by taking that limit.
    Inspect semantic keys and constraint shapes instead of assuming each
    engineering limit always has one scalar dual.

### Angle windows and voltage-dependent loads

`_angle_window` validates **static**, two-sided, finite windows strictly inside
`(-π/2, π/2)`. `_angle_window_constraints!` uses sine/cosine coefficients instead
of tangent coefficients that diverge near those endpoints. An exact target uses
one equality and a half-plane guard to exclude the antipodal solution. The
origin remains feasible: these rows do not give zero voltage a defined angle.
Line and centered bus angle conventions differ; see the runtime limits above.

`_add_subload_power!` selects a load formulation from its structural law. Pure-Z
uses an affine current law for fixed coefficients, including zero voltage;
constant-P equivalents omit unused magnitude lifts. Remaining laws use W/s lifts
only where `_load_voltage_lower` certifies positive coil voltage from enforced
conditions. Otherwise a logarithmic variable represents positive voltage,
without inventing a physical epsilon floor. This avoids negative-base fractional
powers, but exponential trial values can still overflow or underflow.

`_magnitude_start` evaluates fixed/initialized terminal differences and uses a
positive nominal fallback at a zero or nonfinite magnitude. It initializes load
auxiliaries; it is not a general repair of infeasible/nonfinite starts and does
not certify positive voltage. The log definition is normalized by its fixed
start magnitude squared. Changing a start later does not change that scale.
The [load-domain warning](../opf.md#squared-voltage-drop-variable) explains when
changing physical bounds requires rebuilding.

### Smoothing, substitutions, and performance expectations

`smooth_norm` is a public expression helper for a declared approximation:
`sqrt(sum(c²) + epsilon²) − epsilon`. Size epsilon from a characteristic magnitude
in working units, not merely the SI conversion factor. It underestimates the
true norm, so do not use it as an exact hard cap or form ratios from shifted
norms. `opf_reduce_norm` selects different objective constructions; a `:max`
epigraph is tight only in its intended minimization use. The
[objective guide](../objectives.md) explains accuracy and scaling choices.

`opf_piecewise_linear_expression` constructs smoothed hinge expressions. Its
smoothing width is in input working units; changing it changes the represented
curve. The registered and built-in softplus modes have different numerical and
AD compatibility limits. See the [softplus warning](../relu_softplus_encoding.md)
and the [repeat-solve warning](@ref opf-parameter-resolves).

Do not assume that fewer variables, quadratic rows, or an exact substitution
makes Ipopt or MadNLP faster. Removing a lift can increase expression work or
Jacobian/Hessian fill; retaining it adds rows and unknowns. Preserving feasible
physical states also does not automatically preserve dual interpretation or KKT
regularity. Compare analytic/independent physical residuals and solution quality
first, then warmed build/solve time, iterations, and sparsity under matched solver
settings. The correctness tests are not a performance benchmark.

## Solver parity tests

`test/Project.toml` includes MadNLP alongside Ipopt; neither MadNLP nor its
compatibility requirement is added to the main package project. Run
`julia --project=test --startup-file=no test/runtests.jl` for the full suite.
`test/opf_domain_tests.jl` checks both solvers on floating-neutral loads in SI
and per-unit coordinates, inside and outside the former engineering band, and
checks the zero-radius vector-equality bridge.
`test/opf_final_hardening_tests.jl` adds magnitude/transformer rejection witnesses,
finite-difference Jacobian/Hessian checks, and parameter updates through zero
with the explicit optimizer-cache reset. These are numerical correctness
tests, not performance measurements. Solver-specific options remain separate;
see [MadNLP options](https://madsuite.org/MadNLP.jl/stable/options/).

## Extending the engine without forking it

The "not a model zoo" stance above is only tenable because the engine is
extensible from *outside*: a downstream package can add devices, swap the
objective, couple time steps, or pose an entirely different problem — reusing all
the device physics, per-unit handling, and result extraction — without a new
constraint landing in `ext/BMOPFOpfExt/`. Three seams, in increasing order of
reach (full detail under
[extending the formulation](../opf.md#extending-the-formulation)):

- **`model_hook!(ctx)` / `solution_hook!(ctx, result)`** — add custom variables,
  constraints, or objective terms to a single solve, then read their solved
  values. A hook device stamps its current with `add_terminal_injection!` and may
  register its net injection as `result["custom_injection"]` so the power-balance
  check in [`profile_solution`](../validation.md) stays honest. This is how a
  battery, EV charger, or bespoke limit is added **without touching the JSON
  spec**.
- **The staged API** ([`build_opf_model`](@ref) → [`enforce_kcl!`](@ref) →
  [`extract_result`](@ref), with [`generation_cost`](@ref) for the objective) —
  unfuses build/solve/extract so several snapshots share one JuMP model. This is
  what makes **inter-temporal** coupling (battery state of charge across a
  horizon) expressible, which the single-shot [`solve_opf`](@ref) cannot do; see
  [the staged API](../opf.md#staged-api).
- **A different problem specification entirely.** Because `build_opf_model` adds
  operational limits only where the net *declares* them, a bounds-free net yields
  a pure physics model with free voltages; with `add_objective=false` and a
  `model_hook!` objective this hosts **state estimation**, parameter estimation,
  and other model-fitting problems that are not dispatch optimisation. See
  [Beyond OPF](../opf.md#beyond-opf).

Internally the same seam is the `build!` *recipe* (`build_opf!`, `build_pf!`,
`build_feasibility!`): a fourth problem type is a fourth recipe over the
invariant `_build_and_solve` pipeline. Promoting that recipe entry point to a
public `build_custom_model` is the natural step **if** such a formulation
graduates from a downstream experiment to accepted practice — the same "fold it
back in via the spec" path the model-zoo warning describes. Until then, the
public hooks and staged API let you build it in your own package.

### Authoring a `model_hook!`

A `model_hook!(ctx)` runs **after** the standard build (`_add_device_constraints!`
has already stamped every element in the net and populated the KCL accumulators)
and **before** [`enforce_kcl!`](@ref) turns those accumulators into constraints. Two
conventions trip up first-time hook authors.

**Hooks are additive.** A hook may add current with `add_terminal_injection!`, add
variables and constraints, and set the objective. It **cannot replace** a
constraint already stamped for a network element — by the time the hook runs, that
element's Ohm's-law/KCL contribution is already in the model. There are therefore
two ways to make an element's parameter a decision variable:

- **Native free variable — preferred where it exists.** Some element parameters are
  already exposed as optional free variables when the case declares bounds. A
  transformer **tap** is the worked example: set `tap_min`/`tap_max` on the
  transformer, retrieve the effective from→to ratio with
  `opf_object(ctx, opf_transformer_tap_key(tid))`, and let the engine thread it
  through the per-unit-correct,
  base-referred winding constraints. The hook just *reads* (and, across a staged
  multi-snapshot build, *couples*) the handle — the engine keeps ownership of
  per-unit, limits, and native loss/flow bookkeeping.

- **Use a coefficient provider, or omit-and-re-stamp when no native location
  exists.** Native scalar line `R_series`/`X_series` matrix entries can now be
  supplied by typed coefficient providers without replacing the branch. If the
  quantity has no provider-aware native location (for example a line's length),
  **omit that element from the net** and re-stamp its constraint in the hook with
  your own variable, injecting its current into the KCL accumulators. The caveats
  are the flip side of the above: for that element *you* now own the per-unit
  scaling (`opf_bases(ctx)`), any current/power limit, and native loss/flow bookkeeping —
  none of it is applied for an element the engine never saw.

**Terminal injections are positive _into_ the terminal.** `enforce_kcl!` sets
the sum at each `(bus, terminal)` to zero. So a series element from
bus `f` to bus `g` carrying current `I = cr + j·ci` in the `f → g` direction
**subtracts** at its from-terminal (current leaves `f`) and **adds** at its
to-terminal (current enters `g`):

```julia
# series element f → g on conductor c, current I = cr + j·ci
add_terminal_injection!(ctx, f, c, -cr, -ci)
add_terminal_injection!(ctx, g, c,  cr,  ci)
```

A shunt or user injection `I` into `(bus, phase)`, referenced to the bus neutral,
adds at the phase terminal and subtracts the return at the neutral:

```julia
add_terminal_injection!(ctx, bus, phase,    cr,  ci)
add_terminal_injection!(ctx, bus, neutral, -cr, -ci)
```

The native flow/loss ledger uses the same "into bus" sign, so an element's complex loss is
`S_loss = −Σ V·conj(I_into_bus)`. In per-unit mode (`per_unit=true`, the default)
the accumulator currents are per-unit; a SI current/voltage literal in a hook must
be scaled by the matching `opf_bases(ctx)` base.

## Keep it behind the extension boundary

!!! warning "The OPF engine may be carved out into its own package"
    The reference optimizer may eventually be extracted into a separate package,
    leaving BMOPFTools focused on the data model, conversion, analysis, and
    profiling. To keep that option open:

    - Keep the engine behind the existing extension boundary — it lives in
      `ext/BMOPFOpfExt/`, with `JuMP` and `Ipopt` as weak dependencies (see the
      `[weakdeps]` / `[extensions]` blocks in `Project.toml`).
    - **Do not couple core analysis to the engine.** Parsing, validation,
      analysis, reporting, conversion, and augmentation must all work without
      JuMP/Ipopt loaded. Anything that needs the solver belongs in the extension,
      not in `src/`.

## See also

- [Optimal power flow](../opf.md) — running the engine and the formulation.
- [Parameterized and differentiable extensions](../differentiable_extensions.md) —
  the stable downstream-extension contract, scientific scope, native coverage,
  and known limitations.
- [OPF result dictionary](../results.md) — the result-dict shape (part of the
  public API; see [Versioning](versioning.md)).
- [Validating the OPF](../validation.md) and
  [Bounds & feasibility](../bounds/index.md) — the correctness machinery.
