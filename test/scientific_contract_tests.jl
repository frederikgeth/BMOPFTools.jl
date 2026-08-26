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

@testset "Scientific contracts — load voltage-base consistency" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "load-voltage-base-mismatch")
    wrong = parse_bmopf(joinpath(fixture, "wrong-base-network.json"))
    validated = parse_bmopf(joinpath(fixture, "validated-network.json"))
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))

    @testset "delta line-to-line base rejects the phase-to-neutral shortcut" begin
        result = check_load_voltage_base_consistency(
            wrong; load_ids=["delta_zip"])
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        record = result.evidence["loads"][expected.load_id]
        atol = Float64(expected.absolute_tolerance)
        @test record["bus_phase_to_neutral_base_V"] ≈
              expected.bus_phase_to_neutral_base_V atol=atol
        @test record["expected_v_nom_V"] ≈ expected.expected_v_nom_V atol=atol
        @test only(record["declared_v_nom_V"]) ≈ expected.declared_v_nom_V atol=atol
        @test only(record["ratios"]) ≈ expected.ratio atol=atol
        @test record["voltage_coordinate"] == "line_to_line"
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000004"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])

        ordinary = Finding[]
        domain_rules_check(wrong, ordinary)
        @test "W.LOAD.VNOM_MISMATCH" in [finding.code for finding in ordinary]
    end

    @testset "connection-consistent anchors pass only declared dimensions" begin
        result = check_load_voltage_base_consistency(validated)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "source_propagated_bus_voltage_base",
            "declared_load_connection_voltage_coordinate",
            "load_nominal_voltage_anchor",
        ]
        @test "terminal_map_correctness" in result.unassessed_dimensions
        @test "network_equation_feasibility" in result.unassessed_dimensions
        @test result.evidence["classification"] ==
              "connection_voltage_bases_consistent"

        wye = deepcopy(validated)
        wye_load = wye["load"]["delta_zip"]
        wye_load["configuration"] = "WYE"
        wye_load["terminal_map"] = ["a", "b", "c", "n"]
        wye_load["v_nom"] = [230.0]
        wye_result = check_load_voltage_base_consistency(wye)
        @test wye_result.status == :passed
        @test wye_result.evidence["loads"]["delta_zip"]["voltage_coordinate"] ==
              "phase_to_neutral"

        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000004"]
    end

    @testset "ratio boundaries and refusal semantics are explicit" begin
        low = deepcopy(validated)
        low["load"]["delta_zip"]["v_nom"] = [0.8 * 230.0 * sqrt(3.0)]
        @test check_load_voltage_base_consistency(low).status == :passed
        low["load"]["delta_zip"]["v_nom"] = [0.799 * 230.0 * sqrt(3.0)]
        @test check_load_voltage_base_consistency(low).status == :failed

        constant = deepcopy(validated)
        constant["load"]["delta_zip"]["model"] = "constant_power"
        inapplicable = check_load_voltage_base_consistency(
            constant; load_ids=["delta_zip"])
        @test inapplicable.status == :inapplicable
        @test only(inapplicable.findings).code ==
              "I.CONTRACT.LOAD_VOLTAGE_BASE_NOT_APPLICABLE"

        missing = check_load_voltage_base_consistency(
            validated; load_ids=["missing"])
        @test missing.status == :indeterminate
        @test only(missing.findings).code ==
              "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE"

        no_anchor = deepcopy(validated)
        delete!(no_anchor["load"]["delta_zip"], "v_nom")
        indeterminate = check_load_voltage_base_consistency(no_anchor)
        @test indeterminate.status == :indeterminate
        @test only(indeterminate.findings).code ==
              "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE"

        @test_throws ArgumentError check_load_voltage_base_consistency(
            validated; ratio_min=1.1, ratio_max=1.2)
    end
end

@testset "Scientific contracts — claimed solution validity" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "claimed-feasible-invalid-solution")
    network = parse_bmopf(joinpath(fixture, "network.json"))
    claimed = JSON3.read(
        read(joinpath(fixture, "claimed-solved-result.json"), String),
        Dict{String,Any},
    )
    validated = JSON3.read(
        read(joinpath(fixture, "validated-result.json"), String),
        Dict{String,Any},
    )
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))

    @testset "claimed-feasible status does not override independent evidence" begin
        result = check_claimed_solution_validity(network, claimed)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        @test result.evidence["termination_status"] == expected.termination_status
        @test [finding["code"] for finding in
               result.evidence["blocking_solution_findings"]] ==
              String.(expected.blocking_solution_finding_codes)
        @test result.evidence["solution_summary"]["n_volt_violations"] == 1
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000003"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "clean checked dimensions pass narrowly" begin
        result = check_claimed_solution_validity(network, validated)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "termination_status",
            "result_numeric_finiteness",
            "declared_bus_voltage_and_angle_limits",
        ]
        @test "network_equation_residuals" in result.unassessed_dimensions
        @test "objective_optimality" in result.unassessed_dimensions
        @test "local_or_global_optimality" in result.unassessed_dimensions
        @test result.evidence["classification"] == "checked_solution_dimensions_valid"

        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000003"]
    end

    @testset "non-finite values fail independently of feasible status" begin
        nonfinite = deepcopy(validated)
        nonfinite["bus"]["study_bus"]["a"]["vm"] = NaN
        result = check_claimed_solution_validity(network, nonfinite)
        @test result.status == :failed
        @test only(result.findings).code ==
              "E.CONTRACT.CLAIMED_FEASIBLE_SOLUTION_INVALID"
        @test [finding["code"] for finding in
               result.evidence["blocking_solution_findings"]] ==
              ["E.SOL.NAN_IN_RESULT"]
    end

    @testset "status and completeness refusals are explicit" begin
        unfinished = deepcopy(validated)
        unfinished["termination_status"] = "INFEASIBLE"
        inapplicable = check_claimed_solution_validity(network, unfinished)
        @test inapplicable.status == :inapplicable
        @test only(inapplicable.findings).code ==
              "I.CONTRACT.SOLUTION_STATUS_NOT_APPLICABLE"

        missing_status = deepcopy(validated)
        delete!(missing_status, "termination_status")
        unknown = check_claimed_solution_validity(network, missing_status)
        @test unknown.status == :indeterminate
        @test only(unknown.findings).code ==
              "W.CONTRACT.SOLUTION_VALIDATION_INDETERMINATE"

        incomplete = deepcopy(validated)
        delete!(incomplete["bus"]["study_bus"]["a"], "vi")
        indeterminate = check_claimed_solution_validity(network, incomplete)
        @test indeterminate.status == :indeterminate
        @test only(indeterminate.findings).code ==
              "W.CONTRACT.SOLUTION_VALIDATION_INDETERMINATE"
        @test occursin("bus.study_bus.a.vi", indeterminate.evidence["reason"])
    end
end

@testset "Scientific contracts — neutral, ground, and reference" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "neutral-ground-reference-conflation")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    naive = parse_bmopf(joinpath(fixture, "transformed.json"))
    exact = parse_bmopf(joinpath(fixture, "exact-target.json"))
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))
    mapping = Dict("source" => "source", "load" => "load")

    @testset "conflation fixture loses two distinct relations" begin
        result = check_neutral_ground_reference_preservation(
            source, naive; bus_mapping=mapping)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        @test result.evidence["source_relations"]["load"]["relation_classes"] ==
              String.(expected.source_load_relation_classes)
        @test result.evidence["target_relations"]["load"]["relation_classes"] ==
              String.(expected.target_load_relation_classes)
        @test only(result.evidence["neutral_continuity_mismatches"])["source_connected"]
        @test !only(result.evidence["neutral_continuity_mismatches"])["target_connected"]
        @test all(!isempty(finding.detail["invalid_inferences"]) for finding in result.findings)
        @test all(!isempty(finding.detail["recommended_checks"]) for finding in result.findings)
    end

    @testset "renaming assets preserves the checked relations" begin
        result = check_neutral_ground_reference_preservation(
            source, exact; bus_mapping=mapping)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "neutral_terminal_identity",
            "neutral_continuity",
            "ground_reference_relations",
        ]
        @test "electrical_terminal_behavior" in result.unassessed_dimensions
        @test "grounding_asset_identity_and_state" in result.unassessed_dimensions
        @test result.evidence["classification"] == "representation_relations_preserved"

        payload = contract_result_to_dict(result)
        decoded = JSON3.read(JSON3.write(payload))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000002"]
    end

    @testset "identity loss, unsupported coupling, and missing evidence refuse explicitly" begin
        missing_neutral = deepcopy(exact)
        missing_neutral["bus"]["load"]["terminal_names"] = ["a"]
        identity = check_neutral_ground_reference_preservation(
            source, missing_neutral; bus_mapping=mapping)
        @test identity.status == :failed
        @test only(identity.findings).code == "E.CONTRACT.NEUTRAL_IDENTITY_LOSS"

        coupled = deepcopy(source)
        coupled["shunt"]["load_grounding"] = Dict{String,Any}(
            "bus" => "load",
            "terminal_map" => ["a", "n"],
            "G_1_1" => 0.0,
            "G_1_2" => 0.0,
            "G_2_1" => 0.0,
            "G_2_2" => 0.1,
        )
        inapplicable = check_neutral_ground_reference_preservation(
            coupled, exact; bus_mapping=mapping)
        @test inapplicable.status == :inapplicable
        @test only(inapplicable.findings).code ==
              "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE"

        indeterminate = check_neutral_ground_reference_preservation(
            source, exact; bus_mapping=Dict("source" => "missing", "load" => "load"))
        @test indeterminate.status == :indeterminate
        @test only(indeterminate.findings).code ==
              "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE"

        no_neutral_source = deepcopy(source)
        no_neutral_source["bus"]["load"]["terminal_names"] = ["a"]
        no_neutral = check_neutral_ground_reference_preservation(
            no_neutral_source, exact; bus_mapping=mapping)
        @test no_neutral.status == :inapplicable
        @test only(no_neutral.findings).code ==
              "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE"
    end

    @testset "finite grounding comparison honors declared tolerances" begin
        perturbed = deepcopy(exact)
        perturbed["shunt"]["renamed_grounding"]["G_1_1"] = 0.1000001
        near = check_neutral_ground_reference_preservation(
            source, perturbed; bus_mapping=mapping, atol=1e-6, rtol=0)
        @test near.status == :passed
        far = check_neutral_ground_reference_preservation(
            source, perturbed; bus_mapping=mapping, atol=1e-9, rtol=0)
        @test far.status == :failed
        @test only(far.findings).code ==
              "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH"
    end
end
