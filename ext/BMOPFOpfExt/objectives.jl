# Objective building blocks.
#
# Composable, individually registered objective terms so a caller can express
# "minimise losses", "minimise unbalance at these buses", "minimise the worst
# bus" — alone or in a weighted combination — without hand-writing the
# expressions or having to know the engine's variable layout.
#
# ── Which norm? ────────────────────────────────────────────────────────────────
# Every term that penalises a COMPLEX quantity (a sequence voltage, a neutral
# current, a setpoint deviation) has to reduce a phasor to a scalar. Three
# reductions are offered, and the choice is a modelling decision with real
# consequences, not an implementation detail:
#
#   :squared    Σ (xᵢ² + yᵢ²)          L2. Smooth, exact, cheapest, most
#                                      reliable. Spreads the penalty across all
#                                      targets. THE DEFAULT.
#   :magnitude  Σ ‖(xᵢ, yᵢ)‖₂          L1 over per-element 2-norms — the
#                                      group-lasso norm. Drives individual
#                                      targets to (near) zero rather than
#                                      shrinking all of them: use it when you
#                                      want "fix these few" rather than "improve
#                                      everything a little". Smoothed; see below.
#   :max        maxᵢ (xᵢ² + yᵢ²)       L∞ / minimax. Exact via a LINEAR epigraph,
#                                      no smoothing: `max` is monotone under
#                                      squaring, so the worst element is the same
#                                      whether ranked by magnitude or its square.
#
# Never reduce a complex quantity componentwise (|x| + |y|): that is not
# rotation-invariant, so the answer would depend on the phase reference. It is a
# bug, not a modelling choice. `:magnitude` sums per-element 2-norms precisely to
# avoid this.
#
# ── Why :magnitude is smoothed rather than an exact cone ───────────────────────
# The textbook exact form of a minimised norm is the epigraph
# `min t s.t. x² + y² ≤ t²`, tight because nothing rewards inflating `t`. It is
# NOT used here. Measured over 40 configurations (5 load unbalances × 4
# compensator ratings × both unit modes) on an unbalanced 4-wire LV feeder — see
# `bench/sequence_objective_norms.jl`:
#
#   formulation          converged   median iters   max iters
#   :squared                 40/40             21          28
#   :magnitude (ε=1e-3)      40/40             19          59
#   epigraph                 37/40             40         304
#   :magnitude (ε=1e-9)      27/40            116        3000
#
# The epigraph reports `LOCALLY_INFEASIBLE` on 3/40, all high-compensator-
# authority cases. The shifted norm at a sensibly-sized ε never failed. This
# project ranks convergence reliability above wall clock, so `:magnitude` is the
# smoothed form.
#
# ── ε is a conditioning knob, and its safe range depends on the use ────────────
# `smooth_norm` approximates ‖·‖₂ by √(x² + y² + ε²) − ε, a uniform ε-accurate
# UNDERestimator: 0 ≤ ‖·‖₂ − smooth_norm ≤ ε, with equality at the origin. It is
# C^∞ everywhere including the origin, where the exact norm's AD gradient is
# 0/0 and the epigraph's constraint gradient vanishes.
#
# There are two regimes, and guidance that is correct in one is wrong in the
# other:
#
#   The norm IS the objective (this file's `:magnitude` terms). The solver's
#   endgame happens inside the smoothed region of width ε, so ε controls
#   conditioning directly. Measured: ε_rel 1e-2…1e-4 converges in ~20 iterations;
#   1e-6 costs ~4×; 1e-9 fails outright on a third of cases. Use a LARGE ε.
#   The accuracy price is irrelevant — ε_rel = 1e-2 still resolves |V₂| to
#   ~1e-7 V against an EN 50160 VUF limit of ~4.6 V on a 230 V base.
#
#   The norm is a COEFFICIENT in a term whose optimum is not at zero (e.g. a
#   current-linear conduction loss a·|I|, PowerOptLab's use). The solver never
#   enters the smoothed region, ε is invisible to conditioning, and it can be
#   made as small as the accuracy target wants. Upstream measurements there
#   report iteration counts identical from ε_rel 1e-2 down to 1e-18.
#
# Do not copy an ε policy across that boundary in either direction.
#
# ε must be strictly positive: at an exactly-zero argument the exact norm's AD
# gradient is 0/0 and Ipopt rejects the model (INVALID_MODEL) before the barrier
# reformulation can introduce any slack.
#
# ── Warning: ε in a weighted combination ───────────────────────────────────────
# For a pure norm objective ε does not move the minimiser — √(x²+ε²) − ε is
# still minimised at x = 0 — it only flattens the gradient near zero, which
# stops the solver a little earlier and looser. In a WEIGHTED combination such
# as `generation_cost + λ · unbalance`, that flattened gradient competes against
# the other term, so ε does shift the trade-off point. Treat ε as part of the
# model there, and report it alongside λ.
#
# Background.
#   Nesterov, "Smooth minimization of non-smooth functions", Math. Program. 103,
#     127–152 (2005) — the O(μ) accuracy versus O(1/μ) gradient-Lipschitz
#     trade-off that the two regimes above are two ends of.
#   Chen & Mangasarian, "A class of smoothing functions for nonlinear and mixed
#     complementarity problems", Comput. Optim. Appl. 5, 97–138 (1996).

# Default relative smoothing for a MINIMISED norm. Chosen from the measurements
# above, not from solver tolerance: see the two-regime note.
const _SMOOTH_NORM_EPS_REL = 1e-3

"""
    smooth_norm_value(x, y, eps) -> Float64

Plain-number evaluation of the shifted smooth norm `√(x² + y² + ε²) − ε`, for
tests and post-solve reporting. Mirrors the JuMP expression built by
[`smooth_norm`](@ref) exactly.
"""
smooth_norm_value(x::Real, y::Real, eps::Real) =
    sqrt(Float64(x)^2 + Float64(y)^2 + Float64(eps)^2) - Float64(eps)

"""
    BMOPFTools.smooth_norm(ctx, x, y; scale, eps_rel=1e-3, annotate=true, name="")

Smooth 2-norm `√(x² + y² + ε²) − ε` of the complex quantity `(x, y)`, as a JuMP
**expression** on `ctx`'s model. `x`/`y` may be variables, affine expressions, or
numbers in the model's working units.

Returns an expression, not a lifted variable with an auxiliary equality. Both
compute the same function, but the lifted form puts a possibly-tiny magnitude
inside a squared equality whose residual tolerance is absolute, and the
expression form adds no variable and no constraint.

# Sizing ε
`ε = eps_rel · scale`, where `scale` is the quantity's characteristic magnitude
**in the model's working units** — a conductor rating for a current, a nominal
voltage for a voltage. Declaring ε relative to the quantity's own scale makes
the relative smoothing identical across a heterogeneous fleet (an absolute ε
penalises small devices) and identical in SI and per-unit, provided `scale` is
expressed in the same units as `x`/`y`. In per-unit that usually means
`scale = 1.0`; in SI, the physical rating. `ctx.bases` carries the conversion.

`eps_rel` defaults to `$(_SMOOTH_NORM_EPS_REL)`, which is right when this norm is
being **minimised**. When the norm is instead a coefficient in a term whose
optimum is away from zero, a far smaller `eps_rel` is free. The file-level
comment in `ext/BMOPFOpfExt/objectives.jl` gives the measurements behind both.

# Accuracy
Uniform one-sided error: `0 ≤ ‖(x,y)‖₂ − smooth_norm(x,y) ≤ ε`, with equality at
the origin. The approximation always UNDERestimates, so a penalty built on it is
biased low by at most `ε` per term — a closed-form budget, not a tuning knob.

# Differentiability
`annotate=true` records a differentiability annotation on `ctx` naming this
smoothing, so `opf_differentiability_annotations` and `opf_research_hashes`
report it rather than leaving a silent approximation in the model.
"""
function BMOPFTools.smooth_norm(ctx::OpfContext, x, y;
                                scale::Real,
                                eps_rel::Real = _SMOOTH_NORM_EPS_REL,
                                annotate::Bool = true,
                                name::AbstractString = "")
    scale > 0 || throw(ArgumentError(
        "smooth_norm: `scale` must be strictly positive, got $scale. It is the " *
        "quantity's characteristic magnitude in the model's working units and " *
        "sets ε = eps_rel · scale."))
    eps_rel > 0 || throw(ArgumentError(
        "smooth_norm: `eps_rel` must be strictly positive, got $eps_rel. At an " *
        "exactly-zero argument the unsmoothed norm's AD gradient is 0/0 and " *
        "Ipopt rejects the model outright."))
    eps = Float64(eps_rel) * Float64(scale)
    if annotate
        label = isempty(name) ? "smooth_norm" : "smooth_norm[$name]"
        # `:nonsmooth_operator` marks the SITE: an exact 2-norm here would be
        # nonsmooth at the origin. The surrogate stamped in its place is
        # C^infinity, hence `blocking=false` — this is a reproducibility record
        # of an approximation and its epsilon, not an AD hazard.
        BMOPFTools.register_opf_differentiability_annotation!(
            ctx, Symbol("$(label)@eps=$(eps)");
            kind = :nonsmooth_operator,
            description = "2-norm replaced by the shifted smooth norm " *
                          "sqrt(x^2 + y^2 + eps^2) - eps (eps = $(eps), " *
                          "eps_rel = $(eps_rel), scale = $(scale)); " *
                          "underestimates the exact norm by at most eps. The " *
                          "surrogate is differentiable everywhere; eps is baked " *
                          "in as a constant and must not be made a parameter.",
            owner = :BMOPFTools,
            blocking = false,
            metadata = Dict("eps" => eps, "eps_rel" => Float64(eps_rel),
                            "scale" => Float64(scale), "form" => "shifted_2norm"),
            replace = true)
    end
    return JuMP.@expression(ctx.model, sqrt(x^2 + y^2 + eps^2) - eps)
end

# ── Symmetrical components ────────────────────────────────────────────────────
# One definition of V₀/V₁/V₂, shared by the bus sequence BOUNDS
# (`vpos_min`/`vpos_max`/`vneg_max`/`vzero_max`, see `bus.jl`) and by the
# sequence objective terms below. Two independent copies of the Fortescue
# transform would be free to drift apart, and a bound that disagreed with the
# objective penalising the same quantity is the kind of inconsistency nothing
# would catch.
#
# α = exp(j2π/3): Re(α) = −0.5, Im(α) = √3/2
#   V₀ = (Va + Vb + Vc)/3          zero sequence
#   V₁ = (Va + α·Vb + α²·Vc)/3     positive sequence
#   V₂ = (Va + α²·Vb + α·Vc)/3     negative sequence
#
# The transform is LINEAR in the rectangular voltage variables, so every
# component comes back as an affine expression: `:squared` penalties on them are
# plain quadratics, and only `:magnitude` needs `smooth_norm`.

const _SEQUENCE_COMPONENTS = (:zero, :positive, :negative)

"""
    _sequence_voltage_terms(model, vr, vi, bid, phase_all, neutral, grounded)

Return `(zero=(re,im), positive=(re,im), negative=(re,im))` for a three-phase
bus, as affine JuMP expressions.

The transform's input is the phase-to-NEUTRAL voltage when the bus has a
floating neutral, and the phase-to-ground voltage otherwise (grounded neutral,
or no neutral at all). Using phase-to-ground on a bus whose neutral floats would
fold the neutral displacement into the zero-sequence component and report
unbalance that the phase conductors do not actually see.

`phase_all` must be all three phase terminals in declaration order; the
symmetrical-component transform is defined over the full set, so a
grounded/source-fixed phase is still included (it is a legitimate zero).
"""
function _sequence_voltage_terms(model, vr, vi, bid, phase_all, neutral, grounded)
    length(phase_all) == 3 || throw(ArgumentError(
        "symmetrical components need exactly 3 phase terminals at bus '$bid', " *
        "got $(length(phase_all)): $(phase_all)"))
    s3 = sqrt(3.0) / 2.0
    neutral_floating = neutral !== nothing && !((bid, neutral) in grounded)
    dv(t) = neutral_floating ?
        (JuMP.@expression(model, vr[(bid,t)] - vr[(bid,neutral)]),
         JuMP.@expression(model, vi[(bid,t)] - vi[(bid,neutral)])) :
        (vr[(bid,t)], vi[(bid,t)])
    (dvr1, dvi1) = dv(phase_all[1])
    (dvr2, dvi2) = dv(phase_all[2])
    (dvr3, dvi3) = dv(phase_all[3])
    return (
        zero = (JuMP.@expression(model, (dvr1 + dvr2 + dvr3) / 3),
                JuMP.@expression(model, (dvi1 + dvi2 + dvi3) / 3)),
        positive = (
            JuMP.@expression(model, (dvr1 - 0.5*dvr2 - s3*dvi2 - 0.5*dvr3 + s3*dvi3) / 3),
            JuMP.@expression(model, (dvi1 + s3*dvr2 - 0.5*dvi2 - s3*dvr3 - 0.5*dvi3) / 3)),
        negative = (
            JuMP.@expression(model, (dvr1 - 0.5*dvr2 + s3*dvi2 - 0.5*dvr3 - s3*dvi3) / 3),
            JuMP.@expression(model, (dvi1 - s3*dvr2 - 0.5*dvi2 + s3*dvr3 - 0.5*dvi3) / 3)),
    )
end

"""
    BMOPFTools.opf_sequence_voltage(ctx, bus; component=:negative) -> (re, im)

Symmetrical-component voltage at `bus` as a pair of affine JuMP expressions in
the model's working units. `component` is `:zero`, `:positive`, or `:negative`.

The same expressions the bus sequence bounds (`vneg_max`, `vzero_max`,
`vpos_min`/`vpos_max`) are built from, so a penalty and a limit on the same
quantity cannot disagree.

Reference: phase-to-neutral where the bus neutral floats, phase-to-ground
otherwise. Requires a three-phase bus — symmetrical components are not defined
over a partial phase set, and this throws rather than silently reporting the
unbalance of an imagined three-phase bus.

The transform is linear, so `re`/`im` are affine: `re^2 + im^2` is an exact
smooth quadratic and needs no smoothing. Only a MAGNITUDE penalty (`|V₂|`
rather than `|V₂|²`) needs [`smooth_norm`](@ref).
"""
function BMOPFTools.opf_sequence_voltage(ctx::OpfContext, bus::AbstractString;
                                         component::Symbol = :negative)
    component in _SEQUENCE_COMPONENTS || throw(ArgumentError(
        "unknown sequence component '$component'; expected one of " *
        join(_SEQUENCE_COMPONENTS, ", ")))
    bus_dict = get(get(ctx.net, "bus", Dict{String,Any}()), bus, nothing)
    bus_dict isa AbstractDict || throw(ArgumentError(
        "bus '$bus' is not in the network"))
    terminals = get(ctx.bus_terminals, bus, String[])
    neutral   = BMOPFTools._neutral_terminal(bus_dict)
    phase_all = [t for t in terminals if t != neutral]
    terms = _sequence_voltage_terms(ctx.model, ctx.vars[:vr], ctx.vars[:vi],
                                    bus, phase_all, neutral, ctx.grounded)
    return getfield(terms, component)
end
