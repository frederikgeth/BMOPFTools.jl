# Transformer winding roles swapped as an ordinary edge arrow

`source.json` declares a fixed-tap WYE/DELTA transformer from the mapped
primary bus to the mapped secondary bus. `transformed.json` swaps only
`bus_from` and `bus_to`. It leaves the subtype, ordered terminal maps, winding
reference voltages, and fixed ratio convention untouched, so the WYE and DELTA
coil incidences now attach to the wrong mapped buses.

`exact-target.json` renames the transformer but retains the scoped winding
convention. This fixture does not claim that a complete typed reversal is
impossible; it demonstrates that a bare endpoint swap is not such a reversal.

Run `julia --project=. test/fixtures/negative/transformer-winding-role-swap/reproduce.jl`
from the repository root to emit the structured result.
