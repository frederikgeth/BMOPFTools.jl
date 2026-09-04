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

function _draw_semantic_hash!(rng::_SplitMix64)
    digits = join(lpad(string(_next_u64!(rng); base=16), 16, '0') for _ in 1:4)
    "sha256:" * digits
end

function _serialization_record(unit_system::AbstractString, bases, semantic_hash::AbstractString)
    Dict{String,Any}(
        "serialization" => Dict{String,Any}(
            "unit_system" => String(unit_system),
            "bases" => Dict{String,Any}(bases),
            "semantic_hash" => String(semantic_hash),
        ),
    )
end

function _mutate_hash(hash::AbstractString)
    replacement = endswith(hash, "0") ? "1" : "0"
    String(hash)[1:(end - 1)] * replacement
end

function _draw_unit_base_case!(rng::_SplitMix64, generator)
    voltage = Float64(_draw_int!(rng,
        Int(generator["voltage_min_V"]), Int(generator["voltage_max_V"])))
    power = 1000.0 * _draw_int!(rng,
        Int(generator["power_min_kVA"]), Int(generator["power_max_kVA"]))
    current = power / voltage
    impedance = voltage^2 / power
    bases = Dict{String,Any}(
        "voltage_V" => voltage,
        "power_VA" => power,
        "current_A" => current,
        "impedance_ohm" => impedance,
        "admittance_S" => inv(impedance),
    )
    semantic_hash = _draw_semantic_hash!(rng)
    source = _serialization_record(String(generator["unit_system"]), bases, semantic_hash)
    exact = JSON3.read(JSON3.write(source), Dict{String,Any})
    exact_bases = exact["serialization"]["bases"]
    exact["serialization"]["bases"] = Dict{String,Any}(
        key => exact_bases[key] for key in reverse(sort(collect(keys(exact_bases)))))

    unit_fault = deepcopy(exact)
    unit_fault["serialization"]["unit_system"] = "per_unit"
    base_fault = deepcopy(exact)
    base_fault["serialization"]["bases"]["voltage_V"] += 1.0
    hash_fault = deepcopy(exact)
    hash_fault["serialization"]["semantic_hash"] = _mutate_hash(semantic_hash)
    (; voltage, power, semantic_hash, source, exact, unit_fault, base_fault, hash_fault)
end

function _minimize_unit_base_failure(case, fault::Symbol)
    source = _serialization_record("SI",
        Dict("voltage_V" => case.voltage), case.semantic_hash)
    target = deepcopy(source)
    if fault == :unit_system
        target["serialization"]["unit_system"] = "per_unit"
    elseif fault == :base_map
        target["serialization"]["bases"]["voltage_V"] += 1.0
    elseif fault == :semantic_hash
        target["serialization"]["semantic_hash"] = _mutate_hash(case.semantic_hash)
    else
        error("unknown unit/base fault: $fault")
    end
    (; source, target)
end

function _unit_base_check(source, target)
    check_unit_base_serialization_invariance(source, target;
        source_model_id="generated-source", target_model_id="generated-target")
end

function _run_unit_base_properties(spec)
    generator = spec["generator"]
    seed = parse(UInt64, replace(String(generator["seed"]), "0x" => ""); base=16)
    rng = _SplitMix64(seed)
    expected_codes = Dict(
        :unit_system => String(spec["faults"]["unit_system"]["expected_finding_code"]),
        :base_map => String(spec["faults"]["base_map"]["expected_finding_code"]),
        :semantic_hash => String(spec["faults"]["semantic_hash"]["expected_finding_code"]),
    )
    exact_passes = 0
    failures = Dict(fault => 0 for fault in keys(expected_codes))
    minimized_failures = Dict(fault => 0 for fault in keys(expected_codes))
    summaries = Any[]
    for case_index in 1:Int(generator["case_count"])
        case = _draw_unit_base_case!(rng, generator)
        _unit_base_check(case.source, case.exact).status == :passed &&
            (exact_passes += 1)
        targets = Dict(
            :unit_system => case.unit_fault,
            :base_map => case.base_fault,
            :semantic_hash => case.hash_fault,
        )
        for fault in keys(expected_codes)
            result = _unit_base_check(case.source, targets[fault])
            result.status == :failed && only(result.findings).code == expected_codes[fault] &&
                (failures[fault] += 1)
            minimized = _minimize_unit_base_failure(case, fault)
            minimized_result = _unit_base_check(minimized.source, minimized.target)
            minimized_result.status == :failed &&
                only(minimized_result.findings).code == expected_codes[fault] &&
                length(minimized.source["serialization"]["bases"]) == 1 &&
                (minimized_failures[fault] += 1)
        end
        push!(summaries, Dict(
            "case_index" => case_index,
            "voltage_V" => case.voltage,
            "power_VA" => case.power,
            "semantic_hash" => case.semantic_hash,
        ))
    end
    Dict(
        "exact_passes" => exact_passes,
        "failures" => failures,
        "minimized_failures" => minimized_failures,
        "summaries" => summaries,
    )
end

@testset "Scientific contracts — seeded unit/base serialization properties" begin
    seed_path = joinpath(@__DIR__, "property", "unit-base-serialization-seed.json")
    spec = JSON3.read(read(seed_path, String), Dict{String,Any})
    @test spec["property_suite_id"] == "unit_base_serialization_seeded_properties"
    @test spec["contract_id"] == "unit_base_serialization_invariance"
    @test spec["knowledge_ids"] == ["PSK-000014"]
    first_run = _run_unit_base_properties(spec)
    second_run = _run_unit_base_properties(spec)
    expected = Int(spec["generator"]["case_count"])
    @test first_run == second_run
    @test first_run["exact_passes"] == expected
    @test all(count == expected for count in values(first_run["failures"]))
    @test all(count == expected for count in values(first_run["minimized_failures"]))
    @test all(startswith(item["semantic_hash"], "sha256:") &&
              length(item["semantic_hash"]) == 71 for item in first_run["summaries"])
end
