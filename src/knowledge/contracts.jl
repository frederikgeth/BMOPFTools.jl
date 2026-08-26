# Scientific-contract checks linking concrete BMOPF models to broader,
# repository-external scientific knowledge. This file contains executable
# semantics only; claims, literature, and long-form explanations remain in
# multi-graph-book.

const _PARALLEL_MEMBER_LIMIT_CONTRACT = "parallel_member_limit_preservation"
const _PARALLEL_MEMBER_LIMIT_PSK = "PSK-000001"
const _NEUTRAL_GROUND_CONTRACT = "neutral_ground_reference_preservation"
const _NEUTRAL_GROUND_PSK = "PSK-000002"
const _CLAIMED_SOLUTION_CONTRACT = "claimed_solution_validity"
const _CLAIMED_SOLUTION_PSK = "PSK-000003"
const _LOAD_VOLTAGE_BASE_CONTRACT = "load_voltage_base_consistency"
const _LOAD_VOLTAGE_BASE_PSK = "PSK-000004"
const _TRANSFORMER_TAP_DOMAIN_CONTRACT = "transformer_tap_domain_preservation"
const _TRANSFORMER_TAP_DOMAIN_PSK = "PSK-000005"
const _TRANSFORMER_TAP_SUBTYPES = ("single_phase", "center_tap", "wye_delta", "delta_wye")
const _TRANSFORMER_WINDING_CONVENTION_CONTRACT = "transformer_winding_convention_preservation"
const _TRANSFORMER_WINDING_CONVENTION_PSK = "PSK-000006"
const _TRANSFORMER_WINDING_CONVENTION_SUBTYPES = ("single_phase", "wye_delta", "delta_wye")
const _DECISION_MANIFEST_CONTRACT = "decision_preservation_manifest_completeness"
const _DECISION_MANIFEST_PSK = "PSK-000007"
const _DECISION_MANIFEST_DIMENSIONS = (
    "admissible_domain",
    "terminal_behavior",
    "observations",
    "constraints",
    "decision_variables",
    "objective",
    "recovery",
)
const _DECISION_MANIFEST_STATUSES =
    ("verified", "not_required", "not_preserved", "unassessed")
const _KRON_BOUNDARY_CONTRACT = "kron_boundary_recovery_preservation"
const _KRON_BOUNDARY_PSK = "PSK-000008"
const _POSITIVE_SEQUENCE_CONTRACT = "positive_sequence_collapse_applicability"
const _POSITIVE_SEQUENCE_PSK = "PSK-000009"
const _STATE_EQUIVALENT_CONTRACT = "state_dependent_equivalent_provenance"
const _STATE_EQUIVALENT_PSK = "PSK-000010"
const _REFERENCE_SINGULARITY_CONTRACT = "reference_singularity_validation"
const _REFERENCE_SINGULARITY_PSK = "PSK-000011"
const _PERMUTATION_CONTRACT = "terminal_permutation_invariance"
const _PERMUTATION_PSK = "PSK-000012"
const _FEASIBILITY_CONTRACT = "solved_network_feasibility_validation"
const _FEASIBILITY_PSK = "PSK-000013"
const _UNIT_BASE_CONTRACT = "unit_base_serialization_invariance"
const _UNIT_BASE_PSK = "PSK-000014"
const _CONTRACT_STATUSES = (:passed, :failed, :inapplicable, :indeterminate)

"""
    ScientificContractResult

Structured result of an executable scientific-contract check.

`status` is one of `:passed`, `:failed`, `:inapplicable`, or `:indeterminate`:

- `:passed` — every implemented obligation held in the declared domain;
- `:failed` — an implemented obligation was violated with recorded evidence;
- `:inapplicable` — a domain precondition did not hold, so no preservation
  conclusion was drawn;
- `:indeterminate` — the supplied models or mapping lacked evidence needed to
  decide the implemented obligation.

`passed` applies only to `checked_dimensions`; it says nothing about the
dimensions listed in `unassessed_dimensions`.
"""
struct ScientificContractResult
    contract_id::String
    status::Symbol
    knowledge_ids::Vector{String}
    checked_dimensions::Vector{String}
    unassessed_dimensions::Vector{String}
    findings::Vector{Finding}
    evidence::Dict{String,Any}

    function ScientificContractResult(contract_id, status, knowledge_ids,
                                      checked_dimensions, unassessed_dimensions,
                                      findings, evidence)
        status in _CONTRACT_STATUSES || throw(ArgumentError(
            "scientific-contract status must be one of $(_CONTRACT_STATUSES), got $(repr(status))"))
        new(String(contract_id), status, String.(knowledge_ids),
            String.(checked_dimensions), String.(unassessed_dimensions),
            Vector{Finding}(findings), Dict{String,Any}(evidence))
    end
end

function _kron_boundary_result(
        status::Symbol, findings::Vector{Finding}, evidence::Dict{String,Any};
        checked=String[])
    ScientificContractResult(
        _KRON_BOUNDARY_CONTRACT,
        status,
        [_KRON_BOUNDARY_PSK],
        checked,
        [
            "internal_asset_identity_and_state",
            "internal_equipment_limits",
            "internal_protection_quantities",
            "state_dependent_or_nonlinear_factors",
            "complete_network_feasible_set",
            "objective_or_optimizer_equivalence",
            "solver_status_or_optimality",
        ],
        findings,
        evidence,
    )
end

function _kron_boundary_finding(code::String, severity::Severity,
                                line_id, message::String,
                                detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :line,
            line_id isa String && !isempty(line_id) ? line_id : nothing,
            message, detail)
end

function _kron_boundary_refusal(status::Symbol, code::String,
                                severity::Severity, message::String,
                                mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_KRON_BOUNDARY_PSK],
        "contract_id" => _KRON_BOUNDARY_CONTRACT,
        "line_mapping" => mapping,
        "reason" => reason,
        "invalid_inferences" => [
            "A three-wire target with a Kron-shaped impedance does not establish an exact reduction when an eliminated neutral is not pinned at every connection point.",
            "A boundary relation does not by itself preserve internal line quantities, limits, protection observations, or source provenance.",
        ],
        "recommended_checks" => [
            "Confirm perfect grounding of the eliminated terminal at every source connection point.",
            "Compare the target boundary impedance with the declared Schur complement and retain an explicit recovery map.",
            "Use the full four-wire source model for finite-grounding or floating-neutral studies.",
        ],
    )
    line_id = get(mapping, "target_line_id", nothing)
    finding = _kron_boundary_finding(code, severity, line_id, message, detail)
    _kron_boundary_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "line_mapping" => mapping,
        "reason" => reason,
    ))
end

function _kron_boundary_matrix(net::Dict{String,Any}, line_id::String)
    lines = get(net, "line", Dict())
    line = get(lines, line_id, nothing)
    line isa Dict{String,Any} || return (nothing, nothing, :indeterminate,
        "line '$line_id' does not resolve to a BMOPF line record")
    linecodes = get(net, "linecode", Dict())
    Z, n = _line_z_complex(line, linecodes)
    Z isa AbstractMatrix || return (nothing, line, :indeterminate,
        "line '$line_id' has no resolvable series impedance")
    (size(Z, 1) == n && size(Z, 2) == n) || return (nothing, line, :indeterminate,
        "line '$line_id' has a non-square series impedance")
    all(isfinite(real(value)) && isfinite(imag(value)) for value in Z) ||
        return (nothing, line, :indeterminate,
            "line '$line_id' has non-finite series impedance values")
    (Z, line, :applicable, "")
end

function _kron_boundary_bus(net::Dict{String,Any}, bus_id::String)
    buses = get(net, "bus", Dict())
    bus = get(buses, bus_id, nothing)
    bus isa Dict{String,Any} || return (nothing, :indeterminate,
        "bus '$bus_id' does not resolve to a BMOPF bus record")
    (bus, :applicable, "")
end

function _kron_boundary_nonzero_shunt(line::Dict{String,Any}, linecodes,
                                      atol::Float64)
    Yfr, Yto = _line_shunt_complex(line, linecodes)
    for (side, Y) in (("from", Yfr), ("to", Yto))
        Y !== nothing && norm(Y) > atol &&
            return (false, "line has a nonzero $side-side shunt")
    end
    (true, "")
end

"""
    check_kron_boundary_recovery(source, target;
        source_line_id, target_line_id, bus_mapping,
        phase_terminals=["a", "b", "c"], neutral_terminal="n",
        terminal_mapping=Dict(), recovery_map, atol=1e-9, rtol=1e-8)
        -> ScientificContractResult

Check the initial executable portion of the Kron boundary/recovery contract
(`PSK-000008`). The supported case is a single four-conductor source line and
three-conductor target line with aligned phase terminal coordinates, no line
shunts, and the source neutral perfectly grounded at both source buses. The
target series impedance must equal the Schur complement obtained by eliminating
the source neutral row and column. An explicit recovery-map declaration for the
eliminated terminal is also required.

This is a boundary relation check, not a claim that Kron reduction preserves
internal equipment, protection, state, limits, decisions, objectives, or
solver results. Floating or finite-grounded neutrals return `:failed` with
`E.CONTRACT.KRON_GROUNDING_PRECONDITION`; missing declarations return
`:indeterminate`, and unsupported wire or shunt shapes return `:inapplicable`.
"""
function check_kron_boundary_recovery(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_line_id::AbstractString,
        target_line_id::AbstractString,
        bus_mapping::AbstractDict,
        phase_terminals::AbstractVector{<:AbstractString}=["a", "b", "c"],
        neutral_terminal::AbstractString="n",
        terminal_mapping::AbstractDict=Dict{String,String}(),
        recovery_map::AbstractDict,
        atol::Real=1e-9,
        rtol::Real=1e-8)::ScientificContractResult
    atol_f, rtol_f = Float64(atol), Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))
    source_key, target_key = String(source_line_id), String(target_line_id)
    phases = String.(phase_terminals)
    neutral = String(neutral_terminal)
    buses = Dict{String,String}(string(key) => string(value) for (key, value) in bus_mapping)
    terminals = Dict{String,String}(string(key) => string(value) for (key, value) in terminal_mapping)
    mapping = Dict{String,Any}(
        "source_line_id" => source_key,
        "target_line_id" => target_key,
        "bus_mapping" => buses,
        "phase_terminals" => phases,
        "neutral_terminal" => neutral,
        "terminal_mapping" => terminals,
    )
    length(phases) == 3 && neutral ∉ phases ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: exactly three distinct phase terminals and one distinct neutral are required.",
            mapping, "phase_terminals must contain three distinct labels excluding neutral_terminal")
    length(unique(phases)) == 3 ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: phase terminals are not distinct.",
            mapping, "phase terminal labels are duplicated")

    Zs, source_line, source_status, source_reason =
        _kron_boundary_matrix(source, source_key)
    Zs === nothing && return _kron_boundary_refusal(
        source_status === :inapplicable ? :inapplicable : :indeterminate,
        source_status === :inapplicable ? "I.CONTRACT.KRON_NOT_APPLICABLE" :
            "W.CONTRACT.KRON_INDETERMINATE",
        source_status === :inapplicable ? INFO : WARNING,
        "Kron boundary/recovery contract is $(source_status): $source_reason.",
        mapping, source_reason)
    Zt, target_line, target_status, target_reason =
        _kron_boundary_matrix(target, target_key)
    Zt === nothing && return _kron_boundary_refusal(
        target_status === :inapplicable ? :inapplicable : :indeterminate,
        target_status === :inapplicable ? "I.CONTRACT.KRON_NOT_APPLICABLE" :
            "W.CONTRACT.KRON_INDETERMINATE",
        target_status === :inapplicable ? INFO : WARNING,
        "Kron boundary/recovery contract is $(target_status): $target_reason.",
        mapping, target_reason)
    size(Zs, 1) == 4 || return _kron_boundary_refusal(
        :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
        "Kron boundary/recovery contract is not applicable: source line must have four conductors.",
        mapping, "source line has $(size(Zs, 1)) conductors")
    size(Zt, 1) == 3 || return _kron_boundary_refusal(
        :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
        "Kron boundary/recovery contract is not applicable: target line must have three conductors.",
        mapping, "target line has $(size(Zt, 1)) conductors")

    source_from = get(source_line, "bus_from", nothing)
    source_to = get(source_line, "bus_to", nothing)
    target_from = get(target_line, "bus_from", nothing)
    target_to = get(target_line, "bus_to", nothing)
    all(item isa AbstractString for item in (source_from, source_to, target_from, target_to)) ||
        return _kron_boundary_refusal(
            :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
            "Kron boundary/recovery contract is indeterminate: line endpoint declarations are incomplete.",
            mapping, "source or target line bus_from/bus_to is missing")
    source_from, source_to = String(source_from), String(source_to)
    target_from, target_to = String(target_from), String(target_to)
    source_from != source_to && target_from != target_to ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: each line must connect two distinct buses.",
            mapping, "source or target line is a self-loop")
    haskey(buses, source_from) && haskey(buses, source_to) ||
        return _kron_boundary_refusal(
            :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
            "Kron boundary/recovery contract is indeterminate: bus mapping is incomplete.",
            mapping, "bus_mapping omits a source line endpoint")
    (buses[source_from] == target_from && buses[source_to] == target_to) ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: target line endpoints do not follow the declared bus mapping.",
            mapping, "target line endpoint orientation differs from bus_mapping")

    source_from_map = String.(get(source_line, "terminal_map_from", String[]))
    source_to_map = String.(get(source_line, "terminal_map_to", String[]))
    target_from_map = String.(get(target_line, "terminal_map_from", String[]))
    target_to_map = String.(get(target_line, "terminal_map_to", String[]))
    source_from_map == source_to_map && length(source_from_map) == 4 ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: source terminal maps must have the same four ordered conductors at both ends.",
            mapping, "source terminal maps are missing, unequal, or not four-conductor")
    target_from_map == target_to_map && length(target_from_map) == 3 ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: target terminal maps must have the same three ordered phase conductors at both ends.",
            mapping, "target terminal maps are missing, unequal, or not three-conductor")
    Set(source_from_map) == Set(vcat(phases, [neutral])) ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: source terminal map does not contain the declared phases and neutral.",
            mapping, "source terminal map does not match declared conductor labels")
    expected_target_terms = [get(terminals, phase, phase) for phase in phases]
    target_from_map == expected_target_terms ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: target phase terminal order does not follow terminal_mapping.",
            mapping, "target phase terminal labels or order differs from terminal_mapping")
    length(unique(expected_target_terms)) == 3 ||
        return _kron_boundary_refusal(
            :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
            "Kron boundary/recovery contract is not applicable: terminal_mapping is not one-to-one.",
            mapping, "terminal_mapping collapses phase labels")

    source_buses = get(source, "bus", Dict())
    source_bus_from, status_from, reason_from = _kron_boundary_bus(source, source_from)
    source_bus_from === nothing && return _kron_boundary_refusal(
        :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
        "Kron boundary/recovery contract is indeterminate: $reason_from.",
        mapping, reason_from)
    source_bus_to, status_to, reason_to = _kron_boundary_bus(source, source_to)
    source_bus_to === nothing && return _kron_boundary_refusal(
        :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
        "Kron boundary/recovery contract is indeterminate: $reason_to.",
        mapping, reason_to)
    function bus_has_ground(bus)
        names = String.(get(bus, "terminal_names", String[]))
        grounded = String.(get(bus, "perfectly_grounded_terminals", String[]))
        neutral in names && neutral in grounded
    end
    grounded_from, grounded_to = bus_has_ground(source_bus_from), bus_has_ground(source_bus_to)

    linecodes_source = get(source, "linecode", Dict())
    linecodes_target = get(target, "linecode", Dict())
    source_shunt_ok, source_shunt_reason =
        _kron_boundary_nonzero_shunt(source_line, linecodes_source, atol_f)
    target_shunt_ok, target_shunt_reason =
        _kron_boundary_nonzero_shunt(target_line, linecodes_target, atol_f)
    (source_shunt_ok && target_shunt_ok) || return _kron_boundary_refusal(
        :inapplicable, "I.CONTRACT.KRON_NOT_APPLICABLE", INFO,
        "Kron boundary/recovery contract is not applicable: the initial exact series-only domain excludes nonzero line shunts.",
        mapping, !source_shunt_ok ? source_shunt_reason : target_shunt_reason)

    n_source_from = findfirst(==(neutral), source_from_map)
    n_source_from === nothing && return _kron_boundary_refusal(
        :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
        "Kron boundary/recovery contract is indeterminate: source neutral position is unavailable.",
        mapping, "neutral terminal is absent from source terminal map")
    phase_indices = [findfirst(==(phase), source_from_map) for phase in phases]
    all(index !== nothing for index in phase_indices) || return _kron_boundary_refusal(
        :indeterminate, "W.CONTRACT.KRON_INDETERMINATE", WARNING,
        "Kron boundary/recovery contract is indeterminate: a declared phase is absent from source terminal map.",
        mapping, "phase terminal position is unavailable")
    pidx = Int[index for index in phase_indices]
    nidx = Int(n_source_from)
    Zk = Zs[pidx, pidx] - Zs[pidx, nidx:nidx] *
         (Zs[nidx:nidx, nidx:nidx] \ Zs[nidx:nidx, pidx])
    target_indices = Int[findfirst(==(label), target_from_map) for label in expected_target_terms]
    target_ordered = Zt[target_indices, target_indices]
    relation_error = norm(target_ordered - Zk)
    relation_tolerance = atol_f + rtol_f * max(norm(Zk), norm(target_ordered), 1.0)
    recovery_fields = Dict{String,Any}()
    for key in ("eliminated_terminal", "voltage_constraint", "current_recovery")
        value = get(recovery_map, key, nothing)
        _decision_manifest_nonempty_string(value) || return _kron_boundary_refusal(
            :indeterminate, "W.CONTRACT.KRON_RECOVERY_INDETERMINATE", WARNING,
            "Kron boundary/recovery contract is indeterminate: recovery-map field '$key' is missing.",
            mapping, "recovery_map.$key must be a nonempty string")
        recovery_fields[key] = String(value)
    end
    recovery_fields["eliminated_terminal"] == neutral || return _kron_boundary_refusal(
        :indeterminate, "W.CONTRACT.KRON_RECOVERY_INDETERMINATE", WARNING,
        "Kron boundary/recovery contract is indeterminate: recovery map names a different eliminated terminal.",
        mapping, "recovery_map.eliminated_terminal does not match neutral_terminal")

    evidence = Dict{String,Any}(
        "line_mapping" => mapping,
        "source_bus_grounding" => Dict(
            source_from => grounded_from, source_to => grounded_to),
        "source_conductor_order" => source_from_map,
        "target_conductor_order" => target_from_map,
        "eliminated_neutral_index" => nidx,
        "retained_phase_indices" => pidx,
        "source_impedance_ohm" => Zs,
        "target_impedance_ohm" => target_ordered,
        "schur_complement_impedance_ohm" => Zk,
        "boundary_relation_error_ohm" => relation_error,
        "boundary_relation_tolerance_ohm" => relation_tolerance,
        "recovery_map" => recovery_fields,
        "perfect_grounding_precondition" => grounded_from && grounded_to,
        "boundary_relation_match" => relation_error <= relation_tolerance,
    )
    checked = [
        "perfect_grounding_at_eliminated_terminal",
        "kron_boundary_impedance_relation",
        "target_terminal_coordinate_alignment",
        "recovery_obligation_declared",
    ]
    findings = Finding[]
    if !grounded_from || !grounded_to
        push!(findings, _kron_boundary_finding(
            "E.CONTRACT.KRON_GROUNDING_PRECONDITION", ERROR, target_key,
            "Kron boundary claim is invalid: the eliminated neutral is not perfectly grounded at every source line endpoint.",
            merge(copy(evidence), Dict{String,Any}(
                "knowledge_ids" => [_KRON_BOUNDARY_PSK],
                "contract_id" => _KRON_BOUNDARY_CONTRACT,
                "invalid_inferences" => [
                    "The eliminated neutral is not pinned to zero at every source connection point.",
                ],
                "recommended_checks" => [
                    "Retain the four-wire model for floating or finite-grounded neutrals, or prove the grounding precondition.",
                ],
            )),
        ))
    end
    if relation_error > relation_tolerance
        push!(findings, _kron_boundary_finding(
            "E.CONTRACT.KRON_BOUNDARY_RELATION_MISMATCH", ERROR, target_key,
            "Target line impedance differs from the declared source Schur-complement boundary relation.",
            merge(copy(evidence), Dict{String,Any}(
                "knowledge_ids" => [_KRON_BOUNDARY_PSK],
                "contract_id" => _KRON_BOUNDARY_CONTRACT,
                "invalid_inferences" => [
                    "A Kron-shaped target is not boundary-exact when its impedance differs from the source Schur complement.",
                ],
                "recommended_checks" => [
                    "Recompute the Schur complement in the declared conductor order and preserve the target boundary map.",
                ],
            )),
        ))
    end
    if isempty(findings)
        evidence["classification"] = "exact_grounded_kron_boundary"
        evidence["qualification"] =
            "Pass covers the fixed series boundary relation under endpoint perfect grounding and a declared neutral recovery map only."
        return _kron_boundary_result(:passed, Finding[], evidence; checked=checked)
    end
    if !grounded_from || !grounded_to
        evidence["classification"] = relation_error > relation_tolerance ?
            "grounding_and_boundary_mismatch" : "grounding_precondition_failure"
    else
        evidence["classification"] = "boundary_relation_mismatch"
    end
    _kron_boundary_result(:failed, findings, evidence; checked=checked)
end

function _positive_sequence_result(status::Symbol, findings::Vector{Finding},
                                    evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _POSITIVE_SEQUENCE_CONTRACT,
        status,
        [_POSITIVE_SEQUENCE_PSK],
        checked,
        [
            "phase_specific_limits_and_controls",
            "neutral_or_explicit_earth_observations",
            "unbalanced_boundary_data",
            "internal_device_and_protection_quantities",
            "complete_network_feasible_set",
            "objective_or_optimizer_equivalence",
            "solver_status_or_optimality",
        ],
        findings,
        evidence,
    )
end

function _positive_sequence_finding(code::String, severity::Severity,
                                     line_id, message::String,
                                     detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :line,
            line_id isa String && !isempty(line_id) ? line_id : nothing,
            message, detail)
end

function _positive_sequence_refusal(status::Symbol, code::String,
                                    severity::Severity, message::String,
                                    mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_POSITIVE_SEQUENCE_PSK],
        "contract_id" => _POSITIVE_SEQUENCE_CONTRACT,
        "line_mapping" => mapping,
        "reason" => reason,
        "invalid_inferences" => [
            "Transposition or a numerically plausible scalar target does not establish positive-sequence exactness without sequence-invariant factors and a restricted study domain.",
            "A positive-sequence pass does not preserve phase-specific, neutral, zero-sequence, negative-sequence, protection, or internal-device observations.",
        ],
        "recommended_checks" => [
            "Check circulant series and shunt factors in the declared phase order.",
            "Restrict sources, injections, controls, limits, and observations to the balanced positive-sequence domain.",
            "Retain the phase-domain model for unbalanced, grounding, protection, or phase-specific studies.",
        ],
    )
    finding = _positive_sequence_finding(code, severity,
        get(mapping, "source_line_id", nothing), message, detail)
    _positive_sequence_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status), "line_mapping" => mapping, "reason" => reason))
end

function _positive_sequence_circulant(Z::AbstractMatrix, atol::Float64)
    size(Z) == (3, 3) || return false
    for i in 1:3, j in 1:3
        expected = Z[1, mod1(j - i + 1, 3)]
        abs(Z[i, j] - expected) <= atol || return false
    end
    true
end

"""
    check_positive_sequence_collapse(source, target;
        source_line_id, target_line_id, declarations,
        phase_terminals=["a", "b", "c"], terminal_mapping=Dict(),
        atol=1e-9, rtol=1e-8)
        -> ScientificContractResult

Check the guarded positive-sequence specialization (`PSK-000009`). The
supported case is a three-conductor source factor with circulant series and
shunt matrices and a scalar target whose impedance is the positive-sequence
eigenvalue. `declarations` must explicitly close balanced boundary data,
sequence-compatible grounding, two-terminal factor closure,
phase-symmetric decisions, and positive-sequence observations.
"""
function check_positive_sequence_collapse(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_line_id::AbstractString,
        target_line_id::AbstractString,
        declarations::AbstractDict,
        phase_terminals::AbstractVector{<:AbstractString}=["a", "b", "c"],
        terminal_mapping::AbstractDict=Dict{String,String}(),
        atol::Real=1e-9, rtol::Real=1e-8)::ScientificContractResult
    atol_f, rtol_f = Float64(atol), Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))
    source_key, target_key = String(source_line_id), String(target_line_id)
    phases = String.(phase_terminals)
    mapping = Dict{String,Any}(
        "source_line_id" => source_key, "target_line_id" => target_key,
        "phase_terminals" => phases,
        "terminal_mapping" => Dict{String,String}(string(k) => string(v) for (k, v) in terminal_mapping),
    )
    length(phases) == 3 && length(unique(phases)) == 3 ||
        return _positive_sequence_refusal(:inapplicable, "I.CONTRACT.SEQUENCE_NOT_APPLICABLE", INFO,
            "Positive-sequence collapse is not applicable: exactly three distinct phase terminals are required.",
            mapping, "phase_terminals must contain three distinct labels")

    Zs, source_line, source_status, source_reason = _kron_boundary_matrix(source, source_key)
    Zs === nothing && return _positive_sequence_refusal(
        source_status === :inapplicable ? :inapplicable : :indeterminate,
        source_status === :inapplicable ? "I.CONTRACT.SEQUENCE_NOT_APPLICABLE" : "W.CONTRACT.SEQUENCE_INDETERMINATE",
        source_status === :inapplicable ? INFO : WARNING,
        "Positive-sequence collapse cannot resolve the source series factor.", mapping, source_reason)
    size(Zs) == (3, 3) || return _positive_sequence_refusal(:inapplicable,
        "I.CONTRACT.SEQUENCE_NOT_APPLICABLE", INFO,
        "Positive-sequence collapse is not applicable: the source factor is not three-conductor.",
        mapping, "source series impedance must be 3×3")
    linecodes = get(source, "linecode", Dict())
    shunt_ok, shunt_reason = _kron_boundary_nonzero_shunt(source_line, linecodes, atol_f)
    # A positive-sequence reduction supports shunts only when their matrices are circulant.
    shunt_matrices = Dict{String,Any}()
    for (side, Y) in (("from", _line_shunt_complex(source_line, linecodes)[1]),
                      ("to", _line_shunt_complex(source_line, linecodes)[2]))
        Y === nothing && continue
        size(Y) == (3, 3) || return _positive_sequence_refusal(:inapplicable,
            "I.CONTRACT.SEQUENCE_NOT_APPLICABLE", INFO,
            "Positive-sequence collapse is not applicable: $side shunt is not 3×3.", mapping,
            "shunt matrices must use the three declared phase coordinates")
        _positive_sequence_circulant(Y, atol_f) || begin
            finding = _positive_sequence_finding("E.CONTRACT.SEQUENCE_SYMMETRY_MISMATCH", ERROR,
                source_key, "Positive-sequence collapse fails: a shunt matrix mixes sequence subspaces.",
                Dict{String,Any}("side" => side, "invalid_inference" => "transposition alone establishes exact positive-sequence closure"))
            return _positive_sequence_result(:failed, [finding], Dict{String,Any}(
                "classification" => "sequence_symmetry_failure", "line_mapping" => mapping,
                "source_series_circulant" => _positive_sequence_circulant(Zs, atol_f)))
        end
        shunt_matrices[side] = true
    end
    _positive_sequence_circulant(Zs, atol_f) || begin
        finding = _positive_sequence_finding("E.CONTRACT.SEQUENCE_SYMMETRY_MISMATCH", ERROR,
            source_key, "Positive-sequence collapse fails: the source series matrix is not circulant.",
            Dict{String,Any}("invalid_inference" => "transposition alone establishes exact positive-sequence closure"))
        return _positive_sequence_result(:failed, [finding], Dict{String,Any}(
            "classification" => "sequence_symmetry_failure", "line_mapping" => mapping,
            "source_series_circulant" => false))
    end
    target_Z, target_line, target_status, target_reason = _kron_boundary_matrix(target, target_key)
    target_Z === nothing && return _positive_sequence_refusal(
        target_status === :inapplicable ? :inapplicable : :indeterminate,
        target_status === :inapplicable ? "I.CONTRACT.SEQUENCE_NOT_APPLICABLE" : "W.CONTRACT.SEQUENCE_INDETERMINATE",
        target_status === :inapplicable ? INFO : WARNING,
        "Positive-sequence collapse cannot resolve the target factor.", mapping, target_reason)
    size(target_Z) == (1, 1) || return _positive_sequence_refusal(:inapplicable,
        "I.CONTRACT.SEQUENCE_NOT_APPLICABLE", INFO,
        "Positive-sequence collapse is not applicable: target must be scalar.", mapping,
        "target series impedance must be 1×1")
    src_from = string.(get(source_line, "terminal_map_from", String[]))
    src_to = string.(get(source_line, "terminal_map_to", String[]))
    (src_from == phases && src_to == phases) || return _positive_sequence_refusal(:inapplicable,
        "I.CONTRACT.SEQUENCE_NOT_APPLICABLE", INFO,
        "Positive-sequence collapse is not applicable: source terminal order is not aligned.", mapping,
        "source terminal maps must equal the declared phase order at both ends")
    required = ("balanced_boundary_data", "sequence_compatible_grounding",
                "two_terminal_closure", "phase_symmetric_decisions",
                "positive_sequence_observations")
    missing = String[]
    for key in required
        haskey(declarations, key) || push!(missing, key)
    end
    isempty(missing) || return _positive_sequence_refusal(:indeterminate,
        "W.CONTRACT.SEQUENCE_INDETERMINATE", WARNING,
        "Positive-sequence collapse is indeterminate: applicability declarations are incomplete.",
        mapping, "missing declarations: $(join(missing, ", "))")
    bad = [key for key in required if declarations[key] !== true]
    isempty(bad) || begin
        finding = _positive_sequence_finding("E.CONTRACT.SEQUENCE_DOMAIN_MISMATCH", ERROR,
            source_key, "Positive-sequence collapse fails: the study domain is not closed under the positive-sequence restriction.",
            Dict{String,Any}("failed_guards" => bad, "invalid_inference" => "a balanced factor makes an unbalanced or phase-specific study exact"))
        return _positive_sequence_result(:failed, [finding], Dict{String,Any}(
            "classification" => "sequence_domain_failure", "line_mapping" => mapping,
            "failed_guards" => bad, "source_series_circulant" => true))
    end
    a = cis(2pi / 3)
    zpos = Zs[1, 1] + Zs[1, 2] * a^2 + Zs[1, 3] * a
    delta = ComplexF64(target_Z[1, 1] - zpos)
    tolerance = atol_f + rtol_f * max(abs(zpos), abs(target_Z[1, 1]))
    evidence = Dict{String,Any}(
        "classification" => "positive_sequence_restriction",
        "line_mapping" => mapping, "source_series_circulant" => true,
        "positive_sequence_impedance" => _contract_complex(zpos),
        "target_impedance" => _contract_complex(ComplexF64(target_Z[1, 1])),
        "relation_error" => abs(delta), "relation_tolerance" => tolerance,
        "declarations" => Dict{String,Any}(string(k) => declarations[k] for k in required),
        "shunt_matrices_circulant" => shunt_matrices,
    )
    abs(delta) <= tolerance && return _positive_sequence_result(:passed, Finding[], evidence;
        checked=["source_series_cyclic_symmetry", "source_shunt_cyclic_symmetry",
                 "balanced_boundary_data", "sequence_compatible_grounding",
                 "two_terminal_factor_closure", "phase_symmetric_decisions",
                 "positive_sequence_observations", "positive_sequence_relation"])
    finding = _positive_sequence_finding("E.CONTRACT.SEQUENCE_RELATION_MISMATCH", ERROR,
        target_key, "Positive-sequence collapse fails: scalar target does not match the source positive-sequence relation.",
        Dict{String,Any}("relation_error" => abs(delta), "relation_tolerance" => tolerance))
    _positive_sequence_result(:failed, [finding], evidence;
        checked=["source_series_cyclic_symmetry", "source_shunt_cyclic_symmetry"])
end

function _state_equivalent_result(status::Symbol, findings::Vector{Finding},
                                  evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _STATE_EQUIVALENT_CONTRACT, status, [_STATE_EQUIVALENT_PSK], checked,
        [
            "state_domain_preservation_beyond_declared_parameter",
            "nonlinear_or_topology_update_correctness",
            "complete_network_feasible_set",
            "objective_or_optimizer_equivalence",
            "solver_status_or_optimality",
        ], findings, evidence)
end

function _state_equivalent_finding(code::String, severity::Severity,
                                   model_id, message::String,
                                   detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :transformation,
            model_id isa String && !isempty(model_id) ? model_id : nothing,
            message, detail)
end

function _state_equivalent_refusal(status::Symbol, code::String,
                                   severity::Severity, message::String,
                                   mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_STATE_EQUIVALENT_PSK],
        "contract_id" => _STATE_EQUIVALENT_CONTRACT,
        "model_mapping" => mapping, "reason" => reason,
        "invalid_inferences" => [
            "A target calibrated at one operating point is not a reusable state-dependent equivalent over a non-singleton domain.",
            "An update-rule identifier does not authenticate nonlinear map correctness, feasible-set preservation, or optimizer equivalence.",
        ],
        "recommended_checks" => [
            "Retain the state domain and identify the parameter controlling the equivalent.",
            "Recompute the map at every declared state or provide a bounded approximation certificate.",
            "Validate state-dependent constraints and decisions against the source model.",
        ],
    )
    finding = _state_equivalent_finding(code, severity,
        get(mapping, "target_model_id", nothing), message, detail)
    _state_equivalent_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status), "model_mapping" => mapping, "reason" => reason))
end

"""
    check_state_dependent_equivalent(source, target;
        source_model_id, target_model_id)
        -> ScientificContractResult

Check the declaration boundary for a fixed versus state-dependent equivalent
(`PSK-000010`). Both records must provide a `state_dependent` object with a
non-singleton numeric domain, parameter identity, base state, and update-rule
provenance. A target that freezes the source at one base point fails rather
than being silently promoted to a reusable equivalent.
"""
function check_state_dependent_equivalent(
        source::AbstractDict, target::AbstractDict;
        source_model_id::AbstractString,
        target_model_id::AbstractString)::ScientificContractResult
    mapping = Dict{String,Any}("source_model_id" => String(source_model_id),
                               "target_model_id" => String(target_model_id))
    src = get(source, "state_dependent", nothing)
    dst = get(target, "state_dependent", nothing)
    src isa AbstractDict && dst isa AbstractDict ||
        return _state_equivalent_refusal(:indeterminate,
            "W.CONTRACT.STATE_EQUIVALENT_INDETERMINATE", WARNING,
            "State-dependent equivalent is indeterminate: both source and target state declarations are required.",
            mapping, "state_dependent must be an object in both models")
    parameter = get(src, "parameter", nothing)
    domain = get(src, "domain", nothing)
    base = get(src, "base_state", nothing)
    parameter isa AbstractString && !isempty(parameter) ||
        return _state_equivalent_refusal(:indeterminate,
            "W.CONTRACT.STATE_EQUIVALENT_INDETERMINATE", WARNING,
            "State-dependent equivalent is indeterminate: source parameter identity is missing.",
            mapping, "source.state_dependent.parameter must be nonempty")
    domain isa AbstractVector && length(domain) == 2 && all(x -> x isa Number && isfinite(Float64(x)), domain) ||
        return _state_equivalent_refusal(:indeterminate,
            "W.CONTRACT.STATE_EQUIVALENT_INDETERMINATE", WARNING,
            "State-dependent equivalent is indeterminate: source state domain is missing or malformed.",
            mapping, "source.state_dependent.domain must contain two finite numbers")
    lo, hi = Float64(domain[1]), Float64(domain[2])
    lo <= hi || return _state_equivalent_refusal(:inapplicable,
        "I.CONTRACT.STATE_EQUIVALENT_NOT_APPLICABLE", INFO,
        "State-dependent equivalent is not applicable: source state domain is reversed.",
        mapping, "domain lower bound exceeds upper bound")
    src_base = base isa Number && isfinite(Float64(base)) ? Float64(base) : NaN
    src_base >= lo - 1e-12 && src_base <= hi + 1e-12 ||
        return _state_equivalent_refusal(:indeterminate,
            "W.CONTRACT.STATE_EQUIVALENT_INDETERMINATE", WARNING,
            "State-dependent equivalent is indeterminate: source base state lies outside its domain.",
            mapping, "base_state must lie inside domain")
    dst_parameter = get(dst, "parameter", nothing)
    dst_domain = get(dst, "domain", nothing)
    dst_update = get(dst, "update_rule_id", nothing)
    dst_flag = get(dst, "is_state_dependent", nothing)
    if !(dst_parameter isa AbstractString && dst_parameter == parameter &&
         dst_domain isa AbstractVector && length(dst_domain) == 2 &&
         all(x -> x isa Number && isfinite(Float64(x)), dst_domain) &&
         dst_update isa AbstractString && !isempty(dst_update) && dst_flag === true)
        finding = _state_equivalent_finding("E.CONTRACT.STATE_UPDATE_PROVENANCE_LOSS", ERROR,
            String(target_model_id),
            "Target equivalent freezes or omits the source state update provenance over a non-singleton domain.",
            Dict{String,Any}("parameter" => parameter, "source_domain" => [lo, hi],
                "target_is_state_dependent" => dst_flag,
                "target_update_rule_id" => dst_update,
                "invalid_inference" => "a base-state map is globally reusable"))
        return _state_equivalent_result(:failed, [finding], Dict{String,Any}(
            "classification" => "frozen_state_dependent_equivalent",
            "model_mapping" => mapping, "parameter" => parameter,
            "source_domain" => [lo, hi], "source_base_state" => src_base))
    end
    dst_lo, dst_hi = Float64(dst_domain[1]), Float64(dst_domain[2])
    dst_lo == lo && dst_hi == hi || begin
        finding = _state_equivalent_finding("E.CONTRACT.STATE_DOMAIN_MISMATCH", ERROR,
            String(target_model_id), "Target equivalent does not preserve the source state domain.",
            Dict{String,Any}("source_domain" => [lo, hi], "target_domain" => [dst_lo, dst_hi]))
        return _state_equivalent_result(:failed, [finding], Dict{String,Any}(
            "classification" => "state_domain_mismatch", "model_mapping" => mapping))
    end
    target_base = get(dst, "base_state", nothing)
    target_base isa Number && isfinite(Float64(target_base)) &&
        abs(Float64(target_base) - src_base) <= 1e-12 || begin
        finding = _state_equivalent_finding("E.CONTRACT.STATE_BASE_ALIGNMENT_MISMATCH", ERROR,
            String(target_model_id), "Target equivalent base state is not aligned with the source calibration state.",
            Dict{String,Any}("source_base_state" => src_base, "target_base_state" => target_base))
        return _state_equivalent_result(:failed, [finding], Dict{String,Any}(
            "classification" => "state_base_mismatch", "model_mapping" => mapping))
    end
    _state_equivalent_result(:passed, Finding[], Dict{String,Any}(
        "classification" => "state_domain_and_update_provenance_declared",
        "model_mapping" => mapping, "parameter" => parameter,
        "source_domain" => [lo, hi], "source_base_state" => src_base,
        "target_domain" => [dst_lo, dst_hi], "target_update_rule_id" => String(dst_update));
        checked=["state_domain_declared", "state_parameter_alignment",
                 "base_state_alignment", "update_provenance_declared"])
end

function _reference_singularity_result(status::Symbol, findings::Vector{Finding},
                                       evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _REFERENCE_SINGULARITY_CONTRACT, status, [_REFERENCE_SINGULARITY_PSK], checked,
        ["physical_reference_asset_identity", "equation_and_solver_rank_details",
         "complete_network_feasible_set", "objective_or_optimizer_equivalence",
         "solver_status_or_optimality"], findings, evidence)
end

function _reference_singularity_finding(code::String, severity::Severity,
                                        model_id, message::String,
                                        detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :transformation,
            model_id isa String && !isempty(model_id) ? model_id : nothing,
            message, detail)
end

function _reference_singularity_refusal(status::Symbol, code::String,
                                        severity::Severity, message::String,
                                        mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_REFERENCE_SINGULARITY_PSK],
        "contract_id" => _REFERENCE_SINGULARITY_CONTRACT,
        "model_mapping" => mapping, "reason" => reason,
        "invalid_inferences" => [
            "A successful parser or solver termination does not establish that every connected island has a voltage reference or full rank.",
            "A target rank number without its island and reference provenance is not a source-model equivalence certificate.",
        ],
        "recommended_checks" => [
            "Identify every connected island and its physical or mathematical voltage reference.",
            "Compare rank deficiency and reference incidence after each topology or reduction step.",
            "Retain the source model for floating-island, grounding, and solver-singularity diagnosis.",
        ],
    )
    finding = _reference_singularity_finding(code, severity,
        get(mapping, "target_model_id", nothing), message, detail)
    _reference_singularity_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status), "model_mapping" => mapping, "reason" => reason))
end

"""
    check_reference_singularity(source, target;
        source_model_id, target_model_id, island_mapping=Dict())
        -> ScientificContractResult

Compare declared reference/rank evidence for mapped connected islands
(`PSK-000011`). Each model must provide `reference_analysis.islands`, where
each island has an id, `has_voltage_reference`, `dimension`, and `rank`.
"""
function check_reference_singularity(
        source::AbstractDict, target::AbstractDict;
        source_model_id::AbstractString, target_model_id::AbstractString,
        island_mapping::AbstractDict=Dict{String,String}())::ScientificContractResult
    mapping = Dict{String,Any}("source_model_id" => String(source_model_id),
                               "target_model_id" => String(target_model_id),
                               "island_mapping" => Dict{String,String}(string(k) => string(v) for (k, v) in island_mapping))
    src = get(source, "reference_analysis", nothing)
    dst = get(target, "reference_analysis", nothing)
    src isa AbstractDict && dst isa AbstractDict ||
        return _reference_singularity_refusal(:indeterminate,
            "W.CONTRACT.REFERENCE_SINGULARITY_INDETERMINATE", WARNING,
            "Reference/singularity validation is indeterminate: both analyses are required.",
            mapping, "reference_analysis must be an object in both models")
    src_islands, dst_islands = get(src, "islands", nothing), get(dst, "islands", nothing)
    src_islands isa AbstractVector && dst_islands isa AbstractVector ||
        return _reference_singularity_refusal(:indeterminate,
            "W.CONTRACT.REFERENCE_SINGULARITY_INDETERMINATE", WARNING,
            "Reference/singularity validation is indeterminate: island lists are missing.",
            mapping, "reference_analysis.islands must be arrays")
    function normalize_islands(raw)
        out = Dict{String,Any}()
        for item in raw
            item isa AbstractDict || return nothing
            id = get(item, "id", nothing)
            id isa AbstractString && !isempty(id) || return nothing
            ref = get(item, "has_voltage_reference", nothing)
            dim, rank = get(item, "dimension", nothing), get(item, "rank", nothing)
            ref isa Bool && dim isa Integer && dim >= 0 && rank isa Integer && 0 <= rank <= dim || return nothing
            out[String(id)] = (reference=ref, dimension=Int(dim), rank=Int(rank))
        end
        out
    end
    src_map, dst_map = normalize_islands(src_islands), normalize_islands(dst_islands)
    src_map isa Dict && dst_map isa Dict ||
        return _reference_singularity_refusal(:indeterminate,
            "W.CONTRACT.REFERENCE_SINGULARITY_INDETERMINATE", WARNING,
            "Reference/singularity validation is indeterminate: island records are malformed.",
            mapping, "each island needs id, boolean reference, dimension, and rank")
    isempty(src_map) && return _reference_singularity_refusal(:inapplicable,
        "I.CONTRACT.REFERENCE_SINGULARITY_NOT_APPLICABLE", INFO,
        "Reference/singularity validation is not applicable: no connected islands were supplied.",
        mapping, "island list is empty")
    mapped = Dict{String,String}()
    for id in keys(src_map)
        mapped[id] = get(mapping["island_mapping"], id, id)
    end
    all(haskey(dst_map, id) for id in values(mapped)) ||
        return _reference_singularity_refusal(:indeterminate,
            "W.CONTRACT.REFERENCE_SINGULARITY_INDETERMINATE", WARNING,
            "Reference/singularity validation is indeterminate: an island mapping is unresolved.",
            mapping, "every source island must map to a target island")
    failures = Finding[]
    for (src_id, dst_id) in sort(collect(mapped); by=first)
        s, d = src_map[src_id], dst_map[dst_id]
        if s.reference && !d.reference
            push!(failures, _reference_singularity_finding("E.CONTRACT.REFERENCE_LOSS", ERROR,
                String(target_model_id), "Target island loses the source voltage reference.",
                Dict{String,Any}("source_island" => src_id, "target_island" => dst_id)))
        end
        if s.rank == s.dimension && d.rank < d.dimension
            push!(failures, _reference_singularity_finding("E.CONTRACT.SINGULARITY_CHANGE", ERROR,
                String(target_model_id), "Target island becomes rank-deficient relative to the source.",
                Dict{String,Any}("source_island" => src_id, "target_island" => dst_id,
                                  "source_rank" => s.rank, "target_rank" => d.rank,
                                  "target_rank_deficiency" => d.dimension - d.rank)))
        end
    end
    evidence = Dict{String,Any}("classification" => isempty(failures) ?
        "references_and_rank_preserved" : "reference_or_singularity_failure",
        "model_mapping" => mapping, "mapped_islands" => mapped,
        "source_islands" => src_map, "target_islands" => dst_map)
    isempty(failures) && return _reference_singularity_result(:passed, Finding[], evidence;
        checked=["island_mapping", "voltage_reference_incidence", "rank_deficiency"])
    _reference_singularity_result(:failed, failures, evidence;
        checked=["island_mapping", "voltage_reference_incidence", "rank_deficiency"])
end

function _permutation_result(status::Symbol, findings::Vector{Finding},
                             evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _PERMUTATION_CONTRACT, status, [_PERMUTATION_PSK], checked,
        ["asset_identity_and_provenance", "nonlinear_or_state_dependent_factors",
         "complete_network_feasible_set", "objective_or_optimizer_equivalence",
         "solver_status_or_optimality"], findings, evidence)
end

function _permutation_finding(code::String, severity::Severity,
                              line_id, message::String,
                              detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :line,
            line_id isa String && !isempty(line_id) ? line_id : nothing,
            message, detail)
end

function _permutation_refusal(status::Symbol, code::String,
                              severity::Severity, message::String,
                              mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_PERMUTATION_PSK],
        "contract_id" => _PERMUTATION_CONTRACT,
        "line_mapping" => mapping, "reason" => reason,
        "invalid_inferences" => [
            "Matching conductor counts do not establish that terminal labels or matrix coordinates were permuted consistently.",
            "A passing permutation check does not establish asset identity, nonlinear state, limits, decisions, or solver equivalence.",
        ],
        "recommended_checks" => [
            "Declare a bijective permutation and compare both endpoint terminal maps.",
            "Conjugate the source primitive by the declared permutation and compare the target matrix.",
            "Retain source provenance when a relabelled view is exported.",
        ],
    )
    finding = _permutation_finding(code, severity,
        get(mapping, "target_line_id", nothing), message, detail)
    _permutation_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status), "line_mapping" => mapping, "reason" => reason))
end

"""
    check_terminal_permutation_invariance(source, target;
        source_line_id, target_line_id, permutation)
        -> ScientificContractResult

Check that a target series primitive is exactly the source primitive under an
explicit bijective terminal permutation (`PSK-000012`). The permutation is a
one-based vector whose target coordinate `i` takes source coordinate
`permutation[i]`; both endpoint terminal maps must transform accordingly.
"""
function check_terminal_permutation_invariance(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_line_id::AbstractString, target_line_id::AbstractString,
        permutation::AbstractVector{<:Integer})::ScientificContractResult
    source_key, target_key = String(source_line_id), String(target_line_id)
    mapping = Dict{String,Any}("source_line_id" => source_key,
                               "target_line_id" => target_key,
                               "permutation" => Int.(permutation))
    n = length(permutation)
    n > 0 && sort(Int.(permutation)) == collect(1:n) ||
        return _permutation_refusal(:inapplicable,
            "I.CONTRACT.PERMUTATION_NOT_APPLICABLE", INFO,
            "Terminal permutation is not applicable: permutation must be a nonempty bijection.",
            mapping, "permutation must contain each one-based index exactly once")
    Zs, source_line, source_status, source_reason = _kron_boundary_matrix(source, source_key)
    Zs === nothing && return _permutation_refusal(
        source_status === :inapplicable ? :inapplicable : :indeterminate,
        source_status === :inapplicable ? "I.CONTRACT.PERMUTATION_NOT_APPLICABLE" : "W.CONTRACT.PERMUTATION_INDETERMINATE",
        source_status === :inapplicable ? INFO : WARNING,
        "Terminal permutation cannot resolve the source line primitive.", mapping, source_reason)
    size(Zs, 1) == n && size(Zs, 2) == n || return _permutation_refusal(:inapplicable,
        "I.CONTRACT.PERMUTATION_NOT_APPLICABLE", INFO,
        "Terminal permutation is not applicable: permutation length does not match source conductors.",
        mapping, "permutation length must equal source matrix dimension")
    Zt, target_line, target_status, target_reason = _kron_boundary_matrix(target, target_key)
    Zt === nothing && return _permutation_refusal(
        target_status === :inapplicable ? :inapplicable : :indeterminate,
        target_status === :inapplicable ? "I.CONTRACT.PERMUTATION_NOT_APPLICABLE" : "W.CONTRACT.PERMUTATION_INDETERMINATE",
        target_status === :inapplicable ? INFO : WARNING,
        "Terminal permutation cannot resolve the target line primitive.", mapping, target_reason)
    size(Zt) == (n, n) || return _permutation_refusal(:inapplicable,
        "I.CONTRACT.PERMUTATION_NOT_APPLICABLE", INFO,
        "Terminal permutation is not applicable: target conductor count differs.",
        mapping, "source and target matrix dimensions must match")
    src_from = string.(get(source_line, "terminal_map_from", String[]))
    src_to = string.(get(source_line, "terminal_map_to", String[]))
    dst_from = string.(get(target_line, "terminal_map_from", String[]))
    dst_to = string.(get(target_line, "terminal_map_to", String[]))
    expected_from = src_from[Int.(permutation)]
    expected_to = src_to[Int.(permutation)]
    (dst_from == expected_from && dst_to == expected_to) || begin
        finding = _permutation_finding("E.CONTRACT.TERMINAL_ORDER_MISMATCH", ERROR,
            target_key, "Target terminal maps do not follow the declared permutation.",
            Dict{String,Any}("source_from" => src_from, "target_from" => dst_from,
                "expected_from" => expected_from, "source_to" => src_to,
                "target_to" => dst_to, "expected_to" => expected_to))
        return _permutation_result(:failed, [finding], Dict{String,Any}(
            "classification" => "terminal_order_mismatch", "line_mapping" => mapping))
    end
    expected = Zs[Int.(permutation), Int.(permutation)]
    delta = Zt - expected
    error = norm(delta)
    tolerance = 1e-9 + 1e-8 * max(norm(expected), norm(Zt))
    evidence = Dict{String,Any}(
        "classification" => error <= tolerance ? "permutation_relation_preserved" : "permutation_relation_mismatch",
        "line_mapping" => mapping, "source_terminal_maps" => Dict("from" => src_from, "to" => src_to),
        "target_terminal_maps" => Dict("from" => dst_from, "to" => dst_to),
        "relation_error" => error, "relation_tolerance" => tolerance,
        "expected_matrix" => expected, "target_matrix" => Zt)
    error <= tolerance && return _permutation_result(:passed, Finding[], evidence;
        checked=["permutation_bijection", "endpoint_terminal_map_alignment", "series_matrix_permutation_relation"])
    finding = _permutation_finding("E.CONTRACT.PERMUTATION_RELATION_MISMATCH", ERROR,
        target_key, "Target series primitive does not equal the permuted source primitive.",
        Dict{String,Any}("relation_error" => error, "relation_tolerance" => tolerance))
    _permutation_result(:failed, [finding], evidence;
        checked=["permutation_bijection", "endpoint_terminal_map_alignment"])
end

function _feasibility_result(status::Symbol, findings::Vector{Finding},
                             evidence::AbstractDict; checked=String[])
    ScientificContractResult(
        _FEASIBILITY_CONTRACT, status, [_FEASIBILITY_PSK], checked,
        ["residual_computation_independence", "model_equation_coverage",
         "complete_feasible_set", "objective_or_optimizer_equivalence",
         "solver_status_or_optimality"], findings, Dict{String,Any}(evidence))
end

function _unit_base_result(status::Symbol, findings::Vector{Finding},
                           evidence::AbstractDict; checked=String[])
    ScientificContractResult(
        _UNIT_BASE_CONTRACT, status, [_UNIT_BASE_PSK], checked,
        ["canonical_payload_identity", "source_hash_binding",
         "physical_unit_semantics", "complete_network_equivalence",
         "objective_or_optimizer_equivalence"], findings,
        Dict{String,Any}(evidence))
end

function _unit_base_equal(a, b)
    a isa AbstractDict && b isa AbstractDict &&
        Set(string.(keys(a))) == Set(string.(keys(b))) &&
        all(_unit_base_equal(get(a, k, nothing), get(b, k, nothing)) for k in keys(a)) ||
        (a isa AbstractVector && b isa AbstractVector && length(a) == length(b) &&
         all(_unit_base_equal(a[i], b[i]) for i in eachindex(a)) || a == b)
end

"""
    check_unit_base_serialization_invariance(source, target;
        source_model_id, target_model_id) -> ScientificContractResult

Check explicit unit/base metadata and a canonical semantic hash across a
serialization round trip (`PSK-000014`). The contract compares the declared
unit system, base map, and semantic payload hash; it does not infer units from
numeric magnitudes or claim that metadata equality proves network equivalence.
"""
function check_unit_base_serialization_invariance(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_model_id::AbstractString, target_model_id::AbstractString)::ScientificContractResult
    mapping = Dict{String,Any}("source_model_id" => String(source_model_id),
        "target_model_id" => String(target_model_id))
    sm, tm = get(source, "serialization", nothing), get(target, "serialization", nothing)
    sm isa AbstractDict && tm isa AbstractDict || begin
        f = Finding(WARNING, "W.CONTRACT.UNIT_BASE_SERIALIZATION_INDETERMINATE",
            :scientific_contract, :model, String(target_model_id),
            "Unit/base serialization invariance is indeterminate: serialization metadata is missing.",
            Dict{String,Any}("knowledge_ids" => [_UNIT_BASE_PSK], "contract_id" => _UNIT_BASE_CONTRACT,
                "line_mapping" => mapping, "reason" => "each model needs serialization.unit_system, bases, and semantic_hash"))
        return _unit_base_result(:indeterminate, [f], Dict("classification" => "missing_serialization_metadata", "line_mapping" => mapping))
    end
    fields = ("unit_system", "bases", "semantic_hash")
    missing = [field for field in fields if get(sm, field, nothing) === nothing || get(tm, field, nothing) === nothing]
    isempty(missing) || begin
        f = Finding(WARNING, "W.CONTRACT.UNIT_BASE_SERIALIZATION_INDETERMINATE",
            :scientific_contract, :model, String(target_model_id),
            "Unit/base serialization invariance is indeterminate: required metadata is missing.",
            Dict{String,Any}("knowledge_ids" => [_UNIT_BASE_PSK], "contract_id" => _UNIT_BASE_CONTRACT,
                "missing_fields" => missing))
        return _unit_base_result(:indeterminate, [f], Dict("classification" => "incomplete_serialization_metadata", "line_mapping" => mapping))
    end
    sm["unit_system"] == tm["unit_system"] || begin
        f = Finding(ERROR, "E.CONTRACT.UNIT_SYSTEM_MISMATCH", :scientific_contract, :model,
            String(target_model_id), "Target serialization declares a different unit system.",
            Dict{String,Any}("knowledge_ids" => [_UNIT_BASE_PSK], "contract_id" => _UNIT_BASE_CONTRACT,
                "source_unit_system" => sm["unit_system"], "target_unit_system" => tm["unit_system"]))
        return _unit_base_result(:failed, [f], Dict("classification" => "unit_system_mismatch", "line_mapping" => mapping))
    end
    _unit_base_equal(sm["bases"], tm["bases"]) || begin
        f = Finding(ERROR, "E.CONTRACT.BASE_MAP_MISMATCH", :scientific_contract, :model,
            String(target_model_id), "Target serialization does not preserve the declared unit/base map.",
            Dict{String,Any}("knowledge_ids" => [_UNIT_BASE_PSK], "contract_id" => _UNIT_BASE_CONTRACT,
                "source_bases" => sm["bases"], "target_bases" => tm["bases"]))
        return _unit_base_result(:failed, [f], Dict("classification" => "base_map_mismatch", "line_mapping" => mapping))
    end
    sm["semantic_hash"] == tm["semantic_hash"] || begin
        f = Finding(ERROR, "E.CONTRACT.SERIALIZED_PAYLOAD_MISMATCH", :scientific_contract, :model,
            String(target_model_id), "Target serialization has a different canonical semantic payload hash.",
            Dict{String,Any}("knowledge_ids" => [_UNIT_BASE_PSK], "contract_id" => _UNIT_BASE_CONTRACT,
                "source_semantic_hash" => sm["semantic_hash"], "target_semantic_hash" => tm["semantic_hash"]))
        return _unit_base_result(:failed, [f], Dict("classification" => "canonical_payload_mismatch", "line_mapping" => mapping))
    end
    _unit_base_result(:passed, Finding[], Dict("classification" => "unit_base_and_payload_preserved",
        "line_mapping" => mapping, "unit_system" => sm["unit_system"], "bases" => sm["bases"],
        "semantic_hash" => sm["semantic_hash"]);
        checked=["canonical_payload_identity", "source_hash_binding", "physical_unit_semantics"])
end

"""
    check_solved_network_feasibility(result; tolerances=Dict()) -> ScientificContractResult

Validate an independently computed residual witness for a claimed solved
network (`PSK-000013`). The result must contain finite residual norms for
equations, KCL, power balance, and recovery, plus a nonnegative device-limit
violation count. Solver termination is recorded separately and is never used
as a substitute for these measurements.
"""
function check_solved_network_feasibility(
        result::Dict{String,Any}; tolerances::AbstractDict=Dict{String,Any}())::ScientificContractResult
    raw_status = get(result, "termination_status", nothing)
    raw_status isa AbstractString && !isempty(strip(raw_status)) || begin
        f = Finding(WARNING, "W.CONTRACT.FEASIBILITY_INDETERMINATE", :scientific_contract,
                    :solution, nothing,
                    "Solved-network feasibility is indeterminate: termination_status is missing.",
                    Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                        "contract_id" => _FEASIBILITY_CONTRACT,
                        "reason" => "termination_status is missing"))
        return _feasibility_result(:indeterminate, [f], Dict("classification" => "missing_termination_status"); checked=[])
    end
    status = String(raw_status)
    accepted = ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
    status in accepted || begin
        f = Finding(INFO, "I.CONTRACT.FEASIBILITY_NOT_APPLICABLE", :scientific_contract,
                    :solution, nothing,
                    "Solved-network feasibility is not applicable: solver status does not claim a solved result.",
                    Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                        "contract_id" => _FEASIBILITY_CONTRACT,
                        "termination_status" => status))
        return _feasibility_result(:inapplicable, [f], Dict("classification" => "unsolved_status", "termination_status" => status); checked=[])
    end
    validation = get(result, "feasibility_validation", nothing)
    validation isa AbstractDict || begin
        f = Finding(WARNING, "W.CONTRACT.FEASIBILITY_INDETERMINATE", :scientific_contract,
                    :solution, nothing,
                    "Solved-network feasibility is indeterminate: feasibility_validation is missing.",
                    Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                        "contract_id" => _FEASIBILITY_CONTRACT,
                        "reason" => "feasibility_validation must contain independently computed residuals"))
        return _feasibility_result(:indeterminate, [f], Dict("classification" => "missing_residual_witness", "termination_status" => status); checked=[])
    end
    fields = ("equation_residual_norm", "kcl_residual_norm", "power_balance_residual_norm", "recovery_residual_norm")
    missing = String[]
    residuals = Dict{String,Float64}()
    for field in fields
        value = get(validation, field, nothing)
        if !(value isa Number) || !isfinite(Float64(value))
            push!(missing, field)
        else
            residuals[field] = abs(Float64(value))
        end
    end
    violations = get(validation, "device_limit_violations", nothing)
    if !(violations isa Integer) || violations < 0
        push!(missing, "device_limit_violations")
    end
    isempty(missing) || begin
        f = Finding(WARNING, "W.CONTRACT.FEASIBILITY_INDETERMINATE", :scientific_contract,
                    :solution, nothing,
                    "Solved-network feasibility is indeterminate: residual witness fields are missing or malformed.",
                    Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                        "contract_id" => _FEASIBILITY_CONTRACT,
                        "missing_fields" => missing))
        return _feasibility_result(:indeterminate, [f], Dict("classification" => "malformed_residual_witness", "termination_status" => status); checked=[])
    end
    defaults = Dict{String,Float64}(field => 1e-8 for field in fields)
    for (key, value) in tolerances
        key in fields && value isa Number && isfinite(Float64(value)) && Float64(value) >= 0 && (defaults[String(key)] = Float64(value))
    end
    failures = Finding[]
    for field in fields
        residuals[field] > defaults[field] && push!(failures,
            Finding(ERROR, "E.CONTRACT.FEASIBILITY_RESIDUAL_VIOLATION", :scientific_contract,
                :solution, nothing,
                "Independent $(field) exceeds its declared tolerance.",
                Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                    "contract_id" => _FEASIBILITY_CONTRACT, "field" => field,
                    "residual" => residuals[field], "tolerance" => defaults[field])))
    end
    violations > 0 && push!(failures,
        Finding(ERROR, "E.CONTRACT.FEASIBILITY_DEVICE_LIMIT_VIOLATION", :scientific_contract,
            :solution, nothing,
            "Independent device-limit validation reports one or more violations.",
            Dict{String,Any}("knowledge_ids" => [_FEASIBILITY_PSK],
                "contract_id" => _FEASIBILITY_CONTRACT,
                "device_limit_violations" => violations)))
    evidence = Dict{String,Any}("classification" => isempty(failures) ? "independent_feasibility_witness_passed" : "independent_feasibility_witness_failed",
        "termination_status" => status, "residuals" => residuals,
        "tolerances" => defaults, "device_limit_violations" => violations)
    checked = ["termination_status", "equation_residual_norm", "kcl_residual_norm",
               "power_balance_residual_norm", "device_limit_violations", "recovery_residual_norm"]
    isempty(failures) && return _feasibility_result(:passed, Finding[], evidence; checked=checked)
    _feasibility_result(:failed, failures, evidence; checked=checked)
end

function _decision_manifest_result(
        status::Symbol, findings::Vector{Finding}, evidence::Dict{String,Any};
        checked=String[])
    ScientificContractResult(
        _DECISION_MANIFEST_CONTRACT,
        status,
        [_DECISION_MANIFEST_PSK],
        checked,
        [
            "truth_or_independence_of_cited_evidence",
            "source_and_target_equation_equivalence",
            "source_and_target_feasible_set_equivalence",
            "objective_value_or_optimizer_equivalence",
            "correctness_of_constraint_decision_or_recovery_maps",
            "provenance_completeness_beyond_declared_references",
            "solver_status_or_optimality",
        ],
        findings,
        evidence,
    )
end

function _decision_manifest_finding(code::String, severity::Severity,
                                    transformation_id, message::String,
                                    detail::Dict{String,Any})
    Finding(severity, code, :scientific_contract, :transformation,
            transformation_id isa String && !isempty(transformation_id) ?
                transformation_id : nothing,
            message, detail)
end

function _decision_manifest_refusal(status::Symbol, code::String,
                                    severity::Severity, message::String,
                                    manifest::AbstractDict, reason::String)
    transformation_id = get(manifest, "transformation_id", nothing)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_DECISION_MANIFEST_PSK],
        "contract_id" => _DECISION_MANIFEST_CONTRACT,
        "transformation_id" => transformation_id,
        "reason" => reason,
        "invalid_inferences" => [
            "A terminal-equivalence claim is not a decision-equivalence claim.",
            "An absent, malformed, or out-of-scope manifest cannot be treated as a failed or passed decision-equivalence certificate.",
        ],
        "recommended_checks" => [
            "Declare the exactness object and classification explicitly.",
            "For an exact decision-equivalence claim, provide a disposition and evidence reference or justification for every required dimension.",
        ],
    )
    finding = _decision_manifest_finding(
        code, severity, transformation_id, message, detail)
    _decision_manifest_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "transformation_id" => transformation_id,
        "reason" => reason,
    ))
end

function _decision_manifest_nonempty_string(value)::Bool
    value isa AbstractString && !isempty(strip(String(value)))
end

function _decision_manifest_string_array(value)
    value isa AbstractVector || return nothing
    strings = String[]
    for item in value
        _decision_manifest_nonempty_string(item) || return nothing
        push!(strings, String(item))
    end
    isempty(strings) || length(strings) != length(unique(strings)) ? nothing : strings
end

"""
    check_decision_preservation_manifest(manifest) -> ScientificContractResult

Check declaration-level evidence completeness for a transformation manifest
that claims exact decision equivalence (`PSK-000007`). The manifest must name
its source and target models and give each required dimension—admissible
domain, terminal behavior, observations, constraints, decision variables,
objective, and recovery—one of four dispositions:

- `verified`, with one or more nonempty `evidence_ids`; or
- `not_required`, with a nonempty `justification`; or
- `not_preserved`; or
- `unassessed`.

An exact decision-equivalence claim passes this completeness gate only when
every dimension is closed by `verified` evidence or a justified
`not_required` disposition. Missing evidence produces
`E.CONTRACT.DECISION_MANIFEST_EVIDENCE_GAP`; an explicit `not_preserved` or
`unassessed` dimension produces
`E.CONTRACT.DECISION_MANIFEST_UNRESOLVED_OBLIGATION`. A manifest that claims a
different exactness object is `:inapplicable`, so a correctly scoped terminal-
only certificate is not mislabeled as a failure.

A pass establishes only that the declaration is complete and internally
non-contradictory at this schema boundary. BMOPFTools does not resolve or
authenticate the cited evidence, prove the maps correct, compare feasible
sets or objectives, or establish solver or optimization equivalence.
"""
function check_decision_preservation_manifest(
        manifest::AbstractDict)::ScientificContractResult
    schema_version = get(manifest, "schema_version", nothing)
    transformation_id = get(manifest, "transformation_id", nothing)
    source_model_id = get(manifest, "source_model_id", nothing)
    target_model_id = get(manifest, "target_model_id", nothing)
    if schema_version != "0.1.0" ||
       !_decision_manifest_nonempty_string(transformation_id) ||
       !_decision_manifest_nonempty_string(source_model_id) ||
       !_decision_manifest_nonempty_string(target_model_id)
        return _decision_manifest_refusal(
            :indeterminate,
            "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
            WARNING,
            "Decision-preservation manifest is indeterminate: schema or model identity is missing or unsupported.",
            manifest,
            "schema_version must be 0.1.0 and transformation_id, source_model_id, and target_model_id must be nonempty strings",
        )
    end

    claim = get(manifest, "claim", nothing)
    claim isa AbstractDict || return _decision_manifest_refusal(
        :indeterminate,
        "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
        WARNING,
        "Decision-preservation manifest is indeterminate: claim declaration is missing or malformed.",
        manifest,
        "claim must be an object with exactness_object and classification",
    )
    exactness_object = get(claim, "exactness_object", nothing)
    classification = get(claim, "classification", nothing)
    (_decision_manifest_nonempty_string(exactness_object) &&
     _decision_manifest_nonempty_string(classification)) ||
        return _decision_manifest_refusal(
            :indeterminate,
            "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
            WARNING,
            "Decision-preservation manifest is indeterminate: exactness object or classification is missing.",
            manifest,
            "claim exactness_object and classification must be nonempty strings",
        )
    if exactness_object != "decision_equivalence" || classification != "exact"
        return _decision_manifest_refusal(
            :inapplicable,
            "I.CONTRACT.DECISION_MANIFEST_NOT_APPLICABLE",
            INFO,
            "Decision-preservation manifest completeness is not applicable: the manifest does not claim exact decision equivalence.",
            manifest,
            "claimed exactness object is '$exactness_object' with classification '$classification'",
        )
    end

    dimensions = get(manifest, "dimensions", nothing)
    dimensions isa AbstractDict || return _decision_manifest_refusal(
        :indeterminate,
        "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
        WARNING,
        "Decision-preservation manifest is indeterminate: dimensions declaration is missing or malformed.",
        manifest,
        "dimensions must be an object",
    )

    missing_dimensions = String[]
    missing_support = String[]
    unresolved_dimensions = String[]
    dispositions = Dict{String,Any}()
    for dimension in _DECISION_MANIFEST_DIMENSIONS
        entry = get(dimensions, dimension, nothing)
        if entry === nothing
            push!(missing_dimensions, dimension)
            continue
        end
        entry isa AbstractDict || return _decision_manifest_refusal(
            :indeterminate,
            "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
            WARNING,
            "Decision-preservation manifest is indeterminate: dimension '$dimension' is malformed.",
            manifest,
            "dimension '$dimension' must be an object",
        )
        status = get(entry, "status", nothing)
        if !(status isa AbstractString) || !(String(status) in _DECISION_MANIFEST_STATUSES)
            return _decision_manifest_refusal(
                :indeterminate,
                "W.CONTRACT.DECISION_MANIFEST_INDETERMINATE",
                WARNING,
                "Decision-preservation manifest is indeterminate: dimension '$dimension' has an unsupported disposition.",
                manifest,
                "dimension '$dimension' status must be one of $(_DECISION_MANIFEST_STATUSES)",
            )
        end
        status_string = String(status)
        if status_string == "verified"
            evidence_ids = _decision_manifest_string_array(
                get(entry, "evidence_ids", nothing))
            evidence_ids === nothing && push!(missing_support, dimension)
            dispositions[dimension] = Dict{String,Any}(
                "status" => status_string,
                "evidence_ids" => evidence_ids === nothing ? String[] : evidence_ids,
            )
        elseif status_string == "not_required"
            justification = get(entry, "justification", nothing)
            _decision_manifest_nonempty_string(justification) ||
                push!(missing_support, dimension)
            dispositions[dimension] = Dict{String,Any}(
                "status" => status_string,
                "justification" => justification isa AbstractString ?
                    String(justification) : "",
            )
        else
            push!(unresolved_dimensions, dimension)
            dispositions[dimension] = Dict{String,Any}("status" => status_string)
        end
    end

    common = Dict{String,Any}(
        "transformation_id" => String(transformation_id),
        "source_model_id" => String(source_model_id),
        "target_model_id" => String(target_model_id),
        "exactness_object" => String(exactness_object),
        "classification" => String(classification),
        "required_dimensions" => collect(_DECISION_MANIFEST_DIMENSIONS),
        "dimension_dispositions" => dispositions,
        "missing_dimensions" => missing_dimensions,
        "dimensions_missing_support" => missing_support,
        "unresolved_dimensions" => unresolved_dimensions,
    )
    checked = [
        "manifest_identity_and_claim_scope",
        "required_dimension_dispositions",
        "verified_evidence_reference_presence",
        "not_required_justification_presence",
    ]
    if isempty(missing_dimensions) && isempty(missing_support) &&
       isempty(unresolved_dimensions)
        common["classification"] = "decision_manifest_evidence_complete"
        common["qualification"] =
            "Pass establishes declaration completeness only; cited evidence and decision equivalence remain unverified by this contract."
        return _decision_manifest_result(:passed, Finding[], common; checked=checked)
    end

    findings = Finding[]
    if !isempty(missing_dimensions) || !isempty(missing_support)
        detail = merge(copy(common), Dict{String,Any}(
            "knowledge_ids" => [_DECISION_MANIFEST_PSK],
            "contract_id" => _DECISION_MANIFEST_CONTRACT,
            "invalid_inferences" => [
                "Verified terminal behavior does not close omitted domain, observation, constraint, decision, objective, or recovery obligations.",
            ],
            "recommended_checks" => [
                "Add every missing required dimension.",
                "Attach at least one evidence ID to verified dimensions and a justification to not-required dimensions.",
            ],
        ))
        push!(findings, _decision_manifest_finding(
            "E.CONTRACT.DECISION_MANIFEST_EVIDENCE_GAP",
            ERROR,
            String(transformation_id),
            "Exact decision-equivalence manifest omits required dimensions or supporting references.",
            detail,
        ))
    end
    if !isempty(unresolved_dimensions)
        detail = merge(copy(common), Dict{String,Any}(
            "knowledge_ids" => [_DECISION_MANIFEST_PSK],
            "contract_id" => _DECISION_MANIFEST_CONTRACT,
            "invalid_inferences" => [
                "A manifest cannot claim exact decision equivalence while a required dimension is explicitly unassessed or not preserved.",
            ],
            "recommended_checks" => [
                "Narrow the exactness claim or supply independent evidence closing every unresolved dimension.",
            ],
        ))
        push!(findings, _decision_manifest_finding(
            "E.CONTRACT.DECISION_MANIFEST_UNRESOLVED_OBLIGATION",
            ERROR,
            String(transformation_id),
            "Exact decision-equivalence manifest contains an unassessed or not-preserved obligation.",
            detail,
        ))
    end
    common["classification"] =
        !isempty(unresolved_dimensions) &&
        (!isempty(missing_dimensions) || !isempty(missing_support)) ?
            "evidence_gap_and_unresolved_obligation" :
        !isempty(unresolved_dimensions) ? "unresolved_obligation" : "evidence_gap"
    _decision_manifest_result(:failed, findings, common; checked=checked)
end

function _neutral_ground_result(status::Symbol, findings::Vector{Finding},
                                evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _NEUTRAL_GROUND_CONTRACT,
        status,
        [_NEUTRAL_GROUND_PSK],
        checked,
        [
            "electrical_terminal_behavior",
            "explicit_earth_conductor_behavior",
            "soil_and_electrode_model",
            "grounding_asset_identity_and_state",
            "fault_current",
            "touch_voltage",
            "protection_operation",
        ],
        findings,
        evidence,
    )
end

function _neutral_ground_refusal(status::Symbol, code::String, severity::Severity,
                                 message::String, mapping::Dict{String,String}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_NEUTRAL_GROUND_PSK],
        "contract_id" => _NEUTRAL_GROUND_CONTRACT,
        "bus_mapping" => mapping,
        "reason" => reason,
        "invalid_inferences" => [
            "No neutral/ground/reference preservation conclusion follows when the mapping is incomplete or the declared relation lies outside the supported domain.",
        ],
        "recommended_checks" => [
            "Provide a one-to-one mapping for at least two source buses with explicit neutral terminals.",
            "Retain neutral terminal identity, neutral continuity, and the declared perfect-ground, finite-grounding, and source-reference relations.",
        ],
    )
    finding = Finding(severity, code, :scientific_contract, :transformation,
                      nothing, message, detail)
    _neutral_ground_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "reason" => reason,
        "bus_mapping" => mapping,
    ))
end

_contract_finding_to_dict(f::Finding) = Dict{String,Any}(
    "severity"       => string(f.severity),
    "code"           => f.code,
    "section"        => string(f.section),
    "component_type" => string(f.component_type),
    "component_id"   => f.component_id,
    "message"        => f.message,
    "detail"         => f.detail,
)

"""
    contract_result_to_dict(result::ScientificContractResult) -> Dict{String,Any}

Convert a scientific-contract result to a JSON-compatible dictionary. Complex
quantities in built-in checks are recorded as explicit real/imaginary fields,
so the returned structure can be serialized directly with `JSON3`.
"""
function contract_result_to_dict(result::ScientificContractResult)::Dict{String,Any}
    Dict{String,Any}(
        "contract_id"           => result.contract_id,
        "status"                => string(result.status),
        "knowledge_ids"         => result.knowledge_ids,
        "checked_dimensions"    => result.checked_dimensions,
        "unassessed_dimensions" => result.unassessed_dimensions,
        "findings"              => _contract_finding_to_dict.(result.findings),
        "evidence"              => result.evidence,
    )
end

_contract_complex(z::Complex) = Dict{String,Any}(
    "real" => Float64(real(z)), "imag" => Float64(imag(z)))

function _contract_result(status::Symbol, findings::Vector{Finding}, evidence::Dict{String,Any};
                          checked=String[])
    ScientificContractResult(
        _PARALLEL_MEMBER_LIMIT_CONTRACT,
        status,
        [_PARALLEL_MEMBER_LIMIT_PSK],
        checked,
        [
            "member_identity",
            "independent_outage_state",
            "switching_decisions",
            "asset_provenance",
            "individual_measurements",
            "protection_quantities",
        ],
        findings,
        evidence,
    )
end

function _contract_refusal(status::Symbol, code::String, severity::Severity,
                           message::String, member_ids::Vector{String}, aggregate_id::String,
                           reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_PARALLEL_MEMBER_LIMIT_PSK],
        "contract_id" => _PARALLEL_MEMBER_LIMIT_CONTRACT,
        "source_member_ids" => member_ids,
        "target_aggregate_id" => aggregate_id,
        "reason" => reason,
        "invalid_inferences" => [
            "No preservation conclusion follows when an executable contract is not applicable or lacks required evidence.",
        ],
        "recommended_checks" => [
            "Provide a source model, target model, and explicit member-to-aggregate mapping.",
            "Retain member impedances and ratings when member-limit preservation is requested.",
        ],
    )
    finding = Finding(severity, code, :scientific_contract, :transformation,
                      isempty(aggregate_id) ? nothing : aggregate_id, message, detail)
    _contract_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "reason" => reason,
        "source_member_ids" => member_ids,
        "target_aggregate_id" => aggregate_id,
    ))
end

function _contract_rating(line::Dict{String,Any}, linecodes)::Union{Float64,Nothing}
    raw = get(line, "i_max", nothing)
    if raw === nothing
        linecode_id = get(line, "linecode", nothing)
        linecode = linecode_id isa AbstractString ? get(linecodes, linecode_id, nothing) : nothing
        linecode isa AbstractDict && (raw = get(linecode, "i_max", nothing))
    end
    value = if raw isa Number
        Float64(raw)
    elseif raw isa AbstractVector && length(raw) == 1 && first(raw) isa Number
        Float64(first(raw))
    else
        return nothing
    end
    isfinite(value) && value > 0 ? value : nothing
end

function _contract_scalar_line(net::Dict{String,Any}, line_id::String;
                               atol::Float64)
    lines = get(net, "line", Dict())
    line = get(lines, line_id, nothing)
    line isa Dict{String,Any} || return (nothing, :indeterminate,
        "line '$line_id' does not resolve to a BMOPF line record")
    linecodes = get(net, "linecode", Dict())
    Z, n = _line_z_complex(line, linecodes)
    Z === nothing && return (nothing, :indeterminate,
        "line '$line_id' has no resolvable fixed series impedance")
    n == 1 || return (nothing, :inapplicable,
        "line '$line_id' has $n conductors; the initial executable contract is scalar")
    z = ComplexF64(Z[1, 1])
    (isfinite(real(z)) && isfinite(imag(z)) && abs(z) > atol) ||
        return (nothing, :inapplicable,
            "line '$line_id' has a zero, non-finite, or numerically singular scalar impedance")
    Yfr, Yto = _line_shunt_complex(line, linecodes)
    for (side, Ysh) in (("from", Yfr), ("to", Yto))
        if Ysh !== nothing && norm(Ysh) > atol
            return (nothing, :inapplicable,
                "line '$line_id' has a nonzero $side-side shunt; the initial contract is series-only")
        end
    end
    rating = _contract_rating(line, linecodes)
    rating === nothing && return (nothing, :indeterminate,
        "line '$line_id' has no finite positive scalar i_max rating")
    from_map = string.(get(line, "terminal_map_from", String[]))
    to_map = string.(get(line, "terminal_map_to", String[]))
    length(from_map) == 1 && length(to_map) == 1 ||
        return (nothing, :inapplicable,
            "line '$line_id' does not have one declared terminal at each end")
    data = (
        id=line_id,
        line=line,
        z=z,
        y=inv(z),
        i_max=rating,
        bus_from=string(get(line, "bus_from", "")),
        bus_to=string(get(line, "bus_to", "")),
        terminal_from=from_map[1],
        terminal_to=to_map[1],
    )
    (data, :applicable, "")
end

function _contract_aligned(member, aggregate)::Bool
    direct = member.bus_from == aggregate.bus_from &&
             member.bus_to == aggregate.bus_to &&
             member.terminal_from == aggregate.terminal_from &&
             member.terminal_to == aggregate.terminal_to
    reverse = member.bus_from == aggregate.bus_to &&
              member.bus_to == aggregate.bus_from &&
              member.terminal_from == aggregate.terminal_to &&
              member.terminal_to == aggregate.terminal_from
    direct || reverse
end

"""
    check_parallel_member_limit_preservation(source, target;
        member_ids, aggregate_id, atol=1e-9, rtol=1e-8)
        -> ScientificContractResult

Check the scalar, fixed-linear, series-only portion of scientific contract
`parallel_member_limit_preservation` (`PSK-000001`). `source` must retain the
identified parallel members and their current ratings; `target` must contain
the declared aggregate. The explicit `member_ids`/`aggregate_id` mapping is
required because a reduced target cannot reveal discarded member identity.

The check first verifies the aggregate terminal admittance. If that relation is
preserved, it compares the exact scalar voltage-drop regions induced by source
member limits and the target aggregate limit:

```math
|ΔV| ≤ minₗ(Iₗmax / |Yₗ|),
|ΔV| ≤ Ieqmax / |Σₗ Yₗ|.
```

It returns `:failed` with `W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS` when the
target is an inner restriction or outer relaxation, and includes a concrete
voltage-drop/current witness. A `:passed` result establishes only terminal
behavior and scalar member-current-limit preservation; member identity,
outages, switching, provenance, measurements, and protection quantities remain
explicitly unassessed. Multiconductor, shunted, singular, or state-dependent
cases return `:inapplicable` rather than being guessed.
"""
function check_parallel_member_limit_preservation(
        source::Dict{String,Any}, target::Dict{String,Any};
        member_ids::AbstractVector{<:AbstractString},
        aggregate_id::AbstractString,
        atol::Real=1e-9,
        rtol::Real=1e-8)::ScientificContractResult
    atol_f = Float64(atol)
    rtol_f = Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))
    members_requested = String.(member_ids)
    aggregate_requested = String(aggregate_id)
    if length(members_requested) < 2 || length(unique(members_requested)) != length(members_requested)
        return _contract_refusal(
            :inapplicable, "I.CONTRACT.NOT_APPLICABLE", INFO,
            "Parallel member-limit contract is not applicable: member_ids must name at least two unique source lines.",
            members_requested, aggregate_requested,
            "member_ids must name at least two unique source lines")
    end
    isempty(aggregate_requested) && return _contract_refusal(
        :indeterminate, "W.CONTRACT.INDETERMINATE", WARNING,
        "Parallel member-limit contract is indeterminate: aggregate_id is empty.",
        members_requested, aggregate_requested, "aggregate_id is empty")

    members = Any[]
    for id in members_requested
        data, status, reason = _contract_scalar_line(source, id; atol=atol_f)
        if data === nothing
            result_status = status === :inapplicable ? :inapplicable : :indeterminate
            code = result_status === :inapplicable ? "I.CONTRACT.NOT_APPLICABLE" : "W.CONTRACT.INDETERMINATE"
            severity = result_status === :inapplicable ? INFO : WARNING
            return _contract_refusal(result_status, code, severity,
                "Parallel member-limit contract is $(result_status): $reason.",
                members_requested, aggregate_requested, reason)
        end
        push!(members, data)
    end
    aggregate, status, reason = _contract_scalar_line(target, aggregate_requested; atol=atol_f)
    if aggregate === nothing
        result_status = status === :inapplicable ? :inapplicable : :indeterminate
        code = result_status === :inapplicable ? "I.CONTRACT.NOT_APPLICABLE" : "W.CONTRACT.INDETERMINATE"
        severity = result_status === :inapplicable ? INFO : WARNING
        return _contract_refusal(result_status, code, severity,
            "Parallel member-limit contract is $(result_status): $reason.",
            members_requested, aggregate_requested, reason)
    end
    for member in members
        _contract_aligned(member, aggregate) || return _contract_refusal(
            :inapplicable, "I.CONTRACT.NOT_APPLICABLE", INFO,
            "Parallel member-limit contract is not applicable: source member '$(member.id)' is not aligned with aggregate '$aggregate_requested'.",
            members_requested, aggregate_requested,
            "source and target endpoints or terminal coordinates do not align")
    end

    member_admittance = sum(member.y for member in members)
    relation_error = abs(aggregate.y - member_admittance)
    relation_tolerance = atol_f + rtol_f * max(abs(aggregate.y), abs(member_admittance), 1.0)
    common_evidence = Dict{String,Any}(
        "source_member_ids" => members_requested,
        "target_aggregate_id" => aggregate_requested,
        "source_member_impedances_ohm" => Dict(
            member.id => _contract_complex(member.z) for member in members),
        "source_member_admittances_S" => Dict(
            member.id => _contract_complex(member.y) for member in members),
        "target_admittance_S" => _contract_complex(aggregate.y),
        "summed_source_admittance_S" => _contract_complex(member_admittance),
        "terminal_relation_error_S" => relation_error,
        "terminal_relation_tolerance_S" => relation_tolerance,
    )
    if relation_error > relation_tolerance
        detail = merge(copy(common_evidence), Dict{String,Any}(
            "knowledge_ids" => [_PARALLEL_MEMBER_LIMIT_PSK],
            "contract_id" => _PARALLEL_MEMBER_LIMIT_CONTRACT,
            "classification" => "terminal_relation_mismatch",
            "invalid_inferences" => [
                "The declared target is not a terminal-equivalent aggregate of the identified source members.",
            ],
            "recommended_checks" => [
                "Recompute the aggregate series admittance from the identified source members.",
            ],
        ))
        finding = Finding(ERROR, "E.CONTRACT.PARALLEL_TERMINAL_RELATION_MISMATCH",
            :scientific_contract, :line, aggregate_requested,
            "Aggregate line '$aggregate_requested' does not preserve the summed scalar terminal admittance of source members $(join(members_requested, ", ")).",
            detail)
        common_evidence["classification"] = "terminal_relation_mismatch"
        return _contract_result(:failed, [finding], common_evidence;
                                checked=["terminal_behavior"])
    end

    source_drop_limit = minimum(member.i_max / abs(member.y) for member in members)
    target_drop_limit = aggregate.i_max / abs(aggregate.y)
    limit_tolerance = atol_f + rtol_f * max(source_drop_limit, target_drop_limit, 1.0)
    common_evidence["source_member_ratings_A"] = Dict(
        member.id => member.i_max for member in members)
    common_evidence["target_rating_A"] = aggregate.i_max
    common_evidence["source_voltage_drop_limit_V"] = source_drop_limit
    common_evidence["target_voltage_drop_limit_V"] = target_drop_limit
    common_evidence["limit_tolerance_V"] = limit_tolerance

    if abs(target_drop_limit - source_drop_limit) <= limit_tolerance
        common_evidence["classification"] = "exact_for_scalar_member_current_limits"
        common_evidence["qualification"] =
            "Pass applies only to the scalar terminal-voltage-drop feasible set and does not recover member identity or independent member state."
        return _contract_result(:passed, Finding[], common_evidence;
            checked=["terminal_behavior", "scalar_member_current_limits"])
    end

    outer = target_drop_limit > source_drop_limit
    classification = outer ? "outer_relaxation" : "inner_restriction"
    midpoint = (source_drop_limit + target_drop_limit) / 2
    preferred = 1.5 * source_drop_limit
    witness_drop = outer && source_drop_limit < preferred < target_drop_limit ? preferred : midpoint
    member_currents = Dict(member.id => abs(member.y) * witness_drop for member in members)
    target_current = abs(aggregate.y) * witness_drop
    source_feasible = all(member_currents[member.id] <= member.i_max + limit_tolerance for member in members)
    target_feasible = target_current <= aggregate.i_max + limit_tolerance
    common_evidence["classification"] = classification
    common_evidence["witness"] = Dict{String,Any}(
        "voltage_drop_V" => witness_drop,
        "member_currents_A" => member_currents,
        "aggregate_current_A" => target_current,
        "source_feasible" => source_feasible,
        "target_feasible" => target_feasible,
    )
    detail = merge(copy(common_evidence), Dict{String,Any}(
        "knowledge_ids" => [_PARALLEL_MEMBER_LIMIT_PSK],
        "contract_id" => _PARALLEL_MEMBER_LIMIT_CONTRACT,
        "invalid_inferences" => [
            "Summed admittance does not imply that summing member ratings preserves the member-constrained feasible set.",
        ],
        "recommended_checks" => [
            "Retain member limits explicitly or derive an aggregate constraint for the declared preservation domain.",
            "Verify recovered member currents against every source rating.",
        ],
    ))
    finding = Finding(WARNING, "W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS",
        :scientific_contract, :line, aggregate_requested,
        "Aggregate line '$aggregate_requested' is a $classification of the source member-current-limit region.",
        detail)
    _contract_result(:failed, [finding], common_evidence;
        checked=["terminal_behavior", "scalar_member_current_limits"])
end

function _neutral_ground_signature(net::Dict{String,Any}, bus_id::String;
                                   atol::Float64)
    bus = get(get(net, "bus", Dict()), bus_id, nothing)
    bus isa Dict{String,Any} || return (nothing, :indeterminate,
        "bus '$bus_id' does not resolve to a BMOPF bus record")
    neutral = _neutral_terminal(bus)
    neutral === nothing && return (nothing, :inapplicable,
        "bus '$bus_id' has no identifiable explicit neutral terminal")

    perfect = neutral in string.(get(bus, "perfectly_grounded_terminals", String[]))
    source_references = String[]
    for (id, source) in get(net, "voltage_source", Dict())
        source isa AbstractDict || continue
        string(get(source, "bus", "")) == bus_id || continue
        neutral in string.(get(source, "terminal_map", String[])) && push!(source_references, string(id))
    end

    grounding_shunts = Pair{String,ComplexF64}[]
    for (id, shunt) in get(net, "shunt", Dict())
        shunt isa Dict{String,Any} || continue
        string(get(shunt, "bus", "")) == bus_id || continue
        terminal_map = string.(get(shunt, "terminal_map", String[]))
        neutral in terminal_map || continue
        length(terminal_map) == 1 || return (nothing, :inapplicable,
            "shunt '$id' couples neutral '$neutral' to other terminals; the initial contract supports scalar neutral-only grounding shunts")
        nodes, yprim = _shunt_yprim(shunt)
        size(yprim) == (1, 1) || return (nothing, :indeterminate,
            "shunt '$id' has no resolvable scalar grounding admittance")
        y = ComplexF64(yprim[1, 1])
        (isfinite(real(y)) && isfinite(imag(y))) || return (nothing, :indeterminate,
            "shunt '$id' has a non-finite grounding admittance")
        abs(y) > atol && push!(grounding_shunts, string(id) => y)
    end
    sort!(grounding_shunts; by=first)

    classification = String[]
    perfect && push!(classification, "perfect_ground")
    !isempty(grounding_shunts) && push!(classification, "finite_grounding")
    !isempty(source_references) && push!(classification, "source_reference")
    isempty(classification) && push!(classification, "floating")
    values_sorted = sort(last.(grounding_shunts); by=z -> (real(z), imag(z)))
    raw = (
        neutral=neutral,
        perfect=perfect,
        source_reference_count=length(source_references),
        grounding_values=values_sorted,
    )
    evidence = Dict{String,Any}(
        "bus_id" => bus_id,
        "neutral_terminal" => neutral,
        "relation_classes" => classification,
        "perfectly_grounded" => perfect,
        "source_reference_ids" => sort(source_references),
        "grounding_shunts" => [
            Dict{String,Any}("id" => id, "admittance_S" => _contract_complex(y))
            for (id, y) in grounding_shunts
        ],
    )
    (raw, evidence, :applicable, "")
end

function _neutral_component_labels(net::Dict{String,Any})::Dict{String,Int}
    buses = get(net, "bus", Dict())
    neutral_of = _bus_neutral_map(buses)
    neutral_buses = Set(id for (id, neutral) in neutral_of if neutral !== nothing)
    adjacency = Dict{String,Set{String}}(id => Set{String}() for id in neutral_buses)
    uses_neutral(bus_id, terminal_map) = begin
        neutral = get(neutral_of, bus_id, nothing)
        neutral !== nothing && neutral in string.(terminal_map)
    end

    for component_type in ("line", "switch")
        for (_, component) in get(net, component_type, Dict())
            component isa AbstractDict || continue
            component_type == "switch" && get(component, "open_switch", false) && continue
            from = string(get(component, "bus_from", ""))
            to = string(get(component, "bus_to", ""))
            (from in neutral_buses && to in neutral_buses) || continue
            uses_neutral(from, get(component, "terminal_map_from", String[])) || continue
            uses_neutral(to, get(component, "terminal_map_to", String[])) || continue
            push!(adjacency[from], to)
            push!(adjacency[to], from)
        end
    end
    for (_, component) in get(get(net, "transformer", Dict()),
                              "single_phase_autotransformer", Dict())
        component isa AbstractDict || continue
        from = string(get(component, "bus_from", ""))
        to = string(get(component, "bus_to", ""))
        (from in neutral_buses && to in neutral_buses) || continue
        uses_neutral(from, get(component, "terminal_map_from", String[])) || continue
        uses_neutral(to, get(component, "terminal_map_to", String[])) || continue
        push!(adjacency[from], to)
        push!(adjacency[to], from)
    end

    labels = Dict{String,Int}()
    label = 0
    for start in sort(collect(neutral_buses))
        haskey(labels, start) && continue
        label += 1
        queue = [start]
        labels[start] = label
        while !isempty(queue)
            bus_id = popfirst!(queue)
            for neighbor in sort(collect(adjacency[bus_id]))
                haskey(labels, neighbor) && continue
                labels[neighbor] = label
                push!(queue, neighbor)
            end
        end
    end
    labels
end

function _neutral_relation_equal(source, target; atol::Float64, rtol::Float64)::Bool
    source.perfect == target.perfect || return false
    source.source_reference_count == target.source_reference_count || return false
    length(source.grounding_values) == length(target.grounding_values) || return false
    all(isapprox(a, b; atol=atol, rtol=rtol)
        for (a, b) in zip(source.grounding_values, target.grounding_values))
end

"""
    check_neutral_ground_reference_preservation(source, target;
        bus_mapping, atol=1e-9, rtol=1e-8) -> ScientificContractResult

Check the representation-level portion of scientific contract
`neutral_ground_reference_preservation` (`PSK-000002`). `bus_mapping` must be
a one-to-one mapping for at least two source buses with explicit neutral
terminals. The initial executable domain checks whether the target retains:

- an identifiable neutral terminal at every mapped bus;
- the pairwise neutral-continuity relation among mapped buses; and
- each mapped bus's declared perfect-ground, scalar finite-grounding-shunt,
  and voltage-source-reference relations.

The check deliberately distinguishes an intentional perfectly grounded neutral
from conflating every neutral with the mathematical reference. A pass applies
only to the declared representation relations. It does not establish equal
terminal equations, explicit-earth behavior, fault current, touch voltage,
protection operation, or grounding-asset identity. Coupled multiconductor
grounding shunts are refused as `:inapplicable` rather than reduced to a scalar
guess.
"""
function check_neutral_ground_reference_preservation(
        source::Dict{String,Any}, target::Dict{String,Any};
        bus_mapping::AbstractDict,
        atol::Real=1e-9,
        rtol::Real=1e-8)::ScientificContractResult
    atol_f = Float64(atol)
    rtol_f = Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))
    mapping = Dict{String,String}(string(source_id) => string(target_id)
                                  for (source_id, target_id) in bus_mapping)
    if length(mapping) < 2 || length(unique(values(mapping))) != length(mapping)
        return _neutral_ground_refusal(
            :inapplicable, "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE", INFO,
            "Neutral/ground/reference contract is not applicable: bus_mapping must contain at least two one-to-one bus mappings.",
            mapping, "bus_mapping must contain at least two one-to-one bus mappings")
    end

    source_buses = get(source, "bus", Dict())
    target_buses = get(target, "bus", Dict())
    for source_id in sort(collect(keys(mapping)))
        haskey(source_buses, source_id) || return _neutral_ground_refusal(
            :indeterminate, "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE", WARNING,
            "Neutral/ground/reference contract is indeterminate: source bus '$source_id' is missing.",
            mapping, "source bus '$source_id' is missing")
        target_id = mapping[source_id]
        haskey(target_buses, target_id) || return _neutral_ground_refusal(
            :indeterminate, "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE", WARNING,
            "Neutral/ground/reference contract is indeterminate: target bus '$target_id' is missing.",
            mapping, "target bus '$target_id' is missing")
        _neutral_terminal(source_buses[source_id]) === nothing && return _neutral_ground_refusal(
            :inapplicable, "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE", INFO,
            "Neutral/ground/reference contract is not applicable: source bus '$source_id' has no identifiable explicit neutral terminal.",
            mapping, "source bus '$source_id' has no identifiable explicit neutral terminal")
    end

    terminal_mapping = Dict{String,Any}()
    missing_target_neutrals = String[]
    for source_id in sort(collect(keys(mapping)))
        target_id = mapping[source_id]
        source_neutral = _neutral_terminal(source_buses[source_id])
        target_neutral = _neutral_terminal(target_buses[target_id])
        terminal_mapping[source_id] = Dict{String,Any}(
            "target_bus" => target_id,
            "source_neutral" => source_neutral,
            "target_neutral" => target_neutral,
        )
        target_neutral === nothing && push!(missing_target_neutrals, target_id)
    end
    common_evidence = Dict{String,Any}(
        "bus_mapping" => mapping,
        "neutral_terminal_mapping" => terminal_mapping,
    )
    if !isempty(missing_target_neutrals)
        common_evidence["classification"] = "neutral_identity_loss"
        common_evidence["target_buses_without_neutral"] = missing_target_neutrals
        detail = merge(copy(common_evidence), Dict{String,Any}(
            "knowledge_ids" => [_NEUTRAL_GROUND_PSK],
            "contract_id" => _NEUTRAL_GROUND_CONTRACT,
            "invalid_inferences" => [
                "Omitting an explicit neutral terminal does not establish that its voltage, current, limits, or grounding relation are represented by the mathematical reference.",
            ],
            "recommended_checks" => [
                "Retain an explicit target neutral or provide a separately justified reduction and recovery contract.",
            ],
        ))
        finding = Finding(ERROR, "E.CONTRACT.NEUTRAL_IDENTITY_LOSS",
            :scientific_contract, :bus, nothing,
            "Target model loses the explicit neutral terminal at mapped bus(es): $(join(missing_target_neutrals, ", ")).",
            detail)
        return _neutral_ground_result(:failed, [finding], common_evidence;
                                      checked=["neutral_terminal_identity"])
    end

    source_relations = Dict{String,Any}()
    target_relations = Dict{String,Any}()
    source_raw = Dict{String,Any}()
    target_raw = Dict{String,Any}()
    for source_id in sort(collect(keys(mapping)))
        target_id = mapping[source_id]
        source_signature = _neutral_ground_signature(source, source_id; atol=atol_f)
        source_signature[1] === nothing && return _neutral_ground_refusal(
            source_signature[2] === :inapplicable ? :inapplicable : :indeterminate,
            source_signature[2] === :inapplicable ?
                "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE" :
                "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE",
            source_signature[2] === :inapplicable ? INFO : WARNING,
            "Neutral/ground/reference contract is $(source_signature[2]): $(source_signature[end]).",
            mapping, source_signature[end])
        target_signature = _neutral_ground_signature(target, target_id; atol=atol_f)
        target_signature[1] === nothing && return _neutral_ground_refusal(
            target_signature[2] === :inapplicable ? :inapplicable : :indeterminate,
            target_signature[2] === :inapplicable ?
                "I.CONTRACT.NEUTRAL_GROUND_NOT_APPLICABLE" :
                "W.CONTRACT.NEUTRAL_GROUND_INDETERMINATE",
            target_signature[2] === :inapplicable ? INFO : WARNING,
            "Neutral/ground/reference contract is $(target_signature[2]): $(target_signature[end]).",
            mapping, target_signature[end])
        source_raw[source_id] = source_signature[1]
        source_relations[source_id] = source_signature[2]
        target_raw[source_id] = target_signature[1]
        target_relations[source_id] = target_signature[2]
    end
    common_evidence["source_relations"] = source_relations
    common_evidence["target_relations"] = target_relations

    source_components = _neutral_component_labels(source)
    target_components = _neutral_component_labels(target)
    source_ids = sort(collect(keys(mapping)))
    continuity_mismatches = Dict{String,Any}[]
    for left_index in eachindex(source_ids), right_index in (left_index + 1):length(source_ids)
        right_index > length(source_ids) && continue
        left = source_ids[left_index]
        right = source_ids[right_index]
        target_left = mapping[left]
        target_right = mapping[right]
        source_connected = source_components[left] == source_components[right]
        target_connected = target_components[target_left] == target_components[target_right]
        source_connected == target_connected && continue
        push!(continuity_mismatches, Dict{String,Any}(
            "source_buses" => [left, right],
            "target_buses" => [target_left, target_right],
            "source_connected" => source_connected,
            "target_connected" => target_connected,
        ))
    end
    common_evidence["neutral_continuity_mismatches"] = continuity_mismatches

    relation_mismatches = Dict{String,Any}[]
    for source_id in source_ids
        _neutral_relation_equal(source_raw[source_id], target_raw[source_id];
                                atol=atol_f, rtol=rtol_f) && continue
        push!(relation_mismatches, Dict{String,Any}(
            "source_bus" => source_id,
            "target_bus" => mapping[source_id],
            "source_relation" => source_relations[source_id],
            "target_relation" => target_relations[source_id],
        ))
    end
    common_evidence["ground_reference_relation_mismatches"] = relation_mismatches

    findings = Finding[]
    if !isempty(continuity_mismatches)
        detail = Dict{String,Any}(
            "knowledge_ids" => [_NEUTRAL_GROUND_PSK],
            "contract_id" => _NEUTRAL_GROUND_CONTRACT,
            "mismatches" => continuity_mismatches,
            "invalid_inferences" => [
                "A matching simple bus graph does not imply preservation of the neutral conductor's continuity graph.",
            ],
            "recommended_checks" => [
                "Retain neutral-carrying branch terminal maps or provide an explicit neutral recovery map.",
            ],
        )
        push!(findings, Finding(ERROR, "E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH",
            :scientific_contract, :network, nothing,
            "Target model changes neutral continuity among mapped buses.", detail))
    end
    if !isempty(relation_mismatches)
        detail = Dict{String,Any}(
            "knowledge_ids" => [_NEUTRAL_GROUND_PSK],
            "contract_id" => _NEUTRAL_GROUND_CONTRACT,
            "mismatches" => relation_mismatches,
            "invalid_inferences" => [
                "A finite grounding relation, a perfect ground, and a voltage-source gauge reference are not interchangeable declarations.",
            ],
            "recommended_checks" => [
                "Restore the mapped perfect-ground, scalar grounding-admittance, and source-reference relations before claiming representation preservation.",
            ],
        )
        push!(findings, Finding(ERROR, "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH",
            :scientific_contract, :network, nothing,
            "Target model changes a mapped neutral grounding or voltage-reference relation.", detail))
    end
    if !isempty(findings)
        common_evidence["classification"] = "neutral_ground_reference_relation_loss"
        return _neutral_ground_result(:failed, findings, common_evidence;
            checked=["neutral_terminal_identity", "neutral_continuity", "ground_reference_relations"])
    end

    common_evidence["classification"] = "representation_relations_preserved"
    common_evidence["qualification"] =
        "Pass covers explicit neutral identity, pairwise continuity, and declared grounding/reference relations only; it is not an electrical or protection equivalence certificate."
    _neutral_ground_result(:passed, Finding[], common_evidence;
        checked=["neutral_terminal_identity", "neutral_continuity", "ground_reference_relations"])
end

function _claimed_solution_result(status::Symbol, findings::Vector{Finding},
                                  evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _CLAIMED_SOLUTION_CONTRACT,
        status,
        [_CLAIMED_SOLUTION_PSK],
        checked,
        [
            "network_equation_residuals",
            "branch_thermal_limits",
            "transformer_limits",
            "generator_and_ibr_limits",
            "load_model_residuals",
            "network_power_balance",
            "objective_optimality",
            "local_or_global_optimality",
            "solver_derivative_quality",
        ],
        findings,
        evidence,
    )
end

function _claimed_solution_refusal(status::Symbol, code::String, severity::Severity,
                                   message::String, reason::String, termination_status)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_CLAIMED_SOLUTION_PSK],
        "contract_id" => _CLAIMED_SOLUTION_CONTRACT,
        "termination_status" => termination_status,
        "reason" => reason,
        "invalid_inferences" => [
            "No validated-solution conclusion follows from a missing, non-feasible, or structurally incomplete solver result.",
        ],
        "recommended_checks" => [
            "Supply a claimed-feasible result with vr, vi, and vm for every declared bus terminal.",
            "Run profile_solution and the equation-, limit-, and optimality-specific checks required by the study.",
        ],
    )
    finding = Finding(severity, code, :scientific_contract, :solution, nothing,
                      message, detail)
    _claimed_solution_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "termination_status" => termination_status,
        "reason" => reason,
    ))
end

"""
    check_claimed_solution_validity(net, result) -> ScientificContractResult

Check the initial executable portion of scientific contract
`claimed_solution_validity` (`PSK-000003`). The result must report a
claimed-feasible termination status and provide `vr`, `vi`, and `vm` for every
declared bus terminal. The contract then reuses [`profile_solution`](@ref) to
independently check:

- finiteness of the complete result tree; and
- declared bus voltage-magnitude, sequence-voltage, and angle-difference
  limits recomputed from the primal bus voltages.

An accepted solver termination status is an applicability precondition, not
evidence that these checks passed. A claimed-feasible result with non-finite
values or a declared bus-limit violation returns `:failed` with
`E.CONTRACT.CLAIMED_FEASIBLE_SOLUTION_INVALID` and retains the underlying
`E.SOL.*` evidence.

A pass is deliberately narrow. It does not establish network-equation
residuals, thermal or device limits, load-model residuals, power balance,
objective optimality, global optimality, or solver derivative quality. Those
dimensions remain explicitly unassessed and require their own validators or a
broader future contract.
"""
function check_claimed_solution_validity(
        net::Dict{String,Any}, result::Dict{String,Any})::ScientificContractResult
    raw_status = get(result, "termination_status", nothing)
    if !(raw_status isa AbstractString) || isempty(strip(raw_status))
        return _claimed_solution_refusal(
            :indeterminate, "W.CONTRACT.SOLUTION_VALIDATION_INDETERMINATE", WARNING,
            "Claimed-solution validity is indeterminate: termination_status is missing or invalid.",
            "termination_status is missing or invalid", raw_status)
    end
    termination_status = String(raw_status)
    accepted = ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
    if !(termination_status in accepted)
        return _claimed_solution_refusal(
            :inapplicable, "I.CONTRACT.SOLUTION_STATUS_NOT_APPLICABLE", INFO,
            "Claimed-solution validity is not applicable to termination status '$termination_status'.",
            "the solver did not claim a feasible solution", termination_status)
    end

    buses = get(net, "bus", nothing)
    if !(buses isa AbstractDict) || isempty(buses)
        return _claimed_solution_refusal(
            :inapplicable, "I.CONTRACT.SOLUTION_STATUS_NOT_APPLICABLE", INFO,
            "Claimed-solution validity is not applicable: the network has no declared buses.",
            "the network has no declared buses", termination_status)
    end
    result_buses = get(result, "bus", nothing)
    if !(result_buses isa AbstractDict)
        return _claimed_solution_refusal(
            :indeterminate, "W.CONTRACT.SOLUTION_VALIDATION_INDETERMINATE", WARNING,
            "Claimed-solution validity is indeterminate: the result has no bus block.",
            "the result has no bus block", termination_status)
    end

    missing = String[]
    terminal_count = 0
    for (bus_id_raw, bus) in sort(collect(pairs(buses)); by=pair -> string(first(pair)))
        bus_id = string(bus_id_raw)
        bus isa AbstractDict || continue
        bus_result = get(result_buses, bus_id, nothing)
        if !(bus_result isa AbstractDict)
            push!(missing, "bus.$bus_id")
            continue
        end
        for terminal in string.(get(bus, "terminal_names", String[]))
            terminal_count += 1
            terminal_result = get(bus_result, terminal, nothing)
            if !(terminal_result isa AbstractDict)
                push!(missing, "bus.$bus_id.$terminal")
                continue
            end
            for field in ("vr", "vi", "vm")
                value = get(terminal_result, field, nothing)
                value isa Number || push!(missing, "bus.$bus_id.$terminal.$field")
            end
        end
    end
    if terminal_count == 0
        return _claimed_solution_refusal(
            :inapplicable, "I.CONTRACT.SOLUTION_STATUS_NOT_APPLICABLE", INFO,
            "Claimed-solution validity is not applicable: no bus terminals are declared.",
            "no bus terminals are declared", termination_status)
    end
    if !isempty(missing)
        reason = "required bus-terminal result fields are missing: $(join(missing, ", "))"
        return _claimed_solution_refusal(
            :indeterminate, "W.CONTRACT.SOLUTION_VALIDATION_INDETERMINATE", WARNING,
            "Claimed-solution validity is indeterminate: $reason.",
            reason, termination_status)
    end

    report = profile_solution(net, result)
    blocking_codes = Set([
        "E.SOL.NAN_IN_RESULT",
        "E.SOL.VOLT_VIOLATION",
        "E.SOL.ANGLE_VIOLATION",
    ])
    blocking = [finding for finding in report.findings if finding.code in blocking_codes]
    observed_codes = sort(unique(finding.code for finding in report.findings))
    evidence = Dict{String,Any}(
        "termination_status" => termination_status,
        "covered_bus_count" => length(buses),
        "covered_terminal_count" => terminal_count,
        "observed_solution_finding_codes" => observed_codes,
        "solution_summary" => report.results[:solution],
    )
    checked = [
        "termination_status",
        "result_numeric_finiteness",
        "declared_bus_voltage_and_angle_limits",
    ]

    if !isempty(blocking)
        evidence["classification"] = "claimed_feasible_result_failed_validation"
        evidence["blocking_solution_findings"] = _contract_finding_to_dict.(blocking)
        detail = merge(copy(evidence), Dict{String,Any}(
            "knowledge_ids" => [_CLAIMED_SOLUTION_PSK],
            "contract_id" => _CLAIMED_SOLUTION_CONTRACT,
            "invalid_inferences" => [
                "A solver's feasible termination label does not establish that the returned primal values are finite or satisfy declared study limits.",
            ],
            "recommended_checks" => [
                "Correct every retained E.SOL finding and rerun the independent solution profile.",
                "Run the additional equation, device-limit, balance, and optimality checks required by the study before making a broader validity claim.",
            ],
        ))
        finding = Finding(ERROR, "E.CONTRACT.CLAIMED_FEASIBLE_SOLUTION_INVALID",
            :scientific_contract, :solution, nothing,
            "Solver status '$termination_status' claims feasibility, but independent bus-result validation failed.",
            detail)
        return _claimed_solution_result(:failed, [finding], evidence; checked=checked)
    end

    evidence["classification"] = "checked_solution_dimensions_valid"
    evidence["qualification"] =
        "Pass covers result finiteness and declared bus voltage/angle limits only; it is not an equation-feasibility or optimality certificate."
    _claimed_solution_result(:passed, Finding[], evidence; checked=checked)
end

function _load_voltage_base_result(status::Symbol, findings::Vector{Finding},
                                   evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _LOAD_VOLTAGE_BASE_CONTRACT,
        status,
        [_LOAD_VOLTAGE_BASE_PSK],
        checked,
        [
            "source_voltage_declaration_correctness",
            "transformer_ratio_declaration_correctness",
            "terminal_map_correctness",
            "load_law_and_coefficient_correctness",
            "operating_voltage",
            "network_equation_feasibility",
            "equipment_limits",
            "unit_provenance",
        ],
        findings,
        evidence,
    )
end

function _load_voltage_base_refusal(status::Symbol, code::String, severity::Severity,
                                    message::String, load_ids::Vector{String}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_LOAD_VOLTAGE_BASE_PSK],
        "contract_id" => _LOAD_VOLTAGE_BASE_CONTRACT,
        "load_ids" => load_ids,
        "reason" => reason,
        "invalid_inferences" => [
            "No voltage-base conclusion follows when the load connection, nominal anchor, or source-propagated bus base is unavailable or outside the supported domain.",
        ],
        "recommended_checks" => [
            "Declare a voltage-dependent WYE or DELTA load with a finite positive v_nom.",
            "Provide a source-reachable bus voltage base and verify source and transformer nominal-voltage declarations independently.",
        ],
    )
    finding = Finding(severity, code, :scientific_contract, :load,
                      length(load_ids) == 1 ? only(load_ids) : nothing,
                      message, detail)
    _load_voltage_base_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "load_ids" => load_ids,
        "reason" => reason,
    ))
end

"""
    check_load_voltage_base_consistency(net; load_ids=nothing,
        ratio_min=0.8, ratio_max=1.25) -> ScientificContractResult

Check the initial executable portion of scientific contract
`load_voltage_base_consistency` (`PSK-000004`). The contract applies to
voltage-dependent WYE and DELTA loads whose buses have a nominal
phase-to-neutral voltage reachable from a declared voltage source through the
existing BMOPFTools voltage-level propagation.

For each selected load, the expected nominal anchor is the propagated
phase-to-neutral bus base for WYE and that base multiplied by `sqrt(3)` for
DELTA. Every scalar or per-subload `v_nom` must lie within the declared ratio
band. This uses the same connection-coordinate conversion and default
plausibility band as `W.LOAD.VNOM_MISMATCH` in [`domain_rules_check`](@ref).

A pass establishes only consistency among the declared source-propagated bus
base, load connection, and load-model nominal anchor. It does not validate the
source or transformer declarations used to infer the base, the load law or
coefficients, operating-point voltage, network equations, equipment limits, or
unit provenance.
"""
function check_load_voltage_base_consistency(
        net::Dict{String,Any};
        load_ids::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
        ratio_min::Real=0.8,
        ratio_max::Real=1.25)::ScientificContractResult
    ratio_min_f = Float64(ratio_min)
    ratio_max_f = Float64(ratio_max)
    (isfinite(ratio_min_f) && isfinite(ratio_max_f) &&
     0 < ratio_min_f <= 1 <= ratio_max_f) || throw(ArgumentError(
        "ratio_min and ratio_max must be finite, positive, and bracket 1"))

    loads = get(net, "load", nothing)
    if !(loads isa AbstractDict) || isempty(loads)
        return _load_voltage_base_refusal(
            :inapplicable, "I.CONTRACT.LOAD_VOLTAGE_BASE_NOT_APPLICABLE", INFO,
            "Load voltage-base consistency is not applicable: the network has no loads.",
            String[], "the network has no loads")
    end

    requested = if load_ids === nothing
        sort([string(id) for (id, load) in loads
              if load isa AbstractDict &&
                 get(load, "model", "constant_power") != "constant_power"])
    else
        String.(load_ids)
    end
    if isempty(requested) || length(unique(requested)) != length(requested)
        return _load_voltage_base_refusal(
            :inapplicable, "I.CONTRACT.LOAD_VOLTAGE_BASE_NOT_APPLICABLE", INFO,
            "Load voltage-base consistency is not applicable: load_ids must identify at least one unique voltage-dependent load.",
            requested, "no unique voltage-dependent load was selected")
    end

    selected = Pair{String,Any}[]
    for id in requested
        load = get(loads, id, nothing)
        if !(load isa AbstractDict)
            return _load_voltage_base_refusal(
                :indeterminate, "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE", WARNING,
                "Load voltage-base consistency is indeterminate: load '$id' is missing.",
                requested, "load '$id' is missing")
        end
        model = string(get(load, "model", "constant_power"))
        if model == "constant_power"
            return _load_voltage_base_refusal(
                :inapplicable, "I.CONTRACT.LOAD_VOLTAGE_BASE_NOT_APPLICABLE", INFO,
                "Load voltage-base consistency is not applicable: load '$id' is constant-power and has no operative voltage anchor.",
                requested, "load '$id' is constant-power")
        end
        configuration = string(get(load, "configuration", "WYE"))
        if !(configuration in ("WYE", "DELTA"))
            return _load_voltage_base_refusal(
                :inapplicable, "I.CONTRACT.LOAD_VOLTAGE_BASE_NOT_APPLICABLE", INFO,
                "Load voltage-base consistency is not applicable: load '$id' has unsupported configuration '$configuration'.",
                requested, "load '$id' has unsupported configuration '$configuration'")
        end
        push!(selected, id => load)
    end

    bus_bases = try
        _assign_nominal_voltages(net)
    catch error
        return _load_voltage_base_refusal(
            :indeterminate, "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE", WARNING,
            "Load voltage-base consistency is indeterminate: nominal bus voltages could not be propagated.",
            requested, "nominal bus voltage propagation failed: $(sprint(showerror, error))")
    end

    records = Dict{String,Any}()
    mismatches = String[]
    for (id, load) in selected
        bus_id = get(load, "bus", nothing)
        if !(bus_id isa AbstractString) || !haskey(bus_bases, String(bus_id))
            return _load_voltage_base_refusal(
                :indeterminate, "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE", WARNING,
                "Load voltage-base consistency is indeterminate: load '$id' has no source-reachable bus voltage base.",
                requested, "load '$id' has no source-reachable bus voltage base")
        end
        raw_vnom = get(load, "v_nom", nothing)
        values = if raw_vnom isa Number
            [Float64(raw_vnom)]
        elseif raw_vnom isa AbstractVector && all(value -> value isa Number, raw_vnom)
            Float64.(raw_vnom)
        else
            return _load_voltage_base_refusal(
                :indeterminate, "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE", WARNING,
                "Load voltage-base consistency is indeterminate: load '$id' has no numeric v_nom.",
                requested, "load '$id' has no numeric v_nom")
        end
        if isempty(values) || any(value -> !isfinite(value) || value <= 0, values)
            return _load_voltage_base_refusal(
                :indeterminate, "W.CONTRACT.LOAD_VOLTAGE_BASE_INDETERMINATE", WARNING,
                "Load voltage-base consistency is indeterminate: load '$id' has an empty, non-finite, or non-positive v_nom.",
                requested, "load '$id' has an invalid v_nom")
        end

        configuration = string(get(load, "configuration", "WYE"))
        bus_base_pn = bus_bases[String(bus_id)]
        expected = _load_nominal_voltage_base(bus_base_pn, configuration)
        ratios = values ./ expected
        outside_ratio_band(ratio) = begin
            endpoint_atol = 8 * eps(max(abs(ratio), abs(ratio_min_f),
                                        abs(ratio_max_f), 1.0))
            below = ratio < ratio_min_f &&
                    !isapprox(ratio, ratio_min_f; atol=endpoint_atol, rtol=0)
            above = ratio > ratio_max_f &&
                    !isapprox(ratio, ratio_max_f; atol=endpoint_atol, rtol=0)
            below || above
        end
        load_mismatch = any(outside_ratio_band, ratios)
        load_mismatch && push!(mismatches, id)
        records[id] = Dict{String,Any}(
            "bus" => String(bus_id),
            "configuration" => configuration,
            "voltage_coordinate" => configuration == "DELTA" ? "line_to_line" : "phase_to_neutral",
            "bus_phase_to_neutral_base_V" => bus_base_pn,
            "expected_v_nom_V" => expected,
            "declared_v_nom_V" => values,
            "ratios" => ratios,
            "within_ratio_band" => !load_mismatch,
        )
    end

    checked = [
        "source_propagated_bus_voltage_base",
        "declared_load_connection_voltage_coordinate",
        "load_nominal_voltage_anchor",
    ]
    evidence = Dict{String,Any}(
        "load_ids" => requested,
        "ratio_band" => Dict{String,Any}("minimum" => ratio_min_f,
                                         "maximum" => ratio_max_f),
        "loads" => records,
    )
    if !isempty(mismatches)
        evidence["classification"] = "connection_voltage_base_mismatch"
        evidence["mismatched_load_ids"] = mismatches
        detail = merge(copy(evidence), Dict{String,Any}(
            "knowledge_ids" => [_LOAD_VOLTAGE_BASE_PSK],
            "contract_id" => _LOAD_VOLTAGE_BASE_CONTRACT,
            "invalid_inferences" => [
                "The same numeric nominal voltage cannot be used for WYE phase-to-neutral and DELTA line-to-line load coordinates without an explicit base conversion.",
            ],
            "recommended_checks" => [
                "Use the propagated phase-to-neutral base for WYE loads and sqrt(3) times that base for DELTA loads.",
                "Rerun domain_rules_check and resolve W.LOAD.VNOM_MISMATCH before solving a voltage-dependent load model.",
            ],
        ))
        finding = Finding(ERROR, "E.CONTRACT.LOAD_VOLTAGE_BASE_MISMATCH",
            :scientific_contract, :load,
            length(mismatches) == 1 ? only(mismatches) : nothing,
            "Voltage-dependent load nominal voltage uses a connection-inconsistent base for $(join(mismatches, ", ")).",
            detail)
        return _load_voltage_base_result(:failed, [finding], evidence; checked=checked)
    end

    evidence["classification"] = "connection_voltage_bases_consistent"
    evidence["qualification"] =
        "Pass covers consistency with the declared source-propagated base only; it does not validate the declarations, load law, or solved operating point."
    _load_voltage_base_result(:passed, Finding[], evidence; checked=checked)
end

function _transformer_tap_result(status::Symbol, findings::Vector{Finding},
                                 evidence::Dict{String,Any}; checked=String[])
    ScientificContractResult(
        _TRANSFORMER_TAP_DOMAIN_CONTRACT,
        status,
        [_TRANSFORMER_TAP_DOMAIN_PSK],
        checked,
        [
            "pointwise_terminal_equations",
            "tap_dependent_leakage_or_excitation",
            "discrete_tap_positions",
            "mechanical_or_per_phase_coupling",
            "automatic_control_logic",
            "network_feasible_set",
            "objective_value",
            "optimal_tap",
            "solver_status_or_optimality",
        ],
        findings,
        evidence,
    )
end

function _transformer_tap_refusal(status::Symbol, code::String, severity::Severity,
                                  message::String, mapping::Dict{String,String}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_TRANSFORMER_TAP_DOMAIN_PSK],
        "contract_id" => _TRANSFORMER_TAP_DOMAIN_CONTRACT,
        "transformer_mapping" => mapping,
        "reason" => reason,
        "invalid_inferences" => [
            "No tap-decision preservation conclusion follows when the source has no valid adjustable domain or the mapped base transformer factors differ.",
        ],
        "recommended_checks" => [
            "Provide a mapped two-winding isolating transformer with a finite positive source tap interval.",
            "Keep all non-tap transformer declarations unchanged and retain the complete tap decision domain in the target.",
        ],
    )
    finding = Finding(severity, code, :scientific_contract, :transformer,
                      get(mapping, "target_id", nothing), message, detail)
    _transformer_tap_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "transformer_mapping" => mapping,
        "reason" => reason,
    ))
end

function _transformer_tap_record(net::Dict{String,Any}, subtype::String, id::String)
    transformers = get(net, "transformer", nothing)
    transformers isa AbstractDict || return nothing
    records = get(transformers, subtype, nothing)
    records isa AbstractDict || return nothing
    record = get(records, id, nothing)
    record isa AbstractDict ? record : nothing
end

function _transformer_tap_domain(record::AbstractDict; require_adjustable::Bool)
    has_min = haskey(record, "tap_min")
    has_max = haskey(record, "tap_max")
    if has_min != has_max
        return (nothing, :indeterminate, "tap_min and tap_max must be declared together")
    end

    raw_start = get(record, "tap", 1.0)
    raw_start isa Number || return (nothing, :indeterminate, "tap start is not numeric")
    start = Float64(raw_start)
    isfinite(start) && start > 0 ||
        return (nothing, :indeterminate, "tap start must be finite and positive")

    if !has_min
        require_adjustable && return (nothing, :inapplicable,
            "source transformer has no declared adjustable tap interval")
        return ((minimum=start, maximum=start, start=start, explicit=false), :applicable, "")
    end

    raw_min = record["tap_min"]
    raw_max = record["tap_max"]
    (raw_min isa Number && raw_max isa Number) ||
        return (nothing, :indeterminate, "tap interval bounds are not numeric")
    lower = Float64(raw_min)
    upper = Float64(raw_max)
    all(isfinite, (lower, upper)) && lower > 0 && upper > 0 ||
        return (nothing, :indeterminate, "tap interval bounds must be finite and positive")
    lower <= upper || return (nothing, :indeterminate, "tap_min exceeds tap_max")
    require_adjustable && lower == upper && return (nothing, :inapplicable,
        "source tap interval is a singleton rather than an adjustable decision domain")
    lower <= start <= upper ||
        return (nothing, :indeterminate, "tap start lies outside the declared interval")
    ((minimum=lower, maximum=upper, start=start, explicit=true), :applicable, "")
end

function _transformer_without_tap_domain(record::AbstractDict)::Dict{String,Any}
    ignored = Set(["tap", "tap_min", "tap_max"])
    Dict{String,Any}(string(key) => value for (key, value) in record
                     if !(string(key) in ignored))
end

"""
    check_transformer_tap_domain_preservation(source, target;
        source_subtype, source_id, target_subtype=source_subtype,
        target_id=source_id, atol=1e-9, rtol=1e-8)
        -> ScientificContractResult

Check the initial executable portion of scientific contract
`transformer_tap_domain_preservation` (`PSK-000005`). The source must contain
an adjustable two-winding isolating transformer with a finite positive
`tap_min < tap_max` interval. The target transformer must have the same subtype
and identical non-tap declarations under the explicit mapping.

The check compares the complete continuous tap intervals. Omitting target
bounds is interpreted according to the BMOPFTools data model as a fixed
singleton at `tap` (default `1.0`). A narrower target interval is an inner
restriction; a wider interval is an outer extension; shifted or disjoint
intervals are different decision domains. Any mismatch returns `:failed` with
`E.CONTRACT.TRANSFORMER_TAP_DOMAIN_LOSS` and an interval witness.

A pass establishes only preservation of the mapped base-factor declaration,
tap-start admissibility, and continuous decision domain. It does not establish
pointwise terminal equations, tap-dependent losses, discrete positions,
automatic controls, network feasible-set equality, objective equality, an
optimal tap, or solver guarantees.
"""
function check_transformer_tap_domain_preservation(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_subtype::AbstractString,
        source_id::AbstractString,
        target_subtype::AbstractString=source_subtype,
        target_id::AbstractString=source_id,
        atol::Real=1e-9,
        rtol::Real=1e-8)::ScientificContractResult
    atol_f = Float64(atol)
    rtol_f = Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))

    source_type = String(source_subtype)
    target_type = String(target_subtype)
    source_key = String(source_id)
    target_key = String(target_id)
    mapping = Dict{String,String}(
        "source_subtype" => source_type,
        "source_id" => source_key,
        "target_subtype" => target_type,
        "target_id" => target_key,
    )
    if !(source_type in _TRANSFORMER_TAP_SUBTYPES) ||
       !(target_type in _TRANSFORMER_TAP_SUBTYPES) || source_type != target_type
        return _transformer_tap_refusal(
            :inapplicable, "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE", INFO,
            "Transformer tap-domain preservation is not applicable: source and target must use the same supported isolating-transformer subtype.",
            mapping, "source and target subtypes are unsupported or differ")
    end

    source_record = _transformer_tap_record(source, source_type, source_key)
    source_record === nothing && return _transformer_tap_refusal(
        :indeterminate, "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE", WARNING,
        "Transformer tap-domain preservation is indeterminate: mapped source transformer is missing.",
        mapping, "mapped source transformer is missing")
    target_record = _transformer_tap_record(target, target_type, target_key)
    target_record === nothing && return _transformer_tap_refusal(
        :indeterminate, "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE", WARNING,
        "Transformer tap-domain preservation is indeterminate: mapped target transformer is missing.",
        mapping, "mapped target transformer is missing")

    source_domain, source_status, source_reason =
        _transformer_tap_domain(source_record; require_adjustable=true)
    if source_domain === nothing
        status = source_status === :inapplicable ? :inapplicable : :indeterminate
        code = status === :inapplicable ?
            "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE" :
            "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE"
        severity = status === :inapplicable ? INFO : WARNING
        return _transformer_tap_refusal(status, code, severity,
            "Transformer tap-domain preservation is $status: $source_reason.",
            mapping, source_reason)
    end
    target_domain, target_status, target_reason =
        _transformer_tap_domain(target_record; require_adjustable=false)
    if target_domain === nothing
        status = target_status === :inapplicable ? :inapplicable : :indeterminate
        code = status === :inapplicable ?
            "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE" :
            "W.CONTRACT.TRANSFORMER_TAP_INDETERMINATE"
        severity = status === :inapplicable ? INFO : WARNING
        return _transformer_tap_refusal(status, code, severity,
            "Transformer tap-domain preservation is $status: $target_reason.",
            mapping, target_reason)
    end

    source_base = _transformer_without_tap_domain(source_record)
    target_base = _transformer_without_tap_domain(target_record)
    source_base == target_base || return _transformer_tap_refusal(
        :inapplicable, "I.CONTRACT.TRANSFORMER_TAP_NOT_APPLICABLE", INFO,
        "Transformer tap-domain preservation is not applicable: mapped non-tap transformer declarations differ.",
        mapping, "mapped non-tap transformer declarations differ")

    tolerance = atol_f + rtol_f * max(abs(source_domain.minimum),
                                      abs(source_domain.maximum),
                                      abs(target_domain.minimum),
                                      abs(target_domain.maximum), 1.0)
    same_lower = abs(source_domain.minimum - target_domain.minimum) <= tolerance
    same_upper = abs(source_domain.maximum - target_domain.maximum) <= tolerance
    evidence = Dict{String,Any}(
        "transformer_mapping" => mapping,
        "source_domain" => Dict{String,Any}(
            "minimum" => source_domain.minimum,
            "maximum" => source_domain.maximum,
            "start" => source_domain.start,
            "explicit" => source_domain.explicit,
        ),
        "target_domain" => Dict{String,Any}(
            "minimum" => target_domain.minimum,
            "maximum" => target_domain.maximum,
            "start" => target_domain.start,
            "explicit" => target_domain.explicit,
        ),
        "domain_tolerance" => tolerance,
        "base_factor_declarations_equal" => true,
    )
    checked = [
        "mapped_transformer_base_factor_identity",
        "tap_start_admissibility",
        "continuous_tap_decision_domain",
    ]
    if same_lower && same_upper
        evidence["classification"] = "continuous_tap_domain_preserved"
        evidence["qualification"] =
            "Pass covers the mapped continuous tap interval and base declaration only; it is not a network decision-equivalence or optimality certificate."
        return _transformer_tap_result(:passed, Finding[], evidence; checked=checked)
    end

    source_contains_target =
        target_domain.minimum >= source_domain.minimum - tolerance &&
        target_domain.maximum <= source_domain.maximum + tolerance
    target_contains_source =
        source_domain.minimum >= target_domain.minimum - tolerance &&
        source_domain.maximum <= target_domain.maximum + tolerance
    classification = source_contains_target ? "inner_restriction" :
                     target_contains_source ? "outer_extension" :
                     max(source_domain.minimum, target_domain.minimum) <=
                         min(source_domain.maximum, target_domain.maximum) + tolerance ?
                         "shifted_partial_overlap" : "disjoint_domain"

    witness_tap = if source_domain.minimum < target_domain.minimum - tolerance
        source_domain.minimum
    elseif source_domain.maximum > target_domain.maximum + tolerance
        source_domain.maximum
    elseif target_domain.minimum < source_domain.minimum - tolerance
        target_domain.minimum
    else
        target_domain.maximum
    end
    admissible(value, domain) =
        domain.minimum - tolerance <= value <= domain.maximum + tolerance
    evidence["classification"] = classification
    evidence["witness"] = Dict{String,Any}(
        "tap" => witness_tap,
        "source_admissible" => admissible(witness_tap, source_domain),
        "target_admissible" => admissible(witness_tap, target_domain),
    )
    detail = merge(copy(evidence), Dict{String,Any}(
        "knowledge_ids" => [_TRANSFORMER_TAP_DOMAIN_PSK],
        "contract_id" => _TRANSFORMER_TAP_DOMAIN_CONTRACT,
        "invalid_inferences" => [
            "Evaluating or storing an adjustable transformer only at its start tap does not preserve the source tap decision domain.",
        ],
        "recommended_checks" => [
            "Retain tap_min and tap_max with the mapped transformer instead of replacing the decision by one fixed tap.",
            "Verify pointwise transformer equations and network constraints separately at every tap required by the study.",
        ],
    ))
    finding = Finding(ERROR, "E.CONTRACT.TRANSFORMER_TAP_DOMAIN_LOSS",
        :scientific_contract, :transformer, target_key,
        "Mapped transformer '$target_key' has a $classification relative to source tap interval [$(source_domain.minimum), $(source_domain.maximum)].",
        detail)
    _transformer_tap_result(:failed, [finding], evidence; checked=checked)
end

function _transformer_winding_convention_result(
        status::Symbol, findings::Vector{Finding}, evidence::Dict{String,Any};
        checked=String[])
    ScientificContractResult(
        _TRANSFORMER_WINDING_CONVENTION_CONTRACT,
        status,
        [_TRANSFORMER_WINDING_CONVENTION_PSK],
        checked,
        [
            "series_leakage_parameters",
            "excitation_shunt_placement_and_value",
            "internal_or_external_grounding",
            "tap_decision_domain",
            "current_and_apparent_power_limits",
            "complete_terminal_admittance_or_ideal_constraints",
            "automatic_control_logic",
            "network_feasible_set",
            "objective_value",
            "solver_status_or_optimality",
        ],
        findings,
        evidence,
    )
end

function _transformer_winding_convention_refusal(
        status::Symbol, code::String, severity::Severity, message::String,
        mapping::Dict{String,Any}, reason::String)
    detail = Dict{String,Any}(
        "knowledge_ids" => [_TRANSFORMER_WINDING_CONVENTION_PSK],
        "contract_id" => _TRANSFORMER_WINDING_CONVENTION_CONTRACT,
        "transformer_mapping" => mapping,
        "reason" => reason,
        "invalid_inferences" => [
            "No winding-convention preservation conclusion follows from a bare endpoint swap, an unsupported subtype change, or incomplete terminal mapping.",
        ],
        "recommended_checks" => [
            "Map both transformer buses and every renamed terminal explicitly.",
            "Retain the typed winding roles, ordered terminal-to-coil relation, winding reference voltages, and fixed tap coefficient.",
            "Use transformer_tap_domain_preservation separately when either transformer has an adjustable tap domain.",
        ],
    )
    target_id = get(mapping, "target_id", nothing)
    finding = Finding(severity, code, :scientific_contract, :transformer,
                      target_id isa String ? target_id : nothing, message, detail)
    _transformer_winding_convention_result(status, [finding], Dict{String,Any}(
        "applicability" => string(status),
        "transformer_mapping" => mapping,
        "reason" => reason,
    ))
end

function _transformer_winding_role(subtype::String, side::String)::String
    subtype == "wye_delta" && return side == "from" ? "wye" : "delta"
    subtype == "delta_wye" && return side == "from" ? "delta" : "wye"
    side == "from" ? "winding_1" : "winding_2"
end

function _transformer_fixed_tap(record::AbstractDict)
    domain, status, reason = _transformer_tap_domain(record; require_adjustable=false)
    domain === nothing && return (nothing, status, reason)
    domain.minimum == domain.maximum || return (
        nothing, :inapplicable,
        "transformer has an adjustable tap interval; use transformer_tap_domain_preservation",
    )
    (domain.start, :applicable, "")
end

function _transformer_reference_voltage(record::AbstractDict, side::String)
    key = "v_nom_" * side
    raw = get(record, key, nothing)
    raw isa Number || return (nothing, "$key is missing or nonnumeric")
    value = Float64(raw)
    isfinite(value) && value > 0 || return (nothing, "$key must be finite and positive")
    value, ""
end

function _transformer_terminal_map(record::AbstractDict, side::String)
    key = "terminal_map_" * side
    raw = get(record, key, nothing)
    raw isa AbstractVector || return (nothing, "$key is missing or is not an array")
    labels = String[string(item) for item in raw]
    isempty(labels) && return (nothing, "$key is empty")
    length(labels) == length(unique(labels)) || return (nothing, "$key contains duplicate labels")
    labels, ""
end

function _transformer_incidence_payload(incidence; map_node=identity)
    [
        Dict{String,Any}(
            "core_index" => index,
            "winding_1" => [
                Dict{String,Any}(
                    "bus" => map_node(node)[1],
                    "terminal" => map_node(node)[2],
                    "coefficient" => coefficient,
                )
                for (node, coefficient) in zip(core.w1_nodes, core.w1_coeffs)
            ],
            "winding_2" => [
                Dict{String,Any}(
                    "bus" => map_node(node)[1],
                    "terminal" => map_node(node)[2],
                    "coefficient" => coefficient,
                )
                for (node, coefficient) in zip(core.w2_nodes, core.w2_coeffs)
            ],
            "effective_coil_ratio" => core.ratio,
        )
        for (index, core) in enumerate(incidence)
    ]
end

function _transformer_incidence_structure(payload)
    [
        (
            [(item["bus"], item["terminal"], item["coefficient"])
             for item in core["winding_1"]],
            [(item["bus"], item["terminal"], item["coefficient"])
             for item in core["winding_2"]],
        )
        for core in payload
    ]
end

"""
    check_transformer_winding_convention_preservation(source, target;
        source_subtype, source_id, target_subtype=source_subtype,
        target_id=source_id, bus_mapping, terminal_mapping=Dict(),
        atol=1e-9, rtol=1e-8) -> ScientificContractResult

Check the initial executable portion of scientific contract
`transformer_winding_convention_preservation` (`PSK-000006`). The check covers
fixed-tap `single_phase`, `wye_delta`, and `delta_wye` transformer records with
the same subtype, an explicit one-to-one source-bus to target-bus mapping, and
stable terminal labels or an explicit global terminal-label mapping.

It compares mapped winding-side identity, ordered terminal-to-coil incidence,
positive winding reference-voltage declarations, and the resulting fixed
effective coil ratio. A bare `bus_from`/`bus_to` swap therefore fails: a
transformer side is a typed winding role, not an arbitrary branch arrow.

A pass does not establish equality of leakage, excitation, grounding, limits,
the complete terminal factor, tap decision domains, controls, network feasible
sets, objectives, or solver results. Adjustable taps are explicitly
`:inapplicable` here and belong to `transformer_tap_domain_preservation`.
"""
function check_transformer_winding_convention_preservation(
        source::Dict{String,Any}, target::Dict{String,Any};
        source_subtype::AbstractString,
        source_id::AbstractString,
        target_subtype::AbstractString=source_subtype,
        target_id::AbstractString=source_id,
        bus_mapping::AbstractDict,
        terminal_mapping::AbstractDict=Dict{String,String}(),
        atol::Real=1e-9,
        rtol::Real=1e-8)::ScientificContractResult
    atol_f = Float64(atol)
    rtol_f = Float64(rtol)
    (isfinite(atol_f) && atol_f >= 0 && isfinite(rtol_f) && rtol_f >= 0) ||
        throw(ArgumentError("atol and rtol must be finite and nonnegative"))

    source_type = String(source_subtype)
    target_type = String(target_subtype)
    source_key = String(source_id)
    target_key = String(target_id)
    buses = Dict{String,String}(string(key) => string(value)
                                for (key, value) in bus_mapping)
    terminals = Dict{String,String}(string(key) => string(value)
                                    for (key, value) in terminal_mapping)
    mapping = Dict{String,Any}(
        "source_subtype" => source_type,
        "source_id" => source_key,
        "target_subtype" => target_type,
        "target_id" => target_key,
        "bus_mapping" => buses,
        "terminal_mapping" => terminals,
    )

    if !(source_type in _TRANSFORMER_WINDING_CONVENTION_SUBTYPES) ||
       !(target_type in _TRANSFORMER_WINDING_CONVENTION_SUBTYPES) ||
       source_type != target_type
        return _transformer_winding_convention_refusal(
            :inapplicable, "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE", INFO,
            "Transformer winding-convention preservation is not applicable: source and target must use the same supported subtype.",
            mapping, "source and target subtypes are unsupported or differ")
    end

    source_record = _transformer_tap_record(source, source_type, source_key)
    source_record === nothing && return _transformer_winding_convention_refusal(
        :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
        "Transformer winding-convention preservation is indeterminate: mapped source transformer is missing.",
        mapping, "mapped source transformer is missing")
    target_record = _transformer_tap_record(target, target_type, target_key)
    target_record === nothing && return _transformer_winding_convention_refusal(
        :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
        "Transformer winding-convention preservation is indeterminate: mapped target transformer is missing.",
        mapping, "mapped target transformer is missing")

    source_buses = String[]
    target_buses = String[]
    source_maps = Dict{String,Vector{String}}()
    target_maps = Dict{String,Vector{String}}()
    source_refs = Dict{String,Float64}()
    target_refs = Dict{String,Float64}()
    for side in ("from", "to")
        source_bus = get(source_record, "bus_" * side, nothing)
        target_bus = get(target_record, "bus_" * side, nothing)
        (source_bus isa AbstractString && target_bus isa AbstractString) ||
            return _transformer_winding_convention_refusal(
                :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
                "Transformer winding-convention preservation is indeterminate: mapped transformer bus declarations are incomplete.",
                mapping, "source or target bus declaration is missing")
        push!(source_buses, string(source_bus))
        push!(target_buses, string(target_bus))

        source_map, source_map_reason = _transformer_terminal_map(source_record, side)
        source_map === nothing && return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: $source_map_reason.",
            mapping, source_map_reason)
        target_map, target_map_reason = _transformer_terminal_map(target_record, side)
        target_map === nothing && return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: $target_map_reason.",
            mapping, target_map_reason)
        source_maps[side] = source_map
        target_maps[side] = target_map

        source_ref, source_ref_reason = _transformer_reference_voltage(source_record, side)
        source_ref === nothing && return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: $source_ref_reason.",
            mapping, source_ref_reason)
        target_ref, target_ref_reason = _transformer_reference_voltage(target_record, side)
        target_ref === nothing && return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: $target_ref_reason.",
            mapping, target_ref_reason)
        source_refs[side] = source_ref
        target_refs[side] = target_ref
    end

    length(unique(source_buses)) == 2 && length(unique(target_buses)) == 2 ||
        return _transformer_winding_convention_refusal(
            :inapplicable, "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE", INFO,
            "Transformer winding-convention preservation is not applicable: each transformer must connect two distinct buses.",
            mapping, "source or target transformer does not connect two distinct buses")
    all(haskey(buses, bus) for bus in source_buses) ||
        return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: bus mapping is incomplete.",
            mapping, "bus mapping omits a source transformer bus")
    length(unique([buses[bus] for bus in source_buses])) == 2 ||
        return _transformer_winding_convention_refusal(
            :inapplicable, "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE", INFO,
            "Transformer winding-convention preservation is not applicable: mapped source transformer buses are not one-to-one.",
            mapping, "bus mapping is not one-to-one")

    source_labels = unique(vcat(values(source_maps)...))
    mapped_labels = [get(terminals, label, label) for label in source_labels]
    length(mapped_labels) == length(unique(mapped_labels)) ||
        return _transformer_winding_convention_refusal(
            :inapplicable, "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE", INFO,
            "Transformer winding-convention preservation is not applicable: terminal mapping is not one-to-one.",
            mapping, "terminal mapping collapses source terminal labels")

    source_tap, source_tap_status, source_tap_reason =
        _transformer_fixed_tap(source_record)
    source_tap === nothing && return _transformer_winding_convention_refusal(
        source_tap_status === :inapplicable ? :inapplicable : :indeterminate,
        source_tap_status === :inapplicable ?
            "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE" :
            "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE",
        source_tap_status === :inapplicable ? INFO : WARNING,
        "Transformer winding-convention preservation is $(source_tap_status): $source_tap_reason.",
        mapping, source_tap_reason)
    target_tap, target_tap_status, target_tap_reason =
        _transformer_fixed_tap(target_record)
    target_tap === nothing && return _transformer_winding_convention_refusal(
        target_tap_status === :inapplicable ? :inapplicable : :indeterminate,
        target_tap_status === :inapplicable ?
            "I.CONTRACT.TRANSFORMER_WINDING_NOT_APPLICABLE" :
            "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE",
        target_tap_status === :inapplicable ? INFO : WARNING,
        "Transformer winding-convention preservation is $(target_tap_status): $target_tap_reason.",
        mapping, target_tap_reason)

    source_incidence = _xfmr_winding_incidence(source_record, source_type)
    target_incidence = _xfmr_winding_incidence(target_record, target_type)
    (isempty(source_incidence) || isempty(target_incidence)) &&
        return _transformer_winding_convention_refusal(
            :indeterminate, "W.CONTRACT.TRANSFORMER_WINDING_INDETERMINATE", WARNING,
            "Transformer winding-convention preservation is indeterminate: terminal-to-coil incidence could not be constructed.",
            mapping, "source or target terminal-to-coil incidence is empty")

    map_node(node) = (buses[node[1]], get(terminals, node[2], node[2]))
    source_payload = _transformer_incidence_payload(source_incidence; map_node=map_node)
    target_payload = _transformer_incidence_payload(target_incidence)
    source_structure = _transformer_incidence_structure(source_payload)
    target_structure = _transformer_incidence_structure(target_payload)
    incidence_match = source_structure == target_structure

    ratio_tolerance = atol_f + rtol_f * max(
        maximum(abs(core.ratio) for core in source_incidence),
        maximum(abs(core.ratio) for core in target_incidence), 1.0)
    ratio_match = length(source_incidence) == length(target_incidence) &&
                  all(abs(source_incidence[index].ratio - target_incidence[index].ratio) <=
                      ratio_tolerance for index in eachindex(source_incidence))
    reference_mismatches = String[]
    reference_evidence = Dict{String,Any}()
    for side in ("from", "to")
        tolerance = atol_f + rtol_f * max(abs(source_refs[side]), abs(target_refs[side]), 1.0)
        same = abs(source_refs[side] - target_refs[side]) <= tolerance
        same || push!(reference_mismatches, side)
        reference_evidence[side] = Dict{String,Any}(
            "winding_role" => _transformer_winding_role(source_type, side),
            "mapped_source_bus" => buses[source_buses[side == "from" ? 1 : 2]],
            "target_bus" => target_buses[side == "from" ? 1 : 2],
            "source_v_nom_V" => source_refs[side],
            "target_v_nom_V" => target_refs[side],
            "within_tolerance" => same,
        )
    end
    base_ratio_match = isempty(reference_mismatches) && ratio_match

    evidence = Dict{String,Any}(
        "transformer_mapping" => mapping,
        "winding_references" => reference_evidence,
        "source_fixed_tap" => source_tap,
        "target_fixed_tap" => target_tap,
        "source_mapped_incidence" => source_payload,
        "target_incidence" => target_payload,
        "incidence_match" => incidence_match,
        "reference_voltage_mismatch_sides" => reference_mismatches,
        "effective_coil_ratio_match" => ratio_match,
        "ratio_tolerance" => ratio_tolerance,
    )
    checked = [
        "mapped_winding_side_identity_and_orientation",
        "ordered_terminal_to_coil_incidence",
        "nominal_winding_reference_voltages",
        "fixed_effective_coil_ratio",
    ]
    if incidence_match && base_ratio_match
        evidence["classification"] = "winding_convention_preserved"
        evidence["qualification"] =
            "Pass covers winding roles, incidence, references, and fixed coil ratio only; it is not a complete transformer-factor or decision-equivalence certificate."
        return _transformer_winding_convention_result(
            :passed, Finding[], evidence; checked=checked)
    end

    findings = Finding[]
    if !incidence_match
        detail = merge(copy(evidence), Dict{String,Any}(
            "knowledge_ids" => [_TRANSFORMER_WINDING_CONVENTION_PSK],
            "contract_id" => _TRANSFORMER_WINDING_CONVENTION_CONTRACT,
            "invalid_inferences" => [
                "A transformer's bus_from/bus_to order is not an arbitrary edge arrow when the ordered terminal maps define typed winding coils.",
            ],
            "recommended_checks" => [
                "Restore the mapped winding buses and ordered terminal-to-coil incidence, or provide a complete typed coordinate transformation.",
            ],
        ))
        push!(findings, Finding(ERROR,
            "E.CONTRACT.TRANSFORMER_WINDING_INCIDENCE_MISMATCH",
            :scientific_contract, :transformer, target_key,
            "Mapped transformer '$target_key' changes winding-side orientation or terminal-to-coil incidence.",
            detail))
    end
    if !base_ratio_match
        detail = merge(copy(evidence), Dict{String,Any}(
            "knowledge_ids" => [_TRANSFORMER_WINDING_CONVENTION_PSK],
            "contract_id" => _TRANSFORMER_WINDING_CONVENTION_CONTRACT,
            "invalid_inferences" => [
                "Matching bus endpoints does not preserve transformer semantics when winding reference voltages or the fixed effective coil ratio change.",
            ],
            "recommended_checks" => [
                "Retain each mapped winding reference voltage and fixed tap coefficient in the same connection convention.",
            ],
        ))
        push!(findings, Finding(ERROR,
            "E.CONTRACT.TRANSFORMER_WINDING_BASE_RATIO_MISMATCH",
            :scientific_contract, :transformer, target_key,
            "Mapped transformer '$target_key' changes a winding reference voltage or fixed effective coil ratio.",
            detail))
    end
    evidence["classification"] = !incidence_match && !base_ratio_match ?
        "winding_incidence_and_base_ratio_mismatch" :
        !incidence_match ? "winding_incidence_mismatch" :
        "winding_base_ratio_mismatch"
    _transformer_winding_convention_result(:failed, findings, evidence; checked=checked)
end
