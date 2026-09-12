# [Simplifying a network before optimisation](@id tutorial-simplify)

!!! note "External dataset"
    This tutorial uses CC BY-NC-SA data kept in BMOPFDraftData. Set
    `ENV["BMOPF_RESTRICTED_DATA"] = "/path/to/BMOPFDraftData/test/data"`
    before running it. The dataset retains its upstream licence and is not
    bundled with BMOPFTools. These dataset examples are shown as code and
    are not executed by the package documentation build.

*Reduce a network only within the supported circuit and constraint domain.*

GIS-derived models often contain degree-2 junction buses, explicit switches,
and unloaded stubs. Some can be eliminated exactly; others carry grounding,
shunts, limits, or future modelling meaning. The package records reductions and
refusals in `_simplification_log`. Series merging permits same-linecode π
approximations by default with warnings; intermediate bus constraints require
separate permission to remove. Other topology passes can
still be lossy, including pruning shunt-bearing stubs and collapsing rated
switches; read their warnings and disable them when those effects matter.

This page runs the passes on a feeder and compares a solved operating point.
That comparison is useful evidence, not a guarantee of feasible-set preservation.

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

`LV10_223bus` is one of the Australian LV feeders stored in the external BMOPFDraftData repository:
a 223-bus four-wire residential network whose data came from GIS, so it has
exactly the artefacts described above — including ten closed switches modelled
as explicit switch elements.

```julia
using BMOPFTools

const DATA = joinpath(dirname(pathof(BMOPFTools)), "..", "test", "data")
net = from_dss(joinpath(ENV["BMOPF_RESTRICTED_DATA"], "LV", "LV10_223bus", "Master.dss"))

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

```julia
n1 = collapse_closed_switches(net)
inventory(n1)
```

All ten switches are gone and the bus count dropped by ten — one absorbed bus
per collapsed switch. The log records exactly which bus survived each merge:

```julia
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

```julia
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

```julia
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
provided the chain has no intermediate voltage, segment apparent-power, or
segment angle limits (intermediate bus bounds can be explicitly dropped). The merged line gets the summed length
and the tighter effective current rating:

```julia
n4 = merge_series_lines(n3)

merged = sort([(id, l["_merged_from"], round(l["length"], digits=1))
               for (id, l) in n4["line"] if haskey(l, "_merged_from")];
              by = last, rev = true)
println(inventory(n4), "\n")
if isempty(merged)
    println("No eligible corridors; inspect the refusal codes below.")
else
    println("longest merged corridor: line ", merged[1][1], " absorbed ",
            merged[1][2], ", combined length ", merged[1][3], " m")
end
```

The default `series_merge_policy=:allow_approximate` supports GIS cleanup by
combining same-linecode π sections and summing their lengths. This redistributes
interior shunts and changes terminal equations. Each such merge emits
`SERIES_MERGE_APPROXIMATE`, recording both source lines, the removed bus, and the
unquantified approximation risk. The tighter effective current rating is retained,
but that does not establish equivalence of the original segment current limits.

Use `merge_series_lines(net; series_merge_policy=:exact)` to refuse these merges,
or `:off` to disable series merging. Both keywords below also work with
`simplify_network`. Intermediate bus bounds block merging unless explicitly
permitted with `allow_drop_bus_constraints=true` in approximate mode; their values
are recorded in the warning. Segment apparent-power and angle limits still block
merging, as do grounding, attached devices, and incompatible terminal maps.
Inline shunt overrides are outside the supported approximation domain.

A before/after power-flow comparison can measure the effect at the selected
operating point; no error magnitude or global feasibility preservation is claimed
by the merge itself. The log explains each candidate:

```julia
codes = [e["code"] for e in n4["_simplification_log"]]
foreach(c -> println(rpad(c, 18), count(==(c), codes), "×"), unique(codes))
```

Every outcome is accounted for — the log is the provenance record of the whole
transformation, suitable for serialising alongside the case.

!!! note "Current-rating projection for a series-only chain"
    One current flows through both segments of a series corridor, so the binding
    thermal limit is the **tighter** of the two. The OPF reads a line's limit
    from its own `i_max` if present, otherwise from its linecode
    ([precedence: line override → linecode → unconstrained](opf.md#Current-vs-apparent-power-limits)).
    An `s_max` apparent-power limit depends on local voltage: taking its minimum
    is not a general preservation rule. Such limits block merging until an
    explicit intermediate-voltage recovery representation is available.
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

```julia
simp = simplify_network(net)
inventory(simp)
```

The inventory above reports the reductions actually supported for this import.

## 4. The payoff: verify, don't trust

If simplification preserves fidelity, a power flow on both networks must agree
at every bus that survives in both. Let's check that instead of asserting it:

```julia
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

Inspect the measured voltage and loss differences above together with the
transformation warnings. Agreement at this operating point does not establish
preservation of every constraint or operating point. Timing is reported for
this machine and dependency stack:

```julia
t_orig = @elapsed solve_pf(net;  optimizer = OPT, per_unit = true)
t_simp = @elapsed solve_pf(simp; optimizer = OPT, per_unit = true)
println("re-solve: original ", round(t_orig, digits = 3), " s, simplified ",
        round(t_simp, digits = 3), " s  (this machine, at docs-build time)")
```

Repeated timing can vary across hardware, operating systems, and solver
versions. The inventory reduction is structural; measure its benefit for the
study and retain the applicable preservation checks.

## 5. When *not* to simplify

Even an exact circuit reduction has modelling consequences. Reduction is
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
