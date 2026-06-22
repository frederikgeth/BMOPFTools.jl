# validation/solution.jl
#
# Post-solve result profiler: given a BMOPF network dict and a result dict
# (from any solver), flag bound violations, near-active bounds, poor
# constraint residuals, and other solution-quality issues.
#
# Entry point: solution_check(net, result, findings) -> Dict{String,Any}
#
# Finding codes (SOL family):
#   E.SOL.INFEASIBLE         — solver did not find a feasible point
#   E.SOL.NAN_IN_RESULT      — non-finite value in a claimed-feasible result
#   E.SOL.VOLT_VIOLATION     — vm / vpn / vpp / vpos / vneg / vzero outside bounds
#   E.SOL.THERMAL_VIOLATION  — line or switch current exceeds i_max / s_max
#   E.SOL.GEN_VIOLATION      — generator pg/qg outside [p_min, p_max] / [q_min, q_max]
#   W.SOL.VOLT_ACTIVE        — voltage bound within the active threshold
#   W.SOL.THERMAL_ACTIVE     — thermal limit within the active threshold
#   W.SOL.GEN_ACTIVE         — generator bound within the active threshold
#   W.SOL.LOAD_RESIDUAL      — |pd - p_nom| or |qd - q_nom| above tolerance (constant-power only)
#   W.SOL.LOAD_MODEL_RESIDUAL — realised pd/qd inconsistent with load model at solved voltage
#   I.SOL.LOAD_VD_SUMMARY    — aggregate realised vs nominal P/Q for voltage-dependent loads
#   W.SOL.POWER_BALANCE      — network-wide active OR reactive power doesn't balance
#                              (uses exact element losses, result["losses"])
#   I.SOL.BINDING_SUMMARY    — aggregate count of active / violated bounds
#   I.SOL.LOSS_FRACTION      — line losses as fraction of total load
#   W.SOL.NEG_LOSS           — a line/transformer dissipates negative active power
#                              (non-physical for a passive branch; throughput-scaled)
#   I.SOL.NEUTRAL_SHIFT      — maximum neutral terminal voltage across non-source buses
#   W.SOL.INIT_LEVEL_MISMATCH — init voltage differs from solved by > 10× (wrong voltage level)
#   W.SOL.INIT_LARGE_ERROR   — init voltage error > 20 % of solved value on a phase terminal
#   I.SOL.INIT_NEUTRAL_NONZERO — neutral terminal initialised non-zero

# Predict model power for sub-load `idx` given solved squared-voltage W and Vnom.
# component is "p" (active) or "q" (reactive). Returns nothing if model unknown.
function _load_model_power(load, component::String, idx::Int,
                           p0::Float64, W::Float64, Vnom::Float64)
    model = get(load, "model", "constant_power")
    if model == "constant_impedance"
        return p0 * W / Vnom^2
    elseif model == "constant_current"
        return p0 * sqrt(W) / Vnom
    elseif model == "zip"
        zkey = component == "p" ? "alpha_z" : "beta_z"
        ikey = component == "p" ? "alpha_i" : "beta_i"
        pkey = component == "p" ? "alpha_p" : "beta_p"
        function coeff(key)
            c = get(load, key, nothing)
            c === nothing && return 0.0
            c isa AbstractVector ? Float64(length(c) == 1 ? c[1] : c[idx]) : Float64(c)
        end
        cz = coeff(zkey); ci = coeff(ikey); cp = coeff(pkey)
        # If all three absent, default to constant-power (sum = 1 via cp=1)
        if get(load, zkey, nothing) === nothing &&
           get(load, ikey, nothing) === nothing &&
           get(load, pkey, nothing) === nothing
            cp = 1.0
        end
        return p0 * (cz * W / Vnom^2 + ci * sqrt(W) / Vnom + cp)
    elseif model == "exponential"
        gkey = component == "p" ? "gamma_p" : "gamma_q"
        g = get(load, gkey, nothing)
        γ = if g === nothing
            0.0
        elseif g isa AbstractVector
            Float64(length(g) == 1 ? g[1] : g[idx])
        else
            Float64(g)
        end
        return p0 * (W / Vnom^2)^(γ / 2)
    end
    nothing
end

"""
    solution_check(net, result, findings) -> Dict{String,Any}

Profile an OPF result dict against the network that produced it.
Appends `Finding` objects to `findings` and returns a summary dict.

`net` must be a snapshot (non-time-series) BMOPF network dict.
`result` is the dict returned by `solve_opf` (or any compatible solver).
"""
function solution_check(net::Dict{String,Any},
                        result::Dict{String,Any},
                        findings::Vector{Finding})::Dict{String,Any}
    out = Dict{String,Any}()

    # ── Termination ──────────────────────────────────────────────────────────
    status = get(result, "termination_status", "UNKNOWN")
    feasible = status in ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
    out["termination_status"] = status
    out["feasible"] = feasible

    if !feasible
        push!(findings, Finding(ERROR, "E.SOL.INFEASIBLE", :solution, :network, nothing,
            "Solver terminated with status '$status' — all numeric results are " *
            "unreliable (NaN). No bound or residual checks are meaningful.",
            Dict{String,Any}("termination_status" => status)))
        out["n_volt_violations"]    = 0
        out["n_thermal_violations"] = 0
        out["n_gen_violations"]     = 0
        return out
    end

    # ── NaN / Inf detection ──────────────────────────────────────────────────
    nan_locs = String[]
    for (sec, sec_dict) in result
        sec_dict isa Dict || continue
        for (id, id_dict) in sec_dict
            id_dict isa Dict || continue
            for (t, t_dict) in id_dict
                t_dict isa Dict || continue
                for (f, v) in t_dict
                    v isa Number && !isfinite(v) &&
                        push!(nan_locs, "$sec[$id][$t].$f")
                end
            end
        end
    end
    if !isempty(nan_locs)
        push!(findings, Finding(ERROR, "E.SOL.NAN_IN_RESULT", :solution, :network, nothing,
            "$(length(nan_locs)) non-finite value(s) in a claimed-feasible result " *
            "(first: $(nan_locs[1])). This indicates numerical failure inside the solver.",
            Dict{String,Any}("locations" => nan_locs)))
    end
    out["n_nan_fields"] = length(nan_locs)

    # ── Helpers ───────────────────────────────────────────────────────────────
    # Threshold for "active" (near-binding): within this fraction of the bound value.
    active_frac = 0.01

    # Tolerance below which an excursion past a bound is treated as the optimizer
    # sitting *at* the bound (active), not violating it. A solved interior-point
    # optimum routinely lands a few parts in 10⁻⁶ outside an active bound, and the
    # per-unit ⇄ SI round-trip (solve scaled by s_base, then unscale) inflates that
    # relative slack to ≈2×10⁻⁶; without this the checker would flag every
    # saturated generator/inverter as a violation. 10⁻⁵ relative comfortably covers
    # solver convergence tolerance while still catching any genuine violation, which
    # is orders of magnitude larger. Small absolute floor for bounds near zero.
    viol_frac = 1e-5
    viol_tol(bound) = max(viol_frac * abs(bound), 1e-6)

    # Returns (violated, active) given value v, lower lb, upper ub (either may be nothing).
    # Uses an absolute fallback of 0.01 × |bound| for bounds near zero.
    function _bound_status(v::Float64, lb, ub)
        violated = false
        active   = false
        if lb !== nothing
            lb_f = Float64(lb)
            tol  = max(active_frac * abs(lb_f), 1e-6)
            v < lb_f - viol_tol(lb_f) && (violated = true)
            !violated && v < lb_f + tol && (active = true)
        end
        if ub !== nothing
            ub_f = Float64(ub)
            tol  = max(active_frac * abs(ub_f), 1e-6)
            v > ub_f + viol_tol(ub_f) && (violated = true)
            !violated && v > ub_f - tol && (active = true)
        end
        violated, active
    end

    buses   = get(net, "bus", Dict())
    bus_res = get(result, "bus", Dict())

    source_buses = Set(get(vs, "bus", "") for (_, vs) in get(net, "voltage_source", Dict())
                       if vs isa Dict)

    n_volt_viol   = 0
    n_volt_active = 0

    # ── Voltage magnitude bounds (v_min / v_max) ─────────────────────────────
    # Per-phase arrays (phase-to-ground), one entry per phase terminal in
    # terminal_names order; index k corresponds to the k-th phase terminal.
    for (bid, bus) in buses
        bus isa Dict || continue
        v_min = get(bus, "v_min", nothing)
        v_max = get(bus, "v_max", nothing)
        v_min === nothing && v_max === nothing && continue
        t_res = get(bus_res, bid, nothing)
        t_res isa Dict || continue
        nt = _neutral_terminal(bus)

        term_names = Vector{String}(get(bus, "terminal_names", String[]))
        phase_ts_ordered = [t for t in term_names if t != nt]

        for (k, t) in enumerate(phase_ts_ordered)
            haskey(t_res, t) || continue
            tvals = t_res[t]
            tvals isa Dict || continue
            vm = get(tvals, "vm", NaN)
            isfinite(vm) || continue
            lb = v_min isa AbstractVector ? get(v_min, k, nothing) : v_min
            ub = v_max isa AbstractVector ? get(v_max, k, nothing) : v_max
            viol, act = _bound_status(vm, lb, ub)
            if viol
                n_volt_viol += 1
                push!(findings, Finding(ERROR, "E.SOL.VOLT_VIOLATION", :solution, :bus, bid,
                    "Bus '$bid' terminal '$t': vm=$(_fmt_v(vm)) violates " *
                    "[$(lb === nothing ? "−∞" : _fmt_v(Float64(lb))), " *
                    "$(ub === nothing ? "+∞" : _fmt_v(Float64(ub)))].",
                    Dict{String,Any}("bus"=>bid,"terminal"=>t,"vm"=>vm,
                                     "v_min"=>lb,"v_max"=>ub,"flavour"=>"vm")))
            elseif act
                n_volt_active += 1
                push!(findings, Finding(WARNING, "W.SOL.VOLT_ACTIVE", :solution, :bus, bid,
                    "Bus '$bid' terminal '$t': vm=$(_fmt_v(vm)) is within 1 % of a " *
                    "voltage bound (active constraint).",
                    Dict{String,Any}("bus"=>bid,"terminal"=>t,"vm"=>vm,
                                     "v_min"=>lb,"v_max"=>ub,"flavour"=>"vm")))
            end
        end
    end

    # ── Phase-to-neutral voltage bounds (vpn_min / vpn_max) ──────────────────
    # vpn_min/vpn_max are per-phase arrays ordered by terminal_names phase order.
    # Index k in the bound array corresponds to the k-th phase terminal.
    for (bid, bus) in buses
        bus isa Dict || continue
        vpn_min = get(bus, "vpn_min", nothing)
        vpn_max = get(bus, "vpn_max", nothing)
        vpn_min === nothing && vpn_max === nothing && continue
        t_res = get(bus_res, bid, nothing)
        t_res isa Dict || continue
        nt = _neutral_terminal(bus)
        nt === nothing && continue
        vr_n = get(get(t_res, nt, Dict()), "vr", NaN)
        vi_n = get(get(t_res, nt, Dict()), "vi", NaN)
        isfinite(vr_n) && isfinite(vi_n) || continue

        # Phase terminals in terminal_names order (neutral excluded)
        term_names = Vector{String}(get(bus, "terminal_names", String[]))
        phase_ts_ordered = [t for t in term_names if t != nt]

        for (k, t) in enumerate(phase_ts_ordered)
            haskey(t_res, t) || continue
            tvals = t_res[t]
            tvals isa Dict || continue
            vr_t = get(tvals, "vr", NaN); vi_t = get(tvals, "vi", NaN)
            isfinite(vr_t) && isfinite(vi_t) || continue
            vpn = sqrt((vr_t - vr_n)^2 + (vi_t - vi_n)^2)
            # Index into per-phase bound arrays; fall back to scalar for
            # backward-compatibility with hand-written files that use a scalar.
            lb = vpn_min isa AbstractVector ? get(vpn_min, k, nothing) : vpn_min
            ub = vpn_max isa AbstractVector ? get(vpn_max, k, nothing) : vpn_max
            viol, act = _bound_status(vpn, lb, ub)
            if viol
                n_volt_viol += 1
                push!(findings, Finding(ERROR, "E.SOL.VOLT_VIOLATION", :solution, :bus, bid,
                    "Bus '$bid' terminal '$t': |Vpn|=$(_fmt_v(vpn)) violates vpn bounds.",
                    Dict{String,Any}("bus"=>bid,"terminal"=>t,"vpn"=>vpn,
                                     "vpn_min"=>lb,"vpn_max"=>ub,"flavour"=>"vpn")))
            elseif act
                n_volt_active += 1
                push!(findings, Finding(WARNING, "W.SOL.VOLT_ACTIVE", :solution, :bus, bid,
                    "Bus '$bid' terminal '$t': |Vpn|=$(_fmt_v(vpn)) is near a vpn bound.",
                    Dict{String,Any}("bus"=>bid,"terminal"=>t,"vpn"=>vpn,
                                     "vpn_min"=>lb,"vpn_max"=>ub,"flavour"=>"vpn")))
            end
        end
    end

    # ── Phase-to-phase voltage bounds (vpp_min / vpp_max) ────────────────────
    # vpp_min/vpp_max are per-pair arrays. Pairs are enumerated in the same
    # order as the upper triangle of phase terminals in terminal_names order:
    # (ts[1],ts[2]), (ts[1],ts[3]), (ts[2],ts[3]), i.e. i < j in terminal order.
    for (bid, bus) in buses
        bus isa Dict || continue
        vpp_min = get(bus, "vpp_min", nothing)
        vpp_max = get(bus, "vpp_max", nothing)
        vpp_min === nothing && vpp_max === nothing && continue
        t_res = get(bus_res, bid, nothing)
        t_res isa Dict || continue
        nt = _neutral_terminal(bus)
        term_names = Vector{String}(get(bus, "terminal_names", String[]))
        # Enumerate pairs over the FULL phase list (i<j); the pair index must
        # match the producer/OPF, so a terminal absent from the result is skipped
        # without shifting the index (see _add_bus_limit_constraints!).
        phase_ts_ordered = [t for t in term_names if t != nt]
        length(phase_ts_ordered) < 2 && continue

        pair_idx = 0
        for i in eachindex(phase_ts_ordered), j in (i+1):length(phase_ts_ordered)
            pair_idx += 1
            ta = phase_ts_ordered[i]; tb = phase_ts_ordered[j]
            (haskey(t_res, ta) && haskey(t_res, tb)) || continue
            va = t_res[ta]; vb = t_res[tb]
            dvr = get(va,"vr",NaN) - get(vb,"vr",NaN)
            dvi = get(va,"vi",NaN) - get(vb,"vi",NaN)
            isfinite(dvr) && isfinite(dvi) || continue
            vpp = sqrt(dvr^2 + dvi^2)
            lb = vpp_min isa AbstractVector ? get(vpp_min, pair_idx, nothing) : vpp_min
            ub = vpp_max isa AbstractVector ? get(vpp_max, pair_idx, nothing) : vpp_max
            viol, act = _bound_status(vpp, lb, ub)
            pair = "$ta-$tb"
            if viol
                n_volt_viol += 1
                push!(findings, Finding(ERROR, "E.SOL.VOLT_VIOLATION", :solution, :bus, bid,
                    "Bus '$bid' phase pair $pair: |Vpp|=$(_fmt_v(vpp)) violates vpp bounds.",
                    Dict{String,Any}("bus"=>bid,"pair"=>pair,"vpp"=>vpp,
                                     "vpp_min"=>lb,"vpp_max"=>ub,"flavour"=>"vpp")))
            elseif act
                n_volt_active += 1
                push!(findings, Finding(WARNING, "W.SOL.VOLT_ACTIVE", :solution, :bus, bid,
                    "Bus '$bid' phase pair $pair: |Vpp|=$(_fmt_v(vpp)) is near a vpp bound.",
                    Dict{String,Any}("bus"=>bid,"pair"=>pair,"vpp"=>vpp,
                                     "vpp_min"=>lb,"vpp_max"=>ub,"flavour"=>"vpp")))
            end
        end
    end

    # ── Sequence voltage bounds (vpos / vneg / vzero) ────────────────────────
    # Uses the same Fortescue decomposition as the OPF: α = exp(j2π/3).
    # Phase-to-neutral voltages when neutral is present; phase-to-ground otherwise.
    s3 = sqrt(3.0) / 2.0
    for (bid, bus) in buses
        bus isa Dict || continue
        vpos_min  = get(bus, "vpos_min",  nothing)
        vpos_max  = get(bus, "vpos_max",  nothing)
        vneg_max  = get(bus, "vneg_max",  nothing)
        vzero_max = get(bus, "vzero_max", nothing)
        (vpos_min === nothing && vpos_max === nothing &&
         vneg_max === nothing && vzero_max === nothing) && continue

        t_res = get(bus_res, bid, nothing)
        t_res isa Dict || continue
        nt = _neutral_terminal(bus)
        tnames = get(bus, "terminal_names", String[])
        phase_ts = [string(t) for t in tnames
                    if string(t) != nt && lowercase(string(t)) != "n"]
        length(phase_ts) != 3 && continue  # sequence bounds only meaningful for 3-phase

        vr_n = nt !== nothing ? get(get(t_res, nt, Dict()), "vr", 0.0) : 0.0
        vi_n = nt !== nothing ? get(get(t_res, nt, Dict()), "vi", 0.0) : 0.0

        dvr = Float64[]; dvi = Float64[]
        ok = true
        for t in phase_ts
            tvals = get(t_res, t, nothing)
            tvals isa Dict || (ok = false; break)
            vr_t = get(tvals, "vr", NaN); vi_t = get(tvals, "vi", NaN)
            isfinite(vr_t) && isfinite(vi_t) || (ok = false; break)
            push!(dvr, vr_t - vr_n)
            push!(dvi, vi_t - vi_n)
        end
        ok || continue

        # V1 (positive sequence)
        V1r = (dvr[1] - 0.5*dvr[2] - s3*dvi[2] - 0.5*dvr[3] + s3*dvi[3]) / 3
        V1i = (dvi[1] + s3*dvr[2] - 0.5*dvi[2] - s3*dvr[3] - 0.5*dvi[3]) / 3
        V1  = sqrt(V1r^2 + V1i^2)

        # V2 (negative sequence)
        V2r = (dvr[1] - 0.5*dvr[2] + s3*dvi[2] - 0.5*dvr[3] - s3*dvi[3]) / 3
        V2i = (dvi[1] - s3*dvr[2] - 0.5*dvi[2] + s3*dvr[3] - 0.5*dvi[3]) / 3
        V2  = sqrt(V2r^2 + V2i^2)

        # V0 (zero sequence)
        V0r = (dvr[1] + dvr[2] + dvr[3]) / 3
        V0i = (dvi[1] + dvi[2] + dvi[3]) / 3
        V0  = sqrt(V0r^2 + V0i^2)

        for (label, val, lb, ub) in (
                ("vpos", V1, vpos_min, vpos_max),
                ("vneg", V2, nothing,  vneg_max),
                ("vzero", V0, nothing, vzero_max))
            lb === nothing && ub === nothing && continue
            viol, act = _bound_status(val, lb, ub)
            if viol
                n_volt_viol += 1
                push!(findings, Finding(ERROR, "E.SOL.VOLT_VIOLATION", :solution, :bus, bid,
                    "Bus '$bid': $label=$(_fmt_v(val)) violates $label bound(s).",
                    Dict{String,Any}("bus"=>bid,"sequence"=>label,"value"=>val,
                                     "bound_min"=>lb,"bound_max"=>ub,"flavour"=>label)))
            elseif act
                n_volt_active += 1
                push!(findings, Finding(WARNING, "W.SOL.VOLT_ACTIVE", :solution, :bus, bid,
                    "Bus '$bid': $label=$(_fmt_v(val)) is near its bound (active).",
                    Dict{String,Any}("bus"=>bid,"sequence"=>label,"value"=>val,
                                     "bound_min"=>lb,"bound_max"=>ub,"flavour"=>label)))
            end
        end
    end

    out["n_volt_violations"] = n_volt_viol
    out["n_volt_active"]     = n_volt_active

    # ── Thermal limits — lines ────────────────────────────────────────────────
    linecodes = get(net, "linecode", Dict())
    n_therm_viol   = 0
    n_therm_active = 0

    for (lid, line) in get(net, "line", Dict())
        line isa Dict || continue
        lcid  = get(line, "linecode", nothing)
        lc    = lcid isa String ? get(linecodes, lcid, Dict()) : Dict()
        i_max_lc = get(lc,   "i_max", nothing)
        i_max_ln = get(line, "i_max", nothing)
        s_max_ln = get(line, "s_max", nothing)
        i_max_lc === nothing && i_max_ln === nothing && s_max_ln === nothing && continue

        cond_res = get(get(result, "line", Dict()), lid, nothing)
        cond_res isa Dict || continue
        tm_fr = string.(get(line, "terminal_map_from", String[]))

        for (k, t) in enumerate(tm_fr)
            cvals = get(cond_res, t, nothing)
            cvals isa Dict || continue
            cm_fr = get(cvals, "cm_fr", NaN)
            isfinite(cm_fr) || continue

            # i_max: line field takes precedence over linecode field
            i_lim = nothing
            if i_max_ln isa AbstractVector && k <= length(i_max_ln)
                i_lim = Float64(i_max_ln[k])
            elseif i_max_lc isa AbstractVector && k <= length(i_max_lc)
                i_lim = Float64(i_max_lc[k])
            end

            if i_lim !== nothing
                viol, act = _bound_status(cm_fr, nothing, i_lim)
                if viol
                    n_therm_viol += 1
                    push!(findings, Finding(ERROR, "E.SOL.THERMAL_VIOLATION",
                        :solution, :line, lid,
                        "Line '$lid' conductor '$t': cm_fr=$(_fmt_a(cm_fr)) exceeds " *
                        "i_max=$(_fmt_a(i_lim)).",
                        Dict{String,Any}("line"=>lid,"terminal"=>t,
                                         "cm_fr"=>cm_fr,"i_max"=>i_lim)))
                elseif act
                    n_therm_active += 1
                    push!(findings, Finding(WARNING, "W.SOL.THERMAL_ACTIVE",
                        :solution, :line, lid,
                        "Line '$lid' conductor '$t': cm_fr=$(_fmt_a(cm_fr)) is within " *
                        "1 % of i_max=$(_fmt_a(i_lim)).",
                        Dict{String,Any}("line"=>lid,"terminal"=>t,
                                         "cm_fr"=>cm_fr,"i_max"=>i_lim)))
                end
            end
        end
    end

    # ── Thermal limits — switches ─────────────────────────────────────────────
    for (sid, sw) in get(net, "switch", Dict())
        sw isa Dict || continue
        i_max_sw = get(sw, "i_max", nothing)
        i_max_sw === nothing && continue
        cond_res = get(get(result, "switch", Dict()), sid, nothing)
        cond_res isa Dict || continue
        tm_fr = string.(get(sw, "terminal_map_from", String[]))

        for (k, t) in enumerate(tm_fr)
            cvals = get(cond_res, t, nothing)
            cvals isa Dict || continue
            cm = get(cvals, "cm", NaN)
            isfinite(cm) || continue
            i_lim = i_max_sw isa AbstractVector && k <= length(i_max_sw) ?
                        Float64(i_max_sw[k]) : nothing
            i_lim === nothing && continue
            viol, act = _bound_status(cm, nothing, i_lim)
            if viol
                n_therm_viol += 1
                push!(findings, Finding(ERROR, "E.SOL.THERMAL_VIOLATION",
                    :solution, :switch, sid,
                    "Switch '$sid' conductor '$t': cm=$(_fmt_a(cm)) exceeds " *
                    "i_max=$(_fmt_a(i_lim)).",
                    Dict{String,Any}("switch"=>sid,"terminal"=>t,"cm"=>cm,"i_max"=>i_lim)))
            elseif act
                n_therm_active += 1
                push!(findings, Finding(WARNING, "W.SOL.THERMAL_ACTIVE",
                    :solution, :switch, sid,
                    "Switch '$sid' conductor '$t': cm=$(_fmt_a(cm)) is within 1 % of " *
                    "i_max=$(_fmt_a(i_lim)).",
                    Dict{String,Any}("switch"=>sid,"terminal"=>t,"cm"=>cm,"i_max"=>i_lim)))
            end
        end
    end

    out["n_thermal_violations"] = n_therm_viol
    out["n_thermal_active"]     = n_therm_active

    # ── Generator dispatch bounds ─────────────────────────────────────────────
    n_gen_viol   = 0
    n_gen_active = 0

    for (gid, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        p_min = Float64.(get(gen, "p_min", Float64[]))
        p_max = Float64.(get(gen, "p_max", Float64[]))
        q_min = Float64.(get(gen, "q_min", Float64[]))
        q_max = Float64.(get(gen, "q_max", Float64[]))
        (isempty(p_min) && isempty(p_max) && isempty(q_min) && isempty(q_max)) && continue

        ph_res = get(get(result, "generator", Dict()), gid, nothing)
        ph_res isa Dict || continue
        tm = Vector{String}(get(gen, "terminal_map", String[]))
        cfg = get(gen, "configuration", "WYE")
        ph_pos = cfg == "DELTA" ? collect(eachindex(tm)) : _phase_positions(tm)

        for (idx, ph) in enumerate(ph_pos)
            t_ph = tm[ph]
            gvals = get(ph_res, t_ph, nothing)
            gvals isa Dict || continue

            pg = get(gvals, "pg", NaN); qg = get(gvals, "qg", NaN)
            for (field, v, lo_arr, hi_arr) in (
                    ("pg", pg, p_min, p_max),
                    ("qg", qg, q_min, q_max))
                isfinite(v) || continue
                lo = idx <= length(lo_arr) ? lo_arr[idx] : nothing
                hi = idx <= length(hi_arr) ? hi_arr[idx] : nothing
                lo === nothing && hi === nothing && continue
                viol, act = _bound_status(v, lo, hi)
                if viol
                    n_gen_viol += 1
                    push!(findings, Finding(ERROR, "E.SOL.GEN_VIOLATION",
                        :solution, :generator, gid,
                        "Generator '$gid' phase '$t_ph': $field=$(_fmt_mw(v)) violates " *
                        "[$(lo === nothing ? "−∞" : _fmt_mw(lo)), " *
                        "$(hi === nothing ? "+∞" : _fmt_mw(hi))].",
                        Dict{String,Any}("generator"=>gid,"terminal"=>t_ph,
                                         "field"=>field,"value"=>v,"lo"=>lo,"hi"=>hi)))
                elseif act
                    n_gen_active += 1
                    push!(findings, Finding(WARNING, "W.SOL.GEN_ACTIVE",
                        :solution, :generator, gid,
                        "Generator '$gid' phase '$t_ph': $field=$(_fmt_mw(v)) is within " *
                        "1 % of its bound (active).",
                        Dict{String,Any}("generator"=>gid,"terminal"=>t_ph,
                                         "field"=>field,"value"=>v,"lo"=>lo,"hi"=>hi)))
                end
            end
        end
    end

    out["n_gen_violations"] = n_gen_viol
    out["n_gen_active"]     = n_gen_active

    # ── Inverter dispatch bounds and constant-PF residual ────────────────────
    n_inv_viol   = 0
    n_inv_active = 0
    pf_resid_tol = 1e-3   # relative tolerance on |sign(pf)·Q + tan_phi·P| / s_max

    profiles_net = get(net, "control_profile", Dict())

    for (inv_id, inv) in get(net, "inverter", Dict())
        inv isa Dict || continue
        p_min_arr = Float64.(get(inv, "p_min", Float64[]))
        p_max_arr = Float64.(get(inv, "p_max", Float64[]))
        smax_arr  = Float64.(get(inv, "s_max", Float64[]))

        # Resolve PF for residual check
        pf_val = nothing
        cp_id  = get(inv, "control_profile", nothing)
        if cp_id isa String
            cp = get(profiles_net, cp_id, nothing)
            if cp isa Dict
                pf_obj = get(cp, "power_factor", nothing)
                if pf_obj isa Dict
                    raw = get(pf_obj, "pf", nothing)
                    if raw isa Number && abs(Float64(raw)) > 1e-9
                        pf_val = Float64(raw)
                    end
                end
            end
        end
        tan_phi = pf_val !== nothing ? tan(acos(abs(pf_val))) : nothing
        pf_sign = pf_val !== nothing ? sign(pf_val) : 0.0

        ph_res = get(get(result, "inverter", Dict()), inv_id, nothing)
        ph_res isa Dict || continue

        tm   = Vector{String}(get(inv, "terminal_map", String[]))
        topo = get(inv, "topology", "FOUR_LEG")

        phase_keys = if topo == "SINGLE_PHASE"
            length(tm) >= 1 ? [(1, tm[1])] : Tuple{Int,String}[]
        elseif topo == "FOUR_LEG"
            [(idx, tm[ph]) for (idx, ph) in enumerate(_phase_positions(tm))]
        else  # THREE_LEG
            [(k, tm[k]) for k in eachindex(tm)]
        end

        for (idx, t_ph) in phase_keys
            tvals = get(ph_res, t_ph, nothing)
            tvals isa Dict || continue
            pg = get(tvals, "pg", NaN); qg = get(tvals, "qg", NaN)
            isfinite(pg) && isfinite(qg) || continue

            # P bounds
            lo = idx <= length(p_min_arr) ? p_min_arr[idx] : nothing
            hi = idx <= length(p_max_arr) ? p_max_arr[idx] : nothing
            if lo !== nothing || hi !== nothing
                viol, act = _bound_status(pg, lo, hi)
                if viol
                    n_inv_viol += 1
                    push!(findings, Finding(ERROR, "E.SOL.INV_VIOLATION", :solution, :inverter, inv_id,
                        "Inverter '$inv_id' phase '$t_ph': pg=$(_fmt_mw(pg)) violates " *
                        "[$(lo === nothing ? "−∞" : _fmt_mw(lo)), " *
                        "$(hi === nothing ? "+∞" : _fmt_mw(hi))].",
                        Dict{String,Any}("inverter"=>inv_id,"terminal"=>t_ph,
                                         "field"=>"pg","value"=>pg,"lo"=>lo,"hi"=>hi)))
                elseif act
                    n_inv_active += 1
                    push!(findings, Finding(WARNING, "W.SOL.INV_ACTIVE", :solution, :inverter, inv_id,
                        "Inverter '$inv_id' phase '$t_ph': pg=$(_fmt_mw(pg)) is within 1 % of its P bound.",
                        Dict{String,Any}("inverter"=>inv_id,"terminal"=>t_ph,"pg"=>pg,"lo"=>lo,"hi"=>hi)))
                end
            end

            # s_max circle
            if idx <= length(smax_arr)
                sm = smax_arr[idx]
                apparent = sqrt(pg^2 + qg^2)
                if apparent > sm * (1 + 1e-6)
                    n_inv_viol += 1
                    push!(findings, Finding(ERROR, "E.SOL.INV_VIOLATION", :solution, :inverter, inv_id,
                        "Inverter '$inv_id' phase '$t_ph': |S|=$(_fmt_mw(apparent)) " *
                        "exceeds s_max=$(_fmt_mw(sm)) (apparent-power circle violated).",
                        Dict{String,Any}("inverter"=>inv_id,"terminal"=>t_ph,
                                         "pg"=>pg,"qg"=>qg,"sm"=>apparent,"s_max"=>sm)))
                end
            end

            # Constant-PF residual: sign(pf)*Q + tan_phi*P should be ~0
            if tan_phi !== nothing
                s_ref = idx <= length(smax_arr) ? smax_arr[idx] : max(abs(pg), abs(qg), 1.0)
                resid = abs(pf_sign * qg + tan_phi * pg) / s_ref
                if resid > pf_resid_tol
                    push!(findings, Finding(WARNING, "W.SOL.INV_PF_DEVIATION", :solution, :inverter, inv_id,
                        "Inverter '$inv_id' phase '$t_ph': constant-PF residual " *
                        "$(round(resid*100; digits=3)) % of s_max — solver may not have " *
                        "enforced the PF coupling tightly (pf=$(round(pf_val; digits=4))).",
                        Dict{String,Any}("inverter"=>inv_id,"terminal"=>t_ph,
                                         "pg"=>pg,"qg"=>qg,"pf"=>pf_val,"residual"=>resid)))
                end
            end
        end
    end
    out["n_inv_violations"] = n_inv_viol
    out["n_inv_active"]     = n_inv_active

    # ── Load constraint residuals ─────────────────────────────────────────────
    resid_tol = 1.0   # 1 W / 1 var absolute tolerance
    n_load_resid       = 0
    n_load_model_resid = 0
    vd_p_nom_total = 0.0;  vd_p_real_total = 0.0
    vd_q_nom_total = 0.0;  vd_q_real_total = 0.0
    n_vd_subloads  = 0

    for (lid, load) in get(net, "load", Dict())
        load isa Dict || continue
        model = get(load, "model", "constant_power")
        p_nom = Float64.(get(load, "p_nom", Float64[]))
        q_nom = Float64.(get(load, "q_nom", Float64[]))
        ph_res = get(get(result, "load", Dict()), lid, nothing)
        ph_res isa Dict || continue
        bus = get(load, "bus", "")
        tm  = Vector{String}(get(load, "terminal_map", String[]))
        cfg = get(load, "configuration", "WYE")
        ph_pos    = cfg == "DELTA" ? collect(eachindex(tm)) : _phase_positions(tm)
        n_pos_idx = cfg == "DELTA" ? nothing : _neutral_pos(tm)
        t_n       = n_pos_idx !== nothing ? tm[n_pos_idx] : nothing

        for (idx, ph) in enumerate(ph_pos)
            t_ph = tm[ph]
            lvals = get(ph_res, t_ph, nothing)
            lvals isa Dict || continue
            pd = get(lvals, "pd", NaN); qd = get(lvals, "qd", NaN)
            isfinite(pd) && isfinite(qd) || continue
            p_ref = idx <= length(p_nom) ? p_nom[idx] : 0.0
            q_ref = idx <= length(q_nom) ? q_nom[idx] : 0.0

            if model == "constant_power"
                # Residual from nominal: should be near-zero for a tight solve.
                p_err = abs(pd - p_ref); q_err = abs(qd - q_ref)
                if p_err > resid_tol || q_err > resid_tol
                    n_load_resid += 1
                    push!(findings, Finding(WARNING, "W.SOL.LOAD_RESIDUAL",
                        :solution, :load, lid,
                        "Load '$lid' phase '$t_ph': constant-power residual " *
                        "|Δp|=$(round(p_err; digits=2)) W, " *
                        "|Δq|=$(round(q_err; digits=2)) var — " *
                        "solver may not have converged tightly.",
                        Dict{String,Any}("load"=>lid,"terminal"=>t_ph,
                                         "p_err"=>p_err,"q_err"=>q_err,
                                         "p_nom"=>p_ref,"q_nom"=>q_ref)))
                end
            else
                # Voltage-dependent load: pd ≠ p_nom is expected.
                # Check model self-consistency: pd should equal p_nom·f(W/Vnom²).
                # Reconstruct W from solved bus voltages.
                b_res = get(bus_res, bus, nothing)
                b_res isa Dict || continue
                vr_ph = get(get(b_res, t_ph, Dict()), "vr", NaN)
                vi_ph = get(get(b_res, t_ph, Dict()), "vi", NaN)
                vr_n  = t_n !== nothing ? get(get(b_res, t_n, Dict()), "vr", 0.0) : 0.0
                vi_n  = t_n !== nothing ? get(get(b_res, t_n, Dict()), "vi", 0.0) : 0.0
                isfinite(vr_ph) && isfinite(vi_ph) || continue
                dvr = vr_ph - vr_n; dvi = vi_ph - vi_n
                W = dvr^2 + dvi^2

                Vnom = let vv = get(load, "v_nom", nothing)
                    vv === nothing ? nothing :
                    (vv isa AbstractVector ?
                        Float64(length(vv) == 1 ? vv[1] : (idx <= length(vv) ? vv[idx] : vv[end])) :
                        Float64(vv))
                end
                Vnom === nothing && continue

                pd_model = _load_model_power(load, "p", idx, p_ref, W, Vnom)
                qd_model = _load_model_power(load, "q", idx, q_ref, W, Vnom)
                pd_model === nothing || qd_model === nothing && continue

                p_err = abs(pd - pd_model); q_err = abs(qd - qd_model)
                if p_err > resid_tol || q_err > resid_tol
                    n_load_model_resid += 1
                    push!(findings, Finding(WARNING, "W.SOL.LOAD_MODEL_RESIDUAL",
                        :solution, :load, lid,
                        "Load '$lid' phase '$t_ph' (model=$model): realised power " *
                        "pd=$(round(pd; digits=2)) W deviates from model prediction " *
                        "$(round(pd_model; digits=2)) W at the solved voltage " *
                        "(|ΔV|=$(round(sqrt(W); digits=2)) V, Vnom=$(round(Vnom; digits=1)) V). " *
                        "The load model constraint may not be satisfied.",
                        Dict{String,Any}("load"=>lid,"terminal"=>t_ph,
                                         "pd"=>pd,"qd"=>qd,
                                         "pd_model"=>pd_model,"qd_model"=>qd_model,
                                         "p_nom"=>p_ref,"q_nom"=>q_ref,
                                         "W"=>W,"v_nom"=>Vnom)))
                end

                # Accumulate for VD summary.
                vd_p_nom_total  += p_ref;  vd_p_real_total += pd
                vd_q_nom_total  += q_ref;  vd_q_real_total += qd
                n_vd_subloads   += 1
            end
        end
    end
    out["n_load_residuals"]       = n_load_resid
    out["n_load_model_residuals"] = n_load_model_resid

    # ── Voltage-dependent load summary ────────────────────────────────────────
    if n_vd_subloads > 0
        p_shift = vd_p_real_total - vd_p_nom_total
        q_shift = vd_q_real_total - vd_q_nom_total
        out["vd_p_nom_total"]  = vd_p_nom_total
        out["vd_p_real_total"] = vd_p_real_total
        out["vd_q_nom_total"]  = vd_q_nom_total
        out["vd_q_real_total"] = vd_q_real_total
        push!(findings, Finding(INFO, "I.SOL.LOAD_VD_SUMMARY", :solution, :network, nothing,
            "Voltage-dependent loads ($n_vd_subloads sub-load(s)): " *
            "realised P=$(round(vd_p_real_total/1e3; digits=3)) kW vs nominal " *
            "$(round(vd_p_nom_total/1e3; digits=3)) kW " *
            "($(round(p_shift/1e3; digits=3)) kW shift); " *
            "Q=$(round(vd_q_real_total/1e3; digits=3)) kvar vs nominal " *
            "$(round(vd_q_nom_total/1e3; digits=3)) kvar.",
            Dict{String,Any}(
                "n_vd_subloads"    => n_vd_subloads,
                "p_nom_total_W"    => vd_p_nom_total,
                "p_real_total_W"   => vd_p_real_total,
                "q_nom_total_var"  => vd_q_nom_total,
                "q_real_total_var" => vd_q_real_total)))
    end

    # ── Network-wide power balance ─────────────────────────────────────────────
    # Σ inj (generators + inverters + voltage source) − Σ load − Σ element loss ≈ 0,
    # checked for BOTH active and reactive power. All injection sources must be
    # counted: omitting inverters or the slack makes the balance spuriously fail
    # whenever DERs dispatch or the slack imports/exports.
    #
    # Element losses come from the exact terminal-power identity computed by the
    # solver (result["losses"] = Σ over lines+transformers of S_from + S_to). This
    # replaces the former R·|I|² approximation, which ignored transformers, mutual
    # resistance, shunt-G loss, and all reactive losses, and double-counted the
    # π-shunt current inside cm_fr.
    _sum_injection(block, field) = sum(get(vals, field, 0.0)
                 for (_, ph_dict) in get(result, block, Dict())
                 for (_, vals)    in ph_dict
                 if vals isa Dict; init=0.0)
    p_gen = _sum_injection("generator", "pg") +
            _sum_injection("inverter",  "pg") +
            _sum_injection("voltage_source", "ps")
    q_gen = _sum_injection("generator", "qg") +
            _sum_injection("inverter",  "qg") +
            _sum_injection("voltage_source", "qs")
    p_load = sum(get(lvals, "pd", 0.0)
                 for (_, ph_dict) in get(result, "load", Dict())
                 for (_, lvals)   in ph_dict
                 if lvals isa Dict; init=0.0)
    q_load = sum(get(lvals, "qd", 0.0)
                 for (_, ph_dict) in get(result, "load", Dict())
                 for (_, lvals)   in ph_dict
                 if lvals isa Dict; init=0.0)

    losses = get(result, "losses", Dict())
    p_loss = losses isa Dict ? Float64(get(losses, "p_loss", 0.0)) : 0.0
    q_loss = losses isa Dict ? Float64(get(losses, "q_loss", 0.0)) : 0.0

    balance_err   = abs(p_gen - p_load - p_loss)
    q_balance_err = abs(q_gen - q_load - q_loss)
    balance_tol   = max(0.01 * abs(p_load), 1.0)   # 1 % of load or 1 W
    # Reactive flows can be near zero while loads are unity-PF; floor on |q_load|
    # plus a small share of |q_gen| keeps the relative test meaningful.
    q_balance_tol = max(0.01 * abs(q_load), 0.01 * abs(q_gen), 1.0)
    out["p_gen"]             = p_gen
    out["q_gen"]             = q_gen
    out["p_load"]            = p_load
    out["q_load"]            = q_load
    out["p_loss"]            = p_loss
    out["q_loss"]            = q_loss
    out["power_balance_err"]  = balance_err
    out["q_power_balance_err"] = q_balance_err

    if balance_err > balance_tol
        push!(findings, Finding(WARNING, "W.SOL.POWER_BALANCE", :solution, :network, nothing,
            "Network active-power balance error: |pg_total − pd_total − p_loss| = " *
            "$(_fmt_mw(balance_err)) (>1 % of load). " *
            "pg=$(round(p_gen/1e3;digits=2)) kW, pd=$(round(p_load/1e3;digits=2)) kW, " *
            "p_loss=$(round(p_loss/1e3;digits=2)) kW.",
            Dict{String,Any}("p_gen"=>p_gen,"p_load"=>p_load,"p_loss"=>p_loss,
                             "balance_err"=>balance_err)))
    end
    if q_balance_err > q_balance_tol
        push!(findings, Finding(WARNING, "W.SOL.POWER_BALANCE", :solution, :network, nothing,
            "Network reactive-power balance error: |qg_total − qd_total − q_loss| = " *
            "$(_fmt_mw(q_balance_err)) var (>1 % of reactive load/gen). " *
            "qg=$(round(q_gen/1e3;digits=2)) kvar, qd=$(round(q_load/1e3;digits=2)) kvar, " *
            "q_loss=$(round(q_loss/1e3;digits=2)) kvar.",
            Dict{String,Any}("q_gen"=>q_gen,"q_load"=>q_load,"q_loss"=>q_loss,
                             "balance_err"=>q_balance_err,"flavour"=>"reactive")))
    end

    # ── Initialisation quality ────────────────────────────────────────────────
    # Only meaningful when the solver found a feasible point and the result
    # contains an "initialisation" block (written by solve_opf).
    init_res = get(result, "initialisation", nothing)
    if init_res isa Dict
        n_level_mismatch = 0
        n_large_error    = 0
        n_neutral_nonzero = 0
        level_mismatch_locs  = String[]
        large_error_locs     = String[]
        neutral_nonzero_locs = String[]

        for (bid, bus) in buses
            bus isa Dict || continue
            nt     = _neutral_terminal(bus)
            t_init = get(init_res, bid, nothing)
            t_init isa Dict || continue
            t_sol  = get(bus_res,  bid, nothing)
            t_sol  isa Dict || continue

            for (t, ivals) in t_init
                ivals isa Dict || continue
                vm_init = get(ivals, "vm_init", NaN)
                isfinite(vm_init) || continue

                # Non-zero neutral init — should always start at 0
                if t == nt && vm_init > 1e-6
                    n_neutral_nonzero += 1
                    push!(neutral_nonzero_locs, "$bid.$t (vm_init=$(_fmt_v(vm_init)))")
                    continue
                end
                t == nt && continue   # zero neutral — nothing further to check

                svals   = get(t_sol, t, nothing)
                svals isa Dict || continue
                vm_sol  = get(svals, "vm", NaN)
                isfinite(vm_sol) && vm_sol > 0 || continue

                ratio = vm_init / vm_sol
                if ratio > 10.0 || ratio < 0.1
                    n_level_mismatch += 1
                    push!(level_mismatch_locs,
                          "$bid.$t (vm_init=$(_fmt_v(vm_init)), vm_sol=$(_fmt_v(vm_sol)))")
                elseif abs(vm_init - vm_sol) / vm_sol > 0.20
                    n_large_error += 1
                    push!(large_error_locs,
                          "$bid.$t (vm_init=$(_fmt_v(vm_init)), vm_sol=$(_fmt_v(vm_sol)))")
                end
            end
        end

        out["n_init_level_mismatches"]  = n_level_mismatch
        out["n_init_large_errors"]      = n_large_error
        out["n_init_neutral_nonzero"]   = n_neutral_nonzero

        if n_level_mismatch > 0
            push!(findings, Finding(WARNING, "W.SOL.INIT_LEVEL_MISMATCH", :solution,
                :network, nothing,
                "$n_level_mismatch terminal(s) were initialised at a voltage more than " *
                "10× away from the solved value — the initialisation used the wrong " *
                "voltage level (source voltage applied to LV buses). Convergence to the " *
                "physical solution is not guaranteed; consider using per-unit mode or " *
                "level-aware initialisation.",
                Dict{String,Any}("terminals" => level_mismatch_locs)))
        end
        if n_large_error > 0
            push!(findings, Finding(WARNING, "W.SOL.INIT_LARGE_ERROR", :solution,
                :network, nothing,
                "$n_large_error phase terminal(s) have an initialisation error > 20 % " *
                "of the solved voltage magnitude — the starting point was a poor " *
                "approximation, which may slow convergence or indicate a local minimum.",
                Dict{String,Any}("terminals" => large_error_locs)))
        end
        if n_neutral_nonzero > 0
            push!(findings, Finding(INFO, "I.SOL.INIT_NEUTRAL_NONZERO", :solution,
                :network, nothing,
                "$n_neutral_nonzero neutral terminal(s) were initialised with non-zero " *
                "voltage — neutral start values should be zero.",
                Dict{String,Any}("terminals" => neutral_nonzero_locs)))
        end
    end

    # ── Informational: binding summary ────────────────────────────────────────
    n_violations = n_volt_viol + n_therm_viol + n_gen_viol
    n_active     = n_volt_active + n_therm_active + n_gen_active
    push!(findings, Finding(INFO, "I.SOL.BINDING_SUMMARY", :solution, :network, nothing,
        "Solution bound summary: $n_violations violation(s), $n_active active constraint(s). " *
        "Voltage: $(n_volt_viol)V / $(n_volt_active)A. " *
        "Thermal: $(n_therm_viol)V / $(n_therm_active)A. " *
        "Generator: $(n_gen_viol)V / $(n_gen_active)A.",
        Dict{String,Any}("n_volt_violations"=>n_volt_viol,"n_volt_active"=>n_volt_active,
                         "n_thermal_violations"=>n_therm_viol,"n_thermal_active"=>n_therm_active,
                         "n_gen_violations"=>n_gen_viol,"n_gen_active"=>n_gen_active)))

    # ── Informational: loss fraction ──────────────────────────────────────────
    if p_load > 0
        loss_frac = p_loss / p_load
        out["loss_fraction"] = loss_frac
        if loss_frac > 0.20
            push!(findings, Finding(INFO, "I.SOL.LOSS_FRACTION", :solution, :network, nothing,
                "Line losses are $(round(loss_frac*100; digits=1)) % of total load — " *
                "unusually high; verify impedance scaling and operating point.",
                Dict{String,Any}("loss_fraction"=>loss_frac,"p_loss"=>p_loss,"p_load"=>p_load)))
        end
    end

    # ── Negative active loss on passive branches ──────────────────────────────
    _check_negative_losses(result, findings, out)

    # ── Informational: neutral shift ──────────────────────────────────────────
    max_neutral_vm = 0.0
    max_neutral_bus = ""
    for (bid, bus) in buses
        bus isa Dict || continue
        bid in source_buses && continue
        nt = _neutral_terminal(bus)
        nt === nothing && continue
        t_res = get(bus_res, bid, nothing)
        t_res isa Dict || continue
        vm_n = get(get(t_res, nt, Dict()), "vm", 0.0)
        isfinite(vm_n) && vm_n > max_neutral_vm && (max_neutral_vm = vm_n; max_neutral_bus = bid)
    end
    out["max_neutral_shift_v"] = max_neutral_vm
    out["max_neutral_shift_bus"] = max_neutral_bus
    if max_neutral_vm > 0.0
        push!(findings, Finding(INFO, "I.SOL.NEUTRAL_SHIFT", :solution, :network, nothing,
            "Maximum neutral terminal voltage: $(_fmt_v(max_neutral_vm)) at bus " *
            "'$max_neutral_bus' — reflects the neutral shift under unbalanced loading.",
            Dict{String,Any}("max_neutral_vm"=>max_neutral_vm,"bus"=>max_neutral_bus)))
    end

    out
end

# Active power dissipated by a passive branch is ≥ 0 by construction (series
# R ≥ 0, shunt G ≥ 0). A negative p_loss beyond numerical noise is non-physical —
# the branch would be a net source of active power — and signals a non-converged
# or ill-conditioned solution, a sign error, or a negative-resistance input.
# p_loss is a difference of large near-equal terminal powers, so its cancellation
# noise scales with the power flowing through the branch; the tolerance is
# therefore throughput-relative with a small absolute floor. Reactive loss is
# deliberately excluded: line charging and capacitive shunts make q_loss
# legitimately negative.
const _NEG_LOSS_ABS_W    = 1.0    # absolute floor [W] — ignore sub-watt noise
const _NEG_LOSS_REL_FRAC = 1e-4   # relative floor as a fraction of |s_through|

function _check_negative_losses(result::Dict{String,Any},
                                findings::Vector{Finding},
                                out::Dict{String,Any})
    n_neg = 0
    worst_p = 0.0; worst_id = ""
    for (block, csym, label) in (("line", :line, "Line"),
                                  ("transformer", :transformer, "Transformer"))
        for (id, eres) in get(result, block, Dict())
            eres isa Dict || continue
            loss = get(eres, "loss", nothing)
            loss isa Dict || continue
            pl = Float64(get(loss, "p_loss", 0.0))
            isfinite(pl) || continue
            s_through = abs(Float64(get(loss, "s_through", 0.0)))
            tol = max(_NEG_LOSS_ABS_W, _NEG_LOSS_REL_FRAC * s_through)
            pl < -tol || continue
            n_neg += 1
            pl < worst_p && (worst_p = pl; worst_id = id)
            rel = s_through > 0 ? -pl / s_through : NaN
            push!(findings, Finding(WARNING, "W.SOL.NEG_LOSS", :solution, csym, id,
                "$label '$id' dissipates negative active power: p_loss = " *
                "$(_fmt_mw(pl))" *
                (isfinite(rel) ? " ($(round(rel*100; digits=2)) % of throughput)" : "") *
                " — a passive branch cannot generate active power. This points to a " *
                "non-converged or ill-conditioned solution, a sign error, or a " *
                "negative-resistance input. (Reactive loss may legitimately be " *
                "negative; active cannot.)",
                Dict{String,Any}("p_loss"=>pl, "s_through"=>s_through, "rel"=>rel)))
        end
    end
    out["n_negative_losses"] = n_neg
    out["worst_negative_loss_w"] = worst_p
    n_neg > 0 && (out["worst_negative_loss_id"] = worst_id)
    out
end

"""
    voltage_zone_summary(net, result) -> Dict{String,Any}

Aggregate the solved bus voltages into a per-galvanic-zone band summary for
at-a-glance inspection. Galvanic zones (the connected components left after
cutting transformer windings) are the
natural grouping because every bus in a zone shares one voltage base, so the
per-unit magnitudes are directly comparable; volts across a transformer
boundary are not.

Each zone is reduced over its phase terminals (the neutral is excluded from the
magnitude band but tracked separately as a neutral shift):

- `v_base`        — phase-to-neutral voltage base (V). Taken from the zone's
  voltage source if it contains one, else the midpoint of the buses' `v_min`/
  `v_max`, else the median solved phase magnitude.
- `vm_min_pu` / `vm_max_pu` — min/max phase magnitude in the zone, per unit.
- `vm_min_bus` / `vm_max_bus` — the buses carrying those extremes.
- `max_imbalance_pct` — worst per-bus phase-magnitude spread (max−min)/v_base.
- `max_imbalance_bus` — bus carrying that worst imbalance.
- `max_neutral_shift_v` / `max_neutral_shift_bus` — worst neutral terminal
  voltage in the zone.
- `status` — `"ok"`, `"active"` (within 1 % of a bound), or `"violation"`,
  derived from the buses' own `v_min`/`v_max` using the same threshold as the
  bound checks.
- `bus_rows` — per-bus drill-down records (`bus`, `vm_min_v`/`vm_max_v`,
  `vm_min_pu`/`vm_max_pu`, `imbalance_pct`, `neutral_shift_v`, `deviation_pu`,
  `status`), sorted worst-deviation-from-1.0-pu first. Rendered only in verbose
  output.

Returns `Dict("zones" => Vector{Dict}, "n_zones" => Int)`, zones sorted by
label. Returns empty zones when there is no bus result.
"""
function voltage_zone_summary(net::Dict{String,Any}, result::Dict{String,Any})
    buses   = get(net, "bus", Dict())
    bus_res = get(result, "bus", Dict())
    out = Dict{String,Any}("zones" => Dict{String,Any}[], "n_zones" => 0)
    (isempty(buses) || !(bus_res isa Dict) || isempty(bus_res)) && return out

    active_frac = 0.01   # same "within 1 %" threshold as the bound checks

    # Voltage-source bus → its phase-to-neutral magnitude (for the base).
    src_vbase = Dict{String,Float64}()
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        b = string(get(vs, "bus", ""))
        b == "" && continue
        vmag = Float64.(get(vs, "vm", get(vs, "v_magnitude", Float64[])))
        isempty(vmag) && continue
        src_vbase[b] = maximum(abs, vmag)
    end

    zone_dicts = Dict{String,Any}[]
    for zone in _galvanic_zones(net)
        zbuses = sort(collect(zone))

        # ── Zone voltage base ────────────────────────────────────────────────
        # Priority:
        #   1. bus["v_declared"] — the standardised supply nominal (e.g. 230 V),
        #      so per-unit is reported against the declared voltage rather than
        #      the actual source magnitude (which may be 240 V). When buses in a
        #      zone disagree, use the median.
        #   2. the zone's voltage-source magnitude
        #   3. midpoint of the buses' v_min/v_max declared bounds
        #   4. (later) the median solved phase magnitude
        vbase = 0.0
        declared = Float64[]
        for b in zbuses
            bus = get(buses, b, Dict())
            bus isa Dict || continue
            vd = get(bus, "v_declared", nothing)
            vd isa Real && push!(declared, Float64(vd))
        end
        if !isempty(declared)
            sort!(declared)
            n = length(declared)
            vbase = isodd(n) ? declared[(n+1)÷2] :
                    (declared[n÷2] + declared[n÷2+1]) / 2
        end
        if vbase == 0.0
            for b in zbuses
                haskey(src_vbase, b) && (vbase = max(vbase, src_vbase[b]))
            end
        end
        if vbase == 0.0   # no source in zone: midpoint of declared bounds
            # v_min/v_max are per-phase arrays — flatten every phase entry.
            _flat(x) = x === nothing ? Float64[] :
                       (x isa AbstractVector ? Float64.(x) : [Float64(x)])
            los = Float64[]; his = Float64[]
            for b in zbuses
                bus = get(buses, b, Dict())
                append!(los, _flat(get(bus, "v_min", nothing)))
                append!(his, _flat(get(bus, "v_max", nothing)))
            end
            if !isempty(los) && !isempty(his)
                vbase = (sum(los)/length(los) + sum(his)/length(his)) / 2
            end
        end

        # ── Reduce over phase terminals ──────────────────────────────────────
        vm_min = Inf;  vm_min_bus = ""
        vm_max = -Inf; vm_max_bus = ""
        max_imb = 0.0; max_imb_bus = ""
        max_neutral = 0.0; max_neutral_bus = ""
        viol = false; active = false
        topu(v) = (vbase > 0.0 && isfinite(v)) ? v / vbase : NaN
        bus_rows = Dict{String,Any}[]
        for b in zbuses
            bus = get(buses, b, Dict())
            bus isa Dict || continue
            nt = _neutral_terminal(bus)
            v_min = get(bus, "v_min", nothing)
            v_max = get(bus, "v_max", nothing)
            t_res = get(bus_res, b, nothing)
            t_res isa Dict || continue

            # v_min/v_max are per-phase arrays; map each phase terminal to its
            # index so the bound for terminal t can be looked up.
            phase_ix = Dict{String,Int}()
            for (k, t) in enumerate(t for t in Vector{String}(get(bus, "terminal_names", String[])) if t != nt)
                phase_ix[t] = k
            end
            _vb(v, t) = v === nothing ? nothing :
                        (v isa AbstractVector ? get(v, get(phase_ix, string(t), 0), nothing) : v)

            bus_lo = Inf; bus_hi = -Inf; bus_neutral = 0.0; bus_viol = false; bus_active = false
            for (t, tvals) in t_res
                tvals isa Dict || continue
                vm = get(tvals, "vm", NaN)
                isfinite(vm) || continue
                if t == nt || lowercase(string(t)) == "n"
                    vm > bus_neutral && (bus_neutral = vm)
                    vm > max_neutral && (max_neutral = vm; max_neutral_bus = b)
                    continue
                end
                vm < vm_min && (vm_min = vm; vm_min_bus = b)
                vm > vm_max && (vm_max = vm; vm_max_bus = b)
                vm < bus_lo && (bus_lo = vm)
                vm > bus_hi && (bus_hi = vm)
                lb = _vb(v_min, t); ub = _vb(v_max, t)
                if lb !== nothing && vm < Float64(lb) - 1e-9
                    bus_viol = true
                elseif lb !== nothing &&
                       vm < Float64(lb) + max(active_frac*abs(Float64(lb)), 1e-6)
                    bus_active = true
                end
                if ub !== nothing && vm > Float64(ub) + 1e-9
                    bus_viol = true
                elseif ub !== nothing &&
                       vm > Float64(ub) - max(active_frac*abs(Float64(ub)), 1e-6)
                    bus_active = true
                end
            end
            bus_viol   && (viol = true)
            bus_active && (active = true)

            has_phase = isfinite(bus_lo) && isfinite(bus_hi)
            spread = has_phase ? bus_hi - bus_lo : NaN
            has_phase && spread > max_imb && (max_imb = spread; max_imb_bus = b)

            # Per-bus drill-down record (deviation drives the sort in the renderer).
            vm_lo_pu = topu(bus_lo); vm_hi_pu = topu(bus_hi)
            dev = (isfinite(vm_lo_pu) && isfinite(vm_hi_pu)) ?
                  max(abs(vm_hi_pu - 1.0), abs(vm_lo_pu - 1.0)) : NaN
            push!(bus_rows, Dict{String,Any}(
                "bus"             => b,
                "vm_min_v"        => has_phase ? bus_lo : NaN,
                "vm_max_v"        => has_phase ? bus_hi : NaN,
                "vm_min_pu"       => vm_lo_pu,
                "vm_max_pu"       => vm_hi_pu,
                "imbalance_pct"   => (vbase > 0.0 && has_phase) ? 100 * spread / vbase : NaN,
                "neutral_shift_v" => bus_neutral,
                "deviation_pu"    => dev,
                "status"          => bus_viol ? "violation" : bus_active ? "active" : "ok",
            ))
        end

        isfinite(vm_min) || (vm_min = NaN)
        isfinite(vm_max) || (vm_max = NaN)

        # Worst deviation first; NaN deviations sink to the bottom.
        sort!(bus_rows, by = r -> (isfinite(r["deviation_pu"]) ? -r["deviation_pu"] : Inf))

        push!(zone_dicts, Dict{String,Any}(
            "label"                 => first(zbuses),
            "buses"                 => zbuses,
            "n_buses"               => length(zbuses),
            "v_base"                => vbase,
            "vm_min_v"              => vm_min,
            "vm_max_v"              => vm_max,
            "vm_min_pu"             => topu(vm_min),
            "vm_max_pu"             => topu(vm_max),
            "vm_min_bus"            => vm_min_bus,
            "vm_max_bus"            => vm_max_bus,
            "max_imbalance_pct"     => vbase > 0.0 ? 100 * max_imb / vbase : NaN,
            "max_imbalance_bus"     => max_imb_bus,
            "max_neutral_shift_v"   => max_neutral,
            "max_neutral_shift_bus" => max_neutral_bus,
            "status"                => viol ? "violation" : active ? "active" : "ok",
            "bus_rows"              => bus_rows,
        ))
    end

    sort!(zone_dicts, by = z -> z["label"])
    out["zones"]   = zone_dicts
    out["n_zones"] = length(zone_dicts)
    out
end

# ── Formatting helpers (local to this file) ───────────────────────────────────
_fmt_v(v::Float64)  = "$(round(v; digits=2)) V"
_fmt_a(v::Float64)  = "$(round(v; digits=2)) A"
_fmt_mw(v::Float64) = abs(v) >= 1e6 ? "$(round(v/1e6; digits=3)) MW" :
                       abs(v) >= 1e3 ? "$(round(v/1e3; digits=3)) kW" :
                                       "$(round(v; digits=2)) W"
