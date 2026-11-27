# Resolved control rules of an inverter-based resource (IBR).
#
# One reading of an IBR record, shared by the OPF/PF builder (the JuMP
# extension) and by the profiler: how many coils the device has and between
# which terminals, which control law is active once precedence is applied,
# what each law's normalization base is, and how the DC side couples the coils.
# The builder stamps constraints from these rules; the profiler reasons about
# the same rules without a model. Neither re-derives the other.
#
# Everything here is plain data in SI units. The builder scales to per-unit and
# may replace a coefficient by a live parameter; that is its own business.

"""
    _ibr_coil_count(inv, nlabels) -> Int

Number of independently controlled coils of an IBR, which is also the number of
current variable pairs and of P/Q bound entries: one for `SINGLE_PHASE`, one
per cyclic phase pair for `THREE_LEG`, one per phase conductor for `FOUR_LEG`.
"""
function _ibr_coil_count(inv, nlabels)
    tm   = Vector{String}(get(inv, "terminal_map", String[]))
    topo = get(inv, "topology", "FOUR_LEG")
    topo == "THREE_LEG" && return length(tm)
    topo == "SINGLE_PHASE" && return 1
    return length(_phase_positions(tm, nlabels))   # FOUR_LEG
end

"""
    _ibr_coil_terminals(inv, nlabels) -> Vector{Tuple{String,Union{String,Nothing}}}

The `(positive, reference)` terminal labels of each coil, in coil order, as the
builder forms the coil voltage: `SINGLE_PHASE` is `tm[1]` against `tm[2]`;
`THREE_LEG` is each terminal against the next, cyclically; `FOUR_LEG` is each
phase terminal against the neutral terminal, or against earth (`nothing`) when
the map has no neutral.
"""
function _ibr_coil_terminals(inv, nlabels)
    tm   = Vector{String}(get(inv, "terminal_map", String[]))
    topo = get(inv, "topology", "FOUR_LEG")
    if topo == "SINGLE_PHASE"
        length(tm) >= 2 || throw(ArgumentError("SINGLE_PHASE needs two terminals"))
        return Tuple{String,Union{String,Nothing}}[(tm[1], tm[2])]
    elseif topo == "THREE_LEG"
        n = length(tm)
        return Tuple{String,Union{String,Nothing}}[(tm[k], tm[(k % n) + 1]) for k in 1:n]
    elseif topo == "FOUR_LEG"
        npos = _neutral_pos(tm, nlabels)
        ref = npos === nothing ? nothing : tm[npos]
        return Tuple{String,Union{String,Nothing}}[(tm[k], ref) for k in _phase_positions(tm, nlabels)]
    end
    throw(ArgumentError("unsupported topology '$topo'"))
end

"""
    _volt_var_spec(vv) -> (spec, reason)

Static reading of a `volt_var` object. `spec` is
`(breakpoints, q_limits, voltage_reference)` when the builder supports the
object, else `nothing` with `reason` one of `:not_an_object`, `:shape`,
`:q_unit`, `:q_ref`: the device then falls back to its box bounds.
"""
function _volt_var_spec(vv)
    vv isa Dict || return (nothing, :not_an_object)
    bps = Float64.(get(vv, "breakpoints", Float64[]))
    ql  = Float64.(get(vv, "q_limits", Float64[]))
    length(bps) == 4 && length(ql) == 2 || return (nothing, :shape)
    get(vv, "q_unit", "VA_FRACTION") == "VA_FRACTION" || return (nothing, :q_unit)
    get(vv, "q_ref",  "VAR_MAX")     == "VAR_MAX"     || return (nothing, :q_ref)
    ((breakpoints=bps, q_limits=ql, ref=:VAR_MAX,
      voltage_reference=get(vv, "voltage_reference", "PN_PER_PHASE")), :ok)
end

"""
    _volt_watt_spec(vw) -> (spec, reason)

Static reading of a `volt_watt` object: `(breakpoints, p_limits, ref,
voltage_reference)` with `ref` one of `:S_MAX`, `:P_MAX`, `:P_AVAILABLE`, or
`nothing` with `reason` one of `:not_an_object`, `:shape`, `:p_unit`, `:p_ref`.
"""
function _volt_watt_spec(vw)
    vw isa Dict || return (nothing, :not_an_object)
    bps = Float64.(get(vw, "breakpoints", Float64[]))
    pl  = Float64.(get(vw, "p_limits", Float64[]))
    length(bps) == 2 && length(pl) == 2 || return (nothing, :shape)
    get(vw, "p_unit", "VA_FRACTION") == "VA_FRACTION" || return (nothing, :p_unit)
    ref = get(vw, "p_ref", "S_MAX")
    ref in ("S_MAX", "P_MAX", "P_AVAILABLE") || return (nothing, :p_ref)
    ((breakpoints=bps, p_limits=pl, ref=Symbol(ref),
      voltage_reference=get(vw, "voltage_reference", "PN_PER_PHASE")), :ok)
end

"""
    _ibr_active_laws(inv, profiles) -> (constant_pf, volt_var, volt_watt, dropped)

The control objects the builder acts on for this IBR, after precedence:
a constant power factor suppresses both droop laws, and `THREE_LEG` carries no
droop. `volt_var`/`volt_watt` are the raw profile objects (still to be read by
[`_volt_var_spec`](@ref) / [`_volt_watt_spec`](@ref)) or `nothing`. `dropped`
says why declared droop objects were set aside: `:three_leg`,
`:constant_pf`, or `nothing`.
"""
function _ibr_active_laws(inv, profiles)
    pf = nothing; vv = nothing; vw = nothing
    cp_id = get(inv, "control_profile", nothing)
    if cp_id isa String
        cp = get(profiles, cp_id, nothing)
        if cp isa Dict
            pf = _constant_pf_value(cp)
            vv = get(cp, "volt_var",  nothing)
            vw = get(cp, "volt_watt", nothing)
        end
    end
    dropped = nothing
    if vv !== nothing || vw !== nothing
        if get(inv, "topology", "FOUR_LEG") == "THREE_LEG"
            dropped = :three_leg
        elseif pf !== nothing
            dropped = :constant_pf
        end
        dropped === nothing || (vv = nothing; vw = nothing)
    end
    (constant_pf=pf, volt_var=vv, volt_watt=vw, dropped=dropped)
end

"""
    _ibr_droop_base(ref, idx, s_max, p_max, p_avail_per)

Normalization base of a droop curve for coil `idx`: the coil's `s_max` entry
for `:VAR_MAX` and `:S_MAX`, its `p_max` entry for `:P_MAX`, the per-coil
available power for `:P_AVAILABLE`. A missing entry is a zero base.
"""
function _ibr_droop_base(ref::Symbol, idx::Int, s_max, p_max, p_avail_per)
    (ref === :VAR_MAX || ref === :S_MAX) && return idx <= length(s_max) ? s_max[idx] : 0.0
    ref === :P_MAX       && return idx <= length(p_max) ? p_max[idx] : 0.0
    ref === :P_AVAILABLE && return p_avail_per
    return 0.0
end

"""
    _ibr_p_avail_per_coil(inv, ncoils) -> Float64

The scalar device `p_avail` divided equally over the coils (SI); zero when the
field is absent.
"""
function _ibr_p_avail_per_coil(inv, ncoils::Int)
    pa = get(inv, "p_avail", nothing)
    pa isa Number ? Float64(pa) / max(ncoils, 1) : 0.0
end

"""
    _ibr_dc_mode(inv) -> NamedTuple

How the DC side couples the coils' active powers: `(kind=:bus,)` for a shared
`dc_bus` (the sum follows DC KCL), `(kind=:isolated, p_min, p_max)` for an
isolated link (`dc_link_coupled`; the sum is bounded, both bounds defaulting to
zero), `(kind=:none,)` otherwise. A `dc_bus` takes precedence.
"""
function _ibr_dc_mode(inv)
    haskey(inv, "dc_bus") && return (kind=:bus, p_min=-Inf, p_max=Inf)
    get(inv, "dc_link_coupled", false) === true || return (kind=:none, p_min=-Inf, p_max=Inf)
    (kind=:isolated, p_min=Float64(get(inv, "p_dc_min", 0.0)), p_max=Float64(get(inv, "p_dc_max", 0.0)))
end

"""
    _pf_law_coefficients(pf) -> (a, b)

The constant-power-factor law as the builder stamps it, `a·Q + b·P = 0`, with
`a = sign(pf)·|pf|` and `b = sin(phi) = sqrt(1 - pf²)`, computed without `acos`
so that a power factor near zero stays representable.
"""
function _pf_law_coefficients(pf::Real)
    m = abs(Float64(pf))
    (sign(Float64(pf)) * m, sqrt((1 - m) * (1 + m)))
end

"""
    _ibr_control_rules(inv, profiles, nlabels, minimum_pf) -> NamedTuple

Everything the builder's per-coil constraints depend on, for one IBR record,
in SI. `minimum_pf` is the policy entry of this device from
`_power_factor_config_check!`, or `nothing`. Throws `ArgumentError` (or a
conversion error) on a record the builder would reject; callers that must not
fail catch it and treat the device as unconstrained.

Fields: `topology`, `n_coils`, `coils` (terminal pairs), the bound vectors
`p_min`, `p_max`, `q_min`, `q_max`, `s_max`, `i_max` (empty when absent),
`constant_pf`, `min_pf`, `volt_var` and `volt_watt` (specs, or `nothing` when
inactive), `p_avail_per`, and `dc`.
"""
function _ibr_control_rules(inv, profiles, nlabels, minimum_pf)
    topo = String(get(inv, "topology", "FOUR_LEG"))
    coils = _ibr_coil_terminals(inv, nlabels)
    n = length(coils)
    vec(key) = (v = get(inv, key, Float64[]); Float64.(v isa Real ? [v] : v))
    p_min = vec("p_min"); p_max = vec("p_max"); q_min = vec("q_min"); q_max = vec("q_max")
    for (field, values) in (("p_min", p_min), ("p_max", p_max), ("q_min", q_min), ("q_max", q_max))
        (isempty(values) || length(values) == n) || throw(ArgumentError(
            "$field has $(length(values)) entries but the device has $n coil(s); supply one entry per coil."))
    end
    laws = _ibr_active_laws(inv, profiles)
    vv = laws.volt_var === nothing ? nothing : first(_volt_var_spec(laws.volt_var))
    vw = laws.volt_watt === nothing ? nothing : first(_volt_watt_spec(laws.volt_watt))
    pf_min = minimum_pf === nothing ? nothing : Float64(minimum_pf.pf_min)
    (topology=topo, n_coils=n, coils=coils, p_min=p_min, p_max=p_max, q_min=q_min, q_max=q_max,
     s_max=vec("s_max"), i_max=vec("i_max"), constant_pf=laws.constant_pf, min_pf=pf_min,
     volt_var=vv, volt_watt=vw, p_avail_per=_ibr_p_avail_per_coil(inv, n), dc=_ibr_dc_mode(inv))
end

"""
    _ibr_power_ranges(rules) -> Union{Nothing,Vector{NamedTuple}}

The range each coil's active and reactive power can take under the
voltage-independent part of the builder's constraints, as
`(p=(lo, hi), q=(lo, hi))` per coil, or `nothing` when those constraints are
contradictory.

Constraints used, in the builder's own form:

- the P and Q boxes (a missing bound is no bound);
- a zero `s_max` entry, or a zero current limit, pins both powers at zero,
  except beside a live Volt-var law or a shared DC bus, where the power flow
  (which enforces no ratings) could still carry current;
- a constant power factor, `a·Q + b·P = 0` ([`_pf_law_coefficients`](@ref));
- a minimum power factor, `P >= 0` and `pf_min·|Q| <= sin(phi)·P` (beside a
  constant power factor below it, only the origin satisfies both);
- a Volt-var law `Q = base·f(U)` and a Volt-watt cap `P <= base·f(U)`, only
  where they hold at every voltage: a zero base or an all-zero curve;
- the isolated DC-link balance on the sum of the coil powers.

Each coil's constraints are projected onto its P and Q ranges, then the DC
balance onto each coil given the others, repeated to a fixed point. Every
projection is exact for these constraint shapes, so a range is a single point
exactly when the constraints force it. Voltage-dependent limits (a nonzero
droop curve, the apparent-power circle, a current limit) only ever narrow a
range further and are not used: a coil reported as free may still be limited,
never the reverse.
"""
function _ibr_power_ranges(rules)
    n = rules.n_coils
    at(v, k, default) = k <= length(v) ? v[k] : default
    plo = [at(rules.p_min, k, -Inf) for k in 1:n]; phi = [at(rules.p_max, k, Inf) for k in 1:n]
    qlo = [at(rules.q_min, k, -Inf) for k in 1:n]; qhi = [at(rules.q_max, k, Inf) for k in 1:n]
    for k in 1:n
        # Ratings: one current per SINGLE_PHASE unit, limited by its tightest entry.
        no_current = rules.topology == "SINGLE_PHASE" ?
            (!isempty(rules.i_max) && iszero(minimum(rules.i_max))) :
            (k <= length(rules.i_max) && iszero(rules.i_max[k]))
        # A zero rating is enforced by the OPF but not by the power flow, which
        # drops current limits and the apparent-power circle. It is used only
        # where the power flow cannot disagree: there, P is a fixed setpoint and
        # Q a setpoint or a power-factor multiple of P, so a zero rating either
        # agrees with them or contradicts them (and a contradiction drops
        # nothing). Two cases escape that argument and are left alone: a live
        # Volt-var law, whose Q follows the voltage, and a shared DC bus, whose
        # P follows the DC network.
        live_volt_var = rules.volt_var !== nothing && !all(iszero, rules.volt_var.q_limits) &&
            !iszero(_ibr_droop_base(:VAR_MAX, k, rules.s_max, rules.p_max, rules.p_avail_per))
        rating_applies = rules.dc.kind != :bus && !live_volt_var
        if rating_applies && (no_current || (k <= length(rules.s_max) && iszero(rules.s_max[k])))
            plo[k] = max(plo[k], 0.0); phi[k] = min(phi[k], 0.0)
            qlo[k] = max(qlo[k], 0.0); qhi[k] = min(qhi[k], 0.0)
        end
        if rules.volt_watt !== nothing
            base = _ibr_droop_base(rules.volt_watt.ref, k, rules.s_max, rules.p_max, rules.p_avail_per)
            (iszero(base) || all(iszero, rules.volt_watt.p_limits)) && (phi[k] = min(phi[k], 0.0))
        end
        if rules.volt_var !== nothing
            base = _ibr_droop_base(:VAR_MAX, k, rules.s_max, rules.p_max, rules.p_avail_per)
            if iszero(base) || all(iszero, rules.volt_var.q_limits)
                qlo[k] = max(qlo[k], 0.0); qhi[k] = min(qhi[k], 0.0)
            end
        end
    end
    # A constant power factor below the minimum one puts the coil's line
    # outside its wedge everywhere but at the origin. Interval projection
    # alone would only approach that point; it is stated here.
    if rules.constant_pf !== nothing && rules.min_pf !== nothing && abs(rules.constant_pf) < rules.min_pf
        for k in 1:n
            plo[k] = max(plo[k], 0.0); phi[k] = min(phi[k], 0.0)
            qlo[k] = max(qlo[k], 0.0); qhi[k] = min(qhi[k], 0.0)
        end
    end
    times(m, x) = iszero(x) ? 0.0 : m * x                 # 0·Inf is not a bound
    for _ in 1:4n + 8
        before = (copy(plo), copy(phi), copy(qlo), copy(qhi))
        for k in 1:n
            if rules.constant_pf !== nothing
                a, b = _pf_law_coefficients(rules.constant_pf)
                if iszero(b)                              # unity: Q = 0
                    qlo[k] = max(qlo[k], 0.0); qhi[k] = min(qhi[k], 0.0)
                else
                    m = -a / b                            # P = m·Q
                    x, y = times(m, qlo[k]), times(m, qhi[k])
                    plo[k] = max(plo[k], min(x, y)); phi[k] = min(phi[k], max(x, y))
                    x, y = times(1 / m, plo[k]), times(1 / m, phi[k])
                    qlo[k] = max(qlo[k], min(x, y)); qhi[k] = min(qhi[k], max(x, y))
                end
            end
            if rules.min_pf !== nothing
                sine = sqrt((1 - rules.min_pf) * (1 + rules.min_pf))
                plo[k] = max(plo[k], 0.0)
                if iszero(sine)
                    qlo[k] = max(qlo[k], 0.0); qhi[k] = min(qhi[k], 0.0)
                else
                    t = sine / rules.min_pf               # |Q| <= t·P
                    least = qlo[k] > 0 ? qlo[k] : qhi[k] < 0 ? -qhi[k] : 0.0
                    plo[k] = max(plo[k], least / t)
                    qlo[k] = max(qlo[k], -times(t, phi[k])); qhi[k] = min(qhi[k], times(t, phi[k]))
                end
            end
        end
        if rules.dc.kind == :isolated
            for k in 1:n
                others_hi = sum(phi[j] for j in 1:n if j != k; init=0.0)
                others_lo = sum(plo[j] for j in 1:n if j != k; init=0.0)
                plo[k] = max(plo[k], rules.dc.p_min - others_hi)
                phi[k] = min(phi[k], rules.dc.p_max - others_lo)
            end
        end
        (any(isnan, plo) || any(isnan, phi) || any(isnan, qlo) || any(isnan, qhi)) && return nothing
        before == (plo, phi, qlo, qhi) && break
    end
    scale = maximum(abs(x) for v in (plo, phi, qlo, qhi) for x in v if isfinite(x); init=1.0)
    tol = 1e-9 * max(1.0, scale)
    for k in 1:n
        (plo[k] <= phi[k] + tol && qlo[k] <= qhi[k] + tol) || return nothing
    end
    [(p=(plo[k], phi[k]), q=(qlo[k], qhi[k])) for k in 1:n]
end

# True where a range is the single point zero, to the tolerance of its data.
function _range_is_zero(range, tol)
    isfinite(range[1]) && isfinite(range[2]) && abs(range[1]) <= tol && abs(range[2]) <= tol
end

"""
    _ibr_coil_states(rules) -> Vector{Symbol}

Per coil: `:zero` when the constraints force both its powers to zero (it
carries no current at any voltage), `:fixed` when both are forced to one
nonzero operating point, `:free` otherwise, including when the constraints are
contradictory: only a proven zero removes a coil.
"""
function _ibr_coil_states(rules)
    ranges = _ibr_power_ranges(rules)
    ranges === nothing && return fill(:free, rules.n_coils)
    # Zero is an absolute statement (1e-9 W or var), whatever the size of the
    # device's other numbers: a coil limited to a milliwatt beside one rated in
    # megawatts still carries current. Rounding left by large numbers can only
    # make a forced zero go unrecognized, never the reverse.
    zero(x) = _range_is_zero(x, 1e-9)
    map(ranges) do r
        zero(r.p) && zero(r.q) && return :zero
        point(x) = isfinite(x[1]) && isfinite(x[2]) && abs(x[2] - x[1]) <= 1e-9 * max(1.0, abs(x[1]), abs(x[2]))
        point(r.p) && point(r.q) ? :fixed : :free
    end
end
