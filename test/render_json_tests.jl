# render_json_tests.jl
#
# Coverage for the structured JSON report emitter (src/report/render_json.jl,
# dispatched from `render(report, "*.json")`). No solver required — analyze +
# serialize + re-parse and assert on the machine-readable structure. This is the
# contract downstream feature-tagging depends on, so the stable keys are locked.

using JSON3

@testset "render_json" begin

    net    = parse_bmopf(IEEE13_FIXTURE; from_string=true)
    report = analyze(net)

    @testset "round-trips to valid JSON with the documented shape" begin
        path = tempname() * ".json"
        render(report, path)
        @test isfile(path)
        d = JSON3.read(read(path, String))

        # top-level shape
        for k in (:network_name, :generated_at, :summary, :results, :findings)
            @test haskey(d, k)
        end

        # summary counts mirror the finding accessors
        @test d.summary.errors   == length(errors(report))
        @test d.summary.warnings == length(warnings(report))
        @test d.summary.info     == length(infos(report))

        # every analysis section is serialized under results (stable keys)
        for sec in (:inventory, :voltage_levels, :connectivity, :diversity,
                    :benchmark, :spec, :provenance)
            @test haskey(d.results, sec)
        end
        @test d.results.inventory.bus.total == length(net["bus"])
        structure = d.results.connectivity.structure
        @test structure.whole_network.cycle_rank == d.results.connectivity.n_extra_edges
        @test structure.whole_network.cycle_rank ==
              structure.whole_network.simple_cycle_rank + structure.whole_network.parallel_excess
        @test structure.parallel_lines.n_groups isa Integer
        @test structure.galvanic_zones isa AbstractVector
        @test !haskey(d.results.connectivity, :spatial)

        # findings serialized as an array of typed records
        @test d.findings isa AbstractVector
        @test length(d.findings) == length(report.findings)
        if !isempty(report.findings)
            f = d.findings[1]
            for k in (:severity, :code, :section, :component_type, :message)
                @test haskey(f, k)
            end
            @test f.severity in ("ERROR", "WARNING", "INFO")
        end

        rm(path; force=true)
    end

    @testset "sanitizes non-JSON-native values to strings" begin
        # results dicts hold Symbols/Chars/Sets; the emitter coerces them so the
        # output is always valid JSON that re-parses cleanly.
        io = IOBuffer()
        BMOPFTools.render_json(report, io)
        s = String(take!(io))
        d = JSON3.read(s)                       # must not throw
        @test d.network_name == "ieee13_mini"
        # a connectivity zone topology is a stringified Symbol
        if haskey(d.results.connectivity, :zones) && !isempty(d.results.connectivity.zones)
            @test d.results.connectivity.zones[1].topology isa AbstractString
        end
    end

    @testset "conditional spatial result survives report rendering" begin
        located = deepcopy(net)
        get!(located, "meta", Dict{String,Any}())["crs"] = "EPSG:4326"
        for (i, bus_id) in enumerate(sort!(collect(keys(located["bus"]))))
            located["bus"][bus_id]["longitude"] = 153.0 + i * 0.0001
            located["bus"][bus_id]["latitude"] = -27.0
        end
        first(values(located["line"]))["length"] = 0.01
        located_report = analyze(located)
        io = IOBuffer()
        BMOPFTools.render_json(located_report, io)
        decoded = JSON3.read(String(take!(io)))
        spatial = decoded.results.connectivity.spatial
        @test spatial.coordinate_reference.status == "declared_wgs84"
        @test spatial.coordinate_coverage.n_complete_lonlat == length(located["bus"])
        @test decoded.results.connectivity.structure.conductor_paths.n_path_components isa Integer
        geo = filter(f -> f.code == "W.GEO.LINE_SHORTER_THAN_CHORD", decoded.findings)
        @test !isempty(geo)
        @test first(geo).detail.chord_m > first(geo).detail.length_m
        md = IOBuffer()
        BMOPFTools.render_markdown(located_report, md)
        @test occursin("Geographic evidence", String(take!(md)))
    end

    @testset "extension dispatch: .json vs .md vs plain differ" begin
        base = tempname()
        render(report, base * ".json")
        render(report, base * ".md")
        js = read(base * ".json", String)
        md = read(base * ".md", String)
        @test startswith(strip(js), "{")                 # JSON object
        @test occursin("# BMOPF Network Summary", md)    # Markdown heading
        @test js != md
        rm(base * ".json"; force=true); rm(base * ".md"; force=true)
    end
end
