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

The feeder is `LV1_14bus`: a real 14-bus LV network with an 11 kV / 433 V
delta–wye transformer, nine cables, four normally-closed switches, two
single-phase loads and three neutral reactors.

!!! note "Two deep-dive tutorials branch off this one"
    Once the pipeline makes sense, [DER placement](tutorial_ders.md) explores the
    placement *strategies* and how the binding constraint flips, and the
    [VVWO tutorial](tutorial_vvwo.md) adds smart-inverter Volt-var/Volt-watt
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

Findings are meant to be matched on their **code**, never on message text. A raw
import like this one typically lands clean on structure but flags missing
operating bounds and modeling-provenance observations — exactly the gaps the
later steps fill:

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
source buses. Two passes are opt-in because they change topology inference or OPF
physics.

```@example e2e
net_fixed, fix_mf = fix_case(net; recipe = FixRecipe())

render_manifest(fix_mf)
```

## 4. Place DERs

A faithful import is usually a passive load feeder — there is nothing for an OPF
to optimise. [`add_inverters`](@ref) (and its sibling [`add_generators`](@ref))
**declare** a DER fleet with a recipe and let the library choose buses from the
network's own semantics, recording every field it writes. Here a
`:load_following` recipe drops one PV inverter on each load bus.

See the [DER placement tutorial](tutorial_ders.md) for the full menu of
placement strategies, sizing bases, and cost knobs.

```@example e2e
inv_recipe = InverterRecipe(
    strategy     = :load_following,   # one PV inverter per load bus
    s_fraction   = 5.0,               # s_max = 5 × local load
    s_to_p_ratio = 0.90,              # leave VA headroom for reactive support
    cost_basis   = :uniform, der_cost_uniform = 0.2,   # cheaper than the slack
)

net_der, der_mf = add_inverters(net_fixed; recipe = inv_recipe)

render_manifest(der_mf)
```

## 5. Augment — standards-grounded gap-filling

[`augment_case`](@ref) fills the bounds and costs an OPF needs, **without
overwriting any value already present**. Each fill is tagged in the manifest as
`:standard` (derived from a cited standard) or `:synthetic` (a design choice).
The passes draw on EN 50160 (voltage bounds), IEC 60228 (thermal limits from
conductor cross-sections), and EN 50549-1 / IEEE 1547 (reactive capability). See
[Case augmentation](augmentation.md) for the full pass-by-pass rationale.

```@example e2e
net_ready, aug_mf = augment_case(net_der; recipe = AugmentationRecipe())

render_manifest(aug_mf)
```

## 6. Re-validate

Re-running [`analyze`](@ref) on the augmented case confirms the operating-bound
warnings have cleared — the case is now a well-posed OPF instance.

```@example e2e
report2 = analyze(net_ready)

println("Before → after augmentation")
println("  ERRORs   : ", length(errors(report)),  " → ", length(errors(report2)))
println("  WARNINGs : ", length(warnings(report)), " → ", length(warnings(report2)))
```

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
println("Objective   : ", round(result["objective"]; sigdigits = 6))
```

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

```@example e2e
out_dir = mktempdir()
write_bmopf(net_ready, joinpath(out_dir, "LV1_14bus_ready.json"))

manifests = Dict(
    "fix"     => manifest_to_dict(fix_mf),
    "der"     => manifest_to_dict(der_mf),
    "augment" => manifest_to_dict(aug_mf),
)

println("Wrote benchmark-ready case to ", out_dir)
println("Captured ", sum(length(m["entries"]) for m in values(manifests)),
        " transformation entries across the three manifests")
```

That is the full arc: a raw OpenDSS export is now a clean, bounded, DER-equipped
BMOPF benchmark with a solved OPF and an audit trail for every transformation.
