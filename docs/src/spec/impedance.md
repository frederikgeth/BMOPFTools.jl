# Impedance derivation

Line impedances can be given directly (a [linecode](line.md#Linecode) or inline
matrices) or **derived from conductor geometry**. This page documents the geometry
inputs — `wire_data` (a conductor library) and `line_geometry` (a cross-section
assembly) — and how they compile into a linecode. This is a *data-model* page: these
objects carry no OPF variables or constraints; they produce the
$\textcolor{brown}{\mathbf{Z}^{\text{s}}_c}$ and $\textcolor{brown}{\mathbf{Y}^{\text{sh}}_c}$
matrices the [Lines](line.md) page consumes. Symbols are defined in
[Notation](notation.md). All quantities are SI (Ω/m, m, S/m, A, °C).

## Wire data

A `wire_data` entry is a reusable conductor/cable construction type, referenced by
`line_geometry` conductors.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `kind` | string | – | ✔ | `overhead`, `cn_cable` (concentric-neutral), or `ts_cable` (tape-shield) |
| `r_dc`, `r_ac` | number | Ω/m | (one) | DC / AC resistance at `temperature_ref` (the other defaults via $r_{\text{ac}}=1.02\,r_{\text{dc}}$) |
| `temperature_ref` | number | °C | | Reference temperature (default 20) |
| `alpha_20` | number | 1/K | | Temperature coefficient at 20 °C (e.g. 0.00393 Cu, 0.00403 Al) |
| `gmr`, `radius` | number | m | (one) | Geometric mean radius / physical radius (the other defaults via $\text{gmr}=0.7788\,\text{radius}$) |
| `cap_radius` | number | m | | Electrostatic radius for capacitance (defaults to `radius`) |
| `i_max`, `i_max_emergency` | number | A | | Continuous / emergency current rating |
| `eps_r`, `t_insulation`, `d_insulation`, `d_cable` | number | –, m | | Insulation permittivity and cable dimensions (cables) |
| `n_strands`, `d_strand`, `gmr_strand`, `r_strand` | – | –, m, Ω/m | | Concentric-neutral strand data (`cn_cable`) |
| `d_shield`, `t_tape`, `tape_lap` | number | m, m, % | | Tape-shield data (`ts_cable`) |

## Line geometry

A `line_geometry` entry places wire types at coordinates and maps each to a circuit
terminal.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `conductors` | object[] | – | ✔ | Ordered placements — each has `wire_data`, `x`, `y` (m; `y<0` = buried), and `terminal` |
| `frequency` | number | Hz | ✔ | Frequency the linecode is compiled at (recorded in the derivation; no rescaling) |
| `earth_model` | string | – | | `modified_carson` (default), `full_carson`, or `deri` |
| `earth_resistivity` | number | Ω·m | | Homogeneous earth resistivity (default 100) |
| `capacitance_model` | string | – | | `thin_wire` (default; a line charge at each conductor center) or `charge_simulation` (resolves each conductor's surface charge; accurate for tightly bundled conductors) |
| `temperature` | number | °C | | Conductor operating temperature (resistances corrected from `temperature_ref` via `alpha_20` when present) |

The `conductors` **order defines the matrix row order** of the compiled linecode, and
each conductor maps to exactly one circuit terminal.

## Compilation to a linecode

`compile_linecode(net, geometry_id; id=geometry_id, force=false)` builds the
**full primitive** per-meter matrices from the geometry and stores them as
`net["linecode"][id]` (an existing linecode is overwritten only with `force=true`):

- **Series impedance** $\textcolor{brown}{\mathbf{Z}^{\text{s}}_c}$ (Ω/m) from the
  conductor self/mutual impedances (GMR, spacing) plus the earth-return correction of
  the selected `earth_model` (modified/full Carson, or Deri), with resistances
  temperature-corrected to `temperature` (see Kersting in [References](references.md)).
- **Shunt susceptance** (S/m), split equally into the from/to half-sections: for
  overhead conductors from the Maxwell potential coefficients (perfect-earth images,
  using `cap_radius`); for cables the coaxial phase-to-shield capacitance (diagonal).
  No shunt conductance is emitted. `capacitance_model` selects the overhead kernel;
  `thin_wire` loses accuracy once $(r_i + r_j)/d$ exceeds about 0.5
  (`W.DOM.GEOM_THIN_WIRE`).
- **Ratings** carried from `wire_data.i_max` into the linecode's `i_max`, when every
  conductor's wire type has one.

Every conductor maps to a terminal, so the compiled matrix is the **full primitive
matrix of the circuit conductors — they are never Kron-eliminated**. Grounding is
expressed on the bus (`perfectly_grounded_terminals`), not by reducing the matrix,
keeping the neutral/earth conductors explicit (consistent with the four-wire model).
The one exception is internal cable structure: concentric-neutral strands and tape
shields are built as subconductors held at earth potential and reduced into the
cable's equivalent conductor (recorded under `derivation.shields_reduced`). The
compilation records its provenance in the linecode: `source = "geometry"`, a
`line_geometry` back-reference, and a `derivation` block (earth model, capacitance
model, earth resistivity, frequency, temperature, applied defaults, tool version).

## Implementation in BMOPFTools

- `compile_linecode` assembles the primitive impedance (Carson/Deri) and Maxwell
  potential matrices and emits a `linecode` object with `R_series_k_j`, `X_series_k_j`,
  and (when the capacitance is nonzero) `B_from_k_j`/`B_to_k_j`, plus `i_max` and the
  provenance fields
  ([`src/lineconstants/compile.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/src/lineconstants/compile.jl)).
- Concentric-neutral and tape-shield cables build their shield/strand conductors from
  the cable fields before the primitive assembly.
- The resulting linecode is consumed by the [line](line.md) model exactly as a
  hand-authored linecode; the geometry objects themselves never enter the OPF.

!!! note "Relationship to the Task Force PDF"
    The PDF's data model documents `linecode` (per-meter matrices) as the impedance
    source. The `wire_data`/`line_geometry` geometry layer and `compile_linecode` are a
    BMOPFTools construction convenience that *produces* those matrices; document the
    geometry inputs and the earth-return/Maxwell derivation in the superseding spec so
    geometry-sourced linecodes are reproducible.
