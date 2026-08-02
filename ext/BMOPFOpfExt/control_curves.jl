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

# DiffOpt's optimizer wrapper currently rejects MOI.UserDefinedFunction even
# when the wrapped nonlinear solver supports it. This callable emits only native
# MOI nonlinear operators, which DiffOpt can transform and differentiate.
struct BuiltinSoftplus
    eps::Float64
end
(op::BuiltinSoftplus)(x::Real) = op.eps * log1pexp(x / op.eps)
(op::BuiltinSoftplus)(x) = op.eps * log1p(exp(x / op.eps))

"""
    relu_operator_for!(cache, model, ε) -> op

Return a smooth-ReLU operator for smoothing `ε`, registering it on `model` the
first time a given `ε` is requested and caching it in `cache`
(`Dict{Float64,Any}`). Lets IBRs at different voltage bases share operators
while keeping each registration unique.
"""
function relu_operator_for!(cache::Dict{Float64,Any}, model, ε::Float64;
                            mode::Symbol=:user_defined)
    haskey(cache, ε) && return cache[ε]
    mode in (:user_defined, :builtin) || throw(ArgumentError(
        "softplus must be :user_defined or :builtin, got :$mode"))
    op = if mode == :builtin
        BuiltinSoftplus(ε)
    else
        try
            relu_operator(model, ε;
                name=Symbol("op_reluε_$(length(cache) + 1)"))
        catch err
            if err isa JuMP.MOI.SetAttributeNotAllowed{
                    JuMP.MOI.UserDefinedFunction}
                throw(ArgumentError(
                    "the model backend rejects user-defined nonlinear " *
                    "operators required by softplus=:user_defined; pass " *
                    "softplus=:builtin explicitly (required by current " *
                    "DiffOpt nonlinear wrappers)"))
            end
            rethrow()
        end
    end
    cache[ε] = op
    return op
end

"""
    curve_expr(op, U, baseline, triples)

Build the JuMP expression `baseline + Σ a·op(U − x̄)` for a ReLU-sum curve, where
`op` is a registered smooth-ReLU operator and `U` is a voltage-magnitude
expression. Returns `baseline` unchanged when `triples` is empty.
"""
function curve_expr(op, U, baseline, triples)
    acc = baseline
    isempty(triples) && return acc
    expr = acc + sum(a * op(U - x̄) for (a, x̄) in triples)
    return expr
end

"""
    umag_var(model, dvr, dvi) -> VariableRef

Voltage magnitude √(dvr² + dvi²) as an auxiliary variable `u ≥ 0` pinned by the
smooth equality `u² == dvr² + dvi²` — an *implicit* square root.

We never write `sqrt(dvr² + dvi²)` directly in a constraint: its gradient
`·/√(·)` is unbounded at the origin, and a monitored voltage *difference* is not
bounded away from zero (the formulation does not force voltage bounds on every
node), so the singular corner is reachable and would poison Ipopt's Jacobian.
The `u²`-equality has a bounded Jacobian everywhere. This mirrors the load
model's `W`/`s` implicit-magnitude variables.
"""
function umag_var(model, dvr, dvi)
    u = @variable(model, lower_bound = 0.0, base_name = "umag")
    @constraint(model, u^2 == dvr^2 + dvi^2)
    # Seed the start from the voltage warm-start, so Ipopt does not begin at the
    # degenerate u = 0 point (where the u²-equality has a zero gradient in u and
    # the solver can stall on a spurious stationary point). Unset starts (e.g. a
    # grounded terminal fixed to 0) read as 0.
    sv(v) = something(JuMP.start_value(v), 0.0)
    mag0 = sqrt(JuMP.value(sv, dvr)^2 + JuMP.value(sv, dvi)^2)
    JuMP.set_start_value(u, max(mag0, 1e-6))
    return u
end
