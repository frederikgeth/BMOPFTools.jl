# Static connection-map evidence (PSK-000002). Read raw endpoints rather than
# numeric transformer accessors: validation must retain original winding indices.
function _connection_records(net)
    records = NamedTuple[]
    for kind in ("line", "switch", "transformer")
        collection = get(net, kind, Dict())
        collection isa AbstractDict || continue
        groups = kind == "transformer" ?
            [(s, get(collection,s,Dict())) for s in TRANSFORMER_SUBTYPES] : [(nothing,collection)]
        for (subtype, group) in groups
            group isa AbstractDict || continue
            for id in sort!(collect(keys(group)))
                push!(records, (;kind,id,subtype,component=group[id]))
            end
        end
    end
    records
end

function _connection_endpoints(record)
    c = record.component
    c isa AbstractDict || return NamedTuple[]
    if record.subtype in WINDING_LIST_SUBTYPES
        ws = get(c,"windings",nothing)
        ws isa AbstractVector || return NamedTuple[]
        return [(;side="winding",winding=k,
            bus=w isa AbstractDict ? get(w,"bus",nothing) : nothing,
            map=w isa AbstractDict ? get(w,"terminal_map",nothing) : nothing,
            raw=w) for (k,w) in enumerate(ws)]
    end
    [(;side,winding=nothing,bus=get(c,"bus_$side",nothing),
        map=get(c,"terminal_map_$side",nothing),raw=c) for side in ("from","to")]
end

function _connection_evidence(net, record, endpoint; roles=_index_roles(net))
    c = Dict{String,Any}("bus"=>endpoint.bus,"terminal_map"=>endpoint.map)
    d = _device_index_context(net,record.kind,record.id,c;roles).evidence
    merge(d,Dict{String,Any}("subtype"=>record.subtype,"topology"=>something(record.subtype,record.kind),"side"=>endpoint.side,
        "winding"=>endpoint.winding,"indexing_domain"=>"connection_positions"))
end

function _connection_shape!(findings,record,detail,rule)
    push!(findings,Finding(ERROR,"E.INT.CONNECTION_SHAPE",:integrity,
        Symbol(record.kind),record.id,"Connection data does not match its structural contract.",
        merge(detail,Dict{String,Any}("rule"=>rule,"subtype"=>record.subtype,
            "knowledge_ids"=>["PSK-000002"]))))
end

function _line_connection_evidence(net,id,line)
    r=(;kind="line",id,subtype=nothing,component=line)
    Dict{String,Any}("rule"=>"matrix_row_matches_endpoint_position",
        "endpoints"=>[_connection_evidence(net,r,e) for e in _connection_endpoints(r)],
        "knowledge_ids"=>["PSK-000002"])
end

# Reference errors retain the existing integrity codes. Spec checks below do not
# duplicate these findings. Each valid endpoint is visited exactly once.
function _check_connection_references!(net,findings)
    buses=get(net,"bus",Dict()); roles=_index_roles(net); before=length(findings)
    for r in _connection_records(net)
        if !(r.component isa AbstractDict)
            _connection_shape!(findings,r,Dict{String,Any}("field"=>"component"),"component_object")
            continue
        end
        if r.subtype in WINDING_LIST_SUBTYPES && !(get(r.component,"windings",nothing) isa AbstractVector)
            _connection_shape!(findings,r,Dict{String,Any}("field"=>"windings"),"winding_list")
            continue
        end
        for e in _connection_endpoints(r)
            d=_connection_evidence(net,r,e;roles)
            if !(e.raw isa AbstractDict)
                _connection_shape!(findings,r,d,"winding_object")
                continue
            end
            if !(e.bus isa AbstractString)
                _connection_shape!(findings,r,merge(d,Dict("field"=>"bus")),"bus_identifier")
            elseif !haskey(buses,e.bus)
                push!(findings,Finding(ERROR,"E.INT.UNKNOWN_BUS",:integrity,Symbol(r.kind),r.id,
                    "Connection endpoint references an unknown bus.",
                    merge(d,Dict("field"=>"bus","rule"=>"referenced_bus_exists"))))
            end
            if !_index_strings(e.map) || isempty(e.map)
                _connection_shape!(findings,r,d,"nonempty_string_terminal_map")
                continue
            end
            b=get(buses,e.bus,nothing)
            b isa AbstractDict && _index_strings(get(b,"terminal_names",nothing)) || continue
            bad=[k for k in eachindex(e.map) if !(e.map[k] in b["terminal_names"])]
            isempty(bad) && continue
            push!(findings,Finding(ERROR,"E.INT.UNKNOWN_TERMINAL",:integrity,Symbol(r.kind),r.id,
                "Connection endpoint references undeclared bus terminals.",
                merge(d,Dict{String,Any}("terminals"=>e.map[bad],"invalid_positions"=>bad,
                    "rule"=>"terminal_belongs_to_bus"))))
        end
        if r.kind=="switch"
            es=_connection_endpoints(r)
            all(e -> _index_strings(e.map),es) || continue
            if length(es[1].map)!=length(es[2].map)
                push!(findings,Finding(ERROR,"E.INT.SWITCH_DIM_MISMATCH",:integrity,:switch,r.id,
                    "Switch endpoint maps must have equal length; no position may be truncated.",
                    Dict{String,Any}("from"=>length(es[1].map),"to"=>length(es[2].map),
                        "rule"=>"equal_endpoint_dimensions",
                        "endpoints"=>[_connection_evidence(net,r,e;roles) for e in es])))
            end
        end
    end
    length(findings)-before
end

function _connection_rule!(findings,r,d,rule; code="E.TMAP.WINDING_ROLES", severity=ERROR, extra=Dict())
    push!(findings,Finding(severity,code,:spec,Symbol(r.kind),r.id,
        "Connection map does not satisfy the supported rule '$rule'.",
        merge(d,Dict{String,Any}("rule"=>rule),extra)))
end

function _check_connection_maps!(net,findings)
    roles=_index_roles(net); before=length(findings)
    for r in _connection_records(net)
        r.component isa AbstractDict || continue
        es=_connection_endpoints(r)
        ds=[_connection_evidence(net,r,e;roles) for e in es]
        # Length checks do not need resolved references or numeric winding data.
        if r.kind=="transformer"
            if r.subtype=="n_winding"
                if get(r.component,"windings",nothing) isa AbstractVector && length(es)<2
                    _connection_rule!(findings,r,Dict{String,Any}("subtype"=>r.subtype),"at_least_two_windings";
                        code="W.SPEC.XFMR_TMAP_ARITY",severity=WARNING)
                end
            elseif haskey(_XFMR_ARITY,r.subtype) && all(e -> _index_strings(e.map),es)
                expected=_XFMR_ARITY[r.subtype]; observed=Tuple(length(e.map) for e in es)
                if observed!=expected
                    _connection_rule!(findings,r,Dict{String,Any}("subtype"=>r.subtype,
                        "from"=>observed[1],"to"=>observed[2],"endpoints"=>ds),"subtype_map_arity";
                        code="W.SPEC.XFMR_TMAP_ARITY",severity=WARNING,
                        extra=Dict("expected_lengths"=>collect(expected)))
                end
            end
        end
        assessed=Bool[]
        for (e,d) in zip(es,ds)
            valid=_index_strings(e.map) && !isempty(e.map)
            duplicates=valid && length(unique(e.map))!=length(e.map)
            if duplicates
                _connection_rule!(findings,r,d,"distinct_endpoint_terminals";
                    code="E.SPEC.DUPLICATE_TERMINAL",
                    extra=Dict("duplicates"=>[t for t in unique(e.map) if count(==(t),e.map)>1]))
                # Retain the established repeated-all-neutral branch diagnostic.
                if r.kind in ("line","switch") && !isempty(d["resolved_roles"]) &&
                    all(==("neutral"),d["resolved_roles"])
                    _connection_rule!(findings,r,d,"nondegenerate_neutral_link";code="E.TMAP.PHASE_TO_NEUTRAL")
                end
            end
            if r.subtype=="n_winding" && e.raw isa AbstractDict && valid
                cfg=uppercase(string(get(e.raw,"configuration","WYE")))
                if cfg in ("WYE","DELTA") && length(e.map)<2
                    _connection_rule!(findings,r,d,"winding_minimum_two_terminals";
                        code="W.SPEC.XFMR_TMAP_ARITY",severity=WARNING)
                elseif !(cfg in ("WYE","DELTA"))
                    _connection_rule!(findings,r,d,"supported_winding_configuration";
                        code="W.SPEC.BAD_CONFIG",severity=WARNING,extra=Dict("configuration"=>cfg))
                end
            end
            reason=d["reason"]
            if valid && !duplicates && reason in ("role_declaration_shape","unresolved_roles",
                                                    "multiple_bus_neutrals","unsupported_earth_conductor")
                _connection_rule!(findings,r,d,"resolved_phase_neutral_domain";
                    code="W.TMAP.CONNECTION_UNASSESSED",severity=WARNING)
            end
            push!(assessed,valid && !duplicates && reason===nothing)
        end
        if r.kind in ("line","switch")
            length(es)==2 && all(assessed) && length(es[1].map)==length(es[2].map) || continue
            for k in eachindex(es[1].map)
                ds[1]["resolved_roles"][k]==ds[2]["resolved_roles"][k] && continue
                _connection_rule!(findings,r,Dict{String,Any}("position"=>k,"endpoints"=>ds,
                    "knowledge_ids"=>["PSK-000002"]),"same_conductor_role_at_position";
                    code="E.TMAP.PHASE_TO_NEUTRAL")
            end
            continue
        end
        counts=Union{Nothing,Int}[]
        for (j,(e,d)) in enumerate(zip(es,ds))
            push!(counts,nothing)
            assessed[j] || continue
            rs=d["resolved_roles"]; np=count(==("phase"),rs); nn=count(==("neutral"),rs)
            subtype=r.subtype
            cfg=subtype=="n_winding" ? uppercase(string(get(e.raw,"configuration","WYE"))) :
                subtype=="wye_delta" ? (e.side=="from" ? "WYE" : "DELTA") :
                subtype=="delta_wye" ? (e.side=="to" ? "WYE" : "DELTA") : "PAIR"
            d["configuration"]=cfg
            rule=nothing
            if nn>1 || np==0
                rule="positive_phase_count_single_neutral"
            elseif subtype=="center_tap"
                ok=e.side=="to" ? rs==["phase","neutral","phase"] :
                    rs in (["phase","neutral"],["phase","phase"])
                ok || (rule="center_tap_positional_polarity")
            elseif cfg=="DELTA"
                nn==0 && np>=2 || (rule="delta_phase_only_coils")
                counts[j]=np
            elseif cfg=="WYE"
                counts[j]=np
                if nn==0 && subtype=="n_winding" && length(e.map)>=2
                    _connection_rule!(findings,r,d,"explicit_wye_neutral";
                        code="W.SPEC.XFMR_TMAP_ARITY",severity=WARNING)
                end
            elseif subtype=="open_delta_regulator"
                np==3 || (rule="three_regulator_phases")
                counts[j]=np
            elseif subtype in ("single_phase","single_phase_autotransformer")
                counts[j]=nn==0 && length(rs)==2 ? 1 : np
                subtype=="single_phase_autotransformer" && counts[j]!=1 &&
                    (rule="single_regulating_winding")
            end
            rule===nothing || _connection_rule!(findings,r,d,rule)
        end
        if length(counts)>=2 && all(x -> x!==nothing,counts) && length(unique(counts))!=1
            _connection_rule!(findings,r,Dict{String,Any}("subtype"=>r.subtype,"endpoints"=>ds,
                "coil_counts"=>counts,"knowledge_ids"=>["PSK-000002"]),"matching_coupled_coil_counts")
        end
        # Unlike isolated windings, an autotransformer's two explicit reference
        # bushings are physically tied by the native model. Compare that pair
        # only, resolving neutral by role rather than by map position.
        if r.subtype=="single_phase_autotransformer" && length(es)==2 && all(assessed) && counts==[1,1]
            refs=[findfirst(==("neutral"),d["resolved_roles"]) for d in ds]
            refs=[q===nothing && length(e.map)==2 ? 2 : q for (q,e) in zip(refs,es)]
            if all(q -> q!==nothing,refs) && ds[1]["resolved_roles"][refs[1]]!=ds[2]["resolved_roles"][refs[2]]
                _connection_rule!(findings,r,Dict{String,Any}("subtype"=>r.subtype,
                    "endpoints"=>ds,"reference_positions"=>refs,"knowledge_ids"=>["PSK-000002"]),
                    "shared_regulator_reference_role")
            end
        end
    end
    length(findings)-before
end
