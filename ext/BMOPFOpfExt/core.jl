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
`solve_opf` and `solve_feasibility_opf` (both carry the identical hard feasible
set); a future power-flow recipe would simply not call this.
"""
function _add_voltage_and_bus_bounds!(ctx::OpfContext)
    _add_voltage_bounds!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
    _add_bus_limit_constraints!(ctx.model, ctx.net, ctx.bus_terminals, ctx.grounded, ctx.vars)
end

"""
    _build_and_solve(net; optimizer, t_index, per_unit, s_base, build!, extract!,
                     configure!, verbose, solver_options, model_hook!) -> Dict

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
                          model_hook!::Union{Function,Nothing}=nothing)

    working = BMOPFTools.is_timeseries(net) ?
              BMOPFTools.get_snapshot(net, t_index) : deepcopy(net)

    bases = nothing
    if per_unit
        working, bases = _to_per_unit(working, s_base)
    end

    model = JuMP.Model(optimizer)
    verbose || JuMP.set_silent(model)
    configure! === nothing || configure!(model)
    for (name, value) in solver_options
        JuMP.set_attribute(model, string(name), value)
    end

    bus_terminals = _bus_terminals(working)
    grounded      = _grounded_terminals(working)

    vars = _build_vars(model, working, bus_terminals, grounded)
    _set_dc_start_values!(vars, working)

    kcl_r, kcl_i = _init_kcl(bus_terminals, grounded)
    branch_inj = _new_branch_ledger()

    ctx = OpfContext(model, working, bus_terminals, grounded, vars,
                     kcl_r, kcl_i, branch_inj, bases, relu_eps, Dict{Float64,Any}())

    build!(ctx)
    model_hook! === nothing || model_hook!(ctx)

    _add_kcl_constraints!(model, kcl_r, kcl_i)
    _add_dc_kcl_constraints!(model, vars)

    JuMP.optimize!(model)

    result = _extract_results(model, working, bus_terminals, grounded, vars, branch_inj)
    extract! === nothing || extract!(ctx, result)

    bases !== nothing ? _from_per_unit(result, bases, net) : result
end
