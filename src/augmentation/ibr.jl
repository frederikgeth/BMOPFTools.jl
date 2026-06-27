# IBR augmentation pass.
#
# Derives missing P and Q bounds for IBR objects before the OPF is run.
#
# P bounds
# ────────
# If p_max is absent, it is derived per phase from p_avail (split equally) or
# from the per-phase s_max ratings.  For PV prime movers p_min = 0 is also
# injected when absent (no active-power absorption).
#
# Q bounds
# ────────
# If an IBR references a control_profile with a "power_factor" sub-object,
# q_min/q_max are left absent — the OPF engine enforces the exact PF coupling
# as a bilinear equality constraint (Q = f(P)).
#
# For all other ibrs that lack explicit q_min/q_max, symmetric bounds are
# derived from p_max using the recipe's ibr_default_pf (EN 50549-1 default
# cos φ = 0.90 for LV-connected DERs).

function _apply_ibr_augmentation!(net′::Dict{String,Any},
                                        entries::Vector{TransformEntry},
                                        r::AugmentationRecipe)
    ibrs = get(net′, "ibr", Dict())
    isempty(ibrs) && return
    profiles  = get(net′, "control_profile", Dict())

    pf      = r.ibr_default_pf
    rule    = "EN50549-1:2019_cos_phi_$(round(pf, digits=3))_ibr_default"
    tan_phi = tan(acos(pf))

    for (inv_id, inv) in ibrs
        inv isa Dict || continue
        tm      = Vector{String}(get(inv, "terminal_map", String[]))
        n_phase = length(tm) - 1
        n_phase >= 1 || continue

        smax_arr = let s = get(inv, "s_max", nothing)
            s isa AbstractVector ? Float64.(s) : Float64[]
        end

        # ── P bounds ─────────────────────────────────────────────────────────
        if !haskey(inv, "p_max")
            p_avail = get(inv, "p_avail", nothing)
            p_max_vec = if p_avail isa Number
                fill(Float64(p_avail) / n_phase, n_phase)
            elseif length(smax_arr) >= n_phase
                smax_arr[1:n_phase]
            else
                nothing
            end
            if p_max_vec !== nothing
                inv["p_max"] = p_max_vec
                src = p_avail !== nothing ? "p_avail ÷ $(n_phase) phase(s)" :
                                            "s_max per phase"
                push!(entries, TransformEntry(
                    :ibr, inv_id, "p_max", nothing, p_max_vec,
                    "ibr_p_bound", :standard,
                    "p_max derived from $src"))
            end
        end

        if !haskey(inv, "p_min") && get(inv, "prime_mover", nothing) == "PV"
            pmin = fill(0.0, n_phase)
            inv["p_min"] = pmin
            push!(entries, TransformEntry(
                :ibr, inv_id, "p_min", nothing, pmin,
                "PV_prime_mover_unidirectional", :standard,
                "PV cannot absorb active power; p_min = 0 per phase"))
        end

        # ── Q bounds (only when no PF control profile) ───────────────────────
        has_pf_profile = let cp_id = get(inv, "control_profile", nothing)
            if cp_id isa String
                cp = get(profiles, cp_id, nothing)
                cp isa Dict && haskey(cp, "power_factor")
            else
                false
            end
        end

        if !has_pf_profile && !haskey(inv, "q_min") && !haskey(inv, "q_max")
            p_max = get(inv, "p_max", nothing)
            p_max isa AbstractVector || continue
            isempty(p_max) && continue

            q_max_vec = Float64.(p_max) .* tan_phi
            q_min_vec = -q_max_vec

            inv["q_min"] = q_min_vec
            inv["q_max"] = q_max_vec

            push!(entries, TransformEntry(
                :ibr, inv_id, "q_min", nothing, q_min_vec,
                rule, :standard,
                "Q_min = -P_max × tan(arccos($(pf)))"))
            push!(entries, TransformEntry(
                :ibr, inv_id, "q_max", nothing, q_max_vec,
                rule, :standard,
                "Q_max = P_max × tan(arccos($(pf))) ≈ $(round(tan_phi, digits=3)) × P_max"))
        end
    end
end

# Smart-IBR (Volt-var / Volt-watt) default-characteristic augmentation.
#
# Config-driven (mirrors the voltage-snap pass): when [augment.smart_ibr] is
# enabled, any volt_var/volt_watt sub-object that a control_profile declares but
# leaves blank is filled from the selected regional preset (e.g. AS/NZS 4777.2:2020
# "Aus_A" for Queensland). Fields already present are never overwritten, so a
# study can pin individual breakpoints and let the rest default.
function _apply_smart_ibr_augmentation!(net′::Dict{String,Any},
                                              entries::Vector{TransformEntry},
                                              cfg::Dict)
    get(cfg, "enabled", false) === true || return
    region  = String(get(cfg, "region", "Aus_A"))
    regions = get(cfg, "regions", Dict())
    rdef    = get(regions, region, nothing)
    rdef isa Dict || (@warn "smart_ibr: region '$region' not found in config — skipping"; return)

    profiles = get(net′, "control_profile", Dict())
    profiles isa Dict || return

    for (cp_id, cp) in profiles
        cp isa Dict || continue
        for law in ("volt_var", "volt_watt")
            sub = get(cp, law, nothing)
            sub isa Dict || continue            # only fill a declared sub-object
            rlaw = get(rdef, law, nothing)
            rlaw isa Dict || continue
            for (field, val) in rlaw
                haskey(sub, field) && continue  # respect explicit values
                sub[field] = deepcopy(val)
                push!(entries, TransformEntry(
                    :control_profile, cp_id, "$(law).$(field)", nothing, val,
                    "AS_NZS_4777.2:2020_$(region)_$(law)_default", :standard,
                    "$(law) $(field) defaulted from region $(region)"))
            end
        end
    end
end
