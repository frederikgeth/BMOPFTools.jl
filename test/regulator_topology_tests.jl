using Test
using BMOPFTools
const _M = BMOPFTools

# ---------------------------------------------------------------------------
# Regulator subtypes and topology graphs.
#
# Autotransformers and open-delta regulators are NOT galvanic separations, so
# they must keep their two buses in one galvanic zone/island — unlike the
# isolating transformer subtypes. The *neutral*-continuity graph is a separate
# question: the line-to-neutral single_phase_autotransformer shares one physical
# neutral bushing (the OPF bonds V_fr_n == V_to_n) and so carries the neutral
# through, whereas the line-to-line open_delta_regulator leaves its neutral
# terminal unused and does NOT. These tests lock in that asymmetry.
# ---------------------------------------------------------------------------

@testset "Regulator topology — galvanic & neutral continuity" begin
    D(x...) = Dict{String,Any}(x...)

    # src --(device)--> reg --(line carrying "n")--> dn ; a load on dn uses "n".
    # Only src's neutral is grounded, so a section that fails to reach src via the
    # neutral graph is floating (and ERROR-level, because the load uses it).
    function build(subtype; tmfr, tmto, extra=D())
        D(
          "bus" => D(
            "src" => D("terminal_names" => ["1","2","3","n"],
                       "perfectly_grounded_terminals" => ["n"]),
            "reg" => D("terminal_names" => ["1","2","3","n"]),
            "dn"  => D("terminal_names" => ["1","2","3","n"]),
          ),
          "line" => D("l1" => D("bus_from" => "reg", "bus_to" => "dn",
                       "terminal_map_from" => ["1","2","3","n"],
                       "terminal_map_to"   => ["1","2","3","n"])),
          "load" => D("ld" => D("bus" => "dn", "terminal_map" => ["1","n"],
                       "configuration" => "SINGLE_PHASE",
                       "p_nom" => [1000.0], "q_nom" => [0.0])),
          "transformer" => D(subtype => D("r1" => merge(D(
                       "bus_from" => "src", "bus_to" => "reg",
                       "terminal_map_from" => tmfr,
                       "terminal_map_to"   => tmto), extra))),
        )
    end

    auto_ln() = build("single_phase_autotransformer";
        tmfr = ["1","n"], tmto = ["1","n"],
        extra = D("tap_ratio" => 1.05, "regulator_type" => "B",
                  "r_series_from" => 0.5, "x_series_from" => 2.0))
    auto_ll() = build("single_phase_autotransformer";   # line-to-line: no neutral
        tmfr = ["1","2"], tmto = ["1","2"],
        extra = D("tap_ratio" => 1.05, "regulator_type" => "B",
                  "r_series_from" => 0.5, "x_series_from" => 2.0))
    opendelta() = build("open_delta_regulator";
        tmfr = ["1","2","3","n"], tmto = ["1","2","3","n"],
        extra = D("connection" => "ABBC", "tap_ratio" => [1.05, 1.025],
                  "regulator_type" => "B",
                  "r_series_from" => 0.5, "x_series_from" => 2.0))
    isolating() = build("single_phase";                 # true galvanic separation
        tmfr = ["1","n"], tmto = ["1","n"],
        extra = D("v_ref_from" => 2400.0, "v_ref_to" => 240.0, "s_rating" => 1e5,
                  "r_series_from" => 0.5, "x_series_from" => 2.0))

    zones(net)    = Set(Set.(_M._galvanic_zones(net)))
    nislands(net) = (f = Finding[]; integrity_check(net, f)["n_galvanic_islands"])
    function neutral(net)
        f = Finding[]
        g = provenance_analysis(net, f)["grounding"]
        codes = [x.code for x in f if occursin("FLOATING_NEUTRAL", x.code)]
        (g["n_floating"], codes)
    end

    @testset "galvanic zones" begin
        merged = Set([Set(["src","reg","dn"])])
        @test zones(auto_ln())   == merged
        @test zones(opendelta()) == merged
        @test zones(auto_ll())   == merged   # galvanically continuous even L-L
        # the isolating single_phase splits the source bus off from the rest
        @test zones(isolating()) == Set([Set(["src"]), Set(["reg","dn"])])
    end

    @testset "galvanic island count (integrity)" begin
        @test nislands(auto_ln())   == 1
        @test nislands(opendelta()) == 1
        @test nislands(auto_ll())   == 1
        @test nislands(isolating()) == 2
    end

    @testset "neutral continuity" begin
        # L-N autotransformer bonds the neutrals → downstream reaches source ground
        nf, codes = neutral(auto_ln())
        @test nf == 0
        @test isempty(codes)

        # open-delta is line-to-line: its neutral terminal is unused → downstream floats
        nf, codes = neutral(opendelta())
        @test nf == 1
        @test "E.PROV.FLOATING_NEUTRAL" in codes

        # L-L autotransformer references no neutral → not a neutral branch
        nf, codes = neutral(auto_ll())
        @test nf == 1
        @test "E.PROV.FLOATING_NEUTRAL" in codes

        # an isolating transformer never carries the neutral through
        nf, codes = neutral(isolating())
        @test nf == 1
        @test "E.PROV.FLOATING_NEUTRAL" in codes
    end
end
