# PSK-000013: a nominal-demand screen, never a solved-network witness.
# Restrict allocation to an explicitly mapped, single-bank, rooted tree.
_preflight_finite(x) = x isa Real && !(x isa Bool) && isfinite(x)

function _coil_preflight_estimate(net, tid, xf)
    reject(reason; status="inapplicable", context=Dict{String,Any}()) =
        Dict{String,Any}("transformer"=>tid,"status"=>status,"reason"=>reason,
            "context"=>context,"coils"=>Any[])
    buses = get(net,"bus",Dict())
    sources = get(net,"voltage_source",Dict())
    length(sources)==1 || return reject("requires_one_voltage_source")
    for kind in ("generator","ibr","shunt","capacitor","control_profile",
                 "dc_bus","dc_branch","dc_grounding","dc_load","dc_source")
        isempty(get(net,kind,Dict())) || return reject("unsupported_component";
            context=Dict("collection"=>kind))
    end
    any(haskey(xf,k) for k in ("tap_min","tap_max","control","control_mode","control_profile")) &&
        return reject("tap_or_control_decision")
    tap = get(xf,"tap",1.0)
    _preflight_finite(tap) && tap>0 || return reject("invalid_fixed_tap";status="indeterminate")
    cap = get(xf,"s_rating",nothing)
    _preflight_finite(cap) && cap>0 || return reject("missing_or_invalid_positive_rating";status="indeterminate")
    roles = _terminal_roles(net)
    isempty(intersect(roles.phase,roles.neutral)) &&
        isempty(intersect(union(roles.phase,roles.neutral),roles.earth)) ||
        return reject("ambiguous_terminal_roles";status="indeterminate")
    # A phase allocation uses only explicit ordered maps; label equality across
    # buses is never used as a replacement for a missing map.
    validmap(bus, tm) = haskey(buses,bus) && tm isa AbstractVector && !isempty(tm) &&
        all(t -> t isa AbstractString,tm) && length(unique(tm))==length(tm) &&
        all(t -> t in get(buses[bus],"terminal_names",[]),tm) &&
        all(t -> t in union(roles.phase,roles.neutral),tm)
    neutral(tm) = [t for t in tm if t in roles.neutral]
    for (bid,bus) in buses
        tm=get(bus,"terminal_names",nothing)
        validmap(bid,tm) && length(neutral(tm))==1 ||
            return reject("ambiguous_bus_terminals";status="indeterminate",context=Dict("bus"=>bid))
    end
    sid,source = only(collect(sources))
    root=get(source,"bus",nothing); stm=get(source,"terminal_map",nothing)
    validmap(root,stm) && all(t -> t in roles.phase,stm) ||
        return reject("invalid_source_map";status="indeterminate")
    vm=get(source,"v_magnitude",nothing); va=get(source,"v_angle",nothing)
    vm isa AbstractVector && va isa AbstractVector && length(vm)==length(va)==length(stm) &&
        all(v -> _preflight_finite(v) && v>0,vm) && all(_preflight_finite,va) ||
        return reject("invalid_source_setpoint";status="indeterminate")

    edges=NamedTuple[]
    for kind in ("line","switch","transformer")
        devices = kind=="transformer" ? Dict(tid=>xf) : get(net,kind,Dict())
        for id in sort!(collect(keys(devices)))
            d=devices[id]
            if kind=="switch"
                state=get(d,"open_switch",false)
                state isa Bool || return reject("invalid_switch_state";status="indeterminate")
                state && continue
            end
            f=get(d,"bus_from",nothing); t=get(d,"bus_to",nothing)
            fm=get(d,"terminal_map_from",nothing); tm=get(d,"terminal_map_to",nothing)
            validmap(f,fm) && validmap(t,tm) && length(fm)==length(tm) &&
                length(neutral(fm))==length(neutral(tm))==1 &&
                all((a in roles.neutral)==(b in roles.neutral) for (a,b) in zip(fm,tm)) ||
                return reject("invalid_branch_map";status="indeterminate",
                    context=Dict("collection"=>kind,"id"=>id))
            push!(edges,(;kind,id,f,t,fm,tm))
        end
    end
    adj=Dict(b=>Int[] for b in keys(buses))
    for (i,e) in enumerate(edges)
        push!(adj[e.f],i); push!(adj[e.t],i)
    end
    # Reject cycles (including parallel branches), disconnected islands and
    # reverse-fed transformers before using any allocation.
    maps=Dict(root=>Dict(t=>t for t in stm))
    maps[root][only(neutral(buses[root]["terminal_names"]))]="__neutral__"
    parent_edge=Dict(root=>0); downstream=Dict(root=>false)
    paths=Dict(root=>String[]); queue=[root]; coil_source=String[]
    while !isempty(queue)
        b=popfirst!(queue)
        for i in adj[b]
            i==parent_edge[b] && continue
            e=edges[i]; forward=e.f==b
            nb=forward ? e.t : e.f
            haskey(parent_edge,nb) && return reject("meshed_or_parallel_supply_paths")
            e.kind=="transformer" && !forward && return reject("reverse_fed_transformer")
            fm,tm=forward ? (e.fm,e.tm) : (e.tm,e.fm)
            all(t -> haskey(maps[b],t),fm) || return reject("terminal_not_supplied";
                status="indeterminate",context=Dict("collection"=>e.kind,"id"=>e.id))
            maps[nb]=Dict(t=>maps[b][f] for (f,t) in zip(fm,tm))
            parent_edge[nb]=i; downstream[nb]=downstream[b] || e.kind=="transformer"
            paths[nb]=vcat(paths[b],["$(e.kind).$(e.id)"])
            if e.kind=="transformer"
                coil_source=[maps[b][t] for t in fm if t in roles.phase]
            end
            push!(queue,nb)
        end
    end
    length(parent_edge)==length(buses) || return reject("disconnected_network")
    isempty(coil_source) && return reject("no_phase_coils";status="indeterminate")
    n=length(coil_source); p=zeros(n); q=zeros(n)
    contributions=[Dict{String,Any}[] for _ in 1:n]
    for lid in sort!(collect(keys(get(net,"load",Dict()))))
        load=net["load"][lid]; b=get(load,"bus",nothing)
        haskey(downstream,b) || return reject("invalid_load_bus";status="indeterminate",context=Dict("load"=>lid))
        downstream[b] || continue
        tm=get(load,"terminal_map",nothing); cfg=get(load,"configuration","WYE")
        model=get(load,"model","constant_power")
        cfg in ("SINGLE_PHASE","WYE") && model in ("constant_power","constant_current","constant_impedance") ||
            return reject("unsupported_load_model_or_connection";context=Dict("load"=>lid))
        validmap(b,tm) && length(neutral(tm))==1 &&
            all(t -> haskey(maps[b],t),tm) &&
            (cfg!="SINGLE_PHASE" || length(tm)==2) ||
            return reject("ambiguous_load_map";status="indeterminate",context=Dict("load"=>lid))
        phases=[t for t in tm if t in roles.phase]
        ps=get(load,"p_nom",nothing); qs=get(load,"q_nom",nothing)
        ps isa AbstractVector && qs isa AbstractVector && !isempty(phases) &&
            length(ps)==length(qs)==length(phases) &&
            all(v -> _preflight_finite(v) && v>=0,ps) && all(_preflight_finite,qs) ||
            return reject("invalid_or_negative_nominal_demand";status="indeterminate",context=Dict("load"=>lid))
        volts=get(load,"v_nom",nothing)
        if model!="constant_power" || volts!==nothing
            volts isa AbstractVector && length(volts)==length(phases) &&
                all(v -> _preflight_finite(v) && v>0,volts) ||
                return reject("invalid_load_nominal_voltage";status="indeterminate",context=Dict("load"=>lid))
        end
        for (j,t) in enumerate(phases)
            k=findfirst(==(maps[b][t]),coil_source)
            k===nothing && return reject("load_not_mapped_to_coil";status="indeterminate",context=Dict("load"=>lid))
            p[k]+=Float64(ps[j]); q[k]+=Float64(qs[j])
            push!(contributions[k],Dict("load"=>lid,"load_coil"=>j,"bus"=>b,
                "terminals"=>[t,only(neutral(tm))],"model"=>model,
                "p_nom_W"=>ps[j],"q_nom_var"=>qs[j],
                "v_nom_V"=>volts===nothing ? nothing : volts[j],"source_path"=>paths[b]))
        end
    end
    caps=Float64(cap)/n; apparent=hypot.(p,q)
    all(isfinite,vcat(p,q,apparent,[sum(apparent),caps])) && caps>0 && all(isfinite,apparent./caps) ||
        return reject("nonfinite_estimate";status="indeterminate")
    fr=[t for t in xf["terminal_map_from"] if t in roles.phase]
    to=[t for t in xf["terminal_map_to"] if t in roles.phase]
    rows=[Dict{String,Any}("side"=>"fr","coil"=>string(k),"source_terminal"=>coil_source[k],
        "from_terminals"=>[fr[k],only(neutral(xf["terminal_map_from"]))],
        "to_terminals"=>[to[k],only(neutral(xf["terminal_map_to"]))],
        "p_nom_W"=>p[k],"q_nom_var"=>q[k],"s_nom_VA"=>apparent[k],
        "cap_VA"=>caps,"headroom_VA"=>caps-apparent[k],"utilization"=>apparent[k]/caps,
        "comparison_status"=>apparent[k]>caps ? "negative_nominal_headroom" :
            apparent[k]==caps ? "at_nominal_cap" : "positive_nominal_headroom",
        "contributions"=>contributions[k]) for k in 1:n]
    Dict{String,Any}("transformer"=>tid,"status"=>"estimated","reason"=>nothing,
        "source"=>sid,"terminal_roles"=>roles.inferred ? "case_naming_convention" : "declared",
        "cap_provenance"=>"single_phase.s_rating / explicitly_mapped_phase_neutral_coil_count",
        "bank_s_sum_VA"=>sum(apparent),"bank_cap_VA"=>Float64(cap),
        "bank_utilization"=>sum(apparent)/Float64(cap),"coils"=>rows)
end

function _transformer_headroom_preflight(net, findings)
    entries=Dict{String,Any}[]
    transformers=get(net,"transformer",Dict())
    count=sum(length(devices) for devices in values(transformers);init=0)
    for subtype in sort!(collect(keys(transformers))), tid in sort!(collect(keys(transformers[subtype])))
        reason = count!=1 ? "requires_one_transformer_bank" :
            subtype!="single_phase" ? "unsupported_transformer_subtype" : nothing
        entry = reason===nothing ? _coil_preflight_estimate(net,tid,transformers[subtype][tid]) :
            Dict{String,Any}("transformer"=>tid,"status"=>"inapplicable","reason"=>reason,"coils"=>Any[])
        entry["subtype"]=subtype
        if entry["status"]=="estimated"
            for row in entry["coils"]
                row["headroom_VA"]<0 || continue
                push!(findings,Finding(WARNING,"W.PRE.XFMR_COIL_HEADROOM",:preflight,:transformer,tid,
                    "Transformer '$tid' coil $(row["coil"]) has negative nominal-demand headroom; this is a screening warning, not an infeasibility certificate.",
                    Dict{String,Any}("evidence"=>"nominal_demand_estimate","coil"=>row["coil"],
                        "side"=>"fr","s_nom_VA"=>row["s_nom_VA"],"cap_VA"=>row["cap_VA"],
                        "headroom_VA"=>row["headroom_VA"])))
            end
        else
            push!(findings,Finding(INFO,"I.PRE.XFMR_COIL_UNASSESSED",:preflight,:transformer,tid,
                "Transformer '$tid' nominal coil headroom is unassessed: $(entry["reason"]).",
                Dict{String,Any}("status"=>entry["status"],"reason"=>entry["reason"],
                    "context"=>get(entry,"context",Dict{String,Any}()))))
        end
        push!(entries,entry)
    end
    Dict{String,Any}("evidence"=>"nominal_demand_estimate","knowledge_ids"=>["PSK-000013"],
        "scope"=>"connected_radial_single_source_single_phase_bank",
        "proves_feasibility"=>false,"proves_infeasibility"=>false,"solver_run"=>false,
        "assumptions"=>Dict("voltage"=>"each load evaluated at its own nominal voltage; no voltage-drop calculation",
            "losses"=>"line and transformer losses, charging and magnetizing demand omitted",
            "reactive_power"=>"signed nominal Q summed per coil before hypot(P,Q)",
            "generation"=>"local generation, IBRs and compensation excluded",
            "phase_coupling"=>"phase-to-phase loads excluded; mutual coupling and neutral displacement omitted",
            "alternative_supply"=>"meshes, islands, multiple sources and multiple transformer banks excluded",
            "limits"=>"nameplate VA only; current, voltage and source limits unassessed"),
        "transformers"=>entries)
end
