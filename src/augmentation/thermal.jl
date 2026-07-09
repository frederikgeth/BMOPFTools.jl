# Thermal limit inference pass.
#
# Infers a heuristic i_max for linecodes that lack it by matching the diagonal
# series resistance R₁₁ against a lookup table of representative conductor
# cross-sections → ampacity. This is a SYNTHETIC ESTIMATE, not a standards
# lookup: R₁₁ is the series resistance (conductor AC resistance PLUS the Carson
# earth-return coupling), so it does not by itself identify a conductor's
# material, construction class, cross-section, or installation method. The R₁₁
# column is keyed on maximum DC resistance at 20 °C (the quantity IEC 60228:2004
# specifies, measured by a DC procedure) purely as a size fingerprint; a
# high-confidence rating needs material/class and installation method known
# independently.
#
# The neutral conductor carries the same rating as the phase conductors in
# this implementation (no derating applied).  IEC 60364-5-52:2009 Table B.52
# permits a reduced neutral cross-section above 16 mm² when the load is
# sufficiently balanced, but the appropriate derating is installation- and
# load-specific.  See the augmentation documentation for guidance.
#
# Only linecodes whose provenance confidence is at or above
# recipe.thermal_min_confidence are processed.  This prevents assigning
# ratings derived from a fictitious sequence-impedance matrix.

# ── Heuristic conductor size → ampacity lookup table ────────────────────────
# Columns: (R₁₁ mΩ/m — max DC resistance at 20 °C, cross_section mm²,
#           underground ampacity A, overhead illustrative ampacity A)
# The underground column is loosely calibrated to IEC 60364-5-52:2009 Table B.52
# (LV installation ampacity); the overhead column is illustrative, NOT an
# IEC 60364/AAC catalogue value. `nothing` marks sizes not commonly overhead.
const _IEC_CONDUCTOR_TABLE = [
    (4.950, 4,    34,  nothing),
    (3.300, 6,    41,  nothing),
    (1.980, 10,   57,  70),
    (1.240, 16,   76,  95),
    (0.787, 25,  104, 130),
    (0.559, 35,  134, 160),
    (0.396, 50,  170, 200),
    (0.283, 70,  220, 260),
    (0.209, 95,  277, 320),
    (0.164, 120, 326, 375),
    (0.132, 150, 386, 430),
    (0.107, 185, 451, 490),
    (0.082, 240, 541, 600),
]  # Heuristic table: R₁₁ ~ IEC 60228:2004 max DC resistance (size fingerprint);
   # underground ampacity ~ IEC 60364-5-52:2009 Table B.52; overhead illustrative.

# 15 % relative tolerance (default) for R₁₁ matching against the IEC table.
# Sourced from config/default.toml [thermal].tolerance.
const _THERMAL_TOLERANCE = Float64(_thermal_cfg()["tolerance"])

# Provenance rule tag for thermal fills. Deliberately labelled a heuristic
# estimate rather than "IEC60228+IEC60364": R₁₁ alone does not identify the
# conductor material/class or installation, so the result is not a
# standards-conformant ampacity (see the header comment).
const _THERMAL_RULE = "heuristic_ampacity_estimate"

# Confidence ordering for threshold comparison
const _CONFIDENCE_ORDER = Dict(:low => 1, :medium => 2, :high => 3)

function _confidence_ok(c::Symbol, min_c::Symbol)::Bool
    get(_CONFIDENCE_ORDER, c, 0) >= get(_CONFIDENCE_ORDER, min_c, 0)
end

"""
    _linecode_confidence(classification::String) -> Symbol

Map a provenance linecode classification string to a confidence level for
thermal inference.
"""
function _linecode_confidence(classification::String)::Symbol
    classification == "distinct"        && return :high
    classification == "near_balanced"   && return :medium
    return :low   # exactly_balanced, decoupled, or unknown
end

"""
    _lookup_ampacity(r11_ohm_per_m, conductor_type) -> (mm2, ampacity, note)

Find the nearest heuristic table entry for the given R₁₁ (Ω/m).
Returns (cross_section_mm2, ampacity_A, note_string) or nothing if no match
within tolerance.
"""
function _lookup_ampacity(r11_ohm_per_m::Float64, conductor_type::Symbol;
                          tolerance::Float64=_THERMAL_TOLERANCE)
    r11_mohm = r11_ohm_per_m * 1000.0   # convert to mΩ/m

    best_row  = nothing
    best_reld = Inf
    for row in _IEC_CONDUCTOR_TABLE
        rel = abs(r11_mohm - row[1]) / row[1]
        if rel < best_reld
            best_reld = rel
            best_row  = row
        end
    end

    best_row === nothing && return nothing
    best_reld > tolerance && return nothing

    r_tab, mm2, amp_ug, amp_oh = best_row
    amp = if conductor_type == :overhead
        amp_oh === nothing && return nothing
        Float64(amp_oh)
    else
        Float64(amp_ug)
    end

    note = "R₁₁=$(round(r11_mohm, digits=3)) mΩ/m matched to $(mm2) mm² " *
           "(table: $(r_tab) mΩ/m, Δ=$(round(best_reld*100, digits=1))%); " *
           "$(conductor_type == :overhead ? "overhead AAC" : "underground XLPE")"
    (mm2, amp, note)
end

function _apply_thermal!(net′::Dict{String,Any},
                          entries::Vector{TransformEntry},
                          r::AugmentationRecipe,
                          linecode_classifications::Dict{String,String};
                          config::Dict=_DEFAULT_CONFIG)
    r.apply_thermal || return
    # Read the tolerance from the per-call config (a module-load-time constant
    # would silently ignore an augment_case(...; config=) override).
    tolerance = Float64(_thermal_cfg(config)["tolerance"])

    linecodes = get(net′, "linecode", Dict())

    for (lcid, lc) in linecodes
        lc isa Dict || continue
        haskey(lc, "i_max") && continue   # already present — never overwrite

        # Determine confidence from provenance classification
        cls        = get(linecode_classifications, lcid, "unknown")
        confidence = _linecode_confidence(cls)
        _confidence_ok(confidence, r.thermal_min_confidence) || begin
            push!(entries, TransformEntry(
                :linecode, lcid, "i_max", nothing, nothing,
                _THERMAL_RULE, confidence,
                "skipped: confidence $(confidence) below threshold " *
                "$(r.thermal_min_confidence) (classification: $(cls))"))
            continue
        end

        # Read R₁₁ — must be present and positive
        r11 = get(lc, "R_series_1_1", nothing)
        (r11 isa Number && r11 > 0) || begin
            push!(entries, TransformEntry(
                :linecode, lcid, "i_max", nothing, nothing,
                _THERMAL_RULE, confidence,
                "skipped: R_series_1_1 absent or non-positive"))
            continue
        end

        result = _lookup_ampacity(Float64(r11), r.conductor_type; tolerance)
        if result === nothing
            push!(entries, TransformEntry(
                :linecode, lcid, "i_max", nothing, nothing,
                _THERMAL_RULE, confidence,
                "skipped: R₁₁=$(round(Float64(r11)*1000, digits=3)) mΩ/m " *
                "outside lookup range (no match within $(round(tolerance*100))%)"))
            continue
        end

        _, ampacity, note = result

        # Count conductors from R_series matrix keys
        n_cond = _count_conductors(lc)
        i_max_vec = fill(ampacity, n_cond)

        lc["i_max"] = i_max_vec
        push!(entries, TransformEntry(
            :linecode, lcid, "i_max", nothing, i_max_vec,
            _THERMAL_RULE, confidence, note))
    end
end

"""
    _apply_power_to_current!(net′, entries, r, bus_voltage_map) -> nothing

Opt-in conversion of per-conductor apparent-power limits into equivalent current
limits. For every line/switch that carries `s_max` but **no** `i_max`, and whose
from-bus has a resolvable phase-to-ground reference voltage `v_ref`, write
`i_max[k] = s_max[k] / v_ref` (the standard `I ≈ S/V` per conductor). Current is
the preferred thermal representation for lines/switches (no voltage-reference
ambiguity, no neutral degeneracy); the conversion is exact only at `v_ref`.

Transformers are deliberately excluded — their kVA nameplate stays canonical.
Each write is recorded as a `TransformEntry`; nothing is overwritten.
"""
function _apply_power_to_current!(net′::Dict{String,Any},
                                  entries::Vector{TransformEntry},
                                  r::AugmentationRecipe,
                                  bus_voltage_map::Dict)
    r.apply_power_to_current || return
    buses = get(net′, "bus", Dict())
    for (ctype, csym) in (("line", :line), ("switch", :switch))
        for (id, el) in get(net′, ctype, Dict())
            el isa Dict || continue
            haskey(el, "i_max") && continue            # current already present
            s = get(el, "s_max", nothing)
            (s isa AbstractVector && !isempty(s)) || continue
            bus = get(el, "bus_from", nothing)
            bus isa AbstractString || continue
            v_nom = get(bus_voltage_map, bus, nothing)
            v_nom isa Number || continue
            v_ref = _v_declared(get(buses, bus, Dict{String,Any}()), Float64(v_nom), r)
            (v_ref isa Number && v_ref > 0.0) || continue
            i_max_vec = [Float64(sk) / Float64(v_ref) for sk in s]
            el["i_max"] = i_max_vec
            push!(entries, TransformEntry(
                csym, id, "i_max", nothing, i_max_vec,
                "power_to_current (I = S/v_ref)", :medium,
                "converted per-conductor s_max=$(Float64.(s)) VA to i_max via " *
                "v_ref=$(round(Float64(v_ref), digits=1)) V (exact only at v_ref); " *
                "current is the preferred thermal representation for $(ctype)s"))
        end
    end
    return
end

"""Count conductors in a linecode from the R_series diagonal keys."""
function _count_conductors(lc::Dict{String,Any})::Int
    n = 0
    for k in keys(lc)
        m = match(r"^R_series_(\d+)_\1$", k)
        m === nothing && continue
        idx = parse(Int, m.captures[1])
        n = max(n, idx)
    end
    n == 0 ? 1 : n   # fallback to 1 if no diagonal keys found
end
