# Minimized engine regression witnesses. The angle oracle uses complex phasors;
# the reverse-flow oracle uses S = V*conj(I) at each end independently.
@testset "OPF engine scientific review regressions" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)

    @testset "zero-radius limits have linear, nondegenerate rows" begin
        model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(model)
        x = JuMP.@variable(model); y = JuMP.@variable(model)
        cref = E._soc_norm!(model, x + y, x - y, 0.0)
        @test JuMP.constraint_object(cref).set == JuMP.MOI.Zeros(2)
        @test all(f isa JuMP.AffExpr for f in JuMP.constraint_object(cref).func)
        @test E._soc_norm!(model, 0.0, 0.0, 0.0) === nothing
        E._limit_current_box!(x, y, 0.0)
        @test !JuMP.has_lower_bound(x) && !JuMP.has_upper_bound(x)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) == JuMP.MOI.LOCALLY_SOLVED
        @test abs(JuMP.value(x)) <= 1e-9
        @test abs(JuMP.value(y)) <= 1e-9
        @test length(JuMP.dual(cref)) == 2
        @test E._optimization_profile(model)["n_eq_constraints"] == 2
        @test E._constraint_residual_summary(model)["unsupported_constraints"] == 0
        # A zero neutral-current limit constrains the sum, not each phase.
        m = JuMP.Model()
        a = JuMP.@variable(m); b = JuMP.@variable(m)
        neutral = E._neutral_current_limit!(m, [a, b], [0.0, 0.0], 0.0)
        @test JuMP.constraint_object(neutral).set == JuMP.MOI.EqualTo(0.0)
        @test isempty(JuMP.primal_feasibility_report(m, Dict(a => 1.0, b => -1.0)))
        @test !isempty(JuMP.primal_feasibility_report(m, Dict(a => 1.0, b => 0.0)))
        scalar = E._soc_norm!(m, a, 0.0)
        @test JuMP.constraint_object(scalar).set == JuMP.MOI.EqualTo(0.0)
        positive = E._soc_norm!(m, a, b, 2.0)
        @test JuMP.constraint_object(positive).set == JuMP.MOI.LessThan(1.0)
    end

    @testset "reactance-only multi-conductor linecode" begin
        lc = Dict{String,Any}("X_series_1_1" => 1.0,
            "X_series_1_2" => 0.2, "X_series_2_2" => 2.0)
        line = Dict{String,Any}("linecode" => "x", "length" => 3.0)
        R, X, n = E._line_z_matrix(line, Dict("x" => lc))
        @test n == 2
        @test R == zeros(2, 2)
        @test X ≈ 3 .* [1.0 0.2; 0.2 2.0]
        inline = deepcopy(lc); inline["length"] = 3.0
        Ri, Xi, ni = E._line_z_matrix(inline, Dict())
        @test ni == 2
        @test Ri == R
        @test Xi ≈ X ./ 3 # inline matrices are section totals
    end

    @testset "rated open switch" begin
        model = JuMP.Model()
        net = Dict{String,Any}("switch" => Dict("s" => Dict{String,Any}(
            "bus_from" => "f", "bus_to" => "t", "open_switch" => true,
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
            "i_max" => [10.0], "s_max" => [10.0])))
        cr, ci = E._add_switch_variables!(model, net)
        bt = Dict("f" => ["1"], "t" => ["1"])
        vr, vi = E._add_voltage_variables!(model, bt, Set())
        kr, ki = E._init_kcl(bt)
        E._add_switch_constraints!(model, net,
            Dict(:vr => vr, :vi => vi, :cr_sw => cr, :ci_sw => ci), kr, ki)
        @test JuMP.is_fixed(cr[("s", 1)])
        @test JuMP.fix_value(cr[("s", 1)]) == 0.0
        @test JuMP.is_fixed(ci[("s", 1)])
        @test JuMP.num_variables(model) == 6 # no vacuous P/Q auxiliaries
    end

    @testset "conflicting fixed voltage references" begin
        source(v, a=0.0) = Dict{String,Any}("bus" => "b", "terminal_map" => ["1"],
                                           "v_magnitude" => [v], "v_angle" => [a])
        net = Dict{String,Any}(
            "bus" => Dict("b" => Dict{String,Any}("terminal_names" => ["1"])),
            "voltage_source" => Dict("a" => source(1.0), "b" => source(2.0)))
        for pu in (false, true)
            @test_throws ArgumentError build_opf_model(net; per_unit=pu)
        end
        net["voltage_source"]["b"] = source(1.0, 2pi)
        @test build_opf_model(net; per_unit=false) isa E.OpfContext
        net["voltage_source"]["b"] = source(1.0, pi/2)
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
        delete!(net["voltage_source"], "b")
        net["bus"]["b"]["perfectly_grounded_terminals"] = ["1"]
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
    end

    # Evaluate the stamped rows at specified phasors, without relying on local
    # solver convergence or duplicating the rectangular angle formula.
    function angle_point_ok(theta, lo, hi)
        model = JuMP.Model()
        bt = Dict("f" => ["1"], "t" => ["1"])
        vr, vi = E._add_voltage_variables!(model, bt, Set())
        line = Dict{String,Any}("bus_from" => "f", "bus_to" => "t",
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"])
        lo !== nothing && (line["va_diff_min"] = lo)
        hi !== nothing && (line["va_diff_max"] = hi)
        E._add_line_angle_constraints!(model,
            Dict("line" => Dict("l" => line)), Dict(:vr => vr, :vi => vi))
        vf, vt = cis(theta), 1.0 + 0im
        point = Dict(vr[("f", "1")] => real(vf), vi[("f", "1")] => imag(vf),
                     vr[("t", "1")] => real(vt), vi[("t", "1")] => imag(vt))
        return isempty(JuMP.primal_feasibility_report(model, point; atol=1e-10))
    end

    @testset "signed branch angle and tangent domain" begin
        @test angle_point_ok(0.1, 0.0, 0.2)
        @test !angle_point_ok(-0.1, 0.0, 0.2)
        @test angle_point_ok(0.0, 0.0, 0.2)
        @test angle_point_ok(0.2, 0.0, 0.2)
        @test angle_point_ok(-0.1, -0.2, 0.0)
        @test !angle_point_ok(0.1, -0.2, 0.0)
        @test !angle_point_ok(pi, 0.0, 0.0)
        @test_throws ArgumentError angle_point_ok(-3.0, nothing, 0.2)
        @test_throws ArgumentError angle_point_ok(0.1, nothing, 0.2)
        @test_throws ArgumentError angle_point_ok(-0.1, -0.2, nothing)
        @test_throws ArgumentError angle_point_ok(3.0, -0.2, nothing)
        @test angle_point_ok(3.0, nothing, nothing)
        @test_throws ArgumentError angle_point_ok(0.0, -2.0, 0.2)
        @test_throws ArgumentError angle_point_ok(0.0, 0.2, 0.1)
        @test_throws ArgumentError angle_point_ok(0.0, nothing, pi/2)
        @test_throws ArgumentError angle_point_ok(0.0, NaN, nothing)
    end

    @testset "bounded angle coefficients and exact targets" begin
        model = JuMP.Model()
        s = JuMP.@variable(model); c = JuMP.@variable(model)
        lo, hi = E._angle_window(-pi/2 + 1e-12, pi/2 - 1e-12, "test")
        rows = E._angle_window_constraints!(model, s, c, lo, hi)
        @test keys(rows) == (:lower, :upper)
        for row in rows
            f = JuMP.constraint_object(row).func
            @test all(abs(coef) <= 1 for (coef, _) in JuMP.linear_terms(f))
        end
        for theta in (-1.4, 0.0, 1.4)
            @test isempty(JuMP.primal_feasibility_report(model,
                Dict(s => sin(theta), c => cos(theta)); atol=1e-14))
        end
        @test !isempty(JuMP.primal_feasibility_report(model,
            Dict(s => 0.0, c => -1.0); atol=1e-14))
        exact_model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(exact_model)
        x = JuMP.@variable(exact_model, start=0.1)
        y = JuMP.@variable(exact_model, start=1.0)
        exact = E._angle_window_constraints!(exact_model, x, y, 0.2, 0.2)
        @test keys(exact) == (:equality, :domain)
        @test JuMP.constraint_object(exact.equality).set == JuMP.MOI.EqualTo(0.0)
        @test E._optimization_profile(exact_model)["n_eq_constraints"] == 1
        JuMP.@constraint(exact_model, y == 1.0)
        JuMP.optimize!(exact_model)
        @test JuMP.termination_status(exact_model) == JuMP.MOI.LOCALLY_SOLVED
        @test JuMP.value(x) ≈ tan(0.2) atol=1e-8
    end

    function bus_angle_point_ok(theta, lo, hi; nominal=nothing, magnitude=1.0,
                                reverse=false, rotation=0.0)
        model = JuMP.Model()
        terminals = reverse ? ["b", "a"] : ["a", "b"]
        bt = Dict("bus" => terminals)
        bus = Dict{String,Any}("terminal_names" => terminals)
        lo !== nothing && (bus["va_diff_min"] = lo)
        hi !== nothing && (bus["va_diff_max"] = hi)
        nominal !== nothing && (bus["va_nom"] = nominal)
        # Use the public serialization boundary before stamping the witness.
        io = IOBuffer(); write_bmopf(Dict{String,Any}("bus" => Dict("bus" => bus)), io)
        net = parse_bmopf(String(take!(io)); from_string=true)
        vr, vi = E._add_voltage_variables!(model, bt, Set())
        E._add_bus_limit_constraints!(model, net, bt, Set(), Dict(:vr => vr, :vi => vi))
        phasors = [cis(rotation), magnitude * cis(rotation + theta)]
        point = Dict(v => part(phasors[k]) for (k, t) in enumerate(terminals)
                     for (v, part) in ((vr[("bus", t)], real), (vi[("bus", t)], imag)))
        return isempty(JuMP.primal_feasibility_report(model, point; atol=1e-10))
    end

    @testset "centered bus angle domain and phasor oracle" begin
        for offset in (0.0, -2pi/3, pi), reverse in (false, true), rotation in (0.0, 1.1)
            nominal = [0.0, offset]
            for deviation in (-0.3, -0.1, 0.0, 0.2, 0.4, pi)
                # Independent principal-angle oracle, including branch cuts.
                centered = angle(cis(offset + deviation) / cis(offset))
                expected = -0.1 - 1e-12 <= centered <= 0.2 + 1e-12
                @test bus_angle_point_ok(offset + deviation, -0.1, 0.2;
                    nominal, reverse, rotation) == expected
            end
            @test bus_angle_point_ok(offset + 0.1, 0.1, 0.1; nominal, reverse, rotation)
            @test !bus_angle_point_ok(offset + 0.1 + pi, 0.1, 0.1; nominal, reverse, rotation)
        end
        @test bus_angle_point_ok(0.1, 0.0, 0.2) # absent nominal means zero offset
        @test bus_angle_point_ok(pi, 0.0, 0.0; magnitude=0.0) # undefined angle
        @test angle_point_ok(0.1, 0.1, 0.1)
        @test !angle_point_ok(0.1 + pi, 0.1, 0.1)
        for (lo, hi) in ((nothing, 0.1), (-0.1, nothing), (-pi/2, 0.1),
                         (-0.1, pi/2), (0.2, 0.1), ([0.0], 0.1))
            @test_throws ArgumentError bus_angle_point_ok(0.0, lo, hi)
            @test_throws ArgumentError angle_point_ok(0.0, lo, hi)
        end
        for bound in (Inf, -Inf, NaN, "bad")
            @test_throws ArgumentError E._angle_window(bound, 0.1, "test")
            @test_throws ArgumentError E._angle_window(-0.1, bound, "test")
        end
        for nominal in (0.0, [0.0], [0.0, 0.1, 0.2], [0.0, "bad"])
            @test_throws ArgumentError bus_angle_point_ok(0.0, -0.1, 0.1; nominal)
        end
    end

    @testset "angle semantic keys reflect equality versus interval" begin
        net = parse_bmopf("""
        {"bus":{"f":{"terminal_names":["a","b"]},
                "t":{"terminal_names":["a","b"],"va_diff_min":0,"va_diff_max":0}},
         "voltage_source":{"s":{"bus":"f","terminal_map":["a","b"],
                                   "v_magnitude":[1,1],"v_angle":[0,0]}},
         "line":{"l":{"bus_from":"f","bus_to":"t",
                        "terminal_map_from":["a","b"],"terminal_map_to":["a","b"],
                        "R_series_1_1":1,"R_series_2_2":1,
                        "va_diff_min":0,"va_diff_max":0}}}
        """; from_string=true)
        for width in (0.0, 0.1), per_unit in (false, true)
            net["bus"]["t"]["va_diff_max"] = width
            net["line"]["l"]["va_diff_max"] = width
            ctx = build_opf_model(net; per_unit)
            for (prefix, index) in ((:bus_angle_, ("t", 1, 2)),
                                     (:line_angle_, ("l", 1)))
                suffixes = iszero(width) ? (:equality, :domain) : (:lower, :upper)
                for suffix in suffixes
                    key = OpfModelKey(:constraint, Symbol(prefix, suffix), index)
                    @test key in opf_object_keys(ctx)
                    if suffix == :equality
                        @test JuMP.constraint_object(opf_object(ctx, key)).set == JuMP.MOI.EqualTo(0.0)
                    end
                end
                absent = iszero(width) ? :lower : :equality
                @test OpfModelKey(:constraint, Symbol(prefix, absent), index) ∉ opf_object_keys(ctx)
            end
        end
    end

    @testset "both line-end apparent powers, including reverse flow" begin
        # V_f=1, V_t=2, R=1 => I_f=-1. Thus |S_f|=1, |S_t|=2.
        # Swapping branch orientation must not change feasibility.
        for reverse in (false, true), per_unit in (false, true), cap in (1.5, 2.1)
            f, t = reverse ? ("t", "f") : ("f", "t")
            net = Dict{String,Any}(
                "bus" => Dict(b => Dict{String,Any}("terminal_names" => ["1"])
                              for b in ("f", "t")),
                "voltage_source" => Dict(b => Dict{String,Any}("bus" => b,
                    "terminal_map" => ["1"], "v_magnitude" => [v],
                    "v_angle" => [0.0]) for (b, v) in (("f", 1.0), ("t", 2.0))),
                "line" => Dict("l" => Dict{String,Any}(
                    "bus_from" => f, "bus_to" => t,
                    "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
                    "R_series_1_1" => 1.0, "s_max" => [cap])))
            # Also exercise the public JSON serialization boundary.
            io = IOBuffer(); write_bmopf(net, io)
            net = parse_bmopf(String(take!(io)); from_string=true)
            result = solve_opf(net; per_unit=per_unit,
                               s_base=per_unit ? 10.0 : 1.0e6)
            if cap > 2.0
                @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                @test result["bus"]["f"]["1"]["vm"] ≈ 1.0 atol=1e-7
                @test result["bus"]["t"]["1"]["vm"] ≈ 2.0 atol=1e-7
            else
                @test result["termination_status"] == "LOCALLY_INFEASIBLE"
            end
        end
    end
end
