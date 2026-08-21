# Voltage-source constraints for the four-wire IVR-EN OPF.
#
# A voltage source is an ideal voltage reference *with* a current slack: it fixes
# the bus terminal voltages and injects a free current (cr_src/ci_src) into KCL.
# This is the OpenDSS/PMD `Vsource` semantics. Because the terminal voltages are
# fixed, the per-phase P/Q are LINEAR in the slack current variables.
#
# Voltage reference is phase-to-neutral (WYE / SINGLE_PHASE). The neutral terminal
# at the source bus is fixed to 0 V (system ground); the slack neutral return
# current −Σ cr_src is injected there so neutral KCL is satisfied.
#
# Optional per-phase P/Q box bounds turn the source into a bounded grid
# connection; an optional `cost` (handled in objective.jl) prices imported power.
# Empty/absent bound vectors leave the source unbounded (pure power-flow slack).
#
#   P_k = (vr_ph − vr_n)·cr_src[k] + (vi_ph − vi_n)·ci_src[k]
#   Q_k = (vi_ph − vi_n)·cr_src[k] − (vr_ph − vr_n)·ci_src[k]
#   p_min[k] ≤ P_k ≤ p_max[k] ,  q_min[k] ≤ Q_k ≤ q_max[k]
#   KCL: bus,t_ph += cr_src[k]/ci_src[k] ;  bus,t_n −= Σ cr_src[k]/ci_src[k]

"""
    _add_source_constraints!(model, net, vars, kcl_r, kcl_i)

Fix voltage-source terminal voltages and register the source slack current in the
KCL accumulators, with optional per-phase P/Q box bounds.

Each phase terminal is fixed to `v_mag·cos(v_ang)`, `v_mag·sin(v_ang)`. The source
neutral (if the bus has one) is fixed to 0 V. Phase slack currents `cr_src`/`ci_src`
are injected into KCL at the phase terminals, with the summed return current at the
neutral. When `p_min/p_max/q_min/q_max` are present, the corresponding (linear)
per-phase power constraints are added.
"""
function _add_source_constraints!(model, net, vars, kcl_r, kcl_i;
                                  constraint_context=nothing)
    vr = vars[:vr]; vi = vars[:vi]
    cr_src = vars[:cr_src]; ci_src = vars[:ci_src]
    nlabels = BMOPFTools._neutral_labels(net)
    register(family, index, cref) = _register_semantic_constraint!(
        constraint_context, family, index, cref)

    for (sid, vs) in get(net, "voltage_source", Dict())
        bus   = get(vs, "bus", "")
        tm    = Vector{String}(get(vs, "terminal_map", String[]))
        cfg   = get(vs, "configuration", "WYE")
        v_mag = Float64.(get(vs, "v_magnitude", Float64[]))
        v_ang = Float64.(get(vs, "v_angle",     Float64[]))
        p_min = Float64.(get(vs, "p_min", Float64[]))
        p_max = Float64.(get(vs, "p_max", Float64[]))
        q_min = Float64.(get(vs, "q_min", Float64[]))
        q_max = Float64.(get(vs, "q_max", Float64[]))

        # ── Fix terminal voltages to the magnitude/angle reference ──────────────
        for (k, t) in enumerate(tm)
            if length(v_mag) >= k && length(v_ang) >= k
                real_was_fixed = JuMP.is_fixed(vr[(bus, t)])
                imag_was_fixed = JuMP.is_fixed(vi[(bus, t)])
                fix(vr[(bus, t)], v_mag[k] * cos(v_ang[k]); force=true)
                fix(vi[(bus, t)], v_mag[k] * sin(v_ang[k]); force=true)
                real_was_fixed || register(:source_voltage_real,
                    (string(sid), string(t)), JuMP.FixRef(vr[(bus, t)]))
                imag_was_fixed || register(:source_voltage_imag,
                    (string(sid), string(t)), JuMP.FixRef(vi[(bus, t)]))
            end
        end

        # Fix the neutral voltage at the source bus to 0 (system ground). The
        # source's terminal_map lists only phase terminals; lines/loads attached
        # to this bus also bring a neutral terminal there, which would otherwise
        # be a free variable with no voltage reference (a KKT null space). The
        # slack neutral return current below satisfies neutral KCL. The neutral
        # name comes from the bus's own declaration (neutral_terminal field /
        # convention heuristics) rather than assuming the literal name "n".
        src_bus_nt = BMOPFTools._neutral_terminal(
            get(get(net, "bus", Dict()), bus, Dict{String,Any}()))
        for (b, t) in keys(vr)
            b == bus && (t == src_bus_nt || t in nlabels) || continue
            if !JuMP.is_fixed(vr[(bus, t)])
                fix(vr[(bus, t)], 0.0; force=true)
                register(:source_neutral_voltage_real,
                    (string(sid), string(t)), JuMP.FixRef(vr[(bus, t)]))
            end
            if !JuMP.is_fixed(vi[(bus, t)])
                fix(vi[(bus, t)], 0.0; force=true)
                register(:source_neutral_voltage_imag,
                    (string(sid), string(t)), JuMP.FixRef(vi[(bus, t)]))
            end
        end

        # ── Slack current injection + optional P/Q bounds ───────────────────────
        if cfg in ("WYE", "SINGLE_PHASE")
            ph_pos    = _phase_positions(tm, nlabels)
            n_pos_idx = _neutral_pos(tm, nlabels)
            # Prefer an explicit neutral in the terminal_map; otherwise fall back
            # to the bus neutral terminal (fixed to 0 above) for the return path.
            t_n = if n_pos_idx !== nothing
                tm[n_pos_idx]
            else
                bt = get(get(net, "bus", Dict()), bus, Dict())
                BMOPFTools._neutral_terminal(bt)
            end

            for (idx, ph) in enumerate(ph_pos)
                t_ph = tm[ph]
                vr_ph = vr[(bus, t_ph)]; vi_ph = vi[(bus, t_ph)]
                if t_n !== nothing
                    dvr = @expression(model, vr_ph - vr[(bus, t_n)])
                    dvi = @expression(model, vi_ph - vi[(bus, t_n)])
                else
                    dvr = vr_ph; dvi = vi_ph
                end

                if !isempty(p_min) || !isempty(p_max) || !isempty(q_min) || !isempty(q_max)
                    p_expr = @expression(model, dvr*cr_src[(sid,idx)] + dvi*ci_src[(sid,idx)])
                    q_expr = @expression(model, dvi*cr_src[(sid,idx)] - dvr*ci_src[(sid,idx)])
                    if length(p_min) >= idx
                        register(:source_p_lower, (string(sid), idx),
                            @constraint(model, p_expr >= p_min[idx]))
                    end
                    if length(p_max) >= idx
                        register(:source_p_upper, (string(sid), idx),
                            @constraint(model, p_expr <= p_max[idx]))
                    end
                    if length(q_min) >= idx
                        register(:source_q_lower, (string(sid), idx),
                            @constraint(model, q_expr >= q_min[idx]))
                    end
                    if length(q_max) >= idx
                        register(:source_q_upper, (string(sid), idx),
                            @constraint(model, q_expr <= q_max[idx]))
                    end
                end

                _kcl_add!(kcl_r, kcl_i, bus, t_ph,  cr_src[(sid,idx)],  ci_src[(sid,idx)])
                if t_n !== nothing
                    _kcl_add!(kcl_r, kcl_i, bus, t_n, -cr_src[(sid,idx)], -ci_src[(sid,idx)])
                end
            end
        else
            @warn "Voltage source '$sid': unsupported configuration '$cfg' — " *
                  "slack current not injected."
        end
    end
end
