# nwinding.jl
#
# General n-winding transformer — OPF variables + constraints.
#
# Deliberately INDEPENDENT of the two-bus transformer builder (transformer.jl):
# it shares none of the `_add_yy_transformer!` / `_xf_kadd` / `_kcl_add!` code,
# uses its own current/star-node variables, and its own KCL/ledger contribution
# closure. It replicates the *idea* of the center_tap star/T model generalised to
# n windings.
#
# Model (all-wye), four-wire rectangular IVR, per winding j and phase position k,
# with an internal floating star node `V_star(k)` referred to winding 1's base:
#
#   Voltage : (V_pn_j(k)) − N_j · V_star(k) = Z_j · I_j(k)          (Z_j = R_j+jX_j)
#   Star KCL: Σ_j  N_j · I_j(k) = 0                                 (ideal core)
#
# where V_pn_j(k) = V[bus_j, phase k] − V[bus_j, neutral_j],
#       N_j       = v_ref[j] / v_ref[1]  (off-nominal ratio; N_1 = 1),
#       Z_j       = winding j's star/T leg (own-base; per-unit value is
#                   base-invariant — see `_nw_legs_for_opf`).
#
# Each winding contributes −I_j(k) into its bus phase terminal and +Σ_k I_j(k)
# into its bus neutral terminal. The optional no-load shunt (g+jb) is drawn at
# winding 1's terminals.

"""
    _nw_legs_for_opf(xfmr) -> Vector{Tuple{Float64,Float64}}

Per-winding star/T leg `(R_j, X_j)` for the OPF, in model units. When per-unit
scaling has run (`_pu_scale_nwinding!`), it stored `_r_pu`/`_x_pu` on each winding
(the base-invariant per-unit value); use those. Otherwise (SI model) derive the
own-base legs from `_nw_star_legs`.
"""
function _nw_legs_for_opf(xfmr::Dict{String,Any})
    raw = get(xfmr, "windings", Any[])
    if raw isa AbstractVector && !isempty(raw) &&
       all(w -> w isa AbstractDict && haskey(w, "_r_pu") && haskey(w, "_x_pu"), raw)
        return [(Float64(w["_r_pu"]), Float64(w["_x_pu"])) for w in raw]
    end
    BMOPFTools._nw_star_legs(xfmr)
end

"""
    _add_nwinding_variables!(model, net) -> (cr_nw, ci_nw, vr_star, vi_star)

Declare the n-winding transformer current variables `cr_nw`/`ci_nw` keyed
`(tid, winding_idx, phase_idx)` and the internal star-node voltage variables
`vr_star`/`vi_star` keyed `(tid, phase_idx)`. Independent of
`_add_transformer_variables!`.
"""
function _add_nwinding_variables!(model, net)
    cr_nw   = Dict{Tuple{String,Int,Int}, JuMP.VariableRef}()
    ci_nw   = Dict{Tuple{String,Int,Int}, JuMP.VariableRef}()
    vr_star = Dict{Tuple{String,Int},     JuMP.VariableRef}()
    vi_star = Dict{Tuple{String,Int},     JuMP.VariableRef}()

    nwd = get(get(net, "transformer", Dict()), "n_winding", Dict())
    for (tid, xfmr) in nwd
        xfmr isa Dict || continue
        ws = BMOPFTools._nw_windings(xfmr)
        isempty(ws) && continue
        phases1, _ = BMOPFTools._nw_phase_terminals(ws[1].terminal_map)
        for pk in eachindex(phases1)
            vr_star[(tid, pk)] = @variable(model, base_name = "vr_star_$(tid)_$(pk)")
            vi_star[(tid, pk)] = @variable(model, base_name = "vi_star_$(tid)_$(pk)")
        end
        for (j, w) in enumerate(ws)
            phs, _ = BMOPFTools._nw_phase_terminals(w.terminal_map)
            for pk in eachindex(phs)
                cr_nw[(tid, j, pk)] = @variable(model, base_name = "cr_nw_$(tid)_$(j)_$(pk)")
                ci_nw[(tid, j, pk)] = @variable(model, base_name = "ci_nw_$(tid)_$(j)_$(pk)")
            end
        end
    end
    cr_nw, ci_nw, vr_star, vi_star
end

"""
    _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=nothing)

Add the all-wye n-winding transformer voltage/current constraints and KCL
contributions. Errors if any winding uses a DELTA connection (not yet
implemented). Independent of `_add_transformer_constraints!`.
"""
function _add_nwinding_constraints!(model, net, vars, kcl_r, kcl_i; branch_inj=nothing)
    vr  = vars[:vr];  vi  = vars[:vi]
    cr  = vars[:cr_nw]; ci = vars[:ci_nw]
    vrs = vars[:vr_star]; vis = vars[:vi_star]

    nwd = get(get(net, "transformer", Dict()), "n_winding", Dict())
    for (tid, xfmr) in nwd
        xfmr isa Dict || continue
        ws = BMOPFTools._nw_windings(xfmr)
        isempty(ws) && continue
        any(w -> w.connection == "DELTA", ws) &&
            error("n_winding transformer '$tid': DELTA winding is reserved but not " *
                  "yet implemented (all-wye only).")

        N    = BMOPFTools._nw_turns_ratios(xfmr)
        legs = _nw_legs_for_opf(xfmr)
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

        for (j, w) in enumerate(ws)
            phs, neu = BMOPFTools._nw_phase_terminals(w.terminal_map)
            R, X = legs[j]
            bus  = w.bus
            for pk in 1:nph
                ph = phs[pk]
                Ir = cr[(tid, j, pk)]; Ii = ci[(tid, j, pk)]
                vr_pn = neu === nothing ? @expression(model, vr[(bus, ph)]) :
                                          @expression(model, vr[(bus, ph)] - vr[(bus, neu)])
                vi_pn = neu === nothing ? @expression(model, vi[(bus, ph)]) :
                                          @expression(model, vi[(bus, ph)] - vi[(bus, neu)])
                @constraint(model, vr_pn - N[j] * vrs[(tid, pk)] == R * Ir - X * Ii)
                @constraint(model, vi_pn - N[j] * vis[(tid, pk)] == R * Ii + X * Ir)
                # phase current flows into the transformer
                kadd(bus, ph, @expression(model, -Ir), @expression(model, -Ii))
            end
            # neutral carries the return of all phase currents
            if neu !== nothing
                kadd(bus, neu,
                     @expression(model, sum(cr[(tid, j, pk)] for pk in 1:nph)),
                     @expression(model, sum(ci[(tid, j, pk)] for pk in 1:nph)))
            end
        end

        # Ideal-core star KCL per phase.
        for pk in 1:nph
            @constraint(model, sum(N[j] * cr[(tid, j, pk)] for j in eachindex(ws)) == 0)
            @constraint(model, sum(N[j] * ci[(tid, j, pk)] for j in eachindex(ws)) == 0)
        end

        # Optional no-load (magnetising) shunt drawn at winding 1's terminals.
        g = Float64(get(xfmr, "_g_no_load_pu", get(xfmr, "g_no_load", 0.0)))
        b = Float64(get(xfmr, "_b_no_load_pu", get(xfmr, "b_no_load", 0.0)))
        if g != 0.0 || b != 0.0
            w1 = ws[1]
            phs1, neu1 = BMOPFTools._nw_phase_terminals(w1.terminal_map)
            for pk in 1:nph
                ph = phs1[pk]
                vr_pn = neu1 === nothing ? @expression(model, vr[(w1.bus, ph)]) :
                                           @expression(model, vr[(w1.bus, ph)] - vr[(w1.bus, neu1)])
                vi_pn = neu1 === nothing ? @expression(model, vi[(w1.bus, ph)]) :
                                           @expression(model, vi[(w1.bus, ph)] - vi[(w1.bus, neu1)])
                Imr = @expression(model, g * vr_pn - b * vi_pn)
                Imi = @expression(model, g * vi_pn + b * vr_pn)
                kadd(w1.bus, ph, @expression(model, -Imr), @expression(model, -Imi))
                neu1 !== nothing && kadd(w1.bus, neu1, Imr, Imi)
            end
        end
    end
end
