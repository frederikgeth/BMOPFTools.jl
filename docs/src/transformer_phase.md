# Transformer connections and effective phase relations

A nameplate such as "Dyn11" states a winding connection and a phase
displacement. In a conductor-level model the displacement is not a stored
attribute: it follows from the winding connection *and* from how the terminals
are wired to the buses. [`transformer_phase_relation`](@ref) derives it.

The report keeps four things apart:

1. the authored **winding connection** (wye, delta);
2. the external **terminal correspondence** (which bus terminal each winding
   terminal lands on);
3. the derived **effective phase relation** (the clock number);
4. any **declared nameplate text**, which is recorded and never trusted.

Terminal maps are executable data. Reporting never rewrites them to obtain a
preferred clock number.

```julia
relation = transformer_phase_relation(net, "delta_wye", transformer;
    phase_order=Dict("hv_bus" => ["red", "yellow", "blue"],
                     "lv_bus" => ["u", "v", "w"]))
relation["status"]       # known / partial / unknown / unsupported
relation["clock"]        # integer 0:11 only when known; otherwise nothing
relation["windings"]     # original maps, roles, correspondence, coil incidence
```

## Which terminals are phases A, B, C?

A clock number needs to know which terminals carry the nominal 0°, −120° and
+120° phasors. `phase_order` supplies that, per bus. It is an analysis
argument, not a case field.

Without it, only three complete label sets imply the conventional order:
numeric `1/2/3`, lowercase `a/b/c`, and uppercase `A/B/C`. The order of
`terminal_conventions.phase`, the order of a bus's terminals, and custom phase
labels never imply nominal angles.

Declared roles decide which terminal is a phase and which is a neutral,
including names such as `4`, `N0` and `return`. They do not imply a ground
bond.

## How the relation is derived

**Direction.** The default is winding 1 → winding 2 (`from` → `to` for a
two-bus subtype). `from_winding` and `to_winding` select any other pair,
including the reverse. In the result, the uppercase connection letter is the
*reference* side and the lowercase letter the *target* side. They do not mean
high and low voltage; windings are not reordered by voltage. With three or
more windings, the inventory holds separate winding-1 → winding-k relations
and the aggregate label has no single clock.

**Coil voltages.** The relation concerns ideal, balanced, three-phase winding
voltages with positive real turns ratios and taps. Loaded voltage drops are not part of
it. For a wye, coil `k` is the mapped phase voltage minus the identified
neutral (or the implicit zero reference). For a delta, it is the voltage of
mapped terminal `k` minus that of another terminal:

| Representation | Other delta terminal |
|:--|:--|
| `wye_delta` | `k+1`, cyclically |
| `delta_wye` | `k−1`, cyclically |
| `n_winding` | `k+delta_roll`, cyclically, with `delta_roll` exactly +1 or −1 |

Delta phase references use the balanced virtual neutral (zero mean), which
removes the arbitrary common-mode voltage.

**Clock.** For each paired coil, the ratio `u_reference[k] / u_target[k]` is
reduced to a pure rotation. All three coils must agree. The displacement is
the angle of that rotation and the clock is `−displacement/30° mod 12`.
Clock 0 is a valid result: a supported zero displacement, as for a Yy bank
with matching maps. Yy banks with permuted maps are evaluated the same way.

With default `a/b/c` maps, both `wye_delta` and `delta_wye` give a −30° target
displacement, clock 1. Three consequences follow:

- Reversing the direction negates the displacement and the clock.
- Cyclic external rewiring changes the effective clock.
- A relative reversal of two phases can destroy the uniform rotation, and the
  result is then `unsupported`.

Renaming terminals while supplying the matching `phase_order` leaves the
result unchanged.

!!! warning "Not a loop check"
    Matching labels on two transformers do not establish that they are
    equivalent or that their phase relations are compatible around a network
    loop. This report describes one transformer at a time.

## Statuses

| Status | Meaning |
|:--|:--|
| `known` | A complete three-phase Yy (`single_phase` bank), Yd, Dy, or wye/delta `n_winding` pair with one supported rotation |
| `partial` | The connections are described, but phase correspondence is absent, the map is not three-phase, or a multiwinding label has only pairwise evidence |
| `unknown` | References or roles are unresolved, maps are malformed or duplicated, the supplied phase correspondence is invalid, or a ratio is not positive real |
| `unsupported` | The phase relation is nonuniform, the delta roll or connection is unsupported, or the subtype has no three-phase clock (center-tap, regulators) |

All but `known` have `clock = nothing` and a `?` suffix in the display label.
A center-tap transformer with a valid polarity layout is reported as `Ii?`;
that is a statement about the clock concept, not a defect in the transformer.

Grounding, loaded voltage drops, tap feasibility, nameplate equivalence and
mesh behavior are outside this report.

## Declared nameplate text

`declared_vector_group` accepts a nameplate string from the caller, or keeps a
raw `vector_group` value already present in the dictionary. Its provenance is
`authored_unverified` and it never overrides the derived result. There is no
vector-group field in the external schema and no Finding code for these
statuses.

## Where the relation appears

- `inventory_analysis` keeps the string-keyed `by_vector_group` tallies and
  adds `phase_relations[subtype][id]` with provenance and pairwise evidence.
- `voltage_level_analysis` keeps the string `vector_group` on each voltage
  transition and adds a `phase_relation` record for that direction.
- Terminal and Markdown reports label the value as an *effective* relation.
  `render_ascii_tree` derives the label for the direction it traverses.
- `inventory_analysis`, `voltage_level_analysis` and `render_ascii_tree`
  accept the optional `phase_order` map. [`analyze`](@ref) uses the
  conventional label sets only; call the individual passes to supply your own
  correspondence.

!!! warning "Reading the string label"
    A suffix on a vector-group string is a nameplate clock only when the
    status is `known`. Letter labels do not default to clock zero, and
    single-phase and center-tap labels carry `?`.
