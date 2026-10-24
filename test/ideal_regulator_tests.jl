using Test, BMOPFTools, LinearAlgebra, JSON3

@testset "Regulator bordered ports and copper bonds (#452, PSK-000013)" begin
    for kind in ("single_phase_autotransformer","open_delta_regulator"),
        rt in ("A","B"), tap in (.95,1.,1.05), z in (0.,1e-9,.01)
        net,x=_leakage_net(kind;z,tap)
        x["regulator_type"]=rt; x["g_no_load"]=.003; x["b_no_load"]=-.002
        # Force the same exact bordered representation for the finite controls.
        r=ybus_augmented(net;config=_leakage_config(1.)); n=length(r.nodes); K=Matrix(r.K)
        shared=kind=="single_phase_autotransformer" ? "n" : "b"
        @test r.index[("f",shared)]==r.index[("t",shared)]
        @test length(r.couplings)==(kind=="single_phase_autotransformer" ? 1 : 2)
        @test K ≈ transpose(K)
        # Independent finite-shunt oracle: across each from-side coil once.
        E=zeros(ComplexF64,n,n)
        pairs=kind=="single_phase_autotransformer" ? [("a","n")] : [("a","b"),("b","c")]
        for (p,q) in pairs
            a=r.index[("f",p)]; b=r.index[("f",q)]; y=.003-.002im
            E[a,a]+=y; E[b,b]+=y; E[a,b]-=y; E[b,a]-=y
        end
        @test K[1:n,1:n] ≈ E
        if z>0
            Y=K[1:n,1:n]-K[1:n,n+1:end]*(K[n+1:end,n+1:end]\K[n+1:end,1:n])
            @test Y ≈ Matrix(ybus_passive(net;config=_leakage_config(0.)).Y)
        end
        # Prescribed, unbalanced input with a shifted shared reference. Solve
        # independent output injections, then check every coil's voltage law.
        v=zeros(ComplexF64,size(K,1)); fixed=Int[]
        for (k,t) in enumerate(net["bus"]["f"]["terminal_names"])
            i=r.index[("f",t)]; push!(fixed,i); v[i]=t==shared ? 17. : 230cis(.7k)
        end
        free=setdiff(axes(K,1),fixed); rhs=zeros(ComplexF64,size(K,1))
        for t in setdiff(net["bus"]["t"]["terminal_names"],[shared])
            rhs[r.index[("t",t)]]=-1.0 + .2im
        end
        v[free]=K[free,free]\(rhs[free]-K[free,fixed]*v[fixed])
        @test norm((K*v-rhs)[free])<1e-10
        ne=rt=="A" ? tap : 1/tap
        for (k,(p,q)) in enumerate(pairs)
            ufrom=v[r.index[("f",p)]]-v[r.index[("f",q)]]
            uto=v[r.index[("t",p)]]-v[r.index[("t",q)]]
            i=r.couplings[k].scale*v[n+k]
            @test ufrom-ne*uto ≈ z*(1+ne^2)*i atol=1e-10
        end
        currents=(K*v)[1:n]
        @test abs(sum(currents))<1e-10
        # Passive absorbed power equals independently calculated shunt and
        # series loss, with no phantom path to earth.
        power=sum(v[1:n].*conj.(currents))
        expected=sum(abs2(v[r.index[("f",p)]]-v[r.index[("f",q)]])*(.003+.002im) for (p,q) in pairs)
        expected+=sum(abs2(c.scale*v[n+k])*z*(1+ne^2) for (k,c) in enumerate(r.couplings))
        @test power ≈ expected atol=1e-8
        rt_net=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test ybus_augmented(rt_net;config=_leakage_config(1.)).K==r.K
    end
    # Mixed threshold classification: retaining a finite core matters even
    # when only its partner triggers the bordered representation.
    net,x=_leakage_net("open_delta_regulator";z=0.)
    x["tap_ratio"]=[.5,2.]; x["r_series_to"]=1e-6
    r=ybus_augmented(net); n=length(r.nodes)
    @test Matrix(r.K[n+1:end,n+1:end]) ≈ -Diagonal([.25e-6,4e-6])
    for (connection,shared) in (("ABBC","b"),("BCAC","c"),("CABA","a"))
        x["connection"]=connection
        r=ybus_augmented(net)
        @test r.index[("f",shared)]==r.index[("t",shared)]
        net["bus"]["f"]["perfectly_grounded_terminals"]=[shared]
        @test ybus_augmented(net).index[("t",shared)]==0
        net["bus"]["f"]["perfectly_grounded_terminals"]=String[]
    end
    for kind in ("single_phase_autotransformer","open_delta_regulator"), tap in (0.,-1.,Inf,NaN,true)
        net,x=_leakage_net(kind)
        x["tap_ratio"]=kind=="open_delta_regulator" ? [tap,tap] : tap
        @test_throws ArgumentError ybus_augmented(net)
        @test_throws ArgumentError ybus_passive(net)
    end
    witness=JSON3.read(read(joinpath(@__DIR__,"data","ideal_regulator.json"),String),Dict{String,Any})
    wr=ybus_augmented(witness)
    @test length(wr.couplings)==1
    @test wr.index[("f","n")]==wr.index[("t","n")]
    # An isolated unity-ratio transformer has no galvanic bond; a regulator does.
    net,x=_leakage_net("single_phase";ratio=1.)
    @test ybus_augmented(net).index[("f","n")] != ybus_augmented(net).index[("t","n")]
    net,x=_leakage_net("single_phase_autotransformer")
    @test ybus_augmented(net).index[("f","n")] == ybus_augmented(net).index[("t","n")]
end
