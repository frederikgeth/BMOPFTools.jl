# Bus voltage bounds and KCL.
#
# KCL sign convention: positive current = flowing INTO the bus.
# Each component function receives the KCL expression dicts and adds its
# contribution. At the end, _add_kcl_constraints! enforces sum == 0 at
# every ungrounded terminal.

# Validate that a per-phase (vpn) or per-pair (vpp) voltage bound is an array of
# the expected length. These bounds are strictly per-phase arrays — a scalar is
# rejected with a clear message.
function _check_per_phase_bound(val, n::Int, bid::AbstractString, field::AbstractString)
    val === nothing && return
    (val isa AbstractVector && length(val) == n) && return
    error("Bus '$bid': $field must be a per-phase array of length $n, got " *
          (val isa AbstractVector ? "length $(length(val))" : "a scalar"))
end

"""
    _init_kcl(bus_terminals, grounded) -> (kcl_r, kcl_i)

Allocate zero JuMP AffExpr accumulators for every (bus, terminal), **including**
perfectly grounded terminals. A grounded terminal keeps its KCL equation; its
ground-injection current (`cr_gnd`/`ci_gnd`) is the free term that balances it.
This is what lets current actually flow into earth at a grounded terminal — the
return path for an earth-return circuit or a shunt-grounded neutral.
"""
function _init_kcl(bus_terminals, _grounded=nothing)
    kcl_r = Dict{Tuple{String,String}, JuMP.AffExpr}()
    kcl_i = Dict{Tuple{String,String}, JuMP.AffExpr}()
    for (bid, terminals) in bus_terminals
        for t in terminals
            kcl_r[(bid, t)] = JuMP.AffExpr(0.0)
            kcl_i[(bid, t)] = JuMP.AffExpr(0.0)
        end
    end
    kcl_r, kcl_i
end

"""
    _add_voltage_bounds!(model, net, bus_terminals, grounded, vars)

Add |v|² ∈ [v_min², v_max²] at every ungrounded phase terminal that has bounds.
Grounded terminals (fixed at 0) and source-fixed terminals are skipped, as are
neutral terminals (their voltage is determined by physics, not operational limits).
"""
function _add_voltage_bounds!(model, net, bus_terminals, grounded, vars)
    vr = vars[:vr]; vi = vars[:vi]
    fixed = _source_fixed_terminals(net)

    for (bid, bus) in get(net, "bus", Dict())
        v_min = get(bus, "v_min", nothing)
        v_max = get(bus, "v_max", nothing)
        (v_min === nothing && v_max === nothing) && continue

        terminals = get(bus_terminals, bid, String[])
        neutral   = BMOPFTools._neutral_terminal(terminals)
        # Phase terminals in declaration order (neutral excluded). v_min/v_max are
        # per-phase arrays indexed by this order, so the phase index k is kept
        # aligned to the array even when a phase is grounded/source-fixed (those
        # are skipped at apply-time but do not shift k).
        phase_terms = [t for t in terminals if t != neutral]
        _check_per_phase_bound(v_min, length(phase_terms), bid, "v_min")
        _check_per_phase_bound(v_max, length(phase_terms), bid, "v_max")

        for (k, t) in enumerate(phase_terms)
            (bid, t) in grounded && continue   # vr=vi=0 already fixed
            (bid, t) in fixed   && continue   # source-fixed, skip
            vr_t = vr[(bid, t)]; vi_t = vi[(bid, t)]
            v2 = @expression(model, vr_t^2 + vi_t^2)
            lb = v_min isa AbstractVector ? get(v_min, k, nothing) : v_min
            ub = v_max isa AbstractVector ? get(v_max, k, nothing) : v_max
            lb !== nothing && @constraint(model, v2 >= Float64(lb)^2)
            ub !== nothing && @constraint(model, v2 <= Float64(ub)^2)
        end
    end
end

"""
    _add_bus_limit_constraints!(model, net, bus_terminals, grounded, vars)

Enforce operational bus-level voltage limits (not called from feasibility OPF):

- Neutral voltage upper bound (`vn_max`, V): |v_n|² ≤ vn_max² when neutral is ungrounded.
- Phase-to-neutral voltage magnitude bounds (`vpn_min`, `vpn_max`): applied to each
  ungrounded, non-source phase terminal when a neutral exists.
- Phase-to-phase voltage magnitude bounds (`vpp_min`, `vpp_max`): applied to all
  unordered pairs of ungrounded phase terminals.
- Intra-bus angle-difference bounds (`va_diff_min`, `va_diff_max`, radians): bilinear
  constraints enforcing the angle between every pair of phase terminals.
"""
function _add_bus_limit_constraints!(model, net, bus_terminals, grounded, vars)
    vr    = vars[:vr]; vi = vars[:vi]
    fixed = _source_fixed_terminals(net)

    for (bid, bus) in get(net, "bus", Dict())
        terminals = get(bus_terminals, bid, String[])
        neutral   = BMOPFTools._neutral_terminal(bus)

        # All phase terminals in declaration order (neutral excluded). The
        # per-phase (vpn) and per-pair (vpp/angle) bound arrays are indexed by
        # this *full* order to match the producer (src/augmentation/voltage_bounds.jl)
        # and the post-solve validator. A grounded or source-fixed phase is
        # skipped at apply-time but does NOT shift the index — collapsing onto the
        # filtered list would misalign every entry after the first such phase.
        phase_all  = [t for t in terminals if t != neutral]
        n_phase    = length(phase_all)
        applicable(t) = !((bid, t) in grounded) && !((bid, t) in fixed)

        # ── a. Neutral voltage upper bound ──────────────────────────────────
        vn_max = get(bus, "vn_max", nothing)
        if vn_max !== nothing && neutral !== nothing && !((bid, neutral) in grounded)
            vr_n = vr[(bid, neutral)]; vi_n = vi[(bid, neutral)]
            @constraint(model, vr_n^2 + vi_n^2 <= Float64(vn_max)^2)
        end

        # ── b. Phase-to-neutral voltage magnitude bounds ─────────────────────
        # vpn_min/vpn_max are per-phase arrays, one element per phase terminal in
        # full terminal_names phase order.
        vpn_min = get(bus, "vpn_min", nothing)
        vpn_max = get(bus, "vpn_max", nothing)
        if neutral !== nothing && (vpn_min !== nothing || vpn_max !== nothing)
            _check_per_phase_bound(vpn_min, n_phase, bid, "vpn_min")
            _check_per_phase_bound(vpn_max, n_phase, bid, "vpn_max")
            neutral_grounded = (bid, neutral) in grounded
            for (k, t) in enumerate(phase_all)
                applicable(t) || continue
                vr_t = vr[(bid, t)]; vi_t = vi[(bid, t)]
                if neutral_grounded
                    v2 = @expression(model, vr_t^2 + vi_t^2)
                else
                    dvr = @expression(model, vr_t - vr[(bid, neutral)])
                    dvi = @expression(model, vi_t - vi[(bid, neutral)])
                    v2  = @expression(model, dvr^2 + dvi^2)
                end
                vpn_min !== nothing && @constraint(model, v2 >= Float64(vpn_min[k])^2)
                vpn_max !== nothing && @constraint(model, v2 <= Float64(vpn_max[k])^2)
            end
        end

        # ── c. Phase-to-phase voltage magnitude bounds ────────────────────────
        # vpp_min/vpp_max are per-pair arrays, one element per unordered phase
        # pair in (i<j) order over the *full* phase list. A pair touching a
        # grounded/fixed terminal is skipped but still consumes its pair index.
        vpp_min = get(bus, "vpp_min", nothing)
        vpp_max = get(bus, "vpp_max", nothing)
        if (vpp_min !== nothing || vpp_max !== nothing) && n_phase >= 2
            n_pairs = n_phase * (n_phase - 1) ÷ 2
            _check_per_phase_bound(vpp_min, n_pairs, bid, "vpp_min")
            _check_per_phase_bound(vpp_max, n_pairs, bid, "vpp_max")
            pair_idx = 0
            for ki in 1:n_phase-1
                for kj in ki+1:n_phase
                    pair_idx += 1
                    tk = phase_all[ki]; tj = phase_all[kj]
                    (applicable(tk) && applicable(tj)) || continue
                    dvr = @expression(model, vr[(bid,tk)] - vr[(bid,tj)])
                    dvi = @expression(model, vi[(bid,tk)] - vi[(bid,tj)])
                    v2  = @expression(model, dvr^2 + dvi^2)
                    vpp_min !== nothing && @constraint(model, v2 >= Float64(vpp_min[pair_idx])^2)
                    vpp_max !== nothing && @constraint(model, v2 <= Float64(vpp_max[pair_idx])^2)
                end
            end
        end

        # ── d. Intra-bus angle difference ─────────────────────────────────────
        # va_diff_* are scalars bounding the angle difference of every applicable
        # phase pair, CENTERED on a nominal offset Δ = va_nom[j] − va_nom[k].
        # va_nom is an optional per-phase nominal-angle vector (radians) indexed
        # by the full phase_all order (like vpn/vpp); absent/short ⇒ offset 0,
        # which reduces exactly to the raw θ_j − θ_k bound (back-compatible).
        #
        # With z = conj(V_k)·V_j = c₀ + i·s₀, rotating by e^{−iΔ} gives
        #   c = c₀·cosΔ + s₀·sinΔ,   s = s₀·cosΔ − c₀·sinΔ,   s/c = tan(θ_j−θ_k−Δ).
        # The bilinear constraint tan(min)·c ≤ s ≤ tan(max)·c is faithful only
        # while c > 0, i.e. the centered deviation stays within (−π/2, π/2); the
        # nominal centering is what keeps it there for balanced multiphase buses.
        va_diff_min = get(bus, "va_diff_min", nothing)
        va_diff_max = get(bus, "va_diff_max", nothing)
        if (va_diff_min !== nothing || va_diff_max !== nothing) && n_phase >= 2
            va_nom = get(bus, "va_nom", nothing)
            nom(idx) = (va_nom isa AbstractVector && idx <= length(va_nom)) ?
                       Float64(va_nom[idx]) : 0.0
            tan_min = va_diff_min !== nothing ? tan(Float64(va_diff_min)) : nothing
            tan_max = va_diff_max !== nothing ? tan(Float64(va_diff_max)) : nothing
            for ki in 1:n_phase-1
                for kj in ki+1:n_phase
                    tk = phase_all[ki]; tj = phase_all[kj]
                    (applicable(tk) && applicable(tj)) || continue
                    Δ = nom(kj) - nom(ki)
                    cosΔ = cos(Δ); sinΔ = sin(Δ)
                    s0 = @expression(model, vr[(bid,tk)]*vi[(bid,tj)] - vi[(bid,tk)]*vr[(bid,tj)])
                    c0 = @expression(model, vr[(bid,tk)]*vr[(bid,tj)] + vi[(bid,tk)]*vi[(bid,tj)])
                    s = @expression(model, s0*cosΔ - c0*sinΔ)
                    c = @expression(model, c0*cosΔ + s0*sinΔ)
                    tan_min !== nothing && @constraint(model, tan_min * c <= s)
                    tan_max !== nothing && @constraint(model, s <= tan_max * c)
                end
            end
        end

        # ── e. Symmetrical-component voltage bounds (3-phase buses only) ────────
        # Fortescue transformation is linear in rectangular voltages; squared-magnitude
        # bounds are quadratic and compatible with Ipopt.
        # Phase-to-neutral voltages are used as inputs when a floating neutral exists;
        # phase-to-ground voltages are used otherwise (grounded or absent neutral).
        #
        # α = exp(j2π/3): Re(α)=-0.5, Im(α)=√3/2
        # V₁ = (Va + α·Vb + α²·Vc)/3   positive sequence
        # V₂ = (Va + α²·Vb + α·Vc)/3   negative sequence
        # V₀ = (Va + Vb + Vc)/3         zero sequence
        vpos_min  = get(bus, "vpos_min",  nothing)
        vpos_max  = get(bus, "vpos_max",  nothing)
        vneg_max  = get(bus, "vneg_max",  nothing)
        vzero_max = get(bus, "vzero_max", nothing)
        # Sequence components require the full set of three phase terminals
        # (the symmetrical-component transform is defined over all three phases),
        # so use phase_all — not a grounded/fixed-filtered subset.
        if n_phase == 3 &&
                (vpos_min !== nothing || vpos_max !== nothing ||
                 vneg_max !== nothing || vzero_max !== nothing)
            s3 = sqrt(3.0) / 2.0
            neutral_floating = neutral !== nothing && !((bid, neutral) in grounded)

            # Δv helper: phase-to-neutral if neutral floats, else phase-to-ground
            function _dv(t)
                if neutral_floating
                    return (@expression(model, vr[(bid,t)] - vr[(bid,neutral)]),
                            @expression(model, vi[(bid,t)] - vi[(bid,neutral)]))
                else
                    return (vr[(bid,t)], vi[(bid,t)])
                end
            end

            (dvr1, dvi1) = _dv(phase_all[1])
            (dvr2, dvi2) = _dv(phase_all[2])
            (dvr3, dvi3) = _dv(phase_all[3])

            if vpos_min !== nothing || vpos_max !== nothing
                V1_r = @expression(model,
                    (dvr1 - 0.5*dvr2 - s3*dvi2 - 0.5*dvr3 + s3*dvi3) / 3)
                V1_i = @expression(model,
                    (dvi1 + s3*dvr2 - 0.5*dvi2 - s3*dvr3 - 0.5*dvi3) / 3)
                v1_sq = @expression(model, V1_r^2 + V1_i^2)
                vpos_min !== nothing && @constraint(model, v1_sq >= Float64(vpos_min)^2)
                vpos_max !== nothing && @constraint(model, v1_sq <= Float64(vpos_max)^2)
            end

            if vneg_max !== nothing
                V2_r = @expression(model,
                    (dvr1 - 0.5*dvr2 + s3*dvi2 - 0.5*dvr3 - s3*dvi3) / 3)
                V2_i = @expression(model,
                    (dvi1 - s3*dvr2 - 0.5*dvi2 + s3*dvr3 - 0.5*dvi3) / 3)
                @constraint(model, V2_r^2 + V2_i^2 <= Float64(vneg_max)^2)
            end

            if vzero_max !== nothing
                V0_r = @expression(model, (dvr1 + dvr2 + dvr3) / 3)
                V0_i = @expression(model, (dvi1 + dvi2 + dvi3) / 3)
                @constraint(model, V0_r^2 + V0_i^2 <= Float64(vzero_max)^2)
            end
        end
    end
end

"""
    _add_kcl_constraints!(model, kcl_r, kcl_i)

Enforce KCL: for every (bus, terminal) accumulator, add == 0 constraints.
"""
function _add_kcl_constraints!(model, kcl_r, kcl_i)
    for key in keys(kcl_r)
        @constraint(model, kcl_r[key] == 0)
        @constraint(model, kcl_i[key] == 0)
    end
end

# ---------------------------------------------------------------------------
# KCL contribution helpers — called by branch/load/generator/source/transformer
# ---------------------------------------------------------------------------

"""
    _kcl_add!(kcl_r, kcl_i, bus, terminal, cr_expr, ci_expr;
              ledger=nothing, entry=nothing)

Add (cr_expr, ci_expr) to the KCL accumulator at (bus, terminal).
Silently skips grounded terminals (not present in the dict).

When `ledger`/`entry` are supplied (two-port elements), the injection is *also*
recorded in the per-device ledger via `_ledger_add!`, so the element's complex
loss can be computed exactly from terminal powers. The ledger record happens
regardless of whether the terminal is grounded — a grounded terminal still
carries the element's current (into earth), and its zero voltage simply makes
that terminal's `V·conj(I)` contribution zero in the loss sum.
"""
function _kcl_add!(kcl_r, kcl_i, bus, terminal, cr_expr, ci_expr;
                   ledger=nothing, entry=nothing)
    _ledger_add!(ledger, entry, bus, terminal, cr_expr, ci_expr)
    key = (bus, terminal)
    haskey(kcl_r, key) || return
    JuMP.add_to_expression!(kcl_r[key], cr_expr)
    JuMP.add_to_expression!(kcl_i[key], ci_expr)
end
