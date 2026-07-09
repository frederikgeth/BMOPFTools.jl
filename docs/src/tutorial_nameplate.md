# From nameplate data to a defensible network model

*What you can derive, what you must assume, and what has to stay unknown.*

Real network data arrives incomplete. A cable has an impedance but no current
rating; a bus has a nominal voltage but no operating envelope; a feeder has loads
but nothing dispatchable to optimise. Turning that into a model an OPF can
respect means *writing numbers the source never gave you* — and the integrity of
the study depends on being honest about where each one came from.

BMOPFTools makes that honesty mechanical. Every value a preparation pass writes
is recorded in a **manifest** with the rule that produced it and a **confidence
tag**, so the finished case is self-documenting: you can see at a glance which
numbers are standards-derived, which are heuristic inferences to double-check,
and which are design choices you own. This tutorial walks one incomplete feeder
through that process and reads the provenance back out.

*Prerequisites: a Julia environment with `BMOPFTools` — the augmentation passes
need no solver. See [Case augmentation](augmentation.md) for the reference.*

## 1. An incomplete case

We start from a small LV feeder and, to mimic datasheets that list conductor
impedances but no ampacities, strip the current ratings. Nothing here is
invalid — it is just *optimisation-meaningless*: with no voltage bounds nothing
can be infeasible, and with no ratings nothing can bind.

```@example nameplate
using BMOPFTools, Printf

raw = parse_bmopf(joinpath(pkgdir(BMOPFTools), "examples", "lv1_14bus.json"))
for (_, lc) in raw["linecode"]; delete!(lc, "i_max"); end   # datasheets w/o ratings

n_bus_no_bounds = count(b -> !haskey(b, "v_min"), values(raw["bus"]))
n_lc_no_rating  = count(lc -> !haskey(lc, "i_max"), values(raw["linecode"]))
(buses_without_bounds = "$n_bus_no_bounds / $(length(raw["bus"]))",
 linecodes_without_rating = "$n_lc_no_rating / $(length(raw["linecode"]))")
```

## 2. Fill the gaps — and record where each number came from

[`augment_case`](@ref) fills only what is missing, never overwriting, and returns
the augmented network together with a [`TransformationManifest`](@ref). It never
mutates its input.

```@example nameplate
net, mf = augment_case(raw)
length(mf.entries)   # one entry per value written (or deliberately skipped)
```

Each entry carries a `confidence` tag. Grouping the written values by tag sorts
them onto a spectrum from *fully defensible* to *your call*:

```@example nameplate
tier(c) = c === :standard             ? "1. standards-derived" :
          c in (:high, :medium, :low) ? "2. inferred (heuristic estimate)" :
          c === :heuristic            ? "3. numerical default" :
          c === :synthetic            ? "4. synthetic (design choice)" :
                                        String(c)

byt = Dict{String,Int}()
for e in mf.entries
    e.new_value === nothing && continue          # skips are recorded too
    byt[tier(e.confidence)] = get(byt, tier(e.confidence), 0) + 1
end
sort(collect(byt))
```

One representative rule from each kind, so the tags are concrete:

```@example nameplate
seen = String[]
for e in mf.entries
    (e.new_value === nothing || e.rule in seen) && continue
    push!(seen, e.rule)
    @printf("[%-9s] %-30s → %s.%s\n", e.confidence, e.rule[1:min(30,end)],
            e.component_type, e.field)
end
```

Reading those tiers back as engineering judgment:

- **Standards-derived** (`:standard`) — the number *is* in a published standard.
  The voltage envelopes come straight from EN 50160 (`EN50160:2010§3.5`), and the
  slack generation from the Task Force spec. Trust these.
- **Inferred, heuristic** (`:high` / `:medium` / `:low`) — the thermal ratings
  (`heuristic_ampacity_estimate`). The pass reads each conductor's diagonal
  resistance R₁₁ as a *size fingerprint* and looks up a representative ampacity.
  This is **not** a standards-conformant rating: R₁₁ is the series resistance
  (conductor AC resistance **plus** the Carson earth-return term), so it does not
  identify the conductor's material, class, or installation — see the
  [thermal pass](augmentation.md#Pass-2-—-Thermal-limits). The confidence
  (`:high` vs `:medium`) mirrors how trustworthy the *impedance provenance* is
  (a geometry-`distinct` linecode vs a `near_balanced` one), so a `:medium` tag
  is a flag to check against your real conductor schedule before publishing.
- **Numerical default** (`:heuristic`) — loose regularisation floors added for
  solver conditioning, not physical claims.
- **Synthetic** (`:synthetic`) — pure design choices. These appear the moment you
  place dispatchable generation, which is a *scenario*, not a fact:

```@example nameplate
net_der, der_mf = add_generators(net)
[(e.rule, e.confidence) for e in der_mf.entries if e.confidence === :synthetic] |> unique
```

## 3. What must stay unknown

The passes fill what can be *defensibly* defaulted and leave the rest — the
confidence tag is the tell for what to revisit:

- A conductor's **material and installation** cannot be recovered from R₁₁ alone,
  so the ampacity is a heuristic estimate, tagged as such and capped at
  `:medium`/`:high` confidence rather than presented as a standard.
- Values a datasheet simply omits — a transformer's core-loss branch, a load's
  true ZIP split — are **not invented**. `augment_case` adds no such field; it
  fills operating *envelopes*, not missing *physics*.
- **Where and how large** to place DER is a study input, not a derivable quantity
  ([`add_generators`](@ref) is explicit about this — every placement is a
  `:synthetic` entry with a stated strategy, never random).

## 4. Provenance travels with the case

The manifest serialises, so the augmented case and its provenance can ship as a
pair — `(case.json, case_manifest.json)` — and every default stays auditable
long after the study:

```@example nameplate
sort(collect(keys(manifest_to_dict(mf))))
```

For the human-readable view, `render_manifest(mf)` prints the full diff grouped
by component. The discipline is the point: a benchmark is only as defensible as
its least-documented default, and the tag on every number tells the next reader —
or the reviewer — exactly which ones to trust and which to challenge.

!!! tip "Where to go next"
    [Case augmentation](augmentation.md) is the full pass-by-pass reference;
    the [conversion guide](conversion.md) covers getting faithful data *in* from
    OpenDSS in the first place. Once the model is built and solved, the companion
    discipline is [Trust but verify](tutorial_trust_but_verify.md) — checking the
    *solution* as rigorously as you documented the *inputs*.
