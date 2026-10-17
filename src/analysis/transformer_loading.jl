# Supplied-result diagnostics (PSK-000013). No solver, rating inference, or
# independent electrical reconstruction is performed here.
_coil_number(x) = x isa Real && !(x isa Bool) && isfinite(x) && x >= 0 ? Float64(x) : nothing

# Enumerate native nameplate result slots, not every conductor-current slot.
# Caps themselves always come from supplied s_max; never divide a bank rating.
function _transformer_coil_slots(net, subtype, xf)
    slots = NamedTuple[]
    add(side, k, bus, terminals) = push!(slots, (; side, coil=string(k), bus, terminals))
    nlabels = _neutral_labels(net)
    if subtype == "n_winding"
        raw = get(xf, "windings", nothing)
        raw isa AbstractVector && !isempty(raw) && all(w -> w isa AbstractDict, raw) ||
            return slots, "invalid_winding_list"
        # Reject malformed entries before the native reader can skip/reindex them.
        counts = Int[]
        for (j,w) in enumerate(_nw_windings(xf))
            ph, nt = _nw_phase_terminals(w.terminal_map)
            !isempty(ph) && w.connection in ("WYE","DELTA") &&
                length(unique(w.terminal_map))==length(w.terminal_map) &&
                length(ph)+(nt===nothing ? 0 : 1)==length(w.terminal_map) ||
                return NamedTuple[], "unsupported_winding_map"
            push!(counts,length(ph))
            for k in eachindex(ph)
                other = w.connection == "DELTA" ? ph[_nw_delta_other(k,length(ph),w.delta_roll)] : nt
                add("w$j",k,w.bus,[ph[k],other])
            end
        end
        length(unique(counts))==1 || return NamedTuple[], "unequal_winding_phase_counts"
    elseif subtype in ("single_phase","single_phase_autotransformer","center_tap",
                       "wye_delta","delta_wye","open_delta_regulator")
        side = subtype == "delta_wye" ? "to" : "fr"
        suffix = side == "fr" ? "from" : "to"
        tm = get(xf,"terminal_map_$suffix",nothing)
        tm isa AbstractVector && !isempty(tm) && all(t -> t isa AbstractString,tm) &&
            length(unique(tm)) == length(tm) || return slots,"invalid_terminal_map"
        bus = get(xf,"bus_$suffix",nothing)
        if subtype in ("single_phase","single_phase_autotransformer")
            other = get(xf,"terminal_map_to",nothing)
            other isa AbstractVector || return slots,"invalid_terminal_map"
            pairs = _xfmr_winding_pairs(tm,nlabels)
            length(pairs)==length(_xfmr_winding_pairs(other,nlabels)) || return slots,"unequal_winding_counts"
            subtype=="single_phase_autotransformer" && length(pairs)!=1 && return slots,"unsupported_regulator_map"
            for (k,(p,q)) in enumerate(pairs)
                add(side,k,bus,[tm[p],q === nothing ? nothing : tm[q]])
            end
        elseif subtype == "center_tap"
            length(tm) == 2 && length(get(xf,"terminal_map_to",[]))==3 || return slots,"invalid_terminal_map"
            add(side,1,bus,collect(tm))
        elseif subtype in ("wye_delta","delta_wye")
            nt = _neutral_pos(tm,nlabels)
            for k in _phase_positions(tm,nlabels)
                add(side,k,bus,[tm[k],nt === nothing ? nothing : tm[nt]])
            end
        else
            pairs = get(_OPEN_DELTA_YPRIM_PAIRS,uppercase(strip(string(get(xf,"connection","")))),nothing)
            pairs === nothing && return slots,"unsupported_regulator_connection"
            ph = _phase_positions(tm,nlabels)
            length(ph) == 3 || return slots,"invalid_terminal_map"
            for (k,(p,q)) in enumerate(pairs)
                add(side,k,bus,[tm[ph[p]],tm[ph[q]]])
            end
        end
    else
        return slots,"unsupported_transformer_subtype"
    end
    return slots,nothing
end

function _transformer_loading_summary(net, result, solution, findings)
    status = get(solution,"termination_status","UNKNOWN")
    primal = get(solution,"primal_status",nothing)
    count = get(result,"result_count",nothing)
    no_candidate = (count isa Integer && count == 0) ||
        (primal !== nothing && !(primal in ("FEASIBLE_POINT","NEARLY_FEASIBLE_POINT",
                                          "ALMOST_FEASIBLE_POINT","INFEASIBLE_POINT")))
    claimed = get(solution,"solver_claimed_feasible",false) === true
    failed = status in ("LOCALLY_INFEASIBLE","INFEASIBLE","NUMERICAL_ERROR","INVALID_MODEL","OTHER_ERROR")
    evidence = no_candidate ? "no_candidate" : claimed && !failed ? "supplied_feasible_candidate" :
        claimed && failed ? "diagnostic_candidate" :
        primal == "INFEASIBLE_POINT" ? "diagnostic_candidate" : "no_candidate"
    rows = Dict{String,Any}[]
    groups = Dict{String,Any}[]
    unassessed = Dict{String,Any}[]
    result_xf = get(result,"transformer",Dict())
    result_xf isa AbstractDict || (result_xf = Dict())
    seen = Set{String}()
    for subtype in sort!(collect(keys(get(net,"transformer",Dict()))))
        devices = net["transformer"][subtype]
        devices isa AbstractDict || continue
        for tid in sort!(collect(keys(devices)))
            push!(seen,tid)
            xf = devices[tid]
            slots,reason = if xf isa AbstractDict
                try
                    _transformer_coil_slots(net,subtype,Dict{String,Any}(xf))
                catch e
                    e isa Union{ArgumentError,MethodError,BoundsError,InexactError} || rethrow()
                    (NamedTuple[],"invalid_transformer_mapping")
                end
            else
                (NamedTuple[],"invalid_transformer_record")
            end
            if reason !== nothing || isempty(slots)
                push!(unassessed,Dict("transformer"=>tid,"subtype"=>subtype,
                    "reason"=>something(reason,"no_coil_slots")))
            end
            rec = get(result_xf,tid,Dict())
            rec isa AbstractDict || (rec=Dict())
            expected = Set((s.side,s.coil) for s in slots)
            for (side,sr) in rec
                sr isa AbstractDict || continue
                for (k,v) in sr
                    v isa AbstractDict && (haskey(v,"s") || haskey(v,"s_max")) || continue
                    (side,k) in expected && continue
                    push!(unassessed,Dict("transformer"=>tid,"subtype"=>subtype,
                        "side"=>side,"coil"=>k,"reason"=>"unrecognized_result_slot"))
                end
            end
            local_rows = Dict{String,Any}[]
            for slot in slots
                sr = get(rec,slot.side,Dict())
                v = sr isa AbstractDict ? get(sr,slot.coil,Dict()) : Dict()
                v isa AbstractDict || (v=Dict())
                s = _coil_number(get(v,"s",nothing))
                cap = _coil_number(get(v,"s_max",nothing))
                missing = ["transformer.$tid.$(slot.side).$(slot.coil).$f"
                           for f in ("s","s_max") if _coil_number(get(v,f,nothing)) === nothing]
                codes = sort!(unique([f.code for f in findings if
                    f.component_type == :transformer && f.component_id == tid &&
                    f.code in ("E.SOL.THERMAL_VIOLATION","W.SOL.THERMAL_ACTIVE") &&
                    get(f.detail,"side",nothing) == slot.side &&
                    get(f.detail,"winding",nothing) == slot.coil && haskey(f.detail,"s_max")]))
                assessed = evidence == "supplied_feasible_candidate" && isempty(missing)
                comparison = !assessed ? "unassessed" : "E.SOL.THERMAL_VIOLATION" in codes ?
                    "violation" : "W.SOL.THERMAL_ACTIVE" in codes ? "active" : "within_reported_cap"
                row = Dict{String,Any}("transformer"=>tid,"subtype"=>subtype,
                    "side"=>slot.side,"coil"=>slot.coil,"bus"=>slot.bus,"terminals"=>slot.terminals,
                    "evidence"=>"supplied_s_and_s_max","candidate_status"=>evidence,
                    "s_VA"=>s,"cap_VA"=>cap,
                    "utilization"=>s !== nothing && cap !== nothing && cap > 0 ? s/cap : nothing,
                    "headroom_VA"=>s !== nothing && cap !== nothing ? cap-s : nothing,
                    "comparison_status"=>comparison,"finding_codes"=>codes,
                    "missing_or_invalid_fields"=>missing,
                    "unassessed_reason"=>!isempty(missing) ? "missing_or_invalid_coil_data" :
                        !assessed ? evidence : nothing)
                push!(rows,row); push!(local_rows,row)
            end
            # Group by constrained side/winding. Summing both ends would double
            # count throughput. Sum of |S| is not magnitude of net complex power.
            for side in sort!(unique([r["side"] for r in local_rows]))
                rs = filter(r -> r["side"] == side,local_rows)
                complete = all(r -> isempty(r["missing_or_invalid_fields"]),rs)
                total = complete ? sum(r["s_VA"] for r in rs) : nothing
                cap = complete ? sum(r["cap_VA"] for r in rs) : nothing
                utils = [r["utilization"] for r in rs if r["utilization"] !== nothing]
                push!(groups,Dict{String,Any}("transformer"=>tid,"subtype"=>subtype,"side"=>side,
                    "candidate_status"=>evidence,"complete"=>complete,"expected_coils"=>length(rs),
                    "s_sum_VA"=>total,"cap_sum_VA"=>cap,
                    "utilization"=>complete && cap > 0 ? total/cap : nothing,
                    "headroom_VA"=>complete ? cap-total : nothing,
                    "max_coil_utilization"=>complete && length(utils)==length(rs) ? maximum(utils) : nothing))
            end
        end
    end
    for tid in sort!(collect(setdiff(Set(keys(result_xf)),seen)))
        push!(unassessed,Dict("transformer"=>tid,"reason"=>"transformer_absent_from_case"))
    end
    Dict{String,Any}("evidence"=>"supplied_result","termination_status"=>status,
        "primal_status"=>primal,"result_count"=>count,"candidate_status"=>evidence,
        "independently_reconstructed"=>false,"case_result_provenance_authenticated"=>false,
        "aggregation"=>"sum_of_coil_apparent_magnitudes_per_constrained_side",
        "coils"=>rows,"groups"=>groups,"unassessed"=>unassessed)
end
