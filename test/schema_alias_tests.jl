using Test, BMOPFTools, JSON3, TOML

@testset "Reviewed PowerIO schema alias" begin
    fixture = joinpath(@__DIR__, "data", "schema_alias", "powerio_archive.json")
    raw = JSON3.read(read(fixture, String), Dict{String,Any})
    uri = raw["meta"]["\$schema"]
    snapshot = TOML.parsefile(joinpath(@__DIR__, "..", "schemas", "bundled-schema.toml"))
    @test only(snapshot["accepted_archive"])["uri"] == uri
    net = parse_bmopf(fixture)
    @test net["meta"]["\$schema"] == uri
    @test net["load"]["l"]["model"] == "constant_power"
    findings = Finding[]
    checked = schema_check(net, findings)
    @test checked["jsonschema_ran"]
    @test checked["jsonschema_valid"]
    @test !any(f -> f.code == "I.SCHEMA.VERSION_UNKNOWN", findings)

    # Recognizing a URI must not bypass structural validation.
    invalid = deepcopy(net)
    delete!(invalid, "voltage_source")
    findings = Finding[]
    @test !schema_check(invalid, findings)["jsonschema_valid"]
    @test any(f -> f.code == "E.SCHEMA.REQUIRED", findings)

    # A changed archive revision, another profile, or an embellished URL needs
    # its own review; no prefix/version wildcard is accepted.
    for unknown in (
        replace(uri, "5234df55cd13ad31455697cffbdc16ca50662667" => repeat("0", 40)),
        replace(uri, "5234df55cd13ad31455697cffbdc16ca50662667" => "main"),
        replace(uri, "/0.1.0/" => "/0.2.0/"),
        uri * "?revision=other",
    )
        candidate = deepcopy(raw)
        candidate["meta"]["\$schema"] = unknown
        @test_throws ArgumentError parse_bmopf(JSON3.write(candidate); from_string=true)
    end

    io = IOBuffer()
    write_bmopf(net, io)
    restored = parse_bmopf(String(take!(io)); from_string=true)
    @test restored["meta"]["\$schema"] == uri
    @test restored["load"] == net["load"]
    @test restored["voltage_source"] == net["voltage_source"]
    @test schema_check(restored, Finding[])["jsonschema_valid"]

    # Exercise the installed converter as well as the frozen historical URI.
    live = from_dss(joinpath(@__DIR__, "data", "pf_comparison", "pf_1ph_line.dss"))
    @test schema_check(live, Finding[])["jsonschema_ran"]
end
