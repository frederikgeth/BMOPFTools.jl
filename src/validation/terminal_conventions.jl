# Read-only AC role bookkeeping (#410), within the represented-terminal domain
# associated with PSK-000002. Connection physics remains owned by device/map checks.
const _CONVENTION_ROLES = ("phase", "neutral", "earth")

# RFC 6901 pointers: array positions in paths are zero-based; map_position and
# winding in semantic evidence retain the package's one-based convention.
_terminal_pointer(parts...) = "/" * join((replace(string(p), "~"=>"~0", "/"=>"~1") for p in parts), "/")

function _terminal_usage_inventory(net)
    usage = Dict{String,Any}[]
    unassessed = String[]
    raw_buses = get(net, "bus", Dict())
    buses = raw_buses isa AbstractDict ? raw_buses : Dict()
    raw_buses isa AbstractDict || push!(unassessed, "/bus")

    function record(labels, parts, kind, id, bus, field; declaration=false, winding=nothing)
        _index_strings(labels) || push!(unassessed, _terminal_pointer(parts...))
        labels isa AbstractVector || return
        b = bus isa AbstractString ? get(buses, bus, nothing) : nothing
        names = b isa AbstractDict ? get(b, "terminal_names", nothing) : nothing
        for (position, label) in enumerate(labels)
            label isa AbstractString || continue
            status = declaration ? "declared" : !(b isa AbstractDict) ? "unknown_bus" :
                !_index_strings(names) ? "unassessed" : label in names ? "resolved" : "unknown_terminal"
            push!(usage, Dict{String,Any}("label"=>label,
                "path"=>_terminal_pointer(parts..., position-1), "bus"=>bus,
                "component_type"=>kind, "component_id"=>id, "field"=>field,
                "map_position"=>position, "winding"=>winding, "reference_status"=>status))
        end
    end

    for id in sort!(collect(keys(buses)))
        bus = buses[id]
        if !(bus isa AbstractDict)
            push!(unassessed, _terminal_pointer("bus", id)); continue
        end
        record(get(bus,"terminal_names",nothing), ("bus",id,"terminal_names"),
            "bus",id,id,"terminal_names"; declaration=true)
        if haskey(bus,"perfectly_grounded_terminals")
            record(bus["perfectly_grounded_terminals"], ("bus",id,"perfectly_grounded_terminals"),
                "bus",id,id,"perfectly_grounded_terminals")
        end
        if haskey(bus,"neutral_terminal")
            nt = bus["neutral_terminal"]
            # A scalar metadata reference has no array index in its path.
            if nt isa AbstractString
                record([nt], ("bus",id,"neutral_terminal"), "bus",id,id,"neutral_terminal")
                usage[end]["path"] = _terminal_pointer("bus",id,"neutral_terminal")
                usage[end]["map_position"] = nothing
            else
                push!(unassessed, _terminal_pointer("bus",id,"neutral_terminal"))
            end
        end
    end

    for kind in ("load", "generator", "ibr", "shunt", "voltage_source", "capacitor")
        collection = get(net,kind,Dict())
        if !(collection isa AbstractDict)
            push!(unassessed,_terminal_pointer(kind)); continue
        end
        for id in sort!(collect(keys(collection)))
            c = collection[id]
            if !(c isa AbstractDict)
                push!(unassessed,_terminal_pointer(kind,id)); continue
            end
            record(get(c,"terminal_map",nothing), (kind,id,"terminal_map"),
                kind,id,get(c,"bus",nothing),"terminal_map")
        end
    end

    # Reuse #409's curated endpoint traversal; never infer winding mappings.
    for kind in ("line", "switch", "transformer")
        collection = get(net,kind,Dict())
        if !(collection isa AbstractDict)
            push!(unassessed,_terminal_pointer(kind)); continue
        end
        if kind == "transformer"
            for (subtype, group) in collection
                if !(subtype in TRANSFORMER_SUBTYPES) || !(group isa AbstractDict)
                    push!(unassessed,_terminal_pointer(kind,subtype))
                end
            end
        end
    end
    for r in _connection_records(net)
        parts = r.subtype === nothing ? (r.kind,r.id) : (r.kind,r.subtype,r.id)
        if !(r.component isa AbstractDict)
            push!(unassessed,_terminal_pointer(parts...)); continue
        end
        if r.subtype in WINDING_LIST_SUBTYPES && !(get(r.component,"windings",nothing) isa AbstractVector)
            push!(unassessed,_terminal_pointer(parts...,"windings")); continue
        end
        for e in _connection_endpoints(r)
            nested = e.winding !== nothing
            field = nested ? "terminal_map" : "terminal_map_$(e.side)"
            endpoint = nested ? (parts...,"windings",e.winding-1) : parts
            record(e.map, (endpoint...,field), r.kind,r.id,e.bus,field; winding=e.winding)
        end
    end
    sort!(usage; by=row->row["path"])
    (;usage, unassessed_paths=sort!(unique(unassessed)))
end

"""
    _check_terminal_conventions(net, findings, n_checks) -> Dict

Inventory explicit role declarations and authored AC terminal references without
mutating or reclassifying input. Unknown map references retain their integrity
owner; resolved component references enrich the bus-unclassified Finding.
"""
function _check_terminal_conventions(net, findings, n_checks)
    inventory = _terminal_usage_inventory(net)
    declarations = Dict{String,Any}[]
    invalid = Dict{String,Any}[]
    explicit = haskey(net,"terminal_conventions")
    tc = get(net,"terminal_conventions",nothing)
    if explicit
        if !(tc isa AbstractDict)
            push!(invalid,Dict{String,Any}("path"=>"/terminal_conventions", "expected"=>"object"))
        else
            for role in _CONVENTION_ROLES
                labels = get(tc,role,String[])
                if !_index_strings(labels)
                    push!(invalid,Dict{String,Any}("path"=>_terminal_pointer("terminal_conventions",role),
                        "expected"=>"array_of_strings"))
                end
                labels isa AbstractVector || continue
                for (i,label) in enumerate(labels)
                    label isa AbstractString || continue
                    push!(declarations,Dict{String,Any}("label"=>label,"role"=>role,
                        "path"=>_terminal_pointer("terminal_conventions",role,i-1)))
                end
            end
        end
    end
    result = Dict{String,Any}("role_source"=>explicit ? "declared" : "inferred",
        "status"=>"assessed", "declarations"=>declarations, "usage"=>inventory.usage,
        "unassessed_paths"=>inventory.unassessed_paths, "invalid_declarations"=>invalid,
        "resolved_roles"=>nothing,
        "unclassified_labels"=>String[], "unused_labels"=>nothing,
        "knowledge_ids"=>["PSK-000002"])
    (haskey(net,"bus") || explicit) && (n_checks[] += 1)
    for detail in invalid
        push!(findings,Finding(ERROR,"E.CONV.DECLARATION_INVALID",:domain_rules,:network,nothing,
            "Terminal-role declaration does not have the supported shape.",detail))
    end
    if !isempty(invalid)
        result["role_source"] = "invalid"
        result["status"] = "indeterminate"
        return result
    end

    if !explicit && haskey(net,"bus")
        push!(findings,Finding(WARNING,"W.CONV.TERMINAL_ROLES_INFERRED",:domain_rules,:network,nothing,
            "No terminal_conventions block: legacy bus-name inference is used where terminal names can be assessed.",
            Dict{String,Any}("role_source"=>"inferred", "rule"=>"n_or_N_is_neutral")))
    end
    # Explicit declaration facts do not depend on whether every bus is valid.
    # _index_roles also checks bus shapes, so reserve it for legacy inference.
    roles = explicit ? _terminal_roles(net) :
        get(net,"bus",Dict()) isa AbstractDict ? _index_roles(net) : nothing
    if roles === nothing
        result["status"] = "indeterminate"
        return result
    end
    result["resolved_roles"] = Dict{String,Any}(role=>sort!(collect(labels)) for (role,labels) in
        zip(_CONVENTION_ROLES,(roles.phase,roles.neutral,roles.earth)))
    if !explicit
        isempty(inventory.unassessed_paths) || (result["status"]="indeterminate")
        return result
    end

    sets = (roles.phase, roles.neutral, roles.earth)
    for (ia,ib) in ((1,2),(1,3),(2,3))
        labels = sort!(collect(intersect(sets[ia],sets[ib])))
        isempty(labels) && continue
        names = [_CONVENTION_ROLES[ia],_CONVENTION_ROLES[ib]]
        push!(findings,Finding(ERROR,"E.CONV.ROLE_OVERLAP",:domain_rules,:network,nothing,
            "Terminal labels are declared in multiple role lists.",
            Dict{String,Any}("labels"=>labels,"roles"=>names,
                "declarations"=>[d for d in declarations if d["label"] in labels && d["role"] in names])))
    end
    raw_buses = get(net,"bus",Dict())
    buses = raw_buses isa AbstractDict ? raw_buses : Dict()
    for id in sort!(collect(keys(buses)))
        b = buses[id]
        b isa AbstractDict || continue
        names = get(b,"terminal_names",nothing)
        _index_strings(names) || continue
        neuts = sort!(unique([t for t in names if t in roles.neutral]))
        if length(neuts)>1
            push!(findings,Finding(WARNING,"W.CONV.MULTIPLE_NEUTRALS",:domain_rules,:bus,id,
                "Bus carries multiple terminals classified as neutral.",
                Dict{String,Any}("terminals"=>neuts,"path"=>_terminal_pointer("bus",id,"terminal_names"))))
        end
        haskey(b,"neutral_terminal") || continue
        nt = b["neutral_terminal"]
        matched = nt isa AbstractString ? [_CONVENTION_ROLES[i] for i in 1:3 if nt in sets[i]] : String[]
        # Role-overlap Findings own ambiguity; do not duplicate that root error.
        nt isa AbstractString && nt in names && ("neutral" in matched) && continue
        detail = Dict{String,Any}("label"=>nt,"path"=>_terminal_pointer("bus",id,"neutral_terminal"),
            "declared_roles"=>matched,"expected_neutral_labels"=>neuts,
            "reason"=>!(nt isa AbstractString) ? "metadata_shape" : !(nt in names) ? "unknown_terminal" : "not_declared_neutral",
            "declarations"=>[d for d in declarations if d["label"]==nt])
        push!(findings,Finding(ERROR,"E.CONV.BUS_ROLE_CONFLICT",:domain_rules,:bus,id,
            "Bus neutral_terminal metadata conflicts with the declared terminal roles or bus terminals.",detail))
    end

    classified = union(sets...)
    missing = [u for u in inventory.usage if !(u["label"] in classified) &&
        u["field"]!="neutral_terminal" && u["reference_status"] in ("declared","resolved")]
    labels = sort!(unique([u["label"] for u in missing]))
    result["unclassified_labels"] = labels
    if !isempty(labels)
        bus_ids = sort!(unique([u["bus"] for u in missing]))
        push!(findings,Finding(WARNING,"W.CONV.TERMINAL_UNCLASSIFIED",:domain_rules,:bus,
            length(bus_ids)==1 ? only(bus_ids) : nothing,
            "Existing AC terminals are in none of the declared role lists; legacy consumers treat them as phases.",
            Dict{String,Any}("labels"=>labels,"buses"=>bus_ids,"usage"=>missing)))
    end
    if isempty(inventory.unassessed_paths)
        used = Set(u["label"] for u in inventory.usage)
        unused = sort!(collect(setdiff(classified,used)))
        result["unused_labels"] = unused
        if !isempty(unused)
            push!(findings,Finding(INFO,"I.CONV.UNUSED_LABEL",:domain_rules,:network,nothing,
                "Declared terminal-role labels are unused in the supported AC representation.",
                Dict{String,Any}("labels"=>unused,
                    "declarations"=>[d for d in declarations if d["label"] in unused])))
        end
    else
        result["status"] = "indeterminate"
    end
    result
end
