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
    m = length(oh)
    P = zeros(m, m)
    for (a, i) in enumerate(oh)
        P[a, a] = log(2 * ys[i] / wires[i].cap_radius) / (2pi * _EPS0)
        for (b, j) in enumerate(oh)
            b <= a && continue
            d    = hypot(xs[i] - xs[j], ys[i] - ys[j])
            dimg = hypot(xs[i] - xs[j], ys[i] + ys[j])
            P[a, b] = log(dimg / d) / (2pi * _EPS0)
            P[b, a] = P[a, b]
        end
    end
    C[oh, oh] = inv(P)
    C
end
