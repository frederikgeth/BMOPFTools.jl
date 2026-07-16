# [Findings triage: from raw import to defensible case](@id findings-triage)

*A 3400-bus meshed import arrives with a hundred-plus findings. Learn to sort
them into defects to fix, judgment calls to decide, and disclosures to keep —
and to leave a paper trail for each.*

Real network data is never clean. An OpenDSS feeder that has passed through
utility GIS exports, student edits, and format conversions arrives carrying
structural cruft, suspicious parameters, and modelling conventions that only
made sense in the source tool. The reflex responses — ignore all warnings, or
"fix" everything until the report is silent — are both wrong: the first ships
defects, the second destroys provenance and can change the physics. This
tutorial works a deliberately messy case end to end and builds the habit the
[judgment spine](choose_tutorial.md#The-judgment-spine) starts with:
**triage**. Every block runs at build time.

!!! note "Prerequisites"
    Only `BMOPFTools` — nothing here needs a solver. The
    [analysis reference](analysis.md) and the
    [finding-code reference](findings.md) are the companion pages;
    the [end-to-end tutorial](tutorial_end_to_end.md) covers the
    pipeline this one prepares a case *for*.

## 1. The patient: a meshed MV/LV network

The `MVLVmeshed` test case is a combined MV + LV network in which
normally-open ties and switches were deliberately re-added — a stand-in for
the real-world case where you receive a *system*, not a tidy radial feeder:

```@example triage
using BMOPFTools

path = joinpath(pkgdir(BMOPFTools), "test", "data", "MVLVmeshed", "Master.dss")
net  = from_dss(path)
println(length(net["bus"]), " buses, ", length(net["line"]), " lines, ",
        length(net["switch"]), " switches, ", length(net["load"]), " loads, ",
        sum(length(d) for d in values(net["transformer"])), " transformers")
```

Two independent layers of messages describe what you just loaded, and they
must not be conflated: what the **importer** could not carry across, and what
the **analyzer** thinks of the network that arrived.

## 2. Layer one: what the import could not represent

[`from_dss`](@ref) records every piece of OpenDSS information it had to drop
or reinterpret in `net["_meta"]["powerio_warnings"]` — the import's fidelity
ledger:

```@example triage
pw = net["_meta"]["powerio_warnings"]
println(length(pw), " import warnings; a sample:")
for w in pw[1:3]
    println("  • ", w)
end
```

Triage layer one *first*, because nothing downstream can see what never
arrived. Most entries here are cosmetic (`units` fields the schema carries
differently), but this ledger is where a dropped regulator control or an
unsupported element would appear — losses that no amount of downstream
analysis can detect. Read it once, note anything electrical, and move on.

## 3. Layer two: the findings report and its severity contract

[`analyze`](@ref) runs the full validation battery and returns findings with
a three-level severity contract:

- **`E.*` errors** — the case is broken; solves will fail or be meaningless.
  These are not judgment calls.
- **`W.*` warnings** — something *deserves a decision*: possibly a data
  defect, possibly a legitimate feature of this network. Your job.
- **`I.*` infos** — disclosures: provenance, symmetry observations, benchmark
  realism notes. They are the case's honesty record, not problems.

```@example triage
report = analyze(net)
println("errors ", length(errors(report)),
        " / warnings ", length(warnings(report)),
        " / infos ", length(infos(report)))

wcount = Dict{String,Int}()
for f in warnings(report)
    wcount[String(f.code)] = get(wcount, String(f.code), 0) + 1
end
println("\nwarnings by code:")
for (c, n) in sort(collect(wcount))
    println("  ", rpad(c, 26), n)
end
```

Zero errors — the case is *usable* — and a set of warnings that now get
individual verdicts, not a blanket one.

## 4. Reading warnings like a reviewer

Walk the table. Each code gets one of three verdicts: **fix** (a defect with
a mechanical repair), **decide** (investigate, then either change the data or
accept and document), or **disclose** (true of this network by design — keep
the finding as part of the case's record).

```@example triage
for code in ("W.CONN.MESHED", "W.CONN.DANGLING", "W.DOM.XFMR_STEP_UP",
             "W.OPS.XFMR_OVERLOADED")
    f = first(f for f in warnings(report) if String(f.code) == code)
    println(f.code, "\n   ", f.message, "\n")
end
```

- **`W.CONN.MESHED` → disclose.** This case is meshed *on purpose* (the ties
  are the point). On a supposedly radial feeder the same finding would be a
  defect. The code cannot know which — that is exactly why it is a warning
  and not an error.
- **`W.CONN.DANGLING` → fix.** Hundreds of degree-1 buses with nothing
  attached are conversion cruft (service points whose customers were
  modelled elsewhere). They bloat the model and can hide genuine islands;
  a mechanical repair exists (§5).
- **`W.DOM.XFMR_STEP_UP` / `W.DOM.XFMR_REVERSED` → decide.** A transformer
  oriented *away* from the source usually means swapped
  `v_nom_from`/`v_nom_to` in the source data — but it can be a genuine boost
  unit or, in a meshed network, an artefact of hop-counting through the
  ties. Check these four against the source data; do not auto-"fix" what
  might be real.
- **`W.OPS.XFMR_OVERLOADED` → decide, urgently.** A transformer at thousands
  of percent utilisation at nominal load is not an operating condition — it
  is a **units or rating smell** (a kVA nameplate parsed where MVA was
  meant, or a lumped load on a service transformer). This warning is doing
  its most valuable work here: pointing at data whose *solve* would
  otherwise quietly hit the nameplate cap and report heavy curtailment.
- **`W.DIV.LOAD_SYMMETRIC` → disclose.** Nearly all loads share identical
  nameplates — a benchmark-realism note straight out of the
  [benchmarking-gap](benchmarking_gap.md) argument. Anyone consuming this
  case should know its load diversity is synthetic.

The verdicts differ per network. The discipline is that each warning code
gets *a* verdict, written down — the triage table above is two sentences per
code away from being the "data quality" section of your paper's appendix.

## 5. Mechanical repairs: `fix_case`

The "fix" verdicts have a dedicated tool. [`fix_case`](@ref) applies
**lossless, semantics-preserving** structural repairs — largest connected
component, series-line merging and dangling-stub removal (via
[`simplify_network`](@ref)), zero-load removal, near-zero-impedance lines to
switches, redundant source-bus bounds — and returns a manifest recording
every change. Physics-*changing* repairs (promoting grounding shunts to
perfect groundings, snapping placeholder impedances) exist but are **opt-in**
flags on [`FixRecipe`](@ref), off by default:

```@example triage
fixed, manifest = fix_case(net)

d = manifest_to_dict(manifest)
counts = Dict{String,Int}()
for e in d["entries"]
    counts[string(get(e, "field", "?"))] = get(counts, string(get(e, "field", "?")), 0) + 1
end
println(length(d["entries"]), " manifest entries, by kind:")
for (c, n) in sort(collect(counts); by = x -> -x[2])
    println("  ", rpad(c, 22), n)
end
println("\nbuses ", length(net["bus"]), " → ", length(fixed["bus"]),
        ",  lines ", length(net["line"]), " → ", length(fixed["line"]))
```

Note what the manifest records besides the changes: the *blocked* merges
(different linecodes, switches mid-run, non-line elements) — refusals are
part of the paper trail too, and one of them (`SWITCH_IN_CHAIN`) is itself a
data smell worth a look. Also note the paired `SHUNT_DROPPED` entries: every
removed stub that carried charging susceptance is called out, because
dropping it perturbs the nodal balance — `fix_case` is honest about the
edges of "lossless". Re-analyze to see the effect:

```@example triage
report2 = analyze(fixed)
println("after fix_case: errors ", length(errors(report2)),
        " / warnings ", length(warnings(report2)),
        " / infos ", length(infos(report2)))
for f in warnings(report2)
    String(f.code) == "W.CONN.DANGLING" && println(f.message)
end
```

Two instructive things happened. First, the dangling population collapsed
(534 → 55 buses) but did **not** vanish: the survivors hang off *switches*,
and `fix_case` deliberately refuses to treat an operable device as cruft —
those 55 need a human verdict (normally-open points? metering stubs?).
Second, compare the warning tables before and after: the transformer
*orientation* warnings changed count. Findings are functions of the network
— the orientation heuristic ranks source-distance in hops, and merging
series lines changed the hop metric — so **re-triage after every
transformation**; a verdict written for the raw network does not
automatically transfer. The counts that remain are the "decide" and
"disclose" verdicts of §4 — repairs were never going to (and never should)
silence those.

## 6. From triaged to solvable: bounds, costs, and the gates

A triaged case still is not an optimisation case — this import carries no
voltage bounds, no thermal limits, no costs (`I.PRE.NO_VOLT_BOUNDS` in the
report). [`augment_case`](@ref) synthesizes the missing operating envelope,
and its honesty mechanism is the point: *every* synthesized value is stamped
with a provenance finding, so the info count explodes — by design:

```@example triage
ready, aug_manifest = augment_case(fixed; recipe = AugmentationRecipe())
report3 = analyze(ready)
println("after augment: errors ", length(errors(report3)),
        " / warnings ", length(warnings(report3)),
        " / infos ", length(infos(report3)))
```

Thousands of infos now record which bounds are standards-derived and which
are synthetic — the [nameplate tutorial](tutorial_nameplate.md)'s confidence
tiers, applied at scale. Two gates then say whether the result is ready for
its intended use:

```@example triage
pre = infeasibility_preflight(ready, report3.findings)
rdy = benchmark_readiness_check(ready, report3.findings)
println("preflight keys : ", sort(collect(keys(pre))))
println("readiness keys : ", sort(collect(keys(rdy))))
for s in get(rdy, "suggestions", String[])
    println("  suggestion: ", s)
end
```

[`infeasibility_preflight`](@ref) screens for structurally-doomed solves
*before* you spend solver time (the
[infeasibility tutorial](tutorial_infeasibility.md) picks up when a solve
fails anyway); [`benchmark_readiness_check`](@ref) asks the publication
question — well-posed objective, meaningful constraints, no degeneracy traps
— and its suggestions are your remaining to-do list. Here it lands the
verdict this whole case has been building toward: with only the priced slack,
the *dispatch* problem is trivial — a triaged, bounded, solvable case is
still not a benchmark until it carries decisions worth optimising (the
[DER placement tutorial](tutorial_ders.md) is that step).

## 7. What a defensible case ships with

The end state of triage is *not* a silent report. This case ships as: the
repaired network, **plus** the residual warnings with their written verdicts
(meshed by design; load symmetry synthetic; four transformer orientations
checked against source; the overload smell resolved or documented), **plus**
the import ledger and both manifests. That bundle is what makes the case
*reviewable* — the difference between "we cleaned the data" and a benchmark
someone can trust. It is deliberately the same discipline the engine applies
to itself: derived values are stamped, approximations are listed, and
refusals are recorded.

This tutorial stopped at the gates on purpose — solving a 2700-bus meshed
case is a topic of its own. Take the triaged case onward: the
[simplification tutorial](tutorial_simplify.md) reduces it further where
fidelity allows, and the [end-to-end tutorial](tutorial_end_to_end.md)'s
solve-and-profile loop applies unchanged.

!!! tip "Where to go next"
    The [finding-code reference](findings.md) is the complete catalogue
    behind §3–4; [analysis & reports](analysis.md) documents the report
    object; [case augmentation](augmentation.md) details every pass §6
    invoked; and the [nameplate tutorial](tutorial_nameplate.md) is the
    per-device version of the same provenance discipline.
