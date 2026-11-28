# Case augmentation

An imported distribution model needs explicit study assumptions before it can
serve as an OPF benchmark. Imports can already carry ratings, source controls,
and limits; missing voltage bounds do not guarantee that the nonlinear power-flow
equations have a solution. Conversion fidelity and operating feasibility must
be assessed separately.

Augmentation adds selected bounds, costs and capability assumptions reproducibly,
following the benchmark-curation motivation of PGLib-OPF ([ref. 1](#augrefs)).
BMOPFTools supports this in the four-wire distribution setting with three
composable, audited operations:

- **`fix_case`** — *structural repairs*. Remove inert elements, drop
  disconnected islands, optionally collapse near-zero-impedance lines to
  switches, strip redundant bounds. Make the graph sound before anything is
  written onto it.
- **`add_generators`** / **`add_ibrs`** — *deliberate DER placement*. Create
  dispatchable `generator` elements (or richer inverter-interfaced `ibr`
  elements) at semantically/topologically chosen buses so the OPF has something
  to decide. Never random; every placement is explained.
- **`augment_case`** — *audited study assumptions*. Inject voltage bounds,
  optionally estimate synthetic thermal limits, price the slack, and derive
  reactive capability. Fills only what is missing; never overwrites.

Each returns a `(net′, TransformationManifest)` pair and **never mutates its
input**. The manifest is the heart of the contract: every value written is
recorded with the rule that produced it and a confidence tag (`:standard`,
`:heuristic`, `:synthetic`, …), so the resulting case is self-documenting and
the modeler can see which numbers are defensible defaults and which are design
choices worth revisiting.

This page explains the workflow and how to read its output. The
[Augmentation reference](augmentation_reference.md) lists every pass, flag,
default and recipe field.

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
   graph — drop the islands, optionally collapse the switch-like lines, remove
   inert loads — *before* annotating it, so every later pass operates on the
   network that will actually be solved.
2. **`add_generators` before the final `augment_case`** — placement writes only
   `p_min`/`p_max`/`cost`. The reactive capability of each DER
   (`q_min`/`q_max`) is then filled by `augment_case`'s generation pass from a
   single power-factor rule. Reversing the order would leave the freshly placed
   DERs with active-power bounds but no reactive capability — silently
   restricting the very flexibility you added them to study. Keeping reactive
   logic in one place (`augment_case`) is why generators go in first. The same
   holds for `add_ibrs`, whose nameplates `augment_case` turns into a full
   dispatch box.
3. **`augment_case` last** — gap-filling is idempotent and only ever fills
   missing fields, so it should see the *final* element set: the repaired
   topology plus the new DERs. Run last, it bounds everything once and
   completely.

The placement step is optional. If you only need a feasible power-flow
benchmark (CVR, state estimation, maximum-load-delivery studies) you can run
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

write_bmopf(net3, "my_feeder_ready.json")

result  = solve_opf(net3)
report′ = profile_solution(net3, result)
```

For converter-interfaced DERs, put [`add_ibrs`](@ref) in the generator slot;
`augment_case` then derives each placed IBR's `p_max`/`p_min`/`q_min`/`q_max`
from its nameplate ([Pass 4](@ref pass-4-IBR-dispatch-bounds)):

```julia
net2, ibr_mf = add_ibrs(net1; recipe = IBRRecipe(strategy = :load_following))
net3, aug_mf = augment_case(net2)
```

Passing pre-computed voltage-level and provenance results to `augment_case`
avoids re-running those analyses internally. The `analysis` keyword takes a
dict with `"voltage_levels"` and `"provenance"` entries, which an `analyze`
report holds in its `results`:

```julia
report  = analyze(net2)
net3, aug_mf = augment_case(net2;
                 analysis = Dict("voltage_levels" => report.results[:voltage_levels],
                                 "provenance"     => report.results[:provenance]))
```

The [end-to-end tutorial](tutorial_end_to_end.md) walks this pipeline on a real
feeder (external dataset; the docs build does not execute it). The
[DER placement tutorial](tutorial_ders.md) and [VVWO tutorial](tutorial_vvwo.md)
then drill into placement strategies and smart-IBR control, and
[Developing OPF case families](tutorial_case_development.md) builds comparable
scenario sets with explicit placement.

## Choosing a placement strategy

There is no single correct way to place DERs: the right placement depends on the
question the benchmark is meant to probe, because each placement makes a
different constraint the binding edge of the feasible set. Choose the strategy
from the research question:

| Research question | Strategy | What it stresses (binds first) |
|---|---|---|
| Realistic prosumer dispatch, CVR, self-consumption | `:load_following` | Where demand already is; mild, distributed counter-flow |
| Voltage-rise limits, embedded-generation hosting capacity | `:topology_targeted`, `topology_mode = :leaves` | Worst-case voltage rise at feeder ends, far from the source |
| Bulk reverse power flow, upstream thermal limits | `:topology_targeted`, `topology_mode = :near_source` *or* `:hosting_capacity` | Transformer/head-of-feeder loading and reverse flow |

Running several strategies on one base feeder yields a family of benchmark
instances — a voltage-rise case, a thermal-headroom case, a realistic-dispatch
case — each with a different active constraint. That diversity is what makes the
set useful for comparing OPF formulations and solvers. The strategies, sizing
bases and cost options are listed under
[Adding generators](@ref "Adding generators (DER placement)") and
[Adding IBRs](@ref adding-IBRs-der-placement) in the reference.

## [Reading the manifest: where to fine-tune](@id starting-point)

The three operations do **not** claim to produce the one true benchmark. They
produce a *defensible default* — every value is either copied from a published
standard or flagged as a heuristic estimate or a deliberate synthetic choice —
and the manifest is the map of which is which. That distinction tells a modeler
where to spend fine-tuning effort.

Read the manifest back by confidence tag:

- **`:standard` entries** (EN 50160 voltage windows, EN 50549-1 reactive
  capability) are safe to keep unless the case targets a jurisdiction with
  different rules — in which case override the relevant recipe field
  (`v_declared_lv`, `q_capability_pf`, …) and re-run. The slack price is also
  tagged `:standard` because the specification fixes the form of the slack cost
  term; its 1.0 \$/kWh value is a recipe default (`slack_cost`) worth revisiting.
- **`:heuristic` entries** (synthetic thermal ratings, solver guard bounds) are
  estimates to check against real data before relying on them.
- **`:synthetic` entries** (every DER placement) are design choices. These are
  the first things to revisit: the placement strategy, the `der_p_fraction`
  sizing, the `cost_basis`. Change them and you change *what the OPF decides*.

The intended loop is iterative, not one-shot:

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

Because each pass is pure and re-runnable, and the manifest records the *rule*
behind every field, a modeler can converge on a case tailored to their study
without reverse-engineering an opaque, pre-cooked benchmark file. To ship the
manifest with the case, see
[Serializing the manifest](@ref Serialising-the-manifest).

## Why augment? — rationale and literature

The approach follows established practice in two adjacent communities.

**Curated benchmarks, not raw data.** The AC transmission community learned that
raw network snapshots make poor optimization benchmarks: they lack generation
limits, costs and thermal ratings, so an OPF over them is under-constrained and
non-comparable across studies. PGLib-OPF answered this by *curating* a library
in which "all networks have reasonable values for key parameters"
([ref. 1](#augrefs)). `augment_case` does the four-wire-distribution equivalent,
with the added discipline that the source of every value (which standard, or
"synthetic") is recorded rather than baked in silently. The companion
design-goals analysis for unbalanced OPF benchmarks makes the same point for
distribution: a benchmark must make its bounds and assumptions explicit to be
reproducible ([ref. 4](#augrefs)).

**Standards as the source of defaults.** Where a value *can* be grounded in a
published standard, it should be, so the default is auditable rather than
arbitrary. Voltage windows follow EN 50160:2010 and DER reactive capability
follows EN 50549-1:2019. IEEE 1547-2018 ([ref. 5](#augrefs)) specifies
reactive capability as a fraction of nameplate kVA (Category B: 44 % injecting
and absorbing; Category A: 44 % injecting, 25 % absorbing); the P-based
`q_capability_pf` rule does not reproduce it, so ANSI-region studies write those
bounds from the kVA rating. This is why `augment_case` separates
standards-derived fills from synthetic ones in the manifest. Conductor
ampacities are the deliberate exception: the thermal pass is a **heuristic
estimate** loosely calibrated to IEC 60364-5-52:2009 / IEC 60228:2004 tables,
not a conformant derivation (a bare R₁₁ does not identify the conductor
material, class, or installation), and is tagged as such.

**DER scenarios as designed inputs.** Where a value *cannot* be
standardized — chiefly where to place generation and how large to make it — the
literature treats it as a deliberately varied scenario rather than a fixed fact.
EPRI's DRIVE hosting-capacity method contrasts *distributed* placement (many
small injections, representative of residential rooftop PV) with *centralized*
placement (a single large interconnection), because the two stress a feeder in
opposite ways ([ref. 2](#augrefs)); NREL's SMART-DS effort exposes DER siting
and sizing as configurable scenario knobs over a fixed base network
([ref. 3](#augrefs)). The placement strategies (`:load_following`,
`:topology_targeted` leaves/near-source, `:hosting_capacity`) are the BMOPF
analogues of those scenario choices, and tagging them `:synthetic` acknowledges
that they are design decisions, not measurements.

## Limitations

`augment_case` does not handle the following:

- **Zero-sequence voltage bound (`vzero_max`)** — the appropriate limit
  depends on the earthing system (TN, TT, IT have fundamentally different
  zero-sequence behavior) and cannot be standardized without knowing the
  system's neutral earthing arrangement. Use [`provenance_analysis`](@ref)
  earthing zone results to choose a value if needed.
- **Reactive load (`q_nom`)** — existing reactive demand is preserved as-is.
  If loads were imported with `pf = 0.88` OpenDSS defaults
  (flagged by `I.PROV.DSS_DEFAULT_PF`) the values should be reviewed
  before treating them as benchmark data.
- **Transformer ratings** — no transformer thermal rating is inferred. The
  nameplate `s_rating` (VA) must come from the source data; when present, the
  OPF enforces it directly.

## [References](@id augrefs)

Numbered citations on this page refer to this list. Power-quality and ampacity
standards (EN 50160:2010, EN 50549-1:2019, IEC 60228:2004, IEC 60364-5-52:2009)
are cited at their point of use in the
[Augmentation reference](augmentation_reference.md).

1. S. Babaeinejadsarookolaee et al., "The power grid library for benchmarking
   AC optimal power flow algorithms," arXiv:1908.02788, 2019. (PGLib-OPF,
   maintained by the IEEE PES Task Force on Benchmarks for Validation of
   Emerging Power System Algorithms.)
2. Electric Power Research Institute, *Distribution Resource Integration and
   Value Estimation (DRIVE)*, EPRI, Palo Alto, CA, 2016 — hosting-capacity
   methodology contrasting distributed vs centralized DER placement.
3. B. Palmintier et al., "SMART-DS: Synthetic models for advanced, realistic
   testing — distribution systems and scenarios," National Renewable Energy
   Laboratory (NREL), Golden, CO, 2017.
4. F. Geth, A. C. Chapman, R. Heidari, J. Clark, "Considerations and design
   goals for unbalanced optimal power flow benchmarks," *Electric Power Systems
   Research* 235 (2024) 110646.
5. IEEE Std 1547-2018, *IEEE Standard for Interconnection and Interoperability
   of Distributed Energy Resources with Associated Electric Power Systems
   Interfaces*, IEEE, 2018.
