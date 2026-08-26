# Neutral/ground/reference conflation fixture

This fixture is the minimized executable counterexample linked to `PSK-000002`.

The source retains a two-conductor phase/neutral feeder. The source neutral is perfectly grounded, while the load neutral is connected to the reference through a finite 0.1 S grounding shunt. The transformed case keeps the same simple two-bus graph but removes neutral continuity from the feeder and replaces the finite load grounding relation with a perfect local ground.

The target therefore cannot preserve the source representation's neutral-conductor continuity or grounding relation merely by calling every `n` terminal the local zero-voltage reference. The exact target demonstrates that component and shunt IDs may change while the checked relations remain preserved.

Run from the repository root:

```bash
julia --project=test --startup-file=no \
  test/fixtures/negative/neutral-ground-reference-conflation/reproduce.jl
```

This is a representation-level guardrail. It does not establish electrical terminal equivalence, explicit-earth behavior, fault or touch voltage, protection operation, or grounding-asset identity.
