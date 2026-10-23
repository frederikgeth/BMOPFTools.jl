# Curtailed minimum-PF witness (#89, PSK-000013 evidence)

`curtailed.json` is an original synthetic one-bus, prescribed-230 V case.
The package-owned extras policy requires per-coil generation PF >= 0.8.
With P fixed at 400 W and Q maximized, the independent envelope is
|Q| <= 0.75 P = 300 var. The unchanged #438 base ignores the new policy and
returns approximately 900 var (the Q box). The new model returns 300 var.
The current oracle is conjugate((400 + j300)/230) A. Both reactive signs,
THREE_LEG pair voltages, FOUR_LEG phase voltages and SI/PU coordinates are
covered in `test/ibr_minimum_pf_tests.jl`.

The schema's existing free-form extras field carries a versioned BMOPFTools
policy, not an adopted Task Force control-profile field. It survives ordinary
JSON case parsing/serialization. Other consumers need not implement it; use
BMOPFTools' validated native model and retain this policy with the case.
No external dataset or solver output is needed to derive the expected envelope.
A separate analytic contradiction (P <= 400, Q >= 400, |Q| <= 0.75P) accompanies
local solver failure; the termination code alone is not a global certificate.
