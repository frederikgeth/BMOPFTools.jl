using JSON3

@testset "Scientific contracts — parallel member limits" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "parallel-rating-outer-relaxation")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    naive = parse_bmopf(joinpath(fixture, "transformed.json"))
    exact = parse_bmopf(joinpath(fixture, "exact-target.json"))
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))

    @testset "naive summed rating reproduces the registered witness" begin
        result = check_parallel_member_limit_preservation(
            source, naive; member_ids=["l1", "l2"], aggregate_id="leq")
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [f.code for f in result.findings] == String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        atol = Float64(expected.absolute_tolerance)
        @test result.evidence["source_voltage_drop_limit_V"] ≈
              expected.source_voltage_drop_limit_V atol=atol
        @test result.evidence["target_voltage_drop_limit_V"] ≈
              expected.target_voltage_drop_limit_V atol=atol
        witness = result.evidence["witness"]
        @test witness["voltage_drop_V"] ≈ expected.witness.voltage_drop_V atol=atol
        @test witness["member_currents_A"]["l1"] ≈
              expected.witness.member_currents_A.l1 atol=atol
        @test witness["member_currents_A"]["l2"] ≈
              expected.witness.member_currents_A.l2 atol=atol
        @test witness["aggregate_current_A"] ≈ expected.witness.aggregate_current_A atol=atol
        @test witness["source_feasible"] === false
        @test witness["target_feasible"] === true
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000001"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "case-specific exact scalar rating passes only checked dimensions" begin
        result = check_parallel_member_limit_preservation(
            source, exact; member_ids=["l1", "l2"], aggregate_id="leq")
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions ==
              ["terminal_behavior", "scalar_member_current_limits"]
        @test "member_identity" in result.unassessed_dimensions
        @test result.evidence["classification"] ==
              "exact_for_scalar_member_current_limits"
    end

    @testset "terminal relation is checked independently of limits" begin
        mismatched = deepcopy(naive)
        mismatched["line"]["leq"]["R_series_1_1"] = 0.2
        result = check_parallel_member_limit_preservation(
            source, mismatched; member_ids=["l1", "l2"], aggregate_id="leq")
        @test result.status == :failed
        @test only(result.findings).code ==
              "E.CONTRACT.PARALLEL_TERMINAL_RELATION_MISMATCH"
        @test result.evidence["classification"] == "terminal_relation_mismatch"
    end

    @testset "unsupported domain and missing evidence refuse explicitly" begin
        shunted = deepcopy(source)
        shunted["line"]["l1"]["B_from_1_1"] = 1e-3
        inapplicable = check_parallel_member_limit_preservation(
            shunted, naive; member_ids=["l1", "l2"], aggregate_id="leq")
        @test inapplicable.status == :inapplicable
        @test only(inapplicable.findings).code == "I.CONTRACT.NOT_APPLICABLE"

        unrated = deepcopy(naive)
        delete!(unrated["line"]["leq"], "i_max")
        indeterminate = check_parallel_member_limit_preservation(
            source, unrated; member_ids=["l1", "l2"], aggregate_id="leq")
        @test indeterminate.status == :indeterminate
        @test only(indeterminate.findings).code == "W.CONTRACT.INDETERMINATE"
    end

    @testset "orientation and JSON serialization are stable" begin
        reversed = deepcopy(source)
        line = reversed["line"]["l2"]
        line["bus_from"], line["bus_to"] = line["bus_to"], line["bus_from"]
        line["terminal_map_from"], line["terminal_map_to"] =
            line["terminal_map_to"], line["terminal_map_from"]
        result = check_parallel_member_limit_preservation(
            reversed, naive; member_ids=["l2", "l1"], aggregate_id="leq")
        @test result.status == :failed
        @test result.evidence["witness"]["voltage_drop_V"] ≈ 15.0

        payload = contract_result_to_dict(result)
        json = JSON3.write(payload)
        decoded = JSON3.read(json)
        @test decoded.status == "failed"
        @test decoded.knowledge_ids == ["PSK-000001"]
        @test decoded.findings[1].detail.contract_id ==
              "parallel_member_limit_preservation"
    end
end
