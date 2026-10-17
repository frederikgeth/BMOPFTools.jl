using Test, BMOPFTools, JSON3

function _cm_net(neutral="n"; phases=["a","b","c"])
    Dict{String,Any}("terminal_conventions"=>Dict("phase"=>phases,"neutral"=>[neutral],"earth"=>String[]),
        "bus"=>Dict(b=>Dict{String,Any}("terminal_names"=>vcat(phases,[neutral]),
            "perfectly_grounded_terminals"=>[neutral]) for b in ("f","t","u")))
end
function _cm_branch!(net,kind,fr,to)
    c=Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>fr,"terminal_map_to"=>to)
    if kind=="line"
        for i in eachindex(fr), j in eachindex(fr)
            c["R_series_$(i)_$j"]=i==j ? 1.0 : 0.0
            c["X_series_$(i)_$j"]=i==j ? 0.5 : 0.0
        end
    end
    net[kind]=Dict{String,Any}("x"=>c); c
end
function _cm_xf!(net,subtype,fr,to)
    c=Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>fr,"terminal_map_to"=>to)
    net["transformer"]=Dict(subtype=>Dict("x"=>c)); c
end
function _cm_nw!(net,maps,configs)
    c=Dict{String,Any}("windings"=>Any[Dict{String,Any}("bus"=>b,"terminal_map"=>tm,
        "configuration"=>cfg,"v_nom"=>1.0) for (b,tm,cfg) in zip(("f","t","u"),maps,configs)])
    net["transformer"]=Dict("n_winding"=>Dict("x"=>c)); c
end
function _cm_findings(net)
    out=Finding[]; integrity_check(net,out); spec_conformance_check(net,out); out
end
_cm_code(fs,code)=[f for f in fs if f.code==code]
_cm_errors(fs)=[f for f in fs if f.severity==ERROR]

@testset "Connection map contracts (#409)" begin
    @testset "minimal mixed-role witness and unchanged information" begin
        net=JSON3.read(read(joinpath(@__DIR__,"data","connection_maps","role_swap.json"),String),Dict{String,Any})
        before=deepcopy(net); fs=_cm_findings(net)
        bad=_cm_code(fs,"E.TMAP.PHASE_TO_NEUTRAL")
        @test length(bad)==2
        @test [f.detail["position"] for f in bad]==[1,2]
        @test all(f.detail["rule"]=="same_conductor_role_at_position" for f in bad)
        @test length(_cm_code(fs,"I.TMAP.CROSS_PHASE_LINE"))==1
        @test net==before
        net["switch"]["s"]["terminal_map_to"]=["b","return"]
        @test isempty(_cm_errors(_cm_findings(net)))
        @test length(_cm_code(_cm_findings(net),"I.TMAP.CROSS_PHASE_LINE"))==1
    end

    @testset "positional continuity, subsets, neutral permutations and labels" begin
        perms=([1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1])
        for n in ("n","4","return"), phases in (["a","b","c"],["red","blue","gold"]), kind in ("line","switch")
            for perm in perms, slot in 1:4
                fr=copy(phases); insert!(fr,slot,n)
                to=phases[perm]; insert!(to,slot,n)
                net=_cm_net(n;phases); c=_cm_branch!(net,kind,fr,to)
                @test isempty(_cm_errors(_cm_findings(net)))
                for other in setdiff(1:4,[slot])
                    swapped=copy(to); swapped[slot],swapped[other]=swapped[other],swapped[slot]
                    c["terminal_map_to"]=swapped
                    fs=_cm_findings(net)
                    bad=_cm_code(fs,"E.TMAP.PHASE_TO_NEUTRAL")
                    @test sort([f.detail["position"] for f in bad])==sort([slot,other])
                    @test all(f.detail["endpoints"][1]["bus"]=="f" && f.detail["endpoints"][2]["bus"]=="t" for f in bad)
                end
            end
            for (fr,to) in (([phases[1]],[phases[2]]),([n],[n]),(phases[1:2],phases[2:3]))
                net=_cm_net(n;phases); _cm_branch!(net,kind,fr,to)
                @test isempty(_cm_errors(_cm_findings(net)))
            end
        end
    end

    @testset "strict dimensions, references and endpoint evidence" begin
        for kind in ("line","switch"), side in ("from","to")
            net=_cm_net(); c=_cm_branch!(net,kind,["a","n"],["b","n"])
            c["terminal_map_$side"]=["a"]
            code=kind=="line" ? "E.INT.LINE_DIM_MISMATCH" : "E.INT.SWITCH_DIM_MISMATCH"
            f=only(_cm_code(_cm_findings(net),code))
            @test length(f.detail["endpoints"])==2
            @test f.detail["endpoints"][side=="from" ? 1 : 2]["map_positions"]==[1]
            c["terminal_map_$side"]=["ghost","n"]
            f=only(_cm_code(_cm_findings(net),"E.INT.UNKNOWN_TERMINAL"))
            @test f.detail["side"]==side
            @test f.detail["invalid_positions"]==[1]
            c["bus_$side"]="ghostbus"
            fs=_cm_findings(net)
            @test length(_cm_code(fs,"E.INT.UNKNOWN_BUS"))==1
            @test isempty(_cm_code(fs,"E.INT.UNKNOWN_TERMINAL"))
        end
        # Referenced matrix path remains as strict as inline matrices.
        net=_cm_net(); c=_cm_branch!(net,"line",["a","n"],["b","n"])
        net["linecode"]=Dict("lc"=>Dict(k=>pop!(c,k) for k in collect(keys(c)) if startswith(k,"R_series_") || startswith(k,"X_series_")))
        c["linecode"]="lc"; c["terminal_map_to"]=["b"]
        @test length(_cm_code(_cm_findings(net),"E.INT.LINE_DIM_MISMATCH"))==1
    end

    @testset "transformer domains, without across-winding continuity" begin
        for n in ("n","4","return")
            layouts=(("single_phase",["a",n],["b","c"]),
                ("single_phase",[n,"b"],["c",n]),
                ("single_phase_autotransformer",["a","b"],["c","b"]),
                ("center_tap",["a",n],["b",n,"a"]),
                ("wye_delta",[n,"c","a","b"],["b","c","a"]),
                ("delta_wye",["c","b","a"],["b","a",n,"c"]),
                ("open_delta_regulator",["a","b","c",n],[n,"b","c","a"]))
            for (subtype,fr,to) in layouts
                net=_cm_net(n); c=_cm_xf!(net,subtype,fr,to)
                @test isempty(_cm_errors(_cm_findings(net)))
                # Every side has exactly one reference diagnostic, qualified by subtype.
                for side in ("from","to")
                    bad=deepcopy(net); x=bad["transformer"][subtype]["x"]
                    x["bus_$side"]="absent"
                    f=only(_cm_code(_cm_findings(bad),"E.INT.UNKNOWN_BUS"))
                    @test f.detail["side"]==side && f.detail["subtype"]==subtype
                    x["bus_$side"]=side=="from" ? "f" : "t"
                    x["terminal_map_$side"][1]="absent"
                    f=only(_cm_code(_cm_findings(bad),"E.INT.UNKNOWN_TERMINAL"))
                    @test f.detail["side"]==side
                end
            end
            net=_cm_net(n); c=_cm_xf!(net,"center_tap",["a",n],["a","b",n])
            f=only(_cm_code(_cm_findings(net),"E.TMAP.WINDING_ROLES"))
            @test f.detail["side"]=="to" && f.detail["rule"]=="center_tap_positional_polarity"
            net=_cm_net(n); _cm_xf!(net,"wye_delta",["a","b","c",n],["a","b",n])
            @test any(f.detail["rule"]=="delta_phase_only_coils" for f in _cm_code(_cm_findings(net),"E.TMAP.WINDING_ROLES"))
            net=_cm_net(n); _cm_xf!(net,"single_phase",["a",n],["a","b",n])
            @test any(f.detail["rule"]=="matching_coupled_coil_counts" for f in _cm_code(_cm_findings(net),"E.TMAP.WINDING_ROLES"))
            net=_cm_net(n); _cm_xf!(net,"single_phase_autotransformer",[n,"a"],["b","c"])
            f=only(_cm_code(_cm_findings(net),"E.TMAP.WINDING_ROLES"))
            @test f.detail["rule"]=="shared_regulator_reference_role"
            @test f.detail["reference_positions"]==[1,2]
            # The ungrounded secondary's map is valid: reference requirements are separate.
            net=_cm_net(n); _cm_xf!(net,"single_phase",["a",n],["b",n])
            net["bus"]["t"]["perfectly_grounded_terminals"]=String[]
            fs=_cm_findings(net)
            @test isempty(_cm_code(fs,"E.TMAP.WINDING_ROLES"))
            @test length(_cm_code(fs,"E.INT.NO_VOLTAGE_REFERENCE"))==1
        end
    end

    @testset "nested windings retain their indices, roles and coil counts" begin
        for n in ("n","4","return")
            net=_cm_net(n); c=_cm_nw!(net,[["a","b","c",n],["c","b","a"],[n,"b","a","c"]],["WYE","DELTA","WYE"])
            @test isempty(_cm_errors(_cm_findings(net)))
            for k in 1:3
                bad=deepcopy(net); w=bad["transformer"]["n_winding"]["x"]["windings"][k]
                w["bus"]="missing"
                f=only(_cm_code(_cm_findings(bad),"E.INT.UNKNOWN_BUS"))
                @test f.detail["winding"]==k
                w["bus"]=("f","t","u")[k]; w["terminal_map"][1]="missing"
                f=only(_cm_code(_cm_findings(bad),"E.INT.UNKNOWN_TERMINAL"))
                @test f.detail["winding"]==k && f.detail["invalid_positions"]==[1]
            end
            c["windings"][3]["terminal_map"]=["a",n]
            f=only(_cm_code(_cm_findings(net),"E.TMAP.WINDING_ROLES"))
            @test f.detail["coil_counts"]==[3,3,1]
            # A malformed earlier element must not renumber the next reference.
            c["windings"][1]=nothing; c["windings"][2]["bus"]="missing"
            fs=_cm_findings(net)
            @test only(_cm_code(fs,"E.INT.UNKNOWN_BUS")).detail["winding"]==2
            @test only(_cm_code(fs,"E.INT.CONNECTION_SHAPE")).detail["winding"]==1
        end
    end

    @testset "malformed shapes, unresolved roles and serialization" begin
        for kind in ("line","switch"), bad in (nothing,1,"a",["a",1],Any[],Dict("a"=>1))
            net=_cm_net(); c=_cm_branch!(net,kind,["a","n"],["a","n"])
            c["terminal_map_to"]=bad
            before=deepcopy(net); fs=_cm_findings(net)
            @test length(_cm_code(fs,"E.INT.CONNECTION_SHAPE"))==1
            @test net==before
        end
        for bad in (nothing,1,"bad",Dict("w"=>1),Any[],[nothing],[Dict("bus"=>"f","terminal_map"=>nothing)],
                    [Dict("bus"=>"f","terminal_map"=>["a","n"],"v_nom"=>"not numeric")])
            net=_cm_net(); c=_cm_nw!(net,[["a","n"],["a","n"]],["WYE","WYE"]); c["windings"]=bad
            before=deepcopy(net); fs=_cm_findings(net)
            @test net==before
            @test any(f.code in ("E.INT.CONNECTION_SHAPE","W.SPEC.XFMR_TMAP_ARITY") for f in fs)
        end
        for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
            net=_cm_net(); net["transformer"]=Dict(subtype=>Dict("x"=>nothing))
            @test length(_cm_code(_cm_findings(net),"E.INT.CONNECTION_SHAPE"))==1
            subtype=="n_winding" && continue
            for bad in (nothing,"bad",["a",1],Any[]), side in ("from","to")
                net=_cm_net(); c=_cm_xf!(net,subtype,["a","n"],["a","n"])
                c["terminal_map_$side"]=bad
                @test length(_cm_code(_cm_findings(net),"E.INT.CONNECTION_SHAPE"))==1
            end
        end
        for kind in ("line","switch"), bad in (nothing,1,["f"],Dict("bus"=>"f"))
            net=_cm_net(); c=_cm_branch!(net,kind,["a","n"],["a","n"])
            c["bus_to"]=bad
            @test length(_cm_code(_cm_findings(net),"E.INT.CONNECTION_SHAPE"))==1
        end
        for kind in ("line","switch")
            net=_cm_net(); net[kind]=Dict("bad"=>nothing)
            @test length(_cm_code(_cm_findings(net),"E.INT.CONNECTION_SHAPE"))==1
        end
        for mutation in (net -> push!(net["terminal_conventions"]["phase"],"n"),
                         net -> (net["terminal_conventions"]["phase"]=["b","c"]),
                         net -> (net["terminal_conventions"]["earth"]=["a"];net["terminal_conventions"]["phase"]=["b","c"]))
            net=_cm_net(); _cm_branch!(net,"switch",["a","n"],["a","n"]); mutation(net)
            fs=_cm_findings(net)
            @test length(_cm_code(fs,"W.TMAP.CONNECTION_UNASSESSED"))==2
            @test isempty(_cm_code(fs,"E.TMAP.PHASE_TO_NEUTRAL"))
        end
        net=_cm_net("return"); _cm_branch!(net,"line",["a","return"],["return","b"])
        net["shunt"]=Dict("ground"=>Dict("bus"=>"t","terminal_map"=>["return"],"G_1_1"=>0.1))
        before=deepcopy(net); fs=_cm_findings(net)
        @test !any(f.severity==ERROR && f.component_type==:shunt for f in fs)
        restored=JSON3.read(JSON3.write(net),Dict{String,Any})
        @test restored==before && net==before
        selected(fs)=[(f.code,f.component_type,f.component_id,f.detail) for f in fs if startswith(f.code,"E.TMAP") || startswith(f.code,"E.INT.CONNECTION")]
        @test selected(_cm_findings(restored))==selected(fs)==selected(_cm_findings(net))
        for f in _cm_code(fs,"E.TMAP.PHASE_TO_NEUTRAL")
            @test JSON3.read(JSON3.write(f.detail),Dict{String,Any})==f.detail
            for d in f.detail["endpoints"]
                @test all(haskey(d,k) for k in ("bus","side","subtype","winding","terminal_map","map_positions","resolved_roles","role_source","observed_shape"))
            end
        end
    end
end
