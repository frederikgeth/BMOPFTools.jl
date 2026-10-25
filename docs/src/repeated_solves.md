# Repeated solves and parameter updates

Scenario studies, time series and sensitivity experiments all solve related
problems, but they do not necessarily share one model. Choose the workflow
before trying to reuse solver state. These workflows need JuMP and a suitable
optimizer; DiffOpt is needed only when requesting derivatives through DiffOpt.

## Choose what is shared

| What changes or couples? | Workflow | Detailed guide |
|:--|:--|:--|
| Network data or independent operating scenarios | Materialize each case/snapshot and build its model. This is the simplest baseline. | [Case families](tutorial_case_development.md), [time series](tutorial_timeseries.md). |
| Supported coefficient values in an already parameterized model | Update the registered JuMP parameters and follow the cached-model reset/re-solve workflow. | [Updating parameters and resolving](@ref opf-parameter-resolves), [`resolve_opf!`](@ref). |
| Topology, dimensions, device ownership or voltage-domain certificates | Rebuild the model; a coefficient update does not reconstruct these choices. | [Staged construction](differentiable_extensions.md#Current-extension-substrate), [device replacement](differentiable_extensions.md#Replaceable-device-formulations). |
| Decisions coupled between time periods | Build multiple contexts into one model, add coupling constraints and solve jointly. | [Multi-period and storage construction](@ref staged-api), [coupled-snapshot example](tutorial_custom_formulations.md#5.-Rung-3-—-two-snapshots,-one-model:-an-energy-budget). |

Updating the source network dictionary alone does not update an already built
JuMP model. For a parameterized path, the coefficient-provider reference defines
which quantities remain symbolic. A parameter that currently equals zero is
still a parameter; see [substitution boundaries](formulation_substitutions.md).

## Reuse needs a fresh solution check

The [canonical update workflow](@ref opf-parameter-resolves) documents a measured
stale-evaluation failure and the tested `resolve_opf!` workaround. It owns the
code recipe, version-specific evidence, cached/direct-model distinction, and
reset behavior; follow it rather than assuming another call to `optimize!`
invalidates all numerical caches.

The reset preserves JuMP handles and algebra but reloads the optimizer. It is
not a promise to retain numerical factorizations or transport primal/dual warm
starts. Check the solution against the **updated** parameters and physical
laws. A successful termination status alone is insufficient.

For sensitivity studies, the [DiffOpt example](@ref diffopt-worked-example)
compares analytic, forward, reverse and finite-difference derivatives on one
selected local solution branch. For experiment logs, use
[research provenance](differentiable_extensions.md#Experiment-provenance) at
appropriate checkpoints. For changes in base policy or initialization, return
to [Scaling, initialization and diagnostics](numerical_workflows.md).
