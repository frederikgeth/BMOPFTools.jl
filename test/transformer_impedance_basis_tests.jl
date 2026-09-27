using Test, BMOPFTools, JSON3

@testset "winding-local transformer leakage base" begin
    fixture = joinpath(@__DIR__, "fixtures", "delta_wye_secondary_leakage.json")
    net = parse_bmopf(fixture)
    transformer = net["transformer"]["delta_wye"]["tx"]
    zpu = BMOPFTools._xfmr_z_pu(transformer, "delta_wye")
    @test isapprox(zpu, 0.04; atol=1e-10)
    findings = Finding[]
    domain_rules_check(net, findings)
    @test !any(f -> f.code == "W.DOM.XFMR_LOW_IMPEDANCE", findings)

    disabled = (apply_largest_component=false, apply_simplify_network=false,
                apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
                apply_source_bus_bounds=false)
    fixed, manifest = fix_case(net; recipe=FixRecipe(; disabled...,
        apply_snap_transformer_impedance=true))
    @test fixed["transformer"]["delta_wye"]["tx"]["x_series_to"] == transformer["x_series_to"]
    @test !any(e -> e.rule == "snap_transformer_impedance", manifest.entries)

    tiny = deepcopy(net)
    tiny_tx = tiny["transformer"]["delta_wye"]["tx"]
    tiny_tx["r_series_to"] = 0.0
    tiny_tx["x_series_to"] = 1e-4
    @test 0 < BMOPFTools._xfmr_z_pu(tiny_tx, "delta_wye") < 1e-3
    tiny_findings = Finding[]
    domain_rules_check(tiny, tiny_findings)
    @test any(f -> f.code == "W.DOM.XFMR_LOW_IMPEDANCE", tiny_findings)
    snapped, snapped_manifest = fix_case(tiny; recipe=FixRecipe(; disabled...,
        apply_snap_transformer_impedance=true))
    @test snapped["transformer"]["delta_wye"]["tx"]["x_series_to"] == 0.0
    @test any(e -> e.rule == "snap_transformer_impedance", snapped_manifest.entries)

    threshold = deepcopy(net)
    threshold_tx = threshold["transformer"]["delta_wye"]["tx"]
    threshold_tx["r_series_to"] = 0.0
    threshold_tx["x_series_to"] = 0.001 * (400.0^2 / 100000.0)
    @test isapprox(BMOPFTools._xfmr_z_pu(threshold_tx, "delta_wye"), 0.001)
    boundary_findings = Finding[]
    domain_rules_check(threshold, boundary_findings)
    @test !any(f -> f.code == "W.DOM.XFMR_LOW_IMPEDANCE", boundary_findings)

    # The witness and its corrected diagnostic are stable through JSON.
    roundtrip = JSON3.read(JSON3.write(BMOPFTools._jsonable(
        Dict("z_pu" => zpu, "finding_codes" => [f.code for f in findings]))))
    @test isapprox(roundtrip.z_pu, 0.04; atol=1e-10)
    @test !("W.DOM.XFMR_LOW_IMPEDANCE" in roundtrip.finding_codes)
end
