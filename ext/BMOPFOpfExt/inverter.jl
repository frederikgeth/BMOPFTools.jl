# Inverter constraints for the four-wire IVR-EN OPF.
#
# Topology → voltage reference mapping:
#   FOUR_LEG    — phase-to-neutral; neutral is the last terminal in terminal_map
#   THREE_LEG   — line-to-line (delta); no neutral current; one current per
#                 conductor pair (k, k mod n + 1)
#   SINGLE_PHASE — phase-to-reference; terminal_map = [phase, ref]; one current
#
# Constant power-factor (PF) mode
# ────────────────────────────────
# When the inverter references a control_profile with a "power_factor" sub-object
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
# normally filled by _apply_inverter_augmentation! before the OPF is called.

"Declare `cri`/`cii` inverter current variables (one per phase conductor)."
function _add_inverter_variables!(model, net)
    cri = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    cii = Dict{Tuple{String,Int}, JuMP.VariableRef}()

    for (inv_id, inv) in get(net, "inverter", Dict())
        inv isa Dict || continue
        tm   = Vector{String}(get(inv, "terminal_map", String[]))
        topo = get(inv, "topology", "FOUR_LEG")
        n_ph = topo == "THREE_LEG" ? length(tm) :
               topo == "SINGLE_PHASE" ? 1 :
               length(_phase_positions(tm))   # FOUR_LEG
        for k in 1:n_ph
            cri[(inv_id, k)] = @variable(model, base_name = "cri_$(inv_id)_$(k)")
            cii[(inv_id, k)] = @variable(model, base_name = "cii_$(inv_id)_$(k)")
        end
    end
    cri, cii
end

# Resolved Volt-var / Volt-watt droop curve, ready to stamp into the model.
# `triples`/`eps` are in model voltage units (SI volts, or per-unit when the
# model is solved per-unit); `ref` selects the per-phase normalisation base.
struct DroopCurve
    baseline::Float64
    triples::Vector{Tuple{Float64,Float64}}
    eps::Float64
    ref::Symbol           # :S_MAX | :P_MAX | :P_AVAILABLE | :VAR_MAX
end

# Map SI breakpoints into model units and pick a smoothing ε proportional to the
# voltage scale (so the corner rounding tracks SI/per-unit automatically).
function _curve_from_points(xs_si, ys, Uscale::Float64, relu_eps::Float64, ref::Symbol)
    xs = Float64.(xs_si) ./ Uscale
    base, triples = breakpoints_to_triples(xs, ys)
    ε = relu_eps * (sum(xs) / length(xs))
    return DroopCurve(base, triples, ε, ref)
end

"""
    _resolve_volt_var(vv, Uscale, relu_eps) -> DroopCurve | nothing

Build the reactive-power droop curve Q/Q_base = f(U) from a `volt_var` sub-object.
Only the Queensland default option space is supported (PN_PER_PHASE voltage
reference, VA_FRACTION q_unit, VAR_MAX q_ref); unsupported variants warn and skip
so the inverter falls back to its box bounds.
"""
function _resolve_volt_var(vv, Uscale::Float64, relu_eps::Float64)
    vv isa Dict || return nothing
    bps = Float64.(get(vv, "breakpoints", Float64[]))
    ql  = Float64.(get(vv, "q_limits",    Float64[]))
    length(bps) == 4 && length(ql) == 2 || (@warn "volt_var needs 4 breakpoints and 2 q_limits — skipping"; return nothing)
    get(vv, "q_unit", "VA_FRACTION") == "VA_FRACTION" || (@warn "volt_var q_unit ≠ VA_FRACTION not yet supported — skipping"; return nothing)
    get(vv, "q_ref",  "VAR_MAX")     == "VAR_MAX"     || (@warn "volt_var q_ref ≠ VAR_MAX not yet supported — skipping"; return nothing)
    # ys: [inject (≥0) at U1, 0 at U2, 0 at U3, absorb (≤0) at U4]
    q_absorb, q_inject = ql[1], ql[2]
    ys = [q_inject, 0.0, 0.0, q_absorb]
    return _curve_from_points(bps, ys, Uscale, relu_eps, :VAR_MAX)
end

"""
    _resolve_volt_watt(vw, Uscale, relu_eps) -> DroopCurve | nothing

Build the active-power cap curve P/P_base = f(U) from a `volt_watt` sub-object.
Supports VA_FRACTION p_unit with p_ref ∈ {S_MAX, P_MAX, P_AVAILABLE}; other
variants warn and skip.
"""
function _resolve_volt_watt(vw, Uscale::Float64, relu_eps::Float64)
    vw isa Dict || return nothing
    bps = Float64.(get(vw, "breakpoints", Float64[]))
    pl  = Float64.(get(vw, "p_limits",    Float64[]))
    length(bps) == 2 && length(pl) == 2 || (@warn "volt_watt needs 2 breakpoints and 2 p_limits — skipping"; return nothing)
    get(vw, "p_unit", "VA_FRACTION") == "VA_FRACTION" || (@warn "volt_watt p_unit ≠ VA_FRACTION not yet supported — skipping"; return nothing)
    ref = get(vw, "p_ref", "S_MAX")
    ref in ("S_MAX", "P_MAX", "P_AVAILABLE") || (@warn "volt_watt p_ref '$ref' not supported — skipping"; return nothing)
    # ys: [p_high at U5, p_low at U6]  (p_limits given as [p_low, p_high])
    p_low, p_high = pl[1], pl[2]
    ys = [p_high, p_low]
    return _curve_from_points(bps, ys, Uscale, relu_eps, Symbol(ref))
end

# Per-phase normalisation base for a resolved curve, in model units.
function _droop_base(c::DroopCurve, idx::Int, smax, p_max, p_avail_per)
    c.ref === :VAR_MAX     && return idx <= length(smax)  ? smax[idx]  : 0.0
    c.ref === :S_MAX       && return idx <= length(smax)  ? smax[idx]  : 0.0
    c.ref === :P_MAX       && return idx <= length(p_max) ? p_max[idx] : 0.0
    c.ref === :P_AVAILABLE && return p_avail_per
    return 0.0
end

"""
    _add_inverter_constraints!(model, net, vars, kcl_r, kcl_i; bases, relu_eps, relu_ops)

Add P/Q power constraints and KCL contributions for all inverter objects.

For each phase k the bilinear power equations are formed from the voltage
difference (dvr, dvi) appropriate to the inverter topology and the inverter
current variables (cri, cii):

    P_k = dvr·cri[k] + dvi·cii[k]
    Q_k = dvi·cri[k] − dvr·cii[k]

Constraints applied per phase:
- `p_min[k] ≤ P_k`; upper bound is `P_k ≤ p_max[k]`, or — under a `volt_watt`
  profile — the curtailment cap `P_k ≤ p_base · f^VW(|U_k|)`.
- `P_k² + Q_k² ≤ s_max[k]²`  (apparent-power circle)
- Reactive power: constant-PF equality `sign(pf)·Q_k + tan_phi·P_k = 0`, or —
  under a `volt_var` profile — the droop equality `Q_k = q_base · f^VV(|U_k|)`,
  otherwise the box bounds `q_min[k] ≤ Q_k ≤ q_max[k]`.

Volt-var/Volt-watt droop is applied for SINGLE_PHASE and FOUR_LEG inverters only;
for THREE_LEG (delta) there are too few degrees of freedom for a per-phase droop,
so a profile is ignored (box bounds retained) with a warning.
"""
function _add_inverter_constraints!(model, net, vars, kcl_r, kcl_i;
                                    bases=nothing, relu_eps::Float64=2e-3,
                                    relu_ops::Dict{Float64,Any}=Dict{Float64,Any}())
    vr  = vars[:vr];  vi  = vars[:vi]
    cri = vars[:cri]; cii = vars[:cii]
    profiles = get(net, "control_profile", Dict())

    for (inv_id, inv) in get(net, "inverter", Dict())
        inv isa Dict || continue
        bus   = get(inv, "bus", "")
        tm    = Vector{String}(get(inv, "terminal_map", String[]))
        topo  = get(inv, "topology", "FOUR_LEG")
        smax  = Float64.(get(inv, "s_max",  Float64[]))
        p_min = Float64.(get(inv, "p_min",  Float64[]))
        p_max = Float64.(get(inv, "p_max",  Float64[]))
        q_min = Float64.(get(inv, "q_min",  Float64[]))
        q_max = Float64.(get(inv, "q_max",  Float64[]))

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
                @warn "Inverter '$inv_id': Volt-var/Volt-watt not supported for THREE_LEG — using box bounds."
            elseif pf_val !== nothing
                @warn "Inverter '$inv_id': control_profile has both power_factor and Volt-var/Volt-watt — using power_factor."
            else
                vv = _resolve_volt_var(vv_obj, Uscale, relu_eps)
                vw = _resolve_volt_watt(vw_obj, Uscale, relu_eps)
            end
        end

        # Per-phase available active power (model units) for p_ref=P_AVAILABLE.
        p_avail_per = let pa = get(inv, "p_avail", nothing)
            n = max(length(_phase_positions(tm)), 1)
            pa isa Number ?
                Float64(pa) / n / (bases === nothing ? 1.0 : Float64(bases.s_base)) : 0.0
        end

        tan_phi  = pf_val !== nothing ? tan(acos(abs(pf_val))) : nothing
        # sign(pf) > 0 (lagging): Q = -tan_phi*P  →  +1*Q + tan_phi*P = 0
        # sign(pf) < 0 (leading): Q = +tan_phi*P  →  -1*Q + tan_phi*P = 0
        pf_sign  = pf_val !== nothing ? sign(pf_val) : 0.0

        # Droop reference-voltage mode: PER_PHASE (each phase sees its own
        # magnitude) or AVERAGE (every phase sees the mean of the phase
        # magnitudes). Only meaningful for multi-phase FOUR_LEG inverters.
        volt_ref = uppercase(String(get(inv, "voltage_ref", "PER_PHASE")))
        avg_ref  = volt_ref == "AVERAGE"

        if topo == "SINGLE_PHASE"
            length(tm) >= 2 || (@warn "Inverter '$inv_id': SINGLE_PHASE needs ≥2 terminals"; continue)
            t_ph  = tm[1]
            t_ref = tm[2]
            dvr = @expression(model, vr[(bus, t_ph)] - vr[(bus, t_ref)])
            dvi = @expression(model, vi[(bus, t_ph)] - vi[(bus, t_ref)])

            p_expr = @expression(model, dvr*cri[(inv_id,1)] + dvi*cii[(inv_id,1)])
            q_expr = @expression(model, dvi*cri[(inv_id,1)] - dvr*cii[(inv_id,1)])

            avg_ref && @warn "Inverter '$inv_id': voltage_ref=AVERAGE has no effect for SINGLE_PHASE — using per-phase magnitude."
            U = umag_expr(dvr, dvi)
            _apply_inverter_phase!(model, inv_id, 1, p_expr, q_expr, U,
                p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign,
                vv, vw, p_avail_per, relu_ops)

            _kcl_add!(kcl_r, kcl_i, bus, t_ph,   cri[(inv_id,1)],  cii[(inv_id,1)])
            _kcl_add!(kcl_r, kcl_i, bus, t_ref,  -cri[(inv_id,1)], -cii[(inv_id,1)])

        elseif topo == "FOUR_LEG"
            ph_pos    = _phase_positions(tm)
            n_pos_idx = _neutral_pos(tm)
            t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing

            # The droop reference magnitude is only needed when a curve consumes it.
            need_U = vv !== nothing || vw !== nothing

            # First pass: build the per-phase voltage differences, P/Q expressions
            # and (when droop is active) per-phase magnitudes, and stamp KCL.
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

                push!(phase, (idx=idx, p_expr=p_expr, q_expr=q_expr,
                              U=need_U ? umag_expr(dvr, dvi) : nothing))

                _kcl_add!(kcl_r, kcl_i, bus, t_ph,  cri[(inv_id,idx)],  cii[(inv_id,idx)])
                t_n !== nothing &&
                    _kcl_add!(kcl_r, kcl_i, bus, t_n, -cri[(inv_id,idx)], -cii[(inv_id,idx)])
            end

            # AVERAGE feeds the mean phase magnitude into every phase's droop curve.
            U_avg = (need_U && avg_ref && length(phase) >= 1) ?
                    @expression(model, sum(p.U for p in phase) / length(phase)) :
                    nothing

            # Second pass: stamp the per-phase constraints with the chosen reference.
            for p in phase
                U = U_avg === nothing ? p.U : U_avg
                _apply_inverter_phase!(model, inv_id, p.idx, p.p_expr, p.q_expr, U,
                    p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign,
                    vv, vw, p_avail_per, relu_ops)
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

                # THREE_LEG never carries droop (vv = vw = nothing); U is unused.
                _apply_inverter_phase!(model, inv_id, k, p_expr, q_expr, nothing,
                    p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign,
                    nothing, nothing, p_avail_per, relu_ops)

                _kcl_add!(kcl_r, kcl_i, bus, t_pos,  cri[(inv_id,k)],  cii[(inv_id,k)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg, -cri[(inv_id,k)], -cii[(inv_id,k)])
            end

        else
            @warn "Inverter '$inv_id': unknown topology '$topo' — skipping."
        end
    end
end

# Stamp the per-phase active/reactive constraints and apparent-power circle for a
# single inverter phase `idx`, given the bilinear P/Q expressions and (optionally)
# resolved Volt-var (`vv`) / Volt-watt (`vw`) droop curves.
#
# `U` is the reference voltage-magnitude expression fed into the droop curves. The
# caller chooses it per the inverter's `voltage_ref` field: the per-phase magnitude
# √(dvr²+dvi²) for PER_PHASE, or the mean of the phase magnitudes for AVERAGE.
function _apply_inverter_phase!(model, inv_id, idx, p_expr, q_expr, U,
                                p_min, p_max, q_min, q_max, smax, tan_phi, pf_sign,
                                vv, vw, p_avail_per, relu_ops)
    # P lower bound (always a box bound).
    length(p_min) >= idx && @constraint(model, p_expr >= p_min[idx])

    # P upper bound: Volt-watt curtailment cap, else box.
    if vw !== nothing
        op   = relu_operator_for!(relu_ops, model, vw.eps)
        base = _droop_base(vw, idx, smax, p_max, p_avail_per)
        @constraint(model, p_expr <= curve_expr(op, U, base * vw.baseline,
                                                 [(base*a, x̄) for (a, x̄) in vw.triples]))
    else
        length(p_max) >= idx && @constraint(model, p_expr <= p_max[idx])
    end

    # Reactive power: constant-PF equality, Volt-var droop equality, or box.
    if tan_phi !== nothing
        @constraint(model, pf_sign * q_expr + tan_phi * p_expr == 0)
    elseif vv !== nothing
        op   = relu_operator_for!(relu_ops, model, vv.eps)
        base = _droop_base(vv, idx, smax, p_max, p_avail_per)
        @constraint(model, q_expr == curve_expr(op, U, base * vv.baseline,
                                                [(base*a, x̄) for (a, x̄) in vv.triples]))
    else
        length(q_min) >= idx && @constraint(model, q_expr >= q_min[idx])
        length(q_max) >= idx && @constraint(model, q_expr <= q_max[idx])
    end

    # Apparent-power circle.
    if length(smax) >= idx
        p_aux = @variable(model, base_name = "pi_$(inv_id)_$(idx)")
        q_aux = @variable(model, base_name = "qi_$(inv_id)_$(idx)")
        @constraint(model, p_aux == p_expr)
        @constraint(model, q_aux == q_expr)
        @constraint(model, p_aux^2 + q_aux^2 <= smax[idx]^2)
    end
end
