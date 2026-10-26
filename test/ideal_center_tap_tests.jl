using Test, BMOPFTools, LinearAlgebra, JSON3

@testset "Center-tap ideal and partly ideal ports (#452, PSK-000002)" begin
    for (zf,zl) in ((0.,0.),(0.,.01),(.02,0.),(.02,.01),(1e-9,.01),(.02,1e-9)),
        ratio in (1.,2.,10.), tap in (.95,1.05)
        net,x=_leakage_net("center_tap";ratio,tap)
        x["r_series_from"]=zf; x["x_series_from"]=.4zf
        x["r_series_to"]=zl; x["x_series_to"]=.3zl
        x["g_no_load"]=.003; x["b_no_load"]=-.002
        x["r_neutral_from"]=3.; x["r_neutral_to"]=2.
        before=deepcopy(net)
        r=ybus_augmented(net;config=_leakage_config(1.)); K=Matrix(r.K); n=length(r.nodes)
        @test length(r.couplings)==2
        @test K ≈ transpose(K)
        @test r.index[("f","n")] != r.index[("t","n")]
        zh=complex(zf,.4zf)/ratio^2; zt=complex(zl,.3zl)
        Z=ComplexF64[zh+zt zh; zh zh+zt]
        scale=r.couplings[1].scale
        @test K[n+1:end,n+1:end] ≈ -scale^2*Z
        E=zeros(ComplexF64,n,n); a=r.index[("t","a")]; b=r.index[("t","b")]
        nt=r.index[("t","n")]; nf=r.index[("f","n")]; hf=r.index[("f","a")]
        E[nf,nf]+=1/3; E[nt,nt]+=.5
        E[a,a]+=.003-.002im; E[nt,nt]+=.003-.002im
        E[a,nt]-=.003-.002im; E[nt,a]-=.003-.002im
        @test K[1:n,1:n] ≈ E
        if zf>0 && zl>0
            Y=E-K[1:n,n+1:end]*(lu(K[n+1:end,n+1:end])\collect(K[n+1:end,1:n]))
            @test Y ≈ Matrix(ybus_passive(net;config=_leakage_config(0.)).Y) rtol=1e-7
        end
        # Unequal secondary injections and a shifted primary neutral. The
        # finite LV grounding branch is the only sink for net secondary current.
        v=zeros(ComplexF64,size(K,1)); v[nf]=17.; v[hf]=17+230ratio*tap
        fixed=[hf,nf]; free=setdiff(axes(K,1),fixed)
        rhs=zeros(ComplexF64,size(K,1)); rhs[a]=-1.; rhs[b]=-2.
        v[free]=lu(K[free,free])\(rhs[free]-K[free,fixed]*v[fixed])
        @test norm((K*v-rhs)[free])<1e-9
        @test v[nt] ≈ -6.
        uH=(v[hf]-v[nf])/(ratio*tap); u1=v[a]-v[nt]; u2=v[nt]-v[b]
        i=scale*v[n+1:end]
        @test [uH-u1,uH-u2] ≈ Z*i atol=1e-10
        currents=(K*v)[1:n]; series=currents-E*v[1:n]
        @test series[hf] ≈ (i[1]+i[2])/(ratio*tap) atol=1e-10
        @test series[a] ≈ -i[1] atol=1e-10
        @test series[b] ≈ i[2] atol=1e-10
        @test abs(sum(series))<1e-9
        if zf==zl==0.
            @test u1 ≈ 230.
            @test u2 ≈ 230. # leg2 is opposite polarity relative to neutral
            @test v[a]-v[b] ≈ 460.
        end
        expected=abs2(v[nf])/3+abs2(v[nt])/2+abs2(u1)*(.003+.002im)
        expected+=abs2(i[1]+i[2])*zh+sum(abs2,i)*zt
        @test sum(v[1:n].*conj.(currents)) ≈ expected atol=1e-8
        @test net==before
        rt=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test ybus_augmented(rt;config=_leakage_config(1.)).K==r.K
    end
    # Grounded-neutral elimination keeps the independent ideal leg constraints.
    net,x=_leakage_net("center_tap")
    for bus in values(net["bus"]); bus["perfectly_grounded_terminals"]=["n"]; end
    r=ybus_augmented(net)
    @test length(r.nodes)==3
    @test length(r.couplings)==2
    @test rank(Matrix(r.K))==4 # one free excitation; supplying HV fixes it
    x["terminal_map_to"]=["a","n","a"]
    @test_throws ArgumentError ybus_augmented(net)
    # Serialized minimized witness: a finite primary arm and ideal LV arms.
    witness=JSON3.read(read(joinpath(@__DIR__,"data","ideal_center_tap.json"),String),Dict{String,Any})
    w=ybus_augmented(witness); n=length(w.nodes)
    @test rank(Matrix(w.K[n+1:end,n+1:end]))==1
    @test length(w.couplings)==2
end
