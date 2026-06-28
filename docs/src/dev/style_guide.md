# Style guide

This page describes how BMOPFTools code is written. To keep it honest, it is
split into **three tiers**:

1. **Enforced** — CI fails if you break it.
2. **Conventions we follow** — how the code is written today; match it.
3. **Preferred direction** — where we want new code to go; not yet universal, so
   stated as intent rather than as a description of the whole codebase.

When in doubt, read the surrounding code and match its idiom.

## Julia style

Follow [ColPrac](https://github.com/SciML/ColPrac) and the Blue/Julia base
conventions:

- 4-space indentation, no tabs.
- `snake_case` for functions and variables, `CamelCase` for types.
- Roughly 92-column soft wrap; match the existing source.
- Internal helpers are prefixed `_` (e.g. `_migrate_draft_to_…`,
  `_lookup_ampacity`).

## Tier 1 — Enforced (CI fails otherwise)

These are checked on every pull request. Treat them as hard requirements, not
guidelines.

- **Exported symbols need docstrings.** `docs/make.jl` sets
  `checkdocs = :exports`, so every exported name must carry a docstring or the
  docs build (and CI) fails. Adding an `export` is therefore also a
  documentation task — and an API-surface change (see
  [Versioning](versioning.md)).
- **Coverage must not decrease.** Codecov runs on every PR
  (`.github/workflows/ci.yml`). New code needs tests; a coverage drop will be
  flagged.
- **Must pass on Julia `lts` and `1`.** The CI matrix runs the declared LTS
  (the compat floor, currently Julia 1.10) and the latest stable. Do not use
  syntax or stdlib APIs newer than the floor.
- **Finding codes are a stable API.** Consumers match on `f.code`, never on
  message text. A new code needs a row in the
  [finding-code reference](../findings.md) with its trigger and rationale, and
  the correct severity prefix (`E.` error, `W.` warning, `I.` info). Renaming or
  removing a code is a **breaking change** — see [Versioning](versioning.md).

## Tier 2 — Conventions we follow

These describe how the code is actually written. New code should match them.

- **No wrapper types over the network.** The network is a plain
  `Dict{String,Any}` that mirrors the BMOPF JSON exactly (see
  [the design rationale](../index.md#Design)). Data flows to and from JSON, and
  out to PowerModelsDistribution via [`to_pmd`](../conversion.md), with no
  conversion layer. The only structs in the library are:
  - **outputs** — `Finding`, `SummaryReport`, `SolutionReport` (stable shape for
    rendering and programmatic use);
  - **config recipes** — `AugmentationRecipe`, `FixRecipe`, `IBRRecipe`,
    `GeneratorRecipe` (keyword-constructed options);
  - the `TransformationManifest` audit types.

  None of these wrap network data. Do not introduce a struct that does.
- **SI units everywhere.** All physical quantities are SI
  ([conventions, Table 8](../conventions.md#Units)) — V, A, m, W/var/VA, Ω, S,
  rad. Never introduce per-unit, kV, or kW at the data-model boundary.
- **Impedance for series elements.** Lines and transformers are modeled with
  impedance `R + jX`, so the lossless limit stays expressible. Shunts and the
  transformer no-load branch are naturally admittance `G + jB` (a lossless shunt
  is pure `B`, with no blow-up), and stay that way. The rationale is in the
  [OPF engine page](opf_engine.md).
- **Thermal/branch ratings are current.** Line and branch limits are current
  magnitude limits (`i_max`), not apparent-power limits; `augment_case` infers
  `i_max` from conductor ampacity. (Injection limits are a separate story — see
  Tier 3.)
- **Every transformation is auditable.** Anything that mutates a network records
  what it did: `fix_case` and `augment_case` return a `TransformationManifest`,
  and `migrate` appends `W.MIGRATE.UPGRADED` notes to `_meta`. A new
  transformation must leave the same kind of trail; never mutate silently.
- **Terminology discipline.** Prefer the canonical component term. The recent
  `inverter` → `ibr` (inverter-based resource) rename is the worked example: the
  *component* is `ibr`, but the physical adjective ("inverter-interfaced") and
  the data-model field `inverter_topology` keep the hardware term where it is
  physically correct. Rename components consistently; leave physics nouns alone.

## Tier 3 — Preferred direction

This is where we want new code to go. It is **not** a description of the whole
codebase — call it out as intent, and do not retrofit claims that the codebase
already does this everywhere.

- **Current limits over power limits, for device injections.** Thermal/branch
  ratings are already current-based (Tier 2). Device *injection* limits, however,
  are still mostly power-based (`p_max` / `q_max` / `s_max`), with the IBR
  current limit `i_max` an optional add-on. A current bound stays linear or
  quadratic in the rectangular IVR variables and avoids bilinear power
  expressions, so **new injection constraints should prefer a current form where
  practical.** Existing power-based limits are not a bug to be rewritten en
  masse.
- **Doc examples should be runnable.** Only the two end-to-end tutorials
  (`tutorial_end_to_end.md`, `tutorial_swer.md`) use executed `@example` / `@repl`
  blocks today; most pages use plain, non-executed ` ```julia ` fences. The rule
  is: **if you add an `@example`, keep it runnable** (the docs build executes it).
  Do not claim every code block in the docs executes — most do not.

## See also

- [Data model conventions](../conventions.md) — the authoritative reference for
  units, identifiers, and field shapes; the style guide does not duplicate it.
- [Versioning & the data model](versioning.md) — what counts as a breaking
  change and how data-model changes are governed.
