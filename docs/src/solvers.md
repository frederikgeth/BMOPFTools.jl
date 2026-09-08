# Solver guide for OPF

BMOPFTools builds one four-wire rectangular current–voltage (IVR-EN) OPF
model through JuMP. The solver is selected at the boundary: pass a JuMP
optimizer to [`solve_opf`](@ref), [`solve_pf`](@ref), or
[`solve_feasibility_opf`](@ref). Changing the solver does not change the
network physics, objective, units, or result schema; it changes how the
mathematical program is searched and what solver status is reported.

This page covers the three solver paths currently supported and tested with
the engine:

| Solver | Julia package | Best first use | Important qualification |
|:--|:--|:--|:--|
| Ipopt | [`Ipopt.jl`](https://github.com/jump-dev/Ipopt.jl) | The reference solve and the broadest nonlinear model coverage | Local nonlinear optimization; a successful solve is a local result. |
| MadNLP | [`MadNLP.jl`](https://github.com/MadNLP/MadNLP.jl) | An alternative local NLP implementation, especially when experimenting with sparse linear algebra or accelerator-backed extensions | Local nonlinear optimization; solver options and defaults differ from Ipopt. |
| Gurobi | [`Gurobi.jl`](https://github.com/jump-dev/Gurobi.jl) | Cross-checks and workflows that need Gurobi, for the quadratic-compatible IVR-EN subset | Commercial software and license required; not every BMOPFTools nonlinear feature is Gurobi-compatible. |

Ipopt and MadNLP are local nonlinear-programming solvers in the same broad
family of interior-point methods. Gurobi should be thought of here as the
quadratic/nonconvex path through the engine: it is useful for the part of the
IVR-EN model that JuMP can represent as affine and quadratic expressions, but
it is not a drop-in replacement for every smooth nonlinear load or control
curve.

The [JuMP models guide](https://jump.dev/JuMP.jl/stable/manual/models/) is a
useful introduction to optimizer objects and solver attributes. The
[PowerModels installation guide](https://lanl-ansi.github.io/PowerModels.jl/stable/)
uses the same practical convention: identify the formulation, install a
compatible optimizer, and make solver settings explicit when comparing runs.

## Install the solvers

Install JuMP and whichever solver packages you intend to use in the same Julia
environment as BMOPFTools. None of the solvers is a hard dependency — add only
the ones you need:

```julia
using Pkg
Pkg.add(["JuMP", "Ipopt"])   # add "MadNLP" and/or "Gurobi" as needed
```

Gurobi.jl also needs a usable Gurobi installation/license. The Julia package
and a license are separate concerns; see the
[Gurobi.jl installation notes](https://github.com/jump-dev/Gurobi.jl#installation)
and the [Gurobi license documentation](https://www.gurobi.com/solutions/licensing/).

!!! note "Gurobi is not a test dependency"
    Because Gurobi is commercial and license-gated, it is deliberately absent
    from `test/Project.toml`. The suite detects it at load time and skips
    `test/gurobi_engine_tests.jl` when the package is missing, fails to load,
    or has no usable license, so a Gurobi-free checkout runs green. To exercise
    that coverage, add Gurobi to the test environment yourself:

    ```julia
    using Pkg
    Pkg.activate("test")
    Pkg.add("Gurobi")
    ```

Load the solver package whose optimizer you pass:

```julia
using BMOPFTools, JuMP, Ipopt
# or: using BMOPFTools, JuMP, MadNLP
# or: using BMOPFTools, JuMP, Gurobi
```

Loading JuMP activates BMOPFTools' OPF extension. Ipopt is the default when
`Ipopt` is loaded, but an explicit optimizer is preferable in scripts and
papers because it records the intended solver and makes a solver comparison
reproducible.

## The common pattern

Assume `net` is a BMOPF network dictionary, for example one returned by
`from_dss` and prepared with the workflow in the
[end-to-end tutorial](tutorial_end_to_end.md). The shortest form is:

```julia
result = solve_opf(net; optimizer = Ipopt.Optimizer)
```

For a controlled run, create an optimizer with attributes and pass it to the
engine:

```julia
opt = optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol" => 1e-8,
    "max_iter" => 3000,
    "print_level" => 0,
)
result = solve_opf(net; optimizer = opt, per_unit = true)
```

You can instead pass raw solver attributes through BMOPFTools:

```julia
result = solve_opf(net;
    optimizer = Ipopt.Optimizer,
    solver_options = ["tol" => 1e-8, "max_iter" => 3000],
)
```

`solver_options` is an iterable of `name => value` pairs. The engine applies
these settings after its own defaults, so user-supplied values win at the point
they are set. Attribute names are solver-specific: `OutputFlag` is a Gurobi
parameter, while `print_level` is an Ipopt or MadNLP option. Do not assume that
an option with a similar name has the same meaning across solvers.

One caveat: `verbose = false` (the default) calls `JuMP.set_silent`, and a
solver is free to act on that later than the raw attributes you pass. MadNLP,
for instance, overwrites `print_level` with `MadNLP.ERROR` inside `optimize!`
whenever the model is silent, so a `print_level` in `solver_options` only takes
effect under `verbose = true`.

Inspect the result and validate the physical solution rather than relying on a
status string alone:

```julia
println(result["termination_status"])
println(result["objective"])

validation = profile_solution(net, result)
render_solution(validation, stdout)
```

Ipopt and MadNLP commonly report `"LOCALLY_SOLVED"`; Gurobi may report
`"OPTIMAL"` for a supported quadratic model. These statuses are not
interchangeable claims about global optimality. Read the solver status together
with residuals, bounds, and the independent checks in
[Validating the OPF](validation.md).

## Ipopt: the reference local NLP solve

[Ipopt](https://coin-or.github.io/Ipopt/) is the default reference solver for
BMOPFTools. It has the broadest coverage of the engine's smooth nonlinear
features, including voltage-dependent load laws and smoothed control curves.
It is a local solver, so a successful result is a locally optimal or locally
stationary solution of the nonconvex OPF, not a proof that no better feasible
point exists.

### Basic Ipopt example

```julia
using BMOPFTools, JuMP, Ipopt

const IPOPT_OPT = optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol" => 1e-8,
    "max_iter" => 3000,
    "print_level" => 0,
)

result = solve_opf(net; optimizer = IPOPT_OPT)
```

The library supplies phase-aware voltage starts and defaults to per-unit
coordinates. Those two choices are usually more important than immediately
tightening a tolerance.

### Ipopt settings worth experimenting with

- `tol` controls the requested KKT accuracy. Try `1e-6`, `1e-8`, and `1e-10`
  only after checking the physical residuals; a smaller number is not always a
  better-conditioned solve.
- `max_iter` is useful when a difficult case is making progress but needs more
  interior-point iterations. A time limit or external job timeout may still be
  more appropriate for batch studies.
- `linear_solver` can have a large effect on runtime and robustness. MUMPS is
  the common default in Ipopt.jl; an appropriately installed HSL solver can be
  worth testing on larger sparse cases. The linear solver is an algorithmic
  choice, not a change to the OPF.
- `bound_relax_factor` is useful for a diagnostic comparison. Setting it to
  `0.0` makes the solver respect declared bounds without its initial relaxation,
  but may make a difficult boundary solve less forgiving.
- `acceptable_tol` can allow early termination at a looser KKT residual. Use it
  deliberately: for feasibility checks and published comparisons, inspect the
  final residuals and consider requiring the regular `tol` instead.

For example, to expose the Ipopt log while investigating convergence:

```julia
result = solve_opf(net;
    optimizer = Ipopt.Optimizer,
    verbose = true,
    solver_options = ["tol" => 1e-8, "max_iter" => 5000],
)
```

`verbose=true` lets solver output through. It is independent of the numeric
settings, so use `"print_level" => 0` when you want a quiet, reproducible run.

## MadNLP: an alternative local NLP solver

[MadNLP](https://madsuite.org/MadNLP.jl/) is another interior-point local NLP
solver with a JuMP interface. It is a useful independent implementation for
solver parity checks and for experiments with alternative sparse linear
solvers; the MadNLP ecosystem also provides extensions for selected HSL,
Pardiso, and GPU-backed configurations.

### Basic MadNLP example

```julia
using BMOPFTools, JuMP, MadNLP

const MADNLP_OPT = optimizer_with_attributes(
    MadNLP.Optimizer,
    "tol" => 1e-8,
    "max_iter" => 3000,
    "print_level" => MadNLP.ERROR,
)

result = solve_opf(net; optimizer = MADNLP_OPT)
```

!!! warning "`print_level` does not mean the same thing to Ipopt and MadNLP"
    Ipopt's `print_level` is an integer from `0` (silent) to `12`. MadNLP's is
    a `MadNLP.LogLevels` enum running `TRACE` (1) through `ERROR` (6), with no
    level `0` — passing `0` throws
    `ArgumentError: invalid value for Enum LogLevels: 0` at solve time. Use
    `MadNLP.ERROR` for the quietest MadNLP log.

The same call can be written with `solver_options`:

```julia
result = solve_opf(net;
    optimizer = MadNLP.Optimizer,
    solver_options = ["tol" => 1e-9, "bound_relax_factor" => 0.0],
)
```

### MadNLP settings worth experimenting with

- `linear_solver` chooses the KKT linear algebra backend. The default is
  `MadNLP.MumpsSolver`; on a suitable installation, comparing it with another
  supported backend can be more informative than changing the nonlinear
  tolerance.
- `tol`, `max_iter`, `acceptable_tol`, and `bound_relax_factor` play roles
  similar to their Ipopt counterparts, but the defaults and implementation are
  not identical. Compare physical residuals and iteration counts, not just
  wall time.
- `hessian_approximation` can be useful when exact second derivatives are
  expensive or numerically fragile. MadNLP's exact-Hessian path is the natural
  starting point; quasi-Newton choices are an experiment, not a universally
  safer default.
- `jacobian_constant` and `hessian_constant` are performance hints. Set them
  only when the corresponding derivatives really are constant; they are not
  generic convergence switches and should not be enabled for a changing
  parameterized model without checking the formulation.
- `nlp_scaling` controls MadNLP's nonlinear-program scaling. Compare it with
  BMOPFTools' own `per_unit=true` coordinate choice rather than treating the
  two scaling layers as substitutes.

The authoritative option names and supported linear-solver types are in the
[MadNLP options reference](https://madsuite.org/MadNLP.jl/stable/options/).

## Gurobi: the quadratic-compatible local-NLP path

[Gurobi](https://www.gurobi.com/) is a commercial optimizer exposed to JuMP by
[Gurobi.jl](https://github.com/jump-dev/Gurobi.jl). In BMOPFTools it is
appropriate for the quadratic-compatible IVR-EN subset: constant
power/current/impedance models and other features that leave the generated
JuMP model affine or quadratic. Voltage-dependent exponential laws should
remain on Ipopt or MadNLP unless you have separately verified that your exact
formulation is supported by your Gurobi version. Smooth piecewise-linear
control curves (IBR Volt-var / Volt-watt) *are* supported, but only under the
encoding described next.

!!! warning "Volt-var / Volt-watt on Gurobi requires `softplus=:swish`"
    The engine smooths each control-curve kink with a smooth-ReLU surrogate,
    and Gurobi's nonlinear interface accepts only a fixed opcode set. Of the
    three available encodings, exactly one lands inside it:

    | `softplus` | Emits | On Gurobi |
    |:--|:--|:--|
    | `:user_defined` (default) | `MOI.UserDefinedFunction` | rejected — `MOI.UnsupportedAttribute` |
    | `:builtin` | `log1p(exp(⋅))` | rejected — `:log1p` is not a Gurobi opcode |
    | `:swish` | `z · logistic(z / ε)` | accepted — maps to `GRB_OPCODE_LOGISTIC` |

    So a case carrying a Volt-var or Volt-watt profile must select the
    encoding explicitly, or the solve fails at `optimize!`:

    ```julia
    result = solve_opf(net;
        optimizer = Gurobi.Optimizer,
        softplus = :swish,
        solver_options = ["NonConvex" => 2, "OutputFlag" => 0],
    )
    ```

    Gurobi's nonlinear support needs **Gurobi 12.0 or newer**; older libraries
    expose no nonlinear opcodes at all. Swish is a genuinely different
    surrogate, not a re-implementation of softplus — it is non-monotone and
    non-convex near each hinge, so validate the resulting droop curve against
    the exact characteristic. See
    [ReLU/softplus encoding](relu_softplus_encoding.md) for the error analysis.

    Cases with no control profile are unaffected: `softplus` only matters once
    a curve is actually smoothed.

The engine's quadratic OPF constraints are generally nonconvex. Set Gurobi's
`NonConvex` parameter explicitly:

```julia
using BMOPFTools, JuMP, Gurobi

const GUROBI_OPT = optimizer_with_attributes(
    Gurobi.Optimizer,
    "NonConvex" => 2,
    "OutputFlag" => 0,
)

result = solve_opf(net; optimizer = GUROBI_OPT)
```

The equivalent BMOPFTools form is:

```julia
result = solve_opf(net;
    optimizer = Gurobi.Optimizer,
    solver_options = ["NonConvex" => 2, "OutputFlag" => 0],
)
```

`NonConvex=2` tells Gurobi to accept and solve nonconvex quadratic structure;
without it, a model containing the engine's nonconvex quadratic constraints
may be rejected. Gurobi's treatment of a nonconvex quadratic model is not the
same algorithm as Ipopt or MadNLP, so compare the returned point and
independent residuals as well as the objective.

### Gurobi settings worth experimenting with

- `OutputFlag` controls Gurobi logging. Keep it at `0` in batch runs and use
  `verbose=true` plus `OutputFlag=1` while diagnosing the solve.
- `TimeLimit` is useful for bounded batch jobs. Always record whether the
  result stopped due to a time limit and whether a feasible point was returned.
- `FeasibilityTol` and `OptimalityTol` affect numerical acceptance. They are
  absolute solver tolerances, so interpret them in the model's working
  coordinates and validate the final SI result.
- `NumericFocus` asks Gurobi to spend more effort on numerical reliability.
  It can help diagnose scaling-sensitive cases, but per-unit modeling should
  be tested first.
- `Threads` and `Presolve` are useful controlled performance experiments. Fix
  them when comparing solver timings across machines or solver versions.

Gurobi environments and licenses deserve one additional caution. If many
models are solved in one process, a shared `Gurobi.Env()` can avoid acquiring
a new license token for every model, but Gurobi environments are not
thread-safe. Do not solve models concurrently through the same environment;
see the [Gurobi.jl environment guidance](https://github.com/jump-dev/Gurobi.jl#reusing-the-same-gurobi-environment-for-multiple-solves).

## Settings that apply to all three solvers

### Start with the model coordinates

`per_unit=true` is the default and is usually the first conditioning experiment
to keep. Use `per_unit=false` when you specifically need a raw-SI comparison,
not as a general way to improve a solve. For controlled coordinate experiments,
use [`OpfScaling`](@ref) and record the resulting diagnostic metadata.

```julia
pu = solve_opf(net; optimizer = Ipopt.Optimizer, per_unit = true)
si = solve_opf(net; optimizer = Ipopt.Optimizer, per_unit = false)
```

The two runs should represent the same physical problem. If they produce
meaningfully different physical results, inspect conditioning, bounds, solver
termination, and residuals before tuning solver parameters.

### Use tolerances as an experiment, not a substitute for validation

The engine applies solver options after its own defaults, but it cannot make a
solver-specific option portable, and it cannot stop a solver from revisiting an
option during `optimize!` (see the `set_silent` caveat above). A useful
comparison fixes the case, objective, coordinate system, and stopping policy,
then changes one solver or one solver setting at a time:

```julia
configs = [
    ("ipopt", Ipopt.Optimizer, ["tol" => 1e-8]),
    ("madnlp", MadNLP.Optimizer, ["tol" => 1e-8]),
]

for (name, optimizer, options) in configs
    result = solve_opf(net; optimizer, solver_options = options)
    println(name, ": ", result["termination_status"])
end
```

Do not mix solver-specific options in a portable configuration object unless
you filter them by solver. For example, `print_level` is meaningful to Ipopt
and MadNLP, while Gurobi uses `OutputFlag`.

### A practical solver-selection workflow

1. Start with Ipopt in per-unit coordinates and validate the solution.
2. Run MadNLP on the same case when you want an independent local-NLP result
   or want to investigate linear-solver performance.
3. Try Gurobi when the model is in the quadratic-compatible subset and a
   Gurobi solve is useful as a cross-check or part of your deployment stack.
4. Compare objective, termination status, physical residuals, bound activity,
   and runtime. Keep the solver name, package versions, options, coordinate
   system, and result validation with the benchmark record.

For a full discussion of what the engine does and does not model, see the
[OPF engine scope and status](dev/opf_engine.md) page. For the result fields and
status conventions, see [OPF result dictionary](results.md).
