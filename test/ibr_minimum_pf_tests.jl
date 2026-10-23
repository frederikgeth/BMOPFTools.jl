using Test, BMOPFTools, JuMP, Ipopt, JSON3, JSONSchema

function minimum_pf_net(;topology="SINGLE_PHASE",pf=0.8)
    n=JSON3.read(read(joinpath(@__DIR__,"data","ibr_minimum_pf","curtailed.json"),String),Dict{String,Any})
    phases=topology=="SINGLE_PHASE" ? ["a"] : ["a","b","c"]
    tm=topology=="THREE_LEG" ? phases : vcat(phases,["n"])
    n["bus"]["b"]["terminal_names"]=tm
    n["bus"]["b"]["perfectly_grounded_terminals"]=topology=="THREE_LEG" ? String[] : ["n"]
    inv=n["ibr"]["pv"];inv["terminal_map"]=tm;inv["topology"]=topology
    for field in ("p_min","p_max","q_min","q_max","s_max")
        inv[field]=fill(only(inv[field]),length(phases))
    end
    src=n["voltage_source"]["source"];src["terminal_map"]=phases
    src["v_magnitude"]=fill(230.,length(phases));src["v_angle"]=length(phases)==1 ? [0.] : [0.,-2pi/3,2pi/3]
    n["extras"]["bmopftools"]["minimum_power_factor"]["ibr"]["pv"]["pf_min"]=pf
    n
end
minpf_req(n)=n["extras"]["bmopftools"]["minimum_power_factor"]["ibr"]["pv"]
function solve_minpf(n;p=400.,sign=1,per_unit=false,s_base=1e6)
    solve_opf(n;per_unit,s_base,solver_options=("tol"=>1e-10,"constr_viol_tol"=>1e-10,
        "bound_relax_factor"=>0.,"acceptable_iter"=>0),model_hook! = ctx->begin
            scale=ctx.bases===nothing ? 1. : ctx.bases.s_base
            np=length(n["ibr"]["pv"]["p_min"])
            for k in 1:np
                @constraint(ctx.model,opf_object(ctx,opf_ibr_power_key("pv",k))==(p isa Vector ? p[k] : p)/scale)
            end
            @objective(ctx.model,Max,sign*sum(opf_object(ctx,opf_ibr_power_key("pv",k;component=:reactive)) for k in 1:np))
        end)
end
function supplied_minpf(n,p,q;status="LOCALLY_SOLVED")
    Dict{String,Any}("termination_status"=>status,"ibr"=>Dict("pv"=>Dict(
        t=>Dict("pg"=>p isa Vector ? p[k] : p,"qg"=>q isa Vector ? q[k] : q)
        for (k,t) in enumerate(n["voltage_source"]["source"]["terminal_map"]))))
end

@testset "Minimum power factor: dispatched generation per coil (#89)" begin
    @testset "curtailment, signs, topologies, independent VI and SI/PU" begin
        for topology in ("SINGLE_PHASE","FOUR_LEG","THREE_LEG"), sign in (-1,1),
            (pu,base) in ((false,1e6),(true,1e5),(true,1e6))
            n=minimum_pf_net(;topology); before=deepcopy(n)
            r=solve_minpf(n;sign,per_unit=pu,s_base=base)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            v=230 .* cis.(n["voltage_source"]["source"]["v_angle"])
            for (k,t) in enumerate(n["voltage_source"]["source"]["terminal_map"])
                row=r["ibr"]["pv"][t]; dv=topology=="THREE_LEG" ? v[k]-v[mod1(k+1,3)] : v[k]
                measured=dv*conj(row["cri"]+im*row["cii"])
                @test measured ≈ 400+sign*300im atol=2e-3
                @test row["pg"]+im*row["qg"] ≈ measured atol=1e-5
                @test real(measured)/abs(measured) ≈ .8 atol=1e-6
            end
            f=Finding[]; s=solution_check(n,r,f)
            @test all(x->x["status"]=="passed",s["minimum_power_factor"]["coils"])
            @test !any(x->x.code=="E.SOL.IBR_MINIMUM_PF",f)
            @test n==before
        end
    end
    @testset "zero, unity and unbalanced per-coil rather than aggregate" begin
        for topology in ("SINGLE_PHASE","FOUR_LEG","THREE_LEG"), pf in (.8,1.), pu in (false,true)
            n=minimum_pf_net(;topology,pf);r=solve_minpf(n;p=0.,per_unit=pu)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test all(abs(row["qg"])<1e-3 for row in values(r["ibr"]["pv"]))
        end
        n=minimum_pf_net(;topology="FOUR_LEG")
        r=solve_minpf(n;p=[100.,400.,800.])
        @test [r["ibr"]["pv"][t]["qg"] for t in ("a","b","c")] ≈ [75,300,600] atol=1e-3
        bad=supplied_minpf(n,[100.,1000.,1000.],[300.,0.,0.]); f=Finding[]
        s=solution_check(n,bad,f)
        @test 2100/hypot(2100,300)>.8 # aggregate would wrongly pass
        @test [r["status"] for r in s["minimum_power_factor"]["coils"]]==["failed","passed","passed"]
        @test count(x->x.code=="E.SOL.IBR_MINIMUM_PF",f)==1
        @test s["n_inv_violations"]>=1
    end
    @testset "compatible constant PF, capability and control conflicts" begin
        for pf in (.8,-.8,1.,-1.)
            n=minimum_pf_net();n["control_profile"]=Dict("cp"=>Dict("power_factor"=>Dict("pf"=>pf)))
            n["ibr"]["pv"]["control_profile"]="cp"
            r=solve_minpf(n)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test r["ibr"]["pv"]["a"]["qg"] ≈ -sign(pf)*sqrt(1-pf^2)/abs(pf)*400 atol=1e-3
        end
        n=minimum_pf_net();n["ibr"]["pv"]["q_max"]=[200.]
        @test solve_minpf(n)["ibr"]["pv"]["a"]["qg"]≈200 atol=1e-3
        n=minimum_pf_net();n["ibr"]["pv"]["s_max"]=[450.]
        @test solve_minpf(n)["ibr"]["pv"]["a"]["qg"]≈sqrt(450^2-400^2) atol=1e-3
        n=minimum_pf_net();n["ibr"]["pv"]["i_max"]=[450/230]
        @test solve_minpf(n)["ibr"]["pv"]["a"]["qg"]≈sqrt(450^2-400^2) atol=1e-3
        # Fixed reactive droop intersects the envelope without clipping its equality.
        for topo in ("SINGLE_PHASE","FOUR_LEG")
            n=minimum_pf_net(;topology=topo)
            n["control_profile"]=Dict("cp"=>Dict("volt_var"=>Dict("voltage_reference"=>"PN_PER_PHASE",
                "breakpoints"=>[240.,250.,260.,270.],"q_limits"=>[-.02,.02],"q_unit"=>"VA_FRACTION","q_ref"=>"VAR_MAX")))
            n["ibr"]["pv"]["control_profile"]="cp"
            r=solve_minpf(n)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test all(abs(row["qg"]-100)<1e-3 for row in values(r["ibr"]["pv"]))
        end
        for pu in (false,true)
            n=minimum_pf_net(); n["control_profile"]=Dict("cp"=>Dict("volt_watt"=>Dict(
                "breakpoints"=>[220.,240.],"p_limits"=>[0.,1.],"p_unit"=>"VA_FRACTION","p_ref"=>"P_MAX")))
            n["ibr"]["pv"]["control_profile"]="cp"
            r=solve_opf(n;per_unit=pu,solver_options=("tol"=>1e-10,"bound_relax_factor"=>0.),
                model_hook! = c->@objective(c.model,Max,opf_object(c,opf_ibr_power_key("pv",1))+
                    .01*opf_object(c,opf_ibr_power_key("pv",1;component=:reactive))))
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test r["ibr"]["pv"]["a"]["pg"]≈600 atol=2e-3
            @test r["ibr"]["pv"]["a"]["qg"]≈450 atol=2e-3
            n["control_profile"]["cp"]["volt_watt"]["p_unit"]="W"
            @test_throws ArgumentError build_opf_model(n)
        end
        # Changing available P after construction must change the Q envelope too.
        n=minimum_pf_net();model=Model(Ipopt.Optimizer);set_silent(model)
        available=@variable(model,set=Parameter(400.))
        spec=OpfBuildSpec(coefficient_providers=Dict(
            OpfCoefficientKey(:availability,:ibr,"pv",:p_max,1)=>
                OpfCoefficientProvider(:MinimumPFTest,(ctx,key,default)->available)))
        ctx=build_opf_model(n;model,build_spec=spec,per_unit=false)
        @objective(model,Max,opf_object(ctx,opf_ibr_power_key("pv",1;component=:reactive)))
        enforce_kcl!(ctx);set_optimizer_attribute(model,"tol",1e-10)
        set_optimizer_attribute(model,"bound_relax_factor",0.)
        for available_p in (400.,200.,800.)
            set_parameter_value(available,available_p);resolve_opf!(ctx);r=extract_result(ctx)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test r["ibr"]["pv"]["a"]["pg"]≈available_p atol=1e-3
            @test r["ibr"]["pv"]["a"]["qg"]≈.75*available_p atol=1e-3
        end
        # Independent conflict witness: P<=400, Q>=400 contradict Q<=0.75P.
        n=minimum_pf_net();inv=n["ibr"]["pv"];inv["p_max"]=[400.];inv["q_min"]=[400.]
        @test inv["q_min"][1]>.75*inv["p_max"][1]
        ctx=build_opf_model(n;per_unit=false)
        for family in (:ibr_minimum_pf_generation,:ibr_minimum_pf_lower,:ibr_minimum_pf_upper,:ibr_q_lower,:ibr_p_upper)
            @test OpfModelKey(:constraint,family,("pv",1)) in opf_object_keys(ctx)
        end
        r=solve_minpf(n)
        @test !(r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL"))
    end
    @testset "invalid requests are diagnosed and rejected" begin
        cases=[
            n->(n["terminal_conventions"]=Dict("phase"=>["a"],"neutral"=>["n"],"earth"=>["a"])),
            n->(n["ibr"]["pv"]["terminal_map"]=["a","a"]),
            n->(minpf_req(n)["direction"]="consumption"),
            n->(minpf_req(n)["direction"]="bidirectional"),
            n->(minpf_req(n)["scope"]="aggregate"),
            n->(minpf_req(n)["typo"]=1),
            n->(n["ibr"]["pv"]["p_min"]=[-1.]),
            n->delete!(n["ibr"]["pv"],"p_min"),
            n->(n["ibr"]["pv"]["dc_link_coupled"]=true),
            n->(n["ibr"]["pv"]["control_profile"]="missing"),
            n->(n["extras"]["bmopftools"]["minimum_power_factor"]["schema"]="v2"),
            n->(n["extras"]["bmopftools"]["minimum_power_factor"]["ibr"]["absent"]=deepcopy(minpf_req(n))),
        ]
        for mutate in cases
            n=minimum_pf_net();mutate(n);f=Finding[];BMOPFTools._power_factor_config_check!(n,f)
            @test any(x->x.code=="E.INT.MINIMUM_PF_INVALID",f)
            @test_throws ArgumentError build_opf_model(n)
        end
        for pf in (0.,-0.8,1.1,NaN,Inf,true,nothing,"0.8")
            n=minimum_pf_net();minpf_req(n)["pf_min"]=pf
            @test_throws ArgumentError build_opf_model(n)
            f=Finding[];BMOPFTools._power_factor_config_check!(n,f)
            @test any(x->x.code=="E.INT.MINIMUM_PF_INVALID",f)
        end
        for pf in (0.,1.1,-1.1,NaN,Inf,true,nothing,"0.8")
            n=minimum_pf_net();delete!(n,"extras")
            n["control_profile"]=Dict("cp"=>Dict("power_factor"=>Dict("pf"=>pf)))
            n["ibr"]["pv"]["control_profile"]="cp"
            @test_throws ArgumentError build_opf_model(n)
            f=Finding[];solution_check(n,supplied_minpf(n,400.,0.),f)
            @test any(x->x.code=="E.INT.CONSTANT_PF_INVALID",f)
        end
        n=minimum_pf_net();minpf_req(n)["pf_min"]=nextfloat(0.)
        @test build_opf_model(n)!==nothing # bounded coefficients, no tangent overflow
        f=Finding[];s=solution_check(n,supplied_minpf(n,0.,1.),f)
        @test only(s["minimum_power_factor"]["coils"])["status"]=="failed"
        n=minimum_pf_net(;pf=1.);r=solve_minpf(n)
        @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        @test abs(r["ibr"]["pv"]["a"]["qg"])<1e-3
        n=minimum_pf_net();n["control_profile"]=Dict("cp"=>Dict("volt_var"=>Dict(
            "breakpoints"=>[240.,250.,260.,270.],"q_limits"=>[-100.,100.],"q_unit"=>"VAR")))
        n["ibr"]["pv"]["control_profile"]="cp"
        @test_throws ArgumentError build_opf_model(n)
        for topo in ("SINGLE_PHASE","THREE_LEG")
            n=minimum_pf_net(;topology=topo)
            n["control_profile"]=Dict("cp"=>Dict("power_factor"=>Dict("pf"=>.7)))
            n["ibr"]["pv"]["control_profile"]="cp"
            @test_throws ArgumentError build_opf_model(n)
            n["control_profile"]["cp"]=Dict("volt_watt"=>Dict())
            topo=="THREE_LEG" && @test_throws ArgumentError build_opf_model(n)
        end
    end
    @testset "supplied P/Q, tolerance boundaries, missing candidates and serialization" begin
        n=minimum_pf_net()
        for (p,q,want) in ((400.,299.,"passed"),(400.,300.,"passed"),(400.,301.,"failed"),
                           (0.,0.,"passed"),(0.,1.,"failed"),(-1.,0.,"failed"),(400.,-301.,"failed"))
            f=Finding[];s=solution_check(n,supplied_minpf(n,p,q),f)
            @test only(s["minimum_power_factor"]["coils"])["status"]==want
        end
        for field in ("pg","qg"),missing in (nothing,NaN)
            r=supplied_minpf(n,400.,300.)
            missing===nothing ? delete!(r["ibr"]["pv"]["a"],field) : (r["ibr"]["pv"]["a"][field]=missing)
            f=Finding[];s=solution_check(n,r,f)
            @test only(s["minimum_power_factor"]["coils"])["status"]=="indeterminate"
            @test any(x->x.code=="I.SOL.IBR_MINIMUM_PF_UNASSESSED",f)
        end
        r=supplied_minpf(n,400.,301.;status="LOCALLY_INFEASIBLE");f=Finding[]
        @test only(solution_check(n,r,f)["minimum_power_factor"]["coils"])["status"]=="indeterminate"
        r["primal_status"]="INFEASIBLE_POINT";f=Finding[]
        @test only(solution_check(n,r,f)["minimum_power_factor"]["coils"])["status"]=="failed"
        empty_result=supplied_minpf(n,400.,300.);empty_result["result_count"]=0;f=Finding[]
        @test only(solution_check(n,empty_result,f)["minimum_power_factor"]["coils"])["status"]=="indeterminate"
        before=deepcopy(n); r=supplied_minpf(n,400.,301.)
        response=execute_solution_verification(n,r)
        restored=JSON3.read(JSON3.write(response),Dict{String,Any})
        @test restored["result"]["results"]["solution"]["minimum_power_factor"]["coils"][1]["status"]=="failed"
        schema=JSONSchema.Schema(JSON3.read(read(joinpath(@__DIR__,"..","schemas","execution-response.schema.json"),String)))
        @test JSONSchema.validate(schema,JSON3.read(JSON3.write(response)))===nothing
        parsed=parse_bmopf(JSON3.write(n);from_string=true)
        @test parsed["extras"]==n["extras"]
        f=Finding[];schema_check(parsed,f)
        @test !any(x->x.code=="I.SCHEMA.UNKNOWN_FIELDS" && haskey(get(x.detail,"fields",Dict()),"extras"),f)
        @test n==before
    end
end

@testset "Constant PF remains defined near zero (#89 review)" begin
    for pf in (1e-20, -1e-20, nextfloat(0.0))
        n=minimum_pf_net(;pf=abs(pf))
        n["control_profile"]=Dict("cp"=>Dict("power_factor"=>Dict("pf"=>pf)))
        n["ibr"]["pv"]["control_profile"]="cp"
        ctx=build_opf_model(n;per_unit=false)
        f=constraint_object(opf_object(ctx,OpfModelKey(:constraint,:ibr_power_factor,("pv",1)))).func
        coefficients=[abs(c) for (c,_,_) in JuMP.quad_terms(f)]
        @test maximum(coefficients)==1.0
        @test minimum(coefficients)==abs(pf)
        @test all(v->start_value(v)===nothing || isfinite(start_value(v)),all_variables(ctx.model))
        abs(pf)==nextfloat(0.0) && continue # arithmetic underflow is not a solver accuracy claim
        # Independent P/hypot(P,Q) oracle, beyond acos's representable angle.
        p=abs(pf)*1000; q=-sign(pf)*1000
        @test p/hypot(p,q)≈abs(pf) rtol=1e-14
        for (reactive,deviates) in ((q,false),(q/2,true))
            fs=Finding[];solution_check(n,supplied_minpf(n,p,reactive),fs)
            @test any(f->f.code=="W.SOL.IBR_PF_DEVIATION",fs)==deviates
            @test JSON3.read(JSON3.write([f.detail for f in fs]))!==nothing
        end
    end
    cp=Dict("power_factor"=>Dict("pf"=>big"1e-1000"))
    @test_throws ArgumentError BMOPFTools._constant_pf_value(cp)
end

@testset "Minimum PF never infers through a malformed role declaration" begin
    for declaration in (42, Dict("phase"=>"a","neutral"=>["n"]), Dict("phase"=>nothing))
        n=minimum_pf_net();n["terminal_conventions"]=declaration;before=deepcopy(n)
        fs=Finding[]
        evidence=BMOPFTools._minimum_pf_solution_check(n,supplied_minpf(n,400.,300.),fs;has_candidate=true)
        @test isempty(evidence["coils"])
        @test only(evidence["configuration_errors"])["reason"]=="ambiguous_coil_mapping"
        @test any(f->f.code=="E.INT.MINIMUM_PF_INVALID",fs)
        @test_throws ArgumentError BMOPFTools._power_factor_config_check!(n,Finding[];strict=true)
        @test_throws ArgumentError build_opf_model(n)
        @test_throws ArgumentError initialize_opf_model(n)
        @test JSON3.read(JSON3.write(evidence),Dict{String,Any})==evidence
        @test n==before
    end
end

@testset "Minimum-PF entry guard validates the selected snapshot" begin
    n=minimum_pf_net(); n["ibr"]["pv"]["p_min"]=[-1.]
    n["time_series"]=Dict("direction"=>Dict("values"=>[-1.,1.]))
    n["ibr"]["pv"]["time_series"]=Dict("p_min"=>"direction")
    before=deepcopy(n)
    @test build_opf_model(n;t_index=1)!==nothing # resolved lower bound +1 W
    @test_throws ArgumentError build_opf_model(n;t_index=2) # resolved -1 W
    @test n==before
end
