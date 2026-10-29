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
    source = read(joinpath(@__DIR__, "data", "line_geometry", "synthetic_overhead.dss"), String)
    function check_incomplete(f; wrapped=false)
        err = try
            f()
            nothing
        catch e
            e
        end
        @test err isa (wrapped ? DSSConversionError : PowerIO.PowerIOError)
        if err isa DSSConversionError
            @test err.stage == :emit
            @test err.cause.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"
        elseif err isa PowerIO.PowerIOError
            @test err.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"
        end
    end
    # A missing geometry or conductor must not acquire default Z, in either unit.
    for line_definition in ("geometry=missing length=1 units=m", "geometry=missing length=0.001 units=km")
        mktempdir() do dir
            path = joinpath(dir, "Master.dss")
            write(path, replace(source, "geometry=overhead length=1 units=m" => line_definition))
            check_incomplete(() -> from_dss(path); wrapped=true)
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
            "geometry=overhead" => "linecode=explicit phases=4")
        write(path, explicit)
        net = from_dss(path)
        @test net["linecode"][net["line"]["l1"]["linecode"]]["R_series_1_1"] ≈ 0.0002
        @test net["linecode"][net["line"]["l1"]["linecode"]]["R_series_4_4"] ≈ 0.0004
        @test net["line"]["l1"]["terminal_map_from"] == ["a", "b", "c", "n"]
        @test net["line"]["l1"]["terminal_map_to"] == ["a", "b", "c", "n"]
    end
end

@testset "Resolved overhead geometry matches independent OpenDSS matrices" begin
    path = joinpath(@__DIR__, "data", "line_geometry", "synthetic_overhead.dss")
    source = read(path, String)
    reference = JSON3.read(read(joinpath(dirname(path), "opendss_reference.json"), String))
    expected = reference.cases.synthetic_overhead
    for units in ("length=1 units=m", "length=0.001 units=km")
        mktempdir() do dir
            deck = joinpath(dir, "geometry.dss")
            write(deck, replace(source, "length=1 units=m" => units))
            net = from_dss(deck)
            line = net["line"]["l1"]
            code = net["linecode"][line["linecode"]]
            @test line["length"] ≈ 1.0
            @test line["terminal_map_from"] == line["terminal_map_to"] == ["a", "b", "c", "n"]
            for i in 1:4, j in 1:4
                @test code["R_series_$(i)_$(j)"] ≈ expected.R[i][j] rtol=1e-8
                @test code["X_series_$(i)_$(j)"] ≈ expected.X[i][j] rtol=1e-8
                for side in ("from", "to")
                    @test code["B_$(side)_$(i)_$(j)"] ≈ 2pi * 60 * 1e-9 * expected.C[i][j] / 2 rtol=1e-8
                end
            end
            buf = IOBuffer(); write_bmopf(net, buf)
            restored = parse_bmopf(String(take!(buf)); from_string=true)
            @test restored["linecode"][line["linecode"]] == code
            module_ = PowerIO.parse(deck)
            ir = PowerIO.deserialize(IOBuffer(PowerIO.serialize(module_).text))
            @test JSON3.read(PowerIO.emit(ir, "bmopf-json@0.1.0").text) ==
                  JSON3.read(PowerIO.emit(module_, "bmopf-json@0.1.0").text)
        end
    end
    mktempdir() do dir
        deck = joinpath(dir, "missing-wire.dss")
        write(deck, replace(source, "wire=neutral" => "wire=missing"))
        err = try from_dss(deck); nothing catch e; e end
        @test err isa DSSConversionError
        @test err.cause.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"
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
            @test !any(r -> r["rule"] == "dss_static_cvr_exponents",
                get(net["_meta"], "powerio_intake_repairs", []))
            threshold = only(net["_meta"]["powerio_source_semantics"]["load_voltage_thresholds"])
            @test threshold["origin"] == "powerio_typed_voltage_model"
            @test threshold["vminpu"] == 0.0 && threshold["vmaxpu"] == 2.0
            @test threshold["typed_voltage_model"]["v_low_pu"] == 0.5
            @test threshold["typed_voltage_model"]["gamma_p"] == [gp]
            io=IOBuffer();write_bmopf(net,io)
            restored=parse_bmopf(String(take!(io));from_string=true)
            @test restored["_meta"]["powerio_source_semantics"] == net["_meta"]["powerio_source_semantics"]
        end
    end
    # Verify the real reader retains a time-varying curve for our rejection
    # guard, not only the handcrafted IR witnesses below.
    mktempdir() do dir
        path = joinpath(dir, "curve.dss")
        deck = replace(source,
            "New Load.ld1" => "New LoadShape.daily npts=2 interval=1 mult=[0.8 1.2] qmult=[1.5 2.5]\nNew Load.ld1",
            "CVRvars=2.0" => "CVRvars=2.0 CVRcurve=daily")
        write(path, deck)
        @test_throws ArgumentError from_dss(path)
    end
    # Unsupported time-dependent exponents must not masquerade as static data.
    for extras in (Dict("model"=>4,"cvrcurve"=>"daily"),Dict("model"=>4,"cvrwatts"=>"NaN"))
        dn=(data=(loads=[(name="ld",extras=extras)],transformers=[]),)
        net=Dict{String,Any}("load"=>Dict("ld"=>Dict("p_nom"=>[1.],"q_nom"=>[1.],"v_nom"=>[1.])))
        @test_throws ArgumentError BMOPFTools._restore_dss_intake_fidelity!(net,dn)
    end
    for gamma in ([NaN], [Inf], Float64[], [1.0, 2.0], [2.0])
        law = Dict("model"=>"bounded_exponential", "gamma_p"=>gamma, "gamma_q"=>[2.0])
        dn = (data=(loads=[(name="ld", extras=Dict("model"=>4), voltage_model=law)], transformers=[]),)
        net = Dict{String,Any}("load"=>Dict("ld"=>Dict("model"=>"exponential",
            "p_nom"=>[1.], "q_nom"=>[1.], "v_nom"=>[240.], "gamma_p"=>[1.], "gamma_q"=>[2.])))
        @test_throws ArgumentError BMOPFTools._restore_dss_intake_fidelity!(net, dn)
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
    text,_=to_dss(net; allow_unverified_ratings=true)
    @test net==before
    @test occursin("CVRwatts=1.4 CVRvars=2.0",text)
    load=net["load"]["ld1"]
    load["gamma_p"]=[1.,2.]
    @test_throws ArgumentError BMOPFTools._restore_dss_export_fidelity("Solve",net)
end
