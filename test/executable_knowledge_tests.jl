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
    @test manifest.record_count == length(records) == 15
    @test manifest.record_counts.executable_contract == 2
    @test manifest.record_counts.api_operation == 2
    @test manifest.record_counts.finding == 9
    @test manifest.record_counts.fixture == 2
    @test manifest.knowledge_ids == ["PSK-000001", "PSK-000002"]
    @test manifest.contract_ids == [
        "neutral_ground_reference_preservation",
        "parallel_member_limit_preservation",
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
