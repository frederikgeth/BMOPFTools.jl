"""
    BMOPFOpfExt

Julia package extension that implements the four-wire rectangular current-voltage
(IVR-EN) optimal power flow for BMOPF networks. Loaded automatically when
`JuMP` is present in the calling environment. Ipopt is the default optimizer
when available; callers may pass another JuMP-compatible optimizer explicitly.

## Formulation

The data model is SI. By default the model is built in a per-unit working copy
(`per_unit=true`, see `per_unit.jl`) and results are converted back to SI; with
`per_unit=false` the same code builds the model directly in V, A, Ω, W.

Variables (all rectangular):
- `vr / vi`         — voltage at every bus terminal (grounded terminals are fixed to 0)
- `cr_gnd / ci_gnd` — free earth-injection current at each perfectly grounded terminal
- `cr_fr / ci_fr`   — series current of each line conductor, from → to (the one
                      independent series current per conductor)
- `cr_sw / ci_sw`   — switch current (fixed to zero when open)
- `crd / cid`       — load current (one per coil)
- `crg / cig`       — generator current (one per coil)
- `cri / cii`       — IBR current (one per coil / cyclic pair)
- `cr_src / ci_src` — voltage-source slack current (per phase; optionally bounded)
- `cr_xf / ci_xf`   — two-bus transformer winding current (from- and to-side)
- `cr_nw / ci_nw`   — n-winding transformer current (per winding, per phase leg)
- `tap`             — effective ratio of each transformer with a free tap
- DC-network voltages and currents, when the case declares a DC side

The to-side line series currents `cr_to = −cr_fr`, `ci_to = −ci_fr` are
`AffExpr`s, not variables. The total line current at each end (series +
π-shunt) is likewise an `AffExpr` in `cr_fr`/`ci_fr` and `vr`/`vi`, substituted
directly into KCL and the thermal limits.

KCL sign convention: positive current flows **into** the bus. Every component
builder adds its contribution to the accumulator dicts `(kcl_r, kcl_i)`;
`_enforce_kcl!` then pins `sum == 0` at **every** terminal. At a grounded
terminal the free earth-injection current makes that row a definition of the
current flowing to earth rather than a restriction.

## Build pipeline (solve_opf)

`solve_opf` → `_build_and_solve` runs these stages, each also available through
the public staged API (`build_opf_model`, `enforce_kcl!`, `optimize_opf!`,
`extract_result`):

1. `_prepare_working_net`        — copy, snapshot, normalize, per-unit scale
2. `_new_context`                — index terminals, declare variables, allocate KCL
3. `set_opf_start_values!`       — level-aware nominal start, network-wide phasor
                                   transport solve, Yd/Dy current seeds
4. `add_opf_operational_limits!` — bus voltage, angle, sequence, and unbalance limits
5. `add_opf_device_constraints!` — sources, lines, switches, transformers, shunts,
                                   capacitors, loads, generators, IBRs, DC network,
                                   earth injections; each adds its KCL contribution
6. `set_opf_objective!`          — generation-cost rate (`generation_cost`)
7. `model_hook!` (optional)      — caller's constraints, objective, or injections
8. `_enforce_kcl!`               — nodal balance at every terminal, AC and DC
9. `JuMP.optimize!`, `_extract_results`, `_from_per_unit` — solve and report in SI

`solve_pf` (`pf.jl`) omits stage 4 and the objective, strips operational limits
other than transformer nameplates, and requires determined devices.
`solve_feasibility_opf` (`feasibility_opf.jl`) keeps stage 4, adds elastic KCL
slack currents, and minimizes their squared magnitude in amperes.

## File layout

| File                 | Contents                                                        |
|----------------------|-----------------------------------------------------------------|
| `data_utils.jl`      | Network indexing, magnitude-limit helpers, cones, angle windows |
| `control_curves.jl`  | Piecewise-linear droop curves and the smooth ReLU operators      |
| `variables.jl`       | Variable declarations and start-value initialization             |
| `bus.jl`             | Bus voltage/angle/sequence limits, KCL accumulators             |
| `shunt.jl`           | Standalone shunt admittances                                     |
| `capacitor.jl`       | Fixed capacitor banks                                            |
| `branch.jl`          | Line π model, thermal/apparent-power/angle limits; switches      |
| `transformer.jl`     | Two-bus transformers: YY, center-tap, Yd/Dy, regulators          |
| `nwinding.jl`        | General n-winding transformer (ZB model)                         |
| `load.jl`            | Constant-power, ZIP, and exponential loads (WYE/DELTA)          |
| `generator.jl`       | Generator P/Q boxes and current/apparent-power limits            |
| `source.jl`          | Voltage-source voltage fixing, slack current, P/Q bounds         |
| `ibr.jl`             | Inverter-based resources and their control laws                  |
| `dcnetwork.jl`       | DC buses, branches, loads, sources, converter coupling           |
| `objective.jl`       | Linear-in-power generation-cost-rate objective                   |
| `objectives.jl`      | Composable objective terms (losses, unbalance, control effort)   |
| `results.jl`         | Solution extraction to `Dict{String,Any}`                        |
| `profile.jl`         | Optimization profile of a solved model                           |
| `per_unit.jl`        | Per-unit bases, scaling, and conversion of results back to SI    |
| `core.jl`            | `OpfContext`, staged build API, registries, warm starts          |
| `feasibility_opf.jl` | Elastic KCL-slack diagnostic formulation                         |
| `pf.jl`              | Determined power flow                                            |
| `opti_kron.jl`       | Opti-KRON network-reduction models                               |
"""
module BMOPFOpfExt

using BMOPFTools
using JuMP
using LinearAlgebra
using SparseArrays
using SHA
using StatsFuns: log1pexp, logistic

# Look up a currently loaded module by package name, without taking a hard
# dependency on it. Used to report solver-package versions in provenance and to
# find Ipopt for the default-optimizer fallback.
function _loaded_module(name::AbstractString)
    for (pkgid, mod) in Base.loaded_modules
        pkgid.name == name && return mod
    end
    return nothing
end

_ipopt_module() = _loaded_module("Ipopt")

include("data_utils.jl")
include("control_curves.jl")
include("variables.jl")
include("bus.jl")
include("shunt.jl")
include("capacitor.jl")
include("branch.jl")
include("transformer.jl")
include("nwinding.jl")
include("load.jl")
include("generator.jl")
include("source.jl")
include("ibr.jl")
include("dcnetwork.jl")
include("objective.jl")
include("results.jl")
include("profile.jl")
include("per_unit.jl")
include("core.jl")
include("objectives.jl")   # needs OpfContext from core.jl
include("feasibility_opf.jl")
include("pf.jl")
include("opti_kron.jl")

function _default_optimizer()
    ipopt = _ipopt_module()
    ipopt !== nothing && return getfield(ipopt, :Optimizer)
    throw(ArgumentError(
        "No default OPF optimizer is available because Ipopt is not loaded. " *
        "Pass an explicit JuMP optimizer, for example `optimizer=Gurobi.Optimizer`."))
end

"""
    BMOPFTools.solve_opf(net; optimizer=_default_optimizer(), t_index=1,
        per_unit=true, s_base=1e6, scaling_policy=nothing,
        volt_var_watt_eps=2e-3, softplus=:user_defined,
        build_spec=OpfBuildSpec(), verbose=false, solver_options=(),
        model_hook!=nothing, solution_hook!=nothing) -> Dict

Four-wire rectangular current-voltage (IVR-EN) OPF on a BMOPF network dict.
Minimizes the generation-cost rate subject to the network physics and every
operational limit the case declares. Returns a result dictionary in SI units.

The input is copied (and time-series data snapshotted at `t_index`), then
normalized through the same ingest operations as `parse_bmopf` before unit
conversion. This includes legacy field migration, terminal roles, combined
Yd/Dy leakage, and explicit `no_load_shunt` materialization. Competing
electrical representations raise an `ArgumentError`; the caller's dictionary is
not mutated. Already normalized input is accepted without duplicating shunts or
migration records.

# Keywords
- `per_unit`, `s_base`, `scaling_policy` — working coordinates. The default
  builds the model in per-unit on `s_base` with one voltage base per galvanic
  zone; `per_unit=false` builds it in SI. An explicit `scaling_policy`
  (`OpfScaling`) takes precedence over both.
- `volt_var_watt_eps`, `softplus` — relative smoothing width and implementation
  (`:user_defined`, `:builtin`, `:swish`) of Volt-var/Volt-watt and DC droop curves.
- `build_spec` — custom device builders and coefficient providers.
- `verbose`, `solver_options` — solver log and raw solver attributes
  (`name => value` pairs, applied last).
- `model_hook!(ctx)` — called after the standard model is built and before KCL
  is enforced; `solution_hook!(ctx, result)` — called after the solve, before
  results are converted to SI.

# Formulation
- Voltage variables `vr`/`vi` at every bus terminal, neutral included. A neutral
  floats unless it is listed in `perfectly_grounded_terminals` or sits on a
  voltage-source bus, whose neutral is solidly grounded.
- One series current per line conductor (the to-end current is its negative);
  total end currents add the linecode's π-shunt halves. Thermal limits `i_max`
  apply to the total current at both ends; `s_max` and line angle windows
  (phase conductors only) are optional.
- Loads: constant power, constant current, constant impedance, ZIP, and
  exponential, in WYE, DELTA, or two-terminal SINGLE_PHASE connection.
- Generators and inverter-based resources with P/Q boxes, current and
  apparent-power limits; IBRs additionally support constant power factor,
  Volt-var, Volt-watt, a shared DC link, and a DC network side.
- Transformers: `single_phase` (per-phase YY), `center_tap`, `wye_delta`,
  `delta_wye`, `single_phase_autotransformer`, `open_delta_regulator`, and
  general `n_winding`, with optional continuous tap optimization on the
  two-bus subtypes.
- Standalone shunts and fixed capacitor banks, linear in the voltages.
- A wye-connected device whose terminal map has no neutral is referenced to
  earth (a solidly grounded star).

See the OPF reference (`docs/src/opf.md`) for the equations.
"""
function BMOPFTools.solve_opf(net::Dict{String,Any};
                               optimizer=_default_optimizer(),
                               t_index::Int=1,
                               per_unit::Bool=true,
                               s_base::Float64=1e6,
                               scaling_policy::Union{
                                   BMOPFTools.AbstractOpfScalingPolicy,Nothing}=nothing,
                               volt_var_watt_eps::Float64=2e-3,
                               softplus::Symbol=:user_defined,
                               build_spec::BMOPFTools.OpfBuildSpec=BMOPFTools.OpfBuildSpec(),
                               verbose::Bool=false,
                               solver_options=(),
                               model_hook!::Union{Function,Nothing}=nothing,
                               solution_hook!::Union{Function,Nothing}=nothing)
    _build_and_solve(net; optimizer=optimizer, t_index=t_index,
                     per_unit=per_unit, s_base=s_base, scaling_policy,
                     problem=:opf,
                     build_spec=build_spec,
                     build! = build_opf!,
                     relu_eps=volt_var_watt_eps,
                     softplus=softplus,
                     verbose, solver_options, model_hook!, solution_hook!)
end

"""
    build_opf!(ctx; add_objective=true)

Build recipe for the standard generation-cost OPF. With `add_objective=false`
the device model and bounds are built but the generation-cost objective is *not*
set on the model — used by the public `build_opf_model` when a caller (e.g. a
multi-period wrapper) will assemble and set a combined objective itself. The
per-recipe cost is still recoverable via `generation_cost(ctx)`.
"""
function build_opf!(ctx::OpfContext; add_objective::Bool=true)
    # Warm-start: set phase-angle-correct initial values so Ipopt can find
    # the physical (high-voltage) solution without a load-flow pre-solve.
    BMOPFTools.set_opf_start_values!(ctx)

    # Hard operational voltage and bus-limit bounds.
    BMOPFTools.add_opf_operational_limits!(ctx)

    # Source + all device constraints and their KCL contributions.
    BMOPFTools.add_opf_device_constraints!(ctx)

    # Objective: minimize total generation cost.
    add_objective && BMOPFTools.set_opf_objective!(ctx)
end

end # module BMOPFOpfExt
