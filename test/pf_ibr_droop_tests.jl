using Test, BMOPFTools, JuMP, Ipopt, JSON3

function pf_droop_net(; voltage=250.0, power=0.0, topology="SINGLE_PHASE")
    net = JSON3.read(read(joinpath(@__DIR__, "data", "pf_ibr_droop",
                                  "rating_base.json"), String), Dict{String,Any})
    phases = topology == "SINGLE_PHASE" ? ["a"] : ["a", "b", "c"]
    terminals = vcat(phases, ["n"])
    net["bus"]["b"]["terminal_names"] = terminals
    source = net["voltage_source"]["source"]
    source["terminal_map"] = phases
    source["v_magnitude"] = fill(voltage, length(phases))
    source["v_angle"] = length(phases) == 1 ? [0.0] : [0.0, -2pi/3, 2pi/3]
    inv = net["ibr"]["pv"]
    inv["topology"] = topology
    inv["terminal_map"] = terminals
    for (field, value) in (("p_min", power), ("p_max", power),
                           ("s_max", 6000.0), ("i_max", 0.01))
        inv[field] = fill(value, length(phases))
    end
    return net
end

# Independent stable softplus evaluation in physical volts. Match the documented
# relative smoothing scale without using the implementation's curve helpers.
pf_droop_soft(z, epsilon) = max(z, 0.0) + epsilon*log1p(exp(-abs(z)/epsilon))
function pf_expected_var(voltage)
    epsilon = 2e-3 * (207 + 220 + 240 + 258)/4
    sp(z) = pf_droop_soft(z, epsilon)
    6000 * (0.44 - 0.44/13 * (sp(voltage-207) - sp(voltage-220)) -
                    0.6/18 * (sp(voltage-240) - sp(voltage-258)))
end
function pf_expected_watt_cap(voltage)
    epsilon = 2e-3 * (253 + 260)/2
    sp(z) = pf_droop_soft(z, epsilon)
    6000 * (1 - 0.8/7 * (sp(voltage-253) - sp(voltage-260)))
end

const PF_DROOP_SOLVER_OPTIONS = ("tol"=>1e-10, "constr_viol_tol"=>1e-10,
                                "bound_relax_factor"=>0.0)

@testset "Power-flow IBR droop bases (#447, PSK-000013)" begin
    @testset "Volt-var and ignored ratings in SI and per-unit" begin
        for topology in ("SINGLE_PHASE", "FOUR_LEG"), per_unit in (false, true),
            voltage in (230.0, 250.0, 270.0)
            # At 250/270 V this P/Q exceeds s_max. PF must still solve with
            # the rated droop response, ignoring both apparent/current limits.
            net = pf_droop_net(; voltage, power=5900.0, topology)
            delete!(net["control_profile"]["aus_a"], "volt_watt")
            original = deepcopy(net)
            result = solve_pf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS,
                model_hook! = ctx -> begin
                    for k in eachindex(net["ibr"]["pv"]["s_max"])
                        @test OpfModelKey(:constraint, :ibr_power_circle, ("pv", k)) ∉
                              opf_object_keys(ctx)
                    end
                end)
            @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test result["is_power_flow"]
            expected_q = pf_expected_var(voltage)
            for (k, phase) in enumerate(net["voltage_source"]["source"]["terminal_map"])
                row = result["ibr"]["pv"][phase]
                @test row["pg"] ≈ 5900.0 atol=1e-3
                @test row["qg"] ≈ expected_q atol=1e-3
                v = voltage * cis(net["voltage_source"]["source"]["v_angle"][k])
                @test row["cri"] + im*row["cii"] ≈
                      conj((5900.0 + im*expected_q)/v) atol=1e-5
                source = result["voltage_source"]["source"][phase]
                @test source["ps"] ≈ -row["pg"] atol=1e-3
                @test source["qs"] ≈ -row["qg"] atol=1e-3
            end
            restored = JSON3.read(JSON3.write(result), Dict{String,Any})
            @test restored["ibr"] == result["ibr"]
            @test net == original
        end
    end

    @testset "Volt-watt preserves its cap and accepts positive setpoints" begin
        for topology in ("SINGLE_PHASE", "FOUR_LEG"), per_unit in (false, true),
            (voltage, power, feasible) in ((230.0, 1500.0, true),
                (253.0, 5000.0, true), (256.5, 1500.0, true),
                (270.0, 1000.0, true), (270.0, 1500.0, false),
                (253.0, 5900.0, false))
            net = pf_droop_net(; voltage, power, topology)
            delete!(net["control_profile"]["aus_a"], "volt_var")
            inv = net["ibr"]["pv"]
            inv["q_min"] = zeros(length(inv["s_max"]))
            inv["q_max"] = zeros(length(inv["s_max"]))
            original = deepcopy(net)
            result = solve_pf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS)
            @test (power <= pf_expected_watt_cap(voltage)) == feasible
            if feasible
                @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                for (k, phase) in enumerate(net["voltage_source"]["source"]["terminal_map"])
                    @test result["ibr"]["pv"][phase]["pg"] ≈ power atol=1e-3
                    @test result["ibr"]["pv"][phase]["qg"] ≈ 0.0 atol=1e-3
                    evidence = result["modeled_volt_watt"]["pv"][string(k)]
                    # Independent serialized-evidence check catches a zero base
                    # even when a zero active-power setpoint would hide it.
                    @test evidence["baseline_W"] ≈ 6000.0
                    cap = evidence["baseline_W"] + sum(h["slope_W_per_V"] *
                        pf_droop_soft(voltage-h["breakpoint_V"], evidence["epsilon_V"])
                        for h in evidence["hinges"])
                    @test cap ≈ pf_expected_watt_cap(voltage) atol=1e-6
                end
                restored = JSON3.read(JSON3.write(result), Dict{String,Any})
                @test restored["modeled_volt_watt"] == result["modeled_volt_watt"]
            else
                @test result["termination_status"] == "LOCALLY_INFEASIBLE"
            end
            @test net == original
        end
    end

    @testset "Combined original witness and OPF rating control" begin
        for per_unit in (false, true)
            net = pf_droop_net()
            result = solve_pf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS)
            @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test result["ibr"]["pv"]["a"]["qg"] ≈ pf_expected_var(250.0) atol=1e-3
            @test result["modeled_volt_watt"]["pv"]["1"]["baseline_W"] ≈ 6000.0

            # No controller: PF also ignores s_max, while OPF retains its circle.
            net = pf_droop_net(; power=6100.0)
            delete!(net["ibr"]["pv"], "control_profile")
            delete!(net["ibr"]["pv"], "i_max")
            net["ibr"]["pv"]["q_min"] = [0.0]
            net["ibr"]["pv"]["q_max"] = [0.0]
            pf = solve_pf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS)
            @test pf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test pf["ibr"]["pv"]["a"]["pg"] ≈ 6100.0 atol=1e-3
            opf = solve_opf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS,
                model_hook! = ctx -> @test OpfModelKey(:constraint,
                    :ibr_power_circle, ("pv", 1)) in opf_object_keys(ctx))
            @test opf["termination_status"] == "LOCALLY_INFEASIBLE"

            # Ratings remain optional for an uncontrolled fixed-P/Q PF.
            delete!(net["ibr"]["pv"], "s_max")
            free = solve_pf(net; per_unit, solver_options=PF_DROOP_SOLVER_OPTIONS)
            @test free["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test free["ibr"]["pv"]["a"]["pg"] ≈ 6100.0 atol=1e-3
        end
    end
end
