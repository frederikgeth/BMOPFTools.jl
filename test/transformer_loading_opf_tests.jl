using Test, BMOPFTools, JuMP, Ipopt, JSON3

# Fixture/shared report helper is loaded by transformer_loading_tests.jl first.
@testset "Transformer coil loading: independent electrical evidence (#413)" begin
    @testset "native subtype sides, coil-voltage oracle and coordinate parity" begin
        for kind in ("single_phase","center_tap","wye_delta","delta_wye")
            net=JSON3.read(read(joinpath(@__DIR__,"data","transformer_interoperability",kind*".json"),String),Dict{String,Any})
            baseline=nothing
            for (pu,sbase) in ((false,1e6),(true,1e5),(true,1e6))
                r=solve_pf(net;per_unit=pu,s_base=sbase,solver_options=(
                    "tol"=>1e-10,"constr_viol_tol"=>1e-10,
                    "bound_relax_factor"=>0.0,"acceptable_iter"=>0))
                @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                loading=profile_solution(net,r).results[:transformer_loading]
                side=kind=="delta_wye" ? "to" : "fr"
                suffix=side=="fr" ? "from" : "to"
                xf=net["transformer"][kind]["tx"]
                bus=xf["bus_"*suffix]; tm=xf["terminal_map_"*suffix]
                indices=kind in ("single_phase","center_tap") ? [1] : [1,2,3]
                @test length(loading["coils"])==length(indices)
                for (row,k) in zip(loading["coils"],indices)
                    # The retained fixtures use last-terminal neutral on the
                    # capped side. This oracle uses raw maps, not report slots.
                    v=r["bus"][bus][tm[k]]; vn=r["bus"][bus][tm[end]]
                    i=r["transformer"]["tx"][side][string(k)]
                    S=complex(v["vr"]-vn["vr"],v["vi"]-vn["vi"])*conj(complex(i["cr"],i["ci"]))
                    @test row["side"]==side && row["coil"]==string(k)
                    @test row["terminals"]==[tm[k],tm[end]]
                    @test row["s_VA"] ≈ abs(S) atol=2e-3 rtol=2e-6
                    @test row["cap_VA"] ≈ xf["s_rating"]/length(indices)
                end
                if baseline===nothing
                    baseline=loading
                else
                    for (a,b) in zip(baseline["coils"],loading["coils"])
                        @test a["s_VA"] ≈ b["s_VA"] atol=2e-3 rtol=2e-6
                        @test a["headroom_VA"] ≈ b["headroom_VA"] atol=2e-3 rtol=2e-6
                    end
                end
                restored=JSON3.read(JSON3.write(r),Dict{String,Any})
                @test profile_solution(net,restored).results[:transformer_loading]==loading
            end
        end
    end
    for pu in (false,true), power in (30000.,100000/3)
        net,_=coil413_fixture(); net["load"]["d"]["p_nom"]=[power]
        before=deepcopy(net)
        r=solve_pf(net;per_unit=pu,solver_options=("tol"=>1e-10,"constr_viol_tol"=>1e-10,"bound_relax_factor"=>0.0))
        @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        loading=profile_solution(net,r).results[:transformer_loading]
        for (k,t) in enumerate(["a","b","c"])
            vf=r["bus"]["f"][t]; vn=r["bus"]["f"]["n"]
            iw=r["transformer"]["tx"]["fr"][string(k)]
            U=complex(vf["vr"]-vn["vr"],vf["vi"]-vn["vi"])
            I=complex(iw["cr"],iw["ci"])
            # Ideal 1:1 independent load witness: no shunts or leakage. Source
            # current and load current must both match the reconstructed coil.
            expected_S = k==1 ? complex(power) : 0.0im
            @test U*conj(I) ≈ expected_S atol=1e-3
            src=r["voltage_source"]["s"][t]
            @test complex(src["cr"],src["ci"]) ≈ conj(expected_S/U) atol=1e-5
            @test loading["coils"][k]["s_VA"] ≈ abs(U*conj(I)) atol=1e-3
            @test loading["coils"][k]["cap_VA"] ≈ 100000/3
            @test loading["coils"][k]["headroom_VA"] ≈ 100000/3-abs(expected_S) atol=1e-3
        end
        @test loading["coils"][1]["comparison_status"] == (power==30000 ? "within_reported_cap" : "active")
        @test net == before
        restored=JSON3.read(JSON3.write(r),Dict{String,Any})
        @test profile_solution(net,restored).results[:transformer_loading] == loading
    end
    for pu in (false,true)
        net,_=coil413_fixture(); before=deepcopy(net)
        rated=solve_pf(net;per_unit=pu)
        @test rated["termination_status"]=="LOCALLY_INFEASIBLE"
        loading=profile_solution(net,rated).results[:transformer_loading]
        @test loading["candidate_status"] in ("diagnostic_candidate","no_candidate")
        @test all(c -> c["comparison_status"]=="unassessed",loading["coils"])
        # Reproduce the retained #355 witness explicitly in test setup. The
        # profiler itself never edits ratings or retries a solve.
        free=deepcopy(net);delete!(free["transformer"]["single_phase"]["tx"],"s_rating")
        r=solve_pf(free;per_unit=pu)
        @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        @test r["load"]["d"]["a"]["pd"] ≈ 40000 atol=1e-3
        @test r["bus"]["t"]["a"]["vm"] ≈ 230 atol=1e-5
        uncapped=profile_solution(free,r).results[:transformer_loading]
        @test !only(uncapped["groups"])["complete"]
        @test all(c -> c["cap_VA"]===nothing,uncapped["coils"])
        @test net==before
    end
end
