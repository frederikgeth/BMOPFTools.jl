# OPF engine: scope & status

BMOPFTools ships **one reference optimizer**: a nonconvex **four-wire rectangular
current–voltage (IVR-EN)** optimal power flow engine, in a package extension that
activates when JuMP and Ipopt are loaded. It is not a general OPF framework, and
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

- The IVR-EN formulation is fully derived in `docs/math-model.tex`.
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
  transformer windings) are represented with **impedance** `R + jX`, not
  admittance `G + jB`. The reason is the lossless limit: as `R → 0` the impedance
  form stays finite, whereas an admittance form blows up (`G → ∞`) for a lossless
  branch. Keeping series elements in impedance form **preserves the capability to
  build lossless models**. Shunts and the transformer no-load branch are
  naturally admittances (a lossless shunt is pure `B`, with no blow-up) and stay
  in `G + jB` form — there is no tension there.
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

The impedance-over-admittance choice has a sharp practical corollary for
near-zero branches (jumpers, bus ties, idealised regulators, placeholder
transformer leakage). The temptation is to model "approximately zero" impedance
as a small number `ε`. That is the **worst** option on the whole axis:

![Numerical conditioning of a branch as a function of its impedance magnitude: an exact zero is well-conditioned, the physical range is well-conditioned, but the small-but-nonzero placeholder region in between has a condition number that grows like 1/|Z|.](../assets/impedance_conditioning.svg)

- **`Z = 0` exactly** is well-conditioned — the engine handles it *semantically*,
  by merging the nodes / imposing the ideal-transformer constraint
  `V_fr = N·V_to`, rather than inverting a near-singular admittance.
- The **physical range** (real conductors and transformers) is well-conditioned.
- The **gap between them** is the only ill-conditioned region on the axis. A
  small `ε` placeholder lands you exactly there, where the condition number grows
  like `1/|Z|` and the solver's effective tolerance floor rises with it.

So `lim_{Z→0⁺} κ = ∞` while `κ(0) = O(1)`: approximating a true zero by a small
value moves it *away* from the well-conditioned point, not toward the physical
range. In pure admittance form this is unavoidable — `Y = 1/Z → ∞` at `Z = 0` —
which is the same reason series elements are kept in impedance form. **The remedy
is semantic, not numerical:** represent the branch as zero and switch
formulation. BMOPFTools' [`fix_case`](../augmentation.md#fix) does exactly this —
collapsing low-impedance lines to switches (pass 4) and snapping placeholder
transformer leakage to exact zero (pass 9) — and the
[zero-voltage / ill-conditioning traps](../bounds/known_traps.md) page catalogues
what happens when this is gotten wrong.

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
- [OPF result dictionary](../results.md) — the result-dict shape (part of the
  public API; see [Versioning](versioning.md)).
- [Validating the OPF](../validation.md) and
  [Bounds & feasibility](../bounds/index.md) — the correctness machinery.
