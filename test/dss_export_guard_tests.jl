using PowerIO

const _DSS_RATING_CODE = "W.EXPORT.DSS_RATING_UNVERIFIED"
const _UNRATED_SOURCE = joinpath(@__DIR__,"data","powerio_regressions","unrated_source.dss")

@testset "powerio#762: unrated source branch acquires 600 A" begin
    # Exercise only released PowerIO, so the package guard cannot hide an
    # upstream repair. One expected failure, exactly on rating preservation.
    model(m)=BMOPFTools.JSON3.read(PowerIO.emit(m,"bmopf-json@0.1.0").text,Dict{String,Any})
    first_module=PowerIO.parse(_UNRATED_SOURCE)
    before=model(first_module)
    exchange=PowerIO.parse(IOBuffer(BMOPFTools.JSON3.write(before));format="bmopf",name="case.bmopf.json")
    deck=PowerIO.emit(exchange,"dss").text
    after=model(PowerIO.parse(IOBuffer(deck);format="dss",name="roundtrip.dss"))
    id="_pio_vsource_source_impedance"
    @test !haskey(before["line"][id],"i_max")
    @test haskey(after["line"],id)
    @test after["line"][id]["i_max"] == [600.0]
    @test_broken get(before["line"][id],"i_max",nothing) == get(after["line"][id],"i_max",nothing)
end

@testset "DSS export rating admission" begin
    net=from_dss(_UNRATED_SOURCE); original=deepcopy(net)
    fs=Finding[]
    @test_throws ArgumentError to_dss(net;findings=fs)
    f=only(filter(f->f.code==_DSS_RATING_CODE,fs))
    @test f.severity==WARNING
    @test f.detail["status"]=="indeterminate"
    @test f.detail["knowledge_ids"]==["PSK-000007"]
    @test f.detail["upstream_issue"]=="https://github.com/eigenergy/powerio/issues/762"
    rating=only(filter(x->x["path"]=="line._pio_vsource_source_impedance.i_max",f.detail["changes"]))
    @test rating["before"]===nothing
    @test rating["after"]==[600.0]
    serialized=BMOPFTools.JSON3.read(BMOPFTools.JSON3.write(BMOPFTools._finding_to_json(f)),Dict{String,Any})
    @test serialized["code"]==_DSS_RATING_CODE
    @test serialized["detail"]["changes"]==f.detail["changes"]
    mktempdir() do dir
        path=joinpath(dir,"existing.dss");write(path,"retain original")
        @test_throws ArgumentError to_dss(net,path)
        @test read(path,String)=="retain original"
        missing=joinpath(dir,"absent","Master.dss")
        @test_throws ArgumentError to_dss(net,missing)
        @test !ispath(dirname(missing))
        fs=Finding[]
        text,warnings=to_dss(net;allow_unverified_ratings=true,findings=fs)
        @test !isempty(text)
        @test count(f->f.code==_DSS_RATING_CODE,fs)==1
        @test count(w->startswith(w,_DSS_RATING_CODE*":"),warnings)==1
        path_warnings=to_dss(net,missing;allow_unverified_ratings=true)
        @test read(missing,String)==text
        @test path_warnings==warnings
        write_bmopf(net,joinpath(dir,"authoritative.json"))
        restored=parse_bmopf(joinpath(dir,"authoritative.json"))
        @test !haskey(restored["line"]["_pio_vsource_source_impedance"],"i_max")
    end
    @test net==original

    # Identity correspondence plus a real explicit feeder rating can pass.
    # Legitimate 600 A is preserved as a constraint, never stripped.
    for amps in (123.0,600.0)
        safe=from_dss(joinpath(@__DIR__,"data","pf_comparison","pf_cap_wye.dss"))
        safe["line"]["l"]["i_max"]=fill(amps,4)
        snapshot=deepcopy(safe); fs=Finding[]
        text,warnings=to_dss(safe;findings=fs)
        @test all(f->f.code!=_DSS_RATING_CODE,fs)
        @test BMOPFTools._dss_rating_evidence(safe,text)["status"]=="passed"
        @test safe==snapshot
        # An actual lost constraint must be refused even without generated ids.
        constrained=deepcopy(safe); constrained["line"]["l"]["s_max"]=[10.0,10.0,10.0,10.0]
        evidence=BMOPFTools._dss_rating_evidence(constrained,text)
        @test evidence["status"]=="indeterminate"
        @test any(x->x["path"]=="line.l.s_max",evidence["changes"])
    end
    zero=from_dss(joinpath(@__DIR__,"data","pf_comparison","pf_cap_wye.dss"))
    zero["line"]["l"]["i_max"]=zeros(4); fs=Finding[]
    @test_throws ArgumentError to_dss(zero;findings=fs)
    changes=only(filter(f->f.code==_DSS_RATING_CODE,fs)).detail["changes"]
    @test any(x->x["path"]=="line.l.i_max" && x["before"]==zeros(4) && x["after"]==fill(600,4),changes)
    @test zero["line"]["l"]["i_max"]==zeros(4)

    outside=deepcopy(net);outside["time_series"]=Dict("limits"=>Dict("values"=>[100,200]))
    fs=Finding[]
    @test_throws ArgumentError to_dss(outside;findings=fs)
    evidence=only(filter(f->f.code==_DSS_RATING_CODE,fs)).detail
    @test evidence["reason"]=="outside_static_ac_domain"
    @test evidence["unsupported_collections"]==["time_series"]
    @test BMOPFTools._dss_rating_evidence(net,"this is not a DSS model")["status"]=="indeterminate"
end

@testset "DSS neutral role remains a separate limitation" begin
    # Reviewed physical correspondence is lv.n -> lv.b. Ground impedance is
    # checked by the round-trip primitive oracle; the role itself is still lost.
    net=from_dss(joinpath(@__DIR__,"data","pf_comparison","pf_1ph_xfmr.dss"))
    mktempdir() do dir
        path=joinpath(dir,"Master.dss")
        to_dss(net,path;allow_unverified_ratings=true)
        target=from_dss(path)
        @test net["bus"]["lv"]["neutral_terminal"]=="n"
        @test "b" in target["bus"]["lv"]["terminal_names"]
        @test_broken get(target["bus"]["lv"],"neutral_terminal",nothing)=="b"
    end
end
