# Document metadata

Every case may carry an optional top-level `meta` object with provenance, licensing,
and versioning information. It carries no OPF variables or constraints.

The foundational model is in the [Document metadata page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/metadata/). This page records where BMOPFTools extends it.

## BMOPFTools notes

- **`meta.frequency`** is checked against the `line_geometry`/linecode derivation
  frequency during validation and never rescales any quantity, as the specification
  requires.
- **`meta.provenance`** receives BMOPFTools audit records; for example, thermal
  current-rating estimates are written to `meta.provenance.thermal_estimates`.
- **`_meta`** (with a leading underscore) is a separate, BMOPFTools-internal block for
  tooling notes such as `migration_notes` and `powerio_intake_repairs`. It is not part
  of the specification's `meta` object.
