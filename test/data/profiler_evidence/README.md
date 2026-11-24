# Profiler evidence fixture

`two_boundary_chain.json` is a synthetic six-bus network, not a geographic or
asset model. One 11 kV source connects through two two-port n-winding transformers
to the ends of a five-bus 230 V chain. Four declared 100 m sections give 400 m
endpoint-anchor extent and 200 m maximum shortest distance to either boundary.
The transformer nameplates declare no winding caps. The single nominal load
makes transformer attribution ambiguous through the alternative path.

`test/profiler_evidence_tests.jl` checks these independent arithmetic expectations,
refusal cases, ordering/relabeling, serialization and reports. Companion
`test/profiler_limit_builder_tests.jl` compares finite cap coverage to exact JuMP
constraint-family keys without a solve. Positive controls include deliberately
repeated demand declarations and legitimate parallel circuits. Neither repeated
fields nor source-connected ports establish physical asset provenance.

`provenance_context.json` is a minimal two-bus, three-phase LV input with no
represented neutral and a nonuniform matrix outside the PN/MPN patterns. This
is enough to prompt review for Kron reduction, while remaining compatible with
a native three-wire interpretation. It intentionally supplies no transformation
history. `test/profiler_interpretation_tests.jl` checks that the hint remains
informative without selecting an origin or a repair, and varies voltage tier,
neutral transport, matrix structure and missing data around that witness.

`balanced_phase_four_wire.json` retains an explicit neutral with unequal
phase-to-neutral mutual reactances, while the three-phase block is exactly
balanced. Both resistance and reactance are positive definite. The arithmetic
witnesses in `test/profiler_physics_guidance_tests.jl` show neutral displacement
and phase-to-neutral unbalance under balanced phase currents, exact PN terminal
relations for zero earth current with unequal conductor resistances, and Kron
loss preservation with recoverable neutral current under zero neutral voltage
drop. Negative controls break the eliminated-current/boundary assumptions.
The same tests contrast absolute inline and per-length impedances, unit-error
directions, diagonal signatures and explicit unbounded winding caps. These
small reference-relation checks require no solve or reconstruction of unknown
source data.

`kron_cancellation_four_wire.json` is a passive reciprocal primitive with
positive-definite R and X. Its phase and phase-to-neutral mutual entries are
nonzero, but its Schur correction cancels the phase mutuals, leaving `(2+2im)I`.
It demonstrates why a diagonal signature cannot exclude prior Kron reduction.
`sequence_four_conductor.dss` is a synthetic OpenDSS sequence-input example:
`nphases=4` with `r1,x1,r0,x0` materializes a coupled four-conductor matrix. The
backend test reads the native matrices, converts their per-km values to per-m,
and checks that the sequence-construction explanation remains available. The
same tests keep known MV/HV, unknown voltage/map evidence and unused templates
separate and exercise direct interpretation access from serialized analysis JSON.
