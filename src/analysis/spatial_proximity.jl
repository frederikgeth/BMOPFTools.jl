# Radius queries over unique locations. Geographic candidates use 3D sphere
# coordinates, then the existing spherical geodesic for the final decision;
# this avoids longitude seams, polar special cases and a projection dependency.
function _proximity_location(point, kind)
    kind == "cartesian" && return point
    lon, lat = point
    # Equivalent geographic positions, distinct from raw field equality.
    (abs(lat) == 90 ? 0.0 : lon == 180 ? -180.0 : lon, lat)
end

function _proximity_index_point(point, kind)
    kind == "cartesian" && return (point[1], point[2], 0.0)
    lon, lat = deg2rad.(point)
    r = 6_371_008.8
    (r * cos(lat) * cos(lon), r * cos(lat) * sin(lon), r * sin(lat))
end

function _spatial_proximity(net, coordinates, frame, level_by_bus, config)
    options = get(config, "spatial", Dict())
    options isa AbstractDict || (options = Dict("proximity_enabled" => nothing))
    enabled = get(options, "proximity_enabled", true)
    radius = _spatial_length(get(options, "proximity_radius_m", 1.0))
    limit = get(options, "max_candidate_pairs", 1_000_000)
    witnesses_limit = get(options, "witness_limit", 20)
    valid_int(x) = x isa Integer && !(x isa Bool) && 1 <= x <= typemax(Int)
    valid = enabled isa Bool && radius !== nothing && radius > 0 && valid_int(limit) && valid_int(witnesses_limit)
    report = Dict{String,Any}("status" => "indeterminate", "reason" => "invalid_configuration",
        "radius_m" => radius, "n_eligible_buses" => length(coordinates.points),
        "n_near_bus_pairs" => nothing, "n_near_bus_pairs_observed" => 0,
        "n_zero_distance_bus_pairs" => nothing, "n_clusters" => nothing,
        "n_observed_components" => 0, "candidate_pairs_checked" => 0,
        "counts_complete" => false, "pair_witnesses" => Dict{String,Any}[],
        "cluster_witnesses" => Dict{String,Any}[], "metric_kind" => frame.kind,
        "linkage" => "single_linkage",
        "caution" => "Proximity does not establish electrical connectivity or duplicate assets. A cluster is a chain of radius links; its diameter can exceed the radius. Reported accuracy does not change the search radius or certify an error bound.")
    valid || return report
    report["max_candidate_pairs"] = limit
    report["witness_limit"] = witnesses_limit
    if !enabled
        report["status"] = "inapplicable"
        report["reason"] = "disabled"
        return report
    end
    if isempty(coordinates.points)
        report["status"] = frame.status == "declared_other" ? "inapplicable" : "indeterminate"
        report["reason"] = "no_eligible_coordinates"
        return report
    end
    positions = Dict{Tuple{Float64,Float64},Vector{String}}()
    for (id, point) in coordinates.points
        push!(get!(positions, _proximity_location(point, frame.kind), String[]), id)
    end
    locations = sort!([(point=p, buses=sort!(ids)) for (p, ids) in positions], by=l -> first(l.buses))
    n = length(locations)
    index_points = [_proximity_index_point(l.point, frame.kind) for l in locations]
    # Pad candidate cells for floating-point coordinate/trigonometric rounding.
    # The final distance predicate still uses the exact configured radius.
    magnitude = maximum(maximum(abs, p) for p in index_points)
    cell_width = radius + 16 * eps(magnitude)
    parent = collect(1:n)
    ranks = zeros(Int, n)
    function root(i)
        while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        i
    end
    function unite(i, j)
        a, b = root(i), root(j)
        a == b && return
        if ranks[a] < ranks[b]
            parent[a] = b
        else
            parent[b] = a
            ranks[a] == ranks[b] && (ranks[a] += 1)
        end
    end
    bus_evidence(id) = merge(Dict{String,Any}("bus_id" => id,
        "voltage_tier" => get(level_by_bus, id, "unassigned")), coordinates.evidence[id])
    buckets = Dict{NTuple{3,Int},Vector{Int}}()
    checked = 0
    near_pairs = 0
    zero_pairs = sum(length(l.buses) * (length(l.buses) - 1) ÷ 2 for l in locations)
    skipped = 0
    indexed = 0
    pair_witnesses = Dict{String,Any}[]
    function scan!()
        for (i, location) in enumerate(locations)
            position = index_points[i]
            scaled = position ./ radius
            # Keep integer-cell arithmetic exact, and report out-of-domain
            # numerical ranges rather than silently dropping locations.
            if !isfinite(cell_width) || !all(x -> isfinite(x) && abs(x) < 2.0^50, scaled)
                skipped += 1
                continue
            end
            cell = floor.(Int, position ./ cell_width)
            for dx in -1:1, dy in -1:1, dz in -1:1
                nearby = get(buckets, (cell[1]+dx, cell[2]+dy, cell[3]+dz), nothing)
                nearby === nothing && continue
                for j in nearby
                    checked >= limit && return false
                    checked += 1
                    other = locations[j]
                    distance = _coordinate_distance(location.point, other.point, frame.kind)
                    distance === nothing && continue
                    distance <= radius || continue
                    multiplicity = length(location.buses) * length(other.buses)
                    if distance == 0
                        zero_pairs += multiplicity
                        continue
                    end
                    near_pairs += multiplicity
                    unite(i, j)
                    length(pair_witnesses) >= witnesses_limit && continue
                    a, b = first(location.buses), first(other.buses)
                    accuracy_a = coordinates.evidence[a]["coordinate_accuracy_m"]
                    accuracy_b = coordinates.evidence[b]["coordinate_accuracy_m"]
                    accuracy_sum = accuracy_a === nothing || accuracy_b === nothing ? nothing : accuracy_a + accuracy_b
                    accuracy_sum !== nothing && !isfinite(accuracy_sum) && (accuracy_sum = nothing)
                    push!(pair_witnesses, Dict{String,Any}(
                        "representative_bus_pair" => [bus_evidence(a), bus_evidence(b)],
                        "distance_m" => distance, "n_bus_pairs_at_these_locations" => multiplicity,
                        "reported_accuracy_sum_m" => accuracy_sum,
                        "accuracy_context" => accuracy_sum === nothing ? "accuracy_unreported" :
                            distance <= accuracy_sum ? "within_reported_accuracy" : "beyond_reported_accuracy"))
                end
            end
            push!(get!(buckets, cell, Int[]), i)
            indexed += 1
        end
        true
    end
    exhausted = !scan!()
    complete = !exhausted && skipped == 0
    components = Dict{Int,Vector{Int}}()
    for i in 1:n
        push!(get!(components, root(i), Int[]), i)
    end
    filter!(kv -> length(last(kv)) > 1, components)
    groups = sort!(collect(values(components)), by=g -> minimum(first(locations[i].buses) for i in g))
    cluster_witnesses = Dict{String,Any}[]
    for group in Iterators.take(groups, witnesses_limit)
        buses = sort!(reduce(vcat, (locations[i].buses for i in group)))
        push!(cluster_witnesses, Dict{String,Any}("anchor_bus" => first(buses),
            "n_buses" => length(buses), "n_unique_locations" => length(group),
            "members" => [bus_evidence(id) for id in Iterators.take(buses, witnesses_limit)],
            "members_truncated" => length(buses) > witnesses_limit,
            "complete" => complete))
    end
    merge!(report, Dict{String,Any}("status" => complete ? "assessed" : "indeterminate",
        "reason" => exhausted ? "candidate_budget_exhausted" : skipped > 0 ? "index_numeric_range" : "completed",
        "counts_complete" => complete, "candidate_pairs_checked" => checked,
        "n_unique_locations" => n, "n_indexed_locations" => indexed,
        "n_index_range_exclusions" => skipped,
        "n_near_bus_pairs" => complete ? near_pairs : nothing,
        "n_near_bus_pairs_observed" => near_pairs,
        "n_zero_distance_bus_pairs" => complete ? zero_pairs : nothing,
        "n_clusters" => complete ? length(groups) : nothing,
        "n_observed_components" => length(groups),
        "pair_witnesses" => pair_witnesses, "cluster_witnesses" => cluster_witnesses))
    report
end
