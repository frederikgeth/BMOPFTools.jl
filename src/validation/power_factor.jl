# Package-owned minimum-PF policy in the schema's free-form extras escape hatch.
# PSK-000013: supplied-result checks are evidence, not a feasibility certificate.
_pf_finite(x) = x isa Real && !(x isa Bool) && isfinite(x)
function _constant_pf_value(cp)
    cp isa AbstractDict && haskey(cp,"power_factor") || return nothing
    obj=cp["power_factor"]
    raw=obj isa AbstractDict ? get(obj,"pf",nothing) : nothing
    _pf_finite(raw) && 0 < abs(raw) <= 1 && Float64(abs(raw)) > 0 ||
        throw(ArgumentError("constant power_factor.pf must be finite with 0 < abs(pf) <= 1"))
    Float64(raw)
end

# Do not let the legacy droop resolver's warn-and-skip fallback silently remove
# a requested control when it is combined with the new minimum-PF policy.
function _minimum_pf_droop_supported(cp,inv,n)
    for (law,size,limkey,unitkey,refkey,defaultref) in (
        ("volt_var",4,"q_limits","q_unit","q_ref","VAR_MAX"),
        ("volt_watt",2,"p_limits","p_unit","p_ref","S_MAX"))
        haskey(cp,law) || continue
        obj=cp[law]
        obj isa AbstractDict || return false
        issubset(Set(keys(obj)),Set(["breakpoints",limkey,unitkey,refkey,"voltage_reference"])) || return false
        bps=get(obj,"breakpoints",nothing); lim=get(obj,limkey,nothing)
        bps isa AbstractVector && length(bps)==size && all(x->_pf_finite(x) && x>0,bps) &&
            all(bps[i]<bps[i+1] for i in 1:size-1) || return false
        lim isa AbstractVector && length(lim)==2 && all(_pf_finite,lim) || return false
        (law=="volt_var" ? lim[1]<=0<=lim[2] : 0<=lim[1]<=lim[2]) || return false
        get(obj,unitkey,"VA_FRACTION")=="VA_FRACTION" || return false
        get(obj,"voltage_reference","PN_PER_PHASE") in
            ("PN_PER_PHASE","PG_PER_PHASE","PP_PER_PHASE","PN_AVERAGED","PG_AVERAGED","PP_AVERAGED") || return false
        ref=get(obj,refkey,defaultref)
        ref in (law=="volt_var" ? ("VAR_MAX",) : ("S_MAX","P_MAX","P_AVAILABLE")) || return false
        if ref=="P_AVAILABLE"
            pa=get(inv,"p_avail",nothing)
            _pf_finite(pa) && pa>=0 || return false
        else
            values=get(inv,ref=="P_MAX" ? "p_max" : "s_max",nothing)
            values isa AbstractVector && length(values)==n && all(x->_pf_finite(x) && x>=0,values) || return false
        end
    end
    get(inv,"voltage_aggregation","PER_PHASE") in ("PER_PHASE","AVERAGE")
end

# Return validated policies plus structured errors, so analysis can explain a
# request that the model builder must reject. No policy is silently discarded.
function _minimum_pf_configuration(net)
    policies=Dict{String,Any}(); errors=Dict{String,Any}[]
    bad(id,reason)=push!(errors,Dict{String,Any}("ibr"=>id,"reason"=>reason))
    extras=get(net,"extras",Dict())
    extras isa AbstractDict || return policies,errors
    package=get(extras,"bmopftools",Dict())
    package isa AbstractDict || (bad(nothing,"invalid_package_namespace"); return policies,errors)
    haskey(package,"minimum_power_factor") || return policies,errors
    spec=package["minimum_power_factor"]
    if !(spec isa AbstractDict) || get(spec,"schema",nothing)!="bmopftools.minimum_power_factor/v1"
        bad(nothing,"unsupported_policy_schema"); return policies,errors
    end
    if Set(keys(spec)) != Set(["schema","ibr"]) || !(spec["ibr"] isa AbstractDict)
        bad(nothing,"invalid_policy_fields"); return policies,errors
    end
    for id in sort!(collect(keys(spec["ibr"])))
        req=spec["ibr"][id]; inv=get(get(net,"ibr",Dict()),id,nothing)
        if !(inv isa AbstractDict)
            bad(id,"unknown_inverter"); continue
        end
        if !(req isa AbstractDict) || Set(keys(req))!=Set(["pf_min","direction","scope"])
            bad(id,"invalid_request_fields"); continue
        end
        pf=req["pf_min"]
        if !(_pf_finite(pf) && 0 < pf <= 1 && Float64(pf)>0)
            bad(id,"invalid_minimum_pf"); continue
        end
        if req["direction"]!="generation" || req["scope"]!="per_coil"
            bad(id,"unsupported_direction_or_scope"); continue
        end
        if haskey(inv,"dc_bus") || get(inv,"dc_link_coupled",false)!==false
            bad(id,"dc_coupling_not_supported"); continue
        end
        tm=get(inv,"terminal_map",nothing); topo=get(inv,"topology","FOUR_LEG")
        roles=_terminal_roles(net); bus=get(get(net,"bus",Dict()),get(inv,"bus",nothing),Dict())
        if !(tm isa AbstractVector) || !all(t->t isa AbstractString,tm) ||
           length(unique(tm))!=length(tm) || !all(t->t in get(bus,"terminal_names",[]),tm) ||
           !isempty(intersect(roles.phase,roles.neutral)) ||
           !isempty(intersect(union(roles.phase,roles.neutral),roles.earth)) ||
           !all(t->t in union(roles.phase,roles.neutral),tm)
            bad(id,"ambiguous_coil_mapping"); continue
        end
        ph=[t for t in tm if t in roles.phase]; nt=[t for t in tm if t in roles.neutral]
        coilkeys = topo=="SINGLE_PHASE" && length(tm)==2 && !isempty(ph) ? [tm[1]] :
            topo=="FOUR_LEG" && !isempty(ph) && length(nt)==1 ? ph :
            topo=="THREE_LEG" && length(ph)==length(tm)==3 ? tm : nothing
        if coilkeys===nothing
            bad(id,"unsupported_topology_or_mapping"); continue
        end
        pmin=get(inv,"p_min",nothing); pmax=get(inv,"p_max",nothing)
        if !(pmin isa AbstractVector) || length(pmin)!=length(coilkeys) ||
           !all(p->_pf_finite(p) && p>=0,pmin) ||
           (pmax!==nothing && (!(pmax isa AbstractVector) || length(pmax)!=length(coilkeys) ||
                              !all(p->_pf_finite(p) && p>=0,pmax)))
            bad(id,"requires_nonnegative_generation_bounds"); continue
        end
        cp_id=get(inv,"control_profile",nothing)
        cp=cp_id===nothing ? Dict() : get(get(net,"control_profile",Dict()),cp_id,nothing)
        if !(cp isa AbstractDict)
            bad(id,"unresolved_control_profile"); continue
        end
        constant=try _constant_pf_value(cp) catch e
            e isa ArgumentError || rethrow(); bad(id,"invalid_constant_pf"); continue
        end
        if constant!==nothing && abs(constant)<pf
            bad(id,"constant_pf_below_minimum"); continue
        end
        unsupported=setdiff(Set(keys(cp)),Set(["power_factor","volt_var","volt_watt"]))
        droop=haskey(cp,"volt_var") || haskey(cp,"volt_watt")
        if !isempty(unsupported) || (droop && (topo=="THREE_LEG" || constant!==nothing))
            bad(id,"unsupported_control_combination"); continue
        end
        if !_minimum_pf_droop_supported(cp,inv,length(coilkeys))
            bad(id,"unsupported_or_invalid_droop"); continue
        end
        policies[id]=(pf_min=Float64(pf), terminals=String.(coilkeys), topology=topo)
    end
    policies,errors
end

function _power_factor_config_check!(net, findings; strict=false)
    policies,errors=_minimum_pf_configuration(net)
    for (id,cp) in get(net,"control_profile",Dict())
        try
            _constant_pf_value(cp)
        catch e
            e isa ArgumentError || rethrow()
            push!(findings,Finding(ERROR,"E.INT.CONSTANT_PF_INVALID",:integrity,:control_profile,id,
                "Constant PF must be finite and satisfy 0 < abs(pf) <= 1.",
                Dict{String,Any}("reason"=>"invalid_constant_pf")))
            strict && throw(ArgumentError("control_profile '$id': invalid constant PF"))
        end
    end
    for err in errors
        push!(findings,Finding(ERROR,"E.INT.MINIMUM_PF_INVALID",:integrity,:ibr,err["ibr"],
            "Minimum power-factor request is invalid or unsupported: $(err["reason"]).",err))
    end
    strict && !isempty(errors) && throw(ArgumentError("minimum power factor: $(errors)"))
    policies,errors
end

function _minimum_pf_solution_check(net,result,findings;has_candidate)
    policies,errors=_power_factor_config_check!(net,findings)
    rows=Dict{String,Any}[]
    for id in sort!(collect(keys(policies)))
        spec=policies[id]; m=spec.pf_min
        for (k,t) in enumerate(spec.terminals)
            device=get(get(result,"ibr",Dict()),id,Dict())
            raw=device isa AbstractDict ? get(device,t,Dict()) : Dict()
            p=raw isa AbstractDict ? get(raw,"pg",nothing) : nothing
            q=raw isa AbstractDict ? get(raw,"qg",nothing) : nothing
            assessed=has_candidate && _pf_finite(p) && _pf_finite(q) && isempty(errors)
            # Bounded coefficients avoid tan(acos(m)) overflow at tiny m.
            residual=assessed ? (p==0 ? abs(Float64(q)) :
                max(-Float64(p),m*abs(Float64(q))-sqrt((1-m)*(1+m))*Float64(p))) : nothing
            tol=assessed ? max(1e-6,1e-6*max(abs(Float64(p)),abs(Float64(q)))) : nothing
            status=!assessed ? "indeterminate" : residual>tol ? "failed" : "passed"
            reason=!has_candidate ? "no_candidate" : !isempty(errors) ? "invalid_policy" :
                !assessed ? "missing_or_nonfinite_dispatch" : nothing
            detail=Dict{String,Any}("ibr"=>id,"coil"=>k,"terminal"=>t,"topology"=>spec.topology,
                "pf_min"=>m,"scope"=>"per_coil","direction"=>"generation",
                "pg_W"=>_pf_finite(p) ? p : nothing,"qg_var"=>_pf_finite(q) ? q : nothing,
                "status"=>status,"unassessed_reason"=>reason,"residual_VA"=>residual,"tolerance_VA"=>tol,
                "zero_power_policy"=>"Q_zero_at_P_zero")
            push!(rows,detail)
            if status=="failed"
                push!(findings,Finding(ERROR,"E.SOL.IBR_MINIMUM_PF",:solution,:ibr,id,
                    "IBR '$id' coil $k violates its dispatched-power minimum-PF envelope.",detail))
            elseif status=="indeterminate"
                push!(findings,Finding(INFO,"I.SOL.IBR_MINIMUM_PF_UNASSESSED",:solution,:ibr,id,
                    "IBR '$id' coil $k minimum PF is unassessed: $reason.",detail))
            end
        end
    end
    Dict{String,Any}("schema"=>"bmopftools.minimum_power_factor/v1",
        "evidence"=>"supplied_dispatch_against_case_policy","knowledge_ids"=>["PSK-000013"],
        "case_result_provenance_authenticated"=>false,"configuration_errors"=>errors,"coils"=>rows)
end
