# Claimed-feasible invalid-solution fixture

This hand-minimized fixture executes scientific contract `claimed_solution_validity`
for `PSK-000003`.

The network declares a 200--260 V magnitude range at its phase terminal. The
negative result is labelled `LOCALLY_SOLVED` but reports 180.5 V. BMOPFTools
therefore retains the underlying `E.SOL.VOLT_VIOLATION` evidence and emits
`E.CONTRACT.CLAIMED_FEASIBLE_SOLUTION_INVALID`. The companion validated result
reports 230.5 V and passes the three dimensions implemented by this initial
contract.

Run from the repository root:

```bash
julia --project=test --startup-file=no \
  test/fixtures/negative/claimed-feasible-invalid-solution/reproduce.jl
```

This fixture does not establish equation feasibility, thermal or device-limit
satisfaction, load-model residuals, power balance, objective optimality, global
optimality, or solver derivative quality.
