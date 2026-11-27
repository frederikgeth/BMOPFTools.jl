"""
    voltage_level_analysis(net, findings) -> Dict{String,Any}

Propagate nominal voltage through the network graph via BFS from each
voltage source, assigning a voltage level to every bus. Transformers
are level-change edges; all other edges (lines, switches) must connect
buses at the same level.

Lines and closed switches that map only neutral- or earth-role terminals at
both ends (see `_neutral_only_branch`), such as a primary-to-secondary neutral
bond beside a service transformer, carry no phase conductor. They neither
propagate a nominal voltage nor count as level crossings. A bus whose terminals
are all neutral/earth-role and which is reached only through such branches has
no phase voltage level; it is listed in `neutral_only_buses` instead of
`unassigned_buses`.

Returns identified voltage levels, bus assignments, and any consistency
violations.
"""
function voltage_level_analysis(net::Dict{String,Any},
                                 findings::Vector{Finding}; phase_order=Dict())::Dict{String,Any}
    result = Dict{String,Any}()
    buses  = get(net, "bus", Dict())
    isempty(buses) && return result

    # assigned_level: bus_id => nominal voltage in V (Float64)
    assigned_level = Dict{String,Float64}()

    # --- Seed from voltage sources ---
    for (id, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", nothing)
        bus isa AbstractString || continue
        vm  = get(vs, "v_magnitude", nothing)
        vm === nothing && continue
        vals = Float64.(vm)
        isempty(vals) && continue
        vnom = maximum(vals)   # take peak phase voltage as nominal
        assigned_level[bus] = vnom
    end

    # --- BFS propagation ---
    # Build adjacency: bus => Vector of (neighbor_bus, edge_type, edge_id, ratio)
    # ratio = 1.0 for same-level edges; v_nom_to/v_nom_from for transformers
    # High-leg banks are resolved once and shared by every step below.
    high_leg_banks = _high_leg_banks(net)
    high_leg = _high_leg_power_units(high_leg_banks)
    adjacency = _build_voltage_adjacency(net; high_leg=high_leg)

    queue = collect(keys(assigned_level))
    while !isempty(queue)
        bus = popfirst!(queue)
        current_v = assigned_level[bus]
        for (neighbor, edge_type, edge_id, ratio) in get(adjacency, bus, [])
            expected_v = current_v * ratio
            if haskey(assigned_level, neighbor)
                existing_v = assigned_level[neighbor]
                # Check consistency: allow 5% tolerance for floating point
                if abs(existing_v - expected_v) / max(expected_v, 1.0) > 0.05
                    push!(findings, Finding(ERROR, "E.VOLT.LEVEL_MISMATCH",
                        :voltage_levels, :bus, neighbor,
                        "Bus '$neighbor' assigned conflicting voltage levels " *
                        "$(round(existing_v/1000, digits=2)) kV and " *
                        "$(round(expected_v/1000, digits=2)) kV.",
                        Dict{String,Any}("bus" => neighbor,
                                         "existing_v" => existing_v,
                                         "expected_v" => expected_v,
                                         "via_edge"   => edge_id)))
                end
            else
                assigned_level[neighbor] = expected_v
                push!(queue, neighbor)
            end
        end
    end

    # Return-only buses reached through neutral-only branches carry no phase
    # level; they are not islanded from a source.
    neutral_only = _neutral_only_buses(net, assigned_level)

    # Buses with no assigned level (islanded from all sources)
    unassigned = [id for id in keys(buses)
                  if !haskey(assigned_level, id) && !(id in neutral_only)]
    if !isempty(unassigned)
        push!(findings, Finding(WARNING, "W.VOLT.UNASSIGNED", :voltage_levels, :bus, nothing,
            "$(length(unassigned)) bus(es) have no reachable voltage source — may be islanded.",
            Dict{String,Any}("buses" => unassigned)))
    end

    # --- Group buses into voltage levels ---
    # Cluster buses with the same nominal voltage (within 5%)
    level_groups = _cluster_voltage_levels(assigned_level)

    # For each level, collect connected component membership
    levels_out = Dict{String,Any}()
    for (level_v, bus_list) in sort(collect(level_groups), by=x->x[1])
        label = _voltage_level_label(level_v)
        levels_out[label] = Dict{String,Any}(
            "nominal_v"  => level_v,
            "nominal_kv" => level_v / 1000.0,
            "buses"      => sort(bus_list),
            "n_buses"    => length(bus_list)
        )
        # lines within this level
        level_bus_set = Set(bus_list)
        level_lines = [id for (id, l) in get(net, "line", Dict())
                       if get(l, "bus_from", "") in level_bus_set &&
                          get(l, "bus_to",   "") in level_bus_set]
        levels_out[label]["lines"]   = level_lines
        levels_out[label]["n_lines"] = length(level_lines)

        # loads at this level
        level_loads = [id for (id, l) in get(net, "load", Dict())
                       if get(l, "bus", "") in level_bus_set]
        levels_out[label]["loads"]   = level_loads
        levels_out[label]["n_loads"] = length(level_loads)

        # generators at this level
        level_gens = [id for (id, g) in get(net, "generator", Dict())
                      if get(g, "bus", "") in level_bus_set]
        levels_out[label]["generators"]   = level_gens
        levels_out[label]["n_generators"] = length(level_gens)
    end

    result["levels"]              = levels_out
    result["voltage_basis"]       = "phase_to_reference"
    result["voltage_basis_note"]  = "Nominal phase-to-reference magnitudes; balanced three-phase line-to-line values are √3 times these values."
    result["n_levels"]            = length(levels_out)
    result["bus_voltage_map"]     = Dict(k => v for (k, v) in assigned_level)
    result["unassigned_buses"]    = unassigned
    result["neutral_only_buses"]  = sort!(collect(neutral_only))

    # Transformer transition summary
    transitions = _transformer_transitions(net, assigned_level; phase_order)
    result["transformer_transitions"] = transitions
    # Buses whose phase-to-neutral voltage is not uniform across conductors
    # (high-leg delta); the reported level is the center-tapped leg voltage.
    result["high_leg_units"] = sort!([b.id for b in high_leg_banks])
    result["high_leg_banks"] = [Dict{String,Any}("power_unit" => b.id, "lighting_unit" => b.lighting,
        "bus_from" => b.bus_from, "bus_to" => b.bus_to, "high_leg" => b.high, "status" => b.status,
        "secondary_amplitude_ratio" => b.amplitude_ratio,
        "secondary_amplitude_range" => b.amplitude_range === nothing ? nothing : collect(b.amplitude_range))
        for b in high_leg_banks]
    result["mixed_phase_to_neutral_buses"] = sort!(unique!(String[b.bus_to for b in high_leg_banks
                                                                  if b.status == "verified"]))

    # Check: non-transformer edges crossing voltage levels
    _check_level_crossing_lines(net, assigned_level, findings)
    _check_transformer_ratio_consistency(net, assigned_level, findings; banks=high_leg_banks)

    result
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A 1-phase winding is connected phase-to-phase when its terminal map spans two
# phase conductors with no neutral — so its v_nom is a line-to-line voltage.
function _winding_phase_to_phase(net, t::AbstractDict, key::String)::Bool
    tm = get(t, key, nothing)
    tm isa AbstractVector || return false
    bid=get(t,key=="terminal_map_from" ? "bus_from" : "bus_to",nothing)
    c=Dict{String,Any}("bus"=>bid,"terminal_map"=>tm)
    ctx=_device_index_context(net,"transformer","",c)
    ctx.evidence["reason"]===nothing && ctx.evidence["resolved_roles"]==["phase","phase"]
end

# High-leg (four-wire) delta: a center-tapped lighting unit and a phase-to-phase
# power unit land on the same secondary bus and close an open delta. The center
# tap fixes the per-conductor reference (the two legs); the third conductor, the
# high leg, sits at √3 times that to neutral, so no single per-conductor nominal
# describes the bus through the power unit.
#
# Secondary maps and turns ratios do not establish that geometry: it depends on
# the relative phasors of the two PRIMARY windings. With nominal primary
# phasors p₁ (lighting) and p₂ (power), unit directions u = p/|p|, and leg
# level L, the model's winding polarity (secondary first-minus-second terminal
# in phase with primary first-minus-second) gives the legs at ±L·u₁ and the
# new conductor at V_shared ∓ 2L·u₂. That is a high leg only when its
# magnitude is √3·L: primaries on the same conductors give 3L, a line-to-neutral
# beside a line-to-line primary gives about 2.9L. The power unit's own voltage
# rating is deliberately not used here; `_check_high_leg_ratio` checks it.
#
# Returns one record per identified power unit, resolved once per network:
# `(id, bus_from, bus_to, lighting, high, status, amplitude_ratio,
# amplitude_range)`. `amplitude_range` is set when a unit of the bank has a
# free tap (`tap_min < tap_max`): the status then holds for every tap position
# in the bounds, or is "unverified" when the positions disagree. A unit
# whose primaries point the right way but whose secondary amplitude is not the
# bank's line-to-line voltage has status "amplitude_mismatch": it is not a
# high leg, it is kept out of level propagation, and the ratio check reports it. `status` is "verified", or
# "unverified" when the primary phasors are not established: no voltage source
# declares the angle of the conductor each winding terminal is on, as followed
# through the terminal maps of lines and closed switches. Phase labels are
# never taken as evidence of an angle. An
# unverified unit is kept out of level propagation rather than raised as a
# false conflict, is reported with that status, and is not called a high leg.
function _high_leg_banks(net::Dict{String,Any})
    out = NamedTuple{(:id, :bus_from, :bus_to, :lighting, :high, :status, :amplitude_ratio, :amplitude_range),
                     Tuple{String,String,String,String,Vector{String},String,Union{Float64,Nothing},
                           Union{Tuple{Float64,Float64},Nothing}}}[]
    xfmr = get(net, "transformer", Dict())
    xfmr isa AbstractDict || return out
    ct = get(xfmr, "center_tap", nothing); sp = get(xfmr, "single_phase", nothing)
    ct isa AbstractDict && sp isa AbstractDict || return out
    strs(tm, n) = tm isa AbstractVector && length(tm) == n && all(x -> x isa AbstractString, tm)
    lighting = Dict{Tuple{String,String},Vector{Any}}()
    for id in sort!(collect(keys(ct)))
        t = ct[id]
        t isa AbstractDict || continue
        f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
        tm = get(t, "terminal_map_to", nothing); tf = get(t, "terminal_map_from", nothing)
        f isa AbstractString && b isa AbstractString && strs(tm, 3) && strs(tf, 2) || continue
        push!(get!(lighting, (String(f), String(b)), Any[]), (id=string(id), to=string.(tm), from=string.(tf)))
    end
    isempty(lighting) && return out

    # Terminal roles and nominal phasors are resolved once, lazily.
    roles = _index_roles(net)
    is_return(x) = roles === nothing ? _is_convention_neutral(x) :
        (x in roles.neutral || x in roles.earth)
    # Nominal phasor of a (bus, terminal): the magnitude and angle a voltage
    # source declares for the CONDUCTOR that terminal belongs to, followed through the terminal
    # maps of lines and closed switches. Labels are not followed: `pole.b` fed
    # from `sub.a` through a mapped conductor carries the angle of `sub.a`,
    # and two legs behind another transformer carry none. A conductor that two
    # sources declare at different angles is not established either.
    conductor_angle = nothing
    function phasor(bus, t)
        if conductor_angle === nothing
            Node = Tuple{String,String}
            parent = Dict{Node,Node}()
            function find(x)
                haskey(parent, x) || (parent[x] = x)
                root = x
                while parent[root] != root; root = parent[root]; end
                while parent[x] != root
                    parent[x], x = root, parent[x]
                end
                root
            end
            for kind in ("line", "switch"), (_, c) in get(net, kind, Dict())
                c isa AbstractDict || continue
                kind == "switch" && get(c, "open_switch", false) === true && continue
                bf = get(c, "bus_from", nothing); bt = get(c, "bus_to", nothing)
                tf = get(c, "terminal_map_from", nothing); tt = get(c, "terminal_map_to", nothing)
                bf isa AbstractString && bt isa AbstractString && tf isa AbstractVector &&
                    tt isa AbstractVector || continue
                for k in 1:min(length(tf), length(tt))
                    tf[k] isa AbstractString && tt[k] isa AbstractString || continue
                    ra = find((String(bf), String(tf[k]))); rb = find((String(bt), String(tt[k])))
                    ra == rb || (parent[ra] = rb)
                end
            end
            # The declared phasor is magnitude AND angle: a winding across two
            # conductors of unequal magnitude does not point where their angles
            # alone would put it.
            declared = Dict{Node,Vector{ComplexF64}}()
            for (_, vs) in get(net, "voltage_source", Dict())
                vs isa AbstractDict || continue
                sb = get(vs, "bus", nothing); tm = get(vs, "terminal_map", nothing)
                va = get(vs, "v_angle", nothing); vm = get(vs, "v_magnitude", nothing)
                sb isa AbstractString && tm isa AbstractVector && va isa AbstractVector &&
                    vm isa AbstractVector || continue
                for (label, magnitude, angle) in zip(tm, vm, va)
                    label isa AbstractString && angle isa Real && isfinite(angle) &&
                        magnitude isa Real && isfinite(magnitude) && magnitude >= 0 || continue
                    push!(get!(declared, find((String(sb), String(label))), ComplexF64[]),
                          Float64(magnitude) * cis(Float64(angle)))
                end
            end
            established = Dict{Node,ComplexF64}()
            for (root, values) in declared
                ref = first(values)
                all(v -> abs(v - ref) <= 1e-6 * max(abs(ref), 1.0), values) && (established[root] = ref)
            end
            # A conductor no source declares is at zero only when something
            # holds it there exactly: one of its terminals is a return terminal
            # that is perfectly grounded or on a source bus. The label alone
            # decides nothing: a terminal called `n` that a line maps onto a
            # source phase carries that phase, and an `n` that reaches no such
            # point has no established voltage. A shunt to earth is a path,
            # not a voltage: an electrode carries the primary return current,
            # and a shunt may couple the neutral to a phase as well.
            members = Dict{Node,Vector{Node}}()
            for n in collect(keys(parent)); push!(get!(members, find(n), Node[]), n); end
            source_buses = Set{String}(String(vs["bus"]) for (_, vs) in get(net, "voltage_source", Dict())
                                       if vs isa AbstractDict && get(vs, "bus", nothing) isa AbstractString)
            pinned(n) = is_return(n[2]) && (n[1] in source_buses || begin
                b = get(get(net, "bus", Dict()), n[1], nothing)
                g = b isa AbstractDict ? get(b, "perfectly_grounded_terminals", nothing) : nothing
                g isa AbstractVector && n[2] in g
            end)
            conductor_angle = n -> begin
                root = find(n)
                haskey(declared, root) && return get(established, root, nothing)
                group = get(members, root, [n])
                any(pinned, group) ? 0.0 + 0.0im : nothing
            end
        end
        conductor_angle((String(bus), String(t)))
    end
    # Phasor across a winding's two terminals, or nothing when it is not
    # established. Both terminals at the same phasor (one source conductor on
    # both ends) is an established result: exactly zero, with no direction.
    function winding(bus, tm)
        a = phasor(bus, tm[1]); b = phasor(bus, tm[2])
        (a === nothing || b === nothing) && return nothing
        p = a - b
        scale = max(abs(a), abs(b))
        scale > 0 && abs(p) > 1e-6 * scale ? p : zero(p)
    end
    # Secondary volts per primary volt as the solver builds the unit: the
    # nameplate ratio N0 = v_nom_from / v_nom_to times the `tap` multiplier is
    # the from-to ratio, for single_phase and center_tap alike. With
    # `tap_min < tap_max` the solver frees the tap within those bounds and
    # `tap` is only its start, clamped into them: the ratio is then a range.
    # Returns `(lo, hi, at)`, `at` being the ratio at the (clamped) `tap`.
    ratio(t) = begin
        vf = get(t, "v_nom_from", nothing); vt = get(t, "v_nom_to", nothing)
        tap = get(t, "tap", 1.0)
        ok(x) = x isa Real && isfinite(x) && x > 0
        ok(vf) && ok(vt) && ok(tap) || return nothing
        at(x) = Float64(vt) / (Float64(vf) * Float64(x))
        haskey(t, "tap_min") && haskey(t, "tap_max") || return (at(tap), at(tap), at(tap))
        tlo = t["tap_min"]; thi = t["tap_max"]
        tlo isa Real && thi isa Real && isfinite(tlo) && isfinite(thi) || return nothing
        tlo < thi || return (at(tap), at(tap), at(tap))
        tlo > 0 || return nothing
        (at(thi), at(tlo), at(clamp(tap, tlo, thi)))
    end

    for id in sort!(collect(keys(sp)))
        t = sp[id]
        t isa AbstractDict || continue
        f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
        f isa AbstractString && b isa AbstractString || continue
        units = get(lighting, (String(f), String(b)), nothing)
        units === nothing && continue
        tm = get(t, "terminal_map_to", nothing); tf = get(t, "terminal_map_from", nothing)
        strs(tm, 2) && strs(tf, 2) || continue
        to = string.(tm)
        any(is_return, to) && continue                 # the power unit is phase-to-phase
        for u in units
            legs = (u.to[1], u.to[3])
            shared = [x for x in to if x in legs]; fresh = [x for x in to if !(x in legs)]
            # One end on a leg, the other on a new conductor: a unit across the
            # two legs is paralleled with the lighting winding instead.
            length(shared) == 1 && length(fresh) == 1 || continue
            record(status, amplitude, range=nothing) = (id=string(id), bus_from=String(f), bus_to=String(b),
                lighting=u.id, high=fresh, status=status, amplitude_ratio=amplitude, amplitude_range=range)
            p1 = winding(String(f), u.from); p2 = winding(String(f), string.(tf))
            r1 = ratio(get(ct, u.id, Dict())); r2 = ratio(t)
            if p1 === nothing || p2 === nothing || r1 === nothing || r2 === nothing || iszero(p1)
                push!(out, record("unverified", nothing))
                break
            end
            if iszero(p2)
                # The power winding's primary is fed from one conductor on
                # both ends: no voltage across it, so none on its secondary,
                # at any tap. The delta cannot close; the ratio check reports it.
                push!(out, record("amplitude_mismatch", 0.0))
                break
            end
            # Secondary voltages as the declared ratios make them from the
            # traced primary phasors: the legs at ±leg, the power winding at
            # `across`. The delta closes only if both the direction and the
            # amplitude of the power winding fit.
            leg = r1[3] * p1; across = r2[3] * p2
            placed(a) = (v_shared = shared[1] == legs[1] ? leg : -leg;
                         to[1] == shared[1] ? v_shared - a : v_shared + a)
            fits(a) = abs(abs(placed(a)) / (sqrt(3.0) * abs(leg)) - 1) <= 0.1
            amplitude = abs(across) / (2 * abs(leg))
            # Two independent conditions. Geometry: with the bank's own
            # line-to-line amplitude the primaries' directions put the third
            # conductor at sqrt(3) times the leg. Amplitude: this winding's
            # secondary is that line-to-line voltage. Testing only the
            # resulting magnitude would accept in-phase primaries whose
            # winding happens to add up to the same number.
            geometry = fits(2 * abs(leg) * across / abs(across))
            geometry || continue
            # The amplitude over every tap position the solver may take. With
            # fixed taps the range is the one value.
            free = r1[1] < r1[2] || r2[1] < r2[2]
            base = abs(p2) / (2 * abs(p1))
            lo = base * r2[1] / r1[2]; hi = base * r2[2] / r1[1]
            range = free ? (lo, hi) : nothing
            if abs(lo - 1) <= 0.1 && abs(hi - 1) <= 0.1
                push!(out, record("verified", amplitude, range))
            elseif hi < 0.9 || lo > 1.1
                # Right direction, wrong amplitude at every tap position: the
                # primaries would close a delta, but this unit's secondary
                # voltage is not the bank's line-to-line voltage (its rating,
                # its tap range, or the magnitude of the phase it is fed
                # from). Not a high leg; the ratio check reports it.
                push!(out, record("amplitude_mismatch", amplitude, range))
            else
                # A free tap decides: some positions close the delta, others
                # do not. Not certified either way.
                push!(out, record("unverified", amplitude, range))
            end
            break
        end
    end
    out
end

_high_leg_power_units(net::Dict{String,Any}) = _high_leg_power_units(_high_leg_banks(net))
_high_leg_power_units(banks::AbstractVector)::Set{Tuple{String,String}} =
    Set{Tuple{String,String}}(("single_phase", b.id) for b in banks)

function _build_voltage_adjacency(net::Dict{String,Any};
                                  high_leg=_high_leg_power_units(net))
    # adjacency: bus => [(neighbor, edge_type, edge_id, ratio)]
    adj = Dict{String,Vector{Tuple{String,Symbol,String,Float64}}}()
    roles = _index_roles(net)

    function add_adj!(a, b, etype, eid, ratio)
        push!(get!(adj, a, []), (b, etype, eid, ratio))
        push!(get!(adj, b, []), (a, etype, eid, 1.0/ratio))
    end

    # Transformers first so transformer-defined level boundaries take BFS priority
    # over line edges. When both a transformer and a line connect the same two
    # buses, the transformer must win to detect line-crossing violations correctly.
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            (subtype, string(id)) in high_leg && continue
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            (f isa AbstractString && b isa AbstractString) || continue
            vf = get(t, "v_nom_from", nothing)
            vt = get(t, "v_nom_to",   nothing)
            ratio = (vf !== nothing && vt !== nothing && Float64(vf) > 0) ?
                    Float64(vt) / Float64(vf) : 1.0
            # Bus nominals are phase-to-ground, but a 1-phase winding connected
            # PHASE-TO-PHASE (terminal_map = two phases, no neutral, e.g. a SWER
            # isolating transformer tapped across two MV phases) has its v_nom on a
            # line-to-line basis (√3 × phase-to-ground). Correct the ratio per side
            # so the phase-to-ground nominal propagates consistently. Scoped to
            # single_phase/center_tap — wye/delta subtypes carry their own √3.
            if subtype in ("single_phase", "center_tap")
                bf = _winding_phase_to_phase(net, t, "terminal_map_from") ? sqrt(3.0) : 1.0
                bt = _winding_phase_to_phase(net, t, "terminal_map_to")   ? sqrt(3.0) : 1.0
                ratio *= bf / bt
            end
            add_adj!(f, b, :transformer, id, ratio)
        end
    end

    # n-winding: edge from winding 1 to every other winding (ratio v_nom_j/v_nom_1).
    for (id, t) in get(xfmr, "n_winding", Dict())
        ws = _nw_windings(t)
        isempty(ws) && continue
        # Bus nominals are per conductor (phase-to-reference). A WYE winding's
        # v_nom is already its line-to-neutral coil voltage, but a three-phase
        # DELTA winding's v_nom is the line-to-line coil voltage: √3 above the
        # per-conductor nominal of the bus it lands on.
        _per_conductor(w) = w.connection == "DELTA" && length(w.terminal_map) == 3 ?
            w.v_nom / sqrt(3.0) : w.v_nom
        b1, v1 = ws[1].bus, _per_conductor(ws[1])
        isempty(b1) && continue
        for j in 2:length(ws)
            bj, vj = ws[j].bus, _per_conductor(ws[j])
            (isempty(bj) || bj == b1) && continue
            ratio = v1 > 0 ? vj / v1 : 1.0
            add_adj!(b1, bj, :transformer, id, ratio)
        end
    end

    # A neutral-only branch carries no phase conductor and therefore no
    # nominal phase voltage between its buses.
    for (id, l) in get(net, "line", Dict())
        _neutral_only_branch(l, roles) && continue
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        add_adj!(f, t, :line, id, 1.0)
    end

    for (id, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        _neutral_only_branch(sw, roles) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        add_adj!(f, t, :switch, id, 1.0)
    end

    adj
end

# Buses without a phase level whose terminals are all neutral/earth-role and
# that are reached from a leveled bus through neutral-only lines or closed
# switches (for example, a grounding-electrode bus).
function _neutral_only_buses(net::Dict{String,Any}, assigned::AbstractDict)::Set{String}
    roles = _index_roles(net)
    reached = Set{String}()
    roles isa TerminalRoles || return reached
    buses = get(net, "bus", Dict())
    adj = Dict{String,Vector{String}}()
    for kind in ("line", "switch"), (_, br) in get(net, kind, Dict())
        kind == "switch" && get(br, "open_switch", false) && continue
        _neutral_only_branch(br, roles) || continue
        f = get(br, "bus_from", nothing); t = get(br, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        push!(get!(adj, f, String[]), t)
        push!(get!(adj, t, String[]), f)
    end
    function return_only(id)
        b = get(buses, id, nothing)
        names = b isa AbstractDict ? get(b, "terminal_names", nothing) : nothing
        names isa AbstractVector && !isempty(names) &&
            all(t -> _return_only_label(t, roles), names)
    end
    queue = [id for id in keys(assigned) if haskey(adj, id)]
    seen = Set{String}(queue)
    while !isempty(queue)
        bus = popfirst!(queue)
        for nb in get(adj, bus, String[])
            (nb in seen || haskey(assigned, nb) || !return_only(nb)) && continue
            push!(seen, nb); push!(reached, nb); push!(queue, nb)
        end
    end
    reached
end

function _cluster_voltage_levels(assigned::Dict{String,Float64};
                                  tol::Float64=0.05)
    # Sort buses by voltage so clustering is deterministic, then group
    # sequentially using a running-mean centroid per cluster.
    sorted_pairs = sort(collect(assigned), by=last)
    clusters = Vector{Tuple{Float64,Vector{String}}}()  # (centroid, members)

    for (bus, v) in sorted_pairs
        if !isempty(clusters)
            centroid, members = clusters[end]
            if abs(v - centroid) / max(centroid, 1.0) <= tol
                push!(members, bus)
                # update running mean
                new_centroid = centroid + (v - centroid) / length(members)
                clusters[end] = (new_centroid, members)
                continue
            end
        end
        push!(clusters, (v, String[bus]))
    end

    Dict{Float64,Vector{String}}(c => m for (c, m) in clusters)
end

function _voltage_level_label(v_volts::Float64)::String
    kv = v_volts / 1000.0
    if kv >= 100
        "EHV_$(round(Int, kv))kV"
    elseif kv >= 35
        "HV_$(round(Int, kv))kV"
    elseif kv >= 1
        "MV_$(round(kv, digits=1))kV"
    else
        "LV_$(round(Int, v_volts))V"
    end
end

function _transformer_transitions(net::Dict{String,Any},
                                   assigned::Dict{String,Float64}; phase_order=Dict())
    transitions = Dict{String,Any}[]
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        subtype in WINDING_LIST_SUBTYPES && continue   # n_winding below
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            f = get(t, "bus_from", nothing)
            b = get(t, "bus_to",   nothing)
            vf = get(assigned, f, nothing)
            vt = get(assigned, b, nothing)
            push!(transitions, Dict{String,Any}(
                "id"           => id,
                "subtype"      => subtype,
                "vector_group" => _derive_vector_group(net, subtype, t;phase_order),
                "phase_relation" => transformer_phase_relation(net,subtype,t;phase_order),
                "bus_from"     => f,
                "bus_to"       => b,
                "v_from"       => vf,
                "v_to"         => vt,
                "level_from"   => vf !== nothing ? _voltage_level_label(vf) : "unknown",
                "level_to"     => vt !== nothing ? _voltage_level_label(vt) : "unknown"
            ))
        end
    end

    # n-winding: one transition row per winding 1 → winding j boundary.
    for (id, t) in get(xfmr, "n_winding", Dict())
        ws = _nw_windings(t)
        isempty(ws) && continue
        f  = ws[1].bus
        vf = get(assigned, f, nothing)
        for j in 2:length(ws)
            b  = ws[j].bus
            vt = get(assigned, b, nothing)
            push!(transitions, Dict{String,Any}(
                "id"           => "$(id) (w1→w$j)",
                "subtype"      => "n_winding",
                "vector_group" => _derive_vector_group(net,"n_winding",t;phase_order,to_winding=j),
                "phase_relation" => transformer_phase_relation(net,"n_winding",t;phase_order,to_winding=j),
                "bus_from"     => f,
                "bus_to"       => b,
                "v_from"       => vf,
                "v_to"         => vt,
                "level_from"   => vf !== nothing ? _voltage_level_label(vf) : "unknown",
                "level_to"     => vt !== nothing ? _voltage_level_label(vt) : "unknown"
            ))
        end
    end
    transitions
end

function _check_level_crossing_lines(net::Dict{String,Any},
                                      assigned::Dict{String,Float64},
                                      findings::Vector{Finding})
    roles = _index_roles(net)
    for (id, l) in get(net, "line", Dict())
        # A neutral bond between buses of different levels is not a crossing.
        _neutral_only_branch(l, roles) && continue
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        vf = get(assigned, f, nothing); vt = get(assigned, t, nothing)
        (vf === nothing || vt === nothing) && continue
        if abs(vf - vt) / max(vf, 1.0) > 0.05
            push!(findings, Finding(ERROR, "E.VOLT.LINE_CROSSING",
                :voltage_levels, :line, id,
                "Line '$id' connects buses at different voltage levels " *
                "($(round(vf/1000,digits=2)) kV ↔ $(round(vt/1000,digits=2)) kV). " *
                "Only transformers should cross voltage levels.",
                Dict{String,Any}("line" => id, "v_from" => vf, "v_to" => vt)))
        end
    end
end

# A high-leg power unit is left out of level propagation (the center-tapped
# unit fixes the scalar bus nominal), but its own ratio is still checked: its
# secondary closes the delta across the bank's line-to-line voltage, which is
# twice the leg level the lighting unit establishes.
function _check_high_leg_ratio(roles, id, t, assigned, findings, bank)
    leg = get(assigned, get(t, "bus_to", nothing), nothing)
    vt_ref = get(t, "v_nom_to", nothing)
    if bank.amplitude_ratio !== nothing
        # Traced primary phasors and declared turns ratios give the secondary
        # amplitude this unit actually produces, against the bank's
        # line-to-line voltage (twice the leg voltage of the lighting unit).
        # A free tap that can both close and miss the delta is not a
        # contradiction in the data: nothing to report.
        bank.status == "unverified" && return
        abs(bank.amplitude_ratio - 1) > 0.1 || return
        push!(findings, Finding(WARNING, "W.VOLT.XFMR_RATIO",
            :voltage_levels, :transformer, id,
            "Transformer '$id' is connected as the power unit of a high-leg delta bank, but its " *
            "secondary voltage is $(round(100 * bank.amplitude_ratio, digits=1)) % of the bank's " *
            "line-to-line voltage (twice the leg voltage set by center-tapped unit " *
            "'$(bank.lighting)'): the delta does not close. " *
            (iszero(bank.amplitude_ratio) ?
                "Both primary terminals are fed from the same source conductor, so there is no " *
                "voltage across the winding. Check its primary terminal map." :
                "Check its voltage ratings and the magnitude of the phase it is fed from."),
            Dict{String,Any}("id" => id, "basis" => "high_leg_line_to_line",
                "secondary_amplitude_ratio" => bank.amplitude_ratio,
                "secondary_amplitude_range" => bank.amplitude_range === nothing ? nothing : collect(bank.amplitude_range),
                "lighting_unit" => bank.lighting,
                "leg_level_v" => leg, "bank_line_to_line_v" => leg isa Real ? 2 * leg : nothing,
                "v_nom_to" => vt_ref isa Real ? Float64(vt_ref) : nothing, "status" => bank.status)))
        return
    end
    # Phasors not established: fall back to the nominal levels of the two buses.
    f = get(t, "bus_from", nothing)
    vf_bus = get(assigned, f, nothing)
    vf_ref = get(t, "v_nom_from", nothing)
    all(v -> v isa Real && isfinite(v) && v > 0, (vf_bus, leg, vf_ref, vt_ref)) || return
    # Phase-to-phase primary: both terminals are phases under the resolved roles.
    tf = get(t, "terminal_map_from", nothing)
    is_return(x) = roles === nothing ? _is_convention_neutral(x) :
        (x in roles.neutral || x in roles.earth)
    primary_ll = tf isa AbstractVector && length(tf) == 2 && all(x -> x isa AbstractString, tf) &&
        !any(is_return, tf) ? sqrt(3.0) : 1.0
    expected = Float64(vt_ref) / (Float64(vf_ref) / primary_ll)   # secondary L-L per primary per-conductor volt
    actual = 2 * leg / vf_bus
    abs(expected - actual) / max(expected, 1e-6) > 0.1 || return
    push!(findings, Finding(WARNING, "W.VOLT.XFMR_RATIO",
        :voltage_levels, :transformer, id,
        "Transformer '$id' is the power unit of a high-leg delta bank, but its turns ratio " *
        "$(round(expected, digits=4)) is inconsistent with the bank's line-to-line voltage " *
        "(twice the $(round(leg, digits=1)) V leg level set by the center-tapped unit: " *
        "ratio $(round(actual, digits=4))).",
        Dict{String,Any}("id" => id, "turns_ratio" => expected, "bus_ratio" => actual,
            "basis" => "high_leg_line_to_line", "leg_level_v" => leg,
            "bank_line_to_line_v" => 2 * leg, "v_nom_to" => Float64(vt_ref), "status" => bank.status)))
end

function _check_transformer_ratio_consistency(net::Dict{String,Any},
                                               assigned::Dict{String,Float64},
                                               findings::Vector{Finding};
                                               banks=_high_leg_banks(net))
    xfmr = get(net, "transformer", Dict())
    roles = _index_roles(net)
    high_leg = _high_leg_power_units(banks)
    bank_of = Dict(b.id => b for b in banks)
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            if (subtype, string(id)) in high_leg
                _check_high_leg_ratio(roles, string(id), t, assigned, findings, bank_of[string(id)])
                continue
            end
            f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
            vf_bus = get(assigned, f, nothing)
            vt_bus = get(assigned, b, nothing)
            vf_ref = get(t, "v_nom_from", nothing)
            vt_ref = get(t, "v_nom_to",   nothing)
            (vf_bus === nothing || vt_bus === nothing) && continue
            (vf_ref === nothing || vt_ref === nothing) && continue
            expected_ratio = Float64(vt_ref) / Float64(vf_ref)
            # Apply the same phase-to-phase √3 correction the nominal-voltage
            # propagation uses, so a SWER (phase-to-phase-tapped 1-phase)
            # transformer's raw line-to-line v_nom is not compared against the
            # phase-to-ground bus ratio — that mismatch was a false XFMR_RATIO.
            if subtype in ("single_phase", "center_tap")
                bf = _winding_phase_to_phase(net, t, "terminal_map_from") ? sqrt(3.0) : 1.0
                bt = _winding_phase_to_phase(net, t, "terminal_map_to")   ? sqrt(3.0) : 1.0
                expected_ratio *= bf / bt
            end
            actual_ratio   = vt_bus / vf_bus
            if abs(expected_ratio - actual_ratio) / max(expected_ratio, 1e-6) > 0.1
                push!(findings, Finding(WARNING, "W.VOLT.XFMR_RATIO",
                    :voltage_levels, :transformer, id,
                    "Transformer '$id' turns ratio $(round(expected_ratio, digits=3)) " *
                    "inconsistent with adjacent bus voltage ratio " *
                    "$(round(actual_ratio, digits=3)).",
                    Dict{String,Any}("id" => id,
                                     "turns_ratio"    => expected_ratio,
                                     "bus_ratio"      => actual_ratio)))
            end
        end
    end
end

"""
    _assign_nominal_voltages(net) -> Dict{String,Float64}

BFS from every voltage source to assign a phase-to-neutral nominal voltage (V)
to every reachable bus. Transformer edges apply the v_nom_to/v_nom_from ratio.
Used by `diagnose_infeasibility` to derive per-unit voltage thresholds for buses
that have no explicit v_min/v_max.
"""
function _assign_nominal_voltages(net::Dict{String,Any})::Dict{String,Float64}
    assigned = Dict{String,Float64}()

    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", nothing)
        bus isa AbstractString || continue
        vm = get(vs, "v_magnitude", nothing)
        vm === nothing && continue
        vals = Float64.(vm)
        isempty(vals) && continue
        assigned[bus] = maximum(vals)
    end

    adjacency = _build_voltage_adjacency(net)
    queue = collect(keys(assigned))
    while !isempty(queue)
        bus = popfirst!(queue)
        v = assigned[bus]
        for (neighbor, _, _, ratio) in get(adjacency, bus, [])
            haskey(assigned, neighbor) && continue
            assigned[neighbor] = v * ratio
            push!(queue, neighbor)
        end
    end

    assigned
end
