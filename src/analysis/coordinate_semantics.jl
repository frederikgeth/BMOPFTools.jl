# Package-local coordinate declarations. No reprojection, axis guessing, or
# interpretation of a projected EPSG code as a local Euclidean frame.
const _SPATIAL_CRS_KEYS = ("coordinate_reference_system", "crs", "coordinate_system")

function _coordinate_declarations(record, keys)
    rows = Pair{String,Any}[]
    for (prefix, source) in (("", record), ("meta.", get(record, "meta", nothing)))
        source isa AbstractDict || continue
        for key in keys
            haskey(source, key) && push!(rows, "$prefix$key" => source[key])
        end
    end
    rows
end

function _coordinate_crs(value)
    if value isa AbstractDict
        kind = get(value, "type", nothing)
        if kind == "cartesian"
            name = get(value, "name", "network_local")
            name isa AbstractString && !isempty(strip(name)) || return nothing
            # Do not allow a projected identifier to masquerade as a local frame.
            any(k -> haskey(value, k), ("epsg", "code")) && return nothing
            return "cartesian:$(strip(name))"
        end
        kind === nothing || kind in ("geographic", "wgs84") || return nothing
        tokens = [_coordinate_crs(value[k]) for k in ("epsg", "code", "name") if haskey(value, k)]
        isempty(tokens) || any(isnothing, tokens) || length(unique(tokens)) != 1 ? nothing : first(tokens)
    elseif value isa AbstractString || (value isa Integer && !(value isa Bool))
        token = strip(string(value))
        isempty(token) && return nothing
        _spatial_is_wgs84(token) ? "WGS84" : lowercase(token)
    else
        nothing
    end
end

function _coordinate_unit(value)
    value isa AbstractString || return nothing
    token = lowercase(strip(value))
    token in ("m", "metre", "metres", "meter", "meters") && return ("m", 1.0)
    token in ("km", "kilometre", "kilometer") && return ("km", 1000.0)
    token in ("ft", "foot", "feet", "international_foot") && return ("ft", 0.3048)
    token in ("deg", "degree", "degrees") && return ("degrees", 1.0)
    nothing
end

function _coordinate_frame(net)
    declarations = _coordinate_declarations(net, _SPATIAL_CRS_KEYS)
    tokens = [_coordinate_crs(last(row)) for row in declarations]
    issues = String[]
    any(isnothing, tokens) && push!(issues, "invalid_crs_declaration")
    length(unique(filter(!isnothing, tokens))) > 1 && push!(issues, "conflicting_crs_declarations")
    token = isempty(tokens) || !isempty(issues) ? nothing : first(tokens)
    kind = token === nothing ? "unknown" : token == "WGS84" ? "wgs84" :
        startswith(token, "cartesian:") ? "cartesian" : "unsupported"
    units = _coordinate_declarations(net, ("coordinate_units",))
    axes = _coordinate_declarations(net, ("coordinate_axis_order",))
    for (path, declaration) in declarations
        declaration isa AbstractDict || continue
        haskey(declaration, "units") && push!(units, "$path.units" => declaration["units"])
        haskey(declaration, "axis_order") && push!(axes, "$path.axis_order" => declaration["axis_order"])
    end
    parsed_units = [_coordinate_unit(last(row)) for row in units]
    any(isnothing, parsed_units) && push!(issues, "unsupported_coordinate_units")
    length(unique(filter(!isnothing, parsed_units))) > 1 && push!(issues, "conflicting_coordinate_units")
    unit = isempty(parsed_units) ? (kind == "wgs84" ? ("degrees", 1.0) : nothing) : first(parsed_units)
    expected_axes = kind == "cartesian" ? ["x", "y"] : ["longitude", "latitude"]
    # Named fields define their axes. Metadata cannot silently swap their values.
    kind != "unsupported" && any(row -> last(row) != expected_axes, axes) && push!(issues, "axis_order_conflict")
    if kind == "cartesian" && unit === nothing && isempty(units)
        push!(issues, "missing_cartesian_units")
    elseif unit !== nothing && ((kind == "wgs84" && first(unit) != "degrees") ||
                               (kind == "cartesian" && first(unit) == "degrees"))
        push!(issues, "coordinate_unit_domain_conflict")
    end
    status = !isempty(issues) ? "ambiguous" : kind == "wgs84" ? "declared_wgs84" :
        kind == "cartesian" ? "declared_cartesian" : kind == "unsupported" ? "declared_other" : "unspecified"
    (kind=kind, token=token, unit=unit, status=status,
     report=Dict{String,Any}("status" => status, "frame" => token,
        "units" => unit === nothing ? nothing : first(unit), "axis_order" => expected_axes,
        "unit_scale_to_m" => kind == "cartesian" && unit !== nothing ? last(unit) : nothing,
        "issues" => sort!(unique(issues)),
        "declarations" => [Dict("path" => first(r), "value" => last(r)) for r in vcat(declarations, units, axes)]))
end

function _coordinate_metadata(record, key)
    rows = _coordinate_declarations(record, (key,))
    isempty(rows) && return (value=nothing, present=false, conflict=false)
    (value=last(first(rows)), present=true,
     conflict=any(r -> !isequal(last(r), last(first(rows))), rows))
end

function _coordinate_inventory(net, frame, route_supported)
    points = Dict{String,Tuple{Float64,Float64}}()
    evidence = Dict{String,Any}()
    counts = Dict{String,Int}()
    provenance_counts = Dict{String,Int}()
    issues = Dict{String,Any}[]
    default_accuracy = _coordinate_metadata(net, "coordinate_accuracy_m")
    default_provenance = _coordinate_metadata(net, "coordinate_provenance")
    for (id, bus) in sort!(collect(get(net, "bus", Dict())), by=first)
        bus isa AbstractDict || continue
        reasons = String[]
        local_frame = _coordinate_declarations(bus, _SPATIAL_CRS_KEYS)
        local_tokens = [_coordinate_crs(last(r)) for r in local_frame]
        expected = frame.status == "wgs84_route_evidence" ? "WGS84" : frame.token
        any(t -> t === nothing || t != expected, local_tokens) && push!(reasons, "bus_crs_conflict")
        # Local unit/axis declarations must agree; local overrides are not
        # coordinate transformations. All points in an index share one frame.
        local_units = _coordinate_declarations(bus, ("coordinate_units",))
        local_axes = _coordinate_declarations(bus, ("coordinate_axis_order",))
        for (path, declaration) in local_frame
            declaration isa AbstractDict || continue
            haskey(declaration, "units") && push!(local_units, "$path.units" => declaration["units"])
            haskey(declaration, "axis_order") && push!(local_axes, "$path.axis_order" => declaration["axis_order"])
        end
        expected_unit = frame.status == "wgs84_route_evidence" ? ("degrees", 1.0) : frame.unit
        any(r -> _coordinate_unit(last(r)) === nothing || _coordinate_unit(last(r)) != expected_unit, local_units) &&
            push!(reasons, "bus_units_conflict")
        any(r -> last(r) != frame.report["axis_order"], local_axes) && push!(reasons, "bus_axis_order_conflict")
        accuracy = _coordinate_metadata(bus, "coordinate_accuracy_m")
        accuracy.present || (accuracy = default_accuracy)
        accuracy_m = _spatial_length(accuracy.value)
        accuracy.conflict && push!(reasons, "conflicting_coordinate_accuracy")
        accuracy.present && accuracy_m === nothing && push!(reasons, "invalid_coordinate_accuracy")
        accuracy.conflict && (accuracy_m = nothing)
        provenance = _coordinate_metadata(bus, "coordinate_provenance")
        provenance.present || (provenance = default_provenance)
        origin = provenance.value isa AbstractString ? lowercase(strip(provenance.value)) : "unspecified"
        provenance.conflict && push!(reasons, "conflicting_coordinate_provenance")
        provenance.present && (!(provenance.value isa AbstractString) || isempty(origin)) &&
            push!(reasons, "invalid_coordinate_provenance")
        provenance_counts[origin] = get(provenance_counts, origin, 0) + 1
        origin in ("schematic", "displaced") && push!(reasons, "nonphysical_coordinate_provenance")
        geographic = frame.status in ("declared_wgs84", "wgs84_route_evidence")
        cartesian = frame.status == "declared_cartesian"
        family = cartesian ? ("x", "y") : ("longitude", "latitude")
        point = _spatial_point(get(bus, family[1], nothing), get(bus, family[2], nothing))
        point === nothing && push!(reasons, "missing_or_invalid_coordinate_pair")
        geographic && point !== nothing && !_wgs84_point(point) && push!(reasons, "wgs84_range")
        frame.status == "wgs84_route_evidence" && !(string(id) in route_supported) &&
            push!(reasons, "no_route_frame_evidence")
        !(geographic || cartesian) && push!(reasons, "unavailable_network_frame")
        # Accuracy describes measurement quality; invalid accuracy metadata is
        # exposed but does not invalidate the coordinate itself.
        blockers = filter(r -> !(r in ("invalid_coordinate_accuracy", "conflicting_coordinate_accuracy")), reasons)
        if isempty(blockers) && point !== nothing
            converted = cartesian ? _spatial_point(point[1] * last(frame.unit), point[2] * last(frame.unit)) : point
            if converted === nothing
                push!(reasons, "coordinate_conversion_overflow")
            else
                points[string(id)] = converted
            end
        end
        for reason in reasons
            counts[reason] = get(counts, reason, 0) + 1
        end
        if !isempty(reasons) && length(issues) < 20
            push!(issues, Dict{String,Any}("bus_id" => string(id), "issues" => reasons,
                "crs_declarations" => [Dict("path" => first(r), "value" => last(r)) for r in local_frame]))
        end
        evidence[string(id)] = Dict{String,Any}("coordinate_accuracy_m" => accuracy_m,
            "coordinate_provenance" => origin, "metric_eligible" => haskey(points, string(id)),
            "issues" => reasons)
    end
    report = merge(frame.report, Dict{String,Any}("n_metric_eligible_buses" => length(points),
        "bus_issue_counts" => counts, "bus_issue_witnesses" => issues, "bus_issue_witness_limit" => 20,
        "provenance_counts" => provenance_counts,
        "n_with_reported_accuracy" => count(e -> e["coordinate_accuracy_m"] !== nothing, values(evidence)),
        "caution" => "Named coordinate fields fix axis order. Unsupported or conflicting frames are not transformed. Accuracy and provenance are reported metadata, not independent survey evidence."))
    (points=points, evidence=evidence, report=report)
end

function _coordinate_distance(a, b, kind)
    distance = kind == "cartesian" ? hypot(a[1]-b[1], a[2]-b[2]) : _spatial_haversine(a, b)
    isfinite(distance) ? distance : nothing
end
