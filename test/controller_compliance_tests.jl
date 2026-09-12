using Test, BMOPFTools, JuMP, Ipopt, JSON3

function controller_witness(voltage)
    Dict{String,Any}("bus"=>Dict("b"=>Dict("terminal_names"=>["a","n"],"perfectly_grounded_terminals"=>["n"])),
        "voltage_source"=>Dict("src"=>Dict("bus"=>"b","terminal_map"=>["a"],"v_magnitude"=>[voltage],"v_angle"=>[0.])),
        "ibr"=>Dict("pv"=>Dict("bus"=>"b","terminal_map"=>["a","n"],"topology"=>"SINGLE_PHASE",
            "p_min"=>[0.],"p_max"=>[5250.],"q_min"=>[0.],"q_max"=>[0.],"s_max"=>[5250.],"control_profile"=>"vw")),
        "control_profile"=>Dict("vw"=>Dict("volt_watt"=>Dict("breakpoints"=>[253.,260.],"p_limits"=>[0.,1.],
            "p_unit"=>"VA_FRACTION","p_ref"=>"S_MAX","voltage_reference"=>"PN_PER_PHASE"))))
end

@testset "Exact and modeled controller compliance (#386, PSK-000013)" begin
    caps=Dict()
    for per_unit in (false,true), voltage in (250.,253.,256.5,260.,263.)
        net=BMOPFTools._deep_convert(controller_witness(voltage))
        result=solve_opf(net;optimizer=Ipopt.Optimizer,per_unit,
            solver_options=("tol"=>1e-10,"bound_relax_factor"=>0.),
            model_hook! = ctx -> @objective(ctx.model,Max,ctx.vars[:cri][("pv",1)]))
        @test result["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        fs=Finding[]; summary=BMOPFTools.solution_check(net,result,fs)
        detail=only(summary["controller_compliance"])
        @test detail["epsilon_V"] ≈ .513
        @test detail["modeled_cap_feasibility"]=="passed"
        # Independent stable two-hinge softplus formula in SI.
        soft(z)=max(z,0)+.513*log1p(exp(-abs(z)/.513))
        cap=5250*(1-(soft(voltage-253)-soft(voltage-260))/7)
        @test detail["modeled_cap_W"] ≈ cap atol=1e-7
        @test detail["exact_cap_W"] ≈ 5250*clamp((260-voltage)/7,0,1)
        @test detail["approximation_error_W"] ≈ cap-detail["exact_cap_W"] atol=1e-8
        if voltage==260.
            @test detail["exact_profile_compliance"]=="failed"
            @test any(f -> f.code=="E.SOL.IBR_VIOLATION",fs)
        end
        caps[(per_unit,voltage)]=detail["modeled_cap_W"]
        r=JSON3.read(JSON3.write(result),Dict{String,Any})
        @test BMOPFTools.solution_check(net,r,Finding[])["controller_compliance"]==summary["controller_compliance"]
        bad=deepcopy(r)
        bad["modeled_volt_watt"]["pv"]["1"]["baseline_W"]-=10000.
        bad_findings=Finding[]
        bad_summary=BMOPFTools.solution_check(net,bad,bad_findings)
        @test only(bad_summary["controller_compliance"])["modeled_cap_feasibility"]=="failed"
        @test any(f -> f.code=="E.SOL.IBR_VIOLATION" &&
            get(f.detail,"field",nothing)=="modeled_volt_watt_cap",bad_findings)
        delete!(r,"modeled_volt_watt")
        @test only(BMOPFTools.solution_check(net,r,Finding[])["controller_compliance"])["modeled_cap_feasibility"]=="indeterminate"
    end
    for voltage in (250.,253.,256.5,260.,263.)
        @test caps[(false,voltage)] ≈ caps[(true,voltage)] atol=1e-7
    end
    # Extreme tails, alternate encoding, and malformed evidence.
    row=Dict{String,Any}("units"=>"SI","mode"=>"swish","epsilon_V"=>.5,"baseline_W"=>1.,
        "hinges"=>[Dict("slope_W_per_V"=>1.,"breakpoint_V"=>0.)])
    @test BMOPFTools._modeled_volt_watt_cap(row,-1000.)==1.
    @test BMOPFTools._modeled_volt_watt_cap(row,1000.)==1001.
    row["epsilon_V"]=0.
    @test BMOPFTools._modeled_volt_watt_cap(row,0.)===nothing
end
