# Contributing to BMOPFTools.jl

BMOPFTools is a community-driven Julia toolkit that supports the IEEE PES Task
Force on *Benchmarking Multiconductor OPF for Distribution Systems*. The Task
Force owns the BMOPF data model and governs official benchmark releases. This
repository contains the tooling, documentation, and small test fixtures; draft
benchmark datasets live in the companion
[BMOPFDraftData](https://github.com/frederikgeth/BMOPFDraftData) repository.

Contributions of code, documentation, bug reports, and data-model feedback are
welcome.

## Contributor guide

The detailed guidance is published in the latest development documentation:

- [Contributing and workflow](https://frederikgeth.github.io/BMOPFTools.jl/dev/dev/contributing/)
- [Style guide](https://frederikgeth.github.io/BMOPFTools.jl/dev/dev/style_guide/)
- [Versioning and the data model](https://frederikgeth.github.io/BMOPFTools.jl/dev/dev/versioning/)
- [OPF engine scope and status](https://frederikgeth.github.io/BMOPFTools.jl/dev/dev/opf_engine/)
- [Profiling pipeline priorities](https://frederikgeth.github.io/BMOPFTools.jl/dev/dev/profiling/)

To build the guide locally from the repository root:

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Then open `docs/build/index.html` and navigate to **Reference → Developer
guide**.

## Where to contribute

- **Bugs and questions:** [open an issue](https://github.com/frederikgeth/BMOPFTools.jl/issues/new)
  with a minimal reproducer. For a conversion problem, include the smallest
  `.dss` snippet that demonstrates it.
- **Code, analysis, and documentation:** [open a pull request](https://github.com/frederikgeth/BMOPFTools.jl/pulls)
  against this repository.
- **Draft network cases:** contribute the source network, generated case, and
  provenance to [BMOPFDraftData](https://github.com/frederikgeth/BMOPFDraftData).
- **Data-model changes:** record implementation feedback in
  [`docs/taskforce_feedback.md`](docs/taskforce_feedback.md) and take the
  proposal through the Task Force process. BMOPFTools does not change the
  shared data model unilaterally. Once accepted, implement the change behind a
  migration step so existing case files continue to parse.

## Pull-request expectations

For code or analysis changes:

- Add tests under `test/` and include new test files from `test/runtests.jl`.
- Add a docstring to every exported symbol; the documentation build uses
  `checkdocs = :exports`.
- Add every new finding code to
  [`docs/src/findings.md`](docs/src/findings.md), including its trigger and
  rationale. Match findings on `f.code`; renaming, removing, or changing the
  meaning of a code is a breaking change.
- Avoid coverage regressions. CI uploads coverage to Codecov for each run.
- Keep the code compatible with Julia 1.10, the floor declared in
  `Project.toml`. CI tests the Julia LTS channel and the latest stable release.

Run the full test suite from the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Changes that affect generated reports or simplified cases should also run:

```sh
julia --project=. scripts/generate_output.jl
```

The OPF and benchmark scripts use the environment in `scripts/`. Set it up
once with:

```sh
julia --project=scripts -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
```

## Contributing a draft network case

Draft cases do not need to be perfect, but they must be redistributable and
traceable to their source. Before opening a pull request in BMOPFDraftData:

1. Convert the source network with `from_dss`.
2. Run `analyze`, investigate all error findings, and document any understood
   warnings.
3. Cross-check the converted case against OpenDSS where possible.
4. If the case is intended for OPF, prepare it with the case-augmentation
   workflow (`fix_case` → `add_generators` → `augment_case`).
5. Preserve the source citation and exact upstream licence in the data
   directory and the generated case metadata.

Hosting a draft does not make it an official Task Force benchmark. Adoption is
a separate, Task-Force-governed process.

## Documentation and tutorials

Documentation changes should be accurate, runnable, and covered by the local
documentation build. A new tutorial should teach a workflow or feature not
already covered by the [tutorial guide](https://frederikgeth.github.io/BMOPFTools.jl/dev/choose_tutorial/).
If it substantially overlaps an existing tutorial, extend that tutorial
instead.

## Licensing

- **Code** is licensed under the [BSD-3-Clause licence](LICENSE.md).
- **Network data** retains the licence of its upstream dataset. Check the
  `License.md` or `license.md` in the relevant data directory and preserve its
  terms and citation in derivatives. The `LV` and `MV` datasets are stored externally in
  `BMOPFDraftData/test/data`; they are
  [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) and do
  not permit commercial use. The [README](README.md#licensing) has the current
  dataset-by-dataset summary.
- **Task Force feedback** in `docs/taskforce_feedback.md` is
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

By contributing code, you agree that it may be distributed under the
BSD-3-Clause licence. For data, only contribute material you have the right to
redistribute, and do not replace an upstream dataset's licence with the
repository's code licence.
