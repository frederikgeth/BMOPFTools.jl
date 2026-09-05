# Scientific review of the reference IVR engine

Review date: 2026-09-05. Scope: `ext/BMOPFOpfExt`, its tests and runtime
documentation. Core package analysis and book-owned scientific claims are outside
the change scope. This is a targeted implementation review, not a proof of every
transformer, converter, or nonlinear objective. The executable evidence is linked
to **PSK-000013** through `knowledge/executable.toml`; the existing contract's
unassessed dimensions remain unassessed. In particular, a solver status is not an
independent feasibility certificate.

## Defects fixed in this branch

| Priority | Defect and witness | Correction |
|---|---|---|
| P1 | A shunt-free line omitted its to-end `s_max`. With `V_f=1`, `V_t=2`, `R=1`, the series current is `-1`; apparent powers are 1 and 2. A cap of 1.5 was accepted in one orientation and rejected in the other. | Stamp both power limits, including without shunts. |
| P1 | Branch angle cross product encoded `θ_to−θ_from`, whereas the documented/PMD convention is `θ_from−θ_to`. Symmetric windows masked the error. | Correct the sign; test positive and negative asymmetric windows and their boundaries. |
| P1 | One-sided or zero-width tangent bounds admitted the opposite half-plane; out-of-range endpoints were passed through `tan`. | Enforce the right half-plane for equal bounds; reject one-sided windows rather than inventing the missing bound, and reject unordered/nonfinite/out-of-domain endpoints. |
| P1 | `fix(...; force=true)` silently replaced an existing source or physical ground reference. A one-bus model with sources of magnitudes 1 and 2 built successfully and retained 1 in the observed dictionary order. | Reject inconsistent references before overwriting; permit phasor-roundoff differences such as angles 0 and 2π. |
| P2 | An X-only two-conductor linecode created a 1×1 R matrix and reported one conductor. | Infer the missing R matrix dimension from X, consistent with inline impedances. |
| P2 | An open switch with `i_max` threw a JuMP assertion when bounds were added to its fixed current. | Keep zero currents fixed and omit vacuous current/power limits and auxiliaries. |

`test/opf_engine_review_tests.jl` contains minimized witnesses. Before the initial
line/linecode/switch corrections, its initial version produced 12 failed assertions and one
build error. Tests evaluate angle rows at independently constructed complex
phasors, reverse branch orientation, exercise SI and per-unit solves, and pass
the power-limit case through JSON serialization. Later tests cover source
reference conflicts and numerical helper behavior.

The additional half-plane row is deliberately omitted for a strict two-sided
angle interval: its two inequalities already imply a nonnegative dot product.
Zero voltage still has no angle; an angle constraint must not synthesize a
missing voltage lower bound.

## Numerical helper added

`_zero_components!` implements exact zero-radius norm limits as component
equalities. `_soc_norm!` now calls it when the declared radius is exactly zero.
The old squared inequality has zero gradient at its only feasible point, violating
the usual regularity assumptions needed for reliable NLP steps and sensitivities.
For affine current or sequence-voltage components, the replacement has constant
Jacobian rows. This improves the local constraint representation; it cannot cure
dependencies elsewhere in the network.

The helper drops only literal or identically zero polynomial components, never a
small coefficient or a parameter whose current value happens to be zero. A scalar
component returns a scalar equality; two components return one vector equality
handle. A zero-radius constraint's value and dual can therefore be vectors under
the existing semantic key. Downstream code must inspect its MOI set/shape instead
of assuming every thermal handle is a scalar inequality. Completely zero
expressions produce no constraint. The optimization profile counts the vector's
scalar equations. Redundant zero-width current boxes are omitted.

## Device substitution follow-up

The next development slice corrects two-terminal `SINGLE_PHASE` generator
allocation, constraints, pricing, and result extraction together. One coil now
uses the two listed endpoints, including reversed phase-to-phase maps. Both
conductor ratings bound its single current. It also fixes a separately discovered
DELTA generator objective bug: cost used phase-to-ground voltage while constraints
and result powers used line-to-line voltage. An unbalanced three-coil test with
unequal costs checks the objective against the independent sum of coil powers.

Pure-Z loads now retain their public current variables but stamp the admittance
current law directly, removing one W auxiliary and one net equality per sub-load.
This avoids cancellation of voltage in a power equation at the zero-voltage
boundary. Pure-Z ZIP/exponential forms receive the same treatment. Constant-P
equivalents omit the unused W/s variables and the artificial voltage band. Their
current/power semantics and units are explicitly represented by separate registry
families. Fixed nominal powers yield affine Z laws; mutable providers remain
symbolic and can be updated through zero without rebuilding.

`_magnitude_start` now seeds remaining load W/s variables from fixed or initialized
terminal voltages, with a nominal fallback and clamping to their existing domain.
General fractional/current/mixed-load domain cleanup remains separate. The new
`test/opf_device_substitution_tests.jl` exercises SI/per-unit coordinates,
serialization, analytic currents/powers/cost, zero voltage for pure Z, conductor
limit rejection, and updates of nominal-power parameters through zero.

## Remaining correctness work

These issues are **not fixed** by this branch and should precede a broad
substitution/presolve pass.

1. **P1 — remaining load-voltage domain.** Mixed ZIP, constant-current, and
   general exponential models still impose `0.5 Vnom ≤ |ΔV| ≤ 1.5 Vnom`.
   Constant-P equivalents and pure-Z models have been corrected. Separate declared
   physical/domain bounds from numerical initialization for the remaining cases.
   For fractional or negative exponents, explicitly specify supported zero-voltage
   behavior instead of imposing the same engineering band everywhere.
2. **P1 — independent limit coverage has matching blind spots.**
   `src/validation/solution.jl` checks line current and apparent power at the from
   end, and its angle check covers intra-bus angles. It does not independently
   check receiving-end line limits or branch angle bounds. Fixing the engine does
   not make that external verification complete. Track this separately in the
   main package using stable Finding codes and conductor endpoint mappings.
3. **P2 — bus-angle domain.** The centered bus-angle encoding still lacks the
   explicit half-plane guard for one-sided/equal bounds and build-time endpoint
   checks now present for lines. Nominal centering does not itself impose that
   domain. Reuse a common angle-window helper once bus and line conventions are
   represented explicitly; add antipodal and zero-voltage tests.
4. **P2 — invalid or unsupported elements can be skipped.** Missing line
   impedance skips line stamping; unsupported source configurations omit source
   current injection; n-winding tap fields warn and use nominal ratios. Define a
   strict engine applicability check that rejects unsupported requested physics
   before building a plausible partial model. Validate matching terminal counts,
   finite coefficients, rating domains, and source-reference completeness there.
5. **P2 — ideal topology is not fully guarded.** The current check detects direct
   parallel zero-impedance conductors, not ideal cycles, self-loops, or general
   dependent ideal-transformer relations. Its check runs before coefficient
   providers replace impedances, so static nominal topology alone cannot justify
   rejecting or eliminating a parameterized branch. Distinguish inconsistent
   reference equations, dependent rows, and unidentifiable circulating currents.

## More in-place substitutions

Use an explicit substitution record containing original semantic keys, expression
recovery, supported parameter domain, and any dual/sensitivity limitations.
Preserve terminal labels and four-wire ground return accounting. Test against the
unreduced model; fewer variables alone is not evidence of a better NLP.

| Candidate | Exact domain and guard | Expected structural effect |
|---|---|---|
| Constant-Z loads, ZIP Z terms, exponential exponent 2 | Fixed nominal voltage and coefficients; stamp `I=conj(Snom) ΔV/Vnom²`. Preserve total device-current limits and result recovery. Resolve the hidden voltage domain first. | Pure Z becomes affine; can remove two current variables, two power equations, and the W auxiliary/definition per branch. Mixed ZIP can substitute only its Z current. |
| Constant-P-equivalent ZIP/exponential | Both components have no remaining W or magnitude dependence. Coefficient-provider structure must guarantee that under updates. | Avoid unused W/s auxiliaries and artificial bounds. |
| Ground-injection current | One unconstrained earth-current pair whose sole equation is terminal KCL; preserve hooks that consume it. | Recover `I_ground = -Σ I_other` and remove its pair of variables/equations, rather than forgetting ground return. |
| Fixed-ratio transformer current coupling | Ratio is fixed and nonzero in the relevant side-local bases; retain shunt and neutral expressions. | Replace one winding-current pair by an affine expression. A variable tap would make the substitution nonlinear in KCL and may be worse. |
| Ideal switch/tree voltages | Exact zero impedance with independent, consistent voltage relations; preserve individual currents/ratings and output labels. | Alias voltages; retain current variables when branch flows remain identifiable. Do not discard circulating-current degrees of freedom by arbitrarily choosing their values. |
| Exact equal lower/upper limits | Equality is structural, not merely two parameter values equal at today's update. | One equality instead of opposing inequalities; supply a dual convention and retain an unreduced path for sensitivity clients. |
| Zero shunt rows | Every row coefficient is identically zero; no provider can introduce a nonzero entry. | Skip duplicate to-end current cones per conductor. Never use this to skip the to-end apparent-power cap. |

Do not generically replace zero P/Q equations by zero current at a bus that can
have zero voltage: `S=V conj(I)=0` does not algebraically imply `I=0` there. Likewise,
avoid dividing constant-power currents by `|V|²` without an enforced nonzero
voltage domain. Affine substitution is generally a safer starting point than
introducing rational expressions.

## Other stability helpers worth adding

- **`set_consistent_magnitude_starts!`**: initialize load `W` and `s`, and lifted
  power auxiliaries, from the final transported voltage/current starts. Use a
  declared positive fallback for fractional powers when the physical start is
  zero; record it as initialization, not a hard bound. Load W/s starts are now
  implemented by `_magnitude_start`; lifted power starts remain follow-up work.
- **`scale_residual_block!`**: choose positive, fixed physical scales for voltage
  drop, current balance, power, and control equations; retain the inverse map for
  duals and SI residual reports. Existing `OpfScaling` and semantic residual
  blocks are the right integration points. Scale a block by declared bases or
  engineering references rather than dividing by its current residual or a
  potentially zero rating. Never hide a bad physical residual through normalization.
- **`check_ideal_constraint_rank`**: start with conductor-level cycle/reference
  consistency and sparse structural rank; use numeric rank only with declared
  scaling/tolerance. Report non-identifiability rather than injecting epsilon
  impedances. Diagnose all current/voltage relations after supported coefficient
  providers are resolved.
- **`validate_nlp_start`**: evaluate all rows at the proposed start and report
  nonfinite functions/derivatives, bound violations, undefined fractional powers,
  and contradictory fixed references with semantic keys. Include overflow checks
  for the explicitly selected `softplus=:builtin` path: unlike the default stable
  operator, it constructs `log1p(exp(z))`, which can overflow for large positive z. It should identify the
  first failing device instead of relying on a generic solver evaluation error.

## Performance and coverage assessment

The engine already uses a sensible sparse IVR structure: one series current per
line, affine π-shunt currents, finite impedance equations at exact zero, topology
aware voltage starts, normalized positive-radius thermal limits, current boxes,
and quadratic lifts of apparent power. Preserve these strengths.

Do not assume that removing every lift improves performance. JuMP does not
automatically eliminate common nonlinear subexpressions; an explicit auxiliary
and equality can avoid repeated derivative work. Conversely, a small expression
may be cheaper without the lift. Compare derivative cost and KKT fill, not only
model size. See the [JuMP nonlinear modeling documentation](https://jump.dev/JuMP.jl/stable/manual/nonlinear/).

Ipopt and MadNLP both expose fixed-variable treatment. Let that treatment handle
ordinary fixed variables unless an engine substitution gives a measured benefit
and preserves downstream recovery. Avoid adding redundant equalities to variables
the solver already removes. Solver scaling, fixed-variable policy, linear solver,
and stopping tolerances must be recorded with results; a shared option dictionary
is not portable across both solvers. See [Ipopt options](https://coin-or.github.io/Ipopt/OPTIONS.html)
and [MadNLP options](https://madnlp.github.io/MadNLP.jl/dev/options/).

No speedup is claimed here. MadNLP is absent from the local test environment and
from the dedicated CI matrix. Add an isolated MadNLP environment/job before
claiming numerical parity, including vector equality bridging from zero-radius
limits. Benchmark warm builds separately from first-call compilation, with repeated
solves, fixed starting points, objective/dispatch checks, SI residuals, Jacobian
and Hessian nonzeros, iterations, factorization time/fill, and peak memory. Include
radial and meshed four-wire cases, weak networks, floating neutrals, transformer
chains, free taps, reverse flow, active/zero limits, and several per-unit bases.

Coverage is broad but **not sufficient to establish substitution safety**. Existing
analytic cases, OpenDSS comparisons, PMD OPF bounds, scaling tests, semantic-block
tests, DiffOpt integration, and downstream extension tests are valuable. The new
counterexamples show why successful solves and symmetric nominal cases leave
gaps. Add metamorphic comparisons for branch reversal, terminal permutation,
model-equivalent ZIP/exponential encodings, optional-zero versus absent data,
parameter updates through zero, and reduced-versus-unreduced primal recovery.
Use derivative checks away from nonsmooth regime boundaries, and explicitly test
rank-deficient/zero-voltage boundaries where a smooth sensitivity is unsupported.

The optimization profile's `n_variables - n_equalities` is only a row-count
heuristic, not a Jacobian-rank calculation. Its multiplier thresholds do not prove
LICQ, second-order sufficiency, uniqueness, or strict complementarity independent
of scaling. Document these as diagnostics, not scientific certificates.
