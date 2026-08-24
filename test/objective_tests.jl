# Objective building blocks: smooth_norm and the composable objective terms.
#
# Included from runtests.jl inside the JuMP/Ipopt-gated block.

const _OBJEXT = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

# Deliberately unbalanced 4-wire LV feeder with a per-phase STATCOM, matching
# bench/sequence_objective_norms.jl so measured claims stay checkable.
_obj_net(smax) = parse_bmopf("""
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
      "configuration":"WYE","p_nom":[6000.0,1000.0,500.0],
      "q_nom":[1500.0,200.0,100.0]}},
  "ibr":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
      "topology":"FOUR_LEG","prime_mover":"STATCOM",
      "s_max":[$smax,$smax,$smax],"p_max":[0.0,0.0,0.0],"p_min":[0.0,0.0,0.0],
      "cost":[0.0,0.0,0.0]}}}
 """; from_string=true)

@testset "smooth_norm — accuracy bound" begin
    # The contract is a UNIFORM ONE-SIDED bound: the surrogate never exceeds the
    # exact norm, and never falls short of it by more than eps. This is what
    # lets a penalty built on it carry a closed-form error budget.
    for eps in (1e-1, 1e-3, 1e-6)
        for (x, y) in ((0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (3.0, 4.0),
                       (-3.0, 4.0), (1e-12, 0.0), (1e6, 1e6))
            exact  = hypot(x, y)
            smooth = _OBJEXT.smooth_norm_value(x, y, eps)
            # The bound is exact in real arithmetic; in Float64 it holds to
            # within rounding. `sqrt(x^2+y^2+eps^2) - eps` subtracts a tiny eps
            # from a possibly-huge root, so the achievable resolution is set by
            # the ulp of the RESULT, not by eps. At (1e6,1e6) with eps=1e-6 one
            # ulp is ~2.3e-10, which is 5 orders above eps.
            slack = 16 * Base.eps(max(1.0, exact))
            @test smooth <= exact + slack               # never overestimates
            @test exact - smooth <= eps + slack         # never short by > eps
        end
        # Equality at the origin: the bound is attained, not merely respected.
        @test _OBJEXT.smooth_norm_value(0.0, 0.0, eps) == 0.0
        @test hypot(0.0, 0.0) - _OBJEXT.smooth_norm_value(0.0, 0.0, eps) ≈ 0.0 atol=1e-15
    end
    # Rotation invariance: a complex quantity's penalty must not depend on the
    # phase reference. (Componentwise |x|+|y| would fail this — hence the
    # per-element 2-norm.)
    r, eps = 5.0, 1e-3
    vals = [_OBJEXT.smooth_norm_value(r*cos(θ), r*sin(θ), eps)
            for θ in range(0, 2π; length = 17)]
    @test maximum(vals) - minimum(vals) < 1e-12
end

@testset "smooth_norm — rejects a degenerate epsilon" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0);
                                     per_unit=true, add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    x = JuMP.@variable(m); y = JuMP.@variable(m)
    # eps = 0 restores the exact norm, whose AD gradient at the origin is 0/0;
    # Ipopt rejects such a model outright, so refuse to build it.
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, x, y; scale=1.0, eps_rel=0.0)
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, x, y; scale=0.0)
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, x, y; scale=-1.0)
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, x, y; scale=1.0, eps_rel=-1e-3)
end

@testset "smooth_norm — records a differentiability annotation" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0);
                                     per_unit=true, add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    x = JuMP.@variable(m); y = JuMP.@variable(m)
    @test isempty(BMOPFTools.opf_differentiability_annotations(ctx))
    hash_before = BMOPFTools.opf_research_hashes(ctx)["differentiability_annotations_sha256"]

    BMOPFTools.smooth_norm(ctx, x, y; scale=1.0, eps_rel=1e-3, name="probe")
    ann = BMOPFTools.opf_differentiability_annotations(ctx)
    @test length(ann) == 1
    rec = first(values(ann))
    @test rec.kind == :nonsmooth_operator
    # The surrogate is differentiable everywhere: this is a reproducibility
    # record of an approximation, not an AD hazard.
    @test rec.blocking == false
    @test rec.metadata["eps"] ≈ 1e-3
    @test rec.metadata["eps_rel"] ≈ 1e-3
    @test rec.metadata["scale"] ≈ 1.0

    # eps is part of the model, so it must reach the reproducibility fingerprint:
    # the annotation hash has to MOVE, not merely exist.
    hash_after = BMOPFTools.opf_research_hashes(ctx)["differentiability_annotations_sha256"]
    @test hash_after != hash_before

    # ...and a different eps must fingerprint differently, or two models that
    # are not the same model would hash alike.
    ctx_e = BMOPFTools.build_opf_model(_obj_net(20_000.0);
                                       per_unit=true, add_objective=false)
    m_e = BMOPFTools.opf_model(ctx_e)
    BMOPFTools.smooth_norm(ctx_e, JuMP.@variable(m_e), JuMP.@variable(m_e);
                           scale=1.0, eps_rel=1e-6, name="probe")
    @test BMOPFTools.opf_research_hashes(ctx_e)["differentiability_annotations_sha256"] !=
          hash_after

    # Opting out leaves no record.
    ctx2 = BMOPFTools.build_opf_model(_obj_net(20_000.0);
                                      per_unit=true, add_objective=false)
    m2 = BMOPFTools.opf_model(ctx2)
    BMOPFTools.smooth_norm(ctx2, JuMP.@variable(m2), JuMP.@variable(m2);
                           scale=1.0, annotate=false)
    @test isempty(BMOPFTools.opf_differentiability_annotations(ctx2))
end

@testset "smooth_norm — eps scales with the declared quantity scale" begin
    # The same relative smoothing must mean the same thing in SI and per-unit.
    # A voltage of 230 V at scale 230 and 1.0 pu at scale 1.0 are the same
    # physical quantity, so their relative errors must agree.
    eps_rel = 1e-3
    si_err = hypot(230.0, 0.0) -
             _OBJEXT.smooth_norm_value(230.0, 0.0, eps_rel * 230.0)
    pu_err = hypot(1.0, 0.0) - _OBJEXT.smooth_norm_value(1.0, 0.0, eps_rel * 1.0)
    @test si_err / 230.0 ≈ pu_err / 1.0 rtol=1e-12
end

@testset "opf_sequence_voltage — matches a hand-computed Fortescue transform" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(200.0); per_unit=true,
                                     add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    seq = Dict(c => BMOPFTools.opf_sequence_voltage(ctx, "b1"; component=c)
               for c in (:zero, :positive, :negative))
    JuMP.@objective(m, Min, 0.0)
    BMOPFTools.enforce_kcl!(ctx)
    JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

    vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
    # b1's neutral is perfectly grounded here, so the reference is
    # phase-to-ground and the hand transform uses the raw phase voltages.
    V = [JuMP.value(vr[("b1", t)]) + im * JuMP.value(vi[("b1", t)])
         for t in ("1", "2", "3")]
    a = exp(im * 2π / 3)
    hand = Dict(:zero     => sum(V) / 3,
                :positive => (V[1] + a*V[2] + a^2*V[3]) / 3,
                :negative => (V[1] + a^2*V[2] + a*V[3]) / 3)
    for c in (:zero, :positive, :negative)
        (re, ie) = seq[c]
        @test JuMP.value(re) ≈ real(hand[c]) atol=1e-10
        @test JuMP.value(ie) ≈ imag(hand[c]) atol=1e-10
    end
    # The feeder is genuinely unbalanced, or this test would pass vacuously.
    @test hypot(JuMP.value(seq[:negative][1]), JuMP.value(seq[:negative][2])) > 1e-4
end

@testset "opf_sequence_voltage — rejects an undefined request" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(200.0); per_unit=true,
                                     add_objective=false)
    @test_throws ArgumentError BMOPFTools.opf_sequence_voltage(ctx, "b1"; component=:bogus)
    @test_throws ArgumentError BMOPFTools.opf_sequence_voltage(ctx, "no_such_bus")
end

@testset "opf_sequence_voltage — shares one definition with the bus bounds" begin
    # Regression guard for the refactor that made bus.jl consume
    # `_sequence_voltage_terms`: a vneg_max LIMIT and an opf_sequence_voltage
    # PENALTY must be talking about the same number. If the two Fortescue
    # copies ever drift, a bound would stop matching the quantity it bounds.
    net = _obj_net(200.0)
    ctx0 = BMOPFTools.build_opf_model(net; per_unit=true, add_objective=false)
    m0 = BMOPFTools.opf_model(ctx0)
    (r0, i0) = BMOPFTools.opf_sequence_voltage(ctx0, "b1"; component=:negative)
    JuMP.@objective(m0, Min, 0.0); BMOPFTools.enforce_kcl!(ctx0)
    JuMP.set_attribute(m0, "print_level", 0); JuMP.optimize!(m0)
    v2_free = hypot(JuMP.value(r0), JuMP.value(i0))
    @test v2_free > 1e-4

    # Now impose vneg_max BELOW what the unconstrained solve produced. If the
    # bound is built from the same expression, it must bind.
    netb = _obj_net(200.0)
    netb["bus"]["b1"]["vneg_max"] = 0.5 * v2_free
    ctxb = BMOPFTools.build_opf_model(netb; per_unit=true, add_objective=false)
    mb = BMOPFTools.opf_model(ctxb)
    (rb, ib) = BMOPFTools.opf_sequence_voltage(ctxb, "b1"; component=:negative)
    JuMP.@objective(mb, Min, 0.0); BMOPFTools.enforce_kcl!(ctxb)
    JuMP.set_attribute(mb, "print_level", 0); JuMP.optimize!(mb)
    if JuMP.termination_status(mb) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
        @test hypot(JuMP.value(rb), JuMP.value(ib)) <= 0.5 * v2_free + 1e-6
    else
        # Refusing the tightened bound is also consistent with the two agreeing;
        # silently exceeding it would not be.
        @test JuMP.termination_status(mb) != JuMP.OPTIMAL
    end
end
