# ─────────────────────────────────────────────────────────────────────────────
# Transformer parameter library + snapping
#
# A curated library of realistic distribution-transformer parameters (impedance
# and losses that grow/shrink with voltage and rating), used to *fill missing
# parameters* — the transformer analogue of snapping a placeholder to a sensible
# real value. The first dataset is Energex/Ergon (Queensland) oriented; the file
# format and matcher stay region-extensible.
#
# Percentage impedance (z_pct) and X/R are rating-dependent and essentially
# HV-class independent across the QLD 11/22/33 kV range, so a transformer is
# matched to the nearest library entry primarily by (subtype, rated power); the
# unit's own `v_ref_from`/`s_rating` then set the impedance base for the Ω
# conversion. See `src/io/data/transformer_library.json` for the data and
# provenance.
# ─────────────────────────────────────────────────────────────────────────────

const _TXLIB_PATH = normpath(joinpath(@__DIR__, "..", "io", "data",
                                      "transformer_library.json"))
const _TXLIB_CACHE = Dict{String,Any}()

"""
    _transformer_library(region="AU-QLD")

Load (and cache) the transformer parameter library for `region`. Currently the
file ships a single region; `region` is validated against it so callers fail
loudly if they ask for an unavailable dataset.
"""
function _transformer_library(region::AbstractString = "AU-QLD")
    get!(_TXLIB_CACHE, String(region)) do
        lib = JSON3.read(read(_TXLIB_PATH, String))
        String(lib.region) == String(region) || error(
            "transformer library: region '$region' not available " *
            "(file provides '$(lib.region)')")
        lib
    end
end

# Nearest library entry for a transformer, by subtype + rated power. Returns the
# JSON entry object, or `nothing` when the subtype is uncovered, the rating is
# unusable, or the transformer's voltage falls grossly outside the covered class.
function _txlib_match(lib, subtype::AbstractString, v_from::Real, s_rating::Real)
    any(==(String(subtype)), String.(lib.subtypes)) || return nothing
    entries = lib.entries
    (isempty(entries) || s_rating <= 0) && return nothing

    # Soft voltage gate: don't snap a transformer whose from-side voltage is far
    # outside the library's documented envelope (e.g. a transmission unit).
    if v_from > 0
        vclass = Float64.(lib.v_from_class)
        (v_from >= 0.5 * minimum(vclass) && v_from <= 2.0 * maximum(vclass)) ||
            return nothing
    end

    best = nothing
    bestd = Inf
    for e in entries
        d = abs(log(Float64(e.s_rating)) - log(Float64(s_rating)))  # log-distance
        if d < bestd
            bestd = d
            best = e
        end
    end
    best
end

# Write `val` into `t[key]`, recording a provenance entry, but only when the
# field is missing (or a zero placeholder, for impedance/shunt fields) unless
# `overwrite`. Returns whether a write happened.
function _txlib_fill!(t::Dict, key::String, val::Real, entries::Vector{TransformEntry},
                      comp_id::String, eid::String; overwrite::Bool,
                      zero_is_empty::Bool = true)
    cur   = get(t, key, nothing)
    empty = cur === nothing ||
            (zero_is_empty && cur isa Number && Float64(cur) == 0.0)
    (overwrite || empty) || return false
    t[key] = Float64(val)
    push!(entries, TransformEntry(
        :transformer, comp_id, key, cur, Float64(val),
        "snap_transformer_library", :heuristic,
        "filled `$key` from library entry '$eid'"))
    true
end

# Fill a single transformer `t` of `subtype` from library entry `e`.
function _txlib_apply_entry!(t::Dict, subtype::AbstractString, e,
                             entries::Vector{TransformEntry}, comp_id::String;
                             overwrite::Bool)
    sbase = Float64(get(t, "s_rating",   0.0))
    vf    = Float64(get(t, "v_ref_from", 0.0))
    (sbase > 0 && vf > 0) || return     # no impedance base → cannot convert

    eid   = String(e.id)
    zbase = vf^2 / sbase                 # Ω, from-side rating base (matches _xfmr_z_pu)

    # Split z_pct into r/x via the X/R ratio; %Z is base-invariant so this is the
    # correct percentage referred to the from side.
    zpct = Float64(e.z_pct)
    xr   = Float64(e.xr_ratio)
    x_ohm = (zpct * xr / sqrt(1 + xr^2)) / 100 * zbase
    r_ohm = (zpct       / sqrt(1 + xr^2)) / 100 * zbase

    three_phase = subtype in ("wye_delta", "delta_wye")
    if three_phase
        # `three_phase_transformer` schema: single series impedance on the wye winding.
        _txlib_fill!(t, "r_series", r_ohm, entries, comp_id, eid; overwrite)
        _txlib_fill!(t, "x_series", x_ohm, entries, comp_id, eid; overwrite)
    else
        # `single_phase_or_center_tap_transformer` schema: from/to split fields.
        # Refer the whole leakage to the from winding (to-side left at 0).
        _txlib_fill!(t, "r_series_from", r_ohm, entries, comp_id, eid; overwrite)
        _txlib_fill!(t, "x_series_from", x_ohm, entries, comp_id, eid; overwrite)
    end

    # No-load (core) shunt, referred phase-to-ground on the from side. For a
    # 1-phase line-to-line unit (no neutral on the from side, e.g. a SWER
    # isolating transformer) the phase-to-ground stamp would land on the wrong
    # nodes, so skip the shunt there — same guard as the from_dss PMD recovery.
    ll_single = subtype == "single_phase" &&
                !("n" in string.(get(t, "terminal_map_from", String[])))
    vstp = three_phase ? vf / sqrt(3) : vf      # per-phase stamping voltage
    if !ll_single && vstp > 0
        g = Float64(e.g_no_load_pct)   / 100 * sbase / vstp^2
        b = Float64(e.mag_current_pct) / 100 * sbase / vstp^2
        _txlib_fill!(t, "g_no_load", g, entries, comp_id, eid; overwrite)
        _txlib_fill!(t, "b_no_load", b, entries, comp_id, eid; overwrite)
    end

    # Off-circuit tap range (fill only when absent — a present range is a
    # deliberate modelling choice, never a zero placeholder).
    _txlib_fill!(t, "tap_min", Float64(e.tap_min), entries, comp_id, eid;
                 overwrite, zero_is_empty = false)
    _txlib_fill!(t, "tap_max", Float64(e.tap_max), entries, comp_id, eid;
                 overwrite, zero_is_empty = false)
    return
end

# Recipe-internal pass: snap missing parameters of every two-winding transformer
# in `net′` from the regional library, appending provenance to `entries`.
function _fix_snap_transformer_library!(net′, entries::Vector{TransformEntry};
                                        region::AbstractString = "AU-QLD",
                                        overwrite::Bool = false)
    xfmr = get(net′, "transformer", nothing)
    xfmr isa Dict || return
    lib = _transformer_library(region)
    for subtype in _XFMR_2WINDING_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            vf = Float64(get(t, "v_ref_from", 0.0))
            s  = Float64(get(t, "s_rating",   0.0))
            e  = _txlib_match(lib, subtype, vf, s)
            e === nothing && continue
            _txlib_apply_entry!(t, subtype, e, entries, String(id); overwrite)
        end
    end
    return
end

"""
    apply_snap_transformer_library!(net; region="AU-QLD", overwrite=false)
        -> Vector{TransformEntry}

Fill missing/placeholder parameters of each two-winding transformer in `net`
(`single_phase`, `center_tap`, `wye_delta`, `delta_wye`) from the realistic
parameter library for `region`, mutating `net` in place and returning a
provenance log of every field written.

Each transformer is matched to the nearest library entry by subtype and rated
power; the unit's own `v_ref_from`/`s_rating` set the impedance base. With
`overwrite=false` (default) only fields that are absent — or a zero placeholder,
for series impedance and the no-load shunt — are written, so genuine data is
never clobbered. `overwrite=true` re-snaps every covered field.

Fields filled: `r_series[_from]`/`x_series[_from]` (from `z_pct` + `xr_ratio`),
`g_no_load`/`b_no_load` (from core-loss and magnetising-current percentages),
and `tap_min`/`tap_max`. Intended to run after the `from_dss` PMD recovery
([`_recover_transformer_params_from_pmd!`](@ref)) so the library only fills what
remains empty.

See also [`fix_case`](@ref) (`apply_snap_transformer_library` recipe flag).
"""
function apply_snap_transformer_library!(net::Dict{String,Any};
                                         region::AbstractString = "AU-QLD",
                                         overwrite::Bool = false)::Vector{TransformEntry}
    entries = TransformEntry[]
    _fix_snap_transformer_library!(net, entries; region, overwrite)
    entries
end
