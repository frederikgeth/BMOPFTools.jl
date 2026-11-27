# Device topology and parameter indexing

A vector field such as `p_nom`, `i_max` or `v_min` has one entry per *something*,
and that something depends on the device and its wiring: a phase, a coil
between two terminals, a conductor, or a pair of phases. This page states the
rule for every indexed field. `integrity_check` and `spec_conformance_check`
enforce these rules; they report mismatches and never reorder or repair a case.

!!! note "What these checks do not establish"
    A correctly sized array says nothing about grounding adequacy or
    electrical equivalence. Those are separate analyses.

## Three terms

- **Phase order** is the `terminal_map` order with the identified neutral
  removed. **Bus phase order** is `terminal_names` order with the neutral
  removed. The neutral does not have to be the last entry.
- **Cyclic coils** connect map position `k` to position `k+1`, wrapping at the
  end. A `DELTA` on `["a","b","c"]` has coils `ab`, `bc`, `ca`.
- A two-terminal **`SINGLE_PHASE`** load, generator or IBR has one coil, in
  either orientation, whether it is phase-to-neutral or phase-to-phase.

For example, a `WYE` load on `terminal_map = ["a","b","c","n"]` has three
phase-to-neutral coils, so `p_nom` has three entries, for `a`, `b` and `c`.
With `terminal_map = ["n","c","a"]` it has two, for `c` and `a`.

## Indexing rules

### Loads

| Topology | Fields | One entry per |
|:--|:--|:--|
| `SINGLE_PHASE` | `p_nom`, `q_nom` | the terminal pair (one entry; no scalar broadcast) |
| `WYE` | `p_nom`, `q_nom` | phase-to-reference coil, in phase order |
| `DELTA` | `p_nom`, `q_nom` | cyclic coil; a two-terminal map is one pair |
| any, voltage-dependent | `v_nom`; ZIP `alpha_z/i/p`, `beta_z/i/p`; exponential `gamma_p/q` | sub-load coil, or a scalar, or a length-one vector that broadcasts |

### Generators and IBRs

| Device and topology | Fields | One entry per |
|:--|:--|:--|
| Generator `SINGLE_PHASE` | `p_min/max`, `q_min/max`, `s_max`, `cost` | the terminal pair |
| Generator `WYE` | same | phase-to-reference coil |
| Generator `DELTA` | same | cyclic coil; a two-terminal map is one pair |
| IBR `SINGLE_PHASE` | `p_min/max`, `q_min/max`, `s_max`, `cost`, `r_filter`, `x_filter` | the terminal pair |
| IBR `FOUR_LEG` | same | phase-to-neutral branch, in phase order; an identified neutral is required |
| IBR `THREE_LEG` | same | cyclic coil; a neutral is forbidden |
| IBR, any | `p_avail` | the device (a scalar total, not a per-phase array) |

Current limits `i_max` follow the conductors, not the power arrays:

| Device and topology | `i_max` shape |
|:--|:--|
| Generator or IBR, single-phase pair | one shared-current cap, or two conductor entries that collapse to the tighter cap |
| Generator or IBR, multi-phase star | one entry per phase, optionally followed by a neutral-return cap, wherever the neutral sits in the map. A phases-only vector raises `W.INT.IMAX_NO_NEUTRAL` |
| Generator `DELTA`, IBR `THREE_LEG` | one entry per cyclic coil (the native current variables are coil currents, so this is a coil cap, not a conductor cap) |

### Voltage sources

| Fields | One entry per |
|:--|:--|
| `v_magnitude`, `v_angle` | terminal, in `terminal_map` order; the two arrays have equal length. A trailing run of already perfectly grounded terminals may be omitted; an ungrounded phase may not |
| `p_min/max`, `q_min/max`, `cost` | phase, in phase order, with the neutral excluded even when the reference arrays include it. A source with `DELTA` configuration is not length-checked |

### Buses

| Fields | One entry per |
|:--|:--|
| `v_min/max`, `vpn_min/max` | bus phase; always an array |
| `vpp_min/max` | unordered phase pair, nested `i<j` in bus phase order: `ab, ac, bc` for phases `a, b, c` |

## Empty, absent and scalar values

- Absent optional bounds are allowed.
- An **empty** P/Q, current or apparent-power limit array on a generator, IBR
  or source means "no authored limits". A nonempty partial vector is an error.
- `cost` and filter arrays must cover every indexed quantity.
- No scalar is broadcast for capabilities, costs, source references or bus
  bounds. A scalar bus `v_min`/`v_max` is rejected at ingest.
- The scalar `b_filter_shunt` is not a phase array. Filter arrays are checked
  for shape only; the check does not assert that the OPF stamps a physical
  filter.
- `vpn_*` on a bus without an identified neutral is reported as unassessed.

Load-model coefficient shapes are checked by `domain_rules_check`; all other
shapes by `integrity_check`. The JSON schema may impose additional
representation requirements.

## How roles are resolved

A declared [`terminal_conventions`](conventions.md#Terminal-role-conventions)
block takes precedence over naming guesses and over a stale in-memory
`neutral_terminal`. Equivalent labels such as `n`, `4` and `return` give the
same indexing result once declared. Without a declaration, roles are inferred
and `W.CONV.TERMINAL_ROLES_INFERRED` is raised.

- Phase permutations and reversed single-phase pairs are valid.
  `I.TMAP.PERMUTED_ORDER` may describe the ordering; it is informational.
- An explicit earth conductor is outside these device models and raises
  `E.TMAP.DEVICE_ROLES`. It is never counted as a phase.
- An implicit-reference `WYE` (no neutral in its map) raises
  `W.INT.WYE_WITHOUT_NEUTRAL`. No implicit return is inferred.
- Duplicate terminals in a map and a neutral in a `DELTA` map have their own
  diagnostics.
- Load-model coefficient families that the chosen `model` does not read are
  reported for information.
- OpenDSS intake uses `n_ref` for a separate, perfectly grounded node-0
  return. A bus may carry both the conductor neutral `n` and `n_ref`; each
  device map selects its own return, and `n` remains the bus neutral for
  voltage bounds. See [the intake semantics](conversion.md#earth-terminal).
  Other multiple-neutral declarations are reported as unassessed.

## Findings

| Code | Meaning |
|:--|:--|
| `W.INT.DIM_MISMATCH` | An indexed field has the wrong shape. The evidence lists the bus, topology, terminal map and positions, resolved roles and their provenance, the indexing domain, the allowed lengths, whether a scalar is allowed, and the observed shape |
| `E.LOAD.*_ARITY` | The same, for load-model fields |
| `W.INT.DEVICE_INDEXING_UNASSESSED` | Roles are overlapping, unclassified or ambiguous, so no expected dimension is computed (`status = "indeterminate"`). The declaration problem itself is reported by the `E.CONV.*`/`W.CONV.*` checks, and unknown references by `E.INT.*` |
| `W.SPEC.CONFIG_ARITY`, `W.SPEC.INV_TMAP_ARITY` | The terminal-map length differs from the data-model configuration arity. A reduced-phase device can have correctly sized arrays and still receive this conformance warning |

These are static validation passes over raw data. They do not guarantee that
every analysis or solver entry point accepts schema-invalid input.
