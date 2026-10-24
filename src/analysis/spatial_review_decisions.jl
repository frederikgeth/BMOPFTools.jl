const _SPATIAL_DECISION_KEYS = ("schema_version", "item_id", "case_fingerprint", "analysis_fingerprint",
    "evidence_fingerprint", "disposition", "reviewer", "recorded_at", "rationale", "evidence_refs")
function _spatial_decision_errors(record)
    record isa AbstractDict || return ["record_not_object"]
    issues = String[]
    Set(string.(keys(record))) == Set(_SPATIAL_DECISION_KEYS) || push!(issues, "unexpected_or_missing_fields")
    get(record, "schema_version", nothing) == _SPATIAL_REVIEW_VERSION || push!(issues, "unsupported_schema")
    for key in ("item_id", "reviewer", "rationale", "recorded_at")
        v = get(record, key, nothing)
        v isa AbstractString && !isempty(strip(v)) || push!(issues, "invalid_$key")
    end
    for key in ("case_fingerprint", "analysis_fingerprint", "evidence_fingerprint")
        v = get(record, key, nothing)
        v isa AbstractString && occursin(r"^[0-9a-f]{64}$", v) || push!(issues, "invalid_$key")
    end
    get(record, "disposition", nothing) in _SPATIAL_DISPOSITIONS || push!(issues, "invalid_disposition")
    refs = get(record, "evidence_refs", nothing)
    refs isa AbstractVector && all(r -> r isa AbstractString && !isempty(strip(r)), refs) || push!(issues, "invalid_evidence_refs")
    timestamp = get(record, "recorded_at", nothing)
    valid_time = timestamp isa AbstractString && occursin(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", timestamp)
    if valid_time
        valid_time = try
            DateTime(timestamp[1:end-1], dateformat"yyyy-mm-ddTHH:MM:SS"); true
        catch
            false
        end
    end
    valid_time || push!(issues, "invalid_utc_timestamp")
    sort!(unique(issues))
end

"""
    spatial_review_decision(review, item_id; disposition, reviewer, recorded_at,
                            rationale, evidence_refs=String[])

Create an evidence-bound sidecar decision without changing the review or network.
`recorded_at` is an explicit UTC timestamp (`yyyy-mm-ddTHH:MM:SSZ`); no reviewer
identity or decision is inferred. `resolved` records a reviewer assertion only.
"""
function spatial_review_decision(review::AbstractDict, item_id::AbstractString;
        disposition::AbstractString, reviewer::AbstractString, recorded_at::AbstractString,
        rationale::AbstractString, evidence_refs::AbstractVector=String[])
    get(review, "schema_version", nothing) == _SPATIAL_REVIEW_VERSION || throw(ArgumentError("unsupported spatial review schema"))
    matches = filter(i -> i["item_id"] == item_id, review["items"])
    length(matches) == 1 || throw(ArgumentError("item_id must identify one captured review item"))
    item = only(matches)
    item["evidence_fingerprint"] == _spatial_review_item_fingerprint(item) || throw(ArgumentError("review item evidence was modified"))
    record = Dict{String,Any}("schema_version" => _SPATIAL_REVIEW_VERSION, "item_id" => item_id,
        "case_fingerprint" => review["case_fingerprint"], "analysis_fingerprint" => review["analysis_fingerprint"],
        "evidence_fingerprint" => item["evidence_fingerprint"], "disposition" => disposition,
        "reviewer" => reviewer, "recorded_at" => recorded_at, "rationale" => rationale,
        "evidence_refs" => deepcopy(evidence_refs))
    issues = _spatial_decision_errors(record)
    isempty(issues) || throw(ArgumentError("invalid review decision: $(join(issues, ", "))"))
    record
end

"""
    apply_spatial_review(review, decisions)

Return a copy with append-only sidecar decisions applied. Latest UTC timestamp
wins; contradictory simultaneous records, invalid records and stale bindings
leave the item unreviewed with an explicit review status. Orphan decisions are
retained without treating an absent/truncated candidate as resolved. Diagnostics,
geometry, ranking and the input network are unchanged.
"""
function apply_spatial_review(review::AbstractDict, decisions::AbstractVector)
    get(review, "schema_version", nothing) == _SPATIAL_REVIEW_VERSION || throw(ArgumentError("unsupported spatial review schema"))
    out = deepcopy(review)
    items = Dict(i["item_id"] => i for i in out["items"])
    grouped = Dict{String,Vector{Any}}()
    invalid = Dict{String,Any}[]; orphan = Any[]
    blocked = Set{String}()
    for record in decisions
        issues = _spatial_decision_errors(record)
        id = record isa AbstractDict ? get(record, "item_id", nothing) : nothing
        if !isempty(issues)
            push!(invalid, Dict("record" => deepcopy(record), "issues" => issues))
            id isa AbstractString && haskey(items, id) && push!(blocked, id)
        elseif !haskey(items, id)
            push!(orphan, deepcopy(record))
        else
            push!(get!(grouped, id, Any[]), record)
        end
    end
    for (id, item) in items
        # Always start from the complete supplied ledger; do not inherit a
        # disposition left by an earlier application with a different ledger.
        item["review"] = Dict{String,Any}("status" => "unreviewed", "disposition" => "unreviewed")
        if item["evidence_fingerprint"] != _spatial_review_item_fingerprint(item)
            item["review"]["status"] = "modified_evidence"
            continue
        end
        if id in blocked
            item["review"]["status"] = "invalid_record"
            continue
        end
        records = get(grouped, id, Any[])
        isempty(records) && continue
        latest = maximum(r["recorded_at"] for r in records)
        newest = filter(r -> r["recorded_at"] == latest, records)
        unique_records = Dict(_spatial_review_hash(r) => r for r in newest)
        if length(unique_records) != 1
            item["review"]["status"] = "conflicting_decisions"
            continue
        end
        record = only(values(unique_records))
        item["review"]["decision"] = deepcopy(record)
        bindings = ("case_fingerprint", "analysis_fingerprint")
        current = all(k -> record[k] == out[k], bindings) && record["evidence_fingerprint"] == item["evidence_fingerprint"]
        if !current
            item["review"]["status"] = "stale_decision"
            continue
        end
        item["review"]["status"] = "recorded"
        item["review"]["disposition"] = record["disposition"]
    end
    out["decision_audit"] = Dict{String,Any}("records" => deepcopy(decisions),
        "invalid_records" => invalid, "unmatched_records" => orphan,
        "n_invalid_records" => length(invalid), "n_unmatched_records" => length(orphan),
        "policy" => "Latest UTC timestamp, strict case/config/evidence binding; ties conflict. Unmatched does not mean resolved.")
    _spatial_review_groups!(out)
end
