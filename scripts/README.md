# OPF formulation experiments

`opf_encoding_comparison.jl` compares the existing Ipopt smooth Volt-var/
Volt-watt formulation with the CCOpt complementarity encoding introduced by
this branch. It runs every formulation on the same parsed BMOPF snapshot and
reports solver status, objective, timing, IBR-output differences, voltage
differences, complementarity residual, and pair count.

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

# Compare CCOpt's penalty method instead of its relaxation homotopy.
julia --project=/path/to/ccopt-environment \
  scripts/opf_encoding_comparison.jl CASE.bmopf.json \
  --method=penalty --warmup
```

The TSV columns ending in `_delta` are smooth-result minus CCOpt-result
absolute differences, except `objective_delta_vs_ccopt`, which is signed.
Reported solve times are solver times; `outer_time_s` is included for the
CCOpt call as a rough wall-clock check. Use `--warmup` when comparing timings
because the first Julia invocation includes compilation.
