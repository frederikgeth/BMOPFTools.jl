# test/write_bmopf_tests.jl
#
# Syntactic validity tests for write_bmopf:
#   - output is parseable JSON (bytes → JSON3.read succeeds)
#   - default output is pretty-printed (multi-line, indented)
#   - indent=nothing produces compact output
#   - _meta is never serialised
#   - no NaN or Inf values in output (JSON does not support these)
#   - round-trip preserves all top-level keys

using JSON3

# Walk any nested structure and return true iff all Float64 values are finite.
function _all_finite(v)
    v isa Float64        && return isfinite(v)
    v isa AbstractDict   && return all(_all_finite(val) for val in values(v))
    v isa AbstractVector && return all(_all_finite(x)   for x in v)
    true
end

@testset "IO — write_bmopf JSON validity" begin
    net = parse_bmopf(IEEE13_FIXTURE; from_string=true)

    @testset "file output is parseable JSON" begin
        path = tempname() * ".json"
        try
            write_bmopf(net, path)
            @test isfile(path)
            raw    = read(path, String)
            parsed = JSON3.read(raw)
            @test !isnothing(parsed)
            @test haskey(parsed, "name")
            @test haskey(parsed, "bus")
            @test haskey(parsed, "meta")
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "IOBuffer output is parseable JSON" begin
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw    = String(take!(buf))
        parsed = JSON3.read(raw)
        @test haskey(parsed, "bus")
        @test length(parsed["bus"]) == 7
        @test haskey(parsed, "line")
        @test length(parsed["line"]) == 4
    end

    @testset "default output is multi-line" begin
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw = String(take!(buf))
        # JSON3.pretty with default 4-space indent produces many newlines.
        @test count('\n', raw) > 20
        lines = split(raw, '\n')
        # At least some lines start with whitespace (indented keys/values).
        @test any(l -> startswith(l, "    "), lines)
    end

    @testset "indent=nothing produces compact single-line output" begin
        buf = IOBuffer()
        write_bmopf(net, buf; indent=nothing)
        raw = String(take!(buf))
        # JSON3 compact mode writes no internal newlines.
        @test count('\n', raw) == 0
    end

    @testset "_meta is never serialised" begin
        net2 = deepcopy(net)
        net2["_meta"] = Dict{String,Any}("tool_private" => "yes")
        buf = IOBuffer()
        write_bmopf(net2, buf)
        raw = String(take!(buf))
        @test !occursin("\"_meta\"",      raw)
        @test !occursin("tool_private",   raw)
    end

    @testset "all top-level keys are present after round-trip" begin
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw  = String(take!(buf))
        net2 = parse_bmopf(raw; from_string=true)
        for k in keys(net)
            k == "_meta" && continue   # tool-private, intentionally dropped
            @test haskey(net2, k)
        end
    end

    @testset "no NaN or Inf in output" begin
        # JSON3 throws if a NaN/Inf reaches the serialiser; a successful
        # write_bmopf call therefore proves the dict was finite. We also
        # verify the parsed-back tree contains only finite floats.
        buf = IOBuffer()
        @test_nowarn write_bmopf(net, buf)
        raw    = String(take!(buf))
        parsed = JSON3.read(raw, Dict{String,Any})
        @test _all_finite(parsed)
        # Belt-and-suspenders: the literal tokens must not appear.
        @test !occursin("NaN",      raw)
        @test !occursin("Infinity", raw)
    end

    @testset "meta block always present and well-formed" begin
        buf = IOBuffer()
        write_bmopf(net, buf)
        raw    = String(take!(buf))
        parsed = JSON3.read(raw)
        meta   = parsed["meta"]
        @test haskey(meta, "\$schema")
        @test haskey(meta, "generator")
        @test haskey(meta, "created")
        @test meta["generator"]["tool"] == "BMOPFTools.jl"
    end

    # ── write_result / read_result round-trip ─────────────────────────────────
    @testset "write_result / read_result round-trip" begin
        # A solver-shaped result dict mirroring the network structure.
        result = Dict{String,Any}(
            "termination_status" => "LOCALLY_SOLVED",
            "objective"          => 1234.5,
            "solve_time"         => 0.42,
            "bus" => Dict{String,Any}("b1" => Dict{String,Any}(
                "1" => Dict{String,Any}("vr"=>230.4,"vi"=>0.0,"vm"=>230.4,"va"=>0.0))),
            "losses" => Dict{String,Any}("p_loss"=>750.0,"q_loss"=>-10.0),
        )

        # File round-trip preserves the nested structure exactly.
        path = tempname() * ".json"
        try
            write_result(result, path)
            @test isfile(path)
            back = read_result(path)
            @test back == result
            @test back["bus"]["b1"]["1"]["vm"] == 230.4
        finally
            isfile(path) && rm(path)
        end

        # String round-trip via from_string.
        io = IOBuffer(); write_result(result, io)
        @test read_result(String(take!(io)); from_string=true) == result

        # Compact (indent=nothing) output is single-line and still round-trips.
        io2 = IOBuffer(); write_result(result, io2; indent=nothing)
        compact = String(take!(io2))
        @test !occursin('\n', strip(compact))
        @test read_result(compact; from_string=true) == result

        # Infeasible results carry NaN; write_result must not choke and the NaN
        # must round-trip back as NaN (JSON3 allow_inf).
        infres = Dict{String,Any}(
            "termination_status" => "INFEASIBLE",
            "objective"          => NaN,
            "solve_time"         => 0.1,
            "bus" => Dict{String,Any}("b1" => Dict{String,Any}(
                "1" => Dict{String,Any}("vm"=>NaN))))
        io3 = IOBuffer(); write_result(infres, io3)
        nb = read_result(String(take!(io3)); from_string=true)
        @test nb["termination_status"] == "INFEASIBLE"
        @test isnan(nb["objective"])
        @test isnan(nb["bus"]["b1"]["1"]["vm"])
    end
end
