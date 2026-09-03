# OPF formulation experiments

`opf_encoding_comparison.jl` compares the existing smooth Volt-var/Volt-watt
formulation with the CCOpt complementarity encoding introduced by this branch.
It runs every formulation on the same parsed BMOPF snapshot and reports solver
status, objective, iterations, timing, IBR-output differences, voltage
differences, complementarity residuals, and pair count.

The comparison is **factorial**, because encoding and solver are otherwise
confounded: CCOpt drives MadNLP, so a plain smooth-Ipopt-vs-CCOpt table cannot
say whether a difference came from dropping the smoothing or from changing the
optimiser. Three row families separate them:

| row | encoding | solver | isolates |
| --- | --- | --- | --- |
| `smooth / ipopt` | softplus | Ipopt | the status quo |
| `smooth / madnlp` | softplus | MadNLP | solver effect |
| `ccopt` | exact hinge | MadNLP via CCOpt | encoding effect |

Every solver runs with `bound_relax_factor = 0.0`, matching the default
`solve_ccopt!` applies, and every smooth row shares one `--tol` so no row is
advantaged by a looser stopping rule. The CCOpt row keeps its own homotopy
tolerances — tightening the inner tolerance actively disrupts it — and how
exactly it solved its complementarity pairs is reported in the residual columns
instead.

The script needs an active Julia environment containing `BMOPFTools`, `JuMP`,
`Ipopt`, `CCOpt`, `MPCCModels`, and `NLPModelsJuMP`. The ordinary `scripts`
environment predates the optional CCOpt stack, so use the environment where
the draft PR's CCOpt dependencies have been installed. From the repository
root, a disposable environment can be prepared with:

```bash
julia --project=/tmp/bmopf-ccopt-env -e \
  'using Pkg; Pkg.activate("/tmp/bmopf-ccopt-env"); \
   Pkg.develop(path=pwd()); \
   Pkg.add(["JuMP", "Ipopt", "CCOpt", "MPCCModels", "NLPModelsJuMP"])'
```

Then run the experiment:

```bash
julia --project=/tmp/bmopf-ccopt-env \
  scripts/opf_encoding_comparison.jl \
  /path/to/BMOPFDraftData/benchmarks/ENWLsnapshots/30bus_LG/30bus_LG_t01_0800.bmopf.json \
  --warmup --out=/tmp/opf-encoding-comparison.tsv
```

Useful variants:

```bash
# A shorter epsilon sweep.
julia --project=/path/to/ccopt-environment \
  scripts/opf_encoding_comparison.jl CASE.bmopf.json \
  --eps=2e-3,1e-4,1e-5 --warmup

# Reproduce MadNLP's premature termination (see the caveats below).
julia --project=/path/to/ccopt-environment \
  scripts/opf_encoding_comparison.jl CASE.bmopf.json \
  --eps=1e-5 --tol=1e-8 --warmup
```

## Two solver caveats worth knowing before you read a table

**MadNLP terminates prematurely at its default tolerance.** On the two-bus
Volt-watt case it returns p_g = 800.8 W where Ipopt returns 1183.3 W, reporting
`LOCALLY_SOLVED` after as few as 7 iterations. The returned point is feasible —
it is not garbage — but it is not a local optimum: Ipopt warm-started there
walks away to the better objective, and MadNLP started at the better point walks
away from it. Which epsilon triggers this varies erratically with the softplus
mode, and both modes are affected:

| ε | Ipopt | MadNLP, `tol=1e-8` | MadNLP, `tol=1e-10` |
| --- | --- | --- | --- |
| 1e-1 | 1779.6419 | 1779.6419 | 1779.6419 |
| 1e-2 | 1554.9024 | **1079.8999** | 1554.9024 |
| 1e-3 | 1183.5450 | **798.1582** | 1183.5450 |
| 1e-4 | 1183.2966 | 1183.2966 | 1183.2966 |
| 1e-5 | 1183.2966 | **800.7890** | 1183.2966 |

At `tol=1e-10` MadNLP matches Ipopt at every epsilon, in both softplus modes,
which is why the script's `--tol` defaults to 1e-10 and applies the same value
to every smooth row. Ipopt is unaffected either way. The script also warns when
two solvers disagree at the same epsilon, since that is the visible symptom.

**`softplus=:builtin` overflows at small ε.** Its expression form is
`ε·log1p(exp(x/ε))`, emitted as native MOI operators so DiffOpt can
differentiate it; there is no MOI `log1pexp`. For ε ≲ 1e-3 over a realistic
per-unit voltage span this overflows — `exp(0.2/1e-4) = Inf` — and the solve
returns `INVALID_MODEL`. The default `:user_defined` mode uses the stable
`log1pexp` with analytic derivatives and is fine down to 1e-5, so prefer it
unless you specifically need the DiffOpt-compatible form.

## The penalty method

`--method=penalty` selects CCOpt's penalty homotopy instead of its relaxation
homotopy. It does not currently run: CCOpt 0.1.0 evaluates the complementarity
residual at the ℓ₁-relaxation's expanded iterate, so it raises a
`DimensionError` for any model with at least one pair. `solve_ccopt!` reports
that for what it is; use `--method=relaxation` (the default) until it is fixed
upstream.

## Reading the report

The TSV columns ending in `_delta` are smooth-result minus CCOpt-result
absolute differences, except `objective_delta_vs_ccopt`, which is signed.

Three columns describe how exact the "exact" encoding actually was:

| column | meaning |
| --- | --- |
| `max_complementarity_product` | worst `\|r · s\|` — what the homotopy drives, but not interpretable in model terms |
| `max_curve_error_relative` | worst `\|slope\| · min(r, s)`: the fraction of a curve's own reference base by which the *enforced* droop value is displaced. This is the number to read |
| `max_hinge_bound_violation` | worst `max(−r, −s, 0)`. A hinge below its own zero is meaningless rather than merely small, and the product column hides it |

`complementarity_satisfied` is false when either of the last two exceeds
`extract_ccopt_result`'s tolerances, in which case the row's `feasible` is
false as well: the point sits on a *relaxed* droop curve and its setpoints do
not obey the control law.

Compare timings on **`outer_time_s`**, which brackets the whole call for every
row. `solve_time_s` is each solver's own report and the two do not
measure the same span — CCOpt's includes MadNLP initialisation, Ipopt's
excludes model construction. Use `--warmup` either way, because the first
Julia invocation includes compilation.
