# Scientific-contract checks linking concrete BMOPF models to broader,
# repository-external scientific knowledge. This file contains executable
# semantics only; claims, literature, and long-form explanations remain in
# multi-graph-book.

const _PARALLEL_MEMBER_LIMIT_CONTRACT = "parallel_member_limit_preservation"
const _PARALLEL_MEMBER_LIMIT_PSK = "PSK-000001"
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
