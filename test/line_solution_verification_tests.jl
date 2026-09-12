using Test, BMOPFTools, JSON3

# PSK-000013: supplied-result limit evidence, not an equation/KCL certificate.
function line_limit_witness()
    data = JSON3.read(read(joinpath(@__DIR__,
        "data", "scientific_review", "receiving-limit-result.json"), String), Dict{String,Any})
    data["network"], data["result"]
end
function line_limit_profile(net, result)
    findings = Finding[]
    summary = BMOPFTools.solution_check(net, result, findings)
    summary, findings
end

@testset "Independent line endpoint and angle verification (#386)" begin
    net, result = line_limit_witness()
    original = deepcopy(result)
    summary, fs = line_limit_profile(net, result)
    violations = filter(f -> f.code == "E.SOL.THERMAL_VIOLATION", fs)
    @test length(violations) == 1
    @test only(violations).detail["endpoint"] == "to"
    @test only(violations).detail["terminal"] == "b"
    @test summary["verification_status"] == "failed"
    @test result == original
    # Independent pi-line oracle: I_fr=(Vfr-Vto)/R; I_to=-I_fr+G_to*Vto.
    @test result["line"]["l"]["a"]["cm_fr"] ≈ abs((1.0-1.1)/0.1)
    @test result["line"]["l"]["a"]["cm_to"] ≈ abs(-(1.0-1.1)/0.1+0.5*1.1)
    for cap in (1.55, 2.0)
        n=deepcopy(net); n["line"]["l"]["i_max"]=cap
        @test !any(f -> f.code == "E.SOL.THERMAL_VIOLATION", last(line_limit_profile(n,result)))
    end
    # Apparent power uses receiving voltage 1.1, not sending voltage 1.0.
    n=deepcopy(net); delete!(n["line"]["l"],"i_max"); n["line"]["l"]["s_max"]=1.6
    fs=last(line_limit_profile(n,result))
    @test only(filter(f -> f.code=="E.SOL.THERMAL_VIOLATION",fs)).detail["s"] ≈ 1.705
    # Inline ratings override linecode ratings, including vector forms.
    n["linecode"]=Dict("lc"=>Dict("s_max"=>[0.1])); n["line"]["l"]["linecode"]="lc"
    n["line"]["l"]["s_max"]=[2.0]
    @test !any(f -> f.code=="E.SOL.THERMAL_VIOLATION",last(line_limit_profile(n,result)))
    delete!(n["line"]["l"],"s_max")
    @test count(f -> f.code=="E.SOL.THERMAL_VIOLATION",last(line_limit_profile(n,result))) == 2
    # A legacy supplied result missing receiving current is explicitly incomplete.
    r=deepcopy(result); delete!(r["line"]["l"]["a"],"cm_to")
    s,fs=line_limit_profile(net,r)
    @test "line.l.a.cm_to" in s["missing_result_fields"]
    @test s["verification_status"] == "indeterminate"

    n=deepcopy(net); delete!(n["line"]["l"],"i_max")
    for (lo,hi,delta,expected) in ((-.1,.3,.2,false),(-.1,.3,-.2,true),
                                  (-.1,.3,-.1,false),(-.1,.3,.3,false),
                                  (.2,.2,.2,false),(.2,.2,-.2,true),
                                  (-.1,.3,pi-.01,true))
        n["line"]["l"]["va_diff_min"]=lo; n["line"]["l"]["va_diff_max"]=hi
        r=deepcopy(result)
        # Crossing atan's branch cut still gives the small signed difference.
        for (bus,t,angle) in (("f","a",pi-.05),("t","b",pi-.05-delta))
            r["bus"][bus][t]=Dict("vr"=>cos(angle),"vi"=>sin(angle),"vm"=>1.0)
        end
        fs=last(line_limit_profile(n,r))
        @test any(f -> f.code=="E.SOL.ANGLE_VIOLATION",fs) == expected
        # JSON evidence survives a round trip without changing codes/details.
        nr=JSON3.read(JSON3.write(n), Dict{String,Any})
        rr=JSON3.read(JSON3.write(r), Dict{String,Any})
        fs2=last(line_limit_profile(nr,rr))
        @test [(f.code,f.detail) for f in fs] == [(f.code,f.detail) for f in fs2]
    end
    for mode in (:zero,:missing,:one_sided,:bad_map)
        nn=deepcopy(n); r=deepcopy(result)
        if mode==:zero
            r["bus"]["t"]["b"]=Dict("vr"=>0.0,"vi"=>0.0,"vm"=>0.0)
        elseif mode==:missing
            delete!(r["bus"]["t"],"b")
        elseif mode==:one_sided
            delete!(nn["line"]["l"],"va_diff_max")
        else
            nn["line"]["l"]["terminal_map_to"]=String[]
        end
        s,fs=line_limit_profile(nn,r)
        @test any(f -> f.code=="W.SOL.LIMIT_UNASSESSED",fs)
        @test s["verification_status"] == "indeterminate"
    end
end
