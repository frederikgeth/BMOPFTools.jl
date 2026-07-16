# Generic build/solve engine shared by every problem formulation.
#
# Each problem (OPF, feasibility OPF, and future power-flow / state-estimation
# variants) is expressed as a small *build recipe* — a function that declares
# which start values, bounds, device constraints, slacks, and objective to add.
# `_build_and_solve` owns the invariant pipeline around those recipes:
#
#   1. snapshot / per-unit the network
#   2. build the JuMP model + index structures + variables
#   3. initialise the KCL accumulators
#   4. run the problem's `build!(ctx)` recipe        ← the only part that varies
#   5. enforce KCL and optimize
#   6. extract the standard result dict
#   7. run the problem's optional `extract!(ctx, result)` hook for extra keys
#   8. unwrap per-unit
#
# This mirrors the PowerModels/InfrastructureModels pattern where a generic
# `solve_model(data, type, optimizer, build_method)` core is parameterised by a
# per-problem `build_*` function.

"""
    OpfContext

Bundle of everything a build recipe needs, threaded through the device-constraint
helpers in place of the previous 7 positional arguments. Field names match the
local variables the helpers already expect.

- `model`         — the JuMP model
- `net`           — the working network dict (snapshot + per-unit applied)
- `bus_terminals` — `Dict{String,Vector{String}}` bus → ordered terminals
- `grounded`      — `Set{Tuple{String,String}}` perfectly-grounded (bus, terminal)
- `vars`          — variable dict returned by `_build_vars`
- `kcl_r`/`kcl_i` — per-terminal KCL accumulator expressions
- `branch_inj`    — per two-port-device injection ledger (see `_new_branch_ledger`),
  populated as side effect of `_kcl_add!` so element complex losses can be
  computed exactly from terminal powers: `branch_inj[block][id]` is a vector of
  `(bus, terminal, cr_expr, ci_expr)`, each the current the element injects INTO
  that bus terminal (KCL "into bus" sign). The element's complex loss is then
  `S_loss = Σ V·conj(I_into_element) = −Σ V·conj(I_into_bus)`.
"""
struct OpfContext
    model
    net::Dict{String,Any}
    bus_terminals::Dict{String,Vector{String}}
    grounded::Set{Tuple{String,String}}
    vars::Dict
    kcl_r::Dict
    kcl_i::Dict
    branch_inj::Dict{String,Any}
    # Per-unit bases (`nothing` when the model is built in SI units), used by the
    # IBR Volt-var/Volt-watt droop to scale SI breakpoint voltages into model
    # units. `relu_eps` is the relative smoothing for the smooth-ReLU droop and
    # `relu_ops` caches the registered operators by (model-unit) ε.
    #
    # `bases` also lets a `model_hook!` author express physical-unit constraints:
    # by default `per_unit=true`, so `ctx.model`'s variables (voltages, currents,
    # powers) are per-unit and any watt/volt/amp literal in a hook must be divided
    # by the matching base. When present, `bases` is a NamedTuple carrying
    # `s_base` (VA), per-bus `v_base`/`i_base`/`z_base`/`y_base` Dicts, and the DC
    # `v_dc_base`/`i_dc_base`/`z_dc_base`; e.g. a watt cap becomes
    # `expr <= P_watts / ctx.bases.s_base`. In SI mode `bases === nothing` and the
    # literal is used as-is (divide by 1.0).
    bases
    relu_eps::Float64
    relu_ops::Dict{Float64,Any}
end

# Fresh per-device injection ledger. Keyed block ("line"/"switch"/"transformer")
# → device id → Vector of (bus, terminal, cr_expr, ci_expr) injected into bus.
_new_branch_ledger() = Dict{String,Any}(
    "line" => Dict{String,Any}(),
    "switch" => Dict{String,Any}(),
    "transformer" => Dict{String,Any}())

# Record one terminal injection for a two-port device into the ledger. `entry`
# is the (block, id) pair identifying the device; nothing disables recording.
function _ledger_add!(branch_inj, entry, bus, terminal, cr_expr, ci_expr)
    branch_inj === nothing && return
    entry === nothing && return
    block, id = entry
    dev = get!(get!(branch_inj, block, Dict{String,Any}()), id, Vector{Any}())
    push!(dev, (bus, terminal, cr_expr, ci_expr))
    return
end

"""
    _add_device_constraints!(ctx)

Add the constraints shared by *every* problem formulation: the voltage source,
all branch/transformer/shunt couplings, and the load/generator/IBR power
equations, each contributing to the KCL accumulators. Voltage and bus-limit
bounds are NOT added here — a build recipe adds them explicitly so that an
unbounded formulation (e.g. power flow) can omit them.
"""
function _add_device_constraints!(ctx::OpfContext)
    model = ctx.model; net = ctx.net; vars = ctx.vars
    kcl_r = ctx.kcl_r; kcl_i = ctx.kcl_i

    branch_inj = ctx.branch_inj
    # Reject parallel zero-impedance branches (undetermined current split) before
    # stamping any branch constraints.
    _assert_no_parallel_zero_impedance(net)
    _add_source_constraints!(model, net, vars, kcl_r, kcl_i)
    _add_line_constraints!(model, net, vars, kcl_r, kcl_i;
                           grounded=ctx.grounded, branch_inj=branch_inj)
    _add_line_angle_constraints!(model, net, vars)
    _add_switch_constraints!(model, net, vars, kcl_r, kcl_i)
    _add_transformer_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=branch_inj)
    _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=branch_inj)
    _add_shunt_constraints!(net, vars, kcl_r, kcl_i)
    _add_capacitor_constraints!(net, vars, kcl_r, kcl_i)
    _add_load_constraints!(model, net, vars, kcl_r, kcl_i)
    _add_generator_constraints!(model, net, vars, kcl_r, kcl_i)
    # DC network (branches/grounding/loads/sources) must populate the DC KCL
    # accumulator before the IBR builder adds converter DC-port injections.
    _add_dc_network_constraints!(model, net, vars)
    _add_ibr_constraints!(model, net, vars, kcl_r, kcl_i;
                               bases=ctx.bases, relu_eps=ctx.relu_eps,
                               relu_ops=ctx.relu_ops)
    _add_ground_injections!(vars, kcl_r, kcl_i, ctx.grounded)
end

"""
    _add_ground_injections!(vars, kcl_r, kcl_i, grounded)

Inject the free ground current `cr_gnd`/`ci_gnd` into the KCL accumulator at every
perfectly grounded terminal (current flowing from earth into the node). The
terminal voltage is fixed to 0; this current is what the solid ground sinks or
sources, giving KCL the degree of freedom to balance the branch currents arriving
at a grounded node — the physical earth-return path.
"""
function _add_ground_injections!(vars, kcl_r, kcl_i, grounded)
    cr_gnd = vars[:cr_gnd]; ci_gnd = vars[:ci_gnd]
    for (bid, t) in grounded
        _kcl_add!(kcl_r, kcl_i, bid, t, cr_gnd[(bid,t)], ci_gnd[(bid,t)])
    end
end

"""
    _add_voltage_and_bus_bounds!(ctx)

Add the hard operational voltage bounds and bus-limit constraints. Shared by
`solve_opf` and `solve_feasibility_opf` (both carry the same non-KCL hard
constraints); the power-flow recipe does not call this.
"""
function _add_voltage_and_bus_bounds!(ctx::OpfContext)
    _add_voltage_bounds!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
    _add_bus_limit_constraints!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
end

"""
    _build_and_solve(net; optimizer, t_index, per_unit, s_base, build!, extract!,
                     configure!, verbose, solver_options, model_hook!,
                     solution_hook!) -> Dict

Generic build/solve engine. `build!(ctx)` is the per-problem recipe run after
variables exist and before KCL is enforced. `extract!(ctx, result)` is an
optional post-solve hook to append problem-specific result keys. `configure!`
is an optional hook to set solver attributes on the freshly created model.

User-facing knobs threaded through from the public solve entry points:
- `verbose`        — when `false` (default) the solver output is silenced.
- `solver_options` — iterable of `name => value` pairs applied as raw solver
  attributes *after* the problem's own `configure!`, so user options win.
- `model_hook!`    — optional `hook!(ctx)` called after the standard `build!`
  recipe and **before** KCL is enforced, so a hook can add constraints,
  replace the objective, or stamp extra injections into `ctx.kcl_r`/`ctx.kcl_i`.
- `solution_hook!` — optional `hook!(ctx, result)` called after the solve and
  the problem's own `extract!`, but **before** per-unit unwrapping, so a hook
  can read `JuMP.value` of custom variables (the model is still live) and append
  its own result keys. Runs in the model's units (per-unit when `per_unit=true`);
  the hook must scale its outputs to SI via `ctx.bases` so they survive alongside
  the engine's SI result. See the public `solve_opf` docstring for the contract.
"""
function _build_and_solve(net::Dict{String,Any};
                          optimizer,
                          t_index::Int,
                          per_unit::Bool,
                          s_base::Float64,
                          build!::Function,
                          extract!::Union{Function,Nothing}=nothing,
                          configure!::Union{Function,Nothing}=nothing,
                          relu_eps::Float64=2e-3,
                          verbose::Bool=false,
                          solver_options=(),
                          model_hook!::Union{Function,Nothing}=nothing,
                          solution_hook!::Union{Function,Nothing}=nothing)

    working, bases = _prepare_working_net(net, t_index, per_unit, s_base)

    model = JuMP.Model(optimizer)
    verbose || JuMP.set_silent(model)
    configure! === nothing || configure!(model)
    for (name, value) in solver_options
        JuMP.set_attribute(model, string(name), value)
    end

    ctx = _new_context(model, working, bases, relu_eps)

    build!(ctx)
    model_hook! === nothing || model_hook!(ctx)

    _enforce_kcl!(ctx)

    JuMP.optimize!(model)

    result = _extract_results(model, working, ctx.bus_terminals, ctx.grounded,
                              ctx.vars, ctx.branch_inj)
    extract! === nothing || extract!(ctx, result)

    # User post-solve extraction: read custom-variable values (model still live)
    # and append result keys. Runs in model units, before per-unit unwrapping —
    # the hook scales its own outputs to SI via `ctx.bases`.
    solution_hook! === nothing || solution_hook!(ctx, result)

    # Optimization fingerprint of the best-known solution — must be captured here,
    # while `model` is live (it is discarded when this function returns).
    result["opt_profile"] = _optimization_profile(model; per_unit=per_unit)

    bases !== nothing ? _from_per_unit(result, bases, net) : result
end

# ── Shared build sub-steps ─────────────────────────────────────────────────
# Factored out of `_build_and_solve` so the public staged API (`build_opf_model`,
# `enforce_kcl!`, `optimize!`, `extract_result`) and the fused engine run the
# EXACT same preparation, model, and KCL code — no second implementation to drift.

"""
    _prepare_working_net(net, t_index, per_unit, s_base) -> (working, bases)

Snapshot a time-series net at `t_index` (or deep-copy a static net), materialise
terminal roles, and per-unit-scale it when `per_unit=true`. `bases` is the
per-unit base NamedTuple, or `nothing` in SI mode.
"""
function _prepare_working_net(net::Dict{String,Any}, t_index::Int,
                              per_unit::Bool, s_base::Float64)
    working = BMOPFTools.is_timeseries(net) ?
              BMOPFTools.get_snapshot(net, t_index) : deepcopy(net)
    # Stamp per-bus neutral terminals from an explicit terminal_conventions block
    # so bus-level neutral resolution honours non-"n" labels even for nets built
    # programmatically (parse_bmopf already does this on load). Mutates the copy.
    BMOPFTools._materialize_terminal_roles!(working)

    bases = nothing
    per_unit && ((working, bases) = _to_per_unit(working, s_base))
    return working, bases
end

"""
    _new_context(model, working, bases, relu_eps) -> OpfContext

Index the working net, declare all JuMP variables into `model`, initialise the
KCL accumulators and branch-injection ledger, and bundle them into an
`OpfContext`. Adds no constraints and sets no objective.
"""
function _new_context(model, working::Dict{String,Any}, bases, relu_eps::Float64)
    bus_terminals = _bus_terminals(working)
    grounded      = _grounded_terminals(working)

    vars = _build_vars(model, working, bus_terminals, grounded)
    _set_dc_start_values!(vars, working)

    kcl_r, kcl_i = _init_kcl(bus_terminals, grounded)
    branch_inj = _new_branch_ledger()

    OpfContext(model, working, bus_terminals, grounded, vars,
               kcl_r, kcl_i, branch_inj, bases, relu_eps, Dict{Float64,Any}())
end

"""
    _enforce_kcl!(ctx)

Enforce Kirchhoff's current law: pin every AC KCL accumulator to zero and add
the DC-network nodal balance. Call once, after all device constraints and any
`model_hook!` injections have contributed to `ctx.kcl_r`/`ctx.kcl_i`.
"""
function _enforce_kcl!(ctx::OpfContext)
    _add_kcl_constraints!(ctx.model, ctx.kcl_r, ctx.kcl_i)
    _add_dc_kcl_constraints!(ctx.model, ctx.vars)
    return ctx
end

# ── Public staged build/solve/extract API ──────────────────────────────────
# The fused `solve_opf` is the convenience path. These four functions expose the
# same pipeline as discrete, composable steps so a caller (typically an external
# package) can build SEVERAL OPF snapshots into ONE JuMP model, couple them with
# its own cross-snapshot constraints (e.g. battery state-of-charge dynamics
# linking period t to t+1), set a single combined objective, solve once, and
# extract each snapshot's result. Each `ctx` keeps its own variable, KCL, and
# ledger dicts, so multiple contexts coexist in one model without collision.

"""
    BMOPFTools.build_opf_model(net; optimizer=Ipopt.Optimizer, t_index=1,
        per_unit=true, s_base=1e6, model=nothing, add_objective=true,
        model_hook!=nothing, volt_var_watt_eps=2e-3, verbose=false) -> ctx

Build the IVR-EN OPF device model, bounds, and (optionally) the generation-cost
objective for one snapshot, **without enforcing KCL or optimising**. The first
step of the staged API; see the module notes above.

- `model` — build into this existing JuMP model instead of a fresh one. Pass the
  same model for every snapshot of a multi-period problem so they share one
  optimisation. When `nothing`, a new `JuMP.Model(optimizer)` is created (and
  silenced unless `verbose`).
- `add_objective` — when `false`, the per-snapshot generation cost is NOT set on
  the model; recover it with [`generation_cost`](@ref) and set one combined
  objective yourself. Setting `@objective` once per snapshot would overwrite, so
  multi-period callers pass `add_objective=false`.
- `model_hook!` — called as `hook!(ctx)` after the standard build, exactly as in
  `solve_opf`, to add custom devices/constraints for this snapshot.

Returns the snapshot's `ctx` (an `OpfContext`); read `ctx.model`, `ctx.vars`,
`ctx.bases`, `ctx.kcl_r`/`ctx.kcl_i` to couple snapshots. Pass it to
[`enforce_kcl!`](@ref) and [`extract_result`](@ref).
"""
function BMOPFTools.build_opf_model(net::Dict{String,Any};
                                    optimizer=Ipopt.Optimizer,
                                    t_index::Int=1,
                                    per_unit::Bool=true,
                                    s_base::Float64=1e6,
                                    model=nothing,
                                    add_objective::Bool=true,
                                    model_hook!::Union{Function,Nothing}=nothing,
                                    volt_var_watt_eps::Float64=2e-3,
                                    verbose::Bool=false)
    working, bases = _prepare_working_net(net, t_index, per_unit, s_base)
    if model === nothing
        model = JuMP.Model(optimizer)
        verbose || JuMP.set_silent(model)
    end
    ctx = _new_context(model, working, bases, volt_var_watt_eps)
    build_opf!(ctx; add_objective=add_objective)
    model_hook! === nothing || model_hook!(ctx)
    return ctx
end

"""
    BMOPFTools.enforce_kcl!(ctx) -> ctx

Enforce Kirchhoff's current law for one snapshot's accumulators (AC nodal balance
+ DC network). Call after every device constraint and `model_hook!` injection for
that snapshot has been added, and before optimising. In a multi-period build call
it once per snapshot `ctx`.
"""
BMOPFTools.enforce_kcl!(ctx::OpfContext) = _enforce_kcl!(ctx)

"""
    BMOPFTools.generation_cost(ctx) -> JuMP.QuadExpr

The snapshot's total active-power generation-cost expression (the quantity
`solve_opf` minimises), returned WITHOUT setting it on the model. Sum these
across snapshots — adding any custom terms (e.g. storage throughput cost) — and
call `JuMP.@objective(ctx.model, Min, total)` once for a multi-period solve.
"""
BMOPFTools.generation_cost(ctx::OpfContext) =
    _generation_cost_expr(ctx.model, ctx.net, ctx.vars)

"""
    BMOPFTools.extract_result(ctx; solution_hook!=nothing) -> Dict{String,Any}

Extract one snapshot's result dict from the solved model (call `JuMP.optimize!`
on `ctx.model` first). Mirrors `solve_opf`'s output for that snapshot: runs the
optional `solution_hook!(ctx, result)`, attaches `opt_profile`, and unwraps
per-unit back to SI. Safe to call once per snapshot `ctx` after a single solve.
"""
function BMOPFTools.extract_result(ctx::OpfContext;
                                   solution_hook!::Union{Function,Nothing}=nothing)
    result = _extract_results(ctx.model, ctx.net, ctx.bus_terminals,
                              ctx.grounded, ctx.vars, ctx.branch_inj)
    solution_hook! === nothing || solution_hook!(ctx, result)
    per_unit = ctx.bases !== nothing
    result["opt_profile"] = _optimization_profile(ctx.model; per_unit=per_unit)
    per_unit ? _from_per_unit(result, ctx.bases, ctx.net) : result
end
