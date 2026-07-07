# Generator constraints.
#
# Generators: P/Q bounds expressed via bilinear power equations.
# (Voltage-source constraints live in source.jl.)
#
# ── Generator (WYE / SINGLE_PHASE) ────────────────────────────────────────
# For phase conductor k (1-based in the phase subset of terminal_map):
#   P_k = (vr[t_ph] - vr[t_n]) * crg[k] + (vi[t_ph] - vi[t_n]) * cig[k]
#   Q_k = (vi[t_ph] - vi[t_n]) * crg[k] - (vr[t_ph] - vr[t_n]) * cig[k]
#   p_min[k] <= P_k <= p_max[k]
#   q_min[k] <= Q_k <= q_max[k]
# KCL: phase terminal += crg[k], neutral terminal -= crg[k].

"""
    _add_generator_constraints!(model, net, vars, kcl_r, kcl_i)

Add constant-power P/Q bound constraints for all generators and register generator
currents in the KCL accumulators.

For WYE/SINGLE_PHASE generators, real and reactive power per phase `k` are
related to the phase-to-neutral voltage and the current variables by:
```
  P_k = (vr_ph − vr_n)·crg[k] + (vi_ph − vi_n)·cig[k]
  Q_k = (vi_ph − vi_n)·crg[k] − (vr_ph − vr_n)·cig[k]
```
with `p_min[k] ≤ P_k ≤ p_max[k]` and `q_min[k] ≤ Q_k ≤ q_max[k]`.
DELTA generators use the same bilinear form with line-to-line voltage.
"""
function _add_generator_constraints!(model, net, vars, kcl_r, kcl_i)
    vr = vars[:vr]; vi = vars[:vi]
    crg = vars[:crg]; cig = vars[:cig]

    for (gid, gen) in get(net, "generator", Dict())
        bus       = get(gen, "bus", "")
        tm        = Vector{String}(get(gen, "terminal_map", String[]))
        cfg       = get(gen, "configuration", "WYE")
        p_min     = Float64.(get(gen, "p_min", Float64[]))
        p_max     = Float64.(get(gen, "p_max", Float64[]))
        q_min     = Float64.(get(gen, "q_min", Float64[]))
        q_max     = Float64.(get(gen, "q_max", Float64[]))
        i_max_g   = Float64.(get(gen, "i_max", Float64[]))
        s_max_g   = Float64.(get(gen, "s_max", Float64[]))

        if cfg in ("WYE", "SINGLE_PHASE")
            ph_pos    = _phase_positions(tm)
            n_pos_idx = _neutral_pos(tm)
            t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing
            n_ph      = length(ph_pos)

            # i_max is per CONDUCTOR. For a single-phase device (one phase + its
            # return) the phase and neutral are the SAME current, so collapse any
            # entries to one circle at the tighter limit (never constrain twice).
            # For ≥2 phases the per-phase entries and the trailing neutral entry
            # bound genuinely distinct quantities.
            phase_ilim  = fill!(Vector{Union{Float64,Nothing}}(undef, n_ph), nothing)
            neutral_ilim = nothing
            if n_ph == 1
                isempty(i_max_g) || (phase_ilim[1] = minimum(i_max_g))
            else
                for idx in 1:n_ph
                    length(i_max_g) >= idx && (phase_ilim[idx] = i_max_g[idx])
                end
                t_n !== nothing && length(i_max_g) == n_ph + 1 &&
                    (neutral_ilim = i_max_g[n_ph + 1])
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

                p_expr = @expression(model, dvr*crg[(gid,idx)] + dvi*cig[(gid,idx)])
                q_expr = @expression(model, dvi*crg[(gid,idx)] - dvr*cig[(gid,idx)])

                length(p_min) >= idx && @constraint(model, p_expr >= p_min[idx])
                length(p_max) >= idx && @constraint(model, p_expr <= p_max[idx])
                length(q_min) >= idx && @constraint(model, q_expr >= q_min[idx])
                length(q_max) >= idx && @constraint(model, q_expr <= q_max[idx])

                # Current magnitude limit (per conductor; single-phase collapsed)
                if phase_ilim[idx] !== nothing
                    _soc_norm!(model, crg[(gid,idx)], cig[(gid,idx)], phase_ilim[idx])
                    _limit_current_box!(crg[(gid,idx)], cig[(gid,idx)], phase_ilim[idx])
                end

                # Apparent power limit (via auxiliary variables to keep quadratic)
                if length(s_max_g) >= idx
                    pg_v = @variable(model, base_name = "pg_$(gid)_$(idx)")
                    qg_v = @variable(model, base_name = "qg_$(gid)_$(idx)")
                    @constraint(model, pg_v == p_expr)
                    @constraint(model, qg_v == q_expr)
                    _soc_norm!(model, pg_v, qg_v, s_max_g[idx])
                end

                _kcl_add!(kcl_r, kcl_i, bus, t_ph,  crg[(gid,idx)],  cig[(gid,idx)])
                if t_n !== nothing
                    _kcl_add!(kcl_r, kcl_i, bus, t_n, -crg[(gid,idx)], -cig[(gid,idx)])
                end
            end

            # Neutral-conductor current limit (≥2 phases): cap the neutral return
            # current = −Σ phase currents at the trailing per-conductor entry.
            if neutral_ilim !== nothing
                _neutral_current_limit!(model,
                    [crg[(gid,idx)] for idx in 1:n_ph],
                    [cig[(gid,idx)] for idx in 1:n_ph], neutral_ilim)
            end

        elseif cfg == "DELTA"
            n_c = length(tm)
            for k in 1:n_c
                t_pos = tm[k]; t_neg = tm[(k % n_c) + 1]
                dvr = @expression(model, vr[(bus,t_pos)] - vr[(bus,t_neg)])
                dvi = @expression(model, vi[(bus,t_pos)] - vi[(bus,t_neg)])

                p_expr = @expression(model, dvr*crg[(gid,k)] + dvi*cig[(gid,k)])
                q_expr = @expression(model, dvi*crg[(gid,k)] - dvr*cig[(gid,k)])

                length(p_min) >= k && @constraint(model, p_expr >= p_min[k])
                length(p_max) >= k && @constraint(model, p_expr <= p_max[k])
                length(q_min) >= k && @constraint(model, q_expr >= q_min[k])
                length(q_max) >= k && @constraint(model, q_expr <= q_max[k])

                # Current magnitude limit
                if length(i_max_g) >= k
                    _soc_norm!(model, crg[(gid,k)], cig[(gid,k)], i_max_g[k])
                    _limit_current_box!(crg[(gid,k)], cig[(gid,k)], i_max_g[k])
                end

                # Apparent power limit (via auxiliary variables to keep quadratic)
                if length(s_max_g) >= k
                    pg_v = @variable(model, base_name = "pg_$(gid)_$(k)")
                    qg_v = @variable(model, base_name = "qg_$(gid)_$(k)")
                    @constraint(model, pg_v == p_expr)
                    @constraint(model, qg_v == q_expr)
                    _soc_norm!(model, pg_v, qg_v, s_max_g[k])
                end

                _kcl_add!(kcl_r, kcl_i, bus, t_pos,  crg[(gid,k)],  cig[(gid,k)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg, -crg[(gid,k)], -cig[(gid,k)])
            end
        else
            @warn "Generator '$gid': unknown configuration '$cfg' — skipping."
        end
    end
end

# Voltage-source slack and voltage-fixing constraints live in `source.jl`.
