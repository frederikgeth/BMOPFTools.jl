# JuMP variable declarations for the four-wire IVR-EN OPF.
#
# Index conventions:
#   vr/vi        : Dict{Tuple{String,String}, VariableRef}  (bus_id, terminal)
#   cr_fr/ci_fr  : Dict{Tuple{String,Int},    VariableRef}  (line_id, conductor_pos)
#   cr_to/ci_to  : Dict{Tuple{String,Int},    AffExpr}      (line_id, conductor_pos) = -cr_fr / -ci_fr
#   crd/cid      : Dict{Tuple{String,Int},    VariableRef}  (load_id, conductor_pos)
#   crg/cig      : Dict{Tuple{String,Int},    VariableRef}  (gen_id,  conductor_pos)
#   cr_src/ci_src: Dict{Tuple{String,Int},    VariableRef}  (src_id,  conductor_pos)
#   cr_xf/ci_xf  : Dict{Tuple{String,String,Int},VariableRef} (xfmr_id, "fr"/"to", k)
#   cr_sw/ci_sw  : Dict{Tuple{String,Int},    VariableRef}  (sw_id,   conductor_pos)

"Declare `vr`/`vi` voltage variables at every bus terminal; fix grounded terminals to 0."
function _add_voltage_variables!(model, bus_terminals, grounded)
    vr = Dict{Tuple{String,String}, JuMP.VariableRef}()
    vi = Dict{Tuple{String,String}, JuMP.VariableRef}()

    for (bid, terminals) in bus_terminals
        for t in terminals
            key = (bid, t)
            if (bid, t) in grounded
                vr[key] = @variable(model, base_name = "vr_$(bid)_$(t)")
                vi[key] = @variable(model, base_name = "vi_$(bid)_$(t)")
                fix(vr[key], 0.0; force=true)
                fix(vi[key], 0.0; force=true)
            else
                vr[key] = @variable(model, base_name = "vr_$(bid)_$(t)")
                vi[key] = @variable(model, base_name = "vi_$(bid)_$(t)")
            end
        end
    end
    vr, vi
end

"""
    _add_ground_variables!(model, grounded) -> (cr_gnd, ci_gnd)

Declare `cr_gnd`/`ci_gnd`, a free ground-injection current per perfectly grounded
`(bus, terminal)`. The terminal voltage is fixed to 0 (the ground reference); this
current is the conductor current that flows into/out of earth at that terminal. It
is the degree of freedom KCL uses to balance whatever the connected branches push
into the node — without it, a grounded terminal whose return path is earth (a
shunt, or another ground) rather than a neutral wire has no way to carry current,
forcing it (and the load that needs it) to zero.
"""
function _add_ground_variables!(model, grounded)
    cr_gnd = Dict{Tuple{String,String}, JuMP.VariableRef}()
    ci_gnd = Dict{Tuple{String,String}, JuMP.VariableRef}()
    for (bid, t) in grounded
        cr_gnd[(bid,t)] = @variable(model, base_name = "cr_gnd_$(bid)_$(t)")
        ci_gnd[(bid,t)] = @variable(model, base_name = "ci_gnd_$(bid)_$(t)")
    end
    cr_gnd, ci_gnd
end

"Declare `cr_fr`/`ci_fr` series current variables for each line conductor.
`cr_to`/`ci_to` are returned as `AffExpr` aliases equal to `-cr_fr` — there
is only one independent series current per branch."
function _add_line_variables!(model, net)
    cr_fr = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    ci_fr = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    cr_to = Dict{Tuple{String,Int}, JuMP.AffExpr}()
    ci_to = Dict{Tuple{String,Int}, JuMP.AffExpr}()

    for (lid, line) in get(net, "line", Dict())
        n_c = length(get(line, "terminal_map_from", String[]))
        for k in 1:n_c
            cr_fr[(lid,k)] = @variable(model, base_name = "cr_fr_$(lid)_$(k)")
            ci_fr[(lid,k)] = @variable(model, base_name = "ci_fr_$(lid)_$(k)")
            cr_to[(lid,k)] = JuMP.AffExpr(0.0, cr_fr[(lid,k)] => -1.0)
            ci_to[(lid,k)] = JuMP.AffExpr(0.0, ci_fr[(lid,k)] => -1.0)
        end
    end

    cr_fr, ci_fr, cr_to, ci_to
end

"Declare `cr_sw`/`ci_sw` switch current variables; fix open-switch currents to 0."
function _add_switch_variables!(model, net)
    cr_sw = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    ci_sw = Dict{Tuple{String,Int}, JuMP.VariableRef}()

    for (sid, sw) in get(net, "switch", Dict())
        is_open = get(sw, "open_switch", false)
        n_c = length(get(sw, "terminal_map_from", String[]))
        for k in 1:n_c
            cr_sw[(sid,k)] = @variable(model, base_name = "cr_sw_$(sid)_$(k)")
            ci_sw[(sid,k)] = @variable(model, base_name = "ci_sw_$(sid)_$(k)")
            if is_open
                fix(cr_sw[(sid,k)], 0.0; force=true)
                fix(ci_sw[(sid,k)], 0.0; force=true)
            end
        end
    end
    cr_sw, ci_sw
end

"Declare `crd`/`cid` load current variables (one per phase conductor; neutral excluded)."
function _add_load_variables!(model, net)
    crd = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    cid = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    nlabels = BMOPFTools._neutral_labels(net)

    for (lid, load) in get(net, "load", Dict())
        tm  = Vector{String}(get(load, "terminal_map", String[]))
        cfg = get(load, "configuration", "WYE")
        # A two-terminal SINGLE_PHASE load is one branch, including when both
        # terminals are phase conductors. Its one current is injected with
        # opposite signs at the two endpoints by `_add_load_constraints!`.
        # Counting both endpoints here used to create an unused second complex
        # coordinate for phase-to-phase loads.
        n_ph = if cfg == "SINGLE_PHASE" && length(tm) == 2
            1
        elseif cfg == "DELTA"
            length(tm)
        else
            length(_phase_positions(tm, nlabels))
        end
        for k in 1:n_ph
            crd[(lid,k)] = @variable(model, base_name = "crd_$(lid)_$(k)")
            cid[(lid,k)] = @variable(model, base_name = "cid_$(lid)_$(k)")
        end
    end
    crd, cid
end

"Declare `crg`/`cig` generator current variables (one per phase conductor; neutral excluded)."
function _add_generator_variables!(model, net)
    crg = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    cig = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    nlabels = BMOPFTools._neutral_labels(net)

    for (gid, gen) in get(net, "generator", Dict())
        tm  = Vector{String}(get(gen, "terminal_map", String[]))
        cfg = get(gen, "configuration", "WYE")
        n_ph = cfg == "DELTA" ? length(tm) : length(_phase_positions(tm, nlabels))
        for k in 1:n_ph
            crg[(gid,k)] = @variable(model, base_name = "crg_$(gid)_$(k)")
            cig[(gid,k)] = @variable(model, base_name = "cig_$(gid)_$(k)")
        end
    end
    crg, cig
end

"Declare `cr_src`/`ci_src` voltage-source slack current variables (one per phase
conductor; neutral excluded — the neutral carries the summed return current)."
function _add_source_variables!(model, net)
    cr_src = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    ci_src = Dict{Tuple{String,Int}, JuMP.VariableRef}()
    nlabels = BMOPFTools._neutral_labels(net)

    for (sid, vs) in get(net, "voltage_source", Dict())
        tm   = Vector{String}(get(vs, "terminal_map", String[]))
        cfg  = get(vs, "configuration", "WYE")
        n_ph = cfg == "DELTA" ? length(tm) : length(_phase_positions(tm, nlabels))
        for k in 1:n_ph
            cr_src[(sid,k)] = @variable(model, base_name = "cr_src_$(sid)_$(k)")
            ci_src[(sid,k)] = @variable(model, base_name = "ci_src_$(sid)_$(k)")
        end
    end
    cr_src, ci_src
end

"Declare `cr_xf`/`ci_xf` transformer branch current variables for both winding sides."
function _add_transformer_variables!(model, net)
    cr_xf = Dict{Tuple{String,String,Int}, JuMP.VariableRef}()
    ci_xf = Dict{Tuple{String,String,Int}, JuMP.VariableRef}()
    nlabels = BMOPFTools._neutral_labels(net)

    xfmr_dict = get(net, "transformer", Dict())
    for subtype in BMOPFTools.TRANSFORMER_SUBTYPES
        for (tid, xfmr) in get(xfmr_dict, subtype, Dict())
            tmfr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
            tmto = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
            if subtype == "single_phase_autotransformer"
                # Single-phase autotransformer: one series current per regulating
                # winding (winding pairs, so a line-to-line map is ONE winding, not
                # two). A galvanic bond ties the from/to reference terminals (the
                # shared SVR bushing — the neutral for L-N, the common phase for
                # L-L); its bond current is the extra "fr" index (analogous to the
                # open-delta straight-through wire). Allocated only when both sides
                # have a winding reference q (a neutral or a second phase).
                pf = BMOPFTools._xfmr_winding_pairs(tmfr, nlabels)
                pt = BMOPFTools._xfmr_winding_pairs(tmto, nlabels)
                has_both_q = !isempty(pf) && !isempty(pt) &&
                             pf[1][2] !== nothing && pt[1][2] !== nothing
                n_fr = length(pf) + (has_both_q ? 1 : 0)
                n_to = length(pt)
            elseif subtype == "single_phase"
                # YY single-phase: one current variable per winding pair. A
                # line-to-neutral and a line-to-line map are both ONE winding.
                n_fr = length(BMOPFTools._xfmr_winding_pairs(tmfr, nlabels))
                n_to = length(BMOPFTools._xfmr_winding_pairs(tmto, nlabels))
            elseif subtype == "open_delta_regulator"
                # Two line-to-line regulating windings → one series current per
                # regulator on each side (indices 1,2). A 3rd "fr" current models
                # the galvanic straight-through wire on the shared phase (the
                # common-neutral connection, V_shared_fr = V_shared_to). The "to"
                # side needs only the two regulator currents.
                n_fr = 3
                n_to = 2
            else
                n_fr = length(tmfr)
                n_to = length(tmto)
            end
            for k in 1:n_fr
                cr_xf[(tid,"fr",k)] = @variable(model, base_name = "cr_xf_$(tid)_fr_$(k)")
                ci_xf[(tid,"fr",k)] = @variable(model, base_name = "ci_xf_$(tid)_fr_$(k)")
            end
            for k in 1:n_to
                cr_xf[(tid,"to",k)] = @variable(model, base_name = "cr_xf_$(tid)_to_$(k)")
                ci_xf[(tid,"to",k)] = @variable(model, base_name = "ci_xf_$(tid)_to_$(k)")
            end
        end
    end
    cr_xf, ci_xf
end

"""
    _add_tap_variables!(model, net) -> Dict

Declare one continuous tap variable per FREE transformer tap, equal to the effective
from→to ratio coefficient used by the winding constraints (`N` for `single_phase`,
`n_eff` otherwise). Fixed taps allocate nothing (so the constraint set is unchanged).
Keyed by `tid` for the one-tap subtypes and by `(tid, k)` for the open-delta
per-regulator taps. Bounded and warm-started at the nominal coefficient.
"""
function _add_tap_variables!(model, net)
    tap = Dict{Any, JuMP.VariableRef}()
    xfmr_dict = get(net, "transformer", Dict())
    for subtype in ("single_phase", "center_tap", "wye_delta", "delta_wye",
                    "single_phase_autotransformer")
        for (tid, xfmr) in get(xfmr_dict, subtype, Dict())
            xfmr isa Dict || continue
            spec = BMOPFTools._xfmr_ratio_coeff_bounds(subtype, xfmr)
            spec === nothing && continue
            lo, hi, start = spec
            v = @variable(model, base_name = "tap_$(tid)",
                          lower_bound = lo, upper_bound = hi)
            JuMP.set_start_value(v, start)
            tap[tid] = v
        end
    end
    for (tid, xfmr) in get(xfmr_dict, "open_delta_regulator", Dict())
        xfmr isa Dict || continue
        for k in 1:2
            spec = BMOPFTools._odr_ratio_coeff_bounds(xfmr, k)
            spec === nothing && continue
            lo, hi, start = spec
            v = @variable(model, base_name = "tap_$(tid)_$(k)",
                          lower_bound = lo, upper_bound = hi)
            JuMP.set_start_value(v, start)
            tap[(tid, k)] = v
        end
    end
    tap
end

# Canonical 3-phase start angle (rad) for a terminal NAME under any of the
# supported naming conventions ("1"/"2"/"3"/"4", "a"/"b"/"c"/"n", "L1"…"N"),
# resolved through the same table `to_pmd` uses. Unknown names fall back to 0
# (co-phasal) — the previous behaviour, but now only for genuinely unknown
# conventions rather than for everything that wasn't literally "1"/"2"/"3".
const _CANONICAL_PHASE_ANGLE = Dict{Int,Float64}(
    1 => 0.0, 2 => -2.0944, 3 => 2.0944, 4 => 0.0)

function _canonical_start_angle(t::AbstractString)::Float64
    i = get(BMOPFTools._TERMINAL_NAME_TO_INT, lowercase(String(t)), nothing)
    i === nothing ? 0.0 : _CANONICAL_PHASE_ANGLE[i]
end

# Angle for terminal `t`: the actual source angle when the source declares it,
# else the canonical 120°-spaced start for its naming convention.
_start_angle(t_angle::Dict{String,Float64}, t::AbstractString)::Float64 =
    get(t_angle, String(t)) do
        _canonical_start_angle(t)
    end

"""
    _split_phase_init_angles(net, base_angle) -> Dict{String,Dict{String,Float64}}

For every split-phase galvanic zone (fed by a `center_tap` transformer, per
`BMOPFTools._classify_zones`), return per-bus, per-terminal warm-start angles in
which the two legs are **anti-phase**: leg-1 at θ and leg-2 at θ+π, where θ is the
feeding MV phase angle (looked up in `base_angle` from the centre-tap's from-side
phase terminal). The neutral is 0. Applied across every bus in the zone, since the
LV section keeps the centre-tap leg terminal names. Buses not in a split-phase zone
are absent (callers fall back to the canonical 3-phase angles).
"""
function _split_phase_init_angles(net, base_angle::Dict{String,Float64})
    out   = Dict{String,Dict{String,Float64}}()
    buses = get(net, "bus", Dict())
    cts   = get(get(net, "transformer", Dict()), "center_tap", Dict())

    for z in BMOPFTools._classify_zones(net)
        z.topology == :split_phase || continue
        ctid = nothing
        for (sub, id) in z.feed
            sub == "center_tap" && (ctid = id; break)
        end
        ctid === nothing && continue
        ct = get(cts, ctid, nothing); ct isa Dict || continue

        tmfr = string.(get(ct, "terminal_map_from", String[]))
        tmto = string.(get(ct, "terminal_map_to",   String[]))
        nt_fr = BMOPFTools._neutral_terminal(get(buses, get(ct, "bus_from", ""), Dict()))
        nt_to = BMOPFTools._neutral_terminal(get(buses, get(ct, "bus_to",   ""), Dict()))

        ph_fr = findfirst(t -> t != nt_fr, tmfr)
        θ     = ph_fr === nothing ? 0.0 : _start_angle(base_angle, tmfr[ph_fr])

        legs = [t for t in tmto if t != nt_to]
        length(legs) >= 2 || continue
        leg1, leg2 = legs[1], legs[end]

        for bid in z.buses
            d = get!(out, bid, Dict{String,Float64}())
            d[leg1] = θ
            d[leg2] = θ + π
            nt = BMOPFTools._neutral_terminal(get(buses, bid, Dict()))
            nt !== nothing && (d[nt] = 0.0)
        end
    end
    out
end

"""
    _set_voltage_start_values!(vars, net, bus_terminals, grounded)

Provide Ipopt with phase-correct initial voltage estimates.

For every non-grounded, non-fixed terminal the start value is set to
`v_nom × exp(j × angle)` where `v_nom` and `angle` are read from the
network's first voltage source.  Terminals that are not in the source's
terminal_map use the canonical 3-phase angles (0°, −120°, +120°).
The neutral terminal is initialised at 0.

Without this, Ipopt starts from vr=vi=0 and fails to navigate into the
correct region of the feasible set for multi-phase (complex-voltage)
problems.
"""
function _set_voltage_start_values!(vars, net, bus_terminals, grounded)
    vr = vars[:vr]; vi = vars[:vi]
    nlabels = BMOPFTools._neutral_labels(net)

    # Source-declared angles keyed by terminal name; any terminal the source
    # does not declare falls back to the canonical 120°-spaced start for its
    # naming convention via `_start_angle` (works for "1"/"2"/"3", "a"/"b"/"c",
    # "L1"/"L2"/"L3" alike — previously only literal "1"/"2"/"3" got angles,
    # every other convention started degenerately co-phasal).
    t_angle = Dict{String,Float64}()
    v_nom = 0.0

    for (_, vs) in get(net, "voltage_source", Dict())
        tm   = Vector{String}(get(vs, "terminal_map", String[]))
        vmag = Float64.(get(vs, "v_magnitude", Float64[]))
        vang = Float64.(get(vs, "v_angle",     Float64[]))
        for (k, t) in enumerate(tm)
            k ≤ length(vmag) && (v_nom = max(v_nom, vmag[k]))
            k ≤ length(vang) && (t_angle[t] = vang[k])
        end
        break   # first source is enough
    end
    v_nom == 0.0 && (v_nom = 1.0)   # degenerate fallback

    sp = _split_phase_init_angles(net, t_angle)   # anti-phase legs for split-phase zones

    for (bid, terminals) in bus_terminals
        nt = BMOPFTools._neutral_terminal(terminals, nlabels)
        for t in terminals
            (bid, t) in grounded && continue   # fixed at 0 — skip
            key = (bid, t)
            if t == nt
                JuMP.set_start_value(vr[key], 0.0)
                JuMP.set_start_value(vi[key], 0.0)
            else
                ang = haskey(sp, bid) && haskey(sp[bid], t) ?
                      sp[bid][t] : _start_angle(t_angle, t)
                JuMP.set_start_value(vr[key], v_nom * cos(ang))
                JuMP.set_start_value(vi[key], v_nom * sin(ang))
            end
        end
    end
end

"""
    _set_level_aware_start_values!(vars, net, bus_terminals, grounded)

Like `_set_voltage_start_values!` but uses per-bus nominal voltages derived
from the BFS voltage propagation (`_assign_nominal_voltages`). This correctly
initialises LV buses at ~250 V rather than at the source voltage (~6350 V),
reducing attraction to a degenerate high-voltage local minimum when the case
supplies no useful voltage bounds.
"""
function _set_level_aware_start_values!(vars, net, bus_terminals, grounded)
    vr = vars[:vr]; vi = vars[:vi]
    nlabels = BMOPFTools._neutral_labels(net)

    # Source-declared angles; other terminals get the canonical 120° start
    # for their naming convention via `_start_angle` (see above).
    t_angle = Dict{String,Float64}()

    for (_, vs) in get(net, "voltage_source", Dict())
        tm   = Vector{String}(get(vs, "terminal_map", String[]))
        vang = Float64.(get(vs, "v_angle", Float64[]))
        for (k, t) in enumerate(tm)
            k ≤ length(vang) && (t_angle[t] = vang[k])
        end
        break
    end

    v_nom_by_bus = BMOPFTools._assign_nominal_voltages(net)

    sp = _split_phase_init_angles(net, t_angle)   # anti-phase legs for split-phase zones

    for (bid, terminals) in bus_terminals
        nt    = BMOPFTools._neutral_terminal(terminals, nlabels)
        v_nom = get(v_nom_by_bus, bid, 1000.0)
        for t in terminals
            (bid, t) in grounded && continue
            key = (bid, t)
            if t == nt
                JuMP.set_start_value(vr[key], 0.0)
                JuMP.set_start_value(vi[key], 0.0)
            else
                ang = haskey(sp, bid) && haskey(sp[bid], t) ?
                      sp[bid][t] : _start_angle(t_angle, t)
                JuMP.set_start_value(vr[key], v_nom * cos(ang))
                JuMP.set_start_value(vi[key], v_nom * sin(ang))
            end
        end
    end
end

"""
    _set_topology_aware_voltage_start_values!(vars, net, bus_terminals, grounded)

Transport source phasors through the complete idealized network topology and
overwrite the voltage warm start with the resulting bus-terminal phasors.

The transport system is assembled from the same zero-current voltage relations
used by the OPF formulation: conductor maps for lines and closed switches,
winding-pair equations for single-phase transformers and regulators,
anti-series half windings for center-tap transformers, connection-aware Yd/Dy
relations, and coil-voltage relations for general WYE/DELTA n-winding units.
It is solved in voltage-normalized coordinates, so SI, classic per-unit, and
custom consistent bases select the same physical point.

Source and grounding rows are strongest, ideal network equations are next, and
a weak canonical prior resolves genuinely free common-mode coordinates. The
prior is not a claim that every bus is balanced; it only selects a deterministic
representative where topology and source data leave a gauge free.
"""
function _set_topology_aware_voltage_start_values!(
        vars, net, bus_terminals, grounded)
    vr = vars[:vr]; vi = vars[:vi]
    keys_all = sort!(collect(keys(vr)); by=repr)
    isempty(keys_all) && return (
        applied=false, equation_count=0, coordinate_count=0,
        maximum_normalized_physics_residual=0.0,
        equation_count_by_kind=Dict{String,Int}(),
        maximum_normalized_residual_by_kind=Dict{String,Float64}(),
        transformer_component_count_by_subtype=Dict{String,Int}(),
        unsupported_transformer_subtypes=String[],
    )
    position = Dict(key => k for (k, key) in enumerate(keys_all))
    nominal = BMOPFTools._assign_nominal_voltages(net)
    nlabels = BMOPFTools._neutral_labels(net)
    scale(key) = begin
        value = Float64(get(nominal, key[1], 1.0))
        isfinite(value) && value > 0 ? value : 1.0
    end

    rows = Vector{Tuple{Dict{Int,Float64},ComplexF64,Symbol,Float64}}()
    function add_equation!(raw_terms, rhs::Number, kind::Symbol;
                           weight::Float64=1.0e6)
        terms = Dict{Int,Float64}()
        for (key, coefficient) in raw_terms
            haskey(position, key) || continue
            value = Float64(coefficient) * scale(key)
            terms[position[key]] = get(terms, position[key], 0.0) + value
        end
        filter!(pair -> !iszero(last(pair)), terms)
        isempty(terms) && return false
        row_norm = sqrt(sum(abs2, values(terms)))
        row_norm > 0 || return false
        push!(rows, (terms, ComplexF64(rhs), kind, weight / row_norm))
        return true
    end
    function add_coil!(terms, bus, terminal_map, pair, coefficient)
        p, q = pair
        p <= length(terminal_map) || return terms
        kp = (String(bus), String(terminal_map[p]))
        push!(terms, kp => coefficient)
        if q !== nothing && q <= length(terminal_map)
            kq = (String(bus), String(terminal_map[q]))
            push!(terms, kq => -coefficient)
        end
        return terms
    end

    # Exact physical anchors.
    for key in grounded
        add_equation!([key => 1.0], 0.0, :ground; weight=1.0e8)
    end
    for (_, source) in sort!(collect(get(net, "voltage_source", Dict())); by=first)
        bus = String(get(source, "bus", ""))
        terminals = string.(get(source, "terminal_map", String[]))
        magnitudes = Float64.(get(source, "v_magnitude", Float64[]))
        angles = Float64.(get(source, "v_angle", Float64[]))
        for k in eachindex(terminals)
            k <= length(magnitudes) || continue
            angle_value = k <= length(angles) ? angles[k] :
                _canonical_start_angle(terminals[k])
            add_equation!([(bus, terminals[k]) => 1.0],
                magnitudes[k] * cis(angle_value), :source; weight=1.0e8)
        end
    end

    # Galvanic conductor transport. Terminal order, not label spelling, owns the
    # phase mapping, which covers a/b/c ↔ 1/2/3 and single-phase laterals.
    for family in ("line", "switch")
        for (_, branch) in sort!(collect(get(net, family, Dict())); by=first)
            family == "switch" && Bool(get(branch, "open_switch", false)) && continue
            bus_from = String(get(branch, "bus_from", ""))
            bus_to = String(get(branch, "bus_to", ""))
            map_from = string.(get(branch, "terminal_map_from", String[]))
            map_to = string.(get(branch, "terminal_map_to", String[]))
            for k in 1:min(length(map_from), length(map_to))
                add_equation!([
                    (bus_from, map_from[k]) => 1.0,
                    (bus_to, map_to[k]) => -1.0,
                ], 0.0, :galvanic)
            end
        end
    end

    transformers = get(net, "transformer", Dict())
    supported_transformer_subtypes = Set([
        "single_phase", "center_tap", "wye_delta", "delta_wye",
        "single_phase_autotransformer", "open_delta_regulator", "n_winding",
    ])
    transformer_component_count_by_subtype = Dict(
        String(subtype) => length(components)
        for (subtype, components) in transformers if components isa AbstractDict
    )
    unsupported_transformer_subtypes = sort!([
        String(subtype) for (subtype, components) in transformers
        if components isa AbstractDict && !isempty(components) &&
           !(String(subtype) in supported_transformer_subtypes)
    ])

    # Ordinary per-coil YY transformers, including an off-three-phase
    # single-phase branch whose phase is determined by its from-side mapping.
    for (tid, transformer) in sort!(collect(get(transformers, "single_phase", Dict())); by=first)
        bus_from = String(get(transformer, "bus_from", ""))
        bus_to = String(get(transformer, "bus_to", ""))
        map_from = string.(get(transformer, "terminal_map_from", String[]))
        map_to = string.(get(transformer, "terminal_map_to", String[]))
        pairs_from = BMOPFTools._xfmr_winding_pairs(map_from, nlabels)
        pairs_to = BMOPFTools._xfmr_winding_pairs(map_to, nlabels)
        ratio = BMOPFTools._xfmr_turns_ratio(transformer) *
            BMOPFTools._xfmr_tap_mult(transformer)
        for k in 1:min(length(pairs_from), length(pairs_to))
            terms = Pair{Tuple{String,String},Float64}[]
            add_coil!(terms, bus_from, map_from, pairs_from[k], 1.0)
            add_coil!(terms, bus_to, map_to, pairs_to[k], -ratio)
            add_equation!(terms, 0.0, :single_phase_transformer)
        end
    end

    # Split-phase: both LV half-windings are referred to the same HV coil, but
    # winding 3 is dotted at the centre tap and therefore has reversed polarity.
    for (tid, transformer) in sort!(collect(get(transformers, "center_tap", Dict())); by=first)
        bus_from = String(get(transformer, "bus_from", ""))
        bus_to = String(get(transformer, "bus_to", ""))
        map_from = string.(get(transformer, "terminal_map_from", String[]))
        map_to = string.(get(transformer, "terminal_map_to", String[]))
        length(map_from) == 2 && length(map_to) == 3 || continue
        ratio = BMOPFTools._xfmr_turns_ratio(transformer) *
            BMOPFTools._xfmr_tap_mult(transformer)
        for (lv_pair, sign) in (((1, 2), -ratio), ((3, 2), ratio))
            terms = Pair{Tuple{String,String},Float64}[]
            add_coil!(terms, bus_from, map_from, (1, 2), 1.0)
            add_coil!(terms, bus_to, map_to, lv_pair, sign)
            add_equation!(terms, 0.0, :center_tap_transformer)
        end
    end

    # Yd/Dy ideal voltage transformations. Solving all rows simultaneously
    # makes the propagation direction independent of transformer orientation.
    for subtype in ("wye_delta", "delta_wye")
        for (tid, transformer) in sort!(collect(get(transformers, subtype, Dict())); by=first)
            wye_from = subtype == "wye_delta"
            bus_wye = String(get(transformer,
                wye_from ? "bus_from" : "bus_to", ""))
            bus_delta = String(get(transformer,
                wye_from ? "bus_to" : "bus_from", ""))
            map_wye = string.(get(transformer,
                wye_from ? "terminal_map_from" : "terminal_map_to", String[]))
            map_delta = string.(get(transformer,
                wye_from ? "terminal_map_to" : "terminal_map_from", String[]))
            phases = BMOPFTools._phase_positions(map_wye, nlabels)
            neutral = BMOPFTools._neutral_pos(map_wye, nlabels)
            nphase = min(length(phases), length(map_delta))
            nphase == 0 && continue
            nominal_ratio = BMOPFTools._xfmr_turns_ratio(transformer) *
                BMOPFTools._xfmr_tap_mult(transformer)
            effective = wye_from ? sqrt(3.0) / nominal_ratio :
                nominal_ratio * sqrt(3.0)
            for k in 1:nphase
                other = wye_from ? mod1(k + 1, nphase) : mod1(k - 1, nphase)
                terms = Pair{Tuple{String,String},Float64}[
                    (bus_delta, map_delta[k]) => 1.0,
                    (bus_delta, map_delta[other]) => -1.0,
                    (bus_wye, map_wye[phases[k]]) => -effective,
                ]
                neutral === nothing || push!(terms,
                    (bus_wye, map_wye[neutral]) => effective)
                add_equation!(terms, 0.0, Symbol(subtype))
            end
        end
    end

    # Single-phase and open-delta regulators use their actual line-neutral or
    # line-line winding relations plus their galvanic common-bushing ties.
    for (tid, transformer) in sort!(collect(get(transformers,
            "single_phase_autotransformer", Dict())); by=first)
        bus_from = String(get(transformer, "bus_from", ""))
        bus_to = String(get(transformer, "bus_to", ""))
        map_from = string.(get(transformer, "terminal_map_from", String[]))
        map_to = string.(get(transformer, "terminal_map_to", String[]))
        pairs_from = BMOPFTools._xfmr_winding_pairs(map_from, nlabels)
        pairs_to = BMOPFTools._xfmr_winding_pairs(map_to, nlabels)
        (isempty(pairs_from) || isempty(pairs_to)) && continue
        ratio = BMOPFTools._autotransformer_ratio(transformer)
        terms = Pair{Tuple{String,String},Float64}[]
        add_coil!(terms, bus_from, map_from, pairs_from[1], 1.0)
        add_coil!(terms, bus_to, map_to, pairs_to[1], -ratio)
        add_equation!(terms, 0.0, :single_phase_autotransformer)
        q_from = pairs_from[1][2]; q_to = pairs_to[1][2]
        if q_from !== nothing && q_to !== nothing
            add_equation!([
                (bus_from, map_from[q_from]) => 1.0,
                (bus_to, map_to[q_to]) => -1.0,
            ], 0.0, :galvanic)
        end
    end
    open_delta_pairs = Dict(
        "ABBC" => ((1, 2), (2, 3)),
        "BCAC" => ((2, 3), (1, 3)),
        "CABA" => ((3, 1), (2, 1)),
    )
    for (tid, transformer) in sort!(collect(get(transformers,
            "open_delta_regulator", Dict())); by=first)
        bus_from = String(get(transformer, "bus_from", ""))
        bus_to = String(get(transformer, "bus_to", ""))
        map_from = string.(get(transformer, "terminal_map_from", String[]))
        map_to = string.(get(transformer, "terminal_map_to", String[]))
        phases_from = BMOPFTools._phase_positions(map_from, nlabels)
        phases_to = BMOPFTools._phase_positions(map_to, nlabels)
        pairs = get(open_delta_pairs,
            uppercase(strip(String(get(transformer, "connection", "")))), nothing)
        pairs === nothing && continue
        length(phases_from) >= 3 && length(phases_to) >= 3 || continue
        taps = Float64.(get(transformer, "tap_ratio", Float64[]))
        regulator_type = String(get(transformer, "regulator_type", "B"))
        for (j, (p, q)) in enumerate(pairs)
            tap = length(taps) >= j ? taps[j] : 1.0
            ratio = BMOPFTools._autotransformer_neff(tap, regulator_type)
            terms = Pair{Tuple{String,String},Float64}[
                (bus_from, map_from[phases_from[p]]) => 1.0,
                (bus_from, map_from[phases_from[q]]) => -1.0,
                (bus_to, map_to[phases_to[p]]) => -ratio,
                (bus_to, map_to[phases_to[q]]) => ratio,
            ]
            add_equation!(terms, 0.0, :open_delta_regulator)
        end
        shared = intersect(collect(first(pairs)), collect(last(pairs)))
        if length(shared) == 1
            p = only(shared)
            add_equation!([
                (bus_from, map_from[phases_from[p]]) => 1.0,
                (bus_to, map_to[phases_to[p]]) => -1.0,
            ], 0.0, :galvanic)
        end
    end

    # General n-winding WYE/DELTA units, including delta_roll vector groups.
    for (tid, transformer) in sort!(collect(get(transformers, "n_winding", Dict())); by=first)
        windings = BMOPFTools._nw_windings(transformer)
        length(windings) >= 2 || continue
        ratios = BMOPFTools._nw_turns_ratios(transformer)
        phases_reference, _ =
            BMOPFTools._nw_phase_terminals(windings[1].terminal_map)
        for phase in eachindex(phases_reference)
            function winding_coil_terms!(terms, winding, phase_index, coefficient)
                phases, neutral = BMOPFTools._nw_phase_terminals(
                    winding.terminal_map)
                phase_index <= length(phases) || return
                push!(terms, (winding.bus, phases[phase_index]) => coefficient)
                if winding.connection == "DELTA"
                    other = BMOPFTools._nw_delta_other(
                        phase_index, length(phases), winding.delta_roll)
                    push!(terms, (winding.bus, phases[other]) => -coefficient)
                elseif neutral !== nothing
                    push!(terms, (winding.bus, neutral) => -coefficient)
                end
            end
            for k in 2:length(windings)
                terms = Pair{Tuple{String,String},Float64}[]
                winding_coil_terms!(terms, windings[1], phase, 1.0)
                winding_coil_terms!(terms, windings[k], phase, -1.0 / ratios[k])
                add_equation!(terms, 0.0, :n_winding_transformer)
            end
        end
    end

    # Weak deterministic prior for degrees of freedom not fixed by the ideal
    # transport equations (notably floating delta common mode).
    for key in keys_all
        terminals = get(bus_terminals, key[1], String[])
        neutral = BMOPFTools._neutral_terminal(terminals, nlabels)
        target = key[2] == neutral ? 0.0 + 0.0im :
            cis(_canonical_start_angle(key[2]))
        add_equation!([key => 1.0], scale(key) * target, :prior; weight=1.0)
    end

    row_indices = Int[]; column_indices = Int[]; coefficients = Float64[]
    right_hand_side = ComplexF64[]
    for (row, (terms, rhs, _, multiplier)) in enumerate(rows)
        for (column, coefficient) in terms
            push!(row_indices, row)
            push!(column_indices, column)
            push!(coefficients, multiplier * coefficient)
        end
        push!(right_hand_side, multiplier * rhs)
    end
    matrix = sparse(row_indices, column_indices, coefficients,
                    length(rows), length(keys_all))
    equation_count_by_kind = Dict{String,Int}()
    for (_, _, kind, _) in rows
        kind == :prior && continue
        label = string(kind)
        equation_count_by_kind[label] =
            get(equation_count_by_kind, label, 0) + 1
    end
    solution = try
        matrix \ right_hand_side
    catch
        return (
            applied=false,
            equation_count=count(row -> row[3] != :prior, rows),
            coordinate_count=length(keys_all),
            maximum_normalized_physics_residual=Inf,
            equation_count_by_kind,
            maximum_normalized_residual_by_kind=Dict{String,Float64}(),
            transformer_component_count_by_subtype,
            unsupported_transformer_subtypes,
        )
    end
    all(value -> isfinite(real(value)) && isfinite(imag(value)), solution) ||
        return (
            applied=false,
            equation_count=count(row -> row[3] != :prior, rows),
            coordinate_count=length(keys_all),
            maximum_normalized_physics_residual=Inf,
            equation_count_by_kind,
            maximum_normalized_residual_by_kind=Dict{String,Float64}(),
            transformer_component_count_by_subtype,
            unsupported_transformer_subtypes,
        )

    for (column, key) in enumerate(keys_all)
        key in grounded && continue
        value = scale(key) * solution[column]
        JuMP.set_start_value(vr[key], real(value))
        JuMP.set_start_value(vi[key], imag(value))
    end
    maximum_residual = 0.0
    maximum_residual_by_kind = Dict{String,Float64}()
    for (terms, rhs, kind, _) in rows
        kind == :prior && continue
        lhs = sum(coefficient * solution[column]
                  for (column, coefficient) in terms; init=0.0 + 0.0im)
        denominator = max(abs(rhs),
            sqrt(sum(abs2, values(terms))) * max(norm(solution, Inf), 1.0),
            eps(Float64))
        residual = abs(lhs - rhs) / denominator
        maximum_residual = max(maximum_residual, residual)
        label = string(kind)
        maximum_residual_by_kind[label] = max(
            get(maximum_residual_by_kind, label, 0.0), residual,
        )
    end
    return (
        applied=true,
        equation_count=count(row -> row[3] != :prior, rows),
        coordinate_count=length(keys_all),
        maximum_normalized_physics_residual=maximum_residual,
        equation_count_by_kind,
        maximum_normalized_residual_by_kind=maximum_residual_by_kind,
        transformer_component_count_by_subtype,
        unsupported_transformer_subtypes,
    )
end

"""
    _set_yd_dy_start_values!(vars, net, grounded; set_voltage_starts=true)

Override start values for delta-bus terminals of Yd/Dy transformers.

The generic `_set_level_aware_start_values!` assigns angles from the source
terminal map ("1"→0°, "2"→−120°, "3"→+120°), which is correct for wye buses
but wrong for the floating delta secondary.  Here we propagate the ideal Yd/Dy
voltage loop to compute physically correct starting angles for the delta bus,
which guides Ipopt to the correct local minimum.
"""
function _set_yd_dy_start_values!(
        vars, net, grounded; set_voltage_starts::Bool=true)
    vr = vars[:vr]; vi = vars[:vi]
    cr_xf = vars[:cr_xf]; ci_xf = vars[:ci_xf]
    xfmr_dict = get(net, "transformer", Dict())
    nlabels = BMOPFTools._neutral_labels(net)
    start_component(variable, fallback=0.0) = something(
        JuMP.start_value(variable), fallback)
    start_complex(real_variable, imag_variable) = complex(
        start_component(real_variable), start_component(imag_variable))
    for subtype in ("wye_delta", "delta_wye")
        for (tid, xfmr) in get(xfmr_dict, subtype, Dict())
            wye_is_from = (subtype == "wye_delta")
            b_wye = wye_is_from ? get(xfmr, "bus_from", "") : get(xfmr, "bus_to", "")
            b_del = wye_is_from ? get(xfmr, "bus_to",   "") : get(xfmr, "bus_from", "")
            tm_wye = Vector{String}(wye_is_from ?
                get(xfmr, "terminal_map_from", String[]) :
                get(xfmr, "terminal_map_to",   String[]))
            tm_del = Vector{String}(wye_is_from ?
                get(xfmr, "terminal_map_to",   String[]) :
                get(xfmr, "terminal_map_from", String[]))
            N     = Float64(get(xfmr, "v_nom_from", 1.0)) / Float64(get(xfmr, "v_nom_to", 1.0))
            n_eff = wye_is_from ? sqrt(3) / N : N * sqrt(3)
            ph_idx = BMOPFTools._phase_positions(tm_wye, nlabels)
            n_pos  = BMOPFTools._neutral_pos(tm_wye, nlabels)
            side_wye = wye_is_from ? "fr" : "to"
            side_del = wye_is_from ? "to" : "fr"
            n_ph   = length(tm_del)

            # Read wye neutral start value (zero if no neutral or grounded). A
            # grounded neutral (incl. a source-pinned neutral) is fixed to 0 with
            # no start value, so JuMP.start_value would return `nothing` — treat it
            # as 0 explicitly.
            Vn = if n_pos !== nothing && !((b_wye, tm_wye[n_pos]) in grounded)
                start_complex(vr[(b_wye, tm_wye[n_pos])],
                              vi[(b_wye, tm_wye[n_pos])])
            else
                0.0 + 0.0im
            end

            # Read wye phase start values
            Vw = [start_complex(vr[(b_wye, tm_wye[ph_idx[k]])],
                                vi[(b_wye, tm_wye[ph_idx[k]])]) for k in 1:n_ph]
            Vw_pn = Vw .- Vn

            # Find the first grounded delta terminal to anchor the propagation
            start_k = 1
            for k in 1:n_ph
                (b_del, tm_del[k]) in grounded && (start_k = k; break)
            end

            # Propagate ideal delta voltages around the loop:
            #   V_del[k] - V_del[k_next] = n_eff * Vw_pn[k]  (Yd)
            #   V_del[k] - V_del[k_prev] = n_eff * Vw_pn[k]  (Dy)
            # The anchor is the first grounded delta terminal when one exists; a
            # grounded terminal is fixed to 0 with no start value (start_value ⇒
            # `nothing`), so read it as 0 rather than via JuMP.start_value — same
            # guard as the wye neutral Vn above.
            V_del = zeros(ComplexF64, n_ph)
            V_del[start_k] = (b_del, tm_del[start_k]) in grounded ? (0.0 + 0.0im) :
                start_complex(vr[(b_del, tm_del[start_k])],
                              vi[(b_del, tm_del[start_k])])
            for step in 1:(n_ph - 1)
                k      = mod1(start_k + step - 1, n_ph)
                k_next = mod1(k, n_ph) + 1
                V_del[k_next] = V_del[k] - n_eff * Vw_pn[k]
            end

            if set_voltage_starts
                # The legacy direct propagation remains useful as a standalone
                # fallback. The staged builder disables this write after its
                # network-wide transport solve and uses this pass only to seed
                # currents from the final transported wye phasors.
                for k in 1:n_ph
                    t = tm_del[k]
                    (b_del, t) in grounded && continue
                    JuMP.set_start_value(vr[(b_del, t)], real(V_del[k]))
                    JuMP.set_start_value(vi[(b_del, t)], imag(V_del[k]))
                end
            end

            # Estimate wye winding currents from apparent power and start voltages.
            # S_rated / (sqrt(3) * V_LL) gives the nominal line current magnitude.
            # The physical direction is positive (into transformer from wye bus).
            s_rating = if wye_is_from
                Float64(get(xfmr, "_s_rating_from_pu", get(xfmr, "s_rating", 0.0)))
            else
                Float64(get(xfmr, "_s_rating_to_pu", get(xfmr, "s_rating", 0.0)))
            end
            delta_current_factor = Float64(get(
                xfmr, "_delta_to_wye_power_factor", 1.0))
            if s_rating > 0
                v_wye_start = abs(Vw_pn[1])
                I_mag = v_wye_start > 0 ? s_rating / (3 * v_wye_start) : 0.0
                for k in 1:n_ph
                    ph = ph_idx[k]
                    # Physical wye current is IN PHASE with the phase-neutral voltage
                    # (pure resistive estimate); positive = out of wye bus (load conv.)
                    Vw_hat = Vw_pn[k]
                    I_start = abs(Vw_hat) > 0 ? I_mag * conj(Vw_hat) / abs(Vw_hat) : I_mag + 0im
                    JuMP.set_start_value(cr_xf[(tid, side_wye, ph)], real(I_start))
                    JuMP.set_start_value(ci_xf[(tid, side_wye, ph)], imag(I_start))
                end
                # Delta currents from the exact normalized current coupling:
                # n_eff*(S_delta/S_wye)*I_del = -(I_wye[k]-I_wye[k_other]).
                for k in 1:n_ph
                    ph = ph_idx[k]
                    k_other = wye_is_from ?
                        ((k - 2 + n_ph) % n_ph) + 1 :  # k_prev for Yd
                        (k % n_ph) + 1                   # k_next for Dy
                    ph_other = ph_idx[k_other]
                    I_del_r = -(start_component(cr_xf[(tid, side_wye, ph)]) -
                                start_component(cr_xf[(tid, side_wye, ph_other)])) /
                               (n_eff * delta_current_factor)
                    I_del_i = -(start_component(ci_xf[(tid, side_wye, ph)]) -
                                start_component(ci_xf[(tid, side_wye, ph_other)])) /
                               (n_eff * delta_current_factor)
                    JuMP.set_start_value(cr_xf[(tid, side_del, k)], I_del_r)
                    JuMP.set_start_value(ci_xf[(tid, side_del, k)], I_del_i)
                end
                # Neutral wye current start value
                if n_pos !== nothing
                    I_n_r = -sum(start_component(cr_xf[(tid, side_wye, ph_idx[k])]) for k in 1:n_ph)
                    I_n_i = -sum(start_component(ci_xf[(tid, side_wye, ph_idx[k])]) for k in 1:n_ph)
                    JuMP.set_start_value(cr_xf[(tid, side_wye, n_pos)], I_n_r)
                    JuMP.set_start_value(ci_xf[(tid, side_wye, n_pos)], I_n_i)
                end
            end
        end
    end
end

"Declare all JuMP variables and return them in a single dict."
function _build_vars(model, net, bus_terminals, grounded)
    vr,    vi    = _add_voltage_variables!(model, bus_terminals, grounded)
    cr_fr, ci_fr,
    cr_to, ci_to = _add_line_variables!(model, net)
    cr_sw, ci_sw = _add_switch_variables!(model, net)
    crd,   cid   = _add_load_variables!(model, net)
    crg,   cig   = _add_generator_variables!(model, net)
    cr_src,ci_src= _add_source_variables!(model, net)
    cr_xf, ci_xf = _add_transformer_variables!(model, net)
    tap          = _add_tap_variables!(model, net)
    cr_nw, ci_nw = _add_nwinding_variables!(model, net)
    cri,   cii   = _add_ibr_variables!(model, net)
    cr_gnd,ci_gnd= _add_ground_variables!(model, grounded)

    base = Dict{Symbol,Any}(
        :vr => vr, :vi => vi,
        :cr_gnd=> cr_gnd,:ci_gnd=> ci_gnd,
        :cr_fr => cr_fr, :ci_fr => ci_fr,
        :cr_to => cr_to, :ci_to => ci_to,
        :cr_sw => cr_sw, :ci_sw => ci_sw,
        :crd   => crd,   :cid   => cid,
        :crg   => crg,   :cig   => cig,
        :cr_src=> cr_src,:ci_src=> ci_src,
        :cr_xf => cr_xf, :ci_xf => ci_xf,
        :tap   => tap,
        :cr_nw => cr_nw, :ci_nw => ci_nw,
        :cri   => cri,   :cii   => cii,
    )
    # DC-network variables (only when the case declares a DC side).
    haskey(net, "dc_bus") && merge!(base, _add_dc_variables!(model, net))
    base
end
