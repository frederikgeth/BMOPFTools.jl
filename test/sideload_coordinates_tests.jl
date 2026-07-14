# sideload_coordinates_tests.jl
#
# Coverage for sideload_coordinates! — merges an OpenDSS-style Buscoords CSV
# (bus_id,x,y, no header) into a parsed network. No solver required.

using JSON3

@testset "sideload_coordinates!" begin

    # write_csv(rows) → path to a temp CSV holding the given text lines.
    write_csv(lines) = (p = tempname() * ".csv";
                        open(io -> foreach(l -> println(io, l), lines), p, "w"); p)

    @testset "matches buses and stores lon/lat (x→lon, y→lat)" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "650, 100.0, 200.0",
            "632, 110.5, 205.5",
            "634, 120.0, 210.0",
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 3
        @test n_skipped == 0
        @test net["bus"]["650"]["longitude"] == 100.0
        @test net["bus"]["650"]["latitude"]  == 200.0
        @test net["bus"]["632"]["longitude"] == 110.5
    end

    @testset "rows for unknown buses are counted as skipped" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "650, 1.0, 2.0",
            "no_such_bus, 3.0, 4.0",   # not present in net → skipped
            "another_ghost, 5.0, 6.0", # skipped
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1
        @test n_skipped == 2
        @test !haskey(net["bus"]["650"], "latitude") == false  # 650 did get coords
    end

    @testset "blank, short and non-numeric rows are ignored (not skipped)" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        path = write_csv([
            "",                  # blank → continue
            "   ",               # whitespace-only → continue
            "650, 1.0",          # < 3 fields → continue
            "632, abc, 2.0",     # non-numeric x → continue
            "634, 3.0, xyz",     # non-numeric y → continue
            "671, 7.0, 8.0",     # the one good row
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1                       # only bus 671 matched
        @test n_skipped == 0                       # malformed rows are not "skipped"
        @test net["bus"]["671"]["longitude"] == 7.0
        @test !haskey(net["bus"]["650"], "longitude")
    end

    @testset "missing file throws ArgumentError" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        @test_throws ArgumentError sideload_coordinates!(
            net, joinpath(tempdir(), "definitely_no_such_coords.csv"))
    end

    @testset "sideloaded coordinates are stripped on write_bmopf" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        # Attach synthetic coordinates to all buses
        for (id, bus) in net["bus"]
            bus["longitude"] = 153.0 + rand()
            bus["latitude"]  = -27.0 - rand()
        end
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw    = String(take!(buf))
        parsed = JSON3.read(raw, Dict{String,Any})
        for (_, bus) in parsed["bus"]
            @test !haskey(bus, "longitude")
            @test !haskey(bus, "latitude")
        end
    end

    @testset "schema_check passes after sideload + write + reload" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        for (id, bus) in net["bus"]
            bus["longitude"] = 153.0
            bus["latitude"]  = -27.5
        end
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw      = String(take!(buf))
        reloaded = parse_bmopf(raw; from_string=true)
        findings = Finding[]
        schema_check(reloaded, findings)
        @test isempty(filter(f -> f.severity == ERROR, findings))
        # Unstripped coordinates surface as INFO-level I.SCHEMA.UNKNOWN_FIELDS,
        # never as ERROR, so the assertion has to name that code to have teeth.
        @test isempty(filter(f -> f.code == "I.SCHEMA.UNKNOWN_FIELDS", findings))
    end
end
