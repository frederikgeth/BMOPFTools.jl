# A package-local review workflow. Priorities order inspection, not probability
# of error; ledger decisions never modify networks or suppress diagnostics.
const _SPATIAL_REVIEW_VERSION = "spatial-cleanup-review/v1"
const _SPATIAL_DISPOSITIONS = ("unreviewed", "needs_information", "confirmed_issue", "accepted_modeling", "deferred", "resolved")

function _spatial_review_canonical(io, x)
    if x isa AbstractDict
        print(io, '{')
        for (i, k) in enumerate(sort!(collect(keys(x)), by=string))
            i > 1 && print(io, ',')
            JSON3.write(io, string(k)); print(io, ':'); _spatial_review_canonical(io, x[k])
        end
        print(io, '}')
    elseif x isa AbstractVector || x isa Tuple
        print(io, '[')
        for (i, v) in enumerate(x)
            i > 1 && print(io, ',')
            _spatial_review_canonical(io, v)
        end
        print(io, ']')
    elseif x isa AbstractFloat && !isfinite(x)
        # Non-JSON token in hash input only; distinguish malformed values from null.
        print(io, "nonfinite:", repr(x))
    elseif x isa AbstractFloat && isinteger(x)
        # JSON readers may turn 1.0 into 1. Bind numerical value, not spelling.
        print(io, BigInt(x))
    else
        JSON3.write(io, _jsonable(x))
    end
end
function _spatial_review_hash(x)
    io = IOBuffer(); _spatial_review_canonical(io, x)
    bytes2hex(SHA.sha256(take!(io)))
end
function _spatial_review_options(config)
    o = get(config, "spatial", Dict())
    o isa AbstractDict || return (valid=false, enabled=false, limit=0)
    enabled = get(o, "review_enabled", true)
    limit = get(o, "max_review_candidates", 5000)
    valid = enabled isa Bool && limit isa Integer && !(limit isa Bool) && 1 <= limit <= 100_000
    (valid=valid, enabled=enabled === true, limit=valid ? Int(limit) : 0)
end
_spatial_review_room(check) = length(get(check, "_review_candidates", [])) < get(check, "_review_limit", 0)

function _spatial_review_subjects(w)
    buses = Set{String}(); components = Set{Tuple{String,String}}()
    addbus(b) = b isa AbstractString && push!(buses, b)
    function addbranch(c)
        push!(components, (c["kind"], c["component_id"]))
        for p in c["ports"]; addbus(p["bus"]); end
    end
    code = w["code"]
    if code == "S.NEARBY_WITHOUT_DIRECT_BRANCH"
        foreach(b -> addbus(b["bus_id"]), w["buses"])
    elseif code == "S.DIRECT_ALONGSIDE_SERIES_PATH"
        addbranch(w["direct_branch"]); foreach(addbranch, w["series_branches"])
    elseif code == "S.LONG_BRANCH_SPAN"
        addbranch(w["branch"])
    elseif haskey(w, "lines")
        for l in w["lines"]
            push!(components, ("line", l["line_id"]))
            addbus(l["bus_from"]); addbus(l["bus_to"])
        end
    elseif haskey(w, "line_id")
        push!(components, ("line", w["line_id"]))
        addbus(get(w, "bus_from", nothing)); addbus(get(w, "bus_to", nothing))
    end
    (buses=buses, components=components)
end

function _spatial_review_identity(w, subjects)
    code = w["code"]
    if code == "S.SHARED_ROUTE_SEGMENT"
        return [code, w["segment_lonlat"], w["line_ids_digest"]]
    elseif code == "S.REPEATED_SOURCE_INTERVAL"
        return [code, w["namespace"], w["source_interval"]]
    end
    [code, sort!(collect(subjects.components)), code == "S.NEARBY_WITHOUT_DIRECT_BRANCH" ? sort!(collect(subjects.buses)) : nothing]
end

function _spatial_review_priority(w)
    code = w["code"]
    if code == "S.INVALID_ROUTE_GEOMETRY"
        return (3, "invalid_geometry", "declaration_inconsistency")
    elseif code == "R.LINE_LENGTH_CONTEXT"
        tags = w["contexts"]
        any(t -> t in ("invalid_length_declaration", "invalid_route_length", "shorter_than_chord"), tags) &&
            return (3, "invalid_or_inconsistent_length", "declaration_inconsistency")
        w["electrical_length_regularized"] === true && return (1, "regularized_length_requires_interpretation", "representation_context")
        return (2, "length_declarations_disagree", "declaration_inconsistency")
    elseif code == "S.ROUTE_ENDPOINT_DISAGREEMENT"
        return (3, "route_and_bus_coordinates_disagree", "geometric_discrepancy")
    elseif code == "S.NEARBY_WITHOUT_DIRECT_BRANCH"
        w["component_relation"] == "separate_bus_components" && w["voltage_tier_relation"] == "same" &&
            return (2, "nearby_separate_components_same_tier", "topology_candidate")
        w["component_relation"] in ("unknown_switch_state", "indeterminate_graph") &&
            return (2, "topology_evidence_incomplete", "needs_information")
        return (1, "proximity_without_connectivity_claim", "representation_context")
    elseif code == "S.DIRECT_ALONGSIDE_SERIES_PATH"
        return (2, "direct_and_series_declarations", "topology_candidate")
    elseif code in ("S.SHARED_ROUTE_SEGMENT", "S.REPEATED_SOURCE_INTERVAL")
        get(w, "declared_arrangement", "") == "series_chain" && return (1, "shared_representation_in_series_chain", "representation_context")
        get(w, "terminal_map_relation", "") == "different_declared_maps" && return (1, "distinct_terminal_maps", "representation_context")
        return (2, "shared_representation_requires_review", "representation_context")
    elseif code == "S.ROUTE_SEGMENT_DEFECT" && w["n_zero_segments"] + w["n_repeated_segments"] > 0
        return (2, "degenerate_or_retraced_segments", "geometric_discrepancy")
    end
    (1, "absolute_span_review_threshold", "representation_context")
end

function _spatial_review_geometry(w, subjects, coordinates, frame)
    # Points only in GeoJSON: avoids inventing a physical route from bus chords,
    # including misleading line segments drawn through the antimeridian.
    if haskey(w, "segment_lonlat")
        ps = sort!(unique([Tuple(p) for p in w["segment_lonlat"]]))
        return (kind="wgs84", frame="WGS84", points=ps, basis="explicit_route_segment_vertices")
    elseif w["code"] == "S.ROUTE_ENDPOINT_DISAGREEMENT"
        ps = sort!(unique([Tuple(e["route_endpoint_lonlat"]) for e in w["endpoints"]]))
        return (kind="wgs84", frame="WGS84", points=ps, basis="disagreeing_route_endpoints")
    end
    ps = sort!(unique([_proximity_location(coordinates.points[b], frame.kind) for b in subjects.buses if haskey(coordinates.points, b)]))
    (kind=frame.kind, frame=frame.token, points=ps, basis="eligible_referenced_bus_locations")
end

function _spatial_review_groups!(review)
    groups = Dict{String,Any}()
    for item in review["items"]
        key = item["location_id"]
        group = get!(groups, key) do
            Dict{String,Any}("location_id" => key, "location" => item["location"],
                "item_ids" => String[], "codes" => String[], "priority" => 0,
                "disposition_counts" => Dict{String,Int}())
        end
        push!(group["item_ids"], item["item_id"]); push!(group["codes"], item["code"])
        group["priority"] = max(group["priority"], item["priority"])
        state = item["review"]["disposition"]
        group["disposition_counts"][state] = get(group["disposition_counts"], state, 0) + 1
    end
    for group in values(groups)
        sort!(group["item_ids"]); group["codes"] = sort!(unique(group["codes"]))
    end
    review["locations"] = sort!(collect(values(groups)), by=g -> (-g["priority"], g["location_id"]))
    counts = Dict(s => 0 for s in _SPATIAL_DISPOSITIONS)
    for item in review["items"]; counts[item["review"]["disposition"]] += 1; end
    review["disposition_counts"] = counts
    statuses = Dict{String,Int}()
    for item in review["items"]
        state = item["review"]["status"]
        statuses[state] = get(statuses, state, 0) + 1
    end
    review["review_status_counts"] = statuses
    review
end

function _spatial_cleanup_review(net, coordinates, frame, config, checks, length_rows)
    options = _spatial_review_options(config)
    result = Dict{String,Any}("schema_version" => _SPATIAL_REVIEW_VERSION,
        "status" => "indeterminate", "reason" => "invalid_configuration", "items" => Dict{String,Any}[],
        "locations" => Dict{String,Any}[], "coverage" => Dict{String,Any}(), "queue_complete" => false,
        "scope" => "M3 discrepancy candidates and non-regularization-only M1 length contexts; coordinate and coincidence inventories remain in the spatial report.",
        "ranking_policy" => "spatial-review-priority/v1",
        "ranking_scope" => "Captured candidates only. Ordinal priority, directly attached load count, identified component count, then stable item ID; not an error probability or electrical impact estimate.",
        "grouping_policy" => "Exact first sorted evidence location within a declared frame; missing geometry groups by primary asset identity. No snapping, bus merging or transitive proximity clustering.",
        "calibration" => "Supplied networks and labelled synthetic expectations; no human-adjudicated real-world precision or recall.",
        "caution" => "Reviewer dispositions are assertions with provenance, not validation or repairs. Resolved items remain visible. Unknown frames never become map coordinates.")
    options.valid || return result
    if !options.enabled
        result["status"] = "inapplicable"; result["reason"] = "disabled"
        return result
    end
    result["max_review_candidates"] = options.limit
    result["case_fingerprint"] = _spatial_review_case_hash(net)
    result["analysis_fingerprint"] = _spatial_review_hash([_SPATIAL_REVIEW_VERSION, get(config, "spatial", Dict())])
    captures = Tuple{String,Dict{String,Any}}[]
    for (name, check) in sort!(collect(checks), by=first)
        rows = get(check, "_review_candidates", Dict{String,Any}[])
        observed = check["n_candidates_observed"]
        captured = length(rows)
        result["coverage"][name] = Dict("status" => check["status"], "reason" => check["reason"],
            "n_observed" => observed, "n_captured" => captured,
            "scan_complete" => check["counts_complete"], "capture_complete" => captured == observed)
        append!(captures, [(name, w) for w in rows])
    end
    nlength = 0; captured_length = 0
    for row in length_rows
        any(t -> t != "regularized_electrical_length", row["contexts"]) || continue
        nlength += 1
        captured_length >= options.limit && continue
        push!(captures, ("length_context", merge(Dict{String,Any}("code" => "R.LINE_LENGTH_CONTEXT"), row)))
        captured_length += 1
    end
    result["coverage"]["length_context"] = Dict("status" => "assessed", "reason" => "completed",
        "n_observed" => nlength, "n_captured" => captured_length, "scan_complete" => true,
        "capture_complete" => captured_length == nlength)
    # Direct attachment counts only. No downstream attribution or power ranking.
    loads = Dict{String,Int}()
    for load in values(get(net, "load", Dict()))
        load isa AbstractDict || continue
        b = get(load, "bus", nothing); b isa AbstractString || continue
        loads[b] = get(loads, b, 0) + 1
    end
    for (check_name, w) in captures
        subjects = _spatial_review_subjects(w)
        # Recover line endpoints for route-only and length records, without a
        # nearest-neighbour assignment or source-to-target mapping.
        for (kind, id) in subjects.components
            kind == "line" || continue
            l = get(get(net, "line", Dict()), id, Dict())
            l isa AbstractDict || continue
            for side in ("from", "to")
                b = get(l, "bus_$side", nothing)
                b isa AbstractString && push!(subjects.buses, b)
            end
        end
        identity = _spatial_review_identity(w, subjects)
        item_id = "review-" * _spatial_review_hash(identity)
        geometry = _spatial_review_geometry(w, subjects, coordinates, frame)
        primary = isempty(subjects.components) ? ["bus", minimum(subjects.buses)] : collect(minimum(subjects.components))
        location = isempty(geometry.points) ? Dict{String,Any}("status" => "unavailable", "primary_asset" => primary) :
            Dict{String,Any}("status" => "located", "frame" => geometry.frame,
                "coordinate" => collect(first(geometry.points)), "units" => geometry.kind == "wgs84" ? "degrees" : "m")
        location_id = "location-" * _spatial_review_hash(location)
        priority, rule, evidence_class = _spatial_review_priority(w)
        impact = Dict{String,Any}("n_identified_buses" => length(subjects.buses),
            "n_identified_components" => length(subjects.components),
            "n_directly_attached_loads" => sum(get(loads, b, 0) for b in subjects.buses; init=0),
            "subjects_complete" => !get(w, "lines_truncated", false),
            "scope" => "Referenced subjects only; counts can be lower bounds when member evidence is truncated. No downstream or electrical severity estimate.")
        mapped = geometry.kind == "wgs84" && !isempty(geometry.points)
        geom = mapped ? Dict("type" => "MultiPoint", "coordinates" => [collect(p) for p in geometry.points]) : nothing
        local_geom = geometry.kind == "cartesian" && !isempty(geometry.points) ?
            Dict("frame" => geometry.frame, "units" => "m", "points" => [collect(p) for p in geometry.points]) : nothing
        geometry_coverage = Dict{String,Any}("n_identified_buses" => length(subjects.buses),
            "n_buses_with_eligible_coordinates" => count(b -> haskey(coordinates.points, b), subjects.buses),
            "n_evidence_points" => length(geometry.points),
            "all_identified_buses_located" => all(b -> haskey(coordinates.points, b), subjects.buses),
            "subject_list_complete" => impact["subjects_complete"])
        row = Dict{String,Any}("item_id" => item_id, "code" => w["code"], "check" => check_name,
            "priority" => priority, "ranking_reason" => rule, "evidence_class" => evidence_class,
            "impact" => impact, "bus_ids" => sort!(collect(subjects.buses)),
            "components" => [Dict("kind"=>k,"id"=>id) for (k,id) in sort!(collect(subjects.components))],
            "location_id" => location_id, "location" => location,
            "geometry" => geom, "local_geometry" => local_geom, "geometry_basis" => geometry.basis, "geometry_coverage" => geometry_coverage,
            "evidence" => _jsonable(w), "review" => Dict("status" => "unreviewed", "disposition" => "unreviewed"))
        row["evidence_fingerprint"] = _spatial_review_item_fingerprint(row)
        push!(result["items"], row)
    end
    sort!(result["items"], by=i -> (-i["priority"], -i["impact"]["n_directly_attached_loads"],
        -i["impact"]["n_identified_components"], i["item_id"]))
    n = length(result["items"])
    resize!(result["items"], min(n, options.limit))
    result["n_captured_before_queue_limit"] = n
    result["n_items"] = length(result["items"])
    result["queue_truncated"] = n > options.limit
    complete = n <= options.limit && all(c -> c["capture_complete"] &&
        (c["scan_complete"] || (c["status"] == "inapplicable" && c["reason"] != "disabled")), values(result["coverage"]))
    result["queue_complete"] = complete
    result["status"] = complete ? "assessed" : "indeterminate"
    result["reason"] = complete ? "completed_within_declared_scope" : "incomplete_scan_or_capture"
    _spatial_review_groups!(result)
end

"""
    spatial_review_geojson(review)

Return a FeatureCollection of captured review items with supported WGS84
locations. Features are evidence points, not reconstructed physical routes.
Cartesian and unlocated items are omitted with explicit omission counts.
"""
function spatial_review_geojson(review::AbstractDict)
    get(review, "schema_version", nothing) == _SPATIAL_REVIEW_VERSION || throw(ArgumentError("unsupported spatial review schema"))
    features = Dict{String,Any}[]
    for item in review["items"]
        item["geometry"] === nothing && continue
        properties = Dict(k => deepcopy(item[k]) for k in ("code", "location_id", "priority", "ranking_reason", "impact", "review", "geometry_basis", "geometry_coverage", "evidence_fingerprint"))
        properties["case_fingerprint"] = review["case_fingerprint"]
        properties["analysis_fingerprint"] = review["analysis_fingerprint"]
        push!(features, Dict("type" => "Feature", "id" => item["item_id"],
            "geometry" => deepcopy(item["geometry"]), "properties" => properties))
    end
    Dict{String,Any}("type" => "FeatureCollection", "features" => features,
        "review_schema_version" => _SPATIAL_REVIEW_VERSION, "queue_complete" => review["queue_complete"],
        "n_items_without_wgs84_geometry" => length(review["items"]) - length(features))
end

function _spatial_review_item_fingerprint(item)
    _spatial_review_hash(Dict(k => item[k] for k in ("item_id", "code", "check", "evidence", "location_id", "location", "geometry",
        "local_geometry", "geometry_basis", "geometry_coverage", "impact", "priority", "ranking_reason", "evidence_class", "bus_ids", "components")))
end

function _spatial_review_case_hash(net)
    # parse_bmopf stamps wall-clock ingestion time on each fresh load. This is
    # bookkeeping, not model evidence. All other provenance remains binding.
    payload = copy(net)
    if get(net, "_meta", nothing) isa AbstractDict
        metadata = copy(net["_meta"]); delete!(metadata, "parsed_at")
        if isempty(metadata)
            delete!(payload, "_meta")
        else
            payload["_meta"] = metadata
        end
    end
    if get(net, "meta", nothing) isa AbstractDict && get(net["meta"], "provenance", nothing) isa AbstractDict
        metadata = copy(net["meta"])
        provenance = copy(metadata["provenance"]); delete!(provenance, "parsed_at")
        if isempty(provenance)
            delete!(metadata, "provenance")
        else
            metadata["provenance"] = provenance
        end
        payload["meta"] = metadata
    end
    _spatial_review_hash(payload)
end
