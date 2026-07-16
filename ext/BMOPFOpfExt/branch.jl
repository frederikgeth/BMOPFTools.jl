# Line and switch constraints.
#
# ── Lines (nominal Π model) ───────────────────────────────────────────────────
#
# Each line is modelled as a nominal Π equivalent:
#
#   from-bus ─┬─[Y_sh_fr/2]─ ─ ─[Z_series]─ ─ ─[Y_sh_to/2]─┬─ to-bus
#             └──(to ground)                   (to ground)──┘
#
# Series KVL (conductor k, total impedance Z = R + jX in Ω):
#   vr_fr[k] − vr_to[k]  =  Σ_j ( R[k,j]·cr_fr[j] − X[k,j]·ci_fr[j] )
#   vi_fr[k] − vi_to[k]  =  Σ_j ( R[k,j]·ci_fr[j] + X[k,j]·cr_fr[j] )
#
# cr_fr[k] is the only independent series current variable (from → to direction).
# The to-side series current is the AffExpr alias:
#   cr_to[k] := −cr_fr[k],  ci_to[k] := −ci_fr[k]
#
# π-shunt current leaving bus b at conductor k (AffExpr, linear in vr/vi):
#   ish^r_k = Σ_j ( G_kj · vr[b,t_j] − B_kj · vi[b,t_j] )
#   ish^i_k = Σ_j ( G_kj · vi[b,t_j] + B_kj · vr[b,t_j] )
#
# Total current (series + shunt) — AffExpr, substituted directly into KCL and limits:
#   I^tot_fr[k] = cr_fr[k] + ish^r_fr[k]      (leaving from-bus)
#   I^tot_to[k] = −cr_fr[k] + ish^r_to[k]     (leaving to-bus)
#
# KCL contributions (sign convention: positive = into bus):
#   bus_from, tmfr[k]: −I^tot_fr[k]
#   bus_to,   tmto[k]: −I^tot_to[k]
#
# Current magnitude limits:
#   (I^tot_fr[k])² ≤ I_max[k]²
#   (I^tot_to[k])² ≤ I_max[k]²
#
# When shunts are zero, I^tot_fr = cr_fr and I^tot_to = −cr_fr, so the two
# limits are symmetric and either alone would suffice; both are kept for
# generality when shunts are non-zero.

"""
    _assert_no_parallel_zero_impedance(net)

Throw if two *zero-impedance* branches — a closed switch, or a line whose entire
series impedance is zero — directly bridge the SAME conductor endpoints, i.e. the
same `(bus, terminal)` pair on both ends.

A zero-impedance branch imposes `V_from == V_to` on its conductors. Two of them
across the same node pair impose that equality twice and leave two current
variables whose only determined quantity is their SUM (fixed by KCL) — the split
is a free degree of freedom, a singular KKT system with infinitely many optima.
Finite-impedance parallels are fine (each current is pinned by its own Ohm's-law
drop); only the zero-impedance case is rejected. The check is per conductor
(same terminals), not per bus: two branches on different conductors of the same
bus pair are independent and allowed.
"""
function _assert_no_parallel_zero_impedance(net)
    linecodes = get(net, "linecode", Dict())
    Node = Tuple{String,String}
    seen = Dict{Tuple{Node,Node}, String}()
    function record!(bid, b_fr, b_to, tmfr, tmto, n)
        for k in 1:n
            p::Node = (b_fr, tmfr[k]); q::Node = (b_to, tmto[k])
            key = p <= q ? (p, q) : (q, p)
            if haskey(seen, key)
                error("Parallel zero-impedance branches: '$(seen[key])' and " *
                    "'$bid' both directly bridge terminals $p — $q with zero " *
                    "series impedance, so the current split between them is " *
                    "undetermined (singular system). Merge them into one branch, " *
                    "or give one a finite impedance.")
            end
            seen[key] = bid
        end
    end
    # Closed switches are always zero-impedance (V_from == V_to); open ones are
    # electrically disconnected and impose no coupling.
    for (sid, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        tmfr = Vector{String}(get(sw, "terminal_map_from", String[]))
        tmto = Vector{String}(get(sw, "terminal_map_to",   String[]))
        record!(sid, sw["bus_from"], sw["bus_to"], tmfr, tmto,
                min(length(tmfr), length(tmto)))
    end
    # Lines whose entire series impedance matrix is zero (stamped as V_from==V_to).
    for (lid, line) in get(net, "line", Dict())
        R, X, n_c = _line_z_matrix(line, linecodes)
        (n_c == 0 || R === nothing || X === nothing) && continue
        (all(iszero, R) && all(iszero, X)) || continue
        tmfr = Vector{String}(get(line, "terminal_map_from", String[]))
        tmto = Vector{String}(get(line, "terminal_map_to",   String[]))
        record!(lid, line["bus_from"], line["bus_to"], tmfr, tmto,
                min(n_c, length(tmfr), length(tmto)))
    end
    return nothing
end

"""
    _add_line_constraints!(model, net, vars, kcl_r, kcl_i)

Add nominal Π-model constraints for all lines and register their KCL
contributions.

For each line this adds:
- KVL across the series impedance (real and imaginary parts per conductor)
- π-shunt KCL contributions at both buses (linear in voltage variables)
- Thermal current magnitude limits on the **total** current (series + π-shunt)
  at both the from- and to-ends

`cr_to`/`ci_to` are `AffExpr` aliases (`−cr_fr`) — no equality constraints needed.

Impedance comes from the line's single source: the referenced linecode
(per-metre matrices × `length`) or inline absolute matrices on the line
(Ω/S, used as-is). Shunt conductance (`G_from`, `G_to`) and susceptance
(`B_from`, `B_to`) follow the same rule. Missing or all-zero shunt fields
are a no-op.
"""
function _add_line_constraints!(model, net, vars, kcl_r, kcl_i;
                                grounded::Set{Tuple{String,String}}=Set{Tuple{String,String}}(),
                                branch_inj=nothing)
    linecodes = get(net, "linecode", Dict())
    buses = get(net, "bus", Dict())
    vr = vars[:vr]; vi = vars[:vi]
    cr_fr = vars[:cr_fr]; ci_fr = vars[:ci_fr]
    cr_to = vars[:cr_to]; ci_to = vars[:ci_to]

    for (lid, line) in get(net, "line", Dict())
        R, X, n_c = _line_z_matrix(line, linecodes)
        if n_c == 0
            @warn "Line '$lid': no impedance source (missing/unknown linecode " *
                  "and no inline matrices) — skipping KVL."
            continue
        end

        b_fr  = line["bus_from"]
        b_to  = line["bus_to"]
        tmfr  = Vector{String}(get(line, "terminal_map_from", String[]))
        tmto  = Vector{String}(get(line, "terminal_map_to",   String[]))
        # The impedance matrix is n_c×n_c and matrix row k is the impedance seen
        # by conductor k of each terminal map. The counts must match exactly —
        # silently truncating to the minimum (as admittance tools do) would drop
        # conductors and mutual coupling, or misalign rows with terminal roles,
        # and solve to a plausible-but-wrong answer. Refuse instead.
        if length(tmfr) != n_c || length(tmto) != n_c
            error("Line '$lid': impedance matrix is $(n_c)×$(n_c) but the " *
                  "terminal maps have lengths ($(length(tmfr)), $(length(tmto))). " *
                  "A $(n_c)-conductor linecode/inline matrix must be used on a " *
                  "$(n_c)-terminal line; there is no meaningful truncation. " *
                  "Fix the linecode/geometry or the terminal maps " *
                  "(validation reports this as E.INT.LINE_DIM_MISMATCH).")
        end
        n_map = n_c

        # ── KVL ───────────────────────────────────────────────────────────────
        for k in 1:n_map
            t_fr = tmfr[k]; t_to = tmto[k]
            @constraint(model,
                vr[(b_fr, t_fr)] - vr[(b_to, t_to)] ==
                sum(R[k,j]*cr_fr[(lid,j)] - X[k,j]*ci_fr[(lid,j)] for j in 1:n_map))
            @constraint(model,
                vi[(b_fr, t_fr)] - vi[(b_to, t_to)] ==
                sum(R[k,j]*ci_fr[(lid,j)] + X[k,j]*cr_fr[(lid,j)] for j in 1:n_map))
        end

        # ── π-shunt currents (linear in voltage variables) ────────────────────
        G_fr, B_fr, G_to, B_to = _line_pi_shunt(line, linecodes)

        ish_fr_r = [JuMP.AffExpr(0.0) for _ in 1:n_map]
        ish_fr_i = [JuMP.AffExpr(0.0) for _ in 1:n_map]
        ish_to_r = [JuMP.AffExpr(0.0) for _ in 1:n_map]
        ish_to_i = [JuMP.AffExpr(0.0) for _ in 1:n_map]

        _shunt_current!(ish_fr_r, ish_fr_i, vr, vi, G_fr, B_fr, b_fr, tmfr[1:n_map])
        _shunt_current!(ish_to_r, ish_to_i, vr, vi, G_to, B_to, b_to, tmto[1:n_map])

        # ── KCL: series currents + π-shunt currents, both leaving their bus ───
        entry = ("line", lid)
        for k in 1:n_map
            _kcl_add!(kcl_r, kcl_i, b_fr, tmfr[k],
                      -cr_fr[(lid,k)] - ish_fr_r[k],
                      -ci_fr[(lid,k)] - ish_fr_i[k]; ledger=branch_inj, entry=entry)
            _kcl_add!(kcl_r, kcl_i, b_to, tmto[k],
                      -cr_to[(lid,k)] - ish_to_r[k],
                      -ci_to[(lid,k)] - ish_to_i[k]; ledger=branch_inj, entry=entry)
        end

        # ── Thermal current limits on total current at each end ───────────────
        # The to-side total current is cr_to + ish_to = −cr_fr + ish_to. It has
        # the same magnitude as the from-side total (cr_fr + ish_fr) only when
        # BOTH π-shunts vanish (then both ends are ±cr_fr). If either side has a
        # shunt the two magnitudes differ, so the to-side needs its own cone;
        # otherwise the from-side cone alone would leave |cr_fr| unbounded up to
        # i_max + |ish_fr|. Add the to-side cone whenever any shunt is present.
        has_any_shunt = !(G_fr === nothing && B_fr === nothing &&
                          G_to === nothing && B_to === nothing)
        lc = get(linecodes, get(line, "linecode", ""), nothing)
        # line-level i_max overrides the linecode's (and is the only rating
        # source for lines carrying inline absolute matrices)
        i_max = get(line, "i_max", nothing)
        i_max === nothing && lc !== nothing && (i_max = get(lc, "i_max", nothing))
        begin
            if i_max !== nothing
                # Sound box bound on the bare series current variable. The cone
                # limits the *total* current I_tot = c_series + I_shunt, so
                #   |c_series| ≤ |I_tot| + |I_shunt| ≤ i_max + |I_shunt|^max,
                # with |I_shunt,k|^max ≤ Σ_j |Y_fr,kj|·V^max_fr,j. The box is added
                # only when every voltage cap feeding row k is known (else the
                # row's shunt term is unbounded and we must leave c_fr[k] free).
                bus_fr = get(buses, b_fr, Dict{String,Any}())
                vmax_fr = Union{Float64,Nothing}[
                    _terminal_vmax_to_ground(bus_fr, tmfr[j], grounded, b_fr)
                    for j in 1:n_map]
                bus_to = get(buses, b_to, Dict{String,Any}())
                vmax_to = Union{Float64,Nothing}[
                    _terminal_vmax_to_ground(bus_to, tmto[j], grounded, b_to)
                    for j in 1:n_map]
                for k in 1:min(n_map, length(i_max))
                    ilim = Float64(i_max[k])
                    cfr_r = @expression(model, cr_fr[(lid,k)] + ish_fr_r[k])
                    cfr_i = @expression(model, ci_fr[(lid,k)] + ish_fr_i[k])
                    _soc_norm!(model, cfr_r, cfr_i, ilim)
                    if has_any_shunt
                        cto_r = @expression(model, cr_to[(lid,k)] + ish_to_r[k])
                        cto_i = @expression(model, ci_to[(lid,k)] + ish_to_i[k])
                        _soc_norm!(model, cto_r, cto_i, ilim)
                    end

                    # Series-current variable boxes. The one series current
                    # appears at both ends: the from-total is cr_fr + ish_fr and
                    # the to-total is −cr_fr + ish_to, so a valid outer box on the
                    # bare series variable is |cr_fr| ≤ ilim + |ish_end| at each
                    # end. Applying both keeps the tighter (min). These hard
                    # variable bounds backstop the (soft) SOC cones: at a large
                    # per-unit base the cone values fall below Ipopt's constraint
                    # tolerance, so without a to-side box a from-side-only shunt
                    # would leave the to-end current effectively unconstrained
                    # (issue #299). With no to-side shunt the to-side box is a
                    # tight |cr_fr| ≤ ilim.
                    ish_fr_bound = _line_shunt_row_bound(G_fr, B_fr, vmax_fr, k, n_map)
                    ish_fr_bound !== nothing &&
                        _limit_current_box!(cr_fr[(lid,k)], ci_fr[(lid,k)], ilim + ish_fr_bound)
                    ish_to_bound = _line_shunt_row_bound(G_to, B_to, vmax_to, k, n_map)
                    ish_to_bound !== nothing &&
                        _limit_current_box!(cr_fr[(lid,k)], ci_fr[(lid,k)], ilim + ish_to_bound)
                end
            end
        end

        # ── Apparent-power limit on total current at each end (optional) ───────
        # Ground-referenced per conductor: S_k = V_k ∘ conj(I_tot,k) with V_k the
        # node-to-ground voltage. Same element→linecode precedence as i_max. Both
        # limits may coexist; enforcing both is generally redundant (see
        # W.RED.DUAL_THERMAL_LIMIT) and the neutral entry is degenerate (V_n ≈ 0,
        # see W.DOM.POWER_LIMIT_NEUTRAL).
        s_max = get(line, "s_max", nothing)
        s_max === nothing && lc !== nothing && (s_max = get(lc, "s_max", nothing))
        if s_max !== nothing
            for k in 1:min(n_map, length(s_max))
                slim = Float64(s_max[k])
                cfr_r = @expression(model, cr_fr[(lid,k)] + ish_fr_r[k])
                cfr_i = @expression(model, ci_fr[(lid,k)] + ish_fr_i[k])
                _apparent_power_limit!(model,
                    vr[(b_fr, tmfr[k])], vi[(b_fr, tmfr[k])], cfr_r, cfr_i, slim;
                    base_name = "$(lid)_fr_$(k)")
                if has_any_shunt
                    cto_r = @expression(model, cr_to[(lid,k)] + ish_to_r[k])
                    cto_i = @expression(model, ci_to[(lid,k)] + ish_to_i[k])
                    _apparent_power_limit!(model,
                        vr[(b_to, tmto[k])], vi[(b_to, tmto[k])], cto_r, cto_i, slim;
                        base_name = "$(lid)_to_$(k)")
                end
            end
        end
    end
end

"""
    _add_line_angle_constraints!(model, net, vars)

Enforce per-line angle-difference bounds (`va_diff_min`, `va_diff_max`, radians) between
the from- and to-end voltages on each conductor. Shared by OPF and feasibility OPF.

For each conductor k:
  s = vr_fr·vi_to − vi_fr·vr_to   (imaginary part of V_fr · conj(V_to))
  c = vr_fr·vr_to + vi_fr·vi_to   (real part)
  tan(va_diff_min)·c ≤ s ≤ tan(va_diff_max)·c
"""
function _add_line_angle_constraints!(model, net, vars)
    vr = vars[:vr]; vi = vars[:vi]

    for (lid, line) in get(net, "line", Dict())
        va_diff_min = get(line, "va_diff_min", nothing)
        va_diff_max = get(line, "va_diff_max", nothing)
        (va_diff_min === nothing && va_diff_max === nothing) && continue

        tan_min = va_diff_min !== nothing ? tan(Float64(va_diff_min)) : nothing
        tan_max = va_diff_max !== nothing ? tan(Float64(va_diff_max)) : nothing

        b_fr  = line["bus_from"]
        b_to  = line["bus_to"]
        tmfr  = Vector{String}(get(line, "terminal_map_from", String[]))
        tmto  = Vector{String}(get(line, "terminal_map_to",   String[]))
        n_c   = min(length(tmfr), length(tmto))

        for k in 1:n_c
            t_fr = tmfr[k]; t_to = tmto[k]
            haskey(vr, (b_fr, t_fr)) || continue
            haskey(vr, (b_to, t_to)) || continue
            s = @expression(model, vr[(b_fr,t_fr)]*vi[(b_to,t_to)] - vi[(b_fr,t_fr)]*vr[(b_to,t_to)])
            c = @expression(model, vr[(b_fr,t_fr)]*vr[(b_to,t_to)] + vi[(b_fr,t_fr)]*vi[(b_to,t_to)])
            tan_min !== nothing && @constraint(model, tan_min * c <= s)
            tan_max !== nothing && @constraint(model, s <= tan_max * c)
        end
    end
end

"""
    _add_switch_constraints!(model, net, vars, kcl_r, kcl_i)

Add constraints for all switches and register switch currents in the KCL
accumulators.

A *closed* switch short-circuits its two terminals (zero-impedance coupling):
  `vr[from,k] == vr[to,k]`,  `vi[from,k] == vi[to,k]`

An *open* switch has its current fixed to zero by `_add_switch_variables!`; no
voltage coupling is imposed (terminals are electrically disconnected).

If the switch carries an `i_max` vector (A, one entry per conductor), a thermal
current limit is enforced on the from-side current. No to-side constraint is
needed because switches have no shunt (from and to magnitudes are equal).
"""
function _add_switch_constraints!(model, net, vars, kcl_r, kcl_i)
    vr = vars[:vr]; vi = vars[:vi]
    cr_sw = vars[:cr_sw]; ci_sw = vars[:ci_sw]

    for (sid, sw) in get(net, "switch", Dict())
        b_fr  = sw["bus_from"]
        b_to  = sw["bus_to"]
        tmfr  = Vector{String}(get(sw, "terminal_map_from", String[]))
        tmto  = Vector{String}(get(sw, "terminal_map_to",   String[]))
        is_open = get(sw, "open_switch", false)
        i_max   = get(sw, "i_max", nothing)
        s_max   = get(sw, "s_max", nothing)
        n_c = min(length(tmfr), length(tmto))

        for k in 1:n_c
            if !is_open
                @constraint(model, vr[(b_fr, tmfr[k])] == vr[(b_to, tmto[k])])
                @constraint(model, vi[(b_fr, tmfr[k])] == vi[(b_to, tmto[k])])
            end
            _kcl_add!(kcl_r, kcl_i, b_fr, tmfr[k], -cr_sw[(sid,k)], -ci_sw[(sid,k)])
            _kcl_add!(kcl_r, kcl_i, b_to, tmto[k],  cr_sw[(sid,k)],  ci_sw[(sid,k)])
            if i_max !== nothing && k <= length(i_max)
                ilim = Float64(i_max[k])
                _soc_norm!(model, cr_sw[(sid,k)], ci_sw[(sid,k)], ilim)
                _limit_current_box!(cr_sw[(sid,k)], ci_sw[(sid,k)], ilim)
            end
            # Apparent-power limit (ground-referenced per conductor). A switch has
            # no shunt, so from and to magnitudes are equal — one cone suffices.
            if s_max !== nothing && k <= length(s_max)
                _apparent_power_limit!(model,
                    vr[(b_fr, tmfr[k])], vi[(b_fr, tmfr[k])],
                    cr_sw[(sid,k)], ci_sw[(sid,k)], Float64(s_max[k]);
                    base_name = "$(sid)_$(k)")
            end
        end
    end
end
