using JuMP, Ipopt, MadNLP
for opt in (Ipopt.Optimizer,MadNLP.Optimizer)
    m=Model(opt); set_silent(m)
    @variable(m,p in Parameter(1.0)); @variable(m,x,start=0.0); @variable(m,y,start=1.0)
    @constraint(m,y==1.0); @constraint(m,x==p*exp(y))
    for value in (1.0,0.0,2.0)
        set_parameter_value(p,value); optimize!(m)
        println((solver=opt,p=value,status=termination_status(m),x=JuMP.value(x),residual=JuMP.value(x)-value*exp(1.0)))
    end
end
