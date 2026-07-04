# lineconstants/series.jl
#
# Assemble the primitive series-impedance matrix [Ω/m] over the internal
# conductor list (circuit conductors first, then any cable shield
# subconductors appended by `compile_linecode`).

# One row of the primitive system. `pair` is the index of the conductor this
# one is coaxial with (core ↔ its own shield), so the mutual distance is the
# radial shield distance rather than the (zero) centre-to-centre distance.
struct _PrimitiveConductor
    r_ac::Float64
    gmr::Float64
    x::Float64
    y::Float64
    pair::Union{Int,Nothing}
    pair_distance::Float64
end

function _mutual_distance(ci::_PrimitiveConductor, cj::_PrimitiveConductor,
                          i::Int, j::Int)::Float64
    (ci.pair == j) && return ci.pair_distance
    (cj.pair == i) && return cj.pair_distance
    hypot(ci.x - cj.x, ci.y - cj.y)
end

"""
    _primitive_z(conds, model, f, rho) -> Matrix{ComplexF64}  [Ω/m]

Full primitive series-impedance matrix for the conductor system.
"""
function _primitive_z(conds::Vector{_PrimitiveConductor}, model::String,
                      f::Float64, rho::Float64)::Matrix{ComplexF64}
    n = length(conds)
    Z = zeros(ComplexF64, n, n)
    for i in 1:n
        ci = conds[i]
        Z[i, i] = _z_self(model, ci.r_ac, ci.gmr, ci.y, f, rho)
        for j in i+1:n
            cj = conds[j]
            d = _mutual_distance(ci, cj, i, j)
            d > 0 || error("conductors $i and $j coincide at " *
                           "($(ci.x), $(ci.y)) — overlapping conductors.")
            Z[i, j] = _z_mutual(model, d, ci.x, ci.y, cj.x, cj.y, f, rho)
            Z[j, i] = Z[i, j]
        end
    end
    Z
end
