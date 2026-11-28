# Bus-level neutral resolution under declared terminal roles (#494).
#
# When a case declares `terminal_conventions`, a conductor declared as a phase is
# never the bus neutral because of its name. Ingest stamps every bus with its
# declared neutral, or with `nothing` when it has none, and every bus-level lookup
# (`_neutral_terminal(bus)`) honors that. Entry points that accept a network that
# did not pass through `parse_bmopf` resolve the same way on a copy.
#
# Included from runtests.jl inside the JuMP/Ipopt-gated block.

@testset "Declared terminal roles decide the bus neutral (#494)" begin
    D = Dict{String,Any}

    # Two-conductor feeder whose second conductor is *named* "n". `declared`
    # selects whether the case declares it a phase, declares it the neutral, or
    # declares nothing (roles inferred from names).
    function feeder(declared::Symbol)
        net = D(
            "name" => "declared_neutral",
            "bus" => D(
                "src" => D("terminal_names" => ["a", "n"]),
                "load" => D("terminal_names" => ["a", "n"],
                            "v_min" => [200.0, 200.0], "v_max" => [260.0, 260.0],
                            "vn_max" => 50.0,
                            "vpn_min" => [200.0], "vpn_max" => [260.0],
                            "vpp_max" => [460.0])),
            "voltage_source" => D("vs" => D(
                "bus" => "src", "terminal_map" => ["a", "n"],
                "v_magnitude" => [230.0, 230.0], "v_angle" => [0.0, -2pi / 3])),
            "linecode" => D("lc" => D(
                "R_series_1_1" => 0.01, "X_series_1_1" => 0.005,
                "R_series_2_2" => 0.01, "X_series_2_2" => 0.005)),
            "line" => D("l1" => D(
                "bus_from" => "src", "bus_to" => "load",
                "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
                "linecode" => "lc", "length" => 1.0)),
            "load" => D("ld" => D(
                "bus" => "load", "terminal_map" => ["a", "n"],
                "configuration" => "DELTA",
                "p_nom" => [5000.0], "q_nom" => [1000.0])))
        if declared === :phase
            net["terminal_conventions"] = D("phase" => ["a", "n"], "neutral" => String[])
        elseif declared === :neutral
            # "n" is the neutral: give it a ground and turn the load into a
            # phase-to-neutral unit so the case stays well formed.
            net["terminal_conventions"] = D("phase" => ["a"], "neutral" => ["n"])
        end
        if declared !== :phase
            net["bus"]["src"]["perfectly_grounded_terminals"] = ["n"]
            net["voltage_source"]["vs"]["terminal_map"] = ["a"]
            net["voltage_source"]["vs"]["v_magnitude"] = [230.0]
            net["voltage_source"]["vs"]["v_angle"] = [0.0]
            net["load"]["ld"]["configuration"] = "WYE"
            net["bus"]["load"]["v_min"] = [200.0]
            net["bus"]["load"]["v_max"] = [260.0]
            delete!(net["bus"]["load"], "vpp_max")
        end
        net
    end
    parsed(declared) = parse_bmopf(BMOPFTools.JSON3.write(feeder(declared)); from_string=true)

    @testset "ingest stamps declared neutrals and declared absence" begin
        net = parsed(:phase)
        for bid in ("src", "load")
            bus = net["bus"][bid]
            @test haskey(bus, "neutral_terminal")
            @test bus["neutral_terminal"] === nothing
            @test BMOPFTools._neutral_terminal(bus) === nothing
            @test BMOPFTools._declared_bus_neutral(BMOPFTools._terminal_roles(net), bus) === nothing
        end
        neutral = parsed(:neutral)
        @test BMOPFTools._neutral_terminal(neutral["bus"]["load"]) == "n"
        # Without a declaration the naming convention still applies, and nothing
        # is stamped.
        inferred = parsed(:inferred)
        @test !haskey(inferred["bus"]["load"], "neutral_terminal")
        @test BMOPFTools._neutral_terminal(inferred["bus"]["load"]) == "n"
    end

    @testset "hand-built networks resolve the same way without mutation" begin
        raw = feeder(:phase)
        view = BMOPFTools._with_materialized_roles(raw)
        @test view !== raw
        @test BMOPFTools._neutral_terminal(view["bus"]["load"]) === nothing
        @test !haskey(raw["bus"]["load"], "neutral_terminal")          # input untouched
        @test BMOPFTools._with_materialized_roles(feeder(:inferred)) isa Dict
        # The "no neutral" marker is derived: a parsed case edited afterwards to
        # declare a neutral resolves it, rather than keeping the stale marker.
        edited = parsed(:phase)
        edited["terminal_conventions"] = D("phase" => ["a"], "neutral" => ["n"])
        @test edited["bus"]["load"]["neutral_terminal"] === nothing        # stale
        @test BMOPFTools._neutral_terminal(
            BMOPFTools._with_materialized_roles(edited)["bus"]["load"]) == "n"
        # A malformed declaration is left for validation to report.
        bad = feeder(:phase); bad["terminal_conventions"]["neutral"] = "n"
        @test BMOPFTools._with_materialized_roles(bad) === bad
    end

    @testset "serialization strips the derived marker and re-derives it" begin
        net = parsed(:phase)
        text = sprint(io -> write_bmopf(net, io))
        @test !occursin("neutral_terminal", text)
        again = parse_bmopf(text; from_string=true)
        @test haskey(again["bus"]["load"], "neutral_terminal")
        @test again["bus"]["load"]["neutral_terminal"] === nothing
    end

    keys_of(net) = Set(BMOPFTools.opf_object_keys(
        build_opf_model(net; add_objective=false); kind=:constraint))
    has_family(ks, family) = any(k -> k.family === family, ks)

    @testset "OPF bus limits treat a declared phase named n as a phase" begin
        for net in (parsed(:phase), feeder(:phase))     # parsed and hand-built
            ks = keys_of(net)
            # Two phases, no neutral: no neutral cap and no phase-to-neutral
            # limits; one phase pair (a, n) carries the phase-to-phase limit.
            @test !has_family(ks, :bus_neutral_voltage_upper)
            @test !has_family(ks, :bus_vpn_lower)
            @test !has_family(ks, :bus_vpn_upper)
            @test OpfModelKey(:constraint, :bus_vpp_upper, ("load", 1)) in ks
            @test OpfModelKey(:constraint, :bus_voltage_upper, ("load", 2)) in ks
        end
        # Declared neutral: the same names now mean a phase and its neutral.
        ks = keys_of(parsed(:neutral))
        @test OpfModelKey(:constraint, :bus_neutral_voltage_upper, ("load", "n")) in ks
        @test OpfModelKey(:constraint, :bus_vpn_lower, ("load", 1)) in ks
        @test !has_family(ks, :bus_vpp_upper)
    end

    @testset "the declared-phase case solves and verifies" begin
        opt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
        for net in (parsed(:phase), feeder(:phase))
            r = solve_opf(net; optimizer=opt)
            @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            # "n" is a phase at about 230 V, not a 0 V neutral.
            @test r["bus"]["load"]["n"]["vm"] > 200.0
            report = profile_solution(net, r)
            @test isempty(errors(report))
        end
    end
end
