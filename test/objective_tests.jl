# Objective building blocks: smooth_norm and the composable objective terms.
#
# Included from runtests.jl inside the JuMP/Ipopt-gated block.

const _OBJEXT = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

# The per-unit/SI agreement tests ask Ipopt for a tight `tol` so both modes are
# compared at the same convergence quality. Whether it REACHES that level is
# platform-dependent: on x86_64 Linux (CI, Julia LTS) it can stop at the
# acceptable level and report ALMOST_LOCALLY_SOLVED, while aarch64 macOS reaches
# LOCALLY_SOLVED on the same commit. That is a valid local solution, not a
# failure, so the status set accepts it — and `acceptable_tol` is pinned two
# orders below the rtol these tests assert, so accepting it cannot let a
# materially worse solution through.
const _OBJ_SOLVED = (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL, JuMP.ALMOST_LOCALLY_SOLVED)
_obj_tight!(m) = (JuMP.set_attribute(m, "tol", 1e-10);
                  JuMP.set_attribute(m, "acceptable_tol", 1e-8))

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

# 4-wire feeder with an explicit neutral conductor, so a neutral current exists.
_obj_net_4w() = parse_bmopf("""
 {"bus":{
   "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]},
   "b1": {"terminal_names":["1","2","3","n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]}},
  "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
      "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944],
      "cost":[1.0,1.0,1.0]}},
  "linecode":{"lc":{"R_series_1_1":0.08,"R_series_2_2":0.08,"R_series_3_3":0.08,
                    "R_series_4_4":0.08}},
  "line":{"l1":{"bus_from":"src","bus_to":"b1",
      "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
      "linecode":"lc","length":1.0}},
  "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
      "configuration":"WYE","p_nom":[6000.0,1000.0,500.0],"q_nom":[0.0,0.0,0.0]}}}
 """; from_string=true)


# Two independently-controllable compensators on separate laterals: the case
# where a group-lasso can actually choose, unlike a single radial path.
_obj_net_2lat(smax = 6000.0) = parse_bmopf("""
 {"bus":{
   "src":{"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
   "L1":{"terminal_names":["a","b","c","n"],
         "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
   "L2":{"terminal_names":["a","b","c","n"],
         "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
  "voltage_source":{"grid":{"bus":"src","terminal_map":["a","b","c"],
      "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944],
      "cost":[0.3,0.3,0.3]}},
  "linecode":{"lc":{"R_series_1_1":0.15,"R_series_2_2":0.15,"R_series_3_3":0.15,
                    "R_series_4_4":0.15}},
  "line":{"a1":{"bus_from":"src","bus_to":"L1",
      "terminal_map_from":["a","b","c","n"],"terminal_map_to":["a","b","c","n"],
      "linecode":"lc","length":1.0},
          "a2":{"bus_from":"src","bus_to":"L2",
      "terminal_map_from":["a","b","c","n"],"terminal_map_to":["a","b","c","n"],
      "linecode":"lc","length":1.0}},
  "load":{"d1":{"bus":"L1","terminal_map":["a","b","c","n"],"configuration":"WYE",
                "p_nom":[5000.0,900.0,600.0],"q_nom":[800.0,150.0,100.0]},
          "d2":{"bus":"L2","terminal_map":["a","b","c","n"],"configuration":"WYE",
                "p_nom":[600.0,900.0,5000.0],"q_nom":[100.0,150.0,800.0]}},
  "ibr":{"c1":{"bus":"L1","terminal_map":["a","b","c","n"],"topology":"FOUR_LEG",
               "prime_mover":"STATCOM","s_max":[$smax,$smax,$smax],
               "p_max":[$(smax/2),$(smax/2),$(smax/2)],"p_min":[$(-smax/2),$(-smax/2),$(-smax/2)],
               "dc_link_coupled":true,"cost":[0.0,0.0,0.0]},
         "c2":{"bus":"L2","terminal_map":["a","b","c","n"],"topology":"FOUR_LEG",
               "prime_mover":"STATCOM","s_max":[$smax,$smax,$smax],
               "p_max":[$(smax/2),$(smax/2),$(smax/2)],"p_min":[$(-smax/2),$(-smax/2),$(-smax/2)],
               "dc_link_coupled":true,"cost":[0.0,0.0,0.0]}}}
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

@testset "opf_total_loss — agrees with the reported post-solve loss" begin
    # The strongest available check: the expression the solver would minimise
    # and the number the result reports must be the SAME quantity. This also
    # validates the per-bus power weighting and the grounded-terminal handling,
    # which are the two places a model-side reimplementation would drift.
    for pu in (true, false)
        ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0);
                                         per_unit=pu, add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        loss = BMOPFTools.opf_total_loss(ctx)
        JuMP.@objective(m, Min, 0.0)
        BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

        res = BMOPFTools.extract_result(ctx)
        # extract_result unwraps per-unit back to SI; the expression is in
        # working units, so scale it the same way before comparing.
        s_base = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
        @test JuMP.value(loss) * s_base ≈ res["losses"]["p_loss"] rtol=1e-8
        # Passive network: the loss must be strictly positive, or the test
        # would be satisfied by an expression that is identically zero.
        @test res["losses"]["p_loss"] > 1.0
    end
end

@testset "opf_element_loss — per-element losses sum to the total" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    total = BMOPFTools.opf_total_loss(ctx)
    per_element = Any[]
    for block in ("line", "transformer", "switch")
        for id in keys(get(ctx.branch_inj, block, Dict{String,Any}()))
            push!(per_element, BMOPFTools.opf_element_loss(ctx, block, id))
        end
    end
    @test !isempty(per_element)
    JuMP.@objective(m, Min, 0.0); BMOPFTools.enforce_kcl!(ctx)
    JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
    @test sum(JuMP.value.(per_element)) ≈ JuMP.value(total) rtol=1e-9

    # And each element's expression matches its own reported loss.
    res = BMOPFTools.extract_result(ctx)
    s_base = ctx.bases.s_base
    for (lid, _) in get(ctx.branch_inj, "line", Dict{String,Any}())
        e = BMOPFTools.opf_element_loss(ctx, "line", lid)
        @test JuMP.value(e) * s_base ≈ res["line"][lid]["loss"]["p_loss"] rtol=1e-8
    end
end

@testset "opf_element_loss — rejects an unknown target" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    @test_throws ArgumentError BMOPFTools.opf_element_loss(ctx, "bogus_block", "l1")
    @test_throws ArgumentError BMOPFTools.opf_element_loss(ctx, "line", "no_such_line")
    @test_throws ArgumentError BMOPFTools.opf_total_loss(ctx; blocks=("line", "nope"))
end

@testset "opf_total_loss — minimising it actually reduces losses" begin
    # A loss objective must move the answer, or it is decorative. Compare the
    # loss at a zero-objective feasible point against the loss-minimising one.
    function loss_under(objective)
        ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                         add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        L = BMOPFTools.opf_total_loss(ctx)
        objective === :none ? JuMP.@objective(m, Min, 0.0) : JuMP.@objective(m, Min, L)
        BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        (JuMP.termination_status(m), JuMP.value(L))
    end
    (st0, l0) = loss_under(:none)
    (st1, l1) = loss_under(:loss)
    @test st0 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test st1 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test l1 <= l0 + 1e-9          # never worse
    @test l1 < l0                  # and the STATCOM genuinely finds headroom
end

@testset "composed objective — per-unit and SI agree" begin
    # The property the whole units design exists for: one specification, two
    # unit modes, the same physical answer. Weights are declared per physical
    # unit and the terms are converted, so nothing is left for the caller to
    # reconcile.
    function run(pu, norm)
        ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0);
                                         per_unit=pu, add_objective=false)
        terms = [BMOPFTools.opf_loss_term(ctx; weight=1.0),
                 BMOPFTools.opf_sequence_term(ctx, "b1"; norm=norm, weight=50.0)]
        BMOPFTools.set_opf_objective!(ctx, terms)
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); _obj_tight!(m)
        JuMP.optimize!(m)
        res = BMOPFTools.extract_result(ctx)
        (status = JuMP.termination_status(m),
         obj = JuMP.objective_value(m),
         q = [res["ibr"]["pv1"][p]["qg"] for p in ("1", "2", "3")])
    end
    for norm in (:squared, :magnitude, :max)
        a = run(true, norm); b = run(false, norm)
        @test a.status in _OBJ_SOLVED
        @test b.status in _OBJ_SOLVED
        # Tolerance reflects the quantity, not the implementation: the objective
        # contains a LOSS, which is a small difference of large terminal powers
        # (here ~60 W out of ~7.5 kW). The engine's physics agrees between modes
        # to ~1e-8 on voltages; that cancellation amplifies it by ~2 orders in
        # any loss-valued quantity. Asserting 1e-8 here would be asserting
        # something arithmetic cannot deliver.
        @test a.obj ≈ b.obj rtol=1e-4
        @test a.q ≈ b.q rtol=1e-3
    end
end

@testset "composed objective — weights are recorded, not just applied" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                     add_objective=false)
    terms = [BMOPFTools.opf_loss_term(ctx; weight=2.0),
             BMOPFTools.opf_sequence_term(ctx, "b1"; norm=:squared, weight=7.5)]
    BMOPFTools.set_opf_objective!(ctx, terms)

    regs = BMOPFTools.opf_regularizations(ctx)
    @test length(regs) == 2
    by_name = Dict(String(r.name) => r for r in values(regs))
    @test haskey(by_name, "objective_term_losses")
    @test by_name["objective_term_losses"].weight ≈ 2.0
    @test by_name["objective_term_losses"].units == :W
    seq = only(r for (n, r) in by_name if n != "objective_term_losses")
    @test seq.weight ≈ 7.5
    # :squared on a voltage is V^2 — recorded, so a weight tuned for one norm is
    # not silently reused for another.
    @test seq.units == :V2

    # A weighted objective whose weights are not fingerprinted is not a
    # reproducible experiment.
    h1 = BMOPFTools.opf_research_hashes(ctx)["regularization_declarations_sha256"]
    ctx2 = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                      add_objective=false)
    BMOPFTools.set_opf_objective!(ctx2,
        [BMOPFTools.opf_loss_term(ctx2; weight=2.0),
         BMOPFTools.opf_sequence_term(ctx2, "b1"; norm=:squared, weight=99.0)])
    @test BMOPFTools.opf_research_hashes(ctx2)["regularization_declarations_sha256"] != h1
end

@testset "composed objective — rejects malformed specifications" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                     add_objective=false)
    @test_throws ArgumentError BMOPFTools.set_opf_objective!(ctx, [])
    dup = [BMOPFTools.opf_loss_term(ctx; weight=1.0, name=:x),
           BMOPFTools.opf_loss_term(ctx; weight=1.0, name=:x)]
    @test_throws ArgumentError BMOPFTools.set_opf_objective!(ctx, dup)
    @test_throws ArgumentError BMOPFTools.set_opf_objective!(
        ctx, [BMOPFTools.opf_loss_term(ctx)]; sense=:sideways)
end

@testset "opf_physical_scale — per-bus units demand a bus" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                     add_objective=false)
    # A system-wide voltage scale would be wrong on any multi-voltage network,
    # so omitting the bus must throw rather than quietly pick one.
    @test_throws ArgumentError BMOPFTools.opf_physical_scale(ctx, :V)
    @test_throws ArgumentError BMOPFTools.opf_physical_scale(ctx, :A)
    @test_throws ArgumentError BMOPFTools.opf_physical_scale(ctx, :furlong; bus="b1")
    @test BMOPFTools.opf_physical_scale(ctx, :dimensionless) == 1.0
    @test BMOPFTools.opf_physical_scale(ctx, :V2; bus="b1") ≈
          BMOPFTools.opf_physical_scale(ctx, :V; bus="b1")^2

    # In SI every scale is 1.0, so a term written against it needs no branch.
    si = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=false,
                                    add_objective=false)
    @test BMOPFTools.opf_physical_scale(si, :W) == 1.0
    @test BMOPFTools.opf_physical_scale(si, :V; bus="b1") == 1.0
end

@testset "norm modes — :max equalises, :squared and :magnitude do not" begin
    # The original version of this testset was named for a property it never
    # asserted: it checked only that every solve returned a value, and would
    # have passed with all three norms producing identical dispatch.
    #
    # The compensators are deliberately UNDER-rated (smax=1000) so the optimum
    # is bounded away from zero. Given full authority all three norms drive both
    # buses to ~1e-11 and any comparison between them is vacuous.
    function residuals(norm)
        ctx = BMOPFTools.build_opf_model(_obj_net_2lat(1_000.0); per_unit=true,
                                         add_objective=false)
        t = BMOPFTools.opf_sequence_term(ctx, ["L1","L2"]; norm=norm, weight=1.0)
        BMOPFTools.set_opf_objective!(ctx, [t])
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL) || return nothing
        [hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx, b;
                                                           component=:negative))...)
         for b in ("L1", "L2")]
    end
    got = Dict(n => residuals(n) for n in (:squared, :magnitude, :max))
    for n in keys(got); @test !isnothing(got[n]); end

    # Non-vacuous: the residuals are genuinely nonzero, so the comparisons below
    # are between real operating points.
    @test minimum(minimum(v) for v in values(got)) > 1e-6

    spread(v) = maximum(v) - minimum(v)

    # :max is indifferent to everything but the worst target, so it EQUALISES:
    # it lets the better bus drift up rather than spending effort there. That is
    # the minimax signature and it is strictly measurable here.
    @test spread(got[:max]) < spread(got[:squared])
    @test maximum(got[:max]) <= maximum(got[:squared]) + 1e-6

    # Honest negative result: :magnitude and :squared coincide on this fixture.
    # The two laterals are near-symmetric, so there is no reason to prefer
    # zeroing one over the other and a sparsity-inducing norm has nothing to
    # choose. Group-lasso behaviour needs ASYMMETRIC targets -- see the control
    # effort testset below, which constructs exactly that.
    @test got[:magnitude] ≈ got[:squared] rtol=1e-4
end

@testset "epsilon is commensurate across voltage and current, in both unit modes" begin
    # A single `eps_rel` must mean ONE thing everywhere: the same fraction of
    # the quantity's own characteristic magnitude, whether that quantity is a
    # voltage or a current, in per-unit or SI. Otherwise "eps_rel = 1e-3" is
    # 0.1% of a volt in one place and something unrelated in another, and the
    # smoothing guidance measured in bench/sequence_objective_norms.jl does not
    # transfer between term types.
    ctx_pu = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=true,
                                        add_objective=false)
    ctx_si = BMOPFTools.build_opf_model(_obj_net(20_000.0); per_unit=false,
                                        add_objective=false)
    for bus in ("b1", "src")
        v_pu = _OBJEXT._quantity_scale(ctx_pu, :V; bus=bus)
        v_si = _OBJEXT._quantity_scale(ctx_si, :V; bus=bus)
        a_pu = _OBJEXT._quantity_scale(ctx_pu, :A; bus=bus)
        a_si = _OBJEXT._quantity_scale(ctx_si, :A; bus=bus)

        # 1. Mode independence: the characteristic PHYSICAL magnitude is the
        #    same number whichever coordinates the model is built in.
        @test v_pu ≈ v_si rtol=1e-12
        @test a_pu ≈ a_si rtol=1e-12

        # 2. The scales are physically sensible, not accidental 1.0s.
        @test 100.0 < v_pu < 1000.0                    # an LV phase voltage
        @test a_pu > 1.0

        # 3. Cross-unit commensurability: current and voltage scales are tied by
        #    the engine's own i_base = s_base / v_base relation, so eps/scale is
        #    the same fraction for both.
        s_base = ctx_pu.manifest.s_base
        @test a_pu ≈ s_base / v_pu rtol=1e-12
        @test a_si ≈ s_base / v_si rtol=1e-12

        # 4. Therefore a single eps_rel yields equal RELATIVE smoothing on a
        #    voltage penalty and a current penalty, in either mode.
        eps_rel = 1e-3
        @test (eps_rel * v_pu) / v_pu ≈ (eps_rel * a_pu) / a_pu rtol=1e-12
        @test (eps_rel * v_pu) / v_pu ≈ (eps_rel * a_si) / a_si rtol=1e-12
    end
    # Power scale is the system base and needs no bus.
    @test _OBJEXT._quantity_scale(ctx_pu, :W) ≈ _OBJEXT._quantity_scale(ctx_si, :W)
    # Squared units are the square of the linear one, so a :squared penalty's
    # scale stays consistent with its :magnitude counterpart.
    @test _OBJEXT._quantity_scale(ctx_pu, :V2; bus="b1") ≈
          _OBJEXT._quantity_scale(ctx_pu, :V; bus="b1")^2
    @test _OBJEXT._quantity_scale(ctx_pu, :A2; bus="b1") ≈
          _OBJEXT._quantity_scale(ctx_pu, :A; bus="b1")^2
end

@testset "opf_neutral_current — is exactly three times the zero-sequence current" begin
    # Independent cross-check of two separately-derived quantities: for a 4-wire
    # element with no parallel earth path, I_n = -(Ia+Ib+Ic) = -3*I0. The
    # neutral current is read straight off a ledger record; I0 comes from the
    # Fortescue transform. If either the sign convention or the transform were
    # wrong, this exact factor of 3 would not appear.
    ctx = BMOPFTools.build_opf_model(_obj_net_4w(); per_unit=true,
                                     add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    (nr, ni) = BMOPFTools.opf_neutral_current(ctx, "line", "l1"; side=:to)
    (zr, zi) = BMOPFTools.opf_sequence_current(ctx, "line", "l1"; side=:to,
                                               component=:zero)
    JuMP.@objective(m, Min, 0.0); BMOPFTools.enforce_kcl!(ctx)
    JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

    In = hypot(JuMP.value(nr), JuMP.value(ni))
    I0 = hypot(JuMP.value(zr), JuMP.value(zi))
    @test In > 1e-4                      # genuinely unbalanced, not a vacuous pass
    @test In ≈ 3 * I0 rtol=1e-8

    # And in amps it is a physically plausible number for this unbalance.
    In_amps = In * ctx.bases.i_base["b1"]
    @test 5.0 < In_amps < 100.0
end

@testset "opf_neutral_current — refuses a three-wire element" begin
    # Returning zero would make the penalty silently contribute nothing.
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    @test_throws ArgumentError BMOPFTools.opf_neutral_current(ctx, "line", "l1")
    @test_throws ArgumentError BMOPFTools.opf_branch_currents(ctx, "line", "nope")
    @test_throws ArgumentError BMOPFTools.opf_branch_currents(ctx, "line", "l1";
                                                              side=:sideways)
end

@testset "opf_current_term — minimising neutral current actually reduces it" begin
    # With a per-phase STATCOM the compensator can shift current between phases,
    # so a neutral-current objective must move the answer.
    net = _obj_net_4w()
    net["ibr"] = Dict{String,Any}("pv1" => Dict{String,Any}(
        "bus" => "b1", "terminal_map" => ["1","2","3","n"],
        "topology" => "FOUR_LEG", "prime_mover" => "STATCOM",
        "s_max" => [20000.0,20000.0,20000.0],
        "p_max" => [0.0,0.0,0.0], "p_min" => [0.0,0.0,0.0],
        "cost" => [0.0,0.0,0.0]))
    function neutral_under(minimise)
        ctx = BMOPFTools.build_opf_model(deepcopy(net); per_unit=true,
                                         add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        (nr, ni) = BMOPFTools.opf_neutral_current(ctx, "line", "l1"; side=:to)
        if minimise
            t = BMOPFTools.opf_current_term(ctx, [("line","l1",:to)];
                                            quantity=:neutral, norm=:squared)
            BMOPFTools.set_opf_objective!(ctx, [t])
        else
            JuMP.@objective(m, Min, 0.0)
        end
        BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        (JuMP.termination_status(m), hypot(JuMP.value(nr), JuMP.value(ni)))
    end
    (st0, n0) = neutral_under(false)
    (st1, n1) = neutral_under(true)
    @test st0 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test st1 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test n1 < n0
end

@testset "opf_current_term — declares amps and stays unit-mode independent" begin
    function build(pu)
        ctx = BMOPFTools.build_opf_model(_obj_net_4w(); per_unit=pu,
                                         add_objective=false)
        t = BMOPFTools.opf_current_term(ctx, [("line","l1",:to)];
                                        quantity=:sequence, component=:zero,
                                        norm=:magnitude, weight=1.0)
        BMOPFTools.set_opf_objective!(ctx, [t])
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); _obj_tight!(m)
        JuMP.optimize!(m)
        (t.units, JuMP.termination_status(m), JuMP.objective_value(m))
    end
    (u_pu, st_pu, o_pu) = build(true)
    (u_si, st_si, o_si) = build(false)
    @test u_pu == :A && u_si == :A          # :magnitude on a current is amps
    @test st_pu in _OBJ_SOLVED
    @test st_si in _OBJ_SOLVED
    # No loss term here, so no cancellation amplification: the two modes should
    # agree far more tightly than the loss-containing objective does.
    @test o_pu ≈ o_si rtol=1e-6
    @test o_pu > 1.0                        # amps, not a vacuous zero
end

@testset "smooth_norm — vector form groups components under one norm" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    xs = [JuMP.@variable(m) for _ in 1:4]
    e = BMOPFTools.smooth_norm(ctx, xs; scale=1.0, eps_rel=1e-3, annotate=false)
    for v in xs; JuMP.set_start_value(v, 0.0); end
    # A grouped norm of (3,4,0,0) is 5, not 3+4: one norm, not a sum of norms.
    vals = Dict(xs[1] => 3.0, xs[2] => 4.0, xs[3] => 0.0, xs[4] => 0.0)
    got = JuMP.value(z -> vals[z], e)
    @test got ≈ 5.0 rtol=1e-3
    @test 5.0 - got <= 1e-3 + 1e-12          # underestimates by at most eps
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, []; scale=1.0)
    @test_throws ArgumentError BMOPFTools.smooth_norm(ctx, xs; scale=0.0)
end

@testset "opf_control_effort_term — group-lasso concentrates, :squared shrinks" begin
    # The original version asserted only that currents were non-negative, which
    # every norm satisfies. This asserts the property the :magnitude default
    # exists to support.
    #
    # The laterals must be ASYMMETRIC or there is nothing to concentrate: with
    # mirrored loads and equal ratings both compensators move identically under
    # every norm (measured: concentration exactly 0.5 throughout). Here c2 is
    # deliberately under-rated, so preferring c1 is a real choice.
    function movement(norm, weight)
        net = _obj_net_2lat(6_000.0)
        net["ibr"]["c2"]["s_max"] = [700.0, 700.0, 700.0]
        net["ibr"]["c2"]["p_max"] = [350.0, 350.0, 350.0]
        net["ibr"]["c2"]["p_min"] = [-350.0, -350.0, -350.0]
        ctx = BMOPFTools.build_opf_model(net; per_unit=true, add_objective=false)
        terms = [BMOPFTools.opf_sequence_term(ctx, ["L1","L2"]; norm=:squared,
                                              weight=1.0, name=:unbal),
                 BMOPFTools.opf_control_effort_term(ctx, [("ibr","c1"),("ibr","c2")];
                                                    norm=norm, weight=weight)]
        BMOPFTools.set_opf_objective!(ctx, terms)
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL) || return nothing
        crv = ctx.vars[:cri]; civ = ctx.vars[:cii]
        sort([sum(hypot(JuMP.value(crv[k]), JuMP.value(civ[k]))
                  for k in keys(crv) if String(k[1]) == d)
              for d in ("c1", "c2")]; rev=true)
    end
    conc(v) = sum(v) > 0 ? v[1] / sum(v) : 0.5

    for weight in (1e-2, 1e-1)
        sq = movement(:squared, weight); mg = movement(:magnitude, weight)
        @test !isnothing(sq) && !isnothing(mg)
        @test sum(sq) > 1e-8 && sum(mg) > 1e-8      # both actually move

        # A squared penalty's gradient vanishes as movement does, so it shrinks
        # every device toward zero together -- concentration collapses to 0.5. A
        # grouped norm has constant gradient, so it keeps the EFFECTIVE device
        # working instead of shrinking both uniformly.
        @test conc(mg) > conc(sq)
        @test sum(mg) > sum(sq)
    end

    # Not a claim of exact sparsity: neither device is driven to identically
    # zero here. This is relative concentration, which is what a smoothed
    # group-lasso delivers; exact zeros would need a nonconvex or thresholded
    # formulation.
end

@testset "opf_control_effort_term — unit-mode independent" begin
    function run(pu)
        ctx = BMOPFTools.build_opf_model(_obj_net_2lat(); per_unit=pu,
                                         add_objective=false)
        t = BMOPFTools.opf_control_effort_term(ctx, [("ibr","c1"),("ibr","c2")];
                                               norm=:magnitude, weight=1.0)
        BMOPFTools.set_opf_objective!(ctx,
            [BMOPFTools.opf_sequence_term(ctx, ["L1","L2"]; norm=:squared,
                                          weight=1.0, name=:unbal), t])
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); _obj_tight!(m)
        JuMP.optimize!(m)
        (t.units, JuMP.termination_status(m), JuMP.objective_value(m))
    end
    (ua, sa, oa) = run(true); (ub, sb, ob) = run(false)
    @test ua == :A && ub == :A          # :magnitude on a current is amps
    @test sa in _OBJ_SOLVED
    @test sb in _OBJ_SOLVED
    @test oa ≈ ob rtol=1e-4
    @test oa > 1e-3                     # not a vacuous zero
end

@testset "opf_control_effort_term — rejects unsupported targets" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    @test_throws ArgumentError BMOPFTools.opf_control_effort_term(ctx, [])
    @test_throws ArgumentError BMOPFTools.opf_control_effort_term(ctx, [("line","l1")])
    @test_throws ArgumentError BMOPFTools.opf_control_effort_term(ctx, [("ibr","nope")])
end

@testset "opf_vuf_term — demands an enforced vpos_min" begin
    # A ratio whose denominator is decision-dependent is only well posed while a
    # lower bound on |V1| is actually in the model. Refusing is the whole point.
    plain = _obj_net(2_000.0)
    ctx = BMOPFTools.build_opf_model(plain; per_unit=true, add_objective=false)
    @test_throws ArgumentError BMOPFTools.opf_vuf_term(ctx, "b1")
    @test_throws ArgumentError BMOPFTools.opf_vuf_term(ctx, "no_such_bus")
    @test_throws ArgumentError BMOPFTools.opf_vuf_term(ctx, String[])
end

@testset "opf_vuf_term — is the exact squared ratio, in both unit modes" begin
    # Under-rated compensator so the optimum stays bounded away from zero: an
    # agreement check between two effectively-zero numbers proves nothing.
    function run(pu)
        net = _obj_net(400.0); net["bus"]["b1"]["vpos_min"] = 180.0
        ctx = BMOPFTools.build_opf_model(net; per_unit=pu, add_objective=false)
        t = BMOPFTools.opf_vuf_term(ctx, "b1"; weight=1.0)
        BMOPFTools.set_opf_objective!(ctx, [t])
        BMOPFTools.enforce_kcl!(ctx)
        m = BMOPFTools.opf_model(ctx)
        JuMP.set_attribute(m, "print_level", 0); _obj_tight!(m)
        JuMP.optimize!(m)
        v2 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx,"b1"; component=:negative))...)
        v1 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx,"b1"; component=:positive))...)
        (units = t.units, status = JuMP.termination_status(m),
         obj = JuMP.objective_value(m), vuf = 100 * v2 / v1)
    end
    a = run(true); b = run(false)
    @test a.status in _OBJ_SOLVED
    @test b.status in _OBJ_SOLVED
    @test a.units == :percent_squared

    # EXACT: no smoothing anywhere, so the objective is the squared VUF to
    # solver precision -- not to an eps-sized tolerance. This is what the
    # smooth_norm-based formulation could not deliver: with eps sized for
    # conditioning it mis-stated the ratio by more than 40%.
    for r in (a, b)
        @test r.obj ≈ r.vuf^2 rtol=1e-8
        @test 1e-6 < r.obj < 25.0        # genuinely nonzero, and a sane percent^2
    end

    # The ratio is dimensionless, so the voltage base cancels EXACTLY and no
    # scaling error enters the term itself. The residual difference is in the
    # solved operating point: V2 (~0.6 V) is a small difference of large phase
    # voltages (~230 V), so the engine's ~1e-8 pu/SI agreement on voltages is
    # amplified ~380x in V2, and squaring doubles that again. Same cancellation
    # story as a loss-valued quantity, so the same order of tolerance.
    @test a.obj ≈ b.obj rtol=1e-4
    @test a.vuf ≈ b.vuf rtol=1e-4
end

@testset "opf_vuf_term — minimising VUF reduces it" begin
    net = _obj_net(20_000.0); net["bus"]["b1"]["vpos_min"] = 180.0
    function vuf_under(minimise)
        ctx = BMOPFTools.build_opf_model(deepcopy(net); per_unit=true,
                                         add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        if minimise
            BMOPFTools.set_opf_objective!(ctx, [BMOPFTools.opf_vuf_term(ctx, "b1")])
        else
            JuMP.@objective(m, Min, 0.0)
        end
        BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        v2 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx,"b1"; component=:negative))...)
        v1 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx,"b1"; component=:positive))...)
        (JuMP.termination_status(m), 100 * v2 / v1)
    end
    (st0, u0) = vuf_under(false); (st1, u1) = vuf_under(true)
    @test st0 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test st1 in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    @test u1 < u0
end

@testset "epsilon is per-target, not shared across a heterogeneous set" begin
    # The relative-smoothing promise is per TARGET. A single scale taken from
    # the largest target gives every smaller one an eps sized for something
    # else: on a 33 kV / 230 V network that is two orders out at the LV end,
    # which changes that term's gradient and its trade-off weight.
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    mk() = (JuMP.@variable(m), JuMP.@variable(m))
    pairs = [mk(), mk()]
    scales = [1.0, 100.0]
    BMOPFTools.opf_reduce_norm(ctx, pairs; norm=:magnitude, scale=scales,
                               eps_rel=1e-3, name="het")
    ann = collect(values(BMOPFTools.opf_differentiability_annotations(ctx)))
    eps_used = sort([Float64(a.metadata["eps"]) for a in ann])
    scl_used = sort([Float64(a.metadata["scale"]) for a in ann])
    @test length(eps_used) == 2
    # Two DIFFERENT epsilons, each 1e-3 of its own target's scale.
    @test scl_used ≈ scales
    @test eps_used ≈ 1e-3 .* scales
    @test eps_used[2] / eps_used[1] ≈ 100.0 rtol=1e-12
    # ...and therefore identical RELATIVE smoothing, which is the actual promise.
    for a in ann
        @test Float64(a.metadata["eps"]) / Float64(a.metadata["scale"]) ≈ 1e-3 rtol=1e-12
    end

    # Malformed scale vectors are refused rather than silently recycled.
    @test_throws ArgumentError BMOPFTools.opf_reduce_norm(ctx, pairs;
        norm=:magnitude, scale=[1.0, 2.0, 3.0])
    @test_throws ArgumentError BMOPFTools.opf_reduce_norm(ctx, pairs;
        norm=:magnitude, scale=[1.0, 0.0])
end

@testset "sequence current is anchored to bus phase order, not terminal-map order" begin
    # The Fortescue transform assumes its inputs are phases A,B,C in rotational
    # order. Ledger order follows the ELEMENT's terminal map, which is free to
    # permute; feeding a permuted set silently swaps positive and negative
    # sequence. Every map must agree with a hand transform built from the BUS's
    # declared phase order.
    function check(perm)
        net = _obj_net_4w()
        net["line"]["l1"]["terminal_map_to"] = perm
        ctx = BMOPFTools.build_opf_model(net; per_unit=true, add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        got = Dict(c => BMOPFTools.opf_sequence_current(ctx, "line", "l1";
                                                        side=:to, component=c)
                   for c in (:zero, :positive, :negative))
        entries = BMOPFTools.opf_branch_currents(ctx, "line", "l1"; side=:to)
        JuMP.@objective(m, Min, 0.0); BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        byt = Dict(t => JuMP.value(re) + im * JuMP.value(ie) for (t, re, ie) in entries)
        I = [byt[t] for t in ("1", "2", "3")]          # BUS declaration order
        a = exp(im * 2π / 3)
        hand = Dict(:zero     => sum(I) / 3,
                    :positive => (I[1] + a*I[2] + a^2*I[3]) / 3,
                    :negative => (I[1] + a^2*I[2] + a*I[3]) / 3)
        for c in (:zero, :positive, :negative)
            g = JuMP.value(got[c][1]) + im * JuMP.value(got[c][2])
            @test g ≈ hand[c] atol=1e-10
        end
        abs(hand[:negative])
    end
    # Identity, a transposition, a cyclic rotation, and a neutral-first map.
    i2 = [check(p) for p in (["1","2","3","n"], ["2","1","3","n"],
                             ["3","1","2","n"], ["n","3","2","1"])]
    @test all(>(0), i2)
    # A cyclic rotation relabels the same rotational sequence, and this linecode
    # is symmetric (equal diagonals, no mutuals), so it is an equivalent circuit
    # and must reproduce the identity map's negative-sequence magnitude. The
    # tolerance is solver convergence between two separately-solved models, not
    # a modelling difference. A transposition is a genuinely DIFFERENT circuit
    # and is not expected to agree.
    @test i2[3] ≈ i2[1] rtol=1e-5
    @test !isapprox(i2[2], i2[1]; rtol=1e-3)
end

@testset "composed objective — epigraph terms refuse an invalid orientation" begin
    ctx = BMOPFTools.build_opf_model(_obj_net(2_000.0); per_unit=true,
                                     add_objective=false)
    tmax = BMOPFTools.opf_sequence_term(ctx, "b1"; norm=:max, weight=1.0)
    @test tmax.valid_sense == :min

    # `t` is bounded from BELOW by its targets and from above by nothing, so
    # maximising it -- or minimising it with a negative weight -- is unbounded,
    # not merely inaccurate. Refuse instead of handing Ipopt an unbounded model.
    @test_throws ArgumentError BMOPFTools.set_opf_objective!(ctx, [tmax]; sense=:max)
    tneg = BMOPFTools.opf_sequence_term(ctx, "b1"; norm=:max, weight=-1.0,
                                        name=:neg)
    @test_throws ArgumentError BMOPFTools.set_opf_objective!(ctx, [tneg])

    # Non-epigraph reductions carry no such restriction.
    for norm in (:squared, :magnitude)
        t = BMOPFTools.opf_sequence_term(ctx, "b1"; norm=norm)
        @test t.valid_sense == :any
    end
end

@testset "opf_total_loss — default blocks match what results actually total" begin
    # opf_total_loss promises equality with result["losses"]["p_loss"].
    # results.jl totals ONLY lines and transformers, so a default that included
    # switches would make the contract false on any network with one. The
    # earlier test could not catch this: its fixture had no switch.
    net = _obj_net_4w()
    net["bus"]["mid"] = Dict{String,Any}(
        "terminal_names" => ["1","2","3","n"],
        "v_min" => [180.0,180.0,180.0], "v_max" => [280.0,280.0,280.0])
    net["line"]["l1"]["bus_to"] = "mid"
    net["switch"] = Dict{String,Any}("sw1" => Dict{String,Any}(
        "bus_from" => "mid", "bus_to" => "b1",
        "terminal_map_from" => ["1","2","3","n"],
        "terminal_map_to" => ["1","2","3","n"], "status" => "CLOSED"))
    ctx = BMOPFTools.build_opf_model(net; per_unit=true, add_objective=false)
    m = BMOPFTools.opf_model(ctx)
    # Switches are NOT ledger-recorded: branch.jl calls _kcl_add! for them
    # without an `entry`, so this collection is always empty. Offering "switch"
    # as a loss block would be a silent no-op returning exactly zero.
    @test isempty(get(ctx.branch_inj, "switch", Dict()))
    total = BMOPFTools.opf_total_loss(ctx)                        # default blocks
    JuMP.@objective(m, Min, 0.0); BMOPFTools.enforce_kcl!(ctx)
    JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
    @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)
    res = BMOPFTools.extract_result(ctx)
    @test JuMP.value(total) * ctx.bases.s_base ≈ res["losses"]["p_loss"] rtol=1e-8
    @test res["losses"]["p_loss"] > 1.0
    # Asking for switch loss is refused, not answered with a misleading zero.
    @test_throws ArgumentError BMOPFTools.opf_total_loss(ctx;
        blocks=("line","transformer","switch"))
    @test_throws ArgumentError BMOPFTools.opf_element_loss(ctx, "switch", "sw1")
end

@testset "vuf_max — an exact ratio bound, not a nominal-voltage approximation" begin
    # `vneg_max` bounds |V2| ABSOLUTELY; a standard's unbalance limit is the
    # RATIO |V2|/|V1|. They coincide only if |V1| is treated as fixed nominal.
    # `vuf_max` is the exact instantaneous constraint |V2|^2 <= u^2 |V1|^2.
    #
    # Exercised under the generation-cost objective, NOT a `Min 0.0` feasibility
    # solve. A feasibility problem has no unique solution — Ipopt stops at
    # whatever interior point the barrier happens to reach — so under `Min 0.0`
    # neither "the bound is active" nor "pu agrees with SI" is a testable
    # property, and a bound the compensator cannot reach surfaces as
    # ITERATION_LIMIT rather than LOCALLY_INFEASIBLE. With a real objective the
    # constrained optimum is determinate and the bound is genuinely active.
    vuf_of(ctx) = begin
        v2 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx, "b1";
                                                               component=:negative))...)
        v1 = hypot(JuMP.value.(BMOPFTools.opf_sequence_voltage(ctx, "b1";
                                                               component=:positive))...)
        v2 / v1
    end
    function solve_with(bound, pu; tol=nothing)
        net = _obj_net(4000.0)          # enough authority to reach the bound
        bound === nothing || (net["bus"]["b1"]["vuf_max"] = bound)
        ctx = BMOPFTools.build_opf_model(net; per_unit=pu)
        m = BMOPFTools.opf_model(ctx)
        BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0)
        if tol !== nothing
            JuMP.set_attribute(m, "tol", tol)
            JuMP.set_attribute(m, "constr_viol_tol", tol)
            JuMP.set_attribute(m, "acceptable_constr_viol_tol", tol)
        end
        JuMP.optimize!(m)
        (JuMP.termination_status(m), vuf_of(ctx))
    end

    # Unconstrained: a determinate optimum, so the two unit modes must agree
    # tightly. Measured 5.6e-8.
    (st_free_pu, free)    = solve_with(nothing, true)
    (st_free_si, free_si) = solve_with(nothing, false)
    @test st_free_pu in _OBJ_SOLVED
    @test st_free_si in _OBJ_SOLVED
    @test free > 1e-4                      # genuinely unbalanced to begin with
    @test free ≈ free_si rtol=1e-6

    # A bound below the unconstrained optimum must become ACTIVE, not merely
    # respected: the cost-optimal point sits on it.
    limit = 0.5 * free
    (st_pu, v_pu) = solve_with(limit, true)
    (st_si, v_si) = solve_with(limit, false)
    @test st_pu in _OBJ_SOLVED
    @test st_si in _OBJ_SOLVED
    @test v_pu ≈ limit rtol=5e-3
    @test v_si ≈ limit rtol=5e-3
    @test v_pu < free && v_si < free

    # DIMENSIONLESS: alone among the bus voltage bounds it must NOT be rescaled
    # between unit modes — the same number means the same limit in both.
    #
    # The agreement tolerance is 5e-3, not 1e-6, and that is a property of the
    # SOLVER, not of the constraint. The residual `|V2|^2 - u^2 |V1|^2` is
    # dimensionful (volts^2) while `u` is not, so its absolute magnitude differs
    # between modes by v_base^2 ~ 5e4. Ipopt's `constr_viol_tol` is ABSOLUTE, so
    # at default tolerance the same bound is enforced to ~2e-3 relative in
    # per-unit and ~1e-7 relative in SI.
    @test v_pu ≈ v_si rtol=5e-3

    # Proof that the gap above is tolerance and not a scaling defect: tightening
    # `constr_viol_tol` drives the per-unit overshoot to zero (2.2e-3 at
    # default, 2.0e-5 at 1e-10, 2.2e-7 at 1e-12). A mis-scaled bound would not
    # improve with tolerance.
    (st_tight, v_tight) = solve_with(limit, true; tol=1e-10)
    @test st_tight in _OBJ_SOLVED
    @test (v_tight - limit) / limit < 1e-4
    # Deliberately NOT asserted as a strict improvement over `v_pu`: if a
    # platform happens to land the default-tolerance solve already on the
    # bound there is nothing left to improve, and the comparison would fail
    # for a reason that says nothing about the code.

    # A slack bound leaves the answer alone.
    (st2, slack) = solve_with(10.0 * free, true)
    @test st2 in _OBJ_SOLVED
    @test slack ≈ free rtol=1e-4
end

@testset "post-solve reporting helpers agree with hand computation" begin
    for pu in (true, false)
        net = _obj_net_4w(); net["bus"]["b1"]["vpos_min"] = 180.0
        ctx = BMOPFTools.build_opf_model(net; per_unit=pu, add_objective=false)
        m = BMOPFTools.opf_model(ctx)
        JuMP.@objective(m, Min, 0.0); BMOPFTools.enforce_kcl!(ctx)
        JuMP.set_attribute(m, "print_level", 0); JuMP.optimize!(m)
        @test JuMP.termination_status(m) in (JuMP.LOCALLY_SOLVED, JuMP.OPTIMAL)

        v2 = BMOPFTools.opf_report_sequence_voltage(ctx, "b1"; component=:negative)
        v1 = BMOPFTools.opf_report_sequence_voltage(ctx, "b1"; component=:positive)
        vuf = BMOPFTools.opf_report_vuf(ctx, "b1")
        In  = BMOPFTools.opf_report_current(ctx, "line", "l1"; side=:to,
                                            quantity=:neutral)
        I0  = BMOPFTools.opf_report_current(ctx, "line", "l1"; side=:to,
                                            quantity=:sequence, component=:zero)

        @test 200.0 < v1 < 260.0            # volts, not per-unit
        @test 0.0 < v2 < 20.0
        @test vuf ≈ 100 * v2 / v1 rtol=1e-9
        @test 5.0 < In < 100.0              # amps
        @test In ≈ 3 * I0 rtol=1e-8
        @test BMOPFTools.opf_report_vuf(ctx, "b1"; percent=false) ≈ vuf / 100 rtol=1e-12
    end
end
