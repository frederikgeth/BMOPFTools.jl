using Test, BMOPFTools, LinearAlgebra, JSON3

function _nwi_net(nw,mode;style=:wye,roll=1,nph=3)
    N=[1.,.5,.25,2.][1:nw]
    zs = mode==:ideal ? zeros(ComplexF64,nw) :
        mode==:partial ? vcat([.02+.03im],zeros(ComplexF64,nw-1)) :
        mode==:near ? vcat([.02+.03im],fill(1e-9+2e-9im,nw-1)) :
        ComplexF64[(.02+.01k)+im*(.03+.01k) for k in 1:nw]
    phases=nph==1 ? ["a"] : ["a","b","c"]
    ws=Dict{String,Any}[]; buses=Dict{String,Any}()
    for k in 1:nw
        delta=style==:delta || (style==:mixed && iseven(k))
        tm=delta ? copy(phases) : vcat(phases,["n"])
        w=Dict{String,Any}("bus"=>"w$k","terminal_map"=>tm,"v_nom"=>230N[k],
            "r_winding"=>real(zs[k])*N[k]^2,"configuration"=>delta ? "DELTA" : "WYE",
            "delta_roll"=>roll)
        push!(ws,w); buses["w$k"]=Dict{String,Any}("terminal_names"=>copy(tm))
    end
    x=Dict{String,Any}("windings"=>ws,"x_sc"=>Dict{String,Any}(
        "$(i)_$(j)"=>imag(zs[i]+zs[j]) for i in 1:nw for j in i+1:nw),
        "g_no_load"=>.003,"b_no_load"=>-.002)
    net=Dict{String,Any}("bus"=>buses,"transformer"=>Dict("n_winding"=>Dict("x"=>x)))
    net,x,N,zs
end

@testset "N-winding references distinguish missing nodes from earth (PSK-000002)" begin
    for mode in (:ideal, :partial, :near, :finite), mutation in (
            (net, x) -> (x["windings"][2]["bus"] = "missing"),
            (net, x) -> filter!(!=("a"), net["bus"]["w2"]["terminal_names"]),
            (net, x) -> filter!(!=("n"), net["bus"]["w2"]["terminal_names"]))
        net, x, _, _ = _nwi_net(3, mode; nph=1)
        mutation(net, x)
        before = deepcopy(net)
        for builder in (ybus_passive, ybus_linearized, ybus_augmented)
            @test_throws ArgumentError builder(net)
        end
        @test_throws ArgumentError ybus_augmented(net; ideal_xfmrs=:stamp)
        @test net == before
        rt = JSON3.read(JSON3.write(net), Dict{String,Any})
        @test_throws ArgumentError ybus_augmented(rt)
    end
    for mode in (:ideal, :partial, :near, :finite)
        grounded, _, _, _ = _nwi_net(3, mode; nph=1)
        for bus in values(grounded["bus"])
            bus["perfectly_grounded_terminals"] = ["n"]
        end
        explicit = ybus_augmented(grounded)
        @test all(explicit.index[("w$k", "n")] == 0 for k in 1:3)
        implicit = deepcopy(grounded)
        for bus in values(implicit["bus"])
            filter!(!=("n"), bus["terminal_names"])
            delete!(bus, "perfectly_grounded_terminals")
        end
        for w in implicit["transformer"]["n_winding"]["x"]["windings"]
            filter!(!=("n"), w["terminal_map"])
        end
        earth = ybus_augmented(implicit)
        @test earth.nodes == explicit.nodes
        @test earth.K ≈ explicit.K
        rt = JSON3.read(JSON3.write(implicit), Dict{String,Any})
        @test ybus_augmented(rt).K ≈ earth.K
    end
    witness = JSON3.read(read(joinpath(@__DIR__, "data", "ideal_nwinding.json"), String), Dict{String,Any})
    witness["transformer"]["n_winding"]["x"]["windings"][2]["bus"] = "missing"
    @test_throws ArgumentError ybus_augmented(witness)
end

@testset "N-winding singular and finite port modes (#452, PSK-000002)" begin
    for nw in 2:4, mode in (:ideal,:partial,:near,:finite),style in (:wye,:mixed,:delta),roll in (-1,1)
        net,x,N,zs=_nwi_net(nw,mode;style,roll); before=deepcopy(net)
        r=ybus_augmented(net;config=_leakage_config(1.)); K=Matrix(r.K); n=length(r.nodes)
        Z=Matrix(Diagonal(zs[2:end]))+fill(zs[1],nw-1,nw-1)
        @test length(r.couplings)==3*(nw-1)
        @test K ≈ transpose(K)
        @test BMOPFTools._nw_zb_matrix(x) ≈ Z
        scale=r.couplings[1].scale
        for p in 1:3
            rows=n .+ ((p-1)*(nw-1)+1:p*(nw-1))
            @test K[rows,rows] ≈ -scale^2*Z
        end
        # Construct compatible coil voltages from independent star-arm laws,
        # including finite modes of a singular matrix. Currents sum to a
        # balanced three-phase set, so DELTA coil drops are compatible.
        current=ComplexF64[(.3k+.1im)*cis(-2π*(p-1)/3) for k in 1:nw-1,p in 1:3]
        coils=zeros(ComplexF64,nw,3)
        for p in 1:3
            coils[1,p]=230cis(-2π*(p-1)/3)
            for k in 2:nw
                coils[k,p]=N[k]*(coils[1,p]-zs[1]*sum(current[:,p])-zs[k]*current[k-1,p])
            end
        end
        v=zeros(ComplexF64,size(K,1)); expected=zeros(ComplexF64,n)
        expected_shunts=zeros(ComplexF64,n,n)
        for k in 1:nw
            w=x["windings"][k]; delta=w["configuration"]=="DELTA"
            ids=[r.index[("w$k",p)] for p in ("a","b","c")]
            if delta
                # Explicit terminal-to-coil map; a uniform offset is a free
                # winding reference and must not draw any transformer current.
                D=zeros(3,3)
                for p in 1:3; D[p,p]=1.; D[p,mod1(p+roll,3)]=-1.; end
                v[ids]=pinv(D)*coils[k,:] .+ (7k+.5im)
            else
                ni=r.index[("w$k","n")]; v[ni]=7k+.5im
                v[ids]=coils[k,:].+v[ni]
            end
            for p in 1:3
                i=k==1 ? sum(current[:,p]) : -current[k-1,p]/N[k]
                k==2 && (i+=(.003-.002im)*coils[k,p])
                q=delta ? ids[mod1(p+roll,3)] : r.index[("w$k","n")]
                expected[ids[p]]+=i; expected[q]-=i
                if k==2
                    a=ids[p]; y=.003-.002im
                    expected_shunts[a,a]+=y; expected_shunts[q,q]+=y
                    expected_shunts[a,q]-=y; expected_shunts[q,a]-=y
                end
            end
        end
        v[n+1:end]=vec(current)/scale
        actual=K*v
        @test norm(actual[n+1:end])<1e-10
        @test actual[1:n] ≈ expected atol=1e-10
        @test K[1:n,1:n] ≈ expected_shunts
        @test abs(sum(actual[1:n]))<1e-9
        expected_power=sum(abs2,coils[2,:])*(.003+.002im)
        for p in 1:3
            expected_power+=abs2(sum(current[:,p]))*zs[1]+sum(abs2(current[k-1,p])*zs[k] for k in 2:nw)
        end
        @test sum(v[1:n].*conj.(actual[1:n])) ≈ expected_power atol=1e-8
        for k in 1:nw
            shift=zeros(ComplexF64,size(K,1))
            for t in x["windings"][k]["terminal_map"]; shift[r.index[("w$k",t)]]=1.; end
            @test norm(K*shift)<1e-12
        end
        if mode==:finite || (mode in (:partial,:near) && nw==2)
            Y=K[1:n,1:n]-K[1:n,n+1:end]*(lu(K[n+1:end,n+1:end])\collect(K[n+1:end,1:n]))
            @test Y ≈ Matrix(ybus_passive(net).Y)
        elseif mode==:near
            @test !BMOPFTools._xfmr_leakage_policy(x,"n_winding",1e-6).exact_zero
            @test length(ybus_augmented(net).couplings)==3*(nw-1)
        else
            @test_throws ArgumentError BMOPFTools.nwinding_yprim(x)
            _,S=BMOPFTools.nwinding_yprim(x;shunt_only=true)
            @test norm(S)>0 # singular ZB must not erase excitation
        end
        @test net==before
        rt=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test ybus_augmented(rt;config=_leakage_config(1.)).K==r.K
    end
    # A boundary-value solve exercises a rank-deficient ZB under unequal loads.
    # Its analytic common star voltage follows from the total referred current.
    for mode in (:ideal,:partial)
        net,x,N,zs=_nwi_net(3,mode;nph=1)
        for bus in values(net["bus"]); bus["perfectly_grounded_terminals"]=["n"]; end
        function solve_loaded(net)
            r=ybus_augmented(net;config=_leakage_config(1.)); K=Matrix(r.K)
            fixed=r.index[("w1","a")]; free=setdiff(axes(K,1),[fixed])
            v=zeros(ComplexF64,size(K,1)); v[fixed]=230.
            rhs=zeros(ComplexF64,size(K,1)); rhs[r.index[("w2","a")]]=-1.; rhs[r.index[("w3","a")]]=-2.
            v[free]=lu(K[free,free])\(rhs[free]-K[free,[fixed]]*v[[fixed]])
            @test norm((K*v-rhs)[free])<1e-10
            [v[r.index[("w$k","a")]] for k in 2:3]
        end
        ref=solve_loaded(net); y=.003-.002im
        total=(N[2]+2N[3]+N[2]^2*y*230)/(1+N[2]^2*y*zs[1])
        @test ref ≈ N[2:3].*(230-zs[1]*total)
        errs=Float64[]
        for e in (1e-3,1e-4,1e-5)
            finite=deepcopy(net); xx=finite["transformer"]["n_winding"]["x"]
            for k in 2:3; xx["windings"][k]["r_winding"]=e*N[k]^2; end
            push!(errs,norm(solve_loaded(finite)-ref))
        end
        @test issorted(errs;rev=true)
        @test errs[end]<1e-4
    end
    # One-phase, partly singular witness also works at a zero cutoff: choose
    # the border by numerical rank, but preserve the supplied finite block.
    witness=JSON3.read(read(joinpath(@__DIR__,"data","ideal_nwinding.json"),String),Dict{String,Any})
    r=ybus_augmented(witness;config=_leakage_config(0.)); n=length(r.nodes)
    @test length(r.couplings)==2
    @test rank(Matrix(r.K[n+1:end,n+1:end]))==1
    @test_throws ArgumentError ybus_passive(witness;config=_leakage_config(0.))
    # Unsupported domains are explicit for primitive and augmented paths.
    for mutation in (
        x->(x["windings"][2]["configuration"]="ZIGZAG"),
        x->(x["windings"][2]["terminal_map"]=["a","n","n"]),
        x->(x["windings"][2]["terminal_map"]=["a","b"]),
        x->(x["windings"][2]["terminal_map"]=["red","n"]),
        x->(x["windings"][2]["v_nom"]=0.),
        x->(x["windings"][2]["r_neutral"]=1.),
        x->delete!(x["x_sc"],"1_2"),
        x->(x["x_sc"]["1_2"]=NaN))
        net,x,_,_=_nwi_net(3,:ideal;nph=1); mutation(x)
        @test_throws ArgumentError ybus_augmented(net)
        @test_throws ArgumentError BMOPFTools.nwinding_yprim(x;shunt_only=true)
    end
    for roll in (0,2,true)
        net,x,_,_=_nwi_net(3,:ideal;style=:delta); x["windings"][2]["delta_roll"]=roll
        @test_throws ArgumentError ybus_augmented(net)
    end
end
