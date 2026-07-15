# Pure numerical entry point for overhead-line constants. Dictionary parsing,
# network mutation, provenance, and user-facing validation remain in
# `compile_linecode`; this API exists for numerical consumers such as parameter
# studies and inverse problems that need primitive matrices directly.

"""
    overhead_line_constants(r_ac, gmr, radius, x, y;
        cap_radius=radius, frequency, earth_model="modified_carson",
        earth_resistivity=100.0) -> (; Z, C)

Compute the full primitive series-impedance matrix `Z` [Ω/m] and Maxwell
capacitance matrix `C` [F/m] of an overhead conductor arrangement. Input vectors
are ordered by conductor and use SI units: `r_ac` [Ω/m], `gmr`, `radius`, `x`,
`y`, and `cap_radius` [m]. `frequency` is required [Hz]; `earth_resistivity` is
in Ω·m.

Unlike [`compile_linecode`](@ref), this is a pure numerical API: it does not
read or mutate a BMOPF dictionary, apply wire-data defaults, stamp provenance,
or Kron-reduce any circuit conductor. It uses the same Carson/Deri and Maxwell
kernels as the compiler. `compile_linecode` remains the preferred entry point
for ordinary network data.

The implementation is generic over `Real` element types so numerical clients
can propagate alternative scalar types. Modified Carson is smooth on the
interior of the physical domain (`gmr > 0`, positive separation, `y > 0`). The
`full_carson` model retains its documented near-ground height clamp and is not
smooth at that clamp.
"""
function overhead_line_constants(r_ac::AbstractVector{<:Real},
                                 gmr::AbstractVector{<:Real},
                                 radius::AbstractVector{<:Real},
                                 x::AbstractVector{<:Real},
                                 y::AbstractVector{<:Real};
                                 cap_radius::AbstractVector{<:Real}=radius,
                                 frequency::Real,
                                 earth_model::AbstractString="modified_carson",
                                 earth_resistivity::Real=100.0)
    n = length(r_ac)
    n > 0 || throw(ArgumentError("at least one conductor is required"))
    all(==(n), (length(gmr), length(radius), length(x), length(y),
                length(cap_radius))) ||
        throw(DimensionMismatch("all conductor-property vectors must have equal length"))
    earth_model in _EARTH_MODELS ||
        throw(ArgumentError("unknown earth_model '$earth_model'"))
    frequency > 0 || throw(ArgumentError("frequency must be > 0 Hz"))
    earth_resistivity > 0 || throw(ArgumentError("earth_resistivity must be > 0 Ω·m"))
    all(>(0), r_ac) || throw(ArgumentError("all r_ac values must be > 0 Ω/m"))
    all(>(0), gmr) || throw(ArgumentError("all gmr values must be > 0 m"))
    all(>(0), radius) || throw(ArgumentError("all radius values must be > 0 m"))
    all(>(0), cap_radius) || throw(ArgumentError("all cap_radius values must be > 0 m"))
    all(>(0), y) || throw(ArgumentError("all overhead conductor heights must be > 0 m"))
    all(gmr[i] <= radius[i] * (1 + 1e-9) for i in 1:n) ||
        throw(ArgumentError("every gmr must be less than or equal to its radius"))

    for i in 1:n, j in i+1:n
        d = hypot(x[i] - x[j], y[i] - y[j])
        d >= radius[i] + radius[j] ||
            throw(ArgumentError("conductors $i and $j overlap"))
    end

    # One promoted scalar type keeps the small dense kernels type-stable even
    # when only some input vectors carry an alternative numeric scalar type.
    T = promote_type(eltype(r_ac), eltype(gmr), eltype(radius), eltype(x),
                     eltype(y), eltype(cap_radius), typeof(frequency),
                     typeof(earth_resistivity))
    isconcretetype(T) || throw(ArgumentError("input vectors need concrete scalar types"))
    rac = T.(r_ac); gm = T.(gmr); rad = T.(radius)
    xs = T.(x); ys = T.(y); cr = T.(cap_radius)
    f = convert(T, frequency); rho = convert(T, earth_resistivity)

    prims = [_PrimitiveConductor(rac[i], gm[i], xs[i], ys[i], nothing, zero(T))
             for i in 1:n]
    Z = _primitive_z(prims, earth_model, f, rho)
    C = _overhead_shunt_c(cr, xs, ys)
    (; Z, C)
end
