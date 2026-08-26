using JSON3

@testset "Scientific contracts — unit/base serialization invariance" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "unit-base-serialization")
    load(name) = JSON3.read(read(joinpath(fixture, name), String), Dict{String,Any})
    result = check_unit_base_serialization_invariance(load("source.json"), load("target.json");
        source_model_id="source", target_model_id="target")
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.SERIALIZED_PAYLOAD_MISMATCH"
    @test result.evidence["classification"] == "canonical_payload_mismatch"
    result = check_unit_base_serialization_invariance(load("source.json"), load("exact-target.json");
        source_model_id="source", target_model_id="target")
    @test result.status == :passed
    @test result.checked_dimensions == ["canonical_payload_identity", "source_hash_binding", "physical_unit_semantics"]
    bad = deepcopy(load("exact-target.json")); bad["serialization"]["bases"]["voltage_V"] = 240.0
    @test only(check_unit_base_serialization_invariance(load("source.json"), bad;
        source_model_id="source", target_model_id="target").findings).code == "E.CONTRACT.BASE_MAP_MISMATCH"
    @test check_unit_base_serialization_invariance(Dict{String,Any}(), Dict{String,Any}();
        source_model_id="source", target_model_id="target").status == :indeterminate
end

@testset "Scientific contracts — solved-network feasibility witness" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "solved-network-feasibility")
    load(name) = JSON3.read(read(joinpath(fixture, name), String), Dict{String,Any})
    result = check_solved_network_feasibility(load("source.json"))
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.FEASIBILITY_RESIDUAL_VIOLATION"
    @test result.evidence["classification"] == "independent_feasibility_witness_failed"

    result = check_solved_network_feasibility(load("exact-target.json"))
    @test result.status == :passed
    @test isempty(result.findings)
    @test "complete_feasible_set" in result.unassessed_dimensions

    result = check_solved_network_feasibility(Dict{String,Any}(
        "termination_status" => "INFEASIBLE"))
    @test result.status == :inapplicable
    @test only(result.findings).code == "I.CONTRACT.FEASIBILITY_NOT_APPLICABLE"

    result = check_solved_network_feasibility(Dict{String,Any}(
        "termination_status" => "OPTIMAL"))
    @test result.status == :indeterminate
    @test only(result.findings).code == "W.CONTRACT.FEASIBILITY_INDETERMINATE"
end

@testset "Scientific contracts — terminal permutation invariance" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "terminal-permutation")
    load(name) = parse_bmopf(joinpath(fixture, name))
    source, target, exact = load("source.json"), load("target.json"), load("exact-target.json")
    result = check_terminal_permutation_invariance(source, target;
        source_line_id="l3", target_line_id="l3", permutation=[2, 3, 1])
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.PERMUTATION_RELATION_MISMATCH"
    @test result.evidence["classification"] == "permutation_relation_mismatch"

    result = check_terminal_permutation_invariance(source, exact;
        source_line_id="l3", target_line_id="l3", permutation=[2, 3, 1])
    @test result.status == :passed
    @test isempty(result.findings)
    @test result.checked_dimensions == ["permutation_bijection",
        "endpoint_terminal_map_alignment", "series_matrix_permutation_relation"]
    @test "complete_network_feasible_set" in result.unassessed_dimensions

    mismatched = deepcopy(exact)
    mismatched["line"]["l3"]["terminal_map_to"] = ["a", "c", "b"]
    result = check_terminal_permutation_invariance(source, mismatched;
        source_line_id="l3", target_line_id="l3", permutation=[2, 3, 1])
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.TERMINAL_ORDER_MISMATCH"

    result = check_terminal_permutation_invariance(source, exact;
        source_line_id="l3", target_line_id="l3", permutation=[1, 1, 2])
    @test result.status == :inapplicable
    @test only(result.findings).code == "I.CONTRACT.PERMUTATION_NOT_APPLICABLE"

    decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
    @test decoded.status == "inapplicable"
    @test decoded.knowledge_ids == ["PSK-000012"]
end

@testset "Scientific contracts — reference and singularity validation" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "reference-singularity")
    load(name) = JSON3.read(read(joinpath(fixture, name), String), Dict{String,Any})
    result = check_reference_singularity(
        load("source.json"), load("target.json");
        source_model_id="referenced-source", target_model_id="floating-target")
    @test result.status == :failed
    @test [f.code for f in result.findings] ==
          ["E.CONTRACT.REFERENCE_LOSS", "E.CONTRACT.SINGULARITY_CHANGE"]
    @test result.evidence["classification"] == "reference_or_singularity_failure"

    result = check_reference_singularity(
        load("source.json"), load("exact-target.json");
        source_model_id="referenced-source", target_model_id="referenced-target")
    @test result.status == :passed
    @test result.checked_dimensions == ["island_mapping", "voltage_reference_incidence", "rank_deficiency"]

    missing = Dict("reference_analysis" => Dict("islands" => Any[]))
    result = check_reference_singularity(
        missing, missing; source_model_id="source", target_model_id="target")
    @test result.status == :inapplicable
    @test only(result.findings).code == "I.CONTRACT.REFERENCE_SINGULARITY_NOT_APPLICABLE"
end

@testset "Scientific contracts — fixed versus state-dependent equivalents" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "state-dependent-equivalent")
    load(name) = JSON3.read(read(joinpath(fixture, name), String), Dict{String,Any})
    source, frozen, updating = load("source.json"), load("target.json"), load("exact-target.json")
    result = check_state_dependent_equivalent(
        source, frozen; source_model_id="source-state-dependent",
        target_model_id="target-frozen-base")
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.STATE_UPDATE_PROVENANCE_LOSS"
    @test result.evidence["classification"] == "frozen_state_dependent_equivalent"

    result = check_state_dependent_equivalent(
        source, updating; source_model_id="source-state-dependent",
        target_model_id="target-updating-equivalent")
    @test result.status == :passed
    @test result.checked_dimensions == ["state_domain_declared", "state_parameter_alignment",
                                       "base_state_alignment", "update_provenance_declared"]
    @test "complete_network_feasible_set" in result.unassessed_dimensions

    malformed = deepcopy(source)
    delete!(malformed["state_dependent"], "domain")
    result = check_state_dependent_equivalent(
        malformed, updating; source_model_id="source-state-dependent",
        target_model_id="target-updating-equivalent")
    @test result.status == :indeterminate
    @test only(result.findings).code == "W.CONTRACT.STATE_EQUIVALENT_INDETERMINATE"

    narrowed = deepcopy(updating)
    narrowed["state_dependent"]["domain"] = [0.9, 1.2]
    result = check_state_dependent_equivalent(
        source, narrowed; source_model_id="source-state-dependent",
        target_model_id="target-updating-equivalent")
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.STATE_DOMAIN_MISMATCH"
end

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

@testset "Scientific contracts — positive-sequence collapse applicability" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "positive-sequence-collapse")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    target = parse_bmopf(joinpath(fixture, "target.json"))
    declarations = Dict(
        "balanced_boundary_data" => true,
        "sequence_compatible_grounding" => true,
        "two_terminal_closure" => true,
        "phase_symmetric_decisions" => true,
        "positive_sequence_observations" => true,
    )
    result = check_positive_sequence_collapse(
        source, target; source_line_id="l3", target_line_id="l1",
        declarations=declarations)
    @test result.status == :passed
    @test result.contract_id == "positive_sequence_collapse_applicability"
    @test result.knowledge_ids == ["PSK-000009"]
    @test result.evidence["source_series_circulant"] === true
    @test result.evidence["relation_error"] < 1e-12
    @test "positive_sequence_relation" in result.checked_dimensions

    unbalanced = deepcopy(declarations)
    unbalanced["balanced_boundary_data"] = false
    result = check_positive_sequence_collapse(
        source, target; source_line_id="l3", target_line_id="l1",
        declarations=unbalanced)
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.SEQUENCE_DOMAIN_MISMATCH"

    nonsymmetric = deepcopy(source)
    nonsymmetric["line"]["l3"]["R_series_2_3"] = 0.09
    result = check_positive_sequence_collapse(
        nonsymmetric, target; source_line_id="l3", target_line_id="l1",
        declarations=declarations)
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.SEQUENCE_SYMMETRY_MISMATCH"

    incomplete = check_positive_sequence_collapse(
        source, target; source_line_id="l3", target_line_id="l1",
        declarations=Dict("balanced_boundary_data" => true))
    @test incomplete.status == :indeterminate
    @test only(incomplete.findings).code == "W.CONTRACT.SEQUENCE_INDETERMINATE"

    wrong_target = deepcopy(target)
    wrong_target["line"]["l1"]["R_series_1_1"] = 0.36
    result = check_positive_sequence_collapse(
        source, wrong_target; source_line_id="l3", target_line_id="l1",
        declarations=declarations)
    @test result.status == :failed
    @test only(result.findings).code == "E.CONTRACT.SEQUENCE_RELATION_MISMATCH"

    serialized = JSON3.write(contract_result_to_dict(result))
    @test occursin("positive_sequence_collapse_applicability", String(serialized))
end

@testset "Scientific contracts — Kron boundary and recovery" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "kron-boundary-grounding")
    load_network(name) = parse_bmopf(joinpath(fixture, name))
    source = load_network("source.json")
    target = load_network("transformed.json")
    exact_target = load_network("exact-target.json")
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))
    mapping = Dict("src" => "src", "load" => "load")
    recovery = Dict(
        "eliminated_terminal" => "n",
        "voltage_constraint" => "V_n = 0 at both endpoints",
        "current_recovery" => "recover I_n from retained phase voltages and source Z",
    )
    check(src, dst; kwargs...) = check_kron_boundary_recovery(
        src, dst; source_line_id="l4", target_line_id="l3",
        bus_mapping=mapping, recovery_map=recovery, kwargs...)

    @testset "floating neutral refuses a Kron-shaped target" begin
        result = check(source, target)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        @test result.evidence["source_bus_grounding"]["src"] === true
        @test result.evidence["source_bus_grounding"]["load"] === false
        @test result.evidence["boundary_relation_match"] === true
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000008"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "perfectly grounded endpoints pass the narrow boundary check" begin
        grounded_source = deepcopy(source)
        grounded_source["bus"]["load"]["perfectly_grounded_terminals"] = ["n"]
        result = check(grounded_source, exact_target)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "perfect_grounding_at_eliminated_terminal",
            "kron_boundary_impedance_relation",
            "target_terminal_coordinate_alignment",
            "recovery_obligation_declared",
        ]
        @test "internal_equipment_limits" in result.unassessed_dimensions
        @test "complete_network_feasible_set" in result.unassessed_dimensions
        @test result.evidence["classification"] == "exact_grounded_kron_boundary"
        @test result.evidence["boundary_relation_error_ohm"] < 1e-12
        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000008"]
    end

    @testset "boundary relation and recovery declarations are separate obligations" begin
        grounded_source = deepcopy(source)
        grounded_source["bus"]["load"]["perfectly_grounded_terminals"] = ["n"]
        changed = deepcopy(exact_target)
        changed["line"]["l3"]["R_series_1_1"] += 1e-3
        result = check(grounded_source, changed)
        @test result.status == :failed
        @test only(result.findings).code == "E.CONTRACT.KRON_BOUNDARY_RELATION_MISMATCH"
        @test result.evidence["boundary_relation_match"] === false

        missing_recovery = check_kron_boundary_recovery(
            grounded_source, exact_target;
            source_line_id="l4", target_line_id="l3", bus_mapping=mapping,
            recovery_map=Dict("eliminated_terminal" => "n",
                              "voltage_constraint" => "V_n = 0 at both endpoints"),
        )
        @test missing_recovery.status == :indeterminate
        @test only(missing_recovery.findings).code ==
              "W.CONTRACT.KRON_RECOVERY_INDETERMINATE"

        wrong_recovery = deepcopy(recovery)
        wrong_recovery["eliminated_terminal"] = "x"
        wrong = check_kron_boundary_recovery(
            grounded_source, exact_target;
            source_line_id="l4", target_line_id="l3", bus_mapping=mapping,
            recovery_map=wrong_recovery,
        )
        @test wrong.status == :indeterminate
        @test only(wrong.findings).code == "W.CONTRACT.KRON_RECOVERY_INDETERMINATE"
    end

    @testset "unsupported shapes and mappings refuse explicitly" begin
        grounded_source = deepcopy(source)
        grounded_source["bus"]["load"]["perfectly_grounded_terminals"] = ["n"]
        bad_phase = check_kron_boundary_recovery(
            grounded_source, exact_target;
            source_line_id="l4", target_line_id="l3", bus_mapping=mapping,
            phase_terminals=["a", "b"], recovery_map=recovery,
        )
        @test bad_phase.status == :inapplicable
        @test only(bad_phase.findings).code == "I.CONTRACT.KRON_NOT_APPLICABLE"

        incomplete = check_kron_boundary_recovery(
            grounded_source, exact_target;
            source_line_id="l4", target_line_id="l3",
            bus_mapping=Dict("src" => "src"), recovery_map=recovery,
        )
        @test incomplete.status == :indeterminate
        @test only(incomplete.findings).code == "W.CONTRACT.KRON_INDETERMINATE"

        shunted = deepcopy(exact_target)
        shunted["line"]["l3"]["G_from_1_1"] = 0.01
        shunted_result = check(grounded_source, shunted)
        @test shunted_result.status == :inapplicable
        @test only(shunted_result.findings).code == "I.CONTRACT.KRON_NOT_APPLICABLE"

        bad_target_order = deepcopy(exact_target)
        bad_target_order["line"]["l3"]["terminal_map_from"] = ["b", "a", "c"]
        bad_target_order["line"]["l3"]["terminal_map_to"] = ["b", "a", "c"]
        order_result = check(grounded_source, bad_target_order)
        @test order_result.status == :inapplicable
        @test only(order_result.findings).code == "I.CONTRACT.KRON_NOT_APPLICABLE"

        @test_throws ArgumentError check(grounded_source, exact_target; rtol=-1.0)
    end

    @testset "declared tolerances are explicit" begin
        grounded_source = deepcopy(source)
        grounded_source["bus"]["load"]["perfectly_grounded_terminals"] = ["n"]
        near = deepcopy(exact_target)
        near["line"]["l3"]["R_series_1_1"] += 1e-7
        @test check(grounded_source, near; atol=1e-6, rtol=0.0).status == :passed
        @test check(grounded_source, near; atol=1e-10, rtol=0.0).status == :failed
    end
end

@testset "Scientific contracts — decision-preservation manifest" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "decision-manifest-terminal-only")
    load_manifest(name) = JSON3.read(
        read(joinpath(fixture, name), String), Dict{String,Any})
    overclaimed = load_manifest("transformed.json")
    complete = load_manifest("exact-target.json")
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))

    @testset "terminal evidence does not complete a decision claim" begin
        result = check_decision_preservation_manifest(overclaimed)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        @test result.evidence["missing_dimensions"] ==
              String.(expected.missing_dimensions)
        @test isempty(result.evidence["dimensions_missing_support"])
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000007"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "an evidence-complete declaration passes narrowly" begin
        result = check_decision_preservation_manifest(complete)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "manifest_identity_and_claim_scope",
            "required_dimension_dispositions",
            "verified_evidence_reference_presence",
            "not_required_justification_presence",
        ]
        @test "truth_or_independence_of_cited_evidence" in
              result.unassessed_dimensions
        @test "source_and_target_feasible_set_equivalence" in
              result.unassessed_dimensions
        @test "objective_value_or_optimizer_equivalence" in
              result.unassessed_dimensions
        @test result.evidence["classification"] ==
              "decision_manifest_evidence_complete"
        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000007"]
    end

    @testset "justified not-required dimensions close an obligation" begin
        feasibility_only = deepcopy(complete)
        feasibility_only["dimensions"]["objective"] = Dict{String,Any}(
            "status" => "not_required",
            "justification" => "The declared study is feasibility-only with no ranked objective.",
        )
        @test check_decision_preservation_manifest(feasibility_only).status == :passed

        missing_justification = deepcopy(feasibility_only)
        missing_justification["dimensions"]["objective"] =
            Dict{String,Any}("status" => "not_required")
        missing_result = check_decision_preservation_manifest(missing_justification)
        @test missing_result.status == :failed
        @test only(missing_result.findings).code ==
              "E.CONTRACT.DECISION_MANIFEST_EVIDENCE_GAP"
        @test missing_result.evidence["dimensions_missing_support"] == ["objective"]
    end

    @testset "explicit unresolved obligations contradict exactness" begin
        unresolved = deepcopy(complete)
        unresolved["dimensions"]["constraints"] =
            Dict{String,Any}("status" => "not_preserved")
        unresolved["dimensions"]["recovery"] =
            Dict{String,Any}("status" => "unassessed")
        result = check_decision_preservation_manifest(unresolved)
        @test result.status == :failed
        @test [finding.code for finding in result.findings] ==
              ["E.CONTRACT.DECISION_MANIFEST_UNRESOLVED_OBLIGATION"]
        @test result.evidence["classification"] == "unresolved_obligation"
        @test result.evidence["unresolved_dimensions"] == ["constraints", "recovery"]

        mixed = deepcopy(overclaimed)
        mixed["dimensions"]["constraints"] =
            Dict{String,Any}("status" => "unassessed")
        mixed_result = check_decision_preservation_manifest(mixed)
        @test [finding.code for finding in mixed_result.findings] == [
            "E.CONTRACT.DECISION_MANIFEST_EVIDENCE_GAP",
            "E.CONTRACT.DECISION_MANIFEST_UNRESOLVED_OBLIGATION",
        ]
        @test mixed_result.evidence["classification"] ==
              "evidence_gap_and_unresolved_obligation"
    end

    @testset "narrow claims and malformed inputs refuse explicitly" begin
        terminal_only = deepcopy(overclaimed)
        terminal_only["claim"]["exactness_object"] = "terminal_behavior"
        terminal_result = check_decision_preservation_manifest(terminal_only)
        @test terminal_result.status == :inapplicable
        @test only(terminal_result.findings).code ==
              "I.CONTRACT.DECISION_MANIFEST_NOT_APPLICABLE"

        inner = deepcopy(complete)
        inner["claim"]["classification"] = "inner"
        @test check_decision_preservation_manifest(inner).status == :inapplicable

        missing_identity = deepcopy(complete)
        delete!(missing_identity, "source_model_id")
        identity_result = check_decision_preservation_manifest(missing_identity)
        @test identity_result.status == :indeterminate
        @test only(identity_result.findings).code ==
              "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE"

        malformed = deepcopy(complete)
        malformed["dimensions"]["constraints"] = "verified"
        @test check_decision_preservation_manifest(malformed).status == :indeterminate

        unsupported = deepcopy(complete)
        unsupported["dimensions"]["constraints"] =
            Dict{String,Any}("status" => "assumed")
        @test check_decision_preservation_manifest(unsupported).status == :indeterminate

        missing_evidence = deepcopy(complete)
        missing_evidence["dimensions"]["constraints"] =
            Dict{String,Any}("status" => "verified", "evidence_ids" => String[])
        evidence_result = check_decision_preservation_manifest(missing_evidence)
        @test evidence_result.status == :failed
        @test evidence_result.evidence["dimensions_missing_support"] == ["constraints"]
    end
end

@testset "Scientific contracts — transformer tap-domain preservation" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "transformer-tap-domain-loss")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    frozen = parse_bmopf(joinpath(fixture, "transformed.json"))
    exact = parse_bmopf(joinpath(fixture, "exact-target.json"))
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))

    check(target; kwargs...) = check_transformer_tap_domain_preservation(
        source, target; source_subtype="single_phase", source_id="tx", kwargs...)

    @testset "freezing the start value is an inner restriction with a witness" begin
        result = check(frozen)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        atol = Float64(expected.absolute_tolerance)
        @test result.evidence["source_domain"]["minimum"] ≈
              expected.source_domain.minimum atol=atol
        @test result.evidence["source_domain"]["maximum"] ≈
              expected.source_domain.maximum atol=atol
        @test result.evidence["target_domain"]["minimum"] ≈
              expected.target_domain.minimum atol=atol
        @test result.evidence["target_domain"]["maximum"] ≈
              expected.target_domain.maximum atol=atol
        witness = result.evidence["witness"]
        @test witness["tap"] ≈ expected.witness.tap atol=atol
        @test witness["source_admissible"] === true
        @test witness["target_admissible"] === false
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000005"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "the complete interval passes independently of the start" begin
        result = check(exact)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "mapped_transformer_base_factor_identity",
            "tap_start_admissibility",
            "continuous_tap_decision_domain",
        ]
        @test "pointwise_terminal_equations" in result.unassessed_dimensions
        @test "network_feasible_set" in result.unassessed_dimensions
        @test "optimal_tap" in result.unassessed_dimensions
        @test result.evidence["classification"] ==
              "continuous_tap_domain_preserved"

        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000005"]
    end

    @testset "other domain mismatches are classified" begin
        wider = deepcopy(exact)
        wider["transformer"]["single_phase"]["tx"]["tap_min"] = 0.9
        @test check(wider).evidence["classification"] == "outer_extension"

        shifted = deepcopy(exact)
        shifted_tx = shifted["transformer"]["single_phase"]["tx"]
        shifted_tx["tap_min"] = 1.0
        shifted_tx["tap_max"] = 1.1
        @test check(shifted).evidence["classification"] ==
              "shifted_partial_overlap"

        disjoint = deepcopy(exact)
        disjoint_tx = disjoint["transformer"]["single_phase"]["tx"]
        disjoint_tx["tap"] = 1.2
        disjoint_tx["tap_min"] = 1.15
        disjoint_tx["tap_max"] = 1.25
        @test check(disjoint).evidence["classification"] == "disjoint_domain"
    end

    @testset "applicability and evidence failures refuse explicitly" begin
        fixed_source = deepcopy(source)
        delete!(fixed_source["transformer"]["single_phase"]["tx"], "tap_min")
        delete!(fixed_source["transformer"]["single_phase"]["tx"], "tap_max")
        inapplicable = check_transformer_tap_domain_preservation(
            fixed_source, frozen;
            source_subtype="single_phase", source_id="tx")
        @test inapplicable.status == :inapplicable
        @test only(inapplicable.findings).code ==
              "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE"

        missing = deepcopy(exact)
        delete!(missing["transformer"]["single_phase"], "tx")
        indeterminate = check(missing)
        @test indeterminate.status == :indeterminate
        @test only(indeterminate.findings).code ==
              "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE"

        changed_base = deepcopy(exact)
        changed_base["transformer"]["single_phase"]["tx"]["v_nom_to"] = 230.0
        base_result = check(changed_base)
        @test base_result.status == :inapplicable
        @test only(base_result.findings).code ==
              "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE"

        invalid = deepcopy(exact)
        invalid["transformer"]["single_phase"]["tx"]["tap"] = 1.2
        invalid_result = check(invalid)
        @test invalid_result.status == :indeterminate
        @test only(invalid_result.findings).code ==
              "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE"

        @test_throws ArgumentError check(exact; atol=-1.0)
    end

    @testset "endpoint tolerance is explicit" begin
        near = deepcopy(exact)
        near["transformer"]["single_phase"]["tx"]["tap_min"] = 0.95 + 1e-10
        @test check(near; atol=1e-9, rtol=0.0).status == :passed
        @test check(near; atol=1e-12, rtol=0.0).status == :failed
    end
end

@testset "Scientific contracts — transformer winding conventions" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative",
                       "transformer-winding-role-swap")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    swapped = parse_bmopf(joinpath(fixture, "transformed.json"))
    exact = parse_bmopf(joinpath(fixture, "exact-target.json"))
    expected = JSON3.read(read(joinpath(fixture, "expected.json"), String))
    bus_mapping = Dict("primary" => "primary", "secondary" => "secondary")

    check_winding(target; kwargs...) =
        check_transformer_winding_convention_preservation(
            source,
            target;
            source_subtype="wye_delta",
            source_id="tx",
            target_id="tx_equiv",
            bus_mapping=bus_mapping,
            kwargs...,
        )

    @testset "a bare endpoint swap changes typed winding incidence" begin
        result = check_winding(swapped)
        @test result isa ScientificContractResult
        @test result.status == :failed
        @test result.contract_id == expected.contract_id
        @test result.knowledge_ids == String.(expected.knowledge_ids)
        @test [finding.code for finding in result.findings] ==
              String.(expected.finding_codes)
        @test result.evidence["classification"] == expected.classification
        @test result.evidence["incidence_match"] === false
        @test result.evidence["effective_coil_ratio_match"] === true
        @test isempty(result.evidence["reference_voltage_mismatch_sides"])
        source_core = first(result.evidence["source_mapped_incidence"])
        target_core = first(result.evidence["target_incidence"])
        @test first(source_core["winding_1"])["bus"] == expected.source_from_bus
        @test first(source_core["winding_2"])["bus"] == expected.source_to_bus
        @test first(target_core["winding_1"])["bus"] == expected.target_from_bus
        @test first(target_core["winding_2"])["bus"] == expected.target_to_bus
        detail = only(result.findings).detail
        @test detail["knowledge_ids"] == ["PSK-000006"]
        @test !isempty(detail["invalid_inferences"])
        @test !isempty(detail["recommended_checks"])
    end

    @testset "the scoped winding convention passes narrowly" begin
        result = check_winding(exact)
        @test result.status == :passed
        @test isempty(result.findings)
        @test result.checked_dimensions == [
            "mapped_winding_side_identity_and_orientation",
            "ordered_terminal_to_coil_incidence",
            "nominal_winding_reference_voltages",
            "fixed_effective_coil_ratio",
        ]
        @test "series_leakage_parameters" in result.unassessed_dimensions
        @test "excitation_shunt_placement_and_value" in result.unassessed_dimensions
        @test "complete_terminal_admittance_or_ideal_constraints" in
              result.unassessed_dimensions
        @test result.evidence["classification"] == "winding_convention_preserved"

        different_unassessed = deepcopy(exact)
        tx = different_unassessed["transformer"]["wye_delta"]["tx_equiv"]
        tx["x_series_from"] = 9.0
        tx["s_rating"] = 750000.0
        @test check_winding(different_unassessed).status == :passed

        decoded = JSON3.read(JSON3.write(contract_result_to_dict(result)))
        @test decoded.status == "passed"
        @test decoded.knowledge_ids == ["PSK-000006"]
    end

    @testset "reference-base and terminal-map changes fail separately" begin
        changed_base = deepcopy(exact)
        changed_base["transformer"]["wye_delta"]["tx_equiv"]["v_nom_to"] = 230.0
        base_result = check_winding(changed_base)
        @test base_result.status == :failed
        @test [finding.code for finding in base_result.findings] ==
              ["E.CONTRACT.TRANSFORMER_WINDING_BASE_RATIO_MISMATCH"]
        @test base_result.evidence["classification"] ==
              "winding_base_ratio_mismatch"
        @test base_result.evidence["reference_voltage_mismatch_sides"] == ["to"]
        @test base_result.evidence["effective_coil_ratio_match"] === false

        changed_incidence = deepcopy(exact)
        changed_tx = changed_incidence["transformer"]["wye_delta"]["tx_equiv"]
        changed_tx["terminal_map_to"] = ["a", "c", "b"]
        incidence_result = check_winding(changed_incidence)
        @test incidence_result.status == :failed
        @test [finding.code for finding in incidence_result.findings] ==
              ["E.CONTRACT.TRANSFORMER_WINDING_INCIDENCE_MISMATCH"]
        @test incidence_result.evidence["classification"] ==
              "winding_incidence_mismatch"
    end

    @testset "explicit terminal relabelling is supported" begin
        renamed = deepcopy(exact)
        tx = renamed["transformer"]["wye_delta"]["tx_equiv"]
        tx["terminal_map_from"] = ["1", "2", "3", "N"]
        tx["terminal_map_to"] = ["1", "2", "3"]
        result = check_winding(
            renamed;
            terminal_mapping=Dict("a" => "1", "b" => "2", "c" => "3", "n" => "N"),
        )
        @test result.status == :passed
        @test result.evidence["incidence_match"] === true
    end

    @testset "unsupported or incomplete inputs refuse explicitly" begin
        incomplete = check_transformer_winding_convention_preservation(
            source,
            exact;
            source_subtype="wye_delta",
            source_id="tx",
            target_id="tx_equiv",
            bus_mapping=Dict("primary" => "primary"),
        )
        @test incomplete.status == :indeterminate
        @test only(incomplete.findings).code ==
              "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE"

        collapsed = check_winding(
            exact;
            terminal_mapping=Dict("a" => "x", "b" => "x"),
        )
        @test collapsed.status == :inapplicable
        @test only(collapsed.findings).code ==
              "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE"

        adjustable = deepcopy(source)
        tx = adjustable["transformer"]["wye_delta"]["tx"]
        tx["tap_min"] = 0.95
        tx["tap_max"] = 1.05
        adjustable_result = check_transformer_winding_convention_preservation(
            adjustable,
            exact;
            source_subtype="wye_delta",
            source_id="tx",
            target_id="tx_equiv",
            bus_mapping=bus_mapping,
        )
        @test adjustable_result.status == :inapplicable
        @test only(adjustable_result.findings).code ==
              "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE"

        missing_ref = deepcopy(exact)
        delete!(missing_ref["transformer"]["wye_delta"]["tx_equiv"], "v_nom_to")
        missing_result = check_winding(missing_ref)
        @test missing_result.status == :indeterminate
        @test only(missing_result.findings).code ==
              "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE"

        subtype_result = check_transformer_winding_convention_preservation(
            source,
            exact;
            source_subtype="center_tap",
            source_id="tx",
            target_subtype="center_tap",
            target_id="tx_equiv",
            bus_mapping=bus_mapping,
        )
        @test subtype_result.status == :inapplicable
        @test only(subtype_result.findings).code ==
              "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE"

        @test_throws ArgumentError check_winding(exact; rtol=-1.0)
    end

    @testset "reference-voltage tolerance is explicit" begin
        near = deepcopy(exact)
        near["transformer"]["wye_delta"]["tx_equiv"]["v_nom_to"] += 1e-7
        @test check_winding(near; atol=1e-6, rtol=0.0).status == :passed
        @test check_winding(near; atol=1e-10, rtol=0.0).status == :failed
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
