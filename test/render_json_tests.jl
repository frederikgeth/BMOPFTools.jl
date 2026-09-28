# render_json_tests.jl
#
# Coverage for the structured JSON report emitter (src/report/render_json.jl,
# dispatched from `render(report, "*.json")`). No solver required — analyze +
# serialize + re-parse and assert on the machine-readable structure. This is the
# contract downstream feature-tagging depends on, so the stable keys are locked.

using JSON3

@testset "render_json" begin

    net    = parse_bmopf(SYNTHETIC_FEEDER_FIXTURE; from_string=true)
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
        @test d.results.connectivity.switch_scenarios.status == "inapplicable"

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

    @testset "switch scenarios render in JSON, Markdown, and terminal" begin
        switched = deepcopy(net)
        switched["switch"] = Dict("tie" => Dict{String,Any}(
            "bus_from" => "supply", "bus_to" => "primary", "open_switch" => true,
            "terminal_map_from" => ["1", "2", "3", "n"],
            "terminal_map_to" => ["1", "2", "3", "n"]))
        switched_report = analyze(switched)
        json_io = IOBuffer()
        BMOPFTools.render_json(switched_report, json_io)
        decoded = JSON3.read(String(take!(json_io)))
        @test decoded.results.connectivity.switch_scenarios.status == "assessed"
        @test decoded.results.connectivity.switch_scenarios.switch_counts.n_declared_open == 1
        @test decoded.results.connectivity.switch_scenarios.transition_counts.classifications.parallel_closure == 1
        @test decoded.results.connectivity.switch_scenarios.conductor.status == "assessed"
        @test decoded.results.connectivity.switch_scenarios.conductor.transition_counts.classifications.path_merge == 1
        md_io = IOBuffer()
        BMOPFTools.render_markdown(switched_report, md_io)
        md = String(take!(md_io))
        @test occursin("Switch-state bus graph", md)
        @test occursin("Switch-state mapped conductor paths", md)
        terminal_io = IOBuffer()
        BMOPFTools.render_terminal(switched_report, terminal_io)
        terminal_text = String(take!(terminal_io))
        @test occursin("Switch-state bus graph: assessed", terminal_text)
        @test occursin("Switch-state conductor paths: assessed", terminal_text)

        incomplete = deepcopy(switched)
        delete!(incomplete["switch"]["tie"], "terminal_map_to")
        incomplete_report = analyze(incomplete)
        @test incomplete_report.results[:connectivity]["switch_scenarios"]["status"] == "assessed"
        @test incomplete_report.results[:connectivity]["switch_scenarios"]["conductor"]["status"] ==
            "inapplicable"
        incomplete_md = IOBuffer()
        BMOPFTools.render_markdown(incomplete_report, incomplete_md)
        @test occursin("Incomplete branch maps: switch:tie",
                       String(take!(incomplete_md)))
    end

    @testset "sanitizes non-JSON-native values to strings" begin
        # results dicts hold Symbols/Chars/Sets; the emitter coerces them so the
        # output is always valid JSON that re-parses cleanly.
        io = IOBuffer()
        BMOPFTools.render_json(report, io)
        s = String(take!(io))
        d = JSON3.read(s)                       # must not throw
        @test d.network_name == "synthetic_workshop_feeder"
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
