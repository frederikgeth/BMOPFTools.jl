# lineconstants/earth.jl
#
# Earth-return formulations for the series-impedance engine. All three take
# frequency and earth resistivity as data — never compile-time constants.
#
#   modified_carson — Kersting's two-term truncation of Carson's series.
#                     Height-independent (the equivalent return depth De
#                     dominates any realistic conductor height/burial depth
#                     at power frequency). The 50/60 Hz industry default.
#   full_carson     — Carson's series kept to second order in k = a·S
#                     (k ≪ 1 at power frequency, so this is numerically
#                     indistinguishable from the infinite series there).
#   deri            — complex-depth image plane at p = √(ρ/(jωμ₀))
#                     (Deri et al. 1981). OpenDSS's DEFAULT earth model —
#                     select this when cross-validating against OpenDSS.
#
# Sign/height conventions: y > 0 is height above ground, y < 0 burial depth.
# modified_carson never uses y. deri uses y as-is (valid for |y| ≪ |p|,
# which holds for any realistic burial depth at power frequency).
# full_carson is an above-ground formulation; heights are clamped to
# ≥ _MIN_HEIGHT so buried conductors are evaluated at the surface — the
# standard power-frequency treatment (Pollaczek's correction is negligible
# there; see the docs).

const _MIN_HEIGHT = 0.01   # [m] height clamp for the image-based formulations

const _EARTH_MODELS = ("modified_carson", "full_carson", "deri")

"Carson equivalent return depth De = 2·e^(1/2)/(mₑ·e^γ) [m], mₑ = √(ωμ₀/ρ)."
function _carson_return_depth(f::Float64, rho::Float64)::Float64
    me = sqrt(2pi * f * _MU0 / rho)
    2 * exp(0.5) / (me * exp(MathConstants.eulergamma))
end

"""
Carson correction ΔZ = (ωμ₀/π)·(P + jQ) [Ω/m] to second order in
k = a·S (a = √(ωμ₀/ρ), S = distance to the image conductor), with θ the
angle at the image between the conductors.
"""
function _carson_correction(k::Float64, theta::Float64, omega::Float64)::ComplexF64
    c = cos(theta)
    c2, s2 = cos(2theta), sin(2theta)
    P = pi / 8 - k * c / (3 * sqrt(2)) +
        k^2 / 16 * (c2 * (0.6728 + log(2 / k)) + theta * s2)
    Q = -0.0386 + 0.5 * log(2 / k) + k * c / (3 * sqrt(2)) - pi * k^2 / 64 * c2
    omega * _MU0 / pi * (P + im * Q)
end

"""
    _z_self(model, r_ac, gmr, y, f, rho) -> ComplexF64  [Ω/m]

Self impedance of a conductor with AC resistance `r_ac`, GMR `gmr`, at
vertical coordinate `y`. Uses the GMR in the external term, so the internal
inductance is included implicitly — no separate internal-reactance term
(adding one would double-count it).
"""
function _z_self(model::String, r_ac::Float64, gmr::Float64, y::Float64,
                 f::Float64, rho::Float64)::ComplexF64
    omega = 2pi * f
    jk = im * omega * _MU0 / 2pi
    if model == "modified_carson"
        de = _carson_return_depth(f, rho)
        return r_ac + omega * _MU0 / 8 + jk * log(de / gmr)
    elseif model == "deri"
        p = sqrt(rho / (im * omega * _MU0))
        return r_ac + jk * log(2 * (y + p) / gmr)
    elseif model == "full_carson"
        h = max(y, _MIN_HEIGHT)
        a = sqrt(omega * _MU0 / rho)
        return r_ac + jk * log(2h / gmr) + _carson_correction(a * 2h, 0.0, omega)
    end
    error("unknown earth model '$model' (expected one of $(_EARTH_MODELS)).")
end

"""
    _z_mutual(model, d, xi, yi, xj, yj, f, rho) -> ComplexF64  [Ω/m]

Mutual impedance between conductors i and j separated by distance `d`
(passed explicitly so cable-internal core↔shield pairs can override the
centre-to-centre distance).
"""
function _z_mutual(model::String, d::Float64,
                   xi::Float64, yi::Float64, xj::Float64, yj::Float64,
                   f::Float64, rho::Float64)::ComplexF64
    omega = 2pi * f
    jk = im * omega * _MU0 / 2pi
    if model == "modified_carson"
        de = _carson_return_depth(f, rho)
        return omega * _MU0 / 8 + jk * log(de / d)
    elseif model == "deri"
        p  = sqrt(rho / (im * omega * _MU0))
        dx = xi - xj
        dimg = sqrt(complex(dx^2) + (yi + yj + 2p)^2)
        return jk * log(dimg / d)
    elseif model == "full_carson"
        hi, hj = max(yi, _MIN_HEIGHT), max(yj, _MIN_HEIGHT)
        dx = xi - xj
        s  = hypot(dx, hi + hj)                   # distance to the image
        a  = sqrt(omega * _MU0 / rho)
        theta = acos(clamp((hi + hj) / s, -1.0, 1.0))
        return jk * log(s / d) + _carson_correction(a * s, theta, omega)
    end
    error("unknown earth model '$model' (expected one of $(_EARTH_MODELS)).")
end
