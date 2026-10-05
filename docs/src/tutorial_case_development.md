# Developing a small family of OPF cases

Start with a question: **how does this feeder behave when demand, PV availability,
or the location of installed PV changes?** This tutorial builds a few comparable
operating points, checks the returned solutions, and optionally saves an author log.
It does not define Task Force submission requirements.

You need the package's `test` environment (JuMP and Ipopt). The example uses an
original, small synthetic four-wire feeder shipped with the package. Its parameters
are illustrative, not calibrated to a utility population. The same functions accept
your own BMOPF network dictionary.

## 1. Keep equipment and operating conditions separate

The example has two customer aggregates and an unloaded cable joint. It supplies
phase-to-neutral operating bounds at the customers, per-conductor current ratings,
and a priced grid connection. Those are explicit study inputs, not values inferred
from a successful solve.

Load the worked recipes and build a base with **18 kVA total installed PV inverter
capacity**, shared according to the two customer aggregates:

```@example case_development
using BMOPFTools
include(joinpath(dirname(pathof(BMOPFTools)), "..", "examples", "case_development.jl"))
base, placement = case_development_base()
println("Installed capacity: ", sum(sum(inv["s_max"]) for inv in values(base["ibr"])), " VA")
println("PV availability: ", sum(inv["p_avail"] for inv in values(base["ibr"])), " W")
```

The two quantities happen to have the same numeric value here. They have different
meanings: `s_max` limits converter apparent power; `p_avail` is the active power
available from the PV source. A cloudy scenario changes availability without buying
a smaller inverter. Scenario creation allocates available power in proportion to
per-phase `s_max`, then sets `p_max` to the tightest of that allocation, the rating
and the base case's existing `p_max`. The native solver enforces this operating
box. Reactive bounds and `p_min` remain unchanged: a positive minimum output can
therefore conflict with a night-time scenario. Such a conflict must be investigated,
not silently repaired.

The example sets Q limits to ±40% of each phase's S rating, subject also to the
converter capability circle. That is an explicit illustrative assumption, not a
claim of compliance with a regional standard. Use known equipment capabilities
when you have them.

## 2. Make one operating point before making a sweep

```@example case_development
midday = CaseScenario(name="midday", demand_scale=0.5, pv_scale=1.0)
case, change_log = materialize_scenario(base, midday)
println("Base far-bus demand: ", base["load"]["far"]["p_nom"], " W")
println("Midday demand: ", case["load"]["far"]["p_nom"], " W")
@assert case["ibr"]["pv_far"]["s_max"] == base["ibr"]["pv_far"]["s_max"]
```

By default, P and Q demand receive the same multiplier, retaining each load's power
factor. Supply `reactive_scale` separately only when your scenario justifies it.
Load model and nominal voltage are unchanged. Every call starts from `base`, so
scenarios do not accumulate one another's changes.

Only IBRs explicitly labelled `prime_mover="PV"` are selected automatically.
`pv_ids=["pv_far"]` restricts the selection. Other generators, batteries and
STATCOMs remain unchanged. Missing availability or unknown selected IDs are errors,
not invitations to invent data. Availability increases do not automatically widen
hardware or dispatch bounds; inspect those bounds when using factors above one.

For a network with linked time profiles, select the time explicitly:

```julia
scenario = CaseScenario(name="summer_noon", t_index=13, demand_scale=1.1)
case, changes = materialize_scenario(time_series_network, scenario)
```

The profile is resolved first, then the extra study multiplier is applied. These
remain independent snapshot problems. Battery energy balances and EV departure
requirements need a coupled formulation; a snapshot sweep cannot supply them.

## 3. Compare a few operating regimes

```@example case_development
specs = [CaseScenario(name="evening", demand_scale=1.4, pv_scale=0.0),
         CaseScenario(name="midday", demand_scale=0.5, pv_scale=1.0),
         CaseScenario(name="cloudy", demand_scale=0.8, pv_scale=0.3)]
rows = run_case_sweep(base, specs; solve=case_development_solver)
for row in rows
    println(row["name"], ": ", row["status"], "; solver=", row["termination_status"])
    if row["status"] == "completed"
        println("  PV dispatched: ", round(row["metrics"]["pv_dispatch_w"]; digits=1), " W")
        println("  checks: ", row["verification"]["summary"])
    else
        println("  ", row["error_stage"], ": ", row["error"])
    end
end
```

The callback is the ordinary solver call. You control optimizer options and can
supply a different solver that returns the supported result dictionary. The runner
passes a fresh copy to the callback and profiles against the unchanged scenario.

Read the output in this order:

1. **Execution:** `completed` means materialization, solver invocation, and profiling
   completed. An exception is retained as an `error` row with its stage.
2. **Solver report:** inspect `termination_status`. Nonconvergence does not prove
   physical infeasibility. A returned unsolved result is still retained and profiled.
3. **Independent checks:** inspect coded Findings and `verification_status`, including
   unassessed dimensions. Zero ERROR Findings alone is not a global feasibility or
   optimality certificate. Warnings include both near-active limits and residual
   concerns; distinguish them by code.
4. **Physical comparison:** inspect loss (W), PV dispatch/curtailment (W), limit counts,
   and voltage-zone summaries. These are reported quantities, not an automatic
   ranking of how useful the case is. Review missing or non-finite result data first.

`keep_results=true` retains the full solver results for further inspection. The
usual default keeps the profile and compact metrics. No files are written by the
sweep. Each row records the exact in-memory scenario hash; a result is never assigned
to another network simply because their names match.

A binding device limit does not by itself show network congestion. Conversely, an
interior optimum can still represent useful optimization. Ask which controls moved,
which constraint families matter, and whether the result answers your study question.

## 4. Change placement while holding installed capacity fixed

Both `GeneratorRecipe` and `IBRRecipe` accept:

| Setting | Meaning |
|---|---|
| `bus_ids` | Explicit load buses. Existing voltage/source/device filters still apply; an explicit request that cannot be honoured raises an error. |
| `phase_by_bus` | A declared phase at each selected bus, making that new device single-phase with an explicit neutral. Unsupported connections are rejected. |
| `capacity_budget` | Total **new** capacity after filtering: W for generators, VA for IBRs. Existing sizing rules supply relative weights. Existing devices are not counted toward this budget. |

```julia
net, placements = add_ibrs(input; recipe=IBRRecipe(
    bus_ids=["near", "far"],
    phase_by_bus=Dict("near"=>"1", "far"=>"2"),
    capacity_budget=18_000.0))
```

Run `placement_experiment()` from the worked script to compare dispersed adoption
with all new PV at the far bus, at the same 18 kVA total. Phase assignments must
refer to physical bus terminals. The helper does not modify customer load phases.

For a sampled study, generate the explicit selections with your chosen seeded
sampling procedure and save its seed and assumptions. For example, use Julia's
`Random.MersenneTwister(seed)` and `shuffle` on a sorted eligible bus list. The
returned recipe records the actual selected IDs, so replay does not depend on
re-running the sampler. Sampling uniformly over buses is a study assumption,
not a calibrated adoption model.

## 5. Compare controls and check a reduction

The same script also exposes two small experiments:

```julia
control_rows = control_experiment()
comparison = reduction_experiment()
```

`control_experiment` holds equipment, availability, network limits and the export
incentive fixed. It compares free coordinated Q dispatch, unity power factor, and
an illustrative Volt-var curve. Active power remains optimizable in all three.
This compares steady-state feasible policies; it is not a simulation of controller
dynamics or a claim that any droop settings meet a grid code.

`reduction_experiment` removes the unloaded joint through the supported series
reduction. The source and target keep the same two PV device identities and terminal
maps. The script explicitly maps those IDs, pins the reduced solution's dispatch on
the full feeder, and runs PF there. It then checks the replay against the **original**
operating bounds. PF termination by itself does not check those bounds (PSK-000013).

For a different reduction, supply and review the appropriate mapping and recovery
procedure. This small example does not establish arbitrary reduction fidelity or
infer missing device identities. Start with the existing scientific contracts when
neutral elimination, member limits or discarded controls are involved.

## 6. Save a log only if it is useful to you

```julia
write_case_log(base, "case-development.json";
    manifests=[placement], runs=rows,
    assumptions=["Synthetic teaching feeder; not utility calibrated",
                 "Illustrative Q capability: +/-40% of S rating"],
    settings=Dict("optimizer"=>"Ipopt", "per_unit"=>true, "max_iter"=>500),
    source_paths=["original-feeder.json"])
```

Use `.md` for a readable log with the complete structured record embedded, or `.json`
for downstream processing. Source-file hashes describe file bytes; the case hash
describes sorted-key in-memory JSON, including array ordering. It is deliberately
not presented as the hash of an exported BMOPF file. Record that file separately
if its exact bytes matter. Transformation records now include resolved recipe
parameters and full structured Findings.

For reproducibility, record solver/package environments and any external data
versions you used. The helper records the package version but does not guess your
solver settings or whether a local checkout has uncommitted edits.

This log is optional. It explains how an author developed a case; it neither
certifies the case nor adds a Task Force submission requirement.

## 7. Move from teaching examples to useful cases

For a real feeder, first replace the assumptions that most affect your question:

- **Operating points:** use demand and PV observations from the same times and
  region, with their temporal resolution and aggregation level recorded. Sampling
  the two independently can create combinations that rarely occur. These global
  multipliers deliberately retain the base spatial pattern; use linked per-device
  profiles when spatial variation matters.
- **Equipment and connections:** check phase allocation, neutral/grounding data,
  cable and transformer ratings, and actual inverter capabilities. An absent
  rating is a data gap, not evidence that the asset has unlimited capacity.
- **Operating rules and incentives:** distinguish physical capability from export
  limits, control policy, and energy prices. Change one of these at a time when
  the purpose is to explain why dispatch changes.

Keep a small comparison table before generating many variants: the changed study
input, solver termination, verification status, losses, curtailment and the actual
constraint families that bind. Look for different physical mechanisms—for example,
evening voltage drop, midday voltage rise, a thermal bottleneck, or phase-specific
stress. A larger number of files does not necessarily give a more diverse set of
problems. Include ordinary operating conditions as well as challenging ones, and
retain unsuccessful attempts so selection does not hide the difficult cases.

Run these pilots into separate output directories. The bundled feeder and recipes
provide a reproducible way to test package behavior; calibration and selection of
a released real-world case family remain a separate study.

## API

```@docs
CaseScenario
materialize_scenario
run_case_sweep
write_case_log
```
