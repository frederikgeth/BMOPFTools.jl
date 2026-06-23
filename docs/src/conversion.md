# Conversion guide

[`to_pmd`](@ref) exports a BMOPF data model to a PowerModelsDistribution
ENGINEERING dict. This page documents every deliberate decision in that
converter — the things you would otherwise have to discover by diffing data.
The same field mapping (read in reverse) describes how a PMD ENGINEERING dict
maps onto BMOPF, which is useful when comparing against PMD-based tooling.

> **Note.** OpenDSS networks are now ingested directly by [`from_dss`](@ref)
> (via PowerIO.jl), which emits BMOPF JSON without going through PMD. The
> earlier `from_pmd` parser has been removed.

## Scaling and basic field mapping

- Voltages: PMD `vm` (per-unit on `voltage_scale_factor`) → volts;
  `va` degrees → **radians**.
- Powers: PMD values × `power_scale_factor` → W/var/VA.
- Terminals: PMD integers `1,2,3 → "1","2","3"`, `4 → "n"`.
- PMD enum values (`WYE`, `DELTA`, …) → strings.
- Unrecognised PMD fields are preserved per component under a `_pmd`
  sub-dict — nothing is silently dropped; `to_pmd` merges them back.
- Line lengths and per-length linecode values arrive from PMD already in
  metres / Ω-per-metre (PMD normalises DSS units internally).

## The earth terminal (OpenDSS `.0`)

PMD maps the OpenDSS earth reference node `.0` to terminal **5**. BMOPF has
no earth terminal — ground is implicit — so `from_pmd` resolves every
occurrence:

| PMD pattern | BMOPF result |
|---|---|
| bus `terminals` containing 5 | filtered from `terminal_names` |
| bus `grounded = [5]` | dropped (earth is not a bus terminal) |
| self-loop line with `t_connections = [5]` (a neutral-to-earth **reactor**) | a `shunt` at the bus with `G = R/(R²+X²)`, `B = −X/(R²+X²)` on the neutral |
| voltage source with `connections = [1,2,3,5]` (neutral bonded to earth) | earth entry dropped, `vm`/`va` sliced with the same mask |
| transformer wye winding `connections = [.., 5]` (star point earthed directly) | re-routed to the bus **neutral** terminal, with a warning |

The last row is a genuine modeling change: the star point is then earthed
through that bus's grounding impedance rather than solidly. The warning
makes it visible; the alternative (an extra perfectly-grounded terminal) is
exact but non-standard — see `docs/taskforce_feedback.md` item 7.

## Pricing the slack source

The OpenDSS circuit object is simultaneously a voltage reference and an
implicit unbounded power injection. The BMOPF `voltage_source` captures **both**:
it is the network's current slack (see [Voltage source as current slack](opf.md#source-slack)).
What's missing for a well-posed cost objective on a raw utility dataset (no
generators at all) is a *price* on that imported power. `from_pmd` therefore
attaches a per-phase **`cost`** to the source itself:

- per-phase `cost` (kwarg `slack_cost`, default 1.0 \$/kWh) — minimum-cost
  dispatch then equals loss minimisation;
- no flow bounds are added, so the source remains an unbounded slack;
- no auxiliary generator is created — the cost lives on the `voltage_source`.

Disable with `from_pmd(eng; add_slack_generator=false)` (the kwarg name is kept
for backwards compatibility; it now controls the source cost, not a generator).
The augmentation pass applies the same default — see [Augmentation](augmentation.md).

## Load configuration

PMD labels 2-terminal loads "wye"; the spec distinguishes `SINGLE_PHASE`
(any two nodes) from `WYE` (4-terminal midpoint return). `from_pmd`
reclassifies by terminal arity; `to_pmd` maps `SINGLE_PHASE` back to PMD
wye.

## Transformer impedance bases

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
    `wye_delta`/`delta_wye`.

**Legacy single-impedance form.** A network carrying the older single
`r_series`/`x_series` (wye-side lumped, delta ideal) is still accepted: it is
migrated onto `r_series_from`/`x_series_from` with the secondary branch zero,
reproducing the previous ideal-delta behaviour. `to_pmd` writes the
per-winding fields back to PMD `rw`/`xsc`.

## Known limitations

- **Wye-wye three-phase transformers** have no spec type. They are parked
  in `single_phase` with 3-phase terminal maps and flagged
  (`W.SPEC.XFMR_TMAP_ARITY`); the faithful decomposition into three
  single-phase units is future work.
- **Generator costs** do not exist in PMD's ENGINEERING model; after conversion
  only the priced slack source carries a `cost`.
- **`basefreq` mismatches** between linecodes and the circuit are a
  parse-time phenomenon (PMD warns during `parse_file`); they are not
  recoverable from the ENGINEERING dict and hence not visible to
  BMOPFTools.
- **RegControl / tap controllers** do not convert; see the
  regulator-pattern detection in the [methodology notes](methodology.md).
- **Regulator subtypes** (`single_phase_autotransformer`, `open_delta_regulator`)
  are OPF-native data-model objects but are **not produced by the converters** —
  `from_dss`/`from_pmd` do not recognise OpenDSS `AutoTrans`/`RegControl` or
  open-delta banks as these objects, and `to_pmd` does not emit them. They are
  authored directly in BMOPF JSON. See [conventions](conventions.md) and the
  [OPF reference](opf.md).
