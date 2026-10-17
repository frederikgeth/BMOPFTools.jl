# Positional role-swap witness (#409)

`role_swap.json` is a synthetic two-bus switch with equal endpoint lengths and
equal phase/neutral counts. Position 1 joins phase to neutral and position 2
joins neutral to phase. Base `0efa4ad56` reports only an informational label
change; the new check emits `E.TMAP.PHASE_TO_NEUTRAL` for each bad position.
Changing the to-map to `["b", "return"]` is a valid phase relabeling control.

The test suite mutates a fresh copy for malformed/nested cases and retains the
original winding index in reference evidence. There is no power-flow claim or
external dataset dependency. The package evidence links to PSK-000002.
