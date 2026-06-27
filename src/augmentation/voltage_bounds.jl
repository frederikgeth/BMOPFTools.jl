# Voltage bound injection pass.
#
# For each bus that is missing bounds, injects v_min/v_max (solver
# regularisation), vpn/vpp (power-quality standards), and vneg_max.
#
# Never overwrites existing bounds.  Source buses are skipped for vpn/vpp/vneg
# (their voltages are fixed by the voltage source, not constrained by bounds).
#
# Declared supply voltage priority:
#   1. bus["v_declared"]          — explicit field set at import time, OR the
#                                   value written by the voltage-snap pass below
#   2. recipe.v_declared_lv/mv/hv — recipe-level regional fallback
#   3. v_nom from voltage_level_analysis — last resort

# ── Voltage-level snapping ───────────────────────────────────────────────────
#
# Standardised nominal voltages (IEC 60038 / ANSI C84.1), stored PHASE-TO-NEUTRAL
# (per-conductor) to match how v_nom is reported by voltage_level_analysis. The
# familiar line-to-line name is given alongside. Used by the optional snap pass
# to pull imported 240/250 V transformers onto the standard 230 V (etc.).

const _VOLTAGE_PRESETS = Dict{String,Vector{Float64}}(
    # IEC 60038, 50 Hz (Europe / Australia / UK). L-N values.
    "IEC_50Hz" => [
        230.0,                 # 230 V L-N  (400 V L-L)  LV
        400.0,                 # 400 V L-N  (690 V L-L)  LV
        3300.0   / sqrt(3),    # 3.3 kV L-L  MV
        6600.0   / sqrt(3),    # 6.6 kV L-L
        11000.0  / sqrt(3),    # 11 kV  L-L
        22000.0  / sqrt(3),    # 22 kV  L-L
        33000.0  / sqrt(3),    # 33 kV  L-L
        66000.0  / sqrt(3),    # 66 kV  L-L  HV
        132000.0 / sqrt(3),    # 132 kV L-L
        220000.0 / sqrt(3),    # 220 kV L-L
        275000.0 / sqrt(3),    # 275 kV L-L
        400000.0 / sqrt(3),    # 400 kV L-L  EHV
    ],
    # ANSI C84.1, 60 Hz (North America). L-N / per-leg values.
    "ANSI_60Hz" => [
        120.0,                 # 120 V  (split-phase leg / 208Y L-N)
        277.0,                 # 277 V L-N  (480 V L-L)
        7200.0,                # 7.2 kV L-N (12.47 kV L-L)
        7620.0,                # 7.62 kV L-N (13.2 kV L-L)
        14400.0,               # 14.4 kV L-N (24.9 kV L-L)
        19920.0,               # 19.92 kV L-N (34.5 kV L-L)
    ],
    "none" => Float64[],
)

"""
    _resolve_snap_levels(snap_cfg) -> Vector{Float64}

Merge the named-preset level list with any user `levels` (custom phase-to-neutral
volts), de-duplicated and sorted. Unknown presets fall back to an empty list
(custom `levels` only).
"""
function _resolve_snap_levels(snap_cfg::Dict)::Vector{Float64}
    preset  = string(get(snap_cfg, "preset", "IEC_50Hz"))
    base    = get(_VOLTAGE_PRESETS, preset, Float64[])
    custom  = Float64.(get(snap_cfg, "levels", Float64[]))
    sort(unique(vcat(base, custom)))
end

"""
    _snap_voltage(v, levels, tol) -> Float64

Snap `v` to the nearest standard level in `levels` whose relative distance
`|v/std − 1|` is within `tol`; if no level qualifies (or `levels` is empty),
return `v` unchanged.
"""
function _snap_voltage(v::Float64, levels::AbstractVector{<:Real}, tol::Float64)::Float64
    isempty(levels) && return v
    best     = v
    best_rel = tol
    for std in levels
        std <= 0 && continue
        rel = abs(v / std - 1.0)
        if rel <= best_rel
            best_rel = rel
            best     = Float64(std)
        end
    end
    best
end

"""
    _apply_voltage_snap!(net′, entries, snap_cfg, bus_voltage_map)

Optional augment pass: when `snap_cfg["enabled"]`, snap each bus's derived
nominal (`v_nom`) to the nearest standard level (within tolerance) and write the
result as `bus["v_declared"]`, so the downstream bounds passes reference the
standardised voltage. Buses that already carry an explicit `v_declared`, or
whose `v_nom` does not move under snapping, are left untouched. Each write is
recorded as a `TransformEntry`.
"""
function _apply_voltage_snap!(net′::Dict{String,Any},
                               entries::Vector{TransformEntry},
                               snap_cfg::Dict,
                               bus_voltage_map::Dict{String,Float64})
    get(snap_cfg, "enabled", false) === true || return
    levels = _resolve_snap_levels(snap_cfg)
    isempty(levels) && return
    tol = Float64(get(snap_cfg, "tolerance", 0.10))

    for (bid, bus) in get(net′, "bus", Dict())
        bus isa Dict || continue
        haskey(bus, "v_declared") && continue        # respect explicit value
        v_nom = get(bus_voltage_map, bid, nothing)
        v_nom === nothing && continue                 # islanded bus
        snapped = _snap_voltage(Float64(v_nom), levels, tol)
        snapped == v_nom && continue                  # no standard within band

        bus["v_declared"] = snapped
        push!(entries, TransformEntry(
            :bus, bid, "v_declared", nothing, snapped,
            "IEC60038_snap", :heuristic,
            "v_nom=$(round(v_nom, digits=1)) V snapped to standard " *
            "$(round(snapped, digits=1)) V (tol $(round(Int, tol*100))%)"))
    end
end

# Return the declared supply voltage (phase-to-ground, V) for a bus.
function _v_declared(bus::Dict{String,Any}, v_nom::Float64,
                     r::AugmentationRecipe)::Float64
    vd = get(bus, "v_declared", nothing)
    vd isa Number && return Float64(vd)
    fallback = v_nom <= 1_000.0  ? r.v_declared_lv :
               v_nom <= 35_000.0 ? r.v_declared_mv :
                                   r.v_declared_hv
    fallback isa Number ? Float64(fallback) : v_nom
end

function _level_name(v_nom::Float64)::String
    v_nom <= 1_000.0  && return "LV"
    v_nom <= 35_000.0 && return "MV"
    return "HV"
end

function _vpn_pu(v_nom::Float64, r::AugmentationRecipe)::Tuple{Float64,Float64}
    v_nom <= 1_000.0 ? r.vpn_lv_pu : r.vpn_mv_pu
end

function _vpp_pu(v_nom::Float64, r::AugmentationRecipe)::Tuple{Float64,Float64}
    v_nom <= 1_000.0  ? r.vpp_lv_pu :
    v_nom <= 35_000.0 ? r.vpp_mv_pu :
                        r.vpp_hv_pu
end

function _apply_voltage_bounds!(net′::Dict{String,Any},
                                 entries::Vector{TransformEntry},
                                 r::AugmentationRecipe,
                                 bus_voltage_map::Dict{String,Float64})
    buses = get(net′, "bus", Dict())

    source_buses = Set{String}()
    for (_, vs) in get(net′, "voltage_source", Dict())
        b = get(vs, "bus", nothing)
        b isa String && push!(source_buses, b)
    end

    for (bid, bus) in buses
        bus isa Dict || continue
        v_nom = get(bus_voltage_map, bid, nothing)
        v_nom === nothing && continue   # islanded bus — skip

        lvl = _level_name(v_nom)
        v_dec = _v_declared(bus, v_nom, r)
        is_source = bid in source_buses

        nt       = _neutral_terminal(bus)
        terms    = get(bus, "terminal_names", String[])
        n_phase  = count(t -> string(t) != nt, terms)
        has_neutral = nt !== nothing && any(t -> string(t) == nt, terms)
        is_four_wire = has_neutral && n_phase >= 1

        # ── v_min / v_max (solver regularisation) ────────────────────────────
        # Per-phase arrays, one entry per phase conductor (phase-to-ground).
        if r.apply_v_bounds && r.v_min_pu !== nothing && r.v_max_pu !== nothing && n_phase >= 1
            for (field, pu) in (("v_min", r.v_min_pu), ("v_max", r.v_max_pu))
                if !haskey(bus, field)
                    val = fill(v_dec * pu, n_phase)
                    bus[field] = val
                    push!(entries, TransformEntry(
                        :bus, bid, field, nothing, val,
                        "solver_regularisation", :heuristic,
                        "$lvl bus; v_declared=$(round(v_dec, digits=1)) V × $pu × $n_phase phases"))
                end
            end
        end

        is_source && continue   # skip power-quality bounds on source buses

        # ── vpn_min / vpn_max (four-wire only) ───────────────────────────────
        # Per-phase arrays, one entry per phase conductor (length = n_phase).
        if r.apply_vpn_bounds && is_four_wire
            # v_dec is the declared per-conductor (phase-to-ground ≈ phase-to-
            # neutral) voltage — exactly the basis the phase-to-neutral bounds
            # need, so vpn_nom = v_dec directly. (EN 50160 LV: 230 V L-N.)
            v_pn_dec = v_dec
            lo_pu, hi_pu = _vpn_pu(v_nom, r)

            for (field, pu) in (("vpn_min", lo_pu), ("vpn_max", hi_pu))
                if !haskey(bus, field)
                    val = fill(v_pn_dec * pu, n_phase)
                    bus[field] = val
                    push!(entries, TransformEntry(
                        :bus, bid, field, nothing, val,
                        "EN50160:2010§3.5", :standard,
                        "vpn_declared=$(round(v_pn_dec, digits=1)) V × $pu ($(n_phase) phase(s))"))
                end
            end

            # ── vneg_max (EN 50160: VUF ≤ 2 %) ──────────────────────────────
            if r.apply_vneg_bounds && n_phase >= 2
                if !haskey(bus, "vneg_max")
                    val = v_pn_dec * r.vneg_max_pu
                    bus["vneg_max"] = val
                    push!(entries, TransformEntry(
                        :bus, bid, "vneg_max", nothing, val,
                        "EN50160:2010§3.5_VUF≤2%", :standard,
                        "$(r.vneg_max_pu*100)% of vpn_declared=$(round(v_pn_dec, digits=1)) V"))
                end
            end
        end

        # ── vpp_min / vpp_max ─────────────────────────────────────────────────
        # Per phase-pair arrays, length = n_phase*(n_phase-1)/2.
        # v_dec is the per-conductor (phase-to-ground) declared voltage, so the
        # line-to-line (phase-to-phase) nominal is vpp_nom = v_dec × √3 for both
        # four-wire and three-wire buses. (EN 50160 LV: 230 V L-N → 400 V L-L.)
        # Requires ≥ 2 phase terminals (spec: only meaningful if |Nᵢ| ≥ 3,
        # but we also support the single phase-pair case, length 1).
        if r.apply_vpp_bounds && n_phase >= 2
            n_pairs = n_phase * (n_phase - 1) ÷ 2
            v_pp_dec = v_dec * sqrt(3.0)
            lo_pu, hi_pu = _vpp_pu(v_nom, r)

            for (field, pu) in (("vpp_min", lo_pu), ("vpp_max", hi_pu))
                if !haskey(bus, field)
                    val = fill(v_pp_dec * pu, n_pairs)
                    bus[field] = val
                    push!(entries, TransformEntry(
                        :bus, bid, field, nothing, val,
                        "EN50160:2010§3.5", :standard,
                        "vpp_declared=$(round(v_pp_dec, digits=1)) V × $pu ($(n_pairs) pair(s))"))
                end
            end
        end
    end
end

"""
    _apply_angle_diff_bounds!(net′, entries, r)

Inject the intra-bus angle-difference centering reference (`va_nom`) and the
symmetric bound window (`va_diff_min`/`va_diff_max`) for multiphase, non-source
buses, following the PSCC-2026 centered formulation. Only buses with an
unambiguous nominal phasor arrangement are touched:

- **split-phase** (in a `center_tap`-fed zone, exactly 2 phase terminals) →
  `va_nom = [0, π]` (the two legs are anti-phase);
- **three-phase** (exactly 3 phase terminals) → `va_nom = [0, −2π/3, 2π/3]`
  (positive sequence, declaration order a,b,c).

All other buses (single-phase, or ambiguous phase counts) are skipped — the
nominal offset is never guessed. Existing `va_nom`/`va_diff_*` are never
overwritten. `va_nom` is indexed in the full phase order (`terminal_names` minus
neutral), matching the OPF and `vpn`/`vpp`.
"""
function _apply_angle_diff_bounds!(net′::Dict{String,Any},
                                    entries::Vector{TransformEntry},
                                    r::AugmentationRecipe)
    buses = get(net′, "bus", Dict())

    source_buses = Set{String}()
    for (_, vs) in get(net′, "voltage_source", Dict())
        b = get(vs, "bus", nothing)
        b isa String && push!(source_buses, b)
    end

    split_phase_buses = Set{String}()
    for z in _classify_zones(net′)
        z.topology == :split_phase && union!(split_phase_buses, z.buses)
    end

    w = r.va_diff_window_rad
    for (bid, bus) in buses
        bus isa Dict || continue
        bid in source_buses && continue                 # source phasors are pinned

        nt      = _neutral_terminal(bus)
        terms   = get(bus, "terminal_names", String[])
        n_phase = count(t -> string(t) != nt, terms)

        va_nom =
            (bid in split_phase_buses && n_phase == 2) ? [0.0, π]             :
            (n_phase == 3)                             ? [0.0, -2π/3, 2π/3]   :
                                                          nothing
        va_nom === nothing && continue                  # never guess the offset

        kind = (bid in split_phase_buses && n_phase == 2) ? "split-phase (180°)" :
                                                            "three-phase (±120°)"
        if !haskey(bus, "va_nom")
            bus["va_nom"] = va_nom
            push!(entries, TransformEntry(
                :bus, bid, "va_nom", nothing, va_nom,
                "PSCC2026_anglediff", :heuristic,
                "$kind nominal phase angles (rad)"))
        end
        for (field, val) in (("va_diff_min", -w), ("va_diff_max", w))
            if !haskey(bus, field)
                bus[field] = val
                push!(entries, TransformEntry(
                    :bus, bid, field, nothing, val,
                    "PSCC2026_anglediff", :heuristic,
                    "±$(round(rad2deg(w), digits=1))° window around $kind nominal"))
            end
        end
    end
end
