using Test, BMOPFTools, JuMP, Ipopt

@testset "Transformer phase evidence in SI and per-unit native coordinates" begin
    for kind in ("wye_delta","delta_wye"), n in ("n","4","return"),
        perm in ([1,2,3],[2,3,1]), tap in (1.,1.06), pu in (false,true), rotation in (0.,.7)
        net,x=_pr_net(kind;neutral=n,to=perm);x["tap"]=tap
        wyebus=kind=="wye_delta" ? "f" : "t"
        vm=kind=="wye_delta" ? 1200. : 230.
        net["voltage_source"]=Dict("s"=>Dict("bus"=>wyebus,"terminal_map"=>["a","b","c"],
            "v_magnitude"=>fill(vm,3),"v_angle"=>[rotation,rotation-2π/3,rotation+2π/3]))
        expected=transformer_phase_relation(net,kind,x)
        ctx=build_opf_model(net;per_unit=pu,add_objective=false)
        actual=transformer_phase_relation(ctx.net,kind,ctx.net["transformer"][kind]["x"])
        @test actual["clock"]==expected["clock"]
        # Generic warm starts contain deliberate perturbations. Prescribe the
        # source exactly before exercising the native winding initialization;
        # these tests compare ideal phasors, not a perturbed NLP starting point.
        s=ctx.net["voltage_source"]["s"]
        for (k,p) in enumerate(("a","b","c"))
            z=s["v_magnitude"][k]*cis(s["v_angle"][k])
            JuMP.set_start_value(ctx.vars[:vr][(wyebus,p)],real(z))
            JuMP.set_start_value(ctx.vars[:vi][(wyebus,p)],imag(z))
        end
        JuMP.set_start_value(ctx.vars[:vr][(wyebus,n)],0.)
        JuMP.set_start_value(ctx.vars[:vi][(wyebus,n)],0.)
        Base.get_extension(BMOPFTools,:BMOPFOpfExt)._set_yd_dy_start_values!(
            ctx.vars,ctx.net,ctx.grounded;set_voltage_starts=true)
        value(b,t)=complex(JuMP.start_value(ctx.vars[:vr][(b,t)]),JuMP.start_value(ctx.vars[:vi][(b,t)]))
        # A floating delta has an arbitrary common mode. Compare balanced
        # virtual-neutral phasors, the reference used by a three-phase clock.
        phase(b,t)=value(b,t)-sum(value(b,p) for p in ("a","b","c"))/3
        ratio=phase("t","a")/phase("f","a")
        @test ratio/abs(ratio) ≈ cis(-expected["clock"]*π/6) atol=1e-8
        # Positive bases/taps affect magnitude, not the observed phasor transfer.
        for p in ("b","c")
            r=phase("t",p)/phase("f",p)
            @test r/abs(r) ≈ ratio/abs(ratio) atol=1e-8
        end
    end
end
