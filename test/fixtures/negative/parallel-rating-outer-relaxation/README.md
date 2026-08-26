# Parallel-rating outer relaxation

This hand-minimized fixture executes scientific contract
`parallel_member_limit_preservation` for `PSK-000001`.

`source.json` retains two scalar resistive parallel members with impedances
0.1 Ω and 1.0 Ω and current limits of 100 A each. `transformed.json` replaces
them by the terminal-equivalent 1/11 Ω branch and naively assigns the sum of
the member ratings, 200 A.

The source member limits require `|ΔV| ≤ 10 V`; the naive target admits
`|ΔV| ≤ 200/11 V`. At the recorded 15 V witness the target carries 165 A and
is feasible, while recovered source currents are 150 A and 15 A, so member
`l1` is overloaded. `exact-target.json` uses a case-specific 110 A scalar
aggregate limit and therefore reproduces this scalar voltage-drop region. It
does not recover member identity, outage state, measurements, or provenance.

Run from the repository root with:

```sh
julia --project=test test/fixtures/negative/parallel-rating-outer-relaxation/reproduce.jl
```

The reproducer is algebraic and does not require JuMP or a nonlinear solver.
`expected.json` records scientifically meaningful values and tolerances rather
than a complete byte-for-byte runtime dump.
