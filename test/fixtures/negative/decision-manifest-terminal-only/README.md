# Terminal-only decision-manifest counterexample

`transformed.json` makes an exact decision-equivalence claim but cites only an
aggregate terminal-relation certificate. It omits the declared admissible
domain, observations, source constraints, decision variables, objective, and
recovery obligations required by the initial manifest-completeness contract.

`exact-target.json` is an evidence-complete declaration for the lifted
parallel-member example. Its pass is intentionally administrative: it says the
required dispositions and references are present, not that BMOPFTools has
authenticated those references or proved decision equivalence.

Run from the package environment:

```bash
julia --project=. test/fixtures/negative/decision-manifest-terminal-only/reproduce.jl
```
