# Nodal admittance (Yprim) export for BMOPF transformer subtypes.
#
# For each transformer, builds the complex matrix Y ∈ ℂⁿˣⁿ over the terminal
# nodes such that I = Y·V, where I is the vector of currents INTO the element
# (out of the bus) and V is the vector of node voltages.
#
# Convention matches OpenDSS Yprim / DumpYprim: SI units (siemens), positive
# current = into the element, symmetric (Y = Yᵀ — reciprocal, NOT Hermitian).
#
# Construction: C' * y_prim * C + Y₀ (magnetising shunt across the winding-2 /
# to-side coil, the OpenDSS convention), where C maps node voltages to per-core
# winding voltages and y_prim is the block-diagonal primitive admittance. This
# guarantees Y = Yᵀ. See docs/transformer_admittance_derivation.md.
#
# All four subtypes are supported:
#   single_phase  — per-phase YY, Γ-model referred to HV (§2 of the note)
#   wye_delta     — Yd 3-phase, connection-matrix form (§3)
#   delta_wye     — Dy 3-phase, connection-matrix form (§3)
#   center_tap    — 3-winding star-equivalent T-model (§4)

"""
    transformer_yprim(xfmr, subtype) -> (nodes, Y)

Return the nodal admittance block for a single transformer data dict.

- `nodes`  — `Vector{Tuple{String,String}}` of `(bus_id, terminal_name)` pairs,
             in the same order as the rows/columns of `Y`.
- `Y`      — `Matrix{ComplexF64}`, SI siemens. Symmetric: `Y ≈ transpose(Y)`.

`subtype` must be one of `"single_phase"`, `"center_tap"`, `"wye_delta"`,
`"delta_wye"`.

The ordinary subtypes use the effective ratio
`N_eff = (v_nom_from/v_nom_to) · tap` (schema convention; `tap` defaults to
1.0), so a fixed off-nominal tap is reflected in the exported admittance.

The regulator subtypes `"single_phase_autotransformer"` and
`"open_delta_regulator"` use the fixed-tap effective ratio `n_eff`
(`BMOPFTools._autotransformer_ratio`) in place of the nameplate turns ratio.

Raises an `ArgumentError` for unknown subtypes. Returns `([], zeros(0,0))` when
the transformer is degenerate (zero `v_nom_to`, missing terminal maps).
"""
function transformer_yprim(xfmr::Dict{String,Any}, subtype::AbstractString)
    subtype == "single_phase" && return _yprim_single_phase(xfmr)
    subtype == "center_tap"   && return _yprim_center_tap(xfmr)
    subtype == "wye_delta"    && return _yprim_yd(xfmr; wye_is_from=true)
    subtype == "delta_wye"    && return _yprim_yd(xfmr; wye_is_from=false)
    subtype == "single_phase_autotransformer" && return _yprim_autotransformer(xfmr)
    subtype == "open_delta_regulator"          && return _yprim_open_delta(xfmr)
    throw(ArgumentError("unknown transformer subtype: $(repr(subtype))"))
end

"""
    export_yprim(net) -> Dict

Build the Yprim block for every transformer in the network and return a nested
Dict:

```
Dict(
  subtype => Dict(
    id => Dict("nodes" => [...], "Y_real" => [...], "Y_imag" => [...])
  )
)
```

Each `"nodes"` entry is a `Vector` of `[bus_id, terminal_name]` pairs.
`"Y_real"` and `"Y_imag"` are row-major dense matrices (Vector of Vector).
"""
function export_yprim(net::Dict{String,Any})::Dict{String,Any}
    result = Dict{String,Any}()
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding handled below
        sub = get(xfmr_dict, subtype, Dict())
        isempty(sub) && continue
        result[subtype] = Dict{String,Any}()
        for (tid, xfmr) in sub
            nodes, Y = transformer_yprim(xfmr, subtype)
            isempty(nodes) && continue
            result[subtype][tid] = Dict{String,Any}(
                "nodes"  => [[b, t] for (b, t) in nodes],
                "Y_real" => [real.(row) for row in eachrow(Y)],
                "Y_imag" => [imag.(row) for row in eachrow(Y)],
            )
        end
    end

    # Unknown subtypes are silently absent from the export otherwise — flag them.
    known = Set(TRANSFORMER_SUBTYPES)
    for (subtype, sub) in xfmr_dict
        (subtype in known || !(sub isa Dict) || isempty(sub)) && continue
        @warn "export_yprim: transformer subtype '$subtype' has no Yprim " *
              "builder — its $(length(sub)) device(s) are omitted from the export."
    end

    # n-winding transformers use their own (independent) Yprim builder.
    nwd = get(xfmr_dict, "n_winding", Dict())
    if !isempty(nwd)
        result["n_winding"] = Dict{String,Any}()
        for (tid, xfmr) in nwd
            nodes, Y = nwinding_yprim(xfmr)
            isempty(nodes) && continue
            result["n_winding"][tid] = Dict{String,Any}(
                "nodes"  => [[b, t] for (b, t) in nodes],
                "Y_real" => [real.(row) for row in eachrow(Y)],
                "Y_imag" => [imag.(row) for row in eachrow(Y)],
            )
        end
    end
    result
end

"""
    write_yprim(net, path)

Write the Yprim export for all transformers in `net` to a JSON file at `path`.
"""
function write_yprim(net::Dict{String,Any}, path::AbstractString)
    data = export_yprim(net)
    open(path, "w") do io
        JSON3.pretty(io, data)
    end
    nothing
end

# ── internal helpers ────────────────────────────────────────────────────────

# Build node list and read basic fields shared by all subtypes.
function _node_list(bus, tm)
    [(bus, string(t)) for t in tm]
end

# Winding neutral grounding admittance (OpenDSS rneut/xneut) for one side:
# y_n = 1/(R_n + jX_n) from the winding's neutral terminal to earth, INTERNAL
# to the transformer (matches OpenDSS's Yprim, where the neutral-node diagonal
# gains exactly y_n). Returns 0 when the fields are absent/zero.
function _xfmr_yn(xfmr, side::String)
    rn = Float64(get(xfmr, "r_neutral_$(side)", 0.0))
    xn = Float64(get(xfmr, "x_neutral_$(side)", 0.0))
    (rn == 0.0 && xn == 0.0) && return 0.0 + 0.0im
    1.0 / (rn + im * xn)
end

# ── single_phase ────────────────────────────────────────────────────────────

function _yprim_single_phase(xfmr::Dict{String,Any})
    b_fr  = get(xfmr, "bus_from", "")
    b_to  = get(xfmr, "bus_to",   "")
    tm_fr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tm_to = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    (isempty(tm_fr) || isempty(tm_to)) && return (Tuple{String,String}[], zeros(ComplexF64,0,0))

    N0   = _xfmr_turns_ratio(xfmr)
    tapm = _xfmr_tap_mult(xfmr)
    N    = N0 * tapm
    # One coupled winding per terminal pair (p, q): line-to-neutral (q = neutral),
    # line-to-line (q = second phase), or phase-to-ground (q absent). The winding
    # voltage and the no-load shunt are taken across (V_p − V_q) via Y = Cᵀ·prim·C.
    pairs_fr = _xfmr_winding_pairs(tm_fr)
    pairs_to = _xfmr_winding_pairs(tm_to)
    n_c = min(length(pairs_fr), length(pairs_to))

    r1 = Float64(get(xfmr, "r_series_from", 0.0))
    x1 = Float64(get(xfmr, "x_series_from", 0.0))
    r2 = Float64(get(xfmr, "r_series_to",   0.0))
    x2 = Float64(get(xfmr, "x_series_to",   0.0))
    # An off-nominal tap changes the FROM-winding turns, so the from-winding
    # leakage scales with tap² while the to-winding term carries the full N²
    # referral: Z = tap²·z_fr + N²·z_to = N²·(z_to + z_fr/N0²). This matches the
    # OPF builder `_add_yy_transformer!` (to-referred leakage held at nominal)
    # and OpenDSS's turns-scaled Yprim; at tap = 1 it is the classical
    # z_fr + N0²·z_to. (The from term was previously not tap-scaled, so the
    # export disagreed with both at any off-nominal tap.)
    Z  = (tapm^2 * r1 + N^2 * r2) + im*(tapm^2 * x1 + N^2 * x2)

    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))
    Y0_per = n_c > 0 ? (G0 + im*B0) / n_c : 0.0 + 0.0im

    # Internal neutral-grounding branch (OpenDSS rneut/xneut): y_n from the
    # side's shared neutral terminal to earth — a diagonal stamp, matching
    # OpenDSS's Yprim and the OPF builder `_add_yy_transformer!`. Applies only
    # to sides whose windings share a neutral (L-N maps).
    yn_fr = _xfmr_yn(xfmr, "from")
    yn_to = _xfmr_yn(xfmr, "to")
    use_yn_fr = !iszero(yn_fr) && _neutral_pos(tm_fr) !== nothing
    use_yn_to = !iszero(yn_to) && _neutral_pos(tm_to) !== nothing
    (!iszero(yn_fr) && !use_yn_fr) &&
        @warn "single_phase transformer: r/x_neutral_from set but the from side has no shared neutral terminal; ignored."
    (!iszero(yn_to) && !use_yn_to) &&
        @warn "single_phase transformer: r/x_neutral_to set but the to side has no shared neutral terminal; ignored."

    nodes    = Tuple{String,String}[]
    node_idx = Dict{Tuple{String,String},Int}()
    nidx!(b, t) = get!(node_idx, (b, t)) do
        push!(nodes, (b, t)); length(nodes)
    end
    # Register nodes in a deterministic order (from-phase, to-phase, then refs).
    for k in 1:n_c
        (p_fr, q_fr) = pairs_fr[k]; (p_to, q_to) = pairs_to[k]
        nidx!(b_fr, tm_fr[p_fr]); nidx!(b_to, tm_to[p_to])
        q_fr !== nothing && nidx!(b_fr, tm_fr[q_fr])
        q_to !== nothing && nidx!(b_to, tm_to[q_to])
    end
    n_tot = length(nodes)
    Y = zeros(ComplexF64, n_tot, n_tot)

    for k in 1:n_c
        (p_fr, q_fr) = pairs_fr[k]; (p_to, q_to) = pairs_to[k]
        ifp = nidx!(b_fr, tm_fr[p_fr]); itp = nidx!(b_to, tm_to[p_to])
        ifq = q_fr === nothing ? 0 : nidx!(b_fr, tm_fr[q_fr])
        itq = q_to === nothing ? 0 : nidx!(b_to, tm_to[q_to])

        # C rows: from coil (p_fr − q_fr), to coil (p_to − q_to).
        C = zeros(ComplexF64, 2, n_tot)
        C[1, ifp] = 1.0; ifq != 0 && (C[1, ifq] = -1.0)
        C[2, itp] = 1.0; itq != 0 && (C[2, itq] = -1.0)

        if !iszero(Z)
            Y .+= transpose(C) * ((1.0/Z) * [1.0 -N; -N N^2]) * C
        end
        # No-load (magnetising) shunt across the TO coil (p_to − q_to). OpenDSS
        # places the exciting branch on winding 2, referred to winding 2's coil
        # voltage — verified against its Yprim. `g/b_no_load` are therefore on
        # the to-side base (`from_dss` derives them there).
        if !iszero(Y0_per)
            Cf = reshape(C[2, :], 1, n_tot)
            Y .+= transpose(Cf) * Y0_per * Cf
        end
    end

    # Neutral-grounding branch: diagonal stamp at the shared neutral terminal.
    use_yn_fr && (Y[nidx!(b_fr, tm_fr[_neutral_pos(tm_fr)]),
                    nidx!(b_fr, tm_fr[_neutral_pos(tm_fr)])] += yn_fr)
    use_yn_to && (Y[nidx!(b_to, tm_to[_neutral_pos(tm_to)]),
                    nidx!(b_to, tm_to[_neutral_pos(tm_to)])] += yn_to)

    nodes, Y
end

# ── center_tap ──────────────────────────────────────────────────────────────

function _yprim_center_tap(xfmr::Dict{String,Any})
    b_fr  = get(xfmr, "bus_from", "")
    b_to  = get(xfmr, "bus_to",   "")
    tm_fr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tm_to = Vector{String}(get(xfmr, "terminal_map_to",   String[]))

    if length(tm_fr) != 2 || length(tm_to) != 3
        @warn "center_tap transformer: expected 2 HV and 3 LV terminals; got " *
              "$(length(tm_fr)) and $(length(tm_to)). Skipping."
        return (Tuple{String,String}[], zeros(ComplexF64,0,0))
    end

    N  = _xfmr_turns_ratio(xfmr) * _xfmr_tap_mult(xfmr)
    Z1 = Float64(get(xfmr, "r_series_from", 0.0)) + im*Float64(get(xfmr, "x_series_from", 0.0))
    Z2 = Float64(get(xfmr, "r_series_to",   0.0)) + im*Float64(get(xfmr, "x_series_to",   0.0))
    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))

    # Nodes: [HV-phase, HV-neutral, LV-leg1, LV-center-tap, LV-leg2]
    nodes = Tuple{String,String}[
        (b_fr, tm_fr[1]), (b_fr, tm_fr[2]),
        (b_to, tm_to[1]), (b_to, tm_to[2]), (b_to, tm_to[3]),
    ]

    # 3-port star admittance (all referred to LV).
    # Arms: HV (impedance Z1/N², admitted y1=N²/Z1), LV1 (Z2, y2), LV2 (Z2, y2).
    # LV-leg-2 winding spans V_c→V_g (same direction as leg-1 V_a→V_g).
    if iszero(Z1) || iszero(Z2)
        # A zero star arm makes the coupling (partly) ideal, which has no
        # admittance form: the series block is singular. Still stamp the no-load
        # shunt (previously dropped) so a zero-leakage unit keeps its core loss.
        @warn "center_tap transformer has a zero series star arm; the ideal " *
              "coupling has no admittance form — exporting the (singular) shunt-only Yprim."
        Y_deg = zeros(ComplexF64, 5, 5)
        Y0 = G0 + im*B0                    # across winding 2 (LV leg 1: nodes 3-4)
        Y_deg[3,3] += Y0; Y_deg[4,4] += Y0; Y_deg[3,4] -= Y0; Y_deg[4,3] -= Y0
        return nodes, Y_deg
    end

    y1 = N^2 / Z1
    y2 = 1.0  / Z2
    Ys = y1 + y2 + y2   # total star admittance

    # 3×3 star-equivalent admittance (winding ordering: [HV-ref, LV1, LV2])
    yv = (y1, y2, y2)
    Y3 = zeros(ComplexF64, 3, 3)
    for i in 1:3, j in 1:3
        Y3[i,j] = i == j ? yv[i] * (Ys - yv[i]) / Ys : -yv[i] * yv[j] / Ys
    end

    # Connection matrix C (3×5): maps node voltages [p,m,a,g,c] to winding voltages.
    # Row 1: V_HV_ref = (V_p - V_m)/N
    # Row 2: V_leg1   = V_a - V_g   (winding 2 dotted at leg 1)
    # Row 3: V_leg2   = V_g - V_c   (winding 3 dotted at the centre tap g)
    # Winding 3 is dotted at the centre tap, so its voltage is V_g − V_c (NOT
    # V_c − V_g). The opposite sign makes the two LV legs identical instead of
    # series-aiding; with the correct sign this Yprim matches OpenDSS exactly.
    C = zeros(ComplexF64, 3, 5)
    C[1,1] =  1.0/N;  C[1,2] = -1.0/N
    C[2,3] =  1.0;    C[2,4] = -1.0
    C[3,4] =  1.0;    C[3,5] = -1.0

    Y_core = transpose(C) * Y3 * C

    # No-load (magnetising) shunt across winding 2 = LV leg 1 (nodes 3-4, the
    # t1-tn coil at the per-leg voltage). OpenDSS places the ENTIRE exciting
    # branch on winding 2 — not split across the legs, and not on the HV side
    # (verified against its Yprim). `g/b_no_load` are on the per-leg LV base.
    Y0 = G0 + im*B0
    Y_core[3,3] += Y0; Y_core[4,4] += Y0; Y_core[3,4] -= Y0; Y_core[4,3] -= Y0

    nodes, Y_core
end

# ── wye_delta / delta_wye ───────────────────────────────────────────────────

function _yprim_yd(xfmr::Dict{String,Any}; wye_is_from::Bool)
    if wye_is_from
        b_wye  = get(xfmr, "bus_from", "")
        b_del  = get(xfmr, "bus_to",   "")
        tm_wye = Vector{String}(get(xfmr, "terminal_map_from", String[]))
        tm_del = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    else
        b_del  = get(xfmr, "bus_from", "")
        b_wye  = get(xfmr, "bus_to",   "")
        tm_del = Vector{String}(get(xfmr, "terminal_map_from", String[]))
        tm_wye = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    end

    (isempty(tm_wye) || isempty(tm_del)) && return (Tuple{String,String}[], zeros(ComplexF64,0,0))

    N     = _xfmr_turns_ratio(xfmr) * _xfmr_tap_mult(xfmr)
    # Delta-coil / wye-coil voltage ratio: V_del_coil = n_eff·V_wye_pn
    # (same convention as the OPF builder `_add_yd_transformer!`).
    n_eff = wye_is_from ? sqrt(3.0)/N : N*sqrt(3.0)

    # Per-winding impedances mapped to wye/delta sides.
    r_fr = Float64(get(xfmr, "r_series_from", 0.0))
    x_fr = Float64(get(xfmr, "x_series_from", 0.0))
    r_to = Float64(get(xfmr, "r_series_to",   0.0))
    x_to = Float64(get(xfmr, "x_series_to",   0.0))
    if wye_is_from
        Zw = (r_fr + im*x_fr); Zd = (r_to + im*x_to)
    else
        Zd = (r_fr + im*x_fr); Zw = (r_to + im*x_to)
    end

    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))

    n_ph  = length(tm_del)
    n_pos = _neutral_pos(tm_wye)
    ph_idx = _phase_positions(tm_wye)

    # Γ-equivalent series leakage referred to the WYE row of the primitive. The
    # delta-side r/x arrive on the delta BUS line-to-neutral base (1/n_ph of the
    # delta COIL base), so the coil impedance is n_ph·Zd.
    #
    # EXACT tap scaling (matches `_add_yd_transformer!` and OpenDSS's
    # short-circuit Yprim, verified: the tapped-side Z_sc ∝ tap²). With the
    # nominal wye-referred leakage Z_sc_nom = Zw + (n_ph/n_eff0²)·Zd:
    #   Yd (wye = from, tapped) : Z_total = (n_eff0/n_eff)²·Z_sc_nom   (∝ tap²)
    #   Dy (delta = from, tapped): Z_total = Z_sc_nom                  (constant)
    # At n_eff = n_eff0 both equal the legacy Zw + (n_ph/n_eff²)·Zd.
    n_eff0 = wye_is_from ? sqrt(3.0) / _xfmr_turns_ratio(xfmr) :
                           _xfmr_turns_ratio(xfmr) * sqrt(3.0)
    Z_sc_nom = Zw + (n_ph / n_eff0^2) * Zd
    Z_total  = wye_is_from ? (n_eff0 / n_eff)^2 * Z_sc_nom : Z_sc_nom

    n_wye  = length(tm_wye)
    n_tot  = n_wye + n_ph

    # Internal neutral-grounding branch (OpenDSS rneut/xneut) on the wye side:
    # y_n from the wye neutral terminal to earth — a diagonal stamp, matching
    # OpenDSS's Yprim and the OPF builder `_add_yd_transformer!`. The delta
    # side has no neutral; its fields are ignored (warned).
    yn_wye = _xfmr_yn(xfmr, wye_is_from ? "from" : "to")
    yn_del = _xfmr_yn(xfmr, wye_is_from ? "to" : "from")
    iszero(yn_del) ||
        @warn "wye_delta/delta_wye transformer: neutral impedance set on the DELTA side, which has no neutral; ignored."
    use_yn = !iszero(yn_wye) && n_pos !== nothing
    (!iszero(yn_wye) && !use_yn) &&
        @warn "wye_delta/delta_wye transformer: r/x_neutral set but the wye side has no neutral terminal; ignored."
    Y = zeros(ComplexF64, n_tot, n_tot)

    # Node ordering: [wye terminals..., delta terminals...]
    nodes = vcat(
        [(b_wye, t) for t in tm_wye],
        [(b_del, t) for t in tm_del],
    )

    if iszero(Z_total)
        @warn "wye_delta/delta_wye transformer has zero effective series impedance; " *
              "the ideal coupling has no admittance form — exporting the (singular) shunt-only Yprim."
    else
        yt = 1.0 / Z_total

        # Per-core primitive with rows [wye, delta]. The ideal coil relation is
        # V_del_coil = n_eff·V_wye_pn, i.e. V_wye = a·V_del with a = 1/n_eff, and
        # the series leakage Z_total sits on the wye row:
        #   I_wye = (V_wye − a·V_del)/Z_total,   I_del_coil = −a·I_wye
        # ⇒ y_prim^(k) = yt·[1, −a; −a, a²].  (Stamping n_eff instead of a here
        # inverts the transformer — the exported no-load point lands at
        # V_del = V_wye/n_eff instead of n_eff·V_wye.)
        #
        # Connection matrix C (2*n_ph × n_tot):
        #   Row k (wye winding k):   C[k, ph_idx[k]] = 1, C[k, neutral] = -1
        #   Row n_ph+k (delta winding k): C[n_ph+k, n_wye+k] = 1, C[n_ph+k, n_wye+k_other] = -1
        #
        # Build C and y_prim, then Y = C' * y_prim * C.
        n_rows = 2 * n_ph
        C      = zeros(ComplexF64, n_rows, n_tot)

        for k in 1:n_ph
            ph = ph_idx[k]
            # Wye winding k: voltage = V_wye_ph[k] - V_wye_neutral
            C[k, ph] = 1.0
            if n_pos !== nothing
                C[k, n_pos] = -1.0
            end
            # Delta winding k:
            # Yd uses k_next; Dy uses k_prev (backward delta convention from OPF).
            k_other = wye_is_from ? (k % n_ph) + 1 : ((k - 2 + n_ph) % n_ph) + 1
            C[n_ph+k, n_wye+k]       =  1.0
            C[n_ph+k, n_wye+k_other] = -1.0
        end

        # y_prim: 2n_ph × 2n_ph block-diagonal, each core's 2×2 in rows [k, n_ph+k].
        a = 1.0 / n_eff
        prim_block = yt * [1.0 -a; -a a^2]
        y_prim = zeros(ComplexF64, n_rows, n_rows)
        for k in 1:n_ph
            rows = [k, n_ph+k]
            y_prim[rows, rows] .= prim_block
        end

        Y .= transpose(C) * y_prim * C
    end

    # Neutral-grounding branch: diagonal stamp at the wye neutral terminal.
    use_yn && (Y[n_pos, n_pos] += yn_wye)

    # No-load (magnetising) shunt across the WINDING-2 (to-side) coils, referred
    # to winding 2's coil voltage — OpenDSS places the exciting branch on
    # winding 2 (verified against its Yprim). `g/b_no_load` is the total on the
    # to-side coil base, split equally over the n_ph coils and stamped across
    # each: a delta of branches for a delta winding 2 (Yd), phase-to-neutral for
    # a wye winding 2 (Dy).
    if !iszero(G0) || !iszero(B0)
        y_per = (G0 + im*B0) / n_ph
        for k in 1:n_ph
            if wye_is_from
                # to side = delta: coil across delta terminals k and k_next.
                a = n_wye + k
                b = n_wye + (k % n_ph) + 1
            else
                # to side = wye: coil phase-to-neutral (implicit ground if no n).
                a = ph_idx[k]
                b = n_pos
            end
            Y[a, a] += y_per
            if b !== nothing
                Y[b, b] += y_per
                Y[a, b] -= y_per; Y[b, a] -= y_per
            end
        end
    end

    nodes, Y
end

# ── single_phase_autotransformer ──────────────────────────────────────────────

# Step voltage regulator / autotransformer. Structurally a YY core with the
# fixed-tap effective ratio n_eff (= 1/tap_ratio for Type B, tap_ratio for
# Type A) and a SHARED neutral: the from and to windings reference their own
# neutral terminal, and KCL at each neutral closes the common-winding return.
#
# Nodes: [fr_ph, to_ph, (fr_q), (to_q)]. One core spanning (V_fr_ph − V_fr_q)
# and (V_to_ph − V_to_q), primitive yt·[1 −n_eff; −n_eff n_eff²] via Y = Cᵀ·yprim·C.
# The winding reference q is the neutral (line-to-neutral SVR) or the second phase
# (line-to-line SVR); the shared bushing tie is an OPF topological constraint.
function _yprim_autotransformer(xfmr::Dict{String,Any})
    b_fr  = get(xfmr, "bus_from", "")
    b_to  = get(xfmr, "bus_to",   "")
    tm_fr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tm_to = Vector{String}(get(xfmr, "terminal_map_to",   String[]))

    pairs_fr = _xfmr_winding_pairs(tm_fr); pairs_to = _xfmr_winding_pairs(tm_to)
    if isempty(pairs_fr) || isempty(pairs_to)
        @warn "single_phase_autotransformer: needs a phase conductor on each side."
        return (Tuple{String,String}[], zeros(ComplexF64, 0, 0))
    end
    n_eff = _autotransformer_ratio(xfmr)

    r1 = Float64(get(xfmr, "r_series_from", 0.0))
    x1 = Float64(get(xfmr, "x_series_from", 0.0))
    r2 = Float64(get(xfmr, "r_series_to",   0.0))
    x2 = Float64(get(xfmr, "x_series_to",   0.0))
    Z  = (r1 + n_eff^2 * r2) + im*(x1 + n_eff^2 * x2)
    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))

    (p_fr, q_fr) = pairs_fr[1]; (p_to, q_to) = pairs_to[1]
    t_fr_ph = tm_fr[p_fr]; t_fr_n = q_fr === nothing ? nothing : tm_fr[q_fr]
    t_to_ph = tm_to[p_to]; t_to_n = q_to === nothing ? nothing : tm_to[q_to]

    # Node order: phase-from, phase-to, [ref-from], [ref-to].
    nodes = Tuple{String,String}[(b_fr, t_fr_ph), (b_to, t_to_ph)]
    idx_fr_n = idx_to_n = 0
    t_fr_n !== nothing && (push!(nodes, (b_fr, t_fr_n)); idx_fr_n = length(nodes))
    t_to_n !== nothing && (push!(nodes, (b_to, t_to_n)); idx_to_n = length(nodes))
    n_tot = length(nodes)

    Y = zeros(ComplexF64, n_tot, n_tot)
    if iszero(Z)
        # Ideal regulator: the series block is singular; only the shunt is finite.
        iszero(G0) && iszero(B0) &&
            @warn "single_phase_autotransformer has zero series impedance; Yprim is singular."
    else
        yt = 1.0 / Z
        # C (2 winding-voltage rows × n_tot): row 1 = from coil (ph_fr − n_fr),
        # row 2 = to coil (ph_to − n_to).
        C = zeros(ComplexF64, 2, n_tot)
        C[1, 1] = 1.0;  idx_fr_n != 0 && (C[1, idx_fr_n] = -1.0)
        C[2, 2] = 1.0;  idx_to_n != 0 && (C[2, idx_to_n] = -1.0)
        prim = yt * [1.0 -n_eff; -n_eff n_eff^2]
        Y .= transpose(C) * prim * C
    end

    # No-load shunt ACROSS the from winding (ph_fr − ref_fr), matching the OPF
    # builder `_add_regulating_winding!`, which injects the shunt return at the
    # winding reference terminal (phase-to-ground only when no reference exists).
    # Previously stamped Y[1,1]-only (phase-to-ground), which diverged from the
    # OPF whenever the reference/neutral voltage was nonzero.
    if !iszero(G0) || !iszero(B0)
        Cf = zeros(ComplexF64, 1, n_tot)
        Cf[1, 1] = 1.0;  idx_fr_n != 0 && (Cf[1, idx_fr_n] = -1.0)
        Y .+= transpose(Cf) * (G0 + im*B0) * Cf
    end
    nodes, Y
end

# ── open_delta_regulator ──────────────────────────────────────────────────────

# Phase-pair index map for the open-delta Yprim (mirrors the OPF dispatch in
# ext/BMOPFOpfExt/transformer.jl _OPEN_DELTA_PAIRS).
const _OPEN_DELTA_YPRIM_PAIRS = Dict{String,Tuple{Tuple{Int,Int},Tuple{Int,Int}}}(
    "ABBC" => ((1, 2), (2, 3)),
    "BCAC" => ((2, 3), (1, 3)),
    "CABA" => ((3, 1), (2, 1)),
)

# Monolithic open-delta regulator: two line-to-line regulating cores across the
# phase pairs implied by `connection`, each with its own tap. No neutral winding
# path. Nodes: [fr_1,fr_2,fr_3,(fr_n), to_1,to_2,to_3,(to_n)].
function _yprim_open_delta(xfmr::Dict{String,Any})
    b_fr  = get(xfmr, "bus_from", "")
    b_to  = get(xfmr, "bus_to",   "")
    tm_fr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tm_to = Vector{String}(get(xfmr, "terminal_map_to",   String[]))

    pairs = get(_OPEN_DELTA_YPRIM_PAIRS,
                uppercase(strip(string(get(xfmr, "connection", "")))), nothing)
    ph_fr = _phase_positions(tm_fr); ph_to = _phase_positions(tm_to)
    if pairs === nothing || length(ph_fr) < 3 || length(ph_to) < 3
        @warn "open_delta_regulator: bad connection or <3 phase conductors."
        return (Tuple{String,String}[], zeros(ComplexF64, 0, 0))
    end

    taps = Float64.(get(xfmr, "tap_ratio", Float64[]))
    rt   = string(get(xfmr, "regulator_type", "B"))
    a1 = length(taps) >= 1 ? taps[1] : 1.0
    a2 = length(taps) >= 2 ? taps[2] : a1
    n_eff = (_autotransformer_neff(a1, rt), _autotransformer_neff(a2, rt))

    r1 = Float64(get(xfmr, "r_series_from", 0.0))
    x1 = Float64(get(xfmr, "x_series_from", 0.0))
    r2 = Float64(get(xfmr, "r_series_to",   0.0))
    x2 = Float64(get(xfmr, "x_series_to",   0.0))

    # Per-regulator no-load (core-loss) shunt, stamped across each from-side
    # line-to-line pair (mirrors the OPF builder _add_open_delta_regulator!).
    Y0 = Float64(get(xfmr, "g_no_load", 0.0)) + im*Float64(get(xfmr, "b_no_load", 0.0))

    # Node order: all from terminals (terminal_map order), then all to terminals.
    nodes = vcat([(b_fr, t) for t in tm_fr], [(b_to, t) for t in tm_to])
    n_fr  = length(tm_fr)
    fr_pos(p) = ph_fr[p]            # node index within the from block
    to_pos(p) = n_fr + ph_to[p]    # node index within the to block
    n_tot = length(nodes)
    Y = zeros(ComplexF64, n_tot, n_tot)

    for (j, (p, q)) in enumerate(pairs)
        ne = n_eff[j]
        Z  = (r1 + ne^2 * r2) + im*(x1 + ne^2 * x2)
        if !iszero(Z)
            yt = 1.0 / Z
            C = zeros(ComplexF64, 2, n_tot)
            C[1, fr_pos(p)] = 1.0;  C[1, fr_pos(q)] = -1.0
            C[2, to_pos(p)] = 1.0;  C[2, to_pos(q)] = -1.0
            prim = yt * [1.0 -ne; -ne ne^2]
            Y .+= transpose(C) * prim * C
        end
        # No-load shunt across the from-side line-to-line pair (p − q).
        if !iszero(Y0)
            Cf = zeros(ComplexF64, 1, n_tot)
            Cf[1, fr_pos(p)] = 1.0;  Cf[1, fr_pos(q)] = -1.0
            Y .+= transpose(Cf) * Y0 * Cf
        end
    end

    # This is the device's natural line-to-line primitive admittance — exactly
    # the "unspecified neutral" matrix of Yan et al. 2018 (IEEE TSG 9(3):2224),
    # Eq. (11): the self/mutual terms are yr, the shared phase gets 2·yr on its
    # diagonal (both regulators), and the from↔to coupling scales as the
    # autotransformer factor r (= our n_eff) and r² — NOT an isolated-transformer
    # ratio. The galvanic straight-through of the shared phase (the paper's
    # physically-correct "common neutral" model, Eq. 14: V_shared_fr = V_shared_to)
    # is NOT folded into this primitive — it is a topological constraint imposed
    # in the OPF (_add_open_delta_regulator!). Folding it here (the paper's Eq. 15)
    # would conflate the device admittance with a particular elimination of the
    # shared node, so the export keeps the Eq. (11) device primitive.
    nodes, Y
end

# ── n_winding (general n-winding, WYE and/or DELTA) ─────────────────────────
#
# Independent of `transformer_yprim`. Builds the exact n-winding leakage primitive
# from the OpenDSS-style ZB matrix (referred to winding 1): YB = ZB⁻¹ is the
# (n-1)-port admittance; expanding with winding 1 as the reference node gives the
# referred n×n admittance Yref = Cᵀ·YB·C, and de-referring by the turns ratios
# gives the per-winding admittance Yw = D⁻¹·Yref·D⁻¹ (D = diag(N_k)). Yw is
# stamped per leg via the connection-aware coil incidence P: a WYE coil maps to
# its phase-neutral pair, a DELTA coil to its phase-phase pair (so delta windings
# couple phase nodes). The optional no-load shunt is stamped across winding 2 (OpenDSS convention).
function nwinding_yprim(xfmr::Dict{String,Any})
    ws = _nw_windings(xfmr)
    nW = length(ws)
    nW < 2 && return (Tuple{String,String}[], zeros(ComplexF64, 0, 0))

    N  = _nw_turns_ratios(xfmr)
    ZB = _nw_zb_matrix(xfmr)                         # (n-1)×(n-1), referred to wdg 1
    local YB
    try
        YB = inv(ZB)
    catch
        @warn "n_winding transformer ZB is singular; Yprim skipped."
        return (Tuple{String,String}[], zeros(ComplexF64, 0, 0))
    end

    # Referred n-port admittance with winding 1 as reference: Yref = Cᵀ YB C,
    # C[i, :] = e_1 − e_{i+1}. Then de-refer by the turns ratios.
    C = zeros(ComplexF64, nW - 1, nW)
    for i in 1:nW-1
        C[i, 1] = 1.0; C[i, i+1] = -1.0
    end
    # I^r = −Cᵀ Jr with Jr = −YB·(C V^r) ⇒ Yref = +Cᵀ YB C (passive form).
    Yref = transpose(C) * YB * C
    Dinv = ComplexF64[iszero(N[k]) ? 0.0 : 1.0 / N[k] for k in 1:nW]
    Yw = ComplexF64[Dinv[i] * Yref[i, j] * Dinv[j] for i in 1:nW, j in 1:nW]

    nodes    = Tuple{String,String}[]
    node_idx = Dict{Tuple{String,String},Int}()
    nidx!(b, t) = get!(node_idx, (b, t)) do
        push!(nodes, (b, t)); length(nodes)
    end
    for w in ws
        phs, neu = _nw_phase_terminals(w.terminal_map)
        for p in phs; nidx!(w.bus, p); end
        neu !== nothing && nidx!(w.bus, neu)
    end
    n_tot = length(nodes)
    Y = zeros(ComplexF64, n_tot, n_tot)

    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))
    Y0 = G0 + im*B0

    phases1, _ = _nw_phase_terminals(ws[1].terminal_map)
    for pk in eachindex(phases1)
        # Map each winding's phase-neutral voltage onto the node list.
        P = zeros(ComplexF64, nW, n_tot)
        for (k, w) in enumerate(ws)
            phs, neu = _nw_phase_terminals(w.terminal_map)
            P[k, nidx!(w.bus, phs[pk])] = 1.0
            if w.connection == "DELTA"
                po = _nw_delta_other(pk, length(phs), w.delta_roll)
                P[k, nidx!(w.bus, phs[po])] = -1.0
            elseif neu !== nothing
                P[k, nidx!(w.bus, neu)] = -1.0
            end
        end
        Y .+= transpose(P) * Yw * P

        # No-load (magnetising) shunt across WINDING 2's coil — OpenDSS places
        # the exciting branch on winding 2 (verified against its Yprim), not
        # winding 1. `g/b_no_load` are on winding 2's coil base.
        if !iszero(Y0) && nW >= 2
            w2 = ws[2]; phs2, neu2 = _nw_phase_terminals(w2.terminal_map)
            Cf = zeros(ComplexF64, 1, n_tot)
            Cf[1, nidx!(w2.bus, phs2[pk])] = 1.0
            if w2.connection == "DELTA"
                po = _nw_delta_other(pk, length(phs2), w2.delta_roll)
                Cf[1, nidx!(w2.bus, phs2[po])] = -1.0
            elseif neu2 !== nothing
                Cf[1, nidx!(w2.bus, neu2)] = -1.0
            end
            Y .+= transpose(Cf) * Y0 * Cf
        end
    end

    nodes, Y
end
