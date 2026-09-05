# PowerIO BMOPF writer contracts consumed by BMOPFTools.

@testset "PowerIO BMOPF writer" begin
    @testset "pairable regulator legs merge into one open delta regulator" begin
        # OpenDSS represents an open delta regulator bank as two independent
        # single phase transformers. RegControl marks both as regulator legs;
        # PowerIO must pair them while writing BMOPF rather than leave this test
        # to a hand built BMOPF object that bypasses the writer.
        source = read(
            joinpath(@__DIR__, "data", "pf_comparison", "pf_open_delta_reg.dss"),
            String,
        ) * """

        New RegControl.rc1 Transformer=reg1
        New RegControl.rc2 Transformer=reg2
        """

        net = mktempdir() do dir
            path = joinpath(dir, "pairable_open_delta.dss")
            write(path, source)
            from_dss(path)
        end

        transformers = net["transformer"]
        @test Set(keys(transformers)) == Set(["open_delta_regulator"])
        regulator = only(values(transformers["open_delta_regulator"]))
        @test regulator["connection"] == "ABBC"
        @test regulator["tap_ratio"] == [1.05, 1.025]
        @test regulator["terminal_map_from"] == ["a", "b", "c"]
        @test regulator["terminal_map_to"] == ["a", "b", "c"]

        diagnostics = net["_meta"]["powerio_diagnostics"]
        merged = only(filter(
            d -> d["code"] == "EMIT.BMOPF.TRANSFORMER_OPEN_DELTA_MERGED",
            diagnostics,
        ))
        @test merged["component_type"] == "transformer"
        @test merged["component_id"] == "reg1"
    end
end

@testset "PowerIO 0.11 explicit profile and metadata audit" begin
    module_ = PowerIO.parse(joinpath(@__DIR__, "data", "pf_comparison", "pf_3ph_line.dss"))
    audit = BMOPFTools._powerio_audit_input(module_)
    @test audit.network isa PowerIO.MulticonductorNetwork
    @test audit.data.loads[1].extras isa AbstractDict
    emitted = PowerIO.emit(module_, "bmopf-json@0.1.0")
    parsed = parse_bmopf(emitted.text; from_string=true)
    @test BMOPFTools._detect_spec_version(parsed) == BMOPFTools._CURRENT_SPEC
    invalid = deepcopy(parsed)
    invalid["meta"]["\$schema"] = "https://example.invalid/unknown-schema"
    @test_throws ArgumentError BMOPFTools.migrate(invalid)
end

@testset "Complete transformer relocation preserves conflicts" begin
    existing = Dict{String,Any}("tap_ratio" => [1.0, 1.0])
    retained = Dict{String,Any}("tap_ratio" => [1.05, 1.025])
    net = Dict{String,Any}(
        "transformer" => Dict("open_delta_regulator" => Dict("a" => existing)),
        "extras" => Dict("transformer" => Dict("open_delta_regulator" =>
            Dict("a" => retained, "b" => deepcopy(retained)))),
    )
    BMOPFTools._fold_transformer_extras!(net)
    @test net["transformer"]["open_delta_regulator"]["a"] == existing
    @test net["transformer"]["open_delta_regulator"]["b"] == retained
    @test net["extras"]["transformer"]["open_delta_regulator"] == Dict("a" => retained)
    @test only(net["_meta"]["migration_notes"])["id"] == "b"
    BMOPFTools._fold_transformer_extras!(net)
    @test length(net["_meta"]["migration_notes"]) == 1
end

@testset "PowerIO aggregate attribution is bounded and retained" begin
    source_path = joinpath(@__DIR__, "data", "pf_comparison", "pf_delta_load.dss")
    net = from_dss(source_path)
    module_ = PowerIO.parse(source_path)
    audit = BMOPFTools._powerio_audit_input(module_)
    details = Dict{String,Any}("field" => "kv", "elements" => ["load d12"], "count" => 2,
        "elements_truncated" => true)
    diagnostic = (code="EMIT.BMOPF.FIELD_DROPPED", details=details)
    net["_meta"]["powerio_warnings"] = ["EMIT.BMOPF.FIELD_DROPPED: aggregate"]
    mapping = BMOPFTools._powerio_bmopf_field_mapping(audit, net; diagnostics=[diagnostic])
    @test mapping["warnings_truncated_upstream"]
    @test mapping["warning_status"] == "truncated_upstream"
    @test "kv" in mapping["blocking_unmapped_fields"]
    @test "unknown:unattributed" in mapping["by_field"]["kv"]["unmapped_scopes"]
    details["count"] = 1
    delete!(details, "elements_truncated")
    complete = BMOPFTools._powerio_bmopf_field_mapping(audit, net; diagnostics=[diagnostic])
    @test complete["warning_status"] == "parsed"
    @test "kv" ∉ complete["blocking_unmapped_fields"]
    path = joinpath(mktempdir(), "diagnostics.json")
    original = from_dss(source_path)
    write_bmopf(original, path)
    @test parse_bmopf(path)["_meta"]["powerio_diagnostic_details"] ==
        original["_meta"]["powerio_diagnostic_details"]
end

@testset "Explicit transformer core shunts preserve their physical winding" begin
    for winding in 1:2
        source = Dict{String,Any}(
            "bus" => Dict("h" => Dict("terminal_names" => ["a", "n"]),
                          "l" => Dict("terminal_names" => ["a", "n"])),
            "transformer" => Dict("single_phase" => Dict("t" => Dict(
                "bus_from" => "h", "bus_to" => "l",
                "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
                "s_rating" => 25000.0, "v_nom_from" => 7200.0, "v_nom_to" => 240.0,
                "r_series_from" => 1.0, "x_series_from" => 2.0,
                "no_load_shunt" => Dict("winding" => winding, "g" => 0.001, "b" => -0.002))))
        )
        net = parse_bmopf(BMOPFTools.JSON3.write(source); from_string=true)
        shunt = only(values(net["shunt"]))
        @test shunt["bus"] == (winding == 1 ? "h" : "l")
        @test shunt["terminal_map"] == ["a", "n"]
        nodes, admittance = BMOPFTools._shunt_yprim(shunt)
        @test admittance ≈ (0.001 - 0.002im) .* [1 -1; -1 1]
        voltage = ComplexF64[245 + 3im, 5 + 3im]
        power = sum(voltage .* conj.(admittance * voltage))
        @test real(power) ≈ 57.6
        @test imag(power) ≈ 115.2
        @test !haskey(net["transformer"]["single_phase"]["t"], "no_load_shunt")
        @test net["_meta"]["explicit_transformer_core_shunts"]["single_phase/t"]["source"] == source["transformer"]["single_phase"]["t"]["no_load_shunt"]
        reparsed = BMOPFTools._postprocess(deepcopy(net))
        @test length(reparsed["shunt"]) == 1
        bad = deepcopy(source)
        bad["transformer"]["single_phase"]["t"]["no_load_shunt"]["winding"] = 3
        @test_throws ArgumentError parse_bmopf(BMOPFTools.JSON3.write(bad); from_string=true)
        bad = deepcopy(source)
        bad["transformer"]["single_phase"]["t"]["g_no_load"] = 0
        @test_throws ArgumentError parse_bmopf(BMOPFTools.JSON3.write(bad); from_string=true)
    end
end


@testset "Explicit core shunt conductor incidence" begin
    cases = [
        ("wye_delta", 2, ["a", "b", "c"], [2 -1 -1; -1 2 -1; -1 -1 2]),
        ("delta_wye", 2, ["a", "b", "c", "return"], [1 0 0 -1; 0 1 0 -1; 0 0 1 -1; -1 -1 -1 3]),
        ("single_phase", 2, ["a", "b"], [1 -1; -1 1]),
        ("center_tap", 3, ["a", "return", "b"], [0 0 0; 0 1 -1; 0 -1 1]),
    ]
    for (subtype, winding, terminals, incidence) in cases
        transformer = Dict{String,Any}("bus_from" => "h", "bus_to" => "l",
            "terminal_map_from" => ["a", "n"], "terminal_map_to" => terminals,
            "no_load_shunt" => Dict("winding" => winding, "g" => 0.001, "b" => -0.002))
        net = Dict{String,Any}("bus" => Dict("h" => Dict("terminal_names" => ["a", "n"]),
            "l" => Dict("terminal_names" => terminals, "neutral_terminal" => "return")),
            "transformer" => Dict(subtype => Dict("t" => transformer)))
        BMOPFTools._materialize_transformer_core_shunts!(net)
        shunt = only(values(net["shunt"]))
        _, matrix = BMOPFTools._shunt_yprim(shunt)
        @test shunt["bus"] == "l"
        order = [findfirst(==(terminal), terminals) for terminal in shunt["terminal_map"]]
        @test matrix ≈ (0.001 - 0.002im) .* incidence[order, order]
        @test maximum(abs.(sum(matrix, dims=1))) < 1e-12
        if "return" in terminals
            @test last(shunt["terminal_map"]) == "return"
        end
    end
    transformer = Dict{String,Any}("windings" => [Dict("bus" => "bus$i", "terminal_map" => ["a", "n"], "configuration" => "WYE") for i in 1:4],
        "no_load_shunt" => Dict("winding" => 4, "g" => 0.001, "b" => 0))
    net = Dict{String,Any}("transformer" => Dict("n_winding" => Dict("t" => transformer)))
    BMOPFTools._materialize_transformer_core_shunts!(net)
    shunt = only(values(net["shunt"]))
    @test shunt["bus"] == "bus4"
    @test BMOPFTools._shunt_yprim(shunt)[2] ≈ 0.001 .* [1 -1; -1 1]
end
