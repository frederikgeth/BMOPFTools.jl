# Scientific review regression witnesses

Hand-minimized package-behavior fixtures. These exercise implementation errors;
they do not establish a general scientific claim beyond the linked contracts.

- `inconsistent-phasor-result.json`: use with the existing
  `claimed-feasible-invalid-solution/network.json` fixture. A 1000 V rectangular
  voltage contradicts the supplied 230 V magnitude (`PSK-000003`).
- `vuf-network.json` / `vuf-result.json`: a 10% negative/positive sequence ratio
  violates the declared 2% bus limit (`PSK-000003` checked voltage dimensions).
- `pi-chain.json`: two scalar π sections; an independent Schur complement in
  `test/scientific_review_tests.jl` demonstrates that adding lengths is not an
  exact port-admittance reduction. Large conductance deliberately makes the
  algebraic mismatch obvious; this is not a typical-feeder error estimate.

Run with `julia --project=test --startup-file=no -e 'using Test, BMOPFTools, JuMP, Ipopt; include("test/scientific_review_tests.jl")'`.
The suite also reuses `pf_center_tap_240.dss` to check split-phase augmentation.
