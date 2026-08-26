# Kron boundary/recovery counterexample

The tutorial-grounding case demonstrates the key guardrail: a three-wire
Schur-complement target is exact only when the eliminated neutral is pinned at
every connection point. `source.json` leaves the load-end neutral floating;
`transformed.json` nevertheless uses the exact algebraic Schur complement and
is rejected with `E.CONTRACT.KRON_GROUNDING_PRECONDITION`.

The exact companion target passes when the source load neutral is additionally
declared perfectly grounded. The pass is limited to the fixed series boundary
relation and an explicit recovery-map declaration; it is not a certificate for
internal equipment limits, protection, or network decisions.

Run from the package environment:

```bash
julia --project=. test/fixtures/negative/kron-boundary-grounding/reproduce.jl
```
