using Test, BMOPFTools, JuMP, Ipopt

# Performance-oriented engine behavior: current start values, warm-started
# re-solves, batched result reads, and snapshot copying. These tests check
# behavior and equivalence, never timings.

const _WS_EXT = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

function _ws_feeder(; load_scale=1.0)
    net = BMOPFTools.parse_bmopf(joinpath(@__DIR__, "data", "case_development", "feeder.json"))
    for load in values(net["load"])
        load["p_nom"] = load_scale .* Float64.(load["p_nom"])
        load["q_nom"] = load_scale .* Float64.(load["q_nom"])
    end
    net["generator"] = Dict{String,Any}("der_far" => Dict{String,Any}(
        "bus" => "far", "terminal_map" => ["1", "2", "3", "n"],
        "configuration" => "WYE", "p_min" => zeros(3), "p_max" => fill(3000.0, 3),
        "q_min" => fill(-1000.0, 3), "q_max" => fill(1000.0, 3),
        "cost" => fill(0.10, 3)))
    return net
end

function _ws_ctx(net)
    ctx = build_opf_model(net; optimizer=Ipopt.Optimizer)
    set_attribute(ctx.model, "print_level", 0)
    set_attribute(ctx.model, "tol", 1e-9)
    return ctx
end

_ws_key(family, index) = BMOPFTools.OpfModelKey(:constraint, family, index)
_ws_iters(m) = MOI.get(m, MOI.BarrierIterations())

@testset "OPF current start values" begin
    ctx = _ws_ctx(_ws_feeder())
    start(v) = something(start_value(v), 0.0)
    crd = ctx.vars[:crd]
    @test !isempty(crd)
    for (lid, k) in keys(crd)
        @test start_value(crd[(lid, k)]) !== nothing
        @test start_value(ctx.vars[:cid][(lid, k)]) !== nothing
        # The seeded current satisfies each constant-power row at the start point.
        for family in (:load_power_real, :load_power_imag)
            cref = ctx.objects[_ws_key(family, (lid, k))]
            f = constraint_object(cref).func
            @test value(start, f) ≈ normalized_rhs(cref) rtol = 1e-9
        end
    end
    for (gid, k) in keys(ctx.vars[:crg])
        @test start_value(ctx.vars[:crg][(gid, k)]) !== nothing
        @test start_value(ctx.vars[:cig][(gid, k)]) !== nothing
    end

    # Boundary: an existing start is kept, and a non-numeric target is skipped.
    m = Model()
    @variable(m, cr, start = 3.0); @variable(m, ci, start = 4.0)
    @variable(m, vr, start = 1.0); @variable(m, vi, start = 0.0)
    _WS_EXT._seed_power_current!(cr, ci, 1.0 * vr, 1.0 * vi, 2.0, 0.0)
    @test (start_value(cr), start_value(ci)) == (3.0, 4.0)
    @variable(m, cr2); @variable(m, ci2); @variable(m, p in Parameter(1.0))
    _WS_EXT._seed_power_current!(cr2, ci2, 1.0 * vr, 1.0 * vi, p, 0.0)
    @test start_value(cr2) === nothing && start_value(ci2) === nothing
    # Negative: a zero voltage start gives no seed instead of a division by zero.
    @variable(m, vz, start = 0.0)
    _WS_EXT._seed_power_current!(cr2, ci2, 1.0 * vz, 1.0 * vz, 2.0, 1.0)
    @test start_value(cr2) === nothing
    # Generator target: the finite-box midpoint, else zero.
    @test _WS_EXT._generator_power_target([0.0], [4.0], [-1.0], [3.0], 1) == (2.0, 1.0)
    @test _WS_EXT._generator_power_target([0.0], [Inf], Float64[], Float64[], 1) == (0.0, 0.0)
end

@testset "resolve_opf! warm start" begin
    ctx = _ws_ctx(_ws_feeder())
    m = ctx.model
    original = Dict(v => start_value(v) for v in all_variables(m))

    # Without a prior feasible solve there is nothing to transfer.
    @test !_WS_EXT._transfer_warm_start!(ctx, m)
    @test all(start_value(v) === original[v] for v in all_variables(m))

    optimize_opf!(ctx)
    @test termination_status(m) == MOI.LOCALLY_SOLVED

    # Perturb the loads the way a sweep would: this discards JuMP's result, so
    # the warm start must come from the snapshot taken after the solve.
    scale = 1.05
    for (lid, k) in keys(ctx.vars[:crd]), family in (:load_power_real, :load_power_imag)
        cref = ctx.objects[_ws_key(family, (lid, k))]
        set_normalized_rhs(cref, scale * normalized_rhs(cref))
    end
    @test !has_values(m)
    resolve_opf!(ctx)
    @test termination_status(m) == MOI.LOCALLY_SOLVED
    warm_obj = objective_value(m); warm_iters = _ws_iters(m)
    @test get_attribute(m, "warm_start_init_point") == "yes"
    @test get_attribute(m, "mu_init") == 1e-6

    cold = _ws_ctx(_ws_feeder(; load_scale=scale))
    optimize_opf!(cold)
    @test termination_status(cold.model) == MOI.LOCALLY_SOLVED
    @test warm_obj ≈ objective_value(cold.model) rtol = 1e-6
    @test warm_iters < _ws_iters(cold.model)
    @test extract_result(ctx)["bus"]["far"]["1"]["vm"] ≈
          extract_result(cold)["bus"]["far"]["1"]["vm"] rtol = 1e-6

    # warm_start=false restores the build's starts and the options it set.
    resolve_opf!(ctx; warm_start=false)
    @test termination_status(m) == MOI.LOCALLY_SOLVED
    @test objective_value(m) ≈ warm_obj rtol = 1e-6
    @test get_attribute(m, "warm_start_init_point") == "no"
    @test get_attribute(m, "mu_init") == 0.1
    @test all(start_value(v) === original[v] for v in all_variables(m))

    # Caller-set options are never overwritten or reset.
    user = _ws_ctx(_ws_feeder())
    set_attribute(user.model, "mu_init", 1e-3)
    optimize_opf!(user)
    resolve_opf!(user)
    @test get_attribute(user.model, "mu_init") == 1e-3
    @test get_attribute(user.model, "warm_start_init_point") == "yes"
    resolve_opf!(user; warm_start=false)
    @test get_attribute(user.model, "mu_init") == 1e-3
end

@testset "Batched result reads match JuMP queries" begin
    ctx = _ws_ctx(_ws_feeder())
    optimize_opf!(ctx)
    m = ctx.model
    reader = _WS_EXT._primal_reader(m)
    for v in all_variables(m)
        @test reader(v) == value(v)
    end
    expr = first(values(ctx.kcl_r))
    @test reader(expr) ≈ value(expr) atol = 1e-12
    @test reader(2.5) == 2.5

    # The batched active-set count equals a per-row recount.
    prof = _WS_EXT._optimization_profile(m)
    n_active = 0
    for (F, S) in list_of_constraint_types(m)
        S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.Interval} || continue
        for c in all_constraints(m, F, S)
            v = value(c); set = constraint_object(c).set
            sl = _WS_EXT._slack(v, set)
            abs(sl) <= 1e-6 * (1.0 + abs(v)) && (n_active += 1)
        end
    end
    @test prof["n_active"] == n_active
    @test prof["n_unassessed_inequalities"] == 0

    # Lazy per-bus transformer weights accept dictionaries and functions.
    @test _WS_EXT._delta_load_roles(Dict{String,Any}("load" => Dict{String,Any}())) === nothing
end

@testset "Time-series snapshots share, not copy, the series" begin
    net = _ws_feeder()
    series = Dict{String,Any}("shape" => Dict{String,Any}("values" => [0.5, 1.0]))
    net["time_series"] = series
    net["load"]["near"]["time_series"] = Dict{String,Any}("p_nom" => "shape")
    p_near = copy(net["load"]["near"]["p_nom"])
    a = build_opf_model(net; optimizer=Ipopt.Optimizer, t_index=1)
    b = build_opf_model(net; optimizer=Ipopt.Optimizer, t_index=2)
    @test a.net["load"]["near"]["p_nom"] ≈ 0.5 .* b.net["load"]["near"]["p_nom"]
    @test !haskey(a.net, "time_series") && !haskey(a.net["load"]["near"], "time_series")
    # The caller's network, including its series, is unchanged.
    @test net["time_series"] === series
    @test series["shape"]["values"] == [0.5, 1.0]
    @test net["load"]["near"]["p_nom"] == p_near
    @test haskey(net["load"]["near"], "time_series")
end
