using BMOPFTools

source = parse_bmopf(joinpath(@__DIR__, "source.json"))
target = parse_bmopf(joinpath(@__DIR__, "target.json"))
result = check_terminal_permutation_invariance(source, target;
    source_line_id="l3", target_line_id="l3", permutation=[2, 3, 1])
println(contract_result_to_dict(result))
