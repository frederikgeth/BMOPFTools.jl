# Per-unit scaling for the IVR-EN OPF.
#
# _to_per_unit(net, s_base)  ->  (net_pu, bases)
# _from_per_unit(result, bases) -> result_si
#
# Convention
# ──────────
# A single system MVA base (s_base, VA) is chosen by the caller.
# V_base at the source bus comes from the first voltage source's v_magnitude[1].
# V_base propagates through transformers by the turns ratio N = v_nom_from/v_nom_to:
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
function _compute_classic_bases(net::Dict{String,Any}, s_base::Float64)
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
    # Build adjacency: bus -> [(neighbour_bus, v_nom_from, v_nom_to, from_is_from)]
    xfmr_adj = Dict{String,Vector{Tuple{String,Float64,Float64}}}()
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        subtype in BMOPFTools.WINDING_LIST_SUBTYPES && continue   # handled below
        for (_, xfmr) in get(xfmr_dict, subtype, Dict())
            bf = get(xfmr, "bus_from", "")
            bt = get(xfmr, "bus_to",   "")
            vrf = Float64(get(xfmr, "v_nom_from", 1.0))
            vrt = Float64(get(xfmr, "v_nom_to",   1.0))
            (isempty(bf) || isempty(bt)) && continue
            push!(get!(xfmr_adj, bf, Tuple{String,Float64,Float64}[]), (bt, vrf, vrt))
            push!(get!(xfmr_adj, bt, Tuple{String,Float64,Float64}[]), (bf, vrt, vrf))
        end
    end

    # n-winding: propagate base from winding 1 to every other winding's bus.
    for (_, xfmr) in get(xfmr_dict, "n_winding", Dict())
        ws = BMOPFTools._nw_windings(xfmr)
        isempty(ws) && continue
        b1, v1 = ws[1].bus, ws[1].v_nom
        isempty(b1) && continue
        for j in 2:length(ws)
            bj, vj = ws[j].bus, ws[j].v_nom
            isempty(bj) && continue
            push!(get!(xfmr_adj, b1, Tuple{String,Float64,Float64}[]), (bj, v1, vj))
            push!(get!(xfmr_adj, bj, Tuple{String,Float64,Float64}[]), (b1, vj, v1))
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

    queue = isempty(src_bus) ? String[] : [src_bus]
    visited = isempty(src_bus) ? Set{String}() : Set{String}([src_bus])
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

    # ── DC voltage base ──────────────────────────────────────────────────────
    # A single global DC base is used for every dc_bus: the DC network's
    # fixed-voltage converter (dc_control="V") is its uniqueness anchor, so its
    # set voltage is the natural base; a shared base also keeps DC KCL consistent
    # across dc_branches (per-bus bases would mismatch branch vs converter
    # currents at a terminal). Fallbacks: the largest pole-to-ground nominal,
    # then the pole ceiling. The base is not user-exposed — any O(V_dc) choice
    # removes the v·I port ill-conditioning.
    dc_base = 0.0
    for (_, inv) in get(net, "ibr", Dict())          # 1) fixed-voltage anchor
        inv isa Dict && String(get(inv, "dc_control", "P")) == "V" || continue
        vs = get(inv, "dc_v_set", nothing)
        if vs isa Number && abs(Float64(vs)) > 0
            dc_base = abs(Float64(vs)); break
        end
    end
    if dc_base <= 0                                   # 2) nominal, then 3) ceiling
        for f in ("v_dc_nom", "v_dc_max")
            for (_, dcbus) in get(net, "dc_bus", Dict())
                dcbus isa Dict || continue
                v = Float64.(get(dcbus, f, Float64[]))
                isempty(v) || (dc_base = max(dc_base, maximum(abs, v)))
            end
            dc_base > 0 && break
        end
    end
    dc_base > 0 || (dc_base = 1.0)
    dc_ids    = collect(keys(get(net, "dc_bus", Dict())))
    v_dc_base = Dict(b => dc_base            for b in dc_ids)
    z_dc_base = Dict(b => dc_base^2 / s_base for b in dc_ids)
    i_dc_base = Dict(b => s_base / dc_base   for b in dc_ids)

    (s_base=s_base, v_base=v_base, z_base=z_base, i_base=i_base, y_base=y_base,
     v_dc_base=v_dc_base, z_dc_base=z_dc_base, i_dc_base=i_dc_base)
end

function _scaling_policy_error(component, detail)
    throw(ArgumentError(
        "inconsistent ConsistentPerUnitScaling at $component: $detail. " *
        "The current IVR formulation requires voltage bases to be compatible " *
        "with network connections and derives I=S/V, Z=V^2/S, and Y=S/V^2."))
end

function _check_same_voltage_base(v_base, from_bus, to_bus, component)
    vf = v_base[from_bus]
    vt = v_base[to_bus]
    isapprox(vf, vt; rtol=1e-10, atol=0.0) || _scaling_policy_error(
        component, "connected buses $(repr(from_bus)) and $(repr(to_bus)) " *
                   "have voltage bases $vf V and $vt V")
end

function _check_transformer_voltage_bases(
        v_base, from_bus, to_bus, v_nom_from, v_nom_to, component)
    vf = v_base[from_bus]
    vt = v_base[to_bus]
    nominal_ratio = Float64(v_nom_to) / Float64(v_nom_from)
    actual_ratio = vt / vf
    isfinite(nominal_ratio) && nominal_ratio > 0 || _scaling_policy_error(
        component, "transformer nominal voltages must be positive")
    isapprox(actual_ratio, nominal_ratio; rtol=1e-10, atol=0.0) ||
        _scaling_policy_error(component,
            "voltage-base ratio $actual_ratio does not match nominal turns " *
            "ratio $nominal_ratio between $(repr(from_bus)) and $(repr(to_bus))")
end

function _validate_custom_voltage_bases!(net, v_base)
    expected = Set(String.(keys(get(net, "bus", Dict()))))
    supplied = Set(keys(v_base))
    missing_buses = sort!(collect(setdiff(expected, supplied)))
    extra_buses = sort!(collect(setdiff(supplied, expected)))
    isempty(missing_buses) || throw(ArgumentError(
        "ConsistentPerUnitScaling requires a voltage base for every AC bus; " *
        "missing $(join(repr.(missing_buses), ", "))"))
    isempty(extra_buses) || throw(ArgumentError(
        "ConsistentPerUnitScaling contains unknown AC buses: " *
        join(repr.(extra_buses), ", ")))

    for family in ("line", "switch")
        for (id, component) in get(net, family, Dict())
            from_bus = String(get(component, "bus_from", ""))
            to_bus = String(get(component, "bus_to", ""))
            (isempty(from_bus) || isempty(to_bus)) && continue
            _check_same_voltage_base(
                v_base, from_bus, to_bus, "$family $(repr(id))")
        end
    end

    transformers = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        subtype in BMOPFTools.WINDING_LIST_SUBTYPES && continue
        for (id, transformer) in get(transformers, subtype, Dict())
            from_bus = String(get(transformer, "bus_from", ""))
            to_bus = String(get(transformer, "bus_to", ""))
            (isempty(from_bus) || isempty(to_bus)) && continue
            if subtype in BMOPFTools.GALVANIC_CONTINUOUS_SUBTYPES
                # A regulator/autotransformer contains a literal copper bond
                # between its two bus records.  Its tap changes a winding
                # voltage, not the coordinate scale of that shared conductor.
                # Distinct bus voltage bases would therefore require explicit
                # coefficients in the bond-voltage row and all bond-current KCL
                # injections.  Keep one voltage coordinate throughout the
                # galvanic zone, just as we keep one power/current coordinate.
                _check_same_voltage_base(
                    v_base, from_bus, to_bus,
                    "galvanically continuous transformer/$subtype $(repr(id))")
            else
                _check_transformer_voltage_bases(
                    v_base, from_bus, to_bus,
                    get(transformer, "v_nom_from", 1.0),
                    get(transformer, "v_nom_to", 1.0),
                    "transformer/$subtype $(repr(id))")
            end
        end
    end
    for (id, transformer) in get(transformers, "n_winding", Dict())
        windings = BMOPFTools._nw_windings(transformer)
        length(windings) < 2 && continue
        reference = first(windings)
        for winding in Iterators.drop(windings, 1)
            _check_transformer_voltage_bases(
                v_base, reference.bus, winding.bus,
                reference.v_nom, winding.v_nom,
                "transformer/n_winding $(repr(id))")
        end
    end
    return v_base
end

function _compute_bases(
        net::Dict{String,Any}, policy::BMOPFTools.ClassicPerUnitScaling)
    bases = _compute_classic_bases(net, policy.s_base)
    s_base_bus = Dict(bus => policy.s_base for bus in keys(bases.v_base))
    return (; bases..., s_base_bus=s_base_bus, s_dc_base=policy.s_base,
            scaling_policy=policy)
end

function _compute_bases(
        net::Dict{String,Any}, policy::BMOPFTools.ConsistentPerUnitScaling)
    v_base = copy(policy.voltage_bases)
    _validate_custom_voltage_bases!(net, v_base)
    sb = policy.s_base
    z_base = Dict(bus => base^2 / sb for (bus, base) in v_base)
    i_base = Dict(bus => sb / base for (bus, base) in v_base)
    y_base = Dict(bus => sb / base^2 for (bus, base) in v_base)

    classic = _compute_classic_bases(net, sb)
    dc_base = policy.dc_voltage_base
    dc_base === nothing && !isempty(classic.v_dc_base) &&
        (dc_base = first(values(classic.v_dc_base)))
    dc_ids = String.(collect(keys(get(net, "dc_bus", Dict()))))
    v_dc_base = Dict(bus => dc_base::Float64 for bus in dc_ids)
    z_dc_base = Dict(bus => dc_base^2 / sb for bus in dc_ids)
    i_dc_base = Dict(bus => sb / dc_base for bus in dc_ids)

    s_base_bus = Dict(bus => sb for bus in keys(v_base))
    return (s_base=sb, s_base_bus=s_base_bus, v_base=v_base,
            z_base=z_base, i_base=i_base,
            y_base=y_base, v_dc_base=v_dc_base, z_dc_base=z_dc_base,
            i_dc_base=i_dc_base, s_dc_base=sb, scaling_policy=policy)
end

_ac_power_base(bases, bus) = Float64(get(bases.s_base_bus, String(bus), bases.s_base))
_dc_power_base(bases) = Float64(bases.s_dc_base)

function _validate_zone_power_bases!(net, power_bases)
    expected = Set(String.(keys(get(net, "bus", Dict()))))
    supplied = Set(keys(power_bases))
    missing_buses = sort!(collect(setdiff(expected, supplied)))
    extra_buses = sort!(collect(setdiff(supplied, expected)))
    isempty(missing_buses) || throw(ArgumentError(
        "ZonePerUnitScaling requires a power base for every AC bus; missing " *
        join(repr.(missing_buses), ", ")))
    isempty(extra_buses) || throw(ArgumentError(
        "ZonePerUnitScaling contains unknown AC buses: " * join(repr.(extra_buses), ", ")))

    for zone in BMOPFTools._galvanic_zones(net)
        buses = sort!(String.(collect(zone)))
        zone_values = unique(power_bases[bus] for bus in buses)
        length(zone_values) == 1 || throw(ArgumentError(
            "ZonePerUnitScaling power bases must be constant inside a " *
            "galvanically continuous zone; buses $(join(repr.(buses), ", ")) " *
            "use bases $(sort!(collect(zone_values))) VA"))
    end

    # Cross-zone current/power coefficients are qualified for ordinary isolated
    # single-phase, center-tap, three-phase Y/Delta, and general n-winding
    # transformers. Other isolated
    # connections need their own connection-matrix covariance tests before local
    # bases are safe.
    transformers = get(net, "transformer", Dict())
    qualified = Set((
        "single_phase", "center_tap", "wye_delta", "delta_wye", "n_winding",
    ))
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        subtype in qualified && continue
        for (id, transformer) in get(transformers, subtype, Dict())
            from, to = BMOPFTools._xfmr_from_to_buses(subtype, transformer)
            isempty(from) && continue
            sf = power_bases[first(from)]
            any(bus -> !isapprox(power_bases[bus], sf; rtol=1e-12, atol=0.0), to) ||
                continue
            throw(ArgumentError(
                "ZonePerUnitScaling does not yet qualify a local power-base " *
                "change across transformer/$subtype $(repr(id)); currently " *
                "supported across isolated single_phase, center_tap, " *
                "wye_delta, delta_wye, and n_winding transformers only"))
        end
    end

    return power_bases
end

function _compute_bases(
        net::Dict{String,Any}, policy::BMOPFTools.ZonePerUnitScaling)
    v_base = copy(policy.voltage_bases)
    s_base_bus = copy(policy.power_bases)
    _validate_custom_voltage_bases!(net, v_base)
    _validate_zone_power_bases!(net, s_base_bus)
    z_base = Dict(bus => v_base[bus]^2 / s_base_bus[bus] for bus in keys(v_base))
    i_base = Dict(bus => s_base_bus[bus] / v_base[bus] for bus in keys(v_base))
    y_base = Dict(bus => s_base_bus[bus] / v_base[bus]^2 for bus in keys(v_base))

    reference = maximum(values(s_base_bus); init=1.0)
    classic = _compute_classic_bases(net, reference)
    dc_voltage = policy.dc_voltage_base
    dc_voltage === nothing && !isempty(classic.v_dc_base) &&
        (dc_voltage = first(values(classic.v_dc_base)))
    dc_voltage === nothing && (dc_voltage = 1.0)
    dc_power = something(policy.dc_power_base, reference)
    dc_ids = String.(collect(keys(get(net, "dc_bus", Dict()))))
    v_dc_base = Dict(bus => dc_voltage for bus in dc_ids)
    z_dc_base = Dict(bus => dc_voltage^2 / dc_power for bus in dc_ids)
    i_dc_base = Dict(bus => dc_power / dc_voltage for bus in dc_ids)

    return (s_base=reference, s_base_bus=s_base_bus, v_base=v_base,
            z_base=z_base, i_base=i_base, y_base=y_base,
            v_dc_base=v_dc_base, z_dc_base=z_dc_base,
            i_dc_base=i_dc_base, s_dc_base=dc_power,
            scaling_policy=policy)
end

_compute_bases(net::Dict{String,Any}, s_base::Float64) =
    _compute_bases(net, BMOPFTools.ClassicPerUnitScaling(s_base))

# ── Conversion to per unit ────────────────────────────────────────────────────

"""
    _to_per_unit(net, s_base) -> (net_pu, bases)

Return a deep copy of `net` with all numerical fields scaled to per unit,
plus the `bases` NamedTuple produced by `_compute_bases`. The original `net`
is never mutated.
"""
function _to_per_unit(
        net::Dict{String,Any}, policy::BMOPFTools.AbstractOpfScalingPolicy)
    policy isa BMOPFTools.SIUnitsScaling && throw(ArgumentError(
        "SIUnitsScaling does not define a per-unit transformation"))
    bases  = _compute_bases(net, policy)
    net_pu = deepcopy(net)
    _pu_scale_buses!(net_pu, bases)
    _pu_scale_sources!(net_pu, bases)
    _pu_scale_linecodes!(net_pu, bases)
    _pu_scale_loads!(net_pu, bases)
    _pu_scale_generators!(net_pu, bases)
    _pu_scale_ibrs!(net_pu, bases)
    _pu_scale_transformers!(net_pu, bases)
    _pu_scale_nwinding!(net_pu, bases)
    _pu_scale_shunts!(net_pu, bases)
    _pu_scale_capacitors!(net_pu, bases)
    _pu_scale_switches!(net_pu, bases)
    _pu_scale_dc!(net_pu, bases)
    net_pu, bases
end

_to_per_unit(net::Dict{String,Any}, s_base::Float64) =
    _to_per_unit(net, BMOPFTools.ClassicPerUnitScaling(s_base))

# Switches are ideal (no impedance), so only the per-conductor current limit
# needs scaling — by the from-bus current base, like a line's i_max. Without
# this the current variables are p.u. but i_max stays in A, leaving the thermal
# cap ~I_base too loose.
function _pu_scale_switches!(net, bases)
    for (_, sw) in get(net, "switch", Dict())
        sw isa Dict || continue
        sb = _ac_power_base(bases, get(sw, "bus_from", ""))
        if haskey(sw, "i_max")
            ib = get(bases.i_base, get(sw, "bus_from", ""), 1.0)
            sw["i_max"] = Float64.(sw["i_max"]) ./ ib
        end
        # s_max is an apparent power → divide by the system VA base.
        if haskey(sw, "s_max")
            sw["s_max"] = Float64.(sw["s_max"]) ./ sb
        end
    end
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
    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", "")
        vb  = get(v_base, bus, 1.0)
        sb  = _ac_power_base(bases, bus)
        if haskey(vs, "v_magnitude")
            vs["v_magnitude"] = Float64.(vs["v_magnitude"]) ./ vb
        end
        # v_angle is in radians — unchanged

        # Optional flow bounds: W/var → PU (divide by s_base)
        for f in ("p_min", "p_max", "q_min", "q_max")
            haskey(vs, f) && (vs[f] = Float64.(vs[f]) ./ sb)
        end
        # Cost: $/kWh price is multiplied by s_base because the objective uses
        # P_pu; _phase_cost then applies the W→kW factor (1/1000).
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
    #
    # A linecode may legally be shared by lines at *different* voltage levels;
    # scaling it with a single z_base would silently corrupt the impedances of
    # every other level. Detect that case and split: the first z_base keeps
    # the original id, each further z_base gets a cloned linecode (this runs
    # on the OPF's working copy, so the user's dict is untouched).
    lc_zbase = Dict{String,Float64}()
    lc_ibase = Dict{String,Float64}()
    lc_sbase = Dict{String,Float64}()
    linecodes = get(net, "linecode", Dict())
    clone_of = Dict{Tuple{String,Float64,Float64,Float64},String}()
    for (_, line) in get(net, "line", Dict())
        lcid = get(line, "linecode", nothing)
        lcid === nothing && continue
        bus = get(line, "bus_from", "")
        zb  = get(bases.z_base, bus, 1.0)
        ib  = get(bases.i_base, bus, 1.0)
        if !haskey(lc_zbase, lcid)
            lc_zbase[lcid] = zb
            lc_ibase[lcid] = ib
            lc_sbase[lcid] = _ac_power_base(bases, bus)
        elseif !isapprox(lc_zbase[lcid], zb; rtol=1e-9) ||
               !isapprox(lc_ibase[lcid], ib; rtol=1e-9) ||
               !isapprox(lc_sbase[lcid], _ac_power_base(bases, bus); rtol=1e-9)
            sb = _ac_power_base(bases, bus)
            new_id = get!(clone_of, (String(lcid), zb, ib, sb)) do
                nid = string(lcid, "__zbase", length(clone_of) + 1)
                haskey(linecodes, lcid) && (linecodes[nid] = deepcopy(linecodes[lcid]))
                lc_zbase[nid] = zb
                lc_ibase[nid] = ib
                lc_sbase[nid] = _ac_power_base(bases, bus)
                nid
            end
            line["linecode"] = new_id
        end
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
        # s_max is an apparent power → divide by the system VA base (not i_base).
        if haskey(lc, "s_max")
            # A line remains inside one galvanic zone, so either terminal's
            # local power base is the same.
            lc["s_max"] = Float64.(lc["s_max"]) ./
                get(lc_sbase, lcid, bases.s_base)
        end
    end

    # Inline ABSOLUTE matrices on lines (Ω, S — never length-scaled) use the
    # same z_base as the line's buses; line-level i_max (rating override /
    # inline-line rating) scales by the current base. Same scaling laws as
    # linecodes — absolute vs per-metre makes no difference to per-unit.
    for (_, line) in get(net, "line", Dict())
        bus = get(line, "bus_from", "")
        zb  = get(bases.z_base, bus, 1.0)
        ib  = get(bases.i_base, bus, 1.0)
        if BMOPFTools._line_has_inline_z(line)
            for (k, v) in line
                v isa Number || continue
                for pref in series_fields
                    startswith(k, pref) && (line[k] = Float64(v) / zb; break)
                end
                for pref in shunt_fields
                    startswith(k, pref) && (line[k] = Float64(v) * zb; break)
                end
            end
        end
        if haskey(line, "i_max")
            line["i_max"] = Float64.(line["i_max"]) ./ ib
        end
        # s_max is an apparent power → divide by the system VA base (not i_base).
        if haskey(line, "s_max")
            line["s_max"] = Float64.(line["s_max"]) ./
                _ac_power_base(bases, bus)
        end
    end
end

function _pu_scale_loads!(net, bases)
    for (_, load) in get(net, "load", Dict())
        sb = _ac_power_base(bases, get(load, "bus", ""))
        haskey(load, "p_nom") && (load["p_nom"] = Float64.(load["p_nom"]) ./ sb)
        haskey(load, "q_nom") && (load["q_nom"] = Float64.(load["q_nom"]) ./ sb)
        # v_nom is the load's line-to-neutral reference voltage; the ZIP and
        # exponential models evaluate (V/v_nom), so it must move to per-unit with
        # the bus voltage base.  Without this the voltage-dependent terms compare
        # a per-unit V (≈1) against an SI v_nom (≈240) and the solve goes
        # infeasible.  (Constant-power loads ignore v_nom, hence only ZIP/exp
        # were affected.)
        if haskey(load, "v_nom")
            vb = get(bases.v_base, get(load, "bus", ""), 1.0)
            load["v_nom"] = Float64.(load["v_nom"]) ./ vb
        end
    end
end

function _pu_scale_generators!(net, bases)
    for (_, gen) in get(net, "generator", Dict())
        bus = get(gen, "bus", "")
        sb  = _ac_power_base(bases, bus)
        ib  = get(bases.i_base, bus, 1.0)
        for f in ("p_min", "p_max", "q_min", "q_max", "s_max")
            haskey(gen, f) && (gen[f] = Float64.(gen[f]) ./ sb)
        end
        if haskey(gen, "i_max")
            gen["i_max"] = Float64.(gen["i_max"]) ./ ib
        end
        # Cost: $/kWh price is multiplied by s_base because P_pu = P_si/s_base;
        # _phase_cost applies the remaining W→kW factor (1/1000).
        if haskey(gen, "cost")
            c = gen["cost"]
            gen["cost"] = c isa AbstractVector ? Float64.(c) .* sb : Float64(c) * sb
        end
    end
end

function _pu_scale_ibrs!(net, bases)
    for (_, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        bus = get(inv, "bus", "")
        sb  = _ac_power_base(bases, bus)
        ib  = get(bases.i_base, bus, 1.0)
        for f in ("p_min", "p_max", "q_min", "q_max", "s_max")
            haskey(inv, f) && (inv[f] = Float64.(inv[f]) ./ sb)
        end
        if haskey(inv, "dc_bus")
            # The AC and DC ports may use distinct power coordinates.  The
            # physical lossless balance Sdc*Udc*Idc = Sac*Pac therefore becomes
            # Udc*Idc = (Sac/Sdc)*Pac in working coordinates.
            sdc = _dc_power_base(bases)
            inv["_ac_power_base"] = sb
            inv["_dc_power_base"] = sdc
            inv["_ac_to_dc_power_factor"] = sb / sdc
        end
        # DC-link net active-power bounds are scalars (Σ over phases); scale by sb.
        for f in ("p_dc_min", "p_dc_max")
            haskey(inv, f) && (inv[f] = Float64(inv[f]) / sb)
        end
        # Current-magnitude limit scales by the per-bus current base (mirrors
        # _pu_scale_generators!), since the OPF current variables cri/cii are PU.
        haskey(inv, "i_max") && (inv["i_max"] = Float64.(inv["i_max"]) ./ ib)
        # The power_factor control_profile "pf" field is dimensionless and the
        # PF equality constraint is scale-invariant — nothing to scale here.
        # topology / terminal_map are structural — untouched.
        # Cost follows the same scaling as generator/source cost. Omitting this
        # would change both the objective value and the merit order in PU mode.
        if haskey(inv, "cost")
            c = inv["cost"]
            inv["cost"] = c isa AbstractVector ? Float64.(c) .* sb : Float64(c) * sb
        end
    end
end

function _pu_scale_transformers!(net, bases)
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        subtype in BMOPFTools.WINDING_LIST_SUBTYPES && continue  # see _pu_scale_nwinding!
        for (_, xfmr) in get(xfmr_dict, subtype, Dict())
            bf = get(xfmr, "bus_from", "")
            bt = get(xfmr, "bus_to",   "")
            vb_fr = get(bases.v_base, bf, 1.0)
            vb_to = get(bases.v_base, bt, 1.0)
            zb_fr = get(bases.z_base, bf, 1.0)
            zb_to = get(bases.z_base, bt, 1.0)
            ib_fr = get(bases.i_base, bf, 1.0)
            ib_to = get(bases.i_base, bt, 1.0)
            sb_fr = _ac_power_base(bases, bf)
            sb_to = _ac_power_base(bases, bt)

            # Preserve the side-base contract on the working transformer. The
            # ordinary two-winding current equation is expressed in to-side
            # current coordinates, so its from-side coefficient is S_fr/S_to.
            xfmr["_s_base_from"] = sb_fr
            xfmr["_s_base_to"] = sb_to
            xfmr["_current_coupling_from_factor"] = sb_fr / sb_to
            if subtype == "wye_delta"
                xfmr["_delta_to_wye_power_factor"] = sb_to / sb_fr
                xfmr["_wye_to_delta_power_factor"] = sb_fr / sb_to
            elseif subtype == "delta_wye"
                xfmr["_delta_to_wye_power_factor"] = sb_fr / sb_to
                xfmr["_wye_to_delta_power_factor"] = sb_to / sb_fr
            end

            haskey(xfmr, "v_nom_from") && (xfmr["v_nom_from"] = Float64(xfmr["v_nom_from"]) / vb_fr)
            haskey(xfmr, "v_nom_to")   && (xfmr["v_nom_to"]   = Float64(xfmr["v_nom_to"])   / vb_to)
            if haskey(xfmr, "s_rating")
                rating = Float64(xfmr["s_rating"])
                xfmr["_s_rating_from_pu"] = rating / sb_fr
                xfmr["_s_rating_to_pu"] = rating / sb_to
                # Existing builders enforce the from-side coil nameplate.
                xfmr["s_rating"] = xfmr["_s_rating_from_pu"]
            end

            haskey(xfmr, "r_series_from") && (xfmr["r_series_from"] = Float64(xfmr["r_series_from"]) / zb_fr)
            haskey(xfmr, "x_series_from") && (xfmr["x_series_from"] = Float64(xfmr["x_series_from"]) / zb_fr)
            haskey(xfmr, "r_series_to")   && (xfmr["r_series_to"]   = Float64(xfmr["r_series_to"])   / zb_to)
            haskey(xfmr, "x_series_to")   && (xfmr["x_series_to"]   = Float64(xfmr["x_series_to"])   / zb_to)

            # Winding neutral impedance (rneut/xneut): same side-base scaling as
            # the series leakage.
            haskey(xfmr, "r_neutral_from") && (xfmr["r_neutral_from"] = Float64(xfmr["r_neutral_from"]) / zb_fr)
            haskey(xfmr, "x_neutral_from") && (xfmr["x_neutral_from"] = Float64(xfmr["x_neutral_from"]) / zb_fr)
            haskey(xfmr, "r_neutral_to")   && (xfmr["r_neutral_to"]   = Float64(xfmr["r_neutral_to"])   / zb_to)
            haskey(xfmr, "x_neutral_to")   && (xfmr["x_neutral_to"]   = Float64(xfmr["x_neutral_to"])   / zb_to)

            # No-load (magnetising) shunt admittance is stamped across the
            # winding-2 (to-side) coil, so it scales by the TO-bus base. An
            # admittance goes to p.u. by ×z_base (= ÷y_base), the reciprocal of
            # an impedance — without this the core loss silently vanishes in
            # per_unit mode (G in S applied to ~1 p.u. voltages ≈ 0).
            haskey(xfmr, "g_no_load") && (xfmr["g_no_load"] = Float64(xfmr["g_no_load"]) * zb_to)
            haskey(xfmr, "b_no_load") && (xfmr["b_no_load"] = Float64(xfmr["b_no_load"]) * zb_to)

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

# n-winding transformers: an independent per-unit pass. The OPF leakage is the
# ZB matrix referred to winding 1, so it converts to p.u. with a single divide by
# z_base(bus_1); the result is stashed as `_zb_re`/`_zb_im` (read by
# `_nw_zb_for_opf`). Each referred current carries S_base(winding)/S_base(1),
# recorded in `_ampere_turn_power_factors`. v_nom is scaled per winding bus so
# N_j stays the off-nominal ratio; the no-load shunt (across winding 2's coil)
# scales by ×z_base(bus_2); per-winding i_max by ÷i_base(winding bus); s_rating
# by ÷s_base(winding 1).
function _pu_scale_nwinding!(net, bases)
    for (_, xfmr) in get(get(net, "transformer", Dict()), "n_winding", Dict())
        xfmr isa Dict || continue
        raw = get(xfmr, "windings", nothing)
        raw isa AbstractVector && !isempty(raw) || continue

        ws  = BMOPFTools._nw_windings(xfmr)
        sb1 = _ac_power_base(bases, ws[1].bus)
        xfmr["_ampere_turn_power_factors"] = [
            _ac_power_base(bases, w.bus) / sb1 for w in ws
        ]
        ZB  = BMOPFTools._nw_zb_matrix(xfmr)                     # SI, ref-1 base
        zb1 = get(bases.z_base, ws[1].bus, 1.0)
        ZBpu = ZB ./ zb1
        m = size(ZBpu, 1)
        xfmr["_zb_re"] = [[real(ZBpu[i, j]) for j in 1:m] for i in 1:m]
        xfmr["_zb_im"] = [[imag(ZBpu[i, j]) for j in 1:m] for i in 1:m]

        # v_nom is divided by the winding's bus base (line-to-neutral). For a DELTA
        # winding v_nom is the line-to-line coil voltage, so v_nom_pu ≈ √3 — exactly
        # the √3 that cancels the line-to-line node-voltage difference the delta coil
        # spans, leaving U_k^r consistent. No delta-specific scaling is needed.
        for (j, w) in enumerate(raw)
            w isa AbstractDict || continue
            vbj = get(bases.v_base, ws[j].bus, 1.0)
            haskey(w, "v_nom") && (w["v_nom"] = Float64(w["v_nom"]) / vbj)
            # Per-winding current limit → p.u. by ÷ i_base of the winding's bus.
            if haskey(w, "i_max")
                ibj = get(bases.i_base, ws[j].bus, 1.0)
                w["i_max"] = Float64(w["i_max"]) / ibj
            end
            # Per-winding apparent-power rating → p.u. by ÷ s_base.
            if haskey(w, "s_max")
                w["s_max"] = Float64(w["s_max"]) /
                    _ac_power_base(bases, ws[j].bus)
            end
        end

        haskey(xfmr, "s_rating") &&
            (xfmr["s_rating"] = Float64(xfmr["s_rating"]) / sb1)
        # The no-load shunt is stamped across WINDING 2's coil, so it converts to
        # p.u. by ×z_base of winding 2's bus (an admittance scales by ×z_base).
        zb2 = length(ws) >= 2 ? get(bases.z_base, ws[2].bus, 1.0) : zb1
        haskey(xfmr, "g_no_load") && (xfmr["_g_no_load_pu"] = Float64(xfmr["g_no_load"]) * zb2)
        haskey(xfmr, "b_no_load") && (xfmr["_b_no_load_pu"] = Float64(xfmr["b_no_load"]) * zb2)
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

# Capacitors: the OPF derives B = q_rated/v_nom² in the builder, so scaling
# q_rated by s_base and v_nom by the bus voltage base makes the derived B come
# out in per-unit automatically:  (q/s_base)/(v_nom/v_base)² = B_SI · z_base.
function _pu_scale_dc!(net, bases)
    haskey(net, "dc_bus") || return
    sb  = _dc_power_base(bases)
    vdb = bases.v_dc_base; zdb = bases.z_dc_base; idb = bases.i_dc_base

    # dc_bus voltage fields (per-terminal vectors v_dc_*, scalar pair bounds).
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        vb = get(vdb, b, 1.0)
        for f in ("v_dc_min", "v_dc_max", "v_dc_nom")
            haskey(dcbus, f) && (dcbus[f] = Float64.(dcbus[f]) ./ vb)
        end
        for f in ("vdc_ln_min", "vdc_ln_max", "vdc_ll_min", "vdc_ll_max")
            haskey(dcbus, f) && (dcbus[f] = Float64(dcbus[f]) / vb)
        end
    end

    # Constant-power DC loads / sources (W → pu).
    for (_, l) in get(net, "dc_load", Dict())
        l isa Dict && haskey(l, "p") && (l["p"] = Float64(l["p"]) / sb)
    end
    for (_, s) in get(net, "dc_source", Dict())
        s isa Dict || continue
        for f in ("p", "p_min", "p_max")
            haskey(s, f) && (s[f] = Float64(s[f]) / sb)
        end
    end

    # dc_branch: r (Ω → pu via the from-bus Z base), i_max (A → pu), p_max (W → pu).
    for (_, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        bf = String(get(br, "dc_bus_from", ""))
        zb = get(zdb, bf, 1.0); ib = get(idb, bf, 1.0)
        haskey(br, "r")     && (br["r"]     = Float64.(br["r"]) ./ zb)
        haskey(br, "i_max") && (br["i_max"] = Float64.(br["i_max"]) ./ ib)
        haskey(br, "p_max") && (br["p_max"] = Float64(br["p_max"]) / sb)
    end

    # Resistive DC grounding (Ω → pu). Perfect grounds (r ≤ 0) stay ≤ 0.
    for (_, gr) in get(net, "dc_grounding", Dict())
        gr isa Dict || continue
        zb = get(zdb, String(get(gr, "dc_bus", "")), 1.0)
        haskey(gr, "r") && (gr["r"] = Float64(gr["r"]) / zb)
    end

    # Converter DC-control fields on each IBR referencing a dc_bus.
    #   dc_v_set, dc_deadband : volts → /v_dc_base
    #   dc_p_ref              : watts → /the converter AC power base
    #   dc_droop k (V/W)      : P = p_ref + (v − v_set)/k
    #                            ⇒ k_pu = k·S_ac/V_dc_base
    # Droop is an AC active-power control law even though its independent
    # variable is a DC voltage.  Scaling these fields by S_dc would silently
    # change the controller whenever S_ac != S_dc.
    for (_, inv) in get(net, "ibr", Dict())
        inv isa Dict && haskey(inv, "dc_bus") || continue
        vb = get(vdb, String(inv["dc_bus"]), 1.0)
        sac = _ac_power_base(bases, String(get(inv, "bus", "")))
        haskey(inv, "dc_v_set")    && (inv["dc_v_set"]    = Float64(inv["dc_v_set"]) / vb)
        haskey(inv, "dc_deadband") && (inv["dc_deadband"] = Float64(inv["dc_deadband"]) / vb)
        haskey(inv, "dc_p_ref")    && (inv["dc_p_ref"]    = Float64(inv["dc_p_ref"]) / sac)
        haskey(inv, "dc_droop")    && (inv["dc_droop"]    = Float64(inv["dc_droop"]) * sac / vb)
    end
end

function _pu_scale_capacitors!(net, bases)
    for (_, cap) in get(net, "capacitor", Dict())
        cap isa Dict || continue
        bus = get(cap, "bus", "")
        vb  = get(bases.v_base, bus, 1.0)
        sb  = _ac_power_base(bases, bus)
        haskey(cap, "q_rated") && (cap["q_rated"] = Float64.(cap["q_rated"]) ./ sb)
        haskey(cap, "v_nom") && (cap["v_nom"] = Float64(cap["v_nom"]) / vb)
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
            elseif tk == "loss"        # complex loss + throughput (W/var/VA): × s_base
                for f in ("p_loss", "q_loss", "s_through")
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
        sb_local = _ac_power_base(bases, bus)
        for (_, lvals) in ph_dict
            lvals isa Dict || continue
            for f in ("crd", "cid")
                haskey(lvals, f) && (lvals[f] = lvals[f] * ib)
            end
            for f in ("pd", "qd")
                haskey(lvals, f) && (lvals[f] = lvals[f] * sb_local)
            end
        end
    end

    # Generator currents and powers
    gens = get(net, "generator", Dict())
    for (gid, ph_dict) in get(result, "generator", Dict())
        gen = get(gens, gid, Dict())
        bus = get(gen, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        sb_local = _ac_power_base(bases, bus)
        for (_, gvals) in ph_dict
            gvals isa Dict || continue
            for f in ("crg", "cig")
                haskey(gvals, f) && (gvals[f] = gvals[f] * ib)
            end
            for f in ("pg", "qg")
                haskey(gvals, f) && (gvals[f] = gvals[f] * sb_local)
            end
        end
    end

    # IBR currents and powers
    invs = get(net, "ibr", Dict())
    for (iid, ph_dict) in get(result, "ibr", Dict())
        inv = get(invs, iid, Dict())
        bus = get(inv, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        sb_local = _ac_power_base(bases, bus)
        for (_, ivals) in ph_dict
            ivals isa Dict || continue
            for f in ("cri", "cii")
                haskey(ivals, f) && (ivals[f] = ivals[f] * ib)
            end
            for f in ("pg", "qg")
                haskey(ivals, f) && (ivals[f] = ivals[f] * sb_local)
            end
        end
        if haskey(inv, "dc_bus") && haskey(ph_dict, "dc_port") &&
                ph_dict["dc_port"] isa Dict
            dc_bus = String(inv["dc_bus"])
            dc = ph_dict["dc_port"]
            vdb = get(bases.v_dc_base, dc_bus, 1.0)
            idb = get(bases.i_dc_base, dc_bus, 1.0)
            haskey(dc, "v_dc") && (dc["v_dc"] = dc["v_dc"] * vdb)
            haskey(dc, "i_dc") && (dc["i_dc"] = dc["i_dc"] * idb)
            haskey(dc, "p_dc") &&
                (dc["p_dc"] = dc["p_dc"] * _dc_power_base(bases))
        end
    end

    # Voltage-source slack currents and powers
    sources = get(net, "voltage_source", Dict())
    for (sid, ph_dict) in get(result, "voltage_source", Dict())
        vs  = get(sources, sid, Dict())
        bus = get(vs, "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        sb_local = _ac_power_base(bases, bus)
        for (_, svals) in ph_dict
            svals isa Dict || continue
            for f in ("cr", "ci", "cm")
                haskey(svals, f) && (svals[f] = svals[f] * ib)
            end
            for f in ("ps", "qs")
                haskey(svals, f) && (svals[f] = svals[f] * sb_local)
            end
        end
    end

    # Capacitor banks: per-terminal currents ← × I_base[bus]; delivered q ← × s_base
    caps = get(net, "capacitor", Dict())
    for (cid, cvals) in get(result, "capacitor", Dict())
        cvals isa Dict || continue
        bus = get(get(caps, cid, Dict()), "bus", "")
        ib  = get(bases.i_base, bus, 1.0)
        sb_local = _ac_power_base(bases, bus)
        term_d = get(cvals, "terminals", Dict())
        if term_d isa Dict
            for (_, tvals) in term_d
                tvals isa Dict || continue
                for f in ("cr", "ci", "cm")
                    haskey(tvals, f) && (tvals[f] = tvals[f] * ib)
                end
            end
        end
        haskey(cvals, "q") && (cvals["q"] = cvals["q"] * sb_local)
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
        sb_fr = _ac_power_base(bases, bf)
        sb_to = _ac_power_base(bases, bt)
        for (_, cvals) in get(winding_dict, "fr", Dict())
            cvals isa Dict || continue
            for f in ("cr", "ci", "cm"); haskey(cvals, f) && (cvals[f] = cvals[f] * ib_fr); end
            for f in ("s", "s_max"); haskey(cvals, f) && (cvals[f] = cvals[f] * sb_fr); end
        end
        for (_, cvals) in get(winding_dict, "to", Dict())
            cvals isa Dict || continue
            for f in ("cr", "ci", "cm"); haskey(cvals, f) && (cvals[f] = cvals[f] * ib_to); end
            for f in ("s", "s_max"); haskey(cvals, f) && (cvals[f] = cvals[f] * sb_to); end
        end
        # Device ground current was assembled in from-side current coordinates.
        if haskey(winding_dict, "ground") && winding_dict["ground"] isa Dict
            g = winding_dict["ground"]
            for f in ("cg_r", "cg_i", "cgm"); haskey(g, f) && (g[f] = g[f] * ib_fr); end
        end
        # Complex loss + throughput (W/var/VA): × s_base
        if haskey(winding_dict, "loss") && winding_dict["loss"] isa Dict
            l = winding_dict["loss"]
            for f in ("p_loss", "q_loss", "s_through"); haskey(l, f) && (l[f] = l[f] * sb); end
        end
    end

    # n-winding transformer winding currents ("w1".."wN") ← × I_base[winding bus].
    # Keyed by "w\$j" (not "fr"/"to"), so the loop above skips them; unscale here
    # with the same per-winding base that _pu_scale_nwinding! used for i_max.
    nw_dict = get(xfmr_dict, "n_winding", Dict())
    for (tid, winding_dict) in get(result, "transformer", Dict())
        (winding_dict isa Dict && haskey(nw_dict, tid)) || continue
        for (j, w) in enumerate(BMOPFTools._nw_windings(nw_dict[tid]))
            wd = get(winding_dict, "w$j", nothing)
            wd isa Dict || continue
            ib = get(bases.i_base, w.bus, 1.0)
            sb_local = _ac_power_base(bases, w.bus)
            for (_, cvals) in wd
                cvals isa Dict || continue
                for f in ("cr", "ci", "cm")
                    haskey(cvals, f) && (cvals[f] = cvals[f] * ib)
                end
                for f in ("s", "s_max"); haskey(cvals, f) && (cvals[f] = cvals[f] * sb_local); end
            end
        end
    end

    # DC bus voltages: v_dc ← × V_dc_base
    for (b, t_dict) in get(result, "dc_bus", Dict())
        t_dict isa Dict || continue
        vb = get(bases.v_dc_base, b, 1.0)
        for (_, tvals) in t_dict
            tvals isa Dict || continue
            haskey(tvals, "v_dc") && (tvals["v_dc"] = tvals["v_dc"] * vb)
        end
    end

    # DC branch currents: i_dc ← × I_dc_base[dc_bus_from]
    dc_branches = get(net, "dc_branch", Dict())
    for (id, cond_dict) in get(result, "dc_branch", Dict())
        cond_dict isa Dict || continue
        bf = String(get(get(dc_branches, id, Dict()), "dc_bus_from", ""))
        ib = get(bases.i_dc_base, bf, 1.0)
        for (_, cvals) in cond_dict
            cvals isa Dict || continue
            haskey(cvals, "i_dc") && (cvals["i_dc"] = cvals["i_dc"] * ib)
        end
    end

    # Network-wide loss totals (W/var): × s_base
    if haskey(result, "losses") && result["losses"] isa Dict
        for f in ("p_loss", "q_loss")
            haskey(result["losses"], f) && (result["losses"][f] = result["losses"][f] * sb)
        end
    end

    # Default OPF objective cost rate: (cost_kWh * s_base / 1000) * P_pu
    # = cost_kWh * P_si / 1000 ($/h). The s_base factors cancel, so this
    # objective is already in the same $/h units as the SI solve. A feasibility
    # OPF's raw objective instead remains a working-coordinate slack metric; its
    # physically interpretable slack fields are converted below.

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
