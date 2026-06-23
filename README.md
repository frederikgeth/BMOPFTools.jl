> [!WARNING]  
> This project is currently ongoing rapid development and may have breaking changes made directly to main. Use at your own risk until further notice. OpenDSS ingestion now goes through [PowerIO.jl](https://github.com/eigenergy/PowerIO.jl) (the earlier PowerModelsDistribution-based `from_pmd` parser has been removed).


[![Documentation](https://github.com/frederikgeth/BMOPFTools.jl/actions/workflows/documentation.yml/badge.svg)](https://github.com/frederikgeth/BMOPFTools.jl/actions/workflows/documentation.yml) [![CI](https://github.com/frederikgeth/BMOPFTools.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/frederikgeth/BMOPFTools.jl/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/frederikgeth/BMOPFTools.jl/graph/badge.svg)](https://codecov.io/gh/frederikgeth/BMOPFTools.jl)

# BMOPFTools.jl

A Julia library for **parsing, validating, analysing and reporting** on
BMOPF-format distribution network datasets — the JSON data model developed by
the IEEE Task Force on *Benchmarking Multiconductor OPF for Distribution
Systems* for up-to-four-wire optimal power flow, currently hosted at
https://github.com/frederikgeth/bmopf-report.

The network data model is a plain `Dict{String,Any}` that mirrors the BMOPF
JSON schema exactly: no wrapper types, so data flows naturally between JSON,
the `to_pmd` PowerModelsDistribution export, and your own code.

## IEEE PES Task Force

**Benchmarking Multiconductor OPF for Distribution Systems**

| Role | Name | Affiliation |
|---|---|---|
| Chair | Matthew Deakin | Newcastle University, UK |
| Co-chair | Frederik Geth | University of Queensland, Australia |
| Secretary | Amrit Pandey | University of Vermont, USA |

## Motivation

Reliable benchmarks are essential for validating and comparing power system
algorithms, yet unbalanced distribution networks have historically
lacked a common, open benchmark format.  This repository is part of the IEEE
PES Task Force effort to fill that gap — motivated by the success of
community benchmark libraries such as [PGLib](https://power-grid-lib.github.io/)
in the broader power systems and optimisation communities.

BMOPFTools provides the tooling needed to convert real utility-derived OpenDSS
networks into clean, spec-conformant BMOPF benchmark cases, validate them
against the data model, and confirm that they are well-posed OPF instances
before publication.  The companion `/output` directory contains the resulting
benchmark cases. We will move the accepted test cases to another repository down 
the line, to enable versioning and control. 

## Licensing

**Code** — BSD-3-Clause License.

**Benchmark cases and task force outputs** (everything in `/output`,
`/test/data`, and `docs/taskforce_feedback.md`) — [Creative Commons Attribution
4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
Anyone may copy, redistribute, and adapt these materials provided appropriate
credit is given, a link to the licence is included, and changes are indicated. 
Note that some cases are restricted to non-commercial use ("MV" and "LV"). 

## What it does

```
OpenDSS .dss ──(from_dss / PowerIO.jl)──► BMOPF Dict{String,Any} ◄── parse_bmopf ◄── BMOPF JSON
                                                 │               └──── write_bmopf
                                                 │ analyze
                                                 ▼
                                          SummaryReport ──► render
                                                 │ fix_case
                                                 ▼
                                         net′ (repaired)
                                                 │ add_generators / add_inverters  (optional DER)
                                                 ▼
                                          net′ + DERs
                                                 │ augment_case
                                                 ▼
                                    net″ (benchmark-ready) ──► write_bmopf
                                                 │ solve_opf / solve_pf / to_pmd
                                                 ▼
                                        result Dict{String,Any}
                                                 │ profile_solution
                                                 ▼
                                       SolutionReport ──► render_solution
```

- **Conversion**: `from_dss` (via [PowerIO.jl](https://github.com/eigenergy/PowerIO.jl))
  translates OpenDSS networks into BMOPF dicts, handling earth-terminal
  conventions, grounding reactors, and transformer impedance bases. `to_pmd`
  exports a BMOPF dict to a PowerModelsDistribution ENGINEERING model.
- **Validation**: required fields, spec conformance (configuration/arity
  rules, terminal types), referential and dimensional integrity, domain
  plausibility, redundancy.
- **Analysis**: inventory, voltage levels, connectivity/topology, diversity,
  operational loading, infeasibility preflight, data **provenance**
  (sequence-derived impedances, Kron-reduction likelihood, earthing-system
  tagging, OpenDSS default fingerprints, regulator patterns) and
  **benchmark readiness**.
- **Reporting**: every `analyze` run produces a `SummaryReport` with a
  complete catalogue of stable, documented finding codes, rendered to
  terminal or Markdown.
- **Case preparation**: `fix_case` (structural repairs — remove inert
  elements, convert near-zero impedance lines to switches, drop disconnected
  islands) and `augment_case` (standards-grounded gap-filling — inject
  voltage bounds, infer thermal limits, add slack generation) prepare a raw
  import for use as an OPF benchmark.  Both return a `TransformationManifest`
  audit trail.
- **Solution profiling**: given a BMOPF network and an OPF result dict,
  `profile_solution` flags bound violations, near-active constraints,
  constraint residuals, and solution-quality issues without access to solver
  internals.

## Installation

BMOPFTools requires **Julia ≥ 1.10**.  It is not yet in the General registry,
so install it from this Git URL:

```julia
using Pkg
Pkg.add(url = "https://github.com/frederikgeth/BMOPFTools.jl")
```

Parsing, validation, analysis, reporting, OpenDSS ingestion (`from_dss`, via
the [PowerIO.jl](https://github.com/eigenergy/PowerIO.jl) dependency), and the
`to_pmd` exporter work out of the box. One capability pulls in extra tooling,
activated only when you load it:

- **OPF / power flow** (`solve_opf`, `solve_pf`, `solve_feasibility_opf`) is a
  package extension that activates once **JuMP** and a solver such as **Ipopt**
  are present — `Pkg.add(["JuMP", "Ipopt"])`.

> [!TIP]
> Because breaking changes land directly on `main` (see the warning above),
> pin a revision when you need reproducibility:
> `Pkg.add(url = "https://github.com/frederikgeth/BMOPFTools.jl", rev = "<commit-sha>")`.

## Quickstart

Analysing an existing BMOPF JSON case:

```julia
using BMOPFTools

net    = parse_bmopf("case.json")
report = analyze(net)
render(report, stdout)              # terminal report
render(report, "case_report.md")    # Markdown report

errors(report)                      # findings with ERROR severity
report.results[:provenance]["convention"]
```

Profiling an OPF result dict (requires `solve_opf` or any compatible solver):

```julia
using BMOPFTools, JuMP, Ipopt

net    = parse_bmopf("case.json")
result = solve_opf(net; optimizer=Ipopt.Optimizer)

report = profile_solution(net, result)
render_solution(report, "solution.md")

errors(report)    # bound violations and infeasibility findings
warnings(report)  # near-active bounds and residual warnings
```

Converting from OpenDSS (via PowerIO.jl):

```julia
using BMOPFTools

net    = from_dss("Master.dss")     # parsed in-process by PowerIO.jl
net′,  fix_mf  = fix_case(net)
net″,  aug_mf  = augment_case(net′)
write_bmopf("case.json", net″)
```

## Development

The dependencies are declared in `Project.toml`: the core runtime pulls in
`Graphs`, `JSON3`, `JSONSchema`, `PowerIO`, `TOML`, and the standard libraries;
`JuMP`/`Ipopt` are weak dependencies behind the OPF extension (see
[Installation](#installation)). The test suite skips the power-flow comparison
tests when `OpenDSSDirect` is absent.

```sh
# full test suite (from the package root)
julia --project=. -e "using Pkg; Pkg.test()"

# generate analysis reports and simplified variants for all output/ networks
julia --project=. scripts/generate_output.jl

# regenerate everything under output/ENWLbenchmark/ (reports, OPF results,
# solution reports). The scripts/ env carries JuMP + Ipopt; instantiate once:
julia --project=scripts -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=scripts scripts/run_benchmark.jl            # all stages
julia --project=scripts scripts/run_benchmark.jl opf        # or: outputs / solutions
```

One-off data-migration scripts live in `scripts/oneoff/`.

## Documentation

Build the documentation locally:

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
# open docs/build/index.html
```

Pages: data-model conventions, the conversion guide (every deliberate
`from_dss`/`to_pmd` decision), the analysis/report guide, the **complete
finding-code reference** (128 codes), methodology notes with literature
references, the case augmentation guide (`fix_case` + `augment_case`), the
OPF guide, and the OPF result dictionary reference.

`docs/taskforce_feedback.md` collects implementation feedback on the Task
Force draft specification.

## Examples

- `examples/lv1_14bus_walkthrough.jl` — step-by-step tour of every analysis
  on a real 14-bus LV feeder.

## Case file overview

Converted benchmark cases live in `/output/`.  The original OpenDSS source
files are in `/test/data/`.

## How to contribute

BMOPFTools is a community-driven initiative.  Contributions of all kinds are
welcome:

- **Bug reports and questions** — open an issue in the tracker.
- **New network cases** — fork the repository, convert and validate your case
  with BMOPFTools, then submit a pull request.  All data contributions go
  through a quality-assurance review before merging.
- **Tooling improvements** — pull requests for new analysis passes, conversion
  fixes, or documentation are encouraged.

By contributing data you agree to release it under CC BY 4.0.

## Citation

This repository is not static; please include the version number when citing
it in scholarly work.  Case files carry original-source attribution in their
headers — cite those sources when using specific networks.