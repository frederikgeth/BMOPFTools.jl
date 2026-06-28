# Contributing & workflow

BMOPFTools is a community-driven initiative to **support** the IEEE PES Task
Force on *Benchmarking Multiconductor OPF for Distribution Systems*. The Task
Force — not BMOPFTools — owns and manages the JSON data model and the official
benchmark data releases; this repository provides the tooling around them and a
home for *draft* benchmarks. Contributions of all kinds are welcome — draft
cases, tooling, documentation, and feedback on the data model itself.

This page is the entry point for contributors. The rest of the Developer guide
goes deeper on the conventions and guard-rails:

- [Style guide](style_guide.md) — Julia style plus the project-specific
  invariants, split into what CI enforces, what we follow, and where we are
  still heading.
- [Versioning & the data model](versioning.md) — the two version axes (package
  SemVer and the BMOPF spec version), the migration requirement, and how
  data-model changes go through the Task Force.
- [OPF engine: scope & status](opf_engine.md) — the correctness bar for the
  reference optimizer and the modeling preferences for new constraints.
- [Profiling pipeline: priorities](profiling.md) — what makes a good new finding
  and what is currently out of scope.

## Ways to contribute

| Kind | Where it goes | What review looks at |
|---|---|---|
| **Bug reports & questions** | Issue tracker | A minimal reproducer; for conversion bugs, the source `.dss` snippet. |
| **New network cases (draft)** | PR (see below) | CC BY 4.0 licence; conversion sanity. Perfection not required. |
| **Tooling / analysis** | PR | Tests, docstrings, finding-code catalogue, coverage. |
| **Documentation & tutorials** | PR | Accuracy, and **non-overlap** with existing tutorials. |
| **Data-model feedback** | `docs/taskforce_feedback.md` → Task Force | Goes through the TF process, not merged unilaterally — see [Versioning](versioning.md). |

## Contributing a network case

### Draft benchmarks vs. official benchmarks

There are two tiers of benchmark, and they are governed differently:

- **Draft benchmarks** can be hosted *here*. They **do not need to be perfect** —
  the key requirement is that the data is licensed **CC BY 4.0** (and that you
  have the right to release it that way). A draft case is a useful contribution
  even with open warnings or rough edges.
- **Official benchmarks** fall under **Task Force governance**. Adding a case to
  this repository does **not** mean the Task Force will adopt it as an official
  benchmark — that is a separate process the Task Force navigates and decides.

So: contribute drafts freely; don't assume a draft becomes official.

### Adding a draft case

1. **Convert** your source with [`from_dss`](../conversion.md) (OpenDSS in,
   BMOPF `Dict` out).
2. **Sanity-check** with [`analyze`](../analysis.md): read the findings and make
   sure nothing is badly wrong. Aim to clear `E.` (error) findings, but a draft
   with understood warnings is still welcome — read the
   [finding-code reference](../findings.md).
3. **Cross-check** against OpenDSS where you can: the test suite runs a relaxed
   power-flow comparison against OpenDSSDirect when it is installed. A case that
   matches the source deck's power flow is more trustworthy than one that only
   parses — and helps when the Task Force later assesses it.
4. **Prepare** the case if it is destined to be an OPF benchmark — see
   [case augmentation](../augmentation.md) (`fix_case` → `add_generators` →
   `augment_case`), which records every change in a `TransformationManifest`.
5. **Open a PR**, and confirm the licence in the case header.

!!! note "Official benchmark data is the Task Force's, and will live elsewhere"
    The Task Force owns the official benchmark releases. The accepted cases under
    `/output` and the source decks under `/test/data` are expected to be carved
    out into a separate, versioned, Task-Force-governed repository so they can be
    released and cited independently of the tooling. Draft cases can be hosted
    here in the meantime.

## Contributing tooling or analysis

A pull request that adds an analysis pass, a conversion fix, or an OPF feature
should include:

- **Tests** under `test/` (add the file to `test/runtests.jl`).
- **A docstring** on every exported symbol — CI fails otherwise
  (`checkdocs = :exports`).
- **A `findings.md` row** if you introduce a new finding code, with its trigger
  and rationale. Finding codes are a stable, matched-on API; see the
  [style guide](style_guide.md).
- **No drop in coverage** — Codecov reports on every PR.

See the [style guide](style_guide.md) for the full set of conventions.

## Contributing a tutorial

Tutorials are welcome contributions. The one rule: **a new tutorial must not
substantially overlap an existing one.** The current tutorials are

- [End-to-end tutorial](../tutorial_end_to_end.md) — load → analyze → fix →
  place DERs → augment → solve,
- [DER placement tutorial](../tutorial_ders.md),
- [VVWO tutorial](../tutorial_vvwo.md),
- [SWER case study](../tutorial_swer.md).

Litmus test: a tutorial earns its own page only if it teaches a workflow or
feature that none of the above already walks through. If your idea overlaps an
existing tutorial, propose **merging** your material into that page rather than
adding a parallel one. When two pages drift into heavy overlap, we will consider
merging them.

## Local development loop

From the package root:

```sh
# full test suite (power-flow comparison tests are skipped when OpenDSSDirect is absent)
julia --project=. -e "using Pkg; Pkg.test()"

# generate analysis reports and simplified variants for all output/ networks
julia --project=. scripts/generate_output.jl
```

The OPF / benchmark scripts carry `JuMP` + `Ipopt` in their own environment;
instantiate it once:

```sh
julia --project=scripts -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=scripts scripts/run_benchmark.jl            # all stages
julia --project=scripts scripts/run_benchmark.jl opf        # or: outputs / solutions
```

Build the documentation locally:

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
# open docs/build/index.html
```

One-off data-migration scripts live in `scripts/oneoff/`.

## Licensing of contributions

The repository carries a **dual licence** (see `LICENSE.md` and the README):

- **Code** — BSD-3-Clause.
- **Benchmark cases and Task Force outputs** (`/output`, `/test/data`,
  `docs/taskforce_feedback.md`) — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  Some cases are restricted to non-commercial use (the `MV` and `LV` cases).

By contributing **data** you agree to release it under CC BY 4.0; cite the
original source in the case header. By contributing **code** you agree to the
BSD-3-Clause licence.
