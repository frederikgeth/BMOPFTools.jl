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

        # The exemption needs the perfect grounding, not just the label: an
        # ungrounded n_ref beside n is two conductor neutrals.
        loose=deepcopy(implicit); delete!(loose["bus"]["lv"],"perfectly_grounded_terminals")
        @test BMOPFTools._conductor_neutrals(loose["bus"]["lv"],Set(["n","n_ref"]))==["n","n_ref"]
        found=Finding[]; BMOPFTools._check_terminal_conventions(loose,found,Ref(0))
        @test any(f -> f.code=="W.CONV.MULTIPLE_NEUTRALS" && f.component_id=="lv",found)
        found=Finding[]; BMOPFTools._check_terminal_conventions(implicit,found,Ref(0))
        @test !any(f -> f.code=="W.CONV.MULTIPLE_NEUTRALS",found)
        @test BMOPFTools._index_bus_neutral(implicit,"lv")=="n"
        @test BMOPFTools._index_bus_neutral(loose,"lv")===nothing

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
        # A 4-wire trunk with a 2-wire service reports both conductor counts.
        service=deepcopy(explicit)
        service["bus"]["house"]=Dict{String,Any}("terminal_names"=>["a","n"])
        service["line"]["svc"]=merge(deepcopy(service["line"]["l"]),Dict{String,Any}(
            "bus_from"=>"customer","bus_to"=>"house",
            "terminal_map_from"=>["a","n"],"terminal_map_to"=>["a","n"]))
        @test BMOPFTools._branch_wire_description(service,["lv","customer","house"])==
            "mixed (2/4 conductors)"
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
        @test_throws ArgumentError BMOPFTools._remap_opendss_terminals!(bad;
            grounded_references=Dict("b"=>["4","5"]))

        # leadlag is checked, never repaired: lag/ansi (the OpenDSS default)
        # match the converted Dy1 clock; lead/euro are a known 60° mismatch;
        # unrecognized values stay indeterminate. All three classes stay serializable.
        for (leadlag,status,blocking,note) in (
                ("lag","verified",false,"source leadlag=lag verified"),
                ("ansi","verified",false,"source leadlag=ansi verified"),
                ("euro","known_mismatch",true,"SOURCE MISMATCH: leadlag=euro implies clock 11, converted clock 1"),
                ("lead","known_mismatch",true,"SOURCE MISMATCH: leadlag=lead implies clock 11, converted clock 1"),
                ("unsupported_value","indeterminate",true,"source leadlag=unsupported_value unverified"))
            net,_=load_variant(leadlag=leadlag)
            mapping=net["_meta"]["powerio_source_mapping"]
            @test ("leadlag" in mapping["blocking_unmapped_fields"]) == blocking
            @test (mapping["by_field"]["leadlag"]["unmapped_scopes"]==["transformer:t"]) == blocking
            blocking || @test mapping["by_field"]["leadlag"]["status"]=="mapped_with_verification"
            ev=transformer_phase_relation(net,"delta_wye",net["transformer"]["delta_wye"]["t"])
            @test ev["status"]=="known" && ev["clock"]==1 # the represented target relation
            @test ev["source_preservation"]["status"]==status
            @test ev["source_preservation"]["leadlag"]==leadlag
            @test ev["source_preservation"]["source_clock"]==(status=="indeterminate" ? nothing :
                status=="verified" ? 1 : 11)
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
            @test occursin(note,text)
            @test occursin("phase-to-reference",text)
            @test occursin("diagnostic record(s)",text)
            @test !occursin("fidelity loss(es)",text)
            @test occursin("perfect (0 Ω)",text)
            terminal=IOBuffer();render(report,terminal;color=false)
            @test occursin(note,String(take!(terminal)))
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
                # Observed agreement is ~2e-8; swapping the star slot with a
                # phase gives ~0.94, so 1e-6 separates placement errors cleanly.
                @test norm(Y-y[rows,rows])/norm(y[rows,rows])<1e-6
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
            # Source-clock table used by from_dss, measured against OpenDSS for
            # both mixed connection orders and every recognized leadlag value.
            for (c1,c2) in (("delta","wye"),("wye","delta")), ll in ("lag","ansi","lead","euro")
                deck="""
                Clear
                Set DefaultBaseFrequency=50
                New Circuit.c basekv=11 pu=1 angle=0 frequency=50 bus1=mv model=ideal
                New Transformer.t phases=3 windings=2 leadlag=$ll xhl=4
                ~ wdg=1 bus=mv conn=$c1 kv=11 kva=100 %r=0.5
                ~ wdg=2 bus=lv conn=$c2 kv=0.433 kva=100 %r=0.5
                New Load.x bus1=lv.1.2.3 phases=3 kv=0.433 kw=0.001 conn=delta
                Solve
                """
                p=joinpath(dir,"clock.dss"); write(p,deck)
                D.dss("Clear");D.dss("Redirect \"$p\"")
                seq(b)=(D.Circuit.SetActiveBus(b); v=D.Bus.Voltages(); a=cis(2π/3); v[1]+a*v[2]+a^2*v[3])
                native_clock=mod(round(Int,-rad2deg(angle(seq("lv")/seq("mv")))/30),12)
                rec=only(from_dss(p)["_meta"]["powerio_source_semantics"]["transformer_phase_relations"])
                @test rec["source_clock"]==native_clock
                @test rec["status"]==(ll in ("lag","ansi") ? "verified" : "known_mismatch")
            end
        else
            @test_skip "OpenDSS primitive, neutral-voltage and leadlag oracles require OpenDSSDirect"
        end
    end
end
