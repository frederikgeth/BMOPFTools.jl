using BMOPFTools
using JSON3

mutable struct _SplitMix64
    state::UInt64
end

function _next_u64!(rng::_SplitMix64)
    rng.state += 0x9e3779b97f4a7c15
    value = rng.state
    value = (value ⊻ (value >> 30)) * 0xbf58476d1ce4e5b9
    value = (value ⊻ (value >> 27)) * 0x94d049bb133111eb
    value ⊻ (value >> 31)
end

_draw_int!(rng::_SplitMix64, low::Int, high::Int) =
    low + Int(_next_u64!(rng) % UInt64(high - low + 1))

function _draw_permutation!(rng::_SplitMix64, n::Int)
    permutation = collect(1:n)
    for i in n:-1:2
        j = _draw_int!(rng, 1, i)
        permutation[i], permutation[j] = permutation[j], permutation[i]
    end
    permutation
end

function _draw_series_matrix!(rng::_SplitMix64, n::Int)
    resistance = zeros(Float64, n, n)
    reactance = zeros(Float64, n, n)
    for i in 1:n, j in (i + 1):n
        resistance[i, j] = resistance[j, i] = _draw_int!(rng, 0, 50) / 1000
        reactance[i, j] = reactance[j, i] = _draw_int!(rng, 0, 100) / 1000
    end
    for i in 1:n
        resistance[i, i] = sum(abs, resistance[i, :]) + _draw_int!(rng, 100, 1000) / 1000
        reactance[i, i] = sum(abs, reactance[i, :]) + _draw_int!(rng, 50, 500) / 1000
    end
    complex.(resistance, reactance)
end

function _permutation_network(matrix::Matrix{ComplexF64}, from_labels, to_labels)
    line = Dict{String,Any}(
        "bus_from" => "source",
        "bus_to" => "target",
        "length" => 1.0,
        "terminal_map_from" => String.(from_labels),
        "terminal_map_to" => String.(to_labels),
    )
    for i in axes(matrix, 1), j in axes(matrix, 2)
        line["R_series_$(i)_$(j)"] = real(matrix[i, j])
        line["X_series_$(i)_$(j)"] = imag(matrix[i, j])
    end
    Dict{String,Any}("line" => Dict{String,Any}("generated" => line))
end

function _draw_permutation_case!(rng::_SplitMix64, dimension_min::Int, dimension_max::Int)
    n = _draw_int!(rng, dimension_min, dimension_max)
    source_matrix = _draw_series_matrix!(rng, n)
    permutation = _draw_permutation!(rng, n)
    source_from = ["f$(i)" for i in 1:n]
    source_to = ["t$(i)" for i in 1:n]
    target_matrix = source_matrix[permutation, permutation]
    source = _permutation_network(source_matrix, source_from, source_to)
    exact = _permutation_network(
        target_matrix, source_from[permutation], source_to[permutation])
    corrupted = deepcopy(exact)
    corrupted["line"]["generated"]["R_series_1_1"] += 0.01
    (; n, permutation, source_matrix, target_matrix, source_from, source_to,
       source, exact, corrupted)
end

function _minimize_permutation_failure(case)
    mapped = case.permutation[1]
    source_matrix = reshape([case.source_matrix[mapped, mapped]], 1, 1)
    target_matrix = reshape([case.target_matrix[1, 1] + 0.01], 1, 1)
    source = _permutation_network(
        source_matrix, [case.source_from[mapped]], [case.source_to[mapped]])
    target = _permutation_network(
        target_matrix, [case.source_from[mapped]], [case.source_to[mapped]])
    (; source, target, permutation=[1])
end

function _run_terminal_permutation_properties(spec)
    generator = spec["generator"]
    seed = parse(UInt64, replace(String(generator["seed"]), "0x" => ""); base=16)
    rng = _SplitMix64(seed)
    summaries = Any[]
    exact_passes = corrupted_failures = minimized_failures = 0
    for case_index in 1:Int(generator["case_count"])
        case = _draw_permutation_case!(
            rng, Int(generator["dimension_min"]), Int(generator["dimension_max"]))
        exact = check_terminal_permutation_invariance(case.source, case.exact;
            source_line_id="generated", target_line_id="generated",
            permutation=case.permutation)
        corrupted = check_terminal_permutation_invariance(case.source, case.corrupted;
            source_line_id="generated", target_line_id="generated",
            permutation=case.permutation)
        minimized_case = _minimize_permutation_failure(case)
        minimized = check_terminal_permutation_invariance(
            minimized_case.source, minimized_case.target;
            source_line_id="generated", target_line_id="generated",
            permutation=minimized_case.permutation)
        exact.status == :passed && (exact_passes += 1)
        corrupted.status == :failed &&
            only(corrupted.findings).code == "E.CONTRACT.PERMUTATION_RELATION_MISMATCH" &&
            (corrupted_failures += 1)
        minimized.status == :failed &&
            only(minimized.findings).code == "E.CONTRACT.PERMUTATION_RELATION_MISMATCH" &&
            (minimized_failures += 1)
        push!(summaries, Dict(
            "case_index" => case_index,
            "dimension" => case.n,
            "permutation" => case.permutation,
            "source_real_trace" => sum(real(case.source_matrix[i, i]) for i in 1:case.n),
            "source_imag_trace" => sum(imag(case.source_matrix[i, i]) for i in 1:case.n),
        ))
    end
    Dict(
        "exact_passes" => exact_passes,
        "corrupted_failures" => corrupted_failures,
        "minimized_failures" => minimized_failures,
        "summaries" => summaries,
    )
end

@testset "Scientific contracts — seeded terminal-permutation properties" begin
    seed_path = joinpath(@__DIR__, "property", "terminal-permutation-seed.json")
    spec = JSON3.read(read(seed_path, String), Dict{String,Any})
    @test spec["property_suite_id"] == "terminal_permutation_seeded_properties"
    @test spec["contract_id"] == "terminal_permutation_invariance"
    @test spec["knowledge_ids"] == ["PSK-000012"]
    first_run = _run_terminal_permutation_properties(spec)
    second_run = _run_terminal_permutation_properties(spec)
    expected = Int(spec["generator"]["case_count"])
    @test first_run == second_run
    @test first_run["exact_passes"] == expected
    @test first_run["corrupted_failures"] == expected
    @test first_run["minimized_failures"] == expected
    @test all(item["dimension"] in 1:6 for item in first_run["summaries"])
end
