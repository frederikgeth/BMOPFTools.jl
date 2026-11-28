# [Sensitivities with DiffOpt](@id diffopt-sensitivities)

## What does differentiating a solved model provide?

How much does a bus voltage change if a line resistance increases slightly?
How does a dispatch decision respond to a demand or cost parameter? These are
questions about the **sensitivity of a solved model**, rather than just the
derivatives of its equations. They are useful for parameter calibration,
local screening, and research algorithms that place an optimization problem
inside an outer learning or design loop.

[DiffOpt.jl](https://jump.dev/DiffOpt.jl/) adds forward and reverse
differentiation to supported JuMP/MathOptInterface optimization models [2, 3].
In the nonlinear workflow below, Ipopt solves the model and DiffOpt computes a
local derivative through its optimality conditions. This does not require
unrolling Ipopt's iterations; implicit differentiation separates the solution
method from the derivative calculation [4].

| What you need | Mode | Seed and result |
|---|---|---|
| Responses to one parameter direction | Forward | Seed a parameter perturbation; obtain directional changes in solution variables. |
| A gradient of one scalar output with respect to parameters | Reverse | Seed that output; obtain parameter sensitivities by an adjoint calculation. |

**Prerequisites:** work through [First case](first_case.md), know basic JuMP
model construction, and read [units and bases](tutorial_units.md). The worked
example uses the optional `test/diffopt` environment; DiffOpt is not a runtime
dependency of BMOPFTools. For assembling a network matrix alone, start with
[nodal admittance builders](spec/nodal-admittance.md).

## [Worked example: voltage sensitivity to line resistance](@id diffopt-worked-example)

A 1,000 V source supplies a 100 kW constant-power load through a 0.5 ohm
resistive line. Both neutrals are perfectly grounded. A 900–999 V load-voltage
band selects the high-voltage solution and is inactive at the operating point.
A constant objective makes this a power-flow feasibility example; it does not
illustrate sensitivity of economic dispatch or an active operating limit.

Writing ``V_s`` for the fixed source voltage, ``P`` for load power and ``R`` for
line resistance gives an independent check:

```math
V^2-V_s V+RP=0,\qquad
V=\frac{V_s+\sqrt{V_s^2-4RP}}{2},\qquad
\frac{dV}{dR}=-\frac{P}{2V-V_s}.
```

Here ``V\approx947.2136`` V and ``dV/dR\approx-111.8034`` V/ohm. Locally,
an extra 0.001 ohm therefore predicts about a 0.112 V voltage decrease.
The script below checks the circuit residual after every solve and compares
three derivative calculations. The coefficient provider replaces the native
line-resistance coefficient with a live JuMP parameter; changing the original
network dictionary alone would not update the constructed JuMP model.

From a repository checkout, prepare the isolated optional environment once:

```sh
julia --project=test/diffopt --startup-file=no -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=test/diffopt --startup-file=no examples/diffopt_resistance_sensitivity.jl
```

The following code is included directly from
[`examples/diffopt_resistance_sensitivity.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/diffopt_resistance_sensitivity.jl).
The optional DiffOpt test job executes this same function and checks its results;
the ordinary documentation build displays it without installing DiffOpt.

```@eval
using Markdown
source = read(joinpath(Main.REPOSITORY_ROOT, "examples", "diffopt_resistance_sensitivity.jl"), String)
Markdown.parse("```julia\n" * source * "\n```")
```

Forward and reverse results should agree with the analytic derivative to about
``10^{-7}`` V/ohm, and the central difference to about ``10^{-5}`` V/ohm in the
tested environment. The finite-difference step is in ohms, and `per_unit=false`
makes the output voltage an SI quantity. For a per-unit model, the provider
must divide physical resistance by the impedance base, and the output
sensitivity must be multiplied by the voltage base; the optional integration
suite also checks that conversion.

This derivative belongs to the selected local solution. As ``2V-V_s`` tends
to zero the analytic sensitivity becomes singular; an active-set change or
switch to a different solution branch also invalidates a naive smooth
extrapolation. `opf_differentiability_report(ctx).ready` screens supported
construction and solution conditions but does not prove KKT nonsingularity.
For production experiments, continue to
[differentiability readiness](#Differentiability-readiness-and-qualifications),
[singular-KKT handling](#Refusing-singular-KKT-derivatives), and the
[parameter-update workflow](@ref opf-parameter-resolves). The circuit residual
above is an example-specific check; larger studies need the independent
[solution-verification workflow](tutorial_trust_but_verify.md) too.

## Who owns which part?

DiffOpt computes sensitivities of supported models built with the
[extension API](differentiable_extensions.md). Downstream research code chooses
the parameters, outputs, outer objective, and how to validate and use those
derivatives. The API does not supply a globally differentiable OPF solver or a
complete bilevel algorithm.

## Mathematical scope

Consider the smooth parameterized nonlinear program

```math
\begin{aligned}
z^\star(\theta) \in \arg\min_z\quad & f(z,\theta) \\
\text{subject to}\quad & c(z,\theta)=0, \\
                         & g(z,\theta)\leq0.
\end{aligned}
```

Writing its local primal-dual optimality system as
``F(w^\star,\theta)=0``, implicit differentiation formally gives

```math
\frac{\partial w^\star}{\partial\theta}
=-
\left(\frac{\partial F}{\partial w}\right)^{-1}
\frac{\partial F}{\partial\theta},
```

when the relevant Jacobian is nonsingular. This is a **local sensitivity of the
selected primal-dual solution**. For the nonconvex IVR-EN formulation it is not a
derivative of a guaranteed global optimizer. Multiple local solutions,
degeneracy, finite solver tolerances, and initialization can change the selected
solution branch.

Classical perturbation analysis relates smooth solution sensitivity to
constraint qualifications, second-order sufficient conditions, and
complementarity/nondegeneracy assumptions [1]. DiffOpt implements forward and
reverse differentiation of optimization models through MathOptInterface model
transformations [2]. The original paper develops quadratic/conic rules;
current nonlinear API support is documented separately [3] and exercised by
the package integration tests.

## Differentiability readiness and qualifications

After optimization, call:

```julia
report = opf_differentiability_report(ctx)
report.ready || error(join(report.qualifications, "\n"))
```

The report checks construction lifecycle, termination status, discrete
variables, and unconsumed providers. It records parameter/coefficient keys and
classifies scalar inequalities from normalized primal slack and dual magnitude:
`active_constraints`, `near_active_constraints`,
`weakly_active_constraints`, and `violated_constraints`. Near-active and weakly
active constraints make `ready=false`; tolerances are explicit keywords so a
study can align them with its solver tolerances and report them. This catches
common active-set and strict-complementarity hazards, but is not a proof of LICQ,
second-order sufficiency, or solution-branch uniqueness.

Reports and research hashes inspect the complete JuMP model. When several
snapshot contexts share one model, model/constraint counts, residuals, active
sets, and readiness are therefore model-wide; semantic inventories and build
manifests remain context-owned. A report from one snapshot can consequently
reflect a constraint added by another snapshot. Treat this as a joint-model
qualification, not a per-snapshot certificate.

## Explicit differentiability annotations

A completed JuMP graph cannot, in general, reveal that an extension selected
its equations using Julia control flow, embedded a bespoke hard operator, or
accepted a parameter at a formulation-specific location whose structure may
change. Extension packages should declare these cases explicitly:

```julia
register_opf_differentiability_annotation!(ctx, :volt_watt_hard_priority;
    kind=:nonsmooth_operator,
    description="The lower-level priority rule contains a hard max",
    owner=:PowerOptLab,
    key=OpfModelKey(:expression, :pv_priority, "pv_1"))

register_opf_differentiability_annotation!(ctx, :fixed_scenario_regime;
    kind=:dynamic_branch,
    description="A regime was selected before construction and held fixed",
    owner=:PowerOptLab,
    blocking=false,
    metadata=Dict("study_protocol" => "fixed-regime-v1"))
```

The supported kinds are `:nonsmooth_operator`, `:dynamic_branch`, and
`:unsupported_parameter_location`. An optional `OpfModelKey` or
`OpfCoefficientKey` locates the issue. Annotations block readiness by default;
`blocking=false` is an explicit owner assertion that the disclosed choice is
fixed or otherwise outside the differentiated path. It remains in
`report.qualifications`, `opf_differentiability_annotations(ctx)`, provenance,
and the annotation hash. This mechanism is an auditable declaration, not static
analysis of extension code and not a proof that undeclared operations are
smooth.

## Refusing singular KKT derivatives

DiffOpt's nonlinear backend may apply inertia correction to a singular KKT
Jacobian. That can be useful numerically, but the resulting regularized
sensitivity answers a modified linear system. For a fail-closed research
workflow, install BMOPFTools' optional checked factorization before calling
DiffOpt:

```julia
JuMP.MOI.set(model, DiffOpt.NonLinearKKTJacobianFactorization(),
    opf_checked_kkt_factorization(ctx; pivot_tolerance=1e-10))

DiffOpt.set_forward_parameter(model, theta, 1.0)
DiffOpt.forward_differentiate!(model)  # throws OpfDifferentiationError if rejected

diagnostic = opf_kkt_diagnostic(ctx)
@assert diagnostic.status == :accepted
```

The callback uses sparse LU and records the matrix dimension, rejection
tolerance, and minimum-to-maximum absolute pivot ratio. The ratio is a cheap,
global-scale-invariant warning proxy, not an exact condition number. It deliberately
throws rather than returning zeros or silently regularizing a rejected system.
Installing the callback remains explicit because BMOPFTools does not depend on
DiffOpt or own downstream JVP/VJP execution. After an attempt, the diagnostic is
also incorporated into `opf_differentiability_report(ctx)`.

## Scientific limitations

### Active-set changes

Inequality-constrained solution maps are generally piecewise smooth. DiffOpt's
nonlinear sensitivity is local and does not account for active-set changes [3].
Voltage limits, inverter capability curves, volt-watt activation, thermal
limits, battery bounds, and tap bounds are therefore scientifically important
transition points. Derivatives should be checked against directional or
one-sided perturbations near such points.

Interior-point solvers generally return a point slightly inside a mathematically
binding inequality. Consequently, the active and transition tolerances should
be no tighter than the study's observed primal/barrier residuals. The report
stores `minimum_inactive_slack` to make that calibration auditable.

### Nonuniqueness and regularization

When the lower problem has multiple solutions, ``argmin`` is set-valued. A
solver and its initialization select one solution; this is not automatically an
optimistic or pessimistic bilevel convention. A downstream package may add a
small regularization to isolate a solution, but must report that regularization
because it changes the mathematical problem.

### Discrete decisions

Switch states, exact tap steps, and binary battery modes have no ordinary
derivative. Enumeration, continuous relaxations, smoothing, surrogate gradients,
or mixed discrete/continuous outer methods belong in downstream research code
and must be stated explicitly.

### Solution versus value derivatives

Researchers should distinguish sensitivity of the optimizer
``\partial z^\star/\partial\theta``, sensitivity of the optimal value, and the
gradient of a downstream loss. The extension API exposes primitive model objects
so a research package can define the relevant mathematical quantity rather than
receiving an ambiguous generic “gradient.” Forward Jacobian-vector products and
reverse vector-Jacobian products are generally preferable to materializing a
dense Jacobian [4].

## Research directions

Differentiable optimization is used for optimization layers and
decision-focused learning [5, 6], bilevel and hyperparameter optimization [4,
7], differentiable model-predictive control [8], inverse problems and parameter
estimation, and learning constrained policies while retaining explicit physical
models.

Power-system applications include dynamic locational marginal emissions via
implicit differentiation [9], learning state-dependent robustness margins for
OPF [10], and distribution-system flexibility sensitivities [11]. More recent
work explores differentiating power-flow solutions with respect to admittance
and topology parameters [12]; that item is a preprint and is cited as emerging
work rather than established evidence.

The interface is intended to enable research in these directions without
claiming support for global sensitivities, exact discrete differentiation,
parameter-dependent topology without rebuilding, generalized derivatives, or
GPU-batched differentiable simulation.

## Reproducibility checklist

A publication using this capability should report, at minimum:

- BMOPFTools, JuMP, DiffOpt, and solver versions;
- the network snapshot and formulation choices;
- parameter and output definitions with SI/internal scaling;
- initialization, warm-start, regularization, and smoothing choices;
- termination status and primal/dual/complementarity residuals;
- the local active-set convention and tolerance;
- how nonconvex solution-branch consistency was assessed;
- finite-difference or analytic derivative checks away from transitions;
- the treatment of discrete controls and failed/singular derivative evaluations.

## References

1. J. F. Bonnans and A. Shapiro, “Optimization Problems with Perturbations: A
   Guided Tour,” *SIAM Review* 40(2), 228–264, 1998.
   [doi:10.1137/S0036144596302644](https://doi.org/10.1137/S0036144596302644)
2. M. Besançon, J. Dias Garcia, B. Legat, and A. Sharma, “Flexible
   Differentiable Optimization via Model Transformations,” *INFORMS Journal on
   Computing* 36(2), 456–478, 2024.
   [doi:10.1287/ijoc.2022.0283](https://doi.org/10.1287/ijoc.2022.0283)
3. [DiffOpt.jl nonlinear differentiation reference](https://jump.dev/DiffOpt.jl/stable/reference/).
4. M. Blondel et al., “Efficient and Modular Implicit Differentiation,”
   *NeurIPS*, 2022. [paper](https://papers.neurips.cc/paper_files/paper/2022/hash/228b9279ecf9bbafe582406850c57115-Abstract-Conference.html)
5. B. Amos and J. Z. Kolter, “OptNet: Differentiable Optimization as a Layer in
   Neural Networks,” *ICML*, 2017. [paper](https://proceedings.mlr.press/v70/amos17a.html)
6. A. Agrawal et al., “Differentiable Convex Optimization Layers,” *NeurIPS*, 2019.
   [paper](https://papers.neurips.cc/paper_files/paper/2019/hash/9ce3c52fc54362e22053399d3181c638-Abstract.html)
7. S. Gould et al., “On Differentiating Parameterized Argmin and Argmax Problems
   with Application to Bi-level Optimization,” 2016.
   [preprint](https://arxiv.org/abs/1607.05447)
8. B. Amos et al., “Differentiable MPC for End-to-end Planning and Control,”
   *NeurIPS*, 2018. [paper](https://papers.neurips.cc/paper_files/paper/2018/hash/ba6d843eb4251a4526ce65d1807a9309-Abstract.html)
9. L. F. Valenzuela et al., “Dynamic Locational Marginal Emissions via Implicit
   Differentiation,” *IEEE Transactions on Power Systems*.
   [doi:10.1109/TPWRS.2023.3247345](https://doi.org/10.1109/TPWRS.2023.3247345)
10. R. Mieth and H. V. Poor, “Prescribed Robustness in Optimal Power Flow,”
    *Electric Power Systems Research* 235, 110704, 2024.
    [doi:10.1016/j.epsr.2024.110704](https://doi.org/10.1016/j.epsr.2024.110704)
11. “Sensitivity Analysis of Power Flow Solution in Distribution Network Using
    Differentiable Convex Programming,” *NAPS*, 2025.
    [doi:10.1109/NAPS66256.2025.11272437](https://doi.org/10.1109/NAPS66256.2025.11272437)
12. S. Talkington et al., “Differentiating Through Power Flow Solutions for
    Admittance and Topology Control,” 2025.
    [preprint](https://arxiv.org/abs/2510.17071)
