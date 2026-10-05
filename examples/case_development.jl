# Four small experiments on an original synthetic teaching feeder.
# Run: julia --project=test examples/case_development.jl [optional-log.json]
# No outputs are written unless a log path is supplied.
using BMOPFTools, JuMP, Ipopt

case_development_input() = parse_bmopf(joinpath(@__DIR__, "..", "test", "data",
                                               "case_development", "feeder.json"))
case_development_solver(net) = solve_opf(net; per_unit=true,
    optimizer=optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "max_iter"=>500))

function case_development_base(; bus_ids=["near", "far"], phase_by_bus=Dict{String,String}())
    net, placement = add_ibrs(case_development_input(); recipe=IBRRecipe(
        bus_ids=bus_ids, phase_by_bus=phase_by_bus, capacity_budget=18000.0,
        cost_basis=:uniform, der_cost_uniform=0.0))
    # Explicit study capability: Q in +/-40% of converter rating, bounded also
    # by the engine's apparent-power capability circle. Not a compliance claim.
    for inv in values(net["ibr"])
        inv["p_min"] = zeros(length(inv["s_max"]))
        inv["p_max"] = copy(inv["s_max"])
        inv["q_min"] = -0.4 .* inv["s_max"]
        inv["q_max"] = 0.4 .* inv["s_max"]
    end
    net, placement
end

"""Vary demand and PV independently; keep the base and ratings unchanged."""
function demand_pv_experiment()
    net, placement = case_development_base()
    specs = [CaseScenario(name="evening", demand_scale=1.4, pv_scale=0.0),
             CaseScenario(name="midday", demand_scale=0.5, pv_scale=1.0),
             CaseScenario(name="cloudy", demand_scale=0.8, pv_scale=0.3)]
    net, placement, run_case_sweep(net, specs; solve=case_development_solver, keep_results=true)
end

"""Same total installed capacity, two declared adoption/phase patterns."""
function placement_experiment()
    rows = Dict{String,Any}[]
    for (name, buses, phases) in (
        ("dispersed", ["near", "far"], Dict("near"=>"1", "far"=>"2")),
        ("far_cluster", ["far"], Dict("far"=>"2")))
        net, placement = case_development_base(bus_ids=buses, phase_by_bus=phases)
        row = only(run_case_sweep(net, [CaseScenario(name=name, demand_scale=0.5)];
            solve=case_development_solver, keep_results=true))
        row["placement"] = manifest_to_dict(placement)
        push!(rows, row)
    end
    rows
end

"""Compare dispatch policies with identical hardware and operating limits."""
function control_experiment()
    base, _ = case_development_base()
    rows = Dict{String,Any}[]
    for policy in ("coordinated", "unity_pf", "volt_var")
        net = deepcopy(base)
        for inv in values(net["ibr"])
            if policy == "unity_pf"
                inv["q_min"] .= 0.0; inv["q_max"] .= 0.0
            elseif policy == "volt_var"
                inv["control_profile"] = "illustrative_vv"
            end
        end
        if policy == "volt_var"
            net["control_profile"] = Dict{String,Any}("illustrative_vv"=>Dict{String,Any}(
                "volt_var"=>Dict{String,Any}("voltage_reference"=>"PN_PER_PHASE",
                    "breakpoints"=>[207.0, 220.0, 240.0, 253.0],
                    "q_limits"=>[-0.4, 0.4], "q_unit"=>"VA_FRACTION", "q_ref"=>"VAR_MAX")))
        end
        append!(rows, run_case_sweep(net, [CaseScenario(name=policy, demand_scale=0.5)];
            solve=case_development_solver, keep_results=true))
    end
    rows
end

"""
Solve a series-reduced feeder, then replay its dispatch on the full feeder.
This example uses the explicit identity mapping of unchanged PV IDs/terminals.
It does not infer mappings for arbitrary reductions, transformer taps or controls.
"""
function reduction_experiment()
    full, _ = case_development_base()
    full, _ = materialize_scenario(full, CaseScenario(demand_scale=0.5))
    reduced = simplify_network(full; series_merge_policy=:exact)
    result = case_development_solver(reduced)
    checked = profile_solution(reduced, result)
    isempty(errors(checked)) || error("Reduced solution failed checks; cannot replay")
    # Explicit mapping for this fixture, reviewed against the unchanged devices.
    mapping = Dict("pv_near"=>"pv_near", "pv_far"=>"pv_far")
    Set(keys(mapping)) == Set(keys(reduced["ibr"])) || error("Unsupported reduced device set")
    Set(values(mapping)) == Set(keys(full["ibr"])) || error("Unsupported full device set")
    mapped = Dict{String,Any}("feasible"=>true, "ibr"=>Dict{String,Any}())
    for (rid, fid) in mapping
        reduced["ibr"][rid] == full["ibr"][fid] || error("Device changed during reduction")
        device_result = result["ibr"][rid]
        for phase in full["ibr"][fid]["terminal_map"][1:end-1]
            all(k -> isfinite(device_result[phase][k]), ("pg", "qg")) || error("Missing dispatch")
        end
        mapped["ibr"][fid] = device_result
    end
    pinned = project_solution(full, mapped)
    replay = solve_pf(pinned; per_unit=true,
        optimizer=optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0))
    # Check against the original limits, rather than interpreting PF termination
    # as evidence of operational feasibility (PSK-000013).
    verification = profile_solution(full, replay)
    (full=full, reduced=reduced, reduced_result=result, replay=replay,
     verification=verification, mapping=mapping)
end

function print_case_development_rows(rows)
    for row in rows
        checks = row["verification"]
        counts = checks === nothing ? "unassessed" : string(checks["summary"])
        println(row["name"], ": ", row["status"], ", solver=", row["termination_status"],
                ", checks=", counts)
        haskey(row, "error") && println("  ", row["error"])
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    net, placement, rows = demand_pv_experiment()
    print_case_development_rows(rows)
    print_case_development_rows(placement_experiment())
    print_case_development_rows(control_experiment())
    comparison = reduction_experiment()
    println("Reduction: ", length(comparison.full["bus"]), " -> ",
        length(comparison.reduced["bus"]), " buses; replay errors: ",
        length(errors(comparison.verification)))
    if !isempty(ARGS)
        write_case_log(net, only(ARGS); manifests=[placement], runs=rows,
            source_paths=[joinpath(@__DIR__, "..", "test", "data", "case_development", "feeder.json")],
            assumptions=["Synthetic teaching feeder; not utility calibrated",
                         "PV Q capability +/-40% of S rating; no standards compliance claim"],
            settings=Dict("optimizer"=>"Ipopt", "per_unit"=>true, "max_iter"=>500))
    end
end
