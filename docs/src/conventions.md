# Data model conventions

This page documents the BMOPF data-model conventions as implemented by
BMOPFTools, following the Task Force specification ([ref. 1](methodology.md#refs)) with the
implementation choices called out explicitly.

## Structure and identifiers

The network is a nested `Dict{String,Any}`: component types at the top level
(`bus`, `line`, `linecode`, `voltage_source`, `load`, `generator`, `shunt`,
`switch`, `transformer`), each a dict of `id => component`. IDs are
**strings** and carry no ordering semantics. Keys beginning with `_`
(`_meta`, `_pmd`, `_slack`, …) are tolerated extension/bookkeeping fields
and are never reported as schema violations.

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
metres, linecodes per-metre, voltages in volts and powers in watts/vars — so no
further scaling is applied on ingest.

## Terminal names

Terminal identifiers are **strings**. The library writes the OpenDSS-flavoured
convention `"1", "2", "3", "n"` and understands these conventions on read:

| Convention | Phases | Neutral |
|---|---|---|
| OpenDSS numeric | `"1" "2" "3"` | `"4"` (positional, see below) |
| BMOPFTools canonical | `"1" "2" "3"` | `"n"` |
| Letter | `"a" "b" "c"` (any case) | `"n"`/`"N"` |
| IEC 60445 | `"L1" "L2" "L3"` | `"N"` |

**Neutral identification** is heuristic (the spec carries no explicit
marker): a terminal named `n`/`N` is the neutral; failing that, terminal
`"4"` of a bus whose terminal set is exactly `{"1","2","3","4"}`. Anything
else is treated as all-phase.

**Ingest normalisation**: JSON files with non-string terminal entries (e.g.
`[1,2,3,4]`) are coerced by [`parse_bmopf`](@ref). If every numeric token is
covered by the alias table (default `1→"1", 2→"2", 3→"3", 4→"n"`,
overridable via `terminal_aliases`), the aliases apply; otherwise — the
profiling guard, e.g. a 5th conductor present — everything becomes its
verbatim decimal string. Coercion is recorded in
`_meta["terminal_coercions"]` and flagged as `W.SPEC.TERMINAL_TYPES`.

## Buses, bounds and grounding

A bus carries `terminal_names`, optionally `perfectly_grounded_terminals`,
and optional voltage-magnitude bounds in four flavours: phase-to-ground
(`v_min`/`v_max`), phase-to-neutral (`vpn_*`), phase-to-phase (`vpp_*`)
and sequence (`vpos_*`). `v_min`/`v_max` and `vpn_min`/`vpn_max` are
**per-phase arrays** (one element per phase terminal, in `terminal_names` order,
neutral excluded); `vpp_min`/`vpp_max` are **per-pair arrays** (one element per
unordered phase pair, in `(i<j)` order). A scalar `v_min`/`v_max` is **rejected
at ingest** (`parse_bmopf`) — wrap it in an array of the phase count. The
neutral conductor has its own separate, optional, **maximum-only** bound
`vn_max` (scalar, neutral-to-ground), valid only when the bus has a neutral.
Absent bounds mean *unconstrained* (spec §4.1.5).

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
(A, per conductor) and `s_max` (VA).

The spec defines full row-first storage; BMOPFTools also *reads*
upper-triangular shorthand (mirroring the missing transpose entries) and
reports it as `I.SPEC.MATRIX_TRIANGULAR`. It always *writes* all n²
entries.

## Loads and generators

`configuration` ∈ `SINGLE_PHASE` (2 terminals, between any two nodes),
`WYE` (4 terminals, midpoint return) or `DELTA` (3 terminals). Setpoint
vectors `p_nom`/`q_nom` have length 1 (single-phase) or 3. Note the spec
FAQ: a "wye" in the BMOPF sense always has the neutral return — a
2-terminal load is `SINGLE_PHASE`, not a degenerate wye.

Generators additionally carry `cost` and optional `p_min/p_max/q_min/q_max`.
`cost` is a **per-phase vector of linear coefficients** (\$/W), one element per
phase term; the objective contribution of phase `k` is `cost[k]·P_k`. (There is
no polynomial/quadratic cost form.) A generator without bounds is an unbounded
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

## Transformer subtypes

Six subtypes, each its own sub-dict under `transformer`.  All impedance
fields are in SI units (Ω or S); `v_ref_*` in V; `s_rating` in VA.

| Subtype | map arity (from, to) | OPF model | impedance fields |
|---|---|---|---|
| `single_phase` | (2, 2) | Γ-equivalent, series Z referred to HV | `r/x_series_from` (HV, Ω), `r/x_series_to` (LV, Ω), `g/b_no_load` (S) |
| `center_tap` | (2, 3) | T-model, per-leg secondary Z | same field names — see note below |
| `wye_delta` | (4, 3) | per-winding T behind ideal Yd transform | `r/x_series_from` (wye), `r/x_series_to` (delta), `g/b_no_load` (S) |
| `delta_wye` | (3, 4) | per-winding T behind ideal Dy transform | `r/x_series_from` (delta), `r/x_series_to` (wye), `g/b_no_load` (S) |
| `single_phase_autotransformer` | (2, 2) | step voltage regulator: YY core at fixed-tap effective ratio `n_eff`, **shared neutral** | `r/x_series_from`, `r/x_series_to`, `g/b_no_load`; ratio from `tap_ratio` + `regulator_type` |
| `open_delta_regulator` | (4, 4) | monolithic open-delta: two line-to-line regulating windings + galvanic straight-through | per-regulator `r/x_series_*`; `connection`, `tap_ratio` (len 2), `regulator_type` |

**`single_phase`**: the series impedance $R = R_1 + N^2 R_2$, $X = X_1 + N^2 X_2$
is lumped onto the HV side (Γ convention).  `r_series_from`/`x_series_from`
are the HV winding values (Ω on the HV voltage base); `r_series_to`/`x_series_to`
are the LV winding values (Ω on the LV voltage base).  The no-load shunt
`g_no_load`/`b_no_load` is placed at the HV terminals, phase-to-ground.

**`center_tap`**: `terminal_map_from = ["1","n"]` (HV phase + neutral),
`terminal_map_to = ["1","n","2"]` (leg-1, center-tap neutral, leg-2).
`v_ref_to` is the **per-leg** voltage (e.g. 120 V, not 240 V).
The OPF uses a T-model with **independent per-leg** secondary impedance
branches — `r_series_to`/`x_series_to` apply separately to each leg, so
unbalanced loading produces different voltages on the two legs.

!!! warning "Leakage from OpenDSS XHL/XLT/XHT"
    For `center_tap`, `x_series_from`/`x_series_to` are the **star-network**
    leakage values, not `XHL/2`.  Given OpenDSS pair-wise values in %:
    ```
    x_series_from = (XHL + XHT − XLT) / 2  ×  Vhv² / (100 · s_rating)
    x_series_to   = (XHL + XLT − XHT) / 2  ×  Vlv² / (100 · s_rating)
    ```
    Using the 2-winding shortcut `XHL/2` on both sides forces both leg
    voltages to be identical under unbalanced loading, which is wrong.

**`wye_delta`/`delta_wye`**: a per-winding T-model behind the ideal Yd/Dy
transform, matching the OpenDSS / PMD reference loss network.  Each winding
carries its own series impedance (`r/x_series_from`, `r/x_series_to`) and a
`g/b_no_load` core-loss shunt sits at the from-side (HV) phase terminals.
`v_ref_*` are phase-to-neutral equivalents (the √3 factor is absorbed into
the effective turns ratio `n_eff`).  The older single `r_series`/`x_series`
(wye-side lumped, delta ideal) is accepted as legacy shorthand and migrated
onto `r_series_from`/`x_series_from` with the secondary branch zero — see the
[conversion guide](conversion.md) and feedback item 21.

**`single_phase_autotransformer`**: a single-phase step voltage regulator
modelled as an autotransformer (series + common winding sharing a node), so the
from and to sides are galvanically tied — not isolated.  The ratio is the
**fixed** `tap_ratio` $a$ (regulated/source); `regulator_type` selects the ANSI
connection, giving the effective from→to ratio $n_\text{eff}=1/a$ (Type B,
default) or $n_\text{eff}=a$ (Type A).  The OPF voltage/current constraints are
the `single_phase` YY form with $N:=n_\text{eff}$, plus a **shared-neutral KCL**
($I_n + I_\text{series} + I_\text{to}=0$) that closes the common-winding return.
`v_ref_*` are not used (the ratio is `tap_ratio`); per-unit propagates the same
base across the galvanic tie (no voltage-level change).

**`open_delta_regulator`**: a monolithic three-phase open-delta regulator — two
single-phase autotransformer windings connected line-to-line across the phase
pairs implied by `connection` (`ABBC`/`BCAC`/`CABA`, GridLAB-D convention),
with per-regulator taps `tap_ratio = [a1, a2]`.  The phase common to both
regulators is a **galvanic straight-through** (`V_shared,from = V_shared,to`),
the physically-correct "common neutral" model of Yan et al. (2018); the two
regulated line-to-line voltages are boosted by their taps while the shared phase
passes through unchanged.  See the [OPF reference](opf.md) and the derivation
note `docs/transformer_admittance_derivation.md`.

There is **no wye-wye three-phase type**: three-phase wye-wye units must be
decomposed into three `single_phase` transformers.  The converter currently
parks them in `single_phase` with 3-phase terminal maps and the conformance
check flags the arity (`W.SPEC.XFMR_TMAP_ARITY`) — see the
[conversion guide](conversion.md).

## Switches

### Scope: what the `switch` object represents

The `switch` is the data model's element for **any section of negligible series
impedance** — a per-conductor short between two buses that either carries current
with no voltage drop (closed) or carries none (open). It is an *idealised,
lossless* two-bus element: there is no `linecode`, no `length`, and no `R`/`X`
(contrast [Lines](#Lines,-linecodes-and-matrices)). The closed switch imposes
$v_{b^\text{fr}} = v_{b^\text{to}}$ on every conductor in its terminal map and
the open switch fixes its currents to zero (see
[the OPF switch model](opf.md#Switches)).

A single object therefore covers a family of physical devices that, for
steady-state OPF, all reduce to the same idealisation. The intended scope:

| Physical device | Why it maps to `switch` |
|---|---|
| **Disconnector / isolator** | Manually-operated open/close point; impedance negligible when closed. |
| **Load-break switch / sectionaliser** | Field switching point for reconfiguration; lossless when closed. |
| **Circuit breaker** | The *conducting path* is lossless; protection/trip logic is out of scope for steady-state OPF. |
| **Recloser** | As above — a breaker with reclosing control; only its open/closed conduction state matters here. |
| **Tie switch** | Normally-open reconfiguration link between feeders. |
| **Busbar section / jumper / bus-tie** | A near-zero-impedance metallic connection between nodes; an explicit object instead of merging the buses. |
| **Near-zero-impedance line** | A line whose $\|Z\|$ is below the conditioning threshold — the augmentation pass converts it to a closed switch (`W.DOM.LINE_LOW_IMPEDANCE`, [ref. 2](methodology.md#refs)). |

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
  `normalOpen` / `ratedCurrent` attributes, specialised into `ProtectedSwitch`
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

The network dict carries two distinct metadata containers, with different
scopes and serialisation behaviour.

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
| `authors` | Array of objects | List of contributors; each object may have `name`, `email`, `orcid`. |
| `sources` | Array of objects | Origin datasets; each object may have `name`, `url`, `format`, `doi`, `version`. |
| `generator` | Object | Tool provenance: `{"tool": "BMOPFTools.jl", "version": "x.y.z"}`. Auto-filled by `write_bmopf`. |

**Auto-generation on write.** [`write_bmopf`](@ref) always emits a `meta`
block.  It merges fields in priority order: the `meta` keyword argument
→ `net["meta"]` → auto-generated defaults.  Auto-generation fills three
fields if they are absent: `$schema`, `generator`, and `created`.
Caller-supplied values are never overwritten.

**On parse.** [`parse_bmopf`](@ref) and [`from_dss`](@ref)
carry `net["meta"]` through unchanged.  [`migrate`](@ref) reads
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
        "sources"     => [Dict("name" => "ENWL dataset",
                               "format" => "OpenDSS",
                               "url"    => "https://www.enwl.co.uk/")],
    ))
```

### `_meta` — tool-private, never serialised

`net["_meta"]` is a `Dict{String,Any}` used internally by BMOPFTools for
traceability.  It is **not written to JSON** by [`write_bmopf`](@ref) and
is never reported as a schema violation.  Its contents are informational;
downstream code should treat them as advisory.

| Key | Set by | Contents |
|---|---|---|
| `parsed_at` | [`parse_bmopf`](@ref) | Timestamp when the JSON was parsed. |
| `terminal_coercions` | [`parse_bmopf`](@ref) | `{"n": <count>, "mode": "<alias|verbatim>"}` — populated when non-string terminal IDs were normalised. See `W.SPEC.TERMINAL_TYPES`. |
| `powerio_source` | `from_dss` | Absolute path of the `.dss` file that was converted. |
| `powerio_warnings` | `from_dss` | Array of warning strings emitted by the DSS→JSON converter. |
| `migration_notes` | [`migrate`](@ref) | Array of `W.MIGRATE.UPGRADED` finding dicts appended when a forward migration is applied. |

## Time series (extension)

`time_series` at the root plus component-level `time_series` reference
dicts follow the PMD convention (values are multiplicative scale factors on
the static value). This is a BMOPFTools extension beyond the static-only TF
spec; [`get_snapshot`](@ref) materialises a snapshot at a given index and
[`analyze`](@ref) does this automatically.
