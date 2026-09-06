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
        if third_kva == 20000
            @test getindex.(xf["windings"], "r_winding") ≈ expected_r
        else
            # OpenDSS uses winding 1's power base (confirmed by its Yprim).
            # PowerIO 0.11 instead uses each winding's own rating: keep #356 open.
            @test_broken getindex.(xf["windings"], "r_winding") ≈ expected_r
        end
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

@testset "Earth routing and transformer terminals survive JSON (#163)" begin
    net = from_dss(joinpath(@__DIR__, "data", "LV", "LV1_14bus", "Master.dss"))
    xf = only(values(net["transformer"]["delta_wye"]))
    @test xf["bus_to"] == "b179"
    @test xf["terminal_map_to"] == ["a", "b", "c", "n"]
    @test net["bus"]["b179"]["neutral_terminal"] == "n"
    io = IOBuffer(); write_bmopf(net, io)
    restored = parse_bmopf(String(take!(io)); from_string=true)
    @test restored["bus"]["b179"] == net["bus"]["b179"]
    @test only(values(restored["transformer"]["delta_wye"])) == xf
    @test restored["_meta"]["earth_terminal_routing"] == net["_meta"]["earth_terminal_routing"]
end
