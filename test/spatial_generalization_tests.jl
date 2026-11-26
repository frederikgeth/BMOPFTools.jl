# Geospatial profiling beyond a WGS84 case at one latitude: national geographic
# datums, local Cartesian frames in several length units, both hemispheres and
# all four longitude quadrants, unit slips, placeholder positions.

using Test
using BMOPFTools

@testset "Spatial generalization" begin
    geo(findings) = [f.code for f in findings if startswith(f.code, "W.GEO.")]
    run(net; config=load_config()) = redirect_stderr(devnull) do
        analyze(net; config=config)
    end
    # A chain of `n` lines; `place(k)` gives bus k's coordinate pair.
    function chain(crs, place, lengths; fields=("longitude", "latitude"))
        n = length(lengths)
        net = Dict{String,Any}("bus" => Dict{String,Any}(), "line" => Dict{String,Any}(),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}("R_series_1_1" => 3e-4, "X_series_1_1" => 1e-4)))
        crs === nothing || (net["meta"] = Dict{String,Any}("crs" => crs))
        for k in 0:n
            p = place(k)
            net["bus"]["b$k"] = Dict{String,Any}(fields[1] => p[1], fields[2] => p[2], "terminal_names" => ["a"])
        end
        for k in 1:n
            net["line"]["l$(lpad(k, 2, '0'))"] = Dict{String,Any}("bus_from" => "b$(k-1)", "bus_to" => "b$k",
                "terminal_map_from" => ["a"], "terminal_map_to" => ["a"], "linecode" => "lc", "length" => lengths[k])
        end
        net
    end
    spatial(report) = report.results[:connectivity]["spatial"]

    @testset "equivalent geographic datums are metric frames" begin
        # ~98.6 m east-west step at Brisbane, Tokyo, Philadelphia, Berlin.
        sites = (("EPSG:7844", "GDA2020", (153.0, -27.0)), ("EPSG:4283", "GDA94", (153.0, -27.0)),
                 ("EPSG:6668", "JGD2011", (139.7, 35.68)), ("EPSG:4612", "JGD2000", (139.7, 35.68)),
                 ("EPSG:4269", "NAD83", (-75.0, 40.0)), ("EPSG:4258", "ETRS89", (13.4, 52.5)),
                 ("GDA2020", "GDA2020", (153.0, -27.0)), (7844, "GDA2020", (153.0, -27.0)),
                 (Dict{String,Any}("type" => "geographic", "epsg" => 6668), "JGD2011", (139.7, 35.68)))
        for (crs, datum, (lon, lat)) in sites
            step = 100.0 / (111_194.9 * cosd(lat))          # degrees of longitude per 100 m
            net = chain(crs, k -> (lon + k * step, lat), [10.0])
            r = run(net)
            sp = spatial(r)
            @test sp["coordinate_reference"]["status"] == "declared_wgs84"
            @test sp["coordinate_semantics"]["datum"] == datum
            @test geo(r.findings) == ["W.GEO.LINE_SHORTER_THAN_CHORD"]
            f = only(x for x in r.findings if x.code == "W.GEO.LINE_SHORTER_THAN_CHORD")
            @test f.detail["chord_m"] ≈ 100.0 rtol = 1e-3
            # The same case with a consistent length is clean.
            net["line"]["l01"]["length"] = 104.0
            @test isempty(geo(run(net).findings))
        end
        # WGS84 itself still reports its own datum.
        sp = spatial(run(chain("EPSG:4326", k -> (153.0 + 1e-3k, -27.0), [99.0])))
        @test sp["coordinate_semantics"]["datum"] == "WGS84"
        @test sp["coordinate_semantics"]["frame"] == "WGS84"
    end

    @testset "frames that are not interpreted stay explicit" begin
        # Projected grids are never reprojected: metric checks are inapplicable,
        # and the string, integer and object spellings are one declaration.
        for crs in ("EPSG:28356", 28356, Dict{String,Any}("type" => "projected", "epsg" => 28356))
            net = chain(crs, k -> (502_000.0 + 100k, 6_900_000.0), [10.0])
            r = run(net)
            @test spatial(r)["coordinate_reference"]["status"] == "declared_other"
            @test spatial(r)["coordinate_semantics"]["frame"] == "epsg:28356"
            @test isempty(geo(r.findings))
        end
        # No declaration at all: indeterminate, no Finding.
        r = run(chain(nothing, k -> (153.0 + 1e-3k, -27.0), [10.0]))
        @test spatial(r)["coordinate_reference"]["status"] == "unspecified"
        @test isempty(geo(r.findings))
        # Mixed datums in one case are a conflict, not a blend.
        net = chain("EPSG:7844", k -> (153.0 + 1e-3k, -27.0), [10.0])
        net["bus"]["b1"]["crs"] = "EPSG:4326"
        sp = spatial(run(net))
        @test sp["coordinate_semantics"]["bus_issue_counts"]["bus_crs_conflict"] == 1
        @test sp["coordinate_semantics"]["n_metric_eligible_buses"] == 1
        # A geographic CRS declared as projected is a contradiction.
        @test BMOPFTools._coordinate_crs(Dict{String,Any}("type" => "projected", "epsg" => 4326)) === nothing
    end

    @testset "hemispheres, antimeridian and latitude" begin
        for (lon, lat) in ((153.0, -27.0), (-70.6, -33.4), (-122.4, 37.8), (24.9, 60.2), (179.9995, -17.0))
            step = 100.0 / (111_194.9 * cosd(lat))
            wrap(x) = x > 180 ? x - 360 : x
            east = chain("EPSG:4326", k -> (wrap(lon + k * step), lat), [100.0])
            north = chain("EPSG:4326", k -> (lon, lat + k * 100.0 / 111_194.9), [100.0])
            for net in (east, north)
                r = run(net)
                @test isempty(geo(r.findings))
                @test spatial(r)["lines"]["n_with_chord_comparison"] == 1
                @test spatial(r)["lines"]["n_shorter_than_chord_beyond_tolerance"] == 0
            end
        end
    end

    @testset "local Cartesian frames raise findings in every length unit" begin
        # 300 m spans expressed in each unit.
        for (unit, scale) in (("m", 1.0), ("km", 1000.0), ("ft", 0.3048), ("ftUS", 1200 / 3937),
                              ("us_survey_foot", 1200 / 3937), ("kft", 304.8), ("mi", 1609.344))
            crs = Dict{String,Any}("type" => "cartesian", "name" => "local", "units" => unit)
            net = chain(crs, k -> (300.0 * k / scale, 0.0), [50.0, 300.0]; fields=("x", "y"))
            r = run(net)
            sp = spatial(r)
            @test sp["coordinate_reference"]["status"] == "declared_cartesian"
            @test sp["coordinate_semantics"]["unit_scale_to_m"] ≈ scale
            short = [f for f in r.findings if f.code == "W.GEO.LINE_SHORTER_THAN_CHORD"]
            @test [f.component_id for f in short] == ["l01"]
            @test only(short).detail["chord_m"] ≈ 300.0 rtol = 1e-9
            @test only(short).detail["from_xy_m"] == [0.0, 0.0]
            @test !haskey(only(short).detail, "from_lonlat")
        end
        # An unknown unit is ambiguous, never guessed.
        crs = Dict{String,Any}("type" => "cartesian", "name" => "local", "units" => "chains")
        r = run(chain(crs, k -> (300.0k, 0.0), [50.0]; fields=("x", "y")))
        @test spatial(r)["coordinate_reference"]["status"] == "ambiguous"
        @test isempty(geo(r.findings))
    end

    @testset "length far above the chord" begin
        at(k) = (153.0 + 1e-3k, -27.0)                    # ~99 m spans
        r = run(chain("EPSG:4326", at, [5000.0]))
        f = only(x for x in r.findings if x.code == "W.GEO.LINE_LONGER_THAN_CHORD")
        @test f.component_id == "l01" && f.detail["length_to_chord"] > 50
        # Boundary: the threshold is max(5 x chord, chord + 100 m).
        chord = f.detail["chord_m"]
        @test isempty(geo(run(chain("EPSG:4326", at, [5 * chord - 1.0])).findings))
        @test geo(run(chain("EPSG:4326", at, [5 * chord + 1.0])).findings) == ["W.GEO.LINE_LONGER_THAN_CHORD"]
        # Short chords use the absolute margin: a 60 m service on a 10 m chord is fine.
        near(k) = (153.0 + 1e-4k, -27.0)
        @test isempty(geo(run(chain("EPSG:4326", near, [60.0])).findings))
        @test geo(run(chain("EPSG:4326", near, [200.0])).findings) == ["W.GEO.LINE_LONGER_THAN_CHORD"]
        # A route polyline of matching length accounts for the excess.
        net = chain("EPSG:4326", at, [600.0])
        @test geo(run(net).findings) == ["W.GEO.LINE_LONGER_THAN_CHORD"]
        detour = [[153.0, -27.0], [153.0, -27.00225], [153.001, -27.00225], [153.001, -27.0]]
        net["line"]["l01"]["meta"] = Dict{String,Any}("route_geometry" => Dict{String,Any}(
            "basis" => "WGS84_geodesic_polyline", "coordinates" => detour))
        @test isempty(geo(run(net).findings))
        # The OpenDSS default length on an inline-impedance line is a placeholder.
        net = chain("EPSG:4326", at, [1.0])
        @test geo(run(net).findings) == ["W.GEO.LINE_SHORTER_THAN_CHORD"]
        delete!(net["line"]["l01"], "linecode")
        net["line"]["l01"]["R_series_1_1"] = 0.03; net["line"]["l01"]["X_series_1_1"] = 0.01
        @test isempty(geo(run(net).findings))
        net["line"]["l01"]["length"] = 2.0                 # any other value is data
        @test geo(run(net).findings) == ["W.GEO.LINE_SHORTER_THAN_CHORD"]
    end

    @testset "a consistent length factor is a unit" begin
        at(k) = (153.0 + 1e-3k, -27.0)
        chordm = 98.63
        for (factor, word) in ((0.001, "kilometers"), (1 / 0.3048, "feet"), (1 / 304.8, "kilofeet"),
                               (1 / 1609.344, "miles"))
            lengths = [chordm * factor * (1 + 0.01 * (k % 3)) for k in 1:12]
            r = run(chain("EPSG:4326", at, lengths))
            f = only(x for x in r.findings if x.code == "W.GEO.LENGTH_SCALE_SUSPECT")
            @test f.component_id === nothing
            @test f.detail["factor"] ≈ factor && occursin(word, f.detail["reading"])
            @test f.detail["n_lines"] == 12
        end
        # Coordinates in feet declared as meters.
        crs = Dict{String,Any}("type" => "cartesian", "name" => "local", "units" => "m")
        r = run(chain(crs, k -> (328.084k, 0.0), fill(100.0, 12); fields=("x", "y")))
        @test only(x for x in r.findings if x.code == "W.GEO.LENGTH_SCALE_SUSPECT").detail["factor"] ≈ 0.3048
        # Consistent lengths: assessed and passed. Realistic slack is not a unit.
        r = run(chain("EPSG:4326", at, [chordm * 1.08 for _ in 1:12]))
        @test !("W.GEO.LENGTH_SCALE_SUSPECT" in geo(r.findings))
        @test spatial(r)["length_scale"]["status"] == "passed"
        # Too few lines, or no agreement in the bulk: no verdict.
        r = run(chain("EPSG:4326", at, [chordm * 0.001 for _ in 1:9]))
        @test spatial(r)["length_scale"]["status"] == "indeterminate"
        @test !("W.GEO.LENGTH_SCALE_SUSPECT" in geo(r.findings))
        mixed = vcat([chordm * 0.001 for _ in 1:7], [chordm for _ in 1:6])
        @test !("W.GEO.LENGTH_SCALE_SUSPECT" in geo(run(chain("EPSG:4326", at, mixed)).findings))
        # The scale Finding is rolled up with, not instead of, the per-line ones.
        r = run(chain("EPSG:4326", at, [chordm * 0.001 for _ in 1:30]))
        short = only(x for x in r.findings if x.code == "W.GEO.LINE_SHORTER_THAN_CHORD")
        @test is_rolled_up(short) && short.detail["count"] == 30
    end

    @testset "placeholder and far-away positions" begin
        at(k) = (153.0 + 1e-3k, -27.0)
        net = chain("EPSG:4326", at, fill(100.0, 8))
        @test !("W.GEO.COORDINATE_OUTLIER" in geo(run(net).findings))
        net["bus"]["b3"]["longitude"] = 0.0; net["bus"]["b3"]["latitude"] = 0.0
        f = only(x for x in run(net).findings if x.code == "W.GEO.COORDINATE_OUTLIER")
        @test f.detail["buses"] == ["b3"] && f.detail["reasons"]["b3"]["reason"] == "null_island"
        # Signed zero is the same placeholder.
        net["bus"]["b3"]["longitude"] = -0.0
        @test only(x for x in run(net).findings if x.code == "W.GEO.COORDINATE_OUTLIER").detail["buses"] == ["b3"]
        # A bus on another continent.
        net = chain("EPSG:4326", at, fill(100.0, 8))
        net["bus"]["b5"]["longitude"] = 2.35; net["bus"]["b5"]["latitude"] = 48.85
        f = only(x for x in run(net).findings if x.code == "W.GEO.COORDINATE_OUTLIER")
        @test f.detail["reasons"]["b5"]["reason"] == "far_from_network"
        # A long rural feeder is not an outlier of itself: 60 km of 2 km spans.
        rural = chain("EPSG:4326", k -> (146.0 + 0.02k, -24.0), fill(2040.0, 30))
        @test !("W.GEO.COORDINATE_OUTLIER" in geo(run(rural).findings))
        # In a local Cartesian frame the origin is a legitimate position.
        crs = Dict{String,Any}("type" => "cartesian", "name" => "local", "units" => "m")
        local_net = chain(crs, k -> (100.0k, 0.0), fill(100.0, 8); fields=("x", "y"))
        @test !("W.GEO.COORDINATE_OUTLIER" in geo(run(local_net).findings))
        local_net["bus"]["b8"]["x"] = 5.0e6
        f = only(x for x in run(local_net).findings if x.code == "W.GEO.COORDINATE_OUTLIER")
        @test f.detail["buses"] == ["b8"]
        # Fewer than five positioned buses: the extent rule gives no verdict.
        tiny = chain("EPSG:4326", at, fill(100.0, 2))
        tiny["bus"]["b2"]["longitude"] = 2.35; tiny["bus"]["b2"]["latitude"] = 48.85
        @test !("W.GEO.COORDINATE_OUTLIER" in geo(run(tiny).findings))
    end

    @testset "exchanged axes are reported as evidence, never applied" begin
        # Brisbane with longitude and latitude exchanged: out of range, valid if exchanged.
        net = chain("EPSG:4326", k -> (-27.0, 153.0 + 1e-3k), [100.0])
        fs = [f for f in run(net).findings if f.code == "W.GEO.WGS84_RANGE"]
        @test length(fs) == 2 && all(f -> f.detail["in_range_if_axes_exchanged"], fs)
        @test net["bus"]["b0"]["longitude"] == -27.0          # input untouched
        # Projected eastings mislabeled as geographic are not a simple exchange.
        net = chain("EPSG:4326", k -> (502_000.0 + 100k, 6_900_000.0), [100.0])
        fs = [f for f in run(net).findings if f.code == "W.GEO.WGS84_RANGE"]
        @test length(fs) == 2 && !any(f -> f.detail["in_range_if_axes_exchanged"], fs)
        # Many such buses are one roll-up, not one Finding per bus.
        big = chain("EPSG:4326", k -> (502_000.0 + 100k, 6_900_000.0), fill(100.0, 40))
        f = only(x for x in run(big).findings if x.code == "W.GEO.WGS84_RANGE")
        @test is_rolled_up(f) && f.detail["count"] == 41
    end

    @testset "buscoords load into a local Cartesian frame" begin
        csv = tempname() * ".csv"
        write(csv, "b0,0,0\nb1,300,0\nb2, 600 , 0\nghost,1,1\nbad,x,y\n")
        base() = chain(nothing, k -> (nothing, nothing), [50.0, 91.44]; fields=("unused_a", "unused_b"))
        net = base()
        @test sideload_coordinates!(net, csv; frame=:cartesian, units="ft", name="ieee") == (3, 1)
        @test net["bus"]["b1"]["x"] == 300.0 && net["bus"]["b1"]["y"] == 0.0
        @test !haskey(net["bus"]["b1"], "longitude")
        @test net["meta"]["crs"] == Dict{String,Any}("type" => "cartesian", "name" => "ieee", "units" => "ft")
        r = run(net)
        @test spatial(r)["coordinate_reference"]["status"] == "declared_cartesian"
        @test spatial(r)["coordinate_semantics"]["n_metric_eligible_buses"] == 3
        short = only(f for f in r.findings if f.code == "W.GEO.LINE_SHORTER_THAN_CHORD")
        @test short.component_id == "l01" && short.detail["chord_m"] ≈ 91.44
        # Loading again with the same declaration is idempotent.
        @test sideload_coordinates!(net, csv; frame=:cartesian, units="ft", name="ieee") == (3, 1)
        # The default is unchanged: longitude/latitude fields and no declaration.
        plain = base()
        @test sideload_coordinates!(plain, csv) == (3, 1)
        @test plain["bus"]["b1"]["longitude"] == 300.0 && !haskey(plain, "meta")
        # Explicit refusals instead of guesses.
        @test_throws ArgumentError sideload_coordinates!(base(), csv; frame=:cartesian)
        @test_throws ArgumentError sideload_coordinates!(base(), csv; frame=:cartesian, units="degrees")
        @test_throws ArgumentError sideload_coordinates!(base(), csv; frame=:cartesian, units="furlong")
        @test_throws ArgumentError sideload_coordinates!(base(), csv; units="ft")
        @test_throws ArgumentError sideload_coordinates!(base(), csv; frame=:projected, units="m")
        conflict = base(); conflict["meta"] = Dict{String,Any}("crs" => "EPSG:4326")
        @test_throws ArgumentError sideload_coordinates!(conflict, csv; frame=:cartesian, units="m")
        @test !haskey(conflict["bus"]["b1"], "x")              # nothing written on refusal
        # A declaration under another accepted key, at the root, conflicts too,
        # and the refused call leaves the case untouched.
        aliased = base(); aliased["coordinate_reference_system"] = "EPSG:4326"
        @test_throws ArgumentError sideload_coordinates!(aliased, csv; frame=:cartesian, units="m")
        @test !haskey(aliased, "meta")
    end

    @testset "an IBR on a series-path interior bus is an attachment" begin
        net = parse_bmopf(joinpath(@__DIR__, "data", "spatial_discrepancies.json"))
        net["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "b", "terminal_map" => ["1"],
            "topology" => "SINGLE_PHASE", "prime_mover" => "PV", "s_max" => [5000.0]))
        index = BMOPFTools._spatial_review_attachment_index(net)
        @test [(a["kind"], a["component_id"]) for a in index["b"]] == [("ibr", "pv")]
    end
end
