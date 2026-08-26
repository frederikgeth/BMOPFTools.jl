using BMOPFTools
source = Dict{String,Any}("serialization" => Dict{String,Any}("unit_system" => "SI", "bases" => Dict("voltage_V" => 230.0), "semantic_hash" => "sha256:a"))
target = Dict{String,Any}("serialization" => Dict{String,Any}("unit_system" => "SI", "bases" => Dict("voltage_V" => 230.0), "semantic_hash" => "sha256:b"))
println(contract_result_to_dict(check_unit_base_serialization_invariance(source, target; source_model_id="source", target_model_id="target")))
