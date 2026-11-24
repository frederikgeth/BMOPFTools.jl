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

# Rough per-phase (P, Q) operating point used only to seed generator currents:
# the midpoint of each finite box, else 0. The constraints decide the optimum.
function _generator_power_target(p_min, p_max, q_min, q_max, idx)
    mid(lo, hi) = (length(lo) >= idx && length(hi) >= idx &&
                   isfinite(lo[idx]) && isfinite(hi[idx])) ? (lo[idx] + hi[idx]) / 2 : 0.0
    return mid(p_min, p_max), mid(q_min, q_max)
end

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
with `p_min[k] ≤ P_k ≤ p_max[k]` and `q_min[k] ≤ Q_k ≤ q_max[k]`. Equal static
bounds become one equality row (see `_box_constraints!`).
DELTA generators use the same bilinear form with line-to-line voltage.
"""
function _add_generator_constraints!(model, net, vars, kcl_r, kcl_i;
                                     coefficient=nothing,
                                     constraint_context=nothing)
    vr = vars[:vr]; vi = vars[:vi]
    crg = vars[:crg]; cig = vars[:cig]
    nlabels = BMOPFTools._neutral_labels(net)
    register(family, index, cref) = _register_semantic_constraint!(
        constraint_context, family, index, cref)

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

        # P/Q box rows per phase: :generator_{p,q}_{lower,upper}, or one
        # :generator_{p,q}_equality row when a static minimum equals its maximum.
        bound(values, category, field, k) = length(values) >= k ?
            (coefficient === nothing ? values[k] :
             coefficient(category, :generator, gid, field, k, values[k])) : nothing
        function stamp_power_bounds!(p_expr, q_expr, k)
            for (quantity, expr, lo, hi) in (
                    (:p, p_expr, bound(p_min, :limit, :p_min, k),
                                 bound(p_max, :availability, :p_max, k)),
                    (:q, q_expr, bound(q_min, :limit, :q_min, k),
                                 bound(q_max, :limit, :q_max, k)))
                for (side, cref) in pairs(_box_constraints!(model, expr, lo, hi))
                    register(Symbol(:generator_, quantity, :_, side),
                             (string(gid), k), cref)
                end
            end
        end

        if cfg in ("WYE", "SINGLE_PHASE")
            ph_pos, n_pos_idx = _generator_positions(tm, cfg, nlabels)
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
                p_seed, q_seed = _generator_power_target(p_min, p_max, q_min, q_max, idx)
                _seed_power_current!(crg[(gid,idx)], cig[(gid,idx)], dvr, dvi, p_seed, q_seed)

                stamp_power_bounds!(p_expr, q_expr, idx)

                # Current magnitude limit (per conductor; single-phase collapsed)
                if phase_ilim[idx] !== nothing
                    _soc_norm!(model, crg[(gid,idx)], cig[(gid,idx)], phase_ilim[idx])
                    _limit_current_box!(crg[(gid,idx)], cig[(gid,idx)], phase_ilim[idx])
                end

                # Apparent power limit (via auxiliary variables to keep quadratic)
                if length(s_max_g) >= idx
                    pg_v = @variable(model, base_name = "pg_$(gid)_$(idx)")
                    qg_v = @variable(model, base_name = "qg_$(gid)_$(idx)")
                    JuMP.set_start_value(pg_v, p_seed)
                    JuMP.set_start_value(qg_v, q_seed)
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
                p_seed, q_seed = _generator_power_target(p_min, p_max, q_min, q_max, k)
                _seed_power_current!(crg[(gid,k)], cig[(gid,k)], dvr, dvi, p_seed, q_seed)

                stamp_power_bounds!(p_expr, q_expr, k)

                # Current magnitude limit
                if length(i_max_g) >= k
                    _soc_norm!(model, crg[(gid,k)], cig[(gid,k)], i_max_g[k])
                    _limit_current_box!(crg[(gid,k)], cig[(gid,k)], i_max_g[k])
                end

                # Apparent power limit (via auxiliary variables to keep quadratic)
                if length(s_max_g) >= k
                    pg_v = @variable(model, base_name = "pg_$(gid)_$(k)")
                    qg_v = @variable(model, base_name = "qg_$(gid)_$(k)")
                    JuMP.set_start_value(pg_v, p_seed)
                    JuMP.set_start_value(qg_v, q_seed)
                    @constraint(model, pg_v == p_expr)
                    @constraint(model, qg_v == q_expr)
                    _soc_norm!(model, pg_v, qg_v, s_max_g[k])
                end

                _kcl_add!(kcl_r, kcl_i, bus, t_pos,  crg[(gid,k)],  cig[(gid,k)])
                _kcl_add!(kcl_r, kcl_i, bus, t_neg, -crg[(gid,k)], -cig[(gid,k)])
            end
        else
            throw(ArgumentError("Generator '$gid': unsupported configuration '$cfg'."))
        end
    end
end

# Voltage-source slack and voltage-fixing constraints live in `source.jl`.
