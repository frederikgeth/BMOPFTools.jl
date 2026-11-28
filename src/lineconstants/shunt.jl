# lineconstants/shunt.jl
#
# Shunt capacitance of the compiled conductor system [F/m].
#
# Overhead conductors: Maxwell potential coefficients against a perfectly
# conducting earth (there is no Carson analogue electrostatically), using the
# electrostatic radius `cap_radius` — NOT the GMR (mixing them is the classic
# implementation bug). C = P̂⁻¹ over the overhead subsystem.
#
# Two capacitance models (`line_geometry.capacitance_model`):
#   "thin_wire" (default, OpenDSS LineConstants parity): each conductor is one
#     line charge at its center. Accurate while radii are small against the
#     spacing; at (r_i + r_j)/d = 0.5 the mutual capacitance is off by about
#     5 %, and from about 0.7 (touching insulated cores) the mutual between
#     diagonally opposite cores of a four-core bundle turns positive, which
#     breaks the Maxwell sign pattern.
#   "charge_simulation": a ring of line charges inside each conductor, matched
#     to equal potential at collocation points on its surface (least squares),
#     with ground images. Captures the redistribution of charge around each
#     conductor's surface; agrees with thin_wire to ~0.01 % at wide spacing.
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
                  xs::Vector{Float64}, ys::Vector{Float64};
                  capacitance_model::AbstractString = "thin_wire")::Matrix{Float64}
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
                                  xs[oh], ys[oh]; capacitance_model)
    C
end

const _CAPACITANCE_MODELS = ("thin_wire", "charge_simulation")

# Thin-wire validity guard on (r_i + r_j)/d for any conductor pair: about 5 %
# error in the mutual capacitance at 0.5 against a converged charge-simulation
# reference (0.4 % at 0.2, 25 % at 0.8; sign flip of the opposite-core mutual
# of a four-core square from about 0.7).
const _THIN_WIRE_RATIO_MAX = 0.5

"""
    _thin_wire_ratio(cap_radius, xs, ys) -> (ratio, (i, j))

Largest (r_i + r_j)/d over conductor pairs, with the pair; `(0.0, (0, 0))` for
fewer than two conductors.
"""
function _thin_wire_ratio(cap_radius::AbstractVector{<:Real},
                          xs::AbstractVector{<:Real}, ys::AbstractVector{<:Real})
    worst = 0.0; pair = (0, 0)
    for i in eachindex(xs), j in i+1:lastindex(xs)
        d = hypot(xs[i] - xs[j], ys[i] - ys[j])
        d > 0 || continue
        r = Float64((cap_radius[i] + cap_radius[j]) / d)
        r > worst && (worst = r; pair = (i, j))
    end
    worst, pair
end

"Maxwell capacitance [F/m] for above-ground conductors (see the header)."
function _overhead_shunt_c(cap_radius::AbstractVector{<:Real},
                           xs::AbstractVector{<:Real},
                           ys::AbstractVector{<:Real};
                           capacitance_model::AbstractString = "thin_wire")
    n = length(xs)
    n > 0 || throw(ArgumentError("at least one conductor is required"))
    length(cap_radius) == n == length(ys) ||
        throw(DimensionMismatch("cap_radius, x, and y must have equal length"))
    capacitance_model in _CAPACITANCE_MODELS ||
        throw(ArgumentError("unknown capacitance_model '$capacitance_model' " *
                            "(expected one of $(_CAPACITANCE_MODELS))"))
    capacitance_model == "charge_simulation" &&
        return _overhead_shunt_c_csm(cap_radius, xs, ys)

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
    # The Maxwell matrix is reciprocal by construction, so materialize that
    # invariant exactly rather than leaking numerical asymmetry downstream.
    C = inv(P)
    for i in 1:n, j in i+1:n
        C[j, i] = C[i, j]
    end
    C
end

# Charge-simulation method (CSM) for round conductors over a perfectly
# conducting ground plane y = 0, homogeneous medium. Each conductor carries
# `m` line charges on a ring of radius `ρ·r` inside it; potentials are matched
# at `2m` points on its surface (least squares). The total charge per
# conductor for unit potential on conductor j gives column j of C. The image
# of a charge at (x, y) is −q at (x, −y).
function _overhead_shunt_c_csm(cap_radius::AbstractVector{<:Real},
                               xs::AbstractVector{<:Real},
                               ys::AbstractVector{<:Real};
                               m::Int = 48, ρ::Real = 0.7)
    n = length(xs)
    ratio, (ci, cj) = _thin_wire_ratio(cap_radius, xs, ys)
    ratio < 0.99 || throw(ArgumentError(
        "capacitance_model 'charge_simulation': conductors $ci and $cj " *
        "(nearly) touch ((r_i + r_j)/d = $(round(ratio, sigdigits=3))); " *
        "bare conductors in contact are one conductor electrically"))
    T = float(promote_type(eltype(cap_radius), eltype(xs), eltype(ys)))
    k = one(T) / (2 * T(pi) * T(_EPS0))
    sx = Vector{T}(undef, n * m); sy = similar(sx); owner = Vector{Int}(undef, n * m)
    px = Vector{T}(undef, 2n * m); py = similar(px); powner = Vector{Int}(undef, 2n * m)
    for c in 1:n, a in 1:m
        θ = 2 * T(pi) * (a - 1) / m
        sx[(c-1)*m + a] = xs[c] + ρ * cap_radius[c] * cos(θ)
        sy[(c-1)*m + a] = ys[c] + ρ * cap_radius[c] * sin(θ)
        owner[(c-1)*m + a] = c
    end
    for c in 1:n, a in 1:2m
        φ = 2 * T(pi) * (a - T(1) / 2) / (2m)
        px[(c-1)*2m + a] = xs[c] + cap_radius[c] * cos(φ)
        py[(c-1)*2m + a] = ys[c] + cap_radius[c] * sin(φ)
        powner[(c-1)*2m + a] = c
    end
    A = Matrix{T}(undef, 2n * m, n * m)
    for q in eachindex(sx), p in eachindex(px)
        dx = px[p] - sx[q]
        A[p, q] = k * (log(hypot(dx, py[p] + sy[q])) - log(hypot(dx, py[p] - sy[q])))
    end
    F = qr(A)
    C = Matrix{T}(undef, n, n)
    for j in 1:n
        q = F \ T.(powner .== j)
        for i in 1:n
            C[i, j] = sum(q[owner .== i])
        end
    end
    for i in 1:n, j in i+1:n
        C[i, j] = C[j, i] = (C[i, j] + C[j, i]) / 2
    end
    C
end
