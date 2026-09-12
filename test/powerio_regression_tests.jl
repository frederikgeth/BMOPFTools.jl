# Package intake witnesses for #163, #356, and the rejection part of #381.
# These are finite parser regressions, not extensions of a scientific contract.

@testset "PowerIO unequal winding kVA resistance bases (#356)" begin
    source = read(joinpath(@__DIR__, "data", "pf_comparison", "pf_3wdg_unequal_kva.dss"), String)
    # Smaller, equal, and larger than winding 1: equal ratings alone hide the bug.
    for third_kva in (5000, 20000, 40000)
        net = mktempdir() do dir
            path = joinpath(dir, "Master.dss")
            write(path, replace(source, "kvas=(20000, 20000, 5000)" =>
                "kvas=(20000, 20000, $third_kva)"))
            from_dss(path)
        end
        xf = net["transformer"]["n_winding"]["t1"]
        ratings = [20e6, 20e6, third_kva * 1000.0]
        expected_r = [0.004 * 3 * 33000^2 / ratings[1],
                      0.004 * 11000^2 / ratings[2],
                      0.008 * 400^2 / ratings[1]]
        @test getindex.(xf["windings"], "s_rating") == ratings
        @test getindex.(xf["windings"], "r_winding") ≈ expected_r
        @test all(!haskey(w, "s_max") for w in xf["windings"])
        for (pair, percent) in (("1_2", 10), ("1_3", 17), ("2_3", 6))
            @test xf["x_sc"][pair] ≈ percent / 100 * 3 * 33000^2 / ratings[1]
        end
        io = IOBuffer(); write_bmopf(net, io)
        restored = parse_bmopf(String(take!(io)); from_string=true)
        @test restored["transformer"]["n_winding"]["t1"] == xf
        @test BMOPFTools.nwinding_yprim(restored["transformer"]["n_winding"]["t1"])[2] ≈
              BMOPFTools.nwinding_yprim(xf)[2]
    end
end

@testset "Unresolved DSS geometry is rejected, never replaced (#381)" begin
    source = read(joinpath(@__DIR__, "data", "line_geometry", "ieee13_601.dss"), String)
    function check_incomplete(f)
        err = try
            f()
            nothing
        catch e
            e
        end
        @test err isa PowerIO.PowerIOError
        if err isa PowerIO.PowerIOError
            @test err.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"
        end
    end
    # One physical length in two unit encodings; neither may acquire default Z.
    for line_definition in ("geometry=g601 length=1 units=m", "geometry=g601 length=0.001 units=km")
        mktempdir() do dir
            path = joinpath(dir, "Master.dss")
            write(path, replace(source, "geometry=g601 length=1 units=m" => line_definition))
            check_incomplete(() -> from_dss(path))
            # Retaining the source IR does not make an unresolved line electrical.
            module_ = PowerIO.parse(path)
            restored = PowerIO.deserialize(IOBuffer(PowerIO.serialize(module_).text))
            check_incomplete(() -> PowerIO.emit(restored, "bmopf-json@0.1.0"))
        end
    end
    # Positive control: explicitly supplied four-conductor data are accepted.
    mktempdir() do dir
        path = joinpath(dir, "Master.dss")
        code = "new linecode.explicit nphases=4 units=m " *
            "rmatrix=[0.0002 | 0.00003 0.0002 | 0.00003 0.00003 0.0002 | 0.00003 0.00003 0.00003 0.0004] " *
            "xmatrix=[0.0003 | 0.00002 0.0003 | 0.00002 0.00002 0.0003 | 0.00002 0.00002 0.00002 0.0005]\n"
        explicit = replace(source, "new line.l1" => code * "new line.l1",
            "geometry=g601" => "linecode=explicit phases=4")
        write(path, explicit)
        net = from_dss(path)
        @test net["linecode"]["explicit"]["R_series_1_1"] ≈ 0.0002
        @test net["linecode"]["explicit"]["R_series_4_4"] ≈ 0.0004
        @test net["line"]["l1"]["terminal_map_from"] == ["a", "b", "c", "n"]
        @test net["line"]["l1"]["terminal_map_to"] == ["a", "b", "c", "n"]
    end
end

@testset "DSS static CVR import (#333)" begin
    source=read(joinpath(@__DIR__,"data","pf_comparison","pf_exp_1ph.dss"),String)
    for (suffix,gp,gq) in (("CVRwatts=1.4 CVRvars=2.0",1.4,2.0),
                           ("",1.0,2.0),("CVRwatts=0 CVRvars=0",0.0,0.0),
                           ("CVRwatts=-0.5 CVRvars=3.1",-0.5,3.1))
        mktempdir() do dir
            path=joinpath(dir,"case.dss")
            write(path,replace(source,"CVRwatts=1.4 CVRvars=2.0"=>suffix))
            net=from_dss(path); load=net["load"]["ld1"]
            @test load["model"]=="exponential"
            @test load["gamma_p"]==[gp] && load["gamma_q"]==[gq]
            @test load["v_nom"]==[240.0]
            io=IOBuffer();write_bmopf(net,io)
            @test parse_bmopf(String(take!(io));from_string=true)["load"]==net["load"]
            @test haskey(net["_meta"],"powerio_intake_repairs")
        end
    end
    # Unsupported time-dependent exponents must not masquerade as static data.
    for extras in (Dict("model"=>4,"cvrcurve"=>"daily"),Dict("model"=>4,"cvrwatts"=>"NaN"))
        dn=(data=(loads=[(name="ld",extras=extras)],transformers=[]),)
        net=Dict{String,Any}("load"=>Dict("ld"=>Dict("p_nom"=>[1.],"q_nom"=>[1.],"v_nom"=>[1.])))
        @test_throws ArgumentError BMOPFTools._restore_dss_intake_fidelity!(net,dn)
    end
    # Existing non-CVR laws are not reinterpreted.
    dn=(data=(loads=[(name="ld",extras=Dict("model"=>1))],transformers=[]),)
    net=Dict{String,Any}("load"=>Dict("ld"=>Dict("model"=>"constant_power")))
    before=deepcopy(net);BMOPFTools._restore_dss_intake_fidelity!(net,dn)
    @test net==before
end

@testset "DSS export preserves repaired laws without mutating input" begin
    net=from_dss(joinpath(@__DIR__,"data","pf_comparison","pf_exp_1ph.dss"))
    before=deepcopy(net)
    text,_=to_dss(net)
    @test net==before
    @test occursin("CVRwatts=1.4 CVRvars=2.0",text)
    load=net["load"]["ld1"]
    load["gamma_p"]=[1.,2.]
    @test_throws ArgumentError BMOPFTools._restore_dss_export_fidelity("Solve",net)
end
