# [Simplifying a network before optimization](@id tutorial-simplify)

!!! note "External dataset"
    This tutorial uses CC BY-NC-SA data kept in BMOPFDraftData. Set
    `ENV["BMOPF_RESTRICTED_DATA"] = "/path/to/BMOPFDraftData/test/data"`
    before running it. The dataset retains its upstream license and is not
    bundled with BMOPFTools. These dataset examples are shown as code and
    are not executed by the package documentation build.

*Remove the buses and branches that exist only for geometric reasons, and
check what that cost.*

!!! warning "Approximate, one-way, and lossy: keep the source case"
    Several passes approximate by default: series merging redistributes the
    interior shunts of merged π sections, pruning a stub drops any shunt it
    carried, and collapsing a rated switch drops its flow limit. Each such
    change is logged, but no error bound or preservation of the feasible set
    is claimed. A solved comparison, as in §4, is evidence at one operating
    point, not a guarantee.

    The reduction cannot be undone. Merged and pruned buses, and each
    segment's impedance, are gone from the result, so you cannot later add a
    grounding electrode, load, or tap there. The reduction is recorded only in
    the package-level `_simplification_log` and `_merged_from`, **not** in the
    versioned data-model schema, so a downstream tool has no schema-level
    signal that a case was reduced. Treat the simplified network as a
    solve-time compile target and keep the original as the exchanged case; see
    [Object identity & semantic projection](@ref object-identity).

!!! tip "Which reduction do I need?"
    `simplify_network` removes topology artifacts but keeps every loaded bus.
    To remove loaded buses with a voltage-error guarantee, use Opti-KRON; to
    turn a four-wire model into a three-wire one, use
    [`kron_reduce_neutrals`](@ref). [Network reduction](@ref network-reduction)
    compares all three on real feeders.

GIS-derived models often contain degree-2 junction buses, explicit switches,
and unloaded stubs. Some can be eliminated exactly; others carry grounding,
shunts, limits, or future modeling meaning. Every pass records its reductions
and refusals in `_simplification_log`. This page runs the passes one at a time
on a feeder, then all at once, and compares a solved operating point.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`
installed (see [Installation](installation.md)), and the external dataset
noted above; the [first-case walkthrough](first_case.md) is a bundled
introduction to solving and verification. [`fix_case`](@ref) already calls
[`simplify_network`](@ref) as one of its passes (see
[Case fixing](@ref fix)); this page is about running and verifying
the passes yourself.*

## [1. A feeder with artifacts](@id 1.-A-feeder-with-artefacts)

`LV10_223bus` is one of the Australian LV feeders stored in the external BMOPFDraftData repository:
a 223-bus four-wire residential network whose data came from GIS, so it has
the artifacts described above, including ten closed switches written
in OpenDSS as `switch=y` lines.

```julia
using BMOPFTools

net = from_dss(joinpath(ENV["BMOPF_RESTRICTED_DATA"], "LV", "LV10_223bus", "Master.dss"))

inventory(n) = (buses    = length(n["bus"]),
                lines    = length(n["line"]),
                switches = length(get(n, "switch", Dict())),
                loads    = length(n["load"]))
inventory(net)
```

`from_dss` warns about cosmetic OpenDSS fields with no BMOPF equivalent;
nothing electrical is lost (the [end-to-end tutorial](tutorial_end_to_end.md)
shows how to read the warning).

225 buses (including the source's internal bus) and 223 lines, but only 94
loads: more than half of the buses exist for purely geometric reasons. The ten
OpenDSS switches arrive as ordinary `line` elements (`switch_329_closed`, …)
with their 1 m linecode impedance, so the import has no `switch` elements.
Each pass below returns a **deep copy**, leaving the input network unchanged,
and appends its outcomes to `net["_simplification_log"]`.

## [2. The four passes, one at a time](@id simplify-passes)

**[`collapse_closed_switches`](@ref)** merges the two buses joined by each
closed (zero-impedance) switch; the `bus_from` bus survives and everything on
the absorbed bus is redirected to it:

```julia
n1 = collapse_closed_switches(net)
inventory(n1)
```

This import has no `switch` elements, so the pass is a no-op here and the
inventory is unchanged. On a case with closed switch elements, each collapse
absorbs one bus, and the log records which bus survived each merge:

```julia
log1 = get(n1, "_simplification_log", [])
isempty(log1) ? println("no closed switch elements collapsed") :
                println(log1[1]["message"])
```

!!! warning "A rated switch loses its flow limit when collapsed"
    A *closed* switch is flow-limited in the OPF exactly like a line when it
    carries an `i_max`. Collapsing it fuses its two buses into one node, so the
    cut its rating constrained no longer exists — unlike a series line merge,
    there is **no surviving branch to project the limit onto**, and it is simply
    dropped (`SWITCH_LIMIT_DROPPED`, warning). If that rating could bind, the
    reduction relaxes the feasible set. Keep `closed_switches = false` to retain
    a rated switch as an explicit zero-impedance branch, and also when
    switching is a decision in your study. (Most `from_dss` switches arrive
    unrated, so this affects only switches you or the adjacent-bounds pass
    gave an `i_max`.)

**[`remove_open_switches`](@ref)** deletes switch elements with
`open_switch = true`. An open switch carries no current, so only the stub it
fed remains, and the next pass cleans that up. This feeder has none, so the pass is
a no-op here:

```julia
n2 = remove_open_switches(n1)
inventory(n2)
```

!!! warning "Open-switch status may be lost at import"
    `from_dss` does not apply OpenDSS `open` *commands*: a switch opened that
    way arrives as **closed**, and `collapse_closed_switches` would then fuse
    buses that are actually electrically separate. If your source model opens
    switches by command, set `open_switch = true` on those switch dicts before
    simplifying.

**[`remove_dangling_lines`](@ref)** prunes stub lines whose far-end bus has one
line and no other element: no load, generator, shunt, transformer, or source.
It iterates to convergence, so a dangling *chain* disappears entirely:

```julia
n3 = remove_dangling_lines(n2)
inventory(n3)
```

The largest single reduction: 58 lines and their leaf buses served nothing.
These are typically service drops to premises that have no load attached in
this dataset snapshot. Every one of the 58 carries shunt admittance, so each
removal also logs `SHUNT_DROPPED` (see the warning below).

!!! warning "A stub with shunt admittance is *not* electrically nothing"
    "Serves nothing" means no device at the leaf; it does **not** mean the
    line is electrically inert. A line with nonzero shunt admittance (line
    charging, `G_*`/`B_*` on the line or its linecode) is a shunt to earth: its
    near-end half-π injects current into the surviving bus whatever sits at
    the far end. Removing it drops that injection from the nodal balance, so
    **the feasible set can move**: negligibly on LV overhead lines, materially
    on a cable with real charging. `remove_dangling_lines` still prunes such a
    stub but emits `SHUNT_DROPPED` (warning) naming the surviving bus. If
    preserving the shunt matters for your study, keep `dangling_lines = false`.

**[`merge_series_lines`](@ref)** fuses two lines meeting at a pass-through bus
(exactly two line connections, nothing else) **when their linecodes match**
and the chain has no intermediate voltage, segment apparent-power, or segment
angle limits (intermediate bus bounds can be explicitly dropped). The merged
line gets the summed length and the tighter effective current rating:

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

The default `series_merge_policy=:allow_approximate` combines same-linecode π
sections and sums their lengths, which redistributes interior shunts and
changes the terminal equations. Each such merge emits
`SERIES_MERGE_APPROXIMATE`, recording both source lines and the removed bus.
`series_merge_policy=:exact` refuses these merges and `:off` disables series
merging. Intermediate bus bounds block a merge unless
`allow_drop_bus_constraints=true` (approximate mode only), in which case their
values are recorded in the warning. Segment apparent-power and angle limits,
grounding, attached devices, and incompatible terminal maps always block a
merge, and inline shunt overrides are outside the supported approximation
domain. Both keywords also work with `simplify_network`. The log explains each
candidate:

```julia
codes = [e["code"] for e in n4["_simplification_log"]]
foreach(c -> println(rpad(c, 18), count(==(c), codes), "×"), unique(codes))
```

On this import five corridors merge, each logged as `SERIES_MERGE_APPROXIMATE`
next to its `LINES_MERGED` entry, and 21 candidate buses are refused with
`LINECODE_MISMATCH` (their two lines use different linecodes). The log is the
provenance record of the whole transformation; serialize it alongside the
case.

!!! note "Current-rating projection for a series-only chain"
    One current flows through both segments of a series corridor, so the binding
    thermal limit is the **tighter** of the two. The OPF reads a line's limit
    from its own `i_max` if present, otherwise from its linecode
    ([precedence: line override → linecode → unconstrained](opf.md#Current-vs-apparent-power-limits)).
    The merge therefore compares each segment's *effective* limit (override
    **or** linecode) and keeps the element-wise minimum, not merely the
    minimum of the line-level overrides. If one segment relied on the linecode
    (say 100 A) while the other carried a *looser* override (150 A), taking the
    smaller override would pin 150 A on the merged line, beat the linecode, and
    silently relax the corridor. Because both merged segments share a linecode, the common case
    reduces to the identical linecode rating, and no explicit override is pinned
    when neither segment had one. An `s_max` apparent-power limit depends on
    local voltage, so its minimum is not a preservation rule; such limits
    block merging.

## 3. One call

[`simplify_network`](@ref) composes the four passes in the order above; each
can be switched off by keyword (e.g. `closed_switches = false` if you intend to
optimize switch states later):

```julia
simp = simplify_network(net)
inventory(simp)
```

The inventory above reports the reductions actually supported for this import:
162 buses and 160 lines, the same as the four passes run one at a time.

## 4. Verify, don't trust

An exact reduction would leave the power flow unchanged, up to solver
tolerance, at every bus that survives in both networks. This one approximates
(see the warning at the top), so measure the deviation:

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
println("max |ΔV|    : ", round(dv, sigdigits = 3), " V")
println("losses      : ", round(r_orig["losses"]["p_loss"] / 1e3, digits = 3),
        " kW vs ", round(r_simp["losses"]["p_loss"] / 1e3, digits = 3), " kW")
```

Compare the two solutions only when both terminations report a solved point,
and read the differences together with the `SHUNT_DROPPED` and
`SERIES_MERGE_APPROXIMATE` entries in the log. Then time the two solves:

```julia
t_orig = @elapsed solve_pf(net;  optimizer = OPT, per_unit = true)
t_simp = @elapsed solve_pf(simp; optimizer = OPT, per_unit = true)
println("re-solve: original ", round(t_orig, digits = 3), " s, simplified ",
        round(t_simp, digits = 3), " s  (this machine, at docs-build time)")
```

Timings vary across hardware, operating systems, and solver versions, so
measure the benefit for your own study.

## 5. When *not* to simplify

Turn a pass off, or simplify later, when any of these applies:

- **You exchange the case.** Distribute the original and simplify at solve
  time (see the warning at the top).
- **Post-processing uses original bus ids.** Absorbed and pruned buses have no
  entry in the result; map old ids to survivors through `_simplification_log`
  and `_merged_from` on lines.
- **You will add devices or grounding.** Place IBRs, loads or electrodes
  first (for example with [`add_ibrs`](@ref)), or keep `series_lines = false`
  and `dangling_lines = false`. A ground already modeled on an intermediate
  bus blocks its merge (`GROUNDED_BUS`).
- **You need per-segment currents or losses,** for example for protection
  studies: keep `series_lines = false`.
- **Cable charging is material:** keep `dangling_lines = false`
  ([shunt-stub warning](@ref simplify-passes)).
- **Switching is a decision, or a switch rating can bind:** keep
  `closed_switches = false` and `open_switches = false`
  ([switch-limit warning](@ref simplify-passes)).

For the passes that go further than topology, such as replacing low-impedance
lines with switches or dropping disconnected components, see
the [`fix_case` reference](@ref fix).
