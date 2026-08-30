# Neutral, ground, and reference recipe

This recipe exercises the package-owned executable contract linked to
`PSK-000002`. It compares explicit neutral identity, neutral continuity, and
declared grounding/reference relations across an explicit bus mapping in the
existing minimized fixture.

From the repository root:

```sh
julia --startup-file=no --project=. recipes/neutral_ground_reference/recipe.jl
```

The same check is available through the CLI:

```sh
bin/bmopf check-contract neutral_ground_reference_preservation \
  --source test/fixtures/negative/neutral-ground-reference-conflation/source.json \
  --target test/fixtures/negative/neutral-ground-reference-conflation/transformed.json \
  --bus-map source=source --bus-map load=load --pretty
```

Expected result:

- execution status `failed`;
- Findings `E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH` and
  `E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH`;
- explicit evidence for the mapped neutral terminals, continuity mismatch, and
  changed finite/perfect grounding relation; and
- electrical, earth-return, safety, protection, and asset-state dimensions
  retained as unassessed.

This result does not say that a perfectly grounded neutral is intrinsically
invalid. It says that this target changes two representation relations present
in this source. Matching a terminal label is not evidence that neutral
continuity or its grounding relation was preserved. The package's pedagogical
[grounding tutorial](../../docs/src/tutorial_grounding.md) develops the
floating, finite-grounded, and perfectly grounded cases; consult the companion
book record linked by `PSK-000002` for the scientific statement and evidence
status.
