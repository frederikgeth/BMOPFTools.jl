# [Grounding and neutral findings explained](@id grounding-findings)

*What each grounding and neutral finding means electrically, one case where it
is right, and one case where the same data is harmless.*

The findings on this page are the ones people most often ask about, because
they concern something a positive-sequence tool never shows: where the neutral
is, and what ties the network to earth. For the modeling background, read
[Ground, neutral and earth return](tutorial_grounding.md) first; this page is
about reading the profiler's output. Every block is executed when the
documentation is built.

```@example grounding
using BMOPFTools

case(name) = parse_bmopf(joinpath(pkgdir(BMOPFTools), "test", "data",
                                  "profiler_systems", name * ".json"))
codes(report, prefixes...) = sort([f.code for f in report.findings
                                   if any(p -> occursin(p, f.code), prefixes)])
nothing # hide
```

## Two different questions

The profiler asks two separate questions, and they are easy to confuse.

1. **Does every island have a voltage reference?** An *island* is a set of
   buses joined by conductors; transformer windings separate islands. Every
   voltage in the model is measured to one common reference (earth). If nothing
   in an island is tied to that reference, its voltages can all shift by the
   same amount and still satisfy every equation: the problem has no unique
   answer. This is `E.INT.NO_VOLTAGE_REFERENCE`.
2. **Does every neutral conductor have a path to earth?** A neutral section is
   the set of buses joined by a *neutral* conductor. If it reaches no earth,
   the neutral's potential is undefined even when the phases are referenced
   some other way. This is `E.PROV.FLOATING_NEUTRAL` (or `W.` when nothing uses
   the neutral).

Both questions, and the conductor-group test below, read one body of evidence.
What counts as a tie to the reference:

| In the data | Counts as |
|---|---|
| `perfectly_grounded_terminals` on a bus | a zero-impedance tie |
| a `voltage_source` | pins each of its terminals, and the neutral of its bus |
| a `shunt` row with a nonzero sum (for example a one-terminal earth electrode) | a finite tie, for that terminal |
| a WYE or one-terminal SINGLE_PHASE load with no neutral in its map, on a phase with nonzero demand | a tie for that phase terminal: the solver writes the load against earth |
| a generator written the same way, with both P and Q fixed and not both zero | the same. A generator with a dispatch range is not a reference: a shift of its terminal voltages is absorbed by its output |
| line shunt admittance to earth (`G/B_from/to`, the line's capacitance), as the engine stamps it: from the linecode scaled by length, or from the line itself when it carries inline impedance; over the mapped conductors only | a finite tie at both ends |
| a transformer's `r_neutral_*` / `x_neutral_*` on a side with a neutral terminal | a finite tie at the winding's star point |

A delta-connected capacitor bank, whose admittance rows sum to zero, ties
phases to each other and not to earth, so it does not count.

A tie references only the conductors it reaches. Conductors are grouped by the
elements that fix voltage differences between them: a line conductor end to
end, the terminals of one winding, the two ends of an active load, generator or
IBR coil (a zero-power load coil, or a generator or inverter coil whose bounds,
ratings, power-factor control, an all-zero Volt-var curve or a zero DC-link balance force zero current, carries no current at any
voltage and ties nothing), two shunt
terminals with a nonzero admittance entry between them (listing a terminal in a
shunt's map connects it to nothing), the terminal pairs a capacitor bank
actually stamps. Each group needs
its own tie. An earth shunt on a neutral that is carried along a delta feeder,
with no winding or load between that neutral and the phases, leaves the phases
free to shift together; `E.INT.NO_VOLTAGE_REFERENCE` then names the floating
group (`detail["scope"] = "conductor_group"`), although the island as a whole
has a reference.

## A floating neutral

Start from the European feeder, whose neutral is earthed at the transformer,
and remove that earth:

```@example grounding
net = case("eu_tn_four_wire")
delete!(net["bus"]["lv0"], "perfectly_grounded_terminals")
report = analyze(net)
println(codes(report, "FLOATING", "NO_VOLTAGE", "WYE_NEUTRAL"))
```

Three findings, one cause. The neutral joins the LV buses but reaches no earth
(`E.PROV.FLOATING_NEUTRAL`); since it was the island's only tie to the
reference, the island has none either (`E.INT.NO_VOLTAGE_REFERENCE`); and the
INFO names the transformer star point where the earth is missing.

**When it is right:** always, for a solver. This case has no unique solution.

**The repair is one earth, and which kind is a modeling decision.** A real
electrode is not a perfect ground:

```@example grounding
net["shunt"] = Dict{String,Any}("electrode" => Dict{String,Any}(
    "bus" => "lv0", "terminal_map" => ["n"], "G_1_1" => 1 / 10.0, "B_1_1" => 0.0))
report = analyze(net)
println(codes(report, "FLOATING", "NO_VOLTAGE", "WYE_NEUTRAL"))
println(report.results[:provenance]["grounding"]["n_grounding_points"], " earthing point")
```

A 10 Ω electrode clears all three. The neutral will now rise above earth under
unbalanced load, which is what happens physically; a perfect ground would hide
that. Use `perfectly_grounded_terminals` only where zero neutral voltage is a
fair statement, such as a substation earth mat.

### The unused neutral

If a neutral section floats but no load or generator connects to it, nothing
depends on its potential, and the severity drops:

```@example grounding
net = case("eu_tn_four_wire")
delete!(net["bus"]["lv0"], "perfectly_grounded_terminals")
for l in values(net["load"])           # make every load phase-to-phase
    l["configuration"] == "SINGLE_PHASE" && (l["terminal_map"] = ["a", "b"])
end
delete!(net["load"], "shop")
println(codes(analyze(net), "FLOATING", "NO_VOLTAGE"))
```

The neutral finding drops to `W.PROV.FLOATING_NEUTRAL`: latent rather than
active, because no device depends on the neutral's potential. The island
finding stays an error, because the island as a whole still has no tie to the
reference. The two questions are answered separately, and one earth answers
both.

## Earthing through an impedance at the transformer

Many MV systems earth the transformer star point through a resistor or an
arc-suppression coil, and some LV systems use an impedance too. In the data
that is `r_neutral_to` / `x_neutral_to` (or `_from`) on the transformer:

```@example grounding
net = case("eu_tn_four_wire")
delete!(net["bus"]["lv0"], "perfectly_grounded_terminals")
net["transformer"]["delta_wye"]["sub"]["r_neutral_to"] = 5.0     # a 5 Ω earthing resistor
report = analyze(net)
println(isempty(errors(report)) ? "no errors" : [f.code for f in errors(report)])
```

The star point is tied to earth through 5 Ω, so the island is referenced and
the neutral is not floating. The same field on a side that has no neutral
terminal (the delta side) is ignored by the network builders, so it is not
counted there.

!!! note "An earthing impedance on the source bus"
    A `voltage_source` pins the neutral of its own bus to zero volts. A shunt
    on that terminal then carries no current, and the profiler says so with
    `W.DOM.SHUNT_ON_GROUNDED`. To study an impedance-earthed supply, model the
    source behind a transformer and put the impedance on the transformer's
    star point, as above.

## An island with no reference

An unearthed delta secondary, or an industrial IT system, has no intentional
tie to earth at all.

```@example grounding
bare = analyze(case("it_delta_island_unreferenced"))
finding = only(errors(bare))
println(finding.code)
println(finding.message)
```

**When it is right:** when the model truly contains no path to earth. The
line-to-line voltages are defined; the position of the whole triangle relative
to earth is not. A power flow on this case returns *an* answer, and its
phase-to-earth voltages are an accident of the starting point.

**When the physical system is fine:** always, in the sense that such systems
operate every day. What ties them to earth is the capacitance of their
conductors. Put that in the data and the island is referenced:

```@example grounding
capacitive = case("it_delta_island_capacitive")
println("B to earth per meter: ", capacitive["linecode"]["cable"]["B_from_1_1"] * 2, " S/m")
println(isempty(errors(analyze(capacitive))) ? "no errors" : "errors")
```

The finding is therefore not "this network is wrong" but "this model is
missing the thing that references it". If you do not have capacitance data, a
high-resistance shunt on each phase at one bus is the usual stand-in; state it
as an assumption.

## Was the neutral removed, or was it never there?

Most LV networks are four-wire. Many datasets, though, arrive with three
conductors because an earlier tool eliminated the neutral (Kron reduction),
which assumes the neutral sits at zero volts at every bus. Three findings
concern this.

| Code | What it says |
|---|---|
| `I.PROV.KRON_LIKELY` | An LV level has branches but none carries a neutral: the neutral may have been eliminated. A candidate, not a verdict. |
| `I.PROV.KRON_REDUCIBLE` | Every neutral is perfectly grounded, so eliminating it would be exact. The explicit neutral adds variables and no information. |
| `W.PROV.IMPLICIT_GROUNDING` | Components reference a neutral terminal, no branch carries a neutral, and some of those neutrals have no grounding: the intended return path is not determined by the data. |

**A candidate that deserves a look.** Take the four-wire feeder and strip the
neutral conductor from its lines, as a reduction would:

```@example grounding
net = case("eu_tn_four_wire")
for line in values(net["line"])
    line["terminal_map_from"] = ["a", "b", "c"]; line["terminal_map_to"] = ["a", "b", "c"]
end
lc = net["linecode"]["cable"]
net["linecode"]["cable"] = merge(Dict{String,Any}(k => v for (k, v) in lc if !occursin("4", k)),
                                 Dict{String,Any}("i_max" => fill(250.0, 3)))
report = analyze(net)
println(codes(report, "KRON", "IMPLICIT"))
```

The loads still connect to a neutral terminal that no conductor carries:
`I.PROV.KRON_LIKELY` raises the question and `W.PROV.IMPLICIT_GROUNDING` states
the consequence. Go back to the source data: if the neutral was eliminated, the
study cannot show neutral voltage rise or neutral current, and you should say
so or restore the conductor.

**The same absence, harmless.** A network that is three-wire by construction
raises nothing. The delta island behind a wye-delta transformer has no neutral
that could have been removed:

```@example grounding
report = analyze(case("it_delta_island_capacitive"))
println(codes(report, "KRON", "IMPLICIT"))
println(report.results[:provenance]["wires_by_level"]["LV_231V"]["delta_fed"])
```

A level supplied by a delta secondary is recognized as three-wire and not
flagged. An MV level is not flagged either: three-wire MV is the norm.

**The explicit neutral that adds nothing.**

```@example grounding
net = case("eu_tn_four_wire")
for b in ("lv1", "lv2")
    net["bus"][b]["perfectly_grounded_terminals"] = ["n"]
end
println(codes(analyze(net), "KRON"))
```

With every neutral pinned to zero volts, the neutral conductor carries no
voltage information: `I.PROV.KRON_REDUCIBLE`. That is correct for a network
that really is solidly earthed at every bus, and a warning sign if the perfect
grounds were added only to make a case solve. See
[Network reduction](network_reduction.md) for removing such a neutral exactly.

## Reading order for a grounding problem

1. Look at `results[:provenance]["grounding"]`: neutral sections, earthing
   points, floating sections.
2. If there is an `E.` finding, find the island or neutral section it names and
   ask what should tie it to earth. The `I.PROV.WYE_NEUTRAL_UNGROUNDED` finding
   usually points at the place.
3. Decide what kind of tie is true: a finite electrode, a transformer
   impedance, line capacitance, or a perfect ground. Each is a statement about
   the physical system.
4. Re-run and compare codes.

A worked example of the whole loop is in
[Profile your first messy case](tutorial_profile_messy_case.md).
