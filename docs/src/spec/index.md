# Data model specification

The IEEE PES Task Force maintains the BMOPF mathematical and data model in its
[specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/).
That document owns the foundational model — data fields, symbols, variables and
constraints — for the elements it covers. The pages in this section record what
BMOPFTools does with it:

- **Elements the external specification covers** (buses, lines, switches,
  loads, generators, shunts, capacitors, voltage sources, transformers, the
  objective, and the foundations such as grounding and data formatting): each
  page links to the matching external page for the foundational model and keeps
  only where BMOPFTools extends it and how BMOPFTools implements it.
- **Elements only BMOPFTools documents** — the full reference for these is here:
  [inverter-based resources](ibr.md), [control profiles](control-profile.md),
  [regulators](regulator.md), [DC networks](dc.md), [time series](timeseries.md)
  and [impedance derivation](impedance.md).

[Notation](notation.md) defines the symbols used across these pages. For using
the package rather than the data model, start with
[Data model conventions](../conventions.md), [Optimal power flow](../opf.md) and
the [API reference](../api.md).
