# lineconstants/series.jl
#
# Assemble the primitive series-impedance matrix [Ω/m] over the internal
# conductor list (circuit conductors first, then any cable shield
# subconductors appended by `compile_linecode`).

# One row of the primitive system. `pair` is the index of the conductor this
# one is coaxial with (core ↔ its own shield), so the mutual distance is the
# radial shield distance rather than the (zero) centre-to-centre distance.
struct _PrimitiveConductor{T<:Real}
    r_ac::T
    gmr::T
    x::T
    y::T
    pair::Union{Int,Nothing}
    pair_distance::T
end

function _PrimitiveConductor(r_ac::Real, gmr::Real, x::Real, y::Real,
                             pair::Union{Int,Nothing}, pair_distance::Real)
    values = promote(r_ac, gmr, x, y, pair_distance)
    T = typeof(values[1])
    _PrimitiveConductor{T}(values[1], values[2], values[3], values[4], pair,
                           values[5])
end

function _mutual_distance(ci::_PrimitiveConductor, cj::_PrimitiveConductor,
                          i::Int, j::Int)
    (ci.pair == j) && return ci.pair_distance
    (cj.pair == i) && return cj.pair_distance
    hypot(ci.x - cj.x, ci.y - cj.y)
end

"""
    _primitive_z(conds, model, f, rho) -> Matrix{ComplexF64}  [Ω/m]

Full primitive series-impedance matrix for the conductor system.
"""
function _primitive_z(conds::AbstractVector{<:_PrimitiveConductor},
                      model::AbstractString, f::Real, rho::Real)
    n = length(conds)
    n > 0 || throw(ArgumentError("at least one conductor is required"))
    z11 = _z_self(model, conds[1].r_ac, conds[1].gmr, conds[1].y, f, rho)
    Z = Matrix{typeof(z11)}(undef, n, n)
    Z[1, 1] = z11
    for i in 1:n
        ci = conds[i]
        i == 1 || (Z[i, i] = _z_self(model, ci.r_ac, ci.gmr, ci.y, f, rho))
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
