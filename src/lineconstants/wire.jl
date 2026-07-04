# lineconstants/wire.jl
#
# Resolve `wire_data` library entries into the effective per-conductor
# electrical parameters the impedance engine needs. Cross-defaults follow
# OpenDSS's ConductorData conventions but are applied on `nothing` (absent
# field) rather than sentinel values, and every applied default is recorded
# so `compile_linecode` can stamp it into the linecode's `derivation` block.
#
# All quantities SI: Ω/m, m, °C.

const _MU0  = 4e-7 * pi              # vacuum permeability [H/m]
const _EPS0 = 8.8541878128e-12       # vacuum permittivity [F/m]

# GMR of a solid round conductor: gmr = e^(-1/4)·radius. Also the OpenDSS
# cross-default factor between gmr and radius.
const _GMR_FACTOR = exp(-0.25)

# Tape-shield resistivity: OpenDSS hard-codes copper at 50 °C.
const _TS_RHO_COPPER = 2.3718e-8     # [Ω·m]

# Effective series parameters of one circuit conductor, plus the optional
# shield/concentric-neutral subconductor a cable contributes. Internal
# working struct only — the data model stays Dict.
struct _ResolvedWire
    id::String
    kind::String            # "overhead" | "cn_cable" | "ts_cable"
    r_ac::Float64           # phase/core AC resistance at operating temp [Ω/m]
    gmr::Float64            # phase/core GMR [m]
    radius::Float64         # physical outside radius of the core [m]
    cap_radius::Float64     # electrostatic radius [m]
    i_max::Union{Float64,Nothing}
    # coaxial capacitance parameters (cables; NaN when not applicable)
    c_shunt::Float64        # phase-to-shield capacitance [F/m]; 0.0 for overhead
    # shield equivalent subconductor (cables; nothing for overhead)
    r_shield::Union{Float64,Nothing}   # [Ω/m]
    gmr_shield::Union{Float64,Nothing} # [m]
    rad_shield::Union{Float64,Nothing} # radial distance core→shield equivalent [m]
end

"Temperature-correct a resistance from t_ref to t_op using α at 20 °C."
function _r_at_temperature(r_ref::Float64, t_ref::Float64, t_op::Float64,
                           alpha20::Union{Float64,Nothing})::Float64
    (alpha20 === nothing || t_op == t_ref) && return r_ref
    r_ref * (1 + alpha20 * (t_op - 20.0)) / (1 + alpha20 * (t_ref - 20.0))
end

"""
Resolve a `wire_data` entry to the effective parameters at the geometry's
operating conditions. `defaults` collects `"field:wire_id"` strings for each
cross-default applied. Throws for missing required data.
"""
function _resolve_wire(id::String, w::Dict{String,Any},
                       temperature::Union{Float64,Nothing},
                       defaults::Vector{String})::_ResolvedWire
    kind = get(w, "kind", nothing)
    kind in ("overhead", "cn_cable", "ts_cable") ||
        error("wire_data '$id': missing or invalid `kind` " *
              "(expected \"overhead\", \"cn_cable\", or \"ts_cable\").")

    # -- resistance: r_ac ↔ 1.02·r_dc cross-default -------------------------
    r_dc = get(w, "r_dc", nothing)
    r_ac = get(w, "r_ac", nothing)
    (r_dc === nothing && r_ac === nothing) &&
        error("wire_data '$id': at least one of `r_dc`/`r_ac` is required.")
    if r_ac === nothing
        r_ac = 1.02 * Float64(r_dc)
        push!(defaults, "r_ac:$id")
    else
        r_ac = Float64(r_ac)
    end
    t_ref = Float64(get(w, "temperature_ref", 20.0))
    alpha = haskey(w, "alpha_20") ? Float64(w["alpha_20"]) : nothing
    t_op  = temperature === nothing ? t_ref : temperature
    r_ac  = _r_at_temperature(r_ac, t_ref, t_op, alpha)

    # -- inductive and electrostatic radii: gmr ↔ 0.7788·radius -------------
    gmr    = get(w, "gmr", nothing)
    radius = get(w, "radius", nothing)
    (gmr === nothing && radius === nothing) &&
        error("wire_data '$id': at least one of `gmr`/`radius` is required.")
    if gmr === nothing
        gmr = _GMR_FACTOR * Float64(radius)
        push!(defaults, "gmr:$id")
    else
        gmr = Float64(gmr)
    end
    if radius === nothing
        radius = gmr / _GMR_FACTOR
        push!(defaults, "radius:$id")
    else
        radius = Float64(radius)
    end
    # GMR ≤ radius for any internal current distribution (0.7788·radius for a
    # solid round conductor, lower for stranded/ACSR) — larger is unbuildable.
    gmr <= radius * (1 + 1e-9) ||
        error("wire_data '$id': gmr ($(gmr) m) exceeds radius ($(radius) m) — " *
              "physically impossible (GMR ≤ radius; = 0.7788·radius for solid " *
              "round). Check for a units or transcription error.")
    cap_radius = if haskey(w, "cap_radius")
        Float64(w["cap_radius"])
    else
        radius
    end

    i_max = haskey(w, "i_max") ? Float64(w["i_max"]) : nothing

    # -- cable structure -----------------------------------------------------
    c_shunt    = 0.0
    r_shield   = nothing
    gmr_shield = nothing
    rad_shield = nothing

    if kind in ("cn_cable", "ts_cable")
        # coaxial phase-to-shield capacitance (OpenDSS CableData convention)
        d_ins = get(w, "d_insulation", nothing)
        t_ins = get(w, "t_insulation", nothing)
        if d_ins !== nothing && t_ins !== nothing
            eps_r = Float64(get(w, "eps_r", 2.3))
            haskey(w, "eps_r") || push!(defaults, "eps_r:$id")
            rad_out = Float64(d_ins) / 2
            rad_in  = rad_out - Float64(t_ins)
            rad_in > 0 || error("wire_data '$id': t_insulation ≥ d_insulation/2.")
            c_shunt = 2pi * _EPS0 * eps_r / log(rad_out / rad_in)
        end
        # layers must nest radially: core inside the insulation
        if d_ins !== nothing && radius >= Float64(d_ins) / 2
            error("wire_data '$id': core radius ($(radius) m) ≥ insulation " *
                  "outer radius ($(Float64(d_ins)/2) m) — cable layers must " *
                  "nest radially.")
        end
    end

    if kind == "cn_cable"
        for f in ("n_strands", "d_strand", "r_strand", "d_cable")
            haskey(w, f) || error("wire_data '$id': `$f` is required for cn_cable.")
        end
        k  = Int(w["n_strands"])
        ds = Float64(w["d_strand"])
        gs = if haskey(w, "gmr_strand")
            Float64(w["gmr_strand"])
        else
            push!(defaults, "gmr_strand:$id")
            _GMR_FACTOR * ds / 2
        end
        # Kersting: strands lie on a circle of radius R; the k strands act as
        # one equivalent conductor at that radius.
        R = (Float64(w["d_cable"]) - ds) / 2
        R > 0 || error("wire_data '$id': d_cable must exceed d_strand.")
        d_ins2 = get(w, "d_insulation", nothing)
        d_ins2 !== nothing && R < Float64(d_ins2) / 2 &&
            error("wire_data '$id': concentric-neutral strand circle radius " *
                  "($(R) m) lies inside the insulation " *
                  "(d_insulation/2 = $(Float64(d_ins2)/2) m) — layers must nest.")
        gmr_shield = (gs * k * R^(k - 1))^(1 / k)
        r_shield   = Float64(w["r_strand"]) / k
        rad_shield = R
    elseif kind == "ts_cable"
        for f in ("d_shield", "t_tape")
            haskey(w, f) || error("wire_data '$id': `$f` is required for ts_cable.")
        end
        d_s = Float64(w["d_shield"])
        t_t = Float64(w["t_tape"])
        d_ins3 = get(w, "d_insulation", nothing)
        d_ins3 !== nothing && d_s < Float64(d_ins3) &&
            error("wire_data '$id': d_shield ($(d_s) m) < d_insulation " *
                  "($(d_ins3) m) — the tape shield sits outside the insulation.")
        lap = Float64(get(w, "tape_lap", 20.0))
        haskey(w, "tape_lap") || push!(defaults, "tape_lap:$id")
        lap < 100 || error("wire_data '$id': tape_lap must be < 100 %.")
        # Mean tape radius as GMR; resistance from the tape cross-section with
        # the OpenDSS lap factor and hard-coded copper resistivity.
        gmr_shield = (d_s - t_t) / 2
        r_shield   = _TS_RHO_COPPER /
                     (pi * d_s * t_t * sqrt(50.0 / (100.0 - lap)))
        rad_shield = gmr_shield
    end

    _ResolvedWire(id, kind, r_ac, gmr, radius, cap_radius, i_max,
                  c_shunt, r_shield, gmr_shield, rad_shield)
end
