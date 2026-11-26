# report/finding_consolidation.jl
#
# Report-level consolidation of the Findings one `analyze` call collected.
#
# The passes stay simple: each emits one Finding per affected component, and
# two passes may each describe the same root cause from their own angle. That
# is the right shape for a pass, and the wrong shape for a reader of a feeder
# with a thousand sub-meter line segments. This step, run once by `analyze`
# after every pass, makes the report proportional to the number of distinct
# problems rather than the number of affected components:
#
# 1. **Subsumption** — a Finding is dropped when a stronger Finding already
#    states the same fact about the same component (`_SUBSUMED_BY`).
# 2. **Roll-up** — when one INFO/WARNING code is raised on more than
#    `[report] rollup_threshold` components, those Findings become a single
#    Finding with the same code and severity that lists the components.
#
# Both steps are lossless: `results[:consolidation]` records what was dropped,
# and `expand_findings` restores the per-component Findings of a roll-up.
# ERROR Findings are never rolled up or dropped.

# (weaker code, stronger code): the weaker Finding is dropped for a component
# that also carries the stronger one. Both describe the same root cause.
const _SUBSUMED_BY = (
    # A line whose absolute impedance is below the conditioning threshold is,
    # a fortiori, "switch-like"; the warning already recommends a switch.
    ("I.PROV.LINE_SWITCH_LIKE", "W.DOM.LINE_LOW_IMPEDANCE"),
)

# (weaker code, stronger code) for network-level aggregates. The weaker one is
# dropped only when both count the same components.
const _SUBSUMED_AGGREGATE = (
    # Both report lines with no thermal limit; the provenance Finding names them.
    ("W.OPS.LINE_UNCONSTRAINED", "W.PROV.I_MAX_ABSENT", "n_unconstrained", "lines"),
)

const _ROLLUP_DETAIL_KEY = "rolled_up"

_rollup_threshold(config) = begin
    section = get(config, "report", nothing)
    value = section isa AbstractDict ? get(section, "rollup_threshold", 25) : 25
    value isa Integer && !(value isa Bool) && value >= 0 ? Int(value) : 25
end

"""
    is_rolled_up(finding::Finding) -> Bool

Whether `finding` is a roll-up that stands for several per-component Findings
of the same code (see [`expand_findings`](@ref)).
"""
is_rolled_up(f::Finding) =
    f.detail isa AbstractDict && get(f.detail, _ROLLUP_DETAIL_KEY, false) === true

"""
    expand_findings(findings) -> Vector{Finding}
    expand_findings(report::SummaryReport) -> Vector{Finding}

Return the Findings with every roll-up replaced by the per-component Findings
it stands for, in component order. Findings that are not roll-ups pass through
unchanged, so the result has one Finding per affected component, exactly as the
analysis passes emitted them.

`analyze` rolls up an INFO or WARNING code raised on more than
`config["report"]["rollup_threshold"]` components (default 25) into one Finding
whose `detail["components"]` lists them. Use this function when a workflow
needs the per-component records, for example to act on each flagged line.
"""
function expand_findings(findings::AbstractVector{Finding})::Vector{Finding}
    out = Finding[]
    for f in findings
        if !is_rolled_up(f)
            push!(out, f); continue
        end
        records = f.detail["by_component"]
        for id in f.detail["components"]
            r = records[id]
            push!(out, Finding(f.severity, f.code, f.section, f.component_type,
                id, r["message"], r["detail"]))
        end
    end
    out
end
expand_findings(report::SummaryReport) = expand_findings(report.findings)

function _consolidate_findings(findings::Vector{Finding}; config::AbstractDict=_DEFAULT_CONFIG)
    summary = Dict{String,Any}("subsumed" => Dict{String,Any}[],
                               "rolled_up" => Dict{String,Any}[])
    keep = trues(length(findings))

    # --- subsumption, per component ---
    for (weak, strong) in _SUBSUMED_BY
        covered = Set{String}()
        for f in findings
            f.code == strong && f.component_id !== nothing && push!(covered, f.component_id)
        end
        isempty(covered) && continue
        dropped = String[]
        for (k, f) in enumerate(findings)
            keep[k] && f.code == weak && f.component_id !== nothing &&
                f.component_id in covered || continue
            keep[k] = false; push!(dropped, f.component_id)
        end
        isempty(dropped) || push!(summary["subsumed"], Dict{String,Any}(
            "code" => weak, "by" => strong, "n" => length(dropped),
            "components" => sort!(dropped)))
    end

    # --- subsumption, network-level aggregates over the same components ---
    for (weak, strong, weak_count, strong_list) in _SUBSUMED_AGGREGATE
        ks = findfirst(f -> f.code == strong, findings)
        kw = findfirst(f -> f.code == weak, findings)
        (ks === nothing || kw === nothing) && continue
        ds = findings[ks].detail; dw = findings[kw].detail
        ds isa AbstractDict && dw isa AbstractDict || continue
        listed = get(ds, strong_list, nothing); n = get(dw, weak_count, nothing)
        listed isa AbstractVector && n isa Integer && length(listed) == n || continue
        keep[kw] = false
        push!(summary["subsumed"], Dict{String,Any}("code" => weak, "by" => strong, "n" => n))
    end

    # --- roll-up ---
    threshold = _rollup_threshold(config)
    members = Dict{String,Vector{Int}}()
    if threshold > 0
        for (k, f) in enumerate(findings)
            keep[k] && f.severity != ERROR && f.component_id !== nothing || continue
            push!(get!(members, f.code, Int[]), k)
        end
    end
    replacement = Dict{Int,Finding}()
    for (code, idx) in members
        length(idx) > threshold || continue
        # One component may raise a code more than once; a roll-up keyed by
        # component cannot restore that, so such a code is left untouched.
        ids = [findings[k].component_id for k in idx]
        allunique(ids) || continue
        first_f = findings[idx[1]]
        all(k -> findings[k].severity == first_f.severity &&
                 findings[k].section == first_f.section &&
                 findings[k].component_type == first_f.component_type, idx) || continue
        order = sortperm(ids)
        sorted_ids = ids[order]
        by_component = Dict{String,Any}(findings[k].component_id => Dict{String,Any}(
            "message" => findings[k].message, "detail" => findings[k].detail) for k in idx)
        example = findings[idx[order[1]]]
        n = length(idx)
        shown = join(sorted_ids[1:min(5, n)], ", ")
        message = "$n $(first_f.component_type) components raise $code " *
            "($shown$(n > 5 ? ", …" : "")). Example — $(example.message)"
        replacement[idx[1]] = Finding(first_f.severity, code, first_f.section,
            first_f.component_type, nothing, message, Dict{String,Any}(
                _ROLLUP_DETAIL_KEY => true, "count" => n,
                "components" => sorted_ids, "by_component" => by_component))
        for k in idx[2:end]; keep[k] = false; end
        push!(summary["rolled_up"], Dict{String,Any}("code" => code, "n" => n))
    end

    out = Finding[]
    for (k, f) in enumerate(findings)
        keep[k] || continue
        push!(out, get(replacement, k, f))
    end
    sort!(summary["rolled_up"], by = d -> d["code"])
    summary["rollup_threshold"] = threshold
    summary["n_findings_before"] = length(findings)
    summary["n_findings_after"] = length(out)
    out, summary
end
