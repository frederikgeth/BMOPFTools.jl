# Transformer constraints — four-wire rectangular IVR formulation.
#
# All transformer constraints are linear.
#
# ── single_phase (per-phase YY) ────────────────────────────────────────────
#   N = v_nom_from / v_nom_to
#   Voltage : vr_fr − N·vr_to = R·cr_series − X·ci_series
#   Current : N·I_series_fr + I_to = 0
#   Shunt   : I_mag = (G + jB)·V_fr  added to KCL at from terminals
#
# ── center_tap (split-phase, North American distribution) ──────────────────
#   from: bus_fr  terminal_map_from = ["1","n"]      (HV phase + neutral)
#   to:   bus_lv  terminal_map_to   = ["1","n","2"]  (leg-1, center-tap, leg-2)
#   N = v_nom_from / v_nom_to  (v_nom_to is the 120 V leg rating)
#
#   T-model: primary impedance (R1,X1) on HV; per-leg secondary (R2,X2) on each LV branch.
#   This correctly captures load-asymmetry: unequal leg currents → unequal leg voltages.
#
#   Voltage (HV-side form, legs independently):
#     (V_fr[1]−V_fr[n]) − N·(V_lv[1]−V_lv[n]) = R1·I_s − X1·jI_s + N·(R2·I_leg1 − X2·jI_leg1)
#     (V_fr[1]−V_fr[n]) − N·(V_lv[n]−V_lv[2]) = R1·I_s − X1·jI_s + N·(R2·I_leg2 − X2·jI_leg2)
#
#   Current (power conservation):
#     N·I_s + I_leg1 + I_leg2 = 0
#
#   Center-tap KCL (n terminal, not a floating node):
#     I_n + I_leg1 + I_leg2 = 0
#
#   KCL contributions: bus_fr -= I_fr (series + shunt), bus_lv -= I_lv_k
#
# ── wye_delta (Yd) ─────────────────────────────────────────────────────────
#   Wye side (from) : n_ph phase terminals + 1 neutral
#   Delta side (to) : n_ph terminals
#   N = v_nom_from / v_nom_to  (both v_nom as phase-to-neutral equivalents)
#   n_eff = √3 / N             (effective turns ratio per winding)
#
#   Voltage (k = 1..n_ph, k_next = k%n_ph + 1):
#     vr_del[k] - vr_del[k_next] = n_eff * (vr_wye_ph[k] - vr_wye_neutral)
#
#   Current (T^T of voltage transform, power-conservative):
#     n_eff * cr_xf[del,k] = cr_xf[wye,ph_k] - cr_xf[wye,ph_{k_prev}]
#
#   Neutral KCL at transformer star point:
#     cr_xf[wye,neutral] + Σ_k cr_xf[wye,ph_k] = 0
#
# ── delta_wye (Dy) ─────────────────────────────────────────────────────────
#   Symmetric to wye_delta with from↔to swapped; n_eff = N * √3.

"""
    _add_transformer_constraints!(model, net, vars, kcl_r, kcl_i)

Dispatch transformer constraints for all subtypes in the network:
- `single_phase` → `_add_yy_transformer!` (per-phase YY with Γ-model losses)
- `center_tap`   → `_add_center_tap_transformer!` (split-phase, coupled-coil primitive admittance)
- `wye_delta`    → `_add_yd_transformer!` with `wye_is_from=true`
- `delta_wye`    → `_add_yd_transformer!` with `wye_is_from=false`
"""
function _add_transformer_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=nothing)
    vr = vars[:vr]; vi = vars[:vi]
    cr_xf = vars[:cr_xf]; ci_xf = vars[:ci_xf]
    tapd  = get(vars, :tap, Dict{Any,Any}())
    xfmr_dict = get(net, "transformer", Dict())
    # Per-winding coil apparent-power auxiliaries (P, Q), registered by the
    # nameplate cap so the result writer can report the solved |S| without
    # reconstructing coil voltages. Keyed (tid, "fr"/"to", winding-index).
    s_coil = get!(vars, :s_coil_xf, Dict{Any,Any}())

    for (tid, xfmr) in get(xfmr_dict, "single_phase", Dict())
        _add_yy_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              tap=get(tapd, tid, nothing), branch_inj=branch_inj,
                              scoil=s_coil)
    end
    for (tid, xfmr) in get(xfmr_dict, "center_tap", Dict())
        _add_center_tap_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              tap=get(tapd, tid, nothing), branch_inj=branch_inj,
                              scoil=s_coil)
    end

    for (tid, xfmr) in get(xfmr_dict, "wye_delta", Dict())
        _add_yd_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              wye_is_from=true, tap=get(tapd, tid, nothing),
                              branch_inj=branch_inj, scoil=s_coil)
    end
    for (tid, xfmr) in get(xfmr_dict, "delta_wye", Dict())
        _add_yd_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              wye_is_from=false, tap=get(tapd, tid, nothing),
                              branch_inj=branch_inj, scoil=s_coil)
    end

    for (tid, xfmr) in get(xfmr_dict, "single_phase_autotransformer", Dict())
        _add_autotransformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              tap=get(tapd, tid, nothing), branch_inj=branch_inj,
                              scoil=s_coil)
    end
    for (tid, xfmr) in get(xfmr_dict, "open_delta_regulator", Dict())
        _add_open_delta_regulator!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              tap=tapd, branch_inj=branch_inj, scoil=s_coil)
    end
    # n_winding is built by a separate pass (`_add_nwinding_constraints!`). Any
    # OTHER key under `transformer` is an unmodeled subtype whose devices would
    # be silently absent from KCL — surface it loudly rather than drop it.
    known = Set(BMOPFTools.TRANSFORMER_SUBTYPES)
    recognized = join(BMOPFTools.TRANSFORMER_SUBTYPES, ", ")
    for (subtype, sub) in xfmr_dict
        (subtype in known || !(sub isa Dict) || isempty(sub)) && continue
        @warn "OPF: transformer subtype '$subtype' is not modeled — its " *
              "$(length(sub)) device(s) contribute NO constraints and are absent " *
              "from KCL. Recognized subtypes: $recognized."
    end
end

# Per-transformer KCL-add closure: records into the branch-loss ledger under
# ("transformer", tid) while forwarding to the shared accumulator. Each subtype
# builder binds `kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)` and uses it in
# place of `_kcl_add!(kcl_r, kcl_i, ...)` so every terminal injection (phases and
# neutral, both winding sides) is captured for the S_from+S_to loss identity.
_xf_kadd(kcl_r, kcl_i, branch_inj, tid) =
    (bus, terminal, cr, ci) -> _kcl_add!(kcl_r, kcl_i, bus, terminal, cr, ci;
                                         ledger=branch_inj, entry=("transformer", tid))

# ── YY (per-phase) ──────────────────────────────────────────────────────────

"""
    _add_yy_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i)

Add per-phase wye-wye (YY) transformer constraints using a Γ-equivalent model.

`cr_xf[(tid,"fr",k)]` / `ci_xf[(tid,"fr",k)]` are the **series** (ideal-core)
currents.  The TO-side terminal current is series + magnetising shunt:

  I_term_to = I_series_to + I_mag,   I_mag = (G + jB) · V_to_coil

where `G = g_no_load`, `B = b_no_load` are the total no-load admittance (S)
referred to the TO side (OpenDSS places the exciting branch on winding 2 —
verified against its Yprim), shared equally across the `n_c` per-phase pairs.

Series impedance (Ω), referred to the from side (Γ convention):

  R = r_series_from + N² · r_series_to
  X = x_series_from + N² · x_series_to

Voltage constraints (replaces ideal `V_fr = N·V_to`):

  vr_fr − N·vr_to = R·cr_series − X·ci_series
  vi_fr − N·vi_to = R·ci_series + X·cr_series

Current coupling (ideal core, unchanged):

  N·I_series_fr + I_to = 0

KCL contributions use the terminal current (series + shunt).
`i_max_from` limits the terminal current; `i_max_to` limits `I_to`.

When all loss parameters are absent or zero the model collapses to the
previous ideal transformer.

`r/x_neutral_from` / `r/x_neutral_to` (OpenDSS rneut/xneut) add an internal
neutral-grounding branch y_n = 1/(R_n+jX_n) from the side's shared neutral
terminal to earth (verified against OpenDSS Yprim — the neutral-node diagonal
gains exactly y_n).
"""
function _add_yy_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                              tap=nothing, branch_inj=nothing, scoil=nothing)
    kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)
    b_fr       = get(xfmr, "bus_from", "")
    b_to       = get(xfmr, "bus_to",   "")
    tmfr       = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tmto       = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    # Effective from→to ratio N. Fixed: N0·tap multiplier (default 1.0, so legacy
    # data is unchanged). Free: the tap variable (= N), warm-started at N0·tap.
    N0         = _xfmr_turns_ratio(xfmr)
    N          = tap === nothing ? N0 * BMOPFTools._xfmr_tap_mult(xfmr) : tap
    # Each winding spans a terminal pair (p, q): line-to-neutral when a neutral
    # terminal is present (q = neutral, shared by all phases), line-to-line for a
    # two-terminal map with no neutral (q = the other phase), or phase-to-ground
    # otherwise. The winding voltage and the no-load shunt are both taken across
    # (V_p − V_q), and the series/shunt return current closes at q.
    pairs_fr   = BMOPFTools._xfmr_winding_pairs(tmfr)
    pairs_to   = BMOPFTools._xfmr_winding_pairs(tmto)
    n_c        = min(length(pairs_fr), length(pairs_to))
    i_max_fr   = Float64.(get(xfmr, "i_max_from", Float64[]))
    i_max_to_v = Float64.(get(xfmr, "i_max_to",   Float64[]))
    # Per-phase share of the nameplate (VA, per-unitised upstream). n_c windings
    # carry the total 3-phase rating, so each coil is rated s_rating / n_c. The
    # nameplate is a required transformer field and is always enforced.
    s_rating   = Float64(get(xfmr, "s_rating", 0.0))
    s_per      = (s_rating > 0.0 && n_c > 0) ? s_rating / n_c : 0.0

    # Series impedance referred to the from side (Ω). Zero when absent.
    r_fr = Float64(get(xfmr, "r_series_from", 0.0))
    x_fr = Float64(get(xfmr, "x_series_from", 0.0))
    r_to = Float64(get(xfmr, "r_series_to",   0.0))
    x_to = Float64(get(xfmr, "x_series_to",   0.0))
    # To-side-referred leakage (constant). An OLTC changes the from-winding turns,
    # so the from-referred leakage scales with tap²; referred to the TO side it is
    # tap-independent: R' = r_to + r_fr/N0², X' = x_to + x_fr/N0². This matches the
    # OpenDSS turns-scaled Yprim and, combined with the coupling N·Is = −I_to, keeps
    # the voltage drop degree-2 in N (see the constraint below). At N = N0 it is
    # identical to the legacy R = r_fr + N0²·r_to form.
    invN0sq = N0 == 0.0 ? 0.0 : 1.0 / N0^2
    Rp = r_to + r_fr * invN0sq
    Xp = x_to + x_fr * invN0sq

    # No-load (magnetising) admittance (S), split equally per winding. OpenDSS
    # places the exciting branch across winding 2 (the TO coil), referred to
    # winding 2's coil voltage — verified against its Yprim. `g/b_no_load` are
    # therefore on the to-side base (`from_dss` derives them there).
    G_total = Float64(get(xfmr, "g_no_load", 0.0))
    B_total = Float64(get(xfmr, "b_no_load", 0.0))
    G = n_c > 0 ? G_total / n_c : 0.0
    B = n_c > 0 ? B_total / n_c : 0.0

    has_series = (r_fr != 0.0 || x_fr != 0.0 || r_to != 0.0 || x_to != 0.0)
    has_shunt  = (G != 0.0 || B != 0.0)

    # Winding neutral grounding impedance (OpenDSS rneut/xneut): a grounding
    # branch y_n = 1/(R_n + jX_n) from the side's shared neutral TERMINAL to
    # earth, INTERNAL to the transformer (verified against OpenDSS's Yprim: the
    # neutral-node diagonal gains exactly y_n). Stand-alone transformer
    # property — external groundings stay on buses/shunts. Applies only when
    # the side actually has a shared neutral terminal (L-N maps).
    rn_fr = Float64(get(xfmr, "r_neutral_from", 0.0))
    xn_fr = Float64(get(xfmr, "x_neutral_from", 0.0))
    rn_to = Float64(get(xfmr, "r_neutral_to",   0.0))
    xn_to = Float64(get(xfmr, "x_neutral_to",   0.0))
    n_pos_fr = BMOPFTools._neutral_pos(tmfr)
    n_pos_to = BMOPFTools._neutral_pos(tmto)
    for (side, rn, xn, n_pos) in (("from", rn_fr, xn_fr, n_pos_fr),
                                  ("to",   rn_to, xn_to, n_pos_to))
        b, tm = side == "from" ? (b_fr, tmfr) : (b_to, tmto)
        (rn != 0.0 || xn != 0.0) || continue
        if n_pos === nothing
            @warn "single_phase '$tid': r/x_neutral_$(side) set but the $(side) " *
                  "side has no shared neutral terminal; ignored."
            continue
        end
        zn2 = rn^2 + xn^2
        Gn  = rn / zn2; Bn = -xn / zn2      # y_n = 1/(R_n + jX_n)
        t_n = tm[n_pos]
        igr = @expression(model, Gn * vr[(b, t_n)] - Bn * vi[(b, t_n)])
        igi = @expression(model, Gn * vi[(b, t_n)] + Bn * vr[(b, t_n)])
        kadd(b, t_n, -igr, -igi)
    end

    # Winding voltage V_p − V_q (q absent → reference ground, i.e. V_p).
    _vpair(b, tp, tq) = tq === nothing ?
        (vr[(b, tp)], vi[(b, tp)]) :
        (@expression(model, vr[(b, tp)] - vr[(b, tq)]),
         @expression(model, vi[(b, tp)] - vi[(b, tq)]))

    for k in 1:n_c
        (p_fr, q_fr) = pairs_fr[k]
        (p_to, q_to) = pairs_to[k]
        t_p_fr = tmfr[p_fr]; t_q_fr = q_fr === nothing ? nothing : tmfr[q_fr]
        t_p_to = tmto[p_to]; t_q_to = q_to === nothing ? nothing : tmto[q_to]

        vr_fr, vi_fr = _vpair(b_fr, t_p_fr, t_q_fr)
        vr_to, vi_to = _vpair(b_to, t_p_to, t_q_to)
        Isr = cr_xf[(tid,"fr",k)]; Isi = ci_xf[(tid,"fr",k)]
        Itr = cr_xf[(tid,"to",k)]; Iti = ci_xf[(tid,"to",k)]

        # Voltage: (V_p_fr − V_q_fr) − N·(V_p_to − V_q_to) = Z·I_series. Using the
        # ideal coupling N·I_series = −I_to and the tap²-scaled (to-referred) leakage
        # R'/X', the drop collapses to −N·(R'·I_to ∓ X'·I_to): degree-2 in N, with the
        # cubic/tap² terms eliminated. At N = N0 this equals the legacy
        # R = r_fr + N0²·r_to stamping exactly.
        if has_series
            @constraint(model, vr_fr - N * vr_to == -N * (Rp * Itr - Xp * Iti))
            @constraint(model, vi_fr - N * vi_to == -N * (Rp * Iti + Xp * Itr))
        else
            @constraint(model, vr_fr == N * vr_to)
            @constraint(model, vi_fr == N * vi_to)
        end

        # Ideal-core current coupling: N·I_series_fr + I_to = 0
        @constraint(model, N * Isr + Itr == 0)
        @constraint(model, N * Isi + Iti == 0)

        # From-side terminal current = series only (the magnetising branch is on
        # the to side now). Inject −I at p and +I at q so the return closes at q.
        kadd(b_fr, t_p_fr, -Isr, -Isi)
        t_q_fr !== nothing && kadd(b_fr, t_q_fr, Isr, Isi)
        if length(i_max_fr) >= k
            @constraint(model, Isr^2 + Isi^2 <= i_max_fr[k]^2)
            _limit_current_box!(Isr, Isi, i_max_fr[k])
        end

        # Nameplate apparent-power cap on the from (winding-1) coil: the coil
        # voltage (phase-to-neutral / line-to-line) is never ≈0, so unlike a
        # ground-referenced conductor power this cap is well-posed. Per-phase
        # share of the total nameplate = s_rating / n_c.
        if s_per > 0.0
            _apparent_power_limit!(model, vr_fr, vi_fr, Isr, Isi, s_per;
                                   base_name = "$(tid)_w1_$(k)",
                                   ledger = scoil, key = (tid, "fr", k))
        end

        # To-side terminal current = series + magnetising shunt across the TO
        # coil (V_p_to − V_q_to). Inject −I at p and +I at q (return at q).
        if has_shunt
            icr_mag = @expression(model,  G * vr_to - B * vi_to)
            ici_mag = @expression(model,  G * vi_to + B * vr_to)
            icr_term = @expression(model, Itr + icr_mag)
            ici_term = @expression(model, Iti + ici_mag)
            kadd(b_to, t_p_to, -icr_term, -ici_term)
            t_q_to !== nothing && kadd(b_to, t_q_to, icr_term, ici_term)
            length(i_max_to_v) >= k &&
                @constraint(model, icr_term^2 + ici_term^2 <= i_max_to_v[k]^2)
        else
            kadd(b_to, t_p_to, -Itr, -Iti)
            t_q_to !== nothing && kadd(b_to, t_q_to, Itr, Iti)
            if length(i_max_to_v) >= k
                @constraint(model, Itr^2 + Iti^2 <= i_max_to_v[k]^2)
                _limit_current_box!(Itr, Iti, i_max_to_v[k])
            end
        end
    end
end

# ── Center-tap (split-phase) ────────────────────────────────────────────────

"""
    _add_center_tap_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i)

Add constraints for a center-tap (North American split-phase) transformer.

Terminal conventions (from the BMOPF spec arity (2,3)):
  from: `terminal_map_from = ["t_ph", "t_n"]`   — HV phase + neutral
  to:   `terminal_map_to   = ["t1",  "tn", "t2"]` — LV leg-1, center-tap, leg-2

Variable index mapping:
  `cr_xf[(tid,"fr",1)]` — HV series current (into phase terminal)
  `cr_xf[(tid,"to",1)]` — LV leg-1 current  (flows through winding-2 resistance)
  `cr_xf[(tid,"to",2)]` — LV center-tap current I_n (KCL balance at neutral)
  `cr_xf[(tid,"to",3)]` — LV leg-2 current  (flows through winding-3 resistance)

Physics (coupled-coil / primitive-admittance model):

  The split-phase transformer is a genuine 3-winding transformer — winding 1 is
  the HV coil (t_ph→t_n); windings 2 and 3 are the two LV half-windings, BOTH
  dotted at the centre tap (winding 2: t1→tn, winding 3: tn→t2). The two
  half-windings are tightly coupled on the shared core, so a per-leg decoupled
  voltage drop (which omits the mutual term) lets the legs spread apart under
  load. Instead we impose the OpenDSS-consistent 5×5 primitive admittance
  reconstructed from the symmetric star leakage arms:

    R1 = r_series_from, X1 = x_series_from  (HV winding star arm, HV side)
    R2 = r_series_to,   X2 = x_series_to    (each LV winding star arm, LV side)
    y1 = N²/(R1+jX1),  y2 = 1/(R2+jX2),  Y3 = star-reduce(y1, y2, y2)
    Yp = Cᵀ Y3 C  over nodes [t_ph, t_n, t1, tn, t2]

  with the connection matrix C mapping node voltages to winding voltages:
    winding 1: (V_t_ph − V_t_n)/N
    winding 2:  V_t1 − V_tn          (dotted at leg 1)
    winding 3:  V_tn − V_t2          (dotted at the centre tap)

  The `x_series_*` data must hold the STAR arms (not XHL/2). From an OpenDSS
  3-winding short-circuit set they are, for a symmetric centre tap (X2=X3):
    X1_star = (XHL + XHT − XLT)/2,  X2_star = (XHL + XLT − XHT)/2
  (`from_dss` reconstructs these from PowerIO's `pmd` export.) This Yp matches
  OpenDSS's transformer Yprim to machine precision (see `_yprim_center_tap`).

  The element current into each of the 5 nodes is I = Yp·V; the per-winding
  current variables are pinned to those injections so `i_max` limits and the
  result/loss writer see physical currents. The implied relations are the
  ampere-turn N·I_s + I_leg1 − I_leg2 = 0 and the centre-tap KCL
  I_n + I_leg1 + I_leg2 = 0.

  For an ideal core (zero series impedance) Yp is singular, so both legs are
  pinned directly to V_hv/N (winding 3 dotted at the centre tap) and the
  ampere-turn / centre-tap KCL route the currents.

  No-load shunt (G+jB) at HV terminals (placed on winding-1 from side).

  Winding neutral grounding (OpenDSS rneut/xneut): `r/x_neutral_from` grounds the HV
  neutral through y_n = 1/(R_n+jX_n); `r/x_neutral_to` grounds the LV centre-tap
  neutral. Accepted for OpenDSS compatibility (a future data-cleanup pass should
  reify it as an explicit external shunt).
"""
function _add_center_tap_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                                      tap=nothing, branch_inj=nothing, scoil=nothing)
    kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)
    b_fr       = get(xfmr, "bus_from", "")
    b_to       = get(xfmr, "bus_to",   "")
    tmfr       = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tmto       = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    # Effective HV→LV-leg ratio N. Fixed: N0·tap multiplier (default 1.0, so legacy
    # data is unchanged). Free: the tap variable IS N (= N0·tap), warm-started at N0.
    N0         = _xfmr_turns_ratio(xfmr)
    N          = tap === nothing ? N0 * BMOPFTools._xfmr_tap_mult(xfmr) : tap
    i_max_fr   = Float64.(get(xfmr, "i_max_from", Float64[]))
    i_max_to_v = Float64.(get(xfmr, "i_max_to",   Float64[]))
    # Split-phase: the single HV coil carries the whole nameplate (VA, p.u.).
    s_per      = Float64(get(xfmr, "s_rating", 0.0))

    # Require exactly 2 HV and 3 LV terminals.
    length(tmfr) == 2 && length(tmto) == 3 || begin
        @warn "center_tap '$tid': expected terminal_map_from length 2 and " *
              "terminal_map_to length 3; got $(length(tmfr)) and $(length(tmto)). Skipping."
        return
    end

    t_fr_ph = tmfr[1]; t_fr_n  = tmfr[2]   # HV phase, HV neutral
    t_lv_1  = tmto[1]; t_lv_n  = tmto[2]; t_lv_2 = tmto[3]  # leg-1, center-tap, leg-2

    # Winding impedances in their own-side units (Ω).
    # r_series_from / x_series_from  — HV winding (Ω, HV-side)
    # r_series_to   / x_series_to    — each LV winding (Ω, LV-side); both legs same rating
    R1 = Float64(get(xfmr, "r_series_from", 0.0))
    X1 = Float64(get(xfmr, "x_series_from", 0.0))
    R2 = Float64(get(xfmr, "r_series_to",   0.0))
    X2 = Float64(get(xfmr, "x_series_to",   0.0))
    # The analytical Yprim path needs BOTH star arms finite: a zero arm makes
    # the coupling partly ideal (y = 1/Z → ∞) and the star reduction would
    # produce NaN. A zero arm is legitimate data (e.g. XHT = XHL + XLT gives an
    # exactly-zero LV arm), so any-zero-arm cases take the T-model branch below,
    # which is linear in the impedances and exact for zero arms.
    arm1 = (R1 != 0.0 || X1 != 0.0)
    arm2 = (R2 != 0.0 || X2 != 0.0)

    # No-load admittance at HV terminals.
    G = Float64(get(xfmr, "g_no_load", 0.0))
    B = Float64(get(xfmr, "b_no_load", 0.0))
    has_shunt = (G != 0.0 || B != 0.0)

    # HV series current: index 1 on the "fr" side.
    Isr = cr_xf[(tid,"fr",1)];  Isi = ci_xf[(tid,"fr",1)]
    # LV currents: leg-1 = index 1, center-tap = index 2, leg-2 = index 3.
    Il1r = cr_xf[(tid,"to",1)]; Il1i = ci_xf[(tid,"to",1)]
    Il2r = cr_xf[(tid,"to",3)]; Il2i = ci_xf[(tid,"to",3)]
    Inr  = cr_xf[(tid,"to",2)]; Ini  = ci_xf[(tid,"to",2)]

    # ── Winding neutral grounding (OpenDSS rneut/xneut) ───────────────────────
    # An internal grounding branch y_n = 1/(R_n + jX_n) from a shared neutral
    # terminal to earth (verified against OpenDSS's Yprim; matches the single_phase
    # and Yd/Dy builders). `r/x_neutral_from` grounds the HV neutral t_fr_n;
    # `r/x_neutral_to` grounds the LV centre-tap neutral t_lv_n. Added before the
    # winding-model branch below so it applies to BOTH the fixed Yprim and the
    # free-tap T-model paths (the current sums additively into the same KCL node).
    #
    # NOTE: this is accepted for compatibility with OpenDSS-sourced data; a future
    # data-cleanup pass should express it as an explicit external `shunt` object so
    # the transformer zoo stays simpler (see the data-cleanup notes).
    for (rn_key, xn_key, b_nt, t_nt) in
            (("r_neutral_from", "x_neutral_from", b_fr, t_fr_n),
             ("r_neutral_to",   "x_neutral_to",   b_to, t_lv_n))
        rn = Float64(get(xfmr, rn_key, 0.0)); xn = Float64(get(xfmr, xn_key, 0.0))
        (rn != 0.0 || xn != 0.0) || continue
        zn2 = rn^2 + xn^2
        Gn  = rn / zn2; Bn = -xn / zn2      # y_n = 1/(R_n + jX_n) = G_n + jB_n
        igr = @expression(model, Gn * vr[(b_nt, t_nt)] - Bn * vi[(b_nt, t_nt)])
        igi = @expression(model, Gn * vi[(b_nt, t_nt)] + Bn * vr[(b_nt, t_nt)])
        kadd(b_nt, t_nt, -igr, -igi)        # grounding current leaves the node to earth
    end

    # ── Coupled-coil (primitive-admittance) formulation ───────────────────────
    # The split-phase transformer is a genuine 3-winding transformer: winding 1
    # is the HV coil (t_fr_ph→t_fr_n); windings 2 and 3 are the two LV
    # half-windings, BOTH dotted at the centre tap (winding 2: t_lv_1→t_lv_n,
    # winding 3: t_lv_n→t_lv_2). Reconstructing the OpenDSS-consistent 5×5
    # primitive admittance from the star leakage arms captures the mutual
    # coupling between the two half-windings — which a per-leg decoupled voltage
    # drop omits, causing the legs to spread apart under load. This Yprim matches
    # OpenDSS's transformer Yprim to machine precision (see `_yprim_center_tap`).
    #
    # CRITICAL: winding 3 is dotted at the centre tap, so its voltage is
    # V(t_lv_n) − V(t_lv_2) (NOT V(t_lv_2) − V(t_lv_n)). The opposite sign makes
    # the two LV legs identical instead of series-aiding, the original bug.
    #
    # This analytical Yprim folds N into y1 = N²/Z1 and C = ±1/N, so it is only
    # used when the ratio is a FIXED number. A free tap (variable N) takes the
    # degree-2 T-model branch below, which is algebraically identical at N = N0
    # (derived from this same Yprim) but linear-in-leakage so the products stay
    # quadratic for Ipopt. It also requires both star arms nonzero (see arm1/arm2
    # above); a zero arm previously produced y = Inf and NaN-poisoned the stamp.
    if arm1 && arm2 && tap === nothing
        Z1 = R1 + im * X1            # HV star arm  (HV side, Ω/pu)
        Z2 = R2 + im * X2            # each LV star arm (LV side, Ω/pu)
        y1 = N^2 / Z1
        y2 = 1.0 / Z2
        Ys = y1 + 2 * y2
        yv = (y1, y2, y2)
        # 3×3 star-equivalent winding admittance (windings [HV, LV1, LV2]).
        Y3 = Matrix{ComplexF64}(undef, 3, 3)
        for a in 1:3, c in 1:3
            Y3[a, c] = a == c ? yv[a] * (Ys - yv[a]) / Ys : -yv[a] * yv[c] / Ys
        end
        # Connection matrix C (3×5) over nodes
        #   [t_fr_ph, t_fr_n, t_lv_1, t_lv_n, t_lv_2]:
        #   winding 1: (V_frph − V_frn)/N ; winding 2: V_lv1 − V_lvn ;
        #   winding 3: V_lvn − V_lv2  (dotted at the centre tap).
        C = zeros(ComplexF64, 3, 5)
        C[1, 1] =  1.0 / N; C[1, 2] = -1.0 / N
        C[2, 3] =  1.0;     C[2, 4] = -1.0
        C[3, 4] =  1.0;     C[3, 5] = -1.0
        Yp = transpose(C) * Y3 * C
        # No-load shunt across winding 2 = LV leg 1 (nodes 3-4, the t1-tn coil).
        # OpenDSS places the ENTIRE exciting branch on winding 2 at the per-leg
        # voltage — not on the HV node (verified against its Yprim).
        Y0 = G + im * B
        Yp[3, 3] += Y0; Yp[4, 4] += Y0; Yp[3, 4] -= Y0; Yp[4, 3] -= Y0

        node_bt = ((b_fr, t_fr_ph), (b_fr, t_fr_n),
                   (b_to, t_lv_1),  (b_to, t_lv_n), (b_to, t_lv_2))
        # Element current INTO node m: I_m = Σ_k Yp[m,k]·V_k.
        function inj(m)
            er = JuMP.AffExpr(0.0); ei = JuMP.AffExpr(0.0)
            for k in 1:5
                (bk, tk) = node_bt[k]
                g = real(Yp[m, k]); bb = imag(Yp[m, k])
                JuMP.add_to_expression!(er,  g, vr[(bk, tk)])
                JuMP.add_to_expression!(er, -bb, vi[(bk, tk)])
                JuMP.add_to_expression!(ei,  g, vi[(bk, tk)])
                JuMP.add_to_expression!(ei,  bb, vr[(bk, tk)])
            end
            er, ei
        end
        # Pin the per-winding current variables to the nodal injections so the
        # result writer and i_max limits see physical winding currents.
        I2r = cr_xf[(tid,"fr",2)]; I2i = ci_xf[(tid,"fr",2)]
        e1r,e1i = inj(1); e2r,e2i = inj(2); e3r,e3i = inj(3); e4r,e4i = inj(4); e5r,e5i = inj(5)
        @constraint(model, Isr  == e1r); @constraint(model, Isi  == e1i)
        @constraint(model, I2r  == e2r); @constraint(model, I2i  == e2i)
        @constraint(model, Il1r == e3r); @constraint(model, Il1i == e3i)
        @constraint(model, Inr  == e4r); @constraint(model, Ini  == e4i)
        @constraint(model, Il2r == e5r); @constraint(model, Il2i == e5i)
        # KCL: inject −I_m into each bus terminal.
        kadd(b_fr, t_fr_ph, -Isr, -Isi)
        kadd(b_fr, t_fr_n,  -I2r, -I2i)
        kadd(b_to, t_lv_1,  -Il1r, -Il1i)
        kadd(b_to, t_lv_n,  -Inr,  -Ini)
        kadd(b_to, t_lv_2,  -Il2r, -Il2i)
        # Current-magnitude limits on the pinned winding-current variables.
        length(i_max_fr)   >= 1 && @constraint(model, Isr^2  + Isi^2  <= i_max_fr[1]^2)
        length(i_max_to_v) >= 1 && @constraint(model, Il1r^2 + Il1i^2 <= i_max_to_v[1]^2)
        length(i_max_to_v) >= 2 && @constraint(model, Inr^2  + Ini^2  <= i_max_to_v[2]^2)
        length(i_max_to_v) >= 3 && @constraint(model, Il2r^2 + Il2i^2 <= i_max_to_v[3]^2)
        # Nameplate cap on the HV coil (V_frph − V_frn) · conj(I_s).
        if s_per > 0.0
            _apparent_power_limit!(model,
                @expression(model, vr[(b_fr,t_fr_ph)] - vr[(b_fr,t_fr_n)]),
                @expression(model, vi[(b_fr,t_fr_ph)] - vi[(b_fr,t_fr_n)]),
                Isr, Isi, s_per; base_name = "$(tid)_hv",
                ledger = scoil, key = (tid, "fr", 1))
        end
        return
    end

    # ── T-model core (free tap, or a zero series star arm) ────────────────────
    # Degree-2 voltage drop derived from the SAME coupled-coil Yprim as the fixed
    # path above: with the HV core EMF E = V_hv − Z1·Is and the star node V* = E/N,
    #   leg1:  V_hv − N·v1 = Z1·Is − N·Z2·Il1
    #   leg2:  V_hv − N·v2 = Z1·Is + N·Z2·Il2   (winding 3 reversed at the centre tap)
    # where v1 = V_t1 − V_tn, v2 = V_tn − V_t2, Z1 = R1+jX1 (HV Ω, HV winding) and
    # Z2 = R2+jX2 (each LV leg, LV Ω). The shared Z1·Is term carries the
    # half-winding mutual coupling that the 5×5 Yprim captured. At Z = 0 this
    # collapses to the ideal V_hv = N·v1 = N·v2; at N = N0 it reproduces the fixed
    # Yprim exactly. The only nonlinear terms are the bilinear N·v and N·Z2·Il
    # products, so the constraint set stays quadratic when N is a free tap.
    vr_hv = @expression(model, vr[(b_fr, t_fr_ph)] - vr[(b_fr, t_fr_n)])
    vi_hv = @expression(model, vi[(b_fr, t_fr_ph)] - vi[(b_fr, t_fr_n)])
    vr_l1 = @expression(model, vr[(b_to, t_lv_1)] - vr[(b_to, t_lv_n)])
    vi_l1 = @expression(model, vi[(b_to, t_lv_1)] - vi[(b_to, t_lv_n)])
    vr_l2 = @expression(model, vr[(b_to, t_lv_n)] - vr[(b_to, t_lv_2)])
    vi_l2 = @expression(model, vi[(b_to, t_lv_n)] - vi[(b_to, t_lv_2)])
    z1r_Is = @expression(model, R1 * Isr - X1 * Isi)   # Re(Z1·Is)
    z1i_Is = @expression(model, R1 * Isi + X1 * Isr)   # Im(Z1·Is)
    @constraint(model, vr_hv - N * vr_l1 == z1r_Is - N * (R2 * Il1r - X2 * Il1i))
    @constraint(model, vi_hv - N * vi_l1 == z1i_Is - N * (R2 * Il1i + X2 * Il1r))
    @constraint(model, vr_hv - N * vr_l2 == z1r_Is + N * (R2 * Il2r - X2 * Il2i))
    @constraint(model, vi_hv - N * vi_l2 == z1i_Is + N * (R2 * Il2i + X2 * Il2r))

    # ── Current coupling (power conservation) ────────────────────────────────
    # Power balance at ideal core: V_hv·conj(I_s) + (V_leg1·conj(−Il1) + V_leg2·conj(−Il2)) = 0
    # The ideal-core coupling for a 3-winding T with both secondaries in the same
    # polarity convention (current into terminal = positive) is: N·I_s = Il1 + Il2
    # i.e. N·I_s − Il1 − Il2 = 0 (primary delivers, secondaries receive)
    # BUT: in the BMOPF variable convention, I_s is defined flowing INTO hv.1
    # (into the transformer), while Il1 and Il2 flow INTO lv.1 and lv.2
    # (also into the transformer from their respective buses).
    # Power balance: V_hv·I_s* = V_leg1·Il1* + V_leg2·Il2*  (complex power into primary = sum out)
    # Actually all currents are INTO the transformer, so power conservation:
    # V_hv·I_s* + V_leg1·Il1* + V_leg2·Il2* = 0  (three ports, all into element)
    # With V_hv/N = V_leg1 (ideal, no losses) and winding-3 wound in REVERSE
    # (its leg-2 voltage equation uses V_to[tn] − V_to[t2]), power conservation
    # requires the leg-2 current to enter the coupling with a MINUS sign:
    #   N·I_s + Il1 − Il2 = 0
    # Using +Il2 instead violates the ideal-core power balance by 2·Re[(V_hv/N)·conj(Il2)]
    # — a spurious source/sink proportional to the leg-2 current (latent on stiff
    # short test feeders, first-order on long high-impedance SWER lines).
    @constraint(model, N * Isr + Il1r - Il2r == 0)
    @constraint(model, N * Isi + Il1i - Il2i == 0)

    # ── Center-tap KCL: I_n balances the two leg currents at the center-tap ──
    # At lv.n: current entering = I_n (from wdg neutral tap) − Il1 (leaving to leg-1 bus)
    #   + Il2 (entering from leg-2 bus, since leg-2 draws from neutral).
    # Wait — both Il1 and Il2 are currents INTO the transformer FROM their buses.
    # Il1 leaves bus lv.1 → it's extracted from bus (negative KCL contribution to bus).
    # Il2 leaves bus lv.2 → it's extracted from bus (negative KCL contribution to bus).
    # At the center-tap node (lv.n): current in from lv.n bus = I_n (also leaves bus lv.n).
    # Center-tap node internal: the winding junction sees Il1 + I_n − Il2 = 0
    # (Il1 flows into the t1→tn winding at the tn end, I_n into the neutral terminal,
    #  and Il2 flows out of the tn→t2 winding at the tn end)
    # Actually: at tn node: current from wdg2's tn-end (= Il1 arrives here after flowing from t1)
    # + current from wdg3's tn-end (= Il2 arrives here going toward t2)
    # + I_n (from bus) = 0 at ideal no-leakage node
    # In our BMOPF variables, Inr = cr_xf[(tid,"to",2)] = current extracted from bus lv.n.
    # KCL at internal tn node: Il1 + Inr + Il2 = 0  (all flowing through the winding, sign from bus into element)
    # This matches the power coupling: if coupling is N·Is + Il1 + Il2 = 0,
    # then the center-tap sees the sum Il1 + Il2 = −N·Is, and I_n = −Il1 − Il2 = N·Is.
    # The neutral carries the leg UNBALANCE (Il1 + Il2), which is small for a
    # balanced split-phase load — so this KCL keeps the "+Il2" sum (unlike the
    # current-coupling above, which needs −Il2 for the reversed winding's MMF).
    @constraint(model, Inr + Il1r + Il2r == 0)
    @constraint(model, Ini + Il1i + Il2i == 0)

    # ── Pin the HV neutral winding-current variable (fr,2) ────────────────────
    # The HV coil is phase-to-neutral, so the series current returns entirely
    # through the neutral: I_neutral = −I_s. The fixed Yprim path pins this via
    # the nodal injection; the T-model path pins it explicitly so the result
    # writer and loss accounting (which read the fr,2 variable) see the physical
    # neutral current.
    I2r = cr_xf[(tid,"fr",2)]; I2i = ci_xf[(tid,"fr",2)]
    @constraint(model, I2r == -Isr)
    @constraint(model, I2i == -Isi)

    # ── HV side KCL (pure series current; the exciting branch is on winding 2) ──
    kadd(b_fr, t_fr_ph, -Isr, -Isi)
    if length(i_max_fr) >= 1
        @constraint(model, Isr^2 + Isi^2 <= i_max_fr[1]^2)
        _limit_current_box!(Isr, Isi, i_max_fr[1])  # bare HV series-current variable
    end
    # Nameplate cap on the HV coil (vr_hv = V_frph − V_frn, computed above).
    if s_per > 0.0
        _apparent_power_limit!(model, vr_hv, vi_hv, Isr, Isi, s_per;
                               base_name = "$(tid)_hv",
                               ledger = scoil, key = (tid, "fr", 1))
    end
    kadd(b_fr, t_fr_n, Isr, Isi)   # HV neutral: series return

    # ── LV side KCL contributions ─────────────────────────────────────────────
    # The no-load (magnetising) branch sits across winding 2 = LV leg 1
    # (V_lv1 − V_lvn), the entire Y0 at the per-leg voltage — OpenDSS places the
    # exciting branch on winding 2 (verified against its Yprim). Injected −I_mag
    # at t_lv_1 and +I_mag at t_lv_n on top of the winding currents.
    if has_shunt
        vr_leg1 = @expression(model, vr[(b_to, t_lv_1)] - vr[(b_to, t_lv_n)])
        vi_leg1 = @expression(model, vi[(b_to, t_lv_1)] - vi[(b_to, t_lv_n)])
        imr = @expression(model, G * vr_leg1 - B * vi_leg1)
        imi = @expression(model, G * vi_leg1 + B * vr_leg1)
        il1r_t = @expression(model, Il1r + imr); il1i_t = @expression(model, Il1i + imi)
        kadd(b_to, t_lv_1, -il1r_t, -il1i_t)
        kadd(b_to, t_lv_n, -Inr + imr, -Ini + imi)
    else
        kadd(b_to, t_lv_1, -Il1r, -Il1i)
        kadd(b_to, t_lv_n, -Inr,  -Ini)
    end
    kadd(b_to, t_lv_2, -Il2r, -Il2i)

    # ── Current magnitude limits (Il1/In/Il2 are bare LV winding-current
    #    variables, so the limit also tightens each component's box bound) ───────
    if length(i_max_to_v) >= 1
        @constraint(model, Il1r^2 + Il1i^2 <= i_max_to_v[1]^2)
        _limit_current_box!(Il1r, Il1i, i_max_to_v[1])
    end
    if length(i_max_to_v) >= 2
        @constraint(model, Inr^2 + Ini^2 <= i_max_to_v[2]^2)
        _limit_current_box!(Inr, Ini, i_max_to_v[2])
    end
    if length(i_max_to_v) >= 3
        @constraint(model, Il2r^2 + Il2i^2 <= i_max_to_v[3]^2)
        _limit_current_box!(Il2r, Il2i, i_max_to_v[3])
    end
end

# ── YD / DY ─────────────────────────────────────────────────────────────────

"""
    _add_yd_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i; wye_is_from)

Add wye-delta (Yd) or delta-wye (Dy) transformer constraints.

`wye_is_from=true`  → wye side is `bus_from` (Yd: wye is HV primary).
`wye_is_from=false` → wye side is `bus_to`   (Dy: delta is HV primary).

The effective per-winding turns ratio accounts for the √3 factor introduced by the
delta connection geometry (phase-to-neutral `v_nom` on both sides as convention):
```
  n_eff = √3 / N   (Yd, wye is HV,    N = V_wye_ref / V_del_ref)
  n_eff = N · √3   (Dy, delta is HV,  N = V_del_ref / V_wye_ref)
```

Voltage constraints (k = 1..n_ph, k_next = (k % n_ph) + 1):
```
  vr_del[k] − vr_del[k_next] = n_eff · (vr_wye_ph[k] − vr_wye_neutral)
```

Current constraints (T^T of voltage transform, power-conservative):
```
  n_eff · cr_xf[del,k] = cr_xf[wye, ph_k] − cr_xf[wye, ph_{k_prev}]
```

Neutral KCL at the transformer star point:
```
  cr_xf[wye,neutral] + Σ_k cr_xf[wye,ph_k] = 0
```

Loss model (per-winding T behind the ideal transform — matches OpenDSS / PMD):
  - `r/x_series_from` → series impedance on the from-side winding branch
  - `r/x_series_to`   → series impedance on the to-side winding branch
  - `g/b_no_load`     → magnetising shunt across the winding-2 (to-side) coils
    (delta of branches for a delta winding 2, phase-to-neutral for a wye
    winding 2) — OpenDSS places the exciting branch on winding 2
  - `r/x_neutral_*` (wye side) → internal neutral-grounding branch
    y_n = 1/(R_n+jX_n) from the wye neutral terminal to earth (OpenDSS
    rneut/xneut; verified against OpenDSS Yprim)

The series drop enters the voltage constraint; with all impedance fields zero
the model collapses to the previous ideal transform.  A legacy single
`r_series`/`x_series` is read by the converter/migration as `*_series_from`
(wye side) with the to-side branch zero.
"""
function _add_yd_transformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                               wye_is_from::Bool, tap=nothing, branch_inj=nothing,
                               scoil=nothing)
    kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)
    N = _xfmr_turns_ratio(xfmr)   # v_nom_from / v_nom_to
    i_max_fr   = Float64.(get(xfmr, "i_max_from", Float64[]))
    i_max_to_v = Float64.(get(xfmr, "i_max_to",   Float64[]))
    s_rating   = Float64(get(xfmr, "s_rating", 0.0))

    if wye_is_from
        b_wye    = get(xfmr, "bus_from", "")
        b_del    = get(xfmr, "bus_to",   "")
        tm_wye   = Vector{String}(get(xfmr, "terminal_map_from", String[]))
        tm_del   = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
        side_wye = "fr"; side_del = "to"
    else
        b_del    = get(xfmr, "bus_from", "")
        b_wye    = get(xfmr, "bus_to",   "")
        tm_del   = Vector{String}(get(xfmr, "terminal_map_from", String[]))
        tm_wye   = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
        side_del = "fr"; side_wye = "to"
    end

    # Effective from→to ratio n_eff. Fixed: from N0·tap multiplier (default 1.0, so
    # legacy data is unchanged). Free: the tap variable IS n_eff (= N·√3 for Dy,
    # √3/N for Yd), warm-started at nominal. `inv_neff` carries the 1/n_eff factor of
    # the delta-arm referral: a Float64 when fixed, else an auxiliary variable pinned
    # by n_eff·inv_neff = 1 so the rows stay degree-2 (no rational term).
    if tap === nothing
        N     = _xfmr_turns_ratio(xfmr) * BMOPFTools._xfmr_tap_mult(xfmr)
        n_eff = wye_is_from ? sqrt(3) / N : N * sqrt(3)
        inv_neff = 1.0 / n_eff
    else
        n_eff = tap
        lo = JuMP.lower_bound(tap); hi = JuMP.upper_bound(tap)
        inv_neff = @variable(model, base_name = "inv_neff_$(tid)",
                             lower_bound = 1.0 / hi, upper_bound = 1.0 / lo)
        s0 = JuMP.start_value(tap)
        s0 === nothing || JuMP.set_start_value(inv_neff, 1.0 / s0)
        @constraint(model, n_eff * inv_neff == 1)
    end

    n_ph  = length(tm_del)             # number of delta (phase) conductors
    n_wye = length(tm_wye)

    n_pos  = _neutral_pos(tm_wye)       # position of neutral in tm_wye (or nothing)
    ph_idx = _phase_positions(tm_wye)   # positions of phase conductors in tm_wye

    length(ph_idx) < n_ph && @warn "Transformer '$tid': wye-side phase count < delta conductors."

    # Series impedance per winding (Ω). r/x_series_from is the from-side winding,
    # r/x_series_to the to-side winding. Map to wye/delta branches by side.
    r_fr = Float64(get(xfmr, "r_series_from", 0.0))
    x_fr = Float64(get(xfmr, "x_series_from", 0.0))
    r_to = Float64(get(xfmr, "r_series_to",   0.0))
    x_to = Float64(get(xfmr, "x_series_to",   0.0))
    if wye_is_from
        Rw, Xw = r_fr, x_fr   # wye branch = from
        Rd, Xd = r_to, x_to   # delta branch = to
    else
        Rd, Xd = r_fr, x_fr   # delta branch = from
        Rw, Xw = r_to, x_to   # wye branch = to
    end
    has_series = (Rw != 0.0 || Xw != 0.0 || Rd != 0.0 || Xd != 0.0)

    # Winding neutral grounding impedance (OpenDSS rneut/xneut): a grounding
    # branch y_n = 1/(R_n + jX_n) from the wye winding's neutral TERMINAL to
    # earth, INTERNAL to the transformer (verified against OpenDSS's Yprim:
    # the neutral-node diagonal gains exactly y_n; the star point itself stays
    # solidly on the neutral node). Stand-alone transformer property — external
    # groundings stay on buses/shunts. The delta side has no neutral; its
    # fields are ignored (warned).
    rn_key_w = wye_is_from ? "r_neutral_from" : "r_neutral_to"
    xn_key_w = wye_is_from ? "x_neutral_from" : "x_neutral_to"
    rn_key_d = wye_is_from ? "r_neutral_to"   : "r_neutral_from"
    xn_key_d = wye_is_from ? "x_neutral_to"   : "x_neutral_from"
    Rn = Float64(get(xfmr, rn_key_w, 0.0))
    Xn = Float64(get(xfmr, xn_key_w, 0.0))
    if get(xfmr, rn_key_d, 0.0) != 0.0 || get(xfmr, xn_key_d, 0.0) != 0.0
        @warn "Transformer '$tid': $(rn_key_d)/$(xn_key_d) set on the DELTA side, " *
              "which has no neutral; ignored."
    end
    has_zn = (Rn != 0.0 || Xn != 0.0)
    if has_zn && n_pos === nothing
        @warn "Transformer '$tid': $(rn_key_w)/$(xn_key_w) set but the wye side " *
              "has no neutral terminal; ignored."
        has_zn = false
    end
    zn2 = Rn^2 + Xn^2
    Gn  = has_zn ? Rn / zn2 : 0.0     # y_n = 1/(R_n + jX_n) = G_n + jB_n
    Bn  = has_zn ? -Xn / zn2 : 0.0

    # Voltage constraints.
    # For Yd (wye_is_from=true):  V_del[k] - V_del[k_next] = n_eff*(V_wye[k] - V_n)
    # For Dy (wye_is_from=false): V_del[k] - V_del[k_prev] = n_eff*(V_wye[k] - V_n)
    # The Dy direction matches the ODS backward-delta convention.
    #
    # Per-winding T: subtract the series drop across the wye coil (winding
    # current I_wye,k) and the delta coil k (arm current I_arm,k):
    #   ΔV_del = n_eff·ΔV_wye − n_eff·(Rw+jXw)·I_wye,k − (Rd_coil+jXd_coil)·I_arm,k
    #
    # Both drops are driven by the WYE phase current I_wye,k.  The delta-arm
    # current is the magnetising image of the wye winding current:
    #   I_arm,k = (1/n_eff)·I_wye,k    (amp-turn balance; verified numerically to
    #   match the OpenDSS terminal-Y oracle to 3 d.p. on the unbalanced fixture).
    # NB: the delta CURRENT variable cr_xf[del,k] is the delta LINE current
    # (= I_arm,k − I_arm,k_other, set by the current-coupling constraint below and
    # injected at the delta node by KCL) — NOT the arm current, so it must NOT be
    # used for the coil voltage drop.  Using the line current here was the cause
    # of the historical mis-referral (wrong-direction sensitivity, negative
    # transformer losses).
    #
    # Delta-coil impedance base (matches OpenDSS Transformer.pas exactly).
    # OpenDSS builds Y_term[i,j] = Y_1volt[i,j]/(VBase_i·VBase_j) with the
    # per-winding VBase line-to-NEUTRAL for a wye winding (kVLL/√3) but the full
    # line-to-LINE coil voltage (kVLL) for a delta winding — the √3 lives
    # entirely in VBase_delta.  Our `r/x_series_to` (delta side) arrive referred
    # to the delta BUS line-to-neutral base, which is 1/n_ph of the delta-COIL
    # (line-to-line) base, so Zd_coil = n_ph·(Rd+jXd).
    #
    # EXACT tap scaling (verified against OpenDSS's short-circuit Yprim). OpenDSS
    # scales winding 1's self-impedance by tap², so the short-circuit impedance
    # referred to the TAPPED (winding-1 / from) side scales as tap² while the
    # NON-tapped (to) side referral is held at nominal. Expressing the drop on
    # the wye phase current as Reff·I_wye (delta-side voltage), Reff = n_eff·Z_sc
    # with Z_sc the wye-referred short-circuit impedance:
    #   Z_sc_nom = Zw + (n_ph/n_eff0²)·Zd          (nominal, tap-independent)
    #   Yd (wye = from, tapped) : Z_sc = (n_eff0/n_eff)²·Z_sc_nom  ⇒ ∝ tap²
    #     Reff = n_eff·Z_sc = inv_neff·(n_eff0²·Zw + n_ph·Zd)
    #   Dy (delta = from, tapped): Z_sc = Z_sc_nom (constant on the non-tapped wye)
    #     Reff = n_eff·Z_sc = n_eff·(Zw + (n_ph/n_eff0²)·Zd)
    # At n_eff = n_eff0 both reduce to the legacy n_eff·Zw + (n_ph/n_eff)·Zd.
    # `n_eff0` is the NOMINAL effective ratio (before the tap). Both coefficients
    # are degree-1 in {n_eff, inv_neff}, so the drop stays quadratic for a free tap.
    N0     = _xfmr_turns_ratio(xfmr)
    n_eff0 = wye_is_from ? sqrt(3) / N0 : N0 * sqrt(3)
    if wye_is_from      # Yd: the wye (from) winding is tapped
        Rw_coef = n_eff0^2 * inv_neff
        Rd_coef = n_ph * inv_neff
    else                # Dy: the delta (from) winding is tapped
        Rw_coef = n_eff
        Rd_coef = (n_ph / n_eff0^2) * n_eff
    end
    for k in 1:n_ph
        t_del_k   = tm_del[k]
        ph_pos    = ph_idx[k]
        t_wye_ph  = tm_wye[ph_pos]
        if wye_is_from
            k_other = (k % n_ph) + 1          # k_next for Yd
        else
            k_other = ((k - 2 + n_ph) % n_ph) + 1  # k_prev for Dy
        end
        t_del_other = tm_del[k_other]

        # Wye phase-to-neutral voltage (neutral implicitly zero if absent)
        if n_pos !== nothing
            t_wye_n = tm_wye[n_pos]
            vr_wye_pn = vr[(b_wye, t_wye_ph)] - vr[(b_wye, t_wye_n)]
            vi_wye_pn = vi[(b_wye, t_wye_ph)] - vi[(b_wye, t_wye_n)]
        else
            vr_wye_pn = vr[(b_wye, t_wye_ph)]
            vi_wye_pn = vi[(b_wye, t_wye_ph)]
        end

        if has_series
            Iwr = cr_xf[(tid, side_wye, ph_pos)]; Iwi = ci_xf[(tid, side_wye, ph_pos)]
            # Delta-side voltage drop on the wye phase current, with the exact
            # tap² referral (Rw_coef/Rd_coef derived above).
            Reff = Rw_coef * Rw + Rd_coef * Rd
            Xeff = Rw_coef * Xw + Rd_coef * Xd
            @constraint(model,
                vr[(b_del, t_del_k)] - vr[(b_del, t_del_other)] ==
                n_eff * vr_wye_pn
                - (Reff * Iwr - Xeff * Iwi))
            @constraint(model,
                vi[(b_del, t_del_k)] - vi[(b_del, t_del_other)] ==
                n_eff * vi_wye_pn
                - (Reff * Iwi + Xeff * Iwr))
        else
            @constraint(model,
                vr[(b_del, t_del_k)] - vr[(b_del, t_del_other)] == n_eff * vr_wye_pn)
            @constraint(model,
                vi[(b_del, t_del_k)] - vi[(b_del, t_del_other)] == n_eff * vi_wye_pn)
        end

        # Nameplate cap on the wye (phase-to-neutral) coil: S = V_wye,pn · conj(I_wye).
        # Per-phase share = s_rating / n_ph.
        if s_rating > 0.0 && n_ph > 0
            _apparent_power_limit!(model, vr_wye_pn, vi_wye_pn,
                cr_xf[(tid, side_wye, ph_pos)], ci_xf[(tid, side_wye, ph_pos)],
                s_rating / n_ph; base_name = "$(tid)_wye_$(k)",
                ledger = scoil, key = (tid, side_wye, ph_pos))
        end
    end

    # Current constraints (transpose of voltage transformation):
    # For Yd (wye_is_from=true):  n_eff*I_del[k] = I_wye[k] - I_wye[k_prev]
    # For Dy (wye_is_from=false): n_eff*I_del[k] = I_wye[k] - I_wye[k_next]
    for k in 1:n_ph
        ph_pos = ph_idx[k]
        if wye_is_from
            k_other = ((k - 2 + n_ph) % n_ph) + 1  # k_prev for Yd
        else
            k_other = (k % n_ph) + 1                # k_next for Dy
        end
        ph_other = ph_idx[k_other]
        @constraint(model,
            n_eff * cr_xf[(tid, side_del, k)] ==
            -(cr_xf[(tid, side_wye, ph_pos)] - cr_xf[(tid, side_wye, ph_other)]))
        @constraint(model,
            n_eff * ci_xf[(tid, side_del, k)] ==
            -(ci_xf[(tid, side_wye, ph_pos)] - ci_xf[(tid, side_wye, ph_other)]))
    end

    # Neutral KCL at the transformer star point:
    #   I_neutral + Σ I_phase = 0
    if n_pos !== nothing
        @constraint(model,
            cr_xf[(tid, side_wye, n_pos)] +
            sum(cr_xf[(tid, side_wye, ph)] for ph in ph_idx) == 0)
        @constraint(model,
            ci_xf[(tid, side_wye, n_pos)] +
            sum(ci_xf[(tid, side_wye, ph)] for ph in ph_idx) == 0)
    end

    # ── No-load (magnetising) shunt across the WINDING-2 (to-side) coils ───────
    # OpenDSS places the exciting branch on winding 2, referred to winding 2's
    # coil voltage (verified against its Yprim): a delta of branches across the
    # LV delta coils when the delta is winding 2 (Yd), phase-to-neutral across
    # the LV wye coils when the wye is winding 2 (Dy). `g/b_no_load` are the
    # total on the to-side coil base, split equally over the n_ph coils.
    G_total = Float64(get(xfmr, "g_no_load", 0.0))
    B_total = Float64(get(xfmr, "b_no_load", 0.0))
    Gp = n_ph > 0 ? G_total / n_ph : 0.0
    Bp = n_ph > 0 ? B_total / n_ph : 0.0
    has_shunt = (Gp != 0.0 || Bp != 0.0)

    # ── KCL contributions: winding currents (+ rneut branch at the wye neutral) ─
    for k in 1:n_wye
        t = tm_wye[k]
        if has_zn && n_pos !== nothing && k == n_pos
            icr = @expression(model, cr_xf[(tid, side_wye, k)] +
                              Gn * vr[(b_wye, t)] - Bn * vi[(b_wye, t)])
            ici = @expression(model, ci_xf[(tid, side_wye, k)] +
                              Gn * vi[(b_wye, t)] + Bn * vr[(b_wye, t)])
            kadd(b_wye, t, -icr, -ici)
        else
            kadd(b_wye, t, -cr_xf[(tid, side_wye, k)], -ci_xf[(tid, side_wye, k)])
        end
    end
    for k in 1:n_ph
        kadd(b_del, tm_del[k], -cr_xf[(tid, side_del, k)], -ci_xf[(tid, side_del, k)])
    end

    # ── Magnetising-shunt injections on the to-side coils ──────────────────────
    if has_shunt
        if wye_is_from
            # to = delta: a branch across each coil (del_k, del_{k_next}).
            for k in 1:n_ph
                ta = tm_del[k]; tb = tm_del[(k % n_ph) + 1]
                vdr = @expression(model, vr[(b_del, ta)] - vr[(b_del, tb)])
                vdi = @expression(model, vi[(b_del, ta)] - vi[(b_del, tb)])
                imr = @expression(model, Gp * vdr - Bp * vdi)
                imi = @expression(model, Gp * vdi + Bp * vdr)
                kadd(b_del, ta, -imr, -imi)
                kadd(b_del, tb,  imr,  imi)
            end
        else
            # to = wye: a branch phase-to-neutral (implicit ground if no neutral).
            t_n = n_pos !== nothing ? tm_wye[n_pos] : nothing
            for k in 1:n_ph
                tph = tm_wye[ph_idx[k]]
                vwr = t_n === nothing ? vr[(b_wye, tph)] :
                      @expression(model, vr[(b_wye, tph)] - vr[(b_wye, t_n)])
                vwi = t_n === nothing ? vi[(b_wye, tph)] :
                      @expression(model, vi[(b_wye, tph)] - vi[(b_wye, t_n)])
                imr = @expression(model, Gp * vwr - Bp * vwi)
                imi = @expression(model, Gp * vwi + Bp * vwr)
                kadd(b_wye, tph, -imr, -imi)
                t_n !== nothing && kadd(b_wye, t_n, imr, imi)
            end
        end
    end

    # ── Current magnitude limits (bare winding-current variables, so the
    #    magnitude limit also tightens each component's box bound) ───────────────
    _limit_xf_current!(s, t, ilim) = (@constraint(model, s^2 + t^2 <= ilim^2);
                                      _limit_current_box!(s, t, ilim))
    for k in 1:n_wye
        length(i_max_fr)   >= k && side_wye == "fr" &&
            _limit_xf_current!(cr_xf[(tid,"fr",k)], ci_xf[(tid,"fr",k)], i_max_fr[k])
        length(i_max_to_v) >= k && side_wye == "to" &&
            _limit_xf_current!(cr_xf[(tid,"to",k)], ci_xf[(tid,"to",k)], i_max_to_v[k])
    end
    for k in 1:n_ph
        length(i_max_fr)   >= k && side_del == "fr" &&
            _limit_xf_current!(cr_xf[(tid,"fr",k)], ci_xf[(tid,"fr",k)], i_max_fr[k])
        length(i_max_to_v) >= k && side_del == "to" &&
            _limit_xf_current!(cr_xf[(tid,"to",k)], ci_xf[(tid,"to",k)], i_max_to_v[k])
    end
end

# ── Autotransformer / step voltage regulator ──────────────────────────────────
#
# A step voltage regulator is an autotransformer: a SERIES winding and a COMMON
# (shunt) winding share a node, so the from (source) and to (regulated) sides are
# galvanically tied — NOT isolated like a two-winding transformer. With a FIXED
# tap ratio `a` (regulated/source) and ANSI connection type, define the effective
# from→to ratio (BMOPFTools._autotransformer_neff):
#
#   Type B (standard SVR, default):  n_eff = a
#   Type A:                          n_eff = 1/a
#
# The voltage and current-coupling constraints are then IDENTICAL in form to the
# wye-wye transformer with N := n_eff and series impedance Z = R + jX referred to
# the from side (R = r_series_from + n_eff²·r_series_to, etc.):
#
#   Voltage : ΔV_fr − n_eff·ΔV_to = R·cr_series − X·ci_series   (+ conjugate for imag)
#   Current : n_eff·I_series_fr + I_to = 0
#
# where ΔV is phase-to-neutral (single-phase) or line-to-line (open-delta).
#
# The DEPARTURE from the isolated YY model is at the shared node. For the single-
# phase regulator the from and to share the neutral, and the common-winding return
# flows there, so the neutral KCL closes BOTH returns:
#
#   I_n + I_series_fr + I_to = 0       (= I_n + (1 − n_eff)·I_series_fr = 0)
#
# Getting this sign wrong yields negative transformer losses (cf. the Yd notes).
# A lossless ideal regulator (R=X=G=B=0) collapses to V_to = n_eff·V_fr_pn.

"""
    _add_regulating_winding!(model, refs, n_eff, r_fr, x_fr, r_to, x_to) -> nothing

Apply the per-winding autotransformer voltage and current-coupling constraints
for one regulating winding spanning a `from` terminal pair (p_fr, q_fr) and a
`to` terminal pair (p_to, q_to), driven by series-current variables
`(Isr, Isi)` on the from side and `(Itr, Iti)` on the to side.

`refs` is a NamedTuple with fields `vr_fr_p, vr_fr_q, vi_fr_p, vi_fr_q` and the
matching `*_to_*` voltage variable refs, plus `Isr, Isi, Itr, Iti`. The voltage
drop is taken across (p − q) on each side, so a phase-to-neutral pair gives the
single-phase regulator and a phase-to-phase pair gives an open-delta winding.

Voltage : (V_fr_p − V_fr_q) − n_eff·(V_to_p − V_to_q) = R·Isr − X·Isi  (+ imag)
Current : n_eff·Isr + Itr = 0  (+ imag)
"""
function _add_regulating_winding!(model, refs, n_eff,
                                  r_fr::Float64, x_fr::Float64,
                                  r_to::Float64, x_to::Float64)
    dvr_fr = @expression(model, refs.vr_fr_p - refs.vr_fr_q)
    dvi_fr = @expression(model, refs.vi_fr_p - refs.vi_fr_q)
    dvr_to = @expression(model, refs.vr_to_p - refs.vr_to_q)
    dvi_to = @expression(model, refs.vi_to_p - refs.vi_to_q)

    has_series = (r_fr != 0.0 || x_fr != 0.0 || r_to != 0.0 || x_to != 0.0)
    if has_series
        # Series drop with the to-side-referred impedance written via I_to (using the
        # coupling n_eff·Isr = −Itr below): degree-2 when n_eff is a tap VARIABLE and
        # exactly equivalent to R = r_fr + n_eff²·r_to when n_eff is fixed.
        @constraint(model, dvr_fr - n_eff * dvr_to ==
            r_fr * refs.Isr - n_eff * r_to * refs.Itr
            - x_fr * refs.Isi + n_eff * x_to * refs.Iti)
        @constraint(model, dvi_fr - n_eff * dvi_to ==
            r_fr * refs.Isi - n_eff * r_to * refs.Iti
            + x_fr * refs.Isr - n_eff * x_to * refs.Itr)
    else
        @constraint(model, dvr_fr == n_eff * dvr_to)
        @constraint(model, dvi_fr == n_eff * dvi_to)
    end

    # Ideal-core current coupling (power-conservative): n_eff·I_series_fr + I_to = 0
    @constraint(model, n_eff * refs.Isr + refs.Itr == 0)
    @constraint(model, n_eff * refs.Isi + refs.Iti == 0)
    return nothing
end

"""
    _add_autotransformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i)

Single-phase step voltage regulator (autotransformer). Terminal arity (2,2):
either line-to-neutral (`["ph","n"]`) or line-to-line (`["ph1","ph2"]`). Uses one
series-current variable per side (index 1). The regulating winding spans the pair
`(p, q)` where q = the neutral (L-N) or the second phase (L-L). The SVR shares a
single physical bushing (the neutral, or the common phase); since the data exposes
it as two terminals (`t_fr_q`, `t_to_q`), each coil returns at its own reference
(matching the Yprim) and a galvanic bond — V equal + a bond current (the extra
"fr" index 2) — ties them, the open-delta straight-through pattern. Without the
bond the secondary return would leak to earth / dangle.
"""
function _add_autotransformer!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                               tap=nothing, branch_inj=nothing, scoil=nothing)
    kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)
    b_fr  = get(xfmr, "bus_from", "")
    b_to  = get(xfmr, "bus_to",   "")
    tmfr  = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tmto  = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
    # Effective ratio n_eff: fixed from `tap_ratio` (default 1.0) or the free tap
    # variable (= n_eff, warm-started at the nominal regulation ratio).
    n_eff = tap === nothing ? BMOPFTools._autotransformer_ratio(xfmr) : tap

    # Winding terminal pairs (p, q): q = neutral for a line-to-neutral SVR, or the
    # second phase for a line-to-line SVR. The regulating winding spans (V_p − V_q)
    # on each side, and the return closes at q.
    pairs_fr = BMOPFTools._xfmr_winding_pairs(tmfr)
    pairs_to = BMOPFTools._xfmr_winding_pairs(tmto)
    if isempty(pairs_fr) || isempty(pairs_to)
        @warn "single_phase_autotransformer '$tid': needs a phase conductor on " *
              "each side; got from=$(tmfr) to=$(tmto). Skipping."
        return
    end
    (p_fr, q_fr) = pairs_fr[1]
    (p_to, q_to) = pairs_to[1]
    t_fr_ph = tmfr[p_fr]; t_fr_q = q_fr === nothing ? nothing : tmfr[q_fr]
    t_to_ph = tmto[p_to]; t_to_q = q_to === nothing ? nothing : tmto[q_to]

    # Winding impedances (Γ convention, identical to YY). The regulating-winding
    # helper refers the to-side branch via I_to so n_eff may be a tap variable.
    r_fr = Float64(get(xfmr, "r_series_from", 0.0))
    x_fr = Float64(get(xfmr, "x_series_from", 0.0))
    r_to = Float64(get(xfmr, "r_series_to",   0.0))
    x_to = Float64(get(xfmr, "x_series_to",   0.0))

    G = Float64(get(xfmr, "g_no_load", 0.0))
    B = Float64(get(xfmr, "b_no_load", 0.0))
    has_shunt = (G != 0.0 || B != 0.0)

    i_max_fr   = Float64.(get(xfmr, "i_max_from", Float64[]))
    i_max_to_v = Float64.(get(xfmr, "i_max_to",   Float64[]))
    # Regulators PREFER current (tap-changer limit); the nameplate is still
    # accepted. Measuring the FROM-TERMINAL power (V_fr,p − V_fr,q)·conj(I_series)
    # gives the through-kVA — correct for the autotransformer advantage, where the
    # internal winding kVA is smaller than the through rating.
    s_rating   = Float64(get(xfmr, "s_rating", 0.0))

    Isr = cr_xf[(tid,"fr",1)]; Isi = ci_xf[(tid,"fr",1)]
    Itr = cr_xf[(tid,"to",1)]; Iti = ci_xf[(tid,"to",1)]

    # Winding-reference voltages V_q (implicitly 0 when q absent — phase-to-ground).
    vr_fr_q = t_fr_q !== nothing ? vr[(b_fr, t_fr_q)] : JuMP.AffExpr(0.0)
    vi_fr_q = t_fr_q !== nothing ? vi[(b_fr, t_fr_q)] : JuMP.AffExpr(0.0)
    vr_to_q = t_to_q !== nothing ? vr[(b_to, t_to_q)] : JuMP.AffExpr(0.0)
    vi_to_q = t_to_q !== nothing ? vi[(b_to, t_to_q)] : JuMP.AffExpr(0.0)

    refs = (vr_fr_p = vr[(b_fr, t_fr_ph)], vr_fr_q = vr_fr_q,
            vi_fr_p = vi[(b_fr, t_fr_ph)], vi_fr_q = vi_fr_q,
            vr_to_p = vr[(b_to, t_to_ph)], vr_to_q = vr_to_q,
            vi_to_p = vi[(b_to, t_to_ph)], vi_to_q = vi_to_q,
            Isr = Isr, Isi = Isi, Itr = Itr, Iti = Iti)
    _add_regulating_winding!(model, refs, n_eff, r_fr, x_fr, r_to, x_to)

    # Nameplate cap on the from-side through-power (V_fr,p − V_fr,q)·conj(I_series).
    # Regulators prefer current, but the nameplate is still enforced when present.
    if s_rating > 0.0
        _apparent_power_limit!(model,
            @expression(model, refs.vr_fr_p - refs.vr_fr_q),
            @expression(model, refs.vi_fr_p - refs.vi_fr_q),
            Isr, Isi, s_rating; base_name = "$(tid)_reg",
            ledger = scoil, key = (tid, "fr", 1))
    end

    # From-side phase terminal current = series + magnetising shunt (V_p − V_q).
    if has_shunt
        vr_pn = t_fr_q !== nothing ?
            @expression(model, vr[(b_fr, t_fr_ph)] - vr[(b_fr, t_fr_q)]) : vr[(b_fr, t_fr_ph)]
        vi_pn = t_fr_q !== nothing ?
            @expression(model, vi[(b_fr, t_fr_ph)] - vi[(b_fr, t_fr_q)]) : vi[(b_fr, t_fr_ph)]
        icr = @expression(model, Isr + G * vr_pn - B * vi_pn)
        ici = @expression(model, Isi + G * vi_pn + B * vr_pn)
        kadd(b_fr, t_fr_ph, -icr, -ici)
        length(i_max_fr) >= 1 && @constraint(model, icr^2 + ici^2 <= i_max_fr[1]^2)
    else
        kadd(b_fr, t_fr_ph, -Isr, -Isi)
        if length(i_max_fr) >= 1
            @constraint(model, Isr^2 + Isi^2 <= i_max_fr[1]^2)
            _limit_current_box!(Isr, Isi, i_max_fr[1])
        end
    end

    # To-side phase terminal: transformer injects I_to.
    kadd(b_to, t_to_ph, -Itr, -Iti)
    if length(i_max_to_v) >= 1
        @constraint(model, Itr^2 + Iti^2 <= i_max_to_v[1]^2)
        _limit_current_box!(Itr, Iti, i_max_to_v[1])
    end

    # Reference-terminal KCL + galvanic bond. The SVR shares one physical bushing
    # (the neutral for an L-N regulator, the common phase for an L-L regulator),
    # exposed as two terminals (t_fr_q, t_to_q) on two buses. We match the Yprim —
    # each coil returns at its own reference terminal (primary + no-load shunt at
    # t_fr_q, secondary at t_to_q) — and impose the shared bushing as a galvanic
    # bond: a zero-impedance through-branch (V equal + bond current, the extra "fr"
    # index), the open-delta straight-through pattern. The four terminal injections
    # still sum to zero, so the loss identity stays exact.
    if t_fr_q !== nothing && t_to_q !== nothing
        # Primary coil return (+ no-load shunt return) at the from reference.
        icr_fr = @expression(model, Isr)
        ici_fr = @expression(model, Isi)
        if has_shunt
            vr_pn = @expression(model, vr[(b_fr, t_fr_ph)] - vr[(b_fr, t_fr_q)])
            vi_pn = @expression(model, vi[(b_fr, t_fr_ph)] - vi[(b_fr, t_fr_q)])
            icr_fr = @expression(model, icr_fr + G * vr_pn - B * vi_pn)
            ici_fr = @expression(model, ici_fr + G * vi_pn + B * vr_pn)
        end
        # Bond current (extra "fr" index): flows from the from-reference to the
        # to-reference through the shared bushing.
        Ibnr = cr_xf[(tid,"fr",2)]; Ibni = ci_xf[(tid,"fr",2)]
        @constraint(model, vr[(b_fr, t_fr_q)] == vr[(b_to, t_to_q)])
        @constraint(model, vi[(b_fr, t_fr_q)] == vi[(b_to, t_to_q)])
        kadd(b_fr, t_fr_q, @expression(model, icr_fr - Ibnr),
                           @expression(model, ici_fr - Ibni))
        kadd(b_to, t_to_q, @expression(model, Itr + Ibnr),
                           @expression(model, Iti + Ibni))
    elseif t_fr_q !== nothing
        # No to-side reference terminal: the secondary return folds into the shared
        # from reference (galvanic tie). I_ref + I_series_fr + I_to = 0.
        icr_n = @expression(model, Isr + Itr)
        ici_n = @expression(model, Isi + Iti)
        if has_shunt
            vr_pn = @expression(model, vr[(b_fr, t_fr_ph)] - vr[(b_fr, t_fr_q)])
            vi_pn = @expression(model, vi[(b_fr, t_fr_ph)] - vi[(b_fr, t_fr_q)])
            icr_n = @expression(model, icr_n + G * vr_pn - B * vi_pn)
            ici_n = @expression(model, ici_n + G * vi_pn + B * vr_pn)
        end
        kadd(b_fr, t_fr_q, icr_n, ici_n)
    elseif t_to_q !== nothing
        # Only a to-side reference: the combined return closes there.
        kadd(b_to, t_to_q, @expression(model, Isr + Itr),
                           @expression(model, Isi + Iti))
    end
end

# ── Open-delta regulator (monolithic three-phase) ─────────────────────────────
#
# Two single-phase autotransformer windings connected LINE-TO-LINE across the
# phase pairs implied by `connection` (GridLAB-D convention). Each winding uses
# the same line-to-line regulating constraint as the single-phase case, but with
# the voltage drop taken across two PHASE terminals (no neutral path). The third
# phase and the neutral are determined by KCL.
#
#   "ABBC" => regulator 1 across (1,2), regulator 2 across (2,3)
#   "BCAC" => regulator 1 across (2,3), regulator 2 across (1,3)
#   "CABA" => regulator 1 across (3,1), regulator 2 across (2,1)
#
# Variable indices: series current per regulator on each side — index 1 and 2.

const _OPEN_DELTA_PAIRS = Dict{String,Tuple{Tuple{Int,Int},Tuple{Int,Int}}}(
    "ABBC" => ((1, 2), (2, 3)),
    "BCAC" => ((2, 3), (1, 3)),
    "CABA" => ((3, 1), (2, 1)),
)

"""
    _add_open_delta_regulator!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i)

Monolithic open-delta regulator: two line-to-line regulating windings. Terminal
arity (4,4): `["1","2","3","n"]` on both sides; the neutral carries no winding
current. `tap_ratio` is `[a1, a2]` (per regulator); `regulator_type` shared.
"""
function _add_open_delta_regulator!(model, tid, xfmr, vr, vi, cr_xf, ci_xf, kcl_r, kcl_i;
                                    tap=nothing, branch_inj=nothing, scoil=nothing)
    kadd = _xf_kadd(kcl_r, kcl_i, branch_inj, tid)
    b_fr = get(xfmr, "bus_from", "")
    b_to = get(xfmr, "bus_to",   "")
    tmfr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
    tmto = Vector{String}(get(xfmr, "terminal_map_to",   String[]))

    conn = uppercase(strip(string(get(xfmr, "connection", ""))))
    pairs = get(_OPEN_DELTA_PAIRS, conn, nothing)
    if pairs === nothing
        @warn "open_delta_regulator '$tid': unknown connection '$conn' " *
              "(expected ABBC/BCAC/CABA). Skipping."
        return
    end
    ph_fr = BMOPFTools._phase_positions(tmfr)
    ph_to = BMOPFTools._phase_positions(tmto)
    if length(ph_fr) < 3 || length(ph_to) < 3
        @warn "open_delta_regulator '$tid': needs 3 phase conductors on each " *
              "side; got from=$(tmfr) to=$(tmto). Skipping."
        return
    end

    # Per-regulator tap ratios → effective ratios.
    taps = Float64.(get(xfmr, "tap_ratio", Float64[]))
    rt   = string(get(xfmr, "regulator_type", "B"))
    a1   = length(taps) >= 1 ? taps[1] : 1.0
    a2   = length(taps) >= 2 ? taps[2] : a1
    n_eff = (BMOPFTools._autotransformer_neff(a1, rt),
             BMOPFTools._autotransformer_neff(a2, rt))

    r_fr = Float64(get(xfmr, "r_series_from", 0.0))
    x_fr = Float64(get(xfmr, "x_series_from", 0.0))
    r_to = Float64(get(xfmr, "r_series_to",   0.0))
    x_to = Float64(get(xfmr, "x_series_to",   0.0))

    i_max_fr   = Float64.(get(xfmr, "i_max_from", Float64[]))
    i_max_to_v = Float64.(get(xfmr, "i_max_to",   Float64[]))
    # Each of the two windings is an identical single-phase regulator, rated at
    # the per-regulator through nameplate `s_rating` (undivided, matching the
    # single_phase_autotransformer convention). Regulators prefer current.
    s_rating   = Float64(get(xfmr, "s_rating", 0.0))

    # Per-regulator no-load (core-loss) shunt, stamped across each from-side
    # line-to-line pair (V_p − V_q), consistent with the single-phase and Yd
    # builders and with `_yprim_open_delta`.
    G0 = Float64(get(xfmr, "g_no_load", 0.0))
    B0 = Float64(get(xfmr, "b_no_load", 0.0))
    has_shunt = (G0 != 0.0 || B0 != 0.0)

    for (j, (pj, qj)) in enumerate(pairs)
        # Per-regulator effective ratio: the free tap variable when present, else the
        # fixed n_eff. The winding helper refers the to-side branch via I_to so a
        # variable ratio keeps the rows degree-2.
        ne = (tap isa AbstractDict && haskey(tap, (tid, j))) ? tap[(tid, j)] : n_eff[j]
        # Phase terminals spanned by this regulator (line-to-line).
        t_fr_p = tmfr[ph_fr[pj]]; t_fr_q = tmfr[ph_fr[qj]]
        t_to_p = tmto[ph_to[pj]]; t_to_q = tmto[ph_to[qj]]

        Isr = cr_xf[(tid,"fr",j)]; Isi = ci_xf[(tid,"fr",j)]
        Itr = cr_xf[(tid,"to",j)]; Iti = ci_xf[(tid,"to",j)]

        refs = (vr_fr_p = vr[(b_fr, t_fr_p)], vr_fr_q = vr[(b_fr, t_fr_q)],
                vi_fr_p = vi[(b_fr, t_fr_p)], vi_fr_q = vi[(b_fr, t_fr_q)],
                vr_to_p = vr[(b_to, t_to_p)], vr_to_q = vr[(b_to, t_to_q)],
                vi_to_p = vi[(b_to, t_to_p)], vi_to_q = vi[(b_to, t_to_q)],
                Isr = Isr, Isi = Isi, Itr = Itr, Iti = Iti)
        _add_regulating_winding!(model, refs, ne, r_fr, x_fr, r_to, x_to)

        # KCL: the from-side series current enters at phase p and returns at q;
        # the to-side current is injected at p and returned at q (line-to-line).
        # The from-side current also carries the no-load shunt Y0·(V_p − V_q).
        if has_shunt
            vr_ll = @expression(model, refs.vr_fr_p - refs.vr_fr_q)
            vi_ll = @expression(model, refs.vi_fr_p - refs.vi_fr_q)
            imr = @expression(model, Isr + G0 * vr_ll - B0 * vi_ll)
            imi = @expression(model, Isi + G0 * vi_ll + B0 * vr_ll)
            kadd(b_fr, t_fr_p, -imr, -imi)
            kadd(b_fr, t_fr_q,  imr,  imi)
        else
            kadd(b_fr, t_fr_p, -Isr, -Isi)
            kadd(b_fr, t_fr_q,  Isr,  Isi)
        end
        kadd(b_to, t_to_p, -Itr, -Iti)
        kadd(b_to, t_to_q,  Itr,  Iti)

        if length(i_max_fr) >= j
            @constraint(model, Isr^2 + Isi^2 <= i_max_fr[j]^2)
            _limit_current_box!(Isr, Isi, i_max_fr[j])
        end
        if length(i_max_to_v) >= j
            @constraint(model, Itr^2 + Iti^2 <= i_max_to_v[j]^2)
            _limit_current_box!(Itr, Iti, i_max_to_v[j])
        end
        # Nameplate cap on the from-side line-to-line through-power for this regulator.
        if s_rating > 0.0
            _apparent_power_limit!(model,
                @expression(model, refs.vr_fr_p - refs.vr_fr_q),
                @expression(model, refs.vi_fr_p - refs.vi_fr_q),
                Isr, Isi, s_rating; base_name = "$(tid)_odreg_$(j)",
                ledger = scoil, key = (tid, "fr", j))
        end
    end

    # ── Galvanic straight-through of the shared phase (common-neutral model) ───
    # In a real open-delta SVR the phase common to both regulators (B in the
    # AB-CB / ABBC arrangement) is a copper wire straight through the bank, so
    # V_shared_from = V_shared_to (Yan et al. 2018, Eq. 14 — the "common neutral"
    # model that matches OpenDSS and field measurement). Without this the
    # line-to-line voltages are still correct but the per-phase/neutral reference
    # floats (the unphysical "unspecified neutral" model, 4.9–6.5 pu in the paper).
    #
    # The shared phase is the terminal appearing in BOTH regulator pairs. We tie
    # its from/to voltages and inject the wire current (a free variable, index 3
    # on the "fr" side) as a zero-impedance through-branch so KCL stays balanced.
    (p1, q1), (p2, q2) = pairs
    shared = intersect((p1, q1), (p2, q2))
    if length(shared) == 1
        sp = first(shared)
        t_fr_s = tmfr[ph_fr[sp]]
        t_to_s = tmto[ph_to[sp]]
        # Straight-through: equal voltage on both sides of the shared phase.
        @constraint(model, vr[(b_fr, t_fr_s)] == vr[(b_to, t_to_s)])
        @constraint(model, vi[(b_fr, t_fr_s)] == vi[(b_to, t_to_s)])
        # Wire current: leaves src.shared, enters reg.shared (through-branch).
        Iwr = cr_xf[(tid,"fr",3)]; Iwi = ci_xf[(tid,"fr",3)]
        kadd(b_fr, t_fr_s, -Iwr, -Iwi)
        kadd(b_to, t_to_s,  Iwr,  Iwi)
    end
end
