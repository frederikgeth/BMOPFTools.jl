using Test, BMOPFTools, JuMP, Ipopt

@testset "Device indexing agrees with native model rows (#408)" begin
    for neutral in ("n","4","return"), pu in (false,true), kind in ("load","generator","ibr"),
        topology in (kind=="ibr" ? ("SINGLE_PHASE","THREE_LEG","FOUR_LEG") : ("SINGLE_PHASE","DELTA","WYE"))
        maps=topology=="SINGLE_PHASE" ? [["a",neutral],["a","b"],[neutral,"a"]] :
            topology in ("DELTA","THREE_LEG") ? [["c","a","b"]] : [[neutral,"c","a","b"]]
        for tm in maps
            net=_idx_net(neutral); c=_idx_device!(net,kind,topology,tm)
            n=topology=="SINGLE_PHASE" ? 1 : 3
            if kind=="load"
                c["p_nom"]=fill(100.,n); c["q_nom"]=fill(10.,n)
            else
                c["p_max"]=collect(100.:100.:100n); c["cost"]=ones(n)
                c["i_max"]=fill(10.,n); c["s_max"]=fill(500.,n)
            end
            ctx=build_opf_model(net;per_unit=pu)
            family=kind=="load" ? :load_power_real : kind=="generator" ? :generator_p_upper : :ibr_p_upper
            for k in 1:n
                @test OpfModelKey(:constraint,family,("d",k)) in opf_object_keys(ctx)
            end
            @test OpfModelKey(:constraint,family,("d",n+1)) ∉ opf_object_keys(ctx)
            @test !any(x -> x.code=="W.INT.DIM_MISMATCH",_idx_findings(net))
            if kind!="load"
                for k in 1:n
                    row=constraint_object(opf_object(ctx,OpfModelKey(:constraint,family,("d",k))))
                    @test row.set.upper ≈ ctx.net[kind]["d"]["p_max"][k]
                end
            end
        end
    end
    # Source reference prefixes exclude only known grounded trailing entries;
    # power/cost arrays still index the three phase injections.
    for neutral in ("n","4","return"), pu in (false,true)
        net=_idx_net(neutral); s=net["voltage_source"]["s"]
        push!(s["terminal_map"],neutral); s["p_max"]=[1000.,2000.,3000.]
        ctx=build_opf_model(net;per_unit=pu)
        @test all(OpfModelKey(:constraint,:source_p_upper,("s",k)) in opf_object_keys(ctx) for k in 1:3)
        @test !any(x -> x.code=="W.INT.DIM_MISMATCH",_idx_findings(net))
    end
end
