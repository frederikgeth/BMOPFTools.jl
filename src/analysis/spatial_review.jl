# A package-local review workflow. Priorities order inspection, not probability
# of error; ledger decisions never modify networks or suppress diagnostics.
const _SPATIAL_REVIEW_VERSION = "spatial-cleanup-review/v1"
const _SPATIAL_REVIEW_POLICY = "spatial-review-priority/v2"
const _SPATIAL_QUALITY_CATEGORIES = ("context_only", "needs_information", "review_candidate", "data_inconsistency")
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
        w["voltage_tier_relation"] == "unknown" &&
            return (2, "voltage_context_unavailable", "needs_information")
        w["component_relation"] == "separate_bus_components" && w["voltage_tier_relation"] == "same" &&
            return (2, "nearby_separate_components_same_tier", "topology_candidate")
        w["component_relation"] in ("unknown_switch_state", "indeterminate_graph") &&
            return (2, "topology_evidence_incomplete", "needs_information")
        w["voltage_tier_relation"] == "different" &&
            return (1, "different_voltage_systems_share_location", "representation_context")
        return (1, "proximity_without_connectivity_claim", "representation_context")
    elseif code == "S.DIRECT_ALONGSIDE_SERIES_PATH"
        return (2, "direct_and_series_declarations", "topology_candidate")
    elseif code in ("S.SHARED_ROUTE_SEGMENT", "S.REPEATED_SOURCE_INTERVAL")
        relation = get(get(w, "voltage_context", Dict()), "relation", "unknown")
        relation == "crossing_endpoint_tiers" && return (2, "line_endpoints_cross_voltage_tiers", "topology_candidate")
        relation == "different" && return (1, "different_voltage_systems_share_route", "representation_context")
        get(w, "declared_arrangement", "") == "series_chain" && return (1, "shared_representation_in_series_chain", "representation_context")
        get(w, "terminal_map_relation", "") == "different_declared_maps" && return (1, "distinct_terminal_maps", "representation_context")
        relation == "unknown" && return (2, "voltage_context_unavailable", "needs_information")
        code == "S.SHARED_ROUTE_SEGMENT" && return (1, "shared_route_without_conflicting_evidence", "representation_context")
        return (2, "repeated_source_identity_requires_review", "topology_candidate")
    elseif code == "S.ROUTE_SEGMENT_DEFECT" && w["n_zero_segments"] + w["n_repeated_segments"] > 0
        return (2, "degenerate_or_retraced_segments", "geometric_discrepancy")
    end
    (1, "absolute_span_review_threshold", "representation_context")
end

# These categories describe evidence, not defect probability or electrical severity.
# Reviewer confirmation is a separate disposition and is never inferred here.
function _spatial_review_assessment(w, rule, evidence_class)
    category = evidence_class == "representation_context" ? "context_only" :
        evidence_class == "needs_information" ? "needs_information" :
        evidence_class == "declaration_inconsistency" || w["code"] == "S.ROUTE_ENDPOINT_DISAGREEMENT" ?
            "data_inconsistency" : "review_candidate"
    explanations = Dict(
        "different_voltage_systems_share_location" => ("Different voltage systems occupy nearby locations.",
            "Compatible with MV/LV sharing infrastructure; proximity does not require an electrical connection.",
            "Shared poles are not verified by coordinates or voltage labels.",
            "No correction is indicated by proximity alone."),
        "different_voltage_systems_share_route" => ("Lines in different voltage systems share spatial or source representation.",
            "Compatible with shared infrastructure; each line has matching endpoint voltage labels.",
            "Shared poles and independent circuit identities are not verified.",
            "No correction is indicated by overlap alone; retain any separate endpoint or length discrepancy."),
        "shared_route_without_conflicting_evidence" => ("Lines share an exact route segment.",
            "Same-voltage circuits and legitimate parallel lines can share a route. Overlap alone is contextual.",
            "Neither independent circuits nor duplicate electrical assets are established.",
            "No correction is indicated by overlap alone."),
        "shared_representation_in_series_chain" => ("Lines share representation and form a declared series chain.",
            "Segmentation or inherited source geometry can explain this representation.",
            "The source segmentation and physical routing have not been independently verified.",
            "Compare source segmentation if a separate discrepancy requires review."),
        "distinct_terminal_maps" => ("Lines share representation but have different declared terminal maps.",
            "The declarations distinguish conductor participation; shared geometry does not establish duplication.",
            "Terminal maps alone do not verify independent physical circuits.",
            "Retain the map differences when reviewing any separate discrepancy."),
        "proximity_without_connectivity_claim" => ("Nearby buses have no direct branch between them.",
            "They belong to the same declared bus component; proximity alone does not require another connection.",
            "Bus-level connectivity does not establish conductor continuity or shared poles.",
            "No connection or bus merge is indicated by proximity alone."),
        "voltage_context_unavailable" => ("Nearby buses or shared line representation lack complete voltage context.",
            "The available labels cannot distinguish voltage systems reliably.",
            "Missing voltage labels are not evidence of duplication or a missing connection.",
            "Inspect source voltage declarations and voltage propagation results."),
        "topology_evidence_incomplete" => ("Nearby buses have incomplete connectivity evidence.",
            "Unknown switch state or invalid graph declarations prevent a definite component comparison.",
            "Proximity does not resolve the electrical state.",
            "Check switch states and invalid branch references before assessing connectivity."),
        "nearby_separate_components_same_tier" => ("Nearby same-tier buses are in separate declared bus components.",
            "Separation plus proximity warrants inspection, but intentional boundaries remain possible.",
            "The bus graph does not establish a missing conductor connection.",
            "Compare source connection records and intentional isolation boundaries."),
        "line_endpoints_cross_voltage_tiers" => ("At least one grouped line has different endpoint voltage labels.",
            "This separate declaration concern must not be hidden by shared-route context.",
            "Voltage propagation or connection declarations may be responsible; geometry cannot decide which.",
            "Check endpoint bus references, source voltage declarations and transformer boundaries."),
        "repeated_source_identity_requires_review" => ("Multiple lines use the same explicit source interval identity.",
            "The identity reuse needs interpretation beyond simple geometric overlap.",
            "A source interval may intentionally cover several circuits; duplication is not established.",
            "Compare source interval ownership, circuit identifiers and segmentation."),
        "direct_and_series_declarations" => ("A direct line lies alongside a bounded series path in endpoint geometry.",
            "The model contains both declarations, which may represent legitimate parallel paths.",
            "Chord alignment does not establish physical routes or electrical equivalence.",
            "Compare circuit identifiers and source segmentation; retain attachments on intermediate buses."),
        "route_and_bus_coordinates_disagree" => ("A supported route endpoint disagrees with its connected bus location beyond the configured tolerance.",
            "The spatial declarations disagree; this does not identify which declaration is wrong.",
            "Survey accuracy, displaced coordinates or stale routes may explain the discrepancy.",
            "Compare route and bus coordinate provenance and accuracy before editing either."),
        "invalid_geometry" => ("A route geometry declaration is invalid for the supported geometry check.",
            "The route cannot be used as declared.",
            "This identifies a data declaration problem, not its electrical consequences.",
            "Inspect the route declaration and the recorded validation reason."),
        "invalid_or_inconsistent_length" => ("A length declaration is invalid or below its applicable endpoint bound.",
            "The declared values conflict with supported length semantics or geometry.",
            "The responsible field is unresolved; accuracy and provenance still matter.",
            "Compare physical versus electrical length, units, coordinate accuracy and source records."),
        "length_declarations_disagree" => ("Length declarations disagree under the configured comparisons.",
            "Physical, electrical or stored route lengths may describe different source representations.",
            "A disagreement does not establish which length should be changed.",
            "Check inherited parent lengths, segment lengths, units and source provenance."),
        "regularized_length_requires_interpretation" => ("Length context includes an explicitly regularized electrical length.",
            "Electrical regularization can intentionally differ from physical distance.",
            "Geometry does not determine the intended electrical parameterization.",
            "Compare regularization provenance before changing electrical length."),
        "degenerate_or_retraced_segments" => ("A route contains zero-length or repeated segments.",
            "Repeated vertices or retracing may reflect export artifacts or intentional routing.",
            "A geometric pattern alone does not establish an electrical error.",
            "Inspect the recorded segment indices against the source route."),
        "absolute_span_review_threshold" => ("A span exceeds the configured absolute review threshold.",
            "The threshold provides context; it is not an engineering limit.",
            "A long span alone is not evidence of incorrect length or connectivity.",
            "Compare geographic extent and source routing if unexpected for this case."))
    observed, explanation, uncertainty, inspect = explanations[rule]
    voltage = if haskey(w, "voltage_context")
        deepcopy(w["voltage_context"])
    elseif haskey(w, "voltage_tier_relation")
        Dict("relation" => w["voltage_tier_relation"], "basis" => "source_propagated_bus_voltage_labels",
            "buses" => [Dict("bus_id"=>b["bus_id"], "voltage_tier"=>b["voltage_tier"]) for b in w["buses"]])
    else
        nothing
    end
    Dict{String,Any}("category" => category, "observation" => observed,
        "explanation" => explanation, "uncertainty" => uncertainty, "inspect" => inspect,
        "voltage_context" => voltage, "error_probability" => nothing)
end

_spatial_review_category(item) = get(get(item, "assessment", Dict()), "category", "review_candidate")
function _spatial_review_bucket(item)
    disposition = item["review"]["disposition"]
    disposition in ("accepted_modeling", "resolved") && return "reviewed"
    disposition in ("confirmed_issue", "needs_information", "deferred") && return "attention"
    _spatial_review_category(item) == "context_only" ? "context" : "attention"
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
                "category_counts" => Dict(c => 0 for c in _SPATIAL_QUALITY_CATEGORIES),
                "disposition_counts" => Dict{String,Int}(), "bus_ids" => Set{String}(),
                "component_refs" => Set{Tuple{String,String}}(), "evidence_classes" => Set{String}(),
                "max_item_directly_attached_loads" => 0)
        end
        push!(group["item_ids"], item["item_id"]); push!(group["codes"], item["code"])
        union!(group["bus_ids"], item["bus_ids"])
        union!(group["component_refs"], ((c["kind"], c["id"]) for c in item["components"]))
        push!(group["evidence_classes"], item["evidence_class"])
        group["category_counts"][_spatial_review_category(item)] += 1
        group["max_item_directly_attached_loads"] = max(group["max_item_directly_attached_loads"], item["impact"]["n_directly_attached_loads"])
        group["priority"] = max(group["priority"], item["priority"])
        state = item["review"]["disposition"]
        group["disposition_counts"][state] = get(group["disposition_counts"], state, 0) + 1
    end
    for group in values(groups)
        sort!(group["item_ids"]); group["codes"] = sort!(unique(group["codes"]))
        group["bus_ids"] = sort!(collect(group["bus_ids"]))
        group["components"] = [Dict("kind"=>k,"id"=>id) for (k,id) in sort!(collect(group["component_refs"]))]
        delete!(group, "component_refs")
        group["evidence_classes"] = sort!(collect(group["evidence_classes"]))
        group["n_identified_buses"] = length(group["bus_ids"])
        group["n_identified_components"] = length(group["components"])
    end
    review["locations"] = sort!(collect(values(groups)), by=g -> (-g["priority"], -g["max_item_directly_attached_loads"], -g["n_identified_components"], g["location_id"]))
    counts = Dict(s => 0 for s in _SPATIAL_DISPOSITIONS)
    for item in review["items"]; counts[item["review"]["disposition"]] += 1; end
    review["disposition_counts"] = counts
    review["category_counts"] = Dict(c => count(i -> _spatial_review_category(i) == c, review["items"]) for c in _SPATIAL_QUALITY_CATEGORIES)
    review["presentation_counts"] = Dict(b => count(i -> _spatial_review_bucket(i) == b, review["items"]) for b in ("attention", "context", "reviewed"))
    review["count_scope"] = "Captured observations only; context is not an issue count. Categories describe automated evidence; confirmation requires a separate reviewer disposition."
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
        "coordinate_context" => merge(_jsonable(coordinates.report), Dict("n_buses" => length(get(net, "bus", Dict())))),
        "analysis_settings" => _jsonable(get(config, "spatial", Dict())),
        "scope" => "M3 discrepancy candidates and non-regularization-only M1 length contexts; coordinate and coincidence inventories remain in the spatial report.",
        "ranking_policy" => _SPATIAL_REVIEW_POLICY,
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
    result["analysis_fingerprint"] = _spatial_review_hash([_SPATIAL_REVIEW_VERSION, _SPATIAL_REVIEW_POLICY, get(config, "spatial", Dict())])
    captures = Tuple{String,Dict{String,Any}}[]
    for (name, check) in sort!(collect(checks), by=first)
        rows = get(check, "_review_candidates", Dict{String,Any}[])
        observed = check["n_candidates_observed"]
        captured = length(rows)
        result["coverage"][name] = Dict("status" => check["status"], "reason" => check["reason"],
            "n_observed" => observed, "n_captured" => captured,
            "scan_complete" => check["counts_complete"], "capture_complete" => captured == observed,
            "scope" => check["scope"], "domain_counts" => Dict(k => v for (k,v) in check if startswith(k, "n_") && k != "n_candidates_observed" && k != "n_candidates"))
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
            "assessment" => _spatial_review_assessment(w, rule, evidence_class),
            "coordinate_evidence" => Dict(b => deepcopy(coordinates.evidence[b]) for b in sort!(collect(subjects.buses)) if haskey(coordinates.evidence, b)),
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
        properties = Dict(k => deepcopy(item[k]) for k in ("code", "location_id", "priority", "ranking_reason", "impact", "bus_ids", "components", "review", "geometry_basis", "geometry_coverage", "evidence_fingerprint"))
        for key in ("assessment", "coordinate_evidence")
            haskey(item, key) && (properties[key] = deepcopy(item[key]))
        end
        properties["case_fingerprint"] = review["case_fingerprint"]
        properties["analysis_fingerprint"] = review["analysis_fingerprint"]
        push!(features, Dict("type" => "Feature", "id" => item["item_id"],
            "geometry" => deepcopy(item["geometry"]), "properties" => properties))
    end
    Dict{String,Any}("type" => "FeatureCollection", "features" => features,
        "review_schema_version" => _SPATIAL_REVIEW_VERSION, "queue_complete" => review["queue_complete"],
        "scope" => review["scope"], "coordinate_context" => deepcopy(review["coordinate_context"]),
        "n_items_without_wgs84_geometry" => length(review["items"]) - length(features))
end

function _spatial_review_item_fingerprint(item)
    payload = Dict(k => item[k] for k in ("item_id", "code", "check", "evidence", "location_id", "location", "geometry",
        "local_geometry", "geometry_basis", "geometry_coverage", "impact", "priority", "ranking_reason", "evidence_class", "bus_ids", "components"))
    for key in ("assessment", "coordinate_evidence")
        haskey(item, key) && (payload[key] = item[key])
    end
    _spatial_review_hash(payload)
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
