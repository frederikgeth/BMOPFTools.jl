# Transformer connections and effective phase relations

A transformer report separates four meanings: the authored winding connection,
external terminal correspondence, the derived effective phase relation, and any
unverified declared nameplate text. Terminal maps are executable data. Reporting
never rewrites them to obtain a preferred clock number.

```julia
relation = transformer_phase_relation(net, "delta_wye", transformer;
    phase_order=Dict("hv_bus" => ["red", "yellow", "blue"],
                     "lv_bus" => ["u", "v", "w"]))
relation["status"]       # known / partial / unknown / unsupported
relation["clock"]        # integer 0:11 only when known; otherwise nothing
relation["windings"]     # original maps, roles, correspondence, coil incidence
```

`phase_order` supplies corresponding nominal phases at 0°, −120°, +120° by bus.
It is an explicit analysis argument, not a new case-schema field. Without it,
only complete numeric `1/2/3`, lowercase `a/b/c`, or uppercase `A/B/C` label sets
supply that conventional order. The order of `terminal_conventions.phase`, bus
terminals or an arbitrary custom phase label never supplies nominal angles.
Declared roles determine phase versus neutral accessibility, including names such
as `4`, `N0` and `return`; they do not imply a ground bond.

## Orientation and derivation

The default direction is authored winding 1 → winding 2 (`from` → `to` for a
two-bus subtype). `from_winding` and `to_winding` may select any original winding
pair, including reverse traversal. Uppercase connection letters identify the
**reference** side, lowercase the **target** side. They do not claim HV → LV;
the code does not reorder windings by voltage. For three or more windings,
inventory carries separate winding-1 → winding-k relations, and its aggregate
string has no single clock designation.

The relation concerns ideal balanced three-phase winding voltages with positive
real turns ratios/taps, not loaded terminal voltage drops. Delta phase references use the balanced
virtual neutral (zero mean); its arbitrary common-mode voltage is excluded.
For WYE, coil k is the
mapped phase voltage minus the identified neutral (or the existing implicit zero
reference). For DELTA it is the mapped terminal k voltage minus the other terminal:

| Representation | Other delta position |
|:--|:--|
| `wye_delta` | k+1 cyclically |
| `delta_wye` | k−1 cyclically |
| `n_winding` | k+`delta_roll` cyclically, with roll exactly +1 or −1 |

For each paired coil, the derivation compares the prescribed nominal phasors
`u_reference[k] / u_target[k]` after removing positive magnitude. All three must
agree on one rotation. The target displacement is the angle of that rotation;
clock is `−displacement/30° mod 12`. Zero means a supported zero displacement.
For the default a/b/c maps, both Yd and Dy have a −30° target displacement under
their respective executable delta orientations (clock 1). Reversing traversal
negates the displacement/clock. Cyclic external rewiring can change the effective
clock; a relative reversal can destroy a uniform positive-sequence relation.
Equivalent renaming with explicit correspondence leaves the result unchanged.

Matching labels do not establish equivalent equipment or compatible phase
relations around a network loop. Loop compatibility requires a separate
assessment; this report describes each transformer's represented phase relation.

## Domain and statuses

| Status | Meaning |
|:--|:--|
| `known` | Complete three-phase Yy (`single_phase` bank), Yd, Dy, or WYE/DELTA n-winding pair with one supported clock rotation |
| `partial` | Connections are described, but phase correspondence is absent, the map is not three-phase, or an aggregate multiwinding label has only pairwise evidence |
| `unknown` | Required references/roles are unresolved, maps are malformed/duplicated, an explicit phase correspondence is invalid, or a supplied ratio/base is not positive real |
| `unsupported` | Nonuniform phase relation, unsupported delta roll/connection, or a subtype without this three-phase clock interpretation (center-tap and regulators) |

The latter three statuses have `clock = nothing` and a `?` display suffix. A
center-tap may have a fully valid positional polarity layout yet no single
three-phase clock (`Ii?`). This is not an invalid-transformer Finding. The
native n-winding solver's existing a/b/c/n label restriction is unchanged;
static declared-role evidence does not promise solver support for custom labels.
Grounding, loaded drops, tap feasibility, nameplate equivalence and mesh behavior
are explicitly unassessed. Numeric winding data are retained/checked only as
needed for this descriptive domain, not normalized or converted by reporting.

`declared_vector_group` accepts a caller-supplied nameplate declaration (or retains
an existing raw `vector_group` value if supplied in the dictionary). Its provenance
is `authored_unverified`; it never overrides the derived result. No generic
vector-group field is added to the external schema, and no new execution adapter
or Finding code is introduced for these descriptive statuses.

## Consumer compatibility and migration

- Inventory retains string-keyed `by_vector_group` tallies and adds
  `phase_relations[subtype][id]` with structured provenance and pairwise evidence.
- Voltage transitions retain their string `vector_group` field and add a
  `phase_relation` record for that exact direction/pair.
- Terminal and Markdown transitions identify the label as an *effective* relation.
  ASCII trees derive the label for the actual traversal direction, including
  winding-list edges, and show the referenced bus arrow.
- `inventory_analysis`, `voltage_level_analysis` and `render_ascii_tree` accept
  the same optional `phase_order` map. Ordinary `analyze` uses the conventional
  label domain; use the standalone passes for caller-supplied correspondence.

Consumers must stop treating every string suffix as a nameplate clock. Letter
labels no longer fall back to zero, declared neutral names retain accessibility,
Yy permutations are evaluated, and unsupported single-phase/center-tap labels no
longer assert clock zero. The context-free private `_derive_vector_group` wrapper
returns an incomplete label; network-aware consumers use the structured API.

Tests use independent prescribed-phasor primitive solves over all six phase-map
permutations on both sides, source-angle rotations and taps, plus native SI and
per-unit phasor checks. They preserve authored maps and verify JSON evidence and
unknown states without mutating the network. The existing source-angle tagging
test retains invariance checks and replaces its unjustified center-tap `Ii0`
expectation with `Ii?` and an explicit unsupported-status assertion.
