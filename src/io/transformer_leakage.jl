# SI leakage policy for primitive and network admittance assembly. A small
# impedance selects a bordered representation; it is never rounded to zero.
function _ybus_xfmr_z_min(thresh)
    v = get(thresh, "xfmr_z_min_ohm", 1e-6)
    v isa Real && !(v isa Bool) && isfinite(v) && v >= 0 ||
        throw(ArgumentError("xfmr_z_min_ohm must be finite and nonnegative"))
    Float64(v)
end

function _xfmr_series_ohms(x, side)
    vals = [get(x, "$(p)_series_$side", 0.0) for p in ("r", "x")]
    all(v -> v isa Real && !(v isa Bool) && isfinite(v), vals) ||
        throw(ArgumentError("transformer series impedance must be finite real ohms"))
    complex(Float64(vals[1]), Float64(vals[2]))
end

function _xfmr_checked_ratio(r)
    isfinite(r) && !iszero(r) || throw(ArgumentError("transformer coil ratio must be finite and nonzero"))
    r
end

function _ybus_regulator_ratios(x, subtype)
    rt = uppercase(strip(string(get(x, "regulator_type", "B"))))
    rt in ("A", "B") || throw(ArgumentError("regulator_type must be A or B"))
    taps = subtype == "open_delta_regulator" ? get(x,"tap_ratio",[1.,1.]) : [get(x,"tap_ratio",1.)]
    taps isa AbstractVector && length(taps) in (1,2) ||
        throw(ArgumentError("regulator requires one or two fixed taps"))
    all(t -> t isa Real && !(t isa Bool) && isfinite(t) && t > 0, taps) ||
        throw(ArgumentError("regulator taps must be positive finite real numbers"))
    n = subtype == "open_delta_regulator" ? 2 : 1
    [_xfmr_checked_ratio(_autotransformer_neff(taps[min(k,end)],rt)) for k in 1:n]
end

# Effective impedances use the SAME reference as the associated primitive row.
function _xfmr_leakage_values(x, subtype)
    if subtype == "n_winding"
        _validate_nw_ybus_domain(x)
        ws = _nw_windings(x)
        length(ws) >= 2 || throw(ArgumentError("n_winding requires at least two windings"))
        all(w -> isfinite(w.v_nom) && w.v_nom > 0, ws) ||
            throw(ArgumentError("n_winding requires positive finite coil voltages"))
        Z = _nw_zb_matrix(x)
        all(isfinite, Z) || throw(ArgumentError("n_winding ZB must be finite"))
        return svdvals(Z) # winding-1 coil base, detects partially singular ZB
    end
    zf = _xfmr_series_ohms(x, "from"); zt = _xfmr_series_ohms(x, "to")
    if subtype in ("single_phase", "center_tap", "wye_delta", "delta_wye")
        n = _xfmr_checked_ratio(_xfmr_turns_ratio(x))
        t = _xfmr_checked_ratio(_xfmr_tap_mult(x))
        if subtype == "single_phase"
            return ComplexF64[t^2 * (zf + n^2 * zt)]
        elseif subtype == "center_tap"
            return ComplexF64[zf / n^2, zt, zt] # each star arm, LV coil base
        end
        yd = subtype == "wye_delta"
        np = length(get(x, yd ? "terminal_map_to" : "terminal_map_from", []))
        n0 = yd ? sqrt(3.0)/n : sqrt(3.0)*n
        return ComplexF64[(yd ? t^2 : 1.0) * ((yd ? zf : zt) + np/n0^2 * (yd ? zt : zf))]
    elseif subtype == "single_phase_autotransformer"
        n = only(_ybus_regulator_ratios(x, subtype))
        return ComplexF64[zf + n^2 * zt]
    elseif subtype == "open_delta_regulator"
        return ComplexF64[zf + n^2 * zt for n in _ybus_regulator_ratios(x, subtype)]
    end
    throw(ArgumentError("unknown transformer subtype: $subtype"))
end

function _xfmr_leakage_policy(x, subtype, zmin)
    z = _xfmr_leakage_values(x, subtype)
    all(isfinite, z) || throw(ArgumentError("nonfinite effective transformer leakage"))
    # A roundoff-rank-deficient ZB also requires a border when the configured
    # cutoff is zero. This chooses a representation; no mode is truncated.
    cutoff = subtype == "n_winding" ? max(zmin, eps(Float64)*length(z)*maximum(abs,z)) : zmin
    (exact_zero=all(iszero, z), needs_border=any(v -> abs(v) <= cutoff, z), impedances=z)
end

function _require_finite_xfmr_primitive(x, subtype, config)
    p = _xfmr_leakage_policy(x, subtype, _ybus_xfmr_z_min(_domain_thresholds(config)))
    p.needs_border && throw(ArgumentError(
        "$subtype leakage requires a bordered representation; use ybus_augmented " *
        "where supported, or shunt_only=true solely to inspect finite shunts"))
    p
end
