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

# ── Network losses ────────────────────────────────────────────────────────────
# Active loss in a two-port element, from the same per-device terminal-injection
# ledger `results.jl` uses post-solve, so the objective the solver minimises and
# the loss the result reports are the same quantity by construction:
#
#     S_loss = Σ_terminals V · conj(I_into_element),   I_into_element = −I_into_bus
#     P_loss = Σ_terminals −(vr·cr + vi·ci)
#
# BILINEAR in (V, I), hence an exact smooth quadratic. A loss objective needs no
# smoothing and no magnitude: `smooth_norm` has no business here. (Semiconductor
# CONDUCTION loss is different — it is linear in |I| and does need the norm, but
# that is a device model, not a network loss.)
#
# Grounded terminals contribute V = 0 and are dropped, matching `_branch_loss`.
# In per-unit each term carries the per-bus power base over the system base, so
# a network with heterogeneous bus bases totals correctly.

const _LOSS_BLOCKS = ("line", "transformer", "switch")

"""
    _element_loss_expr(ctx, records) -> JuMP expression

Active-power loss of one two-port element from its terminal-injection records,
in the model's working units.
"""
function _element_loss_expr(ctx::OpfContext, records)
    vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
    terms = Any[]
    for (bus, t, cr_e, ci_e) in records
        (bus, t) in ctx.grounded && continue      # V ≡ 0 there
        w = ctx.bases === nothing ? 1.0 :
            _ac_power_base(ctx.bases, bus) / ctx.bases.s_base
        push!(terms, JuMP.@expression(ctx.model,
            -w * (vr[(bus,t)] * cr_e + vi[(bus,t)] * ci_e)))
    end
    isempty(terms) && return JuMP.@expression(ctx.model, 0.0)
    return JuMP.@expression(ctx.model, sum(terms))
end

"""
    BMOPFTools.opf_element_loss(ctx, block, id) -> JuMP expression

Active-power loss of one two-port element (`block` is `"line"`, `"transformer"`,
or `"switch"`) as a JuMP expression in the model's working units.

Built from the same per-device terminal-injection ledger that the post-solve
result uses, so `result[block][id]["loss"]["p_loss"]` and this expression are
the same quantity — an objective built on it cannot silently disagree with the
loss that gets reported.

The expression is bilinear in voltage and current, hence an exact smooth
quadratic: a loss objective needs no smoothing.
"""
function BMOPFTools.opf_element_loss(ctx::OpfContext, block::AbstractString,
                                     id::AbstractString)
    block in _LOSS_BLOCKS || throw(ArgumentError(
        "unknown loss block '$block'; expected one of " * join(_LOSS_BLOCKS, ", ")))
    recs = get(get(ctx.branch_inj, block, Dict{String,Any}()), id, nothing)
    recs === nothing && throw(ArgumentError(
        "no terminal-injection records for $block '$id'. Either the id is not " *
        "in the network, or device constraints have not been built yet — the " *
        "ledger is populated during `build_opf_model`."))
    return _element_loss_expr(ctx, recs)
end

"""
    BMOPFTools.opf_total_loss(ctx; blocks=("line","transformer","switch")) -> expr

Total active-power loss over every two-port element in `blocks`, as a JuMP
expression in the model's working units. The quantity `result["losses"]["p_loss"]`
reports.

Sums [`opf_element_loss`](@ref) over the ledger, so it is an exact smooth
quadratic and matches the reported total by construction.

!!! note "Losses are not generation cost"
    Minimising losses is NOT the same as minimising `generation_cost`, and on a
    network with heterogeneous generation prices the two can disagree sharply:
    least-loss dispatch happily sources from an expensive nearby unit to avoid
    transporting cheap distant power. Combine them deliberately with explicit
    weights rather than assuming one proxies for the other.
"""
function BMOPFTools.opf_total_loss(ctx::OpfContext; blocks = _LOSS_BLOCKS)
    for b in blocks
        b in _LOSS_BLOCKS || throw(ArgumentError(
            "unknown loss block '$b'; expected a subset of " *
            join(_LOSS_BLOCKS, ", ")))
    end
    terms = Any[]
    for b in blocks, (_, recs) in get(ctx.branch_inj, b, Dict{String,Any}())
        push!(terms, _element_loss_expr(ctx, recs))
    end
    isempty(terms) && return JuMP.@expression(ctx.model, 0.0)
    return JuMP.@expression(ctx.model, sum(terms))
end

# ── Physical scales ───────────────────────────────────────────────────────────
# Objective terms must mean the SAME THING in `per_unit=true` and `per_unit=false`,
# and must keep meaning it under a future nondimensionalisation strategy. The
# engine already sets this precedent for generation cost: `_pu_scale_generators!`
# multiplies every cost coefficient by `s_base` in the per-unit working net, so
# the `s_base` factors cancel and the objective comes out in the same
# currency/hour either way (see per_unit.jl).
#
# Every term here follows the same rule, made explicit:
#
#   * a quantity EXPRESSION is in the model's working units;
#   * a term declares the PHYSICAL unit it is measured in;
#   * a weight is declared in [objective-unit per physical-unit];
#   * the engine multiplies the expression by the physical value of one working
#     unit before applying the weight.
#
# So the composed objective is a physical quantity, identical in both unit modes,
# and a weight tuned once stays correct. Nothing is left for the caller to
# reconcile by hand.

"""
    BMOPFTools.opf_physical_scale(ctx, unit; bus=nothing) -> Float64

Physical value of one working unit of `unit` — the factor that converts an
expression in the model's working units into SI. Returns `1.0` throughout when
the model was built in SI (`per_unit=false`), so a term written against this is
correct in both modes without a branch.

`unit` is one of `:W`, `:var`, `:VA` (scaled by the bus/system power base),
`:V`, `:V2` (bus voltage base, squared for `:V2`), `:A`, `:A2`, or
`:dimensionless`. Voltage and current bases are PER BUS, so `bus` is required
for those.
"""
function BMOPFTools.opf_physical_scale(ctx::OpfContext, unit::Symbol;
                                       bus::Union{AbstractString,Nothing}=nothing)
    ctx.bases === nothing && return 1.0          # already SI
    needs_bus(u) = u in (:V, :V2, :A, :A2)
    if needs_bus(unit)
        bus === nothing && throw(ArgumentError(
            "opf_physical_scale: unit '$unit' has a PER-BUS base, so `bus` is " *
            "required. Passing a system-wide scale would be wrong on any " *
            "network with more than one voltage level."))
    end
    if unit === :dimensionless
        return 1.0
    elseif unit in (:W, :var, :VA)
        return bus === nothing ? Float64(ctx.bases.s_base) :
                                 _ac_power_base(ctx.bases, bus)
    elseif unit === :V
        return Float64(get(ctx.bases.v_base, String(bus), 1.0))
    elseif unit === :V2
        return Float64(get(ctx.bases.v_base, String(bus), 1.0))^2
    elseif unit === :A
        return Float64(get(ctx.bases.i_base, String(bus), 1.0))
    elseif unit === :A2
        return Float64(get(ctx.bases.i_base, String(bus), 1.0))^2
    end
    throw(ArgumentError(
        "opf_physical_scale: unknown unit '$unit'; expected :W, :var, :VA, " *
        ":V, :V2, :A, :A2, or :dimensionless"))
end

"""
    _quantity_scale(ctx, unit; bus) -> Float64

Characteristic PHYSICAL magnitude of `unit` at `bus` — volts for `:V`, amps for
`:A`, VA for `:W`/`:var`/`:VA` — returning the same number in `per_unit=true`
and `per_unit=false`.

Distinct from [`opf_physical_scale`](@ref), which is the working→physical
CONVERSION FACTOR. `smooth_norm`'s eps needs the quantity's characteristic
MAGNITUDE. Conflating the two makes eps differ between unit modes, which
silently changes the smoothing and therefore the answer — a bug this file's own
per-unit/SI equivalence test caught.

ONE rule for every unit, so voltage and current smoothing stay commensurate:

  * voltage — the bus's own declared bound in the WORKING net, converted with
    the same factor, so both modes reach the same volts (`v_max_pu * v_base` in
    per-unit, `v_max_V * 1.0` in SI);
  * current — `s_base / v_scale`, mirroring the engine's own
    `i_base = s_base / v_base` (per_unit.jl). `ctx.manifest.s_base` is populated
    in both modes, so this is mode-independent too;
  * power — `s_base`.

The consequence that matters: the RELATIVE smoothing `eps / scale` is then the
same number for a voltage penalty and a current penalty, at the same `eps_rel`,
in either unit mode. A single `eps_rel` therefore means one thing everywhere.
"""
function _quantity_scale(ctx::OpfContext, unit::Symbol;
                         bus::Union{AbstractString,Nothing}=nothing)
    s_base = Float64(ctx.manifest.s_base)
    unit in (:W, :var, :VA) && return s_base
    unit === :dimensionless && return 1.0
    bus === nothing && throw(ArgumentError(
        "_quantity_scale: unit '$unit' is per-bus; `bus` is required"))
    factor = BMOPFTools.opf_physical_scale(ctx, :V; bus=bus)
    b = get(get(ctx.net, "bus", Dict{String,Any}()), String(bus), nothing)
    working = 1.0
    if b isa AbstractDict
        for field in ("v_max", "v_min")
            v = get(b, field, nothing)
            v isa AbstractVector && !isempty(v) || continue
            cand = maximum(abs(Float64(x)) for x in v if x isa Real; init=0.0)
            if cand > 0
                working = cand
                break
            end
        end
    end
    v_scale = working * factor
    unit in (:V, :V2) && return unit === :V2 ? v_scale^2 : v_scale
    unit in (:A, :A2) && begin
        i_scale = v_scale > 0 ? s_base / v_scale : 1.0
        return unit === :A2 ? i_scale^2 : i_scale
    end
    throw(ArgumentError(
        "_quantity_scale: unknown unit '$unit'; expected :W, :var, :VA, :V, " *
        ":V2, :A, :A2, or :dimensionless"))
end

# ── Norm reduction ────────────────────────────────────────────────────────────

const _NORM_MODES = (:squared, :magnitude, :max)

# Physical unit produced by each norm mode, given the unit of the quantity.
_norm_result_unit(norm::Symbol, quantity_unit::Symbol) =
    norm === :magnitude ? quantity_unit :
        quantity_unit === :V ? :V2 : quantity_unit === :A ? :A2 : quantity_unit

"""
    BMOPFTools.opf_reduce_norm(ctx, pairs; norm=:squared, scale=1.0,
                               eps_rel=1e-3, name="") -> expr

Reduce a collection of complex quantities `pairs` — a vector of `(re, im)`
expression pairs — to one scalar JuMP expression, using `norm`:

| `norm`       | expression            | exact? | notes |
|--------------|-----------------------|--------|-------|
| `:squared`   | `Σ (reᵢ² + imᵢ²)`     | yes    | L2. Cheapest, most reliable. Spreads the penalty over all targets. Default. |
| `:magnitude` | `Σ ‖(reᵢ, imᵢ)‖₂`     | to ε   | Group-lasso. Drives individual targets to zero rather than shrinking all. Uses [`smooth_norm`](@ref). |
| `:max`       | `maxᵢ (reᵢ² + imᵢ²)`  | yes    | L∞ via a LINEAR epigraph. `max` is monotone under squaring, so no root is needed. |

Choosing between them is a modelling decision, not an implementation detail:
`:squared` improves everything a little, `:magnitude` fixes a few targets
completely, `:max` protects the worst one. They give different answers.

`pairs` must already be in the units you want the result in — see
[`opf_physical_scale`](@ref). `:squared` and `:max` return the SQUARE of that
unit; `:magnitude` returns the unit itself.

`:max` adds one variable and `length(pairs)` linear constraints; the others add
neither. `scale`/`eps_rel` are used only by `:magnitude`.
"""
function BMOPFTools.opf_reduce_norm(ctx::OpfContext, pairs;
                                    norm::Symbol = :squared,
                                    scale::Real = 1.0,
                                    eps_rel::Real = _SMOOTH_NORM_EPS_REL,
                                    name::AbstractString = "")
    norm in _NORM_MODES || throw(ArgumentError(
        "unknown norm '$norm'; expected one of " * join(_NORM_MODES, ", ")))
    isempty(pairs) && throw(ArgumentError(
        "opf_reduce_norm: nothing to reduce. An empty penalty is almost always " *
        "a mis-specified target list rather than an intentional zero."))
    m = ctx.model
    if norm === :squared
        return JuMP.@expression(m, sum(re^2 + im^2 for (re, im) in pairs))
    elseif norm === :magnitude
        parts = [BMOPFTools.smooth_norm(ctx, re, im; scale=scale, eps_rel=eps_rel,
                                        name = isempty(name) ? "" : "$(name)[$k]")
                 for (k, (re, im)) in enumerate(pairs)]
        return JuMP.@expression(m, sum(parts))
    else # :max — linear epigraph over squared magnitudes
        t = JuMP.@variable(m, lower_bound = 0.0,
                           base_name = isempty(name) ? "objmax" : "objmax_$(name)")
        for (re, im) in pairs
            JuMP.@constraint(m, re^2 + im^2 <= t)
        end
        JuMP.set_start_value(t, max(1e-9, (Float64(scale) * 1e-2)^2))
        return JuMP.@expression(m, t)
    end
end

# ── Objective terms ───────────────────────────────────────────────────────────

"""
    BMOPFTools.opf_sequence_term(ctx, buses; component=:negative, norm=:squared,
                                 weight=1.0, eps_rel=1e-3, name=nothing)

An [`OpfObjectiveTerm`](@ref) penalising a symmetrical-component voltage over
`buses`. `buses` may be one bus id or a collection; every bus must be
three-phase.

The per-bus voltage expressions are converted to **volts** before reduction, so
a network spanning several voltage levels is weighted consistently and the term
means the same thing in `per_unit=true` and `per_unit=false`. `weight` is
therefore in objective-units per V² (`norm=:squared` or `:max`) or per V
(`:magnitude`).

`component=:negative` is the usual unbalance objective; `:zero` targets neutral
displacement, which is the quantity that actually heats a neutral conductor.
"""
function BMOPFTools.opf_sequence_term(ctx::OpfContext, buses;
                                      component::Symbol = :negative,
                                      norm::Symbol = :squared,
                                      weight::Real = 1.0,
                                      eps_rel::Real = _SMOOTH_NORM_EPS_REL,
                                      name::Union{Symbol,Nothing} = nothing)
    ids = buses isa AbstractString ? [String(buses)] : [String(b) for b in buses]
    isempty(ids) && throw(ArgumentError(
        "opf_sequence_term: `buses` is empty; nothing would be penalised."))
    pairs = Any[]; scales = Float64[]
    for b in ids
        (re, ie) = BMOPFTools.opf_sequence_voltage(ctx, b; component=component)
        vb = BMOPFTools.opf_physical_scale(ctx, :V; bus=b)
        # eps must be sized from the quantity's characteristic MAGNITUDE in
        # volts, not from the conversion factor — see `_quantity_scale`.
        push!(scales, _quantity_scale(ctx, :V; bus=b))
        # Convert to VOLTS here, so buses at different voltage levels are
        # compared on one physical footing and the weight is mode-independent.
        push!(pairs, (JuMP.@expression(ctx.model, vb * re),
                      JuMP.@expression(ctx.model, vb * ie)))
    end
    tname = name === nothing ? Symbol("v", component, "_", norm) : name
    expr = BMOPFTools.opf_reduce_norm(ctx, pairs; norm=norm,
                                      scale=maximum(scales), eps_rel=eps_rel,
                                      name=String(tname))
    return BMOPFTools.OpfObjectiveTerm(tname, expr;
        weight = weight,
        units  = _norm_result_unit(norm, :V),
        purpose = "$(component)-sequence voltage penalty over " *
                  "$(length(ids)) bus(es), $(norm) norm")
end

"""
    BMOPFTools.opf_loss_term(ctx; blocks=("line","transformer","switch"),
                             weight=1.0, name=:losses)

An [`OpfObjectiveTerm`](@ref) for total active-power loss, in **watts**, so the
term and its weight mean the same thing in both unit modes. `weight` is in
objective-units per W.
"""
function BMOPFTools.opf_loss_term(ctx::OpfContext;
                                  blocks = _LOSS_BLOCKS,
                                  weight::Real = 1.0,
                                  name::Symbol = :losses)
    working = BMOPFTools.opf_total_loss(ctx; blocks=blocks)
    s = BMOPFTools.opf_physical_scale(ctx, :W)      # system power base, or 1.0 in SI
    return BMOPFTools.OpfObjectiveTerm(name,
        JuMP.@expression(ctx.model, s * working);
        weight = weight, units = :W,
        purpose = "total active-power loss over " * join(blocks, "/"))
end

"""
    BMOPFTools.opf_generation_cost_term(ctx; weight=1.0, name=:generation_cost)

An [`OpfObjectiveTerm`](@ref) wrapping [`generation_cost`](@ref), in
currency/hour. Already mode-independent: the per-unit working net pre-scales
every cost coefficient by `s_base`, so the `s_base` factors cancel.
"""
BMOPFTools.opf_generation_cost_term(ctx::OpfContext; weight::Real = 1.0,
                                    name::Symbol = :generation_cost) =
    BMOPFTools.OpfObjectiveTerm(name, BMOPFTools.generation_cost(ctx);
        weight = weight, units = :currency_per_hour,
        purpose = "total active-power generation cost rate")

# ── Composition ───────────────────────────────────────────────────────────────

"""
    BMOPFTools.set_opf_objective!(ctx, terms; sense=:min)

Set a weighted sum of [`OpfObjectiveTerm`](@ref)s, `Σ tᵢ.weight * tᵢ.expr`,
instead of the bare generation cost. Pair with
`build_opf_model(...; add_objective=false)`.

Every term's expression is in the PHYSICAL unit the term declares, so the
composed objective is a physical quantity: the same specification produces the
same objective value and the same dispatch in `per_unit=true` and
`per_unit=false`, and a weight tuned once stays correct. This is the same
convention the engine already uses for generation cost.

Each term is registered under a semantic key and declared as a regularization
carrying its weight, units and purpose, so the composition reaches
[`opf_research_hashes`](@ref) — a weighted objective whose weights are not
recorded is not a reproducible experiment.

!!! note "Weights still carry meaning you must supply"
    Unit-consistency is handled; COMMENSURABILITY is not, and cannot be. Summing
    currency/hour with V² is only meaningful once the weight states the exchange
    rate you intend, and no check can infer that for you. Note also that
    `:squared`/`:max` penalties are in the square of the quantity's unit while
    `:magnitude` is in the unit itself, so switching `norm` changes what a given
    weight means — the declared `units` on each term make that visible after the
    fact.
"""
function BMOPFTools.set_opf_objective!(ctx::OpfContext,
                                       terms::AbstractVector;
                                       sense::Symbol = :min)
    sense in (:min, :max) || throw(ArgumentError(
        "objective sense must be :min or :max; got $sense"))
    isempty(terms) && throw(ArgumentError(
        "set_opf_objective!: no terms. An empty objective makes every feasible " *
        "point optimal; use `solve_feasibility_opf` if that is what you want."))
    names = [t.name for t in terms]
    if length(unique(names)) != length(names)
        dups = unique([n for n in names if count(==(n), names) > 1])
        throw(ArgumentError(
            "duplicate objective term names: " * join(sort(string.(dups)), ", ") *
            ". Each term is registered under its name, so names must be unique."))
    end
    return _run_opf_stage!(ctx, :objective, () -> begin
        for t in terms
            key = BMOPFTools.OpfModelKey(:objective, :composed, String(t.name))
            BMOPFTools.register_opf_objective_term!(ctx, key, t.expr; replace=true)
            BMOPFTools.register_opf_regularization!(
                ctx, Symbol("objective_term_", t.name);
                method   = :weighted_objective_term,
                weight   = t.weight,
                term_key = key,
                purpose  = t.purpose,
                units    = t.units,
                owner    = :BMOPFTools,
                replace  = true)
        end
        total = JuMP.@expression(ctx.model,
            sum(Float64(t.weight) * t.expr for t in terms))
        sense === :min ? JuMP.@objective(ctx.model, Min, total) :
                         JuMP.@objective(ctx.model, Max, total)
    end; required = (:device_physics,))
end
