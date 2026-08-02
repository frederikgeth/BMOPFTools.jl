# Versioning & the data model

BMOPFTools has **two independent version axes**, and keeping them separate is
the single most important thing to understand before making a change that could
break a downstream user or an existing case file:

1. The **package version** — the Julia package SemVer in `Project.toml`
   (currently `0.1.0`). Governs the *code* API.
2. The **data-model (spec) version** — the BMOPF JSON schema version, tracked in
   `meta.$schema` and migrated by [`BMOPFTools.migrate`](../api.md). Governs the *data*.

A change can touch one, the other, or both. They are released on different
cadences and have different compatibility promises.

## Package SemVer

The package follows [semantic versioning](https://semver.org/) under the
[ColPrac](https://github.com/SciML/ColPrac) pre-1.0 conventions.

While the package is `0.x` (pre-1.0):

- **Breaking changes bump the minor** — `0.y.z` → `0.(y+1).0`.
- **New features and fixes bump the patch** — `0.y.z` → `0.y.(z+1)`.

Breaking changes currently land directly on `main` during rapid development, so
**pin a revision when you need reproducibility**:

```julia
Pkg.add(url = "https://github.com/frederikgeth/BMOPFTools.jl", rev = "<commit-sha>")
```

### What counts as a breaking change

The public API is larger than just the exported functions. A change to any of
these is breaking and must bump the minor version:

- **Exported symbols** — signatures, removed/renamed exports.
- **Finding codes** — renaming or removing a code, or changing a code's
  *semantics* (what triggers it). Adding a new code is additive, not breaking,
  but still needs a [`findings.md`](../findings.md) row.

Some documented functions are deliberately **not exported** and must be called
qualified (`BMOPFTools.migrate`, `BMOPFTools.render_markdown`,
`BMOPFTools.render_terminal`, `BMOPFTools.voltage_zone_summary`): their
*behaviour* follows the same stability rules, but their *names* are not part of
the export surface and may move with a documented deprecation rather than a
breaking bump.
- **Result-dict shape** — the structure of the dict returned by
  [`solve_opf`](../opf.md) / consumed by [`profile_solution`](../results.md).
- **Report shape** — the fields of `Finding`, `SummaryReport`, `SolutionReport`.
- **Documented OPF extension records and provenance schemas** — semantic key,
  build-manifest, parameter-binding, differentiability-report and KKT-diagnostic
  fields are research-facing API. While the package remains pre-1.0 they may
  evolve on a minor release; provenance records carry an explicit `/vN` schema
  identifier and consumers must reject or migrate unknown versions.

## Data-model (spec) version

The BMOPF data model is versioned independently of the package. A case file
declares its spec version in `meta.$schema`, and BMOPFTools migrates it forward
on read so that **all downstream code — analysis, OPF, augmentation — only ever
sees a current-spec dict.**

The machinery lives in `src/io/migrate.jl`:

- `_SPEC_VERSIONS` maps each canonical `meta.$schema` URI to an internal version
  tag symbol.
- `_CURRENT_SPEC` is the tag this build targets (currently `:draft`).
- [`parse_bmopf`](../api.md) calls [`BMOPFTools.migrate`](../api.md) automatically; you can
  also call `BMOPFTools.migrate` directly on an already-parsed dict.
- Each upgrade appends a `W.MIGRATE.UPGRADED` note to `_meta` so the
  transformation is auditable.

### What the spec does *not* track: derived reductions

Not everything a case dict can carry is part of the versioned spec. Keys with a
leading underscore — notably `_simplification_log` and the per-line
`_merged_from` written by the [simplification passes](../tutorial_simplify.md) —
are **package-level provenance conventions, not schema fields**. They are not
validated, not migrated, and carry no compatibility promise.

This has a consequence worth stating plainly, because the data model is meant for
**exchanging benchmark cases**: a network that has been run through
`simplify_network` (merged corridors, pruned stubs, collapsed switches) is a
*lossy, derived compile target*, and the fact that it was reduced — let alone how
to undo it — is **not recorded at the spec level**. A downstream tool that reads
a simplified case sees only the reduced topology, with no schema signal that
intermediate buses, per-segment impedances, or shunt-bearing stubs were removed.

The guidance follows directly: **exchange the source case and simplify at solve
time** (as [`fix_case`](@ref) does), rather than distributing the reduced form as
the artefact of record. The design rationale — keep the fuller representation
canonical, treat the dense form as derived — is in
[Object identity: derived reductions](../semantic_modeling.md#derived-reductions).
Making the dense compiled form a first-class, spec-tracked companion to the full
model (so both travel together) is a candidate for a future schema revision.

### Adding a new spec version

When the data model advances, add a migration step (recipe mirrored from the
header of `src/io/migrate.jl`):

1. Bundle the new schema under `src/validation/schemas/<tag>.json`.
2. Add an entry to `_SPEC_VERSIONS` mapping the canonical `$schema` URI to a new
   version-tag symbol (chronological order).
3. Write a `_migrate_<old>_to_<new>(net) -> net` function.
4. Add that step to the chain in `migrate`.

### The migration-path requirement

**Every data-model change must ship a migration step.** Old case files must keep
parsing — there are no flag-day breaks. In practice this means legacy forms are
accepted as shorthand and migrated forward. Two concrete examples already in the
codebase:

- `single_phase` / `center_tap` transformers accept legacy lumped-impedance
  shorthand and expand it to the per-winding form;
- `wye_delta` / `delta_wye` accept the legacy single `r_series`/`x_series` and
  map it onto `r_series_from`/`x_series_from`.

See items 20–21 of the [Task Force feedback](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/docs/taskforce_feedback.md)
for the modelling background.

### Data-model changes go through the Task Force

The BMOPF data model is **owned by the IEEE PES Task Force**, not by this
repository. BMOPFTools *tracks* the spec; it does not unilaterally extend it.

So a proposed model change follows this path:

1. **Propose** it through `docs/taskforce_feedback.md` and the Task Force
   process. That document is the implementation-feedback channel into the spec.
2. Once the Task Force accepts it into the spec, **implement** it here behind a
   migration step (above).

The only locally sanctioned additions are **informal extension fields** prefixed
with `_` (e.g. `_meta`, `_pmd`, `_slack`). These are tolerated, never reported
as schema violations, and are the right home for converter passthrough or
provisional fields that have not yet been blessed by the Task Force. Anything
that should be portable across compliant tools belongs in the spec, not in an
extension field.

## Other guard-rails tied to releases

- **Coverage must not decrease.** Codecov gates every PR
  (`.github/workflows/ci.yml`).
- **Compat floor: Julia ≥ 1.10 (LTS).** CI runs both the LTS and the latest
  stable (`lts` + `1`); the `[compat]` floor in `Project.toml` is the contract.
