# Branch and winding connection maps

`integrity_check` visits each line/switch endpoint, each two-bus transformer
endpoint, and every original `n_winding.windings[k]` entry. It checks raw
structures without converting winding voltages, impedances or taps. Unknown
bus/terminal references keep `E.INT.UNKNOWN_BUS` / `E.INT.UNKNOWN_TERMINAL`;
their evidence now identifies the endpoint or original winding index. Invalid
objects, missing/non-string bus identifiers, and empty or malformed maps use
`E.INT.CONNECTION_SHAPE`. Invalid entries are never dropped or renumbered.

`spec_conformance_check` resolves the declared roles using the same helpers as
device parameter indexing. It does not repair, reorder, truncate or mutate maps.
The evidence is linked to PSK-000002; this page defines package behavior, not a
new scientific claim or grounding model.

## Coverage and supported rules

| Layout | Reference traversal | Map rule | Previous coverage / change in #409 |
|:--|:--|:--|:--|
| Line | `bus_from/to`, `terminal_map_from/to` | Matrix row and both endpoint positions must agree in count; position `k` connects equal conductor roles | Existing references, duplicates and matrix dimension error retained; structured endpoint evidence added; mixed phase/neutral swaps now fail |
| Switch (open or closed) | Same two endpoints | Equal map lengths; same role at each position | Existing references/duplicates retained; unequal lengths and mixed role swaps now diagnosed even for currently open switches |
| `single_phase` | Both endpoints | Matching positive coil counts; neutral-present maps form phase-neutral pairs, a neutral-free two-terminal map forms one phase pair, other phase-only maps form implicit-reference coils | Existing spec arity warning retained; duplicates and coupled-coil counts checked |
| `center_tap` | Both endpoints | HV `[phase, neutral]` or phase-phase pair; LV `[phase, neutral, phase]` in leg-1/midpoint/leg-2 order | Existing 2/3 arity warning retained; positional midpoint/polarity contract checked |
| `wye_delta`, `delta_wye` | Both endpoints, with subtype-specific WYE/DELTA side | WYE phase order excludes neutral wherever it occurs; DELTA contains only phases; WYE phase count equals DELTA coil count (at least two) | Existing 4/3 or 3/4 spec arity warning retained; declared roles and coupling checked; no line-style continuity imposed across windings |
| `single_phase_autotransformer` | Both endpoints | Exactly one regulating coil on each side, allowing phase-neutral or phase-phase pairs; explicit shared reference bushings must have matching roles | Existing 2/2 spec arity warning retained; coil count checked; regulator connection/voltage policy is unchanged |
| `open_delta_regulator` | Both endpoints | Three phases on each side, with optional identified neutral; phase ordering follows each map | Existing 4/4 spec arity warning retained; phase-count/duplicate checks added; ABBC/BCAC/CABA policy is unchanged |
| `n_winding` | Every `windings[k].bus/terminal_map`, retaining `k` | At least two winding objects; WYE/DELTA configuration; positive equal phase counts across windings; DELTA has at least two phases and no neutral | Existing references and duplicate/arity codes retained; validation no longer invokes a numeric converter or infers roles from literal labels; malformed entries retain their original index |

The role-check domain is distinct, declared phase/neutral conductors. Ambiguous
or unclassified roles, malformed declarations, multiple bus neutrals, and earth
conductors outside this model produce `W.TMAP.CONNECTION_UNASSESSED` with an
indeterminate reason. Declaration hygiene remains owned by its existing checks.
Unknown references and malformed structures are diagnosed by integrity rather
than duplicated as role errors. A component with invalid map dimensions is not
silently shortened for a position comparison.

Phase labels need not match across a line or switch. Phase subsets, arbitrary
phase permutations and a single neutral-to-neutral metallic link remain valid.
`I.TMAP.CROSS_PHASE_LINE` and `I.TMAP.PERMUTED_ORDER` remain informational. A
phase-to-neutral transition at a particular position uses the established
`E.TMAP.PHASE_TO_NEUTRAL` code, with both endpoint records and the bad position.
Repeated all-neutral maps retain that historical diagnostic as well as the
existing duplicate-terminal code.

Transformers can change phase labels, winding connection, terminal count and
neutral accessibility. `E.TMAP.WINDING_ROLES` identifies violations of the
subtype's supported map or coupled-coil rule, never equality of conductor roles
across independent windings. An autotransformer is not isolated: its two explicit
reference bushings are tied, so a neutral-to-phase transition on that specific
shared reference is rejected. Neutral-only grounding shunts remain valid nodal
admittances and are not subject to a phase-injection rule. No new ground bond or
through-neutral requirement is introduced. The existing galvanic-island voltage
reference check remains separate and may diagnose an otherwise valid winding.

## Runtime and diagnostic boundaries

The original data-model arity warnings remain, even where native reduced-phase
or implicit-reference winding models accept a boundary case. An n-winding WYE
without an explicit neutral retains `W.SPEC.XFMR_TMAP_ARITY`; it is not reclassified
as a phase-to-neutral continuity error. Numerical transformer parameters, vector
group policy (#268), and mesh compatibility (#176) remain with their owners.

These are static structural/role checks. In particular, the native n-winding
solver currently restricts labels to `a/b/c/n`, regardless of valid declared
roles. Equivalent renamed maps receive equivalent static role judgments; this
does **not** expand solver or primitive-admittance label support. This change
also does not make every analysis, ingestion or solver entrypoint accept
arbitrary malformed input, or add a general earth/PE wire model (#70).

Endpoint evidence includes component identity (on the Finding), subtype,
side/winding index, bus, terminal map and positions, resolved roles, role source,
observed shape and the violated rule. Composite comparisons include all involved
endpoints and explicit counts/positions. Tests check stable codes and detail,
JSON round trips, deterministic connection findings, and input non-mutation.
