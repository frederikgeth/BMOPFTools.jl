# Positioning & ecosystem

BMOPFTools is **infrastructure for distribution-system optimization research**:
it constructs, validates, converts, and benchmarks conductor-level network
models. It is not positioned as another distribution OPF *solver* — although it
ships a reference four-wire IVR-EN OPF ([`solve_opf`](opf.md)) used to validate
cases and profile solutions, the product is the model and the tooling around it,
not the optimizer.

## The transmission/distribution maturity gap

Power-system software is often discussed as one ecosystem, but transmission and
distribution have matured very differently.

**Transmission** optimization has decades of shared conventions and benchmarks —
MATPOWER, PowerModels.jl, and PGLib-OPF among them — which let researchers
compare algorithms on common test systems with well-understood problem
definitions, and reproduce each other's results.

**Distribution** optimization remains fragmented. Tools such as
PowerModelsDistribution.jl, ppOPF, Open-DSOPF, and various OpenDSS- and
GridLAB-D-based workflows solve overlapping problems — Volt/VAr optimization, DER
coordination, network reconfiguration, hosting-capacity analysis, distribution
OPF — but rely on different data models, feeder representations, assumptions,
formulations, and conversion pipelines. As a result, reproducing results and
fairly comparing methods is hard.

## What BMOPFTools is

Rather than competing with optimization frameworks, BMOPFTools strengthens the
ecosystem around them. It focuses on:

- **Network representation** — a faithful, conductor-level (up-to-four-wire)
  data model ([conventions](conventions.md));
- **Data interoperability** — OpenDSS ingestion via `from_dss` and export to
  PowerModelsDistribution via `to_pmd` ([conversion guide](conversion.md));
- **Analytical model construction & validation** — provenance, data-quality, and
  spec-conformance analysis ([analysis & reports](analysis.md));
- **Benchmark generation** — structural repair and standards-grounded gap-filling
  that turn raw utility feeders into well-posed cases ([case augmentation](augmentation.md));
- **Reproducible workflows** — a stable, code-addressable diagnostic vocabulary
  ([finding-code reference](findings.md)).

## How it relates to existing tools

BMOPFTools sits *between* the simulation tools that produce network data and the
optimization frameworks that consume it — supplying the shared representation and
benchmark cases that let those frameworks be compared. It is complementary to all
of the below, not a replacement for any.

| Project / tool | Focus | Relationship to BMOPFTools |
|---|---|---|
| MATPOWER | Transmission OPF conventions & benchmarks | Inspiration — BMOPFTools aims to bring comparable reproducibility to *distribution* |
| PowerModels.jl | Optimization formulations (transmission) | Complementary formulation layer; BMOPFTools supplies the network model |
| PowerModelsDistribution.jl | Distribution OPF formulations & solution methods | Complementary and interoperable (`to_pmd` export); BMOPFTools supplies benchmark cases |
| ppOPF, Open-DSOPF | Distribution OPF implementations | Complementary; BMOPFTools provides shared representations & benchmark feeders for comparison |
| OpenDSS, GridLAB-D, Power Grid Model, PowerFactory, PSS®SINCAL, CYME, Synergi Electric | Simulation & engineering analysis | Data sources; BMOPFTools ingests their models and produces an optimization-ready representation |

## The benchmarking gap, and the opportunity

The throughline above is a missing layer of **shared benchmark infrastructure**
for distribution optimization: feeder conversion is lossy, assumptions are
inconsistent, data models are incompatible, and reproducibility is limited, so
published methods are difficult to compare fairly.

Transmission optimization matured rapidly once the community converged on common
benchmark systems and data formats. Distribution likely needs the same shift.
BMOPFTools is intended to help create the conditions for it — reusable benchmark
feeders, common network representations, transparent model transformations, and
cross-framework interoperability — so the broader distribution-optimization
ecosystem can mature, without replacing the optimization frameworks at its core.
