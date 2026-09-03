# Parse and inventory one BMOPF document

Run from the repository root:

```sh
julia --startup-file=no --project=. recipes/parse_case/recipe.jl
```

The recipe reads a deliberately incomplete JSON document whose legacy uppercase
load model is normalized during ingest. It prints a hash-bound `parse_case`
response containing document identity, component counts, time-series detection,
and parse-time normalization evidence. The equivalent CLI call is:

```sh
bin/bmopf parse-case --input recipes/parse_case/input.json --pretty
```

The fixture is intentionally missing required BMOPF fields. As a CI assertion,
the recipe runs `schema_check` separately and requires `E.SCHEMA.REQUIRED`; that
validation report is not folded into the parse response. This makes the
pedagogical boundary executable: `completed` means JSON decoding and supported
migration/normalization ran, not that the document is valid, analyzable,
solver-ready, feasible, or scientifically validated.

Use `analyze-case` when you need the complete structured validation and analysis
report. The parse recipe carries no PSK identifier because it demonstrates
ordinary package intake behavior rather than a scientific preservation claim.
