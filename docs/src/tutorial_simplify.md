# [Simplifying a network before optimisation](@id tutorial-simplify)

*Fewer buses, same physics — and you can verify that claim rather than assume it.*

Feeders imported from GIS-derived OpenDSS models carry **modelling artefacts**:
degree-2 junction buses left behind by geometry points, closed switches modelled
as separate elements, stub lines that end at a bus with nothing on it. None of
these change the physics, but every one of them adds voltage and current
variables to the OPF. Simplification strips them out as a *fidelity-preserving*
transformation — the solution on the simplified network matches the original at
every surviving bus. That guarantee is not free: it holds because each pass is
**gated** to refuse any reduction that would move the physics (a grounded
intermediate bus, a stub that is really a shunt-to-earth). This page runs each
pass on a real feeder, shows those gates firing, then closes the loop by solving
both networks and comparing.

!!! note "Simplification is one-way and lossy — keep the source case"
    Merging a corridor deletes the intermediate bus and each segment's
    per-section impedance; pruning a stub deletes its bus and line. You cannot
    reconstruct them from the result, and you cannot later add a grounding
    electrode, load, or tap at a bus that no longer exists. The reduction is
    recorded only in the package-level `_simplification_log`/`_merged_from`,
    **not** in the versioned data-model schema — a downstream tool reading a
    simplified case has no schema-level signal that it was reduced. Treat the
    simplified network as a *solve-time compile target* and keep the original as
    the exchanged benchmark artifact. See
    [Object identity & semantic projection](@ref object-identity) for why the
    canonical model keeps the fuller representation.

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

!!! warning "A rated switch loses its flow limit when collapsed"
    A *closed* switch is flow-limited in the OPF exactly like a line when it
    carries an `i_max`. Collapsing it fuses its two buses into one node, so the
    cut its rating constrained no longer exists — unlike a series line merge,
    there is **no surviving branch to project the limit onto**, and it is simply
    dropped (`SWITCH_LIMIT_DROPPED`, warning). If that rating could bind, the
    reduction relaxes the feasible set. Keep `closed_switches = false` to retain
    a rated switch as an explicit zero-impedance branch. (Most `from_dss`
    switches arrive unrated, so this affects only switches you or the
    adjacent-bounds pass gave an `i_max`.)

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

!!! warning "A stub with shunt admittance is *not* electrically nothing"
    "Serves nothing" means no load, generator, shunt, source, or transformer at
    the leaf — it does **not** mean the line is electrically inert. A line with
    non-zero shunt admittance (line charging, `G_*`/`B_*` on the line or its
    linecode) is a shunt-to-earth: its near-end half-π injects current into the
    surviving bus regardless of what sits at the far end. Removing it drops that
    injection from the nodal balance, so **the feasible set can move** — a
    negligible effect on LV overhead, but material for a cable with real
    charging. `remove_dangling_lines` still prunes such a stub (this is a
    topology pass), but emits `SHUNT_DROPPED` (warning) naming the surviving bus,
    so the loss of the shunt is on the record rather than silent. If preserving
    the shunt matters for your study, keep `dangling_lines = false`.

**[`merge_series_lines`](@ref)** fuses two lines meeting at a pass-through bus
(exactly two line connections, nothing else) **when their linecodes match** —
the merged line simply gets the summed length and a correctly projected thermal
rating (see below):

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
meaningful), and so does a **grounded** intermediate bus — a modelled ground
(`perfectly_grounded_terminals`, e.g. a multi-grounded neutral point) fixes
terminal voltages, so deleting the bus would silently drop it. That case logs
`GROUNDED_BUS` (warning) and leaves the corridor intact. The log says why each
candidate was or wasn't merged:

```@example simp
codes = [e["code"] for e in n4["_simplification_log"]]
foreach(c -> println(rpad(c, 18), count(==(c), codes), "×"), unique(codes))
```

Every outcome is accounted for — the log is the provenance record of the whole
transformation, suitable for serialising alongside the case.

!!! note "How the merged rating is projected — and why it stays optimal"
    One current flows through both segments of a series corridor, so the binding
    thermal limit is the **tighter** of the two. The OPF reads a line's limit
    from its own `i_max` if present, otherwise from its linecode
    ([precedence: line override → linecode → unconstrained](opf.md#Current-vs-apparent-power-limits)).
    A line may also carry an `s_max` (apparent-power) limit, now enforced
    natively with the same precedence; the merge below applies the identical
    element-wise-minimum rule to it. Current is the preferred rating for a
    corridor (see [current vs. apparent-power limits](opf.md#Current-vs-apparent-power-limits)).
    The merge therefore compares each segment's
    *effective* limit (override **or** linecode) and keeps the element-wise
    minimum — not merely the minimum of the line-level overrides. That
    distinction matters: if one segment relied on the linecode (say 100 A) while
    the other carried a *looser* override (150 A), taking the smaller override
    would pin 150 A on the merged line, beat the linecode, and silently relax the
    corridor. Because both merged segments share a linecode, the common case
    reduces to the identical linecode rating, and no explicit override is pinned
    when neither segment had one.

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

Fidelity-preserving does not mean free of consequences. The reduction is
**one-way and lossy**: deleted buses and per-segment data cannot be recovered
from the output, and the reduction lives only in the `_simplification_log`, not
in the exchanged data-model schema (see
[Versioning & the data model](dev/versioning.md)). Concretely:

- **The reduced network is a compile target, not the case of record.** For a
  benchmark you exchange, distribute the *original*; simplify at solve time (as
  [`fix_case`](@ref) already does as one pass). A recipient who receives only the
  simplified network cannot reintroduce detail you compiled away, and has no
  schema-level flag that it was reduced.
- **Bus ids disappear.** Absorbed and pruned buses have no entry in the result
  dict — key your post-processing to the simplified network, or use the
  `_simplification_log` (and `_merged_from` on lines) to map old ids to
  survivors.
- **Intermediate buses are gone — including for grounding and new attachments.**
  You cannot add a grounding electrode, load, PV system, or tap at a bus a merge
  deleted. Do placement *before* simplifying (run [`add_ibrs`](@ref) or similar
  first), or keep `series_lines = false` / `dangling_lines = false`. A modelled
  ground *already present* on an intermediate bus blocks its merge
  (`GROUNDED_BUS`) rather than being dropped.
- **Per-section detail is gone.** A merged corridor reports one current and one
  loss figure; if you need per-segment currents (e.g. for protection studies),
  keep `series_lines = false`.
- **Shunt-bearing stubs shift the feasible set.** Pruning a dangling line with
  real charging removes its shunt-to-earth (flagged `SHUNT_DROPPED`); keep
  `dangling_lines = false` where cable charging is material.
- **Switch states become topology, and rated switches lose their limit.**
  Collapsing closed switches bakes today's configuration into the graph. If
  switching is a decision variable in your study, disable `closed_switches` (and
  `open_switches`). A closed switch carrying an `i_max` is flow-limited in the
  OPF; collapsing merges its buses into one node with nowhere to project the
  rating, so the limit is dropped (`SWITCH_LIMIT_DROPPED`) — keep
  `closed_switches = false` where that rating can bind.

For the passes that go further than topology — replacing low-impedance lines
with switches, dropping disconnected components — see
[`fix_case`](@ref) in [Case fixing & augmentation](augmentation.md#fix).
