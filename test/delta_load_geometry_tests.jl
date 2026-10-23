using Test, BMOPFTools, JSON3

@testset "Shared DELTA load geometry (#455, PSK-000002)" begin
    base()=JSON3.read(read(joinpath(@__DIR__,"data","delta_load_geometry.json"),String),Dict{String,Any})
    caught(f)=try f(); nothing catch e; e end
    @testset "Map/count enumeration and public rejection" begin
        for neutral in ("n","4","return"), tm0 in (["a","b"],["a","b","c"],["a","b","n"],["a","b","c","n"]), n in 1:4
            net=base(); tm=replace(tm0,"n"=>neutral)
            net["bus"]["b"]["terminal_names"]=["a","b","c",neutral]
            net["bus"]["b"]["perfectly_grounded_terminals"]=[neutral]
            net["terminal_conventions"]=Dict("phase"=>["a","b","c"],"neutral"=>[neutral],"earth"=>String[])
            l=net["load"]["l"]; l["terminal_map"]=tm; l["p_nom"]=fill(1000.,n); l["q_nom"]=fill(200.,n)
            valid=!(neutral in tm) && n==(length(tm)==2 ? 1 : 3)
            before=deepcopy(net)
            err=caught(()->ybus_linearized(net))
            @test (err===nothing)==valid
            if valid
                sub=BMOPFTools._load_subloads(l,net)
                pairs=length(tm)==2 ? [(tm[1],tm[2])] : [(tm[1],tm[2]),(tm[2],tm[3]),(tm[3],tm[1])]
                @test [(s.pos[2],s.neg[2]) for s in sub]==pairs
                @test sum(s.p0 for s in sub)==1000n
                rt=JSON3.read(JSON3.write(net),Dict{String,Any})
                @test Matrix(ybus_linearized(rt).Y)==Matrix(ybus_linearized(net).Y)
            else
                @test err isa ArgumentError
            end
            if isdefined(Main,:_HAS_JUMP_IPOPT) && _HAS_JUMP_IPOPT
                for pu in (false,true)
                    model=JuMP.Model()
                    ctx=nothing
                    opferr=caught(()->(ctx=build_opf_model(net;per_unit=pu,model)))
                    @test (opferr===nothing)==valid
                    if valid
                        keys=opf_object_keys(ctx)
                        @test OpfModelKey(:variable,:crd,("l",n)) in keys
                        @test OpfModelKey(:variable,:crd,("l",n+1)) ∉ keys
                        @test OpfModelKey(:variable,:cid,("l",n+1)) ∉ keys
                        if !pu
                            volts=Dict("a"=>230+0im,"b"=>230cis(-2pi/3),"c"=>230cis(2pi/3),neutral=>0im)
                            vals=Dict(v=>0. for v in JuMP.all_variables(model))
                            for (t,v) in volts
                                vals[opf_object(ctx,OpfModelKey(:variable,:vr,("b",t)))]=real(v)
                                vals[opf_object(ctx,OpfModelKey(:variable,:vi,("b",t)))]=imag(v)
                            end
                            for k in 1:n
                                a=tm[k];b=tm[mod1(k+1,length(tm))]
                                i=conj((1000+200im)/(volts[a]-volts[b]))
                                vals[opf_object(ctx,OpfModelKey(:variable,:crd,("l",k)))]=real(i)
                                vals[opf_object(ctx,OpfModelKey(:variable,:cid,("l",k)))]=imag(i)
                                for family in (:load_power_real,:load_power_imag)
                                    row=JuMP.constraint_object(opf_object(ctx,OpfModelKey(:constraint,family,("l",k))))
                                    @test JuMP.value(v->vals[v],row.func) ≈ row.set.value atol=1e-8
                                end
                            end
                        end
                    else
                        @test opferr isa ArgumentError
                        @test sprint(showerror,opferr)==sprint(showerror,err)
                        @test JuMP.num_variables(model)==0
                    end
                end
            end
            @test net==before
        end
    end
    @testset "Invalid shape, identity, and power arrays" begin
        for (field,value) in (("terminal_map",["a","a"]),("terminal_map",["a","unknown"]),
            ("terminal_map",["a"]),("terminal_map",["a",1]),("q_nom",Float64[]),
            ("q_nom",[0.,0.]),("p_nom",[Inf]),("q_nom",[NaN]),("p_nom",[true]))
            net=base(); l=net["load"]["l"];l["p_nom"]=[1000.];l["q_nom"]=[200.];l[field]=value
            @test_throws ArgumentError BMOPFTools._load_subloads(l,net)
        end
    end
    @testset "Independent folded current and power for valid phase permutations" begin
        for tm in (["a","b"],["b","a"],["c","a","b"],["c","b","a"])
            net=base(); l=net["load"]["l"]; n=length(tm)==2 ? 1 : 3
            l["terminal_map"]=tm;l["p_nom"]=collect(1000.:1000.:1000n);l["q_nom"]=fill(200.,n)
            r=ybus_linearized(net)
            volts=Dict("a"=>230+0im,"b"=>230cis(-2pi/3),"c"=>230cis(2pi/3),"n"=>0im)
            v=ComplexF64[volts[t] for (_,t) in r.nodes]
            inj=r.i_comp(v)
            expected=zeros(ComplexF64,length(r.nodes))
            for k in 1:n
                a=tm[k];b=tm[mod1(k+1,length(tm))]
                i=conj(complex(l["p_nom"][k],200.)/(volts[a]-volts[b]))
                expected[r.index[("b",a)]]-=i;expected[r.index[("b",b)]]+=i
            end
            @test inj ≈ expected
            @test sum(v.*conj.(-inj)) ≈ sum(l["p_nom"])+200n*im
        end
    end
end
