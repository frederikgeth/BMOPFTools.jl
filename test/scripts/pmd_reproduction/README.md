# PMD reproduction scripts for the bound-binding OPF tests

These scripts regenerate the hardcoded PowerModelsDistribution (PMD) targets of
the two-generator cases (F, G1/G2, H1/H2, W1, X1, D1, S1–S3) in
[`test/pmd_opf_bounds_tests.jl`](../../pmd_opf_bounds_tests.jl), plus the
Case-A pipeline gate. The remaining single-DER targets (B–E) were locked from
the original IVREN reproduction and predate these scripts. They are **not**
part of the test suite and are **never run in CI** — the suite needs no PMD
dependency, which is the point of hardcoding the targets. Run them when adding
a new bound-binding case or when re-deriving the locked numbers after a
modelling change.

## Environment

A Julia environment containing:

- `BMOPFTools` (this repository, `Pkg.develop`),
- `PowerModelsDistribution` **≥ 0.16.0** (a `Pkg.develop`'d checkout is fine and
  is what the locked targets were produced with — see each script's header),
- `JuMP`, `Ipopt`.

```julia
using Pkg; Pkg.activate(; temp=true)
Pkg.develop(path="/path/to/BMOPFTools.jl")
Pkg.develop(path="/path/to/PowerModelsDistribution")   # or Pkg.add
Pkg.add(["JuMP", "Ipopt"])
include("test/scripts/pmd_reproduction/ivren_cases.jl")
```

## Files

- `common.jl` — shared helpers: `solve_pmd_en` (BMOPF net → `to_pmd` → four-wire
  math model → `IVRENPowerModel` OPF), `inject_pmd_bounds!` (translates BMOPF
  `vn_max`/`vpn_*`/`vpp_*` bus bounds into the PMD eng fields via the `"_pmd"`
  passthrough, since `to_pmd` does not map them), and reporting utilities.
- `ivren_cases.jl` — the explicit-neutral cases: pipeline check against locked
  Case A, then the two-generator cases F, G1/G2, H1/H2, W1, X1.
- `ivru_angle.jl` — the branch angle-difference case D1 against the three-wire
  `IVRUPowerModel` (PMD has no explicit-neutral angle constraint).
- `acp_sequence.jl` — the sequence-bound cases S1–S3 against
  `ACPUPowerModel` with a custom builder (no stock PMD problem enforces the
  sequence constraints).

## Conventions

- Fixtures live in `test/data/pmd_bounds/<case>.json` (single source of truth):
  the testset and the reproduction script both parse the same file — never
  duplicate a fixture inline.
- Generator costs: BMOPF's `cost` field is currency/kWh (objective
  `cost·P/1000`); PMD math gens get `cost = [c, 0.0]` with the **same sign and
  ratio** between units (absolute scale does not move a linear argmax). Scripts
  derive the coefficients from the fixture's own `cost` fields via
  `gen_costs_from_fixture` — never from a hardcoded parallel copy. The PMD
  slack gen created for the voltage source gets cost `[0, 0]` unless the case
  prices the source.
- Compare **dispatch (per unit and total), voltages, and the recomputed binding
  quantity** — never raw objective values across tools (unit conventions differ).
- Every two-generator case must pass the cost-ratio perturbation check
  (`perturbation_check`) before its numbers are locked: scaling one unit's cost
  must move the split, proving the arbitration is non-degenerate.
- Solutions come back **eng-keyed** (`transform_solution` maps math names back
  to the original ids) in **W and V** — `to_pmd` exports
  `power_scale_factor = voltage_scale_factor = 1`, so PMD's "SI" here is plain
  SI, same as BMOPF. The `pmd_dispatch` helper reports kW/kvar.
