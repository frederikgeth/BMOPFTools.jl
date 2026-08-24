# The staged-API KCL guard: skipping `enforce_kcl!` must be loud, not silent.
#
# Included from runtests.jl inside the JuMP/Ipopt-gated block.
#
# Every test here asserts that the guard FIRES, or that a specific legitimate
# path stays quiet. A guard is trivially "passing" if it never fires at all, so
# tests that only check guarded solves still succeed would be worthless.

const _KCLEXT = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

_kg_net() = parse_bmopf("""
 {"bus":{
   "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]},
   "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]}},
  "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
      "v_magnitude":[230.0,230.0,230.0],
      "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
  "linecode":{"lc":{"R_series_1_1":0.08,"R_series_2_2":0.08,"R_series_3_3":0.08,
                    "X_series_1_1":0.04,"X_series_2_2":0.04,"X_series_3_3":0.04}},
  "line":{"l1":{"bus_from":"src","bus_to":"b1",
      "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
      "linecode":"lc","length":1.0}},
  "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
      "configuration":"WYE","p_nom":[5000.0,1500.0,900.0],
      "q_nom":[800.0,250.0,150.0]}}}
  """; from_string=true)

_kg_model() = (m = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(m); m)

@testset "KCL guard — refuses to optimise an unstamped model" begin
    ctx = BMOPFTools.build_opf_model(_kg_net())
    m = BMOPFTools.opf_model(ctx)
    err = try JuMP.optimize!(m); nothing catch e; e end
    @test err isa ArgumentError
    msg = sprint(showerror, err)
    @test occursin("enforce_kcl!", msg)
    @test occursin("electrically disconnected", msg)
    @test occursin("1 staged OPF context", msg)      # names how many
end

@testset "KCL guard — quiet once KCL is stamped, and does not perturb the answer" begin
    ctx = BMOPFTools.build_opf_model(_kg_net())
    BMOPFTools.enforce_kcl!(ctx)
    m = BMOPFTools.opf_model(ctx)
    JuMP.optimize!(m)
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

    # Same build with the guard disabled: the guard must be inert, not merely
    # harmless-looking.
    ref = BMOPFTools.build_opf_model(_kg_net(); kcl_guard=false)
    BMOPFTools.enforce_kcl!(ref)
    mref = BMOPFTools.opf_model(ref)
    JuMP.optimize!(mref)
    @test JuMP.objective_value(m) ≈ JuMP.objective_value(mref) rtol=1e-12
end

@testset "KCL guard — survives repeated optimise on a caller-supplied model" begin
    # The DiffOpt pattern: one model owned by the caller, re-solved after each
    # parameter perturbation. The guard must stay quiet on every solve, not just
    # the first, and must not consume the stage record.
    m = _kg_model()
    ctx = BMOPFTools.build_opf_model(_kg_net(); model=m)
    BMOPFTools.enforce_kcl!(ctx)
    for _ in 1:6
        JuMP.optimize!(m)
        @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    end
end

@testset "KCL guard — multi-period: one unstamped context among several" begin
    m = _kg_model()
    a = BMOPFTools.build_opf_model(_kg_net(); model=m, add_objective=false)
    b = BMOPFTools.build_opf_model(_kg_net(); model=m, add_objective=false)
    JuMP.@objective(m, Min, BMOPFTools.generation_cost(a) +
                            BMOPFTools.generation_cost(b))
    BMOPFTools.enforce_kcl!(a)                   # b deliberately left unstamped
    err = try JuMP.optimize!(m); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin("1 staged OPF context", sprint(showerror, err))

    BMOPFTools.enforce_kcl!(b)                   # now complete
    JuMP.optimize!(m)
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
end

@testset "KCL guard — counts every unstamped context, not just one" begin
    m = _kg_model()
    a = BMOPFTools.build_opf_model(_kg_net(); model=m, add_objective=false)
    b = BMOPFTools.build_opf_model(_kg_net(); model=m, add_objective=false)
    JuMP.@objective(m, Min, 0.0)
    err = try JuMP.optimize!(m); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin("2 staged OPF context", sprint(showerror, err))
end

@testset "KCL guard — a copied model is refused, not silently permitted" begin
    # `JuMP.copy_model` copies the optimize hook but NOT the registry entry, so
    # the copy would query itself, find no registered contexts, and permit an
    # unstamped solve — the guard failing OPEN. It is bound to its originating
    # model and refuses anything else.
    m = _kg_model()
    ctx = BMOPFTools.build_opf_model(_kg_net(); model=m)
    BMOPFTools.enforce_kcl!(ctx)                 # original is fully stamped
    cp, _ = JuMP.copy_model(m)
    @test cp.optimize_hook !== nothing           # the hook does come across
    @test _KCLEXT._unstamped_kcl_contexts(cp) == 0   # ...but the state does not

    JuMP.set_optimizer(cp, Ipopt.Optimizer); JuMP.set_silent(cp)
    err = try JuMP.optimize!(cp); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin("copy_model", sprint(showerror, err))

    # The documented escape: drop the inherited hook and solve unguarded.
    JuMP.set_optimize_hook(cp, nothing)
    JuMP.optimize!(cp)
    @test JuMP.termination_status(cp) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

    JuMP.optimize!(m)                            # original still works
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
end

@testset "KCL guard — an abandoned model is not retained by the registry" begin
    # The registry must not reach its own weak key. Storing the CONTEXT would:
    # a context owns its model, so value -> ctx -> model pins the key and the
    # session retains complete JuMP models. Only the stage vector is stored,
    # which references nothing.
    build_and_drop() = (m = _kg_model();
                        BMOPFTools.build_opf_model(_kg_net(); model=m);
                        nothing)
    for _ in 1:5; GC.gc(true); end
    before = length(_KCLEXT._KCL_GUARD_REGISTRY)
    for _ in 1:3; build_and_drop(); end
    for _ in 1:5; GC.gc(true); end
    @test length(_KCLEXT._KCL_GUARD_REGISTRY) == before
end

@testset "KCL guard — survives garbage collection" begin
    # Regression: OpfContext is an IMMUTABLE struct, so `WeakRef(ctx)` boxes a
    # copy that is unreachable immediately and reads back as `nothing`. A guard
    # registry built on WeakRef counts zero unstamped contexts forever and never
    # fires — it passes every "guarded solve still works" test while doing
    # nothing. Contexts are therefore held strongly under a weak MODEL key.
    m = _kg_model()
    ctx = BMOPFTools.build_opf_model(_kg_net(); model=m)
    @test _KCLEXT._unstamped_kcl_contexts(m) == 1
    GC.gc(); GC.gc()
    @test _KCLEXT._unstamped_kcl_contexts(m) == 1     # not silently emptied
    @test_throws ArgumentError JuMP.optimize!(m)
    BMOPFTools.enforce_kcl!(ctx)
    @test _KCLEXT._unstamped_kcl_contexts(m) == 0
end

@testset "KCL guard — chains a pre-existing optimize hook" begin
    m = _kg_model()
    fired = Ref(false)
    JuMP.set_optimize_hook(m, (mm; kwargs...) -> (fired[] = true;
                           JuMP.optimize!(mm; ignore_optimize_hook=true)))
    ctx = BMOPFTools.build_opf_model(_kg_net(); model=m)
    @test_throws ArgumentError JuMP.optimize!(m)   # guard runs before the chain
    @test !fired[]                                 # and short-circuits it
    BMOPFTools.enforce_kcl!(ctx)
    JuMP.optimize!(m)
    @test fired[]                                  # foreign hook not clobbered
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
end

@testset "KCL guard — kcl_guard=false opts out of the optimise-time check" begin
    ctx = BMOPFTools.build_opf_model(_kg_net(); kcl_guard=false)
    m = BMOPFTools.opf_model(ctx)
    JuMP.optimize!(m)                              # must not throw
    @test BMOPFTools.opf_stage_completed(ctx, :kcl) == false
    # The backstop still applies: the answer is meaningless, so extraction
    # refuses it even though the solve was allowed.
    @test_throws ArgumentError BMOPFTools.extract_result(ctx)
end

@testset "KCL guard — extract_result refuses an unstamped context" begin
    ctx = BMOPFTools.build_opf_model(_kg_net(); kcl_guard=false)
    err = try BMOPFTools.extract_result(ctx); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin("enforce_kcl!", sprint(showerror, err))
    @test occursin("electrically disconnected", sprint(showerror, err))

    BMOPFTools.enforce_kcl!(ctx)
    JuMP.optimize!(BMOPFTools.opf_model(ctx))
    res = BMOPFTools.extract_result(ctx)           # now allowed
    @test haskey(res, "losses")
end

@testset "KCL guard — initialize_opf_model installs it too" begin
    ctx = BMOPFTools.initialize_opf_model(_kg_net())
    m = BMOPFTools.opf_model(ctx)
    @test m.optimize_hook !== nothing
    @test _KCLEXT._unstamped_kcl_contexts(m) == 1

    bare = BMOPFTools.initialize_opf_model(_kg_net(); kcl_guard=false)
    @test BMOPFTools.opf_model(bare).optimize_hook === nothing
end

@testset "KCL guard — the fused solve_opf path is untouched" begin
    # `_build_and_solve` stamps KCL itself and never registers, so the fused
    # recipe must neither install a hook nor be affected by the guard.
    before = length(_KCLEXT._KCL_GUARD_REGISTRY)
    res = solve_opf(_kg_net())
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test length(_KCLEXT._KCL_GUARD_REGISTRY) == before
end
