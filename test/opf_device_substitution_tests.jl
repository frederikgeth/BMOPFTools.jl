# Analytic device witnesses; PSK-000013 linkage is recorded in executable.toml.
@testset "OPF device connections and structural substitutions" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    roundtrip(net) = begin
        io = IOBuffer(); write_bmopf(net, io)
        parse_bmopf(String(take!(io)); from_string=true)
    end
    function source_net(terminals, magnitudes, angles; grounded=String[])
        Dict{String,Any}(
            "bus" => Dict("b" => Dict{String,Any}("terminal_names" => terminals,
                         "perfectly_grounded_terminals" => grounded)),
            "voltage_source" => Dict("s" => Dict{String,Any}("bus" => "b",
                "terminal_map" => terminals, "v_magnitude" => magnitudes,
                "v_angle" => angles)))
    end

    @testset "single-phase generator coil, both orientations and limits" begin
        for tm in (["a", "b"], ["b", "a"]), pu in (false, true)
            net = source_net(["a", "b"], [120.0, 120.0], [0.0, pi])
            net["generator"] = Dict("g" => Dict{String,Any}("bus" => "b",
                "configuration" => "SINGLE_PHASE", "terminal_map" => tm,
                "p_min" => [2400.0], "p_max" => [2400.0],
                "q_min" => [1200.0], "q_max" => [1200.0],
                "i_max" => [20.0, 12.0], "s_max" => [3000.0], "cost" => [0.2]))
            net = roundtrip(net)
            ctx = build_opf_model(net; per_unit=pu)
            for (key, val) in (("bound_relax_factor", 0.0), ("tol", 1e-10),
                               ("constr_viol_tol", 1e-10))
                JuMP.set_optimizer_attribute(opf_model(ctx), key, val)
            end
            @test OpfModelKey(:variable, :crg, ("g", 2)) ∉ opf_object_keys(ctx)
            enforce_kcl!(ctx); JuMP.optimize!(opf_model(ctx))
            res = extract_result(ctx)
            @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            g = res["generator"]["g"][tm[1]]
            @test length(res["generator"]["g"]) == 1
            @test g["pg"] ≈ 2400.0 atol=1e-3
            @test g["qg"] ≈ 1200.0 atol=1e-3
            @test g["crg"] + im*g["cig"] ≈
                (tm[1] == "a" ? 1 : -1) * (10 - 5im) atol=1e-5
            @test res["objective"] ≈ 0.48 atol=1e-6
            currents = res["voltage_source"]["s"]
            @test currents["a"]["cr"] + currents["b"]["cr"] ≈ 0.0 atol=1e-6
            @test currents["a"]["ci"] + currents["b"]["ci"] ≈ 0.0 atol=1e-6
            # The second conductor's tighter cap limits the same coil current.
            net["generator"]["g"]["i_max"] = [20.0, 10.0]
            @test solve_opf(net; per_unit=pu)["termination_status"] == "LOCALLY_INFEASIBLE"
        end
    end

    @testset "DELTA generator cost equals sum of coil powers" begin
        for pu in (false, true)
            net = source_net(["a", "b", "c"], fill(120.0, 3), [0.0, -2pi/3, 2pi/3])
            p = [300.0, 500.0, 900.0]; q = [20.0, -30.0, 40.0]
            costs = [0.1, 0.2, 0.3]
            net["generator"] = Dict("g" => Dict{String,Any}("bus" => "b",
                "configuration" => "DELTA", "terminal_map" => ["a", "b", "c"],
                "p_min" => p, "p_max" => p, "q_min" => q, "q_max" => q,
                "cost" => costs))
            res = solve_opf(roundtrip(net); per_unit=pu, solver_options=(
                "bound_relax_factor" => 0.0, "tol" => 1e-10, "constr_viol_tol" => 1e-10))
            @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test res["objective"] ≈ sum(costs .* p)/1000 atol=1e-7
            for (k, t) in enumerate(["a", "b", "c"])
                @test res["generator"]["g"][t]["pg"] ≈ p[k] atol=1e-4
            end
        end
    end

    function load_net(v, model; impedance=false)
        net = source_net(["a", "n"], [v, 0.0], [0.0, 0.0]; grounded=["n"])
        load = Dict{String,Any}("bus" => "b", "configuration" => "SINGLE_PHASE",
            "terminal_map" => ["a", "n"], "p_nom" => [3.0], "q_nom" => [1.5],
            "v_nom" => [1.0], "model" => model)
        if model == "zip"
            for (z, i, p) in (("alpha_z", "alpha_i", "alpha_p"),
                              ("beta_z", "beta_i", "beta_p"))
                load[z] = [impedance ? 1.0 : 0.0]
                load[i] = [0.0]; load[p] = [impedance ? 0.0 : 1.0]
            end
        elseif model == "exponential"
            load["gamma_p"] = load["gamma_q"] = [impedance ? 2.0 : 0.0]
        end
        net["load"] = Dict("d" => load)
        return roundtrip(net)
    end

    @testset "constant-P equivalents have no implicit voltage band" begin
        for v in (0.25, 2.0), model in ("constant_power", "zip", "exponential"), pu in (false, true)
            net = load_net(v, model)
            ctx = build_opf_model(net; per_unit=pu)
            @test all(k.family != :load_voltage_squared for k in opf_object_keys(ctx))
            enforce_kcl!(ctx); JuMP.optimize!(opf_model(ctx))
            res = extract_result(ctx)
            @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            d = res["load"]["d"]["a"]
            @test d["pd"] ≈ 3.0 atol=1e-6
            @test d["qd"] ≈ 1.5 atol=1e-6
            @test d["crd"] + im*d["cid"] ≈ (3 - 1.5im)/v atol=1e-5
        end
    end

    @testset "pure-Z laws remain affine, including zero voltage" begin
        for v in (0.0, 0.25, 2.0), model in ("constant_impedance", "zip", "exponential"), pu in (false, true)
            v == 0 && pu && continue # a zero source does not define a PU voltage base
            net = load_net(v, model; impedance=true)
            ctx = build_opf_model(net; per_unit=pu)
            @test all(k.family != :load_voltage_squared for k in opf_object_keys(ctx))
            for family in (:load_impedance_current_real, :load_impedance_current_imag)
                row = opf_object(ctx, OpfModelKey(:constraint, family, ("d", 1)))
                @test JuMP.constraint_object(row).func isa JuMP.AffExpr
            end
            enforce_kcl!(ctx); JuMP.optimize!(opf_model(ctx))
            res = extract_result(ctx)
            @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            d = res["load"]["d"]["a"]
            @test d["pd"] ≈ 3v^2 atol=1e-5
            @test d["qd"] ≈ 1.5v^2 atol=1e-5
            @test d["crd"] + im*d["cid"] ≈ (3 - 1.5im)*v atol=1e-5
            blocks = BMOPFTools.opf_semantic_blocks(ctx)
            @test any(b -> b.quantity == :current &&
                first(b.members).family == :load_impedance_current_real, blocks)
        end
    end

    @testset "symbolic load powers survive zero-to-nonzero updates" begin
        for (model_name, impedance) in (("zip", false), ("constant_impedance", true))
            net = load_net(2.0, model_name; impedance=impedance)
            model = JuMP.Model(Ipopt.Optimizer)
            p = JuMP.@variable(model, set=JuMP.Parameter(0.0))
            key = OpfCoefficientKey(:load, :load, "d", :p_nom, 1)
            spec = OpfBuildSpec(coefficient_providers=Dict(key =>
                OpfCoefficientProvider(:SubstitutionTest, (ctx, seen, default) -> p)))
            ctx = build_opf_model(net; model, build_spec=spec, per_unit=false)
            enforce_kcl!(ctx)
            nvar = JuMP.num_variables(model)
            ncon = JuMP.num_constraints(model; count_variable_in_set_constraints=true)
            for pnom in (0.0, 3.0, 0.0)
                JuMP.set_parameter_value(p, pnom)
                JuMP.optimize!(model)
                res = extract_result(ctx)
                @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                @test res["load"]["d"]["a"]["pd"] ≈
                    pnom * (impedance ? 4.0 : 1.0) atol=1e-6
            end
            @test JuMP.num_variables(model) == nvar
            @test JuMP.num_constraints(model; count_variable_in_set_constraints=true) == ncon
        end
    end

    @testset "WYE and DELTA impedance currents use their coil voltages" begin
        terminals = ["a", "b", "c"]
        voltages = cis.([0.0, -2pi/3, 2pi/3])
        for cfg in ("WYE", "DELTA"), pu in (false, true)
            net = source_net(terminals, ones(3), angle.(voltages))
            net["load"] = Dict("d" => Dict{String,Any}("bus" => "b",
                "configuration" => cfg, "terminal_map" => terminals,
                "p_nom" => fill(3.0, 3), "q_nom" => fill(1.5, 3),
                "model" => "constant_impedance", "v_nom" => [1.0]))
            res = solve_opf(roundtrip(net); per_unit=pu)
            @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            for (k, t) in enumerate(terminals)
                dv = cfg == "DELTA" ? voltages[k] - voltages[mod1(k+1, 3)] : voltages[k]
                d = res["load"]["d"][t]
                @test d["crd"] + im*d["cid"] ≈ (3 - 1.5im)*dv atol=1e-6
                @test d["pd"] + im*d["qd"] ≈ (3 + 1.5im)*abs2(dv) atol=1e-5
            end
        end
    end

    @testset "consistent magnitude starts and finite nominal voltages" begin
        net = load_net(1.2, "constant_current")
        ctx = build_opf_model(net; per_unit=false)
        W = opf_object(ctx, OpfModelKey(:variable, :load_voltage_squared, ("d", 1)))
        s = opf_object(ctx, OpfModelKey(:variable, :load_voltage_magnitude, ("d", 1)))
        @test JuMP.start_value(W) ≈ 1.2^2
        @test JuMP.start_value(s) ≈ 1.2
        for vnom in (0.0, -1.0, Inf, NaN)
            net["load"]["d"]["v_nom"] = [vnom]
            @test_throws ErrorException build_opf_model(net; per_unit=false)
        end
    end
end
