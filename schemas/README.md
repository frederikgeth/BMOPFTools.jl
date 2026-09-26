# Bundled schema and reviewed intake aliases

BMOPFTools validates normalized networks offline against its package-owned,
extended draft in `src/validation/schemas/draft_bmopf_schema.json`.
`bundled-schema.toml` fingerprints those bytes. Recognizing an input URI selects
this existing normalization/validation path; it does not certify the input as
valid or establish equivalence between every upstream and package feature.

## PowerIO 0.11.3 archive review (2026-09-26)

PowerIO 0.11.3 stamps the immutable archive URL ending in
`5234df55cd13ad31455697cffbdc16ca50662667/powerio-dist/schemas/bmopf/0.1.0/bmopf.schema.json`.
The accepted URL and SHA-256 are recorded in `bundled-schema.toml`.

At that exact PowerIO revision, the archive's parsed JSON is identical to
`tests/data/dist/bmopf/draft_bmopf_schema.json` after removing only `$id`.
The historical file identifies itself with the already-supported
`bmopf-report/main/draft_schema_and_networks/draft_bmopf_schema.json` URL.
The archive identifies itself with the already-supported dsopt-schema 0.1.0 URL.
The [archive manifest](https://github.com/eigenergy/powerio/blob/5234df55cd13ad31455697cffbdc16ca50662667/powerio-dist/schemas/bmopf/manifest.json)
records its source as dsopt-schema commit
`b75d0d6669c670dca37ae3ec778b3ac405c361ba` and licence as CC BY 4.0.
The file retrieved from that source commit has the same SHA-256 as the archive.
No schema bytes are copied into this repository by this change.

The package schema is broader than that baseline: it includes additional
transformer forms, IBR/DC components, time series, and line geometry. Intake
already lowercases load models, folds supported transformer fields from
`extras`, and normalizes legacy fields. These behaviors remain covered by the
PowerIO conversion and numerical regression suites. Acceptance of this alias
does not introduce a new scientific contract or widen a PSK domain.

Only the exact archived URL is added. Other commits, mutable archive URLs,
query-suffixed URLs, and the 0.2.0 proposal remain unrecognized. Adding an alias
requires comparing its schema and testing its emitted data; do not accept an
arbitrary URL merely because its path contains `0.1.0`.

## Current upstream is a separate review

The bmopf-report draft at commit
`b0b8fbec83e83b04fe84ef98749727651b7b9c90` has SHA-256
`60ffdd0f89d8a3e4d567db629c989ece11c86de2385aa4fff79ab5f5f2d0a0d7`.
Compared with PowerIO's archived baseline, it changes the schema identifier,
renames generator `cost` to `energy_cost_rate`, adds voltage-source
`energy_cost_rate`, and changes descriptive text. It is not interchangeable
with the bundled runtime schema. The public draft URL is mutable, so its
existing acceptance does not prove compatibility with every future edit.

The first-release maintainer review must settle the package's extended schema
identity, supported exchange versions, and these upstream differences.
`upstream_revision_verified = false` still accurately describes the bundled
runtime schema. The verified intake alias above does not change that flag.
