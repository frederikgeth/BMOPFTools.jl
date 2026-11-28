# [System types and regional practice](@id system-types)

*What the profiler reports for the wiring and earthing practices used in North
America, Europe, Japan and Australia, shown on one small case each, and where
its knowledge stops.*

Distribution networks are not built the same way everywhere. A European LV
feeder is three-phase four-wire with the neutral earthed at the substation. A
North American one runs a multi-grounded neutral along the primary and feeds
houses from center-tapped single-phase transformers. Japan uses a three-wire
6.6 kV primary and V-connected transformer pairs. Rural Australia uses a
single wire and the earth. The profiler has to describe each of these without
mistaking a legitimate practice for a defect.

Every case on this page is a bundled fixture in `test/data/profiler_systems`,
and every block is executed when the documentation is built.

!!! note "Prerequisites"
    `BMOPFTools`, plus `JuMP` and `Ipopt` for the two power-flow cross-checks.

```@example systems
using BMOPFTools

case(name) = parse_bmopf(joinpath(pkgdir(BMOPFTools), "test", "data",
                                  "profiler_systems", name * ".json"))

function summarize(net)
    report = analyze(net)
    conn = report.results[:connectivity]
    levels = report.results[:voltage_levels]["bus_voltage_map"]
    println(length(errors(report)), " errors, ", length(warnings(report)), " warnings")
    for z in sort(conn["zones"], by = z -> z["label"])
        println("  zone at ", rpad(z["label"], 6), rpad(z["topology"], 13),
                "phases ", z["phases"])
    end
    println("  bus levels (V): ",
            join(["$b=$(round(Int, levels[b]))" for b in sort(collect(keys(levels)))], "  "))
    report
end
nothing # hide
```

`summarize` prints the three things to look at first for any case: the error
and warning counts, the **zones**, and the **bus levels**.

A *zone* is a set of buses joined by lines and closed switches. Transformers
separate zones, because their windings are galvanically isolated. Each zone is
classified by the phase conductors it carries. A *bus level* is the nominal
voltage of one conductor to the reference, propagated from the source through
the transformer ratios.

## [Europe: three-phase four-wire, earthed at the substation](@id systems-europe)

```@example systems
report = summarize(case("eu_tn_four_wire"))
nothing # hide
```

Two three-phase zones (MV and LV) and an LV level of 231 V, which is 400 V
line-to-line. The neutral is earthed once, at the transformer:

```@example systems
g = report.results[:provenance]["grounding"]
println("neutral sections: ", g["n_neutral_components"],
        ", earthing points: ", g["n_grounding_points"],
        ", floating: ", g["n_floating"])
```

One earthing point is enough for the profiler: the neutral section has a path
to earth. Whether the installation is TN-S, TN-C-S or TT is a question about
the customer's protective earth, which this data model does not represent, so
the earthing report says so rather than guessing:

```@example systems
for z in report.results[:provenance]["earthing_zones"]
    println(rpad(join(z["buses"], ","), 14), z["wires"], "; ", z["tag"])
end
```

## [Australia: multiple earthed neutral](@id systems-australia)

The Australian MEN system earths the neutral at the transformer and again at
every customer installation.

```@example systems
report = summarize(case("au_men_four_wire"))
g = report.results[:provenance]["grounding"]
println("  earthing points: ", g["n_grounding_points"])
```

The earths are finite resistances (10 Ω at the transformer, 30 Ω at each
installation), modeled as `shunt` objects on the neutral terminal. The profiler
keeps them finite: a 30 Ω electrode is not treated as a perfect ground. For
Australian rural networks, the [SWER case study](tutorial_swer.md) covers the
single-wire earth-return system; the profiler tags its backbone as a `swer`
zone because the spans carry one conductor and no neutral.

## [North America: multi-grounded neutral and split-phase service](@id systems-north-america)

A 12.47 kV four-wire primary with the neutral grounded along the line, a
single-phase lateral, and a pole transformer with a center-tapped 120/240 V
secondary.

```@example systems
report = summarize(case("na_mgn_split_phase"))
nothing # hide
```

Read the zones. The single-phase lateral bus `lat` does not appear as its own
zone: it is joined to the three-phase primary by a line, so it belongs to the
primary's zone. Only the service bus `svc`, behind the pole transformer, is a
separate zone, and it is tagged **split-phase**:

```@example systems
split = only(f for f in report.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
println(split.message)
```

The two legs are 180° apart, so the level of `svc` is 120 V per leg and a load
between the legs sees 240 V. Phase-balance checks that assume 120° separation
skip a split-phase zone.

## [North America: high-leg delta from an open-wye/open-delta bank](@id systems-high-leg)

Small commercial services often take three-phase power from two single-phase
transformers: a center-tapped *lighting* unit for the 120 V loads and a *power*
unit that closes an open delta. The third phase conductor, the *high leg*, sits
at 208 V to neutral.

```@example systems
net = case("na_high_leg_open_delta")
report = summarize(net)
nothing # hide
```

No errors and no warnings. Three things had to be understood for that:

```@example systems
conn = report.results[:connectivity]
vl = report.results[:voltage_levels]
println("bank            : ", conn["transformer_banks"][1]["units"])
println("radial          : ", conn["is_radial"])
println("mixed-level bus : ", vl["mixed_phase_to_neutral_buses"])
split = only(f for f in report.findings if f.code == "I.PROV.SPLIT_PHASE_ZONE")
println("legs            : ", split.detail["legs"], ", high leg: ", split.detail["high_leg"])
```

- The two units join the same two buses on different conductors. They are one
  **bank**: one branch of the network graph, not a loop.
- Together they supply all three phase conductors, although neither does alone.
- The bus has no single nominal voltage to neutral. Its level is reported as
  the leg voltage, and it is listed as a mixed-level bus.

The power flow agrees. Legs `a` and `b` solve at about 120 V and the high leg
`c` at about √3 × 120 ≈ 208 V; the small shortfall is the voltage drop across
the transformer impedances under load:

```@example systems
using JuMP, Ipopt

result = redirect_stdout(devnull) do
    solve_pf(net)
end
for t in ("a", "b", "c")
    v = result["bus"]["svc"][t]
    println(t, ": ", round(hypot(v["vr"], v["vi"]), digits = 1), " V to neutral")
end
```

## [Japan: three-wire primary and V-connection](@id systems-japan)

The Japanese 6.6 kV primary is three-wire, with no neutral conductor. A pole
transformer connected between two phases feeds a 100/200 V single-phase
three-wire service, and a V-connected pair feeds three-phase 200 V with 100 V
lighting legs taken from the center-tapped unit.

```@example systems
net = case("jp_three_wire_v_connection")
report = summarize(net)
nothing # hide
```

The home is an ordinary split-phase zone at 100 V per leg. The shop is the same
structure as the North American high-leg service, at Japanese voltages:

```@example systems
vl = report.results[:voltage_levels]
println("mixed-level bus: ", vl["mixed_phase_to_neutral_buses"],
        ", power unit: ", vl["high_leg_units"])
result = redirect_stdout(devnull) do
    solve_pf(net)
end
for t in ("a", "b", "c")
    v = result["bus"]["shop"][t]
    println(t, ": ", round(hypot(v["vr"], v["vi"]), digits = 1), " V to neutral")
end
```

About 100 V on the two legs and about 173 V on the third conductor, again
slightly below nominal under load.

!!! note "What the source pins"
    A `voltage_source` fixes the voltage of each of its terminals to the
    reference. The 6.6 kV primary in this fixture is therefore referenced at
    the source, like a system earthed at the substation. A primary that is
    *unearthed everywhere* has to be modeled behind an isolating transformer,
    as in the next section.

## [An unearthed delta island](@id systems-delta-island)

Industrial IT systems, and unearthed delta secondaries generally, have no
intentional connection to earth. Two fixtures differ in one thing only: whether
the cable's capacitance to earth is modeled.

```@example systems
bare = analyze(case("it_delta_island_unreferenced"))
cap = analyze(case("it_delta_island_capacitive"))
println("no capacitance modeled : ", [f.code for f in errors(bare)])
println("capacitance modeled    : ", [f.code for f in errors(cap)])
```

Without any path to earth, the voltages of the island to earth are not
defined: line-to-line voltages are, but the whole triangle can sit anywhere.
`E.INT.NO_VOLTAGE_REFERENCE` reports exactly that, and it is a true error for
a solver, which needs a unique answer. Cable capacitance is the real path to
earth in such a system, and once it is in the data the island is referenced.
The explanation page [works through both](grounding_findings.md#An-island-with-no-reference).

## [What is recognized, and what is not](@id systems-coverage)

| Practice | What the profiler reports |
|---|---|
| Three-phase four-wire, neutral earthed once or many times | `three_phase` zones; earthing points counted; a neutral section with no earth is `E.PROV.FLOATING_NEUTRAL` |
| Neutral earthed through a resistor or arc-suppression coil at the transformer (`r_neutral_*`, `x_neutral_*`) | a finite voltage reference; no error |
| Single-phase lateral on a three-phase feeder | part of the feeder's zone |
| Center-tapped 120/240 V or 100/200 V service | `split_phase` zone, `I.PROV.SPLIT_PHASE_ZONE` |
| Banks of single-phase units: wye bank, open-wye/open-delta, V-connection | one branch (`transformer_banks`), supplying the union of the legs |
| High-leg (four-wire) delta | `split_phase` zone with a `high_leg`; bus listed in `mixed_phase_to_neutral_buses` |
| Isolated SWER | `swer` zone, `I.PROV.SWER_ZONE`, when a span carries one conductor and no neutral |
| Two-wire single-phase section behind a transformer | `single_phase` zone |
| Unearthed delta or IT island | referenced only through modeled shunt admittance; otherwise `E.INT.NO_VOLTAGE_REFERENCE` |
| AC sections joined by a DC link | one connected network (`dc_links`) |

Not recognized, and reported as such rather than guessed:

- **TN-S, TN-C-S, TT and IT** as protective-earthing systems. The model has no
  protective-earth conductor, so the earthing report describes the represented
  paths to earth and marks the system type indeterminate.
- **Non-isolated SWER** (a single-wire lateral tapped directly off a
  three-phase feeder). It shares the feeder's zone and is not tagged.
- **Corner-grounded delta.** It can be written by perfectly grounding one phase
  terminal, which gives the island its reference, but no fixture or check is
  specific to it; read the zone and level output critically for such a case.
- **Two-phase loads as one WYE object.** The specification fixes a WYE load at
  four terminals; write two `SINGLE_PHASE` loads instead.
- **Five-wire systems** with a separate protective earth conductor. Device
  indexing is reported as unassessed for those buses.

If your network uses a practice that is not in either list, run it and read
the zones and levels first: they show what the profiler understood.
