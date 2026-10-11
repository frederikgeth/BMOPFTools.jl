# Ipopt barrier comparison (#429)

`ipopt_barrier.jl` compares explicit `mu_strategy="monotone"` and `"adaptive"`
with the same per-unit model, power base, topology-aware initialization, Ipopt
tolerance, MUMPS linear solver, and iteration/time budgets. It calls the existing
`solve_opf` and `profile_solution` APIs. It changes no package defaults and does
not implement a preset, retry policy, factorization telemetry, or new contract.

## Run

Use the repository's instantiated test environment, with this checkout developed
as `BMOPFTools`. The harness rejects a different installed package copy so its
recorded repository identity describes the code actually being exercised.
For a small plumbing check:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_NUM_THREADS=1 \
  julia --project=test --startup-file=no bench/ipopt_barrier.jl \
  /tmp/ipopt-barrier-smoke.jsonl test/data/case_development/feeder.json \
  --der-every 1 --load-factors 1.0 --repeats 3
```

The synthetic teaching feeder is already owned by this repository. This run
checks the workflow; its performance does not reproduce the French-feeder
observations. `--der-every 1` gives this two-load fixture dispatch freedom.

For the 498-bus example from [issue #429](https://github.com/frederikgeth/BMOPFTools.jl/issues/429):

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_NUM_THREADS=1 \
  julia --project=test --startup-file=no bench/ipopt_barrier.jl \
  /tmp/ipopt-barrier-498.jsonl \
  ../BMOPFDraftData/output/FrenchPowerGrids/original/84_MVFeeder2628.bmopf.json \
  --load-factors 0.5,1.0 --repeats 3 --max-wall-time 600
```

Supply additional case paths to compare a panel. Obtain the external data with
its applicable access/licensing terms; the harness neither downloads nor copies
that dataset into this repository. Preserve the original input and JSONL output.
Paths are recorded for traceability, but SHA-256 identities bind the input bytes
and the augmented, canonically ordered JSON model.

Include the issue's 995-bus case at load factor `1.25`, where adaptive μ was
reported slower, and the other difficult cases at their reported factors. Bus
count alone is not a case identity: confirm the file and hash against the source
campaign. Use `--max-wall-time 600` to allow a repeat of the reported 288-second
run. A smaller budget is useful for a bounded check, but a time-limited result
does not reproduce the full detection-time comparison. Ipopt checks its wall
limit at convergence checks; this is not a hard process deadline.

All options are listed by `--help`. Outputs must not already exist. Run from a
directory without `ipopt.opt`, which could override the comparison settings.
The CLI sets Julia's BLAS threads to one and records the actual configuration;
set the thread environment before launching Julia as shown above. Package load
and process startup are outside the measured intervals.

## Exact augmentation and experimental conditions

- Sort **all** load IDs lexicographically. At each fifth position by default,
  add a generator only for a three-phase WYE/DELTA load with positive total
  demand and nonnegative phase demands. Count positions before filtering.
- Set its per-phase active range to `[0, 2p_nom]`, reactive range to
  `[-p_nom, p_nom]`, and cost to `0.10`. Use the original, unscaled load demand
  to size DER, then multiply both load P and Q by the requested load factor.
- Set each voltage source's per-terminal cost to `0.25`. Preserve existing
  generators and reject a generated ID collision. `--der-every 0` disables new
  DER while retaining source pricing and load scaling.
- Inputs must be static BMOPF JSON snapshots accepted by the existing engine;
  time-series inputs must first be materialized as snapshots. This harness does
  not qualify unsupported device families or change load laws or bounds.
- Use fresh copies and model builds for every call, with no solution or dual
  warm-start transfer. Explicit common options are `tol=1e-8`,
  `linear_solver="mumps"`, `max_iter=3000`, and `max_wall_time=60` by default.
  All other solver settings retain the installed solver's defaults.

These conditions follow the issue's augmentation and its linked FormulationLab
harness. The baseline explicitly selects monotone μ rather than relying on an
installed solver's default. Pin versions when comparing with historical results.

## Output and interpretation

The streaming JSONL contains an `environment` record, then a `case` record,
`run` records, and a `summary` for each input/load-factor pair. Records are
flushed after each solve so earlier evidence survives a later interruption.

The environment records the repository revision and dirty status, harness hash,
Julia/dependency versions and package tree hashes (including solver JLLs),
hardware/thread settings, solver options, power base, repeat count, and start
policy. Preserve a commit or patch when the recorded checkout is dirty.

Each strategy receives one excluded `warmup` per case/factor. Only the first
solve in the process is marked `process_first_call`; it can include compilation
cost and is **not** an unbiased cold comparison of the two strategies. Measured
repetitions alternate order and use fresh initializations. For an independent
cold-start study, launch separate processes with controlled order.

Each run keeps termination and primal status, objective, iterations, solver time,
full `profile_solution` evidence and Finding codes, and any exception. Timing
fields have explicit boundaries:

| Field | Includes |
| --- | --- |
| `solve_time_s` | Solver-reported optimization time, when available |
| `solve_call_s` | Input copy, model construction, optimization, result extraction |
| `verification_s` | Independent package profiling and report conversion |
| `total_time_s` | Entire attempt, including verification or exception handling |

Input loading, augmentation, environment collection, and JSONL writing are
outside those intervals. The difference between solve-call and solver time is
not a direct measurement of any individual construction or factorization phase.

An `accepted` run requires `LOCALLY_SOLVED`/`OPTIMAL`, `FEASIBLE_POINT`, a finite
objective, and `profile_solution`'s `checks_passed`. This means the **assessed**
checks passed; the report retains `unassessed_dimensions`, including terminal
KCL and complete equation/limit coverage. It is not a complete physical or global
optimality certificate. `LOCALLY_INFEASIBLE` remains a solver outcome, not proof
of global physical infeasibility. Failed, indeterminate, and budget-limited runs
remain visible and are not successful timings.

Summaries report min/median/max and sample count, accepted/attempted counts,
termination statuses, all-attempt total time, and accepted-only metrics. The
adaptive/monotone median solver-time ratio is emitted only if every measured run
is accepted and all objectives agree within `atol=1e-4, rtol=1e-5`. This tolerance
is a declared comparison convention, not proof of equivalent local optima. Inspect
the objective ranges and verification evidence as well as the ratio; `null`
means a comparison is unavailable, never zero time or a speedup.

CI checks deterministic augmentation, refusal of invalid settings/collisions,
successful assessed checks, budget-limited behavior, and JSON serialization on
the synthetic fixture. It asserts no speedup or exact iteration count.

## Follow-ups kept separate

Factorization counts need a verified Ipopt/MUMPS telemetry source before joining
`opt_profile`. The reported ratio above 1.2 factorizations per iteration is a
campaign observation, not a new Finding threshold. Automatic fallback, automatic
power-base selection, and transformer-seeded `ZonePerUnitScaling` each need their
own experiments. The present comparison holds the formulation and power base fixed.
