# [Porting an OpenDSS feeder: what the profiler tells you](@id opendss-port)

*Import a small North American style OpenDSS deck and read the report in three
layers: what the import could not carry, what the profiler recognized, and what
looks like a tool default rather than data.*

An OpenDSS model and a BMOPF case do not describe a network the same way.
OpenDSS has an implicit earth node, default values for almost every field, and
controls; BMOPF has explicit terminals and only what the data states. Porting
is therefore a translation, and the report is where the translation shows its
working. This page is executed when the documentation is built, on a deck that
ships with the package.

!!! note "Prerequisites"
    Only `BMOPFTools`. For the conversion rules themselves, see the
    [conversion guide](conversion.md).

## 1. The deck

A 12.47 kV source feeds two transformers: a three-phase delta-wye unit with a
416 V secondary, and a single-phase center-tapped unit with a 120/240 V
secondary, the North American service arrangement.

```@example port
using BMOPFTools

deck = joinpath(pkgdir(BMOPFTools), "test", "data", "pf_comparison",
                "pf_combined_3ph_split.dss")
for line in readlines(deck)
    startswith(line, "New ") && println(first(line, 100))
end
```

```@example port
net = from_dss(deck)
println(sort(collect(keys(net["bus"]))))
report = analyze(net)
println(length(errors(report)), " errors, ", length(warnings(report)), " warnings, ",
        length(infos(report)), " infos")
```

Note the extra bus. The importer represents the OpenDSS source as an ideal
source behind its impedance, which needs a bus of its own
(`_pio_vsource_source_emf`).

## 2. Layer one: what the import could not carry

Findings whose code does not start with `E.`, `W.` or `I.` come from the
importer ([PowerIO](https://powerio.dev)), not from this package. Their first
part names the stage that raised them.

```@example port
ours(f) = first(f.code, 2) in ("E.", "W.", "I.")
for f in report.findings
    ours(f) && continue
    println(rpad(f.code, 34), first(f.message, 95))
end
```

Each line is a difference between the two formats, not an error in your data:

- `EMIT.BMOPF.FIELD_DROPPED` — a field with no place in the target, such as the
  `kv` voltage base or the source short-circuit level.
- `EMIT.BMOPF.VALUE_SUBSTITUTED` — OpenDSS loads switch model outside a voltage
  band (`Vminpu`/`Vmaxpu`); BMOPF has one load law, so the nominal law is kept.
- `EMIT.BMOPF.RETAINED_SOURCE_ONLY` — data kept under `extras` because the
  target subtype has no slot for it (here the no-load shunt of the
  center-tapped transformer).

Read this layer once and decide whether anything dropped matters for your
study. If the load model switch matters, for example, that is a modeling
decision to make now, not something the solver will tell you later.

## 3. Layer two: what the profiler recognized

```@example port
conn = report.results[:connectivity]
for z in sort(conn["zones"], by = z -> z["label"])
    println(rpad(z["label"], 26), rpad(z["topology"], 13), z["phases"])
end
levels = report.results[:voltage_levels]["bus_voltage_map"]
println(Dict(b => round(Int, v) for (b, v) in levels))
```

Three zones: the 12.47 kV source side, the three-phase 416 V secondary
(240 V per phase), and the split-phase service at 120 V per leg. The
split-phase zone is announced explicitly:

```@example port
for f in report.findings
    f.code == "I.PROV.SPLIT_PHASE_ZONE" && println(f.message)
end
```

OpenDSS writes the earth as node `0` and the neutral as node `4`. After import
they are separate named terminals, and you can see which is which:

```@example port
for id in ("src", "lv3", "lvsp")
    b = net["bus"][id]
    println(rpad(id, 6), b["terminal_names"], "  grounded: ",
            get(b, "perfectly_grounded_terminals", String[]))
end
```

`n` is the neutral (OpenDSS node 4). On the source bus, `n_ref` is what OpenDSS
node 0 became where a device was connected to it: a perfectly grounded
terminal, the earth reference itself and not a conductor. The grounding
reactors of the deck (`Reactor.grnd_*`) became finite shunts from each neutral
to earth, so every neutral is earthed through 1 mΩ, as the deck says:

```@example port
g = report.results[:provenance]["grounding"]
println("buses with a neutral: ", g["n_buses_with_neutral"],
        ", earthing points: ", g["n_grounding_points"], ", floating: ", g["n_floating"])
for (id, s) in sort(collect(net["shunt"]), by = first)
    length(s["terminal_map"]) == 1 &&
        println(rpad(id, 12), s["bus"], ".", s["terminal_map"][1], "  ", round(1 / s["G_1_1"], digits = 4), " Ω")
end
```

## 4. Layer three: defaults that look like data

OpenDSS fills in a value for every field you leave out. After conversion those
values look exactly like data. The profiler fingerprints the common ones.

```@example port
for f in report.findings
    startswith(f.code, "I.PROV.DSS_DEFAULT") && println(f.code, "\n    ", f.message)
end
```

`I.PROV.DSS_DEFAULT_KV` says two components sit exactly at 12.47 kV, an OpenDSS
default. Here that is **correct**: this is a 12.47 kV feeder, a common North
American primary voltage. The finding is a prompt to check, and the check takes
a second. On a European or Australian case the same finding would be a strong
sign that a `kv` was never set.

If a whole project uses 12.47 kV, say so once in the
[thresholds](howto_thresholds.md) rather than re-reading the finding on every
case:

```@example port
cfg = load_config()
cfg["provenance"]["dss_defaults"]["kv_v"] = 1.0        # no component is at 1 V
quiet = analyze(net; config = cfg)
println(any(f -> f.code == "I.PROV.DSS_DEFAULT_KV", quiet.findings) ? "still raised" : "not raised")
```

## 5. What is left to do

```@example port
for f in warnings(report)
    ours(f) && println(f.code, "\n    ", first(f.message, 150))
end
```

The line that models the source impedance has no current rating, which is
expected for a Thevenin impedance. Real lines without a rating would be a gap
to fill before an OPF, since no thermal limit is enforced on them. The case
also has no voltage limits and no priced generation yet:

```@example port
for f in infos(report)
    f.code in ("I.PRE.NO_VOLT_BOUNDS", "I.BENCH.AUGMENTATION") && println(first(f.message, 140))
end
```

Those are the job of [case augmentation](augmentation.md), not of the import.

## What to take away

- **Three layers.** Importer findings (what was lost in translation), the
  profiler's reading of the network (zones, levels, grounding), and default
  fingerprints (values that may never have been set).
- **Check the zones and levels first.** If they match your picture of the
  feeder, the translation understood it.
- **A default fingerprint is a question.** It is right as often as it is wrong;
  it costs a look.
- **Controls do not survive.** Regulator and capacitor controls have no
  counterpart: a regulator arrives as a fixed-tap transformer and
  `W.PROV.REGULATOR_PATTERN` reminds you.

Next: [System types and regional practice](tutorial_system_types.md) for the
split-phase and bank arrangements, and the
[utility-data end-to-end tutorial](tutorial_end_to_end.md) for a full feeder.
