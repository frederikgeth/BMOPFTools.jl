"""
    voltage_level_analysis(net, findings) -> Dict{String,Any}

Propagate nominal voltage through the network graph via BFS from each
voltage source, assigning a voltage level to every bus. Transformers
are level-change edges; all other edges (lines, switches) must connect
buses at the same level.

Returns identified voltage levels, bus assignments, and any consistency
violations.
"""
function voltage_level_analysis(net::Dict{String,Any},
                                 findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()
    buses  = get(net, "bus", Dict())
    isempty(buses) && return result

    # assigned_level: bus_id => nominal voltage in V (Float64)
    assigned_level = Dict{String,Float64}()

    # --- Seed from voltage sources ---
    for (id, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", nothing)
        bus isa AbstractString || continue
        vm  = get(vs, "v_magnitude", nothing)
        vm === nothing && continue
        vals = Float64.(vm)
        isempty(vals) && continue
        vnom = maximum(vals)   # take peak phase voltage as nominal
        assigned_level[bus] = vnom
    end

    # --- BFS propagation ---
    # Build adjacency: bus => Vector of (neighbor_bus, edge_type, edge_id, ratio)
    # ratio = 1.0 for same-level edges; v_ref_to/v_ref_from for transformers
    adjacency = _build_voltage_adjacency(net)

    queue = collect(keys(assigned_level))
    while !isempty(queue)
        bus = popfirst!(queue)
        current_v = assigned_level[bus]
        for (neighbor, edge_type, edge_id, ratio) in get(adjacency, bus, [])
            expected_v = current_v * ratio
            if haskey(assigned_level, neighbor)
                existing_v = assigned_level[neighbor]
                # Check consistency: allow 5% tolerance for floating point
                if abs(existing_v - expected_v) / max(expected_v, 1.0) > 0.05
                    push!(findings, Finding(ERROR, "E.VOLT.LEVEL_MISMATCH",
                        :voltage_levels, :bus, neighbor,
                        "Bus '$neighbor' assigned conflicting voltage levels " *
                        "$(round(existing_v/1000, digits=2)) kV and " *
                        "$(round(expected_v/1000, digits=2)) kV.",
                        Dict{String,Any}("bus" => neighbor,
                                         "existing_v" => existing_v,
                                         "expected_v" => expected_v,
                                         "via_edge"   => edge_id)))
                end
            else
                assigned_level[neighbor] = expected_v
                push!(queue, neighbor)
            end
        end
    end

    # Buses with no assigned level (islanded from all sources)
    unassigned = [id for id in keys(buses) if !haskey(assigned_level, id)]
    if !isempty(unassigned)
        push!(findings, Finding(WARNING, "W.VOLT.UNASSIGNED", :voltage_levels, :bus, nothing,
            "$(length(unassigned)) bus(es) have no reachable voltage source — may be islanded.",
            Dict{String,Any}("buses" => unassigned)))
    end

    # --- Group buses into voltage levels ---
    # Cluster buses with the same nominal voltage (within 5%)
    level_groups = _cluster_voltage_levels(assigned_level)

    # For each level, collect connected component membership
    levels_out = Dict{String,Any}()
    for (level_v, bus_list) in sort(collect(level_groups), by=x->x[1])
        label = _voltage_level_label(level_v)
        levels_out[label] = Dict{String,Any}(
            "nominal_v"  => level_v,
            "nominal_kv" => level_v / 1000.0,
            "buses"      => sort(bus_list),
            "n_buses"    => length(bus_list)
        )
        # lines within this level
        level_bus_set = Set(bus_list)
        level_lines = [id for (id, l) in get(net, "line", Dict())
                       if get(l, "bus_from", "") in level_bus_set &&
                          get(l, "bus_to",   "") in level_bus_set]
        levels_out[label]["lines"]   = level_lines
        levels_out[label]["n_lines"] = length(level_lines)

        # loads at this level
        level_loads = [id for (id, l) in get(net, "load", Dict())
                       if get(l, "bus", "") in level_bus_set]
        levels_out[label]["loads"]   = level_loads
        levels_out[label]["n_loads"] = length(level_loads)

        # generators at this level
        level_gens = [id for (id, g) in get(net, "generator", Dict())
                      if get(g, "bus", "") in level_bus_set]
        levels_out[label]["generators"]   = level_gens
        levels_out[label]["n_generators"] = length(level_gens)
    end

    result["levels"]              = levels_out
    result["n_levels"]            = length(levels_out)
    result["bus_voltage_map"]     = Dict(k => v for (k, v) in assigned_level)
    result["unassigned_buses"]    = unassigned

    # Transformer transition summary
    transitions = _transformer_transitions(net, assigned_level)
    result["transformer_transitions"] = transitions

    # Check: non-transformer edges crossing voltage levels
    _check_level_crossing_lines(net, assigned_level, findings)
    _check_transformer_ratio_consistency(net, assigned_level, findings)

    result
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function _build_voltage_adjacency(net::Dict{String,Any})
    # adjacency: bus => [(neighbor, edge_type, edge_id, ratio)]
    adj = Dict{String,Vector{Tuple{String,Symbol,String,Float64}}}()

    function add_adj!(a, b, etype, eid, ratio)
        push!(get!(adj, a, []), (b, etype, eid, ratio))
        push!(get!(adj, b, []), (a, etype, eid, 1.0/ratio))
    end

    # Transformers first so transformer-defined level boundaries take BFS priority
    # over line edges. When both a transformer and a line connect the same two
    # buses, the transformer must win to detect line-crossing violations correctly.
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            (f isa AbstractString && b isa AbstractString) || continue
            vf = get(t, "v_ref_from", nothing)
            vt = get(t, "v_ref_to",   nothing)
            ratio = (vf !== nothing && vt !== nothing && Float64(vf) > 0) ?
                    Float64(vt) / Float64(vf) : 1.0
            add_adj!(f, b, :transformer, id, ratio)
        end
    end

    # n-winding: edge from winding 1 to every other winding (ratio v_ref_j/v_ref_1).
    for (id, t) in get(xfmr, "n_winding", Dict())
        ws = _nw_windings(t)
        isempty(ws) && continue
        b1, v1 = ws[1].bus, ws[1].v_ref
        isempty(b1) && continue
        for j in 2:length(ws)
            bj, vj = ws[j].bus, ws[j].v_ref
            (isempty(bj) || bj == b1) && continue
            ratio = v1 > 0 ? vj / v1 : 1.0
            add_adj!(b1, bj, :transformer, id, ratio)
        end
    end

    for (id, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        add_adj!(f, t, :line, id, 1.0)
    end

    for (id, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        add_adj!(f, t, :switch, id, 1.0)
    end

    adj
end

function _cluster_voltage_levels(assigned::Dict{String,Float64};
                                  tol::Float64=0.05)
    # Sort buses by voltage so clustering is deterministic, then group
    # sequentially using a running-mean centroid per cluster.
    sorted_pairs = sort(collect(assigned), by=last)
    clusters = Vector{Tuple{Float64,Vector{String}}}()  # (centroid, members)

    for (bus, v) in sorted_pairs
        if !isempty(clusters)
            centroid, members = clusters[end]
            if abs(v - centroid) / max(centroid, 1.0) <= tol
                push!(members, bus)
                # update running mean
                new_centroid = centroid + (v - centroid) / length(members)
                clusters[end] = (new_centroid, members)
                continue
            end
        end
        push!(clusters, (v, String[bus]))
    end

    Dict{Float64,Vector{String}}(c => m for (c, m) in clusters)
end

function _voltage_level_label(v_volts::Float64)::String
    kv = v_volts / 1000.0
    if kv >= 100
        "EHV_$(round(Int, kv))kV"
    elseif kv >= 35
        "HV_$(round(Int, kv))kV"
    elseif kv >= 1
        "MV_$(round(kv, digits=1))kV"
    else
        "LV_$(round(Int, v_volts))V"
    end
end

function _transformer_transitions(net::Dict{String,Any},
                                   assigned::Dict{String,Float64})
    transitions = Dict{String,Any}[]
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            f = get(t, "bus_from", nothing)
            b = get(t, "bus_to",   nothing)
            vf = get(assigned, f, nothing)
            vt = get(assigned, b, nothing)
            push!(transitions, Dict{String,Any}(
                "id"           => id,
                "subtype"      => subtype,
                "vector_group" => _derive_vector_group(subtype, t),
                "bus_from"     => f,
                "bus_to"       => b,
                "v_from"       => vf,
                "v_to"         => vt,
                "level_from"   => vf !== nothing ? _voltage_level_label(vf) : "unknown",
                "level_to"     => vt !== nothing ? _voltage_level_label(vt) : "unknown"
            ))
        end
    end

    # n-winding: one transition row per winding 1 → winding j boundary.
    for (id, t) in get(xfmr, "n_winding", Dict())
        ws = _nw_windings(t)
        isempty(ws) && continue
        vg = _derive_vector_group("n_winding", t)
        f  = ws[1].bus
        vf = get(assigned, f, nothing)
        for j in 2:length(ws)
            b  = ws[j].bus
            vt = get(assigned, b, nothing)
            push!(transitions, Dict{String,Any}(
                "id"           => "$(id) (w1→w$j)",
                "subtype"      => "n_winding",
                "vector_group" => vg,
                "bus_from"     => f,
                "bus_to"       => b,
                "v_from"       => vf,
                "v_to"         => vt,
                "level_from"   => vf !== nothing ? _voltage_level_label(vf) : "unknown",
                "level_to"     => vt !== nothing ? _voltage_level_label(vt) : "unknown"
            ))
        end
    end
    transitions
end

function _check_level_crossing_lines(net::Dict{String,Any},
                                      assigned::Dict{String,Float64},
                                      findings::Vector{Finding})
    for (id, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        vf = get(assigned, f, nothing); vt = get(assigned, t, nothing)
        (vf === nothing || vt === nothing) && continue
        if abs(vf - vt) / max(vf, 1.0) > 0.05
            push!(findings, Finding(ERROR, "E.VOLT.LINE_CROSSING",
                :voltage_levels, :line, id,
                "Line '$id' connects buses at different voltage levels " *
                "($(round(vf/1000,digits=2)) kV ↔ $(round(vt/1000,digits=2)) kV). " *
                "Only transformers should cross voltage levels.",
                Dict{String,Any}("line" => id, "v_from" => vf, "v_to" => vt)))
        end
    end
end

function _check_transformer_ratio_consistency(net::Dict{String,Any},
                                               assigned::Dict{String,Float64},
                                               findings::Vector{Finding})
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            vf_bus = get(assigned, f, nothing)
            vt_bus = get(assigned, b, nothing)
            vf_ref = get(t, "v_ref_from", nothing)
            vt_ref = get(t, "v_ref_to",   nothing)
            (vf_bus === nothing || vt_bus === nothing) && continue
            (vf_ref === nothing || vt_ref === nothing) && continue
            expected_ratio = Float64(vt_ref) / Float64(vf_ref)
            actual_ratio   = vt_bus / vf_bus
            if abs(expected_ratio - actual_ratio) / max(expected_ratio, 1e-6) > 0.1
                push!(findings, Finding(WARNING, "W.VOLT.XFMR_RATIO",
                    :voltage_levels, :transformer, id,
                    "Transformer '$id' turns ratio $(round(expected_ratio, digits=3)) " *
                    "inconsistent with adjacent bus voltage ratio " *
                    "$(round(actual_ratio, digits=3)).",
                    Dict{String,Any}("id" => id,
                                     "turns_ratio"    => expected_ratio,
                                     "bus_ratio"      => actual_ratio)))
            end
        end
    end
end

"""
    _assign_nominal_voltages(net) -> Dict{String,Float64}

BFS from every voltage source to assign a phase-to-neutral nominal voltage (V)
to every reachable bus. Transformer edges apply the v_ref_to/v_ref_from ratio.
Used by `diagnose_infeasibility` to derive per-unit voltage thresholds for buses
that have no explicit v_min/v_max.
"""
function _assign_nominal_voltages(net::Dict{String,Any})::Dict{String,Float64}
    assigned = Dict{String,Float64}()

    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", nothing)
        bus isa AbstractString || continue
        vm = get(vs, "v_magnitude", nothing)
        vm === nothing && continue
        vals = Float64.(vm)
        isempty(vals) && continue
        assigned[bus] = maximum(vals)
    end

    adjacency = _build_voltage_adjacency(net)
    queue = collect(keys(assigned))
    while !isempty(queue)
        bus = popfirst!(queue)
        v = assigned[bus]
        for (neighbor, _, _, ratio) in get(adjacency, bus, [])
            haskey(assigned, neighbor) && continue
            assigned[neighbor] = v * ratio
            push!(queue, neighbor)
        end
    end

    assigned
end
