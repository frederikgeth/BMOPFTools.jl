using Test, BMOPFTools, LinearAlgebra, JSON3

@testset "Ideal transformer finite shunts (#454, PSK-000002)" begin
    fixture = joinpath(@__DIR__, "data", "ideal_transformer_shunts.json")
    base() = JSON3.read(read(fixture, String), Dict{String,Any})
    passive(r) = hasproperty(r,:K) ? Matrix(r.K[1:length(r.nodes),1:length(r.nodes)]) : Matrix(r.Y)
    function expected_shunts(net, subtype, r)
        x=net["transformer"][subtype]["t"]
        E=zeros(ComplexF64,length(r.nodes),length(r.nodes))
        function branch(a,b,y)
            i=r.index[a]; j=b===nothing ? 0 : r.index[b]
            i>0 && (E[i,i]+=y); j>0 && (E[j,j]+=y)
            i>0 && j>0 && (E[i,j]-=y; E[j,i]-=y)
        end
        tm=x["terminal_map_to"]; ph=filter(!=("n"),tm)
        for (k,p) in enumerate(ph)
            q=subtype=="wye_delta" ? ph[mod1(k+1,length(ph))] : "n"
            branch(("lv",p),("lv",q),complex(x["g_no_load"],x["b_no_load"])/length(ph))
        end
        side=subtype=="wye_delta" ? "from" : "to"
        branch((side=="from" ? "hv" : "lv","n"),nothing,0.5)
        E
    end
    @testset "Independent entries and input preservation" begin
        for subtype in ("single_phase","wye_delta","delta_wye"), ratio in (1.,2.),
            z in (0.,5e-7), grounded in (false,true)
            net=base(); x=pop!(net["transformer"],"single_phase")["t"]
            net["transformer"][subtype]=Dict{String,Any}("t"=>x)
            x["v_nom_from"]=230ratio; x["r_series_to"]=z; x["b_no_load"]=-0.002
            if subtype!="single_phase"
                x["terminal_map_from"]=subtype=="delta_wye" ? ["a","b","c"] : ["a","b","c","n"]
                x["terminal_map_to"]=subtype=="wye_delta" ? ["a","b","c"] : ["a","b","c","n"]
            end
            side=subtype=="wye_delta" ? "from" : "to"
            delete!(x,"r_neutral_to"); x["r_neutral_"*side]=2.
            for (bus,s) in (("hv","from"),("lv","to"))
                net["bus"][bus]["terminal_names"]=copy(x["terminal_map_"*s])
            end
            grounded && (net["bus"][side=="from" ? "hv" : "lv"]["perfectly_grounded_terminals"]=["n"])
            before=deepcopy(net)
            r=ybus_augmented(net;config=Dict("domain_rules"=>Dict("xfmr_z_min_ohm"=>1e-5)))
            @test passive(r) ≈ expected_shunts(net,subtype,r) atol=1e-13
            @test net==before
            for builder in (ybus_passive,ybus_linearized)
                @test_throws ArgumentError builder(net;config=Dict("domain_rules"=>Dict("xfmr_z_min_ohm"=>1e-5)))
            end
            @test_throws ArgumentError ybus_augmented(net;ideal_xfmrs=:stamp,
                config=Dict("domain_rules"=>Dict("xfmr_z_min_ohm"=>1e-5)))
            # Ordinary finite stamps must not receive an extra copy of shunts.
            x["r_series_to"]=0.01
            p=ybus_passive(net); nd,Y=transformer_yprim(x,subtype)
            E=zeros(ComplexF64,length(p.nodes),length(p.nodes))
            for a in eachindex(nd), b in eachindex(nd)
                i=p.index[nd[a]]; j=p.index[nd[b]]
                i>0 && j>0 && (E[i,j]+=Y[a,b])
            end
            @test passive(p) ≈ E
        end
    end
    @testset "Only earth path and missing/doubled counterfactuals" begin
        net=base(); net["bus"]["hv"]["perfectly_grounded_terminals"]=["n"]
        r=ybus_augmented(net); rhs=zeros(ComplexF64,size(r.K,1))
        # Inject on the isolated secondary: its finite grounding branch must
        # carry the net injection; no primary-neutral bond is permitted.
        rhs[r.index[("lv","a")]]=1.
        fixed=r.index[("hv","a")]; free=setdiff(axes(r.K,1),[fixed])
        v=zeros(ComplexF64,size(r.K,1)); v[fixed]=230.
        v[free]=r.K[free,free]\(rhs[free]-r.K[free,[fixed]]*v[[fixed]])
        @test v[r.index[("lv","n")]] ≈ 2.
        @test v[r.index[("lv","a")]] ≈ 232.
        @test v[r.index[("lv","n")]]/2 ≈ sum(rhs)
        @test norm((2Matrix(r.K)*v-rhs)[free])>0.9
        @test norm((zeros(size(r.K))*v-rhs)[free])>0.9
        rt=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test Matrix(ybus_augmented(rt).K)==Matrix(r.K)
    end
    @testset "Promoted transformer agrees with finite leakage limit" begin
        net=base(); x=net["transformer"]["single_phase"]["t"]
        x["v_nom_from"]=460.; net["bus"]["hv"]["perfectly_grounded_terminals"]=["n"]
        function solve_boundary(r)
            K=hasproperty(r,:K) ? Matrix(r.K) : Matrix(r.Y)
            fixed=r.index[("hv","a")]; free=setdiff(axes(K,1),[fixed])
            rhs=zeros(ComplexF64,size(K,1)); rhs[r.index[("lv","a")]]=1.
            v=zeros(ComplexF64,size(K,1)); v[fixed]=460.
            v[free]=K[free,free]\(rhs[free]-K[free,[fixed]]*v[[fixed]])
            @test norm((K*v-rhs)[free])<1e-7
            v[r.index[("lv","a")]],v[r.index[("lv","n")]]
        end
        ref=solve_boundary(ybus_augmented(net))
        @test ref[2] ≈ 2.
        @test ref[1]-ref[2] ≈ 230.
        errs=Float64[]
        for z in (1e-3,1e-4,1e-5)
            x["r_series_to"]=z
            v=solve_boundary(ybus_passive(net))
            push!(errs,maximum(abs.(v.-ref)))
            @test v[2]/2 ≈ 1. atol=1e-7
        end
        @test issorted(errs;rev=true)
        @test errs[end]<1e-4
    end
end
