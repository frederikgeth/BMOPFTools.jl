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
#
# STATCOM prime movers
# ────────────────────
# A STATCOM (or D-STATCOM in distribution parlance) is a shunt-connected VSC
# with no active-power source: it exchanges purely reactive power, bounded by
# the converter apparent-power rating. It is therefore an IBR with P clamped to
# zero (converter losses neglected at this fidelity) and the full per-phase
# s_max made available as symmetric reactive capability (q_max = s_max).

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
        # Phase-current count follows the topology: length(tm) - 1 assumes a
        # neutral and undercounts a THREE_LEG (delta) IBR by one, truncating the
        # per-phase p_max/q_max boxes it writes below.
        n_phase, _ = _ibr_phase_count(get(inv, "topology", "FOUR_LEG"), tm)
        n_phase >= 1 || continue

        smax_arr = let s = get(inv, "s_max", nothing)
            s isa AbstractVector ? Float64.(s) : Float64[]
        end

        prime_mover = get(inv, "prime_mover", nothing)
        is_statcom  = prime_mover in ("STATCOM", "DSTATCOM")
        dc_coupled  = get(inv, "dc_link_coupled", false) === true

        # ── STATCOM: shunt converter with no active source ───────────────────
        # Reactive-only (default): each phase's active power is clamped to zero.
        # DC-link-coupled: the phases share one DC link, so per-phase active
        # power is free within the s_max circle but the *net* active power is
        # zero — the converter circulates active power between phases to balance
        # an unbalanced feeder (Heidari & Geth 2024; Deakin, Heidari & Deng 2025).
        if is_statcom
            if dc_coupled && length(smax_arr) >= n_phase
                smax = smax_arr[1:n_phase]
                if !haskey(inv, "p_max")
                    inv["p_max"] = copy(smax)
                    push!(entries, TransformEntry(
                        :ibr, inv_id, "p_max", nothing, copy(smax),
                        "STATCOM_dc_link_circulation", :standard,
                        "DC-link-coupled STATCOM: per-phase p_max = +s_max (circulation)"))
                end
                if !haskey(inv, "p_min")
                    inv["p_min"] = -smax
                    push!(entries, TransformEntry(
                        :ibr, inv_id, "p_min", nothing, -smax,
                        "STATCOM_dc_link_circulation", :standard,
                        "DC-link-coupled STATCOM: per-phase p_min = -s_max (circulation)"))
                end
            else
                zeros_p = fill(0.0, n_phase)
                if !haskey(inv, "p_max")
                    inv["p_max"] = copy(zeros_p)
                    push!(entries, TransformEntry(
                        :ibr, inv_id, "p_max", nothing, zeros_p,
                        "STATCOM_no_active_source", :standard,
                        "STATCOM exchanges no active power; p_max = 0 per phase"))
                end
                if !haskey(inv, "p_min")
                    inv["p_min"] = copy(zeros_p)
                    push!(entries, TransformEntry(
                        :ibr, inv_id, "p_min", nothing, zeros_p,
                        "STATCOM_no_active_source", :standard,
                        "STATCOM exchanges no active power; p_min = 0 per phase"))
                end
            end

            # Q bounds drawn from the converter rating, not from p_max.
            if !haskey(inv, "q_min") && !haskey(inv, "q_max") && length(smax_arr) >= n_phase
                q_max_vec = smax_arr[1:n_phase]
                q_min_vec = -q_max_vec
                inv["q_max"] = q_max_vec
                inv["q_min"] = q_min_vec
                push!(entries, TransformEntry(
                    :ibr, inv_id, "q_max", nothing, q_max_vec,
                    "STATCOM_full_reactive_rating", :standard,
                    "Q_max = s_max per phase (full converter reactive capability)"))
                push!(entries, TransformEntry(
                    :ibr, inv_id, "q_min", nothing, q_min_vec,
                    "STATCOM_full_reactive_rating", :standard,
                    "Q_min = -s_max per phase"))
            end

            _apply_dc_link_bounds!(inv, inv_id, entries, is_statcom)
            continue
        end

        # ── P bounds ─────────────────────────────────────────────────────────
        if !haskey(inv, "p_max")
            p_avail = get(inv, "p_avail", nothing)
            has_smax = length(smax_arr) >= n_phase && sum(@view smax_arr[1:n_phase]) > 0
            p_max_vec = if p_avail isa Number
                if has_smax
                    # Split p_avail PROPORTIONALLY to each phase's s_max so no
                    # phase's p_max exceeds its own apparent-power rating. An equal
                    # ÷n_phase split puts p_max[k] > s_max[k] on a lightly loaded
                    # phase when s_max mirrors an unbalanced load shape.
                    sm = smax_arr[1:n_phase]
                    Float64(p_avail) .* (sm ./ sum(sm))
                else
                    fill(Float64(p_avail) / n_phase, n_phase)
                end
            elseif length(smax_arr) >= n_phase
                smax_arr[1:n_phase]
            else
                nothing
            end
            if p_max_vec !== nothing
                inv["p_max"] = p_max_vec
                src = p_avail !== nothing ?
                    (has_smax ? "p_avail split ∝ per-phase s_max" : "p_avail ÷ $(n_phase) phase(s)") :
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

        # ── DC-link net active-power bounds (shared-DC-link converters) ──────
        _apply_dc_link_bounds!(inv, inv_id, entries, is_statcom)

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

# Derive the net DC-side active-power bounds for a shared-DC-link converter.
#
# When `dc_link_coupled` is set, the OPF couples the per-phase active powers by
#   p_dc_min ≤ Σ_k P_k ≤ p_dc_max,
# expressing the single DC link's power balance. The converter can then move
# active power between phases (to balance an unbalanced feeder) while the net
# stays inside [p_dc_min, p_dc_max]. Defaults (only filled when absent):
#   • STATCOM  → 0/0      (no active source; pure circulation)
#   • else     → 0/p_avail (curtailable PV-style source), else 0/Σ p_max.
function _apply_dc_link_bounds!(inv::Dict, inv_id, entries::Vector{TransformEntry},
                                is_statcom::Bool)
    get(inv, "dc_link_coupled", false) === true || return
    # When the converter attaches to a shared dc_bus, the active-power balance is
    # enforced on the DC node (DC KCL), not as a private per-IBR bound.
    haskey(inv, "dc_bus") && return

    p_dc_min = haskey(inv, "p_dc_min")
    p_dc_max = haskey(inv, "p_dc_max")
    (p_dc_min && p_dc_max) && return     # respect explicit values

    lo, hi, rule = if is_statcom
        0.0, 0.0, "STATCOM_dc_link_balance"
    else
        p_avail = get(inv, "p_avail", nothing)
        hi = if p_avail isa Number
            Float64(p_avail)
        else
            pm = get(inv, "p_max", nothing)
            pm isa AbstractVector ? sum(Float64.(pm)) : 0.0
        end
        0.0, hi, "ibr_dc_link_balance"
    end

    if !p_dc_min
        inv["p_dc_min"] = lo
        push!(entries, TransformEntry(
            :ibr, inv_id, "p_dc_min", nothing, lo, rule, :standard,
            "DC-link net active-power lower bound Σ P_k ≥ $(lo) W"))
    end
    if !p_dc_max
        inv["p_dc_max"] = hi
        push!(entries, TransformEntry(
            :ibr, inv_id, "p_dc_max", nothing, hi, rule, :standard,
            "DC-link net active-power upper bound Σ P_k ≤ $(hi) W"))
    end
end

# DC-network augmentation.
#
# Fills missing operational defaults on the DC side so a converter-station case is
# OPF-ready without hand-specifying every bound:
#   • dc_bus    → signed line-to-ground v_dc_min/v_dc_max from v_dc_nom ± a band
#                 (recipe.dc_v_band_frac); only when both are absent and v_dc_nom
#                 is present. Sign-preserving so the ordering min ≤ max holds.
#   • dc_source → p_min = 0, p_max = p (curtailable) when bounds are absent.
# Existing values are never overwritten.
function _apply_dc_network_augmentation!(net′::Dict{String,Any},
                                               entries::Vector{TransformEntry},
                                               r::AugmentationRecipe)
    frac = r.dc_v_band_frac

    for (id, b) in get(net′, "dc_bus", Dict())
        b isa Dict || continue
        (haskey(b, "v_dc_min") || haskey(b, "v_dc_max")) && continue
        nom = get(b, "v_dc_nom", nothing)
        nom isa AbstractVector && !isempty(nom) || continue
        nomf = Float64.(nom)
        vmin = [v - frac * abs(v) for v in nomf]
        vmax = [v + frac * abs(v) for v in nomf]
        b["v_dc_min"] = vmin
        b["v_dc_max"] = vmax
        push!(entries, TransformEntry(
            :dc_bus, id, "v_dc_min", nothing, vmin,
            "dc_v_band_$(round(frac, digits=3))", :standard,
            "Signed line-to-ground v_dc_min = v_dc_nom − $(round(100frac))% |v_dc_nom|"))
        push!(entries, TransformEntry(
            :dc_bus, id, "v_dc_max", nothing, vmax,
            "dc_v_band_$(round(frac, digits=3))", :standard,
            "Signed line-to-ground v_dc_max = v_dc_nom + $(round(100frac))% |v_dc_nom|"))
    end

    for (id, s) in get(net′, "dc_source", Dict())
        s isa Dict || continue
        p = get(s, "p", nothing)
        p isa Number || continue
        if !haskey(s, "p_min")
            s["p_min"] = 0.0
            push!(entries, TransformEntry(
                :dc_source, id, "p_min", nothing, 0.0,
                "dc_source_curtailable", :standard,
                "DC source p_min = 0 (curtailable)"))
        end
        if !haskey(s, "p_max")
            s["p_max"] = Float64(p)
            push!(entries, TransformEntry(
                :dc_source, id, "p_max", nothing, Float64(p),
                "dc_source_curtailable", :standard,
                "DC source p_max = p (rated injection)"))
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
