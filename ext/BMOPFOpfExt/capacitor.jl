# capacitor.jl
#
# Fixed (nameplate-rated) shunt capacitor banks — OPF KCL contribution.
#
# A capacitor is a constant susceptance B = q_rated / v_rated² that delivers the
# voltage-dependent reactive power Q = B·V². It is electrically a connection-aware
# shunt: `_cap_bmatrix` (src/io/capacitor.jl) assembles the terminal-space
# susceptance matrix, and the current is injected with the SAME machinery as a
# standalone `shunt` (`_shunt_current!` with G = nothing). No decision variables.

"""
    _add_capacitor_constraints!(net, vars, kcl_r, kcl_i)

Register the KCL contribution of every fixed `capacitor`. The susceptance matrix
is built from the nameplate (`q_rated`/`v_rated`) and connection, then the
constant-admittance current (linear in the bus voltages) is subtracted from the
KCL accumulators — identical to a `shunt`.
"""
function _add_capacitor_constraints!(net, vars, kcl_r, kcl_i)
    vr = vars[:vr]; vi = vars[:vi]

    for (_, cap) in get(net, "capacitor", Dict())
        cap isa Dict || continue
        tm, B = BMOPFTools._cap_bmatrix(cap)
        isempty(tm) && continue
        all(iszero, B) && continue
        bus = get(cap, "bus", "")

        n  = length(tm)
        cr = [JuMP.AffExpr(0.0) for _ in 1:n]
        ci = [JuMP.AffExpr(0.0) for _ in 1:n]
        _shunt_current!(cr, ci, vr, vi, nothing, B, bus, tm)

        for k in 1:n
            _kcl_add!(kcl_r, kcl_i, bus, tm[k], -cr[k], -ci[k])
        end
    end
end
