# Original synthetic line geometries

These three independently specified test cases replace the IEEE-13/Kersting
601/606/607 fixtures. Their parameters are chosen for regression coverage,
not copied from a feeder or conductor catalogue and not asserted to describe
commercial equipment. They are licensed under the parent `license.md` (CC BY 4.0).

- `synthetic_overhead.dss`: asymmetric four-wire layout with distinct phase and
  neutral wire parameters, retained as a full 4×4 primitive.
- `synthetic_cn.dss`: three cables at unequal horizontal spacings, each with
  12 neutral strands. Shields are reduced internally; phases remain 3×3.
- `synthetic_ts.dss`: one tape-shield cable with 25% lap and a separate return
  conductor. Shield reduction leaves a 2×2 phase/return primitive.

All decks use explicit SI length/resistance units and a 60 Hz Carson baseline.
Tests also exercise overhead FullCarson, Deri, and 50 Hz variants. The Julia
input dictionaries are written separately from the DSS decks; neither engine
supplies the other's geometry or impedance matrices.

`opendss_reference.json` holds full R/X/C matrices calculated by OpenDSS only,
with engine/package versions, SI units, and the SHA-256 of every input deck.
Regenerate intentionally with an instantiated test environment:

```sh
julia --project=test --startup-file=no scripts/regenerate_geometry_reference.jl
```

Review input and reference diffs together. The generator never calls BMOPFTools.
Offline tests use the frozen results; CI requires live OpenDSS comparisons.
Existing analytic, invalid-input, serialization, and frequency checks remain.
Neutral elimination is tested against explicit Schur complements of OpenDSS's
matrices, not the former published reference literals. This changes the
finite validation cases, not the supported scientific domain or a PSK claim.
