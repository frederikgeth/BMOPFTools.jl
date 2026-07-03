# [Simplifying a network before optimisation](@id tutorial-simplify)

*Fewer buses, same physics — and you can verify that claim rather than assume it.*

Feeders imported from GIS-derived OpenDSS models carry **modelling artefacts**:
degree-2 junction buses left behind by geometry points, closed switches modelled
as separate elements, stub lines that end at a bus with nothing on it. None of
these change the physics, but every one of them adds voltage and current
variables to the OPF. Simplification strips them out as a *fidelity-preserving*
transformation — the solution on the simplified network must match the original
at every surviving bus. This page runs each simplification pass on a real
feeder, then closes the loop by solving both networks and comparing.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`
installed — see the [end-to-end tutorial](tutorial_end_to_end.md) first. If you
use [`fix_case`](@ref), note that its second pass already calls
[`simplify_network`](@ref) for you (see
[Case fixing](augmentation.md#fix)); this page is about running — and
verifying — the passes yourself.*

## 1. A feeder with artefacts

`LV10_223bus` is one of the Australian LV feeders shipped with the test suite:
a 223-bus four-wire residential network whose data came from GIS, so it has
exactly the artefacts described above — including ten closed switches modelled
as explicit switch elements.

```@example simp
using BMOPFTools

const DATA = joinpath(dirname(pathof(BMOPFTools)), "..", "test", "data")
net = from_dss(joinpath(DATA, "LV", "LV10_223bus", "Master.dss"))

inventory(n) = (buses    = length(n["bus"]),
                lines    = length(n["line"]),
                switches = length(get(n, "switch", Dict())),
                loads    = length(n["load"]))
inventory(net)
```

(The `from_dss` warning above lists cosmetic OpenDSS fields with no BMOPF
equivalent — nothing electrical; see the
[end-to-end tutorial](tutorial_end_to_end.md) for how to read it.)

224 buses and 212 lines, but only 94 loads: a third of the buses exist for
purely geometric reasons. Each pass below returns a **deep copy** — the input
network is never mutated — and appends its outcomes to
`net["_simplification_log"]`.

## 2. The four passes, one at a time

**[`collapse_closed_switches`](@ref)** merges the two buses joined by each
closed (zero-impedance) switch; the `bus_from` bus survives and everything on
the absorbed bus is redirected to it:

```@example simp
n1 = collapse_closed_switches(net)
inventory(n1)
```

All ten switches are gone and the bus count dropped by ten — one absorbed bus
per collapsed switch. The log records exactly which bus survived each merge:

```@example simp
println(n1["_simplification_log"][1]["message"])
```

**[`remove_open_switches`](@ref)** deletes switch elements with
`open_switch = true` — an open switch carries no current, so only the stub it
fed (cleaned up by the next pass) remains. This feeder has none, so the pass is
a no-op here:

```@example simp
n2 = remove_open_switches(n1)
inventory(n2)
```

!!! warning "Open-switch status may be lost at import"
    `from_dss` does not apply OpenDSS `open` *commands* — a switch opened that
    way arrives as **closed**, and `collapse_closed_switches` would then fuse
    buses that are actually electrically separate. If your source model opens
    switches by command, set `open_switch = true` on those switch dicts before
    simplifying.

**[`remove_dangling_lines`](@ref)** prunes stub lines whose far-end bus has one
line and no other element — no load, generator, shunt, transformer, or source.
It iterates to convergence, so a dangling *chain* disappears entirely:

```@example simp
n3 = remove_dangling_lines(n2)
inventory(n3)
```

The largest single reduction: 57 lines and their leaf buses served nothing.
These are typically service drops to premises that have no load attached in
this dataset snapshot.

**[`merge_series_lines`](@ref)** fuses two lines meeting at a pass-through bus
(exactly two line connections, nothing else) **when their linecodes match** —
the merged line simply gets the summed length, and the tighter of the two
segments' `i_max`/`s_max` ratings so no thermal constraint is silently relaxed:

```@example simp
n4 = merge_series_lines(n3)

merged = sort([(id, l["_merged_from"], round(l["length"], digits=1))
               for (id, l) in n4["line"] if haskey(l, "_merged_from")];
              by = last, rev = true)
println(inventory(n4), "\n")
println("longest merged corridor: line ", merged[1][1], " absorbed ",
        merged[1][2], ", combined length ", merged[1][3], " m")
```

Only some junctions merge: a differing linecode blocks the fuse (the series
impedance per metre changes there, so the intermediate bus is physically
meaningful). The log says why each candidate was or wasn't merged:

```@example simp
codes = [e["code"] for e in n4["_simplification_log"]]
foreach(c -> println(rpad(c, 18), count(==(c), codes), "×"), unique(codes))
```

Every outcome is accounted for — the log is the provenance record of the whole
transformation, suitable for serialising alongside the case.

## 3. One call

[`simplify_network`](@ref) composes the four passes in the order above; each
can be switched off by keyword (e.g. `closed_switches = false` if you intend to
optimise switch states later):

```@example simp
simp = simplify_network(net)
inventory(simp)
```

Same result as the manual chain: a third of the buses — and their four
terminal-voltage variables each — are gone.

## 4. The payoff: verify, don't trust

If simplification preserves fidelity, a power flow on both networks must agree
at every bus that survives in both. Let's check that instead of asserting it:

```@example simp
using JuMP, Ipopt
OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

r_orig = solve_pf(net;  optimizer = OPT, per_unit = true)   # pays JIT compilation
r_simp = solve_pf(simp; optimizer = OPT, per_unit = true)

shared = intersect(keys(r_orig["bus"]), keys(r_simp["bus"]))
dv = maximum(abs(v["vm"] - r_orig["bus"][b][t]["vm"])
             for b in shared for (t, v) in r_simp["bus"][b]
             if haskey(r_orig["bus"][b], t))

println("termination : ", r_orig["termination_status"], " / ",
        r_simp["termination_status"])
println("shared buses: ", length(shared), " of ", length(r_orig["bus"]))
println("max |ΔV|    : ", round(dv * 1e6, digits = 1), " μV")
println("losses      : ", round(r_orig["losses"]["p_loss"] / 1e3, digits = 3),
        " kW vs ", round(r_simp["losses"]["p_loss"] / 1e3, digits = 3), " kW")
```

The headline number is the voltage agreement: tens of **micro**volts on a 230 V
feeder — solver tolerance, not model error. Total losses match to the same
precision, confirming the merged corridors carry the same impedance as the
chains they replaced. Solve time is the bonus, not the headline:

```@example simp
t_orig = @elapsed solve_pf(net;  optimizer = OPT, per_unit = true)
t_simp = @elapsed solve_pf(simp; optimizer = OPT, per_unit = true)
println("re-solve: original ", round(t_orig, digits = 3), " s, simplified ",
        round(t_simp, digits = 3), " s  (this machine, at docs-build time)")
```

On a determined power flow of this size the gap is modest — sub-100 ms either
way, well inside run-to-run noise. The structural reduction is what compounds:
a third fewer buses means a third fewer voltage variables **and** their bound
constraints in the *OPF*, and the saving multiplies in Monte-Carlo or
time-series studies where the same network is solved thousands of times.

## 5. When *not* to simplify

Fidelity-preserving does not mean free of consequences:

- **Bus ids disappear.** Absorbed and pruned buses have no entry in the result
  dict — key your post-processing to the simplified network, or use the
  `_simplification_log` (and `_merged_from` on lines) to map old ids to
  survivors.
- **Per-section detail is gone.** A merged corridor reports one current and one
  loss figure; if you need per-segment currents (e.g. for protection studies),
  keep `series_lines = false`.
- **Switch states become topology.** Collapsing closed switches bakes today's
  configuration into the graph. If switching is a decision variable in your
  study, disable `closed_switches` (and `open_switches`).
- **Dangling stubs may be tomorrow's loads.** A pruned service drop cannot
  receive the load or PV system you planned to place there — run
  [`add_ibrs`](@ref) or similar placement *before* simplifying, or keep
  `dangling_lines = false`.

For the passes that go further than topology — replacing low-impedance lines
with switches, dropping disconnected components — see
[`fix_case`](@ref) in [Case fixing & augmentation](augmentation.md#fix).
