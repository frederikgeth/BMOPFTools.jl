# Explicit metallic neutral continuity is retained under PSK-000002.
# This static acceptance does not establish grounding assets or installed state.
using Test, BMOPFTools, JSON3

@testset "Neutral-only terminal-map branches" begin
    witness = joinpath(@__DIR__, "data", "neutral_only_link.json")
    base() = BMOPFTools.parse_bmopf(witness)
    function findings(net)
        out = BMOPFTools.Finding[]
        BMOPFTools.spec_conformance_check(net, out)
        out
    end
    code = "E.TMAP.PHASE_TO_NEUTRAL"
    net = base()
    @test !any(f.code == code for f in findings(net))
    @test net["line"]["neutral_link"]["terminal_map_from"] == ["4"]

    @testset "Neutral-only switch and serialization" begin
        net = base()
        net["switch"] = Dict{String,Any}("neutral_switch" => Dict{String,Any}(
            "bus_from"=>"a", "bus_to"=>"b", "terminal_map_from"=>["4"],
            "terminal_map_to"=>["4"], "state"=>"closed"))
        @test !any(f.code == code for f in findings(net))
        roundtrip = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)
        @test roundtrip["switch"]["neutral_switch"]["terminal_map_to"] == ["4"]
        @test !any(f.code == code for f in findings(roundtrip))
    end

    @testset "Asymmetric and duplicate neutral maps remain invalid" begin
        for kind in ("line", "switch")
            net = base()
            if kind == "switch"
                net["switch"] = Dict{String,Any}("bad" => deepcopy(net["line"]["neutral_link"]))
                branch = net["switch"]["bad"]
            else
                branch = net["line"]["neutral_link"]
            end
            branch["terminal_map_to"] = ["1"]
            out = findings(net)
            @test any(f.code == code && string(f.component_type) == kind for f in out)
            @test any(f.code == "I.TMAP.CROSS_PHASE_LINE" && string(f.component_type) == kind for f in out)
        end
        net = base()
        for key in ("terminal_map_from", "terminal_map_to")
            net["line"]["neutral_link"][key] = ["4", "4"]
        end
        @test any(f.code == code && f.component_id == "neutral_link" for f in findings(net))
    end

    @testset "Nodal phase-to-neutral mistakes remain invalid" begin
        for (configuration, terminals) in (("SINGLE_PHASE",["4"]),
                                           ("DELTA",["1","4","3"]),
                                           ("WYE",["1","4","3","4"]))
            net = base();net["load"]["customer"]["configuration"] = configuration
            net["load"]["customer"]["terminal_map"] = terminals
            @test any(f.code == code && f.component_id == "customer" for f in findings(net))
        end
    end
end
