# validation/domain_rules.jl
#
# Domain-level plausibility checks — things the JSON Schema cannot express.
# Thresholds are configurable per network voltage class (MV/LV mixed).

"""
    domain_rules_check(net, findings) -> Dict{String,Any}

Check numerical plausibility of field values. All thresholds are
configurable via the `thresholds` keyword (see `_DEFAULT_THRESHOLDS`).
"""
function domain_rules_check(net::Dict{String,Any},
                             findings::Vector{Finding};
                             thresholds::Dict=_domain_thresholds())::Dict{String,Any}
    result = Dict{String,Any}()
    n_checks = Ref(0)

    _check_bus_voltage_bounds(net, findings, n_checks)
    _check_load_power_factor(net, findings, thresholds, n_checks)
    _check_generator_cost(net, findings, thresholds, n_checks)
    _check_line_impedance(net, findings, thresholds, n_checks)
    _check_transformer_ratings(net, findings, thresholds, n_checks)
    _check_transformer_ideal(net, findings, thresholds, n_checks)
    _check_nonnegative_fields(net, findings, n_checks)
    _check_zero_limits(net, findings, n_checks)
    _check_zero_length(net, findings, n_checks)
    _check_angle_units(net, findings, n_checks)
    _check_negative_loads(net, findings, n_checks)
    _check_generator_semantics(net, findings, n_checks)
    _check_generator_capability(net, findings, n_checks)
    _check_load_models(net, findings, n_checks)
    _check_low_impedance_lines(net, findings, thresholds, n_checks)
    _check_adjacent_line_impedance_spread(net, findings, thresholds, n_checks, result)
    _check_ibr_capability(net, findings, n_checks)
    _check_droop_breakpoint_band(net, findings, n_checks)
    _check_cost_phase_uniformity(net, findings, n_checks)
    _check_source_voltage_margin(net, findings, thresholds, n_checks)
    _check_shunt_on_grounded_terminal(net, findings, n_checks)

    result["n_checks_run"] = n_checks[]
    result
end

# Backwards-compatible handle on the domain-rules thresholds. These now live in
# `config/default.toml` under `[domain_rules]`; this is a view of that section.
# Pass a `thresholds=` (or `analyze(...; config=)`) to override per call.
const _DEFAULT_THRESHOLDS = _domain_thresholds()

function _check_bus_voltage_bounds(net, findings, n_checks)
    # v_min/v_max are per-phase arrays (phase-to-ground); vn_max is the optional
    # scalar neutral-to-ground maximum. Check value validity on every entry.
    _as_vec(x) = x === nothing ? Float64[] : (x isa AbstractVector ? Float64.(x) : [Float64(x)])
    for (id, b) in get(net, "bus", Dict())
        vmin = get(b, "v_min", nothing)
        vmax = get(b, "v_max", nothing)
        vnmax = get(b, "vn_max", nothing)
        (vmin === nothing && vmax === nothing && vnmax === nothing) && continue
        n_checks[] += 1

        if any(<(0), _as_vec(vmin))
            push!(findings, Finding(ERROR, "E.DOM.VMIN_NEGATIVE", :domain_rules, :bus, id,
                "Bus '$id': v_min = $(vmin) V has a negative per-phase entry.",
                Dict{String,Any}("v_min" => vmin)))
        end
        if any(<=(0), _as_vec(vmax))
            push!(findings, Finding(ERROR, "E.DOM.VMAX_NONPOSITIVE", :domain_rules, :bus, id,
                "Bus '$id': v_max = $(vmax) V has a per-phase entry ≤ 0.",
                Dict{String,Any}("v_max" => vmax)))
        end
        if vnmax !== nothing && Float64(vnmax) < 0
            push!(findings, Finding(ERROR, "E.DOM.VNMAX_NEGATIVE", :domain_rules, :bus, id,
                "Bus '$id': vn_max = $(vnmax) V is negative.",
                Dict{String,Any}("vn_max" => vnmax)))
        end
    end
end

# Warn when a Volt-var/Volt-watt breakpoint (SI phase-to-neutral volts) lies
# outside the operational voltage band of the IBR's bus — the droop would
# then never engage (or always saturate) within the feasible voltage range.
function _check_droop_breakpoint_band(net, findings, n_checks)
    profiles = get(net, "control_profile", Dict())
    profiles isa Dict && !isempty(profiles) || return
    buses = get(net, "bus", Dict())

    for (inv_id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        cp_id = get(inv, "control_profile", nothing)
        cp_id isa AbstractString || continue
        cp = get(profiles, cp_id, nothing)
        cp isa Dict || continue

        bus = get(buses, get(inv, "bus", ""), nothing)
        bus isa Dict || continue
        vmin = get(bus, "v_min", nothing)
        vmax = get(bus, "v_max", nothing)
        (vmin isa AbstractVector && !isempty(vmin)) || continue
        (vmax isa AbstractVector && !isempty(vmax)) || continue
        lo = minimum(Float64.(vmin)); hi = maximum(Float64.(vmax))

        for law in ("volt_var", "volt_watt")
            sub = get(cp, law, nothing)
            sub isa Dict || continue
            bps = get(sub, "breakpoints", nothing)
            bps isa AbstractVector || continue
            n_checks[] += 1
            outside = [Float64(b) for b in bps if Float64(b) < lo || Float64(b) > hi]
            isempty(outside) || push!(findings, Finding(WARNING,
                "W.DOM.DROOP_BREAKPOINT_OUTSIDE_BAND", :domain_rules, :ibr, inv_id,
                "IBR '$inv_id': $law breakpoint(s) $(outside) V lie outside the " *
                "bus voltage band [$(round(lo,digits=1)), $(round(hi,digits=1))] V; " *
                "the droop may never engage within the feasible range.",
                Dict{String,Any}("breakpoints" => outside)))
        end
    end
end

function _check_load_power_factor(net, findings, thresh, n_checks)
    pf_min = Float64(thresh["pf_min"])
    for (id, l) in get(net, "load", Dict())
        p = Float64.(get(l, "p_nom", Float64[]))
        q = Float64.(get(l, "q_nom", Float64[]))
        isempty(p) && continue
        n_checks[] += 1
        for (pi, qi) in zip(p, q)
            s = hypot(pi, qi)
            s <= 0 && continue
            pf = pi / s
            if pf < pf_min
                push!(findings, Finding(WARNING, "W.DOM.LOAD_PF_LOW", :domain_rules, :load, id,
                    "Load '$id' has power factor $(round(pf, digits=3)) < $pf_min.",
                    Dict{String,Any}("pf" => pf, "threshold" => pf_min)))
                break  # one warning per load
            end
        end
    end
end

function _check_generator_cost(net, findings, thresh, n_checks)
    cost_max = Float64(thresh["cost_max_per_kwh"])
    for (id, g) in get(net, "generator", Dict())
        haskey(g, "cost") || continue
        n_checks[] += 1
        # cost is a per-phase linear-coefficient vector ($/W); a scalar is
        # tolerated here for validation only (the OPF requires the vector form)
        c = g["cost"]
        costs = c isa AbstractVector ? Float64.(c) : [Float64(c)]
        if any(<(0), costs)
            push!(findings, Finding(WARNING, "W.DOM.GEN_COST_NEGATIVE", :domain_rules,
                :generator, id,
                "Generator '$id' has negative cost $(minimum(costs)) \$/kWh.",
                Dict{String,Any}("cost" => costs)))
        elseif any(>(cost_max), costs)
            push!(findings, Finding(WARNING, "W.DOM.GEN_COST_HIGH", :domain_rules,
                :generator, id,
                "Generator '$id' cost $(maximum(costs)) \$/kWh exceeds threshold $cost_max \$/kWh.",
                Dict{String,Any}("cost" => costs, "threshold" => cost_max)))
        end
    end
end

"""
    _check_cost_phase_uniformity(net, findings, n_checks)

Warn when a dispatchable element's per-phase `cost` vector is non-uniform across
phases. Costs usually represent a single \$/W price applied symmetrically; a
vector with differing entries is more often a data-entry slip than an intended
per-phase price signal. Covers `generator` and `voltage_source` today; extend the
`elements` list as further dispatchable element types gain a `cost` field.
"""
function _check_cost_phase_uniformity(net, findings, n_checks)
    elements = (("generator", :generator), ("voltage_source", :voltage_source))
    for (key, kind) in elements
        for (id, el) in get(net, key, Dict())
            el isa Dict || continue
            haskey(el, "cost") || continue
            c = el["cost"]
            c isa AbstractVector || continue   # scalar cost is uniform by definition
            costs = Float64.(c)
            length(costs) > 1 || continue
            n_checks[] += 1
            spread = maximum(costs) - minimum(costs)
            # Relative tolerance against the largest |cost|; absolute floor guards
            # the all-near-zero case.
            scale = maximum(abs, costs)
            if spread > max(1e-9, 1e-6 * scale)
                push!(findings, Finding(WARNING, "W.DOM.COST_PHASE_NONUNIFORM",
                    :domain_rules, kind, id,
                    "$(uppercasefirst(replace(key, '_' => ' '))) '$id' has " *
                    "non-uniform per-phase cost $(costs) — costs usually apply " *
                    "symmetrically across phases; check this is intentional.",
                    Dict{String,Any}("cost" => costs, "spread" => spread)))
            end
        end
    end
end

"""
    _check_source_voltage_margin(net, findings, thresh, n_checks)

Warn when a voltage source's fixed `v_magnitude` sits within
`source_v_margin_frac` of the (v_max − v_min) band from either bound, on the
source bus or on a same-voltage-base neighbour (reachable via lines/switches;
transformers change the base and are not crossed). A fixed source voltage hard
against a phase bound leaves the OPF no headroom and is a common cause of
infeasibility.
"""
function _check_source_voltage_margin(net, findings, thresh, n_checks)
    margin_frac = Float64(get(thresh, "source_v_margin_frac", 0.05))
    buses = get(net, "bus", Dict())
    sources = get(net, "voltage_source", Dict())
    isempty(sources) && return

    # Same-base adjacency: lines and switches preserve the voltage base.
    adj = Dict{String,Vector{String}}()
    for key in ("line", "switch")
        for (_, br) in get(net, key, Dict())
            br isa Dict || continue
            bf = get(br, "bus_from", ""); bt = get(br, "bus_to", "")
            (isempty(bf) || isempty(bt)) && continue
            push!(get!(adj, bf, String[]), bt)
            push!(get!(adj, bt, String[]), bf)
        end
    end

    _as_vec(x) = x === nothing ? Float64[] :
                 (x isa AbstractVector ? Float64.(x) : [Float64(x)])

    for (sid, vs) in sources
        vs isa Dict || continue
        vmag = _as_vec(get(vs, "v_magnitude", nothing))
        isempty(vmag) && continue
        src_bus = get(vs, "bus", "")
        isempty(src_bus) && continue
        n_checks[] += 1

        # Source bus plus its same-base neighbours (one hop is enough to cover
        # "the next bus"; lines/switches share the base so bounds are comparable).
        check_buses = String[src_bus]
        append!(check_buses, get(adj, src_bus, String[]))

        flagged = false
        for bid in unique(check_buses)
            flagged && break
            bus = get(buses, bid, nothing)
            bus isa Dict || continue
            vmin = _as_vec(get(bus, "v_min", nothing))
            vmax = _as_vec(get(bus, "v_max", nothing))
            (isempty(vmin) || isempty(vmax)) && continue
            np = min(length(vmag), length(vmin), length(vmax))
            for k in 1:np
                lo = vmin[k]; hi = vmax[k]
                band = hi - lo
                band > 0 || continue
                margin = margin_frac * band
                v = vmag[k]
                near_lo = v <= lo + margin
                near_hi = v >= hi - margin
                if near_lo || near_hi
                    side = near_lo ? "lower" : "upper"
                    bound = near_lo ? lo : hi
                    where = bid == src_bus ? "its bus '$bid'" :
                            "neighbour bus '$bid'"
                    push!(findings, Finding(WARNING, "W.DOM.SOURCE_V_NEAR_BOUND",
                        :domain_rules, :voltage_source, sid,
                        "Voltage source '$sid' magnitude $(round(v, digits=1)) V " *
                        "(phase $k) is within $(round(margin_frac*100, digits=1)) % " *
                        "of the $side voltage bound " *
                        "$(round(bound, digits=1)) V on $where — little OPF " *
                        "headroom; risk of infeasibility.",
                        Dict{String,Any}("v_magnitude" => v, "bus" => bid,
                            "phase" => k, "side" => side, "bound" => bound,
                            "band" => band)))
                    flagged = true   # one warning per source
                    break
                end
            end
        end
    end
end

"""
    _check_shunt_on_grounded_terminal(net, findings, n_checks)

Warn when a `shunt` connects to a terminal that is also perfectly grounded — i.e.
a terminal whose voltage is pinned to 0 V, either by the bus's
`perfectly_grounded_terminals` or by being the neutral of a voltage-source bus
(the source pins its neutral to system ground). On such a terminal the shunt draws
`I = G·V = 0` current, so it is completely inert: it has no effect on the solution
and usually signals either a redundant element or that impedance grounding was
intended where a hard V=0 ground was actually declared.
"""
function _check_shunt_on_grounded_terminal(net, findings, n_checks)
    buses = get(net, "bus", Dict())

    # Build the set of perfectly-grounded (bus, terminal) pairs.
    grounded = Set{Tuple{String,String}}()
    for (bid, bus) in buses
        bus isa Dict || continue
        for t in get(bus, "perfectly_grounded_terminals", String[])
            push!(grounded, (bid, string(t)))
        end
    end
    # Source-bus neutrals are pinned to 0 V by the voltage source.
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        bus = get(vs, "bus", "")
        b   = get(buses, bus, Dict())
        nt  = b isa Dict ? _neutral_terminal(b) : nothing
        nt === nothing || push!(grounded, (bus, string(nt)))
    end
    isempty(grounded) && return

    for (id, sh) in get(net, "shunt", Dict())
        sh isa Dict || continue
        bus = get(sh, "bus", "")
        for t in Vector{String}(get(sh, "terminal_map", String[]))
            (bus, t) in grounded || continue
            n_checks[] += 1
            push!(findings, Finding(WARNING, "W.DOM.SHUNT_ON_GROUNDED", :domain_rules,
                :shunt, id,
                "Shunt '$id' is connected to terminal '$t' of bus '$bus', which is " *
                "perfectly grounded (V = 0) — the shunt draws G·V = 0 current and " *
                "is inert. Drop the redundant shunt, or remove the perfect ground " *
                "if impedance grounding was intended.",
                Dict{String,Any}("bus" => bus, "terminal" => t)))
        end
    end
end

function _check_line_impedance(net, findings, thresh, n_checks)
    r_min = Float64(thresh["r_series_min"])
    linecodes = get(net, "linecode", Dict())
    for (id, lc) in linecodes
        lc isa Dict || continue
        R = _pattern_keys_to_matrix(lc, "R_series_")
        R isa AbstractMatrix || continue
        n_checks[] += 1
        low = [i for i in 1:size(R, 1) if R[i, i] < r_min]
        if !isempty(low)
            push!(findings, Finding(WARNING, "W.DOM.LC_ZERO_R", :domain_rules,
                :linecode, id,
                "Linecode '$id' has near-zero or negative self-resistance on " *
                "diagonal entr$(length(low) == 1 ? "y" : "ies") $(low) " *
                "(superconducting?).",
                Dict{String,Any}("entries" => low, "threshold" => r_min)))
        end
    end
end

function _check_zero_limits(net, findings, n_checks)
    # A literal zero limit forces zero flow. Source tools often use 0 to
    # mean "no limit" — classic semantic abuse worth surfacing.
    for (comp_type, csym) in (("linecode", :linecode), ("line", :line),
                               ("switch", :switch))
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            for field in ("i_max", "s_max")
                haskey(c, field) || continue
                n_checks[] += 1
                v = c[field]
                vals = v isa AbstractVector ? Float64.(v) : [Float64(v)]
                if any(==(0.0), vals)
                    push!(findings, Finding(WARNING, "W.DOM.ZERO_LIMIT",
                        :domain_rules, csym, id,
                        "$comp_type '$id' has a zero entry in $field — read " *
                        "literally this forces zero flow; if it means 'no " *
                        "limit', drop the field instead.",
                        Dict{String,Any}("field" => field, "values" => vals)))
                end
            end
        end
    end
end

function _check_zero_length(net, findings, n_checks)
    for (id, l) in get(net, "line", Dict())
        l isa Dict || continue
        haskey(l, "length") || continue
        n_checks[] += 1
        if Float64(l["length"]) == 0.0
            push!(findings, Finding(WARNING, "W.DOM.ZERO_LENGTH", :domain_rules,
                :line, id,
                "Line '$id' has zero length — degenerate impedance; model " *
                "low-impedance sections with the lossless switch object instead.",
                nothing))
        end
    end
end

function _check_angle_units(net, findings, n_checks)
    # v_angle is radians per the data model; magnitudes beyond 2π are a
    # near-certain degrees-in-a-radians-field unit error
    for (id, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        va = get(vs, "v_angle", nothing)
        va === nothing && continue
        n_checks[] += 1
        vals = va isa AbstractVector ? Float64.(va) : [Float64(va)]
        if any(a -> abs(a) > 2π, vals)
            push!(findings, Finding(WARNING, "W.DOM.ANGLE_UNITS", :domain_rules,
                :voltage_source, id,
                "Voltage source '$id' has |v_angle| > 2π — angles are radians " *
                "in the data model; this looks like degrees.",
                Dict{String,Any}("v_angle" => vals)))
        end
    end
end

# Validate voltage-dependent load model fields (ZIP / exponential).
# (`_n_subloads` and `_as_vec` are defined in analysis/load_models.jl.)
# Constant-power loads (no `model`, or model="constant_power") are unaffected.
function _check_load_models(net, findings, n_checks)
    bus_vnom = _assign_nominal_voltages(net)   # phase-to-neutral V, BFS from sources

    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        model = get(l, "model", "constant_power")

        # Fields that belong to each family — used to flag stray/ignored fields.
        zip_fields = ("alpha_z","alpha_i","alpha_p","beta_z","beta_i","beta_p")
        exp_fields = ("gamma_p","gamma_q")
        has_zip = any(k -> haskey(l, k), zip_fields)
        has_exp = any(k -> haskey(l, k), exp_fields)

        if model == "constant_power"
            if has_zip || has_exp
                push!(findings, Finding(INFO, "I.LOAD.MODEL_FIELDS_IGNORED",
                    :domain_rules, :load, id,
                    "Load '$id' has model=constant_power but carries ZIP/exponential " *
                    "coefficient fields; they will be ignored.", nothing))
            end
            continue
        end

        n_checks[] += 1
        n_sub = _n_subloads(l)

        # All voltage-dependent models require v_nom.
        vnom = get(l, "v_nom", nothing)
        if vnom === nothing
            push!(findings, Finding(ERROR, "E.LOAD.VNOM_MISSING", :domain_rules,
                :load, id,
                "Load '$id' has model=$model but no v_nom; the reference voltage " *
                "for the load model is undefined.", nothing))
        elseif vnom isa AbstractVector && !(length(vnom) in (1, n_sub))
            push!(findings, Finding(ERROR, "E.LOAD.VNOM_ARITY", :domain_rules,
                :load, id,
                "Load '$id' v_nom has length $(length(vnom)); expected 1 or " *
                "$n_sub (one per sub-load).", nothing))
        elseif vnom isa AbstractVector && any(<=(0.0), Float64.(vnom))
            push!(findings, Finding(ERROR, "E.LOAD.VNOM_NONPOSITIVE", :domain_rules,
                :load, id, "Load '$id' has non-positive v_nom entries.", nothing))
        end

        # Named degenerate ZIP models: no coefficient fields required.
        if model in ("constant_current", "constant_impedance")
            if has_zip || has_exp
                push!(findings, Finding(INFO, "I.LOAD.MODEL_FIELDS_IGNORED",
                    :domain_rules, :load, id,
                    "Load '$id' has model=$model; ZIP/exponential coefficient fields " *
                    "are redundant and will be ignored.", nothing))
            end
        elseif model == "zip"
            has_exp && push!(findings, Finding(WARNING, "W.LOAD.MODEL_MIXED",
                :domain_rules, :load, id,
                "Load '$id' is model=zip but also carries gamma_p/gamma_q; " *
                "exponential fields are ignored.", nothing))
            _check_zip_coeffs(id, l, n_sub, findings)
        elseif model == "exponential"
            has_zip && push!(findings, Finding(WARNING, "W.LOAD.MODEL_MIXED",
                :domain_rules, :load, id,
                "Load '$id' is model=exponential but also carries ZIP coefficients; " *
                "they are ignored.", nothing))
            _check_exp_coeffs(id, l, n_sub, findings)
        end

        # v_nom plausibility: compare against BFS-inferred bus nominal voltage.
        vnom === nothing && continue
        vnom_vals = vnom isa AbstractVector ? Float64.(vnom) : [Float64(vnom)]
        any(<=(0.0), vnom_vals) && continue   # already flagged above
        bid = get(l, "bus", nothing)
        bid isa AbstractString || continue
        v_bus_pn = get(bus_vnom, bid, nothing)
        v_bus_pn === nothing && continue      # bus unreachable from source — skip

        cfg = get(l, "configuration", "WYE")
        # v_bus_pn is phase-to-neutral; DELTA loads reference line-to-line
        v_expected = cfg == "DELTA" ? v_bus_pn * sqrt(3.0) : v_bus_pn

        for (k, vk) in enumerate(vnom_vals)
            ratio = vk / v_expected
            if ratio < 0.8 || ratio > 1.25
                push!(findings, Finding(WARNING, "W.LOAD.VNOM_MISMATCH",
                    :domain_rules, :load, id,
                    "Load '$id' sub-load $k: v_nom=$(round(vk; digits=1)) V differs " *
                    "from the bus inferred nominal " *
                    "$(cfg == "DELTA" ? "line-to-line" : "phase-to-neutral") voltage " *
                    "$(round(v_expected; digits=1)) V by " *
                    "$(round(abs(ratio-1)*100; digits=0)) %. " *
                    "Power setpoint and voltage sensitivity are referenced to the " *
                    "wrong operating point.",
                    Dict{String,Any}("load"=>id, "sub_load"=>k,
                                     "v_nom"=>vk, "v_expected"=>v_expected,
                                     "ratio"=>ratio, "bus"=>bid)))
                break  # one warning per load is enough
            end
        end
    end
end

# ZIP coefficient checks: per-family arity, and sum ≈ 1 (warning, not error,
# because experimentally-fitted coefficients need not sum exactly to 1).
function _check_zip_coeffs(id, l, n_sub, findings)
    for (z, i, p, lbl) in (("alpha_z","alpha_i","alpha_p","active"),
                           ("beta_z","beta_i","beta_p","reactive"))
        cz = get(l, z, nothing); ci = get(l, i, nothing); cp = get(l, p, nothing)
        all(x -> x === nothing, (cz, ci, cp)) && continue
        for (name, c) in ((z,cz),(i,ci),(p,cp))
            c isa AbstractVector && !(length(c) in (1, n_sub)) &&
                push!(findings, Finding(ERROR, "E.LOAD.ZIP_ARITY", :domain_rules,
                    :load, id,
                    "Load '$id' $name has length $(length(c)); expected 1 or $n_sub.",
                    nothing))
        end
        # element-wise sum over the broadcast coefficients
        vz = _as_vec(cz, n_sub); vi = _as_vec(ci, n_sub); vp = _as_vec(cp, n_sub)
        (vz === nothing || vi === nothing || vp === nothing) && continue
        for k in 1:n_sub
            s = vz[k] + vi[k] + vp[k]
            if abs(s - 1.0) > 1e-3
                push!(findings, Finding(WARNING, "W.LOAD.ZIP_SUM", :domain_rules,
                    :load, id,
                    "Load '$id' $lbl ZIP coefficients sum to $(round(s, digits=4)) " *
                    "(≠ 1) on sub-load $k; p_nom/q_nom scaling will be off.", nothing))
                break
            end
        end
    end
end

# Exponential exponent checks: γ outside (0,2) has no power-cone form (INFO,
# documentary), γ < 0 is physically unusual (WARNING).
function _check_exp_coeffs(id, l, n_sub, findings)
    for (g, lbl) in (("gamma_p","active"), ("gamma_q","reactive"))
        c = get(l, g, nothing)
        c === nothing && continue
        c isa AbstractVector && !(length(c) in (1, n_sub)) &&
            push!(findings, Finding(ERROR, "E.LOAD.EXP_ARITY", :domain_rules,
                :load, id,
                "Load '$id' $g has length $(length(c)); expected 1 or $n_sub.",
                nothing))
        vals = c isa AbstractVector ? Float64.(c) : [Float64(c)]
        any(<(0.0), vals) && push!(findings, Finding(WARNING,
            "W.LOAD.GAMMA_NEGATIVE", :domain_rules, :load, id,
            "Load '$id' has negative $g ($lbl); power increases as voltage falls — " *
            "verify this is intended.", nothing))
        any(x -> x < 0.0 || x > 2.0, vals) && push!(findings, Finding(INFO,
            "I.LOAD.GAMMA_RANGE", :domain_rules, :load, id,
            "Load '$id' $g has entries outside (0,2); no convex power-cone " *
            "relaxation exists — exact NLP form required.", nothing))
    end
end

function _check_negative_loads(net, findings, n_checks)
    neg = String[]
    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        p = get(l, "p_nom", nothing)
        p === nothing && continue
        n_checks[] += 1
        vals = p isa AbstractVector ? Float64.(p) : [Float64(p)]
        any(<(0.0), vals) && push!(neg, id)
    end
    if !isempty(neg)
        push!(findings, Finding(INFO, "I.DOM.NEGATIVE_LOAD", :domain_rules,
            :load, nothing,
            "$(length(neg)) load(s) have negative p_nom — embedded generation " *
            "modeled as negative load; consider explicit generator objects: " *
            "$(join(sort(neg), ", ")).",
            Dict{String,Any}("loads" => sort(neg))))
    end
end

# Generator object-identity checks (semantic projection — see the docs on
# "object identity"). Two collisions:
#   • a generator whose active-power range is entirely ≤ 0 only ever absorbs — it
#     is really a load (the mirror of `I.DOM.NEGATIVE_LOAD`);
#   • a generator connected at LV (≤ 1 kV) is almost certainly an inverter-
#     interfaced DER, which the `ibr` object models faithfully (capability
#     curve, no inertia, current limit, volt-var/volt-watt) — a synchronous
#     `generator` is the wrong asset class for distribution-connected DERs.
function _check_generator_semantics(net, findings, n_checks)
    gens = get(net, "generator", Dict())
    isempty(gens) && return
    vmap = get(voltage_level_analysis(net, Finding[]), "bus_voltage_map",
               Dict{String,Float64}())

    absorbers = String[]
    ibr_like = String[]
    for (id, g) in gens
        g isa Dict || continue
        n_checks[] += 1
        pmax = get(g, "p_max", nothing)
        if pmax !== nothing
            vals = pmax isa AbstractVector ? Float64.(pmax) : [Float64(pmax)]
            !isempty(vals) && all(<=(0.0), vals) && push!(absorbers, id)
        end
        vb = get(vmap, string(get(g, "bus", "")), nothing)
        vb isa Number && vb > 0 && vb <= 1_000.0 && push!(ibr_like, id)
    end

    if !isempty(absorbers)
        push!(findings, Finding(INFO, "I.DOM.NEGATIVE_GENERATION", :domain_rules,
            :generator, nothing,
            "$(length(absorbers)) generator(s) can only absorb active power " *
            "(p_max ≤ 0 on all phases) — a consumer modeled as a generator; " *
            "consider explicit load objects: $(join(sort(absorbers), ", ")).",
            Dict{String,Any}("generators" => sort(absorbers))))
    end
    if !isempty(ibr_like)
        push!(findings, Finding(INFO, "I.DOM.GEN_LIKELY_IBR", :domain_rules,
            :generator, nothing,
            "$(length(ibr_like)) generator(s) sit on LV buses (≤ 1 kV) — " *
            "distribution-connected DERs are overwhelmingly inverter-interfaced; " *
            "the `ibr` object models them faithfully (capability curve, no " *
            "inertia, current limit, volt-var/volt-watt control): " *
            "$(join(sort(ibr_like), ", ")).",
            Dict{String,Any}("generators" => sort(ibr_like))))
    end
end

# Generator capability plausibility (mirrors `_check_ibr_capability`):
#   - the optional apparent-power rating `s_max` and current-magnitude limit
#     `i_max` stamp empty feasible circles if any per-phase entry is ≤ 0, so a
#     non-positive entry is an error (a literal zero is caught more gently as a
#     forced-zero-flow warning, consistent with line/switch handling).
function _check_generator_capability(net, findings, n_checks)
    for (id, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        n_checks[] += 1

        for (field, code, unit) in (
                ("s_max", "E.DOM.GEN_SMAX_NONPOSITIVE", "VA"),
                ("i_max", "E.DOM.GEN_IMAX_NONPOSITIVE", "A"))
            v = get(gen, field, nothing)
            arr = v isa AbstractVector ? [Float64(x) for x in v if x isa Number] : nothing
            if arr !== nothing && any(<=(0), arr)
                push!(findings, Finding(ERROR, code, :domain_rules,
                    :generator, id,
                    "Generator '$id' has a non-positive entry in $field $(arr) $unit; " *
                    "all per-phase limits must be strictly positive (a zero entry " *
                    "collapses the feasible circle to a point).",
                    Dict{String,Any}(field => arr)))
            end
        end
    end
end

# IBR capability plausibility (IBR extension §3.6'):
#   - s_max is the apparent-power nameplate and must be strictly positive;
#   - active/reactive bound pairs must be ordered (p_min ≤ p_max, q_min ≤ q_max),
#     else the feasible box is empty;
#   - a P or Q bound whose magnitude exceeds the kVA nameplate is unreachable
#     inside the apparent-power circle and is almost always a unit error;
#   - a PV prime mover that can absorb active power (p_min < 0) is unphysical.
function _check_ibr_capability(net, findings, n_checks)
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        n_checks[] += 1

        smax = get(inv, "s_max", nothing)
        smax_arr = smax isa AbstractVector ? [Float64(x) for x in smax if x isa Number] : nothing
        smax_total = nothing
        if smax_arr !== nothing
            if any(<=(0), smax_arr)
                push!(findings, Finding(ERROR, "E.DOM.INV_SMAX_NONPOSITIVE", :domain_rules,
                    :ibr, id,
                    "IBR '$id' has a non-positive entry in s_max $(smax_arr) VA; " *
                    "all per-phase apparent-power ratings must be strictly positive.",
                    Dict{String,Any}("s_max" => smax_arr)))
            else
                smax_total = sum(smax_arr)
            end
        end

        imax = get(inv, "i_max", nothing)
        imax_arr = imax isa AbstractVector ? [Float64(x) for x in imax if x isa Number] : nothing
        if imax_arr !== nothing && any(<=(0), imax_arr)
            push!(findings, Finding(ERROR, "E.DOM.IBR_IMAX_NONPOSITIVE", :domain_rules,
                :ibr, id,
                "IBR '$id' has a non-positive entry in i_max $(imax_arr) A; " *
                "all per-phase current-magnitude limits must be strictly positive.",
                Dict{String,Any}("i_max" => imax_arr)))
        end

        pmin = get(inv, "p_min", nothing)
        pmax = get(inv, "p_max", nothing)
        if pmin isa Number && pmax isa Number && Float64(pmin) > Float64(pmax)
            push!(findings, Finding(ERROR, "E.DOM.INV_P_BOUNDS", :domain_rules,
                :ibr, id,
                "IBR '$id' has p_min = $(pmin) W > p_max = $(pmax) W; " *
                "the active-power range is empty.",
                Dict{String,Any}("p_min" => pmin, "p_max" => pmax)))
        end

        qmin = get(inv, "q_min", nothing)
        qmax = get(inv, "q_max", nothing)
        if qmin isa Number && qmax isa Number && Float64(qmin) > Float64(qmax)
            push!(findings, Finding(ERROR, "E.DOM.INV_Q_BOUNDS", :domain_rules,
                :ibr, id,
                "IBR '$id' has q_min = $(qmin) var > q_max = $(qmax) var; " *
                "the reactive-power range is empty.",
                Dict{String,Any}("q_min" => qmin, "q_max" => qmax)))
        end

        # Bounds that exceed the total apparent-power nameplate are unreachable.
        if smax_total !== nothing
            for (field, v) in (("p_min", pmin), ("p_max", pmax),
                               ("q_min", qmin), ("q_max", qmax))
                v isa Number || continue
                if abs(Float64(v)) > smax_total
                    push!(findings, Finding(WARNING, "W.DOM.INV_BOUND_EXCEEDS_SMAX",
                        :domain_rules, :ibr, id,
                        "IBR '$id': |$field| = $(abs(Float64(v))) exceeds the " *
                        "total apparent-power nameplate sum(s_max) = $(smax_total) VA; " *
                        "this bound is unreachable inside the capability circle (unit error?).",
                        Dict{String,Any}("field" => field, "value" => v,
                                         "s_max_total" => smax_total)))
                end
            end
        end

        # PV prime movers inject only; a negative active-power floor is unphysical.
        if get(inv, "prime_mover", nothing) == "PV" &&
           pmin isa Number && Float64(pmin) < 0
            push!(findings, Finding(WARNING, "W.DOM.INV_PV_ABSORBS", :domain_rules,
                :ibr, id,
                "IBR '$id' is prime_mover=PV but has p_min = $(pmin) W < 0 — " *
                "PV cannot absorb active power; use prime_mover=BATTERY for " *
                "bidirectional devices.",
                Dict{String,Any}("p_min" => pmin)))
        end
    end
end

function _check_transformer_ratings(net, findings, thresh, n_checks)
    ratio_max = Float64(thresh["xfmr_ratio_max"])
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            vf = get(t, "v_ref_from", nothing)
            vt = get(t, "v_ref_to",   nothing)
            (vf === nothing || vt === nothing) && continue
            n_checks[] += 1
            vf_f, vt_f = Float64(vf), Float64(vt)

            # Non-positive v_ref yields an undefined or infinite turns ratio —
            # the OPF will fail to build.
            if vf_f <= 0 || vt_f <= 0
                push!(findings, Finding(ERROR, "E.DOM.XFMR_VREF_INVALID", :domain_rules,
                    :transformer, id,
                    "Transformer '$id' has non-positive v_ref_from=$(vf) V or " *
                    "v_ref_to=$(vt) V. The turns ratio N = v_ref_from/v_ref_to " *
                    "is undefined; the OPF cannot be built.",
                    Dict{String,Any}("v_ref_from" => vf, "v_ref_to" => vt)))
                continue
            end

            # direction-agnostic step ratio: 11kV/433V and 433V/11kV are the
            # same physical transformer
            step = max(vt_f / vf_f, vf_f / vt_f)
            if step > ratio_max
                push!(findings, Finding(WARNING, "W.DOM.XFMR_RATIO_OOB", :domain_rules,
                    :transformer, id,
                    "Transformer '$id' step ratio $(round(step, digits=1)):1 exceeds " *
                    "plausibility threshold $(ratio_max):1.",
                    Dict{String,Any}("step_ratio" => step,
                                     "v_ref_from" => vf_f, "v_ref_to" => vt_f)))
            end
        end
    end
end

# Isolating power transformers whose leakage impedance is physically meaningful.
# Regulators / autotransformers (single_phase_autotransformer, open_delta_regulator)
# are intentionally near-ideal tap changers and are excluded.
const _XFMR_LEAKAGE_SUBTYPES = ("single_phase", "center_tap", "wye_delta",
                                "delta_wye", "n_winding")

# Per-unit total series impedance of a transformer on its from-side rating base
# (Z_base = v_ref_from²/s_rating). Returns `nothing` when the base is undefined.
function _xfmr_z_pu(t::Dict, R::Real, X::Real)
    sbase = Float64(get(t, "s_rating",   0.0))
    vref  = Float64(get(t, "v_ref_from", 0.0))
    (sbase > 0 && vref > 0) || return nothing
    hypot(Float64(R), Float64(X)) / (vref^2 / sbase)
end

# Flag transformers carrying zero / near-zero placeholder leakage. The OPF uses
# the IVR formulation, where series impedance is a *coefficient* in the winding
# voltage-drop equation (`V_fr − N·V_to = R·I − X·jI`), not an inverted
# admittance, so:
#   • exactly-zero leakage collapses cleanly to the ideal constraint
#     `V_fr = N·V_to` — well-posed, NOT degenerate (INFO `I.DOM.XFMR_IDEAL`);
#   • a tiny non-zero leakage (a placeholder for zero carried over from an
#     admittance tool, which forbids exact zero) weakly constrains the series
#     current and is ill-conditioned — exact zero is better (WARNING
#     `W.DOM.XFMR_LOW_IMPEDANCE`, the transformer analogue of a low-impedance
#     line that should be a switch).
# A lossless unit (`R≈0` with realistic `X`) is entirely normal here and is not
# flagged.
function _check_transformer_ideal(net, findings, thresh, n_checks)
    ztol    = Float64(get(thresh, "xfmr_z_min_ohm", 1e-6))
    zpu_min = Float64(get(thresh, "xfmr_z_min_pu",  1e-3))
    xfmr = get(net, "transformer", Dict())
    for subtype in _XFMR_LEAKAGE_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            if subtype == "n_winding"
                xvals = Float64[Float64(v) for v in values(get(t, "x_sc", Dict()))]
                ws    = get(t, "windings", Any[])
                rvals = Float64[Float64(get(w, "r_winding", 0.0)) for w in ws if w isa Dict]
            else
                xvals = Float64[Float64(t[k]) for k in
                                ("x_series_from", "x_series_to", "x_series") if haskey(t, k)]
                rvals = Float64[Float64(t[k]) for k in
                                ("r_series_from", "r_series_to", "r_series") if haskey(t, k)]
            end
            isempty(xvals) && continue   # reactance unspecified → a completeness issue, not here
            n_checks[] += 1
            X = sum(abs, xvals)
            R = isempty(rvals) ? 0.0 : sum(abs, rvals)

            if X <= ztol
                kind = R <= ztol ? "ideal (lossless, zero-impedance)" :
                                   "zero-leakage (purely resistive)"
                push!(findings, Finding(INFO, "I.DOM.XFMR_IDEAL", :domain_rules,
                    :transformer, id,
                    "Transformer '$id' ($subtype) has zero leakage reactance (X≈$(X) Ω, " *
                    "R≈$(R) Ω) — modeled as an $kind transformer with no series voltage " *
                    "drop. The IVR OPF represents this as the exact voltage-ratio " *
                    "constraint V_fr = N·V_to (well-posed, not degenerate), but `%Z` was " *
                    "most likely omitted — supply realistic leakage (x ≈ 4–10 % on the " *
                    "rating base) if regulation across the winding matters.",
                    Dict{String,Any}("subtype" => subtype, "x_series_total" => X,
                                     "r_series_total" => R)))
                continue
            end

            # Small non-zero placeholder? (per-unit; n_winding bases differ — skip)
            subtype == "n_winding" && continue
            zpu = _xfmr_z_pu(t, R, X)
            (zpu !== nothing && 0 < zpu < zpu_min) || continue
            push!(findings, Finding(WARNING, "W.DOM.XFMR_LOW_IMPEDANCE", :domain_rules,
                :transformer, id,
                "Transformer '$id' ($subtype) has near-zero series impedance " *
                "(|Z| ≈ $(round(zpu, sigdigits=2)) pu < $(zpu_min) pu on the rating " *
                "base; real units are 1–15 %) — almost certainly a small placeholder " *
                "for zero carried over from an admittance-based tool. In this IVR " *
                "engine a tiny leakage ill-conditions the winding voltage-drop " *
                "equation, whereas exact zero collapses to the well-posed ideal " *
                "constraint V_fr = N·V_to. Set it to exactly zero (the fix recipe can, " *
                "via `apply_snap_transformer_impedance`) or to a realistic %Z.",
                Dict{String,Any}("subtype" => subtype, "z_pu" => zpu,
                                 "x_series_total" => X, "r_series_total" => R)))
        end
    end
end

function _check_nonnegative_fields(net, findings, n_checks)
    # Schema already enforces nonnegative_number via minimum:0, but JSON Schema
    # validation may not have run. Spot-check key fields.
    nonneg_checks = [
        ("line",    "length",        :line),
        ("linecode","R_series_1_1",  :linecode),
        ("linecode","X_series_1_1",  :linecode),
    ]
    for (comp_type, field, csym) in nonneg_checks
        for (id, comp) in get(net, comp_type, Dict())
            haskey(comp, field) || continue
            n_checks[] += 1
            val = comp[field]
            if val isa Number && Float64(val) < 0
                push!(findings, Finding(ERROR, "E.DOM.NEGATIVE_VALUE", :domain_rules,
                    csym, id,
                    "$comp_type '$id': $field = $val must be non-negative.",
                    Dict{String,Any}("field" => field, "value" => val)))
            end
        end
    end
end

# ---------------------------------------------------------------------------
# Impedance helpers
# ---------------------------------------------------------------------------

# Compute the Frobenius norm of the absolute series impedance matrix Z = (R+jX)*length
# for a line, resolving its linecode. Returns nothing if data is missing.
function _line_z_norm(line, linecodes)
    lc_id  = get(line, "linecode", nothing)
    lc_id isa AbstractString || return nothing
    lc = get(linecodes, lc_id, nothing)
    lc isa Dict || return nothing
    len = get(line, "length", nothing)
    len isa Number || return nothing
    len = Float64(len)
    len > 0 || return nothing
    R = _pattern_keys_to_matrix(lc, "R_series_")
    X = _pattern_keys_to_matrix(lc, "X_series_")
    R isa AbstractMatrix || return nothing
    X isa AbstractMatrix || return nothing
    # Frobenius norm of complex Z matrix scaled by length
    norm_val = 0.0
    for i in eachindex(R)
        norm_val += (R[i]*len)^2 + (X[i]*len)^2
    end
    sqrt(norm_val)
end

# ---------------------------------------------------------------------------
# Check 1: low-impedance lines that should be modelled as switches
# ---------------------------------------------------------------------------

function _check_low_impedance_lines(net, findings, thresh, n_checks)
    z_min = Float64(thresh["z_line_min_ohm"])
    linecodes = get(net, "linecode", Dict())
    for (id, line) in get(net, "line", Dict())
        line isa Dict || continue
        n_checks[] += 1
        z = _line_z_norm(line, linecodes)
        z === nothing && continue
        if z < z_min
            push!(findings, Finding(WARNING, "W.DOM.LINE_LOW_IMPEDANCE", :domain_rules,
                :line, id,
                "Line '$id' has ||Z||_F = $(round(z, sigdigits=3)) Ω < threshold " *
                "$(z_min) Ω — near-zero series impedance; consider replacing with " *
                "a switch object to avoid ill-conditioned KVL constraints.",
                Dict{String,Any}("z_norm_ohm" => z, "threshold" => z_min)))
        end
    end
end

# ---------------------------------------------------------------------------
# Check 2: adjacent lines with wildly different absolute impedances
# ---------------------------------------------------------------------------

function _check_adjacent_line_impedance_spread(net, findings, thresh, n_checks, result)
    z_info = Float64(thresh["z_spread_info"])
    z_warn = Float64(thresh["z_spread_warn"])
    linecodes = get(net, "linecode", Dict())
    lines = get(net, "line", Dict())

    # Buses that host a voltage source, transformer, or switch — excluded from
    # adjacency because fixed voltages or topology breaks remove those coupling rows
    # from the KKT system.
    excluded_buses = Set{String}()
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict && push!(excluded_buses, get(vs, "bus", ""))
    end
    for (_, sw) in get(net, "switch", Dict())
        sw isa Dict || continue
        push!(excluded_buses, get(sw, "bus_from", ""))
        push!(excluded_buses, get(sw, "bus_to",   ""))
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        for (_, t) in get(xfmr, subtype, Dict())
            t isa Dict || continue
            push!(excluded_buses, get(t, "bus_from", ""))
            push!(excluded_buses, get(t, "bus_to",   ""))
        end
    end

    # Build bus → [(line_id, z_norm)] index for lines with computable Z
    bus_lines = Dict{String, Vector{Tuple{String,Float64}}}()
    for (id, line) in lines
        line isa Dict || continue
        z = _line_z_norm(line, linecodes)
        z === nothing && continue
        for bus_field in ("bus_from", "bus_to")
            b = get(line, bus_field, "")
            b in excluded_buses && continue
            push!(get!(bus_lines, b, Tuple{String,Float64}[]), (id, z))
        end
    end

    # Find worst ratio across all qualifying adjacent pairs
    worst_ratio  = 1.0
    worst_pair   = ("", "")
    worst_bus    = ""

    for (bus, entries) in bus_lines
        length(entries) < 2 && continue
        n_checks[] += 1
        for i in eachindex(entries), j in (i+1):length(entries)
            id_a, za = entries[i]
            id_b, zb = entries[j]
            za == 0.0 || zb == 0.0 && continue
            ratio = max(za, zb) / min(za, zb)
            if ratio > worst_ratio
                worst_ratio = ratio
                worst_pair  = (id_a, id_b)
                worst_bus   = bus
            end
        end
    end

    result["max_adjacent_impedance_ratio"] = worst_ratio

    worst_ratio < z_info && return

    sev = worst_ratio >= z_warn ? WARNING : INFO
    code = worst_ratio >= z_warn ? "W.DOM.LINE_IMPEDANCE_SPREAD" : "I.DOM.LINE_IMPEDANCE_SPREAD"
    push!(findings, Finding(sev, code, :domain_rules, :line, nothing,
        "Adjacent lines '$(worst_pair[1])' and '$(worst_pair[2])' at bus '$worst_bus' " *
        "have ||Z||_F ratio $(round(worst_ratio, sigdigits=3))× — " *
        "large impedance contrasts between neighbouring lines cause ill-conditioned " *
        "KKT Jacobians; consider per-unit scaling or network reformulation.",
        Dict{String,Any}("line_a" => worst_pair[1], "line_b" => worst_pair[2],
                         "bus"    => worst_bus,
                         "ratio"  => worst_ratio,
                         "threshold_info" => z_info,
                         "threshold_warn" => z_warn)))
end
