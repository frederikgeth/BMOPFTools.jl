using Test, BMOPFTools, JuMP, JSON3

@testset "winding coverage matches built constraint families without solving" begin
    for configuration in ("WYE", "DELTA"), pu in (false, true), capkind in ("none", "i_max", "s_max", "both", "zero")
        tm = configuration == "WYE" ? ["a","b","c","n"] : ["a","b","c"]
        net = Dict{String,Any}("bus" => Dict(b => Dict("terminal_names" => tm) for b in ("f","t")),
            "transformer" => Dict("n_winding" => Dict("tx" => Dict{String,Any}(
                "s_rating" => 10000.0, "x_sc" => Dict("1_2" => 0.1),
                "windings" => [Dict{String,Any}("bus"=>b, "terminal_map"=>tm, "v_nom"=>v,
                    "configuration"=>configuration, "r_winding"=>0.01) for (b,v) in (("f",240.0),("t",120.0))]))))
        ws = net["transformer"]["n_winding"]["tx"]["windings"]
        for w in ws
            capkind in ("i_max", "both", "zero") && (w["i_max"] = capkind == "zero" ? 0.0 : 17.0)
            capkind in ("s_max", "both", "zero") && (w["s_max"] = capkind == "zero" ? 0.0 : 9000.0)
        end
        coverage = BMOPFTools._winding_limit_coverage(net, Finding[])
        ctx = build_opf_model(net; optimizer=nothing, model=JuMP.Model(), per_unit=pu)
        keys = opf_object_keys(ctx)
        for (field, family) in (("i_max", :nwind_current_thermal), ("s_max", :nwind_apparent_power_circle))
            expected = coverage["limit_counts"][field]["present"] == 2
            actual = Set(k for k in keys if k.family == family)
            @test length(actual) == (expected ? 6 : 0)
            for winding in 1:2, phase in 1:3
                @test (OpfModelKey(:constraint, family, ("tx", winding, phase)) in actual) == expected
            end
        end
        if capkind in ("s_max", "both", "zero")
            for winding in 1:2, phase in 1:3
                declared = ctx.net["transformer"]["n_winding"]["tx"]["windings"][winding]["s_max"]
                @test ctx.vars[:s_coil_xf][("tx",winding,phase)][3] ≈ declared/3
            end
        end
        @test all(r -> r["direct_neutral_current"] == (configuration == "WYE" ? "unsupported" : "inapplicable"), coverage["windings"])
    end
end

@testset "malformed winding caps retain native validation ownership" begin
    base = JSON3.read(read(joinpath(@__DIR__,"data","profiler_evidence","two_boundary_chain.json"),String),Dict{String,Any})
    for field in ("i_max","s_max"), value in (-1.0, NaN, [1.0], "1.0")
        net = deepcopy(base)
        net["transformer"]["n_winding"]["left"]["windings"][1][field] = value
        evidence = BMOPFTools._winding_limit_coverage(net, Finding[])
        @test evidence["windings"][1]["limits"][field]["supported"] === false
        @test_throws ArgumentError build_opf_model(net; optimizer=nothing, model=JuMP.Model(), per_unit=false)
    end
end
