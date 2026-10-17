using Test, BMOPFTools, JSON3, LinearAlgebra, Dates

function _pr_net(kind="delta_wye"; phases=["a","b","c"],neutral="n",fr=[1,2,3],to=[1,2,3])
    net=JSON3.read(read(joinpath(@__DIR__,"data","transformer_phase","letters.json"),String),Dict{String,Any})
    net["terminal_conventions"]=Dict("phase"=>phases,"neutral"=>[neutral],"earth"=>String[])
    for b in values(net["bus"])
        b["terminal_names"]=vcat(phases,[neutral]);b["perfectly_grounded_terminals"]=[neutral]
    end
    x=net["transformer"]["delta_wye"]["x"]
    x["terminal_map_from"]=kind=="delta_wye" ? phases[fr] : vcat(phases[fr],[neutral])
    x["terminal_map_to"]=kind=="wye_delta" ? phases[to] : vcat(phases[to],[neutral])
    net["transformer"]=Dict(kind=>Dict("x"=>x))
    net,x
end

# Independent no-load primitive solve: prescribe the three input voltages and
# both explicit neutrals, and solve I_target=0. pinv fixes only the floating delta
# common mode; phase-to-phase relations do not depend on that gauge.
function _pr_primitive(nodes,Y;rotation=0.0)
    phases=["a","b","c"]
    V=zeros(ComplexF64,length(nodes)); unknown=Int[]
    for (i,(bus,t)) in enumerate(nodes)
        if bus=="f" && t in phases
            V[i]=cis(rotation-2π*(findfirst(==(t),phases)-1)/3)
        elseif bus=="t" && t in phases
            push!(unknown,i)
        end
    end
    fixed=setdiff(eachindex(nodes),unknown)
    V[unknown]=-pinv(Y[unknown,unknown])*(Y[unknown,fixed]*V[fixed])
    ratios=[V[findfirst(==(("t",p)),nodes)]/cis(rotation-2π*(k-1)/3) for (k,p) in enumerate(phases)]
    rotations=ratios./abs.(ratios)
    uniform=maximum(abs.(rotations.-rotations[1]))<1e-8
    clock=uniform ? mod(round(Int,-rad2deg(angle(rotations[1]))/30),12) : nothing
    clock,V
end

@testset "Transformer phase relation evidence (#268)" begin
    perms=([1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1])
    @testset "named correspondence, labels, explicit declarations and direction" begin
        for kind in ("single_phase","delta_wye","wye_delta"), phases in (["1","2","3"],["a","b","c"],["red","gold","blue"]), n in ("n","4","N0")
            net,x=_pr_net(kind;phases,neutral=n)
            order=Dict(b=>phases for b in ("f","t"))
            before=deepcopy(net)
            ev=transformer_phase_relation(net,kind,x;phase_order=order,declared_vector_group="authored-nameplate")
            @test ev["status"]=="known"
            @test ev["clock"]==(kind=="single_phase" ? 0 : 1)
            @test ev["declared_vector_group"]=="authored-nameplate"
            @test ev["declared_provenance"]=="authored_unverified"
            @test ev["windings"][kind=="delta_wye" ? 2 : 1]["resolved_roles"][end]=="neutral"
            back=transformer_phase_relation(net,kind,x;phase_order=order,from_winding=2,to_winding=1)
            @test back["clock"]==mod(-ev["clock"],12)
            @test net==before
            automatic=transformer_phase_relation(net,kind,x)
            @test automatic["status"]==(phases[1]=="red" ? "partial" : "known")
            restored=JSON3.read(JSON3.write(net),Dict{String,Any})
            @test transformer_phase_relation(restored,kind,restored["transformer"][kind]["x"];phase_order=order,declared_vector_group="authored-nameplate")==ev
            @test JSON3.read(JSON3.write(ev),Dict{String,Any})==ev
        end
    end
    @testset "independent full-permutation primitive oracle" begin
        for kind in ("single_phase","delta_wye","wye_delta"), fr in perms,to in perms,tap in (1.,1.06), rotation in (0.,0.7)
            net,x=_pr_net(kind;fr,to);x["tap"]=tap
            ev=transformer_phase_relation(net,kind,x)
            nodes,Y=transformer_yprim(x,kind)
            expected,V=_pr_primitive(nodes,Y;rotation)
            @test norm(Y*V) <= 1e-9*max(norm(Y)*norm(V),1.)
            @test ev["clock"]==expected
            @test ev["status"]==(expected===nothing ? "unsupported" : "known")
            if expected===nothing
                @test ev["reason"]=="nonuniform_phase_relation"
            else
                @test ev["displacement_degrees"] in (-180:30:150)
            end
        end
        # Named, independently readable examples fix the convention explicitly.
        for (kind,clocks) in (("single_phase",[0,8,4]),("delta_wye",[1,9,5]),("wye_delta",[1,9,5]))
            for (to,clock) in zip(([1,2,3],[2,3,1],[3,1,2]),clocks)
                net,x=_pr_net(kind;to)
                @test transformer_phase_relation(net,kind,x)["clock"]==clock
            end
        end
    end
    @testset "n-winding orientation and delta_roll" begin
        for ca in ("WYE","DELTA"), cb in ("WYE","DELTA"), ra in (-1,1),rb in (-1,1)
            net,_=_pr_net()
            x=Dict{String,Any}("windings"=>[Dict{String,Any}("bus"=>b,"configuration"=>cfg,"delta_roll"=>roll,
                "v_nom"=>v,"r_winding"=>.01,"terminal_map"=>cfg=="WYE" ? ["a","b","c","n"] : ["a","b","c"])
                for (b,cfg,roll,v) in (("f",ca,ra,1200.),("t",cb,rb,230.))],"x_sc"=>Dict("1_2"=>.2))
            net["transformer"]=Dict("n_winding"=>Dict("x"=>x))
            ev=transformer_phase_relation(net,"n_winding",x)
            nodes,Y=BMOPFTools.nwinding_yprim(x)
            expected,V=_pr_primitive(nodes,Y;rotation=.3)
            @test norm(Y*V)<=1e-9*max(norm(Y)*norm(V),1.)
            @test ev["clock"]==expected
            @test ev["status"]=="known"
            @test transformer_phase_relation(net,"n_winding",x;from_winding=2,to_winding=1)["clock"]==mod(-expected,12)
            # A third winding keeps its original index and per-winding roll.
            net["bus"]["u"]=deepcopy(net["bus"]["t"])
            w=deepcopy(x["windings"][2]);w["bus"]="u";push!(x["windings"],w)
            summary=inventory_analysis(net,Finding[])["transformer"]["phase_relations"]["n_winding"]["x"]
            @test summary["clock"]===nothing && summary["status"]=="partial"
            @test summary["relations"][2]["to_winding"]==3
            if cb=="DELTA"
                x["windings"][2]["delta_roll"]=0
                invalid=transformer_phase_relation(net,"n_winding",x)
                @test invalid["status"]=="unsupported" && invalid["clock"]===nothing
            end
        end
    end
    @testset "partial, unknown and unsupported never claim clock zero" begin
        cases=[("partial",(n,x)->(x["terminal_map_to"]=["a","n"])),
            ("unknown",(n,x)->(x["terminal_map_to"]=nothing)),
            ("unknown",(n,x)->(x["terminal_map_to"]=["a","a","c","n"])),
            ("unknown",(n,x)->push!(n["terminal_conventions"]["neutral"],"a")),
            ("unknown",(n,x)->(x["bus_to"]="absent")),
            ("unknown",(n,x)->(x["tap"]=-1.0)),
            ("unsupported",(n,x)->(x["terminal_map_to"]=["a","c","b","n"]))]
        for (status,mutate) in cases
            net,x=_pr_net();mutate(net,x);before=deepcopy(net)
            ev=transformer_phase_relation(net,"delta_wye",x)
            @test ev["status"]==status
            @test ev["clock"]===nothing && endswith(ev["display_label"],"?")
            @test net==before
            @test JSON3.read(JSON3.write(ev),Dict{String,Any})==ev
        end
        for kind in ("center_tap","single_phase_autotransformer","open_delta_regulator")
            net,x=_pr_net(kind)
            @test transformer_phase_relation(net,kind,x)["status"]=="unsupported"
            @test transformer_phase_relation(net,kind,x)["clock"]===nothing
        end
        net,x=_pr_net();ev=transformer_phase_relation(net,"delta_wye",x;phase_order=Dict("t"=>["a","a","c"]))
        @test ev["status"]=="unknown" && ev["reason"]=="invalid_phase_correspondence"
        net,x=_pr_net("single_phase";neutral="return")
        x["terminal_map_from"]=["a","return"];x["terminal_map_to"]=["b","return"]
        @test !BMOPFTools._winding_phase_to_phase(net,x,"terminal_map_from")
        x["terminal_map_from"]=["a","b"]
        @test BMOPFTools._winding_phase_to_phase(net,x,"terminal_map_from")
    end
    @testset "consumers, source angle and serialization remain read-only" begin
        net,x=_pr_net()
        net["voltage_source"]=Dict("s"=>Dict("bus"=>"f","terminal_map"=>["a","b","c"],"v_magnitude"=>fill(1200.,3),"v_angle"=>[0.,-2π/3,2π/3]))
        before=deepcopy(net);inv=inventory_analysis(net,Finding[]);vl=voltage_level_analysis(net,Finding[])
        @test haskey(inv["transformer"]["by_vector_group"],"Dyn1")
        tr=only(vl["transformer_transitions"])
        @test tr["vector_group"]=="Dyn1" && tr["phase_relation"]["clock"]==1
        io=IOBuffer();render_ascii_tree(net,io;split_by_level=false);tree=String(take!(io))
        @test occursin("Dyn1",tree) && occursin("f→t",tree)
        @test net==before
        net["voltage_source"]["s"]["v_angle"].+=.7
        @test inventory_analysis(net,Finding[])["transformer"]==inv["transformer"]
        @test voltage_level_analysis(net,Finding[])["transformer_transitions"]==vl["transformer_transitions"]
        @test JSON3.read(JSON3.write(inv["transformer"]),Dict{String,Any})==inv["transformer"]
        r=SummaryReport("phase witness",DateTime(2026,10,18),Dict(:inventory=>inv,:voltage_levels=>vl),Finding[])
        md=IOBuffer();BMOPFTools.render_markdown(r,md)
        term=IOBuffer();render(r,term;color=false)
        @test occursin("effective Dyn1",String(take!(md)))
        @test occursin("effective Dyn1",String(take!(term)))
        net["voltage_source"]["s"]["bus"]="t"
        io=IOBuffer();render_ascii_tree(net,io;split_by_level=false);backtree=String(take!(io))
        @test occursin("YNd11",backtree) && occursin("t→f",backtree)
    end
end
