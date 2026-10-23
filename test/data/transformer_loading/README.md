# Coil-loading diagnostic witness (#413, P8)

`overloaded_coil.json` retains the 100 kVA three-coil bank / 40 kW single-phase
constant-impedance load from `test/pf_nameplate_contract_tests.jl` (#355/#401).
The `result` is deliberately supplied diagnostic data, not a successful solve of
the rated case: one coil carries 40 kVA against 100/3 kVA while the sum of coil
magnitudes is only 40% of the summed caps. Its claimed solved status is not
authentication. Missing unrelated result fields are intentionally retained;
the whole-network verification is not thereby certified.

The static suite verifies the overloaded coil is visible beside the modest
aggregate, and checks below/on/above-cap, zero, missing/invalid data, failed
candidates, JSON/Markdown, subtype slot layouts and unsupported evidence. It
compares Findings directly with `solution_check`: the report emits no new
thermal checks or duplicate Findings. Existing tests and fixtures are unchanged.

The native suite solves the same ideal 1:1, shunt-free case at 30 kW and 100/3 kW
in SI and classic PU, then independently computes each coil's
`S = (V_phase - V_neutral) * conj(I_coil)`. It compares full complex power with
the prescribed load and the independent source current, then checks report
magnitudes/caps/headroom. The rated 40 kW case remains locally infeasible; an
explicit test-only copy without the rating recovers 230 V and 40 kW. Neither
the report nor any runtime code changes ratings or retries a solve, and local
infeasibility is not called a global certificate. Unrated results have missing
coil-cap records, not zero loading.

This finite, deterministic evidence links to existing PSK-000013. It is not a
proof of all transformer equations or result provenance. Subtype layout tests
cover every native subtype, including n-winding per-winding groups. The physical
oracle also checks the unchanged single-phase, center-tap, wye-delta and
delta-wye interoperability fixtures at SI and two PU bases, using raw terminal
maps and coil currents to reconstruct |S| independently of report slot helpers.
P9 preflight
allocation/estimation remains separate and is not implemented by this slice.

`integer_voltage_candidate.json` minimizes a verification crash found by these
JSON round trips: integral voltage coordinates produced an integer squared
voltage, which did not dispatch to `_load_model_power`'s Float64 argument. The
checker now converts coordinates before squaring; physics and tolerances are
unchanged. A new test compares integer and floating-point candidate Findings
without changing an existing expectation. This is supplied-result verification,
not a parsing or external-format export change.
