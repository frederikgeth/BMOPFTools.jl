# Per-unit scaling for the IVR-EN OPF.
#
# _to_per_unit(net, s_base)  ->  (net_pu, bases)
# _from_per_unit(result, bases) -> result_si
#
# Convention
# ──────────
# A single system MVA base (s_base, VA) is chosen by the caller.
# V_base at the source bus comes from the first voltage source's v_magnitude[1].
# V_base propagates through transformers by the turns ratio N = v_ref_from/v_ref_to:
#   V_base[to] = V_base[from] / N
# Lines and switches do not change the voltage base.
# Buses not reachable from the BFS receive the source V_base as a fallback.
#
# Derived bases per bus:
#   Z_base[bus] = V_base[bus]^2 / s_base   (Ω)
#   I_base[bus] = s_base / V_base[bus]      (A)
#   Y_base[bus] = s_base / V_base[bus]^2   (S)
#
# The net dict is deep-copied before modification; the original is never mutated.
# The bases NamedTuple is returned alongside the per-unit net so that
# _from_per_unit can scale results back to SI without re-traversing the network.

# ── Base computation ─────────────────────────────────────────────────────────

"""
    _compute_bases(net, s_base) -> NamedTuple

Compute per-bus voltage bases via BFS from the voltage source, propagating
through transformers by turns ratio. Returns a NamedTuple with:
  - `s_base`     :: Float64          system VA base
  - `v_base`     :: Dict{String,Float64}  per-bus voltage base (V, line-to-neutral)
  - `z_base`     :: Dict{String,Float64}  per-bus impedance base (Ω)
  - `i_base`     :: Dict{String,Float64}  per-bus current base (A)
  - `y_base`     :: Dict{String,Float64}  per-bus admittance base (S)
"""
function _compute_bases(net::Dict{String,Any}, s_base::Float64)
    buses = keys(get(net, "bus", Dict()))

    # Find source bus and its V_base from the first voltage source.
    src_bus = ""
    src_vbase = 0.0
    for (_, vs) in get(net, "voltage_source", Dict())
        vmag = Float64.(get(vs, "v_magnitude", Float64[]))
        isempty(vmag) && continue
        src_bus   = get(vs, "bus", "")
        src_vbase = maximum(abs, vmag)   # phase-to-neutral magnitude
        break
    end
    src_vbase == 0.0 && (src_vbase = 1.0)   # degenerate fallback

    v_base = Dict{String,Float64}()
    src_bus != "" && (v_base[src_bus] = src_vbase)

    # BFS through transformers to propagate V_base.
    # Build adjacency: bus -> [(neighbour_bus, v_ref_from, v_ref_to, from_is_from)]
    xfmr_adj = Dict{String,Vector{Tuple{String,Float64,Float64}}}()
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        for (_, xfmr) in get(xfmr_dict, subtype, Dict())
            bf = get(xfmr, "bus_from", "")
            bt = get(xfmr, "bus_to",   "")
            vrf = Float64(get(xfmr, "v_ref_from", 1.0))
            vrt = Float64(get(xfmr, "v_ref_to",   1.0))
            (isempty(bf) || isempty(bt)) && continue
            push!(get!(xfmr_adj, bf, Tuple{String,Float64,Float64}[]), (bt, vrf, vrt))
            push!(get!(xfmr_adj, bt, Tuple{String,Float64,Float64}[]), (bf, vrt, vrf))
        end
    end

    # Lines and switches do not change the voltage base; build adjacency for
    # same-base propagation so all buses on an LV feeder inherit the correct
    # v_base from the transformer LV terminal rather than falling back to the
    # MV source base.
    line_adj = Dict{String,Vector{String}}()
    for (_, line) in get(net, "line", Dict())
        bf = get(line, "bus_from", "")
        bt = get(line, "bus_to",   "")
        (isempty(bf) || isempty(bt)) && continue
        push!(get!(line_adj, bf, String[]), bt)
        push!(get!(line_adj, bt, String[]), bf)
    end
    for (_, sw) in get(net, "switch", Dict())
        bf = get(sw, "bus_from", "")
        bt = get(sw, "bus_to",   "")
        (isempty(bf) || isempty(bt)) && continue
        push!(get!(line_adj, bf, String[]), bt)
        push!(get!(line_adj, bt, String[]), bf)
    end

    queue = [src_bus]
    visited = Set{String}([src_bus])
    while !isempty(queue)
        bus = popfirst!(queue)
        vb  = v_base[bus]
        for (nb, vref_this, vref_nb) in get(xfmr_adj, bus, Tuple{String,Float64,Float64}[])
            nb in visited && continue
            push!(visited, nb)
            # V_base[nb] = V_base[bus] * (vref_nb / vref_this)
            ratio = vref_this > 0.0 ? vref_nb / vref_this : 1.0
            v_base[nb] = vb * ratio
            push!(queue, nb)
        end
        for nb in get(line_adj, bus, String[])
            nb in visited && continue
            push!(visited, nb)
            v_base[nb] = vb   # lines preserve the voltage base
            push!(queue, nb)
        end
    end

    # Buses not reached by BFS get the source V_base as fallback.
    for b in buses
        haskey(v_base, b) || (v_base[b] = src_vbase)
    end

    z_base = Dict(b => v_base[b]^2 / s_base for b in keys(v_base))
    i_base = Dict(b => s_base / v_base[b]   for b in keys(v_base))
    y_base = Dict(b => s_base / v_base[b]^2 for b in keys(v_base))

    (s_base=s_base, v_base=v_base, z_base=z_base, i_base=i_base, y_base=y_base)
end

# ── Conversion to per unit ────────────────────────────────────────────────────

"""
    _to_per_unit(net, s_base) -> (net_pu, bases)

Return a deep copy of `net` with all numerical fields scaled to per unit,
plus the `bases` NamedTuple produced by `_compute_bases`. The original `net`
is never mutated.
"""
function _to_per_unit(net::Dict{String,Any}, s_base::Float64)
    bases  = _compute_bases(net, s_base)
    net_pu = deepcopy(net)
    _pu_scale_buses!(net_pu, bases)
    _pu_scale_sources!(net_pu, bases)
    _pu_scale_linecodes!(net_pu, bases)
    _pu_scale_loads!(net_pu, bases)
    _pu_scale_generators!(net_pu, bases)
    _pu_scale_inverters!(net_pu, bases)
    _pu_scale_transformers!(net_pu, bases)
    _pu_scale_shunts!(net_pu, bases)
    net_pu, bases
end

# ── Per-element scalers ───────────────────────────────────────────────────────

function _pu_scale_buses!(net, bases)
    v_base = bases.v_base
    voltage_fields = ("v_min", "v_max", "vpn_min", "vpn_max",
                      "vpp_min", "vpp_max", "vn_max",
                      "vpos_min", "vpos_max", "vneg_max", "vzero_max")
    for (bid, bus) in get(net, "bus", Dict())
        vb = get(v_base, bid, 1.0)
        # Scale each voltage bound by V_base. v_min/v_max (per-phase), vpn_*
        # (per-phase) and vpp_* (per-pair) are vectors; vn_max and the sequence
        # bounds are scalars. The branch below handles both shapes generically.
        for f in voltage_fields
            haskey(bus, f) || continue
            v = bus[f]
            bus[f] = v isa AbstractVector ? Float64.(v) ./ vb : Float64(v) / vb
        end
        # va_diff_min/max are angles (radians) — unchanged
    end
end

function _pu_scale_sources!(net, bases)
    v_base = bases.v_base
    sb     = bases.s_base
    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", "")
        vb  = get(v_base, bus, 1.0)
        if haskey(vs, "v_magnitude")
            vs["v_magnitude"] = Float64.(vs["v_magnitude"]) ./ vb
        end
        # v_angle is in radians — unchanged

        # Optional flow bounds: W/var → PU (divide by s_base)
        for f in ("p_min", "p_max", "q_min", "q_max")
            haskey(vs, f) && (vs[f] = Float64.(vs[f]) ./ sb)
        end
        # Cost: per-phase linear coefficient $/W in SI → $/PU-W in PU (× s_base)
        if haskey(vs, "cost")
            c = vs["cost"]
            vs["cost"] = c isa AbstractVector ? Float64.(c) .* sb : Float64(c) * sb
        end
    end
end

function _pu_scale_linecodes!(net, bases)
    # Linecodes are shared across buses; we need a representative Z_base.
    # Since lines don't change V_base, any bus on the line has the same Z_base.
    # Strategy: build a map linecode_id -> z_base from line elements.
    lc_zbase = Dict{String,Float64}()
    lc_ibase = Dict{String,Float64}()
    for (_, line) in get(net, "line", Dict())
        lcid = get(line, "linecode", nothing)
        lcid === nothing && continue
        haskey(lc_zbase, lcid) && continue   # already assigned
        bus = get(line, "bus_from", "")
        lc_zbase[lcid] = get(bases.z_base, bus, 1.0)
        lc_ibase[lcid] = get(bases.i_base, bus, 1.0)
    end

    series_fields = ("R_series_", "X_series_")
    shunt_fields  = ("G_from_", "B_from_", "G_to_", "B_to_")

    for (lcid, lc) in get(net, "linecode", Dict())
        zb = get(lc_zbase, lcid, 1.0)
        ib = get(lc_ibase, lcid, 1.0)
        for (k, v) in lc
            for pref in series_fields
                startswith(k, pref) && (lc[k] = Float64(v) / zb; break)
            end
            for pref in shunt_fields
                startswith(k, pref) && (lc[k] = Float64(v) * zb; break)
            end
        end
        if haskey(lc, "i_max")
            lc["i_max"] = Float64.(lc["i_max"]) ./ ib
        end
    end
end

function _pu_scale_loads!(net, bases)
    sb = bases.s_base
    for (_, load) in get(net, "load", Dict())
        haskey(load, "p_nom") && (load["p_nom"] = Float64.(load["p_nom"]) ./ sb)
        haskey(load, "q_nom") && (load["q_nom"] = Float64.(load["q_nom"]) ./ sb)
    end
end

function _pu_scale_generators!(net, bases)
    sb = bases.s_base
    for (_, gen) in get(net, "generator", Dict())
        bus = get(gen, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        for f in ("p_min", "p_max", "q_min", "q_max", "s_max")
            haskey(gen, f) && (gen[f] = Float64.(gen[f]) ./ sb)
        end
        if haskey(gen, "i_max")
            gen["i_max"] = Float64.(gen["i_max"]) ./ ib
        end
        # Cost: per-phase linear coefficient $/W in SI → $/PU-W in PU (× s_base)
        # (cost per PU power = cost_si * s_base, since P_pu = P_si/s_base)
        if haskey(gen, "cost")
            c = gen["cost"]
            gen["cost"] = c isa AbstractVector ? Float64.(c) .* sb : Float64(c) * sb
        end
    end
end

function _pu_scale_inverters!(net, bases)
    sb = bases.s_base
    for (_, inv) in get(net, "inverter", Dict())
        inv isa Dict || continue
        for f in ("p_min", "p_max", "q_min", "q_max", "s_max")
            haskey(inv, f) && (inv[f] = Float64.(inv[f]) ./ sb)
        end
        # The power_factor control_profile "pf" field is dimensionless and the
        # PF equality constraint is scale-invariant — nothing to scale here.
        # topology / terminal_map are structural — untouched.
    end
end

function _pu_scale_transformers!(net, bases)
    sb = bases.s_base
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        for (_, xfmr) in get(xfmr_dict, subtype, Dict())
            bf = get(xfmr, "bus_from", "")
            bt = get(xfmr, "bus_to",   "")
            vb_fr = get(bases.v_base, bf, 1.0)
            vb_to = get(bases.v_base, bt, 1.0)
            zb_fr = get(bases.z_base, bf, 1.0)
            zb_to = get(bases.z_base, bt, 1.0)
            ib_fr = get(bases.i_base, bf, 1.0)
            ib_to = get(bases.i_base, bt, 1.0)

            haskey(xfmr, "v_ref_from") && (xfmr["v_ref_from"] = Float64(xfmr["v_ref_from"]) / vb_fr)
            haskey(xfmr, "v_ref_to")   && (xfmr["v_ref_to"]   = Float64(xfmr["v_ref_to"])   / vb_to)
            haskey(xfmr, "s_rating")   && (xfmr["s_rating"]   = Float64(xfmr["s_rating"])   / sb)

            haskey(xfmr, "r_series_from") && (xfmr["r_series_from"] = Float64(xfmr["r_series_from"]) / zb_fr)
            haskey(xfmr, "x_series_from") && (xfmr["x_series_from"] = Float64(xfmr["x_series_from"]) / zb_fr)
            haskey(xfmr, "r_series_to")   && (xfmr["r_series_to"]   = Float64(xfmr["r_series_to"])   / zb_to)
            haskey(xfmr, "x_series_to")   && (xfmr["x_series_to"]   = Float64(xfmr["x_series_to"])   / zb_to)

            # No-load (core-loss) shunt admittance is stamped at the from side, so
            # it scales by the from-bus base. An admittance goes to p.u. by ×z_base
            # (= ÷y_base), the reciprocal of an impedance — without this the core
            # loss silently vanishes in per_unit mode (G in S::S applied to ~1 p.u.
            # voltages ≈ 0).
            haskey(xfmr, "g_no_load") && (xfmr["g_no_load"] = Float64(xfmr["g_no_load"]) * zb_fr)
            haskey(xfmr, "b_no_load") && (xfmr["b_no_load"] = Float64(xfmr["b_no_load"]) * zb_fr)

            # delta_wye: single wye-side impedance; wye bus determines the base
            wye_bus = subtype == "delta_wye" ? bt : bf
            zb_wye  = get(bases.z_base, wye_bus, 1.0)
            haskey(xfmr, "r_series") && (xfmr["r_series"] = Float64(xfmr["r_series"]) / zb_wye)
            haskey(xfmr, "x_series") && (xfmr["x_series"] = Float64(xfmr["x_series"]) / zb_wye)

            if haskey(xfmr, "i_max_from")
                xfmr["i_max_from"] = Float64.(xfmr["i_max_from"]) ./ ib_fr
            end
            if haskey(xfmr, "i_max_to")
                xfmr["i_max_to"] = Float64.(xfmr["i_max_to"]) ./ ib_to
            end
        end
    end
end

function _pu_scale_shunts!(net, bases)
    for (_, sh) in get(net, "shunt", Dict())
        sh isa Dict || continue
        bus = get(sh, "bus", "")
        zb  = get(bases.z_base, bus, 1.0)
        for (k, v) in sh
            (startswith(k, "G_") || startswith(k, "B_")) &&
                (sh[k] = Float64(v) * zb)
        end
    end
end

# ── Conversion from per unit ──────────────────────────────────────────────────

"""
    _from_per_unit(result_pu, bases, net) -> result_si

Scale a per-unit result dict back to SI (V, A, W, var).
`net` is the original SI network dict, used to look up bus membership.
"""
function _from_per_unit(result_pu::Dict{String,Any}, bases, net::Dict{String,Any})
    result = deepcopy(result_pu)
    sb = bases.s_base

    # Bus voltages: vr, vi, vm ← × V_base;  va unchanged
    for (bid, t_dict) in get(result, "bus", Dict())
        vb = get(bases.v_base, bid, 1.0)
        for (_, tvals) in t_dict
            tvals isa Dict || continue
            for f in ("vr", "vi", "vm")
                haskey(tvals, f) && (tvals[f] = tvals[f] * vb)
            end
            # va is an angle — unchanged
        end
    end

    # Initialisation start values: same V_base scaling as solved bus voltages
    for (bid, t_dict) in get(result, "initialisation", Dict())
        vb = get(bases.v_base, bid, 1.0)
        for (_, tvals) in t_dict
            tvals isa Dict || continue
            for f in ("vr_init", "vi_init", "vm_init")
                haskey(tvals, f) && (tvals[f] = tvals[f] * vb)
            end
            # va_init is an angle — unchanged
        end
    end

    # Line currents: ← × I_base[bus_from]
    lines = get(net, "line", Dict())
    for (lid, cond_dict) in get(result, "line", Dict())
        line = get(lines, lid, Dict())
        bf   = get(line, "bus_from", "")
        ib   = get(bases.i_base, bf, 1.0)
        for (tk, cvals) in cond_dict
            cvals isa Dict || continue
            if tk == "ground"          # device ground current (A): × I_base
                for f in ("cg_r", "cg_i", "cgm")
                    haskey(cvals, f) && (cvals[f] = cvals[f] * ib)
                end
                continue
            elseif tk == "loss"        # complex loss (W/var): × s_base
                for f in ("p_loss", "q_loss")
                    haskey(cvals, f) && (cvals[f] = cvals[f] * sb)
                end
                continue
            end
            for f in ("cr_fr", "ci_fr", "cr_to", "ci_to", "cm_fr", "cm_to")
                haskey(cvals, f) && (cvals[f] = cvals[f] * ib)
            end
        end
    end

    # Node-level ground-injection currents: ← × I_base[bus]
    for (bid, t_dict) in get(result, "ground", Dict())
        t_dict isa Dict || continue
        ib = get(bases.i_base, bid, 1.0)
        for (_, gvals) in t_dict
            gvals isa Dict || continue
            for f in ("cg_r", "cg_i", "cgm")
                haskey(gvals, f) && (gvals[f] = gvals[f] * ib)
            end
        end
    end

    # Switch currents: ← × I_base[bus_from]
    switches = get(net, "switch", Dict())
    for (sid, cond_dict) in get(result, "switch", Dict())
        sw = get(switches, sid, Dict())
        bf = get(sw, "bus_from", "")
        ib = get(bases.i_base, bf, 1.0)
        for (_, cvals) in cond_dict
            cvals isa Dict || continue
            for f in ("cr", "ci", "cm")
                haskey(cvals, f) && (cvals[f] = cvals[f] * ib)
            end
        end
    end

    # Load currents and powers
    loads = get(net, "load", Dict())
    for (lid, ph_dict) in get(result, "load", Dict())
        load = get(loads, lid, Dict())
        bus  = get(load, "bus", "")
        ib   = get(bases.i_base, bus, 1.0)
        for (_, lvals) in ph_dict
            lvals isa Dict || continue
            for f in ("crd", "cid")
                haskey(lvals, f) && (lvals[f] = lvals[f] * ib)
            end
            for f in ("pd", "qd")
                haskey(lvals, f) && (lvals[f] = lvals[f] * sb)
            end
        end
    end

    # Generator currents and powers
    gens = get(net, "generator", Dict())
    for (gid, ph_dict) in get(result, "generator", Dict())
        gen = get(gens, gid, Dict())
        bus = get(gen, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        for (_, gvals) in ph_dict
            gvals isa Dict || continue
            for f in ("crg", "cig")
                haskey(gvals, f) && (gvals[f] = gvals[f] * ib)
            end
            for f in ("pg", "qg")
                haskey(gvals, f) && (gvals[f] = gvals[f] * sb)
            end
        end
    end

    # Inverter currents and powers
    invs = get(net, "inverter", Dict())
    for (iid, ph_dict) in get(result, "inverter", Dict())
        inv = get(invs, iid, Dict())
        bus = get(inv, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        for (_, ivals) in ph_dict
            ivals isa Dict || continue
            for f in ("cri", "cii")
                haskey(ivals, f) && (ivals[f] = ivals[f] * ib)
            end
            for f in ("pg", "qg")
                haskey(ivals, f) && (ivals[f] = ivals[f] * sb)
            end
        end
    end

    # Voltage-source slack currents and powers
    sources = get(net, "voltage_source", Dict())
    for (sid, ph_dict) in get(result, "voltage_source", Dict())
        vs  = get(sources, sid, Dict())
        bus = get(vs, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        for (_, svals) in ph_dict
            svals isa Dict || continue
            for f in ("cr", "ci", "cm")
                haskey(svals, f) && (svals[f] = svals[f] * ib)
            end
            for f in ("ps", "qs")
                haskey(svals, f) && (svals[f] = svals[f] * sb)
            end
        end
    end

    # Transformer currents: from-side ← I_base[bus_from], to-side ← I_base[bus_to]
    xfmr_dict = get(net, "transformer", Dict())
    for (tid, winding_dict) in get(result, "transformer", Dict())
        # Find which subtype this transformer belongs to
        xfmr = nothing
        for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
            sub = get(xfmr_dict, subtype, nothing)
            sub isa Dict && haskey(sub, tid) && (xfmr = sub[tid]; break)
        end
        xfmr === nothing && continue
        bf = get(xfmr, "bus_from", ""); bt = get(xfmr, "bus_to", "")
        ib_fr = get(bases.i_base, bf, 1.0)
        ib_to = get(bases.i_base, bt, 1.0)
        for (_, cvals) in get(winding_dict, "fr", Dict())
            cvals isa Dict || continue
            for f in ("cr", "ci", "cm"); haskey(cvals, f) && (cvals[f] = cvals[f] * ib_fr); end
        end
        for (_, cvals) in get(winding_dict, "to", Dict())
            cvals isa Dict || continue
            for f in ("cr", "ci", "cm"); haskey(cvals, f) && (cvals[f] = cvals[f] * ib_to); end
        end
        # Device ground current (A): the no-load shunt is on the from side → I_base[bus_from]
        if haskey(winding_dict, "ground") && winding_dict["ground"] isa Dict
            g = winding_dict["ground"]
            for f in ("cg_r", "cg_i", "cgm"); haskey(g, f) && (g[f] = g[f] * ib_fr); end
        end
        # Complex loss (W/var): × s_base
        if haskey(winding_dict, "loss") && winding_dict["loss"] isa Dict
            l = winding_dict["loss"]
            for f in ("p_loss", "q_loss"); haskey(l, f) && (l[f] = l[f] * sb); end
        end
    end

    # Network-wide loss totals (W/var): × s_base
    if haskey(result, "losses") && result["losses"] isa Dict
        for f in ("p_loss", "q_loss")
            haskey(result["losses"], f) && (result["losses"][f] = result["losses"][f] * sb)
        end
    end

    # Objective: cost_pu * P_pu = (cost_si * s_base) * (P_si / s_base) = cost_si * P_si
    # The s_base factors cancel, so the PU objective is already in SI — no rescaling needed.

    # Feasibility OPF slack injections
    if haskey(result, "slack_injections")
        for (bid, t_dict) in result["slack_injections"]
            ib = get(bases.i_base, bid, 1.0)
            for (_, svals) in t_dict
                svals isa Dict || continue
                for f in ("cs_r", "cs_i", "cs_mag")
                    haskey(svals, f) && (svals[f] = svals[f] * ib)
                end
            end
        end
        # Recompute total slack magnitude in SI
        total_sq = sum(
            v["cs_mag"]^2
            for td in values(result["slack_injections"]) for v in values(td);
            init = 0.0
        )
        result["total_slack_magnitude_A"] = sqrt(total_sq)
    end

    result
end
