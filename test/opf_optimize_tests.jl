# Included after kcl_guard_tests.jl, reusing its small physical network.
using JSON3

_oo_counts(m) = (JuMP.num_variables(m),
    JuMP.num_constraints(m; count_variable_in_set_constraints=true))
_oo_state(c) = (copy(c.manifest.stages), opf_lifecycle(c),
    _oo_counts(opf_model(c)), copy(opf_object_keys(c)))
_oo_kcl(c) = Dict(k => opf_object(c, k) for k in opf_object_keys(c)
    if k.kind == :constraint && k.family in (:kcl_r, :kcl_i))

function _oo_counting_model()
    model = _kg_model()
    calls = Ref(0)
    tokens = Any[]
    JuMP.set_optimize_hook(model, function (m; test_token=nothing, kwargs...)
        calls[] += 1
        push!(tokens, test_token)
        JuMP.optimize!(m; ignore_optimize_hook=true, kwargs...)
    end)
    return model, calls, tokens
end

@testset "optimize_opf! — finalize, solve once, and preserve handles" begin
    m, calls, tokens = _oo_counting_model()
    a = build_opf_model(_kg_net(); model=m, add_objective=false)
    b = build_opf_model(_kg_net(); model=m, add_objective=false)
    JuMP.@objective(m, Min, generation_cost(a) + generation_cost(b))
    @test optimize_opf!(a, b; test_token=:first) === m
    @test calls[] == 1
    @test tokens == [:first]
    @test all(c -> opf_stage_completed(c, :kcl), (a, b))
    @test all(c -> opf_lifecycle(c) == :kcl_finalized, (a, b))
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    rows = (_oo_kcl(a), _oo_kcl(b))
    @test all(!isempty, rows)
    counts = _oo_counts(m)
    @test optimize_opf!(a, b; test_token=:again) === m
    @test calls[] == 2
    @test tokens == [:first, :again]
    @test _oo_counts(m) == counts
    @test (_oo_kcl(a), _oo_kcl(b)) == rows
    @test all(c -> count(==(:kcl), c.manifest.stages) == 1, (a, b))

    # Shared extraction is compared to the independent manual workflow.
    manual = build_opf_model(_kg_net())
    enforce_kcl!(manual)
    JuMP.optimize!(opf_model(manual))
    @test JuMP.objective_value(m) ≈ 2JuMP.objective_value(opf_model(manual)) rtol=1e-8
    for c in (a, b)
        result = extract_result(c)
        reference = extract_result(manual)
        restored = JSON3.read(JSON3.write(result), Dict{String,Any})
        @test restored["bus"] == result["bus"]
        for t in ("1", "2", "3")
            @test result["bus"]["b1"][t]["vm"] ≈ reference["bus"]["b1"][t]["vm"] atol=1e-6
        end
        # Independent per-phase voltage-drop and constant-power-load equations.
        for (i, t) in enumerate(("1", "2", "3"))
            phasor(b) = complex(result["bus"][b][t]["vr"], result["bus"][b][t]["vi"])
            v = phasor("b1")
            load = _kg_net()["load"]["ld"]
            current = conj(complex(load["p_nom"][i], load["q_nom"][i]) / v)
            @test phasor("src") - v ≈ complex(0.08, 0.04) * current atol=1e-5
            @test 180.0 <= abs(v) <= 280.0
        end
        @test isempty(filter(f -> f.severity == ERROR, profile_solution(_kg_net(), result).findings))
    end
end

@testset "optimize_opf! — mixed finalization and finalized omitted sibling" begin
    m, calls, _ = _oo_counting_model()
    a = build_opf_model(_kg_net(); model=m, add_objective=false)
    b = build_opf_model(_kg_net(); model=m, add_objective=false)
    JuMP.@objective(m, Min, generation_cost(a) + generation_cost(b))
    enforce_kcl!(a)
    rows = _oo_kcl(a)
    @test optimize_opf!(a, b) === m
    @test calls[] == 1
    @test _oo_kcl(a) == rows
    counts = _oo_counts(m)
    @test optimize_opf!(b) === m # omitted a is already complete
    @test calls[] == 2
    @test _oo_counts(m) == counts
end

@testset "optimize_opf! — invalid preflight never finalizes or solves" begin
    @test_throws ArgumentError optimize_opf!()
    m, calls, _ = _oo_counting_model()
    a = build_opf_model(_kg_net(); model=m, add_objective=false)
    b = build_opf_model(_kg_net(); model=m, add_objective=false)
    initial = (_oo_state(a), _oo_state(b))
    @test_throws ArgumentError optimize_opf!(a, a, b)
    @test_throws ArgumentError optimize_opf!(a)
    @test_throws ArgumentError optimize_opf!(a, b; ignore_optimize_hook=true)
    @test_throws ArgumentError optimize_opf!(a, b; ignore_optimize_hook=false)
    @test initial == (_oo_state(a), _oo_state(b))
    @test calls[] == 0

    other = build_opf_model(_kg_net())
    other_state = _oo_state(other)
    @test_throws ArgumentError optimize_opf!(a, b, other)
    @test other_state == _oo_state(other)
    @test initial == (_oo_state(a), _oo_state(b))
    @test calls[] == 0

    # The ready context comes first, so a sequential finalize/check would mutate it.
    bare = initialize_opf_model(_kg_net(); model=m)
    initial = (_oo_state(a), _oo_state(b), _oo_state(bare))
    @test_throws ArgumentError optimize_opf!(a, b, bare)
    @test initial == (_oo_state(a), _oo_state(b), _oo_state(bare))
    @test calls[] == 0
end

@testset "optimize_opf! — inconsistent lifecycle is rejected before mutation" begin
    m, calls, _ = _oo_counting_model()
    ready = build_opf_model(_kg_net(); model=m, add_objective=false)
    finished = build_opf_model(_kg_net(); model=m, add_objective=false)
    enforce_kcl!(finished)
    finished.lifecycle[] = :building
    state = (_oo_state(ready), _oo_state(finished))
    @test_throws ArgumentError optimize_opf!(ready, finished)
    @test state == (_oo_state(ready), _oo_state(finished))
    @test calls[] == 0
    finished.lifecycle[] = :kcl_finalized
    # Duplicate finalized arguments are also invalid and do not request a solve.
    state = (_oo_state(ready), _oo_state(finished))
    @test_throws ArgumentError optimize_opf!(ready, finished, finished)
    @test state == (_oo_state(ready), _oo_state(finished))
    @test calls[] == 0
end

@testset "optimize_opf! — explicit checks survive hook replacement and guard opt-out" begin
    m, calls, _ = _oo_counting_model()
    a = build_opf_model(_kg_net(); model=m)
    b = initialize_opf_model(_kg_net(); model=m)
    # Replacing the optional guard cannot bypass the helper's registry preflight.
    JuMP.set_optimize_hook(m, mm -> (calls[] += 1))
    state = (_oo_state(a), _oo_state(b))
    @test_throws ArgumentError optimize_opf!(a)
    @test state == (_oo_state(a), _oo_state(b))
    @test calls[] == 0

    m, calls, _ = _oo_counting_model()
    ready = build_opf_model(_kg_net(); model=m, kcl_guard=false)
    bare = initialize_opf_model(_kg_net(); model=m, kcl_guard=false)
    state = (_oo_state(ready), _oo_state(bare))
    @test_throws ArgumentError optimize_opf!(ready, bare)
    @test state == (_oo_state(ready), _oo_state(bare))
    @test calls[] == 0
    @test optimize_opf!(ready) === m
    @test calls[] == 1
    @test opf_lifecycle(ready) == :kcl_finalized
    @test_throws ArgumentError extract_result(bare)
end

@testset "optimize_opf! — optional stages and direct model" begin
    # Manual construction may intentionally omit native operational bounds and
    # the default objective; KCL readiness follows the existing stage contract.
    for m in (_kg_model(), JuMP.direct_model(Ipopt.Optimizer()))
        JuMP.set_silent(m)
        c = initialize_opf_model(_kg_net(); model=m, per_unit=false)
        set_opf_start_values!(c)
        add_opf_device_constraints!(c)
        JuMP.@objective(m, Min, generation_cost(c))
        @test !opf_stage_completed(c, :operational_limits)
        @test !opf_stage_completed(c, :objective)
        @test optimize_opf!(c) === m
        @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
        @test isempty(JuMP.primal_feasibility_report(m; atol=1e-6))
    end
end

@testset "optimize_opf! — inherited copied-model guard still rejects" begin
    original = build_opf_model(_kg_net())
    enforce_kcl!(original)
    copied, _ = JuMP.copy_model(opf_model(original))
    JuMP.set_optimizer(copied, Ipopt.Optimizer)
    JuMP.set_silent(copied)
    c = build_opf_model(_kg_net(); model=copied)
    @test_throws ArgumentError optimize_opf!(c)
    @test JuMP.termination_status(copied) == JuMP.OPTIMIZE_NOT_CALLED
end
