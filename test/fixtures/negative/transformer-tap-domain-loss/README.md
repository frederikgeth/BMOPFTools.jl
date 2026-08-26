# Adjustable transformer tap frozen at its start

`source.json` declares transformer `tx` with a continuous tap decision over
`[0.95, 1.05]`. `transformed.json` keeps the same base transformer declaration
but omits `tap_min` and `tap_max`, which makes `tap = 1.0` a fixed singleton in
the BMOPFTools data model. The target is therefore an inner restriction, not an
equivalent representation of the source decision problem.

`exact-target.json` retains the complete interval. Its different admissible
start value demonstrates that the contract compares the decision domain rather
than demanding identical initial guesses.

Run `julia --project=. test/fixtures/negative/transformer-tap-domain-loss/reproduce.jl`
from the repository root to emit the structured contract result.
