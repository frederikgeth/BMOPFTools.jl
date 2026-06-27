# Smooth piecewise-linear control-curve encoding for Volt-var / Volt-watt droop.
#
# A piecewise-linear characteristic f(U) defined by non-decreasing breakpoints
# (x₁,y₁) … (xₙ,yₙ), clamped flat outside [x₁, xₙ], is encoded as a sum of
# shifted/scaled ReLU functions (Geth, "ReLU-sum encoding"):
#
#     f(U) = y₁ + Σ_i  aᵢ · ReLU(U − x̄ᵢ)
#
# Each interior segment i (between xᵢ and xᵢ₊₁) with slope sᵢ contributes two
# terms — (+sᵢ, xᵢ) turns the slope on at the segment start, (−sᵢ, xᵢ₊₁) turns it
# off again at the segment end — so the slope telescopes correctly and the curve
# is flat (= y₁) below x₁ and flat (= yₙ) above xₙ. This is exactly the two-triple
# form used for the canonical Volt-Watt example.
#
# For a gradient-based solver (Ipopt) the kinked ReLU is replaced by the smooth
# softplus surrogate
#
#     reluε(x) = ε · log1pexp(x/ε),     reluε'(x) = logistic(x/ε)
#
# evaluated with the numerically stable `log1pexp` / `logistic` from StatsFuns and
# registered as a JuMP nonlinear operator (analytic 1st/2nd derivatives) so that
# JuMP/Ipopt differentiate it exactly. ε → 0 recovers the exact ReLU.

"""
    breakpoints_to_triples(xs, ys) -> (baseline, triples)

Convert a piecewise-linear characteristic through points `(xs[i], ys[i])` into the
ReLU-sum encoding. Returns `baseline = ys[1]` and `triples`, a vector of
`(a, x̄)` pairs such that

    f(U) = baseline + Σ a · ReLU(U − x̄)

reproduces the characteristic and clamps flat outside `[xs[1], xs[end]]`.

`xs` must be strictly increasing; `xs`/`ys` equal length ≥ 2. Zero-slope segments
contribute no triples.
"""
function breakpoints_to_triples(xs::AbstractVector{<:Real}, ys::AbstractVector{<:Real})
    n = length(xs)
    n == length(ys) ||
        throw(ArgumentError("breakpoints xs and values ys must have equal length"))
    n >= 2 || throw(ArgumentError("need at least 2 breakpoints, got $n"))
    for i in 1:(n - 1)
        xs[i + 1] > xs[i] ||
            throw(ArgumentError("breakpoints xs must be strictly increasing"))
    end

    baseline = Float64(ys[1])
    triples = Tuple{Float64,Float64}[]   # (slope a, shift x̄)
    for i in 1:(n - 1)
        s = (Float64(ys[i + 1]) - Float64(ys[i])) / (Float64(xs[i + 1]) - Float64(xs[i]))
        s == 0.0 && continue
        push!(triples, (s,  Float64(xs[i])))
        push!(triples, (-s, Float64(xs[i + 1])))
    end
    return (baseline = baseline, triples = triples)
end

"Exact (kinked) evaluation of a ReLU-sum curve — used for testing the encoding."
function curve_value_exact(baseline::Real, triples, u::Real)
    acc = Float64(baseline)
    for (a, x̄) in triples
        acc += a * max(0.0, Float64(u) - x̄)
    end
    return acc
end

"Smooth (softplus) evaluation of a ReLU-sum curve — mirrors the JuMP expression."
function curve_value_smooth(baseline::Real, triples, u::Real, ε::Real)
    acc = Float64(baseline)
    for (a, x̄) in triples
        acc += a * ε * log1pexp((Float64(u) - x̄) / ε)
    end
    return acc
end

"""
    relu_operator(model, ε; name) -> op

Register the smooth-ReLU `reluε(x) = ε·log1pexp(x/ε)` as a JuMP nonlinear
operator on `model`, with analytic first and second derivatives, and return the
operator handle. `ε` is in the same units as the operator's argument (model
voltage units). `name` must be unique on `model`.
"""
function relu_operator(model, ε::Float64; name::Symbol)
    ε > 0 || throw(ArgumentError("smoothing ε must be > 0, got $ε"))
    f(x)   = ε * log1pexp(x / ε)
    df(x)  = logistic(x / ε)
    d2f(x) = (s = logistic(x / ε); s * (1 - s) / ε)
    return JuMP.add_nonlinear_operator(model, 1, f, df, d2f; name = name)
end

"""
    relu_operator_for!(cache, model, ε) -> op

Return a smooth-ReLU operator for smoothing `ε`, registering it on `model` the
first time a given `ε` is requested and caching it in `cache`
(`Dict{Float64,Any}`). Lets IBRs at different voltage bases share operators
while keeping each registration unique.
"""
function relu_operator_for!(cache::Dict{Float64,Any}, model, ε::Float64)
    haskey(cache, ε) && return cache[ε]
    name = Symbol("op_reluε_$(length(cache) + 1)")
    op = relu_operator(model, ε; name = name)
    cache[ε] = op
    return op
end

"""
    curve_expr(op, U, baseline, triples)

Build the JuMP expression `baseline + Σ a·op(U − x̄)` for a ReLU-sum curve, where
`op` is a registered smooth-ReLU operator and `U` is a voltage-magnitude
expression. Returns `baseline` unchanged when `triples` is empty.
"""
function curve_expr(op, U, baseline::Real, triples)
    acc = Float64(baseline)
    isempty(triples) && return acc
    expr = acc + sum(a * op(U - x̄) for (a, x̄) in triples)
    return expr
end

"Voltage-magnitude expression √(dvr² + dvi²) from rectangular voltage differences."
umag_expr(dvr, dvi) = sqrt(dvr^2 + dvi^2)
