# [Grounding and neutral findings explained](@id grounding-findings)

*What each grounding and neutral finding means electrically, and how to tell
a modeling error from a legitimate feature of the network.*

The findings on this page are the ones people most often ask about, because
they concern something a positive-sequence tool never shows: where the neutral
is, and what ties the network to earth. For the modeling background, read
[Ground, neutral and earth return](tutorial_grounding.md) first; this page is
about reading the profiler's output. Every block is executed when the
documentation is built.

The examples use the regional fixtures in `test/data/profiler_systems/`, named
after the IEC 60364 earthing systems. In a **TN** system the supply neutral is
earthed at the source and customer protective conductors connect back to it;
`eu_tn_four_wire` models this as one perfect ground at the transformer star
point. In a **TT** system each customer has its own electrode, connected to
the installation's exposed metalwork but not to the neutral, so the network
model looks the same as TN: the neutral is earthed at the source only. The
Australian and New Zealand **MEN** (multiple earthed neutral) practice, a form
of TN-C-S, bonds the neutral to earth at every customer installation as well
as at the transformer, so the neutral has many earth paths in parallel;
`au_men_four_wire` models them as finite electrodes (10 Ω at the transformer,
30 Ω at each customer). Modeled instead as perfect grounds at every bus, an
MEN neutral is held at zero volts everywhere, and
[`I.PROV.KRON_REDUCIBLE`](@ref kron-reducible-men) then fires for a
legitimate reason. An **IT** system is unearthed or earthed through a high
impedance; the `it_delta_island_*` fixtures cover it.

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

A tie references only the conductors it reaches. Conductors form groups
through the elements that fix voltage differences between them:

- a line conductor, end to end;
- the terminals of one transformer winding;
- the two ends of a load, generator or IBR coil that can carry current. A
  zero-power load coil, or a generator coil whose bounds or ratings force zero
  current, ties nothing; for IBR coils see the note below;
- two shunt terminals with a nonzero admittance entry between them (listing a
  terminal in a shunt's map does not by itself connect it to anything);
- the terminal pairs a capacitor bank actually stamps.

Each group needs its own tie. An earth shunt on a neutral that is carried along a delta feeder,
with no winding or load between that neutral and the phases, leaves the phases
free to shift together; `E.INT.NO_VOLTAGE_REFERENCE` then names the floating
group (`detail["scope"] = "conductor_group"`), although the island as a whole
has a reference.

!!! note "When an IBR counts as a connection"
    An IBR coil ties its two terminals unless the constraints the solver
    stamps on it (P and Q bounds, power-factor rules, zero-base Volt-var or
    Volt-watt laws, DC-link balance) force its active and reactive power to
    zero at every voltage; voltage-dependent limits are never used to drop a
    coil. See `E.INT.NO_VOLTAGE_REFERENCE` in the
    [finding-code reference](findings.md#INT-—-structural-integrity).

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

A 10 Ω electrode clears all three. In this case it is the only earth, so no
current can return through it: the star-point neutral sits at earth potential
and the neutral rises along the feeder by the drop of the neutral current, the
same solution as with a perfect ground. The choice matters once there is a
second earth path, such as customer multiple-earthed-neutral (MEN) bonds,
distributed electrodes, or a fault: a perfect ground then diverts return
current from the neutral conductor into earth that a real electrode would not
(see
[Ground, neutral and earth return](tutorial_grounding.md)). Use
`perfectly_grounded_terminals` only where zero neutral voltage is a fair
statement, such as a substation earth mat.

### The unused neutral

If a neutral section floats but no load or generator connects to it, nothing
depends on its potential, and the severity drops:

```@example grounding
net = case("eu_tn_four_wire")
delete!(net["bus"]["lv0"], "perfectly_grounded_terminals")
for l in values(net["load"])           # single-phase loads go phase-to-phase
    l["configuration"] == "SINGLE_PHASE" && (l["terminal_map"] = ["a", "b"])
end
delete!(net["load"], "shop")           # the wye shop uses the neutral: remove it
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

An unearthed delta secondary, or an isolated (unearthed) industrial IT system,
has no intentional tie to earth at all. (An IT system may instead be earthed
through a high impedance; model that impedance as a shunt.)

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
flagged. The check considers only levels below 1 kV and never flags an MV
level: three-wire MV is common in some regions (much of Europe and Australia)
and four-wire multigrounded MV in others (North America), so a missing MV
neutral is no evidence of a reduction.

### [The explicit neutral that adds nothing](@id kron-reducible-men)

The MEN fixture earths its neutral through finite electrodes, and raises no
reduction finding. Replace each electrode by a perfect ground, a common
idealization of MEN bonds:

```@example grounding
println(codes(analyze(case("au_men_four_wire")), "KRON"))
net = case("au_men_four_wire")
for s in values(net["shunt"])
    net["bus"][s["bus"]]["perfectly_grounded_terminals"] = ["n"]
end
delete!(net, "shunt")
println(codes(analyze(net), "KRON"))
```

With every neutral pinned to zero volts, the neutral conductor carries no
voltage information: `I.PROV.KRON_REDUCIBLE`. For an MEN network that is a
consequence of the modeling choice, not a defect; it says the four-wire model
can be reduced to three wires exactly. It is a warning sign only where the
perfect grounds were added to make a case solve. Finite electrodes keep the
neutral voltage rise the perfect grounds remove. See
[Network reduction](@ref network-reduction) for removing such a neutral exactly.

## Reading order for a grounding problem

1. Look at `results[:provenance]["grounding"]`: `n_neutral_components`,
   `n_grounding_points`, `n_floating`, and, when neutral conductors are
   present on branches, `floating_components` (the bus lists of the floating
   neutral sections).
2. If there is an `E.` finding, find the island or neutral section it names and
   ask what should tie it to earth. The `I.PROV.WYE_NEUTRAL_UNGROUNDED` finding
   usually points at the place.
3. Decide what kind of tie is true: a finite electrode, a transformer
   impedance, line capacitance, or a perfect ground. Each is a statement about
   the physical system.
4. Re-run and compare codes.

A worked example of the whole loop is in
[Profile your first messy case](tutorial_profile_messy_case.md).

## Related codes

These codes also concern neutrals and earth returns; the
[finding-code reference](findings.md) has the full triggers.

| Code | What it says |
|---|---|
| [`I.PROV.SWER_ZONE`](findings.md#Zone-phase-topology) | A transformer-isolated zone carries one phase conductor and no neutral on its branches: a single-wire earth return (SWER) section. |
| [`W.INT.WYE_WITHOUT_NEUTRAL`](findings.md#INT-—-structural-integrity) | A wye load or generator sits at a bus with no identifiable neutral, which implies an undeclared earth return. |
| [`W.INT.IMAX_NO_NEUTRAL`](findings.md#INT-—-structural-integrity) | A star generator or IBR with two or more phases rates only its phase conductors; the neutral, which can carry more current under unbalance compensation, needs its own `i_max` entry. |
| [`W.CONV.MULTIPLE_NEUTRALS`](findings.md#CONV-—-terminal-role-conventions) | One bus carries more than one terminal classified as neutral. |
| [`I.SOL.NEUTRAL_SHIFT`](findings.md#SOL-—-solution-profiling) | After a solve, the largest neutral terminal voltage and its bus. Unbalance or an earthing impedance makes it nonzero. |
