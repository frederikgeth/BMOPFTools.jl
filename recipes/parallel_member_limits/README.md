# Parallel member-current-limit recipe

This recipe exercises the package-owned executable contract linked to
`PSK-000001`. It compares the two retained source members with the declared
aggregate in the existing minimized fixture and emits a JSON execution
response.

From the repository root:

```sh
julia --startup-file=no --project=. recipes/parallel_member_limits/recipe.jl
```

The same check is available through the CLI:

```sh
bin/bmopf check-contract parallel_member_limit_preservation \
  --source test/fixtures/negative/parallel-rating-outer-relaxation/source.json \
  --target test/fixtures/negative/parallel-rating-outer-relaxation/transformed.json \
  --member-id l1 --member-id l2 --aggregate-id leq --pretty
```

Expected result:

- execution status `failed`;
- Finding `W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS`;
- checked terminal-behaviour and scalar member-current-limit dimensions;
- explicit unassessed dimensions and a numerical witness.

This package result is case-specific evidence. It does not establish that all
parallel aggregation is invalid, extend the scalar result to unsupported model
classes, or recover member identity, outage state, measurements, provenance,
or protection quantities. Consult the book record linked by `PSK-000001` for
the scientific statement and evidence status.
