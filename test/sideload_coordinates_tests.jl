# sideload_coordinates_tests.jl
#
# Coverage for sideload_coordinates! — merges an OpenDSS-style Buscoords CSV
# (bus_id,x,y, no header) into a parsed network. No solver required.

using JSON3
using JSONSchema

@testset "sideload_coordinates!" begin

    # write_csv(rows) → path to a temp CSV holding the given text lines.
    write_csv(lines) = (p = tempname() * ".csv";
                        open(io -> foreach(l -> println(io, l), lines), p, "w"); p)

    @testset "matches buses and stores lon/lat (x→lon, y→lat)" begin
        net  = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        path = write_csv([
            "primary, 100.0, 200.0",
            "trunk, 110.5, 205.5",
            "workshop, 120.0, 210.0",
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 3
        @test n_skipped == 0
        @test net["bus"]["primary"]["longitude"] == 100.0
        @test net["bus"]["primary"]["latitude"]  == 200.0
        @test net["bus"]["trunk"]["longitude"] == 110.5
        buf = IOBuffer(); write_bmopf(net, buf)
        back = parse_bmopf(String(take!(buf)); from_string=true)
        @test back["bus"]["primary"]["longitude"] == 100.0
        @test back["bus"]["primary"]["latitude"] == 200.0
    end

    @testset "rows for unknown buses are counted as skipped" begin
        net  = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        path = write_csv([
            "primary, 1.0, 2.0",
            "no_such_bus, 3.0, 4.0",   # not present in net → skipped
            "another_ghost, 5.0, 6.0", # skipped
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1
        @test n_skipped == 2
        @test !haskey(net["bus"]["primary"], "latitude") == false  # primary did get coords
    end

    @testset "blank, short and non-numeric rows are ignored (not skipped)" begin
        net  = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        path = write_csv([
            "",                  # blank → continue
            "   ",               # whitespace-only → continue
            "primary, 1.0",          # < 3 fields → continue
            "trunk, abc, 2.0",     # non-numeric x → continue
            "workshop, 3.0, xyz",     # non-numeric y → continue
            "junction, 7.0, 8.0",     # the one good row
        ])
        n_matched, n_skipped = sideload_coordinates!(net, path)
        @test n_matched == 1                       # only bus junction matched
        @test n_skipped == 0                       # malformed rows are not "skipped"
        @test net["bus"]["junction"]["longitude"] == 7.0
        @test !haskey(net["bus"]["primary"], "longitude")
    end

    @testset "missing file throws ArgumentError" begin
        net = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        @test_throws ArgumentError sideload_coordinates!(
            net, joinpath(tempdir(), "definitely_no_such_coords.csv"))
    end

    @testset "coordinates survive both writer destinations without mutation" begin
        net = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        # Deterministic illustrative geographic pairs, not utility locations.
        for (i, id) in enumerate(sort(collect(keys(net["bus"]))))
            net["bus"][id]["longitude"] = 153.0 + i / 1000
            net["bus"][id]["latitude"] = -27.5 - i / 1000
        end
        before = deepcopy(net)
        mktempdir() do dir
            for include_coordinates in (true, false), indent in (2, nothing)
                buf = IOBuffer()
                write_bmopf(net, buf; include_coordinates, indent)
                path = joinpath(dir, "case.json")
                write_bmopf(net, path; include_coordinates, indent)
                for raw in (String(take!(buf)), read(path, String))
                    parsed = JSON3.read(raw, Dict{String,Any})
                    reloaded = parse_bmopf(raw; from_string=true)
                    for (id, bus) in parsed["bus"]
                        @test !haskey(bus, "neutral_terminal")
                        for field in ("longitude", "latitude")
                            @test haskey(bus, field) == include_coordinates
                            if include_coordinates
                                @test bus[field] == net["bus"][id][field]
                                @test reloaded["bus"][id][field] == bus[field]
                            else
                                @test !haskey(reloaded["bus"][id], field)
                            end
                        end
                        # All electrical fields, including derived neutral identity,
                        # survive independently of the coordinate policy.
                        for (field, value) in net["bus"][id]
                            field in ("longitude", "latitude") && continue
                            @test reloaded["bus"][id][field] == value
                        end
                    end
                    for component in ("line", "load", "voltage_source", "transformer")
                        @test get(reloaded, component, nothing) == get(net, component, nothing)
                    end
                end
                @test net == before
            end
        end
        # Exercise the default separately from an explicit true keyword.
        buf = IOBuffer(); write_bmopf(net, buf)
        default = JSON3.read(String(take!(buf)), Dict{String,Any})
        @test default["bus"]["primary"]["longitude"] == net["bus"]["primary"]["longitude"]
        mktempdir() do dir
            path = joinpath(dir, "default.json")
            write_bmopf(net, path)
            @test parse_bmopf(path)["bus"]["primary"]["latitude"] == net["bus"]["primary"]["latitude"]
        end
    end

    @testset "strict coordinate omission and core schema validation" begin
        net = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        for (id, bus) in net["bus"]
            bus["longitude"] = 153.0
            bus["latitude"]  = -27.5
        end
        for include_coordinates in (true, false)
            buf = IOBuffer(); write_bmopf(net, buf; include_coordinates)
            raw = String(take!(buf))
            parsed = JSON3.read(raw, Dict{String,Any})
            schema = BMOPFTools._get_schema(:draft)
            issue = JSONSchema.validate(schema, parsed)
            if include_coordinates
                @test issue !== nothing
                @test string(issue.reason) == "additionalProperties"
            else
                @test issue === nothing
            end
            # Package schema_check has always excluded known coordinate extensions;
            # its core validation must remain independent of the writer policy.
            findings = Finding[]
            result = schema_check(parse_bmopf(raw; from_string=true), findings)
            @test result["jsonschema_valid"]
            @test !any(f -> f.severity == ERROR || f.code == "I.SCHEMA.UNKNOWN_FIELDS", findings)
        end
    end

    @testset "missing, partial and boundary coordinates are copied verbatim" begin
        net = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
        net["bus"]["primary"]["longitude"] = 180.0
        net["bus"]["primary"]["latitude"] = -90.0
        net["bus"]["trunk"]["longitude"] = 0.0  # latitude deliberately absent
        net["bus"]["workshop"]["latitude"] = 200.0  # not a geographic position
        before = deepcopy(net)
        buf = IOBuffer(); write_bmopf(net, buf)
        back = parse_bmopf(String(take!(buf)); from_string=true)
        for (id, bus) in net["bus"], field in ("longitude", "latitude")
            @test haskey(back["bus"][id], field) == haskey(bus, field)
            haskey(bus, field) && @test back["bus"][id][field] == bus[field]
        end
        @test net == before
        for field in ("longitude", "latitude"), value in (NaN, Inf, -Inf)
            invalid = deepcopy(net)
            invalid["bus"]["primary"][field] = value
            @test_throws ErrorException write_bmopf(invalid, IOBuffer())
            @test_nowarn write_bmopf(invalid, IOBuffer(); include_coordinates=false)
        end
    end
end
