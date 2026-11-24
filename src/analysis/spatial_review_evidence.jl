# Literal, shallow metadata excerpts. Never infer provenance from asset names or
# search historical nested models such as prior_line. Values remain source claims.
const _SPATIAL_PROVENANCE_KEYS = ("origin", "evidence_status", "claim", "attachment_mode", "method", "source_ref", "placeholder")
function _spatial_model_declarations(object)
    meta = get(object, "meta", nothing)
    meta isa AbstractDict || return Dict{String,Any}[]
    rows = Dict{String,Any}[]
    function capture(container, path)
        for key in _SPATIAL_PROVENANCE_KEYS
            value = get(container, key, nothing)
            value isa Union{AbstractString,Bool,Real} || continue
            push!(rows, Dict("path" => [path; key], "value" => _jsonable(value)))
        end
    end
    capture(meta, ["meta"])
    for key in sort!(collect(keys(meta)), by=string)
        meta[key] isa AbstractDict || continue
        capture(meta[key], ["meta", string(key)])
    end
    rows
end

function _spatial_review_attachment_index(net)
    index = Dict{String,Vector{Dict{String,Any}}}()
    for kind in ("load", "shunt", "capacitor", "voltage_source", "generator", "solar", "storage")
        for (id, object) in sort!(collect(get(net, kind, Dict())), by=first)
            object isa AbstractDict || continue
            bus = get(object, "bus", nothing)
            bus isa AbstractString || continue
            push!(get!(index, bus, Dict{String,Any}[]), Dict{String,Any}(
                "kind" => kind, "component_id" => string(id),
                "terminal_map" => _jsonable(get(object, "terminal_map", nothing))))
        end
    end
    index
end

function _spatial_series_review_evidence(net, witness, length_contexts, attachments)
    path = [b["bus_id"] for b in witness["path_buses"]]
    function branch(ref, from, to)
        id = ref["component_id"]
        line = net["line"][id]
        forward = line["bus_from"] == from
        Dict{String,Any}("line_id" => id, "path_from" => from, "path_to" => to,
            "terminal_map_from" => _jsonable(get(line, forward ? "terminal_map_from" : "terminal_map_to", nothing)),
            "terminal_map_to" => _jsonable(get(line, forward ? "terminal_map_to" : "terminal_map_from", nothing)),
            "length_context" => get(length_contexts, id, nothing),
            "model_declarations" => _spatial_model_declarations(line))
    end
    direct = branch(witness["direct_branch"], first(path), last(path))
    series = [branch(ref, path[i], path[i+1]) for (i,ref) in enumerate(witness["series_branches"])]
    # Terminal labels are compared only at the SAME bus. This is not composition
    # of branch conductor maps and does not establish electrical equivalence.
    function compare(bus, a, b)
        valid(x) = x isa AbstractVector && !isempty(x) && all(t -> t isa AbstractString, x) && length(unique(x)) == length(x)
        relation = !valid(a) || !valid(b) ? "indeterminate" :
            Set(a) == Set(b) ? "same_declared_terminal_sets" : "different_declared_terminal_sets"
        Dict("bus_id" => bus, "left_terminal_map" => a, "right_terminal_map" => b, "relation" => relation)
    end
    comparisons = [compare(first(path), direct["terminal_map_from"], first(series)["terminal_map_from"]),
        compare(last(path), direct["terminal_map_to"], last(series)["terminal_map_to"])]
    for i in 1:length(series)-1
        push!(comparisons, compare(path[i+1], series[i]["terminal_map_to"], series[i+1]["terminal_map_from"]))
    end
    function grounded(bus)
        object = net["bus"][bus]
        object isa AbstractDict ? _jsonable(get(object, "perfectly_grounded_terminals", nothing)) : nothing
    end
    intermediate = [Dict{String,Any}("bus_id" => bus,
        "attachments" => get(attachments, bus, Dict{String,Any}[]),
        "perfectly_grounded_terminals" => grounded(bus)) for bus in path[2:end-1]]
    Dict{String,Any}("direct" => direct, "series" => series,
        "terminal_comparisons" => comparisons, "intermediate_buses" => intermediate,
        "scope" => "Path-oriented terminal declarations at common buses, lengths and shallow source claims. Equal terminal sets do not prove conductor-path equivalence. Shunts may implement grounding; no grounding role is inferred. Missing metadata is unknown, not observed provenance.")
end
