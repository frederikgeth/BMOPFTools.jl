# Data input formatting

This page covers how physical quantities are represented in the JSON data model:
units, the encoding of complex numbers and matrices, unit conversion, required and
optional fields, and permissible strings.

The foundational model is in the [Data input formatting page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/data-format/). This page records where BMOPFTools extends it.

## BMOPFTools notes

- **Temperature.** The BMOPFTools `wire_data` and `line_geometry` objects (see the
  [line-geometry tutorial](../tutorial_line_geometry.md)) carry temperatures in °C, a
  second non-SI exception next to the specification's cost rate in \$/kWh.
- **Cost field name.** BMOPFTools reads per-phase energy prices (currency/kWh) from an
  element's `cost` field rather than the specification's `energy_cost_rate`; see
  [Objective](objective.md).
