using Test, BMOPFTools, PowerIO, JSON3, LinearAlgebra

@testset "OpenDSS reference preservation and qualified reporting" begin
    source=read(joinpath(@__DIR__,"data","opendss_semantics","Master.dss"),String)
    mktempdir() do dir
        function load_variant(;star="lv",leadlag="lag")
            path=joinpath(dir,"case.dss")
            write(path,replace(source,"bus=lv conn=wye"=>"bus=$star conn=wye",
                "leadlag=lag"=>"leadlag=$leadlag"))
            from_dss(path),path
        end
        implicit,path=load_variant()
        explicit,_=load_variant(star="lv.1.2.3.4")
        xf=implicit["transformer"]["delta_wye"]["t"]
        @test xf["terminal_map_to"]==["a","b","c","n_ref"]
        @test explicit["transformer"]["delta_wye"]["t"]["terminal_map_to"]==["a","b","c","n"]
        @test implicit["bus"]["lv"]["perfectly_grounded_terminals"]==["n_ref"]
        @test implicit["bus"]["lv"]["neutral_terminal"]=="n"
        @test implicit["bus"]["mv"]["terminal_names"]==["a","b","c","n_ref"]
        @test implicit["shunt"]["gs"]["terminal_map"]==["n"]
        @test implicit["shunt"]["gs"]["G_1_1"]≈1/0.3
        @test Set(implicit["terminal_conventions"]["neutral"])==Set(["n","n_ref"])
        index=ybus_passive(implicit).index
        @test index[("lv","n_ref")]==0
        @test index[("lv","n")]>0
        @test !haskey(explicit["bus"]["lv"],"perfectly_grounded_terminals") ||
              isempty(explicit["bus"]["lv"]["perfectly_grounded_terminals"])
        fs=Finding[];spec_conformance_check(implicit,fs);integrity_check(implicit,fs)
        @test !any(f -> f.code in ("E.TMAP.WINDING_ROLES","W.TMAP.CONNECTION_UNASSESSED",
            "W.INT.DEVICE_INDEXING_UNASSESSED","E.INT.UNKNOWN_TERMINAL"),fs)
        # Ground-connected devices must not be relabeled as phase-to-phase
        # or forced onto the separate conductor neutral at the same bus.
        for (cfg,tm,powers) in (("SINGLE_PHASE",["a","n_ref"],[1.0]),
                              ("WYE",["a","b","c","n_ref"],ones(3)))
            n=deepcopy(implicit)
            n["load"]["reference_load"]=Dict{String,Any}("bus"=>"lv",
                "terminal_map"=>tm,"configuration"=>cfg,"p_nom"=>powers,
                "q_nom"=>zeros(length(powers)),"v_nom"=>fill(250.0,length(powers)))
            found=Finding[];spec_conformance_check(n,found)
            @test !any(f -> f.component_id=="reference_load" && f.code in
                ("E.SPEC.WYE_MISSING_NEUTRAL","I.SPEC.LOAD_PHASE_TO_PHASE"),found)
        end

        ri=analyze(implicit); re=analyze(explicit)
        zi=only(z for z in ri.results[:provenance]["earthing_zones"] if "lv" in z["buses"])
        ze=only(z for z in re.results[:provenance]["earthing_zones"] if "lv" in z["buses"])
        mv=only(z for z in ri.results[:provenance]["earthing_zones"] if "mv" in z["buses"])
        @test zi["star_earthing"]=="perfect" && zi["star_R_ohm"]==0.0
        @test ze["star_earthing"]=="impedance" && ze["star_R_ohm"]≈0.3
        @test zi["n_downstream_earths"]==ze["n_downstream_earths"]==1
        @test zi["wires"]=="4-wire"
        # Four map positions alone do not identify a neutral.
        phase_only=deepcopy(explicit)
        phase_only["terminal_conventions"]["neutral"]=String[]
        @test BMOPFTools._branch_wire_description(phase_only,["lv","customer"])==
            "4 conductors; neutral unassessed"
        @test mv["n_buses_with_neutral_conductor"]==0
        @test mv["wires"]=="no branch conductors represented"
        @test zi["protective_system_status"]=="indeterminate"
        @test !occursin("TN-C-S",zi["tag"])
        @test only(filter(e->e["bus"]=="lv",zi["neutral_earths"]))["impedance_ohm"]≈0.3

        # Small, threshold, and high finite values stay finite; no threshold
        # silently substitutes a zero constraint or an isolated-system claim.
        for r in (1e-6,0.3,1.0,200.0,201.0)
            n=deepcopy(explicit);n["shunt"]["gs"]["G_1_1"]=1/r
            z=only(z for z in provenance_analysis(n,Finding[])["earthing_zones"] if "lv" in z["buses"])
            @test z["star_earthing"]=="impedance"
            @test z["star_R_ohm"]≈r
        end
        missing=deepcopy(explicit);delete!(missing["shunt"],"gs")
        z=only(z for z in provenance_analysis(missing,Finding[])["earthing_zones"] if "lv" in z["buses"])
        @test z["star_earthing"]=="none" && z["protective_system_status"]=="indeterminate"
        parallel=deepcopy(explicit)
        parallel["shunt"]["gs2"]=deepcopy(parallel["shunt"]["gs"])
        z=only(z for z in provenance_analysis(parallel,Finding[])["earthing_zones"] if "lv" in z["buses"])
        @test z["star_R_ohm"]≈0.15
        coupled=deepcopy(explicit)
        coupled["shunt"]["gs"]["terminal_map"]=["n","a"]
        z=only(z for z in provenance_analysis(coupled,Finding[])["earthing_zones"] if "lv" in z["buses"])
        @test z["star_earthing"]=="indeterminate"
        @test !isempty(z["unassessed_earthing_terminals"])
        # Reject unresolved multiple reference identities instead of merging them.
        bad=Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}(
            "terminal_names"=>["1","2","3","4","5"],
            "perfectly_grounded_terminals"=>["4","5"])))
        @test_throws ArgumentError BMOPFTools._remap_opendss_terminals!(bad)

        # The upstream export gap remains explicit, including unknown values.
        for leadlag in ("euro","lag","unsupported_value")
            net,_=load_variant(leadlag=leadlag)
            mapping=net["_meta"]["powerio_source_mapping"]
            @test "leadlag" in mapping["blocking_unmapped_fields"]
            @test mapping["by_field"]["leadlag"]["unmapped_scopes"]==["transformer:t"]
            ev=transformer_phase_relation(net,"delta_wye",net["transformer"]["delta_wye"]["t"])
            @test ev["status"]=="known" # the represented target relation
            @test ev["source_preservation"]["status"]=="indeterminate"
            @test ev["source_preservation"]["leadlag"]==leadlag
            @test any(f->f.code=="EMIT.BMOPF.TRANSFORMER_EXTRA_DROPPED",powerio_findings(net))
            io=IOBuffer();write_bmopf(net,io)
            restored=parse_bmopf(String(take!(io));from_string=true)
            @test restored["bus"]["lv"]["neutral_terminal"]=="n"
            @test restored["bus"]["lv"]["perfectly_grounded_terminals"]==["n_ref"]
            @test restored["_meta"]["powerio_source_mapping"]==mapping
            @test transformer_phase_relation(restored,"delta_wye",restored["transformer"]["delta_wye"]["t"])==ev
            @test ybus_passive(restored).index[("lv","n")]>0
            report=analyze(restored)
            md=IOBuffer();BMOPFTools.render_markdown(report,md);text=String(take!(md))
            @test occursin("source leadlag=$leadlag unverified",text)
            @test occursin("phase-to-reference",text)
            @test occursin("diagnostic record(s)",text)
            @test !occursin("fidelity loss(es)",text)
            @test occursin("perfect (0 Ω)",text)
            terminal=IOBuffer();render(report,terminal;color=false)
            @test occursin("source leadlag=$leadlag unverified",String(take!(terminal)))
            json=IOBuffer();BMOPFTools.render_json(report,json)
            data=JSON3.read(String(take!(json)),Dict{String,Any})
            @test data["results"]["voltage_levels"]["voltage_basis"]=="phase_to_reference"
        end

        # Native OpenDSS primitive oracle: preserve the actual grounded star
        # terminal, not just report labels or voltage magnitudes.
        if isdefined(@__MODULE__,:OpenDSSDirect)
            D=OpenDSSDirect
            for (net,star) in ((implicit,"lv"),(explicit,"lv.1.2.3.4"))
                _,casepath=load_variant(;star)
                D.dss("Clear");D.dss("Redirect \"$casepath\"")
                D.Circuit.SetActiveElement("Transformer.t")
                ns=D.CktElement.NodeOrder(); y=reshape(D.CktElement.YPrim(),8,8)
                nodes,Y=transformer_yprim(net["transformer"]["delta_wye"]["t"],"delta_wye")
                label=Dict(0=>"n_ref",1=>"a",2=>"b",3=>"c",4=>"n")
                native=[(k<=4 ? "mv" : "lv",label[ns[k]]) for k in 1:8]
                rows=[findfirst(==(node),native) for node in nodes]
                @test all(!isnothing,rows)
                @test norm(Y-y[rows,rows])/norm(y[rows,rows])<1e-2
                if isdefined(@__MODULE__,:Ipopt) && isdefined(@__MODULE__,:JuMP)
                    @test D.Solution.Converged()
                    D.Circuit.SetActiveBus("lv")
                    native_neutral=D.Bus.Voltages()[findfirst(==(4),D.Bus.Nodes())]
                    for pu in (false,true)
                        result=solve_pf(net;optimizer=Ipopt.Optimizer,per_unit=pu)
                        @test result["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                        b=result["bus"]["lv"]["n"]
                        @test complex(b["vr"],b["vi"])≈native_neutral atol=2e-3
                    end
                end
            end
        end
    end
end
