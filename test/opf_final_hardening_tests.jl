using MadNLP

@testset "OPF magnitude domains" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    for cap in (-1.0, -Inf, NaN, 1e-200, 1e200)
        m=JuMP.Model(); x=JuMP.@variable(m); y=JuMP.@variable(m)
        @test_throws ArgumentError E._soc_norm!(m,x,y,cap)
        @test_throws ArgumentError E._limit_current_box!(x,y,cap)
        @test_throws ArgumentError E._neutral_current_limit!(m,[x],[y],cap)
        @test_throws ArgumentError E._apparent_power_limit!(m,x,y,x,y,cap)
        @test JuMP.num_constraints(m; count_variable_in_set_constraints=true) == 0
    end
    for cap in (nothing, Inf)
        m=JuMP.Model(); x=JuMP.@variable(m); y=JuMP.@variable(m)
        @test E._soc_norm!(m,x,y,cap) === nothing
        @test E._limit_current_box!(x,y,cap) === nothing
        @test E._neutral_current_limit!(m,[x],[y],cap) === nothing
        @test E._apparent_power_limit!(m,x,y,x,y,cap) === nothing
        @test JuMP.num_variables(m) == 2
        @test JuMP.num_constraints(m; count_variable_in_set_constraints=true) == 0
    end
    # Positive/zero cap oracles and in-memory +Inf upper-bound semantics.
    for cap in (0.0, 0.5, 2.0)
        m=JuMP.Model(); x=JuMP.@variable(m); y=JuMP.@variable(m)
        E._soc_norm!(m,x,y,cap)
        @test isempty(JuMP.primal_feasibility_report(m,Dict(x=>cap,y=>0.0)))
        @test !isempty(JuMP.primal_feasibility_report(m,Dict(x=>cap+1,y=>0.0)))
    end
    for cap in (-1.0, NaN, Inf)
        net=Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a","n"],
            "vn_max"=>cap,"v_max"=>[cap])))
        if cap == Inf
            ctx=build_opf_model(net; per_unit=false)
            @test all(k.family ∉ (:bus_voltage_upper,:bus_neutral_voltage_upper) for k in opf_object_keys(ctx))
        else
            @test_throws ArgumentError build_opf_model(net; per_unit=false)
        end
    end
    net=Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a"],"v_min"=>[Inf])))
    @test_throws ArgumentError build_opf_model(net; per_unit=false)
    # Even an open switch cannot hide an invalid declared rating.
    net=Dict{String,Any}("bus"=>Dict(b=>Dict{String,Any}("terminal_names"=>["a"]) for b in ("f","t")),
        "switch"=>Dict("s"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t",
        "terminal_map_from"=>["a"],"terminal_map_to"=>["a"],"open_switch"=>true,"i_max"=>[-1.0])))
    io=IOBuffer(); write_bmopf(net,io)
    @test_throws ArgumentError build_opf_model(parse_bmopf(String(take!(io));from_string=true);per_unit=false)
end

@testset "OPF native transformer applicability" begin
    E = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    function transformer_fixture(subtype, fr, to)
        Dict{String,Any}("bus"=>Dict("f"=>Dict{String,Any}("terminal_names"=>["a","b","c","n"]),
                                    "t"=>Dict{String,Any}("terminal_names"=>["a","b","c","n"])),
            "transformer"=>Dict(subtype=>Dict("x"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t",
                "terminal_map_from"=>fr,"terminal_map_to"=>to,"v_nom_from"=>1.0,"v_nom_to"=>1.0))))
    end
    for (kind,fr,to) in (("center_tap",["a","n"],["a","n"]),
                         ("wye_delta",["a","n"],["a","b","c"]),
                         ("single_phase",["a","n"],["a","b","c","n"]),
                         ("single_phase",["n"],["n"]),
                         ("single_phase_autotransformer",["n"],["a","n"]),
                         ("open_delta_regulator",["a","b","c"],["a","b","c"]),
                         ("unsupported",["a","n"],["a","n"]))
        net=transformer_fixture(kind,fr,to)
        @test_throws ArgumentError E._validate_native_transformers(net)
        @test_throws ArgumentError build_opf_model(net;per_unit=false)
    end
    # These were warn-and-ignore paths despite declaring neutral physics.
    for (kind,fr,to,field) in (
        ("single_phase",["a","b"],["a","b"],"r_neutral_from"),
        ("wye_delta",["a","b","c","n"],["a","b","c"],"r_neutral_to"),
        ("wye_delta",["a","b","c"],["a","b","c"],"r_neutral_from"))
        net=transformer_fixture(kind,fr,to)
        net["transformer"][kind]["x"][field]=0.1
        @test_throws ArgumentError build_opf_model(net;per_unit=false)
    end
    for rating in (-1.0,0.0,NaN,Inf)
        net=transformer_fixture("single_phase",["a","n"],["a","n"])
        net["transformer"]["single_phase"]["x"]["s_rating"]=rating
        @test_throws ArgumentError E._validate_native_transformers(net)
    end
    for nominal in (0.0,-1.0,Inf,NaN), side in ("from","to")
        net=transformer_fixture("single_phase",["a","n"],["a","n"])
        net["transformer"]["single_phase"]["x"]["v_nom_$side"]=nominal
        @test_throws ArgumentError build_opf_model(net;per_unit=false)
    end
    for rating in (nothing,1.0)
        net=transformer_fixture("single_phase",["a","n"],["a","n"])
        rating === nothing || (net["transformer"]["single_phase"]["x"]["s_rating"]=rating)
        @test E._validate_native_transformers(net) === nothing
    end
    # Winding-level zero caps must be real constraints, including no-load cases.
    net=transformer_fixture("n_winding",["a","n"],["a","n"])
    xf=net["transformer"]["n_winding"]["x"]
    xf["s_rating"]=1.0; xf["x_sc"]=Dict("1_2"=>0.1)
    xf["windings"]=[Dict{String,Any}("bus"=>b,"terminal_map"=>["a","n"],
        "configuration"=>"WYE","v_nom"=>1.0,"i_max"=>0.0,"s_max"=>0.0) for b in ("f","t")]
    ctx=build_opf_model(net;per_unit=false)
    @test any(k.family == :nwind_current_thermal for k in opf_object_keys(ctx))
    @test any(k.family == :nwind_apparent_power_circle for k in opf_object_keys(ctx))
    for tm in (["n"], ["a","b","n"], ["1","n"])
        bad=deepcopy(net)
        bad["bus"]["t"]["terminal_names"]=["a","b","c","1","n"]
        bad["transformer"]["n_winding"]["x"]["windings"][2]["terminal_map"]=tm
        @test_throws ArgumentError build_opf_model(bad;per_unit=false)
    end
    xf["windings"][1]["i_max"]=-1.0
    @test_throws ArgumentError build_opf_model(net;per_unit=false)
end

# Direct device witnesses keep independent voltage equalities, so both load
# formulations can be tested at exactly the same physical operating point.
function stress_load_model(optimizer, nominal, ratio, gamma; certified=false, parameter=false)
    E=Base.get_extension(BMOPFTools,:BMOPFOpfExt)
    m=JuMP.Model(optimizer); JuMP.set_silent(m)
    v=nominal*ratio
    vr=JuMP.@variable(m,start=v); vi=JuMP.@variable(m,start=0.0)
    cr=JuMP.@variable(m,start=0.0); ci=JuMP.@variable(m,start=0.0)
    p=parameter ? JuMP.@variable(m,set=JuMP.Parameter(0.3)) : 0.3
    q=parameter ? JuMP.@variable(m,set=JuMP.Parameter(0.15)) : 0.15
    JuMP.@constraint(m,vr == v); JuMP.@constraint(m,vi == 0)
    load=Dict{String,Any}("model"=>"exponential","v_nom"=>[nominal],"gamma_p"=>[gamma],"gamma_q"=>[gamma])
    E._add_subload_power!(m,load,"d",1,vr*cr+vi*ci,vi*cr-vr*ci,p,q,vr,vi;
        cr,ci,voltage_lower=certified ? v/2 : nothing)
    return m,vr,vi,cr,ci,p,q
end

@testset "OPF load derivatives and parameter stress" begin
    M=JuMP.MOI
    for certified in (false,true), (ratio,gamma) in ((1e-3,1.5),(0.1,-0.5),(0.1,4.0))
        m,vr,vi,cr,ci,_,_=stress_load_model(Ipopt.Optimizer,1.0,ratio,gamma;certified)
        # Build the MOI AD evaluator from the actual emitted scalar rows.
        nl=M.Nonlinear.Model()
        for cref in JuMP.all_constraints(m;include_variable_in_set_constraints=false)
            c=JuMP.constraint_object(cref)
            M.Nonlinear.add_constraint(nl,JuMP.moi_function(c.func),c.set)
        end
        vars=JuMP.all_variables(m); x=[JuMP.start_value(v) for v in vars]
        ev=M.Nonlinear.Evaluator(nl,M.Nonlinear.SparseReverseMode(),JuMP.index.(vars))
        M.initialize(ev,[:Jac,:Hess])
        nr=length(nl.constraints); nc=length(x)
        function values_at(z)
            valuation=Dict(zip(vars,z))
            [JuMP.value(v -> valuation[v], JuMP.constraint_object(c).func) for c in
                JuMP.all_constraints(m;include_variable_in_set_constraints=false)]
        end
        function jacobian_at(z)
            entries=zeros(length(M.jacobian_structure(ev))); M.eval_constraint_jacobian(ev,entries,z)
            matrix=zeros(nr,nc)
            for ((i,j),v) in zip(M.jacobian_structure(ev),entries); matrix[i,j]+=v; end
            matrix
        end
        J=jacobian_at(x); H=zeros(nc,nc); weights=collect(1.0:nr)
        entries=zeros(length(M.hessian_lagrangian_structure(ev)))
        M.eval_hessian_lagrangian(ev,entries,x,0.0,weights)
        for ((i,j),v) in zip(M.hessian_lagrangian_structure(ev),entries)
            H[i,j]+=v; i==j || (H[j,i]+=v)
        end
        @test all(isfinite,J) && all(isfinite,H)
        for j in 1:nc
            h=iszero(x[j]) ? 1e-5 : 1e-5*abs(x[j])
            xp=copy(x); xm=copy(x); xp[j]+=h; xm[j]-=h
            d=(values_at(xp)-values_at(xm))/(2h)
            @test J[:,j] ≈ d atol=1e-5 rtol=2e-5
            d2=(jacobian_at(xp)'*weights-jacobian_at(xm)'*weights)/(2h)
            @test H[:,j] ≈ d2 atol=1e-4 rtol=2e-5
        end
    end
    for optimizer in (Ipopt.Optimizer,MadNLP.Optimizer), certified in (false,true), nominal in (0.01,1.0,1000.0)
        @testset "$optimizer, certified=$certified, nominal=$nominal" begin
        ratio=1e-3; gamma=1.5
        m,vr,vi,cr,ci,p,q=stress_load_model(optimizer,nominal,ratio,gamma;certified,parameter=true)
        JuMP.set_optimizer_attribute(m,"tol",1e-12)
        JuMP.set_optimizer_attribute(m,"bound_relax_factor",0.0)
        counts=(JuMP.num_variables(m),JuMP.num_constraints(m;count_variable_in_set_constraints=true))
        for factor in (1.0,0.0,2.0)
            JuMP.set_parameter_value(p,0.3factor); JuMP.set_parameter_value(q,0.15factor)
            # Refresh backend derivative caches after changing nonlinear parameters.
            M.Utilities.reset_optimizer(JuMP.backend(m))
            JuMP.optimize!(m)
            @test JuMP.termination_status(m) in (M.LOCALLY_SOLVED,M.OPTIMAL)
            expected=factor*(0.3-0.15im)*ratio^gamma/(nominal*ratio)
            @test complex(JuMP.value(cr),JuMP.value(ci)) ≈ expected rtol=1e-5 atol=1e-9
            @test isempty(JuMP.primal_feasibility_report(m;atol=1e-10))
            @test counts == (JuMP.num_variables(m),JuMP.num_constraints(m;count_variable_in_set_constraints=true))
        end
    end
    end
    E=Base.get_extension(BMOPFTools,:BMOPFOpfExt)
    for nominal in (1e-200,1e200)
        @test_throws ArgumentError E._load_vnom_k(Dict("v_nom"=>nominal),1)
    end
end
