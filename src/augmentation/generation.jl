# Generation pass: slack cost assignment and reactive capability bounds.
#
# Slack cost
# ──────────
# The voltage source IS the network's current slack (see ext/BMOPFOpfExt/source.jl).
# If a source has no cost yet, a non-zero per-phase cost is written onto the
# voltage_source so imported slack power is priced in the OPF objective. No phantom
# slack generator is created. This mirrors the from_pmd convention.
#
# Reactive bounds
# ───────────────
# For each existing generator that has p_max defined but lacks q_min/q_max,
# symmetric reactive bounds are derived from the recipe power-factor setting:
#   Q_max = P_max × tan(arccos(pf))
# Default: pf = 0.90 (EN 50549-1:2019, LV grid-connected DERs).

function _q_rule(pf::Float64)::String
    pf ≈ 0.90 && return "EN50549-1:2019_cos_phi_0.90"
    pf ≈ 0.95 && return "IEEE1547-2018_cos_phi_0.95"
    return "cos_phi=$(round(pf, digits=3))"
end

function _apply_generation!(net′::Dict{String,Any},
                              entries::Vector{TransformEntry},
                              r::AugmentationRecipe)
    gens = get!(net′, "generator", Dict{String,Any}())

    # ── Slack cost on the voltage source ────────────────────────────────────────
    if r.apply_slack_generator
        for (vsid, vs) in get(net′, "voltage_source", Dict())
            vs isa Dict || continue
            src_bus = get(vs, "bus", nothing)
            src_bus isa String || continue

            # Don't overwrite an existing cost
            haskey(vs, "cost") && continue

            tm = string.(get(vs, "terminal_map", String[]))
            isempty(tm) && continue
            n_phases = length(tm)

            vs["cost"] = fill(r.slack_cost, n_phases)
            push!(entries, TransformEntry(
                :voltage_source, vsid, "cost", nothing, vs["cost"],
                "TFspec_Eq135_slack_generation", :standard,
                "priced slack at source bus '$(src_bus)'; " *
                "cost=$(r.slack_cost) \$/kWh on $(n_phases) phase(s)"))
        end
    end

    # ── Reactive capability bounds ────────────────────────────────────────────
    if r.apply_q_bounds
        pf   = r.q_capability_pf
        rule = _q_rule(pf)
        tan_phi = tan(acos(pf))

        for (gid, g) in gens
            g isa Dict || continue
            (haskey(g, "q_min") || haskey(g, "q_max")) && continue
            p_max = get(g, "p_max", nothing)
            p_max isa AbstractVector || continue
            isempty(p_max) && continue

            q_max_vec = Float64.(p_max) .* tan_phi
            q_min_vec = -q_max_vec

            g["q_min"] = q_min_vec
            g["q_max"] = q_max_vec

            push!(entries, TransformEntry(
                :generator, gid, "q_min", nothing, q_min_vec,
                rule, :standard,
                "Q_min = -P_max × tan(arccos($(pf)))"))
            push!(entries, TransformEntry(
                :generator, gid, "q_max", nothing, q_max_vec,
                rule, :standard,
                "Q_max = P_max × tan(arccos($(pf))) ≈ $(round(tan_phi, digits=3)) × P_max"))
        end
    end
end

# Standardise a single-phase device's `i_max` to the per-conductor [phase, neutral]
# form. A single-phase generator/IBR has ONE current (the phase and its return
# carry the same magnitude), so a length-1 `i_max` is duplicated to length 2 — the
# canonical per-conductor shape — without changing the physics (the engine still
# stamps a single current circle). Star devices with ≥2 phases are left untouched
# (their neutral rating, if any, is a genuinely independent value).
function _normalize_single_phase_imax!(net′::Dict{String,Any},
                                       entries::Vector{TransformEntry})
    pad!(ctype, id, dev, is_single) = begin
        is_single || return
        v = get(dev, "i_max", nothing)
        (v isa AbstractVector && length(v) == 1) || return
        old = copy(v)
        dev["i_max"] = [Float64(v[1]), Float64(v[1])]
        push!(entries, TransformEntry(ctype, id, "i_max", old, dev["i_max"],
            "per_conductor_imax_single_phase", :standard,
            "single-phase i_max standardised to per-conductor [phase, neutral]"))
    end
    for (gid, g) in get(net′, "generator", Dict())
        g isa Dict || continue
        is_single = get(g, "configuration", "WYE") != "DELTA" &&
                    length(Vector{String}(get(g, "terminal_map", String[]))) == 2
        pad!(:generator, gid, g, is_single)
    end
    for (iid, inv) in get(net′, "ibr", Dict())
        inv isa Dict || continue
        pad!(:ibr, iid, inv, get(inv, "topology", "") == "SINGLE_PHASE")
    end
end
