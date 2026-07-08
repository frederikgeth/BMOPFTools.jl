# Objective: minimise total generation cost.
#
# `cost` is a per-phase vector of linear coefficients, one element per phase term
# of the element ($/W): the cost of phase k is cost[k] * P_k, where
#   P_k = dvr * cr[k] + dvi * ci[k]
# is the per-phase active power (bilinear in voltage and current).
#
# CONVENTION (uniform across generators, IBRs, AND the voltage source): P_k is the
# active power *injected into the network* by the element — every element stamps
# +I into KCL and reports power as +injection (see generator.jl / source.jl /
# results.jl). A POSITIVE cost therefore minimises that element's injection, and a
# NEGATIVE cost maximises it — identically for all element types. The source is NOT
# a special case: for the slack, +injection means importing from the grid, so a
# positive cost reads as the grid import price (and export, a negative injection,
# is credited at that same price). Maximising system exports = positive slack cost
# with free DERs. Do not flip the sign for the source; the convention is enforced
# by the "uniform cost convention (source ≡ generator)" OPF test.

# Linear cost coefficient for loop position `idx` (1-based). `cost` must be a
# per-phase vector; a scalar (legacy/polynomial form) is rejected.
function _phase_cost(cost, idx::Int, kind::AbstractString, id::AbstractString)::Float64
    cost isa AbstractVector ||
        error("$kind '$id': cost must be a per-phase vector of linear coefficients, got a scalar")
    idx <= length(cost) ||
        error("$kind '$id': cost vector has length $(length(cost)) but phase index $idx requested")
    Float64(cost[idx])
end

"""
    _add_objective!(model, net, vars)

Set the JuMP objective to minimise total active-power generation cost.

The `"cost"` field on generators, the voltage source, and IBRs is a
**per-phase vector of linear coefficients** `[c_1, …, c_nphase]` (\$/W); the
objective contribution of phase `k` is `cost[k]·P_k`.  Costs are linear in the
IVR-EN power expression and added exactly — there is no polynomial/quadratic term.
"""
function _add_objective!(model, net, vars)
    vr = vars[:vr]; vi = vars[:vi]
    crg = vars[:crg]; cig = vars[:cig]
    cri = vars[:cri]; cii = vars[:cii]
    nlabels = BMOPFTools._neutral_labels(net)

    obj = JuMP.QuadExpr()

    for (gid, gen) in get(net, "generator", Dict())
        bus  = get(gen, "bus", "")
        tm   = Vector{String}(get(gen, "terminal_map", String[]))
        cfg  = get(gen, "configuration", "WYE")
        cost = get(gen, "cost", nothing)
        cost === nothing && continue

        ph_pos    = cfg == "DELTA" ? collect(eachindex(tm)) : _phase_positions(tm, nlabels)
        n_pos_idx = cfg == "DELTA" ? nothing : _neutral_pos(tm, nlabels)
        t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing

        for (idx, ph) in enumerate(ph_pos)
            c1   = _phase_cost(cost, idx, "Generator", gid)
            t_ph = tm[ph]
            dvr  = t_n !== nothing ?
                   @expression(model, vr[(bus,t_ph)] - vr[(bus,t_n)]) :
                   vr[(bus, t_ph)]
            dvi  = t_n !== nothing ?
                   @expression(model, vi[(bus,t_ph)] - vi[(bus,t_n)]) :
                   vi[(bus, t_ph)]

            # Linear cost: c1 * (dvr*crg + dvi*cig).
            # dvr/dvi may be VariableRef or AffExpr (when a neutral is in the
            # terminal_map).  The 4-arg add_to_expression! only accepts
            # VariableRef × VariableRef, so we use the (scalar, QuadExpr) form.
            JuMP.add_to_expression!(obj, c1,
                @expression(model, dvr*crg[(gid,idx)] + dvi*cig[(gid,idx)]))
        end
    end

    # ── Voltage-source dispatch cost ─────────────────────────────────────────
    # The source's terminal voltages are fixed, so P_k is linear in cr_src/ci_src
    # (dvr/dvi are constants) and the linear cost term is exact.
    cr_src = vars[:cr_src]; ci_src = vars[:ci_src]
    for (sid, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        bus  = get(vs, "bus", "")
        tm   = Vector{String}(get(vs, "terminal_map", String[]))
        cfg  = get(vs, "configuration", "WYE")
        cost = get(vs, "cost", nothing)
        cost === nothing && continue

        cfg in ("WYE", "SINGLE_PHASE") || continue
        ph_pos    = _phase_positions(tm, nlabels)
        n_pos_idx = _neutral_pos(tm, nlabels)
        t_n = if n_pos_idx !== nothing
            tm[n_pos_idx]
        else
            bt = get(get(net, "bus", Dict()), bus, Dict())
            BMOPFTools._neutral_terminal(bt)
        end

        for (idx, ph) in enumerate(ph_pos)
            c1   = _phase_cost(cost, idx, "Voltage source", sid)
            t_ph = tm[ph]
            dvr = t_n !== nothing ?
                  @expression(model, vr[(bus,t_ph)] - vr[(bus,t_n)]) : vr[(bus,t_ph)]
            dvi = t_n !== nothing ?
                  @expression(model, vi[(bus,t_ph)] - vi[(bus,t_n)]) : vi[(bus,t_ph)]
            JuMP.add_to_expression!(obj, c1,
                @expression(model, dvr*cr_src[(sid,idx)] + dvi*ci_src[(sid,idx)]))
        end
    end

    # ── IBR dispatch cost (same structure as generator) ─────────────────
    for (inv_id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        bus  = get(inv, "bus", "")
        tm   = Vector{String}(get(inv, "terminal_map", String[]))
        topo = get(inv, "topology", "FOUR_LEG")
        cost = get(inv, "cost", nothing)
        cost === nothing && continue

        if topo == "SINGLE_PHASE" && length(tm) >= 2
            c1 = _phase_cost(cost, 1, "IBR", inv_id)
            t_ph = tm[1]; t_ref = tm[2]
            dvr = @expression(model, vr[(bus,t_ph)] - vr[(bus,t_ref)])
            dvi = @expression(model, vi[(bus,t_ph)] - vi[(bus,t_ref)])
            JuMP.add_to_expression!(obj, c1,
                @expression(model, dvr*cri[(inv_id,1)] + dvi*cii[(inv_id,1)]))

        elseif topo == "FOUR_LEG"
            ph_pos    = _phase_positions(tm, nlabels)
            n_pos_idx = _neutral_pos(tm, nlabels)
            t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing
            for (idx, ph) in enumerate(ph_pos)
                c1   = _phase_cost(cost, idx, "IBR", inv_id)
                t_ph = tm[ph]
                dvr = t_n !== nothing ?
                      @expression(model, vr[(bus,t_ph)] - vr[(bus,t_n)]) : vr[(bus,t_ph)]
                dvi = t_n !== nothing ?
                      @expression(model, vi[(bus,t_ph)] - vi[(bus,t_n)]) : vi[(bus,t_ph)]
                JuMP.add_to_expression!(obj, c1,
                    @expression(model, dvr*cri[(inv_id,idx)] + dvi*cii[(inv_id,idx)]))
            end

        elseif topo == "THREE_LEG"
            n_c = length(tm)
            for k in 1:n_c
                c1 = _phase_cost(cost, k, "IBR", inv_id)
                t_pos = tm[k]; t_neg = tm[(k % n_c) + 1]
                dvr = @expression(model, vr[(bus,t_pos)] - vr[(bus,t_neg)])
                dvi = @expression(model, vi[(bus,t_pos)] - vi[(bus,t_neg)])
                JuMP.add_to_expression!(obj, c1,
                    @expression(model, dvr*cri[(inv_id,k)] + dvi*cii[(inv_id,k)]))
            end
        end
    end

    @objective(model, Min, obj)
end
