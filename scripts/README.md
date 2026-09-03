# OPF formulation experiments

`opf_encoding_comparison.jl` compares the existing Ipopt smooth Volt-var/
Volt-watt formulation with the CCOpt complementarity encoding introduced by
this branch. It runs every formulation on the same parsed BMOPF snapshot and
reports solver status, objective, timing, IBR-output differences, voltage
differences, complementarity residuals, and pair count.

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
```

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

Compare timings on **`outer_time_s`**, which brackets the whole call for both
formulations. `solve_time_s` is each solver's own report and the two do not
measure the same span — CCOpt's includes MadNLP initialisation, Ipopt's
excludes model construction. Use `--warmup` either way, because the first
Julia invocation includes compilation.
