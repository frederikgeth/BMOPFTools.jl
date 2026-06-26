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
    _nw_star_reactances_ref1(xfmr) -> Vector{Float64}

Solve the pairwise short-circuit reactances `x_sc` for the per-winding star/T
leg reactances, **referred to winding-1's base** (the base `x_sc` is stored on).

For `n` windings the star legs satisfy `X_i + X_j = X_ij` for every pair. This is
exactly determined for `n == 3`, under-determined for `n == 2` (all leakage is
placed on winding 1), and over-determined for `n > 3` (resolved by least squares
— the closed-form solution of `((n-2)I + J) x = b`, where `b_i = Σ_{j≠i} X_ij`).

A star leg may be **negative** for `n ≥ 3` — that is physically correct, not an
error.
"""
function _nw_star_reactances_ref1(xfmr::Dict{String,Any})::Vector{Float64}
    n = length(_nw_windings(xfmr))
    n == 0 && return Float64[]
    xsc = get(xfmr, "x_sc", Dict{String,Any}())

    pair(i, j) = Float64(get(xsc, "$(min(i,j))_$(max(i,j))", 0.0))

    n == 1 && return [0.0]
    if n == 2
        # Under-determined: place the whole leakage on winding 1.
        return [pair(1, 2), 0.0]
    end

    # b_i = Σ_{j≠i} X_ij ;  solve ((n-2) I + J) x = b in closed form:
    #   x = (1/c) (b − (Σb / (c+n)) · 1),  c = n-2.
    b = [sum(pair(i, j) for j in 1:n if j != i) for i in 1:n]
    c = n - 2
    s = sum(b)
    return [(b[i] - s / (c + n)) / c for i in 1:n]
end

"""
    _nw_star_residual(xfmr) -> Float64

Maximum *relative* residual of the star fit `X_i + X_j ≈ X_ij` over all winding
pairs. Zero (to rounding) for `n ≤ 3` and for star-consistent data; non-zero for
`n ≥ 4` whose pairwise reactances cannot be reproduced by a single star node
(the model is then a least-squares approximation). Used to flag the approximation
to the user.
"""
function _nw_star_residual(xfmr::Dict{String,Any})::Float64
    n = length(_nw_windings(xfmr))
    n <= 3 && return 0.0
    X   = _nw_star_reactances_ref1(xfmr)
    xsc = get(xfmr, "x_sc", Dict{String,Any}())
    worst = 0.0
    for i in 1:n, j in i+1:n
        xij = Float64(get(xsc, "$(i)_$(j)", 0.0))
        denom = max(abs(xij), eps())
        worst = max(worst, abs(X[i] + X[j] - xij) / denom)
    end
    worst
end

"""
    _nw_star_legs(xfmr) -> Vector{Tuple{Float64,Float64}}

Per-winding star/T leg impedance `(R_k, X_k)` in **winding k's own base**, in
whatever units the dict currently holds (SI Ω for the Ybus path; per-unit after
`_pu_scale_nwinding!` has scaled the inputs).

- `R_k = r_winding[k]` (already on winding k's own base).
- `X_k = X_k^(ref1) · N_k²`, referring the ref-1 star reactance to winding k's
  own base (`N_k = v_ref[k]/v_ref[1]`).

Note: in per-unit the leg value is base-invariant, so the per-unit path stores
pre-scaled legs rather than re-deriving here — see `_pu_scale_nwinding!`.
"""
function _nw_star_legs(xfmr::Dict{String,Any})::Vector{Tuple{Float64,Float64}}
    ws = _nw_windings(xfmr)
    isempty(ws) && return Tuple{Float64,Float64}[]
    N  = _nw_turns_ratios(xfmr)
    Xr = _nw_star_reactances_ref1(xfmr)
    [(ws[k].r_winding, Xr[k] * N[k]^2) for k in eachindex(ws)]
end
