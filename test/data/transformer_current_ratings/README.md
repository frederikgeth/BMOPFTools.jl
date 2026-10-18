# Center-tap current-rating witness (#116)

`center_tap.json` is a synthetic two-bus, 240/120 V center-tap transformer with
unequal constant-power LV loads, nonzero leakage on both sides, and a legacy
excitation branch across LV leg 1. It contains no imported network data.
The 3 A leg-1 terminal cap is below the magnitude of the internal series current
but above the magnitude of the total terminal current: excitation opposes the
series current. Copying this cap onto the series variable excludes this valid
physical point.

At main `df6bc42bf`, the fixed formulation solves at tap 1 with leg-1 terminal
current magnitude approximately 2.163185 A; the variable-tap T-model pinned to
the same tap returns LOCALLY_INFEASIBLE. That status alone is not a proof of
global infeasibility. The regression independently reconstructs terminal currents
from specified load powers and solved voltages, then checks both leakage voltage
drops, ampere-turn balance, and the loss identity including excitation once.

Tests derive zero-arm, zero-excitation, different-tap, zero/missing/infinite/invalid
cap, tight-neutral, and explicit external-shunt variants in memory. Exact
current-circle boundary rows are checked without depending on optimizer status.
SI, classic per-unit, and different side-local power bases must give the same
physical currents. JSON result round trips preserve the reported currents.
The explicit-shunt variant has the same electrical solution but a different
winding-current rating boundary, which the test checks explicitly.

This fixture and its tests provide package-owned evidence linked to PSK-000013
through `knowledge/executable.toml`. The sibling book owns the scientific claim.
