# Case augmentation

## From a faithful import to a meaningful benchmark

A distribution network freshly imported from OpenDSS is *physically faithful but
optimization-meaningless*. It describes conductors, transformers and loads
exactly — but it carries nothing for an optimizer to respect or decide.
There are no voltage bounds, so no operating point can be *infeasible*. There
are no thermal limits, so no line can *bind*. There is no dispatchable
generation, so the only "decision" is for the slack to import whatever the loads
draw. Run an OPF on a raw import and the solver returns the power-flow solution:
the optimisation is trivial because the model contains nothing to optimise
*against*.

**Case augmentation is the bridge from a valid network to a meaningful OPF
instance.** It is the same gap that the AC transmission community closed with
PGLib-OPF — a curated benchmark library exists precisely because raw network
data lacks the generation limits, costs and thermal ratings an OPF needs, and
those must be added deliberately and reproducibly rather than guessed per study
([ref. 1](#augrefs)). BMOPFTools brings that discipline to the unbalanced
four-wire distribution setting with three composable, audited operations:

- **`fix_case`** — *structural repairs*. Remove inert elements, drop
  disconnected islands, collapse near-zero-impedance lines to switches, strip
  redundant bounds. Make the graph sound before anything is written onto it.
- **`add_generators`** / **`add_inverters`** — *deliberate DER placement*. Create
  dispatchable `generator` elements (or richer inverter-interfaced `inverter`
  elements) at semantically/topologically chosen buses so the OPF has something
  to decide. Never random; every placement is explained.
- **`augment_case`** — *standards-grounded gap-filling*. Inject voltage bounds,
  infer thermal limits, price the slack, and derive reactive capability. Fills
  only what is missing; never overwrites.

Each returns a `(net′, TransformationManifest)` pair and **never mutates its
input**. The manifest is the heart of the contract: every value written is
recorded with the rule that produced it and a confidence tag (standards-derived
vs `:synthetic`), so the resulting case is self-documenting and the modeler can
see at a glance exactly which numbers are defensible defaults and which are
design choices worth revisiting (see [A starting point for fine-tuning](#starting-point)).

## Why this sequence

The three operations are a *pipeline*, not a menu. The order

```
fix_case ──► add_generators ──► augment_case ──► solve_opf
   │              │                   │
 repair       place DERs         fill gaps
 topology     (p/p_max/cost)     (bounds, limits,
                                  q_min/q_max, slack cost)
```

is deliberate, and each edge exists for a reason:

1. **`fix_case` first** — bounds and generators placed on a broken topology are
   wasted or actively wrong. A DER stranded on an islanded bus injects into
   nothing; a thermal limit on a zero-impedance loop is meaningless. Repair the
   graph — drop the islands, collapse the switch-like lines, remove inert loads
   — *before* annotating it, so every later pass operates on the network that
   will actually be solved.
2. **`add_generators` before the final `augment_case`** — placement writes only
   `p_min`/`p_max`/`cost`. The reactive capability of each DER
   (`q_min`/`q_max`) is then filled by `augment_case`'s generation pass from a
   single power-factor rule. Reversing the order would leave the freshly-placed
   DERs with active-power bounds but no reactive capability — silently
   restricting the very flexibility you added them to study. Keeping reactive
   logic in one place (`augment_case`) is why generators go in first.
3. **`augment_case` last** — gap-filling is idempotent and only ever fills
   missing fields, so it should see the *final* element set: the repaired
   topology plus the new DERs. Run last, it bounds everything once and
   completely.

The placement step (`add_generators`, or `add_inverters` for converter-interfaced
DERs) is genuinely optional. If you only need a feasible power-flow benchmark
(CVR, state estimation, maximum-load-delivery studies) you can run
`fix_case → augment_case` and skip placement entirely — the slack remains the
only injector. Add DERs when you want the *dispatch* itself to be the object of
study.

## Recommended workflow

```julia
using BMOPFTools

net = parse_bmopf("my_feeder.json")          # or from_dss

net1, fix_mf = fix_case(net)                 # 1. structural repairs first
net2, der_mf = add_generators(net1;          # 2. place DERs (optional)
                 recipe = GeneratorRecipe(strategy = :load_following))
net3, aug_mf = augment_case(net2)            # 3. fill bounds, limits, q, slack cost

render_manifest(fix_mf)                      # inspect what was repaired
render_manifest(der_mf)                      # inspect every placement
render_manifest(aug_mf)                      # inspect what was added

write_bmopf("my_feeder_ready.json", net3)

result  = solve_opf(net3)
report′ = profile_solution(net3, result)
```

Passing the pre-computed `analyze` result to `augment_case` avoids
re-running voltage-level and provenance analyses internally:

```julia
report  = analyze(net2)
net3, aug_mf = augment_case(net2; analysis=report.analysis)
```

The four `augment_case` passes below run in order. Each can be disabled
independently via the [`AugmentationRecipe`](@ref) `apply_*` flags.  **No pass
ever overwrites an existing value** — augmentation only fills gaps.

### Pass 1 — Voltage bounds

Sets `v_min`/`v_max`, `vpn_min`/`vpn_max`, `vpp_min`/`vpp_max`, and
`vneg_max` on buses that lack them. `vpn_*` are written as per-phase arrays and
`vpp_*` as per-pair arrays (see [Conventions](conventions.md)); the OPF consumes
them in those shapes.

Bounds are expressed as fractions of a **declared supply voltage** — the
nominal voltage defined by the relevant power-quality standard, which may
differ from the transformer rated voltage in the network model (e.g. a 240 V
transformer in a grid declared at 230 V per EN 50160).  The declared voltage
is resolved per bus in priority order:

1. `bus["v_declared"]` — explicit field set at import time (e.g. authored in
   the BMOPF JSON)
2. the optional **voltage-snap** pass (see below) — writes `v_declared` by
   snapping `v_nom` to a standard level; never overrides an explicit value
3. `AugmentationRecipe` fields `v_declared_lv` / `v_declared_mv` /
   `v_declared_hv` — regional fallback (e.g. `v_declared_lv = 230.0` for
   Europe/Australia)
4. `v_nom` from `voltage_level_analysis` — last resort when none of
   the above is set

#### Pass 0 — Voltage-level snapping (optional)

Imported cases frequently carry LV transformers rated 240 or 250 V, so the
derived `v_nom` is non-standard and the bounds would be referenced to it. When
enabled, `augment_case` first snaps each bus's `v_nom` to the nearest
standardised level (IEC 60038 / ANSI C84.1) and writes the result as
`v_declared`, so the bounds below reference the standard voltage (e.g. 230 V).

Configured in the TOML `config` (off by default — no behaviour change unless
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
the manifest as a `v_declared` entry with rule
`IEC60038_snap`. Pass the config via
`augment_case(net; config=load_config("my.toml"))`.

#### Solver regularisation bounds (`v_min` / `v_max`)

`v_min` and `v_max` are **hyperparameters**, not power-quality guarantees.
They widen the feasible set so the solver can find a feasible point even when
the operating point sits at the edge of the physical window.  The same values
are applied to all buses regardless of voltage level.

| Field | Default (pu of `v_declared`) | Purpose |
|---|---|---|
| `v_min` | 0.85 | Lower regularisation bound — disable with `v_min_pu = nothing` |
| `v_max` | 1.15 | Upper regularisation bound — disable with `v_max_pu = nothing` |

**Source buses** receive `v_min`/`v_max` only — `vpn`/`vpp`/`vneg` bounds
are meaningless there because the voltage source pins the terminal voltages.

#### Power-quality bounds

Applied to all non-source buses.  Percentage windows follow EN 50160:2010.

**Four-wire buses** (have a neutral terminal) receive `vpn` bounds, since
customers experience the phase-to-neutral voltage.  `vpp` bounds are also
set when ≥ 2 phase terminals are present.

| Bound | Level | Default (pu of `v_declared`) | Standard |
|---|---|---|---|
| `vpn_min`/`vpn_max` | LV (≤ 1 kV) | 0.90 / 1.10 | EN 50160:2010 §3.5/§3.6, 95 %-of-week ±10 % |
| `vpn_min`/`vpn_max` | MV (1–35 kV) | 0.94 / 1.06 | DSO planning practice ±6 %, budgets for LV voltage drop |
| `vpp_min`/`vpp_max` | LV | 0.90 / 1.10 | EN 50160:2010 §3.5, same ±10 % band |
| `vpp_min`/`vpp_max` | MV | 0.94 / 1.06 | Same ±6 % band as `vpn` |
| `vpp_min`/`vpp_max` | HV (> 35 kV) | 0.95 / 1.05 | Transmission planning ±5 % |

**Three-wire buses** (no neutral terminal) receive `vpp` bounds only.

**Single-phase buses** (one phase terminal + neutral) receive `vpn` but not
`vpp` or `vneg_max`.

**Unassigned buses** (islanded from all voltage sources) are skipped; the
manifest records a note.

| Bound | Applies to | Default | Standard |
|---|---|---|---|
| `vneg_max` | Four-wire, ≥ 2 phases, non-source | 0.02 × vpn_declared | EN 50160:2010 §3.5 — VUF ≤ 2 % |

### Pass 2 — Thermal limits

Infers `i_max` for linecodes that lack it by matching the diagonal series
resistance R₁₁ against an IEC 60228:2004 / IEC 60364-5-52:2009 lookup table.

The table covers cross-sections from 4 mm² to 240 mm²:

| Cross-section (mm²) | R₁₁ (mΩ/m at 20 °C) | Underground XLPE (A) | Overhead AAC (A) |
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

Sources: IEC 60228:2004 (AC resistance at 20 °C), IEC 60364-5-52:2009
Table B.52 (ampacity at 70 °C conductor temperature, single-circuit
in-ground or in-air installation).

The match uses a 15 % relative tolerance on R₁₁.  If no table row falls
within tolerance the linecode is skipped and the manifest records
`"R₁₁ outside lookup range"`.

**Provenance confidence gating.**  The inference is only reliable when R₁₁
comes from a first-principles geometry model (Carson/Pollaczek).  The pass
checks the [`provenance_analysis`](@ref) verdict for each linecode:

| Verdict | Confidence | Included by default? |
|---|---|---|
| `distinct` | `:high` | Yes |
| `near_balanced` | `:medium` | Yes (default threshold) |
| `exactly_balanced` | `:low` | No |
| `decoupled` | `:low` | No |

Lower the threshold with `AugmentationRecipe(thermal_min_confidence=:low)` to
infer limits even from sequence-derived matrices, or raise it to `:high` to
restrict to geometry-derived data only.

**Neutral conductor rating.**  The neutral conductor is assigned the same
`i_max` as the phase conductors.  IEC 60364-5-52:2009 §523 permits a reduced
neutral cross-section above 16 mm² under balanced loading conditions, but the
appropriate reduction is installation- and load-specific and is not applied
automatically.  Set the neutral entry of `i_max` in the linecode manually, or
pass a pre-computed `i_max` vector (which will not be overwritten) if a derated
rating is required.

### Pass 3 — Generation

**Slack cost.**  The voltage source is itself the network's current slack, so no
slack *generator* is created. If a source has no `cost`, a per-phase cost is
written onto the `voltage_source` (default 1.0 \$/kWh) so imported power is
priced in the objective. No
flow bounds are added, so the slack stays unconstrained and the OPF can always
find a feasible point. Controlled by the recipe's `apply_slack_generator` /
`slack_cost` fields (names kept for backwards compatibility).

**Reactive bounds.**  For each generator that has `p_max` defined but lacks
`q_min`/`q_max`, symmetric reactive bounds are derived from the recipe
power-factor setting:

```
Q_max = P_max × tan(arccos(pf))
```

Default `pf = 0.90` (EN 50549-1:2019, LV grid-connected DERs):
Q_max ≈ 0.484 × P_max.  Set `q_capability_pf = 0.95` for IEEE 1547-2018
(ANSI) deployments: Q_max ≈ 0.329 × P_max.

### [Pass 4 — Inverter dispatch bounds](@id pass-4-inverter-dispatch-bounds)

`inverter` elements carry a richer model than generators (an apparent-power
nameplate `s_max`, a `topology`, a `prime_mover`, and an optional smart-inverter
`control_profile`). This pass fills their **active and reactive dispatch box**
from the nameplate, leaving the nameplate itself untouched. Controlled by the
recipe's `apply_inverter` flag; disabled with `apply_inverter = false`.

**Active power.** If `p_max` is absent it is derived per phase — from `p_avail`
(split equally across phases) or from the per-phase `s_max` ratings. For `PV`
prime movers `p_min = 0` is also injected when absent, since PV cannot absorb
active power.

**Reactive power.** If the inverter references a `control_profile` carrying a
`power_factor` sub-object, `q_min`/`q_max` are *left absent* — the OPF enforces
the exact PF coupling `Q = f(P)` as an equality constraint instead. Otherwise,
for inverters lacking explicit `q_min`/`q_max`, symmetric bounds are derived from
`p_max` using the recipe's `inverter_default_pf` (EN 50549-1:2019 default
cos φ = 0.90), exactly as for generators:

```
Q_max = P_max × tan(arccos(pf)),   Q_min = -Q_max
```

This pass only *bounds* inverters that already exist in the case. To **place**
inverters in the first place, see [Adding inverters](#adding-inverters-der-placement)
below; the intended order is `add_inverters → augment_case`, so this pass turns
each placed nameplate into a full dispatch box.

## `fix_case` — structural repairs

Seven passes run in order.  Each is independently controlled by the
corresponding `apply_*` flag in [`FixRecipe`](@ref).  All passes default to
`true` except the two that change power-system semantics, which default to
`false` and must be opted into explicitly.

| # | Pass | Default | Notes |
|---|---|---|---|
| 1 | Largest connected component | `true` | Drops buses, lines, loads, generators, and shunts that have no path to a voltage source. |
| 2 | Simplify network | `true` | Merges consecutive same-linecode series lines; removes dangling stub lines (wraps [`simplify_network`](@ref)). |
| 3 | Remove zero loads | `true` | Deletes loads with `p_nom = q_nom = 0` on all phases — electrically inert. |
| 4 | Low-impedance lines → switches | `true` | Replaces lines with total series impedance `\|Z\| < threshold` (default 10⁻⁴ Ω) with closed switches. |
| 5 | Source bus bounds | `true` | Strips all voltage bounds from source buses — redundant because the voltage source pins the terminal voltages exactly. |
| 6 | Adjacent current bounds | `false` | Infers `i_max` for lines/switches that lack it from directly adjacent elements (one hop). Transformers contribute `s_rating / (√3 × V_ref)`; lines and switches propagate their own `i_max`. Takes the minimum over all adjacent bounds. |
| 7 | Perfect grounding | `false` | Promotes grounding shunts whose `1/\|Y₁₁\| < threshold` (default 0.1 Ω) to `perfectly_grounded_terminals` and removes the shunt. **Changes OPF physics** (forces `V_n = 0`). |

```@docs
fix_case
FixRecipe
```

## `augment_case` — standards-grounded gap-filling

```@docs
augment_case
AugmentationRecipe
default_recipe
```

## `TransformationManifest`

```@docs
TransformationManifest
TransformEntry
manifest_to_dict
render_manifest
```

## Serialising the manifest

The manifest is intended to travel alongside the augmented case file so
the pair `(case.json, case_manifest.json)` is self-documenting:

```julia
using JSON3

net′, manifest = augment_case(net)
write_bmopf("feeder_aug.json", net′)
open("feeder_aug_manifest.json", "w") do io
    JSON3.write(io, manifest_to_dict(manifest))
end
```

## Adding generators (DER placement)

`augment_case` deliberately only gap-fills standards-grounded bounds; it does
**not** create generation.  Without dispatchable generators the OPF is trivial
(the slack imports everything).  [`add_generators`](@ref) is a separate, opt-in
pass that *places* dispatchable `generator` elements using the semantic and
topological knowledge the library already computes — never randomly — so the OPF
becomes a meaningful optimisation.  Like `fix_case`/`augment_case` it never
mutates its input and returns a `(net′, manifest)` pair recording every field
written.

It writes only `bus`, `terminal_map`, `configuration`, `p_min`, `p_max`, and
`cost`; reactive bounds are intentionally left to `augment_case`'s generation
pass (this is the ordering constraint from
[Why this sequence](#why-this-sequence)).

### Why diverse strategies matter

There is **no single correct way to place DERs** — the right placement depends
on the question the benchmark is meant to probe, and a different question puts a
different constraint on the binding edge of the feasible set. This mirrors how
synthetic-network and hosting-capacity practice treats DER scenarios as a
*designed input*: EPRI's DRIVE hosting-capacity method deliberately contrasts
*distributed* placement (many small injections spread across the feeder,
representative of residential rooftop PV) against *centralised* placement (a
single large interconnection), because the two stress the network in opposite
ways ([ref. 2](#augrefs)); and the NREL SMART-DS effort treats DER siting and
sizing as configurable scenario knobs rather than a fixed fact of the network
([ref. 3](#augrefs)). Offering several placement strategies is therefore a
matter of *experimental design*, not optional decoration — it lets one base
feeder generate a family of benchmark instances that exercise distinct physics.

Choose the strategy from the research question:

| Research question | Strategy | What it stresses (binds first) |
|---|---|---|
| Realistic prosumer dispatch, CVR, self-consumption | `:load_following` | Where demand already is; mild, distributed counter-flow |
| Voltage-rise limits, embedded-generation hosting capacity | `:topology_targeted`, `topology_mode = :leaves` | Worst-case voltage rise at feeder ends, far from the source |
| Bulk reverse power flow, upstream thermal limits | `:topology_targeted`, `topology_mode = :near_source` *or* `:hosting_capacity` | Transformer/head-of-feeder loading and reverse flow |

The point of supporting all three is that a *single* base feeder can be turned
into a family of benchmark instances — a voltage-rise case, a thermal-headroom
case, a realistic-dispatch case — each making a different constraint the active
one. That diversity is what makes the resulting set useful for comparing OPF
formulations and solvers, not just solving one network once.

### The recipe knobs

Placement is controlled by a [`GeneratorRecipe`](@ref):

- **`strategy`** — `:load_following` (one DER per load bus, phasing inherited
  from the load), `:hosting_capacity` (DERs sized to a fraction of the feeding
  transformer's `s_rating`), or `:topology_targeted` (`topology_mode = :leaves`
  for embedded generation at feeder ends, or `:near_source` for bulk injection).
- **filters** — `voltage_levels` (e.g. `[:LV]`), `min_local_load_va`, and
  `skip_source_buses` compose over any strategy.
- **sizing** — `size_basis` (`:fraction_of_local_load`,
  `:fraction_of_transformer_rating`, `:fraction_of_downstream_load`,
  `:fixed_tiers`) with `der_p_fraction`.
- **cost** — `cost_basis` (`:cheaper_than_slack`, `:tiered_by_level`,
  `:uniform`); pricing DERs below the slack makes dispatch non-trivial — the
  solver uses local generation until a voltage or thermal constraint binds.

Every generator field written is recorded as a `TransformEntry` with rule
`DER_PLACEMENT/<strategy>` and confidence `:synthetic` (a design choice, not a
standard), and the run emits `I.DER.PLACED` / `W.DER.NO_CANDIDATES` /
`W.DER.OVERSUPPLY` findings into the manifest's `findings_after`. Because every
placement is tagged `:synthetic`, the manifest doubles as the list of knobs a
modeler will most likely want to tune (see below).

```@docs
add_generators
GeneratorRecipe
default_generator_recipe
```

## [Adding inverters (DER placement)](@id adding-inverters-der-placement)

[`add_inverters`](@ref) is the inverter-interfaced counterpart to
[`add_generators`](@ref). Where a `generator` is a thin active-power object, an
`inverter` carries a richer model — an apparent-power nameplate `s_max`, a
`topology` (`FOUR_LEG` / `THREE_LEG` / `SINGLE_PHASE`), a `prime_mover`, and an
apparent-power circle `P² + Q² ≤ s_max²` in the OPF. Use it when the benchmark
should model PV/storage converters with explicit VA headroom rather than plain
dispatchable generation.

The division of labour mirrors generators exactly: **placement places, augment
bounds.** `add_inverters` writes only the nameplate — `bus`, `terminal_map`,
`topology`, `prime_mover`, `s_max`, `p_avail`, `cost` — and
[Pass 4 of `augment_case`](#pass-4-inverter-dispatch-bounds) then derives the
`p_max`/`p_min`/`q_min`/`q_max` dispatch box from that nameplate. The intended
order is therefore the same one-line pipeline with `add_inverters` in the
generator slot:

```julia
net1, _   = fix_case(net)
net2, imf = add_inverters(net1;
              recipe = InverterRecipe(strategy = :load_following))
render_manifest(imf)               # every placement is explained
net3, _   = augment_case(net2)     # fills p_max/p_min/q_min/q_max on the new inverters
```

Placement is controlled by an [`InverterRecipe`](@ref). The strategy, filter and
cost knobs are identical in meaning to [`GeneratorRecipe`](@ref) (so the
[strategy-diversity guidance](#why-diverse-strategies-matter) applies unchanged),
with these inverter-specific additions:

- **`prime_mover`** — `:PV` (the MVP default; drives `p_min = 0` in the augment
  pass). Battery and grid-forming inverters are planned but not yet placed.
- **`inverter_topology`** — `:infer` (FOUR_LEG when the host load has a neutral
  terminal, else SINGLE_PHASE), or a forced `:FOUR_LEG` / `:THREE_LEG` /
  `:SINGLE_PHASE`.
- **sizing targets `s_max`**, not `p_max`: `size_basis` (same four bases as
  generators) with `s_fraction` sets the apparent-power nameplate, and
  `s_to_p_ratio` sets `p_avail = s_to_p_ratio × s_max` (1.0 = unity-rated PV;
  below 1.0 leaves reactive headroom at full irradiance).

Every field written is recorded as a `:synthetic` `TransformEntry` with rule
`INVERTER_PLACEMENT/<strategy>`, and the run emits
`I.INV.PLACED` / `W.INV.NO_CANDIDATES` / `W.INV.OVERSUPPLY` findings into the
manifest's `findings_after`.

!!! note "I/O converter support is pending"
    `solve_opf` dispatches placed inverters once `augment_case` has filled their
    P/Q box — the OPF engine fully models inverters (apparent-power circle,
    topology-dependent voltage reference, constant-PF coupling). What is *not* yet
    wired is the I/O layer: `to_pmd`/`from_dss` do not yet map
    `inverter` elements, so inverters cannot round-trip through
    PowerModelsDistribution or OpenDSS.

```@docs
add_inverters
InverterRecipe
default_inverter_recipe
```

## [A starting point for fine-tuning](@id starting-point)

The three passes do **not** claim to produce the one true benchmark. They
produce a *defensible default* — every value is either copied from a published
standard or flagged as a deliberate synthetic choice — and the manifest is the
map of which is which. That distinction is the whole point: it tells a modeler
exactly where to spend their fine-tuning effort.

Read the manifest back by confidence tag:

- **Standards-derived entries** (EN 50160 voltage windows, IEC 60364 ampacities,
  EN 50549-1 reactive capability) are safe to keep unless the case targets a
  jurisdiction with different rules — in which case override the relevant
  recipe field (`v_declared_lv`, `q_capability_pf`, …) and re-run.
- **`:synthetic` entries** (every DER placement, the slack price) are design
  choices. These are the first things to revisit: the placement strategy, the
  `der_p_fraction` sizing, the `cost_basis`. Change them and you change *what
  the OPF decides*.

The intended loop is therefore iterative, not one-shot:

```julia
net3, mf = add_generators(net2;
             recipe = GeneratorRecipe(strategy = :topology_targeted,
                                      topology_mode = :leaves))
render_manifest(mf)                      # see every synthetic placement & its driver
# … decide the feeder-end DERs are oversized; lower the fraction and re-run …
net3, mf = add_generators(net2;
             recipe = GeneratorRecipe(strategy = :topology_targeted,
                                      topology_mode = :leaves,
                                      der_p_fraction = 0.3))
```

Because each pass is pure and re-runnable, and because the manifest records the
*rule* behind every field, a modeler can converge on a case tailored to their
study without ever reverse-engineering an opaque, pre-cooked benchmark file.

## Why augment? — rationale and literature

The approach here is not ad hoc; it follows established practice in two adjacent
communities.

**Curated benchmarks, not raw data.** The AC transmission community learned that
raw network snapshots make poor optimisation benchmarks: they lack generation
limits, costs and thermal ratings, so an OPF over them is under-constrained and
non-comparable across studies. PGLib-OPF answered this by *curating* a library
in which "all networks have reasonable values for key parameters — generation
injection limits, generation costs, and branch thermal limits"
([ref. 1](#augrefs)). `augment_case` does the four-wire-distribution equivalent,
with the added discipline that the source of every value (which standard, or
"synthetic") is recorded rather than baked in silently. The companion
design-goals analysis for unbalanced OPF benchmarks argues the same point
specifically for distribution: a benchmark must make its bounds and assumptions
explicit to be reproducible ([ref. 4](#augrefs)).

**Standards as the source of defaults.** Where a value *can* be grounded in a
published standard, it should be — so the default is auditable rather than
arbitrary. Voltage windows follow EN 50160:2010, conductor ampacities follow
IEC 60364-5-52:2009 over IEC 60228:2004 resistances, and DER reactive capability
follows EN 50549-1:2019 (with IEEE 1547-2018 as the ANSI alternative, whose
minimum 44 % injecting / 44 % absorbing reactive capability motivates the
`q_capability_pf = 0.95` preset) ([ref. 5](#augrefs)). This is why
`augment_case` separates standards-derived fills from synthetic ones in the
manifest.

**DER scenarios as designed inputs.** Where a value *cannot* be standardised —
chiefly where to place generation and how large to make it — the literature
treats it as a deliberately varied scenario rather than a fixed fact. EPRI's
DRIVE hosting-capacity methodology contrasts distributed against centralised DER
placement precisely because they stress a feeder differently ([ref. 2](#augrefs)),
and NREL's SMART-DS programme exposes DER siting/sizing as configurable scenario
knobs over a fixed base network ([ref. 3](#augrefs)). `add_generators` follows
this practice directly: its strategies (`:load_following`, `:topology_targeted`
leaves/near-source, `:hosting_capacity`) are the BMOPF analogues of those
scenario choices, and tagging them `:synthetic` is the honest acknowledgement
that they are design decisions, not measurements.

## Limitations

The following augmentation tasks are **not** handled by `augment_case`:

- **DER placement** — handled by the separate [`add_generators`](@ref) pass
  documented above, not by `augment_case`, because where to place generators and
  how to size them is a deliberate design choice rather than standards-derivable.

- **Zero-sequence voltage bound (`vzero_max`)** — the appropriate limit
  depends on the earthing system (TN, TT, IT have fundamentally different
  zero-sequence behaviour) and cannot be standardised without knowing the
  system's neutral earthing arrangement.  Use [`provenance_analysis`](@ref)
  earthing zone results to choose a value if needed.

- **Reactive load (`q_nom`)** — existing reactive demand is preserved as-is.
  If loads were imported with `pf = 0.88` OpenDSS defaults
  (flagged by `I.PROV.OPENDSS_DEFAULT_PF`) the values should be reviewed
  before treating them as benchmark data.

- **Transformer `s_max`** — `s_rating` already plays this role; the solver
  uses it directly.  No separate `s_max` augmentation is needed.

## [References](@id augrefs)

Numbered citations above refer to this list. Power-quality and ampacity
standards (EN 50160:2010, EN 50549-1:2019, IEC 60228:2004, IEC 60364-5-52:2009)
are cited inline at their point of use in the tables above.

1. S. Babaeinejadsarookolaee et al., "The power grid library for benchmarking
   AC optimal power flow algorithms," arXiv:1908.02788, 2019. (PGLib-OPF,
   maintained by the IEEE PES Task Force on Benchmarks for Validation of
   Emerging Power System Algorithms.)
2. Electric Power Research Institute, *Distribution Resource Integration and
   Value Estimation (DRIVE)*, EPRI, Palo Alto, CA, 2016 — hosting-capacity
   methodology contrasting distributed vs centralised DER placement.
3. B. Palmintier et al., "SMART-DS: Synthetic models for advanced, realistic
   testing — distribution systems and scenarios," National Renewable Energy
   Laboratory (NREL), Golden, CO, 2017.
4. F. Geth, A. C. Chapman, R. Heidari, J. Clark, "Considerations and design
   goals for unbalanced optimal power flow benchmarks," *Electric Power Systems
   Research* 235 (2024) 110646.
5. IEEE Std 1547-2018, *IEEE Standard for Interconnection and Interoperability
   of Distributed Energy Resources with Associated Electric Power Systems
   Interfaces*, IEEE, 2018.
