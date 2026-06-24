# Conversion guide

This page documents both directions of format conversion:

- **Ingest** — OpenDSS `.dss` models are read by [`from_dss`](@ref) and emitted
  as a BMOPF data model.
- **Export** — a BMOPF data model is written to a PowerModelsDistribution
  ENGINEERING dict by [`to_pmd`](@ref).

Each section records the deliberate decisions in those converters — the things
you would otherwise have to discover by diffing data.

## OpenDSS ingest (`from_dss`)

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
- **Transformer impedance normalisation** — PowerIO's lumped single-impedance
  form is migrated onto the per-winding fields the OPF reads (below).
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
Z_base,from = v_ref_from² / s_rating
Z_base,to   = v_ref_to²   / s_rating
r_series_from = rw₁ · Z_base,from
r_series_to   = rw₂ · Z_base,to
x_series_from = (xhl / 2) · Z_base,from    # half of pair leakage on each side
x_series_to   = (xhl / 2) · Z_base,to
```

**`center_tap`** (3-winding, T-model — star-network leakage conversion required):

OpenDSS specifies three pair-wise leakage values `XHL`, `XLT`, `XHT` (%).
These are **not** split evenly — they must be converted via the star (Steinmetz)
network formula before storing:

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

Note: `v_ref_to` is the **per-leg** voltage (e.g. 120 V), not the full
secondary span (240 V).

**No-load branch** (applies to both `single_phase` and `center_tap`):

OpenDSS `%noloadloss` and `%imag` (or `cmag`) convert to SI admittances
at the HV terminals:

```
Y_base = s_rating / v_ref_from²
G = (%noloadloss / 100) · Y_base                      → g_no_load  (S)
Y_mag = cmag · Y_base          # cmag = %imag/100 · s_rating/v_ref_from
B = sqrt(Y_mag² − G²)                                 → b_no_load  (S)
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
Z_base,from = v_ref_from² / s_rating
Z_base,to   = v_ref_to²   / s_rating
r_series_from = rw₁ · Z_base,from
r_series_to   = rw₂ · Z_base,to
x_series_from = xsc₁ · Z_base,from     # PMD lumps all leakage on winding 1
x_series_to   = 0                      # 2-winding star: LV branch is zero
```

The no-load branch maps as for the two-winding types:

```
Y_base = s_rating / v_ref_from²
g_no_load =  (noloadloss) · Y_base       # noloadloss = %noloadloss / 100
b_no_load = -(cmag)       · Y_base       # cmag       = %imag       / 100
```

!!! note "Leakage placement"
    For a 2-winding unit PMD's star conversion (`_sc2br_impedance`) puts the
    *entire* `xhl` leakage on the winding-1 (HV) branch, with **zero** on the
    LV branch — not an even split. BMOPFTools follows that convention for
    `wye_delta`/`delta_wye`. The lumped single-impedance form `from_dss` emits
    is migrated onto these fields at parse time — see
    [Transformer impedance on ingest](#Transformer-impedance-on-ingest).
    `to_pmd` writes the per-winding fields back to PMD `rw`/`xsc`.

## Known limitations

- **Lumped transformer impedance (from `from_dss`).** PowerIO emits
  `wye_delta`/`delta_wye` units with a single lumped `r_series`/`x_series`
  rather than a per-winding T-model. BMOPFTools normalises this onto
  `r_series_from`/`x_series_from` on ingest (see
  [Transformer impedance on ingest](#Transformer-impedance-on-ingest)), so the
  OPF/Ybus see a nonzero leakage impedance — but the leakage is all on the
  from-winding (the to-winding branch is zero). A faithful per-winding split
  would require per-winding emission upstream (tracked as a PowerIO.jl issue).
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
