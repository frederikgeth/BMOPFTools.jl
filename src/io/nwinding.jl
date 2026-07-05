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
#   windings   :: Vector of {bus, terminal_map, v_nom, connection, r_winding,
#                 delta_roll}
#   x_sc       :: Dict "i_j" => pairwise short-circuit reactance (Ω), i<j,
#                 ALL referred to winding-1's COIL base (see below).
#   s_rating, g_no_load, b_no_load (optional)
#
# Winding 1 is the reference. `connection` is "WYE" or "DELTA"; a WYE winding's
# `v_nom` is its line-to-neutral coil voltage and its terminal_map carries a
# neutral, while a DELTA winding's `v_nom` is its line-to-line coil voltage and
# it carries no neutral. `delta_roll` (±1, DELTA only) selects the coil rotation
# (vector group); OpenDSS's standard delta corresponds to `delta_roll = -1`.
#
# Impedance referral base. r_winding[k] and x_sc are in Ω on the per-winding COIL
# base `z_coil = n_ph · v_nom² / S_rating` — line-to-neutral for WYE (= V_LL²/S)
# and line-to-line for DELTA (= n_ph · V_LL²/S, i.e. n_ph× the naive V_LL²/S). The
# √3/coil-base factor lives entirely in `v_nom`, so the model formulas below are
# connection-agnostic: r_winding[k] is at winding k's own coil base (referred to
# winding 1 via /N_k²), and x_sc is at winding 1's coil base.

"""
    _nw_windings(xfmr) -> Vector{NamedTuple}

Return the ordered winding list of an `n_winding` transformer as
`(bus, terminal_map, v_nom, connection, r_winding)` named tuples. Reads only the
`windings` field — never `bus_from`/`bus_to`.
"""
function _nw_windings(xfmr::Dict{String,Any})
    raw = get(xfmr, "windings", nothing)
    raw isa AbstractVector || return NamedTuple[]
    out = NamedTuple[]
    for w in raw
        w isa AbstractDict || continue
        imx = get(w, "i_max", nothing)
        push!(out, (
            bus          = string(get(w, "bus", "")),
            terminal_map = Vector{String}(string.(get(w, "terminal_map", String[]))),
            v_nom        = Float64(get(w, "v_nom", 1.0)),        # JSON key: v_nom
            connection   = uppercase(string(get(w, "configuration", "WYE"))),  # JSON key: configuration
            r_winding    = Float64(get(w, "r_winding", 0.0)),
            delta_roll   = Int(get(w, "delta_roll", 1)),
            i_max        = imx isa Real ? Float64(imx) : nothing,  # optional per-winding current limit (A)
        ))
    end
    out
end

"""
    _nw_turns_ratios(xfmr) -> Vector{Float64}

Per-winding turns ratio `N_k = v_nom[k] / v_nom[1]` (so `N_1 == 1`). Winding 1 is
the reference. Independent of `_xfmr_turns_ratio`.
"""
function _nw_turns_ratios(xfmr::Dict{String,Any})::Vector{Float64}
    ws = _nw_windings(xfmr)
    isempty(ws) && return Float64[]
    v1 = ws[1].v_nom
    iszero(v1) ? fill(1.0, length(ws)) : [w.v_nom / v1 for w in ws]
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
    _nw_delta_other(pk, nph, roll=1) -> Int

The far-end phase position of the delta coil on leg `pk`. The coil spans phase
terminal `pk` and the returned position: forward (`roll ≥ 0`) connects `pk → pk+1`
(wrapping `nph → 1`), backward (`roll < 0`) connects `pk → pk-1`. Forward is the
default 1→2→3→1 OpenDSS delta arrangement; `roll = -1` reverses it to match the
opposite vector-group rotation.
"""
_nw_delta_other(pk::Int, nph::Int, roll::Int=1) =
    roll >= 0 ? (pk % nph) + 1 : ((pk - 2 + nph) % nph) + 1

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
(`N_k = v_nom[k]/v_nom[1]`); `x_sc` is already on winding 1's base.
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
    _nw_xb_eigvals(xfmr) -> Union{Vector{Float64},Nothing}

Eigenvalues of the symmetrised **reactance** part of the `n_winding` ZB
short-circuit matrix (`imag(ZB)`, SI Ω on winding-1's base). `nothing` for `n < 2`
(no leakage matrix).

Physical realisability test: the leakage network of a passive set of coupled
coils stores non-negative magnetic energy, so `imag(ZB)` must be **positive
semidefinite**. A materially negative eigenvalue means no lossless coupled-coil
model reproduces the given pairwise `x_sc` values — the short-circuit reactances
are mutually inconsistent.

This is the multi-winding generalisation of "each pairwise short-circuit
reactance is inductive", and it is the CORRECT discriminator — deliberately *not*
"every ZB diagonal is positive". A ZB diagonal (star/T branch) entry may be
negative and still perfectly physical (see [`_nw_zb_matrix`](@ref)); only the
matrix-level PSD property is invariant. For `n = 3` the PSD condition reduces
exactly to the realisability triangle inequality
`X₁₂·X₁₃ ≥ ¼(X₁₂ + X₁₃ − X₂₃)²`.
"""
function _nw_xb_eigvals(xfmr::Dict{String,Any})::Union{Vector{Float64},Nothing}
    ZB = _nw_zb_matrix(xfmr)
    isempty(ZB) && return nothing
    Xb = imag(ZB)
    eigvals(Symmetric((Xb + transpose(Xb)) / 2))
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
