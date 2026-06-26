# io/nwinding.jl
#
# General n-winding transformer support — shared (non-OPF) helpers.
#
# This is a deliberately INDEPENDENT code path from the two-bus transformer
# subtypes (single_phase, center_tap, wye_delta, …). It reads only the
# winding-indexed `n_winding` data shape (`xfmr["windings"]` + `xfmr["x_sc"]`)
# and shares nothing with the `_xfmr_*` / `transformer_yprim` helpers. The OPF
# variable allocation and constraint builder live separately in
# `ext/BMOPFOpfExt/nwinding.jl`.
#
# Data shape (subtype "n_winding"):
#   windings   :: Vector of {bus, terminal_map, v_ref, connection, r_winding}
#   x_sc       :: Dict "i_j" => pairwise short-circuit reactance (Ω), i<j,
#                 ALL referred to winding-1's voltage base.
#   s_rating, g_no_load, b_no_load (optional)
#
# Winding 1 is the reference. r_winding[k] is in Ω at winding k's OWN base
# (mirroring the per-side convention of the two-bus subtypes).

"""
    _nw_windings(xfmr) -> Vector{NamedTuple}

Return the ordered winding list of an `n_winding` transformer as
`(bus, terminal_map, v_ref, connection, r_winding)` named tuples. Reads only the
`windings` field — never `bus_from`/`bus_to`.
"""
function _nw_windings(xfmr::Dict{String,Any})
    raw = get(xfmr, "windings", nothing)
    raw isa AbstractVector || return NamedTuple[]
    out = NamedTuple[]
    for w in raw
        w isa AbstractDict || continue
        push!(out, (
            bus          = string(get(w, "bus", "")),
            terminal_map = Vector{String}(string.(get(w, "terminal_map", String[]))),
            v_ref        = Float64(get(w, "v_ref", 1.0)),
            connection   = uppercase(string(get(w, "connection", "WYE"))),
            r_winding    = Float64(get(w, "r_winding", 0.0)),
        ))
    end
    out
end

"""
    _nw_turns_ratios(xfmr) -> Vector{Float64}

Per-winding turns ratio `N_k = v_ref[k] / v_ref[1]` (so `N_1 == 1`). Winding 1 is
the reference. Independent of `_xfmr_turns_ratio`.
"""
function _nw_turns_ratios(xfmr::Dict{String,Any})::Vector{Float64}
    ws = _nw_windings(xfmr)
    isempty(ws) && return Float64[]
    v1 = ws[1].v_ref
    iszero(v1) ? fill(1.0, length(ws)) : [w.v_ref / v1 for w in ws]
end

"""
    _nw_phase_terminals(terminal_map) -> (phases, neutral)

Split a winding terminal map into its ordered phase terminals (`a`/`b`/`c`,
case-insensitive) and its single neutral terminal (`n`), or `nothing` if absent.
Self-contained; does not call the shared `_phase_positions` helper.
"""
function _nw_phase_terminals(terminal_map::Vector{String})
    phases  = String[]
    neutral = nothing
    for t in terminal_map
        lt = lowercase(t)
        if lt in ("a", "b", "c")
            push!(phases, t)
        elseif lt == "n"
            neutral = t
        end
    end
    (phases, neutral)
end

"""
    _nw_zb_matrix(xfmr) -> Matrix{ComplexF64}

The OpenDSS-style **ZB short-circuit impedance matrix**, `(n-1)×(n-1)`, all
referred to **winding 1's base**, in whatever units the dict holds (SI Ω for the
Ybus path; per-unit when the per-unit pass has stored `_zb_re`/`_zb_im`).

With winding 1 as reference, rows/cols index windings `2..n`. From the pairwise
short-circuit impedances `Z_{a,b} = (r_a + r_b) + j·X_{a,b}` (referred to
winding 1):

    ZB[i,i] = Z_{1,i+1}
    ZB[i,j] = ½(Z_{1,i+1} + Z_{1,j+1} − Z_{i+1,j+1})

This captures the leakage **exactly for any n** — `ZB` has `n(n-1)/2` independent
entries, one per pairwise reactance, and reconstructs them all (no approximation;
for `n ≤ 3` it equals the star/T model). A diagonal entry can be negative for
`n ≥ 3`, which is physical.

`r_winding[k]` is referred from winding k's own base to winding 1 via `/N_k²`
(`N_k = v_ref[k]/v_ref[1]`); `x_sc` is already on winding 1's base.
"""
function _nw_zb_matrix(xfmr::Dict{String,Any})::Matrix{ComplexF64}
    ws = _nw_windings(xfmr)
    n  = length(ws)
    n < 2 && return zeros(ComplexF64, 0, 0)
    N   = _nw_turns_ratios(xfmr)
    xsc = get(xfmr, "x_sc", Dict{String,Any}())

    # Per-winding resistance referred to winding 1, and pairwise impedance Z_{a,b}.
    r1(k) = ws[k].r_winding / N[k]^2
    xpair(a, b) = Float64(get(xsc, "$(min(a,b))_$(max(a,b))", 0.0))
    Z(a, b) = (r1(a) + r1(b)) + im * xpair(a, b)

    ZB = zeros(ComplexF64, n - 1, n - 1)
    for i in 1:n-1, j in 1:n-1
        ZB[i, j] = i == j ? Z(1, i + 1) :
                   0.5 * (Z(1, i + 1) + Z(1, j + 1) - Z(i + 1, j + 1))
    end
    ZB
end

"""
    _nw_zb_for_opf(xfmr) -> Matrix{ComplexF64}

ZB matrix in model units for the OPF: the per-unit `_zb_re`/`_zb_im` stored by
`_pu_scale_nwinding!` when present, otherwise the SI matrix from
[`_nw_zb_matrix`](@ref).
"""
function _nw_zb_for_opf(xfmr::Dict{String,Any})::Matrix{ComplexF64}
    if haskey(xfmr, "_zb_re") && haskey(xfmr, "_zb_im")
        re = xfmr["_zb_re"]; im_ = xfmr["_zb_im"]
        m = length(re)
        return ComplexF64[Float64(re[i][j]) + im * Float64(im_[i][j])
                          for i in 1:m, j in 1:m]
    end
    _nw_zb_matrix(xfmr)
end
