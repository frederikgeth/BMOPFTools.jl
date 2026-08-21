# test/powerio_findings_tests.jl
#
# PowerIO conversion diagnostics lifted into Findings. Before this, from_dss
# stashed the diagnostics as raw strings under _meta and raised one aggregate
# @warn; nothing that reports findings could see them, so a fidelity loss that
# changed the physics (a dropped transformer, a substituted value) never
# reached a report a caller reads.
#
# The lift keeps powerio's own code verbatim and maps its severity ladder
# (debug/info/warning/error/fatal) onto this package's three levels. Records
# are folded per (code, severity, component type) class: a large ENWL feeder emits one
# EMIT.BMOPF.FIELD_DROPPED per dropped field per element, five figures on the
# bigger networks, which ungrouped would be the whole report.

@testset "PowerIO conversion findings" begin

    @testset "a line splits into code and message" begin
        code, msg = BMOPFTools._split_powerio_line(
            "EMIT.BMOPF.FIELD_DROPPED: load ld1: `kv` has no place in the schema")
        @test code == "EMIT.BMOPF.FIELD_DROPPED"
        # The message keeps its own colons — only the first separator splits.
        @test msg == "load ld1: `kv` has no place in the schema"

        # A prefix that is not a code leaves the line whole.
        @test BMOPFTools._split_powerio_line("no code here: text") == ("", "no code here: text")
        @test BMOPFTools._split_powerio_line("bare text") == ("", "bare text")
    end

    @testset "element paths resolve to a component" begin
        # The writer spells its paths `<class> <name>`.
        @test BMOPFTools._powerio_element("transformer Tx12", true) == (:transformer, "tx12")
        @test BMOPFTools._powerio_element("transformer Tx12", false) == (:transformer, "Tx12")
        @test BMOPFTools._powerio_element("load ld1", false) == (:load, "ld1")
        # A class this package does not address, and the reader's JSON pointer
        # spelling, both resolve to the network.
        @test BMOPFTools._powerio_element("gizmo g1", false) == (:network, nothing)
        @test BMOPFTools._powerio_element("/transformer/delta_wye/t1/r_series", false) ==
              (:transformer, "t1")
        @test BMOPFTools._powerio_element("/load/LD1/model", true) == (:load, "ld1")
        @test BMOPFTools._powerio_element(nothing, false) == (:network, nothing)

        @test BMOPFTools._powerio_message_element(
            "voltage source Src: `angle` dropped", true) == (:voltage_source, "src")
        @test BMOPFTools._powerio_message_element(
            "meta `created` dropped", false) == (:network, nothing)
    end

    @testset "severity maps off the diagnostic record" begin
        # A powerio Diagnostic carries its record behind the line it renders as;
        # this stands in for one, matching on the properties the lift reads.
        recs = BMOPFTools._powerio_diagnostic_records([
            (code="READ.DSS.X", severity="error",   message="a", stage="read"),
            (code="READ.DSS.Y", severity="info",    message="b", stage="read"),
            (code="READ.DSS.Z", severity="debug",   message="c", stage="read"),
            (code="READ.DSS.W", severity="fatal",   message="d", stage="read"),
            (code="READ.DSS.V", severity="warning", message="e", stage="read"),
        ])
        by_code = Dict(r["code"] => r["severity"] for r in recs)
        @test by_code["READ.DSS.X"] == "ERROR"
        @test by_code["READ.DSS.W"] == "ERROR"
        @test by_code["READ.DSS.V"] == "WARNING"
        @test by_code["READ.DSS.Y"] == "INFO"
        @test by_code["READ.DSS.Z"] == "INFO"
    end

    @testset "a line without a record is a WARNING" begin
        # PowerIO.jl reports a handle's retained findings as lines alone, with
        # no severity to read.
        recs = BMOPFTools._powerio_diagnostic_records(
            ["EMIT.BMOPF.FIELD_DROPPED: load ld1: `kv` dropped"])
        @test length(recs) == 1
        @test recs[1]["severity"] == "WARNING"
        @test recs[1]["code"] == "EMIT.BMOPF.FIELD_DROPPED"
        @test recs[1]["message"] == "load ld1: `kv` dropped"
        @test recs[1]["component_type"] == "load"
        @test recs[1]["component_id"] == "ld1"
    end

    @testset "a class folds to one record, a singleton keeps its element" begin
        diags = Any[(code="EMIT.BMOPF.FIELD_DROPPED", severity="warning",
                     message="load ld$i: `kv` dropped", stage="emit") for i in 1:40]
        push!(diags, (code="EMIT.BMOPF.TRANSFORMER_UNSUPPORTED", severity="warning",
                      message="transformer t1: not representable", stage="emit",
                      element_path="transformer t1"))
        recs = BMOPFTools._powerio_diagnostic_records(diags; fold_ids=true)
        @test length(recs) == 2

        dropped = recs[findfirst(r -> r["code"] == "EMIT.BMOPF.FIELD_DROPPED", recs)]
        @test dropped["count"] == 40
        @test dropped["component_type"] == "load"
        @test startswith(dropped["message"], "40 occurrences, e.g. ")
        @test length(dropped["messages"]) == 5      # examples, not the whole list
        @test length(dropped["elements"]) == 40
        @test !haskey(dropped, "component_id")

        # One element in the class, so the record still names it (case folded
        # to match the ids from_dss wrote into the dict).
        xfmr = recs[findfirst(r -> r["code"] == "EMIT.BMOPF.TRANSFORMER_UNSUPPORTED", recs)]
        @test xfmr["count"] == 1
        @test xfmr["component_type"] == "transformer"
        @test xfmr["component_id"] == "t1"
        @test xfmr["message"] == "transformer t1: not representable"
        @test !haskey(xfmr, "messages")             # a singleton has no examples
    end

    @testset "two elements in a class drop the id and keep the paths" begin
        recs = BMOPFTools._powerio_diagnostic_records([
            (code="EMIT.BMOPF.TRANSFORMER_UNSUPPORTED", severity="warning",
             message="transformer reg1: no", stage="emit", element_path="transformer reg1"),
            (code="EMIT.BMOPF.TRANSFORMER_UNSUPPORTED", severity="warning",
             message="transformer reg2: no", stage="emit", element_path="transformer reg2"),
        ])
        @test length(recs) == 1
        @test !haskey(recs[1], "component_id")
        @test recs[1]["component_type"] == "transformer"
        @test recs[1]["elements"] == ["transformer reg1", "transformer reg2"]
    end

    @testset "one code on different component types stays separate" begin
        recs = BMOPFTools._powerio_diagnostic_records([
            (code="EMIT.BMOPF.FIELD_DROPPED", severity="warning",
             message="load l1: field dropped", stage="emit"),
            (code="EMIT.BMOPF.FIELD_DROPPED", severity="warning",
             message="transformer t1: field dropped", stage="emit"),
        ])
        @test length(recs) == 2
        @test Set(r["component_type"] for r in recs) == Set(["load", "transformer"])
        @test all(r -> r["count"] == 1, recs)
        @test only(filter(r -> r["component_type"] == "load", recs))["component_id"] == "l1"
        @test only(filter(r -> r["component_type"] == "transformer", recs))["component_id"] == "t1"
    end

    @testset "records become Findings carrying the powerio code verbatim" begin
        recs = BMOPFTools._powerio_diagnostic_records([
            (code="EMIT.BMOPF.TRANSFORMER_UNSUPPORTED", severity="warning",
             message="transformer t1: not representable", stage="emit",
             element_path="transformer t1"),
        ])
        fs = powerio_findings(recs)
        @test length(fs) == 1
        f = fs[1]
        @test f isa Finding
        @test f.code == "EMIT.BMOPF.TRANSFORMER_UNSUPPORTED"   # not restated in W.*/E.* grammar
        @test f.severity == WARNING
        @test f.section == :provenance
        @test f.component_type == :transformer
        @test f.component_id == "t1"
        @test f.detail["count"] == 1
        @test f.detail["stage"] == "emit"
        # A network that never crossed the PowerIO boundary reports nothing.
        @test isempty(powerio_findings(Dict{String,Any}()))
    end

    @testset "from_dss records both views and fills a caller's vector" begin
        # The two line-to-line regulator legs are preserved as separate
        # single_phase transformers. Their connection-loss diagnostics form a
        # real two-element class, so this also exercises grouping from an
        # actual PowerIO conversion rather than constructed records alone.
        path = joinpath(@__DIR__, "data", "pf_comparison", "pf_open_delta_reg.dss")
        fs   = Finding[]
        net  = from_dss(path; findings=fs)

        lines = net["_meta"]["powerio_warnings"]
        recs  = net["_meta"]["powerio_diagnostics"]
        @test lines isa Vector{String}
        @test !isempty(lines)
        # The two views cover the same diagnostics.
        @test sum(r["count"] for r in recs) == length(lines)
        @test length(recs) < length(lines)
        @test length(fs) == length(recs)

        lossy = filter(f -> f.code == "EMIT.BMOPF.TRANSFORMER_CONNECTION_LOSSY", fs)
        @test length(lossy) == 1
        @test lossy[1].component_type == :transformer
        @test lossy[1].detail["count"] == 2
        @test lossy[1].detail["elements"] == ["transformer reg1", "transformer reg2"]

        legs = net["transformer"]["single_phase"]
        @test Set(keys(legs)) == Set(["reg1", "reg2"])
        @test legs["reg1"]["terminal_map_from"] == ["a", "b"]
        @test legs["reg1"]["terminal_map_to"] == ["a", "b"]
        @test legs["reg2"]["terminal_map_from"] == ["b", "c"]
        @test legs["reg2"]["terminal_map_to"] == ["b", "c"]
        @test legs["reg1"]["tap"] ≈ inv(1.05)
        @test legs["reg2"]["tap"] ≈ inv(1.025)
    end

    @testset "analyze reports them, before and after a round trip" begin
        path = joinpath(@__DIR__, "data", "pf_comparison", "pf_open_delta_reg.dss")
        net  = from_dss(path)

        report = analyze(net)
        lifted = filter(f -> startswith(f.code, "EMIT."), report.findings)
        @test !isempty(lifted)
        @test all(f -> f.section == :provenance, lifted)
        summary = report.results[:provenance]["powerio_conversion"]
        @test summary["n_classes"] == length(lifted)
        @test summary["n_diagnostics"] == length(net["_meta"]["powerio_warnings"])
        @test summary["source"] == abspath(path)

        # The records ride along under meta.provenance, so a case reloaded from
        # a saved BMOPF file still reports the import's losses.
        buf = IOBuffer()
        write_bmopf(net, buf)
        reloaded = parse_bmopf(String(take!(buf)); from_string=true)
        @test length(filter(f -> startswith(f.code, "EMIT."), analyze(reloaded).findings)) ==
              length(lifted)
    end

    @testset "to_dss fills a caller's findings vector" begin
        net = from_dss(joinpath(@__DIR__, "data", "pf_comparison", "pf_3ph_line.dss"))
        fs  = Finding[]
        dss_text, warns = to_dss(net; findings=fs)
        @test !isempty(dss_text)
        @test warns isa Vector{String}          # the returned shape is unchanged
        @test !isempty(fs)
        @test all(f -> startswith(f.code, "EMIT."), fs)
        @test sum(f -> f.detail["count"], fs) == length(warns)
    end
end
