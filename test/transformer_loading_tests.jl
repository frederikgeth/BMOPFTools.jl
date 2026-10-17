using Test, BMOPFTools, JSON3

function coil413_fixture()
    data = JSON3.read(read(joinpath(@__DIR__,"data","transformer_loading","overloaded_coil.json"),String),Dict{String,Any})
    data["net"],data["result"]
end

@testset "Supplied transformer coil loading (#413)" begin
    @testset "integral JSON phasors preserve load verification" begin
        d=JSON3.read(read(joinpath(@__DIR__,"data","transformer_loading","integer_voltage_candidate.json"),String),Dict{String,Any})
        before=deepcopy(d)
        report=profile_solution(d["net"],d["result"])
        @test !any(f->f.code=="W.SOL.LOAD_MODEL_RESIDUAL",report.findings)
        floating=deepcopy(d["result"])
        for row in values(floating["bus"]["b"]),field in ("vr","vi","vm")
            row[field]=Float64(row[field])
        end
        reference=profile_solution(d["net"],floating)
        @test [(f.code,f.detail) for f in report.findings]==[(f.code,f.detail) for f in reference.findings]
        @test d==before
    end
    @testset "light bank, overloaded coil, unchanged Findings and serialization" begin
        net,result = coil413_fixture()
        before = deepcopy((net,result))
        findings = Finding[]
        solution_check(net,result,findings)
        report = profile_solution(net,result)
        @test [(f.code,f.detail) for f in report.findings] == [(f.code,f.detail) for f in findings]
        loading = report.results[:transformer_loading]
        group = only(loading["groups"])
        @test group["s_sum_VA"] == 40000
        @test group["utilization"] ≈ 0.4
        @test group["max_coil_utilization"] ≈ 1.2
        @test loading["coils"][1]["headroom_VA"] ≈ -20000/3
        @test loading["coils"][1]["comparison_status"] == "violation"
        @test loading["coils"][1]["finding_codes"] == ["E.SOL.THERMAL_VIOLATION"]
        @test loading["coils"][1]["terminals"] == ["a","n"]
        @test loading["coils"][2]["s_VA"] == 0
        @test !loading["independently_reconstructed"]
        @test !loading["case_result_provenance_authenticated"]
        @test (net,result) == before
        io=IOBuffer(); render_solution(report,io); md=String(take!(io))
        @test occursin("Transformer Coil Loading",md)
        @test occursin("40000.0",md) && occursin("-6666.667",md)
        @test occursin("W.OPS.XFMR_OVERLOADED",md)
        envelope = execute_solution_verification(net,result)
        restored = JSON3.read(JSON3.write(envelope),Dict{String,Any})
        @test restored["result"]["results"]["transformer_loading"] == loading
        nr,rr=JSON3.read(JSON3.write(net),Dict{String,Any}),JSON3.read(JSON3.write(result),Dict{String,Any})
        @test profile_solution(nr,rr).results[:transformer_loading] == loading
    end

    @testset "boundaries, finite zero caps, missing and invalid evidence" begin
        for (s,expected) in ((30000.,"within_reported_cap"),(100000/3,"active"),(40000.,"violation"))
            net,r=coil413_fixture(); r["transformer"]["tx"]["fr"]["1"]["s"]=s
            row=profile_solution(net,r).results[:transformer_loading]["coils"][1]
            @test row["comparison_status"] == expected
            @test row["headroom_VA"] ≈ 100000/3-s
        end
        for field in ("s","s_max"), v in (nothing,NaN,Inf,-1.0,true)
            net,r=coil413_fixture(); wr=r["transformer"]["tx"]["fr"]["1"]
            v===nothing ? delete!(wr,field) : (wr[field]=v)
            # The new report safely labels invalid data; existing check behavior
            # remains owned by solution_check (which expects numeric fields).
            fs=Finding[]; sol=Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED","solver_claimed_feasible"=>true)
            loading=BMOPFTools._transformer_loading_summary(net,r,sol,fs)
            @test loading["coils"][1]["comparison_status"] == "unassessed"
            @test !isempty(loading["coils"][1]["missing_or_invalid_fields"])
            @test only(loading["groups"])["s_sum_VA"] === nothing
            @test !only(loading["groups"])["complete"]
        end
        for where in ("coil","side","transformer")
            net,r=coil413_fixture()
            where == "coil" ? delete!(r["transformer"]["tx"]["fr"],"2") :
                where == "side" ? delete!(r["transformer"]["tx"],"fr") : delete!(r["transformer"],"tx")
            loading=profile_solution(net,r).results[:transformer_loading]
            @test length(loading["coils"]) == 3
            @test !only(loading["groups"])["complete"]
            @test only(loading["groups"])["utilization"] === nothing
            @test loading["coils"][2]["s_VA"] === nothing
        end
        for s in (0.,10.)
            net,r=coil413_fixture(); r["transformer"]["tx"]["fr"]["1"] = Dict("s"=>s,"s_max"=>0.)
            row=profile_solution(net,r).results[:transformer_loading]["coils"][1]
            @test row["headroom_VA"] == -s
            @test row["utilization"] === nothing # never Inf or a fabricated zero ratio
            @test row["comparison_status"] == (s==0 ? "active" : "violation")
        end
    end

    @testset "candidate states never turn failed values into a solution" begin
        for (status,primal,count,expected) in (
            ("LOCALLY_INFEASIBLE","INFEASIBLE_POINT",1,"diagnostic_candidate"),
            ("LOCALLY_INFEASIBLE","FEASIBLE_POINT",1,"diagnostic_candidate"),
            ("TIME_LIMIT","INFEASIBLE_POINT",1,"diagnostic_candidate"),
            ("TIME_LIMIT","FEASIBLE_POINT",1,"supplied_feasible_candidate"),
            ("INFEASIBLE","NO_SOLUTION",0,"no_candidate"),
            ("LOCALLY_SOLVED","FEASIBLE_POINT",0,"no_candidate"),
            ("NUMERICAL_ERROR",nothing,0,"no_candidate"))
            net,r=coil413_fixture(); r["termination_status"]=status; r["result_count"]=count
            primal===nothing ? delete!(r,"primal_status") : (r["primal_status"]=primal)
            report=profile_solution(net,r); loading=report.results[:transformer_loading]
            @test loading["candidate_status"]==expected
            @test loading["termination_status"]==status
            @test loading["coils"][1]["s_VA"]==40000 # retain supplied diagnostic values
            @test loading["coils"][1]["comparison_status"] == (expected=="supplied_feasible_candidate" ? "violation" : "unassessed")
            io=IOBuffer();render_solution(report,io)
            @test occursin(expected,String(take!(io)))
        end
    end

    @testset "subtype constrained-side coverage and explicit unknowns" begin
        for (subtype,side,indices) in (("single_phase","fr",[1,2,3]),
            ("wye_delta","fr",[1,2,3]),("delta_wye","to",[1,2,3]),
            ("center_tap","fr",[1]),("single_phase_autotransformer","fr",[1]),
            ("open_delta_regulator","fr",[1,2]))
            net,_=coil413_fixture(); xf=net["transformer"]["single_phase"]["tx"]
            if subtype=="center_tap"
                xf["terminal_map_from"]=["a","n"]; xf["terminal_map_to"]=["a","n","b"]
            elseif subtype=="single_phase_autotransformer"
                xf["terminal_map_from"]=["a","b"];xf["terminal_map_to"]=["a","b"]
            elseif subtype=="open_delta_regulator"
                xf["connection"]="ABBC"
            end
            net["transformer"]=Dict(subtype=>Dict("tx"=>xf))
            r=Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED","transformer"=>Dict("tx"=>Dict(side=>Dict(string(i)=>Dict("s"=>1000i,"s_max"=>10000i) for i in indices))))
            loading=profile_solution(net,r).results[:transformer_loading]
            @test [c["coil"] for c in loading["coils"]] == string.(indices)
            @test all(c -> c["side"]==side,loading["coils"])
            @test only(loading["groups"])["cap_sum_VA"] == sum(10000 .* indices)
            @test isempty(loading["unassessed"])
        end
        net,_=coil413_fixture()
        net["transformer"]=Dict("n_winding"=>Dict("tx"=>Dict("windings"=>[
            Dict("bus"=>"f","terminal_map"=>["a","b","c","n"],"configuration"=>"WYE"),
            Dict("bus"=>"t","terminal_map"=>["a","b","c"],"configuration"=>"DELTA","delta_roll"=>-1)])))
        r=Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED","transformer"=>Dict("tx"=>Dict("w$j"=>Dict(string(k)=>Dict("s"=>1000.,"s_max"=>10000j) for k in 1:3) for j in 1:2)))
        # Isolate report layout from unrelated n-winding operational validators.
        sol=Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED","solver_claimed_feasible"=>true)
        loading=BMOPFTools._transformer_loading_summary(net,r,sol,Finding[])
        @test length(loading["coils"]) == 6
        @test length(loading["groups"]) == 2
        @test [g["cap_sum_VA"] for g in loading["groups"]]==[30000,60000]
        @test loading["coils"][4]["terminals"]==["a","c"]
        net=JSON3.read(JSON3.write(net),Dict{String,Any})
        ws=net["transformer"]["n_winding"]["tx"]["windings"]
        net["transformer"]["n_winding"]["tx"]["windings"]=Any[42,ws[2]]
        loading=BMOPFTools._transformer_loading_summary(net,r,sol,Finding[])
        @test isempty(loading["coils"])
        @test any(u->u["reason"]=="invalid_winding_list",loading["unassessed"])
        net,r=coil413_fixture();net["transformer"]=Dict("future_kind"=>net["transformer"]["single_phase"])
        loading=BMOPFTools._transformer_loading_summary(net,r,sol,Finding[])
        @test isempty(loading["coils"])
        @test any(u->u["reason"]=="unsupported_transformer_subtype",loading["unassessed"])
        net,r=coil413_fixture();r["transformer"]["tx"]["to"]=Dict("1"=>Dict("s"=>40000.,"s_max"=>100000/3))
        r["transformer"]["unknown"]=Dict()
        loading=profile_solution(net,r).results[:transformer_loading]
        @test length(loading["groups"])==1 # never double count from and to
        @test Set(u["reason"] for u in loading["unassessed"])==Set(["unrecognized_result_slot","transformer_absent_from_case"])
    end
end
