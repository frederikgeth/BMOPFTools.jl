# Shunt admittance constraints — standalone shunt objects.
#
# Shunt objects represent admittances Y = G + jB (S) connected between a set
# of bus terminals and ground. The current they draw is linear in the voltage
# variables, so no new JuMP variables are required: contributions are added
# directly to the KCL accumulators as AffExpr terms.
#
# Current leaving bus b at terminal t_k:
#   I^r_k = Σ_j ( G_kj · vr[t_j] − B_kj · vi[t_j] )
#   I^i_k = Σ_j ( G_kj · vi[t_j] + B_kj · vr[t_j] )
#
# KCL sign: current leaves the bus → subtract from accumulator.

"""
    _shunt_current!(cr, ci, vr, vi, G, B, bus, terminals)

Accumulate shunt admittance (G + jB, S) current into the pre-allocated
`AffExpr` vectors `cr` and `ci` (one entry per terminal).

Grounded terminals are absent from the `vr`/`vi` dicts and are silently
skipped (their voltage is zero, contributing nothing).
"""
function _shunt_current!(cr::Vector{JuMP.AffExpr},
                         ci::Vector{JuMP.AffExpr},
                         vr, vi,
                         G::Union{Matrix{Float64},Nothing},
                         B::Union{Matrix{Float64},Nothing},
                         bus::String,
                         terminals::Vector{String})
    (G === nothing && B === nothing) && return
    n = length(terminals)
    for k in 1:n, j in 1:n
        key_j = (bus, terminals[j])
        haskey(vr, key_j) || continue   # grounded — voltage is zero
        g_kj = (G !== nothing && k <= size(G,1) && j <= size(G,2)) ? G[k,j] : 0.0
        b_kj = (B !== nothing && k <= size(B,1) && j <= size(B,2)) ? B[k,j] : 0.0
        (iszero(g_kj) && iszero(b_kj)) && continue
        JuMP.add_to_expression!(cr[k],  g_kj, vr[key_j])
        JuMP.add_to_expression!(cr[k], -b_kj, vi[key_j])
        JuMP.add_to_expression!(ci[k],  g_kj, vi[key_j])
        JuMP.add_to_expression!(ci[k],  b_kj, vr[key_j])
    end
end

"""
    _add_shunt_constraints!(model, net, vars, kcl_r, kcl_i)

Register the KCL contribution of all standalone `shunt` objects.

Each shunt is a bus-connected admittance matrix Y = G + jB (S) with fields
`G_{k}_{j}` / `B_{k}_{j}` indexed by `terminal_map`. No new variables are
added; the shunt current is expressed as a linear AffExpr in the bus voltage
variables and subtracted from the KCL accumulator (current leaves the bus).
"""
function _add_shunt_constraints!(net, vars, kcl_r, kcl_i; branch_inj=nothing)
    vr = vars[:vr]; vi = vars[:vi]

    core_owners = BMOPFTools._core_shunt_owners(net)
    for (id, sh) in get(net, "shunt", Dict())
        sh isa Dict || continue
        bus = get(sh, "bus", "")
        tm  = Vector{String}(get(sh, "terminal_map", String[]))
        isempty(tm) && continue

        G = _pkm(sh, "G_")
        B = _pkm(sh, "B_")
        (G === nothing && B === nothing) && continue

        n = length(tm)
        cr = [JuMP.AffExpr(0.0) for _ in 1:n]
        ci = [JuMP.AffExpr(0.0) for _ in 1:n]
        _shunt_current!(cr, ci, vr, vi, G, B, bus, tm)

        owner = get(core_owners, string(id), nothing)
        entry = owner === nothing ? nothing : ("transformer", owner)
        for k in 1:n
            _kcl_add!(kcl_r, kcl_i, bus, tm[k], -cr[k], -ci[k]; ledger=branch_inj, entry)
        end
    end
end
