# infeasibility_tests.jl
#
# Coverage for diagnose_infeasibility — interprets a solve_feasibility_opf
# result and ranks/classifies infeasible buses.
#
# Most paths are exercised deterministically by feeding hand-built result dicts
# (no solver needed). A final gated test wires it to a real solve_feasibility_opf
# run when JuMP/Ipopt are available.

@testset "diagnose_infeasibility" begin
    net = parse_bmopf(IEEE13_FIXTURE; from_string=true)

    @testset "rejects results that are not from solve_feasibility_opf" begin
        @test_throws ErrorException diagnose_infeasibility(
            Dict{String,Any}("foo" => 1), net)
    end

    @testset "non-converged solver → solver_infeasible report" begin
        res = Dict{String,Any}(
            "is_feasibility_opf" => true,
            "feasible"           => false,
            "termination_status" => "INFEASIBLE",
        )
        d = diagnose_infeasibility(res, net)
        @test d["is_feasible"] == false
        @test d["solver_infeasible"] == true
        @test d["termination_status"] == "INFEASIBLE"
        @test isempty(d["top_buses"])
        @test occursin("did not converge", d["note"])
    end

    @testset "power-balance infeasibility ranked, no voltage violation" begin
        # Two buses with non-zero slack, voltages comfortably within bounds →
        # both classified as power_balance, ranked by slack magnitude.
        res = Dict{String,Any}(
            "is_feasibility_opf"       => true,
            "feasible"                 => true,
            "total_slack_magnitude_A"  => 100.0,
            "slack_injections" => Dict{String,Any}(
                "671" => Dict{String,Any}(
                    "1" => Dict{String,Any}("cs_mag" => 60.0),
                    "2" => Dict{String,Any}("cs_mag" => 80.0)),   # √(60²+80²)=100
                "632" => Dict{String,Any}(
                    "1" => Dict{String,Any}("cs_mag" => 30.0)),
            ),
            "bus" => Dict{String,Any}(
                "671" => Dict{String,Any}(
                    "1" => Dict{String,Any}("vm" => 2300.0),
                    "2" => Dict{String,Any}("vm" => 2300.0),
                    "3" => Dict{String,Any}("vm" => 2300.0)),
                "632" => Dict{String,Any}(
                    "1" => Dict{String,Any}("vm" => 2300.0),
                    "2" => Dict{String,Any}("vm" => 2300.0),
                    "3" => Dict{String,Any}("vm" => 2300.0)),
            ),
        )
        d = diagnose_infeasibility(res, net)
        @test d["is_feasible"] == false
        @test d["n_infeasible_buses"] == 2
        @test d["top_buses"][1]["bus"] == "671"          # largest slack first
        @test d["top_buses"][1]["slack_A"] ≈ 100.0 rtol=1e-6
        @test d["top_buses"][1]["fraction_of_total"] ≈ 1.0 rtol=1e-6
        @test d["top_buses"][1]["failure_mode"] == "power_balance"
        @test d["failure_mode_summary"]["power_balance"] == 2
        @test d["failure_mode_summary"]["voltage_bound"] == 0
        @test d["n_voltage_violations"] == 0
        # load/gen accounting on the ranked bus
        @test d["top_buses"][1]["n_loads"] == 1          # load_671
        @test d["top_buses"][1]["total_load_kW"] > 0.0
    end

    @testset "voltage-bound infeasibility flags under/over voltage" begin
        res = Dict{String,Any}(
            "is_feasibility_opf"       => true,
            "feasible"                 => true,
            "total_slack_magnitude_A"  => 50.0,
            "slack_injections" => Dict{String,Any}(
                "671" => Dict{String,Any}(
                    "1" => Dict{String,Any}("cs_mag" => 50.0)),
            ),
            "bus" => Dict{String,Any}(
                "671" => Dict{String,Any}(
                    "1" => Dict{String,Any}("vm" => 1500.0),   # < v_min 2020 → under
                    "2" => Dict{String,Any}("vm" => 2700.0),   # > v_max 2540 → over
                    "3" => Dict{String,Any}("vm" => 2300.0)),
            ),
        )
        d = diagnose_infeasibility(res, net)
        @test d["is_feasible"] == false
        @test d["top_buses"][1]["failure_mode"] == "voltage_bound"
        @test d["failure_mode_summary"]["voltage_bound"] == 1
        @test !isempty(d["top_buses"][1]["voltage_violations"])
        # global voltage-violation pass picks up both the under- and over-voltage
        @test d["n_voltage_violations"] >= 2
        types = [v["type"] for v in d["voltage_violations"]]
        @test "undervoltage" in types
        @test "overvoltage" in types
        # violations are sorted by margin magnitude (largest first)
        margins = [abs(Float64(v["margin_V"])) for v in d["voltage_violations"]]
        @test issorted(margins; rev=true)
    end

    @testset "feasible result reported as feasible" begin
        res = Dict{String,Any}(
            "is_feasibility_opf"       => true,
            "feasible"                 => true,
            "total_slack_magnitude_A"  => 1e-6,            # below threshold
            "slack_injections"         => Dict{String,Any}(),
            "bus" => Dict{String,Any}(
                "671" => Dict{String,Any}(
                    "1" => Dict{String,Any}("vm" => 2300.0),
                    "2" => Dict{String,Any}("vm" => 2300.0),
                    "3" => Dict{String,Any}("vm" => 2300.0)),
            ),
        )
        d = diagnose_infeasibility(res, net)
        @test d["is_feasible"] == true
        @test d["n_infeasible_buses"] == 0
        @test isempty(d["top_buses"])
    end

    @testset "top_n and slack_threshold parameters are honoured" begin
        res = Dict{String,Any}(
            "is_feasibility_opf"       => true,
            "feasible"                 => true,
            "total_slack_magnitude_A"  => 10.0,
            "slack_injections" => Dict{String,Any}(
                "671" => Dict{String,Any}("1" => Dict{String,Any}("cs_mag" => 9.0)),
                "632" => Dict{String,Any}("1" => Dict{String,Any}("cs_mag" => 5.0)),
                "611" => Dict{String,Any}("3" => Dict{String,Any}("cs_mag" => 0.5)),
            ),
            "bus" => Dict{String,Any}(),
        )
        # high threshold drops the 0.5 A bus from the infeasible count
        d = diagnose_infeasibility(res, net; slack_threshold=1.0)
        @test d["n_infeasible_buses"] == 2
        # top_n caps the ranked list
        d2 = diagnose_infeasibility(res, net; slack_threshold=0.1, top_n=1)
        @test length(d2["top_buses"]) == 1
        @test d2["n_infeasible_buses"] == 3
    end

    @testset "integration: real solve_feasibility_opf on infeasible network" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path"
        else
            # Tight v_min the load cannot physically satisfy → binding bound,
            # imbalance surfaces as a non-zero slack residual.
            infnet = parse_bmopf("""
            {"bus":{
                "sourcebus":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "bus1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                        "v_min":[985.0],"v_max":[999.0]}},
             "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1"],
                 "v_magnitude":[1000.0],"v_angle":[0.0]}},
             "linecode":{"lc":{"R_series_1_1":0.5}},
             "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1",
                 "terminal_map_from":["1"],"terminal_map_to":["1"],
                 "linecode":"lc","length":1.0}},
             "load":{"ld1":{"bus":"bus1","terminal_map":["1","n"],
                 "configuration":"SINGLE_PHASE","p_nom":[100000.0],"q_nom":[0.0]}}}
            """; from_string=true)

            res = solve_feasibility_opf(infnet; optimizer=Ipopt.Optimizer)
            d   = diagnose_infeasibility(res, infnet)
            @test d["is_feasible"] == false
            @test d["n_infeasible_buses"] >= 1
            @test d["top_buses"][1]["bus"] == "bus1"
            @test d["total_infeasibility_A"] > 1.0
        end
    end
end
