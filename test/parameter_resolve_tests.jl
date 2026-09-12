using Test, BMOPFTools, JuMP, Ipopt

@testset "Explicit parameter re-solve on cached shared models (#386)" begin
    net=Dict{String,Any}("bus"=>Dict("b"=>Dict("terminal_names"=>["a"])) )
    calls=Ref(0)
    m=Model(Ipopt.Optimizer);set_silent(m)
    set_optimize_hook(m,(m;kwargs...)->begin
        calls[]+=1;optimize!(m;ignore_optimize_hook=true,kwargs...)
    end)
    a=build_opf_model(net;model=m,per_unit=false)
    b=build_opf_model(net;model=m,per_unit=false)
    @test_throws ArgumentError resolve_opf!(a,b)
    enforce_kcl!(a)
    @test_throws ArgumentError resolve_opf!(a) # unstamped sibling still guards
    enforce_kcl!(b)
    @variable(m,p in Parameter(1.0));@variable(m,x,start=0.0);@variable(m,y,start=1.0)
    @constraint(m,y==1.0);@constraint(m,x==p*exp(y))
    counts=(num_variables(m),num_constraints(m;count_variable_in_set_constraints=true))
    for v in (1.,0.,2.)
        set_parameter_value(p,v)
        @test resolve_opf!(a,b) === m
        @test termination_status(m) in (MOI.LOCALLY_SOLVED,MOI.OPTIMAL)
        @test value(x) ≈ v*exp(1.) atol=1e-8
        @test isempty(primal_feasibility_report(m;atol=1e-8))
        @test start_value(x)==0.0
        @test counts==(num_variables(m),num_constraints(m;count_variable_in_set_constraints=true))
    end
    @test calls[]==3
    c=build_opf_model(net;per_unit=false);enforce_kcl!(c)
    @test_throws ArgumentError resolve_opf!(a,c)
    direct=direct_model(Ipopt.Optimizer())
    d=build_opf_model(net;model=direct,per_unit=false);enforce_kcl!(d)
    @test_throws ArgumentError resolve_opf!(d)
end
