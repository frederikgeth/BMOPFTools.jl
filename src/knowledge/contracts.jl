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
