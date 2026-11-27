# Data model conventions

This page documents the BMOPF data-model conventions as implemented by
BMOPFTools, following the Task Force specification ([ref. 1](methodology.md#refs)) with the
implementation choices called out explicitly.

## Structure and identifiers

The network is a nested `Dict{String,Any}` with component collections at the
top level, each a dict of `id => component`:

| Group | Top-level keys |
|---|---|
| AC components | `bus`, `line`, `switch`, `transformer`, `voltage_source`, `load`, `generator`, `ibr`, `shunt`, `capacitor` |
| Shared catalogs | `linecode`, `wire_data`, `line_geometry`, `control_profile` |
| DC network | `dc_bus`, `dc_branch`, `dc_grounding`, `dc_load`, `dc_source` |
| Case-level blocks | `name`, `meta`, `terminal_conventions`, `time_series`, `extras` |

`transformer` is one level deeper: a dict of subtype (`single_phase`,
`delta_wye`, …) to `id => component`. `extras` is the parking slot a
schema-0.1.0 writer uses for fields that version has no home for;
`BMOPFTools.migrate` folds supported entries back onto their components (see the
[conversion guide](@ref from-dss-ingest)). IDs are **strings** and carry no
ordering semantics. Keys beginning with `_` (`_meta`, …) are tolerated
extension/bookkeeping fields and are never reported as schema violations.

## Units

All physical quantities are SI (spec Table 8):

| Quantity | Unit |
|---|---|
| voltage | V |
| current | A |
| length | m |
| active / reactive / apparent power | W / var / VA |
| resistance / reactance | Ω (lines: Ω/m) |
| conductance / susceptance | S (lines: S/m) |
| angle | rad |
| generation cost | \$/kWh |

Note that `from_dss` (via PowerIO) emits SI values directly — line lengths in
meters, linecodes per-meter, voltages in volts and powers in watts/vars — so no
further scaling is applied on ingest.

!!! note "Data-model units vs. solver units"
    SI here describes the **data model** — how networks are represented and
    serialized. It says nothing about the units a solver computes in: the
    reference OPF can solve directly in SI or in an internally-scaled per-unit
    copy and return SI results either way (see
    [Units & scaling](opf.md#Units-and-scaling)). The representation choice and
    the numerical-scaling choice are independent. The
    [units, bases & economics tutorial](tutorial_units.md) works both layers —
    and the cost units — on one feeder.

## Terminal names

Terminal identifiers are **strings**, and any label is legal: the
[`terminal_conventions`](#Terminal-role-conventions) block, not the spelling,
says which labels are phases and which are neutrals. These are the conventions
you will meet:

| Convention | Phases | Neutral | Where it comes from |
|---|---|---|---|
| Letter | `"a" "b" "c"` | `"n"` | [`from_dss`](@ref) output, and the examples in this documentation |
| Numeric with `n` | `"1" "2" "3"` | `"n"` | [`parse_bmopf`](@ref) coercing integer terminals `1,2,3,4` (see *Ingest normalization* below) |
| OpenDSS numeric | `"1" "2" "3"` | `"4"` | hand-authored or third-party files; `"4"` is a neutral **only if declared** |
| IEC 60445 | `"L1" "L2" "L3"` | `"N"` | hand-authored files |

[`from_dss`](@ref) additionally writes the reserved label `n_ref` for a
materialized OpenDSS node-0 return: a perfectly grounded device return that is
distinct from the conductor neutral `n` (see
[the earth terminal](@ref earth-terminal)).

### Terminal-role conventions

Because the label strings alone do not say which conductor is a phase and
which is the neutral, a case may declare the classification **once, for the
whole network**, in a top-level `terminal_conventions` block:

```json
"terminal_conventions": {
  "phase":   ["a", "b", "c"],
  "neutral": ["n"],
  "earth":   []
}
```

- All three lists are optional arrays of the label strings used across the
  case's AC buses. When the block is present it is **authoritative**: labels
  are matched exactly (including case), and ingestion, validation and the OPF
  resolve roles from it rather than guessing.
- `earth` names dedicated earth-/PE-**wire** terminals only. The ground
  *reference* stays implicit — grounding is still modeled via
  `perfectly_grounded_terminals` and grounding shunts — so `earth` is empty
  for standard cases. OpenDSS node 0 imports as a distinct perfectly
  grounded device return `n_ref`, separate from conductor neutral `n`.
- `dc_bus` is out of scope; it carries its own pole roles.
- The block is **always written** on export ([`write_bmopf`](@ref)): a case
  that never declared one gets the inferred classification promoted to an
  explicit block, so saved files are self-documenting. [`from_dss`](@ref)
  writes the used phase labels and return labels (`n` and/or `n_ref`) directly.

**When the block is absent**, roles are **inferred** from the label alone: a
terminal named `n`/`N`, or the reserved `n_ref`, is a neutral, and everything
else is a phase. A string `"4"` is therefore a *phase* unless the block declares
it a neutral; there is no positional rule. Validation raises
`W.CONV.TERMINAL_ROLES_INFERRED` to nudge you to make the classification
explicit. Inconsistent declarations raise `E.CONV.ROLE_OVERLAP`
(a label in two role lists), `W.CONV.TERMINAL_UNCLASSIFIED` (a bus terminal in
none — treated as a phase), or `W.CONV.MULTIPLE_NEUTRALS`.

`domain_rules_check(net, findings)["terminal_conventions"]` exposes a
deterministic inventory of declarations and authored AC terminal usage. It
covers bus `terminal_names`, `perfectly_grounded_terminals` and in-memory
`neutral_terminal` metadata; nodal load/generator/IBR/shunt/source/capacitor maps;
line/switch endpoints; and supported transformer endpoints and winding lists.
DC terminals and equipment catalogs are outside this inventory. `path` fields
are escaped JSON Pointers with zero-based array indices; semantic
`map_position` and `winding` fields use the package's one-based indices.

Each usage records its reference status. Unclassified terminals that exist on
a bus have one combined `W.CONV.TERMINAL_UNCLASSIFIED` Finding with their bus,
component and winding paths. Map-only labels are still inventoried, but an
unknown bus/terminal is owned by the integrity checks rather than generating a
second role warning. Grounding references use the same
`E.INT.UNKNOWN_TERMINAL` owner. Topology-specific role rules remain with the
[device](device_indexing.md) and [connection-map](connection_maps.md) checks;
label spelling and map permutations alone do not establish a role conflict.

`E.CONV.DECLARATION_INVALID` reports malformed explicit role lists without
substituting inferred roles. `E.CONV.BUS_ROLE_CONFLICT` reports an inconsistent
in-memory `neutral_terminal` assertion. Runtime role resolution, including
ingestion and writing, rejects malformed explicit declarations with
`ArgumentError` rather than guessing. Validation neither edits that metadata
nor changes the existing writer policy: `neutral_terminal` is stripped on write
and derived again from the exported conventions on read.

`I.CONV.UNUSED_LABEL` identifies declared labels with no authored usage anywhere
in the supported inventory. A label in `terminal_names` counts as used even if
the conductor is intentionally spare and has no connected device. Raw map
references also count as authored usage even when integrity rejects them. If
malformed/unsupported usage prevents a complete inventory, the report records
`unassessed_paths`, sets `status="indeterminate"`, and suppresses unused-label
conclusions (`unused_labels=null` rather than a false empty result).
`status="assessed"` means bookkeeping completed, not that the case
passed validation or has a sufficient electrical reference. `role_source`
distinguishes `declared`, `inferred`, and `invalid` declarations.
`resolved_roles` retains the shared resolver's classification, or is `null`
when the declaration/terminal shapes prevent resolution.
Valid explicit role lists can still be resolved when an unrelated bus is
malformed: declaration overlap and conflicts on valid buses remain reportable,
while inventory coverage stays indeterminate. Unknown-terminal errors require
a valid target bus terminal list; malformed target lists retain their schema
and unassessed-indexing diagnostics instead of speculative reference errors.

**Ingest normalization**: JSON files with non-string terminal entries (e.g.
`[1,2,3,4]`) are coerced by [`parse_bmopf`](@ref). If every numeric token is
covered by the alias table (default `1→"1", 2→"2", 3→"3", 4→"n"`,
overridable via `terminal_aliases`), the aliases apply; otherwise — the
profiling guard, e.g. a 5th conductor present — everything becomes its
verbatim decimal string. Coercion is recorded in
`_meta["terminal_coercions"]` (`mode` is `"aliases"` or `"verbatim-string"`)
and flagged as `W.SPEC.TERMINAL_TYPES`. The alias applies to non-string tokens
only: a terminal already stored as the string `"4"` is left alone. When the
case declares `terminal_conventions`, the default `4→"n"` rename is suppressed
so a *declared* neutral label like `"4"` survives verbatim.

### Device terminals: lining up phases and the neutral

Every connected device — `load`, `generator`, `ibr`, `voltage_source`,
`capacitor`, `shunt` — references named bus terminals through its
`terminal_map` (lines, switches and transformers use `terminal_map_from` /
`terminal_map_to`). A device map is a mix of **phase terminals** and, for
wye/four-leg wiring, **one neutral terminal** — classified by the same
`terminal_conventions`. This has a concrete consequence for the data:

> WYE/FOUR_LEG **phase-indexed arrays line up with the phase terminals of
> `terminal_map`, in map order, with the identified neutral excluded.** Other
> fields use their own [device indexing contracts](device_indexing.md).

So a WYE load on `terminal_map = ["a","b","c","n"]` has **three** phase
conductors, and `p_nom`/`q_nom` are length-3 vectors whose entries correspond
to `a`, `b`, `c` respectively; the `n` terminal is the return, not a fourth
element. Concretely:

| Element | Per-phase arrays | Length (WYE / FOUR_LEG) | Neutral entry |
|---|---|---|---|
| `load` | `p_nom`, `q_nom` | # phase terminals | — (return only) |
| `generator` | `p_min/p_max`, `q_min/q_max`, `s_max`, `cost` | # phase terminals | `i_max` may carry a trailing neutral entry (phases+1) |
| `ibr` | `p_min/p_max`, `q_min/q_max`, `s_max`, `cost` | # phase terminals (`THREE_LEG`: all terminals; `SINGLE_PHASE`: 1) | `i_max` may carry a trailing neutral entry |
| `voltage_source` | `p_min/p_max`, `q_min/q_max`, `cost` | # phase terminals in the map | Return only; voltage reference arrays instead index the full terminal map, with an already-grounded trailing suffix optionally omitted |

The neutral is singled out because currents on the phase conductors return
through it: the OPF writes each phase quantity across the phase-to-neutral
terminal pair, and (where rated) the neutral return current is bounded by the
extra trailing `i_max` entry. A `DELTA` map has no neutral — its arrays are
per phase-pair. A two-terminal `SINGLE_PHASE` device has one pair even when both
terminals are phases, and its orientation may be reversed. An identified WYE
neutral need not occupy the last map slot. Indexed-field shape mismatches use
`W.INT.DIM_MISMATCH`; `W.SPEC.CONFIG_ARITY` instead compares the terminal-map
length with the data-model configuration arity (see
[Validation findings](findings.md)). Making the phase/neutral split explicit
via `terminal_conventions` is what lets these checks be exact rather than
heuristic.

## Buses, bounds and grounding

A bus carries `terminal_names`, optionally `perfectly_grounded_terminals`,
and optional voltage-magnitude bounds in four flavors: phase-to-ground
(`v_min`/`v_max`), phase-to-neutral (`vpn_*`), phase-to-phase (`vpp_*`)
and sequence (`vpos_min`/`vpos_max`, plus the maximum-only `vneg_max` and
`vzero_max` on the negative- and zero-sequence magnitudes). `v_min`/`v_max` and `vpn_min`/`vpn_max` are
**per-phase arrays** (one element per phase terminal, in `terminal_names` order,
neutral excluded); `vpp_min`/`vpp_max` are **per-pair arrays** (one element per
unordered phase pair, in `(i<j)` order). A terminal declared as protective
earth in `terminal_conventions` is not a phase either: it has no entry in these
arrays, forms no phase pair, and is left out of the symmetrical-component
transform, so a bus with `a`, `b`, `c`, `n` and `pe` takes three per-phase
entries and three pairs. A scalar `v_min`/`v_max` is **rejected
at ingest** (`parse_bmopf`) — wrap it in an array of the phase count. The
neutral conductor has its own separate, optional, **maximum-only** bound
`vn_max` (scalar, neutral-to-ground), valid only when the bus has a neutral.
Absent bounds mean *unconstrained* (spec §4.1.5).

A bus may also bound the **angle difference between its phases** with the
scalars `va_diff_min`/`va_diff_max` (rad). They apply to every phase pair and
are centered on the nominal offset taken from the optional per-phase vector
`va_nom` (rad); without `va_nom` the offset is zero. A `line` accepts the same
`va_diff_min`/`va_diff_max` pair for the angle difference between its two ends.
See [the OPF bus model](opf.md) for the constraint form.

Grounding semantics (spec Table 10):

- **perfect grounding** is a bus property (`perfectly_grounded_terminals`);
- **grounding through an impedance** is a `shunt` whose terminal map
  references the neutral (e.g. `Y = [G_1_1 + jB_1_1]`, `N = ["n"]`);
- loads, generators, transformers and switches **never** connect directly
  to ground — only to bus terminals;
- voltage sources are defined voltage-to-ground and pin every terminal in
  their map (a source whose map includes the neutral references it to
  ground).

## Lines, linecodes and matrices

Lines carry only topology (`bus_from`/`bus_to`, terminal maps, `length`,
`linecode`); all impedance lives in the linecode as per-length matrices in
flattened row-first pattern keys: `R_series_1_2 ⇒ rs[1,2]` (Ω/m), likewise
`X_series_*`, and optional `G_from_*`/`G_to_*`/`B_from_*`/`B_to_*` (S/m)
for the two shunt half-sections of the Π model. Optional ratings: `i_max`
(A, per conductor) and `s_max` (VA, per conductor). Both are enforced natively
by the OPF when present; the binding one can change with voltage, so the pair is
not mathematically redundant, but declaring both is usually an engineering
duplication and current is the source of truth for conductors (see
[current vs. apparent-power limits](opf.md#Current-vs-apparent-power-limits)).

The spec defines full row-first storage; BMOPFTools also *reads*
upper-triangular shorthand (mirroring the missing transpose entries) and
reports it as `I.SPEC.MATRIX_TRIANGULAR`. It always *writes* all n²
entries.

Linecodes may optionally record their origin: `source` (free-form:
`"geometry"`, `"fem"`, `"datasheet"`, `"import"`, …), a `line_geometry`
back-reference, and a `derivation` block (method, earth resistivity,
frequency, defaults applied, tool + version). Two companion libraries hold
construction data in SI units — `wire_data` (conductor/cable types: Ω/m,
meters; `kind` ∈ `overhead`/`cn_cable`/`ts_cable`) and `line_geometry`
(wire placements at (x, y) meters, y < 0 = burial depth, each conductor
mapped to a terminal) — from which [`compile_linecode`](@ref) derives
linecodes. See the [line-geometry tutorial](tutorial_line_geometry.md).

**Absolute (total) impedances.** A line may instead carry its own matrices —
the same pattern keys directly on the line object — as **section totals**:
`R_series_i_j`/`X_series_i_j` in Ω, `G_*`/`B_*` in S. Units are unambiguous
*by location*: linecode matrices are per meter and scale with `length`;
inline line matrices are totals and are **never** scaled (a `length` on such
a line is purely descriptive). Every line has exactly one impedance source —
`linecode` + `length`, or inline matrices — enforced by the schema `oneOf`
and `E.INT.LINE_IMPEDANCE_SOURCE`. This is the sanctioned home for FEM
results, measured section impedances, and imports that previously abused
`length = 1`.

These three ways of recording a line's impedance — geometry, per-length
linecode, inline totals — form a deliberate **fidelity ladder**: prefer
geometry over a linecode-with-matrices, and a shared linecode over inline
totals, reaching for a lower rung only when the construction data genuinely
does not exist. The reasoning (realizability without solving inverse Carson,
recompilation at other frequencies for harmonics, better features for
learning, live provenance) is in [object identity](semantic_modeling.md#impedance-ladder).

### Units of the wire/geometry libraries

One unit per field, fixed by the schema — there are no unit-selector fields
and no rescaling anywhere in the package (contrast OpenDSS's per-object
`units` and base-frequency scaling). Convert at authoring time.

| Quantity | Unit | Notes |
|---|---|---|
| resistances `r_dc`, `r_ac`, `r_strand` | Ω/m | at `temperature_ref` |
| radii/diameters/thicknesses/coordinates | m | y < 0 = burial depth |
| currents `i_max`, `i_max_emergency` | A | |
| `earth_resistivity` | Ω·m | |
| `frequency` | Hz | **required** on `line_geometry`; no ambient default |
| `temperature`, `temperature_ref` | **°C** | deliberate SI exception — IEC 60228/60287 datasheet convention, matches the α₂₀ formulation |
| `alpha_20` | 1/K | temperature coefficient at 20 °C |
| `tape_lap` | **percent** (0–100) | deliberate exception — OpenDSS convention |
| `eps_r` | – | relative permittivity |

The one unit-mistake the schema cannot catch — an Ω/km value typed into an
Ω/m field — is caught by the implied-resistivity plausibility check
(`W.DOM.WIRE_IMPLIED_RESISTIVITY`; three decades outside the metallic range).

## Loads and generators

`configuration` ∈ `SINGLE_PHASE` (one terminal pair, between any two nodes),
`WYE` (phase terminals plus a neutral return) or `DELTA` (phase terminals
only). Setpoint vectors `p_nom`/`q_nom` have **one entry per sub-load**: one for
`SINGLE_PHASE`, one per phase terminal for `WYE`, one per cyclic coil for
`DELTA`. The data-model *conformance* arity is the three-phase one (4 terminals
for `WYE`, 3 for `DELTA`); a reduced-phase map with correctly sized arrays is
accepted by the solver and reported as `W.SPEC.CONFIG_ARITY`. The full indexing
rules are in [device parameter indexing](device_indexing.md). Note the spec
FAQ: a "wye" in the BMOPF sense always has the neutral return — a
2-terminal load is `SINGLE_PHASE`, not a degenerate wye.

**Voltage dependence.** A load's `model` field selects how its power follows
the sub-load voltage; `v_nom` (V) is the voltage at which it draws exactly
`p_nom`/`q_nom`:

| `model` | Extra fields | Notes |
|---|---|---|
| `constant_power` (default) | — | `v_nom` is not read |
| `constant_current`, `constant_impedance` | `v_nom` | |
| `zip` | `v_nom`; `alpha_z`, `alpha_i`, `alpha_p` (active) and `beta_z`, `beta_i`, `beta_p` (reactive) | coefficients are not required to sum to 1 (`W.LOAD.ZIP_SUM`) |
| `exponential` | `v_nom`; `gamma_p`, `gamma_q` | integer exponents are solved as the equivalent ZIP terms |

`v_nom` and the coefficients are scalars, length-one arrays, or one entry per
sub-load. The equations are in the [load specification](spec/load.md), and
[Choosing and identifying a load model](@ref load-models) covers when each
model is defensible.

Generators additionally carry `cost` and optional `p_min/p_max/q_min/q_max`.
`cost` is a **per-phase vector of energy prices** (\$/kWh), one element per
phase term. For a snapshot, the objective contribution of phase $k$ is the cost
rate $c_k \, P_k / 1000$ (\$/h), because $P_k$ is stored in watts. A multi-period
monetary objective must additionally multiply each rate by the period duration
in hours. (There is no polynomial/quadratic cost form.) A generator without
bounds is an unbounded
(slack-style) unit.

**Voltage source as slack.** The `voltage_source` fixes its terminal voltages
**and** acts as the network's current slack — it injects the current that closes
KCL at the source bus, so no auxiliary slack generator is needed. Beyond
`v_magnitude`/`v_angle`, it accepts an optional `configuration`, per-phase flow
bounds `p_min/p_max/q_min/q_max`, and a per-phase `cost`. The augmentation pass
sets `cost` on the source by default. See
[Voltage source as current slack](opf.md#source-slack). Placing an *unbounded*
generator at the source bus duplicates the slack and is flagged by the pre-flight
check (`W.PRE.SOURCE_BUS_GENERATOR`).

## IBRs (inverter-based resources)

An `ibr` models a PV array, battery, or generic converter (including STATCOMs)
interfaced through an inverter. Required fields are `bus`, `terminal_map`,
`topology` (`SINGLE_PHASE` / `THREE_LEG` / `FOUR_LEG`), `prime_mover` (`PV` /
`BATTERY` / `GENERIC` / `STATCOM` / `DSTATCOM`), and the per-phase apparent-power
rating `s_max` (VA). Optional fields include the available active power `p_avail`
(W), explicit flow bounds `p_min/p_max/q_min/q_max`, a per-phase `cost`, a
converter current limit `i_max` (A), and the shared-DC-link coupling
(`dc_link_coupled`, `p_dc_min/p_dc_max`). The filter and grid-forming fields
(`r_filter`, `x_filter` per phase, scalar `b_filter_shunt`, `grid_forming`,
`v_ref_internal`) are part of the data model and are shape-checked, but the
native OPF does not stamp a physical filter; `grid_forming = true` is read by
the integrity check that looks for a voltage reference in a DC-fed island. Bounds left
absent are filled by the augmentation pass. `i_max` is **per conductor** (like a
line's): for a `FOUR_LEG` IBR, one entry per phase plus a recommended trailing
entry capping the **neutral** return $-\sum_k I_k$ (which can exceed the phase
currents under unbalance compensation; a phases-only vector warns). A
`SINGLE_PHASE` IBR has one current, so `i_max` is length 1 or 2 (the two collapse
to a single limit; a length-1 vector is standardized to 2). Generators take the
same per-conductor `i_max` convention.

!!! note "Why both a `generator` and an `ibr` object?"
    Most distributed generation in an unbalanced LV study *is* inverter-based, so
    the reasonable question is why keep a separate `generator` at all. The two
    objects sit at different modeling altitudes:

    - **`generator`** is the *minimal* active-power dispatch object — `p_min/p_max`,
      reactive box `q_min/q_max`, and a per-phase linear `cost`. It is the right
      model for a synchronous/diesel unit, or wherever you want a dispatchable
      active-power injection *without* committing to converter physics (no
      apparent-power circle, no topology, no droop control).
    - **`ibr`** adds exactly that converter physics: an apparent-power nameplate
      `s_max` with the $P^2 + Q^2 \le (S^{\max})^2$ circle, a `topology`
      (`SINGLE_PHASE`/`THREE_LEG`/`FOUR_LEG`) that fixes the voltage reference, a
      `prime_mover`, and reference-able `control_profile` droop laws.

    Both are kept because benchmark cases span both, and because a thin
    `generator` avoids forcing the full converter model (and its extra variables)
    onto a resource that does not need it. For a PV, battery, STATCOM, or any
    converter-interfaced DER, prefer `ibr`; reach for `generator` for
    non-converter or deliberately abstract dispatch. The placement passes mirror
    this split: [`add_generators`](@ref) versus [`add_ibrs`](@ref).

IBR control laws are attached by reference: `control_profile` names a
shared [`control_profile`](#Control-profiles) entry carrying `volt_var`,
`volt_watt`, or `power_factor`. Each droop law's `voltage_reference` selects the
**monitored-voltage quantity and aggregation** (one of the six
`voltage_reference_type` values — phase-to-ground / phase-to-neutral /
phase-to-phase, per-phase or averaged). The optional IBR-level `voltage_aggregation`
field (`PER_PHASE` / `AVERAGE`) is a convenience that overrides only the
*aggregation* a control law implies, applied across all of that IBR's curves. See
[the OPF IBR model](opf.md#IBRs) for the full formulation.

## Control profiles

A `control_profile` is a **named, reusable bundle of IBR control laws**, shared by
IBRs the way a `linecode` is shared by lines: many `ibr` objects point at one
profile through their `control_profile` field. These are the **AC-side** laws —
they set a converter's active/reactive power from its *AC* terminal voltage (the
DC-port counterpart is configured separately; see below). Each profile holds one or
more optional sub-objects, and the *presence* of a sub-object activates that law:

- **`volt_var`** — reactive-power droop $Q = f(U)$. Fields: `breakpoints`
  `[U1,U2,U3,U4]` (V, non-decreasing); `q_limits` `[q_absorb, q_inject]`
  ($q_\text{absorb} \le 0 \le q_\text{inject}$);
  `q_unit` (`VA_FRACTION` of `s_max`, or `VAR`); `q_ref` (`VAR_MAX`, or
  `VAR_AVAILABLE` scaling with $\sqrt{(S^{\max})^2 - P^2}$); and `voltage_reference`.
  Optional `p_min_for_q` / `p_min_for_q_max` mirror OpenDSS's low-power cut-ins.
- **`volt_watt`** — active-power curtailment cap $P \le f(U)$. Fields: `breakpoints`
  `[U5,U6]`; `p_limits` `[p_low, p_high]`; `p_unit` (`VA_FRACTION` or `W`); `p_ref`
  (`S_MAX` / `P_MAX` / `P_AVAILABLE`); and `voltage_reference`.
- **`power_factor`** — constant power factor: a signed `pf` (positive = lagging,
  absorbing VAr; negative = leading, injecting VAr), coupling `Q` to `P` by an
  exact equality. Mutually exclusive with `volt_var` on the same IBR.

`voltage_reference` is one of the six `voltage_reference_type` values — the
monitored-voltage **quantity** (phase-to-ground `PG`, phase-to-neutral `PN`, or
phase-to-phase `PP`) crossed with **aggregation** (`_PER_PHASE` or `_AVERAGED`);
`volt_var` and `volt_watt` may each choose their own. Voltages are SI volts on the
monitored quantity (e.g. ≈230 V phase-to-neutral nominal).

The augmentation pass can fill a *declared-but-blank* sub-object from a regional
preset (e.g. AS/NZS 4777.2 "Aus_A"), so a study can pin individual breakpoints and
default the rest. The OPF currently implements `volt_var` with `q_unit =
VA_FRACTION` and `q_ref = VAR_MAX`; other variants warn and fall back to box
bounds. See [the OPF IBR model](opf.md#IBRs) for how each law is stamped as a
smooth constraint, and the [VVWO tutorial](tutorial_vvwo.md) for a worked example.

**DC-port control.** A converter's DC-side law is *also* an IBR control law, but it
acts on the **signed DC-port voltage** rather than an AC magnitude, so it lives on
the `ibr` directly via `dc_control` — not in a `control_profile`. Its `"droop"`
mode is a **power–voltage (V–P) droop** stamped as an equality
$P = P^\text{ref} + (v_\text{dc} - v_\text{dc}^\text{set})/k_\text{droop}$
(fields `dc_p_ref`, `dc_v_set`, `dc_droop`; saturated at the converter limits)
using the same smooth-ReLU machinery as `volt_var`/`volt_watt`. See the
[DC network](@ref dc-network) section's `dc_control`.

## Capacitors

A `capacitor` is a fixed shunt capacitor bank with fields `bus`, `terminal_map`,
`configuration` (`WYE` / `SINGLE_PHASE` / `DELTA`), `q_rated` (var) and `v_nom`
(V). It is a **constant susceptance** $B = Q^\text{rated}/(V^\text{nom})^2$
delivering the voltage-dependent reactive power $Q = B\,V^2$ (equal to the
nameplate `q_rated` only at `v_nom`). `q_rated` is a per-phase array for WYE, per-pair for DELTA, length 1
for SINGLE_PHASE; `v_nom` is phase-to-neutral (WYE/SINGLE_PHASE) or
line-to-line (DELTA). It is electrically a connection-aware `shunt` and adds **no
OPF variables** (fixed). A `shunt` remains the general constant-admittance
element (`G_i_j`/`B_i_j`, S); the `capacitor` adds nameplate and connection
semantics. Controllable/smooth capacitors are a future extension. See the
[conversion guide § Capacitor banks](@ref capacitor).

## [DC network (MVDC/LVDC) — terminals, poles, grounding](@id dc-network)

The DC side (`dc_bus`, `dc_branch`, `dc_grounding`, `dc_load`, `dc_source`) models
MVDC/LVDC converter stations. AC/DC converters are ordinary `ibr` objects that
carry a `dc_bus` reference and a `dc_terminal_map`; several converters sharing one
`dc_bus` form a converter station / back-to-back soft open point / MVDC tie.

**Signed voltage, no angle.** A DC terminal holds a single real `v_dc`, the
voltage **to earth** — positive pole `> 0`, negative pole `< 0`, metallic return
`≈ 0`. There is no DC angle. Line-to-ground bounds are `v_dc_min`/`v_dc_max`
(signed, per terminal); line-to-neutral (`vdc_ln_*`) and line-to-line (`vdc_ll_*`,
bipole only) are magnitude bounds.

**Bus arity.** `dc_bus.terminal_names` has length 1 (single pole, earth return),
2 (pole + return), or 3 (bipole: positive pole, negative pole, metallic return).

**Return-conductor recognition** (mirrors the AC neutral rule above): the DC
return / neutral is the terminal whose `pole` role is `METALLIC_RETURN`; failing
that, a terminal named `m` (metallic return) or `n`. This is what line-to-neutral
bounds are measured against.

**Grounding — perfect vs through impedance.** A `dc_grounding` (or a
`perfectly_grounded_terminals` entry on the `dc_bus`) sets the signed-voltage
reference and provides the earth-return path. `r = 0`/omitted is **perfect**
grounding (the terminal's `v_dc` is fixed to 0, with a free earth-return current);
`r > 0` is grounding **through impedance** (earth current $i = v_\text{dc}/r$,
with the electrode floating to the ground-potential rise $i\,r$). Every connected DC island
needs at least one grounding, else `E.INT.NO_DC_VOLTAGE_REFERENCE` fires.

**Converters are lossless** at this fidelity: a converter's DC-port power equals
its AC active power, so a back-to-back SOP conserves power exactly and an MVDC tie
loses only the $I^2 R$ of its DC line.

**DC-voltage control (`dc_control`).** Like an AC network needs a slack/reference,
an MVDC zone needs a converter that sets the DC voltage — otherwise `v_dc` is
underdetermined. Mirroring HVDC/MVDC practice (master–slave and droop):
- `"P"` (default) — constant power; the OPF dispatches the converter's power.
- `"V"` — DC-voltage **master**: holds the pole-to-return $v_\text{dc}$ at
  `dc_v_set` (a fixed setpoint, like an AC source's `v_magnitude`); its AC power
  floats to balance the zone. When `dc_v_set` is absent, the `dc_bus`'s
  `v_dc_nom` is used, in `"droop"` mode too.
- `"droop"` — **saturated** V–P droop: the AC power follows
  $P = P^\text{ref} + (v_\text{dc} - v_\text{dc}^\text{set})/k_\text{droop}$
  inside an optional `±dc_deadband`,
  and **clamps to the converter's power limits** outside the droop band (a
  piecewise-linear P–V curve, implemented with the smooth-ReLU machinery so it is
  Ipopt-friendly). Higher `dc_droop` = softer droop; `dc_droop → 0` is the stiff
  (constant-V) limit.

Every connected DC island must have ≥1 `"V"` or `"droop"` converter, else
`E.INT.DC_NO_VOLTAGE_CONTROL` fires. Line-to-neutral / line-to-line bounds require
`pole` roles to orient them (`E.DOM.DC_POLE_ROLE_REQUIRED`).

## Transformer subtypes

Seven subtypes, each its own sub-dict under `transformer`.  All impedance
fields are in SI units (Ω or S); `v_nom_*` in V; `s_rating` in VA. This section
is the field-level summary; [Transformer models](transformer_models.md) is the
model-level contract (conventions, approximations, nameplate cap) and
[Transformer equations in the OPF](opf_transformers.md) has the constraints.

| Subtype | map arity (from, to) | OPF model | impedance fields |
|---|---|---|---|
| `single_phase` | (2, 2) | Γ-equivalent, series Z referred to the from side | `r/x_series_from` (Ω), `r/x_series_to` (Ω), `g/b_no_load` (S) |
| `center_tap` | (2, 3) | coupled-coil 3-winding (OpenDSS-consistent primitive admittance) | same field names — see note below |
| `wye_delta` | (4, 3) | per-winding T behind ideal Yd transform | `r/x_series_from` (wye), `r/x_series_to` (delta), `g/b_no_load` (S) |
| `delta_wye` | (3, 4) | per-winding T behind ideal Dy transform | `r/x_series_from` (delta), `r/x_series_to` (wye), `g/b_no_load` (S) |
| `single_phase_autotransformer` | (2, 2) | step voltage regulator: YY core at fixed-tap effective ratio `n_eff`, **shared neutral** | `r/x_series_from`, `r/x_series_to`, `g/b_no_load`; ratio from `tap_ratio` + `regulator_type` |
| `open_delta_regulator` | (4, 4) | monolithic open-delta: two line-to-line regulating windings + galvanic straight-through | per-regulator `r/x_series_*`; `connection`, `tap_ratio` (len 2), `regulator_type` |
| `n_winding` | winding list (no `bus_from`/`bus_to`) | ZB short-circuit matrix referred to winding 1, WYE and/or DELTA windings | per-winding `r_winding` (Ω), pairwise `x_sc["i_j"]` (Ω), `g/b_no_load` (S) |

The arities are the data-model conformance values for the full three-phase
shape; reduced-phase maps are covered by the
[connection-map rules](connection_maps.md).

Fields shared across subtypes, beyond the impedances:

| Field | Subtypes | Meaning |
|---|---|---|
| `tap` | `single_phase`, `center_tap`, `wye_delta`, `delta_wye` | Multiplier on the nominal ratio, `N = (v_nom_from / v_nom_to) · tap`; default 1.0 |
| `tap_min`, `tap_max` | same | With `tap_min < tap_max` the tap becomes a continuous OPF variable |
| `tap_ratio`, `tap_ratio_min`, `tap_ratio_max` | the two regulator subtypes | Regulator ratio and its optional optimization bounds |
| `i_max_from`, `i_max_to` | all two-bus subtypes | Winding current limits (A) |
| `r_neutral_from`, `x_neutral_from`, `r_neutral_to`, `x_neutral_to` | `single_phase`, `wye_delta`, `delta_wye` | Impedance from a winding's neutral point to earth (OpenDSS `rneut`/`xneut`), Ω |
| `no_load_shunt` | all | Explicit core branch `{winding, g, b}`, per coil in S; the preferred form for new data, and mutually exclusive with `g/b_no_load` on one unit |
| `s_rating` | all | Nameplate (VA): the impedance base, and for two-bus subtypes a loading cap (see [the nameplate cap](@ref transformer-nameplate-cap)) |

**No-load (core) branch.** For the isolating subtypes the legacy
`g_no_load`/`b_no_load` branch sits across **winding 2** (the to side), on that
winding's coil voltage, matching OpenDSS; it is not a from-side phase-to-ground
shunt. What the stored number means (a bank total or a per-coil value) depends
on the subtype. Both are tabulated in
[Magnetizing-shunt placement](@ref Magnetising-shunt-placement).

**`single_phase`**: the series impedance $R = R_1 + N^2 R_2$, $X = X_1 + N^2 X_2$
is lumped onto the from side (Γ convention).  `r_series_from`/`x_series_from`
are the from-winding values (Ω on the from-side voltage base);
`r_series_to`/`x_series_to` are the to-winding values (Ω on the to-side voltage
base).

**`center_tap`**: `terminal_map_from = ["a","n"]` (HV phase + neutral, or a
phase pair), `terminal_map_to = ["a","n","b"]` (leg 1, center-tap neutral,
leg 2; the order is positional).
`v_nom_to` is the **per-leg** voltage (e.g. 120 V, not 240 V).
The OPF models it as a genuine coupled-coil 3-winding transformer: the two LV
half-windings are series-aiding about the center tap (winding 3 dotted at the
center tap, span $V_g-V_c$) and the OPF imposes the same 5×5 primitive admittance
the Ybus exporter builds. This captures the mutual coupling between the
half-windings — a per-leg *decoupled* drop spreads the legs apart under load —
and matches OpenDSS's transformer `Yprim` to machine precision. Unbalanced
loading correctly produces different voltages on the two legs.

!!! warning "Leakage from OpenDSS XHL/XLT/XHT"
    For `center_tap`, `x_series_from`/`x_series_to` are the **star-network**
    leakage values, not `XHL/2` — the OpenDSS pair-wise values must be converted
    via the Steinmetz star formula. Using the 2-winding shortcut (e.g. all of
    `XHL` on the HV side, `x_series_to = 0`) drops the LV-side leakage and spreads
    the leg voltages apart under load. PowerIO's BMOPF export carries the
    correct star split, so [`from_dss`](@ref) needs no conversion; the formulas
    matter for hand-built cases. See
    [Conversion guide § Transformer impedance bases](conversion.md#Transformer-impedance-bases)
    for the exact formulas.

**`wye_delta`/`delta_wye`**: a per-winding T-model behind the ideal Yd/Dy
transform, matching the OpenDSS / PMD reference loss network.  Each winding
carries its own series impedance (`r/x_series_from`, `r/x_series_to`).
`v_nom_from` and `v_nom_to` enter only through their ratio, so give both on the
**same basis**: the two line-to-line nameplate voltages (`11000` and `415`, as
[`from_dss`](@ref) writes them) or the two phase-to-neutral equivalents. The √3
introduced by the delta connection is applied inside the model, in the
effective turns ratio `n_eff`.  The older single `r_series`/`x_series` (a
wye-referred lump, delta winding ideal) is accepted as legacy shorthand and
migrated onto the **wye** winding's fields (`_from` for `wye_delta`, `_to` for
`delta_wye`) with the delta side zero — see
[Transformer impedance on ingest](conversion.md#Transformer-impedance-on-ingest).

**`single_phase_autotransformer`**: a single-phase step voltage regulator
modeled as an autotransformer (series + common winding sharing a node), so the
from and to sides are galvanically tied — not isolated.  The ratio is the
**fixed** `tap_ratio` $a$ (regulated/source); `regulator_type` selects the ANSI
connection, giving the effective from→to ratio $n_\text{eff}=1/a$ (Type B,
default) or $n_\text{eff}=a$ (Type A).  The OPF voltage/current constraints are
the `single_phase` YY form with $N:=n_\text{eff}$, plus a **shared-neutral KCL**
($I_n + I_\text{series} + I_\text{to}=0$) that closes the common-winding return.
`v_nom_*` are not used (the ratio is `tap_ratio`); per-unit propagates the same
base across the galvanic tie (no voltage-level change).

**`open_delta_regulator`**: a monolithic three-phase open-delta regulator — two
single-phase autotransformer windings connected line-to-line across the phase
pairs implied by `connection` (`ABBC`/`BCAC`/`CABA`, GridLAB-D convention),
with per-regulator taps `tap_ratio = [a1, a2]`.  The phase common to both
regulators is a **galvanic straight-through**
($V^\text{shared}_\text{from} = V^\text{shared}_\text{to}$),
the physically-correct "common neutral" model of Yan et al. (2018); the two
regulated line-to-line voltages are boosted by their taps while the shared phase
passes through unchanged.  See the [OPF reference](opf.md) and
[Transformer primitive admittance](spec/transformer-admittance.md).

**`n_winding`**: a general n-winding transformer, typically for three or more
galvanically isolated voltage levels (e.g. an HV→MV→LV substation, or a
dual-secondary unit).  Unlike the two-bus subtypes it is a **winding-indexed
list** (`windings = [{bus, terminal_map, v_nom, configuration, r_winding}, …]`;
the earlier key names `connection` and `v_ref` are renamed on parse by
`BMOPFTools.migrate`, but a dict built in memory must use the current names)
with inter-winding leakage stored as **pairwise short-circuit reactances**
`x_sc["i_j"]` (referred to winding 1).  The leakage is the OpenDSS-style **ZB
matrix** referred to winding 1 ($ZB[i,i]=Z_{1,i+1}$,
$ZB[i,j]=\tfrac12(Z_{1,i+1}+Z_{1,j+1}-Z_{i+1,j+1})$), which is **exact for any
$n$** — it has $n(n-1)/2$ entries and reconstructs every pairwise reactance (for
$n\le 3$ it coincides with the star/T model).  The OPF references winding 1
($V_1^r - V_{i+1}^r = -\sum_j ZB[i,j] I_{j+1}^r$, ideal core
$\sum_k N_k I_k = 0$, $N_k = v_\text{nom}[k]/v_\text{nom}[1]$), so no internal
star node is required; a ZB entry **may be negative** for $n\ge 3$ (physical).
Each isolated winding is its **own galvanic zone** (n_winding is treated as
isolating, like the other non-regulator subtypes — see the connectivity pass in
[Analysis & reports](analysis.md)).  A winding's `configuration` is `WYE`
**or** `DELTA`: a wye winding's `v_nom` is its line-to-neutral coil voltage, a
delta winding's is its line-to-line coil voltage, and `delta_roll` (`+1`, the
default, or `-1`, OpenDSS's standard delta) selects the vector-group rotation.
Each winding may carry its own scalar `s_max` (VA) and `i_max` (A) limits; the
top-level `s_rating` is the impedance base and does not cap loading on its own.
No tap field is accepted on an `n_winding` unit or its windings.  This is a **fully independent code path** from the
two-bus subtypes, validated against OpenDSS's own 3- and 4-winding solves
(including delta `Dyn`/`Dyyn`).  See the
[conversion guide § n-winding transformers](@ref n-winding).

For a three-phase wye-wye unit you therefore have two options: an `n_winding`
transformer with two wye windings, or three `single_phase` transformers.  The
converter currently parks PowerIO's three-phase wye-wye output in `single_phase`
with 3-phase terminal maps and the conformance check flags the arity
(`W.SPEC.XFMR_TMAP_ARITY`) — see the [conversion guide](conversion.md).

## Switches

### Scope: what the `switch` object represents

The `switch` is the data model's element for **any section of negligible series
impedance** — a per-conductor short between two buses that either carries current
with no voltage drop (closed) or carries none (open). It is an *idealized,
lossless* two-bus element: there is no `linecode`, no `length`, and no `R`/`X`
(contrast [Lines](#Lines,-linecodes-and-matrices)). Its fields are the two
endpoints and terminal maps, the `open_switch` flag, and optional per-conductor
ratings `i_max` (A) and `s_max` (VA). The closed switch imposes
$v_{b^\text{fr}} = v_{b^\text{to}}$ on every conductor in its terminal map and
the open switch fixes its currents to zero (see
[the OPF switch model](opf.md#Switches)).

A single object therefore covers a family of physical devices that, for
steady-state OPF, all reduce to the same idealization. The intended scope:

| Physical device | Why it maps to `switch` |
|---|---|
| **Disconnector / isolator** | Manually-operated open/close point; impedance negligible when closed. |
| **Load-break switch / sectionaliser** | Field switching point for reconfiguration; lossless when closed. |
| **Circuit breaker** | The *conducting path* is lossless; protection/trip logic is out of scope for steady-state OPF. |
| **Recloser** | As above — a breaker with reclosing control; only its open/closed conduction state matters here. |
| **Tie switch** | Normally-open reconfiguration link between feeders. |
| **Busbar section / jumper / bus-tie** | A near-zero-impedance metallic connection between nodes; an explicit object instead of merging the buses. |
| **Near-zero-impedance line** | A line whose $\|Z\|$ is below the conditioning threshold is reported as `W.DOM.LINE_LOW_IMPEDANCE`; the opt-in [`fix_case`](@ref) pass `apply_low_impedance_to_switch` (off by default) converts it to a closed switch ([ref. 2](methodology.md#refs)). |

What it is **not**: a switch never carries impedance, losses, shunt admittance,
tap or phase-shift (use a `line`, `shunt`, or `transformer`); it never connects
to ground (only to bus terminals, like lines); and its `open_switch` flag is a
*data* state, not a control law — there is no protection, fault, or
time-sequence model. Reliability/protection studies that need trip curves and
reclose sequences are out of scope for the steady-state benchmark.

### Why a dedicated element (rather than zero-impedance lines or bus merging)

Inserting a zero- or near-zero-impedance branch into an admittance (bus-injection)
formulation produces an infinite entry in **Y** and an ill-conditioned or
rank-deficient system; the classic remedies are either *bus merging* (contract
the branch and fuse its endpoints into a "super bus") or special zero-impedance
branch handling [ref. 2](methodology.md#refs). The branch-flow / current–voltage
formulation used here sidesteps this: a closed switch is expressed as an exact
voltage-equality constraint with explicit current variables, so it is represented
without an admittance and without losing the two distinct buses (and their
bounds, names and attached devices). Keeping the section as a first-class object
— rather than silently merging buses — preserves topology, lets the open/closed
state be toggled for reconfiguration studies, and keeps current results
addressable per switch (see [`switch` currents](results.md#switch-—-switch-currents)).
When exporting to a tool that *requires* an admittance representation, the switch
can be projected the other way — onto a small-impedance line — at the boundary
(this is exactly OpenDSS's 1 mΩ `Switch=yes` line, below).

### Terminology in other tools and standards

The same "lossless conducting section" concept appears across the field under a
range of names:

- **OpenDSS** has no separate switch *element*: a `Line` with `Switch=yes`
  becomes a 1 mΩ line that protection control elements (`Fuse`, `Relay`,
  `Recloser`) open and close on a terminal. So in OpenDSS the conduction path and
  the control are deliberately split — the line is the switchable section, the
  control element is the logic. The BMOPF `switch` corresponds to the
  *switchable line*, not the controller.
- **PowerModels / PowerModelsDistribution** define an explicit `switch`
  component with a discrete `state` ∈ {`OPEN`, `CLOSED`}; closed enforces equal
  voltages across the two buses, open blocks flow. A switch with no `rs`/`xs`/
  linecode is *ideal* (lossless); lossy parameters trigger a decomposition into a
  virtual branch + bus + ideal switch. BMOPF's `open_switch` boolean maps
  directly onto PMD `state` (`0`=OPEN, `1`=CLOSED) — see
  [`to_pmd`](api.md) — and the BMOPF switch is always the ideal, lossless case.
- **CIM (IEC 61970-301)** models this as a `Switch` class with `open` /
  `normalOpen` / `ratedCurrent` attributes, specialized into `ProtectedSwitch`
  (→ `Breaker`, `Recloser`, `LoadBreakSwitch`), `Disconnector`,
  `GroundDisconnector` and `Sectionaliser`, with `Jumper` and `BusbarSection` as
  related connectivity elements. BMOPF deliberately collapses this whole taxonomy
  into one object: the device *subtype* (breaker vs. disconnector vs. busbar) is
  not represented because it does not change the steady-state equations.
- **General power-flow literature** calls these **zero-impedance branches**
  (ZIB) or zero-impedance lines, and discusses the super-bus / branch-contraction
  treatment they require in admittance formulations [ref. 2](methodology.md#refs).

The takeaway: most tools either (a) reuse a line with a flag (OpenDSS) or (b)
provide a dedicated ideal switch with an open/closed state (PMD, CIM). BMOPF
follows (b), with a single lossless `switch` object whose `open_switch` boolean
is the open/closed state, and intentionally abstracts away the device-class
distinctions (breaker / recloser / disconnector / busbar / tie) that CIM
enumerates, since they are immaterial to a steady-state OPF.

## Metadata blocks

The network dict carries two distinct metadata containers: `meta`, the
spec-level block an author fills in, and `_meta`, the bookkeeping BMOPFTools
keeps while it parses, converts and migrates a case.

### `meta` — spec-level, written to JSON

`net["meta"]` is a flat `Dict{String,Any}` included verbatim in the JSON
output by [`write_bmopf`](@ref).  All fields are optional.  Unknown fields
are allowed (an `I.SCHEMA.UNKNOWN_FIELDS` info finding is raised, not an
error) so callers can add project-specific keys freely.

| Field | Type | Description |
|---|---|---|
| `$schema` | String (URI) | Schema URI for version detection and forward migration. Auto-filled by `write_bmopf`. |
| `title` | String | Human-readable name for this dataset / case. |
| `description` | String | Free-text description. |
| `version` | String | Dataset version (any string; semver recommended). |
| `created` | String | ISO 8601 datetime when the file was first created (e.g. `"2024-06-19T14:32:00Z"`). Auto-filled on first write. |
| `modified` | String | ISO 8601 datetime of most recent edit. Not auto-filled; set explicitly when updating a file. |
| `license` | String | SPDX identifier (e.g. `"CC-BY-4.0"`) or full URI. |
| `frequency` | Number (Hz) | Nominal system frequency. Check-only: it is compared with `line_geometry` and linecode derivation frequencies (`W.DOM.FREQUENCY_MISMATCH`) and never rescales an impedance. [`from_dss`](@ref) fills it from the OpenDSS base frequency. |
| `provenance` | Object | Tool bookkeeping: the persisted copy of `_meta` (see below). Caller-set keys win over tool-written ones. |
| `authors` | Array of objects | List of contributors; each object may have `name`, `email`, `orcid`. |
| `data_sources` | Array of objects | Origin datasets; each object may have `name`, `url`, `format`, `doi`, `version`. |
| `case_study_generator` | Object | Tool provenance: `{"tool": "BMOPFTools.jl", "version": "x.y.z"}`. Auto-filled by `write_bmopf`. |

**Auto-generation on write.** [`write_bmopf`](@ref) always emits a `meta`
block.  It merges fields in priority order: the `meta` keyword argument
→ `net["meta"]` → auto-generated defaults.  Auto-generation fills three
fields if they are absent: `$schema`, `case_study_generator`, and `created`.
Caller-supplied values are never overwritten.

**On parse.** [`parse_bmopf`](@ref) and [`from_dss`](@ref)
carry `net["meta"]` through unchanged.  [`BMOPFTools.migrate`](@ref) reads
`meta.$schema` to detect the spec version and apply forward migrations.
The schema checker validates known fields and flags format violations as
warnings (`W.SCHEMA.META_*`).

**Example** (passed to `write_bmopf` via the `meta` kwarg):

```julia
write_bmopf(net, "lv_feeder1.json";
    meta = Dict(
        "title"       => "LV network 1, Feeder 1",
        "description" => "ENWL LV test feeder, unbalanced residential load",
        "license"     => "https://creativecommons.org/licenses/by/4.0/",
        "authors"     => [Dict("name" => "Frederik Geth",
                               "orcid" => "0000-0001-9534-2265")],
        "data_sources" => [Dict("name" => "ENWL dataset",
                               "format" => "OpenDSS",
                               "url"    => "https://www.enwl.co.uk/")],
    ))
```

### [`_meta` — tool bookkeeping, persisted under `meta.provenance`](@id _meta-—-tool-private,-never-serialised)

`net["_meta"]` is a `Dict{String,Any}` used by BMOPFTools for traceability. It
is not part of the spec and is never reported as a schema violation. The key
`_meta` itself is not written to JSON; instead [`write_bmopf`](@ref) saves its
contents (all keys except the per-parse stamp `parsed_at`) under
`meta.provenance`, and [`parse_bmopf`](@ref) restores them into `_meta` on
read. Import diagnostics, ground-reference records and migration notes
therefore survive a save/load round trip. Its contents are informational;
downstream code should treat them as advisory.

| Key | Set by | Contents |
|---|---|---|
| `parsed_at` | [`parse_bmopf`](@ref) | Timestamp when the JSON was parsed. Stamped only when the parsed dict has no `_meta` yet, so it is absent on `from_dss` output; never persisted. |
| `terminal_coercions` | [`parse_bmopf`](@ref) | `{"n": <count>, "mode": "aliases" or "verbatim-string"}` — populated when non-string terminal IDs were normalized. See `W.SPEC.TERMINAL_TYPES`. |
| `powerio_source` | `from_dss` | Absolute path of the `.dss` file that was converted. |
| `powerio_warnings` | `from_dss` | Array of `CODE: message` lines, one per diagnostic the DSS→JSON converter emitted, verbatim and ungrouped. |
| `powerio_diagnostics` | `from_dss` | The same diagnostics folded to one record per `(code, severity, component type)` class, each with its count, element paths and example messages. [`powerio_findings`](@ref) reads these back as `Finding`s and [`analyze`](@ref) reports them. |
| `powerio_diagnostic_details` | `from_dss` | The structured upstream diagnostic records behind the rendered warning lines. |
| `powerio_source_mapping`, `powerio_source_mapped_fields` | `from_dss` | The [source field ledger](@ref source-field-ledger): which OpenDSS fields were and were not carried over. |
| `powerio_source_metadata` | `from_dss` | Source-level facts PowerIO reports about the parsed deck. |
| `powerio_source_semantics` | `from_dss` | Source semantics with no BMOPF field, such as load voltage-validity thresholds and authored transformer `leadlag`. |
| `powerio_intake_repairs` | `from_dss` | Repairs applied on intake (for example the multi-winding `%R` base); present only when one was applied. |
| `opendss_ground_references` | `from_dss` | Per-bus record of materialized OpenDSS node-0 returns (`n_ref`). See [the earth terminal](@ref earth-terminal). |
| `explicit_transformer_core_shunts` | [`parse_bmopf`](@ref), `from_dss` | For each transformer whose `no_load_shunt` was materialized as a bus shunt: the owning transformer, the shunt id and the source values. |
| `frequency_source` | `from_dss` | `"powerio"` when `meta.frequency` was captured from the parsed OpenDSS base frequency, or `"override"` when the `frequency=` keyword supplied it. |
| `frequency_powerio` | `from_dss` | The parsed base frequency, recorded only when a `frequency=` override differs from it. |
| `migration_notes` | [`BMOPFTools.migrate`](@ref) | Array of `W.MIGRATE.*` finding dicts (one per transformation applied, for example `W.MIGRATE.FIELD_RENAMES`) appended when a forward migration is applied. |

## Time series (extension)

`time_series` at the root plus component-level `time_series` reference
dicts follow the PMD convention (values are multiplicative scale factors on
the static value). This is a BMOPFTools extension beyond the static-only TF
spec; [`get_snapshot`](@ref) materializes a snapshot at a given index and
[`analyze`](@ref) does this automatically.

## Branch and winding map validation

[Connection-map rules](connection_maps.md) document position-wise phase/neutral
continuity for lines/switches and subtype-specific transformer winding domains.
Phase permutations and neutral-only metallic links remain valid. Winding maps
are checked independently of grounding/reference requirements; there is no
universal through-neutral rule across transformers.
