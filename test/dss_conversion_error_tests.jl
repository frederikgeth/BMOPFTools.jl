using Test, BMOPFTools, PowerIO, JSON3

_dce_capture(f) = try f(); nothing catch e; e end
function _dce_diagnostic(code; severity=:error, message="line hidden: diagnostic",
                         id=nothing, target=nothing, action=nothing,
                         spans=PowerIO.SourceSpan[], related=String[], details=nothing)
    PowerIO.Diagnostic(code, severity, message, id, target, action, spans, related, details)
end

@testset "DSS failure evidence — real geometry rejection and collector" begin
    path = joinpath(@__DIR__, "data", "line_geometry", "synthetic_overhead.dss")
    findings = Finding[]
    err = _dce_capture(() -> from_dss(path; findings))
    @test err isa DSSConversionError
    @test err.source_path == abspath(path)
    @test err.stage == :emit
    @test err.cause isa PowerIO.PowerIOError
    @test err.cause.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"
    @test "READ.DSS.GEOMETRY_UNRESOLVED" in getproperty.(err.reader_diagnostics, :code)
    @test Set(f.code for f in findings) ==
        Set(("READ.DSS.GEOMETRY_UNRESOLVED", "BUILD.DIST.ELECTRICAL_INCOMPLETE"))
    @test length(findings) == 2
    @test all(f -> f.detail["source_path"] == abspath(path), findings)
    @test all(f -> f.detail["conversion_stage"] == "emit", findings)
    @test all(f -> !isempty(f.detail["diagnostic_details"]), findings)
    evidence = dss_conversion_error_to_dict(err)
    @test JSON3.read(JSON3.write(evidence), Dict{String,Any}) == evidence
    @test evidence["upstream_error"]["code"] == err.cause.code
    @test evidence["upstream_error"]["message"] == err.cause.message
    @test occursin(repr(err.source_path), sprint(showerror, err))
    @test occursin(err.cause.code, sprint(showerror, err))
    @test length(evidence["reader_diagnostics"]) == length(err.reader_diagnostics)
    # Existing entries are preserved, and a new call appends one set of evidence.
    first_entry = first(findings)
    again = _dce_capture(() -> from_dss(path; findings))
    @test again isa DSSConversionError
    @test length(findings) == 4
    @test first(findings) === first_entry
    # Direct PowerIO use remains outside the package's wrapper.
    module_ = PowerIO.parse(path)
    upstream = _dce_capture(() -> PowerIO.emit(module_, "bmopf-json@0.1.0"))
    @test upstream isa PowerIO.PowerIOError
    @test upstream.code == err.cause.code
end

@testset "DSS failure evidence — cause identity, structured fields and snapshots" begin
    reader = _dce_diagnostic("READ.DSS.GEOMETRY_UNRESOLVED";
        severity=:warning, id="reader-1", target="/line/Feeder~1A",
        action="provide explicit impedance", related=["related-1"],
        spans=[PowerIO.SourceSpan("included.dss", UInt64(3), UInt64(19))],
        details=Dict{String,Any}("nested" => Dict("values" => [1, 2])))
    failed = _dce_diagnostic("BUILD.DIST.ELECTRICAL_INCOMPLETE";
        id="failure-1", target="line Feeder/A",
        details=Dict{String,Any}("reason" => "unresolved"))
    cause = PowerIO.PowerIOError(failed.code, "upstream failure", [failed])
    reader_input = [reader]
    findings = Finding[]
    err = _dce_capture(() -> BMOPFTools._with_dss_conversion_evidence(
        "relative-case.dss", :emit, reader_input; findings) do
            # Simulate a writer modifying source evidence before failing.
            push!(reader.details["nested"]["values"], 3)
            throw(cause)
        end)
    @test err isa DSSConversionError
    @test err.cause === cause
    @test err.cause.diagnostics === cause.diagnostics
    @test err.stage == :emit
    @test err.reader_diagnostics[1].details["nested"]["values"] == [1, 2]
    @test reader_input[1].details["nested"]["values"] == [1, 2, 3]
    data = dss_conversion_error_to_dict(err)
    raw = only(data["reader_diagnostics"])
    @test raw["code"] == reader.code
    @test raw["severity"] == "warning"
    @test raw["target"] == "/line/Feeder~1A"
    @test raw["id"] == "reader-1"
    @test raw["suggested_action"] == "provide explicit impedance"
    @test raw["related"] == ["related-1"]
    @test raw["spans"] == [Dict("source"=>"included.dss", "byte_start"=>3, "byte_end"=>19)]
    @test JSON3.read(JSON3.write(data), Dict{String,Any}) == data
    @test Set(f.component_id for f in findings) == Set(["Feeder/A"])
    @test Set(f.severity for f in findings) == Set([WARNING, ERROR])
    @test only(findings[1].detail["diagnostic_details"])["origin"] == "failure"
    # A serialized evidence consumer cannot mutate the retained diagnostics.
    push!(raw["details"]["nested"]["values"], 99)
    push!(raw["related"], "new")
    @test err.reader_diagnostics[1].details["nested"]["values"] == [1, 2]
    @test err.reader_diagnostics[1].related == ["related-1"]
    data["upstream_error"]["diagnostics"][1]["details"]["reason"] = "changed"
    @test cause.diagnostics[1].details["reason"] == "unresolved"
end

@testset "DSS failure evidence — absent context and folded diagnostic classes" begin
    # The message contains a component hint, but no structured locator exists.
    diagnostic = _dce_diagnostic("BUILD.DIST.ELECTRICAL_INCOMPLETE")
    cause = PowerIO.PowerIOError(diagnostic.code, "failure", [diagnostic])
    err = DSSConversionError("case.dss", :emit, cause, [diagnostic])
    fs = BMOPFTools._dss_failure_findings(err)
    @test length(fs) == 1
    @test only(fs).component_type == :network
    @test only(fs).component_id === nothing
    @test only(fs).detail["count"] == 2
    @test getindex.(only(fs).detail["diagnostic_details"], "origin") == ["reader", "failure"]
    # Each stage's upstream records remain verbatim in the serialized evidence.
    data = dss_conversion_error_to_dict(err)
    @test only(data["reader_diagnostics"])["target"] === nothing
    @test isempty(only(data["reader_diagnostics"])["spans"])
    @test only(data["reader_diagnostics"])["details"] === nothing
    @test length(data["reader_diagnostics"]) == 1
    @test length(data["upstream_error"]["diagnostics"]) == 1

    empty_cause = PowerIO.PowerIOError("BUILD.DIST.ELECTRICAL_INCOMPLETE", "failure", PowerIO.Diagnostic[])
    empty = DSSConversionError("case.dss", :emit, empty_cause)
    @test isempty(BMOPFTools._dss_failure_findings(empty))
    @test dss_conversion_error_to_dict(empty)["upstream_error"]["code"] == empty_cause.code
    @test isempty(dss_conversion_error_to_dict(empty)["reader_diagnostics"])
    @test isempty(dss_conversion_error_to_dict(empty)["upstream_error"]["diagnostics"])
    @test JSON3.read(JSON3.write(dss_conversion_error_to_dict(empty)), Dict{String,Any}) ==
        dss_conversion_error_to_dict(empty)
    @test_throws ArgumentError DSSConversionError("", :emit, cause)
    @test_throws ArgumentError DSSConversionError("case.dss", :unknown, cause)
end

@testset "DSS failure evidence — parse boundary and unrelated errors" begin
    # A real fatal reader failure: invalid UTF-8 cannot produce a reader module.
    mktempdir() do dir
        path = joinpath(dir, "Master.dss")
        write(path, UInt8[0xff, 0xfe])
        upstream = _dce_capture(() -> PowerIO.parse(path))
        @test upstream isa PowerIO.PowerIOError
        collected = Finding[]
        wrapped = _dce_capture(() -> from_dss(path; findings=collected))
        @test wrapped isa DSSConversionError
        @test wrapped.stage == :parse
        @test wrapped.source_path == abspath(path)
        @test wrapped.cause.code == upstream.code
        @test isempty(wrapped.reader_diagnostics)
        @test upstream.code in getproperty.(collected, :code)
        data = dss_conversion_error_to_dict(wrapped)
        @test data["upstream_error"]["code"] == upstream.code
        @test JSON3.read(JSON3.write(data), Dict{String,Any}) == data
    end
    diagnostic = _dce_diagnostic("PARSE.DSS.SOURCE_MALFORMED")
    cause = PowerIO.PowerIOError(diagnostic.code, "parse failure", [diagnostic])
    findings = Finding[]
    err = _dce_capture(() -> BMOPFTools._with_dss_conversion_evidence(
        () -> throw(cause), "case.dss", :parse; findings))
    @test err isa DSSConversionError
    @test err.cause === cause
    @test err.stage == :parse
    @test isempty(err.reader_diagnostics)
    @test only(findings).code == diagnostic.code
    @test only(findings).detail["conversion_stage"] == "parse"
    @test only(only(findings).detail["diagnostic_details"])["origin"] == "failure"

    existing = copy(findings)
    unrelated = ArgumentError("unrelated adapter defect")
    got = _dce_capture(() -> BMOPFTools._with_dss_conversion_evidence(
        () -> throw(unrelated), "case.dss", :emit, [diagnostic]; findings))
    @test got === unrelated
    @test findings == existing
    @test BMOPFTools._with_dss_conversion_evidence(
        () -> :success, "case.dss", :emit, [diagnostic]; findings) == :success
    @test findings == existing
    @test_throws ArgumentError from_dss(joinpath(@__DIR__, "missing-file.dss"); findings)
    @test findings == existing
end

@testset "DSS failure evidence — successful conversion keeps its diagnostic views" begin
    path = joinpath(@__DIR__, "data", "pf_comparison", "pf_1ph_line.dss")
    findings = Finding[]
    net = from_dss(path; findings)
    expected = powerio_findings(net)
    @test length(findings) == length(expected)
    @test getproperty.(findings, :code) == getproperty.(expected, :code)
    @test getproperty.(findings, :detail) == getproperty.(expected, :detail)
    @test haskey(net["_meta"], "powerio_diagnostic_details")
    io = IOBuffer()
    write_bmopf(net, io)
    restored = parse_bmopf(String(take!(io)); from_string=true)
    @test getproperty.(powerio_findings(restored), :code) == getproperty.(expected, :code)
end
