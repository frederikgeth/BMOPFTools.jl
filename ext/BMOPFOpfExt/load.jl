# Load constraints — constant-power, ZIP, and exponential models, rectangular IVR.
#
# Current variables crd/cid are the TOTAL sub-load current (one per phase
# conductor for WYE/SINGLE_PHASE, one per element for DELTA; neutral excluded).
# KCL is therefore unchanged across all load models — only the power equation
# pinning crd/cid differs.
#
# Realized power per sub-load (bilinear in voltage drop Δv and current):
#   P = Δvr·crd + Δvi·cid
#   Q = Δvi·crd − Δvr·cid
#
# Voltage-dependent models introduce a squared-voltage-drop variable
#   W = Δvr² + Δvi²            (bounded: (f·Vnom)² ≤ W ≤ (c·Vnom)²)
# and, only when a constant-current term is present, s = √W (s ≥ 0, s² = W).
# The right-hand side is then:
#   ZIP:          P = p_nom·(αZ·W/Vnom² + αI·s/Vnom + αP)
#   exponential:  P = p_nom·(W/Vnom²)^(γP/2)
# Integer exponents γ ∈ {0,1,2} are routed to the constant-P/I/Z quadratic
# terms above so the formulation stays quadratic; only genuinely non-integer
# exponents emit the nonlinear power term.

# W box, as a fraction of Vnom. These are conditioning bounds (the operational
# voltage limits are enforced separately on the bus voltages), so they are
# deliberately wider than any supply standard.
const _W_FLOOR_FRAC = 0.5
const _W_CEIL_FRAC  = 1.5

# Nominal voltage for sub-load k (length-1 v_nom broadcasts to all sub-loads).
function _load_vnom_k(load, k::Int)
    v = get(load, "v_nom", nothing)
    v === nothing && error("Load model requires v_nom but none is present.")
    vv = v isa AbstractVector ? Float64.(v) : [Float64(v)]
    vnom = length(vv) == 1 ? vv[1] : vv[k]
    # Every voltage-dependent model divides by v_nom (or v_nom²), so a zero or
    # negative nominal voltage yields Inf/NaN coefficients with no well-posed
    # substitution — reject it rather than emit a poisoned model. (Constant-power
    # loads never reach this path.)
    vnom > 0.0 || error("Load model requires a strictly positive v_nom " *
        "(got $vnom); a voltage-dependent load divides by v_nom, which is " *
        "undefined at zero. Set the sub-load's nominal voltage, or use " *
        "model=\"constant_power\".")
    vnom
end

# Scalar coefficient at sub-load k (length-1 broadcasts; absent → 0).
function _coeff_k(load, key::String, k::Int)
    c = get(load, key, nothing)
    c === nothing && return 0.0
    c isa AbstractVector ? Float64(length(c) == 1 ? c[1] : c[k]) : Float64(c)
end

# ZIP coefficients (Z, I, P) for one component family at sub-load k.
# If the family is entirely absent → constant power (0,0,1); otherwise missing
# members default to 0 (the validator warns if Z+I+P ≠ 1).
function _zip_coeffs(load, zkey, ikey, pkey, k::Int)
    if get(load, zkey, nothing) === nothing &&
       get(load, ikey, nothing) === nothing &&
       get(load, pkey, nothing) === nothing
        return (0.0, 0.0, 1.0)
    end
    (_coeff_k(load, zkey, k), _coeff_k(load, ikey, k), _coeff_k(load, pkey, k))
end

# Component right-hand-side as (const, W-coef, s-coef, nonlinear) terms.
# `nl` is `nothing` for the quadratic-representable cases, or `(base, γ)` for a
# genuinely non-integer exponential exponent.
function _component_terms(load, zkeys, gkey, base, Vnom::Float64, k::Int)
    model = get(load, "model", "constant_power")
    if model == "constant_impedance"
        return (cc = 0.0, cW = base / Vnom^2, cs = 0.0, nl = nothing)
    elseif model == "constant_current"
        return (cc = 0.0, cW = 0.0, cs = base / Vnom, nl = nothing)
    elseif model == "zip"
        (cz, ci, cp) = _zip_coeffs(load, zkeys[1], zkeys[2], zkeys[3], k)
        return (cc = base * cp, cW = base * cz / Vnom^2, cs = base * ci / Vnom, nl = nothing)
    else  # exponential
        γ = _coeff_k(load, gkey, k)
        γ == 0.0 && return (cc = base,            cW = 0.0,             cs = 0.0,            nl = nothing)
        γ == 2.0 && return (cc = 0.0,             cW = base / Vnom^2,   cs = 0.0,            nl = nothing)
        γ == 1.0 && return (cc = 0.0,             cW = 0.0,             cs = base / Vnom,    nl = nothing)
        return (cc = 0.0, cW = 0.0, cs = 0.0, nl = (base, γ))
    end
end

function _rhs_expr(model, t, W, s, Vnom::Float64)
    if t.nl !== nothing
        base, γ = t.nl
        return @expression(model, base * (W / Vnom^2)^(γ / 2))
    end
    e = @expression(model, t.cc + t.cW * W)
    t.cs != 0.0 && (e = @expression(model, e + t.cs * s))
    e
end

# Pin one sub-load's realized power (P_tot, Q_tot) to its model.
function _add_subload_power!(model, load, lid, k, P_tot, Q_tot, p0, q0, dvr, dvi;
                             register_constraint=nothing,
                             register_variable=nothing)
    register(family, cref) = register_constraint === nothing ? cref :
        register_constraint(family, (string(lid), k), cref)
    if get(load, "model", "constant_power") == "constant_power"
        register(:load_power_real, @constraint(model, P_tot == p0))
        register(:load_power_imag, @constraint(model, Q_tot == q0))
        return
    end

    Vnom = _load_vnom_k(load, k)
    pt = _component_terms(load, ("alpha_z","alpha_i","alpha_p"), "gamma_p", p0, Vnom, k)
    qt = _component_terms(load, ("beta_z","beta_i","beta_p"),    "gamma_q", q0, Vnom, k)

    W = @variable(model, base_name = "W_$(lid)_$(k)",
                  lower_bound = (_W_FLOOR_FRAC * Vnom)^2,
                  upper_bound = (_W_CEIL_FRAC  * Vnom)^2)
    register_variable !== nothing &&
        register_variable(:load_voltage_squared, (string(lid), k), W)
    register(:load_voltage_squared_definition,
        @constraint(model, W == dvr^2 + dvi^2))
    register(:load_voltage_squared_lower_bound, JuMP.LowerBoundRef(W))
    register(:load_voltage_squared_upper_bound, JuMP.UpperBoundRef(W))

    s = nothing
    if pt.cs != 0.0 || qt.cs != 0.0
        s = @variable(model, base_name = "s_$(lid)_$(k)",
                      lower_bound = _W_FLOOR_FRAC * Vnom,
                      upper_bound = _W_CEIL_FRAC  * Vnom)
        register_variable !== nothing &&
            register_variable(:load_voltage_magnitude, (string(lid), k), s)
        register(:load_voltage_magnitude_definition, @constraint(model, s^2 == W))
        register(:load_voltage_magnitude_lower_bound, JuMP.LowerBoundRef(s))
        register(:load_voltage_magnitude_upper_bound, JuMP.UpperBoundRef(s))
    end

    register(:load_power_real,
        @constraint(model, P_tot == _rhs_expr(model, pt, W, s, Vnom)))
    register(:load_power_imag,
        @constraint(model, Q_tot == _rhs_expr(model, qt, W, s, Vnom)))
end

"""
    _add_load_constraints!(model, net, vars, kcl_r, kcl_i)

Add load power-balance constraints (constant-power / ZIP / exponential) for all
loads and register load currents in the KCL accumulators. Both WYE/SINGLE_PHASE
and DELTA topologies are supported; the neutral return current flows through KCL
automatically and is not an independent variable.
"""
function _add_load_constraints!(model, net, vars, kcl_r, kcl_i;
                                coefficient=nothing,
                                constraint_context=nothing)
    vr = vars[:vr]; vi = vars[:vi]
    crd = vars[:crd]; cid = vars[:cid]
    nlabels = BMOPFTools._neutral_labels(net)
    register(family, index, cref) = _register_semantic_constraint!(
        constraint_context, family, index, cref)
    register_load_variable(family, index, variable) =
        constraint_context === nothing ? variable :
        BMOPFTools.register_opf_object!(constraint_context,
            BMOPFTools.OpfModelKey(:variable, family, index), variable)

    for (lid, load) in get(net, "load", Dict())
        bus = get(load, "bus", "")
        tm  = Vector{String}(get(load, "terminal_map", String[]))
        cfg = get(load, "configuration", "WYE")
        p_nom = Float64.(get(load, "p_nom", Float64[]))
        q_nom = Float64.(get(load, "q_nom", Float64[]))

        if cfg == "SINGLE_PHASE" && length(tm) == 2
            # A single-phase load is ONE two-terminal element connected between
            # the two listed terminals — whether that is phase-to-neutral
            # (["a","n"]) or phase-to-phase (["a","b"], e.g. a 240 V load across
            # the two legs of a split-phase service). The generic WYE path below
            # would mis-read a phase-to-phase map as a phase-to-ground load on
            # the first terminal (and silently drop the second), so handle the
            # two-terminal case explicitly here.
            t_pos, t_neg = tm[1], tm[2]
            if length(p_nom) >= 1
                dvr = @expression(model, vr[(bus, t_pos)] - vr[(bus, t_neg)])
                dvi = @expression(model, vi[(bus, t_pos)] - vi[(bus, t_neg)])

                P_tot = @expression(model, dvr * crd[(lid,1)] + dvi * cid[(lid,1)])
                Q_tot = @expression(model, dvi * crd[(lid,1)] - dvr * cid[(lid,1)])
                p0 = coefficient === nothing ? p_nom[1] : coefficient(
                    :load, :load, lid, :p_nom, 1, p_nom[1])
                q0 = coefficient === nothing ? q_nom[1] : coefficient(
                    :load, :load, lid, :q_nom, 1, q_nom[1])
                _add_subload_power!(model, load, lid, 1, P_tot, Q_tot,
                                    p0, q0, dvr, dvi;
                                    register_constraint=(family, index, cref) ->
                                        register(family, index, cref),
                                    register_variable=register_load_variable)

                _kcl_add!(kcl_r, kcl_i, bus, t_pos, -crd[(lid,1)], -cid[(lid,1)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg,  crd[(lid,1)],  cid[(lid,1)])
            end

        elseif cfg in ("WYE", "SINGLE_PHASE")
            ph_pos = _phase_positions(tm, nlabels)
            n_pos_idx = _neutral_pos(tm, nlabels)
            t_n = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing

            for (idx, ph) in enumerate(ph_pos)
                length(p_nom) >= idx || continue
                t_ph = tm[ph]
                vr_ph = vr[(bus, t_ph)]; vi_ph = vi[(bus, t_ph)]
                if t_n !== nothing
                    dvr = @expression(model, vr_ph - vr[(bus, t_n)])
                    dvi = @expression(model, vi_ph - vi[(bus, t_n)])
                else
                    dvr = vr_ph; dvi = vi_ph
                end

                P_tot = @expression(model, dvr * crd[(lid,idx)] + dvi * cid[(lid,idx)])
                Q_tot = @expression(model, dvi * crd[(lid,idx)] - dvr * cid[(lid,idx)])
                p0 = coefficient === nothing ? p_nom[idx] : coefficient(
                    :load, :load, lid, :p_nom, idx, p_nom[idx])
                q0 = coefficient === nothing ? q_nom[idx] : coefficient(
                    :load, :load, lid, :q_nom, idx, q_nom[idx])
                _add_subload_power!(model, load, lid, idx, P_tot, Q_tot,
                                    p0, q0, dvr, dvi;
                                    register_constraint=(family, index, cref) ->
                                        register(family, index, cref),
                                    register_variable=register_load_variable)

                _kcl_add!(kcl_r, kcl_i, bus, t_ph, -crd[(lid,idx)], -cid[(lid,idx)])
                t_n !== nothing &&
                    _kcl_add!(kcl_r, kcl_i, bus, t_n, crd[(lid,idx)], cid[(lid,idx)])
            end

        elseif cfg == "DELTA"
            n_c = length(tm)
            for k in 1:n_c
                length(p_nom) >= k || continue
                t_pos = tm[k]
                t_neg = tm[(k % n_c) + 1]
                dvr = @expression(model, vr[(bus, t_pos)] - vr[(bus, t_neg)])
                dvi = @expression(model, vi[(bus, t_pos)] - vi[(bus, t_neg)])

                P_tot = @expression(model, dvr * crd[(lid,k)] + dvi * cid[(lid,k)])
                Q_tot = @expression(model, dvi * crd[(lid,k)] - dvr * cid[(lid,k)])
                p0 = coefficient === nothing ? p_nom[k] : coefficient(
                    :load, :load, lid, :p_nom, k, p_nom[k])
                q0 = coefficient === nothing ? q_nom[k] : coefficient(
                    :load, :load, lid, :q_nom, k, q_nom[k])
                _add_subload_power!(model, load, lid, k, P_tot, Q_tot,
                                    p0, q0, dvr, dvi;
                                    register_constraint=(family, index, cref) ->
                                        register(family, index, cref),
                                    register_variable=register_load_variable)

                _kcl_add!(kcl_r, kcl_i, bus, t_pos, -crd[(lid,k)], -cid[(lid,k)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg,  crd[(lid,k)],  cid[(lid,k)])
            end
        else
            @warn "Load '$lid': unknown configuration '$cfg' — skipping."
        end
    end
end
