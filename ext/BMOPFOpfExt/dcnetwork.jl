# DC-network constraints for the IVR-EN OPF.
#
# Models an MVDC/LVDC network that AC/DC converters (IBR objects carrying a
# `dc_bus` reference) share. DC quantities have NO angle: each DC terminal holds a
# single real, SIGNED voltage `v_dc` measured to earth (positive pole > 0, negative
# pole < 0, metallic return ~ 0). DC KCL is enforced per dc_bus terminal in exactly
# the AC pattern: ungrounded terminals get ΣI = 0; perfectly grounded terminals
# keep the equation and a free earth current balances it (earth-return path).
#
# Converters are LOSSLESS here: a converter's DC-port power equals its AC active
# power. A converter station / back-to-back SOP / MVDC tie emerges automatically
# from several converters sharing one dc_bus and balancing through DC KCL.

# ── Return-conductor recognition (DC analog of `_neutral_terminal`) ──────────
# The DC return / neutral is the terminal whose pole role is METALLIC_RETURN;
# fallback to a terminal named "m" (metallic return) or "n".
function _dc_return_terminal(dcbus::Dict)
    pole = get(dcbus, "pole", nothing)
    if pole isa Dict
        for (t, role) in pole
            String(role) == "METALLIC_RETURN" && return String(t)
        end
    end
    for t in string.(get(dcbus, "terminal_names", String[]))
        lowercase(t) in ("m", "n") && return t
    end
    nothing
end

# Terminals with a given pole role, in terminal_names order.
function _dc_terminals_with_role(dcbus::Dict, role::AbstractString)
    pole = get(dcbus, "pole", nothing)
    pole isa Dict || return String[]
    [t for t in string.(get(dcbus, "terminal_names", String[]))
       if String(get(pole, t, "")) == role]
end

# Set of perfectly-grounded (dc_bus, terminal): declared on the dc_bus, or a
# dc_grounding with no/zero resistance.
function _dc_grounded_terminals(net::Dict{String,Any})
    g = Set{Tuple{String,String}}()
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        for t in string.(get(dcbus, "perfectly_grounded_terminals", String[]))
            push!(g, (b, t))
        end
    end
    for (_, gr) in get(net, "dc_grounding", Dict())
        gr isa Dict || continue
        b = get(gr, "dc_bus", nothing); t = get(gr, "terminal", nothing)
        (b isa AbstractString && t isa AbstractString) || continue
        r = get(gr, "r", nothing)
        (r === nothing || Float64(r) <= 0) && push!(g, (String(b), String(t)))
    end
    g
end

"""
    _add_dc_variables!(model, net) -> Dict

Declare all DC-side JuMP variables. Returns a dict merged into the main `vars`:
- `:v_dc`      `(dc_bus, terminal) → VariableRef` signed line-to-ground voltage
  (grounded terminals fixed to 0)
- `:idc_gnd`   `(dc_bus, terminal) → VariableRef` free earth current at perfect grounds
- `:idc_br`    `(branch, k) → VariableRef` per-conductor DC branch current (from→to)
- `:idc_conv`  `ibr → VariableRef` converter DC-port current (into converter at pole)
- `:idc_load`  `dc_load → VariableRef`, `:idc_src` `dc_source → VariableRef`
- `:pdc_src`   `dc_source → VariableRef` dispatched source power (bounded)
"""
function _add_dc_variables!(model, net)
    dc_grounded = _dc_grounded_terminals(net)

    v_dc    = Dict{Tuple{String,String}, JuMP.VariableRef}()
    idc_gnd = Dict{Tuple{String,String}, JuMP.VariableRef}()
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        terms = string.(get(dcbus, "terminal_names", String[]))
        vmin  = Float64.(get(dcbus, "v_dc_min", Float64[]))
        vmax  = Float64.(get(dcbus, "v_dc_max", Float64[]))
        for (k, t) in enumerate(terms)
            key = (b, t)
            v = @variable(model, base_name = "vdc_$(b)_$(t)")
            v_dc[key] = v
            if key in dc_grounded
                fix(v, 0.0; force=true)
                idc_gnd[key] = @variable(model, base_name = "idcgnd_$(b)_$(t)")
            elseif k <= length(vmin) && k <= length(vmax) && vmin[k] == vmax[k]
                # Degenerate band (e.g. a metallic return pinned to 0): fix it so
                # the model has no redundant lb==ub pair and ideal-conductor
                # equalities to it are skipped.
                fix(v, vmin[k]; force=true)
            else
                k <= length(vmin) && set_lower_bound(v, vmin[k])
                k <= length(vmax) && set_upper_bound(v, vmax[k])
            end
        end
    end

    idc_br = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    for (id, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        n = length(get(br, "terminal_map_from", String[]))
        for k in 1:n
            idc_br[(id, k)] = @variable(model, base_name = "idcbr_$(id)_$(k)")
        end
    end

    idc_conv = Dict{String, JuMP.VariableRef}()
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict && haskey(inv, "dc_bus") || continue
        idc_conv[id] = @variable(model, base_name = "idcconv_$(id)")
    end

    idc_load = Dict{String, JuMP.VariableRef}()
    for (id, _) in get(net, "dc_load", Dict())
        idc_load[id] = @variable(model, base_name = "idcload_$(id)")
    end
    idc_src = Dict{String, JuMP.VariableRef}()
    pdc_src = Dict{String, JuMP.VariableRef}()
    for (id, s) in get(net, "dc_source", Dict())
        s isa Dict || continue
        idc_src[id] = @variable(model, base_name = "idcsrc_$(id)")
        p = @variable(model, base_name = "pdcsrc_$(id)")
        haskey(s, "p_min") && set_lower_bound(p, Float64(s["p_min"]))
        haskey(s, "p_max") && set_upper_bound(p, Float64(s["p_max"]))
        if !haskey(s, "p_min") && !haskey(s, "p_max") && haskey(s, "p")
            fix(p, Float64(s["p"]); force=true)
        end
        pdc_src[id] = p
    end

    Dict{Symbol,Any}(:v_dc => v_dc, :idc_gnd => idc_gnd, :idc_br => idc_br,
                     :idc_conv => idc_conv, :idc_load => idc_load,
                     :idc_src => idc_src, :pdc_src => pdc_src)
end

# Initialise per-(dc_bus, terminal) DC KCL accumulators (every terminal, including
# grounded), mirroring `_init_kcl`.
function _init_dc_kcl(net)
    kcl = Dict{Tuple{String,String}, JuMP.AffExpr}()
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        for t in string.(get(dcbus, "terminal_names", String[]))
            kcl[(b, t)] = JuMP.AffExpr(0.0)
        end
    end
    kcl
end

_dc_kcl_add!(kcl, b, t, expr) =
    (haskey(kcl, (b, t)) && JuMP.add_to_expression!(kcl[(b, t)], expr); nothing)

"""
    _add_dc_network_constraints!(model, net, vars)

Stamp DC branches, groundings, loads, and sources into the DC KCL accumulator,
and apply line-to-neutral / line-to-line voltage bounds. The converter DC-port
coupling is added separately by the IBR builder (it needs each converter's AC
active power). Stores the accumulator in `vars[:kcl_dc]` for later enforcement.
"""
function _add_dc_network_constraints!(model, net, vars)
    haskey(net, "dc_bus") || return
    v_dc = vars[:v_dc]
    kcl  = _init_dc_kcl(net)
    vars[:kcl_dc] = kcl

    # ── Perfect-ground free earth currents ──────────────────────────────────
    for (key, ig) in vars[:idc_gnd]
        _dc_kcl_add!(kcl, key[1], key[2], ig)
    end

    # ── Resistive grounding: I_earth = v_dc / r leaves the node ─────────────
    for (_, gr) in get(net, "dc_grounding", Dict())
        gr isa Dict || continue
        b = get(gr, "dc_bus", nothing); t = get(gr, "terminal", nothing)
        r = get(gr, "r", nothing)
        (b isa AbstractString && t isa AbstractString && r !== nothing &&
         Float64(r) > 0 && haskey(v_dc, (b, t))) || continue
        _dc_kcl_add!(kcl, b, t, -v_dc[(b, t)] / Float64(r))
    end

    # ── DC branches: Ohm's law per conductor + thermal limits ───────────────
    idc_br = vars[:idc_br]
    for (id, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        bf = String(get(br, "dc_bus_from", "")); bt = String(get(br, "dc_bus_to", ""))
        tmf = string.(get(br, "terminal_map_from", String[]))
        tmt = string.(get(br, "terminal_map_to",   String[]))
        rv  = Float64.(get(br, "r", Float64[]))
        imax = Float64.(get(br, "i_max", Float64[]))
        n = min(length(tmf), length(tmt))
        for k in 1:n
            i = idc_br[(id, k)]
            kf = (bf, tmf[k]); kt = (bt, tmt[k])
            (haskey(v_dc, kf) && haskey(v_dc, kt)) || continue
            if k <= length(rv) && rv[k] > 0
                @constraint(model, i == (v_dc[kf] - v_dc[kt]) / rv[k])
            elseif !(JuMP.is_fixed(v_dc[kf]) && JuMP.is_fixed(v_dc[kt]))
                @constraint(model, v_dc[kf] == v_dc[kt])   # ideal conductor
            end
            # (both ends already fixed → equality is redundant; current stays free)
            # current flows from→to: leaves "from" (−i into node), enters "to" (+i)
            _dc_kcl_add!(kcl, bf, tmf[k], -i)
            _dc_kcl_add!(kcl, bt, tmt[k],  i)
            k <= length(imax) && @constraint(model, i^2 <= imax[k]^2)
        end
        pmax = get(br, "p_max", nothing)
        if pmax !== nothing && n >= 1 && haskey(v_dc, (bf, tmf[1]))
            # bound the pole-conductor power |v·i| ≤ p_max
            i1 = idc_br[(id, 1)]
            @constraint(model, (v_dc[(bf, tmf[1])] * i1)^2 <= Float64(pmax)^2)
        end
    end

    # ── DC loads: constant-power draw across the port ───────────────────────
    for (id, l) in get(net, "dc_load", Dict())
        l isa Dict || continue
        b = String(get(l, "dc_bus", "")); tm = string.(get(l, "terminal_map", String[]))
        p = get(l, "p", nothing); p isa Number || continue
        I = vars[:idc_load][id]
        _dc_port_power!(model, kcl, v_dc, b, tm, I, Float64(p); inject=false)
    end

    # ── DC sources: dispatched-power injection across the port ──────────────
    for (id, s) in get(net, "dc_source", Dict())
        s isa Dict || continue
        b = String(get(s, "dc_bus", "")); tm = string.(get(s, "terminal_map", String[]))
        I = vars[:idc_src][id]; p = vars[:pdc_src][id]
        _dc_port_power!(model, kcl, v_dc, b, tm, I, p; inject=true)
    end

    # ── Line-to-neutral / line-to-line magnitude bounds ─────────────────────
    _add_dc_voltage_pair_bounds!(model, net, v_dc)
end

# Couple a 1- or 2-terminal DC port carrying current `I` to power `p` (a constant
# or a variable) and stamp it into DC KCL. `inject=true` pushes power INTO the
# dc_bus (source/converter export); `false` draws it (load).
function _dc_port_power!(model, kcl, v_dc, b, tm, I, p; inject::Bool)
    if length(tm) >= 2
        ka = (b, tm[1]); kb = (b, tm[2])
        (haskey(v_dc, ka) && haskey(v_dc, kb)) || return
        @constraint(model, (v_dc[ka] - v_dc[kb]) * I == p)
        s = inject ? 1.0 : -1.0
        _dc_kcl_add!(kcl, b, tm[1],  s * I)
        _dc_kcl_add!(kcl, b, tm[2], -s * I)
    elseif length(tm) == 1
        ka = (b, tm[1]); haskey(v_dc, ka) || return
        @constraint(model, v_dc[ka] * I == p)          # earth return
        s = inject ? 1.0 : -1.0
        _dc_kcl_add!(kcl, b, tm[1], s * I)
    end
end

# Apply a magnitude band [lo, hi] to a voltage difference whose sign is known from
# the pole roles, so the constraints stay LINEAR: for an oriented difference Δ ≥ 0,
# lo ≤ Δ ≤ hi directly. `orient` is +1 if the difference is already non-negative
# (e.g. positive-pole − return), −1 if it is non-positive (negative-pole − return),
# in which case we bound −Δ.
function _bound_oriented_diff!(model, Δ, lo, hi, orient::Int)
    s = orient > 0 ? Δ : @expression(model, -Δ)
    hi !== nothing && @constraint(model, s <= Float64(hi))
    lo !== nothing && @constraint(model, s >= Float64(lo))
end

# Stamp line-to-neutral (pole−return) and line-to-line (positive−negative pole)
# magnitude bounds. Orientation comes from the `pole` role map (POSITIVE pole sits
# above the return, NEGATIVE pole below), so the bounds are LINEAR. A missing role
# is a hard error (validation flags it first as E.DOM.DC_POLE_ROLE_REQUIRED) — we
# never silently fall back to a nonconvex squared form.
function _add_dc_voltage_pair_bounds!(model, net, v_dc)
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        ret  = _dc_return_terminal(dcbus)
        pole = get(dcbus, "pole", Dict())
        role(t) = pole isa Dict ? String(get(pole, t, "")) : ""

        lnlo = get(dcbus, "vdc_ln_min", nothing); lnhi = get(dcbus, "vdc_ln_max", nothing)
        if (lnlo !== nothing || lnhi !== nothing) && ret !== nothing
            for t in string.(get(dcbus, "terminal_names", String[]))
                (t == ret || !haskey(v_dc, (b, t))) && continue
                orient = role(t) == "POSITIVE" ? 1 : role(t) == "NEGATIVE" ? -1 : 0
                orient == 0 && error("dc_bus '$b': terminal '$t' needs a POSITIVE/" *
                    "NEGATIVE pole role to orient its line-to-neutral bound.")
                Δ = @expression(model, v_dc[(b, t)] - v_dc[(b, ret)])
                _bound_oriented_diff!(model, Δ, lnlo, lnhi, orient)
            end
        end

        lllo = get(dcbus, "vdc_ll_min", nothing); llhi = get(dcbus, "vdc_ll_max", nothing)
        if lllo !== nothing || llhi !== nothing
            pos = _dc_terminals_with_role(dcbus, "POSITIVE")
            neg = _dc_terminals_with_role(dcbus, "NEGATIVE")
            (!isempty(pos) && !isempty(neg)) ||
                error("dc_bus '$b': line-to-line bound needs both a POSITIVE and a " *
                      "NEGATIVE pole role.")
            (haskey(v_dc, (b, pos[1])) && haskey(v_dc, (b, neg[1]))) || continue
            Δ = @expression(model, v_dc[(b, pos[1])] - v_dc[(b, neg[1])])
            _bound_oriented_diff!(model, Δ, lllo, llhi, 1)   # pos − neg ≥ 0
        end
    end
end

# DC-port-voltage expression U = v_dc[pole] − v_dc[return] (or v_dc[pole] for a
# 1-terminal earth-return port), and the (b, pole/return) keys, for a converter.
function _dc_port_voltage(model, vars, inv)
    v_dc = vars[:v_dc]
    b  = String(get(inv, "dc_bus", "")); tm = string.(get(inv, "dc_terminal_map", String[]))
    if length(tm) >= 2 && haskey(v_dc, (b, tm[1])) && haskey(v_dc, (b, tm[2]))
        return (@expression(model, v_dc[(b, tm[1])] - v_dc[(b, tm[2])]), b, tm)
    elseif length(tm) == 1 && haskey(v_dc, (b, tm[1]))
        return (v_dc[(b, tm[1])], b, tm)
    end
    return (nothing, b, tm)
end

# Default pole-to-return nominal DC voltage from the dc_bus `v_dc_nom`.
function _dc_v_nom_port(net, b, tm)
    dcb = get(get(net, "dc_bus", Dict()), b, nothing)
    dcb isa Dict || return nothing
    nom = Float64.(get(dcb, "v_dc_nom", Float64[]))
    terms = string.(get(dcb, "terminal_names", String[]))
    idx(t) = findfirst(==(t), terms)
    if length(tm) >= 2
        i, j = idx(tm[1]), idx(tm[2])
        (i !== nothing && j !== nothing && i <= length(nom) && j <= length(nom)) || return nothing
        return nom[i] - nom[j]
    elseif length(tm) == 1
        i = idx(tm[1])
        return (i !== nothing && i <= length(nom)) ? nom[i] : nothing
    end
    nothing
end

# Build the strictly-increasing breakpoint pairs (xs in DC volts, ys in AC watts)
# of a SATURATED V–P droop characteristic: P_ac rises with the DC-port voltage
# (high DC voltage ⇒ export more to AC ⇒ relieve the bus), is flat at p_ref inside
# an optional ±deadband around v_set, and clamps to the converter power limits
# [P_lo, P_hi] outside the droop band. Returns (xs, ys) or nothing when degenerate.
function _droop_breakpoints(v_set, k, p_ref, deadband, P_lo, P_hi)
    (k > 0 && P_hi > P_lo) || return nothing
    pr = clamp(p_ref, P_lo, P_hi)
    db = max(deadband, 0.0)
    U_lo = (v_set - db) - k * (pr - P_lo)    # P_ac reaches P_lo here
    U_hi = (v_set + db) + k * (P_hi - pr)    # P_ac reaches P_hi here
    xs = db > 0 ? [U_lo, v_set - db, v_set + db, U_hi] : [U_lo, v_set, U_hi]
    ys = db > 0 ? [P_lo, pr, pr, P_hi]               : [P_lo, pr, P_hi]
    # keep only strictly increasing x (drop degenerate coincident breakpoints)
    xk = Float64[xs[1]]; yk = Float64[ys[1]]
    for i in 2:length(xs)
        if xs[i] > xk[end] + 1e-9
            push!(xk, xs[i]); push!(yk, ys[i])
        end
    end
    length(xk) >= 2 ? (xk, yk) : nothing
end

"""
    _couple_converter_to_dc!(model, vars, inv_id, inv, p_ac_expr, smax; relu_eps, relu_ops)

Lossless converter DC-port coupling plus its DC-side control law.

Always: the power drawn from the DC bus equals the converter's AC active power
`p_ac_expr` (= Σ phase P) — the bilinear `(v_pole − v_ret)·I == p_ac` — and the
port current `I` is injected into the shared DC KCL.

Control mode (`dc_control`):
- `"P"` (default): no extra constraint — the OPF dispatches the converter power.
- `"V"`: DC-voltage master — pins `v_pole − v_ret == dc_v_set` (the AC power floats
  to balance the zone). `dc_v_set` defaults to the pole-to-return `v_dc_nom`.
- `"droop"`: saturated V–P droop — `p_ac == f(v_port)` where `f` is the smooth
  piecewise-linear curve from `_droop_breakpoints` (Volt-watt/Volt-var machinery),
  rising with DC voltage and clamped at the converter power limits ±Σ s_max.
"""
function _couple_converter_to_dc!(model, vars, inv_id, inv, p_ac_expr, smax,
                                  p_min, p_max;
                                  relu_eps::Float64=2e-3,
                                  relu_ops::Dict{Float64,Any}=Dict{Float64,Any}(),
                                  net=nothing)
    haskey(vars, :kcl_dc) || return
    kcl = vars[:kcl_dc]
    Uport, b, tm = _dc_port_voltage(model, vars, inv)
    Uport === nothing && return
    I = vars[:idc_conv][inv_id]

    # Lossless power balance + KCL injection (all modes).
    @constraint(model, Uport * I == p_ac_expr)
    _dc_kcl_add!(kcl, b, tm[1], -I)                 # current drawn from pole
    length(tm) >= 2 && _dc_kcl_add!(kcl, b, tm[2], I)   # returned at the return

    mode = String(get(inv, "dc_control", "P"))
    v_set = let s = get(inv, "dc_v_set", nothing)
        s isa Number ? Float64(s) : _dc_v_nom_port(net, b, tm)
    end

    if mode == "V"
        v_set === nothing &&
            error("IBR '$inv_id': dc_control=\"V\" needs dc_v_set (or dc_bus v_dc_nom).")
        @constraint(model, Uport == v_set)

    elseif mode == "droop"
        v_set === nothing &&
            error("IBR '$inv_id': dc_control=\"droop\" needs dc_v_set (or dc_bus v_dc_nom).")
        k = Float64(get(inv, "dc_droop", 0.0))
        k > 0 || error("IBR '$inv_id': dc_control=\"droop\" needs dc_droop > 0.")
        p_ref = Float64(get(inv, "dc_p_ref", 0.0))
        db    = Float64(get(inv, "dc_deadband", 0.0))
        # Saturate at the converter's ACTUAL net active-power capability so the droop
        # clamps exactly where the P box would bind (no droop-vs-box conflict): use
        # the per-phase p_max/p_min sums when given, else ±Σs_max.
        P_hi = isempty(p_max) ? (isempty(smax) ? 0.0 : sum(smax))  : sum(p_max)
        P_lo = isempty(p_min) ? (isempty(smax) ? 0.0 : -sum(smax)) : sum(p_min)
        bp = _droop_breakpoints(v_set, k, p_ref, db, P_lo, P_hi)
        if bp === nothing
            error("IBR '$inv_id': degenerate droop (need dc_droop>0 and a non-empty " *
                  "s_max for the saturation limits).")
        end
        xs, ys = bp
        base, triples = breakpoints_to_triples(xs, ys)
        ε  = max(relu_eps * (xs[end] - xs[1]), 1e-6)
        op = relu_operator_for!(relu_ops, model, ε)
        @constraint(model, p_ac_expr == curve_expr(op, Uport, base, triples))
    end
end

"""
    _set_dc_start_values!(vars, net)

Warm-start the signed DC node voltages at their nominal (`v_dc_nom`) or the
midpoint of `[v_dc_min, v_dc_max]`, so Ipopt starts the bilinear converter
power-balance `(v_p − v_m)·I = P` away from the degenerate `v = 0` point.
"""
function _set_dc_start_values!(vars, net)
    haskey(vars, :v_dc) || return
    v_dc = vars[:v_dc]
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        terms = string.(get(dcbus, "terminal_names", String[]))
        nom   = Float64.(get(dcbus, "v_dc_nom", Float64[]))
        vmin  = Float64.(get(dcbus, "v_dc_min", Float64[]))
        vmax  = Float64.(get(dcbus, "v_dc_max", Float64[]))
        for (k, t) in enumerate(terms)
            haskey(v_dc, (b, t)) || continue
            v = v_dc[(b, t)]
            JuMP.is_fixed(v) && continue
            start = k <= length(nom) ? nom[k] :
                    (k <= length(vmin) && k <= length(vmax)) ? (vmin[k] + vmax[k]) / 2 :
                    nothing
            start === nothing || JuMP.set_start_value(v, start)
        end
    end
end

"Enforce DC KCL == 0 at every dc_bus terminal."
function _add_dc_kcl_constraints!(model, vars)
    haskey(vars, :kcl_dc) || return
    for (_, expr) in vars[:kcl_dc]
        @constraint(model, expr == 0)
    end
end
