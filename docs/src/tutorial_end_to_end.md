# End-to-end tutorial: from OpenDSS to a solved OPF benchmark

This is the **primary use case** of BMOPFTools, start to finish, on one real
feeder. We take a utility-style OpenDSS model and walk the whole pipeline:

```
load → analyze → fix → place DERs → augment → re-validate → solve → export
```

Every code block on this page is **executed when the documentation is built**,
so the inventory counts, findings, manifests and solver output below are real —
not hand-transcribed. The complete copy-paste scripts live in
[`examples/lv1_14bus_walkthrough.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/lv1_14bus_walkthrough.jl)
(analysis) and
[`examples/augment_and_solve.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/augment_and_solve.jl)
(preparation and solve).

The feeder is `LV1_14bus`: a real LV network — 14 LV buses plus the 11 kV
source bus, 15 buses in total — with an 11 kV / 433 V delta–wye transformer,
nine cables, four normally-closed switches, two single-phase loads and three
neutral reactors.

!!! note "Prerequisites"
    A Julia session with BMOPFTools plus **JuMP** and **Ipopt** for the solve
    step: `using Pkg; Pkg.add(["JuMP", "Ipopt"])` in your own environment. If
    you are working from a clone of the repository, the docs environment
    already has everything: `julia --project=docs`. First time with Julia, or
    unsure what any of that means? Start with
    [Installation & first steps](installation.md).

!!! note "Two deep-dive tutorials branch off this one"
    Once the pipeline makes sense, [DER placement](tutorial_ders.md) explores the
    placement *strategies* and how the binding constraint flips, and the
    [VVWO tutorial](tutorial_vvwo.md) adds smart-IBR Volt-var/Volt-watt
    control inside the OPF.

## 1. Load — OpenDSS → BMOPF

[`from_dss`](@ref) parses the OpenDSS model in-process (via
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl)) and returns the BMOPF
network as a plain `Dict{String,Any}`.

```@example e2e
using BMOPFTools

dss_path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
net = from_dss(dss_path)

for comp in ("bus", "line", "linecode", "switch", "load", "shunt", "voltage_source")
    n = length(get(net, comp, Dict()))
    n > 0 && println(rpad(comp, 16), ": ", n)
end
xfmr = get(net, "transformer", Dict())
println(rpad("transformer", 16), ": ", sum(length(v) for v in values(xfmr) if v isa Dict; init=0),
        "  (", join(keys(xfmr), ", "), ")")
```

`from_dss` is loud about fidelity: the `Warning` it prints above lists every
piece of OpenDSS information that has no BMOPF representation and was dropped
(here mostly cosmetic fields such as linecode `units`). The console preview
shows one line per diagnostic class — the full, untruncated list stays
inspectable at `net["_meta"]["powerio_warnings"]`, and the same diagnostics
reach [`analyze`](@ref) as findings (see
[Ingest warnings](@ref ingest-warnings)).

## 2. Analyze & diagnose

[`analyze`](@ref) runs fifteen passes — inventory, connectivity, voltage levels,
provenance, schema, completeness, domain rules, redundancy, integrity, spec
conformance, benchmark readiness, and more — and returns a
[`SummaryReport`](@ref). Each diagnostic is a [`Finding`](@ref) with a stable
dot-separated code; see [Analysis & reports](analysis.md) for what each pass
computes and the [finding-code reference](findings.md) for the full catalogue.

```@example e2e
report = analyze(net)

println("ERRORs   : ", length(errors(report)))
println("WARNINGs : ", length(warnings(report)))
println("INFOs    : ", length(infos(report)))
```

Findings are meant to be matched on their **code**, never on message text. This
feeder imports with zero errors and two warnings: a handful of degree-1 buses
with nothing attached (`W.CONN.DANGLING` — switch and stub endpoints), and
`W.OPS.IMPORT_DEPENDENT` — the feeder has **no local generation at all**. That
second warning is the analyzer telling you the import is a *passive load
feeder*: there is nothing for an OPF to optimise yet, which is exactly what the
DER-placement step below is for. The missing operating bounds show up as INFO
findings such as `I.PRE.NO_VOLT_BOUNDS`, which the augmentation step fills.

```@example e2e
for f in warnings(report)
    println("WARN  [", f.code, "]  ", f.message)
end
```

The full report renders to a terminal or a Markdown file. The one-line
**modeling-convention statement** (wires per voltage level, grounding style,
normalisations) makes the case's hidden assumptions explicit:

```@example e2e
render(report, stdout)
```

## 3. Fix — structural repair

[`fix_case`](@ref) applies idempotent structural repairs and returns the
repaired network plus a [`TransformationManifest`](@ref) recording every change.
The default [`FixRecipe`](@ref) keeps the largest connected component, merges
trivial series lines, drops electrically-inert zero loads, turns
near-zero-impedance lines into switches, and strips redundant voltage bounds off
source buses. Four passes are opt-in because they change topology inference,
representation, or OPF physics: `apply_adjacent_current_bounds`,
`apply_perfect_grounding`, `apply_shunt_to_capacitor`, and
`apply_snap_transformer_impedance`.

```@example e2e
net_fixed, fix_mf = fix_case(net; recipe = FixRecipe())

render_manifest(fix_mf)
```

## 4. Place DERs

A faithful import is usually a passive load feeder — there is nothing for an OPF
to optimise. [`add_ibrs`](@ref) (and its sibling [`add_generators`](@ref))
**declare** a DER fleet with a recipe and let the library choose buses from the
network's own semantics, recording every field it writes. Here a
`:load_following` recipe drops one PV IBR on each load bus.

See the [DER placement tutorial](tutorial_ders.md) for the full menu of
placement strategies, sizing bases, and cost knobs.

```@example e2e
ibr_recipe = IBRRecipe(
    strategy     = :load_following,   # one PV IBR per load bus
    s_fraction   = 5.0,               # s_max = 5 × local load
    s_to_p_ratio = 0.90,              # leave VA headroom for reactive support
    cost_basis   = :uniform, der_cost_uniform = 0.2,   # cheaper than the slack
)

net_der, der_mf = add_ibrs(net_fixed; recipe = ibr_recipe)

render_manifest(der_mf)
```

## 5. Augment — standards-grounded gap-filling

[`augment_case`](@ref) fills the bounds and costs an OPF needs, **without
overwriting any value already present**. Each fill is tagged in the manifest as
`:standard` (derived from a cited standard) or `:synthetic` (a design choice).
The passes draw on EN 50160 (voltage bounds), a heuristic conductor-size →
ampacity estimate (thermal limits, loosely IEC-60228/60364-calibrated), and
EN 50549-1 / IEEE 1547 (reactive capability). See
[Case augmentation](augmentation.md) for the full pass-by-pass rationale.

```@example e2e
net_ready, aug_mf = augment_case(net_der; recipe = AugmentationRecipe())

render_manifest(aug_mf)
```

**Where the thermal limits landed.** The thermal pass writes a heuristic
per-conductor ampacity `i_max` (in A) onto each linecode that lacked one — this
is the line/cable thermal limit the OPF enforces, and it is tagged `:synthetic`
in the manifest above. Read it straight off the prepared linecodes:

```@example e2e
for (lc_id, lc) in sort(collect(net_ready["linecode"]); by = first)
    imax = get(lc, "i_max", nothing)
    println(rpad(lc_id, 16),
            imax === nothing ? "no i_max (skipped — see manifest)" :
                               string("i_max = ", imax, " A"))
end
```

A **transformer's** thermal limit is a different mechanism: its nameplate
`s_rating` (kVA) already plays that role and the OPF enforces it directly, so
`augment_case` never adds a separate transformer thermal limit. The full
pass-by-pass rationale — the R₁₁ → ampacity lookup table, its confidence gating,
and the neutral-conductor rating — is in
[Case augmentation](augmentation.md).

## 6. Re-validate

Re-running [`analyze`](@ref) on the prepared case shows what the pipeline
actually changed. Raw counts are a blunt instrument — the interesting signal is
*which* finding codes appeared and disappeared, so we diff them:

```@example e2e
report2 = analyze(net_ready)

all_codes(r) = Set(f.code for f in [errors(r); warnings(r); infos(r)])
before, after = all_codes(report), all_codes(report2)

println("ERRORs   : ", length(errors(report)),   " → ", length(errors(report2)))
println("WARNINGs : ", length(warnings(report)), " → ", length(warnings(report2)))
println("Cleared  : ", join(sort(collect(setdiff(before, after))), ", "))
println("New      : ", join(sort(collect(setdiff(after, before))), ", "))
```

Augmentation cleared `I.PRE.NO_VOLT_BOUNDS` — every bus now has voltage bounds,
so the OPF is well-posed — and the new INFO codes are consequences of the fills
(e.g. `I.PROV.OVERLAPPING_VOLTAGE_BOUNDS` notes that the phase-to-ground and
phase-to-neutral envelopes now coexist). `W.OPS.IMPORT_DEPENDENT` also cleared:
the DER-placement step gave the feeder local active capacity, and that pass
counts both dispatchable `generator` units and the `ibr` fleet we placed (a PV
IBR on each load bus, sized well above the local load), so the feeder is no
longer a passive import. The lone surviving warning is `W.CONN.DANGLING`: a few
degree-1 stub buses that are live switch endpoints (it dropped from 5 buses to
3) — a **structural** finding that gap-filling does not (and should not) touch.
Re-validation is a diff to be read, not a score to be zeroed.

## 7. Solve

`solve_opf` lives in a package extension that loads once **JuMP** and a solver
such as **Ipopt** are present. It solves the four-wire IVR-EN model
(see [Optimal power flow](opf.md)) and returns a result dictionary mirroring the
network structure (see [OPF result dictionary](results.md)).

```@example e2e
using JuMP, Ipopt

optimizer = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
result = solve_opf(net_ready; optimizer = optimizer, per_unit = true)

println("Termination : ", result["termination_status"])
println("Cost rate   : ", round(result["objective"]; sigdigits = 6), " \$/h")
```

The **negative objective is correct**: the PV fleet placed in step 4 is priced
well below the slack and sized at five times the local load, so the cheap DERs
over-generate and the feeder *exports* the surplus. Negative grid import is
revenue at the slack price, hence a negative cost objective.

### Inspecting the result dictionary

`result` is a plain `Dict{String,Any}` in SI units whose structure mirrors the
network: top-level keys are component types, then component id, then terminal.
The full field reference is in [OPF result dictionary](results.md); here we read
a few solved quantities directly:

```@example e2e
b = "b2656"                                    # a load bus with a 1-phase customer
println("Bus '", b, "' terminal voltages (V):")
for (t, v) in sort(collect(result["bus"][b]); by = first)
    println("  terminal ", rpad(t, 3), " |V| = ", round(v["vm"]; digits = 2))
end

# Total active power imported from the grid = Σ ps over the source phases.
src    = first(values(result["voltage_source"]))
p_grid = sum(v["ps"] for v in values(src))
println("\nGrid import : ", round(p_grid / 1e3; digits = 2), " kW")
println("Network loss: ", round(result["losses"]["p_loss"] / 1e3; digits = 2), " kW")
```

Note the fourth terminal: the neutral at `b2656` sits at ≈ 1.3 V above ground,
not 0. The single-phase load and PV cluster on this bus load the phases
unevenly, the imbalance current returns through the neutral conductor, and the
neutral point shifts — so the phase-to-*neutral* voltages the customer actually
sees differ from the phase-to-ground magnitudes. This neutral-point shift is
exactly what the four-wire model resolves and a Kron-reduced three-wire model
would silently ground away. Grid import is negative, as anticipated above: the
feeder exports ≈ 69 kW of PV surplus.

### Profiling the solution

[`profile_solution`](@ref) checks the result against the network bounds —
flagging violations, near-active constraints, and residuals — without access to
solver internals, and returns a [`SolutionReport`](@ref):

```@example e2e
sol_report = profile_solution(net_ready, result)

println("Solution ERRORs   : ", length(errors(sol_report)))
println("Solution WARNINGs : ", length(warnings(sol_report)))

render_solution(sol_report, stdout)
```

!!! tip "When the OPF is infeasible"
    If `solve_opf` reports an infeasible status, swap in
    `solve_feasibility_opf`, which relaxes the problem with elastic current
    slacks, then call `diagnose_infeasibility` to rank the buses absorbing the
    most slack. The [Bounds & feasibility](bounds/index.md) chapter explains how
    to trust — and act on — the solver's verdict.

## 8. Export

[`write_bmopf`](@ref) serialises the benchmark-ready case.
[`manifest_to_dict`](@ref) turns each manifest into a JSON-serialisable `Dict`,
giving every downstream consumer a complete, auditable record of what was
repaired, placed, and filled.

The solved result and the solution report export the same way:
[`write_result`](@ref) writes the result dict to JSON (read it back with
[`read_result`](@ref)), and [`render_solution`](@ref) writes the human-readable
report to a Markdown file when given a path instead of an `IO`.

```@example e2e
out_dir = mktempdir()
write_bmopf(net_ready, joinpath(out_dir, "LV1_14bus_ready.json"))     # the case
write_result(result,   joinpath(out_dir, "LV1_14bus_result.json"))    # solved values
render_solution(sol_report, joinpath(out_dir, "LV1_14bus_report.md")) # the report

manifests = Dict(
    "fix"     => manifest_to_dict(fix_mf),
    "der"     => manifest_to_dict(der_mf),
    "augment" => manifest_to_dict(aug_mf),
)

# The manifests are plain dicts — write them next to the case with any JSON
# library, and the audit trail ships with the benchmark.
using JSON3
open(io -> JSON3.write(io, manifests), joinpath(out_dir, "LV1_14bus_manifests.json"), "w")

# The result JSON round-trips back to an identical dict.
roundtrip = read_result(joinpath(out_dir, "LV1_14bus_result.json"))
println("Result JSON round-trips : ",
        roundtrip["bus"] == result["bus"])

println("Wrote case, result, report, and manifests to ", out_dir)
println("Captured ", sum(length(m["entries"]) for m in values(manifests)),
        " transformation entries across the three manifests")
```

That is the full arc: a raw OpenDSS export is now a clean, bounded, DER-equipped
BMOPF benchmark with a solved OPF, an exported result and report, and an audit
trail for every transformation.
