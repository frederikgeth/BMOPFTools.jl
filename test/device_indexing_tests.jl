using Test, BMOPFTools, JSON3

function _idx_net(neutral="n")
    Dict{String,Any}("terminal_conventions"=>Dict("phase"=>["a","b","c"],
        "neutral"=>[neutral],"earth"=>String[]),
        "bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a","b","c",neutral],
            "perfectly_grounded_terminals"=>[neutral])),
        "voltage_source"=>Dict("s"=>Dict("bus"=>"b","terminal_map"=>["a","b","c"],
            "v_magnitude"=>[230.,230.,230.],"v_angle"=>[0.,-2π/3,2π/3])))
end
function _idx_device!(net,kind,topology,tm)
    c=Dict{String,Any}("bus"=>"b","terminal_map"=>tm,
        (kind=="ibr" ? "topology" : "configuration")=>topology)
    net[kind]=Dict("d"=>c); c
end
function _idx_findings(net;spec=false)
    f=Finding[]; integrity_check(net,f)
    spec && spec_conformance_check(net,f)
    f
end
_idx_dim(f,kind,id,field)=[x for x in f if x.code=="W.INT.DIM_MISMATCH" &&
    x.component_type==Symbol(kind) && x.component_id==id && get(x.detail,"field",nothing)==field]

@testset "Device topology and indexing (#408)" begin
    @testset "baseline witness: false positives removed, missed fields detected" begin
        net=JSON3.read(read(joinpath(@__DIR__,"data","device_indexing","roles.json"),String),Dict{String,Any})
        net["bus"]["b"]["vpp_max"]=[400.,400.]
        before=deepcopy(net); f=_idx_findings(net;spec=true)
        @test net==before
        @test isempty([x for x in f if x.code=="W.INT.DIM_MISMATCH" && x.component_type in (:generator,:voltage_source)])
        @test length(_idx_dim(f,"ibr","inv","q_max"))==1
        @test length(_idx_dim(f,"bus","b","vpp_max"))==1
        for x in filter(x -> x.code=="W.INT.DIM_MISMATCH",f)
            @test all(k -> haskey(x.detail,k),("bus","topology","terminal_map","map_positions",
                "resolved_roles","indexing_domain","expected_lengths","observed_shape"))
            @test JSON3.read(JSON3.write(x.detail),Dict{String,Any})==x.detail
        end
        roundtrip=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test roundtrip["terminal_conventions"]==net["terminal_conventions"]
        @test [(x.code,x.detail) for x in _idx_findings(roundtrip)]==[(x.code,x.detail) for x in _idx_findings(net)]
        # Preserve the old "clean IBR" fixture's scalar-Q form as a negative
        # witness. Ingestion retains the scalar; neither that shape nor a
        # one-entry vector broadcasts to all three phases in the native model.
        legacy=_idx_net(); inv=_idx_device!(legacy,"ibr","FOUR_LEG",["a","b","c","n"])
        inv["q_min"]=-3000.; inv["q_max"]=3000.
        parsed=parse_bmopf(JSON3.write(legacy);from_string=true)
        @test parsed["ibr"]["d"]["q_min"]==-3000.
        for field in ("q_min","q_max")
            d=only(_idx_dim(_idx_findings(parsed),"ibr","d",field)).detail
            @test d["expected_lengths"]==[0,3]
            @test d["observed_shape"]["kind"]=="scalar"
            parsed["ibr"]["d"][field]=[parsed["ibr"]["d"][field]]
            @test only(_idx_dim(_idx_findings(parsed),"ibr","d",field)).detail["observed_shape"]["length"]==1
        end
    end

    @testset "field by topology matrix and neutral-label covariance" begin
        for neutral in ("n","4","return"), kind in ("load","generator","ibr"),
            topology in (kind=="ibr" ? ("SINGLE_PHASE","THREE_LEG","FOUR_LEG") : ("SINGLE_PHASE","DELTA","WYE"))
            maps=topology=="SINGLE_PHASE" ? [["a",neutral],["a","b"],[neutral,"a"],["b","a"]] :
                topology in ("DELTA","THREE_LEG") ? [["a","b","c"],["c","a","b"]] :
                [["a","b","c",neutral],[neutral,"c","a","b"],["b",neutral,"a","c"]]
            for tm in maps
                net=_idx_net(neutral); c=_idx_device!(net,kind,topology,tm)
                n=topology=="SINGLE_PHASE" ? 1 : 3
                fields=kind=="load" ? ("p_nom","q_nom") :
                    kind=="generator" ? ("p_min","p_max","q_min","q_max","s_max","cost") :
                    ("p_min","p_max","q_min","q_max","s_max","cost","r_filter","x_filter")
                for field in fields; c[field]=fill(1.,n); end
                good=_idx_findings(net;spec=true)
                @test !any(x -> x.component_id=="d" && (startswith(x.code,"E.") || x.code=="W.INT.DIM_MISMATCH"),good)
                for field in fields
                    for bad in (fill(1.,n+1), fill(1.,max(0,n-1)), 1., "invalid", [Dict("bad"=>1)])
                        c[field]=bad
                        # Empty optional bounds are an explicit absence, not a
                        # one-element broadcast or a partially specified vector.
                        empty_allowed=kind!="load" && !(field in ("cost","r_filter","x_filter")) && bad==Float64[]
                        @test length(_idx_dim(_idx_findings(net),kind,"d",field))==(empty_allowed ? 0 : 1)
                    end
                    c[field]=fill(1.,n)
                end
                if kind!="load"
                    for k in (0,n,n+1)
                        c["i_max"]=fill(10.,k)
                        allowed=topology=="SINGLE_PHASE" ? k in (0,1,2) : topology in ("DELTA","THREE_LEG") ? k in (0,3) : k in (0,3,4)
                        @test isempty(_idx_dim(_idx_findings(net),kind,"d","i_max"))==allowed
                    end
                    c["i_max"]=fill(10.,n+2)
                    @test length(_idx_dim(_idx_findings(net),kind,"d","i_max"))==1
                    delete!(c,"i_max")
                end
                before=deepcopy(net); _idx_findings(net;spec=true); @test net==before
            end
        end
    end

    @testset "load coefficients retain scalar and length-one broadcasts" begin
        for neutral in ("n","4","return"), topology in ("SINGLE_PHASE","WYE","DELTA"), model in ("zip","exponential","constant_current")
            net=_idx_net(neutral)
            tm=topology=="SINGLE_PHASE" ? ["a","b"] : topology=="WYE" ? ["a","b","c",neutral] : ["a","b","c"]
            c=_idx_device!(net,"load",topology,tm); n=topology=="SINGLE_PHASE" ? 1 : 3
            c["p_nom"]=fill(100.,n); c["q_nom"]=zeros(n); c["model"]=model
            fields=model=="zip" ? ("v_nom","alpha_z","alpha_i","alpha_p","beta_z","beta_i","beta_p") :
                model=="exponential" ? ("v_nom","gamma_p","gamma_q") : ("v_nom",)
            for field in fields
                code=field=="v_nom" ? "E.LOAD.VNOM_ARITY" : model=="zip" ? "E.LOAD.ZIP_ARITY" : "E.LOAD.EXP_ARITY"
                for v in (230.,[230.],fill(230.,n))
                    c[field]=v; f=Finding[]
                    @test BMOPFTools._check_load_index_fields!(net,"d",c,f)
                    @test isempty(f)
                end
                for v in (Float64[],fill(1.,n+1),"bad",[[1.]])
                    c[field]=v; f=Finding[]
                    @test !BMOPFTools._check_load_index_fields!(net,"d",c,f)
                    x=only(filter(x -> x.code==code && x.detail["field"]==field,f))
                    @test x.detail["expected_lengths"]==sort(unique([1,n]))
                end
                delete!(c,field)
            end
            c["v_nom"]=[230.]; c[model=="zip" ? "alpha_p" : "gamma_p"]=[1.,2.]
            if model!="constant_current"
                f=Finding[]; domain_rules_check(net,f)
                code=model=="zip" ? "E.LOAD.ZIP_ARITY" : "E.LOAD.EXP_ARITY"
                @test count(x -> x.code==code,f)==1 # no duplicate legacy arity finding
            end
        end
    end

    @testset "source references, phase bounds and all unordered bus pairs" begin
        for neutral in ("n","4","return")
            net=_idx_net(neutral); s=net["voltage_source"]["s"]; b=net["bus"]["b"]
            push!(s["terminal_map"],neutral)
            @test isempty(_idx_dim(_idx_findings(net),"voltage_source","s","v_magnitude"))
            for field in ("v_magnitude","v_angle")
                old=deepcopy(s[field]); s[field]=old[1:2]
                @test length(_idx_dim(_idx_findings(net),"voltage_source","s",field))==1
                s[field]=old
            end
            s["v_angle"]=vcat(s["v_angle"],0.)
            @test length(_idx_dim(_idx_findings(net),"voltage_source","s","v_angle"))==1
            push!(s["v_magnitude"],0.)
            @test !any(x -> x.code=="W.INT.DIM_MISMATCH",_idx_findings(net))
            for field in ("cost","p_min","p_max","q_min","q_max")
                s[field]=ones(3); @test isempty(_idx_dim(_idx_findings(net),"voltage_source","s",field))
                s[field]=ones(4); @test length(_idx_dim(_idx_findings(net),"voltage_source","s",field))==1
                delete!(s,field)
            end
            for n in 1:3
                b["terminal_names"]=vcat(["a","b","c"][1:n],neutral)
                for field in ("v_min","v_max","vpn_min","vpn_max","vpp_min","vpp_max")
                    count=startswith(field,"vpp") ? n*(n-1)÷2 : n
                    b[field]=fill(230.,count)
                    @test isempty(_idx_dim(_idx_findings(net),"bus","b",field))
                    for bad in (230.,fill(230.,count+1),["bad"])
                        b[field]=bad; @test length(_idx_dim(_idx_findings(net),"bus","b",field))==1
                    end
                    delete!(b,field)
                end
            end
        end
    end

    @testset "boundary arities and explicit role authority" begin
        for kind in ("load","generator","ibr"), count in (1,2)
            net=_idx_net(); tm=vcat(["a","b"][1:count],"n")
            c=_idx_device!(net,kind,kind=="ibr" ? "FOUR_LEG" : "WYE",tm)
            if kind=="load"
                c["p_nom"]=ones(count);c["q_nom"]=zeros(count)
            else
                c["p_max"]=ones(count);c["i_max"]=ones(count+1)
            end
            f=_idx_findings(net;spec=true)
            @test !any(x -> x.code=="W.INT.DIM_MISMATCH",f)
            @test any(x -> x.code in ("W.SPEC.CONFIG_ARITY","W.SPEC.INV_TMAP_ARITY"),f)
        end
        for kind in ("load","generator")
            net=_idx_net(); c=_idx_device!(net,kind,"DELTA",["a","b"])
            n=kind=="load" ? 1 : 2
            for field in (kind=="load" ? ("p_nom","q_nom") : ("p_max","i_max"))
                c[field]=ones(n)
            end
            @test !any(x -> x.code=="W.INT.DIM_MISMATCH",_idx_findings(net))
        end
        net=_idx_net(); c=_idx_device!(net,"ibr","FOUR_LEG",["a","b","c","n"])
        c["p_avail"]=100.; @test isempty(_idx_dim(_idx_findings(net),"ibr","d","p_avail"))
        c["p_avail"]=[100.]; @test length(_idx_dim(_idx_findings(net),"ibr","d","p_avail"))==1
        delete!(c,"p_avail")
        for declaration in (:unclassified,:multiple)
            n=deepcopy(net)
            if declaration==:unclassified
                pop!(n["terminal_conventions"]["phase"])
            else
                push!(n["terminal_conventions"]["neutral"],"second")
                push!(n["bus"]["b"]["terminal_names"],"second")
            end
            @test any(x -> x.code=="W.INT.DEVICE_INDEXING_UNASSESSED" && x.component_id=="d",_idx_findings(n))
        end
        net=_idx_net("return"); net["bus"]["b"]["neutral_terminal"]="a"
        c=_idx_device!(net,"generator","WYE",["a","b","c","return"]); c["p_max"]=ones(3)
        @test isempty(_idx_dim(_idx_findings(net),"generator","d","p_max"))
        net=_idx_net(); pop!(net["bus"]["b"]["terminal_names"])
        net["bus"]["b"]["vpn_max"]=fill(250.,3)
        @test any(x -> x.code=="W.INT.DEVICE_INDEXING_UNASSESSED" && x.detail["reason"]=="vpn_reference_missing",_idx_findings(net))
        net=_idx_net(); net["voltage_source"]["s"]["configuration"]="DELTA"
        @test any(x -> x.code=="W.SPEC.BAD_CONFIG" && x.component_type==:voltage_source,_idx_findings(net;spec=true))
    end

    @testset "unsupported roles are diagnosed, ambiguous roles are not guessed" begin
        for neutral in ("n","4","return")
            net=_idx_net(neutral); c=_idx_device!(net,"ibr","THREE_LEG",["a","b",neutral])
            f=_idx_findings(net;spec=true)
            @test any(x -> x.code=="E.TMAP.PHASE_TO_NEUTRAL" && x.component_id=="d",f)
            c["topology"]="FOUR_LEG"; c["terminal_map"]=["a","b","c"]
            @test any(x -> x.code=="E.TMAP.DEVICE_ROLES",_idx_findings(net;spec=true))
            c["terminal_map"]=["a","b","c",neutral]; c["q_max"]=[1.,2.]
            push!(net["terminal_conventions"]["phase"],neutral)
            f=_idx_findings(net;spec=true)
            @test isempty(_idx_dim(f,"ibr","d","q_max"))
            @test only(filter(x -> x.code=="W.INT.DEVICE_INDEXING_UNASSESSED" && x.component_id=="d",f)).detail["status"]=="indeterminate"
            domain=Finding[]; domain_rules_check(net,domain)
            @test count(x -> x.code=="E.CONV.ROLE_OVERLAP",domain)==1
        end
        net=_idx_net(); push!(net["bus"]["b"]["terminal_names"],"pe")
        net["terminal_conventions"]["earth"]=["pe"]
        _idx_device!(net,"load","SINGLE_PHASE",["a","pe"])
        @test any(x -> x.code=="E.TMAP.DEVICE_ROLES",_idx_findings(net;spec=true))
        net=_idx_net(); delete!(net,"terminal_conventions")
        f=Finding[]; domain_rules_check(net,f)
        @test any(x -> x.code=="W.CONV.TERMINAL_ROLES_INFERRED",f)
        for kind in ("load","generator","ibr","voltage_source"), bad in (nothing,"ab",7,Dict("a"=>1),["a",7])
            net=_idx_net(); c=_idx_device!(net,kind,"SINGLE_PHASE",["a","n"]); c["terminal_map"]=bad
            f=_idx_findings(net;spec=true)
            @test any(x -> x.code=="W.INT.DEVICE_INDEXING_UNASSESSED" && x.component_id=="d",f)
        end
    end
end
