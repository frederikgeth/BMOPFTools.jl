# Reading augmentation provenance: derived, assumed, unknown

!!! note "External dataset"
    This tutorial uses CC BY-NC-SA data kept in BMOPFDraftData. Set
    `ENV["BMOPF_RESTRICTED_DATA"] = "/path/to/BMOPFDraftData/test/data"`
    before running it. The dataset retains its upstream license and is not
    bundled with BMOPFTools. These dataset examples are shown as code and
    are not executed by the package documentation build.

Real network data arrives incomplete. A cable has an impedance but no current
rating; a bus has a nominal voltage but no operating envelope; a feeder has loads
but nothing dispatchable to optimize. Turning that into a model an OPF can
respect means *writing numbers the source never gave you*, and the integrity of
the study depends on being honest about where each one came from.

BMOPFTools records every value a preparation pass writes in a **manifest**,
together with the rule that produced it and a **confidence tag**. This tutorial
takes one incomplete feeder through [`augment_case`](@ref) and reads that
provenance back out, sorting the written values into three groups: what can be
derived from a standard, what has to be assumed, and what must stay unknown.

*Prerequisites: a Julia environment with `BMOPFTools` — the augmentation passes
need no solver. The [Case augmentation](augmentation.md) guide explains the
workflow; the [Augmentation reference](augmentation_reference.md) lists every
pass and rule.*

## 1. An incomplete case

We start from a small LV feeder and, to mimic datasheets that list conductor
impedances but no ampacities, strip the current ratings. Nothing here is
invalid — it is just *optimization-meaningless*: with no voltage bounds nothing
can be infeasible, and with no ratings nothing can bind.

```julia
using BMOPFTools, Printf

raw = parse_bmopf(joinpath(ENV["BMOPF_RESTRICTED_DATA"], "LV", "lv1_14bus.json"))
for (_, lc) in raw["linecode"]; delete!(lc, "i_max"); end   # datasheets w/o ratings

n_bus_no_bounds = count(b -> !haskey(b, "v_min"), values(raw["bus"]))
n_lc_no_rating  = count(lc -> !haskey(lc, "i_max"), values(raw["linecode"]))
(buses_without_bounds = "$n_bus_no_bounds / $(length(raw["bus"]))",
 linecodes_without_rating = "$n_lc_no_rating / $(length(raw["linecode"]))")
```

## 2. Fill the gaps — and record where each number came from

[`augment_case`](@ref) fills only what is missing, never overwriting, and returns
the augmented network together with a [`TransformationManifest`](@ref). It never
mutates its input. The thermal pass is off by default, so the recipe enables it
here; without `apply_thermal = true` the stripped linecodes stay unrated.

```julia
recipe  = AugmentationRecipe(apply_thermal = true)
net, mf = augment_case(raw; recipe)
length(mf.entries)   # one entry per value written (or deliberately skipped)
```

Each entry carries a `confidence` tag. Grouping the written values by tag sorts
them onto a spectrum from *fully defensible* to *your call*:

```julia
tier(c) = c === :standard  ? "1. standards-derived" :
          c === :heuristic ? "2. heuristic (estimate or numerical default)" :
          c === :synthetic ? "3. synthetic (design choice)" :
                             String(c)

byt = Dict{String,Int}()
for e in mf.entries
    e.new_value === nothing && continue          # skips are recorded too
    byt[tier(e.confidence)] = get(byt, tier(e.confidence), 0) + 1
end
sort(collect(byt))
```

One representative rule from each kind, so the tags are concrete:

```julia
seen = String[]
for e in mf.entries
    (e.new_value === nothing || e.rule in seen) && continue
    push!(seen, e.rule)
    @printf("[%-9s] %-30s → %s.%s\n", e.confidence, e.rule[1:min(30,end)],
            e.component_type, e.field)
end
```

Reading those tiers back as engineering judgment:

- **Standards-derived** (`:standard`) — the rule is traceable to a published
  standard. The voltage envelopes use EN 50160 (`EN50160:2010§3.5`), and the
  slack cost follows the form the Task Force spec fixes
  (`TFspec_Eq135_slack_generation`); the spec fixes the form of the cost term,
  not its value, so the 1.0 \$/kWh default (`slack_cost`) is yours to choose.
  This is strong provenance, not
  universal applicability: confirm the jurisdiction, voltage class, revision,
  planning/operational purpose, and any local connection agreement before using
  the value in a published study.
- **Heuristic** (`:heuristic`) — two kinds of value share this tag. The thermal
  ratings (`heuristic_ampacity_estimate`): the pass reads each conductor's diagonal
  resistance R₁₁ as a *size fingerprint* and looks up a representative ampacity.
  This is **not** a standards-conformant rating: R₁₁ is the series resistance
  (conductor AC resistance **plus** the Carson earth-return term), so it does not
  identify the conductor's material, class, or installation — see the
  [thermal pass](@ref "Pass 2 — Thermal limits"). On this feeder the
  effect is visible in the notes: a 185 mm² copper linecode matches the 95 mm²
  row. Only linecodes whose impedance classification meets
  `thermal_min_confidence` (default `:medium`) are rated; the `:high` /
  `:medium` / `:low` tags appear only on the skip entries, where they report that
  classification, not ampacity confidence. Check every estimate against your
  real conductor schedule before publishing. The second kind is the loose
  guard bounds (`solver_regularisation` on `v_min`/`v_max`) and the
  instantaneous unbalance limit `vuf_max`: study policies, not physical claims.
- **Synthetic** (`:synthetic`) — pure design choices. These appear the moment you
  place dispatchable generation, which is a *scenario*, not a fact. Placement
  goes before `augment_case`, so the generation pass gives the new generators
  their reactive bounds (see
  [Why this sequence](@ref "Why this sequence")):

```julia
raw_der, der_mf = add_generators(raw)
net_der, _      = augment_case(raw_der; recipe)
[(e.rule, e.confidence) for e in der_mf.entries if e.confidence === :synthetic] |> unique
```

## 3. What must stay unknown

The passes fill what can be *defensibly* defaulted and leave the rest — the
confidence tag is the tell for what to revisit:

- A conductor's **material and installation** cannot be recovered from R₁₁ alone,
  so the ampacity is a heuristic estimate, tagged `:heuristic` rather than
  presented as a standard, and written only when the thermal pass is requested.
- Values a datasheet simply omits — a transformer's core-loss branch, a load's
  true ZIP split — are **not invented**. `augment_case` adds no such field; it
  fills operating *envelopes*, not missing *physics*.
- **Where and how large** to place DER is a study input, not a derivable quantity
  ([`add_generators`](@ref) is explicit about this — every placement is a
  `:synthetic` entry with a stated strategy, never random).

## 4. Provenance travels with the case

The manifest serializes, so the augmented case and its provenance can ship as a
pair — `(case.json, case_manifest.json)` — and every default stays auditable
long after the study:

```julia
sort(collect(keys(manifest_to_dict(mf))))
```

For the human-readable view, `render_manifest(mf)` prints the full diff grouped
by component. The discipline is the point: a benchmark is only as defensible as
its least-documented default, and the tag on every number tells the next reader —
or the reviewer — exactly which ones to trust and which to challenge.

!!! tip "Where to go next"
    The [Augmentation reference](augmentation_reference.md) documents every
    pass and rule; the [conversion guide](conversion.md) covers getting
    faithful data *in* from OpenDSS in the first place. Once the model is built and solved, the companion
    discipline is [Trust but verify](tutorial_trust_but_verify.md) — checking the
    *solution* as rigorously as you documented the *inputs*.
