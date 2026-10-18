# Package-owned device indexing evidence (PSK-000002). This is not a new
# connection model. Keep counts aligned with the native consumers documented in
# docs/src/device_indexing.md; do not infer a neutral from an arbitrary last slot.
_index_strings(x) = x isa AbstractVector && all(t -> t isa AbstractString, x)
_index_number(x) = x isa Real && !(x isa Bool)
_index_numbers(x) = x isa AbstractVector && all(_index_number, x)
_index_shape(x) = x isa AbstractVector ? Dict{String,Any}("kind"=>"vector", "length"=>length(x)) :
    Dict{String,Any}("kind"=>x === nothing ? "missing" : x isa Number ? "scalar" : "invalid")

function _index_roles(net)
    tc = get(net, "terminal_conventions", nothing)
    if tc isa AbstractDict
        all(k -> _index_strings(get(tc,k,String[])), ("phase","neutral","earth")) || return nothing
    elseif haskey(net,"terminal_conventions")
        return nothing
    end
    buses = get(net,"bus",Dict())
    all(b -> b isa Dict && _index_strings(get(b,"terminal_names",String[])), values(buses)) || return nothing
    _terminal_roles(net)
end

function _index_bus_neutral(net, bid, roles=_index_roles(net))
    roles === nothing && return nothing
    b = get(get(net,"bus",Dict()),bid,nothing)
    b isa Dict || return nothing
    # A materialized field may help legacy callers; explicit conventions win.
    roles.inferred && get(b,"neutral_terminal",nothing) isa String &&
        return b["neutral_terminal"]
    names = get(b,"terminal_names",String[])
    _index_strings(names) || return nothing
    ns = [t for t in names if t in roles.neutral]
    length(ns)==1 ? only(ns) : nothing
end

function _device_index_context(net, kind, id, c; roles=_index_roles(net))
    bid = kind=="bus" ? id : get(c,"bus",nothing)
    tm = get(c,kind=="bus" ? "terminal_names" : "terminal_map",nothing)
    topology = kind=="ibr" ? get(c,"topology","FOUR_LEG") :
        kind=="bus" ? "BUS" : get(c,"configuration","WYE")
    evidence = Dict{String,Any}("bus"=>bid,"topology"=>topology,
        "field"=>kind=="bus" ? "terminal_names" : "terminal_map",
        "indexing_domain"=>"connection_terminals","observed_shape"=>_index_shape(tm),
        "terminal_map"=>tm,"map_positions"=>_index_strings(tm) ? collect(eachindex(tm)) : Int[],
        "resolved_roles"=>String[], "role_source"=>roles===nothing ? "invalid" :
            roles.inferred ? "inferred" : "declared", "knowledge_ids"=>["PSK-000002"])
    b = get(get(net,"bus",Dict()),bid,nothing)
    reason = if !_index_strings(tm)
        "terminal_map_shape"
    elseif !(b isa Dict)
        "unknown_bus"
    elseif roles===nothing
        "role_declaration_shape"
    else
        nn = _index_bus_neutral(net,bid,roles)
        rs = map(tm) do t
            matches = [r for (r,s) in (("phase",roles.phase),("neutral",roles.neutral),("earth",roles.earth)) if t in s]
            roles.inferred && t==nn && return "neutral"
            length(matches)==1 ? only(matches) : isempty(matches) ? "unclassified" : "ambiguous"
        end
        evidence["resolved_roles"] = rs
        if any(t -> !(t in get(b,"terminal_names",String[])),tm)
            "unknown_terminal"
        elseif any(r -> r in ("ambiguous","unclassified"),rs)
            "unresolved_roles"
        elseif count(t -> t in roles.neutral,get(b,"terminal_names",String[])) > 1
            "multiple_bus_neutrals"
        elseif "earth" in rs
            "unsupported_earth_conductor"
        else
            nothing
        end
    end
    evidence["status"] = reason===nothing ? "assessed" : "indeterminate"
    evidence["reason"] = reason
    reason===nothing || return (n=nothing, neutral=false, domain="unassessed", evidence=evidence)
    rs=evidence["resolved_roles"]; np=count(==("phase"),rs); nn=count(==("neutral"),rs)
    n, domain = if kind=="bus"
        (np,"phase")
    elseif kind=="voltage_source"
        (topology in ("WYE","SINGLE_PHASE") ? np : nothing,"phase")
    elseif topology=="SINGLE_PHASE" && length(tm)==2
        (1,"terminal_pair")
    elseif topology in ("DELTA","THREE_LEG")
        (kind=="load" && length(tm)==2 ? 1 : length(tm), "cyclic_coil")
    elseif topology in ("WYE","FOUR_LEG")
        (np,"phase_to_reference")
    else
        (nothing,"unassessed")
    end
    evidence["n_phase"] = n
    (n=n, neutral=nn>0, domain=domain, evidence=evidence)
end

function _index_field!(findings, kind, id, c, ctx, field, lengths;
                       scalar=false, code="W.INT.DIM_MISMATCH", section=:integrity,
                       severity=WARNING, domain=ctx.domain, required=false)
    v=get(c,field,nothing)
    v===nothing && !required && return 0
    allowed=sort!(unique(collect(lengths)))
    valid=(_index_numbers(v) && length(v) in allowed) || (scalar && _index_number(v))
    valid && return 0
    d=merge(ctx.evidence,Dict{String,Any}("field"=>field,"indexing_domain"=>domain,
        "expected_lengths"=>allowed,"scalar_allowed"=>scalar,"observed_shape"=>_index_shape(v)))
    push!(findings,Finding(severity,code,section,Symbol(kind),id,
        "$kind '$id': $field does not match the $domain indexing contract.",d))
    1
end

function _check_device_dimensions!(net, findings)
    roles=_index_roles(net); count_issues=0
    for kind in ("load","generator","ibr","voltage_source","bus")
        for (id,c) in get(net,kind,Dict())
            c isa Dict || continue
            ctx=_device_index_context(net,kind,id,c;roles)
            if ctx.evidence["reason"]!==nothing
                # Reference/declaration errors retain their existing owners. This
                # records the consequence for indexing, rather than guessing.
                push!(findings,Finding(WARNING,"W.INT.DEVICE_INDEXING_UNASSESSED",:integrity,
                    Symbol(kind),id,"$kind '$id': device indexing cannot be assessed.",ctx.evidence))
                continue
            end
            n=ctx.n; n===nothing && continue
            if kind=="load"
                for field in ("p_nom","q_nom")
                    count_issues+=_index_field!(findings,kind,id,c,ctx,field,[n];required=true)
                end
            elseif kind=="bus"
                for field in ("v_min","v_max","vpn_min","vpn_max","vpp_min","vpp_max")
                    pair=startswith(field,"vpp_")
                    count_issues+=_index_field!(findings,kind,id,c,ctx,field,[pair ? n*(n-1)÷2 : n];
                        domain=pair ? "unordered_phase_pair" : "phase")
                end
                if !ctx.neutral && any(f -> haskey(c,f),("vpn_min","vpn_max"))
                    push!(findings,Finding(WARNING,"W.INT.DEVICE_INDEXING_UNASSESSED",:integrity,:bus,id,
                        "Bus '$id': phase-to-neutral bounds lack an identified neutral reference.",
                        merge(ctx.evidence,Dict{String,Any}("status"=>"indeterminate",
                            "reason"=>"vpn_reference_missing","fields"=>[f for f in ("vpn_min","vpn_max") if haskey(c,f)]))))
                end
            else
                for field in ("p_min","p_max","q_min","q_max","s_max","cost")
                    kind=="voltage_source" && field=="s_max" && continue
                    count_issues+=_index_field!(findings,kind,id,c,ctx,field,field=="cost" ? [n] : [0,n])
                end
                if kind=="ibr"
                    for field in ("r_filter","x_filter")
                        count_issues+=_index_field!(findings,kind,id,c,ctx,field,[n])
                    end
                    if haskey(c,"p_avail") && !_index_number(c["p_avail"])
                        count_issues+=_index_field!(findings,kind,id,c,ctx,"p_avail",Int[];
                            scalar=true,domain="device_total")
                    end
                end
                if kind in ("generator","ibr")
                    pair=ctx.domain=="terminal_pair"
                    sizes=pair ? [0,1,2] : ctx.neutral ? [0,n,n+1] : [0,n]
                    count_issues+=_index_field!(findings,kind,id,c,ctx,"i_max",sizes;
                        domain=pair ? "pair_conductors_same_current" : ctx.neutral ? "phases_then_neutral" : ctx.domain)
                    v=get(c,"i_max",nothing)
                    if !pair && ctx.neutral && n>1 && _index_numbers(v) && length(v)==n
                        push!(findings,Finding(WARNING,"W.INT.IMAX_NO_NEUTRAL",:integrity,Symbol(kind),id,
                            "$kind '$id': i_max omits the neutral return rating.",
                            merge(ctx.evidence,Dict{String,Any}("field"=>"i_max","indexing_domain"=>"phases_then_neutral",
                                "observed_shape"=>_index_shape(v),"expected_lengths"=>[n,n+1]))))
                    end
                else
                    tm=c["terminal_map"]; b=net["bus"][c["bus"]]
                    grounded=get(b,"perfectly_grounded_terminals",String[])
                    grounded isa AbstractVector || (grounded=String[])
                    sizes=[k for k in 0:length(tm) if all(t -> t in grounded,tm[k+1:end])]
                    for field in ("v_magnitude","v_angle")
                        count_issues+=_index_field!(findings,kind,id,c,ctx,field,sizes;
                            domain="terminal_reference_prefix",required=true)
                    end
                    vm=get(c,"v_magnitude",nothing); va=get(c,"v_angle",nothing)
                    if _index_numbers(vm) && _index_numbers(va) && length(vm) in sizes &&
                        length(va) in sizes && length(vm)!=length(va)
                        # Each individually admissible prefix still needs its mate.
                        count_issues+=_index_field!(findings,kind,id,c,ctx,"v_angle",[length(vm)];
                            domain="matching_reference_prefix")
                    end
                end
            end
        end
    end
    count_issues
end

# Existing load-model Finding classes retain ownership of coefficient shapes.
function _check_load_index_fields!(net,id,load,findings; ctx=_device_index_context(net,"load",id,load))
    ctx.n===nothing && return false
    n=ctx.n; model=get(load,"model","constant_power"); issues=0
    model=="constant_power" && return true
    if get(load,"v_nom",nothing)!==nothing
        issues+=_index_field!(findings,"load",id,load,ctx,"v_nom",[1,n];scalar=true,
            code="E.LOAD.VNOM_ARITY",section=:domain_rules,severity=ERROR)
    end
    fields=model=="zip" ? ("alpha_z","alpha_i","alpha_p","beta_z","beta_i","beta_p") :
        model=="exponential" ? ("gamma_p","gamma_q") : ()
    for field in fields
        issues+=_index_field!(findings,"load",id,load,ctx,field,[1,n];scalar=true,
            code=model=="zip" ? "E.LOAD.ZIP_ARITY" : "E.LOAD.EXP_ARITY",section=:domain_rules,severity=ERROR)
    end
    issues==0
end
