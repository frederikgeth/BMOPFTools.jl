using Test, BMOPFTools, JSON3

@testset "transformer downstream-load applicability" begin
    fixture = joinpath(@__DIR__, "fixtures", "parallel_transformer_load.json")
    net = parse_bmopf(fixture)
    findings = Finding[]
    result = operational_analysis(net, findings)
    @test length(result["transformer_utilisation"]) == 2
    @test all(u -> u["estimate_status"] == "upper_bound", result["transformer_utilisation"])
    @test all(u -> u["utilisation_pct"] == 100.0, result["transformer_utilisation"])
    @test !any(f -> f.code == "W.OPS.XFMR_OVERLOADED", findings)

    bridge = deepcopy(net)
    delete!(bridge["transformer"]["single_phase"], "t2")
    bridge_findings = Finding[]
    bridge_result = operational_analysis(bridge, bridge_findings)
    @test only(bridge_result["transformer_utilisation"])["estimate_status"] == "radial_component"
    @test only(filter(f -> f.code == "W.OPS.XFMR_OVERLOADED", bridge_findings)).component_id == "t1"

    bridge["load"]["load"]["p_nom"] = [90.0]
    boundary_findings = Finding[]
    operational_analysis(bridge, boundary_findings)
    @test !any(f -> f.code == "W.OPS.XFMR_OVERLOADED", boundary_findings)
    decoded = JSON3.read(JSON3.write(BMOPFTools._jsonable(result)))
    @test all(u -> u.estimate_status == "upper_bound", decoded.transformer_utilisation)

    # The alternate transformer path can also make one LV endpoint appear
    # closer to a source by hop count. That is not evidence of reversed wiring.
    oriented_mesh = deepcopy(net)
    oriented_mesh["bus"]["mv1"] = Dict{String,Any}("terminal_names" => ["1", "n"])
    oriented_mesh["bus"]["mv2"] = Dict{String,Any}("terminal_names" => ["1", "n"])
    oriented_mesh["line"] = Dict{String,Any}(
        "m1" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "mv1"),
        "m2" => Dict{String,Any}("bus_from" => "mv1", "bus_to" => "mv2"))
    oriented_mesh["transformer"]["single_phase"]["t2"]["bus_from"] = "mv2"
    orientation_findings = Finding[]
    domain_rules_check(oriented_mesh, orientation_findings)
    @test !any(f -> f.code in ("W.DOM.XFMR_REVERSED", "W.DOM.XFMR_STEP_UP") &&
                   f.component_id == "t2", orientation_findings)
end
