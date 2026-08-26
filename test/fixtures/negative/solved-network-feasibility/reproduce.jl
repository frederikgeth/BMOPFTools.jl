using BMOPFTools

result = check_solved_network_feasibility(Dict{String,Any}(
    "termination_status" => "OPTIMAL",
    "feasibility_validation" => Dict{String,Any}(
        "equation_residual_norm" => 1e-10,
        "kcl_residual_norm" => 2e-10,
        "power_balance_residual_norm" => 2e-4,
        "device_limit_violations" => 0,
        "recovery_residual_norm" => 1e-10)))
println(contract_result_to_dict(result))
