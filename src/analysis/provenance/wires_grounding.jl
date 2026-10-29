# Wires-per-voltage-level classification and neutral grounding analysis.
#
# _wires_by_level   — 3-wire vs 4-wire per voltage level; flags likely Kron-reduced LV.
# _grounding_analysis — neutral continuity graph; identifies floating neutral sections.
# _earthing_zones   — TT/TN/IT/MV earthing classification per galvanic island.

# ---------------------------------------------------------------------------
# 2. Wires per voltage level — Kron-reduction likelihood
# ---------------------------------------------------------------------------

function _wires_by_level(net::Dict{String,Any},
                          findings::Vector{Finding},
                          vl::Dict{String,Any})::Dict{String,Any}
    buses = get(net, "bus", Dict())
    out = Dict{String,Any}()
    isempty(buses) && return out

    levels = get(vl, "levels", Dict())

    neutral_of = _bus_neutral_map(buses)
    carried = _neutral_branch_buses(net)

    for (label, info) in levels
        ids = get(info, "buses", String[])
        isempty(ids) && continue
        n_with_n = count(in(carried), ids)
        nominal_v = Float64(get(info, "nominal_v", 0.0))
        is_lv = nominal_v < 1000.0

        # Single-terminal loads without a neutral: implicit ground return
        level_set = Set(ids)
        implicit_loads = String[]
        for (lid, l) in get(net, "load", Dict())
            b = get(l, "bus", "")
            b in level_set || continue
            tm = get(l, "terminal_map", String[])
            nn = get(neutral_of, b, nothing)
            (nn !== nothing && nn in tm) && continue
            length(tm) == 1 && push!(implicit_loads, lid)
        end

        wires = _branch_wire_description(net,ids;carried)

        out[label] = Dict{String,Any}(
            "nominal_v"               => nominal_v,
            "n_buses"                 => length(ids),
            "n_with_neutral"          => n_with_n,
            "wires"                   => wires,
            "is_lv"                   => is_lv,
            "n_implicit_ground_loads" => length(implicit_loads)
        )

        if is_lv && n_with_n == 0 && length(ids) > 1
            extra = isempty(implicit_loads) ? "" :
                " $(length(implicit_loads)) load(s) connect phase-to-ground, " *
                "corroborating an implicit neutral."
            push!(findings, Finding(INFO, "I.PROV.KRON_LIKELY", :provenance,
                :network, nothing,
                "Voltage level $label has no represented neutral conductor. " *
                "Consider prior neutral elimination, including Kron reduction; genuine three-wire " *
                "construction and other equivalents are alternatives. Review the original conductor " *
                "and grounding model if neutral displacement matters.$extra",
                Dict{String,Any}("level" => label,
                    "implicit_ground_loads" => sort(implicit_loads),
                    "evidence_kind" => "heuristic_candidate", "history_verified" => false,
                    "knowledge_ids" => ["PSK-000008"],
                    "interpretation" => _provenance_interpretation("I.PROV.KRON_LIKELY",
                        Dict("level" => label, "nominal_v" => nominal_v,
                             "n_buses" => length(ids), "n_with_neutral" => n_with_n),
                        supporting_context=Dict("implicit_ground_loads" => sort(implicit_loads))))))
        end
    end

    out
end

# ---------------------------------------------------------------------------
# 3. Neutral grounding — continuity and floating sections
# ---------------------------------------------------------------------------

function _grounding_analysis(net::Dict{String,Any},
                              findings::Vector{Finding})::Dict{String,Any}
    buses = get(net, "bus", Dict())
    neutral_of = _bus_neutral_map(buses)
    nbuses = sort([id for (id, nn) in neutral_of if nn !== nothing])
    res = Dict{String,Any}("n_buses_with_neutral" => length(nbuses))
    if isempty(nbuses)
        res["n_grounding_points"]  = 0
        res["n_neutral_components"] = 0
        res["n_floating"]          = 0
        return res
    end
    nbus_set = Set(nbuses)

    # Does this terminal list reference the bus's neutral?
    uses_neutral(bus, tm) = begin
        nn = get(neutral_of, bus, nothing)
        nn !== nothing && nn in tm
    end

    # Grounding points: perfect grounding, grounding shunt on the neutral,
    # or a voltage source that references the neutral (pins its potential).
    grounded = Set{String}()
    n_perfect = 0
    for (id, b) in buses
        if uses_neutral(id, get(b, "perfectly_grounded_terminals", String[]))
            push!(grounded, id)
            n_perfect += 1
        end
    end
    earthing_paths = _terminal_earthing(net)
    for (b,n) in neutral_of
        n !== nothing && haskey(earthing_paths,(b,n)) && push!(grounded,b)
    end
    intersect!(grounded, nbus_set)

    # Neutral continuity graph: branches that carry a neutral conductor on both
    # ends — lines and closed switches, plus the line-to-neutral
    # single_phase_autotransformer (see below). Most transformer windings are
    # galvanically isolated circuits, so the neutral does not continue through them.
    adj = Dict{String,Vector{String}}()
    n_neutral_branches = 0
    for comp_type in ("line", "switch")
        for (_, c) in get(net, comp_type, Dict())
            comp_type == "switch" && get(c, "open_switch", false) && continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString) || continue
            (uses_neutral(f, get(c, "terminal_map_from", String[])) &&
             uses_neutral(t, get(c, "terminal_map_to",   String[]))) || continue
            n_neutral_branches += 1
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    # The single_phase_autotransformer shares one physical neutral bushing across
    # its two sides — the OPF bonds V_fr_n == V_to_n — so the neutral continues
    # through it, but only for a line-to-neutral SVR (both maps reference "n").
    # The open_delta_regulator is line-to-line: its neutral terminal is unused by
    # the device (no from↔to tie in the model), so it is NOT a neutral branch —
    # even though it IS galvanically continuous (see GALVANIC_CONTINUOUS_SUBTYPES).
    # All other subtypes have galvanically isolated windings.
    for (_, c) in get(get(net, "transformer", Dict()),
                      "single_phase_autotransformer", Dict())
        c isa Dict || continue
        f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        (uses_neutral(f, get(c, "terminal_map_from", String[])) &&
         uses_neutral(t, get(c, "terminal_map_to",   String[]))) || continue
        n_neutral_branches += 1
        push!(get!(adj, f, String[]), t)
        push!(get!(adj, t, String[]), f)
    end
    res["n_neutral_branches"] = n_neutral_branches
    res["n_grounding_points"] = length(grounded)
    res["all_perfectly_grounded"] = n_perfect >= length(nbuses)

    # Buses whose neutral terminal is actually used by a shunt component
    neutral_users = Set{String}()
    for comp_type in ("load", "generator")
        for (_, c) in get(net, comp_type, Dict())
            b = get(c, "bus", nothing)
            b isa AbstractString || continue
            uses_neutral(b, get(c, "terminal_map", String[])) && push!(neutral_users, b)
        end
    end

    if n_neutral_branches == 0
        # Missing branch incidence does not establish a ground constraint or
        # the provenance of a reduction.
        res["n_neutral_components"] = length(nbuses)
        res["n_floating"] = 0
        res["convention"] = "no_neutral_branches"
        ungrounded_users = sort(collect(setdiff(neutral_users, grounded)))
        if !isempty(ungrounded_users)
            push!(findings, Finding(WARNING, "W.PROV.IMPLICIT_GROUNDING",
                :provenance, :network, nothing,
                "No branch carries a neutral conductor, but " *
                "$(length(ungrounded_users)) bus(es) have components " *
                "referencing terminal 'n' without an explicit grounding — " *
                "the grounding/reduction convention is indeterminate. " *
                "Declare the intended return and grounding connections.",
                Dict{String,Any}("buses" => ungrounded_users,
                    "status"=>"indeterminate","knowledge_ids"=>["PSK-000002"])))
        end
        return res
    end
    res["convention"] = "explicit"

    # Connected components of the neutral graph; each must reach a grounding
    visited = Set{String}()
    n_components = 0
    floating = Vector{Vector{String}}()
    for start in sort(nbuses)
        start in visited && continue
        n_components += 1
        comp = String[]
        queue = String[start]
        push!(visited, start)
        while !isempty(queue)
            b = popfirst!(queue)
            push!(comp, b)
            for nb in get(adj, b, String[])
                (nb in visited || !(nb in nbus_set)) && continue
                push!(visited, nb)
                push!(queue, nb)
            end
        end
        any(b -> b in grounded, comp) || push!(floating, sort(comp))
    end
    res["n_neutral_components"] = n_components
    res["n_floating"]           = length(floating)
    res["floating_components"]  = floating

    for comp in floating
        used = any(b -> b in neutral_users, comp)
        sev  = used ? ERROR : WARNING
        code = used ? "E.PROV.FLOATING_NEUTRAL" : "W.PROV.FLOATING_NEUTRAL"
        push!(findings, Finding(sev, code, :provenance, :bus, nothing,
            "Neutral section spanning $(length(comp)) bus(es) has no path to " *
            "ground$(used ? " and is used by loads/generators — the " *
            "zero-sequence path is undefined (ill-posed for 4-wire analysis)" :
            "") : $(join(comp, ", ")).",
            Dict{String,Any}("buses" => comp, "used" => used)))
    end

    if res["all_perfectly_grounded"] && n_neutral_branches > 0
        push!(findings, Finding(INFO, "I.PROV.KRON_REDUCIBLE", :provenance,
            :network, nothing,
            "Every bus neutral is perfectly grounded (rg = 0): Kron reduction " *
            "is exact, so the explicit neutral conductors are numerically " *
            "redundant — either reduce the model or revisit the perfect-" *
            "grounding assumption.",
            nothing))
    end

    res
end

"""
    _check_ungrounded_wye_neutrals(net, findings)

Info-level note for three-phase wye windings whose neutral (star point) is
brought out at a bus that has neither a perfect ground nor a grounding impedance
on it. A wye star point is the natural earthing point of the winding; if its bus
carries no local ground, the zero-sequence potential is set only by whatever the
neutral conductor reaches elsewhere (if anything) — easy to overlook and often an
omission. Single-phase transformers (connected phase-to-neutral or phase-to-phase)
are exempt: their neutral is a winding terminal, not a three-phase star point, so
the winding must have ≥3 phase conductors to qualify.
"""
function _check_ungrounded_wye_neutrals(net::Dict{String,Any},
                                         findings::Vector{Finding})
    xfmr = get(net, "transformer", Dict())
    isempty(xfmr) && return
    buses = get(net, "bus", Dict())
    neutral_of = _bus_neutral_map(buses)
    # Buses with any neutral-earthing path — perfect ground (|Z|=0), source
    # neutral bond, or a grounding shunt (finite |Z|). Membership = "grounded".
    earth = _terminal_earthing(net)

    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            for (bk, mk, side) in (("bus_from", "terminal_map_from", "primary"),
                                    ("bus_to",   "terminal_map_to",   "secondary"))
                b = get(t, bk, nothing)
                b isa AbstractString || continue
                tm = Vector{String}(get(t, mk, String[]))
                # Three-phase wye winding with the star point brought out: the
                # neutral is accessible and there are ≥3 phase conductors.
                (_neutral_terminal(tm) !== nothing &&
                 length(_phase_positions(tm)) >= 3) || continue
                haskey(earth, (b,_neutral_terminal(tm))) && continue
                push!(findings, Finding(INFO, "I.PROV.WYE_NEUTRAL_UNGROUNDED",
                    :provenance, :transformer, id,
                    "Transformer '$id' ($subtype) brings out a three-phase wye " *
                    "neutral on its $side side at bus '$b', but that bus has no " *
                    "local grounding (no perfect ground and no grounding " *
                    "impedance). The star point's zero-sequence potential is set " *
                    "only by what the neutral conductor reaches elsewhere — add a " *
                    "grounding shunt or perfect ground at '$b' if a local earth " *
                    "was intended.",
                    Dict{String,Any}("bus" => b, "subtype" => subtype,
                                     "side" => side)))
            end
        end
    end
end

# Per-bus neutral terminal name (or nothing), via the convention helper
function _bus_neutral_map(buses)::Dict{String,Union{String,Nothing}}
    Dict{String,Union{String,Nothing}}(
        id => _neutral_terminal(b)
        for (id, b) in buses)
end

# ---------------------------------------------------------------------------
# Galvanic islands (shared with integrity checks)
# ---------------------------------------------------------------------------

"""
Connected components over lines, closed switches, and the galvanically-continuous
transformer subtypes (`single_phase_autotransformer`, `open_delta_regulator`,
listed in `GALVANIC_CONTINUOUS_SUBTYPES`); isolating transformer windings are
galvanic separations. Returns sorted bus-id vectors.
"""
function _galvanic_islands(net::Dict{String,Any})::Vector{Vector{String}}
    busset = Set(keys(get(net, "bus", Dict())))
    adj = Dict{String,Vector{String}}()
    for comp_type in ("line", "switch")
        for (_, c) in get(net, comp_type, Dict())
            c isa AbstractDict || continue
            comp_type == "switch" && get(c, "open_switch", false) && continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString &&
             f in busset && t in busset) || continue
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    # Regulators (autotransformer / open-delta) do not isolate: both sides stay
    # in one island.
    xfmr = get(net, "transformer", Dict())
    for subtype in GALVANIC_CONTINUOUS_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, c) in sub
            c isa AbstractDict || continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString &&
             f in busset && t in busset) || continue
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    visited = Set{String}()
    islands = Vector{Vector{String}}()
    for start in sort(collect(busset))
        start in visited && continue
        comp = String[]
        queue = String[start]
        push!(visited, start)
        while !isempty(queue)
            b = popfirst!(queue)
            push!(comp, b)
            for nb in get(adj, b, String[])
                nb in visited && continue
                push!(visited, nb)
                push!(queue, nb)
            end
        end
        push!(islands, sort(comp))
    end
    islands
end

# ---------------------------------------------------------------------------
# Earthing system classification per galvanic island
# ---------------------------------------------------------------------------

# PSK-000002: exact reference constraints, finite electrode impedances and
# conductor incidence are separate observations. No protective-earth assets are
# present in this model, so these observations do not classify TT/TN/IT systems.
function _terminal_earthing(net)
    earth = Dict{Tuple{String,String},Float64}()
    admittance = Dict{Tuple{String,String},ComplexF64}()
    upd!(b,t,z) = (earth[(b,t)] = min(get(earth,(b,t),Inf),z))
    for (id,b) in get(net,"bus",Dict()), t in get(b,"perfectly_grounded_terminals",String[])
        upd!(id,string(t),0.0)
    end
    for (_,vs) in get(net,"voltage_source",Dict())
        b=get(vs,"bus",nothing); b isa AbstractString || continue
        tm=get(vs,"terminal_map",String[]); vm=get(vs,"v_magnitude",[])
        for (t,v) in zip(tm,vm)
            v isa Real && iszero(v) && upd!(b,string(t),0.0)
        end
    end
    for (_,s) in get(net,"shunt",Dict())
        b=get(s,"bus",nothing); tm=get(s,"terminal_map",String[])
        b isa AbstractString && length(tm)==1 || continue
        y=complex(Float64(get(s,"G_1_1",0.0)),Float64(get(s,"B_1_1",0.0)))
        isfinite(abs(y)) && abs(y)>0 || continue
        key=(b,string(only(tm)))
        admittance[key]=get(admittance,key,0im)+y
    end
    for ((b,t),y) in admittance
        abs(y)>0 && upd!(b,t,abs(1/y))
    end
    earth
end

function _unassessed_earthing_terminals(net)
    out=Set{Tuple{String,String}}()
    for (_,s) in get(net,"shunt",Dict())
        b=get(s,"bus",nothing);tm=get(s,"terminal_map",String[])
        b isa AbstractString && _index_strings(tm) && length(tm)>1 || continue
        for t in tm;push!(out,(b,t));end
    end
    # The scalar external-shunt observation does not assess internal winding
    # impedance branches. Refuse a missing-path inference when they are authored.
    for record in _connection_records(net)
        record.kind=="transformer" || continue
        for e in _connection_endpoints(record)
            e.raw isa AbstractDict && e.bus isa AbstractString && _index_strings(e.map) || continue
            keys=e.winding===nothing ? ("r_neutral_$(e.side)","x_neutral_$(e.side)") :
                ("r_neutral","x_neutral")
            any(k -> haskey(e.raw,k) && e.raw[k]!=0,keys) || continue
            for t in e.map;push!(out,(e.bus,t));end
        end
    end
    out
end

function _bus_neutral_earthing(net::Dict{String,Any},neutral_of)::Dict{String,Float64}
    paths=_terminal_earthing(net)
    Dict(b=>paths[(b,n)] for (b,n) in neutral_of if n!==nothing && haskey(paths,(b,n)))
end

# A bus return/reference label alone does not establish a transported conductor.
function _neutral_branch_buses(net)
    out=Set{String}()
    roles=_index_roles(net)
    roles===nothing && return out
    neutral_labels=roles.neutral
    for kind in ("line","switch"), (_,c) in get(net,kind,Dict())
        c isa AbstractDict || continue
        kind=="switch" && get(c,"open_switch",false) && continue
        f=get(c,"bus_from",nothing); t=get(c,"bus_to",nothing)
        f isa AbstractString && t isa AbstractString || continue
        tf=get(c,"terminal_map_from",String[]); tt=get(c,"terminal_map_to",String[])
        _index_strings(tf) && _index_strings(tt) && length(tf)==length(tt) || continue
        any(a in neutral_labels && b in neutral_labels for (a,b) in zip(tf,tt)) || continue
        push!(out,f); push!(out,t)
    end
    out
end

function _branch_wire_description(net,ids;carried=nothing)
    busset=Set(ids); sizes=Set{Int}(); malformed=false
    for kind in ("line","switch"),(_,c) in get(net,kind,Dict())
        if !(c isa AbstractDict)
            malformed=true; continue
        end
        kind=="switch" && get(c,"open_switch",false) && continue
        get(c,"bus_from",nothing) in busset && get(c,"bus_to",nothing) in busset || continue
        f=get(c,"terminal_map_from",nothing); t=get(c,"terminal_map_to",nothing)
        if !_index_strings(f) || !_index_strings(t) || isempty(f) || length(f)!=length(t)
            malformed=true
        else
            push!(sizes,length(f))
        end
    end
    malformed && return "indeterminate branch conductors"
    isempty(sizes) && return "no branch conductors represented"
    length(sizes)==1 || return "mixed ($(join(sort!(collect(sizes)),"/")) conductors)"
    n=only(sizes)
    carried===nothing && (carried=_neutral_branch_buses(net))
    n==4 && !all(in(carried),ids) &&
        return "4 conductors; neutral unassessed"
    "$n-wire"
end

"""Describe represented earthing per galvanic zone; protective-system identity is indeterminate."""
function _earthing_zones(net::Dict{String,Any},vl::Dict{String,Any})::Vector{Dict{String,Any}}
    buses=get(net,"bus",Dict()); isempty(buses) && return Dict{String,Any}[]
    neutral_of=_bus_neutral_map(buses); earth=_terminal_earthing(net)
    neutral_earth=Dict(b=>z for (b,z) in _bus_neutral_earthing(net,neutral_of)
        if !_is_grounded_reference(buses[b],neutral_of[b]))
    carried=_neutral_branch_buses(net)
    vmap=get(vl,"bus_voltage_map",Dict()); zones=Dict{String,Any}[]
    roles=_index_roles(net)
    neutral_labels=roles===nothing ? Set{String}() : roles.neutral
    unassessed=_unassessed_earthing_terminals(net)
    for isl in _galvanic_islands(net)
        islset=Set(isl)
        known=filter(isfinite,[Float64(get(vmap,b,NaN)) for b in isl])
        vnom=isempty(known) ? NaN : maximum(known)
        stars=Tuple{String,String}[]; infeed_buses=Set{String}()
        # A voltage source whose map holds only phase terminals pins each
        # phase-to-reference voltage: an ideal source referenced to ground by
        # construction, whatever the bus neutral does.
        ground_referenced_sources=String[]
        for (_,vs) in get(net,"voltage_source",Dict())
            b=get(vs,"bus",nothing); b in islset || continue
            push!(infeed_buses,b)
            tm=get(vs,"terminal_map",String[])
            for t in tm
                t in neutral_labels && push!(stars,(b,t))
            end
            _index_strings(tm) && !isempty(tm) && roles!==nothing &&
                all(t -> t in roles.phase,tm) && push!(ground_referenced_sources,b)
        end
        for record in _connection_records(net)
            record.kind=="transformer" || continue
            for e in _connection_endpoints(record)
                e.bus in islset || continue
                _index_strings(e.map) || continue
                for t in e.map
                    t in neutral_labels || continue
                    push!(stars,(e.bus,t)); push!(infeed_buses,e.bus)
                end
            end
        end
        unique!(stars)
        star_R=isempty(stars) ? Inf : minimum(get(earth,s,Inf) for s in stars)
        isempty(ground_referenced_sources) || (star_R=0.0)
        uncertain=any(s -> s in unassessed,stars) && !iszero(star_R)
        kind=iszero(star_R) ? "perfect" : isempty(stars) ? "indeterminate" :
             uncertain ? "indeterminate" :
             isfinite(star_R) ? "impedance" : "none"
        n_down=count(b -> haskey(neutral_earth,b) && !(b in infeed_buses),isl)
        nc=count(in(carried),isl)
        wires=_branch_wire_description(net,isl;carried)
        tag=kind=="indeterminate" ? "earthing indeterminate (infeed grounding unassessed)" :
            n_down>0 ? "multi-earthed neutral; protective-earthing system indeterminate" :
            kind=="perfect" ? "grounded infeed reference; protective-earthing system indeterminate" :
            kind=="impedance" ? "impedance-earthed infeed; protective-earthing system indeterminate" :
            "no local infeed earth represented; protective-earthing system indeterminate"
        push!(zones,Dict{String,Any}("buses"=>isl,"n_buses"=>length(isl),
            "nominal_v"=>vnom,"wires"=>wires,"star_earthing"=>kind,
            "star_R_ohm"=>star_R,"n_downstream_earths"=>n_down,"tag"=>tag,
            "status"=>uncertain || roles===nothing ? "indeterminate" : "assessed","protective_system_status"=>"indeterminate",
            "unassessed_earthing_terminals"=>[Dict("bus"=>b,"terminal"=>t)
                for (b,t) in sort!(collect(unassessed)) if b in islset],
            "knowledge_ids"=>["PSK-000002"],
            "n_buses_with_neutral_conductor"=>nc,
            "star_points"=>vcat([Dict{String,Any}("bus"=>b,"terminal"=>t,
                "impedance_ohm"=>get(earth,(b,t),Inf)) for (b,t) in stars],
                [Dict{String,Any}("bus"=>b,"terminal"=>nothing,"impedance_ohm"=>0.0,
                    "basis"=>"voltage_source_pins_phase_to_reference")
                 for b in sort!(unique(ground_referenced_sources))]),
            "neutral_earths"=>[Dict{String,Any}("bus"=>b,"terminal"=>neutral_of[b],
                "impedance_ohm"=>neutral_earth[b]) for b in isl if haskey(neutral_earth,b)]))
    end
    sort!(zones,by=z->-(isnan(z["nominal_v"]) ? -Inf : z["nominal_v"]))
    zones
end
