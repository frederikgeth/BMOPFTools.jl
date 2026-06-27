# Data quality checks: shunt signs, voltage bound consistency/redundancy/overlap,
# i_max completeness, OpenDSS default fingerprints, and regulator patterns.

# ---------------------------------------------------------------------------
# Bus shunt sign/definiteness checks
# ---------------------------------------------------------------------------

"""
Sign/definiteness checks on bus-shunt admittance matrices: reciprocity and
G-block passivity. The B block carries no sign constraint (grounding
reactors are negative, capacitor banks positive), only symmetry.
"""
function _check_bus_shunts(net::Dict{String,Any}, findings::Vector{Finding})
    for (id, s) in get(net, "shunt", Dict())
        s isa Dict || continue
        for (prefix, isG) in (("G_", true), ("B_", false))
            M = _pattern_keys_to_matrix(s, prefix)
            M isa AbstractMatrix || continue
            scaleM = max(maximum(abs.(M)), 1e-300)
            if maximum(abs.(M - transpose(M))) / scaleM > 1e-6
                push!(findings, Finding(ERROR, "E.PROV.NONRECIPROCAL",
                    :provenance, :shunt, id,
                    "Shunt '$id' $(prefix)block is not symmetric — violates " *
                    "reciprocity (note: a delta capacitor bank's admittance is " *
                    "Y·(M∆)ᵀM∆, which is symmetric).", nothing))
            end
            if isG
                evg = eigvals(Symmetric((M + transpose(M)) / 2))
                if any(M[i, i] < -1e-12 for i in 1:size(M, 1)) ||
                   minimum(evg) < -1e-9 * max(maximum(abs.(evg)), 1e-12)
                    push!(findings, Finding(ERROR, "E.PROV.NEGATIVE_G",
                        :provenance, :shunt, id,
                        "Shunt '$id' conductance block is not positive " *
                        "semidefinite — an active (power-generating) element.",
                        nothing))
                end
            end
        end
    end
end

# ---------------------------------------------------------------------------
# Capacitor-bank detection
# ---------------------------------------------------------------------------
# A fixed capacitor bank, when carried as a generic `shunt`, is a purely
# capacitive admittance: no conductance (G ≈ 0) and a positive susceptance
# (`B = ωC > 0`; a reactor would be negative). Flag such shunts so they can be
# promoted to a first-class `capacitor` (nameplate q_rated/v_rated), optionally
# via the `apply_shunt_to_capacitor` fix pass.
function _check_capacitor_like_shunts(net::Dict{String,Any},
                                      findings::Vector{Finding})::Dict{String,Any}
    affected = String[]
    for (id, s) in get(net, "shunt", Dict())
        s isa Dict || continue
        B = _pattern_keys_to_matrix(s, "B_")
        B isa AbstractMatrix || continue
        G = _pattern_keys_to_matrix(s, "G_")
        bscale = max(maximum(abs, B), 1e-30)
        gmax   = G isa AbstractMatrix ? maximum(abs, G) : 0.0
        bdiag  = [B[i, i] for i in 1:size(B, 1)]
        # No conductance, and every diagonal susceptance strictly positive
        # (capacitive). Mixed/inductive banks (any negative diagonal) are excluded.
        (gmax <= 1e-9 * bscale && all(x -> x > 1e-12 * bscale, bdiag)) || continue
        push!(affected, id)
        push!(findings, Finding(INFO, "I.PROV.SHUNT_LIKELY_CAPACITOR", :provenance,
            :shunt, id,
            "Shunt '$id' is purely capacitive (no conductance, positive diagonal " *
            "susceptance) — it looks like a fixed capacitor bank. Consider modeling " *
            "it as a first-class `capacitor` (nameplate q_rated/v_rated); the fix " *
            "recipe can convert phase-to-ground banks automatically with " *
            "`FixRecipe(apply_shunt_to_capacitor = true)`.",
            Dict{String,Any}("b_diag" => bdiag, "g_max" => gmax)))
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

# ---------------------------------------------------------------------------
# Voltage bound checks
# ---------------------------------------------------------------------------

function _check_bus_voltage_bound_redundancy(net::Dict{String,Any},
                                              findings::Vector{Finding})::Dict{String,Any}
    affected = String[]
    for (bid, bus) in get(net, "bus", Dict())
        has_ground = get(bus, "v_min",   nothing) !== nothing ||
                     get(bus, "v_max",   nothing) !== nothing
        has_pn     = get(bus, "vpn_min", nothing) !== nothing ||
                     get(bus, "vpn_max", nothing) !== nothing
        (has_ground && has_pn) || continue

        grounded_set = Set(string.(get(bus, "perfectly_grounded_terminals", String[])))
        nt = _neutral_terminal(bus)
        (nt !== nothing && nt in grounded_set) || continue

        push!(affected, bid)
        push!(findings, Finding(WARNING, "W.PROV.REDUNDANT_VOLTAGE_BOUNDS",
            :provenance, :bus, bid,
            "Bus '$bid' has both phase-to-ground (`v_min`/`v_max`) and " *
            "phase-to-neutral (`vpn_min`/`vpn_max`) voltage bounds, but its " *
            "neutral terminal '$nt' is perfectly grounded — the two sets of " *
            "bounds are equivalent. Remove one to avoid duplicate constraints.",
            Dict{String,Any}("neutral_terminal" => nt)))
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

function _check_i_max_completeness(net::Dict{String,Any},
                                    findings::Vector{Finding})::Dict{String,Any}
    linecodes  = get(net, "linecode", Dict())

    # Lines: i_max lives on the linecode, indexed by conductor position.
    incomplete_lines = String[]
    absent_lines     = String[]
    for (lid, line) in get(net, "line", Dict())
        lcid = get(line, "linecode", nothing)
        lc   = lcid === nothing ? nothing : get(linecodes, lcid, nothing)
        i_max = lc === nothing ? nothing : get(lc, "i_max", nothing)
        if i_max === nothing
            push!(absent_lines, lid)   # no thermal limit anywhere on this branch
            continue
        end

        n_fr = length(get(line, "terminal_map_from", String[]))
        n_to = length(get(line, "terminal_map_to",   String[]))
        n_c  = min(n_fr, n_to)
        length(i_max) < n_c && push!(incomplete_lines, lid)
    end
    if !isempty(incomplete_lines)
        push!(findings, Finding(WARNING, "W.PROV.I_MAX_INCOMPLETE",
            :provenance, :line, nothing,
            "$(length(incomplete_lines)) line(s) have fewer `i_max` entries in their " *
            "linecode than conductors — current limits will not be enforced on " *
            "all conductors (the neutral conductor may be unprotected).",
            Dict{String,Any}("lines" => incomplete_lines)))
    end
    if !isempty(absent_lines)
        push!(findings, Finding(WARNING, "W.PROV.I_MAX_ABSENT",
            :provenance, :line, nothing,
            "$(length(absent_lines)) line(s) have no `i_max` on their linecode " *
            "(or no linecode at all) — their series current is left entirely " *
            "unconstrained in the OPF, so no thermal limit is enforced on the branch.",
            Dict{String,Any}("lines" => absent_lines)))
    end

    # Switches: i_max is on the switch element itself.
    incomplete_switches = String[]
    absent_switches     = String[]
    for (sid, sw) in get(net, "switch", Dict())
        sw isa Dict || continue
        i_max = get(sw, "i_max", nothing)
        if i_max === nothing
            # An open switch carries zero current by construction, so a missing
            # limit only leaves a *closed* switch unprotected.
            get(sw, "open_switch", false) || push!(absent_switches, sid)
            continue
        end

        n_fr = length(get(sw, "terminal_map_from", String[]))
        n_to = length(get(sw, "terminal_map_to",   String[]))
        n_c  = min(n_fr, n_to)
        length(i_max) < n_c && push!(incomplete_switches, sid)
    end
    if !isempty(incomplete_switches)
        push!(findings, Finding(WARNING, "W.PROV.I_MAX_INCOMPLETE_SWITCH",
            :provenance, :switch, nothing,
            "$(length(incomplete_switches)) switch(es) have fewer `i_max` entries " *
            "than conductors — current limits will not be enforced on all conductors.",
            Dict{String,Any}("switches" => incomplete_switches)))
    end
    if !isempty(absent_switches)
        push!(findings, Finding(WARNING, "W.PROV.I_MAX_ABSENT_SWITCH",
            :provenance, :switch, nothing,
            "$(length(absent_switches)) closed switch(es) have no `i_max` — their " *
            "current is left entirely unconstrained in the OPF, so no thermal limit " *
            "is enforced on the branch.",
            Dict{String,Any}("switches" => absent_switches)))
    end

    # Transformers: i_max_from / i_max_to are per-winding, indexed by conductor.
    # Expected lengths: len(terminal_map_from) and len(terminal_map_to) respectively.
    incomplete_xfmr = String[]
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (tid, xfmr) in sub
            xfmr isa Dict || continue
            n_fr = length(get(xfmr, "terminal_map_from", String[]))
            n_to = length(get(xfmr, "terminal_map_to",   String[]))
            i_fr = get(xfmr, "i_max_from", nothing)
            i_to = get(xfmr, "i_max_to",   nothing)
            fr_short = i_fr !== nothing && length(i_fr) < n_fr
            to_short = i_to !== nothing && length(i_to) < n_to
            (fr_short || to_short) && push!(incomplete_xfmr, "$subtype/$tid")
        end
    end
    if !isempty(incomplete_xfmr)
        push!(findings, Finding(WARNING, "W.PROV.I_MAX_INCOMPLETE_XFMR",
            :provenance, :transformer, nothing,
            "$(length(incomplete_xfmr)) transformer(s) have fewer `i_max_from` or " *
            "`i_max_to` entries than conductors — current limits will not be enforced " *
            "on all conductors.",
            Dict{String,Any}("transformers" => incomplete_xfmr)))
    end

    n_total = length(incomplete_lines) + length(incomplete_switches) + length(incomplete_xfmr) +
              length(absent_lines) + length(absent_switches)
    Dict{String,Any}(
        "n"                  => n_total,
        "lines"              => incomplete_lines,
        "switches"           => incomplete_switches,
        "transformers"       => incomplete_xfmr,
        "absent_lines"       => absent_lines,
        "absent_switches"    => absent_switches,
    )
end

function _check_bus_voltage_bound_consistency(net::Dict{String,Any},
                                               findings::Vector{Finding})::Dict{String,Any}
    affected = String[]
    bound_pairs = [("v_min", "v_max"), ("vpn_min", "vpn_max"),
                   ("vpp_min", "vpp_max"), ("vpos_min", "vpos_max"),
                   ("va_diff_min", "va_diff_max")]
    for (bid, bus) in get(net, "bus", Dict())
        issues = String[]
        for (lo, hi) in bound_pairs
            vlo = get(bus, lo, nothing)
            vhi = get(bus, hi, nothing)
            if vlo !== nothing && vhi !== nothing
                vlo_v = vlo isa AbstractVector ? Float64.(vlo) : [Float64(vlo)]
                vhi_v = vhi isa AbstractVector ? Float64.(vhi) : [Float64(vhi)]
                if any(lo_i > hi_i for (lo_i, hi_i) in zip(vlo_v, vhi_v))
                    push!(issues, "$lo ($vlo) > $hi ($vhi)")
                end
            end
        end
        if !isempty(issues)
            push!(affected, bid)
            push!(findings, Finding(ERROR, "E.PROV.INCONSISTENT_BOUNDS",
                :provenance, :bus, bid,
                "Bus '$bid' has voltage bounds where min > max — the OPF will be " *
                "infeasible: " * join(issues, "; ") * ".",
                Dict{String,Any}("issues" => issues)))
        end
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

function _check_bus_voltage_bound_applicability(net::Dict{String,Any},
                                                 findings::Vector{Finding})::Dict{String,Any}
    affected = String[]
    for (bid, bus) in get(net, "bus", Dict())
        all_terms    = string.(get(bus, "terminal_names", String[]))
        grounded_set = Set(string.(get(bus, "perfectly_grounded_terminals", String[])))
        nt           = _neutral_terminal(bus)
        has_neutral  = nt !== nothing
        n_phase      = count(t -> t ∉ grounded_set && t != nt, all_terms)

        issues = String[]
        if !has_neutral && (haskey(bus, "vpn_min") || haskey(bus, "vpn_max"))
            push!(issues, "vpn_min/vpn_max requires a neutral terminal")
        end
        if !has_neutral && haskey(bus, "vn_max")
            push!(issues, "vn_max requires a neutral terminal")
        end
        has_seq = any(k -> haskey(bus, k),
                      ("vpos_min", "vpos_max", "vneg_max", "vzero_max"))
        if has_seq && n_phase != 3
            push!(issues, "sequence bounds (vpos/vneg/vzero) require exactly 3 phase " *
                          "terminals (found $n_phase)")
        end
        if n_phase < 2 && (haskey(bus, "vpp_min") || haskey(bus, "vpp_max"))
            push!(issues, "vpp_min/vpp_max requires at least 2 phase terminals")
        end
        if n_phase < 2 && (haskey(bus, "va_diff_min") || haskey(bus, "va_diff_max"))
            push!(issues, "va_diff_min/va_diff_max (bus) requires at least 2 phase terminals")
        end
        # va_diff bounds are encoded as tan(·)·c ≤ s ≤ tan(·)·c, which is only a
        # faithful angle bound while the centered deviation stays inside
        # (−π/2, π/2). A window edge at or beyond π/2 crosses the tangent
        # singularity and silently inverts/aliases the constraint.
        for field in ("va_diff_min", "va_diff_max")
            v = get(bus, field, nothing)
            if v isa Number && abs(Float64(v)) >= π/2
                push!(issues, "$field=$(v) rad has magnitude ≥ π/2; the tangent " *
                              "angle-difference encoding is only valid within (−π/2, π/2)")
            end
        end
        # Array-length checks: va_nom and vpn_* must have length n_phase; vpp_*
        # must have length n_phase*(n_phase-1)/2.
        n_pairs = n_phase * (n_phase - 1) ÷ 2
        let v = get(bus, "va_nom", nothing)
            if v isa AbstractVector && length(v) != n_phase
                push!(issues, "va_nom has length $(length(v)), expected n_phase=$n_phase")
            end
        end
        for field in ("vpn_min", "vpn_max")
            v = get(bus, field, nothing)
            if v isa AbstractVector && length(v) != n_phase
                push!(issues, "$field has length $(length(v)), expected n_phase=$n_phase")
            end
        end
        for field in ("vpp_min", "vpp_max")
            v = get(bus, field, nothing)
            if v isa AbstractVector && length(v) != n_pairs
                push!(issues, "$field has length $(length(v)), expected n_pairs=$n_pairs")
            end
        end
        if !isempty(issues)
            push!(affected, bid)
            push!(findings, Finding(WARNING, "W.PROV.INAPPLICABLE_VOLTAGE_BOUNDS",
                :provenance, :bus, bid,
                "Bus '$bid' has voltage bounds that cannot be enforced and will be " *
                "silently ignored in the OPF: " * join(issues, "; ") * ".",
                Dict{String,Any}("issues" => issues)))
        end
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

function _check_bus_voltage_bound_overlap(net::Dict{String,Any},
                                           findings::Vector{Finding})::Dict{String,Any}
    bound_groups = [
        ("phase-to-ground",      ["v_min",     "v_max"]),
        ("phase-to-neutral",     ["vpn_min",   "vpn_max"]),
        ("phase-to-phase",       ["vpp_min",   "vpp_max"]),
        ("positive-sequence",    ["vpos_min",  "vpos_max"]),
        ("negative-sequence",    ["vneg_max"]),
        ("zero-sequence",        ["vzero_max"]),
        ("neutral-to-ground",    ["vn_max"]),
        ("intra-bus-angle",      ["va_diff_min", "va_diff_max"]),
    ]
    affected = String[]
    for (bid, bus) in get(net, "bus", Dict())
        active = [label for (label, keys) in bound_groups
                  if any(haskey(bus, k) for k in keys)]
        length(active) <= 1 && continue
        push!(affected, bid)
        push!(findings, Finding(INFO, "I.PROV.OVERLAPPING_VOLTAGE_BOUNDS",
            :provenance, :bus, bid,
            "Bus '$bid' has $(length(active)) voltage bound types active " *
            "($(join(active, ", "))) — all are enforced simultaneously, which is " *
            "valid but adds constraints and may slow the solver.",
            Dict{String,Any}("bound_types" => active)))
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected)
end

# ---------------------------------------------------------------------------
# Voltage-source phase-sequence / arrangement
# ---------------------------------------------------------------------------
# Classify every polyphase voltage source's stored `v_angle` and flag the
# arrangements that are degenerate or likely modeling errors. Unlike the
# ingest-time merge guard (`_phase_sequence_class`), this runs on EVERY source,
# including ones that arrived already-polyphase. Zero-, negative-sequence and
# incoherent rotations are flagged; valid positive-sequence (≈120° a→b→c),
# split-phase (≈180°) and two-phase (≈90°) supplies are recorded but not flagged
# on their own (a 180°/90° supply is legitimate — its consistency with downstream
# phase counts is checked separately in connectivity).
function _check_voltage_source_sequence(net::Dict{String,Any},
                                        findings::Vector{Finding})::Dict{String,Any}
    affected = String[]
    arrangements = Dict{String,String}()
    for (sid, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        tm  = Vector{String}(string.(get(vs, "terminal_map", String[])))
        va  = Float64.(get(vs, "v_angle", Float64[]))
        nt  = _neutral_terminal(tm)
        # Phase angles in terminal_map order, neutral dropped, aligned to v_angle.
        angs = Float64[]
        for (k, t) in enumerate(tm)
            (t == nt || lowercase(t) == "n") && continue
            k <= length(va) && push!(angs, va[k])
        end
        length(angs) >= 2 || continue   # single-phase: no rotation to classify

        arr = _phase_separation_class(angs)
        arrangements[sid] = string(arr)
        deg = round.(rad2deg.(angs); digits=1)

        code, msg = if arr === :zero
            ("W.PROV.SOURCE_ZERO_SEQUENCE",
             "Voltage source '$sid' has a zero-sequence angle profile " *
             "(v_angle ≈ $(deg)°): all phases share one angle — not a valid " *
             "positive-sequence supply. Fix the source angles and use positive-" *
             "sequence initialisation + va_diff/sequence bounds, or expect " *
             "convergence failure (cf. PSCC-2026 Table VI).")
        elseif arr === :negative
            ("W.PROV.SOURCE_NEGATIVE_SEQUENCE",
             "Voltage source '$sid' has a negative-sequence angle profile " *
             "(v_angle ≈ $(deg)°): rotation is reversed vs the a→b→c phase " *
             "labels — likely a phase-labelling error. Verify the source, and " *
             "match voltage initialisation to the intended rotation.")
        elseif arr === :incoherent
            ("W.PROV.SOURCE_INCOHERENT_ROTATION",
             "Voltage source '$sid' has an incoherent angle profile " *
             "(v_angle ≈ $(deg)°): the per-phase separations are not a " *
             "consistent ±120°, 90° or 180° set. Verify the source angles.")
        else
            ("", "")   # :positive / :anti_phase / :quadrature — valid, no finding
        end
        isempty(code) && continue
        push!(affected, sid)
        push!(findings, Finding(WARNING, code, :provenance, :voltage_source, sid, msg,
            Dict{String,Any}("v_angle_deg" => deg, "arrangement" => string(arr))))
    end
    Dict{String,Any}("n" => length(affected), "ids" => affected,
                     "arrangements" => arrangements)
end

# ---------------------------------------------------------------------------
# OpenDSS default fingerprints
# ---------------------------------------------------------------------------
# When a .dss file omits a property, OpenDSS substitutes a documented default.
# After conversion these look like deliberate data — except the values are
# very specific (mostly US/60 Hz flavored) and essentially never coincide
# with real engineering values elsewhere. Matching them flags fields the
# original modeler most likely never set.

const _DSS_Z1_DEFAULT = (0.058 + im * 0.1206) / 304.8   # Ω/kft → Ω/m
const _DSS_Z0_DEFAULT = (0.1784 + im * 0.4047) / 304.8
# Defaults from config/default.toml [provenance.dss_defaults].
const _DSS_NORMAMPS   = Float64(_dss_defaults_cfg()["normamps"])
const _DSS_EMERGAMPS  = Float64(_dss_defaults_cfg()["emergamps"])
const _DSS_XHL_PU     = Float64(_dss_defaults_cfg()["xhl_pu"])   # xhl = 7 %
const _DSS_RW_PU      = Float64(_dss_defaults_cfg()["rw_pu"])    # %r = 0.2 per winding, two windings
const _DSS_PF_TAN     = tan(acos(Float64(_dss_defaults_cfg()["pf"])))
const _DSS_KV_LL      = (Float64(_dss_defaults_cfg()["basekv_v"]),
                         Float64(_dss_defaults_cfg()["kv_v"]))   # basekv / kv defaults (V, LL)

# total per-unit series impedance of a transformer on its own rating base
function _xfmr_pu(t::Dict{String,Any}, subtype::String)
    s  = get(t, "s_rating", nothing)
    vf = get(t, "v_ref_from", nothing)
    vt = get(t, "v_ref_to",   nothing)
    (s === nothing || vf === nothing || vt === nothing) && return nothing
    s, vf, vt = Float64(s), Float64(vf), Float64(vt)
    (s > 0 && vf > 0 && vt > 0) || return nothing
    if subtype in ("wye_delta", "delta_wye")
        v_wye = subtype == "wye_delta" ? vf : vt
        zb = v_wye^2 / s
        r = haskey(t, "r_series") ? Float64(t["r_series"]) / zb : nothing
        x = haskey(t, "x_series") ? Float64(t["x_series"]) / zb : nothing
        return (r, x)
    else
        zbf, zbt = vf^2 / s, vt^2 / s
        r = haskey(t, "r_series_from") && haskey(t, "r_series_to") ?
            Float64(t["r_series_from"]) / zbf + Float64(t["r_series_to"]) / zbt :
            nothing
        x = haskey(t, "x_series_from") && haskey(t, "x_series_to") ?
            Float64(t["x_series_from"]) / zbf + Float64(t["x_series_to"]) / zbt :
            nothing
        return (r, x)
    end
end

# Coerce a `_pmd`-carried matrix (Matrix, nested vectors, or flat row-major
# vector) into a square Float64 matrix; symmetric inputs make orientation moot
function _as_square(x)
    x isa AbstractMatrix && return Float64.(x)
    if x isa AbstractVector
        isempty(x) && return nothing
        if x[1] isa AbstractVector
            return _to_matrix(x)
        end
        n = isqrt(length(x))
        n * n == length(x) || return nothing
        return reshape(Float64.(x), n, n)
    end
    nothing
end

function _check_opendss_defaults(net::Dict{String,Any},
                                  findings::Vector{Finding},
                                  lc_result::Dict{String,Any})::Dict{String,Any}
    res = Dict{String,Any}()
    n_hits = 0

    # --- default line constants (via recovered sequence parameters) ---
    dz = String[]
    for (id, e) in get(lc_result, "by_linecode", Dict())
        haskey(e, "z1") || continue
        z1 = complex(e["z1"]["r"], e["z1"]["x"])
        z0 = complex(e["z0"]["r"], e["z0"]["x"])
        if isapprox(z1, _DSS_Z1_DEFAULT; rtol=1e-3) &&
           isapprox(z0, _DSS_Z0_DEFAULT; rtol=1e-3)
            push!(dz, id)
        end
    end
    if !isempty(dz)
        n_hits += length(dz)
        push!(findings, Finding(WARNING, "W.PROV.DSS_DEFAULT_Z", :provenance,
            :linecode, nothing,
            "$(length(dz)) linecode(s) match the OpenDSS default line constants " *
            "(r1=0.058, x1=0.1206, r0=0.1784, x0=0.4047 Ω/kft — a fictitious " *
            "60 Hz overhead line); the source files likely omitted impedance " *
            "data: $(join(sort(dz), ", ")).",
            Dict{String,Any}("linecodes" => sort(dz))))
    end
    res["default_z_linecodes"] = sort(dz)

    # --- default ampacities (normamps 400 / emergamps 600) ---
    amp_hits = String[]
    for ct in ("linecode", "line", "switch")
        for (id, c) in get(net, ct, Dict())
            c isa Dict || continue
            v = get(c, "i_max", nothing)
            v === nothing && continue
            vals = v isa AbstractVector ? Float64.(v) : [Float64(v)]
            # i_max maps from normamps; emergamps (600) does not reach i_max,
            # and 600 A is a common genuine rating — fingerprint 400 only
            any(==(_DSS_NORMAMPS), vals) && push!(amp_hits, "$ct/$id")
        end
    end
    if !isempty(amp_hits)
        n_hits += length(amp_hits)
        push!(findings, Finding(INFO, "I.PROV.DSS_DEFAULT_AMPS", :provenance,
            :linecode, nothing,
            "$(length(amp_hits)) component(s) have i_max exactly 400 A or " *
            "600 A — the OpenDSS normamps/emergamps defaults; ratings were " *
            "likely never engineered.",
            Dict{String,Any}("components" => sort(amp_hits))))
    end

    # --- transformer defaults (xhl = 7 %, %r = 0.2/winding) ---
    xfmr_hits = String[]
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            pu = _xfmr_pu(t, subtype)
            pu === nothing && continue
            r_pu, x_pu = pu
            hit_x = x_pu !== nothing && isapprox(x_pu, _DSS_XHL_PU; rtol=1e-3)
            hit_r = r_pu !== nothing && isapprox(r_pu, _DSS_RW_PU;  rtol=1e-3)
            (hit_x || hit_r) && push!(xfmr_hits,
                "$id ($(hit_x ? "xhl=7%" : "")$(hit_x && hit_r ? ", " : "")$(hit_r ? "%r=0.2" : ""))")
        end
    end
    if !isempty(xfmr_hits)
        n_hits += length(xfmr_hits)
        push!(findings, Finding(INFO, "I.PROV.DSS_DEFAULT_XFMR", :provenance,
            :transformer, nothing,
            "$(length(xfmr_hits)) transformer(s) have impedance matching the " *
            "OpenDSS defaults — likely unspecified in the source: " *
            "$(join(sort(xfmr_hits), "; ")).",
            Dict{String,Any}("transformers" => sort(xfmr_hits))))
    end

    # --- default load power factor (pf = 0.88) ---
    pf_hits = String[]
    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        p = get(l, "p_nom", nothing); q = get(l, "q_nom", nothing)
        (p isa AbstractVector && q isa AbstractVector &&
         length(p) == length(q) && !isempty(p)) || continue
        pairs = [(Float64(p[i]), Float64(q[i])) for i in eachindex(p)
                 if Float64(p[i]) > 0]
        isempty(pairs) && continue
        all(isapprox(qq / pp, _DSS_PF_TAN; rtol=1e-3) for (pp, qq) in pairs) &&
            push!(pf_hits, id)
    end
    if !isempty(pf_hits)
        n_hits += length(pf_hits)
        push!(findings, Finding(INFO, "I.PROV.DSS_DEFAULT_PF", :provenance,
            :load, nothing,
            "$(length(pf_hits)) load(s) have power factor exactly 0.88 — the " *
            "OpenDSS default; reactive demand was likely never specified.",
            Dict{String,Any}("loads" => sort(pf_hits))))
    end

    # --- default voltages (basekv 115, kv 12.47) ---
    kv_hits = String[]
    for (id, vs) in get(net, "voltage_source", Dict())
        vm = get(vs, "v_magnitude", nothing)
        vm isa AbstractVector && !isempty(vm) || continue
        vmax = maximum(Float64.(vm))
        any(isapprox(vmax, kv / sqrt(3); rtol=1e-4) for kv in _DSS_KV_LL) &&
            push!(kv_hits, "voltage_source/$id")
    end
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(net, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            for f in ("v_ref_from", "v_ref_to")
                v = get(t, f, nothing)
                v === nothing && continue
                any(isapprox(Float64(v), kv; rtol=1e-4) for kv in _DSS_KV_LL) &&
                    push!(kv_hits, "transformer/$id ($f)")
            end
        end
    end
    if !isempty(kv_hits)
        n_hits += length(kv_hits)
        push!(findings, Finding(INFO, "I.PROV.DSS_DEFAULT_KV", :provenance,
            :network, nothing,
            "$(length(kv_hits)) component(s) sit exactly at an OpenDSS default " *
            "voltage (115 kV / 12.47 kV) — suspicious outside US test feeders: " *
            "$(join(sort(kv_hits), ", ")).",
            Dict{String,Any}("components" => sort(kv_hits))))
    end

    # --- default source impedance (MVAsc3 = 2000, X1R1 = 4) ---
    srcz_hits = String[]
    for (id, vs) in get(net, "voltage_source", Dict())
        pmd = get(vs, "_pmd", nothing)
        pmd isa Dict || continue
        Rs = _as_square(get(pmd, "rs", nothing))
        Xs = _as_square(get(pmd, "xs", nothing))
        (Rs isa AbstractMatrix && Xs isa AbstractMatrix &&
         size(Rs) == size(Xs) && size(Rs, 1) >= 3) || continue
        vm = get(vs, "v_magnitude", nothing)
        vm isa AbstractVector && !isempty(vm) || continue
        kV_LL = maximum(Float64.(vm)) * sqrt(3)
        Z = complex.(Rs, Xs)[1:3, 1:3]
        zs = (Z[1,1] + Z[2,2] + Z[3,3]) / 3
        zm = (Z[1,2] + Z[1,3] + Z[2,3]) / 3
        z1 = zs - zm
        zmag_def = kV_LL^2 / 2000e6                 # MVAsc3 default
        r1_def = zmag_def / sqrt(17)                # X1R1 = 4
        z1_def = complex(r1_def, 4r1_def)
        isapprox(z1, z1_def; rtol=5e-2) && push!(srcz_hits, id)
    end
    if !isempty(srcz_hits)
        n_hits += length(srcz_hits)
        push!(findings, Finding(WARNING, "W.PROV.DSS_DEFAULT_SOURCE_Z",
            :provenance, :voltage_source, nothing,
            "$(length(srcz_hits)) voltage source(s) have Thévenin impedance " *
            "matching the OpenDSS default (MVAsc3=2000, X1R1=4) — the fault " *
            "level is fictitious; the source files likely omitted it: " *
            "$(join(sort(srcz_hits), ", ")).",
            Dict{String,Any}("sources" => sort(srcz_hits))))
    end

    # --- default lengths (1.0): scattered = leak, universal = convention ---
    lens = [Float64(get(l, "length", NaN))
            for (_, l) in get(net, "line", Dict()) if haskey(l, "length")]
    n_one = count(==(1.0), lens)
    res["length_normalized"] = length(lens) >= 3 && n_one / length(lens) >= 0.9
    if n_one > 0 && !res["length_normalized"] && n_one / max(length(lens), 1) <= 0.5
        n_hits += n_one
        push!(findings, Finding(INFO, "I.PROV.DSS_DEFAULT_LENGTH", :provenance,
            :line, nothing,
            "$n_one of $(length(lens)) line(s) have length exactly 1.0 among " *
            "otherwise varied lengths — the OpenDSS default; these lengths " *
            "were likely never set.",
            nothing))
    end

    res["n_default_hits"] = n_hits
    res
end

# ---------------------------------------------------------------------------
# Switch-like line detection
# ---------------------------------------------------------------------------

# Threshold for "effectively zero" series impedance.
# Per-unit-length: < 1e-6 Ω/m on every diagonal entry.
# Effective (Z * length): < 1e-4 Ω total on every diagonal entry.
# Defaults from config/default.toml [provenance.switch_like].
const _SWITCH_LIKE_Z_PER_M  = Float64(_switch_like_cfg()["z_per_m"])   # Ω/m
const _SWITCH_LIKE_Z_TOTAL  = Float64(_switch_like_cfg()["z_total"])   # Ω

"""
    _check_switch_like_lines(net, findings) -> Dict{String,Any}

Flag lines whose series impedance is so small they are functionally switches.
Two independent conditions are checked for each line that references a linecode:

1. **Per-unit-length** — every diagonal entry of R and X (per metre) is below
   `$_SWITCH_LIKE_Z_PER_M` Ω/m. Catches very low-impedance linecodes regardless
   of line length.
2. **Effective total** — every diagonal entry of R·length and X·length is below
   `$_SWITCH_LIKE_Z_TOTAL` Ω. Catches short lines with otherwise normal impedance.

A line meeting either condition gets an `I.PROV.LINE_SWITCH_LIKE` info finding.
"""
function _check_switch_like_lines(net::Dict{String,Any},
                                   findings::Vector{Finding})::Dict{String,Any}
    linecodes = get(net, "linecode", Dict())
    hits = Dict{String, Vector{String}}()   # line_id => reasons

    for (lid, line) in get(net, "line", Dict())
        line isa Dict || continue
        lcid = get(line, "linecode", nothing)
        lcid === nothing && continue
        lc = get(linecodes, lcid, nothing)
        lc === nothing && continue

        R = _pattern_keys_to_matrix(lc, "R_series_")
        X = _pattern_keys_to_matrix(lc, "X_series_")
        (R isa AbstractMatrix) || continue
        n = size(R, 1)
        Xm = (X isa AbstractMatrix && size(X) == size(R)) ? X :
              zeros(Float64, n, n)

        reasons = String[]

        # Condition 1: per-unit-length impedance
        diag_r = [abs(R[k,k]) for k in 1:n]
        diag_x = [abs(Xm[k,k]) for k in 1:n]
        if all(<(_SWITCH_LIKE_Z_PER_M), diag_r) && all(<(_SWITCH_LIKE_Z_PER_M), diag_x)
            push!(reasons, "linecode impedance < $(_SWITCH_LIKE_Z_PER_M) Ω/m on all diagonals")
        end

        # Condition 2: effective total impedance (R * length, X * length)
        len = get(line, "length", nothing)
        if len !== nothing
            len_f = Float64(len)
            if all(<(_SWITCH_LIKE_Z_TOTAL), diag_r .* len_f) &&
               all(<(_SWITCH_LIKE_Z_TOTAL), diag_x .* len_f)
                push!(reasons, "effective impedance (Z·length) < $(_SWITCH_LIKE_Z_TOTAL) Ω on all diagonals")
            end
        end

        isempty(reasons) && continue
        hits[lid] = reasons
    end

    lines = get(net, "line", Dict())
    for (lid, reasons) in sort(collect(hits), by = x -> x[1])
        lcid = get(get(lines, lid, Dict()), "linecode", nothing)
        push!(findings, Finding(INFO, "I.PROV.LINE_SWITCH_LIKE", :provenance,
            :line, lid,
            "Line '$lid' has near-zero series impedance and may be modelled " *
            "more accurately as a switch: $(join(reasons, "; ")).",
            Dict{String,Any}("linecode" => lcid, "reasons" => reasons)))
    end

    Dict{String,Any}("n" => length(hits), "ids" => sort(collect(keys(hits))))
end

# ---------------------------------------------------------------------------
# Regulator / autotransformer encodings
# ---------------------------------------------------------------------------
# OpenDSS has no first-class regulator branch: modelers encode them either as
# a near-1:1 wye transformer (+RegControl), or — per the EPRI autotransformer
# guidance — as two windings on the SAME bus (common + ~10% series winding,
# kVA rated at the series winding) with a negligible-impedance jumper. The
# BMOPF data model has no regulator object, so these patterns deserve a flag:
# a controllable device has been frozen into (or hidden inside) a transformer.

function _check_regulator_patterns(net::Dict{String,Any},
                                    findings::Vector{Finding},
                                    vl::Dict{String,Any})
    vmap = get(vl, "bus_voltage_map", Dict())
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            evidence = String[]

            # Pattern B: explicit autotransformer — windings on one bus
            if f isa AbstractString && f == b
                push!(evidence, "both windings on bus '$f' (explicit " *
                                "autotransformer encoding)")
            end

            # Pattern A: near-1:1 regulator transformer (never delta-coupled)
            vf = get(t, "v_ref_from", nothing); vt = get(t, "v_ref_to", nothing)
            if isempty(evidence) && subtype == "single_phase" &&
               vf !== nothing && vt !== nothing && Float64(vf) > 0
                ratio = Float64(vt) / Float64(vf)
                if 0.85 <= ratio <= 1.176
                    corroborating = String[]
                    uf = get(vmap, f, nothing); ut = get(vmap, b, nothing)
                    if uf !== nothing && ut !== nothing &&
                       abs(uf - ut) / max(uf, 1.0) < 0.05
                        push!(corroborating, "connects buses at the same voltage level")
                    end
                    pu = _xfmr_pu(t, subtype)
                    if pu !== nothing && pu[2] !== nothing && pu[2] < 0.005
                        push!(corroborating,
                              "very low impedance (x≈$(round(pu[2]*100, sigdigits=2)) %)")
                    end
                    tm = get(get(t, "_pmd", Dict()), "tm_set", nothing)
                    if tm !== nothing &&
                       any(any(abs(Float64(x) - 1.0) > 1e-6 for x in w)
                           for w in tm if w isa AbstractVector)
                        push!(corroborating, "non-unity tap setting")
                    end
                    if !isempty(corroborating)
                        push!(evidence,
                              "near-unity ratio ($(round(ratio, digits=3))); " *
                              join(corroborating, "; "))
                    end
                end
            end

            if !isempty(evidence)
                push!(findings, Finding(WARNING, "W.PROV.REGULATOR_PATTERN",
                    :provenance, :transformer, id,
                    "transformer ($subtype) '$id' looks like a voltage " *
                    "regulator/autotransformer encoding: $(join(evidence, "; ")). " *
                    "The data model has no regulator object — verify whether a " *
                    "fixed-tap snapshot is intended; the control capability is " *
                    "otherwise silently lost.",
                    Dict{String,Any}("evidence" => evidence)))
            end
        end
    end
end
