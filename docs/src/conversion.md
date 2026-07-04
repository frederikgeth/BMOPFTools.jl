# Conversion guide

This page documents both directions of format conversion:

- **Ingest** — OpenDSS `.dss` models are read by [`from_dss`](@ref) and emitted
  as a BMOPF data model.
- **Export** — a BMOPF data model is written to a PowerModelsDistribution
  ENGINEERING dict by [`to_pmd`](@ref), or back to an OpenDSS `.dss` model by
  [`to_dss`](@ref).

Each section records the deliberate decisions in those converters — the things
you would otherwise have to discover by diffing data.

## [Design philosophy: ingestion is a semantic projection](@id ingest-philosophy)

!!! note "This is one instance of a model-wide principle"
    Reconstructing the named real-world asset rather than a solver-convenient
    encoding is a stance that governs the whole data model — validation findings
    and [fix recipes](augmentation.md#fix) as much as ingest. The general
    statement, and the catalogue of representational collisions it resolves
    (capacitor-vs-shunt, load-vs-generator, line-vs-transformer, …), live on the
    [Object identity & semantic projection](@ref object-identity) page. This
    section covers the OpenDSS-specific *lowering*.

`from_dss` does not aim to be a byte-faithful transcoder. It is closer to a
**compiler frontend**: PowerIO does the lexing and parsing, and `from_dss` then
performs *semantic analysis* — inferring phase and neutral identity, fingerprinting
voltage regulators, classifying grounding and galvanic zones — to lower a loosely
specified OpenDSS model onto a canonical, conductor-level data model. Just as a
compiler is not expected to round-trip back to the original source whitespace but
*is* expected to preserve program semantics and diagnose errors the source
obscured, BMOPFTools optimises for a different goal than a faithful copy.

The goal hierarchy is explicit:

> **Semantic faithfulness + data-quality leverage  >  byte-level round-trip.**

A lossless transcode of an OpenDSS deck would preserve every quirk of its
encoding — implicit earth nodes, regulators expressed as control loops over
ordinary lines, phases identified only positionally — and in doing so would leave
the network *unanalysable*. You cannot run a semantic data-quality check (is this
star point grounded? which buses share a galvanic zone? is this a four-wire or
three-wire segment?) on a representation that never made those facts explicit. The
non-trivial mapping is therefore not incidental; it is the price of being able to
reason about the network at all.

Three pillars make a non-identity transformation safe to rely on:

1. **Canonicalise representation.** Normalise terminals, neutral/earth, regulator
   structure and grounding onto one explicit convention (the
   [ingest steps](@ref from-dss-ingest) below), so every downstream pass sees the
   same shape.
2. **Surface inferences as findings, never silent assumptions.** Every inferred
   fact is emitted as a provenance finding (`I.PROV.*`) with a confidence tag, so
   a heuristic that guesses wrong is *diagnosable*, not hidden. This is the
   correctness burden a pure transcoder never takes on, paid down openly.
3. **Record provenance.** The transformation manifest and `net["_meta"]` keep an
   auditable trail of what was normalised, so the projection is reproducible
   (same inputs + pinned versions ⇒ same canonical output) and any drift is
   visible.

The aim, then, is **reproducible compatibility with deliberate surgery** — not
losslessness. What is preserved is the physics and the semantics; what is
normalised away is redundant or ambiguous *encoding*, and even that is recorded.

### Background and precedents

This is a principled stance with a clear lineage, in power systems and beyond.

- **In this project's own design goals.** The Task Force benchmark architecture
  argues for *maintaining semantics in the data model* precisely to make data
  debugging tractable and to avoid benchmarking pitfalls
  ([ref. 2](methodology.md#refs)), building on a survey of the data-quality
  problems that pervade existing distribution datasets
  ([ref. 14](methodology.md#refs)).
- **A two-layer model is established practice.** PowerModelsDistribution
  deliberately separates a human-facing *engineering* model from a solver-facing
  *mathematical* model, connected by an explicit lowering step
  ([ref. 15](methodology.md#refs)); BMOPFTools pushes the same idea one stage
  upstream, from "engineering vs math" to "raw export vs benchmark-grade model."
- **Model the entities, not the coordinate transform.** The IEC Common
  Information Model represents a network through explicit terminals and
  connectivity nodes ([ref. 23](methodology.md#refs)) — the very structure
  OpenDSS leaves implicit and `from_dss` reconstructs. This runs against a
  long-standing reflex in power engineering to reason in *coordinate-transformed*
  models (symmetrical components, Kron reduction) that discard the
  conductor-level data a four-wire model — and a non-expert collecting it —
  actually needs ([ref. 10](methodology.md#refs), [ref. 17](methodology.md#refs));
  see the [buses & terminals primer](terminals_primer.md).
- **Good data modelling is a discipline in its own right.** Outside power systems
  the same lesson recurs: *tidy data* observes that data is usually organised for
  ease of entry rather than analysis, and that standardising the mapping from
  semantics to representation is what makes reliable, composable tooling possible
  ([ref. 22](methodology.md#refs)); the **FAIR** principles make *provenance and
  shared vocabularies* — not raw dumps — the basis of reusable data
  ([ref. 21](methodology.md#refs)); **Open Power System Data** brings the same
  validated, reproducible raw-to-results discipline to energy-system modelling
  ([ref. 24](methodology.md#refs)); and **W3C PROV** formalises provenance as the
  mechanism that makes a non-identity transformation trustworthy — notably
  defining validity itself through a normalisation process
  ([ref. 25](methodology.md#refs)).

What is distinctive about BMOPFTools is not any one of these ideas but their
**synthesis**: semantic canonicalisation, a stable and code-addressable
data-quality vocabulary ([findings](findings.md)), standards-grounded augmentation
([case augmentation](augmentation.md)), and a provenance manifest — assembled
specifically to make distribution-OPF benchmarks reproducible.

## [OpenDSS ingest (`from_dss`)](@id from-dss-ingest)

[`from_dss`](@ref) parses an OpenDSS model **in-process** via
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl) and emits BMOPF JSON
directly — there is no PowerModelsDistribution step in the loop, and the earlier
PMD-based `from_pmd` parser has been removed. Values arrive in **SI units**
already (line lengths in metres, impedances in Ω, powers in W/var/VA); PowerIO
normalises the DSS unit declarations internally, so `from_dss` applies no further
scaling.

The pipeline is:

```
OpenDSS .dss ──PowerIO.jl──► raw BMOPF dict ──from_dss post-processing──► BMOPF data model
```

On top of what PowerIO emits, `from_dss` (and the `parse_bmopf`/`migrate` path it
shares) applies a handful of deliberate normalisations so the result lands on the
BMOPF conventions:

- **Identifier case-folding** — all ids and references lower-cased (below).
- **Terminal remap** — `1,2,3,4 → a,b,c,n`, with the OpenDSS earth node `.0`
  (surfaced by PowerIO as terminal `"5"`) routed to the bus neutral (below).
- **Per-phase voltage source merge** — a `Circuit` + per-phase `VSource` bank on
  a shared bus is reassembled into one polyphase source (below).
- **Transformer impedance normalisation** — PowerIO's lumped single-impedance
  form is migrated onto the per-winding fields the OPF reads (below).
- **Transformer leakage & core-shunt recovery** — PowerIO's `bmopf` export drops
  the no-load shunt (every subtype), collapses the `center_tap` 3-winding leakage,
  and mis-refers the `delta_wye` delta-side leakage; `from_dss` re-derives these
  from PowerIO's `pmd` export (`_recover_transformer_params_from_pmd!`) so losses
  and split-phase legs match OpenDSS.
- **Fixed off-nominal tap recovery** — the `bmopf` export drops OpenDSS `taps=`
  entirely (silently solving at nominal ratio); `from_dss` recovers the single
  from-side `tap` multiplier `t₁/t₂` from the pmd `tm_set`. OpenDSS
  `mintap`/`maxtap` are deliberately **not** mapped to `tap_min`/`tap_max`: in
  BMOPF their presence opts the tap into optimisation, whereas in OpenDSS they
  are ubiquitous class defaults (0.9/1.1 on every unit).
- **3-winding reconstruction** — the `bmopf` export drops every 3-phase
  3+-winding transformer (and any connection set outside the four two-bus
  subtypes, e.g. Dd); `from_dss` rebuilds them as `n_winding` from the pmd
  record (`_reconstruct_nwinding_from_pmd!`), validated end-to-end against
  OpenDSS (YYY, Dyn, unbalanced Dyn). 4+ windings currently refuse loudly:
  PowerIO's pmd export mangles `Xscarray` (upstream gap).
- **Winding neutral grounding (`rneut`/`xneut`)** — PowerIO drops these from
  every export, leaving an impedance-grounded wye neutral floating; `from_dss`
  emits a targeted warning. BMOPF models them as the transformer-internal
  grounding branch `r/x_neutral_from`/`to` (set the fields manually until
  PowerIO exports them).
- **System frequency capture** — the OpenDSS base frequency (`Set
  DefaultBaseFreq`, itself defaulting to 60 Hz; European decks set it to 50)
  is otherwise absent from BMOPF impedance data, so `from_dss` reads
  `PowerIO.base_frequency` and records it on `net["meta"]["frequency"]`,
  keeping the case self-contained. It is metadata only — **never** used to
  rescale impedances (there is no OpenDSS-style base-frequency scaling in
  BMOPF) — and feeds the cross-object consistency check
  `W.DOM.FREQUENCY_MISMATCH`. Override it with `from_dss(path; frequency=…)`
  when the deck relied on a base frequency it never stated, or you know the
  intended value; the chosen source (`"powerio"` or `"override"`, plus the
  parsed value when overridden) is recorded on
  `net["_meta"]["frequency_source"]`. A PowerIO regression that dropped or
  hard-coded the base frequency would be caught by the ingest tests, which
  assert distinct 50 Hz and 60 Hz decks map to distinct `meta.frequency`.
- **No slack price** — the imported `voltage_source` is left without a `cost`;
  the [augmentation pass](augmentation.md) supplies one (below).

What is **faithful**: connectivity, phasing, linecode matrices, load models, and
SI impedances pass through unchanged. What is **lossy or not-yet-supported** —
lumped transformer leakage, earth-terminal grounding through the bus neutral, and
the OpenDSS regulator/auto-transformer families — is catalogued under
[Known limitations](#Known-limitations); most are tracked as upstream PowerIO.jl
issues.

### Identifier case-folding

OpenDSS identifiers are case-*insensitive* but case-*preserving*: `SourceBus`,
`sourcebus` and `SOURCEBUS` denote the same bus, and different statements in one
model may spell it differently. BMOPF keys are matched exactly, so `from_dss`
**case-folds every identifier and every reference to lower case** on ingest
(bus names, linecodes, component ids; bus / `bus_from` / `bus_to` / `linecode`
references). This is lossless — OpenDSS uniqueness up to case guarantees folding
only reunites references to the same object. If two ids in a collection ever fold
to the same value (which valid OpenDSS cannot produce) `from_dss` raises rather
than silently dropping one.

### [The earth terminal (OpenDSS `.0`)](@id earth-terminal)

BMOPF has no earth terminal — ground is implicit. OpenDSS, by contrast, uses
node `.0` for earth, which surfaces in the BMOPF JSON as terminal **5**.

PowerIO renders the OpenDSS earth node as terminal `"5"` (e.g. a transformer
wye winding whose star point is earthed arrives with
`terminal_map_to = ["1","2","3","5"]`). On ingest, `from_dss` routes `"5"` to
the bus neutral `"n"` as part of the `1,2,3,4 → a,b,c,n` remap, so every bus
ends up on the `a/b/c/n` convention and its neutral is detected. The earthed
star point is then grounded **through the bus neutral** rather than solidly —
a slightly lossy choice (matching the earlier `from_pmd` behaviour) that is
recorded under `net["_meta"]["earth_terminal_routing"]` so it stays inspectable.

### Transformer impedance on ingest

PowerIO emits `wye_delta`/`delta_wye` units with a **single lumped**
`r_series`/`x_series` (wye-side, delta ideal) rather than the per-winding T-model
the OPF and Ybus builders read. The lumped form is **normalised at parse time**
by `migrate` / `_migrate_transformer_series_fields!`: it is moved onto
`r_series_from`/`x_series_from` (with the secondary branch zero) and a
`W.MIGRATE.XFMR_SERIES_FIELDS` note is recorded. The percentage→ohm conversions
PowerIO performs upstream — and that `to_pmd` reverses — are tabulated under
[Transformer impedance bases](#Transformer-impedance-bases).

### [Capacitor banks](@id capacitor)

BMOPF models a fixed **shunt capacitor bank** as the top-level `capacitor`
object — a nameplate-faithful, connection-aware shunt:

```json
net["capacitor"]["c1"] = {
  "bus": "b035", "terminal_map": ["a","b","c","n"], "configuration": "WYE",
  "q_rated": [600000.0, 600000.0, 600000.0],   // var, per phase (WYE)/pair (DELTA)
  "v_nom": 14400.0                            // V (L-N for WYE, L-L for DELTA)
}
```

A capacitor is a **constant susceptance** `B = q_rated / v_nom²`, so it
delivers the voltage-dependent reactive power `Q = B·V²` (exact capacitor
physics — only equal to the nameplate kvar at the rated voltage). Connections:
`WYE` (phase-to-neutral), `SINGLE_PHASE` (two terminals), `DELTA`
(phase-to-phase). It compiles to a terminal-space susceptance matrix and reuses
the same KCL injection as a `shunt` (no decision variables — **fixed**). A
continuously-controllable / smooth capacitor (`B` a bounded decision variable)
is a documented future extension.

**Nameplate convention** (matches OpenDSS `Capacitor`): for a 3-phase bank of
total `kvar`, `q_rated` is the per-phase (WYE) or per-pair (DELTA) share
(`kvar_3ph/3`), and `v_nom` is phase-to-neutral for WYE/SINGLE_PHASE,
line-to-line for DELTA. Validated against OpenDSS's own Capacitor solve for WYE
and DELTA.

**Modelling a *fixed* bank in OpenDSS (replicable, no accidental switching).**
The toolbox models a **fixed** capacitor only. To produce a matching, constant
bank in OpenDSS (as the parity tests do):

- **no `New CapControl…` object** — a `Capacitor` without a `CapControl` never
  switches during a solve;
- **single step**, all states on — leave `Numsteps` at its default (1) and
  `states` at its default (all on), so the full nameplate kvar stays connected;
- **snapshot solve** (the default `Set Mode=Snapshot`) — no time series to drive
  a control;
- then `New Capacitor.x bus1=… phases=3 conn=wye|delta kv=<rated> kvar=<total>`
  is a constant susceptance `B = kvar/kv²` delivering `Q = B·V²`.

A multi-step `Capacitor` (`Numsteps>1`) or one driven by a `CapControl` is a
**switched** bank — discrete switching is **out of scope** here (planned later).

**Need a controllable/continuous source of reactive power today?** Use an
`ibr` (bounded `q_min`/`q_max`, or a Volt-VAr `control_profile`) or a
`generator` with reactive bounds — those already provide continuous, dispatchable
reactive support. The `capacitor` is specifically the *fixed* physical device.

Ingest status: like `n_winding`, this is a hand-authored / future-PowerIO
target — **`from_dss` is unchanged** and PowerIO still emits OpenDSS Capacitors
as plain `shunt`s (B = kvar/kv²), so existing behaviour is untouched.

### [General n-winding transformers](@id n-winding)

BMOPF models a general **n-winding** (3+) transformer as the `n_winding`
transformer subtype: a winding-indexed list rather than the two-bus
`bus_from`/`bus_to` shape used by the other subtypes. This is the canonical
representation for substations with three (or more) galvanically isolated voltage
levels — e.g. an HV→MV→LV station, or a dual-secondary unit. It is implemented as
a **fully independent code path** (`src/io/nwinding.jl`,
`ext/BMOPFOpfExt/nwinding.jl`, and dedicated `n_winding` branches in the Ybus,
per-unit, results and analysis code) that shares no functions with the two-bus
transformer subtypes.

Data shape (`net["transformer"]["n_winding"][id]`):

```json
{
  "windings": [
    {"bus":"hv","terminal_map":["a","b","c","n"],"v_nom":66395.0,"connection":"WYE","r_winding":0.21},
    {"bus":"mv","terminal_map":["a","b","c","n"],"v_nom":14376.0,"connection":"WYE","r_winding":0.31},
    {"bus":"lv","terminal_map":["a","b","c","n"],"v_nom":2402.0, "connection":"WYE","r_winding":0.32}
  ],
  "x_sc": {"1_2":5.0,"1_3":5.0,"2_3":3.0},
  "s_rating": 30.0e6,
  "g_no_load": 0.0, "b_no_load": 0.0
}
```

Conventions (mirroring OpenDSS, the n-winding reference data model):

- `windings` is ordered; **winding 1 is the reference** (`v_nom` are
  phase-to-neutral volts; `N_k = v_nom[k]/v_nom[1]`).
- Inter-winding leakage is stored as **pairwise short-circuit reactances**
  `x_sc["i_j"]` (i<j, Ω, all referred to **winding 1's** base) — the OpenDSS
  `XHL`/`XHT`/`XLT` / `Xscarray` form. Per-winding resistance `r_winding[k]` is in
  Ω on winding k's own base.
- The OPF/Ybus convert the pairwise reactances to the OpenDSS-style **ZB
  short-circuit matrix** referred to winding 1 — an `(n−1)×(n−1)` impedance matrix
  with winding 1 as the reference (`ZB[i,i] = Z_{1,i+1}`,
  `ZB[i,j] = ½(Z_{1,i+1}+Z_{1,j+1}−Z_{i+1,j+1})`). This is **exact for any `n`**:
  `ZB` has exactly `n(n−1)/2` independent entries and reconstructs every pairwise
  reactance (for `n≤3` it coincides with the star/T model). The OPF references
  winding 1 (`V_1ʳ − V_{i+1}ʳ = −Σⱼ ZB[i,j]·I_{j+1}ʳ`, ampere-turn `Σ N_k I_k = 0`)
  so no internal star node is needed; the Ybus uses `Yref = Cᵀ·ZB⁻¹·C` de-referred
  by the turns ratios. An off-diagonal/leg value **may be negative** for `n≥3` —
  physically correct, not an error. The OPF/PF is validated against OpenDSS's own
  3- and 4-winding solves.
- **`WYE` and `DELTA` windings** are both supported. A `WYE` winding's coil
  voltage is line-to-neutral (`v_nom` = L-N, terminal map carries a neutral); a
  `DELTA` winding's coil voltage is line-to-line (`v_nom` = L-L, no neutral, and
  `delta_roll = ±1` picks the vector-group rotation — `-1` matches OpenDSS). The
  `√3`/coil-base factor lives in `v_nom`, so `r_winding`/`x_sc` are on the coil
  base `n_ph·v_nom²/s_rating` and per-unit needs no `√3` correction.

Ingest and export status: PowerIO does not yet emit `n_winding` from its `bmopf`
export, but `from_dss` reconstructs dropped 3-winding units from the `pmd`
export (see the conversion list above); this data model and its JSON Schema
remain the target PowerIO should populate directly. `to_pmd` **skips** `n_winding` transformers with a
warning, since PowerModelsDistribution has no general n-winding model. The OPF/PF
model is validated to match OpenDSS's own 3-winding solve.

### [Per-phase voltage source merge](@id source-merge)

OpenDSS commonly models a three-phase substation source as a `Circuit` element
plus per-phase `VSource` objects (`…_phB`, `…_phC`) — each a *single-phase*
source wired to one phase of a shared bus. PowerIO faithfully mirrors the
OpenDSS object graph, so these arrive as **separate single-phase**
`voltage_source` entries. BMOPF's spec expects exactly one source, and the OPF
reference convention is a single polyphase slack, so `from_dss` reassembles the
bank into one source at the ingest boundary
(`_merge_phase_voltage_sources!`). The merge clears the `W.SPEC.N_SOURCES`
finding that the un-merged bank would otherwise raise.

Sources on a common bus are merged only when the evidence says they are one
source: every member is single-phase (one of `a`/`b`/`c` plus an optional
neutral), the members cover **distinct** phases, none carries
`p_min`/`p_max`/`q_min`/`q_max`/`cost` (a priced/bounded slack is left untouched
— combining per-phase limits is ambiguous), and the members' angles form a
coherent **3-phase-style arrangement** — a `:positive`/`:negative` ±120° rotation
(within 30°) or a `:zero` (all-equal) set. A bank that is instead a quadrature
(≈90°, two-phase) or anti-phase (≈180°, split-phase) set, or simply incoherent,
is **left unmerged** and recorded under
`net["_meta"]["merged_voltage_sources"]["declined"]` with the recognised
`arrangement` so the reason is specific.

Phase order in the merged source is **physical-label-driven** — always
`a`,`b`,`c` (positive-sequence rotation) followed by `n`, regardless of the order
the `VSource` objects appeared in the file. The per-phase angles are preserved
**verbatim** and are never used to permute conductors: the terminal label is
authoritative for which physical conductor the source feeds (everything else in
the network references that label), while the angle is independent phasor data.
The angles serve only to *disambiguate* whether the bank is one coherent source
and which arrangement it carries. A negative-sequence rotation (angles disagree
with the a→b→c labelling) or a zero-sequence set (all phases co-phasal) is still
merged faithfully, but flagged on the group note as a likely modeling error. The
merge is recorded under `net["_meta"]["merged_voltage_sources"]`. Independently of
the merge, [`provenance_analysis`](@ref) classifies **every** polyphase source's
stored angles and raises `W.PROV.SOURCE_ZERO_SEQUENCE` /
`W.PROV.SOURCE_NEGATIVE_SEQUENCE` / `W.PROV.SOURCE_INCOHERENT_ROTATION` (see
[Findings](findings.md)), so an already-polyphase degenerate source is caught too.

### Pricing the slack source

The OpenDSS circuit object is simultaneously a voltage reference and an
implicit unbounded power injection. The BMOPF `voltage_source` captures **both**:
it is the network's current slack (see [Voltage source as current slack](opf.md#source-slack)).
What's missing for a well-posed cost objective on a raw utility dataset (no
generators at all) is a *price* on that imported power.

`from_dss` imports the source **without** a price (`from_dss` does not add a
`cost`). The [augmentation pass](augmentation.md) supplies one: it attaches a
per-phase **`cost`** to the source itself (default 1.0 \$/kWh, kwarg
`slack_cost`), so minimum-cost dispatch equals loss minimisation. No flow
bounds are added, so the source stays an unbounded slack, and no auxiliary
generator is created — the cost lives on the `voltage_source`.

## PMD field mapping (`to_pmd`)

[`to_pmd`](@ref) exports a BMOPF data model to a PowerModelsDistribution
ENGINEERING dict. The same field mapping (read in reverse) describes how a PMD
ENGINEERING dict maps onto BMOPF, which is useful when comparing against
PMD-based tooling.

### Scaling and basic field mapping

- Voltages: PMD `vm` (per-unit on `voltage_scale_factor`) → volts;
  `va` degrees → **radians**.
- Powers: PMD values × `power_scale_factor` → W/var/VA.
- Terminals: PMD integers `1,2,3 → "1","2","3"`, `4 → "n"`.
- PMD enum values (`WYE`, `DELTA`, …) → strings.
- Unrecognised PMD fields are preserved per component under a `_pmd`
  sub-dict — nothing is silently dropped; `to_pmd` merges them back.
- Line lengths and per-length linecode values arrive from PMD already in
  metres / Ω-per-metre (PMD normalises DSS units internally).

### Load configuration

The spec distinguishes `SINGLE_PHASE` (any two nodes) from `WYE` (4-terminal
midpoint return). 2-terminal loads are `SINGLE_PHASE`; `to_pmd` maps
`SINGLE_PHASE` back to a PMD 2-terminal "wye" load.

### Transformer impedance bases

PMD and OpenDSS give per-winding resistance `rw` (%) and pair-wise leakage
`xsc`/`xhl/xlt/xht` (%), both on the winding's own kVA/kV² base.
BMOPF stores ohms on each winding's own voltage base.

**`single_phase`** (2-winding, Γ-model):

```
Z_base,from = v_nom_from² / s_rating
Z_base,to   = v_nom_to²   / s_rating
r_series_from = rw₁ · Z_base,from
r_series_to   = rw₂ · Z_base,to
x_series_from = (xhl / 2) · Z_base,from    # half of pair leakage on each side
x_series_to   = (xhl / 2) · Z_base,to
```

**`center_tap`** (coupled-coil 3-winding — star-network leakage conversion required):

OpenDSS specifies three pair-wise leakage values `XHL`, `XLT`, `XHT` (%).
These are **not** split evenly — they must be converted via the star (Steinmetz)
network formula before storing. [`from_dss`](@ref) does this automatically
(recovering the values from PowerIO's `pmd` export); the formulas below are for
hand-built nets:

```
x_series_from = (XHL + XHT − XLT) / 2  ×  Z_base,from / 100
x_series_to   = (XHL + XLT − XHT) / 2  ×  Z_base,to   / 100
```

For the common symmetric case `XHT = XHL` (both legs same leakage to HV),
this simplifies to `x_series_from = (XHL − XLT/2) × Z_base,from / 100`
and `x_series_to = (XLT/2) × Z_base,to / 100`.

!!! warning
    Using `XHL/2` for both sides (copying the 2-winding formula) produces
    identical leg voltages regardless of load imbalance.  The error is
    ~0.4–0.5 V per leg under a 3 kW imbalance on a 120 V feeder.

Resistance maps directly per winding:

```
r_series_from = rw₁ · Z_base,from      # wdg1 (HV)
r_series_to   = rw₂ · Z_base,to        # wdg2 = wdg3 for a symmetric unit
```

Note: `v_nom_to` is the **per-leg** voltage (e.g. 120 V), not the full
secondary span (240 V).

**No-load branch** (applies to both `single_phase` and `center_tap`):

OpenDSS places the exciting (no-load) branch across **winding 2** — verified
against its `Yprim` — so `%noloadloss`/`%imag` (`cmag`) convert to SI
admittances on winding 2's coil voltage `V_stamp` (the per-leg LV voltage for
`center_tap`; the to-winding voltage for `single_phase`). The magnetising
branch is inductive, so `b_no_load` is **negative**:

```
V_stamp = v_nom_to (coil voltage of winding 2)
g_no_load =  (%noloadloss / 100) · s_rating / V_stamp²    (S)
b_no_load = -(%imag       / 100) · s_rating / V_stamp²    (S)
```

Both fields are omitted when zero.

**`wye_delta` / `delta_wye`** (2-winding, per-winding T-model):

These now use the same per-winding field set as `single_phase` — separate
`r/x_series_from` (wye/primary winding) and `r/x_series_to` (delta/secondary
winding), plus a `g/b_no_load` core-loss branch — matching the OpenDSS /
PMD `eng2math` reference loss network. The series impedance enters the OPF as
a voltage drop on the winding currents behind the ideal Yd/Dy transform; the
delta side is no longer assumed ideal.

```
Z_base,from = v_nom_from² / s_rating
Z_base,to   = v_nom_to²   / s_rating
r_series_from = rw₁ · Z_base,from
r_series_to   = rw₂ · Z_base,to
x_series_from = xsc₁ · Z_base,from     # PMD lumps all leakage on winding 1
x_series_to   = 0                      # 2-winding star: LV branch is zero
```

The no-load branch is on **winding 2** (the to side): a delta of branches
across the LV delta coils for `wye_delta`, phase-to-neutral on the LV wye for
`delta_wye`. `V_stamp` is winding 2's coil voltage — the full line-to-line
`v_nom_to` for a delta winding 2, the line-to-neutral `v_nom_to/√3` for a wye
winding 2:

```
g_no_load =  (noloadloss) · s_rating / V_stamp²   # noloadloss = %noloadloss / 100
b_no_load = -(cmag)       · s_rating / V_stamp²   # cmag       = %imag       / 100
```

!!! note "Leakage placement"
    For a 2-winding unit PMD's star conversion (`_sc2br_impedance`) puts the
    *entire* `xhl` leakage on the winding-1 (HV) branch, with **zero** on the
    LV branch — not an even split. BMOPFTools follows that convention for
    `wye_delta`/`delta_wye`. The lumped single-impedance form `from_dss` emits
    is migrated onto these fields at parse time — see
    [Transformer impedance on ingest](#Transformer-impedance-on-ingest).
    `to_pmd` writes the per-winding fields back to PMD `rw`/`xsc`.

### `to_pmd` transformer specifics

- **No-load branch**: `noloadloss = g_no_load / Y_base` and
  `cmag = |b_no_load| / Y_base` — `cmag` carries the magnetising susceptance
  only, mirroring the ingest convention above (where `b_no_load` is
  deliberately left at 0, `cmag` is 0 too; core loss is never double-counted
  as magnetising current).
- **Fixed tap**: a `tap ≠ 1` exports as PMD `tm_set = [fill(tap, n_ph), fill(1, n_ph)]`
  with `tm_fix = true` — the same `N_eff = (v_nom_from/v_nom_to)·tap`
  convention, so a fixed off-nominal tap round-trips exactly. Free-tap bounds
  (`tap_min`/`tap_max`), per-winding current limits (`i_max_from`/`i_max_to`),
  and regulator `tap_ratio` have no faithful counterpart in this exporter and
  are dropped **with a warning**.
- **`center_tap` is skipped with a warning**: the split-phase unit needs PMD's
  3-winding representation, which this exporter does not implement; emitting a
  2-winding WYE-WYE with a 3-terminal secondary would be malformed.
- **Settings**: `to_pmd(net; frequency=..., sbase=...)` sets
  `settings.base_frequency` / `settings.sbase_default` (defaults 50 Hz,
  1 MVA). The optional network-level `meta.frequency` (populated on ingest —
  see below) is *not* read automatically; pass `frequency = net["meta"]["frequency"]`
  when you want the export to reflect it.

## [OpenDSS export (`to_dss`)](@id to-dss-export)

[`to_dss`](@ref) is the inverse of [`from_dss`](@ref): it serialises a BMOPF data
model to BMOPF JSON (via [`write_bmopf`](@ref)) and hands it to PowerIO's DSS
writer, which emits OpenDSS text.

```
BMOPF data model ──write_bmopf──► BMOPF JSON ──PowerIO.jl──► OpenDSS .dss text
```

`to_dss(net)` returns the generated text and PowerIO's fidelity-loss warnings;
`to_dss(net, path)` writes the text to `path` (creating parent directories) and
returns the warnings. A `name` keyword overrides the circuit name without
mutating the input dict.

BMOPF terminal labels (`"a"`, `"b"`, `"c"`, `"n"`) are accepted by the writer and
re-normalised to OpenDSS numeric nodes (`.1`, `.2`, `.3`, `.0`); merged polyphase
sources are re-expanded by the writer as needed.

!!! note "Valid, not (yet) validated"
    The current target is **valid** OpenDSS — text that PowerIO (and OpenDSS)
    can parse and solve — not a byte-faithful or power-flow-validated round trip.
    A `from_dss → to_dss` cycle is not guaranteed to reproduce the original file
    or to solve identically in OpenDSS; the warnings PowerIO returns list what its
    writer had to assume or could not represent. Byte-fidelity and an OpenDSS
    power-flow cross-check are future work, tracked alongside the known lossy
    points below (earth-terminal collapse, identifier case-folding, transformer
    fidelity). Every `test/data/pf_comparison` fixture is round-tripped
    (DSS → BMOPF → DSS) and the output re-parsed to guard validity.

## Known limitations

- **Transformer leakage / core shunt (from `from_dss`).** PowerIO's `bmopf`
  export is lossy for transformers: it drops the no-load shunt for every subtype,
  collapses the `center_tap` 3-winding leakage, and refers the `delta_wye`
  delta-side leakage to the wrong base. `from_dss` re-derives the leakage and the
  core-loss shunt from PowerIO's richer `pmd` export for `single_phase`,
  `wye_delta`, `delta_wye` and `center_tap` (`_recover_transformer_params_from_pmd!`),
  so the OPF/Ybus match OpenDSS. The magnetising susceptance (`b_no_load`) is not
  recovered (small, ambiguous sign in the phase-to-ground stamp); `n_winding`
  leakage is taken straight from `pmd` (`x_sc`) and not re-derived.
- **Grounding reactors need `phases=1` (gotcha).** PowerIO silently drops a
  `New Reactor.grnd ... bus2=X.0` neutral-grounding reactor unless it declares
  `phases=1` (OpenDSS itself tolerates the omission). Without it the grounded
  neutral floats — a wye-load `delta_wye` then has no neutral reference and the
  power flow diverges. Always write grounding reactors with an explicit `phases=1`.
- **Earth terminal `"5"` → bus neutral (from `from_dss`).** PowerIO keeps the
  OpenDSS earth node as terminal `"5"`. BMOPFTools routes it to the bus neutral
  on ingest (see [The earth terminal](@ref earth-terminal)), which
  grounds an earthed star point through the bus neutral rather than solidly.
  Native earth resolution upstream is tracked as a PowerIO.jl issue.
- **Wye-wye three-phase transformers** have no spec type. They are parked
  in `single_phase` with 3-phase terminal maps and flagged
  (`W.SPEC.XFMR_TMAP_ARITY`); the faithful decomposition into three
  single-phase units is future work.
- **RegControl / tap controllers** do not convert; see the
  regulator-pattern detection in the [methodology notes](methodology.md).
- **Regulator subtypes** (`single_phase_autotransformer`, `open_delta_regulator`)
  are OPF-native data-model objects but are **not produced by `from_dss`** —
  it does not recognise OpenDSS `AutoTrans`/`RegControl` or open-delta banks as
  these objects, and `to_pmd` does not emit them. They are authored directly in
  BMOPF JSON. See [conventions](conventions.md) and the [OPF reference](opf.md).
