# [Line geometry: wires → impedances](@id line-geometry)

*Defining overhead lines and cables from physical construction data — wire
types placed at coordinates — and compiling them into linecode impedance
matrices, OpenDSS-style but with the full multi-conductor matrix retained.*

A linecode's `R_series`/`X_series`/`B` matrices are usually the *output* of a
physics calculation over the line's cross-section: which conductors, made of
what, hanging or buried where. BMOPF stores that construction data first-class
in two library objects, and derives linecodes from them:

| object | holds | analogous to |
|---|---|---|
| `wire_data` | one reusable conductor/cable type (resistance, GMR, radii, ratings; cable layers) | OpenDSS `WireData`/`CNData`/`TSData`, CIM `WireInfo` |
| `line_geometry` | wire types placed at (x, y) coordinates, each mapped to a circuit terminal, plus the earth model | OpenDSS `LineGeometry`+`LineSpacing`, CIM `WirePosition` |
| `linecode` | the compiled per-metre impedance matrices + provenance | OpenDSS `LineCode` |

[`compile_linecode`](@ref) is the bridge. Most lines reference a linecode
(compiled from geometry, or from finite elements, a datasheet, or an import); a
line may alternatively carry its own inline absolute matrices (see
[conventions](conventions.md#Lines,-linecodes-and-matrices)). Either way the
compiled matrices are what the OPF/PF stack consumes — geometry is an *input*
to the linecode, never a second solve-time pathway.

Geometry is the **top of the impedance fidelity ladder** (geometry > per-length
linecode > inline total matrices): prefer it when the construction data exists,
because it is the only rung whose physical realisability is checkable directly
(no inverse-Carson problem), the only one that carries the data a
*frequency-dependent* (harmonic) impedance method would need, and the one that
keeps a live provenance link back to the matrices it produced. (This engine's
modified-Carson path is fundamental-frequency; see the
[validity-domain note](#Validity-domain-of-the-analytical-models) below.)
The full rationale is in [object identity](semantic_modeling.md#impedance-ladder).
For *why the impedance model changes OPF feasibility and decisions* — the
symmetry-breaking argument, with worked examples — see
[Impedance models & OPF decisions](tutorial_impedance_models.md).

Everything is SI: Ω/m, metres, amps. Convert imperial datasheet values at
construction (as below) rather than carrying unit fields around.

## Design decisions worth knowing

- **Every conductor maps to a terminal.** The compiled matrix is the full
  primitive matrix of the circuit conductors, in listing order — there is no
  Kron-elimination pathway. Grounding is a *bus* property
  (`perfectly_grounded_terminals`), not something baked into impedance data.
  This is deliberate: the four-wire OPF retains the neutral, and eliminating
  it presumes the very `V_n = 0` the model is there to question.
  The one exception is *sub-terminal* structure: concentric-neutral strands
  and tape shields sit at earth potential by construction and are reduced
  into the cable's equivalent conductors internally (Kersting's treatment),
  recorded under `derivation.shields_reduced`.
- **Earth model is data, not a constant.** `modified_carson` (default),
  `full_carson`, or `deri`, with `earth_resistivity` (default 100 Ω·m) and
  `frequency` (**required** — no ambient default, so every case is
  self-contained) on the geometry object. At power frequency the three agree
  to well under 1 % — but note **OpenDSS defaults to `deri`**, so set that
  when cross-validating against OpenDSS geometry lines.
- **Cross-defaults are recorded.** As in OpenDSS: `r_ac = 1.02·r_dc`,
  `gmr = 0.7788·radius` (solid round), `cap_radius = radius`. Every applied
  default lands in `derivation.defaults_applied`, so a dataset audit can see
  which numbers were assumed rather than supplied.
- **GMR vs radii.** `gmr` enters the series (magnetic) terms — using it there
  incorporates the internal inductance implicitly (`gmr = e^{-μᵣ/4}·radius` for
  a solid round conductor), so the engine adds **no separate internal-reactance
  term**; adding one on top of GMR would double-count it. (In the 40–1000 Hz
  power band this is exactly OpenDSS's convention too, which is why the
  cross-check below matches to five significant figures; the double-counting
  critique in the impedance-modelling literature concerns a different,
  higher-frequency code path.) `cap_radius` (default `radius`) enters the
  electrostatic terms; mixing GMR into capacitance is the classic implementation
  bug.

## Overhead example: IEEE 13 configuration 601

556.5 kcmil ACSR phases with a 4/0 ACSR neutral on the standard 500-series
pole top, at 60 Hz over 100 Ω·m earth:

```@example geom
using BMOPFTools

ft = 0.3048; inch = 0.0254; mile = 1609.344   # SI conversions

net = Dict{String,Any}(
    "wire_data" => Dict{String,Any}(
        "acsr_556" => Dict{String,Any}(
            "kind" => "overhead",
            "r_ac" => 0.1859 / mile,          # Ω/m
            "gmr" => 0.0313 * ft,             # m
            "radius" => 0.927 / 2 * inch,     # m
            "i_max" => 730.0),                # A
        "acsr_4_0" => Dict{String,Any}(
            "kind" => "overhead",
            "r_ac" => 0.592 / mile,
            "gmr" => 0.00814 * ft,
            "radius" => 0.563 / 2 * inch,
            "i_max" => 340.0)),
    "line_geometry" => Dict{String,Any}(
        "ieee13_601" => Dict{String,Any}(
            "frequency" => 60.0,
            "earth_resistivity" => 100.0,
            "earth_model" => "modified_carson",
            "conductors" => Any[
                Dict{String,Any}("wire_data" => "acsr_556", "x" => 2.5ft, "y" => 29.0ft, "terminal" => "a"),
                Dict{String,Any}("wire_data" => "acsr_556", "x" => 0.0,   "y" => 29.0ft, "terminal" => "b"),
                Dict{String,Any}("wire_data" => "acsr_556", "x" => 7.0ft, "y" => 29.0ft, "terminal" => "c"),
                Dict{String,Any}("wire_data" => "acsr_4_0", "x" => 4.0ft, "y" => 25.0ft, "terminal" => "n")])))

compile_linecode(net, "ieee13_601")
lc = net["linecode"]["ieee13_601"]
lc["derivation"]
```

The compiled linecode is the **4×4** (a, b, c, n) per-metre matrix — the IEEE
documentation's published 3×3 is its Kron reduction, which BMOPF deliberately
does not perform. Self impedance of phase a, back in Ω/mile for comparison
with the textbook:

```@example geom
z_aa = (lc["R_series_1_1"] + im * lc["X_series_1_1"]) * mile
round(z_aa, digits = 4)
```

A line then uses it like any other linecode, with `terminal_map_*` matching
the geometry's terminal labels in order:

```@example geom
net["line"] = Dict{String,Any}("l632_671" => Dict{String,Any}(
    "bus_from" => "b632", "bus_to" => "b671",
    "terminal_map_from" => ["a", "b", "c", "n"],
    "terminal_map_to"   => ["a", "b", "c", "n"],
    "linecode" => "ieee13_601",
    "length"   => 2000 * ft))
net["line"]["l632_671"]
```

Per-conductor ratings flow from `wire_data.i_max` into the linecode
(`i_max = [730, 730, 730, 340]` here) — the same per-conductor convention
lines already use.

## Cable example: concentric-neutral trio (IEEE 13 config 606)

Cables carry their layer structure on the wire type. A `cn_cable` describes
the core plus the concentric-neutral strands; a `ts_cable` the tape shield
(`d_shield`, `t_tape`, `tape_lap`). The strands/shield are built as internal
subconductors and reduced into the cable equivalent — sub-terminal structure,
not circuit conductors:

```@example geom
net["wire_data"]["cn_250"] = Dict{String,Any}(
    "kind" => "cn_cable",
    "r_ac" => 0.4100 / mile, "gmr" => 0.0171 * ft, "radius" => 0.567 / 2 * inch,
    "d_cable" => 1.29 * inch,           # overall diameter
    "n_strands" => 13,                   # concentric neutral: 13 × #14 Cu
    "d_strand" => 0.0641 * inch,
    "gmr_strand" => 0.00208 * ft,
    "r_strand" => 14.8722 / mile,
    "eps_r" => 2.3,                      # insulation, for the coaxial C
    "d_insulation" => 1.06 * inch, "t_insulation" => 0.220 * inch)

net["line_geometry"]["ieee13_606"] = Dict{String,Any}(
    "frequency" => 60.0,
    "conductors" => Any[
        Dict{String,Any}("wire_data" => "cn_250", "x" => -0.5ft, "y" => -3.0ft, "terminal" => "a"),
        Dict{String,Any}("wire_data" => "cn_250", "x" =>  0.0,   "y" => -3.0ft, "terminal" => "b"),
        Dict{String,Any}("wire_data" => "cn_250", "x" =>  0.5ft, "y" => -3.0ft, "terminal" => "c")])

compile_linecode(net, "ieee13_606")
net["linecode"]["ieee13_606"]["derivation"]["shields_reduced"]
```

Negative `y` is burial depth (CIM convention). At 50/60 Hz the earth-return
depth (~850 m) dwarfs any burial depth, so the same formulations apply
above and below ground; `modified_carson` ignores height entirely.

## Matrices from elsewhere: FEM, datasheets, imports

Geometry compilation is one *producer* of linecodes, not a privileged one. A
per-length matrix from a finite-element tool (e.g. LineCableModels.jl), a
manufacturer datasheet, or a format import is entered directly as a linecode
— stamp its origin so audits can tell them apart:

```julia
net["linecode"]["nayy_4x150"] = Dict{String,Any}(
    "R_series_1_1" => 2.075e-4, "X_series_1_1" => 7.34e-5,  # … full matrix …
    "source" => "fem",
    "derivation" => Dict{String,Any}(
        "method" => "fem_2d", "frequency" => 50.0,
        "tool" => "LineCableModels.jl", "tool_version" => "0.1.1"))
```

`source` is free-form (`"geometry"`, `"fem"`, `"datasheet"`, `"import"`, …);
`derivation` is stamped automatically by `compile_linecode` and written by
hand (or by the exporting tool) otherwise.

### Absolute impedances: matrices on the line itself

When the data is the total impedance of one *specific* section — a FEM run
of an exact cable route, a measured section, a utility-GIS record — there is
no per-length quantity to share. Put the matrices **on the line**, in Ω/S:

```julia
net["line"]["service_7"] = Dict{String,Any}(
    "bus_from" => "b12", "bus_to" => "b13",
    "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
    "R_series_1_1" => 0.031, "X_series_1_1" => 0.0042,   # Ω, section total
    "R_series_1_2" => 0.009, "X_series_1_2" => 0.0031,
    "R_series_2_1" => 0.009, "X_series_2_1" => 0.0031,
    "R_series_2_2" => 0.033, "X_series_2_2" => 0.0044,
    "length" => 28.0)   # descriptive only — NEVER scales the impedance
```

Units are unambiguous **by location**: linecode matrices are Ω/m and scale
with `length`; line matrices are totals and never scale. There is no units
enum and no conversion pathway. Consistency rules:

- exactly one impedance source per line (`linecode`+`length` XOR inline
  matrices) — `E.INT.LINE_IMPEDANCE_SOURCE`;
- inline matrices pass the same physics gates as linecodes (reciprocity,
  passivity, inductive X), reported on the line;
- a descriptive `length` triggers a plausibility check on the implied Ω/m
  (`W.DOM.LINE_IMPLIED_PER_LENGTH`) — catching per-metre data mislabeled as
  totals;
- exports re-express inline lines as a 1 m section carrying the totals
  (numerically exact for PMD/OpenDSS, whose lines are per-length × length).

This replaces the old `length = 1` workaround — which the provenance pass
detects and now recommends migrating.

## Validity domain of the analytical models

The engine is fundamental-frequency (50/60 Hz) circuit-parameter
calculation; every closed-form step has an assumption, and each assumption
has a guard (a `W.DOM.*` finding + compile-time warning — see the
[finding-code reference](findings.md)):

| Assumption | Holds when | Guard |
|---|---|---|
| Carson series truncation (`modified_carson`, `full_carson`) | k = √(ωμ₀/ρ)·S ≪ 1 — true for distribution spacings at 50/60 Hz (< 1 % vs the full series, Kersting & Green 2011) | `W.DOM.GEOM_CARSON_VALIDITY` at k > 0.25 |
| Height-independence of `modified_carson` | equivalent return depth Dₑ = 658.87·√(ρ/f) m (≈ 850 m at 60 Hz/100 Ω·m) dwarfs conductor heights and burial depths | implicit in the above |
| Buried conductors treated at the surface | burial depth ≪ earth skin depth (δ ≈ 356 m at 60 Hz/100 Ω·m); the rigorous theory is Pollaczek (1926)/Saad et al. (1996), needed only beyond power frequency | `W.DOM.GEOM_BURIED_EARTH_MODEL` |
| Deri complex-depth images | \|y\| ≪ \|p\|, p = √(ρ/jωμ₀) (Deri et al. 1981) | `W.DOM.GEOM_BURIED_EARTH_MODEL` (depth > 0.1·\|p\|) |
| Constant r_ac, GMR-based internal inductance | f below the critical skin frequency f_crit = ρ_c/(π r² μ₀) (Jensen et al. 2001) | `W.DOM.WIRE_SKIN_FREQUENCY` |
| Perfect-earth electrostatics (capacitance) | always at power frequency (no Carson analogue exists electrostatically) | — |

Both 50 and 60 Hz are computed exactly from ω — no constant in the engine is
frequency-specific, `frequency` is a **required** field on every geometry,
and nothing is ever rescaled between frequencies (there is no analogue of
OpenDSS's `DefaultBaseFreq`). `meta.frequency`, when present, is check-only:
mismatching objects raise `W.DOM.FREQUENCY_MISMATCH`.

Realizability of the construction data is validated separately (impossible:
GMR > radius, overlapping conductor circles, non-nesting cable layers →
compile errors + `E.DOM.*`; implausible: implied resistivity outside the
metallic range — the Ω/km-as-Ω/m catcher — r_ac < r_dc, εᵣ and soil-ρ
ranges, clearances, current density → `W`/`I` findings).

### References

- J. R. Carson, "Wave propagation in overhead wires with ground return," *Bell Syst. Tech. J.* 5(4), 1926.
- F. Pollaczek, "Über das Feld einer unendlich langen wechselstromdurchflossenen Einfachleitung," *E.N.T.* 3(9), 1926.
- A. Deri, G. Tevan, A. Semlyen, A. Castanheira, "The complex ground return plane: a simplified model for homogeneous and multi-layer earth return," *IEEE Trans. PAS* 100(8), 1981.
- O. Saad, G. Gaba, M. Giroux, "A closed-form approximation for ground return impedance of underground cables," *IEEE Trans. Power Delivery* 11(3), 1996.
- W. H. Kersting, R. K. Green, "The application of Carson's equation to the steady-state analysis of distribution feeders," *IEEE PES PSCE*, 2011.
- W. H. Kersting, *Distribution System Modeling and Analysis*, 4th ed., CRC Press.
- M. Jensen et al., "Series impedance of the four-wire distribution cable with sector-shaped conductors," *IEEE Porto Power Tech*, 2001.
- A. J. Urquhart, M. Thomson, "Series impedance of distribution cables with sector-shaped conductors," *IET Gener. Transm. Distrib.* 9(16), 2015.
- S. Geis-Schroer et al., "Modeling of German low voltage cables with ground return path," *Energies* 14(5), 2021.
- M. Numair, F. Geth, R. Heidari, M. Vanin, D. Van Hertem, "Impact of LV cable impedance model fidelity on distribution system state estimation," *PSCC*, 2026 — quantifies the analytical-vs-FEM gap for sector-shaped LV cables and motivates the `source="fem"` pathway.
- IEC 60228 (conductor resistances), IEC 60287 (cable data conventions, insulation permittivities, temperature coefficients).

## Provenance: the compile is checkable

A compiled linecode carries a `line_geometry` back-reference. The provenance
analyzer re-derives such linecodes and flags divergence — a stale hand-edit,
or a geometry changed without recompiling:

```@example geom
net["linecode"]["ieee13_601"]["R_series_1_1"] *= 1.5   # simulate a hand-edit
findings = BMOPFTools.Finding[]
BMOPFTools.provenance_analysis(net, findings)
[f.code for f in findings if f.code == "W.PROV.GEOMETRY_MISMATCH"]
```

```@example geom
compile_linecode(net, "ieee13_601"; force = true)      # recompile to fix
findings = BMOPFTools.Finding[]
BMOPFTools.provenance_analysis(net, findings)
any(f.code == "W.PROV.GEOMETRY_MISMATCH" for f in findings)
```

Both libraries serialise with the network (`write_bmopf`/`parse_bmopf`), so a
BMOPF JSON file can carry its construction data alongside the compiled
matrices — reviewable, re-derivable, and perturbable for sensitivity studies
(edit the geometry, recompile with `force=true`, re-solve).

## Validation status

The engine is tested against the published IEEE 13-bus feeder matrices
(overhead config 601 series **and** shunt, CN-cable config 606, tape-shield
config 607 — Kersting's reference calculations) and analytic capacitance
formulas; the earth models are cross-checked against each other at power
frequency. See `test/lineconstants_tests.jl`.

## Deferred / future work

- A public Kron-reduction transform (the internal one backs cable shields
  and unit tests only).
- Sector-shaped LV cable corrections (BS 7870 / VDE 0295 actual areas,
  geometric-centre distances) — see Numair et al., *Impact of LV Cable
  Impedance Model Fidelity on Distribution System State Estimation* (PSCC
  2026) for why this matters.
- A LineCableModels.jl import bridge for `source="fem"` linecodes.
- Preserving OpenDSS geometry objects through `from_dss` (PowerIO currently
  flattens them to matrices upstream).
- Seasonal ratings; temperature-sensitivity sweeps.
