# validation/wire_geometry.jl
#
# Physical realizability and model-assumption checks for the wire_data and
# line_geometry libraries, plus network-wide frequency consistency. Runs on
# the raw (uncompiled) dicts so datasets can be audited without compiling;
# `compile_linecode` independently hard-errors on the E-class violations and
# @warns on the assumption-validity ones.
#
# Split of severities (see docs/src/findings.md for the full rationale and
# literature references):
#   E — physically impossible (GMR > radius, overlapping conductors,
#       non-nesting cable layers): the data cannot describe a real conductor.
#   W — implausible values or inputs that strain the validity domain of the
#       analytical impedance models (Carson 1926; Deri et al. 1981;
#       Pollaczek 1926 / Saad et al. 1996; Kersting & Green 2011;
#       Jensen et al. 2001).
#   I — worth knowing (atypical current density).

# Metallic resistivity range for the implied-resistivity check [Ω·m]:
# annealed Cu 1.724e-8 (IEC 60228) … steel ~1.4e-7, widened for stranding /
# fill factor and temperature. A per-km value typed into a per-m field lands
# three decades outside this window.
const _RHO_IMPLIED_RANGE = (8e-9, 3e-7)
const _EPS_R_RANGE       = (1.5, 10.0)      # XLPE 2.3, EPR ~3, PVC 3–8
const _GMR_RATIO_MIN     = 0.2              # ACSR 6/1 ≈ 0.35 … 61-strand 0.826
const _J_RANGE_A_MM2     = (0.5, 10.0)      # typical continuous ratings 1–6
const _EARTH_RHO_RANGE   = (1.0, 1e4)       # practical soils 10–1000 Ω·m
const _CARSON_K_MAX      = 0.25             # truncation parameter guard
const _CLEARANCE_MIN     = 4.0              # [m] distribution statutory order
const _CLEARANCE_MAX     = 100.0            # [m] beyond any distribution pole

"Carson series parameter k = √(ωμ₀/ρ)·S for image distance S [m]."
_carson_k(S::Float64, f::Float64, rho::Float64)::Float64 =
    sqrt(2pi * f * _MU0 / rho) * S

"""
Critical skin/proximity frequency f_crit = ρ_c/(π r² μ₀ μᵣ) below which
constant r_ac and GMR-based internal inductance are valid (Jensen et al.
2001). ρ_c is the conductor's implied resistivity, r its radius, μᵣ = 1.
"""
_f_critical(rho_impl::Float64, r::Float64)::Float64 =
    rho_impl / (pi * r^2 * _MU0)

"Implied conductor resistivity ρ = r_dc·π·radius² [Ω·m], or `nothing`."
function _implied_resistivity(w::Dict{String,Any})::Union{Float64,Nothing}
    r = get(w, "r_dc", get(w, "r_ac", nothing))
    rad = get(w, "radius", nothing)
    (r === nothing || rad === nothing) && return nothing
    Float64(r) * pi * Float64(rad)^2
end

"Physical radius of a wire_data entry, falling back to gmr/0.7788."
function _wire_radius(w::Dict{String,Any})::Union{Float64,Nothing}
    haskey(w, "radius") && return Float64(w["radius"])
    haskey(w, "gmr")    && return Float64(w["gmr"]) / _GMR_FACTOR
    nothing
end

# ---------------------------------------------------------------------------
# wire_data checks
# ---------------------------------------------------------------------------

function _check_wire_data(net, findings, n_checks)
    for (id, w) in get(net, "wire_data", Dict())
        w isa Dict || continue
        n_checks[] += 1

        gmr = get(w, "gmr", nothing); rad = get(w, "radius", nothing)
        if gmr !== nothing && rad !== nothing
            g, r = Float64(gmr), Float64(rad)
            if g > r * (1 + 1e-9)
                push!(findings, Finding(ERROR, "E.DOM.WIRE_GMR_EXCEEDS_RADIUS",
                    :domain_rules, :wire_data, id,
                    "wire_data '$id': gmr ($(g) m) exceeds radius ($(r) m) — " *
                    "physically impossible; GMR ≤ radius for any internal " *
                    "current distribution (= 0.7788·radius for a solid round " *
                    "conductor, lower for stranded/ACSR).",
                    Dict{String,Any}("gmr" => g, "radius" => r)))
            elseif g / r < _GMR_RATIO_MIN
                push!(findings, Finding(WARNING, "W.DOM.WIRE_GMR_RATIO",
                    :domain_rules, :wire_data, id,
                    "wire_data '$id': gmr/radius = $(round(g / r, sigdigits=3)) " *
                    "is below $( _GMR_RATIO_MIN) — real conductors span " *
                    "~0.35 (ACSR 6/1) to 0.826 (61-strand); check for a " *
                    "units or transcription error.",
                    Dict{String,Any}("gmr_ratio" => g / r)))
            end
        end

        rdc = get(w, "r_dc", nothing); rac = get(w, "r_ac", nothing)
        if rdc !== nothing && rac !== nothing && Float64(rac) < Float64(rdc)
            push!(findings, Finding(WARNING, "W.DOM.WIRE_RAC_BELOW_RDC",
                :domain_rules, :wire_data, id,
                "wire_data '$id': r_ac ($(rac) Ω/m) < r_dc ($(rdc) Ω/m) — " *
                "skin and proximity effects can only increase resistance.",
                Dict{String,Any}("r_ac" => Float64(rac), "r_dc" => Float64(rdc))))
        end

        rho_impl = _implied_resistivity(w)
        if rho_impl !== nothing &&
           !(_RHO_IMPLIED_RANGE[1] <= rho_impl <= _RHO_IMPLIED_RANGE[2])
            push!(findings, Finding(WARNING, "W.DOM.WIRE_IMPLIED_RESISTIVITY",
                :domain_rules, :wire_data, id,
                "wire_data '$id': implied conductor resistivity " *
                "r·π·radius² = $(round(rho_impl, sigdigits=3)) Ω·m is outside " *
                "the metallic range [$(_RHO_IMPLIED_RANGE[1]), " *
                "$(_RHO_IMPLIED_RANGE[2])] (Cu 1.72e-8 per IEC 60228 … steel " *
                "~1.4e-7, allowing stranding/fill). A factor ~1e3 off usually " *
                "means an Ω/km value entered in the Ω/m field.",
                Dict{String,Any}("implied_resistivity" => rho_impl)))
        end

        eps_r = get(w, "eps_r", nothing)
        if eps_r !== nothing && !(_EPS_R_RANGE[1] <= Float64(eps_r) <= _EPS_R_RANGE[2])
            push!(findings, Finding(WARNING, "W.DOM.WIRE_EPS_R_RANGE",
                :domain_rules, :wire_data, id,
                "wire_data '$id': eps_r = $(eps_r) is outside the usual " *
                "insulation range [$(_EPS_R_RANGE[1]), $(_EPS_R_RANGE[2])] " *
                "(XLPE 2.3, EPR ~3, PVC 3–8; IEC 60287-1-1).",
                Dict{String,Any}("eps_r" => Float64(eps_r))))
        end

        imax = get(w, "i_max", nothing)
        radw = _wire_radius(w)
        if imax !== nothing && radw !== nothing && radw > 0
            j = Float64(imax) / (pi * radw^2 * 1e6)   # A/mm²
            if !(_J_RANGE_A_MM2[1] <= j <= _J_RANGE_A_MM2[2])
                push!(findings, Finding(INFO, "I.DOM.WIRE_CURRENT_DENSITY",
                    :domain_rules, :wire_data, id,
                    "wire_data '$id': i_max implies a current density of " *
                    "$(round(j, sigdigits=3)) A/mm² — outside the typical " *
                    "continuous-rating range " *
                    "[$(_J_RANGE_A_MM2[1]), $(_J_RANGE_A_MM2[2])] A/mm².",
                    Dict{String,Any}("current_density_A_mm2" => j)))
            end
        end

        _check_cable_layers(id, w, findings)
    end
end

# Cable layer radii must nest: core < insulation outer ≤ shield/strand circle
# ≤ overall. Violations make the construction unbuildable → ERROR.
function _check_cable_layers(id, w, findings)
    kind = get(w, "kind", "")
    kind in ("cn_cable", "ts_cable") || return
    layer_error(msg) = push!(findings, Finding(ERROR, "E.DOM.WIRE_CABLE_LAYERS",
        :domain_rules, :wire_data, id,
        "wire_data '$id': $msg — cable layers must nest radially.", nothing))

    radw  = _wire_radius(w)
    d_ins = get(w, "d_insulation", nothing)
    t_ins = get(w, "t_insulation", nothing)
    if d_ins !== nothing
        r_ins = Float64(d_ins) / 2
        radw !== nothing && radw >= r_ins &&
            layer_error("core radius ($(radw) m) ≥ insulation outer radius ($(r_ins) m)")
        t_ins !== nothing && Float64(t_ins) >= r_ins &&
            layer_error("t_insulation ($(t_ins) m) ≥ d_insulation/2 ($(r_ins) m)")
    end
    if kind == "cn_cable" && haskey(w, "d_cable") && haskey(w, "d_strand")
        R = (Float64(w["d_cable"]) - Float64(w["d_strand"])) / 2
        R <= 0 &&
            layer_error("d_strand ($(w["d_strand"]) m) ≥ d_cable ($(w["d_cable"]) m)")
        d_ins !== nothing && R > 0 && R < Float64(d_ins) / 2 &&
            layer_error("concentric-neutral strand circle radius ($(R) m) lies " *
                        "inside the insulation (d_insulation/2 = $(Float64(d_ins)/2) m)")
    end
    if kind == "ts_cable" && haskey(w, "d_shield")
        d_ins !== nothing && Float64(w["d_shield"]) < Float64(d_ins) &&
            layer_error("d_shield ($(w["d_shield"]) m) < d_insulation ($(d_ins) m)")
        haskey(w, "d_cable") && Float64(w["d_shield"]) > Float64(w["d_cable"]) &&
            layer_error("d_shield ($(w["d_shield"]) m) > d_cable ($(w["d_cable"]) m)")
    end
end

# ---------------------------------------------------------------------------
# line_geometry checks
# ---------------------------------------------------------------------------

function _check_line_geometry(net, findings, n_checks)
    wire_lib = get(net, "wire_data", Dict())
    for (id, geo) in get(net, "line_geometry", Dict())
        geo isa Dict || continue
        conds = get(geo, "conductors", nothing)
        conds isa AbstractVector || continue
        n_checks[] += 1

        model = string(get(geo, "earth_model", "modified_carson"))
        rho   = Float64(get(geo, "earth_resistivity", 100.0))
        f     = haskey(geo, "frequency") ? Float64(geo["frequency"]) : nothing

        if !(_EARTH_RHO_RANGE[1] <= rho <= _EARTH_RHO_RANGE[2])
            push!(findings, Finding(WARNING, "W.DOM.GEOM_EARTH_RESISTIVITY",
                :domain_rules, :line_geometry, id,
                "line_geometry '$id': earth_resistivity = $rho Ω·m is outside " *
                "[$(_EARTH_RHO_RANGE[1]), $(_EARTH_RHO_RANGE[2])] — practical " *
                "soils span ~10–1000 Ω·m.",
                Dict{String,Any}("earth_resistivity" => rho)))
        end

        # gather positions / radii / wire refs (skip unresolved wires —
        # E.INT.UNKNOWN_WIRE_DATA covers those)
        xs = Float64[]; ys = Float64[]; radii = Union{Float64,Nothing}[]
        kinds = String[]; wids = String[]
        for c in conds
            c isa Dict || continue
            haskey(c, "x") && haskey(c, "y") || continue
            push!(xs, Float64(c["x"])); push!(ys, Float64(c["y"]))
            w = get(wire_lib, string(get(c, "wire_data", "")), nothing)
            push!(radii, w isa Dict ? _wire_radius(w) : nothing)
            push!(kinds, w isa Dict ? string(get(w, "kind", "")) : "")
            push!(wids,  string(get(c, "wire_data", "")))
        end
        n = length(xs)

        # conductor circles must not overlap
        for i in 1:n, j in i+1:n
            (radii[i] === nothing || radii[j] === nothing) && continue
            d = hypot(xs[i] - xs[j], ys[i] - ys[j])
            if d < radii[i] + radii[j] - 1e-12
                push!(findings, Finding(ERROR, "E.DOM.GEOM_CONDUCTOR_OVERLAP",
                    :domain_rules, :line_geometry, id,
                    "line_geometry '$id': conductors $i and $j overlap — " *
                    "centre distance $(round(d, sigdigits=4)) m < sum of " *
                    "radii $(round(radii[i] + radii[j], sigdigits=4)) m.",
                    Dict{String,Any}("conductors" => [i, j], "distance" => d)))
            end
        end

        # overhead clearance plausibility (unit-slip catcher: ft as m)
        for i in 1:n
            kinds[i] == "overhead" || continue
            if 0 < ys[i] < _CLEARANCE_MIN || ys[i] > _CLEARANCE_MAX
                push!(findings, Finding(WARNING, "W.DOM.GEOM_CLEARANCE",
                    :domain_rules, :line_geometry, id,
                    "line_geometry '$id': overhead conductor $i at height " *
                    "$(ys[i]) m — below typical statutory clearance " *
                    "($( _CLEARANCE_MIN) m) or implausibly high " *
                    "(> $(_CLEARANCE_MAX) m); check for a feet-as-metres slip.",
                    Dict{String,Any}("conductor" => i, "y" => ys[i])))
                break   # one finding per geometry suffices
            end
        end

        f === nothing && continue   # remaining checks need the frequency

        # Carson truncation validity: k = √(ωμ₀/ρ)·S must stay ≪ 1
        # (Carson 1926; Kersting & Green 2011). Image distances need heights;
        # buried conductors sit at the surface for this estimate.
        if model in ("modified_carson", "full_carson") && n >= 1
            kmax = 0.0
            for i in 1:n
                hi = max(ys[i], 0.0)
                kmax = max(kmax, _carson_k(max(2hi, 1e-3), f, rho))
                for j in i+1:n
                    S = hypot(xs[i] - xs[j], max(ys[i], 0.0) + max(ys[j], 0.0))
                    kmax = max(kmax, _carson_k(max(S, 1e-3), f, rho))
                end
            end
            if kmax > _CARSON_K_MAX
                push!(findings, Finding(WARNING, "W.DOM.GEOM_CARSON_VALIDITY",
                    :domain_rules, :line_geometry, id,
                    "line_geometry '$id': Carson series parameter " *
                    "k = √(ωμ₀/ρ)·S reaches $(round(kmax, sigdigits=3)) " *
                    "(> $(_CARSON_K_MAX)) — the low-order truncation used by " *
                    "$(model) degrades for wide spacings, low earth " *
                    "resistivity, or high frequency (Carson 1926; Kersting & " *
                    "Green 2011). Consider earth_model = \"deri\".",
                    Dict{String,Any}("k_max" => kmax)))
            end
        end

        # buried conductors vs earth model
        if any(<(0.0), ys)
            if model == "full_carson"
                push!(findings, Finding(WARNING, "W.DOM.GEOM_BURIED_EARTH_MODEL",
                    :domain_rules, :line_geometry, id,
                    "line_geometry '$id': buried conductor(s) with " *
                    "earth_model = \"full_carson\" — the engine evaluates them " *
                    "at the surface; the rigorous buried-conductor theory is " *
                    "Pollaczek (1926) / Saad et al. (1996). Negligible at " *
                    "power frequency (burial depth ≪ earth skin depth), but " *
                    "the approximation is now explicit.", nothing))
            elseif model == "deri"
                p_mag = sqrt(rho / (2pi * f * _MU0))   # |complex depth| ~ /√2 factor omitted, conservative
                dmax = -minimum(ys)
                if dmax > 0.1 * p_mag
                    push!(findings, Finding(WARNING, "W.DOM.GEOM_BURIED_EARTH_MODEL",
                        :domain_rules, :line_geometry, id,
                        "line_geometry '$id': burial depth $(dmax) m exceeds " *
                        "10 % of the complex-depth magnitude " *
                        "($(round(p_mag, sigdigits=3)) m) — Deri's image " *
                        "approximation assumes |y| ≪ |p| (Deri et al. 1981).",
                        Dict{String,Any}("depth" => dmax, "p_mag" => p_mag)))
                end
            end
        end

        # skin/proximity validity: f must stay below f_crit for every wire
        for i in 1:n
            w = get(wire_lib, wids[i], nothing)
            w isa Dict || continue
            rho_impl = _implied_resistivity(w)
            r = radii[i]
            (rho_impl === nothing || r === nothing || r <= 0) && continue
            fc = _f_critical(rho_impl, r)
            if f > fc
                push!(findings, Finding(WARNING, "W.DOM.WIRE_SKIN_FREQUENCY",
                    :domain_rules, :line_geometry, id,
                    "line_geometry '$id': frequency $(f) Hz exceeds the " *
                    "critical skin frequency $(round(fc, sigdigits=3)) Hz of " *
                    "wire '$(wids[i])' — constant r_ac and GMR-based internal " *
                    "inductance degrade above f_crit = ρ/(π r² μ₀) (Jensen et " *
                    "al. 2001; Urquhart & Thomson 2015).",
                    Dict{String,Any}("wire_data" => wids[i], "f_critical" => fc)))
                break
            end
        end
    end
end

# ---------------------------------------------------------------------------
# frequency consistency — check-only; nothing is ever defaulted or rescaled
# ---------------------------------------------------------------------------

function _check_frequency_consistency(net, findings, n_checks)
    entries = Tuple{String,String,Float64}[]   # (component_type, id, f)
    for (id, geo) in get(net, "line_geometry", Dict())
        geo isa Dict && haskey(geo, "frequency") &&
            push!(entries, ("line_geometry", id, Float64(geo["frequency"])))
    end
    for (id, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        d = get(lc, "derivation", nothing)
        d isa Dict && haskey(d, "frequency") &&
            push!(entries, ("linecode", id, Float64(d["frequency"])))
    end
    isempty(entries) && return
    n_checks[] += 1

    f_meta = get(get(net, "meta", Dict()), "frequency", nothing)
    if f_meta !== nothing
        fm = Float64(f_meta)
        off = [(t, id, f) for (t, id, f) in entries if !isapprox(f, fm; rtol=1e-9)]
        if !isempty(off)
            desc = join(("$t '$id' ($(f) Hz)" for (t, id, f) in off), ", ")
            push!(findings, Finding(WARNING, "W.DOM.FREQUENCY_MISMATCH",
                :domain_rules, :network, nothing,
                "meta.frequency is $(fm) Hz but $(length(off)) object(s) " *
                "declare a different frequency: $desc. Frequencies are never " *
                "rescaled — recompile or fix the data.",
                Dict{String,Any}("meta_frequency" => fm,
                                 "offenders" => [Dict("type" => t, "id" => id,
                                                      "frequency" => f)
                                                 for (t, id, f) in off])))
        end
    else
        fs = sort(unique(round.(getindex.(entries, 3), digits=6)))
        if length(fs) > 1
            push!(findings, Finding(WARNING, "W.DOM.MIXED_FREQUENCY",
                :domain_rules, :network, nothing,
                "line_geometry / linecode-derivation frequencies disagree " *
                "within one network: $(fs) Hz. Set meta.frequency and " *
                "recompile the outliers — impedances at different " *
                "frequencies must not share a network.",
                Dict{String,Any}("frequencies" => fs)))
        end
    end
end

# ---------------------------------------------------------------------------
# Inline absolute line impedances — plausibility of the implied per-length
# values when a descriptive length is present. Catches per-metre data
# mislabeled as section totals (and vice versa).
# ---------------------------------------------------------------------------

# Plausible per-metre self-impedance magnitude for distribution conductors
# [Ω/m]: heavy MV feeders ~1e-4 up to thin SWER/service wire ~5e-3, widened.
const _Z_PER_M_RANGE = (1e-6, 1e-2)

function _check_inline_line_impedance(net, findings, n_checks)
    for (id, l) in get(net, "line", Dict())
        l isa Dict && _line_has_inline_z(l) || continue
        len = get(l, "length", nothing)
        len isa Number && Float64(len) > 0 || continue
        n_checks[] += 1
        R = _pattern_keys_to_matrix(l, "R_series_")
        X = _pattern_keys_to_matrix(l, "X_series_")
        R isa AbstractMatrix || continue
        n = size(R, 1)
        Xm = (X isa AbstractMatrix && size(X) == size(R)) ? X : zeros(n, n)
        z_self = maximum(hypot(R[i, i], Xm[i, i]) for i in 1:n)
        z_pm = z_self / Float64(len)
        if !(_Z_PER_M_RANGE[1] <= z_pm <= _Z_PER_M_RANGE[2])
            push!(findings, Finding(WARNING, "W.DOM.LINE_IMPLIED_PER_LENGTH",
                :domain_rules, :line, id,
                "Line '$id' carries inline ABSOLUTE matrices and a length of " *
                "$(len) m, implying $(round(z_pm, sigdigits=3)) Ω/m self " *
                "impedance — outside the plausible distribution range " *
                "$(_Z_PER_M_RANGE) Ω/m. Inline line matrices are section " *
                "totals [Ω], never scaled by length; check the values are " *
                "not per-metre data mislabeled as totals.",
                Dict{String,Any}("implied_z_per_m" => z_pm,
                                 "z_self_ohm" => z_self,
                                 "length" => Float64(len))))
        end
    end
end
