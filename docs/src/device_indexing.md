# Device topology and parameter indexing

`integrity_check` and `spec_conformance_check` resolve declared terminal roles
through the shared convention helpers. The checks describe the package's
supported indexing domains; the same array length can mean different things for
different devices. They do not reorder or mutate the case. These indexing checks do not establish
grounding adequacy or electrical equivalence.

## Field coverage

Here, **phase order** means `terminal_map` order with the identified neutral
removed; **bus phase order** means `terminal_names` order with neutral removed.
**Cyclic coils** connect map position `k` to `k+1`, wrapping at the end. A
two-terminal `SINGLE_PHASE` load, generator or IBR has one coil in either
orientation, whether phase-to-neutral or phase-to-phase.

| Device / topology | Fields | Indexing and allowed shapes | Coverage before / change in #408 |
|:--|:--|:--|:--|
| Load, `SINGLE_PHASE` | `p_nom`, `q_nom` | One entry for its terminal pair; no scalar broadcast | Existing power checks; consistent pair count |
| Load, `WYE` | `p_nom`, `q_nom` | One per phase-to-reference coil, in phase order | Previously hard-coded three; now actual map and declared roles |
| Load, `DELTA` | `p_nom`, `q_nom` | One per cyclic coil; native two-terminal boundary represents one pair | Previously hard-coded three; now actual native coil count |
| Voltage-dependent load | `v_nom`; ZIP `alpha_z/i/p`, `beta_z/i/p`; exponential `gamma_p/q` | Scalar, length-one broadcast, or one per sub-load coil; ignored coefficient families keep their existing informational findings | Existing `E.LOAD.*_ARITY` codes retained; counts now use declared roles and pair semantics, with structured shape evidence |
| Generator, `SINGLE_PHASE` | `p_min/max`, `q_min/max`, `s_max`, `cost` | One per terminal pair | Existing checks incorrectly counted both phase terminals for a phase-to-phase pair; corrected |
| Generator, `WYE` | Same | One per phase-to-reference coil | Existing checks now use declared neutral roles |
| Generator, `DELTA` | Same | One per cyclic coil | Existing count retained; domain is identified as a coil, not a bus conductor |
| IBR, `SINGLE_PHASE` | `p_min/max`, `q_min/max`, `s_max`, `cost`, `r_filter`, `x_filter` | One per terminal pair | Adds missing P/Q checks; retains rating/cost/filter checks |
| IBR, `FOUR_LEG` | Same | One per phase-to-neutral branch, in phase order | Adds P/Q checks; neutral presence is checked explicitly |
| IBR, `THREE_LEG` | Same | One per cyclic coil in the current native formulation | Adds P/Q checks; neutral is forbidden. This does not resolve the broader physics review in #95 |
| Generator/IBR, single-phase pair | `i_max` | One shared-current cap or two conductor entries collapsed to the tighter cap | Existing allowance retained, including phase-to-phase pairs |
| Generator/IBR, multi-phase star | `i_max` | Phase entries, optionally followed by a neutral-return cap, regardless of neutral's map position | Existing allowance and `W.INT.IMAX_NO_NEUTRAL` retained; declared-role count corrected |
| Generator `DELTA` / IBR `THREE_LEG` | `i_max` | Native current variables are indexed by cyclic coil, with the same number of entries as map terminals | Existing length retained; no claim that a coil cap is a conductor-current cap |
| IBR | `p_avail` | Scalar device total, not a per-phase array | New shape check; no change to control-law allocation |
| Voltage source | `v_magnitude`, `v_angle` | Matching arrays in terminal-map order; may omit only an already perfectly grounded trailing suffix | Existing exact-map-length check rejected valid prefixes; corrected. Omitting an ungrounded phase is still rejected |
| Voltage source | `p_min/max`, `q_min/max`, `cost` | Phase injection order, excluding neutral even when reference arrays include it | New checks |
| Bus | `v_min/max`, `vpn_min/max` | One per bus phase; strictly arrays | New static checks, aligned with existing native shape gates |
| Bus | `vpp_min/max` | One per unordered phase pair, nested `i<j` in bus phase order: `ab, ac, bc` for `a,b,c` | New static checks; not conductor-indexed |

Absent optional bounds are allowed. Empty generator/IBR/source P/Q or supported
current/apparent-power limit arrays retain the native meaning “no authored
limits”; a nonempty partial vector is diagnosed. Cost and filter arrays must
cover every indexed quantity. No scalar broadcast is invented for capabilities,
costs, source references or bus bounds. Filter arrays retain their declared
extension indexing contract; this does not assert that the native OPF stamps a
physical filter. The scalar `b_filter_shunt` is not a phase array.

ZIP/exponential shape checks are owned by `domain_rules_check`; the other field
shapes are owned by `integrity_check`. Applicable coefficient fields retain
their previous scalar/length-one allowances. The JSON schema and migration
layers may impose additional representation requirements; this change does not
expand the external schema. In particular, scalar bus `v_min/v_max` remain a
pre-migration representation rejected at ingest; static validation does not
migrate them. `vpn_*` without an identified neutral is explicitly unassessed.
Voltage-reference interpretation and feasibility remain separate from shape
validation (see #119).

## Roles, permutations and diagnostic evidence

Declared `terminal_conventions` take precedence over naming guesses or a stale
materialized `neutral_terminal`. Equivalent `n`, `4` and `return` labels have the
same indexing result. With no declaration, existing inference and
`W.CONV.TERMINAL_ROLES_INFERRED` remain in place.

WYE/FOUR_LEG phase order follows the map after removing its neutral; the neutral
need not be last. Phase permutations and reversed single-phase pairs are valid,
although `I.TMAP.PERMUTED_ORDER` may still describe their ordering. The older
WYE “last terminal must be neutral” diagnostic now checks whether the identified
neutral is missing. Existing duplicate-terminal and DELTA-neutral diagnostics
remain. `THREE_LEG` rejects neutral involvement; `FOUR_LEG` requires an identified
neutral return. Explicit earth conductors are outside these device models and
receive `E.TMAP.DEVICE_ROLES`, rather than being silently counted as phases.

The data-model conformance arities (`W.SPEC.CONFIG_ARITY` and
`W.SPEC.INV_TMAP_ARITY`) are unchanged. A native reduced-phase boundary may have
correctly sized parameter arrays and still receive that conformance warning.
An implicit-reference WYE retains its existing `W.INT.WYE_WITHOUT_NEUTRAL`
warning; no new implicit return is inferred by this work.

`W.INT.DIM_MISMATCH` includes bus, topology, terminal map and positions, resolved
roles, role provenance, indexing domain, allowed lengths, scalar allowance and
observed shape. Existing load arity codes carry the same evidence. Overlapping,
unclassified or multiple-neutral roles produce
`W.INT.DEVICE_INDEXING_UNASSESSED` with `status="indeterminate"`; no expected
dimension is guessed. Declaration hygiene keeps its existing `E.CONV.*` /
`W.CONV.*` ownership, and unknown references keep `E.INT.*` ownership. The new
unassessed finding explains why indexing cannot proceed; it is not a second
declaration error.

These checks handle malformed device maps and indexed-field shapes without
indexing or converting invalid payloads. They are static validation passes, not
a guarantee that every analysis or solver entrypoint accepts arbitrary
schema-invalid input. No OPF model, parsing behavior, branch/winding endpoint
rule (#409), or declaration-list hygiene rule (#410) changes here.

OpenDSS intake reserves `n_ref` for a separate, perfectly grounded node-0
return. A bus may carry both conductor neutral `n` and `n_ref`; this bounded
case is assessed without merging the returns. Each winding/device map still
selects its own return, and `n` remains the bus neutral used for voltage bounds.
Other multiple-neutral declarations retain their unassessed diagnostics. See
[the intake semantics](conversion.md#earth-terminal).
