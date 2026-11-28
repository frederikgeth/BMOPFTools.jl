# Augmentation reference

Passes, flags, defaults and recipe fields of the case-preparation operations,
the manifest they return, and their API. For why the operations run in this
order and how to read their output, see the
[Case augmentation](augmentation.md) guide.

## [`fix_case` — structural repairs](@id fix)

Ten passes run in order. Each is independently controlled by the
corresponding `apply_*` flag in [`FixRecipe`](@ref). Review the manifest against
your study: removing disconnected assets changes its scope. Finite-impedance
idealization and grounding changes are opt-in approximations.

| # | Pass | Flag | Default | Effect |
|---|---|---|---|---|
| 1 | Largest connected component | `apply_largest_component` | `true` | Drops buses, lines, loads, generators, and shunts that have no path to a voltage source. |
| 2 | Simplify network | `apply_simplify_network` | `true` | Merges consecutive same-linecode series lines; removes dangling stub lines (wraps [`simplify_network`](@ref)). |
| 3 | Remove zero loads | `apply_remove_zero_loads` | `true` | Deletes loads with `p_nom = q_nom = 0` on all phases — electrically inert. |
| 4 | Low-impedance lines → switches | `apply_low_impedance_to_switch` | `false` | Idealizes lines below 10⁻⁴ Ω as switches. Retains current ratings; skips shunted lines and unsupported extra branch limits. Small finite impedance is still an approximation to zero. |
| 5 | Source bus bounds | `apply_source_bus_bounds` | `true` | Removes satisfied `v_*`, `vpn_*`, and `vpp_*` magnitude bounds only when the required terminal voltages are explicitly fixed. Retains inconsistent, unknown, sequence and angle bounds; preserves `va_nom`. |
| 6 | Adjacent current bounds | `apply_adjacent_current_bounds` | `false` | Infers `i_max` for lines/switches that lack it from directly adjacent elements (one hop). Transformers contribute `s_rating / (√3 × V_ref)`; lines and switches propagate their own `i_max`. Takes the minimum over all adjacent bounds. |
| 7 | Perfect grounding | `apply_perfect_grounding` | `false` | Promotes grounding shunts whose `1/\|Y₁₁\| < threshold` (default 0.1 Ω) to `perfectly_grounded_terminals` and removes the shunt. **Changes OPF physics** (forces `V_n = 0`). |
| 8 | Remove earthed ideal conductors | `apply_remove_earthed_ideal_conductors` | `true` | Drops ideal conductors whose two ends are both perfectly grounded. Exact. |
| 9 | Capacitive shunts → capacitors | `apply_shunt_to_capacitor` | `false` | Re-represents a purely capacitive shunt as a first-class `capacitor`, only when the round trip is exact. |
| 10 | Snap placeholder transformer leakage | `apply_snap_transformer_impedance` | `false` | Zeroes a two-winding transformer's tiny non-zero series impedance (`\|Z\| < snap_transformer_z_min_pu`, default 0.1 % on the rating base). |

**Pass 8 — earthed ideal conductors.** An ideal conductor is a closed switch
pole, or a line conductor with zero self and mutual impedance. If both its ends
are perfectly grounded, it closes a loop through the earth: nothing determines
its current and the OPF rejects the case (`E.INT.IDEAL_LOOP`). Both ends are at
zero volts, so the removal is **exact** and no other quantity changes. The pass
runs after passes 4 and 7 because together they create the pattern. The
surviving conductors keep their impedance and shunt entries (a shunt matrix
written smaller than the conductor count is read with its omitted entries as
zero). A line that uses a shared linecode gets a reduced copy; an element left
without conductors is removed.

**Pass 9 — capacitive shunts.** The pass targets shunts with G ≈ 0, as flagged
by `I.PROV.SHUNT_LIKELY_CAPACITOR`. The susceptance matrix `B` is
**fingerprinted** by sign pattern, sparsity and row sums into `SINGLE_PHASE`,
`WYE`, or `DELTA` (or a phase-to-ground bank → WYE/SINGLE_PHASE on a grounded
neutral), and the nameplate `q_rated = B·v_nom²` is recovered (`v_nom` = bus
P-N nominal, or √3·P-N = L-L for DELTA). The conversion is committed **only when
the emitted capacitor's susceptance reproduces `B` exactly** (round-trip guard),
so it is faithful by construction. Anything ambiguous or unsupported — mixed
return paths, `n>3` cyclic banks, a star with no name-resolvable neutral, no
grounded return for a phase-to-ground bank, or no resolvable nominal — is left
untouched.

**Pass 10 — placeholder transformer leakage.** The tiny impedance this pass
targets (flagged by `W.DOM.XFMR_LOW_IMPEDANCE`) is typically a placeholder for
zero written by an admittance-based tool. It is the transformer analogue of
pass 4. Genuine leakage (1–15 %) is never touched; n_winding units are skipped
because their rating base differs.

!!! note "Why exact zero, not a small ε (passes 4 and 10)"
    Both passes replace a near-zero impedance with an *exact* zero handled
    semantically (a switch, or the ideal-transformer constraint) rather than a
    small numerical placeholder. This is deliberate: a small `ε` impedance is the
    single most ill-conditioned point on the whole axis, whereas an exact zero is
    well-conditioned in the IVR formulation. See
    [Zero impedance: represent it honestly](@ref zero-impedance) in the developer
    guide for the conditioning argument and the figure.

```@docs
fix_case
FixRecipe
```

## `augment_case` — audited study assumptions

The passes run in order:

| Pass | Writes | Control | Default |
|---|---|---|---|
| 0 | `v_declared` (voltage-level snapping) | TOML `[augment.voltage_snap]` | off |
| 1 | voltage bounds; opt-in angle-difference bounds | `apply_v_bounds`, `apply_vpn_bounds`, `apply_vpp_bounds`, `apply_vneg_bounds`, `apply_va_diff_bounds` | on (angle bounds off) |
| 2 | linecode `i_max`; opt-in `s_max` → `i_max` conversion | `apply_thermal`, `apply_power_to_current` | off |
| 3 | slack cost, generator `q_min`/`q_max` | `apply_slack_generator`, `apply_q_bounds` | on |
| 4 | IBR dispatch box | `apply_ibr` | on |
| 5 | smart-IBR Volt-var/Volt-watt fields | TOML `[augment.smart_ibr]` | off |
| 6 | DC bus bounds, DC source limits | `apply_dc` | on |

The `apply_*` flags are fields of [`AugmentationRecipe`](@ref); passes 0 and 5
are enabled through the TOML `config`
(`augment_case(net; config = load_config("my.toml"))`). **No pass overwrites an
existing value** — augmentation only fills gaps. The one rewrite is a shape
change: after pass 3, a single-phase generator or IBR whose `i_max` has length 1
gets that value duplicated to the per-conductor `[phase, neutral]` form (rule
`per_conductor_imax_single_phase`), which leaves the limit unchanged.

### Pass 0 — Voltage-level snapping (optional)

Imported cases frequently carry LV transformers rated 240 or 250 V, so the
derived `v_nom` is non-standard and the bounds would be referenced to it. When
enabled, `augment_case` first snaps each bus's `v_nom` to the nearest
standardized level (IEC 60038 / ANSI C84.1) and writes the result as
`v_declared`, so the pass 1 bounds reference the standard voltage (e.g. 230 V).

Configured in the TOML `config` (off by default — no behavior change unless
opted in):

```toml
[augment.voltage_snap]
enabled   = true        # opt-in
preset    = "IEC_50Hz"  # "IEC_50Hz" | "ANSI_60Hz" | "none"
tolerance = 0.10        # snap only if |v_nom / std − 1| ≤ tolerance
levels    = []          # extra phase-to-neutral volts, merged with the preset
```

A value outside every tolerance band is left unchanged, so genuinely
non-standard buses (e.g. a real 277 V LV) are preserved. Levels are
phase-to-neutral (per-conductor) volts — the same basis as `v_nom`; custom
`levels` follow the same convention (line-to-line ÷ √3). A bus that already
carries an explicit `v_declared` is never re-snapped. Each snap is recorded in
the manifest as a `v_declared` entry with rule `IEC60038_snap`.

### Pass 1 — Voltage bounds

Sets `v_min`/`v_max`, `vpn_min`/`vpn_max`, `vpp_min`/`vpp_max`, and
`vuf_max` on supported buses that lack them. `vpn_*` are written as per-phase
arrays and `vpp_*` as per-pair arrays (see [Conventions](conventions.md)); the
OPF consumes them in those shapes.

Bounds are expressed as fractions of a **declared supply voltage** — the
nominal voltage defined by the relevant power-quality standard, which may
differ from the transformer rated voltage in the network model (e.g. a 240 V
transformer in a grid declared at 230 V per EN 50160). The declared voltage
is resolved per bus in priority order:

1. `bus["v_declared"]` — explicit field set at import time (e.g. authored in
   the BMOPF JSON)
2. the optional voltage-snap pass (pass 0) — writes `v_declared` by snapping
   `v_nom` to a standard level; never overrides an explicit value
3. `AugmentationRecipe` fields `v_declared_lv` / `v_declared_mv` /
   `v_declared_hv` — regional fallback (e.g. `v_declared_lv = 230.0` for
   Europe/Australia)
4. `v_nom` from `voltage_level_analysis` — last resort when none of
   the above is set

#### [Solver regularization bounds (`v_min` / `v_max`)](@id Solver-regularisation-bounds-(v_min-/-v_max))

`v_min` and `v_max` are **hyperparameters**, not power-quality guarantees.
They are loose guard bounds, deliberately wider than the power-quality window,
that keep the solver away from non-physical voltage solutions without binding
at realistic operating points. The same values are applied to all buses
regardless of voltage level.

| Field | Default (pu of `v_declared`) | Purpose |
|---|---|---|
| `v_min` | 0.85 | Lower regularization bound — disable with `v_min_pu = nothing` |
| `v_max` | 1.15 | Upper regularization bound — disable with `v_max_pu = nothing` |

**Source buses** receive `v_min`/`v_max` only — `vpn`/`vpp`/`vuf` bounds
are meaningless there because the voltage source pins the terminal voltages.

#### Power-quality bounds

Applied to all non-source buses. Percentage windows follow EN 50160:2010.

| Bound | Level | Default (pu of `v_declared`) | Standard |
|---|---|---|---|
| `vpn_min`/`vpn_max` | LV (≤ 1 kV) | 0.90 / 1.10 | EN 50160:2010 §3.5/§3.6, 95 %-of-week ±10 % |
| `vpn_min`/`vpn_max` | MV (1–35 kV) | 0.94 / 1.06 | DSO planning practice ±6 %, budgets for LV voltage drop |
| `vpp_min`/`vpp_max` | LV | 0.90 / 1.10 | EN 50160:2010 §3.5, same ±10 % band |
| `vpp_min`/`vpp_max` | MV | 0.94 / 1.06 | Same ±6 % band as `vpn` |
| `vpp_min`/`vpp_max` | HV (> 35 kV) | 0.95 / 1.05 | Transmission planning ±5 % |
| `vuf_max` | Three-phase | 0.02 (dimensionless) | Instantaneous study limit on negative/positive sequence magnitude, not time-aggregated standards compliance |

Which bounds a bus receives depends on its terminals:

- **Four-wire buses** (have a neutral terminal) receive `vpn` bounds, since
  customers experience the phase-to-neutral voltage; `vpp` bounds are also
  set when ≥ 2 phase terminals are present.
- **Three-wire buses** (no neutral terminal) receive `vpp` and, with three
  phases, `vuf_max`; phase-to-ground regularization remains a separate study
  policy.
- **Single-phase buses** (one phase terminal + neutral) receive `vpn` but not
  `vpp` or sequence limits.
- **Unassigned buses** (islanded from all voltage sources) are skipped; the
  manifest records a note.

Pair nominal voltages use `va_nom` when supplied. A center-tapped split-phase
zone uses twice the per-leg nominal (120 V → 240 V); a full three-phase bus uses
√3. An ambiguous two-phase bus is skipped with a manifest entry until its
nominal angles are supplied. Sequence limits require all three phase terminals.

#### Intra-bus angle-difference bounds (opt-in)

Disabled by default (`apply_va_diff_bounds = false`). When enabled, the pass
injects the centering reference `va_nom` and a symmetric window
`va_diff_min`/`va_diff_max = ∓va_diff_window_rad` (default ±30°) on multiphase,
non-source buses whose nominal phasor arrangement is unambiguous:

| Bus | `va_nom` (rad) | Meaning |
|---|---|---|
| three-phase (3 phase terminals) | `[0, −2π/3, 2π/3]` | positive-sequence |
| split-phase (`center_tap`-fed, 2 legs) | `[0, π]` | anti-phase legs |

The OPF bounds the *centered* difference `θⱼ − θₖ − (va_nom[j] − va_nom[k])`, so
the window pins the correct rotation while staying inside the tangent-valid
(−90°, 90°) regime (see [Bus limits](opf.md)). Single-phase and ambiguous buses
are skipped — the offset is never guessed.

### Pass 2 — Thermal limits

Off by default (`apply_thermal = false`). When enabled, the pass infers a
heuristic `i_max` for linecodes that lack it by matching the diagonal series
resistance R₁₁ against a lookup table of representative conductor
cross-sections and their ampacities. This is a **synthetic estimate**, not a
standards lookup: R₁₁ is the *series* resistance (the conductor's AC resistance
**plus** the Carson earth-return coupling), so on its own it does not uniquely
identify a conductor's material, construction class, cross-section, or
installation method. Treat the result as a plausible default; a high-confidence
rating requires the conductor material/class and installation method to be known
independently.

| Cross-section (mm²) | R₁₁ (mΩ/m at 20 °C) | Underground XLPE (A) | Overhead (illustrative, A) |
|---|---|---|---|
| 4   | 4.950 | 34  | —   |
| 6   | 3.300 | 41  | —   |
| 10  | 1.980 | 57  | 70  |
| 16  | 1.240 | 76  | 95  |
| 25  | 0.787 | 104 | 130 |
| 35  | 0.559 | 134 | 160 |
| 50  | 0.396 | 170 | 200 |
| 70  | 0.283 | 220 | 260 |
| 95  | 0.209 | 277 | 320 |
| 120 | 0.164 | 326 | 375 |
| 150 | 0.132 | 386 | 430 |
| 185 | 0.107 | 451 | 490 |
| 240 | 0.082 | 541 | 600 |

**The columns.** The R₁₁ values are representative **maximum DC resistances at
20 °C** for standard conductor sizes — the quantity IEC 60228:2004 actually
specifies (its procedure measures DC resistance), used here only as a size
fingerprint, not an AC or earth-return-inclusive value. The underground column
is loosely calibrated to IEC 60364-5-52:2009 Table B.52 installation ampacity
(70 °C conductor, single circuit, in-ground or in-air); the overhead column is
an illustrative overhead rating, **not** an IEC 60364-5-52 value (that standard
covers LV installation ampacity, not an overhead-AAC catalog). The table as a
whole is a heuristic default and is deliberately *not* tagged as an
IEC-conformant result.

**Matching.** The match uses a 15 % relative tolerance on R₁₁. If no table row
falls within tolerance the linecode is skipped and the manifest records
`"R₁₁ outside lookup range"`. Two caveats follow from the table. The R₁₁ column
holds copper values (close to the IEC 60228 class 5 flexible-copper maxima), so
an aluminum conductor, whose resistance is about 1.6 times that of copper of the
same section, matches a row one or two standard sizes smaller and receives that
copper size's rating. And when a linecode's R₁₁ includes Carson's earth-return
term (about 0.05 mΩ/m at 50 Hz), large sections shift by more than the
tolerance: a 240 mm² conductor then reads about 60 % above its table value and
is skipped or matched to a smaller row.

**Eligibility and tagging.** Existing ratings are never overwritten. The
`thermal_min_confidence` keyword (default `:medium`) gates linecodes by their
impedance classification (`distinct`: `:high`, `near_balanced`: `:medium`,
others: `:low`); it does **not** measure ampacity confidence. Even a distinct
matrix does not establish material, conductor size, or installation. Every
written rating is tagged `:heuristic` (rule `heuristic_ampacity_estimate`); the
`:high`/`:medium`/`:low` tags appear only on manifest entries that record a
skipped linecode, where they report its impedance classification.
`meta.provenance.thermal_estimates[linecode_id]` records the impedance
classification, assumed construction category, equal-conductor-rating
assumption, and lack of material/installation verification; it survives
`write_bmopf`/`parse_bmopf`.

**Neutral conductor rating.** The neutral conductor is assigned the same
`i_max` as the phase conductors. IEC 60364-5-52:2009 §523 permits a reduced
neutral cross-section above 16 mm² under balanced loading conditions, but the
appropriate reduction is installation- and load-specific and is not applied
automatically. Set the neutral entry of `i_max` in the linecode manually, or
pass a pre-computed `i_max` vector (which will not be overwritten) if a derated
rating is required.

**Power → current conversion (opt-in).** With
`AugmentationRecipe(apply_power_to_current = true)`, any line or switch that
carries an apparent-power limit `s_max` but **no** `i_max` gets an equivalent
per-conductor current limit `i_max = s_max / v_ref`, where `v_ref` is the
resolved phase-to-ground reference voltage at the from-bus. Current is the
preferred thermal representation for conductors (no voltage-reference ambiguity,
no neutral degeneracy — see
[current vs. apparent-power limits](opf.md#Current-vs-apparent-power-limits)); the
conversion is exact only at `v_ref`. Transformers are never converted — their
kVA nameplate stays canonical. Each write is recorded in the manifest.

### Pass 3 — Generation

**Slack cost.** The voltage source is itself the network's current slack, so no
slack *generator* is created. If a source has no `cost`, a per-phase cost is
written onto the `voltage_source` (default 1.0 \$/kWh, rule
`TFspec_Eq135_slack_generation`, tagged `:standard`) so imported power is
priced in the objective. No flow bounds are added, so the source can absorb the
network's net active/reactive imbalance. This removes one common cause of
infeasibility, but does not override voltage, thermal, device, or other hard
constraints. Controlled by the recipe's `apply_slack_generator` /
`slack_cost` fields (names kept for backwards compatibility).

**Reactive bounds.** For each generator that has `p_max` defined but lacks
`q_min`/`q_max`, symmetric reactive bounds are derived from the recipe
power-factor setting:

```
Q_max = P_max × tan(arccos(pf))
```

Default `pf = 0.90` (EN 50549-1:2019, LV grid-connected DERs):
Q_max ≈ 0.484 × P_max. The bound scales with `P_max`, not with an apparent-power
nameplate, and is symmetric. Only `pf = 0.90` is recorded as a standard (rule
`EN50549-1:2019_cos_phi_0.90`, `:standard`). Any other value is a study choice,
recorded as `cos_phi_<pf>_P_based` with confidence `:heuristic`:
`q_capability_pf = 0.95`, for example, gives Q_max ≈ 0.329 × P_max, which is not
the IEEE 1547-2018 requirement. IEEE 1547-2018 specifies reactive capability as a fraction of nameplate
apparent power: 44 % injecting and 44 % absorbing for Category B (Q/S = 0.44,
about cos φ = 0.90 at rated kVA), 44 % injecting and 25 % absorbing for
Category A. To model either category, write `q_min`/`q_max` from the kVA
rating directly.

### [Pass 4 — IBR dispatch bounds](@id pass-4-IBR-dispatch-bounds)

`ibr` (inverter-based resource) elements carry a richer model than generators
(an apparent-power nameplate `s_max`, a `topology`, a `prime_mover`, and an
optional smart-IBR `control_profile`). This pass fills their **active and
reactive dispatch box** from the nameplate, leaving the nameplate itself
untouched. Controlled by the recipe's `apply_ibr` flag.

**Active power.** If `p_max` is absent it is derived per phase — from `p_avail`
(split in proportion to the per-phase `s_max` when those ratings are present,
equally across phases otherwise) or, without `p_avail`, from the per-phase
`s_max` ratings. When `p_min` is absent, `PV` gets `p_min = 0` (PV cannot absorb
active power) and `BATTERY` gets `p_min = -p_max` (charge limit assumed equal to
the discharge limit, `:heuristic`).

**Reactive power.** If the IBR references a `control_profile` carrying a
`power_factor` sub-object, `q_min`/`q_max` are *left absent* — the OPF enforces
the exact PF coupling `Q = f(P)` as an equality constraint instead. Otherwise,
for IBRs lacking explicit `q_min`/`q_max`, symmetric bounds are derived from
`p_max` using the recipe's `ibr_default_pf` (EN 50549-1:2019 default
cos φ = 0.90), exactly as for generators; a value other than 0.90 is recorded as
`cos_phi_<pf>_P_based_ibr_default` with confidence `:heuristic`:

```
Q_max = P_max × tan(arccos(pf)),   Q_min = -Q_max
```

STATCOMs and `dc_link_coupled` IBRs are bounded differently; see
[STATCOMs and active power circulation](@ref "STATCOMs and active power circulation").
This pass only *bounds* IBRs that already exist in the case; to place them, see
[Adding IBRs](@ref adding-IBRs-der-placement).

### Pass 5 — Smart-IBR Volt-var/Volt-watt defaults (optional)

Off by default; enabled in the TOML `config` under `[augment.smart_ibr]`
(`enabled = true`, `region = "Aus_A" | "Aus_B" | "Aus_C" | "NZ"`). For every
`control_profile` that declares a `volt_var` or `volt_watt` sub-object, missing
fields (breakpoints, limits, units, references) are filled from the selected
AS/NZS 4777.2:2020 regional preset. A profile without the sub-object gets none,
and fields already present are kept, so a study can pin individual breakpoints.
Each fill is recorded with rule `AS_NZS_4777.2:2020_<region>_<law>_default`.

### Pass 6 — DC network defaults

Controlled by `apply_dc`. A `dc_bus` with `v_dc_nom` and neither `v_dc_min` nor
`v_dc_max` gets signed line-to-ground bounds `v_dc_nom ∓ dc_v_band_frac·|v_dc_nom|`
(default ±10 %). A `dc_source` with a rated injection `p` gets `p_min = 0` and
`p_max = p` (curtailable) where absent.

```@docs
augment_case
AugmentationRecipe
default_recipe
```

## `TransformationManifest`

Every operation on this page returns a [`TransformationManifest`](@ref): one
[`TransformEntry`](@ref) per value written or deliberately skipped, each with
the rule that produced it and a confidence tag, plus the Findings before and
after. How to read the tags is explained in
[Reading the manifest](@ref starting-point).

```@docs
TransformationManifest
TransformEntry
manifest_to_dict
render_manifest
```

### [Serializing the manifest](@id Serialising-the-manifest)

Authors may optionally release the manifest alongside a case. It includes the
resolved recipe and structured Findings; no Task Force submission requires it.
For settings, assumptions, source hashes and experiment summaries together, see
[the case-development log](tutorial_case_development.md). A minimal export is:

```julia
using JSON3

net′, manifest = augment_case(net)
write_bmopf(net′, "feeder_aug.json")
open("feeder_aug_manifest.json", "w") do io
    JSON3.write(io, manifest_to_dict(manifest))
end
```

## Adding generators (DER placement)

`augment_case` does **not** create generation; without dispatchable generators
the OPF is trivial (the slack imports everything). [`add_generators`](@ref)
*places* dispatchable `generator` elements using the semantic and topological
knowledge the library already computes — never randomly. It writes only `bus`,
`terminal_map`, `configuration`, `p_min`, `p_max`, and `cost`; reactive bounds
are left to `augment_case`'s generation pass
([Why this sequence](@ref "Why this sequence")).

Placement is controlled by a [`GeneratorRecipe`](@ref):

- **`strategy`** — `:load_following` (one DER per load bus, phasing inherited
  from the load), `:hosting_capacity` (DERs sized to a fraction of the feeding
  transformer's `s_rating`), or `:topology_targeted` (`topology_mode = :leaves`
  for embedded generation at feeder ends, or `:near_source` for bulk injection).
  Which to choose is a research-design question; see
  [Choosing a placement strategy](@ref "Choosing a placement strategy").
- **filters** — `voltage_levels` (e.g. `[:LV]`), `min_local_load_va`, and
  `skip_source_buses` compose over any strategy.
- **sizing** — `size_basis` (`:fraction_of_local_load`,
  `:fraction_of_transformer_rating`, `:fraction_of_downstream_load`,
  `:fixed_tiers`) with `der_p_fraction`; `:fixed_tiers` reads absolute sizes in
  **W** from `fixed_tier_w`.
- **cost** — `cost_basis` (`:cheaper_than_slack`, `:tiered_by_level`,
  `:uniform`); pricing DERs below the slack makes dispatch non-trivial — the
  solver uses local generation until a voltage or thermal constraint binds.

Every generator field written is recorded as a `TransformEntry` with rule
`DER_PLACEMENT/<strategy>` and confidence `:synthetic` (a design choice, not a
standard), and the run emits `I.DER.PLACED` / `W.DER.NO_CANDIDATES` /
`W.DER.OVERSUPPLY` findings into the manifest's `findings_after`.

```@docs
add_generators
GeneratorRecipe
default_generator_recipe
```

## [Adding IBRs (DER placement)](@id adding-IBRs-der-placement)

[`add_ibrs`](@ref) is the inverter-interfaced counterpart to
[`add_generators`](@ref). Where a `generator` is a thin active-power object, an
`ibr` carries a richer model — an apparent-power nameplate `s_max`, a
`topology` (`FOUR_LEG` / `THREE_LEG` / `SINGLE_PHASE`), a `prime_mover`, and an
apparent-power circle `P² + Q² ≤ s_max²` in the OPF. Use it when the benchmark
should model PV/storage converters with explicit VA headroom rather than plain
dispatchable generation.

The division of labor mirrors generators: **placement places, augment
bounds.** `add_ibrs` writes only the nameplate — `bus`, `terminal_map`,
`topology`, `prime_mover`, `s_max`, `p_avail`, `cost` — and
[Pass 4](@ref pass-4-IBR-dispatch-bounds) of `augment_case` then derives the
`p_max`/`p_min`/`q_min`/`q_max` dispatch box from that nameplate, so the
intended order is `add_ibrs → augment_case`.

Placement is controlled by an [`IBRRecipe`](@ref). The strategy, filter and
cost fields mean the same as in [`GeneratorRecipe`](@ref), with these
IBR-specific additions:

- **`prime_mover`** — default `:PV`; one of `:PV`, `:BATTERY`, `:GENERIC`,
  `:STATCOM`, `:DSTATCOM` (other values are an `ArgumentError`). In the augment
  pass `PV` gets `p_min = 0`, `BATTERY` `p_min = -p_max`, and
  `STATCOM`/`DSTATCOM` the reactive-only treatment.
- **`inverter_topology`** — `:infer` (FOUR_LEG when the host load has a neutral
  terminal, else SINGLE_PHASE), or a forced `:FOUR_LEG` / `:THREE_LEG` /
  `:SINGLE_PHASE`.
- **sizing targets `s_max`**, not `p_max`: `size_basis` selects *how* the
  nameplate is derived. The `:fraction_of_*` bases (`:fraction_of_local_load`,
  `:fraction_of_transformer_rating`, `:fraction_of_downstream_load`) multiply a
  network quantity by `s_fraction`; `:fixed_tiers` instead reads an **absolute
  nameplate in VA** from the `fixed_tier_va` dict (per voltage-level family,
  default `Dict(:LV => 30_000.0, :MV => 1_000_000.0)`). `s_to_p_ratio` then sets
  `p_avail = s_to_p_ratio × s_max` (1.0 = unity-rated PV; below 1.0 leaves
  reactive headroom at full irradiance).

Every field written is recorded as a `:synthetic` `TransformEntry` with rule
`IBR_PLACEMENT/<strategy>`, and the run emits
`I.IBR.PLACED` / `W.IBR.NO_CANDIDATES` / `W.IBR.OVERSUPPLY` findings into the
manifest's `findings_after`.

!!! tip "Sizing in absolute kVA, and placing at zero-load buses"
    The default `:fraction_of_local_load` basis scales the fleet to a feeder,
    but it has two awkward edges:

    - **You want to think in kVA, not "× local load."** Use
      `size_basis = :fixed_tiers` and set the absolute nameplate directly:
      `IBRRecipe(strategy = :load_following, size_basis = :fixed_tiers,
      fixed_tier_va = Dict(:LV => 50_000.0))` places a 50 kVA unit on every LV
      load bus regardless of that bus's load. (The generator analogue is
      `GeneratorRecipe(size_basis = :fixed_tiers, fixed_tier_w = Dict(:LV => …))`,
      in **W**.)
    - **The bus has no local load but you still want a DER there.** A
      `:fraction_of_local_load` size is *zero* at a zero-load bus, and
      `min_local_load_va` will skip a low-load bus entirely. Size with
      `:fixed_tiers` (absolute, so load-independent), and/or choose candidates by
      *topology* rather than by load —
      `strategy = :topology_targeted, topology_mode = :leaves` (feeder ends) or
      `:near_source` — which place at buses selected from the graph, not from
      where demand happens to sit.

!!! note "Modeling PV, batteries, EVs, and other DER technologies"
    Two fields are orthogonal and easy to conflate:

    - **`strategy`** decides *where and how many* DERs are placed
      (`:load_following` = one per load bus, `:topology_targeted`,
      `:hosting_capacity`).
    - **`prime_mover`** decides *what technology* the converter is (`:PV`,
      `:BATTERY`, `:GENERIC`, `:STATCOM`).

    Mapping technologies onto objects: **PV, battery, or any converter-interfaced
    DER → an `ibr`** with the matching `prime_mover`; a **synchronous / simple
    dispatchable unit → a `generator`**. An **EV charger is demand, so it is a
    `load`** (optionally time-varying via a charging profile — see the
    [time-series tutorial](tutorial_timeseries.md)); model it as an `ibr` with
    `prime_mover = "BATTERY"` only for a vehicle-to-grid (V2G) study where it
    *injects*. `EV` is therefore not a `prime_mover` value.

    `add_ibrs` accepts only the data-model values (`:PV`, `:BATTERY`,
    `:GENERIC`, `:STATCOM`, `:DSTATCOM`); anything else is an `ArgumentError`.
    Sizing does not depend on `prime_mover`. When `p_min` is absent, the augment
    pass writes `p_min = 0` for `PV` and `p_min = -p_max` for `BATTERY` (rule
    `BATTERY_symmetric_charge`, `:heuristic`: the charge limit is assumed equal
    to the discharge limit). `GENERIC` gets no `p_min`, so its active power is
    bounded only by the apparent-power circle; set `p_min` explicitly for an
    asymmetric converter or a state-of-charge window.

!!! note "I/O converter support"
    `solve_opf` dispatches placed IBRs once `augment_case` has filled their
    P/Q box — the OPF engine fully models IBRs (apparent-power circle,
    topology-dependent voltage reference, constant-PF coupling). PowerIO can
    import IBR/control data where the source carries it. `to_pmd` and `to_dss`
    do not export IBRs.

```@docs
add_ibrs
IBRRecipe
default_ibr_recipe
```

### STATCOMs and active power circulation

[`add_statcom!`](@ref) places a single shunt converter (a STATCOM / *D-STATCOM*)
at a named bus as an IBR with `prime_mover = "STATCOM"`. Its dispatch box is left
to `augment_case`, which fills it according to the `dc_link_coupled` flag:

- **reactive-only** (default) — per-phase active power is clamped to zero
  (`p_min = p_max = 0`); the full per-phase rating becomes symmetric reactive
  capability (`q_max = s_max`, `q_min = -s_max`).
- **active power circulation** (`dc_link_coupled = true`) — per-phase active power
  is opened to `±s_max` and the net DC-side power is bounded by
  `p_dc_min … p_dc_max`, defaulted to `0 … 0` for a STATCOM. The OPF then enforces
  `∑ₖ Pₖ ∈ [p_dc_min, p_dc_max]`, letting the converter move active power between
  phases (see the [OPF model](opf.md#IBRs) and the
  [D-STATCOM unbalance study](@ref statcom-unbalance)).

The same `dc_link_coupled` augmentation applies to any IBR: for a non-STATCOM
source it defaults the band to `0 … p_avail`, so a curtailable PV inverter can
redistribute its available power across phases. Every derived bound is recorded
as a `:standard` `TransformEntry`.

```@docs
add_statcom!
```

## Explicit placement and comparable scenarios

Both placement recipes accept `bus_ids`, `phase_by_bus` and `capacity_budget`.
The budget is W for new generators and VA for new IBRs, apportioned using the
existing sizing weights. Explicit selections that fail filters raise errors.
Phase overrides support a single declared phase with an explicit neutral only.
See [Developing OPF case families](tutorial_case_development.md) for worked
placement, availability, control and reduction comparisons.
