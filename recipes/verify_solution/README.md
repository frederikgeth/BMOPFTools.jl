# Verify a claimed-feasible solution

Run from the repository root:

```sh
julia --startup-file=no --project=. recipes/verify_solution/recipe.jl
```

The equivalent CLI call is:

```sh
bin/bmopf verify-solution \
  --case test/fixtures/negative/claimed-feasible-invalid-solution/network.json \
  --result test/fixtures/negative/claimed-feasible-invalid-solution/claimed-solved-result.json \
  --pretty
```

The result says `LOCALLY_SOLVED`, but independent profiling emits
`E.SOL.VOLT_VIOLATION`. This is the compact operational companion to the
pedagogical “Trust but verify” tutorial: solver termination describes the
solver's view of the posed problem, while Findings record BMOPFTools' separate
checks against the supplied case and result.

The execution envelope still reports `completed`, because verification ran
successfully. That status must not be read as a clean profile. The recipe does
not establish global optimality, correctness of the intended model, or complete
coverage of every equation and device. The book's `PSK-000003` owns the broader
scientific invalid-inference statement; this package recipe demonstrates one
ordinary verification operation and therefore does not claim that PSK identity
in executable metadata.
