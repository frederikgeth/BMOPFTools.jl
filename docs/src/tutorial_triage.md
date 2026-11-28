# [Case study: findings triage at scale](@id findings-triage)

!!! note "External dataset"
    This tutorial uses CC BY-NC-SA data kept in BMOPFDraftData. Set
    `ENV["BMOPF_RESTRICTED_DATA"] = "/path/to/BMOPFDraftData/test/data"`
    before running it. The dataset retains its upstream license and is not
    bundled with BMOPFTools. These dataset examples are shown as code and
    are not executed by the package documentation build, so the counts quoted
    in the text are from one run. The `MVLVmeshed` deck currently fails to
    import with the released PowerIO
    ([powerio#968](https://github.com/eigenergy/powerio/issues/968)).

*A meshed MV/LV import with several thousand buses arrives with more than a
hundred findings. Sort them into defects to fix, judgment calls to decide, and
disclosures to keep, and record a verdict for each.*

[Profile your first messy case](tutorial_profile_messy_case.md) teaches the
loop of run, read, decide, repair and recheck on a feeder small enough to read
in full. This case study applies the same loop to a network too large to
inspect by hand. Three things change at that scale: verdicts are given per
finding code rather than per finding, repairs are mechanical and must leave a
manifest, and every transformation changes the findings, so the case is
triaged again after each one. The case ends at the readiness gates, with the
bundle a reviewer needs.

!!! note "Prerequisites"
    Only `BMOPFTools`; nothing here needs a solver. The
    [analysis reference](analysis.md) and the
    [finding-code reference](findings.md) are the companion pages.

## 1. The case: a meshed MV/LV network

The `MVLVmeshed` test case is a combined MV and LV network in which
normally-open ties and switches were re-added. It stands in for the common
situation where you receive a whole system rather than a radial feeder:

```julia
using BMOPFTools

path = joinpath(ENV["BMOPF_RESTRICTED_DATA"], "MVLVmeshed", "Master.dss")
net  = from_dss(path)
println(length(get(net, "bus", Dict())), " buses, ",
        length(get(net, "line", Dict())), " lines, ",
        length(get(net, "switch", Dict())), " switches, ",
        length(get(net, "load", Dict())), " loads, ",
        sum((length(d) for d in values(get(net, "transformer", Dict()))); init=0),
        " transformers")
```

## 2. The first report

The report mixes two sources. Codes starting with `EMIT.` or `READ.` come from
the importer and list what OpenDSS information was dropped or reinterpreted;
[Porting an OpenDSS feeder](@ref opendss-port) explains how to read them, and
the full list is in `net["_meta"]["powerio_warnings"]`. Read them first, since
nothing downstream can detect what never arrived. Codes starting with `E.`,
`W.` or `I.` come from this package's analysis: errors must be fixed, warnings
need a decision, and infos are disclosures. The
[finding-code reference](findings.md) defines each code and
[Analysis & reports](analysis.md) the report object.

At this scale, count the warnings by code:

```julia
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

There are no errors, so the case is usable, and the warnings fall into a
handful of codes.

## 3. A verdict per code

Each warning code gets one of three verdicts: **fix** (a defect with a
mechanical repair), **decide** (investigate, then change the data or accept
and document), or **disclose** (true of this network by design; keep the
finding as part of the case's record). Read one example message per code:

```julia
warns = warnings(report)
for code in ("W.CONN.MESHED", "W.CONN.DANGLING", "W.DOM.XFMR_STEP_UP",
             "W.DOM.XFMR_REVERSED", "W.OPS.XFMR_OVERLOADED", "W.DIV.LOAD_SYMMETRIC")
    i = findfirst(f -> String(f.code) == code, warns)
    if isnothing(i)
        println(code, "\n   (not emitted for this network)\n")
    else
        f = warns[i]
        println(f.code, "\n   ", f.message, "\n")
    end
end
```

- **`W.CONN.MESHED`: disclose.** This case is meshed on purpose. On a feeder
  meant to be radial the same finding would be a defect; the code cannot tell
  which, so it is a warning and not an error.
- **`W.CONN.DANGLING`: fix.** Degree-1 buses with nothing attached are
  conversion leftovers, typically service points whose customers were modeled
  elsewhere. They enlarge the model and can hide genuine islands, and a
  mechanical repair exists (§4).
- **`W.DOM.XFMR_STEP_UP` and `W.DOM.XFMR_REVERSED`: decide.** A transformer
  oriented away from the source usually means `v_nom_from` and `v_nom_to` were
  swapped in the source data, but it can be a genuine boost unit or, in a
  meshed network, an artifact of counting hops through the ties. Check each
  against the source data rather than changing it automatically.
- **`W.OPS.XFMR_OVERLOADED`: decide first.** A transformer loaded at many times
  its rating by nominal demand alone is not an operating condition. It points
  at a units or rating error (a kVA nameplate read as MVA, or a lumped load on
  a service transformer). The OPF enforces the transformer rating, so a solve
  would fail or be bound by it.
- **`W.DIV.LOAD_SYMMETRIC`: disclose.** Nearly all loads share identical
  nameplates. Anyone using the case should know that its load diversity is
  synthetic; see [the benchmarking gap](benchmarking_gap.md).

The verdicts are specific to this network. Written down, one or two sentences
per code, they form the data-quality section of a paper's appendix.

## 4. Mechanical repairs with `fix_case`

The fix verdicts have a dedicated tool. By default [`fix_case`](@ref) runs
structural repairs: it keeps only the components reachable from a source,
merges series lines and removes dangling stubs (via
[`simplify_network`](@ref)), removes zero loads, removes satisfied bounds on
fixed source terminals, and removes ideal conductors between two earthed
terminals. It returns a manifest that records every change. These defaults are
not lossless: they can remove disconnected assets, and pruning a stub drops any
shunt it carried. Approximations (low-impedance lines to switches, inferred
current bounds, promoting grounding shunts to perfect groundings,
re-representing capacitive shunts, snapping placeholder impedances) are
**opt-in** flags on [`FixRecipe`](@ref), off by default.

At this scale, summarize the manifest by kind rather than reading it entry by
entry:

```julia
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

The manifest records refusals as well as changes. Blocked merges (different
linecodes, switches mid-run, non-line elements) are listed, and
`SWITCH_IN_CHAIN` in particular deserves a look, since it often indicates a
data error. Each removed stub that carried charging susceptance is listed as
`SHUNT_DROPPED`, because dropping it changes the nodal balance.

## 5. Triage again after every transformation

```julia
report2 = analyze(fixed)
println("after fix_case: errors ", length(errors(report2)),
        " / warnings ", length(warnings(report2)),
        " / infos ", length(infos(report2)))
for f in warnings(report2)
    String(f.code) == "W.CONN.DANGLING" && println(f.message)
end
```

Two things change. First, fewer buses are dangling, but some remain: they hang
off switches, and `fix_case` does not remove an operable device. Each needs a
verdict (a normally-open point, or a metering stub). Second, the transformer
orientation warnings change count. The orientation heuristic ranks distance
from the source in hops, and merging series lines changed the hop count.
Findings are functions of the network, so a verdict written for the raw
network does not automatically carry over to the repaired one. The remaining
warnings are the decide and disclose verdicts of §3, which no repair should
silence.

## 6. From triaged to solvable: bounds, costs and the gates

A triaged case is not yet an optimization case. This import carries no voltage
bounds, thermal limits or costs (`I.PRE.NO_VOLT_BOUNDS` in the report).
[`augment_case`](@ref) synthesizes the missing operating envelope and records
every synthesized value in the returned [`TransformationManifest`](@ref), with
the rule that produced it and a confidence level:

```julia
ready, aug_manifest = augment_case(fixed; recipe = AugmentationRecipe())
report3 = analyze(ready)
println("after augment: errors ", length(errors(report3)),
        " / warnings ", length(warnings(report3)),
        " / infos ", length(infos(report3)))

byconf = Dict{String,Int}()
for e in manifest_to_dict(aug_manifest)["entries"]
    byconf[e["confidence"]] = get(byconf, e["confidence"], 0) + 1
end
println("augmentation entries by confidence: ", byconf)
```

The confidence levels separate standards-derived values from synthetic ones,
the same tiers the [nameplate tutorial](tutorial_nameplate.md) applies per
device. Two gates then say whether the result is ready for its intended use:

```julia
# analyze has already run both gates: read their results from the report.
# (Calling the passes again with report3.findings would append duplicates.)
pre = report3.results[:preflight]
rdy = report3.results[:benchmark]
println("preflight keys : ", sort(collect(keys(pre))))
println("readiness keys : ", sort(collect(keys(rdy))))
for s in get(rdy, "suggestions", String[])
    println("  suggestion: ", s)
end
```

[`infeasibility_preflight`](@ref) screens for solves that are structurally
infeasible before you spend solver time; the
[infeasibility tutorial](tutorial_infeasibility.md) covers a solve that fails
anyway. [`benchmark_readiness_check`](@ref) asks whether the case is fit to
publish as a benchmark: a well-posed objective, meaningful constraints, and no
degeneracy. Its suggestions are the remaining work. Here it reports that with
only the priced slack the dispatch problem is trivial: a bounded, solvable case
is not a benchmark until it carries decisions worth optimizing, which the
[DER placement tutorial](tutorial_ders.md) adds.

## 7. What a defensible case ships with

The end state of triage is not a silent report. This case ships as the repaired
network, plus the residual warnings with their written verdicts (meshed by
design; load symmetry synthetic; transformer orientations checked against the
source; the overload resolved or documented), plus the import warnings and both
manifests. With that bundle a reviewer can check every change, every
synthesized value and every refusal, rather than taking "we cleaned the data"
on trust.

Solving a meshed case of several thousand buses is a topic of its own, so this
case study stops at the gates. To continue, the
[simplification tutorial](tutorial_simplify.md) reduces the case further where
fidelity allows, and the solve-and-profile loop of the
[end-to-end tutorial](tutorial_end_to_end.md) applies unchanged.

!!! tip "Where to go next"
    The [augmentation reference](augmentation_reference.md) details every pass §6 invoked, and the
    [nameplate tutorial](tutorial_nameplate.md) applies the same provenance
    discipline to single devices.
