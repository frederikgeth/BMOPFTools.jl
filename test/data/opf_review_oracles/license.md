# OPF engine review oracles

Small synthetic OpenDSS cases authored for BMOPFTools. Each one isolates a
defect found in the November 2026 review of the unbalanced OPF engine, so that
the fix is held against an independent solver rather than against the engine
itself (see `test/opf_review_opendss_tests.jl`):

| Deck | What OpenDSS certifies |
|---|---|
| `pf_mesh_unequal_ratio.dss` | the circulating current in a mesh closed across transformers of unequal ratio |
| `pf_4w_two_section.dss` | neutral-voltage phasors along a two-section four-wire feeder |
| `pf_delta_gen_1ph.dss` | a single line-to-line generator delivering its setpoint once |

Not derived from utility data. They are kept apart from
`test/data/pf_comparison/`, whose decks are also swept by the `from_dss`
round-trip harness.

License: Creative Commons Attribution 4.0 International (CC BY 4.0), per the
repository's benchmark-data policy (see the root README).
