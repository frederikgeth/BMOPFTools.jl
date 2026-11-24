# Advanced formulations and numerics

Use this section when you need to change how a study is constructed, understand
its equation encoding, or investigate numerical behavior. Start with
[First case](first_case.md) and the [units tutorial](tutorial_units.md); these
advanced routes are optional branches from that basic workflow.

## How are the equations represented?

| Your question | Start here | Continue with |
|:--|:--|:--|
| Which network matrix should I assemble? | [Nodal admittance builders](spec/nodal-admittance.md) | [Transformer primitive admittance](spec/transformer-admittance.md) for device stamps and conventions. |
| Can a variable or equation be eliminated? | [Exact substitutions and formulation boundaries](formulation_substitutions.md) | The linked device equations in the [OPF reference](opf.md). |
| How do objective and limit encodings affect the solve? | [Objective norms and smoothing](objectives.md#Which-norm?) | [Objective pitfalls](objectives.md#objective-pitfalls) and [formulation-helper rationale](@ref opf-formulation-helpers). Private helpers remain contributor interfaces. |
| How are inverter control curves encoded? | [Smooth droop encoding](relu_softplus_encoding.md) | [PV control study](tutorial_vvwo.md) for the engineering application. |

The package's reference OPF uses nonconvex rectangular current–voltage equations.
The [bounds and feasibility discussion](bounds/index.md) also discusses other
formulation families; that discussion does not imply that BMOPFTools ships those
relaxations or approximations.

## How do I construct a different study?

| Your question | Start here | Continue with |
|:--|:--|:--|
| Can I change the objective or add a constraint? | [Custom formulations](tutorial_custom_formulations.md) | [Staged model construction](differentiable_extensions.md#Current-extension-substrate). |
| Can I replace a device formulation and retain result access? | [Model extensions and sensitivities](differentiable_extensions.md) | [Device replacement](differentiable_extensions.md#Replaceable-device-formulations) and [semantic solution access](differentiable_extensions.md#Semantic-solution-access). DiffOpt is not required. |
| Can several periods share constraints and one objective? | [Coupled snapshots](tutorial_custom_formulations.md#5.-Rung-3-—-two-snapshots,-one-model:-an-energy-budget) | [Multi-period construction](@ref staged-api). This is one joint optimization; an independent time-series sweep does not impose inter-temporal coupling. Storage dynamics remain user-supplied. |
| Can I update coefficients without rebuilding everything? | [Repeated solves and parameter updates](repeated_solves.md) | The supported parameter-provider and optimizer-reset workflow. |
| How does a solution respond to a small parameter change? | [DiffOpt worked example](@ref diffopt-worked-example) | Local differentiability, active-set and KKT qualifications in the same guide. |

## How do I understand numerical behavior?

| Your question | Start here | Continue with |
|:--|:--|:--|
| Which coordinates, bases and starting values are used? | [Scaling, initialization and diagnostics](numerical_workflows.md) | [Solver guide](solvers.md) for backend choices and settings. |
| What can bounds, initialization or a solver status establish? | [Bounds, branches and feasibility](bounds/index.md) | [Trusting the solver](bounds/solver_trust.md). |
| What should I record to reproduce an experiment? | [Experiment provenance](differentiable_extensions.md#Experiment-provenance) | Record scaling, parameter state and formulation ownership alongside the study inputs and outputs. |

For input-data concerns, use [How network diagnostics work](methodology.md) in
**Inspect & prepare cases**. For a returned solution, start with
[Trust but verify](tutorial_trust_but_verify.md), then
[solution projection and power-flow comparison](solution_projection.md) in
**Verify & diagnose results**. The [engine validation page](validation.md)
describes implementation evidence and its coverage.
