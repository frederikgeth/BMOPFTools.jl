"""
    BMOPFOpfExt

Julia package extension that implements the four-wire rectangular current-voltage
(IVR-EN) optimal power flow for BMOPF networks.  Loaded automatically when both
`JuMP` and `Ipopt` are present in the calling environment.

## Formulation

Variables (all rectangular, SI units — V and A):
- `vr / vi`       — real/imaginary voltage at every bus terminal
- `cr_fr / ci_fr` — series current in each line, from-terminal direction (independent variable)
- `crd / cid`     — load current (one per phase conductor)
- `crg / cig`     — generator current (one per phase conductor)
- `cr_src/ci_src` — voltage-source slack current (per phase; in KCL, optionally bounded)
- `cr_xf / ci_xf` — transformer branch current (from- and to-side)
- `cr_nw / ci_nw` — n-winding transformer current (per winding, per phase)
- `cr_sw / ci_sw` — switch current (zeroed when open)

The to-side series currents `cr_to = −cr_fr` and `ci_to = −ci_fr` are
`AffExpr`s, not variables. The total branch current at each end
(series + π-shunt) is likewise an `AffExpr` in `cr_fr`/`ci_fr` and
`vr`/`vi`, substituted directly into KCL and thermal limits.

KCL sign convention: positive current flows **into** the bus.  Every component
function adds its contribution to the KCL accumulator dicts `(kcl_r, kcl_i)`;
`_add_kcl_constraints!` then enforces `sum == 0` at every ungrounded terminal.

## Build pipeline (solve_opf / solve_feasibility_opf)

1. `_bus_terminals` / `_grounded_terminals`  — index network topology
2. `_build_vars`                             — declare all JuMP variables
3. `_set_voltage_start_values!`              — warm-start Ipopt
4. `_add_voltage_bounds!`                    — operational V limits (solve_opf only)
5. `_add_source_constraints!`                — fix slack-bus voltages + inject slack current (KCL)
6. `_add_line/switch/transformer_constraints!` — KVL + KCL contributions
7. `_add_load/generator_constraints!`        — constant-power equations + KCL
8. `_add_kcl_constraints!`                   — enforce KCL == 0 at every node
9. `_add_objective!` / slack objective       — set JuMP objective
10. `_extract_results`                       — pack solution into plain Dict

## File layout

| File                | Contents                                          |
|---------------------|---------------------------------------------------|
| `data_utils.jl`     | Network indexing helpers (`_bus_terminals`, etc.) |
| `variables.jl`      | JuMP variable declarations and start-value init   |
| `bus.jl`            | Voltage bounds, KCL accumulators, `_kcl_add!`     |
| `branch.jl`         | Line KVL/current-balance; switch voltage-coupling |
| `transformer.jl`    | YY, Dy, Yd transformer voltage + current coupling |
| `load.jl`           | Constant-power load constraints (WYE / DELTA)     |
| `generator.jl`      | Generator P/Q bounds                              |
| `source.jl`         | Voltage-source voltage fixing + slack current/bounds |
| `objective.jl`      | Generation-cost objective (linear + quadratic)    |
| `results.jl`        | Solution extraction to `Dict{String,Any}`         |
| `feasibility_opf.jl`| Elastic KCL-slack formulation (always feasible)   |
"""
module BMOPFOpfExt

using BMOPFTools
using JuMP
using Ipopt
using StatsFuns: log1pexp, logistic

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
include("per_unit.jl")
include("core.jl")
include("feasibility_opf.jl")
include("pf.jl")

"""
    BMOPFTools.solve_opf(net; optimizer=Ipopt.Optimizer, t_index=1) -> Dict

Four-wire rectangular current-voltage (IVR-EN) OPF on a BMOPF network dict.

The formulation follows the PMD IVRENPowerModel convention:
- Voltage variables vr/vi at every bus terminal including neutral.
- Series current variables cr/ci per conductor at each branch end.
- Constant-power load and generator models (bilinear P/Q equations).
- Neutral terminal voltages are explicit JuMP variables; they float unless
  declared in `perfectly_grounded_terminals` or fixed by a voltage source.
- Transformer models: per-phase YY (single_phase/center_tap) and
  wye-delta / delta-wye with linear voltage-current transformation.
- Shunt admittances: standalone `shunt` objects and the π-model half-sections
  (`G_from/to`, `B_from/to`) of line linecodes. Shunt currents are linear in
  voltage variables (no new variables). Thermal current limits are enforced on
  the total (series + shunt) current at both line ends.
"""
function BMOPFTools.solve_opf(net::Dict{String,Any};
                               optimizer=Ipopt.Optimizer,
                               t_index::Int=1,
                               per_unit::Bool=false,
                               s_base::Float64=1e6,
                               volt_var_watt_eps::Float64=2e-3,
                               verbose::Bool=false,
                               solver_options=(),
                               model_hook!::Union{Function,Nothing}=nothing)
    _build_and_solve(net; optimizer=optimizer, t_index=t_index,
                     per_unit=per_unit, s_base=s_base, build! = build_opf!,
                     relu_eps=volt_var_watt_eps,
                     verbose, solver_options, model_hook!)
end

"""
    build_opf!(ctx)

Build recipe for the standard generation-cost OPF.
"""
function build_opf!(ctx::OpfContext)
    # Warm-start: set phase-angle-correct initial values so Ipopt can find
    # the physical (high-voltage) solution without a load-flow pre-solve.
    _set_voltage_start_values!(ctx.vars, ctx.net, ctx.bus_terminals, ctx.grounded)

    # Hard operational voltage and bus-limit bounds.
    _add_voltage_and_bus_bounds!(ctx)

    # Source + all device constraints and their KCL contributions.
    _add_device_constraints!(ctx)

    # Objective: minimise total generation cost.
    _add_objective!(ctx.model, ctx.net, ctx.vars)
end

end # module BMOPFOpfExt
