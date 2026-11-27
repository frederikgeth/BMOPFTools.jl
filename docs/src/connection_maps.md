# Branch and winding connection maps

Lines, switches and transformers attach to buses through terminal maps. This
page states which maps are valid for each element. `integrity_check` verifies
the references and shapes; `spec_conformance_check` verifies the conductor
roles. Neither pass repairs, reorders or truncates a map.

!!! note "What these checks do not establish"
    A valid map does not show that grounding is adequate or that two models
    are electrically equivalent.

## The two questions

1. **Does each endpoint exist and have a usable shape?** Unknown buses and
   terminals raise `E.INT.UNKNOWN_BUS` and `E.INT.UNKNOWN_TERMINAL`. Entries that
   are not objects, missing or non-string bus identifiers, and empty or
   malformed maps raise `E.INT.CONNECTION_SHAPE`. Duplicate terminals within
   one map have their own diagnostic. The evidence names the endpoint or the winding
   index.
2. **Do the conductor roles at each position make sense for this element?**
   The answer depends on the element, as the table shows.

## Rules by element

| Element | Endpoints | Rule |
|:--|:--|:--|
| Line | `bus_from/to`, `terminal_map_from/to` | Both maps and the impedance matrix agree in size. Position `k` connects conductors of the same role |
| Switch, open or closed | same | Equal map lengths; the same role at each position |
| `single_phase` | both | Matching positive coil counts. With a neutral in the map, coils are phase-to-neutral; a neutral-free two-terminal map is one phase pair; other phase-only maps are implicit-reference coils |
| `center_tap` | both | HV is `[phase, neutral]` or a phase pair. LV is `[phase, neutral, phase]` in leg-1, midpoint, leg-2 order |
| `wye_delta`, `delta_wye` | both | The wye side's phase order excludes its neutral, wherever it sits. The delta side contains only phases. Wye phase count equals delta coil count, at least two |
| `single_phase_autotransformer` | both | Exactly one regulating coil per side, phase-to-neutral or phase-to-phase. Explicit shared reference bushings have matching roles |
| `open_delta_regulator` | both | Three phases per side, with an optional identified neutral |
| `n_winding` | every `windings[k]` | At least two windings; `WYE` or `DELTA` configuration; equal positive phase counts; a `DELTA` winding has at least two phases and no neutral |

### Lines and switches: same role, any label

Phase labels need not match across a line or switch. Phase subsets, arbitrary
phase permutations and a single neutral-to-neutral metallic link are all
valid. `I.TMAP.CROSS_PHASE_LINE` and `I.TMAP.PERMUTED_ORDER` report them for
information.

What is not valid is a phase at one end meeting a neutral at the other at the
same position. That raises `E.TMAP.PHASE_TO_NEUTRAL`, with both endpoint
records and the offending position. A map that repeats the neutral at every
position raises it too, alongside the duplicate-terminal diagnostic.

### Transformers: each winding on its own terms

A transformer may change phase labels, winding connection, terminal count and
neutral accessibility. `E.TMAP.WINDING_ROLES` therefore reports a violation of
the subtype's own rule in the table. It never requires equal conductor roles
across independent windings, and there is no through-neutral requirement.

An autotransformer is the exception, because it is not isolating. Its two
reference bushings are tied, so a neutral-to-phase transition on that shared
reference is rejected.

Neutral-only grounding shunts are valid. The separate galvanic-island
voltage-reference check may still flag an otherwise valid winding.

## When roles cannot be assessed

The role rules apply to distinct, declared phase and neutral conductors.
Ambiguous or unclassified roles, malformed declarations, multiple bus neutrals
and earth conductors outside this model raise `W.TMAP.CONNECTION_UNASSESSED`
with the reason. The declaration problem itself is reported by the
[terminal-convention checks](conventions.md#Terminal-role-conventions). An
element with invalid map dimensions is not shortened to make a position
comparison possible.

## Limits

- The data-model arity warnings remain even where the native models accept a
  reduced-phase or implicit-reference winding. For example, an `n_winding`
  wye without an explicit neutral raises `W.SPEC.XFMR_TMAP_ARITY`.
- The native `n_winding` solver accepts only the labels `a`, `b`, `c`, `n`,
  whatever roles are declared. Static role checks treat renamed maps
  equivalently; solver and primitive-admittance support is narrower.
- Vector-group policy, mesh compatibility and a general earth or
  protective-earth wire model are outside these checks.

Endpoint evidence carries the subtype, side or winding index, bus, terminal
map and positions, resolved roles and their source, the observed shape and
the violated rule.
