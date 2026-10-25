# First case: inspect, solve and verify

This walkthrough follows one small network from inspection to a checked solver
result. It uses the bundled synthetic four-wire feeder: four buses, three lines,
and two loads. Its electrical parameters and operating bounds are illustrative
study inputs, not utility-calibrated measurements. No external dataset is needed.

**Prerequisites:** install BMOPFTools using [Installation & first steps](installation.md).
Steps 1–2 need only BMOPFTools; step 3 additionally needs JuMP and Ipopt
(`using Pkg; Pkg.add(["JuMP", "Ipopt"])`). Step 2's browser inspection is optional.
The Julia example blocks execute during the documentation build; the browser
steps are manual. Run the blocks in order in the same Julia session.

## 1. Inspect the case before changing it

```@example first_case
using BMOPFTools

fixture = joinpath(pkgdir(BMOPFTools), "test", "data",
                   "case_development", "feeder.json")
net = parse_bmopf(fixture)
case_report = analyze(net)
render(case_report, "first-case-report.md")
println(length(net["bus"]), " buses; ", length(net["line"]), " lines; ",
        length(net["load"]), " loads")
println("Analysis: ", length(errors(case_report)), " errors; ",
        length(warnings(case_report)), " warnings")
```

[Read the generated analysis report](first-case-report.md). Look at the inventory,
modelling convention, and individual Finding codes as well as their severity.
Informational Findings can describe deliberate assumptions or useful context;
they are not all instructions to change the model. To print the report locally,
run `render(case_report, stdout)`.

For this fixture, `W.OPS.IMPORT_DEPENDENT` flags the reliance on grid supply,
and `W.CONV.TERMINAL_ROLES_INFERRED` reports that terminal roles use legacy
name inference rather than an explicit convention declaration. Decide whether
those assumptions suit your intended study; a later successful solve does not
resolve these input-model questions.

The same code accepts your own BMOPF file: replace `fixture` with its path.
For OpenDSS intake, continue with the [conversion guide](conversion.md).

## 2. Inspect the same network visually

```@example first_case
write_bmopf(net, "first-case.json")
println("Wrote first-case.json")
```

[Download the case](first-case.json) and drag it onto [Tellegen](https://tellegen.dev/).
This feeder has no geographic coordinates, so follow the viewer's placement
prompt for a topology layout. Select buses and branches and compare their IDs
and attributes with the report. The drawing is not a geographic survey.

For cases with coordinate evidence, follow the
[spatial review and correction workflow](visualization.md#Close-the-loop:-diagnose,-inspect,-correct,-recheck).
Spatial analysis is skipped for this coordinate-free fixture; it does not
provide an example of geographic error detection.

## 3. Solve the supplied operating case

This feeder already declares study inputs such as operating bounds, ratings,
and a priced grid connection. Keep those declarations unchanged for this first
solve; inspect them rather than adding synthetic assumptions automatically.

```@example first_case
using JuMP, Ipopt

optimizer = optimizer_with_attributes(Ipopt.Optimizer,
    "print_level" => 0, "sb" => "yes")
result = solve_opf(net; optimizer=optimizer)
println("Solver termination: ", result["termination_status"])
@assert string(result["termination_status"]) in ("OPTIMAL", "LOCALLY_SOLVED") # hide
```

The termination status describes the solver's outcome for the problem as posed.
It does not establish global optimality or that the model captures your intended
physical network. The fixture has no dispatchable DER fleet; use
[Developing OPF case families](tutorial_case_development.md) to study demand, PV,
and control choices after completing the verification below.

## 4. Verify the result against its case

```@example first_case
solution_report = profile_solution(net, result)
render_solution(solution_report, "first-case-solution.md")
println("Verification: ", length(errors(solution_report)), " errors; ",
        length(warnings(solution_report)), " warnings")
```

[Read the generated solution report](first-case-solution.md). Inspect the
reported checks, residuals, limit violations, and any unassessed quantities;
zero ERROR Findings alone is not a general validity certificate. Keep the case
and result together when interpreting the evidence.

For a worked explanation of independent checks, read
[Trust but verify](tutorial_trust_but_verify.md). If your own case fails to solve,
use [Infeasibility diagnosis](tutorial_infeasibility.md). To assess how the
package's solver implementation is tested, read
[Engine validation evidence](validation.md)—a different question from checking
this particular result.

## Choose the next task

- **Understand the declarations:** [Buses & terminals](terminals_primer.md),
  [Units and bases](tutorial_units.md), and [Data model conventions](conventions.md).
- **Investigate and prepare a case:** [Analysis & reports](analysis.md),
  [Spatial diagnostics](spatial_diagnostics.md), and [Case augmentation](augmentation.md).
- **Compare operating scenarios:** [Developing OPF case families](tutorial_case_development.md)
  uses the same bundled feeder.
- **Work through utility-data conversion and preparation:** the
  [end-to-end tutorial](tutorial_end_to_end.md) requires the external dataset
  identified at its start. It is not needed for the other routes above.

[Choose your tutorial](choose_tutorial.md) maps further tasks to their prerequisites.
