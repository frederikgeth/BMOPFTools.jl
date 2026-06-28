# Contributing to BMOPFTools.jl

BMOPFTools is a community-driven initiative to **support** the IEEE PES Task
Force on *Benchmarking Multiconductor OPF for Distribution Systems*. The Task
Force — not BMOPFTools — owns and manages the JSON data model and the official
benchmark releases; this repository provides the tooling and hosts *draft*
benchmarks. Contributions of all kinds are welcome.

**The full contributor documentation lives in the Developer guide:**

- [Contributing & workflow](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/contributing/)
- [Style guide](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/style_guide/)
- [Versioning & the data model](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/versioning/)
- [OPF engine: scope & status](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/opf_engine/)
- [Profiling pipeline: priorities](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/profiling/)

(Or build the docs locally: `julia --project=docs docs/make.jl`, then open
`docs/build/index.html` → **Reference → Developer guide**.)

## The essentials

- **Bug reports & questions** — open an issue with a minimal reproducer (for
  conversion bugs, the source `.dss` snippet).
- **New network cases (draft)** — convert with `from_dss`, sanity-check with
  `analyze`, cross-check against OpenDSS where you can, then open a PR. Draft
  cases **don't need to be perfect**; the key requirement is a **CC BY 4.0**
  licence. Hosting a draft here does **not** mean the Task Force will adopt it as
  an official benchmark — that is a separate, TF-governed process.
- **Tooling / analysis** — PRs need tests, a docstring on every exported symbol
  (`checkdocs = :exports` enforces this), and a `findings.md` row for any new
  finding code.
- **Tutorials** — welcome, but must not substantially overlap an existing
  tutorial; propose a merge if they do.

## CI guard-rails (a PR must clear these)

- **Coverage must not decrease** (Codecov).
- **Every exported symbol has a docstring** (`checkdocs = :exports`).
- **Tests pass on Julia LTS and latest stable** (compat floor: Julia ≥ 1.10).
- **Finding codes are stable** — match on `f.code`; renaming/removing a code is
  a breaking change.

## Data-model changes go through the Task Force

The BMOPF data model is owned by the Task Force. Propose changes via
`docs/taskforce_feedback.md` and the TF process; once accepted, they are
implemented here **behind a migration step** so existing cases keep parsing. See
the [Versioning](https://frederikgeth.github.io/BMOPFTools.jl/docs/dev/versioning/)
page.

## Licensing

- **Code** — BSD-3-Clause (`LICENSE.md`).
- **Benchmark cases & Task Force outputs** (`/output`, `/test/data`,
  `docs/taskforce_feedback.md`) — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/);
  some cases (`MV`, `LV`) are non-commercial.

By contributing **data** you agree to release it under CC BY 4.0; by contributing
**code** you agree to the BSD-3-Clause licence.
