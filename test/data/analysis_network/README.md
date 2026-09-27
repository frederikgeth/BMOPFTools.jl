# Synthetic workshop feeder

`synthetic_feeder.json` is an original, hand-specified BMOPFTools diagnostic
fixture, licensed under [CC BY 4.0](../license.md). It replaces the former
inline IEEE-13-inspired analysis fixture. Its names, electrical parameters,
load allocations and lateral placement are synthetic; no IEEE/Kersting
line constants, equipment specifications or reference solutions are used.

The seven-bus radial graph is:

```text
supply -- transformer -- primary -- line -- trunk -- line -- junction
                          |                  |                 |
                         line           transformer           line
                          |                  |                 |
                      lateral_a          workshop          lateral_c
```

The supply is 3.3 kV phase-to-ground. Line lengths are 320, 180, 75 and 125 m.
Impedances are in ohm/m: the three-phase R and X matrices are symmetric,
strictly diagonally dominant, and have distinct off-diagonal entries. They
are chosen to exercise matrix reconstruction and provenance diagnostics;
they are not conductor-model calculations. Loads cover unbalanced wye,
balanced delta, single-phase and zero-demand cases with distinct power factors.

This is deliberately an analysis fixture, not a validated power-flow benchmark:

- `lateral_a` has no voltage bounds.
- Neutral terminals exist but lines carry only phases, exposing floating and
  unused-neutral diagnostics. Supply, primary and workshop neutrals are grounded.
- `workshop_transformer` intentionally has three-terminal maps in the
  `single_phase` family, preserving transformer-dimension diagnostic coverage.
- `load_zero` is intentionally redundant.

Tests parse a fresh copy and mutate it to exercise invalid limits, missing
references, topology, matrix conversion, serialization and report rendering.
Removing the trunk load and workshop transformer creates a degree-two trunk
bus, used to test line merging and the effect of adding a switch tee.
There is no assertion that this diagnostic case is solver-feasible.
