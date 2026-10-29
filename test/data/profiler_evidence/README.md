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
