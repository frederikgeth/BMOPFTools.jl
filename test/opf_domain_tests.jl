using MadNLP

# Independent coil-current and series-drop oracles, linked to PSK-000013.
@testset "OPF positive-voltage domains and solver parity" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    function domain_fixture(v, law; bounded=false)
        load = Dict{String,Any}("bus"=>"t", "terminal_map"=>["a","n"],
            "configuration"=>"SINGLE_PHASE", "model"=>startswith(law, "exponential") ? "exponential" : law,
            "p_nom"=>[0.3], "q_nom"=>[0.15], "v_nom"=>[1.0])
        factor = if law == "zip"
            for keys in (("alpha_z","alpha_i","alpha_p"), ("beta_z","beta_i","beta_p"))
                for (key, weight) in zip(keys, (0.2, 0.3, 0.5))
                    load[key] = [weight]
                end
            end
            0.2v^2 + 0.3v + 0.5
        elseif startswith(law, "exponential")
            gamma = law == "exponential_negative" ? -0.5 : law == "exponential_four" ? 4.0 : 1.5
            load["gamma_p"] = load["gamma_q"] = [gamma]
            v^gamma
        else
            v
        end
        current = (0.3 - 0.15im) * factor / v
        source = v + 0.02current # phase AND neutral each have R=0.01
        net = Dict{String,Any}(
            "bus" => Dict("f"=>Dict{String,Any}("terminal_names"=>["a","n"]),
                          "t"=>Dict{String,Any}("terminal_names"=>["a","n"])),
            "voltage_source"=>Dict("s"=>Dict{String,Any}("bus"=>"f",
                "terminal_map"=>["a","n"], "v_magnitude"=>[abs(source),0], "v_angle"=>[angle(source),0])),
            "line"=>Dict("l"=>Dict{String,Any}("bus_from"=>"f", "bus_to"=>"t",
                "terminal_map_from"=>["a","n"], "terminal_map_to"=>["a","n"],
                "R_series_1_1"=>0.01, "R_series_2_2"=>0.01)),
            "load"=>Dict("d"=>load))
        bounded && (net["bus"]["t"]["vpn_min"] = [v/2])
        io=IOBuffer(); write_bmopf(net, io)
        return parse_bmopf(String(take!(io)); from_string=true), current
    end

    for optimizer in (Ipopt.Optimizer, MadNLP.Optimizer), pu in (false,true),
        bounded in (false,true), v in (0.25,2.0), law in ("constant_current","zip","exponential","exponential_negative","exponential_four")
        net, current = domain_fixture(v, law; bounded)
        ctx = build_opf_model(net; optimizer, per_unit=pu, s_base=10.0)
        model = opf_model(ctx)
        JuMP.set_optimizer_attribute(model, "tol", 1e-10)
        JuMP.set_optimizer_attribute(model, "bound_relax_factor", 0.0)
        log_key = OpfModelKey(:variable, :load_log_voltage_magnitude, ("d",1))
        @test (log_key in opf_object_keys(ctx)) == !bounded
        @test all(k.family ∉ (:load_voltage_squared_upper_bound, :load_voltage_magnitude_upper_bound)
                  for k in opf_object_keys(ctx; kind=:constraint))
        enforce_kcl!(ctx); JuMP.optimize!(model)
        @test JuMP.termination_status(model) in (JuMP.MOI.LOCALLY_SOLVED, JuMP.MOI.OPTIMAL)
        res = extract_result(ctx)
        d = res["load"]["d"]["a"]
        @test complex(d["crd"], d["cid"]) ≈ current atol=1e-6
        @test complex(d["pd"], d["qd"]) ≈ v*conj(current) atol=1e-6
        b = res["bus"]["t"]
        @test complex(b["a"]["vr"]-b["n"]["vr"], b["a"]["vi"]-b["n"]["vi"]) ≈ v atol=1e-6
        @test E._constraint_residual_summary(model)["max_primal_violation"] < 1e-7
    end

    @testset "domain bounds must certify the actual coil voltage" begin
        net, _ = domain_fixture(0.25, "constant_current")
        # A to-ground phase bound is not a phase-to-floating-neutral bound.
        net["bus"]["t"]["v_min"] = [0.1]
        ctx = build_opf_model(net; per_unit=false)
        @test OpfModelKey(:variable, :load_log_voltage_magnitude, ("d",1)) in opf_object_keys(ctx)
        # Declared bounds omitted by a PF recipe cannot justify a domain floor.
        net["bus"]["t"]["vpn_min"] = [0.1]
        ctx = initialize_opf_model(net; per_unit=false)
        E._add_device_constraints!(ctx)
        @test OpfModelKey(:variable, :load_log_voltage_magnitude, ("d",1)) in opf_object_keys(ctx)
        # Fixed zero voltage is outside the remaining laws' supported domain.
        net["voltage_source"]["z"] = Dict{String,Any}("bus"=>"t", "terminal_map"=>["a","n"],
            "v_magnitude"=>[0,0], "v_angle"=>[0,0])
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
    end

    @testset "MadNLP zero-radius vector equality bridge" begin
        model = JuMP.Model(MadNLP.Optimizer); JuMP.set_silent(model)
        x=JuMP.@variable(model); y=JuMP.@variable(model)
        row=E._soc_norm!(model, x+y, x-y, 0.0)
        JuMP.optimize!(model)
        @test JuMP.termination_status(model) == JuMP.MOI.LOCALLY_SOLVED
        @test max(abs(JuMP.value(x)), abs(JuMP.value(y))) < 1e-8
        @test length(JuMP.dual(row)) == 2
    end
end

@testset "OPF rejects incomplete native physics" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    function ideal_fixture()
        Dict{String,Any}("bus"=>Dict(b=>Dict{String,Any}("terminal_names"=>["a"]) for b in ("a","b","c")),
            "line"=>Dict("ab"=>Dict{String,Any}("bus_from"=>"a","bus_to"=>"b",
                "terminal_map_from"=>["a"],"terminal_map_to"=>["a"],"R_series_1_1"=>0.0)))
    end
    edge(f,t)=Dict{String,Any}("bus_from"=>f,"bus_to"=>t,
        "terminal_map_from"=>["a"],"terminal_map_to"=>["a"])
    net=ideal_fixture()
    @test build_opf_model(net; per_unit=false) !== nothing
    shared = JuMP.Model()
    first_ctx = build_opf_model(net; model=shared, per_unit=false)
    second_ctx = build_opf_model(net; model=shared, per_unit=false)
    @test opf_model(first_ctx) === opf_model(second_ctx)
    net["switch"]=Dict("bc"=>edge("b","c"))
    @test build_opf_model(net; per_unit=false) !== nothing
    net["switch"]["ca"]=edge("c","a")
    @test_throws ArgumentError build_opf_model(net; per_unit=false)
    net["switch"]["ca"]["open_switch"]=true
    @test build_opf_model(net; per_unit=false) !== nothing
    net["switch"]["aa"]=edge("a","a")
    @test_throws ArgumentError build_opf_model(net; per_unit=false)

    @testset "provider resolution precedes structural cycle detection" begin
        net=ideal_fixture(); net["switch"]=Dict("ab"=>edge("a","b"))
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
        key=OpfCoefficientKey(:physics,:line,"ab",:R_series,(1,1))
        spec=OpfBuildSpec(coefficient_providers=Dict(key=>OpfCoefficientProvider(
            :DomainTest, (ctx,key,default)->1.0)))
        @test build_opf_model(net; per_unit=false,build_spec=spec) !== nothing
        model=JuMP.Model(); p=JuMP.@variable(model, set=JuMP.Parameter(0.0))
        spec=OpfBuildSpec(coefficient_providers=Dict(key=>OpfCoefficientProvider(
            :DomainTest, (ctx,key,default)->p)))
        @test build_opf_model(net; model,per_unit=false,build_spec=spec) !== nothing
        # A custom switch builder owns its equations, so no native ideal edge.
        builder=OpfDeviceBuilder(:DomainTest, (ctx,ids)->nothing)
        @test build_opf_model(net; per_unit=false,
            build_spec=OpfBuildSpec(family_builders=Dict(:switch=>builder))) !== nothing
    end

    for change in (
        l->delete!(l,"R_series_1_1"),
        l->(l["R_series_1_1"]=Inf),
        l->(l["X_series_2_2"]=1.0))
        net=ideal_fixture(); change(net["line"]["ab"])
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
    end
    net=ideal_fixture(); delete!(net["line"]["ab"],"R_series_1_1")
    net["line"]["ab"]["linecode"]="empty"; net["linecode"]=Dict("empty"=>Dict{String,Any}())
    @test_throws ArgumentError build_opf_model(net; per_unit=false)
    # Missing trailing references are valid only when grounding already fixes them.
    net=ideal_fixture(); net["bus"]["a"]["terminal_names"]=["a","n"]
    net["voltage_source"]=Dict("s"=>Dict{String,Any}("bus"=>"a", "terminal_map"=>["a","n"],
        "v_magnitude"=>[1.0], "v_angle"=>[0.0]))
    @test build_opf_model(net; per_unit=false) !== nothing
    net["bus"]["a"]["terminal_names"]=["a","b"]
    net["voltage_source"]["s"]["terminal_map"]=["a","b"]
    @test_throws ArgumentError build_opf_model(net; per_unit=false)
    # A two-terminal DELTA load is one coil, not an incomplete two-coil load.
    net["voltage_source"]["s"]["v_magnitude"]=[1.0,0.0]
    net["voltage_source"]["s"]["v_angle"]=[0.0,0.0]
    net["load"]=Dict("d"=>Dict{String,Any}("bus"=>"a", "terminal_map"=>["a","b"],
        "configuration"=>"DELTA", "p_nom"=>[1.0], "q_nom"=>[0.0]))
    @test build_opf_model(net; per_unit=false) !== nothing
    for field in ("v_magnitude","v_angle"), value in (Float64[],[NaN],[Inf])
        net=ideal_fixture()
        s=Dict{String,Any}("bus"=>"a","terminal_map"=>["a"],"v_magnitude"=>[1.0],"v_angle"=>[0.0])
        s[field]=value; net["voltage_source"]=Dict("s"=>s)
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
    end
    for family in ("voltage_source","generator","load")
        net=ideal_fixture(); net[family]=Dict("bad"=>Dict{String,Any}("bus"=>"a",
            "terminal_map"=>["a"],"configuration"=>"unknown","v_magnitude"=>[1.0],
            "v_angle"=>[0.0],"p_nom"=>[1.0],"q_nom"=>[0.0]))
        @test_throws ArgumentError build_opf_model(net; per_unit=false)
    end
    @test_throws ArgumentError E._assert_nwinding_supported_tap("x", Dict("windings"=>[Dict("tap"=>1.0)]))
end
