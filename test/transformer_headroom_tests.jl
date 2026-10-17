using Test, BMOPFTools, JSON3, JSONSchema

preflight413_net() = JSON3.read(read(joinpath(@__DIR__,"data","transformer_loading","overloaded_coil.json"),String),Dict{String,Any})["net"]
function preflight413(net)
    findings=Finding[]
    result=BMOPFTools._transformer_headroom_preflight(net,findings)
    result,only(result["transformers"]),findings
end

@testset "Qualified nominal transformer coil headroom (#413)" begin
    @testset "analytic boundaries, evidence and unchanged aggregate warning" begin
        for (p,comparison) in ((30000.,"positive_nominal_headroom"),(100000/3,"at_nominal_cap"),(40000.,"negative_nominal_headroom"))
            n=preflight413_net(); n["load"]["d"]["p_nom"]=[p]; before=deepcopy(n)
            root,e,f=preflight413(n); row=e["coils"][1]
            @test e["status"]=="estimated"
            @test row["s_nom_VA"]==p
            @test row["cap_VA"]==100000/3
            @test row["headroom_VA"]==100000/3-p
            @test row["comparison_status"]==comparison
            @test row["source_terminal"]=="a"
            @test e["bank_utilization"]≈p/100000
            @test all(r->r["s_nom_VA"]==0,e["coils"][2:3])
            @test count(x->x.code=="W.PRE.XFMR_COIL_HEADROOM",f)==(p>100000/3 ? 1 : 0)
            @test root["evidence"]=="nominal_demand_estimate"
            @test !root["proves_feasibility"] && !root["proves_infeasibility"] && !root["solver_run"]
            @test n==before
        end
        n=preflight413_net(); before=deepcopy(n); r=analyze(n)
        e=only(r.results[:preflight]["transformer_coil_headroom"]["transformers"])
        @test e["coils"][1]["utilization"]≈1.2
        @test only(r.results[:operational]["transformer_utilisation"])["utilisation_pct"]==40
        @test !any(f->f.code=="W.OPS.XFMR_OVERLOADED",r.findings)
        @test n==before
        # Retain the existing aggregate >90% (rounded to one decimal) policy.
        for (p,warn) in ((90000.,false),(91000.,true))
            n["load"]["d"]["p_nom"]=[p]; findings=Finding[]
            operational_analysis(n,findings)
            @test any(f->f.code=="W.OPS.XFMR_OVERLOADED",findings)==warn
        end
    end
    @testset "signed Q, nominal models and load provenance" begin
        for model in ("constant_power","constant_current","constant_impedance"), sign in (-1,1)
            n=preflight413_net(); d=n["load"]["d"]
            d["model"]=model; d["p_nom"]=[24000]; d["q_nom"]=[sign*18000]
            _,e,_=preflight413(n); row=e["coils"][1]
            @test row["s_nom_VA"]==30000
            @test row["q_nom_var"]==sign*18000
            @test only(row["contributions"])["model"]==model
            @test only(row["contributions"])["v_nom_V"]==230
            n["load"]["opposite"]=deepcopy(d); n["load"]["opposite"]["q_nom"]=[-sign*18000]
            _,e,_=preflight413(n)
            @test e["coils"][1]["s_nom_VA"]==48000
            @test length(e["coils"][1]["contributions"])==2
        end
        n=preflight413_net(); d=n["load"]["d"]
        d["configuration"]="WYE"; d["terminal_map"]=["b","n","a","c"]
        d["p_nom"]=[1000,24000,0]; d["q_nom"]=[0,18000,0]; d["v_nom"]=[230,230,230]
        _,e,_=preflight413(n)
        @test [r["s_nom_VA"] for r in e["coils"]]==[30000,1000,0]
        empty!(n["load"]); _,e,_=preflight413(n)
        @test all(r->r["s_nom_VA"]==0,e["coils"])
    end
    @testset "explicit permutations, branches and reversed line orientation" begin
        n=preflight413_net()
        n["bus"]["u"]=Dict("terminal_names"=>["x","y","z","n"])
        n["terminal_conventions"]=Dict("phase"=>["a","b","c","x","y","z"],"neutral"=>["n"],"earth"=>String[])
        # Explicit position map: x maps to b, y to c, z to a.
        line=Dict{String,Any}("bus_from"=>"u","bus_to"=>"t",
            "terminal_map_from"=>["x","y","z","n"],"terminal_map_to"=>["b","c","a","n"])
        n["line"]=Dict("l"=>line); n["load"]["d"]["bus"]="u"; n["load"]["d"]["terminal_map"]=["z","n"]
        _,e,_=preflight413(n)
        @test [r["s_nom_VA"] for r in e["coils"]]==[40000,0,0]
        @test e["terminal_roles"]=="declared"
        @test only(e["coils"][1]["contributions"])["source_path"]==["transformer.tx","line.l"]
        # Relabel the transformer secondary explicitly; the load now reaches coil 2.
        n["transformer"]["single_phase"]["tx"]["terminal_map_to"]=["c","a","b","n"]
        _,e,_=preflight413(n)
        @test [r["s_nom_VA"] for r in e["coils"]]==[0,40000,0]
        delete!(n,"line"); n["switch"]=Dict("sw"=>line); line["open_switch"]=false
        _,e,_=preflight413(n); @test e["status"]=="estimated"
        line["open_switch"]=true
        _,e,_=preflight413(n); @test e["reason"]=="disconnected_network"
        # Upstream load is not silently counted as transformer demand.
        n=preflight413_net(); n["load"]["up"]=deepcopy(n["load"]["d"]); n["load"]["up"]["bus"]="f"
        _,e,_=preflight413(n); @test e["bank_s_sum_VA"]==40000
    end
    @testset "unsupported and incomplete inputs yield no guessed allocation" begin
        cases=[
            ("requires_one_voltage_source", n->(n["voltage_source"]["other"]=deepcopy(n["voltage_source"]["s"]))),
            ("requires_one_voltage_source", n->empty!(n["voltage_source"])),
            ("requires_one_transformer_bank", n->(n["transformer"]["single_phase"]["other"]=deepcopy(n["transformer"]["single_phase"]["tx"]))),
            ("unsupported_transformer_subtype", n->(n["transformer"]["wye_delta"]=pop!(n["transformer"],"single_phase"))),
            ("tap_or_control_decision", n->(n["transformer"]["single_phase"]["tx"]["tap_min"]=0.9)),
            ("reverse_fed_transformer", n->(n["voltage_source"]["s"]["bus"]="t")),
            ("meshed_or_parallel_supply_paths", n->(n["line"]=Dict("bypass"=>deepcopy(n["transformer"]["single_phase"]["tx"])))),
            ("ambiguous_load_map", n->(n["load"]["d"]["terminal_map"]=["a","b"])),
            ("unsupported_load_model_or_connection", n->(n["load"]["d"]["configuration"]="DELTA")),
            ("unsupported_load_model_or_connection", n->(n["load"]["d"]["model"]="zip")),
            ("invalid_branch_map", n->delete!(n["transformer"]["single_phase"]["tx"],"terminal_map_to")),
            ("invalid_branch_map", n->(n["transformer"]["single_phase"]["tx"]["terminal_map_to"]=["a","a","c","n"])),
            ("invalid_branch_map", n->(n["transformer"]["single_phase"]["tx"]["terminal_map_to"]=["a","b","n","c"])),
            ("invalid_terminal_role_declaration", n->(n["terminal_conventions"]=42)),
            ("invalid_terminal_role_declaration", n->(n["terminal_conventions"]=Dict("phase"=>"abc","neutral"=>["n"]))),
            ("ambiguous_terminal_roles", n->(n["terminal_conventions"]=Dict("phase"=>["a","b","c","n"],"neutral"=>["n"]))),
            ("terminal_not_supplied", n->(n["voltage_source"]["s"]["terminal_map"]= ["a"];n["voltage_source"]["s"]["v_magnitude"]=[230];n["voltage_source"]["s"]["v_angle"]=[0])),
            ("invalid_load_nominal_voltage", n->delete!(n["load"]["d"],"v_nom")),
        ]
        for (reason,mutate) in cases
            n=preflight413_net(); mutate(n); before=deepcopy(n)
            f=Finding[]; r=BMOPFTools._transformer_headroom_preflight(n,f)
            @test all(e->e["reason"]==reason,r["transformers"])
            @test all(e->isempty(e["coils"]),r["transformers"])
            @test all(x->x.code=="I.PRE.XFMR_COIL_UNASSESSED",f)
            @test n==before
        end
        for kind in ("generator","ibr","shunt","capacitor","control_profile","dc_bus")
            n=preflight413_net(); n[kind]=Dict("x"=>Dict()); _,e,_=preflight413(n)
            @test e["reason"]=="unsupported_component"
            @test e["context"]["collection"]==kind
        end
        for v in (nothing,0,-1,NaN,Inf,true)
            n=preflight413_net(); n["transformer"]["single_phase"]["tx"]["s_rating"]=v
            _,e,_=preflight413(n)
            @test e["reason"]=="missing_or_invalid_positive_rating"
            @test e["status"]=="indeterminate"
            @test isempty(e["coils"])
        end
        for field in ("p_nom","q_nom"), v in ([],[NaN],[Inf],[true],[1,2])
            n=preflight413_net(); n["load"]["d"][field]=v; _,e,_=preflight413(n)
            @test e["reason"]=="invalid_or_negative_nominal_demand"
        end
        n=preflight413_net(); n["load"]["d"]["p_nom"]=[-1]
        @test preflight413(n)[2]["reason"]=="invalid_or_negative_nominal_demand"
    end
    @testset "JSON, Markdown, deterministic order and no solved-data confusion" begin
        n=preflight413_net(); before=deepcopy(n); r=analyze(n)
        root=r.results[:preflight]["transformer_coil_headroom"]
        envelope=execute_analysis(n)
        restored=JSON3.read(JSON3.write(envelope),Dict{String,Any})
        @test restored["result"]["results"]["preflight"]["transformer_coil_headroom"]==root
        schema=JSONSchema.Schema(JSON3.read(read(joinpath(@__DIR__,"..","schemas","execution-response.schema.json"),String)))
        @test JSONSchema.validate(schema,JSON3.read(JSON3.write(envelope)))===nothing
        @test preflight413(JSON3.read(JSON3.write(n),Dict{String,Any}))[1]==root
        @test !haskey(r.results,:transformer_loading)
        @test !haskey(profile_solution(n,Dict{String,Any}()).results,:preflight)
        io=IOBuffer(); BMOPFTools.render_markdown(r,io); md=String(take!(io))
        @test occursin("Nominal transformer coil headroom",md)
        @test occursin("not a feasibility",md)
        @test occursin("40000.0",md)
        @test n==before
        n["load"]["z"]=deepcopy(n["load"]["d"])
        _,e,_=preflight413(n)
        n["load"]=Dict(reverse(collect(n["load"])))
        @test preflight413(n)[2]==e
        delete!(n["transformer"]["single_phase"]["tx"],"s_rating")
        r=analyze(n); io=IOBuffer(); BMOPFTools.render_markdown(r,io)
        @test occursin("missing_or_invalid_positive_rating",String(take!(io)))
    end
end
