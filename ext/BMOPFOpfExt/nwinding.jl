# nwinding.jl
#
# General n-winding transformer — OPF variables + constraints.
#
# Deliberately INDEPENDENT of the two-bus transformer builder (transformer.jl):
# it shares none of the `_add_yy_transformer!` / `_xf_kadd` / `_kcl_add!` code,
# uses its own current variables, and its own KCL/ledger contribution closure.
#
# Model (WYE and/or DELTA windings), four-wire rectangular IVR. The leakage is
# the OpenDSS-style ZB matrix referred to winding 1 (exact for any n — see
# `_nw_zb_matrix`), with winding 1 as the reference winding. Per phase/leg, with
# referred coil currents `I_k^r = N_k I_k` (`N_k = v_nom[k]/v_nom[1]`, `N_1 = 1`)
# and referred coil voltages `V_k^r = U_k / N_k`:
#
#   Ampere-turn (ideal core):   Σ_k N_k I_k = 0
#   Leakage (i = 1..n-1):       V_1^r − V_{i+1}^r = Σ_{j=1}^{n-1} ZB[i,j] I_{j+1}^r
#
# The per-leg leakage/ampere-turn structure is identical for WYE and DELTA; only
# the coil↔terminal incidence differs. The coil voltage U_k is phase-to-neutral
# for a WYE winding and line-to-line (phase pk minus its delta partner) for a
# DELTA winding — whose `v_nom` is the line-to-line coil voltage, so the √3 lives
# in N_k and U_k^r stays consistent (and per-unit needs no √3 fudge, since the
# bus base is line-to-neutral). A WYE coil injects −I_k at its phase and +Σ_phase
# I_k at its neutral; a DELTA coil injects −I_k at phase pk and +I_k at its delta
# partner node. The optional no-load shunt (g+jb) is drawn across winding 1's coil.

"""
    _add_nwinding_variables!(model, net) -> (cr_nw, ci_nw)

Declare the n-winding transformer current variables `cr_nw`/`ci_nw`, keyed
`(tid, winding_idx, phase_idx)`. Independent of `_add_transformer_variables!`.
"""
function _add_nwinding_variables!(model, net)
    cr_nw = Dict{Tuple{String,Int,Int}, JuMP.VariableRef}()
    ci_nw = Dict{Tuple{String,Int,Int}, JuMP.VariableRef}()

    nwd = get(get(net, "transformer", Dict()), "n_winding", Dict())
    for (tid, xfmr) in nwd
        xfmr isa Dict || continue
        ws = BMOPFTools._nw_windings(xfmr)
        isempty(ws) && continue
        for (j, w) in enumerate(ws)
            phs, _ = BMOPFTools._nw_phase_terminals(w.terminal_map)
            for pk in eachindex(phs)
                cr_nw[(tid, j, pk)] = @variable(model, base_name = "cr_nw_$(tid)_$(j)_$(pk)")
                ci_nw[(tid, j, pk)] = @variable(model, base_name = "ci_nw_$(tid)_$(j)_$(pk)")
            end
        end
    end
    cr_nw, ci_nw
end

# Tap optimisation is NOT supported for n_winding (the ratio is held fixed at the
# nominal turns ratio). If the data carries tap field(s) — on the transformer or
# any winding — warn loudly so the unsupported request is not silently dropped.
const _NW_TAP_KEYS = ("tap", "tap_min", "tap_max",
                      "tap_ratio", "tap_ratio_min", "tap_ratio_max")
function _warn_nwinding_unsupported_tap(tid, xfmr)
    hit = any(haskey(xfmr, k) for k in _NW_TAP_KEYS)
    if !hit
        ws = get(xfmr, "windings", nothing)
        ws isa AbstractVector && (hit = any(
            w isa AbstractDict && any(haskey(w, k) for k in _NW_TAP_KEYS) for w in ws))
    end
    hit && @warn "n_winding transformer '$(tid)' carries tap field(s), but tap " *
        "optimisation is not supported for n_winding — the ratio is held FIXED at " *
        "the nominal turns ratio. Remove the tap fields, or model the regulated " *
        "winding with a supported subtype (single_phase, center_tap, wye_delta, " *
        "delta_wye, single_phase_autotransformer, open_delta_regulator)."
end

"""
    _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=nothing)

Add the n-winding transformer leakage (ZB) + ampere-turn constraints and KCL
contributions. Handles WYE and DELTA windings (connection-aware coil incidence);
independent of `_add_transformer_constraints!`.
"""
function _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=nothing)
    vr = vars[:vr]; vi = vars[:vi]
    cr = vars[:cr_nw]; ci = vars[:ci_nw]

    nwd = get(get(net, "transformer", Dict()), "n_winding", Dict())
    for (tid, xfmr) in nwd
        xfmr isa Dict || continue
        _warn_nwinding_unsupported_tap(tid, xfmr)
        ws = BMOPFTools._nw_windings(xfmr)
        n  = length(ws)
        n < 2 && continue

        N  = BMOPFTools._nw_turns_ratios(xfmr)
        ZB = BMOPFTools._nw_zb_for_opf(xfmr)          # (n-1)×(n-1), model units
        phases1, _ = BMOPFTools._nw_phase_terminals(ws[1].terminal_map)
        nph = length(phases1)

        # Independent KCL/ledger contribution (current flowing INTO the element).
        kadd = (bus, term, cr_e, ci_e) -> begin
            key = (bus, term)
            if haskey(kcl_r, key)
                JuMP.add_to_expression!(kcl_r[key], cr_e)
                JuMP.add_to_expression!(kcl_i[key], ci_e)
            end
            if branch_inj !== nothing
                dev = get!(get!(branch_inj, "transformer", Dict{String,Any}()),
                           tid, Vector{Any}())
                push!(dev, (bus, term, cr_e, ci_e))
            end
        end

        # Coil phase voltage of winding k at leg pk: phase-to-neutral for a WYE
        # winding, line-to-line (phase pk minus its delta partner) for a DELTA
        # winding. The delta v_nom is the line-to-line coil voltage, so U_k/N_k
        # stays referred consistently (the √3 lives in N_k).
        upn(k, pk) = begin
            w = ws[k]; phs, neu = BMOPFTools._nw_phase_terminals(w.terminal_map)
            if w.connection == "DELTA"
                po = BMOPFTools._nw_delta_other(pk, length(phs), w.delta_roll)
                ur = @expression(model, vr[(w.bus, phs[pk])] - vr[(w.bus, phs[po])])
                ui = @expression(model, vi[(w.bus, phs[pk])] - vi[(w.bus, phs[po])])
                return (ur, ui)
            end
            ur = neu === nothing ? @expression(model, vr[(w.bus, phs[pk])]) :
                                   @expression(model, vr[(w.bus, phs[pk])] - vr[(w.bus, neu)])
            ui = neu === nothing ? @expression(model, vi[(w.bus, phs[pk])]) :
                                   @expression(model, vi[(w.bus, phs[pk])] - vi[(w.bus, neu)])
            (ur, ui)
        end

        for pk in 1:nph
            # Referred winding currents I_k^r = N_k I_k.
            irr = [@expression(model, N[k] * cr[(tid, k, pk)]) for k in 1:n]
            iri = [@expression(model, N[k] * ci[(tid, k, pk)]) for k in 1:n]

            # Ampere-turn (ideal core): Σ_k N_k I_k = 0.
            @constraint(model, sum(irr[k] for k in 1:n) == 0)
            @constraint(model, sum(iri[k] for k in 1:n) == 0)

            # Leakage: V_1^r − V_{i+1}^r = −Σ_j ZB[i,j] I_{j+1}^r  (i = 1..n-1).
            # The minus sign is the current-into-element convention (derived from
            # the equivalent star form U_j − N_j V_core = Z_j I_j).
            u1r, u1i = upn(1, pk)                      # V_1^r (N_1 = 1)
            for i in 1:n-1
                uir, uii = upn(i + 1, pk)
                lhs_r = @expression(model, u1r - uir / N[i+1])
                lhs_i = @expression(model, u1i - uii / N[i+1])
                rhs_r = @expression(model,
                    sum(real(ZB[i, j]) * irr[j+1] - imag(ZB[i, j]) * iri[j+1] for j in 1:n-1))
                rhs_i = @expression(model,
                    sum(real(ZB[i, j]) * iri[j+1] + imag(ZB[i, j]) * irr[j+1] for j in 1:n-1))
                @constraint(model, lhs_r + rhs_r == 0)
                @constraint(model, lhs_i + rhs_i == 0)
            end

            # Inject coil currents into bus terminals (connection-aware). The coil
            # current cr/ci[(tid,k,pk)] is the winding/arm current of leg pk: a WYE
            # coil returns it through the neutral (added below); a DELTA coil flows
            # from node pk to its delta partner, so it injects −I at pk and +I at
            # the partner node (the line current emerges as the node-wise sum).
            for k in 1:n
                w = ws[k]; phs, _ = BMOPFTools._nw_phase_terminals(w.terminal_map)
                kadd(w.bus, phs[pk], @expression(model, -cr[(tid, k, pk)]),
                                     @expression(model, -ci[(tid, k, pk)]))
                if w.connection == "DELTA"
                    po = BMOPFTools._nw_delta_other(pk, length(phs), w.delta_roll)
                    kadd(w.bus, phs[po], @expression(model, cr[(tid, k, pk)]),
                                         @expression(model, ci[(tid, k, pk)]))
                end
            end
        end

        # Neutral return current for each winding: +Σ_phase I_k.
        for k in 1:n
            w = ws[k]; phs, neu = BMOPFTools._nw_phase_terminals(w.terminal_map)
            neu === nothing && continue
            kadd(w.bus, neu,
                 @expression(model, sum(cr[(tid, k, pk)] for pk in 1:length(phs))),
                 @expression(model, sum(ci[(tid, k, pk)] for pk in 1:length(phs))))
        end

        # Optional no-load (magnetising) shunt drawn at winding 1's terminals.
        g = Float64(get(xfmr, "_g_no_load_pu", get(xfmr, "g_no_load", 0.0)))
        b = Float64(get(xfmr, "_b_no_load_pu", get(xfmr, "b_no_load", 0.0)))
        if g != 0.0 || b != 0.0
            w1 = ws[1]; phs1, neu1 = BMOPFTools._nw_phase_terminals(w1.terminal_map)
            for pk in 1:nph
                ur, ui = upn(1, pk)
                Imr = @expression(model, g * ur - b * ui)
                Imi = @expression(model, g * ui + b * ur)
                kadd(w1.bus, phs1[pk], @expression(model, -Imr), @expression(model, -Imi))
                if w1.connection == "DELTA"
                    po = BMOPFTools._nw_delta_other(pk, length(phs1), w1.delta_roll)
                    kadd(w1.bus, phs1[po], Imr, Imi)
                elseif neu1 !== nothing
                    kadd(w1.bus, neu1, Imr, Imi)
                end
            end
        end
    end
end
