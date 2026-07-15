# lineconstants/shunt.jl
#
# Shunt capacitance of the compiled conductor system [F/m].
#
# Overhead conductors: Maxwell potential coefficients against a perfectly
# conducting earth (there is no Carson analogue electrostatically), using the
# electrostatic radius `cap_radius` — NOT the GMR (mixing them is the classic
# implementation bug). C = P̂⁻¹ over the overhead subsystem.
#
# Cables (cn/ts): the grounded shield confines the electric field, so each
# cable contributes only its coaxial phase-to-shield capacitance on the
# diagonal — no interphase terms (OpenDSS convention).
#
# Bare conductors at or below ground level have no defined overhead
# capacitance; they contribute zero (with a warning from the compiler).

"""
    _shunt_c(wires, xs, ys) -> Matrix{Float64}  [F/m]

Nodal capacitance matrix over the n circuit conductors. `wires` are the
resolved wire records (order = matrix order); `xs`/`ys` their coordinates.
"""
function _shunt_c(wires::Vector{_ResolvedWire},
                  xs::Vector{Float64}, ys::Vector{Float64})::Matrix{Float64}
    n = length(wires)
    C = zeros(n, n)

    # cables: diagonal coaxial capacitance
    for i in 1:n
        wires[i].kind in ("cn_cable", "ts_cable") || continue
        C[i, i] = wires[i].c_shunt
    end

    # overhead subsystem: potential coefficients with ground images
    oh = [i for i in 1:n if wires[i].kind == "overhead" && ys[i] > 0]
    isempty(oh) && return C
    C[oh, oh] = _overhead_shunt_c([wires[i].cap_radius for i in oh],
                                  xs[oh], ys[oh])
    C
end

"Maxwell potential-coefficient capacitance for above-ground conductors."
function _overhead_shunt_c(cap_radius::AbstractVector{<:Real},
                           xs::AbstractVector{<:Real},
                           ys::AbstractVector{<:Real})
    n = length(xs)
    n > 0 || throw(ArgumentError("at least one conductor is required"))
    length(cap_radius) == n == length(ys) ||
        throw(DimensionMismatch("cap_radius, x, and y must have equal length"))

    p11 = log(2 * ys[1] / cap_radius[1]) / (2pi * _EPS0)
    P = Matrix{typeof(p11)}(undef, n, n)
    P[1, 1] = p11
    for i in 1:n
        i == 1 || (P[i, i] = log(2 * ys[i] / cap_radius[i]) / (2pi * _EPS0))
        for j in i+1:n
            d = hypot(xs[i] - xs[j], ys[i] - ys[j])
            dimg = hypot(xs[i] - xs[j], ys[i] + ys[j])
            P[i, j] = log(dimg / d) / (2pi * _EPS0)
            P[j, i] = P[i, j]
        end
    end
    # Roundoff in a dense inverse can differ by a few ulps across the diagonal.
    # The Maxwell matrix is reciprocal by construction, so materialise that
    # invariant exactly rather than leaking numerical asymmetry downstream.
    C = inv(P)
    for i in 1:n, j in i+1:n
        C[j, i] = C[i, j]
    end
    C
end
