# IBR constraints for the four-wire IVR-EN OPF.
#
# Topology → voltage reference mapping:
#   FOUR_LEG    — phase-to-neutral; neutral is the last terminal in terminal_map
#   THREE_LEG   — line-to-line (delta); no neutral current; one current per
#                 conductor pair (k, k mod n + 1)
#   SINGLE_PHASE — phase-to-reference; terminal_map = [phase, ref]; one current
#
# Constant power-factor (PF) mode
# ────────────────────────────────
# When the IBR references a control_profile with a "power_factor" sub-object
# the signed field "pf" determines the Q/P coupling:
#
#   pf > 0  (lagging, absorbing VAr):  Q_k = -tan(arccos(pf))  · P_k
#   pf < 0  (leading,  injecting VAr): Q_k = +tan(arccos(|pf|))· P_k
#
# Implemented as the bilinear equality:
#   sign(pf) · Q_k + tan_phi · P_k = 0
#
# which Ipopt handles exactly — no relaxation or bound approximation.
#
# Without a PF control profile, q_min/q_max box bounds are used; these are
# normally filled by _apply_ibr_augmentation! before the OPF is called.

"Declare `cri`/`cii` IBR current variables (one per phase conductor)."
function _add_ibr_variables!(model, net)
    cri = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    cii = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    nlabels = BMOPFTools._neutral_labels(net)

    for (inv_id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        tm   = Vector{String}(get(inv, "terminal_map", String[]))
        topo = get(inv, "topology", "FOUR_LEG")
        n_ph = topo == "THREE_LEG" ? length(tm) :
               topo == "SINGLE_PHASE" ? 1 :
               length(_phase_positions(tm, nlabels))   # FOUR_LEG
        for k in 1:n_ph
            cri[(inv_id, k)] = @variable(model, base_name = "cri_$(inv_id)_$(k)")
            cii[(inv_id, k)] = @variable(model, base_name = "cii_$(inv_id)_$(k)")
        end
    end
    cri, cii
end

# Warm-start an IBR phase current variable near the *physical* (high-voltage,
# low-current) root of the bilinear power equations. The pinned-/box-power
# problem P_k = dvr·cri + dvi·cii also admits a spurious low-voltage/high-current
# root; from the default cri=cii=0 start Ipopt can slide into it, and per-unit
# scaling (tiny currents/powers) makes that far more likely — collapsing FOUR_LEG
# phase voltages. Seeding I ≈ conj(S)/conj(V) at the terminals' nominal voltage
# start (already set by `_set_voltage_start_values!`, in whatever unit system the
# model is built) puts the initial guess on the physical branch in BOTH SI and
# per-unit modes, since S = V·conj(I) ⇒ I = conj(S/V) = conj(S)/conj(V).
function _warmstart_ibr_current!(cri_var, cii_var, dvr, dvi, p_tgt, q_tgt)
    # dvr/dvi are the phase-to-reference voltage-difference expressions; read their
    # value at the current variable starts (the voltage vars are already seeded).
    vr0 = _safe_start_value(dvr); vi0 = _safe_start_value(dvi)
    v2  = vr0^2 + vi0^2
    v2 > 1e-12 || return                       # degenerate start — leave at 0
    # I = conj(S)/conj(V): cri = (P·vr − Q·vi)/|V|², cii = (P·vi + Q·vr)/|V|²
    JuMP.set_start_value(cri_var, (p_tgt*vr0 - q_tgt*vi0) / v2)
    JuMP.set_start_value(cii_var, (p_tgt*vi0 + q_tgt*vr0) / v2)
    return
end

# Value of a scalar (variable or affine expression) at its start values; used to
# read the seeded voltage-difference for the IBR current warm-start. Missing
# starts count as 0 (the JuMP default before seeding).
_safe_start_value(x::JuMP.VariableRef) =
    (s = JuMP.start_value(x); s === nothing ? 0.0 : s)
function _safe_start_value(x::JuMP.AffExpr)
    v = JuMP.constant(x)
    for (var, coef) in x.terms
        s = JuMP.start_value(var)
        v += coef * (s === nothing ? 0.0 : s)
    end
    v
end

# Estimate a per-phase (P, Q) operating point for the current warm-start, in the
# model's units. Prefers the midpoint of the active-power box (pinned ⇒ the pinned
# value); reactive power comes from the constant-PF law when present, else the
# reactive box midpoint. A missing active box falls back to ~90 % of s_max (a
# sensible non-degenerate seed). Only used to steer Ipopt onto the physical root;
# the true operating point is decided by the constraints, so a rough seed suffices.
function _ibr_phase_target(idx, p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign)
    pmid(lo, hi, i) = length(hi) >= i ?
        (length(lo) >= i ? 0.5*(lo[i] + hi[i]) : hi[i]) :
        (length(lo) >= i ? lo[i] : nothing)
    pt = pmid(p_min, p_max, idx)
    if pt === nothing
        pt = length(smax) >= idx ? 0.9*smax[idx] : 0.0
    end
    if tan_phi !== nothing
        # sign(pf)>0 (lagging): Q = −tan_phi·P; sign(pf)<0 (leading): Q = +tan_phi·P.
        qt = -pf_sign * tan_phi * pt
    else
        qt = pmid(q_min, q_max, idx)
        qt === nothing && (qt = 0.0)
    end
    (Float64(pt), Float64(qt))
end

# Resolved Volt-var / Volt-watt droop curve, ready to stamp into the model.
# `triples`/`eps` are in model voltage units (SI volts, or per-unit when the
# model is solved per-unit); `ref` selects the per-phase normalisation base.
struct DroopCurve{B,T,K}
    baseline::B
    triples::T
    eps::Float64
    ref::Symbol           # :S_MAX | :P_MAX | :P_AVAILABLE | :VAR_MAX
    quantity::Symbol      # :PN | :PG | :PP   (monitored voltage quantity)
    averaged::Bool        # true ⇒ every phase sees the mean phase magnitude
    knots::K              # live working-unit breakpoints (possibly parameters)
    min_gap::Float64      # fixed feasibility guard derived from nominal knots
end

# Build a fixed-structure ReLU representation from working-unit points. When
# every point is numeric, retain the historical sparse representation exactly.
# Parameterized curves retain all segment pairs because a zero nominal slope may
# become nonzero after an update. The smoothing width and ordering tolerance stay
# tied to the nominal points, so parameter updates do not alter model structure.
function _curve_from_points(xs, ys, nominal_xs::Vector{Float64},
                            relu_eps::Float64, ref::Symbol,
                            quantity::Symbol, averaged::Bool)
    length(nominal_xs) == length(xs) || throw(ArgumentError(
        "nominal and live curve breakpoints must have equal length"))
    # Validate the source data even when a provider supplies live coefficients.
    # Provider registration must not turn malformed, non-increasing profile data
    # into a superficially feasible parameter-ordering constraint.
    breakpoints_to_triples(nominal_xs, zeros(length(nominal_xs)))
    if all(x -> x isa Real, xs) && all(y -> y isa Real, ys)
        base, numeric_triples = breakpoints_to_triples(
            Float64.(xs), Float64.(ys))
        triples = numeric_triples
        knots = Float64.(xs)
    else
        base = ys[1]
        triples = Tuple{Any,Any}[]
        for i in 1:(length(xs) - 1)
            # A structurally flat segment whose endpoints are fixed contributes
            # nothing, and should not retain a live 0/(x[i+1]-x[i]) expression.
            ys[i] isa Real && ys[i + 1] isa Real && ys[i] == ys[i + 1] && continue
            slope = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
            push!(triples, (slope, xs[i]))
            push!(triples, (-slope, xs[i + 1]))
        end
        knots = Any[xs...]
    end
    ε = relu_eps * (sum(nominal_xs) / length(nominal_xs))
    nominal_gap = minimum(diff(nominal_xs))
    min_gap = max(1e-9, 1e-6 * nominal_gap)
    return DroopCurve(base, triples, ε, ref, quantity, averaged, knots, min_gap)
end

function _enforce_curve_order!(model, curve::Union{DroopCurve,Nothing},
                               profile_id, law::Symbol)
    curve === nothing && return
    all(x -> x isa Real, curve.knots) && return
    for i in 1:(length(curve.knots) - 1)
        @constraint(model,
            curve.knots[i + 1] - curve.knots[i] >= curve.min_gap,
            base_name="$(law)_order_$(profile_id)_$(i)")
    end
    return
end

# The six `voltage_reference_type` enum values split into a monitored quantity
# (phase-to-neutral / phase-to-ground / phase-to-phase) and a per-phase-vs-average
# aggregation. Unknown values fall back to the PN-per-phase default with a warning.
const _VREF_VALUES = ("PN_PER_PHASE","PG_PER_PHASE","PP_PER_PHASE",
                      "PN_AVERAGED","PG_AVERAGED","PP_AVERAGED")
function _split_voltage_reference(raw)
    s = uppercase(String(raw))
    if !(s in _VREF_VALUES)
        @warn "volt-var/watt: unsupported voltage_reference '$raw' — using PN_PER_PHASE."
        return (:PN, false)
    end
    quantity = startswith(s, "PG") ? :PG : startswith(s, "PP") ? :PP : :PN
    (quantity, endswith(s, "AVERAGED"))
end

"""
    _monitor_U(ctx, vr, vi, bus, ph_terms, t_n, c, override_avg,
               inv_id, controller) -> Vector

Per-phase monitored-voltage magnitude expressions for droop curve `c`, one entry
per controlled phase in `ph_terms`:

- `:PG` → `|V_φ|` (phase-to-ground; ground is the rectangular-frame zero)
- `:PN` → `|V_φ − V_n|` (phase-to-neutral; falls back to PG with a warning if the
  IBR has no neutral terminal)
- `:PP` → `|V_φ − V_ψ|` with ψ the next phase cyclically (phase-to-phase)

When the effective aggregation is averaged (`override_avg`, else the curve's own
`averaged` flag) every phase is fed the mean of the per-phase magnitudes.
`override_avg` lets the IBR-level legacy `voltage_aggregation` field win when present.
The per-phase magnitudes are registered under `:pg`, `:pn`, or `:pp`; the actual
shared controller input is registered under the corresponding `:_averaged` key.
"""
function _monitor_U(ctx, vr, vi, bus, ph_terms, t_n, c::DroopCurve, override_avg,
                    inv_id, controller::Symbol)
    model = ctx.model
    n = length(ph_terms)
    averaged = override_avg === nothing ? c.averaged : override_avg
    quantity = c.quantity
    if quantity == :PN && t_n === nothing
        @warn "IBR at bus '$bus': PN voltage_reference but no neutral terminal — using PG."
        quantity = :PG
    elseif quantity == :PP && n < 2
        @warn "IBR at bus '$bus': PP voltage_reference needs ≥2 phases — using PG."
        quantity = :PG
    end
    quantity_ref = lowercase(String(quantity)) |> Symbol
    monitor_ref = averaged ? Symbol("$(String(quantity_ref))_averaged") : quantity_ref

    # Volt-var and Volt-watt can share the same monitored quantity. Reuse the
    # magnitude variables and quadratic constraints in that case, while still
    # registering the same live object under each controller-specific semantic
    # key. The cache is scoped to this build context and includes aggregation.
    cache = get!(ctx.extension_state, :BMOPFOpfExt_ibr_voltage_monitor_cache,
                 Dict{Any,Any}())
    cache_key = (String(inv_id), String(bus), Tuple(String.(ph_terms)),
                 t_n === nothing ? nothing : String(t_n), quantity, averaged)
    cached = get(cache, cache_key, nothing)
    if cached === nothing
        perphase = Vector{Any}(undef, n)
        for k in 1:n
            tk = ph_terms[k]
            semantic_index = (String(inv_id), quantity_ref, k)
            definition_callback = cref -> _register_semantic_constraint!(ctx,
                :ibr_voltage_magnitude_definition, semantic_index, cref)
            lower_callback = cref -> _register_semantic_constraint!(ctx,
                :ibr_voltage_magnitude_lower_bound, semantic_index, cref)
            if quantity == :PG
                perphase[k] = umag_var(model, vr[(bus,tk)], vi[(bus,tk)];
                    on_definition=definition_callback,
                    on_lower_bound=lower_callback)
            elseif quantity == :PN
                perphase[k] = umag_var(model,
                    @expression(model, vr[(bus,tk)] - vr[(bus,t_n)]),
                    @expression(model, vi[(bus,tk)] - vi[(bus,t_n)]);
                    on_definition=definition_callback,
                    on_lower_bound=lower_callback)
            else # :PP
                tj = ph_terms[mod1(k+1, n)]
                perphase[k] = umag_var(model,
                    @expression(model, vr[(bus,tk)] - vr[(bus,tj)]),
                    @expression(model, vi[(bus,tk)] - vi[(bus,tj)]);
                    on_definition=definition_callback,
                    on_lower_bound=lower_callback)
            end
        end
        ubar = averaged && n >= 1 ? @expression(model, sum(perphase) / n) : nothing
        cached = (perphase=perphase, averaged=ubar, quantity_ref=quantity_ref,
                  monitor_ref=monitor_ref)
        cache[cache_key] = cached
    end

    perphase = cached.perphase
    quantity_ref = cached.quantity_ref
    monitor_ref = cached.monitor_ref
    for k in 1:n
        BMOPFTools.register_opf_object!(ctx,
            BMOPFTools.opf_ibr_voltage_magnitude_key(inv_id, k;
                reference=quantity_ref, controller), perphase[k])
        averaged && BMOPFTools.register_opf_object!(ctx,
            BMOPFTools.opf_ibr_voltage_magnitude_key(inv_id, k;
                reference=monitor_ref, controller), cached.averaged)
    end
    if averaged && n >= 1
        return Any[cached.averaged for _ in 1:n]
    end
    perphase
end

"""
    _resolve_volt_var(vv, Uscale, relu_eps) -> DroopCurve | nothing

Build the reactive-power droop curve Q/Q_base = f(U) from a `volt_var` sub-object.
The monitored-voltage quantity/aggregation is taken from `voltage_reference` (any
of the six `voltage_reference_type` values; see [`_split_voltage_reference`]).
`q_unit` must be VA_FRACTION and `q_ref` VAR_MAX; other variants warn and skip so
the IBR falls back to its box bounds.
"""
function _resolve_volt_var(vv, Uscale::Float64, relu_eps::Float64;
                           coefficient=nothing, profile_id="")
    vv isa Dict || return nothing
    bps_si = Float64.(get(vv, "breakpoints", Float64[]))
    ql_default = Float64.(get(vv, "q_limits", Float64[]))
    length(bps_si) == 4 && length(ql_default) == 2 || (@warn "volt_var needs 4 breakpoints and 2 q_limits — skipping"; return nothing)
    bps_default = bps_si ./ Uscale
    bps = coefficient === nothing ? bps_default : Any[
        coefficient(:controller, :control_profile, profile_id,
                    :volt_var_breakpoints, i, value)
        for (i, value) in enumerate(bps_default)]
    ql = coefficient === nothing ? ql_default : Any[
        coefficient(:controller, :control_profile, profile_id,
                    :volt_var_q_limits, i, value)
        for (i, value) in enumerate(ql_default)]
    get(vv, "q_unit", "VA_FRACTION") == "VA_FRACTION" || (@warn "volt_var q_unit ≠ VA_FRACTION not yet supported — skipping"; return nothing)
    get(vv, "q_ref",  "VAR_MAX")     == "VAR_MAX"     || (@warn "volt_var q_ref ≠ VAR_MAX not yet supported — skipping"; return nothing)
    # ys: [inject (≥0) at U1, 0 at U2, 0 at U3, absorb (≤0) at U4]
    q_absorb, q_inject = ql[1], ql[2]
    ys = [q_inject, 0.0, 0.0, q_absorb]
    quantity, averaged = _split_voltage_reference(get(vv, "voltage_reference", "PN_PER_PHASE"))
    return _curve_from_points(bps, ys, bps_default, relu_eps,
                              :VAR_MAX, quantity, averaged)
end

"""
    _resolve_volt_watt(vw, Uscale, relu_eps) -> DroopCurve | nothing

Build the active-power cap curve P/P_base = f(U) from a `volt_watt` sub-object.
Supports VA_FRACTION p_unit with p_ref ∈ {S_MAX, P_MAX, P_AVAILABLE}; other
variants warn and skip.
"""
function _resolve_volt_watt(vw, Uscale::Float64, relu_eps::Float64;
                            coefficient=nothing, profile_id="")
    vw isa Dict || return nothing
    bps_si = Float64.(get(vw, "breakpoints", Float64[]))
    pl_default = Float64.(get(vw, "p_limits", Float64[]))
    length(bps_si) == 2 && length(pl_default) == 2 || (@warn "volt_watt needs 2 breakpoints and 2 p_limits — skipping"; return nothing)
    bps_default = bps_si ./ Uscale
    bps = coefficient === nothing ? bps_default : Any[
        coefficient(:controller, :control_profile, profile_id,
                    :volt_watt_breakpoints, i, value)
        for (i, value) in enumerate(bps_default)]
    pl = coefficient === nothing ? pl_default : Any[
        coefficient(:controller, :control_profile, profile_id,
                    :volt_watt_p_limits, i, value)
        for (i, value) in enumerate(pl_default)]
    get(vw, "p_unit", "VA_FRACTION") == "VA_FRACTION" || (@warn "volt_watt p_unit ≠ VA_FRACTION not yet supported — skipping"; return nothing)
    ref = get(vw, "p_ref", "S_MAX")
    ref in ("S_MAX", "P_MAX", "P_AVAILABLE") || (@warn "volt_watt p_ref '$ref' not supported — skipping"; return nothing)
    # ys: [p_high at U5, p_low at U6]  (p_limits given as [p_low, p_high])
    p_low, p_high = pl[1], pl[2]
    ys = [p_high, p_low]
    quantity, averaged = _split_voltage_reference(get(vw, "voltage_reference", "PN_PER_PHASE"))
    return _curve_from_points(bps, ys, bps_default, relu_eps,
                              Symbol(ref), quantity, averaged)
end

# Per-phase normalisation base for a resolved curve, in model units.
function _droop_base(c::DroopCurve, idx::Int, smax, p_max, p_avail_per)
    c.ref === :VAR_MAX     && return idx <= length(smax)  ? smax[idx]  : 0.0
    c.ref === :S_MAX       && return idx <= length(smax)  ? smax[idx]  : 0.0
    c.ref === :P_MAX       && return idx <= length(p_max) ? p_max[idx] : 0.0
    c.ref === :P_AVAILABLE && return p_avail_per
    return 0.0
end

_same_working_voltage_base(a::Float64, b::Float64) =
    isapprox(a, b; rtol=1e-12, atol=0.0)

"""
    _add_ibr_constraints!(ctx, kcl_r, kcl_i; parameterized_profiles, coefficient)

Add P/Q power constraints and KCL contributions for all IBR objects.

For each phase k the bilinear power equations are formed from the voltage
difference (dvr, dvi) appropriate to the inverter topology and the IBR
current variables (cri, cii):

    P_k = dvr·cri[k] + dvi·cii[k]
    Q_k = dvi·cri[k] − dvr·cii[k]

Constraints applied per phase:
- `p_min[k] ≤ P_k`; the available-power box `P_k ≤ p_max[k]` always applies, and a
  `volt_watt` profile adds the curtailment cap `P_k ≤ p_base · f^VW(|U_k|)` on top,
  so the effective upper bound is the tighter of the two.
- `P_k² + Q_k² ≤ s_max[k]²`  (apparent-power circle)
- `cri[k]² + cii[k]² ≤ i_max[k]²`  (optional converter current-magnitude limit;
  only stamped when `i_max` is present, so `Q_k` rolls off ≈ linearly with voltage
  rather than staying flat at `s_max`)
- Reactive power: constant-PF equality `sign(pf)·Q_k + tan_phi·P_k = 0`, or —
  under a `volt_var` profile — the droop equality `Q_k = q_base · f^VV(|U_k|)`,
  otherwise the box bounds `q_min[k] ≤ Q_k ≤ q_max[k]`.

Volt-var/Volt-watt droop is applied for SINGLE_PHASE and FOUR_LEG IBRs only;
for THREE_LEG (delta) there are too few degrees of freedom for a per-phase droop,
so a profile is ignored (box bounds retained) with a warning.
"""
function _add_ibr_constraints!(ctx, kcl_r, kcl_i;
                               parameterized_profiles::Set{String}=Set{String}(),
                               coefficient=nothing)
    model = ctx.model
    net = ctx.net
    vars = ctx.vars
    bases = ctx.bases
    relu_eps = ctx.relu_eps
    relu_ops = ctx.relu_ops
    softplus = ctx.softplus
    vr  = vars[:vr];  vi  = vars[:vi]
    cri = vars[:cri]; cii = vars[:cii]
    profiles = get(net, "control_profile", Dict())
    nlabels = BMOPFTools._neutral_labels(net)
    curve_cache = Dict{Tuple{String,Float64},Tuple{Any,Any}}()
    parameterized_profile_scale = Dict{String,Float64}()

    for (inv_id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        bus   = get(inv, "bus", "")
        tm    = Vector{String}(get(inv, "terminal_map", String[]))
        topo  = get(inv, "topology", "FOUR_LEG")
        smax  = Float64.(get(inv, "s_max",  Float64[]))
        imax  = Float64.(get(inv, "i_max",  Float64[]))
        p_min = Float64.(get(inv, "p_min",  Float64[]))
        p_max = Float64.(get(inv, "p_max",  Float64[]))
        q_min = Float64.(get(inv, "q_min",  Float64[]))
        q_max = Float64.(get(inv, "q_max",  Float64[]))
        p_min_model = coefficient === nothing ? p_min : Any[
            coefficient(:limit, :ibr, inv_id, :p_min, i, value)
            for (i, value) in enumerate(p_min)]
        p_max_model = coefficient === nothing ? p_max : Any[
            coefficient(:availability, :ibr, inv_id, :p_max, i, value)
            for (i, value) in enumerate(p_max)]
        q_min_model = coefficient === nothing ? q_min : Any[
            coefficient(:limit, :ibr, inv_id, :q_min, i, value)
            for (i, value) in enumerate(q_min)]
        q_max_model = coefficient === nothing ? q_max : Any[
            coefficient(:limit, :ibr, inv_id, :q_max, i, value)
            for (i, value) in enumerate(q_max)]

        # Resolve control_profile sub-objects (constant-PF and droop laws).
        pf_val = nothing
        vv_obj = nothing
        vw_obj = nothing
        cp_id  = get(inv, "control_profile", nothing)
        if cp_id isa String
            cp = get(profiles, cp_id, nothing)
            if cp isa Dict
                pf_obj = get(cp, "power_factor", nothing)
                if pf_obj isa Dict
                    raw = get(pf_obj, "pf", nothing)
                    if raw isa Number && abs(Float64(raw)) > 1e-9
                        pf_val = Float64(raw)
                    end
                end
                vv_obj = get(cp, "volt_var",  nothing)
                vw_obj = get(cp, "volt_watt", nothing)
            end
        end

        # Voltage scale for SI→model-unit conversion of breakpoints.
        Uscale = bases === nothing ? 1.0 : Float64(get(bases.v_base, bus, 1.0))

        # Resolve droop curves (only for the supported topologies).
        vv = nothing
        vw = nothing
        if vv_obj !== nothing || vw_obj !== nothing
            if topo == "THREE_LEG"
                @warn "IBR '$inv_id': Volt-var/Volt-watt not supported for THREE_LEG — using box bounds."
            elseif pf_val !== nothing
                @warn "IBR '$inv_id': control_profile has both power_factor and Volt-var/Volt-watt — using power_factor."
            else
                profile_id = string(cp_id)
                if profile_id in parameterized_profiles &&
                   haskey(parameterized_profile_scale, profile_id)
                    established_scale = parameterized_profile_scale[profile_id]
                    _same_working_voltage_base(established_scale, Uscale) ||
                        throw(ArgumentError(
                        "parameterized control profile '$profile_id' is shared " *
                        "across different voltage bases; one profile-scoped " *
                        "working-unit coefficient cannot represent both bases"))
                    # Canonicalize arithmetic-equivalent bases so the shared
                    # provider is resolved once under one cache key.
                    Uscale = established_scale
                end
                profile_id in parameterized_profiles &&
                    (parameterized_profile_scale[profile_id] = Uscale)
                cache_key = (profile_id, Uscale)
                if !haskey(curve_cache, cache_key)
                    resolved_vv = _resolve_volt_var(vv_obj, Uscale, relu_eps;
                        coefficient, profile_id=profile_id)
                    resolved_vw = _resolve_volt_watt(vw_obj, Uscale, relu_eps;
                        coefficient, profile_id=profile_id)
                    _enforce_curve_order!(model, resolved_vv, cp_id, :volt_var)
                    _enforce_curve_order!(model, resolved_vw, cp_id, :volt_watt)
                    curve_cache[cache_key] = (resolved_vv, resolved_vw)
                end
                vv, vw = curve_cache[cache_key]
            end
        end

        # Per-phase available active power (model units) for p_ref=P_AVAILABLE.
        p_avail_per = let pa = get(inv, "p_avail", nothing)
            n = max(length(_phase_positions(tm, nlabels)), 1)
            pa isa Number ?
                Float64(pa) / n /
                (bases === nothing ? 1.0 : _ac_power_base(bases, bus)) : 0.0
        end

        tan_phi  = pf_val !== nothing ? tan(acos(abs(pf_val))) : nothing
        # sign(pf) > 0 (lagging): Q = -tan_phi*P  →  +1*Q + tan_phi*P = 0
        # sign(pf) < 0 (leading): Q = +tan_phi*P  →  -1*Q + tan_phi*P = 0
        pf_sign  = pf_val !== nothing ? sign(pf_val) : 0.0

        # Aggregation across phases is normally taken from each curve's
        # `voltage_reference` (the _AVERAGED suffix). The legacy IBR-level
        # `voltage_aggregation` field, when explicitly present, overrides it (PER_PHASE /
        # AVERAGE) for backward compatibility. `override_avg === nothing` means
        # "defer to the curve".
        has_vref_field = haskey(inv, "voltage_aggregation")
        volt_ref    = uppercase(String(get(inv, "voltage_aggregation", "PER_PHASE")))
        avg_ref     = volt_ref == "AVERAGE"
        override_avg = has_vref_field ? avg_ref : nothing

        # Shared-DC-link coupling: collect each phase's active-power expression
        # so the net active power can be bounded by [p_dc_min, p_dc_max] after the
        # per-phase constraints are stamped (Heidari & Geth 2024; Deakin, Heidari
        # & Deng 2025). Only assembled when the IBR declares dc_link_coupled.
        dc_coupled = get(inv, "dc_link_coupled", false) === true
        has_dc_bus = haskey(inv, "dc_bus")
        collect_p  = dc_coupled || has_dc_bus
        p_exprs    = JuMP.QuadExpr[]

        if topo == "SINGLE_PHASE"
            length(tm) >= 2 || (@warn "IBR '$inv_id': SINGLE_PHASE needs ≥2 terminals"; continue)
            t_ph  = tm[1]
            t_ref = tm[2]
            dvr = @expression(model, vr[(bus, t_ph)] - vr[(bus, t_ref)])
            dvi = @expression(model, vi[(bus, t_ph)] - vi[(bus, t_ref)])

            p_expr = @expression(model, dvr*cri[(inv_id,1)] + dvi*cii[(inv_id,1)])
            q_expr = @expression(model, dvi*cri[(inv_id,1)] - dvr*cii[(inv_id,1)])
            collect_p && push!(p_exprs, p_expr)

            let (pt, qt) = _ibr_phase_target(1, p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign)
                _warmstart_ibr_current!(cri[(inv_id,1)], cii[(inv_id,1)], dvr, dvi, pt, qt)
            end

            # Per-conductor i_max: a single-phase IBR has ONE current (phase and
            # return carry the same magnitude), so stamp one circle at the tighter
            # of the (≤2) entries — never constrain the same variable twice.
            if !isempty(imax)
                ilim_sp = minimum(imax)
                _register_semantic_constraint!(ctx, :ibr_current_thermal,
                    (String(inv_id), 1),
                    _soc_norm!(model, cri[(inv_id,1)], cii[(inv_id,1)], ilim_sp))
            end

            avg_ref && @warn "IBR '$inv_id': voltage_aggregation=AVERAGE has no effect for SINGLE_PHASE — using per-phase magnitude."
            # PG monitors |V_φ|; PN/PP both monitor the terminal-pair difference
            # |V_φ − V_ref| (ref = tm[2], a neutral for PN-wired or the second
            # phase for PP-wired units). Aggregation is moot for one phase.
            key_pg = BMOPFTools.opf_ibr_voltage_magnitude_key(inv_id, 1;
                reference=:single_pg, controller=:single)
            key_diff = BMOPFTools.opf_ibr_voltage_magnitude_key(inv_id, 1;
                reference=:single_diff, controller=:single)
            magnitude_variable(reference, dvr_value, dvi_value) = umag_var(
                model, dvr_value, dvi_value;
                on_definition=cref -> _register_semantic_constraint!(ctx,
                    :ibr_voltage_magnitude_definition,
                    (String(inv_id), reference, 1), cref),
                on_lower_bound=cref -> _register_semantic_constraint!(ctx,
                    :ibr_voltage_magnitude_lower_bound,
                    (String(inv_id), reference, 1), cref))
            U_pg = magnitude_variable(:single_pg,
                vr[(bus, t_ph)], vi[(bus, t_ph)])
            U_diff = magnitude_variable(:single_diff, dvr, dvi)
            BMOPFTools.register_opf_object!(ctx, key_pg, U_pg)
            BMOPFTools.register_opf_object!(ctx, key_diff, U_diff)
            single_U(c) = c === nothing ? nothing : (c.quantity == :PG ? U_pg : U_diff)
            _apply_ibr_phase!(ctx, inv_id, 1, p_expr, q_expr, single_U(vv), single_U(vw),
                p_min_model, p_max_model, q_min_model, q_max_model,
                smax, tan_phi, pf_sign,
                vv, vw, p_avail_per, relu_ops, softplus)

            _kcl_add!(kcl_r, kcl_i, bus, t_ph,   cri[(inv_id,1)],  cii[(inv_id,1)])
            _kcl_add!(kcl_r, kcl_i, bus, t_ref,  -cri[(inv_id,1)], -cii[(inv_id,1)])

        elseif topo == "FOUR_LEG"
            ph_pos    = _phase_positions(tm, nlabels)
            n_pos_idx = _neutral_pos(tm, nlabels)
            t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing
            ph_terms  = [tm[ph] for ph in ph_pos]

            # First pass: build the per-phase power voltage differences (phase-to-
            # neutral, the inverter's own terminal pair), P/Q expressions, KCL.
            phase = NamedTuple[]
            for (idx, ph) in enumerate(ph_pos)
                t_ph = tm[ph]
                dvr  = t_n !== nothing ?
                       @expression(model, vr[(bus,t_ph)] - vr[(bus,t_n)]) :
                       vr[(bus, t_ph)]
                dvi  = t_n !== nothing ?
                       @expression(model, vi[(bus,t_ph)] - vi[(bus,t_n)]) :
                       vi[(bus, t_ph)]

                p_expr = @expression(model, dvr*cri[(inv_id,idx)] + dvi*cii[(inv_id,idx)])
                q_expr = @expression(model, dvi*cri[(inv_id,idx)] - dvr*cii[(inv_id,idx)])

                pt, qt = _ibr_phase_target(idx, p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign)
                _warmstart_ibr_current!(cri[(inv_id,idx)], cii[(inv_id,idx)], dvr, dvi, pt, qt)

                push!(phase, (idx=idx, p_expr=p_expr, q_expr=q_expr))
                collect_p && push!(p_exprs, p_expr)

                length(imax) >= idx && _register_semantic_constraint!(ctx,
                    :ibr_current_thermal, (String(inv_id), idx),
                    _soc_norm!(model, cri[(inv_id,idx)], cii[(inv_id,idx)], imax[idx]))

                _kcl_add!(kcl_r, kcl_i, bus, t_ph,  cri[(inv_id,idx)],  cii[(inv_id,idx)])
                t_n !== nothing &&
                    _kcl_add!(kcl_r, kcl_i, bus, t_n, -cri[(inv_id,idx)], -cii[(inv_id,idx)])
            end

            # Neutral-conductor current limit: when i_max carries one extra
            # (per-conductor) entry beyond the phases, cap the neutral return
            # current = −Σ phase currents.
            n_ph = length(ph_pos)
            if t_n !== nothing && length(imax) == n_ph + 1
                neutral_limit = _neutral_current_limit!(model,
                    [cri[(inv_id,idx)] for idx in 1:n_ph],
                    [cii[(inv_id,idx)] for idx in 1:n_ph], imax[n_ph + 1])
                neutral_limit === nothing || _register_semantic_constraint!(ctx,
                    :ibr_neutral_current_thermal,
                    (String(inv_id), n_ph + 1), neutral_limit)
            end

            # Monitored droop voltages, per curve (quantity + aggregation from each
            # curve's voltage_reference; legacy voltage_aggregation overrides aggregation).
            U_vv = vv !== nothing ? _monitor_U(ctx, vr, vi, bus, ph_terms, t_n, vv, override_avg, inv_id, :volt_var) : nothing
            U_vw = vw !== nothing ? _monitor_U(ctx, vr, vi, bus, ph_terms, t_n, vw, override_avg, inv_id, :volt_watt) : nothing

            # Second pass: stamp the per-phase constraints.
            for p in phase
                _apply_ibr_phase!(ctx, inv_id, p.idx, p.p_expr, p.q_expr,
                    U_vv === nothing ? nothing : U_vv[p.idx],
                    U_vw === nothing ? nothing : U_vw[p.idx],
                    p_min_model, p_max_model, q_min_model, q_max_model,
                    smax, tan_phi, pf_sign,
                    vv, vw, p_avail_per, relu_ops, softplus)
            end

        elseif topo == "THREE_LEG"
            n_c = length(tm)
            for k in 1:n_c
                t_pos = tm[k]
                t_neg = tm[(k % n_c) + 1]
                dvr = @expression(model, vr[(bus,t_pos)] - vr[(bus,t_neg)])
                dvi = @expression(model, vi[(bus,t_pos)] - vi[(bus,t_neg)])

                p_expr = @expression(model, dvr*cri[(inv_id,k)] + dvi*cii[(inv_id,k)])
                q_expr = @expression(model, dvi*cri[(inv_id,k)] - dvr*cii[(inv_id,k)])
                collect_p && push!(p_exprs, p_expr)

                let (pt, qt) = _ibr_phase_target(k, p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign)
                    _warmstart_ibr_current!(cri[(inv_id,k)], cii[(inv_id,k)], dvr, dvi, pt, qt)
                end

                length(imax) >= k && _register_semantic_constraint!(ctx,
                    :ibr_current_thermal, (String(inv_id), k),
                    _soc_norm!(model, cri[(inv_id,k)], cii[(inv_id,k)], imax[k]))

                # THREE_LEG never carries droop (vv = vw = nothing); U is unused.
                _apply_ibr_phase!(ctx, inv_id, k, p_expr, q_expr, nothing, nothing,
                    p_min_model, p_max_model, q_min_model, q_max_model,
                    smax, tan_phi, pf_sign,
                    nothing, nothing, p_avail_per, relu_ops, softplus)

                _kcl_add!(kcl_r, kcl_i, bus, t_pos,  cri[(inv_id,k)],  cii[(inv_id,k)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg, -cri[(inv_id,k)], -cii[(inv_id,k)])
            end

        else
            @warn "IBR '$inv_id': unknown topology '$topo' — skipping."
        end

        # DC-side active-power coupling of the per-phase active powers.
        if has_dc_bus && !isempty(p_exprs)
            # Shared DC bus: the converter's AC active power equals the power
            # drawn from the DC node (lossless), balanced against the other
            # converters/loads/sources through DC KCL. This forms a converter
            # station / back-to-back SOP / MVDC tie.
            p_ac = @expression(model, sum(p_exprs))
            _couple_converter_to_dc!(model, vars, inv_id, inv, p_ac, smax,
                                     p_min, p_max;
                                     relu_eps=relu_eps, relu_ops=relu_ops,
                                     softplus=softplus, net=net,
                                     constraint_context=ctx)
        elseif dc_coupled && !isempty(p_exprs)
            # Isolated DC link: bound the net (sum of per-phase) active power,
            # letting the converter circulate active power between phases.
            # p_dc_min/p_dc_max default to 0/0 for a STATCOM (pure circulation)
            # — see the augmentation pass and `add_statcom!`.
            p_net = @expression(model, sum(p_exprs))
            p_dc_min = get(inv, "p_dc_min", 0.0)
            p_dc_max = get(inv, "p_dc_max", 0.0)
            _register_semantic_constraint!(ctx, :ibr_dc_power_lower,
                String(inv_id), @constraint(model, p_net >= Float64(p_dc_min)))
            _register_semantic_constraint!(ctx, :ibr_dc_power_upper,
                String(inv_id), @constraint(model, p_net <= Float64(p_dc_max)))
        end
    end
end

# Stamp the per-phase active/reactive constraints and apparent-power circle for a
# single IBR phase `idx`, given the bilinear P/Q expressions and (optionally)
# resolved Volt-var (`vv`) / Volt-watt (`vw`) droop curves.
#
# `U` is the reference voltage-magnitude expression fed into the droop curves. The
# caller chooses it per the IBR's `voltage_aggregation` field: the per-phase magnitude
# √(dvr²+dvi²) for PER_PHASE, or the mean of the phase magnitudes for AVERAGE.
function _apply_ibr_phase!(ctx, inv_id, idx, p_expr, q_expr, U_vv, U_vw,
                                p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign,
                                vv, vw, p_avail_per, relu_ops, softplus)
    model = ctx.model
    register_constraint(family, cref) = BMOPFTools.register_opf_object!(ctx,
        BMOPFTools.OpfModelKey(:constraint, family, (string(inv_id), idx)), cref)
    # P lower bound (always a box bound).
    if length(p_min) >= idx
        register_constraint(:ibr_p_lower, @constraint(model, p_expr >= p_min[idx]))
    end

    # P upper bound(s). The available-power box `p_max` always applies — you cannot
    # generate more active power than is available, regardless of any curtailment
    # curve. A Volt-watt profile adds a voltage-dependent curtailment cap on top, so
    # the effective bound is the tighter of the two (P ≤ min(p_max, p_base·f^VW)).
    # (When p_ref=P_MAX the cap is already ≤ p_max and binds first; when p_ref=S_MAX
    # the cap is a fraction of rated and p_max is what enforces availability.)
    if length(p_max) >= idx
        register_constraint(:ibr_p_upper, @constraint(model, p_expr <= p_max[idx]))
    end
    if vw !== nothing
        op   = relu_operator_for!(relu_ops, model, vw.eps; mode=softplus)
        base = _droop_base(vw, idx, smax, p_max, p_avail_per)
        register_constraint(:ibr_p_volt_watt, @constraint(model,
            p_expr <= curve_expr(op, U_vw, base * vw.baseline,
                                 [(base*a, x̄) for (a, x̄) in vw.triples])))
    end

    # Reactive power: constant-PF equality, Volt-var droop equality, or box.
    if tan_phi !== nothing
        register_constraint(:ibr_power_factor, @constraint(model,
            pf_sign * q_expr + tan_phi * p_expr == 0))
    elseif vv !== nothing
        op   = relu_operator_for!(relu_ops, model, vv.eps; mode=softplus)
        base = _droop_base(vv, idx, smax, p_max, p_avail_per)
        register_constraint(:ibr_q_volt_var, @constraint(model,
            q_expr == curve_expr(op, U_vv, base * vv.baseline,
                                 [(base*a, x̄) for (a, x̄) in vv.triples])))
    else
        if length(q_min) >= idx
            register_constraint(:ibr_q_lower, @constraint(model, q_expr >= q_min[idx]))
        end
        if length(q_max) >= idx
            register_constraint(:ibr_q_upper, @constraint(model, q_expr <= q_max[idx]))
        end
    end

    # Register the native active/reactive power auxiliaries uniformly, even
    # when no apparent-power rating is declared. Consumers should not need a
    # separate s_max precondition just to access the IBR operating point.
    p_aux = @variable(model, base_name = "pi_$(inv_id)_$(idx)")
    q_aux = @variable(model, base_name = "qi_$(inv_id)_$(idx)")
    BMOPFTools.register_opf_object!(ctx,
        BMOPFTools.opf_ibr_power_key(string(inv_id), idx), p_aux)
    BMOPFTools.register_opf_object!(ctx,
        BMOPFTools.opf_ibr_power_key(string(inv_id), idx; component = :reactive), q_aux)
    register_constraint(:ibr_power_link_p, @constraint(model, p_aux == p_expr))
    register_constraint(:ibr_power_link_q, @constraint(model, q_aux == q_expr))
    # Apparent-power circle.
    if length(smax) >= idx
        register_constraint(:ibr_power_circle,
            _soc_norm!(model, p_aux, q_aux, smax[idx]))
    end
end
