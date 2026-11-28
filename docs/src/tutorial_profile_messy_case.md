# [Profile your first messy case](@id profile-messy-case)

*Run the profiler on a small feeder with six planted defects, read what it
says, decide what each finding means, repair what is wrong, and check again.*

This is the loop every case goes through: **run → read → understand → decide →
recheck**. The feeder is small enough that you can see the whole of it, and
every block on this page is executed when the documentation is built, so the
output you see is what the code produces.

!!! note "Prerequisites"
    Only `BMOPFTools`. No solver is needed.

## 1. A clean case, and what clean looks like

The starting point is a bundled European-style feeder: a 10 kV / 400 V
delta-wye substation whose star point is earthed at the transformer, and a
four-wire LV feeder with three single-phase customers and one three-phase
customer.

```@example messy
using BMOPFTools

fixture = joinpath(pkgdir(BMOPFTools), "test", "data", "profiler_systems",
                   "eu_tn_four_wire.json")
clean = parse_bmopf(fixture)
report = analyze(clean)
println(length(errors(report)), " errors, ", length(warnings(report)), " warnings, ",
        length(infos(report)), " infos")
```

No errors and no warnings. The infos are worth a glance even on a clean case,
because they state what the profiler understood:

```@example messy
for f in infos(report)
    println(rpad(f.code, 28), first(f.message, 90))
end
```

An INFO is context, not a defect. `I.PRE.NO_VOLT_BOUNDS` says the case has no
voltage limits yet, which is true and expected before
[augmentation](augmentation.md). `I.SCHEMA.VERSION_UNKNOWN` appears because the
fixture carries no `meta["$schema"]` URI, so the JSON Schema layer is skipped
and only the field catalog runs; `I.PRE.XFMR_COIL_UNASSESSED` appears because
the coil-headroom screen estimates only single-phase transformer banks, and
this substation is a three-phase `delta_wye` unit. Nothing here asks you to
change the data.

## 2. The messy case

Real data rarely arrives like that. The next block plants six defects of the
kinds that conversions, exports and hand edits produce. Read the comments: you
will meet each one again in the report.

```@example messy
net = deepcopy(clean)

# 1. The export lost the star-point earth of the transformer.
delete!(net["bus"]["lv0"], "perfectly_grounded_terminals")
# 2. One line length was typed in kilometers (0.15) instead of meters (150).
net["line"]["f2"]["length"] = 0.15
# 3. Conductor ratings were never exported.
delete!(net["linecode"]["cable"], "i_max")
# 4. A reactive power was entered in the wrong unit: power factor 0.4.
net["load"]["h3"]["q_nom"] = [9000.0]
# 5. A spur to a bus with nothing on it, left over from a removed customer.
net["bus"]["stub"] = Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"])
net["line"]["spur"] = Dict{String,Any}("bus_from" => "lv1", "bus_to" => "stub",
    "terminal_map_from" => ["a", "b", "c", "n"], "terminal_map_to" => ["a", "b", "c", "n"],
    "linecode" => "cable", "length" => 40.0)
# 6. A terminal name typo on the three-phase customer: "m" instead of "n".
net["load"]["shop"]["terminal_map"] = ["a", "b", "c", "m"]
nothing # hide
```

## 3. Run and read

```@example messy
report = analyze(net)
println(length(errors(report)), " errors, ", length(warnings(report)), " warnings, ",
        length(infos(report)), " infos")
```

Read the errors first. An ERROR means the case cannot give a trustworthy
answer as it stands.

```@example messy
for f in errors(report)
    println(f.code, "  [", something(f.component_id, "network"), "]")
    println("    ", f.message)
end
```

Then the warnings: data that is suspicious or that degrades the result.

```@example messy
for f in warnings(report)
    println(f.code, "  [", something(f.component_id, "network"), "]")
    println("    ", first(f.message, 150))
end
```

Always match on `f.code`. The message is written for people and may be
reworded; the code is a stable identifier.

## 4. Understand a finding before acting on it

Each code has a catalog entry you can look up offline:

```@example messy
entry = explain_finding("E.PROV.FLOATING_NEUTRAL")
println(entry["severity"], " — ", entry["section_title"])
println(entry["meaning"])
```

The instance itself carries the evidence. For the floating neutral, the detail
names the buses of the affected neutral section:

```@example messy
floating = only(f for f in report.findings if f.code == "E.PROV.FLOATING_NEUTRAL")
println(floating.detail["buses"])
```

Why does a floating neutral matter? The neutral conductor connects the four LV
buses to each other, but nothing connects it to earth, and the delta-wye
transformer gives the LV side no galvanic path to the earthed source. The load
return currents then have no defined path to earth: the zero-sequence path is
undefined, and a four-wire analysis of the LV island is ill-posed. On its own,
the lost earth would also leave the LV island without any voltage reference
(`E.INT.NO_VOLTAGE_REFERENCE`: voltages defined only up to a common shift).
That error is absent here only by accident: because `m` is not a neutral, the
profiler reads the `shop` load as connected from each phase to earth, and that
typo is the island's only tie to earth. Two defects mask each other, which is
another reason to fix by cause. The profiler even points at where the earth
should have been:

```@example messy
hint = only(f for f in report.findings if f.code == "I.PROV.WYE_NEUTRAL_UNGROUNDED")
println(hint.message)
```

That is an INFO, and it is the most useful line in the report: it names the
transformer star point that has no earth. Severity tells you how bad the
consequence is, not how helpful the finding is. The physics of each grounding
finding, with a case where it is right and a case where it is harmless, is in
[Grounding and neutral findings explained](grounding_findings.md).

## 5. Decide

Sort every warning and error into one of three piles: **fix**, **decide**,
**disclose**.

| Finding | Pile | Why |
|---|---|---|
| `E.PROV.FLOATING_NEUTRAL` | **fix** | one defect: the lost star-point earth |
| `E.INT.UNKNOWN_TERMINAL`, `W.INT.FLOATING_LOAD_TERMINAL`, `W.INT.DEVICE_INDEXING_UNASSESSED` on `shop` | **fix** | one defect: the terminal typo |
| `W.DOM.LOAD_PF_LOW` on `h3` | **fix** | a power factor of 0.4 on a household is a unit error |
| `W.PROV.I_MAX_ABSENT` | **fix**, or **disclose** | ratings are missing; restore them from the source, or state that thermal limits are not enforced |
| `W.CONN.DANGLING` | **decide** | the spur carries nothing; remove it, or keep it and say so |

Seven warnings and errors, four defects to repair and one judgment call. Several
findings share a cause, which is why you sort by cause before touching the data.

One defect produced **no warning at all**: the line length typed in
kilometers. It is in the infos:

```@example messy
for f in report.findings
    f.code == "I.PROV.LINE_SWITCH_LIKE" && println(f.component_id, ": ", f.message)
end
```

A 15 cm line is electrically almost a short circuit, so the profiler notes
that it looks like a switch. It cannot know that the length is wrong: short
jumpers exist. This is the kind of finding that needs you. If the case had
coordinates, the [spatial checks](tutorial_spatial_cleanup.md) would compare
the length with the distance between the buses and settle it.

## 6. Repair and recheck

Fix what is wrong at the source of the error, not by silencing the finding.

```@example messy
fixed = deepcopy(net)
fixed["bus"]["lv0"]["perfectly_grounded_terminals"] = ["n"]        # the star-point earth
fixed["load"]["shop"]["terminal_map"] = ["a", "b", "c", "n"]      # the typo
fixed["load"]["h3"]["q_nom"] = [1300.0]                           # 4 kW at pf 0.95
fixed["linecode"]["cable"]["i_max"] = fill(250.0, 4)              # ratings from the source
fixed["line"]["f2"]["length"] = 150.0                             # meters
delete!(fixed["line"], "spur"); delete!(fixed["bus"], "stub")     # decision: remove the spur

after = analyze(fixed)
println(length(errors(after)), " errors, ", length(warnings(after)), " warnings")
```

Recheck by comparing codes, not by counting. A repair can remove findings and
can also introduce new ones:

```@example messy
before_codes = Set(f.code for f in report.findings)
after_codes = Set(f.code for f in after.findings)
println("cleared   : ", sort(collect(setdiff(before_codes, after_codes))))
println("introduced: ", sort(collect(setdiff(after_codes, before_codes))))
```

Nothing was introduced, and every code that came from a planted defect is
gone, including `I.TMAP.PERMUTED_ORDER`, which the terminal typo on `shop`
produced. The repaired case is the clean case again.

## 7. Keep the report

Write the report next to the case, so the next reader sees what was checked:

```@example messy
render(after, "messy-case-after.md")
println(first(readlines("messy-case-after.md"), 6) |> x -> join(x, "\n"))
```

## What to take away

- **Errors first, then warnings, then read the infos.** The most informative
  line can be an INFO.
- **Sort by root cause.** Several findings usually share one.
- **Three piles: fix, decide, disclose.** A finding you decide to live with is
  recorded, not hidden: see [Accept and track findings](howto_accept_findings.md).
- **Recheck by diffing codes.** A clean count can hide a new finding.

Next: [System types and regional practice](tutorial_system_types.md) shows what
the profiler reports for split-phase, high-leg delta, SWER and other systems;
[Findings triage at scale](tutorial_triage.md) applies the same loop to a
meshed MV/LV import with several thousand buses.
