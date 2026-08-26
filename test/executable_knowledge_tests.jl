using JSON3
using JSONSchema
using SHA

@testset "Executable knowledge export" begin
    root = normpath(joinpath(@__DIR__, ".."))
    corpus_path = joinpath(root, "generated", "executable_knowledge.jsonl")
    manifest_path = joinpath(root, "generated", "executable-knowledge-manifest.json")
    schema_path = joinpath(root, "schemas", "executable-knowledge.schema.json")

    @test isfile(corpus_path)
    @test isfile(manifest_path)
    @test isfile(schema_path)

    schema = JSONSchema.Schema(JSON3.read(read(schema_path, String)))
    lines = filter(!isempty, split(read(corpus_path, String), '\n'))
    records = JSON3.read.(lines)
    for record in records
        @test JSONSchema.validate(schema, record) === nothing
    end

    manifest = JSON3.read(read(manifest_path, String))
    @test manifest.record_count == length(records) == 55
    @test manifest.record_counts.executable_contract == 8
    @test manifest.record_counts.api_operation == 8
    @test manifest.record_counts.finding == 31
    @test manifest.record_counts.fixture == 8
    @test manifest.knowledge_ids == [
        "PSK-000001", "PSK-000002", "PSK-000003", "PSK-000004",
        "PSK-000005", "PSK-000006", "PSK-000007", "PSK-000008"]
    @test manifest.contract_ids == [
        "claimed_solution_validity",
        "decision_preservation_manifest_completeness",
        "kron_boundary_recovery_preservation",
        "load_voltage_base_consistency",
        "neutral_ground_reference_preservation",
        "parallel_member_limit_preservation",
        "transformer_tap_domain_preservation",
        "transformer_winding_convention_preservation",
    ]
    @test manifest.corpus_sha256 == bytes2hex(sha256(read(corpus_path)))

    by_id = Dict(String(record.record_id) => record for record in records)
    contract = by_id["contract:parallel_member_limit_preservation"]
    fixture = by_id["fixture:parallel-rating-outer-relaxation-001"]
    api = by_id["api:check_parallel_member_limit_preservation"]
    @test contract.entrypoint == api.entrypoint == "check_parallel_member_limit_preservation"
    @test fixture.fixture_id in contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)), contract.finding_codes)

    neutral_contract = by_id["contract:neutral_ground_reference_preservation"]
    neutral_fixture = by_id["fixture:neutral-ground-reference-conflation-001"]
    neutral_api = by_id["api:check_neutral_ground_reference_preservation"]
    @test neutral_contract.entrypoint == neutral_api.entrypoint ==
          "check_neutral_ground_reference_preservation"
    @test neutral_fixture.fixture_id in neutral_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              neutral_contract.finding_codes)

    solution_contract = by_id["contract:claimed_solution_validity"]
    solution_fixture = by_id["fixture:claimed-feasible-invalid-solution-001"]
    solution_api = by_id["api:check_claimed_solution_validity"]
    @test solution_contract.entrypoint == solution_api.entrypoint ==
          "check_claimed_solution_validity"
    @test solution_fixture.fixture_id in solution_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              solution_contract.finding_codes)

    load_base_contract = by_id["contract:load_voltage_base_consistency"]
    load_base_fixture = by_id["fixture:load-voltage-base-mismatch-001"]
    load_base_api = by_id["api:check_load_voltage_base_consistency"]
    @test load_base_contract.entrypoint == load_base_api.entrypoint ==
          "check_load_voltage_base_consistency"
    @test load_base_fixture.fixture_id in load_base_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              load_base_contract.finding_codes)

    tap_contract = by_id["contract:transformer_tap_domain_preservation"]
    tap_fixture = by_id["fixture:transformer-tap-domain-loss-001"]
    tap_api = by_id["api:check_transformer_tap_domain_preservation"]
    @test tap_contract.entrypoint == tap_api.entrypoint ==
          "check_transformer_tap_domain_preservation"
    @test tap_fixture.fixture_id in tap_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              tap_contract.finding_codes)

    winding_contract = by_id["contract:transformer_winding_convention_preservation"]
    winding_fixture = by_id["fixture:transformer-winding-role-swap-001"]
    winding_api = by_id["api:check_transformer_winding_convention_preservation"]
    @test winding_contract.entrypoint == winding_api.entrypoint ==
          "check_transformer_winding_convention_preservation"
    @test winding_fixture.fixture_id in winding_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              winding_contract.finding_codes)

    decision_contract = by_id["contract:decision_preservation_manifest_completeness"]
    decision_fixture = by_id["fixture:decision-manifest-terminal-only-001"]
    decision_api = by_id["api:check_decision_preservation_manifest"]
    @test decision_contract.entrypoint == decision_api.entrypoint ==
          "check_decision_preservation_manifest"
    @test decision_fixture.fixture_id in decision_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              decision_contract.finding_codes)

    kron_contract = by_id["contract:kron_boundary_recovery_preservation"]
    kron_fixture = by_id["fixture:kron-boundary-grounding-001"]
    kron_api = by_id["api:check_kron_boundary_recovery"]
    @test kron_contract.entrypoint == kron_api.entrypoint ==
          "check_kron_boundary_recovery"
    @test kron_fixture.fixture_id in kron_contract.fixture_ids
    @test all(code -> haskey(by_id, "finding:" * String(code)),
              kron_contract.finding_codes)

    for record in records
        for path in record.source.paths
            @test isfile(joinpath(root, String(path)))
        end
        if hasproperty(record, :files)
            for file in record.files
                path = joinpath(root, String(file.path))
                @test bytes2hex(sha256(read(path))) == file.sha256
            end
        end
    end

    generator = joinpath(root, "scripts", "generate_executable_knowledge.py")
    @test success(`python3 $generator --check`)
end
